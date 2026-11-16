---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 02
subsystem: ui
tags: [brand, fonts, woff2, favicon, example-app, sha256-parity, phoenix-root-layout, static-paths, ofl]

# Dependency graph
requires:
  - phase: 259-brand-book-vendoring
    provides: brand/ pinned byte-exact by brand.sha256 and scanned for privacy (the copy source for every file vendored here)
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: plan 01 contrast instrument (no code dependency; same test/sigra/brand suite and in-memory planted-control pattern)
provides:
  - the two web fonts, both OFL texts, favicon.svg and favicon.ico vendored byte-identical into the Sigra-owned example app
  - sigra_admin_brand.css, the Sigra-owned example stylesheet holding the two self-hosted font-face rules and the opt-in font tokens scoped to .sg-admin-shell
  - ExampleWeb.Layouts.sigra_owned_page?/1 and the admin-scoped ICO-then-SVG favicon links in the shared root layout
  - favicon.svg in static_paths; the demo's root favicon.ico and app.css untouched
  - Sigra.Brand.VendoredAssetsTest, the sha256 parity, root-favicon pin, stylesheet-contract and installer-ships-text-only oracles
affects: [261-04, 261-05, 261-08, 261-11, 261-12]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the changed text files; the two woff2 and the ico are binary and excluded)
actuals:
  tokens: 9364
  tasks: 3
  commits: 4
commits: 4
plan_head_before: 978687bc53583ba851afbaea729823314726741b
plan_head_after: 38f813f10eaf12eda6e6532191a87b7929ac19bc

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Vendored assets are copied with cp and pinned by a sha256 parity test whose failure message names the cp that restores them; the pure parity/2 helper has planted one-byte controls"
    - "Sigra-owned example CSS lives in its own stylesheet linked after app.css, never inside the demo's vt-* app.css"
    - "A shared root layout gates Sigra-only head links with a conn predicate rather than a second root layout"

key-files:
  created:
    - test/sigra/brand/vendored_assets_test.exs
    - test/example/priv/static/assets/fonts/instrument-sans-var.woff2
    - test/example/priv/static/assets/fonts/red-hat-mono-var.woff2
    - test/example/priv/static/assets/fonts/OFL-InstrumentSans.txt
    - test/example/priv/static/assets/fonts/OFL-RedHatMono.txt
    - test/example/priv/static/favicon.svg
    - test/example/priv/static/images/sigra-favicon.ico
    - test/example/priv/static/assets/css/sigra_admin_brand.css
    - test/example/test/example_web/admin_favicon_test.exs
  modified:
    - test/example/lib/example_web/components/layouts/root.html.heex
    - test/example/lib/example_web/components/layouts.ex
    - test/example/lib/example_web.ex

key-decisions:
  - "sigra_owned_page?/1 matches /admin exactly or any path under /admin/, not a bare string prefix, so a host route such as /administrator can never pick up Sigra's favicon. A non-conn argument returns false instead of raising."
  - "The favicon links sit in the shared root layout behind :if on the predicate; the ICO link is written first so browsers that stop at the first usable icon take the raster file and SVG-capable ones still find the theme-aware SVG (book order)."
  - "The brand stylesheet link is unconditional (every page), because the font tokens are scoped to .sg-admin-shell and inert on Tasklane markup; only the favicon links are page-scoped."
  - "The font-face src uses format('woff2') exactly as the book's fonts.css does; the demo's older Space Grotesk rule uses woff2-variations and is left alone."

patterns-established:
  - "Stylesheet-contract oracle: a pure brand_css_violations/1 strips block comments, then checks face count, font-display, local-only urls, no remote or inline source, and the single token rule, with one planted control per check"
  - "Installer text-only oracle: file-kind, binary-extension and no-font-face guards as pure functions over in-memory data, so each can be shown to fail without touching a real file"

