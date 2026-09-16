---
created: 2026-07-18T00:00:00.000Z
status: resolved
resolved: 2026-09-15
resolved_by: phase-236-04
title: Admin audit "Impersonation" action_prefix filter chip does not apply (duplicate action_prefix query param)
area: admin-ui
files:

  - lib/sigra/admin/live/audit_live.ex
  - lib/sigra/admin/components.ex

source: 2026-07-18 Jon spotted the chip on /admin/audit not filtering; flagged during the demo-DX polish burst
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
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

## Resolution (2026-09-15, Phase 236 plan 04)

**Closed as resolved-by-verification — the duplicate-`action_prefix` checkbox chip this todo
describes no longer exists on `/admin/audit`.**

- The file this todo names, `lib/sigra/admin/live/audit_live.ex`, does not exist. The real module
  (Phase 236's `236-CONTEXT.md` D-07) is `lib/sigra/admin/live/audit_index_live.ex`. Verified:
  `grep -c sg-filter-chip lib/sigra/admin/live/audit_index_live.ex lib/sigra/admin/components.ex`
  → both `0`. The checkbox-chip-with-`name="action_prefix"` shape this todo describes is not
  present on the audit surface at all — the presets are now single-param `<a href>`/`<.link
  patch>` links (`Failures`, `Impersonation`, etc.), each carrying exactly one `action_prefix`
  value, not a checkbox that could collide with a separate text-prefix field. `sg-filter-chip`
  survives repo-wide only at `lib/sigra/admin/live/users_index_live.ex:352` (the unrelated
  `quick_filter` component), confirmed via
  `grep -rn sg-filter-chip lib/sigra/admin/`.
- **The very test that was flaking is this bug's regression test.**
  `test/example/priv/playwright/tests/admin-generated.spec.ts:444-445` asserts
  `page.locator('[name="outcome"]')` and `page.locator('[name="action_prefix"]')` each
  `toHaveCount(1)` — i.e. exactly one node named `action_prefix` on the page, which is
  incompatible with the duplicate-param shape this todo reports. That assertion was added in
  commit `40240903` (v1.46), predating Phase 236's own work.
- Phase 236 (plans 01-04) reproduced, diagnosed, and fixed an unrelated race on this same test
  (`admin-generated.spec.ts:459`, a LiveView `unload()`/native-GET teardown race, not a duplicate
  query param), confirming in the process that the impersonation preset link renders and applies
  correctly under both the pre-fix and post-fix code paths — the `actor=` filter application it
  exercises is downstream of the same preset-link mechanism this todo's chip concern is about.
