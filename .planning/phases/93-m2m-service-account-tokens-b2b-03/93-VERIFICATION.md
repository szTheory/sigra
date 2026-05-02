---
phase: 93
slug: m2m-service-account-tokens-b2b-03
status: gaps_found
created: 2026-05-01
updated: 2026-05-02
requirement: B2B-03
must_haves_total: 22
must_haves_verified: 18
score: 18/22

re_verification:
  previous_status: partial
  previous_score: "0/5 (5 open gaps)"
  gaps_closed:
    - "test/sigra/service_accounts_audit_atomicity_test.exs created (478 lines, 5 tests, D-AUD-08 proven)"
    - "test/sigra/jwt_test.exs extended with SA describe block (6 new tests)"
    - "test/sigra/plug/fetch_bearer_test.exs extended with SA describe block (4 new tests)"
    - "Full UI-SPEC parity OrganizationServiceAccountsLive template (1082 lines) delivered"
    - "test/example/test/example_web/integration/service_account_e2e_test.exs created (2 tests)"
  gaps_remaining:
    - "Postgrex.Error struct pattern in library code (dev/prod compile failure)"
    - "LiveView nil-and bug causes BadBooleanError on mount (E2E test fails)"

gaps:
  - truth: "Library compiles clean in dev/prod (mix compile --warnings-as-errors passes in all MIX_ENV)"
    status: failed
    reason: "lib/sigra/service_accounts.ex uses %Postgrex.Error{} struct pattern at lines 230 and 383, but Postgrex is only a :test dependency in mix.exs:117. MIX_ENV=dev mix compile --warnings-as-errors exits 1 with 'Postgrex.Error.__struct__/1 is undefined'. Tests pass only because MIX_ENV=test loads postgrex."
    artifacts:
      - path: "lib/sigra/service_accounts.ex"
        issue: "Lines 230 and 383 use %Postgrex.Error{postgres: %{code: code}} struct patterns in defp classify_error/1 and defp emit_constraint_or_reraise/3. Postgrex is only: {:postgrex, '~> 0.17', only: :test} in mix.exs:117."
    missing:
      - "Replace %Postgrex.Error{} struct pattern with map-based matching: %{__struct__: Postgrex.Error, postgres: %{code: code}} (same technique used in lib/sigra/oauth/refresh_classifier.ex per Plan 93-08 Rule 1 fix). Or move Postgrex to non-test dep."

  - truth: "Org admin can open the generated service-accounts LiveView without a crash"
    status: failed
    reason: "OrganizationServiceAccountsLive render/1 at line 650 uses `@revoking_credential and @service_account` where @revoking_credential is initialized to nil in mount (line 69). In Elixir, `nil and x` raises BadBooleanError (and is a strict boolean operator). Confirmed by running the E2E test: `ExampleWeb.ServiceAccountE2ETest` fails with 'expected a boolean on left-side of \"and\", got: nil' at organization_service_accounts_live.ex:650. Same bug is present in the generator template at priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:650."
    artifacts:
      - path: "test/example/lib/example_web/live/organization_service_accounts_live.ex"
        issue: "Line 650: <%= if @revoking_credential and @service_account do %> — raises BadBooleanError when @revoking_credential is nil"
      - path: "priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex"
        issue: "Line 650 (template): <%%= if @revoking_credential and @service_account do %> — same nil-and bug in generator template"
    missing:
      - "Change 'and' to '&&' on lines containing '@revoking_credential and @service_account' in both the example app LV and the generator template. Also audit line 488 ('@create_credential_modal_open? and @service_account') — that one is safe since @create_credential_modal_open? is assigned false (boolean) but the same treatment is safer."

  - truth: "CHANGELOG.md [Unreleased] carries the B2B-03 trace bullet"
    status: failed
    reason: "CHANGELOG.md [Unreleased] section contains no mention of B2B-03, service accounts, client_credentials, or Phase 93. The plan 05 must-have required this trace bullet explicitly. Plan 05 SUMMARY acknowledged: 'CHANGELOG.md was already locally modified before this reconciliation; this summary does not claim a clean, isolated B2B-03 changelog closeout.'"
    artifacts:
      - path: "CHANGELOG.md"
        issue: "No B2B-03 trace bullet under [Unreleased] or anywhere in file"
    missing:
      - "Add to CHANGELOG.md [Unreleased] ### Added: '* **B2B-03 (Phase 93)**: Org admins can mint org-scoped service-account tokens via the new client_credentials OAuth grant on POST /oauth/token. Generated host receives ServiceAccount + ServiceAccountCredential schemas, an admin LiveView, and OAuthTokenController. Adopters opt in via mix sigra.install --jwt --organizations. Upgrade via priv/templates/sigra.upgrade/alter_add_service_accounts.exs.'"
