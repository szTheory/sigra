---
phase: 21-passkey-liveviews-post-auth-controller
plan: 14
subsystem: testing
tags: [playwright, phoenix, passkeys, webauthn, router, json]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: served passkey runtime and browser proof guardrails from plans 21-12 and 21-13
provides:
  - JSON-negotiated passkey option routes that match the shipped browser helper
  - controller regression coverage for enrollment, MFA, and passkey-primary option fetches
  - served-browser proof for enrollment and passkey-primary option requests without masking
affects: [phase-21, phase-23-ci-smoke]

tech-stack:
  added: []
  patterns:
    - narrow browser-session JSON pipelines only for helper-driven passkey option endpoints
    - Playwright browser proofs observe real option-route responses while keeping anti-masking guards intact

key-files:
  created:
    - .planning/phases/21-passkey-liveviews-post-auth-controller/21-14-SUMMARY.md
    - test/example/priv/playwright/tests/passkey-options.spec.ts
  modified:
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/controllers/session_controller.ex
    - test/example/test/example_web/controllers/passkey_session_controller_test.exs
    - test/example/priv/playwright/tests/passkey-login.spec.ts

key-decisions:
  - "The three passkey option POST routes now negotiate JSON through a dedicated browser-session pipeline instead of widening the general browser stack."
  - "MFA browser proof remains out of scope because the repo still lacks a product-valid Playwright path to mint mfa_pending; that contract stays proven at the request/controller boundary."

patterns-established:
  - "When a shipped browser helper posts JSON into browser-session routes, fix route negotiation to match the helper instead of downgrading the helper contract."
  - "Playwright passkey proofs may use virtual authenticators, but must not use route interception, init-script injection, or fabricated session state."

requirements-completed: [PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12]

duration: 10min
completed: 2026-04-16
---

# Phase 21 Plan 14: Passkey Options Negotiation and Runtime Proof Summary

**The example app now accepts the shipped JSON passkey helper on all real option routes, with served-browser proof for enrollment and passkey-primary login.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-16T01:31:16Z
- **Completed:** 2026-04-16T01:40:45Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Fixed the route negotiation boundary so passkey enrollment, MFA, and passkey-primary options all accept the helper's JSON request shape.
- Added controller coverage for every passkey options branch, including the former `406` regression path.
- Added served-browser proof for enrollment and passkey-primary login while preserving anti-masking guardrails.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add failing JSON helper contract coverage** - `6000e4a` (`test`)
2. **Task 1: Accept JSON helper requests on passkey option routes** - `bc87c55` (`feat`)
3. **Task 2: Add failing served-app passkey browser proofs** - `0a70756` (`test`)

## Files Created/Modified

- `test/example/lib/example_web/router.ex` - Adds a dedicated JSON-accepting browser pipeline and scopes only the three passkey option routes through it.
- `test/example/lib/example_web/controllers/session_controller.ex` - Keeps the option actions on the existing JSON payload contract while staying inside the browser/session auth boundaries.
- `test/example/test/example_web/controllers/passkey_session_controller_test.exs` - Covers registration, MFA, conditional login, email login, and unavailable branches with helper-shaped JSON requests.
- `test/example/priv/playwright/tests/passkey-login.spec.ts` - Replaces the former `406` assertion with real success-path proof for passkey-primary option fetching.
- `test/example/priv/playwright/tests/passkey-options.spec.ts` - Adds served-browser enrollment proof through sudo and the real MFA settings page.
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-14-SUMMARY.md` - Records the completed plan and verification results.

## Decisions Made

- Used a dedicated `:browser_passkey_options` pipeline so the helper contract is honored without broadening unrelated browser routes.
- Kept MFA proof at the controller layer because the repo still does not have an honest browser path for `mfa_pending`.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- The executor completed the implementation commits but did not finish the summary/tracking step, so the orchestrator closed out the metadata locally after verifying the landed changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 21 execution is now unblocked at the option-route boundary, and the browser/runtime proof covers the highest-level flows this repo can drive honestly.

## Verification

- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/controllers/passkey_session_controller_test.exs --max-failures 1` - `11 tests, 0 failures`
- `! rg -n "page\\.route\\(|route\\.fulfill\\(|page\\.addInitScript\\(|browserContext\\.addInitScript\\(|storageState\\(|addCookies\\(|document\\.cookie|localStorage\\.|sessionStorage\\.|406\\)|Not Acceptable" test/example/priv/playwright/tests/passkey-login.spec.ts test/example/priv/playwright/tests/passkey-options.spec.ts` - passed
- `bash -lc 'set -euo pipefail; cd test/example; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.setup; MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix phx.server > /tmp/sigra-phase21-plan14-playwright.log 2>&1 & server_pid=$!; cleanup(){ kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; }; trap cleanup EXIT; for i in {1..60}; do if curl -fsS http://localhost:4000/users/log_in >/dev/null; then break; fi; if ! kill -0 "$server_pid" 2>/dev/null; then cat /tmp/sigra-phase21-plan14-playwright.log; exit 1; fi; sleep 1; done; cd priv/playwright; SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts tests/passkey-options.spec.ts'` - `3 passed`

## Self-Check: PASSED

- Files exist: `test/example/lib/example_web/router.ex`, `test/example/lib/example_web/controllers/session_controller.ex`, `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/priv/playwright/tests/passkey-login.spec.ts`, `test/example/priv/playwright/tests/passkey-options.spec.ts`, `.planning/phases/21-passkey-liveviews-post-auth-controller/21-14-SUMMARY.md`
- Commits exist: `6000e4a`, `bc87c55`, `0a70756`

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-16*
