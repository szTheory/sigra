---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Cleanup & Hardening
status: active
stopped_at: Phase 39 executed — `39-01`..`39-03` SUMMARY + `39-VERIFICATION.md`; library + example audit work landed; next milestone phase **40** or `/gsd-progress`
last_updated: "2026-04-19T01:05:00.000Z"
last_activity: 2026-04-19 -- Phase 39 execute-phase completed inline (Assertions, atomic api.token_create, example smoke + docs)
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 4
  completed_plans: 4
  percent: 60
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-17)

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Current focus:** **v1.3 Cleanup & Hardening** — Phases 36–40 per `REQUIREMENTS.md` / `ROADMAP.md` (999.x + seeds + tooling; no feature work).

## Current Position

Phase: **39** (Audit trail completeness) — **executed** (`39-VERIFICATION.md` **passed**); implementation: `Sigra.Audit.Assertions`, atomic `api.token_create`, example login/MFA audit smoke, docs trio + `docs/audit-semantics.md`.
Plans: Phase **38** complete on disk — `38-01-SUMMARY.md`, `38-02-SUMMARY.md`, `38-VERIFICATION.md`; UAT-01/UAT-02 checked; machine closure documented in `v1.3-HUMAN-UAT.md` + `docs/uat-ci-coverage.md`.
Phases **36–39** on disk: phase **39** adds `39-01`..`39-03` **SUMMARY** + verifier artifact.
Last activity: 2026-04-19 -- Phase 39 execution + verification written.

Progress: [████████░░] 80% (4/5 v1.3 phases with execution complete for **36–39**); **next focus:** Phase **40** (tooling & release ergonomics) or `/gsd-progress`.

### v1.3 kickoff

- `REQUIREMENTS.md` — REQ-IDs VAL / CI / UAT / AUD / TOOL / REL mapped to Phases 36–40 (**VAL-01..03** checked when satisfied)
- `ROADMAP.md` — “Next milestone” table is the live phase list until v1.3 archives

## Performance Metrics

**Velocity (v1.3):**

- Total plans completed: 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 36–40 | — | — | — |

**Recent Trend:** v1.3 not started — metrics populate as plans land.

_v1.2 execution timings retained in git history / milestone archive if needed._

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
- [Phase 39 context]: AUD-01 — plain-function audit test helpers with partial-field asserts and explicit `repo`; optional host `DataCase` snippet for Sandbox. AUD-02 — **`Sigra.APIToken` `do_create/4`** as first `Ecto.Multi` + `__log_internal__` conversion (fallback: bounded phased plan). AUD-03 — audit-aware integration tests for **token create**, **login/lockout**, **MFA or OAuth link** (planner picks third if cost differs). Docs — anchor C-1 story in **`REQUIREMENTS.md` + `CHANGELOG` + SEED-002**; optional `docs/audit-semantics.md`.

### Pending Todos

None yet.

### Blockers/Concerns

- None. gsd-sdk `query init.new-milestone` unavailable in this environment — planning updated manually.

## Deferred Items

| Category | Item | Status | Notes |
|----------|------|--------|-------|
| — | (empty) | — | **999.x**, **SEED-001**, **SEED-002** promoted into v1.3 Phases 36–39 |

## Session Continuity

Last session: 2026-04-18T18:30:00.000Z
Stopped at: Phase **39** planned — run **`/gsd-execute-phase 39`**
Resume file: `.planning/phases/39-audit-trail-completeness/39-01-PLAN.md`
