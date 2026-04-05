# Feature Research

**Domain:** Elixir/Phoenix Authentication Library (Sigra)
**Researched:** 2026-04-04
**Confidence:** HIGH — based on deep primary research documents, cross-ecosystem analysis of Rodauth, Better Auth, Django Allauth, Devise, Laravel, and direct community feedback (ElixirForum, State of Elixir surveys 2023–2025).

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features developers assume any serious auth library provides. Missing these means the library is not a viable alternative to hand-rolling auth.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Email/password registration | Every auth library since forever | LOW | Argon2id hashing; NIST-compliant policies (min 8 chars, max 64+, no composition rules) |
| Login / logout | Core auth primitive | LOW | Server-side database-backed sessions via opaque token in cookie |
| Email confirmation | Industry norm; spam prevention | MEDIUM | Link-based; single-use HMAC tokens; 48hr TTL; no-enumeration messaging |
| Password reset | Users forget passwords | MEDIUM | HMAC-protected token; single-use; 60min TTL; invalidates all sessions on success |
| Remember-me persistent session | Expected on any login form | LOW | Separate long-lived cookie (60-day default); distinct database token context |
| Route protection plugs | Core Phoenix integration need | LOW | `RequireAuth` plug; `on_mount` hook for LiveView; identical `current_user` on conn and socket |
| Social login — Google, GitHub | Users expect "Sign in with Google" | MEDIUM | Via Assent; auto-registers or links accounts; PKCE; OIDC |
| Account lockout after failed attempts | Security baseline | MEDIUM | Temporary lock (15–30min); never permanent (permanent = DoS vector); 5 attempts default |
| Email enumeration prevention | Security baseline; OWASP | LOW | Constant-time comparisons; generic messaging throughout all flows |
| CSRF protection | Phoenix security primitive | LOW | Integrated with Phoenix's existing CSRF infrastructure |
| Secure cookie defaults | Security baseline | LOW | `HttpOnly`, `Secure`, `SameSite=Lax` by default |
| `mix sigra.install` generator | Elixir ecosystem expectation | MEDIUM | Generates migrations, schema, context, routes, LiveViews; respects José's "own your code" philosophy |
| Testing helpers | Developers test their apps | LOW | `log_in_user/2`, `register_user/1`, `create_api_key/2`, `enroll_totp/1` for ExUnit |
| Telemetry events | Phoenix ecosystem norm | LOW | `:telemetry` events for login, logout, MFA challenge, token validation with user_id, IP, outcome |
| Session invalidation on password change | Security baseline | LOW | Deletes all session tokens for user except current on password change |
| Password change with current password verification | Security baseline | LOW | Requires current password before allowing change |
| Account deletion | Expected lifecycle management | MEDIUM | Configurable: soft delete, hard delete, or anonymization |

### Differentiators (Competitive Advantage)

