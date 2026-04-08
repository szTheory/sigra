# Phase 7: API Authentication - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

API clients authenticate via bearer tokens (opaque API tokens or JWT), with scoped permissions, configurable expiration, and the same `current_scope` shape as session-authenticated users. Dual-mode auth works via separate plugs in separate pipelines (Phoenix-idiomatic). JWT is opt-in with opaque refresh tokens. Headless mode works without any UI.

</domain>

<decisions>
## Implementation Decisions

### API Token Format & Storage
- **D-01:** App-configurable prefix. Default derived from OTP app name: `{otp_app}_sk_`. Developer overrides via `api_token: [prefix: "myapp_live_"]`.
- **D-02:** No live/test key distinction at the library level. Prefix is for human readability and grep-ability only. Environment controlled via standard Mix config per env (config/dev.exs, config/prod.exs). Matches Elixir ecosystem convention (Swoosh, Oban, ExAws all use adapter/config pattern).
- **D-03:** 32 bytes random via `:crypto.strong_rand_bytes(32)`, URL-safe base64 (43 chars). Consistent with Phase 2 D-35 session token format.
- **D-04:** Separate `user_api_tokens` table — NOT in `user_tokens`. Different lifecycle: API tokens are long-lived, scoped, named, with last-used tracking. Email/session tokens have different expiry, cleanup, and no scopes.
- **D-05:** Single token type (user-scoped). No API key vs PAT distinction — scopes handle different use cases. Service accounts deferred to v2. Migration path: rename `user_id` to `owner_id` + `owner_type` when service accounts arrive.
- **D-06:** Table schema: `id` (binary_id PK), `user_id` (FK → users), `hashed_token` (binary, unique), `prefix` (string), `name` (string, required, not unique, max 255), `scopes` ({:array, :string}), `last_used_at` (utc_datetime_usec), `expires_at` (utc_datetime), `revoked_at` (utc_datetime), `inserted_at` (utc_datetime_usec, no updated_at). Indexes: unique(hashed_token), (user_id), (user_id, revoked_at, expires_at).
- **D-07:** Module name: `Sigra.APIToken`. Generated schema: `MyApp.Auth.UserAPIToken`.

### Token Lifecycle
- **D-08:** Soft delete via `revoked_at` timestamp. Token stays in DB for audit trail. `list_active/2` filters `WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now())`.
- **D-09:** Throttled `last_used_at` updates — only write if more than 5 min since last update. Same pattern as Phase 4 D-13 (session activity_update_threshold). Configurable threshold.
- **D-10:** Raw key shown once on creation. `Sigra.APIToken.create/2` returns `{:ok, raw_key, token_record}`. Raw key is never stored — only SHA-256 hash.
- **D-11:** `Sigra.APIToken.revoke_all(user)` sets `revoked_at` on all active tokens. Consistent with Phase 4 session revoke_all. Telemetry event emitted with count.
- **D-12:** API tokens survive password change. Password change invalidates sessions (Phase 4) and JWT refresh tokens, but NOT API tokens. CI pipelines shouldn't break on password change. Explicit `revoke_all` for account compromise.
- **D-13:** Expiration is optional. If not set, token lives until revoked. Developer can enforce expiry via config: `require_expiry: true`, `max_ttl: {365, :days}`.
- **D-14:** Extend existing `Sigra.Workers.TokenCleanup` to clean up revoked API tokens older than retention period (default 90 days). Expired API tokens also cleaned after retention.
- **D-15:** Token names are required, not unique per user, max 255 chars. Users may want "CI deploy" for multiple environments.

### Rate Limiting
- **D-16:** Reuse existing `Sigra.Plug.RateLimit` from Phase 4 with API-specific limits. Rate limit by token ID (not just IP) for authenticated API requests. API pipeline generated with RateLimit plug by default.

