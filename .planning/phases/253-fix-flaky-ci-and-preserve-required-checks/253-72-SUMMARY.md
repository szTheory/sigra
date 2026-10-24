---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "72"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, re-freeze, r4]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: 253-69 per-row context identity, 253-70 R4 run path, 253-71 reconciliation contract
provides:
  - committed R4 native load recovery freeze bound to HEAD 4fdbc82b4 and the R4 budget doc
affects: [253-73]
actuals:
  tokens: 6000
  tasks: 2
  commits: 1
plan_head_before: 4fdbc82b4a988f34eed066c1687f854a049dd03d
plan_head_after: 9ccd03d4d
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R4.json
key-decisions:
  - "Freeze created from final committed source after offline gate was green; no product bytes differ from R3"
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "Offline gate green on exact HEAD 4fdbc82b4 across runner, verifier, reconcile helper, library and example layers"
    verification:
      - kind: unit
        ref: "node --test (5 files): 259 pass 0 fail; python ci-hosted-gate-verify.test.py: 44 OK; mix test 3 files: 85 tests 0 failures; example --include example_app: 12 tests 0 failures"
        status: pass
    human_judgment: false
  - id: D2
    description: "R4 freeze committed; check exits 0; blobs equal HEAD; only runner + test differ from R3; fixture pinned; budget hash bound; R3 lineage hashes unchanged"
    verification:
      - kind: other
        ref: "ci-registration-recovery.mjs --check-load-recovery-freeze exit 0; blob comparison script"
        status: pass
    human_judgment: false
duration: 20min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 72: R4 native freeze Summary

**R4 native load-recovery freeze committed on the offline-green fixed runner, with all product bytes identical to R3, per_row_union context identity, and the R4 budget doc bound by sha256 (no capacity granted).**

## Gate results (Task 1, HEAD 4fdbc82b4, tree unchanged)

- Node 20.18.1 suites (ci-registration-recovery, ci-playwright-load, ci-registration-control-audit, p17 prohibition, reconcile helper): 259 tests, 259 pass, 0 fail.
- python3 ci-hosted-gate-verify.test.py: 44 tests OK.
- mix test auth_test, golden_diff_test, auth_ui_contract_test: 85 tests, 0 failures.
- Example smoke + registration LiveView with --include example_app: 12 tests, 0 failures (nonzero).
- Predecessors 253-69/70/71 commits are ancestors of HEAD. Summaries all status complete.
- Internal diff review (253-69/70 runner changes): dedupe is `[...new Set(ids)]` within one row; cross-row reuse still rejected (crossRowContextReuseR4 and the existing check retained); no timeout, retry or trace change (R4 freeze keeps retries 0, trace retain-on-failure); frozen-path code unchanged. No findings.

## Freeze (Task 2)

- Path: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R4.json`
- File sha256: `abf6e110e00dfb85ed6ae521815d6a5a5388d062b2c5f6ef579643b181107346`
- Commit: 9ccd03d4d; source.checkout_head = 4fdbc82b4a988f34eed066c1687f854a049dd03d (HEAD at creation; the freeze commit is its direct child).
- Check: exit 0 ("R3 lineage re-hashed, 2222537 ms/8 launches/9 spent carried, per-row union context identity, 22 rows, no capacity granted").
- 28 blobs, all equal `git rev-parse HEAD:path`; only differences from R3 are scripts/ci/ci-registration-recovery.mjs and its test; fixture r3-mirrored-context-annotations.json pinned.
- Budget doc sha256 865561402eb87f160aaf746fba9121bb5b9cad936f64d86ada5e9a585ad099c3 matches shasum of committed doc; grants_capacity false.
- R3 lineage hashes present unchanged: evidence b264928d..., freeze effaef51..., approval 724e4472....
- `--verify-load-recovery` on R3 evidence: exit 3, "R3 native load recovery evidence rejected: frozen R3 source identity mismatch for scripts/ci/ci-registration-recovery.mjs", no crash text (clean rejection).

## Deviations from Plan

None - plan executed exactly as written. Task 1 is read-only and produced no commit.

## Remaining gaps

253-73 needs Jon's decision on the R4 budget bound to this freeze hash; no approval record or R4 evidence created. Full Phase 253 verification remains not_started.

## Self-Check: PASSED
