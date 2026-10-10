---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
plan: 04
subsystem: release-closeout
tags: [release-verification, github-api, hex, tdd, evidence]
requires:
  - phase: 250-02
    provides: Phase 249 closeout evidence and validation conventions
  - phase: 250-03
    provides: source-bound owner-report and snapshot conventions
provides:
  - Read-only Phase 249 release verifier and hostile identity tests
  - Independently captured public, historical acceptance, current-main, and repository inventory evidence
  - Refreshed Phase 249 owner report with separate REL-01 and REL-02 verdicts
affects: [phase-249-release-closeout, phase-250-audit]
actuals:
  tokens: 32270
  tasks: 2
  commits: 11
tech-stack:
  added: []
  patterns: [read-only source-bound evidence snapshots, fail-closed live inventory comparison]
key-files:
  created:
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-SOURCE-SNAPSHOT.json
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-04-TDD-RED.json
  modified:
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md
key-decisions:
  - "Keep REL-01 public release proof separate from REL-02 current-main and inventory proof; report REL-02 unsatisfied when its current workflow or live PR joins fail."
  - "Treat the historical HANDOFF loss as accepted-with-recorded-loss under the exact user authorization; the bytes were neither recovered nor preserved."
patterns-established:
  - "Mutable current-main and repository inventory evidence is freshly re-read during report validation and compared by identity."
  - "Historical release main and immutable package source remain separate identities from current protected main."
requirements-completed: [REL-01]
duration: 37m
completed: 2026-10-10
status: complete
commits: 11
plan_head_before: 082dacb3862b0374becac2c884ac32af8eda1110
plan_head_after: f6c67c61494503b535718247682551334dc91f96
---

# Phase 250 Plan 04: Phase 249 Release Evidence Summary

**A read-only verifier joins Sigra 1.6.0 public proof to its historical acceptance and separately checks current main and live repository inventory.**

## Performance

- **Duration:** 37 minutes
- **Started:** 2026-10-10T15:43:00Z (approximate; first task commit at 15:54:16Z)
- **Completed:** 2026-10-10T16:19:36Z
- **Tasks:** 2
- **Files changed by the plan:** 6

## Accomplishments

- Added a read-only verifier that binds public Hex/HexDocs/source/tag evidence to package source `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, historical release main `08300af1740fea8b77d5928a182688acbf103edc`, and the distinct current protected main.
- Captured exact acceptance ref, commit, acceptance and terminal blobs, historical/current CI records, receipt identity, seven raw worktree statuses, and sixteen open PR identities in `250-249-SOURCE-SNAPSHOT.json`.
- Refreshed the Phase 249 report while preserving its previous `gaps_found` report verbatim. REL-01 is satisfied. REL-02 remains unsatisfied because the exact current-main workflow concluded failure and five open PRs lack dispositions matching their current identities.
- Recorded the exact accepted-with-recorded-loss exception for `.planning/HANDOFF.json`; its historical bytes are explicitly recorded as neither recovered nor preserved.

## Task Commits

The RED/GREEN task produced these atomic commits:

1. `86399f5f6` test(250-04): capture release verifier RED evidence
2. `11da66d47` feat(250-04): validate release acceptance and current main
3. `f112d9820` fix(250-04): reject stale acceptance and PR identities
4. `7f772eafb` fix(250-04): resolve public tag through GitHub refs
5. `6c360de81` fix(250-04): bind historical ci to terminal acceptance
6. `d09ed17db` chore(250-04): checkpoint first source snapshot
7. `354c6e90b` fix(250-04): validate exact historical and current CI records
8. `16de311a4` docs(250-04): capture release owner source evidence
9. `659945570` fix(250-04): preserve prior owner verification report
10. `1558900c8` docs(250-04): refresh source snapshot and prior report
11. `f6c67c614` docs(250-04): refresh Phase 249 owner verification

**Plan metadata:** recorded separately after summary and project-state updates.

## Verification

- RED evidence was captured from the actual failing test run and accepted by `gsd-tools check tdd-red-evidence` (`RED_EVIDENCE_OK`).
- `bash scripts/ci/release-public-proof.test.sh` — passed, 60/60.
- `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` — passed, 60/60.
- `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs` — passed, 8/8.
- `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs --check-report .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md` — passed with a fresh live capture and matching report. REL-01 satisfied; REL-02 unsatisfied for the recorded current workflow failure and five stale/missing PR dispositions.
- `git diff --check` — passed.

## Deviations from Plan

### Auto-fixed correctness issues

1. The public tag was not available as a local tag, so the verifier resolves the exact public GitHub tag ref using read-only API access rather than assuming local tag state.
2. Validation was tightened to bind historical CI run/job/attempt and current aggregate workflow conclusion, and to compare live PR base/head identities. The individual `ci-gate` job passing does not satisfy REL-02 when its containing current-main workflow run failed.
3. The source snapshot was refreshed after verifier and report changes and includes the exact prior report bytes/hash, so report consistency checks can preserve historical context without treating it as current evidence.

**Total deviations:** 3 correctness refinements. No publish, retag, merge, dispatch, cancellation, or source mutation occurred.

## Owner Verdicts

| Requirement | Verdict | Evidence |
|---|---|---|
| REL-01 | Satisfied | Public 1.6.0 package/docs/source/tag proof joins package source `9e80cb78d6374b1ed4074d5fef6b613fee879dca`; historical acceptance and receipt are source-bound. |
| REL-02 | Unsatisfied | Current main `6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5` has exact run `38061391571` / job `114241911167`, but the aggregate workflow concluded failure; PRs #302, #306, #307, #308, and #309 have no disposition matching their live identities. |

The report status is `gaps_found`; this is a completed Plan 04 evidence/reporting task, not completion of Phase 250 or REL-02.

## Next Phase Readiness

Plan 05 owns requirements traceability and the phase audit. Its readiness is checked after this summary and state update; Phase 250 remains incomplete until that work is done.

---
*Phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat*
*Completed: 2026-10-10*

## Self-Check: PASSED

- Summary and all declared evidence/report files exist.
- All 11 task commits are ancestors of the current plan head.
- `evaluation-scope --plan 250-04 --commits-only` resolved with no changed, missing, outside-scope, or unreachable files.
