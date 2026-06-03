---
phase: 30-audit-exploration-and-export
plan: 01
subsystem: audit
tags: [audit, admin, ecto, liveview-contracts, csv-contracts]
requires:
  - phase: 29-secure-impersonation
    provides: canonical dual-actor audit fields via impersonation-aware scope handling
provides:
  - Correct admin session-revocation audit attribution at the auth seam
  - Shared admin audit query wrapper with subject-user semantics
  - Whitelist-first normalized filter contract for future explorer and export routes
affects: [admin-audit-explorer, admin-audit-export, phase-30-plan-02, phase-30-plan-03, phase-30-plan-04]
tech-stack:
  added: []
  patterns: [admin-owned audit query wrapper, whitelist-first audit param normalization, canonical dual-actor attribution through existing auth APIs]
key-files:
  created:
    - lib/sigra/admin/audit/query.ex
    - lib/sigra/admin/audit/query_params.ex
    - test/sigra/admin/audit/query_test.exs
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/admin/users/actions.ex
    - test/sigra/admin/users_actions_test.exs
key-decisions:
  - "Kept admin audit semantics additive by wrapping Sigra.Audit.Query instead of extending the lower-level filter builder."
  - "Preserved canonical attribution by threading explicit actor_id, effective_user_id, target_id, and audit_scope through the existing Sigra.Auth session APIs."
patterns-established:
  - "Admin audit normalization returns one shared map for explorer and export callers, including decoded cursor tuples and a resolved limit."
  - "Per-user admin audit history is expressed as effective_user_id OR target_id in an admin-owned wrapper, not by overloading target_id semantics globally."
requirements-completed: [AUD-01, AUD-02]
duration: 4 min
completed: 2026-04-17
---

# Phase 30 Plan 01: Audit Exploration and Export Summary

**Admin session revocations now retain real actor attribution, and future audit explorer/export routes share one normalized query contract with subject-user semantics**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-17T01:14:00Z
- **Completed:** 2026-04-17T01:18:06Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added direct-path regression coverage for admin revoke attribution and the Phase 30 audit query contract.
- Implemented `Sigra.Admin.Audit.Query` as the admin-owned wrapper over the canonical audit query builder and keyset pagination.
- Implemented `Sigra.Admin.Audit.QueryParams` so explorer and export routes can consume the same validated filter map.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add direct-path tests for canonical admin audit attribution and normalized query params** - `b65a1d8` (test)
2. **Task 2: Implement the shared admin audit query seam and close the admin support-action attribution gap** - `bfa95eb` (feat)

## Files Created/Modified
- `lib/sigra/auth.ex` - Accepts explicit audit attribution fields and an optional audit scope for session deletion flows.
- `lib/sigra/admin/users/actions.ex` - Passes real admin actor, target user, effective user, and scoped audit context through revoke flows.
- `lib/sigra/admin/audit/query.ex` - Wraps `Sigra.Audit.Query` and adds subject-user filtering without changing the lower-level builder.
- `lib/sigra/admin/audit/query_params.ex` - Normalizes allowed audit filters, decodes cursors, validates page size, and resolves org scope.
- `test/sigra/admin/users_actions_test.exs` - Pins the corrected dual-actor revoke attribution contract.
- `test/sigra/admin/audit/query_test.exs` - Pins shared filter normalization and subject-user query behavior.

## Decisions Made
- Kept the lower-level audit query contract unchanged and put subject-user semantics in an admin-owned wrapper so later explorer surfaces can reuse canonical filters without drift.
- Reused `Sigra.Auth.delete_session/3` and `delete_all_sessions/3` by extending their audit opts handling, which preserved the existing session/audit pipeline instead of adding a second admin-only path.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The local Postgres test database `sigra_test` did not exist. Created it with `createdb -h localhost -U postgres sigra_test` so the targeted `Sigra.Test.PostgresRepo` suite could run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 30 plans 02-04 can build explorer and export surfaces directly on `Sigra.Admin.Audit.Query` and `Sigra.Admin.Audit.QueryParams`.
- The Phase 28 recent-audit preview can be aligned later against the same subject-user semantics without reopening the lower-level audit query builder.

## Self-Check: PASSED

---
*Phase: 30-audit-exploration-and-export*
*Completed: 2026-04-17*
