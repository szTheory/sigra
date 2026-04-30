# Phase 93: M2M / service-account tokens (B2B-03) — Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>

## Phase Boundary

Org admins can mint org-scoped service-account (SA) credentials and exchange them for short-lived JWT access tokens via RFC 6749 `client_credentials` grant on `POST /oauth/token`. Resulting requests are cleanly distinguishable from user-tied tokens at every layer — `current_scope.actor_type == :service_account`, `scope.user == nil`, `scope.service_account_id` populated, `audit_events.actor_type == "service_account"`. Revoking an SA breaks the entire class of live tokens atomically (per-SA `token_epoch` claim); revoking a single credential breaks tokens minted against that credential only. The dual-mode `Sigra.Plug.FetchBearer` remains the single auth entry point — no parallel pipeline.

**Explicitly out of scope:**
- Other RFC 6749 grants (`password`, `authorization_code`, `device_code`) — `/oauth/token` dispatches on `grant_type` and returns `unsupported_grant_type` for anything other than `client_credentials` in v1.21.
- Migrating `/api/auth/token` (Sigra-specific email+password JWT login) under `/oauth/token` — left untouched in v1.21 to avoid adopter churn. Future v1.x phase if requested.
- SA-to-SA delegation / impersonation.
- Custom claims-builder behaviour for SAs (planner uses existing `Sigra.JWT.ClaimsBuilder` shape, parameterized — discretion).
- Webhooks for SA lifecycle events (deferred to v1.22 webhooks milestone).
- Per-credential `token_epoch` (SA epoch + per-credential `revoked_at` lookup is sufficient — see D-93-12).
- PKCE / proof-of-possession for SA — `client_credentials` per RFC 6749 §4.4 does not require PKCE.
- A dedicated `Sigra.Plug.FetchServiceAccountBearer` parallel pipeline — explicitly forbidden by ROADMAP SC #5.
- `aud` (audience) claim on SA JWTs — RFC 9068 recommends but existing user JWTs don't carry it; planner discretion to add or defer.

</domain>

<decisions>

## Implementation Decisions

### Service-account principal & scope shape

- **D-93-01 — Separate `service_accounts` principal table, NOT synthetic users.** New table `service_accounts(id, organization_id, name, scopes :map, role :string null, revoked_at, last_used_at, token_epoch, created_by_user_id, inserted_at, updated_at)`. Org-scoped (FK to `organizations.id`). Owned by `Sigra.Install.Features.Organizations` generator feature. Industry-unanimous (GitHub Apps, Auth0 M2M, Okta Service Apps); GitLab's regret with bot-user-rows for project access tokens is the explicit cautionary tale. Rejected: synthetic `User` row in `users` table (pollutes `User.list/0`, requires nullable email, makes `audit_events.actor_id` ambiguous, GitLab forum thread documents years of patches for "bot users don't have access to internal projects" / "treat PATs as external users").

- **D-93-02 — Multi-credential shape: separate `service_account_credentials` join table.** Schema: `service_account_credentials(id, service_account_id, client_id :string unique, hashed_client_secret :string, expires_at :utc_datetime null, last_used_at, revoked_at, inserted_at, updated_at)`. SA identity is stable; credentials are rotatable independently. AWS IAM (2 keys/role for rotation), Google Cloud SA (up to 10 keys/SA), Okta Service Apps (2 client_secrets), Auth0 M2M all converged on this shape because enterprise rotation requires overlap (mint new → deploy → revoke old). Migrating from "SA = credential" later is a destructive token-epoch reshuffle. Rejected: single-credential-per-row PAT shape (forces destructive revoke+recreate for rotation; loses audit lineage; every B2B adopter shipping into a security review hits this as a blocker). v1.21 ships the schema correctly (two tables, "create credential" button on SA detail page, secret revealed once); polish defers to v1.3+.

- **D-93-03 — OAuth-native `client_id` + `client_secret` pair, NOT PAT-style single bearer.** RFC 6749 §4.4 + §2.3.1 require `client_id` + `client_secret` for `client_credentials` grant. PAT-style would force Sigra to invent a non-standard auth mechanism for `/oauth/token`. `client_id` format: prefixed (`sigra_sa_<24chars>`) reusing the `prefix` config that drives existing API tokens — planner picks exact byte counts. `client_secret`: 32-byte random, SHA-256 hashed at rest via existing `Sigra.Token.generate_hashed_token/0` + `Sigra.Token.hash_token/1`. Both shown exactly once in admin LiveView at credential creation; never readable again. Rejected: PAT-style single bearer (breaks RFC 6749 conformance; no path to `Authorization: Basic` client auth).

- **D-93-04 — `scope.user = nil` + new `scope.service_account_id` field; tagged-union via existing `:actor_type`.** `Sigra.Scope` and the generated scope template already reserve `:actor_type` (Phase 92). Phase 93 adds `:service_account_id` to both `lib/sigra/scope.ex` and `priv/templates/sigra.install/core/scope.ex`. For SA requests: `scope.user = nil`, `scope.user_id = nil`, `scope.actor_type = :service_account`, `scope.service_account_id = <id>`, `scope.active_organization = <org>`. Forces explicit `case scope.actor_type do :user -> ...; :service_account -> ... end` branching. Pre-Phase-93 host code that does `scope.user.id` raises `KeyError` immediately (loud failure, the Sigra value prop). Spring Security's `Authentication.getPrincipal :: Object` polymorphism, Devise+Doorkeeper's separate `current_resource_owner` helper, and GitHub's migration AWAY from machine-users to GitHub Apps all support this stance. GitLab's project-access-token "bot user" approach is the documented anti-pattern. Add `Sigra.Scope.user_id/1` helper returning `scope.user && scope.user.id` for sites that genuinely don't care about actor type (audit/logging convenience). Rejected: synthetic `%User{}` in `scope.user` (silent-nil bugs at `scope.user.email` propagate into emails, audit logs, password-reset flows; GitLab regret is the cautionary tale).

