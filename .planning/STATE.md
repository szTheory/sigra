---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Admin Dashboard
status: planning
stopped_at: Completed 29-05-PLAN.md
last_updated: "2026-04-17T00:51:18.079Z"
last_activity: 2026-04-17
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 12
  completed_plans: 15
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-16)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Current focus:** Phase 30 — audit-exploration-and-export

## Current Position

Phase: 30
Plan: Not started
Status: Ready to plan
Last activity: 2026-04-17

Progress: [██████████] 100% (5/5 plans complete)

## Performance Metrics

**Velocity:**

- Total plans completed: 10 in v1.2
- Average duration: -
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 27-31 | 0 | 0 | - |
| 29 | 5 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: Not enough data

| Phase 27 P1 | 4 min | 2 tasks | 9 files |
| Phase 27 P2 | 4 min | 3 tasks | 8 files |
| Phase 27 P3 | 8 min | 2 tasks | 12 files |
| Phase 28 P1 | 5min | 3 tasks | 15 files |
| Phase 28 P2 | 34 min | 2 tasks | 9 files |
| Phase 28 P3 | 7min | 2 tasks | 6 files |
| Phase 29 P04 | 44min | 2 tasks | 10 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v1.2 starts at Phase 27 to continue after the Phase 24-26 closeout work rather than resetting milestone numbering.
- v1.2 is grouped into five delivery phases: admin access foundation, user operations, secure impersonation, audit exploration/export, and automation-first verification.
- The milestone remains auth-first on Phoenix/LiveView; no separate SPA stack or generic admin framework is introduced.
- Verification artifacts are milestone scope, not release hardening after feature work.
- [Phase 27]: Admin is a first-class installer feature enabled by default and omitted only via --no-admin.
- [Phase 27]: The generated host app owns only the admin policy module and shell component; long-lived runtime stays library-owned.
- [Phase 27]: Admin router wiring uses normal Phoenix scopes and live_session blocks rather than forward.
- [Phase 27]: Admin route intent resolves into a library-owned Sigra.Admin.Scope that distinguishes :global from :organization access.
- [Phase 27]: Denied global admin access uses insufficient_scope, while unknown or out-of-scope organization routes collapse to not_found.
- [Phase 27]: Direct-path admin queries must scope organization access through Sigra.Organizations.Query.for_org/2.
- [Phase 27]: Example admin routes mount through dedicated global and organization live_session blocks with library-owned admin scope resolution.
- [Phase 27]: ExampleWeb.Layouts.admin is the host-owned shell seam and keeps Admin plus the active global or organization scope visible across admin pages.
- [Phase 27]: Example.SigraAdminPolicy uses explicit fixture-backed email prefixes for platform-admin and org-admin tests instead of bootstrap inference.
- [Phase 28]: Resolved admin user hooks from the configured accounts module when present, otherwise by deriving the accounts context from config.user_schema.
- [Phase 28]: Kept the Phase 28 hook contract read-only and data-returning so host hooks cannot mutate scoped queries or bypass authorization.
- [Phase 28]: Created skipped Wave 0 contract tests now so later plans turn named scenarios green instead of inventing surface requirements late.
- [Phase 28]: The admin user list stays URL-driven through handle_params/3 and carries return_to state forward in rendered Open user links.
- [Phase 28]: Organization membership lookup is constrained to the active admin scope so org routes cannot pivot into other organization memberships.
- [Phase 28]: Kept the user detail loader library-owned and scope-safe so both global and organization routes resolve the same target data contract.
- [Phase 28]: Reused Sigra.Auth revoke APIs for revoke-one and revoke-all so audit logging and disconnect side effects remain centralized.
- [Phase 28]: Preserved the global detail lens while making organization pivots explicit in link copy and destination URLs.
- [Phase 29]: Impersonation start, stop, and timeout evaluation stay library-owned and reuse real Sigra session primitives.
- [Phase 29]: Dual-actor attribution flows through `scope.impersonating_from` so `Sigra.Audit.scope_fields/1` remains the canonical assembly point.
- [Phase 29]: The web layer preserves the original admin session token in Plug session keys and restores it through `UserAuth` rather than separate impersonation persistence.
- [Phase 29]: Impersonation stop lives at `/impersonation` outside admin-only scopes so persistent chrome can end impersonation from any authenticated page.
- [Phase 29]: The example app keeps the sudo redirect local to impersonation start and reuses `/users/sudo?return_to=...` without widening shared auth error handling.
- [Phase 29]: The user detail danger zone is the single impersonation entry point; host-owned chrome only renders explicit state plus the app-wide stop action.
- [Phase 29]: LiveView `mount_current_scope` must preserve `impersonating_from` from the saved admin token so connected pages keep the same impersonation banner contract as controller renders.
- [Phase 29]: The controller boundary uses a reusable plug, while LiveView handlers fail closed through explicit impersonation checks and Accounts scope guards.
- [Phase 29]: Denied sensitive operations reuse the existing audit pipeline with admin.impersonation.denied rows instead of a separate logging path.
- [Phase 29]: Generated API-token mutations now guard the wrapper seam directly and translate impersonation-forbidden tuples into explicit 403 JSON responses.

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 27 planning needs to lock the smallest host-owned admin policy contract that covers platform-admin and org-admin access cleanly.
- Phase 29 planning needs careful timeout and return-context handling because impersonation semantics are security-critical.
- Phase 31 must preserve the milestone's automation-first intent with mobile and dark-mode artifact gates, not just happy-path browser tests.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Seed | SEED-001 human-only GA UAT items | Deferred | v1.1 closeout |
| Seed | SEED-002 atomic audit conversion follow-up | Deferred | v1.1 closeout |
| Backlog | Phase 999.1 Nyquist retroactive validation pass | Deferred | v1.1 closeout |
| Backlog | Phase 999.2 Dependabot major-version cleanup | Deferred | v1.1 closeout |

## Session Continuity

Last session: 2026-04-17T00:22:28.516Z
Stopped at: Completed 29-05-PLAN.md
Resume file: None
