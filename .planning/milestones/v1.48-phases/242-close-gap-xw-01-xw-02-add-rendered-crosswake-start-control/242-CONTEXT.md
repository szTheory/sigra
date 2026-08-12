# Phase 242: Close gap: XW-01/XW-02 — add rendered Crosswake start control - Context

**Gathered:** 2026-08-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the v1.48 integration gap by adding one rendered, authenticated example-host control that initiates the existing Crosswake flow through `POST /crosswake/start`, then prove the complete user-operated journey. The Phase 240.3 controller, continuation, evaluator, denial, secrecy, and fixed safe-return contracts remain unchanged. This phase does not add Sigra-core behavior, generated-host output, a new Crosswake protocol surface, or admin/operator UI.

</domain>

<decisions>
## Implementation Decisions

### Authenticated host surface
- **D-01:** Render the start control on the existing authenticated example-host `/app` LiveView (`ExampleWeb.AppLive`), which is already the post-login account hub and shares the authenticated browser pipeline with `POST /crosswake/start`.
- **D-02:** Submit a normal CSRF-protected HTTP `POST /crosswake/start`. Do not add a route, controller template, generated-host feature, or LiveView event flow; the existing `CrosswakeController` remains the HTTP orchestration boundary.

### User-visible control
- **D-03:** Use a real, visible form/button with an accessible role and name in the example host's existing Tasklane `vt-*` visual system. This is host UI, not the `sg-*` admin/operator surface.
- **D-04:** The control accepts no user-supplied Crosswake or navigation values. It exposes an intentional user action, not protocol configuration.

### Protocol and security preservation
- **D-05:** The form carries only standard CSRF submission mechanics. Continuation, state, PKCE verifier, binding, session identity, route, destination, and evaluator inputs remain server-owned.
- **D-06:** Preserve the complete Phase 240.3 security and navigation contract: fresh backend session resolution, one-time continuation, fail-closed denial before evaluator invocation, evaluator-owned access decision, no secret disclosure, and fixed safe return to `/app`.
- **D-07:** Do not modify Sigra core, generated-host output, Crosswake's published successor, or the host/library responsibility split to deliver this rendered edge.

### Deterministic closure evidence
- **D-08:** Replace Playwright's `page.evaluate()` form fabrication with a role-based interaction against the rendered control.
- **D-09:** Retain the existing real-cookie-jar journey, return-request observation, exact callback-key assertion, absent-Referer assertion, fixed final `/app` state, and correlation/secret non-disclosure checks.
- **D-10:** Keep the focused browser proof deterministic: stable rendered readiness, role/label selectors, no sleeps, serial one-worker execution, and zero retries.

### the agent's Discretion
- Exact placement within the authenticated `/app` account hub and exact user-facing wording, provided the control is obvious, accessible, and consistent with the existing Tasklane host UI.
- Whether the control is a dedicated action panel or an item in the existing quick-actions grid.
- Focused LiveView/source contract assertions needed to make the rendered route, method, and accessible-name contract durable, without duplicating the controller and prohibition suites.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope and closure finding
- `.planning/ROADMAP.md` — Phase 242 placement and fixed gap-closure scope.
- `.planning/REQUIREMENTS.md` — XW-01 and XW-02 requirements whose integration edge this phase closes.
- `.planning/v1.48-MILESTONE-AUDIT.md` — Canonical finding that the rendered authenticated host UI does not initiate Crosswake, plus the required closure steps.
- `.planning/PROJECT.md` — v1.48 B2C alpha boundary, host/library ownership posture, and decisive planning preferences.
- `.planning/METHODOLOGY.md` — Decisive-defaulting, escalation, research-depth, and evidence-truth lenses.

### Locked predecessor contracts
- `.planning/phases/238-generated-auth-runtime-proof/238-CONTEXT.md` — Rendered browser proof, accessible selectors, readiness, and no-sleep requirements.
- `.planning/phases/239-hosted-session-interop/239-CONTEXT.md` — Personal-session adapter, evidence-only return, and fail-closed Crosswake boundary.
- `.planning/phases/240-alpha-operations-rehearsal/240-CONTEXT.md` — Provider-neutral B2C rehearsal and host launch boundary.
- `.planning/phases/240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow/240.3-CONTEXT.md` — Host-only runtime flow, controller ownership, continuation security, fixed navigation, and deterministic proof contracts.
- `.planning/phases/241-close-gap-ops-01-repair-controller-mfa-settings-rendering/241-CONTEXT.md` — Latest example/generated-host lane boundaries and deterministic protected-surface proof precedent.

### Adopter-facing boundary
- `guides/recipes/b2c-alpha.md` — Provider-neutral B2C recipe and the boundary between repository proof and adopter-host launch evidence.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/example/lib/example_web/live/app_live.ex` — Protected Tasklane account-home surface with existing `vt-*` action panels and stable `data-testid="app-account-home"` readiness.
- `test/example/lib/example_web/router.ex` — Existing authenticated, CSRF-protected `POST /crosswake/start` route and protected `/app` LiveView.
- `test/example/lib/example_web/controllers/crosswake_controller.ex` — Complete server-owned start/return/303 orchestration; no new controller behavior is needed for the rendered edge.
- `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` — Existing real-cookie-jar browser journey, final-state assertions, Referer check, and non-disclosure matrix; only the fabricated start interaction needs replacement.
- `scripts/ci/hosted-session-interop-proof.sh` — Existing bounded runtime setup and focused browser proof runner.
- `scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs` — Mechanical authority, callback-key, route/destination, and secret prohibitions that must remain green.

### Established Patterns
- Example-host UI uses Tasklane `vt-*`; admin/operator `sg-*` principles do not govern this non-admin surface.
- Sensitive browser journeys interact with rendered controls through roles/labels and stable readiness rather than injecting DOM or sleeping.
- Crosswake HTTP transitions stay controller-owned; server-side continuation state and freshly resolved backend session state determine authority.
- Success and recovery navigation remain fixed and generic, with no correlation material or identifiers in the final UI or URL.

### Integration Points
- Add the ordinary POST form/button to `ExampleWeb.AppLive` on `/app`.
- Change the Crosswake Playwright test to click the rendered control while leaving its downstream request and secrecy assertions intact.
- Preserve controller tests and P14 prohibitions as the security authority; add only focused rendered-control coverage needed to lock the new UI edge.
- Continue running the browser journey through `scripts/ci/hosted-session-interop-proof.sh` so the closure remains part of the exact-SHA evidence path.

</code_context>

<specifics>
## Specific Ideas

- The user confirmed the cohesive recommendation: existing `/app` host surface, native POST form, server-owned protocol inputs, and rendered role-based Playwright interaction.
- Prefer a plainly labeled Crosswake action within the account hub; placement as a dedicated panel or quick-action card is intentionally left open.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within the phase boundary. All todo matches were unrelated keyword collisions and were not folded into scope.

</deferred>

---

*Phase: 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control*
*Context gathered: 2026-08-11*
