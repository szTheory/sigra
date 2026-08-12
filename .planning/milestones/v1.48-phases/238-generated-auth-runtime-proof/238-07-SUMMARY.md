---
phase: 238-generated-auth-runtime-proof
plan: "07"
subsystem: auth
tags: [phoenix, liveview, playwright, github-actions, session-revocation]
requires:
  - phase: 238-06
    provides: generated-host runtime harness and initial exact-SHA evidence receipt
provides:
  - Browser proof that revokes the active generated session and denies a protected route.
  - Generated authenticated LiveView routes that mount the current scope.
  - Fresh exact-SHA generated-host runtime evidence with complete prior-attempt lineage.
affects: [generated-auth, session-management, ci-evidence]
tech-stack:
  added: []
  patterns:
    - Use role-addressable current-session controls for browser-visible revocation proof.
    - Wrap generated authenticated LiveView routes in UserAuth ensure_authenticated on_mount.
key-files:
  modified:
    - priv/templates/sigra.install/core/session_live.ex
    - lib/sigra/install/features/core.ex
    - test/example/priv/playwright/tests/generated-auth.spec.ts
    - test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs
    - .planning/phases/238-generated-auth-runtime-proof/238-EVIDENCE.json
key-decisions:
  - "Use the existing /users/sessions current-session control, named Log out this device, instead of duplicating a logout UI."
  - "Protect emitted session and settings LiveViews with UserAuth on_mount so their current_scope assign is available at mount."
requirements-completed: [AUTH-01, AUTH-02, AUTH-03]
coverage:
  - id: D1
    description: Generated current-session revocation proves the browser session is invalidated before a protected settings request.
    requirement: AUTH-01
    verification:
      - kind: automated_ui
        ref: "GitHub Actions run 31058020315 / Generated auth runtime proof job 92479701884"
        status: pass
    human_judgment: false
  - id: D2
    description: Reset, normalized email delivery, OAuth collision, and accessibility checks pass in a fresh generated host on the correction SHA.
    requirement: AUTH-02
    verification:
      - kind: e2e
        ref: "GITHUB_WORKSPACE=\"$PWD\" scripts/ci/generated-auth-runtime-proof.sh --all"
        status: pass
    human_judgment: false
  - id: D3
    description: Generated auth state accessibility and DOM contracts remain locked by focused tests and the runtime browser suite.
    requirement: AUTH-03
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-08-06
status: complete
---

# Phase 238 Plan 07: Generated Auth Review Closure Summary

**Fresh generated-host proof now revokes the active browser session through the real sessions UI, mounts authenticated LiveViews correctly, and records a successful exact-SHA CI receipt.**

## Accomplishments

- Replaced the false settings-page logout assumption with the existing `/users/sessions` current-session revocation control, named `Log out this device`.
- Fixed generated authenticated LiveView routing so SessionLive receives `current_scope` and can revoke the actual active session.
- Recorded a successful workflow-dispatch proof on `f485afb81560c9aa28fbf438ea68bdf36386dacd`: run `31058020315`, direct job `92479701884`.

## Task Commits

1. **Task 1: Fail closed across reset, normalized delivery, and browser logout boundaries** - `3d7bef2e`, `09aeb252`, `c21a1b7`, `7b68dbb5`, `a2259fef`, `f485afb8`
2. **Task 2: Ratify the corrections with a fresh exact-SHA generated-host receipt** - pending metadata commit

## Files Modified

- `priv/templates/sigra.install/core/session_live.ex` - Labels the current-session revocation button distinctly.
- `lib/sigra/install/features/core.ex` - Emits authenticated LiveView routes inside a `UserAuth` mount session.
- `test/example/priv/playwright/tests/generated-auth.spec.ts` - Uses the real sessions control and proves protected-route denial.
- `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` - Locks the control and route mounting contracts.
- `238-EVIDENCE.json` - Preserves historical runs and records fresh successful runtime metadata.

## Decisions Made

- Reused the generated session-management UI instead of adding another logout action.
- Repaired the generated router seam discovered by the direct runtime job; the HTTP authentication pipeline alone does not assign a LiveView socket's `current_scope`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Mounted generated authenticated LiveViews before reading `current_scope`**
- **Found during:** Task 2 fresh-host runtime evidence.
- **Issue:** `/users/sessions` crashed because `SessionLive.mount/3` read an absent socket assign.
- **Fix:** Wrapped generated sessions/settings LiveViews in `UserAuth`'s `:ensure_authenticated` `live_session` and added a source regression lock.
- **Files modified:** `lib/sigra/install/features/core.ex`, `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs`.
- **Verification:** Focused installer/source tests and direct job `92479701884` passed.
- **Committed in:** `f485afb8`.

**Total deviations:** 1 auto-fixed Rule 1 issue. The correction was required for the real revocation path and did not expand product scope.

## Known Stubs

None.

## Next Phase Readiness

The exact-SHA receipt is complete and all generated B2C runtime checks are machine-proven. The independently modified `238-VERIFICATION.md` remains unstaged and was not changed by this plan.

## Self-Check: PASSED

All listed files exist and every task commit is present in the repository history.
