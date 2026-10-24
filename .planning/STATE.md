---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: in_progress
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_approved_rerun_continuation
stopped_at: Approved rerun continuation; tooling and preparation preflight in progress
last_updated: "2026-10-23T21:09:52.686054+00:00"
last_activity: 2026-10-23 - Phase 254 implementation complete; hosted baseline PR path blocked
state_head: f2cd83578701b4d212c7b4fc955d50179e867880
progress:
  total_phases: 4
  completed_phases: 2
  percent: 50
requirements_approved: true
roadmap_approved: true
phase252_verification_status: passed
phase253_implementation_status: complete
phase253_verification_status: passed
phase254_planning_status: passed
phase254_plan_count: 8
phase254_completed_plans: 7
phase254_halted_plans: [254-08]
phase254_wave_count: 5
phase254_task_count: 19
phase254_implementation_status: complete
phase254_comparison_status: blocked_not_started
phase254_verification_status: pending
verification_status: pending
next_command: "$gsd-execute-phase 254"
resume_command: "$gsd-execute-phase 254"
next_command_conditional: false
historical_verification_is_forward_blocker: false
resume_file: .planning/phases/254-speed-up-the-measured-slow-jobs/254-08-PLAN.md
phase254_current_execution_addendum: .planning/execution/254-CONTINUATION.json
---

# Current position

Implementation is complete through Plans 254-01 to 254-07. Plan 254-08 halted: baseline PR 331 merges current main into a different tree and CI workflow from the frozen baseline. Hosted comparison has not started; phase verification remains pending.

All five isolated local browser owners passed. Exact parity covers 108 native identities: 105 product cases and three setup cases. Code review has no unresolved findings; validation coverage has no gaps. Local results do not establish the hosted median, p95 or all-attempt runner-cost targets. CISPEED-01 and CISPEED-02 remain open.

## Blocker and next action

Baseline PR #331 has the original head, but its current GitHub merge preview tree is `cc2038166f1847e2e2f5ce2428d9a53ba0ae8cae`; the frozen baseline tree is `bcda2b1eb386bdbaaf1bde2b6f034e0c7ee74452`. The CI workflow differs too. The candidate is also unpublished, which is a separate availability fact. Publishing it would not fix the baseline mismatch.

Next command, conditional on resolving the baseline prerequisite: `$gsd-execute-phase 254`.

First establish an allowed current real-PR path whose actual merge/source/workflow trees match the frozen baseline. Then continue the existing Plan 254-08 checkpoint; do not create replacement samples, reset budgets, or redispatch Plans 01-07.

The installed index sees eight summaries and zero incomplete plans, including one halted plan. That does not mean eight successful plans or a verified phase. Use `.planning/execution/254-CONTINUATION.json` to continue the existing Plan 08 checkpoint. Do not run phase completion or advance to Phase 255 on summary count alone.

## Evidence

- Implementation and parity: `.planning/phases/254-speed-up-the-measured-slow-jobs/254-COLLECTION-ELIGIBILITY.json` and `254-07-SUMMARY.md`.
- Hosted blocker: `254-HOSTED-PR-PATH-PROOF.json`, `254-HOSTED-READINESS.json`, and `254-08-SUMMARY.md` in the same phase directory.
- Local validator repair: `.planning/execution/254-validator-maintenance.json`. Twenty security tests and the comparison suite passed; the blocked contract now returns structured invalid diagnostics. Original contract/proof bytes are unchanged.
- Zero comparison families and preparation runs; no 48-hour window started. Both flagged assumptions and reporting prohibitions remain unresolved.

## Preserved history

Prior shared state and roadmap are recoverable at `f2cd83578701b4d212c7b4fc955d50179e867880` via `refs/gsd/phase254/state-before-hosted-halt`. Exact path/status/blob/hash and read-back results: `.planning/execution/254-final-state-prior.json`. Earlier wave-3 state preservation is recorded in `.planning/execution/254-state-before-wave3.json`.

Phase 253 remains complete and verified at 6/6. Its 81 implementations, 29 halts and 73 retired unused plans remain distinct; old stopped attempts and allowances are unchanged. Canonical report: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-VERIFICATION.md`. Its recovery history remains under `.planning/execution/253-final-gates/` and `.planning/execution/253-final-review/`.

## Approved unblock — execution in progress

The user explicitly approved the rerun method and finite preparation allowance with "yes i approve". Authority: `.planning/execution/254-RERUN-AUTHORIZATION.json`. Preserve the original distinct-run contract and blocked records as history; the approved continuation uses separately registered (run ID, attempt) samples. Keep all forty samples/twenty pairs, thresholds, all-warm/runner compatibility and the single48-hour window. At most two preparation invocations, no retries, within60minutes/600HTTPrequests; no old Phase253 budget is reused. No hosted run has started at this authorization capture. Continue the same Plan254-08 with `$gsd-execute-phase 254`.
