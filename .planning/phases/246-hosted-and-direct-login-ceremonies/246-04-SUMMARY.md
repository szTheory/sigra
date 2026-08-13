---
phase: 246-hosted-and-direct-login-ceremonies
plan: 04
subsystem: authentication
tags: [elixir, ecto, postgresql, direct-login, mfa, app-sessions]
requires:
  - phase: 245-opaque-app-session-core
    provides: digest-only opaque app-session issuance
  - phase: 246-03
    provides: hosted ceremony transaction and audit conventions
provides:
  - Static-policy direct password facade with uniform public failures
  - Digest-only five-minute direct MFA challenges
  - Locked MFA consume-and-issue transaction reusing AppSession
affects: [generated direct-login host facade, first-party native clients]
tech-stack:
  added: []
  patterns: [host-owned verification callbacks, opaque digest persistence, Ecto.Multi row locks]
key-files:
  created:
    - test/sigra/app_login_direct_test.exs
  modified:
    - lib/sigra/app_login.ex
    - lib/sigra/app_login/attempt.ex
    - test/support/app_login_schemas.ex
decisions:
  - Browser-required policy is evaluated before invoking the password verifier.
  - Direct MFA stores only a decoded-token SHA-256 digest and trusted binding facts.
  - MFA factor validation, challenge consumption, and opaque app-session issuance compose in one transaction.
metrics:
  duration: 15m
  tasks_completed: 2
  files_changed: 4
status: complete
---

# Phase 246 Plan 04: Direct Password and MFA Ceremony Summary

**A host-owned direct password/MFA facade that issues the existing opaque app-session contract while preserving browser-only policy and uniform denial.**

## Accomplishments

- Added direct password entry for static `:password_allowed` profiles; successful non-MFA authentication delegates to `Sigra.AppSession.issue/4`.
- Enforced `:browser_required` before invoking a password verifier and normalized profile, credential, callback, and account failures to `:invalid_credentials`.
- Added opaque, digest-only direct-MFA challenges with exact 300-second expiry, trusted profile/user/client bindings, `FOR UPDATE` consumption, and TOTP/backup delegate support.
- Added PostgreSQL coverage for direct credential parity, policy short-circuiting, uniform failures, challenge persistence, factor failure retention, successful TOTP/backup completion, and replay denial.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_direct_test.exs test/sigra/app_login_test.exs --trace` — PASS (12 tests, 0 failures).
- `mix format --check-formatted lib/sigra/app_login.ex lib/sigra/app_login/attempt.ex test/sigra/app_login_direct_test.exs test/support/app_login_schemas.ex` — PASS.
- Direct source contract scan for grant, scope, client-secret, and authority vocabulary — PASS (no matches).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Digest opaque challenges using decoded token bytes**
- **Found during:** Task 2
- **Issue:** `Sigra.Token.generate_hashed_token/0` stores the hash of decoded random bytes, while hashing the URL-safe challenge string would make completion impossible.
- **Fix:** Direct challenge lookup now base64url-decodes the raw challenge before hashing, matching the stored digest representation.
- **Files modified:** `lib/sigra/app_login/attempt.ex`, `test/sigra/app_login_direct_test.exs`
- **Verification:** Direct TOTP/backup completion and replay tests pass.

**2. [Rule 3 - Blocking issue] Extended test challenge schema for persisted ceremony facts**
- **Found during:** Task 2
- **Issue:** The shared test schema did not expose the generated challenge fields needed to assert bindings, expiry, and consumption.
- **Fix:** Added direct-MFA fields to the test-only schema and provisioned its PostgreSQL table in the direct-ceremony suite.
- **Files modified:** `test/support/app_login_schemas.ex`, `test/sigra/app_login_direct_test.exs`
- **Verification:** PostgreSQL direct-ceremony suite passes independently.

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking test-fixture issue). **Impact:** No public-contract expansion; both changes make the planned security assertions executable.

## Known Stubs

None.

## Self-Check: PASSED

- Created direct-ceremony test and implementation files exist.
- TDD RED and GREEN commits exist in the current branch history.
