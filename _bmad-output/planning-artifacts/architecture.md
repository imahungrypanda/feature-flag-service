---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments: ['prd.md', 'product-brief-feature-flag-service-2025-02-04.md']
workflowType: 'architecture'
project_name: 'feature-flag-service'
user_name: 'Steve'
date: '2025-02-04'
lastStep: 8
status: 'complete'
completedAt: '2025-02-04'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
- **Flag management:** Create (unique key + optional metadata), retrieve state, update (toggle), persist across restarts (FR1–FR4).
- **Flag evaluation:** Single-flag evaluation by key with optional context; deterministic, safe result for missing/invalid flag (FR5–FR7).
- **Authentication & access:** Minimal credentials (API key or bearer) required for create/evaluate/update; invalid credentials rejected (FR8–FR9).
- **API contract:** Single documented interface (GraphQL) exposing create, evaluate, and update (FR10–FR11).
- **Operational visibility:** README and example operations so a developer can run the full loop without extra docs (FR12).

**Non-Functional Requirements:**
- **Performance:** Evaluate operations within a defined response-time budget (e.g. p95 under 200 ms) for request-time use; create/update "responsive under normal load."
- **Security:** Credentials transmitted and stored without plaintext exposure; only valid credentials can perform operations.
- **Reliability:** Service available under normal operation; flag state persisted so restarts do not lose flags or their on/off state.

**Scale & Complexity:**
- **Primary domain:** API backend (GraphQL).
- **Complexity level:** Low — single service, one API surface, simple flag model.
- **Architectural components (MVP):** GraphQL layer, flag persistence, auth layer, optional read path optimization (caching) for evaluate.

### Technical Constraints & Dependencies

- **Interface:** GraphQL only; no REST. Schema must support mutations (create, update/toggle) and query (evaluate).
- **Storage:** Persistent store for flags (key, enabled state, optional metadata); unique key constraint; survive restarts.
- **Auth:** Minimal for MVP (single API key or bearer token); no multi-tenant or RBAC.
- **Deferred:** Rate limiting, API versioning, bulk operations, targeting rules, multi-account.

### Cross-Cutting Concerns Identified

- **Authentication:** Applied to all create, evaluate, and update operations; reject unauthenticated requests consistently.
- **Error handling & missing-flag contract:** Deterministic, safe behavior for unknown/missing flag and invalid input; clear errors for clients.
- **Persistence & reliability:** Durable flag state; design supports future HA without blocking MVP.

## Starter Template Evaluation

### Primary Technology Domain

**API backend (Rails + GraphQL)** — From PRD and product brief: Ruby on Rails application serving a GraphQL API for feature flags. No UI in MVP.

### Starter Options Considered

- **Rails API + graphql-ruby:** Create a new Rails API app (`rails new ... --api`), add `gem "graphql"`, then run `rails g graphql:install --api`. This is the standard, maintained approach (graphql-ruby.org). No third-party "starter repo" required; the gem's generators provide schema, Query/Mutation types, base types/mutations, and optional GraphiQL.
- **Full-stack starters (e.g. Rails + Svelte/React + GraphQL):** Rejected for MVP; PRD is API-only with no UI.

### Selected Starter: Rails API + graphql-ruby generator

**Rationale for Selection:**  
PRD and brief specify Rails and GraphQL. The graphql-ruby gem is the standard for Rails GraphQL APIs; its install generator gives a consistent layout (`app/graphql/`), schema, and query/mutation entry points. API-only mode matches "no UI" and keeps the surface small. No separate boilerplate repo is needed.

**Initialization Commands:**

```bash
# Create Rails API app (no frontend, no unnecessary defaults)
rails new feature-flag-service --api -d postgresql --skip-test

# Add GraphQL (in Gemfile add: gem "graphql")
bundle add graphql

# Install GraphQL schema, types, and routes (API mode)
rails g graphql:install --api
bundle install
```

**Architectural Decisions Provided by Starter:**

