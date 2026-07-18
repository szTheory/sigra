---
id: SEED-009
status: open
planted: 2026-07-18
planted_during: "quick task 260718-qxg — home front-door polish (Jon's live click-through of /admin/audit)"
trigger_when: The admin/operator-UI coherence milestone reaches the audit surface (or any admin filter-heavy surface — user search, session review, org views), or an evaluator reports 'I can't tell which filters are applied.'
scope: Small–Medium
---

# SEED-009: Admin audit (and filter-heavy admin surfaces) — active-filter visibility

## Problem

On the admin **Audit** page (e.g.
`/admin/audit?outcome=failure&action_prefix=admin.impersonation&actor=&effective_user=&action_prefix=&outcome=&from=&to=&page_size=25&order_by=inserted_at&order_direction=desc`),
after clicking **Apply filters** it is **not obvious which filters are currently
active**. The filter inputs are mostly tucked behind a **"More filters"**
dropdown/expander, so once applied+collapsed there is no at-a-glance summary of
the applied state — the user has to re-open the expander and read each control.

Jon (live, 2026-07-18): "it's not clear after you hit Apply filters which filters
are being applied … maybe because most of them are progressively shown with the
'More filters' dropdown/expander … make this more obvious."

Note the URL above also shows **duplicate/empty query params** (`action_prefix`
and `outcome` appear twice — once populated, once empty), which suggests the
filter form emits every control including blanks. Worth auditing the query-param
serialization as part of this (empty filters shouldn't be echoed).

## Proposed direction (design, not yet decided)

- **Active-filter pills**: render a row of removable pills summarizing the applied
  filters (e.g. `outcome: failure ✕`, `action: admin.impersonation ✕`), each with
  an `✕` that clears just that one filter (re-applies the rest). This is the
  standard, scannable convention for faceted filtering.
- Must fit the **Sigra admin design system**: use the `sg-*` cascade-layer / BEM
  tokens and Rail Accent brand — a new `sg-filter-pill` (or reuse an existing
  chip/badge primitive if one exists) rather than the demo-app `vt-*` layer.
  Follow `guides/reference/admin-ui-principles.md` + `admin-design-contract.md`
  and support Light/Dark/System.
- **Possibly retire "More filters"**: Jon — "maybe we just get rid of 'More
  filters' for now b/c right now it's basically all of the controls anyways lol."
  If the expander hides ~all controls it adds a click without real progressive
  disclosure. Evaluate flattening the filter bar (show the common filters inline;
  keep the pill summary as the applied-state affordance) vs. keeping the expander
  but adding the pill summary above it.
- Only clear filters that are actually set should render as pills; the pill row is
  the "what's applied" truth, independent of whether the control panel is
  expanded/collapsed.

## Where this lives

- Admin Audit LiveView + its filter component (lib-owned admin surface, `sg-*`
  design system). Find via the `/admin/audit` route + the audit filter
  form/expander component. The active-filter-pill pattern would likely generalize
  to other filter-heavy admin surfaces (user search, session review, scoped org
  views) — design it as a reusable admin primitive.
- Keep browser tests deterministic (admin Playwright baselines / snapshot canary
  guard) if the audit surface has visual coverage.

## Why deferred

Raised mid-flow during unrelated demo front-door polish; Jon explicitly did not
want to get sidetracked. Belongs in the admin/operator-UI coherence milestone
where the audit surface gets deliberate iteration, alongside the other
under-iterated admin overviews. Related: [[project_sigra_admin_coherence_milestone]],
[[project_next_milestone_admin_ui]].
