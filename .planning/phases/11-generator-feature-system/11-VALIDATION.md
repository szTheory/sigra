---
phase: 11
slug: generator-feature-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-11
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
| **Estimated runtime** | ~30s quick; ~2m full (includes golden-diff harness) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale` (plus `mix compile --warnings-as-errors` on touched modules)
- **After every plan wave:** Run `mix test` + `mix format --check-formatted` + `mix credo --strict`
- **Before `/gsd-verify-work`:** Full suite green + golden-diff test green + `mix dialyzer` clean
- **Max feedback latency:** 120 seconds for quick loop

---

## Per-Task Verification Map

> Populated during planning. Each task in PLAN.md gets a row mapping it to a requirement, a test type, and a mechanically-checkable command. Filled in by the planner from RESEARCH.md Validation Architecture section.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 0 | GEN-02 | — | N/A | golden-diff harness scaffold | `mix test test/sigra/install/golden_diff_test.exs` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 0 | GEN-02 | — | N/A | pre-refactor snapshot captured | `mix test test/sigra/install/golden_diff_test.exs --only snapshot` | ❌ W0 | ⬜ pending |
| 11-02-01 | 02 | 1 | GEN-01 | — | N/A | `Sigra.Install.Feature` behaviour compiles + `@callback` count == 5 | `mix test test/sigra/install/feature_test.exs` | ❌ W0 | ⬜ pending |
| 11-02-02 | 02 | 1 | GEN-01 | — | N/A | `%Sigra.Install.Injection{}` struct defined | `mix test test/sigra/install/injection_test.exs` | ❌ W0 | ⬜ pending |
| 11-03-01 | 03 | 2 | GEN-02 | — | N/A | 44 templates present under `priv/templates/sigra.install/core/` | `mix test test/sigra/install/templates_layout_test.exs` | ❌ W0 | ⬜ pending |
| 11-04-01 | 04 | 2 | GEN-05 | — | N/A | `Sigra.Install.Report` records 4 categories | `mix test test/sigra/install/report_test.exs` | ❌ W0 | ⬜ pending |
| 11-05-01 | 05 | 2 | GEN-07 | — | N/A | `MigrationTimestamps.allocate/2` deterministic ordering | `mix test test/sigra/install/migration_timestamps_test.exs` | ❌ W0 | ⬜ pending |
| 11-06-01 | 06 | 3 | GEN-01, GEN-02 | — | N/A | `Features.Core` implements all 5 callbacks | `mix test test/sigra/install/features/core_test.exs` | ❌ W0 | ⬜ pending |
| 11-06-02-postinstr | 06 | 3 | GEN-01 | T-11-14..18 | N/A | `Features.Core.post_instructions/2` Oban + Swoosh detection branches (ported from `inject_oban_queue/1` + `inject_swoosh_config/2`) | `mix test test/sigra/install/features/core_post_instructions_test.exs` | ❌ W0 | ⬜ pending |
| 11-01-stdout | 01 | 0 | GEN-05 | — | N/A | Installer stdout matches `test/fixtures/install_golden/STDOUT.txt` byte gate (4-column summary + post_instructions content) | `mix test test/sigra/install/golden_diff_test.exs` | ❌ W0 | ⬜ pending |
| 11-07-01 | 07 | 3 | GEN-01 | — | N/A | walker refactor; golden diff still zero | `mix test test/sigra/install/golden_diff_test.exs` | ❌ W0 | ⬜ pending |
| 11-07-02 | 07 | 3 | GEN-04 | — | N/A | re-run idempotency (second invocation = no writes) | `mix test test/sigra/install/idempotency_test.exs` | ❌ W0 | ⬜ pending |
| 11-08-01 | 08 | 4 | GEN-01 | — | N/A | V-PA-01 purely-additive: fake feature works with zero walker edits | `mix test test/sigra/install/purely_additive_test.exs` | ❌ W0 | ⬜ pending |
| 11-08-02 | 08 | 4 | GEN-01 | — | N/A | V-ISOLATION-01: `Features.Core` contains no `Features.Organizations\|Passkeys\|Admin` refs | `mix test test/sigra/install/isolation_test.exs` | ❌ W0 | ⬜ pending |

*Rows are a SKELETON. Planner will expand to match actual task IDs from PLAN.md files.*

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/install/golden_diff_test.exs` — bespoke harness using `String.myers_difference/2`, migration-filename normalization helper, fixture at `test/fixtures/install_golden/`
- [ ] `test/sigra/install/feature_test.exs` — behaviour contract tests
- [ ] `test/sigra/install/injection_test.exs` — `%Injection{}` struct + Injector adapter
- [ ] `test/sigra/install/report_test.exs` — 4-category accumulator
- [ ] `test/sigra/install/migration_timestamps_test.exs` — slot allocator determinism
- [ ] `test/sigra/install/features/core_test.exs` — behaviour implementation
- [ ] `test/sigra/install/idempotency_test.exs` — re-run no-op proof (GEN-04)
- [ ] `test/sigra/install/purely_additive_test.exs` — V-PA-01 mechanical check
- [ ] `test/sigra/install/isolation_test.exs` — V-ISOLATION-01 grep-based boundary check
- [ ] `test/sigra/install/templates_layout_test.exs` — 44-file manifest under `core/`
- [ ] `test/support/install_fixture.ex` — `mix phx.new` tmp-app setup helper
- [ ] `test/fixtures/install_golden/` — committed golden snapshot (captured BEFORE refactor begins)
- [ ] `test/fixtures/install_golden/STDOUT.txt` — committed normalized installer stdout fixture (GEN-05 byte gate)
- [ ] `test/sigra/install/features/core_post_instructions_test.exs` — fixture-mode tests for the Oban + Swoosh post_instructions branches (revision §2)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Post-install summary visual quality (color, alignment, long-path wrapping) | GEN-05 | ANSI color + terminal rendering is cosmetic and not worth snapshotting | Run `mix sigra.install --yes` in a fresh `mix phx.new` project, visually inspect the 4-column table output |
| Developer ergonomics re-running installer | GEN-04 | UX feel of "skipping" messages is subjective | After first install, re-run and confirm messages read naturally, not alarming |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (12 new test files + fixture dir)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter (flipped by planner after filling the per-task map)

**Approval:** pending
