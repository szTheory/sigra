---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: in_progress
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_environment_recovery_preparation
stopped_at: Verified environment repair running in PR348 and PR349
last_updated: "2026-10-24T00:05:37.507831+00:00"
last_activity: 2026-10-24 - Package repair verified on Linux; two fixed-source CI preparations running
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
phase254_comparison_status: preparing_verified_environment_repair
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

Scoped package and runner identity fix passed local Linux and hosted diagnostic checks. Fixed-source PR348/baseline and PR349/candidate preparation are running; four previous outcomes remain preserved.

Current user recovery authority: `.planning/execution/254-environment-recovery/PREPARATION/AUTHORIZATION.json`. Continue `$gsd-execute-phase 254` in the same Plan 254-08. The isolated hosted probe passed; no APT rate cap was found, all four package downloads agreed, and native image/environment values agreed. The earlier image-cause claim is corrected in `.planning/execution/254-environment-recovery/IMAGE-CORRECTION.json`. A disposable amd64 Ubuntu container installed the complete locked Chromium/WebKit system packages after a 210 MB download in about 42 seconds, without retry. This is development verification, not a speedup acceptance sample.

Two new initial preparation invocations are running under a separate finite recovery recipe: PR348/run40043060412 baseline; PR349/run40043074317 candidate. Same package transport and early image proof on both sources; browser trees unchanged. Limits: two invocations, zero retries, 60 minutes/600 HTTP requests. Earlier four preparation outcomes and both closed budgets remain spent. Total preparation invocations started: six, plus one isolated diagnostic. No measured sample or 48-hour comparison window has started; all 40 measured invocations remain unspent.

Implementation is complete; comparison and whole-phase verification remain pending. CISPEED-01/02 are open. Phase 253 is complete and verified; Phase 255 remains pending. Source, proposal and native proof contracts are in `.planning/execution/254-environment-recovery/PREPARATION`. Before another action, reconcile `WATCH.jsonl` and the active watcher; do not duplicate polling or start replacements.

Prior shared-state bytes: `.planning/execution/254-environment-recovery/PRIOR-STATE.json` at `refs/evidence/phase254-before-environment-recovery-state` (`a2674e7ed3f21ff29dc3721da8a44bf840163b1b`). Original baseline archives, original halt records and previous preparations remain unchanged. No future notification was scheduled.
