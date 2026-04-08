# Phase 7: API Authentication - Research

**Researched:** 2026-04-08
**Domain:** API token authentication, JWT, bearer auth, scope enforcement
**Confidence:** HIGH

## Summary

Phase 7 adds API authentication to Sigra via two paths: opaque API tokens (default, database-backed) and JWT access tokens (opt-in, stateless). The codebase already has strong foundations to build on: `Sigra.Plug.FetchBearer` exists with a `token_verifier` callback, `Sigra.Token.generate_hashed_token/0` provides the exact random-token-and-hash pattern needed for API keys, `Sigra.Plug.ErrorHandler` behaviour handles content negotiation, and `Sigra.Config` with NimbleOptions is ready for new config sections.

The key implementation challenges are: (1) extending `FetchBearer` to auto-detect opaque vs JWT tokens without breaking the existing interface, (2) implementing the scope permission model with both route-level and inline enforcement, (3) JWT refresh token rotation with family-based reuse detection for stolen token protection, and (4) cursor-based pagination for token listing. Joken 2.6.2 is the right JWT library -- it is actively maintained, supports all required algorithms, and uses a functional API that avoids the macro-heavy patterns CLAUDE.md warns against.

**Primary recommendation:** Build opaque API tokens first (core value, no new dependency), then layer JWT on top as an optional dependency. The `FetchBearer` plug becomes the routing hub that auto-detects token format and delegates to the appropriate verification path.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** App-configurable prefix. Default derived from OTP app name: `{otp_app}_sk_`. Developer overrides via `api_token: [prefix: "myapp_live_"]`.
- **D-02:** No live/test key distinction at the library level. Prefix is for human readability and grep-ability only.
- **D-03:** 32 bytes random via `:crypto.strong_rand_bytes(32)`, URL-safe base64 (43 chars).
- **D-04:** Separate `user_api_tokens` table -- NOT in `user_tokens`. Different lifecycle.
- **D-05:** Single token type (user-scoped). No API key vs PAT distinction.
- **D-06:** Table schema: `id` (binary_id PK), `user_id` (FK), `hashed_token` (binary, unique), `prefix` (string), `name` (string, required, max 255), `scopes` ({:array, :string}), `last_used_at` (utc_datetime_usec), `expires_at` (utc_datetime), `revoked_at` (utc_datetime), `inserted_at` (utc_datetime_usec, no updated_at).
- **D-07:** Module name: `Sigra.APIToken`. Generated schema: `MyApp.Auth.UserAPIToken`.
- **D-08:** Soft delete via `revoked_at` timestamp.
- **D-09:** Throttled `last_used_at` updates (5 min default).
- **D-10:** Raw key shown once on creation. Returns `{:ok, raw_key, token_record}`.
- **D-11:** `revoke_all` sets `revoked_at` on all active tokens.
- **D-12:** API tokens survive password change.
- **D-13:** Expiration is optional. Enforceable via config.
- **D-14:** Extend `TokenCleanup` for revoked API tokens (90 day retention).
- **D-15:** Token names required, not unique, max 255 chars.
- **D-16:** Reuse existing `Sigra.Plug.RateLimit` with API-specific limits.
- **D-17:** `resource:action` colon-separated scopes with canonical registry.
- **D-18:** Explicit grants required. `write` does NOT imply `read` by default.
- **D-19:** Two enforcement layers: `Sigra.Plug.RequireScopes` (route) and `Sigra.APIToken.can?/2` (inline).
- **D-20:** AND logic by default, OR via `match: :any`.
- **D-21:** Session-authenticated users bypass scope checks (implicit full access).
- **D-22:** Scopes as Postgres `text[]`, MySQL/SQLite via `StringList` custom type.
- **D-23:** Scope validation at creation-time only.
- **D-24:** 403 Forbidden with `insufficient_scope` for valid token missing scope.
- **D-25:** Scope registry via runtime config (NimbleOptions).
- **D-26:** Enforce `^[a-z_]+:[a-z_]+$` format for scopes.
- **D-27:** Add `token_scopes`, `auth_method`, `token_id` to `current_scope`.
- **D-28:** Require explicit scopes at creation. No default.
- **D-29:** `list_scopes/0` returns all registered scopes.
- **D-30:** Scopes apply to both opaque and JWT tokens.
- **D-31:** Joken ~> 2.6 as optional dependency.
- **D-32:** HS256 default, key from `secret_key_base` with salt. RS256/ES256 opt-in.
- **D-33:** Refresh tokens are opaque hashed tokens in `user_tokens` (context: "api_refresh"). Rotation on use. Family-based reuse detection.
- **D-34:** Standard JWT claims: `sub`, `iat`, `exp`, `jti`, `iss`, `scopes`, `epoch`.
- **D-35:** Password change revokes JWT refresh tokens. API tokens survive.
- **D-36:** `Sigra.JWT.ClaimsBuilder` behaviour with single `extra_claims/1` callback.
- **D-37:** User epoch check by default. `token_epoch` column. Opt-out via config.
- **D-38:** FetchBearer auto-detects: prefix match -> opaque, `eyJ` -> JWT. Prefix cannot start with `eyJ`.
- **D-39:** No JWT blacklist. Epoch check + short TTL.
- **D-40:** JWT telemetry events defined.
- **D-41:** Generated `TokenController` with JWT endpoints.
- **D-42:** Default TTLs: access 15min, refresh 30 days.
- **D-43:** Any authenticated user can get JWT.
- **D-44:** CORS is developer's responsibility.
- **D-45:** JWT is headless-native.
- **D-46:** JWT rate limiting via RateLimit plug.
- **D-47:** JWT login requires MFA if enrolled. Two-step flow.
- **D-48:** Key rotation: document-only for v1.
- **D-49:** JWT config via NimbleOptions.
- **D-50:** JWT error responses: structured JSON with error codes.
- **D-51:** `Sigra.JWT` module namespace follows concept.ex + concept/ pattern.
- **D-52:** Separate plugs for session vs bearer (no combined plug).
- **D-53:** Both plugs skip if `current_scope` already assigned.
- **D-54:** API pipeline generated only with `--jwt` or `--api` flag.
- **D-55:** Commented-out mixed-mode pipeline example.
- **D-56:** Content negotiation via ErrorHandler behaviour.
- **D-57:** Generated JSON API endpoints for token management.
- **D-58:** Cursor-based pagination, hand-rolled keyset query, opaque Base64 cursors.
- **D-59:** New `api_token:` config section with all specified options.
- **D-60:** API token telemetry events defined.
- **D-61:** Default logger levels for API events.
- **D-62:** Email notification on API token creation only.
- **D-63:** Testing helpers for API tokens and JWT.
- **D-64:** JWT testing helpers.
- **D-65:** `token_epoch` column on users table.
- **D-66:** Multi-database scope storage.

