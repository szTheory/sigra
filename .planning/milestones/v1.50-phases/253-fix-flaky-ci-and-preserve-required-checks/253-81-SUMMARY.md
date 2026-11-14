---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "81"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, reconciliation, accepted-only, r5]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: R4 reconciliation contract and halted 253-73
provides:
  - additive --revision r5 in the reconciliation helper (contract, dry-run, prepare, apply, check-index)
  - committed R5 contract (38 responsibilities, 10 halted records, final owner 253-88)
  - completion verifier load_controls bound to the R5 native evidence
affects: [253-82, 253-87, 253-88]
actuals:
  tokens: 24000
  tasks: 3
  commits: 5
plan_head_before: cdc3932ab3f2679bbe954156a1605631f6147cfd
plan_head_after: 64d26af7b1ffabcb37a2dff2de201c87a39d5829
tech-stack:
  added: []
  patterns: [additive R-revision beside frozen builders, per-plan frozen tooling receipts, real-SDK pairing on temp committed copies]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R5.json
  modified:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
key-decisions:
  - "253-71 tooling receipts frozen per plan at commit 65d670c0c bytes; 253-61 stays frozen as R4 holds it"
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "R5 contract maps 38 never-executed responsibilities to proof owners 79-88 and keeps 10 halted records literal"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R5 reconciliation contract"
        status: pass
    human_judgment: false
  - id: D2
    description: "Real installed SDK: 79 and 81 runnable now, 74-78 blocked behind 73; zero incomplete after simulated dispositions, ten halted, no blocked summary"
    requirement: CIREL-02
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#R5 pairing through the real installed SDK on a copy of the current plan set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Production completion checker accepts load_controls only at the R5 native evidence and rejects v1/R2/R3/R4/253-40 evidence"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#CompletionLoadLinkBindingTests"
        status: pass
    human_judgment: false
duration: 35min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 81: R5 reconciliation contract and completion load-link rebinding Summary

**Additive R5 reconciliation revision (38 superseded responsibilities, 10 halted records, owners 253-79..88) proven against the real installed SDK, plus completion load_controls re-pointed to the R5 native evidence.**

## Task Commits

1. Task 1 RED `e23da0012`, GREEN `4bb3f303a` (helper and test)
2. Task 2 `c7f78119a` (R5 contract)
3. Task 3 RED `5b1091f01`, GREEN `64d26af7b` (verifier and test)

## R5 contract

- sha256 `f92fefe3f028de90112c9693ab5f1d7d769ab4087493f0fedbb39a46f7af1601`
- Partition of PLANs 01-78: 30 completed (R4 twenty-six + 69, 70, 71, 72), 10 halted (R4 nine + 73), 38 never-executed (R4 thirty-three + 74-78). 74-78 carry blocked_by ["253-73"] and the reason "dependency 253-73 halted on a non-infrastructure runner account-count query defect"; every row carries successor_revision R5.
- Pins: sha256 of PLAN 01-88, existing SUMMARYs among 36-43/48-51/57-63/69-73, the v1/R2/R3/R4 contract files and the SDK. bundle_requires_final_summary_of is 253-88.
- Earlier contract hashes unchanged: v1 5eba0fad..., R2 dc29b096..., R3 6a50c6fe..., R4 2c335138.... `--check-only` exit codes: v1 0, r2 0, r3 0, r4 0, r5 0 (also 0 before any edit, as the positive control).

## Current `--revision r5 --check-index 253` report (read-only, expected ok:false)

`{"ok":false,"route":"dispatch_plans","old_unsummarized":38,"any_unsummarized":47}`, exit 1. The 47 are the 38 responsibilities plus 80-88 (79 already has a SUMMARY).

## Test counts

- `253-LOAD-RECOVERY-reconcile.test.mjs`: 60 pass / 0 fail / 0 skipped (RED observed first: 12 failing = 10 new R5 tests + 2 REVISIONS equality assertions in the R3/R4 suites).
- `ci-hosted-gate-verify.test.py` with Node 20.18.1 first on PATH: 44 tests OK (RED observed first: 6 failures, 1 error).

## Deviations from Plan

None - plan executed exactly as written. The edited pre-existing assertions are exactly those named: the REVISIONS equality lists (now include r5) in the R3 and R4 suites of the helper test, and in the verifier test the R4 native evidence path moved from the accepted case to the rejected list (plus the matching error-message string "R5").

## Issues Encountered

None.

## Known Stubs

None.

## Remaining gaps

Full Phase 253 verification stays not_started. No disposition SUMMARY was written to the real phase directory; dispositions are applied only by 253-88 after real accepted completion.

## Self-Check: PASSED

- Created R5 contract found; modified helper, helper test, verifier and verifier test found.
- Commits e23da0012, 4bb3f303a, c7f78119a, 64d26af7b are ancestors of HEAD; scripts/ci/__pycache__ removed; tree clean except .planning/config.json.
