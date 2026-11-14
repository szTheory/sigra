---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "49"
subsystem: ci-reliability
tags: [ci-reliability, canary, test-hygiene, mktemp]
requires: []
provides:
  - collision-free canary temp files under one private mktemp -d directory
  - repeatable recovery refusal and watch contracts (5 tests green)
affects: [253-53, 253-54]
actuals:
  tokens: 9000
  tasks: 2
  commits: 2
plan_head_before: 7dbea652c00fc82aab27f732ee9758aaef88a2bd
plan_head_after: 42e917f3f4025537ad50a9a291fe400a022585f9
key-files:
  modified:
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-gate-canary-recovery.test.py
key-decisions:
  - "Freeze-required refusal preceding halted-evidence refusal is deliberate (253-11), so the test was aligned, not the script."
  - "watch_run was rewritten from gh run watch to API polling in 253-11; the old gh-failure test was obsolete and replaced."
requirements-completed: ["CIREL-02"]
duration: 25min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 49: Canary recovery test hygiene Summary

**ci-gate-canary.sh now keeps every temp file in one private `mktemp -d` directory with trailing-X-only templates, and ci-gate-canary-recovery.test.py is green 5/5 and repeatable on macOS.**

## Accomplishments

- Root cause reproduced: BSD mktemp substitutes only trailing X characters, so `/tmp/253-canary-watch-rate.XXXXXX.json` creates a literal name and fails with `File exists` on the next run. RED was confirmed by running the new tests against the pre-change script from HEAD (both watch tests failed with `mkstemp failed ... File exists`).
- All 22 mktemp calls (including the `-t` forms, which are not portable to GNU mktemp) now use `"$WORK_DIR/<name>.XXXXXX"`. `WORK_DIR` is one `mktemp -d "${TMPDIR:-/tmp}/253-canary.XXXXXX"` (mode 700) removed by an `EXIT` trap. The poll lock directory honors `TMPDIR`. Request and receipt formats are unchanged. No predictable literal path remains for temp files (T-253-97).
- Watch tests run in a hermetic `TMPDIR` with stale literal-name files seeded; one case covers terminal-run capture and one the already-owned-poller refusal, both asserting errexit is preserved.
- Halted-evidence contract split into two cases that each assert the exact refusal text and a zero-invocation recorder (fake `gh` and `curl` on PATH).

## History evidence (Task 2)

- `b0bed87cf` (253-07) introduced the `halted evidence requires a separately authorized new freeze` refusal.
- `307dd9591` (253-11) introduced `hosted execution requires the separately reviewed recovery freeze` and placed it earlier, ahead of the halted-evidence check. This is deliberate (the freeze is validated locally before any hosted path), not a regression, so the script's order is kept.
- Test change: new `test_missing_recovery_freeze_refuses_before_any_github_command` asserts the freeze-required message; `test_halted_evidence_with_reviewed_freeze_stops_before_any_github_command` supplies a valid freeze in a synthetic git repo (mirroring ci-gate-canary.test.sh) so the script reaches and asserts the halted-evidence message. The real freeze cannot be used: it is consumed and its source hashes no longer match.

## Task Commits

1. Task 1: private temp directory and hermetic watch tests - `d84285ab9` (fix)
2. Task 2: separate freeze-required and halted-evidence refusal cases - `42e917f3f` (test)

## Deviations from Plan

**1. [Rule 1 - Bug] Obsolete watch test replaced**
- **Found during:** Task 1
- **Issue:** After the collision fix the watch test still failed: it stubbed `gh` and expected `watch_run` to return 1, but 253-11 replaced `gh run watch` with API polling (no `gh`, needs `fail`, `MAX_MINUTES`, `POLL_INTERVAL`).
- **Fix:** Rewrote the test against the current `watch_run` contract (pre-owned poll lock gives status 1, errexit preserved) and added a terminal-run capture test.
- **Files modified:** scripts/ci/ci-gate-canary-recovery.test.py
- **Commit:** d84285ab9

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** test-only, no scope creep.

## Issues Encountered

- First test run hung because a `fail` stub that returned instead of exiting let the poll loop run forever; fixed by making the stub exit and running `watch_run` in a subshell. A leftover `/tmp/253-canary-poll-901.lock` created by that run was removed.
- The 253-RECOVERY-CANARY-FREEZE.json records source hashes for scripts/ci/ci-gate-canary.sh; this plan's edit changes that hash. The freeze is consumed/historical and unchanged here (not edited). Any future reuse needs a new freeze, which the halted-evidence refusal already requires.
- Pre-existing `/tmp/253-canary-api-error.*` files from older script versions were left alone (not created by this plan).

## Known Stubs

None.

## Remaining gaps

Full Phase 253 verification stays not_started. STATE/ROADMAP are owned by the orchestrator.

## Self-Check: PASSED

Both modified files exist; commits d84285ab9 and 42e917f3f are on HEAD; `python3 scripts/ci/ci-gate-canary-recovery.test.py` passed twice (5/5) and `bash scripts/ci/ci-gate-canary.test.sh` passed; no leftover `/tmp/253-canary.*` directories.
