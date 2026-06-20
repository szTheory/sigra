---
phase: 197-playwright-lanes-design-gallery-re-gate
plan: "05"
subsystem: ci
tags: [playwright, ci, visual-regression, re-gate, seed-006, github-actions, font-determinism]
dependency_graph:
  requires:
    - phase: 197-03
      provides: deterministic render (self-hosted woff2 + fonts.ready guard)
    - phase: 197-04
      provides: CI-native baselines recaptured (admin_design_recapture job)
  provides:
    - Hard-gating design gallery step (D-10): continue-on-error removed
    - Corrected D-07 comment block replacing false "webfont does not load" premise
    - SEED-006 root-cause correction recorded (operator-truth, D-07)
  affects:
    - PW-03 complete: all three ROADMAP success criteria met (font loads, gallery re-gated, MG-5/6 disposed)
tech_stack:
  added: []
  patterns:
    - "D-10 re-gate: remove continue-on-error; keep id + if: !cancelled(); aggregator is load-bearing"
    - "Operator-truth correction: add explicit dated section to seed; preserve original text; mark addressed/folded"
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - .planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md
decisions:
  - "D-10 re-gate: continue-on-error removed from the 'Run design gallery boards' step; gallery now hard-gates via the Plan 02 aggregator on any visual regression"
  - "D-07 operator-truth: the original 'webfont does not load in CI' premise was factually wrong (no @font-face, no woff2, no Google Fonts link ever served); real cause was OS system-ui font-metric delta between macOS capture box and ubuntu CI runner"
  - "SEED-006 addressed/folded: root-cause correction appended as an explicit dated section; original (wrong) premise preserved as corrected-not-deleted"
  - "No pixel tolerance widened: delta root-caused (self-hosted woff2 + CI-native baselines), not papered over"
  - "Gallery stays inline in example_playwright_smoke (not relocated to nightly per D-10 mandate)"
metrics:
  duration: "~2 minutes"
  completed: "2026-06-20"
  tasks_completed: 2
  files_modified: 2
status: complete
requirements: [PW-03]
---

# Phase 197 Plan 05: PW-03 Design Gallery Re-gate Summary

**continue-on-error removed from the design gallery step (D-10); stale false-premise comment rewritten with corrected D-07 root-cause; SEED-006 marked addressed/folded with explicit root-cause-correction section**

## Performance

- **Duration:** ~2 minutes
- **Started:** 2026-06-20T19:25:28Z
- **Completed:** 2026-06-20T19:28:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- **Task 1 (D-10 re-gate):** Removed `continue-on-error: true` from the "Run design gallery boards" step in `.github/workflows/ci.yml`. The step retains its `id: design_gallery` + `if: ${{ !cancelled() }}` guard; the Plan 02 aggregator reads `steps.design_gallery.outcome`, so a gallery failure now hard-blocks the `example_playwright_smoke` job. Step stays inline in `example_playwright_smoke` (not nightly).

