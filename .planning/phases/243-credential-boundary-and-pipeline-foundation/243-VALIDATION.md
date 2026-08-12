# Phase 243: Credential Boundary and Pipeline Foundation - Validation

**Created:** 2026-08-12
**Purpose:** Deterministic evidence contract for BOUND-01 and API-01.
**Status:** Ready for planning

## Validation Strategy

Phase 243 is a library/public-contract phase. Its primary evidence is deterministic ExUnit behavior: a host-selected credential pipeline must construct the normal host Scope from a loaded User, retain only bounded credential facts in conn.private[:sigra_auth], and make incompatible scope checks fail closed. Documentation ownership statements are public contract and receive source-level assertions, not manual review.

The phase must lead with the PAT tracer because Sigra.APIToken.verify/2 already produces a verified token record with user_id, scopes, and identifier. Mox and Plug.Test make the full credential-to-Scope path testable without a live database. JWT follows the same shared helper. FetchAppSession is intentionally tested as fail-closed public foundation until Phase 245 implements its storage/verifier contract. [VERIFIED: 243-RESEARCH.md]

## Requirement-to-Test Matrix

| Requirement | Contract behavior | Automated evidence | Test file | Status |
|-------------|-------------------|--------------------|-----------|--------|
| BOUND-01 | One normative contract assigns first-party identity/session/assurance/revocation to Sigra; OAuth/OIDC AS delegation to Lockspire; runtime/offline facts-only consumption to Crosswake; and authorization/media/lease/replay policy to host. | Source assertions require all owners and deny stale primary implicit-auth claims in contract/API/Lockspire documents. | test/sigra/credential_boundary_docs_test.exs | Wave 0 |
| API-01 | Explicit PAT pipeline verifies PAT, loads current host User, builds normal Scope, writes bounded trusted facts, and skips when a Scope already exists. | Mox Repo expectations plus exact Scope/private/assigns assertions. | test/sigra/plug/fetch_api_token_test.exs | Wave 0 |
| API-01 | Explicit JWT pipeline validates token, loads current User from string subject, builds normal Scope, writes bounded facts, and fails when token/user is invalid. | Existing JWT verifier test support plus Mox Repo assertions. | test/sigra/plug/fetch_jwt_test.exs | Wave 0 |
| API-01 | Explicit app-session pipeline does not infer another credential type, accept raw app-session input into state, or authenticate before Phase 245 storage exists. | Fail-closed Plug.Test cases and private/assigns negative assertions. | test/sigra/plug/fetch_app_session_test.exs | Wave 0 |
| API-01 | Legacy FetchBearer remains deterministic and gives migration/deprecation guidance without becoming new canonical path. | Existing fetch-bearer suite rewritten to test delegation compatibility and deprecation contract, not newly encouraged autodetection. | test/sigra/plug/fetch_bearer_test.exs | Update |
| API-01 | Cookie FetchSession remains source-compatible and normal Scope behavior is preserved if it moves to shared helper. | Existing session-store Mox suite updated for loaded user, normal Scope, session facts, and no behavior regression. | test/sigra/plug/fetch_session_test.exs | Update |
| API-01 | RequireScopes authorizes only trusted server-produced scoped credential facts and denies normal Scope with missing/unscoped browser/app facts. | Table-driven Plug.Test matrix; exact ErrorHandler status/body/halt assertions. | test/sigra/plug/require_scopes_test.exs | Rewrite |

## Wave 0 Test Gaps

- [ ] test/sigra/credential_boundary_docs_test.exs
  - Read exact public documents under guides/introduction/contract.md, guides/flows/api-authentication.md, and guides/recipes/companion-libs/lockspire.md.
  - Assert normative owner labels and explicit-pipeline migration wording.
  - Assert new primary documentation does not recommend FetchBearer/autodetection.

- [ ] test/sigra/plug/fetch_api_token_test.exs
  - PAT tracer: valid bearer PAT invokes Sigra.APIToken.verify/2 path, loads expected user through Sigra.MockRepo, produces host normal Scope through Sigra.Scope.build/3, and stores only allowlisted sigra_auth facts.
  - Assert no raw Authorization token is present in assigns or private metadata.
  - Cover absent/malformed/revoked/expired PAT, missing user, and pre-existing Scope skip paths.

- [ ] test/sigra/plug/fetch_jwt_test.exs
  - Verify integer-like/string JWT subject handling, deleted-user rejection, valid scope facts, missing/invalid JWT, and pre-existing Scope skip.
  - Assert raw JWT and arbitrary claim material cannot enter metadata.

