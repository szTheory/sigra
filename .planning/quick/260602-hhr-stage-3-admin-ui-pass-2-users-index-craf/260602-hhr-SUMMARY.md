---
status: complete
phase: quick-260602-hhr
plan: 01
subsystem: admin-ui
tags: [admin, liveview, users-index, css, sg-tokens, a11y, pagination]
provides:
  - "Showing X–Y of Z users pagination readout (Flop.Meta derived, zero-guarded)"
  - "Removable applied-filter chips + Clear all"
  - "Teaching empty states (filtered-empty vs genuine-zero)"
  - "Truncate-with-tooltip on long emails/orgs"
  - "Richer, labeled mobile card (Organizations/Activity/Registered)"
  - "sg-applied-chip(+__remove), sg-truncate, sg-tabular, sg-cluster--center CSS utilities"
key-files:
  modified:
    - lib/sigra/admin/live/users_index_live.ex
    - test/example/priv/static/assets/css/app.css
metrics:
  completed: 2026-06-02
---

# Quick 260602-hhr: Stage 3 — Users Index Craft Summary

Applied Stage 3 "users index craft" polish to the library-owned admin users index:
a "Showing X–Y of Z users" pagination readout, removable applied-filter chips with
Clear all, teaching empty states that distinguish filtered-empty from genuine zero,
truncate-with-tooltip on long emails/orgs, and a restructured, labeled mobile card —
markup + minimal additive token-driven CSS only.

## What Changed

### lib/sigra/admin/live/users_index_live.ex
- **Pagination readout:** Replaced bare `Page {n}` with a `<span class="sg-muted sg-text-sm sg-tabular">` reading `Showing {x}–{y} of {z} users · Page X of N` (en-dash). Driven by new `showing_range/2` helper computing `{current_offset+1, current_offset+length(rows), total_count}` with the `z == 0` case guarded to `{0,0,0}`. Prev/next icon buttons + aria-disabled/is-disabled states untouched.
- **Applied-filter chips:** New region between `</form>` and the desktop results div, guarded by `any_filter_active?/1`. Each active filter renders an `sg-applied-chip` with a human label and an `✕` (`&times;`) remove link (`aria-label="Remove filter …"` + `sr-only` "remove") pointing at `remove_chip_path/3` (drops one key, preserves the rest, resets `page=1`). Trailing `Clear all` → `index_path`. Non-filter keys (page/page_size/order_by/order_direction) never iterated. Labels via `chip_label/2` clauses ("mfa"→MFA, "passkeys"→Passkeys, "registered_from"→"Registered from:", etc., capitalize fallback).
- **Teaching empty states:** Kept the pinned title `No users match this view`; branched on `any_filter_active?/1` — filtered-empty shows a recovery body + a one-click `Clear all filters` action; genuine-zero shows an orienting, non-error teaching body.
- **Truncate-with-tooltip (desktop):** Email and organization-summary cells gained `sg-truncate` + `title={full value}` (full text stays in DOM).
- **Richer mobile card:** Replaced the single `sg-muted` meta wall with an `sg-kv` definition list of labeled groups (`sg-meta-label`/`sg-meta-value`): Organizations (summary + count), Activity, Registered, plus extra columns. Email/org carry `sg-truncate` + `title`. Identity block, status pills, `extra_badges`, `extra_columns`, the `data-testid`/`id`, and the `Open user` action (+ `?return_to=`) preserved.

### test/example/priv/static/assets/css/app.css (additive only)
- `.sg-applied-chip` + `.sg-applied-chip__remove` (brand-soft pill, full radius, hover-guarded `(hover: hover) and (pointer: fine)`, `sg-transition-tone`).
- `.sg-truncate` (cell-driven ellipsis: `max-width:100%; overflow:hidden; text-overflow:ellipsis; white-space:nowrap`).
- `.sg-tabular` (`font-variant-numeric: tabular-nums`).
- `.sg-cluster--center` (`justify-content: center`) — needed for the centered empty-state action cluster.
- All token-driven, inside `@layer sg-components`, **no new `!important`** (7 → 7).

## Deviations from Plan

**[Rule 3 — blocking] Added `.sg-cluster--center` modifier.** The plan's empty-state action needed a centered button cluster, but only `--between/--end/--start` existed. Added the one-line additive modifier alongside the others rather than inline styling. Token-free, no `!important`.

None otherwise — plan executed as written.

## Verification

- `mix compile --warnings-as-errors` (repo root): **clean** (no warnings, no unused private functions).
- Two pinned contract test files: **6 tests, 0 failures**
  (`admin_user_index_live_test.exs` + `admin_user_filters_live_test.exs`).
- `!important` count: **7 → 7** (unchanged).
- All pinned strings/ids preserved: desktop+mobile `data-testid`/`id`, `Search`, `More filters`, all filter `name=`s, empty-state title `No users match this view`, `Open user` + `?return_to=`.
- `git show --stat HEAD`: exactly the 2 intended files.

## Flags

- **Library-owned LiveView:** `users_index_live.ex` lives in the library (path dep), not the
  example app — it is **not hot-reloaded**. A `mix phx.server` restart is required to view
  changes in the demo. Visual baselines are refreshed in **Stage 8**, not here.

## Self-Check: PASSED
- `lib/sigra/admin/live/users_index_live.ex` — FOUND
- `test/example/priv/static/assets/css/app.css` — FOUND
- Commit on HEAD with exactly these 2 files — FOUND
