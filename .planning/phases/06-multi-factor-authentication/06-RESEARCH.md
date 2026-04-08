# Phase 6: Multi-Factor Authentication - Research

**Researched:** 2026-04-08
**Domain:** TOTP enrollment, backup codes, MFA session gating, trust cookies, MFA enforcement plugs
**Confidence:** HIGH

## Summary

Phase 6 adds TOTP-based multi-factor authentication to Sigra. The implementation spans five concerns: (1) TOTP enrollment with QR code generation, (2) MFA session gating via `mfa_pending` state, (3) backup code generation/consumption, (4) trust-this-browser cookies, and (5) MFA enforcement plugs. All security-critical logic lives in the library (`Sigra.MFA`), with generated schemas, templates, and email modules in the host app.

The existing codebase provides strong foundations to build on: `Sigra.Lockout` for the MFA lockout pattern, `Sigra.Token` for HMAC trust cookies, `Sigra.Identity` for the library struct pattern, `Sigra.Telemetry` for event instrumentation, and `Sigra.Config` for NimbleOptions-validated configuration. The `Sigra.Session` struct needs its type union extended with `:mfa_pending`, and `Sigra.Auth.authenticate/2` needs MFA-aware session creation.

**Primary recommendation:** Build `Sigra.MFA` as the top-level orchestrator module following the same pattern as `Sigra.Auth` and `Sigra.OAuth`. Use NimbleTOTP as a dependency (not copy-paste). Use EQRCode for server-side SVG QR generation. Reuse Phase 5's cloak_ecto Vault for TOTP secret encryption. Track MFA lockout on the `user_mfa_credentials` record independently of login lockout.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Single-page enrollment flow: QR code + manual key + confirmation code entry all on one page. User scans, enters code, submits. Matches GitHub/Google pattern.
- **D-02:** NimbleTOTP kept as a dependency (not copy-pasted). Stable since 2023, minimal surface, gets upstream fixes.
- **D-03:** Unconfirmed TOTP secret held in encrypted Plug session during enrollment. Never touches DB until user confirms with a valid code. Naturally expires with session.
- **D-04:** Server-side SVG QR code generation. Pure Elixir, no JS dependency. Works in headless mode.
- **D-05:** TOTP issuer name configurable via `mfa: [totp_issuer: "MyApp"]`. Falls back to humanized `otp_app` name.
- **D-06:** Enrollment requires sudo mode (re-authentication).
- **D-07:** No re-enrollment without disabling first.
- **D-08:** Backup codes shown after TOTP confirmation on the same page (revealed section).
- **D-09:** TOTP secrets stored in separate `user_mfa_credentials` table. Extensible for future MFA types.
- **D-10:** Display + copy + download UX for backup codes.
- **D-11:** Required acknowledgment checkbox ("I have saved these codes") before enrollment completes.
- **D-12:** 8-digit numeric format, dash-separated: XXXX-XXXX. Verification strips dashes/spaces.
- **D-13:** SHA-256 hashed storage for backup codes.
- **D-14:** Regeneration replaces all codes at once. Requires current TOTP code.
- **D-15:** Remaining backup code count shown in MFA settings.
- **D-16:** Separate `user_backup_codes` table: one row per code, atomic consumption.
- **D-17:** Notification email on backup code use.
- **D-18:** When all codes exhausted: user must use TOTP. Banner after login.
- **D-19:** TOTP and backup code attempts share the same 5-attempt / 15-min lockout counter.
- **D-20:** Backup codes never viewable again after initial display.
- **D-21:** Tab-based input on MFA challenge page: "Authenticator code" tab (default) and "Backup code" tab.
- **D-22:** Session type field extended: `:standard | :remember_me | :mfa_pending`.
- **D-23:** New `Sigra.Plug.RequireMFA` plug.
- **D-24:** `mfa_pending` sessions can ONLY access `/users/mfa` and `/users/log_out`.
- **D-25:** Session token rotated on MFA completion.
- **D-26:** `mfa_pending` sessions expire after 5 minutes (configurable).
- **D-27:** Remember-me deferred until MFA complete.
- **D-28:** MFA challenge page shows partial email.
- **D-29:** `mfa_pending` sessions excluded from active session listing.
- **D-30:** MFA always applies, including OAuth login.
- **D-31:** TOTP lockout counter is per-user (on MFA credential record, not per-session).
- **D-32:** Telemetry event on `mfa_pending` expiration.
- **D-33:** Generator auto-inserts RequireMFA plug into authenticated pipeline.
- **D-34:** Cancel on MFA page = logout.
- **D-35:** Non-pending user visiting `/users/mfa` redirects appropriately.
- **D-36:** Auto-submit with JS when 6 digits entered.
- **D-37:** TOTP drift window: +/-1 step (30s each side), configurable.
- **D-38:** Failed MFA attempts show remaining count.
- **D-39:** Full telemetry on all MFA verification attempts.
- **D-40:** Sudo mode accepts password OR TOTP code when MFA is enabled.
- **D-41:** TOTP replay prevention: track `last_verified_step` on MFA credential.
- **D-42:** MFA lockout notification email. Async via Oban.
- **D-43:** `mfa_pending` uses standard session lookup.
- **D-44:** "Log out everywhere" destroys all sessions including `mfa_pending`.
- **D-45:** MFA attempt counter resets on successful verification.
- **D-46:** Separate HMAC-signed trust cookie (`_sigra_mfa_trust`).
- **D-47:** Default trust TTL: 30 days (configurable).
- **D-48:** "Revoke all trusted browsers" via trust_epoch increment.
- **D-49:** `mfa_trust_epoch` column (integer, default 0) on users table.
- **D-50:** Trust kill switch: `mfa: [trust_enabled: true]`.
- **D-51:** Trust checkbox shown but unchecked by default.
- **D-52:** Trust cookie contains user_id + timestamp only.
- **D-53:** Disabling MFA auto-revokes trust.
- **D-54:** Cookie name: `_sigra_mfa_trust`. HttpOnly, Secure, SameSite=Lax.
- **D-55:** Revoking trusted browsers requires sudo mode.
- **D-56:** Password change invalidates all trust cookies.
- **D-57:** Per-route enforcement via `Sigra.Plug.RequireMFA` plug.
- **D-58:** Separate `Sigra.Plug.RequireMFAEnrolled` plug.
- **D-59:** Disabling requires sudo mode + current TOTP code or backup code.
- **D-60:** Full cleanup on disable.
- **D-61:** Notification email on disable.
- **D-62:** Explicit confirmation step before disabling.
- **D-63:** Post-disable suggestion.
- **D-64:** Telemetry for enable/disable.
- **D-65:** Admin force-disable: `Sigra.MFA.disable!/2`.
- **D-66:** Dedicated `Sigra.MFA` module as top-level MFA namespace.
- **D-67:** Library functions only for Phase 6. JSON API endpoints deferred to Phase 7.
- **D-68:** enroll/2 returns `{:ok, %{secret: base32_secret, otpauth_uri: uri, svg: svg_string}}`.
- **D-69:** `Sigra.MFA.Credential` library struct with `from_schema/1` and `to_params/1`.
- **D-70:** Auth orchestrates session transitions.
- **D-71:** `Sigra.MFA.enabled?/2` public function.
- **D-72:** Generated `MyApp.Auth` context gets MFA functions.
- **D-73 through D-80:** Schema and migration specifications (see CONTEXT.md for full details).
- **D-81 through D-83:** Email template specifications.
- **D-84 through D-87:** Telemetry event specifications.
- **D-88:** NimbleOptions `mfa:` config section specification.
- **D-89 through D-91:** Error handling specifications.
- **D-92 through D-95:** Testing helper specifications.
- **D-96 through D-98:** UI specifications.

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

