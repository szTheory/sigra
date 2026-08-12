---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 01
subsystem: auth
tags: [installer, personal-access-token, jwt, generator, tdd]
requires:
  - phase: 243-credential-boundary-and-pipeline-foundation
    provides: "Explicit FetchAPIToken and FetchJWT credential-kind plugs"
provides:
  - "Independent --api and --jwt generator file, configuration, and pipeline selection"
  - "Generated host-policy JWT issuance and refresh delegate without a password exchange route"
  - "Four-combination PAT/JWT negative source contracts"
affects: [244-02, 244-03, 244-04, PAT-01, JWT-01, JWT-02]
tech-stack:
  added: []
  patterns:
    - "Credential-kind installer predicates remain independent through files, injections, configuration, and instructions"
    - "Generated JWT issuance is host policy and accepts no HTTP-selected authority"
key-files:
  created:
    - priv/templates/sigra.install/core/auth_jwt.ex
  modified:
    - lib/sigra/install/features/core.ex
    - test/sigra/install/features/core_test.exs
    - test/sigra/install/api_token_generator_test.exs
key-decisions:
  - "--api selects only PAT artifacts and FetchAPIToken; --jwt selects only JWT artifacts and FetchJWT."
  - "The generated JWT surface is an Auth.JWT host-policy delegate rather than a password/MFA exchange router."
requirements-completed: [PAT-01, JWT-01, JWT-02]
coverage:
  - id: D1
    description: "Independent PAT and advanced-JWT installer option matrix with explicit credential-kind pipelines"
    requirement: PAT-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/install/features/core_test.exs test/sigra/install/api_token_generator_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "JWT-only generated host-policy delegate has no password exchange or request-selected scopes"
    requirement: JWT-02
    verification:
      - kind: unit
        ref: "test/sigra/install/api_token_generator_test.exs#auth_jwt.ex template"
        status: pass
    human_judgment: false
metrics:
  duration: 2min
  completed: 2026-08-12
  tasks: 1
  files: 4
status: complete
---

# Phase 244 Plan 01: PAT and Advanced JWT Truth Repair Summary

**The installer now emits independent PAT and advanced-JWT contracts, using explicit credential-kind plugs and a host-policy JWT delegate instead of a password exchange route.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-08-12T21:54:17Z
- **Completed:** 2026-08-12T21:56:02Z
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Split API and JWT predicates across generated files, configuration, router injections, and post-install instructions.
- Replaced fresh-host compatibility-dispatch output with `FetchAPIToken` and `FetchJWT` pipelines.
- Added the JWT-only `Auth.JWT` delegate with host-owned scope policy and no password, MFA, or request-scope endpoint.
- Added four-combination positive/negative emission contracts and stable-injection marker checks.

## Task Commits

1. **Task 1: Trace independent feature selection through every generator branch** - `6c8e4e0e` (RED), `ab6fb7f3` (GREEN)

## Files Created/Modified

- `lib/sigra/install/features/core.ex` - independent PAT/JWT emission and explicit plug pipelines.
- `priv/templates/sigra.install/core/auth_jwt.ex` - host-policy issuance, refresh, and revoke delegates.
- `test/sigra/install/features/core_test.exs` - option-matrix and injection isolation contracts.
- `test/sigra/install/api_token_generator_test.exs` - JWT authority-surface and generated-template contracts.

## Decisions Made

- API and JWT config blocks have distinct stable markers, so either option can be re-applied without duplicating its own configuration.
- The existing Sigra facade names its issuance function `generate_jwt_tokens/3`; the generated delegate preserves that public API while exposing `create_jwt_tokens/1` to the host.

## TDD Gate Compliance

- RED commit `6c8e4e0e` recorded 11 expected failures from the coupled generator contract before production edits.
- GREEN commit `ab6fb7f3` made the focused suite pass with 97 tests and 0 failures.

## Verification

`MIX_ENV=test mix test test/sigra/install/features/core_test.exs test/sigra/install/api_token_generator_test.exs --trace` passed twice after the GREEN commit: 97 tests, 0 failures.

The test helper emitted its documented PostgreSQL connection-refused noise, but these generator contracts do not require database access and completed successfully.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test/API correction] Used the existing JWT facade name in the generated delegate**
- **Found during:** Task 1 GREEN implementation
- **Issue:** The plan interface called the facade `Sigra.Auth.create_jwt_tokens/3`, but the implemented public facade is `Sigra.Auth.generate_jwt_tokens/3`.
- **Fix:** Kept the host-facing `create_jwt_tokens/1` delegate and routed it to the actual facade function.
- **Files modified:** `priv/templates/sigra.install/core/auth_jwt.ex`, `test/sigra/install/api_token_generator_test.exs`
- **Verification:** Focused 97-test generator suite passed.
- **Committed in:** `ab6fb7f3`

**Total deviations:** 1 auto-fixed (Rule 1 test/API correction). No scope expansion.

## Known Stubs

None.

## Threat Flags

None. The change removes a public password/MFA JWT issuance surface and adds no new network endpoint or trust boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The independent installer spine is ready for the PAT management and advanced JWT validation work in later Phase 244 plans.

## Self-Check: PASSED

Verified all four planned source/test files exist and both RED/GREEN commits are present in git history.
