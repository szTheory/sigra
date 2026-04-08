# Sigra

## What This Is

Sigra is a comprehensive authentication library for Elixir/Phoenix that fills the critical gap left by Pow's incompatibility with Phoenix 1.8+. It uses a hybrid lib+generator architecture: security-critical code lives in the library (updated via `mix deps.update`), while customizable application code (schemas, routes, LiveViews) is generated into the developer's project. Sigra targets Phoenix/Ecto as the blessed path, with Plug compatibility where it doesn't compromise DX.

## Core Value

Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

## Requirements

### Validated

- [x] `mix sigra.install` generator — Validated in Phase 1: Foundation
- [x] Phoenix context pattern (`MyApp.Auth`) — Validated in Phase 1: Foundation
- [x] Headless mode (all logic works without UI) — Validated in Phase 1: Foundation
- [x] Telemetry events for auth operations — Validated in Phase 1: Foundation (stubs)
- [x] Behaviour + callback architecture for extensibility — Validated in Phase 1: Foundation
- [x] No macro magic hiding schema fields — Validated in Phase 1: Foundation
- [x] Smart defaults with easy overrides — Validated in Phase 1: Foundation (NimbleOptions config)
- [x] Email/password registration with Argon2id hashing — Validated in Phase 2: Core Auth
- [x] Magic link / passwordless email authentication — Validated in Phase 2: Core Auth
- [x] Login / logout with server-side database-backed sessions — Validated in Phase 2: Core Auth
- [x] Password hash algorithm migration (transparent upgrade from bcrypt to Argon2id on login) — Validated in Phase 2: Core Auth
- [x] Account lockout after N failed attempts (temporary, configurable duration) — Validated in Phase 2: Core Auth
- [x] Email enumeration prevention by default (constant-time comparisons, generic messages) — Validated in Phase 2: Core Auth

### Active

#### Core Authentication
- [ ] Email confirmation (link + code verification)
- [ ] Password reset via secure email tokens (HMAC-protected, single-use, time-limited)
- [ ] Remember-me persistent sessions (separate long-lived cookie)
- [ ] Sudo/re-authentication mode for sensitive operations

#### OAuth / Social Login
- [ ] OAuth integration via Assent (Google, GitHub, Apple, Meta as tier 1)
- [ ] Account linking (existing user adds OAuth provider, email-match handling)
- [ ] Multiple OAuth providers per user
- [ ] PKCE and OIDC support (via Assent)

#### Multi-Factor Authentication
- [ ] TOTP enrollment, verification, and recovery (full lifecycle)
- [ ] Backup/recovery codes (8-10 single-use, hashed storage, regeneration)
- [ ] WebAuthn/passkeys as second factor and primary passwordless method
- [ ] "Trust this browser" cookie to skip MFA on trusted devices
- [ ] MFA enforcement policies (per route or role)

#### Session Management
- [ ] Active session tracking (IP, user agent, last active)
- [ ] Session revocation (individual and "log out everywhere")
- [ ] Session invalidation on password change
- [ ] Idle timeout and absolute timeout (configurable)
- [ ] Secure cookie defaults (SameSite=Lax, HttpOnly, Secure)

#### API Authentication
- [ ] Bearer token authentication (API keys with prefix format)
- [ ] Personal access tokens (user-scoped, with scopes and expiration)
- [ ] JWT support for stateless API use cases
- [ ] Dual-mode auth plug (session for browser, bearer for API)

