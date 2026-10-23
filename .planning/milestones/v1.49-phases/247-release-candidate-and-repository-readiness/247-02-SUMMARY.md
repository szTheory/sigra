---
phase: 247-release-candidate-and-repository-readiness
plan: 02
subsystem: release
tags: [release-please, changelog, github-actions, candidate-validation]
requires: [247-01]
provides: [reviewed-1.6.0-candidate, candidate-source-validator, exact-head-docs-ci-evidence]
affects: [247-03, 247-04, release-automation]
tech-stack:
  added: []
  patterns: [exact-source-squash-promotion-proof, exact-head-ci-receipt]
key-files:
  created: []
  modified:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-02-PLAN.md
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
    - tmp/phase-247-candidate/CHANGELOG.md
decisions:
  - "Accept PR #288's exact-source squash promotion by pinned identities, four allowlisted blob matches, and exact-source CI receipts; do not call it ancestry."
  - "Use exact-updated-head CI's unconditional documentation build as the local docs equivalent because the clean candidate lacks its exact locked dependencies and dependency installation is prohibited."
metrics:
  duration: 37min
  completed: 2026-10-07
status: complete
plan_head_before: 9991d54616a5c0e3e39efbcb5fa50699896e6901
plan_head_after: 3986392bc69ca80f449459be738ec5c28b7a5359
commits: 1
actuals:
  tokens: 16355
  tasks: 2
  commits: 1
coverage:
  - id: D1
    description: "PR #224 is a source-verified 1.6.0 candidate with aligned release metadata and guarded live identity validation."
    requirement: READY-01
    verification:
      - kind: unit
        ref: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs (14 tests)
        status: pass
      - kind: other
        ref: validate-release-readiness.mjs --stage candidate --assert-live-refresh; live PR #224 head 51c0e7a
        status: pass
    human_judgment: false
  - id: D2
    description: "Curated 1.6.0 adopter notes are committed to the existing Release Please PR and pass exact-head CI, including the docs build."
    requirement: READY-02
    verification:
      - kind: other
        ref: CI run 37696042318 attempt 2, SHA 51c0e7a; Library tests shard and ci-gate success
        status: pass
      - kind: other
        ref: git -C tmp/phase-247-candidate show --check --oneline HEAD
        status: pass
    human_judgment: false
---

# Phase 247 Plan 02: Release Candidate and Repository Readiness Summary

**PR #224 now carries a curated, source-backed Sigra 1.6.0 candidate with live source-promotion validation and exact-head CI documentation proof.**

## Performance

- **Duration:** 37 minutes
- **Started:** 2026-10-07T22:09:50Z
- **Completed:** 2026-10-07T22:47:04Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Curated the existing PR #224 changelog under its 1.6.0 heading, using adopter-facing behavior and retaining source traceability. The update is in candidate commit `51c0e7a8ca126888fe618ca5ad2401188ff2188b`.
- Extended the candidate validator and fixtures to prove Phase 246 source inclusion either by Git ancestry or by exact-source squash-promotion evidence. PR #288's four approved source blobs match, and its promotion is explicitly recorded as content-equivalent rather than ancestry.
- Recorded a successful exact-head documentation and required-CI receipt: run 37696042318, attempt 2, SHA 51c0e7a. Its `Library tests shard` runs `mix docs --warnings-as-errors` unconditionally; `Generated admin Playwright smoke` and `ci-gate` also passed.
- Kept PR #224 as the only candidate vehicle. The Release Please refresh run 37694904328 created no release or tag.

## Task Commits

1. **Task 1: Refresh PR #224 and reconcile candidate identity** — `3986392` (fix; exact-source promotion validator, fixtures, and evidence ledger).
2. **Task 2: Curate source-backed adopter changes** — `51c0e7a` (docs; candidate changelog commit on PR #224).

**Plan metadata:** `a8a9f8dfb` (GSD-managed summary/state/roadmap/requirements commit).

## Files Created/Modified

- `.planning/phases/247-release-candidate-and-repository-readiness/247-02-PLAN.md` — documented the verified squash-promotion route and exact-head docs CI alternative.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` — recorded source, candidate, changelog claim, and exact-head CI proofs.
- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` — validates live candidate identity, metadata, source-equivalent promotion, approved paths/blobs, and source CI receipts.
- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` — covers promotion identity, path/blob allowlist, and missing/failed CI receipts.
- `tmp/phase-247-candidate/CHANGELOG.md` — curated release-facing 1.6.0 summary.

## Decisions Made

- PR #288's squash merge is accepted only through its exact merged PR identities, full four-path allowlist, matching tested/main Git blob IDs, and required exact-SHA CI receipts. The validator keeps the direct ancestry route and never mislabels content equivalence as ancestry.
- The local docs command could not run because the clean isolated candidate lacks the exact locked dependency tree. The plan prohibits dependency installation. Exact-updated-head CI was accepted only after confirming the checked-in workflow unconditionally runs `mix docs --warnings-as-errors` in the passed Library tests shard.

## Deviations from Plan

### Documented adjustments

**1. Content-equivalent squash promotion for Phase 246 source inclusion**
- **Found during:** Task 1
- **Issue:** Tested SHA `90ec16f` is not a Git ancestor of selected main `590eb4e` because the reviewed PR #288 was squash-merged.
- **Fix:** Added an alternative proof requiring the live merged PR identity, exact four-path diff, identical blobs for each approved path, passing Phase 246 required CI on the tested SHA, and passing selected-main CI on exact main. Direct ancestry remains supported.
- **Verification:** Focused fixtures reject missing or extra paths, blob mismatches, changed PR/head/merge identity, and missing or failed CI receipts.
- **Committed in:** `3986392`.

**2. CI-backed exact-version documentation verification**
- **Found during:** Task 2
- **Issue:** The candidate worktree lacks exact locked dependencies; the plan threat model prohibits running a package-manager install.
- **Fix:** Updated the plan to accept the exact updated-head CI docs step as the equivalent proof and recorded run 37696042318 attempt 2 for SHA 51c0e7a.
- **Verification:** The `Library tests shard` passed and includes the unconditional `Check docs build cleanly` step; the whole rerun and `ci-gate` passed. One initial generated-admin job was cancelled while installing browsers; the one permitted retry passed.
- **Committed in:** `3986392`.

**Total deviations:** 2 documented adjustments. Both preserve the plan's source and exact-head proof requirements.

## Issues Encountered

- The initial exact-head run's Generated admin Playwright smoke was cancelled after 15 minutes during browser setup; `ci-gate` correctly failed on that cancelled required lane. The single permitted rerun passed the browser smoke, docs lane, and `ci-gate` on the same exact PR head.
- A normal local Mix docs build was unavailable without installing dependencies. The exact-head CI build provides the required verified equivalent.

## User Setup Required

None.

## Next Phase Readiness

Phase 247 Plan 02 is complete. PR #224 remains open at SHA `51c0e7a8ca126888fe618ca5ad2401188ff2188b`, based on reviewed main `590eb4ed3323db11dd74326cbee00c9c7973e529`. No release or tag was created. Continue with the next runnable Phase 247 plan; this plan does not establish phase-wide verification or authorize publication.

## Self-Check: PASSED

- The candidate changelog commit `51c0e7a` and scoped task-record commit `3986392` exist.
- Focused tests passed 14/14; live candidate validation passed with no diagnostics; exact-head required CI and docs evidence passed.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-07*
