---
phase: 255-make-failures-reproducible-and-report-the-result
plan: "01"
subsystem: infra
tags: [ci, offline-replay, python, immutable-inputs]
status: complete
requires:
  - phase: 254
    provides: Preserved original before/after attempts and repaired analysis
provides:
  - Exact saved-input comparison replay with pinned tools
  - Complete validated portable input package
  - Real-input and hostile archive regression tests
affects: [255-02, 255-07]
actuals:
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [Pinned Git blobs, temporary replay roots, network command denial]
key-files:
  created:
    - scripts/ci/ci-comparison-replay.py
    - scripts/ci/ci-comparison-replay.test.py
    - .planning/execution/255-replay/PREFLIGHT.json
    - .planning/execution/255-replay/INPUTS.json
    - .planning/execution/255-replay/RESULT.json
    - .planning/execution/255-replay/input-package.tar.gz
  modified: []
key-decisions:
  - Keep raw evaluator JSON separate from Phase 254 closeout annotations.
  - Pin calculated expected output to its later closeout commit separately from analysis.
requirements-completed: [CIMEAS-03]
coverage:
  - id: D1
    description: Original saved inputs recalculate the exact insufficient-data result without changing originals
    requirement: CIMEAS-03
    verification:
      - kind: integration
        ref: python3 -B scripts/ci/ci-comparison-replay.test.py
        status: pass
    human_judgment: false
  - id: D2
    description: Portable package validates its complete input closure and rejects missing, altered or unsafe files
    requirement: CIMEAS-03
    verification:
      - kind: integration
        ref: python3 -B scripts/ci/ci-comparison-replay.test.py
        status: pass
      - kind: integration
        ref: bash scripts/ci/ci-run-metrics-comparison.test.sh
        status: pass
    human_judgment: false
completed: 2026-10-24
---

# Phase 255 Plan 01: Saved comparison replay

The original failed baseline and successful candidate recalculate to the exact saved evaluator JSON, using pinned analysis in a temporary directory with network commands denied.

## Accomplishments

- First execution record resolved both measured commits, analysis and preserved evidence; all 69 before and 109 after receipt entries matched their Git bytes. Its original bytes remain committed at `db2026073:.planning/execution/255-replay/PREFLIGHT.json`.
- The package contains 191 unique verified files: receipts, captured run/job/artifact/producer data, contract, registrations, baseline archive, workload map, pinned calculators and their transitive helpers, and fallback timing input. Each member records Git commit/blob, size and SHA-256.
- Replay returns `insufficient_data`, zero comparable successful pairs, four null median/p95 values and 2046/1589 runner-seconds. It retains baseline failure, candidate success, generic missing-before-family diagnostics and exactly one successful origin check. No speed improvement is claimed.
- Input copies are verified before and after calculation. The real-input test also hashes original local saved files before/after. No collection driver or hosted request is invoked.

## Task Commits

| Task | RED | GREEN |
|---|---|---|
| 255-01-01 | db2026073 | 89e36b7a4 |
| 255-01-02 | ac0df6350 | 66ce9052f |

Both RED records contain complete real unittest reports and passed `tdd-red-evidence`. The tests executed and failed assertions for the absent replay/pack command behavior; no fixture, import or discovery errors were used as RED evidence. No refactor commit was needed.

## Verification

- `python3 -B scripts/ci/ci-comparison-replay.test.py`: 6 tests passed. Includes an empty-directory package replay, missing receipt blob, changed helper, omitted timing input, literal null-family costs and unsafe archive entries.
- `python3 -B scripts/ci/ci-metrics-security.test.py`: 23 tests passed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh`: PASS.
- Actual `preflight`, `replay --from-evidence`, `pack`, and `replay --package` commands succeeded. Final package replay JSON equals `EVALUATION-COSTS.json`; before/after input digests agree.
- `git diff --check`: passed.
- Package SHA-256: `6d098e9bee2d28b0d88dda2c517503467448939b4e48af84bf6e2ffd5255fe23`.

## Deviations from Plan

The frozen single-pair inputs are evaluated directly rather than assembled: the existing assembly function requires successful-family metadata, which the failed baseline never produced. Manufacturing that metadata would alter the original observations. The existing evaluator consumes both original snapshots directly and reproduces the exact result. Expected output is pinned at closeout `9e944b90b0f7914246017ac4c834470988eb2673`, because it was calculated after analysis commit `d5b7300c809ce7cd474e87aa55fda278b3a09cbc`.

## Issues Encountered

No outstanding implementation blocker. Package construction and local replay do not establish remote availability; Plan 07 must publish/retrieve the exact bytes and prove independent replay. CIMEAS-03 stays open until that work and phase verification pass.

## Next Phase Readiness

Plan 02 can use the ready saved-input preflight. Plans 02–07 remain unimplemented. Phase 255 verification has not run. Historical Phase 254 speed requirements remain open; no allowance or comparison window was renewed.

## Self-Check: PASSED

All declared local artifacts exist; both tasks have RED and GREEN commits on the active branch. Actual package replay, exact semantic comparison and required regression commands passed.
