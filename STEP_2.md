# Step 2: Flag Deletion & Archival

## Current State

There is no way to remove flags. `createFlag` and `updateFlag` mutations exist, but there is no `deleteFlag` mutation. In production environments, stale flags accumulate over time and become technical debt — teams need a safe way to retire flags once a rollout is complete.

## Goal

Add safe flag lifecycle management:
1. **Soft delete (archive)** — flags are hidden from normal operation but retained for audit history
2. **Hard delete mutation** — permanently remove an archived flag with an explicit confirmation step
3. **`archivedAt` timestamp** — lets clients distinguish retired flags from active ones

## Implementation Approach

### 1. Database: Add `archived_at` column

```ruby
# db/migrate/TIMESTAMP_add_archived_at_to_flags.rb
add_column :flags, :archived_at, :datetime, default: nil
add_index  :flags, :archived_at
```

### 2. Model: Default scope + archival methods

```ruby
class Flag < ApplicationRecord
  scope :active,    -> { where(archived_at: nil) }
  scope :archived,  -> { where.not(archived_at: nil) }

  def archive!
    update!(archived_at: Time.current, enabled: false)
  end

  def archived?
    archived_at.present?
  end
end
```

All existing queries (`flag(key:)`, `evaluateFlag`) already call `Flag.find_by` — update these to scope to `.active` by default so archived flags are excluded from evaluation. An archived flag evaluates as `enabled: false`.

### 3. GraphQL: `archiveFlag` mutation

```graphql
mutation {
  archiveFlag(input: { key: "my-flag" }) {
    flag { key archivedAt }
    errors
  }
}
```

- Sets `archived_at`, forces `enabled: false`
- Idempotent: archiving an already-archived flag is a no-op

### 4. GraphQL: `deleteFlag` mutation (hard delete)

```graphql
mutation {
  deleteFlag(input: { key: "my-flag", confirm: true }) {
    deletedKey
    errors
  }
}
```

- Requires `confirm: true` to prevent accidental deletion
- Only allows deletion of archived flags (must archive first)
- Returns the deleted key for client confirmation

### 5. GraphQL: `FlagType` — add `archivedAt` field

```graphql
type Flag {
  id: ID!
  key: String!
  enabled: Boolean!
  description: String
  archivedAt: ISO8601DateTime
  createdAt: ISO8601DateTime!
  updatedAt: ISO8601DateTime!
}
```

### 6. GraphQL: `flags` list query with filter

Add a top-level `flags` query with an optional `includeArchived` argument:

```graphql
query {
  flags(includeArchived: false) {
    key
    enabled
    archivedAt
  }
}
```

This is needed as a companion to deletion — clients need to be able to list all flags to find what to archive/delete, and currently there is no list query.

## Tests to Add

- `Flag#archive!` sets `archived_at` and `enabled: false`
- `Flag.active` excludes archived flags
- `evaluateFlag` on an archived key returns `enabled: false, flagNotFound: false`
- `archiveFlag` mutation: success path, idempotent path
- `deleteFlag` mutation: requires archived state, requires `confirm: true`, hard-deletes record
- `flags` query: respects `includeArchived` filter

## Expected Outcome

Teams can safely retire feature flags after a rollout completes. The two-step process (archive → delete) prevents accidental loss of flag history. Archived flags are excluded from evaluation without breaking client code that may still send `evaluateFlag` requests for a retired key.
