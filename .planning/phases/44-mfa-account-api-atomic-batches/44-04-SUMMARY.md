---
phase: 44-mfa-account-api-atomic-batches
plan: "04"
subsystem: account
tags: [audit, AUD-07, Ecto.Multi, postgres]

requires:
  - phase: 44-02
    provides: "log_multi_safe + emit_telemetry_from_changes"
provides:
  - "Sigra.Account success paths atomic with audit when :audit_schema set"
affects: []

key-files:
  created:
    - "test/sigra/account_audit_atomicity_test.exs"
  modified:
    - "lib/sigra/account.ex"
    - "lib/sigra/audit.ex"

requirements-completed: [AUD-07]

completed: 2026-04-20
---

# Phase 44 — Plan 04 summary (AUD-07 Account)

## Shipped

- **`lib/sigra/account.ex`**: When `:audit_schema` is set, success paths wrap domain work in `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` and call `Sigra.Audit.emit_telemetry_from_changes/1` on `{:ok, changes}`. `execute_deletion/3` runs `Deletion.execute` first, then `account.deletion_execute` audit so a failed audit rolls back deletion work. Without `:audit_schema`, behavior matches the pre-audit domain-only paths.
- **`lib/sigra/audit.ex`**: Optional `:organization_id_resolver` and `:effective_user_id_resolver` (arity-1 `changes` callbacks) so `confirm_email_change` can populate org/effective columns from the post-confirm user.
- **`test/sigra/account_audit_atomicity_test.exs`**: Postgres-backed tests for `set_password` + audit atomicity and `execute_deletion` (:anonymize) rollback when audit insert is blocked by a CHECK constraint.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/account_audit_atomicity_test.exs`
- `grep -q "log_multi_safe" lib/sigra/account.ex && grep -q "emit_telemetry_from_changes" lib/sigra/account.ex && grep -q "account.deletion_execute" lib/sigra/account.ex`

## Notes

- `audit_forced_password_change/2` intentionally remains `log_safe` per inventory (EX-44-05).
