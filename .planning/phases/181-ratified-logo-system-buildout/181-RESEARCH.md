# Phase 181: Ratified Logo System Buildout — Research

**Researched:** 2026-06-12
**Domain:** SVG brand asset production, logo system buildout, brandbook archival
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Ratified design:** D4 Linked Rail — Space Grotesk v2.0 (OFL) wght 700 outlined "sigra"; ember rail-block tittle; g tail extended to x=557 with tip aligned under tittle's left edge. One bracketing rail system around "ig". Do not reopen.
- **Mark/favicon:** the abstract rail glyph from `d4-linked-rail-favicon.svg` (ink stem + leftward foot + ember block, no letter). The "ig" crop is permanently retired.
- **Palette:** ember-700 `#c2410c` on light; ember-300 `#fdba74` on dark. Fine-tuning permitted ONLY within hue 15–40° only if measurably improving contrast/legibility. Any value change must be recorded for Phase 182 token bump and Phase 183 sg-* sync.
- **Hard constraints from design brief still bind:** no rectangular container, subtitle-free main lockup, tight logotype proximity, viewBox padding must contain boundary-breaking geometry (54px admin topbar slot must not clip).
- **Asset set (BRAND2-08):** `logo-primary.svg`, `logo-primary-dark.svg`, `logo-primary-subtitle.svg` (ONLY variant with subtitle), `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, `social-card.svg` + dark variant. SVG-only; no raster; no font binaries.
- **Render verification:** every asset verified through committed Playwright `file://` harness at intended sizes; renders throwaway (never committed); executor must Read PNGs, not just run harness.
- **Archive:** v1 assets MOVED (git mv) into `brandbook/logo-options/archive-v1/` with deprecation note.
- **Do NOT touch:** `priv/templates/` or `test/example/` copies — Phase 183 scope.

### Claude's Discretion

- Exact subtitle text/styling for the subtitle variant (brand voice: "Phoenix auth that ships" is the gallery convention).
- Social card composition (must feature D4 lockup + mark; OG-standard 1200×630 viewBox).
- Monochrome strategy (single-ink rendition that keeps tittle/tail geometry legible without color).
- Whether minor palette micro-tuning is warranted — default is no change.

### Deferred Ideas (OUT OF SCOPE)

- `brandbook/index.html` v2 + tokens version bump → Phase 182
- Installer/example propagation + sg-* sync + Playwright baseline recapture → Phase 183
- README header / GitHub social preview adoption → post-milestone fast-follow
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND2-08 | Full ratified asset set ships: `logo-primary.svg`, `logo-primary-dark.svg`, separate `logo-primary-subtitle.svg`, `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, and social cards (light and dark), each render-verified, with clearspace, minimum sizes, and misuse rules documented. | Source geometry fully inventoried from round-4 SVGs; v1 conventions documented; SVG accessibility pattern established; render harness confirmed operational; archive strategy defined. |
</phase_requirements>

---

## Summary

Phase 181 is an SVG production phase with no new external dependencies. The ratified D4 Linked Rail geometry already exists as clean, production-quality SVGs in `brandbook/logo-options/round-4/`; the production asset set is derived directly from those files by: (1) copying or adapting the SVG content, (2) updating `<title>/<desc>` provenance to production language, and (3) producing three net-new files (`logo-primary-subtitle.svg`, `social-card-dark.svg`, and, depending on naming, a v2 `social-card.svg`). Exactly six v1 files are archived (`logo-primary.svg`, `logo-primary-dark.svg`, `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, `social-card.svg`) via `git mv` into `brandbook/logo-options/archive-v1/`, and new v2 files are written at the same canonical paths so `brandbook/index.html` never has broken `src` references. The examples specimens (`examples/readme-header.svg`, `examples/landing-hero.svg`) embed v1 mark geometry inline and are NOT broken by the mv; they are Phase 182/183 scope. The `priv/templates/` and `test/example/priv/static/images/` files use a different naming convention (`sigra-logo-primary.svg`) and are untouched until Phase 183.

**Primary recommendation:** Derive every production SVG directly from the round-4 d4 source files. The glyph path data is already correct; the only authoring work per file is adjusting `<title>`, `<desc>`, fill tokens, and viewBox to match each variant's requirements. Build the render harness HTML files in `/tmp/` per the Phase 179 pattern, run `critique-render.mjs`, Read the PNGs, then commit assets. Archive v1 in the same commit to keep `index.html` references continuously live.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SVG asset production | Brandbook (static files) | — | All assets are static files; no runtime component |
| Render verification | Scripts / Playwright harness | — | `critique-render.mjs` drives Chromium at `file://` URLs |
| Archive / git provenance | Git (mv + new write) | — | git mv preserves rename history; new write at same path means index.html never broken |
| Usage rule documentation | `brandbook/README.md` | `brandbook/brand-book.md` | README gets machine-verifiable clearspace/min-size table; brand-book.md updated logo system section |
| No runtime propagation | — | — | Phase 183 handles priv/templates and test/example |

---

## Standard Stack

### Core (already installed — no new installs)

