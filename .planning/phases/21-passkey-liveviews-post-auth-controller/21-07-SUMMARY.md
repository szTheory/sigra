---
phase: 21-passkey-liveviews-post-auth-controller
plan: 07
subsystem: auth
tags: [passkeys, webauthn, conditional-ui, liveview, generator, tdd]

requires:
  - phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
    provides: Generated passkey browser helper, LiveView hook seam, and app.js injection marker
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: Plan 21-04 controller-rendered passkey-primary login DOM
provides:
  - Controller-page `attachPasskeyLogin()` binding for passkey-primary login
  - Conditional mediation/autofill support with explicit-click fallback
  - Hook support for `optionsUrl`, `completeUrl`, `passkey[response]`, and controller POST completion
  - Node-stub coverage for conditional UI, explicit login, unsupported errors, abort/timeout copy, and teardown
affects: [phase-21-passkey-ui, phase-22-passkeys-generator-wiring, passkeys, generated-assets]

tech-stack:
  added: []
  patterns:
    - Progressive enhancement conditional UI starts only when `PublicKeyCredential.isConditionalMediationAvailable()` succeeds
    - Browser passkey success serializes to `passkey[response]` and submits through controller POST
    - Static controller-page JS binding lives beside the existing Phoenix LiveView passkey hooks

key-files:
  created:
    - priv/templates/sigra.install/passkeys/passkey_browser.js
  modified:
    - priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js
    - priv/templates/sigra.install/passkeys/passkey_hooks.js
    - test/sigra/install/features/passkeys_js_test.exs

key-decisions:
  - "Conditional UI is a progressive enhancement: unsupported browsers retain explicit passkey click, password, and magic-link recovery."
  - "Controller-rendered passkey-primary login uses `attachPasskeyLogin({ enableConditionalUI: true })` on DOMContentLoaded instead of relying on LiveView hooks."
  - "Passkey hook success can POST `passkey[response]` to controller completion URLs, preserving the controller-owned session mutation boundary."

patterns-established:
  - "Controller passkey login binding: resolve `#passkey_login_form` and `#passkey_login_button`, fetch options, run browser ceremony, then submit hidden JSON."
  - "Safe browser error mapping: unsupported, abort/cancel, and timeout become recoverable status buckets without raw browser exception text."
  - "Hook completion POST: `completeUrl` submits a hidden form containing `_csrf_token` and `passkey[response]` JSON."

requirements-completed: [PK-UX-08, PK-UX-10, PK-UX-12]

duration: 10min
completed: 2026-04-15
---

# Phase 21 Plan 07: Conditional Passkey Login JS Summary

**Conditional passkey autofill plus controller-page login binding that keeps explicit passkey, password, and magic-link recovery available**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-15T22:20:29Z
- **Completed:** 2026-04-15T22:30:28Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- Added `conditionalMediationAvailable()`, `useBrowserAutofill`, and `attachPasskeyLogin()` to the generated browser helper.
- Wired generated `app.js` injection to import `attachPasskeyLogin` and call `attachPasskeyLogin({ enableConditionalUI: true })` on `DOMContentLoaded`.
- Extended `PasskeyAuthenticate`/`PasskeyRegister` hooks to fetch `optionsUrl`, submit `completeUrl`, and serialize browser responses into `passkey[response]`.
- Added Node-stub tests for conditional mediation, explicit email-aware click flow, unsupported autofill, safe abort/timeout copy, and existing teardown behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing conditional passkey JS coverage** - `d3946a1` (test)
2. **Task 1 GREEN: Add conditional passkey login wiring** - `7140ab8` (feat)

**Plan metadata:** pending final metadata commit

## Files Created/Modified

- `priv/templates/sigra.install/passkeys/passkey_browser.js` - Adds browser ceremony serialization, conditional mediation detection, `useBrowserAutofill`, and static controller login binding.
- `priv/templates/sigra.install/passkeys/passkey_hooks.js` - Adds `optionsUrl` fetching, `completeUrl` hidden-form POST completion, CSRF headers, and authenticate-hook autofill forwarding.
- `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` - Adds `attachPasskeyLogin` import and DOMContentLoaded controller-page binding while preserving merged LiveView hooks.
- `test/sigra/install/features/passkeys_js_test.exs` - Adds template-contract assertions and Node runtime stubs for conditional UI, explicit click, unsupported autofill, safe recovery copy, and teardown.

## Decisions Made

- Conditional mediation is attempted only after feature detection succeeds; unsupported browsers get a recoverable `unsupported` status and all fallback controls stay available.
- The explicit `Continue with passkey` path remains email-aware and posts `user[email]` to the options endpoint without `mediation: "conditional"`.
- Controller login success uses `HTMLFormElement.prototype.submit.call(form)` after writing `passkey[response]`, keeping terminal auth mutation in `POST /users/log_in/passkey`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The working tree had many unrelated modified and untracked files from prior work. Only the plan-owned files and plan summary were staged.
- Node 22 exposes `navigator` as a getter-only global in the test runtime; the Node-stub test defines it via `Object.defineProperty` so the browser helper can be exercised deterministically.

## User Setup Required

None - no external service configuration required.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs --max-failures 1` - `10 tests, 0 failures`
- Acceptance greps passed for browser helper/hook strings, app.js imports and DOMContentLoaded binding, test assertions, unsupported error coverage, and hook teardown functions.

## Known Stubs

None.

## Threat Flags

None - this plan uses existing controller endpoints and challenge/session boundaries from prior plans.

## Next Phase Readiness

Ready for Plan 21-05 to mirror the generated server/controller/UI/assets into the example app with compile verification.

## Self-Check: PASSED

- Verified summary exists at `.planning/phases/21-passkey-liveviews-post-auth-controller/21-07-SUMMARY.md`.
- Verified task commits exist in git history: `d3946a1`, `7140ab8`.
- Verified no tracked file deletions were introduced by task commits.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-15*
