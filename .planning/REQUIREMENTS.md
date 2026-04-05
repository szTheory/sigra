# Requirements: Sigra

**Defined:** 2026-04-05
**Core Value:** Authentication that works out of the box with great DX — so developers can ship SaaS apps fast and grow with confidence.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [ ] **FOUND-01**: Library initializes via `mix sigra.install` generating migrations, schemas, context module, plugs, and optional LiveView pages
- [ ] **FOUND-02**: Generated code follows Phoenix context pattern (`MyApp.Auth`) with clean DDD boundaries
- [ ] **FOUND-03**: Security-critical code lives in Sigra library dep; customizable code is generated into user's project
- [ ] **FOUND-04**: No macro-based schema injection — generated schemas are plain Ecto schemas calling library functions
- [ ] **FOUND-05**: Configuration via explicit options with smart defaults (confirmation required, lockout threshold, timeouts, table names)
- [ ] **FOUND-06**: Behaviour + callback architecture for extensibility (mailer, rate limiter, session store)
- [ ] **FOUND-07**: Telemetry events emitted for all auth operations (login, logout, register, MFA, lockout, etc.)
- [ ] **FOUND-08**: Works with standard controllers/Plug without requiring LiveView
- [ ] **FOUND-09**: Optional LiveView components for login, registration, MFA, settings
- [ ] **FOUND-10**: Headless mode — all logic works without any UI components

### Email/Password Authentication

- [ ] **AUTH-01**: User can register with email and password
- [ ] **AUTH-02**: Passwords hashed with Argon2id (OWASP standard, 200-500ms target)
- [ ] **AUTH-03**: Transparent password hash migration from bcrypt to Argon2id on login
- [ ] **AUTH-04**: User can log in with email and password
- [ ] **AUTH-05**: User can log out from any page
- [ ] **AUTH-06**: Magic link / passwordless email authentication
- [ ] **AUTH-07**: NIST-compliant password policies (min 8 chars with MFA, max 64+, no composition rules, no forced rotation)

### Email Confirmation

- [ ] **CONF-01**: New registrations trigger confirmation email automatically (async via Oban)
- [ ] **CONF-02**: Confirmation via link click or code entry
- [ ] **CONF-03**: Configurable behavior for unconfirmed users (allow login with banner vs block login)
- [ ] **CONF-04**: Resend confirmation with rate limiting
- [ ] **CONF-05**: Token expiry with helpful error and resend link (default 48h TTL)
- [ ] **CONF-06**: Tokens are single-use, HMAC-protected, hashed before storage

### Password Reset

- [ ] **RESET-01**: User can request password reset via email
- [ ] **RESET-02**: Email enumeration prevention (generic message regardless of email existence)
- [ ] **RESET-03**: HMAC-protected, time-limited, single-use reset tokens (default 60min TTL)
- [ ] **RESET-04**: Password change invalidates all existing sessions except current
- [ ] **RESET-05**: Expired/used token shows helpful error with link to request new one

### Session Management

- [ ] **SESS-01**: Server-side database-backed sessions (opaque token in cookie, data in DB)
- [ ] **SESS-02**: Remember-me via separate long-lived cookie (default 60 days)
- [ ] **SESS-03**: Session invalidation on password change (all sessions except current)
- [ ] **SESS-04**: "Log out everywhere" — deletes all session tokens, broadcasts disconnect to LiveView sockets
- [ ] **SESS-05**: Active session tracking with IP, user agent, last-active timestamp
- [ ] **SESS-06**: Session management UI — users can view and revoke active sessions
- [ ] **SESS-07**: Configurable idle timeout and absolute timeout
- [ ] **SESS-08**: Secure cookie defaults (SameSite=Lax, HttpOnly, Secure)
- [ ] **SESS-09**: Sudo/re-authentication mode for sensitive operations (change email, delete account, manage MFA)

### OAuth / Social Login

- [ ] **OAUTH-01**: OAuth integration via Assent with PKCE and OIDC support
- [ ] **OAUTH-02**: Google and GitHub as tier 1 providers (working in under 10 minutes)
- [ ] **OAUTH-03**: Apple and Meta as tier 2 providers
- [ ] **OAUTH-04**: Account linking — existing user links OAuth provider from settings
- [ ] **OAUTH-05**: Email-match account linking with configurable behavior (auto-link vs require confirmation)
- [ ] **OAUTH-06**: Multiple OAuth providers per user (user_identities table)
- [ ] **OAUTH-07**: OAuth token storage (encrypted access + refresh tokens)
- [ ] **OAUTH-08**: Graceful handling of edge cases (no email from provider, denied permissions, provider down, CSRF mismatch)

### Multi-Factor Authentication

