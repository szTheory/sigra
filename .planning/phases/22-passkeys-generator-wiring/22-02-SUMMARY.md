---
phase: 22-passkeys-generator-wiring
plan: 02
subsystem: auth
tags: [installer, generator, passkeys, javascript, testing]
requires:
  - phase: 22-passkeys-generator-wiring
    provides: "Default-on passkeys installer contract and passkeys? binding"
  - phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
    provides: "Passkey browser helper/manual-action patterns"
provides:
  - "Passkey-owned router, config, mix.exs, and assets/package.json injections"
  - "Generated browser helper backed by @simplewebauthn/browser"
  - "Focused JS and manifest coverage for passkey-owned install wiring"
affects: [22-03, 22-04, generator-flags, passkeys]
tech-stack:
  added:
    - "@simplewebauthn/browser"
    - "wax_"
  patterns:
    - "Feature-owned injector fragments for whole-artifact passkey wiring"
    - "Local browser helper wrapper over @simplewebauthn/browser with Node-test stubs"
key-files:
  created:
    - priv/templates/sigra.install/passkeys/router_injection.ex
    - priv/templates/sigra.install/passkeys/config_injection.ex
    - priv/templates/sigra.install/passkeys/mix_exs_injection.ex
    - priv/templates/sigra.install/passkeys/package_json_injection.json
  modified:
    - lib/sigra/install/features/passkeys.ex
    - lib/sigra/install/features/core.ex
    - lib/sigra/install/injector.ex
    - priv/templates/sigra.install/passkeys/passkey_browser.js
    - test/sigra/install/features/passkeys_test.exs
    - test/sigra/install/features/passkeys_js_test.exs
    - test/sigra/install/features/coverage_test.exs
key-decisions:
  - "Passkey-only routes, runtime config, mix deps, and package deps now belong to Features.Passkeys rather than Core."
  - "The generated passkey browser boundary stays local: passkey_hooks.js imports ./passkey_browser, and passkey_browser.js alone wraps @simplewebauthn/browser."
  - "Injector fallback for mix.exs and assets/package.json must fail loudly with manual instructions rather than silently partially applying."
patterns-established:
  - "Whole-artifact passkey wiring lives in feature-owned fragment templates and gets injected through explicit anchors."
  - "Node-based JS contract tests rewrite local helper imports to stubs instead of importing package code directly."
requirements-completed: [PK-02]
duration: 17 min
completed: 2026-04-16
---

# Phase 22 Plan 02: Passkey Feature-Owned Wiring Summary

**Passkey-owned route/config/dependency injections and a generated browser helper that now really consumes `@simplewebauthn/browser`**

## Performance

- **Duration:** 17 min
- **Started:** 2026-04-16T12:49:10Z
- **Completed:** 2026-04-16T13:06:10Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Moved passkey-only router routes, runtime config, `mix.exs` dependency insertion, and `assets/package.json` dependency insertion into `Sigra.Install.Features.Passkeys`.
- Added injector support for `:mix_deps` and `:package_json_dependencies`, including explicit manual-action fallback text when host file shapes drift.
- Reworked the generated browser helper so the enabled path uses `@simplewebauthn/browser`, while preserving Sigra-specific login status mapping and wrapper behavior for hooks/tests.
- Updated focused feature, JS, and coverage tests to pin manifest ownership and the package-backed browser contract.

## Task Commits

1. **Task 1: Move passkey-only route, config, and dependency wiring into Features.Passkeys** - `92b2452` (feat)
2. **Task 2: Align generated browser imports with `@simplewebauthn/browser`** - `bae6b13` (test)

## Files Created/Modified

- `lib/sigra/install/features/passkeys.ex` - added passkey-owned router/config/dependency injections and expanded manual-action reporting.
- `lib/sigra/install/features/core.ex` - removed passkey-only route emission from Core.
- `lib/sigra/install/injector.ex` - added mix/package dependency anchors and explicit fallback instructions.
- `priv/templates/sigra.install/passkeys/router_injection.ex` - owns passkey route injection.
- `priv/templates/sigra.install/passkeys/config_injection.ex` - owns passkey runtime config injection.
- `priv/templates/sigra.install/passkeys/mix_exs_injection.ex` - inserts `{:wax_, "~> 0.7"}`.
- `priv/templates/sigra.install/passkeys/package_json_injection.json` - inserts `@simplewebauthn/browser`.
- `priv/templates/sigra.install/passkeys/passkey_browser.js` - wraps `@simplewebauthn/browser` behind Sigra’s local helper API.
- `test/sigra/install/features/passkeys_test.exs` - pins passkey-owned manifest behavior.
- `test/sigra/install/features/passkeys_js_test.exs` - pins the generated JS/package contract and Node helper shims.
- `test/sigra/install/features/coverage_test.exs` - records the new passkey-owned fragments in coverage ownership.

## Decisions Made

- Kept the package import in `passkey_browser.js` instead of `passkey_hooks.js` so hooks continue to depend on Sigra’s wrapper API.
- Used JSON decoding/encoding for `assets/package.json` edits instead of string splicing.
- Left unrelated untracked passkey template files outside this plan’s scope.

## Deviations from Plan

- The final JS task commit includes the focused JS test updates alongside the browser-helper code because the contract change is inseparable from its runtime coverage.

## Issues Encountered

- Node ESM tests initially failed after the import boundary moved; fixing the stub rewrite from `./passkey_browser` resolved the runtime lookup.

## User Setup Required

None - generated apps receive package/dependency wiring automatically on the enabled path, with manual instructions emitted only if host file shapes are non-standard.

## Next Phase Readiness

- Shared auth templates can now consume a clean feature boundary in Plan 22-03 without Core re-emitting passkey-only routes or config.
- Opt-out coverage can treat package and asset omission as real behavior because the enabled path now imports the package it installs.

## Self-Check: PASSED

Verified:
- `.planning/phases/22-passkeys-generator-wiring/22-02-SUMMARY.md` exists
- `92b2452` is present in git history
- `bae6b13` is present in git history
- `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/passkeys_js_test.exs test/sigra/install/features/coverage_test.exs --max-failures 1` passed

---
*Phase: 22-passkeys-generator-wiring*
*Completed: 2026-04-16*
