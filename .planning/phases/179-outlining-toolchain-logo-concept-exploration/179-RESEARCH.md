# Phase 179: Outlining Toolchain + Logo Concept Exploration — Research

**Researched:** 2026-06-12
**Domain:** SVG typemark generation via opentype.js + Playwright file:// rendering + OFL font procurement
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Phase boundary:** Build the reproducible glyph-outlining toolchain and produce 5–7 pre-verified logo candidates presented in `brandbook/logo-options/round-3/` gallery. Ends when the gallery is committed and ready for Phase 180 human ratification gate.

**Authoritative design contract:** `brandbook/logo-v2-design-brief.md` — 7 hard constraints, ember hue 15–40° tuning boundary, OFL typeface candidates table, letterform integration anatomy, 6-row render-critique rubric, Direction A/B/C guidance, round-3 deliverables table.

**Toolchain (BRAND2-04):** opentype.js (MIT) glyph-outlining script committed to the repo at `scripts/brand/outline-wordmark.mjs`; run via the node env at `test/example/priv/playwright/` or npx. OFL fonts download to a gitignored temp location; NO font binaries committed; font name/version provenance in SVG `<desc>` and `brandbook/README.md`.

**Candidates (BRAND2-05):** 5–7 total; ≥2–3 fully integrated typemarks (motif worked INTO letterforms); 1–2 evolved tight lockups (boundary-breaking, no container, close-set type); 1 wildcard allowed. Every candidate passes the render-critique loop BEFORE gallery inclusion at 16px, 32px, 54px, and hero, in light AND dark. Renders are throwaway — never committed.

**Gallery (BRAND2-06):** `brandbook/logo-options/round-3/` matching round-2 format: standalone `index.html` linking `../../tokens.css`, per-option sections, `README.md` rationale table, status pill/topbar/crumbs chrome. Each finalist-grade option shows a with-subtitle preview variant.

### Claude's Discretion
- Exact candidate concepts/motifs (guided by brief Directions A/B/C and letterform anatomy)
- Script CLI shape, config format, and where the harness HTML lives (throwaway, gitignored or temp)
- Which OFL faces from the brief's table each candidate uses

### Deferred Ideas (OUT OF SCOPE)
- Final asset set (subtitle variant file, monochrome, social cards) → Phase 181
- Token version bump / palette propagation → Phases 182–183
- README/social adoption → post-milestone fast-follow
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND2-04 | Committed reproducible glyph-outlining script (opentype.js, OFL fonts gitignored); no font binaries; provenance in SVG `<desc>` and `brandbook/README.md` | opentype.js 2.0.0 verified; `loadSync`/`parse` API confirmed; `Font.getPath`, `forEachGlyph`, `Path.toPathData` all confirmed; font download URLs resolved |
| BRAND2-05 | 5–7 candidates including ≥2 integrated typemarks; pre-verified at 16/32/54px + hero in light+dark via render-critique loop | Playwright 1.59.1 standalone `chromium.launch()` + `file://` screenshot confirmed working; concept space mapped; fragility risks documented |
| BRAND2-06 | `brandbook/logo-options/round-3/` gallery matching round-2 format: `index.html` + `README.md` | Round-2 HTML skeleton fully documented; token CSS path confirmed; gallery structure replicable |
</phase_requirements>

---

## Summary

Phase 179 has two parallel workstreams that feed each other: (1) a toolchain — a Node.js script that downloads OFL fonts to a gitignored temp directory, uses opentype.js to outline "sigra" into per-glyph SVG `<path>` elements, and writes the result with font provenance in `<desc>`; and (2) a creative loop — 5–7 logo candidates authored as SVG files, screenshotted via Playwright at multiple scales, self-critiqued against the brief's rubric, iterated until clean, then presented in a gallery.

The toolchain is well-supported: opentype.js 2.0.0 is on npm (13 years old, 1.3M weekly downloads, MIT, no postinstall hooks), its API is exactly as needed (`loadSync`, `Font.getPath`, `forEachGlyph` with kerning, `Path.toPathData({ decimalPlaces: 2, flipY: true })`), and variable fonts are supported via `font.variation.set({ wght: 900 })` — so Space Grotesk, Syne, and Inter (all variable) can be instanced without needing static weight files. Playwright 1.59.1 is already installed at `test/example/priv/playwright/`, chromium-1223 browser is cached at `~/Library/Caches/ms-playwright/chromium-1223/`, and standalone `chromium.launch()` + `page.goto('file://...')` + `page.screenshot()` is confirmed working — no test runner or server needed.

The creative challenge is the weightier work. The brief mandates that ≥2–3 candidates be fully integrated typemarks — motif worked structurally into the letterforms — not icon-beside-text. Seven concrete concept directions are mapped below across Directions A/B/C with typeface pairings, fragility risks at 16px, and dark-mode notes.

**Primary recommendation:** Plan in two parts — Plan 01: toolchain script + font download + harness infrastructure; Plan 02: candidates authored, render-critique looped, gallery assembled. No Plan 03 needed; the gallery is the output of Plan 02.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Glyph outlining | Build script (Node.js) | — | opentype.js runs in Node; output is static SVG paths committed to brandbook |
| Font download/caching | Build script | .gitignore | Fonts are transient inputs; only path data output is committed |
| Render critique screenshots | Playwright (headless Chromium) | — | Throwaway QA renders; file:// URL eliminates server dependency |
| SVG motif integration | Manual SVG editing | — | Path arithmetic is the creative design act; no programmatic boolean needed for most concepts |
| Gallery HTML | Static HTML (brandbook/) | tokens.css | No build step; self-contained like round-2 |
| Font provenance documentation | SVG `<desc>` + brandbook/README.md | — | Both locations required by BRAND2-04 |

