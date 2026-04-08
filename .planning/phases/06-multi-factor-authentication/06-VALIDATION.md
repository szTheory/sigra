---
phase: 6
slug: multi-factor-authentication
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-08
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/mfa` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/mfa`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | MFA-01 | T-06-01 | TOTP secret encrypted at rest via cloak_ecto | unit | `mix test test/sigra/mfa/credential_test.exs` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | MFA-01 | T-06-02 | Enrollment requires sudo mode (re-auth) | integration | `mix test test/sigra/mfa/enroll_test.exs` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | MFA-02 | T-06-03 | TOTP codes validated with drift window +/-1 step | unit | `mix test test/sigra/mfa/totp_test.exs` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | MFA-02 | T-06-04 | TOTP replay prevention via last_verified_step | unit | `mix test test/sigra/mfa/totp_test.exs` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 1 | MFA-03 | T-06-05 | Backup codes SHA-256 hashed, never stored plaintext | unit | `mix test test/sigra/mfa/backup_codes_test.exs` | ❌ W0 | ⬜ pending |
| 06-02-02 | 02 | 1 | MFA-03 | T-06-06 | Atomic consumption via UPDATE WHERE used_at IS NULL | unit | `mix test test/sigra/mfa/backup_codes_test.exs` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 2 | MFA-04 | T-06-07 | mfa_pending blocks all routes except /users/mfa and /users/log_out | integration | `mix test test/sigra/plug/require_mfa_test.exs` | ❌ W0 | ⬜ pending |
| 06-03-02 | 03 | 2 | MFA-04 | T-06-08 | Session token rotated on MFA completion (prevents fixation) | integration | `mix test test/sigra/mfa/session_gate_test.exs` | ❌ W0 | ⬜ pending |
| 06-03-03 | 03 | 2 | MFA-04 | — | mfa_pending sessions expire after configurable timeout | unit | `mix test test/sigra/mfa/session_gate_test.exs` | ❌ W0 | ⬜ pending |
| 06-04-01 | 04 | 2 | MFA-05 | T-06-09 | Trust cookie HMAC-signed, verified with epoch counter | unit | `mix test test/sigra/mfa/trust_test.exs` | ❌ W0 | ⬜ pending |
| 06-04-02 | 04 | 2 | MFA-05 | T-06-10 | Trust epoch increment invalidates all trust cookies | unit | `mix test test/sigra/mfa/trust_test.exs` | ❌ W0 | ⬜ pending |
| 06-05-01 | 05 | 3 | MFA-06 | T-06-11 | Per-user lockout after 5 failed attempts, 15-min window | unit | `mix test test/sigra/mfa/lockout_test.exs` | ❌ W0 | ⬜ pending |
| 06-05-02 | 05 | 3 | MFA-06 | — | Lockout counter independent of login lockout | integration | `mix test test/sigra/mfa/lockout_test.exs` | ❌ W0 | ⬜ pending |
| 06-06-01 | 06 | 3 | MFA-07 | T-06-12 | Enumeration-safe: same error for invalid TOTP and backup code | unit | `mix test test/sigra/mfa/error_test.exs` | ❌ W0 | ⬜ pending |
| 06-07-01 | 07 | 4 | MFA-08 | — | Disable requires sudo + current TOTP or backup code | integration | `mix test test/sigra/mfa/disable_test.exs` | ❌ W0 | ⬜ pending |
| 06-07-02 | 07 | 4 | MFA-08 | — | Cascade cleanup: delete credential, codes, increment epoch | unit | `mix test test/sigra/mfa/disable_test.exs` | ❌ W0 | ⬜ pending |
| 06-08-01 | 08 | 4 | MFA-09 | — | NimbleOptions validates all mfa: config keys | unit | `mix test test/sigra/config_test.exs` | ❌ W0 | ⬜ pending |
| 06-08-02 | 08 | 4 | MFA-09 | — | Telemetry spans emitted for all MFA operations | unit | `mix test test/sigra/mfa/telemetry_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/mfa/credential_test.exs` — stubs for MFA-01
- [ ] `test/sigra/mfa/totp_test.exs` — stubs for MFA-02
- [ ] `test/sigra/mfa/backup_codes_test.exs` — stubs for MFA-03
- [ ] `test/sigra/mfa/session_gate_test.exs` — stubs for MFA-04
- [ ] `test/sigra/mfa/trust_test.exs` — stubs for MFA-05
- [ ] `test/sigra/mfa/lockout_test.exs` — stubs for MFA-06
- [ ] `test/sigra/mfa/error_test.exs` — stubs for MFA-07
- [ ] `test/sigra/mfa/disable_test.exs` — stubs for MFA-08
- [ ] `test/sigra/plug/require_mfa_test.exs` — stubs for MFA-04 plug
- [ ] `test/support/mfa_helpers.exs` — shared MFA test fixtures

*Existing test infrastructure (ExUnit, SQL Sandbox) covers framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| QR code scans correctly in authenticator app | MFA-01 | Requires physical device or emulator | 1. Enroll TOTP 2. Scan QR with Google Authenticator 3. Verify code works |
| Auto-submit JS fires on 6-digit entry | MFA-04 | Browser JS behavior | 1. Open MFA challenge page 2. Enter 6 digits 3. Form auto-submits |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
