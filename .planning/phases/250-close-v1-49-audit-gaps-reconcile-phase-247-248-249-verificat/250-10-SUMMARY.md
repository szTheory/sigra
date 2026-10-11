---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
plan: 10
subsystem: release-validation
tags: [github-actions, playwright, release-proof, phase-249]
requires:
  - phase: 250-07
    provides: authorized exact-main canary evidence and delivery route
provides:
  - Fresh Phase 249 REL-01/REL-02 snapshot and passing owner report
  - Exact protected-main workflow evidence and current PR/worktree inventory
  - Compare API ancestry validation and nested historical-report regression coverage
affects: [phase-250-closeout, release-validation]
actuals:
  tokens: 437284
  tasks: 3
  commits: 10
tech-stack:
  added: []
  patterns:
    - Bind GitHub Compare evidence to the exact request URL, base SHA, merge-base SHA and status fields.
    - Preserve the historical verification report inside the new report and verify its outer details boundary.
key-files:
  created:
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-10-SUMMARY.md
  modified:
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-CURRENT-PROOF-DIAGNOSTIC.json
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-SOURCE-SNAPSHOT.json
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs
    - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs
    - test/example/priv/playwright/tests/admin-eval.spec.ts
    - scripts/ci/phase-250-main-ci-gate.sh
key-decisions:
  - "Use the exact GitHub Compare API request and its base/merge-base/status fields as source-bound ancestry evidence; the response does not expose head_commit."
  - "Accept GitHub owner/repository path casing differences only for the exact szTheory/sigra slug; preserve exact version, source path and SHA checks."
  - "Keep local WebKit launch failure as an environment limitation; use the successful exact-main admin-eval lane as mobile verification."
patterns-established:
  - "Record Compare URL, requested head SHA, response keys, result fields and observation time in the source snapshot."
requirements-completed: [REL-01, REL-02]
coverage:
  - id: D1
    description: Public Sigra 1.6.0 Hex, docs, tag and source reference resolve to the accepted package source and checksum.
    requirement: REL-01
    verification:
      - kind: integration
        ref: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-SOURCE-SNAPSHOT.json#public_release
        status: pass
      - kind: unit
        ref: bash scripts/ci/release-public-proof.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Exact protected-main CI, full open-PR dispositions and clean worktree inventory satisfy the Phase 249 owner report.
    requirement: REL-02
    verification:
      - kind: integration
        ref: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-SOURCE-SNAPSHOT.json
        status: pass
      - kind: other
        ref: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-CURRENT-PROOF-DIAGNOSTIC.json#current_main_ci
        status: pass
      - kind: unit
        ref: verify-249-release.mjs --check-report .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md
        status: pass
    human_judgment: false

duration: 409min
completed: 2026-10-11
status: complete
plan_head_before: 9ccec6c5b89f6417d1c2320603c9efd3be8983a6
plan_head_after: c69ca0142438ac23745b7d7f1d62a19e2fe8e55c
---

# Phase 250 Plan 10: Refresh Phase 249 Release Evidence Summary

**Phase 249 now has passing public-source and exact-main CI evidence, with all 15 open PRs dispositioned against their current identities and all five registered worktrees clean.**

## Performance

- **Duration:** 409 minutes, measured from the persisted Plan 10 starting-head ledger at 2026-10-11T08:57:50Z.
- **Completed:** 2026-10-11T15:46:26Z
- **Tasks:** 3
- **Files changed in the plan diff:** 78, including the final snapshot, owner report and this summary.

## Accomplishments

