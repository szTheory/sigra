---
phase: 187-individual-components-l1
plan: "04"
subsystem: action-filter-return-components
tags:
  - admin-ui
  - actions
  - filters
  - playwright
  - ledger
requires:
  - plan: 187-03
    provides: metrics/help L1 state evidence pattern
provides:
  - Complete state evidence for task_card, applied_chip, and page_back
  - Shipped applied-chip remove interaction styling
  - Inert disabled sg-btn examples for action-family evidence
  - Ledger evidence links for three action-family components
affects:
  - Phase 187 Plans 05-07 state-matrix and ledger patterns
  - Admin-design registration helper determinism
tech-stack:
  added: []
  patterns:
    - Role-selected Playwright registration setup with positive success evidence
    - Short platform-admin test emails that preserve policy prefix
    - Board-local disabled examples verified by computed style and focusability
key-files:
  created:
    - .planning/phases/187-individual-components-l1/187-04-SUMMARY.md
  modified:
    - test/sigra/admin/components_test.exs
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
    - test/example/lib/example_web/live/admin/design_gallery_live.ex
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/
    - guides/reference/admin-quality-ledger.md
key-decisions:
  - "task_card remains an article with one native CTA link; keyboard focus stays on the CTA, not the card."
  - "sg-card-hover hover lift remains pointer-gated under @media (hover: hover) and (pointer: fine)."
  - "applied_chip remove controls keep explicit aria-label=\"Remove filter {label}\" and exact-property transitions."
  - "page_back remains a small ghost native link with aria-hidden arrow glyph plus descriptive text."
  - "Disabled evidence uses native disabled, aria-disabled plus tabindex=-1, or is-disabled examples with pointer-events: none."
patterns-established:
  - "Admin-design setup emails must preserve the host policy prefix while keeping the variable suffix short and deterministic."
  - "Full-matrix setup failures should be diagnosed separately from board visual diffs before refreshing snapshots."
requirements-completed:
  - COMP-01
  - COMP-02
  - COMP-03
  - COMP-04
  - COMP-05
  - COMP-06
duration: 55 min active
completed: 2026-06-15
---

# Phase 187 Plan 04: Action/Filter/Return Components Summary

**The action-family components now have complete L1 state evidence, shipped interaction styling, inert disabled examples, and ledger links.**

## Performance

- **Duration:** 55 min active, interrupted by local workstation suspension.
- **Started:** 2026-06-14T23:04:00Z
- **Completed:** 2026-06-15T02:59:11Z
- **Tasks:** 2 completed
- **Files modified:** 16

## Accomplishments

- Added failing then passing component and Playwright coverage for `task_card`, `applied_chip`, and `page_back`.
- Expanded `board-task_card`, `board-applied_chip`, and `board-page_back` with default, hover, focus-visible, active, and disabled evidence where applicable.
- Preserved native action semantics: task cards are not focusable containers, page back remains a native ghost link, and applied-chip remove links have explicit ARIA labels.
- Added shipped applied-chip remove focus-visible and active styles with exact-property transitions.
- Verified disabled button/link/span examples are inert through computed `pointer-events: none` and keyboard-focus assertions.
- Stabilized admin-design registration setup with role-selected submit, positive success evidence, and short `platform-admin+` test emails.
- Updated `task_card`, `applied_chip`, and `page_back` ledger rows with board ids plus component test evidence.

## Task Commits

1. **Task 1 RED: Add action-family state coverage** - `0b8a5408` (test)
2. **Task 1 GREEN: Complete action-family states** - `5c7bf233` (feat)
3. **Task 2: Record ledger evidence** - `331bdef8` (docs)
4. **Test stabilization: Admin-design registration helper** - `11500b40` (test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Snapshot] Expanded action boards required intended baseline refresh**
- **Found during:** Task 1 focused Playwright run
- **Issue:** `board-task_card`, `board-applied_chip`, and `board-page_back` changed size and visual content after adding complete state matrices.
- **Fix:** Refreshed only those three board baselines across chromium/mobile/dark after behavior checks passed.
- **Verification:** Focused board runs and the full 69-test admin-design matrix passed.
- **Committed in:** `5c7bf233`

**2. [Rule 5 - Determinism] Admin-design registration helper used a brittle setup path**
- **Found during:** Full admin-design matrix
- **Issue:** The helper submitted the registration form with `requestSubmit`, waited only for "not /users/register", and generated unbounded title-derived admin emails. A full-matrix run failed during registration setup rather than board rendering.
- **Fix:** Switched to the accessible "Create an account" button, waited for navigation away from `/users/register`, asserted the success alert, and generated short `platform-admin+dg-...` emails that still satisfy `Example.SigraAdminPolicy`.
- **Verification:** Targeted mobile rerun passed for `board-audit_row` plus the action-family assertion, then the full matrix passed 69/69.
- **Committed in:** `11500b40`

---

**Total deviations:** 2 auto-fixed verification/support updates
**Impact on plan:** Both changes support deterministic evidence for the planned component state work. No unrelated shipped behavior changed.

## Verification

- `mix test test/sigra/admin/components_test.exs` - 31 tests, 0 failures.
- `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs` - 59 tests, 0 failures.
- CSS parity `cmp` across canonical/example/golden `sigra_admin.css` - passed.
- `transition: all` grep against `sigra_admin.css` and `app.css` - passed.
- Source check for `.sg-card-hover:hover` under pointer-gated media only - passed.
- `SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "task_card|applied_chip|page_back|overflow"` - 4 tests, 0 failures.
- `SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-mobile --grep "board: board-audit_row|action boards expose"` - 2 tests, 0 failures.
- `bash scripts/ci/quality-ledger-monotonic.sh --base HEAD` - PASS, 25 cells checked.
- Full admin-design matrix with `SIGRA_EXAMPLE_URL=http://localhost:4011` - 69 tests, 0 failures, 398.08s wall-clock.

## Issues Encountered

- An earlier Playwright run during local suspension produced browser/network setup noise. Reruns on the active server passed and did not indicate a component regression.
- Root ExUnit runs continued to emit pre-existing Chimeway.Repo connection noise about a missing database option; the required Sigra tests completed with 0 failures.

## Next Phase Readiness

Plan 05 can reuse the state-evidence pattern for content/status components: RED source and board assertions, shipped CSS state updates, focused Playwright, ledger row update, then a full visual matrix when baselines change.

## Self-Check: PASSED

---
*Phase: 187-individual-components-l1*
*Completed: 2026-06-15*
