# Project Research Summary

**Project:** Sigra
**Domain:** Elixir/Phoenix open-source authentication library (hybrid lib+generator)
**Researched:** 2026-04-04
**Confidence:** HIGH

## Executive Summary

Sigra is a production-grade Phoenix 1.8+ authentication library that fills the gap left by Pow's death and phx.gen.auth's limitations. The core insight from research across all four domains is that Sigra must be a **hybrid library**: security-critical operations (hashing, token generation, TOTP verification, WebAuthn ceremonies, rate limiting) live in the library dep so security patches propagate via `mix deps.update`, while customizable UX code (schemas, controllers, LiveViews, routes, context module) is generated into the developer's project so they own and can modify it freely. This hybrid model is the primary differentiator — not a feature, but an architectural property — and it must be established in Phase 1 before anything else.

The recommended approach builds on a well-understood stack: Elixir 1.18+/OTP 27/Phoenix 1.8 with Argon2id (argon2_elixir) for password hashing, Assent for OAuth/OIDC, NimbleTOTP for TOTP primitives, Wax for WebAuthn, Hammer for rate limiting, and Swoosh/Oban for async email delivery. The architecture is Rodauth-inspired: per-feature tables with narrow responsibilities, a per-request auth context struct (`Scope`) that models authentication as a progression of states (anonymous → authenticated → mfa_complete → sudo), and behaviours over macros at every extensibility point. The generator produces explicit, readable Ecto schemas with no hidden field injection.

The key risks are all Phase 1 decisions that cannot be retrofit: macro-driven schema hiding (the Pow trap), pure-generator architecture with no security patch path (the phx.gen.auth trap), JWT for browser sessions (the Guardian trap), and database adapter abstraction (the Lucia trap). Each of these has caused a well-known auth library to fail or become unmaintainable. Research is unambiguous: get the library/generated boundary right, use opaque database-backed tokens for sessions, target Ecto exclusively, and use behaviours instead of macros. Everything downstream depends on these decisions holding.

---

## Key Findings

### Recommended Stack

The stack is Phoenix-native with no surprising choices. Argon2id via `argon2_elixir` is the OWASP-recommended password hashing algorithm (memory-hard, GPU-resistant); bcrypt support is kept as an optional migration path only. Assent replaces Ueberauth because it is framework-agnostic, has PKCE support, covers 20+ providers in one package, and is actively maintained. For MFA, NimbleTOTP provides the RFC 6238 cryptographic primitive but Sigra must build the full lifecycle on top (enrollment state machine, backup codes, trust-this-browser, enforcement policies). Wax is the only maintained WebAuthn library for Elixir; it passes all 170 official test suite tests and is deferred to v2. Hammer 7.x provides rate limiting with an ETS backend requiring no external dependency, with an optional Redis backend for multi-node deployments. Oban provides background email delivery with automatic inline fallback for apps not using Oban.

**Core technologies:**
- `argon2_elixir ~> 4.1`: Password hashing — OWASP gold-standard Argon2id; wrap behind `Sigra.Password`, never expose directly
- `comeonin ~> 5.3`: Password hashing behaviour — enables transparent bcrypt→Argon2id migration on login
- `assent ~> 0.3`: OAuth 2.0 / OIDC / social login — framework-agnostic, PKCE, 20+ providers; preferred over Ueberauth
- `nimble_totp ~> 1.0`: TOTP RFC 6238 primitive — cryptographic primitive only; full lifecycle built in Sigra
- `wax_ ~> 0.7`: WebAuthn / FIDO2 / passkeys — only maintained Elixir WebAuthn library; deferred to v2
- `swoosh ~> 1.5` (optional): Transactional email — Phoenix default mailer; expose `Sigra.Mailer` behaviour for swappability
- `hammer ~> 7.3` (optional): Rate limiting — ETS backend, no Redis required; Hammer 7.x API is a breaking change from 6.x
- `oban ~> 2.17` (optional): Background jobs — async email delivery with inline fallback; token cleanup jobs
- `cloak_ecto ~> 1.3`: Field encryption — AES-256-GCM for OAuth tokens and TOTP secrets at rest
- `nimble_options ~> 1.1`: Option validation — eliminates scattered config; auto-generates documentation
- Elixir `~> 1.18`, OTP `~> 27`, Phoenix `~> 1.8`, Ecto `~> 3.12` — minimum version targets; Ecto 3.13 adds `:writable` field option and `Repo.transact/2`

