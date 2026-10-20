---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "181"
subsystem: ci-reliability
tags: [halted, local-validation, preserved-amendment]
status: halted
---

# Phase 253 Plan 181: Repair successor validation Summary

The local repair work reached a terminal halt because the final deterministic suite still has one invalid negative-control mutation. This is not phase completion and does not authorize the existing acceptance plan.

## Result

The final finite test command was `python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR.test.py`. It ran 21 tests: 20 passed and one failed after 384.179 seconds (exit 1). The complete output is preserved at [253-181-TASK3-FINAL-FULL-FAILED.log](253-181-TASK3-FINAL-FULL-FAILED.log), SHA-256 `6864de43372cce91efb9b01ccc5404c6c72e20ee7ed791dd42b5c5b5ac1a39ab`.

The failing `22-halt` test tries to replace `c.halted_plans.length!==24` with `c.halted_plans.length!==22`, but the fixture already contains `c.halted_plans.length!==25`. The replacement changes zero bytes. The test then rehashes the unchanged valid fixture and sees it accepted, contrary to its expectation. This demonstrates a broken negative control; it does not show that a real changed 22-halt assertion would be accepted. No repair was made after this full-suite failure, per the bounded execution instruction.

The earlier complete run is also preserved unchanged at [253-181-TASK3-FIRST-FULL-FAILED.log](253-181-TASK3-FIRST-FULL-FAILED.log), SHA-256 `901946f8435254be8a272436377b6ddd2549e2760657ef4773e6b7a69ff87b30` (21 tests, three errors). The latest run is the final result for the current candidate.

## Completed implementation work

Root committed and verified Task 1 (`59ffb8228`), Task 2 RED (`e03ab7c30`), Task 2 GREEN (`9090010e3`), and Task 3 RED (`bbc5e50e8`). Task 2's strict source manifest, shared semantic SDK-report validation, exact unique index checks, and mutation tests passed the root rerun. Task 3 candidate source and 179/180 plan amendments remain uncommitted; their exact hashes, sizes, and preserved input readbacks are in [253-181-EXECUTION-RECORD.json](253-181-EXECUTION-RECORD.json).

Actual installed SDK schema and structure validators for amended plans 179 and 180 exited successfully and were rerun against the exact retained argv, stdout, hashes, and plan bytes. The full evidence is [253-181-TASK3-FINAL-VALIDATORS.json](253-181-TASK3-FINAL-VALIDATORS.json), SHA-256 `706d0351cf0a3af718e94ada37a92efe065e622bdd95995f01bbe6aa817c6083`. Those checks validate plan structure only and do not negate the failed suite.

## Prior findings

- `178-REVIEW-01`: both amended command bodies now have receipt guards; direct tests pass, but this plan remains halted overall.
- `178-REVIEW-02`: semantic report validation was implemented and Task 2 was committed after root verification.
- `178-REVIEW-03`: exact index-universe and committed-source binding was implemented and Task 2 was committed after root verification.
- `178-TEST-01`: the local Git fixture was repaired; focused nested-history coverage passed.

The original 178 plan, summary, review, and execution record remain unchanged and halted. Their hashes and producing commits, plus the original 179/180 plan readbacks under `refs/gsd/phase253-repair181-inputs` at `c090e22390cda1c17f62814d2be8181babf28830`, are captured in the execution record.

## Requirements and next step

`CIREL-01` remains `partial_not_reproduced`; `CIREL-02` remains `unaccepted`; whole-phase verification is `not_started`. No real acceptance, browser, hosted request, install, or requirement completion occurred.

Next route: `$gsd-plan-phase 253 --gaps`.
