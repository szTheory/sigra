# Phase 21: Passkey LiveViews + POST-Auth Controller - Research

**Researched:** 2026-04-15
**Domain:** Phoenix LiveView passkey UX, WebAuthn browser flows, and controller-owned session finalization
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- A dedicated passkeys management page or richer device-management console — defer unless passkey-primary becomes the dominant mode or Phase 21 materially outgrows `MFASettingsLive`.
- Rich admin/security-console metadata such as RP ID, transports, or raw device/debug fields — out of scope for the default generated user settings UX.
- Fully chooser-first auth flows that split passkey and password into distinct first-class routes/screens — rejected for v1.1.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PK-UX-01 | Sudo-gated enrollment from account settings | `RequireSudo` at the plug/router edge plus passkeys card in `MFASettingsLive` |
| PK-UX-02 | Registration email notification | Reuse suspicious-login-shaped email content and delivery path after successful registration |
| PK-UX-03 | Friendly names + nickname defaults | Bundled AAGUID registry with nickname > AAGUID name > device hint > `"Passkey"` fallback |
| PK-UX-04 | Rename/delete + soft cap | Inline rename, sudo-gated delete, library cap still enforced in `Sigra.Passkeys.register/4` |
| PK-UX-05 | Passkey as MFA second factor | Passkey-first explicit CTA in `MFAChallengeLive`, TOTP and backup code still visible |
| PK-UX-06 | Config-gated passkey-primary login | Identifier-first controller login page with passkey CTA and same POST completion boundary |
| PK-UX-07 | Mandatory recovery for passkey-primary | Magic-link recovery remains always available and cannot be hidden when primary mode is enabled |
| PK-UX-08 | Conditional UI / autofill | Feature-detect conditional mediation, keep explicit click fallback, keep identifier field |
| PK-UX-09 | Duplicate-device enrollment returns friendly error | Preserve `excludeCredentials` on registration and translate duplicate insert failure into non-500 UX |
| PK-UX-10 | Use JS hooks, not hand-rolled plumbing | Build on `PasskeyRegister` / `PasskeyAuthenticate` hook contract from Phase 20 |
| PK-UX-11 | Auth completion via plain controller POST | POST browser response to controller that renews the Plug session and delegates to `UserAuth.log_in_user/3` |
| PK-UX-12 | Clean abort/timeout/cancel handling | Hook lifecycle cancellation plus LiveView recovery-state mapping for aborted/error outcomes |
</phase_requirements>

## Summary

Phase 21 should stay on Sigra's existing split: LiveView owns recoverable passkey ceremony state and controller POST owns the final authenticated session mutation. That is already the project pattern in the generated login flow and is reinforced by Plug's documented session-renew semantics. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/plug/Plug.Conn.html]

The planning center of gravity is not WebAuthn cryptography anymore. Phase 19 and Phase 20 already locked the credential model, challenge storage, hook event contract, and abort teardown seam. Phase 21 is mainly an edge-integration phase: route topology, sudo placement, LiveView state machines, controller completion, email side effects, and test coverage across Phoenix controller, LiveView, and Playwright layers. [VERIFIED: codebase grep]

The safest prescriptive stance is: keep enrollment and management in `MFASettingsLive`, keep login identifier-first, never auto-launch passkey modals on mount, always preserve a visible fallback, and always land passkey success in a plain controller POST that renews the Plug session before redirect. That aligns with passkeys.dev bootstrapping and reauthentication guidance, LiveView hook lifecycle rules, and Sigra's existing `SessionController` plus `UserAuth.log_in_user/3` boundary. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://passkeys.dev/docs/use-cases/reauth/] [CITED: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html] [VERIFIED: codebase grep]

