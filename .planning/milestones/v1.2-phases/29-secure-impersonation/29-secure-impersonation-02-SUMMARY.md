---
phase: 29-secure-impersonation
plan: 02
subsystem: auth
tags: [impersonation, phoenix, sessions, sudo, admin]
requires:
  - phase: 29-01
    provides: library-owned impersonation runtime start/stop/timeout primitives
provides:
  - controller-owned impersonation start and stop routes in the example app
  - generated and example UserAuth helpers for impersonation token preservation and restore
  - focused request and session tests for start, stop, denial, and timeout restore behavior
affects: [29-03, admin-ui, session-timeouts]
tech-stack:
  added: []
  patterns: [controller-owned impersonation routes, preserved-admin-token restore through UserAuth]
key-files:
  created:
    - test/example/lib/example_web/controllers/admin/impersonation_controller.ex
  modified:
    - priv/templates/sigra.install/admin/router_injection.ex
    - priv/templates/sigra.install/core/user_auth.ex
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/user_auth.ex
    - test/example/test/example_web/controllers/impersonation_controller_test.exs
    - test/example/test/example_web/user_auth_test.exs
key-decisions:
  - "Kept impersonation restore state in Plug session keys and reused normal Sigra session tokens instead of expanding schema work in 29-02."
  - "Placed the app-wide stop route at /impersonation outside admin-only scopes while keeping start routes under admin-scoped controllers."
  - "Implemented the sudo redirect locally in the impersonation controller so only impersonation start adopts the /users/sudo return_to flow in this plan."
patterns-established:
  - "Impersonation web seams stay thin: controllers delegate lifecycle decisions to Sigra.Impersonation and UserAuth owns Plug-session token swapping."
  - "Timeout recovery runs in fetch_current_scope/2 so expired impersonation either restores the preserved admin token or clears the browser session."
requirements-completed: [IMPR-01, IMPR-02, IMPR-03, IMPR-05]
duration: 11 min
completed: 2026-04-16
---

# Phase 29 Plan 02: Secure Impersonation Summary

**Controller-owned impersonation start and stop routes with fixation-safe admin-token restore and timeout-aware UserAuth recovery**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-16T23:18:54Z
- **Completed:** 2026-04-16T23:30:09Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Added example-app impersonation controller routes for admin-scoped start and app-wide stop flows.
- Extended generated and example `UserAuth` modules with impersonation begin/restore helpers plus timeout-driven admin-session recovery.
- Locked the behavior with focused controller and user-auth tests covering sudo redirect, denial, restore, and timeout failure-closed paths.

## Task Commits

1. **Task 1: Add controller-flow and user-auth tests for start, stop, and timeout restore** - `caa0aeb` (test)
2. **Task 2: Implement generated and example controller/session wiring for impersonation lifecycle** - `72e6d05` (feat)

## Files Created/Modified
- `test/example/lib/example_web/controllers/admin/impersonation_controller.ex` - controller-owned start/stop orchestration over `Sigra.Impersonation`
- `test/example/lib/example_web/user_auth.ex` - preserved admin-token storage, restore helpers, and timeout recovery
- `test/example/lib/example_web/router.ex` - admin start routes plus app-wide stop route
- `priv/templates/sigra.install/core/user_auth.ex` - generated UserAuth impersonation lifecycle helpers
- `priv/templates/sigra.install/admin/router_injection.ex` - generated start and stop route wiring
- `test/example/test/example_web/controllers/impersonation_controller_test.exs` - request-flow coverage for sudo, denial, restore, and stop reachability
- `test/example/test/example_web/user_auth_test.exs` - token preservation and timeout restore/fail-closed coverage

## Decisions Made

- Kept impersonation restore state in the Plug session (`:impersonator_user_token`, `:impersonation_return_to`) and reused the existing session-renewal path instead of widening schema scope in this plan.
- Used `/impersonation` as the stop endpoint so ending impersonation is reachable from non-admin pages and persistent chrome.
- Scoped the sudo redirect behavior to impersonation start in the controller rather than changing the shared auth error handler during this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Narrowed example user-auth session count assertions to the current user**
- **Found during:** Task 2
- **Issue:** Existing `user_auth_test.exs` assertions counted all `user_sessions` rows globally and started failing once the new impersonation tests created additional sessions in the same module.
- **Fix:** Changed the assertions to count and fetch rows for the current test user only.
- **Files modified:** `test/example/test/example_web/user_auth_test.exs`
- **Verification:** `mix test test/example_web/controllers/impersonation_controller_test.exs test/example_web/user_auth_test.exs --include example_app`
- **Committed in:** `72e6d05`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix kept the existing example-app coverage meaningful without widening scope beyond impersonation behavior.

## Issues Encountered

- Parallel `git add` calls collided on `.git/index.lock`; resolved by staging the remaining files sequentially. No repository content was lost or reverted.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 29-03 can now build the persistent impersonation chrome against real controller routes and restore helpers.
- Timeout restore and fail-closed behavior are covered in focused example-app tests, so follow-on UI work can rely on the route/session contract.

## Self-Check: PASSED

- Summary file exists and task commit hashes `caa0aeb` and `72e6d05` are present in git history.

---
*Phase: 29-secure-impersonation*
*Completed: 2026-04-16*