- Captured a fresh public proof for Hex 1.6.0, versioned docs, tag and canonical source URL. The source URL returned HTTP 200; tag `v1.6.0` resolves to package source `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, matching checksum `e71dd35586011fbb387b4215e86d883ba2c3312f0e4a390ed107552affb75997`.
- Repaired the admin-eval registration navigation wait and added a protected-main workflow gate that records exact run/job identities and sanitized failure evidence. Final main CI run [38146312411](https://github.com/szTheory/sigra/actions/runs/38146312411), attempt 1, passed at `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`. The admin-eval job `114490322445`, ci-gate job `114491782314`, and all 30 required jobs passed; the conditional red-ci notification job was skipped because ci-gate succeeded.
- Refreshed the Phase 249 snapshot and owner report. REL-01 and REL-02 both pass. The historical release main `08300af1740fea8b77d5928a182688acbf103edc` is proven as an ancestor of current main by GitHub Compare: status `ahead`, `ahead_by: 22`, `behind_by: 0`, and merge base equal to the historical SHA. The snapshot records the exact Compare URL, requested head SHA, observed time and response keys.
- Reconciled the current open-PR population and preserved accepted historical HANDOFF loss as accepted-with-recorded-loss; no bytes are claimed recovered.

## Current release evidence

| Evidence | Result |
| --- | --- |
| Protected main | `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97` |
| Full CI | Run `38146312411`, attempt 1, success |
| Admin eval | Job `114490322445`, success |
| CI gate | Job `114491782314`, success |
| Public source | HTTP 200, `https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1` |
| Package source | `9e80cb78d6374b1ed4074d5fef6b613fee879dca` |
| GitHub Compare | `ahead`, 22 ahead, 0 behind, merge base `08300af1740fea8b77d5928a182688acbf103edc` |

Evidence digests: snapshot SHA-256 `c78756977c05d8f13e1cf5de5c174852e90b33b42f71a82a39364c08985bd09d`; owner report SHA-256 `1245ce7bfc639c102cb50ac4dfc96a12ca5773393aa664fdcdef51e2db74dd74`; diagnostic SHA-256 `8944e075e02989700ccb9d0a1fba8b6937df2a74e63bf336214a3599b5fbc066`.

## PR population

All 15 open PRs have one identity-matched disposition in the source snapshot:

| PRs | Disposition |
| --- | --- |
| #219, #274, #275, #283, #306, #307, #308 | release-relevant |
| #266, #267, #268, #269, #271, #272, #273, #309 | separate-follow-up |

The five previously unrecorded rows are resolved as follows: #302 was merged separately as the 1.7.0 release at `ff96768bc2843ef1a89926d238690b1145bfd514` and is no longer open; #306, #307 and #308 are release-relevant future CI/release-workflow dependency updates; #309 is a separate example-app Playwright SDK dependency update. These classifications do not authorize merging other PRs.

## Captured worktrees

Every registered worktree was readable and had an empty raw porcelain status at capture (`e3b0c442…b855`):

| Path | Branch | Head | Status |
| --- | --- | --- | --- |
| `/private/tmp/sigra-250-07-observer-source-id-mode-fix` | `codex/250-07-observer-source-id-mode-fix` | `1f098052d3d4caf7d676749eacfb0a23b2df4ae5` | clean |
| `/private/tmp/sigra-250-canary-observer-dispatch` | `fix/250-canary-observer-dispatch` | `5fc3b2f30528526d9342713d3d04f2eaf489ea6d` | clean |
| `/private/tmp/sigra-main-preflight-20261011` | `fix/release-canary-artifact-download` | `c9d48ac196fe6dbd5041668f56eb87840764c520` | clean |
| `/Users/jon/projects/sigra` | `phase-244-playwright-measurement` | `c69ca0142438ac23745b7d7f1d62a19e2fe8e55c` | clean |
| `/Users/jon/projects/sigra/tmp/phase-247-candidate` | `agent-phase247-plan02` | `563f411bc2659bb9ac1652d552ce58ffb0c876b1` | clean |

## Task commits

Measured from the plan ledger base, the 10 commits through the verified capture were: `8e0dca5`, `0f873e8`, `a61804c`, `a5029f9`, `b73579f`, `0f9b26d`, `b589b1b`, `7493b04`, `8c6b760`, and `c69ca01`. They cover diagnostic capture, admin-eval repair and gate, owner-ledger reconciliation, durable preservation, source/ancestry verifier tests, and the nested-report parser regression fix.

## Deviations from Plan

### Auto-fixed issues

1. **Rule 1 — source reference casing and ancestry proof.** GitHub serves the accepted source link with a lowercase owner path, while the verifier required a case-sensitive owner match. The verifier now normalizes casing only for the exact `szTheory/sigra` slug. Local Git did not contain the exact current main object, so ancestry is proven from the exact GitHub Compare request, requiring the expected base and merge-base SHAs, zero behind, and an `ahead` or `identical` result. The actual API response has no `head_commit`; the snapshot binds the requested main SHA through the exact compare URL and records the response keys and observation timestamp. Modified: `verify-249-release.mjs` and its tests.
2. **Rule 1 — nested historical report boundary.** The report checker stopped at a nested details close marker inside the preserved historical report. It now uses the final outer marker, with a regression test proving trailing historical content remains included. Modified: `verify-249-release.mjs` and its tests.

**Impact:** Both fixes restore exact source and report validation without relaxing SHA, tag, path, CI, or identity checks.

## Issues encountered

- Standalone focused mobile tests were blocked by the local environment’s missing locked WebKit executable; no browser installation was attempted. The final exact-main CI run’s admin-eval job passed and covered the mobile lane.
- An earlier exact-main run failed in admin-eval while ci-gate was green. Its sanitized diagnosis and the final successful run are retained in the diagnostic artifact.

## Validation

- `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs` — 12 passed.
- `bash scripts/ci/release-public-proof.test.sh` — 60 passed.
- Snapshot capture and report generation — REL-01 and REL-02 satisfied.
- Final evaluator predicate and report identity check — passed. The full freshness check is rerun after the final artifact commit so it sees the clean post-commit worktree state.

## Next phase readiness

Plan 10 closes the current Phase 249 release-evidence gap. Phase 250 as a whole remains incomplete: Plan 08 is halted and Plans 09, 11 and 12 remain blocked by it. This summary does not mark Phase 250 complete.

---
*Phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat*
*Completed: 2026-10-11*

## Self-Check: PASSED

The snapshot, owner report and this summary exist; all 10 measured Plan 10 commits are ancestors of the summary’s recorded plan head.
