---
phase: 243-credential-boundary-and-pipeline-foundation
plan: 04
subsystem: auth
tags: [plug, bearer, compatibility, jwt, personal-access-token, scope, mox]
requires:
  - "Explicit PAT/JWT normal-Scope pipelines and bounded credential facts from 243-01 and 243-02"
provides:
  - "Deprecated FetchBearer compatibility dispatcher over explicit PAT and JWT plugs"
  - "Deterministic prefix, enabled-JWT, and opaque-default legacy dispatch with normal Scope facts"
affects: [243-05, API-01]
tech-stack:
  added: []
  patterns:
    - "Legacy dispatchers classify only, then delegate verification and Scope construction to explicit credential-kind plugs"
key-files:
  created: []
  modified:
    - lib/sigra/plug/fetch_bearer.ex
    - test/sigra/plug/fetch_bearer_test.exs
key-decisions:
  - "FetchBearer keeps only its installed three-way classifier; it delegates to FetchAPIToken or FetchJWT rather than rebuilding Scope data."
  - "FetchBearer.init/1 and call/2 are deprecated with migration guidance toward explicit credential-kind plugs."
patterns-established:
  - "Compatibility surfaces preserve routing precedence while forwarding successful authentication through the primary explicit pipeline."
requirements-completed: [API-01]
coverage:
  - id: D1
    description: "Legacy FetchBearer callers retain deterministic prefix/JWT/default dispatch and receive normal Scope plus bounded credential facts."
    requirement: API-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 6min
  completed: 2026-08-12
  tasks: 1
  files: 2
status: complete
---

# Phase 243 Plan 04: FetchBearer Compatibility Dispatcher Summary

**FetchBearer now preserves installed three-way bearer dispatch while delegating every successful path to explicit normal-Scope PAT or JWT pipelines.**

## Performance

- **Duration:** 6 min
- **Tasks:** 1/1
- **Files modified:** 2

## Accomplishments

- Preserved configured-prefix-first, enabled-`eyJ` JWT, and opaque-default PAT dispatch for existing FetchBearer installations.
- Removed direct token-shaped Scope construction by forwarding selected branches through `FetchAPIToken` and `FetchJWT`.
- Deprecated the public compatibility API with direct migration guidance to both explicit credential-kind plugs.

## Task Commits

1. **Task 1: Preserve legacy dispatch while delegating to explicit credential kinds** — `c85e9391` (RED), `df987052` (GREEN)

## Files Created/Modified

- `lib/sigra/plug/fetch_bearer.ex` — deprecated, deterministic compatibility dispatcher.
- `test/sigra/plug/fetch_bearer_test.exs` — normal-Scope, bounded-facts, precedence, failure/skip, and deprecation contracts.

## Decisions Made

- Retained the exact legacy classifier and did not broaden discovery or alter router configuration.
- Delegated all verification, live-user lookup, Scope construction, and bounded-facts production to the named explicit Plug.

## Verification

- `MIX_ENV=test mix test test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs --trace` — passed: 11 tests, 0 failures.
- `mix format --check-formatted lib/sigra/plug/fetch_bearer.ex test/sigra/plug/fetch_bearer_test.exs` — passed.

Focused test startup emitted the documented local PostgreSQL connection-refused noise; all selected Mox/Plug contracts passed without database access.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Fixture Bug] Add the API-token lifecycle field required by the verifier**
- **Found during:** Task 1 RED
- **Issue:** Initial compatibility PAT fixtures omitted `last_used_at`, causing `APIToken.verify/2` to fail before reaching the intended normal-Scope assertion.
- **Fix:** Added the existing verifier-required lifecycle field to both fixture maps.
- **Files modified:** `test/sigra/plug/fetch_bearer_test.exs`
- **Verification:** RED then failed only on the missing dispatcher behavior; GREEN focused suite passed.
- **Commit:** `c85e9391`

**Total deviations:** 1 auto-fixed (Rule 1 test fixture bug). **Impact:** No production-scope change.

## Known Stubs

None.

## Threat Flags

None. The dispatcher adds no endpoints, credential storage, or trust-boundary surface; it reuses the explicit Plug facts allowlists.

## Next Phase Readiness

The legacy bearer surface is bounded to compatibility dispatch and documented as deprecated; Plan 243-05 can establish normative ownership and primary-pipeline documentation without router changes.

## Self-Check: PASSED

Both planned production/test files exist, and RED `c85e9391` plus GREEN `df987052` are present in git history.
