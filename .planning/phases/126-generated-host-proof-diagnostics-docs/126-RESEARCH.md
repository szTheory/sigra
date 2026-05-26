# Phase 126: Generated-Host Proof, Diagnostics & Docs - Research

**Researched:** 2026-05-26  
**Domain:** Generated-host enterprise proof, stage-based operator diagnostics, and bounded enterprise SSO documentation closeout for Sigra's OIDC-first org-scoped contract [VERIFIED: .planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md] [VERIFIED: .planning/ROADMAP.md]  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Phase 126 is a proof-and-truth closeout phase, not a new runtime-capability phase. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-02:** Generated-host proof must stay thin-host proof: reuse library-owned enterprise logic and prove that the generated/example host surfaces wire it honestly rather than inventing enterprise behavior in the host layer. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-03:** The minimum honest proof surface is one bounded happy-path enterprise sign-in lane plus representative denied-path behavior, not a broad matrix of IdPs, browsers, or enterprise-policy combinations. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-04:** Proof should stay layered: targeted root ExUnit, targeted `test/example` integration coverage, and at most one narrow browser lane where a real served route materially closes the contract. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-05:** Generated-host proof should validate installer/example parity for the enterprise surfaces that matter in this milestone. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-10:** Operator diagnostics should stay stage-based and bounded: setup, routing, reconciliation, and enforcement. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-11:** Diagnostics should reuse typed outcomes and persisted safe fields that already exist or naturally fit the current architecture, rather than adding ad hoc host-only messages or broad telemetry work. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-17:** Docs should explain the bounded enterprise SSO contract as one coherent operator story across setup, routing, reconciliation, and SSO-only enforcement. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-19:** Non-goals must remain explicit in every public or maintainer-facing truth surface touched by this phase: no SCIM, no hosted control plane, no opinionated authz, and no provider-certification claim. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **D-24:** The verification artifact for this phase must include a clear Proved / Did Not Prove boundary. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]

### Claude's Discretion
- Exact file split between root proof, example-host proof, installer parity, and docs/truth packaging, provided the final package stays narrow and legible. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- Whether the canonical browser proof extends an existing enterprise Playwright seam or adds one narrow new spec, provided it remains singular and bounded. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- Exact docs targets, provided the final story lives in canonical files instead of spawning a parallel enterprise handbook. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]

