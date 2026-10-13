---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 04
subsystem: infra
tags: [skip-inventory, github-actions]
requires: []
provides: [exact selected-body inventory, verified PR body eligibility]
affects: [253-05, 253-06, 253-07]
key-files:
  modified: [.github/workflows/ci.yml, .github/ci-skip-manifest.tsv, MAINTAINING.md, scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs, scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs]
tech-stack: {added: [], patterns: [exact body condition parity]}
requirements-covered: [CIREL-02]
requirements-completed: []
coverage:
  - id: D1
    description: Actual six selected browser steps match manifest and active notes
    verification: [{kind: unit, ref: "node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs", status: pass}]
    human_judgment: false
status: complete
completed: 2026-10-13
actuals: {tasks: 2, commits: 4}
---

# Plan 253-04 Summary

The skip inventory names the actual selected browser steps rather than the always-run aggregate. Browser bodies skip only for an actual PR with a successful classifier and exactly true output. Six steps serve five producers, including separate PR/non-PR design-gallery bodies.

## Accomplishments

- Added stable IDs and exact two-way body/condition parity; retained populated floors.
- Updated active maintainer IDs and documented mandatory aggregate and classifier eligibility.
- Sixteen parity tests and the 21-check unit gate regression pass; malformed aggregate, stale/missing body, changed condition, duplicate/stale documentation and unverified classification are exercised.

## Task Commits

| Task | RED | GREEN |
|---|---|---|
| 1 | acdfd5ce9 | 56992d70f |
| 2 | bc812ddd5 | 78bc6ce015 |

## TDD Gate Compliance

The initial default Node reporter was unsupported and rejected as INVALID_RED. Its original bytes remain in 253-04-TASK1-RED.json. The unchanged target rerun with TAP was accepted as RED_EVIDENCE_OK, as was Task 2's classifier assertion.

## Deviations from Plan

Stable workflow IDs were absent for four actual body steps, so they were added here to make the inventory resolvable, ahead of plan 06. Tightening body eligibility also touched the workflow. Neither change alters selection, retries, workers, required names or protection rules.

## Issues Encountered

The old active-id notes still listed library_tests_dep_off despite its existing removal; regenerated IDs now exactly match the real manifest. Hosted classification proof remains pending, including a real docs-only PR since eligibility changed.

## Self-Check: PASSED

Scoped production commits are reachable; the exact source parity and unit regression pass. Full requirement acceptance remains pending.
