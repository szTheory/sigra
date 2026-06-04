---
phase: 158-audit-mobile-per-user-audit-high-effort
plan: "04"
subsystem: admin-live
tags:
  - audit-row
  - user-show
  - tone-unification
  - d10
  - audx-03
dependency_graph:
  requires:
    - 158-01 (audit_row/1 component + audit_tone/1 unified helper)
  provides:
    - UserShowLive Recent Audit block routed through compact audit_row/1
    - audit_tone/1 retired from user_show_live.ex (D-10 complete)
  affects:
    - Plan 05 (user-detail Playwright baseline — impersonation→info delta documented)
tech_stack:
  added: []
  patterns:
    - Self-analog swap (inline article block → shared compact component)
    - Tone consolidation via component ownership (no local helper)
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/user_show_live.ex
decisions:
  - audit_tone/1 deleted from user_show_live.ex; tone is owned by components.ex (D-10 complete)
  - compact audit_row called without show_detail/show_codes (defaults false) — preserves existing compact rendering
  - alice@demo.sigra.dev recent-audit contains impersonation rows (offsets 19-20 are most-recent for alice); Plan 05 baseline re-record needed for alice persona
metrics:
  duration: "~5 minutes"
  completed: "2026-06-04"
  tasks_completed: 1
  files_modified: 1
---

# Phase 158 Plan 04: UserShowLive Recent Audit via Compact audit_row Summary

UserShowLive's "Recent Audit" block now routes through the shared compact `audit_row/1` component (defaults: `show_detail=false`, `show_codes=false`). The old divergent `audit_tone/1` in `user_show_live.ex` is deleted — tone is now owned by the component's private helper. This is the third and final consumer site for the unified `audit_row/1` (AUDX-03).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Route Recent Audit block through compact audit_row and retire audit_tone/1 | 4f190daf | lib/sigra/admin/live/user_show_live.ex |

## What Was Built

### UserShowLive "Recent Audit" block — compact audit_row/1

Replaced the inline `<article :for={row <- @detail.recent_audit} class="sg-list-row sg-stack sg-stack--2" data-tone={audit_tone(row)}>` block (with inline `Calendar.strftime`) with the single-line compact call:

```heex
<.audit_row :for={row <- @detail.recent_audit} row={row} />
```

The component's default attrs (`show_detail=false`, `show_codes=false`) reproduce the prior compact layout: status pill + actor summary + timestamp only — no Actor/Effective-user/id/action detail lines.

### Retired: `defp audit_tone/1` in user_show_live.ex

The old local helper (4 clauses, returned `"risk"` for non-success outcomes but had NO impersonation branch — unlike the unified helper) is deleted. Tone derivation is now exclusively in `components.ex`.

### Intended tone consolidation side effect

The unified `audit_tone/1` in `components.ex` maps `action_badge` present → `"info"`. The old local helper had no such branch, returning `nil` for impersonation rows. Any impersonation row in `@detail.recent_audit` now renders `data-tone="info"` where it previously had none.

### Impersonation rows in demo seed data: YES — Plan 05 baseline re-record needed

The demo seed (`test/example/lib/example/demo/seeds.ex`) creates impersonation events for `alice@demo.sigra.dev` at offsets 19 and 20 (`admin.impersonation.start` and `admin.impersonation.stop` with outcome `"success"` and actor `admin@demo.sigra.dev`). These are the **most recent** audit events for alice (highest offsets in her persona batch), and `@audit_preview_limit` is 5 — so alice's `recent_audit` **will include these impersonation rows**.

**Decision for Plan 05:** The `user-detail` Playwright baseline for alice will show `data-tone="info"` on these rows after this change. Plan 05 must perform a deliberate re-record of the alice user-detail baseline to capture the intended `data-tone="info"` rows; the delta is expected, not a surprise.

For the generic test user (18 events, offsets 0-17, impersonation at offsets 9-10), the 5 most recent are offsets 13-17 — no impersonation rows. The generic user-detail baseline is unaffected.

## Deviations from Plan

None. Plan executed exactly as written.

## Verification

- `grep -n ".audit_row" lib/sigra/admin/live/user_show_live.ex` — line 265: `<.audit_row :for={row <- @detail.recent_audit} row={row} />`
- `grep -c "defp audit_tone" lib/sigra/admin/live/user_show_live.ex` — 0 (deleted)
- `grep -c "data-tone={audit_tone" lib/sigra/admin/live/user_show_live.ex` — 0 (deleted)
- `grep -c "View full audit" lib/sigra/admin/live/user_show_live.ex` — 1 (preserved)
- `grep -c "No recent audit activity" lib/sigra/admin/live/user_show_live.ex` — 1 (preserved)
- `grep -c "defp row_tone\|defp audit_tone\|defp recent_tone" lib/sigra/admin/live/user_show_live.ex` — 0 (no new tone helper)
- `grep -c "raw(" lib/sigra/admin/live/user_show_live.ex` — 0 (T-158-09 honored)
- `mix compile --warnings-as-errors` — EXIT: 0
- `mix test test/sigra/admin/` — 74 tests, 0 failures

## Known Stubs

None. All fields are wired to real assigns from `@detail.recent_audit` (presenter row maps). No placeholder text or TODO items.

## Threat Flags

None. Only presentation changes — no new network endpoints, auth paths, file access, or schema changes. All dynamic HEEx interpolation uses `{...}` (auto-escaped, no `raw/1`) via the golden-tested `audit_row/1` component (T-158-09 mitigated).

## Self-Check: PASSED

- lib/sigra/admin/live/user_show_live.ex — FOUND (`.audit_row` at line 265; `audit_tone` count = 0)
- Commit 4f190daf exists (feat(158-04): route user-detail Recent Audit through compact audit_row)
- 74 admin tests pass, 0 failures
- mix compile --warnings-as-errors clean