### Deferred Ideas (OUT OF SCOPE)
- SCIM, deprovisioning, and broad directory lifecycle automation. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- Hosted control-plane dashboards or deep observability tooling. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- Provider certification matrices, broad browser/device claims, or SAML expansion. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- Opinionated role/authz guidance beyond the current enterprise login contract. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-01 | Generated-host proof, diagnostics, and docs make the bounded enterprise SSO contract legible for adopters and operators. | Close the phase with one coherent evidence and docs package: root typed-outcome proof, example/generated-host integration proof, installer parity proof, stage-based operator guidance, and explicit non-goals. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/ROADMAP.md`] |
</phase_requirements>

## Summary

Phase 126 is a packaging and truth phase over already-built enterprise seams. The codebase already contains the core building blocks for all four diagnostic stages the context requires: setup truth in `Sigra.EnterpriseConnections` and `Sigra.EnterpriseConnections.Validation`, routing outcomes in `Sigra.EnterpriseRouting`, callback and reconciliation outcomes in `Sigra.OAuth.Callback` plus `Sigra.OAuth.EnterpriseReconciliation`, and enforcement-denial outcomes in `Sigra.Auth` and the generated-host session flow. [VERIFIED: `lib/sigra/enterprise_connections.ex`] [VERIFIED: `lib/sigra/enterprise_connections/validation.ex`] [VERIFIED: `lib/sigra/enterprise_routing.ex`] [VERIFIED: `lib/sigra/oauth/callback.ex`] [VERIFIED: `lib/sigra/oauth/enterprise_reconciliation.ex`] [VERIFIED: `lib/sigra/auth.ex`]

What remains incomplete is not the enterprise wedge itself, but the milestone-closeout legibility:

1. the repo lacks one bounded diagnostic contract that ties setup, routing, reconciliation, and enforcement into operator-readable stages,
2. the generated-host proof is spread across root tests, example integration tests, and installer assertions without one explicit closeout narrative,
3. the canonical docs (`guides/flows/oauth.md`) still describe generic OAuth/OIDC but not the bounded organization-scoped enterprise contract Sigra now ships, and
4. the maintainer-facing truth surface still needs an explicit phase-local proof package for `OPS-01`. [VERIFIED: `guides/flows/oauth.md`] [VERIFIED: `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs`] [VERIFIED: `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs`] [VERIFIED: `test/sigra/install/features/organizations_test.exs`]

**Primary recommendation:** split execution into four plans.

1. Add a bounded library-owned diagnostic outcome contract and root proof for the four enterprise stages.
2. Extend the example/generated-host proof story with one canonical happy path, one representative denied path, and stage-specific operator-visible guidance.
3. Lock installer/generated-host parity and update canonical docs so adopters see the same bounded contract the example app proves.
4. Package the final phase-local verification/truth surfaces with explicit Proved / Did Not Prove boundaries and milestone-closeout pointers.

That split preserves the thin-host rule, keeps browser proof intentionally narrow, and avoids a support-hostile "go read the internals" posture. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Setup-stage diagnostics | API / Backend | Generated Host | `EnterpriseConnections` already owns activation truth and safe validation failure state; the host should present, not invent, those diagnostics. [VERIFIED: `lib/sigra/enterprise_connections.ex`] |
| Routing-stage diagnostics | API / Backend | Generated Host | `EnterpriseRouting` already emits bounded routing outcomes; the host can turn them into user/operator guidance without expanding tenant enumeration. [VERIFIED: `lib/sigra/enterprise_routing.ex`] |
| Reconciliation-stage diagnostics | API / Backend | Generated Host | `OAuth.Callback` and `EnterpriseReconciliation` already contain typed refusal/success outcomes that can be mapped into recovery guidance and proof assertions. [VERIFIED: `lib/sigra/oauth/callback.ex`] [VERIFIED: `lib/sigra/oauth/enterprise_reconciliation.ex`] |
| Enforcement-stage diagnostics | API / Backend | Generated Host | `Sigra.Auth` and the example session controller already distinguish SSO-only denial from generic invalid credentials. [VERIFIED: `lib/sigra/auth.ex`] [VERIFIED: `test/example/lib/example_web/controllers/session_controller.ex`] |
| Happy-path and denied-path proof | Example Host + Tests | Library Tests | Existing integration and controller tests already prove most enterprise flows; one narrow browser lane should close only the missing served-route seam. [VERIFIED: `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs`] [VERIFIED: `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs`] |
| Installer/example parity | Generated Host Templates | Feature Tests | `Sigra.Install.Features.Organizations` plus `organizations_test.exs` are already the parity gate for generated-host enterprise surfaces. [VERIFIED: `lib/sigra/install/features/organizations.ex`] [VERIFIED: `test/sigra/install/features/organizations_test.exs`] |
| Canonical operator docs | Guides / Docs | Planning Evidence | `guides/flows/oauth.md` and `docs/uat-ci-coverage.md` are the current canonical homes for the enterprise story and proof-boundary framing. [VERIFIED: `guides/flows/oauth.md`] [VERIFIED: `docs/uat-ci-coverage.md`] |

## Repo-Grounded Findings

### Existing proof seams already cover most of the milestone
- `test/sigra/enterprise_connections/validation_test.exs`, `activation_test.exs`, `enterprise_routing/discovery_test.exs`, `oauth/enterprise_callback_test.exs`, `oauth/enterprise_reconciliation_test.exs`, `auth_test.exs`, and `auth/login_and_lockout_audit_atomicity_test.exs` already pin the library-owned setup/routing/reconciliation/enforcement truth. [VERIFIED: codebase grep]
- The example app already proves canonical routing, reconciliation redirect/fallback, and SSO-only denial handling in focused integration and controller tests. [VERIFIED: `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs`] [VERIFIED: `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs`] [VERIFIED: `test/example/test/example_web/controllers/session_controller_test.exs`]
- The installer path already ships enterprise templates, routing, settings, and SSO-only surfaces, with regression coverage in `test/sigra/install/features/organizations_test.exs`. [VERIFIED: `lib/sigra/install/features/organizations.ex`] [VERIFIED: `test/sigra/install/features/organizations_test.exs`]

### What is still missing
- `ExampleWeb.EnterpriseSSOController` currently collapses most enterprise callback failures to one generic message, which is fine for user safety but not yet enough for the operator-troubleshooting story the phase requires. The phase should keep the user-facing copy bounded while exposing operator-oriented stage mapping in docs and settings surfaces. [VERIFIED: `test/example/lib/example_web/controllers/enterprise_sso_controller.ex`]
- The repo has no single current-head enterprise proof artifact analogous to the closeout phases used elsewhere; `OPS-01` needs a phase-local verification narrative. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/`]
- `guides/flows/oauth.md` still describes generic provider OAuth/OIDC and account linking, but does not explain the enterprise-org route, setup lifecycle, JIT membership, SSO-only denial posture, or explicit non-goals. [VERIFIED: `guides/flows/oauth.md`]

