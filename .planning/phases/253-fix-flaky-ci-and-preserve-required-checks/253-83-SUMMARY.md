---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "83"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, native, budget-decision, r5]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-82 R5 native freeze; 253-79/80 schema-qualified auth.users count and R5 run path"
provides:
  - "Jon's R5 budget approval record (approve, retry_granted=1)"
  - "22-row native control proof (16 carried + 6 new) under the R5 freeze, accepted by --stage complete"
affects: [253-84]
actuals:
  tokens: 0
  tasks: 3
  commits: 5
plan_head_before: eead8f915b7ab50615e050c661062976142c8b5f
plan_head_after: 20fe8c1fdcce088137dc0f2b7b8e3f2566468eda
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-BUDGET-APPROVAL-R5.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R5.json
  modified: []
key-decisions:
  - "Jon decision via orchestrator: option approve, text 'Approve with retry (Recommended)'; the single infrastructure retry was NOT needed"
requirements-completed: ["CIREL-01", "CIREL-02"]
duration: ~6min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 83: R5 native second windows Summary

**All three R5 second windows (desktop, mobile, dark) passed on an awake AC-powered host: the fixed schema-qualified count query proved collision absence (0) then creation (1) in each, completing the 22-row native control proof with no retry and 463428 ms of headroom left under the approved cap.**

## Decision (Task 1, resolved by Jon via orchestrator)

Option id `approve`; verbatim decision text recorded: "Approve with retry (Recommended)". R5 freeze check exit 0 (file sha256 a2e273396e986e5ddf7488104829c59930780d21ade8d2fa1fc0ea4f3e1f1312). Approval record: retry_granted=1, shared cap 5264703 ms.

## Preflight JSON (host cannot sleep)

Each window was preceded by --preflight-host-sleep, all exit 0 with ac_power true and a holder PID:
- initial: `{"holder_pid":89935,"ac_power":true,...}`
- before CR5-DESKTOP-SECOND: holder 99590, ac_power true
- before CR5-MOBILE-SECOND: holder 7760, ac_power true
- before CR5-DARK-SECOND: holder 13914, ac_power true

## Execution performed

| Slot | Rows | Charge (ms) | Cumulative launches | Absence receipt | Created receipt | Result |
|---|---|---|---|---|---|---|
| prepare | - | 889 | 9 | - | - | ready |
| CR5-DESKTOP-SECOND | 2 | 33313 | 10 | count 0 | count 1 | passed |
| CR5-MOBILE-SECOND | 2 | 37439 | 11 | count 0 | count 1 | passed |
| CR5-DARK-SECOND | 2 | 29787 | 12 | count 0 | count 1 | passed |

Per-test diagnostics (all status passed): for each of admin-eval, admin-eval-mobile, admin-eval-dark, "registration starts from a fresh database and context" and "registration discards trace after a passing control".

## Accounting

- Cumulative charge 2461131 ms (carried 2359703 + prep 889 + 33313 + 37439 + 29787) versus D19-R5 cap 2924703 ms (463572 ms headroom).
- Launches 12 of 13 approved (9 carried + 3). Infrastructure retry: NOT used (no suspension, holder never lost).
- Verifier: `--verify-load-recovery ... --stage complete` exit 0 ("3 new commands; 12/22 CLI launches; 2461131 ms cumulative"). `--stage progress` after the final slot correctly rejects (3 outcomes exceeds progress bound of 2); this is expected, progress was exit 0 after each of the first two slots.
- p17-no-playwright-retry-wrapper test: 5/5 pass.
- Evidence file sha256: 14df65778c6e1ab924d0ed5430937383af95c499c1f00468028910eda9d9f9a1.

## Task Commits

1. Approval record - `8a6d8fb2f`
2. Ledger initialized with carried first window - `e30617009`
3. CR5-DESKTOP-SECOND - `cc916a9af`
4. CR5-MOBILE-SECOND - `6e676d65d`
5. CR5-DARK-SECOND + complete - `20fe8c1fd`

## Deviations from Plan

None - plan executed exactly as written. (Note: the raw per-slot RECEIPT.json paths listed in the plan's files_modified are not separate files in this runner version; receipts live in the evidence JSON and the per-slot logs/diagnostics under the .raw directory.)

## Remaining gaps

Cause assessment and acceptance remain for 253-84. Full Phase 253 verification stays not_started.

## Self-Check: PASSED