### Scope & Permissions Model
- **D-17:** `resource:action` colon-separated strings with a declared canonical registry. Sigra ships built-in auth scopes: `profile:read`, `profile:write`, `sessions:read`, `sessions:write`, `api_tokens:read`, `api_tokens:write`, `mfa:read`, `mfa:write`. Host apps register custom scopes via config.
- **D-18:** Explicit grants required by default. `write` does NOT imply `read`. Opt-in `write_implies_read: true` config for teams that prefer it. Aligns with OWASP least privilege, AWS/Microsoft pattern.
- **D-19:** Two enforcement layers: `Sigra.Plug.RequireScopes` for route-level (403 Forbidden), and `Sigra.APIToken.can?/2` for inline checks in business logic. Wildcard `*` passes all checks.
- **D-20:** AND logic by default — token must have ALL listed scopes. Named OR option via `match: :any`. Matches Sanctum CheckAbilities/CheckForAnyAbility, Django TokenHasScope.
- **D-21:** Session-authenticated users bypass scope checks (implicit full access). `token_scopes = nil` means full access. Scopes only apply to API tokens and JWT.
- **D-22:** Scopes stored as Postgres `text[]` array (`{:array, :string}`). MySQL/SQLite: comma-separated string via `Sigra.Ecto.Types.StringList` custom type. Generator detects adapter and emits correct DDL.
- **D-23:** Scope validation at creation-time only. Validate against registry when creating token. At verification, fast MapSet lookup — no registry check per request.
- **D-24:** 403 Forbidden with `insufficient_scope` error for valid token missing required scope. Distinct from 401 Unauthenticated. Response includes `required` and `provided` scopes. Via existing ErrorHandler behaviour.
- **D-25:** Scope registry via runtime config (NimbleOptions). Custom scopes in `config.exs`, validated at startup. Consistent with all other Sigra config.
- **D-26:** Enforce `resource:action` format: `^[a-z_]+:[a-z_]+$` regex. Prevents inconsistent naming. Wildcard `*` is special case.
- **D-27:** Scopes on `current_scope` struct. Add `token_scopes` (list or nil), `auth_method` (`:session` | `:api_token` | `:jwt`), and `token_id` fields. Same `current_scope` shape for all auth methods.
- **D-28:** Require explicit scopes at token creation. No default. `scopes: []` or omitted → `{:error, :scopes_required}`. Explicit `["*"]` for full access.
- **D-29:** `Sigra.APIToken.list_scopes/0` returns all registered scopes (built-in + custom). For UI scope picker generation.
- **D-30:** Scopes apply to both opaque API tokens AND JWT access tokens. JWT embeds scopes as a `scopes` claim. Same `RequireScopes` plug works for both.

