---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 02
subsystem: testing
tags: [exunit, ci-topology, fail-first, contract-test, evidence]
requires:
  - phase: 241-01
    provides: ADR 004's exactly-one-full-library-suite-owner guarantee
provides:
  - Runtime-resolved, fail-closed ExUnit contract for the library suite owner
  - Committed two-owner YAML fixture with attributable RED evidence
  - Retired phase_233 remediation-receipt dependency while preserving live receipt readers
affects: [DEBT-02, mix-ci, phase-235-receipts]
tech-stack:
  added: []
  patterns: [runtime environment subject injection, committed known-bad fixture, derived CI invariant]
key-files:
  created:
    - test/fixtures/prohibitions/phase241-library-economics-two-owners.yml
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-02-EVIDENCE.md
  modified:
    - test/sigra/planning/phase_233_library_economics_contract_test.exs
key-decisions:
  - "Resolve SIGRA_CONTRACT_SUBJECT at function call time so an already-compiled test cannot silently use the default subject."
  - "Keep the archived remediation JSON because its collector and Phase 235 contract are live readers; retire only phase_233's stale self-digest assertions."
patterns-established:
  - "Fail-first output must name a runtime-generated assertion phrase not present contiguously in source, so compile errors cannot fake attribution."
requirements-completed: [DEBT-02]
actuals:
  tokens: 4025
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 29e6a612db8b0ce07b9e63d0ff6a00d7fe561f2c
duration: 5min
completed: 2026-09-19
status: complete
coverage:
  - id: D1
    description: Derived, single-owner library-suite contract rejects a committed two-owner workflow while passing the real CI workflow.
    requirement: DEBT-02
    verification:
      - kind: unit
        ref: bash -c SIGRA_CONTRACT_SUBJECT fixture RED attribution plus real-subject ExUnit GREEN
        status: pass
    human_judgment: false
  - id: D2
    description: The retired receipt dependency leaves the archived JSON and its other live readers operational.
    requirement: DEBT-02
    verification:
      - kind: unit
        ref: MIX_ENV=test compile warnings-as-errors plus Phase 233 and Phase 235 receipt-reader tests
        status: pass
    human_judgment: false
---

# Phase 241 Plan 02: Single-owner library-suite contract Summary

**A runtime-injected ExUnit contract now derives the one-full-library-suite-owner invariant, proves it RED against a committed two-owner CI fixture, and retires the stale self-digest receipt checks.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-09-19T15:39:32Z
- **Completed:** 2026-09-19T15:44:49Z
- **Tasks:** 3/3
- **Files modified:** 3

## Accomplishments

- Added `SIGRA_CONTRACT_SUBJECT` runtime resolution with a missing-subject broken-run failure and a derived non-vacuous `library_tests*` universe.
- Committed a structurally faithful two-owner workflow fixture; its RED contains `more than one owner of the full library suite`, and the real workflow is GREEN.
- Removed phase_233's stale remediation receipt assertions, attribute, and four private helpers while preserving the archived JSON and validating both remaining readers.

## Task Commits

1. **Task 1: End-to-end — substitutable subject, derived invariant, RED on a committed fixture** — `e29b9275` (test)
2. **Task 2: Finish the rewrite and retire the receipt dependency with its helpers** — `cd7b3cb6` (test)
3. **Task 3: Record the SC-2 evidence and the retired-receipt disposition** — `46a8b245` (docs)

## Files Created/Modified

- `test/sigra/planning/phase_233_library_economics_contract_test.exs` — derives owner and no-bare-test properties from one runtime-resolved subject; no stale receipt helpers remain.
- `test/fixtures/prohibitions/phase241-library-economics-two-owners.yml` — committed known-bad CI shape with two full-suite owners.
- `241-02-EVIDENCE.md` — reproducible RED, GREEN, missing-subject, compile, and receipt-retirement evidence.

## Decisions Made

- ADR 004's guarantee is asserted as a property of whichever workflow subject is selected, never as a hardcoded job-list snapshot.
- The replacement failure phrase is assembled at runtime, so a compiler error echoing source cannot satisfy the RED attribution grep.
- The `235-FAST-01-REMEDIATION.json` archive remains because the live collector checks its digests at the immutable cutoff, not at HEAD.

## Verification

- RED/Green: the documented `bash -c` fixture proof produced `4 tests, 1 failure` with the required attributable message, then `4 tests, 0 failures` against `.github/workflows/ci.yml`.
- Missing subject: the documented `bash -c` proof failed with `a missing subject is a broken run, never an absent violation`.
- `bash -c 'MIX_ENV=test mix compile --warnings-as-errors'` passed.
- Phase 233 plus the two surviving Phase 235 receipt-reader contract files: `28 tests, 0 failures`.
- The original test 4 body is byte-identical to the pre-plan version; no `mix.exs` or workflow topology changes were introduced.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

DEBT-02 is ready for deterministic phase verification. The archived FAST-01 receipt remains available to its live collector and Phase 235 contract without phase_233 retaining a stale self-digest dependency.

## Self-Check: PASSED

- Confirmed the rewritten contract, committed fixture, evidence file, and this summary exist.
- Confirmed task commits `e29b9275`, `cd7b3cb6`, and `46a8b245` resolve to commits.
