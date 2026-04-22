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
| 43-01-01 | 01 | 1 | AUD-04 | T-43-01 / — | Inventory matches `grep` ground truth | grep + manual review | `rg "Sigra\.Audit\.log_safe" lib/sigra` | ✅ | ✅ green |
| 43-02 | 02 | 2 | AUD-05 | T-43-02 | Register audit durable with user insert | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth/register_audit_atomicity_test.exs` | ✅ | ✅ green |
| 43-03 | 03 | 2 | AUD-05 | T-43-02 | Token + audit atomicity (magic link + reset request) | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` | ✅ | ✅ green |
| 43-04-login | 04 | 2 | AUD-05 | T-43-02 / T-43-03 | Login/lockout/session classification + Multi audit | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` | ✅ | ✅ green |
| 43-04-auth | 04 | 2 | AUD-05 | T-43-02 / T-43-03 | Auth core regression + documented tier-9 hybrids | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs` | ✅ | ✅ green |

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

## Nyquist deferral

Phase **50** published the consolidated policy table in **`MAINTAINING.md`** under **`## Nyquist policy (phases 41-44)`** and wired the installer subprocess merge gate (**`mix ci.install_golden`**, GitHub Actions job **`install_golden_contract`**). Scoped automated evidence for AUD-04/AUD-05 remains **`.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md`** (phase **47**). This **`43-VALIDATION.md`** map stays **`nyquist_compliant: false`** until every per-row checkbox is honestly satisfied with rationale tied to that verification merge gate — not merely because batch prose moved.

---

## Validation Sign-Off

- [x] Per-task map rows reference literal test paths (no glob placeholders) and honest Status markers (phase **47** refresh).
- [x] Batch **41-44** policy + installer drift class — see **`MAINTAINING.md`** (**Nyquist policy** + **Installer golden CI contract**); scoped AUD-04/05 closure remains **`43-VERIFICATION.md`**, not a silent Nyquist flip here.
- [ ] No watch-mode flags in verify commands
- [ ] Plan-level `nyquist_compliant` in individual `43-0x-PLAN.md` files follows planner/reviewer gates; **`nyquist_compliant: false`** here stays honest until row-level automated closure is demonstrated.

**Approval:** pending
