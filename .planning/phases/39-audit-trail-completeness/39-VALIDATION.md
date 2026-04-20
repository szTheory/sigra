---
phase: 39
slug: audit-trail-completeness
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-18
---

# Phase 39 — Validation Strategy

> Library test suite + Postgres-backed scratch tests where atomicity must be proven.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `config/test.exs` (root lib); `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit/log_safe_scope_test.exs test/sigra/api_token_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~3–8 minutes full (machine-dependent) |

---

## Sampling Rate

- **After every task commit:** Quick run on the test file(s) named in that task’s `<verify>` block.
- **After every plan wave:** Full `mix test` when any `lib/sigra/**/*.ex` touched; else quick command + affected directories.
- **Before `/gsd-verify-work`:** Full suite green with live Postgres per `CLAUDE.md`.
- **Max feedback latency:** Target &lt; 10 minutes on full suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-01-01 | 01 | 1 | AUD-01 | T-39-01 | Helpers never log secrets | unit | `mix test test/sigra/audit/audit_assertions_test.exs` | ❌ W0 | ⬜ pending |
| 39-01-02 | 01 | 1 | AUD-01 | T-39-02 | Ordered audit queries documented | grep/docs | `grep -q "order_by" guides/recipes/testing.md` | ✅ | ⬜ pending |
| 39-02-01 | 02 | 2 | AUD-02 | T-39-03 | Atomic commit / rollback | integration | `mix test test/sigra/api_token_audit_atomic_test.exs` (path per plan) | ❌ W0 | ⬜ pending |
| 39-02-02 | 02 | 2 | AUD-02 | T-39-01 | Metadata excludes raw secret | unit+grep | `mix test` + `rg "hashed_token|raw_key" lib/sigra/api_token.ex` audit metadata (must not appear in log opts) | ✅ | ⬜ pending |
| 39-03-01 | 03 | 3 | AUD-03 | T-39-04 | Login audit rows stable fields | integration | `cd test/example && mix test test/example_web/smoke/register_login_logout_test.exs` | ✅ | ⬜ pending |
| 39-03-02 | 03 | 3 | AUD-03 | T-39-04 | MFA audit path | integration | `cd test/example && mix test test/example_web/smoke/mfa_totp_test.exs` | ✅ | ⬜ pending |
| 39-03-03 | 03 | 3 | AUD-01–03 | T-39-05 | REQ narrative honest | grep | `grep -n "AUD-0" .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Postgres service + `Sigra.Test.PostgresRepo` — existing (`test/support/postgres_test_repo.ex`).
- [x] `Sigra.Test.AuditEvent` — existing stub schema.
- [ ] New: audit assertion helpers module (Plan 01).
- [ ] New: atomic API token audit test module (Plan 02).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None required for closure | — | All AUD goals mappable to `mix test` | If CI differs from local DB, reproduce with docker one-liner from `CLAUDE.md` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or explicit manual row above
- [ ] No watch-mode flags in verify commands
- [ ] `nyquist_compliant: true` set in this frontmatter when execution closes

**Approval:** pending
