# Stack Research: v1.51 BRAND-IDENTITY-ADOPTION

**Domain:** Adopting a signed-off brand book (v2.0, "Kiln") in an existing Elixir/Phoenix auth library (hybrid lib + generator, public SemVer API, Hex package)
**Researched:** 2026-11-13
**Overall confidence:** HIGH for everything measured against this repo and the pinned ExDoc build; MEDIUM for external-platform behavior (hex.pm README rendering, Safari fallbacks, Hex size caps)

## Bottom line

**Net-new dependencies: 0 Hex, 0 npm, 0 CI-installed system tools.** Every new capability in this milestone is covered by things the repo already has:

| Need | Covered by (already in repo) |
|------|------------------------------|
| Hash-pin the vendored book | Elixir stdlib (`:crypto`, `File`, `Base`, `JSON`) + stock `shasum -a 256 -c` |
| WCAG contrast math | `Sigra.Branding.Contrast.contrast_ratio/2` (`lib/sigra/branding/contrast.ex`) |
| Contrast in a real browser | `@axe-core/playwright` 4.13.0 / `axe-core` 4.13.0 / Playwright 1.59.1 (locked in `test/example/priv/playwright/package-lock.json`) |
| Docs theming | ExDoc 0.40.3 (`mix.lock`) options `favicon:`, `assets:`, `before_closing_head_tag:` |
| Favicon / icon files | The book already ships every size and format (nothing to generate) |
| Fonts | The book already ships pinned, trimmed woff2 subsets (36.8 KB total) |

Decisions the roadmap can lean on:

| # | Decision | Confidence |
|---|----------|------------|
| D1 | **Generated admin and auth pages ship no font binaries by default.** Add `--sg-font-sans` / `--sg-font-mono` tokens whose default is the book's own stack (web family first, system fallback after), so a host opts in by adding `@font-face` only. Auth pages never load Sigra fonts (they wear the host's brand). | HIGH |
| D2 | **Sigra-owned surfaces self-host the book's two woff2 files byte-for-byte**: HexDocs (recipe verified below), the example/demo app, the component gallery. Never a font CDN. | HIGH |
| D3 | **Favicon: no generation step.** ExDoc `favicon:` points at `brand/assets/icon/favicon.svg`; the example app gets the book's `.ico` + SVG; generated host apps get nothing (the favicon is the host's). | HIGH |
| D4 | **Contrast gate = three offline-first layers, WCAG 2.2 only, no APCA.** (a) ExUnit token-pair contract using the existing `Sigra.Branding.Contrast`; (b) existing axe `wcag2aa` run in light and dark; (c) a ~20-line Playwright helper for the non-text 3:1 pairs axe cannot see. | HIGH |
| D5 | **Do not use the book's `sigra-exdoc.css` as shipped.** In a real ExDoc 0.40.3 build its dark palette never applies and its OS-media query mis-themes code blocks. Use the corrected, measured stylesheet in section 4. | HIGH (measured) |
| D6 | **Do not set ExDoc `logo:`.** ExDoc renders it in a 48x48 box; the book's typemark has a 96 px floor. | HIGH |
| D7 | **Hash pin = a root `brand.sha256` in `shasum -a 256` format + one ExUnit test + `brand/** -text` in `.gitattributes`.** Pin the whole `brand/` tree (72 files, 7.4 KB manifest). | HIGH |
| D8 | **Hex package: `files:` is unchanged.** `brand/` stays repo-only. Package is ~0.56 MB compressed against a 16 MiB client default cap. README images must be absolute URLs (hex.pm has no base path). | MEDIUM |

## Recommended Stack

### Core Technologies (existing, reused for new jobs)

| Technology | Version | New job in this milestone | Why |
|------------|---------|---------------------------|-----|
| Elixir stdlib `JSON`, `:crypto`, `File`, `Base`, `Path` | Elixir `~> 1.18` (repo `.tool-versions`: 1.19.5 / OTP 28.5) | Parse `brand/brand.json` + `brand/tokens.json`; sha256 manifest; copy-contract assertions | `JSON` is in stdlib from 1.18 and the project floor is 1.18, so no `jason` needed. `:crypto` is already in `extra_applications`. Verified by running a prototype on 1.19.5. |
| `Sigra.Branding.Contrast` | in-repo | WCAG 2.x ratio for every brand pair | **Verified: reproduces all 30 of the book's stated ratios (15 pair ids x light/dark) to 2 dp.** Accepts uppercase hex as used in the book. No new color code needed. |
| ExDoc | locked 0.40.3 (latest on Hex: 0.40.4, 2026-09-03); keep `~> 0.40` | Favicon, fonts, code colors in HexDocs | Options exist and were exercised in a real build (section 4). Theme mechanism is `body.dark`. |
| `@axe-core/playwright` + `axe-core` | 4.13.0 | Real-DOM text contrast (WCAG 1.4.3) in light and dark | Already used in 6 specs with tags `wcag2a wcag2aa wcag21a wcag21aa wcag22aa`. Extend to run per color scheme; do not add a second engine. |
| Playwright | 1.59.1 (`@playwright/test` + `playwright-core`) | ExDoc theme check, non-text contrast helper | Already the browser lane; `colorScheme: 'dark'` emulation already used by the dark projects. |
| Phoenix | repo lock 1.8.15 (latest 1.8.16) | Static serving of any font file an adopter opts into | `phx.new` default `static_paths` is `~w(assets fonts images favicon.ico robots.txt)` (seen in the example app); `Phoenix.Digester` rewrites `url(...)` inside `.css` (including relative paths) and appends `?vsn=d`. Verified in `deps/phoenix` source. |

