---
phase: 247-release-candidate-and-repository-readiness
plan: 10
subsystem: release-readiness
tags: [github-actions, playwright, evidence, hex-dry-run]
requires:
  - phase: 247-09
    provides: repaired organization signup test and exact-head candidate CI
provides:
  - protected evidence route and baseline bound to the approved candidate
  - verified exact-source evidence PR merge and CI provenance
affects: [247-11, READY-01, READY-02]
actuals:
  tokens: 8000
  tasks: 3
  commits: 1
commits: 1
plan_head_before: a494f3ee3878da93aab4f70712ffddeefd77a802
plan_head_after: 9d07f211c7a30afd97ae2b6e762f65b683e93a7b
tech-stack:
  added: []
  patterns: [fixed-source non-publishing evidence, protected four-path rebind]
key-files:
  created:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-10-REBIND-PROPOSAL.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-10-SUMMARY.md
  modified:
    - .github/workflows/phase-247-hex-dry-run.yml
    - scripts/ci/phase-247-hex-dry-run.sh
    - scripts/ci/phase-247-hex-dry-run.test.sh
    - .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-05-CURRENT-SOURCE-REVIEW.json
key-decisions:
  - "Use only candidate 0e773d3614a242e4fbcdd34c418ecb8a307703d6 with reviewed base d135cbce343947499a0810736c500ef5f1cb5c32 and pre-merge main a494f3ee3878da93aab4f70712ffddeefd77a802."
  - "Keep the evidence PR limited to the four approved files and stop on any further candidate or base drift."
patterns-established:
  - "The evidence baseline is recomputed from immutable reviewed-base and candidate SHAs, then independently checked after protected merge."
requirements-completed: []
coverage:
  - id: D1
    description: "The trusted evidence route and raw-diff baseline are rebound to the approved Playwright-corrected candidate."
    requirement: READY-01
    verification:
      - kind: integration
        ref: "PR #297 / CI run 37822383917 attempt 2 / merge 51be73415cf6de5531d3fb4c91ec3caf2c7544b6"
        status: pass
    human_judgment: false
  - id: D2
    description: "Candidate source, exact-head CI, and adopter blobs remain fixed through evidence merge."
    requirement: READY-02
    verification:
      - kind: integration
        ref: "PR #224 and CI run 37819712610 attempt 1"
        status: pass
    human_judgment: false
duration: 24min
completed: 2026-10-08
status: complete
---

# Phase 247 Plan 10: Exact-source evidence rebind Summary

The approved 1.6.0 candidate now has a protected, independently recomputed evidence baseline on main, with the rebind limited to four paths and PR #224 held at its approved source.

## Performance

