# Phase 224 UI Specification

## Creative Direction

Quiet, warm, technically exact, and host-respectful. Generated auth should feel complete without pretending to be the adopter's product design system. Use a restrained warm canvas, one clear panel, ember only for primary/selected identity, and strong information hierarchy. The Sigra D4 mark is an implementation fallback when the host has not supplied a logo; host product identity stays first.

## Semantic Vocabulary

### Layout

- `sigra-auth-flow`: page-level content flow.
- `sigra-auth-stack` plus `--2`, `--3`, `--4`, `--6`: vertical rhythm.
- `sigra-auth-cluster` plus `--between`, `--center`: wrapping inline groups.
- `sigra-auth-section`: intentional bounded content region.
- `sigra-auth-divider`: labeled or unlabeled separation between auth methods.

### Actions

- `sigra-auth-action` is the common control shape.
- `sigra-auth-action--primary`, `--secondary`, `--ghost`, `--danger` encode hierarchy explicitly.
- A link remains an `<a>`/`<.link>` and a mutation remains a `<button>`/submit control.
- Every flow has at most one visually primary action at a time.

### Feedback and state

- `sigra-auth-notice` with `--info`, `--success`, `--warning`, `--danger`.
- `sigra-auth-status` for compact, decision-bearing state.
- `sigra-auth-empty` for no-data states.
- `sigra-auth-code` and `sigra-auth-code-list` for recovery/forensic values.
- `sigra-auth-disclosure` for optional methods or advanced detail.

## Interaction Contract

- Focus rings are visible at 3:1 or better and never depend on hover.
- Hover effects run only on hover-capable fine pointers; press feedback is subtle.
- Reduced-motion removes nonessential transitions. Forced colors preserve boundaries and selected state.
- Busy actions use `phx-disable-with` or native disabled state without changing layout.
- Live status updates use the least assertive suitable live region; static copy receives no live role.
- Confirmation and recovery inputs allow paste. OTP fields use `autocomplete="one-time-code"`; password fields use correct current/new password tokens.

## Representative Slice Acceptance

### Login

- Heading is “Sign in” and product identity is already visible in the shell.
- Configured primary method is first and visually primary.
- Alternative methods are grouped under a clear “Other ways to sign in” disclosure/divider.
- Recovery and registration links describe destinations; no auth implementation terms.

### Invitation mismatch

- Heading explains the invitation belongs to another email.
- Invited and current addresses are distinguishable without exposing backend identifiers.
- No accept form, button, `phx-click`, or `phx-submit` exists in this branch.
- The primary recovery action signs out/switches account; a safe destination remains available.

### Backup codes

- One-time nature and consequence are stated before the values.
- Codes are readable, selectable, and exposed as a semantic list.
- Copy and download are secondary actions; “I saved these” is the primary completion action.
- Clipboard failure never destroys access to selectable text.

### Audit active filters

- Presets are links/toggles that construct URLs, not duplicate named inputs.
- Manual filter controls are a single flat grid with one input per key.
- A labeled “Active filters” region follows the form immediately and contains removable applied chips plus Clear all.
- Filter, sort, page-size, cursor, return, export, and browser-history behavior retain GET semantics.

## Responsive and Theme Matrix

- 320 CSS px: one column, no clipped controls/code, horizontal values may wrap or scroll locally.
- 200% zoom: content reflows without two-dimensional page scrolling.
- Light/Dark/System: equivalent hierarchy and WCAG AA contrast; System tracks media changes.
- Long-content fixture: 200% labels, long email/product/org names, translated copy, and error messages do not overlap.

## Review Gates

1. Direction: representative slice communicates trustworthy, neutral generated auth and preserves ownership boundaries.
2. Coherence: propagated surfaces use the same vocabulary, action hierarchy, state copy, theme, and focus behavior.
3. Fresh adopter: a developer unfamiliar with internals can install, create access, authenticate, investigate, and revoke without guessing.
