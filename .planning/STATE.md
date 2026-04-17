---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Admin Dashboard
status: executing
stopped_at: Phase 33 context gathered
last_updated: "2026-04-17T15:45:10.806Z"
last_activity: 2026-04-17 -- Phase 33 planning complete
progress:
  total_phases: 9
  completed_phases: 6
  total_plans: 24
  completed_plans: 25
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-16)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Current focus:** Phase 32 — generated-installer-admin-surface-parity

## Current Position

Phase: 33
Plan: Not started
Status: Ready to execute
Last activity: 2026-04-17 -- Phase 33 planning complete

Progress: [██████████] 100% (4/4 Phase 31 plans complete)

### Phase 31 artifacts

- 4 plans complete (31-01, 31-02, 31-03, 31-04)
- `31-REVIEW.md` — 0 critical, 4 warnings, 6 info (advisory)
- `31-VERIFICATION.md` — 4/4 must-haves verified, 1 human-verification item (reviewer usefulness of admin artifact bundle — inherently non-automatable)

## Performance Metrics

**Velocity:**

- Total plans completed: 16 in v1.2
- Average duration: -
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 27-31 | 0 | 0 | - |
| 29 | 5 | - | - |
| 30 | 4 | - | - |
| 32 | 2 | - | - |

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
| Phase 30 P01 | 4 min | 2 tasks | 6 files |
| Phase 30 P02 | 9 min | 2 tasks | 9 files |
| Phase 30 P03 | 2 min | 2 tasks | 8 files |
| Phase 30 P04 | 8 min | 2 tasks | 12 files |

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
- [Phase 30]: Kept subject-user semantics in Sigra.Admin.Audit.Query so later audit surfaces reuse the canonical lower-level filter builder unchanged.
- [Phase 30]: Extended Sigra.Auth session revoke audit opts for explicit actor, effective user, target, and scope instead of creating an admin-only audit path.
- [Phase 30]: Kept audit filtering on the existing order_by and order_direction query-string pattern instead of inventing a second sort contract for admin list surfaces.
- [Phase 30]: Returned an empty organization-scoped audit view for out-of-scope organization filter params so the route stays fail-closed without widening into cross-org data.
- [Phase 30]: Per-user org-scoped audit routes intentionally widen only to organization_scope {:including_global, org_id} so the same user's global support rows stay visible without changing org-wide explorer behavior.
- [Phase 30]: Recent Audit on user detail now delegates to the same admin subject-user query contract as the full explorer, closing the old target-only drift.
- [Phase 30]: Kept audit CSV export on the same normalized query-param contract as the explorer routes.
- [Phase 30]: Used explicit apostrophe prefix escaping plus CSV quoting for dangerous spreadsheet prefixes instead of a new dependency.
- [Phase 30]: Mounted GET export endpoints beside global, organization, and per-user explorer routes so evidence URLs stay reproducible.

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

Last session: 2026-04-17T15:19:05.805Z
Stopped at: Phase 33 context gathered
Resume file: .planning/phases/33-admin-shell-navigation-and-audit-preview-polish/33-CONTEXT.md
