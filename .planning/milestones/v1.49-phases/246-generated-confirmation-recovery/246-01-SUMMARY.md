---
phase: 246-generated-confirmation-recovery
plan: 01
subsystem: auth
tags: [elixir, phoenix-liveview, email-confirmation, ecto]
requires: []
provides:
  - Explicit generated confirmation links for anonymous and signed-in visitors, with persisted owner confirmation and session preservation.
  - Anonymous code and resend guidance, plus confirmation-code lookup scoped to the signed-in user.
affects: [phase-246-generated-confirmation-recovery]
actuals:
  tokens: 6446
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [optional-scope confirmation LiveView session, fresh-host persisted-state probe]
key-files:
  created: [.planning/phases/246-generated-confirmation-recovery/246-01-tdd-red.json]
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/install/features/core.ex
    - priv/templates/sigra.install/core/confirmation_live.ex
    - priv/templates/sigra.install/core/sigra_auth_components.ex
    - scripts/ci/generated-confirmation-probe.exs
    - scripts/ci/install-smoke.sh
    - test/sigra/install/features/core_test.exs
    - test/sigra/install/generator_wiring_test.exs
key-decisions:
  - "Confirmation link routes use an optional current-scope LiveView session so signed-in visitors keep their identity while the token selects the account being confirmed."
  - "Confirmation codes are looked up by both their hash and the server-selected user ID."
patterns-established:
  - "Fresh-host confirmation probes assert database state and session identity across GET, submit, and replay."
requirements-completed: [CONF-01, CONF-03]
coverage:
  - id: D1
    description: "Generated links confirm only their token owner after explicit submit, preserve an existing visitor session, and reject replay."
    requirement: CONF-01
    verification:
      - kind: integration
        ref: "bash scripts/ci/install-smoke.sh — generated confirmation probe"
        status: pass
    human_judgment: false
  - id: D2
    description: "Anonymous confirmation-code and resend events show localized sign-in guidance; a client account ID cannot redirect code confirmation."
    requirement: CONF-03
    verification:
      - kind: integration
        ref: "bash scripts/ci/install-smoke.sh — anonymous and client-ID probe cases"
        status: pass
      - kind: unit
        ref: "test/sigra/install/generator_wiring_test.exs — confirmation LiveView anonymous safety"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated confirmation LiveView routes are in the optional-scope group, while no-live generation retains controller routes."
    verification:
      - kind: unit
        ref: "test/sigra/install/features/core_test.exs — confirmation optional-scope and no-live route assertions"
        status: pass
    human_judgment: false
duration: 44min
completed: 2026-10-06
status: complete
plan_head_before: b3e2d3d8c4fc05791130128bfc280c221622e1f4
plan_head_after: e47dafca11681221e7aba96f1ad3d6ce8aa40631
commits: 3
---

# Phase 246 Plan 01: Generated Confirmation Recovery Summary

**Generated email confirmation now changes the token owner's persisted state only on explicit submit while preserving the visitor session.**

## Performance

- **Duration:** approximately 44 minutes
- **Started:** 2026-10-06T12:53:00-04:00 (estimated from execution window)
- **Completed:** 2026-10-06T13:37:12-04:00
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Moved generated confirmation LiveViews into an optional current-scope session and kept link GET read-only; explicit submit confirms the token owner and displays visible success status.
- Added fresh-host coverage for anonymous and signed-in link visitors, session preservation, link replay, anonymous code/resend guidance, and client-supplied account-ID tampering.
- Scoped code-token lookup to the server-selected user ID so another account's code cannot confirm its owner through a different signed-in session.

## Task Commits

1. **Task 1: Prove anonymous link confirmation from route to persisted user** - `fe5679de` (`feat`)
2. **Task 2 RED: Complete signed-in link and anonymous code/resend behavior** - `32d31d09` (`test`)
3. **Task 2 GREEN: Secure signed-in and anonymous code confirmation** - `e47dafca` (`feat`)

