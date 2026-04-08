# Phase 6: Multi-Factor Authentication - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 06-multi-factor-authentication
**Areas discussed:** TOTP enrollment flow, Backup codes design, MFA session gate, Trust-this-browser & enforcement, Disable MFA flow, MFA + headless mode, Migration & schema design, Testing helpers, Email templates, MFA telemetry catalog, Config surface review, Error handling

---

## TOTP Enrollment Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Single-page flow | QR code + manual key + confirmation code on one page | ✓ |
| Multi-step wizard | Step 1: QR, Step 2: confirm, Step 3: backup codes | |

**User's choice:** Single-page flow
**Notes:** Matches GitHub/Google pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as dependency | NimbleTOTP as dep, gets upstream fixes | ✓ |
| Copy-paste into Sigra | Eliminate transitive dep | |

**User's choice:** Keep as dependency

| Option | Description | Selected |
|--------|-------------|----------|
| Plug session | Secret in encrypted session until confirmed | ✓ |
| Database with pending flag | Write to DB immediately with status: :pending | |

**User's choice:** Plug session

| Option | Description | Selected |
|--------|-------------|----------|
| Server-side SVG | Pure Elixir QR generation | ✓ |
| Client-side JS | Send otpauth URI, JS renders | |

**User's choice:** Server-side SVG

| Option | Description | Selected |
|--------|-------------|----------|
| eqrcode | Pure Elixir, generates SVG | |
| qr_code | Another pure Elixir option | |
| You decide | Claude picks | ✓ |

**User's choice:** Claude's discretion on QR library

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable with otp_app fallback | New config key, falls back to humanized otp_app | ✓ |
| Always derived from otp_app | Simpler config | |

**User's choice:** Configurable with fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, require sudo | Consistent with Phase 4/5 sensitive ops | ✓ |
| No sudo needed | Less friction | |

**User's choice:** Require sudo

| Option | Description | Selected |
|--------|-------------|----------|
| Show status + disable option | No re-enrollment without disabling | ✓ |
| Allow re-enrollment | Generate new secret, replace old | |

**User's choice:** Show status + disable option

| Option | Description | Selected |
|--------|-------------|----------|
| After TOTP confirmation | Backup codes shown on same page after confirming | ✓ |
| Separate step after | Redirect to dedicated backup codes page | |

**User's choice:** After TOTP confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Separate table | user_mfa_credentials, extensible for WebAuthn | ✓ |
| Columns on users table | Simpler but couples MFA to user schema | |

**User's choice:** Separate table

| Option | Description | Selected |
|--------|-------------|----------|
| Display + copy + download | Copy all + download as .txt | ✓ |
| Display + copy only | No download option | |

**User's choice:** Display + copy + download

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, require acknowledgment | "I have saved these codes" gates navigation | ✓ |
| No gate | Display codes, user can leave freely | |

**User's choice:** Require acknowledgment

---

## Backup Codes Design

| Option | Description | Selected |
|--------|-------------|----------|
| 8-digit numeric | XXXX-XXXX, easy to type on mobile | ✓ |
| Alphanumeric (10 chars) | Higher entropy, harder to type | |

**User's choice:** 8-digit numeric with dash separator

| Option | Description | Selected |
|--------|-------------|----------|
| SHA-256 | Fast hash, fine for high-entropy codes | ✓ |
| Argon2id | Same as passwords, overkill for random codes | |

**User's choice:** SHA-256

| Option | Description | Selected |
|--------|-------------|----------|
| Replace all codes | Fresh set of 8, requires current TOTP code | ✓ |
| Append new codes | Add codes without invalidating existing | |

**User's choice:** Replace all at once

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, show count | "3 of 8 remaining" with warning at <= 2 | ✓ |
| Just enabled/disabled | Don't reveal count | |

**User's choice:** Show count with low warning

| Option | Description | Selected |
|--------|-------------|----------|
| Separate user_backup_codes table | One row per code, atomic consumption | ✓ |
| JSONB array in mfa_credentials | Array in credential row | |

**User's choice:** Separate table

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, email notification | Security alert with remaining count | ✓ |
| No notification | Silent consumption | |

**User's choice:** Notify on use

| Option | Description | Selected |
|--------|-------------|----------|
| TOTP only, prompt to regenerate | No login block when codes exhausted | ✓ |
| Block login entirely | Require admin intervention | |

