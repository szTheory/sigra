---
phase: 247-release-candidate-and-repository-readiness
plan: 07
subsystem: release-readiness
tags: [github-actions, candidate-provenance, release]
requires:
  - phase: 247-06
    provides: Reviewed PR #224 source and exact-head CI evidence.
provides:
  - Existing dry-run workflow and helper fixed to the reviewed candidate and base.
  - Independently verified candidate diff baseline retained on protected main.
  - Refreshed current-source review for PR #224 after the evidence-only main advance.
affects: [247-05, 247-08, release-readiness]
actuals:
  tokens: 3815
  tasks: 2
  commits: 3
plan_head_before: e3883b72fb1df5ad6356ef10dbde408f18bbc3be
plan_head_after: b3739e09aed17085afd4e492391b3aac3032a1d7
tech-stack:
  added: []
  patterns: [fixed full-SHA provenance, four-path protected evidence advance]
key-files:
  created: []
  modified:
    - .github/workflows/phase-247-hex-dry-run.yml
    - scripts/ci/phase-247-hex-dry-run.sh
    - scripts/ci/phase-247-hex-dry-run.test.sh
    - .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-05-CURRENT-SOURCE-REVIEW.json
key-decisions:
  - "Bind the existing workflow and baseline to Plan 06's exact candidate SHA 6f8028658f0bdd7f26e13c3fe4d45437880c341b and reviewed base e3883b72fb1df5ad6356ef10dbde408f18bbc3be."
  - "Use clean isolated clones under /private/tmp while preserving the shared checkout's unrelated work."
patterns-established:
  - "Retain the evidence PR head and manifest blob before protected merge, then independently verify both on main."
requirements-completed: []
coverage:
  - id: D1
    description: "The fixed-source dry-run workflow and immutable candidate baseline are on trusted main after an evidence-only protected merge."
    requirement: READY-01
    verification:
      - kind: integration
        ref: "PR #291 merge 9bb7566f31b40a129c5a234b122ac00b540ede29; helper verify-baseline"
        status: pass
      - kind: unit
        ref: "bash scripts/ci/phase-247-hex-dry-run.test.sh; actionlint .github/workflows/phase-247-hex-dry-run.yml"
        status: pass
    human_judgment: false
  - id: D2
    description: "PR #224 remains at the reviewed adopter source with matching blobs and passing exact-head required CI after the main advance."
    requirement: READY-02
    verification:
      - kind: integration
        ref: "PR #224 head 6f8028658f0bdd7f26e13c3fe4d45437880c341b; CI run 37717911489 attempt 1"
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-10-08
status: complete
---

# Phase 247 Plan 07: Reviewed candidate evidence rebind summary

**The existing dry-run workflow and immutable diff proof now name the reviewed PR #224 source and survive a four-file protected main merge.**

## Performance

- **Duration:** 16 minutes
- **Started:** 2026-10-08T02:42:19Z
- **Completed:** 2026-10-08T02:58:02Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Rebound the workflow, helper, and fail-closed fixtures from the superseded `563f411` candidate to full candidate SHA `6f8028658f0bdd7f26e13c3fe4d45437880c341b` and reviewed base `e3883b72fb1df5ad6356ef10dbde408f18bbc3be`.
- Expanded fixture coverage for the superseded source, changed PR head/base, missing GitHub token, wrong evidence PR or manifest blob, untrusted workflow ref, changed candidate checkout, failed dry-run outcome, and a public 1.6.0 release. The 18-case fixture suite and `actionlint` passed.
- Captured the raw candidate diff baseline before main advanced. An independent recomputation matched SHA-256 `b255ce05050cc9d916cfa47da8920b2ae3c14de5187afc25ea6d9b6b35414fb7` and 12,983 bytes.
- Opened evidence-only PR [#291](https://github.com/szTheory/sigra/pull/291) with exactly four paths. CI run `37719588905`, attempt 1, passed, including all required jobs and `ci-gate`; ordinary squash merge produced main SHA `9bb7566f31b40a129c5a234b122ac00b540ede29`.
- Verified the exact four-path main advance, unchanged manifest blob `9f16f9b4713abb88e5ffbb8812dda9e8d3e1c818`, and final helper baseline check. PR #224 stayed open at the reviewed candidate; all four adopter blobs and its 15 required CI jobs plus `ci-gate` remain green on run `37717911489`.

## Task Commits

Task 1's TDD and baseline commits are on the isolated evidence branch:

1. `389870c5` — `test(247-07): reject superseded release candidate source` (RED)
2. `0d5e0502` — `feat(247-07): rebind dry-run evidence to reviewed candidate` (GREEN)
3. `b3739e09` — `docs(247-07): freeze reviewed candidate diff baseline`

Task 2's protected evidence merge is `9bb7566f31b40a129c5a234b122ac00b540ede29`.

## Files Created/Modified

- `.github/workflows/phase-247-hex-dry-run.yml` and `scripts/ci/phase-247-hex-dry-run.sh` bind the workflow and helper to the reviewed full SHAs.
- `scripts/ci/phase-247-hex-dry-run.test.sh` rejects stale source, trust, baseline, credential, receipt, and Hex-state inputs.
- `247-CANDIDATE-DIFF-BASELINE.json` records the immutable raw-diff digest and byte count.
- `247-05-CURRENT-SOURCE-REVIEW.json` retains existing Plan 05 fields and adds the protected merge, baseline, and current candidate/CI identities; it marks both `563f411` and pre-repair `77dd112` evidence historical.

## Decisions Made

- The evidence workflow remains bound to one reviewed full source SHA. The old `563f411` and pre-repair `77dd112` source evidence remain historical.
- Clean evidence, candidate, and trusted-main checkouts live under `/private/tmp` because the shared checkout contains unrelated edits and its Git metadata is read-only.

## Deviations from Plan

### Execution adjustment

The plan's `tmp/phase-247-*` example paths were replaced with clean clones under `/private/tmp/sigra-phase247-plan07-*`. After protected merge, the four exact merged blobs were copied into the shared checkout only after confirming those paths had no preexisting local edits. No unrelated dirty path was staged or overwritten.

**Total deviations:** 1 execution adjustment; no product-scope deviation.

## Issues Encountered

- A zsh loop variable named `path` shadowed `PATH` and caused the first pre-capture check to exit before invoking the helper. Renaming it to `source_file` resolved the invocation issue; fresh pre- and post-capture PR/main checks and helper capture then passed.
- The shared checkout's Git metadata is read-only, so this executor did not create a summary/state metadata commit or stage shared planning files. The evidence commits and protected merge are present on GitHub.

## User Setup Required

None for Plan 07. The authenticated Hex dry-run remains outside this plan and was not dispatched.

## Next Phase Readiness

Plan 07 is complete. Plan 05 remains checkpointed per the user's choice to continue waiting. Plan 08 has not started; it owns any later credential-bound workflow step. No Hex credential metadata was inspected, no dry-run was dispatched, and no tag, publication, or PR #224 merge occurred.

## Self-Check: PASSED

- This summary exists at the required path.
- Task commits `389870c5`, `0d5e0502`, and `b3739e09` are present in the isolated evidence branch.
- The protected evidence merge is `9bb7566f31b40a129c5a234b122ac00b540ede29`; post-merge helper verification passed.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-08*
