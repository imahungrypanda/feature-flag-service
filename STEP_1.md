# Step 1: User Targeting & Percentage Rollouts

## Current State

The `evaluateFlag` query already accepts `userId` and `attributes` arguments, but ignores them — every flag is either fully on or fully off. This means the service cannot serve one of the primary use cases of a feature flag system: gradual rollouts and targeted releases.

## Goal

Extend the flag evaluation engine to support:
1. **Percentage rollouts** — enable a flag for N% of users deterministically
2. **Attribute-based targeting rules** — enable a flag for users matching conditions (e.g. `plan == "enterprise"`, `country IN ["US", "CA"]`)

## Implementation Approach

### 1. Database: Add a `rules` JSONB column to `flags`

```ruby
# db/migrate/TIMESTAMP_add_rules_to_flags.rb
add_column :flags, :rules, :jsonb, default: [], null: false
add_column :flags, :rollout_percentage, :integer, default: 100, null: false
```

Rules stored as structured JSON:
```json
[
  { "attribute": "plan", "operator": "eq", "value": "enterprise" },
  { "attribute": "country", "operator": "in", "value": ["US", "CA"] }
]
```

### 2. Model: `Flag#evaluate(user_id:, attributes:)`

Add a pure-Ruby evaluation method to `app/models/flag.rb`:

```ruby
def evaluate(user_id: nil, attributes: {})
  return false unless enabled?
  return true if rules.empty? && rollout_percentage == 100

  in_rollout?(user_id) && matches_rules?(attributes)
end
```

- **Rollout**: Use `Digest::MD5.hexdigest("#{key}:#{user_id}").hex % 100 < rollout_percentage` for sticky, deterministic bucketing — the same user always gets the same result for a given flag.
- **Rules**: Evaluate all rules with AND logic. Support operators: `eq`, `neq`, `in`, `not_in`, `lt`, `gt`.

### 3. GraphQL: `EvaluateResultType` — add `reason` field

```graphql
type EvaluateResult {
  enabled: Boolean!
  flagNotFound: Boolean!
  reason: String        # "rule_match" | "rollout" | "flag_disabled" | "flag_not_found"
}
```

### 4. GraphQL: Extend `updateFlag` / `createFlag` mutations

Add inputs for rules and rollout percentage:
```graphql
input UpdateFlagInput {
  key: String!
  enabled: Boolean
  rolloutPercentage: Int
  rules: JSON
}
```

### 5. Validation

Add model-level validation of the rules schema (operator whitelist, attribute name format) to prevent malformed rules from being stored.

## Tests to Add

- `Flag#evaluate` unit tests: disabled flag, 0% rollout, 100% rollout, boundary user, attribute match/no-match
- Integration tests: `evaluateFlag` with userId returns deterministic results, attribute targeting returns correct result per attribute set
- Mutation tests: create/update with rollout percentage and rules

## Expected Outcome

The service can now do gradual canary releases (`rolloutPercentage: 10`) and target specific user segments (`plan == "beta"`). The evaluation result is deterministic — the same userId always resolves to the same on/off state for a given flag configuration, with no state stored per user.
