---
phase: 11
slug: generator-feature-system
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-11
updated: 2026-04-11
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Install-dir suite** | `mix test test/sigra/install/` |
| **Estimated runtime** | ~30s quick; ~65s full install-dir suite (includes golden-diff byte gate) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale` (plus `mix compile --warnings-as-errors` on touched modules)
- **After every plan wave:** Run `mix test test/sigra/install/` + `mix format --check-formatted`
- **Before `/gsd-verify-work`:** Full suite green + golden-diff test green + `mix credo --strict` + `mix dialyzer` clean
- **Max feedback latency:** 120 seconds for quick loop

---

## Per-Task Verification Map

> One row per task across Plans 11-01 through 11-06. Every automated command corresponds verbatim to the `<verify><automated>` block in its task.

| Task ID  | Plan | Wave | Requirement    | Threat Ref  | Secure Behavior | Test Type              | Automated Command                                                                                                                                                                                          | File Exists | Status |
|----------|------|------|----------------|-------------|-----------------|------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|--------|
| 11-01-01 | 01   | 0    | GEN-02         | T-11-01..05 | N/A refactor    | unit + structural      | `mix test test/sigra/install/templates_layout_test.exs && mix compile --warnings-as-errors`                                                                                                                | ✅          | ✅ green |
| 11-01-02 | 01   | 0    | GEN-02, GEN-05 | T-11-01..05 | N/A refactor    | golden-diff harness    | `mix test test/sigra/install/golden_diff_test.exs`                                                                                                                                                         | ✅          | ✅ green |
| 11-02-01 | 02   | 1    | GEN-01         | T-11-06..10 | N/A refactor    | unit                   | `mix test test/sigra/install/feature_test.exs test/sigra/install/injection_test.exs test/sigra/install/golden_diff_test.exs && mix compile --warnings-as-errors`                                           | ✅          | ✅ green |
| 11-02-02 | 02   | 1    | GEN-05, GEN-07 | T-11-06..10 | N/A refactor    | unit                   | `mix test test/sigra/install/report_test.exs test/sigra/install/migration_timestamps_test.exs test/sigra/install/golden_diff_test.exs && mix compile --warnings-as-errors`                                 | ✅          | ✅ green |
| 11-03-01 | 03   | 2    | GEN-02         | T-11-11..13 | N/A refactor    | structural (mv check)  | `test $(find priv/templates/sigra.install -maxdepth 1 -type f \| wc -l) -eq 0 && test $(find priv/templates/sigra.install/core -maxdepth 1 -type f \| wc -l) -eq 45`                                       | ✅          | ✅ green |
| 11-03-02 | 03   | 2    | GEN-02         | T-11-11..13 | N/A refactor    | golden-diff regression | `mix test test/sigra/install/ && mix compile --warnings-as-errors`                                                                                                                                         | ✅          | ✅ green |
| 11-04-01 | 04   | 3    | GEN-01, GEN-02 | T-11-14..18 | N/A refactor    | unit                   | `mix test test/sigra/install/features/core_test.exs test/sigra/install/golden_diff_test.exs && mix compile --warnings-as-errors`                                                                           | ✅          | ✅ green |
| 11-04-02 | 04   | 3    | GEN-01         | T-11-14..18 | N/A refactor    | unit                   | `mix test test/sigra/install/features/core_test.exs test/sigra/install/features/core_post_instructions_test.exs test/sigra/install/golden_diff_test.exs && mix compile --warnings-as-errors`              | ✅          | ✅ green |
| 11-05-01 | 05   | 4    | GEN-01, GEN-05, GEN-07 | T-11-19..23 | N/A refactor | golden-diff regression | `mix test test/sigra/install/golden_diff_test.exs && test $(wc -l < lib/mix/tasks/sigra.install.ex) -le 150 && mix compile --warnings-as-errors`                                                            | ✅          | ✅ green |
| 11-05-02 | 05   | 4    | GEN-04         | T-11-19..23 | N/A refactor    | integration            | `mix test test/sigra/install/idempotency_test.exs`                                                                                                                                                         | ✅          | ✅ green |
| 11-06-01 | 06   | 5    | GEN-01         | T-11-24..26 | N/A refactor    | custom guardrail       | `mix test test/sigra/install/purely_additive_test.exs test/sigra/install/isolation_test.exs && mix test test/sigra/install/`                                                                               | ✅          | ✅ green |
| 11-06-02 | 06   | 5    | GEN-01         | T-11-24..26 | N/A refactor    | documentation          | `grep -c "nyquist_compliant: true" .planning/phases/11-generator-feature-system/11-VALIDATION.md`                                                                                                          | ✅          | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Row count: **12** — matches Plans 01-06 × 2 tasks each.

---

## Wave 0 Requirements

All Wave 0 artifacts shipped in Plans 11-01 / 11-02 (see 11-01-SUMMARY.md and 11-02-SUMMARY.md):

- [x] `test/sigra/install/golden_diff_test.exs` — bespoke harness using `String.myers_difference/2`, migration-filename normalization helper, fixture at `test/fixtures/install_golden/`
- [x] `test/sigra/install/feature_test.exs` — behaviour contract tests
- [x] `test/sigra/install/injection_test.exs` — `%Injection{}` struct + Injector adapter
- [x] `test/sigra/install/report_test.exs` — 4-category accumulator
- [x] `test/sigra/install/migration_timestamps_test.exs` — slot allocator determinism
- [x] `test/sigra/install/features/core_test.exs` — behaviour implementation
- [x] `test/sigra/install/idempotency_test.exs` — re-run no-op proof (GEN-04)
- [x] `test/sigra/install/purely_additive_test.exs` — V-PA-01 mechanical check
- [x] `test/sigra/install/isolation_test.exs` — V-ISOLATION-01 grep-based boundary check
- [x] `test/sigra/install/templates_layout_test.exs` — 45-file manifest under `core/`
- [x] `test/support/install_fixture.ex` — `mix phx.new` tmp-app setup helper
- [x] `test/fixtures/install_golden/` — committed golden snapshot (captured BEFORE refactor began)
- [x] `test/fixtures/install_golden/STDOUT.txt` — committed normalized installer stdout fixture (GEN-05 byte gate)
- [x] `test/sigra/install/features/core_post_instructions_test.exs` — fixture-mode tests for the Oban + Swoosh post_instructions branches

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Post-install summary visual quality (color, alignment, long-path wrapping) | GEN-05 | ANSI color + terminal rendering is cosmetic and not worth snapshotting | Run `mix sigra.install --yes` in a fresh `mix phx.new` project, visually inspect the 4-column table output |
| Developer ergonomics re-running installer | GEN-04 | UX feel of "skipping" messages is subjective | After first install, re-run and confirm messages read naturally, not alarming |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (12 new test files + fixture dir)
- [x] No watch-mode flags
- [x] Feedback latency < 120s (full install-dir suite ~65s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved by planner (2026-04-11, Wave 5 completion)