## Recommended Plan Split

### Plan 126-01: Library-owned stage diagnostics and root proof
Own the bounded diagnostic vocabulary and its root test coverage across setup, routing, reconciliation, and enforcement. This keeps the support story grounded in library truth rather than host heuristics.

### Plan 126-02: Example/generated-host proof and operator surfaces
Own the happy-path and denied-path proof story in the example app, including one narrow browser lane if needed, plus operator-readable stage cues on the generated-host surfaces.

### Plan 126-03: Installer parity and canonical docs
Own installer/template parity, generated-host contract assertions, and the public/operator docs updates in `guides/flows/oauth.md` plus any proof-boundary cross-links in `docs/uat-ci-coverage.md`.

### Plan 126-04: Phase-local verification and closeout truth
Own the final `126-VERIFICATION.md`, any bounded evidence index needed for closeout, and the active planning surfaces that should point maintainers to the authoritative `OPS-01` proof package.

## Architecture Patterns

### Pattern 1: Stage-based diagnostics should reuse typed outcomes, not new telemetry

**What:** Organize enterprise troubleshooting around the outcomes the library already emits or can emit naturally: setup (`validation_failed`, inactive, missing fields), routing (`no_org_match`, `multiple_org_matches`, `org_connection_unavailable`), reconciliation (`provider_subject_conflict`, `ambiguous_email_match`, exact-match success outcomes), and enforcement (`sso_required`). [VERIFIED: `lib/sigra/enterprise_connections.ex`] [VERIFIED: `lib/sigra/enterprise_routing.ex`] [VERIFIED: `lib/sigra/oauth/enterprise_reconciliation.ex`] [VERIFIED: `lib/sigra/auth.ex`]

**When to use:** Every operator-facing troubleshooting surface and every proof artifact touched by Phase 126. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]

**Why:** This preserves the bounded contract and avoids inventing a new support subsystem.

### Pattern 2: Browser proof should close only one missing seam

**What:** Keep ExUnit/integration tests as the authority for most branches, and use Playwright only for one served-route happy-path plus one representative denied-path checkpoint if that materially proves the generated-host contract. [VERIFIED: `test/example/priv/playwright/tests/admin-generated.spec.ts`] [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]

**When to use:** Only where static/read-only tests are insufficient to prove the generated-host route is honestly wired end to end.

**Anti-pattern:** building a live-IdP matrix, broad browser matrix, or screenshot-heavy artifact set.

### Pattern 3: Canonical docs should collapse the milestone into one bounded operator story

**What:** Update `guides/flows/oauth.md` so it becomes the public/generated-host explanation of enterprise setup, org-aware routing, JIT reconciliation, and SSO-only truth, with explicit non-goals. [VERIFIED: `guides/flows/oauth.md`] [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]

**When to use:** After proof seams and operator-stage wording are settled enough to document without thrash.

**Why:** The current repo has all the behavior but not yet one canonical explainer.

## Anti-Patterns to Avoid

