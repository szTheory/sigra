---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
current_phase: 253
current_phase_name: Fix Flaky CI and Preserve Required Checks
status: ready_to_execute
stopped_at: Phase 253 plans independently checked; ready to execute; implementation and phase verification pending
last_updated: "2026-10-13T03:04:29.907034+00:00"
last_activity: 2026-10-13
last_activity_desc: Phase 253 eight plans checked; ready to execute; implementation and verification pending
state_head: dc492e044ae67da84bc2aa022c3aae9b7c25b53b
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 14
  completed_plans: 6
  percent: 25
milestone_status: active
workflow_step: phase_execution_ready
verification_status: not_started
phase252_verification_status: passed
phase253_verification_status: not_started
next_command: $gsd-execute-phase 253
resume_command: $gsd-execute-phase 253
next_command_conditional: false
historical_verification_is_forward_blocker: false
requirements_approved: true
roadmap_approved: true
phase253_planning_status: passed
phase253_plan_count: 8
phase253_wave_count: 4
phase253_task_count: 17
phase253_implementation_status: not_started
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-10-12).

**Core value:** Authentication that works out of the box, with a clear path for Phoenix adopters.
**Current focus:** Phase 253 — Fix Flaky CI and Preserve Required Checks

## Current position

Phase: 253 (Fix Flaky CI and Preserve Required Checks) — READY TO EXECUTE
Plan: 0 of 8 complete (planning checked)
Status: Ready to execute
Last activity: 2026-10-13 — Phase 253 planning checked; implementation and verification pending
Progress: [███░░░░░░░] 25%

## Next GSD command

$gsd-execute-phase 253

Phase 252 implementation and phase verification are complete: six plans, 27/27 verified truths, CIMEAS-01 and CIMEAS-02 satisfied, 20/20 security controls, and both code-review findings independently repaired. The committed baseline covers PR, main-push and nightly populations; run 38317383419 supplies the complete instrumented PR sample. Later comparison runs have not started.

Phase 253 has eight independently checked plans, 17 tasks and four dependency waves. Both phase requirements and all 24 decisions are covered by executable tasks. init.execute-phase 253 recognizes eight incomplete plans, no halted plans and no reported prerequisite blocker. Registration root cause remains unknown; CIREL-01/02, implementation and phase verification are pending. Execute the diagnosis/reproduction and independent gate work under their frozen limits. Historical release-record maintenance does not block this route; no optimization is started.

## Known unfinished work

- READY-01: no original approval was found for the exact code and checks used to prepare the release; saved readiness/test receipts name different code, and the old owner report could not be confirmed from its original GitHub record. The archived requirement remains unchecked.
- Published 1.6.0 lacks its upgrade guide and README link. See `.planning/todos/pending/2026-10-12-add-missing-v16-upgrade-guidance.md`.
- Phase 246's report is stale, and GSD's parser reports Phase 247's legacy report missing even though the source-derived checker reads it. These are recorded verification overrides, not passes.
- Unrelated backlog and quick tasks remain open; none was silently marked complete.

## Evidence

- Phase 253 planning: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-PLANNING-RECORD.json`; independent passed review: `253-PLAN-CHECK-02.md`; planning checks: `253-PLANNING-CHECKS.json`; routing checks: `253-PLANNING-ROUTING-CHECKS.json`; source coverage: `253-SOURCE-AUDIT.md`; research/patterns/validation: `253-RESEARCH.md`, `253-PATTERNS.md`, `253-VALIDATION.md`. SDK planning/session bytes remain recoverable at `dc492e044ae67da84bc2aa022c3aae9b7c25b53b`. Planning review is not phase acceptance.

- Phase 253 context: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTEXT.md` (commit `ba4b9e5eea403b892efe2fb02172a25caa55e10b`); discovery: `253-DISCOVERY.json`; discussion/review: `253-DISCUSSION-LOG.md`, `253-SYNTHESIS-REVIEW.md`; preservation and readiness: `253-DISCUSSION-RECORD.json`; 17 artifact checks: `253-DISCUSSION-CHECKS.json`. Current registration cause is unproved. Prior draft is recoverable at `87177118c66f6f1041a7c1727568ac19aeb3d990`; exact SDK session state at `42c558cd77386b7e92ec142fefe95064c39efec5`.

- Phase 252 completion and routing: 252-COMPLETION-RECORD.json; verifier: 252-VERIFICATION.md (passed, 27/27); security: 252-SECURITY-AUDIT.json (20/20); validation: 252-VALIDATION.md; code review: 252-REVIEW-DISPOSITION.md and 252-REVIEW-FINAL-RECHECK.md (both findings fixed).
- Baseline: 252-BASELINE.md, 252-BASELINE.json, 252-CI-SOURCE-BUNDLE.tar.gz; comparison method: 252-COMPARISON-CONTRACT.json. Hosted sample: draft PR #331, run 38317383419, all five required checks passed. Main ExUnit 2,683 rows and separate child 65 rows; total runner cost 2,042 seconds. Unknown overhead and one-sample limits remain explicit.
- Prior tracking bytes preserved in 252-CLOSEOUT-PRESERVATION.json; exact SDK completion state committed at 48ec9126e06bef0effe5f8578fb592fe9851848b. Initial execution capture remains immutable and is superseded by the completion record.

