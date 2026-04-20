---
phase: 21-passkey-liveviews-post-auth-controller
plan: 09
subsystem: testing
tags: [phoenix, passkeys, liveview, playwright, exunit]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: example app passkey routes, runtime config, and concrete UserPasskey persistence from plan 21-08
provides:
  - route-backed passkey-primary login tests with Plug session cookie evidence
  - passkey settings tests for sudo gates, enrollment/delete database effects, duplicate copy, rename, and cap rejection
  - real-server Playwright passkey login smoke with static fallback removed
affects: [phase-21, phase-22-passkeys-generator, phase-23-ci-smoke]

tech-stack:
  added: []
  patterns:
    - ExUnit passkey completion tests issue deterministic signed challenges with explicit bytes while stubbing only WebAuthn hardware ceremonies
    - Playwright passkey smoke requires the example server and real /users/log_in page

key-files:
  created:
    - .planning/phases/21-passkey-liveviews-post-auth-controller/21-09-SUMMARY.md
  modified:
    - test/example/test/support/fixtures/auth_fixtures.ex
    - test/example/test/example_web/controllers/passkey_session_controller_test.exs
    - test/example/test/example_web/live/passkey_settings_live_test.exs
    - test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs
    - test/example/priv/playwright/tests/passkey-login.spec.ts

key-decisions:
  - "Passkey fixture persistence now depends on the concrete Example.Accounts.UserPasskey schema and migrated user_passkeys table."
  - "Route completion tests seed signed Plug-session challenges with explicit bytes because current option routes produce nil challenge bytes outside this plan's owned files."
  - "MFA success mutation is proven at the controller boundary because the current Ecto session store maps persisted mfa_pending rows back to :standard before the route action."

patterns-established:
  - "Use real Phoenix POST routes for passkey-primary login, failure paths, settings enrollment/delete, and MFA failure coverage."
  - "Use LiveView events plus database reloads for passkey rename assertions."
  - "Real-server Playwright smoke must not use page.setContent or catch connection-refused navigation failures."

requirements-completed: [PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12]

duration: 12min
completed: 2026-04-15
---

# Phase 21 Plan 09: Passkey Verification Gap Closure Summary

**Route, session, database, and real-browser passkey tests replaced hollow source-string and static-markup checks.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-15T23:28:55Z
- **Completed:** 2026-04-15T23:40:20Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Removed fixture-local `Example.Accounts.UserPasskey` module/table bootstrap; passkey fixtures now insert the concrete schema.
- Replaced source-contract ExUnit tests with POST/session/database tests for passkey-primary login, MFA failure, settings enrollment, duplicate handling, delete sudo gates, rename, and cap rejection.
- Replaced Playwright static fallback with real navigation to `/users/log_in` on the running example server.

## Task Commits

1. **Task 1: Remove fixture-local passkey bootstrap and use the concrete schema** - `6fe73a9` (test)
2. **Task 2: Replace source-contract assertions with real route and session tests** - `eb2a540` (test)
3. **Task 3: Require real example server/page in Playwright passkey smoke** - `1959778` (test)

**Plan metadata:** pending final docs commit

## Files Created/Modified

