# Phase 238: Generated Auth Runtime Proof - Research

**Researched:** 2026-08-05
**Domain:** Fresh Phoenix generated-host authentication browser proof
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Run browser proof against the same freshly scaffolded canonical B2C host lifecycle established in Phase 237, rather than `test/example` or source-only fixtures. This keeps generated output and runtime wiring as the thing being proven.
- **D-02:** Use one serial, browser-visible journey with the generated routes and deterministic development mailbox to prove registration, confirmation, password sign-in/logout, magic-link request/consumption, and reset-token password completion. Do not substitute direct context calls for rendered-flow proof.
- **D-03:** Exercise the generated Google start and callback routes through a deterministic local provider double; use an email already associated with a password account to prove the account-link-collision outcome. No test may need real Google credentials or network access. — **Reversibility:** costly — changing this boundary would alter generated-host callback evidence and the provider-double contract together.
- **D-04:** On every materially rendered B2C auth state reached by the journeys, run scoped Axe plus stable DOM assertions for label/control relationships and duplicate IDs. Use role or label selectors and LiveView readiness signals only; no sleep-based browser timing.
- **D-05:** Fold the generated-auth login-only coverage gap into AUTH-01, expanding the existing generated-host browser suite from a single login surface to the required complete email journey.
- **D-06:** Fold the absence of Axe coverage for `sigra-auth-*` surfaces into AUTH-03, with state-scoped checks that fail on accessibility regressions.

### the agent's Discretion
- Reuse the repository’s serial Playwright configuration, mailbox fixture, LiveView readiness conventions, and scoped `main.sigra-auth` Axe pattern.
- Choose the smallest deterministic provider-double seam that exercises the generated controller and callback state rather than mocking away the generated-host boundary.

### Deferred Ideas (OUT OF SCOPE)
- Passkey-primary duplicate-email and identifier work is out of scope because the canonical B2C profile disables passkeys.
- CSS parity, admin, CI-gate, release, and Crosswake-related matches remain in their owning phases; keyword matches did not justify expanding AUTH-01 through AUTH-03.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| AUTH-01 | Generated B2C browser suite proves all email journeys. | One serial generated-host Playwright journey, reusable mailbox link extractors, and real logout form submission. |
| AUTH-02 | Same suite proves Google start/callback and existing-email collision without credentials. | Host-local OIDC/provider double reached by the emitted `/auth/google` controller routes; static callback identity uses the already-created password account email. |
| AUTH-03 | Each rendered state passes Axe, label/control, and duplicate-ID checks. | Shared state assertion invoked after each material render, scoped to `main.sigra-auth`. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system and Rail Accent assets for admin UI work; Phase 238 does not modify admin UI. [VERIFIED: codebase grep]
- Support Light, Dark, and System modes where UI is changed; the Phase 238 proof should not alter auth styling or theme behavior. [VERIFIED: codebase grep]
- Browser tests use deterministic role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: AGENTS.md]
- Replace human/UAT claims with deterministic automation and durable machine-readable evidence; missing evidence blocks completion. [VERIFIED: AGENTS.md]

## Summary

Use a dedicated generated-auth acceptance harness that starts from Phase 237’s fresh B2C lifecycle, then runs a Playwright spec from the repository’s existing Playwright project against that temporary host. The existing generated-host suite is intentionally admin-focused, while the existing `golden-path.spec.ts` proves only an example host and includes passkey/MFA scope; neither is valid evidence for this phase. [VERIFIED: codebase grep]

The generated templates already expose the required routes and browser-visible outcomes: registration posts through the generated login action, confirmation links come from Swoosh’s development mailbox, password and magic-link login are controller flows, password reset is a LiveView flow, and logout is the generated `DELETE /users/log_out` controller action. [VERIFIED: codebase grep]

