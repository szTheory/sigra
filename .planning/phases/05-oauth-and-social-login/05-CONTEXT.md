# Phase 5: OAuth and Social Login - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can register and log in via OAuth providers (Google, GitHub, Apple, Meta); existing users can link and unlink OAuth providers from settings; account linking requires explicit confirmation to prevent account takeover. OAuth tokens are encrypted at rest. Assent is the OAuth/OIDC engine, wrapped by thin Sigra strategy modules.

</domain>

<decisions>
## Implementation Decisions

### Account Linking Policy
- **D-01:** Email-match linking always requires confirmation. When OAuth callback email matches an existing account, user must log in with their existing credentials to link the provider. No auto-linking. Prevents account takeover.
- **D-02:** Unconfirmed accounts treated the same as confirmed for linking -- same confirmation flow required. The unconfirmed account still owns that email.
- **D-03:** Block unlink of last provider until password is set. Show "Set a password first to keep access to your account." Prevents account lockout.
- **D-04:** One identity per provider per user. Unique constraint on (user_id, provider). User picks which account to link.
- **D-05:** Linking and unlinking both require sudo mode. Consistent security posture for all identity-affecting operations. Phase 4 sudo infrastructure reused.
- **D-06:** OAuth-only users (no password) confirm link requests by re-authenticating via their existing provider. Redirect to already-linked provider for re-auth.
- **D-07:** Notification emails on both link AND unlink. "Google was linked/removed from your account. Not you? Secure your account." Full audit trail via email. Uses Phase 3 email infrastructure.
- **D-08:** Provider returns no email: fail with clear error "We need your email to create an account. Please grant email permission and try again." Never create a user without email.
- **D-09:** If provider_uid maps to identity A but returned email matches user B: block login with generic error "Could not complete sign in." Log at :error level. Never auto-merge accounts.

### Provider Architecture
- **D-10:** Providers configured in config.exs as keyword list under `oauth: [providers: [...]]`. Runtime config via runtime.exs for secrets. Familiar Phoenix pattern.
- **D-11:** Thin wrapper per provider: `Sigra.OAuth.Strategies.Google` wraps `Assent.Strategy.Google`. Normalizes response, handles Sigra-specific concerns (email extraction, error mapping). Insulates host app from Assent API changes.
- **D-12:** Same code for all tiers, different docs. Tier 1 (Google, GitHub) gets quick-start docs. Tier 2 (Apple, Meta) gets extended setup docs covering extra steps.
- **D-13:** Named wrappers for tier 1-2 + generic fallback. Any Assent strategy works via `providers: [discord: [strategy: Assent.Strategy.Discord, ...]]`. Open for extension without modifying library.
- **D-14:** Assent is an optional dependency with `Code.ensure_loaded?` gate. Same pattern as Hammer/Oban/bcrypt. Apps that don't use OAuth don't need Assent.
- **D-15:** Runtime validation with startup check. NimbleOptions validates provider config structure at app startup. Missing client_id/secret logged as warning. No compile-time dependency on secrets.
- **D-16:** Sigra owns OAuth state (CSRF): generates HMAC-signed state param, stores in session, verifies on callback before delegating token exchange to Assent. Consistent with Sigra's token security patterns.
- **D-17:** PKCE (S256) enabled by default for all providers where Assent supports it. More secure, prevents authorization code interception.
- **D-18:** OIDC discovery when available. For OIDC-capable providers (Google, Apple), use Assent's OIDC strategy with auto-discovery from `.well-known/openid-configuration`. Fall back to manual config for non-OIDC providers.
- **D-19:** OAuth routes are controller-only. OAuth is redirect-based -- standard controller handles `/auth/:provider` and `/auth/:provider/callback`. LiveView not needed for the redirect dance.
- **D-20:** Module structure split by concern: `Sigra.OAuth` (orchestrator), `Sigra.OAuth.Callback` (response processing), `Sigra.OAuth.Strategies.*` (per-provider wrappers). Follows Phase 1 D-02 convention.
- **D-21:** Configurable scopes per provider: `google: [scopes: ["email", "profile"]]`. Sensible defaults per provider. Developer can expand for API access.