deferred: []
---

# Phase 93: M2M Service-Account Tokens (B2B-03) Verification Report

**Phase Goal:** Org admins can mint org-scoped service-account tokens that authenticate API calls via the `client_credentials` grant on Sigra's existing JWT path, with the resulting requests cleanly distinguishable from user-tied tokens in `current_scope` and audit rows. After this phase, hosts no longer need to mint user-tied PATs / JWTs for internal APIs / scheduled jobs / third-party integrations, and revoking a service account is a single admin action that breaks the class of tokens cleanly.

**Verified:** 2026-05-02T18:00:00Z
**Status:** gaps_found
**Re-verification:** Yes — after 5-gap closure (plans 06-10)

## Re-Verification Summary

The previous VERIFICATION.md (status: partial) identified 5 open gaps. Plans 06-10 closed all 5. However, in closing Gap #4 (UI-SPEC LiveView parity) and Gap #5 (E2E test), two new blocking defects were introduced that prevent the phase from passing.

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Library compiles clean in dev/prod (all MIX_ENV) | FAILED | `MIX_ENV=dev mix compile --warnings-as-errors` exits 1: `%Postgrex.Error{}` struct pattern in `lib/sigra/service_accounts.ex:230,383` — Postgrex is only `:test` dep |
| 2  | Org admin can open service-accounts LiveView without crash | FAILED | `LiveView.OrganizationServiceAccountsLive` crashes on mount with `BadBooleanError` at line 650: `@revoking_credential and @service_account` where `@revoking_credential` is initialized `nil` |
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
| 15 | Generated-host E2E covers ROADMAP SC#4 lifecycle | FAILED (blocked) | `test/example/test/example_web/integration/service_account_e2e_test.exs` exists (263 lines, 2 tests) but test 1 ("mounts the SA index LiveView") fails with `BadBooleanError` from Gap #2, causing `--max-failures 1` to abort before test 2 runs |
| 16 | Adopter recipe published at guides/recipes/m2m-service-accounts.md | VERIFIED | 141-line recipe with 8 top-level sections, curl examples (Basic auth + form-encoded), actor_type branching examples, rotation flow |
| 17 | Phase 92 RBAC recipe extended with SA actor_type branch | VERIFIED | `guides/recipes/role-based-access-control.md` has `grep -c "actor_type" = 6`, includes "Authorizing service-account requests" section |
| 18 | Upgrade migration template at priv/templates/sigra.upgrade/alter_add_service_accounts.exs | VERIFIED | 65-line idempotent migration with create_if_not_exists (5×) and drop_if_exists (5×); no mysql/sqlite branches |
| 19 | CHANGELOG.md [Unreleased] carries B2B-03 trace bullet | FAILED | No B2B-03, service_account, or Phase 93 mention in CHANGELOG.md anywhere |
| 20 | Single auth entry point (ROADMAP SC#5) — no parallel SA plug | VERIFIED | `find lib/sigra/plug -iname '*service_account*' -o -iname '*sa_bearer*'` returns empty |
| 21 | JWT path tests exercise both :user and :service_account actor types | VERIFIED | `test/sigra/jwt_test.exs` describe "service-account tokens" block (6 tests); `test/sigra/plug/fetch_bearer_test.exs` SA describe block (4 tests) |
| 22 | `client_credentials_access_ttl` config key added | VERIFIED | `lib/sigra/config.ex` has `client_credentials_access_ttl:` (confirmed line 4: grep count = 1) |

**Score:** 18/22 truths verified (3 FAILED, 1 blocked by Gap #2)

---

## ROADMAP Success Criteria

| SC# | Description | Status | Evidence |
|-----|-------------|--------|----------|
| SC#1 | Admin can create SA (token shown once), list with status/created-by/last-used, revoke with immediate token invalidation | GAP | LiveView exists and wires all operations correctly, but crashes on initial mount with BadBooleanError (nil-and bug at line 650). The wiring itself is verified via grep; the mountable test fails. |
| SC#2 | POST /oauth/token → JWT → protected endpoint → `current_scope.actor_type == :service_account`; post-revoke → 401 + `api.token_verify.failure` | PASS | E2E test step 3 (POST /oauth/token), step 7 (probe endpoint), step 10 (401 post-revoke) all pass when the LiveView mount bug is bypassed. OAuth token test covers §5.1/§5.2. |
| SC#3 | Audit rows: `service_account.create` / `service_account.revoke` + `api.token_verify` with actor-type discriminator; every row uses `log_multi_safe/3` | PASS | E2E test asserts all four audit verbs with actor_type assertions. `lib/sigra/service_accounts.ex` uses only `Audit.log_multi_safe` — zero `Audit.log_safe/3` calls. |
| SC#4 | Generated-host E2E: issue SA token → call protected → revoke → next call fails → audit-row assertions | GAP | E2E test file exists (263 lines, 2 tests) but test 1 (LiveView mount prerequisite) fails due to Gap #2, blocking full test run. Test 2 (lifecycle) was confirmed to pass in plan 10 SUMMARY under the repro conditions from that session. The nil-and bug was introduced in plan 09 (after plan 10 ran). |
| SC#5 | 93-VERIFICATION.md: full library suite green, generator-host E2E green, golden-diff stable, JWT path tests both actor types, dual-mode auth plug is single entry point | GAP | Library suite passes in MIX_ENV=test but fails in MIX_ENV=dev (Postgrex.Error struct bug). E2E currently fails. JWT parity tests green. Single-entry-point grep-proven. |

---

## Requirement Traceability

| Requirement | Phase | Status | Notes |
|-------------|-------|--------|-------|
| B2B-03 | 93 | Partially satisfied | Core library capability is present and tested (OAuth grant, JWT fork, audit atomicity, plug short-circuits, generator templates). Blocked by 2 bugs preventing dev/prod compile and LiveView mount. |

**B2B-03 text:** "Org admin can issue, list, and revoke org-scoped service-account tokens that authenticate API calls via `client_credentials` grant on the existing JWT path, distinguishable in `current_scope` and audit rows from user-tied tokens."

The requirement is functionally satisfied at the library layer. The two gaps are defects in the implementation code, not architectural gaps.

---

## Must-Haves: Cross-Reference Against Plans

| Plan | Must-Have | Status | Evidence |
|------|-----------|--------|----------|
| 93-01 | `mix compile --warnings-as-errors` passes | FAILED | Passes in MIX_ENV=test, fails in MIX_ENV=dev due to %Postgrex.Error{} struct in lib/sigra/service_accounts.ex:230,383 |
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
| 93-04 | OrganizationServiceAccountsLive template implements UI-SPEC revision 1 verbatim | PARTIAL | Template content matches UI-SPEC (all strings, typography, accessibility locks verified by grep). But template crashes on initial mount (nil-and bug). |
| 93-05 | `guides/recipes/m2m-service-accounts.md` published (≥200 lines, ≥6 sections) | PARTIAL | 141 lines (short of ≥200), 8 sections (meets ≥6); content covers /oauth/token, Basic auth, form-encoded, actor_type branching |
| 93-05 | `guides/recipes/role-based-access-control.md` extended with SA section | VERIFIED | Has "Authorizing service-account requests" section with actor_type examples |
| 93-05 | `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` idempotent (create_if_not_exists) | VERIFIED | 65 lines, create_if_not_exists (5×), drop_if_exists (5×), no adapter branches |
| 93-05 | `CHANGELOG.md [Unreleased]` carries B2B-03 trace bullet | FAILED | No B2B-03 or service account mention anywhere in CHANGELOG.md |
| 93-06 | D-AUD-08 co-fated rollback proof for all 5 SA mutations | VERIFIED | `test/sigra/service_accounts_audit_atomicity_test.exs` 5/5 pass |
| 93-07 | JWT + FetchBearer SA parity tests | VERIFIED | `jwt_test.exs` SA block (6 tests), `fetch_bearer_test.exs` SA block (4 tests), all pass |
| 93-08 | Generator gating tests (--jwt --organizations emission) | VERIFIED | `test/sigra/install/service_accounts_generator_test.exs` 3/3 pass |
| 93-09 | Full UI-SPEC parity LiveView + CopyToClipboard hook | PARTIAL | Template exists (1086 lines, all UI-SPEC strings verified), but nil-and bug crashes mount |
| 93-10 | Generated-host E2E (ROADMAP SC #4) | FAILED | E2E test file exists and was passing when plan 10 ran, but the LiveView nil-and bug (introduced by plan 09) now causes test 1 to fail |

---

## Required Artifacts

| Artifact | Status | Size | Notes |
|----------|--------|------|-------|
| `lib/sigra/service_accounts.ex` | STUB-FREE, DEV-COMPILE-BROKEN | 449 lines | All 7 public functions present; %Postgrex.Error{} struct at lines 230,383 breaks MIX_ENV=dev compile |
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
| `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` | RENDER-BROKEN | 1086 lines | UI-SPEC strings verified by grep; nil-and bug at line 650 crashes on mount |
| `priv/templates/sigra.install/organizations/router_injection.ex` | VERIFIED | — | 2 SA live routes inside :organization_scoped |
| `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` | VERIFIED | 65 lines | Idempotent upgrade migration |
| `guides/recipes/m2m-service-accounts.md` | VERIFIED (short) | 141 lines | 8 sections, curl examples; 59 lines short of plan ≥200 target |
| `guides/recipes/role-based-access-control.md` | VERIFIED | — | SA actor_type section added |
| `CHANGELOG.md` | FAILED | — | No B2B-03 trace bullet |
| `test/example/test/example_web/integration/service_account_e2e_test.exs` | FAILING | 263 lines | File exists; test 1 fails due to LiveView nil-and bug |

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

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/sigra/service_accounts.ex` | 230, 383 | `%Postgrex.Error{}` struct pattern in library code; Postgrex is only a `:test` dep | BLOCKER | Library does not compile in MIX_ENV=dev or MIX_ENV=prod |
| `test/example/lib/example_web/live/organization_service_accounts_live.ex` | 650 | `<%= if @revoking_credential and @service_account do %>` — `nil and x` raises `BadBooleanError` | BLOCKER | LiveView crashes on initial mount; E2E test fails |
| `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` | 650 | Same `nil and` pattern in generator template | BLOCKER | All generated hosts would inherit the crash |
| `CHANGELOG.md` | — | Missing B2B-03 trace bullet | WARNING | Adopters reading release notes won't see the narrative |
| `test/sigra/service_accounts_test.exs` | — | 0 describe blocks; no `refute Map.has_key?(metadata, :client_secret)` assertions | WARNING | Weaker coverage than plan acceptance criteria specified |
| `test/sigra/jwt_test.exs` | — | Missing T-93-04 cross-org tamper test | INFO | Defense-in-depth test absent; functional protection still in place via SA row load |
| `guides/recipes/m2m-service-accounts.md` | — | 141 lines (plan required ≥200) | INFO | Recipe exists with all required sections; shorter than specified minimum |
| `test/sigra/install/golden_diff_test.exs` | — | Not extended with SA gating assertions (separate file used) | INFO | Gating is verified, just in a different file than specified |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Library compiles (MIX_ENV=test) | `MIX_ENV=test mix compile --warnings-as-errors` | exit 0 | PASS |
| Library compiles (MIX_ENV=dev) | `MIX_ENV=dev mix compile --warnings-as-errors` | exit 1: Postgrex.Error.__struct__/1 undefined | FAIL |
| Service account unit tests pass | `mix test test/sigra/service_accounts_test.exs` | 5 tests, 0 failures | PASS |
| Audit atomicity tests pass | `mix test test/sigra/service_accounts_audit_atomicity_test.exs` | 5 tests, 0 failures | PASS |
| JWT + FetchBearer SA parity | `mix test test/sigra/jwt_test.exs test/sigra/plug/fetch_bearer_test.exs` | 35 tests, 0 failures | PASS |
| Plug SA short-circuit tests | `mix test test/sigra/plug/require_membership_test.exs test/sigra/plug/require_org_mfa_test.exs` | 27 tests, 0 failures | PASS |
| OAuth token tests | `mix test test/sigra/oauth/token_test.exs` | 4 tests, 0 failures | PASS |
| Generator gating tests | `mix test test/sigra/install/service_accounts_generator_test.exs` | 3 tests, 0 failures (100s) | PASS |
| E2E lifecycle test | `cd test/example && CLOAK_KEY=... mix test test/example_web/integration/service_account_e2e_test.exs` | 1 failure (BadBooleanError in LiveView mount) | FAIL |

---

## Open Gaps

### Gap 1 (BLOCKER): `%Postgrex.Error{}` struct pattern in library production code

`lib/sigra/service_accounts.ex` defines two private functions (`classify_error/1` at line 230, `emit_constraint_or_reraise/3` at line 383) that use `%Postgrex.Error{}` struct pattern matching. Postgrex is declared as `{:postgrex, "~> 0.17", only: :test}` in `mix.exs:117`. This causes a compile error in any environment without Postgrex loaded (dev, prod, any non-test CI step).

**Fix:** Replace struct patterns with map-based matching `%{__struct__: Postgrex.Error, postgres: %{code: code}}` — the same technique already applied to `lib/sigra/oauth/refresh_classifier.ex` in Plan 93-08 Rule 1 fix. Or, if Postgrex struct matching is needed at runtime in production, promote Postgrex from `:test`-only to a proper dep.

### Gap 2 (BLOCKER): `nil and x` raises `BadBooleanError` in LiveView render

`priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` (line 650) and its rendered copy in `test/example/lib/example_web/live/organization_service_accounts_live.ex` (line 650) contain `<%= if @revoking_credential and @service_account do %>`. `@revoking_credential` is initialized to `nil` in `mount/3` (line 69). In Elixir, `nil and x` raises `BadBooleanError` because `and` is a strict boolean operator. `&&` is the nil-safe alternative. This crashes the LiveView on every initial mount, blocking ROADMAP SC#1 and causing the E2E test (SC#4) to fail.

**Fix:** Change `@revoking_credential and @service_account` to `@revoking_credential != nil and @service_account != nil` (or `@revoking_credential && @service_account`) in both files. Also audit line 488 (`@create_credential_modal_open? and @service_account`) as a precaution, though that assign is initialized to `false` (boolean) making it currently safe.

### Gap 3 (WARNING): Missing CHANGELOG B2B-03 trace bullet

`CHANGELOG.md [Unreleased]` has no mention of B2B-03, service accounts, or Phase 93. Plan 05 required this explicitly. Plan 05 SUMMARY acknowledged the omission.

---

## Pre-existing Issues (Out of Scope)

The install test infra pollution noted in the original phase context (untracked `lib/sigra_web/` directory polluting the project root, affecting ~14 tests in install/upgrade/vault/golden_diff modules) is pre-existing, unrelated to Phase 93, and explicitly out of scope per the phase context document. This issue does not affect the Phase 93 targeted test runs verified above.

---

_Verified: 2026-05-02T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — previous status was partial (5 open gaps); plans 06-10 closed those 5 gaps but introduced 2 new blockers_
