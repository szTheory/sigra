# Sigra

## What This Is

Sigra is a comprehensive authentication library for Elixir/Phoenix that fills the critical gap left by Pow's incompatibility with Phoenix 1.8+. It uses a hybrid lib+generator architecture: security-critical code lives in the library (updated via `mix deps.update`), while customizable application code (schemas, routes, LiveViews) is generated into the developer's project. Sigra targets Phoenix/Ecto as the blessed path, with Plug compatibility where it doesn't compromise DX.

## Core Value

Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

## Current Milestone

The next shipped increment after v1.2 is **not defined in `.planning/` yet**. Run `/gsd-new-milestone` to capture product intent, a fresh `.planning/REQUIREMENTS.md`, and phased roadmap work.

## Current State

**Shipped:** **v1.2 Admin Dashboard** (2026-04-17) — Phases 27-35 (27-31 core; 32-35 closed generated-installer integration gaps INT-01..05, added generated-host Playwright and smoke, retroactive `28-VERIFICATION.md`, and shift-left CI gates). Archives: `.planning/milestones/v1.2-ROADMAP.md`, `v1.2-REQUIREMENTS.md`, `v1.2-MILESTONE-AUDIT.md`.

**Previously shipped:** v1.1 Foundations (2026-04-16); v1.0 Phoenix Auth Library (2026-04-11).

Sigra is a Phoenix 1.8+ authentication platform spanning the v1.0 auth stack, v1.1 organizations and passkeys, and v1.2 admin: default-on admin installer feature, explicit host policy for platform vs org admins, scope-safe admin routes and LiveViews, searchable user operations, time-bounded impersonation with dual-actor audit and forbidden sensitive mutations during impersonation, global/org/user audit exploration with CSV export, Playwright plus direct-path smoke and CI artifacts (including mobile and dark checkpoints), and generator emission parity so `mix sigra.install` hosts match the example application for admin surfaces.

**Verification:** v1.2 milestone audit **passed** (2026-04-17); v1.2 requirements archive **23/23** satisfied; v1.1 remains **79/79** in its archive.

**Known limitations carried forward (tracked, non-blocking):**
- 8 human-only UAT items — `SEED-001` (before broader GA announcement).
- Phase 9 audit `log_safe/3` hybrid vs full `Ecto.Multi` atomicity — `SEED-002` / C-1 caveat.
- Backlog phases **999.1** (Nyquist retro validation) and **999.2** (Dependabot major bumps on SHA-pinned Actions).
- **TOOL-01** — Deprecated reliance on JSON audit helpers from external planning toolchains; **supported path:** [`MAINTAINING.md`](../MAINTAINING.md) (see **Planning hygiene (without gsd-tools JSON)**) and optional [`scripts/maintainers/planning-audit-hygiene.sh`](../scripts/maintainers/planning-audit-hygiene.sh) (Phase 40).

## Next Milestone Goals

Unset until `/gsd-new-milestone`. Likely themes: GA hardening (SEED-001), audit atomicity follow-up (SEED-002), Nyquist/Dependabot backlog, or a new product slice with its own requirements.

<details>
<summary>Archived v1.2 milestone framing (Admin Dashboard)</summary>

**Goal:** Ship a default-on admin surface that feels excellent to use: mobile-responsive LiveView user management, secure impersonation, and rich audit exploration on top of the v1.1 organizations and passkeys foundation.

**Target features (shipped in v1.2):**
- Admin user-management UI in LiveView, default on with `--no-admin` opt-out, mobile-friendly, light/dark, and basic branding hooks
- Admin impersonation with strict guardrails, visible session state, dual-actor audit trail, and blocked sensitive mutations while impersonating
- Expanded audit views across user, organization, and global admin workflows with scope-respecting CSV export
- Automation-first verification: Playwright, screenshots/video where useful, HTML reports, browser and curl-style smoke, CI jobs including generated-host parity and shift-left gates (Phases 31-35)

</details>

<details>
<summary>Archived v1.1 milestone framing</summary>

**Goal:** Ship the architectural foundation that unlocks v1.2's admin dashboard — logical multi-tenancy (organizations + memberships, single DB, no PG schema-per-tenant) and passkey/WebAuthn authentication. No admin UI in this milestone; only the user-facing surface each feature needs to be usable end-to-end.

