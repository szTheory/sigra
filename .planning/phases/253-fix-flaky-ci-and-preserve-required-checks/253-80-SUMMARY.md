---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "80"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, runner, approval, r5]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: 253-79 R5 count fix, ledger, carried first window, freeze and evidence init
provides:
  - R5 second-window run path (prepare and run) with the schema-qualified count wired by default and pinned by an identity test
  - R5 attempt and evidence verifiers (--stage progress 0-2, --stage complete 22 rows across carried and new rows)
  - recordBudgetApprovalR5 (never called against the real R5 files), R5 run gating, CR5-INFRA-RETRY
affects: [253-82, 253-83]
actuals:
  tokens: 42000
  tasks: 3
  commits: 6
plan_head_before: baaaed05ac57479000e9941c91c14f1089f01fea
plan_head_after: c5a65a8bd6d198656336120993628176bc078b69
tech-stack:
  added: []
  patterns: [additive R-revision beside frozen code, single psql run seam so default captures are exercised offline, v2 receipts judged first then shared predicates on v1 projections]
key-files:
  created: []
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "loadR5RunDefaults is an exported frozen object, so the wiring test asserts identity with captureOwnedAccountCountR5/captureOwnedDatabaseAbsenceR5 and a default-wired run is exercised through one injected psql seam (psqlRun) instead of overriding the captures"
  - "Carried first window is re-verified live on every R5 file verify (carriedFirstWindowR5 over the committed R4 bytes) and must equal both the frozen binding and the copy in the evidence"
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "R5 second windows run with the fixed count query and preserved psql stderr; a count failure halts non-infrastructure naming the psql first line, charged, no CLI launch, no retry"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#a synthetic CR5-DESKTOP-SECOND runs with the default captures ... verifies at --stage progress"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#a failed count query halts as a non-infrastructure attempt that names the psql error"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R5 run defaults are the schema-qualified captures"
        status: pass
    human_judgment: false
  - id: D2
    description: "22-row proof judged across 16 carried and 6 new rows (union context ids, distinct databases, fresh-state digest equals carried collision receipt, tamper refusals)"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R5 runs all three second windows once in order ... = 22"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#the R5 complete stage refuses a context id carried from the first window ..."
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#the R5 complete stage refuses a tampered carried binding ..."
        status: pass
    human_judgment: false
  - id: D3
    description: "R5 capacity only through a committed v4 approval on an awake host; single-use CR5-INFRA-RETRY only after a host-fault halt; halts carry per_test_rows and the psql first line; accepted evidence verifies by git objects"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#an R5 run needs a committed v4 approval ... / the R5 retry is never available ... / R5 accepted evidence verifies by git ancestry"
        status: pass
    human_judgment: false
duration: 45min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 80: R5 run path, verifier, approval gates and terminal verification Summary

**Additive R5 runner revision: second-window run path wired to the schema-qualified count by default (identity-pinned), a 22-row verifier that judges the carried and new rows as one ledger, and a v4 approval recorder, run gates and single-use infrastructure retry; no native, psql-against-real-windows, GitHub or approval-recording action was taken.**

## Performance

- **Duration:** about 45 min
- **Completed:** 2026-10-14T21:11Z
- **Tasks:** 3 (tracer, then two auto TDD tasks)
- **Files modified:** 2

## Accomplishments

- Task 1 (tracer): `runLoadRecoverySlotR5` / `runHeldLoadRecoverySlotR5` / `prepareLoadRecoveryR5`, exported `loadR5RunDefaults` (captureAccount and captureAbsence are the R5 captures; asserted by identity and by a default-wired run whose psql input is `"auth".users`, never `FROM users`). Setup has its own 60000 ms dual-clock deadline, the command clock starts at setup end, charge is setup plus command, prior_collision_absence (0) and created_account (1) are v2 receipts with stdout and stderr logs copied into raw. A failing count query halts non-infrastructure before the CLI with the psql first line in `stop_reason` and `stop_record.account_count_failure`. `verifyNativeLoadAttemptR5` judges v2 receipts against the freeze (query, schema, sidecar digest), then runs the shared predicates on v1 projections, then R3 accounting and host-awake. `--stage progress` (new parseArgs value) accepts 0-2 outcomes with the carried binding re-verified.
- Task 2: `--stage complete` = 3 outcomes + 16 carried = 22; union context-id uniqueness (against the carried ids and across new rows, derived from the preserved reports), database distinctness incl. the carried database, per-outcome fresh-state digest equal to `carried_first_window.collision_receipts[project]`, and tamper refusals (binding hashes, revision commit, raw files, no live re-verification, order, counters, caps, fourth slot, any CR/CR2/CR3/CR4 identity).
- Task 3: `recordBudgetApprovalR5` (exclusive create, v4, R5 caps, routed before R4 in main), R5 run refuses before predebit without a committed matching v4 approval (R4/R3/R2 approvals refused by schema and caps), host probe before predebit, min(freeze, approval) caps and the D-20 reservation, `CR5-INFRA-RETRY` single-use only after suspension or lost holder with a committed diagnostic and never under approve-without-retry, per_test_rows on every launched stop, `verifyFrozenSourceBindingR5` exported and tested in terminal (git object) mode.

