# Architecture Research

**Domain:** Elixir/Phoenix authentication library (hybrid lib+generator)
**Researched:** 2026-04-04
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      INTEGRATION LAYER                           │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │ HTTP Plug      │  │ LiveView        │  │ API / Channel    │  │
│  │ Pipeline       │  │ on_mount hooks  │  │ Plugs            │  │
│  └───────┬────────┘  └────────┬────────┘  └────────┬─────────┘  │
│          └────────────────────┼─────────────────────┘           │
├───────────────────────────────┼─────────────────────────────────┤
│                  AUTH CONTEXT (generated: MyApp.Auth)            │
│          Phoenix context — the public API boundary               │
│  register_user/1 · authenticate/2 · issue_session/1             │
│  change_password/2 · enroll_totp/1 · verify_api_key/1 ...       │
├───────────────────────────────┼─────────────────────────────────┤
│                    LIBRARY CORE (Sigra.*) — in dep               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │  Password   │  │  Token       │  │  Session             │    │
│  │  Hashing    │  │  Generation  │  │  Management          │    │
│  └─────────────┘  └──────────────┘  └──────────────────────┘    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │  OAuth /    │  │  MFA / TOTP  │  │  WebAuthn            │    │
│  │  Assent     │  │  NimbleTOTP  │  │  Wax                 │    │
│  └─────────────┘  └──────────────┘  └──────────────────────┘    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │  Rate       │  │  Audit       │  │  Email               │    │
│  │  Limiting   │  │  Logging     │  │  Delivery (Swoosh)   │    │
│  └─────────────┘  └──────────────┘  └──────────────────────┘    │
├───────────────────────────────────────────────────────────────── ┤
│                      DATA LAYER (Ecto)                           │
│  users · user_tokens · user_identities · mfa_credentials        │
│  passkey_credentials · api_keys · sessions · audit_log          │
└─────────────────────────────────────────────────────────────────┘
```

The key architectural insight is the **boundary between library and generated code**:

- **Library (dep):** All security-critical operations. Password hashing, HMAC token generation/verification, TOTP validation, WebAuthn ceremonies, rate limiting logic. Security patches propagate automatically via `mix deps.update sigra`.
- **Generated (owned by dev):** Routes, controllers/LiveViews, Ecto schemas, the `MyApp.Auth` context module. Developers edit these freely without fighting framework internals.
- **Contract:** The generated context module calls library functions for every security-sensitive operation. The library never touches `Plug.Conn` or schema structs directly — those are the developer's domain.

### Component Responsibilities

| Component | Responsibility | Hybrid Position |
|-----------|----------------|-----------------|
| `Sigra.Password` | Argon2id hashing, bcrypt migration, constant-time compare | Library (dep) |
| `Sigra.Token` | HMAC-protected token generation, verification, single-use enforcement | Library (dep) |
| `Sigra.Session` | Session lifecycle, idle/absolute timeouts, device tracking | Library (dep) |
| `Sigra.OAuth` | Assent integration, callback handling, provider normalization | Library (dep) |
| `Sigra.MFA` | TOTP via NimbleTOTP, backup codes, WebAuthn via Wax | Library (dep) |
| `Sigra.RateLimit` | Per-IP and per-account lockout via ETS/Hammer | Library (dep) |
| `Sigra.Audit` | Structured security event logging | Library (dep) |
| `Sigra.Email` | Mailer behaviours, Swoosh templates | Library (dep) |
| `MyApp.Auth` | Phoenix context — public API, orchestrates library calls | Generated |
| `MyApp.UserAuth` | Plugs: `require_authenticated_user`, `fetch_current_scope`, etc. | Generated |
| `MyApp.Auth.Scope` | Scope struct carrying user + org + metadata | Generated |
| Ecto Schemas | `User`, `UserToken`, `UserIdentity`, `ApiKey`, etc. | Generated (migrations too) |
| LiveView pages | Login, register, MFA setup, session list, OAuth flows | Generated (optional) |
| Router | `live_session` blocks, pipeline definitions, OAuth callbacks | Generated |

## Recommended Project Structure

```
lib/
├── sigra/                        # Library — ships as dep
│   ├── password.ex               # Argon2id hashing + migration logic
│   ├── token.ex                  # HMAC token generation + verification
│   ├── session.ex                # Session lifecycle helpers
│   ├── rate_limit.ex             # ETS-backed IP + account limiter
│   ├── audit.ex                  # Structured audit log writer
│   ├── oauth/
│   │   ├── assent.ex             # Assent adapter and normalization
│   │   └── providers.ex          # Provider config helpers
│   ├── mfa/
│   │   ├── totp.ex               # NimbleTOTP wrapper + backup codes
│   │   └── webauthn.ex           # Wax ceremony wrappers
│   ├── email/
│   │   ├── mailer_behaviour.ex   # @behaviour for swappable mailers
│   │   └── templates/            # Default Swoosh email templates
│   ├── plug/
│   │   ├── require_auth.ex       # Reusable plug (devs can also use generated)
│   │   └── dual_mode_auth.ex     # Session-or-bearer detection
│   └── telemetry.ex              # :telemetry event definitions
│
# Generated into developer's project:
lib/my_app/
│   └── auth/
│       ├── auth.ex               # Context module — the public API
│       ├── scope.ex              # Scope struct
│       ├── user.ex               # User schema
│       ├── user_token.ex         # UserToken schema
│       ├── user_identity.ex      # OAuth identity schema
│       ├── mfa_credential.ex     # TOTP/WebAuthn credential schema
│       └── api_key.ex            # API key schema
│
lib/my_app_web/
│   ├── user_auth.ex              # Auth plugs + on_mount hooks
│   └── live/auth/
│       ├── login_live.ex
│       ├── register_live.ex
│       ├── confirm_live.ex
│       ├── reset_password_live.ex
│       ├── mfa_setup_live.ex
│       └── sessions_live.ex      # Active session management UI
│
priv/repo/migrations/             # Generated per-feature migrations
```

### Structure Rationale

- **`lib/sigra/`:** Everything that must stay in the dep for security patch propagation. No Phoenix-specific code here — pure functions or process wrappers only. Stays testable in isolation.
- **`lib/my_app/auth/`:** The Phoenix context boundary. Developers own this code. It's the only place that orchestrates across schemas and library calls. Controllers and LiveViews never bypass this.
- **`lib/my_app_web/user_auth.ex`:** Plug/LiveView integration layer generated into the app. Provides `on_mount` hooks for `live_session` blocks and `require_authenticated_user` plugs for router pipelines. Reads from `MyApp.Auth` context only.
- **`priv/repo/migrations/`:** One migration per feature (Rodauth-inspired). Clean install generates only the tables needed for the features selected.

## Architectural Patterns

### Pattern 1: Per-Request Auth Context (Rodauth-Inspired)

**What:** A lightweight struct (`Sigra.AuthContext`) is constructed at the start of each request and carried via `conn.assigns.current_scope` (HTTP) or `socket.assigns.current_scope` (LiveView). It holds the resolved user, organization, active session metadata, and MFA state. All auth operations in the request read from and return updated context structs — there is no global auth state.

**When to use:** Everywhere in the request lifecycle. The context struct is the single source of truth for "who is this user and what do they have access to" during a request.

**Trade-offs:** Slightly more plumbing at request boundaries vs. implicit current_user patterns. Major benefit: testable, inspectable, no process state leakage between requests.

**Example:**
```elixir
# In the generated fetch_current_scope_for_user plug:
defp fetch_current_scope_for_user(conn, _opts) do
  token = get_session(conn, :user_token)
  case Sigra.Session.verify_token(token, MyApp.Repo) do
    {:ok, session} ->
      scope = MyApp.Auth.Scope.for_session(session)
      assign(conn, :current_scope, scope)
    :error ->
      assign(conn, :current_scope, nil)
  end