**User's choice:** TOTP only + prompt

| Option | Description | Selected |
|--------|-------------|----------|
| Shared rate limit | TOTP + backup share 5-attempt counter | ✓ |
| Separate rate limits | Independent counters | |

**User's choice:** Shared rate limit

| Option | Description | Selected |
|--------|-------------|----------|
| Never viewable again | Shown once, settings shows count only | ✓ |
| Viewable behind sudo | Can review remaining codes | |

**User's choice:** Never viewable again

| Option | Description | Selected |
|--------|-------------|----------|
| Tab on same MFA page | TOTP tab + backup code tab | ✓ |
| Separate backup code page | Link to dedicated page | |

**User's choice:** Tab on same page

| Option | Description | Selected |
|--------|-------------|----------|
| Dash separator | XXXX-XXXX | ✓ |
| Space separator | XXXX XXXX | |

**User's choice:** Dash separator

| Option | Description | Selected |
|--------|-------------|----------|
| In-app banner only | Warning when <= 2 remaining, no email | ✓ |
| Email + banner | Email at 2 remaining | |

**User's choice:** In-app banner only

| Option | Description | Selected |
|--------|-------------|----------|
| Current TOTP code | Proves factor possession | ✓ |
| Sudo (password) | Proves account ownership | |
| Both TOTP + sudo | Maximum security | |

**User's choice:** Current TOTP code for regeneration

| Option | Description | Selected |
|--------|-------------|----------|
| Include in base install | MFA tables in mix sigra.install migration | ✓ |
| Separate generator | mix sigra.gen.mfa | |

**User's choice:** Include in base install

---

## MFA Session Gate

| Option | Description | Selected |
|--------|-------------|----------|
| Session type field | Extend :standard/:remember_me with :mfa_pending | ✓ |
| Separate boolean flag | mfa_verified: boolean on session | |

**User's choice:** Session type field (Phase 4 D-03 planned this)

| Option | Description | Selected |
|--------|-------------|----------|
| New RequireMFA plug | Separate from RequireAuthenticated | ✓ |
| Extend RequireAuthenticated | Single plug checks both | |

**User's choice:** New RequireMFA plug

| Option | Description | Selected |
|--------|-------------|----------|
| MFA page only | Only /users/mfa and /users/log_out accessible | ✓ |
| Configurable allowlist | Developer configures accessible routes | |

**User's choice:** MFA page only (hard gate)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, rotate token | New token on MFA completion | ✓ |
| No rotation | Just update type | |

**User's choice:** Rotate token

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, 5-minute timeout | mfa_pending expires, forces re-login | ✓ |
| No timeout | Normal session TTL applies | |

**User's choice:** 5-minute timeout (configurable)

| Option | Description | Selected |
|--------|-------------|----------|
| Remember-me deferred | Activated only after MFA passes | ✓ |
| Remember-me ignored | Always :standard post-MFA | |

**User's choice:** Remember-me deferred until MFA complete

| Option | Description | Selected |
|--------|-------------|----------|
| Show partial email | j***@example.com | ✓ |
| No identity hint | Generic prompt | |

**User's choice:** Show partial email

| Option | Description | Selected |
|--------|-------------|----------|
| Not visible in listing | mfa_pending excluded | ✓ |
| Visible with badge | Show with status indicator | |

**User's choice:** Not visible

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, MFA always applies | OAuth callback enters mfa_pending | ✓ |
| Skip for trusted providers | Configurable bypass | |

**User's choice:** MFA always applies (Phase 5 D-66 confirmed)

| Option | Description | Selected |
|--------|-------------|----------|
| Per-user | Counter on MFA credential | ✓ |
| Per-session | Counter per mfa_pending session | |

**User's choice:** Per-user lockout

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, emit event | [:sigra, :mfa, :pending_expired] | ✓ |
| Silent expiry | No telemetry | |

**User's choice:** Emit event

| Option | Description | Selected |
|--------|-------------|----------|
| Generator inserts it | RequireMFA in authenticated pipeline | ✓ |
| Developer adds manually | Document where to add | |

**User's choice:** Generator inserts

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel = logout | Destroy mfa_pending session | ✓ |

**User's choice:** Cancel = logout

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect to settings | If not in mfa_pending state | ✓ |
| Show 404 | Route only for mfa_pending | |

