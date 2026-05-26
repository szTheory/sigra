# Phase 125: SSO-Only Enforcement & Break-Glass Truth - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Let organizations require enterprise sign-in for members without creating a fake safety story or a silent local-auth bypass. This phase covers the org-owned SSO-only policy, explicit break-glass exemptions, server-side denial of forbidden local auth paths, and truthful audit/operator behavior for those denied paths. It does not widen into SCIM, broad auth-policy matrices, hosted control-plane behavior, or richer diagnostics/docs beyond what Phase 125 needs to stay truthful.

</domain>

<decisions>
## Implementation Decisions

### Policy ownership and data model
- **D-01:** Model SSO-only as an organization-owned auth policy, not as a field on `enterprise_connections`, not as a membership-role side effect, and not as a global user flag.
- **D-02:** Use a first-class org-scoped policy resource such as `organization_auth_policies` with one durable row per organization.
- **D-03:** Model break-glass as explicit org-user exemptions keyed by `{organization_id, user_id}`, separate from the membership role itself.
- **D-04:** Keep host-owned schemas for this policy/exemption data and library-owned evaluation/enforcement logic, matching Sigra's existing hybrid boundary.

### Break-glass posture
- **D-05:** Break-glass is a narrow recovery seam, not a parallel local-auth product mode.
- **D-06:** For exempt users, preserve local password login and password-reset recovery only.
- **D-07:** Do not preserve magic-link or passkey as break-glass primary sign-in methods under SSO-only enforcement.
- **D-08:** Non-exempt users denied from local auth must be routed back to the explicit enterprise path, not silently downgraded into another local method.

### Enforcement seam
- **D-09:** Put the core enforcement check in the library-owned password-auth decision boundary, after credential verification but before `auth.login.success` and before any session is created.
- **D-10:** Do not rely on controller-only, plug-only, or template-only enforcement for the primary guarantee.
- **D-11:** Generated-host controllers may translate typed library outcomes into redirect/copy, but may not own the core allow/deny rule.
- **D-12:** Routing/discovery and enforcement are separate concerns: enterprise routing remains convenience and ceremony truth; SSO-only enforcement is a server-side auth-policy decision.

### Truthful denied-path behavior
- **D-13:** A denied local password attempt must not emit `auth.login.success` or `session.create`.
- **D-14:** Denied local auth should emit a typed, auditable denial reason, either via bounded `auth.login.failure` metadata or a dedicated deny action.
- **D-15:** The denial/result contract should use bounded result atoms rather than ad hoc controller copy. Expected examples include `:sso_required`, `:break_glass_not_allowed`, `:local_password_denied`, and `:password_reset_denied`.
- **D-16:** Enterprise callback failures keep the same-mode enterprise retry posture already locked by Phases 123 and 124.

### Operator UX and safety rails
- **D-17:** The operator surface for this phase stays on the existing organization settings enterprise area, but the policy UI must remain legible as distinct from connection status and validation state.
- **D-18:** Enabling SSO-only should require an explicit, valid break-glass story rather than treating break-glass as optional guidance.
- **D-19:** The generated-host contract should verify that at least one valid non-SSO recovery path exists before allowing irreversible or lockout-prone transitions.
- **D-20:** Keep Phase 125 focused on password-denial truth and break-glass posture, not a generalized matrix of every possible auth-method combination.

### the agent's Discretion
- Exact schema/module names for the org auth policy and exemption records, as long as org ownership and org-user exemption semantics stay explicit.
- Whether the denial audit reuses `auth.login.failure` with typed metadata or uses a dedicated action name, as long as operator truth is unambiguous.
- Exact generated-host copy, redirects, and settings-page layout, as long as denied users are clearly pointed to enterprise sign-in and exempt users are clearly treated as break-glass only.

</decisions>

<specifics>
## Specific Ideas

