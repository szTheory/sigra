# Phase 5: OAuth and Social Login - Research

**Researched:** 2026-04-08
**Domain:** OAuth 2.0 / OIDC integration via Assent, encrypted token storage, account linking
**Confidence:** HIGH

## Summary

Phase 5 adds OAuth/social login to Sigra using Assent as the OAuth/OIDC engine, wrapped by thin Sigra strategy modules. The phase generates an incremental `mix sigra.gen.oauth` generator that produces a `UserIdentity` schema, Vault + encrypted types (via cloak_ecto), an OAuth controller, templates with dynamic provider buttons, and a separate migration. The core library adds `Sigra.OAuth` (orchestrator), `Sigra.OAuth.Callback` (response processing), `Sigra.OAuth.Strategies.*` (per-provider wrappers), and `Sigra.Identity` (library struct).

The primary technical complexity lies in (1) Assent's two-phase authorize/callback flow with session-stored state and PKCE params, (2) the account linking confirmation flow when an OAuth email matches an existing user, (3) cloak_ecto integration for encrypted token storage, and (4) provider-specific differences (Apple's private key auth, Facebook's unverified emails, GitHub's separate email endpoint).

**Primary recommendation:** Build the OAuth module tree layer-by-layer: Assent strategy wrappers first, then the Identity struct/persistence, then the orchestrator flows (register, login, link, unlink), then the generator and templates last.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Email-match linking always requires confirmation. When OAuth callback email matches an existing account, user must log in with their existing credentials to link the provider. No auto-linking. Prevents account takeover.
- **D-02:** Unconfirmed accounts treated the same as confirmed for linking -- same confirmation flow required. The unconfirmed account still owns that email.
- **D-03:** Block unlink of last provider until password is set. Show "Set a password first to keep access to your account." Prevents account lockout.
- **D-04:** One identity per provider per user. Unique constraint on (user_id, provider). User picks which account to link.
- **D-05:** Linking and unlinking both require sudo mode. Consistent security posture for all identity-affecting operations. Phase 4 sudo infrastructure reused.
- **D-06:** OAuth-only users (no password) confirm link requests by re-authenticating via their existing provider. Redirect to already-linked provider for re-auth.
- **D-07:** Notification emails on both link AND unlink. "Google was linked/removed from your account. Not you? Secure your account." Full audit trail via email. Uses Phase 3 email infrastructure.
- **D-08:** Provider returns no email: fail with clear error "We need your email to create an account. Please grant email permission and try again." Never create a user without email.
- **D-09:** If provider_uid maps to identity A but returned email matches user B: block login with generic error "Could not complete sign in." Log at :error level. Never auto-merge accounts.
- **D-10:** Providers configured in config.exs as keyword list under `oauth: [providers: [...]]`. Runtime config via runtime.exs for secrets. Familiar Phoenix pattern.
- **D-11:** Thin wrapper per provider: `Sigra.OAuth.Strategies.Google` wraps `Assent.Strategy.Google`. Normalizes response, handles Sigra-specific concerns.
- **D-12:** Same code for all tiers, different docs. Tier 1 (Google, GitHub) gets quick-start docs. Tier 2 (Apple, Meta) gets extended setup docs.
- **D-13:** Named wrappers for tier 1-2 + generic fallback. Any Assent strategy works via `providers: [discord: [strategy: Assent.Strategy.Discord, ...]]`.
- **D-14:** Assent is an optional dependency with `Code.ensure_loaded?` gate. Same pattern as Hammer/Oban/bcrypt.
- **D-15:** Runtime validation with startup check. NimbleOptions validates provider config structure at app startup.
- **D-16:** Sigra owns OAuth state (CSRF): generates HMAC-signed state param, stores in session, verifies on callback before delegating token exchange to Assent.
- **D-17:** PKCE (S256) enabled by default for all providers where Assent supports it.
- **D-18:** OIDC discovery when available. For OIDC-capable providers (Google, Apple), use Assent's OIDC strategy with auto-discovery.
- **D-19:** OAuth routes are controller-only. Standard controller handles `/auth/:provider` and `/auth/:provider/callback`.
- **D-20:** Module structure split by concern: `Sigra.OAuth` (orchestrator), `Sigra.OAuth.Callback` (response processing), `Sigra.OAuth.Strategies.*` (per-provider wrappers).
- **D-21:** Configurable scopes per provider: `google: [scopes: ["email", "profile"]]`. Sensible defaults per provider.
- **D-22:** Encrypted token storage via cloak_ecto with AES-256-GCM.
- **D-23:** cloak_ecto is a required dependency for OAuth. If you use `mix sigra.gen.oauth`, cloak_ecto must be installed.
- **D-24:** Vault generated into host app: minimal `MyApp.Vault` module (~10 lines) + `MyApp.Encrypted.Binary` Ecto type.
- **D-25:** Full identity record columns: id, user_id, provider (string, normalized lowercase), provider_uid (string), encrypted_access_token, encrypted_refresh_token, token_expires_at, provider_email, provider_name, provider_avatar_url, metadata (JSONB), last_used_at, inserted_at, updated_at.
- **D-26:** Two unique indexes: (user_id, provider) and (provider, provider_uid).
- **D-27:** Auto-refresh tokens on access via `Sigra.OAuth.get_tokens/2`.
- **D-28:** Library struct `Sigra.Identity` with `from_schema/1` and `to_params/1` mapping.
- **D-29:** No IdentityStore behaviour. Ecto-only. Library functions take repo + schema module directly.
- **D-30:** Provider column is regular string, normalized to lowercase in code.
- **D-31:** Update identity on every OAuth login.
- **D-32:** Match identities by (provider, provider_uid), never by email alone.
- **D-33:** Metadata column stores normalized subset of useful fields.
- **D-34:** Track last_used_at on identity, throttled writes.
- **D-35:** Separate migration generated by `mix sigra.gen.oauth`.
- **D-36:** OAuth buttons above password form with "or" divider.
- **D-37:** Dynamic button rendering from configured providers list.
- **D-38:** Inline SVG icons for tier 1-2 providers following brand guidelines.
- **D-39:** Callback errors: redirect to login with generic flash.
- **D-40:** CSRF state mismatch: redirect to login with "Authentication expired. Please try again."
- **D-41:** Account linking confirmation UX: redirect to login page with banner. Link intent stored in Plug session with prefixed keys, 15-minute TTL.
- **D-42:** OAuth registration auto-confirms email since provider verified it. `confirmed_at = now()`.
- **D-43:** OAuth login creates remember-me sessions by default. Configurable via `:session_type`.
- **D-44:** return_to support via session storage before OAuth redirect.
- **D-45:** Post-OAuth hooks via telemetry only.
- **D-46:** Route namespace: `/auth/:provider` and `/auth/:provider/callback`.
- **D-47:** Session state during redirect stored with prefixed keys: `sigra_oauth_state`, `sigra_oauth_link_intent`, `sigra_oauth_return_to`.
- **D-48:** Session metadata includes `auth_method: :oauth` and `provider: :google`.
- **D-49:** Provider unavailable: no retry, clear error + "Try again" link.
- **D-50:** Already-authenticated user clicking OAuth button: treat as link attempt. Requires sudo.
- **D-51:** Settings page: both LiveView and controller HTML variants. `--live` flag on generator.
- **D-52:** OAuth-only users see "No password set" hint in settings.
- **D-53:** Unlink confirmation shows remaining auth methods.
- **D-54:** `Sigra.Error.OAuthError` struct with provider, error_code fields.
- **D-55:** Generic user-facing messages with detailed internal logging.
- **D-56:** No special cooldown on OAuth initiation. IP rate limiting covers it.
- **D-57:** Incremental generator: `mix sigra.gen.oauth`.
- **D-58:** Full file set: migration, UserIdentity, Vault, OAuth controller, templates, route injection, config injection, test fixtures. ~8-10 files.
- **D-59:** Generator is idempotent. Detects existing files and injections.
- **D-60:** Optional provider args: `mix sigra.gen.oauth --providers google github`.
- **D-61:** OAuth-specific telemetry events.
- **D-62:** New `oauth:` section in Sigra.Config. NimbleOptions validated.
- **D-63:** Kill switch: `oauth: [enabled: false]`.
- **D-64:** New Sigra.Testing helpers: `mock_oauth_callback/2`, `create_identity/2`, `oauth_user_fixture/1`.
- **D-65:** PostgreSQL primary with adapter detection. JSONB for metadata on PostgreSQL, TEXT with JSON serialization for MySQL/SQLite.
- **D-66:** OAuth login with MFA enabled: user enters mfa_pending state.
- **D-67:** Ensure OAuth session creation goes through same code path as password login.