### Deferred Ideas (OUT OF SCOPE)
- WebAuthn/passkeys as MFA second factor (v1.x -- PASSKEY-01 through PASSKEY-04)
- JSON API endpoints for MFA challenge/verify (Phase 7 -- API Authentication)
- MFA requirement during registration (optional future enhancement)
- Per-device trust listing and individual revocation
- Admin UI for MFA management
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MFA-01 | TOTP enrollment with QR code generation and manual entry code | NimbleTOTP 1.0.0 `secret/1` + `otpauth_uri/3`, EQRCode 0.2.1 `encode/1` + `svg/2` for QR SVG |
| MFA-02 | TOTP verification on login (6-digit code, 30s step, +/-1 window) | NimbleTOTP `valid?/3` with `:since` for replay prevention; drift via two calls at t-30 and t+30 |
| MFA-03 | Progressive auth states -- `mfa_pending` session state prevents MFA bypass | Extend `Sigra.Session` type union, new `Sigra.Plug.RequireMFA`, 5-min pending timeout |
| MFA-04 | Backup/recovery codes (8 single-use, hashed, shown once, regeneration) | `:crypto.strong_rand_bytes/1` for generation, SHA-256 for storage, atomic consumption via UPDATE WHERE |
| MFA-05 | "Trust this browser" cookie to skip MFA (configurable TTL) | `Plug.Crypto.sign/4` for HMAC trust cookie, trust_epoch for mass revocation |
| MFA-06 | MFA enforcement policies (per route) | `Sigra.Plug.RequireMFA` and `Sigra.Plug.RequireMFAEnrolled` plugs |
| MFA-07 | Disable MFA requires current TOTP code or backup code | Sudo mode gate + MFA code verification before cleanup |
| MFA-08 | Rate-limited code attempts (5 attempts / 15-min lockout) | `failed_attempts` + `locked_until` on `user_mfa_credentials` record, mirrors `Sigra.Lockout` pattern |
| MFA-09 | TOTP secrets encrypted at rest | Reuse Phase 5 cloak_ecto Vault (`MyApp.Vault` + `MyApp.Encrypted.Binary`) |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nimble_totp | 1.0.0 | TOTP primitive (RFC 6238) | Dashbit-maintained, minimal, correct. 4 functions: secret generation, otpauth URI, code generation, code verification. Stable since Mar 2023. |
| eqrcode | 0.2.1 | QR code SVG generation | Pure Elixir, zero deps, supports SVG output with customizable color/shape/width. Small and focused. |
| cloak_ecto | 1.3.0 | TOTP secret encryption at rest | Already used by Phase 5 for OAuth token encryption. AES-256-GCM via Erlang `:crypto`. |