**Target features:**
- Organizations (logical multi-tenancy, default-on with `--no-organizations` opt-out): `Organization` / `OrganizationMembership` / `OrganizationInvitation` schemas, `Sigra.Organizations` context, `Sigra.Plug.RequireMembership`, Scope struct extension (`:active_organization`, `:membership`), sessions `active_organization_id` column, automatic `organization_id` in audit metadata, HMAC-protected invite flow with email acceptance, `OrganizationSwitcherLive` / `OrganizationSettingsLive` / `OrganizationMembersLive` / `InvitationAcceptLive`, generator conditional template pattern (first in codebase, load-bearing for v1.2 `--no-admin`)
- Passkeys (WebAuthn via `wax_`, default-on with `--no-passkeys` opt-out): `UserPasskey` schema with `cloak_ecto`-encrypted public keys, `Sigra.Passkeys` / `Sigra.Passkeys.Registration` / `Sigra.Passkeys.Authentication` contexts, `Sigra.Plug.PasskeyChallenge`, passkey-as-2FA AND passkey-as-primary modes, `PasskeyEnrollmentLive` / `PasskeyAuthenticationLive`, `MfaSettingsLive` updates to list passkeys alongside TOTP, runtime RP ID / origin config, JS hooks for credential ceremonies

**Deferred to v1.2 "Admin Dashboard"** (full direction captured in `.planning/v1.2-DIRECTION.md`): admin user-management LiveView UI (Django-admin-loved, mobile-first, light+dark mode, basic branding, default-on opt-out), admin impersonation (time-limited, audited, sudo-gated, locked-down sensitive ops, org-scoped for org admins), expanded audit views (per-user, per-org, global, impersonation feed, CSV export).

</details>

## Requirements

### Validated — v1.0

**Core authentication:**
- ✓ `mix sigra.install` generator (migrations, schemas, context, routes, optional LiveView pages) — v1.0
- ✓ Phoenix context pattern (`MyApp.Auth`) — v1.0
- ✓ Headless mode (all logic works without UI) — v1.0
- ✓ Behaviour + callback architecture for extensibility (no hidden macros) — v1.0
- ✓ Smart defaults with easy overrides via NimbleOptions — v1.0
- ✓ Email/password registration with Argon2id hashing — v1.0
- ✓ Magic link / passwordless email authentication — v1.0
- ✓ Login / logout with server-side database-backed sessions — v1.0
- ✓ Password hash migration (bcrypt → Argon2id transparent upgrade on login) — v1.0
- ✓ Email confirmation (link + 6-digit code verification) — v1.0
- ✓ Password reset via HMAC-protected single-use time-limited email tokens — v1.0
- ✓ Remember-me persistent sessions — v1.0
- ✓ Sudo/re-authentication mode for sensitive operations — v1.0

**OAuth / Social login:**
- ✓ OAuth integration via Assent (Google, GitHub, Apple, Facebook, Generic) — v1.0
- ✓ Account linking (existing user adds OAuth provider, email-match handling) — v1.0
- ✓ Multiple OAuth providers per user — v1.0
- ✓ PKCE and OIDC support via Assent — v1.0

**MFA:**
- ✓ TOTP enrollment, verification, and recovery (full lifecycle) — v1.0
- ✓ Backup codes (SHA-256 hashed, single-use, regeneration) — v1.0
- ✓ "Trust this browser" cookie to skip MFA on trusted devices — v1.0
- ✓ MFA enforcement policies via plug — v1.0

**Session management:**
- ✓ Active session tracking (IP, user agent, last active, device) — v1.0
- ✓ Session revocation (individual and log-out-everywhere) — v1.0
- ✓ Session invalidation on password change — v1.0
- ✓ Idle and absolute timeout (configurable) — v1.0
- ✓ Secure cookie defaults (SameSite=Lax, HttpOnly, Secure) — v1.0
- ✓ Account lockout after N failed attempts — v1.0
- ✓ Email enumeration prevention — v1.0

**API authentication:**
- ✓ Bearer token authentication with human-readable prefix (`myapp_sk_*`) — v1.0
- ✓ Personal access tokens (user-scoped, scopes + expiration) — v1.0
- ✓ JWT support for stateless API use cases (opt-in, family-based refresh rotation) — v1.0
- ✓ Dual-mode auth plug (session for browser, bearer for API, identical `current_scope`) — v1.0

**Security:**
- ✓ IP-based and account-based rate limiting via Hammer 7.x — v1.0
- ✓ HMAC-protected tokens for all email flows — v1.0
- ✓ Suspicious login detection with email notification — v1.0

**Transactional email:**
- ✓ Confirmation, password reset, lockout, suspicious-login, MFA, account lifecycle emails — v1.0
- ✓ Swoosh integration with pluggable mailer — v1.0
- ✓ HTML + text multipart with inline CSS — v1.0
- ✓ Async delivery via Oban with inline fallback — v1.0

