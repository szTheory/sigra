# Phase 6: Multi-Factor Authentication - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can enroll TOTP, verify it on login via a `mfa_pending` session gate, use backup codes for recovery, and trust specific browsers; admins can enforce MFA per route or role. Includes TOTP full lifecycle (enroll, verify, disable), backup codes (generate, consume, regenerate), trust-this-browser cookie, MFA enforcement plugs, and rate-limited verification attempts.

</domain>

<decisions>
## Implementation Decisions

### TOTP Enrollment
- **D-01:** Single-page enrollment flow: QR code + manual key + confirmation code entry all on one page. User scans, enters code, submits. Matches GitHub/Google pattern.
- **D-02:** NimbleTOTP kept as a dependency (not copy-pasted). Stable since 2023, minimal surface, gets upstream fixes.
- **D-03:** Unconfirmed TOTP secret held in encrypted Plug session during enrollment. Never touches DB until user confirms with a valid code. Naturally expires with session.
- **D-04:** Server-side SVG QR code generation. Pure Elixir, no JS dependency. Works in headless mode.
- **D-05:** TOTP issuer name configurable via `mfa: [totp_issuer: "MyApp"]`. Falls back to humanized `otp_app` name. Appears in authenticator app as service name.
- **D-06:** Enrollment requires sudo mode (re-authentication). Consistent with Phase 4/5 security-sensitive operations.
- **D-07:** No re-enrollment without disabling first. Already-enrolled users see MFA status + disable option. Prevents accidental secret rotation.
- **D-08:** Backup codes shown after TOTP confirmation on the same page (revealed section). Enrollment not "done" until user acknowledges saving codes.
- **D-09:** TOTP secrets stored in separate `user_mfa_credentials` table. Extensible for future MFA types (WebAuthn in v1.x). Follows Sigra's per-concern table pattern.
- **D-10:** Display + copy + download UX for backup codes. "Copy all" button + "Download as .txt" option. Cover all user preferences.
- **D-11:** Required acknowledgment checkbox ("I have saved these codes") before enrollment completes.

### Backup Codes
- **D-12:** 8-digit numeric format, dash-separated: XXXX-XXXX. Easy to type on mobile. Verification strips dashes/spaces.
- **D-13:** SHA-256 hashed storage. Codes are high-entropy random values; no need for Argon2id's brute-force resistance.
- **D-14:** Regeneration replaces all codes at once. Requires current TOTP code to authorize. Deletes old codes, generates fresh set of 8.
- **D-15:** Remaining backup code count shown in MFA settings: "3 of 8 backup codes remaining." Warning banner when <= 2 remaining (in-app only, no email).
- **D-16:** Separate `user_backup_codes` table: one row per code, atomic consumption via `UPDATE SET used_at WHERE id = ? AND used_at IS NULL`.
- **D-17:** Notification email on backup code use: "A backup code was used to sign in. X of 8 codes remaining." Includes link to regenerate codes.
- **D-18:** When all codes exhausted: user must use TOTP. Prominent banner after login: "All backup codes used. Generate new ones now." No login block.
- **D-19:** TOTP and backup code attempts share the same 5-attempt / 15-min lockout counter. Single wall for both paths.
- **D-20:** Backup codes never viewable again after initial display. Settings shows only remaining count. Regenerate to get new codes.
- **D-21:** Tab-based input on MFA challenge page: "Authenticator code" tab (default) and "Backup code" tab. Single page, no navigation.

