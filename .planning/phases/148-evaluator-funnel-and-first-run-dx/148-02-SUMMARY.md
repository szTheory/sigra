---
phase: 148-evaluator-funnel-and-first-run-dx
plan: 02
subsystem: docs
tags: [evaluator-funnel, demo-showcase, first-run-dx, hexdocs]
requires:
  - phase: 148-evaluator-funnel-and-first-run-dx
    provides: canonical phase scope and persona/screenshot constraints
provides:
  - Canonical evaluator-first demo walkthrough with explicit run path and proof boundaries
  - Runnable example README aligned to the same persona truth and first live stop
affects: [README routing, evaluator onboarding, first-run verification guidance]
tech-stack:
  added: []
  patterns: [source-backed persona mapping, explicit proof-boundary language]
key-files:
  created: [.planning/phases/148-evaluator-funnel-and-first-run-dx/148-02-SUMMARY.md]
  modified: [guides/introduction/demo-showcase.md, test/example/README.md]
key-decisions:
  - "Kept `guides/introduction/demo-showcase.md` as canonical evaluator path and made `test/example/README.md` a runnable companion."
  - "Made proof language explicit that screenshots/demo are inspection aids, not production certification/compliance evidence."
patterns-established:
  - "Evaluator-first docs must share exact run commands and first live stop across surfaces."
requirements-completed: [ADOPT-01, ADOPT-02, ADOPT-03]
duration: 16min
completed: 2026-05-31
---

# Phase 148 Plan 02: Evaluator Funnel And First-Run DX Summary

**Canonical evaluator demo path now uses one exact runnable flow (`cd test/example`, `mix setup && mix phx.server`) with `/demo/credentials` as first stop, six-persona source-backed mapping, screenshot grid, and explicit non-certification proof boundaries.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-05-31T21:00:00Z
- **Completed:** 2026-05-31T21:16:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Rebuilt `demo-showcase.md` around the explicit `Run Demo Showcase` CTA and first live-stop flow.
- Added complete six-persona evaluator map with required D-04 concepts and OAuth caveat separation.
- Aligned `test/example/README.md` to the same run path and caveats while preserving seeded behavior truth.

## Task Commits

1. **Task 1: Refactor the demo showcase guide into the explicit evaluator-first path** - `166a3e98` (docs)
2. **Task 2: Align the example-app README to the same source-backed evaluator story** - `e1d29eaf` (docs)

## Files Created/Modified

- `guides/introduction/demo-showcase.md` - Canonical evaluator-first walkthrough, persona map, screenshot grid, and limitation language.
- `test/example/README.md` - Runnable local companion aligned to canonical guide, first stop, and persona caveats.
- `.planning/phases/148-evaluator-funnel-and-first-run-dx/148-02-SUMMARY.md` - Execution record and verification outcomes.

## Decisions Made

- Keep guide and local README intentionally distinct in purpose: canonical narrative vs runnable companion.
- Preserve and foreground rough-edge caveats (Dave locked/unconfirmed, Frank scheduled deletion, Carol live OAuth credential requirement) to prevent overclaiming.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Concurrent repository activity existed on unrelated files (`.planning/STATE.md`, `mix.lock`, `.planning/milestones/v1.32-MILESTONE-AUDIT.md`). Left untouched per scope rules.

## User Setup Required

None - no external service configuration required for this plan's docs changes.

## Next Phase Readiness

- Plan 148-02 deliverables are complete and aligned to D-03 through D-06 plus demo-guide half of D-07.
- Ready for downstream verification/doc-routing tasks in remaining Phase 148 plans.

## Verification Results

- `rg -n "Run Demo Showcase|cd test/example|mix setup && mix phx.server|/demo/credentials|admin@demo.sigra.dev|alice@demo.sigra.dev|bob@demo.sigra.dev|carol@demo.sigra.dev|dave@demo.sigra.dev|frank@demo.sigra.dev|demo-credentials-demo-showcase-chromium.png|admin-user-list-demo-showcase-chromium.png|admin-user-detail-demo-showcase-chromium.png|audit-explorer-demo-showcase-chromium.png|production certification|compliance evidence|mix sigra.doctor" guides/introduction/demo-showcase.md` → PASS
- `rg -n "mix setup && mix phx.server|http://localhost:4000/demo/credentials|admin@demo.sigra.dev|alice@demo.sigra.dev|bob@demo.sigra.dev|carol@demo.sigra.dev|dave@demo.sigra.dev|frank@demo.sigra.dev|demo-showcase.html|locked and unconfirmed|scheduled deletion|GitHub OAuth" test/example/README.md` → PASS
- `mix docs --warnings-as-errors` → PASS
- `rg -n "demo-showcase.html|/demo/credentials|scheduled deletion|GitHub OAuth|production certification|compliance evidence" guides/introduction/demo-showcase.md test/example/README.md` → PASS

## Self-Check: PASSED

- Found: `guides/introduction/demo-showcase.md`
- Found: `test/example/README.md`
- Found: `.planning/phases/148-evaluator-funnel-and-first-run-dx/148-02-SUMMARY.md`
- Found commit: `166a3e98`
- Found commit: `e1d29eaf`
