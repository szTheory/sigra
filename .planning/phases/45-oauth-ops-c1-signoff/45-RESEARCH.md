# Phase 45 — Technical research (AUD-08 / OAuth / ops / C-1)

**Phase:** 45 — oauth-ops-c1-signoff  
**Research date:** 2026-04-20  
**Question answered:** What do we need to know to plan AUD-08 well?

## Executive summary

Phase 45 closes **AUD-08** by extending the **AUD-04** inventory monotonically from **AUD-04-050** (after **AUD-04-049** in `44-AUD-04-INVENTORY.md`), converting **T1** co-fated boundaries to **`Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` or `__log_internal__/3`**, and documenting **T2/T3** exclusions with **EX-45-*** rows. **OAuth** is a **hybrid** surface (D-45-02): external I/O and redirects cannot share a DB transaction with audit, but **`repo.insert` / `update` / `delete`** on host Ecto schemas **must** compose audit inside the same `Repo.transaction` as domain writes when `:audit_schema` is set.

**`Sigra.OAuth.Callback.register_oauth_user/6`** already uses **`Multi.new()`** for user + identity inserts but emits **no audit** inside the transaction today — success auditing lives in **`Sigra.OAuth`** via **`log_safe`** after navigation/token paths. The conversion pattern from Phases **43–44** applies: add **`Audit.log_multi_safe`** steps to the same `multi` pipeline, then **`repo.transaction(multi)`**; on audit failure return **`{:error, _}`** (T1 DX per D-45-02).

**`update_identity_fields`** uses **`repo.update`** outside Multi — planner should evaluate wrapping login path in Multi (user/identity update + audit) or document **EX-45-*** if session/store boundaries prevent co-fate.

**`Sigra.Workers.AccountDeletion`** calls **`Deletion.execute`** then **`log_safe`** for **`account.deletion_executed`** — violates D-45-04. Remediation: extract a **single internal API** (e.g. extend **`Sigra.Account`** or **`Sigra.Deletion`**) that runs **`Deletion.execute` effects + audit row in one `Repo.transact`**, invoked from both HTTP **`execute_deletion`** and the worker. Retries require **idempotency**: no duplicate **`account.deletion_executed`** on Oban retry (unique key, conditional insert, or “already deleted” no-op without second audit).

**Lockout:** **`Lockout.increment!`** is pure Ecto update; **`Sigra.Auth.handle_failed_login_with_lockout`** already coordinates MFA-style patterns in Phase 44. **`Lockout.audit_lockout/1`** is standalone **`log_safe`** after threshold — if lockout row write and audit must co-fate, fold audit into the same Multi as **`increment!`** at call sites (likely **`Sigra.Auth`** paths), not inside **`Lockout`** without repo injection.

**Suspicious login / impersonation:** Few **`Audit.log_safe`** sites each; classify per D-45-01 (T1 for DB-backed “decision to notify”, T2 for SMTP-adjacent).

## Code anchors (grep evidence, 2026-04-20)

```text
$ rg -n "Sigra\\.Audit\\.(log_safe|log_multi_safe|__log_internal__)|Audit\\.log_safe|Audit\\.log_multi_safe" \\
  lib/sigra/oauth.ex lib/sigra/oauth/callback.ex lib/sigra/lockout.ex \\
  lib/sigra/suspicious_login.ex lib/sigra/impersonation.ex \\
  lib/sigra/workers/account_deletion.ex lib/sigra/api_token.ex

lib/sigra/workers/account_deletion.ex:140:                Sigra.Audit.log_safe("account.deletion_executed", scope,
lib/sigra/lockout.ex:130:    Sigra.Audit.log_safe(
lib/sigra/oauth.ex:89:        Sigra.Audit.log_safe(
lib/sigra/oauth.ex:165:        Sigra.Audit.log_safe(
... (additional oauth.ex lines 174–410)
lib/sigra/suspicious_login.ex:90:        Sigra.Audit.log_safe(
lib/sigra/impersonation.ex:49:            Audit.log_safe(
lib/sigra/impersonation.ex:82:    Audit.log_safe(
lib/sigra/impersonation.ex:101:      Audit.log_safe(
lib/sigra/impersonation.ex:183:    Audit.log_safe(
lib/sigra/api_token.ex:121:      |> Audit.log_multi_safe("api.token_create", audit_opts)
lib/sigra/api_token.ex:199–347: Sigra.Audit.log_safe (verify failure branches, etc.)
lib/sigra/api_token.ex:297,408: Audit.log_multi_safe (revoke paths)
```

**Note:** `lib/sigra/oauth/callback.ex` has **no** `Audit` calls today — mutations are audit-blind inside txn; this is the primary OAuth **T1** gap.

## JWT / api_token rows (AUD-04-048 / 049)

**44-AUD-04-INVENTORY** already assigns **AUD-04-048** / **049** to Phase **45** with “defer AUD-08”. **45-CONTEXT** defers **`audit_jwt_refresh`** unless explicitly added to Phase 45 inventory. **Default plan:** carry forward as **EX-45-JWT-*** deferral rows in **`45-AUD-04-INVENTORY.md`** without code conversion unless the executor promotes them in the inventory wave.

## Testing pattern (inherits 43–44)

- Use **`Sigra.Audit.Assertions`** and **`*_audit_atomicity_test.exs`** with real **`Ecto.Adapters.SQL.Sandbox`** repo.
- Prove rollback: invalid audit metadata → **`{:error, _}`** and **no** partial domain commits on **T1** paths.
- Use **`order_by: [asc: :id]`** when asserting multiple audit rows.

## Risks

| Risk | Mitigation |
|------|------------|
| OAuth Multi expansion breaks host apps relying on post-commit audit | Semver note + CHANGELOG; document **`{:error, _}`** on audit insert failure |
| Worker + HTTP fork drift | Single internal composition function for deletion execution + audit |
| Duplicate **`account.deletion_executed`** on Oban retry | Idempotency guard + tests simulating retry |

## Validation Architecture

Phase 45 execution uses **Elixir / Mix** with **ExUnit** and **PostgreSQL** (per `CLAUDE.md`).

**Feedback sampling:**

- After every task that touches **`.ex` / `.exs`**: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/<relevant>_test.exs` (or path scoped by task).
- After each plan wave: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`
- Gate before sign-off: **`mix format --check-formatted`** and full test suite green.

**Nyquist / Dimension 8:** Every implementation plan task lists **grep-verifiable** acceptance criteria and a **Mix** command in `<verify>` where feasible. Docs-only tasks use **file existence + `grep -q`** checks.

**Wave 0:** Not required — test infrastructure exists from prior phases.

---

## RESEARCH COMPLETE

Next: executable plans **`45-01`–`45-06`** in this directory.
