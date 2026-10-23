---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 03
subsystem: ci guard integrity
tags: [node-test, github-actions, documentation, fail-first]
requires:
  - phase: 241-01
    provides: sequential Phase 241 execution baseline
provides:
  - Offline p21 parity guard with fail-first subject injection
  - Corrected honest-skip topology and permanent stale-document fixture
  - Accurate manifest citations and a deferred manifest-row disposition
affects: [CI guard maintenance, MAINTAINING.md, skip manifest]
tech-stack:
  added: []
  patterns: [floor-before-property, delegated guard ownership, committed known-bad fixture]
key-files:
  created:
    - scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs
    - test/fixtures/prohibitions/p21-maintaining-stale-topology.md
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-03-EVIDENCE.md
  modified:
    - MAINTAINING.md
    - .github/ci-skip-manifest.tsv
    - test/fixtures/prohibitions/p10-manifest-stale-entry.tsv
key-decisions:
  - "p21 owns MAINTAINING.md parity only; p10 remains the single owner of ci.yml id, parent, and display-name legs."
  - "Gate expressions and ci-gate.needs membership remain deliberately unasserted to avoid false scope expansion."
  - "The inaccurate example_playwright_smoke step-gate manifest row is recorded as a pending todo, not silently changed."
requirements-completed: [DEBT-03]
actuals:
  tokens: 5638
  tasks: 3
  commits: 4
commits: 4
plan_head_before: ed029b65d81a684aaa839ff99e68636415abc740
duration: 12min
completed: 2026-09-19
status: complete
---

# Phase 241 Plan 03: Honest-skip parity guard Summary

**An offline, fail-first p21 guard now keeps the manifest's honest-skip entries and MAINTAINING.md topology in sync, with permanent RED and GREEN evidence.**

## Accomplishments

- Added `p21-honest-skip-parity.test.mjs`, with numeric and section-location floors, explicit p10 delegation checks, and independent id and step-parent documentation checks.
- Captured p21 RED against the committed stale documentation before correcting the five topology claims; the pre-correction fixture continues to RED through `GSD_PROHIB_SUBJECT` while the real document is GREEN.
- Replaced both nonexistent manifest citations, including the p10 fixture copy, and recorded the deferred aggregator gate-row discrepancy as a pending todo.

## Verification

- `bash -c 'GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p21-maintaining-stale-topology.md node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs'` REDs with both the missing `example_playwright_shard` id and its missing step-parent condition.
- `bash -c 'node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs'` passed: 97 tests, 0 failures.
- `bash -c 'mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs'` passed: 7 tests, 0 failures.
- `bash -c 'test -z "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- .github/workflows/ci.yml mix.exs)'` passed: no workflow or `mix ci` topology edit.

## Task Commits

1. `ffc23579` — `test(241-03): add red honest-skip parity guard`
2. `f1e3563b` — `docs(241-03): correct honest-skip topology`
3. `6c6c1e42` — `docs(241-03): cite the honest-skip guard`

## Decisions Made

- p21 delegates the three existing ci.yml parity legs to p10 and machine-checks that those p10 test names survive.
- The real document uses the actual shard, step name, aggregator name, and docs-only log text; the aggregator is no longer described as step-gated.
- The manifest's `example_playwright_smoke` gate-row inaccuracy remains an explicit pending follow-up because fixing it would activate an unmeasured p10 branch.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made both known stale-topology sub-checks independently observable.**
- **Found during:** Task 2
- **Issue:** A fail-fast id assertion prevented the subsequent step-parent assertion from appearing in the same RED output.
- **Fix:** Split id and step-parent parity into independent tests; the permanent fixture now REDs both conditions.
- **Files modified:** `scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs`
- **Commit:** `7d35d79b`

**2. [Rule 2 - Missing required disposition] Filed the explicitly required pending todo for the unasserted manifest row.**
- **Found during:** Task 3
- **Issue:** The plan requires the known `example_playwright_smoke` gate-row discrepancy to be filed rather than silently left in the evidence record.
- **Fix:** Added a scoped pending todo that records why neither p10 nor p21 may change it in this plan.
- **Files modified:** `.planning/todos/pending/2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md`
- **Commit:** `6c6c1e42`

## Known Stubs

None.

## Self-Check: PASSED

- Required guard, stale-topology fixture, and evidence ledger exist.
- All four task-related commits exist in reachable history.
- No tracked-file deletions were introduced.

## Next Phase Readiness

The honest-skip claim is now mechanically enforced without a workflow edit. The pending todo isolates the remaining gate-level modeling question for a separately measured follow-up.
