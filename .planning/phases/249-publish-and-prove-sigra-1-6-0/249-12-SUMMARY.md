# Plan 249-12: Final Main and Terminal Closeout

Plan 249-12 closes the release proof for the protected-main commit and adds an automated, ref-only terminal seal for the complete worktree set. The final ledger and acceptance are refreshed only after this summary and the implementation are committed; the terminal record on `refs/heads/evidence/phase-249-final-acceptance` is the final cleanliness authority.

## Release Evidence

- Published Sigra 1.6.0 remains bound to package-source commit `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, its source CI run `37875238741`, versioned docs, and tag `v1.6.0`. The public proof is read-only and does not republish or recreate release identities.
- Protected main is `3c7d713f290c93de3b9fd54be7ece31d71f32787`, which contains the exact release receipt. Its ordinary CI run `37993629114` and `ci-gate` job `114036565274` passed on that same SHA. This later main evidence stays separate from package-source identity.
- The final closeout recaptures all worktrees and open PRs. Its previous complete snapshot contained six worktrees and 14 open PRs, each dispositioned; the final acceptance replay refreshes those live identities.
- The old `.planning/HANDOFF.json` revision remains an explicitly user-authorized `accepted-with-recorded-loss` identity. It is not described as recovered, and the closeout keeps it outside the release candidate.

## Trap Diagnosis and Prevention

The required terminal closeout step had been specified in Plan 12 but did not exist in `validate-closeout.mjs`. Final acceptance was also generated at a tracked path after inventory capture, so writing the proof itself could make the worktree dirty and invalidate the evidence that had just passed. The validator now supports a terminal mode that compares the full canonical release identities, checkpoints the existing scoped evidence ref with compare-and-swap, stores literal NUL-safe status bytes for every registered worktree, writes a ref-only terminal record, and rereads every worktree after that write. Missing, dirty, changed, or unreadable status blocks the seal.

`.planning/METHODOLOGY.md` now makes this sequence a project default: implement and test the terminal writer before multi-step closeout; commit source, summaries, and state before refreshing the ledger; keep canonical proof writes off tracked worktree paths; and run the terminal seal as the last repository mutation. The historical handoff loss has a different diagnosis: retained records cannot identify the replacing tool, so prevention remains write-ahead byte preservation rather than a speculative root-cause claim.

## Validation

- `node --check .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs` passed.
- `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` passed all 60 tests, including terminal ref-only sealing, canonical-byte identity, missing/nonempty raw statuses, and the post-write reread.
- `git diff --check` passed.

After this summary and all tracked closeout inputs are committed, regenerate `249-CLOSEOUT.json` from a clean boundary, run preservation and final acceptance into ignored task-local output, copy the exact passed acceptance bytes to the scoped evidence ref, and run terminal mode. Do not edit tracked phase evidence after that terminal ref passes; the terminal commit OID is resolved from the ref rather than embedded in its own record.
