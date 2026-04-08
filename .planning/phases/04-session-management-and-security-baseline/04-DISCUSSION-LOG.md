# Phase 4: Session Management and Security Baseline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-07
**Phase:** 04-session-management-and-security-baseline
**Areas discussed:** Session lifecycle, Lockout policy, Rate limiting, Suspicious login, Migration strategy, Telemetry events, Config surface, Testing strategy

---

## Session Lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| Separate cookie | Standard session + separate remember-me cookie (60-day). Two distinct tokens. | ✓ |
| Single cookie with flag | One cookie with max_age set on remember-me. | |
| You decide | Claude picks. | |

**User's choice:** Separate cookie
**Notes:** Matches phx.gen.auth and Devise pattern.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Both idle + absolute | 30min idle + 24h absolute. OWASP recommends both. | ✓ |
| Absolute only | Fixed duration regardless of activity. | |
| Idle only | Expires after inactivity, no upper bound. | |
| You decide | Claude picks. | |

**User's choice:** Both idle + absolute

---

| Option | Description | Selected |
|--------|-------------|----------|
| IP + UA + last active | Store IP, user agent string, last_active_at. | |
| IP + UA + last active + geo | Same plus city/country from GeoIP. | |
| You decide | Claude picks. | |

**User's choice:** IP + UA + last active, but user wanted geo too. Discussed lift and decided on behaviour + optional adapter approach.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Behaviour + optional adapter | Geo fields on session, Sigra.GeoIP behaviour, no default impl. | ✓ |
| Bundle geolix as optional dep | Ship adapter with Code.ensure_loaded? detection. | |
| Defer to future phase | Track IP + UA + last_active only. | |

**User's choice:** Behaviour + optional adapter

---

| Option | Description | Selected |
|--------|-------------|----------|
| Delete all + disconnect LiveView | Delete tokens + PubSub broadcast for LiveView socket disconnect. | ✓ |
| Delete all tokens only | Just delete from DB. | |
| You decide | Claude picks. | |

**User's choice:** Delete all + disconnect LiveView

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, rotate on activity | Reissue after reissue_age (7 days). phx.gen.auth pattern. | ✓ |
| No rotation | Token stays same for lifetime. | |
| You decide | Claude picks. | |

**User's choice:** Yes, rotate on activity

---

| Option | Description | Selected |
|--------|-------------|----------|
| 30min idle / 24h absolute | OWASP-aligned defaults. | ✓ |
| 60min idle / 7d absolute | More relaxed. | |
| You decide | Claude picks. | |

**User's choice:** 30min idle / 24h absolute

---

| Option | Description | Selected |
|--------|-------------|----------|
| No idle, longer absolute | Remember-me skips idle timeout. Absolute = remember_me_max_age. | ✓ |
| Same timeouts as regular | Remember-me only rehydrates after browser close. | |
| You decide | Claude picks. | |

**User's choice:** No idle, longer absolute

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, implement now | Pull SESS-09 forward. Session infrastructure built here. | ✓ |
| Defer to Phase 8 | Keep in Account Lifecycle. | |
| You decide | Claude decides. | |

**User's choice:** Yes, implement now

---

| Option | Description | Selected |
|--------|-------------|----------|
| 5 minutes | GitHub uses 5 min. Short but sufficient. | ✓ |
| 15 minutes | AWS uses 15 min. Less friction. | |
| You decide | Claude picks. | |

**User's choice:** 5 minutes

---

| Option | Description | Selected |
|--------|-------------|----------|
| Context functions only | Sigra.Auth exposes functions. No generated UI. | |
| Context + generated LiveView | Functions plus generated LiveView with session listing and revoke. | ✓ |
| You decide | Claude picks. | |

**User's choice:** Context + generated LiveView

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, typed sessions | Session struct has :type field (:standard, :remember_me). | ✓ |
| Infer from context | No type field, infer from cookies/timestamps. | |
| You decide | Claude picks. | |

**User's choice:** Yes, typed sessions

---

| Option | Description | Selected |
|--------|-------------|----------|
| Throttled updates | Update last_active_at only if >5min since last update. | ✓ |
| Every request | DB write every authenticated request. | |
| You decide | Claude picks. | |

