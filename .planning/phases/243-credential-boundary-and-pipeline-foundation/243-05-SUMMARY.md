---
phase: 243-credential-boundary-and-pipeline-foundation
plan: 05
subsystem: auth
tags: [documentation, credential-boundary, pipelines, lockspire, crosswake]
requires:
  - "Explicit browser, PAT, JWT, app-session, and compatibility pipeline seams from Plans 01-04"
provides:
  - "Normative four-owner credential-boundary responsibility matrix"
  - "Explicit public cookie, app-session, PAT, JWT, and mixed pipeline guidance"
  - "Machine-checked Lockspire and Crosswake credential-boundary copy"
affects: [244-generator-pipeline-repair, 245-app-session-storage, 246-native-login]
tech-stack:
  added: []
  patterns:
    - "Documentation source contracts lock security-relevant public wording"
    - "Primary guides select credential kind explicitly; compatibility dispatch is migration-only"
key-files:
  created:
    - test/sigra/credential_boundary_docs_test.exs
  modified:
    - guides/introduction/contract.md
    - guides/flows/api-authentication.md
    - guides/recipes/companion-libs/lockspire.md
key-decisions:
  - "Sigra owns first-party authentication; Lockspire owns external OAuth/OIDC delegation; Crosswake consumes projected facts; the host owns authorization, media, leases, and replay."
  - "Primary documentation uses four explicit public credential plugs and reserves FetchBearer for migration guidance."
requirements-completed: [BOUND-01, API-01]
coverage:
  - id: D1
    description: "Normative responsibility matrix and explicit credential-kind pipeline documentation"
    requirement: BOUND-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs test/sigra/recipes/companion_lib_contract_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase credential-boundary focused Plug and documentation contract suite"
    requirement: API-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_scopes_test.exs test/sigra/scope/build_test.exs"
        status: pass
    human_judgment: false
metrics:
  duration: 3min
  completed: 2026-08-12
  tasks: 1
  files: 4
status: complete
---

# Phase 243 Plan 05: Credential Boundary Documentation Summary

**A machine-checked ownership matrix and explicit cookie, app-session, PAT, and JWT pipelines now define Sigra’s credential boundary without transferring credentials to Lockspire or Crosswake.**

## Performance

- **Duration:** 3 min
- **Completed:** 2026-08-12T19:54:42Z
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Added one normative responsibility matrix covering Sigra, Lockspire, Crosswake, and Phoenix-host ownership for identity, sessions, delegation, runtime, authorization, media/cache, leases, and replay.
- Reframed API guidance around `FetchSession`, `FetchAppSession`, `FetchAPIToken`, and `FetchJWT`, including ordered mixed pipelines and private credential metadata.
- Added source-contract tests preventing primary documentation from recommending compatibility autodetection and locking companion-library credential boundaries.

## Task Commits

1. **Task 1: Ratify the four-owner contract and explicit pipeline documentation** — `0cc3b339` (RED), `8922a830` (GREEN)

## Files Created/Modified

- `test/sigra/credential_boundary_docs_test.exs` — deterministic BOUND-01/API-01 public-copy guard.
- `guides/introduction/contract.md` — normative four-owner responsibility matrix.
- `guides/flows/api-authentication.md` — primary explicit credential-kind pipelines and compatibility migration note.
- `guides/recipes/companion-libs/lockspire.md` — normal-Scope-only delegation boundary.

## Decisions Made

- Normal current-user Scope carries identity/context, while bounded credential facts remain private; only verified PAT/JWT facts authorize delegated scopes.
- Lockspire receives authenticated identity facts for registered-client delegation, never Sigra credentials; Crosswake remains a projected-facts runtime consumer.

## Verification

- `MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs test/sigra/recipes/companion_lib_contract_test.exs --trace` — passed, 5 tests / 0 failures.
- Complete phase-focused suite — passed, 42 tests / 0 failures.
- `MIX_ENV=test mix ci` — not run to test completion: `mix format --check-formatted` failed first on two pre-existing files outside this plan. See `deferred-items.md` for durable diagnostics. The local PostgreSQL service at `127.0.0.1:53988` is also unavailable for a later database-backed gate.

## Deviations from Plan

None - plan implementation executed exactly as written.

## Known Stubs

None.

## Issues Encountered

- The required full CI gate is unproven because unrelated format violations halt it before the test suite. This is recorded in the phase deferred-items ledger and cross-phase Windows ledger.

## Next Phase Readiness

- Phase 244 can consume the explicit public pipeline contract for generator repair.
- Restore formatting in the two deferred test files and a PostgreSQL service before re-running `MIX_ENV=test mix ci`.

## Self-Check: PASSED

- All four documentation-contract artifacts exist.
- RED and GREEN task commits `0cc3b339` and `8922a830` exist in git history.