**Account lifecycle:**
- ✓ Email change with re-verification — v1.0
- ✓ Password change with current password verification — v1.0
- ✓ Account deletion (soft, hard, anonymize) with grace period — v1.0
- ✓ Profile hooks engine with Ecto.Multi abort support — v1.0

**Developer experience:**
- ✓ Testing helpers (`log_in_user/2`, `register_user/1`, `setup_totp/1`, `create_api_key/2`, browser trust helpers) — v1.0
- ✓ Telemetry events for all auth operations (24+ events across phases) — v1.0
- ✓ Audit logging (security events with user, IP, user agent, action, metadata) — v1.0 (with C-1 caveat)
- ✓ `getting-started.md` guide + 15 additional guides + `llms.txt` — v1.0

### Validated — v1.2 Admin Dashboard

**Admin user management UI:**
- ✓ LiveView admin dashboard enabled by default with `--no-admin` opt-out — v1.2
- ✓ Mobile-responsive user list and user detail flows for core operator jobs — v1.2
- ✓ Light/dark mode plus basic branding controls suitable for internal tooling — v1.2
- ✓ Org-aware admin scopes so platform admins and org admins see the right surface by construction — v1.2

**Impersonation + audit:**
- ✓ Secure admin impersonation with visible banner state, time bounds, dual-actor audit trail, and forbidden sensitive actions — v1.2
- ✓ Rich audit views for per-user, per-organization, and global exploration, including impersonation-aware filtering — v1.2 (Phase 30; polish Phase 33)
- ✓ Admin-side user detail views for sessions, security state, identities, organizations, memberships, and danger-zone actions — v1.2

**Verification + review ergonomics:**
- ✓ Browser and system automation for critical admin flows using Playwright and CI — v1.2 (Phases 31, 34-35)
- ✓ Review artifacts (Playwright HTML, screenshots/traces/video where configured, curated PNG baselines) — v1.2
- ✓ Route, controller, and curl-style smoke coverage outside the browser happy path — v1.2

### Active — next milestone

Requirements for the next shipped increment are intentionally absent until `/gsd-new-milestone` recreates `.planning/REQUIREMENTS.md`.

### Other deferred items

- [ ] SEED-001: 8 human-only UAT items before v1.0 GA public announcement
- [ ] SEED-002: Phase 9 `log_safe/3` → atomic `Ecto.Multi` conversion (trigger-conditioned)
- [ ] 999.1 backlog: Nyquist retroactive validation pass
- [ ] 999.2 backlog: Dependabot major-version bumps

### Out of Scope

