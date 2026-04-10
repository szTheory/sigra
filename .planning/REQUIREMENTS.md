# Requirements: Sigra

**Defined:** 2026-04-05
**Core Value:** Authentication that works out of the box with great DX — so developers can ship SaaS apps fast and grow with confidence.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [x] **FOUND-01**: Library initializes via `mix sigra.install` generating migrations, schemas, context module, plugs, and optional LiveView pages
- [x] **FOUND-02**: Generated code follows Phoenix context pattern (`MyApp.Auth`) with clean DDD boundaries
- [x] **FOUND-03**: Security-critical code lives in Sigra library dep; customizable code is generated into user's project
- [x] **FOUND-04**: No macro-based schema injection — generated schemas are plain Ecto schemas calling library functions
- [x] **FOUND-05**: Configuration via explicit options with smart defaults (confirmation required, lockout threshold, timeouts, table names)
- [x] **FOUND-06**: Behaviour + callback architecture for extensibility (mailer, rate limiter, session store)
- [x] **FOUND-07**: Telemetry events emitted for all auth operations (login, logout, register, MFA, lockout, etc.)
- [x] **FOUND-08**: Works with standard controllers/Plug without requiring LiveView
- [x] **FOUND-09**: Optional LiveView components for login, registration, MFA, settings
- [x] **FOUND-10**: Headless mode — all logic works without any UI components

### Email/Password Authentication

- [x] **AUTH-01**: User can register with email and password
- [x] **AUTH-02**: Passwords hashed with Argon2id (OWASP standard, 200-500ms target)
- [x] **AUTH-03**: Transparent password hash migration from bcrypt to Argon2id on login
- [x] **AUTH-04**: User can log in with email and password
- [x] **AUTH-05**: User can log out from any page
- [x] **AUTH-06**: Magic link / passwordless email authentication
- [x] **AUTH-07**: NIST-compliant password policies (min 8 chars with MFA, max 64+, no composition rules, no forced rotation)

### Email Confirmation

- [x] **CONF-01**: New registrations trigger confirmation email automatically (async via Oban)
- [x] **CONF-02**: Confirmation via link click or code entry
- [x] **CONF-03**: Configurable behavior for unconfirmed users (allow login with banner vs block login)
- [x] **CONF-04**: Resend confirmation with rate limiting
- [x] **CONF-05**: Token expiry with helpful error and resend link (default 48h TTL)
- [x] **CONF-06**: Tokens are single-use, HMAC-protected, hashed before storage

### Password Reset

- [x] **RESET-01**: User can request password reset via email
- [x] **RESET-02**: Email enumeration prevention (generic message regardless of email existence)
- [x] **RESET-03**: HMAC-protected, time-limited, single-use reset tokens (default 60min TTL)
- [x] **RESET-04**: Password change invalidates all existing sessions except current
- [x] **RESET-05**: Expired/used token shows helpful error with link to request new one

### Session Management

- [x] **SESS-01**: Server-side database-backed sessions (opaque token in cookie, data in DB)
- [x] **SESS-02**: Remember-me via separate long-lived cookie (default 60 days)
- [x] **SESS-03**: Session invalidation on password change (all sessions except current)
- [x] **SESS-04**: "Log out everywhere" — deletes all session tokens, broadcasts disconnect to LiveView sockets
- [x] **SESS-05**: Active session tracking with IP, user agent, last-active timestamp
- [x] **SESS-06**: Session management UI — users can view and revoke active sessions
- [x] **SESS-07**: Configurable idle timeout and absolute timeout
- [x] **SESS-08**: Secure cookie defaults (SameSite=Lax, HttpOnly, Secure)
- [x] **SESS-09**: Sudo/re-authentication mode for sensitive operations (change email, delete account, manage MFA)

### OAuth / Social Login

