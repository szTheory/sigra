# Phase 238: Generated Auth Runtime Proof - Context

**Gathered:** 2026-08-05 (assumptions mode, automated)
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish deterministic browser and accessibility proof for the generated B2C email and Google authentication journeys without provider credentials. The suite must cover the scoped email flows, Google start/callback and account-link collision behavior, and rendered-state accessibility; it must not add admin, organizations, passkeys, real-provider credentials, or physical-device proof.
</domain>

<decisions>
## Implementation Decisions

### Generated-host proof boundary
- **D-01:** Run browser proof against the same freshly scaffolded canonical B2C host lifecycle established in Phase 237, rather than `test/example` or source-only fixtures. This keeps generated output and runtime wiring as the thing being proven.

### Email authentication journey
- **D-02:** Use one serial, browser-visible journey with the generated routes and deterministic development mailbox to prove registration, confirmation, password sign-in/logout, magic-link request/consumption, and reset-token password completion. Do not substitute direct context calls for rendered-flow proof.

### Google provider double and collision semantics
- **D-03:** Exercise the generated Google start and callback routes through a deterministic local provider double; use an email already associated with a password account to prove the account-link-collision outcome. No test may need real Google credentials or network access. — **Reversibility:** costly — changing this boundary would alter generated-host callback evidence and the provider-double contract together.

### Accessibility and deterministic assertions
- **D-04:** On every materially rendered B2C auth state reached by the journeys, run scoped Axe plus stable DOM assertions for label/control relationships and duplicate IDs. Use role or label selectors and LiveView readiness signals only; no sleep-based browser timing.

### Folded Todos
- **D-05:** Fold the generated-auth login-only coverage gap into AUTH-01, expanding the existing generated-host browser suite from a single login surface to the required complete email journey.
- **D-06:** Fold the absence of Axe coverage for `sigra-auth-*` surfaces into AUTH-03, with state-scoped checks that fail on accessibility regressions.

### the agent's Discretion
- Reuse the repository’s serial Playwright configuration, mailbox fixture, LiveView readiness conventions, and scoped `main.sigra-auth` Axe pattern.
- Choose the smallest deterministic provider-double seam that exercises the generated controller and callback state rather than mocking away the generated-host boundary.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and prior-phase contract
- `.planning/ROADMAP.md` — Phase 238 goal, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` — AUTH-01 through AUTH-03 acceptance requirements.
- `.planning/phases/237-canonical-b2c-generator-contract/237-CONTEXT.md` — exact canonical B2C install/OAuth profile that this phase consumes.
- `scripts/ci/passkeys-opt-out-smoke.sh` — authoritative fresh-host lifecycle that establishes the generated B2C host.

### Browser and accessibility patterns
- `test/example/priv/playwright/playwright.config.ts` — serial, zero-retry generated-host browser execution configuration.
- `test/example/priv/playwright/tests/golden-path.spec.ts` — generated-host journey and LiveView readiness pattern.
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — scoped Axe and role-selector pattern.
- `test/example/priv/playwright/fixtures/mailbox.ts` — deterministic development-mailbox fixture.

### Generated auth and OAuth seams
- `priv/templates/sigra.install/core/registration_live.ex`
- `priv/templates/sigra.install/core/confirmation_controller.ex`
- `priv/templates/sigra.install/core/session_controller.ex`
- `priv/templates/sigra.install/core/reset_password_live.ex`
- `priv/templates/sigra.install/core/reset_password_controller.ex`
- `priv/templates/sigra.gen.oauth/oauth_controller.ex` — generated Google request/callback boundary.
- `lib/sigra/oauth/strategies/google.ex` — Google strategy configuration.
- `test/sigra/oauth/callback_test.exs` — existing-email collision semantics.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 237’s smoke already creates and boots the required fresh canonical B2C host with Google OAuth generated after installation.
- The Playwright mailbox fixture and golden-path journey show how to obtain deterministic confirmation/reset links from a generated host.
- Existing generated-host tests already scope Axe to `main.sigra-auth` and use role-oriented locators.

### Established Patterns
- Browser execution is serial with zero retries, so tests must synchronize on observable LiveView/browser readiness rather than elapsed time.
- Generated auth templates own the rendered forms and controller transitions; browser evidence must exercise those artifacts directly.
- OAuth collision behavior is an explicit domain outcome (`:link_confirmation_required`), not an implementation detail to bypass.

### Integration Points
- Extend the generated-host Playwright suite and its provisioning lifecycle, retaining Phase 237’s canonical installer and OAuth-generator order.
- The deterministic provider double must connect at the generated OAuth controller’s request/callback boundary.
</code_context>

<specifics>
## Specific Ideas

No additional product choices were introduced. The automated defaults preserve the B2C profile and use proof-first, no-secrets generated-host testing.
</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
- Passkey-primary duplicate-email and identifier work is out of scope because the canonical B2C profile disables passkeys.
- CSS parity, admin, CI-gate, release, and Crosswake-related matches remain in their owning phases; keyword matches did not justify expanding AUTH-01 through AUTH-03.

</deferred>

---

*Phase: 238-generated-auth-runtime-proof*
*Context gathered: 2026-08-05*
