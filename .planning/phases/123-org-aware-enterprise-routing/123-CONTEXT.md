# Phase 123: Org-Aware Enterprise Routing - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Route enterprise login into the correct organization connection through explicit organization entry and bounded email-domain discovery. This phase covers entry, routing, callback binding, and session/audit truth for enterprise login initiation. It does not cover JIT membership reconciliation, SSO-only enforcement, hosted control-plane behavior, SCIM, or broader authorization policy.

</domain>

<decisions>
## Implementation Decisions

### Entry path shape
- **D-01:** Ship both a canonical explicit org-scoped enterprise entry route and a bounded generic enterprise discovery entry.
- **D-02:** The org-scoped route is the source of truth. The generic entry is convenience only and must redirect into the canonical org route before the OIDC ceremony starts.
- **D-03:** Do not expose a parallel domain-only internal API. Library/runtime APIs should target explicit organization or connection identity even when UX begins from email discovery.

### Email-domain discovery
- **D-04:** Generic enterprise discovery may auto-route only when `normalize_email(email)` yields an exact match to one active enterprise connection with a verified, uniquely owned domain.
- **D-05:** Pending, disabled, validation-failed, duplicate, wildcard, suffix, shared, or heuristic domain matches never qualify for auto-routing.
- **D-06:** Discovery is a UX convenience, not a trust boundary. The resolved `organization_id`, `connection_id`, and `routing_source: :domain_discovery` must be bound into signed OAuth state and/or server session, then revalidated on callback.

### Failure and ambiguity handling
- **D-07:** Fail closed whenever discovery does not resolve exactly one usable active enterprise connection.
- **D-08:** Recovery stays in the same mode: return the user to an explicit enterprise org-entry retry flow with bounded guidance. Do not silently downgrade into password, magic-link, or passkey login.
- **D-09:** If another auth mode remains allowed by later policy, expose it only as a separate explicit choice outside the enterprise-routing flow.
- **D-10:** Use bounded failure reasons internally and in audits, such as `no_org_match`, `multiple_org_matches`, and `org_connection_unavailable`.

### Org truth during and after login
- **D-11:** Once Sigra resolves an organization, generated-host UI should show lightweight explicit org truth before redirect and on return/error states.
- **D-12:** Keep this lightweight: name the organization and make the scope legible, but do not build a heavier branded enterprise handoff in Phase 123.
- **D-13:** Library code remains authoritative for org resolution, callback binding, session attribution, and audit attribution. Generated-host code owns the UX copy and presentation.

### Shift-left defaults
- **D-14:** For similar future GSD routing decisions, default to: canonical scoped route first, bounded unique verified auto-resolution second.
- **D-15:** Default to fail-closed plus explicit same-mode recovery rather than silent downgrade.
- **D-16:** Default to lightweight explicit tenant/org truth at auth boundaries whenever tenant resolution affects session, callback, or audit correctness.

### the agent's Discretion
- Exact route names and whether the enterprise entry is controller-rendered or LiveView, as long as the canonical org-scoped route stays explicit and obvious.
- Exact UI copy, layout, and button hierarchy for discovery, retry, and return states.
- Exact storage split between signed OAuth state and server session for carrying resolved org/connection identity, as long as callback verification remains strict.

</decisions>

<specifics>
## Specific Ideas

- Prefer a route shape equivalent to `/organizations/:org/sso` or similarly obvious org-owned enterprise entry, keeping parity with Sigra's existing URL-owned org posture.
- The generic login surface may add a clearly separated “Continue with enterprise SSO” path that accepts a work email and either:
  - resolves one verified match and immediately redirects into the canonical org-scoped enterprise route, or
  - stops and asks for explicit organization entry.