### Claude's Discretion
- Exact Assent API surface used in strategy wrappers
- OAuth state HMAC implementation details (key derivation, format)
- SVG icon markup and brand guideline compliance
- Session cleanup for stale link intents
- Exact NimbleOptions schema for per-provider config validation
- Controller template structure and naming
- Test mock implementation details for Assent HTTP layer

### Deferred Ideas (OUT OF SCOPE)
- Headless/API OAuth for SPA/mobile clients (Phase 7)
- MFA session states on OAuth login (Phase 6)
- OAuth re-authentication for sudo mode on OAuth-only accounts
- Email change with re-verification (Phase 8)
- SAML/enterprise SSO (out of scope for v1)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OAUTH-01 | OAuth integration via Assent with PKCE and OIDC support | Assent API research: `authorize_url/1` returns `{:ok, %{url: url, session_params: %{state: ..., code_verifier: ...}}}`, PKCE via `:code_verifier` option, OIDC via `Assent.Strategy.OIDC` with `.well-known` discovery |
| OAUTH-02 | Google and GitHub as tier 1 providers (working in under 10 minutes) | Assent.Strategy.Google (OIDC) and Assent.Strategy.Github documented; minimal config: client_id, client_secret, redirect_uri. GitHub needs `:user_emails_url` for email |
| OAUTH-03 | Apple and Meta as tier 2 providers | Apple needs team_id, private_key_id, private_key; Facebook returns unverified email (trust_provider_email must account for this) |
| OAUTH-04 | Account linking -- existing user links OAuth provider from settings | Requires sudo mode (Phase 4 reuse), D-05/D-50 define the flow |
| OAUTH-05 | Email-match account linking with configurable behavior | D-01 locks to "always require confirmation"; link intent stored in session with 15-min TTL (D-41) |
| OAUTH-06 | Multiple OAuth providers per user (user_identities table) | Identity struct + UserIdentity schema with two unique indexes (D-26) |
| OAUTH-07 | OAuth token storage (encrypted access + refresh tokens) | cloak_ecto integration: Vault + Encrypted.Binary generated into host app (D-22/D-24) |
| OAUTH-08 | Graceful handling of edge cases | OAuthError struct with error_code atoms (D-54), generic messages (D-55), specific handling for no-email (D-08), uid/email conflict (D-09) |
</phase_requirements>

