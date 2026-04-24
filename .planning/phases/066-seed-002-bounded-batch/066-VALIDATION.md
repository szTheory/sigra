---
phase: 66
slug: seed-002-bounded-batch
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-23
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (Sigra / ExUnit).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `config/test.exs` (host); library tests use inline `PostgresRepo` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~30–120s full suite (env-dependent) |

---

## Sampling Rate

- **After every task commit:** Quick run command (atomicity file)
- **After every plan wave:** Quick run + `mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** ~120s

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 66-01-01 | 01 | 1 | AUD-09 | T-66-01 | Enrollment failure after DB rollback emits durable **`mfa.enroll.failure`** without phantom success audit | unit + integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 66-01-02 | 01 | 1 | AUD-09 | T-66-02 | Fault injection proves domain rows absent when audit step fails (reuse CHECK pattern) | integration | same | ✅ | ⬜ pending |
| 66-02-01 | 02 | 2 | AUD-09 | T-66-03 | C-1 matrix matches **`lib/sigra/mfa.ex`** for **AUD-04-020..022** | doc grep | `grep AUD-04-02 .planning/phases/09-audit-logging/09-VERIFICATION.md` | ✅ | ⬜ pending |
| 66-02-02 | 02 | 2 | AUD-09 | T-66-04 | Inventory mechanism column honest vs **`grep log_multi_safe lib/sigra/mfa.ex`** | doc grep | `grep confirm_enrollment lib/sigra/mfa.ex` + inventory diff | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [x] Postgres reachable at `localhost:5432` with `postgres`/`postgres` (see `CLAUDE.md`)

*Existing infrastructure covers MFA atomicity tests.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | All behaviors targeted by automated tests or doc greps |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` or equivalent automated command
- [ ] Sampling continuity maintained (atomicity file between MFA edits)
- [ ] No watch-mode flags in CI commands
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution closes Nyquist gaps

**Approval:** pending
