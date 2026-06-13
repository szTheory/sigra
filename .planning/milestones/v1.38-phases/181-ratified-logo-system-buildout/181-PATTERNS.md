# Phase 181: Ratified Logo System Buildout - Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 10 (8 production SVGs + README.md update + archive-v1/README.md)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `brandbook/logo-primary.svg` | brand-asset / svg | transform (adapt source geometry) | `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` | exact |
| `brandbook/logo-primary-dark.svg` | brand-asset / svg | transform (adapt source geometry) | `brandbook/logo-options/round-4/d4-linked-rail-typemark-dark.svg` | exact |
| `brandbook/logo-primary-subtitle.svg` | brand-asset / svg | transform + extend (new text block) | `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` + social-card.svg `<text>` style | role-match |
| `brandbook/logo-mark.svg` | brand-asset / svg | transform (adapt favicon source, drop media query) | `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` | exact |
| `brandbook/logo-monochrome.svg` | brand-asset / svg | transform (collapse ember to ink) | `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` | role-match |
| `brandbook/favicon.svg` | brand-asset / svg | direct copy + updated provenance | `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` | exact |
| `brandbook/social-card.svg` | brand-asset / svg | adapt layout (replace mark paths, keep composition) | `brandbook/social-card.svg` (v1, inline) | role-match |
| `brandbook/social-card-dark.svg` | brand-asset / svg | adapt (dark fills, new file) | `brandbook/social-card.svg` (v1) + dark fill conventions | role-match |
| `brandbook/README.md` | documentation | extend (add clearspace/misuse section) | `brandbook/README.md` (existing structure) | exact |
| `brandbook/logo-options/archive-v1/README.md` | documentation | new (deprecation note) | `brandbook/logo-options/round-4/README.md` style | partial |

---

## Pattern Assignments

### `brandbook/logo-primary.svg` (brand-asset, adapt exact source)

**Analog:** `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg`

