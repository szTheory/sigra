---
phase: 187-individual-components-l1
plan: "02"
subsystem: shipped-css
tags:
  - admin-ui
  - css
  - installer
  - design-system
requires:
  - phase: 186-token-foundation-l0
    provides: locked sg-* token layer and Phase 186 motion values
  - plan: 187-01
    provides: component CSS inventory, Wave 0 validation scaffold, and admin-design board evidence
provides:
  - Additive L1 motion tokens for exit and tooltip timing
  - Shipped component CSS under canonical @layer sg-components
  - app.css duplicate-selector removal for migrated L1 component families
  - Byte-identical canonical/example/golden sigra_admin.css parity
  - Green W0-04 validation and wave_0_complete status
affects:
  - Phase 187 component polish plans
  - Installer generated-host styling evidence
  - Admin-design visual baseline confidence
tech-stack:
  added: []
  patterns:
    - Canonical sigra_admin.css as the shipped component source of truth
    - Duplicate-selector grep proof against example-only masking
    - Byte-for-byte CSS parity across installer template, example mirror, and install golden
key-files:
  created:
    - .planning/phases/187-individual-components-l1/187-02-SUMMARY.md
  modified:
    - .planning/phases/187-individual-components-l1/187-CSS-INVENTORY.md
    - .planning/phases/187-individual-components-l1/187-VALIDATION.md
    - guides/reference/admin-token-reference.md
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
    - test/sigra/install/features/admin_test.exs
key-decisions:
  - "Existing Phase 186 motion values stayed byte-identical; Plan 02 added only the four L1 tokens required by D-06."
  - "Component CSS moved into canonical @layer sg-components and was copied byte-for-byte to the example mirror and install golden fixture."
  - "The scope_ribbon inventory row was closed by shipping its dedicated hook plus the shared sg-muted and sg-text-sm helpers it depended on."
patterns-established:
  - "Example app.css must not define migrated L1 component selectors; generated-host proof depends on canonical shipped CSS being the only component source."
  - "Any line-window assertions over CSS fixtures must be updated when additive token work shifts verified ranges."
requirements-completed:
  - COMP-01
  - COMP-02
  - COMP-03
duration: 26 min
completed: 2026-06-14
---

# Phase 187 Plan 02: Shipped Component CSS Summary

**The Wave 0 shipped-CSS gap is closed: migrated L1 component rules now ship from canonical `sigra_admin.css`, `app.css` no longer masks them, and W0-04 is green.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-06-14T22:18:21Z
- **Completed:** 2026-06-14T22:44:14Z
- **Tasks:** 3 completed
- **Files modified:** 8

## Accomplishments

- Added the four D-06 L1 motion tokens: `--sg-motion-exit`, `--sg-motion-tooltip`, `--sg-transition-exit`, and `--sg-transition-tooltip`.
- Documented those tokens in `guides/reference/admin-token-reference.md` while preserving the five locked Phase 186 motion values.
- Migrated status pills, buttons, card hover, applied chips, empty states, notices, notice links, field help, skeletons, list rows, metrics, metric links, code chips, scope ribbon, and required shared helpers into canonical `@layer sg-components`.
- Removed migrated component and helper selectors from `test/example/priv/static/assets/css/app.css`.
- Synced canonical `sigra_admin.css` byte-for-byte to the example mirror and install golden fixture.
- Marked all inventory rows migrated and greened `187-W0-04`; `wave_0_complete` is now true while `nyquist_compliant` remains false for final Plan 07 gates.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add L1-only motion tokens** - `3076f23f` (feat)
2. **Task 2: Migrate component CSS into shipped layer** - `8c6e6fc9` (feat)
3. **Task 3: Green shipped-CSS validation** - `6e8d061c` (docs)

## Files Created/Modified

- `.planning/phases/187-individual-components-l1/187-CSS-INVENTORY.md` - All selector rows marked migrated.
- `.planning/phases/187-individual-components-l1/187-VALIDATION.md` - W0-04 green and `wave_0_complete: true`.
- `guides/reference/admin-token-reference.md` - Additive L1 motion token documentation.
- `priv/templates/sigra.install/admin/sigra_admin.css` - Canonical shipped component CSS and motion tokens.
- `test/example/priv/static/assets/css/app.css` - Migrated component/helper duplicate definitions removed.
- `test/example/priv/static/assets/sigra_admin.css` - Synced from canonical.
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` - Synced from canonical.
- `test/sigra/install/features/admin_test.exs` - Updated verified dark-block line range after additive token insertion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Guard] Additive tokens shifted the D-11 dark-token line window**
- **Found during:** Task 1 install feature run
- **Issue:** Adding motion tokens before the dark block shifted `sigra_admin.css` line numbers, causing the hard-coded parity extractor to compare the wrong lines.
- **Fix:** Updated the verified canonical dark-block range from `166..203` to `176..209`.
- **Verification:** `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs` passed.
- **Committed in:** `3076f23f`

**2. [Rule 2 - Inventory Accuracy] scope_ribbon shared helper row needed actual migration**
- **Found during:** Task 2 final diff review
- **Issue:** The inventory included `.sg-muted` and `.sg-text-sm` as shared helpers used by `scope_ribbon`; marking the row migrated while leaving those helper rules in `app.css` would keep example-only masking.
- **Fix:** Shipped `.sg-muted` and `.sg-text-sm` in canonical CSS and removed their duplicates from `app.css`.
- **Verification:** Helper duplicate grep passed, install/golden tests passed, and the full admin-design matrix passed after the helper move.
- **Committed in:** `8c6e6fc9`

---

**Total deviations:** 2 auto-fixed
**Impact on plan:** Both changes strengthened the migration proof. No locked token values changed and no snapshot baselines changed.

## Issues Encountered

- Root ExUnit runs continued to emit pre-existing Chimeway.Repo connection noise about a missing database option; the required Sigra test files completed with 0 failures.
- The example server remained on port 4011 for Playwright because port 4000 was already occupied by a non-matching local app.

## Verification

- Token presence across all three `sigra_admin.css` parity surfaces: passed.
- Locked Phase 186 motion value grep in canonical CSS: passed.
- Duplicate-selector grep against `test/example/priv/static/assets/css/app.css`: passed.
- Canonical `@layer sg-components` selector-family Node check: passed.
- Canonical/example/golden CSS byte parity `cmp`: passed.
- No shipped `--vt-*` references and no `transition: all`: passed.
- No `| pending |` rows in `187-CSS-INVENTORY.md`: passed.
- `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs` - 28 tests, 0 failures.
- `SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark` - 63 tests, 0 failures, 250.66s wall-clock after the final helper migration.

## Next Phase Readiness

Plan 03 can polish individual component families against shipped CSS instead of example-only CSS. Wave 0 is complete; final Nyquist compliance remains intentionally false until Plan 07 runs final phase gates.

## Self-Check: PASSED

---
*Phase: 187-individual-components-l1*
*Completed: 2026-06-14*
