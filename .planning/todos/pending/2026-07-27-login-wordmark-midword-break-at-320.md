---
created: 2026-07-27T00:00:00.000Z
status: pending
title: Generated login brand row breaks the product name mid-word at 320px/200%
area: auth-ui
files:
  - priv/templates/sigra.install/core/login_html.ex
  - priv/templates/sigra.install/core/sigra_auth.css
source: 2026-07-27 Phase 229 PROOF-03 visual acceptance review
---

## What

In the 320px-wide / 200%-text-zoom capture of the generated login page, the app
name in the brand row hyphenates mid-token:

```
Sigra
Admi
nSm
oke
```

Captured at
`test/example/priv/playwright/test-results/css-specificity/admin-generated-generated--4f63b-ves-theme-and-reflow-states-admin-generated/auth-auth-login-system-dark-320-reflow-admin-generated.png`
(320 × 1718, dark, 200% text).

## Why it was NOT fixed during v1.46

Deliberate accept, not an oversight:

1. **The string is a test fixture, not a product name.** "SigraAdminSmoke" is the
   app name the acceptance harness generates (`phx.new sigra_admin_smoke`). It is
   a 15-character single token with no natural break opportunity. A realistic
   adopter app name ("Acme", "Tasklane", "Northwind Books") either fits or breaks
   at a space.
2. **The gate it might have failed already passes.** WCAG reflow containment is
   green — nothing scrolls horizontally, everything stays reachable, and the
   200%-zoom + 320px contract is enforced in CI. This is purely how rough the
   composition is allowed to look at the extreme, not a functional or a11y defect.
3. **Scope discipline.** The v1.46 PROOF-03 remediation was scoped to exactly the
   duplicate-`Email`-label finding (quick task `260727-v15`).

## What would need deciding first

Before touching anything, answer: **should a single-token app name of arbitrary
length be forced to break at 320px, or should it be allowed to overflow its own
line?** The current behaviour is the former (an ancestor is permitting
`word-break`/`overflow-wrap: anywhere` on the brand row). Both are defensible;
picking one is a design call, not a bug fix.

If the answer is "let realistic names break naturally and stop breaking
unnatural ones", the change is to constrain the brand row to
`overflow-wrap: break-word` semantics (break only when there is no other option,
at the last resort) rather than anywhere-breaking — and to verify with a
multi-word app name fixture as well as the current single-token one.

## Related

- Quick task `260727-v15` — the duplicate-`Email`-label finding from the same review.
- Two findings from the same review were cleared with evidence and need no work:
  the ember box around the "Other ways to sign in" disclosure is the
  `:focus-visible` ring (`sigra_auth.css:765`, resting rule at `:239` declares no
  border), and the action hierarchy renders correctly post-CSS-specificity-correction
  (primary takes the accent fill; the superseded 17:49 capture set showed otherwise).