[VERIFIED: `mix hex.info nimble_totp` -- 1.0.0, Apache-2.0]
[VERIFIED: `mix hex.info eqrcode` -- 0.2.1, MIT]
[VERIFIED: `mix hex.info cloak_ecto` -- 1.3.0, MIT]

### Supporting (already in project)
| Library | Version | Purpose | Usage in Phase 6 |
|---------|---------|---------|-------------------|
| plug_crypto | (via phoenix) | HMAC signing for trust cookie | `Plug.Crypto.sign/4` and `Plug.Crypto.verify/4` |
| nimble_options | ~> 1.1 | Config validation | New `mfa:` section in `Sigra.Config` |
| swoosh | ~> 1.5 | Email delivery | 4 MFA email templates (enabled, disabled, backup used, lockout) |
| oban | ~> 2.17 | Async email delivery | MFA notification emails via Oban workers |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| eqrcode | qr_code (iodevs) | qr_code v3.2.0 has more features (embedded images, more rendering options) but heavier. EQRCode is simpler, lighter, sufficient for TOTP QR codes. |
| eqrcode | qrcode_ex | Fork of eqrcode with more error correction levels. Not needed -- eqrcode's default ECC is sufficient for short otpauth URIs. |

**Recommendation: EQRCode 0.2.1** -- the simplest option that meets requirements. Pure Elixir, zero deps, SVG output built in. The otpauth URI is short enough that EQRCode's QR version limit (1-7) is not a concern. [VERIFIED: hexdocs.pm/eqrcode/EQRCode.SVG.html -- SVG API confirmed]

**Installation:**
```bash
# Add to mix.exs deps (nimble_totp is required, eqrcode is optional for QR SVG)
{:nimble_totp, "~> 1.0"},
{:eqrcode, "~> 0.2.1", optional: true}
```

Note: `eqrcode` should be optional. If the host app does not include it, `Sigra.MFA.enroll/2` returns the otpauth URI and base32 secret but not the SVG string. The generated templates check for eqrcode availability. This matches Sigra's "optional dep" pattern (D-35 from Phase 1).

## Architecture Patterns

### Recommended Module Structure
```
lib/sigra/
  mfa.ex                    # Top-level orchestrator (enroll, verify, disable, enabled?, status)
  mfa/
    credential.ex           # Library struct: from_schema/1, to_params/1
    backup_codes.ex         # Generate, hash, verify, consume, regenerate
    trust.ex                # Trust cookie: sign, verify, revoke_all
    lockout.ex              # MFA-specific lockout (mirrors Sigra.Lockout pattern)
  plug/
    require_mfa.ex          # Gate: blocks mfa_pending sessions from protected routes
    require_mfa_enrolled.ex # Gate: requires MFA enrollment before access
```

### Generated Code Structure
```
lib/my_app/
  auth/
    user_mfa_credential.ex  # Ecto schema for user_mfa_credentials table
    user_backup_code.ex     # Ecto schema for user_backup_codes table
  auth.ex                   # Extended with MFA delegation functions

lib/my_app_web/
  controllers/
    mfa_controller.ex       # MFA challenge page (controller variant)
    mfa_html.ex             # MFA challenge/enrollment templates
  live/
    mfa_live.ex             # MFA enrollment LiveView (--live variant)
    mfa_challenge_live.ex   # MFA challenge LiveView

priv/repo/migrations/
  *_add_mfa_tables.exs      # user_mfa_credentials + user_backup_codes + mfa_trust_epoch
```

