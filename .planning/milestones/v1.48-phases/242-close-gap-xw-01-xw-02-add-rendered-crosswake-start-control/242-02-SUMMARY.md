---
phase: 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
plan: "02"
subsystem: testing
tags: [crosswake, ecto, sql-sandbox, postgres, security, xw-01, xw-02]
requires:
  - phase: 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
    provides: rendered Crosswake start control and role-driven browser proof
provides:
  - Sandbox-local continuation cleanup evidence unaffected by shared test-database residue
  - A passing adapter, continuation, controller, and P14 Crosswake security matrix
affects: [XW-01, XW-02, phase-242-verification]
tech-stack:
  added: []
  patterns: [sandbox-local-test-baseline, bounded-terminal-cleanup-proof]
key-files:
  created: []
  modified:
    - test/example/test/example/accounts/crosswake_continuations_test.exs
key-decisions:
  - Clear only transaction-visible continuation rows after ConnCase checks out the SQL sandbox.
  - Retain the exact two-row postcondition and live-claim completion proof after bounded cleanup.
requirements-completed: [XW-01, XW-02]
coverage:
  - id: D1
    description: Transaction-local cleanup setup preserves deterministic bounded continuation cleanup evidence.
    requirement: XW-02
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/example/accounts/crosswake_continuations_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: The unchanged Crosswake security matrix completes with real and fail-first P14 controls.
    requirement: XW-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test adapter/continuation/controller --include example_app; node --test P14 real/bad/clean
        status: pass
    human_judgment: false
metrics:
  duration: 5m
  completed_date: 2026-08-12
  tasks_completed: 1
  files_changed: 1
status: complete
---

# Phase 242 Plan 02: Isolate Continuation Cleanup Evidence Summary

**The Crosswake continuation cleanup proof now resets only sandbox-visible rows, preserving the exact 500-row bound and live-claim path regardless of committed test-database residue.**

## Accomplishments

- Added module setup after `ExampleWeb.ConnCase` sandbox checkout to delete and assert an empty transaction-local `CrosswakeContinuation` baseline.
- Preserved the existing cleanup scenario: 501 expired rows plus one live continuation, exactly 500 deletions, exactly two remaining rows, and successful evaluator completion of the live claim.
- Restored deterministic XW-01/XW-02 evidence: the focused suite and aggregate adapter/continuation/controller/P14 real-bad-clean matrix pass without production changes.

## Verification

- RED: before the change, `MIX_ENV=test mix test test/example/accounts/crosswake_continuations_test.exs` failed the cleanup postcondition (`expected 2`, observed `5`) with shared-database continuation residue.
- `MIX_ENV=test mix format --check-formatted test/example/accounts/crosswake_continuations_test.exs` — passed.
- `MIX_ENV=test mix test test/example/accounts/crosswake_continuations_test.exs` — passed (6 tests).
- Aggregate adapter/continuation/controller command with `--include example_app` — passed (28 tests).
- P14 repository fixture — passed; known-bad fixture — failed as required; clean fixture — passed.

## Task Commits

1. **Task 1: Isolate the continuation cleanup proof and pass the complete Crosswake matrix** — `cb89fc32` (`test`)

## Files Created/Modified

- `test/example/test/example/accounts/crosswake_continuations_test.exs` — establishes the sandbox-local continuation-row baseline before every test.

## Decisions Made

- Keep cleanup isolation test-local and transaction-scoped; production cleanup semantics, schema, controller, browser proof, and P14 guard remain unchanged.
- Keep the exact two-row assertion rather than weakening it to a baseline-relative count, because module setup establishes the baseline deterministically.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The aggregate test command emitted existing unrelated compiler warnings for `/dev/mailbox` verified routes and an unused controller-test module attribute; the specified suites still completed successfully.

## Known Stubs

None.

## Threat Flags

None. The only changed surface is a transaction-local test setup; no production endpoint, authority path, schema, or file access pattern changed.

## Self-Check: PASSED

- Confirmed the modified continuation test file exists.
- Confirmed task commit `cb89fc32` resolves in git history.

