---
phase: 243-credential-boundary-and-pipeline-foundation
verified: 2026-08-12T16:29:00-04:00
status: passed
score: 15/15 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 243: Credential Boundary and Pipeline Foundation Verification Report

**Phase Goal:** Phoenix adopters can choose a credential contract with clear ownership and receive a normal user Scope without credential confusion.
**Verified:** 2026-08-12T16:29:00-04:00
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | One normative contract identifies the owner of identity, session, delegation, runtime, authorization, media, lease, and replay concerns. | ✓ VERIFIED | `guides/introduction/contract.md:35-52` contains the normative seven-row matrix across Sigra, Lockspire, Crosswake, and Phoenix host; `CredentialBoundaryDocsTest` asserts every required concern. |
| 2 | A host can select cookie-session, app-session, PAT, or JWT authentication and receives a normal current-user Scope for supported authenticated selections. | ✓ VERIFIED | The public table and router examples name all four explicit plugs (`guides/flows/api-authentication.md:21-115`). PAT, JWT, and browser-session tests prove Scope construction; app-session is explicitly selected but deliberately fails closed pending Phase 245. |
| 3 | Credential metadata is separate from Scope and incompatible credential/scope combinations fail closed. | ✓ VERIFIED | `CredentialAuth` assigns Scope separately from bounded `:sigra_auth` facts (`lib/sigra/plug/credential_auth.ex:6-18`); `RequireScopes` accepts only PAT/JWT facts and rejects browser, app-session, missing, and empty facts (`lib/sigra/plug/require_scopes.ex:62-95`). |
| 4 | The explicit PAT pipeline verifies only a PAT, reloads the live user, and constructs the host Scope. | ✓ VERIFIED | `FetchAPIToken` calls only `Sigra.APIToken.verify/2`, then `repo.get/2` and `CredentialAuth.put_verified_scope/5` (`lib/sigra/plug/fetch_api_token.ex:31-46`); focused valid/deleted/invalid-path tests pass. |
| 5 | PAT facts are bounded and verifier-derived; raw credentials do not enter Scope metadata. | ✓ VERIFIED | Only kind, ID, scopes, method, and assurance are copied (`credential_auth.ex:7-13`); PAT tests assert exact shape and absence of raw token from assigns/private. |
| 6 | `RequireScopes` uses trusted server-selected scopes only and fails closed when absent or unscoped. | ✓ VERIFIED | Kind allowlist and empty fallback are explicit (`require_scopes.ex:91-102`); test cases cover missing, browser, app-session, empty, Scope-shaped, PAT, JWT, and wildcard facts. |
| 7 | The explicit JWT pipeline validates only JWTs, reloads the live user, and emits normal Scope plus bounded facts. | ✓ VERIFIED | `FetchJWT` calls only `Sigra.JWT.verify_access/2`, requires a string subject, reloads user, and creates facts (`lib/sigra/plug/fetch_jwt.ex:31-58`); focused valid/invalid/deleted-user tests pass. |
| 8 | `FetchAppSession` is publicly selectable yet rejects authentication until Phase 245 provides verifier/storage. | ✓ VERIFIED | The Plug only preserves an existing Scope or assigns `nil`, without credential parsing or metadata (`lib/sigra/plug/fetch_app_session.ex:20-27`); focused tests prove no auth/session private state is emitted. |
| 9 | Explicit PAT and JWT plugs do not fall back to another credential kind or token-shape autodetection. | ✓ VERIFIED | Each explicit plug has a single named verifier and no alternate dispatcher; tests invoke invalid inputs and assert `nil` Scope/no facts. |
| 10 | Browser sessions reload the full current user and construct normal Scope while retaining legacy Scope compatibility. | ✓ VERIFIED | After a valid session, `FetchSession` calls `repo.get/2` and `CredentialAuth.build_scope/2` (`lib/sigra/plug/fetch_session.ex:79-106`); tests cover struct Scope, legacy `new/1`, and deleted user. |
| 11 | Browser sessions never acquire delegated credential facts. | ✓ VERIFIED | Browser path writes only `:sigra_session`, never `:sigra_auth` (`fetch_session.ex:88-94`); tests assert no credential facts for struct and deleted-user cases. |
| 12 | Existing `FetchBearer` callers retain deterministic prefix/JWT/default compatibility dispatch with normal Scope and bounded facts. | ✓ VERIFIED | Dispatcher chooses PAT prefix first, enabled JWT second, PAT default, then delegates (`lib/sigra/plug/fetch_bearer.ex:56-88`); focused tests cover all branches. |
| 13 | `FetchBearer` is deprecated compatibility-only, not the primary public pipeline. | ✓ VERIFIED | Both public functions carry `@deprecated` guidance (`fetch_bearer.ex:24-48`), and the primary guide presents only explicit plugs before its compatibility section. |
| 14 | Primary documentation presents explicit pipelines, normal Scope, and separate metadata. | ✓ VERIFIED | `guides/flows/api-authentication.md:21-115` documents all selections, first-successful Scope order, private facts, and scoped-route restrictions; documentation contract test passes. |
| 15 | Lockspire and Crosswake are consumers of Scope/projected facts, never Sigra credential holders or authentication authorities. | ✓ VERIFIED | Normative matrix and Lockspire recipe state the boundary (`contract.md:43-49`, `lockspire.md:16-22`); documentation contract test passes. |