## Standard Stack

### Core (Phase 5 additions)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| assent | ~> 0.3.1 | OAuth 2.0 / OIDC engine | 23 built-in provider strategies, PKCE support, framework-agnostic, OIDC native. Maintained by Dan Schultzer. [VERIFIED: hexdocs.pm/assent v0.3.1] |
| cloak_ecto | ~> 1.3.0 | Transparent Ecto field encryption | AES-256-GCM encryption at rest for OAuth tokens. Vault + custom type pattern. Last updated Apr 2024 -- stable. [VERIFIED: hex.pm/packages/cloak_ecto] |
| cloak | ~> 1.1 | Encryption primitives (cloak_ecto dep) | Required by cloak_ecto. Provides Vault GenServer for key management. [ASSUMED] |

### Already Present (reused from prior phases)
| Library | Purpose in Phase 5 |
|---------|---------------------|
| nimble_options | NimbleOptions schema for `oauth:` config section |
| swoosh | Provider linked/unlinked notification emails |
| oban | Async email delivery for link/unlink notifications |
| hammer | IP rate limiting on `/auth/:provider` routes |
| plug_crypto | HMAC-signed OAuth state parameter (already used by Sigra.Token) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| assent | ueberauth | Ueberauth has more community strategies but requires separate packages per provider, is Plug-coupled, and lacks PKCE/OIDC natively. Assent is the locked decision. |
| cloak_ecto | raw :crypto | Could use Erlang's :crypto directly for 2 encrypted fields, but cloak_ecto provides key rotation, Vault supervision, and Ecto type integration. Worth the dep for OAuth. |
| Sigra-owned CSRF state | Assent session_params state | Assent generates `:state` in session_params. D-16 says Sigra owns the state with HMAC signing for consistency. Override Assent's state with Sigra.Token.generate/4. |

**Installation (mix.exs additions):**
```elixir
{:assent, "~> 0.3", optional: true},
{:cloak_ecto, "~> 1.3", optional: true},
```
Both are optional deps -- only required when `mix sigra.gen.oauth` is run. [VERIFIED: pattern matches existing optional deps in mix.exs]

## Architecture Patterns

### New Module Structure
```
lib/sigra/
├── oauth.ex                      # Orchestrator: register_oauth/4, login_oauth/4, link/4, unlink/4
├── oauth/
│   ├── callback.ex               # Response processing: process_callback/3, extract_user_info/2
│   └── strategies/
│       ├── google.ex             # Wraps Assent.Strategy.Google
│       ├── github.ex             # Wraps Assent.Strategy.Github
│       ├── apple.ex              # Wraps Assent.Strategy.Apple
│       ├── facebook.ex           # Wraps Assent.Strategy.Facebook
│       └── generic.ex            # Fallback: delegates directly to any Assent strategy
├── identity.ex                   # Library struct: Sigra.Identity
├── error.ex                      # Extended with OAuthError (add to existing file)
├── config.ex                     # Extended with oauth: section (add to existing file)
├── telemetry.ex                  # Extended with OAuth events (add to existing file)
└── testing.ex                    # Extended with OAuth test helpers (add to existing file)

priv/templates/sigra.gen.oauth/
├── user_identity.ex              # Generated Ecto schema
├── vault.ex                      # Generated cloak Vault
├── encrypted_binary.ex           # Generated Ecto type
├── oauth_migration.exs           # Separate migration
├── oauth_controller.ex           # Controller for /auth/:provider
├── oauth_html.ex                 # HTML component module
├── oauth_buttons.html.heex       # OAuth button partial
├── oauth_settings.html.heex      # Settings page: linked providers
├── oauth_live.ex                 # LiveView variant (--live flag)
└── oauth_test_fixtures.ex        # Test fixture helpers

lib/mix/tasks/
└── sigra.gen.oauth.ex            # Incremental generator Mix task
```

### Pattern 1: Assent Two-Phase Flow
**What:** OAuth requires a request phase (generate URL, store session params) and callback phase (exchange code, fetch user).
**When to use:** Every OAuth login/register/link operation.
**Example:**
```elixir
# Source: hexdocs.pm/assent/Assent.Strategy.OAuth2.html
# Request phase
def authorize_url(provider, config) do
  strategy = resolve_strategy(provider)
  config = build_assent_config(provider, config)

  case strategy.authorize_url(config) do
    {:ok, %{url: url, session_params: session_params}} ->
      # Sigra overrides state with HMAC-signed version (D-16)
      sigra_state = Sigra.Token.generate(secret_key_base, "sigra-oauth-state", %{
        provider: provider,
        timestamp: System.system_time(:second)
      })
      url = replace_state_in_url(url, sigra_state)
      {:ok, url, Map.put(session_params, :sigra_state, sigra_state)}

    {:error, error} ->
      {:error, %Sigra.Error.OAuthError{provider: provider, error_code: :authorize_failed}}
  end
end

# Callback phase
def callback(provider, params, session_params, config) do
  strategy = resolve_strategy(provider)
  config = build_assent_config(provider, config)

  # Verify Sigra's HMAC state first (D-16)
  with :ok <- verify_state(params, session_params, secret_key_base),
       {:ok, %{user: user_info, token: token}} <- strategy.callback(config, params, session_params) do
    {:ok, normalize_user_info(provider, user_info), token}
  end
end
```

