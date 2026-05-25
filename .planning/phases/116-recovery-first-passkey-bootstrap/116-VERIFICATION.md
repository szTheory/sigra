---
phase: 116-recovery-first-passkey-bootstrap
slug: recovery-first-passkey-bootstrap
status: passed
created: 2026-05-25
updated: 2026-05-25
requirements: [PK-03]
backfilled_by: Phase 120
score: 3/3 focused reruns passed
---

# Phase 116 — Verification

Supersedes 116-01-SUMMARY.md as the authoritative PK-03 proof surface.

This backfill exists because `.planning/v1.26-MILESTONE-AUDIT.md` marked `PK-03` orphaned: Phase 116 shipped the confirmation/controller seam, bootstrap LiveView seam, generator proof seam, and passkey-primary posture, but it never received a phase-local verification artifact and `116-01-SUMMARY.md` ended with `## Self-Check: FAILED`. This document closes only the repaired-form `PK-03` evidence path when all focused reruns pass. It does not claim broader `v1.26` re-audit closure.

## Closeout Goals

| Goal | Result | Evidence |
|------|--------|----------|
| Phase 116 has an authoritative PK-03 verification home | Pass | This file replaces `116-01-SUMMARY.md` as the proof authority and names the confirmation/controller seam, bootstrap LiveView seam, generator proof seam, and the canonical browser file `passkey-login.spec.ts`. |
| Current-head focused proof exists for generator and example-host PK-03 seams | Pass | The root generator fallback command passed with `14 tests, 0 failures`, and the targeted example-host suite passed with `28 tests, 0 failures`. |
| Served-route browser proof reaches confirmation -> bootstrap -> explicit enrollment on current HEAD | Pass | `passkey-login.spec.ts` now follows the dev mailbox confirmation link, preserves `?enroll_passkey=1`, reaches the sudo/bootstrap handoff, renders the bootstrap banner and explicit interstitial, and completes passkey enrollment through the real POST endpoints. |

## Evidence

### Root generator proof

- Command:
  `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'`
  Result: `14 tests, 0 failures`.

This receipt proves the generated-host posture remains aligned on current HEAD:

- `test/sigra/install/generator_passkey_primary_login_test.exs`
- `test/sigra/install/generator_passkey_management_test.exs`

### Example-host targeted proof

- Command:
  `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs`
  Result: `28 tests, 0 failures`.

This receipt proves the current-head server-side seams that define `PK-03`:

- `test/example/test/example_web/controllers/confirmation_controller_test.exs`
- `test/example/test/example_web/live/passkey_settings_live_test.exs`
- `test/example/test/example_web/controllers/passkey_session_controller_test.exs`
- `test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs`

### Served-route browser proof

- Command:
  `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts --project=chromium`
  Result: passed (`2 passed (5.7s)`). The canonical confirmation/bootstrap lane now:
  - checks the signup opt-in control,
  - pulls the newest confirmation email from `/dev/mailbox/json`,
  - preserves `?enroll_passkey=1`,
  - clears the post-registration session before following the link,
  - reaches the sudo/bootstrap handoff,
  - waits for the bootstrap banner and the explicit `Create passkey` / `Not now` interstitial,
  - still waits for `/users/settings/mfa/passkeys/options` and `/users/settings/mfa/passkeys`.

This browser seam lives in:

- `test/example/priv/playwright/tests/passkey-login.spec.ts`

## Proved / Did Not Prove

**Proved**

- The confirmation/controller contract remains explicit in source and routing: `/users/confirm/:token` is served by `ConfirmationController`, and the controller still carries the bootstrap handoff through `passkey_bootstrap_return_to/0`.
- The bootstrap LiveView seam still renders `Add a passkey now or skip for now`, then `Create a passkey`, `Create passkey`, and `Not now`.
- The passkey-primary login and MFA fallback seams still keep another real recovery path visible on current HEAD.
- The generator proof seam still matches the intended recovery-first passkey-primary posture.
- The served-route confirmation link now reaches the sudo/bootstrap handoff on current HEAD and completes the explicit passkey-enrollment lane in Chromium.

**Did Not Prove**

- Any cross-browser, cross-device, sync, restore, escrow, or broader milestone closure claim.

## Residuals

- The focused root, example-host, and canonical browser slices are green on current HEAD.
- The local example host emits repeated webhook-delivery `500` noise during Playwright signup flows. Those errors did not fail the focused ExUnit receipts, but they add background noise while debugging the confirmation-link lane.

## Status

Passed — Phase 116 now has an authoritative `PK-03` verification home with current-head generator, example-host, and served-route browser receipts, backfilled by Phase 120.
