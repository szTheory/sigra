---
phase: 244-pat-and-advanced-jwt-truth-repair
verified: 2026-08-13T00:04:30Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/4
  gaps_closed:
    - "Core-template inventory/layout contracts recognize the 56 shipped templates."
    - "PAT post-install guidance names the generated /users/api-tokens browser-management route."
  gaps_remaining: []
  regressions: []
---

# Phase 244: PAT and Advanced JWT Truth Repair Verification Report

**Phase Goal:** Adopters can independently generate and safely use the PAT and advanced JWT capabilities Sigra presents.
**Verified:** 2026-08-13T00:04:30Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh `--api` host can create and authenticate PATs using generated schemas, migration, configuration, delegates, routes, and plugs. | ✓ VERIFIED | The Phase 244 focused gate previously generated an API-only host twice, migrated, compiled, created a PAT, and authenticated it through `FetchAPIToken`; current installer regression contracts remain green. |
| 2 | A recent browser-authenticated user can list/create/revoke only their PATs through CSRF and sudo gates, with server-enforced scopes. | ✓ VERIFIED | The generated-router runtime proof covers valid, unauthenticated, invalid/missing-CSRF, stale-sudo, and foreign-owner paths with persisted-row assertions; `APIToken.revoke_for_user/3` constrains id, owner, and active state. |
| 3 | A fresh `--jwt` host independently issues and validates strict advanced JWTs with configured algorithm/type/issuer/audience and required claims, enforcing `nbf` when present. | ✓ VERIFIED | The fresh JWT-only host proof and strict signer/header/claims/audience/`nbf` matrix passed in the verified Phase 244 focused gate; this closure did not alter their implementation. |
| 4 | A host issues server-scoped JWTs and atomically rotates/revokes opaque refresh families without a generated password-to-JWT endpoint or request-selected JWT scopes. | ✓ VERIFIED | Generated `Auth.JWT` keeps scope selection in host code; the locked `Ecto.Multi` refresh lifecycle and PostgreSQL audit-on/off concurrency proof remain intact. |
| 5 | CI-facing inventory recognizes exactly the 56 intentional core templates, including the independent JWT host-policy template. | ✓ VERIFIED | `isolation_test.exs` now asserts 56; its focused run passed while retaining forbidden-symbol scanning. |
| 6 | The explicit sorted template manifest equals the 56 files on disk and includes `auth_jwt.ex`, `rate_limit.ex`, `registration_controller.ex`, and `settings_controller.ex`. | ✓ VERIFIED | `templates_layout_test.exs` lists all four additions and compares `Enum.sort(@manifest_post_move)` to the physical directory; focused test passed. |
| 7 | PAT post-install guidance points to `/users/api-tokens`, not the nonexistent bearer-management path. | ✓ VERIFIED | `Core.base_instruction_block/1` emits the browser PAT route; the focused output test asserts `/users/api-tokens` and refutes `/api/tokens`. |
| 8 | Focused installer integration passes and repository CI is reported honestly with Phase 244 failures separated from unrelated failures. | ✓ VERIFIED | Focused closure command exited 0 (20 tests). Verifier-run `mix ci` exits 1 with exactly 27 classified non-244 failures; none is waived or presented as green. |

