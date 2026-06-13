---
phase: 181-ratified-logo-system-buildout
plan: "02"
subsystem: brandbook
tags: [brand, svg, social-card, d4-linked-rail, archive, usage-rules]
dependency_graph:
  requires: [181-01]
  provides: [social-card.svg, social-card-dark.svg, archive-v1/social-card.svg, archive-v1/README.md, brandbook/README.md usage rules]
  affects: [brandbook/logo-options/archive-v1 now complete (6 SVGs + README), brandbook/README.md logo system docs]
tech_stack:
  added: []
  patterns: [D4-Linked-Rail-SVG, SVG-social-card-composition, hardcoded-dark-fills]
key_files:
  created:
    - brandbook/social-card-dark.svg
    - brandbook/logo-options/archive-v1/social-card.svg
    - brandbook/logo-options/archive-v1/README.md
  modified:
    - brandbook/social-card.svg
    - brandbook/README.md
decisions:
  - "Preserved v1 tagline copy verbatim ('Auth you can keep patching after install.') — matches brand voice from PATTERNS.md analog and avoids copy drift"
  - "Dark card code block uses light bg (#f4f1eb) with dark text (#171614) — maintains readability on the dark card surface"
  - "Top bar in dark card uses #f4f1eb (light) to differentiate top edge on dark background"
  - "D4 mark in social cards uses unique IDs (sc-glyphs, sc-rail-block, scd-glyphs, scd-rail-block) to prevent id collision in HTML pages"
  - "The one .strong { fill: #c2410c } in social-card-dark.svg is intentional — it is a CSS class definition, not a mark fill"
metrics:
  duration: "~25 minutes"
  completed: "2026-06-13T03:15:00Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 181 Plan 02: Social Cards, Archive README, and Usage Docs Summary

v1 social-card.svg archived from the live working tree before overwrite; both D4 social cards (light + dark) written and render-verified at 600x315 thumbnail scale; archive-v1/README.md written with deprecation notice for all 6 v1 files; brandbook/README.md updated with clearspace rule, minimum-sizes table, 6 misuse examples, palette values, and Space Grotesk font provenance row.

## What Was Built

### Task 1: Archive v1 social-card.svg + write v2 social cards

**Archive (FIRST write in task — critical ordering constraint satisfied):**
- `brandbook/logo-options/archive-v1/social-card.svg` — verbatim copy of v1 Rail Accent social card read from live working tree before any canonical path overwrite

**brandbook/social-card.svg (v2, light surface):**
- OG standard 1200×630 viewBox, explicit width/height attributes
- D4 abstract rail glyph embedded in upper-left (scale 0.075, ~64px rendered height): sc-glyphs fill `#151515`, sc-rail-block fill `#c2410c` (ember-700)
- Same right-side panel composition from v1: large D4 mark at scale 0.24, right panel background #fff0e8 (.soft)
- Preserved v1 tagline copy: "Auth you can keep patching after install."
- Preserved v1 muted subtitle: "Library-owned security-sensitive behavior. Generated Phoenix code you can review."
- Code block: `mix sigra.install Accounts User users` in monospace on black rect
- No CDN links, no @import, no prefers-color-scheme, hardcoded fills throughout
- CSS classes identical to v1: .bg, .panel, .ink, .muted, .accent, .strong, .warm, .soft, .type, .mono

**brandbook/social-card-dark.svg (v2, dark surface — new file):**
- Mirror structure of light card
- .bg fill: `#171614` (dark charcoal); .panel fill: `#1e1c1a` with rgba(244,241,235,0.10) stroke; .soft fill: `#2a2520`
- .ink fill: `#f4f1eb` (warm white); .muted fill: `#a0998f`; .accent fill: `#fdba74` (ember-300)
- D4 mark glyphs: `#f4f1eb`; ember rail-block: `#fdba74` (ember-300 — correct for dark surface)
- Top bar: `#f4f1eb` (light bar on dark card)
- Code block: light bg `#f4f1eb`, dark text `#171614`
- Unique IDs: scd-glyphs, scd-rail-block (no id collision risk in HTML pages)

### Task 2: archive-v1/README.md + brandbook/README.md updates

**brandbook/logo-options/archive-v1/README.md (new file):**
- Deprecation header: "Do not use these files."
- Table listing all 6 archived v1 files: logo-primary, logo-primary-dark, logo-mark, logo-monochrome, favicon, social-card
- Each row shows v1 concept and canonical D4 superseding file

**brandbook/README.md (updated):**
- Logo System section updated: references D4 Linked Rail v2 assets and archive-v1/ location
- New "## Logo System Usage Rules" section inserted after "## Logo System":
  - Clearspace rule: 0.25× mark height, 0.15× typemark height
  - Minimum sizes table: 16px favicon, 24px UI accent, 32px topbar, 120px marketing
  - 6 misuse examples (incorrect surface, scaling below minimum, rectangular container, wrong ember hue, rotating/reflecting, live text wordmark)
  - Palette values table (light/dark/monochrome/favicon)
