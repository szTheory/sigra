---
phase: 01-foundation
plan: 03
subsystem: generator
tags: [mix-task, eex, phoenix-1.8, code-generation, ecto-migrations]

requires:
  - phase: 01-01
    provides: Core library modules (Config, Crypto, Token, Error, Behaviours)
  - phase: 01-02
    provides: Telemetry and Plug modules (ErrorHandler behaviour, auth plugs)
provides:
  - mix sigra.install generator task
  - 12 EEx templates for authentication scaffold
  - Injector module for router/config/test injection
  - Idempotent file generation and migration detection
affects: [phase-02, phase-03, testing, documentation]

tech-stack:
  added: [EEx templates, Mix.Task, Mix.Generator]
  patterns: [generator-with-injector, template-override-per-D09, adapter-aware-DDL]

key-files:
  created:
    - lib/mix/tasks/sigra.install.ex
    - lib/sigra/install/injector.ex
    - priv/templates/sigra.install/user.ex
    - priv/templates/sigra.install/user_token.ex
    - priv/templates/sigra.install/scope.ex
    - priv/templates/sigra.install/auth.ex
    - priv/templates/sigra.install/user_auth.ex
    - priv/templates/sigra.install/login_live.ex
    - priv/templates/sigra.install/registration_live.ex
    - priv/templates/sigra.install/session_controller.ex
    - priv/templates/sigra.install/migration.exs
    - priv/templates/sigra.install/error_handler.ex
    - priv/templates/sigra.install/auth_fixtures.ex
    - priv/templates/sigra.install/conn_case_helpers.ex
    - test/mix/tasks/sigra.install_test.exs
    - test/sigra/install/injector_test.exs

key-decisions:
  - "Phoenix 1.8 uses .form/:let instead of .simple_form — all templates updated"
  - "LiveView-aware router injection: live routes when --live, controller routes otherwise"
  - "Idempotent re-run: skip existing files, detect existing migration, already-injected checks"
  - "Generated code uses explicit field declarations, no macro injection (owns-your-code philosophy)"
  - "Template override support via priv/templates/sigra.install/ in host app"

patterns-established:
  - "Generator pattern: EEx templates + Injector module for Phoenix app scaffolding"
  - "Idempotency: check existing files/migrations before creating, check markers before injecting"
  - "Adapter-aware DDL: detect Ecto adapter at generation time, emit appropriate migration SQL"

requirements-completed: [FOUND-01, FOUND-02, FOUND-04, FOUND-09, FOUND-10]

duration: 15min
completed: 2026-04-05
---

# Plan 01-03: Install Generator Summary

**`mix sigra.install` generator producing 12 EEx templates, adapter-aware migrations, idempotent injections, and Phoenix 1.8-compatible LiveView/controller scaffold**

## Performance

- **Duration:** ~15 min (execution) + ~10 min (verification & Phoenix 1.8 fixes)
- **Tasks:** 3/3 (2 implementation + 1 verification checkpoint)
- **Files created:** 16

## Accomplishments
- Complete `mix sigra.install Context Schema table` generator with 12 EEx templates
- Injector module for router, config, test config, and conn_case with idempotent marker detection
- Verified end-to-end in a real Phoenix 1.8.5 app: zero warnings with `--warnings-as-errors`
- Idempotent re-runs: files skipped, no duplicate migrations, injections detected as already-applied

## Task Commits

1. **Task 1: EEx templates** - `8b794cb` (feat) — 12 template files for User, UserToken, Scope, Auth context, UserAuth, LiveViews, SessionController, migration, fixtures
2. **Task 2: Mix task + Injector + tests** - `8d04f09` (feat) — sigra.install Mix task, Injector module, 122 passing tests
3. **Task 3: Verification checkpoint** - `729ff33` (fix) — Phoenix 1.8 compatibility fixes after end-to-end verification

## Decisions Made
- Removed `<.simple_form>` and `<.error>` components (removed in Phoenix 1.8 CoreComponents), replaced with `<.form :let={f}>` and plain HTML
- Removed `class` attribute from `<.header>` (not accepted in Phoenix 1.8)
- Added `validate_current_password/2` to User schema template (called by auth context but was missing)
- Redirected sudo error handler to `/users/log_in` (sudo route is a future phase feature)
- Added LiveView-conditional router injection: `live` routes for `--live`, controller routes for `--no-live`

## Deviations from Plan

### Auto-fixed Issues

**1. Phoenix 1.8 component incompatibility**
- **Found during:** Task 3 (verification checkpoint)
- **Issue:** Templates used `simple_form`, `error`, `header class=` which don't exist in Phoenix 1.8 CoreComponents
- **Fix:** Replaced with `.form :let={f}`, plain `<p>` tag, removed class attr
- **Files modified:** login_live.ex, registration_live.ex
- **Verification:** Zero compilation warnings in fresh Phoenix 1.8.5 test app

**2. Missing function and unused aliases**
- **Found during:** Task 3
- **Issue:** `validate_current_password/2` called but undefined; unused aliases in templates
- **Fix:** Added function to user.ex template; removed unused aliases
- **Files modified:** user.ex, user_auth.ex, session_controller.ex, registration_live.ex

**3. Generator idempotency gaps**
- **Found during:** Task 3
- **Issue:** Re-running generator overwrote files and created duplicate migrations
- **Fix:** Skip existing files; detect existing migration by filename pattern
- **Files modified:** lib/mix/tasks/sigra.install.ex

---

**Total deviations:** 3 auto-fixed (all correctness/compatibility)
**Impact on plan:** Essential fixes caught by end-to-end verification. No scope creep.

## Issues Encountered
None beyond the Phoenix 1.8 compatibility issues caught during verification.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Foundation complete: library core + plugs + install generator all working
- Ready for Phase 2 features building on the auth scaffold
- Generated code compiles cleanly in Phoenix 1.8.5 host apps

---
*Phase: 01-foundation*
*Completed: 2026-04-05*
