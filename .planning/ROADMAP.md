# Roadmap: Sigra

## Overview

Sigra is built in ten focused phases, each delivering a coherent, verifiable capability. The sequence is dependency-driven: the hybrid lib+generator architecture and core session infrastructure must exist before any feature can be built on top of them. Email flows, OAuth, MFA, and API auth each stand on the foundation below them. Account lifecycle, audit logging, and developer experience complete the production-grade story. Every phase ends with observable user behaviors that can be verified against a running application.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Establish hybrid lib+generator architecture, data layer, config, telemetry skeleton, and install generator scaffold (completed 2026-04-05)
- [x] **Phase 2: Core Auth** - Email/password registration, login, logout, Argon2id hashing, and password policies (completed 2026-04-06)
- [x] **Phase 3: Email Flows and Transactional Email** - Email confirmation, password reset, mailer behaviour, Swoosh templates, and Oban async delivery (completed 2026-04-07)
- [x] **Phase 4: Session Management and Security Baseline** - Database-backed sessions, remember-me, revocation, timeouts, lockout, rate limiting, and suspicious login (completed 2026-04-08)
- [x] **Phase 5: OAuth and Social Login** - Assent integration, tier 1-2 providers, account linking, user_identities, and OAuth token storage (completed 2026-04-08)
- [x] **Phase 6: Multi-Factor Authentication** - TOTP full lifecycle, backup codes, trust-this-browser, MFA enforcement, and rate limiting (completed 2026-04-08)
- [x] **Phase 7: API Authentication** - Bearer tokens, personal access tokens, JWT, dual-mode plug, and headless mode (completed 2026-04-09)
- [x] **Phase 8: Account Lifecycle** - Email change, password change, account deletion, profile hooks, and sudo/re-authentication (completed 2026-04-08)
- [x] **Phase 9: Audit Logging** - Security event table, event capture for all auth operations, queryable API, and custom hooks (completed 2026-04-09)
- [x] **Phase 10: Developer Experience** - Testing helpers, scenario fixtures, cookie config, and documentation (completed 2026-04-10)
- [x] **Phase 10.1: Installer and Library Fixes** - Remediation: AR-10-01/02 plain-map insert DoS fixes, 16 installer template backports, docs gate, supply-chain SHA-pinning, Env helper, pre-existing test fixes (completed 2026-04-10)

## Phase Details

### Phase 1: Foundation
**Goal**: The hybrid lib+generator boundary is established, generated code is plain Ecto schemas calling library functions, and a developer can run `mix sigra.install` to get a working project scaffold
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, FOUND-08, FOUND-09, FOUND-10
**Success Criteria** (what must be TRUE):
  1. Running `mix sigra.install` generates migrations, schemas, context module, plugs, and optional LiveView pages into the developer's project
  2. Generated schemas are plain Ecto schemas with no `use Sigra.Schema` field injection — every field is visible in the developer's own files
  3. Security-critical functions (hashing, token generation, HMAC verification) live in library modules; generated code calls into them
  4. Configuration compiles without error using only smart defaults; every option has a documented override
  5. Telemetry events are emitted for operations as stubs that will be filled in by later phases; `Sigra.Telemetry` module exists
**Plans:** 3 plans
Plans:
- [x] 01-01-PLAN.md — Core library modules (config, crypto, token, behaviours, error handling)
- [x] 01-02-PLAN.md — Telemetry and library plugs (event catalog, HTTP middleware)
- [x] 01-03-PLAN.md — Generator (EEx templates, mix sigra.install task, injector)

### Phase 2: Core Auth
**Goal**: A developer's users can register with email/password, log in, and log out, with passwords hashed using Argon2id and enumeration prevention on by default
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07
**Success Criteria** (what must be TRUE):
  1. User can register with an email and password; password is stored as Argon2id hash, never plaintext
  2. User can log in with correct email/password and receives a session
  3. User can log out from any page and the session is invalidated
  4. A user migrating from bcrypt transparently receives an Argon2id hash on their next successful login
  5. User can request a magic link and authenticate via the emailed link without a password
