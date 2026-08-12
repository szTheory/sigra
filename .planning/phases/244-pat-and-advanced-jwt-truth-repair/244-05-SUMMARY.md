---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 05
subsystem: auth
tags: [jwt, joken, phoenix, postgres, generator, runtime-proof, tdd]
requires:
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: "Strict signer-first JWT verification with configured claims and FetchJWT"
provides:
  - "Independent fresh JWT-only host runtime proof with host-policy scoped issuance"
  - "Generated strict JWT policy, Joken dependency, and lazy router configuration"
  - "Cross-feature absence regression for separate API-only and JWT-only hosts"
affects: [244-06, JWT-01, JWT-02]
tech-stack:
  added: [Joken in JWT-only generated hosts]
  patterns:
    - "Generated JWT router options use a remote config function so endpoint-dependent config is resolved at request time."
    - "Generated JWT issuance supplies the host UserToken schema directly to Sigra.JWT.generate_tokens/4."
key-files:
  created: []
  modified:
    - lib/sigra/install/features/core.ex
    - lib/sigra/plug/fetch_jwt.ex
    - priv/templates/sigra.install/core/auth_jwt.ex
    - test/sigra/install/api_token_generator_test.exs
    - test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs
key-decisions:
  - "JWT-only generation installs Joken and explicit enabled/algorithm/type/issuer/audience configuration."
  - "The generated Auth.JWT delegate is host-only and calls Sigra.JWT.generate_tokens/4 with the generated UserToken schema."
requirements-completed: [JWT-01, JWT-02]
coverage:
  - id: D1
    description: "Fresh JWT-only hosts install twice, migrate, compile, issue a host-scoped token, and enforce strict verification."
    requirement: JWT-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "API-only and JWT-only generated hosts remain isolated from each other's files, routes, configuration, and authority surfaces."
    requirement: JWT-02
    verification:
      - kind: integration
        ref: "test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs#fresh API-only host; fresh JWT-only host"
        status: pass
    human_judgment: false
metrics:
  duration: 16min
  completed: 2026-08-12
  tasks: 1
  files: 5
status: complete
---

# Phase 244 Plan 05: JWT-Only Fresh Host Proof Summary

**Fresh JWT-only Phoenix hosts now install, migrate, compile, issue host-policy-scoped JWTs, and reject invalid configured claims without PAT coupling.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-08-12T23:17:00Z
- **Completed:** 2026-08-12T23:33:19Z
- **Tasks:** 1/1
- **Files modified:** 5

## Accomplishments

- Generated JWT-only hosts receive Joken plus explicit enabled, algorithm, protected type, issuer, and audience policy.
- The generated `Auth.JWT` delegate accepts only a host-authenticated user, applies host-owned `read` scope policy, and supplies the generated `UserToken` schema for refresh persistence.
- Added a disposable PostgreSQL JWT-only host lane that reruns installation, migration, compilation, token issuance, FetchJWT projection, wrong type/issuer/audience/future-nbf rejection, and scalar/array audience acceptance.
- Re-ran the existing API-only host lane in the same command and asserted reciprocal file, route, configuration, and authority isolation.

## Task Commits

1. **Task 1: Issue and verify one server-scoped JWT in a fresh JWT-only host** — `dfdc16a5` (RED), `9a811164` (GREEN)

## Files Created/Modified

- `lib/sigra/install/features/core.ex` — emits JWT-only dependency, strict config, and lazy FetchJWT pipeline options.
- `lib/sigra/plug/fetch_jwt.ex` — resolves generated remote config functions when serving a request.
- `priv/templates/sigra.install/core/auth_jwt.ex` — issues tokens through `Sigra.JWT.generate_tokens/4` with host-owned scopes and generated token storage.
- `test/sigra/install/api_token_generator_test.exs` — pins strict generated policy, dependency, and no-request-authority behavior.
- `test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs` — proves separate clean API/JWT generated runtime lanes.

## Decisions Made

- Resolve endpoint-dependent generated JWT config through a remote function at request time, avoiding Phoenix router compile-time endpoint access.
- Keep issuance authority in the host delegate while using the lower-level JWT API required to provide refresh-token storage explicitly.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs --trace` — passed twice; latest run: 73 tests, 0 failures (79.3s).
- The JWT-only tracer lane also passed independently: 1 test, 0 failures (43.4s).

## TDD Gate Compliance

- RED commit `dfdc16a5` recorded failing generated-policy and fresh-host proof expectations.
- GREEN commit `9a811164` made the combined source and generated-host suite pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Runtime blocker] Deferred generated FetchJWT configuration resolution**
- **Found during:** Task 1 GREEN
- **Issue:** Phoenix evaluates router plug options at compile time, before the endpoint configuration table exists.
- **Fix:** Generated a remote `Auth.JWT.sigra_config/0` reference and taught `FetchJWT` to resolve it at request time.
- **Files modified:** `lib/sigra/install/features/core.ex`, `lib/sigra/plug/fetch_jwt.ex`
- **Verification:** JWT-only host migrated, compiled, and authenticated through `FetchJWT`.
- **Committed in:** `9a811164`

**2. [Rule 2 - Missing critical functionality] Added JWT-only generated dependency and refresh storage wiring**
- **Found during:** Task 1 GREEN
- **Issue:** A clean JWT-only host lacked Joken and the required generated `UserToken` schema option for refresh-token creation.
- **Fix:** Injected Joken for `--jwt` hosts and routed the host delegate to `Sigra.JWT.generate_tokens/4` with `UserToken` storage.
- **Files modified:** `lib/sigra/install/features/core.ex`, `priv/templates/sigra.install/core/auth_jwt.ex`
- **Verification:** A fresh host installs twice, resolves dependencies, and issues an access/refresh JWT response.
- **Committed in:** `9a811164`

**Total deviations:** 2 auto-fixed (Rule 3 runtime blocker; Rule 2 missing critical functionality). All were necessary for the plan's fresh-host contract; no authority surface was expanded.

## Known Stubs

None.

## Threat Flags

None. The generated surface remains host-policy-only, and strict verifier policy is exercised through the real `FetchJWT` path.

## User Setup Required

None - automated proof sourced `tmp/db.env` and verified PostgreSQL plus `phx_new` before execution.

## Next Phase Readiness

Plan 06 can build on a generated JWT host that now has real refresh-token storage and independently proven issuance/verification boundaries.

## Self-Check: PASSED

Verified all five task files and the summary exist, and both RED/GREEN task commits are present in git history.
