---
phase: 07-api-authentication
plan: 04
subsystem: api
tags: [api-tokens, jwt, generator, eex-templates, phoenix-router, json-controllers]

# Dependency graph
requires:
  - phase: 07-03
    provides: Auth.ex API token + JWT delegation functions, FetchBearer plug, testing helpers
provides:
  - EEx templates for API token migration, schema, JSON controllers, email notification
  - Install task --api and --jwt flags for generator
  - Injector functions for API pipeline and JWT route injection
  - Auth context delegation template for host app
affects: [08-account-lifecycle, future-api-documentation]

# Tech tracking
tech-stack:
  added: []
  patterns: [conditional-generation-flags, api-pipeline-injection, jwt-route-injection]

key-files:
  created:
    - priv/templates/sigra.install/api_token_migration.exs
    - priv/templates/sigra.install/user_api_token.ex
    - priv/templates/sigra.install/api_token_controller.ex
    - priv/templates/sigra.install/token_controller.ex
    - priv/templates/sigra.install/api_token_created_email.ex
    - priv/templates/sigra.install/auth_api_token.ex
    - test/sigra/install/api_token_generator_test.exs
  modified:
    - lib/sigra/install/injector.ex
    - lib/mix/tasks/sigra.install.ex

key-decisions:
  - "API token migration as separate file from main migration (not appended to existing)"
  - "Auth context delegation via template snippet (auth_api_token.ex) rather than auto-injection"
  - "JWT routes in separate unauthenticated scope (/api/auth) from token CRUD (/api)"

patterns-established:
  - "Flag-based conditional generation: --api includes opaque tokens, --jwt adds JWT endpoints"
  - "Separate injector markers per feature (#Sigra API, #Sigra JWT) for independent idempotency"
  - "API controllers delegate to Auth context which delegates to Sigra.Auth library"

requirements-completed: [API-01, API-02, API-03, API-04, API-05, API-06, API-07]

# Metrics
duration: 8min
completed: 2026-04-09
---

# Phase 7 Plan 4: API Authentication Generator Templates Summary

**EEx templates for API token migration, JSON controllers, JWT auth endpoints, email notification, and install task --api/--jwt flag support with 71 passing generator tests**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-09T00:03:01Z
- **Completed:** 2026-04-09T00:10:31Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Migration template creates user_api_tokens table with all D-06 columns, adapter-conditional scopes (array for Postgres, string for MySQL/SQLite), proper indexes, and token_epoch on users
- APITokenController provides paginated JSON CRUD for token management; TokenController provides JWT auth with MFA flow support
- Install task extended with --api and --jwt flags; injector adds API pipeline with FetchBearer and RequireAuthenticated
- 71 generator tests covering template rendering, injector idempotency, and install task wiring

## Task Commits

Each task was committed atomically:

1. **Task 1: Migration and schema templates** - `9b13525` (feat)
2. **Task 2: Controller templates, email template, Auth context, injector, and install task** - `86f9be4` (feat)

## Files Created/Modified
- `priv/templates/sigra.install/api_token_migration.exs` - EEx template for user_api_tokens migration with adapter-conditional DDL
- `priv/templates/sigra.install/user_api_token.ex` - EEx template for UserAPIToken Ecto schema
- `priv/templates/sigra.install/api_token_controller.ex` - JSON API controller for token CRUD (index, create, delete, delete_all)
- `priv/templates/sigra.install/token_controller.ex` - JWT auth endpoints (create, refresh, mfa, revoke)
- `priv/templates/sigra.install/api_token_created_email.ex` - Email notification template for new token creation
- `priv/templates/sigra.install/auth_api_token.ex` - Auth context delegation functions for API token + optional JWT operations
- `lib/sigra/install/injector.ex` - Extended with inject_api_routes, inject_jwt_routes, inject_api_config
- `lib/mix/tasks/sigra.install.ex` - Extended with --api and --jwt flags, API file generation, route injection
- `test/sigra/install/api_token_generator_test.exs` - 71 tests for template rendering and generator wiring

## Decisions Made
- API token migration generated as a separate migration file rather than appending to the main migration, allowing independent API token adoption
- Auth context delegation provided as a template snippet (auth_api_token.ex) with instructions to add to host app's Auth context, rather than auto-injecting into existing code
- JWT routes placed in a separate unauthenticated `/api/auth` scope since token creation requires email/password, while token CRUD routes go in an authenticated `/api` scope

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed heredoc indentation in JWT config generation**
- **Found during:** Task 2
- **Issue:** JWT config heredoc string had content indented less than the closing delimiter, causing compilation error
- **Fix:** Replaced heredoc with inline escaped string for the JWT config block
- **Files modified:** lib/mix/tasks/sigra.install.ex
- **Verification:** mix compile --warnings-as-errors passes
- **Committed in:** 86f9be4

**2. [Rule 1 - Bug] Fixed unused variable warning in inject_api_files**
- **Found during:** Task 2
- **Issue:** `context_module` and `auth_path` variables were defined but unused in the inject function
- **Fix:** Removed unused variable assignments
- **Files modified:** lib/mix/tasks/sigra.install.ex
- **Verification:** mix compile --warnings-as-errors passes
- **Committed in:** 86f9be4

**3. [Rule 1 - Bug] Fixed EEx template syntax mismatch in auth_api_token.ex**
- **Found during:** Task 2
- **Issue:** Template mixed `@jwt` assigns syntax with `context_module` keyword syntax, causing CompileError when rendered
- **Fix:** Changed `@jwt` to `jwt` keyword syntax matching all other templates
- **Files modified:** priv/templates/sigra.install/auth_api_token.ex
- **Verification:** All 71 tests pass including auth_api_token rendering tests
- **Committed in:** 86f9be4

---

**Total deviations:** 3 auto-fixed (3 bugs)
**Impact on plan:** All fixes necessary for compilation and test correctness. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All API authentication generator templates complete and tested
- Phase 7 fully delivers API token infrastructure (plans 01-04)
- Ready for Phase 8 (account lifecycle) or any phase requiring API auth

---
*Phase: 07-api-authentication*
*Completed: 2026-04-09*