**Plans:** 2 plans
Plans:
- [x] 02-01-PLAN.md — Library modules (email normalization, password policy, bcrypt hasher, crypto upgrade detection)
- [x] 02-02-PLAN.md — Auth orchestrator and generator templates (Sigra.Auth, dual-mode login, registration, controller templates)

### Phase 3: Email Flows and Transactional Email
**Goal**: All email-based auth flows work end to end — confirmation, password reset, and transactional delivery — with HMAC-protected single-use tokens, async delivery, and customizable templates
**Depends on**: Phase 2
**Requirements**: CONF-01, CONF-02, CONF-03, CONF-04, CONF-05, CONF-06, RESET-01, RESET-02, RESET-03, RESET-04, RESET-05, EMAIL-01, EMAIL-02, EMAIL-03, EMAIL-04, EMAIL-05
**Success Criteria** (what must be TRUE):
  1. New registrations automatically receive a confirmation email; user can confirm via link click or 6-digit code
  2. Unconfirmed users experience configurable behavior (login allowed with banner, or login blocked) — both modes work
  3. User can reset their password via email; the reset link expires after 60 minutes and works only once; using it invalidates all other sessions
  4. All email flows return identical responses for known and unknown email addresses, preventing enumeration
  5. Emails are delivered asynchronously via Oban when present, falling back to inline delivery; HTML + text multipart templates are generated into the project for customization
**Plans:** 6 plans
Plans:
- [x] 03-01-PLAN.md — Email delivery infrastructure (Config, Delivery, Workers, Error, Mailer)
- [x] 03-02-PLAN.md — Auth confirmation/reset functions, Telemetry, Testing helpers
- [x] 03-03-PLAN.md — Generated email module, mailer wrapper, confirmation flow templates
- [x] 03-04-PLAN.md — Generated reset password flow templates, unconfirmed access plug
- [x] 03-05-PLAN.md — Auth context wiring, generator updates, test fixtures
- [x] 03-06-PLAN.md — Gap closure: wire EmailDelivery Oban worker perform/1

### Phase 4: Session Management and Security Baseline
**Goal**: Sessions are database-backed and fully controllable, with secure cookie defaults, configurable timeouts, account lockout, IP-based rate limiting, suspicious login detection, and sudo/re-authentication
**Depends on**: Phase 3
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, SESS-05, SESS-06, SESS-07, SESS-08, SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06, SEC-07
**Success Criteria** (what must be TRUE):
  1. Session tokens are opaque database-backed tokens in HttpOnly/SameSite=Lax/Secure cookies; no session data is in the cookie itself
  2. User can opt into remember-me, receiving a separate long-lived cookie (60-day default) that survives browser restarts
  3. User can view all active sessions (IP, user agent, last active) and revoke any individual session or all sessions at once
  4. After 5 failed login attempts the account locks for 15 minutes; after 10 failed attempts from one IP in a minute the IP receives a 429 response
  5. When a user logs in from a new IP or device, they receive an email notification
**Plans:** 6 plans
Plans:
- [x] 04-01-PLAN.md — Session struct, SessionStore behaviour, GeoIP, UAParser, Ecto store, config extensions
- [x] 04-02-PLAN.md — FetchSession plug overhaul, RequireSudo redesign, Auth session functions, telemetry
- [x] 04-03-PLAN.md — Lockout module, Hammer wrapper, RateLimit plug, security testing helpers
- [x] 04-04-PLAN.md — Suspicious login detection, Auth.authenticate integration, TokenCleanup extension
- [x] 04-05-PLAN.md — Generator templates (migration, UserSession, sudo, emails, auth context)
- [x] 04-06-PLAN.md — Session listing LiveView, generator wiring, test fixtures, final verification