**Critical version note:** Hammer 7.x has a completely different API from 6.x. Do not use 6.x patterns. `wax_` (note underscore) is the correct package name, not `wax`.

### Expected Features

The MVP (v1.0) is defined by what makes Sigra genuinely useful for production SaaS immediately: the standard auth lifecycle plus social login and security baseline that phx.gen.auth explicitly lacks. The install story — `mix sigra.install` — is as important as any auth feature because adoption is blocked without it.

**Must have (v1.0 — table stakes):**
- Email/password registration with Argon2id hashing
- Login/logout with database-backed opaque sessions
- Email confirmation with single-use HMAC tokens (48hr TTL)
- Password reset via secure HMAC tokens (60min TTL)
- Remember-me persistent session (60-day, separate token context)
- `mix sigra.install` generator — schemas, context, routes, LiveViews, migrations
- Route protection plugs for HTTP pipeline and LiveView `on_mount`
- Social login via Assent (Google, GitHub minimum)
- Account lockout (temporary, self-releasing after 15min) + IP-based rate limiting
- Email enumeration prevention by default (identical responses for known/unknown email)
- Session invalidation on password change
- Telemetry events for all auth operations
- Testing helpers (ExUnit: `log_in_user/2`, `register_user/1`, etc.)

**Should have (v1.x — production-grade completeness):**
- TOTP full lifecycle: enrollment UI, QR code, backup codes (8 single-use, SHA-256 hashed), trust-this-browser, enforcement policies
- API bearer token authentication with prefix-format keys (`myapp_live_abc...`), scopes, expiration
- Active session tracking and revocation UI (IP + user agent + last active)
- Audit logging (structured security event log, queryable API)
- Sudo / re-authentication mode (`RequireSudo` plug, configurable window)
- Email change with dual-notification (verify new, notify old with cancel link)
- Magic link / passwordless email (15min TTL, rate-limited send)
- Password hash migration (bcrypt → Argon2id transparent upgrade on login)
- Personal access tokens (GitHub-style PATs with scopes)
- Suspicious login detection (new IP/device triggers email)
- JWT support (stateless API use cases only)

**Defer to v2+:**
- WebAuthn / passkeys (high value, high complexity; Wax integration needs ceremony design)
- Organizations / multi-tenancy with invitations (depends on stable identity layer)
- Enterprise SSO per org (depends on Organizations)
- SMS OTP (security concerns; NIST deprecated; ship with strong warnings only)
- Admin impersonation (provide building blocks; defer built-in to v2)
- OAuth2 server / acting as IdP (Boruta integration; separate concern)
- SCIM directory sync (enterprise niche; future plugin)

**Anti-features — explicitly exclude:**
- Macro-based schema injection (`use Sigra.Schema` field injection)
- Permanent account lockout (DoS vector)
- Built-in RBAC/authorization (separate concern; Sigra provides identity context only)
- SAML built-in (maintenance burden; architect for future plugin)

### Architecture Approach

Sigra follows a three-layer architecture: the library core (`Sigra.*` in the dep) contains all security-critical pure functions and process wrappers; the generated Phoenix context (`MyApp.Auth`) is the public API boundary that orchestrates library calls; and the web layer (controllers/LiveViews) never touches schemas or library functions directly. The generated `MyApp.Auth.Scope` struct carries progressive auth state (`:anonymous` → `:authenticated` → `:mfa_pending` → `:mfa_complete` → `:sudo`) through the request lifecycle on both `conn.assigns.current_scope` and `socket.assigns.current_scope`. This Rodauth-inspired approach with per-feature narrow tables (users, user_tokens, user_identities, mfa_credentials, api_keys, sessions, audit_log) provides clean schema evolution, clear ownership, and proven scalability.