### Pattern 1: MFA-Aware Authentication Flow
**What:** After password/OAuth verification succeeds, check if user has MFA enrolled. If yes, create `mfa_pending` session instead of `standard`/`remember_me`.
**When to use:** Every login flow.
**Example:**
```elixir
# In Sigra.Auth.authenticate_with_config/2 (extended)
# After successful password verification:
case Sigra.MFA.enabled?(config, user) do
  true ->
    # Create mfa_pending session, preserve remember_me choice in session metadata
    {:ok, session} = create_session(config, user, type: :mfa_pending)
    {:ok, user, %{session: session, mfa_required: true}}

  false ->
    # Existing flow: create standard/remember_me session
    {:ok, session} = create_session(config, user, type: session_type)
    {:ok, user, %{session: session}}
end
```
[VERIFIED: existing `Sigra.Auth.authenticate_with_config/2` in lib/sigra/auth.ex]

### Pattern 2: Session Type Transition on MFA Verification
**What:** After successful TOTP/backup code verification, rotate session token and upgrade type from `:mfa_pending` to `:standard` or `:remember_me`.
**When to use:** MFA challenge completion.
**Example:**
```elixir
# In Sigra.MFA.verify/3
def verify(config, user, code, opts \\ []) do
  credential = fetch_mfa_credential(config, user)

  with :ok <- check_lockout(credential, config),
       :ok <- verify_code(credential, code, config) do
    # Reset failed attempts
    reset_attempts(config, credential)
    # Update last_verified_step for replay prevention
    update_last_verified_step(config, credential, current_step(config))
    {:ok, :verified}
  else
    {:error, :invalid_code} ->
      increment_attempts(config, credential)
      {:error, :invalid_code, remaining_attempts(credential, config)}

    {:error, :lockout} = err ->
      err
  end
end
```
[ASSUMED -- pattern derived from Sigra.Lockout and CONTEXT.md D-70]

### Pattern 3: HMAC Trust Cookie
**What:** Stateless HMAC-signed cookie containing user_id + trust_epoch + issued_at. Verified by HMAC + trust_epoch match + TTL check.
**When to use:** Skip MFA for trusted browsers.
**Example:**
```elixir
# In Sigra.MFA.Trust
def sign_trust_cookie(secret_key_base, user_id, trust_epoch) do
  data = %{user_id: user_id, epoch: trust_epoch, issued_at: System.system_time(:second)}
  Plug.Crypto.sign(secret_key_base, "sigra-mfa-trust", data, max_age: trust_ttl)
end

def verify_trust_cookie(secret_key_base, cookie, user_trust_epoch, trust_ttl) do
  case Plug.Crypto.verify(secret_key_base, "sigra-mfa-trust", cookie, max_age: trust_ttl) do
    {:ok, %{user_id: uid, epoch: epoch}} when epoch == user_trust_epoch ->
      {:ok, uid}
    _ ->
      {:error, :invalid}
  end
end
```
[VERIFIED: `Plug.Crypto.sign/4` and `Plug.Crypto.verify/4` API from existing `Sigra.Token` module]

### Pattern 4: Backup Code Generation and Atomic Consumption
**What:** Generate 8 random codes, hash with SHA-256, store individually. Consume atomically with UPDATE WHERE.
**When to use:** Enrollment completion and code regeneration.
**Example:**
```elixir
# In Sigra.MFA.BackupCodes
def generate(count \\ 8) do
  Enum.map(1..count, fn _ ->
    raw = :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned() |> rem(100_000_000)
    code = raw |> Integer.to_string() |> String.pad_leading(8, "0")
    formatted = String.slice(code, 0, 4) <> "-" <> String.slice(code, 4, 4)
    {formatted, :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)}
  end)
end

# Atomic consumption: UPDATE user_backup_codes SET used_at = NOW()
# WHERE id = ? AND used_at IS NULL RETURNING id
def consume(repo, backup_code_schema, user_id, submitted_code) do
  normalized = String.replace(submitted_code, ~r/[\s\-]/, "")
  hashed = :crypto.hash(:sha256, normalized) |> Base.encode16(case: :lower)

  from(bc in backup_code_schema,
    where: bc.user_id == ^user_id and bc.hashed_code == ^hashed and is_nil(bc.used_at),
    update: [set: [used_at: ^DateTime.utc_now()]]
  )
  |> repo.update_all([])
  |> case do
    {1, _} -> {:ok, :consumed}
    {0, _} -> {:error, :invalid_backup_code}
  end
end
```
[VERIFIED: pattern consistent with Sigra.Token.hash_token/1 and Ecto update_all API]

