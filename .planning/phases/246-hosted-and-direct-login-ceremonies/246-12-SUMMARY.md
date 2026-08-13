---
phase: 246-hosted-and-direct-login-ceremonies
plan: 12
subsystem: authentication
tags: [elixir, phoenix, generated-host, direct-login, mfa, backup-codes, app-sessions]
requires:
  - phase: 246-11
    provides: generated hosted ceremony proof and completed-browser assurance
provides:
  - Fixed generated direct-MFA factor transport for TOTP and backup codes
  - Fresh-host direct backup-code ceremony evidence with consumed-state assertions
affects: [APP-03, first-party native clients, generated app-session hosts]
tech-stack:
  added: []
  patterns: [literal external-to-trusted factor allowlist, generated-host MFA proof]
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/app_sessions/app_login_controller.ex
    - priv/templates/sigra.install/app_sessions/auth_app_sessions.ex
    - scripts/ci/generated-app-login-runtime-proof.sh
    - test/sigra/install/app_sessions_routes_test.exs
    - test/sigra/install/app_sessions_generator_test.exs
    - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
    - .planning/phases/246-hosted-and-direct-login-ceremonies/COVERAGE.md
decisions:
  - External MFA factor strings decode only through a literal two-value allowlist before reaching library callbacks.
  - Generated direct login derives MFA-required state from the host MFA status while preserving the regular browser authenticator contract.
requirements-completed: [APP-03]
coverage:
  - id: D1
    description: Generated direct-MFA HTTP transport accepts only trusted TOTP and backup-code factor selectors with uniform rejection.
    requirement: APP-03
    verification:
      - kind: unit
        ref: test/sigra/install/app_sessions_routes_test.exs#renders a fixed direct-MFA factor allowlist and uniform invalid-factor path
        status: pass
      - kind: unit
        ref: test/sigra/install/app_sessions_generator_test.exs#emits direct password and MFA adapters only behind the password-login flag
        status: pass
    human_judgment: false
  - id: D2
    description: Fresh generated host completes direct MFA with a real backup code and proves challenge/code consumption.
    requirement: APP-03
    verification:
      - kind: e2e
        ref: bash scripts/ci/generated-app-login-runtime-proof.sh --direct
        status: pass
      - kind: integration
        ref: test/sigra/planning/phase_246_generated_app_login_runtime_test.exs#fresh-host proof is bounded, route-based, and receipt-last
        status: pass
    human_judgment: false
metrics:
  duration: 20m
  tasks_completed: 2
  files_changed: 7
status: complete
---

# Phase 246 Plan 12: Generated Direct MFA Factor Closure Summary

**Generated direct MFA now admits only trusted TOTP or backup-code selectors and proves backup-code app-session issuance in a disposable Phoenix host.**

## Accomplishments

- Required exactly `challenge`, `code`, and `factor` in the generated direct-MFA endpoint; a literal decoder maps only `totp` and `backup_code` to trusted atoms.
- Forwarded the trusted factor to the existing fixed host verifier callbacks while preserving identical `invalid_credentials` failures for malformed or unknown selectors.
- Extended the generated-host direct harness to provision an MFA user and backup code, complete the real route, and assert credential shape plus one-use persisted challenge and backup-code state.
- Recorded the generated endpoint contract and first-party external-integration opt-out in coverage evidence.

## Task Commits

1. **Task 1: Transport one allowlisted direct-MFA factor without dynamic atoms** — RED `8f67e80d`; GREEN `ef69695f`.
2. **Task 2: Complete generated direct MFA with a real backup code** — RED `b5b00702`; GREEN `080b50bf`.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_generator_test.exs test/sigra/app_login_direct_test.exs test/sigra/app_login_direct_fault_test.exs test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace` — PASS (26 tests).
- `bash scripts/ci/generated-app-login-runtime-proof.sh --direct` — PASS.
- `bash -n scripts/ci/generated-app-login-runtime-proof.sh`, dynamic-atom scan, and `git diff --check` — PASS.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Preserve MFA-required state in the generated direct-login adapter**
- **Found during:** Task 2
- **Issue:** The regular generated authenticator intentionally normalizes its session metadata for browser login, so direct login could not create the required MFA challenge for an enrolled user.
- **Fix:** Added a narrow facade-local authenticator that consults generated `mfa_status/1` and returns the existing direct-ceremony MFA signal without altering browser authentication behavior.
- **Files modified:** `priv/templates/sigra.install/app_sessions/auth_app_sessions.ex`, `test/sigra/install/app_sessions_generator_test.exs`
- **Verification:** Fresh generated-host backup-code MFA proof passes.
- **Committed in:** `080b50bf`

**Total deviations:** 1 auto-fixed Rule 2 correction. **Impact:** Necessary to make the planned generated MFA route reachable; no API or authority expansion.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all seven plan files exist and task commits `8f67e80d`, `ef69695f`, `b5b00702`, and `080b50bf` exist in git history.
