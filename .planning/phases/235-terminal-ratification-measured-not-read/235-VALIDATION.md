---
phase: 235
slug: terminal-ratification-measured-not-read
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-02
revised: 2026-09-09
---

# Phase 235 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5 plus Bash contract tests |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/capture-fast-01-gap-closure.test.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` |
| **Full suite command** | `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh && bash scripts/ci/verify-terminal-ratification-attestation-offline.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/` |
| **Estimated runtime** | Measured during execution; no sleep-based allowance |

---

## Sampling Rate

- **After every task commit:** Run the focused Phase 235 ExUnit contract and `bash scripts/ci/ci-run-metrics.test.sh`.
- **Plan 16 Task 1:** Run the exact combined metrics/collector/source-complete/GATE-isolation command declared in `235-16-PLAN.md`; it covers the authoritative metrics source seam, raw pages, miss-branch job/step pages, and comparison oracle.
- **Plan 16 Task 2:** Run the exact protected-main ancestry and seven-file blob comparison declared in `235-16-PLAN.md`; no dispatch is permitted in this sampling point.
- **Plan 17 Task 1:** Run the preflight receipt jq gate and focused ExUnit contract before presenting protected-main identity/blob equality, readiness, REST budget/reset facts, workflow identity, protected SHA, UTC boundary, and bounded pre-dispatch projection at the decision checkpoint.
- **Plan 17 Task 3:** After the immediately preceding authorization, dispatch as the first external mutation, validate the finalized durable correlation receipt before the sole watcher, then run both offline verifiers, source-complete subject predicates, and focused ExUnit contracts exactly as declared in `235-17-PLAN.md`.
- **Plan 18 Tasks 1–2:** Run both offline verifiers plus the applicable FAST/GATE focused contracts before requirement/residual reconciliation, then run the complete planning suite after SEED-005 and CI-PERF synchronization.
- **Plan 19 Task 1:** Run the focused source-complete ExUnit contract; it drives success, failure, and cancelled through the production-shared semantic fixture path, rejects lossy outcome aggregation, and rechecks the authenticated default path.
- **Plan 19 Task 2:** Run the metrics self-test, authenticated FAST-01 verifier, independent GATE-05 verifier, and focused source-complete ExUnit contract together, followed by the scoped whitespace check.
- **After every plan wave:** Run `MIX_ENV=test mix test test/sigra/planning/` plus JSON parse validation for the terminal artifact.
- **Before `$gsd-verify-work`:** Run `MIX_ENV=test mix ci` and the metrics self-test; both must be green.
- **Max feedback latency:** Record actual focused-test duration during Wave 0 and keep every subsequent sample within that deterministic bound.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 235-01-01 | 01 | 1 | FAST-01, GATE-05 | T-235-01 | Reject malformed, stale, duplicate, unowned, non-executable, or receiptless evidence without exposing credentials. | ExUnit contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ | ✅ green |
| 235-01-02 | 01 | 1 | FAST-01 | T-235-02 | Preserve immutable cutoff, real run IDs, exact commands, wall-mode semantics, and honest pass/miss output. | Bash + ExUnit contract | `bash scripts/ci/ci-run-metrics.test.sh && MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ | ✅ green |
| 235-02-01 | 02 | 2 | FAST-01, GATE-05 | T-235-03 | Contributor and closeout claims must be derived from the terminal ledger and live workflow topology. | ExUnit contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ | ✅ green |
| 235-16-01 | 16 | 10 | FAST-01, GATE-05 | T-235-16-01/02/07 | The mandated metrics script owns membership/statistics; raw source and median/maximum job-step pages permit independent comparison and preserve GATE-05. | Bash + ExUnit | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/capture-fast-01-gap-closure.test.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ | ✅ green |
| 235-16-02 | 16 | 10 | FAST-01, GATE-05 | T-235-16-04 | Exact tested metrics/collector/workflow/verifier/contract blobs reach protected main before dispatch. | Git blob check | `git diff --exit-code 2e77218678dfc5a0bc57c5e23afbfd46d6c1016d 158aca14b11de13cbc5ab2fdea1bff790cc7ab29 -- scripts/ci/ci-run-metrics.sh scripts/ci/ci-run-metrics.test.sh scripts/ci/capture-fast-01-gap-closure.sh scripts/ci/capture-fast-01-gap-closure.test.sh .github/workflows/fast-01-gap-closure-evidence.yml scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | ✅ | ✅ green |
| 235-17-01 | 17 | 11 | FAST-01, GATE-05 | T-235-17-01/06 | A reversible preflight retains and validates protected-main identity/blob equality, authoritative readiness, REST budget/reset state, workflow identity, UTC boundary, and the bounded pre-dispatch projection before authorization. | jq + ExUnit | `jq -e '.schema_version == "sigra.fast-01-dispatch-correlation/1" and .status == "dispatched" and .candidate_count == 1' .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | ✅ | ✅ green |
| 235-17-03 | 17 | 11 | FAST-01, GATE-05 | T-235-17-01/02/03/05/06 | Dispatch is the first external mutation after the checkpoint; a durable singleton correlation receipt precedes one watcher; signed source plus instrument output and miss poles verify offline; GATE-05 stays exact. | Bash + jq + ExUnit | `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh && bash scripts/ci/verify-terminal-ratification-attestation-offline.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ | ✅ green |
| 235-18-01 | 18 | 12 | FAST-01, GATE-05 | T-235-18-01/02/04 | Requirement and residual reconciliation branches only on authenticated metrics-script output after independent comparison and complete pole linkage. | Offline verifier + ExUnit | `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh && bash scripts/ci/verify-terminal-ratification-attestation-offline.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ✅ | ✅ green |
| 235-18-02 | 18 | 12 | FAST-01, GATE-05 | T-235-18-03/04 | SEED-005 and CI-PERF agree with the authenticated pass/miss branch while all historical FAST facts and GATE-05 remain exact. | Offline verifier + ExUnit | `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh && bash scripts/ci/verify-terminal-ratification-attestation-offline.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/` | ✅ | ✅ green |
| 235-19-01 | 19 | 13 | FAST-01 | T-235-19-01/02/03 | The production-shared source-first validator preserves literal success, failure, and cancelled outcomes, requires complete statistics equality, rejects collapsed outcomes, and preserves stable ordering, floor median, and strict threshold behavior. | Bash verifier seam + ExUnit | `ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | ✅ | ✅ green |
| 235-19-02 | 19 | 13 | FAST-01, GATE-05 | T-235-19-03/04 | The authenticated n=52/p50=469 FAST-01 path and independent protected 93-row GATE-05 proof remain green with exact digest and contributor-topology guards. | Bash + ExUnit integration | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh && bash scripts/ci/verify-terminal-ratification-attestation-offline.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs && git diff --check -- scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — validates the terminal ledger, Phase 234 inventory consumption, complete before/after ownership coverage, live workflow seams, receipt provenance, and documentation/closeout congruence.
- [x] `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` — provides the machine-readable source of truth with explicit schema, cutoff, window, rows, receipts, and verdict fields.
- [x] `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` — validates the source/instrument/pole/correlation contract, authenticated result, strict reconciliation, and GATE-05 non-regression.