### Pattern 2: Account Linking Confirmation Flow (D-01, D-41)
**What:** When OAuth email matches an existing user, redirect to login with link intent stored in session.
**When to use:** OAuth callback where email matches existing account but no identity exists.
**Example:**
```elixir
# In Sigra.OAuth.Callback
def process_callback(repo, user_info, token, opts) do
  provider = opts[:provider]
  identity_schema = opts[:identity_schema]

  case repo.get_by(identity_schema, provider: provider, provider_uid: user_info["sub"]) do
    %{} = identity ->
      # Existing identity: log in
      handle_existing_identity(repo, identity, user_info, token, opts)

    nil ->
      # No identity: check if email matches existing user
      case repo.get_by(opts[:user_schema], email: user_info["email"]) do
        %{} = _existing_user ->
          # Email match: require confirmation (D-01)
          {:link_confirmation_required, %{
            provider: provider,
            provider_uid: user_info["sub"],
            email: user_info["email"]
          }}

        nil ->
          # No match: register new user
          handle_new_registration(repo, user_info, token, opts)
      end
  end
end
```

### Pattern 3: Identity Struct Mapping (D-28)
**What:** Library struct `Sigra.Identity` maps to/from generated `UserIdentity` Ecto schema.
**When to use:** Same pattern as `Sigra.Session` / `UserSession` from Phase 4.
**Example:**
```elixir
defmodule Sigra.Identity do
  @type t :: %__MODULE__{
    id: term(),
    user_id: term(),
    provider: String.t(),
    provider_uid: String.t(),
    encrypted_access_token: binary() | nil,
    encrypted_refresh_token: binary() | nil,
    token_expires_at: DateTime.t() | nil,
    provider_email: String.t() | nil,
    provider_name: String.t() | nil,
    provider_avatar_url: String.t() | nil,
    metadata: map(),
    last_used_at: DateTime.t() | nil,
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  defstruct [:id, :user_id, :provider, :provider_uid,
             :encrypted_access_token, :encrypted_refresh_token,
             :token_expires_at, :provider_email, :provider_name,
             :provider_avatar_url, metadata: %{},
             :last_used_at, :inserted_at, :updated_at]

  def from_schema(schema_struct), do: # ... map fields
  def to_params(identity), do: # ... map to Ecto-insertable params
end
```

### Pattern 4: Cloak_ecto Vault Generation (D-24)
**What:** Generator creates a minimal Vault module and encrypted type into the host app.
**When to use:** `mix sigra.gen.oauth` always generates this if not already present.
**Example:**
```elixir
# Source: hexdocs.pm/cloak_ecto/install.html
# Generated: lib/my_app/vault.ex
defmodule MyApp.Vault do
  use Cloak.Vault, otp_app: :my_app

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: decode_env!("CLOAK_KEY"),
          iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.fetch_env!()
    |> Base.decode64!()
  end
end
```

### Pattern 5: Optional Dep Gate (D-14)
**What:** Check if Assent is loaded before executing OAuth code paths.
**When to use:** All Sigra.OAuth module entry points.
**Example:**
```elixir
# Same pattern as existing Hammer/Oban/bcrypt gates in codebase
defmodule Sigra.OAuth do
  defp ensure_assent! do
    unless Code.ensure_loaded?(Assent) do
      raise """
      Assent is required for OAuth support but is not available.

      Add {:assent, "~> 0.3"} to your mix.exs dependencies and run:
          mix deps.get
      """
    end
  end
end
```
[VERIFIED: pattern matches existing `Code.ensure_loaded?` usage in lib/sigra/plug/rate_limit.ex, lib/sigra/delivery.ex, lib/sigra/hashers/bcrypt.ex]

### Anti-Patterns to Avoid
- **Direct Assent calls from controller:** Controller calls `Sigra.OAuth.*`, never `Assent.Strategy.*` directly. Sigra owns the abstraction boundary.
- **Storing raw OAuth state from Assent:** Sigra overrides with HMAC-signed state (D-16) for consistency with token security patterns.
- **Auto-linking accounts by email:** Always require confirmation when email matches (D-01). Account takeover risk otherwise.
- **Creating users without email:** Provider returns no email must fail with clear error (D-08).
- **Matching identities by email:** Always match by (provider, provider_uid) (D-32). Email can change on provider side.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OAuth 2.0 / OIDC flow | Custom HTTP client + token exchange | Assent strategy modules | RFC 6749/7636/OIDC Core compliance, PKCE, provider quirks already handled |
| Field encryption | Raw `:crypto` AES-GCM | cloak_ecto Vault + Ecto types | Key rotation, Vault supervision, transparent Ecto integration |
| Provider-specific quirks | Custom URL builders per provider | Assent built-in strategies (23) | Apple's private key JWT, GitHub's email endpoint, Facebook's proof_of_possession |
| OAuth state CSRF | Raw session storage | Sigra.Token.generate/verify with HMAC | Consistent with existing token security; prevents state injection |
| PKCE code_challenge | Manual SHA-256 + base64url | Assent's `code_verifier: true` option | Correctly implements S256 method per RFC 7636 |

