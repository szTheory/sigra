---
phase: "06"
plan: "03"
subsystem: mfa-telemetry-testing
tags: [telemetry, testing, mfa, cleanup]
dependency_graph:
  requires: ["06-01", "06-02"]
  provides: ["mfa-telemetry-events", "mfa-testing-helpers", "mfa-pending-cleanup"]
  affects: ["lib/sigra/telemetry.ex", "lib/sigra/mfa.ex", "lib/sigra/testing.ex", "lib/sigra/workers/token_cleanup.ex"]
tech_stack:
  added: []
  patterns: ["telemetry-span-wrapping", "one-shot-security-events", "testing-helper-pattern"]
key_files:
  created:
    - test/sigra/testing_test.exs
  modified:
    - lib/sigra/telemetry.ex
    - lib/sigra/mfa.ex
    - lib/sigra/mfa/backup_codes.ex
    - lib/sigra/mfa/trust.ex
    - lib/sigra/testing.ex
    - lib/sigra/workers/token_cleanup.ex
    - test/sigra/telemetry_test.exs
decisions:
  - "MFA lockout and pending_expired events logged at :warning level (security events)"
  - "Testing helpers take opts keyword list with :config for repo access rather than global config"
  - "bypass_mfa operates on conn session rather than DB state for simplicity"
  - "trust_browser delegates to Trust.sign for real HMAC-signed cookies in tests"
metrics:
  duration: "5 minutes"
  completed: "2026-04-08T17:15:44Z"
  tasks_completed: 2
  tasks_total: 2
  test_count: 39
  test_failures: 0
---

# Phase 6 Plan 3: MFA Telemetry, Testing Helpers, and TokenCleanup Summary

MFA telemetry spans on enroll/verify/disable/regenerate, one-shot events for lockout/pending_expired/trust, 8 testing helpers, and mfa_pending session cleanup in TokenCleanup worker.

## What Was Done

### Task 1: MFA Telemetry Event Catalog and Integration (826945c)

Added comprehensive MFA telemetry instrumentation:

**Span events (start/stop/exception):**
- `[:sigra, :mfa, :enroll]` -- wraps TOTP enrollment
- `[:sigra, :mfa, :verify]` -- wraps TOTP and backup code verification (with `method: :totp | :backup_code`)
- `[:sigra, :mfa, :disable]` -- wraps MFA disable (with `admin: boolean`)
- `[:sigra, :mfa, :backup_codes, :regenerate]` -- wraps backup code regeneration

**One-shot events:**
- `[:sigra, :mfa, :lockout]` -- emitted when verification triggers lockout threshold
- `[:sigra, :mfa, :pending_expired]` -- emitted when mfa_pending sessions are cleaned up
- `[:sigra, :mfa, :trust, :granted]` -- emitted when trust cookie is signed
- `[:sigra, :mfa, :trust, :revoked_all]` -- emitted when all trust cookies are revoked

Added `mfa_events/0` helper for custom handler attachment. MFA lockout and pending_expired events are classified as security events (logged at `:warning` level).

### Task 2: Testing Helpers and TokenCleanup Extension (bf17b7c)

**8 MFA testing helpers in `Sigra.Testing`:**
1. `setup_totp/2` -- creates fully enrolled MFA credential with backup codes
2. `generate_totp_code/1` -- generates valid TOTP code via `NimbleTOTP.verification_code/1`
3. `create_backup_codes/2` -- generates and stores backup codes for a user
4. `bypass_mfa/1` -- sets conn session to `:standard` to skip MFA flow in tests
5. `simulate_mfa_lockout/2` -- sets failed_attempts to threshold and locked_until
6. `assert_mfa_enabled/2` -- asserts user has enabled MFA credential
7. `assert_mfa_disabled/2` -- asserts user has no enabled MFA credential
8. `trust_browser/3` -- sets signed trust cookie on conn

**TokenCleanup extension:**
- Added `cleanup_mfa_pending_sessions/1` that deletes `mfa_pending` sessions older than `pending_timeout`
- Emits `[:sigra, :mfa, :pending_expired]` telemetry event for each expired session

## Deviations from Plan

### Minor Adjustments

**1. [Rule 2 - Missing] log_in_user mfa: :bypass not added**
- **Issue:** The plan specified updating `log_in_user/2` to accept `mfa: :bypass` option, but the existing `log_in_user` is not yet defined in `Sigra.Testing` (it's referenced as a stub pattern). The `bypass_mfa/1` helper achieves the same purpose (setting session type to `:standard`).
- **Resolution:** `bypass_mfa/1` provides the equivalent functionality. `log_in_user` with `mfa: :bypass` can be wired when `log_in_user` is implemented as a full helper.

**2. [Rule 2 - Scope] Testing helpers use opts pattern instead of positional args**
- **Issue:** Plan showed `setup_totp(user, opts)` with config baked in. Since testing helpers need repo access, they accept `:config` in opts keyword list.
- **Resolution:** Consistent opts pattern across all 8 helpers for uniform API.

## Verification Results

```
mix test test/sigra/telemetry_test.exs test/sigra/testing_test.exs --seed 0
39 tests, 0 failures

mix compile --warnings-as-errors
Generated sigra app (no warnings)
```

## Self-Check: PASSED

- [x] lib/sigra/telemetry.ex -- FOUND, contains MFA event catalog
- [x] lib/sigra/mfa.ex -- FOUND, contains Sigra.Telemetry.span calls
- [x] lib/sigra/mfa/trust.ex -- FOUND, contains telemetry events
- [x] lib/sigra/mfa/backup_codes.ex -- FOUND, contains telemetry span
- [x] lib/sigra/testing.ex -- FOUND, contains 8 MFA helpers
- [x] lib/sigra/workers/token_cleanup.ex -- FOUND, contains cleanup_mfa_pending_sessions
- [x] test/sigra/telemetry_test.exs -- FOUND, MFA telemetry tests
- [x] test/sigra/testing_test.exs -- FOUND, testing helper tests
- [x] Commit 826945c -- FOUND
- [x] Commit bf17b7c -- FOUND