- **Adding a new observability subsystem:** the phase is about legibility, not dashboards or tracing. [VERIFIED: `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`]
- **Letting host copy become the source of truth:** enterprise setup, routing, reconciliation, and enforcement semantics must stay library-owned. [VERIFIED: `lib/sigra/enterprise_connections.ex`] [VERIFIED: `lib/sigra/oauth/callback.ex`] [VERIFIED: `lib/sigra/auth.ex`]
- **Overclaiming enterprise breadth in docs:** keep the OIDC-first bounded contract explicit and repeat the non-goals. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/threads/enterprise-sso-b2b-connections.md`]
- **Treating generic end-user flashes as sufficient operator diagnostics:** the phase should map safe operator actions and failure stages without leaking sensitive internals. [VERIFIED: `test/example/lib/example_web/controllers/enterprise_sso_controller.ex`]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit, Phoenix ConnTest / integration tests, installer template assertions, Playwright, and planning-file grep gates. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `test/example/test/test_helper.exs`, and `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs && cd test/example && MIX_ENV=test mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs test/example_web/controllers/session_controller_test.exs` [VERIFIED: codebase grep] |
| Full suite command | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs test/sigra/install/features/organizations_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs && cd test/example && MIX_ENV=test mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs test/example_web/controllers/session_controller_test.exs test/example_web/live/organization_settings_live_test.exs && cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-generated.spec.ts --project=chromium && rg -n \"enterprise|SSO-only|break-glass|SCIM|hosted control plane|opinionated authz|Proved|Did Not Prove\" guides/flows/oauth.md docs/uat-ci-coverage.md .planning/phases/126-generated-host-proof-diagnostics-docs/126-VERIFICATION.md` [VERIFIED: codebase grep] |

### Phase Requirement → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPS-01 | Setup diagnostics remain truthful and safe. | root ExUnit | `mix test test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs` | ✅ [VERIFIED: codebase grep] |
| OPS-01 | Routing and reconciliation outcomes stay bounded and provable. | root ExUnit | `mix test test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs` | ✅ [VERIFIED: codebase grep] |
| OPS-01 | Enforcement denial stays representative and truthful. | root + example controller | `mix test test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs && cd test/example && MIX_ENV=test mix test --include example_app test/example_web/controllers/session_controller_test.exs` | ✅ [VERIFIED: codebase grep] |
| OPS-01 | Generated-host happy path and denied path remain coherent. | example integration | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs test/example_web/controllers/session_controller_test.exs test/example_web/live/organization_settings_live_test.exs` | ✅ [VERIFIED: codebase grep] |
| OPS-01 | Installer/example parity remains locked. | installer assertions | `mix test test/sigra/install/features/organizations_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs` | ✅ [VERIFIED: codebase grep] |
| OPS-01 | One bounded browser lane proves generated-host wiring. | Playwright | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-generated.spec.ts --project=chromium` | ✅ existing narrow browser precedent; enterprise lane may be extended or added narrowly [VERIFIED: `test/example/priv/playwright/tests/admin-generated.spec.ts`] |
| OPS-01 | Docs and verification surfaces stay explicit about non-goals and proof boundaries. | docs/grep | `rg -n "SCIM|hosted control plane|opinionated authz|Proved|Did Not Prove|enterprise" guides/flows/oauth.md docs/uat-ci-coverage.md .planning/phases/126-generated-host-proof-diagnostics-docs/126-VERIFICATION.md` | ⚠️ phase artifact missing today [VERIFIED: repo state] |

### Wave 0 Gaps

- None for runtime verification infrastructure. Existing root, example, installer, and browser harnesses already cover the enterprise wedge; the missing work is closeout composition and any one narrow browser addition that proves the final generated-host route honestly. [VERIFIED: codebase grep]

## Sources

### Primary
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/phases/126-generated-host-proof-diagnostics-docs/126-CONTEXT.md`
- `lib/sigra/enterprise_connections.ex`
- `lib/sigra/enterprise_connections/validation.ex`
- `lib/sigra/enterprise_routing.ex`
- `lib/sigra/oauth/callback.ex`
- `lib/sigra/oauth/enterprise_reconciliation.ex`
- `lib/sigra/auth.ex`
- `test/example/lib/example_web/controllers/enterprise_sso_controller.ex`
- `test/example/lib/example_web/controllers/session_controller.ex`
- `test/example/lib/example_web/live/organization_settings_live.ex`
- `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs`
- `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs`
- `test/example/test/example_web/controllers/session_controller_test.exs`
- `test/sigra/install/features/organizations_test.exs`
- `guides/flows/oauth.md`
- `docs/uat-ci-coverage.md`

### Secondary
- `.planning/threads/enterprise-sso-b2b-connections.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`
- `test/example/priv/playwright/tests/admin-generated.spec.ts`

