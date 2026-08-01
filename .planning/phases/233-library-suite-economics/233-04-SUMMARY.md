---
phase: 233-library-suite-economics
plan: 04
subsystem: ci
tags: [github-actions, exunit, partitioning]
requires: [233-02, 233-03]
provides: [measured-two-list-library-partitions]
affects: [233-05, TEST-02, TEST-03]
key-files:
  created: [test/support/ci/library_test_partitions.exs]
  modified: [.github/workflows/ci.yml, test/sigra/planning/phase_233_library_economics_contract_test.exs]
decisions:
  - "Use retry-free timing probe 30666977944 with stable greedy lower-total assignment."
metrics:
  tasks_completed: 2
status: complete
---

# Phase 233 Plan 04: Measured Library Partitions Summary

**Two ordinary library workers now receive deterministic cost-balanced explicit path sets derived from the retry-free timing probe.**

## Accomplishments

- Replaced Mix round-robin selection with manifest-selected paths for the existing two-leg CI matrix.
- Preserved scaffold exclusion, formatters, receipts, services, and the byte-identical Library tests aggregate.
- Added provenance, workflow wiring, and fail-closed empty/duplicate/invalid-cost contracts.

## Verification

- `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` — passed (8 tests).
- `mix format --check-formatted test/support/ci/library_test_partitions.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` — passed.

## Task Commits

1. `86f6f121` test: add failing manifest wiring contract
2. `c02c0ec0` feat: wire measured library test partitions
3. `c7454291` test: add failing partition edge contracts
4. `b9ed4855` feat: fail closed on partition drift

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the manifest, workflow wiring, and contract test exist.
- Confirmed all four TDD commits are reachable in git history.