### Claude's Discretion
- Exact Ecto queries for token CRUD operations
- Cursor encoding format (Base64 implementation details)
- Internal module organization within decided namespaces
- Changeset validation implementation details
- Test fixture exact function signatures and default values
- Generated template HTML/CSS styling
- Error message exact wording (within decided error codes)
- NimbleOptions schema validation implementation details
- Sigra.Ecto.Types.StringList internals
- FetchBearer JWT vs opaque detection edge cases
- TokenCleanup batch sizes and scheduling frequency
- RequireScopes plug option parsing internals
- Sigra.JWT.Signer key derivation implementation details
- Refresh token family tracking implementation
- API JSON response envelope structure

### Deferred Ideas (OUT OF SCOPE)
- Service accounts / machine-to-machine tokens (v2)
- JWKS endpoint for multi-key validation (v2)
- Per-token rate limiting quotas
- WebAuthn/passkey as API auth method (v1.x)
- Token usage analytics dashboard
- Automatic token expiry notification emails
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| API-01 | Bearer token authentication via `Authorization: Bearer <token>` header | Existing `Sigra.Plug.FetchBearer` provides the header extraction. Extend with opaque token DB lookup and JWT verification. D-38 defines auto-detection logic. |
| API-02 | API key format with human-readable prefix (`myapp_live_<random>`) | D-01/D-03 lock the format. `Sigra.Token.generate_hashed_token/0` provides the random+hash pattern. Prefix prepended before returning raw key. |
| API-03 | API keys stored as SHA-256 hashes, shown only once at creation | D-06/D-10 lock the storage schema and return format. Existing `Sigra.Token.hash_token/1` provides SHA-256 hashing. |
| API-04 | Personal access tokens with scopes and configurable expiration | D-17-D-30 define the complete scope model. D-13 defines expiration rules. D-06 defines the schema with `scopes` and `expires_at`. |
| API-05 | JWT support for stateless API use cases | D-31-D-51 define JWT fully. Joken 2.6.2 as optional dep. HS256 default, epoch check, refresh token rotation. |
| API-06 | Dual-mode auth plug | D-52-D-56 define separate plugs (not combined). FetchSession in browser, FetchBearer in API pipeline. Both skip if `current_scope` assigned. |
| API-07 | Token lifecycle -- expiry, last-used tracking, revocation, listing | D-08/D-09/D-11/D-13/D-14 define lifecycle. D-58 defines cursor pagination for listing. |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ecto | ~> 3.12 | API token schema, queries, migrations | Already in project. Keyset pagination via `Ecto.Query`. |
| nimble_options | ~> 1.1 | Config validation for `api_token:` and `jwt:` sections | Already in project. Pattern established in `Sigra.Config`. |
| plug | (via phoenix) | FetchBearer, RequireScopes plugs | Already in project. Plug behaviour pattern established. |