**Key insight:** Assent handles the OAuth ceremony complexity (HTTP, token exchange, user info normalization, PKCE, OIDC discovery). Sigra handles the authentication orchestration (account lookup, linking policy, session creation, error mapping).

## Assent API Deep Dive

### authorize_url/1 Return Shape
```elixir
{:ok, %{
  url: "https://accounts.google.com/o/oauth2/v2/auth?client_id=...&state=...&code_challenge=...",
  session_params: %{
    state: "random_state_string",
    code_verifier: "random_pkce_verifier"  # only when code_verifier: true
  }
}}
```
[VERIFIED: hexdocs.pm/assent/Assent.Strategy.OAuth2.html]

### callback/2 Return Shape
```elixir
{:ok, %{
  user: %{
    "sub" => "provider_uid",
    "email" => "user@example.com",
    "name" => "User Name",
    "picture" => "https://...",
    # Provider-specific fields
  },
  token: %{
    "access_token" => "...",
    "refresh_token" => "...",     # Only if access_type: "offline"
    "expires_in" => 3600,
    "token_type" => "Bearer"
  }
}}
```
[VERIFIED: hexdocs.pm/assent/Assent.html]

### Provider-Specific Configuration

**Google (OIDC, Tier 1):**
```elixir
[
  client_id: "...",
  client_secret: "...",
  redirect_uri: "http://localhost:4000/auth/google/callback",
  authorization_params: [access_type: "offline", scope: "email profile"]
]
```
Strategy: `Assent.Strategy.Google` -- uses OIDC with auto-discovery. [VERIFIED: hexdocs.pm/assent/Assent.Strategy.Google.html]

**GitHub (OAuth2, Tier 1):**
```elixir
[
  client_id: "...",
  client_secret: "...",
  redirect_uri: "http://localhost:4000/auth/github/callback",
  user_emails_url: "/user/emails"  # default, fetches verified email
]
```
Strategy: `Assent.Strategy.Github` -- plain OAuth2 with separate email endpoint. [VERIFIED: hexdocs.pm/assent/Assent.Strategy.Github.html]

**Apple (OIDC + private key, Tier 2):**
```elixir
[
  client_id: "com.example.service",  # Services ID
  team_id: "XXXXXXXXXX",
  private_key_id: "XXXXXXXXXX",
  private_key_path: "path/to/AuthKey.p8",
  redirect_uri: "http://localhost:4000/auth/apple/callback"
]
```
Strategy: `Assent.Strategy.Apple` -- OIDC with `private_key_jwt` auth method. Requires Apple Developer account setup. [VERIFIED: hexdocs.pm/assent/Assent.Strategy.Apple.html]

**Facebook/Meta (OAuth2, Tier 2):**
```elixir
[
  client_id: "...",
  client_secret: "...",
  redirect_uri: "http://localhost:4000/auth/facebook/callback",
  user_url_request_fields: "email,name,first_name,last_name"
]
```
Strategy: `Assent.Strategy.Facebook`. **Critical:** Facebook does NOT provide email verification status. Email should be treated as unverified. This conflicts with D-42 (auto-confirm based on provider trust). Solution: `trust_provider_email` config option should be `false` for Facebook by default. [VERIFIED: hexdocs.pm/assent/Assent.Strategy.Facebook.html]

### OIDC Auto-Discovery
For OIDC-capable providers, Assent fetches `/.well-known/openid-configuration` automatically. Configuration options:
- `:openid_configuration_uri` -- defaults to `/.well-known/openid-configuration`
- `:id_token_signed_response_alg` -- defaults to RS256
- Nonce handling: set `:nonce` to `true` for automatic nonce generation in session_params
[VERIFIED: hexdocs.pm/assent/Assent.Strategy.OIDC.html]

## Common Pitfalls

### Pitfall 1: Facebook Email Not Verified
**What goes wrong:** D-42 says "OAuth registration auto-confirms email since provider verified it." Facebook does NOT verify emails.
**Why it happens:** Different providers have different email verification guarantees.
**How to avoid:** Per-provider `trust_provider_email` setting. Default `true` for Google/GitHub/Apple (OIDC verified), `false` for Facebook. When false, trigger normal email confirmation flow after OAuth registration.
**Warning signs:** Users registering via Facebook have `confirmed_at` set but email is actually unverified.

### Pitfall 2: Apple Name Only Available on First Auth
**What goes wrong:** Apple only returns the user's name on the very first authorization. Subsequent callbacks only include `sub` and `email`.
**Why it happens:** Apple's privacy-first design. Name is a one-time payload.
**How to avoid:** Capture and persist `provider_name` on first callback (D-31 says update on every login -- but for Apple, name will be nil on subsequent logins). Only update fields that are non-nil in the callback response.
**Warning signs:** User's name disappears from identity record after re-auth.

