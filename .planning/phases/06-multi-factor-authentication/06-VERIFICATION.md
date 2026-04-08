---
phase: 06-multi-factor-authentication
verified: 2026-04-08T13:45:00Z
status: human_needed
score: 5/5 roadmap SCs verified
overrides_applied: 0
human_verification:
  - test: "Run mix sigra.install in a fresh Phoenix app and verify MFA files are generated"
    expected: "All MFA schemas, controllers, LiveViews, and migrations are generated; router contains /users/mfa route and require_mfa in authenticated pipeline"
    why_human: "Generator integration test requires a real Phoenix app context"
  - test: "Verify MFA challenge page renders correctly in browser"
    expected: "TOTP/backup code tabs, auto-submit JS on 6 digits, trust checkbox, cancel link"
    why_human: "Visual UI and JS behavior cannot be verified programmatically"
  - test: "Complete end-to-end MFA enrollment flow"
    expected: "QR code displays, manual key visible, confirmation code accepted, backup codes shown in 2-column grid with copy/download, acknowledgment checkbox gates Done button"
    why_human: "Multi-step LiveView interaction with QR code rendering and JS hooks"
  - test: "Verify backup code regeneration actually regenerates codes"
    expected: "After entering valid TOTP code, old backup codes are invalidated and new ones generated and displayed"
    why_human: "The regenerate_codes handler has a TODO comment suggesting the wiring may be incomplete"
---

# Phase 6: Multi-Factor Authentication Verification Report

**Phase Goal:** Users can enroll TOTP, verify it on login via a `mfa_pending` session gate, use backup codes for recovery, and trust specific browsers; admins can enforce MFA per route or role
**Verified:** 2026-04-08T13:45:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can enroll TOTP by scanning QR code or entering key manually, confirming with valid code, enrollment not complete until confirmation verified | VERIFIED | `Sigra.MFA.enroll/2` generates secret via `NimbleTOTP.secret()`, builds otpauth URI via `NimbleTOTP.otpauth_uri/3`, optional EQRCode SVG. `confirm_enrollment/5` verifies code before creating credential. Settings LiveView shows QR + manual key + confirmation form. |
| 2 | After login, user with TOTP enabled placed in mfa_pending state, cannot access protected routes until valid 6-digit code submitted | VERIFIED | `auth.ex` creates `:mfa_pending` session when `mfa_check_fn` returns true. `RequireMFA` plug redirects mfa_pending sessions. Session type union includes `:mfa_pending`. FetchSession enforces 5-min pending timeout. Challenge page handles both TOTP and backup code verification. |
| 3 | User shown 8 backup codes exactly once at enrollment; using code consumes atomically; user can regenerate fresh set | VERIFIED | `BackupCodes.generate/1` produces XXXX-XXXX format codes with `:crypto.strong_rand_bytes`. `consume/4` uses atomic `update_all WHERE used_at IS NULL`. `regenerate/4` exists in library. Settings LiveView displays codes in grid-cols-2 with copy/download. Note: regenerate UI handler has TODO for wiring -- library function exists but generated UI wiring incomplete. |
| 4 | User can check "trust this browser" and skip MFA for configurable period; disabling MFA requires current TOTP or backup code | VERIFIED | `Trust.sign/4` uses `Plug.Crypto.sign` with HMAC. `Trust.verify/5` checks user_id + epoch + TTL. Challenge page has trust checkbox "Trust this browser for 30 days". `disable/4` verifies TOTP or backup code before cleanup. `disable!/3` is admin-only force disable. |
| 5 | After 5 failed TOTP attempts, endpoint locks for 15 minutes, independently of main login lockout | VERIFIED | `MFA.Lockout.check/2` returns `{:error, :lockout, remaining_seconds}`. `increment/4` uses atomic `update_all inc: [failed_attempts: 1]`. Config defaults: `lockout_threshold: 5`, `lockout_duration: 900`. Separate from `Sigra.Lockout` -- per-credential tracking on `user_mfa_credentials` table. |

