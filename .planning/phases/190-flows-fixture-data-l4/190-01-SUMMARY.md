---
phase: 190-flows-fixture-data-l4
plan: "01"
subsystem: admin-ui
tags: [confirm-dialog, accessibility, apg, keyboard, error-handling, ecto-changeset]
dependency_graph:
  requires: []
  provides: [WR-01, WR-02, WR-03, WR-04]
  affects:
    - priv/templates/sigra.install/admin/admin_hooks.js
    - test/example/assets/js/admin_hooks.js
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/branding_live.ex
tech_stack:
  added: []
  patterns:
    - "[data-sg-confirm-cancel] explicit selector replaces positional focusables[0]"
    - "document.contains() guard + document.body.focus() sentinel fallback in destroyed()"
    - "event.stopImmediatePropagation() in Escape handler before cancel dispatch"
    - "Ecto.Changeset.traverse_errors/2 for human-readable changeset error messages"
key_files:
  created: []
  modified:
    - priv/templates/sigra.install/admin/admin_hooks.js
    - test/example/assets/js/admin_hooks.js
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/branding_live.ex
decisions:
  - "WR-01: Use explicit [data-sg-confirm-cancel] querySelector in both mounted() and _cancel() with focusables[0] as defensive fallback"
  - "WR-02: document.contains(this._trigger) guard prevents stale-reference focus; document.body.focus() as sentinel"
  - "WR-03: stopImmediatePropagation() before _cancel() prevents co-resident document keydown listeners from double-firing on Escape"
  - "WR-04: %Ecto.Changeset{} clause inserted before %{__struct__: _module} catch-all; traverse_errors/2 with Phoenix-idiomatic ~r\"%{(\\w+)}\" substitution"
metrics:
  duration: "~8 minutes"
  completed: "2026-06-17T18:36:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 190 Plan 01: WR-01/02/03/04 ConfirmDialog Hardening Summary

**One-liner:** ConfirmDialog hardened with APG-conformant keyboard behavior ([data-sg-confirm-cancel] selector, Escape stopImmediatePropagation, body-sentinel focus fallback) and branding error messages upgraded from inspect/1 to human-readable traverse_errors/2 traversal.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | WR-01/02/03 — Harden ConfirmDialog + data-sg-confirm-cancel in LiveViews | 4217a702 | admin_hooks.js (x2), user_show_live.ex, branding_live.ex |
| 2 | WR-04 — Add %Ecto.Changeset{} clause to branding_live.ex error_message/1 | adc54cac | branding_live.ex |

## What Was Built

### Task 1: WR-01/02/03 ConfirmDialog Hardening

Three targeted hardening changes applied to the ConfirmDialog JS hook in both the canonical template and its byte-identical example mirror:

**WR-01 (explicit cancel selector):** In `mounted()`, replaced `focusables[0].focus()` with a `dialog.querySelector('[data-sg-confirm-cancel]')` lookup that focuses the Cancel button explicitly, falling back to `focusables[0]` defensively. In `_cancel()`, replaced `focusables[0].click()` with an explicit `cancelEl = dialog.querySelector('[data-sg-confirm-cancel]')` lookup with early return, keeping the positional fallback.

**WR-02 (body-sentinel focus return):** In `destroyed()`, replaced bare `if (this._trigger && this._trigger.focus)` with `document.contains(this._trigger)` guard so that when the trigger element has been removed from the DOM (e.g., after a LiveView patch), focus falls back to `document.body` instead of silently failing.

**WR-03 (Escape stopImmediatePropagation):** In `_onKeydown`, added `event.stopImmediatePropagation()` immediately after `event.preventDefault()` and before `self._cancel()` in the Escape branch. Prevents co-resident `document` keydown listeners from firing on the same event.

**Companion HEEx changes:** Added `data-sg-confirm-cancel` attribute to the Cancel button in `user_show_live.ex` (line 325, `cancel_confirm` event) and `branding_live.ex` (line 361-366, `cancel_restore_defaults` event). No logic, CSS classes, or copy changed — only the data attribute added.

Both `admin_hooks.js` files (template + example mirror) verified byte-identical (MD5: `b80ebb47e1c9ac9ccba07361514fafdf`).

### Task 2: WR-04 Ecto.Changeset Error Traversal

Inserted a new `defp error_message(%Ecto.Changeset{} = changeset)` clause in `branding_live.ex` between the `%ArgumentError{}` clause and the `%{__struct__: _module}` catch-all. The new clause uses `Ecto.Changeset.traverse_errors/2` with the Phoenix-idiomatic `~r"%{(\w+)}"` regex substitution against `opts` keyword values, then joins field-error pairs as `"field: error1, error2"` separated by `"; "`.

This satisfies T-190-01 (information disclosure threat) — changeset struct internals and the unhelpful `"changeset is invalid"` message from `Exception.message/1` no longer reach the flash. It also satisfies D-13 (brand-voice error rule: what failed + why + next action).

## Verification Results

- `md5sum` on both admin_hooks.js files: identical (`b80ebb47e1c9ac9ccba07361514fafdf`)
- `data-sg-confirm-cancel` count in `admin_hooks.js` (template): 2 (mounted + _cancel)
- `data-sg-confirm-cancel` count in `admin_hooks.js` (example): 2 (mounted + _cancel)
- `data-sg-confirm-cancel` count in `user_show_live.ex`: 1
- `data-sg-confirm-cancel` count in `branding_live.ex`: 1
- `stopImmediatePropagation` count in both admin_hooks.js files: 1 each
- `document.body.focus` count in both admin_hooks.js files: 1 each
- `traverse_errors` in branding_live.ex: present at line 715, before %{__struct__: _module} catch-all (line 725)
- Main repo branding tests: 11 tests, 0 failures

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no stub patterns introduced. All wiring is complete.

## Threat Flags

No new threat surface beyond what was planned.

| Mitigation | Status |
|------------|--------|
| T-190-01: WR-04 traverse_errors replaces inspect/1 for Ecto.Changeset | SHIPPED |
| T-190-02: WR-03 stopImmediatePropagation on Escape | SHIPPED |
| T-190-03: WR-02 body-sentinel fallback (accepted low-severity) | SHIPPED |

## Self-Check: PASSED

- [x] `priv/templates/sigra.install/admin/admin_hooks.js` — modified and committed (4217a702)
- [x] `test/example/assets/js/admin_hooks.js` — modified and committed (4217a702)
- [x] `lib/sigra/admin/live/user_show_live.ex` — modified and committed (4217a702)
- [x] `lib/sigra/admin/live/branding_live.ex` — modified and committed (adc54cac)
- [x] Commits exist: `git log --oneline` shows 4217a702 and adc54cac
- [x] Byte-parity: both admin_hooks.js md5 hashes are identical