### Phase 5: OAuth and Social Login
**Goal**: Users can register and log in via Google, GitHub, Apple, and Meta; existing users can link and unlink OAuth providers; account linking requires explicit confirmation to prevent account takeover
**Depends on**: Phase 4
**Requirements**: OAUTH-01, OAUTH-02, OAUTH-03, OAUTH-04, OAUTH-05, OAUTH-06, OAUTH-07, OAUTH-08
**Success Criteria** (what must be TRUE):
  1. User can register and log in with Google or GitHub in under 10 minutes of provider configuration; Apple and Meta work with additional setup
  2. When an OAuth callback matches an existing email-based account, the user is shown a confirmation step before the provider is linked — auto-linking is opt-in
  3. Authenticated user can link a new OAuth provider from settings and unlink it; a user with only one OAuth provider cannot unlink until a password is set
  4. Multiple OAuth providers can be linked to one account; each stored with encrypted access and refresh tokens
  5. Edge cases are handled gracefully: provider returns no email, user denies permissions, provider is down, CSRF state mismatch all produce clear error messages
**Plans:** 3 plans
Plans:
- [x] 05-01-PLAN.md — Core types, config, Identity struct, Assent strategy wrappers
- [x] 05-02-PLAN.md — OAuth orchestrator, callback processor, Auth integration, telemetry, testing
- [x] 05-03-PLAN.md — Generator (mix sigra.gen.oauth), templates, route/config injection
**UI hint**: yes

### Phase 6: Multi-Factor Authentication
**Goal**: Users can enroll TOTP, verify it on login via a `mfa_pending` session gate, use backup codes for recovery, and trust specific browsers; admins can enforce MFA per route or role
**Depends on**: Phase 4
**Requirements**: MFA-01, MFA-02, MFA-03, MFA-04, MFA-05, MFA-06, MFA-07, MFA-08, MFA-09
**Success Criteria** (what must be TRUE):
  1. User can enroll TOTP by scanning a QR code (or entering the key manually), confirming with a valid code, and enabling it — enrollment is not complete until the confirmation code is verified
  2. After login, a user with TOTP enabled is placed in `mfa_pending` state and cannot access protected routes until they submit a valid 6-digit code; the `mfa_pending` state blocks access, not just redirects
  3. User is shown 8 backup codes exactly once at enrollment; using a code consumes it atomically; user can regenerate a fresh set
  4. User can check "trust this browser" and skip MFA for a configurable period on that device; disabling MFA requires the current TOTP code or a backup code
  5. After 5 failed TOTP attempts the TOTP endpoint locks for 15 minutes, independently of the main login lockout
**Plans:** 5 plans
Plans:
- [x] 06-01-PLAN.md — MFA core library modules (Sigra.MFA, Credential, BackupCodes, Trust, Lockout, Config, Error)
- [x] 06-02-PLAN.md — MFA session gate (Session :mfa_pending, RequireMFA/RequireMFAEnrolled plugs, Auth MFA flow)
- [x] 06-03-PLAN.md — MFA telemetry, testing helpers, TokenCleanup extension
- [x] 06-04-PLAN.md — Generated schemas, migration, email templates, Auth context delegation
- [x] 06-05-PLAN.md — Generated UI templates, generator wiring, router injection
**UI hint**: yes



### Phase 7: API Authentication
**Goal**: API clients can authenticate via bearer tokens or personal access tokens; the same `current_scope` shape is produced for both session and bearer auth paths; headless mode works without any UI
**Depends on**: Phase 4
**Requirements**: API-01, API-02, API-03, API-04, API-05, API-06, API-07
**Success Criteria** (what must be TRUE):
  1. API client can authenticate via `Authorization: Bearer <token>` header and receives the same `current_scope` as a session-authenticated browser user
  2. User can create an API key with a human-readable prefix (`myapp_live_<random>`); the raw key is shown exactly once at creation and is never retrievable again; it is stored as a SHA-256 hash
  3. Personal access tokens can be scoped and given an expiration; they appear in a listing; any token can be revoked individually
  4. JWT support works for stateless API use cases where instant revocation is not required; it is opt-in, not the default
  5. All auth logic works in headless mode with no LiveView or HTML components present
