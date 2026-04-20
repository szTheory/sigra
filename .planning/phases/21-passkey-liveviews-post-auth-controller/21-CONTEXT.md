# Phase 21: Passkey LiveViews + POST-Auth Controller - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 21 delivers the end-to-end passkey UX on top of the Phase 19 and Phase 20 seams: enrollment, management, MFA challenge usage, and opt-in passkey-primary login in the generated Phoenix app. This phase owns the user-facing LiveViews, the POST auth-completion controller path, recovery/failure UX, and the registration-notification email shape.

This phase does **not** redesign challenge storage, hook event contracts, runtime passkey config, or the lower-level credential verification primitives. Those are already locked by Phases 19 and 20 and must be consumed as-is.

</domain>

<decisions>
## Implementation Decisions

### Passkey management surface
- **D-01:** Passkey enrollment and management live on the existing MFA settings surface at `/users/settings/mfa`, not on the main account settings page and not on a new dedicated passkeys page. The page should gain a prominent passkeys card/section rather than a tiny inline subsection.
- **D-02:** `/users/settings` may include a lightweight teaser or deep link to `/users/settings/mfa#passkeys` for discoverability, but `MFASettingsLive` remains the canonical management destination.
- **D-03:** Enrollment and deletion are sensitive security operations and must stay behind a fresh sudo/reverification boundary. The management LiveView renders state and drives the JS hooks, but must not become the final session-mutating auth boundary.

### MFA challenge experience
- **D-04:** For users who have one or more passkeys, the MFA challenge becomes **passkey-first but not auto-triggered**. The primary action is an explicit `Continue with passkey` CTA.
- **D-05:** TOTP remains an immediate visible fallback via `Use authenticator code instead`; backup codes remain recovery-oriented and visually secondary via `Use a backup code`.
- **D-06:** If the user has no passkeys, or the browser/device cannot support the passkey path, the challenge degrades cleanly to the current TOTP-first experience without dead ends.
- **D-07:** Do not keep the current tab model as an equal-weight three-way chooser. Backup codes are recovery, not a peer primary method.

### Primary login experience
- **D-08:** When `:passkey_primary_enabled` is on, the login page stays controller-rendered and identifier-first: keep a single email field with `autocomplete="username webauthn"` and visually lead with passkey login.
- **D-09:** In passkey-primary mode, the page should present `Continue with passkey` as the primary CTA, while still exposing `Use password instead` and `Email me a magic link` as immediate fallback paths.
- **D-10:** Do not split the login UX into separate passkey and password entry screens. A chooser-first flow adds unnecessary state and fights conditional UI/autofill.
- **D-11:** Login/session completion remains a plain controller POST, never a LiveView event. LiveView/hooks can own ceremony UI state, but not the terminal session rotation step.

### Passkey list and device identity
- **D-12:** The enrolled-passkeys UI uses a compact card/list presentation. Each row/card label resolves in this order: `nickname`, then friendly AAGUID-derived provider/device name, then `device_hint`, then `"Passkey"`.
- **D-13:** Default secondary metadata is limited to `Added …` and `Last used …` (or `Never used`). Do not show raw AAGUIDs, credential IDs, transports, RP IDs, or inferred sync state by default.
- **D-14:** Rename is a lightweight inline row/card edit, not a separate page and not a full modal flow. Clearing the nickname should revert to the generated fallback label rather than leaving a blank name.
- **D-15:** Delete remains sudo-gated per PK-UX-04 and uses an inline secondary confirmation state after sudo is satisfied. The confirmation copy should strengthen when the credential is the last passkey or when deleting it changes the user’s primary-login fallback posture.

### Recovery and failure UX
- **D-16:** Passkey errors should use a compact guided-recovery model, not terse raw auth errors and not a heavy wizard. Every passkey failure state must leave the user with a clear next action.
- **D-17:** User-cancel and abort states are neutral, not red-alert failures. Recommended default copy shape: `Passkey sign-in was canceled.` with actions `Try again` and `Use another way`.
- **D-18:** Timeout, unsupported-browser/device, and lost-device states each get state-specific copy and fallback actions. Unsupported environments should be framed as environment limitations, not account problems.
- **D-19:** Passkey-primary flows must explicitly preserve magic-link recovery. In MFA flows, TOTP and backup codes remain visible recovery routes where applicable.
- **D-20:** Never surface raw browser exception strings such as `NotAllowedError` or `AbortError` directly to end users.

### Cross-cutting UX and architecture
- **D-21:** Phase 21 should optimize for passkey-as-MFA first, because passkey-primary is opt-in in v1.1. The default information architecture must not over-rotate toward a pure passwordless world.
- **D-22:** Conditional UI/autofill is progressive enhancement. Do not remove the first-screen identifier field and do not depend on autofill to make the flow understandable.
- **D-23:** Passkey enrollment, challenge, and login UX should feel like extensions of Sigra’s existing controller + LiveView auth model: controller for terminal auth mutation, LiveView for recoverable ceremony state, explicit fallback always visible.

