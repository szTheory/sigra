---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: in_progress
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_blocked_baseline_os_dependencies_and_images
stopped_at: Candidate passed; baseline WebKit system package installation timed out
last_updated: "2026-10-23T23:38:51.564739+00:00"
last_activity: 2026-10-23 - Four preparation outcomes preserved; candidate passed; zero measured samples
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
phase254_comparison_status: blocked_baseline_os_dependencies_and_images
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

Candidate CI and 108-case coverage passed; baseline system-package downloads hit two 30-minute limits, and per-job runner images differ. No measured comparison exists.

The approved baseline amendment and separate two-run allowance were executed. Candidate run 40035537413 passed with all 105 product cases and 3 setup cases preserved. Baseline run 40035528418 concluded cancelled: two WebKit jobs were still downloading Ubuntu packages at their 30-minute limits; Phoenix and browser tests did not start. The cause of slow downloads remains unknown. Different per-job runner images also prevent a fair comparison.

Current allowance is closed: 2 invocations, 0 retries, 202 HTTP requests within 60 minutes. Prior allowance remains 2 failures/186 requests. Total preparation invocations: 4. No measured sample or 48-hour window has started; all 40 measured invocations remain unspent. Implementation remains complete, whole-phase verification pending, CISPEED-01/02 open. Phase 253 is complete and verified; Phase 255 remains pending.

Next command: `$gsd-execute-phase 254`, conditional on resolving WebKit OS package installation and matching per-job images before another baseline invocation. Additional invocation authority is required; no retry or new numbered repair plan is authorized by the spent allowances.

Result: `.planning/execution/254-rebaseline-preparation/RESULT.json`. Recovery: `.planning/execution/254-rebaseline-preparation/FINAL-RECOVERY.json`. Previous shared-state bytes: `.planning/execution/254-rebaseline-preparation/STATE-BEFORE-CLOSEOUT.json` at `refs/evidence/phase254-before-amended-prep-closeout` (`fef59a0af7a888c1efeb229d793d9808ef00131c`). Original baseline archives, original halt records, failed attempts and old budgets remain unchanged. No notification was scheduled.
