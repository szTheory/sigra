---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 12
subsystem: release
tags: [release, evidence, ci, closeout]
provides:
  - Exact final-main receipt and CI evidence separate from immutable package-source identity.
  - Canonical public-release acceptance and a ref-only raw-status terminal seal.
affects: [release-closeout, v1.49-milestone-audit]
key-files:
  created: [.planning/phases/249-publish-and-prove-sigra-1-6-0/249-12-SUMMARY.md]
  modified: [.planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs, .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs, .planning/METHODOLOGY.md]
key-decisions:
  - "Run the terminal seal as the final repository mutation; keep the canonical acceptance and terminal record on the scoped ref."
  - "Preserve the historical handoff loss as an explicit accepted-loss identity without claiming its bytes were recovered."
requirements-completed: [REL-02]
coverage:
  - id: D1
    description: The final protected-main release commit contains the exact receipt and has successful CI and ci-gate on its exact SHA.
    requirement: REL-02
    verification:
      - kind: other
        ref: "249-FINAL-MAIN-PROOF.json: 3c7d713f290c93de3b9fd54be7ece31d71f32787, run 37993629114, job 114036565274"
        status: pass
    human_judgment: false
  - id: D2
    description: Every open PR is dispositioned and every registered worktree remains clean after the terminal ref write.
    requirement: REL-02
    verification:
      - kind: other
        ref: "249-TERMINAL-STATUS.json on refs/heads/evidence/phase-249-final-acceptance: 14 PRs and six byte-empty raw status records with matching reread"
        status: pass
    human_judgment: false
status: complete
completed: 2026-10-09
---

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

## Post-summary security follow-up (2026-10-09)

- Final review found redirect-validation gaps for lookalike Hex/HexDocs hostnames and delimiter-only `?` / `#` URLs. The proof helper now parses effective URLs, checks HTTPS, exact endpoint paths and dot-delimited trusted hosts, and rejects user-info, non-default ports, queries, and fragments. The focused adversarial suite passes 60/60.
- PR #305 head `238eb1d68dd797222a869e5a98676aca4ebef651` passed exact-head CI run `38003010120`, then guarded squash auto-merge completed as `08300af1740fea8b77d5928a182688acbf103edc`. Full final-main CI run `38003573391` passed, including `ci-gate` job `114069179560` and documentation job `114067129936`.
- `249-FINAL-MAIN-PROOF.json` now binds the release receipt and successful CI to the new exact `main` SHA. The prior proof remains recoverable from commit `085ad4bfbbf93031d20b970130687fcbea5da466`, blob `3786fb09a9b471290c02080e3e49fb89ac600b09`.
- The earlier docs mismatch came from running a 1.6.0 index comparison in the stale 1.5.0 phase worktree. A clean checkout of protected-main SHA `3c7d713f290c93de3b9fd54be7ece31d71f32787` passed `mix docs --warnings-as-errors` and the full index comparison on Elixir 1.18.4 / OTP 27.3.4.15; final-main CI repeated the docs gate on `08300af` successfully. `.planning/METHODOLOGY.md` now requires recording exact source, version, tree state, and toolchain, then reproducing mismatches on the exact candidate/target before calling them product failures.
- The security register is verified with zero open high-or-higher threats. Because this follow-up adds review, security, validation, and state artifacts after the previous seal, the closeout ledger, canonical acceptance, and terminal ref-only seal must be refreshed once more before phase completion.