| Tool | Version | Purpose | Status |
|------|---------|---------|--------|
| opentype.js | 2.0.0 | Outline font glyphs to SVG paths (already used for D4 source) | `[VERIFIED: scripts/brand/node_modules/opentype.js present]` |
| playwright-core | (Chromium 1223) | Headless render verification via `critique-render.mjs` | `[VERIFIED: test/example/priv/playwright/node_modules/]` |
| xmllint | system | SVG parse validation | `[VERIFIED: /usr/bin/xmllint present]` |
| python3 | 3.14.4 | Batch SVG XML parse checks | `[VERIFIED: command -v python3]` |

### No New Packages

This phase installs zero new npm or hex packages. All tooling was established in Phase 179 (outline-wordmark.mjs) and Phase 179 (critique-render.mjs). The `scripts/brand/` node_modules and `test/example/priv/playwright/` node_modules are already present.

---

## Package Legitimacy Audit

> No new packages installed in this phase. Existing toolchain (opentype.js 2.0.0, playwright-core) was verified in Phase 179.

| Package | Registry | Status in Phase 181 | Disposition |
|---------|----------|---------------------|-------------|
| opentype.js | npm | Pre-existing — not reinstalled | N/A |
| playwright-core | npm | Pre-existing — not reinstalled | N/A |

**Packages removed due to slopcheck [SLOP] verdict:** none — no new packages.

---

## V1 Asset Inventory (Files to Archive)

[VERIFIED: codebase grep + direct file read]

### Files under `brandbook/` that will be archived (git mv → `brandbook/logo-options/archive-v1/`)

| File | Current Path | v1 Concept | viewBox | Status |
|------|-------------|------------|---------|--------|
| `logo-primary.svg` | `brandbook/logo-primary.svg` | Rail Accent staircase mark + Inter Display Black wordmark | `20 12 188 54` | EXISTS — REPLACE |
| `logo-primary-dark.svg` | `brandbook/logo-primary-dark.svg` | Same, dark wordmark fill `#f4f1eb` | `20 12 188 54` | EXISTS — REPLACE |
| `logo-mark.svg` | `brandbook/logo-mark.svg` | 3-bar Rail Accent staircase mark | `0 0 64 64` | EXISTS — REPLACE |
| `logo-monochrome.svg` | `brandbook/logo-monochrome.svg` | Monochrome Rail Accent mark, opacity=0.72 secondary | `0 0 64 64` | EXISTS — REPLACE |
| `favicon.svg` | `brandbook/favicon.svg` | 3-bar Rail Accent, identical geometry to logo-mark | `0 0 64 64` | EXISTS — REPLACE |
| `social-card.svg` | `brandbook/social-card.svg` | OG 1200×630 with Rail Accent mark, tagline, install snippet | `0 0 1200 630` | EXISTS — REPLACE |

### Files that do NOT exist yet (net-new):

| File | Status |
|------|--------|
| `logo-primary-subtitle.svg` | MISSING — new file |
| `social-card-dark.svg` | MISSING — new file (dark surface OG card) |

---

## `brandbook/index.html` Reference Analysis

[VERIFIED: grep of brandbook/index.html]

The following `<img src="...">` references appear in `brandbook/index.html`:

| src value | Line(s) | Impact of git mv strategy |
|-----------|---------|--------------------------|
| `favicon.svg` | 327 | Must be replaced atomically with mv; new v2 file written at same path in same commit |
| `logo-primary-dark.svg` | 346 | Same |
| `logo-primary.svg` | 433 | Same |
| `logo-primary-dark.svg` | 434 | Same |
| `logo-mark.svg` | 435 | Same |
| `favicon.svg` | 436 | Same |
| `logo-monochrome.svg` | mentioned only in text (line 443), NOT as `<img src>` | No img reference — no breakage risk |
| `social-card.svg` | Not referenced in index.html img src | No breakage risk |

**Archive strategy:** All six referenced v1 files must have their new v2 content written to the same canonical path BEFORE or IN THE SAME COMMIT as the `git mv` of the old content to `archive-v1/`. In practice: copy old file content to archive path with Write tool, then overwrite canonical path with new v2 content. Git tracks the archive write as new and the canonical path as modified — clean history. A single `git add` + `git commit` keeps the index.html references live throughout.

**Deferred to Phase 182:** `brandbook/index.html` text content still refers to the old "Rail Accent" concept and needs a full rewrite. The v2 img `src` attributes will render the new D4 assets correctly once the files are replaced, but the surrounding prose (section titles, rules copy) remains v1 until Phase 182.

---

## SVG Conventions Established in v1

[VERIFIED: direct read of brandbook/logo-primary.svg, logo-mark.svg, logo-monochrome.svg, favicon.svg, social-card.svg]

### Accessibility shell pattern (MUST carry into all v2 files)

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="..." role="img" aria-labelledby="title desc">
  <title id="title">Sigra [variant description]</title>
  <desc id="desc">[Font provenance + design description]</desc>
  ...
</svg>
```

The `role="img"` + `aria-labelledby="title desc"` pattern is established in EVERY v1 file and EVERY round-4 candidate. All v2 files MUST continue this pattern.

### `<desc>` provenance content required

The round-4 D4 files establish the template:

```
Font: Space Grotesk v2.0 (OFL) wght=700. [Design description]. Derived from round-3 a1 outlines (opentype.js 2.0.0). Generated [YYYY-MM-DD].
```

Production v2 `<desc>` should update the date and change "Round-4 A1 refinement D4: ..." to production language like "Sigra D4 Linked Rail production asset."

### Fill color conventions

| Context | Glyph fill | Ember accent |
|---------|-----------|--------------|
| Light surface (primary) | `#151515` (ink) | `#c2410c` (ember-700) |
| Dark surface (primary-dark) | `#f4f1eb` (warm white) | `#fdba74` (ember-300) |
| Monochrome | `#151515` (single ink) | `#151515` (same ink — ember rect becomes solid ink) |
| Favicon (with media query) | CSS: `#151515` / `#f4f1eb` | CSS: `#c2410c` / `#fdba74` |

