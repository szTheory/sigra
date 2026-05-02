---
phase: 93-m2m-service-account-tokens-b2b-03
plan: "07"
subsystem: jwt-service-account-parity-tests
tags: [jwt, fetch-bearer, service-accounts, parity-tests, gap-closure, b2b-03]

dependency_graph:
  requires:
    - 93-01 (lib/sigra/jwt.ex SA branch implementation)
    - 93-02 (lib/sigra/plug/fetch_bearer.ex SA fork implementation)
  provides:
    - Gap #2 from 93-VERIFICATION.md closed
    - test/sigra/jwt_test.exs SA describe block (6 new tests)
    - test/sigra/plug/fetch_bearer_test.exs SA describe block (4 new tests)
  affects:
    - ROADMAP SC #5 (single auth entry point — now covered by parity tests)

tech_stack:
  added: []
  patterns:
    - Pattern B synthetic-UUID scopes for SA mutations under Mox-mocked repo
    - Inline SAMockRepo (Process.put/get) for FetchBearer SA tests without Postgres dep
    - Inline SATestOrganizations stub for load_organization/2 to return non-nil org

key_files:
  modified:
    - test/sigra/jwt_test.exs
    - test/sigra/plug/fetch_bearer_test.exs

decisions:
  - "`verify_service_account_epoch` returns `{:error, :epoch_mismatch}` for ALL SA verify failures (revoked SA, revoked credential, expired credential, epoch drift) — a single error atom, not separate atoms per failure mode. Tests reflect this contract."
  - "FetchBearer requires a non-nil `organizations_module` for `load_organization` to return an organization struct. Without it, `build_jwt_scope` returns nil even for valid SA tokens. Inline `SATestOrganizations` stub added to enable scope building in tests."
  - "`generate_service_account_tokens/3` returns `{access_token, refresh_token: nil, expires_in}` — the `:refresh_token` key IS present but nil (not absent). The D-93-07 no-refresh-token lock asserts `Map.get(response, :refresh_token) == nil` rather than `refute Map.has_key?`."
  - "Pattern B (synthetic UUID scopes) used throughout — parent test modules are Mox-mocked at repo layer; FK integrity on actor_id is never validated, making synthetic UUIDs appropriate and correct."

metrics:
  duration_minutes: 25
  completed_date: "2026-05-02"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
  tests_added: 10
  tests_total_after: 35
---

# Phase 93 Plan 07: JWT + FetchBearer Service-Account Parity Tests Summary

**One-liner:** SA-branch parity tests added to `jwt_test.exs` (6 tests: generate, D-93-10 claims, verify, epoch_mismatch, credential-revoke, user-path guard) and `fetch_bearer_test.exs` (4 tests: scope-build, no-membership, expired-token, user-path guard), closing 93-VERIFICATION.md Gap #2.

## What Was Built

### Task 1: test/sigra/jwt_test.exs — describe "service-account tokens"

Added a `describe "service-account tokens"` block with **6 new tests** (file grew from 358 lines to 646 lines, 288 insertions):

1. `generate_service_account_tokens/3 returns {:ok, %{access_token, expires_in, scopes}} with no refresh_token` — asserts success tuple shape and D-93-07 (refresh_token: nil)
2. `service-account access token contains actor_type, service_account_id, credential_id, org_id, scopes, epoch, sub claims` — full D-93-10 claims verification via `verify_access/2`
3. `verify_access/2 returns {:ok, claims} for a fresh SA token (parity with user path)` — round-trip happy path
4. `verify_access/2 returns {:error, :epoch_mismatch} after Sigra.ServiceAccounts.revoke/3 bumps token_epoch` — D-93-12 atomic revocation invalidates live tokens
5. `verify_access/2 fails after Sigra.ServiceAccounts.revoke_credential/3 (per-credential revoke)` — per-credential revocation invalidates tokens
6. `user JWT path is unaffected (parity regression guard)` — explicit parity invariant pin

Also added inline `SASchema`, `CredentialSchema` modules, and `sa_config/1`, `make_sa/1`, `make_credential/2` helpers.

Pattern B synthetic-UUID scopes used for all `ServiceAccounts.revoke/3` and `revoke_credential/3` calls (required by `ensure_user_scope!/2` at `lib/sigra/service_accounts.ex:347`).

### Task 2: test/sigra/plug/fetch_bearer_test.exs — describe "call/2 service-account JWT path"

Added a `describe "call/2 service-account JWT path"` block with **4 new tests** (file grew from 215 lines to 515 lines, 300 insertions):

1. `valid SA JWT builds scope with actor_type: :service_account, service_account_id populated, user: nil` — D-93-04 lock on plug-built scope
2. `valid SA JWT does NOT populate :membership (single auth entry-point invariant — ROADMAP SC #5)` — proves no membership lookup on SA path
3. `expired SA JWT assigns current_scope: nil` — verify failure yields nil scope
4. `valid user JWT still builds a user scope (parity regression guard)` — user path unchanged

Inline support modules added:
- `SAScopeSchemas` — ServiceAccount, Credential, Organization, User Ecto schemas
- `SATestOrganizations` — `__sigra_org_config__/0` stub enabling `load_organization/2` to return a non-nil org
- `SAMockRepo` — Process.put/get-based in-process mock (avoids Postgres dep for FetchBearer tests)

## Deviations from Plan

### Auto-discovered Implementation Facts

**1. [Rule 2 - Implementation Contract] verify_service_account_epoch returns single error atom**
- **Found during:** Task 1 implementation (reading lib/sigra/jwt.ex lines 478-500)
- **Issue:** The plan suggested both `:credential_revoked` and `:epoch_mismatch` as possible atoms. The actual implementation uses a single `if` condition checking all SA revoke conditions together (`service_account.revoked_at == nil and credential.revoked_at == nil and not credential_expired? and service_account_epoch == claim_epoch`), returning `{:error, :epoch_mismatch}` for all failures.
- **Fix:** Test 5 (credential-revoked) asserts `{:error, _atom}` rather than a specific atom, per the plan's "read the actual file to confirm" instruction. Comment in code documents this.

**2. [Rule 2 - Implementation Contract] generate_service_account_tokens returns refresh_token: nil key**
- **Found during:** Task 1 (first test run)
- **Issue:** Return map is `%{access_token: jwt, refresh_token: nil, expires_in: ttl}` — the `:refresh_token` key IS present (with nil value). The plan skeleton used `Map.has_key?` with `refute`, which would fail.
- **Fix:** Test 1 asserts `Map.get(response, :refresh_token) == nil` instead of `refute Map.has_key?`.

**3. [Rule 2 - Implementation Contract] FetchBearer requires organizations_module for SA scope**
- **Found during:** Task 2 design (reading fetch_bearer.ex load_organization/2)
- **Issue:** `build_jwt_scope` for SA tokens requires `%_{} = organization <- load_organization(config, claims["org_id"])`. Without `organizations_module`, `load_organization` returns nil and the whole `with` returns nil (nil scope). The plan noted we need `active_organization.id` assertion.
- **Fix:** Added inline `SATestOrganizations` module with `__sigra_org_config__/0` returning the org schema. Added to `sa_jwt_config/0` as `organizations_module:`.

## Known Stubs

None. All assertions target real library code paths with no mock data flowing to UI rendering.

## Threat Flags

None. These are test files only; no new production code was added.

## Self-Check: PASSED

- test/sigra/jwt_test.exs: FOUND
- test/sigra/plug/fetch_bearer_test.exs: FOUND
- 93-07-SUMMARY.md: FOUND
- Commit 7110c24 (Task 1): FOUND
- Commit be6aaec (Task 2): FOUND
