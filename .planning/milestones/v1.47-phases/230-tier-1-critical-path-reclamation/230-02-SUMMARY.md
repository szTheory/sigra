---
phase: 230-tier-1-critical-path-reclamation
plan: 02
subsystem: testing
tags: [playwright, axe-core, wcag, ci, admin-design]

# Dependency graph
requires:
  - phase: 230-01
    provides: "Committed CI-run measurement instrument (scripts/ci/ci-run-metrics.sh); this plan does not depend on its output, just runs after it in wave order"
provides:
  - "admin-design.spec.ts split into 28 @snapshot-tagged board-screenshot tests and 13 untagged behaviour/accessibility tests per design project"
  - "One full-page WCAG 2.1/2.2 AA axe scan per design project, replacing the ~84 identical per-board scans"
  - "Sigra.Planning.Phase230DesignGallerySplitTest static ExUnit contract pinning the tag partition"
affects: [230-03, 231]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Playwright details-object tag form: test(title, { tag: '@snapshot' }, fn) instead of embedding the tag in the title"
    - "Static ExUnit contract test over a Playwright spec's raw file contents (File.read! + regex, no YAML/TS parser)"

key-files:
  created:
    - test/sigra/planning/phase_230_design_gallery_split_test.exs
  modified:
    - test/example/priv/playwright/tests/admin-design.spec.ts

key-decisions:
  - "Collapsed the ~84 per-board axe scans to one full-page axe test per design project (D-01) rather than a literal pixels-only split, because every board test reached axe in an identical page state (no .include() scoping) and the registration cost that must stay on PR lives in beforeEach, not in the board-specific work"
  - "Tagged via Playwright's details-object second-positional-argument form (D-02), not by embedding @snapshot in the title, so PNG baseline filenames stay byte-identical and the tag surfaces through TestInfo.tags and the HTML report"
  - "Tagged the per-board test() declaration itself, never test.describe, so a tag cannot accidentally sweep all 41 tests per project"
  - "Left playwright.config.ts untouched (confirmed via git diff --stat) — the split is expressed entirely as a spec-level tag plus CLI grep flags, per D-03/D-22"

requirements-completed: [FAST-02]

coverage:
  - id: D1
    description: "admin-design.spec.ts partitions into exactly 28 @snapshot-tagged board tests and 13 untagged tests per design project (123 total across the three projects), with all board titles and PNG baseline filenames unchanged"
    requirement: "FAST-02"
    verification:
      - kind: e2e
        ref: "npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --list --grep '@snapshot' => Total: 28 tests"
        status: pass
      - kind: e2e
        ref: "npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --list --grep-invert '@snapshot' => Total: 13 tests"
        status: pass
      - kind: e2e
        ref: "npx playwright test tests/admin-design.spec.ts --project=admin-design-mobile|admin-design-dark --list --grep/--grep-invert '@snapshot' => same 28/13 split"
        status: pass
      - kind: e2e
        ref: "npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --list => Total: 123 tests"
        status: pass
    human_judgment: false
  - id: D2
    description: "The WCAG axe scan is relocated out of the per-board path into one dedicated, untagged, full-page test per design project, with corrected doc comments stating the scan is full-document"
    requirement: "FAST-02"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_230_design_gallery_split_test.exs#assertBoardScreenshot no longer calls the axe helper"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_230_design_gallery_split_test.exs#the full-page axe test exists and is untagged"
        status: pass
      - kind: other
        ref: "grep -n \"element-scoped (board locator, not full page)|not full page\" admin-design.spec.ts => no match"
        status: pass
    human_judgment: false
  - id: D3
    description: "The tag partition, untagged describe, axe relocation, and board-count arithmetic are all mechanically enforced by a committed ExUnit contract"
    requirement: "FAST-02"
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_230_design_gallery_split_test.exs => 5 tests, 0 failures"
        status: pass
      - kind: unit
        ref: "manual regression check: removing { tag: '@snapshot' } from the board loop fails test 1 with a message naming the untagged-board hazard; file restored, suite green again"
        status: pass
    human_judgment: false

# Metrics
duration: ~10min
completed: 2026-07-28
status: complete
---

# Phase 230 Plan 02: Design Gallery Axe/Snapshot Split Summary

