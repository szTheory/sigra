---
phase: 230-tier-1-critical-path-reclamation
plan: 07
subsystem: infra
tags: [github-actions, ci, timeout-minutes, actionlint, exunit]

# Dependency graph
requires:
  - phase: 230-tier-1-critical-path-reclamation (plan 06)
    provides: Playwright browser cache step + version-drift guard wired into example_playwright_smoke and fast_checks
provides:
  - Explicit timeout-minutes on all 22 ci.yml jobs, sized at ~2x live-measured duration (230-EVIDENCE.md) with a 5-minute floor
  - Corrected generated_admin_playwright_smoke timeout (60 -> 15) moved to the canonical post-runs-on slot
  - Sigra.Planning.Phase230CiTimeoutsTest — per-job completeness + pole-value contract preventing future timeout regressions
affects: [230-08, 230-09, 231-gate-01, 231-gate-02, 231-gate-04, 235-fast-01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Job-block string walk via zero-width regex lookahead split (no YAML parser dependency), matching the phase_153 contract-test idiom"

key-files:
  created: [test/sigra/planning/phase_230_ci_timeouts_test.exs]
  modified: [.github/workflows/ci.yml]

key-decisions:
  - "example_playwright_smoke set to 45 (not a tighter value close to its 28.5m measured duration) because its historical maximum is 41.7m — a tighter ceiling would time out the very runs Phase 230's before/after pair is judged on; tightening deferred to Phase 235 (D-20)"
  - "generated_admin_playwright_smoke's timeout corrected from 60 to 15 and moved to the canonical post-runs-on slot; only the timeout value/position changed — the adjacent stale ship/v1.42-ci-gate-remediation head-ref condition is untouched (GATE-02, Phase 231's scope)"
  - "Completeness contract counts timeout-minutes per job-block, not file-wide, so N declarations concentrated in one job cannot vacuously satisfy the assertion"

patterns-established:
  - "timeout-minutes lives immediately after runs-on: ubuntu-latest in every job header, at 4-space job-level indentation, so the contract test's fixed-indentation regex stays reliable across future job additions"

requirements-completed: [FAST-07]

coverage:
  - id: D1
    description: "All 22 jobs in ci.yml declare exactly one timeout-minutes, each sized to at least 2x its live-measured duration with a 5-minute floor"
    requirement: "FAST-07"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml"
        status: pass
      - kind: other
        ref: "python3 YAML-parse verify block from 230-07-PLAN.md Task 1 (asserts all 22 job/timeout pairs)"
        status: pass
    human_judgment: false
  - id: D2
    description: "generated_admin_playwright_smoke's mis-sized timeout (60, ~16x its 3.73m measured duration) corrected to 15 without disturbing the adjacent stale head-ref condition"
    requirement: "FAST-07"
    verification:
      - kind: other
        ref: "python3 verify block asserts generated_admin_playwright_smoke timeout-minutes==15 and 'ship/v1.42-ci-gate-remediation' still present in its if:"
        status: pass
    human_judgment: false
  - id: D3
    description: "Per-job completeness is enforced by a committed ExUnit contract that cannot pass vacuously (non-zero job-block floor, per-block counting, pinned pole values, sane-band bounds)"
    requirement: "FAST-07"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_230_ci_timeouts_test.exs (4 tests)"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/planning/ (54 tests total, 0 failures, 12 skipped — matches pre-change baseline of 50 plus this file's 4)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-07-29
status: complete
---

# Phase 230 Plan 07: CI Timeout Completeness Summary

**Every one of ci.yml's 22 jobs now declares an explicit `timeout-minutes` sized at ~2x its live-measured duration, and a per-job-block ExUnit contract makes that completeness property enforceable so a future job cannot land without one.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-29T00:18:00Z (approx.)
- **Completed:** 2026-07-29T00:42:37Z
- **Tasks:** 2/2
- **Files modified:** 2 (1 modified, 1 created)

## Accomplishments
- Added `timeout-minutes:` to 21 of ci.yml's 22 jobs (the 22nd, `changes`, already had the correct value of 5 from plan 05), sized against `230-EVIDENCE.md`'s BEFORE-PR/BEFORE-PUSH run data — `release_ref_guard` 5, `fast_checks` 10, `install_golden_contract` 15, `library_tests_shard` 20, `library_tests` 5, `library_tests_dep_off` 10, `example_unit_smoke` 10, `install_smoke` 10, `upgrade_smoke` 15, `passkeys_manual_fallback_smoke` 10, `install_matrix` 15, `passkeys_opt_out_smoke` 10, `example_http_smoke` 10, `example_playwright_smoke` 45, `generated_admin_playwright_smoke` 15, `ci-gate` 5, `notify_release_lane_rot` 10, `admin_design_recapture` 40, `admin_checkpoint_recapture` 20, `admin_eval_render` 40, `nightly_probe` 5.
- Corrected `generated_admin_playwright_smoke`'s pre-existing mis-sized `timeout-minutes: 60` (~16x its 3.73m measured duration) to 15 and moved it from between `if:` and the rest of the header into the canonical slot immediately after `runs-on:` — while leaving the adjacent stale `ship/v1.42-ci-gate-remediation` head-ref condition untouched (that correction is GATE-02, Phase 231's scope).
- Created `Sigra.Planning.Phase230CiTimeoutsTest` (`test/sigra/planning/phase_230_ci_timeouts_test.exs`), a `File.read!` plus per-job-block string walk (no YAML parser — matches the `phase_153` contract-test idiom) that enforces: a non-vacuous job-block count (≥20), exactly one `timeout-minutes` declaration per job block, the two pole values pinned (`example_playwright_smoke=45`, `generated_admin_playwright_smoke=15`), and every declared value inside a sane `[5, 60]` band.
- Manually proved (and restored, not committed) that the contract test fails with the offending job named when a `timeout-minutes` line is deleted, and fails naming the 41.7m historical maximum when `example_playwright_smoke` is set to 30.