- [ ] **MFA-01**: TOTP enrollment with QR code generation and manual entry code
- [ ] **MFA-02**: TOTP verification on login (6-digit code, 30s step, ±1 window)
- [ ] **MFA-03**: Progressive auth states — `mfa_pending` session state prevents MFA bypass
- [ ] **MFA-04**: Backup/recovery codes (8 single-use codes, hashed storage, shown once, regeneration)
- [ ] **MFA-05**: "Trust this browser" cookie to skip MFA on trusted devices (configurable TTL)
- [ ] **MFA-06**: MFA enforcement policies (per route or role)
- [ ] **MFA-07**: Disable MFA requires current TOTP code or backup code
- [ ] **MFA-08**: Rate-limited code attempts (5 attempts then 15-minute lockout)
- [ ] **MFA-09**: TOTP secrets encrypted at rest

### API Authentication

- [ ] **API-01**: Bearer token authentication via `Authorization: Bearer <token>` header
- [ ] **API-02**: API key format with human-readable prefix (`myapp_live_<random>`)
- [ ] **API-03**: API keys stored as SHA-256 hashes, shown only once at creation
- [ ] **API-04**: Personal access tokens — user-scoped with scopes and configurable expiration
- [ ] **API-05**: JWT support for stateless API use cases
- [ ] **API-06**: Dual-mode auth plug (tries session first, falls back to bearer)
- [ ] **API-07**: Token lifecycle — expiry, last-used tracking, revocation, listing active tokens

### Security

- [ ] **SEC-01**: Account lockout after N failed attempts (default 5, temporary 15-30 min, never permanent)
- [ ] **SEC-02**: IP-based rate limiting (10 failed attempts/IP/minute → 429)
- [ ] **SEC-03**: Account-based rate limiting (failed attempts counter on user record)
- [ ] **SEC-04**: Email enumeration prevention by default (constant-time comparisons, generic messages, dummy hash for nonexistent accounts)
- [ ] **SEC-05**: CSRF protection integrated with Phoenix infrastructure
- [ ] **SEC-06**: HMAC-protected tokens for all email flows (useless without server secret)
- [ ] **SEC-07**: Suspicious login detection — new IP/device triggers email notification

### Transactional Email

- [ ] **EMAIL-01**: Confirmation, password reset, lockout notification, suspicious login emails
- [ ] **EMAIL-02**: Integration with Swoosh (or pluggable mailer behaviour)
- [ ] **EMAIL-03**: HTML + text multipart emails
- [ ] **EMAIL-04**: Easy email template customization (generated templates user can modify)
- [ ] **EMAIL-05**: Async delivery via Oban with inline fallback

### Account Lifecycle

- [ ] **ACCT-01**: Email change with re-verification (send to new address, keep old until confirmed)
- [ ] **ACCT-02**: Password change with current password verification
- [ ] **ACCT-03**: Account deletion with configurable handling (soft delete, hard delete, anonymization)
- [ ] **ACCT-04**: Profile management hooks (callbacks for app-specific profile updates)

### Audit Logging

- [ ] **AUDIT-01**: Automatic logging of all security-relevant auth events
- [ ] **AUDIT-02**: Event metadata includes user, IP, user agent, timestamp, outcome
- [ ] **AUDIT-03**: Queryable audit log API (by user, by org scope, by date range)
- [ ] **AUDIT-04**: Hook for custom events

### Developer Experience

- [ ] **DX-01**: Testing helpers (`log_in_user/2`, `register_user/1`, `setup_totp/1`, `create_api_key/2`)
- [ ] **DX-02**: Comprehensive documentation with copy-paste examples
- [ ] **DX-03**: Scenario-based test fixtures for auth states
- [ ] **DX-04**: Cookie domain configuration with sensible defaults and easy override

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
| FOUND-01 through FOUND-10 | TBD | Pending |
| AUTH-01 through AUTH-07 | TBD | Pending |
| CONF-01 through CONF-06 | TBD | Pending |
| RESET-01 through RESET-05 | TBD | Pending |
| SESS-01 through SESS-09 | TBD | Pending |
| OAUTH-01 through OAUTH-08 | TBD | Pending |
| MFA-01 through MFA-09 | TBD | Pending |
| API-01 through API-07 | TBD | Pending |
| SEC-01 through SEC-07 | TBD | Pending |
| EMAIL-01 through EMAIL-05 | TBD | Pending |
| ACCT-01 through ACCT-04 | TBD | Pending |
| AUDIT-01 through AUDIT-04 | TBD | Pending |
| DX-01 through DX-04 | TBD | Pending |

**Coverage:**
- v1 requirements: 80 total
- Mapped to phases: 0
- Unmapped: 80 (pending roadmap creation)

---
*Requirements defined: 2026-04-05*
*Last updated: 2026-04-05 after initial definition*
