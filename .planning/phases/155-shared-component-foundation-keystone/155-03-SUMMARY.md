---
phase: 155-shared-component-foundation-keystone
plan: "03"
subsystem: ui
tags: [admin, design-contract, ci, playwright, a11y, aria]

requires:
  - phase: 155-shared-component-foundation-keystone plan 01/02
    provides: components.ex module and components_test.exs byte-equality gate

provides:
  - D-09 correction-of-fact: design contract notice entry now matches shipped no-role component
  - D-14 hard CI gate: example_playwright_smoke physically cannot run before library_tests passes

affects:
  - Phase 156 (COHR-01..06): call-site migration will reference the corrected contract
  - Phase 157 / LAND-01: per-call-site live-region role opt-in via :rest documented here

tech-stack:
  added: []
  patterns:
    - "D-09: Correction-of-fact amendments to the design contract are in-scope whenever the committed spec contradicts locked implementation decisions"
    - "D-14: CI gate wiring via needs: job dependency is stronger and less bypassable than in-script step ordering"

key-files:
  created: []
  modified:
    - guides/reference/admin-design-contract.md
    - .github/workflows/ci.yml

key-decisions:
  - "D-09 applied: design contract notice ARIA cell corrected — load-present notices carry no live-region role; tone is conveyed via data-tone + copy; live-region opt-in per-call-site via :rest for post-load dynamic notices only"
  - "D-14 applied: example_playwright_smoke job now declares needs: [release_ref_guard, library_tests] making byte-equality a hard non-bypassable precondition for the Playwright baseline guard"

patterns-established:
  - "Design contract ARIA cells must agree with the shipped component behavior — mismatches are correction-of-fact amendments, not optional polish"
  - "CI Playwright gating: use needs: job dependency (not in-script step ordering) for gating baseline guards on upstream test passes"

requirements-completed: [COMP-01, COMP-02]

duration: 8min
completed: 2026-06-04
---

# Phase 155 Plan 03: Spec/Gate Alignment Summary

**Design contract notice ARIA corrected to no-live-region (D-09) and Playwright CI gate hardened to need library_tests byte-equality pass (D-14)**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-04T06:40:00Z
- **Completed:** 2026-06-04T06:48:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Corrected the design contract notice entry: markup cell now targets `<div class="sg-notice" data-tone={tone}>` (not `sg-list-row`), and the ARIA cell now states load-present notices carry no live-region role with the D-08 rationale folded in
- Wired the CI gate: `example_playwright_smoke` job now declares `needs: [release_ref_guard, library_tests]` so the admin-checkpoint Playwright job physically cannot start before the byte-equality gate passes
- The keystone "re-record is a bug" rule is now enforced structurally in the CI DAG, not just by convention

## Task Commits

Each task was committed atomically:

1. **Task 1: Amend design contract notice ARIA (D-09)** - `ed9568fa` (docs)
2. **Task 2: Wire CI gate so Playwright needs library_tests (D-14)** - `f957d37e` (chore)

## Files Created/Modified
- `guides/reference/admin-design-contract.md` - Notice entry corrected: markup cell uses sg-notice, ARIA cell replaces role=alert/role=status mandate with D-09 no-live-region correction-of-fact
- `.github/workflows/ci.yml` - example_playwright_smoke job needs: changed from single value to [release_ref_guard, library_tests]

## Decisions Made
- Applied D-09 as a correction-of-fact: the committed contract mandated role="alert"/role="status" "in Phase 155 HEEx markup" which directly contradicted the shipped no-role component (D-08). The ARIA cell now accurately reflects shipped behavior.
- Folded D-08 rationale into the ARIA cell (role="alert" inert on load-present per WAI-ARIA APG; role="status" risks duplicate announcements on LiveView re-render; flash/1 uses role="alert" only for dynamic-inject with focus-management JS).
- Applied D-14 as a single-line edit: the existing `needs:` syntax across ci.yml was the correct analog — changed scalar to array form.

## Deviations from Plan

None - plan executed exactly as written.

The plan's automated verify script (`grep -Eqi 'no .*live-region role|carry no'`) had a minor regex mismatch: the ARIA cell text reads "carry **no** live-region role" (with markdown bold markers), so `carry no` does not match literally. However, the pattern `no.*live-region` does match, and all acceptance criteria are satisfied: markup cell targets `sg-notice`, no Phase 155 ARIA mandate, ARIA cell states no live-region role for load-present content.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- D-09 and D-14 are satisfied. The canonical spec and CI gate are now aligned with the keystone decisions.
- Phase 155 Plans 01/02 (components.ex module + test harness) are the remaining wave deliverables in this phase.
- Phase 156 call-site migration can reference the corrected contract directly.

## Self-Check

- [x] `guides/reference/admin-design-contract.md` exists and contains `sg-notice` in notice markup cell: CONFIRMED
- [x] No "applied in Phase 155 HEEx markup" phrase in notice entry: CONFIRMED
- [x] ARIA cell states no live-region role for load-present notices: CONFIRMED
- [x] `.github/workflows/ci.yml` contains `needs: [release_ref_guard, library_tests]`: CONFIRMED
- [x] CI YAML is valid (python3 yaml.safe_load passes): CONFIRMED
- [x] Task 1 commit ed9568fa exists: CONFIRMED
- [x] Task 2 commit f957d37e exists: CONFIRMED

## Self-Check: PASSED

---
*Phase: 155-shared-component-foundation-keystone*
*Completed: 2026-06-04*
