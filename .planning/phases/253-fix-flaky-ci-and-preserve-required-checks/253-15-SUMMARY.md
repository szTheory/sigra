---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: '15'
subsystem: registration-reliability
tags: [registration, playwright, budget, native-evidence]
dependency-graph:
  requires: [253-REPLAN-BUDGETS.md, preserved-registration-capture]
  provides: [budgeted-registration-runner, halted-desktop-diagnostic-receipt]
  affects: [253-16]
tech-stack:
  added: []
  patterns: [frozen-command-slots, source-revision-receipts, per-attempt-build-directory]
key-files:
  created:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPLAN-REGISTRATION-FREEZE-REVISION-03.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPLAN-REGISTRATION-EVIDENCE.json
  modified:
    - scripts/ci/ci-registration-repro.sh
decisions:
  - Stop plan15 after the desktop browser process failed at host launch before the selected registration test began.
  - Retain the desktop slot as spent and preserve the setup, report, logs, and trace with fixture credentials redacted.
metrics:
  duration: 34 seconds native attempt; 3.743 seconds common preparation
  completed_date: 2026-10-13
  status: halted
  commits: 10
  plan_head_before: 5fa42c052922238bd0149cd4ad3845c425c9e501
  plan_head_after: 51276ba76112e46896ab7fc6f4ec98d9f435379b
actuals:
  tokens: 95435
  tasks: 1
  commits: 10
---

# Phase 253 Plan 15: Registration runner and desktop diagnostic summary

The registration replan runner and its frozen budget are implemented, but the plan halted because Chromium terminated with a host permission error before the desktop registration test could execute. The evidence records no registration result and makes no no-flake or Phase 253 acceptance claim.

## Execution status

**Halted: 0 of 2 tasks complete.** Task 1's source, tests, preparation receipt, and frozen diagnostic ran through environment setup, but its required real registration result was not produced. Task 2's mobile diagnostic and adversarial native-receipt checks were not started.

The desktop command used freeze revision 03 (`sha256: 60c790a9fe9c7051eed93e5f7e552ef725558b6b112d6a19c5346dd9f5cb41d9`) and source commit `08429d9e7033e36dec62192b8620858af5592c85`. It charged 26,373 ms for the attempt, in addition to 3,768 ms of preserved historical charge and 3,743 ms of common dependency preparation, for 33,884 ms total. It launched one browser process. Chromium then stopped with `SIGTRAP` after the host denied its Mach port registration. The selected test did not start, the app log contains no registration POST, and no success flash was asserted. The desktop slot is spent; mobile remains unrun.

The exact halted ledger is [253-REPLAN-REGISTRATION-EVIDENCE.json](./253-REPLAN-REGISTRATION-EVIDENCE.json). Native output is under `253-REPLAN-REGISTRATION-EVIDENCE.json.raw/R-DIAG-DESKTOP/attempt-01/`. Ten seeded credential lines were replaced with `[REDACTED]` before the setup log was committed, and its byte count and digest were updated in the ledger.

## Validation

- `node --test scripts/ci/ci-registration-recovery.test.mjs`: 14 tests passed after the final runner source change.
- `bash scripts/ci/ci-registration-repro.test.sh`: 5 tests passed, including rejection of forged claims.
- `node scripts/ci/ci-registration-recovery.mjs --run-revision ... --slot R-DIAG-DESKTOP ...`: halted; one browser launch, 26,373 ms native attempt, test did not execute.
- `node scripts/ci/ci-registration-recovery.mjs --verify-diagnostic ... --revision`: exit 3; rejected the receipt because the selected registration lacked a successful server POST and flash, and the Playwright expected/result statuses differed.
- The final native receipt remains halted. A successful local test suite does not replace the missing desktop and mobile registration results.

## Deviations from Plan

**1. [Rule 3 - Blocking issue] Fixed revision evidence path and nested attempt-directory handling.**
- **Found during:** Task 1
- **Issue:** Initial preflight checks found a wrong capture path and the runner could not create its nested attempt directory.
- **Fix:** Corrected the capture lookup and added recursive attempt-directory creation with regression coverage. Each source repair received a new source freeze; no browser capacity was added by those freezes.
- **Files modified:** `scripts/ci/ci-registration-recovery.mjs`, `scripts/ci/ci-registration-recovery.test.mjs`
- **Commits:** `ba4e82c49`, `08429d9e7`

**2. [Rule 3 - Infrastructure halt] Stopped before a second native command.**
- **Found during:** Task 1
- **Issue:** The host denied Chromium's Mach port registration and the process exited with `SIGTRAP` before the selected test started.
- **Action:** Preserved the failed launch as a spent desktop slot, redacted seeded credential output, and halted. No desktop retry or mobile run was made, and no acceptance claim was inferred.
- **Files modified:** `253-REPLAN-REGISTRATION-EVIDENCE.json` and its scoped raw receipt directory
- **Commit:** `53f7cd797`, `51276ba76`

## Deferred work

- Run the frozen mobile diagnostic after the Chromium host launch constraint is resolved and a reviewed execution can consume its remaining budget.
- The desktop registration result, mobile registration result, historical preceding-order log, and Phase 253 acceptance evidence remain missing.

## Self-Check: PASSED

- The summary, freeze revision 03, halted evidence ledger, and scoped raw artifacts exist on disk.
- All 10 plan commits recorded above are ancestors of the current branch.
- The setup-log digest matches the redacted bytes; the unrelated dirty config remains unchanged at SHA-256 `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`.
