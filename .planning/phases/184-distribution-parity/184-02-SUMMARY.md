---
phase: 184-distribution-parity
plan: "02"
subsystem: installer-pipeline
tags: [css, admin, distribution, installer, golden-fixture, parity-tests]
dependency_graph:
  requires:
    - "184-01 (priv/templates/sigra.install/admin/sigra_admin.css)"
  provides:
    - lib/sigra/install/features/admin.ex (files/1 CSS tuple)
    - priv/templates/sigra.install/admin/layouts_admin_injection.ex (link tag)
    - test/example/priv/static/assets/sigra_admin.css (byte-guarded example copy)
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css (golden fixture)
    - DIST-05 byte-parity gate in admin_test.exs
  affects:
    - Plans 184-03 (Playwright smoke runs against wired stylesheet)
tech_stack:
  added: []
  patterns:
    - auth-pattern analog (sigra_admin.css mirrors sigra_auth.css install pattern)
    - byte-guarded example copy (DIST-05 merge-blocking parity gate)
    - golden fixture update (STDOUT.txt + layouts.ex for new CSS asset)
key_files:
  created:
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
  modified:
    - lib/sigra/install/features/admin.ex
    - priv/templates/sigra.install/admin/layouts_admin_injection.ex
    - test/example/priv/static/assets/css/app.css
    - test/fixtures/install_golden/STDOUT.txt
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/layouts.ex
    - test/sigra/install/features/admin_test.exs
decisions:
  - Used Path.join/3 in admin.ex (consistent with existing tuples) but string literals in test assertions (RESEARCH.md Pitfall 6)
  - The layouts_admin injection link tag uses body-level placement (before <.admin_shell>) matching the sigra_auth.css auth precedent pattern
  - Golden fixture layouts.ex updated to match the injected output from layouts_admin_injection.ex read_template!
  - Python-based selective transformation used to remove sg-* from app.css while preserving vt-* VAULTR HOST APP section structure
metrics:
  duration: ~30 minutes
  completed: "2026-06-14T05:26:41Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 6
---

# Phase 184 Plan 02: Distribution Wiring + Parity Gates — Summary

**One-liner:** Wire `sigra_admin.css` into the installer pipeline (DIST-02), inject the body-level `<link>` tag into generated admin layouts (DIST-03), register byte-guarded example and golden-fixture copies (DIST-04, DIST-05), and add merge-blocking ExUnit parity tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Wire admin.ex files/1 (DIST-02) and layouts_admin_injection.ex link (DIST-03) | 8719eaaf | lib/sigra/install/features/admin.ex, priv/templates/sigra.install/admin/layouts_admin_injection.ex |
| 2 | Example copy + app.css reduction + golden fixture + DIST-05 parity tests | 575c190b | test/example/priv/static/assets/sigra_admin.css, test/example/priv/static/assets/css/app.css, test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css, test/fixtures/install_golden/STDOUT.txt, test/fixtures/install_golden/tree/lib/.../layouts.ex, test/sigra/install/features/admin_test.exs |

## What Was Built

### DIST-02: Installer tuple in Admin.files/1

Added `{:eex, "admin/sigra_admin.css", Path.join(["priv", "static", "assets", "sigra_admin.css"])}` as the seventh tuple in `Admin.files/1`. This follows the exact pattern of the auth precedent at `core.ex:256` — using `:eex` because the CSS file contains no EEX markers (verbatim copy behavior). The installer now ships the admin design system CSS to every generated host application.

### DIST-03: Body-level link tag in layouts_admin_injection.ex

Added `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` as the first element inside the `def admin(assigns)` HEEx heredoc, before `<.admin_shell>`. This is the direct analog of the `sigra_auth_components.ex:27` pattern — body-level placement ensures the admin layout loads the design system CSS without modifying the host's root layout `<head>`.

### DIST-04: Byte-guarded example copy + app.css reduction

`test/example/priv/static/assets/sigra_admin.css` is a verbatim `cp` of the canonical template (11,012 bytes — byte-identical confirmed via diff). The example now loads the same CSS as what the installer ships, closing the previous gap where Playwright and axe ran against CSS that was never distributed to generated hosts.

`test/example/priv/static/assets/css/app.css` was reduced from 3,848 to 3,544 lines by removing all `sg-*` content:
- Layer declaration: `@layer sg-base, sg-components, sg-overrides;`
- All `--sg-*` custom properties from `:root {}` and `@media (prefers-color-scheme: dark) {:root {}}`
- `@layer sg-base {}` block entirely
- The layout primitives subsection of `@layer sg-components {}` (lines 262-350 of original)
- `@layer sg-overrides {}` block entirely
- `@media (prefers-reduced-motion: reduce)` block (uses `--sg-motion-fast` and `.sg-admin-loading-bar`)

