# Phase 243: Credential Boundary and Pipeline Foundation - Context

**Gathered:** 2026-08-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Define the normative Sigra/Lockspire/Crosswake/host ownership seam and introduce explicit authentication pipelines that construct the host's normal current-user Scope while storing credential facts separately. This phase establishes the contract and reusable plug foundation; it does not repair generator output or add app-session persistence.

</domain>

<decisions>
## Implementation Decisions

### Ownership contract
- Sigra owns first-party identities, credentials, inbound provider ceremonies, browser sessions, app sessions, assurance, and revocation.
- Lockspire owns OAuth/OIDC authorization-server behavior for registered external clients, including consent, codes, delegated access tokens, discovery, JWKS, and token exchange.
- Crosswake owns route/runtime and offline-island policy and consumes backend-projected authentication facts; it never receives credentials or becomes authentication authority.
- The Phoenix host owns client registration configuration, product authorization, media/CDN/cache/lease policy, account-to-scope mapping, and replay decisions.

### Pipeline surface
- Public explicit plugs are `Sigra.Plug.FetchAppSession`, `Sigra.Plug.FetchAPIToken`, and `Sigra.Plug.FetchJWT`; the existing `FetchSession` remains the browser-cookie path.
- `Sigra.Plug.FetchBearer` remains temporarily as a deprecated compatibility dispatcher for already-installed hosts, but new generated code and primary documentation never use token-shape autodetection.
- Each explicit plug accepts the established `:config`, `:scope_module`, and error-handler conventions where applicable and skips only when an authenticated Scope is already present.

### Scope and credential metadata
- Every credential path loads the current user record and constructs the host's normal Scope through `Sigra.Scope.build/3`; no token-only map is passed to the host's `Scope.new/1`.
- Credential facts live in `conn.private[:sigra_auth]` with a stable shape containing credential kind, credential identifier, server-selected scopes when applicable, session/family reference when applicable, and authentication method/assurance facts.
- Secret values, raw tokens, stable external device identifiers, and unbounded client input never enter assigns, private metadata, telemetry, or logs.
- `RequireScopes` reads only trusted credential metadata and fails closed for missing/unscoped credentials; app sessions establish identity and assurance, not delegated authorization scopes.

### Compatibility
- Browser-session behavior and existing host Scope modules remain source-compatible.
- Direct callers of `FetchBearer` receive deprecation guidance and deterministic legacy behavior until a future declared removal; this phase does not silently rewrite adopter routers.
- Public docs distinguish first-party authentication from Lockspire delegation and describe explicit mixed-mode pipelines rather than implicit fallback.

### the agent's Discretion
- Exact internal module factoring, helper names, telemetry event additions, and deprecation wording may follow existing Sigra conventions as long as the public contract above holds.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Scope.build/3` already builds host Scope structs without requiring token-only fields.
- `Sigra.Plug.FetchSession`, `RequireAuthenticated`, `RequireScopes`, and `ErrorHandler` provide established Plug behavior and error conventions.
- `Sigra.APIToken.verify/2` and `Sigra.JWT.verify_access/2` remain the credential-specific verification cores.

### Established Patterns
- Public configuration is normalized through `Sigra.Config`.
- Security-relevant behavior remains library-owned while generated routers/configuration are host-owned.
- Tests favor DB-free plug contracts plus generated-host source/runtime coverage.

### Integration Points
- `lib/sigra/plug/` for explicit plugs and shared authentication metadata helpers.
- `lib/sigra/scope.ex` for normal Scope construction.
- `lib/sigra/install/features/core.ex` and public API-auth guides consume this foundation in Phase 244 and later.

</code_context>

<specifics>
## Specific Ideas

The contract must close the current failure where generated `FetchBearer` lacks required options and constructs Scope using `%{id: ..., token_scopes: ...}`. Explicit credential pipelines and private metadata are the chosen correction.

</specifics>

<deferred>
## Deferred Ideas

- Complete PAT/JWT generator/configuration repair belongs to Phase 244.
- Opaque app-session storage and verification belongs to Phase 245.
- Hosted/direct native login and new installer flags belong to Phase 246.

</deferred>