- **Duration:** about 24 minutes
- **Started:** 2026-10-08T18:04:19Z
- **Completed:** 2026-10-08T18:28:06Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Rechecked live PR #224, main, candidate ancestry, clean isolated checkout, source blobs, and successful exact-head CI before editing.
- Updated the existing fixed-source workflow, helper, and fixtures to accept only candidate `0e773d3614a242e4fbcdd34c418ecb8a307703d6` and reviewed base `d135cbce343947499a0810736c500ef5f1cb5c32`; stale `d76d7f23` acceptance and any pre-merge main other than approved SHA `a494f3ee3878da93aab4f70712ffddeefd77a802` fail closed.
- Recomputed and independently verified the `git-diff-raw-v1` candidate baseline: SHA-256 `85020173c21fded708030b7422bb00ddd1510a073010122e6cf5364527772ec4`, 9,906 bytes. The six-path candidate diff includes the five reviewed adopter files and the organizations Playwright correction.
- Merged evidence PR [#297](https://github.com/szTheory/sigra/pull/297) via protected squash merge. Its pre-merge head was `9d07f211c7a30afd97ae2b6e762f65b683e93a7b`; CI run `37822383917` attempt 2 passed, including the non-admin Playwright shard and `ci-gate`; merge SHA is `51be73415cf6de5531d3fb4c91ec3caf2c7544b6`.
- Verified main advanced from `a494f3ee3878da93aab4f70712ffddeefd77a802` through exactly the four approved paths. The baseline blob `12daf4f704bbc2d4aa136d0ef678e64abce38aeb` is identical at the PR head and merged main.
- Rechecked PR #224 remains OPEN at candidate `0e773d3614a242e4fbcdd34c418ecb8a307703d6` with base `d135cbce343947499a0810736c500ef5f1cb5c32`; adopter and spec blobs match the proposal, and candidate CI run `37819712610` attempt 1 remains successful.

## Task Commits

1. **Task 1: Produce a read-only exact-candidate rebind proposal** — proposal created and validated in the shared planning checkout.
2. **Task 2: Obtain separate authorization for one exact-source evidence recovery** — explicitly approved by the user for the displayed candidate/base/main tuple and bounded scope.
3. **Task 3: Bind the existing evidence route to the approved candidate** — `9d07f211c7a30afd97ae2b6e762f65b683e93a7b` (`test(247-10): rebind dry-run evidence to approved source`), merged as `51be73415cf6de5531d3fb4c91ec3caf2c7544b6`.

## Files Created/Modified

- `247-10-REBIND-PROPOSAL.json` — records the approved tuple, source/CI observations, stale artifacts, and precise recovery scope.
- `.github/workflows/phase-247-hex-dry-run.yml`, `scripts/ci/phase-247-hex-dry-run.sh`, and `scripts/ci/phase-247-hex-dry-run.test.sh` — pin candidate/base and approved pre-merge main, with rejection fixtures for stale source and main identities.
- `247-CANDIDATE-DIFF-BASELINE.json` — records the recomputed full candidate diff identity.
- `247-05-CURRENT-SOURCE-REVIEW.json` — records evidence PR, CI attempts, merge, exact paths/blob, and current candidate identities.

## Decisions Made

- The user authorized exactly one evidence PR/merge, its required CI, one authenticated non-publishing dry run, a refreshed final ledger, and independent Phase 247 verification. No publication, tag, or PR #224 merge was authorized.
- Evidence CI attempt 1 failed only on the mobile signed-in matching-user invitation flow; the same exact candidate had successful required CI before this evidence PR. The one allowed transient retry (failed jobs only, attempt 2) passed without source changes.
- The local macOS WebKit launch remains `blocked_host_appkit`; no local browser proof is claimed. The exact-head CI browser shard passed.

## Deviations from Plan

**1. Fixture checkout needed candidate blob hydration.**
- **Found during:** Task 3
- **Issue:** The partial clone used for the isolated evidence checkout had not materialized all candidate tree blobs, so the fixture's shared clone could not check out the candidate.
- **Fix:** Hydrated the approved candidate tree in a separate temporary worktree; then the test-first stale-source check failed as intended and the updated suite passed.
- **Files modified:** None beyond the four approved evidence paths.

**2. One transient CI retry.**
- **Found during:** Task 3
- **Issue:** The first evidence CI attempt had one mobile invitation test fail while remaining browser, install, unit, and fast-check lanes passed.
- **Fix:** Re-ran only failed jobs once. Attempt 2 passed the non-admin shard and `ci-gate`; no source change was made.
- **Files modified:** None.

**Total deviations:** 2 execution accommodations. **Impact:** No candidate, scope, or source changes beyond the approved four evidence paths.

## Issues Encountered

- The evidence baseline capture helper assumed main still equaled the reviewed base, but the approved pre-merge main was already `a494f3ee…`. The helper now pins that exact approved starting main while continuing to diff from the reviewed base.
- Plan 247-11 remains required to run the approved non-publishing dry run, final validation, and independent verification. READY-01 is not declared ready here.

## Self-Check: PASSED

- Proposal, source review, and this summary exist; their tuple and evidence identities agree with live PR/main observations.
- Evidence PR #297 is merged at `51be73415cf6de5531d3fb4c91ec3caf2c7544b6`; its only changed paths are the four approved paths.
- The main and PR-head baseline blob IDs match; candidate PR #224 remains open at the approved head/base and exact-head CI is successful.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-08*
