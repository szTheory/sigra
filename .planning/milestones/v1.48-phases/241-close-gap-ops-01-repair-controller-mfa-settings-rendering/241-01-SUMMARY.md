---
phase: 241-close-gap-ops-01-repair-controller-mfa-settings-rendering
plan: 01
subsystem: generated-host authentication
tags: [phoenix, mfa, controller, sudo, exunit, smoke-test]
requires:
  - phase: 240.2-close-gap-ops-01-add-controller-mode-generated-host-compile-
    provides: Four-leg credential-free generated-host lifecycle with a no-live controller lane
provides:
  - Explicit controller-to-MFASettingsHTML render ownership
  - Deterministic authenticated, fresh-sudo controller MFA route proof
  - Source contracts for route ownership, exact-session setup, and lane preservation
affects: [ops-01, generated-controller-host, mfa-settings]
tech-stack:
  added: []
  patterns: [Phoenix Controller.put_view before render, request-token session sudo freshening, controller-only smoke probes]
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/core/settings_controller.ex
    - scripts/ci/passkeys-opt-out-smoke.sh
    - test/sigra/install/generated_rate_limit_contract_test.exs
key-decisions:
  - "SettingsController.mfa/2 selects MFASettingsHTML locally with put_view/2 rather than renaming the generated HTML module."
  - "The probe freshens only the persisted session derived from the logged-in connection's user token and requires 200 rendered MFA HTML."
requirements-completed: []
coverage:
  - id: D1
    description: Generated no-live MFA settings GET renders through MFASettingsHTML after authenticated fresh-sudo authorization.
    verification:
      - kind: integration
        ref: SIGRA_PASSKEYS_OPT_OUT_LEG=sigra_b2c_controller GITHUB_WORKSPACE="$(pwd)" scripts/ci/passkeys-opt-out-smoke.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Controller-only route proof and default four-leg lifecycle remain mechanically guarded without fixed waits.
    verification:
      - kind: unit
        ref: test/sigra/install/generated_rate_limit_contract_test.exs
        status: pass
      - kind: integration
        ref: GITHUB_WORKSPACE="$(pwd)" scripts/ci/passkeys-opt-out-smoke.sh
        status: pass
    human_judgment: false
duration: 9min
completed: 2026-08-11
status: complete
---

# Phase 241 Plan 01: Controller MFA Settings Rendering Summary

**Generated controller-mode MFA settings now select their emitted HTML module and are proven through a fresh-sudo authenticated request.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-08-11T22:37:00Z
- **Completed:** 2026-08-11T22:46:03Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added the minimal `put_view(html: MFASettingsHTML)` handoff immediately before the existing controller render, retaining all seven assigns and deferred mutation actions.
- Added a controller-leg-only disposable ExUnit probe that logs in, freshens the exact persisted request session, and rejects auth/sudo redirects via `html_response(200)` plus stable MFA content.
- Added focused-leg selection, full topology preservation checks, and source contracts for render ordering, session identity, no-sleep operation, and LiveView isolation.

## Task Commits

1. **Task 1: Prove and repair the protected controller MFA render path end to end** - `987154fe` (test), `1f3553b4` (feat)
2. **Task 2: Lock render ownership, exact-session authorization, and lane preservation into source contracts** - `24056c36` (test)

## Files Created/Modified

- `priv/templates/sigra.install/core/settings_controller.ex` - Selects the emitted MFA HTML module before rendering.
- `scripts/ci/passkeys-opt-out-smoke.sh` - Injects and executes the controller-only route probe and supports validated focused-leg selection.
- `test/sigra/install/generated_rate_limit_contract_test.exs` - Locks render ownership, exact-session sudo, mutation deferral, and smoke topology.

## Verification

- `mix test test/sigra/install/generated_rate_limit_contract_test.exs` — 8 tests, 0 failures.
- `bash -n scripts/ci/passkeys-opt-out-smoke.sh` — passed.
- `SIGRA_PASSKEYS_OPT_OUT_LEG=sigra_b2c_controller GITHUB_WORKSPACE="$(pwd)" scripts/ci/passkeys-opt-out-smoke.sh` — passed; generated route probe: 1 test, 0 failures.
- `GITHUB_WORKSPACE="$(pwd)" scripts/ci/passkeys-opt-out-smoke.sh` — passed all four legs; controller route probe: 1 test, 0 failures.

## Decisions Made

- Used action-local Phoenix `put_view/2` to preserve the existing generated `MFASettingsHTML.mfa_settings/1` contract instead of changing generated module ownership.
- Freshened only the stored session identified by the same connection's `:user_token`; a separate sudo fixture cannot prove the protected request path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the contract's lifecycle ordering assertion**
- **Found during:** Task 2
- **Issue:** The initial source contract compared the probe helper definition to the first test migration rather than comparing the controller branch's probe invocation to its migration.
- **Fix:** Scoped the ordering search to the controller branch and asserted the generated probe test command follows that branch's migration.
- **Files modified:** `test/sigra/install/generated_rate_limit_contract_test.exs`
- **Verification:** Focused source contract suite passed.
- **Committed in:** `24056c36`

**Total deviations:** 1 auto-fixed (Rule 1)

## Issues Encountered

The inherited shell pointed at a stale PostgreSQL port. Loading `tmp/db.env` before database-backed commands restored the healthy disposable-host endpoint.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

OPS-01's controller MFA rendering gap is covered by both a real generated-host route request and focused source contracts. No blocker remains for this plan.

## Self-Check: PASSED

- Required files exist and all three task commits are present in git history.
