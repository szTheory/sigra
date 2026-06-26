---
phase: 200-user-detail-elevation
plan: "01"
subsystem: admin-live
tags: [admin, liveview, sessions, revoke, apg-dialog, routes, glossary]
dependency_graph:
  requires: []
  provides:
    - "Sigra.Admin.Live.UserSessionsLive"
    - "/admin/users/:id/sessions route (global + org, all three router files)"
  affects:
    - "Plan 02 (UserShowLive recompose depends on UserSessionsLive existing)"
    - "Plan 03 (Playwright checkpoints for user-sessions slug)"
tech_stack:
  added: []
  patterns:
    - "per-user LiveView skeleton (clone of audit_user_live.ex pattern)"
    - "APG confirm dialog reuse (ConfirmDialog hook, unchanged JS)"
    - "D-12 lockstep route propagation (example + installer + golden)"
key_files:
  created:
    - lib/sigra/admin/live/user_sessions_live.ex
  modified:
    - test/example/lib/example_web/router.ex
    - priv/templates/sigra.install/admin/router_injection.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
    - test/sigra/admin/glossary_test.exs
decisions:
  - "Confirm copy uses UI-SPEC verbatim ('The user will be signed out of this session immediately. They can sign in again.') rather than the older phrasing in user_show_live.ex"
  - "index_path/2 helper excluded from UserSessionsLive (unused — breadcrumbs use user_detail_path; no rendered self-referential links needed)"
  - "Cancel/Revoke confirm labels per UI-SPEC Copywriting Contract ('Cancel' / 'Revoke') rather than user_show_live.ex's 'Keep sessions' label"
metrics:
  duration: "4m"
  completed: "2026-06-26"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 4
status: complete
---

# Phase 200 Plan 01: UserSessionsLive + Route Lockstep + Glossary Guard Summary

**One-liner:** Net-new `UserSessionsLive` with full session table and APG confirm dialog, wired to `/admin/users/:id/sessions` across example + installer + golden fixture in lockstep, and scoped into the glossary drift guard.

## What Was Built

### Task 1: UserSessionsLive

Created `lib/sigra/admin/live/user_sessions_live.ex` — a lib-owned per-user admin sessions surface.

- Module cloned from `audit_user_live.ex` skeleton (mount, handle_params, scope-aware breadcrumbs, sanitize_return_to, runtime_config!)
- Session table markup and revoke event handlers lifted from `user_show_live.ex`
- Confirmed overlay lifted verbatim: `id="user-session-confirm-overlay"`, `phx-hook="ConfirmDialog"`, `data-sg-confirm-cancel`, `id="user-session-confirm-title"` — all selectors preserved for `admin-modal-interaction.spec.ts`
- Revoke mutations route through `Actions.revoke_session/4` and `Actions.revoke_all_sessions/3` unchanged
- `scope_ribbon`, `sg-page-header`, `sg-card sg-stack--3`, `sg-table-panel/sg-table`, `empty_state` — all existing primitives, no new CSS
- Breadcrumb: Overview / Users / email / Sessions (threads `user_detail_path/3` as parent crumb)
- `mix compile --warnings-as-errors` clean

### Task 2: Route Lockstep (D-12)

Added the Sessions route to both scope blocks of all three router files in a single commit:
- Global: `live "/admin/users/:id/sessions", Elixir.Sigra.Admin.Live.UserSessionsLive, :show`
- Org: `live "/users/:id/sessions", Elixir.Sigra.Admin.Live.UserSessionsLive, :show`

Files changed atomically: `test/example/lib/example_web/router.ex`, `priv/templates/sigra.install/admin/router_injection.ex`, `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex`.

Routes inherit existing `:admin_global` / `:admin_organization` pipelines (RequireAdminAccess + AdminScope on_mount) — no new auth code. Mitigates T-200-01 IDOR threat.

`cd test/example && mix compile --warnings-as-errors` clean — route resolves.

### Task 3: Glossary Drift Guard

Added `"lib/sigra/admin/live/user_sessions_live.ex"` to `@in_scope_files` in `test/sigra/admin/glossary_test.exs`. Updated header comment: 9 in-scope files, 8 admin LiveViews.

`mix test test/sigra/admin/glossary_test.exs` — 2 tests, 0 failures.

## Verification

- `mix compile --warnings-as-errors` (library): PASS
- `cd test/example && mix compile --warnings-as-errors` (example/route): PASS
- `mix test test/sigra/admin/glossary_test.exs`: 2 tests, 0 failures
- All three router files contain exactly 2 `UserSessionsLive` route lines (global + org)
- CSS three-copy parity: md5 returns 1 unique hash (no CSS changes introduced)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused `index_path/2` helper**
- **Found during:** Task 1 verification (`mix compile --warnings-as-errors`)
- **Issue:** Compiler warned `function index_path/2 is unused` — the helper was included from the audit_user_live.ex clone but UserSessionsLive has no rendered self-referential links that need it.
- **Fix:** Removed the two-clause `index_path/2` private function.
- **Files modified:** `lib/sigra/admin/live/user_sessions_live.ex`
- **Commit:** e4c97643 (within the task 1 commit)

### Copy Choices (UI-SPEC over user_show_live.ex defaults)

The UI-SPEC Copywriting Contract specifies different confirm copy from what `user_show_live.ex` currently uses:
- Confirm button labels: `Cancel` / `Revoke` (UI-SPEC) vs `Keep sessions` / `Revoke session` / `Revoke all sessions` (user_show_live.ex). Used UI-SPEC on the new surface since the plan explicitly requires it.
- Confirm body copy: `The user will be signed out of this session immediately. They can sign in again.` (UI-SPEC) vs `Revoke this session for #{email}? This signs them out of that browser or device.` (user_show_live.ex). Used UI-SPEC.

These are intentional: the new surface is authored award-grade from the start per D-04. The plan cites the UI-SPEC Copywriting Contract as authoritative for this surface.

## Known Stubs

None — the new LiveView fully delegates mutations to `Actions.revoke_session/4` and `Actions.revoke_all_sessions/3`. No hardcoded or placeholder data paths.

## Threat Flags

None — no new network endpoints beyond what was planned. The sessions route inherits existing admin auth pipeline. T-200-01 (IDOR) mitigated by pipeline inheritance. T-200-02 (CSRF) mitigated by LiveView websocket channel.

## Self-Check: PASSED

- `lib/sigra/admin/live/user_sessions_live.ex` — FOUND
- `test/example/lib/example_web/router.ex` (2x UserSessionsLive) — FOUND
- `priv/templates/sigra.install/admin/router_injection.ex` (2x UserSessionsLive) — FOUND
- `test/fixtures/install_golden/tree/.../router.ex` (2x UserSessionsLive) — FOUND
- `test/sigra/admin/glossary_test.exs` (user_sessions_live.ex in scope) — FOUND
- Commit e4c97643 — FOUND (feat: create UserSessionsLive)
- Commit 44159e78 — FOUND (feat: add sessions route lockstep)
- Commit 33b5a84a — FOUND (feat: extend glossary guard)
