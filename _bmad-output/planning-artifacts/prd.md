---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish']
inputDocuments: ['product-brief-feature-flag-service-2025-02-04.md']
workflowType: 'prd'
briefCount: 1
researchCount: 0
brainstormingCount: 0
projectDocsCount: 0
classification:
  projectType: api_backend
  domain: general
  complexity: low
  projectContext: greenfield
---

# Product Requirements Document - feature-flag-service

**Author:** Steve  
**Date:** 2025-02-04

## Executive Summary

Feature-flag-service is a developer-focused, GraphQL-only API for creating and evaluating feature flags. MVP delivers the core loop—create flag, evaluate flag, toggle for rollback—with minimal auth and no UI. Target users are developers (and, post-MVP, PMs) who want gradual rollouts and instant rollback. Differentiator: open, self-hosted, Rails-based, with a complete evaluation API from day one.

## Success Criteria

### User Success

- **Core workflow works** — Developers can create a flag via GraphQL and evaluate it; the end-to-end loop works.
- **"It works" moment** — The service runs, responds via GraphQL, and supports create + evaluate without major friction.

### Business Success

*N/A — For-fun, capability-demonstration project. Primary objective is personal: building a complete, working feature flag service.*

### Technical Success

- **Functional** — Create-flag and evaluate-flag operations work via GraphQL.
- **Operational** — Service runs with measurable low latency and high availability (targets can be set later).

### Measurable Outcomes

- **Completion** — MVP shipped: GraphQL API, create flag, evaluate flag.
- **Personal** — "I built it" — end-to-end flow demonstrates the capability.

## Product Scope

### MVP - Minimum Viable Product

- **GraphQL API** — Single interface for all operations.
- **Create flag** — Define and persist a new feature flag.
- **Evaluate flag** — Return flag status for a given context (single evaluation).

*MVP validates: create a flag via GraphQL → evaluate it via GraphQL.*

### Growth Features (Post-MVP)

- **Bulk operations** — Create and evaluate flags in bulk.
- **Targeting rules** — User/segment-based rollout logic.
- **Multi-account security** — Accounts, teams, isolation.

### Vision (Future)

- **UI** — Dashboard for viewing/managing flags and rollout status.
- **Docs** — User guides, API reference, examples.
- **Integrations** — Third-party tools, webhooks, observability.
- **Other SDKs** — Ruby, JavaScript, Python, etc., for easier integration.

## User Journeys

### Developer — Success path (core experience)

**Opening:** A developer is about to ship a new checkout flow. They don’t want to risk a big-bang release. They need a flag so they can turn it off instantly if something breaks.

**Rising action:** They call the GraphQL API to create a flag (e.g. `new_checkout`). They get back a stable identifier. They add an evaluate call in their app (passing flag key and optional context). The app gets on/off (or variant). They deploy. The flag is off by default; they turn it on for internal testing, then gradually for a percentage of users.

**Climax:** A bug appears in production. Instead of rolling back code, they turn the flag off via GraphQL. Traffic reverts to the old flow within seconds. No redeploy, no delay.

**Resolution:** Rollouts and rollbacks become routine. They rely on the service for every risky change.

### Developer — Edge case (error recovery)

**Opening:** The same developer evaluates a flag they haven’t created yet, or mistypes the flag key.

**Rising action:** The evaluate query runs. The service doesn’t find the flag (or returns a clear error).

**Climax:** The API returns a deterministic, safe result (e.g. “off” or an explicit error/code) so the app doesn’t crash. The developer sees the error in logs or response and fixes the key or creates the flag.

**Resolution:** Clear contract for “missing flag” and errors so the developer can handle them and the app degrades gracefully.

### API consumer / integrating system

**Opening:** Another service or script needs to know if a feature is on (e.g. for a cron job or backend workflow).

**Rising action:** It sends a GraphQL evaluate request (flag key + context if needed). No browser, no UI—just an API client.

**Climax:** It gets a simple on/off (or structured result) and branches logic accordingly. Create and evaluate are both available so the same system can create flags and evaluate them.

**Resolution:** Any system that can call GraphQL can use the feature-flag service with the same contract as the developer.

### PM (future — when UI exists)

**Deferred for post-MVP.** When a UI exists, a PM’s journey will include viewing flag status, rollout progress, and requesting or coordinating rollouts. Out of scope for the current PRD.

---

### Journey Requirements Summary

- **Create flag** — GraphQL mutation; returns stable flag identifier; supports the “create then use” flow.
- **Evaluate flag** — GraphQL query; accepts flag key and optional context; returns on/off (or defined shape); deterministic behavior for missing/invalid flag.
- **Error handling** — Clear, safe behavior and responses so apps and scripts can handle errors and missing flags without breaking.
- **API-first** — All interactions via GraphQL; no UI required for MVP; same contract for humans and integrating systems.

## API Backend Specific Requirements

### Project-Type Overview

Feature-flag-service is an API backend: a GraphQL-only service for creating and evaluating feature flags. No REST endpoints; all operations are mutations (create) and queries (evaluate). MVP is API-first with no UI, SDKs, or docs beyond inline/README.

### Technical Architecture Considerations

- **Single interface** — GraphQL only; no REST.
- **Storage** — Persistent store for flags (e.g. relational DB); schema supports flag key, optional metadata, and evaluation state (on/off).
- **Low latency / HA** — Design for fast evaluate path (e.g. caching, simple resolution); HA deferred post-MVP but architecture should not block it.

