---
phase: 213
slug: latest-phoenix-compatibility
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-02
---

# Phase 213 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Bash CI smoke scripts |
| **Config file** | `test/test_helper.exs` (existing); CI in `.github/workflows/ci.yml` |
| **Quick run command** | `mix test test/sigra/install/golden_diff_test.exs` |
| **Full suite command** | `mix test` (requires live Postgres + phx_new 1.8.8 archive) |
| **Estimated runtime** | ~90–180 seconds (golden-diff quick run ~15s) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/install/golden_diff_test.exs` (fixture parity) plus any test touched by the task.
- **After every plan wave:** Run `mix test` full suite + the relevant CI smoke script locally (`scripts/ci/install-smoke.sh`).
- **Before `/gsd-verify-work`:** Full suite green + `scripts/ci/install-smoke.sh` + `scripts/ci/admin-acceptance-smoke.sh` green against the 1.8.8 archive.
- **Max feedback latency:** ~180 seconds (full suite); ~15 seconds (golden-diff quick check).

---

## Per-Task Verification Map

> Task IDs are illustrative placeholders keyed to the two-plan split recommended by research
> (Plan 01 = rebless golden + fixture; Plan 02 = pin flip + docs + `--check` CI + version asserts).
> The planner may renumber; each COMPAT requirement must remain mapped to an automated gate.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 213-01-01 | 01 | 1 | COMPAT-02 | — | Fixture byte-parity with 1.8.8 output (root_tag_attribute block absorbed) | integration | `mix test test/sigra/install/golden_diff_test.exs` | ✅ | ⬜ pending |
| 213-01-02 | 01 | 1 | COMPAT-01 | — | Fresh phx.new 1.8.8 + sigra.install compiles clean under `--warnings-as-errors` | e2e smoke | `scripts/ci/install-smoke.sh` | ✅ | ⬜ pending |
| 213-02-01 | 02 | 2 | COMPAT-03 | — | No `1.8.7` pin string in any workflow file / CLAUDE.md / CONTRIBUTING.md | grep gate | `! grep -rn "phx_new 1.8.7" .github/workflows CLAUDE.md CONTRIBUTING.md` | ✅ | ⬜ pending |
| 213-02-02 | 02 | 2 | COMPAT-03 | — | phase_198 contributor-DX contract test updated off `1.8.7` assertion | unit | `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` | ✅ | ⬜ pending |
| 213-02-03 | 02 | 2 | COMPAT-03 | — | `rebless_golden --check` drift-detector runs in CI + smoke scripts assert resolved archive version (D-11) | integration | `mix sigra.fixture.rebless_golden --check` (exit 0 clean) | ✅ | ⬜ pending |
| 213-02-04 | 02 | 2 | COMPAT-03 | — | Generated-host acceptance smoke green against current phx.new | e2e smoke | `scripts/ci/admin-acceptance-smoke.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* No new test framework, harness, or fixture
scaffold is introduced — every gate (`golden_diff_test.exs`, `install-smoke.sh`,
`admin-acceptance-smoke.sh`, `rebless_golden --check`) already exists. The phase reconciles data
(the golden fixture) and wiring (CI pins + a new `--check` job), not test infrastructure.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| *(none — zero human UAT per D-10/D-11)* | — | All three success criteria are covered by automated gates | N/A |

---

## Validation Architecture (from RESEARCH.md)

| Success Criterion | Requirement | Automated Gate (proof) |
|-------------------|-------------|------------------------|
| Fresh phx.new ≥1.8.8 + sigra.install compiles clean under `--warnings-as-errors` | COMPAT-01 | `scripts/ci/install-smoke.sh` (warnings-as-errors compile at ~line 64) |
| Golden fixture + `golden_diff_test` pass without the 1.8.7 archive | COMPAT-02 | `test/sigra/install/golden_diff_test.exs` (`:golden` tag) after rebless |
| `1.8.7` pin absent from all CI/docs; acceptance smoke green on current phx.new | COMPAT-03 | grep-gate on pin sites + `scripts/ci/admin-acceptance-smoke.sh` + `rebless_golden --check` CI drift-detector + smoke version-assert (D-11) |

---

*Phase: 213-latest-phoenix-compatibility · Validation strategy created 2026-07-02*
