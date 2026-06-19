# Phase 189: Page Compositions (L3) - Pattern Map

**Mapped:** 2026-06-17
**Files analyzed:** 13 (1 net-new behavior across 5 parity/wiring surfaces; 7 LiveViews graded; 1 Playwright spec; ledger/guard evidence)
**Analogs found:** 13 / 13 (all in-repo; no RESEARCH.md fallback needed)

> This is an L3 page-composition AUDIT phase. Most files are EDITED, not created. The single
> net-new code slice is the `ConfirmDialog` LiveView hook. Everything else is wiring
> (`phx-hook` attr), evidence (Playwright assertions, ledger rows), and at most a one-rule CSS add.

---

## File Classification

| File | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|------|---------|------|-----------|----------------|---------------|
| `priv/templates/sigra.install/admin/admin_hooks.js` | modified (+net-new hook) | hook (JS) | event-driven | `CmdK` hook in same file (L118-367) | exact (same file, same focus-trap concern) |
| `test/example/assets/js/admin_hooks.js` | modified (byte mirror) | hook (JS) | event-driven | canonical `admin_hooks.js` | byte-identical mirror |
| `priv/templates/sigra.install/admin/sigra_admin.css` | modified (≤1 rule) | config (CSS) | n/a | `@layer sg-components` `.sg-confirm-*` block (L637-675) | exact |
| `test/example/priv/static/assets/sigra_admin.css` | modified (byte mirror) | config (CSS) | n/a | canonical `sigra_admin.css` | byte-identical mirror |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` | modified (byte mirror) | config (CSS) | n/a | canonical `sigra_admin.css` | byte-identical mirror |
| `lib/sigra/admin/live/user_show_live.ex` | modified (hook attr + IA/rhythm) | LiveView (Detail archetype) | request-response + patch | existing confirm markup L315-333 | exact (self-analog) |
| `lib/sigra/admin/live/branding_live.ex` | modified (hook attr + IA) | LiveView (PAGE-04 customizer) | request-response | `user_show_live` confirm block | exact role-match |
| `lib/sigra/admin/live/index_live.ex` | modified (IA/rhythm evidence) | LiveView (Overview archetype) | request-response | self / design contract | self-analog |
| `lib/sigra/admin/live/organization_live.ex` | modified (IA evidence) | LiveView (Overview instance, D-04) | request-response | `index_live.ex` | exact role-match |
| `lib/sigra/admin/live/users_index_live.ex` | modified (IA/pagination evidence) | LiveView (List archetype) | request-response + patch | self (`multi_page?` guard L513-517) | self-analog |
| `lib/sigra/admin/live/audit_index_live.ex` | modified (IA evidence) | LiveView (PAGE-04 explorer) | request-response + patch | `users_index_live.ex` | role-match |
| `lib/sigra/admin/live/audit_user_live.ex` | modified (IA/breadcrumb evidence) | LiveView (PAGE-04 explorer leaf) | request-response | `user_show_live.ex` (breadcrumbs) | role-match |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` | modified (+modal assertions) | test (E2E) | event-driven | existing checkpoint asserts L78-292 | exact (self-analog) |
| `guides/reference/admin-quality-ledger.md` | modified (ratify 6 L3 rows) | doc/ledger | n/a | existing L3 rows | self-analog |

---

## Pattern Assignments

### `admin_hooks.js` — net-new `ConfirmDialog` hook (hook, event-driven)

**Analog:** `CmdK` hook, `priv/templates/sigra.install/admin/admin_hooks.js` L118-367.

This is the ONE net-new code slice. The `CmdK` hook is the closest analog because it already
implements every APG behavior the new hook needs (focus trap, Escape, focus-restore,
outside-click), but it BUILDS its own DOM. `ConfirmDialog` must instead attach to existing
server-rendered `sg-confirm-overlay` markup that is conditionally shown via `:if`. Per D-06 /
UI-SPEC line 224, the new hook MUST be a separate named hook — do NOT modify `CmdK` (it is
ratified). Planner may share a private `trapFocus` helper or duplicate-and-specialize.

**1. Module-level focusable selector to reuse verbatim** (L115-116):
```javascript
var FOCUSABLE =
  'a[href], button:not([disabled]), input, [tabindex]:not([tabindex="-1"])';
```

**2. Focus-trap pattern to copy** (`CmdK.trapFocus`, L316-328) — note it queries `this.dialog`,
the new hook should query the `.sg-confirm-dialog` element:
```javascript
trapFocus: function (event) {
  var focusables = this.dialog.querySelectorAll(FOCUSABLE);
  if (!focusables.length) return;
  var first = focusables[0];
  var last = focusables[focusables.length - 1];
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
},
```

