---
phase: 245-branch-prune-local-and-remote
plan: 14
subsystem: repository-maintenance
tags: [git, github, pull-requests, evidence, blocker]
requires:
  - phase: 245-07
    provides: strict PR identity audit and fail-closed verifier
provides:
  - Durable record that the pinned identity baseline is unavailable
  - Halted dependency disposition for Plan 245-16
affects: [phase-245-verification, REPO-04]
actuals:
  tokens: 1500
  tasks: 0
  commits: 2
tech-stack:
  added: []
  patterns: [unavailable immutable evidence source remains blocked]
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-14-BASELINE-BLOCKER.json
    - .planning/phases/245-branch-prune-local-and-remote/245-14-SUMMARY.md
  modified: []
key-decisions:
  - "Do not fabricate a baseline audit or accept an unsupported blocked receipt."
  - "Keep REPO-04 open and block dependent Plan 245-16 until an authoritative baseline is available or the plan is revised."
requirements-completed: []
coverage:
  - id: D1
    description: "The missing baseline and rejected source lookups are recorded without claiming the PR identity contract passed."
    requirement: REPO-04
    verification:
      - kind: other
        ref: "245-14-BASELINE-BLOCKER.json schema check and phase-plan-index dependency check"
        status: pass
    human_judgment: false
metrics:
  duration: 5min
  completed: 2026-09-28
  commits: 1
status: halted
---

# Phase 245 Plan 14: Pinned Baseline Unavailable

**Plan 14 halted before task execution because its required immutable baseline is missing.**

## Outcome

No task was started. Task 1's `capture-live` preflight cannot load the pinned baseline commit, and Task 2 depends on the resulting committed audit. The existing validators do not support a structurally valid blocked audit when that baseline source is absent, so no PR identity audit, integrity receipt, or API coverage matrix was created.

## Blocker evidence

- The required immutable baseline commit is recorded in the machine-readable blocker receipt.
- Local Git object lookup reported the commit missing.
- A read-only fetch from `origin` was rejected with `upload-pack: not our ref`.
- GitHub's commit endpoint returned HTTP 422, `No commit found for SHA`.
- The helper failed before capture with `fatal: not a tree object`. Its validators require the pinned baseline blobs and exact historical 11-key set. The fallback blocked receipt has no checked historical rows and fails `validate-final`.
- Independent current reads found 13 open PRs, but they cannot be bound to the required baseline and are not accepted as identity evidence.

The machine-readable details are in `245-14-BASELINE-BLOCKER.json`. No PR, ref, origin/main, or cleanup mutation occurred.

## Task Commits

No implementation task commits were made. The plan halted before Task 1. The scoped blocker receipt was recorded in `b20fef5c`; this halted summary is being committed separately.

## Plan and phase status

- **Tasks:** 0/2; halted before Task 1.
- **Plan 245-16:** blocked by this halted plan and not executed.
- **Plan 245-15:** executed independently; its 30 cleanup-history rows remain unknown and aggregate truth remains unresolved.
- **REPO-04:** remains open.

To resume this identity gap, restore the exact baseline commit from a trusted source or replan the contract around a newly approved immutable baseline. No audit pass is claimed.

## Self-Check: PASSED

- The blocker receipt records the unavailable source and validator limitation.
- The plan index recognizes this summary as halted and records Plan 245-16 as dependent on Plan 245-14.
