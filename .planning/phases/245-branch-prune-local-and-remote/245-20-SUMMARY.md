---
phase: 245-branch-prune-local-and-remote
plan: "20"
subsystem: testing
tags: [git, refs, branch-prune, verifier, disposable-fixtures]

requires:
  - phase: 245-18
    provides: immutable current PR/ref identities and D-07 source contract
  - phase: 245-19
    provides: blocked transition receipt and one already-applied local deletion
provides:
  - operation-stage readback for exact cumulative allowlisted ref removals
  - final-child verification bound to observed removals and declared result dispositions
affects: [245-21, REPO-04]

actuals:
  tokens: 6882
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns: [separate operation readback from final evidence-child validation, compare cumulative ref deltas to a committed allowlist]

key-files:
  created: []
  modified:
    - scripts/maintainers/prune-stale-branches-current.mjs
    - scripts/maintainers/prune-stale-branches-current.test.mjs
    - scripts/maintainers/prune-stale-branches.sh

key-decisions:
  - "Operation readback accepts only the exact cumulative removed refs while the committed contract remains HEAD."
  - "The final result child must declare the same ref set and allowlist side as the observed delta."

patterns-established:
  - "Operation-stage checks can run before a final child exists; after-stage remains reserved for the sole direct result child."
  - "A prior admitted local deletion is included exactly once in each cumulative applied-ref set."

requirements-completed: []
coverage:
  - id: D1
    description: "Operation readback permits only cumulative allowlisted deletions before final evidence exists."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "scripts/maintainers/prune-stale-branches-current.test.mjs#D-07 retains the prior local deletion once across two cumulative tracking readbacks and final child"
        status: pass
    human_judgment: false
  - id: D2
    description: "The sole direct final child must match the observed ref delta, allowlist side, and any declared expected OID."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "scripts/maintainers/prune-stale-branches-current.test.mjs#D-07 final result ref side and OID must match the committed allowlist disposition"
        status: pass
    human_judgment: false

duration: 19min
completed: 2026-09-30
status: complete
---

# Phase 245 Plan 20: Operation Readback Summary

**The branch-prune verifier now separates cumulative operation readback from final-child validation and binds each declared deletion to its committed allowlist disposition.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-09-30T20:15:54Z
- **Completed:** 2026-09-30T20:34:22Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added an operation stage that checks the exact cumulative allowlisted refs removed while the committed contract remains HEAD.
- Updated the operator to pass applied refs into immediate readbacks while the shared coordinator lock and pinned Git runtime are active.
- Bound the final direct child to the observed delta, result-side classification, and optional expected OIDs; disposable fixtures cover prior local deletion plus sequential tracking removals.

## Task Commits

1. **Task 1: Prove one operation readback through verifier and operator**
   - `8a2efb32` — failing operation-readback test
   - `ae4edc60` — verifier/operator operation-stage implementation
2. **Task 2: Bound cumulative readbacks and the final result child**
   - `76c7c9ff` — failing final-disposition test
   - `c1dfec90` — final result side/OID enforcement

## Files Created/Modified

- `scripts/maintainers/prune-stale-branches-current.mjs` — validates cumulative operation deltas and final result dispositions.
- `scripts/maintainers/prune-stale-branches-current.test.mjs` — adds disposable repository fixtures for one and multiple operations, prior local deletion, incomplete/unlisted deltas, and result mismatches.
- `scripts/maintainers/prune-stale-branches.sh` — passes cumulative applied refs into locked operation readbacks.

## Decisions Made

- Operation readback and final-child validation remain separate stages so an in-progress operation cannot be reported as complete.
- The Plan 19 local deletion remains in the cumulative disposition set exactly once; this plan did not repeat it or perform any production ref operation.

## TDD Gate Compliance

- Task 1 RED: `RED_EVIDENCE_OK` for the operation-stage test; GREEN: `ae4edc60`.
- Task 2 RED: `RED_EVIDENCE_OK` for final result side/OID mismatch; GREEN: `c1dfec90`.
- No REFACTOR commit was needed. The specified deterministic suites passed after each implementation stage.

## Deviations from Plan

None. Result-side and expected-OID checks are part of Task 2's final disposition contract.

## Issues Encountered

- The workspace sandbox initially denied writes to `.git` for the plan ledger and index. The authorized Git commits succeeded after requesting the required sandbox escalation. The GSD roadmap helper did not recognize the project's existing phase-row format, so the Plan 20 checklist and count were updated directly. No working-tree files were reset, stashed, cleaned, or discarded.

## Verification

- `node --test scripts/maintainers/prune-stale-branches-current.test.mjs` — passed (10 tests).
- `bash scripts/maintainers/prune-stale-branches.test.sh` — passed.
- The Plan 19 contract and blocked receipt were read-only checked against the pinned blob IDs and SHA-256 values in `245-20-GAP-PREFLIGHT.json` before implementation.

## Next Phase Readiness

Plan 21 can start with a fresh D-06 preflight and must retain the D-01 through D-07 production gates. No Plan 21 execution evidence or production ref operations were performed here. REPO-04 remains open pending Plan 21's complete current-state proof.

## Self-Check: PASSED

- Summary file exists.
- All four plan task commits exist and are measured in the plan commit ledger.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-30*