## Files Created/Modified

- `lib/sigra/install/features/core.ex` - Optional-scope routes for confirmation LiveViews.
- `lib/sigra/auth.ex` - Bind confirmation-code lookup to the selected user.
- `priv/templates/sigra.install/core/confirmation_live.ex` - Explicit link action and safe anonymous event branch.
- `priv/templates/sigra.install/core/sigra_auth_components.ex` - Accessible status and error feedback.
- `scripts/ci/install-smoke.sh` - Fresh-host toolchain/cache setup and probe execution.
- `scripts/ci/generated-confirmation-probe.exs` - Persisted-state and session-preservation probe.
- `test/sigra/install/features/core_test.exs`, `test/sigra/install/generator_wiring_test.exs` - Route and generated-template contracts.
- `.planning/phases/246-generated-confirmation-recovery/246-01-tdd-red.json` - Machine-validated RED evidence.

## Decisions Made

- Kept the confirmation token as the account selector; a logged-in visitor's account and session remain untouched when they submit a different account's link.
- Made the code lookup match the current user's ID as well as the hashed code, preserving server-side account selection throughout the code path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Security] Bound confirmation-code verification to the signed-in user**
- **Found during:** Task 2 (fresh-host account-ID tampering probe)
- **Issue:** `Sigra.Auth.verify_confirmation_code/3` accepted a code token without constraining its lookup by the supplied `user_id`, allowing a signed-in user to submit another account's code.
- **Fix:** Added `user_id` to the code-token lookup so a mismatched account receives the normal invalid-code result.
- **Files modified:** `lib/sigra/auth.ex`
- **Verification:** Fresh-host tampering probe confirms neither the link owner nor the visitor is confirmed; focused tests and install smoke pass.
- **Committed in:** `e47dafca`

**2. [Rule 3 - Blocking] Isolated the generated host toolchain and Hex cache**
- **Found during:** Task 1 (install-smoke tracer)
- **Issue:** The temporary host did not inherit the repository's asdf versions and a shared Hex cache produced ownership errors.
- **Fix:** Passed pinned Erlang/Elixir versions into the smoke host and gave it a private Hex cache.
- **Files modified:** `scripts/ci/install-smoke.sh`
- **Verification:** Repeated full fresh-host install-smoke passed.
- **Committed in:** `fe5679de`

---

**Total deviations:** 2 auto-fixed (1 security correctness fix, 1 smoke-environment fix)
**Impact on plan:** Both changes were required to prove the planned account isolation and fresh-host acceptance criteria.

## TDD Gate Compliance

- **RED:** `test confirmation LiveView anonymous safety code and resend events require a signed-in scope and provide a login link` failed on the missing scope guard before implementation. The persisted report passed `gsd-tools check tdd-red-evidence` with `RED_EVIDENCE_OK`; the semantic assertion was inspected in the captured ExUnit output.
- **GREEN:** The focused generated-template suite passed after implementation, and the fresh-host probe passed all seven tests.

## Issues Encountered

- A first client-ID tampering probe exposed the unscoped code-token lookup; the lookup was corrected and the full disposable-host smoke was rerun successfully.
- Fresh-host runs initially exposed asdf and Hex-cache isolation requirements; the smoke script now sets both explicitly.

## User Setup Required

None.

## Next Phase Readiness

Plan 01 is complete. Plans 02 and 03 remain in this phase and own the remaining confirmation recovery work and phase-level verification.

---
*Phase: 246-generated-confirmation-recovery*
*Completed: 2026-10-06*

## Self-Check: PASSED

- Summary file exists at the plan output path.
- Task commits `fe5679de`, `32d31d09`, and `e47dafca` are ancestors of the current plan head.
- RED evidence revalidated as `RED_EVIDENCE_OK`.
- Focused route and generator suite passed: 64 tests, 0 failures.
- Fresh-host install smoke passed: 7 generated-host tests, 0 failures.