**User's choice:** Throttled updates

---

| Option | Description | Selected |
|--------|-------------|----------|
| Replace with richer interface | Redesign with Session struct. | ✓ |
| Extend with new callbacks | Add callbacks, keep existing 3. | |
| You decide | Claude picks. | |

**User's choice:** Replace with richer interface

---

| Option | Description | Selected |
|--------|-------------|----------|
| Library sets secure defaults | Sigra.Plug.FetchSession configures HttpOnly, SameSite, Secure. | ✓ |
| Generated code configures | Cookie options in generated UserAuth. | |
| You decide | Claude picks. | |

**User's choice:** Library sets secure defaults

---

| Option | Description | Selected |
|--------|-------------|----------|
| Library struct, Ecto schema generated | Sigra.Session as plain struct. Generated UserSession Ecto schema. | ✓ |
| Library Ecto schema | Sigra.Session as Ecto schema in library. | |
| You decide | Claude picks. | |

**User's choice:** Library struct, Ecto schema generated

---

| Option | Description | Selected |
|--------|-------------|----------|
| Rely on Phoenix defaults | SameSite=Lax + POST-only. Document interaction. | ✓ |
| Add Sigra-specific CSRF layer | Custom CSRF validation in plugs. | |
| You decide | Claude picks. | |

**User's choice:** Rely on Phoenix defaults

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, library-side parsing | Lightweight regex UA parser. Returns browser/OS struct. | ✓ |
| Raw UA string only | Store and display raw. | |
| You decide | Claude picks. | |

**User's choice:** Yes, library-side parsing

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, highlight current | Match token, tag "This device", confirm before revoking. | ✓ |
| No special treatment | All sessions look same. | |
| You decide | Claude picks. | |

**User's choice:** Yes, highlight current

---

| Option | Description | Selected |
|--------|-------------|----------|
| Password only | Enter current password to elevate. MFA added Phase 6. | ✓ |
| Any valid auth method | Password, MFA, or magic link. | |
| You decide | Claude picks. | |

**User's choice:** Password only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Timestamp on session record | sudo_at field on session. Check within 5 min. | ✓ |
| Separate session key | Store in Plug.Session data. | |
| You decide | Claude picks. | |

**User's choice:** Timestamp on session record

---

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect to re-auth page | /users/sudo with return_to. GitHub pattern. | ✓ |
| Inline in LiveView | Password modal overlay. | |
| You decide | Claude picks. | |

**User's choice:** Redirect to re-auth page

---

## Lockout Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-unlock after duration | 15 min lockout, auto-unlock. Counter resets. | ✓ |
| Auto-unlock + email unlock link | Auto-unlock AND instant unlock via email. | |
| Manual unlock only | Stays locked until admin/user action. | |

**User's choice:** Auto-unlock after duration

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, on every lockout | Email notification on lockout. Uses Phase 3 infra. | ✓ |
| No lockout emails | Silent lockout. | |
| You decide | Claude picks. | |

**User's choice:** Yes, on every lockout

---

| Option | Description | Selected |
|--------|-------------|----------|
| No escalation | Fixed: 5 attempts = 15 min. Every time. | ✓ |
| Progressive escalation | 15 min, 30 min, 1 hour progression. | |
| You decide | Claude picks. | |

**User's choice:** No escalation

---

| Option | Description | Selected |
|--------|-------------|----------|
| Reset on successful login | Counter to 0 on success. Fresh start after lockout expires. | ✓ |
| Sliding window | Track attempts in time window. | |
| You decide | Claude picks. | |

**User's choice:** Reset on successful login

---

| Option | Description | Selected |
|--------|-------------|----------|
| Password login only | Magic link rate-limited separately. No lockout for ML failures. | ✓ |
| All login methods | All failures increment counter. | |
| You decide | Claude picks. | |

**User's choice:** Password login only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Generic message with time hint | "Invalid email or password" + "Too many attempts. Try again in a few minutes." | ✓ |
| Specific lockout message | "Account locked for 15 minutes." (enumeration risk) | |
| You decide | Claude picks. | |

**User's choice:** Generic message with time hint

---