### Pitfall 3: GitHub Email May Require Separate API Call
**What goes wrong:** GitHub primary email might not be in the user profile response if the user set their email to private.
**Why it happens:** GitHub exposes email via `/user/emails` endpoint, not the profile.
**How to avoid:** Assent.Strategy.Github handles this via `:user_emails_url` (defaults to `/user/emails`). Ensure the `user:email` scope is requested.
**Warning signs:** GitHub callback has no email, triggering D-08 error flow unnecessarily.

### Pitfall 4: Session Params Lost Between Request and Callback
**What goes wrong:** PKCE code_verifier and state are stored in Plug session during authorize but missing during callback.
**Why it happens:** Session cookie not persisted (redirect issues), session cleared between requests, or session cookie path mismatch.
**How to avoid:** Store session_params in Plug session under prefixed keys (D-47: `sigra_oauth_state`, etc.). Verify session persistence in test. Clear after callback processing.
**Warning signs:** All callbacks fail with state mismatch errors.

### Pitfall 5: Provider UID Collision Across Providers
**What goes wrong:** Different providers could theoretically return the same UID string.
**Why it happens:** UID is only unique within a provider.
**How to avoid:** D-26's unique index on (provider, provider_uid) handles this correctly. Always look up by both fields, never UID alone.
**Warning signs:** Wrong user logged in after OAuth callback.

### Pitfall 6: Race Condition on Account Linking
**What goes wrong:** Two simultaneous OAuth callbacks for the same email create duplicate users.
**Why it happens:** No lock between "check if user exists" and "create user."
**How to avoid:** Use `Ecto.Multi` or `INSERT ... ON CONFLICT` for the user creation path. The unique index on (provider, provider_uid) prevents duplicate identities. The unique email index on users prevents duplicate users.
**Warning signs:** IntegrityError on user insertion during OAuth registration.

### Pitfall 7: Token Refresh Race Condition (D-27)
**What goes wrong:** Multiple concurrent requests call `get_tokens/2`, all see expired token, all attempt refresh simultaneously. Provider invalidates refresh token after first use.
**Why it happens:** No serialization on token refresh.
**How to avoid:** Use optimistic locking or a "refreshing" sentinel value. Or accept that the first refresh wins and subsequent attempts use the newly stored token.
**Warning signs:** Intermittent "invalid_grant" errors from provider.

### Pitfall 8: Cloak Key Missing at Runtime
**What goes wrong:** Application crashes on boot because `CLOAK_KEY` env var is not set.
**Why it happens:** Developer forgot to set env var in dev/staging.
**How to avoid:** Vault `init/1` callback should raise a clear error: "Set CLOAK_KEY env var. Generate with: 32 |> :crypto.strong_rand_bytes() |> Base.encode64()". Generator should output this instruction.
**Warning signs:** `** (System.EnvError) could not fetch environment variable "CLOAK_KEY"`.

## Code Examples

### OAuth State HMAC Signing (D-16)
```elixir
# Uses existing Sigra.Token infrastructure
# Purpose salt: "sigra-oauth-state"
defp generate_state(secret_key_base, provider) do
  Sigra.Token.generate(secret_key_base, "sigra-oauth-state", %{
    provider: to_string(provider),
    nonce: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  }, max_age: 900)  # 15-minute TTL
end

defp verify_state(state, secret_key_base) do
  Sigra.Token.verify(secret_key_base, "sigra-oauth-state", state, max_age: 900)
end
```
[Pattern follows existing Sigra.Token.generate/verify in lib/sigra/token.ex]

### UserIdentity Generated Schema (D-25)
```elixir
# priv/templates/sigra.gen.oauth/user_identity.ex
defmodule <%= context_module %>.UserIdentity do
  use Ecto.Schema

  schema "user_identities" do
    field :provider, :string
    field :provider_uid, :string
    field :encrypted_access_token, <%= app_module %>.Encrypted.Binary
    field :encrypted_refresh_token, <%= app_module %>.Encrypted.Binary
    field :token_expires_at, :utc_datetime
    field :provider_email, :string
    field :provider_name, :string
    field :provider_avatar_url, :string
    field :metadata, :map, default: %{}
    field :last_used_at, :utc_datetime

    belongs_to :user, <%= context_module %>.<%= schema_alias %>

    timestamps(type: :utc_datetime)
  end
end
```

### Migration Template (D-35, D-65)
```elixir
# PostgreSQL variant
create table(:user_identities) do
  add :user_id, references(:users, on_delete: :delete_all), null: false
  add :provider, :string, null: false
  add :provider_uid, :string, null: false
  add :encrypted_access_token, :binary
  add :encrypted_refresh_token, :binary
  add :token_expires_at, :utc_datetime
  add :provider_email, :string
  add :provider_name, :string
  add :provider_avatar_url, :string
  add :metadata, :map, default: %{}  # JSONB on PostgreSQL
  add :last_used_at, :utc_datetime

  timestamps(type: :utc_datetime)
end

create unique_index(:user_identities, [:user_id, :provider])
create unique_index(:user_identities, [:provider, :provider_uid])
create index(:user_identities, [:user_id])
```

