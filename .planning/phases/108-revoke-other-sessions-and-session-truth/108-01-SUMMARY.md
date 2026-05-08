---
phase: 108-revoke-other-sessions-and-session-truth
plan: 01
subsystem: auth
tags: [sessions, auth, audit, pubsub, testing]
requires: []
provides:
  - library-owned preserve-current session revoke primitive
  - explicit session.revoke_others audit path
  - focused auth tests for success, zero-sibling, and fail-closed behavior
affects: [generated session UI, admin session truth, session docs]
tech-stack:
  added: []
  patterns: [preserve-current session revocation, fail-closed current-session validation]
key-files:
  created:
    - .planning/phases/108-revoke-other-sessions-and-session-truth/108-01-SUMMARY.md
  modified:
    - lib/sigra/auth.ex
    - test/sigra/auth_test.exs
key-decisions:
  - "Keep sibling-session deletion on the existing :except_token store seam instead of adding a new store primitive."
  - "Return {:error, :current_session_not_found} without side effects when the preserved session cannot be proven for the user."
patterns-established:
  - "Preserve-current session operations must validate the preserved hashed token against persisted session rows before deleting anything."
  - "Audit truth must distinguish revoke-others from revoke-all."
requirements-completed: [SESS-02, SESS-05]
duration: 20min
completed: 2026-05-08
---

# Phase 108 Plan 01 Summary

**Sigra now exposes a first-class preserve-current session revoke API that fails closed and audits revoke-others separately from revoke-all**

## Performance

- **Duration:** 20 min
- **Started:** 2026-05-08T11:20:00Z
- **Completed:** 2026-05-08T11:59:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `Sigra.Auth.revoke_other_sessions/3` as the library-owned preserve-current revoke seam.
- Reused the persisted `:except_token` delete path while validating the current session against listed rows first.
- Added focused auth tests that lock success, zero-sibling, and `:current_session_not_found` failure behavior.

## Task Commits

Atomic task commits were not created.

- The repo already had extensive unrelated unstaged changes, including files touched by adjacent phase work.
- Creating per-task commits would have bundled pre-existing edits from the shared working tree.

## Files Created/Modified

- `lib/sigra/auth.ex` - added `revoke_other_sessions/3` and refactored shared revoke internals.
- `test/sigra/auth_test.exs` - added preserve-current success, no-op, and fail-closed coverage.
- `.planning/phases/108-revoke-other-sessions-and-session-truth/108-01-SUMMARY.md` - recorded the verified library seam outcome.

## Verification

- `MIX_ENV=test mix compile --warnings-as-errors`
  Result: pass
- `CLOAK_KEY=... MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/templates/session_templates_test.exs test/mix/tasks/sigra.install_test.exs --no-color`
  Result: pass
- `rg -n "def revoke_other_sessions\\(|session\\.revoke_others|current_session_not_found" lib/sigra/auth.ex test/sigra/auth_test.exs`
  Result: pass

## Decisions Made

- Kept revoke-set computation inside `Sigra.Auth` and the session store rather than exposing raw `:except_token` wiring to generated hosts.
- Limited telemetry changes to the existing revoke-all path to avoid widening Phase 108 into broader telemetry/docs churn.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository was already dirty before execution. I kept the implementation bounded to the plan-owned auth seam and test coverage.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The generated user surface can now call a truthful preserve-current revoke seam.
- The admin and docs work can build on a stable `Sigra.Auth.revoke_other_sessions/3` contract.

## Self-Check

PASSED

- Verified the library compiles with warnings denied.
- Verified focused auth/store/template test coverage passes.
- Verified the explicit revoke-others contract and failure marker exist in the expected files.

---
*Phase: 108-revoke-other-sessions-and-session-truth*
*Completed: 2026-05-08*