| Option | Description | Selected |
|--------|-------------|----------|
| Before hash | Check locked_at first. Skip Argon2id if locked. | ✓ |
| After hash | Always hash, then check lockout. | |
| You decide | Claude picks. | |

**User's choice:** Before hash

---

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry events only | [:sigra, :security, :lockout] event. Devs attach handlers. | ✓ |
| Callback + telemetry | Behaviour callback plus events. | |
| You decide | Claude picks. | |

**User's choice:** Telemetry events only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Exposed via context API | locked?/1 and lock_status/1. Available for admin dashboards. | ✓ |
| Hidden, internal only | Only login flow checks it. | |
| You decide | Claude picks. | |

**User's choice:** Exposed via context API

---

## Rate Limiting

| Option | Description | Selected |
|--------|-------------|----------|
| Thin wrapper via RateLimiter behaviour | Sigra.RateLimiters.Hammer wrapping Hammer 7.x API. Auto-detected. | ✓ |
| Direct Hammer calls | No wrapper. Direct API usage. | |
| You decide | Claude picks. | |

**User's choice:** Thin wrapper via RateLimiter behaviour

---

| Option | Description | Selected |
|--------|-------------|----------|
| Login + registration + reset + magic link | All auth entry points. 10/IP/min. Independent. | ✓ |
| Login only | Only login endpoint. | |
| All routes with single limit | One limit across all Sigra routes. | |

**User's choice:** Login + registration + reset + magic link

---

| Option | Description | Selected |
|--------|-------------|----------|
| JSON + HTML based on Accept | Content-negotiate. Retry-After header. ErrorHandler behaviour. | ✓ |
| Always redirect with flash | Browser-only. | |
| You decide | Claude picks. | |

**User's choice:** JSON + HTML based on Accept

---

| Option | Description | Selected |
|--------|-------------|----------|
| Plug for IP, inline for account | Sigra.Plug.RateLimit + inline in authenticate. | ✓ |
| All inline in auth functions | Both in Sigra.Auth. | |
| All via Plug | Both as plugs. | |
| You decide | Claude picks. | |

**User's choice:** Plug for IP, inline for account

---

| Option | Description | Selected |
|--------|-------------|----------|
| Per-route configurable | Plug accepts options per-route. | ✓ |
| Global config only | Single limit for all routes. | |
| You decide | Claude picks. | |

**User's choice:** Per-route configurable

---

| Option | Description | Selected |
|--------|-------------|----------|
| conn.remote_ip with proxy header support | Default to conn.remote_ip. Document proxy setup. | ✓ |
| Custom IP extraction callback | Behaviour callback for IP extraction. | |
| You decide | Claude picks. | |

**User's choice:** conn.remote_ip with proxy header support

---

**User discussion on Hammer as optional vs required dep:** User asked why not make Hammer required. Explained: RateLimiter behaviour IS the interface, Hammer is the blessed default. Keeping it optional follows the Ecto adapter pattern and allows devs who rate-limit at CDN/LB level to skip it. User agreed with keeping behaviour + optional Hammer.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Startup warning + config doc | Log warning once. Fail open. Document in install guide. | ✓ |
| Compile-time warning | Compiler warning. | |
| You decide | Claude picks. | |

**User's choice:** Startup warning + config doc (with clarification on optional dep approach)

---

| Option | Description | Selected |
|--------|-------------|----------|
| No, ETS only | Resets on restart. Lockout in DB persists. | ✓ |
| DB-backed rate limits | Store counters in DB. | |
| You decide | Claude picks. | |

**User's choice:** No, ETS only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Include in generated routes | Generator adds plug to auth route scope. | ✓ |
| Document only | README shows how to add it. | |
| You decide | Claude picks. | |

**User's choice:** Include in generated routes

---

| Option | Description | Selected |
|--------|-------------|----------|
| POST only | Only state-changing operations. | ✓ |
| All methods | All requests to auth routes. | |
| You decide | Claude picks. | |

**User's choice:** POST only

---

| Option | Description | Selected |
|--------|-------------|----------|
| On 429 only | Retry-After header only on rate limited response. | ✓ |
| Always include | X-RateLimit-* on every response. | |
| You decide | Claude picks. | |

**User's choice:** On 429 only

---

## Suspicious Login

