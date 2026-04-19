# Phase 39: Audit trail completeness — Research

**Status:** Complete  
**Date:** 2026-04-18  
**Question answered:** What do we need to know to *plan* AUD-01–AUD-03 well?

---

## Summary

1. **AUD-01 (harness):** Reuse established patterns: `Sigra.Audit.LogSafeScopeTest.CaptureRepo` for changeset capture without Postgres; `Sigra.Test.PostgresRepo` + raw SQL `CREATE TABLE` / `TRUNCATE` (see `test/sigra/admin/audit/query_test.exs`) for ordered, multi-row assertions. Helpers should be **plain functions** taking `repo` and `audit_schema` explicitly (D-39-01), not macros.
2. **AUD-02 (atomic conversion):** `Sigra.APIToken.do_create/4` today does `repo.insert` then `Audit.log_safe/3` — classic non-atomic hybrid. **`Sigra.Audit.log_multi_safe/3`** appends `:audit` when `audit_schema` is set and is a no-op when nil — same semantics as `log_safe` for disabled audit. After `Repo.transaction/1`, call **`Sigra.Audit.emit_telemetry_from_changes/1`** on success only (D-39-07); it no-ops when `:audit` absent. Reserved-prefix rules: public `log_multi/3` rejects `api.*`; **`log_multi_safe`** uses internal path — safe for `api.token_create`.
3. **AUD-03 (integration sites):** `lib/sigra/auth.ex` already documents login/lockout as `log_safe` (lines ~368–437, ~1606–1625). Extend tests that exercise **real** `insert` paths: either new Postgres-backed module alongside admin audit tests, or strengthen example-app smoke — **library-first** CONTEXT prefers `test/sigra/` with `PostgresRepo`. **Site 3:** `mfa_test.exs` is largely crypto/unit; **OAuth** `auth_integration_test.exs` uses callback repos without audit. Prefer **`test/example/.../mfa_totp_test.exs`** + `Example.DataCase` for MFA completion audit *or* add a focused **`Sigra.Test.PostgresRepo`** scenario for `Auth.authenticate_user/4`-style path — planner locked **MFA path in example app** if library-only cost is high; document in Plan 03.
4. **Docs:** Keep **two-primitive** story (`log_safe` vs `Multi` / `log_multi_safe` / `__log_internal__`) aligned with `lib/sigra/audit.ex` moduledoc; anchor C-1 in `REQUIREMENTS.md`, `CHANGELOG.md`, `SEED-002`.

---

## Code anchors

| Area | File | Notes |
|------|------|-------|
| Target refactor | `lib/sigra/api_token.ex` | `do_create/4` — insert + `log_safe("api.token_create", ...)` |
| Atomic template | `lib/sigra/auth.ex` | `verify_confirmation_token/3`, `verify_confirmation_code/3`, `complete_password_reset/4` — `Multi` + `__log_internal__` + `emit_telemetry_from_changes` |
| Safe Multi helper | `lib/sigra/audit.ex` | `log_multi_safe/3`, `emit_telemetry_from_changes/1`, `log_safe/3` contract |
| Capture-repo pattern | `test/sigra/audit/log_safe_scope_test.exs` | `CaptureRepo.insert/1` + `receive` |
| Postgres scratch | `test/support/postgres_test_repo.ex`, `test/sigra/admin/audit/query_test.exs` | `async: false`, `setup_all` DDL |
| Stub audit schema | `test/support/audit_test_event.ex` | `Sigra.Test.AuditEvent` — binary_id fields |

---

## Risks / fallback (D-39-08)

- If **`log_multi_safe`** composition conflicts with telemetry span wrapping in `APIToken.create/3`, narrow the refactor to `do_create` only and preserve outer `Telemetry.span`.
- If **semver** concern appears (public API surface), bounded plan: document “v1.3 ships audit-aware tests + harness only; Multi deferred” in `REQUIREMENTS.md` + `SEED-002` — **only** if technical blocker is documented in execution summary.

---

## Validation Architecture

Nyquist-aligned verification for Phase 39:

| Dimension | How it is satisfied |
|-----------|---------------------|
| **D1 — Unit** | Helper pure logic + `CaptureRepo` tests; `Audit` changeset validators unchanged |
| **D2 — Integration** | PostgresRepo: atomic token create leaves **0 or 1** `api.token_create` row per successful insert when audit enabled; rollback leaves 0 token + 0 audit |
| **D3 — Regression** | Existing `api_token_test.exs`, `log_safe_scope_test.exs`, `audit_integration_test.exs` stay green |
| **D4 — Security** | No raw token / hash in audit metadata; reserved-prefix rules preserved |
| **D5 — Performance** | No extra round-trips vs today on success path (single transaction vs insert+log) |
| **D6 — Observability** | `[:sigra, :audit, :log]` only on committed `:audit` step; no telemetry on rollback |
| **D7 — Docs** | REQUIREMENTS + CHANGELOG + SEED-002 + optional `docs/audit-semantics.md` |
| **D8 — Nyquist map** | `39-VALIDATION.md` task grid maps each plan task to a command |

**Sampling:** After each task: `mix test` scoped to touched test files; after each wave: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit test/sigra/api_token_test.exs` (adjust as files land).

---

## RESEARCH COMPLETE

Planning may proceed to `39-PATTERNS.md` and `39-*-PLAN.md`.