**3. Escape-handling + outside-click pattern** (from `CmdK.open` L196-202 and
`handleKeydown` L263-267 / L301-303):
```javascript
// outside-click (optional enhancement per D-08, not a gate):
this._onOverlayClick = function (event) {
  if (event.target === overlay) { self.close(); }
};
overlay.addEventListener("click", this._onOverlayClick);

// Escape (required gate):
if (key === "Escape") { event.preventDefault(); this.close(); return; }
if (key === "Tab") { this.trapFocus(event); }
```

**4. Focus-restore-to-trigger pattern** (`CmdK.close` L335-354). KEY DIFFERENCE: `CmdK` restores
to `this.el` (the persistent trigger). The confirm overlay is conditionally rendered via `:if`,
so the hook's `el` IS the overlay and is destroyed on close. Per UI-SPEC L226: capture
`document.activeElement` at `mounted()` time (overlay shown) and restore on `destroyed()`
(overlay hidden). Adapt the restore call:
```javascript
// CmdK does (trigger persists): this.el.focus();
// ConfirmDialog must instead, in mounted(): this._trigger = document.activeElement;
// and in destroyed(): if (this._trigger && this._trigger.focus) this._trigger.focus();
```

**5. Lifecycle + cleanup pattern** (`CmdK` `mounted`/`destroyed`/`disconnected`, L120-151,
L356-366). The confirm hook uses `mounted()` = dialog shown (per `:if`), `destroyed()` = dialog
hidden. Initial focus per D-07 / UI-SPEC L208: focus first focusable inside `.sg-confirm-dialog`,
or the Cancel button for a destructive confirm (Cancel is rendered first in DOM —
`user_show_live.ex` L325, `branding_live.ex` L361 — so "first focusable" already lands on Cancel).

**6. Registration pattern** (L1009-1014) — add the new hook to `window.SigraAdminHooks`:
```javascript
window.SigraAdminHooks = {
  AuthBrandingPreview: AuthBrandingPreview,
  CmdK: CmdK,
  ConfirmDialog: ConfirmDialog,   // <-- add (alphabetical to match existing order)
  CopyToClipboard: CopyToClipboard,
  ThemeSwitch: ThemeSwitch,
};
```

**File-style constraints (from header L1-21):** plain JS, NO import/export (runs unbundled when
pasted into the app.js readable tail), IIFE-scoped `(function () { "use strict"; ... })()`. The
new hook must follow this — no ESM, no arrow-function-only patterns (existing code uses
`function`). Never throw from a click/keydown handler (see L387-395 swallow-pattern).

---

### `user_show_live.ex` — Detail archetype + hook wiring (LiveView)

**Analog:** the file's own existing confirm block, L315-333 (already migrated to `sg-confirm-*`;
the "still uses `<dialog>`" note is STALE per D-06).

**Existing confirm markup to wire** (L315-333) — add `phx-hook="ConfirmDialog"` + `id` to the
overlay element (LiveView hooks require an `id`):
```elixir
<div :if={@confirm_action} class="sg-confirm-overlay" role="presentation">
  <section
    class="sg-confirm-dialog"
    role="dialog"
    aria-modal="true"
    aria-labelledby="user-session-confirm-title"
  >
    <p id="user-session-confirm-title" class="sg-section-heading">{@confirm_action.title}</p>
    <p class="sg-text-sm" style="margin-top: var(--sg-space-3);">{@confirm_action.copy}</p>
    <div class="sg-confirm-dialog__actions">
      <button type="button" phx-click="cancel_confirm" class="sg-btn sg-btn--ghost sg-btn--sm">
        {@confirm_action.cancel_label}
      </button>
      <button type="button" phx-click="confirm_action" class="sg-btn sg-btn--danger sg-btn--sm">
        {@confirm_action.confirm_label}
      </button>
    </div>
  </section>
</div>
```
Wiring change: add `id="user-session-confirm-overlay" phx-hook="ConfirmDialog"` to the
`:if`-gated `<div class="sg-confirm-overlay">`. Cancel renders first (correct initial-focus
target per D-07). `aria-labelledby` id already matches the `<p id=...>` (UI-SPEC L214 verify).

**Destructive trigger pattern** (L178-187) — this is the element the hook must return focus to,
and the Playwright "click trigger" target:
```elixir
<button
  type="button"
  phx-click="open_revoke_session"
  phx-value-token={Base.url_encode64(session.hashed_token, padding: false)}
  class="sg-btn sg-btn--danger sg-btn--sm"
>
  Revoke session
</button>
```

