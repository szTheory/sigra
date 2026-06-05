---
phase: 158-audit-mobile-per-user-audit-high-effort
plan: "03"
subsystem: admin-live-audit-user
tags:
  - audit-user
  - dual-layout
  - mobile
  - shared-components
  - chips
  - tone-consolidation
  - audx-03
dependency_graph:
  requires:
    - 158-01 (audit_row/1 component + Sigra.Admin.Components import)
  provides:
    - AuditUserLive dual-layout with sg-show-desktop/sg-show-mobile wrappers
    - audit_row/1 mobile cards in AuditUserLive (admin-audit-user-mobile-results)
    - Shared page_back/scope_ribbon/empty_state/applied_chip chrome in AuditUserLive
    - Quick-filter chips (Failures/Impersonation) in AuditUserLive
    - Unified audit_tone/1 (retiring local row_tone/1) in AuditUserLive
  affects:
    - wave-2 parallel plans (158-02, 158-04) that mirror similar changes to other LiveViews
tech_stack:
  added: []
  patterns:
    - Dual-layout sg-show-desktop/sg-show-mobile (mirroring users_index_live.ex idiom)
    - audit_row/1 mobile card iteration with show_detail/show_codes
    - Option (a) chip active-state via label+checked-input shell setting real string params
    - Shared Sigra.Admin.Components chrome (page_back/scope_ribbon/empty_state/applied_chip)
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_user_live.ex
    - test/example/test/example_web/live/admin_audit_user_live_test.exs
decisions:
  - "Dual-layout uses identical testids/classes as the explorer: admin-audit-user-desktop-results (sg-table-panel sg-show-desktop) and admin-audit-user-mobile-results (sg-stack sg-stack--3 sg-show-mobile)"
  - "Local defp row_tone/1 retired; replaced with defp audit_tone/1 (identical three-clause body) for the desktop <tr> data-tone calls"
  - "Quick-filter chips use Option (a): label+checked-input shell whose checked state maps to the real string param value (outcome=failure, action_prefix=admin.impersonation), preserving :has(input:checked) CSS active state with zero new CSS"
  - "Empty-state copy follows UI-SPEC per-user contract: 'No audit events for this user' / 'No scoped events are currently tied to this user.'"
  - "handle_params/list_subject_events left byte-unchanged; subject scoping provably untouched"
metrics:
  duration: "~6 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 2
---

# Phase 158 Plan 03: AuditUserLive Dual-Layout + Shared Chrome + Chips Summary

`AuditUserLive` reconciled with the explorer: dual-layout (desktop table + mobile `<.audit_row>` cards), shared chrome (`page_back`/`scope_ribbon`/`empty_state`/`applied_chip`), quick-filter chips (Failures/Impersonation), and unified `audit_tone/1` — all subject-scoped and presentation-only.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Dual-layout + audit_row mobile cards + tone consolidation | 1d05c1e4 | lib/sigra/admin/live/audit_user_live.ex |
| 2 | Wire shared chrome components + quick-filter chips | 10fe1e4e | lib/sigra/admin/live/audit_user_live.ex, test/example/test/example_web/live/admin_audit_user_live_test.exs |

## What Was Built

### Task 1: Dual-layout + mobile cards + tone consolidation

`AuditUserLive` now has the same dual-layout idiom as `UsersIndexLive` and (post-Plan-02) `AuditIndexLive`:

- **Desktop wrapper:** `<div id="admin-audit-user-desktop-results" data-testid="admin-audit-user-desktop-results" class="sg-table-panel sg-show-desktop">` wraps the existing inline `<table>` (D-03, >= 1024px).
- **Mobile wrapper:** `<div id="admin-audit-user-mobile-results" data-testid="admin-audit-user-mobile-results" class="sg-stack sg-stack--3 sg-show-mobile">` iterates `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` (< 1024px, no horizontal scroll).
- **Tone consolidation (D-10):** Local `defp row_tone/1` retired; replaced with `defp audit_tone/1` (identical three-clause body: outcome not in ["success",nil,""] → "risk"; action_badge present → "info"; else nil). All desktop `<tr>` `data-tone` calls updated to `audit_tone/1`.
- **Import:** `import Sigra.Admin.Components` added for `audit_row/1` access.
- **Subject scoping:** `handle_params` and `list_subject_events` left byte-unchanged.

