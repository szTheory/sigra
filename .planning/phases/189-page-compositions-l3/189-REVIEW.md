---
phase: 189-page-compositions-l3
reviewed: 2026-06-17T00:00:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/sigra/admin/live/audit_index_live.ex
  - lib/sigra/admin/live/audit_user_live.ex
  - lib/sigra/admin/live/branding_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - priv/templates/sigra.install/admin/admin_hooks.js
  - priv/templates/sigra.install/admin/sigra_admin.css
  - test/example/assets/js/admin_hooks.js
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/admin-modal-interaction.spec.ts
  - test/example/priv/static/assets/sigra_admin.css
  - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
  - guides/reference/admin-quality-ledger.md
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: resolved
remediation:
  cr_01: fixed inline during execute-phase (audit pagination guard cursor-meta KeyError); proven by example admin_audit_{index,user}_live_test.exs (7 tests, 0 failures)
  warnings: deferred to .planning/todos/pending/2026-06-17-phase-189-review-deferred.md (WR-01/02/03 hook hardening, WR-04 pre-existing branding error leak)
  info: no action required
---

# Phase 189: Code Review Report

> **Remediation (execute-phase, 2026-06-17):** CR-01 (BLOCKER) was verified
> against the codebase and fixed inline — the audit pagination guard referenced
> `meta.total_pages` on the cursor-based audit explorer meta map (no such key),
> raising `KeyError` on every audit render. Fixed in both `audit_index_live` and
> `audit_user_live` by dropping the meaningless `total_pages` term; the existing
> example `admin_audit_{index,user}_live_test.exs` (7 tests) are the regression
> guard and pass. WR-01..WR-04 (hardening / pre-existing) are tracked in
> `.planning/todos/pending/2026-06-17-phase-189-review-deferred.md`.

**Reviewed:** 2026-06-17
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Reviewed the Phase 189 IA-audit and ConfirmDialog work: the new `ConfirmDialog`
LiveView hook in `admin_hooks.js`, its wiring in `user_show_live.ex` and
`branding_live.ex`, the IA edits to the audit/organization LiveViews, the
PAGE-03 Playwright spec, and the three mirrored static assets.

**Mirror integrity is clean.** Both `admin_hooks.js` copies (template + example)
are byte-identical (MD5 match), and all three `sigra_admin.css` copies
(template + example + golden fixture) are byte-identical (MD5
`9b281962ee8fe33254829c877af00382`, 1484 lines each). The CSS classes the new
hook depends on (`.sg-confirm-overlay`, `.sg-confirm-dialog`,
`.sg-confirm-dialog__actions`, `body.sg-body-scroll-locked`) all exist, and
animations are covered by the global `prefers-reduced-motion` block.

**However, the IA-audit "honest pagination" change is a shipped crash.** The
`multi_page?/1` guard added to both audit explorers was copied verbatim from
`users_index_live.ex`, but it dereferences `meta.total_pages` with map dot
syntax. The audit explorer returns a **plain map** that has no `total_pages`
key (unlike the users index, whose meta is a `%Flop.Meta{}` struct). Dot access
on a map missing the key raises `KeyError`, and the guard runs on every
successful audit render — so both audit pages crash on load. This is not
covered by any existing test.

## Critical Issues

### CR-01: `multi_page?/1` raises `KeyError` on every successful audit render — audit explorer + per-user audit pages crash on load

**File:** `lib/sigra/admin/live/audit_index_live.ex:307-309`, `lib/sigra/admin/live/audit_user_live.ex:473-475`

**Issue:**
Both guards were copied from `users_index_live.ex:516` with the comment
"Guard logic is identical to users_index_live" — but the meta shapes are not
identical:

```elixir
defp multi_page?(meta) do
  (meta.total_pages || 1) > 1 or not is_nil(meta.previous_page) or not is_nil(meta.next_page)
end
```

- `users_index_live` meta is `%Flop.Meta{}` (a struct), so `meta.total_pages`
  resolves to the struct's defaulted field — safe.
