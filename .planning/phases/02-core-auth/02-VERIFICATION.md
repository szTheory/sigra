---
phase: 02-core-auth
verified: 2026-04-06T18:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 2: Core Auth Verification Report

**Phase Goal:** A developer's users can register with email/password, log in, and log out, with passwords hashed using Argon2id and enumeration prevention on by default
**Verified:** 2026-04-06T18:30:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can register with an email and password; password is stored as Argon2id hash, never plaintext | VERIFIED | `Sigra.Auth.register/3` delegates to repo insert with changeset that calls `Sigra.Crypto.hash_password/1` (Argon2id). User schema template calls `Sigra.PasswordPolicy.validate/1` then `put_change(:hashed_password, ...)` and `delete_change(:password)`. Generated auth context delegates to `Sigra.Auth.register/3`. |
| 2 | User can log in with correct email/password and receives a session | VERIFIED | `Sigra.Auth.authenticate/3` normalizes email, queries user, calls `Crypto.verify_with_upgrade/3`. On success returns `{:ok, user}` with failed_login_attempts reset. Generated auth context's `get_user_by_email_and_password/2` delegates to `SigraAuth.authenticate/3`. Session controller wires login to `UserAuth.log_in_user/2`. |
| 3 | User can log out from any page and the session is invalidated | VERIFIED | `SessionController.delete/2` emits logout telemetry and calls `UserAuth.log_out_user/1`. Generated auth context has `delete_user_session_token/1` that deletes from DB. |
| 4 | A user migrating from bcrypt transparently receives an Argon2id hash on their next successful login | VERIFIED | `Crypto.verify_with_upgrade/3` detects `$2b$`/`$2a$` prefix via `bcrypt_hash?/1`, verifies with `Sigra.Hashers.Bcrypt`, returns `{:ok, :valid, new_hash}` where new_hash is Argon2id. `Auth.authenticate/3` applies hash upgrade via `handle_valid_login/5` which passes `%{hashed_password: new_hash}` to `repo.update`. `Hashers.Bcrypt` uses `Code.ensure_loaded?` gate. `bcrypt_elixir` is optional dep in mix.exs. |
| 5 | User can request a magic link and authenticate via the emailed link without a password | VERIFIED | `Sigra.Auth.request_magic_link/3` generates hashed token, stores with "magic_link" context, returns `{:ok, {raw_token, url}}`. `verify_magic_link/3` decodes token, checks 10-min TTL, deletes token (single-use), auto-confirms user. Generated auth context has `request_magic_link/2` and `verify_magic_link/1`. Login LiveView has dual-mode form with magic link section. Session controller handles `_action: "magic_link"` and `magic_link/2` action. UserToken template has `build_magic_link_token/1` and `verify_magic_link_token_query/1` with 600-second TTL. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/auth.ex` | Auth orchestrator | VERIFIED | 299 lines. Implements register/3, authenticate/3, request_magic_link/3, verify_magic_link/3. All with telemetry, enumeration prevention. |
| `lib/sigra/email.ex` | Email normalization | VERIFIED | 83 lines. normalize/1 with trim+downcase+NFKC. validate_format/1 with regex and 160-char limit. |
| `lib/sigra/password_policy.ex` | Password validation + strength | VERIFIED | 343 lines. validate/2 on changesets, check_strength/1, check_breached/1. NIST-compliant defaults (min 8). |
| `lib/sigra/password_policy/common_passwords.ex` | Compile-time password list | VERIFIED | 1138 bytes. @external_resource + MapSet.new. common?/1 with case-insensitive check. |
| `priv/data/common_passwords.txt` | 10k common passwords | VERIFIED | 10,000 lines. |
| `lib/sigra/hashers/bcrypt.ex` | Bcrypt hasher wrapper | VERIFIED | 56 lines. @behaviour Sigra.Hasher. Code.ensure_loaded? gate. |
| `lib/sigra/crypto.ex` | Extended crypto with upgrade | VERIFIED | 268 lines. verify_with_upgrade/2,3, needs_rehash?/2, bcrypt_hash?/1, argon2_hash?/1. |
| `priv/templates/sigra.install/login_live.ex` | Dual-mode login LiveView | VERIFIED | 72 lines. Magic link form + divider + password form. |
| `priv/templates/sigra.install/registration_live.ex` | Registration with strength | VERIFIED | 145 lines. phx-change="validate" calls check_strength/1. Colored bar + label + suggestions. |
| `priv/templates/sigra.install/login_html.ex` | Controller-mode login | VERIFIED | 64 lines. Same dual-mode layout without LiveView lifecycle. |
| `priv/templates/sigra.install/registration_html.ex` | Controller-mode registration | VERIFIED | 37 lines. Static form without real-time strength (noted in moduledoc). |
| `priv/templates/sigra.install/session_controller.ex` | Session + magic link handling | VERIFIED | 75 lines. magic_link action, create with _action "magic_link", logout telemetry. |
| `priv/templates/sigra.install/user.ex` | Updated user schema | VERIFIED | Has failed_login_attempts, password_changed_at fields. Calls Sigra.Email.normalize/1, Sigra.PasswordPolicy.validate/1. |
| `priv/templates/sigra.install/user_token.ex` | Magic link token support | VERIFIED | @magic_link_validity_in_seconds 600. build_magic_link_token/1, verify_magic_link_token_query/1. |
| `priv/templates/sigra.install/auth.ex` | Generated context | VERIFIED | Delegates to Sigra.Auth. Has request_magic_link/2, verify_magic_link/1, :email_taken handling. |
| `priv/templates/sigra.install/migration.exs` | Phase 2 columns | VERIFIED | failed_login_attempts + password_changed_at in all 3 adapter branches (postgres/mysql/sqlite). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/sigra/auth.ex` | `lib/sigra/crypto.ex` | `Sigra.Crypto.verify_with_upgrade` | WIRED | Line 104: `case Crypto.verify_with_upgrade(password, hashed_password)` |
| `lib/sigra/auth.ex` | `lib/sigra/token.ex` | `Sigra.Token.generate_hashed_token` | WIRED | Line 159: `{raw_token, hashed_token} = Token.generate_hashed_token()` |
| `lib/sigra/auth.ex` | `lib/sigra/telemetry.ex` | Telemetry events | WIRED | Lines 50, 55, 109, 252: Telemetry.span and Telemetry.event calls |
| `lib/sigra/auth.ex` | `lib/sigra/email.ex` | Email normalization | WIRED | Line 98: `Email.normalize()` |
| `lib/sigra/crypto.ex` | `lib/sigra/hashers/bcrypt.ex` | Code.ensure_loaded? gate | WIRED | Line 244: `Code.ensure_loaded?(Bcrypt)` then `Sigra.Hashers.Bcrypt.verify_password` |
| `lib/sigra/password_policy.ex` | `common_passwords.ex` | CommonPasswords.common? | WIRED | Line 234: `CommonPasswords.common?(password)` |
| Template auth.ex | `lib/sigra/auth.ex` | SigraAuth delegation | WIRED | Line 14: `alias Sigra.Auth, as: SigraAuth`. Lines 87, 48, 116, 129: `SigraAuth.register/3`, `SigraAuth.authenticate/3`, etc. |
| Template user.ex | `lib/sigra/password_policy.ex` | PasswordPolicy.validate | WIRED | Line 59: `Sigra.PasswordPolicy.validate()` |
| Template user.ex | `lib/sigra/email.ex` | Email.normalize | WIRED | Line 50: `update_change(:email, &Sigra.Email.normalize/1)` |
| Template registration_live.ex | `password_policy.ex` | check_strength | WIRED | Line 107: `Sigra.PasswordPolicy.check_strength(password)` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All phase 2 tests pass | `mix test test/sigra/email_test.exs test/sigra/password_policy_test.exs test/sigra/crypto_test.exs test/sigra/auth_test.exs` | 79 tests, 0 failures | PASS |
| Full test suite (no regressions) | `mix test` | 201 tests, 0 failures | PASS |
| Compilation clean | `mix compile --warnings-as-errors` | Generated sigra app (0 warnings) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUTH-01 | 02-02 | User can register with email and password | SATISFIED | `Sigra.Auth.register/3` + generated `register_user/1` + registration LiveView/HTML templates |
| AUTH-02 | 02-01 | Passwords hashed with Argon2id | SATISFIED | `Sigra.Crypto.hash_password/1` uses `@default_hasher Sigra.Hashers.Argon2`. User schema calls `Sigra.Crypto.hash_password(password)` in `maybe_hash_password/2`. |
| AUTH-03 | 02-01 | Transparent bcrypt-to-Argon2id migration | SATISFIED | `Sigra.Crypto.verify_with_upgrade/3` detects bcrypt prefix, verifies, returns `{:ok, :valid, new_hash}`. `Sigra.Auth.authenticate/3` persists new hash. `Sigra.Hashers.Bcrypt` with Code.ensure_loaded? gate. |
| AUTH-04 | 02-02 | User can log in with email and password | SATISFIED | `Sigra.Auth.authenticate/3` + generated `get_user_by_email_and_password/2` + dual-mode login LiveView/HTML + SessionController |
| AUTH-05 | 02-02 | User can log out from any page | SATISFIED | `SessionController.delete/2` calls `UserAuth.log_out_user/1` with telemetry. Generated `delete_user_session_token/1` deletes from DB. |
| AUTH-06 | 02-02 | Magic link / passwordless email authentication | SATISFIED | `Sigra.Auth.request_magic_link/3` + `verify_magic_link/3`. Single-use, 10-min TTL, rate-limited. Dual-mode login form. SessionController handles magic link create + verify. |
| AUTH-07 | 02-01 | NIST-compliant password policies | SATISFIED | `Sigra.PasswordPolicy.validate/2` with min 8, max 72 bytes, common password rejection. `check_strength/1` for UI feedback. Composition rules configurable but off by default per NIST. |

