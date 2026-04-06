---
phase: 1
slug: foundation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-05
updated: 2026-04-05
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --failed` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --failed`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Task Name | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-----------|-------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01 | 1 | Mix project, config, error modules | FOUND-03, FOUND-05, FOUND-06 | unit | `mix test test/sigra/config_test.exs test/sigra/error_test.exs` | created by task | pending |
| 01-01-T2 | 01 | 1 | Crypto, Token, Behaviours, Testing skeleton | FOUND-04, FOUND-10 | unit | `mix test test/sigra/crypto_test.exs test/sigra/token_test.exs test/sigra/behaviours_test.exs` | created by task | pending |
| 01-02-T1 | 02 | 1 | Telemetry module | FOUND-07 | unit | `mix test test/sigra/telemetry_test.exs` | created by task | pending |
| 01-02-T2 | 02 | 1 | Library plugs | FOUND-08 | unit | `mix test test/sigra/plug/` | created by task | pending |
| 01-03-T1 | 03 | 2 | EEx templates | FOUND-01, FOUND-02, FOUND-04, FOUND-09, FOUND-10 | compile | `mix compile --warnings-as-errors` | created by task | pending |
| 01-03-T2 | 03 | 2 | Mix task, Injector, generator tests | FOUND-01, FOUND-09, FOUND-10 | unit | `mix test test/mix/tasks/sigra.install_test.exs test/sigra/install/injector_test.exs` | created by task | pending |
| 01-03-T3 | 03 | 2 | Verify generator in real Phoenix app | FOUND-01 | manual | Human inspects generated output | N/A (checkpoint) | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/test_helper.exs` — ExUnit setup (created by Plan 01, Task 1)
- [ ] Mix project compiles with `mix compile --warnings-as-errors` (created by Plan 01, Task 1)

*Wave 0 is satisfied by Plan 01 Task 1 which creates the Mix project from scratch.*

---

## Nyquist Compliance

All 6 automated tasks (01-01-T1 through 01-03-T2) have `<automated>` verify commands in their respective PLAN.md files. Task 01-03-T3 is a checkpoint:human-verify task (manual by design). No consecutive automated tasks lack verification commands.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Generator output looks like idiomatic Phoenix code | FOUND-01 | Subjective code style check | Run `mix sigra.install`, review generated files for Phoenix conventions |
| --no-live flag produces working headless scaffold | FOUND-10 | End-to-end integration in real Phoenix app | Run generator with --no-live in fresh Phoenix app, verify no LiveView files |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are checkpoint tasks
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covered by Plan 01 Task 1 (creates test infrastructure)
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution
