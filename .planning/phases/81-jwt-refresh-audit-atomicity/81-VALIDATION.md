---
phase: 81
slug: jwt-refresh-audit-atomicity
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-24
validated: 2026-04-24
---

# Phase 81 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `mix.exs` / `config/test.exs` (host test env); repo config in `test/support/postgres_test_repo.ex` |
| **Quick run command** | `SIGRA_TEST_PG_USERNAME=<user> SIGRA_TEST_PG_PASSWORD=<pass> PGHOST=localhost MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs` (defaults `postgres`/`postgres`; macOS Homebrew often needs `SIGRA_TEST_PG_USERNAME=$(whoami)` `SIGRA_TEST_PG_PASSWORD=`) |
| **Full suite command** | `SIGRA_TEST_PG_USERNAME=<user> SIGRA_TEST_PG_PASSWORD=<pass> PGHOST=localhost MIX_ENV=test mix test` |
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
| 81-01-01 | 01 | 1 | AUD-18-01, AUD-18-02 | T-81-01 | Audit rows for JWT refresh/reuse durable when audit on; no silent wrong Multi | unit + grep | `rg "log_safe\\(.*api\\.jwt_refresh" lib/sigra/api_token.ex` exits **1**; `grep -n "Audit.log_safe" lib/sigra/api_token.ex \| grep -E "api\\.jwt_refresh\|jwt_refresh"` exits **1**; implementation in `lib/sigra/api_token.ex` | ✅ | ✅ green |
| 81-02-01 | 02 | 2 | AUD-18-03 | T-81-02 | Fault injection proves telemetry + no row; happy path proves row | unit | `SIGRA_TEST_PG_USERNAME=<user> SIGRA_TEST_PG_PASSWORD=<pass> PGHOST=localhost MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs` | ✅ | ✅ green |
| 81-03-01 | 03 | 3 | AUD-18-04 | T-81-03 | Inventories match `lib/sigra/api_token.ex` | grep | `grep -nF 'AUD-04-048' .planning/phases/09-audit-logging/09-VERIFICATION.md` contains **`log_multi_safe`** | ✅ | ✅ green |

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

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated verification 2026-04-24 (`api_token_audit_atomic_test.exs` 14 examples, 0 failures with local `SIGRA_TEST_PG_USERNAME`); merge-gate row in **81-VERIFICATION.md** remains maintainer-owned.

---

## Validation Audit 2026-04-24

| Metric | Count |
|--------|-------|
| Gaps found | 3 (VALIDATION map stuck `pending`; test command assumed `postgres` role; no audit trail) |
| Resolved | 3 |
| Escalated | 0 |

**Resolution:** Refreshed per-task statuses against **81-01**/**81-02**/**81-03** artifacts; ran `mix test test/sigra/api_token_audit_atomic_test.exs` green; documented **`SIGRA_TEST_PG_*`** overrides for hosts without a `postgres` DB role. **AUD-18-04** doc truth verified via `09-VERIFICATION.md` **AUD-04-048** line. No implementation or test source edits required (`## GAPS FILLED`).
