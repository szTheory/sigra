# Phase 239: Hosted Session Interop - Context

**Gathered:** 2026-08-08 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the fail-closed SIGRA-to-Crosswake backend-session boundary for the canonical personal-account B2C host. The phase delivers a server-validated session projection to `crosswake_sigra`, personal-account scope without invented organization authority, a strict return-evidence boundary, and deterministic denial proof for replay and changed authority state. It does not add organizations, passkeys, MFA, native/deep-link authority, provider credentials, or an adopter/device run.
</domain>

<decisions>
## Implementation Decisions

### Personal-account Crosswake contract
- **D-01:** Update the `crosswake_sigra` public contract so a `SessionAuthorityLane` and its enclosing `AuthContext` can represent a personal account with `org_id: nil`. A nonblank `org_id` remains required when an organization-scoped session is actually supplied; no sentinel, default, or fabricated organization is permitted.
- **D-02:** Keep `session_ref` and `subject_ref` opaque, server-owned references. The projection supplies the lane facts Crosswake needs—including session state, assurance/authentication facts, timestamps, version, and `as_of`—without exposing a raw session token, credential, provider payload, or OAuth token.

### Server-owned authority and replay
- **D-03:** The SIGRA host must resolve and revalidate the current backend `user_sessions` record and its user before every projection/evaluation. The Crosswake evaluator is a pure consumer of supplied authority facts, not a substitute for SIGRA storage validation.
- **D-04:** Bind every projection/replay to the currently resolved `session_ref` and `subject_ref`; a missing, deleted/revoked, expired, non-active, stale-version, or subject/session-mismatched state denies. Account-switch handling must be explicit at the host adapter boundary, because released Crosswake v0.1.1 has no native account-switch denial.

### Return evidence boundary and proof
- **D-05:** OAuth callback and hosted-return data are evidence/navigation only. They cannot be used as a session reference or independently grant a Crosswake route/replay; Crosswake-facing envelopes keep only approved opaque reference fields.
- **D-06:** Add deterministic contract/evaluator proof for both valid personal (`org_id: nil`) and organization-scoped values, invalid blank organization IDs, missing/revoked/expired/version-mismatched state, account/session switch denial, and the fact that return evidence alone cannot admit access.

### the agent's Discretion
- Choose the smallest backward-compatible Crosswake type/validation change and any required release/versioning process for that companion package.
- Reuse the repository's session-fetching, expiry cleanup, logout/revocation, and deterministic test conventions; select precise internal helper and denial-code names while preserving the locked outcomes above.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and generated-host boundary
- `.planning/ROADMAP.md` — Phase 239 goal, dependency, and success criteria.
- `.planning/REQUIREMENTS.md` — XW-01 and XW-02 acceptance requirements.
- `.planning/phases/237-canonical-b2c-generator-contract/237-CONTEXT.md` — canonical B2C profile and its explicit `org_id: nil` boundary.
- `.planning/phases/238-generated-auth-runtime-proof/238-CONTEXT.md` — generated-host security and no-secrets proof boundary.
- `guides/recipes/b2c-alpha.md` — authoritative hosted-session/Crosswake behavior and evidence boundary.

### SIGRA session authority
- `priv/templates/sigra.install/core/auth.ex` — generated host's canonical session lookup from hashed token to session/user.
- `priv/templates/sigra.install/core/user_auth.ex` — session creation, logout, and scope hydration behavior.
- `lib/sigra/session.ex` — session representation and raw-token handling.
- `lib/sigra/session_stores/ecto.ex` — persisted session-store contract.
- `lib/sigra/plug/fetch_session.ex` — missing/expired session handling and fail-closed scope construction.
- `lib/sigra/plug/require_authenticated.ex` — authorization halt on absent scope.
- `lib/sigra/auth.ex` — session revocation and organization-aware session behavior.
- `test/sigra/auth_org_selection_test.exs` — active-organization session precedent that the B2C profile must avoid.

### Crosswake companion contract (external primary sources)
- `https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex` — released lane/AuthContext validation, including the incompatible required-string `org_id` rule to change.
- `https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex` — pure evaluator and explicit fail-closed outcomes.
- `https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex` — reference-only return-evidence boundary.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The generated `auth.ex` and `user_auth.ex` templates already supply the authoritative session lookup, logout, and scope seam that the host adapter must consume.
- `Sigra.Plug.FetchSession` and `Sigra.Plug.RequireAuthenticated` demonstrate nil-scope fail-closed handling, including expiry cleanup.
- Existing Ecto session storage persists only a token hash; fetched session records do not carry the raw token.

### Established Patterns
- SIGRA sessions are server-authoritative: a raw browser token is only a lookup credential and does not survive as a fetched record field.
- Session expiry and absent storage records produce no authenticated scope; logout and password reset remove canonical server-session state.
- Organization-aware session behavior exists for organization profiles, so the canonical B2C implementation must deliberately take the personal, no-hydration branch.

### Integration Points
- The host-owned SIGRA adapter projects freshly resolved session/user facts into Crosswake's `SessionAuthorityLane` before each route/replay decision.
- Crosswake v0.1.1 currently rejects the locked personal scope, so companion-package contract work is an implementation dependency rather than a reason to synthesize organization authority.
</code_context>

<specifics>
## Specific Ideas

- User approved the recommended Crosswake contract change after receiving a handoff prompt for the Crosswake LLM session.
- Do not use a sentinel such as `"personal"` or `"default-org"`; this would falsely manufacture organization scope.
- The Crosswake handoff explicitly requires backward compatibility for organization sessions and reference-only evidence transport.
</specifics>

<deferred>
## Deferred Ideas

- Runtime/boot-time auth-schema prefix override remains a separate configuration capability; the user chose not to fold it into Phase 239.
- The other 31 todo matches were keyword-only or belong to installer, auth-UI, admin, security, CI, release, or evidence lanes rather than Crosswake interop.
- Real iPhone, production OAuth, email-provider, and adopter-host proof remain Phase 240/staging launch gates.
</deferred>

---

*Phase: 239-hosted-session-interop*
*Context gathered: 2026-08-08*
