---
status: complete
phase: quick-260602-ikd
plan: 01
subsystem: admin-ui
tags: [admin-ui, cmd-k, command-palette, clipboard, motion, accessibility]
requires: [ADMIN-PASS2-STAGE0, ADMIN-PASS2-STAGE6]
provides: [ADMIN-PASS2-STAGE7]
affects: [example-bundle, admin-shell, install-template]
key-files:
  created:
    - test/example/assets/js/admin_hooks.js
    - priv/templates/sigra.install/admin/admin_hooks.js
  modified:
    - test/example/priv/static/assets/css/app.css
    - priv/templates/sigra.install/admin/components/admin_shell.ex
    - test/example/lib/example_web/components/admin_shell.ex
    - test/example/priv/static/assets/js/app.js
metrics:
  completed: 2026-06-02
  tasks: 4
  files: 6
  commits: 3
---

# Quick 260602-ikd — Admin-UI Pass 2 Stage 7 (Cmd-K palette + copy-to-clipboard + motion) Summary

Self-contained client-side Cmd-K command palette and click-to-copy id chips for the admin
console: a plain-JS `CmdK` + `CopyToClipboard` hook pair (window.SigraAdminHooks) injected into
the hand-maintained example bundle, a hidden-until-revealed scope-aware trigger in the
parity-identical admin shell (both copies), `sg-cmdk*` overlay CSS reusing `--sg-z-modal` and
Stage-0 `sg-toast`, and a documented-optional `admin_hooks.js` install template.

## What changed

- **Task 1 — `sg-cmdk*` overlay CSS** (`test/example/priv/static/assets/css/app.css`): new BEM
  section in `@layer sg-components` (`.sg-cmdk` scrim → `--sg-z-modal`, `.sg-cmdk__dialog`,
  `__input`, `__list`, `__item` + `.is-active`/`[aria-selected]`, `__empty`, `__trigger`
  display:none with `.is-ready` reveal, `__trigger-kbd`). Entrance is a keyframed
  `.sg-cmdk--enter` animation on the dialog animating **only** opacity + transform `scale(0.96)→1`
  over `--sg-motion-pop` (180ms) `--sg-ease-out`; the active-row highlight has **no** transition
  (keyboard/nav path is instant). Added click-to-copy `cursor:pointer` + hover tint to
  `.sg-admin-shell code.sg-code` (narrow admin-only scope). No new `!important`; every value
  references an existing token.
- **Task 2 — hidden Cmd-K trigger** (both `admin_shell.ex` files, byte-identical): a real
  `<button type="button" id="admin-cmdk" phx-hook="CmdK" class="sg-cmdk__trigger">` added inside
  the topbar inner cluster (wrapped with the existing "Exit to global" link in a `sg-cluster--2`),
  with `aria-label="Open command palette"`, visible "Search… ⌘K" hint, and scope-aware
  `data-users-href/data-audit-href/data-overview-href/data-overview-label` stamped from the
  existing private helpers (no client-side scope logic). Hidden by default; the hook adds
  `.is-ready` on mount (graceful degradation in hosts without the hook). No asserted markup
  changed.
- **Task 3 — plain-JS hooks source** (`test/example/assets/js/admin_hooks.js` +
  `priv/templates/sigra.install/admin/admin_hooks.js`, content-identical): IIFE, NO import/export,
  assigns `window.SigraAdminHooks = { CmdK, CopyToClipboard }`.
  - `CmdK`: `mounted()` reveals trigger + binds document ⌘K/Ctrl-K toggle + trigger click;
    `open()` builds `role=dialog aria-modal` + `role=listbox`/`option` DOM with a free-text input,
    moves focus in, `.sg-cmdk--enter` entrance; keyboard = ArrowUp/Down move selection
    (aria-selected + `.is-active`, no animation), Enter activates the highlighted command **or**
    free-text → `usersHref + (?|&) + q=<encoded>`, Esc/scrim-click close + restore focus to
    trigger; Tab/Shift+Tab focus-trapped; navigation via `window.location.assign` (no server
    round-trip); `destroyed()`/`disconnected()` tear down listeners + overlay.
  - `CopyToClipboard`: delegated document click listener gated to `.sg-admin-shell code.sg-code`
    → `navigator.clipboard.writeText` (promise rejection swallowed, never throws) + transient
    Stage-0 `sg-toast` "Copied" toast (auto-creates `.sg-toast-region` if absent, enter→leave→
    remove). Installs once (`window.__sigraCopyDelegateInstalled` guard); also sets
    `title="Click to copy"` on chips. No per-LiveView markup edits.