| Option | Description | Selected |
|--------|-------------|----------|
| New IP address only | Compare against stored session IPs. No UA/geo triggers. | ✓ |
| New IP + new user agent combo | Track (IP, UA) pairs. | |
| New IP + geo change | Trigger only on geo change. Requires GeoIP. | |
| You decide | Claude picks. | |

**User's choice:** New IP address only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Derive from existing sessions | Query sessions for distinct IPs. No separate table. | ✓ |
| Separate known_ips table | Dedicated table with first/last seen. | |
| You decide | Claude picks. | |

**User's choice:** Derive from existing sessions

---

| Option | Description | Selected |
|--------|-------------|----------|
| No opt-out, always notify | Security feature. Can't disable. | ✓ |
| User can opt out | Preference flag. | |
| Developer configurable | Global toggle only. | |
| Dev config + user opt-out | Both levels. | |

**User's choice:** No opt-out, always notify

---

| Option | Description | Selected |
|--------|-------------|----------|
| IP + location + time + action link | Full notification with "Secure your account" link. | ✓ |
| Minimal notification | Simple text notification. | |
| You decide | Claude picks. | |

**User's choice:** IP + location + time + action link

---

| Option | Description | Selected |
|--------|-------------|----------|
| Async via existing email infrastructure | Oban/inline delivery. Login not blocked. | ✓ |
| Sync before login completes | Send before returning session. | |
| You decide | Claude picks. | |

**User's choice:** Async via existing email infrastructure

---

| Option | Description | Selected |
|--------|-------------|----------|
| No, login events only | Explicit login only. Remember-me rehydration excluded. | ✓ |
| Yes, all session creation | Including remember-me rehydration. | |
| You decide | Claude picks. | |

**User's choice:** No, login events only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both in Phase 4 | suspicious_login_email + lockout_notification_email generated. | ✓ |
| You decide | Claude picks. | |

**User's choice:** Yes, both in Phase 4

---

| Option | Description | Selected |
|--------|-------------|----------|
| All active sessions | Check all non-expired session IPs. Bounded by TTL. | ✓ |
| Last N unique IPs | Rolling window of N IPs. | |
| You decide | Claude picks. | |

**User's choice:** All active sessions

---

| Option | Description | Selected |
|--------|-------------|----------|
| Password change page | Direct link to /users/settings/password. | ✓ |
| Security settings page | Broader security page. | |
| You decide | Claude picks. | |

**User's choice:** Password change page

---

## Migration Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Separate user_sessions table | New table for sessions. user_tokens stays for email tokens. | ✓ |
| Extend user_tokens | Add session columns to user_tokens. | |
| You decide | Claude picks. | |

**User's choice:** Separate user_sessions table

---

| Option | Description | Selected |
|--------|-------------|----------|
| Update Phase 1 template | Include user_sessions in Phase 1 migration. One clean migration. | ✓ |
| Separate Phase 4 migration | Keep Phase 1 as-is. Add Phase 4 migration. | |
| You decide | Claude picks. | |

**User's choice:** Update Phase 1 template

---

| Option | Description | Selected |
|--------|-------------|----------|
| Standard auth indexes | Unique on hashed_token, index on user_id, on (user_id, type), on inserted_at. | ✓ |
| You decide | Claude picks. | |

**User's choice:** Standard auth indexes

---

| Option | Description | Selected |
|--------|-------------|----------|
| Same table, different type | Remember-me in user_sessions with type: :remember_me. | ✓ |
| Separate remember_me_tokens table | Dedicated table. | |
| You decide | Claude picks. | |

**User's choice:** Same table, different type

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, update Phase 2 plans | Retroactively update Phase 2 to use user_sessions. | ✓ |
| Keep Phase 2 as-is, migrate in Phase 4 | Add migration step. | |
| You decide | Claude picks. | |

**User's choice:** Yes, update Phase 2 plans

---

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern as users table | Standard columns, IP as string, utc_datetime_usec. | |
| You decide | Claude handles multi-DB concerns. | ✓ |

**User's choice:** You decide

---

| Option | Description | Selected |
|--------|-------------|----------|
| Extend TokenCleanup | Add session cleanup to existing worker. | ✓ |
| Separate SessionCleanup worker | New Oban worker. | |
| You decide | Claude picks. | |

