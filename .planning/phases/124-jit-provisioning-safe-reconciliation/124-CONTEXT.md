# Phase 124: JIT Provisioning & Safe Reconciliation - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Make successful enterprise login land in the correct organization membership without silently taking over the wrong account. This phase covers enterprise account resolution, membership reconciliation, fail-closed conflict handling, and post-success landing truth after the Phase 123 routed callback. It does not cover SSO-only enforcement, SCIM, hosted control-plane lifecycle automation, or broad authorization policy.

</domain>

<decisions>
## Implementation Decisions

### Account match policy
- **D-01:** Enterprise reconciliation resolves in this order: existing enterprise identity for the routed connection and provider subject, bounded existing-user auto-claim, then brand-new JIT user creation.
- **D-02:** Bounded auto-claim is allowed only when enterprise callback context is already revalidated, the IdP returned a verified email, normalized email matches exactly one Sigra user, and no conflicting enterprise identity or duplicate plausible match exists.
- **D-03:** Sigra must never silently claim an existing account by email alone when ownership is ambiguous. Any cross-principal conflict fails closed and visibly.
- **D-04:** Enterprise identity ownership is keyed to the routed enterprise connection plus stable provider subject; email is supportive evidence, not the durable identity anchor.

### Membership reconciliation
- **D-05:** Once the user principal is resolved safely, reuse existing membership if present, consume an exact pending invite if present, otherwise create a new organization membership just in time.
- **D-06:** Exact pending invite consumption requires the same resolved organization and exact normalized email match. Invites are weaker than the authenticated enterprise identity and must not override org routing.
- **D-07:** Default JIT-created membership role is `:member`.
- **D-08:** Membership reconciliation must reuse the current org and invitation substrate rather than bypassing it with enterprise-specific side paths.

### Failure and ambiguity rules
- **D-09:** Fail closed on enterprise callback context mismatch, stale or unavailable routed connection, provider subject to user A plus email to user B conflict, duplicate plausible local matches, or any case that would require silent email-only account linking.
- **D-10:** Future inactive membership states, if introduced later, must deny access rather than auto-reactivating on login.
- **D-11:** Failure reasons should be bounded and typed for code and audit purposes, while end-user copy stays truthful and non-leaky on generic surfaces.
- **D-12:** No enterprise callback failure path should silently downgrade into password, magic-link, or passkey login inside the same flow.

### Transaction, session, and audit truth
- **D-13:** User resolution, membership reconciliation, invite consumption, and enterprise-auth audit emission must complete before the final signed-in session is created.
- **D-14:** The first successful signed-in session row and first related audit row must already carry the resolved `active_organization_id` and enterprise connection truth.
- **D-15:** Reconciliation must be atomic and idempotent. Use DB constraints plus transactional recovery rather than pre-check-only logic.
- **D-16:** Reconciliation outcomes should be explicit and machine-readable, such as `existing_membership`, `invitation_consumed`, `jit_created`, and typed refusal atoms.

### Post-success landing and UX truth
- **D-17:** On safe success, honor a sanitized local `return_to` first, but only when it is compatible with the resolved organization context.
- **D-18:** If there is no valid `return_to`, use a host-owned post-sign-in fallback destination. In the current example app, that fallback should be `/organizations`, not organization settings.
- **D-19:** Do not show an interstitial on ordinary success. Show lightweight confirmation only when something materially changed, such as first JIT membership creation or active-org switch.
- **D-20:** If reconciliation is ambiguous or unsafe, do not create a normal signed-in session. Route to a bounded recovery or fixup surface instead.

### Shift-left defaults
- **D-21:** Prefer researched decisive recommendations and only escalate future discuss-phase questions when they materially change the security model, public contract, generated-host contract, or proof/truth claims.
- **D-22:** For enterprise auth decisions, default to exact normalized identifiers, explicit org truth, fail-closed ambiguity handling, and library-owned transactional correctness over convenience heuristics.

### the agent's Discretion
- Exact module and function names for the reconciliation seam, as long as account resolution, membership writes, and session creation remain clearly ordered and library-owned.
- Exact audit action names and metadata key names, as long as they preserve explicit enterprise outcome truth.
- Exact host-level confirmation or recovery copy and template layout, as long as success stays low-friction and unsafe outcomes do not masquerade as a completed sign-in.

</decisions>

<specifics>
## Specific Ideas

