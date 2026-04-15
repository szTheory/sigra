---
phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
plan: 03
subsystem: infra
tags: [passkeys, phoenix, liveview, simplewebauthn, generator]
requires:
  - phase: 20-01
    provides: Passkey challenge session storage and verification seam
  - phase: 20-02
    provides: Runtime passkey config validation and rate limiting
provides:
  - Generated `assets/js/passkey_hooks.js` Phoenix hook seam for passkey ceremonies
  - Deterministic `assets/js/app.js` injection for the standard Phoenix LiveSocket hook shape
  - Exact manual fallback instructions for non-standard `app.js` layouts
affects: [phase-21-passkey-ui, phase-22-passkeys-generator-wiring, generator]
tech-stack:
  added: [@simplewebauthn/browser hook template]
  patterns: [marker-gated app.js injection, report-backed manual fallback instructions]
key-files:
  created:
    - priv/templates/sigra.install/passkeys/passkey_hooks.js
    - priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js
    - test/sigra/install/features/passkeys_js_test.exs
  modified:
    - lib/sigra/install/injector.ex
    - lib/sigra/install/features/passkeys.ex
    - lib/sigra/install/runner.ex
    - test/support/install_fixture.ex
key-decisions:
  - "Use `// Sigra passkeys:start` as the authoritative idempotency gate and only mutate `assets/js/app.js` when the standard colocated-hooks LiveSocket shape is present."
  - "Surface custom-layout fallback through installer manual-action reporting so stdout shows exact copy-pasteable import and hook merge lines."
patterns-established:
  - "JS injector pattern: parse a small template fragment, inject deterministic markers at imports, and replace only the exact blessed LiveSocket hooks line."
  - "Feature fallback pattern: injection returns a manual-action report entry and the feature echoes it through post-install instructions."
requirements-completed: [GEN-06]
duration: 12min
completed: 2026-04-15
---

# Phase 20 Plan 03: Passkey JS Runtime Wiring Summary

**Generated Phoenix passkey hooks plus deterministic `assets/js/app.js` hook merging with exact manual fallback text for custom asset layouts**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-15T17:15:30Z
- **Completed:** 2026-04-15T17:27:33Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added a real installer integration spec that locks marker injection, rerun idempotency, manual fallback text, and generated hook exports.
- Generated `assets/js/passkey_hooks.js` with stable `PasskeyRegister` and `PasskeyAuthenticate` hook exports using `@simplewebauthn/browser`.
- Added a dedicated `inject_app_js_passkeys/2` path that merges into `...colocatedHooks` on the blessed Phoenix shape and records exact manual instructions otherwise.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write GEN-06 installer tests and asset fixture helpers** - `f3a7e44` (test)
2. **Task 2: Implement generated passkey hooks and deterministic app.js wiring** - `1e10020` (feat)

## Files Created/Modified

- `test/support/install_fixture.ex` - Adds narrow tmp-app asset read/write helpers used by install integration tests.
- `test/sigra/install/features/passkeys_js_test.exs` - Covers standard injection, idempotent reruns, manual fallback, and template exports.
- `lib/sigra/install/injector.ex` - Adds `inject_app_js_passkeys/2`, marker detection, standard-shape replacement, and manual-fallback signaling.
- `lib/sigra/install/features/passkeys.ex` - Registers `passkey_hooks.js`, owns the `assets/js/app.js` injection, and emits fallback instructions from report data.
- `lib/sigra/install/runner.ex` - Preserves exact manual-action text from feature injections so install stdout can surface fallback steps.
- `test/sigra/install/features/passkeys_test.exs` - Updates passkeys feature expectations for the new asset file, injection, and manual-instruction behavior.
- `priv/templates/sigra.install/passkeys/passkey_hooks.js` - Ships the generated LiveView passkey hook seam.
- `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` - Defines the marker-backed import and merged hook lines used by the injector.

## Decisions Made

- Marker detection is authoritative on re-runs: if `// Sigra passkeys:start` exists, the installer treats `assets/js/app.js` as already wired and does not attempt secondary heuristics.
- Manual fallback flows through the install report rather than ad hoc logging, so feature-owned instructions stay exact and testable through the real runner path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added runner support for exact manual-action passthrough**
- **Found during:** Task 2 (Implement generated passkey hooks and deterministic app.js wiring)
- **Issue:** The existing runner wrapped injection errors with `inspect/1`, which would have mangled the exact import and hook-registration lines the plan required in fallback output.
- **Fix:** Added a dedicated `{:manual_action, instruction}` error path in `Sigra.Install.Runner` and updated `Features.Passkeys.post_instructions/2` to echo those recorded instructions.
- **Files modified:** `lib/sigra/install/runner.ex`, `lib/sigra/install/features/passkeys.ex`
- **Verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs test/sigra/install/features/passkeys_test.exs --max-failures 1`
- **Committed in:** `1e10020`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The deviation was required to make the real install path emit exact fallback instructions without widening generator scope.

## Issues Encountered

- The plan’s `mix test ... -x` verification command is not valid in this repo’s current Mix version; equivalent fail-fast verification was run with `--max-failures 1`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 21 can now assume generated `PasskeyRegister` and `PasskeyAuthenticate` Phoenix hooks plus deterministic `PasskeyHooks` wiring on the standard Phoenix asset path.
- Custom asset layouts now receive exact import and merged-hook instructions instead of guessed rewrites, so Phase 22 can build on the same trusted generator posture.

## Self-Check: PASSED

---
*Phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra*
*Completed: 2026-04-15*
