# Phase 21: Passkey LiveViews + POST-Auth Controller - Discussion Log

**Date:** 2026-04-15
**Mode:** Research-backed recommendation pass
**Status:** Closed with locked recommendations

## Prompt Shape

The user asked for a one-shot recommendation set rather than an interview-style decision flow:

- research the tradeoffs deeply
- use subagents
- compare ecosystem precedents
- emphasize idiomatic Phoenix/Plug/Ecto/LiveView library design
- optimize for coherence, least surprise, strong UX, and strong DX

## Areas Resolved

### 1. Account settings surface

**Question**
- Should passkey enrollment and management live inside the existing MFA page, inside the main settings page, or on a separate passkeys page?

**Options considered**
- Prominent passkeys section inside `MFASettingsLive`
- Passkeys block on main account settings
- Separate passkeys page/LiveView

**Locked recommendation**
- Keep passkeys on `/users/settings/mfa` as a first-class passkeys card/section.
- Do not create a separate page in v1.1.
- Optionally add a discoverability deep link from `/users/settings`.

**Why**
- Least surprising with the current generated app structure.
- Keeps TOTP, backup codes, and passkeys in one security-factor management surface.
- Lowest route/generator churn while still giving passkeys enough UI weight.

### 2. MFA challenge experience

**Question**
- Should MFA challenge be passkey-first, TOTP-first, or a neutral chooser when passkeys are available?

**Options considered**
- Passkey-first with explicit fallback
- TOTP-first
- Neutral choose-a-method layout

**Locked recommendation**
- Make the MFA challenge passkey-first for users with passkeys, but never auto-trigger the browser prompt on mount.
- Keep TOTP and backup code fallbacks immediately visible.

**Why**
- Best balance of security, UX speed, and recovery clarity.
- Strong fit with Phase 20’s hook contract and the existing controller/LV split.
- Avoids over-elevating backup codes into a peer everyday auth path.

### 3. Primary login experience

**Question**
- In passkey-primary mode, should the login page stay identifier-first, become a chooser screen, or remain subtle progressive enhancement only?

**Options considered**
- Subtle enhancement on the normal form
- Explicit passkey-vs-password chooser
- Identifier-first, passkey-led login

**Locked recommendation**
- Keep `/users/log_in` controller-rendered and identifier-first.
- In passkey-primary mode, visually lead with passkeys while preserving password and magic-link fallback on the same screen.

**Why**
- Preserves conditional UI/autofill on the identifier field.
- Fits the current POST controller session-creation contract.
- Avoids the complexity and friction of a chooser-first design.

### 4. Passkey list and device identity

**Question**
- How much metadata should the UI show, and how should rename/delete work?

**Options considered**
- Compact list with minimal metadata
- Rich device cards with debug-heavy details
- Heavier delete/rename ceremony

**Locked recommendation**
- Use a compact list/card format.
- Label order: `nickname || friendly AAGUID name || device_hint || "Passkey"`.
- Show only `Added …` and `Last used …` by default.
- Rename inline; delete with sudo + inline confirm.

**Why**
- Best match for generated-app ergonomics and account-settings density.
- Uses the existing stored fields without inventing fragile UI claims.
- Avoids exposing low-signal or misleading technical metadata.

### 5. Recovery and failure messaging

**Question**
- Should passkey failure states use terse generic errors, state-specific guided messages, or a more elaborate recovery flow?

**Options considered**
- Terse auth-style errors
- Compact guided state-specific messaging
- Multi-step recovery-heavy flow

**Locked recommendation**
- Use compact state-specific recovery messaging with immediate fallback actions.
- Treat cancel/abort as neutral interruptions, not severe failures.
- Always keep the user on a recoverable path.

**Why**
- Strongest fit for Sigra’s “rough edges matter” product posture.
- Avoids dead ends and raw browser error leakage.
- Preserves the controller/LV split while keeping ceremony state recoverable in-place.

## Cohesion Notes

The five recommendations were chosen to work together as one system:

- Passkeys are managed where other security factors already live.
- MFA challenge leads with passkeys, but only with clear fallback.
- Passkey-primary login stays on the existing controller-owned login page.
- The passkey list stays compact and explainable.
- Failure states always point toward recovery instead of trapping the user.

This produces a coherent Sigra posture:

- passkey-as-MFA first by default
- passkey-primary as opt-in
- controller for terminal auth mutation
- LiveView for recoverable ceremony state
- progressive enhancement, not hidden magic

## External Precedents Considered

- `passkeys.dev`
- `web.dev`
- `SimpleWebAuthn`
- GitHub passkeys and 2FA settings flows
- Auth0 passkeys
- Hanko custom login guidance
- Better Auth passkey plugin
- Django Allauth MFA/WebAuthn
- Laravel Fortify 2FA
- 1Password security-key management

## Result

These recommendations were written into `21-CONTEXT.md` as locked implementation guidance for downstream planning.