end

# In a generated on_mount hook for LiveView:
def on_mount(:require_authenticated_user, _params, session, socket) do
  token = session["user_token"]
  case Sigra.Session.verify_token(token, MyApp.Repo) do
    {:ok, sess} ->
      {:cont, assign(socket, :current_scope, MyApp.Auth.Scope.for_session(sess))}
    :error ->
      {:halt, redirect(socket, to: ~p"/login")}
  end
end
```

### Pattern 2: Dual-Mode Authentication (Browser + API)

**What:** A plug that detects whether the request is browser-based (session cookie) or API-based (Bearer token) and runs the appropriate auth path. Both paths produce a `current_scope` assign of the same shape — downstream code never knows which path was used.

**When to use:** Routes that must serve both browser sessions and programmatic API access. Implemented as `Sigra.Plug.DualModeAuth` in the library; devs include it in their `:api_and_browser` pipeline.

**Trade-offs:** Slight complexity in the plug; avoids duplicating every route for browser vs API. Session-heavy endpoints get minimal overhead since the bearer check short-circuits.

**Example:**
```elixir
defmodule MyAppWeb.Router do
  pipeline :authenticated do
    plug :fetch_session
    plug MyAppWeb.UserAuth, :fetch_current_scope_for_user
  end

  pipeline :api_auth do
    plug Sigra.Plug.DualModeAuth,
      session_fn: &MyApp.Auth.get_user_by_session_token/1,
      bearer_fn: &MyApp.Auth.get_user_by_api_key/1
  end
