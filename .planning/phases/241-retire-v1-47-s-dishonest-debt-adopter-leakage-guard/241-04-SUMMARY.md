---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 04
subsystem: testing
tags: [github-actions, supply-chain, exunit, contract-tests]
requires:
  - phase: 234
    provides: action-pinning contract and immutable-reference validation
provides:
  - Separate composite-action manifest discovery for the action-pinning guard
  - Optional-dash uses inventory parsing with independently attributable fixtures
  - Numeric action-inventory floor and reproducible RED/GREEN evidence
affects: [DEBT-04, composite-actions, GitHub Actions, supply-chain]
tech-stack:
  added: []
  patterns: [function-resolved known-bad subject, committed fixture RED evidence, numeric inventory floor]
key-files:
  created:
    - test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml
    - test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-04-EVIDENCE.md
  modified:
    - test/sigra/planning/phase_234_action_pinning_contract_test.exs
    - .planning/todos/pending/2026-09-15-composite-action-outside-supply-chain-guards.md
key-decisions:
  - "D-18: Preserve the exactly-two release workflow universe and the correct local ./ action exemption; discover composite actions separately."
  - "D-19: Make the dash optional in the inventory regex and prove the bare-uses blind spot with its own fixture."
  - "D-20/D-21: Use committed subject-injected fixtures instead of mutating the live composite action or using git stash."
actuals:
  tokens: 7812
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 82b40bfeb8fe44e0850651bb6f5e439762b86171
requirements-completed: [DEBT-04]
coverage:
  - id: D1
    description: Composite action references, including bare uses entries, are pinned and version annotated.
    requirement: DEBT-04
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_234_action_pinning_contract_test.exs
        status: pass
      - kind: other
        ref: 241-04-EVIDENCE.md fixture RED/GREEN transcripts
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-09-19
status: complete
---

# Phase 241 Plan 04: Composite action pinning guard Summary

**The action-pinning guard now discovers composite manifests independently, validates both dashed and bare uses entries, and proves each protection with a committed known-bad fixture.**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-09-19T15:22:38Z
- **Tasks:** 3/3
- **Files modified:** 6

## Accomplishments

- Added a separate, non-vacuous `Path.wildcard(".github/actions/*/action.yml")` universe while leaving the exactly-two release-workflow universe and local-action exemption intact.
- Relaxed the inventory regex to support optional dashes, then proved the old pattern cannot see a floating bare `uses:` reference while the relaxed pattern rejects it.
- Added separate bare and dashed fixtures: each produces a failure containing its fixture path and the guard’s own `has non-immutable action ref` diagnostic; the real tree passes with 16 inventory entries.
- Recorded reproducible evidence, retained the live action file unchanged, and marked only the pin-guard half of the pending todo partially closed.

## Task Commits

1. **Task 1: End-to-end composite universe and bare-reference proof** — `0a590a16` (`feat`)
2. **Task 2: Independent dashed fixture and numeric inventory floor** — `1e0c3417` (`test`)
3. **Task 3: Evidence and pending-todo annotation** — `5b332e1c` (`docs`)

## Files Created/Modified

- `test/sigra/planning/phase_234_action_pinning_contract_test.exs` — scans the distinct composite universe, accepts bare entries, establishes a 16-entry floor, and tests the pre/post regex behavior.
- `test/fixtures/prohibitions/phase241-composite-unpinned-{bare-uses,dashed-uses}.yml` — independent real-shape known-bad composite action fixtures.
- `241-04-EVIDENCE.md` — reproducible fixture REDs, real-tree GREEN, regex negative control, and count transcript.
- `2026-09-15-composite-action-outside-supply-chain-guards.md` — remains pending with an explicit partial-close disposition.

## Decisions Made

- Kept `@release_workflows` exactly two entries; composite manifests are a separate discovery universe so the existing release-scope contract remains meaningful.
- Used `SIGRA_CONTRACT_SUBJECT` inside a function, not a module attribute, so a process-level fixture override reaches the real production inventory path.
- Set the floor to the execution-head measured 16 entries (9 under the pre-relaxation parser plus 7 newly visible references).
- Did not add a Dependabot directory entry or claim coverage for `ci.yml` action pins; both remain explicitly out of scope.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

None. The fixture REDs were intentionally nonzero and accepted only after the commands also matched both the fixture path and the guard’s own expected diagnostic.

## Next Phase Readiness

DEBT-04 is mechanically covered with durable two-direction evidence. The pending todo retains the separately authorized Dependabot work, and `ci.yml` pin coverage remains an acknowledged future surface.

## Self-Check: PASSED

- Confirmed both committed fixtures, the evidence file, and this summary exist.
- Confirmed task commits `0a590a16`, `1e0c3417`, and `5b332e1c` exist in git history.
