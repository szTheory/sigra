# Phase 224 Context: Experience Contract + Representative Slice

## Outcome

Define and prove the generated-host experience contract before propagating it. The representative slice is the smallest set that exercises the milestone's ownership boundaries and hardest states: configured login hierarchy, invitation mismatch, saved backup codes, and an audit view with active filters.

## Jobs to Be Done

| Persona | Situation | Job | Success signal |
|---|---|---|---|
| First-time adopter | Sigra is installed in a fresh Phoenix host | Understand what the installer owns, create the first authorized operator safely, and reach `/admin` | No hidden privilege inference; every command explains the next step |
| Returning account holder | Needs to authenticate or recover access | See the configured best path first and understand alternatives without implementation jargon | One primary action; alternatives remain available and native browser affordances work |
| Invitee | Opens a valid, expired, replayed, or mismatched invitation | Understand whether they can join and what to do next | Only eligible branches expose acceptance controls; mismatch never exposes an accept action |
| Account holder improving security | Enables MFA or manages recovery credentials | Understand current posture, consequences, and the one-time nature of secrets | Backup-code save/acknowledge flow is explicit and keyboard/paste friendly |
| Support investigator | Narrows an audit timeline | Apply, share, inspect, and remove filters without silent query ambiguity | Exactly one value per filter key and active state is visible immediately after the form |

## Domain Language

- Nouns: account, authentication method, confirmation code, recovery code, passkey, session, invitation, platform-admin grant, audit event, filter preset.
- Events: account registered/confirmed, grant created/revoked, sign-in attempted, invitation accepted/denied, recovery codes regenerated, session revoked, filter applied.
- Verbs: create account, confirm, sign in, continue, save codes, revoke, grant access, inspect, filter, clear.
- Avoid provider-facing terms in UI copy: schema, context, policy callback, Ecto row, token envelope, LiveView, feature flag.

## Ownership Boundary

- Generated auth, recovery, account-security, and invitation acceptance: host-owned semantic `sigra-auth-*` markup and stable `--sigra-auth-*` tokens.
- Sigra admin: library-owned `sg-*` cascade-layer/BEM system and D4 Linked Rail brand assets.
- Tasklane example product: demo-owned `vt-*`; never copied into generated templates.
- Host organization settings, members, switcher, billing, and product onboarding remain visually host-owned. Invitation acceptance is in scope because it is part of the authentication boundary.

## Representative States

1. Login with configuration-derived primary method and progressively disclosed alternatives.
2. Invitation email mismatch with zero accept controls and an explicit account-switch path.
3. MFA recovery codes immediately after generation, including copy/download/save acknowledgement.
4. Global audit timeline with a preset and manual filter active, visible removable chips, and stable URL state.

## Constraints

- Light, Dark, and System modes; no global DaisyUI theme mutation.
- Native form, link, button, details/summary, and dialog semantics before ARIA.
- WCAG 2.2 AA contrast/reflow; visible focus; forced-colors and reduced-motion support.
- Password-manager, paste, OTP autofill, long-copy, error, pending, expired, and reconnect states remain usable.
- No second gallery or broad snapshot regime. Extend the generated-host acceptance and existing v1.44 review substrate with a thin manifest.
- Playwright uses role selectors or stable hooks, waits for LiveView readiness, and never sleeps.

## Decisions

- Brandbook v2/D4 is the visual authority. Rail imagery belongs to Sigra-owned identity/chrome, not every host-auth panel.
- Login priority follows runtime configuration: passkey is primary only when passkey-primary is enabled; otherwise magic link is primary. Password and enterprise SSO are alternatives.
- Semantic CSS is explicit. Styling every submit button as primary and styling generic `section` elements are retired compatibility patterns.
- Human review is bounded to direction, cross-surface coherence, and final fresh-adopter acceptance. Automated checks own deterministic semantics and regressions.

## Out of Scope

Wholesale admin redesign, organization product UI reskin, generic component library, automatic rewriting of customized adopter files, browser/first-user bootstrap, SCIM, runtime prefix/schema helpers, email-theme expansion, and CI sharding.
