# Phase 4: Session Management and Security Baseline - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Sessions are database-backed and fully controllable, with secure cookie defaults, configurable timeouts, account lockout, IP-based rate limiting, suspicious login detection, and sudo/re-authentication. A developer's users can view and revoke active sessions, accounts lock after failed attempts, IPs are rate-limited, and login from a new device triggers an email notification.

</domain>

<decisions>
## Implementation Decisions

### Session Architecture
- **D-01:** Separate `user_sessions` table (not extending user_tokens). Columns: id, user_id, hashed_token, type, ip, user_agent, geo_city (nullable), geo_country_code (nullable), last_active_at, sudo_at (nullable), inserted_at. user_tokens stays purely for email tokens.
- **D-02:** Redesign `SessionStore` behaviour with a richer `Sigra.Session` struct interface. Sigra.Session is a library struct (not Ecto schema); generated `UserSession` Ecto schema maps to/from it. Follows hybrid architecture pattern.
- **D-03:** Session struct includes explicit `:type` field (`:standard`, `:remember_me`). Different types get different timeout rules. Phase 6 adds MFA states (`:mfa_pending`, `:mfa_complete`).
- **D-04:** Remember-me sessions stored in same `user_sessions` table with `type: :remember_me`. One table, one behaviour implementation, unified listing and revocation.
- **D-05:** Update Phase 1 migration template to include `user_sessions` table (since Phases 1-3 haven't been executed). New installs get one clean migration. Refactor Phase 2 session code to use user_sessions instead of user_tokens with context "session".
- **D-06:** Indexes: unique on hashed_token, index on user_id, index on (user_id, type), index on inserted_at (for cleanup). No index on IP.
- **D-07:** Extend existing `Sigra.Workers.TokenCleanup` to also clean up expired sessions. One cron job, two cleanup tasks.

### Remember-Me
- **D-08:** Separate cookie design: standard session cookie (browser-scoped) + separate remember-me cookie (60-day default, configurable). Remember-me cookie rehydrates a new session after browser restart. Two distinct tokens in DB.
- **D-09:** Update remember_me_max_age default from 14 days to 60 days per requirements.

### Timeouts
- **D-10:** Both idle timeout AND absolute timeout. Idle: 30 minutes of inactivity (default). Absolute: 24 hours regardless of activity (default). Both configurable.
- **D-11:** Remember-me sessions skip idle timeout (user explicitly chose to stay logged in). Absolute timeout = remember_me_max_age (60 days). Token rotation still applies.
- **D-12:** Session token rotation: reissue after reissue_age (7 days default) on next request. Old token deleted. phx.gen.auth pattern.
- **D-13:** Throttled last_active_at updates: only write to DB if more than N minutes since last update (default 5 min). Reduces DB writes on high-traffic apps. Configurable threshold.

### Session Listing and Revocation
- **D-14:** IP + user agent + last_active_at tracked per session. Geo (city, country) via optional GeoIP behaviour.
- **D-15:** GeoIP via `Sigra.GeoIP` behaviour with `lookup/1` callback. No default implementation shipped. Developers plug in geolix or similar. Fields are nil when no adapter configured. Same optional-dep pattern as Hammer. Config in own `geo_ip:` section.
- **D-16:** Log out everywhere: delete all session tokens + broadcast disconnect via PubSub so LiveView sockets drop immediately.
- **D-17:** Context functions + generated LiveView for session listing. `Sigra.Auth` exposes `list_sessions/2` and `revoke_session/2`. Generated LiveView shows active sessions with revoke buttons.
- **D-18:** Library-side UA parser (lightweight, regex-based, no external dep). Returns structured data: `%{browser: "Chrome", browser_version: "120", os: "macOS"}`. Generated LiveView uses it for friendly labels.
- **D-19:** Current session indicator: match session token from request against list, tag as "This device", confirm before revoking (logs user out).

### Sudo Mode
- **D-20:** Implement sudo mode in Phase 4 (pulling SESS-09 forward from Phase 8). Session infrastructure is being built here -- natural fit.
- **D-21:** Sudo window: 5 minutes (configurable). Password-only re-authentication. MFA re-auth added in Phase 6. OAuth-only users re-auth via OAuth provider.
- **D-22:** Sudo state stored as `sudo_at` timestamp on session record. Check: "is sudo_at within the last 5 minutes?"
- **D-23:** RequireSudo plug redirects to `/users/sudo` with `return_to` param. User enters password, gets redirected back. Works for both controllers and LiveView. GitHub's pattern.

### Cookie Security
- **D-24:** Library sets secure defaults in `Sigra.Plug.FetchSession`: HttpOnly=true, SameSite=Lax, Secure=true (prod). Generated UserAuth can override.
- **D-25:** CSRF protection relies on Phoenix defaults. SameSite=Lax + POST-only state changes. No custom CSRF layer. Document the interaction.

### Account Lockout
- **D-26:** Fixed threshold: 5 attempts = 15 min lockout (both configurable). No escalation. Counter resets on successful login. Lockout auto-unlocks after duration.
- **D-27:** Lockout counter tracks failed password attempts only. Magic link requests rate-limited separately. Magic link failures don't increment lockout counter.
- **D-28:** Lockout notification email sent on every lockout. Uses Phase 3 email infrastructure (async via Oban).
- **D-29:** Lockout check happens before password hash verification (saves CPU). Slight timing difference acceptable because IP rate limiting covers timing attacks.
- **D-30:** Lockout UX: generic message "Invalid email or password" plus "Too many attempts. Try again in a few minutes." Enumeration-safe (same message for wrong email).
- **D-31:** Lockout hooks via telemetry only (`[:sigra, :security, :lockout]`). No callback behaviour.
- **D-32:** Lockout status exposed via context API: `locked?/1` and `lock_status/1` (returns `{:locked, remaining_seconds}` | `:unlocked`). Available for admin dashboards.

### Rate Limiting
- **D-33:** Thin `Sigra.RateLimiters.Hammer` wrapper implementing existing `RateLimiter` behaviour. Auto-detected via `Code.ensure_loaded?(Hammer)`. Same optional-dep pattern as Oban/bcrypt.
- **D-34:** IP rate limiting via `Sigra.Plug.RateLimit` plug in router pipeline. Account rate limiting inline in `Sigra.Auth.authenticate/2`. Clean separation.
- **D-35:** Rate limit all auth entry points by IP: login, registration, password reset request, magic link request. Default: 10 requests per IP per minute. Each endpoint rate-limited independently.
- **D-36:** Per-route configurable: `plug Sigra.Plug.RateLimit, limit: 10, window: :timer.minutes(1), key_prefix: "login"`. Different routes can have different limits.
- **D-37:** Client IP extracted from `conn.remote_ip`. Document that apps behind proxies should use `remote_ip` or `plug_cloudflare` to set `conn.remote_ip` correctly.
- **D-38:** POST only: rate limit only state-changing operations. GET requests for form rendering are not rate limited.
- **D-39:** 429 response content-negotiated: JSON for API requests (`{"error": "rate_limited", "retry_after": 45}`), flash redirect for browser requests. Retry-After header in both. Uses ErrorHandler behaviour.
- **D-40:** Retry-After header on 429 only. Don't include X-RateLimit-Remaining on normal requests (don't leak rate limit config to attackers).
- **D-41:** When Hammer absent: Noop fallback with startup warning. Fail open -- auth still works, just unprotected. Document prominently in install guide.
- **D-42:** Rate limit state in ETS only (no persistence). Resets on app restart. Acceptable -- lockout is in DB (persists), rate limit windows are short (1 min).
- **D-43:** Generator includes RateLimit plug in generated auth routes by default. Secure by default, visible in developer's router code.