### the agent's Discretion
- Exact component composition inside the passkeys card, provided the hierarchy above remains intact.
- Exact copy wording for success/error/helper text, provided the recovery posture and fallback clarity stay intact.
- Exact inline-vs-small-modal implementation for rename if the final interaction remains row-local and low ceremony.
- Exact relative-time formatting and iconography.
- Whether the discoverability link from `/users/settings` to `/users/settings/mfa#passkeys` ships in Phase 21 or is left to host-app customization.

</decisions>

<specifics>
## Specific Ideas

- MFA challenge for passkey-capable users:
  - Primary CTA: `Continue with passkey`
  - Secondary inline action: `Use authenticator code instead`
  - Recovery action: `Use a backup code`
- Passkey-primary login:
  - Keep the email field on the first screen
  - Primary CTA: `Continue with passkey`
  - Secondary actions: `Use password instead`, `Email me a magic link`
- Passkey row/card label order:
  - `nickname || friendly_aaguid_name || device_hint || "Passkey"`
- Error/recovery mapping:
  - `canceled` / `aborted`: neutral notice + retry / another way
  - `timeout`: warning + retry / another way
  - `unsupported`: info state + password/magic-link/another device
  - `lost device`: explicit recovery guidance pointing at magic link or other enrolled factors
- Do not auto-launch `navigator.credentials.get()` on mount. Make passkey the preferred visible action, not a surprise browser modal.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and locked decisions
- `.planning/ROADMAP.md` — Phase 21 goal, requirements, success criteria, and the controller/LiveView split that must remain intact.
- `.planning/PROJECT.md` — v1.1 milestone scope, passkey-as-MFA plus passkey-primary product posture, and Sigra’s hybrid lib+generator philosophy.
- `.planning/REQUIREMENTS.md` — PK-UX-01 through PK-UX-12; especially sudo-gated enrollment/delete, mandatory recovery, conditional UI, duplicate detection, and POST login completion.
- `.planning/STATE.md` — confirms Phase 21 is the active next phase after Phase 20.
- `.planning/phases/19-passkey-schema-contexts/19-CONTEXT.md` — locked passkey data-layer decisions including friendly-name inputs (`aaguid`, `nickname`, `device_hint`, `last_used_at`), cap behavior, and management API constraints.
- `.planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-CONTEXT.md` — locked challenge/session contract, hook event contract, and app.js/manual wiring posture that Phase 21 must build on.

### Existing generated UX and routing seams
- `priv/templates/sigra.install/core/mfa_settings_live.ex` — current MFA management surface that Phase 21 should extend rather than bypass.
- `priv/templates/sigra.install/core/mfa_challenge_live.ex` — current TOTP/backup-code challenge surface that Phase 21 should evolve into a passkey-first challenge for passkey-capable users.
- `priv/templates/sigra.install/core/settings_live.ex` — existing separation between account settings and security-factor settings.
- `priv/templates/sigra.install/core/session_controller.ex` — canonical controller-owned login/session creation boundary.
- `priv/templates/sigra.install/core/login_html.ex` — current controller-rendered login surface that Phase 21 should adapt for passkey-primary mode.
- `priv/templates/sigra.install/passkeys/passkey_hooks.js` — public hook objects and event names already locked by Phase 20.
- `priv/templates/sigra.install/passkeys/passkey_browser.js` — browser-side ceremony helper behavior and abort normalization.
- `lib/sigra/passkeys.ex` — passkey rename/delete/list/count behaviors and audit-backed mutation posture.
- `priv/templates/sigra.install/passkeys/user_passkey.ex` — generated schema fields available to the UI.
- `priv/templates/sigra.gen.oauth/oauth_settings_live.ex` — compact security-credential settings precedent for row/card density and destructive-action posture.
- `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` — stronger destructive-action precedent showing where typed-confirm belongs when the blast radius is materially larger.

### Verification and tests
- `test/sigra/install/generator_mfa_test.exs` — generated MFA route/template expectations that Phase 21 should extend coherently.
- `test/sigra/install/features/passkeys_js_test.exs` — locked passkey hook/runtime contract for generated apps.
- `test/sigra/passkeys_test.exs` — rename/delete/list expectations and audit-backed management semantics.
- `test/sigra/passkeys/authentication_test.exs` — passkey authentication and sign-count behaviors the UI must respect.
- `test/example/lib/example_web/controllers/session_controller.ex` — example app’s current controller login boundary.
- `test/example/lib/example_web/live/mfa_challenge_live.ex` — example app’s current challenge UX baseline.
- `test/example/lib/example_web/live/mfa_settings_live.ex` — example app’s current MFA settings baseline.

