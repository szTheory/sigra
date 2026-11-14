---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "173"
subsystem: ci-reliability / offline recovery acceptance
status: halted
gap_closure: true
tags: [ci-reliability, execution-halt-recovery, command-correction, r13, r16]
requires: ["253-167 (halted; original state preserved)"]
provides: ["reviewed 253-167 recovery correction", "retained one failed 253-173 regression attempt"]
affects: ["253-168", "253-169", "253-170", "253-171", "253-172"]
tech-stack:
  added: []
  patterns: ["preserve a failed verification attempt with its original exit sentinel"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-173-RECOVERY-REVIEW.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-173-REGRESSION.log
  modified: []
decisions:
  - "Keep 253-167 halted and preserve its failed Task 3 attempt; 253-173 does not claim acceptance from the old diagnostic tail."
  - "Do not rerun the new regression after the first nonzero result; the temporary Git object write failed with a sandbox permission error."
  - "Keep CIREL-01 partial_not_reproduced, CIREL-02 unaccepted, and full phase verification not_started."
metrics:
  duration: "~4 minutes"
  completed: 2026-10-20
actuals:
  tokens: 3257
  tasks: 1
  commits: 2
plan_head_before: a26049c3dc95bd5139ee2682fd02f340a6f07890
plan_head_after: 08f042269a8f3c1fb1b16b95570358ec90b56d19
commits: 2
---

# Phase 253 Plan 173: Recover the halted R13 acceptance attempt Summary

The recovery review is committed, but the single new offline acceptance attempt stopped before projection output because the sandbox denied a temporary Git object write. The failed attempt is preserved verbatim; no success receipt was created and the regression was not rerun.

## Task 1: Review and one new acceptance attempt

The review records the unchanged halted 253-167 summary and plan hashes, the prior Task 1/2 delivery commits, the ten findings and their existing dispositions, the R15-FULL-SUITE interpretation, the scoped paged-listing command, the 7/7 full-run `attempt_jobs` stop, and the 377-byte margin against the 2,097,152-byte tree-body cap. The one-day deadline guard passed at four projected pages; its twenty-day positive control failed at fourteen pages. Direct source hashes and the `origin/main` pin matched the plan. The root-owned `.planning/config.json`, `.planning/state.json`, `.planning/STATE.md`, and `.planning/HANDOFF.json` hashes were recorded at entry and remained unchanged.

The review commit is `647340567` (`docs(253-173): review halted acceptance recovery`). The exact first automated block was extracted to `/var/folders/f3/f0clj9rd2zb85n2c849wcsrc0000gn/T/253-173-task1-verify.sh` with SHA-256 `6bb44c14ecced16766ca8973862f0904a30ffd589e6a3b39ff271866cceb97ce`. It ran once under `caffeinate -i -s`. It printed source commit `64734056781203a3900a9d61c93548ed4e8c6f54`, then stopped with:

```text
ci-git-publication: PublicationError: git hash-object failed: error: unable to create temporary file: Operation not permitted
fatal: Unable to add (null) to database
VERIFY-EXIT 1
```

This is an environment write-permission failure before the projection or regression suite ran. The plan forbids a second attempt after a nonzero exit, so the result remains failed and unaccepted.

## Task 2: Failure evidence preserved

The exact outer log is committed as `08f042269` (`docs(253-173): preserve failed recovery run diagnostics`). It is 339 bytes with SHA-256 `aeb25e295e13b263424cb23f29bdce33282046439c063b236453bea7e49111f9`; its final line is `VERIFY-EXIT 1`. The review also identifies the known `LivePolicyPRTests.test_live_policy_token_and_host_rules_hold_across_both_families` flake and says a recurrence would remain a failure.

No `253-173-RECOVERY-RECEIPT.json` was written because Task 2 requires a successful `VERIFY-EXIT 0` log. The log contains no projection or gate summaries, native full-suite count, or new acceptance result.

## Deviations from Plan

**1. [Rule 3 - Blocking environment issue] The regression helper could not create a temporary Git object.**
- **Found during:** Task 1 automated block.
- **Issue:** `git hash-object` was denied while creating a temporary file in the Git object database (`Operation not permitted`).
- **Action:** Preserved the first run's exact output and nonzero exit. The plan prohibits rerunning a nonzero result.
- **Files:** `253-173-REGRESSION.log`; no product source changed.
- **Commit:** `08f042269`.

## Status and next step

253-167 remains halted with its original summary and plan unchanged. CIREL-01 remains `partial_not_reproduced`; CIREL-02 remains `unaccepted` pending Plans 170/171 hosted proof and Plan 172 completion; full phase verification remains `not_started`. This plan does not unblock Plan 168 because the new acceptance receipt is absent. Resolve the Git object write permission, then re-plan or otherwise authorize a fresh attempt; this plan's failed run must not be repeated or relabeled.

No requirement was marked complete, and no shared planning state file was modified.

## Self-Check: PASSED

- Review and regression log exist; the success receipt is absent by design after `VERIFY-EXIT 1`.
- The original halted 253-167 summary and plan still match their pinned SHA-256 values.
- Both task commits are ancestors of HEAD, and the measured plan commit count is 2.
- The four orchestrator-owned shared planning files retain their captured bytes.