### OAuth Controller Template (D-19, D-46)
```elixir
defmodule <%= web_module %>.OAuthController do
  use <%= web_module %>, :controller

  alias <%= context_module %>, as: Auth

  # GET /auth/:provider -- initiate OAuth
  def request(conn, %{"provider" => provider}) do
    case Auth.oauth_authorize_url(provider) do
      {:ok, url, session_params} ->
        conn
        |> put_session(:sigra_oauth_state, session_params.sigra_state)
        |> put_session(:sigra_oauth_code_verifier, session_params[:code_verifier])
        |> put_session(:sigra_oauth_return_to, get_session(conn, :sigra_return_to))
        |> redirect(external: url)

      {:error, _} ->
        conn
        |> put_flash(:error, "Could not connect to #{provider}. Please try again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  # GET /auth/:provider/callback -- handle OAuth callback
  def callback(conn, %{"provider" => provider} = params) do
    session_params = %{
      state: get_session(conn, :sigra_oauth_state),
      code_verifier: get_session(conn, :sigra_oauth_code_verifier)
    }

    conn = clean_oauth_session(conn)

    case Auth.oauth_callback(provider, params, session_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:link_confirmation_required, intent} ->
        conn
        |> put_session(:sigra_oauth_link_intent, intent)
        |> put_flash(:info, "An account with this email exists. Log in to link your #{intent.provider} account.")
        |> redirect(to: ~p"/users/log_in")

      {:error, %Sigra.Error.OAuthError{error_code: :state_mismatch}} ->
        conn
        |> put_flash(:error, "Authentication expired. Please try again.")
        |> redirect(to: ~p"/users/log_in")

      {:error, _} ->
        conn
        |> put_flash(:error, "Could not sign in with #{provider}. Please try again or use another method.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  defp clean_oauth_session(conn) do
    conn
    |> delete_session(:sigra_oauth_state)
    |> delete_session(:sigra_oauth_code_verifier)
    |> delete_session(:sigra_oauth_return_to)
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ueberauth + N strategy packages | Assent single package with 23 strategies | Assent 0.2+ (2022) | Single dep, PKCE/OIDC native, no Plug coupling |
| OAuth 2.0 without PKCE | PKCE (S256) mandatory for public clients | RFC 7636, enforced 2023+ | Prevents authorization code interception; Assent supports via `code_verifier: true` |
| Implicit grant for SPAs | Authorization code + PKCE for all clients | OAuth 2.1 draft | No tokens in URL fragments; Sigra Phase 5 is server-rendered only |
| Manual OIDC endpoint config | Auto-discovery via .well-known | Standard since OIDC Core 1.0 | Less config needed; Assent handles automatically |
| Pow + PowAssent | Sigra (this project) | 2025/2026 | Pow blocks Phoenix 1.8+; PowAssent unusable |

**Deprecated/outdated:**
- PowAssent: Tied to Pow which blocks Phoenix 1.8+. No migration path.
- Ueberauth: Still maintained but the multi-package model is cumbersome. Not recommended for new projects.
- OAuth implicit grant: Deprecated in OAuth 2.1 draft. Not implemented.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | cloak ~> 1.1 is a transitive dep of cloak_ecto 1.3.0 | Standard Stack | Low -- cloak_ecto declares this dep; may be different minor version |
| A2 | Assent callback returns user info with "sub" key for all providers | Code Examples | Medium -- some providers may use different key names; Assent normalizes to OpenID Connect claims but verify per provider |
| A3 | Assent.Strategy.Facebook module name (not Meta) | Provider Config | Low -- hex.pm lists "Facebook" not "Meta" as strategy name |
| A4 | PKCE code_verifier passed through session_params to callback | Architecture | Low -- documented in Assent.Strategy.OAuth2 hexdocs |

## Open Questions

1. **Assent HTTP client configuration**
   - What we know: Assent uses an HTTP client internally for token exchange and user info fetching
   - What's unclear: Whether Assent 0.3.x uses Req, Finch, or httpc by default; whether the HTTP client is configurable
   - Recommendation: Check Assent's mix.exs deps. If configurable, document recommended HTTP client in generated config.

2. **Token refresh serialization (Pitfall 7)**
   - What we know: D-27 requires auto-refresh on access. Concurrent requests could race.
   - What's unclear: Best Elixir pattern for single-flight token refresh without a dedicated GenServer.
   - Recommendation: Optimistic approach: first refresh wins (UPDATE WHERE refresh_token = old_token), others retry read. Simple and covers 99% of cases.

3. **Vault supervision tree placement**
   - What we know: Cloak Vault is a GenServer that must be in the supervision tree.
   - What's unclear: Whether the generator should inject it into application.ex or document manual placement.
   - Recommendation: Generator injects Vault into the supervision tree (same pattern as Oban injection in many Phoenix apps). Include clear comment.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + Mox 1.1 |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/sigra/oauth_test.exs --max-failures 3` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OAUTH-01 | Assent integration with PKCE and OIDC | unit | `mix test test/sigra/oauth_test.exs -x` | Wave 0 |
