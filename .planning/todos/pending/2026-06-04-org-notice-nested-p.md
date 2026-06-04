---
created: 2026-06-04T00:00:00.000Z
status: pending
title: organization_live notice call passes block <p> children into notice's <p> wrapper (nested <p>)
area: lib/sigra/admin/live
files:
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/components.ex
source: 156-REVIEW.md (WR-01, organization_live portion)
---

## Finding (Phase 156 code review, WR-01)

`Sigra.Admin.Components.notice/1` wraps its `inner_block` slot in a single
`<p class="sg-text-sm">`:

```heex
<div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
  <p class="sg-text-sm">{render_slot(@inner_block)}</p>
</div>
```

The Phase 156 migration (Plan 156-02) converted the organization_live "Risk queue"
alert row to `<.notice>` but kept a two-block `sg-meta-label` / `sg-meta-value`
structure as the slot body:

```heex
<.notice tone={...}>
  <p class="sg-meta-label">Risk queue</p>
  <p class="sg-meta-value">{locked_summary(...)} in this organization</p>
</.notice>
```

This renders `<p class="sg-text-sm"><p class="sg-meta-label">…</p><p class="sg-meta-value">…</p></p>`
— block `<p>` elements nested inside another `<p>`, which is invalid HTML. Browsers
auto-close the outer `<p>`, so the live DOM diverges from the server-rendered string
(a LiveView patch-desync hazard) and the intended `sg-text-sm` wrapper styling is dropped.

## Why deferred (not fixed in-phase)

The user_show_live.ex sibling of this finding was a single-text body and was fixed
cleanly in Phase 156 (`ad506c2c`) by removing the redundant `<p>`. The
organization_live case is **not a clean drop**: the `sg-meta-label` / `sg-meta-value`
pair is a two-line block structure that does not map onto notice's single inline
`<p>` slot. A correct fix requires a visual/product decision (collapse to one inline
message, switch the meta pair to inline `<span>`s, or extend `notice/1` to accept
block content), and `organization_live` is **not** one of the 5 Playwright-baselined
checkpoint screens — so there is no existing visual gate to verify the chosen render
against. Per the fix-clean-ones / defer-uncertain remediation rule, this was logged
rather than guess-fixed.

## Suggested resolution

Pick one:
1. Collapse the alert to a single inline message: `<.notice tone={...}>Risk queue — {locked_summary(...)} in this organization</.notice>` (simplest; drops the label/value split — confirm acceptable visually).
2. Use inline `<span>`s with appropriate classes inside the notice slot (verify `sg-meta-label`/`sg-meta-value` read acceptably as inline).
3. Add a block-content variant to `notice/1` (heavier; affects the component contract + golden test).

Then add a baseline/visual check for the organization landing screen if one is wanted,
and confirm the rendered HTML is valid (no nested `<p>`).
