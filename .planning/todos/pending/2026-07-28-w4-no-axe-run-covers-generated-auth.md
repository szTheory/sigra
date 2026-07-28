---
created: 2026-07-28T00:00:00.000Z
status: pending
title: No axe accessibility run touches any sigra-auth-* surface
area: auth-ui
severity: medium
audit_finding: W-4
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [AUTHUI-04, PROOF-03]
files:
  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

`AxeBuilder` appears in exactly three specs — `admin-checkpoints.spec.ts`,
`admin-design.spec.ts`, `admin-eval.spec.ts` — and all three cover `sg-*` **admin**
surfaces. `admin-generated.spec.ts`, the only spec that renders generated auth, does not
import it.

So Phase 227's claimed "post-interaction axe … pass" and the "post-interaction axe" line in
the 229-VERIFICATION evidence list **do not resolve to any committed spec covering a
`sigra-auth-*` surface**. The axe gate is real, but it is pointed at the admin lane.

To be precise about what this does and does not mean: the automated a11y checks that *did*
run on generated auth are the contract-level ones (native form semantics, label presence,
focus order, forced-colors, reduced-motion, reflow containment). What is missing is a
full axe ruleset sweep of the rendered generated auth DOM.

## Why it was NOT fixed during v1.46 close-out

Adding axe to the generated-host lane is only useful once there are surfaces to point it
at — which is W-3. Doing W-4 alone would sweep the single login page and imply far broader
coverage than it delivers.

## Recommended fix

Fold into W-3. Once each auth surface renders in the generated-host lane, add a post-
interaction axe pass per surface, matching how `admin-checkpoints.spec.ts` already does it
for admin (assert after interaction, not just on initial paint — that is where the admin
lane found real defects).

Then correct the evidence wording in the v1.46 verification record, or supersede it in the
follow-on milestone's verification, so the claim matches what actually runs.

## Related

- W-3 in the same audit — the prerequisite.
- PROOF-03 / AUTHUI-04 in `.planning/milestones/` v1.46 requirements.