- [x] **OAUTH-01**: OAuth integration via Assent with PKCE and OIDC support
- [x] **OAUTH-02**: Google and GitHub as tier 1 providers (working in under 10 minutes)
- [x] **OAUTH-03**: Apple and Meta as tier 2 providers
- [x] **OAUTH-04**: Account linking — existing user links OAuth provider from settings
- [x] **OAUTH-05**: Email-match account linking with configurable behavior (auto-link vs require confirmation)
- [x] **OAUTH-06**: Multiple OAuth providers per user (user_identities table)
- [x] **OAUTH-07**: OAuth token storage (encrypted access + refresh tokens)
- [x] **OAUTH-08**: Graceful handling of edge cases (no email from provider, denied permissions, provider down, CSRF mismatch)

### Multi-Factor Authentication

- [x] **MFA-01**: TOTP enrollment with QR code generation and manual entry code
- [x] **MFA-02**: TOTP verification on login (6-digit code, 30s step, ±1 window)
- [x] **MFA-03**: Progressive auth states — `mfa_pending` session state prevents MFA bypass
- [x] **MFA-04**: Backup/recovery codes (8 single-use codes, hashed storage, shown once, regeneration)
- [x] **MFA-05**: "Trust this browser" cookie to skip MFA on trusted devices (configurable TTL)
- [x] **MFA-06**: MFA enforcement policies (per route or role)
- [x] **MFA-07**: Disable MFA requires current TOTP code or backup code
- [x] **MFA-08**: Rate-limited code attempts (5 attempts then 15-minute lockout)
- [x] **MFA-09**: TOTP secrets encrypted at rest

### API Authentication

- [x] **API-01**: Bearer token authentication via `Authorization: Bearer <token>` header
- [x] **API-02**: API key format with human-readable prefix (`myapp_live_<random>`)
- [x] **API-03**: API keys stored as SHA-256 hashes, shown only once at creation
- [x] **API-04**: Personal access tokens — user-scoped with scopes and configurable expiration
- [x] **API-05**: JWT support for stateless API use cases
- [x] **API-06**: Dual-mode auth plug (tries session first, falls back to bearer)
- [x] **API-07**: Token lifecycle — expiry, last-used tracking, revocation, listing active tokens

### Security

- [x] **SEC-01**: Account lockout after N failed attempts (default 5, temporary 15-30 min, never permanent)
- [x] **SEC-02**: IP-based rate limiting (10 failed attempts/IP/minute → 429)
- [x] **SEC-03**: Account-based rate limiting (failed attempts counter on user record)
- [x] **SEC-04**: Email enumeration prevention by default (constant-time comparisons, generic messages, dummy hash for nonexistent accounts)
- [x] **SEC-05**: CSRF protection integrated with Phoenix infrastructure
- [x] **SEC-06**: HMAC-protected tokens for all email flows (useless without server secret)
- [x] **SEC-07**: Suspicious login detection — new IP/device triggers email notification

### Transactional Email

- [x] **EMAIL-01**: Confirmation, password reset, lockout notification, suspicious login emails
- [x] **EMAIL-02**: Integration with Swoosh (or pluggable mailer behaviour)
- [x] **EMAIL-03**: HTML + text multipart emails
- [x] **EMAIL-04**: Easy email template customization (generated templates user can modify)
- [x] **EMAIL-05**: Async delivery via Oban with inline fallback

### Account Lifecycle

- [x] **ACCT-01**: Email change with re-verification (send to new address, keep old until confirmed)
- [x] **ACCT-02**: Password change with current password verification
- [x] **ACCT-03**: Account deletion with configurable handling (soft delete, hard delete, anonymization)
- [x] **ACCT-04**: Profile management hooks (callbacks for app-specific profile updates)

### Audit Logging

- [x] **AUDIT-01**: Automatic logging of all security-relevant auth events
- [x] **AUDIT-02**: Event metadata includes user, IP, user agent, timestamp, outcome
- [x] **AUDIT-03**: Queryable audit log API (by user, by org scope, by date range)
- [x] **AUDIT-04**: Hook for custom events

