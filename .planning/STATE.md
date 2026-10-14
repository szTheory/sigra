---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
current_phase: 253
current_phase_name: Fix Flaky CI and Preserve Required Checks
status: native_halted_recovery_planning_required
stopped_at: "Plan27 halted: canonicalize cannot load ESM parse5 under Node20; no selected tests ran"
last_updated: "2026-10-14T02:23:52.967Z"
last_activity: "2026-10-14T01:30:01.883389+00:00 — failed 33,409 ms command saved; cumulative 276,453 ms across five launches, with no retry available"
state_head: fd35b20a3957804fa9bb45cc02735f5a7a6e039b
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 53
  completed_plans: 17
  percent: 25
milestone_status: active
workflow_step: plan_recovery
verification_status: not_started
phase252_verification_status: passed
phase253_verification_status: not_started
next_command: $gsd-plan-phase 253
resume_command: $gsd-plan-phase 253
next_command_conditional: false
historical_verification_is_forward_blocker: false
requirements_approved: true
roadmap_approved: true
phase253_planning_status: passed_with_informational_advisory
phase253_plan_count: 35
phase253_wave_count: 9
phase253_task_count: 76
phase253_implementation_status: partial
phase253_completed_plans: 11
phase253_halted_plans:
  - 253-02
  - 253-07
  - 253-09
  - 253-12
  - 253-16
  - 253-27
phase253_blocked_plans:
  - 253-08
  - 253-10
  - 253-13
  - 253-14
  - 253-17
  - 253-21
  - 253-22
  - 253-23
  - 253-24
  - 253-25
  - 253-28
  - 253-29
  - 253-30
  - 253-31
  - 253-32
  - 253-33
  - 253-34
  - 253-35
phase253_recovery_plan_count: 6
phase253_recovery_task_count: 13
phase253_additional_recovery_plan_count: 11
phase253_additional_recovery_task_count: 24
phase253_control_recovery_plan_count: 10
phase253_control_recovery_task_count: 22
phase253_ready_plans: []
last_activity_desc: Plan26 completed offline; Plan27 native load failure preserved; dependent plans stopped
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-10-12).

**Core value:** Authentication that works out of the box, with a clear path for Phoenix adopters.
**Current focus:** Phase 253 — Fix Flaky CI and Preserve Required Checks

## Current position

Phase: 253 (Fix Flaky CI and Preserve Required Checks) — READY TO EXECUTE
Plans: 11/35 implemented; Plan 26 complete offline, Plan 27 halted (0/2 tasks), Plans 28–35 blocked
Status: No runnable plans; Node 20 parse5 loading and missing portable proof need recovery planning
Last activity: 2026-10-14T01:30:01.883389+00:00 — failed 33,409 ms command saved; cumulative 276,453 ms across five launches, with no retry available
Progress: 17/41 planned milestone plans implemented ([███░░░░░░░] 25%); whole-phase verification not started

## Next GSD command

$gsd-plan-phase 253

The saved dark command failed before test collection: canonicalize.ts loads ESM-only parse5 through CommonJS under the frozen Node20 runner. Plan a compatible module-loading correction, source-bound freeze and missing portable runner contracts using only four unused regular commands and nine conditional acceptance commands. The spent retry and CR-DARK-FIRST cannot be reopened. Both reliability requirements and whole-phase verification remain open.

Current native total: 276,453 ms across five physical CLI launches; setup/drop exited0 and temporary build was removed, but no dark result was accepted. Local 41/41 Node 20 tests pass; native verifier exits 3 and correctly rejects the receipt. Diagnostic:253-CONTROL-RECOVERY-LOAD-FAILURE-DIAGNOSTIC.json; closeout:253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json; route:253-CONTROL-RECOVERY-EXECUTION-ROUTING.json. Phase254 remains pending.

## Known unfinished work

- READY-01: no original approval was found for the exact code and checks used to prepare the release; saved readiness/test receipts name different code, and the old owner report could not be confirmed from its original GitHub record. The archived requirement remains unchecked.
- Published 1.6.0 lacks its upgrade guide and README link. See `.planning/todos/pending/2026-10-12-add-missing-v16-upgrade-guidance.md`.
- Phase 246's report is stale, and GSD's parser reports Phase 247's legacy report missing even though the source-derived checker reads it. These are recorded verification overrides, not passes.
- Unrelated backlog and quick tasks remain open; none was silently marked complete.

