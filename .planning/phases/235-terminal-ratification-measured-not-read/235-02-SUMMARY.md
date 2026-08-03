---
phase: 235-terminal-ratification-measured-not-read
plan: 02
subsystem: ci-evidence
tags: [github-actions, ci-metrics, fast-01, gate-05, exunit]
requires:
  - phase: 235-01
    provides: fail-closed terminal ownership ledger and immutable cutoff
provides:
  - bounded post-cutoff PR, push, and schedule measurement receipts
  - strict FAST-01 result with binding-pole diagnosis
affects: [235-03-closeout, fast-01, gate-05]
tech-stack:
  added: []
  patterns: [immutable CI observation window, wall-mode provenance, strict threshold comparator]
key-files:
  created: []
  modified:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
key-decisions:
  - "FAST-01 is a miss because the measured PR p50 of 772 seconds is not strictly less than 720 seconds."
  - "Keep Plan 03 record reconciliation pending; the terminal measurements are ready but do not rewrite the target."
requirements-completed: []
duration: 9min
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 02: Terminal Measurement Capture Summary

**A sealed 19-run PR window measured a 772-second p50, honestly recording FAST-01 as a miss with re-fetchable binding-pole evidence.**

## Accomplishments

- Captured all terminal runs from the immutable `2026-08-01T02:06:30Z` cutoff through `2026-08-02T18:07:04Z`: 19 pull requests, 2 pushes, and 2 schedules, retaining failures.
- Stored the literal wall-mode commands, metric output hashes, public run metadata, and representative same-window ownership receipts.
- Applied the strict `< 720` comparison without success-only filtering: PR p50 is 772 seconds, 866 seconds below baseline but 52 seconds above target.
- Attached one `--jobs` receipt for the median-neighbor run (Library tests shard, 682s) and one for the maximum run (admin-checkpoints Playwright shard, 1062s).

## Task Commits

1. **Task 1: Capture one immutable PR, push, and schedule window with real run IDs** — `e423bb1d` (RED), `82f54a61` (GREEN)
2. **Task 2: Compute the strict FAST-01 verdict and diagnose any measured miss** — `6ebe4f58` (RED), `e2370fdc` (GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — pass (7 tests)
- `bash scripts/ci/ci-run-metrics.test.sh` — pass (9 checks)
- Final jq verdict assertion — pass; the evidence-backed miss branch is present.

## Measured Result

| Event | Runs | p50 seconds | Outcomes |
| --- | ---: | ---: | --- |
| pull_request | 19 | 772 | 13 success / 6 non-success |
| push | 2 | 1439 | 1 success / 1 non-success |
| schedule | 2 | 1546 | 0 success / 2 non-success |

FAST-01 remains unmet: 772 is not less than 720. GATE-05 ownership rows have live same-window receipts; records reconciliation remains for Plan 03.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the capture-contract command matcher**
- **Found during:** Task 1 verification
- **Issue:** The first validator did not recognize the plan-mandated quoted `--since` timestamp.
- **Fix:** Matched the exact quoted literal command form emitted during capture.
- **Files modified:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs`
- **Verification:** Focused contract and metrics self-test pass.

## Known Stubs

None.

## Self-Check: PASSED

- Both modified key files exist.
- All four task commits are present in Git history.