### External ecosystem guidance
- `https://passkeys.dev/docs/use-cases/bootstrapping/` — identifier-first passkey login and fallback posture.
- `https://passkeys.dev/docs/use-cases/reauth/` — passkey-first reauthentication patterns with explicit `another way` fallback.
- `https://web.dev/articles/passkey-form-autofill` — conditional UI/autofill guidance for identifier-first login pages.
- `https://web.dev/articles/passkey-management` — passkey management-page guidance, naming defaults, and metadata density.
- `https://simplewebauthn.dev/docs/advanced/passkeys/` — passkey-primary/discoverable-credential guidance relevant to Sigra’s opt-in primary mode.
- `https://simplewebauthn.dev/docs/packages/browser` — browser-side passkey error/abort behavior and why raw errors should not leak to users.
- `https://docs.github.com/en/authentication/authenticating-with-a-passkey/about-passkeys` — GitHub’s passkey posture as a successful mainstream auth product.
- `https://docs.github.com/en/authentication/authenticating-with-a-passkey/managing-your-passkeys` — passkey management and destructive-action precedent.
- `https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/configuring-two-factor-authentication` — security-settings grouping precedent.
- `https://auth0.com/docs/authenticate/database-connections/passkeys` — passkey-first but fallback-preserving product guidance.
- `https://docs.hanko.io/using-the-api/build-a-custom-login-page` — identifier-first passkey-led login precedent.
- `https://better-auth.com/docs/plugins/passkey` — coherent passkey feature-surface precedent in a modern auth library.
- `https://docs.allauth.org/en/dev/mfa/webauthn.html` — MFA-grouped WebAuthn precedent in a framework-auth library.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `priv/templates/sigra.install/core/mfa_settings_live.ex`: existing security-factor management page; natural home for the passkeys card and enrollment/manage actions.
- `priv/templates/sigra.install/core/mfa_challenge_live.ex`: existing challenge-state LiveView; can absorb a passkey-first CTA and fallback routing without changing the overall controller/LV boundary.
- `priv/templates/sigra.install/core/login_html.ex` + `session_controller.ex`: existing controller-rendered multi-method login surface; ideal place for identifier-first passkey-primary mode.
- `priv/templates/sigra.install/passkeys/passkey_hooks.js`: already exports `PasskeyRegister` and `PasskeyAuthenticate` hook objects with explicit success/error/aborted events.
- `lib/sigra/passkeys.ex`: already provides `list_for_user`, `count_for_user`, `rename`, and `delete` with audit semantics that the Phase 21 UI can call directly through the generated app context.
- `priv/templates/sigra.gen.oauth/oauth_settings_live.ex`: a compact generated credential-management pattern that is closer to passkeys than the heavier organization settings flows.

### Established Patterns
- Controller-owned terminal auth mutation: Sigra prefers plain controller POSTs for login/session-changing steps.
- LiveView owns recoverable UI state: MFA and settings surfaces already use LiveView for interactive state while leaving sensitive mutation boundaries explicit.
- Generated account settings are split by concern: `/users/settings` handles profile/account changes, `/users/settings/mfa` handles security-factor management.
- Destructive-action posture scales with blast radius: lightweight row-local confirmation for smaller actions, stronger confirmation for larger destructive operations.
- Progressive enhancement over hidden magic: Phase 20 locked conditional UI and hook-driven browser work as enhancements, not as the only understandable path.

### Integration Points
- Extend `MFASettingsLive` with a prominent passkeys card that can initiate enrollment, render the passkey list, and dispatch rename/delete actions.
- Evolve `MFAChallengeLive` from TOTP/backup tabs into a passkey-first challenge when passkeys are available, while preserving current TOTP/backup fallback logic.
- Adapt `login_html.ex` and `SessionController` for identifier-first passkey-primary mode, still finishing through a POST controller.
- Use the Phase 20 hook contract (`sigra:passkey-register:*`, `sigra:passkey-authenticate:*`) to drive LiveView state transitions and recovery messaging.
- Reuse existing relative-time, compact-card, and destructive-action copy patterns from sessions, OAuth settings, and organization settings.

</code_context>

<deferred>
## Deferred Ideas

- A dedicated passkeys management page or richer device-management console — defer unless passkey-primary becomes the dominant mode or Phase 21 materially outgrows `MFASettingsLive`.
- Rich admin/security-console metadata such as RP ID, transports, or raw device/debug fields — out of scope for the default generated user settings UX.
- Fully chooser-first auth flows that split passkey and password into distinct first-class routes/screens — rejected for v1.1.

</deferred>

---

*Phase: 21-passkey-liveviews-post-auth-controller*
*Context gathered: 2026-04-15*
