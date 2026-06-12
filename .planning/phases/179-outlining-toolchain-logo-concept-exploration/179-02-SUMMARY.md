---
phase: "179"
plan: "02"
subsystem: brand-identity
tags: [brand, logo, typemark, svg, rail-accent, render-critique]
dependency_graph:
  requires: [scripts/brand/outline-wordmark.mjs, scripts/brand/critique-render.mjs, brandbook/logo-v2-design-brief.md]
  provides: [brandbook/logo-options/round-3 gallery with 7 render-gated candidates]
  affects: [Phase 180 human ratification gate]
tech_stack:
  added: []
  patterns:
    - "variation-aware glyph.getPath(x, y, fontSize, {}, font) for variable-font instancing"
    - "toPathData({ flipY: false }) on getPath output (already SVG-oriented)"
    - "scheme-adaptive favicon SVGs via internal prefers-color-scheme style"
    - "Playwright render-critique loop: harness HTML -> 8 PNGs -> Read -> iterate"
key_files:
  created:
    - brandbook/logo-options/round-3/index.html
    - brandbook/logo-options/round-3/README.md
    - brandbook/logo-options/round-3/a1-rail-i-typemark.svg (+dark, +favicon)
    - brandbook/logo-options/round-3/a2-descender-rail-typemark.svg (+dark, +favicon)
    - brandbook/logo-options/round-3/a3-crossbar-s-typemark.svg (+dark, +favicon)
    - brandbook/logo-options/round-3/a4-ember-dot-typemark.svg (+dark, +favicon)
    - brandbook/logo-options/round-3/b1-redesigned-mark-primary.svg (+dark, +mark, +favicon)
    - brandbook/logo-options/round-3/b2-letterform-sub-primary.svg (+dark, +favicon)
    - brandbook/logo-options/round-3/c1-stacked-primary.svg (+dark, +favicon)
  modified:
    - scripts/brand/outline-wordmark.mjs
decisions:
  - "A3 crossbar-s concept reworked to rail-g after failing the render gate twice; filenames retained per plan file list"
  - "B2 s-substitute is a continuous serpentine rail-switchback stroke (vertical and offset-horizontal bar attempts failed the letter-likeness test)"
  - "C1 mark moved from interline to line-1 negative space after interline placement broke word continuity twice"
  - "PJS ExtraBold s/r terminals natively flat-cut; destructive re-cutting skipped to avoid stroke-contrast damage"
  - "With-subtitle gallery blocks omit a duplicate HTML 'sigra' word (every candidate SVG already contains the full wordmark); subtitle text only"
  - "Favicons adapt light/dark via internal prefers-color-scheme media query; gallery pins color-scheme:light on sample chips"
metrics:
  duration: "~40 minutes"
  completed: "2026-06-12"
  tasks_completed: 3
  files_created: 24
  files_modified: 1
requirements: [BRAND2-05, BRAND2-06]
---

# Phase 179 Plan 02: Logo Concept Exploration + Round-3 Gallery Summary

Seven render-gated logo candidates (4 integrated typemarks, 2 refined lockups, 1 stacked wildcard) authored via opentype.js path surgery, each iterated through the Playwright critique loop at 16/32/54px + hero in light and dark, and assembled into the `brandbook/logo-options/round-3/` gallery for the Phase 180 human ratification gate. Two latent toolchain bugs (ignored variable-font axis, double Y-flip) were caught by actually reading renders and fixed before any candidate work.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Direction A integrated typemarks A1-A4 | a6be5ca0 | 12 SVGs (4 candidates x typemark/dark/favicon) |
| 2 | B1/B2 refined lockups + C1 wildcard | 3437b867 | 10 SVGs (B1 has 4 files incl. stand-alone mark) |
| 3 | Round-3 gallery index.html + README.md | 16a6cddd | index.html (7 option cards), README.md (7-row rationale table) |

Toolchain fixes (pre-task deviations): ec2bd48b, 5a02a270.

## Verification Results

All 8 plan verification checks passed:

1. `ls round-3/*.svg | wc -l` → 22 (≥22 required)
2. All 22 SVGs parse as valid XML
3. Gallery HTML parses valid
4. `tokens.css` linked exactly once (`../../tokens.css`)
5. README pipe rows → 9 (header + separator + 7 data rows)
6. `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2'` → empty
7. brandbook/README.md provenance greps → 7
8. Critique notes sections → 15 (covering all 7 candidates with iteration history)

Gallery smoke: full-page Playwright screenshot read and inspected — all 7 option cards render with light/dark lockups, with-subtitle previews, mark stages, and 32/24/16px favicon rows; no broken images.

## Critique Summary

Render evidence: ~60 PNG screenshots read with the Read tool across 7 candidates x 4 scales x 2 color schemes plus iteration re-renders and zoomed crops. Full iteration-by-iteration notes in `/tmp/sigra-critique-notes.md` (throwaway, not committed).

**A1 Rail-i (Space Grotesk Bold) — approved at iteration 2.**
16px: "ig" crop silhouette readable, ember block visible light+dark. 54px: legible, no clipping, tattoo row coherent. Hero: extended g tail reads as a deliberate rail gesture; tittle block proportion matches stem weight after enlargement (162x160 → 174x174). Iteration 1→2: enlarged tittle block, tightened favicon crop.

**A2 Descender-rail (Plus Jakarta Sans ExtraBold) — approved at iteration 2.**
16px: g + rail silhouette readable after the bar was attached to the bowl. 54px: no clipping (viewBox 1080 high, tallest of the A-set per descender-overflow requirement). Hero: descender visibly sweeps into the round-cap ember-800 rail. Iteration 1→2: bar start moved left (1380→1355 typemark, →1330 favicon) — at raster scales the bar previously read as a detached underscore. PJS terminals verified natively flat-cut via zoomed crop; destructive re-cutting deliberately skipped.

**A3 Rail-g (Syne ExtraBold) — approved at iteration 3, after concept rework.**
Iterations 1–2 (crossbar-s as planned) FAILED: Syne's s spine tips point inward in a tight spiral, so any horizontal terminal bar crosses the visual counters and reads as a band-aid/stray dash. Honest verdict recorded: the planned concept fights this font's anatomy and the brief's fallback (terminal-only flat cuts) is a no-op since Syne terminals are already flat. Reworked: the g's native horizontal descender plate color-blocked as the ember-800 rail. Final: 16px marginal-pass (bowl counter tightens, silhouette still distinct), 32px/54px/hero pass, tattoo pass. Filenames keep the `a3-crossbar-s-*` prefix per the plan's file list; title/desc/gallery name the concept "Rail-g".

**A4 Ember-dot (Inter Display Black) — approved at iteration 1.**
16px: strongest favicon of the A-set ("i" + ember dot reads in both schemes). 54px/hero: dot (r330 ≈ 1.67x original tittle width) balanced above cap-height. Distinctiveness scored low (58%) BY DESIGN — this is the conservative benchmark candidate the others must beat; caveat documented in the gallery card.

**B1 Redesigned mark + Space Grotesk — approved at iteration 1.**
16px: two staggered ember pills + core line read cleanly where v1's three bars blurred. Hero: mark touches the s and extends ~24% em below the wordmark baseline (boundary-breaking, no container). Tattoo: word carries the silhouette; light ember tones fade at 50% gray as expected.

**B2 Letterform substitution (Geist Black) — approved at iteration 3.**
Critical test (does the s-substitute read as a letter?): iteration 1 vertical bar column FAILED (audio-meter icon + "igra"); iteration 2 offset horizontal bars FAILED (hamburger icon). Iteration 3: continuous serpentine rail-switchback stroke PASSES — reads as a squared technical s AND a rail path at every scale including the 16px favicon, and its 130-UPM stroke exactly matches Geist Black's horizontal stroke weight (no stroke-contrast damage).