end
```

### Pattern 3: Behaviour + Callback Extensibility

**What:** Each pluggable concern in Sigra (mailer, rate limiter, session store) is defined as an Elixir `@behaviour`. The library ships default implementations. Developers swap implementations by passing module references — no macro injection, no hidden overrides.

**When to use:** Any place where the library must call outward into developer infrastructure (sending email, storing rate limit state, custom session backends).

**Trade-offs:** Slightly more verbose configuration than "magic" DSLs. Benefit: compiler-checked callbacks, no hidden code generation, easy to mock in tests.

**Example:**
```elixir
# In config/config.exs (generated):
config :sigra,
  mailer: MyApp.Mailer,          # implements Sigra.Mailer behaviour
  rate_limiter: Sigra.RateLimit.ETS,  # or Sigra.RateLimit.Hammer
  repo: MyApp.Repo

# The mailer behaviour:
defmodule Sigra.Mailer do
  @callback deliver_confirmation(user :: map(), token :: String.t()) ::
              {:ok, term()} | {:error, term()}
  @callback deliver_password_reset(user :: map(), token :: String.t()) ::
              {:ok, term()} | {:error, term()}
end
```

### Pattern 4: Progressive Authentication States

**What:** Authentication is not binary (authenticated / not). Sigra models a progression: anonymous → email-verified → password-authenticated → MFA-pending → fully-authenticated → sudo-mode. The `Scope` struct carries this state, and plugs/on_mount hooks match against specific states.

**When to use:** Whenever a route needs more nuance than `require_authenticated_user`. For example, the MFA setup page requires `email-verified` but not `mfa-complete`. Sudo mode pages require `fully-authenticated` within the last N minutes.

**Trade-offs:** More states to reason about, but prevents the common bug of bypassing MFA by navigating directly to a protected URL after email verification.

**Example:**
```elixir
defmodule MyApp.Auth.Scope do
  @type auth_state ::
    :anonymous
    | :email_verified
    | :authenticated
    | :mfa_pending        # authenticated but MFA step required
    | :mfa_complete       # fully authenticated
    | :sudo               # re-authenticated recently

  defstruct [:user, :session, :auth_state, :organization, :ip, :user_agent]
end

# Plug usage:
plug MyAppWeb.UserAuth, :require_mfa_complete  # enforces :mfa_complete state
plug MyAppWeb.UserAuth, :require_sudo          # enforces :sudo state
```

### Pattern 5: Separate Tables Per Concern (Rodauth-Inspired)

**What:** Auth-relevant data lives in purpose-specific tables rather than one fat `users` table. Each table has a narrow responsibility and its own migration.

**When to use:** Default design. Every auth concept gets its own table.

**Trade-offs:** More tables, more joins. Benefit: schema evolution per feature, clear ownership boundaries, Rodauth proved this at scale.

**Core tables:**
- `users` — stable identity anchor: id, email (citext), confirmed_at, locked_at
- `user_tokens` — sessions + email flow tokens: user_id, token_hash, context, expires_at
- `user_identities` — OAuth credentials: user_id, provider, uid, access_token (encrypted)
- `mfa_credentials` — TOTP/WebAuthn: user_id, type, secret (encrypted), backup_code_hashes
- `passkey_credentials` — WebAuthn passkeys: user_id, credential_id, public_key, sign_count
- `api_keys` — API access: user_id, key_hash, key_prefix, scopes, expires_at, revoked_at
- `sessions` — tracked sessions: user_id, token_hash, ip, user_agent, last_active_at
- `audit_log` — security events: user_id, action, ip, user_agent, metadata (JSONB)

## Data Flow

### Browser Login Flow (Session-Based)

```
User submits login form (HTTP POST — not LiveView event)
    ↓
