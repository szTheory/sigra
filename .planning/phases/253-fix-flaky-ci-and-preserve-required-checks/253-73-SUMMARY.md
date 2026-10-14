---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "73"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, native, r4, halted]
status: halted
requires:
  - phase: 253
    provides: 253-72 R4 native freeze
provides:
  - Committed R4 budget approval (approve, retry granted) bound to R4 doc and freeze
  - First R4 window CR4-DESKTOP-MOBILE-FIRST accepted (16/16 rows, verify --stage first exit 0 at that point)
  - Terminal halt of CR4-DESKTOP-SECOND with full receipts
affects: [253-74]
actuals:
  tokens: 12000
  tasks: 2
  commits: 4
plan_head_before: 49ec983c61fe6681df1b68b8cba415023cd13d3f
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-BUDGET-APPROVAL-R4.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R4.json
  modified: []
key-decisions:
  - "Terminal non-infrastructure halt on CR4-DESKTOP-SECOND: the runner's pre-registration collision-absence psql query failed (exit 3), so no Playwright CLI launched; host stayed awake, so the infrastructure retry is not usable and was not used."
requirements-completed: []
coverage:
  - id: D1
    description: "R4 budget decision recorded and committed before any native launch"
    verification:
      - kind: other
        ref: "ci-registration-recovery.mjs --record-budget-approval (approve; retry_granted=1; shared cap 5472537)"
        status: pass
    human_judgment: false
  - id: D2
    description: "First R4 window: 16 frozen rows accepted on an awake host"
    verification:
      - kind: e2e
        ref: "ci-registration-recovery.mjs --verify-load-recovery --stage first (exit 0 before the second window ran)"
        status: pass
    human_judgment: false
  - id: D3
    description: "All 22 native control rows accepted"
    verification:
      - kind: e2e
        ref: "CR4-DESKTOP-SECOND halted; CR4-MOBILE-SECOND and CR4-DARK-SECOND not run"
        status: fail
    human_judgment: true
    rationale: "Plan halted; replanning required"
duration: 5min
completed: 2026-10-14
---

# Phase 253 Plan 73: R4 native budget approval and native control windows Summary

**Jon approved the R4 budget (with one infrastructure retry); the first window passed all 16 rows, but CR4-DESKTOP-SECOND halted before launching any browser because the runner's collision-absence query (`SELECT count(*) FROM users ...`) exited 3 against the fresh database.**

## Decision

Task 1 (checkpoint:decision) was answered "approve" by Jon via the orchestrator ("Approve with retry (Recommended)": D19-R4 cap 3132537 ms, max 13 launches, one 240000 ms infrastructure retry only after a diagnosed infrastructure halt). R4 freeze check exit 0; freeze sha256 abf6e110e00dfb85ed6ae521815d6a5a5388d062b2c5f6ef579643b181107346. Recorded in `253-LOAD-RECOVERY-BUDGET-APPROVAL-R4.json` (commit 788d1fd74; retry_granted 1, shared cap 5472537 ms, budget sha256 865561402eb8...).

## Task outcomes

- Preflight 1: `{"holder_pid":85036,"ac_power":true,"assertions_sha256":"a347c6de...3a55","checked_at":"2026-10-14T18:29:39.497Z"}`. Ledger initialized and committed (b746e15ac). Preparation charged 821 ms.
- **CR4-DESKTOP-MOBILE-FIRST: ACCEPTED.** 16 rows, charged 92810 ms, launch 9, host_awake receipt present (ac_power true, suspended false). `--verify-load-recovery --stage first` exited 0 ("1/4 commands; 9/22 CLI launches; 2316168 ms cumulative"). Committed 0596dd97a.
- Preflight 2 (before second window): ac_power true, holder_pid 66095.
- **CR4-DESKTOP-SECOND: TERMINAL HALT.** setup 39782 ms (setup exit 0, app served 200 on port 25311), command charge 3753 ms, slot charge 43535 ms, no Playwright CLI process, 0 rows, no suspension (max_tick_gap_ms 3), host_awake receipt ok. The prior-collision-absence step ran `psql ... -d <fresh db> -c "SELECT count(*) FROM users WHERE email = :'target'"` and it exited 3 (ON_ERROR_STOP) with empty output; the demo schema places tables under the `auth` schema (seed inserts go to `"auth"."audit_events"`), so the unqualified `users` relation is the likely cause. This is a runner defect (hypothesis, not verified; no source edited after halt). Committed 88e2ba4d1.
- Because no test ran and the host was awake, the runner records no infrastructure halt (infrastructure_halts empty, retry_available 0); the single infrastructure retry was NOT used. CR4-MOBILE-SECOND, CR4-DARK-SECOND and Task 3 not run. No further native command was run.
- Post-halt `--verify-load-recovery --stage first` exits 3 (halted status), as expected for a terminal halt.

## Per-test diagnostics, first window (accepted)

| Project | Title | Status | First error line |
|---|---|---|---|
| admin-eval | registration waits for explicitly released LiveView readiness | passed | - |
| admin-eval | registration stops when LiveView readiness is never released | failed (intended) | 1 error (readiness timeout) |
| admin-eval | registration fails when the readiness wait is deliberately broken | failed (intended) | 1 error |
| admin-eval | registration detects a deliberate same-account collision | passed | - |
| admin-eval | registration retains the first forced assertion failure trace | failed (intended) | 1 error |
| admin-eval-mobile | (same five rows, same pattern) | passed/failed(intended) | as above |
| admin-eval-dark | (same five rows, same pattern) | passed/failed(intended) | as above |
| admin-eval-dark | render bundle: board-mg-9/populated | passed | - |

Per-row detail is in `NATIVE-EVIDENCE-R4.json.raw/CR4-DESKTOP-MOBILE-FIRST/attempt-01/` (tests.jsonl, error-context files, playwright-report.json). The union-context-identity validator that halted 253-63 accepted these rows.

## email_value_after_ready_was_empty

`true` for the positive control in all three projects (admin-eval, admin-eval-mobile, admin-eval-dark); present as 6 occurrences (test and result level mirror) in the sanitized report.

## Charges and launches

- Carried 2222537 ms + preparation 821 + first window 92810 + halted second slot 43535 = 2359703 ms charged (cap 3132537 D19-R4; 5472537 shared).
- Launches: 8 carried + 1 = 9 (cap 13 / 22). Infrastructure retry granted 1, used 0.

## Commits

- 788d1fd74 approval record; b746e15ac ledger init; 0596dd97a first window accepted; 88e2ba4d1 halted second-window evidence.

## Deviations from Plan

None - the halt is the plan's designed terminal path for a non-infrastructure result. Rule-based source fixes were not applied: the contract forbids source edits after a halt.

## Remaining gaps

16 of 22 rows accepted; 6 second-window rows not accepted (CR4-DESKTOP-SECOND halted pre-launch; MOBILE/DARK second windows not run). Replan: fix and verify offline the prior-collision-absence/created-account psql query (schema-qualify `auth.users` or set search_path), then new freeze and budget decision. Remaining D19-R4 headroom: 772834 ms, 4 launches. Full Phase253 verification stays not_started.

## Self-Check: PASSED