- Treat SSO-only as a small explicit policy state machine, not as a pile of UI toggles.
- Keep a non-discoverable but supported break-glass path for exempt users; do not rely on the happy-path login surface as the only access story.
- The simplest truthful user copy is close to: "Your organization requires enterprise sign-in. Continue with your organization sign-in. If you have a break-glass exemption, use password sign-in."
- Favor explicit org-owned policy and explicit org-user exemptions over heuristics like "has a password" or "is an owner therefore exempt."
- Keep local and enterprise identity/linking semantics explicit; do not let SSO-only policy drift into implicit same-email account merging.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` — Phase 125 goal, success criteria, and dependency boundary.
- `.planning/REQUIREMENTS.md` — `ENF-01` and milestone non-goals.
- `.planning/PROJECT.md` — repo-level GSD preference and active milestone posture.
- `.planning/METHODOLOGY.md` — recommendation-first discussion posture and escalation threshold.

### Upstream enterprise decisions
- `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md` — explicit org routing, same-mode recovery, and enterprise truth boundaries.
- `.planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md` — reconciliation/session ordering, fail-closed outcomes, and enterprise callback truth.
- `.planning/research/ARCHITECTURE.md` — org-level SSO posture plus explicit per-user break-glass seam.
- `.planning/research/FEATURES.md` — milestone framing for SSO-only plus break-glass.
- `.planning/research/PITFALLS.md` — especially UI-only enforcement and support-hostile auth-policy behavior.
- `.planning/threads/enterprise-sso-b2b-connections.md` — original milestone investigation and wedge framing.

### Repo prompts and design guidance
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — hybrid library+generator philosophy and least-surprise product shape.
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — B2B adopter expectations for enterprise auth and recovery posture.
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` — process/boundary discipline for library and host responsibilities.
- `prompts/ecto-best-practices-deep-research.md` — explicit tables, DB-owned correctness, and constraint-first posture.
- `prompts/Auth Domain Language — A Field Guide.md` — language for auth boundaries, recovery, and takeover posture.

### Existing Sigra seams to extend
- `lib/sigra/auth.ex` — password auth, success/failure audit timing, and session creation boundary.
- `lib/sigra/oauth/callback.ex` — typed callback outcomes and enterprise-context truth.
- `lib/sigra/oauth/enterprise_reconciliation.ex` — first-session enterprise metadata and fail-closed enterprise behavior.
- `lib/sigra/enterprise_routing.ex` — canonical org-scoped enterprise routing and discovery.
- `lib/sigra/plug/forbid_during_impersonation.ex` — denial pattern with audit plus host redirect/copy split.
- `docs/audit-semantics.md` — audit atomicity and denial/success truth guidance.

### Generated-host/example seams
- `test/example/lib/example_web/controllers/session_controller.ex` — current local auth entry points that must become policy-aware.
- `test/example/lib/example_web/controllers/session_html.ex` — current mixed-method login surface that cannot be trusted as the enforcement boundary.
- `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` — canonical enterprise retry/success surface.
- `test/example/lib/example_web/live/organization_settings_live.ex` — operator-facing enterprise settings surface where Phase 125 controls should live.
- `test/example/lib/example/organizations.ex` — org/enterprise wrapper seam.
- `test/example/lib/example/accounts/organization.ex` — current org data model.
- `test/example/lib/example/accounts/organization_membership.ex` — current membership model, deliberately too thin to own auth policy.
- `test/example/lib/example/accounts/enterprise_connection.ex` — current enterprise connection model and why policy should not be conflated with it.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/sigra/auth.ex`: already owns password verification and `auth.login.success`/failure timing; this is the correct seam for policy evaluation before session issuance.
- `lib/sigra/oauth/callback.ex` and `lib/sigra/oauth/enterprise_reconciliation.ex`: already establish the "typed library result, thin host redirect/copy" pattern Phase 125 should follow.
- `lib/sigra/plug/forbid_during_impersonation.ex`: useful precedent for explicit deny + audit + generated-host message handling.
- `test/example/lib/example_web/live/organization_settings_live.ex`: natural operator surface for org-owned enterprise policy controls.

### Established Patterns
- Security-critical runtime truth belongs in the library; generated host owns routes, templates, and app-specific UX copy.
- Sigra prefers fail-closed boundaries, typed outcomes, and first-session/audit truth that is right immediately rather than repaired later.
- URL-owned org context and same-mode enterprise recovery are already locked by earlier phases.
- Org configuration and enterprise configuration are durable DB-backed runtime state, not compile-time config.

### Integration Points
- Password login path: `SessionController.create/3` -> `Example.Accounts.get_user_by_email_and_password/2` -> `Sigra.Auth.authenticate/3` -> `UserAuth.log_in_user/3` / `Sigra.Auth.create_session/4`.
- Enterprise recovery path: denied local users should be steered back to `/organizations/:org/sso` or bounded enterprise discovery, not to a different local method.
- Operator path: organization settings should present connection status and auth-policy state separately but in the same bounded enterprise area.
- Audit path: denied local auth must preserve org/policy truth without emitting false success events.

</code_context>

<deferred>
## Deferred Ideas

- Broad mixed-auth matrices beyond this phase's narrow SSO-only + break-glass contract.
- Passkey-allowed or magic-link-allowed break-glass variants.
- SCIM/deprovisioning or directory-driven lifecycle enforcement.
- Hosted control-plane style org policy management.
- Rich diagnostics, deep operator tooling, and wider docs/evidence closure beyond the bounded Phase 126 proof/docs phase.

</deferred>

---

*Phase: 125-sso-only-enforcement-break-glass-truth*
*Context gathered: 2026-05-26*
