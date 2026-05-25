---
phase: 115-last-passkey-safety-deletion-truth
slug: last-passkey-safety-deletion-truth
status: passed
created: 2026-05-24
updated: 2026-05-24
requirements: [PK-02]
backfilled_by: Phase 119
score: 3/3 focused reruns passed
verified_at: 2026-05-24T20:17:46Z
---

# Phase 115 — Verification

Supersedes 115-01-SUMMARY.md as the authoritative PK-02 proof surface.

This backfill exists because `.planning/v1.26-MILESTONE-AUDIT.md` marked `PK-02` orphaned: Phase 115 shipped the last-passkey delete behavior, but it never received a phase-local verification artifact or Nyquist validation artifact. This document closes `PK-02` only. It does not close `PK-03` or claim full `v1.26` re-audit success.

## Closeout Goals

| Goal | Result | Evidence |
|------|--------|----------|
| Phase 115 has an authoritative PK-02 verification home | Pass | This file replaces `115-01-SUMMARY.md` as the proof authority and names the exact proof seams for `passkeys_test.exs`, `generator_passkey_management_test.exs`, `passkey_settings_live_test.exs`, `passkey_session_controller_test.exs`, and `passkey-options.spec.ts`. |
| Current-head focused proof exists for the library, generator, and example-host targeted delete seams | Pass with noted fallback | The library and generator suites were proven on current HEAD via a `mix run --no-start` fallback after the exact `mix test` command hung in this runtime; the example-host targeted ExUnit lane passed with `23 tests, 0 failures`. |
| Served-route browser proof is replayable from this artifact | Pass | The exact Playwright command passed once the example host could boot cleanly on `http://localhost:4000`. |

## Evidence

### Root library and generator proof

- Planned command:
  `MIX_ENV=test mix test test/sigra/passkeys_test.exs test/sigra/install/generator_passkey_management_test.exs --no-color`
  Result: did not produce a usable receipt in this runtime before the verification pass moved to a known Phase 117 fallback path.
- Fallback command used for current-head proof:
  `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/passkeys_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'`
  Result: `20 tests, 0 failures`.

This receipt proves the library-owned delete seam and generator parity on current HEAD:

- `test/sigra/passkeys_test.exs`
- `test/sigra/install/generator_passkey_management_test.exs`

### Example-host targeted proof

- Command:
  `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs`
  Result: `23 tests, 0 failures`.

This receipt proves the generated example host still exercises the scoped PK-02 surfaces on current HEAD:

- `test/example/test/example_web/live/passkey_settings_live_test.exs`
- `test/example/test/example_web/controllers/passkey_session_controller_test.exs`

### Served-route browser proof

- Command:
  `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-options.spec.ts --project=chromium`
  Result: `1 passed (9.9s)`.

The targeted Playwright seam exists at:

- `test/example/priv/playwright/tests/passkey-options.spec.ts`

## Proved / Did Not Prove

**Proved**

- `Sigra.Passkeys.delete_with_posture/4` still distinguishes ordinary deletes from last-passkey deletes on current HEAD.
- The generated-host management templates still render truthful last-passkey warning and post-delete posture copy rather than inventing Sigra-owned recovery.
- The example-host targeted controller and LiveView suites still prove delete warning copy, stale-sudo rejection, and final-passkey flash posture on current HEAD.

**Did Not Prove**

- Any claim that `PK-03` or the broader `v1.26` audit is closed.
- Any Sigra-owned sync, restore, escrow, or transparent migration behavior.

## Residuals

- The root `mix test` command remains unreliable in this runtime; the authoritative current-head receipt for the root proof came from the documented `mix run --no-start` fallback with `:telemetry` and `:mox` started explicitly.
- The browser lane requires a running example host at `http://localhost:4000`. This rerun passed after repairing the example app runtime endpoint config and booting the host locally.

## Status

Passed — `PK-02` now has authoritative Phase 115 verification with current-head receipts across the library, generator, example-host targeted, and served-route browser seams.
