---
phase: 236-closeout-evidence-reconciliation
plan: 06
subsystem: testing
tags: [elixir, exunit, git-history, audit-evidence]
requires:
  - phase: 236-05
    provides: frozen audit snapshots and a closeout scope baseline
provides:
  - Commit-scoped validation replay assertions
  - Historical Git-object audit-boundary verification
  - Adversarial snapshot-boundary coverage
affects: [phase-236-closeout, milestone-audit]
tech-stack:
  added: []
  patterns: [historical Git-object evidence verification]
key-files:
  created: []
  modified:
    - test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
    - scripts/planning/phase-236-audit-snapshot.exs
    - scripts/planning/phase-236-audit-snapshot-test.exs
key-decisions:
  - "Historical claims are checked at recorded commits, while current mutable metadata remains outside those claims."
requirements-completed: []
coverage:
  - id: D1
    description: Historical validation and audit boundaries are checked deterministically.
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
        status: pass
      - kind: integration
        ref: elixir scripts/planning/phase-236-audit-snapshot-test.exs
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-08-04
status: complete
---

# Phase 236 Plan 06: Historical Evidence Gate Summary

**Historical validation and milestone-audit evidence now verifies at recorded Git boundaries without treating mutable completion metadata as historical proof.**

## Accomplishments

- Replaced invalid current-HEAD equality with commit-scoped Phase 231 replay checks.
- Added a read-only historical audit verifier that recomputes manifests, ancestry, source digests, path scopes, and audit output digest.
- Added positive and adversarial snapshot-boundary tests, including malformed commit, manifest-link, and audit-digest inputs.

## Task Commits

1. **Task 1: Historical replay and audit boundaries** - `c1a146d5`, `fcb55894`
2. **Task 2: Retained validation replay evidence** - `c7ec527e`

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` — pass (7 tests)
- `elixir scripts/planning/phase-236-audit-snapshot-test.exs` — pass (3 tests)
- `mix format --check-formatted test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs scripts/planning/phase-236-audit-snapshot.exs scripts/planning/phase-236-audit-snapshot-test.exs` — pass

## Deviations from Plan

None - the resumed execution used the approved surgical-rebase baseline.

## Self-Check: PASSED

- All three owned implementation/test files exist in their recorded commits.
- No protected evidence artifact was edited by this plan.