requirements-completed: [BTOK-05, BTOK-06]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "The two woff2 files, both OFL texts, favicon.svg and favicon.ico under the example are byte-identical to brand/ (sha256 parity, cmp clean), a one-byte flip or one missing byte is reported, and brand/ and the root favicon.ico are untouched"
    requirement: BTOK-06
    verification:
      - kind: unit
        ref: "test/sigra/brand/vendored_assets_test.exs#byte parity with brand/ and parity/2 positive controls"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/vendored_assets_test.exs#root favicon.ico stays byte-unchanged"
        status: pass
    human_judgment: false
  - id: D2
    description: "The /admin pages emit the ICO link then the SVG link, a Tasklane login page emits no rel=icon link, the new assets and the demo's root favicon.ico all serve 200, and sigra_owned_page?/1 is true for /admin and /admin/_design and false for /administrator and Tasklane paths"
    requirement: BTOK-05
    verification:
      - kind: integration
        ref: "test/example/test/example_web/admin_favicon_test.exs (10 tests, run with MIX_ENV=test mix test --include example_app)"
        status: pass
    human_judgment: false
  - id: D3
    description: "sigra_admin_brand.css holds exactly two font-face rules (font-display swap, urls under /assets/fonts/, no CDN, no base64) and one .sg-admin-shell rule setting --sg-font-sans and --sg-font-mono to the book stacks; the demo's Fraunces and Inter rules in app.css are untouched"
    requirement: BTOK-06
    verification:
      - kind: unit
        ref: "test/sigra/brand/vendored_assets_test.exs#example brand stylesheet"
        status: pass
      - kind: other
        ref: "grep -c '@font-face' test/example/priv/static/assets/css/sigra_admin_brand.css prints 2; git diff --name-only -- test/example/priv/static/assets/css/app.css prints nothing"
        status: pass
    human_judgment: false
  - id: D4
    description: "The installer ships text only: every Admin.files/1 entry is the :eex kind, no font or icon binary lives under priv/templates/sigra.install/, and sigra_admin.css declares no font-face rule, each guard with a planted violation"
    requirement: BTOK-06
    verification:
      - kind: unit
        ref: "test/sigra/brand/vendored_assets_test.exs#installer ships text only"
        status: pass
    human_judgment: false
  - id: D5
    description: "Whether the vendored fonts actually render in the admin shell and whether the favicon is legible at 16-24 px are not asserted here: the font tokens arrive in plan 04, the render check in a later plan, and the legibility question is the phase's single human gate"
    requirement: BTOK-05
    verification: []
    human_judgment: true
    rationale: "This plan ships inert assets and wiring; visible rendering is owned by plans 04 and 12, and 16-24 px legibility is the owner's contact-sheet judgment"

# Metrics
duration: 9min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 02: Vendored Fonts and Favicon Summary

**Instrument Sans and Red Hat Mono (woff2 plus both OFL texts) and the book's favicon pair copied byte-identical into the Sigra-owned example, with a brand stylesheet linked after app.css, favicon links emitted only on /admin pages, and a sha256 parity test that fails on one planted byte.**

## Performance

- **Duration:** about 9 min timed (snapshot after the initial reads to the last verification)
- **Started:** 2026-11-16T00:00:43Z
- **Completed:** 2026-11-16T00:09:00Z
- **Tasks:** 3
- **Files modified:** 12 (9 created, 3 modified; two of the created files are binary woff2, one is an ico)

## Accomplishments

- **Byte-identical vendoring, proven.** Six pairs (two woff2, two OFL texts, `favicon.svg`, `favicon.ico`) match `brand/` by sha256 and by `cmp`. The parity helper is pure and has two planted controls (one flipped byte in a real font, one missing byte), so the check is known to be able to go red. `brand/` was never edited and `git status -- brand` stays empty.
- **Root favicon left alone, machine-checked.** The demo's 152-byte `test/example/priv/static/favicon.ico` is pinned by sha256, so the "Tasklane keeps its identity" contract cannot drift silently.
- **Favicon links only where Sigra owns the page.** `/admin` and anything under it emit the ICO link then the SVG link; `/users/log_in` emits no `rel="icon"` at all. `favicon.svg` is in `static_paths`, so `/favicon.svg` and `/images/sigra-favicon.ico` both serve 200 and the root `/favicon.ico` still does.
- **Sigra-owned font stylesheet.** `sigra_admin_brand.css` is linked after `app.css` and holds exactly two `font-face` rules (swap, `/assets/fonts/`, never a CDN, never base64) plus the single `.sg-admin-shell` rule that opts in `--sg-font-sans` and `--sg-font-mono`. The demo's Fraunces and Inter rules and the Space Grotesk override in `app.css` are untouched. The tokens themselves arrive in plan 04, so the rule is inert until then.
- **The installer still ships text only.** Every `Admin.files/1` entry is `:eex`, no `.woff`, `.woff2`, `.ttf`, `.otf` or `.ico` exists anywhere under `priv/templates/sigra.install/`, and `sigra_admin.css` has no `font-face`. Each guard has a planted in-memory violation, and the stylesheet guard also has a narrowness control (prose naming the at-rule inside a comment is not a rule).

## Task Commits

