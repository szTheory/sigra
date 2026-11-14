---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 27
subsystem: ci-reliability
tags: [playwright, native-evidence, bounded-runner]

requires:
  - phase: 253-26
    provides: repaired registration controls and Node 20 offline diagnosis
provides:
  - bounded native control recovery runner and five-slot freeze
  - terminal CR-DARK-FIRST failure receipt with sanitized artifacts
affects: [phase-253-recovery]

actuals:
  tokens: 57768
  tasks: 1
  commits: 7

tech-stack:
  added: []
  patterns: [predebited finite reservations, process-group termination, evidence revision preservation]

key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-27-RED-01.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTROL-RECOVERY-NATIVE-FREEZE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs

key-decisions:
  - "The first new reservation is CR-DARK-FIRST, mapped to unused R-CONTROL-FIRST-DESKTOP; the other four remain unspent."
  - "Any unexpected native result ends this recovery; the failed command cannot be retried or reclassified as a pass."

patterns-established:
  - "Native work is debited before setup, uses a 105-second work deadline, and reserves the final 15 seconds for owned cleanup."
  - "Each evidence replacement preserves the exact previous bytes and status under a scoped Git ref, then verifies read-back."

requirements-completed: []
coverage:
  - id: D1
    description: "The recovery runner preserves prior charges, launch count, retry state, and the five unused command mappings."
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#control recovery ledger carries every prior charge and maps each unused reservation once"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#bounded process runner terminates a stalled child and its grandchild and records the real timeout"
        status: pass
    human_judgment: false
  - id: D2
    description: "The dark registration and first controls have accepted native proof."
    requirement: CIREL-01
    verification:
      - kind: integration
        ref: ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json"
        status: fail
    human_judgment: false

duration: 32min
completed: 2026-10-14
status: halted
plan_head_before: 678761bcb32714cb097d08ac2dd045e194888bea
plan_head_after: 88fe2106d93782a59acf0022a0a697cda5a236b9
commits: 7
---

# Phase 253 Plan 27: Native Control Recovery Summary

The runner preserved all earlier native history and stopped after the sole authorized dark command failed to load the Playwright spec: `canonicalize.ts` attempted to `require()` the ESM-only `parse5` package, and Playwright reported “No tests found.” No dark registration result was accepted.

## Performance

- **Duration:** approximately 32 minutes
- **Started:** 2026-10-14T00:52:00Z (approximate; the first Plan 27 commit was recorded at 2026-10-14T01:13:00Z)
- **Completed:** 2026-10-14T01:23:33Z
- **Tasks completed:** 0 of 2; Task 1 halted after the native failure, and dependent Task 2 was not started
- **Files changed:** 12, including the summary and required open verification entry
- **Measured task commits:** 7; the summary commit is separate

## Accomplishments

- Added the finite charge validator, five exact unused-reservation mappings, and a process-group runner that stops timed-out children and grandchildren.
- Committed the freeze before native setup. It records 243,044 ms carried, four prior Playwright CLI launches, five spent invocation reservations, retry 1 used/0 available, and 112,489 ms remaining preparation capacity. The freeze file SHA-256 is `bef539ef0803a5e035266fd2d5334b02dc87893c285114e7f70cbec3b46a0778`; its source is commit `a881094ca250723e26142da6f67e8e9475ba5caa`.
- Ran CR-DARK-FIRST once. Setup returned 0, the app returned HTTP 200, Playwright launched once and exited 1, database drop returned 0, and the temporary build was removed. The command charge is 33,409 ms; cumulative charge is 276,453 ms across five actual CLI launches. The report contains the ESM `parse5` load error and a second “No tests found” error, with no selected test results. The evidence remains `halted` at [253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json](./253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json), SHA-256 `e9982fd5a787777cc00defacd3b88ac41edfee21e08df5e62234e6dfe2319ab0`.
- Preserved the pre-run and pre-final evidence revisions under `refs/gsd/phase253-control-recovery-native-evidence/f8296ac13f20ca1b43b8a560a917b7d4964f377de9a462c2a262025d45c68e4d` and `refs/gsd/phase253-control-recovery-native-evidence/c23f6a529b29edbb745fda4e200c4f1e3ed1ce569baf093d50ca21356b388cf4`; both were read back byte-for-byte. The prior failed Plan 16 record and its separate 112 ms cleanup remain unchanged.

