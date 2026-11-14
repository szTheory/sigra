# Phase 245 Plan 38: Branch prune partial result

Task 3 applied nine approved local origin-tracking deletions before the guarded operator stalled at a later boundary and was interrupted. Fourteen approved tracking refs remain unchanged at their pinned identities, so REPO-04 remains open.

## Approval and contract

- Approval: exact rows approved for contract commit `13760574de0318fd1c120990386473a260cf9a4d` and allowlist SHA-256 `e98cf698eb8792230c37d144820ecd6da8e9783ea6684255b3b7e4aa6a4b9ed1`.
- Contract SHA-256: `6cf2e2e8c4f5e15281755c4b9bc91bfcc8db0d285c878dc062f4226b180fbd81`.
- Admission SHA-256: `e88c090a5fa580bc6ab2730845da324dd9152b02f48df05e6c7a54fbd974560a`.
- Operator exit: 130 (SIGINT after prolonged silence); the ninth deletion completed in-flight and was confirmed absent by coordinator-held local readback and two post-captures.

## Applied tracking rows

| Ref | Expected OID | Type |
|---|---|---|
| refs/remotes/origin/brandbook-rail-accent-logo-system | 093a2a77b3ff13ea17a4cc2a2439a56ddf54c8cd | commit |
| refs/remotes/origin/dependabot/github_actions/actions/attest-build-provenance-4.2.2 | e101caefbe96923dc23c956f71a4cce5aa780fe7 | commit |
| refs/remotes/origin/dependabot/hex/credo-1.7.19 | 39a3790ea829d80f864ffbf1564e97052a4262b3 | commit |
| refs/remotes/origin/dependabot/hex/flop_phoenix-0.26.3 | 6e5fdd7dcc3f25c731791b9e3f819f6bd42db8dd | commit |
| refs/remotes/origin/dependabot/hex/hammer-7.4.1 | 77b4259f1dbd3507fab2f9a8c743c5576eeeef3a | commit |
| refs/remotes/origin/dependabot/hex/oban-2.24.0 | 2086bd14372f493a2ec2cf56b56e21b72e5b18cf | commit |
| refs/remotes/origin/dependabot/hex/threadline-0.9.0 | a7ccd0995d5bd82c9a3c0aa6f9195d266039f14f | commit |
| refs/remotes/origin/dependabot/npm_and_yarn/test/example/priv/playwright/anthropic-ai/sdk-0.123.0 | 859a77deb5a000024a5022e7ea28be790c3d4c51 | commit |
| refs/remotes/origin/dependabot/npm_and_yarn/test/example/priv/playwright/axe-core/playwright-4.13.0 | f67c9115b5aaebc7e38073bef8f1abefd73ae6c9 | commit |

## Remaining approved tracking rows

| Ref | Expected OID | Type |
|---|---|---|
| refs/remotes/origin/dependabot/npm_and_yarn/test/example/priv/playwright/otplib-13.5.0 | 204ce7f59ad2b1a2f709261f69bc35235bdc813c | commit |
| refs/remotes/origin/dependabot/npm_and_yarn/test/example/priv/playwright/playwright/test-1.62.1 | 9f5150bd3a000dc122e8c185bf06c102ac720667 | commit |
| refs/remotes/origin/dependabot/npm_and_yarn/test/example/priv/playwright/zod-4.5.4 | c06cc1475ca91519765b3792958bcadd9f131601 | commit |
| refs/remotes/origin/gsd/phase-236-flake-root-cause | 337538c48b79c358f19a9e1c514a7a373379d353 | commit |
| refs/remotes/origin/gsd/phase-239-priv-templates-sweep | 5abd3ede7fc11f96a66739e53283f9d5aec3c6ec | commit |
| refs/remotes/origin/gsd/phase-240-closeout | 9b4bb4a7f64585e69b2fa55a1266acfb8c9fad4b | commit |
| refs/remotes/origin/gsd/phase-240-green-main-evidence | 4429657a725ef5601fe2e0b25cebcd54c314540e | commit |
| refs/remotes/origin/gsd/phase-241-context | e6b63ca1698e23adb99c84f088fc9ad469122496 | commit |
| refs/remotes/origin/gsd/phase-241-plans | a38651a37875a340462c647d5f9b1beed30893dd | commit |
| refs/remotes/origin/gsd/phase-241-research | 62906d14da1cd4c72e5080c1fa686ba4d6948ca8 | commit |
| refs/remotes/origin/gsd/quick-260918-lfq-bookkeeping | daa8b41f3d458c66ecacb7a0276ab8b65ffc38d6 | commit |
| refs/remotes/origin/gsd/quick-green-04-collector-guards | cea7098347086166ec3ec6e1a8e0db0403d5b9c0 | commit |
| refs/remotes/origin/gsd/state-reconcile-241 | 21c6c25a996ec3497cf89b656bcd0759e5176039 | commit |
| refs/remotes/origin/v1.37-auth-branding-admin-polish | b9cbb7a7b442f0d04b985c01c30a4a4db24a1d1f | commit |

## Post-state checks

Two complete captures agreed: 119 local refs, 361 exact origin refs, and 14 open PRs. Origin refs and PR identities match the contract; only the nine listed tracking refs are absent. All 979/979 recorded Plan 18 and Plan 38 direct/peeled objects are readable at their recorded types. The blocked RESULT does not claim a passed candidate census or close REPO-04.

The complete machine-readable observation is in `245-38-POST-STATE.json`. Task 3 stopped after the interruption and did not apply the remaining rows.
