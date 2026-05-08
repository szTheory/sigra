# Plan 109-01 Summary

## Outcome

Implemented the library-owned recent security activity seam and the missing persisted lifecycle truth needed to keep it honest.

## Delivered

- Added `Sigra.SecurityActivity.list_recent_activity/3` as the canonical recent-activity query/presentation seam over persisted audit rows.
- Extended `Sigra.Admin.Audit.Presenter` with shared action-label normalization for sign-in, logout, suspicious-login, revoke, and MFA-verification activity.
- Added explicit voluntary logout truth via `Sigra.Auth.logout/4`, backed by `auth.logout` instead of a generic `session.delete` label.
- Added explicit MFA-completion truth via `auth.mfa_verified` so MFA flows no longer surface only as a second bare `session.create`.
- Prevented zero-count revoke actions from writing misleading activity rows.
- Added focused library tests for logout audit truth and activity query/normalization behavior.

## Verification

- `MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/security_activity_test.exs test/sigra/suspicious_login_test.exs --no-color`

