---
phase: 156-adopt-shared-components-on-baselined-screens
plan: 05
subsystem: ui
tags: [admin, liveview, components, audit, scope_ribbon, applied_chip, empty_state]

requires:
  - phase: 156-adopt-shared-components-on-baselined-screens
    provides: "Sigra.Admin.Components with scope_ribbon/1, applied_chip/1, empty_state/1 (plans 01-02)"

provides:
  - "audit_index_live.ex imports Sigra.Admin.Components"
  - "scope_ribbon placed after </header> on the audit explorer screen (COHR-04)"
  - "applied_chip component wired for audit filter chips (COHR-01)"
  - "empty_state component wired for audit empty/filtered states (COHR-06)"

affects:
  - "156-adopt-shared-components-on-baselined-screens wave-2 baseline re-record"
  - "audit-explorer Playwright checkpoint (×3 projects — deferred to orchestrator)"

tech-stack:
  added: []
  patterns:
    - "Wave-2 migration pattern: import Sigra.Admin.Components, remove sg-page-copy from header, add scope_ribbon sibling after header, swap inline applied-chip loop, swap inline empty-state div"

key-files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_index_live.ex

key-decisions:
  - "Task 2 (Playwright baseline re-record for audit-explorer ×3 projects) is deferred to the orchestrator's centralised wave-2 gate, not executed by this agent"

patterns-established:
  - "scope_ribbon is placed immediately after </header> as a sibling element (NOT nested inside), following D-07/UI-SPEC"
  - "applied_chip :for loop replaces the inline span loop preserving the surrounding sg-cluster--start div"
  - "empty_state :if={@rows == []} wraps the conditional body verbatim, replacing the inline sg-empty-state div"

requirements-completed:
  - COHR-01
  - COHR-04
  - COHR-06

duration: 8min
completed: 2026-06-04
---

# Phase 156 Plan 05: Audit Index LiveView — Shared Components Migration Summary

**audit_index_live.ex migrated to Sigra.Admin.Components: scope_ribbon after header, applied_chip for filter chips, empty_state for zero-row placeholder (COHR-01/04/06 satisfied)**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-04T05:06:00Z
- **Completed:** 2026-06-04T05:14:00Z
- **Tasks:** 1 of 2 (Task 2 deferred to orchestrator)
- **Files modified:** 1

## Accomplishments

- Added `import Sigra.Admin.Components` to `audit_index_live.ex`
- Replaced `<p class="sg-page-copy">{scope_copy(@admin_scope)}</p>` inside the header with `<.scope_ribbon copy={scope_copy(@admin_scope)} />` placed as a sibling after `</header>`
- Replaced the inline `:for` span loop with `<.applied_chip :for=… label=… remove_href=… />`
- Replaced the inline `sg-empty-state` div with `<.empty_state :if={@rows == []} title="No audit events match this view">` preserving inner conditional and body text verbatim
- All 65 admin tests pass (`mix test test/sigra/admin/`)

## Task Commits

1. **Task 1: Migrate audit_index_live.ex — import, scope_ribbon, applied_chip, empty_state** - `ea45f193` (refactor)

**Plan metadata:** (SUMMARY commit — see final commit in this branch)

## Files Created/Modified

- `lib/sigra/admin/live/audit_index_live.ex` — Added import, replaced scope subtitle with scope_ribbon sibling, replaced inline chip loop with applied_chip, replaced inline empty-state div with empty_state component

## Decisions Made

- Task 2 (Playwright baseline re-record) is intentionally deferred to the orchestrator. The orchestrator will perform all Wave-2 baseline re-records centrally after all three Wave-2 code migrations land.

## Deviations from Plan

None — plan executed exactly as written for Task 1. Task 2 was explicitly excluded from this agent's scope per the orchestrator directive.

## Deferred to Orchestrator Wave Gate

**Task 2: Playwright baseline re-record for slug `audit-explorer` (×3 projects)**

The following `.png` baseline files are expected to be updated by the orchestrator after all Wave-2 code migrations land:

- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-chromium.png`
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png`
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-mobile.png`

Expected delta: only the COHR-04 scope-ribbon addition (new `<span class="sg-muted sg-text-sm">` after `</header>`). The applied-chip and empty-state changes are byte-neutral (same rendered HTML).

Constraint: `impersonation-banner` snapshot must remain byte-green (no changes to that screen were made in this plan).

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `audit_index_live.ex` is fully migrated to shared components
- Ready for orchestrator to perform centralized Wave-2 Playwright baseline re-record (audit-explorer ×3 projects)
- No blockers

## Self-Check: PASSED

All acceptance checks verified before commit:

- `grep -c "import Sigra.Admin.Components" lib/sigra/admin/live/audit_index_live.ex` → 1
- `grep -c "<\.scope_ribbon" lib/sigra/admin/live/audit_index_live.ex` → 1
- `grep -c "sg-page-copy.*scope_copy" lib/sigra/admin/live/audit_index_live.ex` → 0
- `grep -c "<\.applied_chip" lib/sigra/admin/live/audit_index_live.ex` → 1
- `grep -c "<\.empty_state" lib/sigra/admin/live/audit_index_live.ex` → 1
- `mix test test/sigra/admin/` → 65 tests, 0 failures (exit 0)
- Commit `ea45f193` exists in git log

---
*Phase: 156-adopt-shared-components-on-baselined-screens*
*Completed: 2026-06-04*