### Endpoint / Operation Specs

- **Create flag** — GraphQL mutation; input: flag key (required), optional description/metadata; output: created flag (id, key, state). Idempotent behavior for same key (create-or-return-existing or clear error).
- **Evaluate flag** — GraphQL query; input: flag key, optional context (e.g. user id, attributes); output: result (e.g. enabled: boolean or variant). Deterministic behavior for unknown/missing flag (e.g. return disabled or explicit error).
- **Toggle / update flag** — Mutation to set flag on/off; required for the "turn off in production" journey.

### Authentication Model

- **MVP:** Minimal — single API key or bearer token; all callers use the same credential. No multi-account or RBAC.
- **Post-MVP:** Multi-account, credentials, and scoping as per product scope.

### Data Schemas

- **Request/response:** GraphQL schema; types for Flag (id, key, description?, enabled), EvaluationContext (optional), EvaluationResult (enabled or variant).
- **Persistence:** Flags stored by key (unique); at least key and enabled state; optional metadata for future targeting.

### Error Codes / Behavior

- **Unknown/missing flag on evaluate** — Deterministic: return disabled or structured error (e.g. FLAG_NOT_FOUND) so clients can degrade gracefully.
- **Invalid input** — Validation errors with clear GraphQL errors/messages.
- **Server errors** — Standard 5xx semantics.

### Rate Limits

- **MVP:** None. Rate limiting to be added later; document as future work.

### API Documentation

- **MVP:** No formal API docs; inline code comments and README with example GraphQL operations (create, evaluate, toggle).

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP — smallest set that proves the core loop: create a flag, evaluate it, toggle it for rollback. No UI, docs, or SDKs; GraphQL only with minimal auth.

**Resource Requirements:** Solo or small team; Rails + GraphQL experience. No formal team-size requirement; for-fun / capability demo.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Developer success path (create → evaluate → toggle for rollback)
- Developer edge case (missing flag → deterministic safe response)
- API consumer (same GraphQL contract)

**Must-Have Capabilities:**
- GraphQL API with create-flag mutation, evaluate-flag query, toggle/update-flag mutation
- Persistent storage for flags (key, enabled state, optional metadata)
- Minimal authentication (e.g. single API key / bearer token)
- Deterministic behavior for unknown/missing flag on evaluate
- README with example operations

### Post-MVP Features

**Phase 2 (Growth):**
- Bulk create and bulk evaluate
- Targeting rules (user/segment-based)
- Multi-account security (accounts, teams, isolation)
- Rate limiting (documented as "add later" in API requirements)

**Phase 3 (Expansion):**
- UI (dashboard, rollout status)
- Docs (guides, API reference, examples)
- Integrations (webhooks, observability)
- Other SDKs (Ruby, JavaScript, Python, etc.)
- API versioning (if needed)

### Risk Mitigation Strategy

**Technical:** Keep MVP to a single stack (Rails + DB + GraphQL); defer caching/HA until after the loop works. **Market:** N/A (for-fun). **Resource:** Scope is already minimal; cut only by dropping toggle (but that would break the rollback journey).

## Functional Requirements

*This section defines the capability contract for the product. Capabilities not listed here are out of scope unless explicitly added.*

### Flag Management

- FR1: A caller can create a feature flag by providing a unique key and optional metadata.
- FR2: A caller can retrieve a flag's current state (e.g. enabled/disabled) by key.
- FR3: A caller can update a flag's state (toggle on/off) for rollback or rollout.
- FR4: The system persists flags so they survive restarts and can be evaluated later.

### Flag Evaluation

- FR5: A caller can evaluate a single flag by key and receive an enabled/disabled (or equivalent) result.
- FR6: A caller can optionally provide context (e.g. user id, attributes) when evaluating a flag.
- FR7: When a flag does not exist or the key is invalid, the system returns a deterministic, safe result (e.g. disabled or explicit error) so callers can degrade gracefully.

### Authentication & Access

- FR8: A caller must supply valid minimal credentials (e.g. API key or bearer token) to perform create, evaluate, or update operations.
- FR9: Requests without valid credentials are rejected with a clear, standard error.

### API Contract

- FR10: All flag operations are available via a single, documented interface (GraphQL in MVP).
- FR11: The system exposes a way to create flags, evaluate flags, and update flag state through that interface.

### Operational Visibility

- FR12: The system provides enough information (e.g. README, example operations) for a developer to create a flag, evaluate it, and toggle it without additional documentation.

## Non-Functional Requirements

### Performance

- NFR1: Evaluate-flag operations complete within a defined response-time budget (e.g. p95 under 200 ms or similar target to be set at implementation) so callers can use the result in request-time decisions.
- NFR2: Create and update operations complete within a reasonable time; no strict SLA for MVP beyond "responsive under normal load."

### Security

- NFR3: Credentials (API key or bearer token) are transmitted and stored in a way that avoids plaintext exposure (e.g. HTTPS, secure storage).
- NFR4: Only requests presenting valid credentials can perform create, evaluate, or update operations; unauthorized requests receive a clear, non-revealing error.

### Reliability

- NFR5: The service runs in a way that allows it to be available for evaluation and updates under normal operation (e.g. single instance, no formal SLA for MVP).
- NFR6: Flag state is persisted so that a restart does not lose existing flags or their on/off state.
