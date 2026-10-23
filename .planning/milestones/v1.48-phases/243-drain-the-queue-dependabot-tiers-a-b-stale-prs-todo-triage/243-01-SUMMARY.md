---
phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage
plan: 01
subsystem: dependencies
tags: [dependabot, github-actions, npm, mix, ci]
requires: []
provides:
  - Tier A dependency updates merged in the prescribed order with exact lock versions and CI receipts
  - Same-line version annotations preserved for attest-build-provenance pins
affects: [243-02, dependency-maintenance]
actuals:
  tokens: 1100
  tasks: 1
  commits: 0
tech-stack:
  added: []
  patterns: [PR checks refreshed against each advancing main SHA, exact main ci-gate boundary]
key-files:
  created:
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-A-EVIDENCE.json
  modified:
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-A-FAILURE.json
key-decisions:
  - "Merged only the four fixed Tier A PRs, in order, refreshing remaining PR branches as main advanced."
  - "Recorded the optional admin-eval registration URL timeout separately; required ci-gate passed on the final SHA."
patterns-established:
  - "Require fresh PR checks and a green ci-gate on main before the next dependency sequence."
requirements-completed: [QUEUE-01]
coverage:
  - id: D1
    description: Four Tier A dependency bumps are merged with their resolved lock versions verified.
    requirement: QUEUE-01
    verification:
      - kind: integration
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TIER-A-EVIDENCE.json
        status: pass
    human_judgment: false
  - id: D2
    description: Final main ci-gate passed for the resulting Tier A merge SHA.
    requirement: QUEUE-01
    verification:
      - kind: integration
        ref: https://github.com/szTheory/sigra/actions/runs/36100547128/job/107963937362
        status: pass
    human_judgment: false
duration: 110min
completed: 2026-09-25
status: complete
---

# Phase 243 Plan 01: Tier A Dependabot batch

Merged #215, #227, #228, and #220 in the planned order. The final main commit is `53d83ba50df877044fcb1350b5a58f79d766751e`, and the required `ci-gate` passed in run 36100547128 (job 107963937362).

## Accomplishments

- Merged attest-build-provenance 4.2.2 (#215), Anthropic SDK 0.123.0 (#227), zod 4.5.4 (#228), and otplib 13.5.0 (#220); verified final lockfile entries at the final main SHA.
- Preserved same-line `# v4.2.2` annotations and updated the related pin contract assertions in #215.
- Repaired the otplib v13 Playwright call sites to use the asynchronous `generate({ secret })` API.
- Recorded each PR check run, merge SHA, and exact `ci-gate` job in `243-TIER-A-EVIDENCE.json`.

## Issues Encountered

- One refreshed #228 run had an unrelated Oban supervision test failure; its single retry passed.
- An optional admin-eval probe failed on intermediate main SHA `e5d8495…` after a registration page URL timeout. Its `ci-gate` passed and the probe was outside the required gate; the result is recorded in the evidence receipt.

## Next Phase Readiness

Plan 02 can begin with Oban PR #225. Merge Tier B updates individually, waiting for a green `ci-gate` on the exact resulting main SHA after each.

---
*Phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage*
*Plan: 01*
