---
phase: 236-closeout-evidence-reconciliation
plan: "08"
subsystem: testing
tags: [elixir, exunit, git-provenance, scope-fence, audit-evidence]
requires:
  - phase: 236-07
    provides: fixed historical evidence provenance and the original shared scope fence
provides:
  - Fail-closed per-commit Git-range collection for Plan 06 and Plan 07 execution paths
  - Changed-then-restored forbidden-path regression coverage in an isolated temporary repository
  - Immutable Plan 07 completion range boundary
affects: [phase-236-closeout, audit-provenance, planning-evidence]
tech-stack:
  added: []
  patterns:
    - Enumerate every commit before collecting and deduplicating its changed paths.
    - Reject nonzero Git command exits rather than accepting partial scope results.
key-files:
  created:
    - .planning/phases/236-closeout-evidence-reconciliation/236-08-SUMMARY.md
  modified:
    - test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
key-decisions:
  - "Committed execution ranges use rev-list plus per-commit diff-tree, not endpoint-tree differences."
  - "Plan 07 ends at its immutable 287065751e2ed44d39d112801a06503de740e45d completion commit."
  - "The existing five-entry scope allowlist remains the sole authority for committed and worktree paths."
metrics:
  duration: 5m
  completed: 2026-08-04
  tasks_completed: 1
  files_modified: 1
status: complete
---

# Phase 236 Plan 08: Closeout Evidence Reconciliation Summary

**The Phase 236 scope fence now rejects every forbidden path touched in a committed range, including paths restored before the endpoint.**

## Accomplishments

- Replaced endpoint-only range inspection with a sorted, deduplicated union of `git rev-list from..to` commit paths collected by `git diff-tree --no-commit-id --name-only -r`.
- Made enumeration and per-commit collection fail closed with contextual `ArgumentError` diagnostics on nonzero Git exits.
- Added a deterministic temporary-repository regression proving an allowed-plus-forbidden intermediate change remains visible after the forbidden file is restored at the endpoint.
- Pinned Plan 07 range verification to completion commit `287065751e2ed44d39d112801a06503de740e45d`; later bookkeeping cannot affect the audited range.
- Kept the original five-path `@scope_allowlist` unchanged and applied it to Plan 06, Plan 07, tracked, and untracked path collectors.

## Task Commits

1. **Task 1: Reject restored forbidden paths across committed execution ranges** — `8f7d7e27` (`test`, RED) and `b8d27fef` (`fix`, GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only scope_fence` — passed: 1 test, 0 failures.
- `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` — passed: 9 tests, 0 failures.
- `mix format --check-formatted test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` — passed.
- `git diff --check` — passed.

## Decisions Made

- Per-commit collection is the required scope-fence mechanism because endpoint-tree diffs cannot reveal transient forbidden mutations.
- The historic Plan 07 end SHA is fixed to its already-committed completion rather than `HEAD`.

## Deviations from Plan

### Execution-environment reconciliation

The orchestrator-provided Phase 236 `STATE.md` start-tracking edit was outside the unchanged five-path scope allowlist, so the full contract correctly rejected the dirty worktree. Under coordinator direction it was committed separately as `f27e9325` before final verification; the allowlist was not widened and no protected evidence was changed.

**Impact:** None on the Plan 08 implementation or D-05 evidence boundary.

## Known Stubs

None.

## Self-Check: PASSED

- The hardened contract test and this summary exist.
- Task commits `8f7d7e27` and `b8d27fef` exist in Git history.
- All specified deterministic verification commands passed.