---

## Manual-Only Verifications

All phase behaviors use committed contracts, GitHub CLI automation, structured run receipts, and deterministic repository checks. If fewer than ten eligible post-cutoff PR runs exist, execution must stop at a durable evidence checkpoint rather than substitute manual approval or synthetic runs.

---

## Validation Sign-Off

- [x] All executable tasks have `<automated>` verification or Wave 0 dependencies; Plan 17's verified reversible preflight precedes the blocking-human decision checkpoint, and the one-way task begins with the single dispatch as its first external mutation.
- [x] Sampling continuity: every executable task has a deterministic command; Plan 17's decision checkpoint is followed by a retained, contract-checked singleton dispatch receipt.
- [x] Wave 0 covers every formerly missing reference and all referenced files exist.
- [x] No watch-mode flags or sleep-based waits occur in local validation; the one external workflow watcher used the required 60-second interval and is retained in `235-17-SUMMARY.md`.
- [x] Focused feedback is deterministic: the 2026-09-09 audit ran 45 focused tests in 0.8 seconds and the complete planning suite in 11.3 seconds.
- [x] `nyquist_compliant: true` reflects observed green automated coverage, not planned intent.

**Approval:** validated — FAST-01 and GATE-05 are covered by passing behavioral contracts, offline provenance verification, retained machine-readable evidence, and exact protected-main blob proof.

---

## Validation Audit 2026-09-09

| Metric | Count |
|--------|-------|
| Pending map entries audited | 9 |
| Plan 16–18 terminal-gap entries audited | 6 |
| Resolved | 9 |
| Escalated | 0 |

Evidence observed during this audit:

- `bash scripts/ci/ci-run-metrics.test.sh` — 11 passing contracts, including raw source-page authority and strict threshold behavior.
- `bash scripts/ci/capture-fast-01-gap-closure.test.sh` — PASS, including population-size, rate-limit, overlap, chronology, pagination, and 719/720/721 cases.
- `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` — `source_complete_offline_attestation_verified` under network denial.
- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` — `offline_attestation_verified` under network denial, with expected adverse mutation failures.
- Four focused Phase 235 contracts — 45 tests, 0 failures.
- Complete `test/sigra/planning/` suite — 143 tests, 0 failures, 12 intentional skips unrelated to the Phase 235 mapped behaviors.
- All seven Plan 16 evidence-path blobs match protected-main squash commit `158aca14b11de13cbc5ab2fdea1bff790cc7ab29`; all recorded Plan 16–18 execution commits exist.

### Plan 19 Delta Audit 2026-09-09

| Metric | Count |
|--------|-------|
| Plan 19 map entries audited | 2 |
| Resolved | 2 |
| Escalated | 0 |

Evidence observed during this delta audit:

- `bash scripts/ci/ci-run-metrics.test.sh` — 11 passing contracts, including literal terminal conclusions, stable equal-duration ordering, floor median, and strict threshold behavior.
- `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` — `source_complete_offline_attestation_verified`.
- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` — `offline_attestation_verified`; its intentional adverse trusted-root and source-ref mutations failed before the positive verification banner.
- `ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` — 16 tests, 0 failures, including the multi-conclusion semantic fixture, collapsed-outcome rejection, authenticated/default-path separation, protected digests, and exact 93-row GATE-05 assertion.
- `git diff --check -- scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` — clean.
