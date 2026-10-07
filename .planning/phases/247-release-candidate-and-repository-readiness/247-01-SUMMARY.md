---
phase: 247-release-candidate-and-repository-readiness
plan: 01
subsystem: release-readiness
tags: [git, github, inventory, node, ci-evidence]

requires:
  - phase: 246-generated-confirmation-recovery
    provides: Passing exact-source CI receipt and Phase246 verification.
provides:
  - Validated inventory of inherited checkout, dirty paths, commits, and live pull requests.
  - Reviewed protected-main source selection and clean isolated candidate worktree.
  - Inventory and checkout validators tied to immutable and live source identities.
affects: [247-02, 247-03, 247-04, release-candidate]

actuals:
  tokens: 884512
  tasks: 2
  commits: 17

tech-stack:
  added: []
  patterns: [stable-key inventory updates, immutable entry snapshot, fail-closed readiness validation, exact-source evidence binding]

key-files:
  created:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/247-01-tdd-red-evidence.json
  modified:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-01-SUMMARY.md

key-decisions:
  - "Keep the immutable entry inventory and refresh a separate current snapshot before making source decisions."
  - "Promote only the four Phase246 files whose blobs match the tested source and whose scoped PR passed review and CI; exclude other inherited work and open PRs."
  - "Pin the candidate to protected main only after its own required CI passes."

requirements-completed: [READY-02]

coverage:
  - id: D1
    description: "Inherited checkout and live PR inputs are captured in a validated disposition ledger."
    requirement: READY-02
    verification:
      - kind: unit
        ref: "node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs"
        status: pass
      - kind: other
        ref: "node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage inventory .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json"
        status: pass
    human_judgment: false
    rationale: "The inventory validator re-enumerates live Git/GitHub identities and compares all stable-key populations to the current snapshot while preserving the immutable entry snapshot."
  - id: D2
    description: "Select reviewed source and isolate its clean candidate checkout."
    requirement: READY-02
    verification:
      - kind: other
        ref: "node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage checkout .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json"
        status: pass
      - kind: ci
        ref: "https://github.com/szTheory/sigra/actions/runs/37686980115 (attempt 2, main 590eb4e, success)"
        status: pass
    human_judgment: false
    rationale: "Exact Phase246 evidence, reviewed PR #288, its protected-main squash promotion, passing main CI, four source blob matches, and a clean worktree at the selected SHA are recorded in the ledger."

decisions:
  - "Phase246 source SHA 90ec16f72a71d33224c0816ad77762e2e7262c76 passed ci-gate, install smoke, and generated-admin Playwright smoke."
  - "Scoped PR #288 promoted the four approved paths and squash-merged as 590eb4ed3323db11dd74326cbee00c9c7973e529; the selected main CI run passed on attempt 2."
  - "The inherited checkout and all excluded inherited objects remain preserved; the candidate worktree is a separate clean detached checkout."

duration: 2h47m
completed: 2026-10-07
status: complete
plan_head_before: 7e5c19361135aeb63bac006323ffd5899e0d402b
plan_head_after: 3a70baee9da3b9f1e9ff603566c6bbfa62f7687b
---

# Phase 247 Plan 01: Release Readiness Inventory Summary

The validated ledger preserves 380 inherited commits, 1,277 committed-path records, 64 dirty paths, and all 14 currently open PRs; the release candidate is isolated at reviewed main SHA `590eb4e` after exact Phase246 evidence and its own complete CI passed.

## Performance

- **Duration:** 2 hours 47 minutes across the resumed checkpoint and Task 2.
- **Started:** 2026-10-06T23:22:47Z
- **Completed:** 2026-10-07T22:09:09Z
- **Tasks:** 2 of 2 complete.
- **Files modified:** 3 task artifacts and this summary; inherited Phase246/user-dirty files were preserved.

## Accomplishments

- Preserved the original entry snapshot and recorded a fresh live inventory after the Phase246 promotion changed main and the open-PR population.
- Confirmed Phase246's exact tested source SHA `90ec16f72a71d33224c0816ad77762e2e7262c76` had passing `ci-gate`, install smoke, and generated-admin Playwright smoke, with its phase verification at 10/10.
- Promoted only the four approved Phase246 paths through reviewed PR [#288](https://github.com/szTheory/sigra/pull/288). Their blobs match the tested source. The PR passed CI and squash-merged to protected main as `590eb4ed3323db11dd74326cbee00c9c7973e529`.
- Required CI and the full main workflow passed on attempt 2 for the exact selected main SHA, including all Playwright shards, install matrices, generated-admin, golden/idempotency, aggregate lifecycle, `ci-gate`, and admin-eval render.
- Created ignored `tmp/phase-247-candidate` as a clean detached worktree at the selected main SHA. The inherited checkout and all other inherited objects remain preserved and explicitly excluded in the ledger.
- Extended the validator with a checkout stage that checks live main, refreshed `origin/main`, candidate HEAD/cleanliness, exact Phase246 receipt, reviewed promotion, and the four approved paths.

## Task Commits

- Task 1 test and implementation: `9643d20f4`, `83aff7df0`.
- Task 2 implementation: `3a70baee9`.
- The measured plan range is `7e5c19361135aeb63bac006323ffd5899e0d402b` through `3a70baee9da3b9f1e9ff603566c6bbfa62f7687b`, containing 17 commits.

## Verification

- `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` — 5 passed.
- `node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage inventory .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` — ready; 380 commits, 1,213 unique committed paths, 64 dirty paths, 14 open PRs.
- `node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage checkout .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` — ready; candidate clean at the selected SHA.
- `git diff --check` on task artifacts — passed.
- Main CI [run 37686980115](https://github.com/szTheory/sigra/actions/runs/37686980115), attempt 2 — success for exact SHA `590eb4ed3323db11dd74326cbee00c9c7973e529`.

## Deviations from Plan

**1. Scoped the Phase246 promotion to a dedicated four-path PR.** The original Phase246 branch contained hundreds of commits ahead of main, so it was not safe to merge wholesale. The already-tested source was promoted through normal protected-branch review and CI using PR #288; only the four approved paths were selected.

**2. Refreshed the current inventory after promotion.** PR #288's merge changed protected main and the live PR set. The immutable entry snapshot remained unchanged, and a new additive snapshot was captured before source selection.

## Self-Check: PASSED

- Summary, ledger, validator, and test files exist.
- Task commits `9643d20f4`, `83aff7df0`, and `3a70baee9` are ancestors of HEAD.
- Candidate worktree HEAD is `590eb4ed3323db11dd74326cbee00c9c7973e529` and its status is clean.
- Both inventory and checkout stages pass; focused tests pass 5/5.

**Next:** continue with the next ready Phase247 plan through `$gsd-execute-phase 247`.