Router :browser pipeline → fetch_session plug → CSRF check
    ↓
MyApp.AuthController.create/2
    ↓
MyApp.Auth.authenticate(email, password)  [generated context fn]
    ↓
    ├── Sigra.Password.verify(input, hash)        [lib: constant-time]
    ├── Sigra.RateLimit.check_attempt(ip, email)  [lib: ETS bucket]
    └── {:ok, user} | {:error, reason}
    ↓
MyApp.Auth.issue_session_token(user)  [generated]
    ↓
Sigra.Token.generate_session(user_id, repo)  [lib: HMAC-protected]
    ↓
put_session(conn, :user_token, token)
redirect(conn, to: ~p"/dashboard")
```

### LiveView Auth State Propagation

```
Browser connects WebSocket (session cookie carried)
    ↓
live_session :require_authenticated_user,
  on_mount: [{MyAppWeb.UserAuth, :require_authenticated_user}]
    ↓
on_mount callback reads session["user_token"]
    ↓
Sigra.Session.verify_token(token, repo)  [lib]
    ↓
{:cont, assign(socket, :current_scope, scope)}
    ↓
All LiveViews in session block receive current_scope in assigns
    ↓
On logout: MyApp.Auth.log_out(socket)
           Phoenix.Endpoint.broadcast("users_socket:#{id}", "disconnect", %{})
```

### API Bearer Token Flow

```
API client: GET /api/resource
  Authorization: Bearer myapp_live_abc123...
    ↓
Router :api pipeline → Sigra.Plug.DualModeAuth
    ↓
Extract token from Authorization header
    ↓
MyApp.Auth.get_user_by_api_key(token)  [generated]
    ↓
Sigra.Token.verify_api_key(prefix, raw, repo)  [lib: hash lookup]
    ↓
{:ok, %Scope{user: user, auth_state: :authenticated}} | {:error, :unauthorized}
    ↓
Controller receives current_scope — same shape as browser flow
```

### OAuth Callback Flow

```
User clicks "Sign in with Google"
    ↓
MyApp.AuthController.oauth_request/2 (generated)
    ↓
Sigra.OAuth.authorize_url(provider, session_params)  [lib via Assent]
    ↓
Redirect to provider
    ↓
Provider callback: GET /auth/google/callback
    ↓
Sigra.OAuth.callback(provider, params, session_params)  [lib via Assent]
    ↓
{:ok, %{user: claims, token: oauth_token}}
    ↓
MyApp.Auth.find_or_create_from_oauth(provider, claims, oauth_token)  [generated]
    ↓
    ├── Upsert user_identities row
    ├── Find or create users row
    └── Issue session token
    ↓
put_session + redirect to dashboard
```

### MFA Step-Up Flow

```
User logs in with password → Scope: :authenticated
    ↓
Route has plug :require_mfa_complete
    ↓
Plug detects auth_state != :mfa_complete, redirects to /mfa/verify
    ↓
User submits TOTP code (HTTP POST)
    ↓
Sigra.MFA.verify_totp(secret_enc, code)  [lib via NimbleTOTP]
    ↓
{:ok, :valid} → update Scope: :mfa_complete → update session token
    ↓
Redirect to original destination
```

### Email Token Flow (Confirmation / Password Reset)

```
MyApp.Auth.deliver_confirmation_email(user)  [generated]
    ↓
Sigra.Token.generate_email_token(user_id, context: :confirm)  [lib]
    ↓
Store hashed token in user_tokens table, return raw token
    ↓
Sigra.Email.deliver_confirmation(user, raw_token)  [lib, via mailer behaviour]
    ↓
User clicks link: GET /confirm/:token
    ↓
Sigra.Token.verify_email_token(raw_token, :confirm, repo)  [lib]
    ↓
Single-use: delete token row in same transaction
    ↓
{:ok, user} → mark user confirmed_at
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1k users | Default setup. Single Postgres instance. ETS for rate limiting (per-node, good enough). Inline email delivery via Swoosh. |
| 1k-100k users | Rate limiting via Redis/Hammer. Oban for async email delivery and session cleanup jobs. Session table indexed on user_id + context. Read replicas for token lookups if needed. |
| 100k+ users | Postgres partitioning on `user_tokens` and `audit_log` by date. Distributed rate limiting via centralized counter. Consider caching session verification in ETS with TTL. Audit log may need separate archival store. |

