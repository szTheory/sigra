---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: 08
subsystem: testing
tags: [playwright, github-actions, ci, inventory, exunit]
requires:
  - phase: 234-01
    provides: contributor-gate tracer and Phase 234 execution baseline
provides:
  - Explicit chromium/retry-zero ownership for the admin theme and coherence Playwright specs
  - Phase 235-consumable, exact-set Playwright spec-to-CI ownership inventory
  - Fail-closed ExUnit reconciliation for workflow and configuration seams
affects: [phase-235, ci, playwright]
tech-stack:
  added: []
  patterns: [exact live-universe reconciliation, literal workflow-and-config seam validation]
key-files:
  created:
    - .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json
    - test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
  modified:
    - .github/workflows/ci.yml
    - test/example/priv/playwright/playwright.config.ts
key-decisions:
  - "Keep both useful orphan specs in the existing isolated admin_behavior chromium shard with explicit retry-zero command evidence."
  - "Treat the committed inventory as Phase 235 GATE-05 input and validate exact paths plus literal workflow/config seams."
patterns-established:
  - "Coverage inventories must reconcile bidirectionally with the live glob and reject stale, duplicate, or unowned rows."
  - "Workflow ownership claims resolve against bounded job bodies and concrete Playwright configuration tokens."
requirements-completed: [DX-04]
coverage:
  - id: D1
    description: "Both formerly orphaned admin specs run through the existing admin_behavior Chromium lane with retries disabled."
    requirement: DX-04
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_234_playwright_inventory_contract_test.exs#admin_behavior explicitly owns both useful orphan specs on retry-zero chromium
        status: pass
      - kind: other
        ref: npx playwright test --list tests/admin-theme.spec.ts tests/admin-coherence-sweep.spec.ts --project=chromium --retries=0
        status: pass
    human_judgment: false
  - id: D2
    description: "Every live Playwright spec has a resolvable CI owner and the Phase 235 inventory rejects drift."
    requirement: DX-04
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_234_playwright_inventory_contract_test.exs#the Phase 235 inventory exactly reconciles live specs and executable lane seams
        status: pass
      - kind: unit
        ref: test/sigra/planning/phase_234_playwright_inventory_contract_test.exs#inventory validation rejects missing stale duplicate unowned and broken lane tokens
        status: pass
    human_judgment: false
duration: 5m
completed: 2026-08-01
status: complete
---

# Phase 234 Plan 08: Playwright Ownership Inventory Summary

**Every live Playwright spec now has a machine-checked CI owner, and the two useful admin behavior orphans run explicitly in the retry-zero Chromium shard.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-01T02:04:37Z
- **Completed:** 2026-08-01T02:09:37Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Routed `admin-theme.spec.ts` and `admin-coherence-sweep.spec.ts` through the existing isolated `admin_behavior` CI seam with Chromium and `--retries=0`.
- Published the sorted 20-spec `234-PLAYWRIGHT-INVENTORY.json` as Phase 235 GATE-05 input.
- Added a fail-closed ExUnit contract for exact live-spec reconciliation and broken ownership-token mutations.

## Task Commits

1. **Task 1: Route both useful orphan specs through admin_behavior (D-09)** - `0b17e409` (test), `6c57d7b4` (feat)
2. **Task 2: Publish and reconcile the complete Playwright ownership inventory (D-08, D-09)** - `1dc53108` (test), `d0075f48` (feat)

## Files Created/Modified

- `.github/workflows/ci.yml` - Names both orphan specs in the existing admin behavior command.
- `test/example/priv/playwright/playwright.config.ts` - Includes coherence sweep in the shared admin behavior exclusion seam.
- `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json` - Exact, Phase 235-consumable ownership map for all live specs.
- `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` - TDD contract for routing and inventory drift detection.

## Decisions Made

- Preserved useful coverage by assigning both orphans to the already-isolated `admin_behavior` seam rather than deleting or creating a new shard.
- Use literal workflow job, seam, command-marker, project, and configuration-seam tokens as the inventory proof surface.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The focused structural ExUnit commands emitted local Postgrex connection-refused log noise for the unavailable test database, but all 10 targeted assertions passed; the contracts themselves do not require database access.

## Known Stubs

None.

## Next Phase Readiness

Phase 235 can consume the committed inventory directly for GATE-05 coverage reconciliation. No human setup or external credentials are required.

## Self-Check: PASSED

- Verified the inventory and contract-test files exist.
- Verified all four TDD/task commits exist in git history.

---
*Phase: 234-hygiene-supply-chain-and-contributor-dx*
*Completed: 2026-08-01*