### Suspicious Login Detection
- **D-44:** Trigger: new IP address on explicit login only (password, magic link). Compare login IP against all active session IPs for the user. No separate known_ips table -- derive from existing sessions.
- **D-45:** Remember-me rehydration does NOT trigger suspicious login notification.
- **D-46:** Notification email: IP address, approximate location (if GeoIP configured), timestamp, device info (parsed UA). "Not you? Secure your account" link to password change page. Async delivery via Phase 3 email infrastructure.
- **D-47:** No user opt-out. Always notify (security feature). Developer configurable: `suspicious_login:` section with `enabled: true, notify: true`.
- **D-48:** IP history: check all non-expired session records for the user. Naturally bounded by session TTL.

### Config Surface
- **D-49:** Extend existing `session:` section with: idle_timeout (1800s), absolute_timeout (86400s), activity_update_threshold (300s), sudo_timeout (300s).
- **D-50:** New `lockout:` section with: threshold (5), duration (900s), notify (true).
- **D-51:** Existing `rate_limiting:` section unchanged (already has ip_limit, ip_window_ms, account_limit, limiter).
- **D-52:** New `geo_ip:` section with: module (nil -- disabled by default).
- **D-53:** New `suspicious_login:` section with: enabled (true), notify (true).

### Telemetry
- **D-54:** Session telemetry: `[:sigra, :session, :create, :start/:stop]`, `[:sigra, :session, :delete, :start/:stop]`, `[:sigra, :session, :revoke_all, :stop]`, `[:sigra, :session, :sudo, :start/:stop]`. Metadata: user_id, session_type, ip.
- **D-55:** Security events as one-shot: `[:sigra, :security, :lockout]`, `[:sigra, :security, :rate_limited]`, `[:sigra, :security, :suspicious_login]`. No start/stop -- point-in-time signals. Metadata: user_id (if known), ip, reason.
- **D-56:** Default logger: security events at `:warning` level, session operations at `:info`.
- **D-57:** Suspicious login telemetry includes geo_city and geo_country_code in metadata when GeoIP configured.
- **D-58:** Key events specified above are locked. Claude has discretion on additional events and exact metadata shapes during planning.

