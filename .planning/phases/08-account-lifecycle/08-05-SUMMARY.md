---
phase: 08-account-lifecycle
plan: 05
subsystem: auth
tags: [liveview, generator, testing, settings, reactivation, injector]

# Dependency graph
requires:
  - phase: 08-account-lifecycle
    plan: 04
    provides: Generated templates (migration, user schema, auth context, emails)
provides:
  - Settings LiveView with email/password/deletion sections
  - Reactivation LiveView for grace period login
  - RequirePasswordChange and check_account_active plugs in user_auth
  - Generator injector with lifecycle routes, Oban queue, auth_hooks file
  - 10 testing helpers for account lifecycle operations
  - Auth fixtures for deletion and force password change
affects: []

# Tech tracking
decisions:
  - Settings page uses 3 sections matching UI-SPEC component inventory
  - OAuth-only users see "Set a password" instead of "Change password"
  - Reactivation page accessible to deleted users during grace period
  - Deletion section has danger zone styling (red left border)
  - Force password change banner uses yellow warning styling
deviations:
  - rule: 1
    what: Fixed pre-existing test expecting exact unique_index that Plan 04 changed to partial index
    impact: none
    action: Relaxed assertion to use contains? instead of exact match
---

## What Was Built

### Settings LiveView (`priv/templates/sigra.install/settings_live.ex`)
- Three sections: email (`id="email"`), password (`id="password"`), deletion (`id="delete"`)
- Email section: current email display, pending change status with cancel, change email form
- Password section: change password for existing users, "Set a password" for OAuth-only users
- Force password change banner (yellow) when `must_change_password` is true
- Deletion section: danger zone with `border-l-4 border-red-500`, scheduled status with cancel, confirmation modal

### Reactivation LiveView (`priv/templates/sigra.install/reactivation_live.ex`)
- Grace period login page with scheduled deletion date
- "Cancel deletion and keep my account" button
- "I understand, sign me out" link

### User Auth Plugs (`priv/templates/sigra.install/user_auth.ex`)
- `require_password_unchanged/2` — redirects to `/users/settings#password` when `must_change_password` is true
- `check_account_active/2` — redirects deleted users to `/users/reactivation`

### Generator Injector (`lib/sigra/install/injector.ex`)
- `inject_lifecycle_routes/2` — settings, confirm-email, reactivation routes
- `inject_oban_lifecycle_queue/1` — adds `sigra_lifecycle: 5` queue
- `lifecycle_template_files/0` — includes `auth_hooks.ex`, `settings_live.ex`, `reactivation_live.ex`

### Testing Helpers (`lib/sigra/testing.ex`)
- `scheduled_deletion_fixture/3` — creates user with scheduled deletion
- `deleted_user_fixture/3` — creates user in deleted state
- `assert_deletion_scheduled/1` — asserts deletion is scheduled
- `assert_deletion_cancelled/1` — asserts deletion was cancelled
- `assert_account_deleted/3` — asserts account was permanently deleted
- `simulate_grace_period_expiry/2` — sets scheduled_deletion_at to past
- `force_password_change_fixture/2` — creates user with force change flag
- `assert_password_changed/1` — asserts password_changed_at is recent
- `assert_sessions_invalidated/3` — asserts session count
- `with_hook/3` — temporarily overrides a hook for testing

### Auth Fixtures (`priv/templates/sigra.install/auth_fixtures.ex`)
- `scheduled_deletion_fixture/1` — fixture with deletion fields set
- `force_password_change_fixture/1` — fixture with must_change_password: true

## Self-Check: PASSED

## key-files

### created
- priv/templates/sigra.install/settings_live.ex
- priv/templates/sigra.install/reactivation_live.ex
- test/sigra/templates/settings_live_test.exs

### modified
- lib/sigra/install/injector.ex
- lib/sigra/testing.ex
- priv/templates/sigra.install/user_auth.ex
- priv/templates/sigra.install/auth_fixtures.ex
- test/sigra/install/injector_test.exs
- test/mix/tasks/sigra.install_test.exs