**Score:** 15/15 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/plug/credential_auth.ex` | Normal Scope and bounded-metadata seam | ✓ VERIFIED | 34 substantive lines; called by PAT/JWT plugs and browser session uses its Scope builder. |
| `lib/sigra/plug/fetch_api_token.ex` | Explicit PAT Plug | ✓ VERIFIED | 55 substantive lines; verifier → live user → Scope/facts flow is exercised. |
| `lib/sigra/plug/fetch_jwt.ex` | Explicit JWT Plug | ✓ VERIFIED | 59 substantive lines; verifier → live user → Scope/facts flow is exercised. |
| `lib/sigra/plug/fetch_app_session.ex` | Fail-closed app-session seam | ✓ VERIFIED | 28 substantive lines; public Plug contract and no-auth path exercised. |
| `lib/sigra/plug/fetch_session.ex` | Full-user browser Scope construction | ✓ VERIFIED | Live-user and Scope wiring exercised for generated and legacy host Scope forms. |
| `lib/sigra/plug/fetch_bearer.ex` | Deprecated compatibility dispatcher | ✓ VERIFIED | Delegates every successful legacy branch to explicit plugs; tests cover precedence. |
| `lib/sigra/plug/require_scopes.ex` | Fail-closed trusted-scope enforcement | ✓ VERIFIED | Reads only trusted private metadata; negative combinations are exercised. |
| `guides/introduction/contract.md` | Normative ownership matrix | ✓ VERIFIED | Matrix is present, linked to concrete pipeline guide, and machine-checked. |
| `guides/flows/api-authentication.md` | Explicit pipeline/migration guidance | ✓ VERIFIED | Explicit public selection precedes deprecated compatibility guidance. |
| `guides/recipes/companion-libs/lockspire.md` | Delegation boundary guide | ✓ VERIFIED | Scope-without-credentials boundary is machine-checked. |
| `test/sigra/credential_boundary_docs_test.exs` | Public-copy guard | ✓ VERIFIED | Non-stub, 3 assertions groups passed in focused run. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `FetchAPIToken` | `Sigra.APIToken.verify/2` | sole explicit PAT verifier | ✓ WIRED | Direct call at `fetch_api_token.ex:36`; valid and invalid branches tested. |
| `CredentialAuth` | `Sigra.Scope.build/3` | struct Scope construction | ✓ WIRED | Direct call at `credential_auth.ex:23`; generated struct Scope test passes. |
| `RequireScopes` | `conn.private[:sigra_auth]` | trusted scope source | ✓ WIRED | Private facts read at line 63 and allowlisted at lines 91-95. |
| `FetchJWT` | `Sigra.JWT.verify_access/2` | sole explicit JWT verifier | ✓ WIRED | Direct call at `fetch_jwt.ex:36`; valid and invalid JWT tests pass. |
| `FetchJWT` | `CredentialAuth` | live user to Scope/facts seam | ✓ WIRED | Direct call at `fetch_jwt.ex:39`. |
| `FetchSession` | configured Repo | live current-user resolution | ✓ WIRED | Direct `config.repo.get/2` at `fetch_session.ex:81`; deleted-user test passes. |
| `FetchSession` | `CredentialAuth.build_scope/2` | generated/legacy Scope construction | ✓ WIRED | Direct call at `fetch_session.ex:92`; both Scope forms tested. |
| `FetchBearer` | `FetchAPIToken` / `FetchJWT` | deterministic legacy delegation | ✓ WIRED | Dispatch returns modules and invokes `.call/2` at lines 59-75; three branch tests pass. |
| ownership matrix | explicit pipeline guide | concrete application link | ✓ WIRED | `contract.md:51-52` links the normative matrix to API Authentication. |
| Lockspire guide | normal Scope/no credential transfer | delegation seam | ✓ WIRED | Explicit prose at `lockspire.md:18-22`, guarded by test. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `FetchAPIToken` | `current_scope`, `:sigra_auth` | verified PAT plus configured Repo live-user lookup | Mock verifier/Repo behavior is asserted in the focused runtime test | ✓ FLOWING |
| `FetchJWT` | `current_scope`, `:sigra_auth` | verified JWT claims plus configured Repo live-user lookup | Signed test JWT and asserted Repo lookup produce a host Scope | ✓ FLOWING |
| `FetchSession` | `current_scope` | validated stored session plus configured Repo live-user lookup | Session-store/Repo contracts are asserted for valid and deleted users | ✓ FLOWING |
| `FetchAppSession` | `current_scope` | no source by design until Phase 245 | Explicitly produces `nil`, not static success or hollow metadata | ✓ FAIL-CLOSED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| All Phase 243 concrete authentication and documentation contracts | `MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_scopes_test.exs test/sigra/scope/build_test.exs` | 42 tests, 0 failures | ✓ PASS |
| Phase-touched Elixir formatting | `mix format --check-formatted` with Phase 243 `.ex`/`.exs` paths | Exit 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- |
| BOUND-01 | 243-05 | One normative four-owner contract covers all listed concerns. | ✓ SATISFIED | Normative matrix, linked concrete guide, and passing documentation contract test. |
| API-01 | 243-01 through 243-05 | Explicit cookie/app/PAT/JWT pipelines build normal Scope, separate facts, and reject invalid scope/credential combinations. | ✓ SATISFIED | Focused 42-test plug/docs suite; direct code and data-flow trace above. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `guides/recipes/companion-libs/lockspire.md` | 161 | Historical prose mentions generated `# TODO:` markers | ℹ️ Info | Introduced in commit `c1766a7e` (2026-05-28), not Phase 243; describes a host-generator failure mode rather than unfinished Phase 243 code. |
| workspace CI | n/a | Full formatter check fails | ⚠️ Warning (external) | `mix format --check-formatted` reports only `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` (commit `08f5e088`, Phase 238) and `test/sigra/install/generated_rate_limit_contract_test.exs` (commits `a0dd0bc1`/`6f70de51`, Phase 240). Neither is in Phase 243's commit range, so this does not block this phase. |

## Disconfirmation Pass

- A seemingly incomplete app-session Plug is intentional and correct for this phase: it assigns no success state and its no-parse/no-metadata behavior is exercised. Durable verifier/storage work is explicitly Phase 245.
- The documentation test is necessarily string-oriented, so it was not accepted as evidence alone; the focused runtime suite separately executes all Plug paths and their negative cases.
- The focused suite emits Postgrex connection-refused logs for the unavailable local test database (`127.0.0.1:53988`), but the selected Phase 243 tests are DB-free mock contracts and completed successfully (42/42). No test waited on, mutated, or required that unavailable service.

### Human Verification Required

None. Project policy requires deterministic automation where possible; all phase behaviors have focused executable coverage.

---

_Verified: 2026-08-12T16:29:00-04:00_
_Verifier: the agent (gsd-verifier)_
