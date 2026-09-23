---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 03
subsystem: ci
tags: [ci, node-test, documentation, prohibition-guard, honest-skip]
requires:
  - phase: 230-tier-1-critical-path-reclamation
    provides: honest-skip manifest, p10 ownership guard, and CI prohibition convention
provides:
  - Offline p21 parity guard for MAINTAINING.md's honest-skip topology
  - Fail-first fixture and reproducible RED/GREEN evidence
  - Corrected manifest citations and a scoped follow-up todo
affects: [ci-prohibitions, MAINTAINING.md, skip-manifest, phase-241-verification]
tech-stack:
  added: []
  patterns:
    - "One substitutable subject with committed real-location secondary artifacts"
    - "Delegation contracts prevent duplicated parity-check ownership"
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
  - "p21 owns only MAINTAINING.md parity and machine-checks p10's ownership of the three ci.yml legs."
  - "Gate-expression semantics and ci-gate.needs membership remain unasserted by design."
  - "The inaccurate example_playwright_smoke gate-level row is a scoped pending todo, not an unmeasured cell edit."
requirements-completed: [DEBT-03]
coverage:
  - id: D1
    description: "p21 detects stale honest-skip documentation and preserves the real RED as a fixture."
    requirement: DEBT-03
    verification:
      - kind: unit
        ref: "scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs"
        status: pass
      - kind: unit
        ref: "GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p21-maintaining-stale-topology.md node --test scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both manifest copies cite the real p21 guard and the full prohibition suite remains green."
    requirement: DEBT-03
    verification:
      - kind: integration
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs"
        status: pass
    human_judgment: false
actuals:
  tokens: 5171
  tasks: 3
  commits: 3
plan_head_before: bcd8108ec00190fd80bc2796df184edc4866097d
duration: 12h 8m
completed: 2026-09-23
status: complete
---

# Phase 241 Plan 03: Honest-skip parity guard Summary

**An offline p21 guard now proves MAINTAINING.md names every honest-skip manifest construct, with a committed real-rot fixture and corrected CI topology prose.**

## Performance

- **Duration:** 12h 8m
- **Started:** 2026-09-23T02:02:57Z
- **Completed:** 2026-09-23T12:31:30Z
- **Tasks:** 3/3
- **Files modified:** 7

## Accomplishments

- Added p21 as the CI-globbed, offline-only MAINTAINING.md parity leg, including a non-vacuity floor and a machine-checked p10 delegation contract.
- Observed and committed a genuine RED before correcting the documentation; `example_playwright_shard` was absent from the actual honest-skip section as both the missing manifest job and the missing step parent.
- Corrected all five stale topology claims, preserved the pre-correction section as a permanent RED fixture, repaired two stale manifest citations, and recorded the remaining manifest-cell discrepancy as pending work.

## Verification

- `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p21-maintaining-stale-topology.md node --test scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs` — expected RED naming `example_playwright_shard`.
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 96 passed, 0 failed.
- `mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` — 7 passed, 0 failed.
- Confirmed the merge-base diff contains no `.github/workflows/ci.yml` or `mix.exs` edit.

## Task Commits

1. **Task 1: write p21 and commit the genuine RED** — `03ff9eef` (`test`)
2. **Task 2: correct the doc and add the known-bad fixture** — `e7ac65bc` (`docs`)
3. **Task 3: retire stale citations and record dispositions** — `8e1212ad` (`docs`)

## Files Created/Modified

- `scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs` — offline doc-parity guard with p10 delegation contract.
- `MAINTAINING.md` — corrected shard parent, display names, aggregator details, docs-only topology, and backstop text.
- `test/fixtures/prohibitions/p21-maintaining-stale-topology.md` — permanent pre-correction RED subject.
- `.github/ci-skip-manifest.tsv` and `test/fixtures/prohibitions/p10-manifest-stale-entry.tsv` — point their two header citations at p21.
- `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-03-EVIDENCE.md` — commands, RED/GREEN results, and scoped dispositions.
- `.planning/todos/pending/2026-09-23-example-playwright-smoke-manifest-gate-level-is-inaccurate.md` — pending follow-up for the intentionally unasserted gate-level discrepancy.

## Decisions Made

- p21 delegates id resolution, step-parent, and display-name parity to p10 and fails if that ownership disappears.
- p21 does not evaluate the manifest gate column or assert `ci-gate.needs`; those boundaries prevent a brittle second workflow-expression evaluator and preserve FUT-03 as separately tracked work.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Hardened p21's honest-skip section locator at end of file.**

- **Found during:** Task 3
- **Issue:** The initial fallback used a non-JavaScript end anchor, which could make a subject ending immediately after the honest-skip section appear unlocated.
- **Fix:** Located the heading first and bounded the section at the next level-four heading when present, otherwise retaining the remainder of the subject.
- **Files modified:** `scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs`
- **Verification:** Real document GREEN; committed stale fixture still RED; full prohibition suite passed.
- **Committed in:** `8e1212ad`

**Total deviations:** 1 auto-fixed (Rule 1).

## Issues Encountered

The initial scoped Mix invocation was blocked by sandbox-local PubSub socket permissions. One authorized retry ran the same deterministic command successfully (7 tests, 0 failures); no code or test result was waived.

## Known Stubs

None.

## Next Phase Readiness

The p21 guard and evidence are ready for Phase 241 verification. The incorrect `example_playwright_smoke` manifest gate-level representation is explicitly retained as pending work rather than silently changed without a dedicated measurement.

## Self-Check: PASSED

All five created artifacts exist, and task commits `03ff9eef`, `e7ac65bc`, and `8e1212ad` are present in the repository log.
