---
phase: 235
slug: terminal-ratification-measured-not-read
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-02
updated: 2026-08-03
---

# Phase 235 — Validation Strategy

> Retrospective Nyquist audit of the completed terminal-ratification phase.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5, Bash contract tests, `jq`, `actionlint`, and offline Sigstore verification |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Focused command** | `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` |
| **Evidence command** | Run `V2` through `V9` below; each is deterministic and network-free |
| **Full suite command** | `MIX_ENV=test mix test test/sigra/planning/` plus `V2` through `V9` |
| **Measured focused runtime** | 1.0 seconds on the 2026-08-03 validation audit; 29 tests, 0 failures |

## Verification Commands

| ID | Automated command | Audit result |
|----|-------------------|--------------|
| V1 | `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ 29 tests, 0 failures |
| V2 | `bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.test.sh` | ✅ `offline_fast_01_gap_closure_attestation_verified` |
| V3 | `bash scripts/ci/verify-terminal-ratification-attestation-offline.test.sh` | ✅ `offline_attestation_verified` |
| V4 | `bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | ✅ positive subject and adverse mutations verified |
| V5 | `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` | ✅ positive subject and adverse mutations verified |
| V6 | `bash scripts/ci/capture-fast-01-gap-closure.test.sh` | ✅ PASS |
| V7 | `bash scripts/ci/capture-fast-01-remeasurement.test.sh` | ✅ PASS |
| V8 | `bash scripts/ci/capture-terminal-ratification-evidence.test.sh` | ✅ PASS |
| V9 | `bash scripts/ci/ci-run-metrics.test.sh` | ✅ 9 passed, 0 failed |

Expected Sigstore errors printed by V4 and V5 are assertions from adverse fixtures; both commands exit zero only after the retained positive subject passes. ExUnit may log local PostgreSQL connection failures during application startup, but these planning contracts are filesystem-backed and completed with zero failures.

---

## Requirement Coverage

| Requirement | Automated evidence | Status |
|-------------|--------------------|--------|
| FAST-01 | V1, V2, V4, V6, V7, V9 independently validate the protected n=15 population, canonical wall p50=486 seconds, strict `< 720` comparator, immutable receipt provenance, collector behavior, and historical measurement semantics. | ✅ COVERED |
| GATE-05 | V1, V3, V5, and V8 validate the protected 93-row before/after ownership ledger, direct receivers, PR/push/schedule topology, immutable receipts, and hostile-environment staging. | ✅ COVERED |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Automated evidence | Status |
|---------|------|------|-------------|--------------------|--------|
| 235-01-01 | 01 | 1 | FAST-01, GATE-05 | V1, V9 | ✅ green |
| 235-01-02 | 01 | 1 | FAST-01, GATE-05 | V1 | ✅ green |
| 235-02-01 | 02 | 2 | FAST-01, GATE-05 | V1, V8, V9 | ✅ green |
| 235-02-02 | 02 | 2 | FAST-01 | V1, V9 | ✅ green |
| 235-03-01 | 03 | 3 | GATE-05 | V1 | ✅ green |
| 235-03-02 | 03 | 3 | FAST-01, GATE-05 | V1, V9 | ✅ green |
| 235-04-01 | 04 | 4 | FAST-01 | V1, V9 | ✅ green |
| 235-04-02 | 04 | 4 | GATE-05 | V1 | ✅ green |
| 235-04-03 | 04 | 4 | GATE-05 | V1 | ✅ green |
| 235-05-01 | 05 | 5 | FAST-01 | V1, V9 | ✅ green |
| 235-05-02 | 05 | 5 | FAST-01 | V1, V9 | ✅ green |
| 235-05-03 | 05 | 5 | GATE-05 | V1 | ✅ green |
| 235-06-01 | 06 | 6 | FAST-01 | V1, V9 | ✅ green |
| 235-06-02 | 06 | 6 | FAST-01 | V1, V9 | ✅ green |
| 235-06-03 | 06 | 6 | GATE-05 | V1, V5 | ✅ green |
| 235-07-01 | 07 | 7 | FAST-01, GATE-05 | V1, V8 | ✅ green |
| 235-07-02 | 07 | 7 | FAST-01, GATE-05 | V1, V8 | ✅ green |
| 235-08-01 | 08 | 8 | FAST-01, GATE-05 | V3, V5, V8 | ✅ green |
| 235-08-02 | 08 | 8 | FAST-01, GATE-05 | V3, V5, V8 | ✅ green |
| 235-08-03 | 08 | 8 | FAST-01, GATE-05 | V1, V5, V8, V9 | ✅ green |
| 235-09-01 | 09 | 9 | FAST-01 | V1, V7, V9 | ✅ green |
| 235-09-02 | 09 | 9 | FAST-01 | V1, V7 | ✅ green |
| 235-10-01 | 10 | 10 | FAST-01 | V1, V7 | ✅ green |
| 235-10-02 | 10 | 10 | FAST-01, GATE-05 | V1, V5 | ✅ green |
| 235-11-01 | 11 | 11 | GATE-05 | V1, V5 | ✅ green |
| 235-11-02 | 11 | 11 | FAST-01 | V1, V5 | ✅ green |
| 235-12-01 | 12 | 12 | FAST-01 | V1, V6, V7, V9 | ✅ green |
| 235-12-02 | 12 | 12 | FAST-01 | V1, V6 | ✅ green |
| 235-13-01 | 13 | 13 | FAST-01 | V1, V2, V4, V6 | ✅ green |
| 235-13-02 | 13 | 13 | FAST-01, GATE-05 | V1, V4, V5 | ✅ green |
| 235-14-01 | 14 | 14 | FAST-01 | V1, V2, V4 | ✅ green |
| 235-14-02 | 14 | 14 | FAST-01, GATE-05 | V1, V2, V3, V4, V5 | ✅ green |

Every one of the 32 executed tasks has a deterministic automated command. No three-task sampling gap exists.

---

## Manual-Only Verifications

None. Protected GitHub evidence is retained as immutable, offline-verifiable receipts. Insufficient populations, rate-limit exhaustion, malformed provenance, and hostile caller state fail closed through automated contracts rather than manual approval.

---

## Validation Sign-Off

- [x] All tasks have automated verification.
- [x] Both phase requirements map to behavior-targeting tests that run green.
- [x] Sampling continuity has no three consecutive tasks without automated verification.
- [x] Wave 0 artifacts and test references exist.
- [x] No watch-mode flags or sleep-based waits are used.
- [x] Focused feedback latency is measured and bounded.
- [x] `nyquist_compliant: true` is set.

**Approval:** validated automatically on 2026-08-03

## Validation Audit 2026-08-03

| Metric | Count |
|--------|-------|
| Requirement gaps found | 0 |
| Resolved with new tests | 0 |
| Escalated | 0 |
| Existing automated checks rerun | 9 |
| Focused tests passed | 29 |

The prior draft mapped only the first three tasks. This audit reconstructed all fourteen plans and thirty-two tasks from their PLAN/SUMMARY artifacts, cross-referenced them to the current tests, and confirmed complete executable coverage. No implementation or test-file change was required.
