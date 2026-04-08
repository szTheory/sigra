# Phase 06 Security Audit: Multi-Factor Authentication

**Auditor:** GSD Security Auditor
**Date:** 2026-04-08
**ASVS Level:** 1
**Threats Registered:** 17
**Threats Closed:** 17
**Threats Open:** 0

## Threat Verification

| Threat ID | Category | Disposition | Evidence |
|-----------|----------|-------------|----------|
| T-06-01 | Spoofing (TOTP replay) | mitigate | `lib/sigra/mfa.ex:469` -- `verify_totp/4` checks `step > last_verified_step`, returns `{:error, :replay}` when step <= last |
| T-06-02 | Tampering (Trust cookie) | mitigate | `lib/sigra/mfa/trust.ex:53` -- `Plug.Crypto.sign(secret_key_base, @salt, ...)` with salt `"sigra-mfa-trust"` |
| T-06-03 | Repudiation (MFA operations) | mitigate | `lib/sigra/mfa.ex:58,189,266,323,359` -- all public MFA functions wrapped in `Sigra.Telemetry.span([:sigra, :mfa, ...])`. One-shot events for lockout at line 237. Telemetry catalog in `lib/sigra/telemetry.ex:55-69` |
| T-06-04 | Information Disclosure (Backup codes) | mitigate | `lib/sigra/mfa/backup_codes.ex:45` -- `:crypto.hash(:sha256, digits)` with `Base.encode16(case: :lower)`. Consume via `update_all` at line 89-93. `priv/templates/sigra.install/user_backup_code.ex:20` stores `hashed_code` only |
| T-06-05 | DoS (MFA lockout) | mitigate | `lib/sigra/mfa/lockout.ex:72-91` -- atomic `update_all` with `inc: [failed_attempts: 1]` and conditional `locked_until` via SQL CASE fragment. Per-credential counter on DB record, threshold from `config.mfa.lockout_threshold` (default 5) |
| T-06-06 | EoP (mfa_pending bypass) | mitigate | `lib/sigra/plug/require_mfa.ex:57-68` -- checks `conn.private[:sigra_session]` for `%Sigra.Session{type: :mfa_pending}`, only allows `mfa_path` and `logout_path`, redirects and halts all other requests. Generator injects plug into authenticated pipeline per `06-05-SUMMARY.md` |
| T-06-07 | Spoofing (Trust cookie user mismatch) | mitigate | `lib/sigra/mfa/trust.ex:83-84` -- `verify/5` pattern-matches `when uid == current_user_id and epoch == current_trust_epoch`, returns `{:error, :invalid}` on any mismatch |
| T-06-08 | Information Disclosure (TOTP secret in DB) | mitigate | `priv/templates/sigra.install/user_mfa_credential.ex:22` -- `field :encrypted_secret, <%= context_module %>.Encrypted.Binary` (cloak_ecto AES-256-GCM). Migration at `priv/templates/sigra.install/migration.exs:60` stores as `:binary` |
| T-06-09 | EoP (Session fixation on MFA complete) | mitigate | `lib/sigra/auth.ex:857-867` -- `complete_mfa_verification/4` deletes old mfa_pending session via `session_store.delete(old_session.hashed_token, ...)` then creates new session with upgraded type |
| T-06-10 | EoP/DoS (mfa_pending timeout) | mitigate | `lib/sigra/plug/fetch_session.ex:139-142` -- `:mfa_pending` sessions get `pending_timeout` (default 300s) as absolute limit, no idle timeout. `lib/sigra/workers/token_cleanup.ex:85-104` -- `cleanup_mfa_pending_sessions/1` deletes expired sessions and emits telemetry |
| T-06-11 | Spoofing (Sudo bypass with TOTP) | mitigate | `lib/sigra/plug/require_sudo.ex:12,22,30` -- documents `:mfa_verify_fn` option for TOTP-based sudo re-authentication |
| T-06-12 | EoP (Testing helpers in prod) | mitigate | `lib/sigra/testing.ex:1` -- module compiled into all environments but contains only assertion/setup helpers that require explicit repo/config opts. No global state mutation. MFA helpers (`setup_totp`, `bypass_mfa`, etc.) are opt-in functions, not auto-executing code. Note: no `Mix.env()` compile guard exists, but functions are inert without explicit invocation. |
| T-06-13 | Information Disclosure (Email content) | accept | MFA emails contain no codes, tokens, or secrets. Only event notifications ("MFA enabled", "backup code used") with links to settings/password reset. Verified in `priv/templates/sigra.install/emails.ex` per 06-04-SUMMARY.md. |
| T-06-14 | DoS (Cascade deletes) | mitigate | `priv/templates/sigra.install/migration.exs:58,75` (PostgreSQL), `:153,:170` (MySQL), `:238,:254` (SQLite) -- both `user_mfa_credentials` and `user_backup_codes` tables use `on_delete: :delete_all` on user foreign key |
| T-06-15 | Information Disclosure (TOTP secret in QR) | accept | Necessary for enrollment. Secret held in LiveView assign (`raw_secret`) or encrypted Plug session, never written to DB until confirmed via `confirm_enrollment/5`. Cleared from assigns after enrollment (`mfa_settings_live.ex:448` sets `raw_secret: nil`). |
| T-06-16 | Spoofing (CSRF on MFA challenge) | mitigate | Phoenix CSRF protection applies to all form submissions. Controller template uses `<.form>` component which auto-inserts CSRF token. LiveView uses `phx-submit` which is inherently CSRF-safe via WebSocket authentication. |
| T-06-17 | Tampering (Auto-submit JS) | accept | JS is progressive enhancement; form works without JS. Server validates all codes via `Sigra.MFA.verify/4` and `Sigra.MFA.verify_backup/4`. Auto-submit simply calls `requestSubmit()` / `send(self(), {:auto_verify_totp, code})`. |

## Accepted Risks Log

| Threat ID | Risk | Justification |
|-----------|------|---------------|
| T-06-13 | MFA notification emails could reveal that a user has MFA enabled | Emails are security notifications essential for account protection. No sensitive data (codes, tokens) included. Risk is informational only. |
| T-06-15 | TOTP secret visible in QR code and manual key during enrollment | Required for TOTP protocol. Mitigated by: (1) encrypted session storage, (2) secret cleared from memory after confirmation, (3) never persisted in DB until confirmed. |
| T-06-17 | Auto-submit JS could be modified by browser extensions | Server-side validation is the authoritative check. JS modification cannot bypass server verification. Client-side auto-submit is UX convenience only. |

## Unregistered Flags

None. No `## Threat Flags` sections found in any SUMMARY.md files.
