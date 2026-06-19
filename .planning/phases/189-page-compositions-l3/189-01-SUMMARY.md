---
phase: 189-page-compositions-l3
plan: "01"
subsystem: admin-ui
tags: [liveview, javascript, css, accessibility, focus-management, aria]
dependency_graph:
  requires: []
  provides: [ConfirmDialog-hook, sg-body-scroll-locked-css, confirm-overlay-hook-wiring]
  affects: [admin-ui, user_show_live, branding_live, installer-templates]
tech_stack:
  added: []
  patterns: [WAI-ARIA-APG-Dialog-Modal, LiveView-phx-hook, focus-trap, focus-restore-to-trigger]
key_files:
  created: []
  modified:
    - priv/templates/sigra.install/admin/admin_hooks.js
    - test/example/assets/js/admin_hooks.js
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/branding_live.ex
decisions:
  - ConfirmDialog hook dispatches synthetic click on first focusable (Cancel) on Escape — avoids hardcoding page-specific server event names (cancel_confirm vs cancel_restore_defaults)
  - _trapFocus is duplicated-and-specialized from CmdK.trapFocus to avoid coupling to the ratified CmdK hook
  - sg-body-scroll-locked rule placed adjacent to .sg-confirm-* block in @layer sg-components
  - Trigger captured as document.activeElement at mounted() time (not this.el) because overlay is :if-rendered and destroyed on close
metrics:
  duration: "~8 min"
  completed: "2026-06-17"
  tasks: 3
  files: 7
requirements: [PAGE-03]
---

# Phase 189 Plan 01: ConfirmDialog Hook + CSS Scroll-Lock Summary

ConfirmDialog LiveView hook providing WAI-ARIA APG Dialog focus trap, Escape handling, and focus-restore-to-trigger — wired onto both `user_show_live` and `branding_live` confirm overlays, with `body.sg-body-scroll-locked` CSS rule propagated across all three byte-identical surfaces.

## What Was Built

**Task 1 — ConfirmDialog hook (both JS surfaces)**

Added `var ConfirmDialog = { ... }` to the IIFE in `admin_hooks.js`. The hook implements the WAI-ARIA APG "Dialog (Modal)" behavior:

- `mounted()`: captures `document.activeElement` as `_trigger` before moving focus; adds `sg-body-scroll-locked` to `document.body.classList`; focuses the first focusable inside `.sg-confirm-dialog` (Cancel renders first in both LiveViews per the existing DOM order); attaches a document-level `keydown` handler and an overlay-click handler.
- `_cancel()`: dispatches a synthetic click on the first focusable (Cancel) inside `.sg-confirm-dialog` — generic, never hardcodes `cancel_confirm` or `cancel_restore_defaults`.
- `_trapFocus()`: duplicated-and-specialized from `CmdK.trapFocus`; queries `.sg-confirm-dialog` instead of `this.dialog` so there is no coupling to the ratified CmdK hook.
- `destroyed()`: removes document keydown listener and overlay-click listener; removes `sg-body-scroll-locked`; calls `this._trigger.focus()` to return focus to the button that opened the dialog.
- Registered in `window.SigraAdminHooks` alphabetically between `CmdK` and `CopyToClipboard`.
- Canonical file copied verbatim to `test/example/assets/js/admin_hooks.js` — byte-identical (D-10).

**Task 2 — CSS scroll-lock rule (all three CSS surfaces)**

Added `body.sg-body-scroll-locked { overflow: hidden; }` inside `@layer sg-components` in `sigra_admin.css`, placed immediately after `@keyframes sg-confirm-enter` adjacent to the existing `.sg-confirm-*` block. No `--sg-*` token values changed. Canonical copied verbatim to both mirrors (D-10/D-11):
- `test/example/priv/static/assets/sigra_admin.css`
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`

**Task 3 — phx-hook wiring on both LiveView overlays**

- `user_show_live.ex` L315: added `id="user-session-confirm-overlay" phx-hook="ConfirmDialog"` to the `:if={@confirm_action}` overlay `<div>`.
- `branding_live.ex` L349: added `id="restore-defaults-overlay" phx-hook="ConfirmDialog"` to the `:if={@restore_defaults_open?}` overlay `<div>`.
- All existing aria attributes preserved (`role="dialog"`, `aria-modal="true"`, `aria-labelledby` on both inner `<section>` elements).
- Cancel-first button order preserved; server event names (`cancel_confirm`, `confirm_action`, `cancel_restore_defaults`, `restore_config_defaults`) unchanged.
- One existing `style="margin-top: var(--sg-space-3);"` documented exception preserved (not added to).
- `mix compile --warnings-as-errors` exits 0.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | acc1e7f3 | feat(189-01): add ConfirmDialog LiveView hook to admin_hooks.js |
| 2 | e9d75594 | feat(189-01): add body.sg-body-scroll-locked rule across all three CSS surfaces |
| 3 | 1fded376 | feat(189-01): wire phx-hook=ConfirmDialog onto both LiveView confirm overlays |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Changes are:
- Client-side JS focus-trap hook on already-rendered, server-gated overlay markup (T-189-01/T-189-02 mitigations applied: hook only dispatches clicks on existing Cancel button; focus trap fully released in `destroyed()`).
- One CSS keyword rule (`overflow: hidden`).
- Two HTML attribute additions on existing conditional divs.

## Known Stubs

None. All surfaces wire real behavior; no placeholder text or hardcoded empty values.

## Self-Check: PASSED

- `priv/templates/sigra.install/admin/admin_hooks.js` — present, `var ConfirmDialog` count = 1, `ConfirmDialog: ConfirmDialog` registration count = 1, no ESM
- `test/example/assets/js/admin_hooks.js` — byte-identical to canonical
- `priv/templates/sigra.install/admin/sigra_admin.css` — `sg-body-scroll-locked` count = 1
- `test/example/priv/static/assets/sigra_admin.css` — byte-identical to canonical
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — byte-identical to canonical
- `lib/sigra/admin/live/user_show_live.ex` — `phx-hook="ConfirmDialog"` count = 1, `id="user-session-confirm-overlay"` count = 1
- `lib/sigra/admin/live/branding_live.ex` — `phx-hook="ConfirmDialog"` count = 1, `id="restore-defaults-overlay"` count = 1
- All 3 task commits verified in git log
- `mix compile --warnings-as-errors` exits 0