## Evidence

- Recovery planning: `253-RECOVERY-PLANNING-RECORD.json`; independent review: `253-RECOVERY-PLAN-CHECK-02.md`; planning checks: `253-RECOVERY-PLANNING-CHECKS.json`; routing checks: `253-RECOVERY-ROUTING-CHECKS.json`. Six plan schemas and structures valid, 24/24 decisions and 26/26 requirement/decision items covered. Planning success does not mean phase acceptance.

- Startup debug resolved: `.planning/debug/resolved/phase253-registration-setup.md`; live setup receipt and 12 raw logs: `.planning/debug/phase253-setup-final-20261013T125238Z/manifest.json`. Fresh setup tests: 5 passed; forged-evidence checks: 6 passed. Original registration freeze/evidence and Phase 252 paths are unchanged. Startup verification does not prove registration behavior or complete Phase 253.

- Partial execution: `253-EXECUTION-RECORD.json`; fresh local checks: `253-POSTEXEC-CHECKS.json`; review repairs: `253-POSTEXEC-DISPOSITION.md`. Planning prior bytes are recoverable at 5ea3ef6267aabf885df51829f888fa1bf9c4dbc7 with exact read-backs in the execution record. Five implemented plans do not constitute completed phase verification.

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

**Last session:** 2026-10-14T01:30:01.883389+00:00
**Stopped at:** Native spec collection failed on parse5; next recovery planning
**Resume file:** .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json

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

## Latest recovery execution evidence

Plan11 local work complete;09/12 halted; new source repairs are committed with RED-before-GREEN records. Registration tests12/12, hosted verifier16/16, canary shell suite, legacy setup5/5 and six forged-claim checks pass. Registration:0browserlaunches/3768ms charged. Canary:3charged API-command entries/0jobs/0dispatches/0remote-ref changes; actualHTTP headers/redirect counts still need proof. The wrong ruleset query does not show required checks were removed.

Shared prior bytes are recoverable at 64ad6b727a9da7ea0da736f38870e677d37b6d76. The unrelated config model edit is preserved at refs/gsd/phase253-recovery-execution-unrelated-config and left unstaged. Native frozen proof remains rejected; requirements stay open. Historical stop route was $gsd-plan-phase 253; the current route is above.

## Latest additional recovery planning

Plans15–25:11plans,24tasks,8waves. Independent review253-REPLAN-PLAN-CHECK-02.md passed;22schema/structure checks passed,24/24decisions and26/26requirement/decision items covered. Verify paths and failing directions:54commands,0blockers/0warnings. Initial review omitted four artifact metadata requests from arithmetic; deterministic full-table sum and fresh independent review confirm120. No numeric override, plan rewrite, source execution or new phase acceptance.

Original14plans,94Phase252paths and all failed/freezes/ledgers remain byte-identical. Shared priorbytes: 409fb7afd8a14d9ee6755b9435cfad464b58fa73; exactSDKgenericstate preserved there before restoring full history. Unrelated config preserved at refs/gsd/phase253-recovery-execution-unrelated-config and left unstaged. Next: $gsd-execute-phase 253 --gaps-only.

## Additional recovery execution started

Command: $gsd-execute-phase 253 --gaps-only. New15/18 are ready; sequential execution starts with15. Earlier failed records remain unchanged. Capture:253-ADDITIONAL-EXECUTION-CAPTURE.json; exact SDK transition:96e4bbbc3caecd0d1e5320dd3d271dff098a3a58. No new browser or hosted result exists yet.

## Additional execution progress

Plan18 completed:14 local HTTPS tests and hermetic canary contract passed;0GitHub requests. Desktop/mobile registration passed in the reserved retry and mobile slot,121680ms total across3new launches including the firstfailed desktop. Sharedretryspent. Plan15 stayshalted pending permission to replace credential-bearing original setup logs with committed sanitized copies and then rerun the complete local suite. Old logs unchanged. Independent19 is ready. Progressrecord:253-ADDITIONAL-EXECUTION-PROGRESS-01.json. Next:$gsd-execute-phase 253 --gaps-only; phaseverificationnot_started.

## Additional execution current route

