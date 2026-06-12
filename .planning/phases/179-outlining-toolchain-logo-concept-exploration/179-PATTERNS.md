# Phase 179: Outlining Toolchain + Logo Concept Exploration — Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 7 new files (outline-wordmark.mjs, scripts/brand/package.json, 5–7 candidate SVGs, round-3/index.html, round-3/README.md, .gitignore additions, brandbook/README.md update)
**Analogs found:** 6 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/brand/outline-wordmark.mjs` | utility | transform (font-path → SVG) | `brandbook/logo-primary.svg` (SVG conventions) + RESEARCH.md skeleton | partial (no existing Node script) |
| `scripts/brand/package.json` | config | — | `test/example/priv/playwright/package.json` | role-match |
| `brandbook/logo-options/round-3/*.svg` | config/asset | file-I/O | `brandbook/logo-primary.svg`, `brandbook/logo-mark.svg` | exact |
| `brandbook/logo-options/round-3/index.html` | config/asset | — | `brandbook/logo-options/round-2/index.html` | exact |
| `brandbook/logo-options/round-3/README.md` | config/asset | — | `brandbook/logo-options/round-2/README.md` | exact |
| `.gitignore` (additions) | config | — | existing `/.gitignore` (root file) | exact |
| `brandbook/README.md` (provenance update) | config/asset | — | existing `brandbook/README.md` (Logo System + Maintenance Rules sections) | exact |

---

## Pattern Assignments

### `scripts/brand/outline-wordmark.mjs` (utility, transform)

**No exact analog** — no `.mjs` scripts exist in the repo outside of `deps/`. The closest thing is the research's verified skeleton and the SVG conventions in `brandbook/logo-primary.svg`. The script structure follows bash script conventions from `scripts/ci/*.sh` (set header comment with purpose + run context).

**Header comment convention** (from `scripts/ci/snapshot-canary-guard.sh` lines 1–14):
```bash
#!/usr/bin/env bash
# Phase N (TICKET-ID): one-line summary of what this script does.
#
# Longer description of the algorithm and why it exists.
# References to related context.
set -euo pipefail
```

Adapt for `.mjs`:
```javascript
#!/usr/bin/env node
// Phase 179 (BRAND2-04): Outline OFL font glyphs for "sigra" into per-glyph SVG <path> elements.
//
// Usage: node scripts/brand/outline-wordmark.mjs <font.ttf> <wght> <output.svg>
// Run from repo root. Font must be downloaded to scripts/brand/fonts/ (gitignored).
// Requires: npm install in scripts/brand/ (opentype.js)
```

**SVG `<title>`/`<desc>` accessibility pattern** (from `brandbook/logo-primary.svg` lines 1–11):
```svg
<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="20 12 188 54"
  role="img"
  aria-labelledby="title desc"
>
  <title id="title">Sigra primary logo</title>
  <desc id="desc">
    The Sigra Rail Accent tight lockup for light surfaces. Wordmark outlined
    from Inter Display Black v4.1.
  </desc>
```

For generated outline SVGs, extend the `<desc>` with provenance:
```svg
<desc id="desc">Font: Space Grotesk v2.0.0 (OFL), wght=700. Outlined with opentype.js 2.0.0. Generated 2026-06-12.</desc>
```

**Wordmark glyph group with per-glyph `transform="translate(...)"` pattern** (from `brandbook/logo-primary.svg` lines 35–55):
```svg
<g fill="#151515" transform="translate(75 55)">
  <path d="M 16.5 0.5625 C ..." />           <!-- s glyph, no id, no translate — baseline offset on group -->
  <path d="M 2.015625 0 ..." transform="translate(32.890625 0)" />    <!-- i glyph -->
  <path d="M 14.8125 10.125 ..." transform="translate(46.296875 0)" />  <!-- g glyph -->
  <path d="M 2.015625 0 ..." transform="translate(76.296875 0)" />      <!-- r glyph -->
  <path d="M 9.609375 0.445312 ..." transform="translate(96.265625 0)" />  <!-- a glyph -->
</g>
```

**Note for outline-wordmark.mjs:** The existing `logo-primary.svg` uses a single `<g transform="translate(75 55)">` on the group and per-glyph `transform="translate(advanceX 0)"` on each `<path>`. The `forEachGlyph` API already returns absolute x coordinates, so the alternative (and preferred) pattern is to use absolute `d` data per glyph with index-based `id` attributes and no per-path transforms — eliminating the nested transform:

```svg
<g id="glyphs" fill="currentColor">
  <path id="g-0" d="M..." />   <!-- s -->
  <path id="g-1" d="M..." />   <!-- i -->
  <path id="g-2" d="M..." />   <!-- g -->
  <path id="g-3" d="M..." />   <!-- r -->
  <path id="g-4" d="M..." />   <!-- a -->
</g>
```

Use `fill="currentColor"` (not hardcoded `#151515`) on the `<g>` so dark-mode variants inherit correctly.

**viewBox convention** (from `brandbook/logo-primary.svg` line 4):
```
viewBox="20 12 188 54"
```
The existing primary logo trims the viewBox tightly around the content (x=20, y=12 — cropping empty left margin). For round-3 candidates with motif overflow (descenders, above-cap accents), add padding: `viewBox="-vbPad 0 totalWidth+2*vbPad vbHeight"` where `vbPad = fontSize * 0.05`.

---

### `scripts/brand/package.json` (config)

**Analog:** `test/example/priv/playwright/package.json`

**Package.json format** (full file, lines 1–17):
```json
{
  "name": "sigra-example-playwright",
  "version": "0.1.0",
  "private": true,
  "description": "Playwright browser smoke for test/example (phase 10.1.1)",
  "scripts": {
    "test": "playwright test",
    "install-browsers": "playwright install --with-deps chromium"
  },
  "devDependencies": {
    "@axe-core/playwright": "^4.10.0",
    "@playwright/test": "^1.48.0",
    "@simplewebauthn/browser": "^13.3.0",
    "otplib": "^12.0.1"
  }
}
```

Apply this pattern to `scripts/brand/package.json`:
- Use `"private": true` (no publishing)
- Description includes phase reference
- Use `"dependencies"` (not `"devDependencies"`) since opentype.js is a runtime dep of the script (not a test dev dep)
- No `"scripts"` entry required; the .mjs is invoked directly with `node`

```json
{
  "name": "sigra-brand-tools",
  "version": "0.1.0",
  "private": true,
  "description": "Brand toolchain scripts for Sigra (phase 179 BRAND2-04)",
  "type": "module",
  "dependencies": {
    "opentype.js": "^2.0.0"
  }
}
```

**Note:** The `"type": "module"` field is required so Node.js treats `.mjs` files and bare `import` statements correctly when running from this directory. Without it, `import { loadSync } from 'opentype.js'` in a `.mjs` file still works (`.mjs` always uses ESM), but `"type": "module"` is explicit and canonical.

---

### `brandbook/logo-options/round-3/*.svg` (assets)

**Analogs:** `brandbook/logo-primary.svg` (lines 1–56) and `brandbook/logo-mark.svg` (lines 1–8)

**Three ember tone hexes used in the mark** (from `brandbook/logo-mark.svg` and `brandbook/logo-primary.svg`):
```
ember-300: #fdba74   (outer rail bars, lighter orange)
ember-700: #c2410c   (inner rail bars, deep orange-red)
ember-800: #9a3412   (horizontal core line, darkest)
```

**Stroke attributes on the Rail Accent mark** (from `brandbook/logo-mark.svg` lines 4–6):
```svg
<path d="M17 14v14M32 23v18M47 36v14" fill="none" stroke="#fdba74" stroke-width="8" stroke-linecap="round"/>
<path d="M17 36v14M47 14v14" fill="none" stroke="#c2410c" stroke-width="8" stroke-linecap="round"/>
<path d="M17 32h30" fill="none" stroke="#9a3412" stroke-width="4" stroke-linecap="round"/>
```

All stroke paths use `fill="none"`, `stroke-linecap="round"`. The vertical rail bars use `stroke-width="8"`, the horizontal cross bar uses `stroke-width="4"`.

**Mark viewBox** (from `brandbook/logo-mark.svg` line 1):
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-labelledby="title desc">
```
The mark uses a square 64×64 viewport. For favicon candidates, preserve this convention.

**Wordmark-only (outlined path) group** (from `brandbook/logo-primary.svg` lines 35–55):
```svg
<g fill="#151515" transform="translate(75 55)">
  <!-- per-glyph <path> elements, no stroke, just filled paths -->
</g>
```
Outlined wordmark glyphs use only `fill` (no `stroke`). The fill color for light surface is `#151515`. For dark surface variants, swap to `#f4f1eb` (from round-2 gallery dark panel convention).

**SVG root element pattern for lockup files** (from `brandbook/logo-primary.svg` lines 1–11):
```svg
<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="20 12 188 54"
  role="img"
  aria-labelledby="title desc"
>
  <title id="title">Sigra primary logo</title>
  <desc id="desc">...</desc>
```

All candidate SVGs must follow: `role="img"`, `aria-labelledby="title desc"`, `<title id="title">`, `<desc id="desc">`.

---

### `brandbook/logo-options/round-3/index.html` (asset, gallery)

**Analog:** `brandbook/logo-options/round-2/index.html` (full file, lines 1–503)

**Head / CSS link pattern** (lines 1–8):
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sigra Logo Options — Round 3</title>
    <link rel="stylesheet" href="../../tokens.css">
```
Path `../../tokens.css` is fixed — gallery must live at `brandbook/logo-options/round-3/index.html`.

**Topbar / crumbs / status pill pattern** (lines 286–293):
```html
<div class="topbar">
  <nav class="crumbs" aria-label="Logo archive links">
    <a href="../round-2/index.html">Round 2 archive</a>
    <a href="../../index.html">Brandbook</a>
    <a href="README.md">Round 3 notes</a>
  </nav>
  <span class="status">Under review</span>
</div>
```
Change: update crumb href `../index.html` → `../round-2/index.html` (link back to round-2 explicitly), status pill from `"Archive study"` → `"Under review"` (or `"Pending ratification"`).

**Header code tag + h1 + lead pattern** (lines 295–307):
```html
<header>
  <div>
    <p class="code">Round 3 exploration / integrated typemarks / rail motif</p>
    <h1>Typemarks, not icon + text.</h1>
    <p class="lead">...</p>
    <ul class="rules" aria-label="Design constraints">...</ul>
  </div>
  <aside class="brief">...</aside>
</header>
```

**Per-option article pattern** (lines 316–350, one full option shown):
```html
<article class="option" id="option-3a1">
  <div class="option-head">
    <p class="code">A1</p>
    <h2>[Option Name]</h2>
    <p>[One-sentence concept description]</p>
  </div>
  <div class="preview">
    <div class="lockups">
      <div class="surface light">
        <div class="lockup">
          <img src="a1-typemark.svg" alt="">
          <span class="word"><strong>sigra</strong><span>[subtitle text]</span></span>
        </div>
      </div>
      <div class="surface dark">
        <div class="lockup">
          <img src="a1-typemark-dark.svg" alt="">
          <span class="word"><strong>sigra</strong><span>[subtitle text]</span></span>
        </div>
      </div>
    </div>
    <!-- mark-lab section: omit or replace with note for fully-integrated typemarks -->
    <div class="mark-lab">
      <div class="mark-stage"><img src="a1-favicon.svg" alt="A1 favicon mark"></div>
      <div class="favicons">
        <span class="favicon-sample"><img src="a1-favicon.svg" alt="" style="width:32px;height:32px">32px</span>
        <span class="favicon-sample"><img src="a1-favicon.svg" alt="" style="width:24px;height:24px">24px</span>
        <span class="favicon-sample"><img src="a1-favicon.svg" alt="" style="width:16px;height:16px">16px</span>
      </div>
    </div>
  </div>
  <div class="notes">
    <p><strong>Strength:</strong> ...</p>
    <p><strong>Risk:</strong> ...</p>
    <div class="scores">
      <div class="score"><span>Appeal</span><div class="meter"><span style="width:80%"></span></div></div>
      <div class="score"><span>Distinctive</span><div class="meter"><span style="width:85%"></span></div></div>
      <div class="score"><span>Concept</span><div class="meter"><span style="width:90%"></span></div></div>
    </div>
    <div class="test">Tests whether [specific hypothesis from brief rubric].</div>
  </div>
</article>
```

**With-subtitle preview variant** (per CONTEXT.md requirement — not in round-2 but required for round-3 finalist-grade options). Add a second `.lockups` block below the main lockup block:
```html
<!-- Subtitle variant (finalist-grade options only) -->
<div class="lockups" style="margin-top: var(--sigra-space-2)">
  <div class="surface light">
    <div class="lockup">
      <img src="a1-typemark.svg" alt="">
      <span class="word"><strong>sigra</strong><span>Phoenix auth that ships</span></span>
    </div>
  </div>
  <div class="surface dark">
    <div class="lockup">
      <img src="a1-typemark-dark.svg" alt="">
      <span class="word"><strong>sigra</strong><span>Phoenix auth that ships</span></span>
    </div>
  </div>
</div>
```

**Surface classes for light/dark panels** (lines 158–167):
```css
.surface.light {
  background: #f6f5f2;
  color: #151515;
  box-shadow: inset 0 0 0 1px rgba(21,21,21,0.10);
}
.surface.dark {
  background: #151515;
  color: #f4f1eb;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.12);
}
```

**Favicon row pattern** (lines 333–338):
```html
<span class="favicon-sample"><img src="option-2a-rails-path.svg" alt="" style="width:32px;height:32px">32px</span>
<span class="favicon-sample"><img src="option-2a-rails-path.svg" alt="" style="width:24px;height:24px">24px</span>
<span class="favicon-sample"><img src="option-2a-rails-path.svg" alt="" style="width:16px;height:16px">16px</span>
```
Three sizes: 32px, 24px, 16px. Inline `style="width:Npx;height:Npx"` — not CSS classes.

---

### `brandbook/logo-options/round-3/README.md` (asset)

**Analog:** `brandbook/logo-options/round-2/README.md` (full file, lines 1–18)

**Full format to replicate** (lines 1–18):
```markdown
# Sigra Logo Options — Round 3

[One-sentence description of what round 3 explores vs round 2.]

The active Sigra logo source set lives in the parent `brandbook/` directory.

## Files

| Option | File | What it tests |
| --- | --- | --- |
| A1 Rail-i typemark | [`a1-rail-i-typemark.svg`](a1-rail-i-typemark.svg) | [Hypothesis sentence.] |
| A2 Descender-rail typemark | [`a2-descender-rail-typemark.svg`](a2-descender-rail-typemark.svg) | [Hypothesis sentence.] |
...

Open [`index.html`](index.html) to compare mark-only, light/dark lockup, and favicon previews.
```

Column order: Option code + name | File (linked) | What it tests.
Separator row uses `| --- | --- | --- |` (three cells, no alignment markers).

---

### `.gitignore` (additions)

**Analog:** existing `/.gitignore` (full file, lines 1–49)

**Insertion pattern** — the existing file uses grouped sections with blank-line separators and a `# Comment` header per group. The new entries fit naturally after the `# Temporary files` block (line 25) or as a new group at the end.

**Existing structure around the insertion point** (lines 24–28):
```
# Temporary files, for example, from tests.
/tmp/

# IDE
.elixir_ls/
```

**Append as a new group at the end of the file** (after line 49):
```
# Brand toolchain — font binaries and render artifacts (never commit font TTFs).
/scripts/brand/node_modules/
/scripts/brand/fonts/
```

`/tmp/` is already covered (line 25). The render outputs go to `/tmp/sigra-renders/` which is inside the already-ignored `/tmp/` tree, so no additional entry is needed for renders.

---

### `brandbook/README.md` (provenance update)

**Analog:** existing `brandbook/README.md` — specifically the `## Logo System` section (lines 28–33) and `## Maintenance Rules` section (lines 34–48).

**Current Logo System section to extend** (lines 28–33):
```markdown
## Logo System

The current logo files are the Sigra Rail Accent assets. Use the tight lockup for primary identity, the dark lockup for dark surfaces, and the free-standing mark for lightweight UI accents, favicon, and avatar surfaces. [`logo-options/`](logo-options/) is archive material, not usage guidance.

The lockup wordmark is outlined from Inter Display Black v4.1. The SVGs should remain path-only so the logo renders identically without installing fonts or loading a runtime web font.
```

**Add a new "Font Provenance" subsection** immediately after the Logo System paragraph, before Maintenance Rules:
```markdown
## Font Provenance

Round-3 candidate wordmarks are outlined using opentype.js 2.0.0 (MIT) from OFL-licensed variable TTFs. Font binaries are gitignored; only the resulting SVG path data is committed. Each candidate SVG `<desc>` records: font name, version, OFL license, opentype.js version, and generation date.

| Font | Version | License | Source | Used in |
| --- | --- | --- | --- | --- |
| Inter Display | v4.1 | OFL | github.com/rsms/inter | logo-primary.svg (v1), round-3 A4 candidate |
| Space Grotesk | v2.0.0 | OFL | github.com/floriankarsten/space-grotesk | Round-3 A1, B1 candidates |
| Plus Jakarta Sans | v2.7.1 | OFL | github.com/tokotype/PlusJakartaSans | Round-3 A2, C1 candidates |
| Syne | latest | OFL | github.com/google/fonts/ofl/syne | Round-3 A3 candidate |
| Geist | v1.7.2 | OFL | github.com/vercel/geist-font | Round-3 B2 candidate |
```

**Existing Maintenance Rules to preserve verbatim** (lines 34–48) — the `Do not add font files` rule is already present; no edit needed there.

---

## Shared Patterns

### SVG Accessibility Shell
**Source:** `brandbook/logo-primary.svg` lines 1–11 and `brandbook/logo-mark.svg` line 1
**Apply to:** All candidate SVG files in `round-3/`

Every SVG must have:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="..." role="img" aria-labelledby="title desc">
  <title id="title">...</title>
  <desc id="desc">...</desc>
```

### Ember Color Palette
**Source:** `brandbook/logo-mark.svg` lines 4–6
**Apply to:** All candidate SVGs that incorporate the Rail Accent motif or ember accents

```
#fdba74  ember-300  (lighter rail bars, tittle replacements, accent dots)
#c2410c  ember-700  (inner/secondary rail elements)
#9a3412  ember-800  (horizontal core line, heaviest accent)
```

Candidates may tune hue within 15–40° per design brief. These are the locked baseline values.

### Light/Dark Wordmark Fill Colors
**Source:** `brandbook/logo-primary.svg` line 35 (light) + `brandbook/logo-options/round-2/index.html` surface class definitions
**Apply to:** All candidate SVG light/dark pairs

```
Light surface wordmark fill: #151515
Dark surface wordmark fill:  #f4f1eb
```

Use `fill="currentColor"` on outlined-path groups in SVGs intended for CSS-context use. Use hardcoded hex only in standalone lockup SVGs where `currentColor` won't resolve.

### Gallery tokens.css Link
**Source:** `brandbook/logo-options/round-2/index.html` line 7
**Apply to:** `round-3/index.html`

```html
<link rel="stylesheet" href="../../tokens.css">
```

This path only works when the gallery is exactly at `brandbook/logo-options/round-3/index.html`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `scripts/brand/critique-render.mjs` | utility | file-I/O + Playwright | No existing Node scripts in `scripts/`; all scripts are bash. Patterns from RESEARCH.md Pattern 3 (Playwright standalone screenshot) are the primary reference. |

---

## Metadata

**Analog search scope:** `brandbook/`, `brandbook/logo-options/round-2/`, `scripts/`, `test/example/priv/playwright/`
**Files read:** `logo-primary.svg`, `logo-mark.svg`, `logo-options/round-2/index.html`, `logo-options/round-2/README.md`, `brandbook/README.md`, `test/example/priv/playwright/package.json`, `.gitignore`, `scripts/ci/snapshot-canary-guard.sh` (header convention)
**Pattern extraction date:** 2026-06-12