- The audit explorers' meta is a **plain map** built in
  `Sigra.Admin.Audit.Explorer.list_events/3` (`lib/sigra/admin/audit/explorer.ex:143-147`)
  and `list_subject_events/4`:

  ```elixir
  meta = %{
    current_page: if(cursor, do: 2, else: 1),
    previous_page: nil,
    next_page: encode_cursor(next_cursor)
  }
  ```

  There is **no `total_pages` key** (grep confirms `total_pages` is never
  produced anywhere in `lib/` — only consumed). In Elixir, `map.key` dot access
  on a map lacking the key raises `KeyError` *before* the `|| 1` fallback can
  run. `Map.get/2` would return `nil`; `.total_pages` does not.

The render template gates the nav on `<nav :if={@meta && multi_page?(@meta)}>`
(`audit_index_live.ex:216`, `audit_user_live.ex:246`). On the success path
`@meta` is always the non-nil map, so `multi_page?/1` executes on **every**
successful audit page load and raises `KeyError`, crashing the LiveView render.
The only non-crashing path is the error path, which assigns `:meta, nil`.

No existing test exercises the audit pagination nav
(`test/example/.../admin_audit_index_live_test.exs` asserts nothing about
`multi_page`, `Page`, `previous_page`, or `next_page`), so CI does not catch it.

**Fix:** Use safe map access that does not assume the key exists, matching the
actual audit meta shape:

```elixir
defp multi_page?(nil), do: false

defp multi_page?(meta) do
  (Map.get(meta, :total_pages) || 1) > 1 or
    not is_nil(Map.get(meta, :previous_page)) or
    not is_nil(Map.get(meta, :next_page))
end
```

Since the audit meta never carries `total_pages`, the cursor-based signal is
purely `previous_page` / `next_page`; the `total_pages` term can also simply be
dropped. Add a regression test that renders an audit view with a multi-page and
single-page meta and asserts the nav presence/absence so this cannot silently
regress again.

## Warnings

### WR-01: ConfirmDialog Escape/cancel assumes Cancel is always the first focusable — fragile contract for a hook shipped into host-owned markup

**File:** `priv/templates/sigra.install/admin/admin_hooks.js:433-442` (`_cancel`)

**Issue:**
`_cancel()` dispatches a synthetic click on `focusables[0]` inside
`.sg-confirm-dialog`, justified by the comment "Cancel is always the FIRST
button in the dialog." That holds for the two library LiveViews today
(`user_show_live.ex:325`, `branding_live.ex:361` both render Cancel first), but
this hook is copied into host applications that own and customize the overlay
markup. If a host adds a leading close affordance (e.g. an `X` button, or an
`<a href>` link) ahead of Cancel, Escape and scrim-click will fire the wrong
control — potentially the destructive confirm if markup is reordered. The
"first focusable == cancel" coupling is invisible to the host.

**Fix:** Target the cancel action explicitly rather than positionally — e.g.
mark the cancel button with a data attribute the hook keys on
(`[data-sg-confirm-cancel]`) and dispatch the click to that, falling back to
`focusables[0]` only if absent:

```js
var cancel =
  dialog.querySelector("[data-sg-confirm-cancel]") || focusables[0];
if (cancel) cancel.click();
```

Add `data-sg-confirm-cancel` to the Cancel buttons in both LiveViews.

### WR-02: ConfirmDialog focus-return depends on `document.activeElement` at mount, which can be `<body>` after the open round-trip

**File:** `priv/templates/sigra.install/admin/admin_hooks.js:381` (`this._trigger = document.activeElement`)

