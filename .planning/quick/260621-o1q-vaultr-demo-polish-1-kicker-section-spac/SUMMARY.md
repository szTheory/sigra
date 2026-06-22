---
quick_id: 260621-o1q
status: complete
date: 2026-06-21
---

# Vaultr demo polish: kicker spacing + click-to-copy credentials

## What changed

Two small UX refinements on the build-free Vaultr demo app (`test/example`),
reusing existing infrastructure (no new clipboard/toast code):

1. **Section spacing above "Seeded evidence."** The `.vt-panel__header` that
   follows the homepage stat grid was flush against it (grid has no bottom
   margin; `.vt-kicker` is `margin: 0`). Added a surgical adjacency rule
   `.vt-metric-grid + .vt-panel__header { margin-top: var(--sg-space-6) }` (24px) —
   only a header that *directly follows* a metric grid; panel-top headers untouched.

2. **Click-to-copy on `.vt-code` credential chips** (homepage + `/demo/credentials`).
   The shared hooks IIFE already installs a global document-level click delegate
   `installCopyDelegate()` + `showToast("Copied")` + `.sg-toast` CSS on every page;
   it was scoped to `.sg-admin-shell code.sg-code`. Broadened the match + label
   selectors to `".sg-admin-shell code.sg-code, code.vt-code"` in BOTH the source
   (`assets/js/admin_hooks.js`) and the hand-maintained served bundle
   (`priv/static/assets/js/app.js`). Added `cursor: copy` + a hover nudge to
   `.vt-code`. Toast is `position: fixed` → no layout reflow. Wrapped the
   `/demo/credentials` email cell in `<code class="vt-code">` for parity with the
   homepage (text unchanged).

## Files
- `test/example/priv/static/assets/css/app.css` — adjacency spacing rule; `.vt-code` cursor + hover
- `test/example/assets/js/admin_hooks.js` — delegate selector (match + label) + doc comment
- `test/example/priv/static/assets/js/app.js` — served mirror of the same selector change
- `test/example/lib/example_web/live/demo/credentials_live.ex` — email wrapped in `code.vt-code`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts` — spacing + clipboard/toast assertions

## Verification
- Extended demo-showcase home-page Playwright spec **passed** live against `:4011`:
  24px section break, `cursor: copy`, "Copied" toast visible, `clipboard.readText()`
  matches the clicked chip text.
- Live MCP checks: header `margin-top: 24px` (24px gap grid→header), `.vt-code`
  `cursor: copy` + `title="Click to copy"` (homepage); `/demo/credentials` email is
  now a `code.vt-code` chip with `cursor: copy`. (Title hint is stripped by the
  LiveView morphdom patch on the credentials page; `cursor: copy` + working click
  remain — acceptable, copy is click-based not title-dependent.)
- `mix test --include example_app` (page_controller + session_controller + branding):
  **16 tests, 0 failures.**

## Notes / follow-ups discovered
- Persona post-login UX gap surfaced mid-task (separate, larger scope): the homepage
  lures every persona to "Open Sigra Admin"; non-admins bounce through login to a raw
  plain-text 403 (`auth_error_handler.ex`). `signed_in_path` → `/`. Header is not
  auth-aware (always "Sign in"). Being scoped as a follow-on — NOT part of this task.