**Major components:**
1. **`Sigra.Password`** — Argon2id hashing, bcrypt migration detection, constant-time comparison (library dep)
2. **`Sigra.Token`** — HMAC-protected token generation/verification, single-use enforcement (library dep)
3. **`Sigra.Session`** — Session lifecycle, idle/absolute timeouts, device tracking (library dep)
4. **`Sigra.OAuth`** — Assent integration, callback handling, provider normalization (library dep)
5. **`Sigra.MFA`** — TOTP via NimbleTOTP, backup codes, WebAuthn via Wax (library dep)
6. **`Sigra.RateLimit`** — Per-IP and per-account lockout via ETS/Hammer (library dep)
7. **`Sigra.Audit`** — Structured security event logging (library dep)
8. **`MyApp.Auth`** — Generated Phoenix context: public API, orchestrates library calls (developer owns)
9. **`MyApp.UserAuth`** — Generated plugs: `require_authenticated_user`, `fetch_current_scope_for_user`, `on_mount` hooks (developer owns)
10. **Ecto schemas + migrations** — Generated per-feature; explicit fields, no library injection (developer owns)

**Key patterns:**
- Behaviours + callbacks at every extensibility point (mailer, rate limiter, session store) — never macros
- Dual-mode auth plug: session cookie or Bearer token → same `current_scope` shape downstream
- `phx-trigger-action` for all session-mutating flows (login, logout, MFA verify) — never via LiveView events
- Explicit dependency injection: `repo`, `mailer` passed as arguments, not read from `Application.get_env`
- Index `user_tokens` on `(token_hash, context)` with partial indexes; Oban job for expired token cleanup

### Critical Pitfalls

1. **Macro-driven schema hiding (The Pow Trap)** — Avoid any `use Sigra.Schema` that injects fields. Generate real, readable Ecto schemas into the developer's project. Every field must be visible in their own files. This is a Phase 1 foundation decision; retrofitting requires a major version break.

2. **Pure generator with no security patch path (The phx.gen.auth Trap)** — All cryptographic operations (HMAC, hash, token generation, TOTP verify, WebAuthn ceremony) must live in library modules, never in generated files. Generated code calls library functions. A changelog entry that says "update your generated files to fix X" is a failure mode. This boundary is the entire reason Sigra exists.

3. **JWT for browser sessions (The Guardian Trap)** — Opaque database-backed tokens for all sessions. JWTs are appropriate only for stateless API use cases where instant revocation is not required. Database-backed tokens enable instant invalidation, "log out everywhere" as a single `DELETE`, and password change that truly ends all active sessions.

4. **Database adapter abstraction (The Lucia Trap)** — Ecto is the only supported data layer. Lucia's maintainer explicitly cited adapter complexity as the primary reason for deprecation. Ecto is already the adapter abstraction; adding a Sigra-level adapter on top creates fragility and constrains the API.

5. **MFA as a bolted-on function (The NimbleTOTP Trap)** — TOTP is a complete login state machine, not a function call. The `mfa_pending` session state must block route access, not just redirect. Rate limit MFA code attempts independently. Backup codes must be hashed (SHA-256), single-use, and consumed atomically. The TOTP window must be ±1 step maximum (the AuthQuake vulnerability used a wide window for 3% brute-force success per attempt).

6. **Email enumeration via inconsistent responses** — All email-accepting endpoints must return identical responses for known and unknown email addresses. This must be on by default, not opt-in. Includes dummy hash computation on login for nonexistent users to prevent timing-based enumeration.

7. **OAuth auto-linking without confirmation** — When an OAuth callback matches an existing email-based account, require explicit user confirmation before linking. Auto-linking is an account takeover vector. Default to confirmation-required; make auto-link an explicit opt-in.

---

## Implications for Roadmap

Based on research, the component dependency graph and pitfall-to-phase mappings suggest a 6-phase structure:

### Phase 1: Foundation and Core Auth

**Rationale:** Every other feature depends on the library/generated boundary, schema design, session architecture, and config surface. These decisions cannot be changed without breaking user code. All four critical pitfalls (macro hiding, pure generator, JWT sessions, adapter abstraction) are Phase 1 concerns that must be addressed before writing a single feature.

**Delivers:**
- Hybrid lib+generator architecture with clear boundary established
- Data layer: User, UserToken schemas + migrations
- `Sigra.Password` and `Sigra.Token` modules (pure functions, highest test ROI)
- `Sigra.Session` module (opaque database-backed tokens)
- `MyApp.Auth` context generation pattern
- `MyApp.UserAuth` plug + `on_mount` hook generation
- `MyApp.Auth.Scope` struct with progressive auth states
- Single flat config module validated at startup
- Email/password registration + login + logout
- Email enumeration prevention by default
- Session invalidation on password change
- Telemetry events skeleton
- `mix sigra.install` generator (foundation; feature flags added per phase)