---

## Standard Stack

### Core (Toolchain)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| opentype.js | 2.0.0 | Parse OFL TTF/variable fonts; extract `<path d="...">` data | MIT, 13 yrs old, 1.34M weekly downloads, official opentype.js org, no postinstall scripts — the established Node.js font-to-path tool [VERIFIED: npm registry] |
| playwright-core | 1.59.1 (installed) | Standalone headless Chromium screenshots of `file://` harness pages | Already installed in `test/example/priv/playwright/node_modules/`; chromium-1223 browser cached at `~/Library/Caches/ms-playwright/`; confirmed working standalone (no @playwright/test runner needed) [VERIFIED: local inspection + runtime test] |
| Node.js | v22.14.0 (available) | Script runtime | Installed via asdf; `node --version` confirmed [VERIFIED: local inspection] |

### Supporting (Font Downloads)

| Font | OFL Version | Variable? | Static Instance Download Strategy |
|------|-------------|-----------|-----------------------------------|
| Inter (Display weight) | v4.1 | Yes (`opsz,wght` axes) | `font.variation.set({ wght: 900, opsz: 32 })` on variable TTF; or download from Google Fonts static API at weight 900 [VERIFIED: npm + runtime] |
| Space Grotesk | 2.0.0 | Yes (`wght` axis) | `font.variation.set({ wght: 700 })` on `SpaceGrotesk[wght].ttf` from `github.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk[wght].ttf` [VERIFIED: github.com/google/fonts] |
| Syne | Latest | Yes (`wght` axis only) | `font.variation.set({ wght: 800 })` on `Syne[wght].ttf` from `raw.githubusercontent.com/google/fonts/main/ofl/syne/Syne%5Bwght%5D.ttf` [VERIFIED: github.com/google/fonts] |
| Plus Jakarta Sans | 2.7.1 | Yes (variable available) | Download from `github.com/tokotype/PlusJakartaSans/releases/download/2.7.1/PlusJakartaSans-2.7.1.zip` then extract ExtraBold TTF, or use `font.variation.set({ wght: 800 })` [VERIFIED: GitHub releases API] |
| Geist | v1.7.2 | Yes | Download from `github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip` then extract Black TTF [VERIFIED: GitHub releases API] |

**Key insight:** All five candidate fonts are variable. opentype.js 2.0.0 `font.variation.set({ wght: N })` confirmed working — no need to download separate static weight TTFs. The variable TTF files are directly downloadable from google/fonts GitHub raw URLs (no auth).

**Installation (for script):**
```bash
# Run from test/example/priv/playwright/ where node_modules already has playwright-core
npm install opentype.js --prefix scripts/brand   # OR: install into a local node_modules beside the script
# The script can also use: cd test/example/priv/playwright && node ../../../../../../scripts/brand/outline-wordmark.mjs
```

The simplest approach: the script declares `opentype.js` as a dependency in its own `scripts/brand/package.json` (or uses `npx --yes=false` — no, avoid). Best: add a `scripts/brand/package.json` with `opentype.js` and let the executor `npm install` inside that directory. **No font binaries committed.**

**Version verification:**
```bash
npm view opentype.js version   # → 2.0.0 (verified 2026-06-12)
```

---

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| opentype.js | npm | 13 yrs (2013-09-27) | 1.34M/wk | github.com/opentypejs/opentype.js | [ASSUMED] | Approved — 13-year-old well-known library, no postinstall scripts, MIT, official org |

**slopcheck was unavailable at research time.** opentype.js is manually assessed as legitimate based on: 13-year publication age, 1.34M weekly downloads, official org (`opentypejs`), MIT license, no `scripts.postinstall`, and the library being a well-known font-processing tool with 5.7k GitHub stars. Despite slopcheck unavailability, the risk of this package being malicious is negligible.

**Packages removed due to [SLOP]:** none
**Packages flagged [SUS]:** none — but the planner should note: if strict slopcheck is required, a `checkpoint:human-verify` before `npm install opentype.js` is appropriate per protocol.

*No additional packages are installed by this phase. Playwright is already installed.*

---

## Architecture Patterns

### System Architecture Diagram

```
OFL Font URLs (github.com/google/fonts, rsms/inter, etc.)
         |
         | curl/fetch (gitignored: /tmp/sigra-fonts/ or scripts/brand/fonts/)
         v
scripts/brand/outline-wordmark.mjs
         |
         | opentype.loadSync(path)
         | font.variation.set({ wght: N })           [variable fonts]
         | font.forEachGlyph("sigra", 0, 0, 100, {kerning: true}, cb)
         |   → per glyph: glyph.getPath(x, y, 100)
         |                .toPathData({ decimalPlaces: 2, flipY: true })
         v
brandbook/logo-options/round-3/[candidate]-wordmark-outline.svg
  <desc>Font: Space Grotesk v2.0.0 (OFL) wght=700; outlined 2026-06-12</desc>
  <g id="glyphs">
    <path id="g-s" d="M..." />
    <path id="g-i" d="M..." />
    ...
  </g>
         |
         | manual SVG editing (motif integration)
         v
brandbook/logo-options/round-3/[candidate]-{primary|typemark|favicon}.svg
         |
         | scripts/brand/critique-render.mjs  (standalone, throwaway)
         |   playwright-core: chromium.launch()
         |   page.goto('file://.../harness/[candidate].html')
         |   page.screenshot() at { width: 16 }, { width: 32 }, { width: 54 }, { width: 480 }
         |   light + dark (page.emulateMedia({ colorScheme: 'dark' }))
         v
/tmp/sigra-renders/[candidate]-[scale]-[theme].png  (gitignored, throwaway)
         |
         | self-critique against brief rubric → iterate
         v
brandbook/logo-options/round-3/
  index.html         (gallery, links ../../tokens.css)
  README.md          (rationale table)
  [candidate]-primary.svg
  [candidate]-primary-dark.svg
  [candidate]-typemark.svg     (for fully-integrated typemarks)
  [candidate]-mark.svg         (if mark retained)
  [candidate]-favicon.svg
```

