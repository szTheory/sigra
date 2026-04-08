---
phase: 06-multi-factor-authentication
plan: 05
subsystem: mfa-ui-and-generator
tags: [mfa, templates, generator, liveview, controller, ui]
dependency_graph:
  requires: ["06-03", "06-04"]
  provides: ["mfa-challenge-page", "mfa-settings-page", "mfa-generator-wiring"]
  affects: ["priv/templates/sigra.install/", "lib/mix/tasks/sigra.install.ex"]
tech_stack:
  added: []
  patterns: ["tab-based-ui", "auto-submit-js", "trust-cookie", "generator-route-injection"]
key_files:
  created:
    - priv/templates/sigra.install/mfa_challenge_controller.ex
    - priv/templates/sigra.install/mfa_challenge_html.ex
    - priv/templates/sigra.install/mfa_challenge_live.ex
    - priv/templates/sigra.install/mfa_settings_live.ex
    - priv/templates/sigra.install/mfa_settings_html.ex
    - test/sigra/install/generator_mfa_test.exs
  modified:
    - priv/templates/sigra.install/user_auth.ex
    - lib/mix/tasks/sigra.install.ex
decisions:
  - "MFA challenge page uses CSS-based tab switching in controller mode and phx-click in LiveView mode"
  - "require_mfa plug checks session for mfa_pending flag rather than delegating to Sigra.Plug.RequireMFA"
  - "Trust cookie setting defers to Sigra.MFA.Trust module functions for sign/verify/cookie_name"
metrics:
  duration: "6m 18s"
  completed: "2026-04-08"
  tasks_completed: 2
  tasks_total: 3
  tests_added: 53
  tests_total: 807
---

# Phase 6 Plan 5: MFA UI Templates & Generator Wiring Summary

MFA challenge page with TOTP/backup code tabs and auto-submit JS, enrollment/settings LiveView with QR code and backup code management, generator updated to produce all MFA files and inject routes with require_mfa plug.

## What Was Built

### Task 1: MFA Challenge Page Templates
- **Controller** (`mfa_challenge_controller.ex`): Handles `new` (render challenge) and `create` (verify code) actions. Supports both TOTP and backup code methods. Sets trust cookie on success. Masks email for display. Error messages match D-38, D-90, D-91 spec.
- **HTML** (`mfa_challenge_html.ex`): Tab-based UI with "Authenticator code" and "Backup code" tabs. TOTP input uses `inputmode="numeric"`, `autocomplete="one-time-code"`, monospace centered text. Auto-submit JS fires `requestSubmit()` on 6 digits. Trust checkbox. Cancel link. Accessible with `role="tablist/tab/tabpanel"`.
- **LiveView** (`mfa_challenge_live.ex`): Same UI with `phx-change` for auto-submit, `phx-click` for tab switching, `phx-submit` for verification. Auto-verify via `send(self(), {:auto_verify_totp, code})` pattern matching confirmation_live.ex.

### Task 2: MFA Settings/Enrollment + Generator Wiring
- **Settings LiveView** (`mfa_settings_live.ex`): Full enrollment flow (QR code + manual key + confirmation), backup code display with grid-cols-2, copy/download hooks, acknowledgment checkbox. Settings card with Enabled badge, backup count with warning banners, disable confirmation with bg-red-50, regenerate codes, revoke trusted browsers.
- **Settings HTML** (`mfa_settings_html.ex`): Controller-mode equivalent with form POST flow.
- **user_auth.ex**: Added `require_mfa/2` plug that checks `mfa_pending` session flag and redirects to `/users/mfa`.
- **Generator** (`sigra.install.ex`): Copies 7 MFA templates (schemas + UI). Injects `/users/mfa` route. Adds `plug :require_mfa` to authenticated pipeline. LiveView mode gets `MFAChallengeLive` + `MFASettingsLive`; controller mode gets `MFAChallengeController` + `MFASettingsHTML`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] require_mfa implementation approach**
- **Found during:** Task 2
- **Issue:** Plan suggested delegating to `Sigra.Plug.RequireMFA.call/2`, but the plug module pattern in the existing codebase (user_auth.ex) uses inline logic rather than wrapping library plugs. The `mfa_pending` flag is a session-level concern better handled at the session layer.
- **Fix:** Implemented `require_mfa` as a session check (`get_session(conn, :mfa_pending) == true`) consistent with how `require_authenticated_user` is implemented in the same module.
- **Files modified:** `priv/templates/sigra.install/user_auth.ex`

## Verification

- 53 new tests in `generator_mfa_test.exs` -- all pass
- 807 total tests -- 0 failures
- All template files render with base binding (EEx.eval_file)
- Generator source contains correct route patterns and file lists

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `8efd59d` | MFA challenge page templates (controller + HTML + LiveView) |
| 2 | `89cc608` | MFA settings templates, require_mfa plug, and generator wiring |

## Pending

Task 3 is a human-verify checkpoint awaiting manual review of the complete MFA flow.

## Self-Check: PASSED

All created files verified to exist. All commits verified in git log.