### New artifacts (files, not dependencies)

| Path | Kind | Purpose |
|------|------|---------|
| `brand/` | vendored, byte-exact, read-only | The book, as received (72 files, 3.4 MB). Old `brandbook/` untouched until replaced. |
| `brand.sha256` | text manifest (root) | `<sha256>  <path>` per file, sorted, `shasum -c` compatible |
| `.gitattributes` | config | `brand/** -text linguist-vendored` (see section 6) |
| `scripts/brand/book_lock.exs` | stdlib script | `--write` regenerates the manifest, default mode checks it |
| `test/sigra/brand/book_pin_test.exs` | ExUnit | Manifest check + version/date constants + book self-consistency |
| `test/sigra/brand/copy_contract_test.exs` | ExUnit | Byte-identical copies + token-derived values (map in section 6) |
| `test/sigra/brand/contrast_pairs_test.exs` | ExUnit | 30 book pairs, then the same pairs against the implemented CSS |
| `guides/assets/brand/sigra-docs.css` | CSS (ours, derived from the book's) | Fonts + theme vars + code colors for ExDoc (section 4) |
| `test/example/priv/playwright/helpers/contrast.ts` | TS helper (~20 lines) | Resolve computed colors, assert non-text 3:1 pairs |
| `scripts/brand/exdoc-theme-check.mjs` | Node script (~60 lines, reuses existing `playwright-core`) | Asserts computed code colors in a built `doc/` in four theme combinations |

### Supporting Libraries

None. (A row for "none" is the point: see "What NOT to Add".)

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `shasum -a 256 -c brand.sha256` (macOS) / `sha256sum -c brand.sha256` (Linux) | Independent, human-runnable verification of the pin | Verified: 72/72 OK against a manifest produced by the stdlib script |
| `fonttools` (Python, local one-off only) | Inspect or regenerate font subsets | Not a repo or CI dependency. Used here only to inspect the book's woff2 files. |
| `magick` / `sips` (local one-off only) | Make a 180x180 apple-touch icon if the owner insists | Not needed: the book's 512 px avatar PNG is fully opaque (alpha min = 1, verified) |

## 1. Font delivery for generated host apps

### What the book ships (measured, not assumed)

| File | Bytes | Contents |
|------|-------|----------|
| `brand/assets/fonts/web/sans.woff2` | 26,196 | Instrument Sans, variable `wght` 400-700 (the `wdth` axis is dropped), 174 codepoints, GSUB `case liga locl tnum` |
| `brand/assets/fonts/web/mono.woff2` | 10,604 | Red Hat Mono, variable `wght` 400-500, 172 codepoints, GSUB `locl zero` (slashed zero) |
| `brand/assets/fonts/OFL-*.txt` | 4,403 + 4,394 | OFL 1.1 texts |
| `brand/assets/fonts/web/fonts.css` | 338 | Two `@font-face` rules, `font-display: swap`, relative `url('sans.woff2')` |

Total woff2 payload **36,800 B (35.9 KiB)**. The four source TTF/OFL SHA-256 values listed in `brand.json` `fonts.files` match the files on disk (verified with `shasum`). The woff2 subsets themselves are **not** hashed or given a recipe in `brand.json`; the repo pin (section 6) is what makes them reproducible.

### Licensing (HIGH)

- Neither OFL text declares a Reserved Font Name (copyright lines carry none). Subsetting (a Modified Version under OFL) without renaming the family is therefore permitted.
- OFL requires the copyright notice and license to accompany each copy. Both woff2 files retain copyright and license in `name` table IDs 0, 13, 14 (verified with fonttools), which OFL accepts as machine-readable metadata, **but ship the two `OFL-*.txt` files next to any font binary anyway** (8.8 KB, covered by the byte-identical copy contract).
- Fonts may not be sold by themselves; bundling inside a library and HexDocs is fine.

### Decision D1: no font binaries in adopters' repos by default

The book itself calls this a maintainers' call ("a web font is a dependency") and retires its old "system stacks only" rule only for Sigra's own pages. Reasons to default to no binaries in generated code:

1. Auth pages must wear the host's brand. Loading Sigra's typeface there would contradict the book's "Yours" value. They keep `font-family: inherit`/the host's stack (`--sigra-auth-*` tokens, unchanged).
2. The admin is an authenticated operator tool; FOUT and CLS cost almost nothing there, but a 36.8 KB font pair plus two license files committed into every adopter repo is a permanent ownership burden.
3. Shipping binaries needs installer changes that are not free: `Sigra.Install.Feature.files/1` and `Runner.run_files/3` only understand `{:eex, source, target}` and run `EEx.eval_file/2` on the template (corrupting a binary). A `{:copy, source, target}` kind is additive but touches the behaviour typespec, the runner, the golden harness (next bullet) and the upgrade story (existing adopters' `sigra_admin.css` is skipped as "already exists", so they would never receive fonts).
4. `test/support/install_fixture.ex` `normalize_content_for_golden/2` ends **every** non-config tracked file with `String.trim_trailing(content, "\n") <> "\n"`. That would silently alter a woff2 in the golden tree. If fonts ever ship through the installer, binary files must be emitted into the fixture as a `path -> sha256:<hex>` stub, not as bytes (keeps the golden text-diffable, which is milestone feature 2).

**What to build instead (cheap, additive, no installer change):**

- In `priv/templates/sigra.install/admin/sigra_admin.css` `:root` add `--sg-font-sans` and `--sg-font-mono`, defaulting to the book's stacks verbatim:
  - sans: `'Instrument Sans', system-ui, -apple-system, 'Segoe UI', sans-serif`
  - mono: `'Red Hat Mono', ui-monospace, 'SF Mono', Consolas, monospace`
  Naming the web family first is free: with no `@font-face` the browser skips it and uses the system fallback, and a browser only downloads a declared face when text actually uses it (observed: ExDoc's four Lato faces stayed `unloaded`). Opt-in is then "add the book's `fonts.css` and two files", no CSS edits.
- Apply the brand's typographic features regardless of font: `font-variant-numeric: tabular-nums` (already present), `font-feature-settings: "zero"` and `font-variant-ligatures: none` on the mono token's consumers.
- New `--sg-*` tokens must be added to `guides/reference/admin-token-reference.md` or `scripts/ci/admin-token-completeness.sh` fails (it diffs `:root` tokens against the doc). `scripts/ci/admin-css-conformance.sh` forbids raw hex outside `:root`; keep font stacks in tokens too.
- Existing weight tokens (`--sg-weight-regular: 450`, `bold: 800`) do not match the brand scale (400/600/700, nothing lighter than 400; the shipped variable range tops out at 700). Align them in the tokens phase.
- Documented opt-in recipe (HexDocs) that copies the two woff2 + two OFL files to `priv/static/fonts/sigra/` and adds `@font-face` with `url("../fonts/sigra/sans.woff2")` in `priv/static/assets/`. This works with Phoenix defaults: `fonts` is already in `static_paths`, and `mix phx.digest` rewrites the relative `url()` and appends `?vsn=d`.
- **Optional, deferrable to the package-assets phase:** carry one pinned copy of the four files under `priv/brand/fonts/` in the Hex package (46 KB, 0.3% of the size cap) so the recipe is a literal `cp deps/sigra/priv/brand/fonts/* priv/static/fonts/sigra/`. If the owner later wants `mix sigra.install --fonts`, that is the point to add the `{:copy, ...}` kind and the golden stub rule.

### Decision D2: Sigra-owned surfaces load the fonts

- **HexDocs:** verified recipe in section 4 (self-hosted woff2 through ExDoc `assets:`; 36.6 KB transferred; Lato not fetched).
- **Example/demo app and gallery:** copy the two woff2 into `test/example/priv/static/fonts/` (already inside `static_paths`) and link a small `sigra_fonts.css` (the book's `fonts.css` with `../fonts/` URLs) from `root.html.heex`. Do not put it in `app.css` (Tasklane `vt-*` only, with a known stray-comment corruption hazard).
- **Never** `fonts.googleapis.com` / `fonts.gstatic.com`: extra origin in CSP, third-party request from an auth product, availability dependency, and a known GDPR complaint pattern for EU visitors.

### FOUT, perf, and coverage

- Use the book's `font-display: swap`. No preload in v1.51: on an authenticated admin the swap is barely visible, and a mismatched preload URL double-downloads. If the gallery shows visible shift, add `<link rel="preload" as="font" type="font/woff2" crossorigin href={~p"/fonts/sigra/sans.woff2"}>` to `layouts_admin_injection.ex` only (`~p` and the digester both emit the `?vsn=d` form, so the URLs match). A metric-adjusted fallback face (`size-adjust`, ExDoc does this itself for Consolas at 110%) is a later polish item, not a gate.
- Do **not** base64-inline fonts into `sigra_admin.css`: +49 KB of unreadable lines in a 41 KB file, kills golden diffability, blocks all CSS on the font bytes.
- **Coverage gap to record, not fix:** the subsets cover U+0020-007E, A0, B0, C0-FF, curly quotes, en/em dash, bullet, ellipsis, arrows, minus. **Missing:** U+00A1-00BF except A0/B0 (so `·` U+00B7, `©`, `±`, `¿`, `«»`), all of Latin Extended-A/B (`ł ő ğ š č ż ă ș`), `€`, `™`, `✓`. The repo's own UI strings use `·` (8 occurrences) and `✓` (5). Missing glyphs fall back per glyph to the next family, so the effect is a mismatched dot, not broken text; user-supplied names with Polish/Czech/Turkish letters will mix fonts. Re-subsetting is **not** recommended for v1.51: a stock `fontTools.subset` with all layout features produced 35.5 KB + 21.1 KB (56.6 KB), i.e. the book's trimmed 36.8 KB files are better optimized than a naive redo, and adding Latin-Ext-A/`€`/`™`/`✓` costs roughly +5 KB per face. Revisit only if the worst-case-data gallery pass shows ugly fallback.

## 2. Favicon, ICO, SVG, apple-touch: nothing to generate

| Asset | In the book | Use |
|-------|-------------|-----|
| `icon/favicon.svg` (311 B) | 32x32 viewBox with width/height, embedded `@media (prefers-color-scheme: dark)` swapping stem and square | ExDoc `favicon:`; example app `<link rel="icon" type="image/svg+xml">` |
| `icon/favicon.ico` (397 B) | 2 PNG frames (16, 32), **light ink only** | Fallback file for the example app's `favicon.ico`. Invisible-ish stem on dark tab strips, acceptable because SVG-capable browsers use the SVG |
| `icon/favicon-{16,32,48}-{light,dark,mono}.png/.svg` | Pixel-grid drawings | Reference only; do not hand-pick per theme |
| `avatar/sigra-avatar-512-{light,dark}.png` | Opaque (alpha min = max = 1, verified) | Direct source for an apple-touch icon; iOS downsamples, no 180 px file required |

Integration facts:

- ExDoc `favicon:` accepts only PNG, JPEG, SVG (no ICO) and copies to `assets/favicon.<ext>`; head renders `<link rel="icon" href="assets/favicon.svg" />` (observed in the build). The embedded media query follows the OS/browser theme, which is correct for a browser tab strip.
- Safari added SVG favicon support in 26.0 (2025-09, Apple release notes); older Safari ignores it and falls back to whatever the origin offers (on HexDocs, HexDocs' own icon). Accept that degradation; do not build PNG fallbacks for hexdocs.pm.
- **Generated host apps get no Sigra favicon.** The admin renders inside the host's root layout and `layouts_admin_injection.ex` only injects the stylesheet link. Shipping our icon into a host would violate the book's presence tiers.
- `test/example` root layout currently has no `<link rel="icon">`. Place new icon files under `priv/static/images/` (inside `static_paths`) rather than editing `static_paths`. Whether the demo wears Sigra's or Tasklane's favicon is an owner decision for the words-and-layout phase.
- Keep the installed logo **paths** stable: the installer writes `priv/static/images/sigra-logo-primary.svg` and `...-dark.svg`, and `admin_shell.ex` references them via `~p`. Replace the bytes with the book's `logo/sigra-lockup-light.svg` / `-dark.svg` (2,191 B each; flat paths, no live text) and keep the target names. Add a title/role at the `<img alt>` site, since the book's SVGs carry no `<title>`.
- No webmanifest, no 192 px icon: this is a library, not a PWA.

## 3. Contrast checking in CI (WCAG 2.2 AA, no heavy dependency)

### Layer 1: offline token contract (ExUnit, runs inside `mix ci`)

1. **Book self-consistency.** For each `brand.json` `color.contrastPairs` entry and theme, assert `Sigra.Branding.Contrast.contrast_ratio(text, ground)` rounds to the stated `contrast` and is `>= minimum`. Verified today: 30/30 match, 30/30 pass.
2. **Implemented-CSS contract.** Parse the `:root` hex custom properties in `priv/templates/sigra.install/admin/sigra_admin.css` and `core/sigra_auth.css` with a regex (same approach as the existing `admin-token-completeness.sh` awk), map `--sg-*` to the book roles (a small table in the test), and assert (a) equal to `tokens.json` hex, case-insensitively (the repo uses lowercase), and (b) every pair still meets its `minimum`. The existing `--sg-color-brand #c2410c` and `--sg-color-brand-strong #9a3412` already equal Kiln and Kiln Deep.
3. **Margin watch.** Thinnest pair: status word on a selected row, light, **4.61 vs 4.5**. Fail on `< minimum`; also print the three thinnest margins so token drift shows up in review before it fails.

Tokens using `rgba()` or `color-mix()` are out of scope for Layer 1 by design; Layer 2 covers them in the browser.

### Layer 2: axe in the real DOM (existing gate, extended)

- axe `color-contrast` maps to WCAG SC 1.4.3 only. It **cannot** evaluate text over background images, gradients, or pseudo-element backgrounds, and reports those as `incomplete`. It has **no rule for SC 1.4.11 non-text contrast**.
- Extend the existing specs that already scan the admin (tags `wcag2aa`, `wcag22aa`) to run once per color scheme (`browser.newContext({ colorScheme })`), against the gallery (`/admin/_design`) and the generated auth pages. Record the `incomplete` count in the report; do not treat `incomplete` as a pass.

### Layer 3: non-text pairs axe cannot see (small Playwright helper)

Focus ring (3:1 vs page), control edge (4.0:1 on Paper, book minimum 3:1), logo square (4.69:1), status mark vs row. Read computed colors from the DOM and **resolve any CSS color string to sRGB through a 1x1 canvas** (`fillStyle = value; getImageData`), which handles `color-mix()`/`oklab()` results that regex parsing cannot. Compare with the same ratio function; the book's ids (`focus`, `artwork`, `selected-row`...) key the assertions.

### Why not APCA

- axe-core's rule is defined on WCAG 2.x criteria only; APCA exists only as a third-party add-on (`apca-check`) that asks you to disable the stock rule.
- WCAG 3.0 is still a W3C **Working Draft** (10 September 2026) whose contrast measure is "to be determined"; WCAG 2.2 AA (and EN 301 549) is the normative bar. The book also states its ratios as "WCAG 2.2 contrast".
- A second algorithm would add a gate that can disagree with the book's stated ratios and with every compliance reference an adopter will be asked about. Skip. (An advisory APCA print-out is possible later with ~15 lines, but nothing here justifies it.)

## 4. ExDoc theming (measured in a real build)

All results below are from building a minimal project on **ExDoc 0.40.3** (the locked version) and reading computed styles in Chromium through Playwright for all four combinations of OS scheme x ExDoc theme (`?theme=light|dark` is honored by ExDoc, which makes the check deterministic).

### Defect in the book's `docs/sigra-exdoc.css` (the book flags it as unverified)

| Scenario | Result with the book's file as shipped |
|----------|----------------------------------------|
| Light | Correct (6/6: keyword, string, atom, number, comment, code ground) |
| ExDoc dark | **Token colors are ExDoc's Monokai defaults** (`#66D9EF`, `#E6DB74`, `#AE81FF`, `#969386`); only the background matches |
| OS dark, ExDoc set to Light | **Dark palette and dark code ground on a light page** (the unconditional `@media (prefers-color-scheme: dark)` block fires) |

Root causes: ExDoc ships `.dark .makeup .x` rules at specificity (0,3,0) for 40 of the classes the book targets, beating the book's `.makeup .x` (0,2,0); and ExDoc's theme source of truth is `body.dark` (set from `?theme=`, localStorage, or the OS only when the setting is "system"), not the OS media query.

### Corrected stylesheet (verified 24/24 checks, all four combinations)

`:is(body, body.dark)` takes the specificity of its most specific argument, so one rule family gives (0,3,1) in both themes and beats ExDoc's (0,3,0); the variables switch on `body.dark`. Same five roles, same hex values as `brand.json` `code`.

```css
body{--sigra-doc-bg:#EFE8DE;--sigra-doc-text:#1F1A17;--sigra-doc-comment:#6B6057;--sigra-doc-keyword:#9A3412;--sigra-doc-string:#2C5F9E;--sigra-doc-atom:#1F6A8A}
body.dark{--sigra-doc-bg:#120E0C;--sigra-doc-text:#F3EEE8;--sigra-doc-comment:#A99C91;--sigra-doc-keyword:#F4A27C;--sigra-doc-string:#7FB0E8;--sigra-doc-atom:#6FC0E0}
:is(body,body.dark) pre code.makeup{background:var(--sigra-doc-bg);color:var(--sigra-doc-text);font-variant-ligatures:none}
:is(body,body.dark) .makeup :is(.k,.kd,.kn,.kp,.kr,.kt,.ow){color:var(--sigra-doc-keyword)}
:is(body,body.dark) .makeup :is(.s,.s1,.s2,.sa,.sb,.sc,.sd,.se,.sh,.si,.sx,.sr,.sl){color:var(--sigra-doc-string)}
:is(body,body.dark) .makeup :is(.ss,.na,.no,.m,.mb,.mf,.mh,.mi,.mo,.il){color:var(--sigra-doc-atom)}
:is(body,body.dark) .makeup :is(.nf,.fm,.nc,.nn){color:var(--sigra-doc-text)}
:is(body,body.dark) .makeup :is(.c,.c1,.cm,.cs,.ch,.cp,.cpf){color:var(--sigra-doc-comment)}
```

Verified only in Chromium. The `:is()` specificity rule is in the CSS spec and supported by all current engines, so risk is low; run the check in WebKit/Firefox only if the existing lane already provides them.

### Fonts in ExDoc (verified)

ExDoc defines `--sansFontFamily` and `--monoFontFamily` but `--sansFontFamily` only styles headings and table heads; the body text uses a hard-coded `html{font-family:system-ui,...}`. Add the book's two `@font-face` rules (URLs relative to the stylesheet), override both variables on `:root`, and also set `html{font-family:var(--sansFontFamily)}` and `code,kbd,samp,pre{font-family:var(--monoFontFamily)}`. Observed result: body is Instrument Sans, code is Red Hat Mono, Lato `unloaded`, font transfer 26,091 + 10,499 B plus ExDoc's own 2 KB icon font.

### `mix.exs` changes

```elixir
favicon: "brand/assets/icon/favicon.svg",              # was "brandbook/favicon.svg"
# no :logo (ExDoc caps it at 48x48 px; the typemark's floor is 96 px; the sidebar already prints "Sigra")
assets: %{
  "guides/assets" => "assets",                          # existing
  "brand/assets/fonts/web" => "assets/fonts"            # sans.woff2, mono.woff2 (fonts.css is copied, unused)
},
before_closing_head_tag: &before_closing_head_tag/1     # existing Mermaid <style>/<script> stays; prepend
                                                        # <link rel="stylesheet" href="assets/brand/sigra-docs.css">
```

`guides/assets/brand/sigra-docs.css` (ours: font-face with `../fonts/*.woff2` URLs, the two variable overrides, the corrected code colors) is copied by the existing `"guides/assets" => "assets"` entry. All ExDoc pages sit at the docs root, so the relative `assets/...` link works. (The verified probe inlined the CSS in `<style>`; the external-file form differs only in the relative font URL; the check script below must run against whichever form ships.)

### Guard against ExDoc drift

ExDoc's `.makeup` class names and `.dark` rules are internal. `scripts/brand/exdoc-theme-check.mjs` should build nothing itself; it opens the already-built `doc/<Module>.html?theme=light|dark` in four OS x theme combinations and asserts computed keyword, string, atom, number, comment and code-ground colors equal `brand.json`. Run it after the existing `mix docs --warnings-as-errors` step (the `library_tests_dep_off` job). That job has no Playwright: either scoped `npm ci --ignore-scripts` in `test/example/priv/playwright` (pattern already used at `ci.yml` ~line 477) plus `channel: 'chrome'` on the runner image's preinstalled Google Chrome (no browser download; confirm it is present in that job before relying on it), or run it in a lane that already boots Playwright. A Dependabot ExDoc bump is the trigger this catches.

## 5. Hex package files and asset limits

| Fact | Value | Confidence |
|------|-------|------------|
| Client default caps (hex_core `default_config`) | package tarball 16 MiB compressed / 128 MiB uncompressed; docs tarball 16 MiB / 128 MiB | MEDIUM (hex_core source; hex.pm publish docs state no MB cap) |
| Current package (`lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md`) | ~557 KB compressed, ~2.8 MB raw | HIGH (measured) |
| Docs `guides/assets` PNGs | 384 KB | HIGH |
| Cost of everything this milestone could add to the package | 0 B required; 46 KB if the optional `priv/brand/fonts/` copy is taken | HIGH |
| Cost of mistakenly packaging all of `brand/` | 3.4 MB raw, including 1.3 MB PDF, 328 KB previews, 452 KB static TTFs, 260 KB variable TTFs | HIGH |

Recommendations:

- **Leave `package/0 files:` as is.** `priv` and `docs` are already in it; `brand/`, `brand.sha256`, `scripts/` stay repo-only (the book is a reference, and the pin check belongs to the repo gate).
- If the optional font copy is taken, put it under `priv/brand/fonts/` so no `files:` edit is needed.
- **hex.pm has no logo or image metadata field.** "Hex package assets" means the README (rendered by hex.pm from the tarball), the `description:` string, and `links:`. hex.pm renders README images with no base path, so **use absolute URLs** (e.g. `https://raw.githubusercontent.com/<owner>/sigra/main/brand/assets/readme/sigra-header-light.svg`); relative `brand/...` works on GitHub and could be made to work on HexDocs through `assets:`, but breaks on hex.pm.
- GitHub README dark/light uses `<picture><source media="(prefers-color-scheme: dark)">`. hex.pm sanitizes README HTML and may drop `<picture>`/`<source>`, leaving only the `<img>` fallback. Make the fallback the **light** drawing (hex.pm is a light page) and verify after release. Confidence LOW that `<picture>` survives; this is why announcement-last ordering is right.
- The social card (`brand/assets/social/sigra-social-card-1280x640.png`, 38.9 KB) is a GitHub repository setting (Settings -> Social preview); treat it as a manual operator step, not automatable (MEDIUM).
- Update `description:` and `docs` `main`/tagline strings through the copy-contract test, not by hand.
- **Visibility caveat:** the Hex API (checked 2026-11-13) still reports `latest_stable_version` 1.20.0 for the package (a stray release outside this milestone's scope). `hex.pm/packages/sigra` will not show a v1.51 brand until that is resolved; verify with the version-specific page `hex.pm/packages/sigra/<version>`.

## 6. Hash-pinning the vendored book

### Mechanism (decision D7)

| Element | Choice | Why |
|---------|--------|-----|
| Algorithm | SHA-256 via `:crypto.hash(:sha256, bin)` | Already available; matches the book's own `fonts.files[].sha256` |
| Scope | Entire `brand/` tree (72 files) | "This is book 2.0, byte for byte." A subset pin would let non-consumed files change silently |
| Manifest | Root `brand.sha256`, lines `<hex>  brand/<path>` sorted by Elixir binary order | Works unchanged with `shasum -a 256 -c` / `sha256sum -c` (verified 72/72); a human or a bare CI step can verify with no Elixir |
| Location | **Outside** `brand/` | The vendored tree stays untouched; the manifest is the reviewed artifact |
| Check | ExUnit test compares the regenerated manifest to the committed one and prints added/removed/changed paths | Runs in `mix ci`; no new CI job |
| Regeneration | `elixir scripts/brand/book_lock.exs --write` | One command; PR shows book diff + manifest diff + version constants together |
| Metadata | Test constants `@book_version "2.0"` and the date, asserted against `brand/brand.json` | A new book edition forces an explicit edit |
| Line endings | `.gitattributes`: `brand/** -text linguist-vendored` | Without it, `core.autocrlf` on a Windows checkout rewrites SVG/CSS/JSON and breaks every hash. No `.gitattributes` exists in the repo today |

Core of the script (stdlib only, ~10 lines; prototype produced a 7,436-byte manifest):

```elixir
files = Path.wildcard("brand/**/*", match_dot: true)
        |> Enum.filter(&File.regular?/1) |> Enum.reject(&(Path.basename(&1) == ".DS_Store")) |> Enum.sort()
manifest = for f <- files, into: "", do: "#{Base.encode16(:crypto.hash(:sha256, File.read!(f)), case: :lower)}  #{f}\n"
```

Rejected: pinning only `git rev-parse HEAD:brand` (SHA-1, no per-file diff, needs git at test time); a hex/git dependency (the book is data, not code); a tarball checksum (opaque).

### Copy-contract map (decision: byte-identical wherever possible, derived-and-verified otherwise)

| Repo location | Source in `brand/` | Contract |
|---------------|--------------------|----------|
| `priv/templates/sigra.install/admin/sigra-logo-primary.svg`, `...-dark.svg` | `assets/logo/sigra-lockup-light.svg`, `-dark.svg` | Byte-identical (EEx passes it through; the templates contain no `<%`). Target install names unchanged |
| `test/example/priv/static/fonts/*.woff2`, `OFL-*.txt` | `assets/fonts/web/*.woff2`, `assets/fonts/OFL-*.txt` | Byte-identical |
| `priv/brand/fonts/*` (optional) | same | Byte-identical |
| Example `favicon.ico`, `images/favicon.svg`, apple-touch PNG | `assets/icon/favicon.ico`, `favicon.svg`, `assets/avatar/sigra-avatar-512-light.png` | Byte-identical |
| `sigra_admin.css`, `sigra_auth.css` `:root` tokens | `tokens.json` color values | Hex equal (case-insensitive) per the role map in the test |
| `guides/assets/brand/sigra-docs.css` hex values | `brand.json` `code` roles | Every hex in the file is a code-role value; every role appears |
| README/Hex strings (tagline, descriptor), `mix.exs` `description:` | `brand.json` `tagline`, `descriptor` | Substring contract |

Do **not** generate the CSS from `tokens.json` (see "What NOT to Add"): `admin-css-conformance.sh` already enforces that hex lives only in hand-curated `:root` blocks, and dark tokens are tuned by hand. Verify, don't generate.

PII note for the pin: a byte-pinned tree cannot be sanitized after the fact. A scan of the book for home paths and non-fictional emails came back clean (only `*.tasklane.test` demo addresses; PDF producer is a headless browser, no author field). Run the repo's name/home-path guard over `brand/` before the first commit anyway.

## Installation

No installs. Verification commands:

```bash
# Regenerate / check the pin (stdlib only)
elixir scripts/brand/book_lock.exs --write
elixir scripts/brand/book_lock.exs

# Independent check with stock tools (macOS / Linux)
shasum -a 256 -c brand.sha256
sha256sum -c brand.sha256

# ExDoc theme check (after the docs build)
mix docs --warnings-as-errors && node scripts/brand/exdoc-theme-check.mjs doc
```

## Alternatives Considered

| Recommended | Alternative | When the alternative is better |
|-------------|-------------|--------------------------------|
| Tokens with book stacks, no binaries by default (D1) | Ship woff2 into every adopter repo | If the owner decides the admin's typeface is part of the product's identity enough to justify the installer `:copy` kind, the golden stub rule, and an upgrade note. Then do it as `--fonts` opt-in, not default |
| Self-hosted woff2 (D2) | Google Fonts / fontsource npm | Never for an auth library (CSP, third-party request, availability). Fontsource is acceptable only inside an adopter's own Tailwind pipeline, which is their call |
| Corrected ExDoc CSS (D5) | Book's CSS as shipped | Only if ExDoc is not themed dark at all; measured not to work today |
| Existing `Sigra.Branding.Contrast` + axe + tiny helper (D4) | `colorjs.io` / `culori` / `wcag-contrast` / APCA libs | If WCAG 3 reaches Candidate Recommendation with a fixed algorithm and compliance regimes adopt it |
| Root `brand.sha256` (D7) | Git tree OID or subset pin | Git OID if you want zero files and only ever verify inside a git checkout; subset pin if `brand/` is expected to churn in non-consumed files |
| Extend the existing `/admin/_design` gallery for catalog checks | `phoenix_storybook` 1.5.0 | Only if the owner later wants Storybook-style stories as a product. It requires `phoenix ~> 1.8.1`, `phoenix_live_view ~> 1.1.21 or ~> 1.2.0`, and `mdex ~> 0.12` (native NIF); keep it in `test/example/mix.exs` and out of library deps and the package |

## What NOT to Add

| Avoid | Why | Use instead |
|-------|-----|-------------|
| Any new Hex dependency (color libs, `image`/`vix`, `mogrify`, `jason` for JSON, `file_system`) | Stdlib `JSON`/`:crypto` and `Sigra.Branding.Contrast` cover the need; the project constraint is minimal transitive deps | Stdlib + existing modules |
| `style-dictionary` / Tokens Studio / any tokens-to-CSS generator | Hand-written `sg-*` layer with a conformance guard; generation fights the guard and hand-tuned dark values | Verify tokens in a test |
| `apca-w3`, `apca-check`, any APCA gate | Not normative; WCAG 3 draft has no fixed algorithm; disagrees with the book's stated ratios | WCAG 2.2 ratios |
| `culori`, `colorjs.io`, `wcag-contrast`, `color-contrast-checker` (npm) | A 15-line function already exists in-repo and matches the book 30/30 | `Sigra.Branding.Contrast`; canvas 1x1 for browser color resolution |
| A second a11y engine (pa11y, Lighthouse CI, `html_codesniffer`) | axe 4.13 is already the gate; a second engine adds disagreements | axe, extended per color scheme |
| `sharp`, `svgo`, `png-to-ico`, `to-ico`, `favicons`, RealFaviconGenerator, ImageMagick/Inkscape/rsvg in CI | The book ships every icon size and format; regeneration would also drift from the pixel-grid drawings | Copy the book's files; hash-pin |
| `pyftsubset` / `glyphhanger` / `subfont` in CI or the build | Re-subsetting loses the book's trimmed 36.8 KB result (naive redo: 56.6 KB) and adds an unpinned step | Ship the book's woff2 unmodified; fonttools local one-off only |
| Base64-inlined fonts | +49 KB unreadable CSS, blocks rendering on font bytes, kills golden diffs | Separate cacheable woff2 files |
| `fonts.googleapis.com` / any font CDN | Third-party origin, CSP, privacy, availability | Self-hosted |
| ExDoc `logo:` with the typemark; `cover:`; a forked ExDoc theme | 48x48 box vs 96 px floor; forks rot on every ExDoc bump | Head hook + `assets:`; sidebar already shows the name |
| `@storybook/*` or `phoenix_storybook` in the library | Dependency in the middle of a rebrand; a gallery already exists | Extend `/admin/_design` |
| Packaging `brand/` (PDFs, previews, static/variable TTFs) in Hex | 3.4 MB of non-runtime weight | Repo-only; optionally the 46 KB font subset under `priv/` |
| A `{:copy, ...}` installer kind **in v1.51 by default** | Touches behaviour typespec, runner, golden normalizer, upgrade path for a benefit D1 does not need | Defer until an opt-in `--fonts` is chosen |
| Re-sanitizing or editing files inside `brand/` | Breaks the pin and the "byte-exact reference" contract | Change the book upstream, re-vendor, re-lock |

## Stack Patterns by Variant

**If an adopter wants Sigra's typeface in their admin:**
- Copy the two woff2 + two OFL files into `priv/static/fonts/sigra/`, add the book's `@font-face` pointing at `../fonts/sigra/*.woff2`; no token edits (D1 default already names the family first).
- Because `fonts` is in Phoenix's default `static_paths` and the digester rewrites relative `url()` references.

**If an adopter keeps a system or house font:**
- Override `--sg-font-sans` / `--sg-font-mono` in their own CSS. Nothing is downloaded.
- Because the declared web family is only fetched when a face exists and is used.

**If the book is updated upstream:**
- Re-vendor `brand/`, run `elixir scripts/brand/book_lock.exs --write`, update the version/date constants, re-run copy-contract and contrast tests; any byte-identical copy that drifted fails with its path.
- Because the pin makes the book a checked dependency rather than a PDF.

**If ExDoc is bumped (Dependabot):**
- The theme-check script is the gate; if `.makeup` classes or `.dark` rules change, adjust the selector prefix, not the colors.

## Version Compatibility

| Package | Compatible with | Notes |
|---------|-----------------|-------|
| Elixir `JSON` module | Elixir 1.18+ (repo floor `~> 1.18`) | Prototype ran on 1.19.5 / OTP 28.5 (`.tool-versions`) |
| ExDoc 0.40.3 (probe) | `~> 0.40` in `mix.exs`; 0.40.4 is latest | `favicon:` png/jpg/jpeg/svg only; `logo:` 48x48 box; theme = `body.dark`; `?theme=` param works |
| `@axe-core/playwright` 4.13.0, Playwright 1.59.1 | CI browser cache key `playwright-chromium-1.59.1-v3` | Keep one engine; extend, do not replace |
| Phoenix 1.8.15 (lock) | `phx.new` 1.8.x `static_paths` includes `fonts` | Golden fixtures stay pinned to `phx_new 1.8.8` per CI |
| `phoenix_storybook` 1.5.0 | `phoenix ~> 1.8.1`, `phoenix_live_view ~> 1.1.21 or ~> 1.2.0`, `mdex ~> 0.12` | Listed only to document the rejected option |
| Safari | SVG favicons from 26.0 | Older: no tab icon on hexdocs.pm; acceptable |

## Findings that correct or qualify the book

1. `sigra-exdoc.css` does not deliver its dark palette and mis-themes code on an OS-dark / ExDoc-Light combination (measured; fix in section 4).
2. ExDoc's `--sansFontFamily` is not enough to set body text; `html{font-family}` is hard-coded (measured).
3. The woff2 subsets omit `·`, `©`, Latin Extended-A/B, `€`, `™`, `✓`; their provenance is unhashed in `brand.json` (pin covers it).
4. `favicon.ico` is light-ink only; the SVG is the real theme-aware icon.
5. The repo's `--sg-weight-*` tokens (450/600/700/800) do not match the book's 400/600/700 scale.
6. The book itself lists as unverified: logo distinctness, 16 to 24 px favicon legibility, lead-line wording, trademark/look-alike search. These are the irreducible human judgments in this milestone; everything else above is automatable.

## Open items for phase-level research

- **Opt-in fonts path** (only if chosen): installer `{:copy, ...}` kind, binary stub in the golden normalizer, `sigra.upgrade` guidance for existing hosts. Not needed for D1.
- **README `<picture>` on hex.pm**: unverifiable before a release; check on the version-specific page after the first brand-bearing publish.
- **ExDoc check in WebKit/Firefox**: Chromium only so far.
- **axe `incomplete` volume** on `color-mix()` surfaces: measure on the gallery before deciding whether Layer 3 must widen.
- **Demo favicon identity** (Sigra vs Tasklane): owner decision.

## Sources

- Local, pinned-source reads and measurements, run 2026-11-13 (HIGH): `mix.exs`, `mix.lock`, `priv/templates/sigra.install/{admin,core}/*.css`, `lib/sigra/install/{feature,runner}.ex`, `test/support/install_fixture.ex`, `lib/sigra/branding/contrast.ex`, `test/example/priv/playwright/package-lock.json`, `scripts/ci/admin-*.sh`; the brand book (`BRAND.md`, `brand.json`, `tokens.json`, `assets/**`); ExDoc 0.40.3 source and dist CSS/JS (`favicon`/`logo` copy rules, `.dark .makeup` selectors, `--sansFontFamily`, theme bootstrap); Phoenix 1.8.15 `Phoenix.Digester`.
- Real-build probes (HIGH): ExDoc 0.40.3 minimal project + Playwright/Chromium computed styles, 24/24 theme checks with the corrected CSS vs 8/24 with the book's CSS (16 mismatches, all in the three non-light combinations); self-hosted font load (Lato unloaded, two woff2 loaded); stdlib WCAG prototype 30/30; `Sigra.Branding.Contrast` 30/30; stdlib manifest + `shasum -c` 72/72; fonttools inspection of both woff2 files; `fontTools.subset` size comparison.
- hex_core `default_config` (tarball 16 MiB / 128 MiB; docs same) and `hex_tarball.erl` option semantics, via source fetch; corroborated by a closed hex_core issue "Bump package tarball size limits to 16MiB/128MiB" (MEDIUM). hex.pm publish docs state no MB cap.
- axe-core `color-contrast` rule documentation (WCAG 2.x SC 1.4.3 only; cannot evaluate background images, gradients, pseudo-element backgrounds; no 1.4.11) (MEDIUM). W3C WCAG 3.0 Working Draft dated 10 September 2026, contrast algorithm "to be determined" (MEDIUM, primary source fetched once). `apca-check` as the third-party APCA path for axe (LOW-MEDIUM).
- Apple Safari 26.0 release notes and WebKit WWDC25 post: SVG icon support (MEDIUM).
- Hex API checks 2026-11-13: ExDoc 0.40.4, Phoenix 1.8.16, `phoenix_storybook` 1.5.0 and its requirements, sigra `latest_stable_version` 1.20.0 (HIGH, direct API reads).

---
*Stack research for: v1.51 BRAND-IDENTITY-ADOPTION (brand book adoption in an existing Phoenix auth library)*
*Researched: 2026-11-13*
