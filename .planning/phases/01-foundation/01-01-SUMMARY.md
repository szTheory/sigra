---
phase: 01-foundation
plan: 01
subsystem: auth
tags: [elixir, phoenix, nimble_options, argon2, plug_crypto, behaviours, config]

# Dependency graph
requires: []
provides:
  - Mix project skeleton with all core dependencies
  - NimbleOptions-validated config struct (Sigra.Config)
  - Password hashing via Argon2id (Sigra.Crypto, Sigra.Hashers.Argon2)
  - Signed and hashed token operations (Sigra.Token)
  - Error types with enumeration-safe messages (Sigra.Error)
  - 4 behaviours (Hasher, Mailer, SessionStore, RateLimiter) with default implementations
  - Testing helpers module (Sigra.Testing)
affects: [01-02, 01-03, all-subsequent-plans]

# Tech tracking
tech-stack:
  added: [phoenix ~> 1.8, ecto ~> 3.12, ecto_sql ~> 3.12, nimble_options ~> 1.1, argon2_elixir ~> 4.1, comeonin ~> 5.3, hammer ~> 7.3, swoosh ~> 1.5, oban ~> 2.17, ex_doc ~> 0.40, credo ~> 1.7, dialyxir ~> 1.4, mox ~> 1.1]
  patterns: [behaviour + implementations pattern, NimbleOptions config validation, Plug.Crypto for tokens, defexception for error types]

key-files:
  created:
    - mix.exs
    - lib/sigra.ex
    - lib/sigra/config.ex
    - lib/sigra/error.ex
    - lib/sigra/crypto.ex
    - lib/sigra/token.ex
    - lib/sigra/hasher.ex
    - lib/sigra/hashers/argon2.ex
    - lib/sigra/mailer.ex
    - lib/sigra/session_store.ex
    - lib/sigra/rate_limiter.ex
    - lib/sigra/rate_limiters/noop.ex
    - lib/sigra/testing.ex
  modified: []

key-decisions:
  - "Used @schema module attribute instead of nested Schema submodule to avoid compile-order issues with NimbleOptions.docs/1 in @moduledoc"
  - "Configured Swoosh API client to false in config.exs since Swoosh is an optional dep and hackney is not included"
  - "Crypto.no_user_verify/0 returns false (not :ok) to enable direct use in authentication pipelines"

patterns-established:
  - "Behaviour pattern: singular name (Sigra.Hasher) with plural implementations dir (Sigra.Hashers.Argon2)"
  - "Config pattern: NimbleOptions @schema attribute with nested keyword lists for feature domains"
  - "Error pattern: defexception structs + safe_message/1 for enumeration prevention"
  - "Token pattern: Plug.Crypto.sign/verify for signed tokens, :crypto.strong_rand_bytes + SHA-256 for hashed tokens"
  - "Testing pattern: assertion helpers in Sigra.Testing with stubs for future phases"

requirements-completed: [FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-10]

# Metrics
duration: 6min
completed: 2026-04-06
---

# Phase 1 Plan 1: Core Library Foundation Summary

**Sigra Mix project with NimbleOptions config, Argon2id crypto, Plug.Crypto tokens, 4 behaviours, and enumeration-safe error types**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-06T00:27:40Z
- **Completed:** 2026-04-06T00:33:57Z
- **Tasks:** 2
- **Files modified:** 28

## Accomplishments
- Sigra compiles as a Mix library with all dependencies resolved (Phoenix 1.8, Ecto 3.12, NimbleOptions, Argon2, etc.)
- Config.new!/1 validates required options (repo, user_schema) via NimbleOptions with OWASP-grade defaults (12-char min password, 14-day remember-me, Argon2id hasher)
- Crypto module hashes/verifies passwords via Argon2id with timing-safe no_user_verify for enumeration prevention
- Token module provides signed tokens via Plug.Crypto and SHA-256 hashed token pairs for email/API flows
- 4 behaviours define 8 total callbacks; Argon2 hasher and Noop rate limiter implement their respective behaviours
- Error module defines 5 exception structs with safe_message/1 mapping for enumeration-safe user-facing messages
- All 68 tests pass with zero warnings and zero Phoenix UI dependencies in library modules

## Task Commits

Each task was committed atomically:

1. **Task 1: Mix project, config, error modules** - `b0f728f` (feat)
2. **Task 2: Crypto, Token, Behaviours, Testing skeleton** - `3fe6095` (feat)

## Files Created/Modified
- `mix.exs` - Project definition with all deps, package config, docs config
- `lib/sigra.ex` - Top-level module with library documentation
- `lib/sigra/config.ex` - NimbleOptions-validated config struct with OWASP defaults
- `lib/sigra/error.ex` - 5 defexception structs + safe_message/1 for enumeration prevention
- `lib/sigra/crypto.ex` - Password hashing/verification dispatching to configured Hasher
- `lib/sigra/token.ex` - Signed tokens (Plug.Crypto) and hashed token pairs (SHA-256)
- `lib/sigra/hasher.ex` - Hasher behaviour (3 callbacks)
- `lib/sigra/hashers/argon2.ex` - Argon2id implementation of Hasher behaviour
- `lib/sigra/mailer.ex` - Mailer behaviour (1 callback)
- `lib/sigra/session_store.ex` - SessionStore behaviour (3 callbacks)
- `lib/sigra/rate_limiter.ex` - RateLimiter behaviour (1 callback)
- `lib/sigra/rate_limiters/noop.ex` - No-op rate limiter fallback
- `lib/sigra/testing.ex` - Test assertion helpers with stubs for future phases
- `config/config.exs` - Swoosh API client disabled, env-specific config import
- `config/dev.exs` - Dev environment config
- `config/test.exs` - Fast Argon2 params for tests
- `test/test_helper.exs` - ExUnit startup
- `test/sigra/config_test.exs` - 12 tests for config validation
- `test/sigra/error_test.exs` - 16 tests for error types and safe messages
- `test/sigra/crypto_test.exs` - 6 tests for password hashing
- `test/sigra/token_test.exs` - 14 tests for token operations
- `test/sigra/behaviours_test.exs` - 20 tests for behaviours and implementations

## Decisions Made
- Used `@schema` module attribute instead of a nested `Schema` submodule for NimbleOptions definition, avoiding compile-order issues when `NimbleOptions.docs/1` is called in `@moduledoc`
- Added `config :swoosh, :api_client, false` since Swoosh is optional and hackney is not a project dependency
- Made `Crypto.no_user_verify/0` return `false` (not `:ok`) so it can be used directly in auth pipelines as a boolean result

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Swoosh API client config**
- **Found during:** Task 1 (Mix project setup)
- **Issue:** Tests crashed with `missing hackney dependency` because Swoosh starts its API client on boot
- **Fix:** Added `config :swoosh, :api_client, false` in `config/config.exs` and created `config/dev.exs`
- **Files modified:** `config/config.exs`, `config/dev.exs`
- **Verification:** Tests run without Swoosh startup errors
- **Committed in:** b0f728f (Task 1 commit)

**2. [Rule 1 - Bug] Restructured Config.Schema to @schema attribute**
- **Found during:** Task 1 (Config module)
- **Issue:** Nested `Sigra.Config.Schema` submodule not available at compile time when `@moduledoc` evaluates `NimbleOptions.docs(Sigra.Config.Schema.definition())`
- **Fix:** Replaced submodule with `@schema` module attribute, inlined NimbleOptions schema in both `@moduledoc` and `@schema`
- **Files modified:** `lib/sigra/config.ex`
- **Verification:** `mix compile --warnings-as-errors` passes
- **Committed in:** b0f728f (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both auto-fixes necessary for compilation and test execution. No scope creep.

## Known Stubs

- `lib/sigra/testing.ex:72` - `assert_session_created/1` returns `true` unconditionally (will be implemented when session management ships)
- `lib/sigra/testing.ex:85` - `assert_token_sent/2` returns `true` unconditionally (will be implemented when email delivery ships)
- `lib/sigra/testing.ex:96` - `with_test_mailer/1` just calls the function (will set up Mox capture when mailer integration ships)

All stubs are intentional and documented -- they provide the API surface now while deferring implementation to the phases that build the corresponding features.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All library foundation modules are in place for Plan 02 (Plugs) and Plan 03 (Generator)
- Behaviours are ready for Mox-based testing in downstream plans
- Config struct ready to be consumed by plug initialization and generator templates

---
*Phase: 01-foundation*
*Completed: 2026-04-06*