**Server-side close events already present** (do not change): `cancel_confirm` (L65),
`confirm_action` (L69), open via `open_revoke_session`. The hook only adds client behavior; close
remains server-driven via `:if` toggling `@confirm_action` to nil.

**Inline-style spacing exception** (L323 `style="margin-top: var(--sg-space-3);"`) is a documented
prior-phase exception per UI-SPEC L78 — do NOT add new inline spacing.

---

### `branding_live.ex` — PAGE-04 customizer + same hook (LiveView)

**Analog:** identical `sg-confirm-*` block, L349-368 (gated by `@restore_defaults_open?`).

Apply the SAME wiring as `user_show_live`: add `id` + `phx-hook="ConfirmDialog"` to the
`:if={@restore_defaults_open?}` overlay `<div>`. Markup (L349-368):
```elixir
<div :if={@restore_defaults_open?} class="sg-confirm-overlay" role="presentation">
  <section class="sg-confirm-dialog" role="dialog" aria-modal="true"
           aria-labelledby="restore-defaults-title">
    <p id="restore-defaults-title" class="sg-section-heading">Restore defaults?</p>
    <p class="sg-text-sm" style="margin-top: var(--sg-space-3);">This removes the saved...</p>
    <div class="sg-confirm-dialog__actions">
      <button type="button" phx-click="cancel_restore_defaults"
              class="sg-btn sg-btn--ghost sg-btn--sm">Cancel</button>
      ...
```
Close event: `cancel_restore_defaults` (vs `cancel_confirm` in user_show) — the hook is generic
and must not hardcode the close event name; it relies on `:if`-driven `destroyed()` for focus
restore, not on pushing a specific event. (Escape can `pushEventTo` a phx-click-equivalent, OR
simply let the existing Cancel button receive a synthetic click — planner decides; do NOT bake a
page-specific event name into the shared hook.)

---

### `users_index_live.ex` — List archetype + honest pagination (LiveView)

**Analog:** self. The honest-pagination guard already exists — Phase 189 ratifies it as evidence,
does not rewrite it.

**`multi_page?` guard pattern** (L513-517) — the `show_pagination?`-style honesty guard cited in
D-09 / UI-SPEC L175:
```elixir
defp multi_page?(nil), do: false

defp multi_page?(meta) do
  (meta.total_pages || 1) > 1 or not is_nil(meta.previous_page) or not is_nil(meta.next_page)
end
```

**Honest pagination render guards** (L348-379) — single-page case renders an all-results label,
NOT a phantom "page 1 of 1" nav:
```elixir
<.empty_state :if={@rows == []} title="No users match this view">
...
<%!-- single-page: all-results label, no nav --%>
<... :if={@meta && @rows != [] && not multi_page?(@meta)}>
<%!-- multi-page: real nav --%>
<nav :if={@meta && multi_page?(@meta)} class="sg-cluster sg-cluster--between">
  ...
  <span class="sg-muted">&middot; Page {@meta.current_page || 1} of {@meta.total_pages || 1}</span>
```
`audit_index_live.ex` and `audit_user_live.ex` (PAGE-04) must follow the SAME guard pattern
(UI-SPEC L254). Filter-apply is a PATCH: focus stays on the filter input/submit, NOT reset to h1
(UI-SPEC L179).

---

### `admin-checkpoints.spec.ts` — ratification lane + new modal assertions (test, E2E)

**Analog:** the file's existing checkpoint assertions, L78-292.

**Role-selector + no-sleep assertion style to copy** (L78-86, L214-219):
```typescript
await page.getByRole('link', { name: 'Open user' }).first().click();
await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
...
await expect(
  page.getByRole('button', { name: 'Revoke session' }).first(),
).toBeVisible();
```

**Screenshot + axe gate helper to reuse** (L114-148) — wcag2a/wcag2aa scoped, viewport-only,
project-aware diff tolerances. New modal assertions must run axe WHILE the dialog is open
(UI-SPEC L349):
```typescript
async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  ...
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}
```

**New modal-interaction assertions to ADD** (per UI-SPEC L339-349; deterministic, role-based,
no sleeps). Pattern: click the `Revoke session` trigger, then assert focus, Tab-wrap, Escape, and
focus-return using `page.evaluate(() => document.activeElement...)` and `page.keyboard.press`.
Planner decides (D-13) whether to extend this spec or add a focused interaction spec; either way
follow the existing role-selector + `toHaveURL`/`toBeVisible` readiness-gate idiom (no `waitForTimeout`).

**Snapshot recapture path** (D-12, UI-SPEC L351): intended visual deltas go through
`scripts/ci/snapshot-recapture-gate.sh` with the canary slug untouched
(`scripts/ci/snapshot-canary-guard.sh`).

