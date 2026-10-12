---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 06
subsystem: release
tags: [protected-main, public-proof, final-acceptance]
provides:
  - Exact current-main receipt and CI evidence distinct from package-source identity.
  - Final public-release, PR-disposition, preservation, and clean-worktree acceptance.
affects: [249-08, 249-12, release-closeout]
key-files:
  created: [.planning/phases/249-publish-and-prove-sigra-1-6-0/249-06-SUMMARY.md]
  modified: [.planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-MAIN-PROOF.json, .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json]
key-decisions:
  - "Keep the published package-source SHA and its CI distinct from later protected-main SHA and CI."
  - "Replace the original blocked post-merge snapshot with a fresh final acceptance after the scoped merge and all summary/state commits."
requirements-completed: [REL-01, REL-02]
coverage:
  - id: D1
    description: Hex 1.6.0, versioned docs, tag, and resolving source reference still agree with the immutable release receipt.
    requirement: REL-01
    verification:
      - kind: other
        ref: "249-FINAL-ACCEPTANCE.json in refs/heads/evidence/phase-249-final-acceptance: public_release.verdict=passed; package_source_sha=9e80cb78d6374b1ed4074d5fef6b613fee879dca"
        status: pass
    human_judgment: false
  - id: D2
    description: Protected main contains the exact receipt and has successful ordinary CI and ci-gate on its exact SHA.
    requirement: REL-02
    verification:
      - kind: other
        ref: "249-FINAL-MAIN-PROOF.json: main 3c7d713f290c93de3b9fd54be7ece31d71f32787; run 37993629114; job 114036565274"
        status: pass
    human_judgment: false
  - id: D3
    description: Every current open PR is dispositioned and each registered worktree is clean after the terminal ref write.
    requirement: REL-02
    verification:
      - kind: other
        ref: "249-TERMINAL-STATUS.json in refs/heads/evidence/phase-249-final-acceptance: 14 PRs; six empty raw status records and matching reread"
        status: pass
    human_judgment: false
status: complete
completed: 2026-10-09
---

# Plan 249-06 — Final Main and Release Acceptance

**The release-source, protected-main, and repository-closeout conditions first blocked here now pass on fresh exact-identity evidence.**

## Accomplishments

- Revalidated the public Sigra 1.6.0 package, versioned HexDocs, tag, source destination, and immutable package-source commit `9e80cb78d6374b1ed4074d5fef6b613fee879dca`.
- Proved protected main `3c7d713f290c93de3b9fd54be7ece31d71f32787` contains the committed receipt and has successful ordinary CI run `37993629114` and `ci-gate` job `114036565274` on that exact SHA.
- Refreshed and dispositioned all 14 open PRs; the terminal evidence records two empty raw porcelain reads for all six registered worktrees.
- The original blocked Plan 06 result remains available at `refs/phase-249-preservation/e581c59e8739fd8040f72ccf27588a8b` with SHA-256 `c67accf396abade1977b807937400d4151efe9c36fb5205b19d05102416939c9`. It records the earlier missing-receipt and unmerged-PR state and is retained as historical evidence.

## Verification

- Final acceptance on the scoped evidence ref has verdict `passed`, with no errors or blockers.
- Public release proof, protected-main receipt/CI join, accepted-loss preservation audit, complete 14-PR dispositions, and six-worktree terminal seal all pass.
- The terminal record is stored only at `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-TERMINAL-STATUS.json` in `refs/heads/evidence/phase-249-final-acceptance`; its own commit identity is resolved from that ref.

## Original Execution Disposition

Plan 06's original final acceptance was blocked because the scoped Phase 249 PR had not yet merged and the receipt was absent from then-current main. The exact old summary is preserved on the ref above. Plans 11 and 12 later completed the merge and reran the full public/main/PR/worktree proof; this summary records that downstream completion without altering the original blocked result.

## Next Phase Readiness

Phase 249's release proof is complete. The next GSD action is the v1.49 milestone audit; `init.plan-phase 250` reports no Phase 250 in the roadmap.
