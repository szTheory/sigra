---
phase: quick
plan: 260915-vcq
subsystem: testing
tags: [ci, planning-paths, contract-tests, milestone-archive, elixir]

requires:
  - phase: 235-terminal-ratification-measured-not-read
    provides: FAST-01/GATE-05 closed-milestone evidence (v1.47-REQUIREMENTS.md archive)
provides:
  - Sigra.Test.PlanningPaths.requirements_for/1 milestone-scoped resolver
  - Repointed phase-235 contract tests against the immutable v1.47 archive
affects: [future phase contract tests, mix ci gate, todo triage]

actuals:
  tokens: 6800
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Milestone-scoped resolver sibling function (requirements_for/1) alongside an
       ambient live-file resolver (requirements/0), rather than redefining the
       ambient resolver's fallback semantics."

key-files:
  created: []
  modified:
    - test/support/planning_paths.ex
    - test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
    - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
    - .planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md (renamed to .planning/todos/resolved/)

key-decisions:
  - "Took todo option 2 (repoint at archive) over option 1 (retire) — retiring would discard the immutability contract these tests exist to enforce."
  - "requirements/0 behaviour is unchanged; requirements_for/1 is a pure addition, so any future test that legitimately wants the live file is unaffected."

requirements-completed: []

coverage:
  - id: D1
    description: "Sigra.Test.PlanningPaths gains requirements_for/1, a milestone-scoped resolver returning .planning/milestones/<name>-REQUIREMENTS.md"
    verification:
      - kind: unit
        ref: "bash -c 'grep -c \"def requirements_for\" test/support/planning_paths.ex' == 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both phase-235 contract test files (24 tests total, 16 + 8) pass against the v1.47 archive with zero assertions changed"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs + test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs — 24 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "MIX_ENV=test mix ci no longer fails on the 3 originally-named phase-235 failures; todo moved pending -> resolved with root cause + chosen option recorded"
    verification:
      - kind: integration
        ref: "grep -c phase_235|Phase235 /tmp/mix_ci_out.log && /tmp/mix_ci_out2.log — 0 matches in both full runs"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-09-16
status: complete
---

# Quick Task 260915-vcq: Fix stale phase-235 FAST-01/GATE-05 contract tests Summary

**Added a milestone-scoped `requirements_for/1` resolver to `Sigra.Test.PlanningPaths` and repointed both phase-235 contract test files at the immutable v1.47 archive, fixing the root cause instead of the symptom.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-09-16T02:35:00Z
- **Completed:** 2026-09-16T03:10:00Z
- **Tasks:** 3
- **Files modified:** 4 (1 renamed)

## Accomplishments
- `Sigra.Test.PlanningPaths.requirements_for/1` added — resolves a NAMED, CLOSED milestone's archived REQUIREMENTS.md snapshot (`.planning/milestones/<name>-REQUIREMENTS.md`), with `requirements/0`'s live-file-fallback behaviour left byte-unchanged.
- Both `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` and `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` now assert against `requirements_for("v1.47")` instead of the ambient `requirements/0` — 24 tests (16 + 8), 0 failures, same count as before the change (no assertion added, removed, or weakened).
- Confirmed via two full `MIX_ENV=test mix ci` runs that none of the 3 originally-named phase-235 failures occur anymore.
- Resolved `.planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md` via `git mv` to `.planning/todos/resolved/`, recording the chosen option (2) and the true root cause (the `requirements/0` fallback condition, not the tests).

## Task Commits

1. **Task 1: Add a milestone-scoped requirements resolver to PlanningPaths** - `68057aee` (feat)
2. **Task 2: Repoint the two phase-235 contract tests at the v1.47 snapshot** - `e549c6f1` (fix)
3. **Task 3: Prove `mix ci` is unblocked and resolve the todo** - `80623f11` (docs)

_No separate plan-metadata commit — quick tasks fold metadata into the todo-resolution commit; STATE.md is updated in a following commit._

## Files Created/Modified
- `test/support/planning_paths.ex` - Added `requirements_for/1` + moduledoc explaining why two resolvers exist
- `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` - `@requirements` now uses `requirements_for("v1.47")`
- `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` - `@requirements` now uses `requirements_for("v1.47")`
- `.planning/todos/resolved/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md` - moved from `pending/`, resolution note appended

## Decisions Made
- Option 2 (repoint at archive) chosen over option 1 (retire) and option 3 (defer) — repointing preserves the "these tests remain immutable evidence of a closed milestone" contract; retiring would have discarded it, and deferring leaves `mix ci` red on `main` indefinitely for no reason once the actual root cause is this cheap to fix.
- `requirements_for/1` is a sibling function, not a redefinition of `requirements/0` — protects any future caller that legitimately wants the live file's current fallback-to-newest-archived-if-missing behavior.

## Deviations from Plan

None - plan executed exactly as written. Both prohibited actions (deleting/weakening assertions, editing the archived/live REQUIREMENTS.md files, changing `requirements/0` semantics, branch changes) were avoided.

## Issues Encountered

**Unrelated `sigra-dep-off` lane failure, reported and NOT fixed (out of scope per plan Task 3 and standing constraint 4):** Both full `MIX_ENV=test mix ci` runs show 6 pre-existing failures in `Sigra.Audit.Forwarders.ThreadlineTest` — `UndefinedFunctionError: Sigra.Audit.Forwarders.Threadline.attach/1 is undefined`. Confirmed unrelated to this task's diff (`git status`/`git diff` show zero touches to `mix.exs`, `mix.lock`, or any threadline forwarder file from this task). This matches a known stale-optional-dep compile artifact noted earlier in this session; applying the documented remediation (`mix deps.compile threadline --force && mix compile --force`, followed by `mix deps.get` to resolve a resulting lock mismatch) left the working tree clean but the failure recurred identically on the next full `mix ci` invocation — indicating the flake is reintroduced by `mix ci`'s own dependency-resolution step (`sigra-dep-off` lane), not by anything fixable in this task's scope. Left as an out-of-scope, plainly-reported finding per the plan's explicit instruction not to fix unrelated `mix ci` failures. No new todo filed per plan scope (not requested), but noted here for future discovery.

The `mix.lock` diff produced transiently by `sigra-dep-off.sh`/Hex re-resolution during the first `mix ci` attempt was reverted with `git checkout -- mix.lock` before proceeding — it was a byproduct of the pre-existing dep-off lane issue, not an intended change.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `mix ci`'s phase-235 contract-test failures are fully closed; the todo is resolved with root cause on record.
- Outstanding, unrelated: the `sigra-dep-off` lane's `Sigra.Audit.Forwarders.ThreadlineTest` failures (6) remain red on `main` and are not tracked by an existing todo as of this task — a future phase or quick task should file one if not already covered.

---
*Phase: quick*
*Completed: 2026-09-16*