### Dark variant structure

v1 dark variants use a hardcoded `fill="#f4f1eb"` on the glyph group — NOT `currentColor`. The round-4 dark variants follow the same pattern. The v2 files should maintain hardcoded fills (not `currentColor`) to match the established convention and avoid CSS inheritance surprises.

### viewBox conventions

| Variant | viewBox convention |
|---------|-------------------|
| Typemark (primary, dark, subtitle) | Derived from D4 source: `0 220 2410 1026` (shows tittle top at y=246, descender plate to y=1200, comfortable padding) |
| Mark (logo-mark.svg) | Square units, comfortable padding around mark geometry |
| Favicon | Square aspect: `-70 -60 1040 1040` (width=height=1040) with padding — keep exactly from d4-linked-rail-favicon.svg |
| Social card | `0 0 1200 630` with explicit `width="1200" height="630"` attributes (OG standard) |

---

## Architecture Patterns

### Recommended Asset File Structure (after Phase 181)

```
brandbook/
├── logo-primary.svg              # v2 D4 light surface typemark
├── logo-primary-dark.svg         # v2 D4 dark surface typemark
├── logo-primary-subtitle.svg     # v2 D4 + subtitle text below
├── logo-mark.svg                 # v2 D4 abstract rail glyph (full color)
├── logo-monochrome.svg           # v2 D4 typemark in single ink
├── favicon.svg                   # v2 D4 mark, square, with prefers-color-scheme
├── social-card.svg               # v2 light OG card 1200×630
├── social-card-dark.svg          # v2 dark OG card 1200×630 (new)
├── README.md                     # Updated: clearspace, min-sizes, misuse examples, v2 font provenance
├── logo-options/
│   ├── archive-v1/               # git mv destination for all v1 production files
│   │   ├── logo-primary.svg      # archived v1 Rail Accent lockup
│   │   ├── logo-primary-dark.svg
│   │   ├── logo-mark.svg
│   │   ├── logo-monochrome.svg
│   │   ├── favicon.svg
│   │   ├── social-card.svg
│   │   └── README.md             # deprecation note
│   ├── round-4/                  # source geometry (unchanged — kept as ratification record)
│   └── round-3/, round-2/, ...   # unchanged
└── examples/                     # unchanged until Phase 182/183
```

### SVG Architecture Diagram (data flow)

```
Round-4 source SVG
  d4-linked-rail-typemark.svg
  d4-linked-rail-typemark-dark.svg      --> adapt --> logo-primary.svg (light)
  d4-linked-rail-favicon.svg                         logo-primary-dark.svg
                                                     logo-primary-subtitle.svg (extend viewBox)
                                        --> adapt --> logo-mark.svg (same glyph geometry, re-titled)
                                        --> adapt --> logo-monochrome.svg (ember rect → solid ink)
                                        --> keep  --> favicon.svg (direct copy + updated provenance)

Authoring (manual SVG edit)            --> build  --> social-card.svg (1200×630, embed D4 typemark paths)
                                       --> build  --> social-card-dark.svg (dark surface variant)

All 8 files
  ↓
Playwright harness HTML (in /tmp/)
  ↓
critique-render.mjs → PNG screenshots
  ↓
Human reads PNGs (16px favicon kill test, 54px topbar, hero, social thumbnail)
  ↓
Pass → commit assets + archive v1
```

### Render Harness Pattern (from Phase 179)

The render verification uses inline file:// HTML pages — no server required.

```javascript
// critique-render.mjs — already committed and working
// Usage:
node scripts/brand/critique-render.mjs /tmp/sigra-v2-harness.html /tmp/sigra-v2-renders/
// Produces: PNG screenshots at 16px-favicon, 32px, 54px-topbar, hero × light, dark
```

Harness HTML template pattern (wrap each SVG in a scaled container):

```html
<!doctype html>
<html>
<head><meta charset="utf-8"><style>
  body { margin: 0; background: #f6f5f2; } /* light surface test */
  .item { display: inline-block; padding: 12px; }
  .at-54 img { height: 54px; width: auto; }
</style></head>
<body>
  <div class="item at-54"><img src="file:///path/to/brandbook/logo-primary.svg"></div>
  ...
</body>
</html>
```

---

## D4 Source Geometry Reference

[VERIFIED: direct read of round-4 SVG files]

### Typemark geometry (`d4-linked-rail-typemark.svg`)

- **viewBox:** `0 220 2410 1026` — shows y=220 (tittle top at y=246) through y=1246 (comfortable below descender plate at y=1200)
- **Glyph group:** `<g id="glyphs" fill="#151515">` with 5 paths: g-0 (s), g-1 (i), g-2 (g, includes descender plate to y=1200), g-3 (r), g-4 (a)
- **Ember rect:** `<rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#c2410c">`
- **Dark variant:** identical glyph paths with `fill="#f4f1eb"` and ember rect `fill="#fdba74"`
- **Key invariant:** x=557 is SHARED by both the tittle left edge and the g tail endpoint — this is the "one rail system" geometry

