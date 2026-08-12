# Phase 242: Close gap: XW-01/XW-02 — add rendered Crosswake start control - Research

**Researched:** 2026-08-11
**Domain:** Phoenix LiveView host UI, CSRF-protected HTTP navigation, and deterministic Playwright proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

None — analysis stayed within the phase boundary. All todo matches were unrelated keyword collisions and were not folded into scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| XW-01 | A backend-validated SIGRA personal-account session can project to `crosswake_sigra` without inventing an organization or exposing credentials/tokens. | The UI emits only a standard authenticated POST plus CSRF; the existing controller, continuation, adapter, and browser non-disclosure matrix retain ownership. [VERIFIED: codebase grep] |
| XW-02 | Missing, expired, revoked, or account-switched session state fails closed for Crosswake replay; return data alone never grants access. | The start button remains a thin entry point to the existing controller; no new client-provided route, destination, binding, state, or continuation values are introduced. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 242 closes a single rendered-entry gap, not a Crosswake protocol gap. `ExampleWeb.AppLive` already renders the authenticated Tasklane account hub at `/app`, has stable `data-testid="app-account-home"` readiness, and offers a three-item `vt-card-grid` of account actions. The router already routes authenticated `POST /crosswake/start` to `CrosswakeController.start/2`; that controller issues server-owned continuation data and redirects through the fixed local return route. [VERIFIED: codebase grep]

Render one plainly named native submit button in an ordinary action-bearing form in that existing account hub. Use Phoenix's form component with `for={%{}}`, `action={~p"/crosswake/start"}`, and `method="post"`, without `phx-submit`, values, or LiveView events. Phoenix documents that an action-bearing non-GET form receives a CSRF token automatically; the action is necessary for a regular HTTP request. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html]

