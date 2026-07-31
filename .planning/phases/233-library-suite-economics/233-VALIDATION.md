---
phase: 233
slug: library-suite-economics
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-31
---

# Phase 233 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 locally) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs test/support/ci/ex_unit_timing_formatter_test.exs` |
| **Full suite command** | `mix test` plus the CI partitions and scaffold receiver on a real pull request |
| **Estimated runtime** | Focused contract tests under 60 seconds locally; CI topology proof uses one pull-request run |

---

## Sampling Rate

- **After every task commit:** Run the focused Phase 233 contract and formatter tests.
- **After every plan wave:** Run `mix test` and the relevant workflow-contract tests.
- **Before `$gsd-verify-work`:** Full suite green plus one retry-free pull-request run with machine-readable receipts.
- **Max feedback latency:** 60 seconds locally; one CI run for topology evidence.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 233-01-01 | 01 | 1 | TEST-01 | T-233-01 | Timing output uses a fixed CI-owned path and does not interpolate event data into shell | unit + workflow contract | `mix test test/support/ci/ex_unit_timing_formatter_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-02-01 | 02 | 2 | TEST-02 | N/A | contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ❌ W0 | ⬜ pending |
| 233-03-01 | 03 | 2 | TEST-03 | T-233-02 | The required aggregator fails unless ordinary shards and the PR scaffold receiver succeed | workflow contract + PR observation | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs`; `gh run view <run-id> --json jobs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/support/ci/ex_unit_timing_formatter_test.exs` — deterministic timing sort, schema, and error paths.
- [ ] `test/sigra/planning/phase_233_library_economics_contract_test.exs` — scaffold tags, CI commands, manifest coverage, receiver, and aggregator edges.
- [ ] Add a receipt-validation helper/test if the timing and PR evidence schemas are not otherwise mechanically asserted.

---

## Manual-Only Verifications

None. Live GitHub Actions behavior must be verified through automated pull-request CI polling and committed machine-readable evidence.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test references.
- [ ] No watch-mode flags.
- [ ] Local feedback latency is under 60 seconds.
- [x] `nyquist_compliant: true` set in frontmatter after the focused formatter/workflow command passed.

**Approval:** pending