### Pattern 5: NimbleTOTP Drift and Replay Prevention
**What:** Verify TOTP code against current step and +/-1 step. Track `last_verified_step` to prevent replay attacks.
**When to use:** Every TOTP verification.
**Example:**
```elixir
# In Sigra.MFA (internal)
defp verify_totp(secret, code, last_verified_step, drift_steps) do
  now = System.system_time(:second)
  period = 30

  steps = for offset <- -drift_steps..drift_steps do
    time = now + (offset * period)
    step = div(time, period)
    {step, NimbleTOTP.valid?(secret, code, time: time)}
  end

  case Enum.find(steps, fn {_step, valid} -> valid end) do
    {step, true} when step > last_verified_step ->
      {:ok, step}
    {_step, true} ->
      {:error, :replay}
    nil ->
      {:error, :invalid_code}
  end
end
```
[VERIFIED: NimbleTOTP.valid?/3 accepts `:time` option -- hexdocs.pm/nimble_totp/NimbleTOTP.html]

### Anti-Patterns to Avoid
- **Storing raw TOTP secret in DB without encryption:** Always use cloak_ecto for TOTP secrets. A database compromise would give attackers the ability to generate valid codes.
- **Per-session MFA lockout counter:** Must be per-user on the MFA credential record, otherwise attackers can multiply attempts across sessions (D-31).
- **JWT for trust cookies:** Use Plug.Crypto.sign (HMAC) not JWT. Trust cookies are simple user_id + epoch payloads; JWT adds unnecessary complexity and attack surface.
- **Blocking registration/login on MFA enrollment failure:** MFA enrollment is post-login, from settings only (D-97). Never gate registration.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOTP code generation/verification | Custom HOTP/TOTP implementation | NimbleTOTP 1.0.0 | RFC 6238 is subtle (time drift, truncation, HMAC-SHA1). NimbleTOTP is tested and Dashbit-maintained. |
| QR code generation | Custom QR encoder | EQRCode 0.2.1 | QR encoding involves Reed-Solomon error correction, mode selection, and masking. Non-trivial to get right. |
| HMAC token signing | Custom HMAC implementation | Plug.Crypto.sign/4 | Already used by Phoenix for CSRF and session tokens. battle-tested, handles key derivation. |
| Field encryption | Custom AES wrapper | cloak_ecto 1.3.0 | Key rotation, multiple cipher support, Ecto type integration. Already set up in Phase 5. |
| Backup code randomness | `Enum.random` or `:rand` | `:crypto.strong_rand_bytes/1` | Must be cryptographically secure. `:rand` is not suitable for security-sensitive values. |

**Key insight:** The MFA domain combines multiple cryptographic primitives (TOTP, HMAC, AES-GCM, SHA-256, CSPRNG). Each one is deceptively simple to get wrong. Use the established libraries for each primitive and focus implementation effort on the orchestration layer.

## Common Pitfalls

### Pitfall 1: TOTP Replay Attacks
**What goes wrong:** Same valid TOTP code accepted twice within the same 30-second window.
**Why it happens:** TOTP codes are valid for an entire time step. Without tracking the last accepted step, the same code works for repeated requests.
**How to avoid:** Store `last_verified_step` (integer) on the MFA credential. Only accept codes from steps strictly greater than the last verified step (D-41).
**Warning signs:** Tests pass for single verification but don't test double-submit within the same time window.

### Pitfall 2: MFA Bypass via Direct URL Access
**What goes wrong:** User with `mfa_pending` session accesses a protected route by entering the URL directly, bypassing the MFA challenge.
**Why it happens:** `RequireAuthenticated` plug passes because the session exists; it does not check the session type.
**How to avoid:** `Sigra.Plug.RequireMFA` must be a SEPARATE plug after `RequireAuthenticated`. It checks `conn.private[:sigra_session].type` and redirects `:mfa_pending` sessions to `/users/mfa`. The plug ordering in the router pipeline is critical: `FetchSession -> RequireAuthenticated -> RequireMFA` (D-23, D-24).
**Warning signs:** No test verifying that `mfa_pending` sessions cannot access non-MFA routes.

### Pitfall 3: Session Fixation on MFA Completion
**What goes wrong:** The session token created at login persists through MFA verification, allowing an attacker who captured the pre-MFA token to access the now-verified session.
**Why it happens:** Token not rotated on MFA completion.
**How to avoid:** On MFA verification success, delete the `mfa_pending` session token and create a new one with type `:standard` or `:remember_me`. The conn must be updated with the new token (D-25).
**Warning signs:** Session token value is the same before and after MFA verification in tests.

### Pitfall 4: Lockout Counter Reset Race Condition
**What goes wrong:** Concurrent MFA verification requests from different tabs/devices can race, causing the attempt counter to skip the lockout threshold.
**Why it happens:** Read-then-increment is not atomic.
**How to avoid:** Use `Ecto.Multi` or `update_all` with SQL-level increment: `SET failed_attempts = failed_attempts + 1`. Check the returned value to trigger lockout. The MFA credential's `failed_attempts` field should be incremented atomically.
**Warning signs:** Lockout tests pass in isolation but not under concurrent load.