| OAUTH-02 | Google and GitHub provider wrappers | unit | `mix test test/sigra/oauth/strategies_test.exs -x` | Wave 0 |
| OAUTH-03 | Apple and Facebook provider wrappers | unit | `mix test test/sigra/oauth/strategies_test.exs -x` | Wave 0 |
| OAUTH-04 | Account linking from settings (requires sudo) | unit | `mix test test/sigra/oauth_test.exs:link -x` | Wave 0 |
| OAUTH-05 | Email-match linking with confirmation | unit | `mix test test/sigra/oauth/callback_test.exs -x` | Wave 0 |
| OAUTH-06 | Multiple providers per user (identity schema) | unit | `mix test test/sigra/identity_test.exs -x` | Wave 0 |
| OAUTH-07 | Encrypted token storage | unit | `mix test test/sigra/identity_test.exs:encrypted -x` | Wave 0 |
| OAUTH-08 | Edge case handling (no email, CSRF, conflict) | unit | `mix test test/sigra/oauth/callback_test.exs:error -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/oauth_test.exs test/sigra/oauth/ test/sigra/identity_test.exs --max-failures 3`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/oauth_test.exs` -- covers OAUTH-01, OAUTH-04 (orchestrator functions)
- [ ] `test/sigra/oauth/callback_test.exs` -- covers OAUTH-05, OAUTH-08 (callback processing)
- [ ] `test/sigra/oauth/strategies_test.exs` -- covers OAUTH-02, OAUTH-03 (strategy wrappers)
- [ ] `test/sigra/identity_test.exs` -- covers OAUTH-06, OAUTH-07 (Identity struct, from_schema/to_params)
- [ ] Mock setup: `Mox.defmock(Sigra.MockHTTPClient, for: ...)` or Assent test helpers -- need to mock Assent HTTP layer for unit tests without hitting real providers

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | OAuth 2.0 + PKCE via Assent; HMAC-signed state; session-based auth after callback |
| V3 Session Management | Yes | Reuse Phase 4 session infrastructure; OAuth sessions same code path (D-67) |
| V4 Access Control | Yes | Account linking requires sudo mode (D-05); unlink blocked without password (D-03) |
| V5 Input Validation | Yes | NimbleOptions for config; provider name normalized; UID treated as opaque string |
| V6 Cryptography | Yes | cloak_ecto AES-256-GCM for token storage; HMAC for state param; never store raw tokens |

### Known Threat Patterns for OAuth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Authorization code interception | Tampering | PKCE (S256) enabled by default (D-17) |
| CSRF on callback | Spoofing | HMAC-signed state parameter verified before token exchange (D-16) |
| Account takeover via email match | Elevation of Privilege | Mandatory confirmation before linking (D-01); no auto-link |
| Token theft from database | Information Disclosure | AES-256-GCM encryption via cloak_ecto (D-22) |
| Provider impersonation (fake callback) | Spoofing | State verification + token exchange validates against provider |
| Account merging confusion | Tampering | Block login when UID maps to user A but email matches user B (D-09) |
| Enumeration via OAuth errors | Information Disclosure | Generic error messages (D-55); never reveal whether email exists |
| Open redirect on callback | Tampering | Validate redirect_uri; return_to stored in session not URL param (D-44) |

## Sources

### Primary (HIGH confidence)
- [hexdocs.pm/assent](https://hexdocs.pm/assent/) -- v0.3.1 main docs, authorize_url/callback return types, built-in strategies list
- [hexdocs.pm/assent/Assent.Strategy.OAuth2.html](https://hexdocs.pm/assent/Assent.Strategy.OAuth2.html) -- OAuth2 strategy API, PKCE config, session_params structure
- [hexdocs.pm/assent/Assent.Strategy.OIDC.html](https://hexdocs.pm/assent/Assent.Strategy.OIDC.html) -- OIDC auto-discovery, nonce handling
- [hexdocs.pm/assent/Assent.Strategy.Google.html](https://hexdocs.pm/assent/Assent.Strategy.Google.html) -- Google OIDC config
- [hexdocs.pm/assent/Assent.Strategy.Github.html](https://hexdocs.pm/assent/Assent.Strategy.Github.html) -- GitHub OAuth2 config, user_emails_url
- [hexdocs.pm/assent/Assent.Strategy.Apple.html](https://hexdocs.pm/assent/Assent.Strategy.Apple.html) -- Apple private key auth
- [hexdocs.pm/assent/Assent.Strategy.Facebook.html](https://hexdocs.pm/assent/Assent.Strategy.Facebook.html) -- Facebook email NOT verified
- [hexdocs.pm/cloak_ecto/install.html](https://hexdocs.pm/cloak_ecto/install.html) -- Vault setup, encrypted type, migration

### Secondary (MEDIUM confidence)
- Existing Sigra codebase: lib/sigra/auth.ex, lib/sigra/token.ex, lib/sigra/session.ex, lib/sigra/config.ex -- established patterns verified by reading source

### Tertiary (LOW confidence)
- None -- all claims verified against hexdocs or codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Assent and cloak_ecto versions verified against hexdocs; both are locked decisions from CONTEXT.md
- Architecture: HIGH -- Module structure follows established codebase patterns (Token, Session, Auth); CONTEXT.md provides detailed decisions
- Pitfalls: HIGH -- Provider-specific quirks verified against Assent hexdocs (Facebook email, Apple name); account linking edge cases from CONTEXT.md decisions
- Assent API: HIGH -- Return types and config verified against hexdocs.pm

**Research date:** 2026-04-08
**Valid until:** 2026-05-08 (30 days -- Assent and cloak_ecto are stable, slow-moving)
