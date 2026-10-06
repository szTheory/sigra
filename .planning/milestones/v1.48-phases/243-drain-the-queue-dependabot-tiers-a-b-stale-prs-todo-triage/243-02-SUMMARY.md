---
phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage
plan: 02
subsystem: dependencies
tags: [dependabot, mix, npm, github-actions, ci]
requires:
  - phase: 243-plan-01
    provides: completed Tier A batch and green exact-main gate
provides:
  - Six verified Tier B merges with ordered PR and exact-main gate receipts
  - Root cause and repair evidence for the #230 cached-build regression
  - Resolved #216 dependency manifest conflict while preserving main's SDK update
  - Final Tier B exact-main green gate
  - #213 carryover preserved for Phase 244
affects: [243-closeout, dependency-maintenance]
actuals:
  tokens: 2800
  tasks: 1
  commits: 0
tech-stack:
  added: []
  patterns: [one Tier B merge per green exact-main ci-gate boundary]
key-files:
  created: []
  modified:
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-B-EVIDENCE.json
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-B-FAILURE.json
key-decisions:
  - "Kept the strict Tier B order and waited for each exact-main ci-gate before starting the next PR."
  - "Fixed #230's missing Threadline forwarder by isolating the canonical _build cache and forcing a full compile after dep-off restoration; no unrelated source changes."
  - "Kept the Hackney 4.7 override because Threadline 0.9.0 still declares optional Hackney ~> 1.18 and tzdata supports the remediation."
  - "Rebased #216 onto current main, preserving @anthropic-ai/sdk ^0.123.0 and applying @axe-core/playwright 4.13.0."
  - "Retained #213 untouched for Phase 244; no new Credo findings required todos."
patterns-established:
  - "Every Tier B merge requires its own exact-main ci-gate receipt before advancing."
requirements-completed: [QUEUE-01]
coverage:
  - id: D1
    description: Six Tier B updates were merged in fixed order with green PR and exact-main gates, and resulting lock versions match PR titles.
    requirement: QUEUE-01
    verification:
      - kind: integration
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-B-EVIDENCE.json
        status: pass
      - kind: github-actions
        ref: https://github.com/szTheory/sigra/actions/runs/36146050540/job/108110274367
        status: pass
    human_judgment: false
  - id: D2
    description: Threadline dep-off job and Hackney override disposition were verified; #213 remains untouched.
    requirement: QUEUE-01
    verification:
      - kind: integration
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-B-EVIDENCE.json
        status: pass
    human_judgment: false
  - id: D3
    description: #230 cached _build failure was diagnosed and fixed, then exact PR and main evidence passed.
    requirement: QUEUE-01
    verification:
      - kind: integration
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-B-FAILURE.json
        status: pass
    human_judgment: false
duration: 6h45min
completed: 2026-09-25
status: complete
---

# Phase 243 Plan 02: Tier B dependency sequence

All six Tier B updates were merged individually in the required order. Each PR passed its refreshed exact-head `ci-gate`, and each resulting main commit passed its exact-SHA `ci-gate` before the next PR began. Locked versions were checked against PR titles after merge. Final exact-main boundary: commit `fed35a4a3725d217486f45a571421dbbf5721765`, CI run `36146050540`, `ci-gate` job `108110274367` succeeded. The broader main workflow remains in flight for its non-gate admin-evaluation and baseline jobs; no required gate is outstanding.

## Accomplishments

- #225 Oban 2.24.1 merged as `99bbc049`; PR run 36101658778 and main run 36102312917 passed.
- #229 Hammer 7.5.0 merged as `ff0e174`; PR run 36102465443 and main run 36103019375 passed.
- #230 Flop Phoenix 0.26.3 merged as `86c35bf`; after diagnosing the stale `_build` cache could reuse a Sigra build without its conditional Threadline forwarder, the dep-off cleanup was changed to force-compile after restoring the dependency and the library cache namespace was isolated. Exact-head run 36139268651 and main `ci-gate` job 108091102331 passed. The separate main install-matrix checksum mismatch on Phoenix 1.8.15 did not recur on subsequent runs.
- #226 Threadline 0.9.0 merged as `caf3d05`; exact-head `ci-gate` and `library_tests_dep_off` passed. The full main run 36141801875 concluded success. Hackney 4.7 remains pinned because Threadline's published optional metadata still says `~> 1.18`; retaining the supported remediated 4.7.4 override is necessary for resolution.
- #183 Credo 1.7.19 required an up-to-date branch refresh and merged as `170ff25`; exact-head run 36142803112 passed and exact-main run 36143764959 concluded success, including the previously observed non-gate admin-eval job.
- #216 Axe Playwright 4.13.0 conflicted with later main changes to the same package manifests. The PR was rebased on current main, retaining main's Anthropic SDK `^0.123.0` and updating Axe to `^4.13.0`; the lockfile was regenerated. Its diff stayed limited to those package/lock entries. Exact-head run 36145084408 passed and it merged as `fed35a4`; exact-main `ci-gate` job 108110274367 passed in run 36146050540.
- #213 remains open and untouched for Phase 244. No unrelated Credo findings were fixed.

## Failure and transient-signal handling

- The original #230 failure was caused by a broad legacy cache restore key reusing a build without the optional forwarder beam. Both cache isolation and full dep-off recompilation are now in main.
- Four install-matrix jobs and the separate admin-eval job failed on main run 36140299176. The Phoenix registry checksum mismatch passed on the next main run; admin-eval passed in subsequent full runs 36141801875 and 36143764959. These non-reproducing signals are recorded; no unrelated changes were made.

## Next Phase Readiness

Plan 02 is complete. Phase 243's remaining plans are complete and its UAT receipts pass. Keep #213 for its separate Phase 244 baseline-drift decision.

---
*Phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage*
*Plan: 02*
