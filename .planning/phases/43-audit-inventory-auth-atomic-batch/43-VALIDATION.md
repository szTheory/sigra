---
phase: 43
slug: audit-inventory-auth-atomic-batch
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-20
---

# Phase 43 — Validation Strategy

> Per-phase validation contract for AUD-04 documentation and AUD-05 Auth atomicity work.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `config/test.exs`, host `MIX_ENV=test` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~2–8 minutes (local Postgres required per `CLAUDE.md`) |

---

## Sampling Rate

- **After every task commit:** Run quick compile (and scoped `mix test` when the task touched `test/`).
- **After every plan wave:** Run full suite command.
- **Before `/gsd-verify-work`:** Full suite must be green.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 43-01-01 | 01 | 1 | AUD-04 | T-43-01 / — | Inventory matches `grep` ground truth | grep + manual review | `rg "Sigra\.Audit\.log_safe" lib/sigra` | ⬜ | ⬜ pending |
| 43-02-xx | 02 | 2 | AUD-05 | T-43-02 | Register audit durable with user insert | integration | `mix test test/sigra/*register*audit*` | ⬜ | ⬜ pending |
| 43-03-xx | 03 | 2 | AUD-05 | T-43-02 | Token + audit atomicity | integration | scoped `mix test` | ⬜ | ⬜ pending |
| 43-04-xx | 04 | 2 | AUD-05 | T-43-02 / T-43-03 | Login/lockout/session classification | integration | scoped `mix test` | ⬜ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing ExUnit + `Sigra.Test.PostgresRepo` patterns cover new atomicity tests — no new framework install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Inventory completeness review | AUD-04 | Maintainer judgment on exclusions | Read `43-AUD-04-INVENTORY.md` against `rg` output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or documentation grep gates
- [ ] No watch-mode flags in verify commands
- [ ] `nyquist_compliant: true` set in plan frontmatter when plans complete checker pass

**Approval:** pending
