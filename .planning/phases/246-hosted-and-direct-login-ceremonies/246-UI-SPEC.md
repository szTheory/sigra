---
phase: 246
slug: hosted-and-direct-login-ceremonies
status: approved
shadcn_initialized: false
preset: none
created: 2026-08-12
reviewed_at: 2026-08-12
---

# Phase 246 — Hosted and Direct Login Ceremonies UI Design Contract

> Visual and interaction contract for the generated hosted-browser approval screen. Direct password and MFA ceremonies are intentionally JSON protocol endpoints, not browser UI.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none — Phoenix HEEx generated auth surface, not a React project; shadcn gate not applicable |
| Preset | not applicable |
| Component library | existing generated `SigraAuthComponents` and `sigra-auth-*` cascade-layer/BEM vocabulary |
| Icon library | none; do not add decorative or status icons |
| Font | system sans: `ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif` |

Use the existing `sigra_auth_page`, `header`, and `sigra_auth_button` components. The approval template must use `sigra-auth-*` only; do not add admin `sg-*` components, Tailwind, a new CSS layer, or a third-party component library. Source: 246-08 plan and generated auth CSS.

The shared auth shell owns Light, Dark, and System behavior through `data-theme`; preserve all three modes and the existing reduced-motion clamp. Use the Rail Accent/auth token consumer (`--sigra-auth-light-accent`, brandbook ember-700) rather than a hard-coded brand color or logo recreation.

---

## Spacing Scale

Declared values (multiples of 4 only):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline visual adjustment only; no new page layout gap |
| sm | 8px | Compact control and inline copy separation |
| md | 16px | Decision section padding and default content gap |
| lg | 24px | Header-to-decision and stacked-control separation |
| xl | 32px | Small-viewport page padding when the responsive auth shell resolves to this value |
| 2xl | 48px | Wide-viewport auth-shell page padding |
| 3xl | 64px | Not used by this compact single-decision screen; reserved page-scale token |

Exceptions: native button minimum target height is 44px (`2.75rem`) for both actions. The existing auth panel remains constrained to 34rem and the flow to 28rem; do not introduce nested cards.

---

## Typography

Use exactly these four sizes and exactly these two weights for new approval-surface decisions; existing shared shell styles remain canonical.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body / explanatory copy | 16px | 450 | 1.5 |
| Button label | 14px | 700 | 1.2 |
| Decision heading (`h2`) | 24px | 700 | 1.2 |
| Page title (`h1`) | 32px maximum, fluid down to 25px | 700 | 1.12 |

Profile names are static host configuration but may be long: render them as text only and preserve the auth-shell `overflow-wrap: anywhere`; never replace, concatenate, or expose the callback URI, state, code, verifier, password, challenge, user identifier, or app-session credential in visible copy.

---

## Color

All values use the existing `sigra-auth-*` token layer, which is downstream of `brandbook/tokens.*`.

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | Light `--sigra-auth-bg` (`#f7f4ee` fallback); dark `#171614` | Viewport background and quiet surrounding space |
| Secondary (30%) | Light `--sigra-auth-surface` (`#ffffff`); dark `#211f1c` | Centered auth panel and bordered decision section |
| Accent (10%) | `--sigra-auth-accent` (light fallback `#c2410c`; dark text-on-soft uses `#fdba74`) | Primary approve button, focused link/control treatment, and Rail Accent identity only |
| Destructive | `--sigra-auth-risk` (light `#b42318`; dark `#f8a39c`) | Error/flash treatment only; never cancellation or primary action |

Accent reserved for: the “Approve and continue” button, focus ring, existing auth-shell brand mark/identity, and selected auth controls. “Decline app sign-in” is an outlined/secondary full-width action using the existing `sigra-auth-action--secondary` treatment; declining is an explicit denial, not a destructive-account action.

---

## Visual Hierarchy

The primary screen focal point is the signed-in app decision. Read the centered auth panel in this fixed order: page title (`Continue to {static profile name}`) establishes orientation; `Approve app sign-in` is the decision anchor; the one-sentence explanation establishes the consequence; `Approve and continue` is the sole accent primary action; and `Decline app sign-in` follows as the visually quieter secondary action. Do not add competing cards, status illustrations, badges, or other calls to action.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Page title | `Continue to {static profile name}` |
| Page subtitle | `Review this request before continuing to the app.` |
| Decision heading | `Approve app sign-in` |
| Decision explanation | `This will continue your signed-in browser session to {static profile name}.` |
| Primary CTA | `Approve and continue` |
| Secondary CTA | `Decline app sign-in` |
| Empty state heading | Not applicable — this is a single signed continuation decision, not a collection or data view. Missing, expired, or tampered continuation is an invalid request, not an empty state. |
| Empty state body | Not applicable; do not expose profile/callback or authentication facts. |
| Error state | `Invalid app login request.` Return HTTP 400 with no profile, account, callback, code, state, PKCE, MFA, or policy detail. The client must start a new hosted attempt. |
| Destructive confirmation | None. Decline app sign-in immediately consumes the bounded continuation and returns to normal sign-in; no modal, typed confirmation, or extra confirmation page. |