---

## Shared Patterns

### Three-surface CSS byte-parity (D-10/D-11 — HARD CONSTRAINT)
**Source rule:** 187-CONTEXT.md D-01..D-04, carried into 189 D-10.
**Apply to:** every CSS edit.
The three files are currently **byte-identical** (verified clean baseline). Any new rule (only
`body.sg-body-scroll-locked { overflow: hidden; }` is anticipated, UI-SPEC L232-235) lands in
`@layer sg-components` of the canonical template, then is copied verbatim to both mirrors:
```
priv/templates/sigra.install/admin/sigra_admin.css            (canonical)
test/example/priv/static/assets/sigra_admin.css               (mirror — must match)
test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css  (mirror — must match)
```
**Analog block for a new `@layer sg-components` rule** (sigra_admin.css L637-675) — tokens-only,
no raw hex/px:
```css
@layer sg-components {
  .sg-confirm-overlay {
    position: fixed;
    inset: 0;
    z-index: var(--sg-z-modal);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--sg-space-4);
    background: color-mix(in oklab, var(--sg-color-ink) 46%, transparent);
  }
  /* new rule lands beside this, same layer, var(--sg-*) only */
}
```
Cascade-layer declaration order is fixed (L15): `@layer sg-base, sg-components, sg-overrides;`.
Leaving CSS/JS example-only reproduces the Phase 187/188 DIST-05 failure (escalation-worthy).

### Two-surface JS byte-parity (D-10)
**Source rule:** 189 D-10 / UI-SPEC L45-52.
**Apply to:** every `admin_hooks.js` edit.
Canonical + example mirror are currently **byte-identical** (verified). The new `ConfirmDialog`
hook lands in the canonical template and is copied verbatim to the example:
```
priv/templates/sigra.install/admin/admin_hooks.js   (canonical)
test/example/assets/js/admin_hooks.js               (mirror — must match)
```

### Focus management (WAI-ARIA APG Dialog behavior, D-07)
**Source:** `CmdK` hook, `admin_hooks.js` L316-354.
**Apply to:** the new `ConfirmDialog` hook on both `user_show_live` and `branding_live`.
Required gates: initial focus into dialog (Cancel for destructive), Tab/Shift-Tab containment,
Escape closes + returns focus, focus returns to trigger on any close, `role="dialog"` +
`aria-modal="true"` + `aria-labelledby` (already in markup — verify, do not remove). Score the
BEHAVIOR not the technique (JS focus-wrap is APG-conformant).

### Honest affordances (D-09)
**Source:** `users_index_live.ex` `multi_page?` (L513-517) + render guards (L348-379).
**Apply to:** `users_index_live`, `audit_index_live`, `audit_user_live` pagination. No phantom
"page 1 of 1" with disabled controls — hide the nav entirely when one page.

### Page-level a11y landmarks + heading order (PAGE-05)
**Source:** existing admin shell + design contract.
**Apply to:** all 6 graded LiveViews. `<main>` wraps content, `<nav>` for breadcrumbs/tabs,
`<h1>` page title / `<h2>` section headings (no skips), axe wcag2a+wcag2aa = 0 violations across
8 checkpoints × 3 projects.

### Monotonic ledger guard (D-12)
**Source:** `scripts/ci/quality-ledger-monotonic.sh` + `guides/reference/admin-quality-ledger.md`.
**Apply to:** the 6 L3 rows (`index-live`, `organization-live`, `users-index-live`,
`user-show-live`, `audit-index-live`, `audit-user-live`). Evidence-fill and ratify; never
decrease a tier (Tier 1 floor).

---

## No Analog Found

None. Every file has a strong in-repo analog. The CSS scroll-lock rule
(`body.sg-body-scroll-locked`) is net-new content but its placement/style analog is the existing
`@layer sg-components` `.sg-confirm-*` block; no RESEARCH.md fallback is required.

---

## Metadata

**Analog search scope:** `lib/sigra/admin/live/`, `priv/templates/sigra.install/admin/`,
`test/example/{assets/js,priv/static/assets,priv/playwright/tests}/`,
`test/fixtures/install_golden/tree/priv/static/assets/`, `scripts/ci/`, `guides/reference/`.
**Files scanned:** 13 read/inspected; parity baselines verified byte-identical via `diff -q`.
**Pattern extraction date:** 2026-06-17
**Parity baseline state at mapping time:** JS (canonical↔example) IDENTICAL; CSS (canonical↔example↔golden) IDENTICAL. Edits must keep all surfaces in lockstep.
