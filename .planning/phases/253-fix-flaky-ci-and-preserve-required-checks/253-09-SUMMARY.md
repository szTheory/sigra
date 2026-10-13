---
phase: 253
plan: 09
subsystem: testing
tags: [playwright, liveview, registration, receipt-verification]
requires:
  - phase: 253-02
    provides: repaired setup path and preserved historical registration evidence
provides:
  - Source-bound recovery runner and native receipt verifier with forged-success rejection tests
  - Pre-result diagnostic freeze reserving Plan 09 and Plan 10 slots and cumulative time
  - Redacted terminal record for the first diagnostic setup stop
affects: [253-10, CIREL-01, registration-reliability]
actuals:
  tokens: 48090
  tasks: 0
  commits: 16
plan_head_before: 4d34cf0470f721e1df631a830e29ee65bf396278
plan_head_after: 24ffd0b929b89a38a5caffeedd6d9d2518551f52
tech-stack:
  added: []
  patterns: [source-bound native file receipts, serial fixed-slot browser diagnostics]
key-files:
  created:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-REGISTRATION-FREEZE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-09-TERMINAL-DIAGNOSTIC.json
  modified:
    - scripts/ci/ci-registration-repro.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-REGISTRATION-EVIDENCE.json
decisions:
  - "Keep the historical browser cause and missing preceding test order unknown."
  - "Stop Plan 09 after the deterministic Mix setup failure; do not spend a retry or Plan 10 slot."
  - "Keep native logs free of Mix development signing-key values, even though redaction makes the runner's original log digests fail validation."
metrics:
  duration: 87min
  completed: 2026-10-13
  status: halted
requirements-completed: []
coverage:
  - id: D1
    description: Recovery runner, freeze, and native verifier reject forged results and bind source/log/report/trace evidence.
    verification:
      - kind: unit
        ref: scripts/ci/ci-registration-recovery.test.mjs
        status: pass
    human_judgment: false
  - id: D2
    description: Selected browser registration flow for all three projects has source-bound native results.
    requirement: CIREL-01
    verification:
      - kind: integration
        ref: .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-09-TERMINAL-DIAGNOSTIC.json
        status: fail
    human_judgment: true
    rationale: Mix setup failed before the application and browser started, so there is no registration result to assess.
---

# Phase 253 Plan 09: Bounded registration diagnostics summary

The recovery runner and native verifier are in place, but the first bounded diagnostic halted in Mix setup before launching an application or browser.

## Performance

- **Duration:** 87 minutes
- **Started:** 2026-10-13T10:19:12-04:00
- **Completed:** 2026-10-13T11:46:00-04:00
- **Tasks completed:** 0/2; both tasks were stopped before their acceptance criteria were met
- **Files changed:** 26 before this summary was written

## Accomplishments

- Added a separate recovery runner and native verifier. It binds receipts to frozen source and rejects forged success, missing reports, wrong projects, changed log hashes, absent cleanup, missing failure traces, and over-budget attempts. Existing `--verify-controls` and `--verify-acceptance` modes still exit 3.
- Added ten focused recovery tests. The suite covers the native receipt contract, the fractional Node timeout that caused the first stop, and unique output directories that preserve earlier preflight logs.
- Committed a freeze before browser work. It fixes the three diagnostic projects in order, retains the Plan 10 control/acceptance reservations, and binds 1,667 ms of prior setup and no-launch runner failures to the first slot.
- Preserved the actual terminal details in [253-09-TERMINAL-DIAGNOSTIC.json](./253-09-TERMINAL-DIAGNOSTIC.json). The Mix logs are committed with development `secret_key_base` values redacted.

## Diagnostic outcome

The first project was `admin-eval`, selecting `render bundle: board-mg-9/populated`. Mix setup exited 1 because the runtime endpoint port (`25311`) differed from its compiled port (`4011`). The `ecto.drop` cleanup command also exited 1. The app did not start, there was no HTTP readiness result, and Playwright launched zero browsers.