- **Language & runtime:** Ruby, Rails API mode (no views/assets).
- **API surface:** GraphQL only; single endpoint (e.g. POST /graphql); schema and types under `app/graphql/`.
- **Build / tooling:** Rails default (Bundler, no separate frontend build for MVP).
- **Testing:** Rails test stack (or RSpec if added); no starter-specific test framework.
- **Code organization:** `app/graphql/` (types, mutations, resolvers), `app/models/` for persistence; schema defined in one place.
- **Development experience:** Optional GraphiQL (or skip with `--skip-graphiql`); standard `rails s` and console.

**Note:** Project initialization using these commands should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Database: PostgreSQL (from starter).
- Flag persistence: Single table (key, enabled, optional metadata); Rails migrations.
- Authentication: Bearer token (single API key in Authorization header).
- GraphQL schema: Create, evaluate, toggle operations exposed via graphql-ruby.

**Important Decisions (Shape Architecture):**
- No caching for MVP; evaluate reads from DB (enables simple rollout; add caching later if needed for p95).
- Errors: Deterministic missing-flag behavior and validation errors per PRD; standard GraphQL error shape.
- Security: Token in env/credentials; HTTPS in production.

**Deferred Decisions (Post-MVP):**
- Rate limiting, API versioning, bulk operations, targeting rules, multi-account (per PRD).
- Caching layer, HA, scaling, advanced monitoring.

### Data Architecture

- **Database:** PostgreSQL. Rationale: Aligns with `rails new -d postgresql`; durable, simple for MVP.
- **Data model:** One `flags` table: unique `key` (string), `enabled` (boolean), optional `description`/metadata; timestamps. No targeting rules or variants in MVP.
- **Validation:** Uniqueness of key at DB and model layer; presence of key on create/update.
- **Migrations:** Rails migrations for schema changes.
- **Caching:** None for MVP; evaluate path reads from DB. Rationale: Keeps implementation simple; NFR p95 can be met with a single DB read; caching can be added later.

### Authentication & Security

- **Authentication method:** Bearer token (e.g. single API key sent as `Authorization: Bearer <token>`). Rationale: PRD specifies minimal auth; bearer token is standard and easy to implement.
- **Token storage:** Server-side: store token in Rails credentials or env; never commit plaintext. Clients hold their own copy for requests.
- **Authorization:** Single credential for MVP; all valid callers have same access. No RBAC or multi-tenant until post-MVP.
- **HTTPS:** Required in production (NFR: credentials not exposed in transit).
- **Invalid credentials:** Reject with 401 and clear, non-revealing error (per PRD).

### API & Communication Patterns

- **API design:** GraphQL only; single endpoint (e.g. POST /graphql). Schema: Query (evaluate), Mutation (create flag, update/toggle flag). Rationale: From PRD and starter.
- **Error handling:** Unknown/missing flag → deterministic result (e.g. return disabled or explicit error code). Invalid input → validation errors with clear messages. Server errors → standard 5xx. Rationale: PRD and FR7.
- **Rate limiting:** Deferred (post-MVP).
- **Documentation:** README with example operations (per PRD); optional GraphiQL for development.

### Frontend Architecture

- **N/A for MVP** — API-only; no UI.

### Infrastructure & Deployment

- **Hosting:** Single instance for MVP; runnable locally and on one server (e.g. Heroku, Railway, or VM). No HA or multi-region for MVP.
- **CI/CD:** Deferred or minimal (e.g. manual deploy, optional GitHub Actions for tests).
- **Environment configuration:** Rails env (development, test, production); credentials/env for API key and DB URL.
- **Monitoring & logging:** Standard Rails logging; no dedicated APM required for MVP.

### Decision Impact Analysis

**Implementation sequence:**
1. Rails API + graphql-ruby setup (starter commands).
2. PostgreSQL and `flags` table (migration, model).
3. GraphQL types and mutations (create, evaluate, toggle).
4. Authentication middleware (verify Bearer token on GraphQL controller).
5. Error handling (missing flag, validation, 401).
6. README with example operations.

**Cross-component dependencies:** Auth applies to all GraphQL operations. Persistence is required before evaluate/toggle can work. Schema and types depend on Flag model.

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical conflict points:** Naming (DB, GraphQL, Ruby), project layout, API/error formats, auth and error-handling flow.