### Testing
- **D-59:** New Sigra.Testing helpers: `create_session/2`, `list_sessions/1`, `assert_session_revoked/1`, `simulate_lockout/1`, `assert_rate_limited/1`, `assert_suspicious_login_sent/1`.
- **D-60:** Hammer tested via Mox: `Mox.defmock(MockRateLimiter, for: Sigra.RateLimiter)`. No Hammer needed in unit tests. Integration tests can use Hammer ETS backend directly.
- **D-61:** Generated test fixtures: `session_fixture/1`, `remembered_session_fixture/1`, `locked_user_fixture/1`, `sudo_session_fixture/1`. ConnCase `log_in_user/2` updated with session type options.

### Email Templates
- **D-62:** Phase 4 generates `suspicious_login_email/2` and `lockout_notification_email/2` in existing `MyApp.Auth.Emails` module. Extends Phase 3's email infrastructure.

### Multi-Database
- **D-63:** Claude handles multi-DB concerns for sessions table. IP stored as string (not inet) for portability. Timestamps as utc_datetime_usec.

### Claude's Discretion
- SessionStore behaviour exact callback signatures and Session struct field types
- UA parser implementation details (regex patterns, browser/OS coverage)
- Exact LiveView component design for session listing
- Session cleanup frequency and batch size
- Rate limit key formatting in Hammer
- Sudo re-auth page generated template design
- Additional telemetry events and metadata beyond the specified core events

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` -- Vision, architecture philosophy, hybrid lib+generator rationale
- `.planning/REQUIREMENTS.md` -- SESS-01 through SESS-09, SEC-01 through SEC-07 requirements
- `.planning/ROADMAP.md` SS Phase 4 -- Goal, success criteria, requirement mapping

### Phase 1 context (foundation)
- `.planning/phases/01-foundation/01-CONTEXT.md` -- D-05 (NimbleOptions config), D-12 (SessionStore behaviour), D-13 (default implementations), D-15-18 (telemetry patterns), D-23 (schema design -- users, user_tokens tables), D-28-31 (plug architecture), D-35-37 (optional dep handling), D-43-45 (API naming), D-48-50 (security defaults)

### Phase 2 context (core auth)
- `.planning/phases/02-core-auth/02-CONTEXT.md` -- D-30-34 (login attempt tracking, failed_login_attempts column), D-35-38 (session token format, cookie name, TTL), D-44-46 (error messages, enumeration prevention), D-47-49 (Sigra.Auth library module), D-53-55 (controllers primary, LiveView optional)

### Phase 3 context (email flows)
- `.planning/phases/03-email-flows-and-transactional-email/03-CONTEXT.md` -- D-18 (email module structure), D-21-27 (Oban/async delivery), D-45-46 (testing helpers), D-51 (library/generated code boundary)

### Existing code to extend
- `lib/sigra/session_store.ex` -- SessionStore behaviour (redesign with richer Session struct)
- `lib/sigra/rate_limiter.ex` -- RateLimiter behaviour (implement Hammer wrapper)
- `lib/sigra/rate_limiters/noop.ex` -- Noop rate limiter fallback
- `lib/sigra/plug/fetch_session.ex` -- FetchSession plug (add cookie security defaults, remember-me handling)
- `lib/sigra/config.ex` -- Add session timeout, lockout, geo_ip, suspicious_login config sections
- `lib/sigra/auth.ex` -- Add lockout check, session listing, revocation, sudo functions
- `lib/sigra/telemetry.ex` -- Add session and security event catalog
- `lib/sigra/testing.ex` -- Add session and security testing helpers
- `lib/sigra/workers/token_cleanup.ex` -- Extend with session cleanup
- `lib/sigra/error.ex` -- Add lockout, rate_limited error types

### Research documents
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` -- Ecosystem analysis, prior art
- `CLAUDE.md` SS Technology Stack -- Hammer 7.x, dependency versions, version compatibility matrix

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.SessionStore` -- Behaviour with fetch/create/delete. Will be redesigned with richer interface.
- `Sigra.RateLimiter` -- Behaviour with check_rate/3 callback. Ready for Hammer implementation.
- `Sigra.RateLimiters.Noop` -- Fail-open fallback. Already implemented.
- `Sigra.Plug.FetchSession` -- Reads session token from Plug session, assigns current_scope. Extend with cookie security defaults and remember-me handling.
- `Sigra.Plug.ErrorHandler` -- Behaviour with auth_error/3. Types include :rate_limited. Ready for 429 responses.
- `Sigra.Config` -- NimbleOptions validated. Already has session section (remember_me_max_age, reissue_age, store) and rate_limiting section (ip_limit, ip_window_ms, account_limit, limiter).
- `Sigra.Auth` -- Orchestrator with register/authenticate/create_session/verify_session. Extend with lockout, listing, revocation, sudo.
- `Sigra.Telemetry` -- span/3, event/3, attach_default_logger/1. Event catalog ready for extension.
- `Sigra.Testing` -- Assertion helpers. Extend with session/security helpers.
- `Sigra.Workers.TokenCleanup` -- Daily Oban cron. Extend with session cleanup.
- `Sigra.Error` -- Exception types with safe_message/1. Extend with lockout/rate_limited errors.

### Established Patterns
- `{:ok, result}` | `{:error, reason}` everywhere (Phase 1 D-19)
- Behaviours for extensibility, default implementations (Phase 1 D-12/13)
- Telemetry span for sync ops, one-shot events for signals (Phase 1 D-15/18)
- NimbleOptions for all config (Phase 1 D-05)
- `Code.ensure_loaded?` for optional deps (Phase 1 D-35)
- Enumeration-safe responses with dummy hash timing (Phase 2 D-44)
- phx.gen.auth naming conventions (Phase 2 D-43)
- Async email delivery via Oban with inline fallback (Phase 3 D-21-27)

### Integration Points
- `Sigra.Plug.FetchSession` gains cookie security defaults and remember-me handling
- New `Sigra.Plug.RateLimit` plug for router pipeline (IP-based)
- New `Sigra.Plug.RequireSudo` plug (already spec'd in Phase 1 D-28)
- New `Sigra.GeoIP` behaviour with optional adapter
- New `Sigra.Session` library struct
- Generated `UserSession` Ecto schema mapping to/from Sigra.Session
- Generated sessions LiveView component
- Generated sudo re-auth page
- Generated email templates: suspicious_login_email/2, lockout_notification_email/2
- Router: new routes for session management and sudo re-auth
- Phase 1 migration template updated with user_sessions table

</code_context>

<specifics>
## Specific Ideas

- GitHub's sudo mode pattern: redirect to /users/sudo with return_to, enter password, redirect back
- Session listing should feel like GitHub/Google's "active sessions" page -- device name, location, last active, current session highlighted
- Lockout notification email should be actionable: "If this wasn't you, consider changing your password"
- Suspicious login email should include "Not you? Secure your account" link to password change
- UA parsing should produce friendly labels like "Chrome 120 on macOS" not raw UA strings
- RateLimit plug should be visible in generated router code (secure by default, developer can see and adjust)
- Phase 2 session code should be retroactively updated to use user_sessions table (since no code has been executed)

</specifics>

<deferred>
## Deferred Ideas

- MFA-aware sudo re-authentication (Phase 6 -- MFA adds TOTP/backup code as re-auth option)
- MFA session states (:mfa_pending, :mfa_complete) on Session struct type field (Phase 6)
- OAuth re-authentication for sudo mode on OAuth-only accounts (Phase 5)
- WebAuthn/passkey as re-auth method (v1.x)

</deferred>

---

*Phase: 04-session-management-and-security-baseline*
*Context gathered: 2026-04-07*
