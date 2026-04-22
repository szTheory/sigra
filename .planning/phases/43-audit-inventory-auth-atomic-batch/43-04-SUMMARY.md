# Plan 43-04 Summary

## Objective

AUD-05 B3: co-locate `auth.login.success` with Repo-backed lockout reset (and optional hash upgrade) for `authenticate_with_config/2` when audit is enabled; document Scope cut in AUD-04 inventory; add atomicity proof test.

## Completed

- Added `login_success_password_path/7` + `login_success_repo_and_audit_multi/5` for confirmed users with `:audit_schema`; preserved `log_safe` success audit on the unconfirmed pre-check branch.
- Extended `handle_valid_login_with_security/6` with `skip_lockout_reset` / `skip_extra_hash` options.
- Amended `43-AUD-04-INVENTORY.md` with **Scope cut (Plan 04)** and refreshed B1/B2/B3 row status + grep log.
- Added `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs`.

## Self-Check: PASSED

- `mix test` on auth-related subset including new login atomicity module.