### Pitfall 5: Backup Code Timing Attack
**What goes wrong:** Hash comparison takes different time for matching vs. non-matching codes, potentially leaking whether a code exists.
**Why it happens:** Naive string comparison short-circuits on first mismatch.
**How to avoid:** For backup codes, this is less critical than password hashing (codes are high-entropy random, 10^8 possibilities with 8 digits), but the atomically-consumed UPDATE WHERE pattern sidesteps it entirely -- the DB does the comparison. For defense in depth, normalize and hash the submitted code before passing to the query, so the DB comparison is hash-to-hash.
**Warning signs:** Backup code verification uses `==` on raw code strings.

### Pitfall 6: Trust Cookie User ID Mismatch
**What goes wrong:** A trust cookie from user A is accepted for user B because the verification only checks the HMAC signature, not the user_id inside.
**Why it happens:** Verification extracts user_id from signed payload but does not compare it to the currently authenticated user.
**How to avoid:** After verifying the HMAC signature, explicitly compare the `user_id` in the cookie payload with `conn.assigns.current_scope.id`. Also verify `epoch` matches the user's current `mfa_trust_epoch` (D-48).
**Warning signs:** Tests don't cover the scenario of using another user's trust cookie.

### Pitfall 7: Encrypted Session Size Limit for TOTP Secret
**What goes wrong:** Storing the unconfirmed TOTP secret in the encrypted Plug session (D-03) may exceed cookie size limits (~4KB).
**Why it happens:** Plug session is stored in a signed+encrypted cookie. A 20-byte TOTP secret base32-encoded is only ~32 chars, but combined with other session data and encryption overhead, it could grow.
**How to avoid:** The TOTP secret is small (32 chars base32). Measure actual encrypted session size during development. If approaching 4KB, store the secret in a server-side temporary record (ETS or DB) with a reference in the session. This is unlikely to be an issue but should be verified.
**Warning signs:** Session cookie silently truncated or rejected by browsers.

## Code Examples

### NimbleTOTP Integration
```elixir
# Source: hexdocs.pm/nimble_totp/NimbleTOTP.html [VERIFIED]
# Generate secret
secret = NimbleTOTP.secret()  # 20-byte binary

# Generate otpauth URI
uri = NimbleTOTP.otpauth_uri("MyApp:user@example.com", secret, issuer: "MyApp")
# => "otpauth://totp/MyApp:user@example.com?secret=MFRGGZA...&issuer=MyApp"

# Generate QR code SVG
svg = uri |> EQRCode.encode() |> EQRCode.svg(width: 200)
# => "<svg xmlns=\"http://www.w3.org/2000/svg\" ..."

# Verify a code
NimbleTOTP.valid?(secret, "569777")
# => true/false

# Verify with drift window (+/-1 step = +/-30 seconds)
now = System.system_time(:second)
NimbleTOTP.valid?(secret, code, time: now - 30) or
  NimbleTOTP.valid?(secret, code) or
  NimbleTOTP.valid?(secret, code, time: now + 30)
```

### EQRCode SVG Generation
```elixir
# Source: hexdocs.pm/eqrcode/EQRCode.SVG.html [VERIFIED]
qr = EQRCode.encode("otpauth://totp/MyApp:user@example.com?secret=BASE32SECRET&issuer=MyApp")
svg_string = EQRCode.svg(qr, width: 200, color: "#000", background_color: "#FFF")
# Returns a complete <svg> element as a string
# Render in HEEx: {:safe, svg_string} or Phoenix.HTML.raw(svg_string)
```

### HMAC Trust Cookie (using existing Sigra.Token pattern)
```elixir
# Source: lib/sigra/token.ex [VERIFIED]
# Sign: embed user_id + epoch + issued_at
data = {user_id, trust_epoch, System.system_time(:second)}
cookie = Plug.Crypto.sign(secret_key_base, "sigra-mfa-trust", data)

# Verify: check signature + TTL + epoch match
case Plug.Crypto.verify(secret_key_base, "sigra-mfa-trust", cookie, max_age: trust_ttl) do
  {:ok, {uid, epoch, _issued}} when uid == current_user_id and epoch == current_trust_epoch ->
    :trusted
  _ ->
    :not_trusted
end
```

