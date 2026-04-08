---
phase: 04-session-management-and-security-baseline
plan: 02
subsystem: session-plugs-and-auth
tags: [session, plugs, sudo, telemetry, pubsub, cookies]
dependency_graph:
  requires: ["04-01"]
  provides: ["FetchSession plug with timeouts", "RequireSudo with session.sudo_at", "Auth session CRUD with PubSub"]
  affects: ["priv/templates/sigra.install/user_auth.ex", "lib/sigra/auth.ex"]
tech_stack:
  added: []
  patterns: ["Mox-based SessionStore testing", "conn.private for cross-plug session sharing", "PubSub broadcast for LiveView disconnect"]
key_files:
  created: []
  modified:
    - lib/sigra/plug/fetch_session.ex
    - lib/sigra/plug/require_sudo.ex
    - lib/sigra/auth.ex
    - lib/sigra/telemetry.ex
    - test/sigra/plug/fetch_session_test.exs
    - test/sigra/plug/require_sudo_test.exs
    - test/sigra/auth_test.exs
decisions:
  - "Session stored in conn.private[:sigra_session] for downstream plug access (not conn.assigns)"
  - "Remember-me cookie rehydration reads plain cookie value (not signed) — signing is host app responsibility"
  - "Security telemetry events logged at :warning level, session events at :info level"
metrics:
  duration_seconds: 304
  completed: "2026-04-08T03:18:14Z"
  tasks_completed: 2
  tasks_total: 2
  tests_added: 30
  tests_total: 64
  files_modified: 7
requirements:
  - SESS-03
  - SESS-04
  - SESS-08
  - SESS-09
  - SEC-05
---

# Phase 04 Plan 02: Session Plugs, Auth CRUD, and Telemetry Summary

FetchSession overhauled with idle/absolute timeouts, remember-me rehydration, throttled activity updates, and secure cookie defaults (HttpOnly, SameSite=Lax, Secure=true). RequireSudo redesigned to use session.sudo_at from DB. Auth module extended with create/delete/list/revoke session functions and PubSub-based LiveView disconnect on logout-everywhere.

## Task Completion

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | FetchSession plug overhaul | 63077f5 | Cookie security defaults, idle/absolute timeouts, remember-me skip idle, activity throttling, remember-me cookie rehydration, conn.private storage |
| 2 | RequireSudo redesign + Auth session CRUD + telemetry | 3e3ad33 | sudo_at from DB session, create/delete/list/revoke_session, delete_all_sessions with PubSub broadcast, telemetry catalog extension |

## Implementation Details

### FetchSession Plug (Task 1)

- **Cookie defaults**: `http_only: true`, `same_site: "Lax"`, `secure: true` — overridable via `:cookie_opts`
- **Timeout enforcement**: Standard sessions check both idle (30 min) and absolute (24h). Remember-me sessions skip idle, use `remember_me_max_age` (60 days) as absolute
- **Activity throttling**: `update_activity` called only when `elapsed >= activity_update_threshold` (5 min), preventing DB write on every request
- **Remember-me rehydration**: When Plug session has no `:user_token` but remember-me cookie exists, fetches session from cookie value
- **Session sharing**: Session struct stored in `conn.private[:sigra_session]` for RequireSudo and other downstream plugs
- **Config-driven**: All timeout values from `Sigra.Config` struct, no hardcoded magic numbers

### RequireSudo Plug (Task 2)

- Reads session from `conn.private[:sigra_session]` instead of `conn.assigns[:authenticated_at]`
- Checks `session.sudo_at` against configurable sudo window (default 300s)
- Returns `:stale_sudo` when expired or nil, `:unauthenticated` when no scope

### Auth Session Functions (Task 2)

- `create_session/4` — creates via SessionStore with telemetry span
- `delete_session/3` — deletes by hashed_token with telemetry span
- `delete_all_sessions/3` — bulk delete with PubSub broadcast for LiveView disconnect, supports `:except_token`
- `list_sessions/3` — lists all sessions for a user
- `revoke_session/3` — alias for delete_session
- `confirm_sudo/3` — updates sudo_at timestamp with telemetry span
- Private `session_store_and_opts/2` helper extracts store module and options from config

### Telemetry Extension (Task 2)

- Session span events: `[:sigra, :session, :create]`, `[:sigra, :session, :delete]`, `[:sigra, :session, :sudo]`
- Session signal: `[:sigra, :session, :revoke_all, :stop]`
- Security signal: `[:sigra, :security, :suspicious_login]` (defined for Plan 03/04)
- Security events logged at `:warning` level, all others at `:info`

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- `mix test test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_sudo_test.exs test/sigra/auth_test.exs` — 64 tests, 0 failures
- `mix compile --warnings-as-errors` — clean compilation

## Known Stubs

None. All functions are fully implemented with real logic.
