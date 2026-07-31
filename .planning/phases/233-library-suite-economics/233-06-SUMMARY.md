---
phase: 233-library-suite-economics
plan: 06
subsystem: ci
tags: [github-actions, exunit, manifest-validation, test-selection]
requires:
  - phase: 233-library-suite-economics
    provides: measured two-shard ordinary test manifest and scaffold receiver
provides:
  - fail-closed reconciliation of shard partitions against the live eligible test universe
  - status-preserving CI selector capture with non-empty argv guards
affects: [library_tests_shard, library_tests]
tech-stack:
  added: []
  patterns: [Mix test_load_filters, receipt-derived assignment, deterministic shell harness]
key-files:
  created: []
  modified:
    - test/support/ci/library_test_partitions.exs
    - test/sigra/planning/phase_233_library_economics_contract_test.exs
    - .github/workflows/ci.yml
decisions:
  - "Live discovery validates the measured receipt-derived partitions but never assigns an unmeasured path or changes two-shard economics."
metrics:
  duration: 5m
  completed: 2026-07-31
status: complete
---

# Phase 233 Plan 06: Manifest Drift Closure Summary

Library shard selection now fails before `mix test` if the measured two-partition manifest differs from the current Mix-filtered ordinary test universe.

## Tasks Completed

1. Added a RED on-disk unmeasured-test regression, then made partition construction reconcile the receipt-derived lists against live eligible paths and preserve CI selector failures.
2. Added deterministic contracts for filters, exact scaffold subtraction, stale/duplicate/leaking ownership, tie ordering, and failing/successful selector transport.

## Verification

- `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` — 14 tests passed.
- `mix test test/support/ci/ex_unit_timing_formatter_test.exs` — 5 tests passed.
- `mix format --check-formatted test/support/ci/library_test_partitions.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` — passed.
- Production selector reconciliation — passed for 211 ordinary paths; both partitions were non-empty, disjoint, and their sorted union matched live discovery.

## Decisions Made

- `Mix.Project.config()[:test_load_filters]` is the sole eligibility authority; discovered scaffold paths are subtracted only after confirming all six canonical paths are eligible.
- Receipt costs remain the only assignment source. A new ordinary file blocks CI with sorted missing/stale diagnostics until evidence is refreshed.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all three modified implementation files exist and task commits `a25f2d1e`, `fbcf1a46`, and `e066d069` are present.