### Mark / favicon geometry (`d4-linked-rail-favicon.svg`)

- **viewBox:** `-70 -60 1040 1040` (square, with padding)
- **Ink geometry:**
  - Stem: `<rect x="540" y="360" width="180" height="580">`
  - Foot (g-tail echo): `<rect x="180" y="760" width="540" height="180">`
- **Ember block:** `<rect id="rail-block" x="400" y="-20" width="320" height="320">`
- **Media query:** `@media (prefers-color-scheme: dark) { #glyphs { fill: #f4f1eb; } #rail-block { fill: #fdba74; } }`
- **Production favicon:** use this file essentially as-is; update `<title>` and `<desc>` to production language

---

## Per-Asset Production Notes

### `logo-primary.svg`

Derive from `d4-linked-rail-typemark.svg`. Only changes needed:
1. Update `<title>` → `"Sigra primary logo"`
2. Update `<desc>` → `"The Sigra D4 Linked Rail typemark for light surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0. Ember-700 (#c2410c) rail tittle and g-tail bracket. See brandbook/README.md for usage rules."`
3. Keep `viewBox="0 220 2410 1026"` (contains all geometry including 54px topbar fit)
4. Glyph fill: `#151515` (already correct in source)
5. Ember rect fill: `#c2410c` (already correct in source)

### `logo-primary-dark.svg`

Derive from `d4-linked-rail-typemark-dark.svg`. Only changes:
1. Update `<title>` → `"Sigra primary logo for dark surfaces"`
2. Update `<desc>` → same as primary but note "for dark surfaces" and ember-300 `#fdba74`
3. Glyph fill: `#f4f1eb` (already correct)
4. Ember rect fill: `#fdba74` (already correct)

### `logo-primary-subtitle.svg`

Net-new file. Strategy:
1. Start from `d4-linked-rail-typemark.svg` glyph + ember rect (light surface variant)
2. Extend viewBox downward to accommodate subtitle text below the descender plate
   - Current bottom: y=1246 (220+1026); descender plate at y=1200
   - Add ~350–450 units below for subtitle: new viewBox height ≈ 1350–1450
   - New viewBox: `"0 220 2410 1380"` (example; tune after render)
3. Add subtitle as SVG `<text>` element below the wordmark baseline
   - Position: y ≈ 1320 (below descender plate at y=1200)
   - Font: `font-family="ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"` (system font stack, consistent with social-card.svg)
   - Recommended text: `"Phoenix auth that ships"` (established gallery convention)
   - Font size: ~180–220 units (≈18% of wordmark height — proportional to glyphs at ~510u cap height)
   - Fill: `#686868` (muted text — matches v1 social card muted class)
