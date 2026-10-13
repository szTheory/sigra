---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 05
subsystem: testing
tags: [playwright, execution-records, native-reports]
requires: [{phase: 253-04, provides: stable selected body ids}]
provides: [five-seam record validator, source selection inventory matching, bounded producer writer]
affects: [253-06, 253-07]
key-files:
  created: [scripts/ci/ci-browser-records.mjs, scripts/ci/ci-browser-records.test.mjs]
tech-stack: {added: [], patterns: [separate producer directories, native selection-to-result comparison]}
requirements-covered: [CIREL-02]
requirements-completed: []
coverage:
  - id: D1
    description: Exactly five producers and complete native selected results are necessary
    verification: [{kind: integration, ref: "node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs", status: pass}]
    human_judgment: false
status: complete
completed: 2026-10-13
actuals: {tasks: 2, commits: 4}
---

# Plan 253-05 Summary

The dependency-free CLI requires five exact seam directories, source/run/attempt/event/workflow identities, native successful outcomes, and complete nonempty native reports matching their pre-execution test inventory. Successful records cannot override native matrix failure.

## Accomplishments

- Validates actual workflow body selections, report hashes and exact native selected test identities through the existing normalizer.
- Accounts for design-gallery authentication setup dependencies and rejects missing, duplicate, unknown, byte-variant, malformed, changed-source, skipped-full-body, cancelled and masked-failure inputs.
- Docs-only body skips require actual PR, successful classifier and exact true; producer writer copies only selected native JSON files, avoiding auth-state uploads.
- Thirty-four contracts pass, including producer roundtrip, native omission/retry/failure controls, report/selection mismatch and symlink/traversal controls.

## Task Commits

| Task | RED | GREEN |
|---|---|---|
| 1 | 0be786753 | 189535006 |
| 2 | 2488f43fd | 15ec8fec4c |

## TDD Gate Compliance

Both real CLI targets failed on intended absent behavior before implementation and produced RED_EVIDENCE_OK with unchanged TAP and semantic assessment records.

## Deviations from Plan

Added native pre-execution selection JSON as an explicit required input. A report's internally consistent counts alone cannot prove it includes the complete selected test set. Plan 06 must generate those inventories with the same locked command before execution.

## Issues Encountered

Native report paths are relative to the Playwright test directory, while workflow paths include tests/. The validator accepts precisely those two forms. Design-gallery reports also include configured authentication setup projects.

## Self-Check: PASSED

All deliverable files and scoped commits exist, and fresh contracts pass. Workflow integration and hosted origin proof remain pending; CIREL-02 remains open.
