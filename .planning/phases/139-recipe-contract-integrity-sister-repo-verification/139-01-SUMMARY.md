---
phase: 139-recipe-contract-integrity-sister-repo-verification
plan: 01
subsystem: testing
tags: [exunit, recipes, contract-testing, documentation]

# Dependency graph
requires: []
provides:
  - "RCT-01: companion-lib recipe contract fixture at test/sigra/recipes/companion_lib_contract_test.exs"
  - "D-05 non-empty glob guard as standalone test"
  - "Five-marker sweep over all six companion-lib recipes"
affects:
  - 139-02 (recipe edits must satisfy the RCT-01 contract)
  - future companion-lib recipe additions

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Contract fixture pattern: async: true ExUnit with root()/Path.wildcard glob + flat for-loop marker assertions"
    - "D-05 guard: standalone test that fails independently from marker sweep — disambiguates empty glob from missing marker"

key-files:
  created:
    - test/sigra/recipes/companion_lib_contract_test.exs
  modified: []

key-decisions:
  - "Path arithmetic fix: test/sigra/recipes/ is 3 levels deep from repo root, requiring Path.expand('../../..', __DIR__) — plan and PATTERNS.md both stated two dots, which is incorrect; fixed inline per Rule 1"

patterns-established:
  - "Contract test placement: test/sigra/recipes/ for recipe-contract fixtures (parallel to test/sigra/planning/ for planning-contract fixtures)"

requirements-completed:
  - RCT-01

# Metrics
duration: 8min
completed: 2026-05-29
---

# Phase 139 Plan 01: Companion-Lib Recipe Contract Fixture Summary

**Pure-ExUnit merge-blocking fixture (RCT-01) asserting all six companion-lib recipes carry five required contract markers, with a standalone D-05 non-empty glob guard**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-29T16:54:35Z
- **Completed:** 2026-05-29T17:02:00Z
- **Tasks:** 1
- **Files modified:** 1 (created)

## Accomplishments

- Created `test/sigra/recipes/companion_lib_contract_test.exs` — RCT-01 contract fixture
- D-05 guard: standalone test `"companion-libs glob is non-empty (D-05 guard)"` fails independently when the glob path is wrong or the directory is empty
- Five-marker sweep: single test block iterating all six recipes × five required markers (30 assertions total) — each failure names the recipe file and missing marker
- Negative-test verification completed: removing `## Failure modes` from accrue.md produced `accrue.md: missing ## Failure modes section ("## Failure modes")`; recipe reverted; fixture green again
- Full suite passes (pre-existing install/upgrade failures unrelated to this plan)

## Task Commits

1. **Task 1: Create companion-lib recipe contract fixture (RCT-01)** - `c0a02c9` (feat)

## Files Created/Modified

- `test/sigra/recipes/companion_lib_contract_test.exs` — RCT-01 fixture; `use ExUnit.Case, async: true`; two tests (D-05 glob guard + five-marker sweep over guides/recipes/companion-libs/*.md)

## Decisions Made

- Path arithmetic fix applied inline (Rule 1): `Path.expand("../../..", __DIR__)` — three dots, not two. The plan and PATTERNS.md both said "two dots" but the file is at `test/sigra/recipes/` which is 3 directory levels below repo root. The `phase_50_nyquist_docs_contract_test.exs` analog at `test/sigra/planning/` is identically 3 levels deep and uses `"../../.."` — the plan note was wrong.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed path arithmetic: two dots → three dots in root() helper**
- **Found during:** Task 1 (first test run — both tests failed with "matched no files")
- **Issue:** Plan specified `Path.expand("../..", __DIR__)` but `test/sigra/recipes/` is 3 levels deep from repo root (test/sigra/recipes → test/sigra → test → repo root), requiring `"../../.."`. The plan and PATTERNS.md both incorrectly stated "two dots, not three" while noting the phase-50 analog (also 3 levels deep) uses three dots.
- **Fix:** Changed `Path.expand("../..", __DIR__)` to `Path.expand("../../..", __DIR__)` in the fixture
- **Files modified:** `test/sigra/recipes/companion_lib_contract_test.exs`
- **Verification:** `mix test test/sigra/recipes/companion_lib_contract_test.exs` exits 0 after fix
- **Committed in:** c0a02c9 (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in plan's path arithmetic)
**Impact on plan:** Necessary correctness fix. No scope change.

## Negative-Test Evidence (Success Criteria #2)

**Procedure:** Temporarily replaced `## Failure modes` in `guides/recipes/companion-libs/accrue.md` with `## TEMPORARILY_REMOVED_FOR_TEST`.

**Observed failure output:**
```
  1) test each companion-lib recipe carries all five required contract markers (Sigra.Recipes.CompanionLibContractTest)
     accrue.md: missing ## Failure modes section ("## Failure modes")
```

The failure message correctly names the recipe file (`accrue.md`) and the missing marker label + string. The D-05 guard test passed (glob was not empty). After reverting, the fixture returned to 2 tests, 0 failures.

## Issues Encountered

None beyond the path arithmetic deviation above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- RCT-01 fixture is live and merge-blocking (no CI tag exclusions per CLAUDE.md)
- Plan 02 (RCV-01/RCV-02: lockspire.md + rulestead.md recipe fixes) can run next; RCT-01 will re-assert structural integrity over the edited recipes

---
*Phase: 139-recipe-contract-integrity-sister-repo-verification*
*Completed: 2026-05-29*