**SVG root pattern** (line 1):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 220 2410 1026" role="img" aria-labelledby="title desc">
```

**Accessibility shell pattern** (lines 2-3):
```xml
  <title id="title">Sigra primary logo</title>
  <desc id="desc">The Sigra D4 Linked Rail typemark for light surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0. Ember-700 (#c2410c) rail tittle and g-tail bracket. See brandbook/README.md for usage rules.</desc>
```

**Glyph group pattern** (line 4):
```xml
  <g id="glyphs" fill="#151515">
```

**Ember rect pattern** (line 11):
```xml
  <rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#c2410c" />
```

**What must NOT change from the source:** All 5 path `d=` values for g-0 through g-4. The g-2 path includes the descender plate to y=1200 and the tail that terminates at x=557. The viewBox `0 220 2410 1026` is the only value that fits the 54px topbar slot without clipping.

**What changes from the source:** `<title>` text, `<desc>` text (update "Round-4 A1 refinement D4" to production language).

---

### `brandbook/logo-primary-dark.svg` (brand-asset, adapt exact source)

**Analog:** `brandbook/logo-options/round-4/d4-linked-rail-typemark-dark.svg`

**SVG root pattern** (line 1 — identical viewBox to light):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 220 2410 1026" role="img" aria-labelledby="title desc">
```

**Accessibility shell pattern** (lines 2-3):
```xml
  <title id="title">Sigra primary logo for dark surfaces</title>
  <desc id="desc">The Sigra D4 Linked Rail typemark for dark surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0. Ember-300 (#fdba74) rail tittle on dark. See brandbook/README.md for usage rules.</desc>
```

**Dark fill divergence** (line 4 vs light):
```xml
  <g id="glyphs" fill="#f4f1eb">   <!-- warm white, NOT #151515 -->
```

**Dark ember rect** (line 11 — CRITICAL difference from light):
```xml
  <rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#fdba74" />
```

**Pitfall guard:** After writing this file, run `grep '#c2410c' brandbook/logo-primary-dark.svg` — must return zero hits. Any ember-700 in the dark variant is a copy-paste error.

---

### `brandbook/logo-primary-subtitle.svg` (brand-asset, extend typemark + add text)

**Primary analog:** `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` (glyph + ember rect — identical)
**Secondary analog for text style:** `brandbook/social-card.svg` lines 14-15 and 29 (`.type` class + system font stack)

**SVG root pattern — extended viewBox** (viewBox height must grow to accommodate subtitle):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 220 2410 1380" role="img" aria-labelledby="title desc">
```
Note: original bottom is y=1246 (220+1026); subtitle text sits at y≈1320; extra 354 units gives comfortable padding. Tune after render.

**Accessibility shell pattern** (lines 2-3):
```xml
  <title id="title">Sigra primary logo with subtitle</title>
  <desc id="desc">The Sigra D4 Linked Rail typemark with tagline for light surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0. Subtitle in system font. See brandbook/README.md for usage rules.</desc>
```

**Glyph group and ember rect** (identical to logo-primary.svg — do not diverge):
```xml
  <g id="glyphs" fill="#151515">
    <!-- all 5 path elements unchanged from d4-linked-rail-typemark.svg -->
  </g>
  <rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#c2410c" />
```

**Subtitle text element pattern** (derived from social-card.svg `.type .muted` style at line 9 + `<text>` at line 33):
```xml
  <text
    x="60"
    y="1320"
    font-family="ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    font-size="200"
    fill="#686868"
    letter-spacing="0"
  >Phoenix auth that ships</text>
```
Note: x=60 aligns with the leftmost visible glyph extent. font-size=200 is ~20% of the 1000-unit cap height — tune to taste after render. The social-card.svg analog uses `font-family: ui-sans-serif, system-ui, ...` (line 14) and `fill: #686868` for the `.muted` class (line 9). Use those verbatim.

**What must NOT happen:** Do not run `outline-wordmark.mjs` on the subtitle text. The subtitle uses live SVG `<text>` with a system font stack — not outlined paths. The main "sigra" wordmark is already outlined in the glyph paths and must not be re-outlined.

---

### `brandbook/logo-mark.svg` (brand-asset, adapt favicon source, explicit fills)

**Analog:** `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg`

**Full source** (lines 1-10 of the analog):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-70 -60 1040 1040" role="img" aria-labelledby="title desc">
  <title id="title">Sigra D4 linked rail favicon</title>
  <desc id="desc">Font: Space Grotesk v2.0 (OFL) wght=700. D4 favicon: abstract rail glyph: ink stem with leftward foot (the g-tail echo) and the ember block above, no letter. Derived from round-3 a1 outlines (opentype.js 2.0.0). Generated 2026-06-12.</desc>
  <style>#glyphs { fill: #151515; } #rail-block { fill: #c2410c; } @media (prefers-color-scheme: dark) { #glyphs { fill: #f4f1eb; } #rail-block { fill: #fdba74; } }</style>
  <g id="glyphs">
    <rect x="540" y="360" width="180" height="580" />
    <rect x="180" y="760" width="540" height="180" />
  </g>
  <rect id="rail-block" x="400" y="-20" width="320" height="320" />
</svg>
```

**Divergence for logo-mark.svg:** The mark file is used as an `<img>` in HTML, not as a browser tab favicon. Decision: KEEP the `prefers-color-scheme` media query so the mark "just works" in both light and dark HTML contexts without needing a separate dark variant file. This is the better DX choice. Only changes from the source:

```xml
  <title id="title">Sigra mark</title>
  <desc id="desc">Sigra D4 Linked Rail free-standing mark. Abstract rail glyph: ink stem, leftward foot, ember-700 (#c2410c) rail block on light; ember-300 (#fdba74) on dark via prefers-color-scheme. Use as UI accent on any surface.</desc>
```

**viewBox is square and must stay exactly:** `-70 -60 1040 1040` (width=1040, height=1040 — both 1040). The negative offsets are intentional padding, not an error.

---

### `brandbook/logo-monochrome.svg` (brand-asset, collapse ember to ink)

**Analog:** `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` (glyph paths) + v1 `brandbook/logo-monochrome.svg` (structural reference)

**V1 monochrome pattern** (`brandbook/logo-monochrome.svg` lines 4-6 — shows opacity trick used in v1):
```xml
  <path d="M17 14v15M32 23v18M47 35v15" fill="none" stroke="#151515" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 35v15M47 14v15" fill="none" stroke="#151515" stroke-width="8" stroke-linecap="round" opacity="0.72"/>
  <path d="M17 32h30" fill="none" stroke="#151515" stroke-width="4" stroke-linecap="round"/>
```

**D4 divergence — DO NOT use opacity trick.** The v1 mark used opacity=0.72 because its two groups were spatially overlapping path strokes. The D4 ember block (200×200 rect) is spatially distinct from the glyph strokes by position (it sits above at y=246, while glyphs start at y=490). Use solid ink for both:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 220 2410 1026" role="img" aria-labelledby="title desc">
  <title id="title">Sigra monochrome logo</title>
  <desc id="desc">Sigra D4 Linked Rail typemark in single ink for restricted-color contexts. No color distinction between wordmark and rail accents. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0.</desc>
  <g id="glyphs" fill="#151515">
    <!-- identical 5 path elements from d4-linked-rail-typemark.svg -->
  </g>
  <rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#151515" />
                                                                                    <!-- ↑ same ink as glyphs, NOT #c2410c -->
</svg>
```

**Render check:** At 54px, the ember rect (now ink) must still read as spatially distinct from the i stem. The rect sits 244 units above the glyph baseline (y=246 vs glyph cap top y~490 minus descenders). At solid ink it should remain visually distinct because of position, not color.

---

### `brandbook/favicon.svg` (brand-asset, direct copy + updated provenance)

**Analog:** `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` (lines 1-10 — copy essentially verbatim)

**Complete production pattern:**
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-70 -60 1040 1040" role="img" aria-labelledby="title desc">
  <title id="title">Sigra</title>
  <desc id="desc">Sigra D4 Linked Rail favicon mark. Abstract rail glyph: ink stem, leftward foot, ember-700 (#c2410c) rail block on light; adapts to dark mode via prefers-color-scheme.</desc>
  <style>#glyphs { fill: #151515; } #rail-block { fill: #c2410c; } @media (prefers-color-scheme: dark) { #glyphs { fill: #f4f1eb; } #rail-block { fill: #fdba74; } }</style>
  <g id="glyphs">
    <rect x="540" y="360" width="180" height="580" />
    <rect x="180" y="760" width="540" height="180" />
  </g>
  <rect id="rail-block" x="400" y="-20" width="320" height="320" />
</svg>
```

**What must NOT change:** viewBox `-70 -60 1040 1040`, all rect coordinates, the `<style>` media query block, the `id="glyphs"` and `id="rail-block"` attributes (the CSS selects by id).

**Differences from source:** `<title>` becomes `"Sigra"` (not `"Sigra D4 linked rail favicon"`), `<desc>` updated to production language.

**Kill test:** Must read as two distinct elements (stem+foot group vs ember block) at 16px rendered size. The source passed this in round-4 — preserve its geometry exactly.

---

### `brandbook/social-card.svg` (brand-asset, adapt v1 layout + replace mark paths)

**Analog:** `brandbook/social-card.svg` (v1, full file — composition, CSS classes, text layout preserved; only mark geometry changes)

**Root + dimensions pattern** (v1 line 1 — keep verbatim):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-labelledby="title desc">
```

**Accessibility shell** (v1 lines 2-3):
```xml
  <title id="title">Sigra social preview card</title>
  <desc id="desc">A social preview card for Sigra featuring the D4 Linked Rail typemark.</desc>
```

**CSS classes pattern** (v1 lines 5-16 — preserve all classes, add `.ember` if needed):
```xml
  <defs>
    <style>
      .bg { fill: #f6f5f2; }
      .panel { fill: #ffffff; stroke: rgba(21, 21, 21, 0.12); }
      .ink { fill: #151515; }
      .muted { fill: #686868; }
      .accent { fill: #c2410c; }
      .strong { fill: #9a3412; }
      .warm { fill: #fdba74; }
      .soft { fill: #fff0e8; }
      .type { font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; letter-spacing: 0; }
      .mono { font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace; letter-spacing: 0; }
    </style>
  </defs>
```

**Layout structure** (v1 lines 18-20 — preserve background + topbar + panel):
```xml
  <rect class="bg" width="1200" height="630"/>
  <path d="M0 0h1200v22H0z" fill="#151515"/>
  <rect x="72" y="70" width="1056" height="488" rx="24" class="panel"/>
```

**Mark replacement — v2 D4 abstract glyph** (replaces v1 Rail Accent paths in the first `<g transform="translate(104 106)">`):
The v2 mark uses the D4 abstract rail glyph geometry from `d4-linked-rail-favicon.svg`, scaled appropriately. Scale the viewBox coordinates (~900-unit space) down to the ~64-unit target by applying a scale transform. Example at `scale(0.075)` the glyph fits in ~68px:
```xml
  <g transform="translate(104 106) scale(0.075)">
    <g id="sc-glyphs" fill="#151515">
      <rect x="540" y="360" width="180" height="580" />
      <rect x="180" y="760" width="540" height="180" />
    </g>
    <rect id="sc-rail-block" x="400" y="-20" width="320" height="320" fill="#c2410c"/>
  </g>
```
Note: Use unique ids (`sc-glyphs`, `sc-rail-block`) in the social card to avoid id collision with favicon.svg if both are embedded in the same HTML page.

**Wordmark text in social card** (v1 line 29 — uses live text not outlined paths, system font):
```xml
  <text x="186" y="154" class="type ink" font-size="56" font-weight="850">Sigra</text>
```
Keep this pattern. Social card wordmark does not need to be outlined paths.

**Tagline and install snippet** (v1 lines 31-38 — keep the v1 composition, only replace the mark):
```xml
  <text x="104" y="256" class="type ink" font-size="60" font-weight="850">Auth you can keep</text>
  <text x="104" y="326" class="type ink" font-size="60" font-weight="850">patching after install.</text>
  <text x="104" y="392" class="type muted" font-size="25" font-weight="650">Library-owned security-sensitive behavior. Generated Phoenix code you can review.</text>
  <g transform="translate(104 448)">
    <rect width="510" height="64" rx="10" fill="#151515"/>
    <text x="24" y="40" class="mono" fill="#f4f1eb" font-size="22">mix sigra.install Accounts User users</text>
  </g>
```

**Right panel — replace v1 mark with D4 mark** (v1 lines 40-47 used scaled v1 Rail Accent strokes; replace with D4 abstract glyph scaled to fit the 286×356 panel):
```xml
  <g transform="translate(768 128)">
    <rect x="0" y="0" width="286" height="356" rx="18" class="soft"/>
    <!-- D4 abstract mark, scaled to ~240px within the panel -->
    <g transform="translate(23 20) scale(0.24)">
      <g fill="#151515">
        <rect x="540" y="360" width="180" height="580" />
        <rect x="180" y="760" width="540" height="180" />
      </g>
      <rect x="400" y="-20" width="320" height="320" fill="#c2410c"/>
    </g>
  </g>
```

**No CDN or font imports:** The v1 social card has none; v2 must also have none. System font stack only.

---

### `brandbook/social-card-dark.svg` (brand-asset, dark surface variant — new file)

**Primary analog:** `brandbook/social-card.svg` (v2 light, same composition)
**Fill reference:** `brandbook/logo-options/round-4/d4-linked-rail-typemark-dark.svg` (dark fill values)

**Root + dimensions pattern** (identical to light variant):
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-labelledby="title desc">
```

**Accessibility shell:**
```xml
  <title id="title">Sigra social preview card (dark)</title>
  <desc id="desc">A dark-surface social preview card for Sigra featuring the D4 Linked Rail typemark.</desc>
```

**CSS classes for dark surface** (diverge from light on `.bg`, `.panel`, `.ink`):
```xml
  <defs>
    <style>
      .bg { fill: #171614; }                          <!-- dark surface -->
      .panel { fill: #1e1c1a; stroke: rgba(244, 241, 235, 0.10); }  <!-- dark panel -->
      .ink { fill: #f4f1eb; }                         <!-- warm white text -->
      .muted { fill: #a0998f; }                       <!-- muted on dark -->
      .accent { fill: #fdba74; }                      <!-- ember-300 on dark -->
      .strong { fill: #c2410c; }                      <!-- ember-700 as strong accent on dark -->
      .warm { fill: #fdba74; }
      .soft { fill: #2a2520; }                        <!-- dark soft background -->
      .type { font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; letter-spacing: 0; }
      .mono { font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace; letter-spacing: 0; }
    </style>
  </defs>
```

**Mark fill divergence in dark card:** Use `fill="#f4f1eb"` for glyphs and `fill="#fdba74"` for ember rail-block (ember-300 on dark).

**Pitfall guard:** After writing, `grep '#c2410c' brandbook/social-card-dark.svg` must return only hits in the `.strong` class definition, never in the mark fill or ember block.

---

### `brandbook/README.md` (documentation, extend with v2 usage rules)

**Analog:** `brandbook/README.md` (existing structure — the new section appends after the existing "Maintenance Rules" section)

**Current README structure** (lines 1-60):
- `## Open The Brand Book`
- `## Files` (table)
- `## Logo System` (update text to reference D4 / v2)
- `## Font Provenance` (table — add Space Grotesk production entry)
- `## Maintenance Rules`
- `## Suggested Checks`

**New section to insert — clearspace and minimum sizes (after "## Logo System"):**
```markdown
## Logo System Usage Rules

### Clearspace

Minimum clearspace around the **mark** = 0.25 × rendered mark height.
Minimum margin around the **typemark** = 0.15 × rendered typemark height.

### Minimum Sizes

| Context | Minimum rendered height | Notes |
|---------|------------------------|-------|
| Favicon (kill test) | 16px | Abstract rail glyph; ember block legible from 16px |
| UI accent (mark only) | 24px | Block + stem readable |
| Topbar lockup | 32px | Wordmark legible; 54px is the target slot |
| Marketing / docs | 120px | Full typemark with subtitle; below 120px subtitle text is hard to read |

### Misuse Examples

1. **Incorrect surface:** Using `logo-primary.svg` on a dark background — ink wordmark becomes invisible. Use `logo-primary-dark.svg` on dark surfaces.
2. **Scaling below minimum:** Displaying the typemark below 32px — "sigra" letters are no longer distinguishable; use `favicon.svg` (the abstract mark) instead.
3. **Rectangular container:** Wrapping the mark in a box, badge, or pill — the D4 mark is designed for transparent/colored surfaces without containers.
4. **Wrong ember hue:** Substituting `#c2410c` with a bright orange or red outside hue 15–40° — breaks brand differentiation from Phoenix Framework and Ash.
5. **Rotating or reflecting:** The rail direction (vertical stem, leftward foot, upper-right block) is the spatial system — rotation breaks the metaphor.
6. **Live text wordmark:** Recreating "sigra" in any font at runtime — the wordmark is outlined paths that must render identically at all sizes without font loading.

### Palette Values (v2 / D4)

| Context | Glyph fill | Ember accent |
|---------|-----------|--------------|
| Light surface | `#151515` (ink) | `#c2410c` (ember-700) |
| Dark surface | `#f4f1eb` (warm white) | `#fdba74` (ember-300) |
| Monochrome | `#151515` | `#151515` (ember block → solid ink) |
| Favicon | CSS via prefers-color-scheme | CSS via prefers-color-scheme |
```

**Font Provenance table — new row to add:**
```markdown
| Space Grotesk | v2.0.0 | OFL | github.com/floriankarsten/space-grotesk | logo-primary.svg (v2), all D4 production assets |
```

---

### `brandbook/logo-options/archive-v1/README.md` (documentation, deprecation note)

**Analog:** `brandbook/logo-options/round-4/README.md` (heading + table style)

**Pattern:**
```markdown
# Sigra Brandbook — v1 Archive

These files are the original Rail Accent logo assets (v1) superseded by the D4 Linked Rail
production set in Phase 181 (2026-06-12). They are preserved here for historical reference.

**Do not use these files.** The canonical production assets are in `brandbook/` (one level up).

## Archived Files

| File | v1 Concept | Superseded by |
|------|-----------|---------------|
| `logo-primary.svg` | Rail Accent staircase mark + Inter Display Black wordmark | `brandbook/logo-primary.svg` (D4) |
| `logo-primary-dark.svg` | Same, dark wordmark `#f4f1eb` | `brandbook/logo-primary-dark.svg` (D4) |
| `logo-mark.svg` | 3-bar Rail Accent staircase mark | `brandbook/logo-mark.svg` (D4 abstract rail glyph) |
| `logo-monochrome.svg` | Monochrome Rail Accent mark, opacity=0.72 secondary | `brandbook/logo-monochrome.svg` (D4 solid ink) |
| `favicon.svg` | 3-bar Rail Accent mark (same geometry as logo-mark) | `brandbook/favicon.svg` (D4 abstract rail glyph) |
| `social-card.svg` | OG 1200×630 Rail Accent + tagline | `brandbook/social-card.svg` (D4) |
```

---

## Shared Patterns

### SVG Accessibility Shell
**Source:** `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` (line 1) + all v1 brandbook/*.svg files
**Apply to:** Every new SVG file

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="..." role="img" aria-labelledby="title desc">
  <title id="title">...</title>
  <desc id="desc">...</desc>
```

This pattern is present in EVERY existing v1 production file and every round-4 candidate. No new file may omit it.

### Font Provenance in `<desc>`
**Source:** `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` (line 3)
**Apply to:** All typemark SVGs (logo-primary, logo-primary-dark, logo-primary-subtitle, logo-monochrome)

```xml
<desc id="desc">Font: Space Grotesk v2.0 (OFL) wght=700. [Design description]. Derived from round-3 a1 outlines (opentype.js 2.0.0). [Production context].</desc>
```

The favicon and mark SVGs (logo-mark.svg, favicon.svg) use a variant that notes the font context even though no letter glyphs are present, per the source analog `d4-linked-rail-favicon.svg` line 3.

### Hardcoded Fill Values (no `currentColor`)
**Source:** `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` (line 4), `brandbook/logo-options/round-4/d4-linked-rail-typemark-dark.svg` (line 4)
**Apply to:** logo-primary.svg, logo-primary-dark.svg, logo-primary-subtitle.svg, logo-monochrome.svg, social-card.svg, social-card-dark.svg

Light: `fill="#151515"` (glyph group), `fill="#c2410c"` (ember rect)
Dark: `fill="#f4f1eb"` (glyph group), `fill="#fdba74"` (ember rect)

Never use `currentColor` or CSS variable fills in the production typemark assets. Hardcoded fills ensure render fidelity across all SVG-as-img contexts.

### prefers-color-scheme Media Query (favicon and mark only)
**Source:** `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` (line 4)
**Apply to:** favicon.svg AND logo-mark.svg (both used as browser-context `<img>` where OS dark mode should respond)

```xml
<style>#glyphs { fill: #151515; } #rail-block { fill: #c2410c; } @media (prefers-color-scheme: dark) { #glyphs { fill: #f4f1eb; } #rail-block { fill: #fdba74; } }</style>
```

The typemark files (logo-primary, logo-primary-dark, etc.) are explicit light/dark variants and do NOT use this pattern.

### Social Card System Font Stack
**Source:** `brandbook/social-card.svg` lines 14-15
**Apply to:** social-card.svg (v2), social-card-dark.svg, logo-primary-subtitle.svg (subtitle text element)

```xml
font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif
```
```xml
font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace
```

No CDN, no `@import`, no `<link>` for fonts in any SVG.

### viewBox Square Invariant (favicon / mark)
**Source:** `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` (line 1)
**Apply to:** favicon.svg, logo-mark.svg

viewBox 3rd and 4th values must be equal: `-70 -60 1040 1040`. The negative offsets (-70, -60) are padding — the width (1040) and height (1040) are both 1040. Do not "fix" the negative offsets.

---

## No Analog Found

All 10 files have analogs in the codebase. There are no files requiring reference to RESEARCH.md external patterns only.

---

## Derivation Map (Execution Cheat Sheet)

| Production File | Source File | Operation |
|----------------|------------|-----------|
| `logo-primary.svg` | `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` | Copy + update `<title>`/`<desc>` only |
| `logo-primary-dark.svg` | `brandbook/logo-options/round-4/d4-linked-rail-typemark-dark.svg` | Copy + update `<title>`/`<desc>` only |
| `logo-primary-subtitle.svg` | `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` | Copy + extend viewBox + add `<text>` subtitle |
| `logo-mark.svg` | `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` | Copy + update `<title>`/`<desc>` (keep media query) |
| `logo-monochrome.svg` | `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` | Copy + set ember rect fill to `#151515` |
| `favicon.svg` | `brandbook/logo-options/round-4/d4-linked-rail-favicon.svg` | Copy + update `<title>` to "Sigra" + update `<desc>` |
| `social-card.svg` | `brandbook/social-card.svg` (v1) | Keep layout/CSS/text; replace mark path group with D4 abstract glyph |
| `social-card-dark.svg` | `brandbook/social-card.svg` (v2, just written) | Mirror structure + swap all fills to dark surface values |
| `brandbook/README.md` | `brandbook/README.md` (existing) | Add usage rules section, update Logo System prose, add font provenance row |
| `brandbook/logo-options/archive-v1/README.md` | `brandbook/logo-options/round-4/README.md` (style) | New file — deprecation note + table of archived files |

---

## Metadata

**Analog search scope:** `brandbook/`, `brandbook/logo-options/round-4/`, `brandbook/logo-options/round-3/`, `brandbook/examples/`
**Files scanned:** 14 SVG files + 3 README files + 1 social-card specimen
**Pattern extraction date:** 2026-06-12
