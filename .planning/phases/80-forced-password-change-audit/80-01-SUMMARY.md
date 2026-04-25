---
phase: 80
plan: "01"
status: complete
---

# Plan 80-01 — Summary

## Objective

Ship **`Sigra.Account.clear_password_change_requirement/3`** with **`Multi` + `log_multi_safe`** when audit is enabled; deprecate **`audit_forced_password_change/2`** for the same completion path; extend **`account_audit_atomicity_test.exs`** with happy path + **`CHECK`** rollback + audit-off coverage.

## Completed

- **`lib/sigra/account.ex`**: new public API, D-26 dispatch comment refresh, **`@deprecated`** on legacy helper.
- **`test/sigra/account_audit_atomicity_test.exs`**: three tests (atomic success, constraint rollback, no-audit-schema path).

## Verification

- `mix compile` — pass.
- `SIGRA_TEST_PG_USERNAME=jon MIX_ENV=test mix test test/sigra/account_audit_atomicity_test.exs test/sigra/account/password_change_test.exs` — pass (local Postgres; **`postgres`** role absent on this host).

## Self-Check: PASSED