### Naming Patterns

**Database naming (Rails):**
- Tables: plural, snake_case (e.g. `flags`).
- Columns: snake_case (e.g. `enabled`, `description`, `created_at`).
- Indexes: `index_<table>_on_<columns>` or Rails default.

**GraphQL naming:**
- Types: PascalCase (e.g. `Flag`, `EvaluationResult`).
- Fields: camelCase in schema (graphql-ruby default for clients); map to Ruby snake_case in resolvers as needed.
- Mutations: verb + noun, PascalCase (e.g. `CreateFlag`, `UpdateFlag`, `EvaluateFlag`).

**Ruby / code naming:**
- Files: snake_case (e.g. `flag_type.rb`, `create_flag.rb`).
- Classes/modules: PascalCase (e.g. `Types::FlagType`, `Mutations::CreateFlag`).
- Methods: snake_case. Constants: SCREAMING_SNAKE_CASE.

### Structure Patterns

**Project organization:**
- Models: `app/models/` (e.g. `flag.rb`).
- GraphQL: `app/graphql/` — types under `types/`, mutations under `mutations/`, schema in root (per graphql-ruby generator).
- Controllers: `app/controllers/` (e.g. `GraphqlController` for the single endpoint).
- Tests: `test/` (Rails default) or `spec/` if RSpec; mirror app structure (e.g. `test/models/flag_test.rb`, `test/graphql/...`).

**File structure:**
- Config: `config/`; env-specific in `config/environments/`. Credentials: Rails credentials or env for API key.
- No frontend assets for MVP; keep `app/assets` minimal if present.

### Format Patterns

**API (GraphQL) response:**
- Success: GraphQL standard response; `data` holds result; no extra wrapper beyond schema.
- Errors: Use GraphQL `errors` array; each error has `message`; optional `extensions` for code (e.g. `FLAG_NOT_FOUND`, `UNAUTHORIZED`). No custom top-level `error` wrapper.
- Missing flag: Return a defined result (e.g. `enabled: false`) or an error with code `FLAG_NOT_FOUND`; never unhandled exception to client. Document behavior in schema/README.

**Data exchange:**
- JSON: GraphQL controls field names (camelCase typical). Internal Ruby: snake_case.
- Booleans: `true`/`false`. Dates: ISO 8601 in API if exposed.

### Process Patterns

**Authentication:**
- Apply in one place (e.g. `GraphqlController` or shared before_action). Verify `Authorization: Bearer <token>` against configured API key; on failure return 401 and do not execute GraphQL.
- Do not put auth logic inside individual resolvers; keep it at the entry layer.

**Error handling:**
- Resolvers/mutations: Rescue known cases (e.g. `ActiveRecord::RecordNotFound` for missing flag); return deterministic result or add to GraphQL `errors`.
- Validation: Model validations + GraphQL argument validation; translate to GraphQL errors with clear messages. Do not raise uncaught exceptions to the client.
- Log server errors; do not expose internal details in client-facing messages.

**Loading / availability:**
- No UI in MVP; no global loading state. For API, 503 or GraphQL errors if the service is degraded; document in README if needed.

### Enforcement Guidelines

**All implementers MUST:**
- Use the naming conventions above for new DB columns, GraphQL types/fields, and Ruby files/classes.
- Put GraphQL definitions under `app/graphql/` and models under `app/models/`.
- Enforce auth at the single entry point; use deterministic missing-flag behavior and GraphQL errors for failures.
- Add tests for create, evaluate, and toggle (and auth rejection); keep tests in `test/` (or `spec/`) mirroring app structure.

**Pattern enforcement:** Code review and test suite. Document any exception in this architecture doc or README.

### Pattern Examples

**Good:** Table `flags`, columns `key`, `enabled`, `description`; type `Types::FlagType` with field `enabled`; mutation `Mutations::CreateFlag`; auth in `GraphqlController#execute`; missing flag returns `{ enabled: false }` or error with `FLAG_NOT_FOUND`.

