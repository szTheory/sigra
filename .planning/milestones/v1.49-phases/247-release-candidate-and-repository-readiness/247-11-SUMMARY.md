---
phase: 247-release-candidate-and-repository-readiness
plan: 11
subsystem: release-readiness
tags: [release, readiness, playwright, hex, evidence]
dependency_graph:
  requires: [247-09, 247-10]
  provides: [source-bound-hex-receipt, final-readiness-ledger, independent-phase-verification]
  affects: [READY-01, READY-02]
tech_stack:
  added: []
  patterns: [exact-source-evidence, fail-closed-validation, independent-verification]
key_files:
  created:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-11-SUMMARY.md
  modified:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-VALIDATION.md
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md
decisions:
  - Use only the approved candidate, reviewed base, merged evidence PR, and manifest blob tuple for final release evidence.
  - Treat local WebKit as blocked by AppKit while accepting the exact-head successful mobile WebKit CI result as browser evidence.
  - Require every current candidate claim mapping to use exact-head CI run 37819712610.
metrics:
  duration: 43m
  completed: 2026-10-08
  status: complete
actuals:
  tokens: 24768
  tasks: 3
  commits: 0
plan_head_before: 17585574724ce5c9b256c18c8f1605de5865d3d4
plan_head_after: 17585574724ce5c9b256c8f1605de5865d3d4
commits: 0
---

# Phase 247 Plan 11: Final source-bound readiness Summary

The approved Playwright-repaired candidate now has a successful authenticated non-publishing Hex dry-run, a final READY-01/READY-02 ledger with complete current inventories, and an independent Phase 247 verification report at 14/14 truths.

## Completed Tasks

| Task | Result | Evidence |
|---|---|---|
| 1. Authenticated dry run | Passed, run `37824714823` attempt 1 | Safe receipt records the exact candidate/base/evidence merge, successful `mix hex.publish --dry-run --yes`, boolean credential presence, and Hex 404 before/after. |
| 2. Final ledger | Passed, 28 tests | Validator reports `valid: true`, `status: ready`, and zero diagnostics for candidate `0e773d3614a242e4fbcdd34c418ecb8a307703d6`; inventory includes 14 open PRs, 409 inherited commits, and 1,313 paths. |
| 3. Independent verification | Passed, 14/14 truths | Independent GSD verifier updated `247-VERIFICATION.md`; final report is bound to the same candidate SHA and leaves no gaps. |

## Source and Evidence Tuple

- Candidate PR #224 remains open at `0e773d3614a242e4fbcdd34c418ecb8a307703d6`, based on `d135cbce343947499a0810736c500ef5f1cb5c32`. Its isolated checkout is clean.
- Exact-head required CI run `37819712610` attempt 1 passed, including the mobile WebKit organization lane and `ci-gate`.
- Protected evidence PR #297, head `9d07f211c7a30afd97ae2b6e762f65b683e93a7b`, merged at main `51be73415cf6de5531d3fb4c91ec3caf2c7544b6` with exactly the four approved evidence paths. Manifest blob `12daf4f704bbc2d4aa136d0ef678e64abce38aeb` matches at PR head and main.
- The reviewed-base-to-candidate raw diff is SHA-256 `85020173c21fded708030b7422bb00ddd1510a073010122e6cf5364527772ec4`, 9,906 bytes.
- All five current claim mappings use candidate CI run `37819712610`. The validator now rejects the superseded CI source `37700772880`.

## Verification

- `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs`: 28 passed, 0 failed, 0 skipped.
- `bash scripts/ci/phase-247-hex-dry-run.test.sh`: 25 fixtures passed; receipt timestamp check passed.
- `actionlint .github/workflows/phase-247-hex-dry-run.yml`: passed.
- Trusted helper `verify-baseline`: passed; it independently recomputed the digest/bytes and verified the exact four-path main advance.
- Final readiness validator: passed with `PHASE_247_TRUSTED_REPO_DIR=/private/tmp/phase247-postmerge` at `2026-10-08T19:11:09Z`.
- Independent verifier: passed, 14/14 truths at `2026-10-08T19:11:31Z`.

## Known Limitation

Local WebKit remains `blocked_host_appkit`: the cached browser aborts before the test page starts. No local browser proof is claimed. Exact-head remote mobile WebKit CI passed and the independent verification report records this limitation explicitly.

## Scope

The approved evidence PR was merged and the authorized non-publishing dry run was executed. Candidate PR #224 remains open. No tag, release publication, candidate merge, or second evidence rebind was performed. Plan artifacts remain uncommitted in the inherited shared checkout to avoid capturing unrelated dirty work.
