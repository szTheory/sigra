---
phase: 30-audit-exploration-and-export
plan: 03
subsystem: audit
tags: [audit, liveview, admin, user-detail, routing]
requires:
  - phase: 30-audit-exploration-and-export
    provides: shared admin audit normalization, explorer service, and impersonation-aware presentation
provides:
  - Global and organization-scoped per-user audit explorer routes
  - Shared subject-user audit history across user detail preview and full explorer
  - Scoped return-context handoff from user detail into full audit investigation
affects: [phase-30-plan-04, admin-user-detail, admin-audit-explorer]
tech-stack:
  added: []
  patterns: [per-user audit liveview over shared explorer service, subject-user preview alignment, scoped return_to handoff]
key-files:
  created:
    - lib/sigra/admin/live/audit_user_live.ex
    - test/example/test/example_web/live/admin_audit_user_live_test.exs
  modified:
    - lib/sigra/admin/audit/explorer.ex
    - lib/sigra/admin/users/detail.ex
    - lib/sigra/admin/live/user_show_live.ex
    - test/example/lib/example_web/router.ex
    - priv/templates/sigra.install/admin/router_injection.ex
    - test/example/test/example_web/live/admin_user_show_live_test.exs
key-decisions:
  - "Per-user org-scoped audit routes intentionally widen only to `organization_scope: {:including_global, org_id}` so the same user's global support rows stay visible without changing org-wide explorer behavior."
  - "Recent Audit on user detail now delegates to the same admin subject-user query contract as the full explorer, closing the old target-only drift."
patterns-established:
  - "Per-user admin audit routes default their back link to the scoped user detail path and only preserve local admin `return_to` values."
  - "User detail preview and full audit investigation share one subject-user evidence model based on `effective_user_id OR target_id`."
requirements-completed: [AUD-02, AUD-03]
duration: 2 min
completed: 2026-04-17
---

# Phase 30 Plan 03: Audit Exploration and Export Summary

**Per-user admin audit history now works in global and organization scopes, and the user-detail preview matches the same subject-user evidence model as the full explorer**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-17T01:31:27Z
- **Completed:** 2026-04-17T01:33:46Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added RED coverage for global and organization per-user audit routes, preview alignment, and the user-detail handoff into full audit.
- Implemented `Sigra.Admin.Live.AuditUserLive` and routed it under both `/admin/users/:id/audit` and `/admin/organizations/:org/users/:id/audit`.
- Aligned `Recent Audit` on the user detail page with the shared subject-user query contract and added an explicit scoped `View full audit` entry point.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add example tests for per-user audit routes and preview alignment** - `542e9c6` (test)
2. **Task 2: Implement per-user audit explorer routes and align the Phase 28 preview to the shared subject-user query contract** - `93854e2` (feat)

## Files Created/Modified
- `lib/sigra/admin/live/audit_user_live.ex` - New per-user audit LiveView that preserves scoped return context and reuses the shared explorer service.
- `lib/sigra/admin/audit/explorer.ex` - Added a subject-user listing path and org-scope override for per-user views.
- `lib/sigra/admin/users/detail.ex` - Switched recent-audit preview from `target_id` filtering to the shared admin subject-user contract.
- `lib/sigra/admin/live/user_show_live.ex` - Added the explicit `View full audit` handoff from the Recent Audit section.
- `test/example/lib/example_web/router.ex` - Mounted per-user audit routes for both global and organization admin paths.
- `priv/templates/sigra.install/admin/router_injection.ex` - Kept generated router wiring in parity with the example app.
- `test/example/test/example_web/live/admin_audit_user_live_test.exs` - Covers per-user global/org route loading, filter persistence, and org-scoped inclusion of global support rows.
- `test/example/test/example_web/live/admin_user_show_live_test.exs` - Covers preview alignment and scoped full-audit links from user detail.

## Decisions Made
- Kept the per-user explorer on top of `Sigra.Admin.Audit.Explorer` instead of creating a detail-only audit query path, so preview and full investigation continue to share one filter model.
- Preserved the Phase 28 continuity rule for org-scoped user investigation by widening only per-user org routes to `{:including_global, org_id}` while leaving org-wide explorer pages unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a deprecation warning from the new filter merge path**
- **Found during:** Task 2 (Implement per-user audit explorer routes and align the Phase 28 preview to the shared subject-user query contract)
- **Issue:** The first implementation merged explorer filters into a non-empty keyword list with `Enum.into/2`, which raised an Elixir 1.19 Collectable deprecation warning during the focused suite.
- **Fix:** Replaced the merge with `Keyword.merge/2` over `Map.to_list/1` output in `Sigra.Admin.Audit.Explorer`.
- **Files modified:** `lib/sigra/admin/audit/explorer.ex`
- **Verification:** `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/live/admin_audit_user_live_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1`
- **Committed in:** `93854e2`

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** The fix kept the new explorer path warning-free without changing the planned behavior or widening scope.

## Issues Encountered
- The example-app suite must be run from `test/example`; invoking those files from the repo root fails before hitting the actual RED condition.
- Shared git index contention in the dirty worktree caused intermittent `.git/index.lock` staging failures, so the plan finished with serial staging/commit steps.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 30 plan 04 can export the per-user, global, and organization slices through the same normalized explorer filters without reworking route semantics.
- The per-user audit routes now provide the stable, scoped URLs the CSV export layer should mirror.

## Self-Check: PASSED

---
*Phase: 30-audit-exploration-and-export*
*Completed: 2026-04-17*
