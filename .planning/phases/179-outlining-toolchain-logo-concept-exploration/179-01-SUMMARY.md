---
phase: "179"
plan: "01"
subsystem: brand-toolchain
tags: [brand, toolchain, opentype, playwright, svg, OFL-fonts]
dependency_graph:
  requires: []
  provides: [scripts/brand/outline-wordmark.mjs, scripts/brand/critique-render.mjs, scripts/brand/package.json]
  affects: [brandbook/README.md, .gitignore]
tech_stack:
  added: [opentype.js 2.0.0]
  patterns: [ESM createRequire for CJS interop, opentype.parse(buffer) for Node.js CLI, Playwright standalone file:// screenshots]
key_files:
  created:
    - scripts/brand/outline-wordmark.mjs
    - scripts/brand/critique-render.mjs
    - scripts/brand/package.json
    - scripts/brand/package-lock.json
  modified:
    - .gitignore
    - brandbook/README.md
decisions:
  - opentype.parse(readFileSync(path).buffer) used over deprecated loadSync for Node.js ESM scripts
  - createRequire fallback to CJS for both opentype.js and playwright-core to avoid ESM/CJS boundary issues
  - forEachGlyph with try/catch fallback to charToGlyphIndex for fonts with unsupported CCMP lookup tables
  - playwright-core reused from test/example/priv/playwright/ to avoid duplicate install
  - index-based path IDs (g-0 through g-4) used over glyph-name IDs per PATTERNS.md
metrics:
  duration: "~10 minutes"
  completed: "2026-06-12"
  tasks_completed: 3
  files_created: 4
  files_modified: 2
---

# Phase 179 Plan 01: Outlining Toolchain + Playwright Render Harness Summary

Committed reproducible opentype.js glyph-outlining toolchain (`outline-wordmark.mjs`) and Playwright headless render harness (`critique-render.mjs`) for BRAND2-04, with OFL font provenance documented in `brandbook/README.md`.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Toolchain scaffolding — gitignore, package.json, font downloads | 632633e2 | .gitignore, scripts/brand/package.json, package-lock.json |
| 2 | outline-wordmark.mjs — per-glyph SVG path generator | d267b99c | scripts/brand/outline-wordmark.mjs |
| 3 | critique-render.mjs + brandbook/README.md provenance update | beebd16a | scripts/brand/critique-render.mjs, brandbook/README.md |

## Verification Results

All 7 plan verification checks passed:

1. `node outline-wordmark.mjs SpaceGrotesk[wght].ttf 700 /tmp/sigra-final-smoke.svg` → exit 0
2. `python3 xml.etree.ElementTree` → `SVG: valid`
3. `grep -c 'id="g-' ...` → `5` (one path per glyph of "sigra")
4. `grep -c 'Font:' ...` → `1` (provenance desc present)
5. `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2'` → empty (no font binaries in git)
6. `grep -c 'OFL\|outlined\|opentype' brandbook/README.md` → `7`
7. `ls /tmp/sigra-renders/smoke/*.png | wc -l` → `8`

All 5 OFL fonts outline successfully. 8 critique screenshots produced (4 scales × 2 color schemes).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] opentype.loadSync returns undefined in Node.js ESM context**
- **Found during:** Task 2 — first smoke run
- **Issue:** `opentype.loadSync(fontPath)` returned `undefined` when called via `createRequire` in an `.mjs` file. The function is deprecated and does not work with Node.js file paths in v2.0; it requires a browser-style `XMLHttpRequest` environment.
- **Fix:** Replaced `loadSync(path)` with `opentype.parse(readFileSync(path).buffer)` — the recommended approach per the deprecation warning shown at runtime.
- **Files modified:** `scripts/brand/outline-wordmark.mjs`
- **Commit:** d267b99c

**2. [Rule 1 - Bug] Inter variable font throws unsupported CCMP lookup table error**
- **Found during:** Task 2 — smoke test of all 5 fonts
- **Issue:** `font.forEachGlyph('sigra', ...)` throws `Error: substitutionType : 62 lookupType: 6 - substFormat: 2 is not yet supported` for `Inter-VariableFont.ttf`. This is a known opentype.js 2.0.0 limitation with certain advanced GSUB lookup table formats used by Inter.
- **Fix:** Added try/catch around the `forEachGlyph` call with a fallback path using `font.charToGlyphIndex()` + `font.glyphs.get()` + manual kern value lookup. The fallback correctly produces 5 path elements for "sigra" — no ligatures apply to this 5-letter string, so the GSUB bypass is safe.
- **Files modified:** `scripts/brand/outline-wordmark.mjs`
- **Commit:** d267b99c

## Known Stubs

None. All scripts are fully functional for their stated purpose. Font binaries are not committed (gitignored); scripts produce outputs on demand.

## Threat Flags

No new security-relevant surface introduced. This plan adds offline build tooling only (no network endpoints, no auth paths, no schema changes, no user-facing runtime behavior). Threat mitigations from the plan's threat_model were applied:

- T-179-01: Fonts downloaded from 5 verified OFL source repos only; gitignored; never reached git.
- T-179-02: opentype.js pinned to `^2.0.0`; no postinstall scripts; npm audit clean.
- T-179-SC: opentype.js manually assessed as legitimate (13-year-old, 1.34M downloads/week, MIT, official opentypejs org).

## Self-Check: PASSED