- [ ] test/sigra/plug/fetch_app_session_test.exs
  - Prove the Phase 243 public plug is fail-closed until its Phase 245 verifier exists.
  - Assert no fallback into PAT/JWT/autodetection and no credential state retained.

- [ ] Rewrite test/sigra/plug/require_scopes_test.exs
  - Remove authorization based on scope.auth_method and scope.token_scopes.
  - Cover no Scope, no facts, session/app-session facts without scopes, matching PAT/JWT facts, wildcard, matching any/all, and insufficient scopes.
  - Verify handler call, 403 status, response body, and halted connection for every denied state.

- [ ] Update test/sigra/plug/fetch_bearer_test.exs and fetch_session_test.exs
  - Preserve compatibility contracts without using old token-only Scope maps as expected behavior.
  - Add deprecation/source-doc assertion for FetchBearer.
  - Resolve and test whether FetchSession must use the shared normal-Scope helper.

## Deterministic Evidence Expectations

1. Every successful explicit pipeline assertion must compare a real host-Scope-shaped value with user equal to the Repo-returned User; a truthy map with id or token scopes is insufficient evidence.
2. Every credential path must assert exact private fact keys and values and assert credential raw input is absent from conn.assigns and conn.private[:sigra_auth].
3. Every rejected credential and missing-user case must assert current_scope is nil. Scope enforcement rejections must assert error-handler result, status, and conn.halted.
4. Every skip case must place an existing normal Scope before the plug and assert verifier/Repo are not called. Mox verify_on_exit enforces the no-call condition.
5. Documentation tests must assert exact normative owner terms and explicit pipeline names. They must not rely on screenshots, human UAT, sleeps, or network services.
6. Each task must attach its exact test command/result to the commit or plan summary. A passing source grep alone is not sufficient for API-01.

## Commands and Cadence

### Per-task command

    MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_scopes_test.exs test/sigra/scope/build_test.exs

Run the relevant subset before each task commit; run the complete command whenever the shared helper, metadata shape, RequireScopes, FetchBearer, or FetchSession changes.

### Per-wave command

    MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_scopes_test.exs test/sigra/scope/build_test.exs

Expected result: all selected tests pass with no failures. Existing baseline equivalent focused suite passed 41 tests on 2026-08-12. [VERIFIED: 243-RESEARCH.md]

### Phase gate

    MIX_ENV=test mix ci

This includes formatting, dependency checks, warning-free compile, default test execution, golden/install validation, and the dependency-off path. [VERIFIED: mix.exs]

## Local PostgreSQL Limitation Handling

The local environment has Elixir/Mix and compiled dependencies but no running PostgreSQL at the test-helper configured port. Focused Mox/Plug tests pass even though test startup reports Postgrex connection-refused noise; this is not permission to waive the complete phase gate. [VERIFIED: 243-RESEARCH.md]

- Do not mark the full suite or phase gate passed locally while PostgreSQL is unavailable.
- Use the focused Mox command for deterministic implementation feedback only.
- Before full verification, start the project-standard database service through the documented test DB workflow or use the CI service; retain its command output as evidence.
- If database startup or full suite fails deterministically, repair the cause and rerun once. If it cannot be proven, keep the phase blocked with durable diagnostics rather than reporting an unverified pass.
- Do not introduce test sleeps, browser UAT, or external service polling for this phase; all required behavior has unit/source-contract evidence.

## Evidence Artifact Checklist

- [ ] Docs test output proves BOUND-01 ownership language and removal of primary implicit fallback.
- [ ] PAT tracer output proves normal Scope plus bounded private facts.
- [ ] JWT output proves string subject user lookup and deleted-user failure.
- [ ] App-session output proves fail-closed Phase 243 boundary.
- [ ] RequireScopes output proves missing/unscoped browser/app session cases halt.
- [ ] FetchBearer output proves compatibility dispatcher/deprecation without new canonical usage.
- [ ] Focused suite output is green after final code changes.
- [ ] Full MIX_ENV=test mix ci output is green with PostgreSQL available.

## Planner Notes

The first implementation plan must include Wave 0 tests before or with the shared credential helper. Subsequent plans should preserve the tracer ordering: PAT pipeline, scope gate, JWT/app foundation, then compatibility/docs. Generator edits, opaque storage, refresh families, native ceremonies, and app-session persistence are expressly outside this phase and must not be used to satisfy these validation rows. [VERIFIED: 243-CONTEXT.md; 243-RESEARCH.md]
