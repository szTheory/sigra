---
phase: 181-ratified-logo-system-buildout
plan: "01"
subsystem: brandbook
tags: [brand, svg, logo, d4-linked-rail, favicon, archive]
dependency_graph:
  requires: []
  provides: [logo-primary.svg, logo-primary-dark.svg, logo-primary-subtitle.svg, logo-mark.svg, logo-monochrome.svg, favicon.svg, archive-v1]
  affects: [brandbook/index.html img src references now resolve to v2 D4 geometry]
tech_stack:
  added: []
  patterns: [D4-Linked-Rail-SVG, prefers-color-scheme-in-SVG, SVG-accessibility-shell]
key_files:
  created:
    - brandbook/logo-primary-subtitle.svg
    - brandbook/logo-options/archive-v1/logo-primary.svg
    - brandbook/logo-options/archive-v1/logo-primary-dark.svg
    - brandbook/logo-options/archive-v1/logo-mark.svg
    - brandbook/logo-options/archive-v1/logo-monochrome.svg
    - brandbook/logo-options/archive-v1/favicon.svg
  modified:
    - brandbook/logo-primary.svg
    - brandbook/logo-primary-dark.svg
    - brandbook/logo-mark.svg
    - brandbook/logo-monochrome.svg
    - brandbook/favicon.svg
decisions:
  - Kept prefers-color-scheme in logo-mark.svg (same as favicon) for better DX — mark auto-themes without needing a separate dark variant file
  - Added Space Grotesk font provenance to logo-mark.svg and favicon.svg desc elements (not present in initial write; fixed before commit)
  - Palette unchanged from ratified values: ember-700 #c2410c and ember-300 #fdba74 (no legibility issues at 16px warranted a change)
metrics:
  duration: "~20 minutes"
  completed: "2026-06-13T02:43:01Z"
  tasks_completed: 3
  files_changed: 11
---

# Phase 181 Plan 01: Archive v1 + Write D4 Linked Rail Production SVGs Summary

D4 Linked Rail typemark geometry from round-4 sources shipped to all six canonical brandbook SVG paths with full accessibility shells, Space Grotesk font provenance, and render-verified at 16px/54px/hero scales; v1 Rail Accent assets archived from the live working tree before any overwrite.

## What Was Built

### Task 1: Archive v1 Rail Accent assets

Five v1 files read from the live working tree and written verbatim to `brandbook/logo-options/archive-v1/` BEFORE any canonical path was overwritten:

| Archived File | v1 Concept |
|---|---|
| `archive-v1/logo-primary.svg` | Rail Accent staircase mark + Inter Display Black wordmark, viewBox 20 12 188 54 |
| `archive-v1/logo-primary-dark.svg` | Same with light wordmark fill #f4f1eb |
| `archive-v1/logo-mark.svg` | 3-bar Rail Accent staircase mark, viewBox 0 0 64 64 |
| `archive-v1/logo-monochrome.svg` | Rail Accent mark with opacity=0.72 secondary paths |
| `archive-v1/favicon.svg` | 3-bar Rail Accent mark identical to logo-mark |

Archive integrity confirmed: all 5 files parse as valid XML; canonical paths still held v1 content at end of Task 1.

### Task 2: Three D4 Typemark SVGs

**logo-primary.svg** — D4 Linked Rail typemark, light surface:
- viewBox: `0 220 2410 1026`
- Glyph fill: `#151515`, ember rect fill: `#c2410c` (ember-700)
- 5 path elements (g-0 through g-4) from round-4 source, unmodified
- `rail-tittle` rect at x=557 y=246 w=200 h=200

**logo-primary-dark.svg** — D4 Linked Rail typemark, dark surface:
- Identical geometry to light variant
- Glyph fill: `#f4f1eb` (warm white), ember rect fill: `#fdba74` (ember-300)
- Zero hits for `#c2410c` confirmed

**logo-primary-subtitle.svg** — D4 typemark + tagline:
- Extended viewBox: `0 220 2410 1380` (354 units added below for subtitle)
- Identical wordmark geometry to logo-primary
- Subtitle `<text>` element: "Phoenix auth that ships" at x=60 y=1320, font-size=200, fill=#686868, system font stack
- Text is NOT outlined (correct — subtitle uses live SVG text with system font fallback)

### Task 3: Three D4 Mark/Monochrome/Favicon SVGs

**logo-mark.svg** — D4 abstract rail glyph, auto light/dark:
- viewBox: `-70 -60 1040 1040` (square, padding preserved exactly)
- prefers-color-scheme media query kept: auto-themes for HTML img use
- Geometry: stem rect (x=540 y=360 w=180 h=580) + foot rect (x=180 y=760 w=540 h=180) + rail-block rect (x=400 y=-20 w=320 h=320)