### Token Storage & Identity Schema
- **D-22:** Encrypted token storage via cloak_ecto with AES-256-GCM. Encrypted columns for access_token and refresh_token in user_identities.
- **D-23:** cloak_ecto is a required dependency for OAuth. If you use `mix sigra.gen.oauth`, cloak_ecto must be installed.
- **D-24:** Vault generated into host app: minimal `MyApp.Vault` module (~10 lines) + `MyApp.Encrypted.Binary` Ecto type. Works out of box with `CLOAK_KEY` env var. Developer owns encryption config.
- **D-25:** Full identity record columns: id, user_id, provider (string, normalized lowercase), provider_uid (string), encrypted_access_token, encrypted_refresh_token, token_expires_at, provider_email, provider_name, provider_avatar_url, metadata (JSONB -- normalized subset), last_used_at, inserted_at, updated_at.
- **D-26:** Two unique indexes: (user_id, provider) enforces one-per-provider-per-user, (provider, provider_uid) prevents one provider account linking to multiple Sigra users.
- **D-27:** Auto-refresh tokens on access. When developer calls `Sigra.OAuth.get_tokens/2`, if access token is expired and refresh token exists, auto-refresh and persist new tokens. Transparent "pit of success" DX. Clear error if refresh fails.
- **D-28:** Library struct `Sigra.Identity` with `from_schema/1` and `to_params/1` mapping. Generated `UserIdentity` Ecto schema handles persistence. Same pattern as Sigra.Session/UserSession from Phase 4.
- **D-29:** No IdentityStore behaviour. Ecto-only. Nobody stores OAuth identities outside a database. Library functions take repo + schema module directly.
- **D-30:** Provider column is regular string, normalized to lowercase in code. Works across all databases without citext dependency.
- **D-31:** Update identity on every OAuth login. Keep provider_name, provider_email, provider_avatar_url, and tokens fresh. Does NOT update the users table (app domain).
- **D-32:** Match identities by (provider, provider_uid), never by email alone. If provider email changed, update provider_email on identity record. Primary email change is Phase 8 scope.
- **D-33:** Metadata column stores normalized subset of useful fields (locale, verified_email flag, provider-specific IDs). Drop raw response after extraction.
- **D-34:** Track last_used_at on identity, throttled writes like Phase 4 session activity_update_threshold.
- **D-35:** Separate migration generated by `mix sigra.gen.oauth`. Not added to Phase 1 base migration. OAuth is opt-in.

### OAuth Flow UX
- **D-36:** OAuth buttons above password form with "or" divider. Same layout as Phase 2 magic link. Users see easiest path first. Matches GitHub/Vercel/Linear pattern.
- **D-37:** Dynamic button rendering from configured providers list. Add a provider in config, it appears on login page. No template edit needed.
- **D-38:** Inline SVG icons for tier 1-2 providers following brand guidelines. Generic icon for custom providers.
- **D-39:** Callback errors: redirect to login with generic flash "Could not sign in with [Provider]. Please try again or use another method." Internal telemetry/logs include full Assent error details.
- **D-40:** CSRF state mismatch: redirect to login with "Authentication expired. Please try again." Don't mention CSRF. Log at :warning level.
- **D-41:** Account linking confirmation UX: redirect to login page with banner "An account with this email exists. Log in to link your [Provider] account." After successful login, auto-link. Link intent stored in Plug session with prefixed keys (`sigra_oauth_*`), 15-minute TTL.
- **D-42:** OAuth registration auto-confirms email since provider verified it. `confirmed_at = now()`. No confirmation email sent.
- **D-43:** OAuth login creates remember-me sessions by default. Users expect to stay logged in after "Sign in with Google." Configurable via `:session_type` in oauth config.
- **D-44:** return_to support: store in session before OAuth redirect, redirect to stored path after successful callback. Same pattern as RequireAuthenticated plug.
- **D-45:** Post-OAuth hooks via telemetry only (`[:sigra, :oauth, :callback, :stop]`). No separate callback behaviour. Consistent with Phase 4 lockout hooks pattern.
- **D-46:** Route namespace: `/auth/:provider` and `/auth/:provider/callback`. Separate from `/users/*` routes.
- **D-47:** Session state during redirect stored in Plug session with prefixed keys: `sigra_oauth_state`, `sigra_oauth_link_intent`, `sigra_oauth_return_to`. Cleared after callback processing.
- **D-48:** Same session type as password login with metadata noting auth method. Session metadata includes `auth_method: :oauth` and `provider: :google`. Uniform handling, auditable.
- **D-49:** Provider unavailable: no retry, clear error + "Try again" link. OAuth is user-initiated.
- **D-50:** Already-authenticated user clicking OAuth button: treat as link attempt (add provider to current account). Requires sudo.
- **D-51:** Settings page: both LiveView component and controller HTML variants generated. `--live` flag on generator controls which. Dynamic rendering based on configured providers.
- **D-52:** OAuth-only users see subtle hint in settings: "No password set. Set a password to enable email login and as a backup."
- **D-53:** Unlink confirmation shows remaining auth methods: "You'll still be able to log in with: Password, GitHub."

