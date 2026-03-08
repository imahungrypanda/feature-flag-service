# Step 3: Audit Log

## Current State

Flag changes (create, update, archive, delete) leave no trace. In production, teams need to answer questions like "Who turned off the checkout flag at 2am?" and "What was the rollout percentage before it was changed?" Without an audit trail, debugging incidents and satisfying compliance requirements is impossible.

## Goal

Record an immutable audit log entry for every state-changing operation on a flag:
- What changed (field, old value, new value)
- When it changed
- Which API token authorized the change (actor identity)

## Implementation Approach

### 1. Database: `flag_audits` table

```ruby
# db/migrate/TIMESTAMP_create_flag_audits.rb
create_table :flag_audits do |t|
  t.references :flag, null: false, foreign_key: true, index: true
  t.string  :action,      null: false   # "created" | "updated" | "archived" | "deleted"
  t.jsonb   :changes,     null: false, default: {}
  t.string  :actor_token_digest          # SHA-256 of the Bearer token (never store raw token)
  t.timestamps null: false
end
```

Store a one-way digest of the token (`Digest::SHA256.hexdigest(token)`) so the actor is identifiable across requests without exposing the token itself.

### 2. Model: `FlagAudit`

```ruby
class FlagAudit < ApplicationRecord
  belongs_to :flag
  validates :action, inclusion: { in: %w[created updated archived deleted] }

  TRACKED_FIELDS = %w[enabled description rollout_percentage rules archived_at].freeze
end
```

### 3. Model: Callback in `Flag`

Add an `after_create` and `after_update` callback (or use ActiveModel::Dirty) to automatically write audit entries:

```ruby
after_create  { write_audit("created") }
after_update  { write_audit("updated") }

private

def write_audit(action)
  FlagAudit.create!(
    flag: self,
    action: action,
    changes: previous_changes.slice(*FlagAudit::TRACKED_FIELDS),
    actor_token_digest: Current.actor_token_digest
  )
end
```

Use `ActiveSupport::CurrentAttributes` to thread the token digest from the controller into the model layer without passing it explicitly.

### 4. Controller: Set `Current.actor_token_digest`

In `GraphqlController#authenticate_token!`, after successful auth:
```ruby
Current.actor_token_digest = Digest::SHA256.hexdigest(token)
```

### 5. GraphQL: `flagAudits` query

```graphql
query {
  flagAudits(key: "my-flag", limit: 20) {
    action
    changes
    actorTokenDigest
    createdAt
  }
}
```

Scope to a specific flag key, with pagination (limit/offset or Relay cursor). Audits are read-only — no mutations.

### 6. Retention policy

Add a Rake task or Solid Queue recurring job to purge audit records older than a configurable retention window (default 90 days):

```ruby
# lib/tasks/audits.rake
task purge_old_audits: :environment do
  FlagAudit.where("created_at < ?", ENV.fetch("AUDIT_RETENTION_DAYS", 90).to_i.days.ago).delete_all
end
```

## Tests to Add

- Creating a flag writes a `"created"` audit with correct changes hash
- Updating `enabled` writes an `"updated"` audit with `[false, true]` diff
- Archiving writes an `"archived"` audit
- `actor_token_digest` is set and is a SHA-256 hex string (not the raw token)
- `flagAudits` query returns entries in reverse-chronological order
- `flagAudits` query scoped to the correct flag key
- Purge task deletes only records older than the retention window

## Expected Outcome

Every mutation to a flag is durably recorded with a before/after diff and actor identity. On-call engineers can answer "what changed and when" within seconds. The audit log is append-only from the application perspective, and raw API tokens are never persisted.