No orphaned requirements found. All 7 AUTH requirements are mapped to Phase 2 in REQUIREMENTS.md and all 7 are covered by plans 02-01 and 02-02.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `priv/templates/sigra.install/auth.ex` | 250, 260, 296, 303 | "Phase 3 will deliver via Swoosh/Oban" comments | Info | Expected -- email delivery is Phase 3 scope. Functions work correctly, returning tokens/URLs. Not a stub. |
| `priv/templates/sigra.install/registration_live.ex` | 82 | "Phase 3 will send confirmation email here" | Info | Expected -- confirmation email delivery is Phase 3. Registration itself works. |

No blockers or warnings found.

### Human Verification Required

### 1. Dual-Mode Login Form Visual Layout

**Test:** Run `mix sigra.install` in a test Phoenix app and navigate to `/users/log_in`
**Expected:** Magic link section at top, "or sign in with password" divider, password section below. Both forms submit correctly.
**Why human:** Visual layout, form interaction, and CSS styling cannot be verified programmatically from template source.

### 2. Password Strength Indicator Real-Time Feedback

**Test:** Navigate to `/users/register` and type passwords of varying strength
**Expected:** Colored bar updates in real-time (red/weak, yellow/fair, green/strong). Suggestions list appears and updates as password changes.
**Why human:** LiveView phx-change interaction and visual feedback require browser testing.

### 3. Magic Link End-to-End Flow

**Test:** Enter email on login page, click "Send magic link", then visit the generated URL
**Expected:** Token is created, verification logs user in, token is consumed (second visit shows error).
**Why human:** Multi-step flow crossing controller + auth context + DB requires integration testing with running app.

### Gaps Summary

No gaps found. All 5 success criteria from the roadmap are verified. All 7 requirement IDs (AUTH-01 through AUTH-07) are satisfied. All artifacts exist, are substantive (no stubs), and are properly wired. The full test suite passes with 201 tests, 0 failures, and compilation is clean with warnings-as-errors.

---

_Verified: 2026-04-06T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
