---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: in_progress
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_approved_rebaseline_preparation
stopped_at: Approved amended-baseline preparation in progress
last_updated: "2026-10-23T22:43:12.698931+00:00"
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
phase254_comparison_status: in_progress_preparation_failed
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

The latest user approval authorizes the precise baseline amendment and a separate two-run preparation allowance. Authority: `.planning/execution/254-REBASELINE-AUTHORIZATION.json`. Continue the same Plan254-08 with `$gsd-execute-phase 254`. The new baseline retains all original application/browser bytes and changes only Git-history handling, the PostgreSQL registry, and the matching live image assertion. The corrected candidate uses reviewed source `dd4e3b437`.

Prior preparation remains two failures with186 HTTP requests, preserved under `.planning/execution/254-rerun-preparation/FINAL-RECOVERY.json`; no old budget is reset. Current allowance: two initial real-PR CI invocations, zero trigger retries, at most60 minutes and600 actual HTTP requests. It has not started. Current sources and limits: `.planning/execution/254-rebaseline-preparation/SOURCE-SNAPSHOTS.json` and `.planning/execution/254-rebaseline-preparation/CONTRACT.json`.

No measured sample or48-hour comparison window has started. Plans254-01 through254-07 remain implemented. CISPEED-01/02 remain open; whole-phase verification is pending. Phase253 remains complete and verified; Phase255 remains pending.

Previous state bytes are recoverable through `.planning/execution/254-rebaseline-preparation/PRIOR-STATE.json`. All original baseline archives, halted contracts, failed PR345 and prior preparation records remain unchanged. Do not interpret eight summary files as eight successful plans or complete the phase before actual hosted acceptance and verification.
