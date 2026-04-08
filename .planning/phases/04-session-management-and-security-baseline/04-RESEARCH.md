# Phase 4: Session Management and Security Baseline - Research

**Researched:** 2026-04-07
**Domain:** Database-backed sessions, cookie security, account lockout, IP rate limiting, suspicious login detection, sudo mode
**Confidence:** HIGH

## Summary

Phase 4 transforms Sigra's session infrastructure from the basic `user_tokens`-based approach inherited from phx.gen.auth into a dedicated `user_sessions` table with rich metadata (IP, user agent, geo, type, sudo state). It adds account lockout (DB-persisted), IP rate limiting (Hammer ETS), suspicious login detection (IP comparison against active sessions), and sudo/re-authentication mode.

The codebase already has the key behaviour abstractions in place: `Sigra.SessionStore` (3 callbacks: fetch/create/delete), `Sigra.RateLimiter` (check_rate/3), `Sigra.RateLimiters.Noop` (fail-open fallback), `Sigra.Plug.RequireSudo` (stub using `authenticated_at` from conn assigns), and `Sigra.Plug.ErrorHandler` (with `:rate_limited` and `:stale_sudo` types). The work is to redesign SessionStore with a richer `Sigra.Session` struct, implement the Hammer wrapper, build lockout logic into `Sigra.Auth.authenticate/3`, and create the new plugs/generators.

**Primary recommendation:** Build in layers -- (1) Session struct + redesigned SessionStore behaviour, (2) user_sessions migration + Ecto store implementation, (3) cookie/plug infrastructure, (4) lockout + rate limiting, (5) suspicious login + sudo, (6) generated code (LiveView, emails, routes).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Separate `user_sessions` table (not extending user_tokens). Columns: id, user_id, hashed_token, type, ip, user_agent, geo_city (nullable), geo_country_code (nullable), last_active_at, sudo_at (nullable), inserted_at.
- **D-02:** Redesign `SessionStore` behaviour with richer `Sigra.Session` struct. Session is a library struct (not Ecto schema); generated `UserSession` Ecto schema maps to/from it.
- **D-03:** Session struct includes explicit `:type` field (`:standard`, `:remember_me`). Different types get different timeout rules. Phase 6 adds MFA states.
- **D-04:** Remember-me sessions stored in same `user_sessions` table with `type: :remember_me`. One table, one behaviour implementation.
- **D-05:** Update Phase 1 migration template to include `user_sessions` table. Refactor Phase 2 session code to use user_sessions instead of user_tokens with context "session".
- **D-06:** Indexes: unique on hashed_token, index on user_id, index on (user_id, type), index on inserted_at (for cleanup). No index on IP.
- **D-07:** Extend existing `Sigra.Workers.TokenCleanup` to also clean up expired sessions.
- **D-08:** Separate cookie design: standard session cookie (browser-scoped) + separate remember-me cookie (60-day default, configurable). Two distinct tokens in DB.
- **D-09:** Update remember_me_max_age default from 14 days to 60 days.
- **D-10:** Both idle timeout AND absolute timeout. Idle: 30 min default. Absolute: 24 hours default. Both configurable.
- **D-11:** Remember-me sessions skip idle timeout. Absolute timeout = remember_me_max_age (60 days).
- **D-12:** Session token rotation: reissue after reissue_age (7 days default) on next request. Old token deleted.
- **D-13:** Throttled last_active_at updates: only write if > N minutes since last update (default 5 min). Configurable.
- **D-14:** IP + user agent + last_active_at tracked per session. Geo via optional GeoIP behaviour.
- **D-15:** GeoIP via `Sigra.GeoIP` behaviour with `lookup/1` callback. No default implementation shipped.
- **D-16:** Log out everywhere: delete all session tokens + broadcast disconnect via PubSub.
- **D-17:** Context functions + generated LiveView for session listing.
- **D-18:** Library-side UA parser (lightweight, regex-based, no external dep).
- **D-19:** Current session indicator in listing.
- **D-20:** Implement sudo mode in Phase 4 (pulling SESS-09 forward from Phase 8).
- **D-21:** Sudo window: 5 minutes (configurable). Password-only re-auth. MFA added Phase 6. OAuth re-auth Phase 5.
- **D-22:** Sudo state stored as `sudo_at` timestamp on session record.
- **D-23:** RequireSudo plug redirects to `/users/sudo` with `return_to` param.
- **D-24:** Library sets secure defaults: HttpOnly=true, SameSite=Lax, Secure=true (prod).
- **D-25:** CSRF relies on Phoenix defaults. No custom CSRF layer.
- **D-26:** Fixed threshold: 5 attempts = 15 min lockout. Counter resets on successful login. Auto-unlocks.
- **D-27:** Lockout counter tracks failed password attempts only.
- **D-28:** Lockout notification email via Phase 3 email infrastructure.
- **D-29:** Lockout check happens before password hash verification.
- **D-30:** Generic messages for lockout UX. Enumeration-safe.
- **D-31:** Lockout hooks via telemetry only.
- **D-32:** Lockout status exposed via context API: `locked?/1` and `lock_status/1`.
- **D-33:** Thin `Sigra.RateLimiters.Hammer` wrapper. Auto-detected via `Code.ensure_loaded?(Hammer)`.
- **D-34:** IP rate limiting via `Sigra.Plug.RateLimit` plug. Account rate limiting inline in `Sigra.Auth.authenticate/2`.
- **D-35:** Rate limit all auth entry points by IP: login, registration, password reset request, magic link request. Default: 10/min.
- **D-36:** Per-route configurable rate limits.
- **D-37:** Client IP from `conn.remote_ip`. Document proxy considerations.
- **D-38:** POST only rate limiting. GET not rate limited.
- **D-39:** 429 response content-negotiated. JSON for API, flash redirect for browser. Retry-After header in both.
- **D-40:** Retry-After on 429 only. No X-RateLimit-Remaining headers.
- **D-41:** When Hammer absent: Noop fallback with startup warning. Fail open.
- **D-42:** Rate limit state in ETS only (no persistence). Acceptable since lockout is DB-persisted.
- **D-43:** Generator includes RateLimit plug in generated auth routes by default.
- **D-44:** Suspicious login trigger: new IP on explicit login only. Compare against active session IPs.
- **D-45:** Remember-me rehydration does NOT trigger suspicious login notification.
- **D-46:** Notification email with IP, geo (if configured), timestamp, device info.
- **D-47:** No user opt-out. Developer configurable via `suspicious_login:` section.
- **D-48:** IP history from non-expired session records.
- **D-49-D-53:** Config sections: session timeouts, lockout, rate_limiting (existing), geo_ip, suspicious_login.
- **D-54-D-58:** Telemetry events for sessions and security signals.
- **D-59-D-61:** Testing helpers and fixtures.
- **D-62:** Generated suspicious_login_email/2 and lockout_notification_email/2.
- **D-63:** IP stored as string (not inet) for DB portability. Timestamps as utc_datetime_usec.

