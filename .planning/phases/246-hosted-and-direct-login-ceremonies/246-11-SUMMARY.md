---
phase: 246-hosted-and-direct-login-ceremonies
plan: 11
subsystem: hosted app login
tags: [app-sessions, hosted-login, generated-host, mfa]
requires: [246-10]
provides: [typed hosted attempt persistence, completed-browser approval gate, generated hosted tracer]
affects: [APP-02]
tech-stack:
  added: []
  patterns: [Ecto.Enum discriminator, cookie-jar browser tracer, fail-closed assurance classifier]
key-files:
  modified:
    - lib/sigra/app_login.ex
    - priv/templates/sigra.install/app_sessions/app_login_controller.ex
    - scripts/ci/generated-app-login-runtime-proof.sh
decisions:
  - Hosted attempts always persist kind: :hosted_code.
  - Approval accepts only completed standard or remember-me Sigra sessions.
metrics:
  tasks: 2
status: complete
---

# Phase 246 Plan 11: Hosted Ceremony Gap Closure Summary

Hosted approval now satisfies the generated schema and requires completed browser assurance before issuing an app-login code.

## Accomplishments

- Persisted the required `:hosted_code` discriminator and added regression coverage.
- Extended the fresh generated-host harness with cookie-jar login, CSRF approval, callback capture, typed-row assertion, and JSON exchange checks.
- Redirected MFA-pending sessions to ordinary MFA while failing closed for malformed private session state.

## Task Commits

1. Task 1 RED — `38cb9ae8`; GREEN — `7959d762`
2. Task 2 — `b34adb0e`

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace` — PASS (8 tests).
- `MIX_ENV=test mix test test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_auth_continuation_test.exs --trace` — PASS (6 tests).
- Formatter checks, `bash -n scripts/ci/generated-app-login-runtime-proof.sh`, and `git diff --check` — PASS.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all modified implementation files and commits `38cb9ae8`, `7959d762`, and `b34adb0e` exist.