**Split `admin-design.spec.ts` into 28 `@snapshot`-tagged pixel-diff board tests plus a single untagged full-page WCAG 2.1/2.2 AA axe test per design project, pinned by a new ExUnit static contract test — coverage-neutral per the owner-ratified D-01 collapse.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-07-28
- **Tasks:** 2 completed
- **Files modified:** 2 (1 modified, 1 created)

## Accomplishments
- Tagged all 28 board-screenshot tests `@snapshot` via Playwright's details-object form, verified as exactly 28 tagged / 13 untagged / 123 total across the three design projects (`admin-design-chromium`, `-mobile`, `-dark`).
- Removed the per-board `assertNoAxeViolations` call from `assertBoardScreenshot` and added one dedicated, untagged `axe: full-page WCAG 2.1/2.2 AA on the design gallery` test per project, so the WCAG signal stays on every lane while the pixel diffs become event-gateable.
- Corrected two stale doc comments (file header and the axe-helper comment) that wrongly described the axe scan as element-scoped when the code (`new AxeBuilder({ page })` with no `.include()`) has always scanned the whole document.
- Added `Sigra.Planning.Phase230DesignGallerySplitTest` (5 tests) enforcing: the board loop is tagged and iterates all three board catalogs; `test.describe` is never tagged; `assertBoardScreenshot` no longer calls the axe helper; the full-page axe test exists and is untagged; the three board catalogs total 13 + 11 + 4 = 28.
- Confirmed `test/example/priv/playwright/playwright.config.ts` carries zero diff — the split is expressed entirely as a spec-level tag plus CLI `--grep`/`--grep-invert` flags, leaving the event-gating wiring itself to plan 230-03.

## Task Commits

Each task was committed atomically:

1. **Task 1: Tag the 28 board tests and give each design project one full-page WCAG test** - `768a32c1` (feat)
2. **Task 2: Pin the split with an ExUnit static contract test** - `b763b06c` (test)

## Files Created/Modified
- `test/example/priv/playwright/tests/admin-design.spec.ts` - Tagged the board loop `@snapshot`, moved the axe call out of `assertBoardScreenshot` into a new untagged per-project axe test, corrected two stale "element-scoped" doc comments
- `test/sigra/planning/phase_230_design_gallery_split_test.exs` - New static ExUnit contract pinning the tag partition, the untagged describe, the axe relocation, and the 28-board arithmetic

## Decisions Made
- Collapsed the ~84 per-board axe scans to one full-page axe test per design project (D-01), not a literal pixels-only split, because every board test reached axe in an identical page state and the registration cost that must stay on PR lives in `beforeEach`.
- Used Playwright's details-object tag form (D-02) rather than embedding `@snapshot` in titles, keeping the 28 board titles — and therefore all PNG baseline filenames — byte-identical.
- Tagged only the per-board `test()` declaration, never `test.describe`, so a stray tag can never sweep the WCAG scan or the 12 behavior tests off the PR lane.
- Left `playwright.config.ts` untouched — confirmed via `git diff --stat` producing no output, satisfying D-03/D-22's constraint that the filtering mechanism is CLI-only.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' acceptance criteria were verified directly (Playwright `--list` counts, `mix test`, and the manual tag-removal regression check) rather than assumed from the diff.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The spec now exposes a clean `@snapshot` grep seam. Plan 230-03 (not this plan) is responsible for wiring `ci.yml` to run `--grep-invert '@snapshot'` on PR and `--grep '@snapshot'` off-PR, adding the new step's `id` to the seam-outcome aggregator (D-05), and correcting the `example_playwright_smoke` runtime estimate once the demoted step is measured.
- No baseline PNGs were renamed or need recapture — all 28 board titles are byte-identical to their pre-change form.
- `test/sigra/planning/phase_230_design_gallery_split_test.exs` now guards this partition on every `mix test` run, so a future board added without the tag fails fast instead of silently landing on the PR critical path.

## Self-Check: PASSED

- FOUND: `test/example/priv/playwright/tests/admin-design.spec.ts`
- FOUND: `test/sigra/planning/phase_230_design_gallery_split_test.exs`
- FOUND commit `768a32c1` (Task 1)
- FOUND commit `b763b06c` (Task 2)

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-28*
