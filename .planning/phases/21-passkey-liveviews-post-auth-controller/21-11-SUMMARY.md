---
phase: 21-passkey-liveviews-post-auth-controller
plan: 11
subsystem: testing
tags: [phoenix, passkeys, webauthn, playwright, exunit]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: runtime passkey challenge bytes and mfa_pending session hydration from plan 21-10
provides:
  - real route-backed passkey options coverage for registration, MFA, conditional login, and email login
  - route-backed MFA passkey success coverage through POST /users/mfa/passkey
  - Playwright smoke observing a real /users/log_in/passkey/options server response without interception
affects: [phase-21, phase-22-passkeys-generator, phase-23-ci-smoke]

tech-stack:
  added: []
  patterns:
    - Phoenix ConnTest route checks assert non-empty server-generated WebAuthn option challenges
    - Playwright passkey smoke uses waitForResponse instead of page.route route fulfillment

key-files:
  created:
    - .planning/phases/21-passkey-liveviews-post-auth-controller/21-11-SUMMARY.md
  modified:
    - test/example/test/example_web/controllers/passkey_session_controller_test.exs
    - test/example/priv/playwright/tests/passkey-login.spec.ts

key-decisions:
  - "Route-level ExUnit tests are the authoritative proof for challenge JSON shape because the dev Playwright server lacks Sigra secret_key_base for challenge-producing paths."
  - "Playwright keeps only a hardware-avoidance SigraPasskeys.authenticate shim and no longer intercepts or fulfills the options route."

patterns-established:
  - "Call the real Phoenix options routes before passkey completion tests so signed challenge session tokens are seeded by production controller code."
  - "Use page.waitForResponse for browser smoke verification of passkey options network traffic."

requirements-completed: [PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12]

duration: 6min
completed: 2026-04-16
---

# Phase 21 Plan 11: Passkey Route and Browser Proof Summary

**Real passkey options routes and MFA passkey completion are now covered without controller bypasses or Playwright route fulfillment.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-16T00:11:10Z
- **Completed:** 2026-04-16T00:17:15Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added route-backed options tests for sudo enrollment, MFA passkey authentication, conditional passkey login, and email-specific passkey login.
- Replaced direct MFA success controller invocation and manual `conn.private[:sigra_session]` injection with a real `POST /users/mfa/passkey/options` then `POST /users/mfa/passkey` flow.
- Removed Playwright options interception and route fulfillment; the browser smoke now observes a real server response with `page.waitForResponse`.

## Task Commits

1. **Task 1: Prove real options endpoints and MFA success through routes** - `a4a52a6` (test)
2. **Task 2: Remove Playwright options interception and observe the real server response** - `7451413` (test)

**Plan metadata:** captured in final `docs(21-11)` commit.

## Files Created/Modified

- `test/example/test/example_web/controllers/passkey_session_controller_test.exs` - Adds route-backed options JSON assertions and makes MFA passkey success use normal Phoenix POST/session loading.
- `test/example/priv/playwright/tests/passkey-login.spec.ts` - Removes options route interception and waits for the real `/users/log_in/passkey/options` response after clicking passkey login.
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-11-SUMMARY.md` - Execution summary and self-check.

## Decisions Made

- Used ExUnit route tests for the full challenge JSON proof because test setup can inject the Sigra `secret_key_base` required for signed passkey challenge tokens.
- Kept the Playwright shim limited to avoiding WebAuthn hardware prompts; it no longer fakes the route response.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adjusted Playwright route assertion for dev server config**
- **Found during:** Task 2 (Remove Playwright options interception and observe the real server response)
- **Issue:** The real `MIX_ENV=dev` server used by the plan command has no Sigra `secret_key_base`, so challenge-producing options requests return 500 from `Sigra.Token.generate/4`. The browser pipeline also rejects `Accept: application/json` before controller JSON rendering.
- **Fix:** Kept the route non-intercepted, added the real CSRF header, used a browser-pipeline-compatible Accept header, and asserted the real server's 200 response for the unknown-email path. Full challenge JSON shape remains covered by the focused route-level ExUnit tests.
- **Files modified:** `test/example/priv/playwright/tests/passkey-login.spec.ts`
- **Verification:** Focused Playwright command passed; focused ExUnit route tests passed with non-empty challenge JSON assertions.
- **Committed in:** `7451413`

---

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** The route/browser workaround is removed. Browser smoke verifies real network behavior without response faking, while ExUnit provides the full challenge-shape proof that the dev server cannot provide without out-of-scope config changes.

## Issues Encountered

- The plan-level Playwright command runs the example app in `MIX_ENV=dev` without a Sigra `secret_key_base`, so challenge-generating options requests fail in dev even though the same routes pass under the focused test setup.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 21 now has focused route and browser coverage for the previously hollow passkey options and MFA success paths. Future CI smoke work should either configure Sigra `secret_key_base` for the dev example server or keep challenge-shape assertions in test-env route coverage.

## Known Stubs

None.

## Threat Flags

None.

## Verification

- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs --max-failures 1` - 9 tests, 0 failures
- `bash -lc 'set -euo pipefail; cd test/example; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.setup; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix phx.server > /tmp/sigra-example-playwright.log 2>&1 & server_pid=$!; cleanup(){ kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; }; trap cleanup EXIT; for i in {1..60}; do if curl -fsS http://localhost:4000/users/log_in >/dev/null; then break; fi; if ! kill -0 "$server_pid" 2>/dev/null; then cat /tmp/sigra-example-playwright.log; exit 1; fi; sleep 1; done; curl -fsS http://localhost:4000/users/log_in >/dev/null; cd priv/playwright; SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts'` - 2 tests, 0 failures

## Self-Check: PASSED

- Files exist: `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/priv/playwright/tests/passkey-login.spec.ts`, `.planning/phases/21-passkey-liveviews-post-auth-controller/21-11-SUMMARY.md`
- Commits exist: `a4a52a6`, `7451413`

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-16*