**Primary recommendation:** Build three user-facing seams only: a sudo-protected passkeys card in `MFASettingsLive`, a passkey-first explicit CTA flow in `MFAChallengeLive`, and a controller-rendered identifier-first login page whose passkey success always POSTs into a session-rotating controller. [VERIFIED: codebase grep] [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://passkeys.dev/docs/use-cases/reauth/]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sudo gate for enrollment/delete | API / Backend | Frontend Server (SSR) | `Sigra.Plug.RequireSudo` already enforces freshness from `conn.private[:sigra_session]`; the UI should only reflect gate state, not enforce it. [VERIFIED: codebase grep] |
| Passkey enrollment ceremony UI | Browser / Client | Frontend Server (SSR) | Browser owns WebAuthn prompts via hooks; LiveView supplies options and receives normalized outcomes. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html] |
| Passkey authentication ceremony UI | Browser / Client | Frontend Server (SSR) | `navigator.credentials.get()` and conditional mediation are browser capabilities; the server only prepares options and verifies responses. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://simplewebauthn.dev/docs/packages/browser] |
| Final login/session completion | Frontend Server (SSR) | API / Backend | Plug session renewal and redirect happen in controller code, matching `SessionController` and `UserAuth.log_in_user/3`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Passkey list/rename/delete data access | API / Backend | Database / Storage | `Sigra.Passkeys` already owns list/count/rename/delete and audit-backed mutation semantics. [VERIFIED: codebase grep] |
| Friendly device/provider naming | API / Backend | — | Label resolution should happen server-side from stored `nickname`, `aaguid`, and `device_hint` so HEEx stays dumb and deterministic. [VERIFIED: codebase grep] [CITED: https://web.dev/articles/passkey-management] |
| Duplicate credential prevention | API / Backend | Database / Storage | W3C `excludeCredentials` reduces duplicate registration attempts; the DB unique constraint remains the authoritative last line of defense. [CITED: https://www.w3.org/TR/webauthn-3/] [VERIFIED: codebase grep] |
| Recovery fallback selection | Frontend Server (SSR) | API / Backend | The server decides which fallbacks are available per user/config; the UI must keep them visible and actionable. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://passkeys.dev/docs/use-cases/reauth/] |

## Project Constraints (from CLAUDE.md)

- Phoenix 1.8+ and Ecto 3.x are the blessed path; recommendations in this phase must stay Phoenix-native. [VERIFIED: CLAUDE.md]
- Core auth actions such as login/logout should remain plain HTTP POST boundaries, not LiveView events. [VERIFIED: CLAUDE.md]
- Security-sensitive code belongs in the library; generated app files should wire library behavior into routes, controllers, LiveViews, and templates. [VERIFIED: CLAUDE.md]
- Testing must cover happy path, main error cases, and boundary conditions. [VERIFIED: CLAUDE.md]
- Local `mix test` requires a live Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md]
- Use `mix precommit` when execution work is done. [VERIFIED: test/example/AGENTS.md]
- In Phoenix templates, use `<.input>` where practical, unique DOM IDs, HEEx list-form class attributes, and `cond`/`case` instead of `else if`. [VERIFIED: test/example/AGENTS.md]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix` | `1.8.5` (published 2026-03-05) [VERIFIED: hex.pm API] | Controller, router, session, and generated app boundary | Phase 21 depends on controller-rendered login and POST completion; the repo already targets `~> 1.8`. [VERIFIED: hex.pm API] [VERIFIED: codebase grep] |
| `phoenix_live_view` | `1.1.28` (published 2026-03-27) [VERIFIED: hex.pm API] | `MFASettingsLive` and `MFAChallengeLive` state orchestration | Hook lifecycle callbacks `mounted`/`destroyed`/`disconnected` are the correct boundary for passkey ceremony start and teardown. [VERIFIED: hex.pm API] [CITED: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html] |
| `wax_` | `0.7.0` (published 2025-05-18) [VERIFIED: hex.pm API] | Server-side WebAuthn verification | The repo already locked this in Phase 19 for registration/authentication primitives. [VERIFIED: hex.pm API] [VERIFIED: codebase grep] |
| `@simplewebauthn/browser` | `13.3.0` (published 2026-03-10) [VERIFIED: npm registry] | Browser WebAuthn ceremony helper | Official docs cover `useBrowserAutofill`, abort service, and normalized browser errors; do not hand-roll browser API plumbing for Phase 21. [VERIFIED: npm registry] [CITED: https://simplewebauthn.dev/docs/packages/browser] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `passkey-authenticator-aaguids` snapshot | GitHub repo, no package version [VERIFIED: GitHub repo] | Friendly provider/device names from AAGUID | Vendor a pinned JSON snapshot for UI naming only; never treat it as authoritative device security metadata. [CITED: https://github.com/passkeydeveloper/passkey-authenticator-aaguids] |
| `Plug.Conn` session API | Plug docs current [CITED: hexdocs] | Session renewal, clearing, and POST completion behavior | Use for final login completion controller only. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| `@playwright/test` | `1.59.1` available locally via `npx` [VERIFIED: local command] | Browser-level passkey and autofill verification | Use for hook runtime and example-app end-to-end passkey flows. [VERIFIED: local command] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@simplewebauthn/browser` | Raw `navigator.credentials.*` calls | Worse error normalization, more base64url plumbing, and more browser-specific edge cases to own. [CITED: https://simplewebauthn.dev/docs/packages/browser] |
| Controller POST session completion | LiveView event or `push_navigate` completion | Breaks Sigra's existing session-rotation boundary and increases session fixation/regression risk. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Vendored AAGUID registry snapshot | Hard-coded local label map | High maintenance burden and immediate drift as providers expand. [CITED: https://github.com/passkeydeveloper/passkey-authenticator-aaguids] |

**Installation:**
```bash
mix deps.get
npm view @simplewebauthn/browser version
cd test/example/priv/playwright && npm install
```

**Version verification:** Current versions were verified on 2026-04-15 via `hex.pm` package APIs for `phoenix`, `phoenix_live_view`, and `wax_`, and via `npm view @simplewebauthn/browser version time --json` for the browser helper. [VERIFIED: hex.pm API] [VERIFIED: npm registry]

## Architecture Patterns

### System Architecture Diagram
```text
Browser CTA / Conditional UI
  -> LiveView or controller requests auth/registration options
  -> Phase 20 hook (`PasskeyRegister` / `PasskeyAuthenticate`) starts browser ceremony
  -> Hook pushes one of: success | error | aborted
  -> LiveView maps outcome to recoverable UI state
  -> On success, browser POSTs response to plain controller endpoint
  -> Controller verifies with Sigra passkey context
  -> Controller renews Plug session / deletes mfa_pending / redirects
  -> Side effects: audit event, suspicious-login-shaped email, updated passkey list
```

### Recommended Project Structure
```text
priv/templates/sigra.install/
├── core/
│   ├── session_controller.ex      # controller-owned login/session completion
│   ├── login_html.ex              # identifier-first controller login UI
│   ├── mfa_challenge_live.ex      # passkey-first MFA challenge UI
│   └── mfa_settings_live.ex       # passkeys management card
└── passkeys/
    ├── passkey_hooks.js           # Phase 20 hook seam
    ├── passkey_browser.js         # browser helper / abort normalization
    └── user_passkey.ex            # host schema fields exposed to UI
```

### Pattern 1: Controller-Owned Auth Finalization
**What:** Verify passkey success outside the LiveView event loop, then rotate the Plug session in a plain controller. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
**When to use:** Any passkey flow that changes the authenticated session or transitions from `:mfa_pending` to a full session. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: https://hexdocs.pm/plug/Plug.Conn.html
# Pattern adapted to Sigra's existing UserAuth boundary
def complete_passkey(conn, %{"response" => response_params}) do
  with {:ok, user} <- Auth.verify_passkey_login(response_params) do
    conn
    |> put_flash(:info, "Welcome back!")
    |> UserAuth.log_in_user(user)
  else
    {:error, _reason} ->
      conn
      |> put_flash(:error, "Passkey sign-in could not be completed.")
      |> redirect(to: ~p"/users/log_in")
  end
end
```

### Pattern 2: Explicit CTA, Never Surprise-Launch
**What:** Show a passkey-primary action button, but do not auto-open a browser WebAuthn prompt on LiveView mount. [CITED: https://passkeys.dev/docs/use-cases/reauth/] [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks]
**When to use:** MFA challenge and explicit account reauthentication. [CITED: https://passkeys.dev/docs/use-cases/reauth/]
**Example:**
```heex
<button
  id="passkey-mfa-continue"
  type="button"
  phx-click="begin_passkey"
  class={["btn", "btn-primary", "w-full"]}
>
  Continue with passkey
</button>

<button type="button" phx-click="show_totp" class={["btn", "btn-ghost", "w-full"]}>
  Use authenticator code instead
</button>
```

### Pattern 3: Conditional UI as Progressive Enhancement
**What:** Keep the identifier field and explicit button, but also boot a conditional mediation request when the browser supports it. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://simplewebauthn.dev/docs/packages/browser]
**When to use:** Controller-rendered login page when `:passkey_primary_enabled` is on. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/]
**Example:**
```javascript
// Source: https://passkeys.dev/docs/use-cases/bootstrapping/
// Source: https://simplewebauthn.dev/docs/packages/browser
if (
  window.PublicKeyCredential &&
  typeof PublicKeyCredential.isConditionalMediationAvailable === 'function' &&
  await PublicKeyCredential.isConditionalMediationAvailable()
) {
  startAuthentication({ optionsJSON, useBrowserAutofill: true })
}
```

### Pattern 4: Hook Teardown Cancels Pending Ceremonies
**What:** Cancel WebAuthn when a LiveView hook is destroyed or disconnected, and map aborts into neutral retry UI. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html] [CITED: https://simplewebauthn.dev/docs/packages/browser]
**When to use:** Enrollment, MFA challenge, and conditional UI login hooks. [VERIFIED: codebase grep]
**Example:**
```javascript
// Source: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html
// Source: https://simplewebauthn.dev/docs/packages/browser
destroyed() {
  WebAuthnAbortService.cancelCeremony()
  this.pushEvent("sigra:passkey-authenticate:aborted", { reason: "destroyed" })
}

disconnected() {
  WebAuthnAbortService.cancelCeremony()
  this.pushEvent("sigra:passkey-authenticate:aborted", { reason: "disconnected" })
}
```

### Anti-Patterns to Avoid
- **LiveView event performs final login:** It bypasses the repo's established controller session-rotation seam and makes fixation regressions easier to reintroduce. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
- **Auto-trigger passkey modal on mount for MFA:** passkeys.dev reauth guidance is explicit-button-first, and Safari still has user-gesture quirks around WebAuthn initiation. [CITED: https://passkeys.dev/docs/use-cases/reauth/] [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks]
- **Raw browser exception strings in flash/UI:** users should get mapped recovery states, not `NotAllowedError`/`AbortError` dumps. [CITED: https://simplewebauthn.dev/docs/packages/browser]
- **Delete without fallback warning:** the last passkey or a passkey-primary account needs explicit recovery guidance before destructive confirmation. [CITED: https://web.dev/articles/passkey-management] [CITED: https://docs.github.com/en/authentication/authenticating-with-a-passkey/managing-your-passkeys]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser WebAuthn response plumbing | Custom base64url encode/decode and ad hoc error mapping | `@simplewebauthn/browser` or the existing generated Phase 20 helper | The library already handles autofill, abort service, and typed browser errors. [CITED: https://simplewebauthn.dev/docs/packages/browser] [VERIFIED: codebase grep] |
| Hook lifecycle state machine | New bespoke JS event contract | Existing `PasskeyRegister` / `PasskeyAuthenticate` hooks | Phase 20 already locked success/error/aborted semantics and teardown behavior. [VERIFIED: codebase grep] |
| Friendly passkey provider map | Hand-maintained local AAGUID switch statement | Vendored `passkey-authenticator-aaguids` snapshot | The community list is built for RP management UIs and already models provider names/icons. [CITED: https://github.com/passkeydeveloper/passkey-authenticator-aaguids] |
| Duplicate registration detection | JS-only "do I already have this device?" heuristics | `excludeCredentials` plus DB unique constraint remap | W3C explicitly defines `excludeCredentials`/`InvalidStateError`, but server uniqueness still has to be authoritative. [CITED: https://www.w3.org/TR/webauthn-3/] [VERIFIED: codebase grep] |
| Session rotation after passkey success | Manual piecemeal `put_session` updates inside LV | Existing `UserAuth.log_in_user/3` flow behind a controller POST | Plug renewal is already encapsulated and battle-tested in the repo. [VERIFIED: codebase grep] |

**Key insight:** Phase 21 should compose the code that already exists instead of inventing another auth protocol layer. Nearly every risky failure mode in this phase is an integration failure at the controller/hook/LiveView boundary, not a missing primitive. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Stolen-session enrollment takeover
**What goes wrong:** A hijacked authenticated session can enroll an attacker-controlled passkey if enrollment is reachable without fresh reauthentication. [VERIFIED: codebase grep]
**Why it happens:** UI-only gating or stale session checks are weaker than a plug-enforced sudo freshness check. [VERIFIED: codebase grep]
**How to avoid:** Put `RequireSudo` on every enrollment and delete entrypoint, not just on a button or LiveView branch. [VERIFIED: codebase grep]
**Warning signs:** Enrollment routes are under ordinary `:require_authenticated` only, or tests never assert stale-sudo rejection. [VERIFIED: codebase grep]

### Pitfall 2: Lost-device lockout in passkey-primary mode
**What goes wrong:** Users can enable passkey-primary but end up with no recoverable way back into the account after losing the device. [CITED: https://web.dev/articles/passkey-management] [CITED: https://docs.github.com/en/authentication/authenticating-with-a-passkey/managing-your-passkeys]
**Why it happens:** Teams optimize for passwordless success paths and hide fallback methods too aggressively. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/]
**How to avoid:** Make magic-link recovery mandatory and visible for passkey-primary accounts, and strengthen copy before deleting the last passkey. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://web.dev/articles/passkey-management]
**Warning signs:** Login page has no visible secondary recovery action, or deletion flow ignores "last passkey" context. [CITED: https://web.dev/articles/passkey-management]

### Pitfall 3: JS abort or timeout leaves the LiveView corrupted
**What goes wrong:** The browser prompt is canceled or the hook is destroyed, but the LiveView remains in a loading or half-started state. [VERIFIED: codebase grep]
**Why it happens:** Hook teardown is incomplete, or abort outcomes are treated as fatal errors instead of neutral recoverable state. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html]
**How to avoid:** Cancel on `destroyed` and `disconnected`, normalize aborts, and map them to `Try again` / `Use another way`. [VERIFIED: codebase grep] [CITED: https://simplewebauthn.dev/docs/packages/browser]
**Warning signs:** Duplicate modal launches, stuck spinners, or repeated "already in progress" browser errors after navigation. [CITED: https://simplewebauthn.dev/docs/packages/browser]

### Pitfall 4: Duplicate-device registration 500s
**What goes wrong:** Re-registering the same authenticator surfaces an exception or generic 500. [CITED: https://www.w3.org/TR/webauthn-3/] [VERIFIED: codebase grep]
**Why it happens:** The client omits `excludeCredentials` and the server fails to translate unique-constraint collisions into a user message. [CITED: https://www.w3.org/TR/webauthn-3/] [VERIFIED: codebase grep]
**How to avoid:** Keep `excludeCredentials` populated from existing credentials and translate `InvalidStateError` or unique-constraint failure into `"This passkey is already registered."` [CITED: https://www.w3.org/TR/webauthn-3/] [CITED: https://simplewebauthn.dev/docs/packages/browser]
**Warning signs:** Registration tests only cover first-time success and never cover an already-registered credential. [VERIFIED: codebase grep]

### Pitfall 5: Safari/user-gesture regressions
**What goes wrong:** Passkey enrollment or authentication fails in Safari because async work broke the user gesture chain. [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks]
**Why it happens:** The browser call is delayed behind extra promises, wrappers, or surprise mount-time automation. [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks]
**How to avoid:** Use an explicit CTA for modal flows and keep the ceremony launch close to the click-triggered fetch. [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks] [CITED: https://passkeys.dev/docs/use-cases/reauth/]
**Warning signs:** Flow works in Chromium but flakes in Safari or iOS. [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks]

## Code Examples

Verified patterns from official sources:

### Identifier-First Conditional UI
```javascript
// Source: https://passkeys.dev/docs/use-cases/bootstrapping/
if (
  typeof window.PublicKeyCredential !== "undefined" &&
  typeof window.PublicKeyCredential.isConditionalMediationAvailable === "function" &&
  await PublicKeyCredential.isConditionalMediationAvailable()
) {
  const response = await navigator.credentials.get({
    mediation: "conditional",
    publicKey: {
      ...authOptions,
      userVerification: "preferred",
    },
  })
}
```

### Reauthentication with Explicit Passkey CTA
```javascript
// Source: https://passkeys.dev/docs/use-cases/reauth/
await navigator.credentials.get({
  publicKey: {
    challenge,
    rpId,
    allowCredentials: credentialIds,
    userVerification: "preferred",
  },
})
```

### Session Renewal on Successful Completion
```elixir
# Source: https://hexdocs.pm/plug/Plug.Conn.html
conn
|> configure_session(renew: true)
|> clear_session()
|> put_session(:user_token, token)
```

### Abort-Aware Browser Helper
```javascript
// Source: https://simplewebauthn.dev/docs/packages/browser
try {
  const response = await startAuthentication({ optionsJSON, useBrowserAutofill: true })
} catch (err) {
  if (err instanceof WebAuthnError && err.code === "ERROR_CEREMONY_ABORTED") {
    // neutral recovery path
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Raw `navigator.credentials` plumbing in app code | Use `@simplewebauthn/browser` helpers and its abort service | Current browser-helper guidance, documented in current package docs [CITED] | Less browser-specific edge handling in app code. [CITED: https://simplewebauthn.dev/docs/packages/browser] |
| Password-first or chooser-first login | Identifier-first login with conditional mediation and explicit passkey CTA | Current passkeys.dev bootstrapping guidance [CITED] | Better passkey discovery without hiding fallback auth. [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] |
| Single passkey expectation | Support multiple passkeys and explain last-passkey deletion risk | web.dev guidance published 2025-05-15 [CITED] | Reduces lockout risk and improves passkey management UX. [CITED: https://web.dev/articles/passkey-management] |
| Session mutation inside rich front-end flow | Controller POST completes auth and rotates session | Stable Plug/Phoenix security pattern [CITED] | Avoids fixation-prone or framework-coupled auth completion. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |

**Deprecated/outdated:**
- Auto-triggering modal passkey prompts on MFA page mount as the primary path is outdated for this phase's UX contract. [CITED: https://passkeys.dev/docs/use-cases/reauth/]
- Treating device/provider labels as raw credential metadata is outdated; current guidance is to show friendly names and compact timestamps. [CITED: https://web.dev/articles/passkey-management]
- Hand-rolled raw browser error strings in end-user UI are outdated when `@simplewebauthn/browser` already wraps errors with programmatic codes. [CITED: https://simplewebauthn.dev/docs/packages/browser]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Reusing the existing suspicious-login email template will be simpler than introducing a dedicated passkey-registration template. [ASSUMED] | Summary / Common patterns | Low-to-medium; planning may need one extra template task if current mailer shape is too rigid. |

## Open Questions

1. **Should passkey-primary success POST to the existing `SessionController` or a new passkey-specific controller action?**
   - What we know: Controller POST completion is mandatory and the existing login boundary already lives in `SessionController`. [VERIFIED: codebase grep]
   - What's unclear: Whether overloading the existing action would complicate current password/magic-link branching. [ASSUMED]
   - Recommendation: Plan a thin dedicated controller action under the same controller unless routing review shows the existing action stays cleaner. [ASSUMED]

2. **Where should the AAGUID registry snapshot live in the generated app/library split?**
   - What we know: The data is UI-facing naming data, not security metadata. [CITED: https://github.com/passkeydeveloper/passkey-authenticator-aaguids]
   - What's unclear: Whether Sigra wants that JSON in the library for reuse or emitted into the host app for easy customization. [ASSUMED]
   - Recommendation: Default to library-owned data with a narrow helper API so generated templates stay stable. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix/test execution | ✓ | `1.19.5` | — |
| Erlang/OTP | Elixir runtime | ✓ | `28` | — |
| Node.js | Playwright and browser helper verification | ✓ | `v22.14.0` | — |
| npm | `@simplewebauthn/browser` version verification and Playwright install | ✓ | `11.1.0` | — |
| PostgreSQL client/server | `mix test` for library and example app | ✓ | `psql 14.17`, `pg_isready` passing on `localhost:5432` | — |
| Docker | Disposable Postgres fallback from project docs | ✓ | `29.3.1` | Run local Postgres manually |
| Playwright | Browser verification | ✓ | `1.59.1` via `npx playwright --version` | Library-only tests if browser smoke is temporarily unavailable |

**Missing dependencies with no fallback:**
- None. [VERIFIED: local command]

**Missing dependencies with fallback:**
- None. [VERIFIED: local command]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit for library and example app, Playwright for browser smoke [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` [VERIFIED: codebase grep] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/require_sudo_test.exs test/sigra/plug/passkey_challenge_test.exs test/sigra/passkeys_test.exs test/sigra/passkeys/authentication_test.exs test/sigra/install/features/passkeys_js_test.exs` [VERIFIED: codebase grep] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && mix test) && (cd test/example/priv/playwright && npm test -- --grep passkeys)` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PK-UX-01, PK-UX-04 | Enrollment/delete are sudo-gated | integration | `cd test/example && mix test test/example/test/example_web/live/passkey_settings_live_test.exs -x` | ❌ Wave 0 |
| PK-UX-02, PK-UX-03, PK-UX-09 | Registration notification, friendly names, duplicate collision remap | integration | `cd test/example && mix test test/example/test/example_web/live/passkey_settings_live_test.exs -x` | ❌ Wave 0 |
| PK-UX-05, PK-UX-12 | MFA challenge passkey-first CTA with TOTP/backup fallback and abort recovery | LiveView + browser | `cd test/example && mix test test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs -x` and `cd test/example/priv/playwright && npm test -- --grep passkey` | ❌ Wave 0 / ✅ existing hook smoke |
| PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-11 | Identifier-first passkey-primary login with conditional UI and controller POST completion | controller + browser | `cd test/example && mix test test/example/test/example_web/controllers/passkey_session_controller_test.exs -x` and `cd test/example/priv/playwright && npm test -- --grep passkey` | ❌ Wave 0 / ✅ partial |
| PK-UX-10 | Generated hooks remain the blessed JS boundary | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs -x` | ✅ |

### Sampling Rate
- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys_test.exs test/sigra/passkeys/authentication_test.exs test/sigra/install/features/passkeys_js_test.exs`
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && mix test)`
- **Phase gate:** Add passkey-specific Playwright coverage, then run the full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/example/test/example_web/live/passkey_settings_live_test.exs` — settings-page enrollment/list/rename/delete/recovery copy
- [ ] `test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs` — passkey-first MFA challenge fallback matrix
- [ ] `test/example/test/example_web/controllers/passkey_session_controller_test.exs` — controller POST completion and session renewal
- [ ] `test/example/test/example_web/emails/passkey_registration_email_test.exs` or suspicious-login email extension test — registration email content
- [ ] Extend `test/example/priv/playwright/tests/passkeys-hooks.spec.ts` or add `passkeys-auth-flow.spec.ts` — end-to-end browser passkey UX

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `Sigra.Passkeys`, `Sigra.Auth`, controller POST completion [VERIFIED: codebase grep] |
| V3 Session Management | yes | Plug session renewal via `configure_session(renew: true)` and existing `UserAuth.log_in_user/3` pattern [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [VERIFIED: codebase grep] |
| V4 Access Control | yes | `Sigra.Plug.RequireSudo` on enrollment/delete endpoints [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Existing Sigra config validation and server-side response verification; do not trust browser error text or client-submitted ownership claims. [VERIFIED: codebase grep] [CITED: https://www.w3.org/TR/webauthn-3/] |
| V6 Cryptography | yes | `wax_`, Sigra token signing, Cloak-encrypted credential public key storage; never hand-roll cryptographic verification. [VERIFIED: codebase grep] [VERIFIED: hex.pm API] |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stolen authenticated session enrolls attacker passkey | Elevation of Privilege | `RequireSudo` before enrollment and delete, plus audit + user email on registration. [VERIFIED: codebase grep] |
| Session fixation or stale `mfa_pending` after passkey success | Elevation of Privilege | Controller POST completion that renews the session and clears pending state. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [VERIFIED: codebase grep] |
| Lost-device lockout | Denial of Service | Mandatory magic-link recovery for passkey-primary and visible alternative factors in MFA. [CITED: https://web.dev/articles/passkey-management] [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] |
| Duplicate credential collision causes 500 | Denial of Service | `excludeCredentials` plus server-side unique-constraint remap. [CITED: https://www.w3.org/TR/webauthn-3/] [VERIFIED: codebase grep] |
| Browser abort/disconnect corrupts LiveView state | Tampering / DoS | Hook teardown via `destroyed`/`disconnected` and neutral recovery copy. [CITED: https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html] [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)
- [Phoenix LiveView JS interop](https://hexdocs.pm/phoenix_live_view/1.1.1/js-interop.html) - hook lifecycle semantics
- [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) - session renewal and clearing semantics
- [passkeys.dev bootstrapping](https://passkeys.dev/docs/use-cases/bootstrapping/) - identifier-first login, conditional UI, enrollment after strong auth
- [passkeys.dev reauthentication](https://passkeys.dev/docs/use-cases/reauth/) - explicit passkey CTA and fallback posture for sensitive actions
- [SimpleWebAuthn browser docs](https://simplewebauthn.dev/docs/packages/browser) - `useBrowserAutofill`, abort service, wrapped errors
- [SimpleWebAuthn browser quirks](https://simplewebauthn.dev/docs/advanced/browser-quirks) - Safari user-gesture constraints
- [WebAuthn Level 3](https://www.w3.org/TR/webauthn-3/) - `excludeCredentials`, `InvalidStateError`, credential creation/authentication semantics
- [web.dev passkey management](https://web.dev/articles/passkey-management) - multiple passkeys, naming, timestamps, last-passkey deletion warnings
- [GitHub passkey management docs](https://docs.github.com/en/authentication/authenticating-with-a-passkey/managing-your-passkeys) - settings-based enrollment/removal and recovery posture
- [Hex package API: `phoenix`](https://hex.pm/api/packages/phoenix), [Hex package API: `phoenix_live_view`](https://hex.pm/api/packages/phoenix_live_view), [Hex package API: `wax_`](https://hex.pm/api/packages/wax_) - current versions and publish dates
- Local code inspection via `rg` / `sed` across `lib/`, `priv/templates/`, and `test/example/` - existing Sigra boundaries, routes, templates, and tests

### Secondary (MEDIUM confidence)
- [passkeydeveloper AAGUID registry](https://github.com/passkeydeveloper/passkey-authenticator-aaguids) - community provider naming data for RP management UIs

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions verified from `hex.pm` and npm registry; libraries already present in repo constraints. [VERIFIED: hex.pm API] [VERIFIED: npm registry] [VERIFIED: codebase grep]
- Architecture: HIGH - phase decisions align with existing router/controller/LiveView seams and official docs. [VERIFIED: codebase grep] [CITED: https://passkeys.dev/docs/use-cases/bootstrapping/] [CITED: https://passkeys.dev/docs/use-cases/reauth/]
- Pitfalls: HIGH - major risks map directly to documented WebAuthn behavior and Sigra's existing security boundaries. [CITED: https://www.w3.org/TR/webauthn-3/] [CITED: https://simplewebauthn.dev/docs/advanced/browser-quirks] [VERIFIED: codebase grep]

**Research date:** 2026-04-15
**Valid until:** 2026-05-15
