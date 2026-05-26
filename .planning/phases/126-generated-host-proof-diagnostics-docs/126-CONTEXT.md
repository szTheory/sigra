# Phase 126: Generated-Host Proof, Diagnostics & Docs - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the `v1.27 ENT-SSO` milestone with bounded proof and truthful operator guidance for the enterprise SSO contract already defined by Phases 122 through 125.

This phase proves and explains the shipped enterprise path; it does not redesign connection setup, routing, JIT reconciliation, or SSO-only policy. It also does not widen into SCIM, hosted control-plane behavior, deep enterprise observability tooling, or opinionated authorization.

</domain>

<decisions>
## Implementation Decisions

### Proof authority and breadth
- **D-01:** Phase 126 is a proof-and-truth closeout phase, not a new runtime-capability phase.
- **D-02:** Generated-host proof must stay thin-host proof: reuse library-owned enterprise logic and prove that the generated/example host surfaces wire it honestly rather than inventing enterprise behavior in the host layer.
- **D-03:** The minimum honest proof surface is one bounded happy-path enterprise sign-in lane plus representative denied-path behavior, not a broad matrix of IdPs, browsers, or enterprise-policy combinations.
- **D-04:** The proof stack should stay layered:
  - targeted root ExUnit for setup/validation, routing, callback, reconciliation, and enforcement invariants
  - targeted `test/example` integration coverage for generated-host enterprise entry, callback landing, and denied local-auth behavior
  - one narrow browser lane only where real served-route proof materially closes the milestone contract
- **D-05:** Prefer existing test seams and current generated-host parity harnesses over inventing a new enterprise-only verification framework.

### Generated-host proof shape
- **D-06:** The canonical happy path should prove the bounded enterprise journey end to end: operator-configured active connection -> explicit or discovered org entry -> enterprise callback -> safe reconciliation -> signed-in landing in the correct organization context.
- **D-07:** The denied-path proof must include at least one representative SSO-only local-auth denial and show that the user is steered back to the enterprise path without false `auth.login.success` or session truth.
- **D-08:** Generated-host proof should validate parity between installer templates and the example app for the enterprise surfaces that matter in this milestone: organization settings, enterprise entry/callback, and local-auth denial copy/redirect posture.
- **D-09:** Do not widen the proof ask into live third-party IdP certification, cross-browser portability, or full visual-checkpoint coverage unless planning finds an already-existing harness that makes this nearly free.

### Diagnostic ownership and granularity
- **D-10:** Operator diagnostics should stay stage-based and bounded: setup, routing, reconciliation, and enforcement.
- **D-11:** Diagnostics should reuse typed outcomes and persisted safe fields that already exist or naturally fit the current architecture, rather than adding ad hoc host-only messages or broad telemetry work.
- **D-12:** Setup diagnostics are owned by enterprise connection lifecycle state and safe validation errors.
- **D-13:** Routing diagnostics are owned by bounded routing outcomes such as unavailable or ambiguous enterprise resolution, not by exposing internal matching heuristics or extra tenant-enumeration detail.
- **D-14:** Reconciliation diagnostics are owned by typed callback/reconciliation outcomes and truthful recovery routing, not by creating a hosted support console.
- **D-15:** Enforcement diagnostics are owned by typed denial outcomes, audit truth, and explicit generated-host guidance back to enterprise sign-in or break-glass password recovery.
- **D-16:** The milestone-closeout diagnostic goal is legibility, not observability-platform scope. Avoid introducing generic event dashboards, distributed tracing, or wide new telemetry contracts here.

### Documentation packaging and truth posture
- **D-17:** Docs should explain the bounded enterprise SSO contract as a single coherent operator story across setup, routing, reconciliation, and SSO-only enforcement, instead of leaving adopters to stitch together four separate phase implementations.
- **D-18:** The primary doc output should be honest adopter/operator guidance, not marketing copy. It must make clear what Sigra does, what signals operators should check first when enterprise login fails, and what remains out of scope.
- **D-19:** Non-goals must remain explicit in every public or maintainer-facing truth surface touched by this phase: no SCIM, no hosted control plane, no opinionated authz, no claim that Sigra certifies third-party enterprise environments.
- **D-20:** Prefer updating existing canonical docs and coverage/truth surfaces over creating parallel “enterprise closeout” documents that become a second source of truth.
- **D-21:** Where troubleshooting guidance is needed, organize it by enterprise stage failure rather than by internal module names.

