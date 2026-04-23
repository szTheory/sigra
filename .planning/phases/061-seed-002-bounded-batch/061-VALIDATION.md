---
phase: 61
slug: seed-002-bounded-batch
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 61 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `config/test.exs` (host); MFA atomicity tests use embedded `PostgresRepo` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~2–15 minutes (full suite project-dependent) |

---

## Sampling Rate

- **After every task commit:** Run the **quick run command** for `mfa_audit_atomicity_test.exs`
- **After every plan wave:** Run **full suite command**
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** Bounded by full `mix test` (CI-aligned)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 61-01-01 | 01 | 1 | AUD-01 | T-61-01 | Failed backup verify logs co-fated audit or full rollback | unit | `mix test test/sigra/mfa_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 61-01-02 | 01 | 1 | AUD-01 | T-61-02 | Audit failure does not commit lockout increment | unit | `mix test test/sigra/mfa_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 61-02-01 | 02 | 2 | AUD-01 | — | C-1 matrices match merged code | grep + manual read | `grep -F 'verify_backup' .planning/phases/09-audit-logging/09-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements — reuse `test/sigra/mfa_audit_atomicity_test.exs` + local Postgres per `CLAUDE.md`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| C-1 matrix readability | AUD-01 | Table semantics | Open `09-VERIFICATION.md` and confirm row text matches implementation |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` or equivalent automated path
- [ ] Sampling continuity maintained (tests after code tasks)
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution completes

**Approval:** pending
