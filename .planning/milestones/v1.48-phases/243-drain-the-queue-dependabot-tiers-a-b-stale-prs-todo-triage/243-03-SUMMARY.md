---
phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage
plan: 03
subsystem: repository-operations
tags: [github, pull-requests, evidence]
requires: []
provides:
  - Evidence-based dispositions for the eight frozen PR candidates
  - Public reasons for seven fulfilled, superseded, or parked closures
  - Active Phase 248 PR #219 retained as carryover
  - All eight head branches preserved
affects: [phase-245-branch-prune, stale-pr-review]
actuals:
  tokens: 900
  tasks: 1
  commits: 0
tech-stack:
  added: []
  patterns: [reconcile frozen identities individually; close with evidence and retain refs]
key-files:
  created:
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json
    - .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-03-REPLAN.md
  modified:
    - .planning/REQUIREMENTS.md
key-decisions:
  - "Superseded, parked, and fulfilled requests were closed individually after checking their exact heads and evidence."
  - "Keep #219 open as active Phase 248 carryover; do not delete any branch."
patterns-established:
  - "Freeze each candidate identity, verify its exact evidence, publish its disposition, and read back state/head after closure."
requirements-completed: [QUEUE-03]
coverage:
  - id: D1
    description: All eight frozen candidate identities have evidence-based dispositions.
    requirement: QUEUE-03
    verification:
      - kind: integration
        ref: .planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json
        status: pass
    human_judgment: false
  - id: D2
    description: Seven closed PRs retain their head branches; active #219 remains open.
    requirement: QUEUE-03
    verification:
      - kind: external
        ref: https://github.com/szTheory/sigra/pull/211
        status: pass
      - kind: external
        ref: https://github.com/szTheory/sigra/pull/219
        status: pass
    human_judgment: false
duration: 20min
completed: 2026-09-25
status: complete
---

# Phase 243 Plan 03: evidence-based stale PR dispositions

Seven candidates were closed with individual public reasons after verifying the exact request and its superseding or completion evidence: #211, #172, #124, #174, #234, #261, and #254. The exact PR heads are recorded in `243-STALE-PR-EVIDENCE.json`.

#219 remains open as the active draft Phase 248 Android proof lane. All eight remote branches were confirmed to still exist at their frozen head SHAs. No branch was deleted.

The amendment in `243-03-REPLAN.md` replaces the original all-eight-stale stop rule with individually evidenced dispositions, as authorized by the project owner.
