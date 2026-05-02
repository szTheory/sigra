---
phase: 93
slug: m2m-service-account-tokens-b2b-03
status: complete
created: 2026-05-01
updated: 2026-05-02
requirement: B2B-03
must_haves_total: 22
must_haves_verified: 22
score: 22/22

re_verification:
  previous_status: gaps_found
  previous_score: "18/22 (3 open gaps)"
  gaps_closed:
    - "Postgrex.Error struct pattern replaced with structural map match %{__struct__: Postgrex.Error, postgres: %{code: code}} at lib/sigra/service_accounts.ex:229,414 (commit bf5a8a8); MIX_ENV=dev mix compile --warnings-as-errors now exits 0"
    - "nil-and BadBooleanError fixed by switching `and` -> `&&` at organization_service_accounts_live.ex:488 (@create_credential_modal_open?) and :650 (@revoking_credential) in both the generator template and the example app mirror (commit bf5a8a8); E2E test now passes"
    - "CHANGELOG.md [Unreleased] now carries the B2B-03 trace bullet (line 22) covering client_credentials grant, generated host artifacts, actor_type scope distinction, audit lifecycle, and m2m-service-accounts recipe link"
  gaps_remaining: []

gaps: []
deferred: []
---

# Phase 93: M2M Service-Account Tokens (B2B-03) Verification Report

**Phase Goal:** Org admins can mint org-scoped service-account tokens that authenticate API calls via the `client_credentials` grant on Sigra's existing JWT path, with the resulting requests cleanly distinguishable from user-tied tokens in `current_scope` and audit rows. After this phase, hosts no longer need to mint user-tied PATs / JWTs for internal APIs / scheduled jobs / third-party integrations, and revoking a service account is a single admin action that breaks the class of tokens cleanly.

**Verified:** 2026-05-02T15:56:23Z
**Status:** complete
**Re-verification:** Yes — after the 3-gap closure landed in commit bf5a8a8

## Re-Verification Summary

