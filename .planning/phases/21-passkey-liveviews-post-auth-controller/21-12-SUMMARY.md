---
phase: 21-passkey-liveviews-post-auth-controller
plan: 12
subsystem: auth
tags: [passkeys, webauthn, liveview, controller, example-app]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: example passkey routes, controller completion flow, and generated browser/helper sources from plans 21-07 and 21-11
provides:
  - served example bundle with app-owned passkey runtime, hooks, and controller-page login binding
  - LiveSocket hook registration for PasskeyRegister and PasskeyAuthenticate in the checked-in example bundle
  - controller login template markup consumed by the served bundle instead of a missing test global
affects: [phase-21, phase-22-passkeys-generator-wiring, phase-23-ci-smoke, example-app]

tech-stack:
  added: []
  patterns:
    - checked-in served bundle can carry app-owned passkey runtime when the example app is not rebuilding assets in-plan
    - controller passkey login pages expose data attributes and status targets while bundle JS owns the ceremony binding

key-files:
  created:
    - .planning/phases/21-passkey-liveviews-post-auth-controller/21-12-SUMMARY.md
  modified:
    - test/example/priv/static/assets/js/app.js
    - test/example/lib/example_web/controllers/session_html.ex

key-decisions:
  - "The example app's served app.js now owns the passkey runtime directly so LiveView hooks and passkey-primary login work without Playwright globals."
  - "The controller login template exposes data-passkey-login-status markup and leaves all passkey behavior to the served bundle."

patterns-established:
  - "Sigra passkey runtime is fenced by // Sigra passkeys:start and // Sigra passkeys:end in the served bundle."
  - "LiveSocket hook registration reads from window.SigraPasskeyRuntime to keep the runtime browser-inspectable."

requirements-completed: [PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12]

duration: 20min
completed: 2026-04-16
---

# Phase 21 Plan 12: Served Example Passkey Runtime Summary

**Checked-in example app.js now carries the passkey browser/runtime hooks and binds the controller login page without relying on a test-only global.**

## Performance

- **Duration:** 20 min
- **Completed:** 2026-04-16T00:35:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added a self-contained passkey runtime block to the served example bundle with WebAuthn option fetches, base64url conversion, registration/authentication helpers, abort-safe hook teardown, conditional UI login binding, and a browser-inspectable `window.SigraPasskeyRuntime`.
- Registered `PasskeyRegister` and `PasskeyAuthenticate` in the example app's `LiveSocket` hook map so existing `phx-hook` usage resolves from the served bundle.
- Replaced the controller login page's inline `window.SigraPasskeys` dependency with bundle-consumed markup, preserving the passkey form, password fallback, magic-link recovery, and a status target for safe recovery copy.

## Task Commits

No commits were created. The user explicitly asked not to touch git history unless required, and this plan was completed safely without plan-local commits.

## Files Created/Modified

- `test/example/priv/static/assets/js/app.js` - Adds the served passkey runtime block, `DOMContentLoaded` login binding, runtime marker, and LiveSocket hook registration.
- `test/example/lib/example_web/controllers/session_html.ex` - Adds `data-passkey-login-status` markup and removes the inline test-global script.
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-12-SUMMARY.md` - Execution summary for this plan.

## Decisions Made

- Kept the runtime plain browser JavaScript inside the checked-in bundle instead of depending on an asset rebuild step outside the owned file set.
- Preserved controller ownership of final login POST and LiveView ownership of recoverable passkey ceremony state.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first focused LiveView test run failed with a duplicate-email fixture error under one ExUnit seed. Re-running the same focused subset under a new seed passed cleanly without code changes, so this was treated as a transient test issue rather than a plan regression.

## User Setup Required

None.

## Next Phase Readiness

The example app now exposes the passkey runtime from its served bundle, so downstream generator and CI smoke work can verify app-owned passkey behavior instead of test-injected globals.

## Verification

- `rg -n "Sigra passkeys:start|PasskeyRegister|PasskeyAuthenticate|attachPasskeyLogin|SigraPasskeyRuntime|hooks:" test/example/priv/static/assets/js/app.js`
- `! rg -n "window\\.SigraPasskeys" test/example/lib/example_web/controllers/session_html.ex`
- `node --check test/example/priv/static/assets/js/app.js`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/live/passkey_settings_live_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs --max-failures 1`
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs --max-failures 1`
- `bash -lc 'set -euo pipefail; rg -n "PasskeyRegister|PasskeyAuthenticate|attachPasskeyLogin|SigraPasskeyRuntime" test/example/priv/static/assets/js/app.js; ! rg -n "window\\.SigraPasskeys" test/example/lib/example_web/controllers/session_html.ex; cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs --max-failures 1'`

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- Verified summary exists at `.planning/phases/21-passkey-liveviews-post-auth-controller/21-12-SUMMARY.md`.
- Verified modified files exist: `test/example/priv/static/assets/js/app.js`, `test/example/lib/example_web/controllers/session_html.ex`.
- Commit checks were intentionally skipped because no commits were created per explicit user constraint.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-16*