**C1 Stacked (Plus Jakarta Sans ExtraBold) — approved at iteration 3.**
Interline mark placement failed twice (a mark wedged between "si" and "gra" breaks word continuity at any size — read as "si-H-gra"). Iteration 3: stack tightened (interline 420→188) and the Rail Accent mark set into line-1's natural right void as glyph-scale columns. Favicon is the v1 Rail Accent mark alone per plan (stacked wordmark illegible at 16px); reads at 16/32 in both schemes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Variable-font weight axis silently ignored by glyph outlining**
- **Found during:** Task 1 — pre-surgery weight verification (wght=300 and wght=700 produced identical paths)
- **Issue:** `glyph.getPath(x, y, fontSize)` only applies `font.variation` coords when the font object is passed as its 5th argument; every weight rendered at the lightest master. Plan 01's smoke checks (XML validity, glyph count) could not catch this.
- **Fix:** Pass `{}, font` to `getPath` in both the forEachGlyph and CCMP-fallback paths; this also hvar-adjusts advance widths to the instanced weight.
- **Files modified:** scripts/brand/outline-wordmark.mjs
- **Commit:** ec2bd48b

**2. [Rule 1 - Bug] Double Y-flip produced per-glyph upside-down wordmarks**
- **Found during:** Task 1 — first hero render read (wordmark mirrored/rotated, glyphs vertically misaligned)
- **Issue:** `glyph.getPath` already emits SVG-oriented (y-down) coordinates; `toPathData({flipY: true})` (as recommended by Plan 01 research) flips each glyph a second time around its own bounding box. Latent in Plan 01 whose renders were never visually inspected.
- **Fix:** `toPathData({ decimalPlaces: 2, flipY: false })`; header comment corrected.
- **Files modified:** scripts/brand/outline-wordmark.mjs
- **Commit:** 5a02a270

### Design-judgment deviations (documented, not bugs)

- **A3 concept rework** (see Critique Summary) — plan's explicit fallback was insufficient; rework chosen over waving a weak candidate through. Filenames unchanged.
- **B2 geometry** — plan specified three vertical bars; the approved design is a serpentine switchback stroke after two bar-based geometries failed the plan's own critical test ("must read as a letter-like shape, iterate if pure decoration").
- **C1 mark placement** — plan placed the mark "centered in the interline space"; approved design sets it in line-1's right void after interline placement failed twice.
- **Gallery with-subtitle blocks** omit the plan's literal `<strong>sigra</strong>` HTML word: every round-3 candidate SVG already contains the full wordmark, so the duplicate word would render "sigra sigra ...". Subtitle text appears alone beside each lockup; all 7 blocks present (`margin-top: var(--sigra-space-2)` x7, "Phoenix auth that ships" x7).
- **Gallery CSS adaptation** — round-2's fixed 4rem-square lockup img sizing was adapted for wide typemarks (round-2 had only square marks); favicon chips pin `color-scheme: light` so scheme-adaptive favicon SVGs stay visible on the dark board in either OS theme.
- **Acceptance-criterion note:** B1 primary viewBox height is 1060 vs the A1 baseline 1000 (~6% raw). The mark extends 238 UPM (~24% em) below the wordmark baseline as required; the 15%-taller heuristic compares against a no-overflow wordmark box (~914 high), against which B1 is +16%.
- **Acceptance-criterion note:** A4's raw viewBox height (2520) exceeds A2's (1080) only because Inter is a 2048-UPM font; per-em A2 (1.08em) carries the required descender-overflow padding and is the tallest 1000-UPM A-candidate (A1 1.00em, A3 1.05em).

## Authentication Gates

None.

## Known Stubs

None. All 22 SVGs are finished artifacts; the gallery references only files that exist; renders and critique notes intentionally stay in /tmp per plan.

## Threat Flags

No new security-relevant surface: static SVG/HTML assets only, no network endpoints, no auth paths, no schema changes. Threat register dispositions (T-179-03/04/SC: all accept) hold — no font binaries or executable content committed, harness HTML stayed in /tmp, no new packages installed.

## Self-Check: PASSED