### Claude's Discretion
- SessionStore behaviour exact callback signatures and Session struct field types
- UA parser implementation details (regex patterns, browser/OS coverage)
- Exact LiveView component design for session listing
- Session cleanup frequency and batch size
- Rate limit key formatting in Hammer
- Sudo re-auth page generated template design
- Additional telemetry events and metadata beyond specified core events

### Deferred Ideas (OUT OF SCOPE)
- MFA-aware sudo re-authentication (Phase 6)
- MFA session states (:mfa_pending, :mfa_complete) on Session struct type field (Phase 6)
- OAuth re-authentication for sudo mode on OAuth-only accounts (Phase 5)
- WebAuthn/passkey as re-auth method (v1.x)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESS-01 | Server-side database-backed sessions (opaque token in cookie, data in DB) | D-01/D-02: user_sessions table with hashed_token, Session struct. Existing SessionStore behaviour to redesign. |
| SESS-02 | Remember-me via separate long-lived cookie (default 60 days) | D-04/D-08/D-09: Same table, type=:remember_me, separate cookie. Update existing 14-day default to 60 days. |
| SESS-03 | Session invalidation on password change (all sessions except current) | D-05/D-16: delete_all on user_sessions except current token. Existing pattern in reset_password uses token deletion. |
| SESS-04 | "Log out everywhere" -- deletes all session tokens, broadcasts disconnect | D-16: Delete all + PubSub broadcast. Phoenix.PubSub already a dep via Phoenix. |
| SESS-05 | Active session tracking with IP, user agent, last-active timestamp | D-14/D-18: Columns in user_sessions. Library-side UA parser for friendly labels. |
| SESS-06 | Session management UI -- users can view and revoke active sessions | D-17/D-19: Generated LiveView with list/revoke. Current session indicator. |
| SESS-07 | Configurable idle timeout and absolute timeout | D-10/D-11: Idle (30min) + absolute (24h) for standard. Remember-me skips idle, absolute=max_age. |
| SESS-08 | Secure cookie defaults (SameSite=Lax, HttpOnly, Secure) | D-24/D-25: Set in Sigra.Plug.FetchSession. CSRF via Phoenix defaults. |
| SESS-09 | Sudo/re-authentication mode | D-20-D-23: sudo_at on session record, RequireSudo plug already stubbed, /users/sudo page. |
| SEC-01 | Account lockout after N failed attempts (default 5, 15 min) | D-26-D-32: failed_login_attempts column exists. Add locked_at timestamp check before hash verify. |
| SEC-02 | IP-based rate limiting (10/IP/min -> 429) | D-33-D-43: Hammer wrapper, Plug.RateLimit, Noop fallback. Hammer 7.3.0 confirmed in deps. |
| SEC-03 | Account-based rate limiting (failed attempts counter) | D-26/D-27: Uses existing failed_login_attempts column. Check in Sigra.Auth.authenticate before hashing. |
| SEC-04 | Email enumeration prevention | Already implemented in Phase 2. This phase maintains the pattern for lockout messages (D-30). |
| SEC-05 | CSRF protection integrated with Phoenix infrastructure | D-25: Relies on Phoenix defaults (SameSite=Lax + POST-only state changes). Document interaction. |
| SEC-06 | HMAC-protected tokens for all email flows | Already implemented in Phase 3. This phase extends for new email templates. |
| SEC-07 | Suspicious login detection -- new IP/device triggers email notification | D-44-D-48: Compare login IP against active session IPs. Async email via Oban. |
</phase_requirements>

