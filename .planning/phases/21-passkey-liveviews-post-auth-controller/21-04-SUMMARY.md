---
phase: 21-passkey-liveviews-post-auth-controller
plan: 04
subsystem: auth
tags: [passkeys, webauthn, controller, registration, recovery, tdd]

requires:
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: Plan 21-01 controller POST passkey completion routes and Auth passkey wrappers
provides:
  - Identifier-first passkey-primary controller login markup with password and magic-link fallback
  - Signup-time passkey enrollment intent carried through email confirmation into sudo-gated MFA settings
  - Confirmed-email and mandatory magic-link recovery helpers for passkey-primary accounts
affects: [phase-21-passkey-ui, phase-22-passkeys-generator, passkeys, generated-auth]

tech-stack:
  added: []
  patterns:
    - Controller-rendered passkey-primary login posts final session creation to SessionController
    - Signup enrollment intent is preserved in the confirmation URL and converted to server-side user_return_to only after successful confirmation
    - Passkey-primary eligibility is centralized in generated Auth helpers

key-files:
  created:
    - test/sigra/install/generator_passkey_primary_login_test.exs
  modified:
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/confirmation_controller.ex
    - priv/templates/sigra.install/core/session_controller.ex
    - priv/templates/sigra.install/core/login_html.ex
    - priv/templates/sigra.install/core/registration_html.ex
    - priv/templates/sigra.install/core/registration_live.ex
    - test/sigra/install/generator_passkey_primary_login_test.exs

key-decisions:
  - "Passkey-primary login remains one controller-rendered page with visible password and magic-link recovery."
  - "Signup-time passkey enrollment starts only after email confirmation, then routes through sudo before /users/settings/mfa#passkeys."
  - "Generated Auth owns the passkey-primary confirmed-email and magic-link recovery invariants."

patterns-established:
  - "Controller templates can use assigns[:passkey_primary_enabled] for optional controller-mode markup when the controller assign may be absent."
  - "Passkey-primary session completion maps unconfirmed users to the generic passkey failure path and preserves the submitted email flash."

requirements-completed: [PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-11]

duration: 5min
completed: 2026-04-15
---

# Phase 21 Plan 04: Passkey-Primary Login and Recovery Summary

**Identifier-first passkey-primary login with visible recovery plus signup enrollment handoff through confirmed email and sudo-gated passkey setup**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-15T22:12:24Z
- **Completed:** 2026-04-15T22:17:40Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added controller-rendered passkey-primary login markup with `autocomplete="username webauthn"`, `/users/log_in/passkey` completion, and `/users/log_in/passkey/options` option lookup.
- Kept password login and magic-link recovery visible on the same login page, with no LiveView submit boundary.
- Added config-gated signup enrollment controls to LiveView and controller registration templates.
- Routed selected signup enrollment through `?enroll_passkey=1`, then into `:user_return_to` after successful confirmation so passkey setup starts behind sudo.
- Centralized passkey-primary eligibility and recovery invariants in generated Auth helpers, with unconfirmed users rejected before passkey authentication/session creation.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing passkey-primary login template coverage** - `c480a03` (test)
2. **Task 1 GREEN: Add passkey-primary controller login markup** - `060681d` (feat)
3. **Task 2 RED: Add failing signup enrollment invariants** - `8ae0761` (test)
4. **Task 2 GREEN: Enforce passkey-primary signup recovery invariants** - `2fcc46f` (feat)

## Files Created/Modified

- `test/sigra/install/generator_passkey_primary_login_test.exs` - TDD coverage for login markup, enrollment handoff, confirmed-email enforcement, and recovery invariants.
- `priv/templates/sigra.install/core/login_html.ex` - Passkey-primary login branch with passkey form, password fallback, magic-link recovery, and DOMContentLoaded initializer.
- `priv/templates/sigra.install/core/auth.ex` - `passkey_primary_user_eligible?/1`, `ensure_passkey_primary_user_eligible/1`, and `magic_link_recovery_available?/0`.
- `priv/templates/sigra.install/core/session_controller.ex` - Explicit `:email_not_confirmed` passkey-primary failure mapping before session creation.
- `priv/templates/sigra.install/core/registration_live.ex` - Config-gated signup passkey enrollment checkbox and confirmation URL handoff.
- `priv/templates/sigra.install/core/registration_html.ex` - Equivalent controller-mode signup enrollment checkbox.
- `priv/templates/sigra.install/core/confirmation_controller.ex` - Confirmation success path that writes sudo passkey enrollment return into the Plug session before logging in the confirmed user.

## Decisions Made

- Kept passkey-primary fallback recovery on the same login page rather than splitting passkey and password into separate screens.
- Used a server-side `:user_return_to` session write after successful confirmation instead of passing unsupported redirect params to `UserAuth.log_in_user/3`.
- Used `assigns[:passkey_primary_enabled]` in the controller registration template so optional passkey markup does not crash when older generated controllers have not assigned the flag.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The working tree had many unrelated modified and untracked files from prior work. Only the plan-owned files were staged for task commits.

## User Setup Required

None - no external service configuration required.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkey_primary_login_test.exs test/sigra/install/generator_mfa_test.exs --max-failures 1` - `59 tests, 0 failures`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkey_primary_login_test.exs test/sigra/install/generator_wiring_test.exs --max-failures 1` - `38 tests, 0 failures`
- Acceptance greps passed for passkey-primary login markup, absence of `phx-submit`, signup enrollment wiring, confirmed-email handoff, unsupported `return_to` params absence, and mandatory magic-link recovery.

## Known Stubs

None.

## Next Phase Readiness

Ready for Plan 21-07 to add the conditional UI/autofill browser binding on top of the controller-rendered passkey-primary login surface.

## Self-Check: PASSED

- Verified summary exists at `.planning/phases/21-passkey-liveviews-post-auth-controller/21-04-SUMMARY.md`.
- Verified task commits exist in git history: `c480a03`, `060681d`, `8ae0761`, `2fcc46f`.
- Verified no tracked file deletions were introduced by task commits.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-15*
