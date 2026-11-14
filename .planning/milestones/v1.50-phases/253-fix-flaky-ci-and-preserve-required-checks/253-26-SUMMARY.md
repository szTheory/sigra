---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: '26'
subsystem: testing
tags: [node, playwright, registration, ci-controls]
requires:
  - phase: 253-16
    provides: Frozen failed dark-control receipt and post-halt cleanup record
provides:
  - Hash-bound offline timeout assessment for the stopped native command
  - Shared Node ESM registration-control account and sequencing functions
affects: [253-27, phase-253-verification]
actuals:
  tokens: 9808
  tasks: 2
  commits: 2
commits: 2
plan_head_before: fb3743961c29161d6f1fb9c1ebdc8b2bb9341645
plan_head_after: 72c554da160a8dbcd4e03eaaa7593578444514b5
tech-stack:
  added: []
  patterns:
    - Dependency-free ESM control module shared by Node tests and opt-in Playwright callbacks
    - Offline evidence audit tied to Git blobs and retained sanitized log hashes
key-files:
  created:
    - scripts/ci/ci-registration-control-audit.mjs
    - scripts/ci/ci-registration-control-audit.test.mjs
    - test/example/priv/playwright/helpers/registrationControls.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTROL-RECOVERY-TIMEOUT-ASSESSMENT.json
  modified:
    - test/example/priv/playwright/tests/admin-eval.spec.ts
key-decisions:
  - Keep the stopped 121252 ms command failed and its registration cause unproved until a later native recovery run.
  - Separate held and forced-trace positive accounts from the stable account reserved for deliberate collisions.
  - Keep shared control behavior in plain JavaScript ESM so Node 20 tests and the CJS-style Playwright spec invoke the same exports.
metrics:
  duration: not_recorded
  completed: 2026-10-14
status: complete
requirements-completed: []
coverage:
  - id: D1
    description: Offline assessment preserves the failed command, cleanup charge, frozen source blobs, and sanitized log identities.
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: node --test scripts/ci/ci-registration-control-audit.test.mjs
        status: pass
    human_judgment: false
  - id: D2
    description: Shared registration-control exports enforce release-before-submit and separate positive/collision account purposes.
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: scripts/ci/ci-registration-control-audit.test.mjs#shared registration-control tests
        status: pass
      - kind: automated_ui
        ref: test/example/priv/playwright/tests/admin-eval.spec.ts#opt-in registration controls
        status: unknown
    human_judgment: true
    rationale: This plan is restricted to offline work; a later authorized native run must exercise the actual Playwright callbacks and transport.
---

# Phase 253 Plan 26: Offline Control Timeout Audit Summary

**An offline audit preserves the 121252 ms timeout as failed and records two demonstrated control defects without claiming they caused the historical registration failure.**

## Performance

- **Duration:** Not recorded; the plan start timestamp was not captured.
- **Started:** Not recorded.
- **Completed:** 2026-10-14T01:07:33Z.
- **Tasks:** 2.
- **Files modified:** 5.

## Accomplishments

- Added an audit command and temporary-Git-fixture tests that verify frozen source blobs, retained sanitized log hashes, the absent native report, the timeout, and the separate cleanup charge.
- Captured the source-level control issues and executable pre-repair counterexamples: the held control submitted before release, and its positive account matched the deliberate collision account.
- Extracted the account and held-signal sequencing into one dependency-free `.mjs` module used directly by Node tests and dynamically imported by the existing Playwright spec.
- Kept native status `failed`, total recorded charge 243044 ms, and `cause_status: unproved_native_until_recovery`.

## Task Commits

1. **Task 1: Replay one stopped command into a source-bound offline timeout assessment** - `2135be352` (`feat`).
2. **Task 2: Repair only control defects demonstrated by executable counterexamples** - `72c554da1` (`fix`).

## Files Created/Modified

- `scripts/ci/ci-registration-control-audit.mjs` - Offline source/log audit and strict assessment checker.
- `scripts/ci/ci-registration-control-audit.test.mjs` - Hermetic audit tests and direct tests of both shared exports.
- `test/example/priv/playwright/helpers/registrationControls.mjs` - Shared account-purpose and held-control ordering functions.
- `test/example/priv/playwright/tests/admin-eval.spec.ts` - Opt-in controls now use the shared exports and record structural stage/transport observations.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTROL-RECOVERY-TIMEOUT-ASSESSMENT.json` - Hash-bound offline assessment and recorded RED evidence.

## TDD Gate Compliance

The three control tests were run against a faithful extraction of the original behavior. Two failed on behavioral assertions: the held flow produced `submit-while-held` before release, and the positive/collision account comparison returned the same dark-project email. The deliberate collision reuse assertion passed. After repair, the same exports passed all three tests.

The final acceptance command passed under Node `v20.18.1`:

```text
ASDF_NODEJS_VERSION=20.18.1 asdf exec node --test scripts/ci/ci-registration-control-audit.test.mjs scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
11 tests passed, 0 failed
```

The assessment checker also passed under Node 20. No browser, application, database, or GitHub command ran in this plan.

## Decisions Made

- Keep the saved command and cleanup as separate facts: 121252 ms remains the failed native charge, 112 ms is cleanup, and the cumulative charge remains 243044 ms.
- Keep the original cause unknown. The saved source proves a click occurred before the WebSocket release and that two control roles shared an account; neither fact proves why the native command timed out.
- Use distinct project-scoped purposes for held-positive and forced-trace-positive accounts, with one stable project-scoped account shared only by deliberate collision checks.
- Preserve the spec's local three-argument readiness helper, its selector, 1500 ms negative waits, font checks, and the existing Playwright defaults.

## Deviations from Plan

None. The changes follow the two planned tasks and stay offline.

## Issues Encountered

The first run of the new audit tests exposed two mistakes in the test harness assertions; those were corrected before the tests passed. No product behavior was changed to address those harness issues.

## User Setup Required

None.

## Next Phase Readiness

Plan 26's offline implementation is complete. The native command remains failed, the historical registration cause is still unproved, and no native acceptance result was produced. Later authorized recovery work must exercise the actual held-control callbacks, preserve the finite command budget, and collect any required hosted results. CIREL-01 and whole-phase verification remain open.

## Self-Check: PASSED

- The audit CLI, its test file, shared `.mjs` module, modified Playwright spec, and timeout assessment were present at plan closeout.
- Both task commits were ancestors of the recorded plan head: `2135be352` and `72c554da1`.
- The assessment checker verified the nine frozen source blob identities and both retained log hashes; its result still states `native_outcome: failed` and `cause_status: unproved_native_until_recovery`.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-14*
