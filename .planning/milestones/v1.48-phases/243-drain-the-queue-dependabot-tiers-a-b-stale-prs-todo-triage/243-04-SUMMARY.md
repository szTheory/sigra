---
phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage
plan: 04
subsystem: planning
tags: [todos, triage, evidence]
requires: []
provides:
  - Frozen 66-item pending-todo inventory with one reasoned disposition each
  - Corrected or added FUT-01 through FUT-05 records, including adjacent CI gaps
  - Todo-only triage commit with machine-readable validation
affects: [243-closeout, future-milestones]
actuals:
  tokens: 1600
  tasks: 3
  commits: 1
tech-stack:
  added: []
  patterns: [frozen path and content fingerprints, conservative keep without owner completion proof]
key-files:
  created:
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TODO-INVENTORY.json
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TODO-TRIAGE-VALIDATION.json
    - .planning/todos/pending/2026-09-25-fut-02-dependabot-groups-policy.md
    - .planning/todos/pending/2026-09-25-fut-04-launch-pack-contract-caller.md
  modified:
    - .planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md
    - .planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md
key-decisions:
  - "Keep all 66 frozen pending records open because no direct owner completion receipts were supplied."
  - "Keep Dependabot groups as backlog policy work; do not change .github/dependabot.yml."
patterns-established:
  - "Do not infer completion from resolves_phase metadata or resolved-sounding text."
requirements-completed: [QUEUE-04]
coverage:
  - id: D1
    description: Every todo pending at plan start has one keep/close/defer disposition, reason, and fingerprint.
    requirement: QUEUE-04
    verification:
      - kind: other
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TODO-INVENTORY.json
        status: pass
    human_judgment: false
  - id: D2
    description: Required future records exist without implementing their contents.
    requirement: QUEUE-04
    verification:
      - kind: other
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-TODO-TRIAGE-VALIDATION.json
        status: pass
    human_judgment: false
  - id: D3
    description: Todo changes were committed in a todo-only commit.
    requirement: QUEUE-04
    verification:
      - kind: other
        ref: 8750c986d20200219c52702a8023692d9209de03
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-09-25
status: complete
---

# Phase 243 Plan 04: Todo triage

Froze the 66 Markdown todos present in `.planning/todos/pending/` at plan start, including each path's SHA-256, and assigned all 66 a reasoned `keep` disposition. Thirteen records identify an earlier `resolves_phase` owner; they remain open pending direct owner completion evidence.

## Accomplishments

- Added an exact inventory and validation receipt covering count, unique paths, hashes, one disposition per input, and todo-only commit scope.
- Reused the existing FUT-01, FUT-03, and FUT-05 records; corrected FUT-03 and FUT-05 titles and updated FUT-05's target GA to the repository's current 1.5.0.
- Added FUT-02 for Dependabot grouping policy and FUT-04 for the uncalled launch-pack contract script.
- Verified `example_unit_smoke` remains absent from `ci-gate.needs` and no workflow calls `launch-pack-contract.sh`.
- Committed exactly four todo paths in `8750c986d20200219c52702a8023692d9209de03`. No todo issue was fixed, no PR was closed, and `.github/dependabot.yml` was unchanged.

## Issues Encountered

- No owner-supplied completion evidence was available to close any frozen item, so all remain open. Two required future records were missing and were added.

## Next Phase Readiness

Plan 04 is complete. Phase 243 is complete: Tier B passed its ordered gates, and Plan 03 recorded seven individual closures plus the retained #219 Phase 248 carryover.

---
*Phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage*
*Plan: 04*