## Task Commits

1. Task 1 RED `9c27ad4a7`, GREEN `99b18adb6`
2. Task 2 RED `314a97f35`, GREEN `4ed926837`
3. Task 3 RED `e498884d6`, GREEN `c5a65a8bd`

## Test Counts

- Unit: `ci-registration-recovery.test.mjs` 216 pass / 0 fail / 0 skip (198 pre-existing, assertions unchanged, plus 18 new: 5 + 4 + 9). With `ci-playwright-load.test.mjs` (16): 232 pass. Task-3 verify set (also `ci-registration-control-audit.test.mjs`, `p17-no-playwright-retry-wrapper.test.mjs`): `# tests 246`, `# pass 246`, `# fail 0`, `# skipped 0`.
- Real Postgres (`ci-registration-recovery.pg.test.mjs`, re-run once as a regression check, tmp/db.env): `# tests 2`, `# pass 2`, `# fail 0`, `# skipped 0`; leftover `sigra_253_control_r5itest_*` query empty.
- RED observed before each GREEN (5, 2 and 7 failing tests).

## Decisions Made

- The only edits to pre-existing shared lines: the `--verify-load-recovery` parseArgs arm gained `progress` as an allowed stage, the two R5 main() stubs (prepare/run) became real routes, and the 253-79 `verifyLoadRecoveryFileR5` stub and `verifyFrozenSourceBindingR5` (now exported) were replaced/exported. `git diff` removed lines are exactly those; no v1-R4 constant, schema string, function body or message changed.
- Statuses for R5 evidence: `ready` (0 outcomes), `second_partial` (1-2), `complete` (3). Terminal (git object) verification applies to `second_partial` and `complete`.
- An R5 slot id matching `^CR[1-4]?-` is refused as an earlier-revision identity, in addition to the spent/expired/retired lists.
- `recordBudgetApprovalR5` is implemented and unit-tested on a temp repo only. The real R5 approval is 253-83 (Jon's decision) and was not recorded; only a reject-path CLI call (writes nothing) touches the real paths.

## Deviations from Plan

**1. [Rule 1 - Bug] Test-authoring slips corrected in the GREEN commits**
- **Found during:** Tasks 1 and 3
- **Issue:** (a) the redaction assertion looked for a fixed test email while the run uses the project's own collision account; (b) the retry-drift mutation removed an argv entry the desktop slot does not carry; (c) the "never retry" cases asserted an empty `infrastructure_halts`, but an assertion failure under a suspension flag legitimately records a non-retryable halt entry; (d) the copied R4 refusal text said "(v3)" and was corrected to "(v4)" before commit.
- **Fix:** assertions corrected to what the contract actually guarantees (redaction marker present, argv appended, no halt entry is retryable, retry record null).
- **Files modified:** scripts/ci/ci-registration-recovery.test.mjs, scripts/ci/ci-registration-recovery.mjs
- **Committed in:** 99b18adb6, c5a65a8bd

**2. [Rule 2 - Missing critical] `psqlRun` seam**
- **Issue:** the plan requires the default captures to be exercised offline; overriding them would defeat the identity guard.
- **Fix:** a single optional `psqlRun` dep forwarded as `run` to whichever capture is wired; production passes none.

---

**Total deviations:** 2 auto-fixed (1 test-authoring Rule 1, 1 seam Rule 2). **Impact:** no scope change.

## Issues Encountered

None. One test (file verifier re-verifies the carried window) passed immediately in the Task 2 RED commit because the file-level carried re-verification was already built in Task 1; it is kept as a regression contract.

## Raw-SQL / Safety Notes

No psql, Playwright, caffeinate, GitHub or git push action was run by this plan's code paths; all seams were injected. config.json sha256 still `8e312f6ccd34...`, state.json still 70229 bytes, no STATE/ROADMAP/REQUIREMENTS edit, no gsd writer verb run.

## Known Stubs

None.

## Next Phase Readiness

Ready for 253-82 (R5 freeze and ledger init, real-Postgres re-run) and 253-83 (Jon's R5 budget decision; `--record-budget-approval` against the real R5 doc is his call). Full Phase 253 verification stays not_started.

## Self-Check: PASSED

- Modified files exist; commits `9c27ad4a7 99b18adb6 314a97f35 4ed926837 e498884d6 c5a65a8bd` are ancestors of HEAD; `git rev-list --count baaaed05a..HEAD` = 6.