- **Stale comment rewritten:** The ci.yml comment block at the step (previously encoding the false "the brand webfont does not load in this dev-mode boot" premise from SEED-006's original filing) was replaced with an accurate D-07 correction: no `@font-face`, no `*.woff2`, no Google Fonts link was ever served; the ~20–53px height delta was an OS `system-ui` font-metric difference between the macOS capture box and the ubuntu CI runner. The new comment also summarizes the Plans 03–04 remediation (self-hosted woff2 + `document.fonts.ready` guard + CI-native recapture).

- **Task 2 (D-07 operator-truth):** Appended an explicit "Root-cause correction (Phase 197, D-07)" section to `SEED-006-admin-design-gallery-ci-baseline-recapture.md`. The section:
  - States the original premise was factually wrong and explains why (verified: no `@font-face`, no woff2, no Google Fonts link at time of filing)
  - Identifies the real cause: host-OS `system-ui` font-metric delta
  - Documents the Phase 197 remediation (Plans 03–05)
  - Records fix options 1–3 disposition (Option 1 implemented; Options 2/3 rejected)
  - Confirms all acceptance criteria met
  - Marks the seed as addressed/folded by Phase 197
  - Preserves the original (wrong) problem text — corrected-not-deleted

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove continue-on-error from design gallery step (D-10 / D-07 comment rewrite)** — `39b3aefd` (fix)
2. **Task 2: Record SEED-006 root-cause correction (D-07 operator-truth)** — `6b3816a7` (docs)

## Files Modified

- `.github/workflows/ci.yml` — deleted `continue-on-error: true` from "Run design gallery boards" step; replaced 12-line false-premise comment block with 17-line corrected D-07 explanation; YAML valid; aggregator and all other steps unchanged
- `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` — appended 67-line "Root-cause correction" section; original text preserved intact

## Decisions Made

- **D-10 re-gate as final wave-3 step:** `continue-on-error` is removed only AFTER Plans 03–04 provide deterministic render and CI-native baselines. Restoring the gate prematurely (before baselines are green in CI) would have made the gallery permanently red — hence the `depends_on: ["197-04"]` wave-3 ordering.
- **Operator-truth pattern for seed correction:** The incorrect text is preserved (not deleted) and the correction is added as an explicit dated section. This maintains historical traceability while ensuring the record reflects verified reality.
- **No tolerance widening:** The delta was root-caused by the OS `system-ui` metric difference and fixed by the self-hosted woff2. Widening `maxDiffPixelRatio` would mask the signal; it was never an option (GATE-02 equal-or-greater quality invariant).
- **Gallery stays inline:** D-10 explicitly mandates keeping the gallery step inside `example_playwright_smoke`, not relocating it to a nightly lane. The nightly option (Fix Option 3 in SEED-006) is now formally rejected and documented.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The gallery hard-gates on every PR. The CI-native baselines were recaptured by Plan 04 and are merged before this re-gate takes effect.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| Mitigated — T-197-12 | .github/workflows/ci.yml | Re-gate is wave-3 (depends_on: 197-04); hard gate restored only after CI-native baselines are captured and merged, preventing premature red |
| Mitigated — T-197-13 | SEED-006 | D-07 operator-truth correction recorded in writing; historical record reflects real OS-metric cause, not disproven webfont-load premise |
| Mitigated — T-197-14 | admin-design.spec.ts | No tolerance widened; delta root-caused via self-hosted font, signal quality preserved (GATE-02) |

## Phase 197 / PW-03 Completion

Plan 05 is the final plan in Phase 197. With Plans 03–05 delivered:

- **ROADMAP success criterion #3 (brand font loads):** Met — self-hosted Space Grotesk woff2 committed and wired (Plan 03); `document.fonts.ready` + `fonts.check` guard in spec prevents silent misconfiguration (T-197-06).
- **ROADMAP success criterion #4 (gallery re-gated, MG-5/6 resolved):** Met — `continue-on-error` removed (Plan 05); MG-5/6 data-dependency disposed as `test.skip` with tracked todo reference (D-11b, Plan 03).
- **PW-01/02/03 requirements:** All satisfied. PW-03 is the last open requirement.
- **SEED-006:** Addressed/folded. The false "webfont does not load" premise is corrected in writing.

## Self-Check: PASSED

- `.github/workflows/ci.yml` — modified (verified; YAML valid per `python3 yaml.safe_load`)
- `continue-on-error` absent from `design_gallery` step — confirmed (`grep` verified; remaining occurrence at line 1592 is the OQ3 cross-lane compare step in the separate `admin_design_recapture` job)
- `id: design_gallery` + `if: ${{ !cancelled() }}` retained — confirmed
- Aggregator reads `steps.design_gallery.outcome` — confirmed (unchanged)
- Stale comment block replaced — confirmed (old 12 lines; new 17 lines with D-07 explanation)
- SEED-006 — modified; `system` + `correct` grep verified; `addressed/folded` confirmed
- Commit `39b3aefd` — exists (git log verified)
- Commit `6b3816a7` — exists (git log verified)
