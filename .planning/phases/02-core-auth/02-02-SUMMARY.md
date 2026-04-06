---
phase: 02-core-auth
plan: 02
subsystem: auth-orchestrator
tags: [auth, registration, login, magic-link, telemetry, generator]
dependency_graph:
  requires: [01-01, 01-03, 02-01]
  provides: [sigra-auth-module, magic-link-flow, dual-mode-login, controller-mode-templates]
  affects: [03-email-delivery, 04-mfa, 05-session-management]
tech_stack:
  added: []
  patterns: [orchestrator-pattern, mox-repo-mock, embedded-schema-test-structs]
key_files:
  created:
    - lib/sigra/auth.ex
    - test/sigra/auth_test.exs
    - test/support/mock_repo_behaviour.ex
    - priv/templates/sigra.install/login_html.ex
    - priv/templates/sigra.install/registration_html.ex
  modified:
    - priv/templates/sigra.install/migration.exs
    - priv/templates/sigra.install/user.ex
    - priv/templates/sigra.install/user_token.ex
    - priv/templates/sigra.install/auth.ex
    - priv/templates/sigra.install/login_live.ex
    - priv/templates/sigra.install/registration_live.ex
    - priv/templates/sigra.install/session_controller.ex
    - lib/mix/tasks/sigra.install.ex
    - test/test_helper.exs
decisions:
  - "Sigra.Auth accepts changeset_fn option instead of user_schema for register/3 -- cleaner boundary, generated context builds the changeset"
  - "Session CRUD stays in generated auth context (needs UserToken schema) -- Sigra.Auth focuses on register, authenticate, magic link"
  - "Mox-based repo mock with embedded Ecto schemas for unit testing -- avoids database dependency in library tests"
  - "Controller-mode templates (login_html.ex, registration_html.ex) generated only with --no-live flag"
metrics:
  duration: 8m
  completed: "2026-04-06"
  tasks_completed: 2
  tasks_total: 2
  tests_added: 19
  tests_total: 201
  files_created: 5
  files_modified: 9
---

# Phase 02 Plan 02: Auth Orchestrator and Generator Templates Summary

Sigra.Auth orchestrator with register/authenticate/magic-link flows, dual-mode login templates, password strength UI, and controller-mode templates for --no-live installs.

## What Was Built

### Sigra.Auth Orchestrator (lib/sigra/auth.ex)

Core authentication library module implementing four public functions:

- **register/3** -- Takes repo, attrs, and changeset_fn option. Delegates insert to repo, detects email uniqueness constraint violations and returns `{:error, :email_taken}` for enumeration-safe handling. Wraps in telemetry span.

- **authenticate/3** -- Normalizes email via `Sigra.Email.normalize/1`, looks up user, verifies password via `Sigra.Crypto.verify_with_upgrade/3`. On success: resets `failed_login_attempts` to 0, applies hash upgrade if needed. On failure with existing user: increments `failed_login_attempts`. On failure with non-existent user: no DB write (timing protection via `no_user_verify`). Supports `require_confirmation: true` option for unconfirmed user rejection. Emits `[:sigra, :auth, :login, :stop]` and `[:sigra, :auth, :hash_upgraded]` telemetry.

- **request_magic_link/3** -- Rate-limited magic link generation. For existing users: generates hashed token, stores with "magic_link" context, returns `{:ok, {raw_token, url}}`. For non-existent emails: returns `{:ok, :sent}` (enumeration-safe). Supports pluggable rate limiter via `rate_limiter` option.

- **verify_magic_link/3** -- Single-use token verification with 10-minute TTL. Decodes token, hashes, looks up in DB, checks expiry, deletes token (single-use), auto-confirms unconfirmed users.

### Generator Template Updates

- **Migration** -- Added `failed_login_attempts` (integer, default 0) and `password_changed_at` (utc_datetime) columns across all three adapter branches (postgres, mysql, sqlite).

- **User schema** -- Replaced `validate_length(:password, min: 12, max: 72)` with `Sigra.PasswordPolicy.validate/1` (NIST defaults). Added `update_change(:email, &Sigra.Email.normalize/1)` before format validation. Added `password_changed_at` tracking on hash. Added comment for custom field extension point.

- **UserToken** -- Added `@magic_link_validity_in_seconds 600`, `build_magic_link_token/1`, and `verify_magic_link_token_query/1` using `ago(@magic_link_validity_in_seconds, "second")` in the Ecto query.

- **Auth context** -- Delegates `register_user/1` and `get_user_by_email_and_password/2` to `Sigra.Auth` (gaining hash upgrade, failed attempt tracking, telemetry). Added `request_magic_link/2` and `verify_magic_link/1`.

- **Login LiveView** -- Dual-mode form: magic link section (email + send button, POSTs with `_action: "magic_link"`) + divider + password section (existing form).

- **Registration LiveView** -- Real-time password strength feedback via `Sigra.PasswordPolicy.check_strength/1` on `phx-change`. Visual indicator with colored bar (red/yellow/green), strength label, and improvement suggestions. Handles `:email_taken` with generic enumeration-safe message.

- **Session controller** -- Added `create/2` clause for `_action: "magic_link"` (always shows generic message). Added `magic_link/2` action for GET `/users/log-in/:token`. Added logout telemetry emission.

- **Controller-mode templates** -- New `login_html.ex` and `registration_html.ex` for `--no-live` installs. Same dual-mode login layout without LiveView lifecycle. Registration form without real-time strength feedback (static form).

- **Install task** -- Generates controller-mode templates when `--no-live`. Added magic link route: `get "/log-in/:token", SessionController, :magic_link`.

## Test Coverage

19 new tests in `test/sigra/auth_test.exs` covering:
- register/3: valid attrs, invalid attrs, duplicate email detection, telemetry emission
- authenticate/3: correct credentials, wrong password (attempt tracking), non-existent email (no DB write), bcrypt hash upgrade, unconfirmed user rejection, login telemetry, hash_upgraded telemetry, email normalization
- request_magic_link/3: existing user, non-existent email (enumeration-safe), rate limiting
- verify_magic_link/3: valid token consumption, expired token, already-used token, unconfirmed user auto-confirmation

Test infrastructure: Mox-based repo mock with `Sigra.MockRepo.Behaviour` and embedded Ecto schemas for proper changeset operations.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ecto.Changeset.change/2 requires proper Ecto schema**
- **Found during:** Task 1 GREEN phase
- **Issue:** Test structs using `defstruct` failed with `__changeset__/0 is undefined` when `Sigra.Auth` called `Ecto.Changeset.change/2`
- **Fix:** Changed test structs from plain `defstruct` to `use Ecto.Schema` with `embedded_schema` blocks
- **Files modified:** test/sigra/auth_test.exs

**2. [Rule 1 - Bug] Ecto changeset does not track unchanged values**
- **Found during:** Task 1 GREEN phase
- **Issue:** Bcrypt upgrade test asserted `changes.failed_login_attempts == 0` but Ecto omits the key when value matches current (already 0)
- **Fix:** Changed assertion to `Map.get(changes, :failed_login_attempts, 0) == 0`
- **Files modified:** test/sigra/auth_test.exs

## Known Stubs

None -- all data flows are wired. Magic link email delivery is intentionally stubbed at the `url_fun` callback level (Phase 3 will implement Swoosh delivery).

## Self-Check: PASSED

- All 5 created files exist on disk
- Commit 4471451: Sigra.Auth orchestrator (Task 1)
- Commit 42bcb36: generator template updates (Task 2)
- 201 tests pass, 0 failures
- mix compile --warnings-as-errors passes