**User's choice:** Redirect to settings

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-submit with JS | Submit when 6 digits detected | ✓ |
| No auto-submit | Standard form submit | |

**User's choice:** Auto-submit with JS

| Option | Description | Selected |
|--------|-------------|----------|
| +/-1 step, configurable | Default +/-1, developer can adjust | ✓ |
| Fixed +/-1 step | Hardcoded | |

**User's choice:** Configurable drift

| Option | Description | Selected |
|--------|-------------|----------|
| Show remaining attempts | "Invalid code. 3 attempts remaining." | ✓ |
| Generic error only | No remaining count | |

**User's choice:** Show remaining attempts

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, all attempts | [:sigra, :mfa, :verify, :start/:stop] | ✓ |
| Success only | Miss attack detection | |

**User's choice:** All attempts

| Option | Description | Selected |
|--------|-------------|----------|
| Password OR TOTP | Either works for sudo when MFA enabled | ✓ |
| Password AND TOTP | Both required | |
| Password only | Keep Phase 4 as-is | |

**User's choice:** Password OR TOTP

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, prevent replay | Track last_verified_step | ✓ |
| No replay prevention | Accept any valid code | |

**User's choice:** Prevent replay

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, email notification | Reuse Phase 4 lockout pattern | ✓ |
| Telemetry only | No user notification | |

**User's choice:** Email notification

| Option | Description | Selected |
|--------|-------------|----------|
| Standard session lookup | user_id in session record | ✓ |
| Separate MFA session store | Dedicated pre-MFA store | |

**User's choice:** Standard session lookup

| Option | Description | Selected |
|--------|-------------|----------|
| All sessions destroyed | Including mfa_pending | ✓ |

**User's choice:** All destroyed (matches Phase 4 D-16)

| Option | Description | Selected |
|--------|-------------|----------|
| Reset on success | Counter to 0 on successful verification | ✓ |
| Counter persists until expiry | Only resets when lockout window expires | |

**User's choice:** Reset on success

---

## Trust-This-Browser & Enforcement

| Option | Description | Selected |
|--------|-------------|----------|
| Separate trust cookie | HMAC-signed _sigra_mfa_trust cookie | ✓ |
| Trust flag on session | Store in session record | |
| Database-backed trust tokens | Dedicated table for trust | |

**User's choice:** Separate trust cookie

| Option | Description | Selected |
|--------|-------------|----------|
| 30 days | Matches Google's pattern | ✓ |
| 90 days | Longer trust | |
| 7 days | Shorter trust | |

**User's choice:** 30 days (configurable)

| Option | Description | Selected |
|--------|-------------|----------|
| Revoke all only | Increment trust_epoch, no per-device | ✓ |
| Per-device listing | Database-backed trust tokens | |
| No management | Trust expires naturally | |

**User's choice:** Revoke all only

| Option | Description | Selected |
|--------|-------------|----------|
| Per-route plug | RequireMFA placement controls enforcement | ✓ |
| Config-based enforcement | Library-level policy | |

**User's choice:** Per-route plug

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-revoke trust | Increment trust_epoch on disable | ✓ |
| Trust cookies persist | Become inert | |

**User's choice:** Auto-revoke

| Option | Description | Selected |
|--------|-------------|----------|
| _sigra_mfa_trust | Follows Sigra cookie convention | ✓ |

**User's choice:** _sigra_mfa_trust

| Option | Description | Selected |
|--------|-------------|----------|
| Shown but unchecked | User opts in explicitly | ✓ |
| Shown and checked | Pre-checked | |
| Hidden | Developer enables | |

**User's choice:** Shown but unchecked

| Option | Description | Selected |
|--------|-------------|----------|
| User ID + timestamp only | No device fingerprinting | ✓ |
| Include UA hash | More precise but brittle | |

**User's choice:** No fingerprinting

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, kill switch | mfa: [trust_enabled: true] | ✓ |
| No kill switch | Always available | |

**User's choice:** Kill switch

| Option | Description | Selected |
|--------|-------------|----------|
| Require sudo | Consistent with security settings | ✓ |
| Require TOTP code | Targeted factor proof | |
| No auth needed | Already authenticated | |