**Avoids:** Macro schema hiding, JWT sessions, database adapter abstraction, config sprawl, LiveView session mutation

**Research flag:** Standard Phoenix patterns — well-documented. No additional research needed beyond what is in ARCHITECTURE.md.

---

### Phase 2: Email Flows and Security Baseline

**Rationale:** Email confirmation and password reset complete the core auth lifecycle. Account lockout and rate limiting are the security baseline that phx.gen.auth lacks — they are listed as P1 must-haves and are required before social login (which creates additional registration paths that need the same protections).

**Delivers:**
- Email confirmation with single-use HMAC tokens (48hr TTL)
- Password reset with secure HMAC tokens (60min TTL, invalidates all sessions)
- Remember-me persistent session (separate token context, 60-day TTL)
- Account lockout: temporary, self-releasing after 15min, never permanent
- IP-based rate limiting via Hammer with ETS backend
- Resend rate limiting on confirmation emails
- Mailer behaviour + Swoosh default templates (confirmation, password reset)
- Testing helpers for all flows (`log_in_user/2`, `register_user/1`)

**Avoids:** Permanent lockout as DoS vector, enumeration via timing differences, synchronous email delivery blocking requests

**Research flag:** Standard patterns — well-documented. Pitfalls research is the key resource for correctness details (single-use enforcement, HMAC token security).

---

### Phase 3: Social Login and OAuth

**Rationale:** Social login is the #1 community pain point for Elixir SaaS developers and the most immediate differentiator from phx.gen.auth. It depends on the core user and session infrastructure from Phases 1-2. Account linking logic is the hardest part and must be designed explicitly before implementation.

**Delivers:**
- Assent integration: `Sigra.OAuth` module
- Google and GitHub providers (minimum); extensible to all Assent-supported providers
- `user_identities` schema + migration
- Three-case account linking: new user, existing user (email match requiring confirmation), existing user (already has provider)
- OAuth state parameter CSRF validation on callbacks
- Multiple OAuth providers per user (link/unlink from settings)
- Provider access/refresh token encryption via cloak_ecto
- Account linking confirmation flow (email to existing address)

**Avoids:** OAuth auto-linking account takeover vulnerability, trusting provider email claims unconditionally, missing CSRF state validation

**Research flag:** OAuth account linking edge cases (no email from provider, duplicate accounts) warrant careful design review. PITFALLS.md section 7 and the Doyensec/RFC 9700 sources are required reading before implementation.

---

### Phase 4: MFA — TOTP Full Lifecycle

**Rationale:** TOTP is the #2 community pain point and a B2B enterprise requirement. It depends on session state from Phase 1 (for `mfa_pending` state propagation) and email flows from Phase 2 (for backup code recovery via email). The session state machine must be fully modeled before any MFA code is written — this is the most common MFA implementation failure.

**Delivers:**
- `Sigra.MFA.TOTP` module (NimbleTOTP wrapper)
- `mfa_credentials` schema + migration (TOTP secret encrypted via cloak_ecto)
- Complete enrollment state machine: generate secret → show QR code → user confirms with valid code → enable
- Backup codes: 8 single-use codes, SHA-256 hashed, atomically consumed
- MFA enforcement policies: optional, required-for-role, org-level (org-level deferred to v2 orgs feature)
- Rate limiting on MFA verify endpoint (independent from login rate limiting)
- "Trust this browser" encrypted cookie (14-day default, user-specific HMAC)
- Recovery via backup code path
- `mfa_pending` → `mfa_complete` session state transition enforced in plugs

**Avoids:** NimbleTOTP bolted-on-function trap, wide TOTP window (AuthQuake), plaintext backup codes, unrate-limited MFA verify endpoint, enrollment without confirmation code verification

**Research flag:** The `mfa_pending` session state machine and the trust-this-browser cookie security design benefit from an explicit design review before coding. Patterns are documented in ARCHITECTURE.md and PITFALLS.md but the session state machine is complex enough to warrant drawing it out.

---

### Phase 5: API Authentication

