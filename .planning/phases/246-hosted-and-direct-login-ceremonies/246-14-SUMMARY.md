---
phase: 246-hosted-and-direct-login-ceremonies
plan: 14
subsystem: authentication
tags: [elixir, phoenix, liveview, mfa, app-sessions]
requires: [246-13]
provides:
  - Controller MFA completion rotates trusted persisted pending sessions before hosted approval.
  - Selected LiveView MFA forms use the controller-owned Plug-session renewal seam.
affects: [APP-02, hosted-login, generated-host-installation]
tech-stack:
  added: []
  patterns: [persisted MFA session rotation, controller-owned LiveView form completion, signed continuation renewal]
key-files:
  created:
    - test/sigra/install/app_sessions_mfa_session_upgrade_test.exs
  modified:
    - priv/templates/sigra.install/core/mfa_challenge_controller.ex
    - priv/templates/sigra.install/core/mfa_challenge_live.ex
decisions:
  - "Selected LiveView MFA factor forms POST through the existing CSRF-protected controller seam so persisted session rotation remains server-authoritative."
metrics:
  duration: 14m
  completed: 2026-08-13
  tasks: 2
  files: 3
status: complete
coverage:
  - id: D1
    description: "Controller TOTP and backup MFA rotate the trusted pending session before hosted continuation."
    requirement: APP-02
    verification:
      - kind: unit
        ref: "test/sigra/install/app_sessions_mfa_session_upgrade_test.exs#controller MFA success upgrades the persisted pending session before hosted continuation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Selected LiveView factor submissions cross the controller-owned CSRF-protected rotation seam."
    requirement: APP-02
    verification:
      - kind: unit
        ref: "test/sigra/install/app_sessions_mfa_session_upgrade_test.exs#LiveView TOTP and backup completion cross the controller-owned session seam"
        status: pass
    human_judgment: false
---

# Phase 246 Plan 14: MFA Session Rotation Summary

**Generated controller and selected LiveView MFA completions now rotate the authoritative pending browser session before hosted approval resumes.**

## Performance

- **Duration:** 14m
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Added controller coverage for trusted pending-session rotation, continuation preservation, and failed-upgrade denial.
- Routed selected LiveView TOTP and backup forms through the existing CSRF-protected controller/session renewal seam.
- Rejected forged LiveView factor events that could otherwise consume a factor without rotating the persisted browser session.

## Task Commits

1. **Task 1: Rotate one controller MFA session through hosted continuation** — `954504a0` (RED), `b1b95066` (GREEN)
2. **Task 2: Apply the same rotation contract to LiveView TOTP and backup completion** — `d3fc323a` (feat)

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs --only controller --trace` — PASS (2 tests).
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs test/sigra/install/app_sessions_auth_continuation_test.exs --trace` — PASS (7 tests).
- Selected and unselected rendered controller/LiveView templates parsed with `Code.string_to_quoted!/1` — PASS.
- `mix format --check-formatted` for modified tests and `git diff --check` — PASS. Raw EEx templates cannot be passed directly to `mix format` because their EEx directives are not Elixir syntax.

## Decisions Made

- Selected LiveView MFA factor forms POST through the existing CSRF-protected controller seam so persisted session rotation remains server-authoritative.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Reject LiveView factor events outside the controller seam**
- **Found during:** Task 2
- **Issue:** A forged selected-host LiveView event could consume a factor without renewing the persisted Plug session.
- **Fix:** Selected LiveView templates use ordinary CSRF-protected posts to the controller; their corresponding LiveView events fail closed.
- **Files modified:** `priv/templates/sigra.install/core/mfa_challenge_live.ex`
- **Verification:** Focused rendered-template tests passed.
- **Committed in:** `d3fc323a`

**Total deviations:** 1 auto-fixed (Rule 2). **Impact:** Required to retain the persisted-session assurance boundary without adding a second credential path.

## Known Stubs

None.

## Issues Encountered

The configured local PostgreSQL endpoint at `127.0.0.1:53988` refused connections during Mix startup. The committed focused tests are deterministic rendered-template contracts; PostgreSQL-backed generated-host transition evidence remains unrun in this workspace.

## Next Phase Readiness

Hosted MFA factor success reaches explicit approval only after the established pending-session upgrade. The phase still needs its separately planned atomic hosted-continuation-consumption repair and PostgreSQL runtime proof.

## Self-Check: PASSED

- Confirmed the two MFA templates and session-upgrade regression test exist.
- Confirmed commits `954504a0`, `b1b95066`, and `d3fc323a` exist in git history.