- The exact SDK state transition is preserved and read back at commit `2c50a2a213a7ca52f2733e694e4b8bc4a630796f`, with file hashes in `252-06-STATE-PRESERVATION.json`.
- Final independent planning check: `252-PLAN-CHECK-03.md`; planning record/checks: `252-PLANNING-RECORD.json`, `252-PLANNING-CHECKS.json`, `252-PLANNING-ROUTING-CHECKS.json`. These are planning checks, not completed phase verification.

- Phase 252 context/log/discovery: `.planning/phases/252-measure-current-ci/252-CONTEXT.md`, `252-DISCUSSION-LOG.md`, `252-DISCUSSION-RECORD.json`; context commit `96611810e2674a7c6318f48f36ae488a35d33c99`.
- Phase 252 artifact checks: `252-DISCUSSION-CHECKS.json`; final routing checks: `252-ROUTING-CHECKS.json`. Discovery is not phase acceptance.
- Prior session/routing bytes recoverable at `4faed92f6883005a29ced4e5f94d58eb12f0559b`; seven exact path read-backs recorded in the Phase 252 discussion record before route updates.

- New milestone scope/capture: `.planning/v1.50-START.json`; roadmap approval: `.planning/v1.50-ROADMAP-APPROVAL.json`.
- Final setup evidence: `.planning/v1.50-INITIALIZATION.json`; 70 todos scanned, one linked to Phase 253, 69 retained unchanged.
- Confirmed requirements: `.planning/REQUIREMENTS.md`; original proposal retained unchanged.
- Roadmap review, checks, and byte-preservation record: `.planning/v1.50-ROADMAP-REVIEW.json`, `.planning/v1.50-ROADMAP-CHECKS.json`, `.planning/v1.50-ROADMAP-PRESERVATION.json`. Earlier start checks remain historical.
- Prior SDK state and original handoff are exactly recoverable at `a9e29eb00f6e63b0effea1025b22d1e114d24346`; read-back verified before this continuation rewrite.
- Decision: `.planning/milestones/v1.49-CLOSEOUT-DECISION.json`.
- Strict audit: `.planning/milestones/v1.49-MILESTONE-AUDIT.md` — original bytes retained; `gaps_found`, 8/9.
- Requirement archive: `.planning/milestones/v1.49-REQUIREMENTS.md` — READY-01 unchecked, READY-02 checked.
- Owner report: `.planning/milestones/v1.49-phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md`.
- Phase 251 report: `.planning/milestones/v1.49-phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-VERIFICATION.md` — `gaps_found`, 9/10.
- Archive mapping and exact byte checks: `.planning/milestones/v1.49-ARCHIVE-MANIFEST.json`.
- Original context, log, state, and handoff remain recoverable at their recorded commits. Before this final rewrite, all nine target files were read back exactly from `f20381132082360c3fbf5ea2c2dd3068c930e15b`.

## Session

**Last session:** 2026-10-13T03:00:35.213Z
**Stopped at:** Phase 253 plans independently checked; ready to execute; implementation and phase verification pending
**Resume file:** .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-01-PLAN.md

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| verification_gaps | 251/251-VERIFICATION.md | gaps_found; accepted for moving on, not passed | 2026-10-12 | v1.49 |
| verification_gaps | 251/251-VERIFICATION-PRESERVED-20261011T2129Z.md | historical gaps_found; accepted for moving on, not passed | 2026-10-12 | v1.49 |

Two current records were acknowledged through the audit writer; 52 earlier acknowledgments remain. Thirty unrelated open items were retained, and the new upgrade-guide task remains open. The full inventories are in the closeout records.

## Performance Metrics

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 252 P01 | 19m | 2 tasks | 19 files |
| Phase 252 P02 | 28min | 3 tasks | 2 files |
| Phase 252 P03 | 12min | 2 tasks | 5 files |
| Phase 252 P04 | 28min | 2 tasks | 3 files |
| Phase 252 P05 | 32min | 3 tasks | 13 files |
| Phase 252 P6 | 84 | 3 tasks | 12 files |

## Decisions

- Measurement values require matching GitHub source identities and saved hashes; missing inputs remain unknown.
- Main and dependency-off ExUnit invocations stay separate so child output cannot replace the main suite.
- Required-check changes produce unknown waits; original failures and actual physical job cost remain visible.
- The later comparison uses 20 matched pairs in a predeclared 48-hour window, without replacement or window extension.
- Reporter overhead and queue detail remain unknown when not measured; historical release gaps do not block current CI work.