### MFA Session Gate
- **D-22:** Session type field extended: `:standard | :remember_me | :mfa_pending`. Phase 4 D-03 already planned this. After password/OAuth login, session created as `:mfa_pending`. After verification, upgraded to `:standard` or `:remember_me`.
- **D-23:** New `Sigra.Plug.RequireMFA` plug. Checks session type; if `:mfa_pending`, redirects to `/users/mfa`. Separate from RequireAuthenticated -- you can be "authenticated but MFA pending."
- **D-24:** `mfa_pending` sessions can ONLY access `/users/mfa` (verification page) and `/users/log_out`. All other routes redirect to `/users/mfa`. Hard gate prevents MFA bypass.
- **D-25:** Session token rotated on MFA completion. New token generated, old `mfa_pending` token invalidated. Prevents session fixation attacks.
- **D-26:** `mfa_pending` sessions expire after 5 minutes (configurable via `mfa: [pending_timeout: 300]`). Forces re-login if user abandons MFA page.
- **D-27:** Remember-me deferred until MFA complete. User's "remember me" choice preserved during `mfa_pending`, activated only after MFA passes. Session upgrades to `:remember_me` if chosen.
- **D-28:** MFA challenge page shows partial email: "Enter the code for j***@example.com." Helps multi-account users identify correct authenticator entry.
- **D-29:** `mfa_pending` sessions excluded from active session listing. Only `:standard`/`:remember_me` sessions visible. Pending sessions are ephemeral.
- **D-30:** MFA always applies, including OAuth login. OAuth callback creates `:mfa_pending` session. Phase 5 D-66 confirmed this.
- **D-31:** TOTP lockout counter is per-user (on MFA credential record, not per-session). Prevents attempt multiplication across sessions.
- **D-32:** Telemetry event on `mfa_pending` expiration: `[:sigra, :mfa, :pending_expired]` with user_id and ip.
- **D-33:** Generator auto-inserts RequireMFA plug into authenticated pipeline in generated router. Secure by default.
- **D-34:** Cancel on MFA page = logout. Destroys `mfa_pending` session, redirects to login.
- **D-35:** Non-pending user visiting `/users/mfa` redirects to settings (if no MFA enrolled) or home (if MFA already verified).
- **D-36:** Auto-submit with JS when 6 digits entered. Generated template includes enhancement script.
- **D-37:** TOTP drift window: +/-1 step (30s each side), configurable via `mfa: [totp_drift_steps: 1]`.
- **D-38:** Failed MFA attempts show remaining count: "Invalid code. 3 attempts remaining."
- **D-39:** Full telemetry on all MFA verification attempts: `[:sigra, :mfa, :verify, :start/:stop]` with method, result, attempts_remaining.
- **D-40:** Sudo mode accepts password OR TOTP code when MFA is enabled. For OAuth-only users with MFA: TOTP code. Extends Phase 4 D-21.
- **D-41:** TOTP replay prevention: track `last_verified_step` on MFA credential. Reject codes from same or earlier time step.
- **D-42:** MFA lockout notification email sent on lockout trigger. Reuses Phase 4 lockout notification pattern. Async via Oban.
- **D-43:** `mfa_pending` uses standard session lookup (user_id in session record). FetchSession already assigns current_scope.
- **D-44:** "Log out everywhere" destroys all sessions including `mfa_pending`. Matches Phase 4 D-16.
- **D-45:** MFA attempt counter resets on successful verification. Same pattern as Phase 4 login lockout D-26.

### Trust-This-Browser
- **D-46:** Separate HMAC-signed trust cookie (`_sigra_mfa_trust`). Contains user_id + trust_epoch + issued_at. Verified by HMAC. Separate from session cookie.
- **D-47:** Default trust TTL: 30 days (configurable via `mfa: [trust_ttl: 2_592_000]`). After expiry, MFA required again.
- **D-48:** "Revoke all trusted browsers" via trust_epoch increment on user record. No per-device listing -- trust cookies are stateless. Invalidation is instant.
- **D-49:** `mfa_trust_epoch` column (integer, default 0) on users table. Incremented on: disable MFA, revoke trust, password change.
- **D-50:** Trust kill switch: `mfa: [trust_enabled: true]`. When false, checkbox hidden and trust cookies not checked.
- **D-51:** Trust checkbox shown but unchecked by default on MFA challenge page. User opts in explicitly. Configurable via `mfa: [show_trust_option: true]`.
- **D-52:** Trust cookie contains user_id + timestamp only. No device fingerprinting (UA hash). Cookie itself is the trust proof.
- **D-53:** Disabling MFA auto-revokes trust (increments trust_epoch). Clean state on re-enable.
- **D-54:** Cookie name: `_sigra_mfa_trust`. HttpOnly, Secure, SameSite=Lax. Follows Sigra cookie naming convention.
- **D-55:** Revoking trusted browsers requires sudo mode. Consistent with other security-sensitive settings.
- **D-56:** Password change invalidates all trust cookies (increments trust_epoch). Defense in depth.

### MFA Enforcement
- **D-57:** Per-route enforcement via `Sigra.Plug.RequireMFA` plug. Developer controls by pipeline placement. No library-level role-based enforcement -- that mixes auth with authorization.
- **D-58:** Separate `Sigra.Plug.RequireMFAEnrolled` plug for "require MFA setup" routes. Redirects unenrolled users to MFA enrollment. Two plugs, two concerns.