### JWT Implementation
- **D-31:** Joken ~> 2.6 as optional dependency (`optional: true`). Auto-detected via `Code.ensure_loaded?`. Same optional dep pattern as Hammer/bcrypt. If `jwt: [enabled: true]` but Joken absent, hard error at startup with clear message.
- **D-32:** HS256 default, key derived from app's `secret_key_base` with Sigra-specific salt. RS256/ES256 opt-in via PEM config. Library accepts keys, never manages them.
- **D-33:** Refresh tokens are opaque hashed tokens in `user_tokens` table (`context: "api_refresh"`). NOT JWT refresh tokens. Rotation on every use. Family-based reuse detection: reuse of invalidated token revokes entire family (stolen token detection). Auth0/Okta/Passport pattern.
- **D-34:** Standard JWT claims: `sub` (user ID as string), `iat`, `exp`, `jti` (UUID), `iss` (configurable app name), `scopes`, `epoch` (user's token_epoch). Custom claims via `Sigra.JWT.ClaimsBuilder` behaviour with `extra_claims/1` callback.
- **D-35:** Password change revokes all JWT refresh tokens (prevents new access tokens). Access JWTs expire naturally (15min max). API tokens survive password change.
- **D-36:** `Sigra.JWT.ClaimsBuilder` behaviour with single `extra_claims(user) :: map()` callback. Avoids Guardian's 10+ callback anti-pattern. Host app implements for custom claims.
- **D-37:** User epoch check by default. `token_epoch` integer column on users table (next to `mfa_trust_epoch`). Default 0. Embedded in JWT as `epoch` claim. On every JWT request: verify signature + expiry (stateless), then one DB read to check user.token_epoch matches claim. Account deletion = no record = reject immediately. Opt-out via `jwt: [verify_epoch: false]` with logged warning.
- **D-38:** FetchBearer auto-detects token type: starts with configured prefix → opaque API token (DB lookup); starts with `eyJ` → JWT (verify). One plug handles both. Prefix validation at startup rejects prefixes starting with `eyJ` to prevent collision. Prefix must match `^[a-z0-9_]+$`.
- **D-39:** No JWT blacklist. Access JWTs expire only (15min max stale window). Revoke refresh token to prevent new access tokens. Epoch check handles account deletion, password change, and sign-out-everywhere.
- **D-40:** JWT telemetry: `[:sigra, :jwt, :generate, :start/:stop]`, `[:sigra, :jwt, :verify, :start/:stop]`, `[:sigra, :jwt, :refresh, :start/:stop]`. One-shot: `[:sigra, :jwt, :refresh_reuse_detected]`. Metadata: user_id, scopes, auth_method.
- **D-41:** Generator creates `TokenController` with `POST /api/auth/token` (create), `POST /api/auth/token/refresh`, `POST /api/auth/token/mfa`, `DELETE /api/auth/token` (revoke refresh). Opt-in via `mix sigra.install --jwt`.
- **D-42:** Default access TTL: 15 minutes. Default refresh TTL: 30 days. Both configurable.
- **D-43:** Any authenticated user can get JWT (session cookie accepted at token endpoint). OAuth-only users not locked out of API access.
- **D-44:** CORS is developer's responsibility. Document corsica/cors_plug setup in API auth guide. Not auth library's concern. Consistent with Swoosh/Oban/Absinthe/Sanctum/DRF — no auth library ships CORS.
- **D-45:** JWT is headless-native. `mix sigra.install --no-live --jwt` = complete API-only auth solution. JWT endpoints are JSON APIs with no UI dependency.
- **D-46:** JWT rate limiting: reuse `Sigra.Plug.RateLimit`. Strict on token create (5/min/IP, login-equivalent). Relaxed on refresh (30/min/user).
- **D-47:** JWT login always requires MFA if user has TOTP enrolled. No trust cookie concept for API. Two-step flow: `POST /api/auth/token` → `{mfa_required: true, mfa_token: "temp_..."}`, then `POST /api/auth/token/mfa` with TOTP code. Opaque API tokens skip MFA (created from authenticated settings page where user already MFA'd).
- **D-48:** Key rotation: document-only for v1. HS256 rotates with `secret_key_base`. RS256 key rotation documented in guides. v2: JWKS endpoint + multi-key validation for zero-downtime rotation.
- **D-49:** New `jwt:` section in Sigra config via NimbleOptions: `enabled`, `algorithm`, `issuer`, `access_ttl`, `refresh_ttl`, `refresh` (boolean), `claims_builder`, `verify_epoch`.
- **D-50:** JWT error responses: structured JSON with error codes. `token_expired` (401), `invalid_token` (401), `mfa_required` (403), `token_revoked` (401). Via ErrorHandler behaviour.
- **D-51:** `Sigra.JWT` module namespace follows concept.ex + concept/ pattern: `jwt.ex` (public API), `jwt/claims_builder.ex`, `jwt/signer.ex`, `jwt/refresh_token.ex`.

### Dual-Mode Auth Plug
- **D-52:** Separate plugs for session vs bearer. No combined `FetchAny` plug. `FetchSession` in `:browser` pipeline, `FetchBearer` in `:api` pipeline. Phoenix-idiomatic — matches every Phoenix auth library's approach.
- **D-53:** Both `FetchSession` and `FetchBearer` skip if `current_scope` is already assigned. Enables clean composition: in a mixed pipeline, bearer runs first; if bearer found, session plug skips. No wasted DB lookup.
- **D-54:** API pipeline generated only with `--jwt` or `--api` flag. Default `mix sigra.install` generates browser pipeline only.
- **D-55:** Commented-out `api_or_browser` pipeline example in generated router.ex for developers who need mixed-mode endpoints.
- **D-56:** Content negotiation via existing ErrorHandler behaviour (Phase 4 D-39). JSON for API requests, flash+redirect for browser. New error atoms: `:token_expired`, `:insufficient_scope`, `:mfa_required`. No new mechanism needed.
- **D-57:** Generate JSON API endpoints for token management: `GET /api/tokens` (list), `POST /api/tokens` (create), `DELETE /api/tokens/:id` (revoke), `DELETE /api/tokens` (revoke all). Protected by RequireAuthenticated + RequireScopes (`api_tokens:read/write`). Token creation requires sudo mode.

### Pagination
- **D-58:** Cursor-based pagination, hand-rolled keyset query (no library dep). Opaque Base64 cursors (Stripe-style). Default limit 50, max 200. Returns `{tokens, next_cursor | nil}`. No page numbers. Keyset: `WHERE (inserted_at, id) > (cursor_at, cursor_id) ORDER BY inserted_at, id LIMIT n+1`.

### Config Surface
- **D-59:** New `api_token:` section in Sigra config: `prefix` (nil = `{otp_app}_sk_`), `custom_scopes` ([]), `write_implies_read` (false), `require_expiry` (false), `max_ttl` (nil), `cleanup_retention` ({90, :days}), `activity_update_threshold` (300s), `default_page_size` (50), `max_page_size` (200).

### Telemetry
- **D-60:** API token telemetry: `[:sigra, :api_token, :create, :start/:stop]`, `[:sigra, :api_token, :verify, :start/:stop]`, `[:sigra, :api_token, :revoke, :stop]`, `[:sigra, :api_token, :revoke_all, :stop]`. Metadata: user_id, token_id, name, scopes, ip, user_agent. Rich enough for Phase 9 audit logging subscription.
- **D-61:** Default logger: API token events at `:info` level, security events (refresh_reuse_detected) at `:warning`.

### Email Notifications
- **D-62:** Notify on API token creation only. Email includes token name, scopes, IP, and "Not you? Revoke it from settings" link. Uses Phase 3 email infrastructure (async via Oban). No email on revocation or expiry.

### Testing
- **D-63:** Comprehensive testing helpers in `Sigra.Testing`: `create_api_token/2` (returns `{raw_key, %APIToken{}}`), `put_api_token/2` (ConnCase bearer header), `put_bearer_token/2` (alias), `assert_token_revoked/1`, `assert_scope_denied/1` (403 check), `api_token_fixture/2`, `expired_api_token_fixture/1`, `revoked_api_token_fixture/1`, `scoped_api_token_fixture/2`.
- **D-64:** JWT testing helpers: `generate_jwt/2`, `expired_jwt/2`, `jwt_with_scopes/3`.

### Migration
- **D-65:** Add `token_epoch` integer column (default 0, not null) to users table in Phase 1 migration template, next to `mfa_trust_epoch`. Increment on password change, sign-out-everywhere, admin revoke. Account deletion = no record = epoch check fails.

### Multi-Database
- **D-66:** Scopes column: Postgres `text[]` natively, MySQL/SQLite via `Sigra.Ecto.Types.StringList` custom type (comma-separated string). Generator detects adapter and emits correct DDL. IP stored as string (not inet) for portability. Timestamps as utc_datetime_usec.

### Claude's Discretion
- Exact Ecto queries for token CRUD operations
- Cursor encoding format (Base64 implementation details)
- Internal module organization within decided namespaces (Sigra.APIToken/*, Sigra.JWT/*)
- Changeset validation implementation details
- Test fixture exact function signatures and default values
- Generated template HTML/CSS styling
- Error message exact wording (within decided error codes)
- NimbleOptions schema validation implementation details
- Sigra.Ecto.Types.StringList internals for MySQL/SQLite adapter
- FetchBearer JWT vs opaque detection edge cases
- TokenCleanup batch sizes and scheduling frequency
- Exact RequireScopes plug option parsing internals
- Sigra.JWT.Signer key derivation implementation details
- Refresh token family tracking implementation (how family IDs are generated/stored)
- API JSON response envelope structure (beyond decided fields)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` — Vision, architecture philosophy, hybrid lib+generator rationale
- `.planning/REQUIREMENTS.md` — API-01 through API-07 requirements
- `.planning/ROADMAP.md` §Phase 7 — Goal, success criteria, requirement mapping

### Prior phase context (dependencies)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01 (module structure), D-03 (behaviour naming), D-12 (SessionStore behaviour), D-19 (error patterns), D-28-31 (plug architecture), D-35 (optional dep handling), D-43-45 (naming conventions), D-49 (token strategies)
- `.planning/phases/02-core-auth/02-CONTEXT.md` — D-35-38 (session token format, cookie name, TTL), D-44-46 (error messages, enumeration prevention), D-47-49 (Sigra.Auth library module)
- `.planning/phases/03-email-flows-and-transactional-email/03-CONTEXT.md` — D-18 (email module structure), D-21-27 (Oban/async delivery)
- `.planning/phases/04-session-management-and-security-baseline/04-CONTEXT.md` — D-01-06 (user_sessions table design), D-13 (throttled activity updates), D-33-43 (rate limiting, Hammer, RateLimit plug, ErrorHandler), D-54-58 (telemetry patterns)
- `.planning/phases/06-multi-factor-authentication/06-CONTEXT.md` — MFA session states, trust cookies, mfa_trust_epoch pattern

### Existing code to extend
- `lib/sigra/plug/fetch_bearer.ex` — FetchBearer plug (extend with JWT auto-detect, opaque token verification, scope assignment)
- `lib/sigra/plug/require_authenticated.ex` — RequireAuthenticated plug (works unchanged — checks current_scope)
- `lib/sigra/plug/rate_limit.ex` — RateLimit plug (reuse for API rate limiting with token-based keys)
- `lib/sigra/plug/require_sudo.ex` — RequireSudo plug (use for API token creation)
- `lib/sigra/auth.ex` — Orchestrator (add API token context functions)
- `lib/sigra/token.ex` — Token operations (JWT refresh tokens use hashed token pattern)
- `lib/sigra/config.ex` — Add api_token: and jwt: config sections
- `lib/sigra/telemetry.ex` — Add API token and JWT event catalog
- `lib/sigra/testing.ex` — Add API token and JWT testing helpers
- `lib/sigra/workers/token_cleanup.ex` — Extend with API token cleanup
- `lib/sigra/error.ex` — Add token_expired, insufficient_scope, mfa_required error types
- `lib/sigra/rate_limiters/hammer.ex` — Reuse for API rate limiting

### Research documents
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — Ecosystem analysis, prior art
- `CLAUDE.md` §Technology Stack — Joken, dependency versions, version compatibility matrix

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Plug.FetchBearer` — Already exists with `token_verifier` option. Extend with JWT auto-detect and opaque token verification.
- `Sigra.Plug.RateLimit` — Full rate limiting plug with per-route config. Reuse for API endpoints.
- `Sigra.Plug.RequireSudo` — Sudo mode plug. Use for API token creation.
- `Sigra.Plug.RequireAuthenticated` — Works unchanged for API auth (checks `current_scope`).
- `Sigra.Plug.ErrorHandler` — Behaviour with content negotiation (JSON for API, flash for browser). Extend with new error types.
- `Sigra.Token` — `generate_hashed_token/0`, `sign/verify`. Use for refresh tokens and API token generation.
- `Sigra.Config` — NimbleOptions validated. Extend with `api_token:` and `jwt:` sections.
- `Sigra.Auth` — Orchestrator. Extend with API token CRUD and JWT functions.
- `Sigra.Telemetry` — span/3, event/3. Extend with API token and JWT event catalog.
- `Sigra.Testing` — Assertion helpers. Extend with API token and JWT helpers.
- `Sigra.Workers.TokenCleanup` — Oban cron. Extend with API token cleanup.

### Established Patterns
- `{:ok, result}` | `{:error, reason}` everywhere (Phase 1 D-19)
- Behaviours for extensibility, default implementations (Phase 1 D-12/13)
- Telemetry span for sync ops, one-shot events for signals (Phase 1 D-15/18)
- NimbleOptions for all config (Phase 1 D-05)
- `Code.ensure_loaded?` for optional deps (Phase 1 D-35)
- Throttled activity updates (Phase 4 D-13)
- Async email delivery via Oban with inline fallback (Phase 3 D-21-27)
- Epoch counter for token invalidation (Phase 6 mfa_trust_epoch)

### Integration Points
- `Sigra.Plug.FetchBearer` gains JWT auto-detect + opaque token verification + scope assignment to `current_scope`
- New `Sigra.Plug.RequireScopes` plug for route-level scope enforcement
- New `Sigra.APIToken` library module (create, verify, revoke, list, can?)
- New `Sigra.JWT` library module (generate_tokens, verify_access, refresh, revoke_refresh) — optional, requires Joken
- New `Sigra.JWT.ClaimsBuilder` behaviour
- New `Sigra.JWT.Signer` for key loading/derivation
- New `Sigra.Ecto.Types.StringList` custom type for MySQL/SQLite scope storage
- Generated `UserAPIToken` Ecto schema
- Generated `APITokenController` (JSON API for token CRUD)
- Generated `TokenController` (JWT auth endpoints — opt-in via --jwt)
- Generated email template: `api_token_created_email/2`
- `token_epoch` column added to users table migration template
- Router: new API routes for token management and JWT auth

</code_context>

<specifics>
## Specific Ideas

- Stripe-style API token prefix: `my_app_sk_7kQ2xP9mR4nB...` — self-documenting, greppable
- FetchBearer auto-detects opaque vs JWT by format — one plug, transparent to API consumers
- User epoch counter pattern (from Auth0/Okta research) — 1 DB read per JWT request, but immediate revocation on account deletion/password change
- Cursor-based pagination from day 1 — learned from Shopify/Slack/GitLab painful offset-to-cursor migrations
- Family-based refresh token reuse detection — Auth0's stolen token detection pattern
- Two-step JWT login with MFA — API clients handle `mfa_required` response same as browser
- `RequireScopes` plug with AND/OR support — Sanctum's CheckAbilities/CheckForAnyAbility pattern

</specifics>

<deferred>
## Deferred Ideas

- Service accounts / machine-to-machine tokens (v2 — add `owner_id` + `owner_type` polymorphic pattern)
- JWKS endpoint for multi-key validation and zero-downtime key rotation (v2)
- Per-token rate limiting quotas (beyond per-route RateLimit plug)
- WebAuthn/passkey as API auth method (v1.x)
- Token usage analytics dashboard
- Automatic token expiry notification emails

</deferred>

---

*Phase: 07-api-authentication*
*Context gathered: 2026-04-08*
