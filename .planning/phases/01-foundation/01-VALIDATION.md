---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | FOUND-01 | — | N/A | unit | `mix test test/sigra/config_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | FOUND-02 | — | N/A | unit | `mix test test/sigra/crypto_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 1 | FOUND-03 | — | N/A | unit | `mix test test/sigra/token_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01 | 1 | FOUND-04 | — | N/A | unit | `mix test test/sigra/telemetry_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-05 | 01 | 1 | FOUND-05 | — | N/A | unit | `mix test test/mix/tasks/sigra.install_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-06 | 01 | 1 | FOUND-06 | — | N/A | unit | `mix test test/sigra/behaviours_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-07 | 01 | 1 | FOUND-07 | — | N/A | unit | `mix test test/sigra/auth_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-08 | 01 | 1 | FOUND-08 | — | N/A | unit | `mix test test/sigra/plugs_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-09 | 01 | 1 | FOUND-09 | — | N/A | unit | `mix test test/sigra/schema_test.exs` | ❌ W0 | ⬜ pending |
| 1-01-10 | 01 | 1 | FOUND-10 | — | N/A | unit | `mix test test/sigra/generator_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/test_helper.exs` — ExUnit setup
- [ ] `test/support/` — shared test fixtures and helpers
- [ ] Mix project compiles with `mix compile --warnings-as-errors`

*Existing infrastructure covers basic requirements; Wave 0 adds test stubs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Generator output looks like idiomatic Phoenix code | FOUND-01 | Subjective code style check | Run `mix sigra.install`, review generated files for Phoenix conventions |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
