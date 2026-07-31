---
phase: 233-library-suite-economics
plan: 01
subsystem: testing
tags: [exunit, github-actions, ci, timing, deterministic-json]
requires:
  - phase: 230-tier-1-critical-path-reclamation
    provides: two-partition library shard and required-check topology
provides:
  - Same-run deterministic ExUnit timing receipts for ordinary library shards
  - Parallel shard command with retained CI timing artifacts
affects: [233-02, 233-03, ci-workflow]
tech-stack:
  added: []
  patterns: [additive ExUnit formatter, fixed CI-owned artifact paths, fail-closed timing publication]
key-files:
  created: [test/support/ci/ex_unit_timing_formatter.ex, test/support/ci/ex_unit_timing_formatter_test.exs, test/sigra/planning/phase_233_library_economics_contract_test.exs]
  modified: [.github/workflows/ci.yml, .planning/phases/233-library-suite-economics/233-VALIDATION.md]
key-decisions:
  - "Keep ExUnit.CLIFormatter and add Sigra.CI.ExUnitTimingFormatter in the same parallel mix test invocation."
  - "Permit timing writes only to the three fixed /tmp receipt paths and fail publication when the receipt is absent."
patterns-established:
  - "CI timing artifacts are deterministic JSON with stable ordering and no wall-clock fields."
requirements-completed: [TEST-01]
coverage:
  - id: D1
    description: Same-run parallel library shard writes and retains a deterministic timing receipt.
    requirement: TEST-01
    verification:
      - kind: unit
        ref: mix test test/support/ci/ex_unit_timing_formatter_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-07-31
status: complete
---

# Phase 233 Plan 01: Parallel Timing Receipt Summary

**Parallel ordinary library shards now preserve CLI output while emitting deterministic, same-run JSON timing receipts retained as CI artifacts.**

## Accomplishments

- Added `Sigra.CI.ExUnitTimingFormatter`, an additive formatter that collects completed ExUnit events and atomically writes stable JSON receipts.
- Removed the serializing `--slowest` command path; the two existing shard legs now run one parallel `mix test` process with both formatters.
- Added fail-closed job-summary and artifact publication, plus focused formatter and bounded workflow-contract coverage.

## Task Commits

1. Task 1 RED — `6e2a076d` test: add failing timing receipt tests
2. Task 1 GREEN — `35f82758` feat: publish parallel shard timing receipts
3. Task 1 assertion refinement — `a5844c26` test: scope shard invocation assertion
4. Task 2 RED — `ddf4e0a7` test: cover timing receipt failure edges
5. Task 2 GREEN — `f41dd913` feat: harden timing receipt validation

## Files Created/Modified

- `test/support/ci/ex_unit_timing_formatter.ex` — deterministic ExUnit event receipt formatter with fixed-path validation.
- `test/support/ci/ex_unit_timing_formatter_test.exs` — receipt lifecycle, ordering, empty, malformed-event, and path-safety tests.
- `test/sigra/planning/phase_233_library_economics_contract_test.exs` — bounded CI job contract tests.
- `.github/workflows/ci.yml` — parallel formatter invocation, fail-closed summary, and retained shard artifacts.
- `.planning/phases/233-library-suite-economics/233-VALIDATION.md` — marks the TEST-01 Wave 0 proof green.

## Decisions Made

- Retained `ExUnit.CLIFormatter` and added the receipt formatter through the same test command, so timing provenance is the exact parallel run.
- Encode JSON in explicit field order and sort tests by duration then lexical identity, avoiding non-deterministic map serialization.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Normalized actual ExUnit completion states.
- **Found during:** Task 2
- **Issue:** The first formatter implementation modeled synthetic atom outcomes, while real ExUnit completion events use `nil` and tagged tuples.
- **Fix:** Normalized the documented ExUnit state shapes and recorded each aggregate outcome count.
- **Files modified:** `test/support/ci/ex_unit_timing_formatter.ex`, `test/support/ci/ex_unit_timing_formatter_test.exs`
- **Verification:** Focused formatter and workflow-contract command passed.
- **Committed in:** `f41dd913`

## Known Stubs

None.

## Issues Encountered

Focused tests pass locally. The shared test helper logs unavailable local PostgreSQL connections during startup, but these formatter and workflow-contract tests do not require the database and had no skipped assertions.

## Next Phase Readiness

Plans 02 and 03 can consume the fixed receipt schema and artifact names for measured shard balancing and scaffold-lane extraction.

## Self-Check: PASSED

- Confirmed all five task commits exist and all five planned artifacts are present.