**Avoid:** Mixed camelCase in DB; auth logic duplicated in each resolver; uncaught exceptions for missing flag; ad-hoc error wrappers instead of GraphQL `errors`.

## Project Structure & Boundaries

### Complete Project Directory Structure

```
feature-flag-service/
├── README.md
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── config.ru
├── .gitignore
├── .ruby-version
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── graphql_controller.rb          # Single GraphQL endpoint; auth here
│   ├── graphql/
│   │   ├── feature_flag_schema.rb         # Schema (query + mutation root)
│   │   ├── types/
│   │   │   ├── base_object.rb
│   │   │   ├── base_argument.rb
│   │   │   ├── base_field.rb
│   │   │   ├── query_type.rb              # Root query (e.g. evaluate)
│   │   │   ├── mutation_type.rb           # Root mutation (create, update)
│   │   │   ├── flag_type.rb               # Flag type
│   │   │   └── evaluation_result_type.rb  # Result of evaluate
│   │   └── mutations/
│   │       ├── base_mutation.rb
│   │       ├── create_flag.rb
│   │       └── update_flag.rb
│   ├── models/
│   │   ├── application_record.rb
│   │   └── flag.rb
│   └── ...
├── config/
│   ├── application.rb
│   ├── environment.rb
│   ├── routes.rb                          # POST /graphql
│   ├── database.yml
│   ├── credentials.yml.enc
│   └── environments/
│       ├── development.rb
│       ├── test.rb
│       └── production.rb
├── db/
│   ├── schema.rb
│   ├── seeds.rb
│   └── migrate/
│       └── XXXXXX_create_flags.rb
├── test/
│   ├── test_helper.rb
│   ├── controllers/
│   │   └── graphql_controller_test.rb
│   ├── graphql/
│   │   ├── mutations/
│   │   │   ├── create_flag_test.rb
│   │   │   └── update_flag_test.rb
│   │   └── query_type_test.rb             # evaluate behavior + missing flag
│   └── models/
│       └── flag_test.rb
├── lib/
│   └── tasks/
└── log/, tmp/
```

### Architectural Boundaries

**API boundaries:** Single external surface: POST `/graphql`. Auth (Bearer token) enforced in `GraphqlController` before execution. No REST endpoints.

**Component boundaries:** Controllers → GraphQL schema; schema → types/mutations; mutations/queries → `Flag` model; model → DB. No cross-service calls in MVP.

**Data boundaries:** All persistence via ActiveRecord and `flags` table. No caching layer in MVP. Credentials/API key in Rails credentials or env only.

### Requirements to Structure Mapping

| FR / concern        | Location |
|---------------------|----------|
| Create flag (FR1)   | `app/graphql/mutations/create_flag.rb`, `app/models/flag.rb` |
| Retrieve/toggle (FR2–FR3) | `app/graphql/mutations/update_flag.rb`, `app/graphql/types/query_type.rb`, `app/models/flag.rb` |
| Persist (FR4)       | `app/models/flag.rb`, `db/migrate/`, `db/schema.rb` |
| Evaluate (FR5–FR7)  | `app/graphql/types/query_type.rb`, `app/models/flag.rb` (lookup + deterministic missing) |
| Auth (FR8–FR9)      | `app/controllers/graphql_controller.rb` |
| API contract (FR10–FR11) | `app/graphql/feature_flag_schema.rb`, `app/graphql/types/`, `app/graphql/mutations/` |
| README/examples (FR12) | `README.md` |

**Cross-cutting:** Auth in one place (GraphqlController). Error/missing-flag behavior in resolvers and mutations; GraphQL errors array per patterns doc.

### Integration Points

**Internal:** Client → HTTP POST /graphql → GraphqlController (auth) → Schema → QueryType/MutationType → types/mutations → Flag model → PostgreSQL.

**External:** None in MVP. Clients send Bearer token and GraphQL body.

**Data flow:** Request → auth → parse GraphQL → resolve query/mutation → read/write Flag → return JSON (data/errors).

### File Organization Patterns

**Config:** `config/`; env in `config/environments/`; routes in `config/routes.rb`; API key via credentials or ENV.

