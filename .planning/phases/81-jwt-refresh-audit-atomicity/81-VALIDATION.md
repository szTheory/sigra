---
phase: 81
slug: jwt-refresh-audit-atomicity
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-24
---

# Phase 81 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `mix.exs` / `config/test.exs` (host test env) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~30–120 seconds (slice vs full) |

---

## Sampling Rate

- **After every task commit:** Run the **quick run command** when the task modified **`lib/sigra/api_token.ex`** or **`test/sigra/api_token_audit_atomic_test.exs`**
- **After every plan wave:** Run **quick** after wave 1–2; run **full suite** after wave 3 if code changed in the phase
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds (full suite on modest hardware)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 81-01-01 | 01 | 1 | AUD-18-01, AUD-18-02 | T-81-01 | Audit rows for JWT refresh/reuse durable when audit on; no silent wrong Multi | unit + grep | `mix test test/sigra/api_token_audit_atomic_test.exs` (post 02) + `rg "log_safe\\(.*api\\.jwt_refresh" lib/sigra/api_token.ex` exits 1 | ✅ | ⬜ pending |
| 81-02-01 | 02 | 2 | AUD-18-03 | T-81-02 | Fault injection proves telemetry + no row; happy path proves row | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs` | ✅ | ⬜ pending |
| 81-03-01 | 03 | 3 | AUD-18-04 | T-81-03 | Inventories match `lib/sigra/api_token.ex` | grep | `grep -nF 'AUD-04-048' .planning/phases/09-audit-logging/09-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing **`api_token_audit_atomic_test.exs`** + **PostgresRepo** cover infrastructure — no Wave 0 install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Merge gate narrative | AUD-18-04 | Human reads **81-VERIFICATION.md** closure row | After CI green, fill **81-VERIFICATION.md** sign-off and tick **Nyquist** checklist in this file |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
