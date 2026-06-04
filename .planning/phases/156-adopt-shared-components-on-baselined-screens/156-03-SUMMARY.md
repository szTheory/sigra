---
phase: 156-adopt-shared-components-on-baselined-screens
plan: 03
subsystem: ui
tags: [liveview, admin, shared-components, scope-ribbon, applied-chip, empty-state]

# Dependency graph
requires:
  - phase: 156-adopt-shared-components-on-baselined-screens
    provides: "Sigra.Admin.Components with summary_chip, applied_chip, scope_ribbon, empty_state"
provides:
  - "users_index_live.ex imports Sigra.Admin.Components and delegates summary_chip, applied_chip, empty_state, scope_ribbon"
  - "scope_ribbon placed after </header> in users_index_live — COHR-04 satisfied"
  - "inline applied-chip span loop replaced by <.applied_chip :for={...}> — COHR-01 satisfied"
  - "inline sg-empty-state div replaced by <.empty_state> — COHR-06 satisfied"
affects:
  - 156-04
  - 156-05
  - playwright-baseline-wave2-gate

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "import Sigra.Admin.Components at module top (after use Phoenix.LiveView) to resolve shared components"
    - "scope_ribbon placed as sibling of <header> (not nested inside it) on list screens"

key-files:
  created: []
  modified:
    - lib/sigra/admin/live/users_index_live.ex

key-decisions:
  - "scope_ribbon placed immediately after </header> as sibling element per COHR-04 placement rule — not nested inside the header block"
  - "defp summary_chip deleted entirely; import resolves call sites without any changes at call sites"
  - "empty_state inner_block preserves verbatim body text per CONTEXT.md byte-faithful migration rule"

patterns-established:
  - "Wave-2 migration pattern: add import, remove inline defp, wire shared components, keep data-helper defps intact"

requirements-completed: [COHR-01, COHR-04, COHR-06]

# Metrics
duration: 8min
completed: 2026-06-04
---

# Phase 156 Plan 03: users_index_live.ex Admin Shared-Component Migration Summary

**Migrated users_index_live.ex to Sigra.Admin.Components: deleted local defp summary_chip, added scope_ribbon after header, replaced inline applied-chip loop and empty-state div with shared components — all 65 admin tests green**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-04T05:00:00Z
- **Completed:** 2026-06-04T05:08:00Z
- **Tasks:** 1 of 2 (Task 2 deferred to orchestrator — see below)
- **Files modified:** 1

## Accomplishments

- Added `import Sigra.Admin.Components` after `use Phoenix.LiveView` (COHR-01)
- Removed `<p class="sg-page-copy">{scope_copy(@admin_scope)}</p>` from inside the page header (COHR-04)
- Added `<.scope_ribbon copy={scope_copy(@admin_scope)} />` as a sibling element after `</header>` (COHR-04)
- Replaced the inline `:for` span loop with `<.applied_chip :for={chip <- applied_chips(@current_params)} .../>` (COHR-01)
- Replaced the inline `sg-empty-state` div with `<.empty_state :if={@rows == []} title="No users match this view">` preserving inner body text verbatim (COHR-06)
- Deleted local `defp summary_chip` and its `attr` declarations — import resolves call sites unchanged
- 65 admin tests pass (`mix test test/sigra/admin/`)

## Task Commits

1. **Task 1: Migrate users_index_live.ex — import, defp removal, scope_ribbon, applied_chip, empty_state** - `001a74b9` (refactor)

**Plan metadata commit:** pending (this SUMMARY)

## Files Created/Modified

- `lib/sigra/admin/live/users_index_live.ex` — added import, removed defp summary_chip and sg-page-copy subtitle, added scope_ribbon after header, wired applied_chip and empty_state shared components

## Decisions Made

- scope_ribbon placed after `</header>` as sibling (not inside it) — per COHR-04 placement rule confirmed in 156-RESEARCH.md and 156-UI-SPEC.md; list screens have no page_back sibling so no sg-cluster--between wrapper needed
- defp summary_chip deleted without call site changes — import resolves identical `label=`/`value=` attr names
- empty_state inner_block body text preserved verbatim as specified in plan to pass byte-faithful migration rule

## Deviations from Plan

None — plan executed exactly as written.

## Deferred to Orchestrator Wave Gate

**Task 2 (Playwright baseline re-record) is deferred to the execute-phase orchestrator.**

The orchestrator performs all Wave-2 Playwright baseline re-records CENTRALLY on a freshly-compiled example server after all three Wave-2 code migrations land (156-03, 156-04, 156-05). This executor did NOT boot any Phoenix server, did NOT run `npx playwright`, and did NOT touch any `.png` snapshot files.

The 6 expected baseline files requiring re-record after the wave-2 gate:

```
test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-chromium.png
test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png
test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-mobile.png
test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-chromium.png
test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-dark.png
test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-mobile.png
```

The `impersonation-banner` snapshots (×3) must remain byte-green — they are the canary for unintended visual regressions.

## Issues Encountered

None. The Postgrex `Chimeway.Repo` connection errors in test output are from an optional integration fixture with a missing database config — they are pre-existing and unrelated to Sigra's test suite. All 65 Sigra admin tests pass.

## Next Phase Readiness

- users_index_live.ex migration complete and green
- Wave-2 sibling plans (156-04, 156-05) can proceed in parallel
- Playwright baseline re-record gate awaits all three Wave-2 code migrations landing

## Self-Check: PASSED

- `grep -c "import Sigra.Admin.Components" lib/sigra/admin/live/users_index_live.ex` → 1
- `grep -v "^#" lib/sigra/admin/live/users_index_live.ex | grep -c "defp summary_chip"` → 0
- `grep -c "<\.scope_ribbon" lib/sigra/admin/live/users_index_live.ex` → 1
- `grep -c "sg-page-copy.*scope_copy" lib/sigra/admin/live/users_index_live.ex` → 0
- `grep -c "<\.applied_chip" lib/sigra/admin/live/users_index_live.ex` → 1
- `grep -c "<\.empty_state" lib/sigra/admin/live/users_index_live.ex` → 1
- `mix test test/sigra/admin/` → 65 tests, 0 failures

---
*Phase: 156-adopt-shared-components-on-baselined-screens*
*Completed: 2026-06-04*
