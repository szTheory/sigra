# Phase 244: PAT and Advanced JWT Truth Repair - Research

**Researched:** 2026-08-12  
**Domain:** Phoenix generator contracts, personal access-token management, and JWT/refresh-token verification  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Independent Generator Contracts
- **D-01:** `--api` and `--jwt` emit independent host contracts. `--api` owns PAT schema, migration, configuration, Auth delegates, browser-session management routes, and `FetchAPIToken`; `--jwt` emits only the advanced JWT contract and never implies PAT facilities.
- **D-02:** Generated API authentication uses the explicit credential-kind plugs from Phase 243. `FetchBearer` remains compatibility-only and is not the primary fresh-host pipeline.

### PAT Management Boundary
- **D-03:** PAT list/create/revoke operations live on the authenticated browser/session path behind Phoenix CSRF protection, authenticated Scope, and `RequireSudo` recent-auth enforcement.
- **D-04:** Every PAT management operation derives the owner from `current_scope`. Revocation constrains both token ID and owner; request parameters never select the owning user.
- **D-05:** Available PAT scopes are configured server-side and validated by the server. Clients may request only a subset of that allowlist.

### Advanced JWT Contract
- **D-06:** JWT issuance is a host-selected server-policy operation. Do not generate an email/password-to-JWT endpoint, and never accept request-selected authority scopes.
- **D-07:** Access-token verification requires the configured signing algorithm and the configured protected-header `typ`, plus mandatory `iss`, `aud`, `sub`, `iat`, `exp`, and `jti` payload claims; validate `nbf` when present.
- **D-08:** Rely on Joken's configured signer for exact algorithm enforcement. Use required-claim enforcement plus value/type validators for payload claims, and separately validate the protected JOSE `typ` header only in conjunction with successful signature verification.
- **D-09:** Accept RFC-valid scalar or array `aud` token forms. Configuration may identify one or more accepted audiences; matching is exact and case-sensitive with at least one configured recipient present. Missing, empty, or malformed audiences fail closed.

### Refresh-Family Atomicity
- **D-10:** JWT refresh rotation, replacement insertion, and reuse-driven family revocation execute transactionally in audited and non-audited configurations. Transaction failure returns no replacement access or refresh credential.
- **D-11:** Refresh credentials remain opaque and digest-backed. Consumed-token reuse revokes the applicable family before returning `reuse_detected`.

### the agent's Discretion
- Exact internal module/helper boundaries, generated controller/LiveView presentation, and deterministic test organization, provided the public and security contracts above remain intact.
- Whether accepted audience configuration is normalized at config validation or JWT setup time, provided malformed configuration fails before serving traffic.

### Deferred Ideas (OUT OF SCOPE)

- Opaque app sessions and first-party native login remain Phases 245-246.
- OAuth/OIDC authorization-server behavior remains Lockspire's responsibility.
- Published native SDKs and generalized offline behavior remain outside this milestone.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PAT-01 | A fresh host generated with `--api` receives all schemas, migrations, configuration, Auth delegates, routes, and plugs required to create and authenticate with personal access tokens. | Split Core feature predicates/injections, emit the existing PAT migration/schema/Auth template plus an explicit `FetchAPIToken` API pipeline, and prove an independent generated host compiles and exercises PAT authentication. [VERIFIED: codebase inspection — `lib/sigra/install/features/core.ex`; Phase 243 verification] |
| PAT-02 | An authenticated user can list, create, and revoke only their own personal access tokens through CSRF-protected, recent-authenticated management operations with server-validated scopes. | Move generated management routes to browser/authenticated/sudo pipelines; derive owner from Scope; add an owner-constrained revoke call in the library/delegate; retain `ScopeRegistry` as server allowlist validation. [VERIFIED: codebase inspection — `api_token_controller.ex`, `auth_api_token.ex`, `lib/sigra/api_token.ex`, `scope_registry.ex`] |
| JWT-01 | A fresh host generated with `--jwt` receives an independently runnable advanced JWT configuration whose access tokens require the configured algorithm, type, issuer, audience, subject, issued-at, expiry, and identifier claims and validate not-before when present. | Decouple JWT generation, add issuer/audience/type configuration validation and a Joken verify-then-validate boundary, and exercise independent fresh-host compile/runtime proof. [VERIFIED: codebase inspection — `core.ex`, `config.ex`, `jwt.ex`, locked context] |
| JWT-02 | A host can issue server-scoped JWTs and atomically rotate/revoke opaque refresh-token families without exposing a generated password-to-JWT endpoint or accepting request-selected scopes. | Remove the generated password/MFA exchange controller routes, expose only host-callable issuance, and implement one transaction with row locking for classify/rotate/reuse in both audit modes. [VERIFIED: codebase inspection — `token_controller.ex`, `jwt.ex`, `refresh_token.ex`] |
</phase_requirements>