### Scaling Priorities

1. **First bottleneck:** `user_tokens` table becomes hot on every request (session lookup). Fix: index on `(token_hash, context)`, add `expires_at` to allow bulk cleanup, consider a caching layer for session verification.
2. **Second bottleneck:** `audit_log` grows unbounded. Fix: partition by month or stream to external log sink via Oban worker. Separate operational writes from archival reads.
3. **Rate limiting state:** ETS is per-node. In multi-node deployments, an attacker can bypass account lockout by hitting different nodes. Fix: Hammer with Redis backend, or use DB-backed counters for account lockout (lower performance, higher correctness).

## Anti-Patterns

### Anti-Pattern 1: Auth Logic in the Web Layer

**What people do:** Put `Repo.get_by(User, email: email)` and `Argon2.verify_pass/2` calls directly in a controller or LiveView event handler.

**Why it's wrong:** Security-critical code is now owned by the developer and won't receive patches. Also violates Phoenix context boundary — the web layer should never touch schemas or hashing directly.

**Do this instead:** All auth operations go through the generated `MyApp.Auth` context, which delegates to `Sigra.*` library functions. The context is the seam — devs can add callbacks and hooks there without touching library internals.

### Anti-Pattern 2: Logout via LiveView Events

**What people do:** Implement logout as a LiveView `handle_event("logout", ...)` that tries to clear the session.

**Why it's wrong:** `put_session/3` is not available in LiveView handlers because the WebSocket connection is already established. The session lives in the HTTP layer. LiveView event handlers cannot modify it.

**Do this instead:** Use `phx-trigger-action` on a hidden form targeting `DELETE /logout`. The HTTP POST/DELETE handler clears the session and redirects. This is the pattern phx.gen.auth uses and Sigra must follow.

### Anti-Pattern 3: Macros Injecting Schema Fields

**What people do:** `use Sigra.Schema` that injects `field :hashed_password, :string` and `field :confirmed_at, :utc_datetime` into the user schema.

**Why it's wrong:** Violates José's "own your code" principle. Devs can't see or understand their own schema. The macro-injected fields cause confusion when querying, introspecting, or migrating. Pow did this and it's the #1 reason people hate Pow.

**Do this instead:** Generated schemas are plain `defmodule User` with explicit `field` declarations. Developers can read and edit every field. The library is never injected into schemas.

### Anti-Pattern 4: Putting All Tokens in One Table with No Index Strategy

**What people do:** Store sessions, magic links, confirmation tokens, password reset tokens, and API keys all in a single `tokens` table with a generic `type` column and no partial indexes.

**Why it's wrong:** Token lookups must be O(1). Without an index on `(token_hash, context)`, a table with mixed token types forces a full scan or an index that doesn't selectably filter by type. Partial indexes on active tokens of specific contexts are orders of magnitude faster.

**Do this instead:** Index `user_tokens` on `(token_hash, context)`. Use `WHERE revoked_at IS NULL` partial indexes for session and API key lookups. Run a periodic cleanup job (Oban) to delete expired tokens and keep the table lean.

### Anti-Pattern 5: Session Auth and API Auth as Separate Code Paths

**What people do:** Build separate route trees — `/web/` uses cookie sessions, `/api/` uses JWT. The same user resource has two different auth code paths with different bugs.

**Why it's wrong:** Security inconsistencies creep in. A password change that invalidates web sessions may not invalidate API sessions. TOTP enforcement on web won't carry to API. Maintenance doubles.

**Do this instead:** Use the dual-mode plug pattern. Both paths produce the same `current_scope` struct. Session invalidation logic runs once and applies to both. API keys and session tokens share the same `user_tokens` table with different `context` values. A single `revoke_all_sessions(user)` function revokes everything.

### Anti-Pattern 6: Over-Relying on `Application.get_env` in Library Code

**What people do:** Scatter `Application.get_env(:sigra, :repo)` calls throughout the library.

**Why it's wrong:** This ties the library to the host app's config namespace, makes testing harder (must set global config in test setup), and violates the Elixir library best practice of passing dependencies explicitly. It also creates compile-time coupling if misconfigured.

