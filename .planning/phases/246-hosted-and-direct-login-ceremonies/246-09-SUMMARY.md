---
phase: 246-hosted-and-direct-login-ceremonies
plan: 09
subsystem: authentication
tags: [elixir, phoenix, liveview, mfa, app-sessions]
requires:
  - phase: 246-08
    provides: signed hosted app-login continuation and explicit approval route
provides:
  - Browser login and MFA resume only through the explicit app-login approval route
  - Invalid or expired continuation handles fall back to ordinary authentication
  - Selected-host session renewal preserves only the bounded signed handle
affects: [generated-host-installation, first-party-native-clients]
tech-stack:
  added: []
  patterns: [feature-gated continuation routing, signed handle verification, MFA-safe session renewal]
key-files:
  created:
    - test/sigra/install/app_sessions_auth_continuation_test.exs
  modified:
    - priv/templates/sigra.install/app_sessions/app_login_continuation.ex
    - priv/templates/sigra.install/core/session_controller.ex
    - priv/templates/sigra.install/core/mfa_challenge_controller.ex
    - priv/templates/sigra.install/core/mfa_challenge_live.ex
    - priv/templates/sigra.install/core/user_auth.ex
decisions:
  - "A valid hosted continuation can resume only at /app-login/continue after normal browser authentication completes."
  - "MFA-pending browser sessions retain their continuation until MFA succeeds; invalid handles are cleared and use the ordinary return path."
metrics:
  duration: 6m
  completed: 2026-08-13
  tasks: 1
  files: 6
status: complete
---

# Phase 246 Plan 09: Browser Auth Continuation Summary

**Generated browser login and MFA now preserve one signed hosted continuation and resume only at explicit approval.**

## Accomplishments

- Added a focused rendered continuation contract for selected controller/LiveView/MFA branches and continuation-free unselected templates.
- Routed valid post-login and post-MFA continuations only to `/app-login/continue`, leaving approval and credential issuance controller-owned.
- Preserved signed handles across normal and passkey MFA session renewal; MFA-pending sessions cannot skip verification.
- Cleared expired or tampered handles and retained ordinary browser-auth return behavior.

## Task Commits

1. **Task 1: Resume one hosted continuation through controller and LiveView MFA** — `852649ea` (RED), `a4d6e41c` (GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/install/app_sessions_auth_continuation_test.exs test/sigra/install/generator_mfa_test.exs test/sigra/install/generator_passkey_mfa_challenge_test.exs --trace` — PASS (59 tests, 0 failures).
- Rendered selected core templates plus the app-login continuation helper parsed with `Code.string_to_quoted!/1` — PASS.
- `mix format --check-formatted test/sigra/install/app_sessions_auth_continuation_test.exs` — PASS.
- `git diff --check` — PASS.

## Decisions Made

- Valid browser continuations always return to the existing approval controller, never directly to a callback or issuance path.
- The continuation remains preserved while MFA is pending and is consumed only by the approval controller after ordinary authentication finishes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Preserve continuation across passkey MFA renewal**
- **Found during:** Task 1
- **Issue:** `UserAuth.put_user_session_token/2` renews the Plug session during passkey MFA completion and would discard the signed continuation.
- **Fix:** Preserved and restored the bounded handle around that renewal, matching normal browser-login renewal.
- **Files modified:** `priv/templates/sigra.install/core/user_auth.ex`, `priv/templates/sigra.install/core/session_controller.ex`
- **Verification:** Focused continuation/MFA generator suite and rendered-template parse passed.
- **Commit:** `a4d6e41c`

**2. [Rule 2 - Missing critical functionality] Keep MFA pending before approval routing**
- **Found during:** Task 1
- **Issue:** A post-login continuation redirect could have reached approval before an MFA-pending session completed verification.
- **Fix:** Leave valid handles untouched while the generated Sigra session is MFA-pending; only successful MFA routes to the fixed approval controller.
- **Files modified:** `priv/templates/sigra.install/core/session_controller.ex`
- **Verification:** Focused continuation source contract and rendered-template parse passed.
- **Commit:** `a4d6e41c`

**Total deviations:** 2 auto-fixed (Rule 2). **Impact:** Required to preserve MFA as a hard authentication boundary without adding route or credential authority.

## Known Stubs

None.

## Issues Encountered

The focused installer tests passed while local application startup logged unavailable PostgreSQL connections. These source-rendering tests are database-independent; no test result failed.

## Next Phase Readiness

Generated browser authentication now hands a valid hosted continuation to the explicit approval route after both controller and LiveView MFA paths.

## Self-Check: PASSED

- Confirmed the focused continuation test and five modified templates exist.
- Confirmed task commits `852649ea` and `a4d6e41c` exist in git history.