What remains: `--vt-*` tokens in `:root`, `--vt-*` dark overrides, the full VAULTR HOST APP `.vt-*` selector section (dedented, no longer wrapped in `@layer sg-components`), and a updated header comment.

### DIST-05: Golden fixture + parity tests

`test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` registered byte-identically, causing `golden_diff_test.exs` to automatically enforce template≡fixture parity on every CI run.

Also updated:
- `test/fixtures/install_golden/STDOUT.txt`: added `* creating priv/static/assets/sigra_admin.css` line after the `audit_export_controller.ex` creation line
- `test/fixtures/install_golden/tree/lib/.../layouts.ex`: added the `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` tag to match the injected output

Three new test items added to `test/sigra/install/features/admin_test.exs`:
1. In `files/1` describe: tuple assertion `{:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"} in files`
2. In `injections/1` describe: link tag content assertion `layouts_admin.content =~ ~s|href={~p"/assets/sigra_admin.css"}|`
3. New `DIST-05 example≡template byte-parity` describe block with `byte_size` + content equality assertions with resync cp command in error message

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| DIST-02 tuple present | `grep -c 'admin/sigra_admin\.css' lib/sigra/install/features/admin.ex` | 1 PASS |
| DIST-03 link present | `grep -c 'sigra_admin\.css' priv/templates/sigra.install/admin/layouts_admin_injection.ex` | 1 PASS |
| Example copy byte-size | `wc -c test/example/priv/static/assets/sigra_admin.css` | 11012 == template PASS |
| sg-* removed from app.css | `grep -c '@layer sg-' test/example/priv/static/assets/css/app.css` | 0 PASS |
| admin_test.exs (24 tests) | `mix test test/sigra/install/features/admin_test.exs` | 24 tests, 0 failures PASS |
| golden_diff_test.exs | `mix test test/sigra/install/golden_diff_test.exs --only golden` | 2 tests, 0 failures PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Build worktree symlink for Application.app_dir**
- **Found during:** Task 1 verification
- **Issue:** The `_build` directory was symlinked to the main repo's `_build`. `Application.app_dir(:sigra, ...)` resolves through `_build/dev/lib/sigra/priv` → symlink to main repo's `priv/`. Our worktree changes to `priv/` templates weren't visible during test execution.
- **Fix:** Created a local `_build` directory with worktree-local `priv` symlinks pointing to `../../../../priv` (the worktree's own priv), while symlink-linking all compiled dep beams from the main repo's `_build`. Also installed `phx_new 1.8.7` archive (matching CI version) to make golden_diff_test pass.
- **Files modified:** `_build/` directory structure (symlinks, not tracked by git)
- **Commit:** Infrastructure-only, no tracked file changes

**2. [Rule 1 - Bug] Golden fixture layouts.ex missing link tag**
- **Found during:** Task 2 golden_diff_test verification
- **Issue:** The golden test ran the installer and generated `layouts.ex` now includes the `<link>` tag from our DIST-03 change, but the committed fixture didn't have it.
- **Fix:** Updated `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/layouts.ex` to include the `<link>` tag — consistent with the intended installer output.
- **Files modified:** `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/layouts.ex`
- **Commit:** 575c190b

## Known Stubs

None. All files contain production-ready content: the CSS is extracted from the working example, the installer tuple and link tag are wired correctly, and the parity tests use real File.read! byte-compare assertions.

## Threat Flags

None. This plan wires an existing CSS file into the installer pipeline and adds ExUnit byte-compare tests. No user input, authentication logic, network endpoints, or secrets are involved. The `<link>` tag is static markup referencing a pre-existing asset path.

## Self-Check: PASSED

- [x] `lib/sigra/install/features/admin.ex` includes `admin/sigra_admin.css` tuple — `grep -c` returns 1
- [x] `priv/templates/sigra.install/admin/layouts_admin_injection.ex` includes `<link>` with `sigra_admin.css` — `grep -c` returns 1
- [x] `test/example/priv/static/assets/sigra_admin.css` exists and is byte-identical (11,012 bytes) to template
- [x] `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` exists and is byte-identical (11,012 bytes) to template
- [x] `test/example/priv/static/assets/css/app.css` has zero `@layer sg-` occurrences
- [x] `mix test test/sigra/install/features/admin_test.exs` — 24 tests, 0 failures
- [x] `mix test test/sigra/install/golden_diff_test.exs --only golden` — 2 tests, 0 failures
- [x] Commit `8719eaaf` exists: `feat(184-02): wire admin CSS into installer pipeline (DIST-02, DIST-03)`
- [x] Commit `575c190b` exists: `feat(184-02): add example/fixture copies, reduce app.css, add DIST-05 tests`