**Rationale:** API bearer token authentication is required for Persona C (API builders) and unlocks a significant user segment that currently has no good integrated option in the Elixir ecosystem. It depends on the existing session and token infrastructure from Phase 1 (same `user_tokens` table with different `context` values). The dual-mode auth plug requires careful design to ensure session invalidation (password change, revoke-all) works uniformly for both auth paths.

**Delivers:**
- `Sigra.Plug.DualModeAuth`: detects Bearer header vs. session cookie; both paths produce same `current_scope` shape
- API key schema + migration: `key_hash`, `key_prefix` (e.g., `sigra_sk_`), `scopes`, `expires_at`, `revoked_at`, `last_used_at`
- API key issuance: raw key shown exactly once; hash stored; never retrievable again
- Personal access tokens (GitHub-style PATs with scopes)
- Bearer token endpoint for token-based issuance
- Revoke all sessions (password change) covers both session tokens and API keys
- JWT support as lightweight add-on (stateless API use cases only)
- Headless mode: all logic works without LiveView/HTML components

**Avoids:** Session-and-API as separate code paths with diverging security properties, API key prefix collision (32+ byte cryptographic suffix), showing API key more than once

**Research flag:** Standard patterns. ARCHITECTURE.md dual-mode auth section and bearer token flow diagram are sufficient. No additional research needed.

---

### Phase 6: Advanced Security Features

**Rationale:** These features complete the "production-grade" story for compliance buyers and security-conscious users. They are all additive (no schema changes to earlier tables) and depend on the full auth lifecycle being stable. Audit logging is cross-cutting and designed to be added per-feature as each one stabilizes.

**Delivers:**
- Active session tracking UI: per-session IP, user agent, last active; LiveView revocation interface
- Audit logging: `audit_log` table (user_id, action, IP, user agent, metadata JSONB); queryable API; async Oban writes
- Sudo / re-authentication mode: `RequireSudo` plug, configurable window, triggered on sensitive operations
- Email change with dual-notification: confirm new address, notify old address with cancel link
- Magic link / passwordless email: single-use HMAC token, 15min TTL, rate-limited send
- Password hash migration: transparent bcrypt → Argon2id upgrade on successful login
- Suspicious login detection: new IP/device triggers email notification
- Oban-backed async email delivery for all email flows (inline fallback if Oban not present)

**Avoids:** Audit log blocking auth performance (async writes), session tracking N+1 queries, email change that only notifies new address

**Research flag:** Oban integration for async email and audit log writes is well-documented. The `cloak_ecto` key rotation pattern for TOTP secrets should be verified against the cloak_ecto 1.3.0 API before implementation.

---

### Phase Ordering Rationale

- Phases 1-2 are non-negotiable prerequisites: the library/generated boundary, session architecture, and core token security cannot be retrofit without breaking changes
- Phase 3 (OAuth) before Phase 4 (MFA) because OAuth creates new registration paths that must be protected by the rate limiting and lockout from Phase 2, but OAuth does not depend on MFA
- Phase 4 (MFA) before Phase 5 (API) because the session state machine (`mfa_pending`, `mfa_complete`) must be complete before API tokens are added to the same session infrastructure; retrofitting MFA states after API auth exists is higher risk
- Phase 5 (API Auth) before Phase 6 (Advanced Security) because the dual-mode plug and revoke-all semantics must be in place before audit logging captures revocation events
- Phase 6 features are all additive and independent of each other; they can be shipped incrementally within the phase

### Research Flags

**Phases needing deeper pre-implementation design review:**
- **Phase 4 (MFA):** The session state machine for `mfa_pending` → `mfa_complete` and the trust-this-browser cookie security design are complex enough to warrant drawing out the state machine before coding. PITFALLS.md section 5 and ARCHITECTURE.md pattern 4 are the key references.
- **Phase 3 (OAuth):** The account linking confirmation flow has security implications documented in PITFALLS.md section 7. The three account-linking cases should be explicitly designed (with tests for each case) before implementation begins.

