---
created: 2026-06-17T00:00:00.000Z
status: pending
title: ConfirmDialog hook hardening + branding error leak (phase 189 deferred review findings)
area: admin-ui
files:
  - priv/templates/sigra.install/admin/admin_hooks.js
  - test/example/assets/js/admin_hooks.js
  - lib/sigra/admin/live/branding_live.ex
source: 189-REVIEW.md (WR-01, WR-02, WR-03, WR-04)
---

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