### OAuth `/oauth/token` endpoint

- **D-93-05 — New RFC 6749-shaped `/oauth/token` controller; existing `/api/auth/token` untouched.** New generated controller at `priv/templates/sigra.install/core/oauth_token_controller.ex`, route `POST /oauth/token` mounted in core router_injection. Form-encoded body (`application/x-www-form-urlencoded`). Client auth supports BOTH RFC 6749 §2.3.1 mechanisms: `Authorization: Basic base64(client_id:client_secret)` (REQUIRED to support per spec) AND form fields `client_id` + `client_secret` (allowed, "NOT RECOMMENDED" per spec but ubiquitous in real SDKs). Success response per §5.1: `200`, `Content-Type: application/json`, `Cache-Control: no-store`, body `{"access_token", "token_type": "Bearer", "expires_in", "scope"}`. Error response per §5.2: `400` (or `401` for `invalid_client`) with `{"error", "error_description"?}` where `error ∈ invalid_request | invalid_client | invalid_grant | unauthorized_client | unsupported_grant_type | invalid_scope`. The existing `/api/auth/token` (Sigra-specific email+password JWT login) stays unchanged — adopters' flows are unaffected. Rejected: extending `/api/auth/token` with `grant_type` dispatch (breaks existing adopter contract; conflates Sigra-shaped login with RFC 6749 conformance).

- **D-93-06 — `grant_type` dispatch from day one; `client_credentials` only in v1.21.** Controller's `create/2` matches on `params["grant_type"]`: `"client_credentials"` → SA flow; everything else → 400 with `{"error": "unsupported_grant_type"}`. Zero added complexity for v1.21 (one `case` clause), keeps the door open for `password` grant migration and `refresh_token` grant in future v1.x without breaking changes.

- **D-93-07 — No refresh tokens for `client_credentials`.** RFC 6749 §4.4.3: "A refresh token SHOULD NOT be included." Auth0, Okta, AWS STS, Google Cloud all conform. SA gets only `access_token`; client re-POSTs to `/oauth/token` when JWT expires. Existing `Sigra.JWT.RefreshToken` module is NOT extended (user-only). Rejected: opaque refresh tokens for SAs (RFC violation; Auth0 docs explicitly call this out as a foot-gun).

- **D-93-08 — JWT access-token TTL: 3600s (1h) default; separate config key.** Config: `jwt: [client_credentials_access_ttl: 3600, ...]` alongside the existing `:access_ttl` (which stays 900s for users). Industry consensus (Auth0 M2M, Okta Service Apps, Google Cloud SA, GitHub installation tokens, AWS STS AssumeRole all default 3600s); halves network round-trips vs 900s for hourly batch jobs (the canonical M2M workload); 4× lower audit volume than 900s for `service_account.token_issued` rows (D-93-19); SA `token_epoch` claim (D-93-12) keeps revocation atomic regardless of TTL — leaked-token blast radius is `min(TTL, time_until_epoch_bump)`. Rejected: 900s match-user (surprises B2B integrators in a "why does Sigra burn 4× more tokens than Auth0/Okta/GCP?" way; no security upside given epoch); 24h Auth0-style permissive (unusual for a security-forward lib; weakens posture without DX upside given epoch already exists).

### JWT claims shape

- **D-93-09 — JWT `sub` claim: SA's `client_id` (matches OAuth ecosystem convention).** RFC 9068 §2.2 says `sub` should identify the principal; for `client_credentials` grants, `sub == client_id` is the de-facto industry convention (Auth0, Okta, AWS Cognito). Stored in claims as `"sub" => credential.client_id`. The `service_account_id` is also threaded as a separate claim (D-93-10) so verification doesn't need a `client_id → service_account_id` lookup.