4. The subtitle is baked-in SVG text (NOT outlined paths — it doesn't need outline stability because it uses a system font fallback)
5. Title: `"Sigra primary logo with subtitle"`

### `logo-mark.svg`

Derive from `d4-linked-rail-favicon.svg`. Remove the `<style>` media query (mark SVG is not used as a browser tab favicon; it uses explicit fills instead). Assign explicit fills:
- `#glyphs fill="#151515"`
- `#rail-block fill="#c2410c"`
- Update `<title>` → `"Sigra mark"`
- Update `<desc>` → `"Sigra D4 Linked Rail free-standing mark for light surfaces. Ink stem + leftward foot + ember-700 (#c2410c) rail block. Use on light surfaces."`
- Keep `viewBox="-70 -60 1040 1040"`

Alternative: keep the media query for automatic light/dark switching if the mark is expected to be used in SVG `<img>` contexts. [DISCRETION: recommended to keep the media query for DX — the mark file then "just works" in both light and dark HTML contexts without needing a dark variant file.]

### `logo-monochrome.svg`

Monochrome strategy for D4:
- The two-color system: ink glyphs + ember rail block
- Monochrome collapse: ember block becomes solid ink (same fill as glyphs)
- The spatial geometry (tittle bracket above + tail bracket below at x=557) is preserved in ink without color
- The tittle/tail read survives because the POSITION relationship (both at x=557) is structural, not color-dependent
- Recommended approach: solid ink rect (not outlined stroke, not reduced opacity)
  - Why: the v1 monochrome used opacity=0.72 for SEPARATE elements in a multi-bar mark; in D4, the block and tail are spatially defined by position, so solid ink is cleaner and more honest
  - The block at 200×200 units is large enough to be visually distinct at solid ink without needing opacity tricks
- Implementation:
  - Copy typemark paths from d4-linked-rail-typemark.svg
  - Set glyph group fill: `#151515`
  - Set ember rect fill: `#151515` (same ink)
  - Keep viewBox identical to logo-primary.svg
  - `<title>`: `"Sigra monochrome logo"`
  - `<desc>`: `"Sigra D4 Linked Rail typemark in single ink for restricted-color contexts. No color distinction between wordmark and rail accents."`

### `favicon.svg`

Essentially a copy of `d4-linked-rail-favicon.svg` with production `<title>` and `<desc>`:
- Keep the `<style>` block with `prefers-color-scheme` media query (correct production behavior)
- Keep `viewBox="-70 -60 1040 1040"` (square, confirmed passing 16px kill test)
- Update `<title>` → `"Sigra"`
- Update `<desc>` → `"Sigra D4 Linked Rail favicon mark. Abstract rail glyph: ink stem, leftward foot, ember rail block. Adapts to dark mode via prefers-color-scheme."`
- Ember block: ember-700 on light (`#c2410c`), ember-300 on dark (`#fdba74`) — per ratification record

### `social-card.svg` (v2, light)

OG-standard 1200×630, explicit width+height attributes. Structure:
- `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-labelledby="title desc">`
- Background: warm `#f6f5f2`
- Feature the D4 typemark prominently (embed glyph paths inline, scaled to ~180–200px height on the card)
- Include the abstract rail mark as a secondary/background element or in a right-side panel
- Tagline: retained from v1 brand voice OR updated to current voice ("Phoenix auth that ships" / "Auth you can keep patching after install")
- Install snippet: `mix sigra.install Accounts User users` in monospace code block
- Maintain the panel composition pattern from v1 (white rect with rounded corners, top ink bar)
- v1 social card used inline path data for the v1 mark — v2 must use D4 path data

### `social-card-dark.svg` (v2, dark)

Dark surface variant for GitHub social preview context (dark mode):
- `viewBox="0 0 1200 630"` with explicit `width="1200" height="630"`
- Background: `#171614` (established dark surface color from round-4 gallery)
- Wordmark fill: `#f4f1eb`, ember accent: `#fdba74`
- Mirror the light card's layout with adjusted fills
- GitHub social preview renders at ~600×315 or smaller thumbnails — keep element sizes legible at 50% scale

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SVG parse validation | Custom parser | `xmllint --noout` + `python3 xml.etree.ElementTree` | Already established in Phase 179 acceptance criteria |
| Headless PNG render | Custom screenshot | `critique-render.mjs` via playwright-core | Already committed, battle-tested in Phase 179 |
| Font glyph outlining | Custom font parser | `outline-wordmark.mjs` (opentype.js 2.0.0) | Already committed; Phase 181 does NOT need to re-run outlining — D4 paths are final |
| Dark mode CSS injection in SVG | Runtime JS | `@media (prefers-color-scheme: dark)` in `<style>` block | Established in d4-linked-rail-favicon.svg; browser support is near-universal |

**Key insight:** Phase 181 does NOT invoke `outline-wordmark.mjs`. The glyph paths in the round-4 D4 SVGs are already correct production-quality outlines. The phase is SVG adaptation + new composition work, not a re-outline run.

---

## Common Pitfalls

### Pitfall 1: Archive before write — broken index.html window

**What goes wrong:** Running `git mv logo-primary.svg logo-options/archive-v1/logo-primary.svg` without immediately writing the new v2 content at `brandbook/logo-primary.svg` leaves `brandbook/index.html` pointing at a missing file in the working tree.
**Why it happens:** Treating archive and new-write as separate commits or tasks.
**How to avoid:** In the same task that archives, write the new v2 content. Commit both together. Never commit the archive without the replacement.
**Warning signs:** `git status` shows a deletion at `brandbook/logo-primary.svg` with no corresponding addition.

### Pitfall 2: Copying wrong dark ember value

**What goes wrong:** Using `#c2410c` (ember-700) in the dark variant instead of `#fdba74` (ember-300).
**Why it happens:** Copy-paste from the light typemark without updating the ember rect fill.
**How to avoid:** After writing each dark variant, grep for `#c2410c` — should return 0 hits in dark files.
**Warning signs:** `grep '#c2410c' brandbook/logo-primary-dark.svg` returns a match.

### Pitfall 3: Subtitle text as outlined paths

**What goes wrong:** Trying to outline the subtitle text with `outline-wordmark.mjs` at a different font size.
**Why it happens:** Treating the subtitle like the wordmark.
**How to avoid:** Subtitle in `logo-primary-subtitle.svg` is SVG `<text>` with a system font stack. It doesn't need outline stability (it's a secondary variant with no pixel-perfect size requirement). The main wordmark IS outlined because it must render identically at every size — the subtitle is allowed to use system fonts.
**Warning signs:** Spending time running `outline-wordmark.mjs` for subtitle text.

### Pitfall 4: Favicon viewBox not square

**What goes wrong:** Accidentally changing the viewBox to a non-square aspect ratio, causing distortion in browser favicon rendering.
**Why it happens:** Misreading the `-70 -60 1040 1040` as non-square because of the negative offsets.
**How to avoid:** The 3rd and 4th numbers are WIDTH and HEIGHT — both are 1040, so it IS square. Do not change these values.
**Warning signs:** `width != height` in the viewBox 3rd/4th position.

### Pitfall 5: Monochrome with no legibility of rail system

**What goes wrong:** Using the same fill for both glyphs and the ember block causes the block to "disappear" into the wordmark visually.
**Why it happens:** Expecting the D4 monochrome to work the same as a two-element mark.
**How to avoid:** The D4 system works because the ember block is ABOVE the letterform (tittle position) and spatially separated from the glyph strokes — it reads as distinct geometry even at the same ink color. Verify at 54px: the block must read as visually distinct from the i stem.
**Warning signs:** At 54px, the i and its tittle/block look like a single merged blob.

### Pitfall 6: Social card uses web font text

