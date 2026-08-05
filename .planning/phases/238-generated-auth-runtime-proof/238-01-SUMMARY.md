---
phase: 238-generated-auth-runtime-proof
plan: "01"
subsystem: auth
tags: [oauth, oidc, assent, playwright, pkce, generated-host]
requires:
  - phase: 237-canonical-b2c-generator-contract
    provides: canonical B2C installer and Google generator lifecycle
provides:
  - fresh generated-host OAuth runtime harness with a loopback OIDC double
  - focused browser probe for generated Google start/callback collision behavior
affects: [238-02, generated-auth-runtime-proof, CI]
tech-stack:
  added: []
  patterns: [fresh-host loopback OIDC proof, browser-visible generated OAuth route coverage]
key-files:
  created:
    - scripts/ci/generated-auth-runtime-proof.sh
    - test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts
  modified: []
key-decisions:
  - "The provider double is discovery/authorization/token only, with HS256 ID-token claims and no nonce, userinfo, or JWKS dependency."
  - "The probe starts at generated /auth/google and observes the loopback authorization redirect rather than shortcutting the callback."
patterns-established:
  - "Use the Phase 237 canonical B2C scaffold/install/generate lifecycle for generated-host acceptance proof."
requirements-completed: [AUTH-02]
coverage:
  - id: D1
    description: Generated Google OAuth request/callback path reaches the loopback OIDC double and presents the existing-account collision UI.
    requirement: AUTH-02
    verification:
      - kind: automated_ui
        ref: scripts/ci/generated-auth-runtime-proof.sh --probe-oauth
        status: unknown
      - kind: other
        ref: playwright --list generated-auth-oauth-probe.spec.ts
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-05
status: complete
---

# Phase 238 Plan 01: Generated Auth Runtime Proof Summary

**Fresh canonical B2C OAuth proof harness with a loopback Assent Google/OIDC double, PKCE relay, HS256 ID token, and browser-visible account-link collision test.**

## Performance

- **Duration:** 14 min
- **Completed:** 2026-08-05T14:56:03Z
- **Tasks:** 1/1
- **Files modified:** 2

## Accomplishments

- Added a disposable fresh-host lifecycle that retains Phase 237's B2C install, OAuth generation, migration, boot, and bounded cleanup flow.
- Added a local-only discovery/authorization/token double with dummy credentials, signed state relay, PKCE verification, and a dummy-secret HS256 ID token.
- Added a serial Playwright probe that starts at `/auth/google`, confirms the loopback authorization request, and verifies the generated existing-email collision message.

## Task Commits

1. **Task 1: Prove the local Assent Google OIDC seam through generated routes** - `97d77310` (test RED), `517f5e5d` (feat GREEN)

## Files Created

- `scripts/ci/generated-auth-runtime-proof.sh` - Fresh generated-host harness and local OIDC double installation.
- `test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts` - Deterministic generated-route browser proof.

## Decisions Made

- The double exposes only loopback discovery, authorization, and token endpoints; it intentionally omits nonce, userinfo, JWKS, and real credentials.
- The token endpoint verifies the generated PKCE verifier against the authorization challenge before issuing the HS256 ID token.

## Verification

- Passed: `bash -n scripts/ci/generated-auth-runtime-proof.sh`
- Passed: `shellcheck -x scripts/ci/generated-auth-runtime-proof.sh`
- Passed: `git diff --check HEAD`
- Passed: Playwright test discovery lists the focused Chromium probe.
- Not run locally: `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --probe-oauth`. This workstation lacks reachable PostgreSQL and a Playwright Chromium binary; CI must execute the exact command before AUTH-02 can be considered runtime-proven.

## TDD Gate Compliance

- RED: `97d77310` adds the focused browser assertion before the harness implementation.
- GREEN: `517f5e5d` adds the generated-host lifecycle and loopback provider double.
- The runtime RED/GREEN execution is CI-only because local PostgreSQL and Chromium are unavailable.

## Deviations from Plan

None - plan scope and locked provider contract were implemented as specified.

## Known Stubs

None.

## Next Phase Readiness

The reusable `--probe-oauth` harness is ready for CI runtime evidence and for later Phase 238 plans to extend through explicit allowlisted test selection.

## Self-Check: PASSED

- Found both created source artifacts.
- Found RED commit `97d77310` and GREEN commit `517f5e5d`.
