---
phase: 235
slug: terminal-ratification-measured-not-read
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-02
revised: 2026-09-08
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
- **After every plan wave:** Run `MIX_ENV=test mix test test/sigra/planning/` plus JSON parse validation for the terminal artifact.
- **Before `$gsd-verify-work`:** Run `MIX_ENV=test mix ci` and the metrics self-test; both must be green.
- **Max feedback latency:** Record actual focused-test duration during Wave 0 and keep every subsequent sample within that deterministic bound.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 235-01-01 | 01 | 1 | FAST-01, GATE-05 | T-235-01 | Reject malformed, stale, duplicate, unowned, non-executable, or receiptless evidence without exposing credentials. | ExUnit contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ❌ W0 | ⬜ pending |
| 235-01-02 | 01 | 1 | FAST-01 | T-235-02 | Preserve immutable cutoff, real run IDs, exact commands, wall-mode semantics, and honest pass/miss output. | Bash + ExUnit contract | `bash scripts/ci/ci-run-metrics.test.sh && MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | Partial: Bash exists; ExUnit ❌ W0 | ⬜ pending |
| 235-02-01 | 02 | 2 | FAST-01, GATE-05 | T-235-03 | Contributor and closeout claims must be derived from the terminal ledger and live workflow topology. | ExUnit contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | ❌ W0 | ⬜ pending |
| 235-16-01 | 16 | 10 | FAST-01, GATE-05 | T-235-16-01/02/07 | The mandated metrics script owns membership/statistics; raw source and median/maximum job-step pages permit independent comparison and preserve GATE-05. | Bash + ExUnit | `bash scripts/ci/ci-run-metrics.test.sh && bash scripts/ci/capture-fast-01-gap-closure.test.sh && ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | Planned | ⬜ pending |
| 235-16-02 | 16 | 10 | FAST-01, GATE-05 | T-235-16-04 | Exact tested metrics/collector/workflow/verifier/contract blobs reach protected main before dispatch. | Git ancestry/blob check | `git fetch origin main && git merge-base --is-ancestor HEAD origin/main && git diff --exit-code HEAD origin/main -- scripts/ci/ci-run-metrics.sh scripts/ci/ci-run-metrics.test.sh scripts/ci/capture-fast-01-gap-closure.sh scripts/ci/capture-fast-01-gap-closure.test.sh .github/workflows/fast-01-gap-closure-evidence.yml scripts/ci/verify-fast-01-source-complete-attestation-offline.sh test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | Planned | ⬜ pending |
| 235-17-01 | 17 | 11 | FAST-01, GATE-05 | T-235-17-01/06 | A reversible preflight retains and validates protected-main identity/blob equality, authoritative readiness, REST budget/reset state, workflow identity, UTC boundary, and the bounded pre-dispatch projection before authorization. | jq + ExUnit | Exact `<automated>` command in `235-17-PLAN.md` Task 1 | Planned | ⬜ pending |
| 235-17-03 | 17 | 11 | FAST-01, GATE-05 | T-235-17-01/02/03/05/06 | Dispatch is the first external mutation after the checkpoint; a durable singleton correlation receipt precedes one watcher; signed source plus instrument output and miss poles verify offline; GATE-05 stays exact. | Bash + jq + ExUnit | Exact `<automated>` command in `235-17-PLAN.md` Task 3 | Planned | ⬜ pending |
| 235-18-01 | 18 | 12 | FAST-01, GATE-05 | T-235-18-01/02/04 | Requirement and residual reconciliation branches only on authenticated metrics-script output after independent comparison and complete pole linkage. | Offline verifier + ExUnit | Exact `<automated>` command in `235-18-PLAN.md` Task 1 | Planned | ⬜ pending |
| 235-18-02 | 18 | 12 | FAST-01, GATE-05 | T-235-18-03/04 | SEED-005 and CI-PERF agree with the authenticated pass/miss branch while all historical FAST facts and GATE-05 remain exact. | Offline verifier + ExUnit | Exact `<automated>` command in `235-18-PLAN.md` Task 2 | Planned | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — validate the terminal ledger, Phase 234 inventory consumption, complete before/after ownership coverage, live workflow seams, receipt provenance, and documentation/closeout congruence.
- [ ] `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` — establish the machine-readable source of truth with explicit schema, cutoff, window, rows, receipts, and verdict fields.
- [ ] `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` — Plan 16 creates the source/instrument/pole/correlation contract before the irreversible Plan 17 dispatch.

---

## Manual-Only Verifications

All phase behaviors use committed contracts, GitHub CLI automation, structured run receipts, and deterministic repository checks. If fewer than ten eligible post-cutoff PR runs exist, execution must stop at a durable evidence checkpoint rather than substitute manual approval or synthetic runs.

---

## Validation Sign-Off

- [x] All executable tasks have `<automated>` verification or Wave 0 dependencies; Plan 17's verified reversible preflight precedes the blocking-human decision checkpoint, and the one-way task begins with the single dispatch as its first external mutation.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing reference.
- [ ] No watch-mode flags or sleep-based waits.
- [ ] Focused feedback latency is measured and bounded.
- [x] `nyquist_compliant: true` reflects complete planned automated coverage; execution status remains pending in the table.

**Approval:** planned coverage complete; execution pending