**Do this instead:** Library functions accept `repo`, `mailer`, and other dependencies as explicit arguments or via a narrow config struct. The generated context module handles wiring: `Sigra.Token.verify(token, repo: MyApp.Repo)`. Tests pass fakes without touching application config.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| OAuth Providers (Google, GitHub, etc.) | Assent callbacks — fully managed by library | Provider config lives in developer's config.exs |
| Swoosh / Mailer | `Sigra.Mailer` behaviour — developer's mailer module is passed in | Supports async delivery via Oban |
| Oban | Library provides job modules; developer adds to Oban queues | Fallback to inline delivery if Oban not present |
| Wax (WebAuthn) | Wrapped by `Sigra.MFA.WebAuthn` with ceremony state stored in `passkey_credentials` | FIDO2 compliant |
| NimbleTOTP | Wrapped by `Sigra.MFA.TOTP` — no direct dependency on library internals | Secret encrypted at rest |
| Hammer / ETS | `Sigra.RateLimit` behaviour — ETS default, Hammer optional | Multi-node deployments need Redis-backed Hammer |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Library core ↔ Generated context | Explicit function calls with repo passed as argument | No compile-time coupling |
| Generated context ↔ Web layer (controllers/LiveViews) | Context public API only — never bypass to schemas | Enforces DDD boundary |
| Plug pipeline ↔ LiveView on_mount | Both read `current_scope` from session token | Must use HTTP POST for logout (not LiveView events) |
| Session auth ↔ API bearer auth | Same `user_tokens` table, different `context` column | Dual-mode plug normalizes both to same Scope shape |
| Auth context ↔ Email delivery | Via `Sigra.Mailer` behaviour — developer's mailer wired in config | Async via Oban when present |
| Auth events ↔ Application code | Telemetry events (`:sigra, :auth, :login, :start/stop`) + optional PubSub broadcasts | Application hooks for custom logic |

## Build Order Implications

The component dependencies suggest this build sequence:

1. **Data layer first** — Migrations, Ecto schemas (`User`, `UserToken`). Nothing else can be tested without these.

2. **Core library: Password + Token** — `Sigra.Password` and `Sigra.Token` are depended on by everything. No I/O, pure functions. Highest test ROI.

3. **Session management** — Builds on Token. Enables basic login/logout. Unblocks LiveView auth testing.

4. **Generated context + Plug integration** — `MyApp.Auth` context, `UserAuth` plugs, `on_mount` hooks. This is where the hybrid boundary is established. All other features bolt on here.

5. **Email flows** — Confirmation and password reset. Depends on Token + Session + Mailer behaviour.

6. **OAuth** — Depends on context (for user creation) and session (for post-auth redirect). Assent does the heavy lifting.

7. **MFA: TOTP + Backup Codes** — Self-contained feature. Depends on User schema and session (for MFA state propagation).

8. **API Keys + Bearer Auth** — Dual-mode plug depends on Token. API key schema is standalone.

9. **Rate Limiting + Account Lockout** — Can be added incrementally; sits in front of authenticate path.

10. **WebAuthn / Passkeys** — Most complex ceremony flow. Depends on session state for challenge storage. Last core feature.

11. **Session Management UI** — LiveView screens for device list, revocation. Depends on session tracking schema.

12. **Audit Logging** — Cross-cutting; add after each feature stabilizes.

## Sources

- [mix phx.gen.auth — Phoenix v1.8.5](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html) — Session/token architecture, Scope struct, plug organization
- [API Authentication — Phoenix v1.8.5](https://hexdocs.pm/phoenix/api_authentication.html) — Bearer token coexistence with session auth
- [Security considerations — Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/security-model.html) — on_mount patterns, authorize on action
- [Rodauth README](https://github.com/jeremyevans/rodauth/blob/master/README.rdoc) — Per-feature tables, encapsulated auth object, HMAC tokens
- [Better Auth Plugin Architecture](https://deepwiki.com/better-auth/better-auth/5.1-plugin-architecture) — Composable plugin design, schema extension per plugin
- Elixir best practices brief (prompts/) — behaviours over macros, narrow extension points, process use rules
- Phoenix best practices brief (prompts/) — context boundary, LiveView patterns, security model
- Ecto best practices brief (prompts/) — separate-table design, redact: true, load_in_query: false
- Elixir OSS library brief (prompts/) — explicit config, no global app env, NimbleOptions

---
*Architecture research for: Sigra — Elixir/Phoenix authentication library*
*Researched: 2026-04-04*