15/18/19 complete;9/25 actualimplementationplans complete. Userapproved original-logsanitization, committed25286d5d4;no pendingapproval. Fresh26Node/fiveShelltests andbothsavedregistrationreceiptsverified. Totalnativecharge121680ms across3launches,soleinfrastructure retryspent. Plan19:24verifier and15transporttests passed;0GitHubrequests.16/20ready,next16nativecontrols. Priorfailedsummaryrecoverableat25286d5d4;alloldfailure/freezes retained. Progressrecord253-ADDITIONAL-EXECUTION-PROGRESS-02.json. Next:$gsd-execute-phase 253 --gaps-only. Phaseverificationnot_started;requirementsopen.

## Native control halt and independent work

Plan16 halted after the firstdarkcombined command:121252ms exceeds120000ms;no native report,originaldrop timedout. OwnedtemporaryDBnowconfirmedabsent,separate112mscleanup,total243044ms across4browserlaunches;sharedretryspent.32localrunner/prohibitiontests pass;nativecontrolgate rejects. Remainingfivecontrol/nineacceptancecommandsunrun;nohumanapprovalcanreplaceproof.20independentready,next:$gsd-execute-phase 253 --gaps-only tofinishit. After20,next:$gsd-plan-phase 253 fornativecontrolfailure/recoveryplanning;nonewwindowauthorized. Progress:253-ADDITIONAL-EXECUTION-PROGRESS-03.json. Phaseverificationnot_started,requirementsopen.

## Additional recovery execution closeout

Plans 15, 18, 19, and 20 are complete at the implementation level. Plan 16 is halted: 121,252 ms exceeded the 120,000 ms limit and no native report was produced. Separate database cleanup succeeded in 112 ms; total charged work is 243,044 ms across four physical browser launches. Current desktop/mobile passes do not establish the historical cause or complete the missing dark/control results. Saved failed ledgers remain unchanged. The approved two-log sanitization is recorded at commit 25286d5d4. No GitHub requests or remote mutations were made in this invocation.

The next command is $gsd-plan-phase 253. Fresh init.plan-phase 253 found existing context and research with no prerequisite blocker; init.execute-phase 253 found zero runnable plans. Full phase verification has not started.

## Latest control recovery planning

Plans 26–35 add 10 plans, 22 tasks and nine dependency waves. Independent review has zero blockers, zero warnings and one informational command-path advisory; no override was used. All original 25 plans, failed receipts and Phase 252 artifacts remain unchanged. Full prior shared history is recoverable at 4f87b9650ffc54051ed9c4ab692a0283fede559c; the exact SDK state output is recoverable at c14e563aa9679922865de2fd08e3471cc7c6a67a. The unrelated config edit remains unstaged and recoverable at refs/gsd/phase253-recovery-execution-unrelated-config. Both CI reliability requirements and whole-phase verification remain open. Next: $gsd-execute-phase 253 --gaps-only.

## Control recovery execution started

Command: $gsd-execute-phase 253 --gaps-only. Start with Plan 26 offline control diagnosis and repair. Carry 243044 ms, four prior browser launches, and zero retries available. Existing failures remain unchanged; no new native or hosted proof exists yet. Capture: 253-CONTROL-RECOVERY-EXECUTION-CAPTURE.json. Exact SDK output remains recoverable at 6bb702c06d1426f9ddb20dde8a5d437c907f4973. Whole-phase verification remains not started.

## Control recovery execution progress

Plan26 offline implementation complete: Node20 acceptance11/11, assessment checker valid. Shared helper repairs held readiness order and positive/collision account reuse; historical registration cause remains unproved. Plan27 ready next. Record:253-CONTROL-RECOVERY-EXECUTION-PROGRESS-01.json. Native total243044ms/four launched commands/retry0 and both requirements remain open; whole-phase verification not started. Next:$gsd-execute-phase 253 --gaps-only.

## Control recovery execution closeout

Plan 26 complete offline; Plan 27 halted after one 33,409 ms command, no selected native tests. All older failed outcomes remain unchanged. Cumulative 276,453 ms across five launches, with no retry available. Fresh 41 Node 20 tests pass and native verifier rejects. Four unused regular commands and nine conditional acceptance commands remain reserved, not runnable without a new plan. Shared prior bytes are exactly recoverable at 6e7a08945b6940d613626c56fa81b37e9a4350c2. Both requirements and full phase verification remain open. Next: $gsd-plan-phase 253.