- **Task 4 — bundle injection** (`test/example/priv/static/assets/js/app.js`): two surgical edits
  only — (a) bracketed `// Sigra admin hooks:start/end` plain-JS block (mirror of Task 3 source)
  inserted between `// Sigra passkeys:end` and `// LiveSocket initializer`; (b) two entries added
  to the existing `hooks:` map — `CmdK: (window.SigraAdminHooks||{}).CmdK` and
  `CopyToClipboard: (window.SigraAdminHooks||{}).CopyToClipboard`. Minified vendor and existing
  passkey entries untouched.

## Gate results

| Gate | Result |
|------|--------|
| `node --check` app.js | **PASS** (re-checked after each edit) |
| `node --check` admin_hooks.js (example + template) | **PASS**, files byte-identical (`diff` clean) |
| Shell parity `sed \| diff` | **CLEAN** (byte-for-byte) |
| `mix compile --warnings-as-errors` (root) | **CLEAN** (exit 0) |
| `mix compile --warnings-as-errors` (example, `MIX_ENV=test`) | **CLEAN** (exit 0) |
| Admin ExUnit (`admin_shell_test` + `admin_*_live_test`) | **25 tests, 0 failures** |

Grep confirmations: app.js `SigraAdminHooks`×4, `CmdK: (window.SigraAdminHooks`×1,
`PasskeyRegister: passkeyRuntime`×1 (preserved); shell `phx-hook="CmdK"`×1; CSS
`sg-cmdk__dialog|list|trigger` count 7.

## Commits

- `87e9d375` feat(admin-ui): Cmd-K palette overlay CSS + hidden trigger in shell (Stage 7)
- `ba364d71` feat(admin-ui): plain-JS CmdK + CopyToClipboard hooks source + install template (Stage 7)
- `1452c5fd` feat(admin-ui): inject admin hooks into committed example bundle (Stage 7)

Each `git show --stat` lists only intended files. Bundle injection is its own commit so it can
be reverted independently.

## Deviations from Plan

None — plan executed exactly as written. The install template was kept **byte-identical** to the
example source (the Task 3 verify gate requires `diff` to be clean); the shared top-of-file
comment documents the hooks and the optional-wiring nature, satisfying both the "documented
optional" requirement and the identical-content gate.

## Flags

- **Bundle hand-edited, no build step.** `node --check` (run after every app.js edit) plus the
  orchestrator boot/⌘K smoke test are the safety net. Task ordering isolated the bundle edit
  (Task 4 last) against a source already validated in Task 3.
- **Cmd-K is example-only this stage.** The host template ships at
  `priv/templates/sigra.install/admin/admin_hooks.js`, but installer/mix-task wiring is a
  documented follow-on (no installer change this stage). Hosts add the two hooks to their
  LiveSocket `hooks:` map exactly as the example bundle does.
- **Baselines shift for Stage 8.** The trigger is `display:none` until JS adds `.is-ready`, so
  headless screenshot/MCP runs may or may not show it depending on JS execution; note for the
  Stage-8 baseline regeneration.
- **Scope C deferred** (optional flash→sg-toast restyle + animated "More filters" collapse). The
  bulk of motion is already delivered by Stage-0 tokens and Tasks 1–4; Scope C was not pulled in
  to keep the stage tight and within the motion budget. Track for a later stage if desired.
- **Note (not introduced by this work):** running `mix compile` for the example in the *dev*
  env reports a `validate_compile_env` mismatch on `ExampleWeb.Endpoint` (port 4011 / `server:
  true` baked into the running dev server's `_build` vs. current runtime env). This is a
  pre-existing dev-server artifact unrelated to Stage 7 (CSS/HEEx/JS only); the test-env compile
  and the admin suite are clean.

## Self-Check: PASSED

- Created files exist: `test/example/assets/js/admin_hooks.js`,
  `priv/templates/sigra.install/admin/admin_hooks.js` — FOUND.
- Modified files committed across `87e9d375`, `ba364d71`, `1452c5fd` — all present in
  `git log`.
- Admin ExUnit green (25/0); node --check + parity + warnings-as-errors gates all pass.
