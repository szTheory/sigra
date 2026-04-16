---
phase: 22-passkeys-generator-wiring
plan: 03
subsystem: auth
tags: [installer, generator, passkeys, liveview, testing]
requires:
  - phase: 22-passkeys-generator-wiring
    provides: "Feature-owned passkey route/config/dependency/browser wiring"
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: "Passkey controller and LiveView UX contracts"
provides:
  - "Shared auth templates that omit passkey branches when passkeys are disabled"
  - "Generated-app omission coverage for both --no-passkeys legs"
  - "Signup/login/MFA templates with passkey state fully removed on opt-out"
affects: [22-04, generator-flags, passkeys]
tech-stack:
  added: []
  patterns:
    - "EEx guard blocks around passkey-only assigns, aliases, and controller/liveview branches"
    - "Generated-app omission tests that inspect source trees rather than compiled artifacts"
key-files:
  created:
    - test/sigra/install/generator_passkeys_opt_out_test.exs
  modified:
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/session_controller.ex
    - priv/templates/sigra.install/core/login_html.ex
    - priv/templates/sigra.install/core/mfa_settings_live.ex
    - priv/templates/sigra.install/core/mfa_challenge_live.ex
    - priv/templates/sigra.install/core/registration_html.ex
    - priv/templates/sigra.install/core/confirmation_controller.ex
    - priv/templates/sigra.install/core/registration_live.ex
key-decisions:
  - "Opt-out installs should omit passkey assigns entirely rather than keeping false-valued compatibility assigns."
  - "RegistrationLive also needed passkey guards, even though it was missing from the original file list, because signup enrollment prompts are part of the plan’s omission contract."
  - "Generated omission checks must ignore compiled output under _build so binary artifacts do not create false positives."
patterns-established:
  - "For shared templates, passkey-only UI and assigns should disappear completely on disabled installs instead of lingering as inert placeholders."
  - "Generated-app omission suites should validate real source outputs for both disabled flag combinations before CI matrix expansion."
requirements-completed: [PK-02]
duration: 13 min
completed: 2026-04-16
---

# Phase 22 Plan 03: Shared Template Omission Summary

**Shared auth templates now gate passkey-only branches cleanly, and generated-app regression tests prove both disabled passkey combinations stay structurally clean**

## Performance

- **Duration:** 13 min
- **Started:** 2026-04-16T13:06:30Z
- **Completed:** 2026-04-16T13:19:45Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Guarded shared auth templates so disabled installs no longer emit passkey-primary login state, passkey management branches, or passkey confirmation/signup residue.
- Added the generated-app omission suite for both `--no-passkeys` and `--no-organizations --no-passkeys`, covering routes, files, dependencies, config, and source-level residue.
- Fixed real disabled-path leaks surfaced by the new suite in `session_controller.ex` and `registration_live.ex`.

## Task Commits

1. **Task 1: Gate shared auth templates with `passkeys?` and remove disabled-path residue** - `86e08e1` (feat)
2. **Task 2: Add generated-app omission regression coverage for both disabled passkey legs** - `d218498` (test)

## Files Created/Modified

- `priv/templates/sigra.install/core/auth.ex` - keeps passkey helpers/eligibility logic behind passkey guards.
- `priv/templates/sigra.install/core/session_controller.ex` - removes disabled-path `passkey_primary_enabled` residue and keeps passkey actions gated.
- `priv/templates/sigra.install/core/mfa_settings_live.ex` - avoids disabled-path passkey compile/residue leaks.
- `priv/templates/sigra.install/core/confirmation_controller.ex` - keeps passkey enrollment follow-through behind passkey guards.
- `priv/templates/sigra.install/core/registration_live.ex` - removes signup-time passkey enrollment UI and assign handling on opt-out installs.
- `test/sigra/install/generator_passkeys_opt_out_test.exs` - proves omission across both disabled flag combinations on real generated apps.

## Decisions Made

- Treated `passkey_primary_enabled: false` as a residue leak, not an acceptable compatibility shim.
- Extended the shared-template guard sweep into `registration_live.ex` because the generated opt-out app still surfaced passkey signup enrollment there.
- Tightened the omission test to scan generated source trees only, excluding compiled artifacts.

## Deviations from Plan

- `registration_live.ex` was updated even though it was not listed in the original plan file set; the generated opt-out app proved it was part of the same user-facing omission surface.

## Issues Encountered

- The first omission-suite iterations failed on test path assumptions and `_build` false positives before surfacing the real disabled-path leaks.
- The new suite caught two actual regressions: `session_controller.ex` still rendered `passkey_primary_enabled: false`, and `registration_live.ex` still emitted passkey enrollment UX on opt-out installs.

## User Setup Required

None.

## Next Phase Readiness

- CI and smoke harness work in Plan 22-04 can now rely on a source-clean opt-out install instead of only focused template assertions.
- Both disabled passkey combinations have an authoritative generated-app regression suite in place.

## Self-Check: PASSED

Verified:
- `.planning/phases/22-passkeys-generator-wiring/22-03-SUMMARY.md` exists
- `86e08e1` is present in git history
- `d218498` is present in git history
- `mix test test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs --max-failures 1` passed

---
*Phase: 22-passkeys-generator-wiring*
*Completed: 2026-04-16*
