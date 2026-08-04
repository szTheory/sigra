---
phase: 236-closeout-evidence-reconciliation
plan: "07"
subsystem: testing
tags: [elixir, exunit, git-provenance, audit-evidence, scope-fence]
requires:
  - phase: 236-06
    provides: historical audit-boundary verification and retained-evidence contract
provides:
  - Historical audit verification bound to exact committed snapshot bytes
  - Forged self-consistent snapshot-pair regression coverage
  - Exact Plan 06/Plan 07 Git-history scope fence with one allowlist
affects: [phase-236-closeout, audit-provenance, planning-evidence]
tech-stack:
  added: []
  patterns:
    - Resolve and pin commit identities before reading caller-controlled evidence.
    - Use one explicit allowlist for committed, tracked, and untracked scope collections.
key-files:
  created:
    - .planning/phases/236-closeout-evidence-reconciliation/236-07-SUMMARY.md
  modified:
    - scripts/planning/phase-236-audit-snapshot.exs
    - scripts/planning/phase-236-audit-snapshot-test.exs
    - test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
key-decisions:
  - "The exact committed input and output blobs, rather than caller JSON, are authoritative historical evidence."
  - "Plan 07 pins its already-existing one-path introduction commit in the later contract to avoid self-reference."
patterns-established:
  - "Historical evidence checks authenticate raw bytes before decoding or validating content."
  - "Scope fences fail closed across Git history, tracked edits, and untracked files with one allowlist."
requirements-completed: []
coverage:
  - id: D1
    description: Historical snapshot verification rejects forged self-consistent caller documents.
    verification:
      - kind: unit
        ref: scripts/planning/phase-236-audit-snapshot-test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Plan 06 and Plan 07 history and scope are pinned to exact committed boundaries.
    verification:
      - kind: integration
        ref: test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-08-04
status: complete
---

# Phase 236 Plan 07: Closeout Evidence Reconciliation Summary

**Historical audit verification now authenticates exact committed snapshot bytes, with a forged-pair regression and an exact Git-history scope fence.**

## Accomplishments

- Pinned historical verification to the full freeze SHA `22dfd0880967dd84cdee153fa9b1dd1b083f83f5` and audit SHA `a523575d4fb40baac371112d5a4476db5b153ae7` before any evidence read or decode.
- Bound diagnostic caller files to fixed snapshot blobs from those commits, rejecting a wholly forged but internally consistent pair.
- Added the Plan 06 amendment/execution-chain and Plan 07 introduction-boundary contract, using one five-path allowlist for all scope collections.

## Task Commits

1. **Task 1: Bind historical snapshots to committed blobs** — `7bc7dae8` (`fix`)
2. **Task 2: Ratify the rewritten Plan 06 boundary and seal one identical scope fence** — `572f8034` (`test`)

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` — 8 tests, 0 failures.
- `elixir scripts/planning/phase-236-audit-snapshot-test.exs` — 3 tests, 0 failures.
- `mix format --check-formatted test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs scripts/planning/phase-236-audit-snapshot.exs scripts/planning/phase-236-audit-snapshot-test.exs` — passed.
- `git diff --check` — passed.

## Files Created/Modified

- `scripts/planning/phase-236-audit-snapshot.exs` — authenticates fixed Git blobs before decoding caller evidence.
- `scripts/planning/phase-236-audit-snapshot-test.exs` — tests wrong pins and a forged replacement pair.
- `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` — validates exact history and scope boundaries.

## Decisions Made

- Caller file paths remain CLI-compatible diagnostic inputs, but cannot substitute for the committed snapshots.
- The separately committed Plan 07 introduction SHA is asserted only later, avoiding an impossible self-referential planning commit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The plan's clean-worktree and scope-fence prerequisites were restored before Task 2 after an unrelated tracking commit was initially in the fenced range. The final history places that tracking commit before the one-path Plan 07 introduction boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The hardened provenance and scope contracts are committed and ready for final Phase 236 verification.

## Self-Check: PASSED

- All three planned implementation/test files and this summary exist.
- Task commits `7bc7dae8` and `572f8034` exist in Git history.