**What goes wrong:** Using a Google Fonts CDN link in the social card SVG for text rendering.
**Why it happens:** Wanting font consistency with the wordmark.
**How to avoid:** The social card uses system font stacks for non-wordmark text (established in v1). The wordmark is inline path data (no font dependency). Do NOT add CDN links to any brandbook SVG.
**Warning signs:** Any `<link>` or `@import url(` in social-card.svg.

---

## Clearspace and Minimum Size Documentation

[VERIFIED: brand-book.md current docs + D4 geometry analysis]

### Current v1 documentation (to be updated in brandbook/README.md)

Brand-book.md currently states:
- `Minimum mark size: 16px favicon, 24px UI, 40px marketing.`
- `Clearspace: at least one quarter of the mark width.`

### v2 documentation plan for brandbook/README.md

The D4 mark geometry (from d4-linked-rail-favicon.svg):
- Mark bounding box: x[180..720], y[-20..940] → width=540, height=960 (in 1040-unit viewBox)
- Mark-relative unit (M) = mark height = 960 viewport units ≈ 0.92× viewBox side
- Clearspace = 0.25M = 240 viewport units ≈ 23% of viewBox

Proposed minimum sizes table:

| Context | Minimum rendered height | Rationale |
|---------|------------------------|-----------|
| Favicon (kill test) | 16px | Abstract rail glyph passes at 16px (confirmed round-4) |
| UI accent (mark only) | 24px | Block + stem readable at 24px |
| Topbar lockup | 32px | Wordmark + rail bracket legible from 32px; 54px is the target |
| Marketing/docs | 120px | Full typemark with subtitle; under 120px subtitle text becomes hard to read |

Proposed clearspace rule (mark-relative units):
- Minimum clearspace around the mark = 0.25× mark height (one-quarter-mark rule)
- For the typemark, minimum margin = 0.15× rendered height of the wordmark

### Misuse examples (≥4 required)

1. **Incorrect surface:** Using `logo-primary.svg` (black ink wordmark) on a dark background — wordmark becomes invisible. Use `logo-primary-dark.svg` on dark surfaces.
2. **Scaling below minimum:** Displaying the typemark below 32px where the "sigra" wordmark letters are no longer distinguishable — use the favicon mark instead.
3. **Adding a rectangular container:** Wrapping the mark in a box/badge/pill shape — violates the hard constraint; the mark is designed to be boundary-breaking and must sit on transparent/colored surfaces.
4. **Substituting a different ember hue:** Replacing the ember `#c2410c` with a bright orange or red — moves the brand outside the hue 15–40° band, loses the distinctive brick-red differentiation from Phoenix Framework and Ash.
5. **Rotating or reflecting the mark:** The rail direction (stem vertical, foot horizontal leftward, block upper-right) is the directional system — rotation breaks the spatial metaphor.
6. **Applying the wordmark as live text:** Recreating "sigra" in any font at runtime — the wordmark is path-outlined to prevent font substitution; live text will not match.

---

## Render Verification Architecture

[VERIFIED: direct read of scripts/brand/critique-render.mjs + Phase 179 VALIDATION.md patterns]

### Render Profile (from Phase 179 critique-render.mjs)

| Scale name | Viewport width | Viewport height | Purpose |
|------------|---------------|----------------|---------|
| `16px-favicon` | 64 | 64 | Kill test — favicon legibility |
| `32px` | 128 | 128 | Small UI accent |
| `54px-topbar` | 800 | 160 | Admin topbar fit test |
| `hero` | 1200 | 300 | Marketing / full-size read |

Rendered for both `light` and `dark` color scheme (`page.emulateMedia({colorScheme: scheme})`).

**Per-asset harness requirements:**

| Asset | Required scales | Notes |
|-------|----------------|-------|
| `favicon.svg` | 16px (kill test), 32px | Dark scheme must show ember-300 via media query |
| `logo-primary.svg` | 54px-topbar, hero | Light only (light surface lockup) |
| `logo-primary-dark.svg` | 54px-topbar, hero | Dark only |
| `logo-primary-subtitle.svg` | hero | Verify subtitle text is legible; not tested at topbar |
| `logo-mark.svg` | 32px, hero | Both light and dark |
| `logo-monochrome.svg` | 32px, 54px-topbar | Single ink — verify rail block reads distinct from i stem |
| `social-card.svg` | 600×315 thumbnail scale | Verify at 50% scale (GitHub social preview size) |
| `social-card-dark.svg` | 600×315 thumbnail | Dark surface verify |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (brand asset phase — structural/scripted checks) |
| Config file | n/a |
| Quick run command | `find brandbook -name 'logo-*.svg' -o -name 'favicon.svg' -o -name 'social-card*.svg' \| xargs -n1 xmllint --noout` |
| Full suite command | Machine-verifiable check table below |
| Estimated runtime | ~15 seconds |

### Sampling Rate

- **Per task commit:** `xmllint --noout` on the committed file(s)
- **Per wave:** Full check table
- **Phase gate:** All checks green before `/gsd:verify-work`

