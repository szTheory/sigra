---
phase: 06-multi-factor-authentication
fixed_at: 2026-04-08T15:00:00Z
review_path: .planning/phases/06-multi-factor-authentication/06-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 6: Code Review Fix Report

**Fixed at:** 2026-04-08T15:00:00Z
**Source review:** .planning/phases/06-multi-factor-authentication/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: TOTP Secret Stored Unencrypted -- Bypasses cloak_ecto

**Files modified:** `lib/sigra/mfa.ex`, `lib/sigra/testing.ex`
**Commit:** 3c74dc8
**Applied fix:** Replaced `struct/2` + `Ecto.Changeset.change/1` with `Ecto.Changeset.cast/4` on a fresh schema struct so that cloak_ecto's `Encrypted.Binary` type's `dump/1` callback is invoked, ensuring the TOTP secret is encrypted before database storage. Applied to both `confirm_enrollment/5` in `mfa.ex` and `setup_totp/2` in `testing.ex`.

### CR-02: Backup Code Generation Has Modulo Bias

**Files modified:** `lib/sigra/mfa/backup_codes.ex`, `lib/sigra/auth.ex`
**Commit:** 66f1d3b
**Applied fix:** Added `uniform_random/1` private function using rejection sampling to eliminate modulo bias from 4-byte random integers. Values >= `floor(2^32 / range) * range` are rejected and resampled. Applied to backup code generation in `backup_codes.ex` and confirmation code generation in `auth.ex`.

### WR-01: MFA Enrollment Not Wrapped in Transaction -- Partial State on Failure

**Files modified:** `lib/sigra/mfa.ex`
**Commit:** 41b3899
**Applied fix:** Wrapped credential insert and backup code `insert_all` in `Ecto.Multi` transaction in `confirm_enrollment/5` so partial state (credential without backup codes) cannot occur. Also wrapped `cleanup_mfa/5` (backup code deletion, credential deletion, trust revocation) in `Ecto.Multi` for the same atomic guarantee during MFA disable.

### WR-02: MFA Lockout Increment + Lock Is Non-Atomic (TOCTOU Race)

**Files modified:** `lib/sigra/mfa/lockout.ex`
**Commit:** 59f6d78
**Applied fix:** Combined the two separate `update_all` queries (increment + conditional lock) into a single atomic query using a SQL `CASE WHEN` fragment. The `locked_until` is now set conditionally in the same query that increments `failed_attempts`, eliminating the TOCTOU race window.

### WR-03: Generated MFA Challenge Controller Uses Session-Based State Check Instead of Plug-Based

**Files modified:** `priv/templates/sigra.install/mfa_challenge_controller.ex`, `priv/templates/sigra.install/user_auth.ex`, `lib/sigra/plug/fetch_session.ex`
**Commit:** 84fd485
**Applied fix:** Updated the controller template and `user_auth.ex` `require_mfa` plug to check `conn.private[:sigra_session].type == :mfa_pending` via `match?/2` instead of the never-set `get_session(conn, :mfa_pending)`. Added propagation of `:mfa_pending` flag into the Plug session from `FetchSession` plug so that LiveView mounts (which only receive the serialized session map) can correctly detect MFA pending state via `session["mfa_pending"]`.

### WR-04: Undefined Template Binding `settings_url` in emails.ex

**Files modified:** `lib/mix/tasks/sigra.install.ex`
**Commit:** a73c46a
**Applied fix:** Added `settings_url` to the installer binding list, matching the pattern used by `reset_password_url`. The binding resolves to `"#{WebModule.Endpoint.url()}/users/settings"`.

### WR-05: `mfa_user_fixture` in auth_fixtures.ex Passes Wrong Options to setup_totp

**Files modified:** `priv/templates/sigra.install/auth_fixtures.ex`
**Commit:** d8bf183
**Applied fix:** Updated `mfa_user_fixture/1` to pass the required `:config`, `:mfa_credential_schema`, and `:backup_code_schema` options to `Sigra.Testing.setup_totp/2`. Updated `mfa_locked_fixture/1` to pass the required `:config` and `:mfa_credential_schema` options to `Sigra.Testing.simulate_mfa_lockout/2`. Both now call `Auth.sigra_config()` for the config.

### WR-06: RequireMFA Plug Path Comparison Does Not Account for Trailing Slashes

**Files modified:** `lib/sigra/plug/require_mfa.ex`
**Commit:** c1f5e89
**Applied fix:** Added trailing slash normalization via `String.trim_trailing/2` before path comparison. The check now matches both the exact path and the trailing-slash-stripped version against the allowed paths list, preventing infinite redirect loops when `/users/mfa/` is accessed instead of `/users/mfa`.

---

_Fixed: 2026-04-08T15:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
