# Phase 44 — Pattern map

Analogs in-repo for executors — read before editing.

| Intended change | Analog file | Pattern excerpt |
|-----------------|-------------|-----------------|
| Multi + `log_multi_safe` + telemetry after txn | `lib/sigra/api_token.ex` | `create/3` pipelines `Multi.insert` → `Audit.log_multi_safe("api.token_create", ...)` → `Repo.transaction` → `Audit.emit_telemetry_from_changes/1` |
| MFA Multi + audit | `lib/sigra/mfa.ex` | `regenerate_backup_codes/4` — `Multi` composition, `log_multi_safe`, transaction boundary |
| Auth atomic login/register | `lib/sigra/auth.ex` | `Audit.log_multi_safe` / `__log_internal__` inside `Ecto.Multi`, failure paths `log_safe` |
| Postgres audit rollback proof | `test/sigra/api_token_audit_atomic_test.exs` | DDL in setup, constraint violation on audit insert, assert domain row absent after `{:error, _}` |
| Inventory row layout | `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` | Columns: ID, boundary, action, mechanism, tier, batch tag, notes, grep log |

**Anti-pattern:** Duplicating `Ecto.Multi.insert(..., :audit, ...)` by hand inside `Sigra.MFA` — use centralized `Audit` API after plan **44-02** lands.