## Summary

Phase 244 is a truth-repair phase, not a new authentication protocol. The installer currently treats `--jwt` as `--api`: it emits the PAT migration/schema/controller and the `FetchBearer` pipeline whenever either flag is selected. It also emits a password-to-JWT controller accepting request-provided scopes. Those outputs contradict the independent contracts and host-selected issuance decision. [VERIFIED: codebase inspection — `lib/sigra/install/features/core.ex`, `priv/templates/sigra.install/core/token_controller.ex`]

Use the existing PAT persistence, scope registry, explicit Phase 243 plugs, Joken 2.6.2, and Ecto transactions as substrate. Repair ownership at each boundary: browser-session Scope owns PAT self-management; server configuration owns allowed PAT and JWT audiences/scopes; the configured Joken signer owns signature algorithm enforcement; a small Sigra JWT validator owns claim/header checks; and one locked database transaction owns refresh-family state changes. [VERIFIED: codebase inspection — `lib/sigra/api_token.ex`, `lib/sigra/jwt*.ex`, `lib/sigra/plug`; CITED: https://hexdocs.pm/joken/Joken.html]

**Primary recommendation:** Plan four vertical slices: independent generator emission, owner-bound browser PAT management, strict JWT generation/verification with a host-only issuance API, then locked transactional refresh rotation/reuse with independent fresh-host and Postgres evidence.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `--api` host contract and explicit PAT request pipeline | Frontend Server (SSR) | API / Backend | Generator emits the host router/config/schema; API requests use `FetchAPIToken`, not compatibility dispatcher. [VERIFIED: codebase inspection — `core.ex`; Phase 243 verification] |
| PAT self-management | Frontend Server (SSR) | Database / Storage | Browser pipeline supplies CSRF/session Scope; Ecto persists/list/revokes the owner’s records. [VERIFIED: codebase inspection — `core.ex`, `api_token.ex`, `require_sudo.ex`] |
| JWT signing and verification | API / Backend | Database / Storage | Sigra/Joken validates cryptographic and claim contract; epoch checking and refresh users/tokens use Repo. [VERIFIED: codebase inspection — `jwt.ex`, `signer.ex`, `refresh_token.ex`] |
| Refresh-family rotate/reuse | Database / Storage | API / Backend | The database transaction and row lock must serialize consumption/revocation; the API returns tokens only after commit. [VERIFIED: codebase inspection — `refresh_token.ex`, `jwt_refresh_audit_cofate_test.exs`] |

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system and Rail Accent assets if a generated management UI is introduced. [VERIFIED: `AGENTS.md`]
- Support Light, Dark, and System modes for any such UI. [VERIFIED: `AGENTS.md`]
- Keep Playwright/admin UI tests deterministic, with role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: `AGENTS.md`]
- Replace human/UAT verification with deterministic tests, browser automation, CI polling, and committed machine-readable evidence when work is authorized. [VERIFIED: `AGENTS.md`]
- Do not alter unrelated worktree changes, `.planning/config.json`, or `.planning/research/.cache/`. [VERIFIED: orchestrator constraint and current worktree inspection]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Sigra installer/Core templates | repository | Independent generated host files, router/config injections, and post-install guidance | Owns all affected template groups today. [VERIFIED: codebase inspection — `core.ex`] |
| Joken | 2.6.2 (locked) | JWT signer verification and claims validation hooks | Existing optional dependency is locked at 2.6.2; its signer binds verification to an algorithm and its APIs separate verification from validation. [VERIFIED: `mix.lock`, `deps/joken/lib/joken/signer.ex`; CITED: https://hexdocs.pm/joken/Joken.Signer.html] |
| Ecto / Ecto.Multi | 3.14.0 (locked) | Atomic PAT audit and refresh family persistence | Existing PAT/audited refresh paths already use Multi and Repo transactions. [VERIFIED: `mix.lock`, `api_token.ex`, `jwt.ex`] |
| ExUnit + Mox + PostgresCase | repository | Unit, source-contract, generated-host, and concurrency/fault-injection proof | Existing auth unit tests are Mox-based; refresh co-fate integration uses a real Postgres case. [VERIFIED: codebase inspection — `test/sigra/jwt_test.exs`, `jwt_refresh_audit_cofate_test.exs`] |

### Supporting

| Library / component | Purpose | When to Use |
|---------------------|---------|-------------|
| `Sigra.Plug.FetchAPIToken` | Explicit PAT bearer verification and normal Scope construction | Generated API-only authenticated pipeline. [VERIFIED: Phase 243 verification] |
| `Sigra.APIToken.ScopeRegistry` | Server-side scope allowlist and format validation | Every PAT create operation; never trust the request alone. [VERIFIED: `scope_registry.ex`] |
| `Sigra.Plug.RequireSudo` | Fresh browser-session reauthentication gate | All PAT list/create/revoke routes, per locked decision. [VERIFIED: `require_sudo.ex`] |
| `Joken.Hooks.RequiredClaims` + Joken claim validators | Required payload presence plus type/value checks | JWT verify-and-validate contract after successful signature verification. [VERIFIED: `deps/joken/lib/joken/hooks/required_claims.ex`; CITED: https://hexdocs.pm/joken/Joken.Hooks.RequiredClaims.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit generated PAT pipeline | `FetchBearer` autodetection | Rejected by D-02; compatibility dispatcher is for installed hosts only. [VERIFIED: locked context; Phase 243 verification] |
| Browser/sudo PAT management | Bearer/API CRUD controller | Rejected by D-03; bearer management enables recursive credential administration and lacks the intended CSRF/recent-auth boundary. [VERIFIED: locked context] |
| Configured signer + Joken validation | Custom JWT decoder/signature handling | Rejected by D-08; Joken already provides the cryptographic boundary and hooks. [VERIFIED: `deps/joken/lib/joken/signer.ex`; CITED: https://hexdocs.pm/joken/Joken.html] |
| `FOR UPDATE` transaction covering classify and mutation | Read/classify then separate writes | Required because current non-audited flow does separate `get_by`, update, insert, and family revocation calls; concurrent requests can observe the same live refresh token. [VERIFIED: codebase inspection — `refresh_token.ex`, `jwt.ex`] |

**Installation:** None. This phase must use the locked `joken` 2.6.2 and current Ecto stack; do not add an external package. [VERIFIED: `mix.exs`, `mix.lock`]

## Package Legitimacy Audit

No external package is installed; the package-legitimacy gate is not applicable. Joken is an existing locked dependency at 2.6.2. [VERIFIED: `mix.lock`]

## Architecture Patterns

### System Architecture Diagram

```text
mix sigra.install --api                         mix sigra.install --jwt
          |                                               |
          v                                               v
PAT schema/migration/config/Auth + FetchAPIToken     JWT config + host issuance seam only
browser + authenticated + RequireSudo routes          (no PAT output; no password exchange route)
          |                                               |
          v                                               v
current_scope.user -> server allowlist -> owner-bound    server policy chooses user + scopes
create/list/revoke PAT                                    -> Joken signer -> JWT {typ, iss, aud, sub, iat, exp, jti}
          |                                               |
          +--------------------------+--------------------+
                                     v
                       explicit host request pipeline
                       FetchAPIToken | FetchJWT
                                     |
                                     v
                  verified credential -> live user -> normal Scope

refresh credential -> digest lookup + `FOR UPDATE` inside transaction
  -> live: supersede + insert replacement (+ audit if configured) -> commit -> issue access token
  -> consumed: revoke family (+ audit if configured) -> commit -> `reuse_detected`
  -> any rollback/failure -> no replacement credentials returned
```

### Recommended Project Structure / File Map

| Area | Files to modify | Planner action |
|------|-----------------|----------------|
| Generator feature split | `lib/sigra/install/features/core.ex`; `test/sigra/install/features/core_test.exs`; `test/sigra/install/api_token_generator_test.exs` | Separate `api?` from `jwt?` in file selection, injections, routes, configuration, and post-instructions; assert all four flag combinations. [VERIFIED: codebase inspection] |
| PAT host templates | `priv/templates/sigra.install/core/api_token_controller.ex`; `auth_api_token.ex`; potentially a dedicated browser-facing template; `test/sigra/install/api_token_generator_test.exs` | Replace bearer CRUD with browser/session/sudo self-management, owner-derived delegate calls, scope allowlist presentation, and raw-token-once response. [VERIFIED: codebase inspection] |
| PAT library ownership | `lib/sigra/api_token.ex`; `lib/sigra/auth.ex`; `test/sigra/api_token_test.exs` | Add `revoke_for_user(config, token_id, owner)` (or equivalent) that queries by both ID and owner; keep generic internal/admin capability separate only if needed. [VERIFIED: `api_token.ex`, `auth.ex`] |
| JWT config/claims | `lib/sigra/config.ex`; `lib/sigra/jwt.ex`; `lib/sigra/jwt/signer.ex`; add a narrowly scoped validator module only if it simplifies testing; `test/sigra/jwt_test.exs`, `signer_test.exs` | Normalize accepted audiences, require configured `typ`, issue all required claims, verify signature then payload/header contract. [VERIFIED: codebase inspection; CITED: https://hexdocs.pm/joken/Joken.Config.html] |
| JWT host template | remove/replace `priv/templates/sigra.install/core/token_controller.ex`; adjust `auth_api_token.ex`; generator tests | Do not emit email/password/MFA-to-JWT endpoints or request-selected scopes; expose a documented host-callable server-policy function. [VERIFIED: locked context; `token_controller.ex`] |
| Refresh transaction | `lib/sigra/jwt.ex`; `lib/sigra/jwt/refresh_token.ex`; `test/sigra/jwt/refresh_token_test.exs`; `test/sigra/jwt_refresh_audit_cofate_test.exs` | Move classify, lock, supersede/revoke, replacement insert, and optional audit into one transaction in both modes; issue access JWT only after transaction success. [VERIFIED: codebase inspection] |
| Fresh-host evidence | extend `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` or add a phase-specific generated-host test plus source contracts | Create two independent hosts (`--api`, `--jwt`), migrate/compile each, then execute PAT/JWT contract smoke without template-only proof. [VERIFIED: existing generated-host runtime test discovery; locked context] |

### Pattern 1: Owner-bound browser PAT management

**What:** Router routes all PAT mutations/listing through `[:browser, :require_authenticated, :require_sudo]`; controller obtains `owner = conn.assigns.current_scope.user`; the context passes that owner to every list/create/revoke operation. [VERIFIED: locked context; `core.ex`, `require_sudo.ex`]

**When to use:** Only PAT self-management. API resource authorization continues to use explicit `FetchAPIToken` plus `RequireScopes`. [VERIFIED: locked context; Phase 243 verification]

```elixir
# Generated router shape — source contract, not a public API
scope "/users", MyAppWeb do
  pipe_through [:browser, :require_authenticated, :require_sudo]

  get "/api-tokens", APITokenController, :index
  post "/api-tokens", APITokenController, :create
  delete "/api-tokens/:id", APITokenController, :delete
end

# Controller delegates with the scope-derived owner; params do not choose it.
Auth.revoke_api_token(current_scope.user, id, scope: current_scope)
```

Use the existing `ScopeRegistry.validate_scopes/2` in the library, not controller validation, so direct host calls cannot bypass the configured allowlist. [VERIFIED: `scope_registry.ex`, `api_token.ex`]

### Pattern 2: Verify signature first, then enforce JWT contract

**What:** Build a token configuration that requires `iss`, `aud`, `sub`, `iat`, `exp`, and `jti`; applies strict type/value validators; calls `Joken.verify_and_validate` with the configured signer; only after that success decodes/checks the protected header `typ`. Missing/empty/malformed values fail closed. [VERIFIED: locked D-07/D-08/D-09; `deps/joken/lib/joken.ex`, `required_claims.ex`]

**When to use:** `verify_access/2` for inbound JWTs. Issuance must generate matching `iss`, `aud`, and header `typ`; server policy supplies scopes and subject. [VERIFIED: `jwt.ex`; locked context]

```elixir
with {:ok, claims} <- Joken.verify_and_validate(token_config, jwt, signer, %{}, required_hooks),
     {:ok, %{"typ" => expected_typ}} <- Joken.peek_header(jwt),
     :ok <- validate_audience(claims["aud"], configured_audiences) do
  verify_epoch(config, claims)
else
  _ -> {:error, :invalid_token}
end
```

`peek_header/1` is not itself signature verification; its result is admissible only after signer success. Joken’s signer implementation invokes strict JOSE verification with its configured algorithm. [VERIFIED: `deps/joken/lib/joken/signer.ex`; CITED: https://hexdocs.pm/joken/Joken.html]

### Pattern 3: One refresh transaction with a locked current record

**What:** Decode/hash the opaque input, start a transaction, query the refresh row with a write lock, classify it while locked, and then build the rotate or family-revoke Multi in that same transaction. Generate the replacement opaque token before insert but return it only after commit. Fetch the user and sign the replacement access JWT only after persistence commit (or inside the transaction only if the design deliberately needs failure to roll back persistence). [VERIFIED: locked D-10/D-11; current split behavior in `refresh_token.ex`, `jwt.ex`]

**When to use:** Audited and non-audited `JWT.refresh/3` paths. Audit is an additional Multi step, never a reason to select a weaker persistence boundary. [VERIFIED: `jwt.ex`, `jwt_refresh_audit_cofate_test.exs`]

### Anti-Patterns to Avoid

- **Coupled installer condition:** never derive `api?` from `api || jwt`; that emits PAT artifacts for `--jwt`. [VERIFIED: `core.ex`]
- **Fresh-host `FetchBearer`:** do not use the deprecated compatibility dispatcher in generated router content. [VERIFIED: locked D-02; Phase 243 verification]
- **Ownerless `revoke(id)`:** an ID-only lookup permits cross-user revocation if routing/auth mistakes occur; include `user_id == owner.id` in the query. [VERIFIED: `api_token.ex`, locked D-04]
- **Controller-only scope filtering:** selected scopes must be validated in library code against config, including host direct calls. [VERIFIED: `scope_registry.ex`, locked D-05]
- **Unverified header inspection:** never select/approve a signer based on `peek_header`; verify with configured signer first. [CITED: https://hexdocs.pm/joken/Joken.html]
- **JWT `aud` string-only check:** RFC-valid array audiences must work; scalar/array membership is exact and case-sensitive. [CITED: https://www.rfc-editor.org/rfc/rfc7519; https://www.rfc-editor.org/rfc/rfc8725]
- **Non-audited refresh shortcut:** no audit schema must not mean no transaction/lock. [VERIFIED: locked D-10; `jwt.ex`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PAT generation/digest/expiry/revocation | Second token storage format or controller-local validation | `Sigra.APIToken` + `ScopeRegistry` | Existing code hashes raw PATs, validates scope registry, and co-fates audit writes. [VERIFIED: `api_token.ex`, `scope_registry.ex`] |
| JWT signature/algorithm verification | Hand-rolled JOSE/JWS parsing | Configured `Joken.Signer` | Joken 2.6.2 signer uses strict verification for its configured algorithm. [VERIFIED: `deps/joken/lib/joken/signer.ex`] |
| Required-claim detection | Ad hoc map-key checks scattered through controllers | `Joken.Hooks.RequiredClaims` plus a centralized Sigra validator | RequiredClaims is designed to fail validation when named claims are absent. [VERIFIED: `deps/joken/lib/joken/hooks/required_claims.ex`] |
| CSRF/recent auth | Custom token-management guard | Browser pipeline + existing `RequireAuthenticated`/`RequireSudo` | Existing authenticated browser route structure and sudo freshness plug provide the required boundary. [VERIFIED: `core.ex`, `require_sudo.ex`] |
| Atomic refresh | Application-level “update then insert” sequence | `Repo.transaction` + `Ecto.Multi` + row lock | Only the database can serialize competing consumption of one refresh credential. [VERIFIED: `refresh_token.ex`, locked D-10] |

**Key insight:** Keep policy, cryptography, and persistence ownership distinct: hosts choose issuance policy; Joken verifies signatures; Sigra validates the accepted JWT/PAT contract; the database serializes refresh state. [VERIFIED: locked context; codebase inspection]

## Common Pitfalls

### Pitfall 1: `--jwt` secretly generates PAT capability

**What goes wrong:** A JWT-only host receives PAT migration/schema/controller/config because Core defines `api?` as `api || jwt`. [VERIFIED: `core.ex`]

**How to avoid:** Use separate `api?` and `jwt?` predicates in every file/injection/instruction branch; add negative assertions for both independent host trees. [VERIFIED: locked D-01]

### Pitfall 2: PAT endpoint authenticates using the credential it manages

**What goes wrong:** Current `/api/tokens` uses bearer authentication and API scopes, enabling bearer credential self-management rather than browser-session recent-auth protection. [VERIFIED: `core.ex`, `api_token_controller.ex`]

**How to avoid:** Emit browser/authenticated/sudo routes; require CSRF by using the normal browser pipeline; derive owner exclusively from current Scope. [VERIFIED: locked D-03/D-04]

### Pitfall 3: Valid signature with invalid JWT semantics

**What goes wrong:** Current `verify_access/2` calls `Joken.verify` then only checks `exp` and epoch. It does not require or validate issuer/audience/type/registered claims. [VERIFIED: `jwt.ex`]

**How to avoid:** Centralize signer verification, RequiredClaims, claim validators, `nbf` validation when present, and post-signature protected-header `typ` checking; test one failure per missing/malformed/mismatched field. [VERIFIED: locked D-07/D-08; CITED: https://hexdocs.pm/joken/Joken.Config.html]

### Pitfall 4: Claim builder overwrites security claims

**What goes wrong:** Existing `Map.merge(base_claims, extra)` allows a host claims builder to replace `sub`, `iss`, `exp`, `jti`, `aud`, or scopes. [VERIFIED: `jwt.ex`]

**How to avoid:** Merge custom claims first and overwrite with server-owned reserved claims, or reject reserved keys from the builder; add an explicit regression test. [VERIFIED: codebase inspection; locked D-06/D-07]

### Pitfall 5: Refresh race and false success

**What goes wrong:** Non-audited rotation classifies with `get_by`, then performs `update!` and `insert` outside a transaction; reuse family revocation is also separate. Concurrent callers can race before supersession is visible. [VERIFIED: `refresh_token.ex`, `jwt.ex`]

**How to avoid:** Lock the discovered refresh row inside the transaction, classify after lock, and mutate/commit before returning. Add deterministic two-process Postgres proof using barriers rather than sleeps. [VERIFIED: locked D-10/D-11]

### Pitfall 6: Testing generated templates only

**What goes wrong:** String assertions can prove that a template contains text while missing a broken injection/import/configuration path. [VERIFIED: Phase 243 verification; locked fresh-host requirement]

**How to avoid:** Retain source-contract tests but add separate `--api` and `--jwt` generated hosts that run install, migrations, compile, and a focused runtime smoke. [VERIFIED: locked context; existing generated-host test infrastructure]

## Code Examples

### Audience normalization and matching

```elixir
defp audience_matches?(aud, configured) when is_binary(aud), do: aud in configured

defp audience_matches?(aud, configured) when is_list(aud) and aud != [] do
  Enum.all?(aud, &is_binary/1) and Enum.any?(aud, &(&1 in configured))
end

defp audience_matches?(_, _), do: false
```

Use a non-empty, server-validated `configured` list. Equality is exact/case-sensitive because these are audience identifiers, not display text. [VERIFIED: locked D-09; CITED: https://www.rfc-editor.org/rfc/rfc7519]

### Owner-constrained revoke query

```elixir
from(token in api_token_schema,
  where: token.id == ^token_id and token.user_id == ^owner.id
)
|> repo.one()
|> case do
  nil -> {:error, :not_found}
  token -> revoke_loaded_token(config, token)
end
```

Return the same not-found outcome for another user’s ID; do not disclose ownership. The subsequent update/audit should preserve the current PAT transaction convention. [VERIFIED: locked D-04; `api_token.ex`]

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `--jwt` implies PAT files/config/routes | Independently generated `--api` and `--jwt` contracts | JWT-only hosts do not gain PAT facilities. [VERIFIED: locked D-01] |
| Generated email/password-to-JWT exchange and client scopes | Host-server policy calls JWT issuance with server-selected scopes | Removes credential grant and authority-selection surface. [VERIFIED: locked D-06; `token_controller.ex`] |
| Signature + exp/epoch only | Algorithm-bound verify plus required claims, issuer/audience/type and optional `nbf` checks | JWT acceptance matches the explicit host contract. [VERIFIED: locked D-07/D-08/D-09] |
| Audit-on refresh is atomic, audit-off is sequential | Both branches use a locked transaction | Consistent single-use/reuse safety regardless of audit configuration. [VERIFIED: locked D-10; `jwt.ex`] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A new dedicated browser PAT controller/template is preferable to adapting the existing JSON controller. | File Map | Low — discretionary presentation/module boundary; security routing and ownership are locked. |
| A2 | The replacement access JWT should be signed after refresh persistence commits. | Pattern 3 | Medium — avoids returning credentials on transaction failure, but planner should select the exact error/atomicity posture for signer failure. |

## Open Questions

1. **Which generated PAT presentation should be emitted?**
   - What we know: the current template is JSON/bearer CRUD, but locked decisions require browser/session/CSRF/sudo operations. [VERIFIED: `api_token_controller.ex`, locked D-03]
   - Recommendation: use a conventional controller + HTML/LiveView only if existing generator conventions make it low-risk; preserve deterministic browser tests and design-system constraints if UI is added. [ASSUMED]

2. **Where should accepted JWT audiences be normalized?**
   - What we know: D-09 permits config-validation or setup-time normalization but requires malformed config to fail before serving. [VERIFIED: locked context]
   - Recommendation: validate non-empty `:audiences` as a list of non-empty unique binaries in `Sigra.Config.new!/1`, then consume the normalized list in JWT code. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | compilation and test execution | ✓ | Mix 1.19.5 / OTP 28 | — [VERIFIED: local command] |
| Joken source/dependency | JWT contract tests | ✓ | 2.6.2 | — [VERIFIED: `mix.lock`, `deps/joken`] |
| PostgreSQL | transaction/fault-injection/concurrency tests and full suite | ✗ | configured local port was refused in Phase 243 evidence | Mox unit tests only; no substitute for atomicity proof. [VERIFIED: Phase 243 verification, `test/test_helper.exs`] |
| `phx_new` archive | fresh-host runtime lane | unknown locally | expected 1.8.8 | CI installs it; local runner should preflight and report skip/block deterministically. [VERIFIED: `test/test_helper.exs`] |

**Missing dependencies with no fallback:** a running PostgreSQL service for Phase 244 transaction/concurrency evidence. [VERIFIED: `test/test_helper.exs`; Phase 243 verification]

**Missing dependencies with fallback:** `phx_new` can be validated in CI after the test helper’s deterministic archive preflight. [VERIFIED: `test/test_helper.exs`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Mox for fast unit contracts; `Sigra.Test.PostgresCase` for persistence/concurrency; generated-host compile/runtime harness for installer truth. [VERIFIED: `test/test_helper.exs`, JWT tests, generated-host test files] |
| Config file | `test/test_helper.exs` — starts Postgres sandbox only when available and conditionally excludes only upgrade tests without `phx_new`. [VERIFIED: `test/test_helper.exs`] |
| Quick run command | `MIX_ENV=test mix test test/sigra/install/api_token_generator_test.exs test/sigra/install/features/core_test.exs test/sigra/api_token_test.exs test/sigra/api_token/scope_registry_test.exs test/sigra/jwt_test.exs test/sigra/jwt/refresh_token_test.exs test/sigra/jwt/signer_test.exs` |
| Full suite command | `MIX_ENV=test mix ci` — requires PostgreSQL and the `phx_new` archive for all runtime lanes. [VERIFIED: `test/test_helper.exs`, Phase 243 verification] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAT-01 | `--api` emits PAT schema/migration/config/Auth delegates/explicit `FetchAPIToken`, while `--jwt` does not | generator source contract + independent host compile/runtime | focused generator command plus generated-host test | ❌ Wave 0 |
| PAT-01 | Generated `--api` request authenticates a PAT into normal Scope | fresh-host integration smoke | phase generated-host command | ❌ Wave 0 |
| PAT-02 | Browser session + CSRF + `RequireSudo` gate list/create/revoke | generated router/controller integration | focused generated-host/browser test | ❌ Wave 0 |
| PAT-02 | Other user’s ID is indistinguishable from absent; params cannot choose owner; unregistered scopes fail | library/controller unit + integration | `mix test test/sigra/api_token_test.exs ...` | update |
| JWT-01 | Independent `--jwt` config compiles with no PAT artifacts or password exchange route | generator source contract + fresh host | phase generated-host command | ❌ Wave 0 |
| JWT-01 | exact alg/typ/iss/aud/sub/iat/exp/jti and optional `nbf` contract; scalar/array audience tests | JWT unit | `mix test test/sigra/jwt_test.exs test/sigra/jwt/signer_test.exs` | update |
| JWT-02 | host-only issuance does not accept password or request scopes | generator source contract | focused generator command | update |
| JWT-02 | audit-on and audit-off rotation/reuse are atomic, plus concurrent double refresh yields one rotation and one reuse outcome | Postgres integration + deterministic two-process barrier | `mix test test/sigra/jwt_refresh_audit_cofate_test.exs` | update |

### Fresh-Host Strategy

1. Add two independent generated-host lanes, never only a combined `--api --jwt` fixture. Each runs `mix sigra.install`, `mix ecto.migrate`, and compilation. [VERIFIED: locked D-01; existing generated-host test discovery]
2. API lane asserts PAT migration/schema/Auth delegates/config/router use `FetchAPIToken`; executes create then authenticates a PAT; asserts no JWT controller/config artifacts are required. [VERIFIED: locked D-01/D-02; Phase 243 verification]
3. JWT lane asserts only JWT configuration/host issuance seam is emitted; it compiles/runs strict access-token verification; asserts PAT files and password/MFA `/api/auth/token*` routes are absent. [VERIFIED: locked D-01/D-06/D-07]
4. Keep source-template assertions as fast regression guards, but treat successful fresh-host compile/runtime as the generator acceptance gate. [VERIFIED: Phase 243 verification]

### Transaction and Concurrency Proof

- Use a real Postgres test with two processes and explicit `send`/`receive` barriers around two refresh calls for the same raw token; do not use sleeps. [VERIFIED: `AGENTS.md` deterministic-test constraint; locked D-10]
- Assert exactly one caller receives replacement credentials. The other must either observe the consumed record and return `reuse_detected` after the family revoke commits, or return the documented abort error if deliberately fault-injected. [VERIFIED: locked D-10/D-11]
- Assert family rows are superseded, no orphan replacement appears after transaction failure, and audit-on has exactly one matching audit row; repeat the same atomicity assertions audit-off. [VERIFIED: `jwt_refresh_audit_cofate_test.exs`; locked D-10]
- Fault-inject audit constraint failure and persistence failure; verify rollback produces no access/refresh response. Existing audit-on tests are an extension point, not sufficient evidence for audit-off or concurrency. [VERIFIED: `jwt_refresh_audit_cofate_test.exs`, `jwt.ex`]

### Sampling Rate

- **Per task commit:** quick run command plus the touched source-contract test. [VERIFIED: project test layout]
- **Per wave merge:** affected Postgres integration tests and both generated-host lanes. [VERIFIED: phase requirements]
- **Phase gate:** `MIX_ENV=test mix ci` green with machine-readable fresh-host and transaction evidence; do not replace it with manual UAT. [VERIFIED: `AGENTS.md`, config Nyquist enabled]

### Wave 0 Gaps

- [ ] A Phase 244 generated-host runtime test with separate API and JWT lanes.
- [ ] Generator negative assertions for `--api`/`--jwt` artifact and router/config separation.
- [ ] PAT owner-constrained revoke and browser/sudo/CSRF integration tests.
- [ ] JWT required-claim, type, issuer, scalar/array audience, `typ`, algorithm mismatch, `nbf`, and reserved-custom-claim tests.
- [ ] Non-audited rollback and concurrent refresh-family tests using real Postgres barriers.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Explicit PAT/JWT pipelines, configured signer verification, mandatory claims, live-user epoch validation. [VERIFIED: Phase 243 verification, locked D-07/D-08] |
| V3 Session Management | yes | Browser CSRF/session plus recent sudo gate for PAT management; opaque refresh family rotation/reuse revocation. [VERIFIED: `require_sudo.ex`, locked D-03/D-10/D-11] |
| V4 Access Control | yes | Scope-derived owner and `id + user_id` revoke predicate; server allowlists scopes/audiences. [VERIFIED: locked D-04/D-05/D-09] |
| V5 Input Validation | yes | Config validates audiences/type; library validates PAT scopes; JWT values/types fail closed. [VERIFIED: `config.ex`, `scope_registry.ex`, locked D-07/D-09] |
| V6 Cryptography | yes | Joken configured signer and existing digest-backed PAT/refresh storage; no custom JWT crypto. [VERIFIED: `signer.ex`, `api_token.ex`, `refresh_token.ex`] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-account PAT revocation | Elevation of Privilege | Derive owner from Scope and query on token ID plus owner ID. [VERIFIED: locked D-04] |
| Recursive bearer credential management | Elevation of Privilege | Browser/session/CSRF/sudo management boundary, not bearer API. [VERIFIED: locked D-03] |
| JWT algorithm/type/audience confusion | Spoofing | Configured signer, verify-before-header inspection, exact typ/issuer/audience contract. [VERIFIED: locked D-07/D-08/D-09; CITED: https://www.rfc-editor.org/rfc/rfc8725] |
| Client-selected authority | Tampering | Host-only issuance API; ignore request-selected scopes and remove password exchange endpoint. [VERIFIED: locked D-06] |
| Refresh replay race | Repudiation / Elevation of Privilege | Locked transaction serializes classification, rotate, and family revocation. [VERIFIED: locked D-10/D-11] |
| Raw credential disclosure | Information Disclosure | Existing digest-backed PAT/refresh records; return raw token once only and avoid logging. [VERIFIED: `api_token.ex`, `refresh_token.ex`] |

## Sources

### Primary (HIGH confidence)

- Sigra code and locked dependency source: `lib/sigra/install/features/core.ex`, `lib/sigra/api_token.ex`, `lib/sigra/jwt.ex`, `lib/sigra/jwt/refresh_token.ex`, `lib/sigra/config.ex`, and `deps/joken/lib/joken/*`.
- Locked phase decisions: `.planning/phases/244-pat-and-advanced-jwt-truth-repair/244-CONTEXT.md`.
- Existing test evidence: `test/sigra/jwt_test.exs`, `test/sigra/jwt_refresh_audit_cofate_test.exs`, `test/sigra/install/api_token_generator_test.exs`, and Phase 243 verification.

### Secondary (MEDIUM confidence)

- [Joken 2.6.2 API](https://hexdocs.pm/joken/Joken.html) — verify/validate separation and protected-header caveat.
- [Joken signer](https://hexdocs.pm/joken/Joken.Signer.html) — configured signer verification.
- [Joken RequiredClaims](https://hexdocs.pm/joken/Joken.Hooks.RequiredClaims.html) — required payload presence hook.

### Tertiary (LOW confidence)

- [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519) and [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725) were located through web search; their locked-context conclusions are additionally reflected in the phase decisions.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are already locked in this repository and inspected locally.
- Architecture: HIGH — the primary behavior is locked by CONTEXT.md and exposes direct current-code gaps.
- Pitfalls: HIGH — each is either a direct code-path mismatch or an explicit security decision; UI presentation remains discretionary.

**Research date:** 2026-08-12  
**Valid until:** 2026-09-11