**Source:** `app/` — controllers, graphql (schema + types + mutations), models. No `app/views` or frontend in MVP.

**Tests:** `test/` mirrors `app/`: `test/controllers/`, `test/graphql/`, `test/models/`. Fixtures in `test/fixtures/` if needed.

**Assets:** Minimal; no frontend bundle for MVP.

### Development Workflow Integration

**Development:** `rails s`; optional GraphiQL at `/graphiql` if not skipped. DB: `rails db:create db:migrate`. Console: `rails c`.

**Build:** No separate build step; Rails serves API. Tests: `rails test` or `bundle exec rspec` if RSpec is added.

**Deployment:** Single process; set `DATABASE_URL` and API key (credentials or ENV); run migrations on deploy.

## Architecture Validation Results

### Coherence Validation

**Decision compatibility:** Rails API, graphql-ruby, PostgreSQL, and Bearer auth are compatible. Single endpoint, one auth point, and no caching keep the design consistent.

**Pattern consistency:** Naming (snake_case DB/Ruby, camelCase GraphQL), structure (app/graphql, app/models, test/), and process (auth at controller, deterministic errors) align with the stack and PRD.

**Structure alignment:** Directory tree supports schema, types, mutations, model, and tests; boundaries and FR→location mapping are clear.

### Requirements Coverage Validation

**Functional requirements:** FR1–FR4 (flag CRUD, persist) → model, migrations, create/update mutations. FR5–FR7 (evaluate, missing-flag) → query type + Flag lookup. FR8–FR9 (auth) → GraphqlController. FR10–FR11 (API contract) → schema + types/mutations. FR12 (README) → README.md. All covered.

**Non-functional requirements:** Performance (evaluate path) → single DB read; no caching required for MVP. Security → Bearer token, credentials/env, HTTPS in production. Reliability → PostgreSQL persistence, single instance. Addressed.

### Implementation Readiness Validation

**Decision completeness:** Stack, data model, auth, API, and infra are documented; starter commands and implementation order are specified.

**Structure completeness:** Project tree lists key files and directories; FR→structure mapping is explicit.

**Pattern completeness:** Naming, structure, format, and process patterns are defined with examples and anti-patterns.

### Gap Analysis Results

**Critical gaps:** None.

**Important gaps:** None. Optional: add RSpec vs minitest choice if desired; graphql-ruby generator may create slightly different filenames (e.g. schema name)—align with generator output when running it.

**Nice-to-have:** Future: caching strategy, rate-limiting placement, and HA topology when scaling.

### Architecture Completeness Checklist

**Requirements analysis:** Project context analyzed; scale (low) and constraints (GraphQL, minimal auth, persistence) identified; cross-cutting concerns (auth, errors, persistence) mapped.

**Architectural decisions:** Critical decisions documented; stack (Rails, GraphQL, PostgreSQL, Bearer) specified; integration pattern (single POST /graphql) defined; performance addressed (simple evaluate path).

**Implementation patterns:** Naming, structure, format, and process patterns established with examples.

**Project structure:** Directory structure and component boundaries defined; integration points and requirements→structure mapping complete.

### Architecture Readiness Assessment

**Overall status:** READY FOR IMPLEMENTATION

**Confidence level:** High — PRD and NFRs are covered; decisions and patterns are consistent; structure is concrete.

**Key strengths:** Single, clear stack; one auth point and one API surface; deterministic missing-flag and error behavior; FR-to-file mapping for implementation and tests.

**Areas for future enhancement:** Caching for evaluate path if needed; rate limiting; multi-account and targeting (post-MVP).

### Implementation Handoff

**AI agent guidelines:**

- Follow this document for all architectural choices.
- Use the implementation patterns (naming, structure, format, process) consistently.
- Respect project structure and boundaries; add tests per the test layout.
- Resolve missing-flag and errors per the patterns section.

**First implementation priority:** Run the starter commands (Rails API + graphql-ruby install), then add the `flags` table and `Flag` model, then implement schema, types, and mutations for create, evaluate, and toggle, then add auth in GraphqlController and README examples.
