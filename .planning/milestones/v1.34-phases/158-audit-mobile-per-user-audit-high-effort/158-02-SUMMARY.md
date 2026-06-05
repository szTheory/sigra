---
phase: 158-audit-mobile-per-user-audit-high-effort
plan: "02"
subsystem: admin-audit-live
tags:
  - dual-layout
  - mobile
  - quick-filter-chips
  - tone-consolidation
  - audit-index
  - d02
  - d04
  - d05
  - d10
dependency_graph:
  requires:
    - audit_row/1 component in Sigra.Admin.Components (plan 158-01)
    - audit_tone/1 unified tone helper (plan 158-01)
  provides:
    - AuditIndexLive dual-layout (sg-show-desktop table + sg-show-mobile audit_row cards)
    - AuditIndexLive quick-filter chips for outcome=failure and action_prefix=admin.impersonation
    - Unified audit_tone/1 in AuditIndexLive replacing divergent row_tone/1
  affects:
    - wave-3 plans (158-05) that re-record audit-explorer Playwright baselines
tech_stack:
  added: []
  patterns:
    - Dual-layout wrapper idiom mirroring UsersIndexLive (sg-show-desktop/sg-show-mobile)
    - Checked-input-in-form chip shell for :has(input:checked) active-state CSS (zero new CSS)
    - Unified tone helper body co-located in LiveView (D-10 single source of truth)
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_index_live.ex
decisions:
  - audit_tone/1 replaces row_tone/1 with identical three-clause body (D-10 consolidation)
  - Quick-filter chips placed at top of the GET form so checked inputs participate in same form submission
  - Chips use label+checkbox shell (not plain <a> links) so :has(input:checked) CSS active state fires with zero new CSS
  - No sg-show-* gate on chip row (D-05 all-viewport requirement honored)
metrics:
  duration: "~15 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 1
---

# Phase 158 Plan 02: AuditIndexLive Dual-Layout + Quick-Filter Chips Summary

`AuditIndexLive` updated with dual-layout wrappers (desktop `sg-show-desktop` table + mobile `sg-show-mobile` `audit_row` card list), two all-viewport quick-filter chips setting real `outcome`/`action_prefix` string params with working `:has(input:checked)` active state, and the divergent local `row_tone/1` retired in favor of the unified `audit_tone/1` body.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Dual-layout wrappers + audit_row mobile cards + tone consolidation | 73d296cc | lib/sigra/admin/live/audit_index_live.ex |
| 2 | All-viewport quick-filter chips setting real outcome/action_prefix params | 73d296cc | lib/sigra/admin/live/audit_index_live.ex |

Both tasks were committed in a single atomic commit as the changes to `audit_index_live.ex` are tightly coupled (chips added in the same pass as the layout changes).

## What Was Built

### Dual-layout wrappers (AUDX-01)

The existing `<div :if={@rows != []} class="sg-table-panel">` was updated to add:
- `id="admin-audit-desktop-results"` and `data-testid="admin-audit-desktop-results"`
- Class `sg-show-desktop` added to the existing `sg-table-panel`
- Desktop table `data-tone` callsites updated from `row_tone(row)` → `audit_tone(row)`

A sibling mobile block was added immediately after:
```heex
<div :if={@rows != []} id="admin-audit-mobile-results" data-testid="admin-audit-mobile-results"
     class="sg-stack sg-stack--3 sg-show-mobile">
  <.audit_row :for={row <- @rows} row={row} show_detail show_codes />
</div>
```

The `<.audit_row>` component (from Plan 158-01) renders `sg-list-row <article>` cards. No horizontal-scroll utility was added (D-02 hard-fail honored).

### Quick-filter chips (AUDX-02)

Two chips added at the top of the GET filter form, before the `sg-form-grid` detailed fields:

