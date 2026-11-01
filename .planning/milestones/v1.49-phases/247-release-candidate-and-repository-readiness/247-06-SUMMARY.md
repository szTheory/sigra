---
phase: 247-release-candidate-and-repository-readiness
plan: 06
subsystem: release-readiness
tags: [release, playwright, liveview, documentation, ci]
requires:
  - phase: 247-03
    provides: Source-bound candidate documentation and verification baseline.
provides:
  - Source-bound 1.6 adopter guide, changelog notes, README route, and ExDoc registration on PR #224.
  - Deterministic mobile organization-signup synchronization and passing exact-head CI evidence.
  - Candidate-stage review and readiness ledger refreshed against the exact PR source SHA.
affects: [247-07, 247-08, release-readiness]
actuals:
  tokens: 18173
  tasks: 2
  commits: 1
tech-stack:
  added: []
  patterns: [wait for server-rendered LiveView validation before real role-based submit]
key-files:
  created:
    - guides/introduction/upgrading-to-v1.6.md
  modified:
    - CHANGELOG.md
    - README.md
    - mix.exs
    - test/example/priv/playwright/tests/organizations.spec.ts
    - .planning/phases/247-release-candidate-and-repository-readiness/247-05-CURRENT-SOURCE-REVIEW.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
key-decisions:
  - "Keep Phase 246 tested-source SHA 90ec16f separate from its squash-promoted main SHA 590eb4e and current candidate base/main e3883b7."
  - "Use a clean /private/tmp candidate clone because the shared tmp worktree could not safely refresh its read-only shared Git metadata."
patterns-established:
  - "Synchronize LiveView browser tests on visible server-rendered feedback before submitting with a role-based control."
requirements-completed: []
coverage:
  - id: D1
    description: "The live release PR includes the versioned upgrade guide and source-backed 1.6.0 adopter notes."
    requirement: READY-01
    verification:
      - kind: integration
        ref: "PR #224 head 6f8028658f0bdd7f26e13c3fe4d45437880c341b; exact remote source blobs"
        status: pass
      - kind: other
        ref: "CI run 37717911489 attempt 1; docs build and ci-gate"
        status: pass
    human_judgment: true
    rationale: "Final READY-01 also requires the later authenticated release dry-run and evidence capture."
  - id: D2
    description: "Mobile organization signup waits for rendered LiveView validation before a real submission."
    requirement: READY-02
    verification:
      - kind: automated_ui
        ref: "CI run 37717911489 attempt 1, Example Playwright shard (non_admin_smoke)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The candidate review and readiness ledger validate against the exact live PR source and CI result."
    verification:
      - kind: unit
        ref: "node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs (21/21 passed)"
        status: pass
      - kind: integration
        ref: "validate-release-readiness.mjs --stage candidate --assert-live-refresh (valid: true, ready)"
        status: pass
    human_judgment: true
    rationale: "READY-02 still includes the final inventory and readiness capture assigned to later plans."
duration: 30min
completed: 2026-10-08
status: complete
---

# Phase 247 Plan 06: Release candidate source and CI summary

**PR #224 now carries the complete v1.6 adopter path and a deterministic mobile signup test on exact source SHA `6f8028658f0bdd7f26e13c3fe4d45437880c341b`.**

## Performance

- **Duration:** approximately 30 minutes
- **Tasks:** 2
- **Source files modified:** 5
- **Completed:** 2026-10-08

## Accomplishments

- Added curated 1.6.0 notes, connected README and ExDoc to the new upgrade guide, and documented compatibility, selective generated-host adoption, and the verified no-migration action.
- Updated both signup paths in the Playwright spec to wait for visible server-rendered `Strong` feedback before a role-based account-creation submit. No application behavior changed.
- Pushed all five source paths together to PR #224, then verified their remote blobs and required exact-head CI. Run `37717911489`, attempt 1, passed, including `ci-gate`, the warning-free docs build, and the mobile organization registration shard.
- Refreshed the current-source review and candidate ledger. Candidate validation is `valid: true`, `status: ready` at head `6f8028658f0bdd7f26e13c3fe4d45437880c341b`, with base/main `e3883b72fb1df5ad6356ef10dbde408f18bbc3be`.

## Task Commits

1. **Task 1: Put the adopter path and deterministic mobile signup in the actual release PR source** — `6f8028658f0bdd7f26e13c3fe4d45437880c341b` (`fix(247-06): restore 1.6 adoption path and sync mobile signup`).
2. **Task 2: Recheck the final head, exact-head CI, and source-bound candidate ledger** — evidence recorded in the Plan 06 review and readiness ledger; the candidate validator refreshed the ledger.

The shared planning checkout remains on another branch with unrelated edits, so this executor did not create a broad metadata commit there.

## Files Created/Modified

- `CHANGELOG.md`, `README.md`, `guides/introduction/upgrading-to-v1.6.md`, and `mix.exs` contain the 1.6.0 adopter path.
- `test/example/priv/playwright/tests/organizations.spec.ts` synchronizes both signup paths on rendered LiveView feedback.
- `247-05-CURRENT-SOURCE-REVIEW.json` and `247-RELEASE-READINESS.json` retain exact candidate source and CI identities; historical Phase 246 receipt and checkpoint fields remain intact.

## Decisions Made

- The historical tested source `90ec16f72a71d33224c0816ad77762e2e7262c76` remains distinct from squash-promoted main `590eb4ed3323db11dd74326cbee00c9c7973e529`; the current PR base/main is `e3883b72fb1df5ad6356ef10dbde408f18bbc3be`.
- Used `/private/tmp/sigra-phase247-plan06-candidate` as the authoritative clean candidate after the shared worktree could not safely refresh its read-only shared Git metadata.

## Deviations from Plan

### Execution adjustment

The existing candidate worktree could not fetch because its shared `.git` metadata was read-only. Work continued in a clean isolated clone of the exact live PR head. The live validator initially lacked the Phase 246 tested commit object in that clone; fetching the immutable commit SHA made all four historical source-blob checks resolvable. Inspection confirmed the template path exists at both tested source and promoted main with identical blob `812844b7678b5027382fed9ae5963d5a52fdf00c`. No validator or provenance rules were weakened or changed.

**Total deviations:** 1 execution adjustment; no product-scope deviation.

## Verification

- `git diff --check` passed for the source commit.
- `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` passed 21/21 tests.
- `node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage candidate --assert-live-refresh .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` returned `valid: true`, `status: ready`.
- Exact-head CI run `37717911489` attempt 1 concluded success. All 15 recorded required jobs passed; the documentation build and mobile organization-registration lane passed.
- The five source blobs at PR head `6f8028658f0bdd7f26e13c3fe4d45437880c341b` match the candidate clone.

## Remaining Readiness

Plan 06 is complete. READY-01 remains pending final authenticated release evidence; no Hex dry-run was dispatched. READY-02's final inventory/evidence capture remains with the later readiness plans. The PR remains open and has not been merged or published.

## Self-Check: PASSED

- Summary file exists at the required path.
- Source commit `6f8028658f0bdd7f26e13c3fe4d45437880c341b` is present at the isolated candidate HEAD.
- Candidate working tree is clean.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Plan: 06*
*Completed: 2026-10-08*
