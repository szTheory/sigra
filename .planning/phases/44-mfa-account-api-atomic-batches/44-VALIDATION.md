---
phase: 44
slug: mfa-account-api-atomic-batches
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-20
---

# Phase 44 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs`, host `config/test.exs` via `Sigra.Test.PostgresRepo` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/<new_atomicity_module>_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~2–8 minutes full suite (project-dependent) |

---

## Sampling Rate

- **After every task commit:** Run the **quick** command for the test file touched by that plan.
- **After every plan wave:** Run `mix test test/sigra/` (or full suite if shared helpers changed).
- **Before `/gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 600 seconds (CI upper bound)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 44-01-01 | 01 | 1 | AUD-04 | T-44-01 | Inventory completeness (no silent omission) | doc + rg | `rg -n "log_safe|log_multi" lib/sigra/mfa.ex lib/sigra/account.ex lib/sigra/api_token.ex` | ⬜ | ⬜ pending |
| 44-02-01 | 02 | 2 | AUD-06 / AUD-07 | T-44-02 | Named Multi audit steps + telemetry on commit only | unit | `mix test test/sigra/audit_test.exs` (extend or add focused module) | ✅ | ⬜ pending |
| 44-03-xx | 03 | 3 | AUD-06 | T-44-03 | MFA domain + audit share transaction | integration | `mix test test/sigra/mfa_audit_atomicity_test.exs` | ❌ W0 | ⬜ pending |
| 44-04-xx | 04 | 3 | AUD-07 | T-44-04 | Account mutations + audit share transaction | integration | `mix test test/sigra/account_audit_atomicity_test.exs` | ❌ W0 | ⬜ pending |
| 44-05-xx | 05 | 3 | AUD-07 | T-44-05 | Token revoke / revoke_all + audit | integration | `mix test test/sigra/api_token_audit_atomic_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing Postgres-backed audit tests cover `api.token_create` pattern (`test/sigra/api_token_audit_atomic_test.exs`).
- [ ] New files created by plans **44-03** / **44-04** as listed in PLAN acceptance criteria.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None default | — | — | All behaviors target automated atomicity tests per D-44-06 |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 600s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
