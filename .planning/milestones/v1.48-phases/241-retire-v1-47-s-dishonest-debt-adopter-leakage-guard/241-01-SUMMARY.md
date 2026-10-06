---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 01
subsystem: testing
tags: [mix-ci, exunit, adr, ci-topology, debt-retirement]
requires: []
provides:
  - "ADR 004 records TEST-01/TEST-02 supersession and every affected historical ref."
  - "The uninvoked ExUnit timing formatter and its test are removed with a zero-reference source proof."
  - "Reproducible sweep, strict compile, and Phase 233 alias-contract evidence."
affects: [241-02, CI topology, historical cherry-picks]
tech-stack:
  added: []
  patterns: ["Record cross-ref compatibility loss in an ADR before deleting dormant CI support code.", "Use a zero-match-safe grep guard under pipefail when proving a source sweep is empty."]
key-files:
  created:
    - .planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md
  modified:
    - test/support/ci/ex_unit_timing_formatter.ex (deleted)
    - test/support/ci/ex_unit_timing_formatter_test.exs (deleted)
key-decisions:
  - "TEST-01/TEST-02 are superseded by exactly one owner of the full library suite in the mix ci topology."
  - "All ten historical refs with live timing-path consumers are recorded before deletion so future cherry-picks fail transparently rather than silently."
requirements-completed: [DEBT-01]
actuals:
  tokens: 5356
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 5b42f1df6df1ec13ff4702a194700e30d2d0ba40
duration: 3min
completed: 2026-09-19
status: complete
coverage:
  - id: D1
    description: "ADR-backed deletion of the dormant ExUnit timing formatter and its test, with the all-ref consumer consequence recorded."
    requirement: DEBT-01
    verification:
      - kind: other
        ref: "bash -c post-delete source sweep and exact-deletion assertion"
        status: pass
      - kind: unit
        ref: "MIX_ENV=test mix compile --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D2
    description: "The mix ci alias and Phase 233 topology contract remain unchanged and passing."
    requirement: DEBT-01
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_233_library_economics_contract_test.exs"
        status: pass
      - kind: other
        ref: "git diff protected-file assertion from plan ledger base"
        status: pass
    human_judgment: false
  - id: D3
    description: "Plan-scoped evidence preserves commands, output, and the CI-only full-suite claim."
    requirement: DEBT-01
    verification:
      - kind: other
        ref: ".planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md"
        status: pass
    human_judgment: false
---

# Phase 241 Plan 01: TEST-01/TEST-02 Supersession Summary

**ADR-backed retirement of an uninvoked ExUnit timing formatter, with ten affected historical refs recorded and the unchanged `mix ci` topology proven by strict compilation and its existing contract test.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-09-19T15:02:32Z
- **Completed:** 2026-09-19T15:05:45Z
- **Tasks:** 3/3
- **Files modified:** 4 (2 created, 2 deleted)
- **Verification:** plan-wide deterministic checks passed at `e035a42e`

## Accomplishments

- Added ADR 004 in the existing decision convention, describing why TEST-01/TEST-02 are superseded and that Plan 241-02 must assert the derived single-owner guarantee.
- Captured all ten refs with live non-support `SIGRA_EXUNIT_TIMING_PATH` consumers, including both local and origin copies of `gsd/phase-232-playwright-economics`.
- Deleted exactly the dormant formatter and its formatter test; the filtered source-tree sweep now reports zero references.
- Proved the protected `mix.exs` alias and Phase 233 contract-test file are untouched, compiled test code with warnings-as-errors, and passed all six Phase 233 contract tests.
- Added plan-scoped reproducible evidence, including the explicitly CI-only full-suite claim and the six named environmental Threadline failures without excluding them.

## Task Commits

1. **Task 1: End-to-end — sweep, record, delete, prove clean** — `970c1a92` (refactor)
2. **Task 2: Prove the alias and the compile are untouched** — `ff5dda03` (test; verification-only empty commit)
3. **Task 3: Record the SC-1 evidence, including the honest green claim** — `e035a42e` (docs)

## Files Created/Modified

- `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md` — accepted supersession decision, replacement guarantee, and all-ref consumer ledger.
- `test/support/ci/ex_unit_timing_formatter.ex` — deleted dormant timing formatter.
- `test/support/ci/ex_unit_timing_formatter_test.exs` — deleted formatter-only test.
- `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md` — reproducible pre/post sweep, compile, contract-test, and CI-claim evidence.

## Decisions Made

- The formatter is deleted because no active alias leg invokes it; the existing `mix ci` topology remains the sole full-library-suite owner.
- Affected historical refs are recorded before removal because their obsolete consumers turn future cherry-picks into otherwise-unrelated compile failures.
- The CI outcome remains pending phase verification: no local `mix ci` success is represented as a full-suite green claim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking verification] Made the required zero-reference assertion safe under `pipefail`.**
- **Found during:** Task 1
- **Issue:** The supplied `set -o pipefail` command assigned a pipeline whose `grep` correctly returned status 1 when no source references remained, so the shell exited before `wc` could assert the required zero count.
- **Fix:** Guarded only the expected zero-match `grep` status with `|| true` before counting; a nonzero count still fails the explicit `test "$n" = "0"` assertion.
- **Files modified:** None (verification command and evidence only)
- **Verification:** Post-delete filtered source sweep reported `SOURCE_MATCHING_FILES=0` and the plan-wide check passed.
- **Committed in:** `e035a42e` (Task 3 evidence)

**Total deviations:** 1 auto-fixed (Rule 3 verification command).
**Impact on plan:** No implementation scope changed; the correction preserves the planned zero-reference proof instead of allowing an expected grep exit code to abort it.

## Issues Encountered

- `git rm` stages deletions immediately, so the task-commit staging command did not re-add the now-absent paths. The staged deletions were retained and committed atomically with ADR 004; no files beyond the planned two were deleted.
- `roadmap.update-plan-progress 241` found no writable Phase 241 progress row or phase-detail section, so it left `ROADMAP.md` unchanged. The phase remains correctly in progress; plan position and requirement completion were recorded in `STATE.md` and `REQUIREMENTS.md`.

## Known Stubs

None. The evidence file's CI URL is intentionally marked pending phase verification because this plan is not authorized to push or dispatch CI; it is not a runtime or product stub.

## Next Phase Readiness

- Plan 241-02 can implement its replacement guarantee from ADR 004 rather than infer it backward from current workflow text.
- Phase verification must fill the evidence file's CI URL after its final committed HEAD reaches CI and retain the named Threadline environmental-failure context.

## Self-Check

PASSED — ADR, evidence, and summary files exist; task commits `970c1a92`, `ff5dda03`, and
`e035a42e` resolve as commit objects; the persisted plan ledger measures three task commits.