## Standard Stack

### Core (already in mix.exs)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| hammer | 7.3.0 | Rate limiting (IP + account) | Already optional dep. ETS backend, no external infra. `use Hammer, backend: :ets` pattern. [VERIFIED: mix.lock shows 7.3.0] |
| phoenix_pubsub | 2.2.0 | Session disconnect broadcast | Transitive dep via Phoenix. Used for "log out everywhere" LiveView disconnect. [VERIFIED: mix.lock shows 2.2.0] |
| swoosh | ~> 1.5 | Lockout + suspicious login emails | Already optional dep. Phase 3 email infrastructure reused. [VERIFIED: mix.exs] |
| oban | ~> 2.17 | Async email delivery | Already optional dep. Phase 3 delivery pattern reused. [VERIFIED: mix.exs] |

### No New Dependencies Required
This phase introduces zero new dependencies. All functionality builds on existing deps (Hammer, Phoenix PubSub, Swoosh, Oban) or pure Elixir (UA parser, lockout logic, session management).

## Architecture Patterns

### Recommended Project Structure
```
lib/sigra/
  session.ex              # Sigra.Session struct (library-side, not Ecto)
  session_store.ex        # Redesigned behaviour (richer callbacks)
  session_stores/
    ecto.ex               # Default implementation against user_sessions
  geo_ip.ex               # GeoIP behaviour
  ua_parser.ex            # Lightweight user-agent parser
  lockout.ex              # Account lockout logic (check + lock + unlock)
  rate_limiters/
    hammer.ex             # Hammer 7.x wrapper implementing RateLimiter
    noop.ex               # (existing) fail-open fallback
  plug/
    rate_limit.ex         # IP rate limiting plug (new)
    fetch_session.ex      # (extend) cookie security, remember-me, timeout checks
    require_sudo.ex       # (extend) use sudo_at from session record
  auth.ex                 # (extend) lockout check, suspicious login, session CRUD
  config.ex               # (extend) new config sections
  telemetry.ex            # (extend) session + security events
  testing.ex              # (extend) session/security helpers
  workers/
    token_cleanup.ex      # (extend) session cleanup
  error.ex                # (extend) lockout error messages

priv/templates/sigra.install/
  migration.exs           # (extend) add user_sessions table
  user_session.ex         # NEW generated Ecto schema
  user_auth.ex            # (extend) remember-me cookie, session metadata
  auth.ex                 # (extend) session listing, revocation, lockout API
  session_live.ex         # NEW generated LiveView for session listing
  sudo_controller.ex      # NEW generated controller for sudo re-auth
  sudo_html.ex            # NEW generated template for sudo page
  emails.ex               # (extend) suspicious_login_email, lockout_email
```

### Pattern 1: Sigra.Session Struct (Library-Side)
**What:** A plain Elixir struct that represents a session, independent of Ecto. The generated `UserSession` Ecto schema maps to/from it.
**When to use:** All library-side session operations work with `%Sigra.Session{}`. The Ecto store converts between DB records and Session structs.

