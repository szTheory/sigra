# Phase 44 — Technical research

**Question:** What do we need to know to plan MFA + Account + API token audit atomicity well?

## Current `Sigra.Audit` constraints

- `do_log_multi/4` always uses `Ecto.Multi.insert(multi, :audit, fn changes -> ...)`.
- A second `log_multi_safe` / `__log_internal__` in the same `Ecto.Multi` **reuses `:audit`** and **collides** at composition time (duplicate operation name).
- `emit_telemetry_from_changes/1` matches `%{audit: %_{} = event}` only — a second insert under another key needs an explicit telemetry contract so events still fire **once per committed audit row** and **never on rollback**.

## Ecto idioms

- **Named steps:** Pass a configurable atom (e.g. `:audit`, `:audit_backup`, `:audit_mfa_verify`) as the `Multi.insert` name. Default `:audit` preserves backward compatibility for all existing callers.
- **Telemetry:** Prefer one helper that accepts `changes` plus a list of step atoms to scan (default `[:audit]`) **or** iterate all values in `changes` that match `audit_schema` — pick the smallest change that preserves existing tests for `Auth`, `Passkeys`, `APIToken.create`, etc.

## MFA-specific

- **Backup verify** must emit **`mfa.verify.success`** and **`mfa.backup_code_used`** in the **same** `repo.transaction` as `BackupCodes.consume` / lockout reset (CONTEXT D-44-03).
- **`regenerate_backup_codes/4`** already demonstrates Multi + `log_multi_safe` + `emit_telemetry_from_changes/1` — reuse structure for `verify/4`, `confirm_enrollment/4`, `disable`, and failure/lockout Multis.
- **Pure read / validation exits** stay `log_safe` or silent per hybrid policy (D-44-03 item 6).

## Account-specific

- **`execute_deletion`:** Audit row must share rollback with hard delete — no “delete committed, audit best-effort.”
- **Post-commit email:** Keep SMTP / mail delivery **outside** the DB transaction (existing project rule).

## API tokens

- **`revoke/2`:** Mirror `APIToken.create/3` — `Multi.update` + `log_multi_safe("api.token_revoke", ...)`.
- **`revoke_all/2`:** New summary action (e.g. `api.token_revoke_all`) with count metadata; implement with `Multi` + `update_all` / `Multi.run` as appropriate — no raw token material in metadata.

## Testing pattern

- Follow `test/sigra/api_token_audit_atomic_test.exs` and Phase 43 atomicity tests: real Postgres, invalid audit constraint to force rollback, `order_by: [asc: :id]`, no `Repo` mocks, no exact timestamp equality.

## Validation Architecture

**Dimension 8 (Nyquist):** Automated feedback is driven by **ExUnit** against **Sigra.Test.PostgresRepo** for audit atomicity modules.

| Layer | Mechanism |
|-------|-----------|
| **Unit / integration** | `mix test test/sigra/mfa_audit_atomicity_test.exs` (and siblings introduced in plans) |
| **Regression** | `mix test test/sigra/` after each wave touching `lib/sigra/` |
| **CI parity** | Same commands as `.github/workflows` Elixir CI — no watch mode |

**Sampling:** After each implementation plan wave, run targeted atomicity test file(s) plus `mix test test/sigra/api_token_audit_atomic_test.exs` when API token code changes.

**Sign-off gate:** `nyquist_compliant: true` on plans only after `44-VALIDATION.md` task rows are filled and full `mix test` green before `/gsd-verify-work`.

---

## RESEARCH COMPLETE
