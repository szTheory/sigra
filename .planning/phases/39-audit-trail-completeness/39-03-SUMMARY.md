---
phase: 39
plan: 03
status: complete
---

# Plan 39-03 — AUD-03 example smoke + docs trio

## Delivered

- Example smoke: `auth.login.success` / `auth.login.failure` assertions in
  `register_login_logout_test.exs`; `mfa.enroll.success` via
  `mfa_confirm_enrollment` in `mfa_totp_test.exs`.
- `Example.Accounts.get_user_by_email_and_password/2` now calls
  `Sigra.Auth.authenticate/2` with `sigra_config()` and handles `{:ok, user, _}`
  return shape so login audit rows are written.
- `.planning/REQUIREMENTS.md` AUD-01..03 marked implemented; `CHANGELOG.md`
  unreleased bullets; `SEED-002` “Phase 39 resolution”; `docs/audit-semantics.md`
  + README topic-map link.

## Verification

- `cd test/example && mix test --include example_app test/example_web/smoke/register_login_logout_test.exs test/example_web/smoke/mfa_totp_test.exs`

## Self-Check: PASSED
