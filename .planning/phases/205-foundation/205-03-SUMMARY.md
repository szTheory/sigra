---
phase: 205-foundation
plan: "03"
subsystem: admin-design-gallery
tags:
  - design-gallery
  - composites
  - playwright
  - snapshots
  - board-cfg
dependency_graph:
  requires:
    - 205-02-SUMMARY.md
  provides:
    - board-cfg-overview composite in design_gallery_live.ex
    - board-cfg-users-list composite in design_gallery_live.ex
    - board-cfg-user-detail composite in design_gallery_live.ex
    - board-cfg-audit composite in design_gallery_live.ex
    - CONFIG_BOARDS array in admin-design.spec.ts
    - isCfgBoard higher-budget screenshot logic in admin-design.spec.ts
    - config boards structural assertion test
  affects:
    - test/example/lib/example_web/live/admin/design_gallery_live.ex
    - test/example/priv/playwright/tests/admin-design.spec.ts
tech_stack:
  added: []
  patterns:
    - Static-literal-assign composite board pattern (mirrors MG-1..MG-11)
    - isCfgBoard budget discrimination in assertBoardScreenshot (wider tolerances for larger surfaces)
    - Per-array spread into screenshot + responsive loops (...CONFIG_BOARDS)
key_files:
  created: []
  modified:
    - test/example/lib/example_web/live/admin/design_gallery_live.ex
    - test/example/priv/playwright/tests/admin-design.spec.ts
decisions:
  - "D-08/D-09: 4 board-cfg-* composites authored with static literal assigns, source-archetype comments, sg-* class patterns; no card-in-card nesting"
  - "D-10: CONFIG_BOARDS array spread into screenshot loop and responsive/overflow loop; isCfgBoard applies higher maxDiffPixels budget (CI: 300k/0.30, dark: 120k/0.15, mobile: 80k/0.12, default: 50k/0.09)"
  - "D-11: Snapshot baselines pending first-run capture via scripts/uat/up.sh (server not running locally); board-notice canary byte-stable; both allowlists empty"
metrics:
  duration_minutes: 5
  completed_date: "2026-06-28"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
status: complete
---

# Phase 205 Plan 03: board-cfg-* Page Composite Boards + CONFIG_BOARDS Registration Summary

4 real-page composite boards authored in design_gallery_live.ex (board-cfg-overview, board-cfg-users-list, board-cfg-user-detail, board-cfg-audit) and registered in admin-design.spec.ts via CONFIG_BOARDS array with higher snapshot tolerance budget for larger surfaces.

## What Was Built

### Task 1 — Author 4 board-cfg-* composites in design_gallery_live.ex (D-08, D-09)

Added a new top-level "Page Composites" section (`<h2 class="sg-section-heading">Page Composites</h2>`) immediately before the closing `</section>` of the outermost `sg-stack sg-stack--6` wrapper in `design_gallery_live.ex`. The section contains 4 composite boards:

**board-cfg-overview** (Overview archetype — index_live.ex reference)
- `sg-page-header` with kicker "Platform admin" + h1 "Overview" + copy
- `.notice tone={:risk}` with inline `notice_link` ("2 accounts locked — Review accounts")
- `sg-grid sg-grid--3` containing 3 `.task_card` elements (Manage users, Review audit trail, Manage organizations)

**board-cfg-users-list** (List archetype — users_index_live.ex reference)
- `sg-page-header` with kicker "User operations" + h1 "Users"
- `scope_ribbon` ("Viewing all organizations")
- Static filter-panel (`sg-filter-panel`) with search input + `applied_chip` "Status: Locked" + "Clear all"
- `sg-metric-grid` with 3 `summary_chip` elements (Total users neutral, Locked risk, Deletion scheduled warn)

**board-cfg-user-detail** (Detail archetype — user_show_live.ex reference)
- `sg-page-header` with kicker "User detail" + h1 with static email literal
- `scope_ribbon` + `page_back` to /admin/users
- Identity article: display name, `sg-code` email, status pills
- Sessions article: one static session list-row
- MFA credentials article: `empty_state` ("No MFA credentials") — demonstrates both populated and zero-state sections

**board-cfg-audit** (Audit archetype — audit_index_live.ex reference)
- `sg-page-header` with kicker "Audit" + h1 "Audit events"
- Static filter-panel with date inputs, action filter, `applied_chip` "Action: login"
- `sg-table` with thead (Event, Actor, Target, Occurred at) + 2 static `audit_table_row` calls

