---
phase: 01-foundation
plan: 02
subsystem: auth
tags: [telemetry, plug, middleware, observability, elixir]

# Dependency graph
requires:
  - phase: 01-foundation-01
    provides: "Mix project structure with deps (plug, telemetry)"
provides:
  - "Sigra.Telemetry module with event catalog, span/3, event/3, attach_default_logger/1"
  - "Sigra.Plug.ErrorHandler behaviour with auth_error/3 callback"
  - "Sigra.Plug.FetchSession - session token extraction plug"
  - "Sigra.Plug.FetchBearer - bearer token extraction plug"
  - "Sigra.Plug.RequireAuthenticated - authentication gate plug"
  - "Sigra.Plug.RequireSudo - sudo mode enforcement plug"
affects: [02-registration, 03-oauth, 04-mfa, 05-sessions, 07-api-tokens]

# Tech tracking
tech-stack:
  added: [":telemetry ~> 1.0", ":plug ~> 1.16"]
  patterns: ["telemetry span/event helpers wrapping :telemetry library", "behaviour-based error handler for plug pipeline", "mock modules in tests for session store and token verifier"]

key-files:
  created:
    - lib/sigra/telemetry.ex
    - lib/sigra/plug/error_handler.ex
    - lib/sigra/plug/fetch_session.ex
    - lib/sigra/plug/fetch_bearer.ex
    - lib/sigra/plug/require_authenticated.ex
    - lib/sigra/plug/require_sudo.ex
    - test/sigra/telemetry_test.exs
    - test/sigra/plug/fetch_session_test.exs
    - test/sigra/plug/fetch_bearer_test.exs
    - test/sigra/plug/require_authenticated_test.exs
    - test/sigra/plug/require_sudo_test.exs
  modified: []

key-decisions:
  - "Used __MODULE__.handle_event/4 MFA reference for telemetry handler to avoid :telemetry local function performance warning"
  - "RequireSudo halts with :unauthenticated when current_scope is missing (not just :stale_sudo) for defense in depth"
  - "FetchSession and FetchBearer use dependency injection via opts for session_store/token_verifier (Mox-friendly)"

patterns-established:
  - "Telemetry pattern: Sigra.Telemetry.span/3 for operations, Sigra.Telemetry.event/3 for signals"
  - "Plug pattern: @behaviour Plug with init/1 returning opts, call/2 assigning :current_scope"
  - "Error handling pattern: ErrorHandler behaviour dispatched by gate plugs, conn halted after callback"
  - "Test pattern: mock modules defined inside test files for session stores and token verifiers"

requirements-completed: [FOUND-07, FOUND-08]

# Metrics
duration: 4min
completed: 2026-04-05
---

# Phase 1 Plan 2: Telemetry and Plugs Summary

**Telemetry module with full event catalog and 5 library plugs forming the HTTP authentication pipeline**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-06T00:28:11Z
- **Completed:** 2026-04-06T00:32:34Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Telemetry module with complete event catalog (auth, token, security), span/3 and event/3 helpers, and attach_default_logger/1 following Oban pattern
- ErrorHandler behaviour defining auth_error/3 callback for 3 error types (:unauthenticated, :stale_sudo, :rate_limited)
- 4 plugs implementing @behaviour Plug: FetchSession, FetchBearer, RequireAuthenticated, RequireSudo
- 32 tests with zero warnings covering all plug behaviors, telemetry events, and edge cases

## Task Commits

Each task was committed atomically:

1. **Task 1: Telemetry module with event catalog and default logger** - `a99e95c` (feat)
2. **Task 2: Library plugs (FetchSession, FetchBearer, RequireAuthenticated, RequireSudo, ErrorHandler)** - `0354646` (feat)

_Note: TDD tasks have RED (test) + GREEN (implementation) in same commits due to greenfield project_

## Files Created/Modified
- `lib/sigra/telemetry.ex` - Event catalog, span/3, event/3, attach_default_logger/1
- `lib/sigra/plug/error_handler.ex` - ErrorHandler behaviour with auth_error/3 callback
- `lib/sigra/plug/fetch_session.ex` - Session token extraction from Plug session
- `lib/sigra/plug/fetch_bearer.ex` - Bearer token extraction from Authorization header
- `lib/sigra/plug/require_authenticated.ex` - Authentication gate, halts when no current_scope
- `lib/sigra/plug/require_sudo.ex` - Sudo mode gate, halts when authenticated_at is stale
- `test/sigra/telemetry_test.exs` - 10 tests for telemetry module
- `test/sigra/plug/fetch_session_test.exs` - Tests for session plug with mock store
- `test/sigra/plug/fetch_bearer_test.exs` - Tests for bearer plug with mock verifier
- `test/sigra/plug/require_authenticated_test.exs` - Tests for auth gate plug
- `test/sigra/plug/require_sudo_test.exs` - Tests for sudo gate plug

## Decisions Made
- Used `__MODULE__.handle_event/4` MFA reference instead of anonymous function capture for telemetry handler to avoid the `:telemetry` local function performance warning
- RequireSudo returns `:unauthenticated` (not `:stale_sudo`) when `current_scope` is entirely missing, providing defense in depth
- FetchSession and FetchBearer accept session_store/token_verifier as opts for dependency injection, making them Mox-friendly per D-34
- Metadata policy enforced: telemetry event catalog documents NEVER/ALWAYS inclusion rules per D-17

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deprecated `use Plug.Test` in test files**
- **Found during:** Task 2 (Plug tests)
- **Issue:** `use Plug.Test` is deprecated in Plug 1.19.x; `--warnings-as-errors` caused test suite abort
- **Fix:** Replaced with `import Plug.Test` in all 4 plug test files
- **Files modified:** test/sigra/plug/*.exs
- **Verification:** Tests pass with `--warnings-as-errors`
- **Committed in:** 0354646 (Task 2 commit)

**2. [Rule 3 - Blocking] Created minimal mix.exs for compilation**
- **Found during:** Task 1 (project has no mix.exs yet)
- **Issue:** Plan 01-01 creates mix.exs but runs in parallel wave; this plan's modules need to compile
- **Fix:** Created minimal mix.exs with plug and telemetry deps; orchestrator will merge with 01-01's full mix.exs
- **Files modified:** mix.exs, test/test_helper.exs
- **Verification:** `mix compile --warnings-as-errors` succeeds
- **Committed in:** 2372aa9 (Task 1 commit, scaffolding)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for compilation and test execution in parallel wave context. No scope creep.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Known Stubs
- `FetchSession.call/2` delegates to a session_store module that must be passed in opts -- the actual `Sigra.SessionStores.Ecto` implementation comes in Phase 4 (sessions plan)
- `FetchBearer.call/2` delegates to a token_verifier module -- the actual API token verifier comes in Phase 7 (API tokens plan)

These stubs are intentional: the plug contracts are established now, implementations will be wired in their respective phases.

## Next Phase Readiness
- Telemetry module ready for instrumentation in all subsequent phases
- Plug pipeline ready for integration with generated UserAuth module (plan 01-03)
- ErrorHandler behaviour ready for generator to produce default implementation
- FetchSession awaits SessionStores.Ecto (Phase 4)
- FetchBearer awaits API token verifier (Phase 7)

## Self-Check: PASSED

- All 11 created files verified present on disk
- Both task commits (a99e95c, 0354646) verified in git log
- 32 tests pass with `--warnings-as-errors`
- `mix compile --warnings-as-errors` succeeds

---
*Phase: 01-foundation*
*Completed: 2026-04-05*