### Evidence packaging and milestone closeout
- **D-22:** Verification should stay command-first and rerunnable. If screenshots or browser artifacts are used, they remain subordinate evidence rather than the primary truth surface.
- **D-23:** Reuse Sigra’s existing review-artifact policy where possible: narrow green-path proof for reviewers, richer diagnostics only on failure.
- **D-24:** The verification artifact for this phase must include a clear Proved / Did Not Prove boundary so the milestone closes honestly without implying SCIM, deprovisioning, or provider-specific certification.
- **D-25:** Planning surfaces touched by this phase should reconcile the enterprise milestone into one truthful end-state and point maintainers at the authoritative proof/doc surfaces, not leave the closeout scattered across plan summaries.

### Decision posture for downstream agents
- **D-26:** Downstream researcher and planner agents should default to the narrowest proof/docs package that honestly satisfies `OPS-01`.
- **D-27:** Reopen the user only if a choice would materially change the generated-host contract, public documentation claims, or the set of failure signals Sigra promises operators.

### the agent's Discretion
- Exact test-file split, command list, and whether the canonical browser proof extends an existing Playwright spec or adds one narrow enterprise spec.
- Exact doc file targets, provided the final documentation stays canonical and does not create duplicate sources of truth.
- Exact diagnostic copy and where it is rendered in generated-host surfaces, provided setup/routing/reconciliation/enforcement remain distinguishable to operators.

</decisions>

<specifics>
## Specific Ideas

- The cleanest closeout shape is to mirror Sigra’s earlier proof-repair phases: a narrow authoritative verification surface, a bounded validation/truth surface, and only the minimum doc updates required to make the milestone legible to adopters.
- The enterprise proof should look like mature B2B auth truth, not like a playground demo:
  - one real organization-bound setup
  - one canonical enterprise login success lane
  - one representative SSO-only denial lane
  - explicit proof of correct organization attribution and recovery posture
- The most useful troubleshooting structure is likely:
  - setup failed
  - route could not be resolved
  - callback/reconciliation failed safely
  - local login denied because SSO-only is active
- Public docs should explain that enterprise login in Sigra is intentionally bounded to OIDC-first org-scoped login plus JIT membership and SSO-only truth, not a full enterprise identity platform.
- If CI/browser proof expands at all, it should do so by extending existing example-app/playwright seams and generated-host parity checks, not by introducing a new heavyweight enterprise acceptance layer.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone contract
- `.planning/ROADMAP.md` — Phase 126 goal, success criteria, and fixed `OPS-01` boundary.
- `.planning/REQUIREMENTS.md` — milestone requirement mapping, especially `OPS-01`.
- `.planning/PROJECT.md` — active milestone posture, thin-host philosophy, and recommendation-first decision policy.
- `.planning/STATE.md` — current sequencing and milestone-execution status.
- `.planning/METHODOLOGY.md` — decisive-defaulting and escalation threshold rules for proof/docs work.

### Upstream enterprise decisions
- `.planning/phases/122-enterprise-connection-contract-validation/122-RESEARCH.md` — enterprise connection lifecycle and safe setup diagnostics.
- `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md` — canonical org route, bounded discovery, and same-mode recovery rules.
- `.planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md` — callback, reconciliation, session truth, and fail-closed outcomes.
- `.planning/phases/125-sso-only-enforcement-break-glass-truth/125-CONTEXT.md` — SSO-only policy, break-glass boundary, and truthful denied-path behavior.
- `.planning/phases/125-sso-only-enforcement-break-glass-truth/125-RESEARCH.md` — recommended proof split and policy-truth framing for denied local auth.
- `.planning/threads/enterprise-sso-b2b-connections.md` — milestone wedge and original enterprise proof posture.
- `.planning/research/ARCHITECTURE.md` — enterprise responsibility split across library and generated host.
- `.planning/research/FEATURES.md` — milestone-level enterprise feature framing.
- `.planning/research/PITFALLS.md` — failure modes and support-hostile anti-patterns to avoid.
- `.planning/research/STACK.md` — OIDC-first and generated-host-bound milestone posture.

### Existing proof and documentation precedents
- `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md` — closeout-phase precedent for narrow proof authority and explicit Proved / Did Not Prove boundaries.
- `.planning/phases/31-automation-first-verification/31-CONTEXT.md` — generated-host/browser proof philosophy and artifact posture.
- `docs/uat-ci-coverage.md` — existing machine-vs-human proof style and truth boundary conventions.