### Error Handling
- **D-54:** Sigra.Error.OAuthError struct with fields: provider, error_code (:state_mismatch, :no_email, :provider_error, :token_exchange_failed, :link_conflict, :email_mismatch). Each has safe_message/1.
- **D-55:** Generic user-facing messages with detailed internal logging. Never leak provider implementation details.
- **D-56:** No special cooldown on OAuth initiation. IP rate limiting on /auth/:provider covers it.

### Generator Design
- **D-57:** Incremental generator: `mix sigra.gen.oauth`. Not part of base install. Keeps base lean. Phase 1 D-08 planned this.
- **D-58:** Full file set generated: migration, UserIdentity schema, Vault + encrypted type (if not exists), OAuth controller, HTML + LiveView templates, route injection, config injection, test fixtures. ~8-10 files.
- **D-59:** Generator is idempotent. Detects existing files and injections, skips with message. Safe to re-run.
- **D-60:** Optional provider args: `mix sigra.gen.oauth --providers google github` adds config stubs. Without args, generates infra with comments showing how to add providers.

### Telemetry
- **D-61:** OAuth-specific events: `[:sigra, :oauth, :authorize, :start/:stop]`, `[:sigra, :oauth, :callback, :start/:stop]`, `[:sigra, :oauth, :link, :stop]`, `[:sigra, :oauth, :unlink, :stop]`, `[:sigra, :oauth, :refresh, :stop]`. Metadata: provider, user_id (when known).

### Config Surface
- **D-62:** New `oauth:` section in Sigra.Config. Flat structure with providers list. Keys: enabled (true), providers ([]), session_type (:remember_me), link_confirmation (:required), trust_provider_email (true). NimbleOptions validated.
- **D-63:** Kill switch: `oauth: [enabled: false]` disables OAuth routes and hides buttons. Generated code stays intact.

### Testing
- **D-64:** New Sigra.Testing helpers: `mock_oauth_callback/2`, `create_identity/2`, `oauth_user_fixture/1`. Mock Assent at HTTP level for integration tests.

### Multi-Database
- **D-65:** PostgreSQL primary with adapter detection at generation time. JSONB for metadata on PostgreSQL, TEXT with JSON serialization for MySQL/SQLite. Encrypted columns are binary in all databases. Same pattern as Phase 4 D-63.

### MFA Preparation
- **D-66:** OAuth login with MFA enabled: user enters mfa_pending state after OAuth callback (same as password login). MFA is the app's policy, not bypassed by OAuth.
- **D-67:** Minimal prep for Phase 6: ensure OAuth session creation goes through same code path as password login so Phase 6's mfa_pending changes apply uniformly.

### Headless/API OAuth
- **D-68:** Deferred to Phase 7 (API Authentication). Phase 5 is server-rendered OAuth only. Phase 7 adds JSON endpoint for SPA/mobile token exchange.
- **D-69:** When implemented: client handles OAuth redirect (RFC 8252), sends auth code to Sigra API endpoint.

