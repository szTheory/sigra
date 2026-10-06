# Phase 246: Generated Confirmation Recovery - Context

**Gathered:** 2026-10-06 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the generated Phoenix confirmation journey reliable and understandable in a freshly generated host. An account owner can confirm through the email link while anonymous or already signed in, can paste the code as it appears in the generated email, and receives visible success or invalid-code feedback. Preserve the account-binding and single-use properties of confirmation credentials.

This phase is limited to SEED-011 findings A, B, and D: the unreachable confirmation route, spaced-code paste failure, and invisible LiveView feedback. Findings C, E, F, and G; broad generated-auth browser/accessibility coverage; and release preparation remain outside this phase. Phase 245 historical evidence gaps remain closed out of this scope.

</domain>

<decisions>
## Implementation Decisions

### Confirmation routes and token behavior
- **D-01:** Preserve the locked CONF-01 behavior: an anonymous visitor and a signed-in visitor can complete email-link confirmation in the same generated confirmation experience. The link token identifies the account being confirmed. Opening the link only loads a confirmation page; an explicit, keyboard-operable submit performs the state change. This reduces scanner and prefetch side effects while keeping the anonymous path.
- **D-02:** Confirmation must not create a session, sign a visitor in as the token's account, or switch an existing session. If the visitor is signed in, their existing session remains unchanged. Keep the email-link token single-use and bound to its account.
- **D-03:** Code entry and resend operate only for the signed-in account represented by the current request scope. Anonymous visitors must receive clear sign-in guidance and a working link; missing scope must never crash the LiveView. Never accept a target account ID from submitted form data.

### Code paste and account binding
- **D-04:** Accept the confirmation code exactly as displayed in the generated email, including intervening spaces. Browser constraints must not truncate the pasted value or replace Sigra's translated validation with a locale-dependent native error. Normalize permitted whitespace on the server, then require exactly six ASCII digits before attempting verification.
- **D-05:** Confirmation-code verification must match the token to the current account before changing account state. Preserve per-account rate limiting and prove that a valid code for account A cannot confirm account B. The current library verifier accepts a user ID for rate limiting but its token lookup omits that ID; generated code must not be considered secure or complete until the lookup and a cross-account regression case enforce account binding.
- **D-06:** Residual security boundary: anonymous email-link confirmation is an explicit Phase 246 contract. An explicit submit avoids automatic confirmation on scanner GETs and no session change avoids turning the link into a login credential, but this flow alone does not prevent account pre-hijacking when an attacker registers using someone else's email. Do not claim that it does. Preventing that threat would require revisiting the locked anonymous-confirmation contract and is not an unreviewed implementation choice.

### Feedback and accessibility
- **D-07:** Render LiveView confirmation feedback in the shared generated auth page so success and invalid-code messages are visible on the generated screens. Use the existing neutral sigra-auth component and CSS vocabulary; do not introduce a new visual system or expose backend details. Success updates should be announced as a status; validation errors should be announced as an alert/live-region message without forcing focus away from the form. Keep copy localized and allow retry after an invalid code.

### Automated evidence
- **D-08:** Prove the behavior at distinct seams: focused LiveView/integration tests for both link-confirmation session states, persisted confirmed_at changes, anonymous code/resend handling, and cross-account code rejection; template contract assertions for feedback semantics; and one real-browser path in a freshly generated host for actual spaced-code paste and visible success/error feedback.
- **D-09:** Put the generated-host proof on the recurring required CI path for changes to generated auth. Reuse the existing install-smoke and Playwright infrastructure where practical, keep the browser path narrow to avoid duplicating the whole LiveView matrix, and preserve failure output that identifies the failed path. All acceptance evidence is automated; no human UAT is needed. Browser automation should use stable accessible selectors and deterministic readiness, without sleeps.

