---
phase: 219-baseline-recapture-canary-reconciliation
plan: 04
subsystem: testing
tags: [playwright, snapshot-testing, ci, canary-guard, admin-ui]

# Dependency graph
requires:
  - phase: 219-baseline-recapture-canary-reconciliation
    provides: "219-03 branch-scoped recapture landed 115 amd64-native baseline PNGs + canary delete-reborn as 'added'"
provides:
  - "Confirmed proof that both snapshot allowlists (admin-checkpoints, admin-design) are at empty steady-state (SC-2)"
  - "Confirmed proof that snapshot-canary-guard.sh exits zero on a clean re-run for both lanes against the post-recapture HEAD"
affects: [220-ship-planning, snapshot-canary-reconciliation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Confirm-only verification plan: no code changes when the invariant already holds post-recapture; task success is proven via automated verify commands, not new commits"

key-files:
  created: []
  modified: []

key-decisions:
  - "No file changes required — both allowlists were already at D-07 empty steady-state after 219-02/03 landed the recapture via runtime --allow flags rather than committed allowlist entries, exactly as designed"
  - "No task-level commit created since Task 1 made zero file changes (files already matched required state) and Task 2 is a verification-only guard run; work is captured in this plan-completion commit"

patterns-established: []

requirements-completed: [RECAP-01]

coverage:
  - id: D1
    description: "Both snapshot allowlists (admin-checkpoints, admin-design) confirmed at empty steady-state — 0 active non-comment, non-blank lines, header comments preserved, neither canary slug present"
    requirement: "RECAP-01"
    verification:
      - kind: automated_ui
        ref: "scripts/ci/snapshot-canary-guard.sh allowlist-active-line-count check (test/example/priv/playwright/snapshot-allowlist, snapshot-allowlist-design)"
        status: pass
    human_judgment: false
  - id: D2
    description: "snapshot-canary-guard.sh exits zero on a clean re-run for both the admin-checkpoints lane (--canary impersonation-banner) and admin-design lane (--canary board-notice) against post-recapture HEAD, with 0 changed slugs"
    requirement: "RECAP-01"
    verification:
      - kind: automated_ui
        ref: "bash scripts/ci/snapshot-canary-guard.sh --base HEAD"
        status: pass
      - kind: automated_ui
        ref: "SNAP_DIR=test/example/priv/playwright/tests/admin-design.spec.ts-snapshots bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist test/example/priv/playwright/snapshot-allowlist-design --canary board-notice"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-07-09
status: complete
---

# Phase 219 Plan 04: Allowlist Reconciliation to Empty Steady-State Summary

**Confirmed both snapshot allowlists are at D-07 empty steady-state and proved snapshot-canary-guard.sh exits zero on a clean re-run for both admin-checkpoints and admin-design lanes against the post-recapture HEAD — 0 changed slugs, no PNG diff, SC-2 satisfied.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-09T21:55:00Z
- **Completed:** 2026-07-09T22:00:00Z
- **Tasks:** 2 completed
- **Files modified:** 0 (confirm-only plan; both allowlists already matched required state)

## Accomplishments
- Verified `test/example/priv/playwright/snapshot-allowlist` (admin-checkpoints lane) has 0 active non-comment, non-blank lines — comment-only steady-state, header preserved including "The `impersonation-banner` canary must NEVER appear here."
- Verified `test/example/priv/playwright/snapshot-allowlist-design` (admin-design lane) has 0 active non-comment, non-blank lines — comment-only steady-state, header preserved including "The `board-notice` canary must NEVER appear here."
- Ran `scripts/ci/snapshot-canary-guard.sh --base HEAD` for the admin-checkpoints lane (default `SNAP_DIR`, default `--canary impersonation-banner`, default allowlist) — exited 0 with `PASS (0 changed slug(s), all within allowlist)`.
- Ran the same guard for the admin-design lane (`SNAP_DIR=test/example/priv/playwright/tests/admin-design.spec.ts-snapshots`, `--allowlist snapshot-allowlist-design`, `--canary board-notice`) against `--base HEAD` — exited 0 with `PASS (0 changed slug(s), all within allowlist)`.
- Confirmed neither canary slug (`board-notice`, `impersonation-banner`) appears as an active line in either allowlist, satisfying D-06's "canary must never be allowlistable" invariant in the committed manifest.

## Task Commits

No task-level commits — both tasks were confirm/verify-only against the already-satisfied post-219-03 state:

1. **Task 1: Reset both allowlists to empty steady-state (D-07)** — no changes needed; verified 0 active lines in both files via the plan's automated check.
2. **Task 2: Prove the canary drift guard exits zero on a clean re-run for both lanes (SC-2)** — no changes needed; ran `scripts/ci/snapshot-canary-guard.sh` for both lanes against `--base HEAD`, both exited 0.

**Plan metadata:** committed with this SUMMARY.md (docs commit).

## Files Created/Modified
None — the recapture landed in 219-02/03 via the guard's runtime `--allow` flags (not committed allowlist entries), exactly as D-07 designed, so both allowlist files already carried zero active slug lines when this plan began. This plan's job was to confirm and prove that invariant, which it did with no code changes.

## Decisions Made
- No file changes required — both allowlists were already at D-07 empty steady-state; the recapture path (219-02/03) intentionally used the jobs' runtime `--allow` flags instead of committed allowlist entries, so there was nothing to reset.
- No per-task commit created since neither task produced a file diff; the plan-completion metadata commit is the sole commit for this plan.

## Deviations from Plan

None - plan executed exactly as written. Both tasks were confirm/verify-only by design (per the orchestrator-verified context supplied at dispatch), and both verifications passed on the first attempt with no red guard runs and no allowlist edits.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SC-2 is proven: both allowlists at empty steady-state, guard green on both lanes against post-recapture HEAD.
- Phase 219's branch-level goal (recapture + guard reconciliation) is now fully achieved by this plan plus 219-01/02/03.
- **Handoff to Phase 220 (recorded in 219-04-PLAN.md, not a Phase 219 task):** the 219→main merge will re-trigger the canary/guard deadlock — the PR diff will show all 115 slugs including both canaries (`board-notice`, `impersonation-banner`) as `modified` vs main's old darwin baselines, which is hard-forbidden with no allowlist escape hatch. Phase 220's ship planner MUST choose a reconciliation strategy before executing the milestone-ship PR (e.g., accept the recaptured canaries as the new baseline at the merge boundary, or run the guard post-merge against the new main baseline). Not addressed here per the plan's explicit scope boundary.
- Plan 05 (final phase plan) can proceed.

---
*Phase: 219-baseline-recapture-canary-reconciliation*
*Completed: 2026-07-09*

## Self-Check: PASSED
