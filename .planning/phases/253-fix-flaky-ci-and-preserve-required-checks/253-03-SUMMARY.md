---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 03
subsystem: infra
tags: [github-actions, required-checks]
requires: []
provides: [unit smoke internal gate ownership]
affects: [253-06, 253-07]
key-files:
  modified: [.github/workflows/ci.yml, scripts/ci/honest-skip-verdict.sh, scripts/ci/honest-skip-verdict.test.sh]
tech-stack: {added: [], patterns: [fixed lane ownership]}
requirements-covered: [CIREL-02]
requirements-completed: []
coverage:
  - id: D1
    description: Unit dependency and result paths are required by the native verdict
    verification: [{kind: integration, ref: "bash scripts/ci/honest-skip-verdict.test.sh", status: pass}]
    human_judgment: false
status: complete
completed: 2026-10-13
actuals: {tasks: 2, commits: 4}
---

# Plan 253-03 Summary

ci-gate now owns Example unit smoke in its dependency, both environment maps, verdict arguments and legacy result loop. Missing, failed, cancelled and skipped unit jobs fail. Docs-only skips remain body skips inside successful jobs; the five required names are unchanged.

## Accomplishments

- Fixed lane set increased to ten and is checked against workflow needs.
- Dropping the unit result argument or either environment map fails ownership validation.
- 21 shell checks and three actual-verdict unit contracts pass.

## Task Commits

| Task | RED | GREEN |
|---|---|---|
| 1 | 91018cd82 | b4eb2f7ed |
| 2 | 2c64bcdbe | b0ab759baa |


Canonical task commit rows for scope checking (no acceptance status change):

1. **Task 1: unit gate ownership** — RED `91018cd82`, GREEN `b4eb2f7ed`.
2. **Task 2: unit failure controls** — RED `2c64bcdbe`, GREEN `b0ab759baa`.

## TDD Gate Compliance

Both intended target assertions failed before implementation and produced RED_EVIDENCE_OK. Reports preserve the native outputs and semantic assessments.

## Deviations from Plan

A skipped unit job remains invalid even for docs-only PRs because its documented exemption applies to the body, and the required job must still conclude success. The repository lacks scripts/ci_monitor.cjs; hosted operations use the project-authorized GitHub CLI discipline when needed.

## Issues Encountered

The old missing-lane fixture also omitted unit smoke after the fixed set expanded; it was updated to continue testing its original missing generated-admin lane.

## Self-Check: PASSED

Scoped commits are reachable, deliverable files exist and fresh verdict checks pass. Hosted gate proof and full CIREL-02 completion remain pending.
