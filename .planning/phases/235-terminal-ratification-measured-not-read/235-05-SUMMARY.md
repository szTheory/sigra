---
phase: 235-terminal-ratification-measured-not-read
plan: 05
subsystem: ci-evidence
tags: [fast-01, gate-05, receipts, ownership, closeout]
requires:
  - phase: 235-04
    provides: terminal measurement ledger and contract
provides:
  - Pinned capture metadata and retained-run identity checks
  - Digest-checked binding-pole source receipts
  - Live ci-gate ownership and composed contributor closeout validation
affects: [fast-01, gate-05]
tech-stack:
  added: []
  patterns: [immutable constants, SHA-256 receipt validation, source-bound diagnosis]
key-files:
  created: []
  modified:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
key-decisions:
  - "FAST-01 remains an honest miss at 19 retained PR runs and 772 seconds p50."
  - "ci-gate is the live aggregate job identifier; ci_gate is not accepted as a destination."
metrics:
  duration: 8m
  tasks_completed: 3
  files_modified: 2
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 05: Terminal Evidence Boundary Summary

Terminal evidence now pins capture metadata, rejects malformed retained identities, and binds each declared miss diagnosis to a digest-checked PR job receipt.

## Accomplishments

- Pinned the immutable capture instant, source command, and population digest in the terminal contract.
- Validated selected binding-pole source receipts against retained PR identities, URLs, events, timestamps, job names, conclusions, and durations.
- Corrected all `ci_gate_aggregate` live destinations to `ci-gate` and composed contributor topology validation into closeout.

## Task Commits

1. `d38206d6` — pin terminal capture boundary.
2. `930f71f9` — bind miss diagnoses to source jobs.
3. `3f980faf` — enforce terminal ownership and contributor closeout.

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — pass (13 tests).
- `bash scripts/ci/ci-run-metrics.test.sh` — pass (9 checks).
- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_198_contributor_dx_contract_test.exs` — pass (25 tests).
- `MIX_ENV=test mix test test/sigra/planning/` — pass (108 tests, 12 skipped).

## Deviations from Plan

None - plan executed without changing CI topology or the measured FAST-01 result.

## Known Stubs

None.

## Self-Check: PASSED

- Both modified artifacts exist and all three task commits are present in Git history.
- No new network endpoint, authentication path, file-access boundary, or schema surface was introduced.
