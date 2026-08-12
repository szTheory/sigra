# Phase 243: Credential Boundary and Pipeline Foundation - Research

**Researched:** 2026-08-12
**Domain:** Phoenix/Plug authentication-pipeline boundary and public contract
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Sigra owns first-party identities, credentials, inbound provider ceremonies, browser sessions, app sessions, assurance, and revocation.
- Lockspire owns OAuth/OIDC authorization-server behavior for registered external clients, including consent, codes, delegated access tokens, discovery, JWKS, and token exchange.
- Crosswake owns route/runtime and offline-island policy and consumes backend-projected authentication facts; it never receives credentials or becomes authentication authority.
- The Phoenix host owns client registration configuration, product authorization, media/CDN/cache/lease policy, account-to-scope mapping, and replay decisions.
- Public explicit plugs are Sigra.Plug.FetchAppSession, Sigra.Plug.FetchAPIToken, and Sigra.Plug.FetchJWT; the existing FetchSession remains the browser-cookie path.
- Sigra.Plug.FetchBearer remains temporarily as a deprecated compatibility dispatcher for already-installed hosts, but new generated code and primary documentation never use token-shape autodetection.
- Each explicit plug accepts the established :config, :scope_module, and error-handler conventions where applicable and skips only when an authenticated Scope is already present.
- Every credential path loads the current user record and constructs the host's normal Scope through Sigra.Scope.build/3; no token-only map is passed to the host's Scope.new/1.
- Credential facts live in conn.private[:sigra_auth] with a stable shape containing credential kind, credential identifier, server-selected scopes when applicable, session/family reference when applicable, and authentication method/assurance facts.
- Secret values, raw tokens, stable external device identifiers, and unbounded client input never enter assigns, private metadata, telemetry, or logs.
- RequireScopes reads only trusted credential metadata and fails closed for missing/unscoped credentials; app sessions establish identity and assurance, not delegated authorization scopes.
- Browser-session behavior and existing host Scope modules remain source-compatible.
- Direct callers of FetchBearer receive deprecation guidance and deterministic legacy behavior until a future declared removal; this phase does not silently rewrite adopter routers.
- Public docs distinguish first-party authentication from Lockspire delegation and describe explicit mixed-mode pipelines rather than implicit fallback.

### the agent's Discretion
- Exact internal module factoring, helper names, telemetry event additions, and deprecation wording may follow existing Sigra conventions as long as the public contract above holds.

### Deferred Ideas (OUT OF SCOPE)
- Complete PAT/JWT generator/configuration repair belongs to Phase 244.
- Opaque app-session storage and verification belongs to Phase 245.
- Hosted/direct native login and new installer flags belong to Phase 246.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOUND-01 | A Phoenix adopter can determine from one normative contract whether Sigra, Lockspire, Crosswake, or the host owns each identity, session, delegation, runtime, authorization, media, lease, and replay concern. | Add ownership table and request-flow diagram to public contract; align Lockspire recipe and API-authentication guide. |
| API-01 | A host can select explicit cookie-session, app-session, personal-access-token, or JWT authentication pipelines that load the normal current user Scope while keeping credential metadata separate and failing closed for incompatible scope checks. | Add explicit public plugs and shared Scope/metadata seam; RequireScopes reads only private metadata; FetchBearer remains dispatcher. |
</phase_requirements>

## Summary

Phase 243 corrects the implicit bearer boundary without attempting deferred generator repair or app-session persistence. Current FetchBearer identifies a header from raw token prefixes and calls scope_module.new/1 with a token-only map. That is incompatible with generated host Scope modules, which accept a real User struct and expose user, organization, membership, and impersonation fields. [VERIFIED: codebase inspection — lib/sigra/plug/fetch_bearer.ex; priv/templates/sigra.install/core/scope.ex]

