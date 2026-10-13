---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 06
subsystem: infra
tags: [github-actions, browser-records]
requires: [{phase: 253-03, provides: unit gate ownership}, {phase: 253-04, provides: exact body inventory}, {phase: 253-05, provides: native record validator}]
provides: [five producer artifacts and native aggregate validation]
affects: [253-07, 253-08]
key-files:
  modified: [.github/workflows/ci.yml, scripts/ci/ci-measure-workflow.test.mjs, scripts/ci/ci-playwright-report.test.mjs]
tech-stack: {added: [], patterns: [same-run separate artifact intake]}
requirements-covered: [CIREL-02]
requirements-completed: []
coverage:
  - id: D1
    description: All native browser selections and producer outcomes reach the aggregate
    verification: [{kind: integration, ref: "node --test scripts/ci/ci-measure-workflow.test.mjs scripts/ci/ci-browser-records.test.mjs", status: pass}]
    human_judgment: false
status: complete
completed: 2026-10-13
actuals: {tasks: 2, commits: 4}
---

# Plan 253-06 Summary

Each of five producers retains its selected native step outcomes, pre-execution inventory and native report in a unique seam/run/attempt artifact. The mandatory aggregate downloads separate directories and requires native matrix success plus complete validator coverage. Docs-only exemptions use actual successful PR classification.

## Accomplishments

- Seven existing execution selections remain intact; seven native list-only invocations capture expected tests before execution.
- Record/upload steps run narrowly after terminal outcomes and retain expected record files with error-on-absence.
- Reused existing pinned upload/download/checkout actions with unchanged ordinary permissions, required names, worker/retry policy and job timeouts.
- Fifty-seven combined integration/parity/report contracts, 21 verdict checks, five no-retry controls and actionlint pass.

## Task Commits

| Task | RED | GREEN |
|---|---|---|
| 1 | a87e635db | a44a49ba6 |
| 2 | efaa57161 | 9b27d48d31 |


Canonical task commit rows for scope checking (no acceptance status change):

1. **Task 1: producer records and artifacts** — RED `a87e635db`, GREEN `a44a49ba6`.
2. **Task 2: mandatory aggregate intake** — RED `efaa57161`, GREEN `9b27d48d31`.

## TDD Gate Compliance

Both actual-workflow target assertions failed before implementation and their unchanged TAP reports produced RED_EVIDENCE_OK. Missing record/artifact/inventory and falsely hard-coded native success source fixtures fail the wiring guard.

## Deviations from Plan

The existing native reporter test now counts seven execution commands separately from seven required list-only inventories, preserving its original selection and zero-retry assertions. The first hook call used the wrong `query` prefix. The supported `check ui.safety-gate 253 --raw` returns frontend=false, hasUiFiles=false and block=false. Its initial no-task-commit-rows warning came from the table format in these summaries; canonical rows were added during closeout. The direct roadmap check also returned hasUI=false. No UI is in this phase.

## Issues Encountered

A textual test counted list-only commands as extra execution; updated assertions distinguish the commands by their opt-in native result reporter. Hosted action behavior remains unproved until plan 07.

## Self-Check: PASSED

Scoped commits and artifacts exist and fresh automated checks pass. Plan 07 is ready; plan 08 remains blocked by halted registration plan 02.