Direct endpoint contract: `browser_required` is the sole policy-specific JSON response. All other direct password/MFA failures return `invalid_credentials`; neither response has a rendered browser page or user-facing account/profile explanation.

---

## Interaction and Accessibility Contract

- Render the approval surface only after a valid signed continuation exists and the browser user is authenticated. An unauthenticated start redirects through the normal browser login/MFA branches and resumes at this page only; it never redirects to the callback or issues credentials before approval.
- Use a semantic `h1` page title and an `h2` inside `<section aria-labelledby="app-login-decision-title">`. Do not use ARIA roles to simulate buttons or headings.
- Provide two separate CSRF-protected `POST` forms. Submit controls retain native button semantics and visible labels. Keep stable hooks: `app-login-approval`, `app-login-decision-controls`, `app-login-approve`, and `app-login-decline`.
- On approve, submit once, consume the continuation, and redirect only to the exact registered callback with the opaque code and original state. Set `Referrer-Policy: no-referrer`. No visual success screen, flash, code, callback, or credential display is allowed.
- On decline, submit once, consume the continuation, and return to the bounded normal sign-in route. Do not present a confirmation dialog, callback redirect, credential, or account-specific explanation.
- Native navigation is the loading treatment. Do not add a spinner, skeleton, optimistic success, countdown, or LiveView loading animation; the state change must remain explicit and server-authoritative. Focus follows the browser navigation destination.
- Preserve native focus-visible styling and the existing 44px targets. Pointer hover may use existing color/transform transition only; honor `prefers-reduced-motion` and never use `transition: all`.

---

## UI Considerations

Applicable state considerations resolved: 8 covered, 0 backstop, 0 unresolved.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| empty | E1 — Approval decision form | ✅ covered | An invalid or missing continuation does not render an empty decision; it returns the generic HTTP 400 invalid-request response without leaked facts. |
| loading | E1 — Approval decision form | ✅ covered | Native POST/redirect navigation is the only in-flight treatment. No progress animation is permitted because the server must atomically consume and issue before redirecting. |
| error | E1 — Approval decision form | ✅ covered | Malformed, expired, tampered, or consumed state produces `Invalid app login request.` with HTTP 400 and no sensitive context. |
| partial | E1 — Approval decision form | ✅ covered | The form renders only after complete continuation validation and never exposes partially populated callback, state, PKCE, credential, or account data. |
| long-text | E1 — Approval decision form | ✅ covered | Long static profile names wrap within the constrained auth panel. |
| long-text | E2 — Approve and decline controls | ✅ covered | Fixed action labels remain fully visible and wrap safely within full-width buttons. |
| overflow | E3 — Static page content | ✅ covered | The title and explanatory copy wrap and reflow within the panel without clipping or horizontal scrolling. |
| long-text | E3 — Static page content | ✅ covered | Profile names use `overflow-wrap: anywhere`; headings and copy reflow without truncation. |

Direct JSON response bodies are protocol data, not UI elements. The explicit probe classifications are E1 `form` + `interactive-control`, E2 `interactive-control`, and E3 `static-content`; list, collection, media, and navigation element kinds are not present.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable — no React/shadcn initialization |
| third-party | none | not applicable — no third-party registry or block declared |

---

## Deterministic Verification Contract

- Rendered-template tests assert the declared heading order, the explicit `Approve and continue` and `Decline app sign-in` action labels, and stable `data-testid` hooks; use roles and these hooks, not broad text-only selectors.
- Browser automation waits for normal HTTP/LiveView readiness and asserts the approve/decline POST destinations; do not use sleeps.
- Exercise Light, Dark, and System auth-shell modes, including visible focus and no broken Rail Accent asset references.
- Assert that rendered approval markup contains no `sg-` admin classes and that response/HTML sources do not contain raw code, verifier, state, callback, password, challenge, or app credentials beyond the callback redirect protocol boundary.

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved — 2026-08-12