### Developer Experience

- [x] **DX-01**: Testing helpers importable in ExUnit that set up auth state in one call: `YourAppWeb.ConnCase.log_in_user/3` (generated), `YourApp.Accounts.register_user/2` (generated), `Sigra.Testing.setup_totp/2`, and `Sigra.Testing.create_api_token/3`. Arities reflect real option needs (`:mfa`, `:config`); names follow phx.gen.auth convention (Phase 1 D-43) and Phase 7 D-63 (`create_api_token`, not `create_api_key`).
- [x] **DX-02**: Comprehensive documentation with copy-paste examples
- [x] **DX-03**: Scenario-based test fixtures for auth states
- [x] **DX-04**: Cookie domain configuration with sensible defaults and easy override

## v1.x Requirements

Deferred to follow-up releases after v1 core is solid.

### WebAuthn / Passkeys

- **PASSKEY-01**: Passkey registration from security settings (via Wax library)
- **PASSKEY-02**: Passkey authentication as primary passwordless login
- **PASSKEY-03**: Passkey as second factor (alternative to TOTP)
- **PASSKEY-04**: Multiple passkeys per user with friendly names

### Additional Providers

- **PROV-01**: Additional OAuth providers beyond tier 1-2 (Discord, Slack, Twitter, etc.)

## v2 Requirements

Deferred to future milestone.

### Organizations / Multi-Tenancy

- **ORG-01**: Organizations with memberships join table and tenant-scoped roles
- **ORG-02**: Invitation flow (signed token, email, role, expiration)
- **ORG-03**: Organization context in auth (current_org, current_membership)
- **ORG-04**: Role-based access (owner, admin, member, viewer + custom roles)
- **ORG-05**: Verified domains for auto-join

### Admin / Impersonation

- **ADMIN-01**: Admin impersonation of other users (Scope struct carries `impersonated_by`)
- **ADMIN-02**: Impersonation audit trail

### Enterprise SSO

- **SSO-01**: Enterprise SSO per organization (SAML 2.0 / OIDC per org)
- **SSO-02**: JIT user provisioning from SSO assertion

## Out of Scope