### Disable MFA Flow
- **D-59:** Disabling requires sudo mode + current TOTP code or backup code. Two-step: sudo gate, then MFA code confirmation.
- **D-60:** Full cleanup on disable: delete MFA credential (TOTP secret), delete all backup codes, increment trust_epoch. Clean slate.
- **D-61:** Notification email on disable: "Two-factor authentication was disabled on your account. If this wasn't you, re-enable MFA and change your password."
- **D-62:** Explicit confirmation step before disabling: warning message + code entry form.
- **D-63:** Post-disable suggestion (non-blocking): "Consider changing your password for additional security."
- **D-64:** Telemetry for enable/disable: `[:sigra, :mfa, :enable, :stop]`, `[:sigra, :mfa, :disable, :stop]`, `[:sigra, :mfa, :backup_codes, :regenerate, :stop]`.
- **D-65:** Admin force-disable: `Sigra.MFA.disable!/2` (force variant without requiring TOTP code). For developer admin tooling. Emits telemetry noting admin action.

### Module Architecture
- **D-66:** Dedicated `Sigra.MFA` module as top-level MFA namespace: enroll/2, verify/3, disable/3, enabled?/2, status/2. Matches Sigra.OAuth pattern from Phase 5.
- **D-67:** Library functions only for Phase 6. JSON API endpoints deferred to Phase 7. Phase 6 ensures library layer is complete and testable without UI.
- **D-68:** enroll/2 returns `{:ok, %{secret: base32_secret, otpauth_uri: uri, svg: svg_string}}`. Full API for both headless and browser consumers.
- **D-69:** `Sigra.MFA.Credential` library struct with `from_schema/1` and `to_params/1`. Generated `UserMFACredential` Ecto schema maps to/from it. Follows hybrid pattern from Phase 4/5.
- **D-70:** Auth orchestrates session transitions. `Sigra.Auth.authenticate/2` checks MFA enrollment, creates `:mfa_pending`. `Sigra.MFA.verify/3` returns `{:ok, :verified}`. Auth upgrades session type.
- **D-71:** `Sigra.MFA.enabled?/2` public function for custom developer flows. Used by RequireMFAEnrolled plug and login flow.
- **D-72:** Generated `MyApp.Auth` context gets MFA functions delegating to `Sigra.MFA` with repo/config injected.

### Schema & Migration
- **D-73:** `user_mfa_credentials` table: id (uuid), user_id (references users ON DELETE CASCADE), type (string, e.g. "totp"), encrypted_secret (binary, cloak_ecto), last_used_at (utc_datetime_usec), last_verified_step (integer, replay prevention), failed_attempts (integer, default 0), locked_until (utc_datetime_usec), enabled_at (utc_datetime_usec), inserted_at, updated_at. Unique index on (user_id, type).
- **D-74:** `user_backup_codes` table: id (uuid), user_id (references users ON DELETE CASCADE), hashed_code (string, SHA-256 hex), used_at (utc_datetime_usec, nil until consumed), inserted_at. Index on user_id.
- **D-75:** `mfa_trust_epoch` column (integer, default 0) added to users table in base install migration.
- **D-76:** MFA tables included in base `mix sigra.install` migration. MFA is core auth infrastructure, not optional like OAuth. Tables exist but inert until enrollment.
- **D-77:** type column is string (not Ecto.Enum). Portable, no migration needed for new MFA types (WebAuthn).
- **D-78:** Cascade delete on both tables. User deletion cleans up all MFA data automatically.
- **D-79:** Failed MFA attempts tracked in database (on MFA credential). Persists across app restarts. Independent from login lockout.
- **D-80:** Reuse Phase 5 cloak_ecto Vault for TOTP secret encryption. Base install generates Vault module if it doesn't exist (for apps that skip OAuth).

### Email Templates
- **D-81:** Four email templates generated in `MyApp.Auth.Emails`: `mfa_enabled_email/2`, `mfa_disabled_email/2`, `backup_code_used_email/2`, `mfa_lockout_email/2`.
- **D-82:** Backup code used email includes "Generate new backup codes" link to MFA settings. Reduces friction for users running low.
- **D-83:** All MFA emails async via Oban with inline fallback. Consistent with Phase 3 delivery pattern.

### Telemetry
- **D-84:** Spans: `[:sigra, :mfa, :enroll, :start/:stop]`, `[:sigra, :mfa, :verify, :start/:stop]`, `[:sigra, :mfa, :disable, :start/:stop]`, `[:sigra, :mfa, :backup_codes, :regenerate, :start/:stop]`.
- **D-85:** One-shot events: `[:sigra, :mfa, :lockout]`, `[:sigra, :mfa, :pending_expired]`, `[:sigra, :mfa, :trust, :granted]`, `[:sigra, :mfa, :trust, :revoked_all]`.
- **D-86:** Metadata includes: user_id, method (:totp/:backup_code), result (:success/:failure), attempts_remaining.
- **D-87:** Log levels: security events (lockout, pending_expired) at :warning. Operations (enroll, verify, disable) at :info. Matches Phase 4 D-56.

