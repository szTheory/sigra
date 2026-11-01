---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "40"
subsystem: testing
tags: [ci-reliability, load-recovery, native-halt, playwright]
requires:
  - phase: 253
    provides: 253-39 four-slot runner, frozen windows and ready ledger
provides:
  - preserved honest halt of the first native load-recovery window (CR-DESKTOP-MOBILE-FIRST)
affects: [253-41]
actuals:
  tokens: 6000
  tasks: 1
  commits: 1
plan_head_before: b4cf2a5db
plan_head_after: 1e1250641
requirements-completed: []
coverage:
  - id: D1
    description: "Three-project first-control command and original dark case produce 16 accepted native rows"
    requirement: CIREL-01
    verification:
      - kind: integration
        ref: "node scripts/ci/ci-registration-recovery.mjs --verify-load-recovery <evidence> --stage first (rejected: 0/16 rows, first command not accepted)"
        status: fail
    human_judgment: true
    rationale: "Window halted; the frozen allocation for this slot is spent and cannot be retried."
duration: 40min
completed: 2026-10-14
status: halted
---

# Phase 253 Plan 40: Native load-recovery controls Summary

**The first frozen 120000 ms window ran one real Playwright CLI for about 29 minutes without its deadline firing, reported 0 of 16 rows, and is preserved as a halted, non-retryable ledger; Task 1 failed and Task 2 was never started.**

## execution_performed

- Preconditions met: freeze checker exit 0, 73/73 offline tests under Node 20.18.1, psql reached test Postgres on 58624.
- Preparation probes ran (655 ms charged; mix --version, mix deps).
- Slot CR-DESKTOP-MOBILE-FIRST launched once (CLI launch 6). Setup took 18003 ms, app returned HTTP 200, the CLI started `--project=admin-eval --project=admin-eval-mobile --project=admin-eval-dark`.
- The test log shows the first positive control hung for 12.6 minutes and a later control for 15.4 minutes. The runner's work deadline did not terminate the process tree. After about 29 minutes I sent SIGTERM to the Playwright CLI child only; the runner then ran its own cleanup and wrote the halted ledger.
- Charged: 1765488 ms for the slot; cumulative 2042596 ms; 6 CLI launches; retry_available 0.
- Slots CR-DESKTOP-SECOND, CR-MOBILE-SECOND and CR-DARK-SECOND were not run (halt rule). Task 2 not started.

## Outcome

Status halted. Runner stop reason: work deadline reached, owned cleanup over the 120000 ms limit, drop failed at cleanup deadline, no JSON report, 0 rows, independent database absence receipt missing. The `--stage first` verifier rejects the evidence.

## Task Commits

1. Task 1 evidence (halted ledger plus raw logs): `1e1250641` (docs)

## Deviations from Plan

- **[Process] Manual SIGTERM of the CLI child.** Needed because the runner's deadline enforcement never fired. The runner recorded the real elapsed time, so the charge is the true cost, not an edited number.
- **[Hygiene] Dropped orphaned owned database** `sigra_253_control_load_cr_desktop_mobile_first_mv7ucv0t_41145` by exact name, because the runner's drop hit the cleanup deadline. Done after the evidence was written, so the committed evidence still says absence was not proven. Afterwards zero `sigra_253_control_load_%` databases remain. No other process was killed.

## Issues Encountered / Remaining Gaps

- Probable defect for the next planning pass: `runLoggedTree` timeout does not terminate the Playwright process tree in this environment (system load average about 12). This is a likely cause of the unenforced window, not yet root-caused.
- The runner's raw report is missing, so the per-test causes of the 12.6 and 15.4 minute stalls are known only from the test log.
- All four regular windows are not available: one is spent, the cumulative charge is 2042596 ms. Nothing here is accepted native proof. CIREL-01 and CIREL-02 remain open. No GitHub writes were made.

## Self-Check: PASSED

Evidence file and raw directory exist and are committed in `1e1250641`; working tree is clean except the pinned `.planning/config.json`; no `scripts/ci/__pycache__`.
