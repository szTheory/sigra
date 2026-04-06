# Phase 2: Core Auth - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-06
**Phase:** 02-core-auth
**Areas discussed:** Magic link strategy, Bcrypt migration, Password policy, Registration flow, Login attempt tracking, Session token format, Email normalization, Testing strategy, Error message strategy, Sigra.Auth module, Migration strategy, LiveView vs controller auth, Config defaults

---

## Magic Link Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Dual-mode | Both methods always available on same page | ✓ |
| Passwordless-first | Magic link primary, password optional | |
| Password-primary | Magic link secondary/hidden | |

**User's choice:** Dual-mode -- both password and magic link on same login page
**Additional decisions:** 10min single-use TTL, token in URL path, login + confirmation scope, stub email delivery for Phase 3, rate limit 3/email/15min, same-page two-section layout

## Bcrypt Migration

**Decisions made through extended discussion:**
- Prefix detection ($2b$/$2a$) -- not schema field or config-based
- Optional dep with Code.ensure_loaded? gate
- Thin wrapper: Sigra.Hashers.Bcrypt implements Hasher behaviour
- Stale hashes left as-is indefinitely
- Three-way return: {:ok, :valid} | {:ok, :valid, new_hash} | {:error, :invalid}
- Use Argon2.needs_rehash?/2 for cost param upgrades
- Logic in Sigra.Crypto, not generated context
- Best-effort non-transactional hash update
- Emit [:sigra, :auth, :hash_upgraded] telemetry event
- Test with pre-computed fixture hashes
- No reporting Mix task, telemetry only
- Argon2id + bcrypt only, no arbitrary algorithm plugins

## Password Policy

| Option | Description | Selected |
|--------|-------------|----------|
| NIST 8-char min | Follow NIST SP 800-63B | ✓ |
| 12-char min | Keep Phase 1 setting | |

**Additional decisions:**
- Library module: Sigra.PasswordPolicy (not in generated code)
- 72-byte max (Argon2 input limit)
- HIBP: optional, off by default
- Built-in strength analysis with check_strength/1 returning {:weak/:fair/:strong, suggestions}
- Top-10k common passwords list embedded at compile time
- Composition rules: off by default, configurable (require_uppercase, etc.)
- Separate function for strength (not in changeset)
- Optional password expiry via :password_max_age config
- No password history/reuse prevention
- Same policy everywhere

**User correction:** Chose "Structured strength feedback" over "Changeset errors" -- wants {:weak/:fair/:strong, suggestions} pattern

## Registration Flow

- Auto-login after registration (not redirect to login)
- Email + password only, clear extension points for custom fields
- Phase 2 plumbing for :require_confirmation config
- Standard telemetry event on register
- Real-time password strength via phx-change
- Email uniqueness on submit only (anti-enumeration)
- Generic duplicate email message

## Login Attempt Tracking

- Add failed_login_attempts + locked_at columns now (in Phase 1 migration template)
- Increment + reset in Phase 2, lockout logic in Phase 4
- Per-account only in DB, per-IP via Hammer in Phase 4
- No increment for non-existent emails
- Telemetry includes failed_attempts_before count

## Session Token Format

- 32 bytes, URL-safe base64
- Cookie: _{otp_app}_user_session
- Minimal metadata now, extend in Phase 4
- 60-day default TTL, configurable

## Email Normalization

- Both layers: changeset normalization AND citext/collation
- NFKC Unicode normalization
- No Gmail dot/plus stripping
- Basic format validation (~r/^[^\s]+@[^\s]+$/, max 160)
- Library utility: Sigra.Email.normalize/1

## Testing Strategy

- Unit + integration tests
- Sigra.Test.Support module for library integration tests
- Postgres in CI (primary)

## Error Message Strategy

- Login: always generic "Invalid email or password"
- Registration: generic for email, specific for password
- Error atoms are public documented API

## Sigra.Auth Module

- Yes, library orchestrator (register/2, authenticate/2, etc.)
- Repo passed as argument
- User schema from Config

## Migration Strategy

- Modify Phase 1 migration template (no existing users)
- Add password_changed_at column too

## LiveView vs Controller Auth

- Controllers primary, LiveView optional (--live/--no-live flag)
- LiveView uses trigger_submit to HTTP POST
- Phase 2 adds missing controller templates

## Config Defaults

- Password: min 8, max 72 bytes, no composition rules, common check on, HIBP off
- Magic link: 10min TTL, 3/15min rate limit
- Session: 60-day TTL

## Claude's Discretion

- Strength scoring algorithm internals
- Common password list source
- HEEx template styling
- Test helper API design
- Argon2id cost parameters

## Deferred Ideas

None