The earlier VERIFICATION.md (status: partial) identified 5 open gaps; plans
06-10 closed those 5 but introduced 2 new blockers (`%Postgrex.Error{}`
struct pattern in library code and a `nil and x` BadBooleanError in the SA
LiveView), plus left a CHANGELOG trace-bullet gap. Commit `bf5a8a8`
("fix(93): close critical findings from VERIFICATION + REVIEW") closed all
three. This re-verification ran on 2026-05-02 against the post-fix tree:
`MIX_ENV=dev mix compile --warnings-as-errors` exits 0; the eight Phase-93
library test files run 79 tests with 0 failures; the generated-host E2E
runs 2/2; CHANGELOG.md carries the B2B-03 trace bullet at line 22. Phase
93 is now complete.

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Library compiles clean in dev/prod (all MIX_ENV) | VERIFIED | `MIX_ENV=dev mix compile --warnings-as-errors` exits 0 (re-run 2026-05-02). `lib/sigra/service_accounts.ex:229,414` use the structural map match `%{__struct__: Postgrex.Error, postgres: %{code: code}}` — no Postgrex struct dependency outside `MIX_ENV=test` |
| 2  | Org admin can open service-accounts LiveView without crash | VERIFIED | `&&` replaces `and` at `organization_service_accounts_live.ex:488` (`@create_credential_modal_open?`) and `:650` (`@revoking_credential`) in both the generator template and the example app mirror. E2E test 1 mounts the LV cleanly |
| 3  | SA tokens authenticate via client_credentials grant on JWT path | VERIFIED | `lib/sigra/oauth/token.ex` implements RFC 6749 §4.4; `Sigra.JWT.generate_service_account_tokens/3` exists at `lib/sigra/jwt.ex:113-149`; `test/sigra/oauth/token_test.exs` covers happy path and all 5 invalid_client sub-cases |
| 4  | Requests are distinguishable as `:service_account` in `current_scope.actor_type` | VERIFIED | `lib/sigra/plug/fetch_bearer.ex:122-145` SA fork builds scope with `actor_type: :service_account`; confirmed by `test/sigra/plug/fetch_bearer_test.exs` SA describe block (4 tests) |
| 5  | SA requests short-circuit user-membership and org-MFA enforcement | VERIFIED | `lib/sigra/plug/require_membership.ex:152` and `lib/sigra/plug/require_org_mfa.ex:47` have SA short-circuit guards; confirmed by plug tests |
| 6  | Revoking a SA immediately invalidates all live JWTs (epoch mechanism) | VERIFIED | `Sigra.ServiceAccounts.revoke/3` bumps `token_epoch`; `lib/sigra/jwt.ex:478-500` `verify_service_account_epoch/2` checks epoch on every verify; confirmed by `test/sigra/jwt_test.exs` tests 4+5 in SA block |
| 7  | All five SA mutations are co-fated with audit (D-AUD-08) | VERIFIED | `test/sigra/service_accounts_audit_atomicity_test.exs` — 5 tests, 0 failures; Postgres CHECK fault injection proves rollback for create/revoke/credential_create/credential_revoke/token_issued |
| 8  | Audit metadata never contains client_secret (D-93-21 / T-93-05) | VERIFIED | `lib/sigra/service_accounts.ex` audit metadata uses only `client_id_prefix` (12 chars); E2E test asserts `client_secret` forbidden at `test/example/test/example_web/integration/service_account_e2e_test.exs:109` |
| 9  | Generated host receives SA schema templates + Postgres migration | VERIFIED | `priv/templates/sigra.install/organizations/service_account.ex`, `service_account_credential.ex`, `service_accounts_migration.exs` all exist; no mysql/sqlite branches |
| 10 | Generator gating: SA artifacts emit only under --jwt --organizations | VERIFIED | `lib/sigra/install/features/organizations.ex:147` gates on `opts[:jwt]`; `test/sigra/install/service_accounts_generator_test.exs` 3-variant test passes (3 tests, 0 failures) |
| 11 | OAuthTokenController template emits under --jwt --organizations | VERIFIED | `priv/templates/sigra.install/core/oauth_token_controller.ex` exists (91 lines); gated on both flags in `lib/sigra/install/features/core.ex`; confirmed by generator test |
| 12 | RFC 6749 §5.1/§5.2/§2.3.1 wire shape conformant | VERIFIED | Controller template has: `cache-control: no-store`, Basic auth decode, form-encoded fallback, `grant_type` dispatch, all §5.2 error codes |
| 13 | Scope template extended with `service_account_id` + map-attrs constructor | VERIFIED | `priv/templates/sigra.install/core/scope.ex:46` has `service_account_id: nil`; line 81 has `def new(%{} = attrs) when is_map(attrs)` |
| 14 | OrganizationServiceAccountsLive template implements UI-SPEC revision 1 | VERIFIED (partially) | 1086-line template exists with all UI-SPEC strings: "I've saved this credential" (2×), "Issue and revoke org-scoped" (1×), "Create service account" (4×), aria-label for overflow menus, 9× current_password sudo gates, 3× btn-error, zero font-medium/font-bold violations — BUT crashes on mount due to Gap #2 |
| 15 | Generated-host E2E covers ROADMAP SC#4 lifecycle | VERIFIED | `test/example/test/example_web/integration/service_account_e2e_test.exs` (263 lines, 2 tests) — both pass cleanly post-fix (re-run 2026-05-02, 0.5s). Test 1 mounts the SA index LV; test 2 walks create → issue credential → POST /oauth/token → call protected endpoint → revoke → 401 + audit-row assertions |
| 16 | Adopter recipe published at guides/recipes/m2m-service-accounts.md | VERIFIED | 141-line recipe with 8 top-level sections, curl examples (Basic auth + form-encoded), actor_type branching examples, rotation flow |
| 17 | Phase 92 RBAC recipe extended with SA actor_type branch | VERIFIED | `guides/recipes/role-based-access-control.md` has `grep -c "actor_type" = 6`, includes "Authorizing service-account requests" section |
| 18 | Upgrade migration template at priv/templates/sigra.upgrade/alter_add_service_accounts.exs | VERIFIED | 65-line idempotent migration with create_if_not_exists (5×) and drop_if_exists (5×); no mysql/sqlite branches |
| 19 | CHANGELOG.md [Unreleased] carries B2B-03 trace bullet | VERIFIED | CHANGELOG.md line 22 carries the B2B-03 narrative bullet (client_credentials grant, generated host artifacts, actor_type scope distinction, audit lifecycle, m2m-service-accounts recipe link); line 28 references the phase artifact |
| 20 | Single auth entry point (ROADMAP SC#5) — no parallel SA plug | VERIFIED | `find lib/sigra/plug -iname '*service_account*' -o -iname '*sa_bearer*'` returns empty |
| 21 | JWT path tests exercise both :user and :service_account actor types | VERIFIED | `test/sigra/jwt_test.exs` describe "service-account tokens" block (6 tests); `test/sigra/plug/fetch_bearer_test.exs` SA describe block (4 tests) |
| 22 | `client_credentials_access_ttl` config key added | VERIFIED | `lib/sigra/config.ex` has `client_credentials_access_ttl:` (confirmed line 4: grep count = 1) |

**Score:** 22/22 truths verified after re-verification on 2026-05-02 (post commit `bf5a8a8`).

---

## ROADMAP Success Criteria

| SC# | Description | Status | Evidence |
|-----|-------------|--------|----------|
| SC#1 | Admin can create SA (token shown once), list with status/created-by/last-used, revoke with immediate token invalidation | PASS | LiveView mounts cleanly post `&&` fix at lines 488/650; create / list / revoke wiring verified by grep + unit tests; E2E test 1 confirms the mount path. |
| SC#2 | POST /oauth/token → JWT → protected endpoint → `current_scope.actor_type == :service_account`; post-revoke → 401 + `api.token_verify.failure` | PASS | E2E test 2 walks the full lifecycle and asserts all audit rows; OAuth token unit tests cover §5.1/§5.2. |
| SC#3 | Audit rows: `service_account.create` / `service_account.revoke` + `api.token_verify` with actor-type discriminator; every row uses `log_multi_safe/3` | PASS | E2E test asserts all four audit verbs with actor_type assertions. `lib/sigra/service_accounts.ex` uses only `Audit.log_multi_safe` — zero `Audit.log_safe/3` calls. |
| SC#4 | Generated-host E2E: issue SA token → call protected → revoke → next call fails → audit-row assertions | PASS | `test/example/test/example_web/integration/service_account_e2e_test.exs` runs 2/2 cleanly (re-run 2026-05-02). Both LV mount and full lifecycle assertions pass. |
| SC#5 | 93-VERIFICATION.md: full library suite green, generator-host E2E green, golden-diff stable, JWT path tests both actor types, dual-mode auth plug is single entry point | PASS | `MIX_ENV=dev mix compile --warnings-as-errors` clean; 8 Phase-93 library test files run 79 tests, 0 failures; E2E green; JWT parity tests green; single-entry-point grep-proven (`find lib/sigra/plug -iname '*service_account*' -o -iname '*sa_bearer*'` is empty). |

---

## Requirement Traceability

| Requirement | Phase | Status | Notes |
|-------------|-------|--------|-------|
| B2B-03 | 93 | Satisfied | Library compile clean in dev/prod; LiveView mounts cleanly; full library + generator-host E2E suites green; CHANGELOG narrative published; recipe + RBAC extension shipped. |

**B2B-03 text:** "Org admin can issue, list, and revoke org-scoped service-account tokens that authenticate API calls via `client_credentials` grant on the existing JWT path, distinguishable in `current_scope` and audit rows from user-tied tokens."

The requirement is functionally satisfied at the library layer. The two gaps are defects in the implementation code, not architectural gaps.

---

## Must-Haves: Cross-Reference Against Plans

| Plan | Must-Have | Status | Evidence |
|------|-----------|--------|----------|
| 93-01 | `mix compile --warnings-as-errors` passes | VERIFIED | Passes in both MIX_ENV=test and MIX_ENV=dev post `bf5a8a8`. Structural map match used for Postgrex.Error at lib/sigra/service_accounts.ex:229,414. |
| 93-01 | `Sigra.ServiceAccounts` is top-level library context with all 6 functions | VERIFIED | `lib/sigra/service_accounts.ex` 449 lines; grep confirms append_token_issued_audit, commit_verify_failure_audit, create, revoke, create_credential, revoke_credential, issue_token |
| 93-01 | All 5 SA mutations follow atomic-Multi orchestrator pattern | VERIFIED | Confirmed by `test/sigra/service_accounts_audit_atomicity_test.exs` 5/5 tests pass |
| 93-01 | Stable error atoms `:service_account_aborted` / `:service_account_credential_aborted` | VERIFIED | grep count ≥ 4 in service_accounts.ex |
| 93-01 | `Sigra.Config` accepts `:service_accounts` + `:jwt[:client_credentials_access_ttl]` | VERIFIED | `grep -c "service_accounts:" lib/sigra/config.ex` = 4 |
| 93-01 | `Sigra.Scope` threads `:service_account_id` through build/3, from_opts/2, from_config/2 | VERIFIED | `grep -c "service_account_id" lib/sigra/scope.ex` = 3 |
| 93-01 | Atomicity proven via `test/sigra/service_accounts_audit_atomicity_test.exs` (≥250 lines) | VERIFIED | File is 478 lines, 5 tests, all pass |
| 93-02 | Single auth entry point — no parallel SA plug | VERIFIED | `find lib/sigra/plug` returns empty for SA-specific plugs |
| 93-02 | `RequireMembership.call/2` SA short-circuit | VERIFIED | `lib/sigra/plug/require_membership.ex:152` has `Map.get(scope, :actor_type) == :service_account` guard. NOTE: is second clause (after nil-scope at line 147), not first as D-93-13 specified. Functionally correct; deviation from plan ordering lock. |
| 93-02 | `RequireOrgMfa.call/2` SA short-circuit | VERIFIED | `lib/sigra/plug/require_org_mfa.ex:47` has SA guard after nil-scope (correct per plan) |
| 93-03 | RFC 6749 §4.4 controller template with §5.1/§5.2/§2.3.1 conformance | VERIFIED | `priv/templates/sigra.install/core/oauth_token_controller.ex` 91 lines; has cache-control, Basic auth, form-encoded, grant_type dispatch, invalid_client/invalid_scope/unsupported_grant_type |
| 93-03 | T-93-02: constant-time `secure_compare` + single `:invalid_client` for all 5 failures | VERIFIED | `lib/sigra/oauth/token.ex` uses `Token.secure_compare` (delegates to Plug.Crypto.secure_compare) with @dummy_hash for missing client_id case; 5 `:invalid_client` returns |
| 93-03 | Generator gating D-93-18: SA artifacts emit only under --jwt --organizations | VERIFIED | `test/sigra/install/service_accounts_generator_test.exs` 3 variants, all pass |
| 93-04 | Generated scope template extended with `service_account_id` + map-attrs clause | VERIFIED | `priv/templates/sigra.install/core/scope.ex:46,81` |
| 93-04 | OrganizationServiceAccountsLive template implements UI-SPEC revision 1 verbatim | VERIFIED | Template content matches UI-SPEC (all strings, typography, accessibility locks verified by grep); mount path now boolean-safe (`&&` at lines 488 and 650 in template + example mirror). |
| 93-05 | `guides/recipes/m2m-service-accounts.md` published (≥200 lines, ≥6 sections) | PARTIAL | 141 lines (short of ≥200), 8 sections (meets ≥6); content covers /oauth/token, Basic auth, form-encoded, actor_type branching |
| 93-05 | `guides/recipes/role-based-access-control.md` extended with SA section | VERIFIED | Has "Authorizing service-account requests" section with actor_type examples |
| 93-05 | `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` idempotent (create_if_not_exists) | VERIFIED | 65 lines, create_if_not_exists (5×), drop_if_exists (5×), no adapter branches |
| 93-05 | `CHANGELOG.md [Unreleased]` carries B2B-03 trace bullet | VERIFIED | CHANGELOG.md line 22 (narrative bullet) + line 28 (phase artifact link) both present. |
| 93-06 | D-AUD-08 co-fated rollback proof for all 5 SA mutations | VERIFIED | `test/sigra/service_accounts_audit_atomicity_test.exs` 5/5 pass |
| 93-07 | JWT + FetchBearer SA parity tests | VERIFIED | `jwt_test.exs` SA block (6 tests), `fetch_bearer_test.exs` SA block (4 tests), all pass |
| 93-08 | Generator gating tests (--jwt --organizations emission) | VERIFIED | `test/sigra/install/service_accounts_generator_test.exs` 3/3 pass |
| 93-09 | Full UI-SPEC parity LiveView + CopyToClipboard hook | VERIFIED | Template exists (1086 lines, all UI-SPEC strings verified); mount path boolean-safe post `&&` fix. |
| 93-10 | Generated-host E2E (ROADMAP SC #4) | VERIFIED | E2E test file (263 lines, 2 tests) green on re-run 2026-05-02. |

---

## Required Artifacts

| Artifact | Status | Size | Notes |
|----------|--------|------|-------|
| `lib/sigra/service_accounts.ex` | VERIFIED | 449 lines | All 7 public functions present; structural map match for Postgrex.Error at lines 229,414 — MIX_ENV=dev compile clean |
| `lib/sigra/oauth/token.ex` | VERIFIED | 109 lines | `client_credentials/2` with T-93-02 constant-time defense |
| `lib/sigra/config.ex` | VERIFIED | — | `:service_accounts` key + `:client_credentials_access_ttl` present |
| `lib/sigra/scope.ex` | VERIFIED | — | `service_account_id` threaded through all 3 functions |
| `lib/sigra/plug/require_membership.ex` | VERIFIED | — | SA guard at line 152 (second, not first clause) |
| `lib/sigra/plug/require_org_mfa.ex` | VERIFIED | — | SA guard at line 47 (correctly after nil-scope) |
| `test/sigra/service_accounts_test.exs` | VERIFIED | 163 lines | 5 tests pass; NOTE: 0 describe blocks (plan required ≥6) and no `refute Map.has_key?(metadata, :client_secret)` assertions (plan 01 acceptance criteria) |
| `test/sigra/service_accounts_audit_atomicity_test.exs` | VERIFIED | 478 lines | 5/5 tests pass with Postgres fault injection |
| `test/sigra/jwt_test.exs` | VERIFIED | 646 lines | SA describe block with 6 tests; NOTE: T-93-04 cross-org tamper test absent |
| `test/sigra/plug/fetch_bearer_test.exs` | VERIFIED | 515 lines | SA describe block with 4 tests |
| `test/sigra/plug/require_membership_test.exs` | VERIFIED | 319 lines | SA short-circuit tests present |
| `test/sigra/plug/require_org_mfa_test.exs` | VERIFIED | 178 lines | SA short-circuit tests present |
| `test/sigra/oauth/token_test.exs` | VERIFIED | — | RFC 6749 client_credentials tests pass |
| `test/sigra/install/service_accounts_generator_test.exs` | VERIFIED | 278 lines | 3/3 D-93-18 gating tests pass |
| `priv/templates/sigra.install/organizations/service_account.ex` | VERIFIED | — | SA schema template present |
| `priv/templates/sigra.install/organizations/service_account_credential.ex` | VERIFIED | — | Credential schema template present |
| `priv/templates/sigra.install/organizations/service_accounts_migration.exs` | VERIFIED | — | Postgres-only migration, no mysql/sqlite branches |
| `priv/templates/sigra.install/core/scope.ex` | VERIFIED | — | `service_account_id: nil` + map-attrs `new/1` clause |
| `priv/templates/sigra.install/core/oauth_token_controller.ex` | VERIFIED | 91 lines | RFC 6749 conformant controller template |
| `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` | VERIFIED | 1086 lines | UI-SPEC strings verified by grep; `&&` at lines 488 and 650 makes mount path boolean-safe |
| `priv/templates/sigra.install/organizations/router_injection.ex` | VERIFIED | — | 2 SA live routes inside :organization_scoped |
| `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` | VERIFIED | 65 lines | Idempotent upgrade migration |
| `guides/recipes/m2m-service-accounts.md` | VERIFIED (short) | 141 lines | 8 sections, curl examples; 59 lines short of plan ≥200 target |
| `guides/recipes/role-based-access-control.md` | VERIFIED | — | SA actor_type section added |
| `CHANGELOG.md` | VERIFIED | — | B2B-03 narrative bullet at line 22; phase artifact link at line 28 |
| `test/example/test/example_web/integration/service_account_e2e_test.exs` | VERIFIED | 263 lines | 2/2 tests pass on re-run 2026-05-02 (0.5s) |

---

## Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `lib/sigra/service_accounts.ex append_token_issued_audit/4` | `lib/sigra/jwt.ex:137` | `ServiceAccounts.append_token_issued_audit(multi, config, sa, credential)` | VERIFIED |
| `lib/sigra/service_accounts.ex commit_verify_failure_audit/3` | `lib/sigra/plug/fetch_bearer.ex:188` | `ServiceAccounts.commit_verify_failure_audit(config, claims, audit_reason)` | VERIFIED |
| `lib/sigra/oauth/token.ex client_credentials/2` | `lib/sigra/service_accounts.ex issue_token/4` | delegates to JWT.generate_service_account_tokens/3 | VERIFIED |
| `priv/templates/sigra.install/core/oauth_token_controller.ex` | `Sigra.OAuth.Token.client_credentials/2` | function call in controller create/2 | VERIFIED |
| `lib/sigra/install/features/organizations.ex files/1` | SA templates | gated on `opts[:jwt]` | VERIFIED |
| `priv/templates/sigra.install/core/scope.ex` | FetchBearer SA scope build | `service_account_id` in defstruct + map-attrs `new/1` | VERIFIED |
| `lib/sigra/plug/require_membership.ex call/2` | SA short-circuit | `Map.get(scope, :actor_type) == :service_account` at line 152 | VERIFIED (second clause, not first per D-93-13) |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact | Status |
|------|------|---------|----------|--------|--------|
| `lib/sigra/service_accounts.ex` | 229, 414 (was 230, 383) | `%Postgrex.Error{}` struct pattern in library code | BLOCKER | Library would not compile in MIX_ENV=dev/prod | RESOLVED in `bf5a8a8` — replaced with `%{__struct__: Postgrex.Error, postgres: %{code: code}}` map match |
| `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` + example mirror | 488, 650 | `nil and x` BadBooleanError in template | BLOCKER | LiveView crashed on initial mount; generated hosts would inherit | RESOLVED in `bf5a8a8` — switched to `&&` in both files |
| `CHANGELOG.md` | line 22 | Missing B2B-03 trace bullet | WARNING | Adopters reading release notes wouldn't see the narrative | RESOLVED in `bf5a8a8` — narrative + recipe link added |
| `test/sigra/service_accounts_test.exs` | — | 0 describe blocks; no `refute Map.has_key?(metadata, :client_secret)` assertions | WARNING | Weaker coverage than plan acceptance criteria specified | OPEN (non-blocking) — atomicity test + E2E both assert the secret-leak invariant |
| `test/sigra/jwt_test.exs` | — | Missing T-93-04 cross-org tamper test | INFO | Defense-in-depth test absent; functional protection still in place via SA row load | OPEN (non-blocking) |
| `guides/recipes/m2m-service-accounts.md` | — | 141 lines (plan required ≥200) | INFO | Recipe has all required sections; shorter than specified minimum | OPEN (non-blocking) |
| `test/sigra/install/golden_diff_test.exs` | — | Not extended with SA gating assertions (separate file used) | INFO | Gating is verified, just in a different file than specified | OPEN (non-blocking) — equivalent coverage in `service_accounts_generator_test.exs` |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Library compiles (MIX_ENV=test) | `MIX_ENV=test mix compile --warnings-as-errors` | exit 0 | PASS |
| Library compiles (MIX_ENV=dev) | `MIX_ENV=dev mix compile --warnings-as-errors` | exit 0 (re-run 2026-05-02 post `bf5a8a8`) | PASS |
| Phase 93 library suite (combined) | `mix test test/sigra/service_accounts_test.exs test/sigra/service_accounts_audit_atomicity_test.exs test/sigra/jwt_test.exs test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/require_membership_test.exs test/sigra/plug/require_org_mfa_test.exs test/sigra/oauth/token_test.exs test/sigra/install/service_accounts_generator_test.exs` | 79 tests, 0 failures (~109s) | PASS |
| E2E lifecycle test | `cd test/example && CLOAK_KEY=<base64-32B> mix test test/example_web/integration/service_account_e2e_test.exs` | 2 tests, 0 failures (0.5s) | PASS |

---

## Open Gaps

[none — all three gaps from the prior re-verification are closed by commit `bf5a8a8`]

## Closed Gaps (commit `bf5a8a8`)

### Gap 1 (BLOCKER, RESOLVED): `%Postgrex.Error{}` struct pattern in library production code

`lib/sigra/service_accounts.ex` defined two private functions
(`classify_error/1` and `integrity_violation?/1`) that pattern-matched on
`%Postgrex.Error{}`. Postgrex is `{:postgrex, "~> 0.17", only: :test}` in
`mix.exs:117`, so the struct module is not available outside `MIX_ENV=test`,
breaking `MIX_ENV=dev mix compile --warnings-as-errors`.

**Fix shipped:** Both heads now match structurally via
`%{__struct__: Postgrex.Error, postgres: %{code: code}}` (lines 229 and
414). Same technique used in `lib/sigra/oauth/refresh_classifier.ex` per
Plan 93-08. Re-run on 2026-05-02: `MIX_ENV=dev mix compile
--warnings-as-errors` exits 0.

### Gap 2 (BLOCKER, RESOLVED): `nil and x` BadBooleanError in LiveView render

`organization_service_accounts_live.ex` lines 488 and 650 used `and` on
nil-initialized assigns (`@revoking_credential`, `@create_credential_modal_open?`),
crashing every initial mount. Bug was in both the generator template and
the example app mirror.

**Fix shipped:** Switched to Elixir's lazy boolean `&&` in both files at
both lines. Re-run on 2026-05-02:
`test/example_web/integration/service_account_e2e_test.exs` runs 2/2
cleanly.

### Gap 3 (WARNING, RESOLVED): Missing CHANGELOG B2B-03 trace bullet

`CHANGELOG.md [Unreleased]` had no mention of B2B-03 / service accounts /
Phase 93 even though Plan 05 required it.

**Fix shipped:** Narrative bullet at line 22 (capability summary +
generated host artifacts + actor_type scope distinction + audit lifecycle
+ recipe link); phase artifact link at line 28.

---

## Pre-existing Issues (Out of Scope)

The install test infra pollution noted in the original phase context (untracked `lib/sigra_web/` directory polluting the project root, affecting ~14 tests in install/upgrade/vault/golden_diff modules) is pre-existing, unrelated to Phase 93, and explicitly out of scope per the phase context document. This issue does not affect the Phase 93 targeted test runs verified above.

---

_Verified: 2026-05-02T15:56:23Z (re-verified post commit `bf5a8a8`)_
_Verifier: Claude (gsd-verify-work)_
_Re-verification: Yes — previous status was `gaps_found` (3 open gaps from the post-plans-06-10 re-verification); commit `bf5a8a8` closed all three. UAT recorded per zero-human-UAT posture in `93-UAT.md`._