### Session Type Extension
```elixir
# Extend Sigra.Session type union (D-22)
@type session_type :: :standard | :remember_me | :mfa_pending

# In FetchSession plug, mfa_pending sessions get limited scope
# The RequireMFA plug checks:
case conn.private[:sigra_session] do
  %Sigra.Session{type: :mfa_pending} ->
    conn |> redirect(to: "/users/mfa") |> halt()
  _ ->
    conn
end
```

### Backup Code Format (D-12)
```elixir
# Generate 8-digit numeric, dash-separated
raw_int = :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned() |> rem(100_000_000)
code = raw_int |> Integer.to_string() |> String.pad_leading(8, "0")
formatted = String.slice(code, 0, 4) <> "-" <> String.slice(code, 4, 4)
# => "4821-9037"

# Normalize on verification: strip dashes and spaces
normalized = String.replace(submitted, ~r/[\s\-]/, "")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SMS OTP as MFA | TOTP / WebAuthn | NIST deprecated SMS ~2017 | TOTP is primary, WebAuthn is v1.x |
| Storing TOTP secret in plaintext | Encrypted at rest (AES-256-GCM) | Industry standard ~2020+ | cloak_ecto handles transparently |
| JWT-based MFA tokens | Stateless HMAC cookies for trust only | Current best practice | Simpler, fewer attack vectors |
| Per-session lockout counters | Per-user DB-backed counters | Always was correct, often missed | Prevents attempt multiplication |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | EQRCode 0.2.1 can encode otpauth URIs within its QR version limit (1-7) | Standard Stack | LOW -- otpauth URIs are short (~100 chars); QR version 3 handles up to 77 alphanumeric chars, but binary mode handles more. If too long, fall back to qr_code library. |
| A2 | Plug session encrypted cookie has enough space for a base32 TOTP secret (~32 chars) alongside existing session data | Pitfall 7 | LOW -- 32 chars is tiny vs 4KB limit. Verify during implementation. |
| A3 | `NimbleTOTP.valid?/3` with `:time` option adjusts the time step calculation, not just the comparison time | Code Examples | LOW -- verified from hexdocs, but the drift implementation should be tested. |

## Open Questions

1. **EQRCode vs QR Code library: is EQRCode's version limit sufficient?**
   - What we know: EQRCode supports QR versions 1-7. An otpauth URI like `otpauth://totp/MyApp:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=MyApp` is ~90 characters.
   - What's unclear: Whether EQRCode auto-selects the right version or errors on input too long.
   - Recommendation: Test with a representative otpauth URI during implementation. If EQRCode errors, switch to `qr_code` which supports versions 1-40. The `Sigra.MFA.enroll/2` function should handle this gracefully with `Code.ensure_loaded?(EQRCode)`.

2. **Backup code format collision probability**
   - What we know: 8-digit numeric codes = 10^8 = 100 million possible codes. With 8 codes per user, collision within a user is ~3.2 x 10^-7 per pair.
   - What's unclear: Whether we should check for duplicates on generation.
   - Recommendation: The collision probability is negligible. Generate 8 codes independently. If paranoid, regenerate if any duplicates detected (simple uniqueness check on the set).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/sigra/mfa_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MFA-01 | TOTP enrollment returns secret + URI + SVG | unit | `mix test test/sigra/mfa_test.exs -x` | Wave 0 |
| MFA-02 | TOTP verification with drift window | unit | `mix test test/sigra/mfa_test.exs -x` | Wave 0 |
| MFA-03 | mfa_pending session blocks protected routes | unit | `mix test test/sigra/plug/require_mfa_test.exs -x` | Wave 0 |
| MFA-04 | Backup code generation, consumption, regeneration | unit | `mix test test/sigra/mfa/backup_codes_test.exs -x` | Wave 0 |
| MFA-05 | Trust cookie sign/verify/revoke | unit | `mix test test/sigra/mfa/trust_test.exs -x` | Wave 0 |
| MFA-06 | RequireMFA and RequireMFAEnrolled plug behavior | unit | `mix test test/sigra/plug/require_mfa_test.exs test/sigra/plug/require_mfa_enrolled_test.exs -x` | Wave 0 |
| MFA-07 | Disable MFA requires code verification | unit | `mix test test/sigra/mfa_test.exs -x` | Wave 0 |
| MFA-08 | Lockout after 5 failed attempts | unit | `mix test test/sigra/mfa/lockout_test.exs -x` | Wave 0 |
| MFA-09 | TOTP secret stored encrypted (cloak_ecto) | unit | `mix test test/sigra/mfa/credential_test.exs -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/mfa_test.exs test/sigra/mfa/ test/sigra/plug/require_mfa_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/mfa_test.exs` -- covers MFA-01, MFA-02, MFA-07
- [ ] `test/sigra/mfa/backup_codes_test.exs` -- covers MFA-04
- [ ] `test/sigra/mfa/trust_test.exs` -- covers MFA-05
- [ ] `test/sigra/mfa/lockout_test.exs` -- covers MFA-08
- [ ] `test/sigra/mfa/credential_test.exs` -- covers MFA-09
- [ ] `test/sigra/plug/require_mfa_test.exs` -- covers MFA-03, MFA-06
- [ ] `test/sigra/plug/require_mfa_enrolled_test.exs` -- covers MFA-06

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | TOTP verification, backup codes, MFA enforcement |
| V3 Session Management | yes | `mfa_pending` session state, token rotation on MFA completion |
| V4 Access Control | yes | RequireMFA / RequireMFAEnrolled plugs |
| V5 Input Validation | yes | 6-digit code format validation, backup code normalization |
| V6 Cryptography | yes | NimbleTOTP (HMAC-SHA1), cloak_ecto (AES-256-GCM), SHA-256 for backup codes |

