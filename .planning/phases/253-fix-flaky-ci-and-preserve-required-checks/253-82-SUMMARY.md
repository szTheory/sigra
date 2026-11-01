---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "82"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, re-freeze, r5]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: 253-79 fixed runner, 253-80 R5 run path, 253-81 R5 reconciliation
provides:
  - committed R5 native freeze (253-LOAD-RECOVERY-NATIVE-FREEZE-R5.json) bound to the fixed runner, R5 budget doc and carried first window
affects: [253-83]
actuals:
  tokens: 12000
  tasks: 2
  commits: 1
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R5.json
  modified: []
key-decisions:
  - "Froze at checkout_head 1784a7745378d3d3f335bbff61732be2dcdf14a8 (HEAD before the freeze commit)."
requirements-completed: ["CIREL-01", "CIREL-02"]
duration: 15min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 82: R5 native freeze Summary

**R5 native freeze created and committed on the offline-green fixed runner: product blobs identical to R4, schema-qualified (auth) account count, R5 budget hash bound, first window carried; no capacity granted.**

## Gate results (Task 1, HEAD 1784a7745)
- Node 20.18.1 suites (ci-registration-recovery, ci-playwright-load, ci-registration-control-audit, p17, reconcile test): 306 tests, 306 pass, 0 fail, 0 skipped.
- Real-Postgres pg test (tmp/db.env, port 58624): 2 tests, 2 pass, 0 fail, 0 skipped; no leftover sigra_253_control_r5itest_ database. TAP prints `# skipped 0` (the plan's grep for `# skip 0$` would not match literally; verified by hand).
- python3 ci-hosted-gate-verify.test.py: exit 0; __pycache__ removed.
- Root ExUnit (auth_test, golden_diff_test, auth_ui_contract_test): 85 tests, 0 failures.
- Example smoke + registration LiveView with --include example_app: 12 tests, 0 failures.
- reconcile --check-only for v1, r2, r3, r4, r5: all exit 0.
- Ancestry: 253-79, 253-80, 253-81 commits all in HEAD.

## Review findings (253-79/80 diffs)
No high finding. Schema is derived from frozen migration and user schema (must agree, plain lowercase identifier) and only on the R5 path; stderr redacts email and password; non-zero exit/timeout/error rejects; carried-row checks intact; no timeout, retry or trace change observed in the reviewed lines.

## Task 2: freeze
- Path: .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R5.json
- File sha256: a2e273396e986e5ddf7488104829c59930780d21ade8d2fa1fc0ea4f3e1f1312 (embedded freeze_sha256 b6e6fafab7e35199ed2be70197aa84320a2db1a3605870110b84e72e6f96bb9d)
- source.checkout_head: 1784a7745378d3d3f335bbff61732be2dcdf14a8; commit 567925368
- --check-load-recovery-freeze exit 0. All 30 blobs equal HEAD; only runner + its unit test differ from R4; added pins are exactly the pg test and the auth-tables migration (blob equal to 4fdbc82b4's). account_count.schema auth, context_identity per_row_union, budget sha256 aff4aeb1... matches the doc, carried_first_window revision 0596dd97a / 08437732..., R4 evidence/freeze/approval hashes present and unchanged.
- --verify-load-recovery on R4 evidence: exit 3, "R4 native load recovery evidence rejected: ...", no JS crash text.

## Deviations from Plan
None. (Note: the task's `# skip 0$` grep wording vs. actual `# skipped 0`; no effect on result.)

## Remaining
No approval record or R5 evidence created. 253-83 awaits Jon's decision binding to the freeze hash. Full Phase 253 verification remains not_started.

## Self-Check: PASSED
