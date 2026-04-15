---
phase: 21-passkey-liveviews-post-auth-controller
plan: 01
subsystem: auth
tags: [passkeys, webauthn, controller, mfa, generator, tdd]

requires:
  - phase: 19-passkey-schema-contexts
    provides: Sigra.Passkeys CRUD/authentication primitives and generated UserPasskey schema
  - phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
    provides: Sigra.Plug.PasskeyChallenge issue/verify and runtime passkey config
provides:
  - Generated Auth passkey wrappers for registration, authentication, discoverable credentials, rename, delete, labels, and registration email delivery
  - Bundled passkey AAGUID snapshot and friendly label resolver
  - Controller-owned passkey option/completion endpoints for registration, passkey-primary login, MFA passkey upgrade, and sudo-protected deletion
  - Router injection for passkey POST routes under login, MFA, and sudo-protected MFA settings scopes
affects: [phase-21-passkey-ui, phase-22-passkeys-generator, passkeys, generated-auth]

tech-stack:
  added: []
  patterns:
    - Controller POST remains the only terminal passkey auth/session mutation boundary
    - Generated Auth wrappers normalize browser WebAuthn JSON before delegating to Sigra.Passkeys
    - Passkey display labels resolve nickname, bundled AAGUID label, device hint, then generic fallback

key-files:
  created:
    - lib/sigra/passkeys/device_name.ex
    - priv/sigra/passkey_aaguids.json
    - test/sigra/install/generator_passkeys_foundation_test.exs
  modified:
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/emails.ex
    - priv/templates/sigra.install/core/user_auth.ex
    - priv/templates/sigra.install/core/session_controller.ex
    - lib/sigra/install/features/core.ex

key-decisions:
  - "Passkey login, MFA upgrade, enrollment completion, and delete completion finalize through plain SessionController POST actions, not LiveView events."
  - "Discoverable passkey login first resolves the owning UserPasskey row by credential_id, then reuses the known-user Sigra.Passkeys.authenticate/4 path."
  - "Passkey management routes that mutate enrolled credentials are injected only under the generated :require_sudo router pipeline."

patterns-established:
  - "Generated controller passkey hooks submit passkey[response] JSON and the controller decodes it before calling Auth normalizers."
  - "Generated MFA passkey completion upgrades the persisted Sigra session and writes the returned raw token through UserAuth.put_user_session_token/2."

requirements-completed: [PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-11]

duration: 8min
completed: 2026-04-15
---

# Phase 21 Plan 01: Passkey Foundation and Controller POST Boundary Summary

**Generated passkey Auth wrappers, friendly device labels, registration notification email, and controller-owned POST completion routes for passkey-primary, MFA, enrollment, and deletion flows**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-15T21:39:56Z
- **Completed:** 2026-04-15T21:48:16Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added a bundled AAGUID registry snapshot plus `Sigra.Passkeys.DeviceName` label resolution for nickname, registry label, device hint, and `"Passkey"` fallback ordering.
- Added generated Auth passkey wrappers for list/count/label/register/authenticate/discoverable-auth/rename/delete, duplicate credential remapping, passkey-primary eligibility, and registration notification delivery.
- Added `SessionController` passkey options and completion actions using `Sigra.Plug.PasskeyChallenge.issue/4` and `verify/5`, with login failure copy collapsed to one generic message.
- Added router injection for passkey-primary login, conditional options, MFA passkey options/completion, and sudo-protected registration/delete routes.

## Task Commits

1. **Task 1 RED: Add failing passkey foundation tests** - `3c40351` (test)
2. **Task 1 GREEN: Add passkey foundation wrappers** - `bb81934` (feat)
3. **Task 2 RED: Add failing controller passkey route tests** - `6e280e5` (test)
4. **Task 2 GREEN: Add controller passkey completion routes** - `b7b0d7b` (feat)

## Files Created/Modified

- `lib/sigra/passkeys/device_name.ex` - Friendly passkey label resolver backed by the bundled AAGUID snapshot.
- `priv/sigra/passkey_aaguids.json` - Pinned registry snapshot with iCloud Keychain, Google Password Manager, 1Password, and Windows Hello entries.
- `priv/templates/sigra.install/core/auth.ex` - Generated passkey wrappers, normalizers, discoverable-auth lookup, duplicate remap, MFA upgrade wrapper, and eligibility check.
- `priv/templates/sigra.install/core/emails.ex` - Passkey registration notification email.
- `priv/templates/sigra.install/core/user_auth.ex` - Public `put_user_session_token/2` helper for MFA session upgrades.
- `priv/templates/sigra.install/core/session_controller.ex` - Passkey option/completion/delete controller actions and JSON builders.
- `lib/sigra/install/features/core.ex` - Router injection for passkey POST endpoints and sudo-protected MFA settings routes.
- `test/sigra/install/generator_passkeys_foundation_test.exs` - TDD coverage for generated templates and DeviceName behavior.

## Decisions Made

- Kept discoverable login generic on all failure paths: nil credential row, nil user, bad user handle, decode errors, challenge errors, and verification errors all return a single invalid passkey contract.
- Added `ensure_passkey_primary_user_eligible/1` in the generated Auth context so controller code does not duplicate passkey-primary and confirmed-email checks.
- Staged only Phase 21 route-injection hunks from `lib/sigra/install/features/core.ex`; pre-existing vault/encryption edits in that file were left unstaged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added passkey-primary eligibility wrapper**
- **Found during:** Task 2 (controller-owned passkey option/completion routes)
- **Issue:** The controller behavior required `Auth.ensure_passkey_primary_user_eligible(user)`, but the plan did not explicitly add the generated Auth helper.
- **Fix:** Added `ensure_passkey_primary_user_eligible/1` to enforce the app-level `:passkey_primary_enabled` flag and confirmed-email requirement before session creation.
- **Files modified:** `priv/templates/sigra.install/core/auth.ex`
- **Verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_mfa_test.exs --max-failures 1`
- **Committed in:** `b7b0d7b`

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Required for the controller contract and PK-UX-07. No scope expansion beyond the planned passkey-primary safety gate.

## Issues Encountered

- `lib/sigra/install/features/core.ex` had pre-existing unstaged vault/encryption changes. The Task 2 commit used partial staging so only the Phase 21 route-injection hunks were committed.

## User Setup Required

None - no external service configuration required.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkeys_foundation_test.exs --max-failures 1` - `14 tests, 0 failures`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_mfa_test.exs --max-failures 1` - `67 tests, 0 failures`
- Acceptance greps passed for AAGUID labels, `DeviceName`, Auth passkey wrappers, duplicate remap, passkey email copy, session-token writer, MFA upgrade wrapper, controller actions, route injection, and generic passkey sign-in error copy.
- LiveView finalization grep returned no matches for `authenticate_discoverable_passkey`, `UserAuth.log_in_user`, `Auth.delete_passkey(`, or `complete_passkey` in generated LiveView templates.

## Known Stubs

None.

## Next Phase Readiness

Ready for Plan 21-02 to build the MFA settings passkey management UI on top of the generated Auth wrappers and controller POST routes.

## Self-Check: PASSED

- Verified created files exist: `lib/sigra/passkeys/device_name.ex`, `priv/sigra/passkey_aaguids.json`, `test/sigra/install/generator_passkeys_foundation_test.exs`, and this summary.
- Verified task commits exist in git history: `3c40351`, `bb81934`, `6e280e5`, `b7b0d7b`.

---
*Phase: 21-passkey-liveviews-post-auth-controller*
*Completed: 2026-04-15*