```elixir
# Source: Phase 4 CONTEXT.md D-01/D-02/D-03
defmodule Sigra.Session do
  @moduledoc "Library-side session representation."

  @type session_type :: :standard | :remember_me
  # Phase 6 will add: :mfa_pending | :mfa_complete

  @type t :: %__MODULE__{
    id: term(),
    user_id: term(),
    token: binary(),           # raw token (never stored; only in-memory)
    hashed_token: binary(),    # SHA-256 hash (stored in DB)
    type: session_type(),
    ip: String.t() | nil,
    user_agent: String.t() | nil,
    parsed_ua: map() | nil,    # %{browser: "Chrome", browser_version: "120", os: "macOS"}
    geo_city: String.t() | nil,
    geo_country_code: String.t() | nil,
    last_active_at: DateTime.t(),
    sudo_at: DateTime.t() | nil,
    inserted_at: DateTime.t()
  }

  defstruct [
    :id, :user_id, :token, :hashed_token,
    type: :standard,
    ip: nil, user_agent: nil, parsed_ua: nil,
    geo_city: nil, geo_country_code: nil,
    last_active_at: nil, sudo_at: nil, inserted_at: nil
  ]
end
```
[ASSUMED -- exact field types are Claude's discretion per CONTEXT.md]

### Pattern 2: Redesigned SessionStore Behaviour
**What:** Richer behaviour supporting CRUD + listing + revocation + metadata updates.

```elixir
# Source: CONTEXT.md D-02, D-14, D-16, D-17
defmodule Sigra.SessionStore do
  @callback create(user_id :: term(), metadata :: map(), opts :: keyword()) ::
    {:ok, Sigra.Session.t()}

  @callback fetch(token :: binary(), opts :: keyword()) ::
    {:ok, Sigra.Session.t()} | {:error, :not_found | :expired}

  @callback delete(token :: binary(), opts :: keyword()) :: :ok

  @callback list_by_user(user_id :: term(), opts :: keyword()) ::
    [Sigra.Session.t()]

  @callback delete_all_for_user(user_id :: term(), opts :: keyword()) ::
    {non_neg_integer(), nil}

  @callback update_activity(token :: binary(), metadata :: map(), opts :: keyword()) ::
    :ok | {:error, :not_found}

  @callback update_sudo(token :: binary(), sudo_at :: DateTime.t(), opts :: keyword()) ::
    :ok | {:error, :not_found}
end
```
[ASSUMED -- exact callback signatures are Claude's discretion per CONTEXT.md]

### Pattern 3: Hammer 7.x Wrapper
**What:** Adapts Hammer 7.x `hit/3` API to Sigra's `check_rate/3` behaviour.
**Critical detail:** Hammer 7.x uses `use Hammer, backend: :ets` to define a module, then calls `Module.hit(key, scale_ms, limit)` returning `{:allow, count}` or `{:deny, retry_after_ms}`. This matches Sigra's existing `RateLimiter` return type exactly.

```elixir
# Source: hexdocs.pm/hammer/Hammer.html [VERIFIED: Hammer 7.3.0 docs]
defmodule Sigra.RateLimiters.Hammer do
  @behaviour Sigra.RateLimiter

  # The Hammer rate limiter module must be started in the host app's
  # supervision tree. Sigra does NOT start it.
  # Hammer 7.x: use Hammer, backend: :ets creates a GenServer module.

  @impl Sigra.RateLimiter
  def check_rate(key, limit, window_ms) do
    # Hammer.hit/3 signature: hit(key, scale_ms, limit)
    # Note: Hammer's parameter order is (key, scale, limit) not (key, limit, scale)
    hammer_module().hit(key, window_ms, limit)
  end

  defp hammer_module do
    # Configurable via application env or default to Sigra.HammerBackend
    Application.get_env(:sigra, :hammer_module, Sigra.HammerBackend)
  end
end
```
[VERIFIED: Hammer 7.3.0 API confirmed via hexdocs.pm/hammer/Hammer.html -- hit/3 returns {:allow, count} | {:deny, ms}]

### Pattern 4: Lockout Logic
**What:** Check lockout status before password verification to save CPU.
**Key insight:** The `locked_at` column already exists in the migration template. The `failed_login_attempts` column also exists. The logic: if `failed_login_attempts >= threshold` AND `locked_at` is within lockout duration, return `{:error, :account_locked}`.

```elixir
# Source: CONTEXT.md D-26, D-29
defmodule Sigra.Lockout do
  @default_threshold 5
  @default_duration_seconds 900  # 15 minutes

  def check(user, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    duration = Keyword.get(opts, :duration, @default_duration_seconds)

    cond do
      is_nil(user) -> :ok  # Non-existent user, proceed to dummy hash
      user.failed_login_attempts < threshold -> :ok
      is_nil(user.locked_at) -> :ok
      locked_expired?(user.locked_at, duration) -> :ok
      true -> {:error, :account_locked, remaining_seconds(user.locked_at, duration)}
    end
  end

  defp locked_expired?(locked_at, duration) do
    DateTime.diff(DateTime.utc_now(), locked_at, :second) > duration
  end

  defp remaining_seconds(locked_at, duration) do
    elapsed = DateTime.diff(DateTime.utc_now(), locked_at, :second)
    max(duration - elapsed, 0)
  end
end
```
[ASSUMED -- exact API shape is Claude's discretion]

### Pattern 5: Suspicious Login Detection
**What:** Compare login IP against all active session IPs for the user.
**When to trigger:** Only on explicit login (password, magic link). NOT on remember-me rehydration.

```elixir
# Source: CONTEXT.md D-44, D-48
def detect_suspicious_login(user_id, login_ip, session_store, opts) do
  sessions = session_store.list_by_user(user_id, opts)
  known_ips = sessions |> Enum.map(& &1.ip) |> Enum.reject(&is_nil/1) |> MapSet.new()

  if login_ip not in known_ips and MapSet.size(known_ips) > 0 do
    {:suspicious, login_ip}
  else
    :ok
  end
end
```
[ASSUMED -- implementation detail]

### Pattern 6: Plug.RateLimit (IP-Based)
**What:** Router-level plug that rate limits by `conn.remote_ip`.

```elixir
# Source: CONTEXT.md D-34, D-36, D-38, D-39
defmodule Sigra.Plug.RateLimit do
  @behaviour Plug

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 10),
      window: Keyword.get(opts, :window, :timer.minutes(1)),
      key_prefix: Keyword.get(opts, :key_prefix, "sigra"),
      error_handler: Keyword.fetch!(opts, :error_handler),
      limiter: Keyword.get(opts, :limiter)  # resolved at call time if nil
    }
  end

  def call(%{method: method} = conn, _opts) when method in ["GET", "HEAD"], do: conn

  def call(conn, opts) do
    limiter = resolve_limiter(opts.limiter)
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    key = "#{opts.key_prefix}:ip:#{ip}"

    case limiter.check_rate(key, opts.limit, opts.window) do
      {:allow, _count} -> conn
      {:deny, retry_after_ms} ->
        retry_after_s = div(retry_after_ms + 999, 1000)
        conn
        |> Plug.Conn.put_resp_header("retry-after", Integer.to_string(retry_after_s))
        |> opts.error_handler.auth_error(:rate_limited, retry_after: retry_after_s)
        |> Plug.Conn.halt()
    end
  end
end
```
[ASSUMED -- exact implementation is Claude's discretion]

### Anti-Patterns to Avoid
- **Storing session data in cookie:** Cookie must contain only the opaque token reference. All session state lives in the DB. [CITED: CONTEXT.md D-01]
- **Checking lockout AFTER password hash:** Wastes CPU on Argon2id for locked accounts. Check lockout first (D-29).
- **Updating last_active_at on every request:** DB write storm on high-traffic apps. Throttle to every N minutes (D-13).
- **Using `inet` column type for IP:** Not portable across PostgreSQL/MySQL/SQLite. Store as string (D-63).
- **Indexing IP column:** Rare query pattern, index maintenance cost not justified (D-06).
- **Starting Hammer inside the library:** The host app's supervision tree must start the Hammer module. Library never owns GenServer lifecycle.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rate limiting | Custom ETS counter | Hammer 7.3.0 via RateLimiter behaviour | Fixed window, atomic increments, auto-cleanup, distributed option. Edge cases in concurrent access. [VERIFIED: hammer 7.3.0 in mix.lock] |
| Token generation | Custom random bytes | Existing `Sigra.Token.generate_hashed_token/0` | Already uses `:crypto.strong_rand_bytes(32)` + SHA-256. Phase 2 established pattern. |
| PubSub broadcast | Custom GenServer | `Phoenix.PubSub.broadcast/3` | Already a transitive dep. Handles node distribution. |
| User agent parsing | Full UAParser library | Lightweight regex module `Sigra.UAParser` | Only need browser name/version + OS. ~20 regex patterns covers 95% of traffic. External deps add maintenance burden for marginal gain. |
| CSRF protection | Custom CSRF layer | Phoenix built-in CSRF | SameSite=Lax + POST-only state changes. Phoenix handles this. [CITED: CONTEXT.md D-25] |

## Common Pitfalls

### Pitfall 1: Session Fixation on Login
**What goes wrong:** Reusing the same session token after authentication allows attackers who set a known session before login.
**Why it happens:** Not renewing the session ID on authentication state change.
**How to avoid:** The existing `user_auth.ex` template already calls `renew_session()` which does `configure_session(renew: true) |> clear_session()`. Ensure this pattern is preserved. [VERIFIED: priv/templates/sigra.install/user_auth.ex line 68-74]
**Warning signs:** Tests that login without checking session ID change.

### Pitfall 2: Timing Attacks on Lockout Check
**What goes wrong:** Lockout check before hash verification changes response timing, enabling account enumeration.
**Why it happens:** Locked accounts return faster than non-existent accounts (which do dummy hash).
**How to avoid:** Per D-29, this is acceptable because IP rate limiting covers timing attacks. The lockout check returns the same generic message as invalid credentials (D-30). Document this explicitly in code comments.
**Warning signs:** Different response times for locked vs non-existent accounts without IP rate limiting.

### Pitfall 3: Remember-Me Cookie Token Mismatch
**What goes wrong:** Remember-me token in cookie points to a deleted/expired session record in DB.
**Why it happens:** "Log out everywhere" deletes all session records but remember-me cookie persists in browser.
**How to avoid:** The fetch_session plug must check the remember-me cookie, find no matching DB record, and clear the cookie. This is the natural flow -- cookie present + DB miss = unauthenticated + cookie deleted.
**Warning signs:** Ghost sessions where user appears logged in but has no valid session.

### Pitfall 4: Race Condition on Concurrent Token Rotation
**What goes wrong:** Two simultaneous requests both try to rotate the same session token.
**Why it happens:** Token rotation happens on first request after reissue_age. If two requests arrive simultaneously, both may try to delete the old token and create a new one.
**How to avoid:** Use DB-level upsert or conditional delete (WHERE token = old_token). If the delete affects 0 rows, the other request already rotated it. Accept the new token from whichever request won.
**Warning signs:** Intermittent "session not found" errors in high-concurrency scenarios.

### Pitfall 5: Hammer Module Not Started
**What goes wrong:** `Sigra.RateLimiters.Hammer` calls `hit/3` but the Hammer GenServer was never started.
**Why it happens:** Library cannot start Hammer in its own supervision tree. Host app must add it.
**How to avoid:** The generator must add the Hammer module to the host app's supervision tree in `application.ex`. The Hammer wrapper should rescue GenServer timeouts and fall back to allow (fail-open) with a warning log. [CITED: CONTEXT.md D-41]
**Warning signs:** `{:noproc, ...}` errors in production logs.

### Pitfall 6: PubSub Topic Format for LiveView Disconnect
**What goes wrong:** "Log out everywhere" doesn't disconnect LiveView sockets because the broadcast topic doesn't match the LiveView mount topic.
**Why it happens:** phx.gen.auth uses `"users_sessions:#{Base.url_encode64(token)}"` as the `live_socket_id`. When deleting all sessions, you need to broadcast to each session's socket ID individually.
**How to avoid:** When revoking all sessions, iterate over session tokens and broadcast disconnect to each `"users_sessions:#{Base.url_encode64(token)}"`. Or use a user-level topic like `"user:#{user_id}:sessions"` that all LiveViews subscribe to. The existing template already uses the per-token pattern (verified in user_auth.ex line 84-86).
**Warning signs:** LiveView pages stay connected after "log out everywhere".

### Pitfall 7: IP Address Behind Reverse Proxy
**What goes wrong:** All requests show the proxy's IP, making per-IP rate limiting useless and suspicious login detection inaccurate.
**Why it happens:** `conn.remote_ip` defaults to the TCP peer, which is the proxy.
**How to avoid:** Document that apps behind proxies must use `remote_ip` or `plug_cloudflare` to set `conn.remote_ip` correctly. Per D-37, Sigra reads `conn.remote_ip` as-is. This is the standard Phoenix convention.
**Warning signs:** All sessions showing the same IP address.

## Code Examples

### Hammer 7.x Module Definition (Host App)

```elixir
# Source: hexdocs.pm/hammer/tutorial.html [VERIFIED]
# In host app, not in Sigra library
defmodule MyApp.RateLimit do
  use Hammer, backend: :ets
end

# In application.ex supervision tree:
children = [
  {MyApp.RateLimit, clean_period: :timer.minutes(1)}
]
```

### Session Creation with Metadata

```elixir
# Source: CONTEXT.md D-01, D-14
# In Sigra.Auth (library-side)
def create_session(user, conn, opts) do
  session_store = Keyword.fetch!(opts, :session_store)
  type = Keyword.get(opts, :type, :standard)

  metadata = %{
    type: type,
    ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
    user_agent: Plug.Conn.get_req_header(conn, "user-agent") |> List.first(),
    geo_city: resolve_geo(conn, opts, :city),
    geo_country_code: resolve_geo(conn, opts, :country_code)
  }

  session_store.create(user.id, metadata, opts)
end
```
[ASSUMED -- exact API shape]

### Cookie Security Defaults

```elixir
# Source: CONTEXT.md D-24
# In generated user_auth.ex
@session_cookie_name "_<%= otp_app %>_user_session"
@session_cookie_options [
  http_only: true,
  same_site: "Lax",
  secure: Mix.env() == :prod,
  sign: true
]

@remember_me_cookie "_<%= otp_app %>_user_remember_me"
@remember_me_options [
  http_only: true,
  same_site: "Lax",
  secure: Mix.env() == :prod,
  sign: true,
  max_age: 60 * 60 * 24 * 60  # 60 days
]
```
[VERIFIED: Existing user_auth.ex template already has @remember_me_options with sign: true and max_age]

### Throttled Activity Update

```elixir
# Source: CONTEXT.md D-13
defp maybe_update_activity(session, session_store, threshold_seconds, opts) do
  now = DateTime.utc_now()
  elapsed = DateTime.diff(now, session.last_active_at, :second)

  if elapsed >= threshold_seconds do
    session_store.update_activity(session.hashed_token, %{last_active_at: now}, opts)
  end
end
```
[ASSUMED -- implementation detail]

### Idle + Absolute Timeout Check

```elixir
# Source: CONTEXT.md D-10, D-11
defp session_valid?(session, config) do
  now = DateTime.utc_now()

  absolute_limit = case session.type do
    :remember_me -> config.session[:remember_me_max_age]
    _ -> config.session[:absolute_timeout] || 86_400
  end

  idle_limit = case session.type do
    :remember_me -> nil  # skip idle timeout
    _ -> config.session[:idle_timeout] || 1_800
  end

  absolute_ok = DateTime.diff(now, session.inserted_at, :second) < absolute_limit
  idle_ok = is_nil(idle_limit) or DateTime.diff(now, session.last_active_at, :second) < idle_limit

  absolute_ok and idle_ok
end
```
[ASSUMED -- implementation detail]

### Sudo Mode Check (Updated from Current Stub)

```elixir
# Source: CONTEXT.md D-22
# Current RequireSudo uses conn.assigns[:authenticated_at]
# Phase 4 changes to use session.sudo_at from the DB record
defp sudo_fresh?(session, sudo_window) do
  case session.sudo_at do
    nil -> false
    %DateTime{} = sudo_at ->
      DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= sudo_window
  end
end
```
[VERIFIED: Current RequireSudo plug (lib/sigra/plug/require_sudo.ex) uses `conn.assigns[:authenticated_at]`. Phase 4 redesigns to use `session.sudo_at`.]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| user_tokens with context "session" | Separate user_sessions table | Phase 4 (this phase) | Richer session metadata, independent lifecycle from email tokens |
| Single cookie (session or remember-me) | Two distinct cookies | Phase 4 (this phase) | Standard session is browser-scoped, remember-me is persistent |
| No lockout | DB-persisted lockout with auto-unlock | Phase 4 (this phase) | Prevents brute force |
| No rate limiting (Noop default) | Hammer ETS rate limiting | Phase 4 (this phase) | IP-level protection |
| RequireSudo from conn.assigns[:authenticated_at] | RequireSudo from session.sudo_at in DB | Phase 4 (this phase) | Persisted sudo state, survives reconnects |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Sigra.Session struct field types as described | Architecture Pattern 1 | Low -- Claude's discretion per CONTEXT.md |
| A2 | SessionStore behaviour callback signatures as described | Architecture Pattern 2 | Low -- Claude's discretion per CONTEXT.md |
| A3 | Lockout module API shape | Architecture Pattern 4 | Low -- internal implementation detail |
| A4 | Hammer wrapper resolves module via Application.get_env | Architecture Pattern 3 | Medium -- could use config struct instead, but app env is simpler for GenServer reference |
| A5 | UA parser covers ~95% of traffic with ~20 regex patterns | Don't Hand-Roll | Low -- approximate claim, actual coverage depends on pattern quality |

**All critical claims about Hammer API, existing codebase structure, and Phoenix PubSub are verified.**

## Open Questions (RESOLVED)

1. **Hammer Module Reference Pattern**
   - What we know: Hammer 7.x requires a module defined with `use Hammer, backend: :ets` and started in the supervision tree. Sigra's wrapper needs to call `Module.hit/3`.
   - What's unclear: Best way for the wrapper to discover the host app's Hammer module name. Options: (a) Application.get_env, (b) pass in config struct, (c) convention-based module name.
   - RESOLVED: Use `Application.get_env(:sigra, :hammer_module)` with generator setting it automatically. Simple, works at runtime.

2. **PubSub Module Reference for "Log Out Everywhere"**
   - What we know: The existing user_auth.ex template calls `Endpoint.broadcast/3` which uses the endpoint's PubSub.
   - What's unclear: Library-side code (`Sigra.Auth`) needs PubSub access to broadcast disconnect. Library doesn't know the endpoint module.
   - RESOLVED: Accept `pubsub_module` in opts or config. Generated code passes `MyApp.PubSub`. Library calls `Phoenix.PubSub.broadcast/3` directly.

3. **Session Cleanup Batch Size**
   - What we know: TokenCleanup already uses `delete_all` per context. Sessions need similar cleanup.
   - What's unclear: Whether to batch deletes for very large session tables.
   - RESOLVED: Start with simple `delete_all` with WHERE clause (same as tokens). Add batching if performance issues arise. This is Claude's discretion per CONTEXT.md.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + Mox 1.1 |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test --only phase4` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-01 | Sessions stored in user_sessions table with hashed token | unit | `mix test test/sigra/session_test.exs -x` | No -- Wave 0 |
| SESS-02 | Remember-me creates separate long-lived cookie + DB record | unit | `mix test test/sigra/session_test.exs -x` | No -- Wave 0 |
| SESS-03 | Password change invalidates all sessions except current | unit | `mix test test/sigra/auth_test.exs -x` | Partial -- extend existing |
| SESS-04 | Log out everywhere deletes all + broadcasts PubSub | unit | `mix test test/sigra/session_test.exs -x` | No -- Wave 0 |
| SESS-05 | Session tracks IP, UA, last_active_at | unit | `mix test test/sigra/session_test.exs -x` | No -- Wave 0 |
| SESS-06 | Session listing returns all active sessions for user | unit | `mix test test/sigra/session_test.exs -x` | No -- Wave 0 |
| SESS-07 | Idle + absolute timeout correctly expires sessions | unit | `mix test test/sigra/session_test.exs -x` | No -- Wave 0 |
| SESS-08 | Cookie options include HttpOnly, SameSite, Secure | unit | `mix test test/sigra/plug/fetch_session_test.exs -x` | Partial -- extend |
| SESS-09 | Sudo mode checks sudo_at timestamp within window | unit | `mix test test/sigra/plug/require_sudo_test.exs -x` | Partial -- extend |
| SEC-01 | Account locks after 5 failed attempts for 15 min | unit | `mix test test/sigra/lockout_test.exs -x` | No -- Wave 0 |
| SEC-02 | IP rate limiting returns 429 with Retry-After | unit | `mix test test/sigra/plug/rate_limit_test.exs -x` | No -- Wave 0 |
| SEC-03 | Failed attempts counter increments on wrong password | unit | `mix test test/sigra/auth_test.exs -x` | Partial -- extend |
| SEC-04 | Lockout message is enumeration-safe | unit | `mix test test/sigra/error_test.exs -x` | Partial -- extend |
| SEC-05 | CSRF documented, cookie defaults set | unit | `mix test test/sigra/plug/fetch_session_test.exs -x` | Partial -- extend |
| SEC-06 | HMAC tokens for new email templates | unit | existing | Already covered by Phase 3 |
| SEC-07 | Suspicious login detected on new IP | unit | `mix test test/sigra/suspicious_login_test.exs -x` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test --only phase4`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/session_test.exs` -- covers SESS-01 through SESS-07
- [ ] `test/sigra/lockout_test.exs` -- covers SEC-01, SEC-03
- [ ] `test/sigra/plug/rate_limit_test.exs` -- covers SEC-02
- [ ] `test/sigra/suspicious_login_test.exs` -- covers SEC-07
- [ ] `test/sigra/ua_parser_test.exs` -- covers SESS-05 (UA parsing)
- [ ] `test/sigra/rate_limiters/hammer_test.exs` -- covers Hammer wrapper
- [ ] Add `Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)` to test_helper.exs
- [ ] Add `Mox.defmock(Sigra.MockGeoIP, for: Sigra.GeoIP)` to test_helper.exs

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Lockout after N failed attempts (D-26), constant-time comparison preserved |
| V3 Session Management | Yes | Database-backed sessions, secure cookie flags, idle + absolute timeout, rotation |
| V4 Access Control | Yes | Sudo mode for sensitive operations |
| V5 Input Validation | Yes | NimbleOptions for config, rate limit params validated in plug init |
| V6 Cryptography | No | No new crypto -- reuses existing token hashing from Phase 2 |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Session fixation | Spoofing | Renew session ID on login (already implemented in user_auth.ex) |
| Brute force login | Tampering | Account lockout (D-26) + IP rate limiting (D-34) |
| Session hijacking | Spoofing | HttpOnly + Secure + SameSite cookies (D-24), DB-backed tokens |
| Account enumeration via lockout | Information Disclosure | Generic error messages (D-30), same timing for locked + non-existent |
| DoS via account lockout | Denial of Service | Temporary lockout only (15 min), auto-unlock (D-26) |
| Credential stuffing | Spoofing | IP rate limiting (10/min), suspicious login detection |
| Session riding (CSRF) | Tampering | Phoenix CSRF + SameSite=Lax + POST-only mutations (D-25) |
| New device attack | Spoofing | Suspicious login email notification (D-44) |

## Sources

### Primary (HIGH confidence)
- Hammer 7.3.0 docs -- [hexdocs.pm/hammer/Hammer.html](https://hexdocs.pm/hammer/Hammer.html) -- API: `hit/3` returns `{:allow, count} | {:deny, ms}`, `use Hammer, backend: :ets` pattern
- Hammer tutorial -- [hexdocs.pm/hammer/tutorial.html](https://hexdocs.pm/hammer/tutorial.html) -- setup, supervision tree, key format
- Existing codebase (verified via Read tool):
  - `lib/sigra/session_store.ex` -- current 3-callback behaviour
  - `lib/sigra/rate_limiter.ex` -- current check_rate/3 callback
  - `lib/sigra/rate_limiters/noop.ex` -- fail-open fallback
  - `lib/sigra/plug/fetch_session.ex` -- current session fetch logic
  - `lib/sigra/plug/require_sudo.ex` -- current sudo stub using authenticated_at
  - `lib/sigra/auth.ex` -- current authenticate/register/magic_link
  - `lib/sigra/config.ex` -- current NimbleOptions schema
  - `lib/sigra/workers/token_cleanup.ex` -- current cleanup worker
  - `priv/templates/sigra.install/migration.exs` -- current migration (user_tokens, no user_sessions yet)
  - `priv/templates/sigra.install/user_auth.ex` -- current generated UserAuth with remember_me cookie
  - `priv/templates/sigra.install/auth.ex` -- current generated Auth context
  - `mix.exs` -- dependency versions confirmed

### Secondary (MEDIUM confidence)
- [GitHub ExHammer/hammer](https://github.com/ExHammer/hammer) -- repository, README

### Tertiary (LOW confidence)
- None. All claims verified against codebase or official docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all deps already in mix.exs and verified in mix.lock
- Architecture: HIGH -- all patterns derived from locked CONTEXT.md decisions + verified existing code
- Pitfalls: HIGH -- based on direct code inspection and established Phoenix security patterns

**Research date:** 2026-04-07
**Valid until:** 2026-05-07 (stable domain, no fast-moving dependencies)
