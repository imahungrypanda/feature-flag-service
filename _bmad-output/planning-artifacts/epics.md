---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: ['prd.md', 'architecture.md']
---

# feature-flag-service - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for feature-flag-service, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: A caller can create a feature flag by providing a unique key and optional metadata.
- FR2: A caller can retrieve a flag's current state (e.g. enabled/disabled) by key.
- FR3: A caller can update a flag's state (toggle on/off) for rollback or rollout.
- FR4: The system persists flags so they survive restarts and can be evaluated later.
- FR5: A caller can evaluate a single flag by key and receive an enabled/disabled (or equivalent) result.
- FR6: A caller can optionally provide context (e.g. user id, attributes) when evaluating a flag.
- FR7: When a flag does not exist or the key is invalid, the system returns a deterministic, safe result (e.g. disabled or explicit error) so callers can degrade gracefully.
- FR8: A caller must supply valid minimal credentials (e.g. API key or bearer token) to perform create, evaluate, or update operations.
- FR9: Requests without valid credentials are rejected with a clear, standard error.
- FR10: All flag operations are available via a single, documented interface (GraphQL in MVP).
- FR11: The system exposes a way to create flags, evaluate flags, and update flag state through that interface.
- FR12: The system provides enough information (e.g. README, example operations) for a developer to create a flag, evaluate it, and toggle it without additional documentation.

### NonFunctional Requirements

- NFR1: Evaluate-flag operations complete within a defined response-time budget (e.g. p95 under 200 ms or similar target to be set at implementation) so callers can use the result in request-time decisions.
- NFR2: Create and update operations complete within a reasonable time; no strict SLA for MVP beyond "responsive under normal load."
- NFR3: Credentials (API key or bearer token) are transmitted and stored in a way that avoids plaintext exposure (e.g. HTTPS, secure storage).
- NFR4: Only requests presenting valid credentials can perform create, evaluate, or update operations; unauthorized requests receive a clear, non-revealing error.
- NFR5: The service runs in a way that allows it to be available for evaluation and updates under normal operation (e.g. single instance, no formal SLA for MVP).
- NFR6: Flag state is persisted so that a restart does not lose existing flags or their on/off state.

### Additional Requirements

- **Starter template (Epic 1 Story 1):** Initialize project with Rails API + graphql-ruby: `rails new feature-flag-service --api -d postgresql --skip-test`, then `bundle add graphql`, then `rails g graphql:install --api`. Project initialization is the first implementation story.
- **Database:** PostgreSQL; one `flags` table with unique `key`, `enabled`, optional `description`, timestamps; Rails migrations.
- **Authentication:** Bearer token (single API key in `Authorization: Bearer <token>`); verify in GraphqlController before executing GraphQL; reject with 401 if invalid. Store token in Rails credentials or env.
- **API:** Single POST /graphql endpoint; schema exposes Query (evaluate) and Mutation (create flag, update/toggle flag). GraphQL errors array for validation and server errors; deterministic missing-flag behavior (e.g. return disabled or FLAG_NOT_FOUND).
- **Implementation sequence:** Starter → DB/model → GraphQL types & mutations → auth in controller → error handling → README examples.
- **Infrastructure:** Single instance for MVP; DATABASE_URL and API key via credentials or ENV; run migrations on deploy. HTTPS in production.
- **No UI, no caching, no rate limiting for MVP.**

### FR Coverage Map

- FR1: Epic 2 - Create flag with key and optional metadata
- FR2: Epic 2 - Retrieve flag state by key
- FR3: Epic 2 - Update/toggle flag state
- FR4: Epic 1 - Persist flags (DB and migrations)
- FR5: Epic 3 - Evaluate single flag by key
- FR6: Epic 3 - Optional context on evaluate
- FR7: Epic 3 - Deterministic missing-flag result
- FR8: Epic 4 - Valid credentials required
- FR9: Epic 4 - Reject invalid credentials with clear error
- FR10: Epic 1 - Single GraphQL interface
- FR11: Epic 2 & 3 - Expose create, evaluate, update via interface
- FR12: Epic 4 - README and example operations

