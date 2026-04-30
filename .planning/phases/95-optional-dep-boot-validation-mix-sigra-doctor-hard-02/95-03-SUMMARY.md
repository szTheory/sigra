---
phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02
plan: 03
subsystem: infra
tags: [optional-deps, mix-task, warnings, jwt, oban]
requires:
  - phase: 95-01
    provides: Sigra.OptionalDeps registry metadata and doctor row helpers
  - phase: 95-02
    provides: runtime optional dependency enforcement for async email, bcrypt, and QR rendering
provides:
  - contextual `mix sigra.doctor` output with enforced vs advisory optional-dep rows
  - host-proven compile warning support for enabled missing optional deps
  - narrower global `no_warn_undefined` posture for enforced optional deps
affects: [phase-95, install-smoke, warning-clean-ci]
tech-stack:
  added: []
  patterns: [registry-backed doctor reporting, compile-time host-proof warning macro, localized optional-dep suppression]
key-files:
  created:
    - lib/mix/tasks/sigra.doctor.ex
    - test/mix/tasks/sigra.doctor_test.exs
    - test/sigra/application_optional_deps_test.exs
  modified:
    - lib/sigra/application.ex
    - lib/sigra/install/features/core.ex
    - lib/sigra/optional_deps.ex
    - mix.exs
    - test/example/test/example_web/smoke/install_compile_test.exs
    - lib/sigra/plug/fetch_bearer.ex
    - lib/sigra/hashers/bcrypt.ex
    - lib/sigra/mfa.ex
    - lib/sigra/jwt.ex
    - lib/sigra/jwt/signer.ex
key-decisions:
  - "Kept `mix sigra.doctor` contextual: advisory rows render by default, but only enabled enforced rows can halt with status 2."
  - "Moved Joken/Bcrypt/EQRCode warning suppression to local module seams and reserved the global `mix.exs` list for remaining advisory or worker references."
  - "Used a compile-time macro in `Sigra.Application` for host-proven warnings instead of relying on speculative undefined-module warnings."
patterns-established:
  - "Doctor rows should derive from `Sigra.OptionalDeps.doctor_row/2` so enablement evidence, status, and remediation stay aligned."
  - "Generated-host compile contracts can be asserted from root tests by compiling a synthetic host module and seeding only the endpoint config data it needs."
requirements-completed: [HARD-02]
duration: 13min
completed: 2026-04-30
---

# Phase 95 Plan 03: Optional-Dep Doctor and Warning Posture Summary

**Contextual optional-dependency diagnostics via `mix sigra.doctor`, host-proven JWT compile warnings, and a narrower warning-suppression posture for enforced deps**

## Performance

- **Duration:** 13 min
- **Started:** 2026-04-30T21:08:20Z
- **Completed:** 2026-04-30T21:21:09Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments
- Added `mix sigra.doctor` with deterministic enforced/advisory rows, shared remediation copy, and `System.halt(2)` only for blocking enforced rows.
- Added compile-warning support in `Sigra.Application` so statically enabled missing optional deps can warn from a host-proof seam instead of broad global suppression.
- Narrowed `mix.exs` global `no_warn_undefined` posture and localized enforced-dep suppressions to the modules that actually reference `Joken`, `Bcrypt`, and `EQRCode`.

## Task Commits

1. **Task 1: Implement `mix sigra.doctor` as a contextual optional-dep validator** - `55b543d` (test), `3cc35d3` (feat), `f275c9d` (fix)
2. **Task 2: Replace broad warning suppression with host-proven diagnostics** - `83020da` (test), `283d652` (feat)

## Files Created/Modified
- `lib/mix/tasks/sigra.doctor.ex` - doctor task entry point, row rendering, and contextual exit semantics.
- `test/mix/tasks/sigra.doctor_test.exs` - task-level coverage for enforced/advisory output and halt behavior.
- `lib/sigra/install/features/core.ex` - shared optional-dependency remediation copy for installer + doctor messaging.
- `lib/sigra/optional_deps.ex` - delegated remediation strings to the installer-owned helper.
- `lib/sigra/application.ex` - non-static boot-warning helper plus compile-time warning helpers for enabled missing optional deps.
- `test/sigra/application_optional_deps_test.exs` - boot-warning and compile-warning coverage.
- `mix.exs` - reduced the global suppression list to advisory and worker seams.
- `test/example/test/example_web/smoke/install_compile_test.exs` - compile-contract coverage for JWT warnings and root-run example path setup.
- `lib/sigra/plug/fetch_bearer.ex`, `lib/sigra/hashers/bcrypt.ex`, `lib/sigra/mfa.ex`, `lib/sigra/jwt.ex`, `lib/sigra/jwt/signer.ex` - narrow support changes to keep `--warnings-as-errors` meaningful after shrinking the global suppression list.

## Decisions Made

- `Sigra.Application.warn_for_enabled_optional_deps!/1` became the explicit compile-warning seam because it can prove host enablement and emit stable, testable warning text without reintroducing speculative compiler noise.
- The doctor task accepts a test-only injected halt hook but preserves a literal default `System.halt(2)` path so its source contract remains obvious.
- Root-level example smoke verification now seeds only the Example app code path and minimal Phoenix endpoint config instead of trying to boot the full example OTP app.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed the stray JOSE compile warning from install smoke**
- **Found during:** Task 2
- **Issue:** `Sigra.Plug.FetchBearer` referenced `JOSE.JWT.peek_payload/1` directly, which surfaced an unrelated compile warning in the generated-host smoke flow.
- **Fix:** Switched the guarded peek call to `apply/3` so the JOSE reference stays behind the runtime-loaded check.
- **Files modified:** `lib/sigra/plug/fetch_bearer.ex`
- **Verification:** `MIX_ENV=test mix test test/sigra/application_optional_deps_test.exs test/example/test/example_web/smoke/install_compile_test.exs && MIX_ENV=test mix compile --warnings-as-errors`
- **Committed in:** `283d652`

**2. [Rule 3 - Blocking] Made the root verification command load the example smoke contract truthfully**
- **Found during:** Task 2
- **Issue:** Running the owned example smoke file from the repo root did not have `Example.*` beams or endpoint config available, so the plan’s verification command failed before reaching the new warning assertions.
- **Fix:** Seeded the example code path plus the minimal Phoenix ETS/persistent-term endpoint config inside the smoke test setup and localized the `Example.Accounts` compile suppression to that test file.
- **Files modified:** `test/example/test/example_web/smoke/install_compile_test.exs`
- **Verification:** `MIX_ENV=test mix test test/sigra/application_optional_deps_test.exs test/example/test/example_web/smoke/install_compile_test.exs`
- **Committed in:** `83020da`, `283d652`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were required to make the planned warning-clean verification path truthful from the root project. No architecture change or scope broadening was introduced.

## Issues Encountered

- The explicit `System.halt(2)` source check conflicted with the injected test halt hook; a small follow-up fix restored the literal default halt call without breaking doctor task tests.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 95 now has plan 03 complete with the doctor task and warning-posture slice verified.
- `HARD-02` remains open at the phase level because the dep-off CI matrix and remaining verification plans are still pending.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-03-SUMMARY.md`.
- Commits `55b543d`, `3cc35d3`, `f275c9d`, `83020da`, and `283d652` exist in git history.

---
*Phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02*
*Completed: 2026-04-30*
