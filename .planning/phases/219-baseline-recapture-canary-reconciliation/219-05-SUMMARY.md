---
phase: 219-baseline-recapture-canary-reconciliation
plan: 05
subsystem: testing
tags: [ci, generated-host-parity, install-golden, playwright, workflow-dispatch]

# Dependency graph
requires:
  - phase: 219-03
    provides: authoritative workflow_dispatch recapture CI run (29051223765) on the Phase 219 branch
provides:
  - Confirmed SC-3 generated-host parity is green post-wave: install-golden byte-diff AND acceptance-smoke runtime render both succeed on the authoritative non-PR CI run
affects: [220-terminal-ratification]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "Used the existing workflow_dispatch recapture run (29051223765) as the sole authoritative source for both SC-3 halves rather than dispatching a new CI run"
  - "Did not rebless the install-golden fixture — job concluded success with no drift"

patterns-established: []

requirements-completed: [RECAP-01]

coverage:
  - id: D1
    description: "install-golden byte-diff (install_golden_contract lane) confirmed green on the Phase 219 branch's authoritative CI run — no rebless performed"
    requirement: "RECAP-01"
    verification:
      - kind: other
        ref: "gh run view 29051223765 --json jobs (job: Install golden + idempotency contract (subprocess harness)) -> success"
        status: pass
    human_judgment: false
  - id: D2
    description: "generated-host acceptance-smoke runtime render (generated_admin_playwright_smoke job) confirmed to actually execute (non-PR event) and pass on the workflow_dispatch recapture run — not a skipped conclusion"
    requirement: "RECAP-01"
    verification:
      - kind: other
        ref: "gh run view 29051223765 --json jobs (job: Generated admin Playwright smoke) -> success, event=workflow_dispatch"
        status: pass
    human_judgment: false

# Metrics
duration: 4min
completed: 2026-07-09
status: complete
---

# Phase 219 Plan 05: Generated-Host Parity Confirmation (SC-3) Summary

**Confirmed both SC-3 generated-host parity halves — install-golden byte-diff and acceptance-smoke runtime render — conclude `success` on the authoritative workflow_dispatch CI run (29051223765), with no rebless and no source changes needed.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-09T21:59:00Z
- **Completed:** 2026-07-09T22:03:00Z
- **Tasks:** 2 completed
- **Files modified:** 0 (confirm-only plan, `files_modified: []`)

## Accomplishments
- Confirmed `install_golden_contract` lane concluded `success` on run 29051223765 — the example-only icon fix (219-01) left generated-host templates untouched, matching D-08's prediction that no rebless would be needed.
- Confirmed `generated_admin_playwright_smoke` (admin-acceptance-smoke.sh, generated host's own scaffolded app) concluded `success` on the same run, which is a `workflow_dispatch` event so the stale ci.yml:1320 `if:` condition did not skip it — providing the authoritative (non-skipped) SC-3 proof required by the plan.
- Both halves of SC-3 (generated-host parity) are now proven green against the post-wave, post-recapture codebase.

## Task Commits

Both tasks were read-only confirmations against existing CI evidence — no code, template, or workflow changes were made, so no task-level commits were produced. This SUMMARY and STATE/ROADMAP updates are captured in the plan-completion metadata commit.

1. **Task 1: Confirm install-golden byte-diff is green (SC-3, D-08)** - confirm-only, no commit (verified via `gh run view 29051223765`)
2. **Task 2: Confirm generated-host acceptance-smoke runtime render is green (SC-3, D-08)** - confirm-only, no commit (verified via `gh run view 29051223765`)

**Plan metadata:** captured in the final docs commit for this plan.

## Files Created/Modified
None — this is a confirm-only plan (`files_modified: []`); no source, template, or workflow files were changed.

## Decisions Made
- Used run **29051223765** (the `workflow_dispatch` recapture run from 219-03, on branch `gsd/phase-219-baseline-recapture-canary-reconciliation`) as the single authoritative source for both SC-3 confirmations, per the orchestrator-provided run id — did not trigger a new CI run.
- No install-golden rebless was performed; the lane was already green, consistent with D-08 (wave touched no `priv/templates/**`, commit `ec4dfd12` already re-blessed the fixture for the phx_new 1.8.8 pin).
- Confirmed `generated_admin_playwright_smoke` executed (not skipped) specifically because the run's event is `workflow_dispatch`, which satisfies the stale `if:` at ci.yml:1320; a plain-PR run's `skipped` conclusion would NOT have been an acceptable SC-3 proof per the plan's explicit gating nuance.

## Deviations from Plan

None - plan executed exactly as written. Both tasks were pure confirmation reads against the pre-identified authoritative CI run; no auto-fixes, blockers, or architectural questions arose.

## Issues Encountered

None. The plan's automated verify commands (which independently re-discover the latest run via `gh run list`) were corroborated by directly inspecting run 29051223765 as identified by the orchestrator, confirming consistent results:
- `Install golden + idempotency contract (subprocess harness)` → `success`
- `Generated admin Playwright smoke` → `success`
- Run event: `workflow_dispatch` (confirms the job actually executed rather than being skipped)

Note (out of 219 scope, already tracked): the same run's `fast_checks` job is red due to a missing `cheerio` module (218-era eval infra), unrelated to install-golden or generated-host parity. Not acted on here — SC-3 is unaffected.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- SC-3 (generated-host parity) is fully confirmed green, closing out one of the phase's required success criteria ahead of Phase 220 Terminal Ratification.
- No blockers or follow-up work identified from this plan.

---
*Phase: 219-baseline-recapture-canary-reconciliation*
*Completed: 2026-07-09*