### the agent's Discretion
The planner may choose the smallest route grouping and helper structure consistent with these decisions, the exact whitespace normalization implementation, focused test names/fixtures, and the existing CI job that should own the generated-host browser check. Prefer existing Phoenix, ExUnit, and Playwright patterns; do not add a new framework or broad generated-auth coverage.

### Folded Todos
- **Generated confirmation route cannot confirm in EITHER session state** — folded from .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md, already marked resolves_phase: 246. Its route/session diagnosis, requirement to assert persisted state rather than response status, and account-scoped code invariant belong directly to CONF-01 and CONF-02.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements and operating decisions
- .planning/ROADMAP.md §Phase 246 — phase goal, boundaries, and success criteria.
- .planning/REQUIREMENTS.md §CONF-01–CONF-03 — locked acceptance contract.
- .planning/PROJECT.md — Sigra's auth-library purpose, current v1.49 scope, and generated-host quality goals.
- .planning/METHODOLOGY.md — automation-first verification, decisive defaults, escalation threshold, and user-experience bias.

### Findings and prior generated-auth decisions
- .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md — route/session defect and account-scoped code invariant; folded into this phase.
- .planning/seeds/SEED-011-generated-auth-email-and-confirmation-defects.md — A/B/D scope and why C/E/F/G remain deferred.
- .planning/todos/pending/2026-07-28-w3-generated-auth-runtime-coverage-is-login-only.md — broader coverage gap; this phase supplies only the confirmation-journey slice.
- .planning/milestones/v1.46-phases/226-auth-entry-recovery/226-CONTEXT.md — generated auth is a host-owned starting point using the sigra-auth-* vocabulary.

### Project prompts and domain guidance
- prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md §P0-4 — confirmation user flow, user intent, and security expectations.
- prompts/Auth Domain Language — A Field Guide.md — confirmation tokens, account identity, and conn versus LiveView socket boundaries.
- prompts/phoenix-live-view-best-practices-deep-research.md — LiveView form and presentation conventions.
- prompts/phoenix-best-practices-deep-research.md — Phoenix context and generated-code conventions.
- prompts/elixir-best-practices-deep-research.md — idiomatic Elixir implementation guidance.