- Do not teach users that “enterprise login” can silently become “normal login with different steps.”
- Keep explicit org copy small but visible: “Continue to Acme enterprise sign-in” is the right level; full branded hosted-IdP chrome is not.
- Where privacy tradeoffs are unclear, prefer generic recovery copy on the generic discovery surface and more specific copy only once org context is already explicit.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` — Phase 123 goal, dependency boundary, and success criteria.
- `.planning/REQUIREMENTS.md` — `SSO-03` and adjacent milestone requirements that constrain routing truth.
- `.planning/PROJECT.md` — active milestone goals, non-goals, and current product posture for `ENT-SSO`.
- `.planning/STATE.md` — current sequencing and explicit instruction not to widen this milestone into hosted control-plane or directory-platform work.

### Enterprise milestone research
- `.planning/threads/enterprise-sso-b2b-connections.md` — repo-grounded milestone investigation and prior-art references for org routing.
- `.planning/research/SUMMARY.md` — milestone wedge and protocol stance.
- `.planning/research/ARCHITECTURE.md` — library-versus-generated-host responsibility split.
- `.planning/research/PITFALLS.md` — especially wrong-org routing and support-hostile setup truth.
- `.planning/research/STACK.md` — OIDC-first stack and explicit-org-entry plus bounded-discovery posture.
- `.planning/phases/122-enterprise-connection-contract-validation/122-RESEARCH.md` — Phase 122 contract assumptions that Phase 123 must build on.

### Existing Sigra routing and org patterns
- `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md` — locked precedent for URL-owned organization routing and generated-host ownership boundaries.
- `guides/flows/oauth.md` — current Sigra OAuth/OIDC flow shape and callback expectations.
- `lib/sigra/oauth.ex` — current OAuth orchestration and state ownership.
- `lib/sigra/oauth/callback.ex` — callback routing precedent and account-linking safety posture.
- `lib/sigra/auth.ex` — session creation and active-organization audit ordering.
- `lib/sigra/session.ex` — session truth model with `active_organization_id`.
- `lib/sigra/enterprise_connections.ex` — org-scoped enterprise connection runtime contract.
- `test/example/lib/example/accounts/enterprise_connection.ex` — generated-host enterprise connection schema shape, statuses, and `login_hint_domains`.
- `test/example/lib/example_web/controllers/session_html.ex` — current generated-host login surface.
- `test/example/lib/example_web/router.ex` — current scoped routing posture and auth pipelines.
- `test/example/lib/example_web/live/organization_settings_live.ex` — operator-facing enterprise connection truth surface.
- `test/example/lib/example_web/components/org_switcher.ex` — current org-truth UI precedent after sign-in.

### Product and DX guidance
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — target personas and DX goals, especially enterprise/security-conscious adopters.
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — hybrid library+generator philosophy and prior-art lessons.
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` — system-design defaults relevant to boundary ownership and runtime truth.
- `prompts/phoenix-best-practices-deep-research.md` — idiomatic Phoenix routing, context, and generated-host conventions.
- `prompts/ecto-best-practices-deep-research.md` — context/API boundary and DB-owned correctness expectations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/sigra/oauth.ex`: already owns authorization URL generation, signed OAuth state, and callback orchestration; Phase 123 should extend this path rather than create a second auth stack.
- `lib/sigra/oauth/callback.ex`: already treats callback routing truth as security-sensitive and avoids email-only trust in existing OAuth flows.
- `lib/sigra/auth.ex`: existing session creation already delays audit emission until active org is known, which is a strong precedent for enterprise routing truth.
- `lib/sigra/enterprise_connections.ex`: current enterprise connection contract already exposes org-bound active/draft/disabled truth and should remain the only source for routable enterprise connections.
- `test/example/lib/example_web/controllers/session_html.ex`: current controller-rendered login page is the natural host surface for adding a bounded enterprise discovery branch.

### Established Patterns
- URL-owned org context is already a locked Sigra pattern from Phase 16. Explicit scoped routes beat session-hidden tenant inference.
- Library owns security-critical runtime behavior; generated host owns routes, forms, templates, and app-specific copy.
- Sigra favors truthful lifecycle states over soft implied behavior; Phase 122's enterprise connection states must remain authoritative during routing.
- Current OAuth flow already owns signed state and callback verification; Phase 123 should reuse that discipline for resolved org/connection identity.

### Integration Points
- Generic login page can host the discovery affordance.
- Canonical org-scoped enterprise entry route should sit alongside existing `/organizations/:org/...` patterns.
- Callback handling must persist and re-check initiating org/connection context before any session attribution or future reconciliation work.
- Audit and session metadata should record which organization initiated the enterprise flow, not infer it later from email alone.

</code_context>

<deferred>
## Deferred Ideas

- Per-organization branded enterprise login handoff or theming.
- Broader privacy-policy customization for discovery enumeration tradeoffs beyond bounded defaults.
- SSO-only enforcement and break-glass UX.
- JIT membership reconciliation and identity-link decisions after successful enterprise callback.
- SCIM, hosted admin/control-plane workflows, and broader enterprise directory lifecycle automation.

</deferred>

---

*Phase: 123-org-aware-enterprise-routing*
*Context gathered: 2026-05-25*
