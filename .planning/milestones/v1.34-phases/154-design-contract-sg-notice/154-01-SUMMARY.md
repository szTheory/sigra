---
phase: 154-design-contract-sg-notice
plan: "01"
subsystem: admin-ui-docs
tags: [documentation, exdoc, design-contract, admin-ui]
dependency_graph:
  requires: []
  provides: [guides/reference/admin-design-contract.md, mix.exs-exdoc-registration]
  affects: [phases-155-160-reference-authority]
tech_stack:
  added: []
  patterns: [exdoc-extras-registration, markdown-governance-doc]
key_files:
  created:
    - guides/reference/admin-design-contract.md
  modified:
    - mix.exs
decisions:
  - "Documented current reality only per D-07/D-08: no new design calls, no .sg-stat CSS invented, stat and scope_ribbon noted as Phase 155 COMP-01 targets"
  - "Inserted admin-design-contract.md immediately after generator-options.md in mix.exs extras: list; Reference ~r{guides/reference/.?} regex already covers new path"
metrics:
  duration: "2m"
  completed: "2026-06-03T23:07:49Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
requirements_satisfied: [COMP-03]
---

# Phase 154 Plan 01: Admin Design Contract doc + ExDoc registration Summary

Created `guides/reference/admin-design-contract.md`, a committed governance doc covering all 10 canonical admin components with job/markup/ARIA/motion/when-NOT-to-use tables and 3 page archetype compositions, registered in `mix.exs` ExDoc extras so it renders in hexdocs under the Reference group.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create admin-design-contract.md | `6dc373d9` | `guides/reference/admin-design-contract.md` |
| 2 | Register in mix.exs ExDoc extras | `e422b6b3` | `mix.exs` |

## What Was Built

### Task 1: Create admin-design-contract.md

Created `guides/reference/admin-design-contract.md` — the durable, citable authority for the Sigra admin UI component system satisfying requirement COMP-03. The document:

- Covers all 10 canonical components (stat_link, stat, task_card, summary_chip, applied_chip, empty_state, page_back, scope_ribbon, notice, skeleton) each with a property table containing: Job, Winning markup/CSS, ARIA role(s), Motion spec, When NOT to use
- Includes 9 explicit "not animated" motion spec entries (keyboards-frequent interactions per GATE-03 seed)
- Documents 3 page archetypes (Overview, List, Detail) as explicit component compositions from verified LiveView sources
- Records current reality only: no new design calls; `stat` and `scope_ribbon` documented as Phase 155 COMP-01 targets; no `.sg-stat` CSS class invented per D-07/D-08
- Notes all consolidation targets: `notice` currently uses `sg-list-row data-tone` (COHR-05 migration target); Identity card currently boxed (COHR-02 reconciliation target)

### Task 2: Register in mix.exs ExDoc extras

Added `"guides/reference/admin-design-contract.md"` to the `extras:` list in `mix.exs`, immediately after `"guides/reference/generator-options.md"` (line 198 → 199). The existing `groups_for_extras: [Reference: ~r{guides/reference/.?}]` regex at line 244 already covers the new path — no other changes needed. `mix docs` exits 0.

## Verification Results

| Check | Result |
|-------|--------|
| File exists at `guides/reference/admin-design-contract.md` | PASS |
| Section count ≥13 (`##` + `###` headings) | PASS (15) |
| All 10 components present | PASS |
| `## Job -> Component Mapping` heading present | PASS (1) |
| 3 archetype headings present | PASS (3) |
| Not animated entries ≥3 | PASS (9) |
| No `.sg-stat {` CSS class invented | PASS |
| ExDoc registration (exactly 1 hit in mix.exs) | PASS (1) |
| `generator-options.md` immediately precedes new entry | PASS |
| `mix docs` exit 0 | PASS |
| No LiveView files modified | PASS (empty diff) |
| No Playwright baselines changed | PASS (empty diff) |
| Only expected files changed (doc + mix.exs) | PASS |

## Deviations from Plan

None - plan executed exactly as written.

## Threat Surface Scan

No new attack surfaces introduced. Both deliverables are committed source artifacts (Markdown doc + one-line build config edit). No runtime paths, no secrets, no authentication logic, no network endpoints. The threat model accepted all risks as low per the plan's threat register.

## Self-Check: PASSED

- `guides/reference/admin-design-contract.md` exists: CONFIRMED
- Commit `6dc373d9` exists: CONFIRMED
- Commit `e422b6b3` exists: CONFIRMED
- No LiveView files modified: CONFIRMED (empty diff)
- `mix docs` exits 0: CONFIRMED