### New Dependencies
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| joken | ~> 2.6 (2.6.2 current) | JWT generation and verification | Optional dep. Only loaded when `jwt: [enabled: true]`. [VERIFIED: `mix hex.info joken` returned 2.6.2] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Joken | Raw JOSE | JOSE is lower-level, no claim validation built in. Joken wraps JOSE with Elixir-friendly API. |
| Joken | Guardian | Guardian is macro-heavy, opinionated, low maintenance -- explicitly in CLAUDE.md "What NOT to Use". |
| Hand-rolled cursor pagination | Paginator/Scrivener | Decision D-58 locks hand-rolled keyset. Eliminates dep for a 15-line query. |

**Installation:**
```bash
# In mix.exs deps
{:joken, "~> 2.6", optional: true}
```

## Architecture Patterns

### Recommended Module Structure
```
lib/sigra/
  api_token.ex              # Public API: create, verify, revoke, list, can?, list_scopes
  api_token/
    scope_registry.ex       # Scope validation, registry, format enforcement
  jwt.ex                    # Public API: generate_tokens, verify_access, refresh, revoke_refresh
  jwt/
    claims_builder.ex       # Behaviour: extra_claims/1 callback
    signer.ex               # Key loading, derivation from secret_key_base
    refresh_token.ex        # Refresh token rotation, family tracking, reuse detection
  ecto/
    types/
      string_list.ex        # MySQL/SQLite comma-separated string <-> list
  plug/
    fetch_bearer.ex         # EXTEND: auto-detect opaque vs JWT, scope assignment
    require_scopes.ex       # NEW: route-level scope enforcement
```

### Pattern 1: FetchBearer Auto-Detection (D-38)
**What:** Single plug detects token type by format and delegates to appropriate verifier.
**When to use:** Every API request with `Authorization: Bearer` header.
**Example:**
```elixir
# Source: Decision D-38
def call(conn, opts) do
  if conn.assigns[:current_scope], do: conn, else: do_fetch(conn, opts)
end

defp do_fetch(conn, opts) do
  case extract_bearer_token(conn) do
    {:ok, raw_token} ->
      cond do
        String.starts_with?(raw_token, "eyJ") and jwt_enabled?(opts) ->
          verify_jwt(conn, raw_token, opts)
        true ->
          verify_opaque_token(conn, raw_token, opts)
      end
    :error ->
      Plug.Conn.assign(conn, :current_scope, nil)
  end
end
```

### Pattern 2: Scope Enforcement (D-19/D-20)
**What:** Route-level plug that checks token scopes against required scopes.
**When to use:** Any API route that needs scope restriction.
**Example:**
```elixir
# Source: Decisions D-19, D-20, D-21
defmodule Sigra.Plug.RequireScopes do
  @behaviour Plug

  def call(conn, opts) do
    required = Keyword.fetch!(opts, :scopes)
    match_mode = Keyword.get(opts, :match, :all)
    error_handler = Keyword.fetch!(opts, :error_handler)

    scope = conn.assigns[:current_scope]

    cond do
      # Session users bypass scope checks (D-21)
      scope && scope.auth_method == :session -> conn
      # Wildcard passes all checks
      scope && "*" in scope.token_scopes -> conn
      # Check scopes
      scope && scopes_match?(scope.token_scopes, required, match_mode) -> conn
      # Valid token but wrong scopes -> 403
      scope ->
        conn
        |> error_handler.auth_error(:insufficient_scope, Keyword.put(opts, :required, required))
        |> Plug.Conn.halt()
      # No auth at all -> 401
      true ->
        conn
        |> error_handler.auth_error(:unauthenticated, opts)
        |> Plug.Conn.halt()
    end
  end
end
```

