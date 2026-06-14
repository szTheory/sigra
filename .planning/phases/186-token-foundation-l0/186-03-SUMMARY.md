---
phase: 186-token-foundation-l0
plan: "03"
subsystem: testing
tags: [playwright, typescript, wcag, contrast-ratio, admin-ui, design-system]

# Dependency graph
requires:
  - phase: 186-token-foundation-l0/01
    provides: admin-token-reference.md rationale doc and L0 ledger row
  - phase: 186-token-foundation-l0/02
    provides: D-11 ExUnit dark-block parity assertion
provides:
  - "contrastRatio() computed-style assertions for 4 tone notices × 2 themes + brand-soft dark pair"
  - "Closed axe coverage gap for alpha-composited color-mix() soft backgrounds (TOKEN-02)"
affects: [admin-design-spec, token-foundation-l0-verification, 186-token-reference]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "expect.poll() for computed-style contrast assertions across theme switches"
    - "Loop over tones array for DRY multi-tone coverage in a single test block"
    - ".sg-text-sm child element as the inner text selector for .sg-notice components"
    - ".sg-metric__icon as the brand-soft surface selector (not the .sg-metric root)"

key-files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-theme.spec.ts

key-decisions:
  - "Inner text element for .sg-notice is .sg-text-sm (not .sg-notice__body); read from components.ex source"
  - "Brand-soft assertion targets .sg-metric__icon (has brand-soft bg + brand-strong color) not the .sg-metric chip root (which uses --sg-color-panel bg)"
  - "Loop over tones array for 4×2 matrix instead of 8 separate test statements — DRY and maintainable"
  - "Single test block at /admin/_design gallery covers all four tone notices and metric icon without fixture users"

requirements-completed:
  - TOKEN-02

# Metrics
duration: 12min
completed: 2026-06-14
---

# Phase 186 Plan 03: Tone-on-soft contrastRatio() assertions Summary

**9 computed-style WCAG AA assertions for tone-on-soft notice backgrounds and brand-soft metric icon, covering the axe-skipped alpha-composited color-mix() pairs in both light and dark modes**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-06-14T18:16:23Z
- **Completed:** 2026-06-14T18:22:16Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added a new Playwright test block covering the 5 color pairs (4 tone notices × 2 themes + 1 brand-soft dark pair) that axe cannot evaluate due to alpha-composited `color-mix(in oklab, ...)` backgrounds
- All 9 `contrastRatio()` assertions use `expect.poll()` for reliable computed-style reading after theme switches
- Test navigates to `/admin/_design` gallery (dev-only route) which renders all four tone notices and metric icon without requiring fixture users
- Closing TOKEN-02 WCAG AA verification for alpha-composited soft backgrounds

## Task Commits

Each task was committed atomically:

1. **Task 1: Add tone-on-soft contrastRatio() test block to admin-theme.spec.ts** - `7e0e07cc` (feat)

**Plan metadata commit:** (follows this SUMMARY)

## Files Created/Modified

- `test/example/priv/playwright/tests/admin-theme.spec.ts` - Added new test "tone notice and status chip pairs meet WCAG AA in light and dark (axe-skipped soft backgrounds)" with 4 light + 4 dark tone-notice assertions + 1 brand-soft metric icon dark assertion

## Decisions Made

- **Inner text selector:** The `.sg-notice` component renders inner content in `<div class="sg-text-sm">`, not a `.sg-notice__body` element (the RESEARCH.md had an approximation; confirmed from `components.ex` source). The assertion reads `getComputedStyle(inner).color` from `.sg-text-sm`.
- **Brand-soft surface:** The plan mentions "summary chip brand-strong on brand-soft" — the actual brand-soft surface is `.sg-metric__icon` (which has `background: var(--sg-color-brand-soft)` and `color: var(--sg-color-brand-strong)`). The `.sg-metric` root itself uses `--sg-color-panel` background and is not the brand-soft pair.
- **Loop pattern:** Used `const tones = ["ok", "warn", "risk", "info"] as const` and iterated with `for (const tone of tones)` to cover 4×2 assertions cleanly instead of repeating 8 similar blocks.

## Deviations from Plan

None - plan executed exactly as written. The inner text child selector was determined from reading `components.ex` (`.sg-text-sm` not `.sg-notice__body`) but this is a direct implementation detail lookup, not a deviation. The plan explicitly instructed to "read the notice HTML from the gallery to confirm the correct child selector."

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The Playwright assertions run against a locally booted example server.

## Next Phase Readiness

- TOKEN-02 WCAG AA computed-style gap is now covered for alpha-composited soft backgrounds
- Phase 186 verification gate can run `npx playwright test tests/admin-theme.spec.ts --project=chromium` to confirm all assertions pass with current token values
- All existing tests in admin-theme.spec.ts are undisturbed

---
*Phase: 186-token-foundation-l0*
*Completed: 2026-06-14*

## Self-Check: PASSED

Files exist:
- FOUND: test/example/priv/playwright/tests/admin-theme.spec.ts

Commits exist:
- FOUND: 7e0e07cc (feat(186-03): add tone-on-soft contrastRatio() assertions)