**Phases with standard, well-documented patterns (no additional research needed):**
- **Phase 1 (Foundation):** Phoenix 1.8 context patterns, phx.gen.auth architecture, and Rodauth-inspired design are all thoroughly documented in ARCHITECTURE.md.
- **Phase 2 (Email Flows):** Token generation, HMAC security, and Swoosh mailer patterns are well-understood. PITFALLS.md "Looks Done But Isn't" checklist is the key reference for correctness.
- **Phase 5 (API Auth):** Dual-mode auth plug pattern is documented in ARCHITECTURE.md. Bearer token flows are straightforward.
- **Phase 6 (Advanced Security):** Individual features are well-documented. Oban async patterns are standard.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified against hex.pm as of 2026-04-04. Alternatives explicitly evaluated. No speculative choices. |
| Features | HIGH | Based on cross-ecosystem analysis (Rodauth, Better Auth, Django Allauth, Devise), State of Elixir surveys 2023–2025, and direct community feedback. MVP scope is well-justified. |
| Architecture | HIGH | Grounded in Phoenix 1.8 official docs, phx.gen.auth source, Rodauth design documentation, and Elixir/Phoenix best practice research. Patterns are proven in production. |
| Pitfalls | HIGH | Every pitfall is grounded in a real prior-art failure (Pow, phx.gen.auth, Guardian, Lucia) or security documentation (OWASP, NIST, RFC 9700, AuthQuake post-mortem). |

**Overall confidence:** HIGH

### Gaps to Address

- **cloak_ecto key rotation API:** Research confirmed cloak_ecto 1.3.0 is the right choice for field encryption, but the specific key rotation workflow should be verified against current cloak_ecto docs during Phase 4 implementation, since the library is slow-moving and the 1.3.0 API may differ from older documentation.

- **nimble_totp copy-paste decision:** STACK.md notes that given NimbleTOTP's tiny surface area (4 functions) and stable-since-2023 status, it may be worth copying into the library to eliminate the transitive dependency. This is a minor dependency management decision to make at Phase 4 start.

- **Multi-database migration generation:** STACK.md recommends conditional migration generation for MySQL/SQLite (detecting adapter in the generator). The specific DDL differences (e.g., `citext` is PostgreSQL-only) should be mapped out before the generator is built in Phase 1.

- **WebAuthn / Phase 7 scope:** Wax (WebAuthn) is deferred to v2, but the `passkey_credentials` table schema and the JavaScript ceremony module interface should be at least sketched during Phase 4 (MFA) so the data model doesn't need breaking changes when passkeys are added.

---

## Sources

### Primary (HIGH confidence)

- `hex.pm` — all library versions verified (argon2_elixir 4.1.3, assent 0.3.1, nimble_totp 1.0.0, wax_ 0.7.0, swoosh 1.25.0, hammer 7.3.0, oban 2.21.1, cloak_ecto 1.3.0, nimble_options 1.1.1, ex_doc 0.40.1, phoenix 1.8.5, ecto 3.13.5)
- `hexdocs.pm/phoenix` — Phoenix 1.8 auth patterns, Scope struct, `phx.gen.auth` architecture, LiveView security model
- `hexdocs.pm/phoenix_live_view` — security model, `on_mount` patterns, `phx-trigger-action` pattern
- Rodauth README and design documentation — per-feature tables, encapsulated auth object, HMAC tokens
- OWASP Authentication Cheat Sheet — security baseline requirements
- NIST SP 800-63B — password policy guidance (no composition rules, length requirements)
- RFC 9700 — OAuth 2.0 security best current practice
- AuthQuake research (WorkOS) — TOTP window vulnerability
- Lucia deprecation discussion — adapter abstraction as primary failure mode
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — comprehensive ecosystem analysis
- `prompts/elixir-best-practices-deep-research.md` — library architecture patterns
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — OSS library best practices
- `prompts/ecto-best-practices-deep-research.md` — Ecto auth patterns
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — CI/CD stack
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — persona and priority framework
- `prompts/Auth Domain Language — A Field Guide.md` — domain vocabulary

### Secondary (MEDIUM confidence)

- Better Auth plugin architecture (deepwiki.com) — composable plugin design patterns
- Django Allauth documentation — account linking with confirmation, email notification patterns
- Devise modules and source — macro injection anti-pattern illustration
- State of Elixir surveys 2023–2025 — community pain points and feature gaps

### Tertiary (LOW confidence / needs validation at implementation)

- cloak_ecto 1.3.0 key rotation API — stable but slow-moving; verify against current docs at Phase 4
- nimble_totp copy-paste feasibility — minor decision; verify the 4-function surface area is still accurate

---

*Research completed: 2026-04-04*
*Ready for roadmap: yes*
