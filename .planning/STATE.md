---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: in_progress
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_native_image_authority_correction
stopped_at: Corrected image authority running in existing evidence PRs
last_updated: "2026-10-24T00:33:52.807047+00:00"
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
phase254_comparison_status: preparing_native_image_authority_correction
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

Verified package acquisition repair plus corrected native image authority are running in the same evidence PRs. Six preceding preparation outcomes remain preserved; no measured sample has started.

Current user delegated recovery authority: `.planning/execution/254-environment-recovery/IMAGE-AUTHORITY/AUTHORIZATION.json`. Continue `$gsd-execute-phase 254` in the same Plan 254-08. The bounded signed HTTPS installer worked in real hosted WebKit jobs: package downloads took about 21–22 seconds and package installation about 19–25 seconds. The first environment-repair pair failed because the newly introduced v1 gate required redundant environment metadata to equal the documented native image record. Both failures and their 180-request closed budget are preserved in `.planning/execution/254-environment-recovery/PREPARATION/FINAL-RECOVERY.json`.

The reviewed v2 policy fixes the native image file as authority on both roles, preserves environment disagreements as diagnostics, verifies unchanged raw native/OS bytes and execution identity, and still compares canonical images/hashes per owner. Prior failures remain failed. The remaining generated-host OS-package installation now uses the same bounded helper. No dependency was added.

PR348 baseline is now source05f1a4a/run40045468739. PR349 candidate is sourceefff737/run40045481175. Both corrected initial runs are in progress under exactly two non-forcing source updates, zero retries, 60 minutes/600 HTTP requests. Six earlier preparation outcomes remain spent; total preparations started: eight, plus the isolated diagnostic. All 40 measured invocations remain unspent and the 48-hour window has not begun.

Implementation is complete; comparison and whole-phase verification remain pending; CISPEED-01/02 remain open. Phase 253 is complete and verified; Phase 255 remains pending. Reconcile `.planning/execution/254-environment-recovery/IMAGE-AUTHORITY/WATCH.jsonl` and the existing active watcher before polling. Earlier shared state is recoverable at `refs/evidence/phase254-before-native-authority-running-state` (`f656174dbaca536f421a59e5f28b60b544418e48`), recorded in `.planning/execution/254-environment-recovery/IMAGE-AUTHORITY/STATE-PRIOR.json`. Do not create another numbered repair plan or return to the obsolete approval question.