### Pattern 3: Cursor-Based Pagination (D-58)
**What:** Keyset pagination using `(inserted_at, id)` composite cursor.
**When to use:** Token listing endpoints.
**Example:**
```elixir
# Source: Decision D-58
def list_active(user_id, opts \\ []) do
  limit = min(Keyword.get(opts, :limit, 50), 200)
  cursor = Keyword.get(opts, :cursor)

  query =
    from(t in token_schema,
      where: t.user_id == ^user_id,
      where: is_nil(t.revoked_at),
      where: is_nil(t.expires_at) or t.expires_at > ^DateTime.utc_now(),
      order_by: [asc: t.inserted_at, asc: t.id],
      limit: ^(limit + 1)
    )

  query = if cursor, do: apply_cursor(query, decode_cursor(cursor)), else: query
  results = repo.all(query)

  if length(results) > limit do
    tokens = Enum.take(results, limit)
    last = List.last(tokens)
    {tokens, encode_cursor(last.inserted_at, last.id)}
  else
    {results, nil}
  end
end
```

### Pattern 4: Refresh Token Family Reuse Detection (D-33)
**What:** Each refresh token belongs to a family. Rotation creates new token in same family. Reuse of old token revokes entire family.
**When to use:** JWT refresh endpoint.
**Example:**
```elixir
# Source: Decision D-33
# Refresh tokens stored in user_tokens table with context: "api_refresh"
# Additional columns: family_id (binary), superseded_at (utc_datetime)
#
# On refresh:
# 1. Look up token by hash
# 2. If superseded_at is NOT nil -> reuse detected! Revoke entire family.
# 3. If valid: mark current as superseded, create new token in same family
# 4. Return new access JWT + new refresh token
```

### Pattern 5: current_scope Extension (D-27)
**What:** Extend the scope struct shape to include API auth metadata.
**When to use:** All auth paths populate the same shape.
```elixir
# The scope_module.new/1 currently receives %{id: user_id}
# For API auth, extend to include:
# %{
#   id: user_id,
#   token_scopes: ["profile:read", "api_tokens:write"] | nil,
#   auth_method: :session | :api_token | :jwt,
#   token_id: token_id | nil
# }
#
# Session auth: token_scopes=nil, auth_method=:session, token_id=nil
# API token: token_scopes=[...], auth_method=:api_token, token_id=id
# JWT: token_scopes=[...], auth_method=:jwt, token_id=jti
```

### Anti-Patterns to Avoid
- **Combined FetchAny plug:** D-52 explicitly rejects this. Use separate pipelines.
- **JWT refresh tokens as JWT:** D-33 requires opaque refresh tokens. JWT refresh tokens cannot be revoked.
- **Storing raw API tokens:** D-10 requires SHA-256 hash only in DB. Raw shown once.
- **Default scopes on creation:** D-28 requires explicit scopes. Empty = error.
- **Scope validation on every request:** D-23 locks validation to creation-time only. Fast MapSet lookup at verification.
- **Guardian-style use MyApp.Token:** Joken supports `use Joken.Config` but prefer functional API to avoid macro coupling. Use `Joken.Signer.create/2` and `Joken.generate_and_sign/3` directly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT signing/verification | Custom HMAC/RSA implementation | Joken 2.6 (wraps JOSE) | Cryptographic correctness, algorithm support, claim validation |
| SHA-256 token hashing | Custom hash function | Existing `Sigra.Token.hash_token/1` (`:crypto.hash(:sha256, raw)`) | Already verified and tested in codebase |
| Random token generation | Custom RNG | Existing `Sigra.Token.generate_hashed_token/0` | Uses `:crypto.strong_rand_bytes/1`, already in codebase |
| Rate limiting | Custom counter/window | Existing `Sigra.Plug.RateLimit` + Hammer | Already implemented in Phase 4, reuse with API-specific keys |
| Config validation | Manual keyword checking | Existing `Sigra.Config` + NimbleOptions | Pattern established, extend schema |

