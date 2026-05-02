---
phase: 93-m2m-service-account-tokens-b2b-03
plan: 03
subsystem: oauth
tags: [oauth, client-credentials, generator, b2b-03]
requires:
  - phase: 93-01
    provides: "Service-account context and JWT issuance delegate"
provides:
  - "`Sigra.OAuth.Token.client_credentials/2` library helper"
  - "Generated `OAuthTokenController` template and `/oauth/token` route gating under `--jwt --organizations`"
  - "Focused RFC-shaped library tests for the client-credentials helper"
affects: [phase-93, oauth-token, installer, templates]
key-files:
  created:
    - "lib/sigra/oauth/token.ex"
    - "priv/templates/sigra.install/core/oauth_token_controller.ex"
    - "test/sigra/oauth/token_test.exs"
  modified:
    - "lib/sigra/install/features/core.ex"
    - "lib/sigra/install/features/organizations.ex"
requirements-completed: [B2B-03]
completed: 2026-05-01
---

# Phase 93 Plan 03 Summary

**Sigra now exposes a working `client_credentials` token path and emits the generated OAuth token controller only when both JWT and organizations are enabled.**

## Accomplishments

- Added `lib/sigra/oauth/token.ex` with client credential verification, constant-time invalid-client handling, scope-subset validation, and delegation to `Sigra.ServiceAccounts.issue_token/4`.
- Added `priv/templates/sigra.install/core/oauth_token_controller.ex` implementing the generated `/oauth/token` endpoint.
- Gated `/oauth/token` generation in the installer so it only emits when `--jwt --organizations` are both enabled.
- Added `test/sigra/oauth/token_test.exs` covering the library helper's happy path and key invalid-client / invalid-scope cases.

## Deviations From Plan

- The full RFC wire-shape suite described in the plan was not added. The controller surface exists, but the verification here is library-level rather than full controller-envelope coverage.
- `test/sigra/install/golden_diff_test.exs` was not extended with the planned gating assertions.
- No explicit rate-limit integration was added for `/oauth/token`; the generated controller moduledoc and current implementation should still be treated as lacking the Phase 93 planned hardening on that edge.

## Verification

- `mix test test/sigra/oauth/token_test.exs`
- `cd test/example && mix compile --warnings-as-errors`

## Next Dependency

The generated host can now expose `/oauth/token`; Plan 93-04 and 93-05 provide the generated host management surface and adopter-facing documentation around it.