**Score:** 8/8 truths verified (0 present-but-behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/install/features/core.ex` | Independent API/JWT wiring and truthful PAT guidance | ✓ VERIFIED | Emits the explicit credential-kind pipelines and now states `/users/api-tokens`. |
| `priv/templates/sigra.install/core/auth_api_token.ex`, `api_token_controller.ex` | Owner-bound browser PAT management | ✓ VERIFIED | Current-scope owner wiring is exercised by the generated-host proof. |
| `lib/sigra/api_token.ex`, `lib/sigra/auth.ex` | Owner-bound revoke and server scope allowlist | ✓ VERIFIED | Active-owner query and facade are covered by focused PAT tests. |
| `priv/templates/sigra.install/core/auth_jwt.ex` | Host-policy JWT issuance | ✓ VERIFIED | Server-selected scope policy is used by the fresh JWT-only host proof. |
| `lib/sigra/jwt.ex`, `lib/sigra/jwt/validator.ex`, `lib/sigra/jwt/refresh_token.ex` | Strict access tokens and locked refresh lifecycle | ✓ VERIFIED | Focused JWT/refresh and PostgreSQL concurrency evidence passed in the phase gate. |
| `test/sigra/install/isolation_test.exs` | Exact 56-file isolation inventory | ✓ VERIFIED | 4 focused assertions passed. |
| `test/sigra/install/templates_layout_test.exs` | Exact sorted 56-file layout manifest | ✓ VERIFIED | Directory-to-manifest equality passed. |
| `test/sigra/install/features/core_post_instructions_test.exs` | PAT route instruction regression test | ✓ VERIFIED | `/users/api-tokens` present and `/api/tokens` absent in rendered output. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Core API injection | `Sigra.Plug.FetchAPIToken` | Generated API pipeline | ✓ WIRED | API-only fresh host authenticates a real PAT through this plug. |
| Generated PAT controller | Generated Auth/PAT facade | `current_scope.user` owner | ✓ WIRED | Owner is derived from Scope; foreign revoke is a 404 without mutation. |
| Browser router | PAT controller | browser + authenticated + sudo gates | ✓ WIRED | Generated route is behind `[:browser, :require_authenticated, :require_sudo]`. |
| Generated JWT delegate | `Sigra.JWT.generate_tokens/4` | Host-selected user/scopes | ✓ WIRED | `auth_jwt.ex` uses private `jwt_scopes_for/1`, not request input. |
| JWT pipeline | `Sigra.Plug.FetchJWT` | strict verification and Scope projection | ✓ WIRED | Fresh JWT host accepts valid and rejects forged credentials. |
| Core template directory | layout manifest test | exact sorted equality | ✓ WIRED | The test reads the directory and rejects additions/omissions. |
| Core post instructions | post-instruction test | rendered `--api` route | ✓ WIRED | Both source and rendered-output assertions use `/users/api-tokens`. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated PAT controller | `current_scope.user`, PAT rows | browser Scope and repository-backed Auth calls | Generated-host PostgreSQL smoke creates/lists/revokes/authenticates real PATs | ✓ FLOWING |
| Generated JWT delegate/pipeline | access/refresh credentials and Scope | host policy → JWT/Joken → refresh store | Generated-host smoke signs, verifies, and projects the user Scope | ✓ FLOWING |
| Refresh lifecycle | digest-addressed family | locked DB query and `Ecto.Multi` | PostgreSQL audit-on/off and two-caller proof use persisted rows | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Template inventory, layout, and PAT guidance | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs test/sigra/install/features/core_post_instructions_test.exs --trace` | 20 tests, 0 failures | ✓ PASS |
| Repository integration diagnostic | `source tmp/db.env && MIX_ENV=test mix ci` | Exit 1; 2,625 tests, 27 failures, 12 skipped (26 excluded) | ℹ️ EXTERNAL FAILURES — no Phase 244 failure |

## Repository CI Attribution

The verifier reran the repository diagnostic. It is red, and the result is preserved as non-passing. Its 27 failures have no failing Phase 244 artifact, test module, or requirement path:

| Area | Failure count | Current failure class |
| --- | ---: | --- |
| Phase 234 planning evidence/inventory | 5 | Missing live Playwright specs and validation-signoff inventory mismatch |
| Phase 235 planning artifacts | 3 | Missing FAST-01 residual todo artifact |
| Phase 236 closeout | 2 | Scope fence rejects user-modified `.planning/config.json`; traceability map mismatch |
| Phase 239 planning artifacts | 2 | Missing Crosswake release proof and `COVERAGE.md` |
| Phase 240 / 240.3 planning artifacts | 4 | Missing plan, runtime evidence, and coverage files |
| Legacy generator/template contracts | 4 | Three `GeneratorWiringTest` assertions and one installer-drift assertion unrelated to the Phase 244 route-instruction diff |
| Architecture guides | 1 | Source excerpt drift |
| Threadline forwarder | 6 | Missing `Sigra.Audit.Forwarders.Threadline` module |

The only CI failures previously attributed to Phase 244—core template count/layout inventory—are absent. Although three legacy `GeneratorWiringTest` failures read `core.ex`, `git diff 7b4888b1^..971364c2` shows Phase 244-07 changed only the post-install instruction line; the failing reset/confirmation/password assertions target unrelated source/template expectations. They are therefore not caused by, nor required to prove, the Phase 244 PAT/JWT integration.

## Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
| --- | --- | --- | --- |
| PAT-01 | 01, 03, 07 | ✓ SATISFIED | API-only fresh-host proof plus reconciled shipped-template contract. |
| PAT-02 | 02, 03, 07 | ✓ SATISFIED | Owner/scope/browser guards, plus correct adopter route guidance. |
| JWT-01 | 01, 04, 05, 07 | ✓ SATISFIED | JWT-only host/claim proof and registered `auth_jwt.ex` template inventory. |
| JWT-02 | 01, 04, 05, 06, 07 | ✓ SATISFIED | Host-policy issuance and atomic opaque refresh-family evidence remain green. |

No Phase 244 requirement is orphaned from its plans.

## Anti-Patterns Found

No Phase 244 blocker or warning anti-pattern remains. The closure artifacts contain no unreferenced `TBD`, `FIXME`, or `XXX` marker; the exact manifest guard was retained rather than weakened.

## Decision Coverage

All 11 trackable Phase 244 CONTEXT decisions remain honored by shipped artifacts (previous deterministic decision-coverage check; Plan 07 changes only inventory and guidance contracts).

## Gaps Summary

The prior Phase 244 integration gaps are closed. Repository CI remains globally red for the 27 separately classified failures above, but none is a Phase 244 regression or a missing proof required for this phase's PAT/JWT goal. They remain open repository debt and are not waived by this passed phase verdict.

_Verified: 2026-08-13T00:04:30Z_
_Verifier: the agent (gsd-verifier)_