### Task 2: Shared chrome + quick-filter chips

- **Back-nav:** Replaced `<a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>` with `<.page_back return_to={@return_to} label="Back to user" />`.
- **Scope ribbon:** Replaced inline `<span class="sg-muted sg-text-sm">{scope_copy(...)}</span>` with `<.scope_ribbon copy={scope_copy(@admin_scope)} />`.
- **Applied chips:** Replaced inline `<span :for={...} class="sg-applied-chip">` loop with `<.applied_chip :for={...} label remove_href />`.
- **Empty state:** Replaced `<div class="sg-empty-state ...">` with `<.empty_state title="No audit events for this user">No scoped events are currently tied to this user.</.empty_state>` per per-user copy contract.
- **Quick-filter chips:** Two chips above the detailed filter form on all viewports: "Failures" (sets `outcome=failure`) and "Impersonation" (sets `action_prefix=admin.impersonation`). Uses Option (a): `<label class="sg-filter-chip"><input type="checkbox" name="outcome" value="failure" checked={...}>` so `:has(input:checked)` CSS active state works with zero new CSS. No dead `impersonation=true`/`failure=true` params.
- **Tests:** Added 2 LiveView render tests in `admin_audit_user_live_test.exs` asserting `page_back` ghost-button and `empty_state` per-user title/copy.

## Deviations from Plan

None. Plan executed exactly as written.

The `audit_tone/1` rename (from `row_tone/1`) is consistent with the plan's "retire the local `defp row_tone/1`" instruction while keeping the desktop `<tr>` data-tone calls working.

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix test test/sigra/admin/components_test.exs` — 19 tests, 0 failures
- `(cd test/example && mix test test/example_web/live/admin_audit_user_live_test.exs)` — 4 tests, 0 failures (2 existing + 2 new)
- `grep -c "admin-audit-user-desktop-results"` → 2 (id + data-testid)
- `grep -c "admin-audit-user-mobile-results"` → 2 (id + data-testid)
- `grep -n "\.audit_row"` → shows `<.audit_row :for={row <- @rows} row={row} show_detail show_codes />`
- `grep -c "defp row_tone"` → 0 (retired)
- `grep -c "list_subject_events"` → 1 (unchanged from baseline)
- `grep -ci "overflow-x"` → 0 (no horizontal scroll)
- `grep -c "\.page_back\|\.scope_ribbon\|\.empty_state\|\.applied_chip"` → 5 (all 4 wired)
- `grep -c "sg-btn--ghost sg-btn--sm\" href="` → 0 (back-nav via component)
- `grep -c "class=\"sg-applied-chip\""` → 0 (inline chip replaced)
- `grep -c "class=\"sg-empty-state"` → 0 (inline empty-state replaced)
- `grep -c "No audit events for this user"` → 1 (per-user copy)
- `grep -c "sg-filter-chip"` → 2 (both chips)
- `grep -c "admin.impersonation"` → 3 (value + checked attr + hidden input context)
- `grep -c "impersonation=true\|failure=true"` → 0 (no dead booleans)
- `grep -c "raw("` → 0 (no raw/1 introduced)

## Known Stubs

None. All fields are wired to live assigns. No placeholder text or TODO items.

## Threat Flags

None. This plan is presentation-only with no new network endpoints, auth paths, or schema changes.

- T-158-06 (scope leak): `handle_params`/`list_subject_events` byte-unchanged — per-user view cannot widen beyond the subject user.
- T-158-07 (XSS): All dynamic fields render via HEEx auto-escaped `{...}` interpolation through golden-tested components; no `raw/1` introduced.
- T-158-08 (open redirect): `return_to` continues through `sanitize_return_to/3` before reaching `<.page_back>`; sanitizer not bypassed.

## Self-Check: PASSED

- lib/sigra/admin/live/audit_user_live.ex — FOUND (audit_row at line 231, page_back at line 66, empty_state title at line 250)
- test/example/test/example_web/live/admin_audit_user_live_test.exs — FOUND (Phase 158 describe block with page_back and empty_state tests)
- Commits exist: 1d05c1e4 (Task 1: dual-layout + tone), 10fe1e4e (Task 2: shared chrome + chips)
