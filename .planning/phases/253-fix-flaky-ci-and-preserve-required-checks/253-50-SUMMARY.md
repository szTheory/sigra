---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "50"
subsystem: ci-reliability
tags: [gsd-sdk, accepted-only, historical-disposition, load-recovery, r2]
requires:
  - phase: 253
    provides: 253-43 v1 reconciliation helper and contract
provides:
  - additive --revision r2 mode in 253-LOAD-RECOVERY-reconcile.mjs (contract, dry-run, prepare, apply, check-index)
  - committed R2 contract mapping 23 never-executed responsibilities and 7 halted records to 253-48..56
affects: [253-53, 253-56]
actuals:
  tokens: 21000
  tasks: 2
  commits: 3
plan_head_before: 6c5da94b1
plan_head_after: 1c5e440df
requirements-completed: []
coverage:
  - id: D1
    description: "R2 contract builder partitions 47 pre-R2 plans (17 completed, 7 halted, 23 never-executed) and owns every responsibility via 253-48..56, never via 40/41/44-47"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs#R2 reconciliation contract"
        status: pass
    human_judgment: false
  - id: D2
    description: "Real installed SDK on a committed copy: 48/49/50 runnable with empty blocked_by, 41/44-47 blocked by 253-40; after simulated R2 dispositions zero incomplete, 7 halted stay halted, no status: blocked summary, init agrees"
    requirement: CIREL-02
    verification:
      - kind: integration
        ref: ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs#R2 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "v1 default path and v1 contract file are byte-identical"
    verification:
      - kind: unit
        ref: "reconcile.test.mjs#the default revision and the committed v1 contract stay byte-identical; --prepare-contract --check-only exit 0"
        status: pass
    human_judgment: false
duration: 30min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 50: R2 reconciliation contract Summary

**Additive `--revision r2` mode in the Phase 253 reconcile helper plus a committed R2 contract that re-points 23 never-executed responsibilities (original eighteen plus 253-41, 44, 45, 46, 47) to the new plans 253-48..56, proven against the real installed gsd-tools on committed temp copies.**

## Task Commits

1. **Task 1 RED:** `6a58119af` (test) - failing R2 contract and real-SDK pairing tests
2. **Task 1 GREEN:** `87086cb72` (feat) - R2 builder, preflight pin checks, never-ran disposition text, `--revision` CLI
3. **Task 2:** `1c5e440df` (feat) - generated and committed the R2 contract

## R2 contract

- Path: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R2.json`
- sha256: `dc29b0963c4b6948bcb5a3b1c2cc058f84ea5b81da7364bafc7509f2448694ed`
- v1 contract sha256 unchanged: `5eba0fad1a70ae70d073ac4d4c1d4cc4ab09d1c919e8f3a7f9b6e0daf5c1dfd5`
- 23 responsibilities, 7 halted records (02/07/09/12/16/27 plus 40), 17 completed plans; final-summary owner `253-56`.
- Owners used: 36, 37, 38, 39, 42, 43, 48, 50, 51, 52, 53, 54, 55, 56 (never 40/41/44-47).
- Pins: sha256 of PLAN 01-56, SUMMARYs 36-40/42/43, the v1 contract file, and the seven SDK files (SDK 1.16.0).
- `--check-only` exits 0 for the committed file.

## Current `--revision r2 --check-index 253` report (read-only, expected ok:false)

`ok:false`, route `dispatch_plans`, 23 old responsibilities unsummarized, 31 incomplete plans in total (the 23 plus unexecuted 48, 50-56), `halted_literal: true`, `originals_intact: true`, `sdk_ok: true`, verification status `missing`, dispatchable now: 253-48, 253-50 (253-49 already summarized).

## Verification

- `node --test 253-LOAD-RECOVERY-reconcile.test.mjs`: 31/31 pass (23 pre-existing plus 8 new); the 8 new failed before the implementation commit.
- v1 `--prepare-contract --check-only`: exit 0, bytes unchanged.
- No real-directory writes other than the R2 contract; no SUMMARY dispositions, no STATE/ROADMAP/REQUIREMENTS edits, `.planning/config.json` untouched.

## Deviations from Plan

**1. [Rule 3 - Blocking] v1 test fixture leaked R2 plans and the real halted 253-40**
- **Found during:** Task 1 (RED run)
- **Issue:** The existing `realisticFixture` copied every real `253-NN-PLAN.md`, so plans 253-48..56 (and the real 253-49 SUMMARY) appeared as unsummarized, and the now-real halted 253-40 SUMMARY broke the v1 owner check; 6 pre-existing v1 write-ahead tests failed before any change.
- **Fix:** Restricted the v1 fixture to plans/summaries 01-47 and modelled 253-40 as a completed owner in the v1 world (fixture only). v1 helper code untouched.
- **Files modified:** 253-LOAD-RECOVERY-reconcile.test.mjs
- **Committed in:** 6a58119af

**Total deviations:** 1 auto-fixed (Rule 3). **Impact:** test-fixture only; v1 behavior and contract bytes unchanged.

## Known Stubs

None.

## Remaining gaps

- Dispositions are not written; 253-56 applies them after accepted completion. Whole-phase verification stays `not_started`.
- The R2 contract pins PLAN hashes: any later edit to a PLAN 01-56 requires regenerating the contract. The earlier 253-RECOVERY-CANARY-FREEZE source hash for `ci-gate-canary.sh` is stale after 253-49 (expected; 253-53 re-freezes).

## Self-Check: PASSED

R2 contract, reconcile.mjs and test file exist; commits 6a58119af, 87086cb72, 1c5e440df are ancestors of HEAD.