The key implementation seam is a test-only host-local Google/OIDC double. Keep provider `:google` and exercise the generated `/auth/google` request and callback controller routes; configure the generated host with non-secret dummy client values and a local `base_url`, then serve OIDC discovery, authorization, token, and userinfo responses locally. Assent 0.3.1 documents Google as OIDC and its current changelog documents the `:base_url` configuration name. [CITED: https://assent.hexdocs.pm/Assent.Strategy.Google.html] [CITED: https://hexdocs.pm/assent/CHANGELOG.html]

**Primary recommendation:** Add a fresh-host `generated-auth-runtime-proof` harness plus a dedicated serial `generated-auth.spec.ts`; do not extend `admin-generated.spec.ts`, do not test `test/example`, and do not use provider credentials or network calls.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Fresh canonical B2C lifecycle | API / Backend | Build / CI | `mix phx.new`, installer, migration, boot, and temporary-host configuration determine the generated runtime under test. [VERIFIED: codebase grep] |
| Rendered email auth journey | Browser / Client | API / Backend | Playwright operates generated forms and follows browser redirects while generated controllers/LiveViews own the state transitions. [VERIFIED: codebase grep] |
| Development mailbox token retrieval | API / Backend | Browser / Client | Swoosh local mailbox is served by the generated host; the browser fixture reads its JSON only to navigate the emitted link. [VERIFIED: codebase grep] |
| Google provider double | API / Backend | Browser / Client | A local host endpoint returns deterministic OAuth/OIDC responses while the browser follows the controller-created authorization redirect. [CITED: https://assent.hexdocs.pm/] |
| Accessibility proof | Browser / Client | — | Axe and DOM relationship checks inspect the hydrated rendered auth subtree. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---:|---|---|
| `@playwright/test` | lockfile `1.59.1` | Generated-host browser journey and assertions. | Already the repository’s browser runner, configured with `workers: 1`, `fullyParallel: false`, and `retries: 0`. [VERIFIED: codebase grep] |
| `@axe-core/playwright` | lockfile `4.11.2` | Scoped WCAG automated analysis of rendered auth states. | Already used with `AxeBuilder` in generated auth and admin specs. [VERIFIED: codebase grep] |
| `assent` | lockfile `0.3.1` | Google OIDC request/callback integration used by generated host. | Sigra’s Google strategy delegates to `Assent.Strategy.Google`; the phase must exercise that path. [VERIFIED: codebase grep] |

### Supporting

| Library / facility | Version | Purpose | When to Use |
|---|---:|---|---|
| Swoosh local mailbox | generated Phoenix dev facility | Deterministic confirmation, magic-link, and reset-link retrieval. | Only inside the temporary development host; never a real mail provider. [VERIFIED: codebase grep] |
| Phoenix LiveView | generated host | Hydrated registration, confirmation, and reset states. | Wait for `[data-phx-session].phx-connected` before LiveView interaction. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Host-local provider double | Real Google account / credentials | Violates D-03 and creates network/credential-dependent CI. [VERIFIED: CONTEXT.md] |
| Generated B2C host | `test/example` golden path | Tests a maintained fixture with passkey/MFA/admin/organization surfaces, not the Phase 237 generated B2C contract. [VERIFIED: codebase grep] |
| Real browser journey | Direct `Accounts`/`Sigra.OAuth.Callback` calls | Loses generated templates, controller routes, redirect/session state, and rendered accessibility evidence. [VERIFIED: CONTEXT.md] |

**Installation:** No dependency installation or version upgrade is authorized. Reuse the committed Playwright lockfile and the existing optional `assent` dependency. [VERIFIED: codebase grep]

## Package Legitimacy Audit

No new external package is recommended or installed by this phase. The existing lockfile pins Playwright 1.59.1 and Axe Playwright 4.11.2; do not update either as part of this work. [VERIFIED: npm registry]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---|---|---:|---:|---|---|---|
| `@playwright/test` | npm | existing lockfile | 52M/wk | microsoft/playwright | SUS (fresh release signal) | Reuse locked 1.59.1 only; no upgrade/install decision in phase. [VERIFIED: npm registry] |
| `@axe-core/playwright` | npm | existing lockfile | 8M/wk | dequelabs/axe-core-npm | OK | Reuse locked 4.11.2 only. [VERIFIED: npm registry] |

**Packages removed due to [SLOP] verdict:** none.

**Packages flagged as suspicious [SUS]:** none newly introduced. If a planner elects to upgrade Playwright despite scope, add `checkpoint:human-verify` before doing so. [VERIFIED: npm registry]

## Architecture Patterns

### System Architecture Diagram

```text
fresh Phoenix app
  -> canonical installer (--no-admin --no-organizations --no-passkeys)
  -> generated Google OAuth artifacts + temporary test-only double/config
  -> compile, migrate, boot temporary B2C host
  -> Playwright (single worker, no retries)
       -> generated email forms / LiveViews
       -> host /dev/mailbox/json -> emitted confirmation/magic/reset links
       -> generated /auth/google -> local authorization endpoint
       -> generated /auth/google/callback -> local token + userinfo endpoints
       -> rendered login collision message
       -> state-scoped Axe + DOM accessibility assertions
```

### Recommended Project Structure

```text
scripts/ci/
├── generated-auth-runtime-proof.sh       # fresh-host lifecycle, test-only host seams, boot/cleanup
test/example/priv/playwright/
├── fixtures/
│   └── mailbox.ts                         # extend to extract confirmation, magic, reset links without sleeps
└── tests/
    └── generated-auth.spec.ts             # generated B2C email, OAuth double/collision, a11y proof
```

### Pattern 1: Fresh-host acceptance boundary
**What:** Keep Phase 237’s exact installer-then-OAuth generator order, but add only temporary host-owned test files/configuration needed to expose a local provider double and development mailbox journey. [VERIFIED: Phase 237 context and smoke]

**When to use:** Every Phase 238 browser run, including CI; never substitute the example application. [VERIFIED: CONTEXT.md]

**Example:**

```bash
# Source: scripts/ci/passkeys-opt-out-smoke.sh (adapt, do not replace)
mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes
# add direct cloak_ecto prerequisite, then:
mix sigra.gen.oauth --providers google
# write test-only local provider configuration before booting this host
```

### Pattern 2: Observable-state synchronization
**What:** Wait on browser-visible outcomes—URL change, role-visible heading/alert, LiveView connected root, or mailbox item becoming available—rather than elapsed time. [VERIFIED: AGENTS.md]

**When to use:** Before each submit/click on a LiveView, after every redirect, and while waiting for an email to appear. [VERIFIED: codebase grep]

**Example:**

```typescript
// Source: existing generated-host and golden-path specs
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
}

await page.getByLabel('Email', { exact: true }).fill(email);
await page.getByRole('button', { name: 'Create an account' }).click();
await expect(page).not.toHaveURL(/\/users\/register/);
```

### Pattern 3: Per-rendered-state accessibility gate
**What:** Centralize state checks in one helper invoked after each meaningful auth render: scoped Axe, label/control association, and duplicate-ID uniqueness. [VERIFIED: CONTEXT.md]

**When to use:** Register, confirmation, login (collapsed and expanded alternatives), magic-link result, reset request, reset completion, Google collision/login result, and any explicit error/expired render reached by the traced journeys. [VERIFIED: template and route grep]

**Example:**

```typescript
// Source: existing Axe usage in admin-generated.spec.ts
const root = page.locator('main.sigra-auth');
const { violations } = await new AxeBuilder({ page })
  .include('main.sigra-auth')
  .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
  .analyze();
expect(violations).toHaveLength(0);

await expect(root.locator('label[for]')).toEvaluateAll(labels =>
  labels.every(label => {
    const id = label.getAttribute('for');
    return id && document.getElementById(id) !== null;
  }),
);
```

### Pattern 4: Real generated controller plus local OIDC double
**What:** The generated `/auth/google` request action stores signed state/PKCE in its session and redirects to the provider. The local double must receive that redirect, preserve its `state`, redirect back to generated `/auth/google/callback`, and supply deterministic token/userinfo responses so the generated callback invokes `Sigra.OAuth.handle_callback`. [VERIFIED: codebase grep]

**When to use:** Google start/callback and collision only. Use a pre-created password user whose email exactly equals the double’s userinfo email; assert the generated controller’s login redirect and collision flash, not a direct callback return value. [VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **Mocking `Sigra.OAuth.handle_callback/4` or `OAuthController`:** bypasses the generated state/session/controller boundary that AUTH-02 requires. [VERIFIED: CONTEXT.md]
- **Directly browsing `/auth/google/callback?code=...` without first starting `/auth/google`:** omits the generated signed state and PKCE session established by `request/2`. [VERIFIED: codebase grep]
- **Using the current mailbox helper unchanged:** it contains `waitForTimeout(1_000)`, which conflicts with D-04’s no-sleep rule. Replace with a bounded observable polling/retry mechanism or a host-side mailbox-readiness endpoint. [VERIFIED: codebase grep]
- **Adding a second browser package or separate test runner:** existing locked Playwright/Axe facilities cover this scope. [VERIFIED: codebase grep]
- **Extending admin-generated proof:** its provisioning adds admin/organization data and violates the B2C boundary. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Browser automation | custom WebDriver/process polling | Existing Playwright project/config | It already encodes serial execution, no retries, failure artifacts, and host base URL injection. [VERIFIED: codebase grep] |
| WCAG rule engine | custom accessibility checks | `@axe-core/playwright` scoped to `main.sigra-auth` | Axe handles broad rule coverage; supplemental DOM checks only cover explicit AUTH-03 predicates. [VERIFIED: codebase grep] |
| Email transport double | fake generated-context mail functions | Generated host’s Swoosh local mailbox | Preserves the actual generated delivery/link rendering path. [VERIFIED: codebase grep] |
| OAuth callback result | controller/module stubs | Host-local OIDC endpoint double | Preserves browser redirect, signed state, token exchange, normalized profile, and generated collision handling. [VERIFIED: codebase grep] |

**Key insight:** The only new code should be test harness/double code. Authentication templates, controller semantics, and public OAuth API remain the subject under test. [VERIFIED: CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Proving the example app instead of generated output
**What goes wrong:** A green `golden-path.spec.ts` covers the fixture’s own configuration and extra MFA/passkey surfaces, not a newly scaffolded B2C host. [VERIFIED: codebase grep]

**How to avoid:** Start every run from the canonical Phase 237 host lifecycle and point `SIGRA_EXAMPLE_URL` at its free port. [VERIFIED: codebase grep]

### Pitfall 2: OAuth double skips signed state
**What goes wrong:** A callback-only test can appear green while the generated `request/2` state/PKCE session wiring is broken. [VERIFIED: codebase grep]

**How to avoid:** Begin in the browser at `/auth/google`; make the local authorization endpoint relay its exact `state` parameter to the callback. [VERIFIED: codebase grep]

### Pitfall 3: Wrong double email never reaches collision branch
**What goes wrong:** A new or mismatched provider email takes registration or generic-error paths instead of `:link_confirmation_required`. [VERIFIED: codebase grep]

**How to avoid:** Create a confirmed password account during temporary-host setup and return its exact normalized email plus a stable previously-unseen provider subject from local userinfo. [VERIFIED: codebase grep]

### Pitfall 4: Sleep-based mailbox polling
**What goes wrong:** Existing fixture delay polling contradicts the locked no-sleeps requirement and may flake under variable local-mailbox timing. [VERIFIED: codebase grep]

**How to avoid:** Use Playwright `expect.poll` on `/dev/mailbox/json` (or an equivalent observable readiness assertion) with a bounded timeout; provide link extraction for all three token routes. [ASSUMED]

### Pitfall 5: Axe runs at the wrong boundary
**What goes wrong:** Full-document scans can fail for unrelated Phoenix shell/dev-route content or miss a collapsed/redirected auth render. [VERIFIED: codebase grep]

**How to avoid:** Scan the currently rendered `main.sigra-auth` subtree after stable readiness and separately assert labels/IDs in that same root. [VERIFIED: CONTEXT.md]

### Pitfall 6: Claiming local proof when prerequisites are missing
**What goes wrong:** This workstation currently has Node/npm/Mix and Playwright node modules, but no reachable PostgreSQL service, no Playwright browser cache, and `phx_new` resolves 1.8.9 while the Phase 237 script expects 1.8.8. [VERIFIED: environment probe]

**How to avoid:** Treat the hosted CI lane or a correctly provisioned local environment as required evidence; never close AUTH-01 through AUTH-03 on a fixture-only or compile-only result. [VERIFIED: AGENTS.md]

## Code Examples

### Stable duplicate-ID assertion

```typescript
// Source: Phase 238 requirement; implementation pattern is local
async function assertUniqueIds(page: Page) {
  const duplicates = await page.locator('main.sigra-auth [id]').evaluateAll(nodes => {
    const counts = new Map<string, number>();
    for (const node of nodes) {
      const id = node.id;
      counts.set(id, (counts.get(id) ?? 0) + 1);
    }
    return [...counts.entries()].filter(([, count]) => count > 1).map(([id]) => id);
  });
  expect(duplicates, `duplicate IDs in auth state: ${duplicates.join(', ')}`).toEqual([]);
}
```

### Browser-visible logout

```typescript
// Source: generated SessionController delete action and emitted DELETE route
await page.getByRole('button', { name: /log out/i }).click();
await expect(page).toHaveURL(/\/users\/log_in/);
await expect(page.getByText('Logged out successfully.')).toBeVisible();
```

### Collision proof predicate

```typescript
// Source: generated OAuthController collision branch
await page.goto('/auth/google');
await expect(page).toHaveURL(/\/auth\/google\/callback\?.*code=.*state=/);
await expect(page).toHaveURL(/\/users\/log_in/);
await expect(page.getByText(/An account with this email exists/i)).toBeVisible();
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Example-only golden path | Generated-host parity browser lane | Existing repository pattern | Phase 238 must add the B2C-specific variant without pulling in admin scope. [VERIFIED: codebase grep] |
| Fixed `page.waitForTimeout` mailbox polling | Observable readiness / retry assertion | Required by D-04 | Token retrieval must become deterministic without sleeps. [VERIFIED: CONTEXT.md] |
| Assent `:site` endpoint configuration | `:base_url` | Assent 0.3.0 | Test-only double configuration must use current terminology. [CITED: https://hexdocs.pm/assent/CHANGELOG.html] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Playwright `expect.poll` can replace the existing fixed-delay mailbox loop while preserving bounded deterministic behavior in this repository version. | Common Pitfalls | Implementer needs an equivalent observable helper if project constraints/version prevent it. |
| A2 | The generated host can configure Assent Google’s `base_url` to a host-local OIDC double without a Sigra wrapper change. | Summary / Pattern 4 | A short harness spike may reveal an additional narrowly scoped configuration passthrough is required; do not silently fall back to real Google. |

## Open Questions

1. **Does `Assent.Strategy.Google` 0.3.1 accept the generated provider config’s local `base_url` through both authorize and callback paths?**
   - What we know: Sigra forwards provider configuration to Assent and Assent 0.3.0 renamed `:site` to `:base_url`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/assent/CHANGELOG.html]
   - What's unclear: The exact local discovery/endpoint shape should be proven against the locked dependency before the broader journey is authored.
   - Recommendation: Make Plan Wave 0 a focused temporary-host spike: run `/auth/google`, assert the local authorization location, complete the callback, and assert the collision. If it fails, add only the smallest test-only config passthrough necessary; retain Google provider identity and generated controller route.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Node.js | Playwright runner | ✓ | 22.14.0 | — [VERIFIED: environment probe] |
| npm | existing Playwright lockfile | ✓ | 11.1.0 | — [VERIFIED: environment probe] |
| Playwright node modules | browser suite | ✓ | lockfile 1.59.1 | — [VERIFIED: environment probe] |
| Playwright browser binaries | browser suite | ✗ | — | CI browser-install step / local `npm run install-browsers`. [VERIFIED: environment probe] |
| PostgreSQL | fresh host migration | ✗ | no reachable local server | Existing GitHub Actions PostgreSQL service. [VERIFIED: environment probe] |
| `phx_new` | fresh host scaffold | ✓, wrong pin | 1.8.9 (Phase 237 expects 1.8.8) | install the pinned archive before local reproduction. [VERIFIED: environment probe] |

**Missing dependencies with no fallback:** none; CI provides the browser and PostgreSQL lane.

**Missing dependencies with fallback:** local browser binaries and PostgreSQL use existing CI; local `phx_new` must be aligned to the Phase 237 contract before running the script.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | `@playwright/test` lockfile 1.59.1 plus existing serial config. [VERIFIED: codebase grep] |
| Config file | `test/example/priv/playwright/playwright.config.ts` [VERIFIED: codebase grep] |
| Quick run command | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://127.0.0.1:$PORT npx playwright test tests/generated-auth.spec.ts --project=generated-auth` [ASSUMED] |
| Full suite command | `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh` [ASSUMED] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| AUTH-01 | register, confirm, password sign-in/logout, magic link, reset completion on fresh generated host | browser integration | generated auth harness command | ❌ Wave 0 |
| AUTH-02 | Google request/callback local double and existing-email collision | browser integration | generated auth harness command | ❌ Wave 0 |
| AUTH-03 | state-scoped Axe, label/control, duplicate-ID checks | browser accessibility | generated auth harness command | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** focused generated-auth Playwright target after the temporary host is up. [ASSUMED]
- **Per wave merge:** fresh-host harness command. [ASSUMED]
- **Phase gate:** exact-commit CI generated-host browser evidence green; do not waive unavailable local prerequisites. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `scripts/ci/generated-auth-runtime-proof.sh` — lifecycle, test-only local provider double/config, bounded boot/cleanup.
- [ ] `test/example/priv/playwright/tests/generated-auth.spec.ts` — all AUTH-01 to AUTH-03 browser predicates.
- [ ] Extend `fixtures/mailbox.ts` — magic/reset extractors and no-sleep observable readiness.
- [ ] Playwright config project/match for the new generated B2C lane, excluding it from generic example projects.
- [ ] CI job/artifact collection using the generated-host lane; retain deterministic failure diagnostics.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | Prove rendered credential/magic/reset paths against the generated host; use no real provider credentials. [VERIFIED: REQUIREMENTS.md] |
| V3 Session Management | yes | Exercise generated login and real `DELETE /users/log_out`; Google request/callback preserves signed state/PKCE session behavior. [VERIFIED: codebase grep] |
| V4 Access Control | no | Admin and organization scopes are deliberately absent from canonical B2C output. [VERIFIED: CONTEXT.md] |
| V5 Input Validation | yes | Browser uses deterministic inputs; generated controller/LiveView remains the validation owner. [VERIFIED: codebase grep] |
| V6 Cryptography | yes | Reuse generated OAuth state/PKCE and dummy ephemeral `CLOAK_KEY`; never implement crypto or add secrets. [VERIFIED: codebase grep] |

### Known Threat Patterns for generated OAuth/browser proof

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Callback invoked without request state | Tampering | Follow generated start redirect and relay state through local authorization endpoint. [VERIFIED: codebase grep] |
| CI credential disclosure or live provider dependency | Information Disclosure | Dummy config + host-local provider double; no network. [VERIFIED: CONTEXT.md] |
| Existing email silently links identity | Elevation of Privilege | Precreate password account and assert generated `link_confirmation_required` message/redirect. [VERIFIED: codebase grep] |
| Accessibility regression hidden in a redirect or shell | Denial of Service | Run scoped Axe and explicit DOM checks on every reached material auth render. [VERIFIED: CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- Repository sources: `scripts/ci/passkeys-opt-out-smoke.sh`, generated auth/OAuth templates, `lib/sigra/oauth*`, Playwright config/specs, mailbox fixture, requirements, and Phase 237 artifacts — lifecycle, route, controller, and existing-test findings. [VERIFIED: codebase grep]
- [Assent Google strategy docs](https://assent.hexdocs.pm/Assent.Strategy.Google.html) — Google OIDC usage/config. [CITED: https://assent.hexdocs.pm/Assent.Strategy.Google.html]
- [Assent changelog](https://hexdocs.pm/assent/CHANGELOG.html) — current `:base_url` terminology. [CITED: https://hexdocs.pm/assent/CHANGELOG.html]

### Secondary (MEDIUM confidence)

- npm registry — current package versions, source repositories, postinstall inspection, and legitimacy results. [VERIFIED: npm registry]

### Tertiary (LOW confidence)

- None beyond assumptions A1–A2, both explicitly gated by a Wave 0 spike.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all runner/a11y dependencies are existing locked repository facilities. [VERIFIED: codebase grep]
- Architecture: MEDIUM — fresh-host/controller/state boundaries are verified; exact Assent local-double configuration is gated by Wave 0. [VERIFIED: codebase grep]
- Pitfalls: HIGH — derived from current fixture/template/config inspection and locked constraints. [VERIFIED: codebase grep]

**Research date:** 2026-08-05
**Valid until:** 2026-08-12 (fast-moving browser/OAuth dependency surface)