**User's choice:** Require sudo

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, RequireMFAEnrolled | Separate plug for "require MFA setup" | ✓ |
| Single RequireMFA handles both | Conflates concerns | |

**User's choice:** Separate RequireMFAEnrolled plug

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, invalidate trust | Increment trust_epoch on password change | ✓ |
| Trust persists | Separate concern | |

**User's choice:** Invalidate on password change

| Option | Description | Selected |
|--------|-------------|----------|
| Column on users table | mfa_trust_epoch integer | ✓ |
| On MFA credential record | Ties to MFA state | |

**User's choice:** Users table

| Option | Description | Selected |
|--------|-------------|----------|
| Settings only | Registration stays simple | ✓ |
| Optional during registration | Catch security-conscious users | |

**User's choice:** Settings only

| Option | Description | Selected |
|--------|-------------|----------|
| Both variants generated | LiveView + controller, --live flag | ✓ |
| LiveView only | Most interactive | |
| Controller only | Simplest | |

**User's choice:** Both variants

---

## Disable MFA Flow

| Option | Description | Selected |
|--------|-------------|----------|
| TOTP code OR backup code | Proves second factor possession (MFA-07) | ✓ |
| Sudo + TOTP/backup | Both required | |
| Sudo only | Password only | |

**User's choice:** TOTP or backup code

| Option | Description | Selected |
|--------|-------------|----------|
| Full cleanup | Delete credential, codes, increment epoch | ✓ |
| Soft disable | Keep data, mark disabled | |

**User's choice:** Full cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, email notification | Security alert | ✓ |
| No notification | User already knows | |

**User's choice:** Notify

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, explicit confirmation | Warning + code entry | ✓ |
| No extra confirmation | Code entry IS confirmation | |

**User's choice:** Explicit confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Sudo required | In addition to TOTP/backup code | ✓ |
| Code only | No sudo | |

**User's choice:** Sudo + code (two-step)

| Option | Description | Selected |
|--------|-------------|----------|
| Suggest, don't force | Non-blocking password change suggestion | ✓ |
| No suggestion | Clean disable | |

**User's choice:** Non-blocking suggestion

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, events for both | Enable/disable/regenerate telemetry | ✓ |

**User's choice:** Full telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Expose context function | Sigra.MFA.disable!/2 for admin tooling | ✓ |
| Out of scope | Only user-initiated | |

**User's choice:** Expose force-disable function

---

## MFA + Headless Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Library functions only | JSON API in Phase 7 | ✓ |
| Include JSON controllers | Generate API endpoints now | |

**User's choice:** Library functions only

| Option | Description | Selected |
|--------|-------------|----------|
| Return secret + URI + SVG | Full API for all consumers | ✓ |
| Return secret only | Caller generates URI/QR | |

**User's choice:** Return all three

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra.MFA module | Dedicated namespace like Sigra.OAuth | ✓ |
| Everything in Sigra.Auth | Single orchestrator | |

**User's choice:** Dedicated Sigra.MFA

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, expose check | MFA.enabled?/2 for custom flows | ✓ |
| Internal only | Login flow only | |

**User's choice:** Public check function

| Option | Description | Selected |
|--------|-------------|----------|
| Generated context delegates | MyApp.Auth gets MFA functions | ✓ |
| Direct Sigra.MFA calls | No wrappers | |

**User's choice:** Context delegates

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, library struct | Sigra.MFA.Credential with from/to_schema | ✓ |
| No library struct | Work with Ecto schema directly | |

**User's choice:** Library struct

| Option | Description | Selected |
|--------|-------------|----------|
| Auth handles transition | Auth orchestrates, MFA is domain module | ✓ |
| MFA handles transition | Self-contained | |

**User's choice:** Auth orchestrates

---

## Migration & Schema Design

| Option | Description | Selected |
|--------|-------------|----------|
| Full schema | All columns specified | ✓ |
| Minimal schema | Bare minimum | |

**User's choice:** Full schema for both tables

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in base migration | mfa_trust_epoch in mix sigra.install | ✓ |
| Separate migration | Additional migration file | |

**User's choice:** Base migration

| Option | Description | Selected |
|--------|-------------|----------|
| Database counter | failed_attempts on MFA credential | ✓ |
| Hammer ETS | Rate limiter | |

