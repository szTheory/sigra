---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 01
subsystem: testing
tags: [mix-ci, exunit, ci-topology, adr, evidence]
requires: []
provides:
  - "ADR 004 records TEST-01/TEST-02 supersession and the single-owner full-suite guarantee."
  - "The orphaned ExUnit timing formatter and its test are removed with a ten-ref consumer sweep."
  - "Reproducible source, compile, and alias-contract evidence for SC-1."
affects: [241-02, ci-topology, phase-233-library-economics-contract]
tech-stack:
  added: []
  patterns: ["Record branch-consumer impact before deleting orphaned CI support code", "Assert CI topology as a derived guarantee rather than a workflow snapshot"]
key-files:
  created:
    - .planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md
  modified:
    - test/support/ci/ex_unit_timing_formatter.ex
    - test/support/ci/ex_unit_timing_formatter_test.exs
key-decisions:
  - "TEST-01/TEST-02 are superseded by exactly one `mix ci` owner of the full library suite."
  - "Affected branch consumers remain visible in ADR 004 and require scoped migration if promoted."
actuals:
  tokens: 5165
  tasks: 3
  commits: 2
plan_head_before: 8fbeaa82d04a7f56ead7c3b9e0a3418da8ad7a25
requirements-completed: [DEBT-01]
coverage:
  - id: D1
    description: "ADR 004 records the supersession, replacement guarantee, and all ten affected refs."
    requirement: DEBT-01
    verification:
      - kind: other
        ref: "241-01-EVIDENCE.md: cross-reference consumer sweep"
        status: pass
    human_judgment: false
  - id: D2
    description: "The two orphaned timing formatter files are removed without changing the CI alias or its Phase 233 contract."
    requirement: DEBT-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix compile --warnings-as-errors; mix test test/sigra/planning/phase_233_library_economics_contract_test.exs"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-09-22
status: complete
---

# Phase 241 Plan 01: TEST-01/TEST-02 Supersession Summary

**ADR-backed retirement of an unowned ExUnit timing formatter, with all ten stale branch consumers recorded and the unchanged single-owner `mix ci` contract proven.**

## Performance

- **Duration:** 18min
- **Completed:** 2026-09-22
- **Tasks:** 3 completed
- **Files modified:** 4 (2 created, 2 deleted)

## Accomplishments

- Added ADR 004, which retires TEST-01/TEST-02 in favor of exactly one `mix ci` owner of the full library suite and lists every consumer-bearing local and remote ref.
- Deleted exactly the unused formatter module and its test; the post-delete project-source reference sweep is zero.
- Recorded reproducible sweep, compile, and contract-test evidence; the strict compile and focused Phase 233 suite pass 6/6 without modifying `mix.exs` or the contract test.

## Task Commits

1. **Task 1: End-to-end — sweep, record, delete, prove clean** — `7f77ad69` (docs)
2. **Task 2: Prove the alias and the compile are untouched** — verification-only; no source change or commit
3. **Task 3: Record the SC-1 evidence, including the honest green claim** — `65293787` (docs)

## Files Created/Modified

- `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md` — accepted supersession decision, replacement guarantee, and the ten-ref impact record.
- `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md` — commands, outputs, and CI-scoped full-suite claim.
- `test/support/ci/ex_unit_timing_formatter.ex` — deleted unowned timing formatter.
- `test/support/ci/ex_unit_timing_formatter_test.exs` — deleted orphaned formatter tests.

## Decisions Made

- TEST-01/TEST-02 are formally superseded: the meaningful guarantee is exactly one full-suite owner, not a formatter that no alias invokes.
- Stale consumers on ten refs are a visible migration boundary, not a reason to keep dead support code on the current branch.
- The SC-1 full-suite result remains a CI claim. Local environmental `ThreadlineTest` failures are named in evidence and are not hidden with test exclusions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Scoped source verification to the repository rather than nested sibling worktrees**

- **Found during:** Task 1
- **Issue:** The prescribed recursive grep descended into `.claude/worktrees/`, finding copies owned by sibling worktrees rather than source in this checkout. Its expected zero-match post-delete state also exits 1 under `pipefail` before the count assertion can run.
- **Fix:** Excluded `.claude/` from the source sweep and used `grep ... || true` only for the expected zero-match result; the numeric assertion remains fail-closed.
- **Files modified:** None (verification command and evidence only)
- **Verification:** The project-source sweep reports `source-reference-count=0`; strict compile and the focused contract suite pass.
- **Committed in:** `65293787` (evidence)

---

**Total deviations:** 1 auto-fixed (1 blocking verification-environment issue).
**Impact on plan:** No product or CI topology change; the adjustment prevents sibling worktree files from invalidating the intended source-tree proof.

## Issues Encountered

- Mix requires a local PubSub socket; the verification was rerun with the required local permission and passed.

## Next Phase Readiness

- Plan 241-02 can now assert ADR 004's replacement guarantee as a derived property.
- The evidence intentionally leaves the CI URL as `PENDING — filled at phase verification`; the full-suite claim is not represented as a local green run.

## Self-Check: PASSED

- ADR 004 and `241-01-EVIDENCE.md` exist at the recorded commits.
- Task commits `7f77ad69` and `65293787` are present in repository history.
- The two formatter files are absent; no project-source references remain.

---
*Phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard*
*Completed: 2026-09-22*
