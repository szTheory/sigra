---
phase: 21-passkey-liveviews-post-auth-controller
plan: 08
subsystem: auth
tags: [passkeys, webauthn, phoenix, example-app, config, ecto]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: Plans 21-05 and 21-06 example app passkey controller/UI mirror and tests
provides:
  - Sigra.Config support for the passkey_primary_enabled runtime flag
  - Example app passkey POST routes under login, MFA, and sudo-gated settings scopes
  - Example app runtime passkey config for Sigra.Passkeys.config/0
  - Concrete Example.Accounts.UserPasskey schema and user_passkeys migration
affects: [phase-21-verification, phase-21-plan-09, phase-22-passkeys-generator, passkeys, example-app]

tech-stack:
  added: []
  patterns:
    - Example app passkey routes mirror generated controller POST boundaries
    - Sudo-sensitive passkey enrollment and delete routes run through Sigra.Plug.RequireSudo
    - Example passkey persistence now uses normal app schema and migration files

key-files:
  created:
    - test/example/lib/example/accounts/user_passkey.ex
    - test/example/priv/repo/migrations/20260415000002_create_user_passkeys.exs
  modified:
    - lib/sigra/config.ex
    - test/sigra/passkeys/config_test.exs
    - test/example/lib/example_web/router.ex
    - test/example/config/config.exs
    - test/example/lib/example/accounts.ex

key-decisions:
  - "passkey_primary_enabled is a Sigra.Config passkeys option with a false default; host apps opt into passkey-primary separately from general passkey support."
  - "Example enrollment and delete routes are sudo-gated, while primary-login and MFA passkey routes remain reachable without sudo."
  - "Example passkey runtime config is present in both config.exs and Example.Accounts.sigra_config/0 so controller and context paths share the same concrete schema and RP settings."

patterns-established:
  - "Runtime passkey config for example apps should set :sigra otp_app plus :example :sigra_config before Sigra.Passkeys.config/0 is called."
  - "Example app passkey schemas should instantiate the generated template directly instead of relying on fixture-local dynamic modules."

requirements-completed: [PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12]

duration: 5min
completed: 2026-04-15
---

# Phase 21 Plan 08: Example Passkey Runtime Gap Closure Summary

**Example passkey routes, runtime config, and persistence now exist as normal Phoenix app code instead of source-contract or fixture bootstrap stand-ins.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-15T23:21:11Z
- **Completed:** 2026-04-15T23:25:44Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added `passkey_primary_enabled` to the library passkeys option schema with focused TDD coverage for true, default false, and invalid non-boolean values.
- Added all seven example app passkey POST routes under the correct unauthenticated, MFA-pending, authenticated, and sudo-gated route scopes.
- Added example runtime passkey config in `config.exs` plus matching `Example.Accounts.sigra_config/0` passkey settings.
- Added a concrete `Example.Accounts.UserPasskey` schema and `user_passkeys` migration with user and credential indexes.

## Task Commits

1. **Task 1 RED: Add failing passkey primary config coverage** - `f685492` (test)
2. **Task 1 GREEN: Support passkey primary config flag** - `e38539f` (feat)
3. **Task 2: Wire example passkey routes and config** - `5af8235` (feat)
4. **Task 3: Add example passkey persistence** - `f18725f` (feat)

**Plan metadata:** pending final metadata commit

## Files Created/Modified

- `lib/sigra/config.ex` - Adds `passkey_primary_enabled` to both passkeys option schema definitions.
- `test/sigra/passkeys/config_test.exs` - Covers passkey-primary true preservation, false default, and non-boolean rejection.
- `test/example/lib/example_web/router.ex` - Registers primary-login, MFA, enrollment, and delete passkey POST routes with sudo gating for settings mutations.
- `test/example/config/config.exs` - Defines `:sigra` OTP app and `:example, :sigra_config` passkey runtime settings.
- `test/example/lib/example/accounts.ex` - Adds matching passkey settings to the example Accounts Sigra config.
- `test/example/lib/example/accounts/user_passkey.ex` - Concrete example app passkey credential schema.
- `test/example/priv/repo/migrations/20260415000002_create_user_passkeys.exs` - Creates `user_passkeys` with `user_id` index and unique `credential_id` index.

## Decisions Made

- Kept passkey-primary opt-in distinct from `passkeys[:enabled]`, matching the product posture that passkey MFA/enrollment and primary login are separate switches.
- Used a separate `:require_sudo` pipeline for passkey enrollment and delete so settings mutations inherit the existing sudo freshness check.
- Left Plan 21-06's fixture bootstrap in place for compatibility; because the real schema now loads, the dynamic module branch is bypassed and Plan 21-09 can remove the bootstrap.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix format` attempted broad formatting churn in pre-existing committed files, including a large NimbleOptions docs interpolation. Those post-commit formatting-only changes were discarded from the specific affected files; no user-owned unrelated edits were reverted.

## User Setup Required

None - no external service configuration required.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs --max-failures 1` - `5 tests, 0 failures`
- `mix compile --warnings-as-errors` - passed after Task 1
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix compile --warnings-as-errors` - passed after Task 2 and final verification
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix run -e 'IO.inspect(Sigra.Passkeys.config().passkeys[:rp_id])'` - returned `"localhost"`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix run -e 'IO.inspect(Sigra.Passkeys.config().passkeys[:passkey_primary_enabled])'` - returned `true`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.reset` - migrated `user_passkeys`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix run -e 'IO.inspect(Code.ensure_loaded?(Example.Accounts.UserPasskey)); IO.inspect(Example.Repo.query!("SELECT to_regclass('public.user_passkeys')").rows)'` - returned `true` and a `user_passkeys` regclass row
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs --max-failures 1` - `5 tests, 0 failures`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix phx.routes | rg "passkey"` - listed all seven required passkey routes
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix run -e 'Sigra.Passkeys.reset_cached_config(); IO.inspect(Sigra.Passkeys.config().passkeys)'` - returned the configured example passkey keyword list

## Known Stubs

None.

## Threat Flags

None - the new network route surface and database persistence surface were explicitly covered by the plan threat model and mitigations.

## Next Phase Readiness

Ready for Plan 21-09 to remove source-string and fixture-bootstrap workarounds now that the example app has real routes, config, schema, and migration support.

## Self-Check: PASSED

- Verified created files exist: `test/example/lib/example/accounts/user_passkey.ex`, `test/example/priv/repo/migrations/20260415000002_create_user_passkeys.exs`, and this summary.
- Verified modified files exist for every plan-owned source and test file.
- Verified task commits exist in git history: `f685492`, `e38539f`, `5af8235`, and `f18725f`.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-15*