### Existing code and proof seams
- `lib/sigra/enterprise_connections.ex` — enterprise connection lifecycle and activation truth.
- `lib/sigra/enterprise_connections/validation.ex` — safe setup validation diagnostics.
- `lib/sigra/enterprise_routing.ex` — bounded discovery and canonical routing outcomes.
- `lib/sigra/oauth/callback.ex` — typed callback outcomes and enterprise-context validation boundary.
- `lib/sigra/oauth/enterprise_reconciliation.ex` — enterprise reconciliation result contract and first-session metadata.
- `lib/sigra/auth.ex` — local-auth enforcement, denial timing, and session/audit truth.
- `test/example/lib/example/organizations.ex` — host wrapper seam for enterprise setup, routing, and auth-policy controls.
- `test/example/lib/example_web/live/organization_settings_live.ex` — operator-facing setup, status, and SSO-only controls.
- `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` — enterprise entry, callback, success/denial recovery, and user-facing enterprise copy.
- `test/example/lib/example_web/controllers/session_controller.ex` — local-auth denial and break-glass host handling.
- `test/example/lib/example_web/controllers/session_html.ex` — generated-host user guidance for SSO-only and break-glass boundaries.
- `test/example/lib/example_web/user_auth.ex` — enterprise-safe `return_to` and session-path behavior.
- `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs` — current routed entry proof seam.
- `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` — callback and reconciliation proof seam.
- `test/example/test/example_web/controllers/session_controller_test.exs` — denied local-auth and break-glass controller proof seam.
- `test/example/test/example_web/live/organization_settings_live_test.exs` — operator-surface proof seam for setup and SSO-only controls.
- `test/sigra/oauth/enterprise_callback_test.exs` — root callback truth and refusal-path proof seam.
- `test/sigra/enterprise_connections/validation_test.exs` — setup validation proof seam.
- `test/sigra/admin/live/enterprise_connection_live_test.exs` — installer/example parity proof seam for operator surfaces.
- `test/sigra/install/features/organizations_test.exs` — generated-host template parity seam.
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — precedent for intentionally narrow generated-host/browser parity checks.

### Existing user-facing docs
- `guides/flows/oauth.md` — current OAuth/OIDC guide that Phase 126 may need to extend or cross-link for enterprise behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `enterprise_connections` already provides persisted lifecycle state plus safe validation diagnostics, so Phase 126 can explain setup failures without inventing a new diagnostic subsystem.
- `enterprise_routing`, `oauth/callback`, and `enterprise_reconciliation` already emit bounded typed outcomes that map naturally to routing and reconciliation troubleshooting stages.
- The example app already has focused integration tests for enterprise routing and enterprise reconciliation, which are strong seeds for the generated-host proof story.
- `OrganizationSettingsLive` already keeps enterprise setup state and SSO-only controls in one bounded operator surface, which is the natural place to make setup/enforcement diagnostics legible.
- `admin-generated.spec.ts`, installer feature tests, and other parity harnesses already show how Sigra likes to prove generated-host/example alignment without turning Playwright into the primary verification authority.

### Established Patterns
- Security-critical truth belongs in the library; generated host proves and presents that truth but does not own the contract.
- Sigra prefers command-first verification, narrow browser proof, and explicit “what this did not prove” boundaries.
- Generated-host milestones should validate installer/example parity rather than trusting one surface as a proxy for the other.
- Operator truth is bounded and typed; Sigra avoids support-hostile “inspect internals to understand failure” posture, but also avoids overpromising a hosted support console.

### Integration Points
- Enterprise closeout proof should connect enterprise setup status, org entry/callback flow, reconciliation outcome, and SSO-only denial behavior into one coherent milestone story.
- Docs should likely integrate with existing OAuth/OIDC guidance and the existing UAT/CI truth surfaces instead of creating a standalone parallel enterprise handbook.
- Verification can stay largely in existing root and `test/example` seams, with only narrow browser additions if a real served-route lane is needed to satisfy the milestone honestly.

</code_context>

<deferred>
## Deferred Ideas

- SCIM, directory sync, and deprovisioning lifecycle work.
- Hosted control-plane behavior or broader operator dashboards.
- Provider-specific certification, live-IdP compatibility matrices, or broad browser/device support claims.
- Opinionated role/authz policy guidance beyond the existing enterprise login contract.
- Deep telemetry or observability platform work beyond bounded operator-readable diagnostics.

</deferred>

---

*Phase: 126-generated-host-proof-diagnostics-docs*
*Context gathered: 2026-05-26*
