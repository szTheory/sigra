# Plan 45-03 — Summary

**Status:** Complete  
**Phase:** 45 (oauth-ops-c1-signoff)

## Outcome

- **Lockout threshold + audit:** **`Sigra.Auth.handle_failed_login_with_lockout/5`** composes **`security.invalid_credentials`** and **`security.lockout`** via **`log_multi_safe`** inside **`repo.transaction`** when `:audit_schema` is set.
- **Suspicious login / impersonation:** Retained **`log_safe`** where **`SessionStore`** or read-only paths prevent same-txn compose; documented as **T2** with **`EX-45-03`**, **`EX-45-06`** in **`45-AUD-04-INVENTORY.md`**.

## Self-Check: PASSED

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth/login_and_lockout_audit_atomicity_test.exs test/sigra/suspicious_login_test.exs test/sigra/impersonation_test.exs`

## Key files

- `lib/sigra/auth.ex`
- `lib/sigra/lockout.ex`
- `lib/sigra/suspicious_login.ex`
- `lib/sigra/impersonation.ex`
