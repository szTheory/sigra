# Vaultr demo polish: kicker spacing + click-to-copy credentials

## Context

Two small UX refinements on the Vaultr demo app (`test/example`, build-free, hand-authored
CSS/JS), both surfaced from `http://127.0.0.1:4011/`:

1. **Spacing bug.** On the homepage, the `<p class="vt-kicker">Seeded evidence</p>` header
   sits flush against the `.vt-metric-grid` stat cards above it — no section breathing room.
   Cause: `.vt-kicker` is `margin: 0`, `.vt-metric-grid` has no bottom margin, and the
   `.vt-panel__header` that wraps the kicker only has `margin-bottom` (no top margin) because
   it normally sits at a panel's top. Here it's the *second* block in the panel, after the grid.

2. **Credentials should copy on click.** Clicking a credential chip
   (`<code class="vt-code">admin@demo.vaultr.test</code>`, passwords, etc.) should copy it to
   the clipboard with a familiar, no-reflow confirmation — on the homepage *and* on
   `/demo/credentials`. KISS, principle of least surprise.

**Key reuse finding:** the copy UX already exists and already runs on every page. The shared
hooks IIFE (`test/example/assets/js/admin_hooks.js`, mirrored into the served
`test/example/priv/static/assets/js/app.js`) installs a global document-level click delegate
`installCopyDelegate()` + a `showToast("Copied")` helper + `.sg-toast-region`/`.sg-toast` CSS.
It's just scoped to `.sg-admin-shell code.sg-code`. So this is mostly: **broaden one selector
to also match `code.vt-code`** + a `cursor: copy` affordance — no new clipboard/toast code, no
reflow (toast is `position: fixed`).

Outcome: tidier homepage rhythm, and every `.vt-code` chip (emails, passwords, paths) copies on
click with a corner "Copied" toast — consistent across both demo pages, reusing shipped infra.

## Changes

### 1. Kicker section spacing — `test/example/priv/static/assets/css/app.css`
Add a surgical adjacency rule after the `.vt-panel__header` block (~line 606). Only a panel
header that *directly follows* a metric grid gets the extra top margin — panel headers at the
top of a panel are untouched:
```css
.vt-metric-grid + .vt-panel__header {
  margin-top: var(--sg-space-6);
}
```
Rationale: the header's own `margin-bottom` is `--sg-space-4` (16px); a `--sg-space-6` (24px)
top margin makes the header sit closer to the content it labels than to the grid above —
correct hierarchy for a section break. Verify live; bump to `--sg-space-8` if it still reads
tight.

### 2. Copy affordance on `.vt-code` — same `app.css` (`.vt-code` block, ~lines 341–357)
Add a clickable affordance + restrained hover so the chip reads as interactive (mirrors the
admin `.sg-code` "click to copy" affordance):
```css
  cursor: copy;
```
plus a hover nudge:
```css
.vt-code:hover {
  background: color-mix(in oklab, var(--vt-color-accent-soft) 90%, transparent);
}
```

### 3. Broaden the copy delegate — TWO files kept in sync (build-free JS gotcha)
Both files carry the same `installCopyDelegate()`; edit both identically:
- Source: `test/example/assets/js/admin_hooks.js` (lines ~501 and ~524)
- Served:  `test/example/priv/static/assets/js/app.js` (lines ~8280 and ~8298)

Change the match selector and the affordance-label selector from
`".sg-admin-shell code.sg-code"` to `".sg-admin-shell code.sg-code, code.vt-code"` in both
places. Admin behavior is unchanged; public Vaultr `.vt-code` chips become copyable. Update the
doc comment atop `admin_hooks.js` (the CopyToClipboard bullet, ~line 10) to note it also covers
public demo `.vt-code` chips. (The `.sg-toast` shows globally — `--sg-*` tokens load on every
page — so no new toast styling is needed.)

### 4. Make the `/demo/credentials` email copyable — `test/example/lib/example_web/live/demo/credentials_live.ex` (line 82)
The password is already `<code class="vt-code">` but the email is plain text. Wrap it for
consistency with the homepage (which already wraps both), so the delegate picks it up:
```heex
<td><code class="vt-code">{c.email}</code></td>
```
(Text content is unchanged, so existing `=~ email` test assertions still pass.)

No changes to installer templates, the real login, admin surfaces, or the `.sg-code` admin path.

## Verification

**Live (MCP Playwright on `http://127.0.0.1:4011/`, demo already booted via `scripts/uat/up.sh`):**
1. Homepage: confirm clear breathing room above "Seeded evidence" (vs the previous tight flush).
2. Click an email and a password `.vt-code` chip → a corner "Copied" toast appears (no layout
   shift); `navigator.clipboard.readText()` equals the chip text. Cursor shows the copy affordance.
3. `/demo/credentials`: same — clicking an email cell and a password chip copies + toasts.
4. `/users/log_in` and an admin page still copy `.sg-code` as before (regression check).

**Automated (extend `test/example/priv/playwright/tests/demo-showcase.spec.ts`):**
- In the home-page test, grant clipboard permission, click a `.vt-code` credential, assert the
  `.sg-toast` ("Copied") becomes visible and `navigator.clipboard.readText()` matches the chip.
- Assert `getComputedStyle(panelHeaderAfterGrid).marginTop` is non-zero (spacing applied).
- Keep the existing font guard green.
Run: `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://127.0.0.1:4011 npx playwright
test --project=demo-showcase-chromium -g "home page orients evaluators"`.

**Elixir tests (cosmetic email wrap is the only server-side change):**
`cd test/example && mix test --include example_app` (covers branding + page/credentials tests).

## Notes
- Pure demo cosmetics + one shared-JS selector broadening; no security/installer surface.
- Route execution through `/gsd-quick`; verify live before committing (build-free JS must be
  hand-propagated source→served, and CSS must be confirmed to actually parse in-browser per the
  known `app.css` orphan-comment gotcha).
- Click-only copy matches the shipped admin `.sg-code` pattern (no keyboard handler) — parity,
  not a regression; revisit only if keyboard-copy is requested.
