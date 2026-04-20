---
phase: 27-admin-access-foundation
plan: 3
subsystem: ui
tags: [admin, liveview, phoenix, example-app, routing]
requires:
  - phase: 27-admin-access-foundation
    provides: library-owned admin scope enforcement and host policy contract
provides:
  - example-app admin router mounts for global and organization scopes
  - host-owned admin shell chrome with visible global versus org scope
  - example-app tests for platform-admin, org-admin, and denied admin routes
affects: [phase-28-user-operations, impersonation, audit, installer-example]
tech-stack:
  added: [phoenix_live_view]
  patterns: [library-owned admin liveviews with host live layout, explicit fixture-backed admin policy, route-level admin scope assertions]
key-files:
  created:
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
    - test/example/lib/example/sigra_admin_policy.ex
    - test/example/lib/example_web/components/admin_shell.ex
    - test/example/test/example_web/admin_shell_test.exs
    - test/example/test/example_web/integration/phase_27_integration_test.exs
  modified:
    - mix.exs
    - mix.lock
    - test/example/lib/example_web/auth_error_handler.ex
    - test/example/lib/example_web/components/layouts.ex
    - test/example/lib/example_web/router.ex
    - .planning/phases/27-admin-access-foundation/deferred-items.md
key-decisions:
  - "The example host mounts admin pages through dedicated global and organization live_session blocks that reuse the library-owned admin scope resolver."
  - "The host-owned admin shell lives in ExampleWeb.Layouts.admin and keeps Admin plus the active Global or organization scope visible at all times."
  - "Example.SigraAdminPolicy stays explicit by using fixture-backed email prefixes for platform-admin and org-admin tests instead of hidden bootstrap inference."
patterns-established:
  - "Library-owned admin LiveViews can render through a host live layout without pushing long-lived admin runtime into the example app."
  - "Example-app route assertions are enough to prove admin shell chrome and scope-denial behavior without browser-only smoke."
requirements-completed: [ADMIN-01, ADMIN-03, ADMIN-04, ADMIN-05]
duration: 8 min
completed: 2026-04-16
---

# Phase 27 Plan 3: Admin Access Foundation Summary

**Example-host admin routing with visible scope chrome, library-owned admin LiveViews, and end-to-end platform-admin versus org-admin coverage**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-16T19:17:20Z
- **Completed:** 2026-04-16T19:25:53Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Mounted `/admin` and `/admin/organizations/:org` in the example app through `Sigra.Plug.RequireAdminAccess` plus `Sigra.LiveView.AdminScope`.
- Added a host-owned admin shell and live layout that always show `Admin` and the active global or organization scope.
- Added example-app tests proving platform-admin and org-admin routing, allowed organization access, and denial behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire the example host to the admin feature and render the admin shell** - `3d2c14b` (feat)
2. **Task 2: Add example-app shell and integration coverage for global and org admin flows** - `a83cb4c` (test)

## Files Created/Modified
- `lib/sigra/admin/live/index_live.ex` - Global admin foundation LiveView.
- `lib/sigra/admin/live/organization_live.ex` - Organization-scoped admin foundation LiveView.
- `mix.exs` - Adds optional `phoenix_live_view` so the library-owned admin LiveViews compile.
- `mix.lock` - Resolves the new optional LiveView dependency.
- `test/example/lib/example/sigra_admin_policy.ex` - Example-host explicit admin policy for platform-admin and org-admin fixtures.
- `test/example/lib/example_web/auth_error_handler.ex` - Adds explicit insufficient-scope and not-found admin responses.
- `test/example/lib/example_web/components/admin_shell.ex` - Host-owned admin scope bar, sidebar, and bottom-nav shell.
- `test/example/lib/example_web/components/layouts.ex` - Adds the admin live layout wrapper.
- `test/example/lib/example_web/router.ex` - Mounts the admin global and organization routes through plug and live_session enforcement.
- `test/example/test/example_web/admin_shell_test.exs` - Shell chrome and denied-state coverage.
- `test/example/test/example_web/integration/phase_27_integration_test.exs` - Platform-admin and org-admin route coverage.
- `.planning/phases/27-admin-access-foundation/deferred-items.md` - Records the unrelated installer drift failure discovered during verification.

## Decisions Made
- Used the example app's live layout as the shell seam instead of rendering host chrome directly inside the library LiveViews.
- Kept the example admin policy explicit and fixture-backed rather than deriving admin access from signup order or ambient organization state.
- Exercised the admin routes with direct `get/2` assertions so the tests prove rendered shell and denial responses together.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added optional Phoenix LiveView to the root library deps**
- **Found during:** Task 1
- **Issue:** The new library-owned admin LiveViews could not compile because `phoenix_live_view` was not declared in the root `sigra` app.
- **Fix:** Added optional `phoenix_live_view` to `mix.exs`, fetched deps, and updated `mix.lock`.
- **Files modified:** `mix.exs`, `mix.lock`
- **Verification:** `cd test/example && mix test test/example_web/admin_shell_test.exs test/example_web/integration/phase_27_integration_test.exs --max-failures 1`
- **Committed in:** `3d2c14b` and `a83cb4c`

**2. [Rule 2 - Missing Critical] Added explicit admin denial responses in the example auth error handler**
- **Found during:** Task 1
- **Issue:** `Sigra.Plug.RequireAdminAccess` can emit `:insufficient_scope` and `:not_found`, but the example handler did not implement those paths.
- **Fix:** Added 403 access-denied and 404 not-found admin responses in `ExampleWeb.AuthErrorHandler`.
- **Files modified:** `test/example/lib/example_web/auth_error_handler.ex`
- **Verification:** `cd test/example && mix test test/example_web/admin_shell_test.exs --max-failures 1`
- **Committed in:** `3d2c14b`

**3. [Rule 1 - Bug] Corrected the example admin live layout and router scope wiring**
- **Found during:** Task 2
- **Issue:** The first test run exposed two issues in the new admin wiring: the live layout used `inner_block` instead of `inner_content`, and the admin scopes needed alias-free router mounts for `Sigra.Admin.Live.*`.
- **Fix:** Switched the admin layout to `@inner_content` and updated the admin router scopes to mount the library LiveViews without `ExampleWeb` alias prefixing.
- **Files modified:** `test/example/lib/example_web/components/layouts.ex`, `test/example/lib/example_web/router.ex`
- **Verification:** `cd test/example && mix test test/example_web/admin_shell_test.exs test/example_web/integration/phase_27_integration_test.exs --max-failures 1`
- **Committed in:** `a83cb4c`

---

**Total deviations:** 3 auto-fixed (1 blocking, 1 missing critical, 1 bug)
**Impact on plan:** All three fixes were required for the planned admin wiring and tests to run. No scope expansion beyond the admin host integration and its direct verification.

## Issues Encountered
- `mix test test/sigra/templates/installer_drift_test.exs --max-failures 1` still fails on an unrelated pre-existing drift assertion for `test/example/lib/example_web/live/confirmation_live.ex` (`fix #9`). Logged to `.planning/phases/27-admin-access-foundation/deferred-items.md` and left out of scope for this admin plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The example app now exposes the Phase 27 admin entry routes with visible scope chrome and deterministic admin-role fixtures.
- Phase 28 can build real user-operations pages on top of the mounted admin shell and the verified global versus organization routing behavior.

## Self-Check: PASSED

- Found `.planning/phases/27-admin-access-foundation/27-admin-access-foundation-03-SUMMARY.md`
- Found commit `3d2c14b`
- Found commit `a83cb4c`
