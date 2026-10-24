---
phase: make-failures-reproducible-and-report-the-result
plan: "03"
subsystem: testing
tags: [mix, exunit, ci, subprocess, seed-replay]
requires:
  - phase: 255-01
    provides: Native replay prerequisites and local execution staging
  - phase: 255-02
    provides: Native command recorder with independent stream and exit capture
provides:
  - Native observation of ordinary, scaffold, and dependency-off Mix test receivers
  - Per-suite observed seed and failure identity reporting
  - Dep-off cleanup handling that retains the guard's original status
affects: [255-04, 255-05, 255-06, 255-07]
actuals:
  tokens: 1286397
  tasks: 2
  commits: 4
commits: 4
plan_head_before: 6ba9077c56c4b2419f74662f5c794b2a8258d8c4
plan_head_after: bb5b305921d57fc42c33baea3ddfe8b2e8deb08b
tech-stack:
  added: []
  patterns: [fresh native Mix receiver processes, observed ExUnit suite seeds, preserve primary exit across restoration]
key-files:
  created:
    - scripts/ci/ci-mix-receivers.py
    - scripts/ci/ci-mix-receivers.test.py
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-03-01-RED.json
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-03-02-RED.json
  modified:
    - mix.exs
    - scripts/ci/ci-prep-semantics.test.mjs
    - scripts/ci/sigra-dep-off.sh
    - scripts/ci/test-sigra-dep-off.sh
    - test/test_helper.exs
    - test/support/ci_timing_formatter.ex
    - test/sigra/planning/ci_timing_formatter_test.exs
    - .planning/execution/255-local/MIX-RECEIVERS.json
requirements-completed: []
coverage:
  - id: D1
    description: The native contributor command executes ordinary, scaffold, and dependency-off test receivers with observed identities and status.
    verification:
      - kind: integration
        ref: .planning/execution/255-local/attempt-007/commands/mix-ci/record.json
        status: pass
      - kind: unit
        ref: scripts/ci/ci-mix-receivers.test.py
        status: pass
    human_judgment: false
  - id: D2
    description: Test receivers record actual suite seeds, and dependency cleanup preserves the primary failure result.
    verification:
      - kind: unit
        ref: test/sigra/planning/ci_timing_formatter_test.exs
        status: pass
      - kind: unit
        ref: scripts/ci/test-sigra-dep-off.sh
        status: pass
    human_judgment: false
duration: 34min
completed: 2026-10-24
status: complete
---

# Phase 255 Plan 03: Native Mix Receiver Summary

**`MIX_ENV=test mix ci` now runs and reports the ordinary suite, all six scaffold modules, and the dep-off receiver with observed suite seeds and preserved failure status.**

## Performance

- **Duration:** 34 min
- **Started:** 2026-10-24T16:28:36Z (first task commit)
- **Completed:** 2026-10-24T17:02:14Z
- **Tasks:** 2
- **Files changed:** 86, including scoped native command streams and reports
- **Measured task commits:** 4 (`6ba9077c56c4b2419f74662f5c794b2a8258d8c4..bb5b305921d57fc42c33baea3ddfe8b2e8deb08b`)

## Accomplishments

- Added native receiver observation and corrected the nested Mix task behavior that returned success without starting the scaffold receiver. The seven ordered legs now have separate native process boundaries; ordinary tests exclude scaffold, and the scaffold invocation records the six required modules.
- Recorded ExUnit seeds and failed test identities per invocation. Required CI mode explicitly checks the pinned `phx_new` prerequisite and live test database, while standalone tests retain their opt-in behavior.
- Fixed dep-off cleanup to retain the guard's failure status when restoration also fails; a successful guard followed by failed restoration remains nonzero. The shell harness verifies failure, cleanup failure, interrupt, and lock-byte restoration behavior.
- Kept the pre-change baseline separate from the repaired native observation in `MIX-RECEIVERS.json`.

## Task Commits

1. **Task 1 RED:** `69deb03a6` — test(255-03): assert native CI receiver identities
2. **Task 1 GREEN:** `2afd331ca` — feat(255-03): observe native mix ci receivers
3. **Task 2 RED:** `aa23e404f` — test(255-03): preserve dep-off failure status during cleanup
4. **Task 2 GREEN:** `bb5b30592` — fix(255-03): preserve dep-off primary failures

## TDD Gate Compliance

- **Task 1 RED:** `255-03-01-RED.json` passed `gsd_run check tdd-red-evidence` as `RED_EVIDENCE_OK`. The named receiver-report assertion failed because identity and seed validation was not implemented. It was committed before GREEN.
- **Task 1 GREEN:** Native receiver validation, per-process command execution, and required-gate prerequisite checks passed the scoped tests and the final native run.
- **Task 2 RED:** `255-03-02-RED.json` passed `gsd_run check tdd-red-evidence` as `RED_EVIDENCE_OK`. The real shell harness restored `mix.lock` but showed exit 1 replacing the guard's original exit 24. It was committed before GREEN.
- **Task 2 GREEN:** The corrected shell behavior and primary exit preservation passed the shell and process tests.

## Verification