- SAML support — enterprise SSO protocol, high maintenance burden, low SaaS builder need. Leave architecture extensible for future plugin.
- Acting as OAuth/OIDC identity provider — enterprise/B2B concern, dramatically expands scope. Architecture should not prevent future addition.
- Rebuilding organizations or passkeys as standalone milestones — v1.1 shipped the foundation; v1.2 builds on top of it.
- Authorization (RBAC, permissions, policies) — separate concern. Sigra provides identity context; authorization builds on top.
- SCIM directory sync — enterprise feature, out of scope for v1.
- Full theming engine or runtime UI builder — only basic branding hooks are in scope for the admin surface.

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
| Hybrid lib+generator architecture | Security patches propagate via dep updates; devs own customizable code. Respects José's philosophy while solving the patch propagation problem. | ✓ Validated v1.0 — no regret |
| Phoenix context pattern for generated code | `MyApp.Auth` context follows DDD boundaries, is idiomatic Phoenix, and keeps the public API clean. | ✓ Validated v1.0 — no regret |
| Assent over Ueberauth for OAuth | Framework-agnostic, PKCE/OIDC built-in, single package vs N strategy deps, actively maintained. | ✓ Validated v1.0 — shipped 5 strategy wrappers (Google/GitHub/Apple/Facebook/Generic); Assent's PKCE + OIDC + single-package design paid off |
| Hybrid user/identity table pattern | `users` + `user_identities` — clean multi-provider support, natural Ecto idiom, matches Better Auth/Django Allauth/PowAssent. | ✓ Validated v1.0 — pattern held through registration/login/linking/unlink |
| Argon2id default with bcrypt migration path | OWASP gold standard; memory-hard; transparent upgrade on login keeps migration invisible to users. | ✓ Validated v1.0 — `verify_with_upgrade/3` pattern works cleanly |
| Database-backed session tokens (no JWT for browser) | Revocation requires server-side state; JWT-only for browser is an anti-pattern for session auth. | ✓ Validated v1.0 — JWT remains opt-in for stateless API paths only |
| D-01 universal atomic `Ecto.Multi` for audit writes | Audit rows must be as durable as the business op that produced them; no dropped rows on partial failure. | ⚠️ Revisit — phase 9 shipped as hybrid (3 atomic sites + `log_safe/3` elsewhere), tracked as SEED-002 for conversion when subsystem tests go audit-aware |
| D-10 installer default PK type = `binary_id` (uuid) | UUIDs are idiomatic for modern Phoenix; avoids enumeration of integer IDs; matches phx.gen.auth 1.8 convention. | ✓ Validated v1.0 (flipped in phase 10.1.1) — no integer-PK regressions downstream |
| IN-03 SHA-pin all GitHub Actions | Supply-chain security: tag-based references allow the tag to be moved post-publish; SHA pins lock the exact code. | ✓ Validated v1.0 (phase 10.1 + 10.1.1) — Dependabot `github-actions` ecosystem handles upgrade churn |
| D-15 no `continue-on-error` on any required CI check | Flakes must be fixed at root cause; masking them defeats the gate's purpose. | ✓ Validated v1.0 — all 5 CI jobs are strict-pass; no `continue-on-error` anywhere in `.github/workflows/ci.yml` |
| Playwright over Cypress/WebdriverIO for browser smoke | Only runner with first-class frameLocator support for Swoosh dev-mailbox iframe; lowest-friction TypeScript setup. | ✓ Validated v1.0 (phase 10.1.1) — golden-path spec runs in ~90s on CI, zero flakes to date |
| Organizations as first-class multi-tenancy | Logical tenants without schema-per-tenant; scope + membership + invitations. | ✓ Shipped v1.1 — org switcher, plugs, audit columns; superseded the old “defer to v2” note |
| SAML / OAuth IdP out of scope | Enterprise concern with high maintenance burden. Architecture should not prevent future plugin/extension. | — Pending (still out of scope) |
| WebAuthn / passkeys deferred from v1.0 MFA | TOTP covers the broader developer use case; WebAuthn adds meaningful complexity; `wax_` dep was evaluated but not integrated. | ✓ Shipped v1.1 — passkeys + orgs foundations |
| v1.2 admin is default-on installer feature with library-owned enforcement | Keeps security semantics in the dep while host owns policy module + shell chrome; matches hybrid architecture. | ✓ Validated v1.2 — plugs, `Sigra.Admin.*`, generator parity phases 32-33 |
| Shift-left gates for installer + verification docs | Prevents INT-01..04 recurrence: emission audit, drift dead-text nav guard, milestone VERIFICATION.md gate, installer-scoped milestone audit CI, artifact bundle contract. | ✓ Validated v1.2 — Phase 35 |

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
*Last updated: 2026-04-17 after v1.2 milestone completion — Admin Dashboard shipped as Phases 27-35. Planning artifacts archived to `.planning/milestones/v1.2-*`; live `.planning/REQUIREMENTS.md` removed for the next milestone. Use `/gsd-new-milestone` to define v1.3+ scope.*

*Last updated: 2026-04-11 — started v1.1 Foundations milestone. Scope: Organizations (logical multi-tenancy) + Passkeys (WebAuthn). No admin UI. v1.2 Admin Dashboard direction fully earmarked in `.planning/v1.2-DIRECTION.md`.*

*Last updated: 2026-04-11 after v1.0 milestone completion — Sigra v1.0 Phoenix Auth Library: 12 phases, 60 plans, 117 tasks. All 85 requirements validated. 1249 tests + 33 doctests + 3 properties, 0 failures. 5 required CI checks on main (library_tests + example_unit_smoke + install_smoke + example_http_smoke + example_playwright_smoke). 2 seeds planted for GA gating (SEED-001) and audit atomicity followup (SEED-002). 2 backlog items parked (999.1 Nyquist retro, 999.2 Dependabot major bumps). Tagged v1.0.*

*Last updated: 2026-04-09 after Phase 8 completion — Account lifecycle: email change (request/confirm/cancel with token security), password change (with current password verification and configurable session invalidation), account deletion (soft_delete/hard_delete/anonymize with grace period via Oban worker), hooks engine (Ecto.Multi integration for profile update callbacks), DataExport behaviour, RequirePasswordChange plug, 24 telemetry events, 7 email templates, Settings LiveView, reactivation page, generator injector wiring, and 10 testing helpers. Human UAT pending for visual verification.*