## Epic List

### Epic 1: Project foundation and API shell
Developers have a running Rails API with a GraphQL endpoint and persistence for flags.
**FRs covered:** FR4, FR10

### Epic 2: Create and manage flags
Developers can create, retrieve, and update flags via the GraphQL API.
**FRs covered:** FR1, FR2, FR3, FR11 (create/update)

### Epic 3: Evaluate flags
Developers can evaluate a flag by key and get a deterministic enabled/disabled (or error) result; missing flags are handled safely.
**FRs covered:** FR5, FR6, FR7

### Epic 4: Secure and document the API
Only authenticated callers can perform operations; developers have README and example operations to use the API.
**FRs covered:** FR8, FR9, FR12

---

## Epic 1: Project foundation and API shell

Developers have a running Rails API with a GraphQL endpoint and persistence for flags.

### Story 1.1: Initialize Rails API with GraphQL

As a developer,
I want a new Rails API application with GraphQL installed and configured,
So that I have a single endpoint and schema to add flag operations.

**Acceptance Criteria:**

- **Given** a clean project directory
- **When** I run the architecture-specified commands (`rails new feature-flag-service --api -d postgresql --skip-test`, `bundle add graphql`, `rails g graphql:install --api`)
- **Then** the project has a working Rails API (no views/assets), PostgreSQL as the database, and GraphQL schema/types under `app/graphql/`
- **And** a single POST endpoint (e.g. `/graphql`) is available and responds to GraphQL requests
- **And** the app boots and the GraphQL endpoint returns a valid response (e.g. introspection or a placeholder query)

### Story 1.2: Add flags table and Flag model

As a developer,
I want a `flags` table and a `Flag` model with key, enabled, and optional metadata,
So that the system can persist flags and survive restarts.

**Acceptance Criteria:**

- **Given** the Rails API from Story 1.1
- **When** I add a migration for a `flags` table with: unique string `key`, boolean `enabled`, optional `description` (or text metadata), and timestamps
- **Then** the migration runs successfully and the table exists in the database
- **And** a `Flag` model exists with validations: presence of `key`, uniqueness of `key`
- **And** creating a flag via the Rails console (e.g. `Flag.create!(key: "test", enabled: true)`) persists and can be reloaded after restart

---

## Epic 2: Create and manage flags

Developers can create, retrieve, and update flags via the GraphQL API.

### Story 2.1: Create flag mutation

As a caller,
I want to create a feature flag by providing a unique key and optional metadata via GraphQL,
So that I can manage flags through the API (FR1).

**Acceptance Criteria:**

- **Given** the GraphQL API and Flag model from Epic 1
- **When** I send a GraphQL mutation (e.g. `createFlag(key: "my_flag", enabled: true, description: "Optional")`) with valid input
- **Then** a new flag is persisted and the mutation returns the created flag (e.g. key, enabled, description)
- **And** sending the same key again returns a validation error (e.g. key already taken)
- **And** omitting optional fields (e.g. description) creates the flag with defaults (e.g. enabled: false if not provided)

### Story 2.2: Retrieve flag by key

As a caller,
I want to retrieve a flag's current state (enabled/disabled) by key via GraphQL,
So that I can inspect flag state (FR2).

**Acceptance Criteria:**

- **Given** at least one flag exists
- **When** I send a GraphQL query with the flag key (e.g. a query that returns a flag by key)
- **Then** the response includes the flag's key, enabled state, and any stored metadata
- **And** querying for a non-existent key returns a deterministic error or null as defined by the schema (no 500)

### Story 2.3: Update flag state (toggle) mutation

As a caller,
I want to update a flag's state (toggle on/off) via GraphQL,
So that I can roll out or roll back features (FR3).

**Acceptance Criteria:**

