---
phase: 235
slug: terminal-ratification-measured-not-read
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-02
---

# Phase 235 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5 plus Bash contract tests |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs && bash scripts/ci/ci-run-metrics.test.sh` |
| **Full suite command** | `MIX_ENV=test mix ci && bash scripts/ci/ci-run-metrics.test.sh` |
| **Estimated runtime** | Measured during execution; no sleep-based allowance |

---

## Sampling Rate

- **After every task commit:** Run the focused Phase 235 ExUnit contract and `bash scripts/ci/ci-run-metrics.test.sh`.
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

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — validate the terminal ledger, Phase 234 inventory consumption, complete before/after ownership coverage, live workflow seams, receipt provenance, and documentation/closeout congruence.
- [ ] `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` — establish the machine-readable source of truth with explicit schema, cutoff, window, rows, receipts, and verdict fields.

---

## Manual-Only Verifications

All phase behaviors use committed contracts, GitHub CLI automation, structured run receipts, and deterministic repository checks. If fewer than ten eligible post-cutoff PR runs exist, execution must stop at a durable evidence checkpoint rather than substitute manual approval or synthetic runs.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing reference.
- [ ] No watch-mode flags or sleep-based waits.
- [ ] Focused feedback latency is measured and bounded.
- [ ] `nyquist_compliant: true` is set after execution proves the contract.

**Approval:** pending
