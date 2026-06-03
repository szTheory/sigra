# Architecture Patterns

**Domain:** Open Source Authentication Library Maintenance (Post-1.0)
**Researched:** 2026-06-01

## Recommended Architecture

The core architecture for Sigra is settled: **Hybrid Lib+Generator**. The post-1.0 posture focuses on *defending* this architecture against feature creep and maintaining clear boundaries.

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| Core Library | Security logic, token validation, audit invariants | Database (via Ecto), Generated Host Code |
| Generated Host Code | UI, controllers, mailer templates, domain logic | Core Library, Web Client |
| Adapters/Seams | Abstracting third-party integrations (Email, Audit) | Companion libraries (Mailglass, Threadline) |

## Patterns to Follow

### Pattern 1: Adapter/Seam-First Integration
**What:** Providing a `@behaviour` or configurable module rather than hardcoding integrations.
**When:** When a user requests integration with a specific third-party service (e.g., a new email provider or logging system).
**Example:**
Instead of building a `Mailchimp` adapter into Sigra core, ensure `Sigra.Mailer` can be implemented by the host application to use whatever provider they choose.

### Pattern 2: Explicit Deprecation Cycles
**What:** Marking functions with `@deprecated` and providing a clear timeline (e.g., "Will be removed in v2.0").
**When:** When refactoring APIs or fixing design flaws in the core library.
**Why:** Post-1.0 means semantic versioning is law. No breaking changes without a major version bump.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Leaking Domain Logic into Core
**What:** Adding fields to `users` or `organizations` in the library migrations that are specific to a subset of SaaS apps (e.g., `stripe_customer_id`).
**Why bad:** Bloats the library and violates the boundaries of the hybrid architecture.
**Instead:** Rely on the host application to extend the generated schemas or associate new tables with the `user_id`.

### Anti-Pattern 2: Generator Breaking Changes
**What:** Updating `mix sigra.install` to output significantly different templates without a migration path.
**Why bad:** Existing users who have customized their templates cannot upgrade easily.
**Instead:** Clearly document changes, use non-destructive updates where possible, and provide "boundary-first" migration guides.

## Scalability Considerations

| Concern | Maintenance Workload | Contributor Scaling | Release Confidence |
|---------|----------------------|---------------------|--------------------|
| Issue Management | Triage cadence to prevent backlog | Tag issues "good first issue" | Maintain a zero-bug policy for security |
| Dependency Updates | Dependabot | Automate PR merges | Rely on strict CI gates |

## Sources

- Open source maintenance best practices.
- `PROJECT.md`