The attempt used 2,101 ms of execution time plus the frozen 1,667 ms prelaunch charge, for 3,768 ms total. The runner halted because the database drop did not succeed. After the raw setup/drop logs were redacted to remove development key values, the direct native validator rejected their changed hashes and the nonzero drop exit. This is an honest halted receipt, not proof that registration passed or that the historical failure was reproduced.

The first diagnostic slot is consumed by setup failure. `D19-DIAG-02` and `D19-DIAG-03` remain unused; all six Plan 10 control slots, the flexible infrastructure retry, and the nine acceptance slots remain unused. The old archived preceding test order is still unknown. `CIREL-01` remains open.

## Task commits

The source/test work and evidence were committed in atomic commits:

1. `a77db6297` — RED receipt-rejection tests
2. `a4643521d` — source-bound native verifier
3. `1ed3453d3` — charge Playwright restore to diagnostic budget
4. `31c966de7` — preserve first unlaunched freeze revision
5. `bad08bac4` — order control bundles by round
6. `0dacd976d` — freeze bounded diagnostics
7. `6079a15aa` — preserve zero-launch start state
8. `e402569ad` — preserve timeout failure receipt and freeze revision
9. `094dc5a79` — preserve exact prior freeze bytes
10. `6b45b6605` — fix fractional timeout handling and preflight accounting
11. `ab1d692f2` — freeze corrected diagnostic ledger
12. `e813c4223` — preserve second zero-launch stop and start-state bytes
13. `4d81192fb` — isolate attempt output from preserved preflight logs
14. `6be4b5332` — only replace an exactly preserved freeze
15. `5641b3b04` — commit the final pre-browser freeze
16. `24ffd0b92` — retain redacted setup-stop diagnostics

The frozen native test run passed 10/10 focused tests. The legacy runner suite passed 5/5 tests, and its forged-claim checks passed 6 cases. `node --check` passed. The selected browser run did not start Playwright; native validation rejected the setup/drop result and later rejected the redacted log digests.

## TDD Gate Compliance

- **RED:** The new recovery-mode rejection test failed before the recovery mode existed; its TAP and evidence files are committed in `a77db6297`.
- **GREEN:** The implemented verifier and runner passed the focused suite, which grew to 10 tests and passed after the timeout and output-directory fixes.
- **REFACTOR:** No behavior-neutral refactor was needed after the final passing run.

## Deviations and issues

- Fixed the runner's fractional timeout argument after Node rejected `118654.22791698575` before spawning any child process. That first failure consumed 146 ms and launched no browser.
- Fixed output-directory allocation after the next invocation collided with the preserved preflight log directory. That failure consumed 177 ms and launched no browser.
- After the selected setup failed deterministically, stopped as instructed rather than attempting a retry or continuing to another diagnostic project. The endpoint port mismatch remains a concrete implementation blocker for a future run.
- Mix's setup/drop output included development `secret_key_base` values. The committed raw logs redact those values. Automatic approval review rejected committing an exact pre-redaction evidence copy as credential-bearing. The canonical evidence ledger remains unchanged from the runner's halted write and is uncommitted; it retains hashes for the pre-redaction logs, so native validation reports digest mismatches after redaction. No key values were committed.

## Next phase readiness

Plan 09 is halted and its browser acceptance criteria are unmet. Before attempting any later diagnostic, resolve the runtime/compile-time endpoint port mismatch, preserve the canonical evidence ledger through an allowed durable method, and create a new freeze bound to the corrected runner and exact remaining slots. Do not reuse the spent first diagnostic slot or Plan 10 allocations. The root orchestrator owns shared `STATE.md`, `state.json`, `HANDOFF.json`, `ROADMAP.md`, `REQUIREMENTS.md`, and the execution record; those shared files were not changed here.

---
*Phase: 253*
*Status: halted*

## Self-Check: PASSED

- This summary file exists at the planned phase path.
- All 16 listed task/evidence commits are ancestors of the current branch head.
- The committed freeze and redacted terminal diagnostic paths exist.
