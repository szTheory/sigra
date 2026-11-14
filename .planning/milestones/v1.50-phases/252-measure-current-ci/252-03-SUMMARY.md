---
phase: 252-measure-current-ci
plan: "03"
subsystem: ci-observability
tags: [elixir, exunit, timing, test-only]
requires:
  - phase: 252-01
    provides: Bounded CI collection and source-bound replay used by the later timing reports.
provides:
  - Opt-in ExUnit test and suite timing in explicit microseconds beside the standard CLI formatter.
  - Process checks proving write failures keep the original ExUnit result and cannot produce a complete timing measurement.
affects: [252-05, 252-06]
actuals:
  tokens: 6024
  tasks: 2
  commits: 3
commits: 3
plan_head_before: 9c59d8e615551a3fb68acf117843000a622b16ed
plan_head_after: 5adf5d2e6ef550673d87f4b6b2b1c3f5462c4e8b
tech-stack:
  added: []
  patterns:
    - Enable the test-only formatter only for a nonempty timing path; keep ordinary ExUnit output and scheduling.
    - Publish complete reports by writing a same-directory temporary file and renaming it after suite finish.
key-files:
  created:
    - test/support/ci_timing_formatter.ex
    - test/sigra/planning/ci_timing_formatter_test.exs
    - scripts/ci/ci-exunit-timing.test.sh
    - .planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json
  modified:
    - test/test_helper.exs
key-decisions:
  - "The report contains only module/name, result, duration and suite counts; missing timing or failed output stays explicitly incomplete."
  - "Instrumentation overhead is the median of five paired whole-process timing differences, with every sample retained and no target adjustment."
requirements-completed: []
coverage:
  - id: D1
    description: "Opt-in ExUnit reports distinct completed test identities, literal results, microsecond durations, suite totals and skip/exclusion counts."
    requirement: CIMEAS-02
    verification:
      - kind: unit
        ref: "test/sigra/planning/ci_timing_formatter_test.exs#writes distinct completed test results only after the suite finishes"
        status: pass
      - kind: integration
        ref: "PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Unavailable timing output emits an incomplete diagnostic, preserves the original failed-test exit, and is excluded from overhead measurements."
    requirement: CIMEAS-02
    verification:
      - kind: integration
        ref: "bash scripts/ci/ci-exunit-timing.test.sh --output .planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json"
        status: pass
      - kind: other
        ref: ".planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json#instrumentation_overhead_us"
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-10-12
status: complete
---

# Phase 252 Plan 03: Opt-in ExUnit timing Summary

**The library test process now emits optional per-test microsecond timings and suite totals while preserving normal CLI output, test scheduling and original failure exits.**

## Performance

- **Duration:** 12 minutes
- **Started:** 2026-10-12T18:18:10Z
- **Completed:** 2026-10-12T18:30:31Z
- **Tasks:** 2
- **Files modified:** 5, including the committed timing evidence

## Accomplishments

- Added Sigra.Test.CITimingFormatter to the existing test support path. SIGRA_EXUNIT_TIMING_JSON enables it beside ExUnit.CLIFormatter; when unset, the helper keeps the existing formatter setup.
- Recorded each completed test's module/name, passed/failed/skipped result and duration_us. The report separates test-duration sum from suite elapsed and ExUnit run/async/load times, and retains skipped/excluded counts.
- Made report publication atomic and complete-only-after-suite-finish. Missing durations, interrupted runs, stale output and file-write errors remain visible as incomplete data; errors are emitted as a structured JSON diagnostic on stderr.
- Added real ExUnit process checks for a passing test, a deliberate failure, opt-out behavior and unavailable output. The failing process returned exit 2 with and without report output.
- Ran five focused-suite samples with timing enabled and five without. The saved paired samples report an instrumentation_overhead_us median of -60,547 microseconds; the spread is noisy and the raw measurements remain in the evidence file without changing the comparison target.

## Task Commits

1. **Task 1: Emit complete opt-in ExUnit event timing beside the standard formatter** — a6771b9fe (test), b2b022691 (feat)
2. **Task 2: Preserve failing test exit and expose partial timing-output diagnostics** — 5adf5d2e6 (fix)

## Files Created/Modified

- test/support/ci_timing_formatter.ex — test-only ExUnit event formatter with atomic report output and explicit incomplete diagnostics.
- test/test_helper.exs — opt-in formatter setup while retaining the default formatter configuration.
- test/sigra/planning/ci_timing_formatter_test.exs — deterministic event and schema contracts.
- scripts/ci/ci-exunit-timing.test.sh — actual ExUnit process checks and five paired overhead samples.
- .planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json — raw sample arrays, measured overhead and process exit evidence.

## Decisions Made

