---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: 14
subsystem: ci-evidence
tags: [nyquist, evidence, exunit, supply-chain, validation]
requires:
  - phase: 234-hygiene-supply-chain-and-contributor-dx
    provides: contributor, action-pinning, Dependabot, Playwright, and GitHub receipts
provides:
  - Fail-closed parser for the exact Phase 234 focused-contract inventory
  - Machine-checked draft-state gate for missing/red evidence and command receipts
affects: [phase-234-validation, phase-235, ci-evidence]
tech-stack:
  added: []
  patterns: [pre-mutation validation parsing, immutable receipt hashes, fail-closed status transitions]
key-files:
  created: []
  modified:
    - .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md
    - test/sigra/planning/phase_234_evidence_contract_test.exs
key-decisions:
  - "Validation remains draft until both managed-service and repository verification residuals become green."
  - "Command output is represented by sanitized SHA-256 receipts rather than captured logs or environment data."
patterns-established:
  - "Completion frontmatter transitions are data-gated: all required slots and command receipts must be green."
requirements-completed: []
coverage:
  - id: D1
    description: Exact quick-run and Wave 0 inventory parser rejects stale paths and pending evidence before sign-off.
    verification:
      - kind: unit
        ref: mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff
        status: pass
    human_judgment: false
  - id: D2
    description: Missing or red evidence and nonzero verification receipts retain draft/false validation frontmatter.
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_234_evidence_contract_test.exs#missing or red evidence and command receipts force every completion field to remain false
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-08-02
status: complete
---

# Phase 234 Plan 14: Fail-Closed Validation Sign-Off Summary

**Phase 234 now machine-checks its exact evidence inventory and refuses a completion claim while Dependabot receipts and the golden fixture verification remain red.**

## Performance

- **Duration:** 8 min
- **Tasks:** 1/1
- **Files modified:** 2

## Accomplishments

- Added a pre-mutation parser for the six focused contracts, Wave 0 checklist, task-map rows, command receipts, and approval state.
- Added stale-path and all-slot mutation coverage that permits `complete/true/true` only for a fully green evidence and command set.
- Recorded sanitized hashes for the focused contracts, planning suite, formatter, and golden/idempotency verification.

## Task Commits

1. **Task 1: Fail closed, then ratify the validation artifact** — `d0e9f528` (test)

## Files Created/Modified

- `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md` — completed inventory/checklist accounting, command receipts, and explicit blocked approval.
- `test/sigra/planning/phase_234_evidence_contract_test.exs` — validation parser plus stale, missing, and red receipt transition tests.

## Decisions Made

- Kept `status: draft`, `nyquist_compliant: false`, and `wave_0_complete: false`; the guard owns the transition and the evidence is not green.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Corrected the sign-off assertion to compare only transition frontmatter fields.**
- **Found during:** Task 1
- **Issue:** Validation frontmatter also includes phase metadata, so an equality assertion against only three fields failed.
- **Fix:** The contract now takes the three completion fields before evaluating the transition.
- **Files modified:** `test/sigra/planning/phase_234_evidence_contract_test.exs`
- **Verification:** Focused `validation_signoff` suite passes.
- **Committed in:** `d0e9f528`

## Issues Encountered

- Dependabot evidence is still explicitly failed: no authenticated GitHub browser session was available to capture all three ecosystem job logs.
- `mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` exits 1: generated `config/dev.exs` is 2,679 bytes versus the committed 3,252-byte fixture. This is recorded as a validation residual; no fixture or generator changes were in Plan 14 scope.

## Known Stubs

None.

## Next Phase Readiness

The evidence guard is ready to transition the validation only after the Dependabot job-log receipts and golden fixture verification succeed. Phase 234 must not be represented as Nyquist-complete before then.

## Self-Check: PASSED

- Task commit `d0e9f528` exists.
- Validation artifact and evidence-contract test exist at their recorded paths.

