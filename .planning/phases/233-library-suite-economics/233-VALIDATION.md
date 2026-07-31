---
phase: 233
slug: library-suite-economics
status: validated
nyquist_compliant: true
wave_0_complete: true
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
| 233-01-02 | 01 | 1 | TEST-01 | T-233-02, T-233-03 | Empty, malformed, and unsafe receipt output fails closed and remains deterministic | unit + workflow contract | `mix test test/support/ci/ex_unit_timing_formatter_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-02-01 | 02 | 2 | TEST-01, TEST-02 | T-233-04, T-233-05 | The timing probe is an exact-head, retry-free pull-request observation with two successful shards | evidence contract + GitHub observation | `jq -e '.timing_probe.event == "pull_request" and .timing_probe.retry_free == true and (.timing_probe.shards \| length == 2)' .planning/phases/233-library-suite-economics/233-EVIDENCE.json` | ✅ | ✅ green |
| 233-02-02 | 02 | 2 | TEST-01, TEST-02 | T-233-05, T-233-06 | Per-file costs are non-negative, unique, and tied to two retained timing artifacts | evidence contract | `jq -e '(.timing_probe.per_file_costs \| length) > 0 and ([.timing_probe.per_file_costs[].time_us] \| all(type == "number" and . >= 0)) and (.timing_probe.artifacts \| length == 2)' .planning/phases/233-library-suite-economics/233-EVIDENCE.json` | ✅ | ✅ green |
| 233-03-01 | 03 | 3 | TEST-03 | T-233-08, T-233-09 | The scaffold receiver is unconditional and required by the aggregate | workflow contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-03-02 | 03 | 3 | TEST-03 | T-233-07 | Exactly the six intended subprocess-heavy modules carry the scaffold tag | workflow contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-04-01 | 04 | 4 | TEST-02, TEST-03 | T-233-10, T-233-11, T-233-12 | Measured costs produce two deterministic, non-empty ordinary partitions | unit + workflow contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-04-02 | 04 | 4 | TEST-02, TEST-03 | T-233-10, T-233-12 | Invalid costs, duplicates, missing ownership, and exact ties have fail-closed deterministic behavior | unit + workflow contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-05-01 | 05 | 5 | TEST-01, TEST-02, TEST-03 | T-233-13, T-233-15 | Final topology evidence is exact-head, retry-free, successful, and retains the required check | evidence contract + GitHub observation | `jq -e '.after.event == "pull_request" and .after.retry_free == true and .after.required_check.name == "Library tests" and .after.required_check.conclusion == "success"' .planning/phases/233-library-suite-economics/233-EVIDENCE.json` | ✅ | ✅ green |
| 233-05-02 | 05 | 5 | TEST-01, TEST-02, TEST-03 | T-233-14, T-233-15 | The final observed shard gap improves on baseline and all requirement dispositions are complete | evidence contract + focused tests | `jq -e '.before_gap_seconds == 192 and .after_gap_seconds < .before_gap_seconds and ([.requirements[] \| select(.status == "complete") \| .id] \| sort == ["TEST-01","TEST-02","TEST-03"])' .planning/phases/233-library-suite-economics/233-EVIDENCE.json` | ✅ | ✅ green |
| 233-06-01 | 06 | 6 | TEST-01, TEST-02, TEST-03 | T-233-13, T-233-15 | A live unmeasured ordinary test or selector failure blocks shard execution | unit + shell workflow contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ✅ W0 | ✅ green |
| 233-06-02 | 06 | 6 | TEST-01, TEST-02, TEST-03 | T-233-14, T-233-16 | Live ownership rejects stale, duplicate, missing, scaffold-leaking, and empty assignments | unit + workflow contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs && mix test test/support/ci/ex_unit_timing_formatter_test.exs` | ✅ W0 | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/support/ci/ex_unit_timing_formatter_test.exs` — deterministic timing sort, schema, and error paths.
- [x] `test/sigra/planning/phase_233_library_economics_contract_test.exs` — scaffold tags, CI commands, manifest coverage, receiver, selector transport, and aggregator edges.
- [x] `233-EVIDENCE.json` assertions — timing and PR evidence schemas are mechanically checked with `jq`.

---

## Manual-Only Verifications

None. Live GitHub Actions behavior must be verified through automated pull-request CI polling and committed machine-readable evidence.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verification or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Wave 0 covers all missing test references.
- [x] No watch-mode flags.
- [x] Local feedback latency is under 60 seconds.
- [x] `nyquist_compliant: true` set in frontmatter after the focused formatter/workflow command passed.

**Approval:** automated evidence complete — run 30668911851

## Validation Audit 2026-07-31

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All three phase requirements and all twelve plan tasks map to green deterministic verification. The focused ExUnit suite passed with 19 tests and the machine-readable evidence assertions passed. No additional test file was generated because no behavioral coverage gap remained.