1. **Task 1: Tracer, byte-identical vendored assets proven by sha256 parity with a planted mismatch**
   - RED `01deece65` (test): 9 of 11 tests fail on a missing file (the copies did not exist)
   - GREEN `8e35eb244` (feat): 11 tests pass; all six `cmp` clean
   - Tracer feedback gate: `<verify>` re-run at the committed HEAD (41 tests across the vendored and source-pin files, 0 failures). Verified end to end, so expansion continued.
2. **Task 2: Example stylesheet, static path and admin-scoped favicon links** - `b739d6822` (feat)
3. **Task 3: Installer ships no binary and sigra_admin.css carries no @font-face** - `38f813f10` (test). The invariants already hold on the current tree, so the planted tests are the controls and there is no separate red commit (the same honest shape as plan 01 Task 3).

**Plan metadata:** the docs commit that follows this file (SUMMARY, then STATE and ROADMAP).

## Files Created/Modified

- `test/sigra/brand/vendored_assets_test.exs` - `Sigra.Brand.VendoredAssetsTest`, 25 tests (parity, controls, font-name set, root favicon pin, stylesheet contract, installer text-only)
- `test/example/priv/static/assets/fonts/instrument-sans-var.woff2`, `red-hat-mono-var.woff2` - copies of `brand/assets/fonts/web/sans.woff2` and `mono.woff2` (26,196 and 10,604 bytes)
- `test/example/priv/static/assets/fonts/OFL-InstrumentSans.txt`, `OFL-RedHatMono.txt` - copies of the two OFL texts
- `test/example/priv/static/favicon.svg`, `test/example/priv/static/images/sigra-favicon.ico` - copies of the book's favicon pair
- `test/example/priv/static/assets/css/sigra_admin_brand.css` - the two font-face rules and the opt-in token rule
- `test/example/lib/example_web/components/layouts/root.html.heex` - brand stylesheet link after `app.css`; two `:if`-gated icon links
- `test/example/lib/example_web/components/layouts.ex` - `sigra_owned_page?/1`
- `test/example/lib/example_web.ex` - `favicon.svg` added to `static_paths`
- `test/example/test/example_web/admin_favicon_test.exs` - `ExampleWeb.AdminFaviconTest`, 10 tests

## Decisions Made

See `key-decisions` in the frontmatter. In short: a path-segment-safe predicate, ICO link before SVG link, an unconditional stylesheet link with page-scoped favicon links, and `format('woff2')` as the book writes it.

## Deviations from Plan

### Auto-fixed Issues

None. No bug in existing code was found; no blocker occurred.

### Additions and interpretations