**logo-monochrome.svg** — D4 typemark, single ink:
- Same 5 glyph paths as logo-primary
- Glyph fill: `#151515`, ember rect fill: `#151515` (collapses to solid ink)
- Zero hits for `#c2410c` and `#fdba74` confirmed
- No prefers-color-scheme (correct — single-ink file for restricted-color contexts)

**favicon.svg** — D4 abstract rail glyph, browser favicon:
- `<title>Sigra</title>` (production value)
- viewBox: `-70 -60 1040 1040` (identical to source — square, padding intact)
- prefers-color-scheme media query preserved verbatim

## Render Gate Outcomes

All renders executed via `node scripts/brand/critique-render.mjs` using `file://` URLs. PNGs read and self-critiqued.

| Asset | Scale | Color Scheme | Result | Notes |
|---|---|---|---|---|
| favicon.svg | 16px kill test | light | PASS | Ember block and ink stem+foot visually two distinct elements at 16px |
| favicon.svg | 16px kill test | dark | PASS | Ember block switched to amber (#fdba74) via prefers-color-scheme media query |
| favicon.svg | 32px | light | PASS | Two elements clearly readable |
| logo-mark.svg | 32px | light | PASS | Mark elements readable |
| logo-mark.svg | hero (128px) | light | PASS | Ember-700 block prominently distinct above ink stem+foot |
| logo-mark.svg | hero (128px) | dark | PASS | Ember-300 block amber; glyphs warm white |
| logo-primary.svg | 54px topbar | light | PASS | "sigra" fully legible, no clipping, ember block distinct above i |
| logo-primary.svg | hero | light | PASS | Letterforms well-formed, ember block crisp brick-red |
| logo-primary-dark.svg | 54px topbar | dark | PASS | Warm white wordmark + amber ember on dark surface |
| logo-primary-dark.svg | hero | dark | PASS | Warm white letterforms, amber ember-300 block |
| logo-monochrome.svg | 54px topbar | light | PASS | "sigra" legible in solid ink; rail block above i reads as spatially distinct from i stem due to position |

**16px favicon kill test verdict: PASSED.** The ember block and ink stem+foot are two distinct visual elements at 16px.

## Palette Decision

No palette change applied. Ratified values shipped unchanged:
- Light surface: glyph `#151515`, ember `#c2410c`
- Dark surface: glyph `#f4f1eb`, ember `#fdba74`

16px kill test showed both elements distinctly visible on the ratified ember-700. No micro-tuning warranted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Space Grotesk provenance absent from logo-mark.svg and favicon.svg initial writes**
- **Found during:** Task 3 automated check (`grep -l 'Space Grotesk'` returned 4, not 6)
- **Issue:** Initial `<desc>` for logo-mark.svg and favicon.svg did not include the "Space Grotesk" font provenance sentence, violating the plan's must_have that all 6 production files include it
- **Fix:** Appended "Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0." to both descs before the Task 3 commit
- **Files modified:** `brandbook/logo-mark.svg`, `brandbook/favicon.svg`
- **Commit:** `8e52d206` (included in the Task 3 commit)

## Known Stubs

None. All 6 production files contain final D4 geometry from the ratified round-4 source. No placeholder values, hardcoded empty content, or deferred wiring.

## Threat Flags

None found. All files are static SVGs with no network requests, no CDN font imports, no inline scripts, and no external references. The prefers-color-scheme media query in favicon.svg and logo-mark.svg is a CSS-only OS-level signal — not a network request.

Threat register check (T-181-02): `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2'` returns 0. No font binaries committed.

## Commits

| Hash | Message |
|---|---|
| `0e7e4c93` | chore(181-01): archive v1 Rail Accent logo assets from live working tree |
| `ee295536` | feat(181-01): write D4 Linked Rail typemark SVGs (primary, dark, subtitle) |
| `8e52d206` | feat(181-01): write D4 Linked Rail mark, monochrome, and favicon SVGs |

## Self-Check: PASSED

- All 6 canonical files exist at `brandbook/{logo-primary,logo-primary-dark,logo-primary-subtitle,logo-mark,logo-monochrome,favicon}.svg`
- 5 v1 files at `brandbook/logo-options/archive-v1/`
- xmllint passes on all files
- Space Grotesk provenance in all 6 production files
- No #c2410c in logo-primary-dark.svg (0 hits)
- No color fills in logo-monochrome.svg (0 hits for both #c2410c and #fdba74)
- prefers-color-scheme in favicon.svg and logo-mark.svg
- 0 font binaries committed
- 0 SVGs exceed 250KB
- Commits 0e7e4c93, ee295536, 8e52d206 all confirmed in git log