### External primary sources considered
- [Phoenix LiveView security model](https://phoenix-live-view.hexdocs.pm/security-model.html) and [Phoenix authentication generator](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Gen.Auth.html) — LiveView mount and authorization boundaries; the generated sign-in behavior is not copied where it conflicts with Sigra's no-session-change contract.
- [Phoenix LiveViewTest](https://phoenix-live-view.hexdocs.pm/1.2.11/Phoenix.LiveViewTest.html) — server-rendered LiveView integration evidence.
- [RFC 9110 safe methods](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.1), [Microsoft Safe Links](https://learn.microsoft.com/en-us/defender-office-365/safe-links-about), and [django-allauth confirmation flow](https://github.com/pennersr/django-allauth/blob/main/allauth/templates/account/email_confirm.html) — explicit confirmation avoids using a scanner-prone GET as the state-changing action.
- [WHATWG input standard](https://html.spec.whatwg.org/dev/input.html), [MDN maxlength](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/maxlength), and [LiveView bindings](https://phoenix-live-view.hexdocs.pm/bindings.html) — browser constraints and server-side event validation.
- [WCAG 2.2 status messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html) — accessible announcements for success and validation feedback.
- [Devise confirmation implementation](https://github.com/heartcombo/devise/blob/main/lib/devise/models/confirmable.rb) and [USENIX account pre-hijacking research](https://www.usenix.org/system/files/sec22-sudhodanan.pdf) — account-bound confirmation without session switching and the residual risk that anonymous confirmation does not itself prevent pre-hijacking.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- priv/templates/sigra.install/core/sigra_auth_components.ex defines the shared sigra_auth_page; it is the single generated presentation seam for confirmation flashes.
- priv/templates/sigra.install/core/sigra_auth.css already has success/danger status styles, including sigra-auth-status--success and sigra-auth-status--danger.
- priv/templates/sigra.install/core/user_auth.ex has a current-scope mount hook that can represent an anonymous visitor without a scope.
- scripts/ci/install-smoke.sh creates a fresh Phoenix host, installs Sigra, compiles it, migrates its database, and runs a generated-host test probe.

### Established Patterns
- lib/sigra/install/features/core.ex currently injects LiveView confirmation routes into a scope using redirect_if_user_is_authenticated; confirmation routes need a path that supports an optional current scope.
- priv/templates/sigra.install/core/confirmation_live.ex already emits success and error flashes, has token and code flows, and uses a text input with numeric autofill hints. Its six-character maxlength and native digit pattern reject the spaced email value before LiveView receives it.
- priv/templates/sigra.install/core/emails.ex creates the spaced six-digit code and also applies CSS letter spacing. Keep the displayed/copyable value and input contract aligned.
- priv/templates/sigra.install/core/auth.ex passes the current user ID to the code verifier. lib/sigra/auth.ex currently uses that ID for rate limiting but omits it from the token lookup; the generated scoped query in priv/templates/sigra.install/core/user_token.ex is not used on that verification path.
- test/sigra/install/generator_email_test.exs, test/sigra/install/generator_wiring_test.exs, and test/sigra/install/features/core_test.exs provide fast generator/template coverage, but source assertions alone cannot prove route behavior, persisted state, or browser paste.
- The current install-smoke probe is fresh-host integration coverage, not a confirmation browser test. A narrow browser flow is needed to prove real paste and visible feedback.

### Integration Points
- Generated routes: lib/sigra/install/features/core.ex.
- Generated confirmation behavior and forms: priv/templates/sigra.install/core/confirmation_live.ex.
- Shared generated feedback: priv/templates/sigra.install/core/sigra_auth_components.ex and priv/templates/sigra.install/core/sigra_auth.css.
- Generated email/code: priv/templates/sigra.install/core/emails.ex.
- Library code verifier and user binding: lib/sigra/auth.ex, priv/templates/sigra.install/core/auth.ex, and priv/templates/sigra.install/core/user_token.ex.
- Generated-host and browser verification: scripts/ci/install-smoke.sh, existing test/example/priv/playwright tooling, and the CI workflow that runs the install smoke.

</code_context>

<specifics>
## Specific Ideas

The primary user is a newly registered account owner who receives a generated confirmation email, opens its link or copies its code, and needs an unambiguous result. Keep the flow low-friction: the link leads to a clear confirmation action; code paste succeeds as displayed; an anonymous visitor who tries code entry or resend is told to sign in instead of encountering a server error; success and invalid-code feedback are visible and announced accessibly.

Prior-art research found that Phoenix's generated confirmation flow couples confirmation to sign-in, which is incompatible with the locked Sigra contract; Devise and django-allauth offer useful examples of token-bound confirmation without copying their whole flow. The explicit submit is a security/UX choice within the same journey, not a new feature.

Known risk for planning and release review: the accepted anonymous-link contract still permits a pre-stuffed account to become email-confirmed when the email owner follows the link. The recommended GET-then-explicit-submit behavior reduces scanner-triggered state changes, but it does not eliminate pre-hijacking. Do not claim otherwise; any change to require credential proof before confirmation must reopen the phase contract.

</specifics>

<deferred>
## Deferred Ideas

- SEED-011 C (wide transactional-email rendering), E (error modifier vocabulary), F (spent-link messaging), and G (Apple Mail styling) remain separate findings.
- Broad generated-auth runtime and axe coverage remains in AUTHUI-01 and the W-3 follow-up; Phase 246 adds only confirmation-journey evidence.
- Preventing account pre-hijacking would require changing the locked anonymous-confirmation contract and needs a separate product/security decision if the project chooses to take that on.

</deferred>

---

*Phase: 246-Generated Confirmation Recovery*
*Context gathered: 2026-10-06*