All boards: static literal assigns only, no DB/Repo/Ecto.Query, no card-in-card nesting, source-archetype comment on each board.

**Commit:** `4ca6e537`

### Task 2 — Register CONFIG_BOARDS in admin-design.spec.ts, add structural assertion, capture baselines (D-10, D-11)

Applied 5 changes to `admin-design.spec.ts`:

1. **CONFIG_BOARDS array** added after GROUP_BOARDS (line ~118): `const CONFIG_BOARDS = ['board-cfg-overview', 'board-cfg-users-list', 'board-cfg-user-detail', 'board-cfg-audit'] as const;`

2. **isCfgBoard detection** in `assertBoardScreenshot`: `const isCfgBoard = boardId.startsWith('board-cfg-');` with conditional maxDiffPixels/maxDiffPixelRatio — higher budget for cfg boards (CI: 300k/0.30, dark: 120k/0.15, mobile: 80k/0.12, default: 50k/0.09) vs MG-board values (CI: 200k/0.22, dark: 75k/0.10, mobile: 45k/0.08, default: 30k/0.06)

3. **Screenshot loop spread**: `for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS])`

4. **Responsive/overflow loop spread**: `for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS])`

5. **Structural assertion test** "config boards expose expected archetype sections" — iterates CONFIG_BOARDS, asserts each board is visible and has at least one h1/h2 heading

Canary stability (D-11): `board-notice.png` (impersonation-banner canary) is byte-stable. Both allowlist files are empty (comments only — steady state). No snapshot files for board-cfg-* exist; they are pending first-run capture on the next `scripts/uat/up.sh` run — treated as net-new captures per D-11.

**Commit:** `da980c7a`

## Verification Results

```
grep -c "board-cfg-overview\|board-cfg-users-list\|board-cfg-user-detail\|board-cfg-audit" \
  test/example/lib/example_web/live/admin/design_gallery_live.ex
=> 8 (each id appears in both the board id= and the source comment)

grep -c "CONFIG_BOARDS" test/example/priv/playwright/tests/admin-design.spec.ts
=> 5 (definition + comment + 2 loop spreads + structural test loop)

cd test/example && mix compile --warnings-as-errors
=> 0 warnings, 0 errors (Generated example app)

grep -c "isCfgBoard\|board-cfg" test/example/priv/playwright/tests/admin-design.spec.ts
=> 4 (isCfgBoard declaration + 2 conditional uses + CONFIG_BOARDS definition)

grep -c "Ecto\|Repo\|Query" test/example/lib/example_web/live/admin/design_gallery_live.ex
=> 2 (both in @moduledoc / comments, no actual imports)

git diff --name-only test/example/priv/playwright/ | grep "board-notice"
=> (empty — canary byte-stable)

cat test/example/priv/playwright/snapshot-allowlist-design
=> (comments only — empty steady state)

cat test/example/priv/playwright/snapshot-allowlist
=> (comments only — empty steady state)
```

## Deviations from Plan

None — plan executed exactly as written. The "server not running" snapshot capture case was explicitly anticipated in the plan (D-11 net-new semantics) and documented accordingly.

## Known Stubs

None. All composites use static literal assigns with realistic data values. The `placeholder` HTML attribute on the search input in board-cfg-users-list is a standard HTML form pattern, not a stub.

## Threat Flags

No new threat-relevant surface introduced. The design gallery remains dev-only (compile_env(:example, :dev_routes) gated). Composite boards use static assigns with no real user data. No new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- [x] `test/example/lib/example_web/live/admin/design_gallery_live.ex` modified — verified 4 board-cfg-* ids (8 occurrences including comments), "Page Composites" section heading, no DB imports
- [x] `test/example/priv/playwright/tests/admin-design.spec.ts` modified — verified CONFIG_BOARDS (5 occurrences), isCfgBoard logic, screenshot/responsive loop spreads, structural assertion test
- [x] `mix compile --warnings-as-errors` clean in test/example
- [x] Commit `4ca6e537` exists — Task 1 (board-cfg-* composites)
- [x] Commit `da980c7a` exists — Task 2 (CONFIG_BOARDS + spec updates)
- [x] board-notice canary byte-stable (git diff shows no changes to snapshot files)
- [x] Both allowlists empty (comments only)
