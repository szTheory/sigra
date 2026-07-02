---
status: complete
phase: quick-260602-gzc
plan: 01
subsystem: admin-ui
tags: [admin-shell, scope-chrome, css, tests, ia]
requires: []
provides:
  - "Tenant-marked admin scope chip (Org · <name> + ⌂ glyph) + data-scope chrome hook"
  - "Desktop sidebar nouns (Users/Audit) matching mobile bottom-nav"
  - "Restrained [data-scope=organization] CSS treatment (info-accent), AA in light+dark"
  - "Green admin_shell_test.exs (6/6) pinned to current reshaped markup"
affects:
  - "Playwright admin-checkpoints + demo-showcase PNG baselines (shift intentional, deferred to Stage 8)"
tech-stack:
  added: []
  patterns:
    - "data-scope attribute as CSS hook for scope-aware chrome"
    - "chip-specific tenant formatting isolated from scope_label/1 (raw name preserved everywhere)"
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/admin/components/admin_shell.ex
    - test/example/lib/example_web/components/admin_shell.ex
    - test/example/priv/static/assets/css/app.css
    - test/example/test/example_web/admin_shell_test.exs
decisions:
  - "Used info accent family (not a new token) for org-scope chrome — AA-clean in light + dark"
metrics:
  completed: 2026-06-02
---

# Quick 260602-gzc: Admin-UI Pass 2 Stage 1 (Shell & IA Chrome) Summary

Made tenant-vs-global scope unmistakable in the admin shell via a tenant-marked scope chip
(`Org · <name>` + ⌂ glyph) and a restrained `[data-scope="organization"]` chrome treatment;
fixed the desktop↔mobile sidebar label mismatch (Support users/Audit evidence → Users/Audit);
and rewrote the stale `admin_shell_test.exs` to 6/6 green against the reshaped markup.

## What Changed

### Task 1 — Shell markup (both files, parity-identical)
- Added `data-scope={scope_mode(@admin_scope)}` to the root `<section class="sg-admin-shell">`.
  New private helper `scope_mode/1` → `"organization"` | `"global"`.
- Tenant-marked chip: new `scope_chip_label/1` → `"Org · " <> scope_label(s)` for org scope,
  plain `scope_label/1` otherwise. Rendered in BOTH `scope_switcher` branches (`<summary>` for
  >1 target, `<span>` for ≤1). Added an aria-hidden ⌂ glyph (`sg-scope-pill__tenant`) for the
  org branch only. `scope_label/1`, `scope_targets/1`, breadcrumb, and active-state helpers were
  left untouched — the raw org name stays a clean substring everywhere tests/IA assert it.
- Desktop sidebar relabel: "Support users" → "Users", "Audit evidence" → "Audit". Hrefs,
  `nav_item_class`, and group titles ("Workspace"/"Overviews") unchanged. Mobile bottom-nav was
  already Users/Audit, so desktop now matches mobile + breadcrumb/page-title nouns.

### Task 2 — Org-scope chrome CSS (`app.css`, sg-components layer)
- `.sg-scope-pill__tenant` glyph: `font-size: var(--sg-text-xs); line-height: 1;` (inherits pill color).
- `[data-scope="organization"] .sg-scope-pill`: info-soft bg + info text + inset info ring.
- `[data-scope="organization"] .sg-admin-topbar`: 2px info-derived accent top border (subtle, not a repaint).
- Global (`[data-scope="global"]`) appearance unchanged. No new `!important` (still 7, all pre-existing).
  No separate dark block needed — all referenced tokens have existing dark-mode overrides.

### Task 3 — `admin_shell_test.exs` rewrite (6/6 green)
- Sidebar label assertions: "Support users"/"Audit evidence" → "Users"/"Audit" (hrefs kept exact).
- Stale landing copy "Operate Sigra with confidence" → current "What do you need to do?".
- `sidebar_operations_before_scope?/1` → `sidebar_workspace_before_overviews?/1` (matches real
  `sg-nav-title">Workspace<` before `sg-nav-title">Overviews<`); both call sites updated.
- `bottom_nav_users_before_home?/1` → `bottom_nav_users_first?/1` (asserts `<span>Users</span>`
  precedes `<span>Global</span>` within the `aria-label="Admin bottom nav"` fragment); old
  `btm-nav-label`/"Home" matching removed (those classes/strings no longer exist).
- Org test: replaced the dead `refute html =~ "btm-nav-label\">Home<"` with meaningful
  `assert html =~ "Org · Acme Ops"` (ties test to the new tenant chip; org-name substring preserved).
- Added `data-scope` wiring assertions: `data-scope="organization"` (org test),
  `data-scope="global"` (global test). No unused helpers left; warnings-as-errors clean.

## Verification Results

- **Parity gate:** `sed 's/<%= web_module %>/ExampleWeb/g' <template> | diff - <example>` → no output. **PARITY-OK.**
- **Shell test:** `cd test/example && mix test test/example_web/admin_shell_test.exs` → **6 tests, 0 failures.**
- **Compile:** `MIX_ENV=test mix compile --warnings-as-errors` → exit 0, clean.
  - Note: plain (dev-env) `mix compile` emits a pre-existing `validate_compile_env` mismatch on
    `ExampleWeb.Endpoint` (`:port`/`:server` compile-vs-runtime delta). Unrelated to this stage's
    heex/CSS/test changes — out of scope, not introduced here.
- **No JS touched:** `git diff --name-only` shows no `app.js` / `*_hooks.js` / `priv/playwright` changes.
- **Commit hygiene:** `git show --stat HEAD` and `git diff --name-only HEAD~1 HEAD` list ONLY the
  four scoped files; pre-existing unrelated dirty files were not staged.

## Org-scope accent decision + AA result

- **Chosen accent:** the existing **info family** (`--sg-color-info` / `--sg-color-info-soft`),
  NOT a brand-ring-only approach and NOT a new token. It reads clearly as a distinct "tenant"
  signal vs the global brand-soft chip while staying on-brand.
- **AA (small pill text, ≥4.5:1 required):**
  - **Light:** `#1d4ed8` info text on `#eef2ff` info-soft → **5.99:1** (pass).
  - **Dark:** `#9db8f5` info text on dark info-soft (`rgba(120,150,245,0.16)` composited over panel
    `#1f1d1a` → ~`rgb(45,48,61)`) → **6.62:1** (pass; 8.49:1 directly on panel).
  - Both clear AA comfortably in light and dark.
- **New token introduced:** **None.**

## Baseline-shift flag (intentional, deferred)

Playwright **admin-checkpoints** (chromium / mobile / dark) and **demo-showcase** PNG baselines
WILL shift because of the org-scope recolor (info-tinted chip + 2px topbar accent border) and the
sidebar relabel (Users/Audit). This is **intentional and expected**. Baselines were **NOT**
regenerated in this stage — **Stage 8 owns baseline regeneration**.

## Deviations from Plan

None — plan executed exactly as written. The `tdd="true"` Task 3 was a contract-rewrite against
already-reshaped markup (the behavior pre-existed Stage 1); the rewritten test went green on first
run with no implementation gap, consistent with the plan's framing of "stale assertions to rewrite."

## Self-Check

- Files: all 4 modified files present in `git diff --name-only HEAD~1 HEAD`. FOUND.
- Commit: `2ec5dd6c` present in `git log`. FOUND.

## Self-Check: PASSED