### Recommended Project Structure

```
scripts/
└── brand/
    ├── package.json             # {"dependencies": {"opentype.js": "^2.0.0"}}
    ├── node_modules/            # gitignored
    ├── fonts/                   # gitignored (downloaded OFL fonts)
    ├── outline-wordmark.mjs     # BRAND2-04 deliverable; outputs per-glyph SVG paths
    └── critique-render.mjs      # throwaway harness screenshotter

brandbook/logo-options/round-3/
    ├── index.html               # gallery (round-2 format)
    ├── README.md                # rationale table
    ├── [A1]-typemark.svg
    ├── [A1]-typemark-dark.svg
    ├── [A1]-favicon.svg
    ├── [A2]-typemark.svg
    ... (5–7 candidate sets)
```

**Gitignore additions needed:**
```
# Brand toolchain — font binaries and render artifacts
/scripts/brand/node_modules/
/scripts/brand/fonts/
/tmp/sigra-renders/
```

### Pattern 1: opentype.js Per-Glyph Outlining

**What:** Load font, set variable weight, iterate glyphs with kerning, emit per-glyph `<path>` elements with provenance `<desc>`.

**When to use:** Generating the wordmark path source for any candidate that starts from a real OFL typeface.

**Example:**
```javascript
// Source: opentype.js 2.0.0 API (confirmed from local inspection)
import { loadSync } from 'opentype.js';
import { writeFileSync } from 'fs';

const font = loadSync('./fonts/SpaceGrotesk[wght].ttf');
font.variation.set({ wght: 700 });   // set named axis coordinate

const text = 'sigra';
const fontSize = 1000; // work at 1000px UPM — scale down in SVG viewBox

const paths = [];
font.forEachGlyph(text, 0, 0, fontSize, { kerning: true }, (glyph, x, y) => {
  const pathData = glyph.getPath(x, y, fontSize).toPathData({ decimalPlaces: 2, flipY: true });
  paths.push({ id: `g-${glyph.name}`, x, d: pathData });
});

// Compute bounding box from paths for viewBox
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -50 4200 1100" role="img" aria-labelledby="title desc">
  <title id="title">sigra wordmark outline</title>
  <desc id="desc">Font: Space Grotesk v2.0.0 (OFL), wght=700. Outlined with opentype.js 2.0.0. Generated 2026-06-12.</desc>
  <g id="glyphs" fill="#151515">
    ${paths.map(p => `<path id="${p.id}" d="${p.d}" />`).join('\n    ')}
  </g>
</svg>`;

writeFileSync('./round-3/A1-wordmark-base.svg', svg);
```

**Critical note: `flipY: true` (the default)** — font coordinate systems are Y-up; SVG is Y-down. `toPathData` flips Y by default using `flipYBase` derived from `fontSize`. Working at `fontSize = 1000` (= UPM scale) is recommended for precision before scaling via SVG `viewBox`. The `y` passed to `forEachGlyph` is the baseline — pass `fontSize` (e.g. 1000) so paths are fully positive-Y after flip.

### Pattern 2: Variable Font Weight Setting

**What:** Set the `wght` axis before outlining. Works for all five candidate fonts (all are variable TTFs).

**Example:**
```javascript
// Source: confirmed from opentype.js 2.0.0 source (VariationManager.set)
font.variation.set({ wght: 900 });    // Inter Display Black equivalent
font.variation.set({ wght: 700 });    // Space Grotesk Bold
font.variation.set({ wght: 800 });    // Syne ExtraBold, Plus Jakarta Sans ExtraBold
font.variation.set({ wght: 900 });    // Geist Black

// OR by named instance index (0-based):
font.variation.set(0);  // First named instance (check font's fvar table)
```

The `variation` property is auto-initialized from the font's `fvar` table when the font is loaded. No special parsing step needed.

### Pattern 3: Playwright Standalone Screenshot

**What:** A standalone `.mjs` script (no test framework) that screenshots harness HTML files at multiple widths.

**Example:**
```javascript
// Source: Playwright 1.59.1 API (confirmed via local runtime test)
import { chromium } from 'playwright-core';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';

const SCALES = [
  { name: '16px-favicon', width: 16, height: 16 },
  { name: '32px',         width: 32, height: 32 },
  { name: '54px-topbar',  width: 400, height: 54 },  // wide enough to not clip
  { name: 'hero',         width: 800, height: 200 },
];

const harnessPath = '/tmp/sigra-renders/A1-light.html';
const browser = await chromium.launch({ headless: true });