- Font Provenance table: added Space Grotesk v2.0.0 row for D4 production assets

## Render Gate Outcomes

Both cards verified at 600×315 thumbnail scale (GitHub social preview size) and 1200×630 full size.

| Asset | Scale | Scheme | Result | Notes |
|---|---|---|---|---|
| social-card.svg | 600×315 | light | PASS | D4 mark (ember block + L-shape stem/foot) readable, "Sigra" wordmark clear, tagline legible, code block present |
| social-card-dark.svg | 600×315 | dark | PASS | Dark charcoal background, warm white wordmark, amber ember-300 block, stem/foot in warm white — all elements distinguishable |
| social-card.svg | 1200×630 | light | PASS | Right panel D4 mark prominent; ember-700 block and ink stem/foot distinct; all text elements fully readable |
| social-card-dark.svg | 1200×630 | dark | PASS | Dark panel with soft dark inner box, amber ember block prominent above warm white stem+foot; code block high contrast |

**Render gate verdict: PASSED.** Both cards pass at 600×315 thumbnail scale.

## Archive State

`brandbook/logo-options/archive-v1/` contains all 6 v1 Rail Accent files + README:

| File | Status |
|------|--------|
| logo-primary.svg | Archived (Plan 01) |
| logo-primary-dark.svg | Archived (Plan 01) |
| logo-mark.svg | Archived (Plan 01) |
| logo-monochrome.svg | Archived (Plan 01) |
| favicon.svg | Archived (Plan 01) |
| social-card.svg | Archived (Plan 02 Task 1 — this plan) |
| README.md | Written (Plan 02 Task 2 — this plan) |

## Phase Gate Verification Results

All phase gate checks pass:

| Check | Result |
|-------|--------|
| All 8 production SVGs exist | PASS |
| All SVGs parse as valid XML | PASS |
| Font provenance in 6 typemark/mark files | PASS (6/6) |
| Dark variants have no ember-700 in mark fills | PASS (0 hits for logo-primary-dark.svg; 1 hit for social-card-dark.svg CSS class def only) |
| Monochrome uses no ember colors | PASS (0 c2410c, 0 fdba74) |
| Favicon and mark have prefers-color-scheme | PASS (2/2) |
| Archive: 6 SVGs + README | PASS |
| Usage rules in README (Misuse/clearspace/Minimum) | PASS (5 hits) |
| No font binaries committed | PASS (0) |
| No SVGs exceed 250KB | PASS |
| index.html referenced files all exist at v2 | PASS (favicon, logo-primary, logo-primary-dark, logo-mark) |

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written.

### Notes on False Positives in Automated Checks

1. **CDN/http check false positive:** The plan's check `grep -c 'prefers-color-scheme\|@import\|http' brandbook/social-card.svg | grep -q '^0$'` fires a false positive because `http` matches inside `xmlns="http://www.w3.org/2000/svg"`. The social cards have no CDN font links, @import, or prefers-color-scheme — only the mandatory SVG namespace URI. Not a real violation.

2. **Font binary `wc -l` whitespace:** `wc -l` on macOS outputs leading spaces (`       0`) which causes `grep -q '^0$'` to fail. Actual binary count is 0 — confirmed with trimmed comparison.

## Known Stubs

None. Both social cards contain final D4 geometry with production-quality fills and all text elements present.

## Threat Flags

None found. Static SVG files only. No network requests, no external references. The `xmlns="http://www.w3.org/2000/svg"` URI is a namespace identifier, not a network request.

Threat register checks:
- T-181-03 (Archive atomicity): MITIGATED — archive write completed as first write in Task 1 before canonical overwrite
- T-181-04 (Dark card ember-700 in mark fill): MITIGATED — grep confirms only CSS `.strong` class definition contains `#c2410c`, no mark rects
- T-181-05 (Font binaries): MITIGATED — 0 font binaries committed
- T-181-SC (Package installs): N/A — no packages installed

## Commits

| Hash | Message |
|---|---|
| `0445a98e` | feat(181-02): archive v1 social-card and write D4 v2 social cards (light + dark) |
| `2c906c84` | docs(181-02): write archive-v1/README.md deprecation note and add usage rules to brandbook/README.md |

## Self-Check: PASSED

- brandbook/logo-options/archive-v1/social-card.svg exists with v1 Rail Accent content
- brandbook/social-card.svg exists with D4 mark geometry (sc-glyphs, sc-rail-block)
- brandbook/social-card-dark.svg exists with dark fills and ember-300 accents
- brandbook/logo-options/archive-v1/README.md exists with "Do not use" deprecation notice
- brandbook/README.md has Misuse section, clearspace rule, minimum sizes table, Space Grotesk row
- All 8 production SVGs present at brandbook/
- No font binaries committed
- Commits 0445a98e and 2c906c84 confirmed in git log