## Task Commits

Each task was committed atomically:

1. **Task 1: Declare an explicit timeout on all 22 jobs** - `e0129a53` (feat)
2. **Task 2: Enforce timeout completeness with a per-job ExUnit contract** - `b404585d` (test)

**Plan metadata:** this SUMMARY commit

## Files Created/Modified
- `.github/workflows/ci.yml` - `timeout-minutes:` added to 21 jobs; `generated_admin_playwright_smoke`'s corrected and relocated
- `test/sigra/planning/phase_230_ci_timeouts_test.exs` - new per-job completeness + pole-value contract (4 tests)

## Decisions Made
- `example_playwright_smoke` was set to 45, not a tighter value nearer its 28.5m measured duration, because it has hit 41.7m historically (D-20, hard-fail boundary in the plan). A 30-minute ceiling would time out the pre-change baseline run and destroy the before/after pair Phase 230 is judged on. Tightening is explicitly deferred to Phase 235 once the post-reshape steady state is measured.
- `generated_admin_playwright_smoke`'s stale `head_ref == 'ship/v1.42-ci-gate-remediation'` condition on the line adjacent to its timeout was deliberately left untouched — fixing it is GATE-02's scope in Phase 231, not this plan's.
- The ExUnit contract counts `timeout-minutes:` occurrences per job block (not file-wide), so a future regression where 22 declarations concentrate in one job cannot vacuously satisfy the completeness assertion.

## Deviations from Plan

None — plan executed exactly as written. The `changes` job's `timeout-minutes: 5` was already present (added in plan 05) and required no edit, matching the plan's own note that it was "already present."

## Issues Encountered

None. Both `actionlint -shellcheck= .github/workflows/ci.yml` and the Task 1 Python YAML-parse verify block passed on the first attempt; the new ExUnit contract passed on the first run and both manual regression-injection checks (deleted timeout, mis-sized pole value) produced the expected named failures before being restored.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- FAST-07 (all 22 jobs bounded, no timeout tight enough to truncate a healthy run) is satisfied and enforced going forward by a committed contract test.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md`'s AFTER-PR / AFTER-PR-WARM / AFTER-NONPR / AFTER-PUSH slots still need capturing by plan 09 to confirm no job concludes with a timeout on the phase's own runs — this plan only sizes the ceilings, it does not itself capture those observed-run evidence slots.
- No blockers for plans 08/09 or Phase 231's GATE-02 (stale head-ref condition, left intentionally untouched here) and GATE-04 (`admin_eval_render`'s `continue-on-error`, also untouched).

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-29*