| Feature | Reason |
|---------|--------|
| SAML support (v1) | Enterprise SSO protocol, high maintenance burden, low SaaS builder need. Architecture extensible for future plugin. |
| Acting as OAuth/OIDC identity provider | Enterprise B2B concern, dramatically expands scope. Architecture should not prevent future addition. |
| SCIM directory sync | Enterprise feature, extremely high scope. |
| Authorization (RBAC, permissions, policies) | Separate concern. Sigra provides identity context; authorization builds on top. |
| SMS OTP as primary MFA | NIST deprecated for primary factor. Document the pattern, leave integration to developer. |
| Permanent account lockout | DoS vector. Always temporary with configurable duration. |
| Macro-based schema injection | Explicitly anti-pattern (killed Pow). Generated schemas are plain Ecto. |
| Database adapter abstraction | Killed Lucia. Sigra is Ecto-first, no adapter layer. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| FOUND-06 | Phase 1 | Complete |
| FOUND-07 | Phase 1 | Complete |
| FOUND-08 | Phase 1 | Complete |
| FOUND-09 | Phase 1 | Complete |
| FOUND-10 | Phase 1 | Complete |
| AUTH-01 | Phase 2 | Complete |
| AUTH-02 | Phase 2 | Complete |
| AUTH-03 | Phase 2 | Complete |
| AUTH-04 | Phase 2 | Complete |
| AUTH-05 | Phase 2 | Complete |
| AUTH-06 | Phase 2 | Complete |
| AUTH-07 | Phase 2 | Complete |
| CONF-01 | Phase 3 | Complete |
| CONF-02 | Phase 3 | Complete |
| CONF-03 | Phase 3 | Complete |
| CONF-04 | Phase 3 | Complete |
| CONF-05 | Phase 3 | Complete |
| CONF-06 | Phase 3 | Complete |
| RESET-01 | Phase 3 | Complete |
| RESET-02 | Phase 3 | Complete |
| RESET-03 | Phase 3 | Complete |
| RESET-04 | Phase 3 | Complete |
| RESET-05 | Phase 3 | Complete |
| EMAIL-01 | Phase 3 | Complete |
| EMAIL-02 | Phase 3 | Complete |
| EMAIL-03 | Phase 3 | Complete |
| EMAIL-04 | Phase 3 | Complete |
| EMAIL-05 | Phase 3 | Complete |
| SESS-01 | Phase 4 | Complete |
| SESS-02 | Phase 4 | Complete |
| SESS-03 | Phase 4 | Complete |
| SESS-04 | Phase 4 | Complete |
| SESS-05 | Phase 4 | Complete |
| SESS-06 | Phase 4 | Complete |
| SESS-07 | Phase 4 | Complete |
| SESS-08 | Phase 4 | Complete |
| SEC-01 | Phase 4 | Complete |
| SEC-02 | Phase 4 | Complete |
| SEC-03 | Phase 4 | Complete |
| SEC-04 | Phase 4 | Complete |
| SEC-05 | Phase 4 | Complete |
| SEC-06 | Phase 4 | Complete |
| SEC-07 | Phase 4 | Complete |
| OAUTH-01 | Phase 5 | Complete |
| OAUTH-02 | Phase 5 | Complete |
| OAUTH-03 | Phase 5 | Complete |
| OAUTH-04 | Phase 5 | Complete |
| OAUTH-05 | Phase 5 | Complete |
| OAUTH-06 | Phase 5 | Complete |
| OAUTH-07 | Phase 5 | Complete |
| OAUTH-08 | Phase 5 | Complete |
| MFA-01 | Phase 6 | Complete |
| MFA-02 | Phase 6 | Complete |
| MFA-03 | Phase 6 | Complete |
| MFA-04 | Phase 6 | Complete |
| MFA-05 | Phase 6 | Complete |
| MFA-06 | Phase 6 | Complete |
| MFA-07 | Phase 6 | Complete |
| MFA-08 | Phase 6 | Complete |
| MFA-09 | Phase 6 | Complete |
| API-01 | Phase 7 | Complete |
| API-02 | Phase 7 | Complete |
| API-03 | Phase 7 | Complete |
| API-04 | Phase 7 | Complete |
| API-05 | Phase 7 | Complete |
| API-06 | Phase 7 | Complete |
| API-07 | Phase 7 | Complete |
| ACCT-01 | Phase 8 | Complete |
| ACCT-02 | Phase 8 | Complete |
| ACCT-03 | Phase 8 | Complete |
| ACCT-04 | Phase 8 | Complete |
| SESS-09 | Phase 8 | Complete |
| AUDIT-01 | Phase 9 | Complete |
| AUDIT-02 | Phase 9 | Complete |
| AUDIT-03 | Phase 9 | Complete |
| AUDIT-04 | Phase 9 | Complete |
| DX-01 | Phase 10 | Complete |
| DX-02 | Phase 10 | Complete |
| DX-03 | Phase 10 | Complete |
| DX-04 | Phase 10 | Complete |

**Coverage:**
- v1 requirements: 85 total
- Mapped to phases: 85
- Unmapped: 0

**Note:** REQUIREMENTS.md originally listed 80 requirements; actual count is 85 (SESS has 9, not grouped as 8; all categories counted individually at roadmap creation).

*Last updated: 2026-04-10 — milestone v1.0 audit: all 85 v1 requirements verified by per-phase VERIFICATION.md, traceability table flipped Pending → Complete.*

---
*Requirements defined: 2026-04-05*
*Last updated: 2026-04-05 after roadmap creation — full traceability added*
