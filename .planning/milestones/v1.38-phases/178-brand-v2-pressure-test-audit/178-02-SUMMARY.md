---
phase: 178-brand-v2-pressure-test-audit
plan: "02"
subsystem: brand
tags: [brand, logo, design-brief, typography, OFL, integrated-typemark]

# Dependency graph
requires:
  - phase: 178-01
    provides: pressure-test-audit-v2.md Section 8 REWORK verdict — brief's provenance
provides:
  - brandbook/logo-v2-design-brief.md — standalone design brief for Phase 179 logo exploration
affects:
  - Phase 179 (logo candidate exploration — reads this brief as primary input)
  - Phase 180 (human ratification gate — cites brief as constraint source)
  - Phase 181 (full asset buildout — confirms all brief constraints are met)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Design brief as standalone file: Phase 179 reads one document and proceeds; no other planning artifacts required as pre-read
    - Hue boundary constraint: logo candidates constrained to hue 15-40 degree warm amber range to prevent palette drift
    - Direction A/B/C candidate taxonomy: named directions replace open exploration brief

key-files:
  created:
    - brandbook/logo-v2-design-brief.md
  modified: []

key-decisions:
  - "Standalone brief file (not audit section): keeps Phase 179 execution context clean — one document, not the full 14-section audit"
  - "Six OFL candidates tabulated with download URLs so Phase 179 toolchain setup requires no additional research"
  - "Direction A (integrated typemark) named as the primary direction the brief optimizes for, with Direction B as fallback"
  - "Hue 15-40 boundary made explicit in both the hard constraint (#6) and the scope decisions table and rubric — three places prevents misreading"

patterns-established:
  - "Render-critique rubric with named pixel scales (16px/32px/54px/hero/social card) is the canonical acceptance gate for Phase 179"
  - "Tattoo test (50% opacity grayscale at 54px) as wordmark coherence check"

requirements-completed:
  - BRAND2-03

# Metrics
duration: 20min
completed: 2026-06-12
---

# Phase 178 Plan 02: Logo v2 Design Brief Summary

**Standalone design brief encoding 7 hard constraints, OFL font shortlist with download URLs, sigra letterform integration anatomy, render-critique rubric, and Direction A/B candidate guidance for Phase 179 logo exploration**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-06-12T15:15:00Z
- **Completed:** 2026-06-12T15:35:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Wrote `brandbook/logo-v2-design-brief.md` (151 lines) as a standalone document for Phase 179. The brief encodes all 7 hard constraints from CONTEXT.md verbatim with expansion sentences, the three ratified scope decisions, an ember token reference table with the `#c2410c` anchor and the explicit hue 15–40 degree boundary, and a back-reference to `pressure-test-audit-v2.md` Section 8 REWORK verdict as provenance.
- Tabulated 6 OFL typeface candidates with version info, download URLs, key characteristics, and integration potential ratings. The table provides enough context for Phase 179 to begin toolchain setup without additional research: Space Grotesk and Plus Jakarta Sans ExtraBold are highlighted as highest-potential alternatives; Bricolage Grotesque is deprioritized with rationale.
- Documented 4 "sigra" letterform integration points (g descender, i tittle, s strokes, r shoulder) with specific action descriptions, plus 5 integration pitfalls to avoid (forced ligature, gimmick letter, stroke contrast damage, kerning distortion, scale fragility) and 3 optical adjustment requirements.
- Created a 6-row render-critique rubric with testable pass conditions at named pixel scales (16px, 32px, 54px, hero, social card) including the "tattoo test" (50% opacity grayscale at 54px). Phase 179 executor can score candidates against this rubric without judgment calls.
- Named Direction A (integrated typemark, primary), Direction B (refined combination lockup), and Direction C (optional wildcard) plus an explicit "do not produce" list. Phase 179 has constrained creative space rather than open-ended exploration.

## Task Commits

1. **Task 1: Write brandbook/logo-v2-design-brief.md** — `86763a6e` (docs)

**Plan metadata:** (this SUMMARY commit)

## Files Created/Modified

- `brandbook/logo-v2-design-brief.md` — 151-line standalone design brief for Phase 179 (7 hard constraints, ratified scope, OFL candidates table, letterform anatomy, render-critique rubric, direction guidance)

## Decisions Made

- Wrote the brief as a standalone `brandbook/logo-v2-design-brief.md` rather than embedding in the audit, because the plan and Wave 1 SUMMARY both confirmed this format keeps Phase 179 execution context clean.
- Included the ember token table (ember-050/300/700/800 with raw hex values) inline in the brief so Phase 179 has the exact palette values without needing to read `brandbook/tokens.json` separately.
- Named the hue boundary (15–40 degrees) in three places — the constraint text, the scope decisions table, and the render-critique rubric — to prevent any ambiguity about what "ember-anchored and tunable" means in practice.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria verified before commit.

## Issues Encountered

None.

## Known Stubs

None — this is a documentation-only plan producing a design brief. No runtime data flows, UI components, or generated code are involved.

## Threat Flags

None — documentation-only phase. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## User Setup Required

None — no external service configuration required. This plan produces a documentation file only.

## Next Phase Readiness

- `brandbook/logo-v2-design-brief.md` is committed and ready for Phase 179 to read as its primary input
- The brief's Direction A/B guidance and render-critique rubric give Phase 179 constrained creative space
- The OFL candidates table with download URLs means Phase 179 toolchain setup requires no additional font research
- The "do not produce" list prevents scope drift at Phase 180 ratification

## Self-Check

- [x] `brandbook/logo-v2-design-brief.md` exists: VERIFIED (86763a6e)
- [x] All 7 keyword checks pass (rectangular/logotype/subtitle/typemark/ember/OFL/boundary): PASS
- [x] OFL candidates: Space Grotesk, Syne, Geist, Jakarta all present: PASS (4 of 4 grep matches)
- [x] Letterform anatomy: g descender and i tittle present: PASS
- [x] Hue boundary: "15.*40" present in 3 locations: PASS
- [x] Back-reference to pressure-test-audit-v2: present in header and sources: PASS
- [x] Forward reference to round-3: present in deliverables and sources: PASS
- [x] Line count ≥ 80: 151 lines: PASS
- [x] 7 numbered constraint items: 11 total numbered items (constraints + anatomy): PASS

## Self-Check: PASSED

---
*Phase: 178-brand-v2-pressure-test-audit*
*Completed: 2026-06-12*
