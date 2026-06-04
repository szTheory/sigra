---
phase: 156-adopt-shared-components-on-baselined-screens
plan: "02"
subsystem: admin-ui
tags: [refactor, admin, liveview, components, coherence]
dependency_graph:
  requires: [lib/sigra/admin/components.ex]
  provides: [index_live.ex using shared components, organization_live.ex using shared components]
  affects: [admin overview screens, COHR-01 requirement]
tech_stack:
  added: []
  patterns: [import Sigra.Admin.Components, shared component delegation]
key_files:
  modified:
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
decisions:
  - "Delete duplicate defp blocks atomically with import addition to avoid name-collision shadow hazard"
  - "sg-list-row alert div migrated to <.notice> with atom :risk tone (not string) per notice/1 contract"
metrics:
  duration: "~5 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 156 Plan 02: Pixel-neutral import swap for Overview LiveViews Summary

Import `Sigra.Admin.Components` into `index_live.ex` and `organization_live.ex`, deleting duplicate `defp metric_link/1` and `defp task_card/1` blocks, renaming `<.metric_link>` call sites to `<.stat_link>`, and migrating the `organization_live.ex` alert row from a raw `sg-list-row` div to `<.notice>` with atom tone.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Pixel-neutral import swap — index_live.ex | a026c547 | lib/sigra/admin/live/index_live.ex |
| 2 | Pixel-neutral import swap — organization_live.ex | f6b5e5c5 | lib/sigra/admin/live/organization_live.ex |

## What Was Built

### Task 1 — index_live.ex

- Added `import Sigra.Admin.Components` immediately after `use Phoenix.LiveView`
- Deleted `defp metric_link(assigns)` block (lines 118–125) and its three `attr` declarations
- Deleted `defp task_card(assigns)` block (lines 132–144) and its four `attr` declarations
- Renamed all 6 `<.metric_link` call sites to `<.stat_link` (attr names `href`, `label`, `value` are identical — name-only change)
- `<.task_card` call sites left unchanged — the shared component has the same name
- `defp capability/1` preserved (not a shared component)

### Task 2 — organization_live.ex

- Added `import Sigra.Admin.Components` immediately after `use Phoenix.LiveView`
- Deleted `defp metric_link(assigns)` block (lines 169–181) and its three `attr` declarations
- Deleted `defp task_card(assigns)` block (lines 183–196) and its four `attr` declarations
- Renamed all 5 `<.metric_link` call sites to `<.stat_link`
- Migrated the `sg-list-row` alert div at line 71 to `<.notice tone={...}>` with atom `:risk` (not string `"risk"`) per `notice/1` attr contract
- The two children (`<p class="sg-meta-label">` and `<p class="sg-meta-value">`) preserved verbatim inside the inner_block slot

## Verification

All acceptance criteria passed via static grep checks:

```
index_live.ex:
  import Sigra.Admin.Components: 1 (pass)
  defp metric_link: 0 (pass)
  defp task_card: 0 (pass)
  <.stat_link call sites: 6 (pass)
  <.metric_link call sites: 0 (pass)

organization_live.ex:
  import Sigra.Admin.Components: 1 (pass)
  defp metric_link: 0 (pass)
  defp task_card: 0 (pass)
  <.stat_link call sites: 5 (pass)
  <.metric_link call sites: 0 (pass)
  <.notice call sites: 1 (pass)
  sg-list-row.*data-tone: 0 (pass)
```

Note: `mix test test/sigra/admin/` deferred to post-merge orchestrator gate — deps/_build not present in worktree. Static verification confirms the migration is structurally correct per PLAN.md acceptance criteria.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

No new security-relevant surface introduced. This plan migrates private component `defp` functions to shared imports only. No auth, session, token, or authorization code paths touched.

## Self-Check: PASSED

- lib/sigra/admin/live/index_live.ex — FOUND (modified)
- lib/sigra/admin/live/organization_live.ex — FOUND (modified)
- Commit a026c547 — FOUND (Task 1)
- Commit f6b5e5c5 — FOUND (Task 2)