**Key insight:** The codebase already has most building blocks. Phase 7 is primarily composition and extension, not greenfield. The only truly new dependency is Joken for JWT.

## Common Pitfalls

### Pitfall 1: JWT Prefix Collision
**What goes wrong:** An API token prefix that starts with `eyJ` causes the auto-detect logic to misroute opaque tokens as JWTs.
**Why it happens:** Base64-encoded JSON always starts with `eyJ` (for `{"...`). If a developer configures a prefix like `eyJfoo_`, FetchBearer routes it to JWT verification.
**How to avoid:** Validate prefix at startup (D-38): reject any prefix starting with `eyJ`. Enforce `^[a-z0-9_]+$` regex.
**Warning signs:** Opaque tokens returning "invalid JWT" errors.

### Pitfall 2: Refresh Token Reuse Without Family Tracking
**What goes wrong:** Without family-based tracking, a stolen refresh token can be used indefinitely after the legitimate user refreshes.
**Why it happens:** Simple rotation (invalidate old, create new) only prevents the original token from being used again. If the attacker uses it first, the legitimate user's token fails but the attacker has a valid new token.
**How to avoid:** D-33 requires family-based reuse detection. When a superseded token is presented, revoke the entire family (all tokens sharing the `family_id`). This is the Auth0 pattern.
**Warning signs:** Users reporting "logged out of API" without taking action.

### Pitfall 3: Scope Check Bypass via Nil Scopes
**What goes wrong:** A token with `scopes: nil` or missing scopes field passes scope checks because nil comparison is truthy.
**Why it happens:** Elixir's `nil in list` returns false but `MapSet.subset?(nil, set)` crashes.
**How to avoid:** D-21 defines the rule: `token_scopes = nil` means full access (session auth only). For API tokens, D-28 requires explicit scopes. Guard at creation time, not verification time.
**Warning signs:** API tokens with unexpectedly broad access.

### Pitfall 4: Epoch Check Defeating JWT Statelessness
**What goes wrong:** Every JWT request hits the database to check epoch, negating JWT's stateless benefit.
**Why it happens:** D-37 requires epoch check by default. This is a deliberate tradeoff for security.
**How to avoid:** This is the intended behavior. Document the tradeoff clearly. Provide `jwt: [verify_epoch: false]` opt-out for apps that truly need stateless JWT and accept the stale window risk.
**Warning signs:** High DB load from JWT-heavy API traffic.

### Pitfall 5: Cursor Pagination with Clock Skew
**What goes wrong:** Tokens created in the same microsecond get non-deterministic ordering, causing items to be skipped or duplicated across pages.
**Why it happens:** `inserted_at` alone is not unique. Two tokens created in quick succession may share the same timestamp.
**How to avoid:** D-58 specifies composite cursor `(inserted_at, id)`. The `id` (binary_id / UUID) provides a tiebreaker. Always use both fields in the WHERE clause.
**Warning signs:** Missing tokens in paginated listings, duplicate tokens across pages.

### Pitfall 6: Joken Not Loaded When JWT Disabled
**What goes wrong:** Calling any `Sigra.JWT.*` function when Joken is not in deps causes `UndefinedFunctionError` at runtime.
**Why it happens:** Joken is optional. If not in deps, its modules don't exist.
**How to avoid:** D-31 pattern: use `Code.ensure_loaded?(Joken)` at startup. If `jwt: [enabled: true]` but Joken absent, raise a clear error during `Config.new!/1` validation. Guard all JWT module functions with loaded check.
**Warning signs:** Runtime crashes in production when JWT feature is misconfigured.

## Code Examples