for (const scale of SCALES) {
  for (const scheme of ['light', 'dark']) {
    const page = await browser.newPage();
    await page.setViewportSize({ width: scale.width * 4, height: scale.height * 4 });
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(`file://${harnessPath}`);
    const buf = await page.screenshot({ type: 'png' });
    mkdirSync('/tmp/sigra-renders', { recursive: true });
    writeFileSync(`/tmp/sigra-renders/A1-${scale.name}-${scheme}.png`, buf);
    await page.close();
  }
}
await browser.close();
```

**Run from:** `cd /Users/jon/projects/sigra/test/example/priv/playwright && node ../../../../../scripts/brand/critique-render.mjs`

**Important:** `playwright-core` (not `@playwright/test`) is the correct import for standalone use. It is already installed at `test/example/priv/playwright/node_modules/playwright-core`. The chromium-1223 browser binary is cached at `~/Library/Caches/ms-playwright/chromium-1223/chrome-mac-arm64/`.

### Anti-Patterns to Avoid

- **Committing font TTF/OTF files:** Any font binary in git violates BRAND2-04 hard constraint. The `.gitignore` must cover `scripts/brand/fonts/` and `scripts/brand/node_modules/` before any font is downloaded.
- **Using `path.toPathData()` without `flipY: true`:** The default is `flipY: true`, but if overriding with an options object, omitting `flipY` produces an upside-down wordmark. Always pass `{ decimalPlaces: 2 }` (inherits `flipY: true`) or explicitly `{ decimalPlaces: 2, flipY: true }`.
- **Boolean-union operations without tooling:** opentype.js does not do boolean path operations. paper.js does, but it is not installed. For motif integration, design around needing booleans by using `fill-rule="evenodd"` for overlap removal or by keeping motif as separate `<path>` elements. If a hard boolean union is truly needed for a specific concept, paper.js (v0.12.18, 13 yrs, 222k weekly downloads, MIT, no postinstall) can be added — but most concepts can be designed to avoid it.
- **Per-glyph `<path>` with unresolved group transforms:** The `forEachGlyph` callback already returns absolute-positioned x values at the requested fontSize. Do NOT apply additional `translate` transforms on top of the `<path>` elements unless working at UPM scale and scaling the whole group with `transform="scale()"`.
- **Harness HTML committed to the repo:** The render harness pages are throwaway. They go in a gitignored temp location (`/tmp/` or `scripts/brand/.harness/` gitignored). The only committed brandbook files are the final candidate SVGs and gallery HTML.
- **Working at small fontSize (e.g., 20px) in the outline script:** Work at `fontSize = 1000` or the font's `unitsPerEm` value for path precision. Scale via the SVG `viewBox`, not the outline font size.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Font glyph path extraction | Custom OpenType parser | `opentype.js loadSync` + `forEachGlyph` | Handles TrueType quadratic curves, CFF cubic curves, GPOS kerning, variable font axis normalization — all needed for the 5 candidate typefaces |
| Kerning between glyphs | Manual tracking adjustments | `opentype.js` `kerning: true` option in `forEachGlyph` | Reads both legacy kern table and GPOS tables; Space Grotesk and Inter have complex GPOS kerning |
| Variable font weight selection | Downloading static weight TTFs | `font.variation.set({ wght: N })` | All 5 candidate fonts are variable; static weight download avoids nothing and wastes a step |
| Headless SVG screenshots | PhantomJS, puppeteer | `playwright-core chromium.launch()` | Already installed; confirmed working for `file://` URLs; consistent with repo's Playwright investment |
| Y-axis flip for SVG output | Manual path coordinate transform | `Path.toPathData({ flipY: true })` (default) | Built into opentype.js; handles `flipYBase` from fontSize correctly |

**Key insight:** The only custom code is the orchestration script — downloading fonts, setting variation axes, calling `forEachGlyph`, emitting SVG with provenance. All the hard parts (OpenType parsing, kerning, variable glyph rendering, Y-flip) are handled by opentype.js internals.

---

## Candidate Concept Space (Direction A/B/C)

These are concept descriptions for the creative execution in BRAND2-05. The executor (planner → implementor) selects 5–7 and begins with the strongest 2–3 Direction A candidates.

### Direction A — Integrated Typemarks (MUST produce ≥2–3)

**A1 — Rail-i typemark (Space Grotesk Bold)**
The `i` stem and tittle become the Rail Accent mark: the tittle is replaced by ember-300 (`#fdba74`) dot (or the stacked-bar motif in miniature), the stem has a flat horizontal foot at baseline that echoes the core line. The rest of the word is monochrome dark. The `g` descender is elongated and curves leftward to provide visual mass at the end of the word.
- Font: Space Grotesk Bold (squared terminals echo the rail geometry naturally)
- 16px risk: The `i` tittle detail may merge into the stem — design the tittle as a colored block wide enough to survive at 16px
- Dark mode: Replace `#151515` with `#f4f1eb`; ember dot unchanged

