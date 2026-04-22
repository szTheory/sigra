---
phase: 48
slug: phase-44-verification-aud0607
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 48 — Validation Strategy

> Closure phase: documentation + REQ reconciliation for **AUD-06** / **AUD-07** after phase **44** implementation.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` via `Sigra.Test.PostgresRepo` |
| **Merge gate (scoped)** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/api_token_audit_atomic_test.exs test/sigra/audit_multi_step_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | Scoped compound ~1–3 min; full suite project-dependent |

---

## Sampling Rate

- **After `44-VALIDATION.md` edits:** Grep acceptance criteria from **`48-01-PLAN.md`** Task 1.
- **After `44-VERIFICATION.md` draft:** Run merge gate commands from **`48-01-PLAN.md`** Task 3.
- **Before `48-02` REQ flips:** `grep -E "^status: passed" .planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md` must exit 0.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 1 | AUD-06/07 | T-48-01 | Validation rows bind to real test paths | doc + grep | `grep -F "mfa_audit_atomicity_test.exs" .planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md` | ✅ | ⬜ pending |
| 48-01-02 | 01 | 1 | AUD-06/07 | T-48-02 | Verification snapshot + no secrets | doc + grep | `grep -F "44-AUD-04-INVENTORY.md" .planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md` | ⬜ | ⬜ pending |
| 48-01-03 | 01 | 1 | AUD-06/07 | T-48-03 | Merge gate commands executed | shell | Same compound `mix test` as **Merge gate** row above | ✅ | ⬜ pending |
| 48-02-01 | 02 | 2 | AUD-06/07 | T-48-10 | REQ flip only after `status: passed` | grep | `grep -E "^status: passed" .planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md` | ⬜ | ⬜ pending |
| 48-02-02 | 02 | 2 | AUD-06/07 | T-48-11 | Traceability table honest | doc | `grep "AUD-06 | 48 | Complete" .planning/REQUIREMENTS.md` (after flip) | ⬜ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Postgres-backed library tests exist under `test/sigra/` for MFA, Account/API, and audit Multi-step foundation.
- [x] Phase **47** precedent (`43-VERIFICATION.md`, `47-01-PLAN.md`) defines closure task shape.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| None default | — | — | All gates target automated `mix` + grep |

---

## Validation Sign-Off

- [ ] All **48** tasks have grep- or shell-verifiable acceptance
- [ ] `44-VERIFICATION.md` records merge gate with verbatim commands
- [ ] No watch-mode flags in documented commands
- [ ] **`44-VALIDATION.md`** frontmatter remains `nyquist_compliant: false` unless **`STATE.md`** records explicit escalation (**D-48-03**)
- [ ] **Phase 50** referenced for full Nyquist batch **41–44** — not claimed complete in phase **48**

**Approval:** pending