- **Given** a flag exists
- **When** I send a GraphQL mutation to update the flag (e.g. `updateFlag(key: "my_flag", enabled: false)`)
- **Then** the flag's `enabled` value is updated in the database and the mutation returns the updated flag
- **And** updating a non-existent key returns a clear error (e.g. not found)
- **And** the updated state is persisted and visible on subsequent retrieve or evaluate

---

## Epic 3: Evaluate flags

Developers can evaluate a flag by key and get a deterministic enabled/disabled (or error) result; missing flags are handled safely.

### Story 3.1: Evaluate single flag by key

As a caller,
I want to evaluate a single flag by key and receive an enabled/disabled result via GraphQL,
So that I can gate behavior in my application (FR5).

**Acceptance Criteria:**

- **Given** the GraphQL API and at least one flag
- **When** I send a GraphQL query to evaluate a flag by key (e.g. `evaluateFlag(key: "my_flag")`)
- **Then** the response includes whether the flag is enabled or disabled (or equivalent boolean/result type)
- **And** the result reflects the current persisted state of the flag
- **And** evaluate is implemented as a read (query), not a mutation

### Story 3.2: Optional context on evaluate

As a caller,
I want to optionally provide context (e.g. user id, attributes) when evaluating a flag,
So that future targeting or logging can use it (FR6); for MVP the system may ignore context but must accept it.

**Acceptance Criteria:**

- **Given** the evaluate query from Story 3.1
- **When** I send an evaluate request with optional context arguments (e.g. userId, attributes)
- **Then** the request is accepted and does not error
- **And** the result is still based on the flag's enabled state (MVP does not require context to change the result)
- **And** context can be omitted; when omitted, evaluate still returns the flag state

### Story 3.3: Deterministic missing-flag behavior

As a caller,
I want a deterministic, safe result when a flag does not exist or the key is invalid,
So that my application can degrade gracefully (FR7).

**Acceptance Criteria:**

- **Given** the evaluate query from Story 3.1
- **When** I evaluate with a key that does not exist (or invalid key)
- **Then** the system returns a deterministic result (e.g. disabled, or an explicit error code/message like FLAG_NOT_FOUND)
- **And** the response is not a 500; it is a defined behavior (e.g. GraphQL error or a "disabled" result)
- **And** the behavior is documented (e.g. in schema or README) so callers know how to handle it

---

## Epic 4: Secure and document the API

Only authenticated callers can perform operations; developers have README and example operations to use the API.

### Story 4.1: Bearer token authentication

As a service operator,
I want all create, evaluate, and update requests to require a valid Bearer token,
So that only authorized callers can use the API (FR8, FR9).

**Acceptance Criteria:**

- **Given** the GraphQL endpoint from Epic 1
- **When** a request does not include a valid `Authorization: Bearer <token>` (or token does not match the configured value)
- **Then** the request is rejected with a clear, standard error (e.g. 401) and a non-revealing message
- **And** when a valid token is present (stored in Rails credentials or ENV), create, evaluate, and update operations succeed
- **And** the token is not logged or exposed in error responses
- **And** authentication is applied at the GraphQL controller (or equivalent) before executing the GraphQL operation

### Story 4.2: README with example operations

As a developer,
I want a README with enough information and example operations to create a flag, evaluate it, and toggle it,
So that I can use the API without additional documentation (FR12).

**Acceptance Criteria:**

- **Given** the full API (create, evaluate, update) and auth from previous stories
- **When** I read the README
- **Then** it explains how to run the service (e.g. DB setup, migrations, env/credentials for API key)
- **And** it includes at least one example each for: creating a flag, evaluating a flag, and updating/toggling a flag (e.g. curl or GraphQL snippets)
- **And** it states how missing-flag or invalid-key behavior works (e.g. deterministic disabled or FLAG_NOT_FOUND)
- **And** a developer can create a flag, evaluate it, and toggle it using only the README and the API