Use a shared internal seam: verify exactly one credential format; resolve the current user with config.repo.get(config.user_schema, user_id); build normal scope with Sigra.Scope.build(scope_module, user); write only allowlisted facts to conn.private[:sigra_auth]. Plug documents conn.private as library/framework storage that avoids user-facing assigns and recommends library-prefixed keys. [CITED: https://plug.hexdocs.pm/Plug.Conn.html]

The tracer is explicit PAT authentication: its verifier already returns a token with user_id, scopes, and ID, while focused plug tests are Mox-backed and DB-free. Then rewrite RequireScopes to consume private facts and fail closed. Add JWT through the same seam. FetchAppSession is a fail-closed public foundation only until Phase 245 supplies opaque storage, and no generator repair occurs before Phase 244. [VERIFIED: codebase inspection — lib/sigra/api_token.ex; lib/sigra/jwt.ex; test/sigra/plug; VERIFIED: phase context — 243-CONTEXT.md]

**Primary recommendation:** Build a private credential-to-normal-Scope helper; complete and test the PAT tracer first; then attach RequireScopes, JWT/app-session surface, legacy compatibility, and normative documentation.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Credential verification, user lookup, Scope construction | API / Backend | Database / Storage | Sigra plugs authenticate through host Repo and emit host Scope. [VERIFIED: codebase inspection — lib/sigra/config.ex; fetch_bearer.ex] |
| Browser cookie session | Frontend Server (SSR) | Database / Storage | FetchSession reads Plug session and configured session store. [VERIFIED: codebase inspection — fetch_session.ex] |
| First-party app-session contract | API / Backend | Database / Storage | Public explicit plug now; opaque verifier is Phase 245. [VERIFIED: phase context — 243-CONTEXT.md] |
| OAuth/OIDC authorization server | API / Backend | — | Lockspire owns external-client consent, codes, delegated tokens, discovery, JWKS, and exchange. [VERIFIED: phase context — 243-CONTEXT.md] |
| Route/offline runtime policy | Browser / Client | API / Backend | Crosswake consumes projected facts only; host retains policy and replay decisions. [VERIFIED: phase context — 243-CONTEXT.md] |
| Product authorization, media/cache/lease/replay | API / Backend | CDN / Static | Explicitly host-owned product policy, not credential pipeline work. [VERIFIED: phase context — 243-CONTEXT.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Sigra + Plug | existing, plug ~> 1.16 | Public plugs and request state | Extends current APIs; no new dependency. [VERIFIED: codebase inspection — mix.exs; lib/sigra/plug] |
| Ecto Repo via Sigra.Config | existing | Live-user lookup | Config supplies repo/user_schema; JWT epoch validation already uses repo.get. [VERIFIED: codebase inspection — config.ex; jwt.ex] |
| Sigra.Scope.build/3 | existing | Normal generated host Scope | Reflects supported Scope fields. [VERIFIED: codebase inspection — scope.ex] |
| ExUnit + Mox + Plug.Test | existing | Deterministic plug tests | Existing focused suite passed 41 tests. [VERIFIED: test run, 2026-08-12] |

### Supporting

| Library | Purpose | When to Use |
|---------|---------|-------------|
| Sigra.APIToken.verify/2 | PAT verification | FetchAPIToken only. [VERIFIED: api_token.ex] |
| Sigra.JWT.verify_access/2 | Signature/expiry/epoch validation | FetchJWT only; never token-shape inference. [VERIFIED: jwt.ex] |
| Sigra.Plug.ErrorHandler | Host error convention | Preserve current handler/halt behavior. [VERIFIED: error_handler.ex] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit plugs | Prefix/eyJ autodetection | Rejected by locked decision; current dispatcher causes confusion. [VERIFIED: 243-CONTEXT.md; fetch_bearer.ex] |
| private sigra_auth facts | Credential fields in Scope | Rejected; credential facts are request metadata, not host identity Scope. [CITED: https://plug.hexdocs.pm/Plug.Conn.html] |
| Live user plus Scope.build/3 | Token-only Scope.new map | Rejected; generated Scope.new pattern-matches host User. [VERIFIED: 243-CONTEXT.md; scope template] |

**Installation:** None. [VERIFIED: phase context — 243-CONTEXT.md]

## Package Legitimacy Audit

No external packages are installed; package legitimacy gate is not applicable. [VERIFIED: phase context — 243-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

    Browser/API client
      -> host-selected explicit pipeline
      -> FetchSession | FetchAppSession | FetchAPIToken | FetchJWT
      -> verifier-specific result
      -> load host user from Repo
      -> Sigra.Scope.build/3 assigns current_scope
      -> conn.private[:sigra_auth] has bounded credential facts
      -> RequireAuthenticated and host product policy
      -> RequireScopes consumes facts only
      -> Lockspire receives authenticated user for delegation
      -> Crosswake receives backend-projected runtime facts only

FetchBearer is a deprecated compatibility dispatcher into the explicit internals. This diagram does not promise router generation: Phase 244 owns generator repair, Phase 245 app-session storage, and Phase 246 native ceremonies. [VERIFIED: phase context — 243-CONTEXT.md]

### Recommended Project Structure

    lib/sigra/plug/
      fetch_session.ex        existing browser path
      fetch_api_token.ex      explicit PAT path
      fetch_jwt.ex            explicit JWT path
      fetch_app_session.ex    public fail-closed foundation
      fetch_bearer.ex         deprecated dispatcher
      credential_auth.ex      recommended private shared helper
      require_scopes.ex       reads private trusted facts
    test/sigra/plug/
      fetch_api_token_test.exs
      fetch_jwt_test.exs
      fetch_app_session_test.exs
      fetch_bearer_test.exs
      fetch_session_test.exs
      require_scopes_test.exs
    guides/
      introduction/contract.md
      flows/api-authentication.md
      recipes/companion-libs/lockspire.md

Exact helper name is discretionary; keep it private to avoid an accidental extension API. [ASSUMED]

### Pattern 1: Explicit verifier -> live user -> normal Scope -> bounded facts

Each fetcher handles one credential type, delegates to existing verifier, loads host user, calls Scope.build/3, and writes a fresh allowlisted facts map. Every explicit fetcher skips only when an authenticated Scope already exists. [VERIFIED: phase context — 243-CONTEXT.md]

    case config.repo.get(config.user_schema, user_id) do
      nil -> Plug.Conn.assign(conn, :current_scope, nil)
      user ->
        conn
        |> Plug.Conn.assign(:current_scope, Sigra.Scope.build(scope_module, user))
        |> Plug.Conn.put_private(:sigra_auth, facts)
    end

Required facts: credential_kind, credential_id, server-selected scopes when applicable, session_or_family_id when applicable, auth_method, and assurance facts. Omit inapplicable fields. Never include raw tokens, secrets, stable external device IDs, or unbounded input. [VERIFIED: phase context — 243-CONTEXT.md]

### Pattern 2: RequireScopes reads facts, never Scope shape

| current_scope | private credential facts | Result |
|---|---|---|
| nil | any | unauthenticated, error handler, halt |
| normal Scope | missing/unscoped session facts | insufficient scope, error handler, halt |
| normal Scope | PAT/JWT matching scopes or wildcard | pass |
| normal Scope | PAT/JWT missing/nonmatching scopes | insufficient scope, error handler, halt |

This replaces current scope.auth_method/scope.token_scopes session bypass, fields not owned by generated Scope. [VERIFIED: codebase inspection — require_scopes.ex; scope template]

### Pattern 3: Compatibility dispatcher remains deterministic

Keep FetchBearer for installed routers. Mark its public documentation deprecated, preserve deterministic legacy routing, and use the shared normal-Scope helper after verification. Elixir supports compiler-warning deprecation for functions/macros through @deprecated and documentation deprecation through @doc deprecated. [CITED: https://elixir.hexdocs.pm/main/Module.html]

### Anti-Patterns to Avoid

- New token-shape routing: host names the credential path. [VERIFIED: 243-CONTEXT.md]
- Token-only Scope maps: never call generated Scope constructor with id/token_scopes map. [VERIFIED: fetch_bearer.ex; scope template]
- Scope checks from assigns/client input: consume only verifier-produced private facts. [VERIFIED: 243-CONTEXT.md]
- Silent router rewrite: Phase 243 does not repair generator output. [VERIFIED: 243-CONTEXT.md]
- Premature app-session system: no opaque schema, families, device IDs, or native endpoints. [VERIFIED: 243-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PAT validation/revocation/expiry | second token parser | Sigra.APIToken.verify/2 | Existing hash lookup/state checking. [VERIFIED: api_token.ex] |
| JWT validation | custom decoder/classifier | Sigra.JWT.verify_access/2 in FetchJWT | Existing signature/expiry/epoch checks. [VERIFIED: jwt.ex] |
| Host Scope construction | ad-hoc Scope.new payload | Sigra.Scope.build/3 | Preserves generated Scope contract. [VERIFIED: scope.ex] |
| Error responses | per-plug response behavior | Sigra.Plug.ErrorHandler | Maintains host control and consistency. [VERIFIED: error_handler.ex] |

**Key insight:** This is composition/boundary work, not token cryptography work. [VERIFIED: api_token.ex; jwt.ex]

## Common Pitfalls

### Pitfall 1: Truthy but invalid Scope

RequireAuthenticated accepts any truthy map, but generated code and Lockspire resolver expect scope.user. Current FetchBearer produces the bad shape. [VERIFIED: require_authenticated.ex; fetch_bearer.ex; Lockspire recipe]

Avoid: load user after verification; missing user becomes nil Scope; use Scope.build/3 only. [VERIFIED: 243-CONTEXT.md]

### Pitfall 2: Retaining session bypass

Current RequireScopes lets auth_method session pass. App/browser sessions establish identity, not delegated authorization. Read private facts only and fail closed when absent/unscoped. [VERIFIED: require_scopes.ex; 243-CONTEXT.md]

### Pitfall 3: User-ID type mismatch

JWT sub is stringified while PAT user_id is Ecto-native. Pass verifier identity directly to repo.get and test integer PAT plus string JWT subject. [VERIFIED: jwt.ex; api_token.ex; jwt_test.exs]

### Pitfall 4: Metadata leakage

Build a fresh allowlisted facts map; assert raw bearer/JWT/refresh tokens and device identifiers are absent from assigns/private data, telemetry, and logs. [VERIFIED: 243-CONTEXT.md; ASSUMED: exact source-level regression-test form]

### Pitfall 5: Compatibility break

Do not change FetchBearer interface or silently update routers; current generator lacks required options and Phase 244 owns that repair. [VERIFIED: 243-CONTEXT.md; lib/sigra/install/features/core.ex]

## Code Examples

### Explicit PAT pipeline

    pipeline :api_pat do
      plug :accepts, ["json"]
      plug Sigra.Plug.FetchAPIToken,
        config: MyApp.Auth.sigra_config(),
        scope_module: MyApp.Accounts.Scope
      plug Sigra.Plug.RequireAuthenticated,
        error_handler: MyAppWeb.AuthErrorHandler
    end

### Explicit mixed cookie/PAT pipeline

    pipeline :api_browser_or_pat do
      plug Sigra.Plug.FetchSession,
        config: MyApp.Auth.sigra_config(),
        scope_module: MyApp.Accounts.Scope
      plug Sigra.Plug.FetchAPIToken,
        config: MyApp.Auth.sigra_config(),
        scope_module: MyApp.Accounts.Scope
    end

Order is host policy: the first successful normal Scope wins because later fetchers skip. [VERIFIED: 243-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| FetchBearer detects token shape and writes credential fields into Scope | Host selects explicit plug; normal Scope plus private facts | Removes confusion and restores Scope compatibility. [VERIFIED: 243-CONTEXT.md; fetch_bearer.ex] |
| RequireScopes reads Scope fields and bypasses sessions | Reads private facts and fails closed | Session identity cannot imply scope authority. [VERIFIED: 243-CONTEXT.md; require_scopes.ex] |

**Deprecated/outdated:** FetchBearer as primary configuration. Retain as compatibility dispatcher. Rewrite primary API-guide implicit examples now; defer generator implementation to Phase 244. [VERIFIED: 243-CONTEXT.md; api-authentication.md; core.ex]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Private helper module is best factoring boundary. | Structure | Low; exact factoring is discretionary. |
| A2 | FetchAppSession should be fail-closed until Phase 245 storage. | Open Questions | Medium; planner must define public foundation semantics. |
| A3 | FetchSession should use Scope.build/3 now because every credential path is locked. | Open Questions | Medium; must preserve browser compatibility. |
| A4 | Source-level credential-leak regression-test form. | Pitfalls | Low; reuse stronger project convention if available. |

## Open Questions

1. **FetchAppSession before Phase 245**
   - Known: public plug is locked; opaque storage/verification is deferred. [VERIFIED: 243-CONTEXT.md]
   - Recommendation: fail closed, no raw-token state/fallback, document future verifier seam, no schema/config/generator work. [ASSUMED]

2. **FetchSession normal Scope correction**
   - Known: locked wording says every credential path uses Scope.build/3; current library FetchSession calls scope_module.new with id map while generated UserAuth already loads full user. [VERIFIED: 243-CONTEXT.md; fetch_session.ex; test/example/lib/example_web/user_auth.ex]
   - Recommendation: include compatibility-preserving correction in shared-helper task. If scope pressure occurs, surface a decision checkpoint instead of retaining divergent contracts. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | compile/focused tests | ✓ | Mix 1.19.5 | — [VERIFIED: local command] |
| Erlang/OTP | runtime | ✓ | OTP 28 | — [VERIFIED: local command] |
| Existing dependencies | Plug/Mox tests | ✓ | build and deps present | — [VERIFIED: local filesystem] |
| Local PostgreSQL | full suite boot | ✗ | configured port refused | Focused Mox tests; full gate needs normal DB service. [VERIFIED: test run] |

**Missing dependencies with no fallback:** local PostgreSQL for complete root suite. [VERIFIED: test helper and test run]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Mox + Plug.Test [VERIFIED: test helper and plug tests] |
| Config file | test/test_helper.exs [VERIFIED: codebase inspection] |
| Quick run command | MIX_ENV=test mix test test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_bearer_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_scopes_test.exs test/sigra/scope/build_test.exs |
| Full suite command | MIX_ENV=test mix ci; needs PostgreSQL and phx_new archive. [VERIFIED: mix.exs; test helper] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOUND-01 | Ownership contract and no stale primary implicit copy | docs source test | MIX_ENV=test mix test test/sigra/credential_boundary_docs_test.exs | Wave 0 |
| API-01 | Explicit PAT yields normal Scope and bounded facts | unit plug/Mox | MIX_ENV=test mix test test/sigra/plug/fetch_api_token_test.exs | Wave 0 |
| API-01 | Explicit JWT validates/loads Scope and rejects deleted user | unit plug/Mox | MIX_ENV=test mix test test/sigra/plug/fetch_jwt_test.exs | Wave 0 |
| API-01 | App-session foundation fails closed/no credential state | unit plug/Mox | MIX_ENV=test mix test test/sigra/plug/fetch_app_session_test.exs | Wave 0 |
| API-01 | Cookie/legacy compatibility | unit plug/Mox | MIX_ENV=test mix test test/sigra/plug/fetch_session_test.exs test/sigra/plug/fetch_bearer_test.exs | update |
| API-01 | Scope gate trusts private facts only | unit plug | MIX_ENV=test mix test test/sigra/plug/require_scopes_test.exs | rewrite |

### Sampling Rate

- **Per task commit:** Quick command above; equivalent existing focused baseline passed 41 tests. [VERIFIED: test run]
- **Per wave merge:** MIX_ENV=test mix ci with DB prerequisites. [VERIFIED: mix.exs]
- **Phase gate:** Full suite green before verification.

### Wave 0 Gaps

- [ ] credential_boundary_docs_test.exs — BOUND-01 ownership/copy guard.
- [ ] fetch_api_token_test.exs — tracer: user, Scope, fact allowlist, failures, skip.
- [ ] fetch_jwt_test.exs — verified claims/string subject/missing user/no raw JWT.
- [ ] fetch_app_session_test.exs — fail-closed foundation.
- [ ] rewrite require_scopes_test.exs from Scope fields/session bypass to private-facts matrix.
- [ ] update fetch_bearer_test.exs to compatibility/deprecation behavior.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Explicit verifier, live user lookup, nil Scope on failure. [VERIFIED: phase context; api_token.ex; jwt.ex] |
| V3 Session Management | yes | Browser session retained; app-session persistence deferred. [VERIFIED: phase context] |
| V4 Access Control | yes | RequireScopes consumes trusted metadata and fails closed. [VERIFIED: phase context] |
| V5 Input Validation | yes | Explicit selected parser; no unbounded input in metadata. [VERIFIED: phase context] |
| V6 Cryptography | yes | Reuse PAT/JWT verifiers; no plug crypto. [VERIFIED: api_token.ex; jwt.ex] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credential confusion | Spoofing | Explicit selection; legacy dispatcher only. [VERIFIED: phase context] |
| Deleted user authenticated by claims | Spoofing | Live user lookup. [VERIFIED: phase context] |
| Session implies API scope | Elevation of Privilege | Private trusted facts; fail closed. [VERIFIED: phase context] |
| Raw credential/device data leak | Information Disclosure | Fresh allowlisted map; no assigns/logs/telemetry secrets. [VERIFIED: phase context] |
| Scope contract corruption | Tampering | Scope.build/3 only. [VERIFIED: phase context] |

## Tracer-First Build Order

1. **Wave 0:** Add docs and plug tests describing normal Scope and private facts.
2. **Tracer:** Add shared internal helper plus FetchAPIToken; prove PAT -> verifier -> loaded user -> Scope.build/3 -> facts -> RequireAuthenticated.
3. **Close tracer:** Rewrite RequireScopes; prove browser/app/unscoped requests are denied.
4. **Expand:** Add FetchJWT with same helper and fail-closed FetchAppSession; no persistence or ceremony work.
5. **Compatibility/docs:** Refactor FetchBearer deterministic dispatcher with deprecation guidance; align FetchSession if Open Question 2 resolves yes; update contract/API/Lockspire docs. [VERIFIED: phase context — 243-CONTEXT.md]

## Sources

### Primary (HIGH confidence)

- Sigra code: fetch_bearer, fetch_session, require_scopes, error_handler, scope, api_token, jwt, config.
- Sigra tests: test/sigra/plug, test/sigra/scope, test helper, and focused baseline evidence.
- Sigra docs: contract, architecture, API-authentication, Lockspire recipe.
- Locked phase context: 243-CONTEXT.md.

### Secondary (MEDIUM confidence)

- https://plug.hexdocs.pm/Plug.Conn.html — private library state convention.
- https://elixir.hexdocs.pm/main/Module.html — deprecation mechanics.

### Tertiary (LOW confidence)

- Assumptions A1-A4 only.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified existing runtime/testing components.
- Architecture: HIGH — locked decisions match current Scope/verifier/Plug seams.
- Pitfalls: HIGH — direct code/contract mismatches and locked security rules.

**Research date:** 2026-08-12
**Valid until:** 2026-09-11

