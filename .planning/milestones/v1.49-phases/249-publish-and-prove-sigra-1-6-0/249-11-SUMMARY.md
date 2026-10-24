---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 11
status: complete
completed_at: 2026-10-09T21:28:08Z
---

# Plan 11 Summary: Protected Promotion

PR [#304](https://github.com/szTheory/sigra/pull/304) promoted the reviewed Phase 249 candidate through GitHub's protected squash auto-merge. The exact candidate head was `4e631d895caa1e02108e05ed9d68069990ca305f`, based on `e2fa303017364c7e496c3c620f7b709c8e90c8fb`; GitHub recorded squash merge `3c7d713f290c93de3b9fd54be7ece31d71f32787` at `2026-10-09T21:28:08Z`. The immutable 1.6.0 package-source receipt remained unchanged.

The successful candidate run was [CI run 37992672660, attempt 1](https://github.com/szTheory/sigra/actions/runs/37992672660), on that exact candidate head. Its `ci-gate` job `114033358088` succeeded. The candidate contains 15 scoped paths: the Plan 09 and 10 release-proof work plus one Phase 232 workflow-contract test for the PostgreSQL registry correction.

The first candidate CI run failed twice after parallel jobs exhausted Docker Hub's anonymous pull allowance while pulling `postgres:15`. The failed logs showed correlated service-container startup failures, not application test failures. No Docker Hub credentials were configured, so both `.github/workflows/ci.yml` and `.github/workflows/release-please.yml` now use Docker's official PostgreSQL image from the public AWS ECR mirror. The Phase 232 contract test asserts the exact image source. The successful run completed the affected service-container, library, install, HTTP, and Playwright checks, and confirms this mirror works in hosted CI.

The protected merge completed before local evidence persistence reported `unable to create temporary file` under `.git/objects`; the command sandbox had a writable checkout but read-only Git storage. GitHub was re-read before recovery, confirming that PR #304 had already merged. The exact captured promotion bytes (SHA-256 `9fde3c1c2516e75421d04d2aef2ba77c93f20f63288ac6d8f134b1d3d065870e`) were then appended to `refs/heads/evidence/phase-249-promotion` at commit `9b1074975077ffdc5a711327a2de50bce15b787f`, descended from blocked checkpoint `320fe1beaea388d86e9d294f66ab39233c6a1e15`; read-back matched byte-for-byte before the stranded working-copy file was removed.

This recovery exposed a validator contract mismatch as well: Plan 11 correctly recorded the exact-head internal review artifact, while the original post-merge validator accepted only hosted GitHub approvals. Plan 12 now validates either form through the same exact-head review rules and requires the internal review source hash to match the candidate artifact bytes. A regression test covers both matching and mismatched hashes. The first blocked final-main proof was preserved before refresh at final-acceptance evidence commit `6f0fbfb8fd8e07e5bec28cf6040e59f82dc37e39`, with exact byte SHA-256 `febe0455cedd8631c81c731c09cfa7b1eeaa282b0f8406cbdf2b0c358c8aa43a`.

## Verification

- Candidate local release and contributor checks passed as recorded in `249-10-CANDIDATE.json`.
- Hosted candidate CI run `37992672660`, attempt 1, succeeded on the exact candidate SHA with successful `ci-gate` job `114033358088`.
- `node --check .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs` passed.
- `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` passed: 58 tests, 0 failures.
- The promotion record on `refs/heads/evidence/phase-249-promotion` validated as `promoted`; main receipt and exact-main CI remain Plan 12 acceptance inputs.

## Preventive Lesson

Before requesting an external merge, preflight local Git object writes and expected-old evidence-ref updates in the same repository that must preserve the result. A successful write to the working tree does not prove `.git/objects` is writable. If persistence fails after an external action, re-read the external state and preserve the captured bytes before any retry; never replay the merge blindly. This rule is now in `.planning/METHODOLOGY.md`.

The remaining work is Plan 12: prove the unchanged receipt and successful `ci-gate` on the resulting protected-main SHA, refresh PR/worktree inventories, verify the published release read-only, and seal the terminal clean-worktree record.