### Phase Requirement → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| BRAND2-08 | All 8 production SVGs exist at canonical paths | ls | `ls brandbook/{logo-primary,logo-primary-dark,logo-primary-subtitle,logo-mark,logo-monochrome,favicon,social-card,social-card-dark}.svg` | ❌ Wave 0 |
| BRAND2-08 | All SVGs parse as valid XML | parse | `find brandbook -maxdepth 1 -name '*.svg' \| xargs -n1 xmllint --noout` | ❌ Wave 0 |
| BRAND2-08 | All production SVGs have `<desc>` with font provenance | grep | `grep -l 'Space Grotesk' brandbook/{logo-primary,logo-primary-dark,logo-primary-subtitle,logo-mark,logo-monochrome,favicon}.svg \| wc -l` returns 6 | ❌ Wave 0 |
| BRAND2-08 | favicon.svg has prefers-color-scheme media query | grep | `grep -c 'prefers-color-scheme' brandbook/favicon.svg` returns ≥1 | ❌ Wave 0 |
| BRAND2-08 | Dark variants use ember-300 not ember-700 | grep | `grep -c '#c2410c' brandbook/logo-primary-dark.svg brandbook/social-card-dark.svg` returns 0 | ❌ Wave 0 |
| BRAND2-08 | No font binaries committed | git | `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2' \| wc -l` returns 0 | ✅ |
| BRAND2-08 | No SVG file exceeds 250KB | size | `find brandbook -maxdepth 1 -name '*.svg' -size +250k -print` returns empty | ❌ Wave 0 |
| BRAND2-08 | v1 assets archived with deprecation note | git+ls | `ls brandbook/logo-options/archive-v1/*.svg \| wc -l` returns ≥6; `cat brandbook/logo-options/archive-v1/README.md` exists | ❌ Wave 0 |
| BRAND2-08 | clearspace + min-sizes + ≥4 misuse examples in README | grep | `grep -c 'Minimum\|clearspace\|Misuse' brandbook/README.md` returns ≥3 | ❌ Wave 0 |
| BRAND2-08 | Render harness exits 0 and produces PNGs | render | `node scripts/brand/critique-render.mjs /tmp/v2-harness.html /tmp/v2-renders/ && ls /tmp/v2-renders/*.png \| wc -l` returns ≥8 | manual — harness HTML created in task |

### Manual-Only Verifications

| Behavior | Why Manual | Instructions |
|----------|------------|--------------|
| 16px favicon kill test | Optical judgment | Executor reads `/tmp/v2-renders/*favicon*-16px-favicon-light.png` — ember block and stem geometry must read as distinct elements |
| 54px topbar fit | Optical judgment | Read `*logo-primary*-54px-topbar*.png` — "sigra" wordmark must be legible, no clipping |
| Monochrome rail read | Optical judgment | Read `*monochrome*` renders — rail block above i must read as spatially distinct from i stem |
| Social card thumbnail legibility | Optical judgment | Read social card renders at ~50% scale — wordmark and tagline must be readable |

### Wave 0 Gaps

- [ ] `brandbook/logo-options/archive-v1/` directory (created during archive task)
- [ ] All 8 production SVG files (none exist yet at v2 content)
- [ ] `brandbook/README.md` clearspace/min-size/misuse section (existing README lacks this)

---

## State of the Art

| Old Approach (v1) | New Approach (v2 / D4) | When Changed | Impact |
|-------------------|----------------------|--------------|--------|
| Rail Accent staircase mark (3-bar path geometry) | D4 abstract rail glyph (ink stem + foot + ember block) | Phase 180 ratification | Mark is now system-coherent with the typemark's tittle+tail bracket |
| Inter Display Black wordmark | Space Grotesk v2.0 wght 700 wordmark | Phase 179 candidate work | Better ecosystem distinctiveness; squared terminals echo rail geometry |
| Mark-beside-text lockup | Integrated typemark (brand motif IN the letterforms) | Phase 179 brief | Eliminates the generic Phoenix ecosystem lockup pattern |
| v1 favicon = same as logo-mark.svg | v2 favicon = purpose-built abstract mark | Phase 180 gate (Instagram confusion fix) | No more "ig" crop that reads as Instagram |
| No subtitle variant | `logo-primary-subtitle.svg` as explicit separate file | Phase 181 (new) | Subtitle is a distinct design problem, never appended as an afterthought |
| No dark social card | `social-card-dark.svg` | Phase 181 (new) | GitHub social preview dark mode support |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | outline-wordmark.mjs, critique-render.mjs | ✓ (via asdf) | check with `node --version` | — |
| opentype.js | outline-wordmark.mjs (NOT needed for Phase 181) | ✓ | 2.0.0 | N/A (not needed) |
| playwright-core / Chromium | critique-render.mjs | ✓ | Chromium 1223 cached | — |
| xmllint | SVG parse validation | ✓ | system | python3 xml.etree.ElementTree |
| python3 | Batch SVG XML checks | ✓ | 3.14.4 | xmllint per-file loop |

**Missing dependencies with no fallback:** None. All required tools confirmed present.

**Note on outline-wordmark.mjs:** Phase 181 does NOT need to re-run the outline script. The glyph paths are already final in the round-4 D4 SVGs. The script is available if any optical correction is needed but should not be invoked by default.

---

## Project Constraints (from CLAUDE.md)