**Issue:**
The overlay is rendered after a server `phx-click` round-trip
(`open_revoke_session` / `open_restore_defaults`). The hook captures
`document.activeElement` at `mounted()` and returns focus to it in
`destroyed()`. This relies on the trigger button retaining focus across the
round-trip. In Chromium the trigger stays focused (the spec's Gate 5 passes),
but if anything blurs the trigger during the loading window (some browsers blur
on certain DOM patches, or a host's loading overlay steals focus),
`document.activeElement` is `<body>`, and on close focus silently drops to the
top of the document — an APG focus-return violation. There is no fallback.

**Fix:** Capture the trigger more defensively and fall back to a known anchor.
Prefer reading the LiveView-provided trigger if available, and guard against the
body sentinel:

```js
var trigger = document.activeElement;
this._trigger =
  trigger && trigger !== document.body ? trigger : null;
```

and on close, fall back to focusing the admin shell or the first heading when
`_trigger` is null so focus never lands at the document root.

### WR-03: ConfirmDialog Escape handler does not `stopPropagation`, so co-resident document-level Escape listeners also fire

**File:** `priv/templates/sigra.install/admin/admin_hooks.js:398-413`

**Issue:**
`MetricHelp` (L629-632) and `FieldHelp` (L756-759) both register
document-level `keydown` listeners that call `closeAll(null)` on Escape, and
`ConfirmDialog` adds its own document-level Escape handler. When the confirm
dialog is open and the user presses Escape, all three fire. Today this is
benign (the help popovers are simply force-closed), but stacking unscoped
document-level Escape handlers is brittle: any future handler that does more
than a no-op close will run while a modal is open. A modal that calls
`preventDefault()` but not `stopImmediatePropagation()` is not actually
intercepting the key for the rest of the document.

**Fix:** When the dialog consumes Escape, stop further propagation:

```js
if (key === "Escape") {
  event.preventDefault();
  event.stopImmediatePropagation();
  self._cancel();
  return;
}
```

### WR-04: `error_message/1` in branding_live has no total fallback for non-map, non-exception reasons

**File:** `lib/sigra/admin/live/branding_live.ex:710-719`

**Issue:**
The `error_message/1` clauses cover `%{message: binary}`, `%ArgumentError{}`,
and a generic `%{__struct__: _}` exception clause, then a final
`error_message(reason)` catch-all. The struct clause at L713-717 calls
`Exception.message(exception)` inside a `rescue`. If `Branding.save_global` or
`delete_global` returns a struct that is *not* an exception (e.g. a changeset
`%Ecto.Changeset{}`, which has `__struct__` but is not an `Exception`),
`Exception.message/1` raises, the `rescue` catches it, and the user is shown a
raw `inspect/1` of the changeset — leaking internal struct detail into the UI
error notice rather than a human message. This is reachable from the `{:error,
reason}` branches at L426 and L478.

**Fix:** Match changesets explicitly (or guard on `Exception.exception?/1`)
before falling through to `inspect`:

```elixir
defp error_message(%Ecto.Changeset{} = changeset) do
  # traverse_errors / first message
end

defp error_message(%{__struct__: module} = exception) do
  if Kernel.function_exported?(module, :message, 1) or
       Exception.exception?(exception) do
    Exception.message(exception)
  else
    "Could not save auth branding."
  end
end
```

## Info

### IN-01: `user_show_live` confirm dialog `aria-labelledby` target is a `<p>`, not a heading — coherent with branding but worth noting

**File:** `lib/sigra/admin/live/user_show_live.ex:320-322`, `lib/sigra/admin/live/branding_live.ex:354-356`

**Issue:**
Both dialogs label themselves via `aria-labelledby` pointing at a `<p
class="sg-section-heading">`. Using a paragraph styled as a heading (rather than
a real `<h2>`) is accessible for the dialog name (axe passes per Gate 7), but
the dialog title is not in the heading outline. This is consistent across both
overlays, so it is a deliberate pattern, not drift — flagged only so a future
heading-outline audit does not treat it as a regression.

**Fix:** Optional — promote the title to a semantic heading inside the dialog if
a heading-outline pass later requires it; no action needed now.

### IN-02: PAGE-03 spec Gate 3 relies on the dialog having exactly two focusable elements

**File:** `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts:118-156`

**Issue:**
Gate 3's Tab/Shift-Tab wrap assertions use `button:first-of-type` and
`button:last-of-type` and assume precisely two focusable buttons. This couples
the spec to the current two-button dialog markup; if a host or future change
adds a third focusable inside the dialog, the wrap assertions become misleading
(they would still pass on the boundaries but no longer prove full containment of
the middle element). Pairs with WR-01's positional coupling.

**Fix:** Optional — assert containment generically (focus stays within
`.sg-confirm-dialog` across N Tab presses) rather than against fixed
first/last-of-type selectors.

---

_Reviewed: 2026-06-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
