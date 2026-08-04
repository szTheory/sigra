---
phase: 230-tier-1-critical-path-reclamation
plan: 04
subsystem: infra
tags: [github-actions, ci, concurrency, workflow-yaml]

# Dependency graph
requires:
  - phase: 230-03
    provides: "design_gallery/design_gallery_snapshots split and seam-outcome aggregator wiring in ci.yml"
provides:
  - "admin_eval_render demoted to push/schedule/workflow_dispatch only via a job-level if:, removing ~17m33s from every PR"
  - "top-level concurrency: block giving PR runs supersession (cancel-in-progress) while every non-PR event sits in a group of one"
affects: [230-09, 231]

# Tech tracking
tech-stack:
  added: []
  patterns: ["job-level if: github.event_name != 'pull_request' non-PR gating (house pattern, now 8 sites)", "workflow-level concurrency group keyed on PR number || run_id"]

key-files:
  created: []
  modified: [.github/workflows/ci.yml]

key-decisions:
  - "D-10: single-line if: github.event_name != 'pull_request' on admin_eval_render, continue-on-error: true left byte-unchanged (GATE-04 is Phase 231's scope, not this plan's)"
  - "D-12/D-13: concurrency group keys non-PR events on github.run_id (unique per run, structurally never queued/cancelled) rather than SEED-005's github.ref + conditional cancel-in-progress, because cancel-in-progress: false still queues and would compound the release lane's 30-minute gate-ci-green ceiling"
  - "D-06: no trigger-level path filtering added; on: block's key set and push/pull_request child-key set are unchanged"

requirements-completed: [FAST-03, FAST-04]

coverage:
  - id: D1
    description: "admin_eval_render demoted to non-PR events (if: github.event_name != 'pull_request'), continue-on-error retained, comment rewritten"
    requirement: "FAST-03"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml && python3 YAML assertion script (job.if, continue-on-error, ci-gate.needs absence, generated_admin_playwright_smoke.if unchanged, continue-on-error count == 3)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Top-level concurrency: block (PR-number-or-run_id group, cancel-in-progress: true bare boolean) added after permissions:, no trigger-level path filtering introduced"
    requirement: "FAST-04"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml && python3 YAML assertion script (on: key sets, concurrency.cancel-in-progress is True, concurrency.group contents, permissions:/concurrency: line ordering)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Observed on-CI proof that admin_eval_render reports skipped on a PR run and executes on a non-PR run, and that a superseded PR run is cancelled while push/schedule/dispatch runs are never queued or cancelled"
    requirement: "FAST-03, FAST-04"
    verification: []
    human_judgment: true
    rationale: "This plan's acceptance criteria require observing real gh run view/gh run list conclusions across an AFTER-PR run, an AFTER-PUSH or dispatch run, and an AFTER-CANCEL two-push probe. Those runs are captured by plan 230-09 (the phase's evidence-capture plan), not by this plan in isolation — this plan only ships and statically verifies the YAML that makes those observations possible."

# Metrics
duration: ~12min
completed: 2026-07-28
status: complete
---

# Phase 230 Plan 04: Demote admin_eval_render + add concurrency Summary

**Single job-level `if:` demotes `admin_eval_render` off the PR lane (17m33s/PR), and a single workflow-level `concurrency:` block makes superseded PR runs cancel while every push/schedule/dispatch run sits in a structurally-unqueueable group of one.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-07-28T20:13:54-04:00
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `admin_eval_render` now carries `if: github.event_name != 'pull_request'` — PRs no longer pay for a job that gates nothing (not in `ci-gate.needs`, not a ruleset context); render evidence for a PR branch is now obtained via `workflow_dispatch` on that ref
- The job's `continue-on-error: true` was left byte-unchanged, and its stale "not gated to non-PR events" comment was rewritten to state the new demotion, the measured 17m33s saving, and the explicit GATE-04/Phase 231 deferral for actually fixing the two underlying harness defects
- Added a top-level `concurrency:` block (`group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}`, `cancel-in-progress: true`) placed after `permissions:`, matching the placement already used by `release-please.yml`, `playwright-github-pages.yml`, and `hex-publish.yml`
- No trigger-level `paths:`/`paths-ignore:` filtering was introduced (D-06) — the `on:` block's key set and the `push`/`pull_request` child-key sets (`branches` only) are unchanged, so all five ruleset-required contexts still resolve on every PR

## Task Commits

Each task was committed atomically:

1. **Task 1: Demote admin_eval_render to non-PR events (FAST-03)** - `39443cf3` (feat)
2. **Task 2: Add workflow-level run supersession (FAST-04)** - `4c10418c` (feat)

_No TDD tasks in this plan._

## Files Created/Modified
- `.github/workflows/ci.yml` - Added `if: github.event_name != 'pull_request'` to `admin_eval_render`'s job header with a rewritten Phase 230 (FAST-03) comment; added a top-level `concurrency:` block with a Phase 230 (FAST-04) comment recording the D-12/D-13/D-14 rationale

## Decisions Made
- Followed the plan's literal `if:` form exactly — it matches the house pattern already used at 7 other sites in the file (now 8, including this one), keeping the non-PR-gating idiom consistent.
- Followed the plan's literal concurrency `group:`/`cancel-in-progress:` expression exactly, including the explicit rejection rationale for SEED-005's `github.ref` + conditional `cancel-in-progress` form (queueing risk against the release lane's 30-minute `gate-ci-green` ceiling), recorded inline as a comment so a future reader does not reintroduce the rejected form.
- No deviations from the plan's specified action beyond the literal text — both edits are exactly the one-line `if:` and the three-line `concurrency:` block the plan specifies.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both tasks' automated `<verify>` commands (actionlint + YAML-parse assertions) passed on the first attempt, and `mix test test/sigra/planning/` matched the documented pre-change baseline (50 tests, 0 failures, 12 skipped) after each task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `admin_eval_render`'s demotion and the new `concurrency:` block are ready for the on-CI observation plan 230-09 must capture: an AFTER-PR run showing `admin_eval_render` as `skipped` (<5s), an AFTER-PUSH/dispatch run showing it non-skipped (>900s), and an AFTER-CANCEL two-push probe showing the earlier run `cancelled` and the later run completing.
- `continue-on-error: true` on `admin_eval_render` is intact and unambiguously deferred to Phase 231's GATE-04 — this plan does not claim the lane's two underlying defects are fixed, only that the lane's cost is no longer charged to every PR.
- No blockers for the remaining Wave 3+ plans (230-05 onward), which also edit `ci.yml`; this plan's diff is scoped to exactly the one job-level `if:` and the one top-level `concurrency:` block specified.

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-28*

## Self-Check: PASSED

- FOUND: `.planning/phases/230-tier-1-critical-path-reclamation/230-04-SUMMARY.md`
- FOUND: commit `39443cf3` (Task 1)
- FOUND: commit `4c10418c` (Task 2)
- FOUND: commit `a5947eb7` (this SUMMARY)