### API Token Creation (D-10)
```elixir
# Source: Existing Sigra.Token pattern + D-01/D-03/D-10
def create(config, user, attrs) do
  Sigra.Telemetry.span([:sigra, :api_token, :create], %{user_id: user.id}, fn ->
    prefix = get_prefix(config)
    {raw_random, hashed} = Sigra.Token.generate_hashed_token()
    raw_key = prefix <> raw_random

    changeset =
      %api_token_schema{}
      |> Ecto.Changeset.cast(attrs, [:name, :scopes, :expires_at])
      |> Ecto.Changeset.validate_required([:name, :scopes])
      |> Ecto.Changeset.validate_length(:name, max: 255)
      |> validate_scopes(config)
      |> validate_expiry(config)
      |> Ecto.Changeset.put_change(:user_id, user.id)
      |> Ecto.Changeset.put_change(:hashed_token, hashed)
      |> Ecto.Changeset.put_change(:prefix, prefix)

    case config.repo.insert(changeset) do
      {:ok, token} -> {:ok, raw_key, token}
      {:error, changeset} -> {:error, changeset}
    end
  end)
end
```

### Token Verification (D-38 opaque path)
```elixir
# Source: Existing Sigra.Token.hash_token/1 + D-06/D-08/D-09
def verify(config, raw_token) do
  Sigra.Telemetry.span([:sigra, :api_token, :verify], %{}, fn ->
    hashed = Sigra.Token.hash_token(raw_token)

    case config.repo.get_by(api_token_schema, hashed_token: hashed) do
      nil -> {:error, :invalid_token}
      token ->
        cond do
          not is_nil(token.revoked_at) -> {:error, :token_revoked}
          expired?(token) -> {:error, :token_expired}
          true ->
            maybe_update_last_used(config, token)
            {:ok, token}
        end
    end
  end)
end
```

### Joken JWT Generation (D-32/D-34)
```elixir
# Source: Joken 2.6 docs [VERIFIED: hexdocs.pm/joken/introduction.html]
def generate_access_token(config, user, scopes) do
  signer = get_signer(config)
  now = DateTime.utc_now() |> DateTime.to_unix()
  ttl = get_in(config.jwt, [:access_ttl]) || 900

  claims = %{
    "sub" => to_string(user.id),
    "iat" => now,
    "exp" => now + ttl,
    "jti" => Ecto.UUID.generate(),
    "iss" => get_in(config.jwt, [:issuer]) || to_string(config.otp_app),
    "scopes" => scopes,
    "epoch" => user.token_epoch || 0
  }

  # Merge custom claims from ClaimsBuilder if configured
  claims = maybe_add_extra_claims(config, user, claims)

  case Joken.encode_and_sign(claims, signer) do
    {:ok, token, _claims} -> {:ok, token}
    {:error, reason} -> {:error, reason}
  end
end

defp get_signer(config) do
  case get_in(config.jwt, [:algorithm]) || "HS256" do
    "HS256" ->
      # Derive key from secret_key_base with Sigra-specific salt
      key = Plug.Crypto.sign(config.secret_key_base, "sigra-jwt-signer", "")
      Joken.Signer.create("HS256", key)
    "RS256" ->
      pem = get_in(config.jwt, [:private_key])
      Joken.Signer.create("RS256", %{"pem" => pem})
    "ES256" ->
      pem = get_in(config.jwt, [:private_key])
      Joken.Signer.create("ES256", %{"pem" => pem})
  end
end
```

### RequireScopes Plug (D-19/D-20)
```elixir
# Source: Decisions D-19, D-20, D-24
defmodule Sigra.Plug.RequireScopes do
  @behaviour Plug

  def init(opts) do
    scopes = Keyword.fetch!(opts, :scopes)
    unless is_list(scopes) and scopes != [], do: raise("scopes must be a non-empty list")
    opts
  end

  def call(conn, opts) do
    required = Keyword.fetch!(opts, :scopes)
    match_mode = Keyword.get(opts, :match, :all)
    error_handler = Keyword.fetch!(opts, :error_handler)
    scope = conn.assigns[:current_scope]

    cond do
      is_nil(scope) ->
        conn |> error_handler.auth_error(:unauthenticated, opts) |> Plug.Conn.halt()

      scope.auth_method == :session ->
        conn  # D-21: session users bypass

      scope.token_scopes && "*" in scope.token_scopes ->
        conn  # Wildcard

      has_required_scopes?(scope.token_scopes, required, match_mode) ->
        conn

      true ->
        opts = Keyword.put(opts, :required_scopes, required)
        opts = Keyword.put(opts, :provided_scopes, scope.token_scopes)
        conn |> error_handler.auth_error(:insufficient_scope, opts) |> Plug.Conn.halt()
    end
  end

  defp has_required_scopes?(token_scopes, required, :all) do
    required_set = MapSet.new(required)
    token_set = MapSet.new(token_scopes || [])
    MapSet.subset?(required_set, token_set)
  end

  defp has_required_scopes?(token_scopes, required, :any) do
    token_set = MapSet.new(token_scopes || [])
    Enum.any?(required, &MapSet.member?(token_set, &1))
  end
end
```