## Verification

- Node 20.18.1 runner suite passed: 30 tests, 0 failures.
- The committed RED contract was classified `RED_EVIDENCE_OK`; its actual target assertion failed because the new ledger validator did not yet exist.
- The native freeze check passed before setup and confirmed the exact source, historical hashes, slot mapping, carried charges, and retry count.
- The required dark evidence check failed. It found the sanitized setup log's demo-credentials marker, an empty quiet-drop log, top-level Playwright errors, no selected tests, and an exit that did not match the frozen control outcomes. The saved report states that CommonJS `require()` of `parse5/dist/index.js` is unsupported and then says “No tests found.”
- All committed native logs were checked for unredacted signing keys and cookie/authorization headers; none were found. The demo-credentials block is present only as `[REDACTED seeded demo credentials]`.
- Task 2's hermetic candidate-repository checks were not run. This is recorded as an open `unrun-verify` entry in `.planning/WINDOWS.md`.

## Task status and remaining blocker

| Task | Result |
| --- | --- |
| 1. Freeze and run CR-DARK-FIRST | Halted. One command was spent; no native test result was accepted. |
| 2. Reject counter laundering and make inherited contracts portable | Not started because the required native command failed terminally. |

The remaining four regular reservations and nine conditional acceptance reservations are untouched. No retry was made or reopened. Both Phase 253 requirements and whole-phase verification remain open. The native failure requires a separately planned correction for the `parse5` CommonJS/ESM incompatibility before another reserved command can run.

## Task commits

- `030914aef`: `test(253-27): add recovery ledger red contract`
- `4df75ffc6`: `feat(253-27): add bounded control recovery ledger`
- `176c038cb`: `fix(253-27): read carried control history accurately`
- `c92ad34db`: `fix(253-27): count cumulative native launches once`
- `a881094ca`: `fix(253-27): link timeout assessment to failed receipt`
- `4c0b516b9`: `docs(253-27): freeze native control recovery allocation`
- `88fe2106d`: `docs(253-27): preserve halted dark control receipt`

## Deviations from Plan

**1. [Rule 1 - Bug] Corrected how the runner reads historical charges and retry counts.**
- **Found during:** Task 1, before freeze creation
- **Issue:** The earlier receipts store cumulative launch and retry values in different records than the new runner initially expected.
- **Fix:** Read the exact terminal, failed-dark, and timeout-assessment fields and use the carried cumulative launch count once.
- **Files modified:** `scripts/ci/ci-registration-recovery.mjs`
- **Commits:** `176c038cb`, `c92ad34db`, `a881094ca`

**2. Native failure stopped dependent work.**
- **Found during:** Task 1 native CR-DARK-FIRST
- **Issue:** `canonicalize.ts` cannot `require()` the installed ESM `parse5` package. Playwright produced no selected test results, so the planned native proof is absent. The strict receipt check also rejected the sanitized demo-credentials marker and empty quiet-drop log.
- **Action:** Kept the command terminally failed, recorded its actual 33,409 ms charge, and did not run Task 2 or retry the browser command.
- **Files modified:** `253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json` and its `.raw/CR-DARK-FIRST/attempt-01/` artifacts
- **Commit:** `88fe2106d`

## Self-Check: PASSED

- Runner and test files exist; freeze and failed native evidence are committed.
- All seven task commits are ancestors of the current branch head.
- The saved native report has a matching digest and records the ESM load failure and zero test results.
