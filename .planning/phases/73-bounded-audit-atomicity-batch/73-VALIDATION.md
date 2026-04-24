---
phase: 73
slug: bounded-audit-atomicity-batch
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-23
---

# Phase 73 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` / `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~30–120 seconds (atomicity file only vs full suite) |

---

## Sampling Rate

- **After every task commit:** Run the **quick run command** above.
- **After every plan wave:** Re-run **quick** (both plans touch the same file set — same command).
- **Before `/gsd-verify-work`:** Full suite green per project policy.
- **Max feedback latency:** Bounded by local Postgres availability.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 73-01-01 | 01 | 1 | AUD-11 | T-73-01 | C-1 rows **023–032** match **`lib/`** mechanism | doc grep | `rg "AUD-04-02[3-9]\\|AUD-04-03[0-2]" .planning/phases/09-audit-logging/09-VERIFICATION.md` | ✅ | ⬜ pending |
| 73-02-01 | 02 | 1 | AUD-11 | T-73-02 | Verify/regenerate **Multi** rolls back with audit **CHECK** failure | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — **Postgres** at `localhost:5432` with `postgres`/`postgres` per **CLAUDE.md**.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| *None* | — | — | All behaviors targeted by **073-02** use automated **CHECK** constraints. |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` or equivalent acceptance commands
- [ ] Sampling continuity: atomicity tests run after each commit touching **`mfa_audit_atomicity_test.exs`**
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution completes

**Approval:** pending
