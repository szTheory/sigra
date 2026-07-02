---
status: complete
phase: quick-260602-hvx
plan: 01
subsystem: admin-ui
tags: [admin, audit, liveview, filters, investigator]
requires: [Sigra.Admin.Audit.QueryParams @allowed_params, sg-select, sg-applied-chip, sg-status-pill, app.css]
provides: [investigator-shaped audit explorer (global/org + per-user)]
affects: [lib/sigra/admin/live/audit_index_live.ex, lib/sigra/admin/live/audit_user_live.ex]
tech-stack:
  added: []
  patterns: [Stage-3 sg-applied-chip filter-chip pattern mirrored onto audit views]
key-files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_index_live.ex
    - lib/sigra/admin/live/audit_user_live.ex
decisions:
  - Outcome converted to sg-select (not pinned as text); action_prefix kept free text (pinned)
  - sg-day-group day-group sub-headers deferred (risked :for row-stream + cell assertions)
  - No app.css change needed — all required tokens already existed
metrics:
  duration: ~12m
  completed: 2026-06-02
---

# Phase quick-260602-hvx Plan 01: Stage 5 — Audit Explorer Investigator Filters Summary

Reshaped both audit LiveViews into an investigator surface: Outcome dropdown, from/to date range, removable applied-filter chips with Clear all, risk-toned failure pill, and teaching empty states — backend-safe (markup + private helpers only).

## What Changed

### audit_index_live.ex (global/org explorer)
- Outcome → `<select name="outcome" class="sg-select">` (Any/Success/Failure, value reflected as `selected`).
- Added `name="from"` + `name="to"` `type="date"` range inputs.
- Action prefix kept free TEXT, now with an `e.g. auth or admin.impersonation` placeholder; name + value echo intact.
- New applied-filter chip cluster (keys: actor, effective_user, action_prefix, outcome, from, to) with per-chip ✕ → `remove_chip_path/3` (drops one key + cursor, preserves rest) and `Clear all` → `index_path`.
- Failure outcome cell now renders `<span class="sg-status-pill" data-tone="risk">`; success stays muted text.
- Empty state keeps pinned title `No audit events match this view`, teaches recovery + one-click `Clear all filters` when filtered, orienting copy otherwise.
- Helpers added: `any_filter_active?/1`, `applied_chips/1`, `chip_label/2`, `humanize_outcome/1`, `remove_chip_path/3`, `present_param?/2` (`@chip_keys` module attr).

### audit_user_live.ex (per-user explorer)
- Same Outcome select + risk pill + teaching empty (pinned title `No audit events match this user view`).
- Added a symmetric `name="to"` input next to existing `from`; relabeled `Occurred after` → `Occurred from` and added `Occurred to`. Kept the per-view text-input + placeholder style (did not switch to `type="date"` mid-view, per plan's consistency guidance).
- Chip keys: actor, action_prefix, outcome, from, to (no effective_user input on this view).
- `remove_chip_path/5` and `clear_path` threading preserve `return_to` through chips, Clear all, and the filtered empty-state clear link; export/pagination return_to plumbing untouched.

## Test Pins Preserved
- `action_prefix` stays free text echoing `admin.impersonation` (index) and `session` (per-user).
- `name="effective_user"`, hidden `page_size` echo (value="1"), hidden `order_by`/`order_direction`, per-user hidden `return_to` + `return_to=%2F…` persistence.
- Sortable `Occurred` header, Presenter labels + impersonation badge, no raw metadata rendered.
- Cursor pagination prev/next + aria/disabled logic untouched.

## Deviations from Plan
None - plan executed exactly as written. No CSS gap existed, so `app.css` was not touched.

## Flags
- Library-owned LiveViews: a running dev server must be restarted to view these changes in the browser.
- Visual baselines are refreshed in Stage 8 (not this stage).
- Optional `sg-day-group` day-group sub-headers: **DEFERRED** on both views (per plan — risked the `:for` row stream + cell-content assertions; simpler wins prioritized).

## Test & Compile Results
- `mix compile --warnings-as-errors`: clean (no unused private fns).
- `admin_audit_index_live_test.exs` + `admin_audit_user_live_test.exs`: 5 tests, 0 failures.

## Self-Check: PASSED
- Both modified files exist and compile.
- Commit 92abb7ce contains only the two audit live files (`git show --stat HEAD` verified).
