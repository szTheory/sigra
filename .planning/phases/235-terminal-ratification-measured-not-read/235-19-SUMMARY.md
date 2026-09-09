---
phase: 235-terminal-ratification-measured-not-read
plan: 19
subsystem: ci-verification
tags: [bash, jq, exunit, provenance, metrics]

requires:
  - phase: 235-18
    provides: Authenticated source-complete FAST-01 retained subject and offline verifier
provides:
  - Literal terminal-conclusion parity between the source-first oracle and ci-run-metrics.sh
  - Hermetic semantic-fixture entry point sharing the production validator
  - Verifier-level success, failure, cancelled, ordering, median, threshold, and argument coverage
affects: [phase-235-verification, FAST-01, GATE-05]

actuals:
  tokens: 4983
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns: [single shared jq semantic validator, explicit hermetic CLI fixture seam]

key-files:
  created: []
  modified:
    - scripts/ci/verify-fast-01-source-complete-attestation-offline.sh
    - test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs

key-decisions:
  - "Preserve terminal conclusions literally with the same group_by/map/from_entries aggregation used by ci-run-metrics.sh."
  - "Keep fixture mode explicit and provenance-free while routing both fixture and authenticated paths through one semantic validator."

patterns-established:
  - "Complete-statistics equality: derive the oracle statistics object once and compare it exactly at both retained statistics locations."
  - "CLI seam isolation: malformed fixture arguments fail before any provenance or retained-subject processing."

requirements-completed: [FAST-01, GATE-05]

coverage:
  - id: D1
    description: "The source-first oracle retains success, failure, and cancelled as distinct literal outcome keys and compares complete statistics exactly."
    requirement: FAST-01
    verification:
      - kind: integration
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs#semantic fixture preserves literal conclusions and strict wall semantics"
        status: pass
      - kind: other
        ref: "bash scripts/ci/ci-run-metrics.test.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Authenticated FAST-01 provenance and independent protected 93-row GATE-05 evidence remain green and byte-stable."
    requirement: GATE-05
    verification:
      - kind: integration
        ref: "bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/verify-terminal-ratification-attestation-offline.sh"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs#completed ownership proof and contributor topology remain immutable"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-09-09
status: complete
---

# Phase 235 Plan 19: Literal Terminal-Outcome Parity Summary

**A shared source-first validator now preserves every literal terminal conclusion, rejects lossy outcome maps, and keeps authenticated FAST-01 and protected GATE-05 proof independently green.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-09-09T15:25:22Z
- **Completed:** 2026-09-09T15:32:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced success/non-success bucketing with the authoritative literal-conclusion grouping used by `ci-run-metrics.sh`.
- Added an explicit `--semantic-fixture PATH` seam that shares production semantic logic while remaining isolated from provenance processing.
- Proved distinct success/failure/cancelled counts, stable equal-duration run ordering, floor median, strict `<720`, full statistics equality, and collapsed-map rejection.
- Re-ran authenticated FAST-01, metrics self-tests, independent GATE-05 verification, and immutable digest guards without changing retained evidence.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing literal-outcome verifier contract** - `cc20a10a` (test)
2. **Task 1 GREEN: Preserve literal terminal outcomes** - `30d465b8` (fix)
3. **Task 2: Lock verifier path separation** - `59696e4b` (test)

## Files Created/Modified

- `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` - Shared literal-outcome semantic validator and isolated fixture argument path.
- `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` - Multi-conclusion positive/adverse fixture coverage and authenticated-path separation guards.

## Decisions Made

- Used the instrument's literal `group_by(.conclusion) | map(...) | from_entries` expression verbatim in semantics, with no aliases or synthesized buckets.
- Constructed one complete oracle statistics object and compared it directly with both top-level and instrument-output statistics.
- Kept fixture mode before retained-input and provenance setup, while default zero-argument execution continues through all fixed digest, trusted-root, workflow, and source-ref checks.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Task 2's new regression assertions began green because the fixture seam and strict parser were necessarily delivered by Task 1; the test locks that behavior without adding a second implementation.

## Verification

- `bash scripts/ci/ci-run-metrics.test.sh` — 11 passed, 0 failed.
- `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` — `source_complete_offline_attestation_verified`.
- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` — `offline_attestation_verified`.
- `ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` — 16 tests, 0 failures.
- `git diff --check -- scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` — clean.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The sole Phase 235 verifier gap is closed and ready for phase re-verification.
- No retained evidence, closeout record, CI topology, pending todo, product code, package, schema, GATE-05 proof, or unrelated review finding changed.

## Self-Check: PASSED

- Both modified tracked files exist.
- Task commits `cc20a10a`, `30d465b8`, and `59696e4b` exist in history.
- Protected GATE-05 artifact, receipt, attestation, trusted root, verifier, and contributor digests remain exactly pinned.

---
*Phase: 235-terminal-ratification-measured-not-read*
*Completed: 2026-09-09*
