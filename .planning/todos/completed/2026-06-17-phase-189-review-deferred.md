---
created: 2026-06-17T00:00:00.000Z
status: done
resolved: 2026-06-18
resolved_by: investigation + test(189) commit this session
title: ConfirmDialog hook hardening + branding error leak (phase 189 deferred review findings)
area: admin-ui
files:
  - priv/templates/sigra.install/admin/admin_hooks.js
  - test/example/assets/js/admin_hooks.js
  - lib/sigra/admin/live/branding_live.ex
source: 189-REVIEW.md (WR-01, WR-02, WR-03, WR-04)
---

## Resolution (2026-06-18)

All four findings were already fixed in the source (most likely during phase 192's
admin-hooks Escape work); this pass verified that and closed the dormant gap in the
verification.

- **WR-01** (Cancel via positional `focusables[0]`) — RESOLVED: the ConfirmDialog hook
  `mounted()` and `_cancel()` both target `[data-sg-confirm-cancel]` with a `focusables[0]`
  fallback; the overlay Cancel buttons in `user_show_live.ex` and `branding_live.ex` carry
  the `data-sg-confirm-cancel` attribute.
- **WR-02** (focus-return with no `<body>` sentinel) — RESOLVED: `destroyed()` guards with
  `document.contains(this._trigger)` and falls back to `document.body.focus()` (commented
  `// WR-02`).
- **WR-03** (Escape lacks `stopImmediatePropagation`) — RESOLVED: the Escape branch calls
  `event.stopImmediatePropagation()` before `_cancel()`.
- **WR-04** (branding `error_message/1` `inspect/1` leak) — RESOLVED: `branding_live.ex`
  now has a dedicated `%Ecto.Changeset{}` clause (human-readable traversal) and a
  `%{__struct__: _}` clause using `Exception.message/1` with a safe rescue — no raw
  `inspect/1` of a non-exception struct reaches the UI.
- Both `admin_hooks.js` mirrors are byte-identical and the served example bundle
  (`test/example/priv/static/assets/js/app.js`) carries the hardened hook (marker parity
  verified).

### Verification gap found and fixed

The PAGE-03 verification spec `admin-modal-interaction.spec.ts` (authored in phase 189)
was **never wired into CI** and had a **stale `/cancel/i` matcher** (the cancel label is
action-specific copy — "Keep sessions" since 188-04), so it could not pass and never ran.
Fixed the matcher to select via the stable `[data-sg-confirm-cancel]` contract and added
the spec to the chromium admin-behavior lane in `.github/workflows/ci.yml`. Ran green
locally against a booted example server (disposable Postgres): 1 passed, all 7 APG gates
(initial focus, tab containment, Escape close, focus return, ARIA, axe-while-open).

## Why deferred

Phase 189's code review (`.planning/phases/189-page-compositions-l3/189-REVIEW.md`)
surfaced 1 blocker, 4 warnings, 2 info findings. The blocker (CR-01 — the audit
pagination guard crashing on cursor meta) was verified and fixed inline during
execute-phase (commit `fix(189): audit pagination guard crashed on cursor meta`),
proven by the example `admin_audit_{index,user}_live_test.exs` regression guard.

The four warnings below are hardening / edge-case / pre-existing improvements —
none is a verified active bug introduced by this phase, so they were deferred
rather than guess-fixed at phase close:

- **WR-01 — ConfirmDialog `_cancel` assumes Cancel is `focusables[0]`.** True for
  both current overlays (`user-session-confirm-overlay`, `restore-defaults-overlay`),
  so no current bug. Brittle if the hook is reused on host-owned markup where Cancel
  is not first. Recommended: target an explicit `[data-sg-confirm-cancel]` element
  instead of positional `focusables[0]`. (Touch both mirrored `admin_hooks.js` copies.)

- **WR-02 — Focus-return uses `document.activeElement` captured at mount with no
  `<body>`-sentinel fallback.** If the trigger blurs during the open round-trip,
  focus can drop to the document root on close. Edge case; add a sentinel fallback.

- **WR-03 — Escape handler lacks `stopImmediatePropagation`.** Co-resident
  document-level Escape listeners (MetricHelp / FieldHelp) also fire on the same
  keystroke. Low impact today (harmless when those popovers are closed), but the
  modal should consume the Escape it handles.

- **WR-04 — `branding_live` `error_message/1` can leak a raw `inspect/1` of a
  non-exception struct** (e.g. `%Ecto.Changeset{}`) into the UI error notice.
  Pre-existing (189-01 only added a `phx-hook` attribute to the restore-defaults
  overlay; it did not touch `error_message/1`). Should map known error structs to
  human copy instead of inspecting.

The two INFO findings (IN-01/IN-02) are noted in the REVIEW.md and need no action.

## How to apply

Run `/gsd-quick` (or fold into a future admin-UI phase) to harden the
ConfirmDialog hook (WR-01/02/03 — remember to keep the two `admin_hooks.js`
mirrors byte-identical) and the branding error mapping (WR-04). Re-run the
example admin browser/behavior tests after.
