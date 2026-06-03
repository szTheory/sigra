---
phase: 29-secure-impersonation
plan: 4
subsystem: auth
tags: [impersonation, phoenix, liveview, audit, passkeys, mfa]
requires:
  - phase: 29-02
    provides: impersonation session state and dual-actor scope hydration
provides:
  - reusable request-boundary plug for impersonation-blocked mutations
  - guarded Accounts wrappers for password, MFA, passkey, and deletion/reactivation paths
  - example and generated controller/LiveView wiring for blocked sensitive operations
affects: [29-05, impersonation, account-security]
tech-stack:
  added: []
  patterns: [shared impersonation gate plug, direct-path scope guard, audited denial path]
key-files:
  created: [lib/sigra/plug/forbid_during_impersonation.ex]
  modified:
    [
      priv/templates/sigra.install/core/session_controller.ex,
      priv/templates/sigra.install/core/mfa_settings_live.ex,
      priv/templates/sigra.install/core/reactivation_live.ex,
      test/example/lib/example/accounts.ex,
      test/example/lib/example_web/controllers/session_controller.ex,
      test/example/lib/example_web/live/mfa_settings_live.ex,
      test/example/lib/example_web/live/reactivation_live.ex,
      test/sigra/plug/forbid_during_impersonation_test.exs,
      test/example/test/example_web/impersonation_blocked_ops_test.exs
    ]
key-decisions:
  - "The controller boundary uses a reusable plug, while LiveView handlers fail closed through explicit impersonation checks and Accounts scope guards."
  - "Denied sensitive operations reuse the existing audit pipeline with admin.impersonation.denied rows instead of a separate logging path."
patterns-established:
  - "Sensitive impersonation-blocked mutations accept scope opts in generated/example Accounts wrappers and return {:error, :impersonation_forbidden}."
  - "Controller denial UX stays explicit via redirect-plus-flash while the library plug still supports error_handler-based denial in generic contexts."
requirements-completed: [IMPR-04]
duration: 44min
completed: 2026-04-17
---

# Phase 29 Plan 4: Secure Impersonation Summary

**Server-side impersonation gates now block passkey, MFA, password, and deletion/reactivation mutations with explicit denial feedback and audit context.**

## Performance

- **Duration:** 44 min
- **Started:** 2026-04-16T23:37:20Z
- **Completed:** 2026-04-17T00:21:43Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- Added `Sigra.Plug.ForbidDuringImpersonation` as the shared request-boundary gate for controller mutation paths.
- Guarded `Example.Accounts` direct mutation entry points so password, MFA, passkeys, and deletion/reactivation fail closed when a scope is impersonating.
- Wired the example app and generated templates to surface explicit impersonation denial feedback and exercised the new behavior in focused library and example tests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add blocked-operation tests for controller, LiveView, and direct-path impersonation gates** - `eedecf1` (`test`)
2. **Task 2: Implement the shared impersonation gate and wire the required blocked sensitive operations** - `5070bab` (`feat`)

## Files Created/Modified
- `lib/sigra/plug/forbid_during_impersonation.ex` - Shared plug that halts impersonated requests, carries denial metadata, and emits audit rows.
- `test/example/lib/example/accounts.ex` - Direct-path scope guards for password, MFA, passkey, schedule/cancel deletion operations.
- `test/example/lib/example_web/controllers/session_controller.ex` - Passkey mutation controller paths now run through the impersonation gate with explicit redirect copy.
- `test/example/lib/example_web/live/mfa_settings_live.ex` - Passkey rename handler and MFA disable path fail closed while impersonating.
- `test/example/lib/example_web/live/reactivation_live.ex` - Example reactivation flow now exists and blocks cancellation while impersonating.
- `priv/templates/sigra.install/core/session_controller.ex` - Generated controller wiring mirrors the example plug-based denial path.
- `priv/templates/sigra.install/core/mfa_settings_live.ex` - Generated LiveView wiring mirrors the example passkey/MFA guard path.
- `priv/templates/sigra.install/core/reactivation_live.ex` - Generated reactivation flow now passes scope into cancellation and surfaces impersonation denial.
- `test/sigra/plug/forbid_during_impersonation_test.exs` - Plug-level regression coverage for pass-through vs denial behavior.
- `test/example/test/example_web/impersonation_blocked_ops_test.exs` - Example coverage for controller denial, LiveView handler denial, and direct Accounts guard behavior.

## Decisions Made
- Kept denial behavior split by boundary: controller paths redirect with explicit flash copy, while direct-path and LiveView handlers return `:impersonation_forbidden` and let the caller surface the message.
- Used the existing `admin.impersonation.denied` audit stream with operation metadata so denied sensitive-operation attempts stay queryable alongside other impersonation lifecycle rows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed struct access in the new plug's audit metadata**
- **Found during:** Task 2 (shared gate implementation)
- **Issue:** The first plug version used `get_in/2` against host scope structs, which raised `UndefinedFunctionError` because `Example.Accounts.Scope` does not implement `Access`.
- **Fix:** Replaced `get_in/2` with struct-safe `Map.get/2` extraction for actor and effective-user ids.
- **Files modified:** `lib/sigra/plug/forbid_during_impersonation.ex`
- **Verification:** `mix test test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1` and `cd test/example && mix test test/example_web/impersonation_blocked_ops_test.exs --max-failures 1`
- **Committed in:** `5070bab`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix stayed inside the new plug and did not expand scope.

## Issues Encountered
None.

## Known Stubs

- `test/example/lib/example_web/live/mfa_settings_live.ex:871` - Pre-existing `TODO` for backup-code regeneration wiring; unrelated to impersonation blocking and still non-blocking for this plan.
- `priv/templates/sigra.install/core/mfa_settings_live.ex:864` - Generated-template mirror of the same pre-existing backup-code regeneration `TODO`.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- API-token create/revoke seams remain intentionally deferred to Plan 29-05.
- The impersonation gate, direct Accounts contract, and denial audit pattern are now in place for the remaining sensitive-operation surface.

## Self-Check: PASSED

---
*Phase: 29-secure-impersonation*
*Completed: 2026-04-17*
