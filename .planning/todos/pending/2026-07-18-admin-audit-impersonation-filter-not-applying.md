---
created: 2026-07-18T00:00:00.000Z
status: pending
title: Admin audit "Impersonation" action_prefix filter chip does not apply (duplicate action_prefix query param)
area: admin-ui
files:
  - lib/sigra/admin/live/audit_live.ex
  - lib/sigra/admin/components.ex
source: 2026-07-18 Jon spotted the chip on /admin/audit not filtering; flagged during the demo-DX polish burst
---

## What

The `sg-filter-chip` "Impersonation" checkbox on `/admin/audit` appears not to filter:

```html
<label class="sg-filter-chip">
  <input type="checkbox" name="action_prefix" value="admin.impersonation" class="checkbox checkbox-sm">
  <span>Impersonation</span>
</label>
```

Reproduced URL:
`/admin/audit?action_prefix=admin.impersonation&actor=&effective_user=&action_prefix=&outcome=&from=&to=&page_size=25&order_by=inserted_at&order_direction=desc`

## Prime suspect

`action_prefix` appears **TWICE** in the query string — once with the chip's value
(`action_prefix=admin.impersonation`) and once **empty** (`action_prefix=`). With duplicate
params, the LAST one typically wins in Plug/Phoenix param parsing, so the empty value
clobbers the real one → the filter resolves to "no prefix" and nothing is filtered.

Likely cause: the filter form renders BOTH a dedicated hidden/blank `action_prefix` field
(the general prefix text filter) AND the checkbox chip that also uses `name="action_prefix"`,
so the form submits two `action_prefix` entries. They collide.

## Where to look

- `lib/sigra/admin/live/audit_live.ex` — the filter form + `handle_event`/`handle_params`
  that reads `action_prefix`; confirm how params are decoded (single vs list) and whether the
  chip and the prefix text-input share the `action_prefix` name.
- `lib/sigra/admin/components.ex` — the `sg-filter-chip` markup + the audit filter form
  assembly (does it emit a blank `action_prefix` alongside the chip?).

## Fix direction (to confirm)

Give the impersonation chip a **distinct** param name (e.g. a boolean `impersonation_only` or a
separate `action_prefix_chip`) OR make the chip and the text prefix filter share ONE source of
truth so only a single `action_prefix` is ever submitted. Add a regression test that a checked
chip produces a URL/params with exactly one effective `action_prefix=admin.impersonation` and
that the audit query actually narrows to impersonation rows.

## Scope

Lib-owned admin surface (`lib/sigra/admin/**`) — so the fix ships to adopters; add coverage in
the admin audit LiveView tests. Not example-only. Check whether any Playwright audit baseline
captures the filtered state.