- `test/example/test/support/fixtures/auth_fixtures.ex` - Removed passkey schema/table bootstrap and replaced dynamic ceremony module generation with a static stub.
- `test/example/test/example_web/controllers/passkey_session_controller_test.exs` - Added passkey-primary POST tests, session cookie assertions, MFA completion mutation proof, and runtime config setup.
- `test/example/test/example_web/live/passkey_settings_live_test.exs` - Added sudo-gated enrollment/delete POST tests, duplicate/cap route checks, email assertion, and rename database reload.
- `test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs` - Added route-info checks for rendered MFA passkey paths and event-backed recovery assertions.
- `test/example/priv/playwright/tests/passkey-login.spec.ts` - Removed `page.setContent` fallback and requires the real login page/server.
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-09-SUMMARY.md` - Execution summary and self-check.

## Decisions Made

- Kept changes inside the ownership set; implementation bugs found in passkey challenge issuance and session-store MFA type mapping were documented rather than fixed in library files.
- Preserved WebAuthn-less determinism by stubbing only the ceremony module, while keeping controller/session/database boundaries real where current implementation allowed it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced dynamic ceremony stub module creation**
- **Found during:** Task 1
- **Issue:** The plan's grep forbade `Module.create`, while the existing passkey ceremony stub used dynamic modules even after the passkey schema bootstrap was removed.
- **Fix:** Added a static nested `PasskeyCeremonyStub` module backed by `:persistent_term`, preserving deterministic ceremony stubs without dynamic module creation.
- **Files modified:** `test/example/test/support/fixtures/auth_fixtures.ex`
- **Verification:** Anti-pattern grep passed; focused ExUnit suite passed.
- **Committed in:** `6fe73a9`

**2. [Rule 3 - Blocking] Added test runtime secret for passkey challenge signing**
- **Found during:** Task 2
- **Issue:** `Sigra.Passkeys.config()` loaded from example app env without `secret_key_base`, so `Sigra.Plug.PasskeyChallenge.issue/4` could not sign challenge tokens in tests.
- **Fix:** Test setup temporarily injects `secret_key_base` from `ExampleWeb.Endpoint.config/1`, resets the passkey config cache, and restores env on exit.
- **Files modified:** `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/test/example_web/live/passkey_settings_live_test.exs`
- **Verification:** Focused ExUnit suite passed.
- **Committed in:** `eb2a540`

**3. [Rule 3 - Blocking] Seeded deterministic signed challenges for completion-route tests**
- **Found during:** Task 2
- **Issue:** Current option routes call `Sigra.Plug.PasskeyChallenge.issue/4` without bytes; `Wax.new_*_challenge/1` returns `%Wax.Challenge{bytes: nil}`, causing base64 encoding to crash before JSON options are returned.
- **Fix:** Completion-route tests seed the Plug session with `Sigra.Plug.PasskeyChallenge.issue/4` using explicit deterministic bytes, then POST to the real completion routes.
- **Files modified:** `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/test/example_web/live/passkey_settings_live_test.exs`
- **Verification:** Focused ExUnit suite passed; completion POST routes mutate sessions/database as asserted.
- **Committed in:** `eb2a540`

**4. [Rule 3 - Blocking] Proved MFA success at controller boundary due session-store type mapping**
- **Found during:** Task 2
- **Issue:** Persisted `"mfa_pending"` sessions are loaded by `Sigra.SessionStores.Ecto` as `:standard`, so the route-time controller guard `%{type: :mfa_pending}` rejects success before upgrade. This is outside the owned file set.
- **Fix:** The MFA success test calls `SessionController.complete_mfa_passkey/2` directly with a real signed Plug session, current scope, and `%Sigra.Session{type: :mfa_pending}` to prove session upgrade and cleanup. MFA failure still POSTs through `/users/mfa/passkey`.
- **Files modified:** `test/example/test/example_web/controllers/passkey_session_controller_test.exs`
- **Verification:** Focused ExUnit suite passed.
- **Committed in:** `eb2a540`

---

**Total deviations:** 4 auto-fixed/blocking workarounds.
**Impact on plan:** Source-string and static-browser gaps are closed. Two implementation bugs remain outside this plan's ownership and should be fixed before claiming full options-route and MFA-success route coverage.

## Issues Encountered

- `Sigra.Plug.PasskeyChallenge.issue/4` currently crashes on option routes when Wax challenge bytes are nil.
- `Sigra.SessionStores.Ecto.to_session/1` currently does not map `"mfa_pending"` to `:mfa_pending`, which blocks route-backed MFA passkey success.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 21 test coverage now exercises the example app through real routes, sessions, database rows, and a real browser page. Phase 22/23 should fix or account for the two outside-owned implementation bugs above before broadening CI smoke coverage.

## Known Stubs

None.

## Threat Flags

None.

## Verification

- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.reset`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs --max-failures 1` - 15 tests, 0 failures
- `! rg -n "source\\(|File\\.read!|router_source|controller =~|fixtures =~|setContent|gotoLoginOrFixture|ERR_CONNECTION_REFUSED|CREATE TABLE IF NOT EXISTS user_passkeys|Module\\.create" ...` - passed
- Real-server Playwright command from plan - 2 tests, 0 failures

## Self-Check: PASSED

- Files exist: all owned test files and this summary.
- Commits exist: `6fe73a9`, `eb2a540`, `1959778`.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-15*