- **brandbook/ self-containment:** Brand artifacts stay under `brandbook/`. Do not scatter into `docs/`, `guides/`, or generated templates without a separate decision. [CITED: CLAUDE.md Maintenance Rules]
- **SVG-only:** No font binaries, no raster commits, no web font CDN links. [CITED: CLAUDE.md + REQUIREMENTS.md Non-Goals]
- **No propagation to priv/templates or test/example:** Phase 183 scope. Do not touch `sigra-logo-primary.svg` in `test/example/priv/static/images/`. [CITED: 181-CONTEXT.md]
- **index.html rewrite deferred:** Phase 182. This phase only replaces the SVG src targets — the HTML prose remains v1 text. [CITED: 181-CONTEXT.md Deferred]
- **Token changes:** If any palette micro-tuning is applied (hue 15–40° only), record the delta explicitly in `brandbook/README.md` for Phase 182 to pick up. Default: no change from ember-700/ember-300.
- **GSD workflow:** All file changes through the GSD execute-phase workflow. [CITED: CLAUDE.md GSD Workflow Enforcement]
- **AAA test style, flat, self-contained:** Not applicable to this SVG-only phase (no Elixir test files generated).
- **Admin UI direction:** Not applicable to this brandbook-only phase. admin-ui-principles.md and admin-design-contract.md are not modified.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Subtitle text "Phoenix auth that ships" is appropriate for production use | Per-Asset Production Notes: logo-primary-subtitle.svg | Gallery text may not be final product copy; executor should verify brand voice against brand-book.md |
| A2 | System font stack in subtitle `<text>` element is acceptable (not outlined) | Per-Asset Production Notes: logo-primary-subtitle.svg | If extreme cross-platform consistency is required, subtitle needs outlining — but complexity is not justified for a secondary variant |
| A3 | Social card dark variant naming is `social-card-dark.svg` | V1 Asset Inventory | No existing precedent — but it follows the `logo-primary-dark.svg` naming pattern exactly |
| A4 | `logo-mark.svg` can omit the prefers-color-scheme media query (use explicit fill) OR keep it | Per-Asset Production Notes: logo-mark.svg | If mark is used in dark HTML contexts via `<img>` without a dark variant, keeping the media query is better DX |

---

## Open Questions

1. **Subtitle text finalization**
   - What we know: "Phoenix auth that ships" has been used consistently across round-3 and round-4 gallery previews as the subtitle preview text
   - What's unclear: Whether this is the production subtitle or a placeholder
   - Recommendation: Use "Phoenix auth that ships" as the production subtitle text unless brand-book.md voice section provides a stronger alternative; it is concise, brand-consistent, and technically honest

2. **Social card v1 replacement vs archival of the v1 content**
   - What we know: `social-card.svg` currently embeds the v1 Rail Accent mark paths inline; it is NOT referenced by `brandbook/index.html`
   - What's unclear: Whether the v1 social card composition (taglines, code block) should be adapted or fully redesigned
   - Recommendation: Adapt the v1 layout (panel + tagline + install snippet) — the composition is solid; replace only the mark geometry and adjust fills to v2

3. **Palette micro-tuning scope**
   - What we know: CONTEXT permits tuning within hue 15–40° if it measurably improves legibility at small sizes; default is no change
   - What's unclear: Whether the ember-700 `#c2410c` on the favicon at 16px needs brightening for legibility on non-white backgrounds
   - Recommendation: Default to no change; make a final determination only after reading the 16px favicon kill test PNG

---

## Sources

### Primary (HIGH confidence — direct codebase verification)

- `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` — exact source geometry, glyph paths, viewBox, fill values
- `brandbook/logo-options/round-4/d4-linked-rail-typemark-dark.svg` — dark variant fills
- `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` — mark geometry, media query, ember values
- `brandbook/logo-options/round-3/README.md` — ratification record
- `brandbook/logo-options/round-4/README.md` — round-4 design decisions
- `brandbook/logo-primary.svg` + dark + mark + monochrome + favicon + social-card — v1 conventions
- `brandbook/index.html` — brandbook-internal `<img src>` references
- `brandbook/README.md` — current font provenance table and maintenance rules
- `brandbook/brand-book.md` — v1 logo system rules, clearspace/min-size docs
- `scripts/brand/critique-render.mjs` — render harness conventions
- `scripts/brand/outline-wordmark.mjs` — toolchain pitfall notes (flipY, variation.set)
- `.planning/phases/179-outlining-toolchain-logo-concept-exploration/179-VALIDATION.md` — Nyquist validation pattern
- `.planning/phases/181-ratified-logo-system-buildout/181-CONTEXT.md` — locked decisions
- `.planning/REQUIREMENTS.md` — BRAND2-08 success criteria
- `test/example/priv/static/images/` — confirmed different naming convention (sigra-logo-primary.svg); Phase 183 scope only

### Secondary (MEDIUM confidence)

- SVG `prefers-color-scheme` media query: browser support confirmed at Chrome 82+, Firefox 63+, Safari 14+ [ASSUMED from training; conservative stance is safe — the favicon.svg already uses this pattern from Phase 179]
- OG standard image size 1200×630 [ASSUMED from training; near-universal standard, low risk]

---

## Metadata

**Confidence breakdown:**
- V1 asset inventory: HIGH — verified by direct file read
- D4 source geometry: HIGH — verified by direct SVG read
- SVG conventions: HIGH — verified across all v1 + round-4 files
- Archive/index.html strategy: HIGH — grep-verified all img src references
- Render harness: HIGH — script read and Phase 179 confirmed working
- Clearspace/min-size numbers: MEDIUM — D4 geometry is verified, proportional numbers are derived

**Research date:** 2026-06-12
**Valid until:** Phase 181 execution only — no external dependencies to expire
