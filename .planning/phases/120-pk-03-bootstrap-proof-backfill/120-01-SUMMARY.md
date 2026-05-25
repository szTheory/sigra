# Phase 120 Plan 01 Summary

## Outcome

Repaired the `PK-03` proof scaffolding around Phase 116 by:

- updating the canonical browser lane to start from signup passkey intent and the dev mailbox confirmation link,
- restoring `/users/confirm/:token` to `ConfirmationController` on the example host,
- preserving `?enroll_passkey=1` in the shared mailbox extractor,
- fixing the confirmation-token hashing mismatch so emailed confirmation links resolve on current HEAD,
- creating authoritative Phase 116 verification and validation artifacts.

## Tasks Completed

### Task 1

- `test/example/priv/playwright/tests/passkey-login.spec.ts` now checks the signup opt-in, fetches the latest mailbox confirmation link, asserts `/users/confirm/` is present, and still waits for `/users/settings/mfa/passkeys/options` plus `/users/settings/mfa/passkeys`.
- `test/example/lib/example_web/router.ex` now serves `/users/confirm/:token` through `ConfirmationController`, while `live "/confirm"` remains the code-entry route.
- `test/example/test/example_web/controllers/confirmation_controller_test.exs` now locks the route contract explicitly.
- `test/example/priv/playwright/fixtures/mailbox.ts` now preserves confirmation query strings such as `?enroll_passkey=1`.

### Task 2

- Added `.planning/phases/116-recovery-first-passkey-bootstrap/116-VERIFICATION.md` as the repaired-form Phase 116 proof home for `PK-03`.

### Task 3

- Added `.planning/phases/116-recovery-first-passkey-bootstrap/116-VALIDATION.md` as the Phase 116 Nyquist map for the same proof seams.

## Verification

- `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` -> passed (`14 tests, 0 failures`).
- `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs` -> passed (`28 tests, 0 failures`).
- `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts --project=chromium` -> passed (`2 passed (5.7s)`).

## Deviations from Plan

### [Rule 1 - Runtime integration defect] Confirmation-link runtime failure narrowed to token hashing and then cleared

- Found during: Task 1 verification
- Issue: the example app emitted a correct `?enroll_passkey=1` link and routed `/users/confirm/:token` through `ConfirmationController`, but the served-route confirmation request still resolved to `/users/confirm` with an invalid/expired-link flash.
- Fix: after narrowing the lane with the router, Playwright, and mailbox changes, the remaining defect was corrected in `lib/sigra/auth.ex` by storing the hash of the transported confirmation token rather than the underlying raw bytes hash.
- Verification: focused generator and example-host suites passed, then Playwright replayed green on the real confirmation-link handoff.

Total deviations: 1 auto-documented and resolved. Impact: Phase 116 now has authoritative repaired-form proof artifacts and the served-route confirmation -> bootstrap lane is green.

## Self-Check: PASSED