Replace the Playwright-created DOM form with `page.getByRole("button", {name: ...}).click()` after registering the existing `/crosswake/return` and final `/app` request observers. Playwright documents role-and-accessible-name locators and locator auto-waiting; this proves the visible user journey without weakening the real-cookie-jar, no-Referer, exact-key, or secret non-disclosure checks. [CITED: https://playwright.dev/docs/api/class-locator]

**Primary recommendation:** Add a Tasklane quick-action panel containing a native Phoenix CSRF POST form and uniquely named Crosswake button, then make the focused browser proof click that button and contract-lock the form's route/method/name/no-`phx-submit` boundary.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Visible start affordance | Browser / Client | Frontend Server (LiveView render) | `/app` renders an accessible native control; it supplies no protocol authority. [VERIFIED: codebase grep] |
| CSRF-protected start transition | API / Backend | Browser / Client | The browser makes a normal POST; Phoenix validates CSRF and the authenticated router dispatches to the controller. [VERIFIED: codebase grep] |
| Continuation, PKCE transport, session identity, evaluator decision | API / Backend | Database / Storage | Existing `CrosswakeController`, continuation context, session adapter, and persisted continuation own those values and checks. [VERIFIED: codebase grep] |
| Final safe navigation | API / Backend | Browser / Client | Existing controller emits 303 redirects and the continuation destination is fixed to `/app`. [VERIFIED: codebase grep] |
| End-to-end closure proof | Browser / Client | API / Backend | Playwright uses the real cookie jar and observes server-generated transitions, while focused suites preserve fail-closed contracts. [VERIFIED: codebase grep] |

## Project Constraints (from AGENTS.md)

- This is example-host UI, not admin UI: preserve the Tasklane `vt-*` visual system; do not introduce `sg-*` admin styling or Rail Accent/admin-theme work. [VERIFIED: 242-CONTEXT.md]
- If admin UI is touched, preserve `sg-*` cascade-layer/BEM, Rail Accent assets, Light/Dark/System support, and deterministic tests. This phase must not touch admin UI. [VERIFIED: AGENTS.md]
- Use deterministic automation instead of manual UAT. Evidence must not be waived when a requirement cannot be proven. [VERIFIED: AGENTS.md]
- Keep Playwright tests deterministic: role selectors, stable hooks, LiveView readiness, no sleeps; retain one worker and zero retries for this focused project. [VERIFIED: AGENTS.md; VERIFIED: codebase grep]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView / Phoenix.Component | `~> 1.1.0` / `~> 1.8.5` | Render `/app` and generate a normal CSRF-protected POST form. | Already powers the host and supports action-bearing regular forms with automatic CSRF token generation. [VERIFIED: test/example/mix.exs; CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html] |
| `@playwright/test` | `^1.48.0` | Drive the actual visible start button and assert the browser journey. | Already owns the serial `crosswake-hosted-runtime` project and its request-level checks. [VERIFIED: test/example/priv/playwright/package.json; VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Existing `crosswake_sigra` dependency | `~> 0.1.3` | Evaluator-facing, in-process Crosswake behavior. | Do not modify it; it remains behind the current server-owned adapter. [VERIFIED: test/example/mix.exs; VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native action-bearing POST form | LiveView `phx-submit` event | Rejected by locked D-02: it would create a new LiveView orchestration path rather than use the established HTTP controller boundary. [VERIFIED: 242-CONTEXT.md] |
| Role-based click | `page.evaluate()` fabricated form | Rejected by locked D-08: it bypasses rendered user UI and is the precise audit gap. [VERIFIED: 242-CONTEXT.md; VERIFIED: .planning/v1.48-MILESTONE-AUDIT.md] |
| `/app` Tasklane control | Admin or generated-host UI | Rejected by locked D-01/D-03/D-07: this phase is a host-only example surface. [VERIFIED: 242-CONTEXT.md] |

**Installation:** None — use existing dependencies only. [VERIFIED: 242-CONTEXT.md; VERIFIED: test/example/mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Authenticated user
  -> GET /app (ExampleWeb.AppLive; rendered Tasklane button; stable readiness)
  -> native form POST /crosswake/start (standard CSRF only)
  -> authenticated router
  -> CrosswakeController.start/2
  -> server-owned continuation + encrypted HttpOnly transport
  -> 303 GET /crosswake/return?continuation&state
  -> exact-key validation, fresh session resolution, one-time claim, evaluator
     -> allow: 303 /app
     -> deny/session unavailable: existing fixed recovery response

Playwright: role-based button click -> observes return request + /app document request -> asserts no Referer and no secret/correlation disclosure.
```

### Recommended Project Structure

```text
test/example/
├── lib/example_web/live/app_live.ex                    # rendered host-only Crosswake entry
├── test/example_web/live/app_live_test.exs             # rendered-control contract
└── priv/playwright/tests/crosswake-hosted-runtime.spec.ts # user-operated cookie-jar proof

test/sigra/planning/
└── phase_240_3_hosted_crosswake_runtime_test.exs       # update only if its source-contract assertions need the new rendered boundary
```

### Pattern 1: Native form delegates to a controller-owned transition

**What:** Render a regular form with an action and POST method but no `phx-submit`; submit only Phoenix's CSRF field and the native submit button.

**When to use:** A LiveView page needs to initiate an existing controller-owned redirect flow rather than handle a LiveView event.

**Example:**

```elixir
<.form
  for={%{}}
  action={~p"/crosswake/start"}
  method="post"
  class="vt-panel"
  data-testid="app-crosswake-start"
>
  <p class="vt-kicker">Account access</p>
  <h2 class="vt-panel__title">Continue to Crosswake</h2>
  <p class="vt-copy">Start a secure Crosswake session for this account.</p>
  <button type="submit" class="vt-btn vt-btn--primary">Continue to Crosswake</button>
</.form>
```

The `action` is the key regular-HTTP contract and the non-GET action-bearing form receives Phoenix's CSRF token; the exact accessible wording and placement remain discretionary. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html]

### Pattern 2: Pre-register navigation observers, then click the visible control

**What:** Start `waitForRequest` promises before clicking the named button, then inspect only the observed server-generated URLs in memory.

**When to use:** Verifying redirect chains where an intermediate value must be checked but never logged, injected, retained, or reconstructed.

**Example:**

```typescript
const returnRequest = page.waitForRequest((request) => {
  const url = new URL(request.url());
  return request.method() === 'GET' && url.pathname === '/crosswake/return';
});
const appRequest = page.waitForRequest((request) => {
  const url = new URL(request.url());
  return request.method() === 'GET' && request.resourceType() === 'document' && url.pathname === '/app';
});

await page.getByRole('button', { name: 'Continue to Crosswake' }).click();
```

`getByRole` uses the native button role and accessible name, with Playwright auto-waiting; the implementation must retain the test's existing no-Referer, exact callback-key, and final non-disclosure assertions after this click. [CITED: https://playwright.dev/docs/api/class-locator; VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **`page.evaluate()` form fabrication:** It submits a crafted request from the DOM and cannot prove that an authenticated user can discover and operate the host control. [VERIFIED: .planning/v1.48-MILESTONE-AUDIT.md]
- **`phx-submit` or a new LiveView event:** It bypasses the established controller as the HTTP orchestration boundary. [VERIFIED: 242-CONTEXT.md]
- **Hidden protocol inputs:** Do not render continuation, state, PKCE verifier, binding, session identity, route, destination, evaluator, or navigation fields. [VERIFIED: 242-CONTEXT.md]
- **Duplicate security tests:** Do not copy the controller denial or P14 prohibition matrix into UI tests; preserve and run them as the authority while adding only the rendered edge contract. [VERIFIED: 242-CONTEXT.md]
- **Admin styling or theme work:** `vt-*` is the only relevant presentation system; admin Light/Dark/System requirements do not expand this host-only phase. [VERIFIED: 242-CONTEXT.md; VERIFIED: AGENTS.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSRF submission | Custom meta-token extraction and manually appended hidden input | Existing `Phoenix.Component.form/1` action-bearing form | Phoenix generates the standard CSRF token for non-GET forms with an action. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html] |
| Redirect/protocol orchestration | New client event, route, controller, or template | Existing `POST /crosswake/start` and `CrosswakeController` | The controller already owns issuance, transport, fixed return, denial, and safe destination. [VERIFIED: codebase grep] |
| Browser interaction | Synthetic form or direct HTTP/cookie manipulation | Playwright `getByRole(...).click()` | It proves the accessible rendered surface and benefits from locator auto-waiting. [CITED: https://playwright.dev/docs/api/class-locator] |
| Security proof | New UI-only denial/evaluator suite | Existing controller, continuation, adapter, and P14 suites | Their existing tests are the server-side security authority; the phase's new evidence is the missing user entry point. [VERIFIED: codebase grep] |

**Key insight:** The rendered control is intentionally a zero-configuration edge. Giving it protocol fields or client authority would turn a one-line host entry point into a second security boundary.

## Common Pitfalls

### Pitfall 1: Form is visually present but is not a normal controller POST

**What goes wrong:** The control has `phx-submit`, no action, or client code that intercepts/reconstructs the request.

**Why it happens:** LiveView forms are commonly used for event handling, but this transition is explicitly controller-owned.

**How to avoid:** Assert the rendered source/HTML contract includes `/crosswake/start`, `method="post"`, a native named submit button, and no `phx-submit`; keep the route and controller unchanged. [VERIFIED: 242-CONTEXT.md]

**Warning signs:** A new `handle_event/3`, new route/controller action, or test-side CSRF/DOM fabrication appears.

### Pitfall 2: Test misses the redirect due to observer timing

**What goes wrong:** `waitForRequest` is registered after the click and intermittently misses the quick localhost transition.

**Why it happens:** The test starts watching only after the native navigation begins.

**How to avoid:** Create both `/crosswake/return` and final document `/app` request promises before clicking the button; await them after the click. [VERIFIED: codebase grep]

**Warning signs:** Flaky timeout failures despite a visible final page.

### Pitfall 3: Closure proof regresses secrecy coverage

**What goes wrong:** Replacing the fabricated form accidentally removes the exact callback-key, absent-Referer, final-URL, final-DOM, or cookie-jar assertions.

**Why it happens:** The visible control change looks small and downstream assertions can be mistaken as unrelated.

**How to avoid:** Alter only the submission block; retain all observers, sentinels, final `/app` readiness, and response assertions verbatim where possible. [VERIFIED: 242-CONTEXT.md; VERIFIED: codebase grep]

**Warning signs:** The spec no longer asserts `continuation`/`state` exactness, no Referer, or absence of `pkce_verifier`.

### Pitfall 4: Scope creep into unresolved Crosswake review debt

**What goes wrong:** The plan also changes continuation cardinality, transport storage, generated output, or Crosswake dependency behavior.

**Why it happens:** Prior review material identifies separate runtime concerns.

**How to avoid:** Treat those as out of scope; phase 242 changes the authenticated rendered entry and proof only. [VERIFIED: 242-CONTEXT.md]

**Warning signs:** Changes under `crosswake_controller.ex`, continuation modules/migrations, `lib/sigra`, templates, or dependency manifests.

## Code Examples

Verified patterns from current project code and official documentation:

### Rendered controller form and deterministic test interaction

```elixir
# Source pattern: existing controller forms use action + method="post";
# Phoenix.Component documents automatic CSRF for action-bearing non-GET forms.
<.form for={%{}} action={~p"/crosswake/start"} method="post" class="vt-panel">
  <button type="submit" class="vt-btn vt-btn--primary">Continue to Crosswake</button>
</.form>
```

```typescript
// Source pattern: existing Crosswake proof already registers request observers first.
await page.getByRole('button', { name: 'Continue to Crosswake' }).click();
await expect(page.locator('[data-testid="app-account-home"]')).toBeVisible();
```

Sources: [Phoenix.Component documentation](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html), [Playwright Locator documentation](https://playwright.dev/docs/api/class-locator). [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html; CITED: https://playwright.dev/docs/api/class-locator]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Playwright creates an invisible CSRF form through `page.evaluate()` | Rendered accessible Tasklane button submits the existing endpoint | Phase 242 | Evidence moves from a crafted protocol request to a complete user-operated host journey. [VERIFIED: .planning/v1.48-MILESTONE-AUDIT.md] |

**Deprecated/outdated:**

- The test-local fabricated form: it must be removed from `crosswake-hosted-runtime.spec.ts` because it bypasses the missing rendered integration edge. [VERIFIED: .planning/v1.48-MILESTONE-AUDIT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A fourth quick-action panel is the smallest and most coherent placement for the named Crosswake control. | Open Questions | Low — planner may instead choose a dedicated Tasklane panel without affecting protocol or test contracts. |

## Open Questions

1. **Exact visible label and placement**
   - What we know: the button must be obvious, accessible, and Tasklane-consistent; the account hub already has a three-item quick-actions grid. [VERIFIED: 242-CONTEXT.md; VERIFIED: codebase grep]
   - What's unclear: whether maintaining a symmetrical grid is preferred to a dedicated Crosswake action panel.
   - Recommendation: add it as a fourth quick-action panel with a unique `Continue to Crosswake` button; this is the smallest visible extension and keeps the affordance on the primary account action surface. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | Compile and focused LiveView/controller tests | ✓ | Elixir/Mix 1.19.5, OTP 28 | — [VERIFIED: local environment] |
| Node / npm | Playwright focused browser proof | ✓ | Node 22.14.0 / npm 11.1.0 | — [VERIFIED: local environment] |
| PostgreSQL configuration | `hosted-session-interop-proof.sh --browser-only` migration and host | ✓ | `tmp/db.env` present; psql 14.17 available | — [VERIFIED: local environment] |
| Chromium Playwright project | Real cookie-jar journey | ✓ | Repository-managed `@playwright/test` dependency; browser binary was not launched during research | Install the repository's documented browser dependency only if the focused runner reports it missing. [VERIFIED: test/example/priv/playwright/package.json] |

**Missing dependencies with no fallback:** None identified.

**Missing dependencies with fallback:** None identified.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Phoenix LiveView test helpers) and Playwright `@playwright/test` `^1.48.0`. [VERIFIED: test/example/mix.exs; VERIFIED: test/example/priv/playwright/package.json] |
| Config file | `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase grep] |
| Quick run command | `cd test/example && mix test test/example_web/live/app_live_test.exs` |
| Full focused closure command | `scripts/ci/hosted-session-interop-proof.sh --browser-only` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| XW-01 | Authenticated `/app` renders a visible, named, normal POST control with no protocol values; role click reaches the existing personal-session journey. | LiveView unit + browser integration | `cd test/example && mix test test/example_web/live/app_live_test.exs` and `scripts/ci/hosted-session-interop-proof.sh --browser-only` | ✅ — extend existing files |
| XW-02 | The same role-driven journey preserves existing exact callback keys, no-Referer, fixed `/app`, and secret/correlation non-disclosure checks. | Browser integration + existing server security suites | `scripts/ci/hosted-session-interop-proof.sh --browser-only`; then existing focused controller/continuation/P14 commands in the full runner | ✅ — extend existing browser file; retain existing suites |

### Sampling Rate

- **Per task commit:** `cd test/example && mix test test/example_web/live/app_live_test.exs`
- **Per wave merge:** `scripts/ci/hosted-session-interop-proof.sh --browser-only`
- **Phase gate:** Run the full existing `scripts/ci/hosted-session-interop-proof.sh` only from a clean exact-SHA worktree when receipt sealing is authorized; it includes all controller, continuation, adapter, browser, prohibition, and source-contract checks. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] Extend `test/example/test/example_web/live/app_live_test.exs` with rendered form route/method/name/no-event contract assertions.
- [ ] Replace only the fabricated submission in `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` with the named role click.
- [ ] Add/update the narrow planning source contract only if needed to assert the newly rendered `AppLive` control; do not duplicate server security assertions.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing authenticated router pipeline and fresh backend session resolution. [VERIFIED: codebase grep] |
| V3 Session Management | yes | Existing encrypted HttpOnly session transport, one-time continuation, and session re-resolution. [VERIFIED: codebase grep] |
| V4 Access Control | yes | Existing evaluator-owned decision; no client-selected authority or navigation. [VERIFIED: 242-CONTEXT.md; VERIFIED: codebase grep] |
| V5 Input Validation | yes | The new form submits no Crosswake inputs; existing callback accepts exact server-validated keys. [VERIFIED: 242-CONTEXT.md; VERIFIED: codebase grep] |
| V6 Cryptography | yes | Reuse existing PKCE/continuation and encrypted session behavior; do not add client-side or custom cryptography. [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-site start request | Spoofing / Tampering | Phoenix-generated CSRF token on the native POST form and existing browser pipeline. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html] |
| Client authority or navigation smuggling | Elevation of Privilege | Render no route/destination/binding/state inputs; existing callback checks exact permitted keys before evaluation. [VERIFIED: 242-CONTEXT.md; VERIFIED: codebase grep] |
| PKCE/correlation disclosure | Information Disclosure | Preserve current encrypted HttpOnly transport and browser URL/DOM/no-Referer checks. [VERIFIED: codebase grep] |
| Replay/account switch | Elevation of Privilege | Preserve existing one-time continuation, fresh backend lookup, binding checks, and evaluator-owned decision. [VERIFIED: 242-CONTEXT.md; VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- Current codebase: `test/example/lib/example_web/live/app_live.ex`, router, Crosswake controller, existing browser spec, proof runner, prohibition guard, and focused test suites — host boundary and verification seams. [VERIFIED: codebase grep]
- `242-CONTEXT.md` and `.planning/v1.48-MILESTONE-AUDIT.md` — locked phase scope and audit-defined closure. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- [Phoenix.Component documentation](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) — normal action-bearing forms and CSRF mechanics. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html]
- [Playwright Locator documentation](https://playwright.dev/docs/api/class-locator) — role/name locators and auto-wait behavior. [CITED: https://playwright.dev/docs/api/class-locator]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependency; existing Phoenix and Playwright versions are pinned in repository manifests and the relevant behavior is cited in official docs.
- Architecture: HIGH — all tiers and boundaries are locked by CONTEXT.md and implemented in the existing host/controller path.
- Pitfalls: HIGH — derived from the milestone audit, locked constraints, and current test/code contracts.

**Research date:** 2026-08-11
**Valid until:** 2026-09-10 (stable, repository-local implementation seam)