### Claude's Discretion
- Exact Assent API surface used in strategy wrappers
- OAuth state HMAC implementation details (key derivation, format)
- SVG icon markup and brand guideline compliance
- Session cleanup for stale link intents
- Exact NimbleOptions schema for per-provider config validation
- Controller template structure and naming
- Test mock implementation details for Assent HTTP layer

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` -- Vision, hybrid lib+generator architecture, Assent chosen over Ueberauth
- `.planning/REQUIREMENTS.md` -- OAUTH-01 through OAUTH-08 requirements
- `.planning/ROADMAP.md` SS Phase 5 -- Goal, success criteria, requirement mapping

### Prior phase context
- `.planning/phases/01-foundation/01-CONTEXT.md` -- D-02 (concept.ex convention), D-05 (NimbleOptions config), D-08 (incremental generators), D-09 (EEx templates), D-10 (string injection), D-12 (behaviours), D-19 (error handling), D-35 (optional dep handling)
- `.planning/phases/02-core-auth/02-CONTEXT.md` -- D-01 (dual-mode auth layout), D-23 (auto-login after registration), D-28 (enumeration prevention), D-35-38 (session token format)
- `.planning/phases/03-email-flows-and-transactional-email/03-CONTEXT.md` -- D-18 (email module structure), D-21-27 (Oban/async delivery)
- `.planning/phases/04-session-management-and-security-baseline/04-CONTEXT.md` -- D-01-07 (session architecture), D-08-09 (remember-me), D-20-23 (sudo mode), D-33-43 (rate limiting), D-62 (email templates)

### Existing code to extend
- `lib/sigra/auth.ex` -- Core auth orchestrator. Add OAuth registration, login, link, unlink functions
- `lib/sigra/config.ex` -- NimbleOptions config. Add oauth: section
- `lib/sigra/telemetry.ex` -- Event catalog. Add OAuth events
- `lib/sigra/testing.ex` -- Test helpers. Add OAuth helpers
- `lib/sigra/error.ex` -- Error types. Add OAuthError
- `lib/sigra/plug/fetch_session.ex` -- Session handling. OAuth sessions use same path
- `lib/sigra/plug/require_sudo.ex` -- Sudo mode. Used for link/unlink operations
- `lib/sigra/plug/rate_limit.ex` -- Rate limiting. Apply to /auth/:provider routes
- `lib/sigra/install/injector.ex` -- Route/config injection. Extend for OAuth routes

### Ecosystem documentation
- `CLAUDE.md` SS Technology Stack -- Assent 0.3.1, cloak_ecto 1.3.0, version compatibility matrix
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` -- Ecosystem analysis, Assent rationale, account linking patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Auth` -- Orchestrator with register/authenticate/create_session. Extend with OAuth registration/login/link/unlink
- `Sigra.Token` -- HMAC token generation/verification. Reuse for OAuth state parameter
- `Sigra.Config` -- NimbleOptions validated config. Add oauth: section
- `Sigra.Telemetry` -- span/3 and event/3 helpers. Add OAuth event catalog
- `Sigra.Error` -- Exception types with safe_message/1. Add OAuthError
- `Sigra.Plug.RequireSudo` -- Sudo mode plug. Reuse for link/unlink operations
- `Sigra.Plug.RateLimit` -- IP rate limiting. Apply to /auth routes
- `Sigra.Session` -- Library struct. OAuth sessions use same struct with auth_method metadata
- `Sigra.Install.Injector` -- Route/config injection. Extend for OAuth routes
- `priv/templates/sigra.install/` -- Existing template patterns. Follow same conventions for OAuth templates

### Established Patterns
- `{:ok, result} | {:error, reason}` everywhere (Phase 1 D-19)
- Behaviours for extensibility, `Code.ensure_loaded?` for optional deps (Phase 1 D-12, D-35)
- Telemetry span for sync ops, one-shot for signals (Phase 1 D-15/18)
- NimbleOptions for all config sections (Phase 1 D-05)
- Enumeration-safe responses with generic messages (Phase 2 D-44)
- Async email delivery via Oban with inline fallback (Phase 3 D-21-27)
- Incremental generator pattern planned in Phase 1 D-08
- Library struct + generated schema mapping (Phase 4 Session/UserSession)

### Integration Points
- New `Sigra.OAuth` module tree (orchestrator, callback, strategies)
- New `Sigra.Identity` library struct
- New `Sigra.Error.OAuthError` exception type
- Generated `UserIdentity` Ecto schema
- Generated `MyApp.Vault` + `MyApp.Encrypted.Binary` (cloak_ecto)
- Generated OAuth controller with /auth/:provider routes
- Generated OAuth HTML + LiveView templates (login buttons, settings page)
- Route injection for /auth/:provider and /auth/:provider/callback
- Config injection for oauth: section in Sigra config
- New email templates: provider_linked_email/2, provider_unlinked_email/2
- Login page templates updated with dynamic OAuth buttons

</code_context>

<specifics>
## Specific Ideas

- OAuth buttons above password form matching GitHub/Vercel/Linear layout pattern
- "Pit of success" DX: auto-refresh tokens transparently, auto-confirm provider-verified emails, remember-me sessions by default
- Linking confirmation via redirect to login page with banner (not a separate dedicated page)
- Settings page shows linked providers with icon, name, linked date, last used, and remaining auth methods on unlink
- OAuth-only users see subtle "set a password" hint in settings, not an intrusive banner
- Dynamic OAuth buttons render from config -- add provider in config, it appears on login page
- Generator creates Vault + encrypted type as a small, focused module -- not a bunch of scattered config

</specifics>

<deferred>
## Deferred Ideas

- Headless/API OAuth for SPA/mobile clients (Phase 7 -- API Authentication)
- MFA session states on OAuth login (Phase 6 -- MFA adds mfa_pending gate)
- OAuth re-authentication for sudo mode on OAuth-only accounts (Phase 5 supports via existing provider re-auth, Phase 6 adds MFA option)
- Email change with re-verification (Phase 8 -- ACCT-01)
- SAML/enterprise SSO (out of scope for v1)

</deferred>

---

*Phase: 05-oauth-and-social-login*
*Context gathered: 2026-04-08*