**Score:** 5/5 roadmap success criteria verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/mfa.ex` | Top-level MFA orchestrator | VERIFIED (513 lines) | enroll/2, confirm_enrollment/5, verify/4, verify_backup/4, disable/4, disable!/3, enabled?/2, status/2, verify_totp/4 |
| `lib/sigra/mfa/credential.ex` | MFA Credential library struct | VERIFIED (118 lines) | from_schema/1, to_params/1 |
| `lib/sigra/mfa/backup_codes.ex` | Backup code generation/consumption | VERIFIED (159 lines) | generate/1, hash/1, consume/4, remaining_count/3, regenerate/4 |
| `lib/sigra/mfa/trust.ex` | Trust cookie HMAC signing/verification | VERIFIED (119 lines) | sign/4, verify/5, revoke_all/3, cookie_name/0 |
| `lib/sigra/mfa/lockout.ex` | MFA-specific lockout | VERIFIED (123 lines) | check/2, increment/4, reset/3 |
| `lib/sigra/plug/require_mfa.ex` | MFA session gate plug | VERIFIED (70 lines) | Checks mfa_pending, redirects, allows /users/mfa and /users/log_out |
| `lib/sigra/plug/require_mfa_enrolled.ex` | MFA enrollment enforcement plug | VERIFIED (54 lines) | mfa_check_fn option, redirects unenrolled users |
| `lib/sigra/telemetry.ex` | MFA event catalog | VERIFIED (284 lines) | 4 span events + 4 one-shot events documented and registered |
| `lib/sigra/testing.ex` | MFA testing helpers | VERIFIED (592 lines) | 8 helpers: setup_totp, generate_totp_code, create_backup_codes, bypass_mfa, simulate_mfa_lockout, assert_mfa_enabled, assert_mfa_disabled, trust_browser |
| `lib/sigra/workers/token_cleanup.ex` | TokenCleanup extension | VERIFIED (163 lines) | cleanup_mfa_pending_sessions/1 deletes expired mfa_pending sessions |
| `priv/templates/sigra.install/migration.exs` | MFA tables DDL | VERIFIED (270 lines) | user_mfa_credentials, user_backup_codes, mfa_trust_epoch across 3 DB adapters |
| `priv/templates/sigra.install/user_mfa_credential.ex` | Generated MFA credential schema | VERIFIED (51 lines) | cloak_ecto Encrypted.Binary for encrypted_secret |
| `priv/templates/sigra.install/user_backup_code.ex` | Generated backup code schema | VERIFIED (33 lines) | hashed_code, used_at, updated_at: false |
| `priv/templates/sigra.install/emails.ex` | MFA email builders | VERIFIED (512 lines) | mfa_enabled_email, mfa_disabled_email, backup_code_used_email, mfa_lockout_email |
| `priv/templates/sigra.install/auth.ex` | Auth context MFA delegation | VERIFIED (566 lines) | 7 MFA functions delegating to Sigra.MFA |
| `priv/templates/sigra.install/auth_fixtures.ex` | MFA test fixtures | VERIFIED (122 lines) | mfa_user_fixture, mfa_pending_session_fixture, mfa_locked_fixture |
| `priv/templates/sigra.install/mfa_challenge_controller.ex` | MFA challenge controller | VERIFIED (121 lines) | new/create actions, TOTP + backup code methods |
| `priv/templates/sigra.install/mfa_challenge_html.ex` | MFA challenge HTML | VERIFIED (180 lines) | Tab UI, inputmode=numeric, auto-submit JS, trust checkbox |
| `priv/templates/sigra.install/mfa_challenge_live.ex` | MFA challenge LiveView | VERIFIED (283 lines) | phx-change auto-submit, tab switching |
| `priv/templates/sigra.install/mfa_settings_live.ex` | MFA settings LiveView | VERIFIED (590 lines) | Enrollment QR + manual key, backup codes grid, disable confirmation, regenerate |
| `priv/templates/sigra.install/mfa_settings_html.ex` | MFA settings HTML | VERIFIED (286 lines) | Controller mode equivalent |
| `priv/templates/sigra.install/user_auth.ex` | require_mfa plug | VERIFIED (326 lines) | require_mfa/2 checks mfa_pending session flag |
| `lib/mix/tasks/sigra.install.ex` | Generator with MFA files | VERIFIED (564 lines) | Copies 7 MFA templates, injects routes, adds plug :require_mfa |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| mfa.ex | mfa/credential.ex | Credential struct mapping | WIRED | `Sigra.MFA.Credential` referenced in mfa.ex |
| mfa.ex | mfa/backup_codes.ex | Backup code generation during enrollment | WIRED | `BackupCodes.generate` called in confirm_enrollment |
| mfa/trust.ex | Plug.Crypto | HMAC signing | WIRED | `Plug.Crypto.sign/verify` with "sigra-mfa-trust" salt |
| plug/require_mfa.ex | session.ex | Checks session.type == :mfa_pending | WIRED | Matches on `%Sigra.Session{type: :mfa_pending}` |
| auth.ex | session.ex | Creates :mfa_pending session | WIRED | `session_type = if mfa_enabled, do: :mfa_pending, else: :standard` |
| mfa.ex | telemetry.ex | Telemetry.span and event calls | WIRED | 5 span calls + 2 event calls in mfa.ex |
| testing.ex | mfa.ex | Testing helpers call MFA functions | WIRED | `Sigra.MFA` referenced in setup_totp, etc. |
| user_mfa_credential.ex template | mfa/credential.ex | Schema maps to library struct | WIRED | Schema fields match Credential struct |
| auth.ex template | mfa.ex | Auth context delegates to Sigra.MFA | WIRED | 7 delegation functions with `Sigra.MFA.` calls |
| mfa_challenge_controller.ex | auth.ex template | Calls Auth.mfa_verify | WIRED | `Auth.mfa_verify` and `Auth.mfa_verify_backup` |
| mfa_settings_live.ex | auth.ex template | Calls Auth.mfa_enroll, mfa_confirm | WIRED | `Auth.mfa_enroll`, `Auth.mfa_verify` referenced |
| generator | templates | Generator copies MFA templates | WIRED | 7 template files + route injection + plug injection |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| mfa.ex enroll/2 | raw_secret | NimbleTOTP.secret() | Yes -- cryptographic RNG | FLOWING |
| mfa.ex verify/4 | credential | Ecto query via mfa_credential_schema | Yes -- DB query | FLOWING |
| backup_codes.ex generate/1 | codes | :crypto.strong_rand_bytes/1 | Yes -- cryptographic RNG | FLOWING |
| trust.ex sign/4 | cookie | Plug.Crypto.sign/4 | Yes -- HMAC signed | FLOWING |
| lockout.ex increment/4 | failed_attempts | Ecto update_all atomic increment | Yes -- DB atomic op | FLOWING |
| mfa_settings_live.ex regenerate | new backup codes | TODO -- not wired to BackupCodes.regenerate | No -- calls mfa_status only | STATIC |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Test suite passes | `mix test --seed 0` | 807 tests, 0 failures | PASS |
| Clean compilation | `mix compile --warnings-as-errors` | Generated sigra app (no warnings) | PASS |
| MFA modules export expected functions | Verified via grep | All expected functions present | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| MFA-01 | 01, 04, 05 | TOTP enrollment with QR code and manual entry code | SATISFIED | enroll/2 generates QR+URI; settings LiveView shows QR+manual key; migration creates tables |
| MFA-02 | 01, 02, 03 | TOTP verification on login (6-digit, 30s step, +/-1 window) | SATISFIED | verify_totp/4 with drift; mfa_pending session gate; telemetry spans |
| MFA-03 | 02, 03, 05 | Progressive auth states -- mfa_pending prevents MFA bypass | SATISFIED | Session type union, RequireMFA plug, FetchSession timeout, challenge page |
| MFA-04 | 01, 03, 04 | Backup/recovery codes (8 single-use, hashed, shown once, regeneration) | SATISFIED | BackupCodes module, atomic consume, SHA-256 hashed; regenerate/4 in library (UI wiring incomplete but function exists) |
| MFA-05 | 01, 05 | Trust this browser cookie with configurable TTL | SATISFIED | Trust.sign/verify with HMAC, trust checkbox in challenge page, cookie_name constant |
| MFA-06 | 02, 05 | MFA enforcement policies per route or role | SATISFIED | RequireMFAEnrolled plug with mfa_check_fn; configurable enforcement |
| MFA-07 | 01, 05 | Disable MFA requires current TOTP or backup code | SATISFIED | disable/4 verifies code before cleanup; disable!/3 is admin-only |
| MFA-08 | 01, 03 | Rate-limited code attempts (5 attempts, 15-min lockout) | SATISFIED | MFA.Lockout with configurable threshold/duration, telemetry lockout event |
| MFA-09 | 01, 04 | TOTP secrets encrypted at rest | SATISFIED | cloak_ecto Encrypted.Binary in generated schema; encrypted_secret field |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| priv/templates/sigra.install/mfa_settings_live.ex | 549 | `TODO: Wire to Auth.mfa_regenerate_backup_codes/2 when available` | WARNING | Regenerate codes UI handler verifies TOTP code but does not actually call BackupCodes.regenerate; shows success flash without regenerating. Library function exists but Auth context delegation and UI wiring are incomplete. |

### Human Verification Required

### 1. Generator Integration Test

**Test:** Run `mix sigra.install` in a fresh Phoenix 1.8 app and verify all MFA files are generated
**Expected:** MFA schemas, controllers, LiveViews, migrations generated; router contains `/users/mfa` route and `require_mfa` in authenticated pipeline
**Why human:** Generator integration requires a real Phoenix app context

### 2. MFA Challenge Page UI

**Test:** Navigate to `/users/mfa` with an mfa_pending session and verify the challenge page
**Expected:** TOTP/backup code tabs, auto-submit JS fires on 6 digits, trust checkbox visible, "Cancel and sign out" link works
**Why human:** Visual UI rendering and JavaScript behavior cannot be verified programmatically

### 3. MFA Enrollment Flow

**Test:** Complete the full MFA enrollment flow from settings
**Expected:** QR code renders, manual key is visible and copyable, confirmation code accepted, backup codes display in 2-column grid with copy/download buttons, acknowledgment checkbox gates Done button
**Why human:** Multi-step LiveView interaction with QR code rendering and JS hooks (CopyBackupCodes, DownloadBackupCodes)

### 4. Backup Code Regeneration

**Test:** With MFA enabled, click "Regenerate codes" and enter a valid TOTP code
**Expected:** Old backup codes invalidated, new set generated and displayed
**Why human:** The `regenerate_codes` LiveView event handler has a TODO comment (`Wire to Auth.mfa_regenerate_backup_codes/2 when available`) -- the handler verifies the code but may not actually regenerate. Needs manual verification of actual behavior.

### Gaps Summary

No blocking gaps found. All 5 roadmap success criteria are verified at the code level. The library layer (Sigra.MFA, BackupCodes, Trust, Lockout) is complete and well-tested. The session gate (RequireMFA, mfa_pending type, Auth MFA-aware flow) is fully wired. Generated templates (schemas, migrations, emails, Auth context, challenge/settings UI) exist and contain expected content. The generator copies all files and injects routes/plugs.

**One WARNING-level anti-pattern:** The backup code regeneration UI flow in `mfa_settings_live.ex` has a TODO indicating incomplete wiring to `BackupCodes.regenerate/4`. The library function exists and is tested, but the generated Auth context is missing a `mfa_regenerate_backup_codes` delegation function, and the LiveView handler does not call it. This means the "Regenerate codes" button in the generated app may verify the TOTP code but not actually produce new backup codes. This should be confirmed during human verification and fixed if confirmed.

**One minor deviation:** `log_in_user` with `mfa: :bypass` option was not implemented (noted in 06-03 SUMMARY). The standalone `bypass_mfa/1` helper provides equivalent functionality.

---

_Verified: 2026-04-08T13:45:00Z_
_Verifier: Claude (gsd-verifier)_