**Plans:** 4 plans
Plans:
- [x] 07-01-PLAN.md — Core API token modules (config, types, scopes, APIToken, RequireScopes, errors, telemetry)
- [x] 07-02-PLAN.md — JWT library modules (Joken dep, JWT, Signer, ClaimsBuilder, RefreshToken)
- [x] 07-03-PLAN.md — FetchBearer rewrite, Auth delegation, TokenCleanup, Testing helpers, Email
- [x] 07-04-PLAN.md — Generator templates (migration, schema, controllers, router, install task)

### Phase 8: Account Lifecycle
**Goal**: Users can change email (with re-verification), change password, delete their account, and perform sensitive operations only after re-authenticating in sudo mode; profile update hooks integrate cleanly with app-specific schemas
**Depends on**: Phase 3
**Requirements**: ACCT-01, ACCT-02, ACCT-03, ACCT-04, SESS-09
**Success Criteria** (what must be TRUE):
  1. User can request an email change; the new address receives a confirmation link and the old address receives a notification with a cancel link; the change only takes effect after confirmation
  2. User can change their password by providing the current password; all other sessions are invalidated after a successful change
  3. User can delete their account; the deletion behavior (soft delete, hard delete, anonymization) is configurable by the developer
  4. Sensitive operations (change email, delete account, manage MFA) prompt for re-authentication if the sudo window has expired; the sudo window is configurable
  5. Application developers can register profile update callbacks that run within the same transaction as auth operations
**Plans:** 5 plans
Plans:
- [x] 08-01-PLAN.md — Config extensions, EmailTemplates behaviour, Hooks engine, DataExport behaviour
- [x] 08-02-PLAN.md — Account lifecycle library modules (EmailChange, PasswordChange, Deletion, Account orchestrator)
- [x] 08-03-PLAN.md — RequirePasswordChange plug, AccountDeletion Oban worker, Telemetry, Auth delegation
- [x] 08-04-PLAN.md — Generated templates (migration, user schema, auth context, hooks stub, email templates)
- [x] 08-05-PLAN.md — Settings LiveView, reactivation page, generator/injector updates, testing helpers
**UI hint**: yes

### Phase 9: Audit Logging
**Goal**: All security-relevant auth events are automatically captured in a queryable audit log with structured metadata; developers can emit custom events; log writes do not block auth request performance
**Depends on**: Phase 4
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03, AUDIT-04
**Success Criteria** (what must be TRUE):
  1. Every auth operation (login, logout, register, MFA, lockout, token creation, etc.) automatically writes an audit event without any developer action
  2. Each audit event includes user ID, IP address, user agent, timestamp, operation name, and outcome; the full metadata is queryable via `Sigra.Audit` API
  3. Developer can query the audit log by user, date range, or event type and receive structured results
  4. Developer can emit a custom audit event from application code using the same API
**Plans:** 5 plans
Plans:
- [x] 09-01-PLAN.md — Generator: audit_events migration + AuditEvent schema templates
- [x] 09-02-PLAN.md — Sigra.Audit core module (log/log_multi/query/list/stream/count) + Changeset/Cursor/Query submodules + Config
- [x] 09-03-PLAN.md — Integrate Sigra.Audit.__log_internal__ into auth/session/mfa/oauth/api/account/security subsystems (D-26 mapping)
- [x] 09-04-PLAN.md — Sigra.Workers.AuditCleanup Oban worker + inline fallback startup warning
- [x] 09-05-PLAN.md — Wave 0 test scaffolding (unit, integration, property, observability, sensitive-data, security, worker tests + fixtures)

