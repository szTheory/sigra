# Phase 7: API Authentication - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 07-api-authentication
**Areas discussed:** API key format & prefix, Scope & permissions model, JWT implementation, Dual-mode auth plug, API token expiration, Token listing pagination, Token creation auth, Token naming, Token cleanup, Prefix collision, Multi-database, Config surface, Testing helpers, Email notifications, Audit events, Claude's discretion

---

## API Key Format & Prefix

| Option | Description | Selected |
|--------|-------------|----------|
| App-configurable prefix | Default from OTP app name, developer overrides | ✓ |
| Fixed library prefix | Always `sigra_sk_` | |
| No prefix | Plain random token | |

**User's choice:** App-configurable prefix (`{otp_app}_sk_` default)

| Option | Description | Selected |
|--------|-------------|----------|
| No live/test — env via config | Prefix for readability only, env via Mix config | ✓ |
| Built-in live/test modes | Stripe-style enforcement | |

**User's choice:** No live/test distinction. Research showed no auth library implements this — it's an API platform pattern only.

| Option | Description | Selected |
|--------|-------------|----------|
| 32 bytes, URL-safe base64 | 256 bits entropy, 43 chars | ✓ |
| 24 bytes, shorter keys | 192 bits, ~32 chars | |

**User's choice:** 32 bytes, consistent with Phase 2 session tokens.

| Option | Description | Selected |
|--------|-------------|----------|
| Single type, separate table | One `user_api_tokens` table | ✓ |
| Single type, reuse user_tokens | Add to existing table | |
| Two types: API key + PAT | Separate concepts | |

**User's choice:** Single type, separate table. Research showed GitHub/GitLab/Sanctum/Stripe all converge on one token table with column-level differentiation.

| Option | Description | Selected |
|--------|-------------|----------|
| Soft delete via revoked_at | Timestamp, audit trail preserved | ✓ |
| Hard delete | Row deleted on revocation | |

| Option | Description | Selected |
|--------|-------------|----------|
| Throttled last_used_at updates | Write only if >5min since last | ✓ |
| Every request | Always update | |

| Option | Description | Selected |
|--------|-------------|----------|
| Show once on creation | {:ok, raw_key, token_record} | ✓ |
| Separate reveal step | Click to reveal | |

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, revoke_all function | Sets revoked_at on all | ✓ |
| Individual only | One at a time | |

| Option | Description | Selected |
|--------|-------------|----------|
| API tokens survive password change | Consistent with GitHub/GitLab | ✓ |
| Revoke everything | Breaks CI/CD silently | |

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing RateLimit plug | Same plug, API-specific limits | ✓ |
| Dedicated API rate limiter | Separate module | |

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra.APIToken | Matches "token" terminology | ✓ |
| Sigra.APIKey | Stripe-style naming | |

---

## Scope & Permissions Model

| Option | Description | Selected |
|--------|-------------|----------|
| resource:action with registry | Colon-separated, validated, extensible | ✓ |
| Freeform strings | Any string, no validation | |

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit grants, opt-in hierarchy | write does NOT imply read by default | ✓ |
| Write always implies read | Stripe/GitLab pattern | |

**Notes:** Research showed AWS IAM, Microsoft Graph, Sanctum require explicit grants. OWASP classifies implicit scope expansion as privilege escalation. Opt-in `write_implies_read: true` config available.

| Option | Description | Selected |
|--------|-------------|----------|
| AND by default, OR via option | Token must have ALL scopes | ✓ |
| OR by default | Token needs at least ONE | |

**Notes:** Research showed Sanctum/Django use AND default. GitHub/Google use OR because scopes represent resource areas, not capabilities. Sigra's `resource:action` model = capabilities = AND is correct.

| Option | Description | Selected |
|--------|-------------|----------|
| Plug + context function | RequireScopes plug + can?/2 | ✓ |
| Plug only | Route-level enforcement only | |

| Option | Description | Selected |
|--------|-------------|----------|
| Session users have full access | token_scopes = nil = bypass | ✓ |
| Session users have scopes too | Uniform enforcement | |

| Option | Description | Selected |
|--------|-------------|----------|
| Postgres text array | {:array, :string}, MySQL/SQLite via custom type | ✓ |
| JSONB column | More flexible but overkill | |

| Option | Description | Selected |
|--------|-------------|----------|
| Creation-time validation only | Fast MapSet at verify time | ✓ |
| Both creation and verification | Registry lookup per request | |

| Option | Description | Selected |
|--------|-------------|----------|
| 403 with scope info | Distinct from 401, includes required/provided | ✓ |
| 401 for everything | Simpler but unhelpful | |

| Option | Description | Selected |
|--------|-------------|----------|
| Runtime config via NimbleOptions | Custom scopes in config.exs | ✓ |
| Compile-time module attribute | Requires recompilation | |