### StringList Custom Ecto Type (D-22/D-66)
```elixir
# Source: Decision D-22 for MySQL/SQLite compatibility
defmodule Sigra.Ecto.Types.StringList do
  use Ecto.Type

  def type, do: :string

  def cast(list) when is_list(list), do: {:ok, list}
  def cast(string) when is_binary(string), do: {:ok, String.split(string, ",")}
  def cast(_), do: :error

  def dump(list) when is_list(list), do: {:ok, Enum.join(list, ",")}
  def dump(_), do: :error

  def load(string) when is_binary(string), do: {:ok, String.split(string, ",")}
  def load(nil), do: {:ok, []}
  def load(_), do: :error
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Guardian for JWT | Joken 2.6 (functional API) | Joken 2.x (2020+) | No macro injection, simpler API, active maintenance |
| Offset pagination | Cursor/keyset pagination | Industry standard since ~2018 | Consistent performance, no skip-ahead attacks |
| JWT refresh tokens as JWT | Opaque refresh + JWT access | Auth0/Okta pattern (2019+) | Refresh tokens are revocable, access tokens are stateless |
| Single rate limit key | Per-token-ID + per-IP rate limiting | Standard practice | Prevents token abuse independent of IP |

**Deprecated/outdated:**
- Guardian: low maintenance, macro-heavy, explicitly in CLAUDE.md "What NOT to Use"
- Ueberauth: Plug-coupled, no PKCE -- not relevant to API auth anyway

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Joken's `Joken.encode_and_sign/2` accepts a plain claims map (not just via `use Joken.Config` module) | Code Examples | Would need to use module-based approach instead; minor refactor |
| A2 | `Plug.Crypto.sign/4` output is deterministic for same inputs (suitable for key derivation from secret_key_base) | Code Examples (HS256 signer) | Would need alternative key derivation; use `:crypto.mac/4` with HMAC-SHA256 directly instead |
| A3 | Joken.Signer.create("RS256", %{"pem" => pem}) accepts PEM string for RSA keys | Code Examples | May need `JOSE.JWK.from_pem/1` conversion step |

## Open Questions

1. **Joken functional API vs module-based API**
   - What we know: Joken supports both `use Joken.Config` (module macros) and direct functional calls via `Joken.generate_and_sign/3`
   - What's unclear: Whether the functional API provides the same claim validation hooks
   - Recommendation: Use functional API to avoid macros (CLAUDE.md constraint). Validate claims manually before signing and after verification.

2. **HS256 key derivation from secret_key_base**
   - What we know: D-32 says "key derived from app's secret_key_base with Sigra-specific salt"
   - What's unclear: Exact derivation method (HKDF, HMAC, Plug.Crypto.sign?)
   - Recommendation: Use `:crypto.mac(:hmac, :sha256, secret_key_base, "sigra-jwt-signing-key")` to derive a 256-bit key. Simple, deterministic, standard HMAC-based key derivation. [ASSUMED]

3. **Refresh token family_id storage**
   - What we know: D-33 requires family-based reuse detection. Refresh tokens go in `user_tokens` table.
   - What's unclear: Whether `user_tokens` table already has a `family_id` column or needs migration
   - Recommendation: Add `family_id` (binary_id) and `superseded_at` (utc_datetime) columns to `user_tokens` migration. These are JWT-specific and only populated for `context: "api_refresh"` tokens.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/sigra/api_token_test.exs --seed 0` |