- **D-93-10 — JWT carries `service_account_id`, `credential_id`, `org_id`, `scopes`, `epoch`, `actor_type` claims.** Claims map: `%{"sub" => client_id, "iat", "exp", "jti", "iss", "scopes" => [...], "epoch" => sa.token_epoch, "actor_type" => "service_account", "service_account_id" => sa.id, "credential_id" => credential.id, "org_id" => sa.organization_id}`. `FetchBearer` JWT branch reads these directly to build scope without DB lookups beyond the SA + credential rows that revocation/epoch checks need anyway. Planner discretion: whether to add `aud` per RFC 9068 (existing user JWTs don't have it; symmetry argues skip, future-proofing argues include — defer to planner).

### Plug & scope hydration

- **D-93-11 — `Sigra.Plug.FetchBearer` JWT branch forks on `claims["actor_type"]`; no new plug, no parallel pipeline.** Single new code path inside `do_fetch/2`'s JWT clause: when `claims["actor_type"] == "service_account"`, build scope via `Sigra.Scope.build(scope_module, nil, actor_type: :service_account, service_account_id: claims["service_account_id"], active_organization: <org_lookup>, role: <sa.role>)`. The user path is untouched. Active-organization is populated DIRECTLY at FetchBearer time from `claims["org_id"]` — no `Sigra.Scope.Hydration.hydrate/3` extension (hydration is user-membership-shaped; SA has no membership). Honors ROADMAP SC #5 (single auth entry point). Rejected: `Sigra.Plug.FetchServiceAccountBearer` parallel plug (explicitly forbidden); extending `Scope.Hydration` with SA branches (couples hydration to actor type — leaky abstraction).

- **D-93-12 — Revocation: per-SA `token_epoch` field + per-credential `revoked_at` lookup.** SA-level `token_epoch :integer` mirrors `users.token_epoch` (locked from `lib/sigra/jwt.ex` line 375). Revoking the SA bumps `token_epoch` AND sets `revoked_at` in one Multi → all live JWTs invalidate immediately (epoch claim mismatch). Revoking a single credential sets `service_account_credentials.revoked_at` → JWTs minted against that credential fail verify (credential row read at verify time; needed anyway for `revoked_at IS NULL` check). Rejected: per-credential `token_epoch` (over-engineered; per-credential `revoked_at` is sufficient because credential row is loaded at verify time anyway); pure `revoked_at` lookup at SA level (loses atomic O(1) revocation symmetry with user pattern; no upside given the field is one column).

- **D-93-13 — `Sigra.Plug.RequireMembership` short-circuits on `actor_type == :service_account`.** Top-of-function guard returns conn unchanged when `scope.actor_type == :service_account`. SA's `organization_id` IS the implicit membership; no `OrganizationMembership` row lookup. Mirrors Phase 91 D-91-07's pre-declared `RequireOrgMfa` short-circuit. Rejected: synthesizing a fake `%OrganizationMembership{}` struct (pollutes `Organizations.get_membership/3` query path with synthetic rows; couples SA-awareness into membership query paths).

- **D-93-14 — `Sigra.Plug.RequireOrgMfa` short-circuit (locked from Phase 91 D-91-07).** Phase 91 pre-declared this; Phase 93 implements the 3-line guard at top of `RequireOrgMfa.call/2`. SAs are exempt from member-MFA enforcement — they're a separate actor class.

- **D-93-15 — `scope.role` for SA: populated from optional `service_accounts.role :string null` column.** Hosts who use Phase 92's RBAC seam can set `service_account.role = :ci_bot` (or any host-defined atom) and have `MyApp.SigraAuthz.can?/3` route on it the same way it routes on user/membership roles. Generated SA admin LiveView shows a role dropdown populated from `__sigra_org_config__()[:roles]` (same source the member admin uses). When `nil`, `scope.role` is `nil` for the SA — Phase 92's deny-by-default `can?/3` still gets actor_type to discriminate. Rejected: always-nil for SA `scope.role` (forces hosts to duplicate role logic in `can?/3` actor_type branches; loses Phase 92 RBAC reuse for B2B adopters who want "the CI bot has the deployer role").

### Admin LiveView surface

- **D-93-16 — Dedicated `/organizations/:slug/service-accounts` LiveView.** New `OrganizationServiceAccountsLive` module at `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex`, sidebar entry alongside Members and Settings. Index view: list service accounts with name, status (active/revoked), created-by, last-used-at columns (per ROADMAP SC #1). Detail view (or modal): list credentials for that SA with client_id, expires_at, last_used_at, revoked_at columns, plus "Create credential" button. Create credential action: form with optional `expires_at` → on success, modal showing `client_id` + `client_secret` exactly once with explicit "I've saved this credential" confirm. Revoke SA: inline button with confirm modal, sets `revoked_at` + bumps `token_epoch` in one Multi. Revoke credential: sets credential `revoked_at` only. Rejected: nesting under `/organizations/:slug/settings` (settings page is already crowded post-Phase 91 with General, Slug, Security, Danger Zone).

- **D-93-17 — Sudo gates on create + revoke (BOTH SA and credential level).** User API token precedent (`api_token_controller.ex:13`) requires sudo on create only. SA-class operations are stronger: revoke is class-level (breaks all live consumers immediately) and credentials are org-scoped/long-lived — that warrants the friction. Sudo required for: create SA, revoke SA, create credential, revoke credential. List/view operations don't require sudo. Rejected: sudo on create only matching user PAT pattern (revoke is the higher-blast-radius action here).

- **D-93-18 — Generator gating: `--organizations` AND `--jwt` both required.** Generator emits SA artifacts only when both feature flags are on. If either is off, all SA artifacts (schemas, migration, controller, LiveView, recipe) are omitted from generator output. No new `--service-accounts` opt-in flag — keeps the surface minimal. The `OAuth Token` controller registers the `/oauth/token` route only when JWT is on (the route is meaningless without JWT). Rejected: gating only on `--jwt` (SA without orgs is meaningless — there's no org to scope to); separate `--service-accounts` flag (forces adopters to opt into a feature whose dependencies are already opted-in).

### Audit shape (atomic Multi locked from Phase 91 D-91-15)

- **D-93-19 — Audit verbs (present-tense per codebase precedent; Phase 91 D-91-12 maneuver).** Six new audit actions:
  1. `service_account.create` — emitted from SA creation Multi.
  2. `service_account.revoke` — emitted from SA revocation Multi.
  3. `service_account.credential_create` — emitted from credential creation Multi.
  4. `service_account.credential_revoke` — emitted from credential revocation Multi.
  5. `service_account.token_issued` — emitted from `/oauth/token` successful issuance Multi (D-93-20).
  6. `api.token_verify.failure` — REUSED (existing action); rows for revoked-SA-JWT verifies write `actor_type = "service_account"` automatically via existing column.

  ROADMAP SC #3 says `service_account.created` / `service_account.revoked` (past tense). Surgical edit at phase commit canonicalizes to present tense (`service_account.create` / `service_account.revoke`) per `lib/sigra/organizations.ex` precedent (`organization.{create,update,rename,delete,...}`) — mirrors Phase 91 D-91-12 maneuver. Planner edits ROADMAP.md success criterion #3 wording in the phase commit.

- **D-93-20 — `service_account.token_issued` audit (D-27 asymmetry documented).** Industry-unanimous: GitHub `installation_token.created`, Auth0 `seccft` (Success Exchange — Client Credentials), AWS CloudTrail `AssumeRole`, Stripe `oauth/token` exchange events, Datadog/Sentry/1Password Business audit logs all log issuance. SOC 2 CC6.1/CC6.2 + ISO 27001 A.8.5 evidence tests effectively require it ("show every time SA-42's credentials were exchanged between Jan 1 and Mar 31" cannot be answered from `last_used_at` alone). NOT a D-27 violation: D-27 forbids auditing successful `Sigra.APIToken.verify/2` on every API request (millions/day at SaaS scale); SA token issuance is a discrete admin-class event TTL-bounded at thousands/day (D-93-08 1h TTL × 1000 SAs ≈ 24k rows/day, ~650 MB/year steady-state with `Sigra.Workers.AuditCleanup` 90-day retention). The asymmetry must be documented: D-27 stays for verifies; new D-93-20 documents issuance is audited. Rejected: skip success audit verbatim D-27 (compliance-incomplete; B2B-trust framing of v1.21 explicitly wants production-honest audit).

- **D-93-21 — Audit metadata payloads.**
  - `service_account.create`: `%{service_account_id, name, scopes}` (NOT client_id, NOT client_secret).
  - `service_account.revoke`: `%{service_account_id, reason: "admin_revoke" | "scope_change" | nil}`.
  - `service_account.credential_create`: `%{service_account_id, credential_id, client_id_prefix, expires_at}` (only the prefix portion of client_id, NEVER client_secret — D-23 forbidden-keys pattern).
  - `service_account.credential_revoke`: `%{service_account_id, credential_id, reason}`.
  - `service_account.token_issued`: `%{service_account_id, credential_id, scopes, jti, ip_address}` (jti links issuance to subsequent verify failures; ip_address aids forensics).
  - `api.token_verify.failure` (SA path): `%{actor_type: "service_account", service_account_id, credential_id, reason: "revoked" | "epoch_mismatch" | "credential_revoked" | "expired"}` (actor_type also written to column; mirrored in metadata for query ergonomics).

- **D-93-22 — Atomic audit pattern (locked from Phase 91 D-91-15 / Phases 73, 77, 79, 80, 81, 82, 85).** All five new SA mutations follow the established orchestrator shape:
  ```elixir
  Multi.new()
  |> Multi.insert/update(:service_account, changeset)
  |> append_audit(config, "service_account.X", scope,
       metadata: %{...})
  |> config.repo.transaction()
  |> normalize_multi_result()
  ```
  `append_audit/5` delegates to `Sigra.Audit.log_multi_safe/3`. Co-fated rollback: under fault injection (CHECK-guard on audit_events insert), no orphan SA/credential write. Public contract on co-fated paths: `{:ok, sa}` / `{:ok, credential}` only if both rows commit; failure → `{:error, :service_account_aborted}` / `{:error, :service_account_credential_aborted}` (per D-AUD-08 stable error atom). Token-issuance audit at `/oauth/token` follows the same pattern even though the issuance itself doesn't write to `service_accounts` — the credential `last_used_at` bump happens in the same Multi as the audit row to keep the contract uniform.

### Test posture

- **D-93-23 — Test files (planner discretion on exact paths).**
  - Library unit: `test/sigra/service_accounts_test.exs` (CRUD + revoke).
  - JWT path: extend `test/sigra/jwt_test.exs` to exercise both `:user` and `:service_account` actor types per ROADMAP SC #5.
  - OAuth token endpoint: `test/sigra/oauth/token_test.exs` (or wherever `Sigra.OAuth` tests live) — RFC 6749 envelope conformance, both auth mechanisms, error envelope per §5.2.
  - Atomicity: `test/sigra/service_accounts_audit_atomicity_test.exs` (mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs` shape from Phase 82).
  - Plug: extend `test/sigra/plug/require_membership_test.exs` and `test/sigra/plug/require_org_mfa_test.exs` with SA short-circuit assertions; extend `test/sigra/plug/fetch_bearer_test.exs` with SA scope-build assertions.
  - Generator-host integration: `test/example/test/example_web/integration/service_account_e2e_test.exs` per ROADMAP SC #4 — issues SA token via `/oauth/token`, calls protected endpoint successfully, revokes SA, asserts next call fails 401, asserts both create + revoke + token_issued + token_verify.failure audit rows.
  - Golden diff: stable for new schema templates + LiveView template + oauth_token_controller template.

- **D-93-24 — Zero human UAT (per user-wide GSD preference).** All verification shifts to integration/E2E automation per the generator-host integration test plus library unit + atomicity + plug tests. No `human_required` UAT items.

### Claude's Discretion

- Exact NimbleOptions schema field names (`:client_credentials_access_ttl` vs `:sa_access_ttl` vs `:m2m_access_ttl`).
- Exact `client_id` byte count (16 vs 24 vs 32 base64url chars after the `sigra_sa_` prefix).
- Whether `aud` (audience) claim is added to SA JWTs per RFC 9068 §2.2 (existing user JWTs don't have it; symmetry argues skip, RFC compliance argues include).
- Stable error atoms: `:service_account_aborted` vs `:sa_aborted`, `:service_account_credential_aborted` vs `:sa_credential_aborted`.
- Exact LiveView component composition for SA detail / credentials sub-panel (progressive disclosure shape).
- Whether SA detail is a route (`/service-accounts/:id`) or a modal — modal is simpler, route is shareable; planner picks.
- Whether the recipe lives at `guides/recipes/m2m-service-accounts.md` vs `guides/recipes/client-credentials.md` (m2m-service-accounts is more discoverable; client-credentials is more grant-name-faithful).
- Exact wording of `scope.user_id/1` helper docstring and whether it lives on `Sigra.Scope` or in the generated host scope module.
- Whether `Sigra.ServiceAccounts` is its own context module (parallel to `Sigra.Organizations`) or a submodule (`Sigra.Organizations.ServiceAccounts`). Lean: top-level `Sigra.ServiceAccounts` (parallel to `Sigra.Account`, `Sigra.MFA`, `Sigra.Passkeys`).
- Whether the `/oauth/token` route lives in core router_injection or organizations router_injection — leaning core (the route exists for the lib's RFC 6749 surface; SA happens to be the only grant in v1.21).
- Phase numbering for the surgical ROADMAP edit on D-93-19 action canonicalization (single-line edit committed with the phase, mirroring Phase 91 D-91-12).

### Folded Todos

_None — `gsd-sdk query todo.match-phase 93` returned 0 matches._

</decisions>

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **B2B-03** (the requirement this phase satisfies).
- `.planning/ROADMAP.md` — Phase 93 goal + 5 success criteria (`### Phase 93: M2M / service-account tokens (B2B-03)`). **Note D-93-19: success criterion #3 wording requires a one-line edit canonicalizing `service_account.created` → `service_account.create` and `service_account.revoked` → `service_account.revoke` during phase commit (mirrors Phase 91 D-91-12).**
- `.planning/PROJECT.md` — v1.21 framing (B2B trust leg), B2B-03 requirement narrative, "production-honest" framing that drives D-93-20 audit completeness.
- `.planning/STATE.md` — v1.21 leg-1 framing (Phase 93 = third B2B trust phase, depends on Phase 92).

### Atomic-audit precedent (locked behaviour contract)

- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — `D-AUD-01` (orchestrator owns txn), `D-AUD-06` (audit-only `:ok` semantics), `D-AUD-08` (co-fated paths roll back with stable error atom).
- `.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-CONTEXT.md` — `D-91-07` (Phase 91 pre-declared SA short-circuit on `RequireOrgMfa`), `D-91-12` (action-name canonicalization maneuver — Phase 93 D-93-19 mirrors), `D-91-15` (atomic audit pattern locked).
- `.planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-CONTEXT.md` — `D-85-02` orchestrator pattern + `D-85-04` D-AUD-06 sharpening.
- `.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-CONTEXT.md` — `D-82-01` orchestrator pattern, `D-82-02` public contract on co-fated paths, `D-82-04` test shape mirrored by D-93-23.
- `.planning/phases/81-jwt-refresh-audit-atomicity/81-CONTEXT.md` — `D-81-04` planning-truth surgical-update pattern.
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — `D-01` universal-atomic-Multi original intent; **D-27** (don't audit successful `APIToken.verify/2`; Phase 93 D-93-20 documents the asymmetry for issuance).

### Phase 92 RBAC seams (locked carry-forward)

- `.planning/phases/92-rbac-seams-b2b-02/92-VERIFICATION.md` — confirms `:role` and `:actor_type` already on scope (template + library), `Sigra.Authz.can?/3` behaviour, generated `<App>.SigraAuthz` allow-all stub, library is role-agnostic, host owns role taxonomy. D-93-15 builds on these.
- `lib/sigra/authz.ex` — single-callback behaviour module (102 lines, line 38 references "current user struct or a service-account principal" — Phase 92 anticipated Phase 93).
- `priv/templates/sigra.install/core/sigra_authz.ex` — generated allow-all stub; recipe extension for SA branch lives in v1.21 deliverable.
- `guides/recipes/role-based-access-control.md` — Phase 92 recipe; Phase 93 adds an "Authorizing service-account requests" section.

### IETF specifications (RFC 6749, RFC 9068)

- **IETF RFC 6749 §4.4 — Client Credentials Grant** — defines the wire shape Phase 93 implements; D-93-05/06/07 grounded here.
- **IETF RFC 6749 §2.3.1 — Client Password** — Basic auth REQUIRED, form fields allowed; D-93-05 supports both.
- **IETF RFC 6749 §5.1 — Successful Response** — JSON envelope `{access_token, token_type, expires_in, scope}`, `Cache-Control: no-store`.
- **IETF RFC 6749 §5.2 — Error Response** — JSON envelope `{error, error_description?}`, error values; D-93-06 routes `unsupported_grant_type`.
- **IETF RFC 9068 — JWT Profile for OAuth 2.0 Access Tokens** — guides `sub == client_id` in D-93-09; planner discretion on `aud` claim per D-93-10.

### Code (integration points — read these)

- `lib/sigra/jwt.ex` — `generate_tokens/4` (line 90), `verify_access/2` (line 127), `build_claims/4` (line 365–375 — epoch claim mechanics). **D-93-08 adds `:client_credentials_access_ttl` config; D-93-12 mirrors `users.token_epoch` for `service_accounts.token_epoch`.**
- `lib/sigra/jwt/claims_builder.ex` — behaviour shape Phase 93 may extend (planner discretion).
- `lib/sigra/jwt/refresh_token.ex` — **DO NOT extend** (no SA refresh tokens per D-93-07).
- `lib/sigra/jwt/signer.ex` — JWT signing/verification primitives.
- `lib/sigra/api_token.ex` — `verify/2` (line 50–245 area for verify-failure audit pattern), `do_create/4` (line 97 area for atomic Multi shape mirrored by SA creation).
- `lib/sigra/api_token/scope_registry.ex` — `valid_format?/1`, `validate_scopes/2`. Phase 93 reuses this registry; hosts add SA-relevant scopes via `:custom_scopes` config (no new registry).
- `lib/sigra/plug/fetch_bearer.ex` — single auth entry point; D-93-11 forks JWT branch on `claims["actor_type"]`. Lines 50–95 area is the modification surface.
- `lib/sigra/plug/require_membership.ex` — D-93-13 short-circuit; mirrors Phase 91 plug pattern.
- `lib/sigra/plug/require_org_mfa.ex` (TBD by Phase 91 deliverable) — D-93-14 short-circuit; locked from Phase 91 D-91-07.
- `lib/sigra/scope.ex` — `build/3` (line 42), `from_opts/2` (line 81), `from_config/2` (line 108) — all already accept `:actor_type`; Phase 93 adds `:service_account_id` parameter threading.
- `lib/sigra/scope/hydration.ex` — **DO NOT extend** (D-93-11; SA scope built directly in FetchBearer).
- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3` — Phase 93 reuses `log_multi_safe/3` per D-93-22.
- `lib/sigra/organizations.ex` — `update_organization/4` (line 435), `append_audit/5` private helper (line ~1313 area). Orchestrator shape mirrored by `Sigra.ServiceAccounts.create/3`, `revoke/3`, `create_credential/3`, `revoke_credential/3`.
- `lib/sigra/oauth.ex` — existing OAuth orchestrator; `/oauth/token` is a NEW endpoint (does not currently exist; verified). D-93-05 adds `Sigra.OAuth.Token` (or `Sigra.OAuth.ClientCredentials`) submodule for token-grant logic.

### Generator templates (where new code lands)

- `priv/templates/sigra.install/organizations/service_account.ex` — **NEW** SA schema template.
- `priv/templates/sigra.install/organizations/service_account_credential.ex` — **NEW** credential schema template.
- `priv/templates/sigra.install/organizations/service_accounts_migration.exs` — **NEW** migration creating both tables (Postgres-only post-Phase-94; planner targets Postgres).
- `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` — **NEW** admin LiveView per D-93-16.
- `priv/templates/sigra.install/organizations/router_injection.ex` — extend with `/service-accounts` route under `:org_scoped` pipeline.
- `priv/templates/sigra.install/core/oauth_token_controller.ex` — **NEW** RFC 6749 token controller per D-93-05.
- `priv/templates/sigra.install/core/scope.ex` — extend with `service_account_id: nil` field + `@type` declaration; Phase 92 already reserved `:role` and `:actor_type`.
- `priv/templates/sigra.install/core/audit_event.ex` — **UNCHANGED** (`actor_type` column already exists at line 29 with default `"user"`; D-93-19 just writes `"service_account"` for SA events).
- `priv/templates/sigra.install/core/create_audit_events.exs` — **UNCHANGED** (`actor_type` column exists with index from Phase 9 area).
- `priv/templates/sigra.install/sigra.upgrade/alter_add_service_accounts.exs` — **NEW** v1.21 upgrade migration adding both tables (idempotent `create_if_not_exists`); structural twin of `priv/templates/sigra.install/sigra.upgrade/alter_add_personal.exs`.

### Recipe + docs (where adopters learn the SA path)

- `guides/recipes/m2m-service-accounts.md` (or `guides/recipes/client-credentials.md` — planner discretion) — **NEW**: walks adopters from `mix sigra.install --jwt --organizations` through admin LiveView creation, RFC 6749 `POST /oauth/token` curl example, host `Sigra.Authz` actor_type branch, scope-list authorization examples. Registered under ExDoc Recipes group in `mix.exs:213` `Recipes: ~r{guides/recipes/.?}`.
- `guides/recipes/role-based-access-control.md` — Phase 92 recipe; Phase 93 adds an "Authorizing service-account requests" section showing `case scope.actor_type do :user -> ...; :service_account -> ... end` in `MyApp.SigraAuthz.can?/3`.
- `CHANGELOG.md` `[Unreleased]` — add B2B-03 trace bullet at phase commit.

### Verification + planning truth touch points

- `.planning/ROADMAP.md` — surgical edit to Phase 93 success criterion #3 (action-name canonicalization per D-93-19) at phase commit.
- `.planning/phases/93-m2m-service-account-tokens-b2b-03/93-VERIFICATION.md` — to be authored at phase close per ROADMAP success criterion #5.

</canonical_refs>

<code_context>

## Existing Code Insights

### Reusable Assets

- **`Sigra.Audit.log_multi_safe/3`** — atomic-audit Multi step composer. No changes needed for Phase 93 audit verbs.
- **`Sigra.Organizations.append_audit/5` (private helper)** — already used by every org mutation. New `Sigra.ServiceAccounts` context borrows the helper shape (or imports it; planner discretion).
- **`Sigra.Token.generate_hashed_token/0` + `Sigra.Token.hash_token/1`** — existing primitives for `client_secret` generation + storage (32-byte random + SHA-256).
- **`Sigra.APIToken.ScopeRegistry` (`lib/sigra/api_token/scope_registry.ex`)** — same scope registry; SAs use the same `resource:action` format. Hosts add SA-relevant scopes via `:custom_scopes` config (e.g., `"deploy:write"`, `"billing:read"`).
- **`Sigra.JWT.generate_tokens/4` + `verify_access/2` + `build_claims/4`** — extended for SA flow (extra claims `actor_type`, `service_account_id`, `credential_id`, `org_id`); user path untouched.
- **`Sigra.Plug.FetchBearer` JWT branch** — single fork point for SA scope construction (D-93-11).
- **`audit_events.actor_type` column** — already exists with default `"user"` at `priv/templates/sigra.install/core/audit_event.ex:29` and indexed via `priv/templates/sigra.install/core/create_audit_events.exs`. Zero migration cost; D-93-19 just writes `"service_account"`.
- **Phase 92's `Sigra.Authz` behaviour + `<App>.SigraAuthz` allow-all stub** — host's `can?/3` impl branches on `scope.actor_type` for SA requests; Phase 93 recipe extends Phase 92's recipe.
- **Phase 91's `Sigra.Plug.RequireOrgMfa` SA short-circuit declaration (D-91-07)** — Phase 93 implements the 3-line guard.

### Established Patterns

- **Atomic Multi + audit** — every mutation in `lib/sigra/organizations.ex` and `lib/sigra/api_token.ex` uses `Multi.new() |> Multi.X(...) |> append_audit(config, "...", scope, metadata: ...) |> config.repo.transaction() |> normalize_multi_result()`. Five Phase 93 SA mutations (create, revoke, credential_create, credential_revoke, token_issued) follow.
- **Single auth entry point (`Sigra.Plug.FetchBearer`)** — locked by ROADMAP SC #5; Phase 93 adds one new code path inside the JWT branch, no new plug.
- **Generator-managed router pipelines** — `:org_scoped` pipeline lives in `priv/templates/sigra.install/organizations/router_injection.ex`; `/oauth/token` mounts in core router_injection (no auth pipeline needed — the endpoint authenticates via `client_id` + `client_secret`, not bearer).
- **Sudo-ladder for org-settings actions** — General (no sudo), Slug (sudo + typed-confirm), Danger (sudo + typed-confirm + red), Security (sudo via Phase 91). New "Service Accounts" admin sits at sudo-on-create-and-revoke per D-93-17.
- **Phoenix scope = struct-or-nil** — `current_scope` is `nil` when unauthenticated (Phoenix 1.8 idiom); for SA, `scope.user = nil` is the natural extension.
- **Plug ↔ on_mount pairing** — pattern from RequireMembership/OrganizationScope. Phase 93 does NOT add a new on_mount (SA requests never reach LiveView paths in v1.21 — LV is HTTP-cookie-session-based; SA is bearer-only). If a future phase adds SA-authenticated LV (websocket bearer), that's separate.

### Integration Points

- **NEW** library context `Sigra.ServiceAccounts` (top-level, parallel to `Sigra.Organizations`).
- **NEW** library module `Sigra.OAuth.Token` (or `Sigra.OAuth.ClientCredentials`) — RFC 6749 token-grant logic; planner discretion on naming.
- **NEW** schema fields on `Sigra.Scope` and generated scope template: `:service_account_id` (string/uuid).
- **NEW** schema modules in generated host: `<App>.ServiceAccount`, `<App>.ServiceAccountCredential`.
- **NEW** generated controller: `<App>Web.OAuthTokenController`.
- **NEW** generated LiveView: `<App>Web.OrganizationServiceAccountsLive`.
- **NEW** generated migration: `priv/repo/migrations/<TS>_create_service_accounts.exs`.
- **NEW** generated upgrade migration: `priv/repo/migrations/<TS>_alter_add_service_accounts.exs` (for adopters upgrading from v1.20).
- **NEW** library function `Sigra.ServiceAccounts.create/3`, `revoke/3`, `create_credential/3`, `revoke_credential/3`, `issue_token/3`.
- **NEW** library function `Sigra.JWT.generate_for_service_account/3` (or `generate_tokens/4` extended with SA branch — planner discretion).
- **MODIFIED** `Sigra.Plug.FetchBearer` — JWT branch forks on `actor_type` claim.
- **MODIFIED** `Sigra.Plug.RequireMembership` — SA short-circuit guard (D-93-13).
- **MODIFIED** `Sigra.Plug.RequireOrgMfa` — SA short-circuit guard (Phase 91 D-91-07; Phase 93 implements).
- **MODIFIED** `Sigra.JWT.build_claims/4` — extra claims for SA path.
- **MODIFIED** `Sigra.Scope` (lib + template) — add `:service_account_id` field + thread through `build/3`, `from_opts/2`, `from_config/2`.
- **MODIFIED** generated `<App>.SigraAuthz` recipe — SA actor_type branch added in Phase 92's RBAC recipe.
- **NEW** `Sigra.Scope.user_id/1` helper — returns `scope.user && scope.user.id`; convenience for sites that don't care about actor_type (D-93-04).

</code_context>

<specifics>

## Specific Ideas

- **Industry-precedent locks (from Area research):** AWS IAM (2 keys/user for rotation), Google Cloud SA (10 keys/SA), Okta Service Apps (2 client_secrets), Auth0 M2M, GitHub Apps installation-tokens — all converged on stable-identity + multi-credential shape because enterprise rotation requires overlap. v1.21 ships the schema correctly to avoid a destructive migration later.
- **GitLab project-access-token "bot user" approach is the documented anti-pattern** — years of forum patches for "bot users don't have access to internal projects" (#361993), "PATs should be treated as external users" (#383882), immortal bot members on the org member list. GitHub deliberately migrated AWAY from machine-users to GitHub Apps. Sigra D-93-04 uses the GitHub Apps shape: `scope.user = nil` + tagged-union on `actor_type`.
- **Spring Security + Devise+Doorkeeper precedent for non-user principals** — both keep `current_user` (or equivalent) typed strictly; tokens get a sibling helper. Sigra adds `Sigra.Scope.user_id/1` helper for sites that genuinely don't care about actor_type.
- **RFC 6749 §4.4.3 wording** — "A refresh token SHOULD NOT be included." Auth0/Okta/AWS/Google all conform. Sigra D-93-07 conforms.
- **Auth0 M2M docs framing** — "store new as fallback to previous" credential rotation is the OAuth-ecosystem-standard pattern. Sigra D-93-02 makes this trivial via the credentials join table.
- **NIST SP 800-92 §4.2** — log all authentication events including token issuance; manage retention. D-93-20 conforms; existing `Sigra.Workers.AuditCleanup` (90-day default) bounds storage.
- **SOC 2 CC6.1 / ISO 27001 A.8.5** — auditor evidence test "show every time SA-X was exchanged for a token" requires issuance rows; `last_used_at` + create/revoke + verify-failure is incomplete. D-93-20 conforms.
- **GitHub `installation_token.created` / Auth0 `seccft` / AWS CloudTrail `AssumeRole` / Stripe `oauth/token` events / Datadog/Sentry/1Password Business audit logs** — industry-unanimous on auditing token issuance.
- **Decimal phase numbering not used** — Phase 93 is a primary phase under v1.21.

</specifics>

<deferred>

## Deferred Ideas

- **Other RFC 6749 grant types** (`password`, `authorization_code`, `device_code`, `refresh_token`) — `/oauth/token` dispatches but only `client_credentials` works in v1.21. Future v1.x phases can add grants without breaking changes (D-93-06 unlocks this).
- **Migrating `/api/auth/token` (Sigra-specific email+password JWT login) under `/oauth/token` `grant_type=password`** — out of scope for v1.21 to avoid adopter churn. Re-evaluate if RFC 6749 conformance becomes a stronger driver.
- **Multi-credential UI polish** — v1.21 ships minimal "create credential" + "revoke credential" buttons; richer rotation flows (overlap windows, expiration warnings, automated rotation reminders) defer to v1.3+.
- **SA-to-SA delegation / impersonation** — out of scope; not a v1.21 B2B-trust requirement.
- **`Sigra.Plug.FetchServiceAccountBearer` parallel pipeline** — explicitly forbidden by ROADMAP SC #5 / D-93-11. Park as a v2 host-extension pattern only if a real adopter signal demands separation.
- **PKCE / proof-of-possession for SA tokens** — `client_credentials` per RFC 6749 §4.4 doesn't require PKCE. If a future "high-security M2M" adopter signal emerges, RFC 8705 (mTLS-bound tokens) is the upgrade path.
- **`aud` (audience) claim on SA JWTs per RFC 9068** — planner discretion in v1.21; if added, should be added to user JWTs too for symmetry. Park as a "JWT spec compliance" follow-up phase if a deeper RFC 9068 conformance pass becomes needed.
- **Per-credential `token_epoch` field** — over-engineered for v1.21 (per-credential `revoked_at` lookup is sufficient because credential row is loaded at verify time anyway). Re-evaluate if SA fleets get large enough that per-verify credential lookup becomes a hot-path concern.
- **Webhooks for SA lifecycle events (`service_account.create.webhook`, `.token_issued.webhook`, etc.)** — deferred to v1.22 webhooks milestone.
- **SA-authenticated LiveView (websocket bearer auth)** — Sigra LV in v1.21 is HTTP-cookie-session-based; SA is bearer-only, no SA-authenticated LV path. If a future phase adds SA WebSocket auth, the plug ↔ on_mount pairing pattern (Phase 91 D-91-03) is the model.
- **Adopting GitHub's "fine-grained token expiration" model in addition to client_credentials** — v1.21 supports per-credential `expires_at` (D-93-02) but doesn't enforce expiration policies (e.g., "force rotation every 90 days"). Future adoption cue if security-review feedback wants policy enforcement.

### Reviewed Todos (not folded)

_No todos matched the phase scope (`gsd-sdk query todo.match-phase 93` returned 0)._

</deferred>

---

*Phase: 93-m2m-service-account-tokens-b2b-03*
*Context gathered: 2026-04-30*