- Final native invocation: `MIX_ENV=test mix ci`, through the Plan 02 recorder, exited 0 after 377.15 seconds. The command record binds the actual native command and working directory to source commit `aa23e404f70593c2deda22dd0d6e29240145ba91`, branch `phase-244-playwright-measurement`, and the captured dirty paths. The dep-off source diff hash is `eb8dfcfa51b56a248b6f6f1bd804f12b5e8622d5e6dd6ae38e1e599e8f809d36`.
- Native receivers: ordinary 2,695 tests, 0 failed, seed 259829; scaffold 22 tests, 0 failed, seed 512725; `threadline_guard` 65 tests, 0 failed, seed 48307. All six required scaffold module identities are present. The report has no errors.
- Baseline, before source changes: ordinary 2,659 tests, 0 failed, 12 skipped, 22 excluded; scaffold had no separate ExUnit start or summary; dep-off had 65 tests and 0 failures. This is recorded separately and is not represented as a passing scaffold run.
- `python3 -B scripts/ci/ci-mix-receivers.test.py` — 8 passed.
- `node --test scripts/ci/ci-prep-semantics.test.mjs` — 5 passed.
- `bash scripts/ci/test-sigra-dep-off.sh` — 22 assertions passed.
- `MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs` — 3 passed.
- `mix format --check-formatted` — passed.
- Ordinary receiver failure injection (`attempt-006`) propagated exit 1 from the outer `mix ci` command.
- The final native capture used the observer's `native --output DIR --report-output FILE` spelling. A `--native --output FILE` alias was added afterward and passed a narrow CLI help dispatch check; the alias change is explicitly recorded in the report with its own diff hash and does not change product behavior. The exact plan spelling was not rerun as a full native suite.
- An isolated clone attempt was denied by the local sandbox (`Operation not permitted`); it is retained as a failed experiment and is not counted as product evidence. No hosted CI or historical acceptance run was performed.

## Files Created/Modified

- `scripts/ci/ci-mix-receivers.py` and `scripts/ci/ci-mix-receivers.test.py` — native receiver invocation and source/runtime-bound identity checks.
- `mix.exs`, `test/test_helper.exs`, and `test/support/ci_timing_formatter.ex` — fresh receiver processes, explicit required prerequisites, and observed per-suite seed/failure records.
- `scripts/ci/sigra-dep-off.sh` and `scripts/ci/test-sigra-dep-off.sh` — primary result preservation and restoration failure coverage.
- `.planning/execution/255-local/MIX-RECEIVERS.json` and `attempt-001` through `attempt-007` — baseline, preserved attempts, raw command streams, and final native observation.
- `255-03-01-RED.json` and `255-03-02-RED.json` — committed, classifier-accepted assertion-based RED evidence.

## Decisions Made

- Each test receiver runs in a fresh native Mix process so nested task re-enablement cannot hide a missing execution.
- Seeds are recorded from each observed ExUnit suite. Non-test command failures use `seed: null` with `not_applicable`; no global seed fan-out is claimed.
- Keep all stopped and failed attempts as diagnostics. Only the final unchanged product behavior run establishes the receiver result.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the archive prerequisite check.**
- **Found during:** Task 1 native prerequisite validation
- **Issue:** The required-gate check used `mix archive.list`, which is not a valid Mix task on the pinned toolchain.
- **Fix:** Use the available `mix archive` command and preserve explicit missing-prerequisite diagnostics.
- **Files modified:** `test/test_helper.exs`
- **Verification:** Required-mode process tests and the final native run passed.
- **Committed in:** `2afd331ca`

**2. [Rule 1 - Bug] Matched the receiver observer's CLI adapter to the plan's invocation spelling.**
- **Found during:** Final evidence review
- **Issue:** The native run used a working `native --output DIR --report-output FILE` spelling; the plan also specifies `--native --output FILE`.
- **Fix:** Added an equivalent alias and a focused CLI dispatch check. The full native run was not repeated because this adapter does not change product behavior.
- **Files modified:** `scripts/ci/ci-mix-receivers.py`, `scripts/ci/ci-mix-receivers.test.py`, `.planning/execution/255-local/MIX-RECEIVERS.json`
- **Verification:** `python3 -B scripts/ci/ci-mix-receivers.py --native --help` passed; adapter diff hash is recorded in the report.
- **Committed in:** `bb5b30592`

**Total deviations:** 2 auto-fixed. Both were narrow corrections needed for the planned checks; no scope was added.

## Issues Encountered

- Earlier retained attempts exposed the nested receiver skip and then a dep-off fixture expectation/exit-status defect. They remain in the attempt ledger; only the final-source native run and focused passing checks are reported as passes.
- Raw captured native stderr includes terminal blank lines. A broad `git diff --check` reports those lines in retained `.bin` evidence files; the evidence bytes were preserved unchanged.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 03's native receiver and seed evidence is available to Plans 04–07. This does not complete Phase 255 or mark CIDX-01/CIDX-02 complete. Hosted CI and historical acceptance remain outside this plan's authorization.

---

*Phase: make-failures-reproducible-and-report-the-result*
*Completed: 2026-10-24*

## Self-Check: PASSED

- Summary file exists and the four task commits are ancestors of the current HEAD.
- Measured plan commit count is four, from the persisted ledger base `6ba9077c56c4b2419f74662f5c794b2a8258d8c4` to `bb5b305921d57fc42c33baea3ddfe8b2e8deb08b`.
- Both RED records passed `tdd-red-evidence`; required focused tests and the native report have the results listed above.