| Full suite command | `mix test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| API-01 | Bearer token auth via header | unit | `mix test test/sigra/plug/fetch_bearer_test.exs -x` | Exists (extend) |
| API-02 | API key prefix format | unit | `mix test test/sigra/api_token_test.exs -x` | Wave 0 |
| API-03 | SHA-256 hash storage, show-once | unit | `mix test test/sigra/api_token_test.exs -x` | Wave 0 |
| API-04 | Scoped tokens with expiration | unit | `mix test test/sigra/api_token_test.exs -x` | Wave 0 |
| API-05 | JWT generate/verify/refresh | unit | `mix test test/sigra/jwt_test.exs -x` | Wave 0 |
| API-06 | Dual-mode auth (separate plugs) | unit | `mix test test/sigra/plug/fetch_bearer_test.exs -x` | Exists (extend) |
| API-07 | Token lifecycle (revoke, list, expire) | unit | `mix test test/sigra/api_token_test.exs -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/api_token_test.exs test/sigra/jwt_test.exs test/sigra/plug/fetch_bearer_test.exs --seed 0`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/api_token_test.exs` -- covers API-02, API-03, API-04, API-07
- [ ] `test/sigra/api_token/scope_registry_test.exs` -- covers scope validation (D-17, D-26)
- [ ] `test/sigra/jwt_test.exs` -- covers API-05
- [ ] `test/sigra/jwt/refresh_token_test.exs` -- covers refresh rotation, reuse detection (D-33)
- [ ] `test/sigra/plug/require_scopes_test.exs` -- covers scope enforcement (D-19, D-20)
- [ ] `test/sigra/ecto/types/string_list_test.exs` -- covers D-22/D-66
- [ ] Joken dep added to mix.exs: `{:joken, "~> 2.6", optional: true}`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Bearer token verification, JWT signature check, epoch validation |
| V3 Session Management | yes | Refresh token rotation, family-based reuse detection, revocation |
| V4 Access Control | yes | Scope enforcement via RequireScopes plug, AND/OR logic |
| V5 Input Validation | yes | Scope format regex `^[a-z_]+:[a-z_]+$`, token name length, NimbleOptions |
| V6 Cryptography | yes | SHA-256 token hashing, HS256/RS256/ES256 JWT signing via Joken (wraps JOSE) |

### Known Threat Patterns for API Auth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stolen API token | Information Disclosure | SHA-256 hash storage, show-once, revocation capability |
| Stolen refresh token | Elevation of Privilege | Family-based reuse detection (D-33), revoke entire family |
| JWT forgery | Spoofing | Cryptographic signature verification via Joken/JOSE |
| Stale JWT after account deletion | Spoofing | Epoch check on every request (D-37) |
| Scope escalation | Elevation of Privilege | Creation-time validation, no runtime scope modification, explicit grants |
| Token enumeration via timing | Information Disclosure | Constant-time hash comparison via `Plug.Crypto.secure_compare/2` |
| API token prefix collision with JWT | Spoofing | Startup validation: prefix cannot start with `eyJ` (D-38) |
| Rate limit bypass via token rotation | Denial of Service | Rate limit by token ID, not just IP (D-16) |

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/sigra/plug/fetch_bearer.ex` -- existing FetchBearer implementation
- Codebase: `lib/sigra/token.ex` -- existing token generation/hashing
- Codebase: `lib/sigra/config.ex` -- existing NimbleOptions config pattern
- Codebase: `lib/sigra/telemetry.ex` -- existing telemetry pattern
- Codebase: `lib/sigra/error.ex` -- existing error types
- Codebase: `lib/sigra/testing.ex` -- existing test helpers
- Codebase: `lib/sigra/workers/token_cleanup.ex` -- existing cleanup worker
- Codebase: `lib/sigra/plug/error_handler.ex` -- existing error handler behaviour
- Codebase: `mix.exs` -- current dependency list

### Secondary (MEDIUM confidence)
- [Joken 2.6.2 docs](https://hexdocs.pm/joken/introduction.html) -- JWT API, signer creation, claim validation [VERIFIED: WebFetch]
- [Joken hex.info](https://hex.pm/packages/joken) -- version 2.6.2 confirmed [VERIFIED: `mix hex.info joken`]

### Tertiary (LOW confidence)
- Joken functional API claim map usage (A1 in Assumptions Log) -- needs validation during implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Joken version verified, all other deps already in project
- Architecture: HIGH -- extending established codebase patterns with locked decisions
- Pitfalls: HIGH -- well-known API auth patterns, Auth0/Okta prior art

**Research date:** 2026-04-08
**Valid until:** 2026-05-08 (stable domain, locked decisions)
