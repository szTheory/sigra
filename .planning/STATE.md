---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
milestone_status: active
status: in_progress
current_phase: 254
current_phase_name: Speed Up the Measured Slow Jobs
current_plan: "08"
workflow_step: phase254_final_live_parity_verification
stopped_at: Exact final parity-corrected sources running
last_updated: "2026-10-24T00:54:18.793805+00:00"
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
phase254_comparison_status: preparing_final_workflow_parity_verification
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

Both preceding sources passed every required context; full CI exposed a live evidence-workflow copy mismatch. The exact two-file correction passed both complete local guard suites and is running in the same evidence PRs.

Continue `$gsd-execute-phase 254` in the same Plan254-08 under current delegated recovery authority `.planning/execution/254-environment-recovery/PARITY-FIX/AUTHORIZATION.json`. Do not return to an obsolete approval question. Package acquisition and native image authority are verified in hosted runs; all five required contexts passed on both preceding sources. Their overall CI remains failed because the active green-04 evidence copy missed the generated-host install-body change. The exact two-file companion/marker correction passes all93 baseline and118 candidate prohibition tests locally. Strict parity checks and historical fixtures remain intact.

Current sources: baselinefb2d3faa/run40046955449; candidateebb1d3ef/run40047078287, in PR348/349. Exactly two counted source updates, zero retries,60minutes/600HTTPrequests. Eight preceding preparation outcomes remain spent and preserved; total initial preparations started: ten, plus the isolated diagnostic. No measured sample or48-hour window has started; all40 measured invocations remain unspent.

Implementation is complete; comparison and whole-phase verification pending; CISPEED-01/02 open. Phase253 complete and verified; Phase255 pending. Reconcile `.planning/execution/254-environment-recovery/PARITY-FIX/WATCH.jsonl` and active watcher before any polling. The measurement script and draft are in `.planning/execution/254-environment-recovery/MEASUREMENT`; never start it without actual successful current-source preparation, native/image/cache proof and an immutable future window. Prior shared state: `.planning/execution/254-environment-recovery/PARITY-FIX/STATE-PRIOR.json` at `refs/evidence/phase254-before-live-parity-running-state` (`f66d32198c60c4a20d9093d280da6a2f3b9a6750`).
