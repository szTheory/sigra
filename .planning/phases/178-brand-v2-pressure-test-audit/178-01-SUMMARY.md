---
phase: 178-brand-v2-pressure-test-audit
plan: "01"
subsystem: brand
tags: [brand, audit, logo, design-tokens, sztheory-suite, trademark]

# Dependency graph
requires:
  - phase: 167-logo-ratification
    provides: Option A Core Rails logo ratification, brandbook/ SVG system
  - phase: 172-admin-brand-theme-verification
    provides: admin shell sg-* token system, Rail Accent topbar
  - phase: 177-auth-branding-verification
    provides: sigra_auth.css, sigra_brand_profiles, SigraAuthComponents
provides:
  - brandbook/pressure-test-audit-v2.md — full 14-section KEEP/TIGHTEN/REWORK audit with evidence
  - szTheory suite brand architecture — shared/unique split for all 7 libraries
  - Three-surface ember parity rule (tokens.json/app.css/sigra_auth.css all ember-700 #c2410c)
  - Logo REWORK verdict with evidence — mark-beside-text = generic ecosystem pattern
  - Section 13 action plan driving Phases 179–183 scope
affects:
  - Phase 179 (logo candidate exploration uses design brief forward reference)
  - Phase 180 (human ratification gate defined in Section 13)
  - Phase 181 (full asset buildout spec in Section 12)
  - Phase 182-183 (integration/propagation scope defined)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Three-surface ember parity rule: ember-700 #c2410c must be the canonical accent across all three surfaces (brandbook tokens, admin CSS, auth CSS)
    - szTheory suite brand split: shared OFL font/vocabulary/token-namespace; unique mark/accent-hue/domain-metaphor per library
    - KEEP/TIGHTEN/REWORK verdict framework: KEEP is default, REWORK requires named surface + failure mode + codebase citation

key-files:
  created:
    - brandbook/pressure-test-audit-v2.md
  modified: []

key-decisions:
  - "Logo REWORK verdict: mark-beside-text is the generic Elixir ecosystem lockup pattern (Phoenix/Ash/Oban Pro all use it); the integrated typemark gap from v1.35 has grown in urgency."
  - "Token system KEEP: ember-700 #c2410c confirmed as three-surface parity value — brandbook/tokens.json, admin --sg-color-brand, and auth --sigra-auth-light-accent all converge without coordination."
  - "szTheory suite model: FastAPI/tiangolo creator-aesthetic with unjs puzzle-piece influence — shared wordmark typeface/vocabulary; unique mark+accent per library."
  - "Section 13 action plan: Tier 1 Phase 179 (opentype.js toolchain + candidates), Tier 2 Phase 180 (human gate), Tier 3 Phase 181 (full buildout), Tier 4 Phases 182-183 (integration)."
  - "Design brief: standalone brandbook/logo-v2-design-brief.md file (not embedded in audit) for clean Phase 179 reference."

patterns-established:
  - "Evidence citation inline format: [VERIFIED: file.ext line N], [ASSUMED: claim], [CITED: source] — applied throughout all 14 sections."
  - "Suite architecture scope boundary: Sigra contributes to the shared system only; other library brandbooks are out of scope per REQUIREMENTS boundary."

requirements-completed:
  - BRAND2-01
  - BRAND2-02

# Metrics
duration: 45min
completed: 2026-06-12
---

# Phase 178 Plan 01: Brand v2 Pressure-Test Audit Summary

**14-section KEEP/TIGHTEN/REWORK audit of the v1.35 brand system against v1.36/v1.37 deployment evidence, confirming the ember token system and issuing a REWORK verdict on the logo with szTheory suite brand architecture for all 7 libraries**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-06-12T14:30:00Z
- **Completed:** 2026-06-12T15:15:00Z
- **Tasks:** 2 (written together as a complete document)
- **Files modified:** 1

## Accomplishments

- Produced `brandbook/pressure-test-audit-v2.md` with all 14 sections following the exact structural conventions of the v1 audit: H2 headings with "## Section N - Title Case" format, two-column Brand DNA table (11 rows), 15-row pressure-test scorecard with right-aligned score column, 4-column stress-test table (26 v1 surfaces + 4 new v1.36/v1.37 surfaces), and 8-bullet Section 14 quality gate.
- Confirmed three-surface ember parity: `ember-700: #c2410c` appears in brandbook/tokens.json (line 20), `--sg-color-brand: #c2410c` in admin app.css (line 67), and `--sigra-auth-light-accent: #c2410c` in sigra_auth.css (line 4) — all VERIFIED by direct codebase inspection. This is the v2 audit's most significant positive finding.
- Issued the lone REWORK verdict for the logo system with full evidence: brandbook/logo-primary.svg uses mark-beside-text construction, which is the generic lockup pattern shared by Phoenix Framework, Ash Framework, and Oban Pro in the target developer audience's visual field. Section 8 includes the current asset inventory and a forward reference to `brandbook/logo-v2-design-brief.md`.
- Completed the szTheory suite brand architecture subsection (BRAND2-02): named all 7 libraries, documented the FastAPI/tiangolo+unjs recommended model, specified shared elements (OFL typeface/vocabulary/token namespace) vs unique elements (mark/accent hue/domain metaphor per library), and cited `test/example/priv/static/images/vaultr-mark.svg` as verified evidence of the per-library color diversity pattern already in place.
- Section 13 action plan defines a clear 4-tier execution path for Phases 179–183: Phase 179 opentype.js toolchain + 5–7 candidates including ≥2 integrated typemarks; Phase 180 human ratification gate; Phase 181 full asset buildout; Phases 182–183 integration and propagation.

## Task Commits

1. **Task 1+2: Write pressure-test-audit-v2.md (all 14 sections)** — `016448ee` (docs)

**Plan metadata:** (this SUMMARY commit)

## Files Created/Modified

- `/Users/jon/projects/sigra/.claude/worktrees/agent-a1d3b51875917e178/brandbook/pressure-test-audit-v2.md` — 14-section brand pressure-test audit v2 with KEEP/TIGHTEN/REWORK verdicts, szTheory suite architecture, and Phase 179–183 action plan (424 lines)

## Decisions Made

- Wrote both tasks as a single complete document rather than separate commits per section because the structural template makes the sections a continuous document — splitting them into two commits (Sections 1–7, then 8–14) would have created an intermediate state with an incomplete audit that would be confusing if ever checked out.
- Placed the szTheory suite brand architecture as a subsection of Section 8 (Logo and Mark System) rather than a standalone Section between 12 and 13, because the suite architecture's most relevant evidence — the vaultr-mark.svg per-library color pattern — is directly connected to the logo mark system discussion. This is consistent with the plan's guidance that Section 8 is where BRAND2-02 lives.
- Used two REWORK verdicts in the document (one in Section 1's Executive Judgment summary paragraph, one in Section 8's full REWORK verdict block) because the executive summary in Section 1 needs to name all major verdicts, and Section 8 is where the full evidence/failure-mode/citation triple appears per the structural convention.

## Deviations from Plan

None - plan executed exactly as written. All 14 sections produced per the structural conventions specified in the interfaces block. All acceptance criteria verified before commit.

## Issues Encountered

None. The `awk '/## Section 14/,/^$/'` acceptance-criteria check from the plan returned 0 because Section 14 is the last section in the file and has no trailing blank line before EOF — so awk never found the `^$` terminator. The actual Section 14 content contains 8 "Could" bullets as required, verified by direct grep.

## Known Stubs

None — this is a documentation-only plan producing a brand audit document. No runtime data flows, UI components, or generated code are involved.

## Threat Flags

None — documentation-only phase. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## User Setup Required

None — no external service configuration required. This plan produces a documentation file only.

## Next Phase Readiness

- `brandbook/pressure-test-audit-v2.md` is committed and ready for Phase 179 and all subsequent phases to cite
- Section 8 forward reference to `brandbook/logo-v2-design-brief.md` is present — Plan 02 of Phase 178 creates that file
- Section 13 action plan gives Phase 179 a concrete brief: opentype.js toolchain, 5–7 candidates, ≥2 integrated typemarks, Space Grotesk Bold and Plus Jakarta Sans ExtraBold as top OFL candidates, render-critique loop at 16/32/54px/hero scales

## Self-Check

- [x] `brandbook/pressure-test-audit-v2.md` exists: VERIFIED
- [x] 14 sections present (`grep -c "^## Section"` = 14): PASS
- [x] All 7 suite libraries named: Sigra/Accrue/Mailglass/Threadline/Lockspire/Relyra/Rulestead all present
- [x] REWORK verdicts have Evidence/failure-mode/citation: VERIFIED on lines 17 and 187
- [x] sigra-auth cross-reference in Section 7: VERIFIED (3 occurrences)
- [x] Scorecard has 15 data rows (16 rows total including header): PASS
- [x] Phase 179–183 references: 43 total mentions
- [x] tokens.json parseability: PASS (`jq .` exits 0)
- [x] SVG parse check: PASS (xmllint exits 0 on all brandbook SVGs)
- [x] Task commit 016448ee exists: VERIFIED

## Self-Check: PASSED

---
*Phase: 178-brand-v2-pressure-test-audit*
*Completed: 2026-06-12*