**User's choice:** Database counter

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse Phase 5 Vault | Same encryption infrastructure | ✓ |
| Separate encryption | Different keys per concern | |

**User's choice:** Reuse Vault

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, generate in base install | Vault is core infrastructure | ✓ |
| Require mix sigra.gen.oauth | Creates ordering dependency | |

**User's choice:** Base install generates Vault

| Option | Description | Selected |
|--------|-------------|----------|
| String | Portable, no migration for new types | ✓ |
| Ecto.Enum | Validates at changeset level | |

**User's choice:** String type column

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, cascade delete | ON DELETE CASCADE | ✓ |
| Application-level cleanup | No cascade | |

**User's choice:** Cascade delete

---

## Testing Helpers

| Option | Description | Selected |
|--------|-------------|----------|
| Full helper set | setup_totp, generate_code, bypass, simulate, assert | ✓ |
| Minimal set | Just setup_totp + bypass | |

**User's choice:** Full set

| Option | Description | Selected |
|--------|-------------|----------|
| bypass_mfa in log_in_user | mfa: :bypass option | ✓ |
| Separate bypass plug | Test-env plug | |

**User's choice:** Option on log_in_user

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, generate fixtures | mfa_user, mfa_pending_session, mfa_locked | ✓ |
| No fixtures | Build from helpers | |

**User's choice:** Generate fixtures

| Option | Description | Selected |
|--------|-------------|----------|
| Real code via NimbleTOTP | Exercises real TOTP logic | ✓ |
| Static test code | Fixed code for test env | |

**User's choice:** Real codes

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, trust_browser/2 | Sets valid trust cookie on conn | ✓ |
| No helper | Go through real trust flow | |

**User's choice:** Trust browser helper

---

## Email Templates

| Option | Description | Selected |
|--------|-------------|----------|
| MFA enabled notification | Informational security alert | ✓ |
| MFA disabled notification | Security alert | ✓ |
| Backup code used notification | Alert with remaining count | ✓ |
| MFA lockout notification | Failed attempts alert | ✓ |

**User's choice:** All four templates

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing module | Add to MyApp.Auth.Emails | ✓ |
| Separate MFA email module | New module | |

**User's choice:** Extend existing

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include link | "Generate new backup codes" in email | ✓ |
| No link | Informational only | |

**User's choice:** Include regeneration link

| Option | Description | Selected |
|--------|-------------|----------|
| Async via Oban | Consistent with Phase 3 pattern | ✓ |

**User's choice:** Async delivery

---

## MFA Telemetry Catalog

| Option | Description | Selected |
|--------|-------------|----------|
| Full catalog | Spans + one-shot events as proposed | ✓ |

**User's choice:** Full catalog confirmed

| Option | Description | Selected |
|--------|-------------|----------|
| Match Phase 4 | Security at :warning, ops at :info | ✓ |

**User's choice:** Match Phase 4 log levels

---

## Config Surface Review

| Option | Description | Selected |
|--------|-------------|----------|
| Full mfa: section | All keys as proposed | ✓ |

**User's choice:** Full config section confirmed

---

## Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated MFAError | Struct with error codes | ✓ |
| Reuse error atoms | {:error, :invalid_code} | |

**User's choice:** Dedicated struct

| Option | Description | Selected |
|--------|-------------|----------|
| Generic messages | Same message for TOTP and backup code errors | ✓ |
| Distinct per code type | Reveal which type attempted | |

**User's choice:** Enumeration-safe generic messages

| Option | Description | Selected |
|--------|-------------|----------|
| Time-based message | "Try again in X minutes" | ✓ |
| Generic message | "Try again later" | |

**User's choice:** Time-based lockout message

---

## Claude's Discretion

- QR code library selection (eqrcode, qr_code, or alternative)
- Exact MFA.Credential struct field types and from_schema/to_params mapping
- SVG QR code rendering implementation
- Generated template design details
- Auto-submit JS implementation
- HMAC trust cookie format and key derivation
- NimbleOptions schema for mfa: config
- Session cleanup for expired mfa_pending sessions
- Test fixture implementation details

## Deferred Ideas

- WebAuthn/passkeys as MFA factor (v1.x)
- JSON API endpoints for MFA (Phase 7)
- MFA during registration (future enhancement)
- Per-device trust listing (requires DB-backed trust tokens)
- Admin UI for MFA management (app concern)