- Keep the timing feature opt-in and test-only; the existing mix ci owner, test selection, default max_cases, timeout behavior and Sandbox setup remain in place.
- Keep a missing or unwritable report out of any timing measurement. A report-write diagnostic cannot replace or erase the test process exit status.
- Preserve the measured overhead as observed, including a negative median caused by local timing variation; do not adjust the later comparison target.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Avoid cross-process collisions in temporary contract report paths**
- **Found during:** Task 1
- **Issue:** A per-VM unique integer repeated across separate ExUnit processes, so a stale temporary report could make the pre-suite assertion fail.
- **Fix:** Added a nanosecond timestamp to the path and remove the generated report on test exit.
- **Files modified:** test/sigra/planning/ci_timing_formatter_test.exs
- **Verification:** The focused contract and an opt-in real ExUnit process both passed.
- **Committed in:** b2b022691

**2. [Rule 2 - Missing critical] Remove stale report output before an opt-in run**
- **Found during:** Task 2
- **Issue:** If a previous complete report remained at the configured path, a later failed write could leave stale data looking current.
- **Fix:** Clear the exact configured output path when the formatter starts; if it cannot be cleared, mark the report incomplete and emit a diagnostic.
- **Files modified:** test/support/ci_timing_formatter.ex, scripts/ci/ci-exunit-timing.test.sh
- **Verification:** The shell contract starts with a stale complete file and verifies the new run replaces it with the current report.
- **Committed in:** 5adf5d2e6

**3. [Rule 1 - Bug] Encode filesystem write reasons as JSON strings**
- **Found during:** Task 2
- **Issue:** Erlang's file error formatter returns a charlist, which JSON encoded as an integer array instead of a readable reason.
- **Fix:** Convert the reason to a string before emitting the structured incomplete-output diagnostic.
- **Files modified:** test/support/ci_timing_formatter.ex, scripts/ci/ci-exunit-timing.test.sh
- **Verification:** The shell contract parses the stderr JSON and requires complete=false, diagnostic=write_failed and a string reason.
- **Committed in:** 5adf5d2e6

**Total deviations:** 3 auto-fixed (2 Rule 1, 1 Rule 2). **Impact:** These fixes keep test paths isolated and prevent stale or malformed output from being treated as a current measurement.

## Verification

- PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs — 2 tests passed.
- bash scripts/ci/ci-exunit-timing.test.sh --output .planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json — passed; all ten focused-suite runs passed, the failure process returned the same exit with and without report output, and the evidence JSON passed its schema assertions.
- MIX_ENV=test mix format --check-formatted for the three changed Elixir files and bash -n scripts/ci/ci-exunit-timing.test.sh — passed.
- The focused test command's local PostgreSQL prerequisite was available at localhost:5432; no environment setup or dependency installation was needed.

## Planning Write-Ahead Preservation

| Prior revision | Durable ref | Path/status | Exact SHA-256 read-back |
|---|---|---|---|
| Initial timing sample before refresh | refs/gsd-preservation/phase252/252-03-initial-exunit-timing | .planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json; untracked | 153f105dc82554e3e4134a8e0dbd0e73bf557ea8d0f21c416e1ee377e5323007 |
| Timing sample before structured write diagnostic update | refs/gsd-preservation/phase252/252-03-timing-evidence-before-diagnostics | .planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json; untracked | 865fb7461d6afe7f736e039a576cecb47c7dd0509a18e0b02aa4c774b7612b3f |
| State before SDK transition | refs/gsd-preservation/phase252/252-03-prestate-STATE-md | .planning/STATE.md; clean, 6,811 bytes | 9f4cc33dd31e524557fa54540a47fc9558f34ec56559ecdf4c7c5be696b2083f |
| state.json before SDK transition | refs/gsd-preservation/phase252/252-03-prestate-state-json | .planning/state.json; clean, 810 bytes | 8790003d46f6604a86c10a444f4a3077241d85907cda35cf503b06ab3d03b637 |
| Roadmap before SDK transition | refs/gsd-preservation/phase252/252-03-prestate-ROADMAP-md | .planning/ROADMAP.md; clean, 10,658 bytes | 975d6f0f7b833ab82efb7ff9ef3f6549274e2e0e5f7e1dd902e37581e6728136 |
| Handoff before SDK transition | refs/gsd-preservation/phase252/252-03-prestate-HANDOFF-json | .planning/HANDOFF.json; clean, 22,428 bytes | e4bd2152b2714f151a4665b1a9f60672cce111752a9fee0c5a6e8445e423af49 |

## Issues Encountered

- The SDK's plan-scope check found all three plan commits. No GitHub access, remote changes, package installs or full mix ci run were needed for this plan.
- Phase requirements remain pending until Phase 252 verification; this plan does not mark CIMEAS-02 complete at the phase level.

## User Setup Required

None.

## Next Phase Readiness

Plan 252-03 and its automated checks are complete. Plans 252-04 through 252-06 and phase-level verification remain; continue with $gsd-execute-phase 252. The nine phase requirements remain pending.

## Self-Check: PASSED

- All five planned source/script files and the committed timing evidence exist.
- Task commits a6771b9fe, b2b022691 and 5adf5d2e6 are ancestors of the current branch.
- The plan-scope check returned all three commits, and the focused ExUnit contract and process harness passed.

---
*Phase: 252-measure-current-ci*
*Completed: 2026-10-12*
