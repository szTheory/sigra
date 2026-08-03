---
phase: 235-terminal-ratification-measured-not-read
plan: 10
subsystem: CI evidence verification
tags: [github-actions, sigstore, attestation, fast-01, performance]
requires:
  - phase: 235-09
    provides: protected FAST remeasurement producer
provides:
  - attested FAST-01 replacement measurement receipt and offline verifier
  - durable strict-miss reconciliation for FAST-01
affects: [FAST-01, GATE-05, CI performance evidence]
tech-stack:
  added: []
  patterns: [network-denied attestation verification, strict p50 miss retention]
key-files:
  created:
    - scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.json
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.attestation.jsonl
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT-TRUSTED-ROOT.jsonl
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md
key-decisions:
  - "FAST-01 remains open because protected p50 724 is not strictly below 720."
  - "GATE-05 remains independently Complete and unchanged."
requirements-completed: []
duration: 0min
completed: 2026-08-03
status: complete
---

# Phase 235 Plan 10: Protected FAST remeasurement Summary

**Attested 13-run FAST remeasurement retained a strict 724-second p50 miss while preserving GATE-05.**

## Accomplishments

- Retained and offline-verified the replacement protected subject from run `30849907303`.
- Kept FAST-01 unchecked with its exact protected miss evidence and preserved the historical 19-run/772-second miss.
- Preserved GATE-05's existing protected ownership proof.

## Task Commits

1. **Task 1: verified FAST measurement evidence** — `ee50b58c` (feat)
2. **Task 2: durable FAST miss reconciliation** — `2a7a0bab` (docs)

## Files Created/Modified

- `scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh` - network-denied FAST provenance verifier.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.json` - protected 13-run measured miss receipt.
- `.planning/REQUIREMENTS.md` - unchanged FAST requirement with protected miss evidence.

## Decisions Made

- The no-subject shallow-checkout attempt `30845588405` is diagnostic only; replacement `30849907303` is the sole verdict authority.
- 724 seconds is a miss because FAST-01 requires p50 strictly below 720 seconds.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 - Blocking producer] Added full checkout history for immutable cutoff validation.**
- **Found during:** Task 1
- **Issue:** Initial protected run could not resolve the fixed cutoff and produced no subject.
- **Fix:** Published the narrow producer recovery before the one replacement measurement.
- **Verification:** Replacement receipt attestation verifies offline.

## Issues Encountered

The initial protected dispatch `30845588405` produced no subject because a shallow checkout lacked the cutoff commit; no verdict was accepted from it.

## Self-Check

**Result:** PASSED

- Evidence files exist and receipt digest `1245a469b33af8bed185bc0ffff47612d9866c25f816fd5ae58060736149cd02` verifies with the retained bundle and trusted root.
- `MIX_ENV=test mix test test/sigra/planning/` passed with 118 tests, 0 failures, and 12 skipped.
- Both FAST and GATE-05 offline verifier commands passed.
