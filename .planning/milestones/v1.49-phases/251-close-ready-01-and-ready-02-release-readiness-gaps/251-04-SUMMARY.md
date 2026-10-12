---
phase: 251-close-ready-01-and-ready-02-release-readiness-gaps
plan: 04
subsystem: release-readiness
tags: [readiness, source-evidence, package-checks, tdd]
requires:
  - phase: 251-01
    provides: Fresh Phase 251 source-feasibility packet and Phase 247 owner report.
  - phase: 251-02
    provides: Source-derived milestone audit and Phase 250 historical exception boundary.
provides:
  - Explicit check-to-source paths and digest-bound assertions for all 14 READY-01 package/adopter checks.
  - Independent milestone-audit validation of each READY-01 check source reference and assertion.
affects: [release-readiness, milestone-audit]
actuals:
  tokens: 8581
  tasks: 2
  commits: 4
  plan_head_before: 66ccf94d75720fabf4e1b1c6255a161a0c6b28b1
  plan_head_after: 27cff3b40c1d97be9e89ff7a91e365985b35698a
tech-stack:
  added: []
  patterns: [named per-check source references, independent exact-source audit joins]
key-files:
  created:
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-04-task1-red-evidence.json
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-04-task2-red-evidence.json
  modified:
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs
key-decisions:
  - "Keep READY-01 and READY-02 unsatisfied until their original owner evidence bars are proven."
  - "Require exact source identity, path, blob OID, SHA-256, and named assertions; generic check prose cannot establish acceptance."
  - "Keep the milestone audit's package-source mapping independent from the owner evaluator."
patterns-established:
  - "Each passing package check carries exact source_refs and source_assertions joined to trusted source records."
requirements-completed: []
coverage:
  - id: D1
    description: "Owner and audit validators reject READY-01 package checks that cite the wrong source path, commit, blob, digest, or assertion."
    verification:
      - kind: unit
        ref: ".planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs — 42 tests"
        status: pass
      - kind: unit
        ref: ".planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs — focused source-binding cases, 4 tests"
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-10-11
status: complete
---

# Phase 251 Plan 04: Bind READY-01 Package Checks to Exact Source Evidence

**All 14 READY-01 package/adopter checks now require their mapped immutable candidate or published-tag records and matching source assertions in both owner and audit validators.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-10-11T22:14:37Z
- **Completed:** 2026-10-11T22:19:47Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added a named source-path contract and digest-bound source assertions for all 14 READY-01 checks.
- Made the owner evaluator reject mismatched paths, commits, blob OIDs, SHA-256 values, and assertion identities.
- Made the independent milestone audit recompute those joins and preserve exact-tag missing-guide evidence as a blocker.
- Captured and machine-validated RED evidence for both regressions.

## Task Commits

1. **Task 1 RED:** `b47dfb6b4` — reproduce a published-guide check citing candidate guide bytes.
2. **Task 1 GREEN:** `409135a16` — bind owner checks to exact source records.
3. **Task 2 RED:** `53909c75a` — reproduce the independent audit accepting the forged source join.
4. **Task 2 GREEN:** `27cff3b40` — independently validate package source joins.

## Files Created/Modified

- `verify-247-readiness.mjs` — maps every package check to immutable source records and named assertions.
- `verify-247-readiness.test.mjs` — covers false passes, exact-source controls, and identity mutations.
- `verify-v149-traceability.mjs` — independently checks complete source and assertion joins.
- `verify-v149-traceability.test.mjs` — covers forged joins, missing published records, and valid controls.
- `251-04-task1-red-evidence.json`, `251-04-task2-red-evidence.json` — classifier-approved RED reports and semantic assessments.

## Decisions Made

- READY-01 and READY-02 remain unsatisfied until their original owner evidence bars are proven.
- Phase 250's historical exception remains separate from current READY acceptance.
- The audit keeps its own mapping so it can detect owner-evaluator drift.

## TDD Gate Compliance

- **Task 1 RED:** `RED_EVIDENCE_OK`; the target assertion failed because candidate guide bytes were accepted for the published-tag check. **GREEN:** owner suite passed 42/42.
- **Task 2 RED:** `RED_EVIDENCE_OK`; the target assertion failed because the independent audit accepted the mismatched source reference. **GREEN:** focused source-binding cases passed 4/4.
- No REFACTOR commit was needed.

## Deviations from Plan

None. The current Phase 251 source-derived audit remains `gaps_found` at 7/9, with READY-01 and READY-02 unsatisfied.

## Issues Encountered

- The full traceability suite reports 27/28 passing. Its existing hypothetical 9/9 READY fixture is rejected because `251-03-SUMMARY.md` claims READY-02 outside the original Phase 247 owner. This is unrelated to the package-source changes and remains deferred for the owning plan.
- No planning artifacts were dirty at task capture, so no write-ahead recovery ref was needed. STATE.md, state.json, ROADMAP.md, HANDOFF.json, and REQUIREMENTS.md were not modified.

## Next Phase Readiness

- CR-02's owner and audit validation gap is repaired and regression-covered.
- READY-01 remains unsatisfied because its original approval/source evidence is incomplete; READY-02 remains unsatisfied because its inventory and preservation joins are incomplete.
- Phase 251 implementation continues with its remaining plans; phase verification is not complete.

## Self-Check: PASSED

- Both RED evidence files exist and each returned `RED_EVIDENCE_OK`.
- All four task commits are present on the current branch.
- Owner suite passed 42/42; focused independent-audit cases passed 4/4.
- The source-derived audit still reports READY-01 and READY-02 as unsatisfied.

---
*Phase: 251-close-ready-01-and-ready-02-release-readiness-gaps*
*Completed: 2026-10-11*
