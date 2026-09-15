---
phase: 235-terminal-ratification-measured-not-read
plan: 01
subsystem: testing
tags: [exunit, ci, evidence-ledger, github-actions, json]
requires:
  - phase: 234-hygiene-supply-chain-and-contributor-dx
    provides: verified Playwright ownership inventory
provides:
  - versioned terminal ratification ledger with immutable topology cutoff
  - fail-closed ownership and pending-verdict contract
affects: [phase-235-plan-02, phase-235-plan-03, fast-01, gate-05]
tech-stack:
  added: []
  patterns: [exact JSON schema validation, inventory hash pinning, sorted ownership reconciliation]
key-files:
  created: [.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json, test/sigra/planning/phase_235_terminal_ratification_contract_test.exs]
  modified: []
key-decisions:
  - "Use the Phase 234 inventory as a hash-pinned input rather than duplicate its lane model."
  - "Keep measurements, FAST-01 verdict, and closeout explicitly pending until Plan 02 captures real runs."
requirements-completed: []
coverage:
  - id: D1
    description: Versioned terminal ledger preserves the immutable cutoff and baseline-compatible pending measurement semantics.
    requirement: FAST-01
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Complete before/after PR, push, and schedule ownership universe consumes the Phase 234 Playwright inventory and rejects malformed ownership.
    requirement: GATE-05
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
        status: pass
      - kind: integration
        ref: MIX_ENV=test mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 01: Terminal Ratification Ledger Summary

**A fail-closed, inventory-pinned terminal ledger now maps all affected CI ownership across PR, push, and schedule while reserving FAST-01 claims for measured run data.**

## Performance

- **Duration:** 6 min
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Recorded the immutable topology cutoff, exact baseline seconds, and three pending wall-mode measurement slots without inventing run data.
- Added 93 sorted before/after ownership rows: all 20 Phase 234 Playwright specs plus every required non-Playwright family and terminal aggregate.
- Added a focused ExUnit contract that rejects extra/missing schema keys, malformed cutoffs, aggregate-only execution, stale inventory entries, duplicate or incomplete event rows, and success-shaped pending measurement data.

## Task Commits

1. **Task 1: Trace one library-suite ownership row through the terminal ledger and live workflow** — `ecff2be4` (RED test), `3a076c16` (GREEN tracer)
2. **Task 2: Expand the ledger to every affected spec, suite, event, and receiver** — `1fd6b42e`

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — pass (5 tests)
- `MIX_ENV=test mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` — pass (6 tests)
- `bash scripts/ci/ci-run-metrics.test.sh` — pass (9 checks)
- `jq -e '.schema_version == "sigra.terminal-ratification/v1" and (.ownership.rows == (.ownership.rows | sort_by(.family, (.spec // ""), .event)))' .../235-TERMINAL-RATIFICATION.json` — pass

## Decisions Made

- The ledger consumes the Phase 234 inventory by literal path, schema marker, gate-input flag, and SHA-256; it never creates a competing lane inventory.
- Pending is a terminally non-success state: no measurement statistics, real run IDs, FAST-01 pass, or completed closeout can be inferred until the live capture plan runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected Elixir validation implementation details**
- **Found during:** Tasks 1 and 2
- **Issue:** The initial contract used an Elixir reserved word as a local variable, an incorrect assertion macro, and a tuple interpolation that obscured the intended stale-row diagnostic.
- **Fix:** Renamed the local binding, used `assert_raise`, and rendered duplicate row keys with `inspect/1` while prioritizing stale-inventory validation.
- **Files modified:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs`
- **Verification:** Focused Phase 235 contract passes all mutation cases.
- **Committed in:** `3a076c16`, `1fd6b42e`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** Required correctness fixes only; no scope expansion.

## Issues Encountered

Focused ExUnit runs log unavailable local PostgreSQL connections during test application startup, but the isolated planning contracts complete successfully and do not require a database.

## Next Phase Readiness

Plan 02 can now populate the immutable measurement slots with live, post-cutoff run receipts. FAST-01 and GATE-05 remain deliberately unmarked until that evidence and the later closeout are complete.

## Self-Check: PASSED

- Both key files exist and all three task commits are present in Git history.
