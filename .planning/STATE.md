---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
current_phase: 252
current_phase_name: Measure Current CI
status: verifying
stopped_at: Completed 252-06-PLAN.md; phase verification pending
last_updated: "2026-10-12T21:38:49Z"
last_activity: 2026-10-12
last_activity_desc: Plan 252-06 hosted baseline and report complete; Phase 252 verification remains
state_head: 68f72acfd440e5ab8f25bfd8693245511921a006
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 6
  completed_plans: 6
  percent: 0
milestone_status: active
workflow_step: phase_verification_pending
verification_status: not_started
next_command: $gsd-execute-phase 252
resume_command: $gsd-execute-phase 252
next_command_conditional: false
historical_verification_is_forward_blocker: false
requirements_approved: true
roadmap_approved: true
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-10-12).

**Core value:** Authentication that works out of the box, with a clear path for Phoenix adopters.
**Current focus:** Phase 252 — Measure Current CI

## Current position

Phase: 252 (Measure Current CI) — VERIFYING
Plan: 6 of 6
Status: Plan implementation complete — phase-level verification pending
Last activity: 2026-10-12 — Plan 252-06 hosted baseline, archive replay and comparison contract completed
Progress: [░░░░░░░░░░] 0%

## Next GSD command

$gsd-execute-phase 252

All six Phase 252 plan implementations and summaries are complete. Plan 252-06 saved the hosted run, all five passing required checks, the source bundle, the hash-validated baseline and the later comparison contract. The phase-level verification has not started, so all nine requirements remain Pending. Plan 252-05's original Threadline failure was resolved by a forced test-environment compile and its required full `mix ci` rerun passed; see `252-05-INTEGRATION-RECHECK.json` and `252-05-SUMMARY.md`. Research, pattern mapping and independent plan checks are complete.

The broad-research skip choice and prior approvals stay in force. Old release-record failures are separate maintenance and do not block Phase 252. No missing old record is required from the user. Continue with `$gsd-execute-phase 252` for the phase-level verification route; do not advance to Phase 253 or mark Phase 252 requirements complete before verification.

## Known unfinished work

- READY-01: no original approval was found for the exact code and checks used to prepare the release; saved readiness/test receipts name different code, and the old owner report could not be confirmed from its original GitHub record. The archived requirement remains unchecked.
- Published 1.6.0 lacks its upgrade guide and README link. See `.planning/todos/pending/2026-10-12-add-missing-v16-upgrade-guidance.md`.
- Phase 246's report is stale, and GSD's parser reports Phase 247's legacy report missing even though the source-derived checker reads it. These are recorded verification overrides, not passes.
- Unrelated backlog and quick tasks remain open; none was silently marked complete.

## Evidence

- Phase 252 Plans 01–06 implementation and checks are complete; phase-level verification remains. Plan 06 evidence: `252-06-SUMMARY.md`, `252-CI-SOURCE-BUNDLE.tar.gz`, `252-BASELINE.json`, `252-BASELINE.md`, and `252-COMPARISON-CONTRACT.json`. Hosted evidence is draft PR #331 and run 38307191464, attempt 2; its five required contexts passed. Plan 05 evidence: `252-05-SUMMARY.md`, `252-05-MIX-CI-DIAGNOSTIC.json`, and `252-05-INTEGRATION-RECHECK.json`. Phase requirements stay unchecked until verification.
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

**Last session:** 2026-10-12T21:36:27.637Z
**Stopped at:** Completed 252-06-PLAN.md; phase verification pending
**Resume file:** None

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

- [Phase 252]: Current effective required context names determine eligibility; ruleset IDs are provenance only.
- [Phase 252]: Missing source-revision data keeps a multi-revision family at unknown timing.
- [Phase 252]: workflow_dispatch and release-branch pushes remain separate from the primary PR, main-push and schedule cohorts
- [Phase 252]: Expired, mismatched, unavailable or unsafe artifact inputs remain diagnostics and do not become timing rows
- [Phase 252]: Keep the ExUnit timing report opt-in and test-only; reporting failures preserve the original test process exit.
- [Phase 252]: Playwright JSON stays opt-in; excluded counts and unmeasured reporter overhead remain null, with CI wiring owned by Plan 252-05.
- [Phase 252]: Replay keeps rankings for initial wait, required-context critical path, execution, and summed runner time separate.
- [Phase 252]: Missing artifact identities, timestamps, cache results, and runtime versions remain unknown rather than being filled from configured pins.
- [Phase 252]: Failure signatures require repeat source references; cancellation without superseding-run evidence stays unclassified.
- [Phase 252]: The 20-pair comparison uses the measured baseline cache vector and freezes candidate identity and exact UTC dates before the first run.
- [Phase 252]: ExUnit's five-pair historical overhead is retained separately; current ExUnit paired overhead and Playwright reporter overhead remain unknown and are not subtracted.
- [Phase 252]: Hosted retry evidence and runner cost remain in the original source family; no replacement families or comparison-window extension are allowed.
