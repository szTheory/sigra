---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
current_phase: 253
current_phase_name: Fix Flaky CI and Preserve Required Checks
status: "executing_recovery"
stopped_at: "Plan 09 halted before browser; independent Plan 11 executing"
last_updated: "2026-10-13T14:04:38.077234+00:00"
last_activity: "2026-10-13"
last_activity_desc: "Six recovery plans passed independent review and planning checks"
state_head: "32d3646159f279014b84c7bdb02e5e118f6c2e3b"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 20
  completed_plans: 11
  percent: 55
milestone_status: active
workflow_step: "execute_recovery"
verification_status: not_started
phase252_verification_status: passed
phase253_verification_status: not_started
next_command: "$gsd-execute-phase 253 --gaps-only"
resume_command: "$gsd-execute-phase 253 --gaps-only"
next_command_conditional: false
historical_verification_is_forward_blocker: false
requirements_approved: true
roadmap_approved: true
phase253_planning_status: passed
phase253_plan_count: 14
phase253_wave_count: 4
phase253_task_count: 30
phase253_implementation_status: partial
phase253_completed_plans: 5
phase253_halted_plans: [253-02, 253-07, 253-09]
phase253_blocked_plans: [253-08, 253-10, 253-13, 253-14]

phase253_recovery_plan_count: 6

phase253_recovery_task_count: 13
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-10-12).

**Core value:** Authentication that works out of the box, with a clear path for Phoenix adopters.
**Current focus:** Phase 253 — Fix Flaky CI and Preserve Required Checks

## Current position

Phase: 253 (Fix Flaky CI and Preserve Required Checks) — INCOMPLETE
Plans: 5 of 14 complete; six recovery plans ready in four waves; original 02/07 halted and 08 blocked
Status: Plan 09 halted before browser; independent Plan 11 executing
Last activity: 2026-10-13 — Six plans, thirteen tasks checked; no browser or hosted work launched
Progress: 11/20 planned milestone plans complete (55%); Phase 253 verification not started

## Next GSD command

$gsd-execute-phase 253 --gaps-only

Six new recovery plans (09–14) passed independent review after one budget revision. Their first runnable plans are 09 and 11; the `--gaps-only` selection preserves original halted attempts and excludes blocked original 08. All new runs require new source and budget freezes before observing outcomes. Registration controls and targeted repeats share one ledger; hosted canary and both PR families have separate finite request/time ceilings. The normal PR supplies the five-seam integration proof once.

The startup repair is verified on three real apps with HTTP 200 and database cleanup, but no registration browser run has been proved. Original 02 and 07 remain halted and original 08 remains blocked. Both requirements remain open and Phase 253 verification has not started. Plan 14 may add an explicit 08 supersession summary only after both requirements are accepted, preserving the original failed evidence. Then unfiltered `$gsd-execute-phase 253` can reach whole-phase verification. Phase 254 has not started.

The original canary request count is still unproved, and the overwritten Task 2 RED bytes and missing original chronology remain disclosed. New proof does not retroactively repair either record. Phase 252 remains complete with all prior paths unchanged; historical release-record maintenance stays separate.

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

**Last session:** 2026-10-13T14:04:38.077234+00:00
**Stopped at:** Recovery planning passed; execute new plans 09–14 with --gaps-only
**Resume file:** .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-EXECUTION-RECORD.json

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

## Recovery execution update

Plan 09 stopped in setup: runtime port 25311 differs from compiled port 4011. Setup/drop both exited1; zero browsers launched; 3,768ms charged and D19-DIAG-01 spent. Native verification rejects failed cleanup and log digests made stale by key redaction. The exact metadata ledger contains no key values and is now durably committed and read back. GSD correctly blocks 10/13/14 behind halted09. Plan11 remains independent and is starting; Plan12 awaits11. Both requirements remain open and phase verification is not started. No GitHub requests occurred in this recovery execution.