- The default enterprise experience should feel like mature B2B SaaS SSO: if the org route is correct and the user can be resolved safely, one successful login lands them in the correct org without manual pre-seeding.
- Sigra should keep its current generic OAuth safety posture for ambiguous existing-account linking, but enterprise auth may add a narrower auto-claim path because the org-bound callback context is stronger than plain social OAuth.
- The current example success redirect to organization settings is operator-facing and should not be the default member landing after enterprise sign-in.
- Exact-match normalization only: no wildcard, suffix, plus-address, alias folding, or heuristic user selection.
- A stricter preprovision-only posture is a plausible future hardening mode, but it should not be the default baseline for this milestone.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` — Phase 124 goal, dependency boundary, and success criteria.
- `.planning/REQUIREMENTS.md` — `SSO-04`, `JIT-01`, and `JIT-02`.
- `.planning/PROJECT.md` — active milestone posture plus repo-level GSD preference.
- `.planning/STATE.md` — current milestone sequencing and non-goals.

### Upstream enterprise work
- `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md` — locked routing, callback binding, and same-mode recovery rules from Phase 123.
- `.planning/phases/123-org-aware-enterprise-routing/123-RESEARCH.md` — repo-grounded routing design and pitfalls.
- `.planning/phases/122-enterprise-connection-contract-validation/122-RESEARCH.md` — enterprise connection lifecycle and contract assumptions.
- `.planning/research/FEATURES.md` — milestone feature framing and enterprise wedge.
- `.planning/research/PITFALLS.md` — milestone failure modes and trust boundaries.

### Existing Sigra runtime seams
- `lib/sigra/oauth.ex` — OAuth authorize/callback orchestration and signed state ownership.
- `lib/sigra/oauth/callback.ex` — current account routing, conflict posture, and enterprise context validation boundary.
- `lib/sigra/auth.ex` — session creation ordering and first-audit active-org truth.
- `lib/sigra/enterprise_routing.ex` — routed organization and connection truth from Phase 123.
- `lib/sigra/organizations.ex` — membership substrate, unique membership invariant, and organization-owned write paths.
- `lib/sigra/organizations/invitations.ex` — invitation acceptance and mismatch precedent.
- `lib/sigra/session.ex` — session truth model.
- `lib/sigra/scope/hydration.ex` — active-organization hydration behavior after session creation.
- `lib/sigra/plug/load_active_organization.ex` — stale-pointer recovery semantics.

### Generated-host and example-app seams
- `test/example/lib/example/organizations.ex` — host wrapper seam for organizations and enterprise connection/runtime integration.
- `test/example/lib/example/accounts/organization_membership.ex` — host membership schema and uniqueness contract.
- `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` — current enterprise callback and post-success redirect surface.
- `test/example/lib/example_web/user_auth.ex` — `return_to` and signed-in redirect posture.
- `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` — current example controller expectations.
- `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs` — current enterprise routing integration proof.

### Product, DX, and architectural guidance
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — prior-art lessons and hybrid library/generator philosophy.
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — target personas, especially B2B adopters who expect low-friction enterprise auth.
- `prompts/Auth Domain Language — A Field Guide.md` — auth-domain terminology and safety framing.
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` — context boundaries, transactional writes, and least-surprise system design.
- `prompts/ecto-best-practices-deep-research.md` — DB-owned correctness, context APIs, and `Ecto.Multi` discipline.
- `prompts/phoenix-best-practices-deep-research.md` — generated-host routing and controller/LiveView boundary norms.
- `prompts/elixir-best-practices-deep-research.md` — explicit result shapes and assertive domain modeling.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/sigra/oauth/callback.ex`: already owns provider subject lookup, same-email conflict handling, and enterprise callback context validation; Phase 124 should extend this path rather than adding controller-side reconciliation logic.
- `lib/sigra/auth.ex`: already delays session audit emission until active org is known, which is the correct seam for enterprise post-reconciliation session truth.
- `lib/sigra/organizations.ex`: already exposes membership lookup, add-member transactional substrate, and uniqueness invariants that JIT provisioning should reuse.
- `lib/sigra/organizations/invitations.ex`: already encodes invitation mismatch and acceptance semantics; enterprise JIT should compose this instead of inventing a separate invitation interpretation.
- `test/example/lib/example_web/user_auth.ex`: already has a disciplined `return_to` pattern that enterprise success can mirror.

### Established Patterns
- Library owns security-critical runtime truth; generated host owns routes, templates, and UX copy.
- URL-owned org context and signed callback state are already locked by Phase 123.
- Sigra prefers fail-closed security boundaries and bounded recovery over silent downgrade or heuristic recovery.
- Session and audit truth are expected to be right on the first successful signed-in event, not repaired later.

### Integration Points
- Enterprise callback processing is the primary insertion point for account resolution and membership reconciliation.
- Membership and invite writes should stay inside the organizations subsystem and feed explicit `active_organization_id` into session creation.
- Example-app callback success redirect should switch from hardcoded org settings to `return_to -> host fallback`.
- New tests should sit alongside existing enterprise routing and OAuth callback tests rather than inventing a separate enterprise-only harness.

</code_context>

<deferred>
## Deferred Ideas

- Configurable preprovision-only mode that denies JIT membership creation for orgs that want stricter operator approval.
- Heavier post-success branded org handoff or enterprise-specific dashboard UX.
- Operator-configurable membership role mapping beyond default `:member`.
- SCIM-driven lifecycle reconciliation and deprovisioning.
- SSO-only enforcement, break-glass policy, and richer diagnostics beyond the bounded Phase 124 posture.

</deferred>

---

*Phase: 124-jit-provisioning-safe-reconciliation*
*Context gathered: 2026-05-25*