### Phase 10: Developer Experience
**Goal**: The library ships with testing helpers that make auth state easy to set up in tests, scenario fixtures covering all auth states, correct cookie domain config, and copy-paste documentation examples
**Depends on**: Phase 1
**Requirements**: DX-01, DX-02, DX-03, DX-04
**Success Criteria** (what must be TRUE):
  1. `log_in_user/2`, `register_user/1`, `setup_totp/1`, and `create_api_key/2` are importable in ExUnit tests and set up the described state in one call
  2. Scenario-based fixtures cover all auth states (anonymous, authenticated, mfa_pending, mfa_complete, sudo, locked, unconfirmed) and can be used directly in test setup
  3. Cookie domain is configurable with sensible defaults that work in development, test, and production without manual intervention
  4. Documentation includes copy-paste examples for every major flow; a developer can get from zero to working auth in an afternoon

**Plans:** 6/6 plans complete
Plans:
- [x] 10-01-PLAN.md — REQUIREMENTS DX-01 reconciliation, Sigra.Testing section headers + audit helpers (D-01, D-18, D-19)
- [x] 10-02-PLAN.md — Seven scenario fixtures + scenario/2 dispatcher in generated AuthFixtures (D-02..D-07)
- [x] 10-03-PLAN.md — :cookie_domain config + runtime refactor across 3 cookie sites + prod boot warning (D-08..D-11)
- [x] 10-04-PLAN.md — ex_doc :extras + :groups_for_extras scaffold; subdomain-auth recipe (D-12, D-15)
- [x] 10-05-PLAN.md — Guide content (getting-started + flows + recipes) + doctests on Sigra.Testing/Auth/Config (D-13, D-14)
- [x] 10-06-PLAN.md — test/example/ Phoenix app + 6 D-17 smoke tests + example_app_smoke CI job (D-16, D-17)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/3 | Planning complete | - |
| 2. Core Auth | 0/2 | Planning complete | - |
| 3. Email Flows and Transactional Email | 0/5 | Planning complete | - |
| 4. Session Management and Security Baseline | 0/6 | Planning complete | - |
| 5. OAuth and Social Login | 0/3 | Planning complete | - |
| 6. Multi-Factor Authentication | 0/5 | Planning complete | - |
| 7. API Authentication | 0/4 | Planning complete | - |
| 8. Account Lifecycle | 0/5 | Planning complete | - |
| 9. Audit Logging | 0/5 | Planning complete | - |
| 10. Developer Experience | 6/6 | Complete   | 2026-04-10 |

### Phase 10.1: Installer and library fixes (INSERTED)

**Goal:** Fix pre-existing library bugs and backport installer template fixes surfaced during phase 10 review/security/validation audits
**Requirements**: Remediation (no new requirement IDs)
**Depends on:** Phase 10
**Plans:** 7/7 plans complete

**Scope (from phase 10 audits):**

1. **AR-10-01** — Fix `Sigra.Auth.request_password_reset/3` plain-map insert at `lib/sigra/auth.ex:828-835`. Build proper `%UserToken{}` struct via `config.token_schema`. Add live-repo regression test.
2. **AR-10-02** — Fix magic-link twin at `lib/sigra/auth.ex:425-432` (same plain-map-to-`insert!/1` pattern). Share regression test with AR-10-01.
3. **Installer template backport** — Merge 16 installer template fixes from `test/example/` copies into `priv/templates/sigra.install/*` (enumerated in `10-06-SUMMARY.md § Deviations > Rule 1`).
4. **MFA API surface** — Ensure `Sigra.MFA.verify_backup/4` and `Sigra.MFA.enabled?/2` exist as the canonical names used by guides/flows/mfa.md post-WR-01 fix.
5. **Docs strictness** — Clean up 27 pre-existing `mix docs --warnings-as-errors` `@doc` reference warnings so strict docs build passes in CI. Affected: OAuth strategy wrappers, `Sigra.Session`, `Sigra.Audit.Changeset`, `Sigra.RateLimiters.Hammer`.
6. **IN-03 supply chain** — SHA-pin third-party GitHub Actions in `.github/workflows/ci.yml` (`actions/checkout`, `erlef/setup-beam`, `actions/cache`). Add Dependabot `github-actions` config.
7. **IN-01** — Extract `Sigra.Env.current/0` helper for release-safe `Mix.env` guard (replaces duplicated `function_exported?(Mix, :env, 0)` pattern).
8. **IN-02** — Add concrete example comment for `mix.exs` `test_load_filters` regex.
9. **IN-04** — `AuthFixtures.scenario/2` should raise `ArgumentError` with the list of valid atoms instead of `FunctionClauseError` on typos.
10. **IN-05** — Document or fix `Sigra.Auth.normalize_email/1` interior whitespace handling scope.
11. **Pre-existing failing tests** — Fix `test/mix/tasks/sigra.install_test.exs` (2 failures) and `test/sigra/audit/cursor_portability_test.exs` (1 failure).
12. **test/example stubs** — Replace or better-document stub `Settings`/`Reactivation` LiveViews in `test/example/lib/example_web/live/` so they don't mislead users copying from the example app.

