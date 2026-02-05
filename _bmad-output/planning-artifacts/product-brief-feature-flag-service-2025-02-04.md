---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments: []
date: 2025-02-04
author: Steve
---

# Product Brief: feature-flag-service

## Executive Summary

**feature-flag-service** is a developer-focused, open-source feature flag platform built with Ruby on Rails and GraphQL—*the feature flag service a developer would build for themselves*. It targets Rails + GraphQL developers who want to create, manage, and evaluate feature flags across runtime applications, local development, CI/CD pipelines, and debugging dashboards. Designed for high availability and low latency, it offers a **complete evaluation API from day one**: single-flag checks, bulk evaluation, and targeting rules—with multi-account security for teams and organizations. Open, inspectable, and self-hosted—no vendor lock-in.

---

## Core Vision

### Problem Statement

Developers need a feature flag service that is transparent, self-hosted, and covers the full evaluation surface—single checks, bulk evaluation, and targeting rules—across all contexts where flags matter: runtime in applications, local development, CI/CD, and dashboards. Existing commercial solutions are often opaque, costly, or overkill for teams who want control and simplicity. There is a gap for an open, approachable feature flag service that developers can run themselves, understand fully, and contribute to.

### Problem Impact

Without a straightforward, self-hosted option, developers either lock into commercial vendors, build ad-hoc solutions that lack consistency, or avoid feature flags altogether—missing out on safer deployments, gradual rollouts, and experimentation. Teams sacrifice transparency and control for convenience.

### Why Existing Solutions Fall Short

- **Commercial platforms** are powerful but proprietary, expensive, and opaque—hard to reason about and customize.
- **Generic open-source options** often lack bulk evaluation, GraphQL APIs, or production-grade HA/low-latency design.
- **DIY solutions** tend to be inconsistent across contexts (runtime vs. CI vs. local) and rarely cover the full evaluation surface.

### Proposed Solution

A Ruby on Rails application that serves feature flag status via GraphQL. The API supports:

- **Create flags** — define and manage flags with targeting rules
- **Evaluate flags** — single-flag and bulk evaluation with context (user, attributes, etc.)
- **Bulk operations** — create and evaluate flags in bulk for efficiency
- **Multi-account security** — accounts and isolation for teams and organizations
- **High availability & low latency** — production-ready operational characteristics

The service is designed for use in runtime apps, local dev, CI/CD, and dashboards—one consistent API across all contexts.

### Key Differentiators

- **Open and self-hosted** — full control, no vendor lock-in, inspectable codebase
- **GraphQL-native** — flexible queries, bulk evaluation in a single request, strong typing
- **Rails foundation** — familiar stack for many developers, easy to extend and contribute
- **Complete evaluation API from day one** — single checks, bulk evaluation, and targeting rules in one place
- **Production-quality** — HA and low latency built in from the start

---

## Target Users

### Primary Users

**Developers** who want to gradually roll out new features and roll back easily. They create and manage feature flags, wire evaluation into their applications (runtime, local dev, CI/CD), and rely on the service for safe deployments and quick rollbacks. They value simplicity, transparency, and control—preferring a self-hosted, inspectable solution over opaque commercial platforms.

### Secondary Users

**Product Managers** who may use the service to view flag status, request or coordinate feature rollouts, or monitor experiment/launch progress. Their usage is complementary to developers—they benefit from visibility and coordination rather than direct flag creation or evaluation.

### User Journey

- **Discovery:** Developers or PMs learn about the tool via open-source channels, team recommendations, or Rails/GraphQL communities.
- **Onboarding:** Set up the service (self-hosted), create an account, define initial flags via GraphQL or UI.
- **Core Usage:** Developers create flags, evaluate in apps; PMs check status and coordinate rollouts. Rollback is a core daily workflow.
- **Success Moment:** First incident resolved by turning off a flag instead of redeploying; or first gradual rollout completed without incident.
- **Long-term:** Feature flags become standard practice for releases—gradual rollouts and instant rollback are the default.

---

## Success Metrics

### User Success

- **Core workflow works** — Developers can create flags, evaluate them (single and bulk), and roll back by toggling—end to end.
- **"It works" moment** — The service runs, responds via GraphQL, and supports the main use cases without major friction.

### Business Objectives

*N/A — This is a for-fun, capability-demonstration project. The primary objective is personal: building a complete, working feature flag service.*

### Key Performance Indicators

- **Completion** — Core features shipped: create flags, evaluate flags (single + bulk), targeting rules, multi-account security.
- **Operational** — Service meets stated non-functionals: measurable low latency and high availability (e.g., p99 latency, uptime).
- **Personal** — "I built it" — the project is complete enough to demonstrate the capability.

---

## MVP Scope

### Core Features

- **GraphQL API** — Primary interface for all operations
- **Create flag** — Define and persist a new feature flag
- **Evaluate flag** — Check flag status for a given context (single evaluation)

*MVP validates the core loop: create a flag via GraphQL, evaluate it via GraphQL.*

### Out of Scope for MVP

- UI (dashboard, admin interface)
- Documentation (beyond inline/README)
- Integrations (LaunchDarkly, analytics, etc.)
- Other SDKs (client libraries beyond GraphQL)

### MVP Success Criteria

- Can create a flag via GraphQL mutation
- Can evaluate a flag via GraphQL query
- Service runs and responds with low latency
- "I built it" — end-to-end flow works

### Future Vision

- **UI** — Dashboard for viewing/managing flags, rollout status
- **Docs** — User guides, API reference, examples
- **Integrations** — Third-party tools, webhooks, observability
- **Other SDKs** — Ruby, JavaScript, Python, etc. for easier integration
- **Bulk operations** — Create and evaluate flags in bulk
- **Targeting rules** — User/segment-based rollout logic
- **Multi-account security** — Accounts, teams, isolation