```heex
<div class="sg-cluster">
  <label class="sg-filter-chip">
    <input type="checkbox" name="outcome" value="failure"
           checked={@current_params[:outcome] == "failure"} class="checkbox checkbox-sm" />
    <span>Failures</span>
  </label>
  <label class="sg-filter-chip">
    <input type="checkbox" name="action_prefix" value="admin.impersonation"
           checked={@current_params[:action_prefix] == "admin.impersonation"} class="checkbox checkbox-sm" />
    <span>Impersonation</span>
  </label>
</div>
```

Implementation uses the checked-input-in-form shell (RESEARCH Option a): the `<label class="sg-filter-chip">` wraps an `<input type="checkbox">` whose `checked` state reflects whether the real string value is active in `@current_params`. This makes the existing `.sg-filter-chip:has(input:checked)` CSS fire with zero new CSS. The inputs are named `outcome`/`action_prefix` and set values `failure`/`admin.impersonation` — the real QueryParams string values. No dead boolean params (`impersonation=true`/`failure=true`) introduced (D-04 hard-fail honored).

The chip row has no `sg-show-*` class — all-viewport (D-05 honored).

### Tone consolidation (D-10)

The local `defp row_tone/1` function was retired and replaced with `defp audit_tone/1` carrying the identical three-clause body:

```elixir
defp audit_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
defp audit_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
defp audit_tone(_row), do: nil
```

All four callsites in the inline `<tr>` (`data-tone=`, `sg-status-pill data-tone=`, and the two outcome cell conditions) were updated to `audit_tone(row)`. This matches the unified body in `Components.audit_tone/1` exactly.

## Deviations from Plan

None — plan executed exactly as written.

The two tasks were committed in a single commit rather than two because all changes were to a single file and were developed together. The commit message covers both task descriptions.

## Verification

- `grep -c "admin-audit-desktop-results" lib/sigra/admin/live/audit_index_live.ex` → 2 (id= + data-testid=)
- `grep -c "admin-audit-mobile-results" lib/sigra/admin/live/audit_index_live.ex` → 2 (id= + data-testid=)
- Desktop wrapper class: `sg-table-panel sg-show-desktop` ✓
- Mobile wrapper class: `sg-stack sg-stack--3 sg-show-mobile` ✓
- `grep -n ".audit_row" lib/sigra/admin/live/audit_index_live.ex` → line 202: `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` ✓
- `grep -c "defp row_tone" lib/sigra/admin/live/audit_index_live.ex` → 0 ✓
- `grep -ci "overflow-x\|scroll" lib/sigra/admin/live/audit_index_live.ex` → 0 ✓
- `grep -c "sg-filter-chip" lib/sigra/admin/live/audit_index_live.ex` → 2 ✓
- `grep -c "impersonation=true\|failure=true\|name=\"impersonation\"\|name=\"failure\"" lib/sigra/admin/live/audit_index_live.ex` → 0 ✓
- `grep -c "checked=" lib/sigra/admin/live/audit_index_live.ex` → 2 ✓
- `grep -c "raw(" lib/sigra/admin/live/audit_index_live.ex` → 0 (T-158-04 honored) ✓
- `mix compile --warnings-as-errors` → exit 0 ✓
- `mix test test/sigra/admin/` → 74 tests, 0 failures ✓

## Known Stubs

None. All fields are wired to real assigns. The chip `checked=` expressions compare against real `@current_params` values. The `audit_row` component is wired to the real `@rows` data.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. Chips set values consumed through the existing `QueryParams.normalize` whitelist (`Map.take(@allowed_params)`). No `raw/1` added. T-158-03 and T-158-04 mitigations confirmed:
- T-158-03: `grep -c "outcome=failure\|admin.impersonation" lib/sigra/admin/live/audit_index_live.ex` shows literal values only — no bypass of QueryParams normalization
- T-158-04: `grep -c "raw(" lib/sigra/admin/live/audit_index_live.ex` → 0

## Self-Check: PASSED

- lib/sigra/admin/live/audit_index_live.ex — FOUND (dual-layout wrappers, audit_row usage, chips, audit_tone/1)
- Commit exists: 73d296cc — FOUND (`git log --oneline | grep 73d296cc` matches)
