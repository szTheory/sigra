---
phase: 251-close-ready-01-and-ready-02-release-readiness-gaps
plan: 03
subsystem: release-readiness
tags: [pull-requests, evidence-identity, node-test, tdd]
requires:
  - phase: 251-01
    provides: Fresh Phase 251 evidence capture and READY-02 inventory inputs.
  - phase: 251-02
    provides: Current owner verdict and audit context for unresolved READY-02.
provides:
  - Final PR dispositions bound to repository, number, head SHA, base ref, and base SHA.
  - Snapshot and final-inventory validation for complete PR identity, uniqueness, and numeric order.
affects: [release-readiness, phase-247-owner-verification]
actuals:
  tokens: 9469
  tasks: 2
  commits: 4
plan_head_before: f463111efcab06baee4e00b59b8b8baa01f7c63a
plan_head_after: e33f0a3bdd71d01ae5748b28db50a4131384e1ee
tech-stack:
  added: []
  patterns: [explicit disposition_identity binding, complete PR identity comparison]
key-files:
  created:
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-03-task1-red-evidence.json
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-03-task2-red-evidence.json
  modified:
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
key-decisions:
  - "Record disposition_identity separately so later reconciliation cannot make an old disposition appear current by overwriting row identity fields."
  - "Treat multiple distinct identities for one PR number as a conflict, even when the full identity keys differ."
requirements-completed: [READY-02]
coverage:
  - id: D1
    description: "Final PR disposition evidence is invalidated when repository, head, base ref, or base SHA changes, and final readiness checks the captured identity against the live row."
    requirement: READY-02
    verification:
      - kind: unit
        ref: ".planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs#final inventory invalidates disposition when any captured PR identity component changes"
        status: pass
    human_judgment: false
  - id: D2
    description: "PR snapshots and final inventories reject incomplete or duplicate identities and preserve deterministic numeric ordering."
    requirement: READY-02
    verification:
      - kind: unit
        ref: ".planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs#requires unique complete PR identities and stable numeric ordering in snapshots"
        status: pass
      - kind: unit
        ref: ".planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs#final inventory sorts PRs numerically and rejects duplicate or null identities"
        status: pass
    human_judgment: false
duration: 4min
completed: 2026-10-11
status: complete
---

# Phase 251 Plan 03: Bind READY-02 dispositions to full PR identity

**Final readiness now preserves a PR disposition only while repository, number, head SHA, base ref, and base SHA remain identical.**

## Performance

- **Duration:** 4 minutes
- **Started:** 2026-10-11T22:08:09Z
- **Completed:** 2026-10-11T22:12:08Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Added explicit `disposition_identity` binding so changed PR identities lose their saved disposition and cannot pass final readiness.
- Required repository, head, base ref, and full base SHA in immutable snapshot validation; final validation rejects same-number conflicts and duplicate complete identities.
- Added deterministic coverage for changed head/base/base SHA, missing and null identity fields, duplicate rows, and numeric ordering of PRs 9 and 10.

## Task Commits

1. **Task 1 RED: Changed PR identity regression** — `e10fbb300` (`test`)
2. **Task 1 GREEN: Bind final PR dispositions to full identity** — `d383363a7` (`feat`)
3. **Task 2 RED: PR identity boundary fixtures** — `16f1ed3bf` (`test`)
4. **Task 2 GREEN: Validate full identity and ordering** — `e33f0a3bd` (`feat`)

The summary and plan metadata are committed separately after this file is written.

## Files Created/Modified

- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` — validates complete PR identities, preserves only exactly bound dispositions, and rejects identity conflicts.
- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` — adds changed-identity, uniqueness, null-field, and ordering regressions.
- `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-03-task1-red-evidence.json` — machine-validated Task 1 TAP RED evidence.
- `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-03-task2-red-evidence.json` — machine-validated Task 2 TAP RED evidence.

## Decisions Made

- Store a separate `disposition_identity` snapshot so a later refresh cannot overwrite identity fields and make stale evidence appear current.
- Reject two distinct full identities that share one PR number as a conflict.

## Deviations from Plan

None — plan executed as written. Both tasks used real RED/GREEN cycles; the two scoped TAP evidence records are retained with their test commits.

## Issues Encountered

- The first Task 1 RED attempt failed on a fixture timestamp mismatch. The fixture was corrected, and the next run failed on the intended stale-disposition assertion before GREEN.
- Git could not create `.git/index.lock` in the workspace sandbox. Scoped commits were completed with the authorized escalation and normal hooks.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 251-03 closes CR-01's validator boundary. READY-02 itself remains unsatisfied because the full current PR population and inherited-work preservation joins remain incomplete; later Phase 251 plans own those remaining gaps.

## Self-Check: PASSED

- Both validator files exist and the four task commits are ancestors of the current HEAD.
- The plan evaluation scope resolves to four commits on this branch.
- The fresh validator suite passes 31/31 tests; `git diff --check` passes.
- No new TODO, FIXME, placeholder, or empty-value stubs were found in the changed validator files.
- No new endpoint, auth path, file-access boundary, or schema trust boundary was introduced.

---
*Phase: 251-close-ready-01-and-ready-02-release-readiness-gaps*
*Completed: 2026-10-11*