**1. [Rule 2 - Missing critical functionality] Oracle for the stylesheet contract**
- **Found during:** Task 2
- **Issue:** must_have truth 4 (exactly two local font-face rules, swap, no CDN, no base64, one token rule) had no test; the Task 2 acceptance only counted `@font-face` with grep.
- **Fix:** a pure `brand_css_violations/1` in `vendored_assets_test.exs` (comments stripped first) with a real-file test and six planted controls (third face, CDN source, base64 source, missing swap, extra rule, changed token value) plus one narrowness control (prose naming the at-rule in a comment).
- **Files modified:** `test/sigra/brand/vendored_assets_test.exs` (a file the plan already lists in `files_modified`, though not under Task 2's `<files>`)
- **Committed in:** `b739d6822`

**2. [Interpretation] The design gallery is not reachable in the test build**
- **Found during:** Task 2
- **Issue:** the plan's ConnCase check names the design gallery, but `/admin/_design` is mounted only under `dev_routes` (compile-time, dev config), so the test build answers 404.
- **Fix:** the request-level test uses `/admin/users` as a second admin page; `/admin/_design` is covered at the predicate level (`sigra_owned_page?/1` is true for it) and its rendered links are left to the Playwright lane named in the UI-SPEC ("present on `/admin` and `/admin/_design`, absent on a Tasklane page"). Nothing was weakened: the gallery's links come from the same root-layout lines.
- **Committed in:** `b739d6822`

**3. [Interpretation] Predicate matches a path segment, not a bare string prefix**
- The plan says "request path starting /admin". The shipped predicate is true for `/admin` and `/admin/...`, so `/administrator` is false. This is a strict tightening that excludes only hypothetical host routes; every real Sigra-owned path is still matched (verified for `/admin`, `/admin/users`, `/admin/_design`, `/admin/organizations/acme/users`).
- **Committed in:** `b739d6822`

**4. [Interpretation] Task 1 behaviour item 3 asserts names, not sizes**
- The plan says sizes are informational and identity is the sha256 parity. The test asserts the exact set of Sigra-owned font names beside the demo's fonts (no stray variant) and does not assert a byte size. The 26,196 and 10,604 byte figures appear only in this summary.
- **Committed in:** `01deece65`

---

**Total deviations:** 0 auto-fixed bugs; 4 additive or interpretive notes (1 Rule 2 addition, 3 interpretations).
**Impact on plan:** none negative. Every acceptance criterion is met as written; the additions only widen the oracles.

## Authentication Gates

None.

## Issues Encountered

- My own first draft of the font-name test missed `OFL-RedHatMono.txt` (no hyphen in "RedHat"); caught by the first GREEN run and fixed before the GREEN commit.
- A compile-time typing warning (`assert files != []` on a list the type checker knows is non-empty) was replaced by a stylesheet-entry membership assertion before the Task 3 commit; the final file runs clean under `mix test --warnings-as-errors`.
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started and were never staged. The example project's own HEEx formatter (run inside `test/example`) flags a long `<img ... />` line in `layouts.ex` at HEAD, before this change. The plan's criterion, the root `mix format --check-formatted`, passes. Recorded in `deferred-items.md`.
- The example suite prints a pre-existing compile warning (`no route path ... "/dev/mailbox"` in `settings_live.ex`); unrelated.

## Verification

- `mix test test/sigra/brand/vendored_assets_test.exs test/sigra/brand/source_pin_test.exs`: 55 tests, 0 failures (25 vendored-assets tests).
- `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/admin_favicon_test.exs test/example_web/admin_shell_test.exs`: 24 tests, 0 failures (10 in the new file). The whole example suite with `--include example_app`: 443 tests, 0 failures.
- Broader root run: `mix test test/sigra/brand test/sigra/install/asset_parity_test.exs test/sigra/templates`: 675 tests, 0 failures.
- `mix format --check-formatted` clean; `mix credo --strict` reports no issues on the new test; `mix test --warnings-as-errors` clean on the new test.
- `git status --short -- brand priv/templates` prints nothing; `git diff --name-only <plan base>..HEAD` lists exactly the 12 `files_modified`.
- A privacy grep over the added text lines (home paths, local file URLs, personal handles) finds nothing; the only matches of a case-insensitive `/Users/` are the Tasklane routes `/users/log_in`.

## Known Stubs

None.

## Threat Flags

None. `/favicon.svg` and `/images/sigra-favicon.ico` are new public static paths, but they are the planned, byte-copied book assets served by the existing `Plug.Static` allowlist; no new endpoint, auth path or schema. T-261-02 (tampering with the vendored binaries) is mitigated as planned: copy-only from the pinned `brand/` tree, sha256 parity with planted controls, OFL texts beside the fonts, no dependency added. T-261-03 (metadata in the binaries) is covered by the Phase 259 source-pin privacy scan of the originals; these are byte-copies, and the phase-end privacy legs re-scan the diff.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 04 adds `--sg-font-sans` and `--sg-font-mono` to `:root` and the application rules (`.sg-admin-shell { font-family: var(--sg-font-sans, inherit); }`). The example's `.sg-admin-shell` token rule in `sigra_admin_brand.css` is unlayered and loads after `app.css`, so it wins over the layered default; confirm it with the computed-style probe the UI-SPEC asks for.
- The Playwright guard rewrite (`document.fonts.check('16px "Instrument Sans"')` and `'13px "Red Hat Mono"'`) only turns true once a rendered element actually uses each face, which needs plan 04's application rules; until then the faces are declared but unused.
- The favicon render check and the Playwright `link[rel=icon]` assertions on `/admin` and `/admin/_design` can use the served paths `/images/sigra-favicon.ico` and `/favicon.svg`; the design gallery needs a dev-routes build.
- `space-grotesk-var.woff2`, its font-face and the `--font-sans` override in `app.css` were deliberately left in place; the grep-then-remove decision belongs to a later plan.

## Self-Check: PASSED

- FOUND: `test/sigra/brand/vendored_assets_test.exs`, `test/example/test/example_web/admin_favicon_test.exs`, `test/example/priv/static/assets/css/sigra_admin_brand.css`, `test/example/priv/static/favicon.svg`, `test/example/priv/static/images/sigra-favicon.ico`, and the four font files under `test/example/priv/static/assets/fonts/`
- FOUND commits: `01deece65`, `8e35eb244`, `b739d6822`, `38f813f10` (all ancestors of HEAD)
- Measured: 4 commits since `plan_head_before` `978687bc53583ba851afbaea729823314726741b`

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