### Config Surface
- **D-88:** New `mfa:` section in `Sigra.Config`: enabled (true), totp_issuer (nil -- falls back to otp_app), totp_drift_steps (1), backup_code_count (8), trust_enabled (true), trust_ttl (2_592_000), lockout_threshold (5), lockout_duration (900), pending_timeout (300), show_trust_option (true). NimbleOptions validated.

### Error Handling
- **D-89:** `Sigra.Error.MFAError` struct with error_code: `:invalid_code`, `:lockout`, `:not_enrolled`, `:already_enrolled`, `:enrollment_required`, `:backup_exhausted`, `:invalid_backup_code`. Each has `safe_message/1`.
- **D-90:** Enumeration-safe: invalid TOTP and invalid backup code return same generic "Invalid verification code." Don't reveal code type attempted.
- **D-91:** Lockout message includes remaining time: "Too many failed attempts. Try again in X minutes."

### Testing
- **D-92:** Full helper set in `Sigra.Testing`: `setup_totp/2`, `generate_totp_code/1` (real code via NimbleTOTP), `create_backup_codes/2`, `bypass_mfa/1`, `simulate_mfa_lockout/1`, `assert_mfa_enabled/1`, `assert_mfa_disabled/1`, `trust_browser/2`.
- **D-93:** `log_in_user/2` updated with `mfa: :bypass` option. Non-MFA tests skip MFA challenge without code changes.
- **D-94:** Generated test fixtures: `mfa_user_fixture/1`, `mfa_pending_session_fixture/1`, `mfa_locked_fixture/1`.
- **D-95:** `generate_totp_code/1` uses NimbleTOTP for real valid codes. Tests exercise real TOTP verification logic.

### MFA Settings Page
- **D-96:** Both LiveView component and controller HTML variants generated. `--live` flag controls which. MFA enrollment (QR scan, code entry) works well as interactive LiveView.
- **D-97:** MFA enrollment from settings page only, not during registration. Registration stays simple.

### MFA Challenge Page UX
- **D-98:** Clean, focused GitHub-style: centered card, partial email, 6-digit monospace input, "Trust this browser" checkbox, Verify button, TOTP/backup code tabs, cancel (logout) link.

