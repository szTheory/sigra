---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Admin lib reaches into sigra-auth-* classes, and sigra-auth-preview-form is dead
area: admin-ui
severity: low
audit_finding: W-7
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [EXPR-01]
files:
  - lib/sigra/admin/components.ex
  - priv/templates/sigra.install/core/sigra_auth.css
  - lib/sigra/admin/assets/sigra_admin.css
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

EXPR-01 fixes an ownership boundary between three CSS lanes: `sigra-auth-*` (generated
auth, host-owned), `sg-*` (admin, library-owned), `vt-*` (the Tasklane demo app). The audit
confirmed the boundary holds in the direction that matters — **zero** `sg-*` or `vt-*`
tokens appear anywhere in `priv/templates/sigra.install/{core,organizations}` or in
generated golden auth output.

One reverse touch exists: `lib/sigra/admin/components.ex:1032,1050,1063,1070,1075` uses
`sigra-auth-*` classes from inside the admin library. This is bounded to the
`/admin/branding` preview — the admin surface whose entire job is to show what generated
auth will look like — so it is defensible rather than a leak. Worth an explicit comment
saying so, since it otherwise reads as a violation to anyone grepping the boundary.

The genuine defect is smaller: **`sigra-auth-preview-form` (`components.ex:1050`) is
defined in neither `sigra_auth.css` nor `sigra_admin.css`.** It is a dead, unstyled class.

## Recommended fix

1. Delete `sigra-auth-preview-form`, or define it — whichever matches the intent. Check git
   history for whether it was renamed and the markup missed.
2. Add a short comment at the `components.ex` branding-preview block recording that the
   `sigra-auth-*` usage there is a deliberate, bounded exception to the EXPR-01 lane rule.
3. Consider a lint that asserts every class referenced in library markup resolves to a rule
   in one of the shipped stylesheets. That would have caught this, and it is the same class
   of silent drift as W-2.

Note the interaction with W-2: the branding preview currently renders using the **stale**
example `sigra_auth.css`. Fixing W-2 may change how this preview looks, so sequence W-2
first and re-check this block afterwards.

## Related

- W-2 in the same audit — the stale stylesheet this preview actually loads.
- `guides/reference/admin-design-contract.md` — the `sg-*` system this sits beside.