| Option | Description | Selected |
|--------|-------------|----------|
| Enforce resource:action format | ^[a-z_]+:[a-z_]+$ regex | ✓ |
| Freeform within registry | Any string if registered | |

| Option | Description | Selected |
|--------|-------------|----------|
| On current_scope struct | token_scopes, auth_method, token_id | ✓ |
| Separate assigns | conn.assigns.current_token | |

| Option | Description | Selected |
|--------|-------------|----------|
| Require explicit scopes | No default, must specify | ✓ |
| Default to wildcard * | Full access if omitted | |

| Option | Description | Selected |
|--------|-------------|----------|
| list_scopes/0 helper | Returns all registered scopes | ✓ |
| Developer reads config | No helper | |

| Option | Description | Selected |
|--------|-------------|----------|
| Scopes on both JWT and API tokens | Same RequireScopes plug works | ✓ |
| API tokens only | JWT unscoped | |

---

## JWT Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Joken ~> 2.6, optional dep | Only credible Elixir JWT library | ✓ |
| Raw JOSE | More verbose | |
| Roll from :crypto | Zero deps but edge cases | |

**Notes:** Research confirmed no new JWT libraries emerged in 2025-2026. Joken is in maintenance mode but not deprecated. 54M+ downloads.

| Option | Description | Selected |
|--------|-------------|----------|
| HS256 from secret_key_base | Zero config, RS256/ES256 opt-in | ✓ |
| RS256 asymmetric default | Requires key generation | |

| Option | Description | Selected |
|--------|-------------|----------|
| Opaque refresh in user_tokens | DB-backed, rotated, revocable | ✓ |
| JWT refresh tokens | Needs blacklist = stateful anyway | |
| No refresh tokens | Poor UX for mobile/SPA | |

**Notes:** Deep research showed "stateless refresh token is a contradiction" — every serious IdP (Auth0, Okta, Passport) uses opaque refresh tokens. Django SimpleJWT's JWT refresh is widely criticized. The key insight: if you need revocation (and you MUST), you need state — so use the simplest stateful format (opaque hash).

| Option | Description | Selected |
|--------|-------------|----------|
| Epoch check by default | 1 DB read/request, immediate revocation | ✓ |
| Pure stateless, no epoch | Trust claims, 15min stale window | |

**Notes:** Initially recommended pure stateless, then research on account deletion security changed the recommendation. Auth0/Firebase/Cognito accept the stale window, but the user epoch pattern costs only 1 DB read and provides immediate revocation for all scenarios. Opt-out available for high-throughput APIs.

| Option | Description | Selected |
|--------|-------------|----------|
| Standard + scopes claims | sub, iat, exp, jti, iss, scopes, epoch | ✓ |
| Minimal (sub + exp only) | Less out-of-the-box | |

| Option | Description | Selected |
|--------|-------------|----------|
| ClaimsBuilder behaviour | extra_claims/1 callback | ✓ |
| Pure config, no behaviour | Function reference in config | |

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, revoke refresh on password change | Access JWTs expire naturally | ✓ |
| JWT tokens survive like API tokens | Worse security for JWT | |

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect token type | Prefix = opaque, eyJ = JWT | ✓ |
| Separate plugs per token type | More explicit | |

| Option | Description | Selected |
|--------|-------------|----------|
| No blacklist, expiry-only | Epoch check handles edge cases | ✓ |
| Optional blacklist table | Instant JWT revocation | |

| Option | Description | Selected |
|--------|-------------|----------|
| Generate JWT controller | --jwt flag on mix sigra.install | ✓ |
| Library functions only | Host wires own controllers | |

| Option | Description | Selected |
|--------|-------------|----------|
| 15 minutes access TTL | Industry standard, configurable | ✓ |
| 1 hour | More forgiving but riskier | |

| Option | Description | Selected |
|--------|-------------|----------|
| Any auth user can get JWT | Session cookie accepted at token endpoint | ✓ |
| Password/magic link only | OAuth users locked out | |

| Option | Description | Selected |
|--------|-------------|----------|
| No CORS — developer's responsibility | Document corsica/cors_plug | ✓ |
| Ship a CORS plug | Conflicts with existing setup | |

**Notes:** Research showed no auth library in any language ships CORS. It's a transport concern, not auth.

| Option | Description | Selected |
|--------|-------------|----------|
| JWT is headless-native | --no-live --jwt = API-only auth | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Compile-time error if Joken absent | Hard error with clear dep instruction | ✓ |
| Warning + disable silently | Confusing | |

