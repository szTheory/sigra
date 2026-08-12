# Phase 244: PAT and Advanced JWT Truth Repair - Context

**Gathered:** 2026-08-12 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the existing `--api` personal-access-token and `--jwt` advanced-JWT capabilities independently generatable, secure, and truthful. This phase owns fresh-host emission, PAT self-management, JWT claim validation and server-scoped issuance, and atomic JWT refresh-family behavior. It does not add app sessions, native login, OAuth/OIDC authorization-server behavior, or client/offline SDKs.
</domain>

<decisions>
## Implementation Decisions

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
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 244 goal and success criteria.
- `.planning/REQUIREMENTS.md` — PAT-01, PAT-02, JWT-01, and JWT-02 contracts.
- `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-CONTEXT.md` — explicit pipeline and ownership decisions.
- `lib/sigra/install/features/core.ex` — current coupled generator gates, injections, and routes.
- `priv/templates/sigra.install/core/api_token_controller.ex` — current PAT management surface.
- `priv/templates/sigra.install/core/token_controller.ex` — current password-to-JWT and request-scope surface to remove.
- `lib/sigra/auth.ex` and `lib/sigra/api_token.ex` — PAT public API and persistence boundary.
- `lib/sigra/jwt.ex`, `lib/sigra/jwt/signer.ex`, and `lib/sigra/jwt/refresh_token.ex` — claim, signature, and refresh-family implementation.
- `lib/sigra/config.ex` — public configuration validation contract.
- RFC 7519 sections 4.1.3 and 5.1 — audience and JOSE `typ` semantics.
- RFC 8725 sections 3.1, 3.9, and 3.11 — algorithm verification, audience validation, and explicit typing best current practices.
- Joken 2.6.2 `Joken.Signer`, `Joken.Hooks.RequiredClaims`, and hooks APIs — version-locked verification behavior.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 243 provides `FetchAPIToken`, `FetchJWT`, `CredentialAuth`, and trusted `RequireScopes` metadata.
- `RequireSudo` and the generated browser/authenticated pipelines already provide the recent-auth and CSRF-compatible management boundary.
- Existing PAT schemas, migrations, Auth delegates, and JWT refresh modules are repairable substrate rather than greenfield replacements.
- Existing generator source contracts and fresh-host smokes can be extended to prove independent feature output.

### Established Patterns
- Library code owns security-critical verification and lifecycle semantics; generators emit host-owned schemas, configuration, routes, and presentation.
- Credential verification reloads the live host user and builds the normal Scope; authority metadata is a bounded separate private map.
- Sensitive mutations use `Ecto.Multi` so audit and business state share one transaction.
- Generated-host claims require fresh-host compile/runtime evidence, not template-string inspection alone.

### Integration Points
- Split feature predicates and injections in `Sigra.Install.Features.Core` without changing unrelated installer flags.
- Move PAT management under generated browser/authenticated/recent-auth pipelines and add owner-constrained library calls.
- Extend `Sigra.Config` and JWT claim construction/verification for issuer, audience, type, and required-claim semantics.
- Replace non-audited refresh bang-operation sequences with the same transactional boundary used by audited paths.
</code_context>

<specifics>
## Specific Ideas

- Treat advanced JWTs as a power-user capability, not the default mobile/session answer.
- A copied generated host must not receive recursive bearer-token management or a password-to-JWT exchange endpoint.
- Proof should include truly independent `--api` and `--jwt` fresh hosts, not only combined-generation fixtures.
</specifics>

<deferred>
## Deferred Ideas

- Opaque app sessions and first-party native login remain Phases 245-246.
- OAuth/OIDC authorization-server behavior remains Lockspire's responsibility.
- Published native SDKs and generalized offline behavior remain outside this milestone.

### Reviewed Todos (not folded)

None — no matching open todos were found.
</deferred>
