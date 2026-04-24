---
phase: 83
slug: mfa-confirm-enrollment-022
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 83 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` (project default) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~30–120 seconds (Postgres-backed MFA tests) |

---

## Sampling Rate

- **After every task commit:** Run quick command when **`mfa_audit_atomicity_test.exs`** or **`lib/sigra/mfa.ex`** changed; otherwise `MIX_ENV=test mix compile --warnings-as-errors`.
- **After every plan wave:** Run quick command for wave touching MFA audit tests.
- **Before `/gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 120 seconds (full suite local ceiling).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|---------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 83-01-01 | 01 | 1 | AUD-20-01 | T-83-01 | Invalid TOTP path uses durable audit **only** when `:audit_schema` set; no empty txn when off | compile | `MIX_ENV=test mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 83-02-01 | 02 | 2 | AUD-20-02 | T-83-02 / T-83-03 | Matrix A/B/C: return parity, row counts, telemetry on fault injection | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 83-03-01 | 03 | 2 | AUD-20-03 | — | Planning artifacts + CHANGELOG reflect **022** T1 promotion | grep / manual | `rg "022" .planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` (post-edit) | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- **Existing infrastructure covers all phase requirements.** No new framework install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | All behaviors covered by ExUnit + doc grep |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` or Wave 0 dependencies
- [ ] Sampling continuity maintained for MFA audit file
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter after green full suite

**Approval:** pending
