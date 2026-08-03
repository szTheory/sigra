---
phase: 235-terminal-ratification-measured-not-read
plan: 10
status: complete
---

# Phase 235 Plan 10: Protected FAST remeasurement summary

FAST-01 remains a verified gap: replacement protected run `30849907303` attested 13 terminal PR runs with queue-inclusive wall p50 724 seconds, which does not satisfy the unchanged strict `< 720` threshold. GATE-05 remains Complete and unchanged.

## Evidence

- Failed no-subject infrastructure attempt `30845588405` was retained as diagnostic only; it could not resolve the historical cutoff in shallow checkout.
- Recovery PRs added PR-only readiness validation, portable cutoff epoch binding, and full checkout history.
- Replacement receipt, bundle, trusted root, and network-denied adversarial verifier are retained under this phase directory.

## Verification

- `MIX_ENV=test mix test test/sigra/planning/` — 118 tests, 0 failures, 12 skipped.
- `bash scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh`
- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh`

## Task Commits

- `ee50b58c` evidence and FAST offline verifier
- `2a7a0bab` durable FAST miss reconciliation

## Deviations from Plan

- Rule 3 recovery: the original protected run had no subject because its checkout lacked the immutable cutoff commit; the verified replacement alone supplies the measured verdict.

## Self-Check: PASSED

- Receipt digest `1245a469b33af8bed185bc0ffff47612d9866c25f816fd5ae58060736149cd02` verifies against the retained bundle and trusted root.
