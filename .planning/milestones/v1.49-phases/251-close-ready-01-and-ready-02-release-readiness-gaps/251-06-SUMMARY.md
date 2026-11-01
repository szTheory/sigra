---
phase: 251-close-ready-01-and-ready-02-release-readiness-gaps
plan: 06
subsystem: release-readiness
tags: [readiness, provenance, github-api, package-source]
requires:
  - phase: 251-04
    provides: Exact package-check source_refs contract and named check map.
  - phase: 251-05
    provides: Independently satisfied READY-02 capture and preservation evidence.
provides:
  - Exact historical READY-01 approval and owner-source trust evaluation.
  - Exact published-tag source refs for all 14 package/adopter checks.
  - Capture-ID and digest consistency checks across packet, summary, and owner report.
affects: [phase-247-owner-verification, phase-251-readiness]
actuals:
  tokens: 44579
  tasks: 2
  commits: 4
plan_head_before: 00b8b0b66d745dda9294425aa80310b108925d91
plan_head_after: 0a8adf7c1a61d821da793290bee67241061efc69
tech-stack:
  added: []
  patterns: [exact-source-reference binding, fail-closed historical approval joins, generation identity validation]
key-files:
  created:
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-06-task1-red-evidence.json
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-06-task2-red-evidence.json
  modified:
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-247-RECONCILIATION.json
    - .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-SUMMARY.md
    - .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md
key-decisions:
  - "Only an exact, contemporaneous approval joined to the candidate, CI run, readiness record, and authenticated non-publishing dry-run can satisfy READY-01."
  - "Keep READY-01 authorization_pending when independent historical source or approval evidence is absent; preserve the satisfied READY-02 verdict."
patterns-established:
  - "Every named package/adopter check carries source_refs and source_assertions bound to exact identity, commit, path, blob, and digest."
  - "Packet, summary, and owner report share one capture_id and packet digest; mixed generations fail --check-251."
requirements-completed: []
coverage:
  - id: D1
    description: Historical READY-01 evidence is evaluated against a complete original approval interval and exact candidate tuple.
    requirement: READY-01
    verification:
      - kind: unit
        ref: node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
        status: pass
    human_judgment: false
  - id: D2
    description: Published-tag package checks and generated artifacts are bound to exact sources and a shared capture generation.
    requirement: READY-01
    verification:
      - kind: unit
        ref: "verify-247-readiness.test.mjs: source refs, idempotency, and mixed-generation rejection"
        status: pass
      - kind: integration
        ref: node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-251
        status: pass
    human_judgment: false
duration: 35min
completed: 2026-10-11
status: complete
---

# Phase 251 Plan 06: Historical Approval and Published Source Summary

**The refreshed evidence keeps READY-01 pending on independently untrusted historical bytes, absent approval, and missing published guide/link evidence while preserving READY-02 as satisfied.**

## Performance

- **Duration:** approximately 35 minutes
- **Started:** 2026-10-11T22:16:00Z
- **Completed:** 2026-10-11T22:51:14Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added a strict READY-01 approval predicate that requires exact owner source identity, complete original history, the original candidate/base/main tuple, matching exact-source CI, readiness record, and authenticated non-publishing dry-run receipt.
- Captured the historical owner report's local blob and digest while recording the GitHub commit endpoint HTTP 422 and exact-ref contents HTTP 404; local-only bytes remain untrusted.
- Recorded complete PR #224 review/timeline evidence: zero reviews, 46 timeline items, one cross-reference inside the original interval, and zero qualifying approvals. The exact candidate CI run 37819712610 attempt 1 succeeded, while readiness and dry-run records refer to a different parent candidate.
- Verified the immutable `v1.6.0` tag resolves to `9e80cb78d6374b1ed4074d5fef6b613fee879dca`; the published upgrade guide is absent (trusted exact-commit 404) and the published README omits its guide link. Candidate guide bytes do not satisfy either published check.
- Bound all 14 named package/adopter checks to source references and assertions. Packet, summary, and owner report use capture ID `phase251-939607ff3f17e03b22aa` and pass `--check-251`.
- Confirmed READY-02 remains `satisfied` while READY-01 remains `authorization_pending`.

## Task Commits

1. **Task 1: Trace a missing historical approval through feasibility, packet, and owner verdict** - `5b549a80f` (test), `cc3d4b49c` (feat)
2. **Task 2: Verify published-tag adopter paths and capture determinism** - `5a37783d8` (test), `0a8adf7c1` (feat)

## Decisions Made

The owner-source and approval gaps are recorded as durable blockers rather than inferred as approval from broad consent or a later review. The immutable published tag is evaluated independently from candidate source content. READY-02 remains independent of READY-01.

## Deviations from Plan

None. The unavailable historical owner source and absent approval/published guide evidence are the precise blocked outcomes allowed by the plan.

## Issues Encountered

The GitHub API could not resolve the historical owner-report commit (HTTP 422) and exact-ref file lookup returned 404. The complete original approval interval contains no review approvals. The stored readiness and dry-run records use parent candidate `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, not candidate `0e773d3614a242e4fbcdd34c418ecb8a307703d6`. The immutable published tag lacks the guide and README link. These conditions leave READY-01 pending; they do not affect READY-02.

## User Setup Required

None.

## Next Phase Readiness

Plan 06 implementation and automated artifact verification are complete. READY-01 acceptance remains unsatisfied pending independently trusted historical owner-report bytes, an exact contemporaneous approval with matching evidence identities, and published guide/link evidence. READY-02 remains satisfied.

---
*Phase: 251-close-ready-01-and-ready-02-release-readiness-gaps*
*Completed: 2026-10-11*

## Self-Check: PASSED

The summary exists, all four task commits are ancestors of HEAD, and the measured plan commit count is four. The refreshed packet has 14 named checks with source references; READY-01 is `authorization_pending`, READY-02 is `satisfied`, and `--check-251` passed.
