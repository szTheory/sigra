---
phase: 235-terminal-ratification-measured-not-read
plan: 06
subsystem: ci-evidence
tags: [fast-01, gate-05, github-actions, receipts, ownership]
requires:
  - phase: 235-05
    provides: terminal ledger
provides:
  - Byte-pinned canonical CI population and binding-pole replay receipts
  - Exhaustive ownership destination validation
affects: [FAST-01, GATE-05]
tech-stack:
  added: []
  patterns: [closed receipts, sha256 evidence binding, deterministic pole selection, workflow topology contracts]
key-files:
  created: []
  modified:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
key-decisions:
  - FAST-01 remains an honest miss: 19 PR runs, p50 772 seconds.
  - Ownership evidence is validated from Phase 234 inventory, live workflow blocks, and retained event-job bytes.
metrics:
  tasks_completed: 3
  files_modified: 2
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 06: Terminal Ratification Evidence Summary

The terminal ledger now binds its 19 PR, 2 push, and 2 schedule measurements to canonical GitHub bytes, deterministically derives median and maximum diagnoses, and validates all 93 ownership destinations against the inventory, workflow, and event receipts.

## Accomplishments

- Retained the canonical `gh run list` output with an independently pinned SHA-256 and reconciled every bounded measurement field-for-field.
- Selected the floor-median and maximum PR poles from source-bound wall durations and retained digest-checked job and metrics receipts.
- Retained each ownership event's complete job response and reject missing, mismatched, or live-but-wrong direct owners and receivers across all ownership classes.

## Task Commits

1. `789a6e46` — failing source-receipt boundary test.
2. `91c141ac` — canonical population and pole receipt implementation.
3. `5dd2de44` — ownership event receipt binding.
4. `a565aedd` — exhaustive ownership semantic contract.

## Verification

- Focused Phase 235, Phase 234 inventory, and contributor-DX contracts: 27 tests, 0 failures.
- Complete planning contracts: 110 tests, 0 failures, 12 skipped.
- `bash scripts/ci/ci-run-metrics.test.sh`: 9 passed, 0 failed.
- Ledger assertion: 93 ownership rows; FAST-01 p50 `772`, status `miss`.

## Deviations from Plan

None - CI topology and performance behavior were unchanged; FAST-01 remains an honest measured miss.

## Known Stubs

None.

## Self-Check: PASSED

- Both modified artifacts exist and all task commits are present.
- No network endpoint, authentication path, schema, or workflow behavior was introduced.