Features that make Sigra meaningfully better than the existing Elixir ecosystem (phx.gen.auth + patchwork of libraries) and competitive with best-in-class auth libraries in other ecosystems.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| TOTP full lifecycle — enroll, verify, recover | NimbleTOTP leaves all of this to the developer; no integrated solution exists in Elixir | HIGH | Enrollment UI, QR code, backup codes (8 single-use, SHA-256 hashed), enforcement policies, trust-this-browser cookie |
| WebAuthn / passkeys | Forward-looking; increasingly expected for B2B | HIGH | Via Wax library; second factor AND primary passwordless; multiple passkeys per user |
| API bearer token authentication | Persona C has no good integrated option today | MEDIUM | Prefix-format keys (`myapp_live_abc...`); hashed storage; scopes; expiration; dual-mode AnyAuth plug |
| Active session tracking and revocation UI | Security-conscious users demand this; no Elixir library provides it | MEDIUM | IP + user agent + last active per session; revoke individual or all; LiveView component included |
| Security patch propagation via dep updates | Fatal flaw of phx.gen.auth's pure-generator approach | MEDIUM | Hybrid lib+generator: security-critical code in library dep; UX code generated into project |
| Oban-backed async email delivery | Production-quality email reliability | LOW | Async via Oban jobs; inline fallback for apps without Oban; Swoosh adapter |
| Audit logging | Required for SOC2/compliance; no Elixir lib provides this | MEDIUM | Structured event log: user_id, IP, user agent, action, outcome, timestamp; queryable API |
| Sudo / re-authentication mode | Security best practice; Phoenix 1.8 ships a basic version; Sigra makes it ergonomic | LOW | `RequireSudo` plug; configurable window; triggers on sensitive operations |
| Suspicious login detection | Differentiating security feature; Rodauth-inspired | MEDIUM | New IP/device triggers email notification; configurable sensitivity |
| Password hash migration (bcrypt → Argon2id) | Devs migrating from Pow/hand-rolled need this | LOW | Transparent upgrade on successful login; no forced migration downtime |
| Magic link / passwordless email | Phoenix 1.8 direction; consumer app DX | LOW | Single-use HMAC token; 15min TTL; rate-limited send |
| Headless mode | API builders (Persona C) need auth without HTML | LOW | All logic works without UI; components are optional add-on |
| "Trust this browser" MFA cookie | Reduces MFA friction for trusted devices | LOW | Encrypted cookie; 14-day default; skips MFA challenge on recognized device |
| Organizations / multi-tenancy with invitations | Most B2B SaaS needs this; no Elixir lib provides it | HIGH | Memberships table with roles; invitation flow with signed tokens; org context on socket/conn |
| Multiple OAuth providers per user | Social login account linking | MEDIUM | Link/unlink from settings; email-match handling (auto-link vs. confirm configurable) |
| Personal access tokens (PAT) | GitHub-style developer credentials | LOW | User-scoped; inherit user permissions filtered by scopes; expiration; last-used tracking |
| JWT support | API builders with stateless requirements | LOW | For stateless API use cases only; opaque tokens everywhere else |
| IP-based rate limiting | Security baseline that most libraries leave out | MEDIUM | Via Hammer or ETS; 10 failed attempts/min/IP; pluggable rate limiter interface |
| Email change with dual-notification | Security best practice; subtle to implement correctly | LOW | Verify new address; notify old address with cancel link; 24hr expiration |
| Profile management hooks / callbacks | Developers always need to extend user data | LOW | Callbacks for post-registration, post-login; app extends profile without fighting library |
| Configurable table names | Developers with existing schemas need flexibility | LOW | For Persona D (Pow migrators) and teams with established naming conventions |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem valuable but create more problems than they solve, or that fall outside the appropriate scope for an auth library.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| SAML support (built-in) | Enterprise customers demand SAML | Enormous maintenance burden; SAML is XML-based, has dozens of edge cases in IdP implementations, requires ongoing security scrutiny; kills velocity | Architecture should not prevent a future SAML plugin/extension; provide integration points. Defer. |
| Acting as OAuth/OIDC identity provider | Platform builders want to issue OAuth tokens to third-party apps | Dramatically expands scope beyond authentication into authorization server territory; different threat model entirely; Boruta already exists for this | Document how to integrate Boruta alongside Sigra; provide the handshake |
| Built-in authorization (RBAC, policies) | Developers want one library for identity + permissions | Authorization is a separate concern; conflating the two creates coupling that limits both; every app has different permission models | Sigra provides identity context (current_user, current_org, role); authorization builds on top with Permit, LetMe, or custom logic |
| SCIM directory sync | Enterprise HR-driven user provisioning | Niche enterprise concern; requires implementing SCIM server spec; high maintenance; tiny percentage of users | Defer to a future enterprise plugin; document the integration pattern for teams that need it |
| Admin impersonation | Support teams need to see user's view | Security risk if not implemented carefully; creates audit/compliance complications; each app has different impersonation policies | Provide the building blocks (load_user/1, create_session_for/2) and document the pattern; defer built-in support to v2 |
| Permanent account lockout | "Lock out bad actors forever" | Permanent lockout is a DoS vector — attackers lock target accounts by intentionally failing logins; support teams get flooded with unlock requests | Temporary lockout with auto-release (15–30min default); admin unlock endpoint; IP-based rate limiting catches persistent attackers |
| SMS OTP as primary MFA | Widely deployed, users are familiar with SMS codes | SIM swap attacks make SMS fundamentally insecure as a second factor; NIST 800-63B deprecated it; library should not encourage insecure patterns | Support SMS OTP as a v1.x add-on with prominent security warnings; push TOTP and passkeys as primary MFA |
| Macro-based schema injection (Devise-style `use Auth.Schema`) | Reduces boilerplate | Hides schema fields; breaks Ecto introspection; violates José Valim's explicit objection; hard to customize; creates "magic" that confuses debugging | Generator approach: generate real Ecto schema files the developer owns |
| Storing hashed passwords on the users table | Simplest implementation | Single table exposure; harder to implement per-table PostgreSQL security definer isolation (Rodauth's innovation); couples identity and credentials | Separate `user_identities` table for credentials; users table is stable identity anchor |
| Enforcing specific password complexity rules | "Stronger passwords" | NIST 800-63B explicitly recommends against composition rules (mix of upper/lower/numbers/symbols); they don't improve security and worsen UX | Enforce minimum length (12+ recommended), maximum length (64+), and check against common password lists; strength meter is fine |
| Email-only registration by default (no password option) | Reduces friction | Magic links as the only option breaks developer tooling (curl, API clients, tests); limits Persona C; confuses Persona D migrating from password auth | Magic links as an option alongside password auth; Phoenix 1.8's direction is right but should not be forced |
| Synchronous email delivery inline | "Keep it simple" | Blocks request; creates timeout risk; drops emails on provider downtime; no retry | Oban-backed async delivery with inline fallback for apps without Oban |

---

## Feature Dependencies

```
Email/password auth
    └──requires──> Password hashing (Argon2id via Comeonin)
    └──requires──> User schema + migration (generated)
    └──requires──> Session management (opaque token, database-backed)
    └──requires──> Email delivery (Swoosh adapter)

Email confirmation
    └──requires──> Email/password auth
    └──requires──> HMAC token generation
    └──requires──> Email delivery

Password reset
    └──requires──> Email/password auth
    └──requires──> HMAC token generation
    └──requires──> Email delivery
    └──requires──> Session invalidation on success

TOTP / 2FA
    └──requires──> Email/password auth (must already be authenticated to enroll)
    └──requires──> MFA credentials table (encrypted TOTP secret)
    └──requires──> Backup codes table (hashed)
    └──requires──> Partial session state (mfa_pending flag)
    └──enhances──> Session management (MFA challenge gate)

WebAuthn / passkeys
    └──requires──> Wax library
    └──requires──> Passkey credentials table
    └──requires──> JavaScript ceremony module (client-side)
    └──can──replace──> TOTP as second factor
    └──can──replace──> Password as primary credential

Social login / OAuth
    └──requires──> Assent library + provider config
    └──requires──> user_identities / oauth_accounts table
    └──requires──> Account linking logic (email-match handling)
    └──enhances──> Registration (social signup path)

API bearer tokens
    └──requires──> api_keys table (hashed key, prefix, scopes, expiration)
    └──requires──> BearerAuth plug
    └──enhances──> AnyAuth dual-mode plug (session OR bearer)

Audit logging
    └──requires──> audit_log table
    └──enhances──> All auth operations (emits events)
    └──enhances──> Organizations (org-scoped queries)

Active session tracking
    └──requires──> Session management (extends user_tokens with IP/UA/last_active)
    └──requires──> Session revocation UI (LiveView component)

Organizations / multi-tenancy
    └──requires──> Email/password auth (users must exist first)
    └──requires──> organizations + memberships + invitations tables
    └──requires──> Email delivery (invitation emails)
    └──enhances──> Audit logging (org-scoped events)
    └──enhances──> TOTP/MFA (org-level MFA enforcement policy)

Enterprise SSO (SAML/OIDC per org)
    └──requires──> Organizations
    └──requires──> SAML/OIDC library (external)
    └──requires──> user_identities table (SSO-provisioned identities)

Sudo mode
    └──requires──> Email/password auth
    └──enhances──> Any sensitive operation (change password, delete account, view API keys)

Magic links
    └──requires──> Email delivery
    └──requires──> HMAC token generation
    └──can──coexist──with──> Email/password auth
    └──conflicts──with──> "magic links as the ONLY auth method" (breaks API clients)

Remember-me
    └──requires──> Session management (separate database token context)
    └──requires──> Long-lived cookie handling

Trust-this-browser (MFA skip)
    └──requires──> TOTP or WebAuthn (something to skip)
    └──requires──> Encrypted browser cookie

Suspicious login detection
    └──requires──> Session management (stores IP/user agent)
    └──requires──> Email delivery
    └──enhances──> Audit logging

Password hash migration (bcrypt → Argon2id)
    └──requires──> Email/password auth
    └──requires──> Hash algorithm detection on login
```

### Dependency Notes

- **TOTP requires partial session state:** The `mfa_pending` flag in session must exist before TOTP verification can be built. Full authentication only completes after the second factor is verified. This is a non-obvious state machine requirement.
- **Organizations depend on users, not the reverse:** The identity layer must be complete and stable before adding multi-tenancy on top. Building both simultaneously creates scope risk.
- **Audit logging enhances everything but blocks nothing:** Audit logging can be added to each feature as it ships without blocking earlier features from launching. However, it should be designed from the start so the schema and API are consistent.
- **WebAuthn requires client-side JavaScript:** Unlike TOTP (which just needs QR code generation), passkeys require a JavaScript ceremony module that must be served with the application. This is a deployment consideration.
- **API bearer tokens conflict with pure-session architecture:** Introducing bearer tokens requires the AnyAuth dual-mode plug pattern and careful thought about which operations are session-only (logout, for example, cannot be done via bearer token for security reasons).
- **Social login's account linking logic is the hardest part:** The easy case (new user, register) is trivial. The hard cases — email already exists in the system, provider doesn't return an email, user wants to link a second provider — are where bugs live. Plan for explicit handling of each case.

---

## MVP Definition

### Launch With (v1.0 — "Solid Foundation")

Minimum feature set that is genuinely useful for production SaaS apps and meaningfully better than the current phx.gen.auth + manual patchwork.

- [ ] Email/password registration with Argon2id — the foundation all else builds on
- [ ] Login / logout with database-backed sessions — can't ship without this
- [ ] Email confirmation with HMAC tokens — required for anti-spam; v1 must have it
- [ ] Password reset via secure email tokens — required; auth without password reset is unusable
- [ ] Remember-me persistent session — expected on any login form
- [ ] `mix sigra.install` generator — without this, adoption is blocked; the install story IS the product
- [ ] Route protection plugs (HTTP + LiveView on_mount) — developers cannot use Sigra without this
- [ ] Social login via Assent (Google, GitHub at minimum) — the #1 community pain point; differentiates from phx.gen.auth immediately
- [ ] Account lockout + IP-based rate limiting — security baseline that phx.gen.auth lacks
- [ ] Email enumeration prevention by default — security baseline; must be on by default
- [ ] Session invalidation on password change — security baseline
- [ ] Telemetry events — Phoenix ecosystem norm; needed from day one for observability
- [ ] Testing helpers — developers must be able to test their auth flows; ship with ExUnit helpers

### Add After Validation (v1.x — "Production Ready")

Features to add once the core installation story and security baseline are validated working.

- [ ] TOTP full lifecycle (enroll, verify, backup codes) — B2B enterprise requirement; #2 community pain point
- [ ] API bearer token authentication — required for Persona C; significant unlock for API builders
- [ ] Active session tracking and revocation UI — security-conscious users and compliance buyers need this
- [ ] Audit logging — needed before any compliance conversation; builds on session tracking
- [ ] Sudo / re-authentication mode — security best practice for settings pages
- [ ] Email change with dual-notification — complete account lifecycle management
- [ ] Magic link / passwordless email — Phoenix 1.8 direction; consumer DX win
- [ ] Password hash migration (bcrypt → Argon2id) — Persona D (Pow migrators) need this
- [ ] Personal access tokens — extends API bearer token feature; GitHub-style PATs
- [ ] Suspicious login detection — differentiating security feature
- [ ] "Trust this browser" MFA cookie — reduces MFA friction after TOTP ships
- [ ] JWT support — stateless API use cases; low complexity add-on after bearer tokens exist

### Future Consideration (v2+)

Defer until core is solid and community adoption is validated.

- [ ] WebAuthn / passkeys — high value, high complexity; Wax integration needs careful design
- [ ] Organizations / multi-tenancy with invitations — significant scope; requires stable identity layer first
- [ ] Enterprise SSO (SAML/OIDC per org) — depends on Organizations; niche until PMF
- [ ] SMS OTP as MFA fallback — security concerns; defer and ship with strong warnings when added
- [ ] Admin impersonation — v2 nice-to-have; provide building blocks in v1
- [ ] OAuth2 server (act as IdP) — Boruta integration; separate concern from auth library
- [ ] SCIM directory sync — enterprise niche; future plugin architecture

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Email/password auth | HIGH | LOW | P1 |
| Login/logout + sessions | HIGH | LOW | P1 |
| `mix sigra.install` generator | HIGH | MEDIUM | P1 |
| Route protection (Plug + LiveView) | HIGH | LOW | P1 |
| Email confirmation | HIGH | LOW | P1 |
| Password reset | HIGH | LOW | P1 |
| Social login (Google, GitHub) | HIGH | MEDIUM | P1 |
| Account lockout + rate limiting | HIGH | MEDIUM | P1 |
| Email enumeration prevention | HIGH | LOW | P1 |
| Testing helpers | HIGH | LOW | P1 |
| Telemetry events | MEDIUM | LOW | P1 |
| Remember-me | MEDIUM | LOW | P1 |
| TOTP full lifecycle | HIGH | HIGH | P2 |
| API bearer tokens | HIGH | MEDIUM | P2 |
| Session tracking + revocation UI | MEDIUM | MEDIUM | P2 |
| Audit logging | HIGH | MEDIUM | P2 |
| Sudo mode | MEDIUM | LOW | P2 |
| Email change | MEDIUM | LOW | P2 |
| Magic links | MEDIUM | LOW | P2 |
| Password hash migration | MEDIUM | LOW | P2 |
| Personal access tokens | MEDIUM | LOW | P2 |
| "Trust this browser" cookie | LOW | LOW | P2 |
| Suspicious login detection | MEDIUM | MEDIUM | P2 |
| JWT support | MEDIUM | LOW | P2 |
| WebAuthn / passkeys | HIGH | HIGH | P3 |
| Organizations + invitations | HIGH | HIGH | P3 |
| Enterprise SSO per org | HIGH | HIGH | P3 |
| SMS OTP | LOW | MEDIUM | P3 |
| Admin impersonation | LOW | MEDIUM | P3 |
| OAuth2 server (IdP) | LOW | HIGH | P3 |
| SCIM directory sync | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v1.0 launch
- P2: Should have in v1.x; required for production-grade completeness
- P3: Future consideration; v2+ or plugin

---

## Competitor Feature Analysis

| Feature | phx.gen.auth | Pow (dead) | NimbleTOTP + Ueberauth patchwork | Devise (Ruby) | Rodauth (Ruby) | Better Auth (JS) | Django Allauth (Python) | Sigra approach |
|---------|-------------|------------|----------------------------------|---------------|----------------|------------------|-------------------------|----------------|
| Email/password auth | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes, Argon2id default |
| Security patch propagation | No (generator) | N/A (dead) | No (generators) | Yes (gem) | Yes (gem) | Yes (package) | Yes (package) | Yes (hybrid lib+gen) |
| Social login (OAuth) | No | Via PowAssent | Via Ueberauth/Assent (manual) | Via OmniAuth (manual) | Via Rodauth plugin | Yes (30+ providers) | Yes (100+ providers) | Yes, via Assent |
| TOTP / 2FA | No | Via PowTwoFactor | Via NimbleTOTP (bare primitives only) | Via devise-two-factor gem | Yes (built-in plugin) | Yes (plugin) | Yes (built-in) | Yes, full lifecycle |
| WebAuthn / passkeys | No | No | No | No | Yes (built-in plugin) | Yes (plugin) | Yes (built-in) | v2 (via Wax) |
| API bearer tokens | No | No | Via Guardian (manual) | No | Yes (JSON mode for all features) | Yes (apiKey plugin) | Via DRF (manual) | Yes, prefix-format keys |
| Session management UI | No | No | No | No | Yes (active_sessions plugin) | Yes | Yes (usersessions app) | Yes, with revocation |
| Audit logging | No | No | No | No | Yes (audit_logging plugin) | No | No | Yes |
| Sudo / re-auth mode | Yes (Phoenix 1.8) | No | No | No | No (manual) | No | No | Yes, ergonomic plug |
| Org / multi-tenancy | No | No | No | No | No | Yes (organization plugin) | No | v2 |
| Magic links | Default in Phoenix 1.8 | No | Via Magic Auth (separate lib) | No | Yes (email_auth plugin) | Yes (magicLink plugin) | No | Yes |
| Account lockout | No | No | No | Yes (lockable module) | Yes (lockout plugin) | No | No | Yes, temporary with auto-release |
| Email enumeration prevention | Partial | Partial | No | No | Yes (first-class feature) | No | Yes | Yes, on by default |
| Testing helpers | Yes (basic) | Yes | No | Via Devise test helpers | No | No | No | Yes, comprehensive |
| LiveView integration | Yes | No | No | N/A | N/A (Rails) | N/A (JS) | N/A (Python) | Yes, first-class |
| Install generator | Yes | No | No | No (magic) | Via rodauth-rails | CLI (DB migrations) | Yes | Yes, hybrid approach |
| Configuration surface | Scattered | Config + macros | N/A (multiple libs) | Multi-layer (confusing) | Uniform DSL | Plugin composition | Django settings | Single flat config module |

---

## Sources

- Primary research: "Building the gold-standard Elixir/Phoenix authentication library" (comprehensive ecosystem analysis)
- Community data: "The biggest gaps in Elixir's ecosystem for SaaS builders" (State of Elixir surveys 2023–2025)
- User flows: "Phoenix Auth Library — Jobs to Be Done, Personas & User Flows" (P0/P1/P2 priority framework)
- Domain vocabulary: "Auth Domain Language — A Field Guide"
- Project context: `.planning/PROJECT.md`
- Rodauth documentation and feature list: https://rodauth.jeremyevans.net/rdoc/files/README_rdoc.html
- Better Auth plugin list: https://www.better-auth.com/docs/plugins
- Django Allauth feature overview: https://allauth.org
- Devise modules: https://github.com/heartcombo/devise
- Laravel auth layers: Breeze / Jetstream / Fortify / Sanctum / Passport documentation
- phx.gen.auth Phoenix 1.8 changelog (magic links, sudo mode, scopes)
- Assent library: https://github.com/pow-auth/assent
- Wax WebAuthn library: https://github.com/tanguilp/wax
- NIST SP 800-63B password guidelines
- OWASP Authentication Cheat Sheet

---
*Feature research for: Elixir/Phoenix authentication library (Sigra)*
*Researched: 2026-04-04*
