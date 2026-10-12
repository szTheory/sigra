---
phase: 247-release-candidate-and-repository-readiness
plan: 04
subsystem: release-readiness
tags: [release, hex, ex_doc, github, inventory, validation]

requires:
  - phase: 247-01
    provides: reviewed source selection and isolated candidate checkout
  - phase: 247-02
    provides: refreshed Release Please PR #224
  - phase: 247-03
    provides: adopter guide and exact-head documentation CI evidence
provides:
  - final-stage validator for adopter docs, exact-head CI, Hex package inspection, PR state, and inherited checkout populations
  - refreshed final readiness ledger with explicit blocker for the unavailable Hex dry run
affects: [phase-247, phase-248, release-readiness]

actuals:
  tokens: 401153
  tasks: 1
  commits: 1
  plan_head_before: de68ef4b1df825659ede621d6b4bca955117270a
  plan_head_after: 0aba1874dad1098ebd80a32e98c834e3f5a248d0

tech-stack:
  added: []
  patterns: [exact-head readiness validation, explicit-empty inventory sets, fail-closed package evidence]

key-files:
  created: [.planning/phases/247-release-candidate-and-repository-readiness/247-04-SUMMARY.md]
  modified:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs

key-decisions:
  - "Keep READY-01/READY-02 blocked until the local Hex dry run can be proven without installing candidate dependencies."
patterns-established:
  - "The final validator records fresh live observations and rejects stale candidate, PR, package, and inventory identities."
requirements-completed: []
coverage:
  - id: D1
    description: Final-stage validation rejects stale source, incomplete inherited dispositions, broken adopter links, and missing package evidence.
    verification:
      - kind: unit
        ref: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs (21 passing tests)
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-10-07
status: halted
commits: 1
plan_head_before: de68ef4b1df825659ede621d6b4bca955117270a
plan_head_after: 0aba1874dad1098ebd80a32e98c834e3f5a248d0
---

# Phase 247 Plan 04: Final Candidate and Repository Readiness Summary

**A fail-closed final validator now checks the reviewed 1.6.0 candidate, adopter docs, exact-head CI, Hex package output, live PR population, and inherited checkout; readiness remains blocked by the local Hex dry run.**

## Performance

- **Duration:** 7 minutes
- **Started:** 2026-10-07T23:25:48Z
- **Completed:** 2026-10-07T23:33:12Z
- **Tasks:** 1 executed; completion gate remains blocked
- **Files modified:** 3 plan artifacts, plus this summary and GSD state metadata

## Accomplishments

- Added final-stage checks for the README → v1.6 upgrade guide → 1.6.0 changelog route, ExDoc extra/source reference, supported compatibility statements, migration claims, and source/CI citations for every candidate claim.
- Refreshed PR #224, protected main, open-PR population, and the inherited commit/path/status inventory. The PR is open at `563f411bc2659bb9ac1652d552ce58ffb0c876b1` against main `590eb4ed3323db11dd74326cbee00c9c7973e529`; the candidate worktree is clean. The final inherited inventory contains 14 open PRs, 387 commits, and 1,270 committed or dirty paths.
- Recorded passing exact-head CI run 37700772880 attempt 1, including the warning-free docs step, required CI lanes, and `ci-gate`. The unpacked Hex build succeeded and contains 1.6.0 metadata, README, and CHANGELOG. A local `mix docs --warnings-as-errors` now also passes using the candidate lockfile dependencies in an isolated `/private/tmp` build area.
- The focused validator suite passes all 21 tests, including regression coverage for legacy dirty planning paths without dispositions while unresolved source-path dispositions remain fail-closed.

## Task Commits

1. **Task 1: Prove the final candidate and repository-readiness contract** - `0aba1874d` (`feat`)

The validator follow-up classifies Phase 247 planning/evidence paths as preserved separate-follow-up work and repairs incomplete legacy planning rows on subsequent refreshes. The inherited source paths remain fail-closed when their disposition is missing.

## Files Created/Modified

- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` - Final evidence collection, source-linked claim validation, stable live-population checks, and final readiness diagnostics.
- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` - 21 deterministic validator tests.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` - Refreshed PR/inventory/package/docs evidence, including the current blocking diagnostic.

## Decisions Made

- READY-01 and READY-02 remain incomplete until `mix hex.publish --dry-run --yes` passes for the exact candidate. The clean candidate lacks its exact locked dependencies. No dependencies were installed, consistent with the plan's supply-chain constraint.

## Deviations from Plan

None. The final checks preserve missing package evidence as a blocker instead of promoting it to a pass.

## Issues Encountered

- `mix deps.get --check-locked` succeeded in `/private/tmp/sigra-phase247-hex-verify` with `MIX_DEPS_PATH`, `MIX_BUILD_PATH`, and `HEX_HOME` redirected there; the candidate lockfile and worktree remained unchanged. The 65 locked Hex packages resolved at their recorded versions.
- `mix hex.publish --dry-run --yes` built the Sigra 1.6.0 package summary, then exited 1 because the isolated Hex home has no authenticated user/API key. This is an authentication prerequisite in Hex's task even with `--dry-run`; [Hex 2.5.1's task source](https://github.com/hexpm/hex/blob/v2.5.1/lib/mix/tasks/hex.publish.ex#L1657-L1777) performs the public-package owner lookup before the dry-run skips upload. No publish endpoint was called, no user login was attempted, and the final validator preserves `final_hex_dry_run_failed`.
- Local `mix docs --warnings-as-errors` passed against the same exact locked dependencies. The dry-run remains unproven until an authenticated protected workflow supplies the read-only dry-run key planned for Phase 248.

## Next Phase Readiness

Phase 247 is not complete. READY-01/READY-02 are not marked complete, and the final readiness validator remains blocked on the authenticated Hex dry run. Phase 248 must not treat this plan as a passing readiness receipt until the remaining evidence is closed.

## Self-Check: PASSED

- Final readiness ledger and validator/test files exist.
- Task commit `0aba1874d` is an ancestor of HEAD.
- Candidate remains at `563f411bc2659bb9ac1652d552ce58ffb0c876b1` with an empty status.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-07*