#### Security
- [ ] IP-based and account-based rate limiting
- [ ] CSRF protection (integrated with Phoenix's existing infrastructure)
- [ ] HMAC-protected tokens for all email flows
- [ ] Suspicious login detection (new IP/device triggers email notification)

#### Transactional Email
- [ ] Confirmation, password reset, lockout notification, suspicious login emails
- [ ] Integration with Swoosh (or pluggable mailer interface)
- [ ] HTML + text multipart emails with cross-client compatibility
- [ ] Easy email template customization
- [ ] Async delivery via Oban (with inline fallback)

#### Account Lifecycle
- [ ] Account deletion with configurable handling (soft delete, hard delete, anonymization)
- [ ] Email change with re-verification
- [ ] Password change with current password verification
- [ ] Profile management hooks (callbacks for app-specific profile updates)

#### Developer Experience
- [ ] `mix sigra.install` generator (migrations, schemas, context, routes, optional LiveView pages)
- [ ] Phoenix context pattern (`MyApp.Auth`) following DDD boundaries
- [ ] Works with standard controllers/Plug (LiveView components optional)
- [ ] Headless mode (all logic works without UI)
- [ ] Testing helpers (`log_in_user/2`, `register_user/1`, `setup_totp/1`, `create_api_key/2`)
- [ ] Telemetry events for all auth operations
- [ ] Audit logging (security events with user, IP, user agent, action, metadata)

#### Configuration
- [ ] Smart defaults with easy overrides (confirmation required, lockout threshold, timeouts)
- [ ] Configurable table names
- [ ] Behaviour + callback architecture for extensibility
- [ ] No macro magic hiding schema fields

### Out of Scope

- SAML support — enterprise SSO protocol, high maintenance burden, low SaaS builder need. Leave architecture extensible for future plugin.
- Acting as OAuth/OIDC identity provider — enterprise/B2B concern, dramatically expands scope. Architecture should not prevent future addition.
- Organizations / multi-tenancy — deferred to v2 milestone. Design identity layer to support clean org membership later.
- Authorization (RBAC, permissions, policies) — separate concern. Sigra provides identity context; authorization builds on top.
- SCIM directory sync — enterprise feature, out of scope for v1.
- Admin impersonation — nice-to-have, defer to v2.

## Context

**Ecosystem gap:** Elixir's auth ecosystem is fragmented. phx.gen.auth is a minimal generator (no OAuth, MFA, API tokens, rate limiting). Pow is dead on Phoenix 1.8+. Ueberauth/NimbleTOTP/Guardian each handle one slice — no integrated solution exists. State of Elixir surveys (2023-2025) rank missing libraries as the #1-2 challenge.

**Prior art studied extensively:**
- **Devise** (Ruby) — cautionary tale of hidden magic, but defined the "batteries-included" category
- **Rodauth** (Ruby) — architectural gold standard (encapsulated auth object, per-feature tables, HMAC tokens, uniform DSL), but integration ergonomics suffer from Rack middleware approach
- **Better Auth** (JS) — modern benchmark for plugin architecture and composable features
- **Django Allauth** — feature completeness standard (100+ providers, MFA, headless API, identity provider)
- **Laravel** — progressive complexity with clear layers (Breeze → Jetstream → Fortify → Sanctum → Passport)
- **phx.gen.auth** — respects José's "own your code" philosophy, but security patches don't propagate

**Hybrid architecture chosen because:** Pure generators have a fatal flaw (no security patch propagation). Pure libraries fight the Elixir philosophy of visible code. The hybrid — security in the dep, UX in generated code — threads the needle.

**Database design:** Hybrid user/identity pattern — `users` table as stable identity anchor, `user_identities` table for credentials (password, OAuth providers). Separate tables per concern (tokens, passkeys, MFA credentials, API keys, audit log). This is the pattern Better Auth, Django Allauth, and PowAssent all converge on.

**Key dependencies (minimal, high-quality):**
- Assent — OAuth/OIDC (framework-agnostic, PKCE, 20+ providers in one package)
- Comeonin + Argon2 — password hashing
- NimbleTOTP — TOTP primitives (or copy-paste if simple enough)
- Wax — WebAuthn/FIDO2 ceremonies
- Swoosh — transactional email (pluggable mailer interface)
- Prefer copy-paste over deps where the code is small and stable

**Code philosophy:**
- Idiomatic Elixir/Plug/Phoenix
- DDD with clean layered architecture (domain → application services → infrastructure)
- Command/query separation at application layer
- Behaviours + callbacks for extensibility (no hidden macros)
- Dependency injection via module attributes/config for testability
- Principle of least surprise — API should be a joy to use
- Flat, self-contained AAA-style specs with scenario-based fixtures

**Target users:**
- Solo SaaS builders wanting auth done in an afternoon (Persona A)
- Mid-market engineering teams needing MFA/SSO for enterprise customers (Persona B)
- API builders needing bearer tokens and JWT (Persona C)
- Developers migrating from Pow or hand-rolled auth (Persona D)

## Constraints

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. Plug compatibility where DX is not compromised.
- **Database:** PostgreSQL as primary (citext, JSONB). MySQL/SQLite support via conditional migrations.
- **Security:** OWASP standards throughout. Argon2id default. All tokens HMAC-protected. Enumeration prevention by default.
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable.
- **LiveView:** Supported but optional. Core works with standard controllers. Login/logout via HTTP POST (not LiveView events).
- **Testing:** Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hybrid lib+generator architecture | Security patches propagate via dep updates; devs own customizable code. Respects José's philosophy while solving the patch propagation problem. | ✓ Validated Phase 1 |
| Assent over Ueberauth for OAuth | Framework-agnostic, PKCE/OIDC built-in, single package vs N strategy deps, actively maintained. Ueberauth is Plug-coupled with lagging strategies. | — Pending |
| Hybrid user/identity table pattern | `users` + `user_identities` — clean multi-provider support, natural Ecto idiom, matches Better Auth/Django Allauth/PowAssent pattern. Single merged table breaks with OAuth. | — Pending |
| Organizations deferred to v2 | Significant scope expansion. Core auth must be solid first. Identity layer designed to support org membership later. | — Pending |
| SAML/OAuth IdP out of scope | Enterprise concern with high maintenance burden. Architecture should not prevent future plugin/extension. | — Pending |
| Phoenix context pattern for generated code | `MyApp.Auth` context follows DDD boundaries, is idiomatic Phoenix, and keeps the public API clean. | ✓ Validated Phase 1 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-08 after Phase 6 completion — Multi-factor authentication: TOTP via NimbleTOTP, backup codes (SHA-256 hashed, single-use), trust cookies (HMAC + epoch revocation), MFA lockout, mfa_pending session gating, telemetry spans, testing helpers, generated schemas/migrations/emails, and MFA UI templates (challenge page, enrollment, settings) with generator wiring. Human UAT pending for visual verification and generator integration.*
