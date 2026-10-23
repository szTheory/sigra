---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: blocked
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_baseline_amendment_decision
stopped_at: Both preparation runs failed; baseline amendment requires a decision
last_updated: "2026-10-23T22:31:10.936343+00:00"
last_activity: 2026-10-23 - Two failed preparation invocations preserved; zero measured samples
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
phase254_comparison_status: blocked_preparation_failed
phase254_verification_status: pending
verification_status: pending
next_command: "$gsd-execute-phase 254"
resume_command: "$gsd-execute-phase 254"
next_command_conditional: true
historical_verification_is_forward_blocker: false
resume_file: .planning/phases/254-speed-up-the-measured-slow-jobs/254-08-PLAN.md
phase254_current_execution_addendum: .planning/execution/254-CONTINUATION.json
---

# Current position

Plans 254-01 through254-07 are implemented. Both approved preparation invocations failed: baseline attempt 2 hit missing Git history and an ECR PostgreSQL download cap; candidate PR #345 attempt 1 failed one stale workflow assertion. Local repairs pass scoped tests. No measured sample or48-hour window started; phase verification is pending.

CISPEED-01 and CISPEED-02 remain open. Implementation, hosted comparison and whole-phase verification remain separate. Phase 253 is still complete and verified; its old attempts and allowances are unchanged. Phase 255 remains pending.

## Blocker and next action

The original baseline rerun preserved checkout `cc8cd273` and its original workflow, but its shallow fetch of newer main caused `no merge base`, followed by `docs_only=true`. Some green job labels contained skipped test bodies. Separately, ECR refused PostgreSQL with `toomanyrequests: Data limit exceeded`. Another unchanged rerun cannot repair the shallow-fetch command.

Candidate draft PR #345 used the exact tested snapshot and reached the suite: 2,659 tests, one failure in the live Mix-command assertion. That assertion and the current change detector are repaired locally. The failed hosted snapshot is preserved unchanged.

Next command: `$gsd-execute-phase 254`, **conditional on approving the concrete baseline amendment and separate preparation allowance** in `.planning/execution/254-rerun-preparation/REBASELINE-PROPOSAL.json`. The patch changes Git history handling, PostgreSQL registry, and the matching live image assertion. No proposed-baseline run has started.

Both authorized preparation invocations are spent; zero CI trigger retries remain. Acquisition used186 of 600 HTTP requests under the original 60-minute clock. Five previously rejected execution-record artifacts were recaptured after an ordinary parser fix; no workflow was rerun, no clock/count was reset, and the old failed capture remains preserved. No comparison sample was spent and the single 48-hour window is unopened.

## Evidence and recovery

- Actual results, source/tree checks, failures, budget and limits: `.planning/execution/254-rerun-preparation/RESULT.json`.
- Full raw attempts and original failed capture: verified scoped refs named by `.planning/execution/254-rerun-preparation/FINAL-RECOVERY.json`. Initial refs: `refs/evidence/phase254-preparation-before-attempt-2` and `refs/evidence/phase254-preparation-after-attempt-1`.
- Local repaired source: `dd4e3b437`; local test logs under `.planning/execution/254-rerun-preparation/LOCAL-*`. Native owner implementation and 108-identity parity remain recorded in the Phase 254 collection eligibility artifact.
- Prior shared state: `.planning/execution/254-rerun-preparation/STATE-BEFORE-CLOSEOUT.json`, ref `refs/evidence/phase254-state-before-preparation-closeout`. Original baseline/archive and original blocked Plan08 contract, proof and summary remain unchanged.

The installed index sees eight summaries, including the halted eighth plan. Do not complete Phase 254 or advance on summary count alone. Follow `.planning/execution/254-CONTINUATION.json`; no new numbered repair plan or acceptance budget reset is authorized.