**User's choice:** Extend TokenCleanup

---

## Telemetry Events

| Option | Description | Selected |
|--------|-------------|----------|
| Subsystem-based naming | [:sigra, :session, :create/:delete/:revoke_all/:sudo]. | ✓ |
| You decide | Claude designs catalog. | |

**User's choice:** Subsystem-based naming

---

| Option | Description | Selected |
|--------|-------------|----------|
| One-shot events | [:sigra, :security, :lockout/:rate_limited/:suspicious_login]. Point-in-time. | ✓ |
| Spans for all | Start/stop for everything. | |
| You decide | Claude picks. | |

**User's choice:** One-shot events

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, :warning for security events | Security at :warning, session ops at :info. | ✓ |
| All at :info | Consistent level. | |
| You decide | Claude picks. | |

**User's choice:** Yes, :warning for security events

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include if available | geo_city/geo_country_code in metadata when GeoIP configured. | ✓ |
| No geo in telemetry | Geo only in email. | |
| You decide | Claude picks. | |

**User's choice:** Yes, include if available

---

| Option | Description | Selected |
|--------|-------------|----------|
| Specify key events, rest to Claude | Lock core events. Claude decides additional events/metadata. | ✓ |
| Full catalog now | Every event specified. | |
| All to Claude | Full discretion. | |

**User's choice:** Specify key events, rest to Claude

---

## Config Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing session section | Add idle_timeout, absolute_timeout, activity_update_threshold, sudo_timeout. | ✓ |
| New section for timeouts | Separate session_timeouts: section. | |
| You decide | Claude organizes. | |

**User's choice:** Extend existing session section

---

| Option | Description | Selected |
|--------|-------------|----------|
| New lockout section | lockout: with threshold, duration, notify. | ✓ |
| Nested under rate_limiting | Add lockout keys to rate_limiting. | |
| You decide | Claude organizes. | |

**User's choice:** New lockout section

---

| Option | Description | Selected |
|--------|-------------|----------|
| On by default, configurable | suspicious_login: with enabled: true, notify: true. | ✓ |
| Always on, no config | Can't disable. | |
| You decide | Claude picks. | |

**User's choice:** On by default, configurable

---

| Option | Description | Selected |
|--------|-------------|----------|
| Own section | geo_ip: with module: nil. Used beyond sessions. | ✓ |
| Under session section | Nested in session config. | |
| You decide | Claude picks. | |

**User's choice:** Own section

---

| Option | Description | Selected |
|--------|-------------|----------|
| Keep under session:, update to 60 days | Update remember_me_max_age default from 14 to 60 days. | ✓ |
| You decide | Claude handles alignment. | |

**User's choice:** Keep under session:, update to 60 days

---

## Testing Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Session + security helpers | create_session, list_sessions, assert_session_revoked, simulate_lockout, etc. | ✓ |
| You decide | Claude designs helpers. | |

**User's choice:** Session + security helpers

---

| Option | Description | Selected |
|--------|-------------|----------|
| Mox via RateLimiter behaviour | MockRateLimiter via Mox. No Hammer in unit tests. | ✓ |
| Hammer test backend | Use Hammer's test utilities. | |
| You decide | Claude picks. | |

**User's choice:** Mox via RateLimiter behaviour

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, full session state fixtures | session_fixture, remembered_session_fixture, locked_user_fixture, sudo_session_fixture. | ✓ |
| You decide | Claude designs fixtures. | |

**User's choice:** Yes, full session state fixtures

---

## Claude's Discretion

- SessionStore behaviour exact callback signatures and Session struct field types
- UA parser implementation details
- Exact LiveView component design for session listing
- Session cleanup frequency and batch size
- Rate limit key formatting in Hammer
- Sudo re-auth page template design
- Additional telemetry events beyond specified core events
- Multi-DB concerns for sessions table (IP as string, timestamps)

## Deferred Ideas

- MFA-aware sudo re-authentication (Phase 6)
- MFA session states on Session struct (Phase 6)
- OAuth re-authentication for sudo on OAuth-only accounts (Phase 5)
- WebAuthn/passkey as re-auth method (v1.x)
