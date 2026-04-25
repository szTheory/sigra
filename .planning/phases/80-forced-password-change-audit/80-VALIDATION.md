---
phase: 80
slug: forced-password-change-audit
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-24
---

# Phase 80 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `mix.exs` (`MIX_ENV=test`) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/account_audit_atomicity_test.exs` |
| **Full suite command** | Same as quick + `mix test test/sigra/account/password_change_test.exs` |
| **Estimated runtime** | ~30–90 seconds (Postgres + compilation) |

---

## Sampling Rate

- **After every task commit on code paths:** Run the **quick** command (atomicity file).
- **After wave 2 (planning truth):** Run **full** command if any **`lib/`** change landed in the same PR; otherwise grep-only verification from plan **02** is sufficient.
- **Before `/gsd-verify-work`:** `account_audit_atomicity_test.exs` must be green.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 80-01-01 | 01 | 1 | AUD-17-01, AUD-17-02 | T-80-01 | Atomic user + audit commit | integration | `mix test test/sigra/account_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 80-01-02 | 01 | 1 | AUD-17-03 | T-80-02 | Rollback leaves no orphan audit | integration | same file (forced-clear guard test) | ✅ | ⬜ pending |
| 80-02-01 | 02 | 2 | AUD-17-04 | — | Planning matrix honest | grep | `rg 'AUD-04-043' .planning/phases/09-audit-logging/09-VERIFICATION.md` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [x] Existing **ExUnit** + **`Sigra.Test.PostgresRepo`** harness in **`test/sigra/account_audit_atomicity_test.exs`** — no new framework install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | All behaviors have automated or grep verification. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or grep acceptance
- [ ] Sampling continuity: atomicity tests run after **`lib/sigra/account.ex`** edits
- [ ] Feedback latency acceptable for CI
- [ ] `nyquist_compliant: true` set in frontmatter when phase evidence is merged

**Approval:** pending