| Option | Description | Selected |
|--------|-------------|----------|
| Consistent telemetry spans | [:sigra, :jwt, :*] pattern | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse RateLimit plug for JWT | 5/min/IP for create, 30/min for refresh | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Always require MFA for JWT login | No trust cookie for API | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Document-only key rotation for v1 | JWKS + multi-key in v2 | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| New jwt: section in Sigra config | NimbleOptions validated | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Structured JSON error codes | token_expired, invalid_token, etc. | ✓ |
| Generic 401 for all | Harder to debug | |

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra.JWT + Sigra.JWT/* | concept.ex + concept/ pattern | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| token_epoch on users table | Next to mfa_trust_epoch | ✓ |
| Separate security_state table | Breaks existing pattern | |

**Notes:** Research confirmed Sigra uses a single users table (not split users/accounts). Security state (failed_login_attempts, locked_at, mfa_trust_epoch) all lives on users. token_epoch follows the same pattern.

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive JWT test helpers | generate_jwt, expired_jwt, jwt_with_scopes, put_bearer_token | ✓ |
| Minimal | Just generate_jwt | |

---

## Dual-Mode Auth Plug

| Option | Description | Selected |
|--------|-------------|----------|
| Separate plugs, document composition | FetchSession + FetchBearer in separate pipelines | ✓ |
| Combined FetchAny plug | Sanctum-style auto-detect | |

**Notes:** Research showed Phoenix-idiomatic pattern is two pipelines. Every Phoenix auth library uses separate plugs.

| Option | Description | Selected |
|--------|-------------|----------|
| Skip if current_scope assigned | First plug wins, no wasted lookup | ✓ |
| Always run, last one wins | More predictable but wasteful | |

| Option | Description | Selected |
|--------|-------------|----------|
| API pipeline with --jwt/--api flag | Default = browser only | ✓ |
| Always generate both | Clutters browser-only apps | |

| Option | Description | Selected |
|--------|-------------|----------|
| Commented example in generated router | api_or_browser pipeline recipe | ✓ |
| Docs only | No code in generated files | |

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse ErrorHandler behaviour | JSON for API, flash for browser | ✓ |
| Separate API error handler | Duplicates logic | |

| Option | Description | Selected |
|--------|-------------|----------|
| JSON API for token CRUD | GET/POST/DELETE /api/tokens | ✓ |
| Browser UI only | Locks out headless/CLI | |

| Option | Description | Selected |
|--------|-------------|----------|
| Consistent API token telemetry | [:sigra, :api_token, :*] | ✓ |

---

## Additional Areas

| Option | Description | Selected |
|--------|-------------|----------|
| Optional expiry, no default | Lives until revoked unless configured | ✓ |
| Required, 90-day default | Breaks long-lived CI tokens | |

| Option | Description | Selected |
|--------|-------------|----------|
| Cursor-based pagination | Keyset query, Base64 cursors, no library dep | ✓ |
| Limit/offset | Always ends up needing cursor | |

**Notes:** Research validated user's experience. Stripe/Slack/Shopify/GitLab all migrated from offset to cursor. Security argument: offset skips tokens silently during revocation audit.

| Option | Description | Selected |
|--------|-------------|----------|
| Require sudo for token creation | Sensitive operation | ✓ |
| Regular auth only | Stolen session can mint tokens | |

| Option | Description | Selected |
|--------|-------------|----------|
| Not unique, required, max 255 | Duplicate names allowed | ✓ |
| Unique per user | Adds friction | |

| Option | Description | Selected |
|--------|-------------|----------|
| Extend TokenCleanup worker | Revoked tokens > 90 days, configurable | ✓ |
| No cleanup | Table grows unbounded | |

| Option | Description | Selected |
|--------|-------------|----------|
| Validate prefix at startup | Reject eyJ*, empty, non-lowercase | ✓ |
| No validation | Trust developer | |

| Option | Description | Selected |
|--------|-------------|----------|
| Custom Ecto type for multi-DB | StringList for MySQL/SQLite | ✓ |
| Postgres-only for v1 | Less portable | |

| Option | Description | Selected |
|--------|-------------|----------|
| New api_token: config section | NimbleOptions, all settings in one place | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive test helpers | create_api_token, fixtures, assertions | ✓ |
| Minimal | Just create_api_token | |

| Option | Description | Selected |
|--------|-------------|----------|
| Notify on token creation only | Email with name, scopes, IP | ✓ |
| No notifications | Less awareness | |

| Option | Description | Selected |
|--------|-------------|----------|
| All CRUD via telemetry | Phase 9 subscribes to events | ✓ |

---

## Claude's Discretion

Areas where Claude has flexibility during planning: exact Ecto queries, cursor encoding, internal module organization, changeset validation, test fixture signatures, generated template styling, error message wording, NimbleOptions validation details, StringList type internals, FetchBearer edge cases, TokenCleanup scheduling, RequireScopes internals, JWT Signer key derivation, refresh token family tracking, API response envelope structure.

## Deferred Ideas

- Service accounts / machine-to-machine tokens (v2)
- JWKS endpoint for zero-downtime key rotation (v2)
- Per-token rate limiting quotas
- WebAuthn as API auth method (v1.x)
- Token usage analytics dashboard
- Automatic token expiry notification emails