**A2 — Descender-rail typemark (Plus Jakarta Sans ExtraBold)**
The `g` descender is the primary motif: instead of terminating, it continues down and curls back as a horizontal rail bar with round cap (matching the Rail Accent's stroke-linecap geometry). The rail bar underscores only the `g` — a structural extension of the descender, not a decorative element. The `s` entry stroke is cut flat (horizontal terminal) to echo the rail crossbar. The `r` shoulder terminates flat.
- Font: Plus Jakarta Sans ExtraBold (the pointy curves give the `g` descender distinctive character; the `a` is single-story which reads cleaner at small sizes)
- 16px risk: The descender rail detail disappears — but the wordmark remains legible as text; this is acceptable since the brief requires the 16px favicon render to have a readable silhouette, not the motif detail
- Dark mode: Whole wordmark flips to `#f4f1eb`; if ember accent is on the descender bar, it reads clearly on dark

**A3 — Crossbar-s typemark (Syne ExtraBold)**
The `s` is built from two horizontal rail strokes bridged by a sinuous path: the entry and exit terminals of the `s` are replaced with flat horizontal bars (like the two outer columns of the Rail Accent mark). The body of the `s` becomes the connector — a visual reference to the three-column rail structure. This is the most structural modification and requires the most careful optical adjustment.
- Font: Syne ExtraBold (Syne's unusual width-at-heavier-weight means the `s` is naturally wider, giving more room for the motif)
- 16px risk: HIGH — the `s` modification may make it unreadable. Mitigation: keep the `s` legible as a letterform; only modify the terminal cuts, not the body of the `s`. Fall back to a subtler terminal-only modification if the rail-bridge reads as broken at 32px
- Dark mode: Syne's heavy weight maintains legibility on dark surfaces; ember accent on the terminal bars

**A4 — Ember-dot minimal typemark (Inter Display Black)**
The reference font is used but given a single differentiated element: the `i` tittle is replaced by a larger ember-700 (`#c2410c`) dot (2–3× the standard tittle size), positioned slightly higher than the cap-height. Everything else is path-accurate Inter Display Black. This is the most conservative Direction A candidate — closest to a real-world production-safe typemark.
- Font: Inter Display Black (reference; intentionally kept to test whether the motif alone creates enough distinctiveness vs the v1)
- 16px risk: LOW — the enlarged colored tittle survives favicon scale
- Dark mode: Word flips to `#f4f1eb`; ember dot unchanged. Works cleanly.
- **Fragility note:** If this reads as "just Inter with a colored dot," it fails the ecosystem distinctiveness test. Include anyway to have a baseline for the rubric.

### Direction B — Refined Combination Lockup (produce 1–2)

**B1 — Redesigned mark + Space Grotesk tight lockup**
The Rail Accent mark is simplified: three staggered bars reduced to two, with heavier stroke weight that reads at 16px without bleeding. The mark is placed to the left of the wordmark but the composition breaks the conventional "mark beside text" pattern by having the mark baseline extend below the wordmark baseline — boundary-breaking. Wordmark in Space Grotesk Bold (not Inter Display Black).
- No rectangular container; mark touches or overlaps the first letter's vertical stroke
- 16px risk: Medium — the mark simplification is specifically for favicon durability
- Dark mode: Mark ember tones unchanged; wordmark and mark adapt

**B2 — Letterform-substitution lockup (Geist Black)**
The `s` in "sigra" is replaced by a custom glyph shaped like the Rail Accent mark's three-bar column. The rest of the word is set in Geist Black. The mark does not appear separately — the first letter IS the mark. This is a hybrid between A and B: it looks like a combination lockup at first glance, but on inspection the "mark" is a modified letterform.
- 16px risk: LOW for wordmark legibility (the `s`-replacement is wider and reads as a letter-like shape); MEDIUM for mark distinctiveness (the three bars must survive scale reduction)
- Dark mode: Works; Geist Black's uniform weight maintains legibility

### Direction C — Wildcard

**C1 — Stacked wordmark (Plus Jakarta Sans ExtraBold)**
"sigra" in all-lowercase set in two lines: "si" (top) / "gra" (bottom), tightly tracked, with the Rail Accent mark centered vertically between the two lines. This composition pattern is rare in the Elixir ecosystem and satisfies the "no mark-beside-text" constraint structurally. The mark becomes a vertical accent between the two word halves.
- No rectangular container; the mark is embedded in the interline space
- 16px risk: HIGH — a stacked wordmark at favicon scale is not legible as "sigra." Mitigation: the favicon SVG for this candidate uses the mark alone, not the stacked lockup
- Dark mode: Works; this is a compositional variant that tolerates both surfaces

---

## Common Pitfalls

### Pitfall 1: Font coordinate Y-axis inversion

**What goes wrong:** Paths generated with default `flipY: false` (old opentype.js behavior) appear upside-down in SVG. The default in opentype.js 2.0.0 is `flipY: true` via the `createSVGOutputOptions` internal function — but if you pass `toPathData(2)` (the integer shorthand from v1.x), it sets `{ decimalPlaces: 2, flipY: false }` and produces inverted output.

**Why it happens:** The integer shorthand is backwards-compatible from v1.x where `flipY` was not yet default-true. In v2.0.0, `toPathData(2)` maps to `{ decimalPlaces: 2, flipY: false }` (note: the integer form sets `flipY: false` explicitly).

**How to avoid:** Always pass an options object: `toPathData({ decimalPlaces: 2 })` — this inherits `flipY: true` from the defaultOptions. Verify output by checking that the first `M` command in the path data has a positive Y value (for descenders, Y exceeds the fontSize value).

**Warning signs:** wordmark appears mirrored vertically in the browser; all Y coordinates are negative.

### Pitfall 2: Per-glyph `id` collision when font has repeated letterforms

**What goes wrong:** In "sigra", there is only one instance of each letter, so this pitfall doesn't apply to the primary wordmark. But if testing with "signal" or other test strings, `id="g-a"` would collide if `a` appears twice.

**How to avoid:** Use index-based IDs: `id="g-0"`, `id="g-1"` etc., not glyph-name-based IDs.

### Pitfall 3: 54px admin topbar clip on boundary-breaking compositions

**What goes wrong:** Direction A typemark candidates that extend descenders below the baseline, or Direction B compositions that have mark elements above cap-height, will be clipped by `<img height="54">` in the admin topbar slot unless the SVG `viewBox` includes appropriate padding.

**Why it happens:** The admin topbar `<img height="54">` constrains the render bounding box. An SVG with `viewBox="0 0 300 50"` where a motif extends to `y=-10` will clip the top of the design.

**How to avoid:** Design the final SVG `viewBox` to include motif overflow. For a descender that extends 20% below baseline: if the wordmark cap-height is 700 UPM and the descender goes to 850 UPM, the viewBox height should be at least 900 UPM in the source coordinate system. The brief explicitly notes: "design viewBox padding that tolerates overflow."

### Pitfall 4: Variable font `variation` property is null if no `fvar` table

**What goes wrong:** `font.variation.set(...)` throws `TypeError: Cannot read properties of null` for non-variable fonts (fonts without an `fvar` table). The `variation` property is only initialized if `fvar` is found during font loading.

**Why it happens:** The `VariationManager` is conditionally instantiated. For a static-weight TTF (e.g., `SpaceGrotesk-Bold.ttf` instead of `SpaceGrotesk[wght].ttf`), `font.variation` is null.

**How to avoid:** Use the variable TTF files (the `[wght].ttf` naming convention). Guard: `if (font.variation) font.variation.set({ wght: 700 }); else console.warn('Not a variable font, using default weight');`

### Pitfall 5: Gallery `tokens.css` relative path breaks if harness is in wrong location

**What goes wrong:** The round-3 gallery `index.html` links `../../tokens.css`. This resolves correctly when the file is at `brandbook/logo-options/round-3/index.html`. If the gallery structure uses a different nesting level, the tokens CSS will 404 and the gallery will render without the design system variables.

**How to avoid:** The gallery must be exactly at `brandbook/logo-options/round-3/index.html` — matching the CONTEXT.md decision. The relative path `../../tokens.css` from `round-3/` correctly resolves to `brandbook/tokens.css`.

### Pitfall 6: `forEachGlyph` callback x position is in font UPM units, not pixels

**What goes wrong:** The x position passed to the callback is in font units scaled by `fontSize`. At `fontSize = 1000`, the `x` for the second glyph might be `700` (UPM units). The resulting SVG `viewBox` needs to accommodate the total advance width of "sigra" at that scale.

**How to avoid:** Accumulate the advance widths during `forEachGlyph` to determine total path width. Use `font.getAdvanceWidth("sigra", fontSize)` to get the total width for the viewBox calculation. Add 5% padding each side.

---

## Code Examples

### Minimal outline-wordmark.mjs skeleton

```javascript
// Source: opentype.js 2.0.0 API (verified 2026-06-12)
// Run from: node scripts/brand/outline-wordmark.mjs [font.ttf] [wght] [output.svg]
import { loadSync } from 'opentype.js';
import { writeFileSync } from 'fs';

const [,, fontPath, wghtStr, outPath] = process.argv;
const wght = Number(wghtStr) || 700;

const font = loadSync(fontPath);
if (font.variation) font.variation.set({ wght });

const fontSize = font.unitsPerEm;  // work at native UPM for precision
const paths = [];
let totalWidth = 0;

font.forEachGlyph('sigra', 0, fontSize, fontSize, { kerning: true }, (glyph, x, y) => {
  const d = glyph.getPath(x, y, fontSize).toPathData({ decimalPlaces: 2 });  // flipY: true default
  paths.push(`<path id="g-${paths.length}" d="${d}" />`);
  totalWidth = x + (glyph.advanceWidth || 0) * (fontSize / font.unitsPerEm);
});

const vbPad = fontSize * 0.05;
const vbX = -vbPad;
const vbW = totalWidth + vbPad * 2;
const vbH = fontSize * 1.3;  // cap-height + descender room

const fontName = font.getEnglishName('fullName') || 'Unknown';
const svg = `<svg xmlns="http://www.w3.org/2000/svg"
  viewBox="${vbX.toFixed(0)} 0 ${vbW.toFixed(0)} ${vbH.toFixed(0)}"
  role="img" aria-labelledby="title desc">
  <title id="title">sigra wordmark outline</title>
  <desc id="desc">Font: ${fontName} wght=${wght}. OFL licensed. Outlined with opentype.js 2.0.0. Generated ${new Date().toISOString().slice(0,10)}.</desc>
  <g id="glyphs" fill="currentColor">
${paths.map(p => '    ' + p).join('\n')}
  </g>
</svg>`;

writeFileSync(outPath, svg);
console.log(`Wrote ${outPath} (${paths.length} glyphs, width ≈ ${totalWidth.toFixed(0)} UPM)`);
```

### Gallery index.html skeleton for round-3

The round-3 gallery is a direct structural replication of round-2. Key differences:
- Topbar crumbs: `<a href="../round-2/index.html">Round 2 archive</a>` + `<a href="../../index.html">Brandbook</a>` + `<a href="README.md">Round 3 notes</a>`
- Status pill: `Archive study` → `Under review` (or `Pending ratification`)
- Header subheader: `Round 3 exploration / integrated typemarks / rail motif`
- Each `<article class="option">` uses `class="option-head"` + `class="preview"` + `class="notes"` — same structure as round-2
- For integrated typemarks (no separate mark), the `.mark-lab` section is omitted or replaced with a "mark-only" note
- Each option shows a `.subtitle` preview variant section (per CONTEXT.md: "each finalist-grade option shows a with-subtitle preview variant")
- Favicon row: same `.favicons` / `.favicon-sample` pattern with `style="width:32px"`, `style="width:24px"`, `style="width:16px"`

The `<link rel="stylesheet" href="../../tokens.css">` path is fixed — gallery must be at `brandbook/logo-options/round-3/index.html`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Path.toPathData(2)` (integer shorthand, v1.x) | `Path.toPathData({ decimalPlaces: 2 })` object form | opentype.js v2.0 | Integer form still works but sets `flipY: false`; prefer object form |
| Download static weight TTF per desired weight | Download variable TTF once, `font.variation.set({ wght: N })` | Space Grotesk 2.0, Syne, Inter v4, Plus Jakarta Sans 2.7, Geist v1 | One file per font family, any weight available |
| `opentype.load(path, callback)` (async callback) | `opentype.loadSync(path)` (sync) or `opentype.parse(await fs.promises.readFile(path))` | Both available in v2.0 | For a CLI build script, `loadSync` is simpler |

**Deprecated/outdated:**
- `opentype.load()` with Node-style callback: still works but the async callback style is legacy. Prefer `loadSync` for scripts.
- The `path.toSVG()` method: wraps `toPathData` in a full `<path d="...">` element string but doesn't support COLR layers (logs a warning). For standard outline fonts, `toSVG()` is fine but `toPathData()` gives more control for multi-glyph SVGs.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `toPathData(2)` (integer form) sets `flipY: false` in v2.0 | Pitfall 1 | If wrong, integer shorthand may still respect `flipY: true` default — low risk, just use object form regardless |
| A2 | All 5 candidate fonts are variable TTFs (no static-only releases) | Standard Stack | If any font is static-only, `font.variation` is null — use the guard pattern in Pitfall 4 |
| A3 | The chromium-1223 browser binary at `~/Library/Caches/ms-playwright/chromium-1223/` is the correct binary for playwright-core 1.59.1 | Architecture Patterns | Confirmed browser cache folder exists and standalone launch tested successfully — LOW risk |
| A4 | paper.js (if needed for boolean union) is not required for any of the 7 proposed candidate concepts | Don't Hand-Roll | If a concept requires boolean union for a clean result, paper.js needs to be added; each concept is designed to avoid it |

**Note:** A1 is a LOW-risk assumption. The recommended approach (object form `{ decimalPlaces: 2 }`) is correct regardless of A1.

---

## Open Questions

1. **Font download location: `/tmp/sigra-fonts/` vs `scripts/brand/fonts/`**
   - What we know: CONTEXT says "gitignored temp location"; `/tmp/` is already in `.gitignore`; `scripts/brand/fonts/` would need a new gitignore entry
   - What's unclear: Which approach is better for repeatability across dev machines (where `/tmp/` may be cleaned)
   - Recommendation: Use `scripts/brand/fonts/` with a `.gitignore` entry — this way the downloaded font persists between script runs on the same machine and the developer sees it in the working directory. Add `scripts/brand/fonts/` and `scripts/brand/node_modules/` to `.gitignore`.

2. **Harness HTML location: committed temp dir vs `/tmp/`**
   - What we know: Harness pages are throwaway (CONTEXT: "Renders are throwaway — never committed"); `/tmp/` is gitignored
   - What's unclear: Whether the harness should be recreated each run or kept for manual inspection
   - Recommendation: Generate harness HTML to `/tmp/sigra-harness/` at runtime (created by the critique-render script). This avoids any accidental commit risk and eliminates the need for a gitignore entry.

3. **opentype.js module type in `outline-wordmark.mjs`**
   - What we know: `opentype.js` ships both CJS (`dist/opentype.js`) and ESM (`dist/opentype.mjs`); the `.mjs` script extension in Node.js uses native ESM; npm package has no `exports` map so Node.js will use `main` (CJS) by default even in `.mjs` files via `import` unless `node_modules/opentype.js/package.json` has an `exports` map
   - What's unclear: Whether `import { loadSync } from 'opentype.js'` in a `.mjs` file will resolve to the ESM or CJS build
   - Recommendation: Use CJS require pattern in a `.cjs` file, or use a dynamic `createRequire` in the `.mjs`. Alternatively: `import opentype from 'opentype.js'` (default import of the CJS default export) works reliably. Test the import on first implementation.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | outline-wordmark.mjs, critique-render.mjs | ✓ | v22.14.0 (asdf) | — |
| opentype.js | outline-wordmark.mjs | NOT YET installed | 2.0.0 (npm latest) | — (must install) |
| playwright-core | critique-render.mjs | ✓ | 1.59.1 | — |
| Chromium browser | Playwright screenshot | ✓ | chromium-1223 | — |
| OFL font TTFs | outline-wordmark.mjs input | NOT YET downloaded | See font table above | — (download script step) |
| `scripts/brand/` directory | toolchain scripts | NOT YET | — | Create in Plan 01 |
| Gitignore entries for fonts/node_modules | No-binary-commit constraint | NOT YET | — | Add in Plan 01 before downloading |

**Missing dependencies with no fallback:**
- opentype.js must be installed before the script can run
- Font TTFs must be downloaded before the outline script can run
- `scripts/brand/` directory must be created

**Missing dependencies with fallback:**
- None — all critical dependencies are available or installable without blockers

---

## Validation Architecture

> nyquist_validation: true — section required

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (no test runner for brand scripts) — validation is structural/scripted |
| Config file | n/a |
| Quick run command | `node scripts/brand/outline-wordmark.mjs --help` (or equivalent: script exits 0) |
| Full suite command | See machine-verifiable checks below |

### Machine-Verifiable Checks (Phase Gate)

These checks replace conventional tests for a brand toolchain phase. The planner should include a verification task that runs all of these:

| Check | Command | Pass Condition |
|-------|---------|----------------|
| Script exits 0 | `node scripts/brand/outline-wordmark.mjs [font] [wght] /tmp/test-out.svg` | Exit code 0, file created |
| Output is valid SVG | `python3 -c "import xml.etree.ElementTree as ET; ET.parse('/tmp/test-out.svg'); print('valid')"` | Prints "valid" |
| Output contains `<path>` elements | `grep -c '<path' /tmp/test-out.svg` | Count ≥ 5 (5 glyphs in "sigra") |
| Output contains provenance `<desc>` | `grep -c 'Font:' /tmp/test-out.svg` | Count ≥ 1 |
| No font binaries committed | `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2'` | No output (empty) |
| Candidate count | `ls brandbook/logo-options/round-3/*.svg \| wc -l` | Count ≥ 5 |
| Gallery parses | `python3 -c "from html.parser import HTMLParser; p=HTMLParser(); p.feed(open('brandbook/logo-options/round-3/index.html').read()); print('valid')"` | Prints "valid" |
| README table rows | `grep -c '^\|' brandbook/logo-options/round-3/README.md` | Count ≥ 6 (header + separator + ≥4 rows) |
| tokens.css linked correctly | `grep -c 'tokens.css' brandbook/logo-options/round-3/index.html` | Count = 1 |
| brandbook/README.md has font provenance | `grep -c 'OFL\|outlined\|opentype' brandbook/README.md` | Count ≥ 1 |

### Sampling Rate

- Per plan completion: full check suite above
- Phase gate: All checks green + `git ls-files *.ttf *.otf` returns empty before PR

### Wave 0 Gaps

- [ ] `scripts/brand/package.json` — opentype.js dependency declaration
- [ ] `scripts/brand/outline-wordmark.mjs` — toolchain script
- [ ] `scripts/brand/` gitignore entries for fonts/ and node_modules/
- [ ] `brandbook/logo-options/round-3/` directory

---

## Security Domain

> This phase makes no runtime changes to Sigra's auth library, LiveViews, or any user-facing surface. ASVS categories V2, V3, V4, V6 do not apply.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Brand toolchain only |
| V3 Session Management | No | Brand toolchain only |
| V4 Access Control | No | Brand toolchain only |
| V5 Input Validation | No | No user input |
| V6 Cryptography | No | No secrets |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious font file from untrusted download | Tampering | Only download from official GitHub repos (google/fonts, rsms/inter, floriankarsten, tokotype, vercel) — verified OFL sources; do not accept user-provided font paths |
| `postinstall` script in opentype.js | Tampering | Verified: opentype.js has no `scripts.postinstall` — no risk |

---

## Plan Breakdown Recommendation

**Two plans (not three):**

**Plan 01 — Toolchain + harness infrastructure** (BRAND2-04 deliverable)
- Create `scripts/brand/` directory
- Add gitignore entries for `scripts/brand/fonts/`, `scripts/brand/node_modules/`
- Create `scripts/brand/package.json` with opentype.js dependency
- `npm install` inside `scripts/brand/`
- Write `scripts/brand/outline-wordmark.mjs` (outline script)
- Write `scripts/brand/critique-render.mjs` (Playwright screenshot script)
- Download OFL fonts to `scripts/brand/fonts/` (Space Grotesk, Inter, Syne, Plus Jakarta Sans — 4 candidate fonts minimum)
- Run validation checks: script exits 0, SVG is valid, no binaries in git
- Update `brandbook/README.md` with font provenance section

**Plan 02 — Candidates + critique loop + gallery** (BRAND2-05 + BRAND2-06 deliverables)
- Generate wordmark base path SVGs for each candidate font
- Author 5–7 candidate SVG files (manual + script-assisted motif integration)
- Create throwaway harness HTML for each candidate
- Run critique-render.mjs for each candidate at 16/32/54/hero × light/dark
- Self-critique against brief rubric; iterate
- Create `brandbook/logo-options/round-3/index.html` (gallery)
- Create `brandbook/logo-options/round-3/README.md` (rationale table)
- Run final validation checks

---

## Sources

### Primary (HIGH confidence)
- `brandbook/logo-v2-design-brief.md` — design contract, OFL candidates, letterform anatomy, rubric, deliverables [VERIFIED: local file read]
- `.planning/phases/179-outlining-toolchain-logo-concept-exploration/179-CONTEXT.md` — implementation decisions, scope, constraints [VERIFIED: local file read]
- `.planning/REQUIREMENTS.md` BRAND2-04..06 — requirement text [VERIFIED: local file read]
- opentype.js 2.0.0 source at `/tmp/opentype-test/node_modules/opentype.js/dist/opentype.js` — API methods, `VariationManager`, `toPathData` defaults [VERIFIED: npm registry + local runtime inspection]
- `test/example/priv/playwright/node_modules/playwright-core` v1.59.1 — confirmed standalone `chromium.launch()` + `file://` screenshot [VERIFIED: local runtime test]
- `~/Library/Caches/ms-playwright/chromium-1223/` — Chromium browser binary confirmed present [VERIFIED: local inspection]
- `brandbook/logo-options/round-2/index.html` — gallery HTML skeleton fully read [VERIFIED: local file read]
- `brandbook/logo-primary.svg` — v1 conventions: outlined paths, title/desc pattern, per-glyph transforms [VERIFIED: local file read]

### Secondary (MEDIUM confidence)
- `github.com/google/fonts/ofl/syne/Syne[wght].ttf` — variable font download URL [VERIFIED: GitHub API]
- `github.com/google/fonts/ofl/spacegrotesk/SpaceGrotesk[wght].ttf` — variable font download URL [VERIFIED: GitHub API]
- `github.com/tokotype/PlusJakartaSans/releases/2.7.1/PlusJakartaSans-2.7.1.zip` — release URL [VERIFIED: GitHub releases API]
- `github.com/vercel/geist-font/releases/v1.7.2/geist-font-v1.7.2.zip` — release URL [VERIFIED: GitHub releases API]
- `github.com/rsms/inter/releases/v4.1/Inter-4.1.zip` — release URL [VERIFIED: GitHub releases API]

### Tertiary (LOW confidence — training knowledge, not re-verified this session)
- paper.js as a boolean path operations library: exists on npm at v0.12.18, not installed — mentioned as fallback option only

---

## Metadata

**Confidence breakdown:**
- Standard stack (opentype.js API): HIGH — confirmed from live npm install + source inspection
- Playwright file:// screenshot: HIGH — confirmed via runtime test in repo's own playwright install
- Font download URLs: HIGH — confirmed via GitHub releases API
- Variable font `variation.set` API: HIGH — confirmed from opentype.js 2.0.0 source
- Candidate concept directions: MEDIUM — design judgment; the rubric defines success criteria, not the research

**Research date:** 2026-06-12
**Valid until:** 2026-07-12 (stable domain — opentype.js and Playwright APIs are slow-moving)