**Traceability:** `10-REVIEW.md` (CR-02, IN-01..IN-05), `10-REVIEW-FIX.md` (DEFERRED), `10-SECURITY.md` (AR-10-01, AR-10-02, IN-03), `10-VERIFICATION.md` (deferred items 1-6), `10-06-SUMMARY.md § Deviations`.

Plans:
- [x] 10.1-01-PLAN.md — Fix auth.ex plain-map DoS bugs (D-01, D-02, D-03) with shared live-repo regression test
- [x] 10.1-02-PLAN.md — Backport 16 Rule-1 installer template fixes + drift test (D-04, D-05)
- [x] 10.1-03-PLAN.md — Eliminate 27 mix docs --warnings-as-errors @doc reference warnings (D-07)
- [x] 10.1-04-PLAN.md — Sigra.Env.current helper + SHA-pin actions + Dependabot + docs CI gate (D-08, D-09, D-10, D-11)
- [x] 10.1-05-PLAN.md — Code quality: MFA allow-list, mix.exs comment, scenario/2 ArgumentError, normalize_email doc (D-06, D-12, D-13, D-14)
- [x] 10.1-06-PLAN.md — Investigate + fix 3 pre-existing failing tests (D-15, D-16)
- [x] 10.1-07-PLAN.md — Mark test/example stub LiveViews with visible warnings (D-17)

### Phase 10.1.1: example-app repair + CI install/usage smoke harness (INSERTED)

**Goal:** Repair the 5 remaining UAT integration bugs (B5-B9) in test/example/ (registration confirmation email, dual session stores, sudo KeyError, audit actor_id type mismatch, LiveView login form swallowed), fix doc drift + llms.txt + RUNBOOK brew collision note, flip the library installer default to uuid primary keys, and add a four-job CI smoke harness (install_smoke, example_http_smoke, example_playwright_smoke, example_unit_smoke) that would catch the B1-B9 class of bugs automatically on every PR.
**Requirements**: Remediation — CONTEXT.md decisions D-01 through D-15 (no new requirement IDs; traceability cleanup deferred)
**Depends on:** Phase 10.1
**Plans:** 4/8 plans executed

Plans:
- [x] 10.1.1-01-PLAN.md — Doc drift + llms.txt + RUNBOOK brew note (D-02, D-03, D-04)
- [x] 10.1.1-02-PLAN.md — B5 confirmation email wiring + B7 sudo template fix + template sync (D-05, D-08)
- [x] 10.1.1-03-PLAN.md — B6 session store unification in test/example + template sync (D-06, D-07)
- [x] 10.1.1-04-PLAN.md — B9 LoginLive → plain controller + template sync (D-12)
- [ ] 10.1.1-05-PLAN.md — B8 audit type mismatch + library uuid default flip + guides (D-09, D-10, D-11)
- [ ] 10.1.1-06-PLAN.md — CI install_smoke + example_http_smoke jobs + sigra.install --yes flag (D-13, D-15)
- [ ] 10.1.1-07-PLAN.md — Playwright golden-path harness + example_playwright_smoke CI job + MFA data-testid (D-13, D-14, D-15)
- [ ] 10.1.1-08-PLAN.md — Rename example_app_smoke → example_unit_smoke + branch protection note (D-13)
