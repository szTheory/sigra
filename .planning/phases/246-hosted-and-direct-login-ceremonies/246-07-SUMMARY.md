---
phase: 246-hosted-and-direct-login-ceremonies
plan: 07
subsystem: installer
tags: [elixir, ecto, generator, app-sessions, hosted-login, direct-login]
requires:
  - phase: 245-opaque-app-session-core
    provides: Digest-only app-session family and token lifecycle
  - phase: 246-01
    provides: Locked hosted-code exchange facade
  - phase: 246-02
    provides: Static profile and PKCE contract
  - phase: 246-06
    provides: Independent app-session feature and migration allocation
provides:
  - Generated host schemas and migration for opaque app-session families, tokens, and ceremony attempts
  - Static first-party profiles with literal callbacks and policy records
  - Thin generated facade into Sigra.AppLogin and Sigra.AppSession
affects: [246-08, generated-host-installation]
tech-stack:
  added: []
  patterns: [digest-only ceremony storage, host-owned static profiles, feature-gated delegates]
key-files:
  created:
    - priv/templates/sigra.install/app_sessions/user_app_session_family.ex
    - priv/templates/sigra.install/app_sessions/user_app_session_token.ex
    - priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex
    - priv/templates/sigra.install/app_sessions/app_sessions_migration.exs
    - priv/templates/sigra.install/app_sessions/first_party_apps.ex
    - priv/templates/sigra.install/app_sessions/auth_app_sessions.ex
  modified:
    - lib/sigra/install/features/app_sessions.ex
    - test/sigra/install/app_sessions_generator_test.exs
key-decisions:
  - "Generated app-session state uses one host-owned migration with binary IDs, auth-prefix support, cascading FKs, unique digests, and lifecycle indexes."
  - "First-party profiles remain finite module data with literal callback strings; direct adapters are emitted only when app-password-login is selected."
metrics:
  duration: 5min
  completed: 2026-08-13
  tasks: 3
  files: 8
status: complete
---

# Phase 246 Plan 07: Generated Host Ceremony Contract Summary

**The app-session installer now renders digest-only host persistence, finite first-party profiles, and thin ceremony delegates without coupling API or JWT output.**

## Accomplishments

- Rendered host-owned Phase 245 family and typed token schemas plus a prefix-aware migration with required uniqueness, foreign keys, and lifecycle indexes.
- Added one digest-only attempt schema for hosted authorization codes and direct-MFA challenges; no raw ceremony credentials are persisted.
- Registered static profiles and a host facade that configures paired schemas and delegates hosted, refresh, and revocation flows to the public Sigra facades.
- Kept direct password and MFA callback adapters behind the independent `--app-password-login` selection.

## Task Commits

1. **Task 1: Render one migratable host persistence contract** — `469f2d50` (RED), `caba7c1c` (GREEN)
2. **Task 2: Render digest-only hosted-code and direct-MFA attempt storage** — `fe82e282` (RED), `56435c0f` (GREEN)
3. **Task 3: Render static profiles and thin ceremony delegates** — `09cf9438` (RED), `b7ceb820` (GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/features/core_test.exs --trace` — passed (41 tests).
- Rendered every app-session template with binary IDs/auth prefix and without an auth prefix; both rendered source sets parsed successfully.
- `mix format --check-formatted` passed for modified Elixir source and tests.

The focused suites log unavailable local PostgreSQL connections during application startup, but the selected generator tests are database-independent and passed.

## Decisions Made

- Ceremony rows store only digest and bounded trusted bindings; password, state, verifier, client secret, and raw challenge/code fields are absent.
- Profile selection remains static and server-owned; generated clients receive no runtime registration surface or compiled secret.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test contract] Corrected the typed token test to match the existing `Ecto.Enum` lifecycle representation.**
- **Found during:** Task 1
- **Issue:** The initial rendered-source assertion expected `kind` as a string despite the Phase 245 writer assigning `:access` and `:refresh` atoms.
- **Fix:** Assert the generated `Ecto.Enum` representation while retaining the string migration storage contract.
- **Files modified:** `test/sigra/install/app_sessions_generator_test.exs`
- **Verification:** Focused generator suite passed.
- **Commit:** `caba7c1c`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** The generated schema now matches the existing Phase 245 lifecycle writer.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all six generated template artifacts and the feature/test sources exist.
- Confirmed all six RED/GREEN task commits are present in git history.