### Known Threat Patterns for MFA

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| TOTP replay attack | Replay | Track `last_verified_step`, reject same/earlier steps (D-41) |
| MFA bypass via direct URL | Elevation of privilege | `RequireMFA` plug checks session type, hard gate (D-24) |
| Session fixation on MFA complete | Spoofing | Rotate session token on MFA verification (D-25) |
| Brute force TOTP (10^6 space) | Tampering | 5-attempt lockout, 15-min duration (D-19) |
| Trust cookie theft | Spoofing | HMAC-signed, HttpOnly, Secure, SameSite=Lax, epoch-based revocation (D-46-54) |
| Backup code enumeration | Information disclosure | Enumeration-safe error messages, same response for TOTP and backup failures (D-90) |
| TOTP secret exfiltration from DB | Information disclosure | Encrypted at rest via cloak_ecto (MFA-09) |
| Lockout counter manipulation via concurrent requests | Denial of service | Atomic DB-level increment (not read-then-write) |

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path
- **Database:** PostgreSQL primary (citext, JSONB). MySQL/SQLite support via conditional migrations
- **Security:** OWASP standards throughout. All tokens HMAC-protected. Enumeration prevention by default
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable
- **LiveView:** Supported but optional. Core works with standard controllers. Login/logout via HTTP POST
- **Testing:** Comprehensive spec coverage -- happy path, main error cases, boundary conditions. AAA style, flat, self-contained
- **Architecture:** Security-critical code in library; customizable code generated into host app
- **No macros:** Generated schemas are plain Ecto schemas calling library functions
- **Config:** Runtime struct-based config passed explicitly via NimbleOptions

## Sources

### Primary (HIGH confidence)
- [hexdocs.pm/nimble_totp/NimbleTOTP.html](https://hexdocs.pm/nimble_totp/NimbleTOTP.html) -- Full API reference: secret/1, otpauth_uri/3, valid?/3, verification_code/2
- [hexdocs.pm/eqrcode/EQRCode.SVG.html](https://hexdocs.pm/eqrcode/EQRCode.SVG.html) -- SVG generation API: svg/2 with color, width, shape options
- [hex.pm/packages/eqrcode](https://hex.pm/packages/eqrcode) -- v0.2.1 verified via `mix hex.info`
- [hex.pm/packages/nimble_totp](https://hex.pm/packages/nimble_totp) -- v1.0.0 verified via `mix hex.info`
- [hex.pm/packages/cloak_ecto](https://hex.pm/packages/cloak_ecto) -- v1.3.0 verified via `mix hex.info`
- Existing codebase: `lib/sigra/auth.ex`, `lib/sigra/session.ex`, `lib/sigra/token.ex`, `lib/sigra/lockout.ex`, `lib/sigra/identity.ex`, `lib/sigra/config.ex`, `lib/sigra/error.ex`, `lib/sigra/telemetry.ex`, `lib/sigra/testing.ex`, `lib/sigra/plug/require_sudo.ex`, `lib/sigra/plug/fetch_session.ex`

### Secondary (MEDIUM confidence)
- [hexdocs.pm/eqrcode/EQRCode.html](https://hexdocs.pm/eqrcode/EQRCode.html) -- encode/1 function
- [github.com/SiliconJungles/eqrcode](https://github.com/SiliconJungles/eqrcode) -- QR version limits

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries verified via hex.pm, APIs confirmed via hexdocs
- Architecture: HIGH -- follows established patterns in existing codebase (Sigra.Auth, Sigra.Identity, Sigra.Lockout)
- Pitfalls: HIGH -- TOTP security is well-documented domain; pitfalls derived from RFC 6238 and OWASP MFA guidelines

**Research date:** 2026-04-08
**Valid until:** 2026-05-08 (stable libraries, no fast-moving changes expected)