### Claude's Discretion
- QR code library selection (eqrcode, qr_code, or alternative)
- Exact Sigra.MFA.Credential struct field types and from_schema/to_params mapping
- SVG QR code rendering implementation
- Generated template design for enrollment, challenge, and settings pages
- MFA settings page layout and component structure
- Auto-submit JS implementation details
- HMAC trust cookie format and key derivation
- Exact NimbleOptions schema for mfa: config validation
- Session cleanup for expired mfa_pending sessions (extend TokenCleanup)
- Test fixture implementation details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` -- Vision, hybrid lib+generator architecture, NimbleTOTP and cloak_ecto in stack
- `.planning/REQUIREMENTS.md` -- MFA-01 through MFA-09 requirements
- `.planning/ROADMAP.md` SS Phase 6 -- Goal, success criteria, requirement mapping

### Prior phase context
- `.planning/phases/01-foundation/01-CONTEXT.md` -- D-05 (NimbleOptions config), D-08 (incremental generators), D-12 (behaviours), D-19 (error handling), D-35 (optional dep handling)
- `.planning/phases/02-core-auth/02-CONTEXT.md` -- D-30-34 (login attempt tracking), D-35-38 (session token format), D-44-46 (enumeration prevention)
- `.planning/phases/03-email-flows-and-transactional-email/03-CONTEXT.md` -- D-18 (email module structure), D-21-27 (Oban/async delivery)
- `.planning/phases/04-session-management-and-security-baseline/04-CONTEXT.md` -- D-01-07 (session architecture, mfa_pending planned), D-20-23 (sudo mode), D-26-32 (lockout pattern), D-33-43 (rate limiting)
- `.planning/phases/05-oauth-and-social-login/05-CONTEXT.md` -- D-22-24 (cloak_ecto Vault), D-28 (Identity library struct pattern), D-66-67 (OAuth+MFA interaction)

### Existing code to extend
- `lib/sigra/auth.ex` -- Add MFA-aware authenticate flow, session type transitions
- `lib/sigra/config.ex` -- Add mfa: section with NimbleOptions schema
- `lib/sigra/session.ex` -- Add :mfa_pending to session_type type
- `lib/sigra/telemetry.ex` -- Add MFA event catalog
- `lib/sigra/testing.ex` -- Add MFA testing helpers
- `lib/sigra/error.ex` -- Add MFAError struct
- `lib/sigra/lockout.ex` -- Pattern reference for MFA lockout
- `lib/sigra/plug/require_sudo.ex` -- Extend to accept TOTP codes
- `lib/sigra/plug/fetch_session.ex` -- Handle mfa_pending session type
- `lib/sigra/workers/token_cleanup.ex` -- Extend with mfa_pending session cleanup
- `priv/templates/sigra.install/` -- Add MFA tables to base migration template

### Ecosystem documentation
- `CLAUDE.md` SS Technology Stack -- NimbleTOTP 1.0.0, cloak_ecto 1.3.0, version compatibility
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` -- MFA patterns, TOTP best practices

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Auth` -- Orchestrator with register/authenticate/create_session. Extend with MFA-aware login flow
- `Sigra.Session` -- Library struct with type field. Add :mfa_pending to type union
- `Sigra.Token` -- HMAC token generation/verification. Reuse for trust cookie HMAC
- `Sigra.Config` -- NimbleOptions validated. Add mfa: section
- `Sigra.Telemetry` -- span/3 and event/3. Add MFA event catalog
- `Sigra.Error` -- Exception types with safe_message/1. Add MFAError
- `Sigra.Lockout` -- Lockout pattern with failed_attempts tracking. Reference for MFA lockout
- `Sigra.Plug.RequireSudo` -- Sudo mode plug. Extend to accept TOTP codes
- `Sigra.Identity` -- Library struct pattern (from_schema/to_params). Follow for MFA.Credential
- `Sigra.Workers.TokenCleanup` -- Daily Oban cron. Extend with mfa_pending cleanup
- Phase 5 Vault (`MyApp.Vault` + `MyApp.Encrypted.Binary`) -- Reuse for TOTP secret encryption

### Established Patterns
- `{:ok, result} | {:error, reason}` everywhere (Phase 1 D-19)
- Behaviours for extensibility, `Code.ensure_loaded?` for optional deps (Phase 1 D-12, D-35)
- Library struct + generated schema mapping (Phase 4 Session, Phase 5 Identity)
- Telemetry span for sync ops, one-shot for signals (Phase 1 D-15/18)
- NimbleOptions for all config sections (Phase 1 D-05)
- Enumeration-safe responses with generic messages (Phase 2 D-44)
- Async email delivery via Oban with inline fallback (Phase 3 D-21-27)
- DB-backed lockout with failed_attempts counter (Phase 4 D-26)

### Integration Points
- New `Sigra.MFA` module tree (orchestrator, credential)
- New `Sigra.MFA.Credential` library struct
- New `Sigra.Error.MFAError` exception type
- New `Sigra.Plug.RequireMFA` and `Sigra.Plug.RequireMFAEnrolled` plugs
- Generated `UserMFACredential` and `UserBackupCode` Ecto schemas
- Generated MFA enrollment, challenge, and settings page templates (LiveView + controller)
- Generated email templates: mfa_enabled, mfa_disabled, backup_code_used, mfa_lockout
- Base migration updated: user_mfa_credentials, user_backup_codes tables, mfa_trust_epoch on users
- Vault generated in base install if not present
- Router: RequireMFA plug auto-inserted, /users/mfa route added
- Auth context: MFA delegation functions added to generated MyApp.Auth

</code_context>

<specifics>
## Specific Ideas

- GitHub-style MFA challenge page: centered, focused, minimal
- Single-page enrollment matching GitHub/Google pattern (not multi-step wizard)
- Backup codes displayed in a grid with copy/download, never viewable again
- Tab-based TOTP/backup code switching on challenge page (no separate pages)
- Auto-submit JS enhancement when 6 digits entered
- "3 of 8 backup codes remaining" with visual warning when low
- Trust cookie is stateless (HMAC-signed) with epoch counter for instant mass revocation
- Non-blocking password change suggestion after disabling MFA via backup code

</specifics>

<deferred>
## Deferred Ideas

- WebAuthn/passkeys as MFA second factor (v1.x -- PASSKEY-01 through PASSKEY-04)
- JSON API endpoints for MFA challenge/verify (Phase 7 -- API Authentication)
- MFA requirement during registration (optional future enhancement)
- Per-device trust listing and individual revocation (adds database-backed trust tokens)
- Admin UI for MFA management (app-level concern, library exposes functions only)

</deferred>

---

*Phase: 06-multi-factor-authentication*
*Context gathered: 2026-04-08*
