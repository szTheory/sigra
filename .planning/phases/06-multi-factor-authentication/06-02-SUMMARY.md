---
phase: 06-multi-factor-authentication
plan: 02
subsystem: mfa-session-gate
tags: [mfa, session, plug, authentication]
dependency_graph:
  requires: [session-store, auth-core, plug-infrastructure]
  provides: [mfa-session-gate, mfa-pending-type, complete-mfa-verification]
  affects: [fetch-session, require-sudo, config]
tech_stack:
  added: []
  patterns: [session-type-union, plug-gate-pattern, token-rotation]
key_files:
  created:
    - lib/sigra/plug/require_mfa.ex
    - lib/sigra/plug/require_mfa_enrolled.ex
    - test/sigra/plug/require_mfa_test.exs
    - test/sigra/plug/require_mfa_enrolled_test.exs
  modified:
    - lib/sigra/session.ex
    - lib/sigra/auth.ex
    - lib/sigra/config.ex
    - lib/sigra/plug/fetch_session.ex
    - lib/sigra/plug/require_sudo.ex
    - test/sigra/auth_test.exs
decisions:
  - MFA check function passed via config.mfa.check_fn rather than hardcoded dependency
  - Session creation moved into authenticate_with_config for config-based auth flow
  - mfa_pending sessions filtered at application layer (Enum.reject) not store layer
metrics:
  duration: 573s
  completed: 2026-04-08
  tasks_completed: 2
  tasks_total: 2
  tests_added: 19
  tests_total: 672
  files_created: 4
  files_modified: 6
---

# Phase 06 Plan 02: MFA Session Gate and Auth Flow Summary

MFA-pending session state with gate plugs, token rotation on MFA completion, and 5-minute pending timeout enforcement in FetchSession.

## What Was Built

### Task 1: Session Type Extension and MFA Gate Plugs

- Extended `Sigra.Session.session_type` union with `:mfa_pending`
- Created `Sigra.Plug.RequireMFA` -- gates all routes for `mfa_pending` sessions, allowing only the MFA challenge path and logout path through
- Created `Sigra.Plug.RequireMFAEnrolled` -- enforces MFA enrollment via configurable check function, redirects unenrolled users to enrollment page
- Both plugs follow existing patterns (RequireAuthenticated, RequireSudo)

### Task 2: MFA-Aware Auth Flow and Session Transitions

- Modified `authenticate_with_config` to check MFA enrollment after successful password verification; creates `:mfa_pending` session when MFA is enabled, standard session otherwise
- Added `complete_mfa_verification/4` -- rotates session token (deletes old mfa_pending, creates new standard/remember_me), preventing session fixation attacks
- Extended `FetchSession.session_valid?/2` with `:mfa_pending` timeout (default 300s / 5 min) -- expired pending sessions are auto-deleted
- `list_sessions/3` now excludes `:mfa_pending` sessions from active session listings (D-29)
- Added `:mfa` keyword list to `Sigra.Config` struct
- Documented RequireSudo TOTP extension capability (D-40)

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| f50fbfc | test | Add failing tests for RequireMFA and RequireMFAEnrolled plugs |
| d3bb45b | feat | Add RequireMFA and RequireMFAEnrolled plugs with mfa_pending session type |
| 0d800d6 | test | Add failing tests for MFA-aware authenticate and complete_mfa_verification |
| db192a1 | feat | Add MFA-aware authenticate flow and complete_mfa_verification |

## Decisions Made

1. **MFA check via config function** -- `config.mfa.check_fn` is a function `(user_id -> boolean)` passed at configuration time, keeping the auth module decoupled from the MFA credential store.
2. **Session creation in authenticate_with_config** -- Config-based authenticate now creates sessions directly (mfa_pending or standard), so the caller receives a ready-to-use session in the result map.
3. **mfa_pending filtering at application layer** -- `list_sessions` filters out mfa_pending sessions via `Enum.reject` rather than modifying the SessionStore behaviour, keeping the store interface simple.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Existing config-based auth tests needed session store expectations**
- **Found during:** Task 2
- **Issue:** Adding session creation to `handle_valid_login_with_security` broke 5 existing tests that didn't expect `MockSessionStore.create` calls
- **Fix:** Added `MockSessionStore.create` expectations and updated result assertions from `{:ok, user}` to `{:ok, user, %{session: _}}` in affected tests
- **Files modified:** test/sigra/auth_test.exs
- **Commit:** db192a1

## Verification

- `mix test --seed 0` -- 672 tests, 0 failures
- `mix compile --warnings-as-errors` -- clean compilation
- All acceptance criteria met per plan

## Self-Check: PASSED

All 10 files verified present. All 4 commits verified in history.
