---
phase: 06-multi-factor-authentication
plan: 01
subsystem: mfa-core
tags: [mfa, totp, backup-codes, trust-cookie, lockout]
dependency_graph:
  requires: [sigra-config, sigra-error, sigra-lockout, sigra-identity, sigra-token]
  provides: [sigra-mfa, sigra-mfa-credential, sigra-mfa-backup-codes, sigra-mfa-trust, sigra-mfa-lockout]
  affects: [mix.exs, lib/sigra/config.ex, lib/sigra/error.ex]
tech_stack:
  added: [nimble_totp-1.0, eqrcode-0.2.1]
  patterns: [library-struct, hmac-trust-cookie, atomic-update-all, totp-drift-replay]
key_files:
  created:
    - lib/sigra/mfa.ex
    - lib/sigra/mfa/credential.ex
    - lib/sigra/mfa/backup_codes.ex
    - lib/sigra/mfa/trust.ex
    - lib/sigra/mfa/lockout.ex
    - test/sigra/mfa_test.exs
    - test/sigra/mfa/backup_codes_test.exs
    - test/sigra/mfa/trust_test.exs
    - test/sigra/mfa/lockout_test.exs
    - test/sigra/mfa/config_test.exs
    - test/sigra/mfa/error_test.exs
    - test/sigra/mfa/credential_test.exs
  modified:
    - mix.exs
    - mix.lock
    - lib/sigra/config.ex
    - lib/sigra/error.ex
decisions:
  - "NimbleTOTP kept as dependency (not copy-paste) per D-02: stable, minimal, gets upstream fixes"
  - "EQRCode as optional dep: enroll/2 returns nil SVG when not loaded, not a hard requirement"
  - "verify_totp/4 exposed as public function for testability while documented as internal helper"
  - "Credential.from_schema/1 uses Map.fetch to preserve struct defaults when source map lacks keys"
metrics:
  duration: "9 minutes"
  completed: "2026-04-08"
  tasks: 2
  tests_added: 61
  tests_total: 712
  files_changed: 16
  lines_added: 1794
---

# Phase 6 Plan 1: MFA Core Library Modules Summary

Core MFA library layer with TOTP enrollment, backup codes, trust cookies, and lockout -- all security-critical logic in the library dep for patch propagation.

## What Was Built

### Task 1: Dependencies, Config, Error, and Credential struct

Added `nimble_totp ~> 1.0` (required) and `eqrcode ~> 0.2.1` (optional) to mix.exs. Extended `Sigra.Config` with an `mfa:` section containing 10 NimbleOptions-validated keys: `enabled`, `totp_issuer`, `totp_drift_steps`, `backup_code_count`, `trust_enabled`, `trust_ttl`, `lockout_threshold`, `lockout_duration`, `pending_timeout`, `show_trust_option`. Added `Sigra.Error.MFAError` defexception with 7 error codes and safe_message mappings. Created `Sigra.MFA.Credential` library struct following the `Sigra.Identity` pattern with `from_schema/1` and `to_params/1`.

### Task 2: MFA orchestrator, BackupCodes, Trust, and Lockout modules

**Sigra.MFA** -- Top-level orchestrator with `enroll/2` (NimbleTOTP secret + otpauth URI + optional EQRCode SVG), `confirm_enrollment/5`, `verify/4` (drift + replay prevention + lockout integration), `verify_backup/4`, `disable/4` (code-verified), `disable!/3` (admin force), `enabled?/2`, `status/2`. Internal `verify_totp/4` implements Pattern 5 from research: checks +/- drift steps, rejects codes at or below `last_verified_step`.

**Sigra.MFA.BackupCodes** -- `generate/1` produces XXXX-XXXX format codes using `:crypto.strong_rand_bytes/1`, hashed with SHA-256. `consume/4` uses atomic `update_all` with `WHERE used_at IS NULL`. `remaining_count/3` and `regenerate/4` for full lifecycle.

**Sigra.MFA.Trust** -- HMAC trust cookies via `Plug.Crypto.sign/4` with salt `"sigra-mfa-trust"`. Payload is `{user_id, trust_epoch, issued_at}`. `verify/5` checks HMAC + user_id match + epoch match + TTL. `revoke_all/3` increments `mfa_trust_epoch` via `update_all`. Cookie constants: `_sigra_mfa_trust`, HttpOnly, Secure, SameSite=Lax.

**Sigra.MFA.Lockout** -- Per-credential lockout mirroring `Sigra.Lockout` pattern. `check/2` returns `:ok` or `{:error, :lockout, remaining_seconds}`. `increment/4` uses atomic `update_all` with `inc: [failed_attempts: 1]`. `reset/3` clears state. Uses config `mfa.lockout_threshold` and `mfa.lockout_duration`.

## Threat Mitigations Applied

| Threat ID | Mitigation |
|-----------|-----------|
| T-06-01 (TOTP replay) | `verify_totp/4` tracks `last_verified_step`, rejects step <= last (D-41) |
| T-06-02 (Trust cookie tampering) | `Plug.Crypto.sign/4` HMAC with `secret_key_base` (D-46) |
| T-06-04 (Backup code disclosure) | SHA-256 hashed storage, never retrievable after display (D-13, D-20) |
| T-06-05 (MFA DoS) | Per-credential lockout counter on DB, not per-session (D-31) |
| T-06-07 (Trust cookie user mismatch) | `verify/5` compares `user_id` + `epoch` in payload vs current user (Pitfall 6) |
| T-06-08 (TOTP secret in DB) | Encrypted secret field passed through to cloak_ecto in generated schema (D-09) |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 (RED) | caacbb5 | Failing tests for config, error, credential |
| 1 (GREEN) | 52a25f4 | Deps, config mfa section, MFAError, Credential struct |
| 2 (RED) | 8a0ed8f | Failing tests for MFA, BackupCodes, Trust, Lockout |
| 2 (GREEN) | e913806 | All 4 MFA library modules implemented |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Credential.from_schema/1 overriding struct defaults**
- **Found during:** Task 1
- **Issue:** Using `Map.get(schema, field)` returned nil for missing keys, overriding the `failed_attempts: 0` struct default
- **Fix:** Changed to `Map.fetch/2` with `:error` check to only set fields present in the source map
- **Files modified:** lib/sigra/mfa/credential.ex
- **Commit:** 52a25f4

**2. [Rule 1 - Bug] Trust test URL-encoded issuer name**
- **Found during:** Task 2
- **Issue:** Test asserted `=~ "My Cool App"` but otpauth URI encodes spaces as `%20`
- **Fix:** Changed assertion to match `"My%20Cool%20App"`
- **Files modified:** test/sigra/mfa_test.exs
- **Commit:** e913806

## Self-Check: PASSED

All 12 created files verified present. All 4 commits verified in git log.
