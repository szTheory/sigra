---
phase: 189-page-compositions-l3
plan: "02"
subsystem: admin-live
tags: [admin-ui, ia-audit, pagination, overview-archetype, explorer-pages]
dependency_graph:
  requires: []
  provides: [Overview-IA-conformance, honest-pagination-audit-explorers]
  affects: [organization_live, audit_index_live, audit_user_live]
tech_stack:
  added: []
  patterns: [multi_page?-honest-pagination, PAGE-01-no-scope_ribbon-on-overview]
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/organization_live.ex
    - lib/sigra/admin/live/audit_index_live.ex
    - lib/sigra/admin/live/audit_user_live.ex
decisions:
  - Overview archetype does not render scope_ribbon — topbar sg-scope-pill is the scope signal; scope_ribbon is for list/leaf screens only (UI-SPEC L152)
  - multi_page?/1 guard is the canonical honest-pagination pattern; identical body across users_index_live, audit_index_live, and audit_user_live (D-09)
metrics:
  duration: "~3 minutes"
  completed: "2026-06-17T15:25:00Z"
  tasks_completed: 2
  files_modified: 3
---

# Phase 189 Plan 02: IA Audit + Honest Pagination on 5 Admin LiveViews Summary

Audit and correction of page-level IA ordering, vertical rhythm, landmark/heading order, and honest-pagination affordances on index_live, organization_live, users_index_live, audit_index_live, and audit_user_live against the L3 rubric. Two rubric violations found and fixed; three pages confirmed fully conformant.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Audit + fix Overview archetype pages | 7ebf970f | lib/sigra/admin/live/organization_live.ex |
| 2 | Audit List + PAGE-04 explorer IA and confirm honest pagination | 8832dc6e | lib/sigra/admin/live/audit_index_live.ex, lib/sigra/admin/live/audit_user_live.ex |

## Per-Page Rubric Evidence

### index_live.ex — Overview archetype (global)

| L3 Scorecard Row | Result | Evidence |
|------------------|--------|----------|
| Archetype conformance | PASS | header → notice → task-card grid → user-snapshot section; correct tasks-first, posture-second, KPIs-last IA |
| GOV.UK IA (general→specific, tasks-first) | PASS | alarm notice at position [2], task-card grid at [3], metric section last |
| Principle-of-least-surprise | PASS | Three primary task cards are the first interactive elements; no destructive actions |
| Vertical rhythm (sg-stack--6 between sections, no flush, no double-gap) | PASS | Outer `<section class="sg-stack sg-stack--6">` spaces all 4 children; no double-wrap; no adjacent sections without gap |
| Landmark/heading order (main, h1, h2, no skips) | PASS | `<main>` provided by admin shell (admin_shell.ex L250); single h1 at L41; h2 at L85 for "User snapshot"; no h3/h4 in file |
| No page_back | PASS | `grep -c 'page_back' index_live.ex` = 0 |
| No scope_ribbon | PASS | No scope_ribbon present; correct for Overview archetype |

**Verdict: conformant, no edit required.**

---

### organization_live.ex — Overview archetype (org-scoped instance, D-04)

| L3 Scorecard Row | Result | Evidence |
|------------------|--------|----------|
| Archetype conformance | FIXED | Prior: scope_ribbon between [1] header and [2] alarm notice broke IA order. Fixed: removed scope_ribbon |
| GOV.UK IA (general→specific, tasks-first) | PASS after fix | Alarm notice is now first child after header [2]; task-card grid [3]; member roster + invitations tail (capabilities-last) [4] |
| Principle-of-least-surprise | PASS | Two primary task cards first; member/invitation sections scoped capabilities last |
| Vertical rhythm | PASS | Outer `<section class="sg-stack sg-stack--6">` provides uniform spacing; inner sections use sg-stack--3 inside sg-card wrappers; no double-gap |
| Landmark/heading order | PASS | `<main>` from shell; single h1 (org name, L52); h2 "Members" (L92), h2 "Pending invitations" (L115); no skipped levels |
| No page_back | PASS | `grep -c 'page_back' organization_live.ex` = 0 |
| Org tail capabilities-last | PASS | member roster and pending invitations sections appear after [3] task-card grid |

**Rubric violation found and fixed:** scope_ribbon was at position [2] (between header and alarm notice), violating the PAGE-01 IA order which requires alarm notice at [2] directly after header. UI-SPEC L152 explicitly states scope_ribbon is for list/leaf screens only — the topbar sg-scope-pill is sufficient on Overview. The now-unused `scope_copy/1` private function was also removed to keep compile clean.

---

### users_index_live.ex — List archetype anchor (RATIFIED, no edit)

| L3 Scorecard Row | Result | Evidence |
|------------------|--------|----------|
| Archetype conformance | PASS | header+summary chips → scope ribbon → filter panel → applied chips → results (table/card) → empty state → pagination |
| Honest pagination | PASS (ratified) | `multi_page?/1` at L513-517; render guard at L359-390: all-results label shown when not multi_page?, nav only when multi_page? |
| multi_page? guard preserved | PASS | `grep -c 'defp multi_page?' users_index_live.ex` = 2 (nil clause + meta clause) |
| Landmark/heading order | PASS | h1 (L80), h2 "User health" (L92), h2 "Find users" (L153); no skipped levels |
| No page_back | PASS | No page_back component present |

**Verdict: conformant, no edit required. multi_page?/1 preserved exactly as ratified.**

---

### audit_index_live.ex — PAGE-04 explorer (filter/results/export)

| L3 Scorecard Row | Result | Evidence |
|------------------|--------|----------|
| Explorer IA (filter first, results second, export/actions last) | PASS | filter panel → applied chips → results table/card → empty state → pagination |
| Honest pagination | FIXED | Prior: `<nav :if={@meta}>` showed nav on single-page results (phantom "page 1 of 1"). Fixed: `<nav :if={@meta && multi_page?(@meta)}>` hides nav entirely when one page |
| multi_page? guard | ADDED | `defp multi_page?(nil), do: false` + `defp multi_page?(meta)` with total_pages/previous_page/next_page check (L305-309) |
| Landmark/heading order | PASS | h1 "Audit" at L54; no h2 needed (bespoke explorer, not a sectioned page); no skipped levels |
| No page_back | PASS | No page_back present |
| Mobile table→card swap | PASS | Desktop `sg-show-desktop` table + mobile `sg-show-mobile` cards at L148-203; content-equivalent |

**Guard pattern (exact expression, L216):** `<nav :if={@meta && multi_page?(@meta)} class="sg-cluster sg-cluster--between">`

---

### audit_user_live.ex — PAGE-04 explorer-leaf (per-user audit)

| L3 Scorecard Row | Result | Evidence |
|------------------|--------|----------|
| Explorer IA (filter first, results second, export/actions last) | PASS | filter panel → applied chips → results table/card → empty state → pagination |
| Honest pagination | FIXED | Prior: `<nav :if={@meta}>` — same phantom nav issue. Fixed: `<nav :if={@meta && multi_page?(@meta)}>` |
| multi_page? guard | ADDED | `defp multi_page?(nil), do: false` + `defp multi_page?(meta)` at L471-475 |
| Breadcrumb return context (not page_back) | PASS | `admin_breadcrumbs` computed in handle_params (L44/59) via `audit_breadcrumbs/3` building [Overview → Users → user email → Audit]; shell renders it as `<ol class="sg-breadcrumb">` |
| No page_back | PASS | `grep -c 'page_back' audit_user_live.ex` = 0 |
| Landmark/heading order | PASS | h1 at L71 (display name or email); no skipped heading levels |
| Mobile table→card swap | PASS | Desktop `sg-show-desktop` + mobile `sg-show-mobile` cards; content-equivalent |

**Guard pattern (exact expression, L246):** `<nav :if={@meta && multi_page?(@meta)} class="sg-cluster sg-cluster--between">`

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] scope_ribbon placement in organization_live broke PAGE-01 IA order**
- **Found during:** Task 1
- **Issue:** `<.scope_ribbon>` was rendered between the page header and the alarm notice, pushing the alarm notice to position [3] instead of [2]. The Overview archetype IA contract requires alarm notice at [2] directly after the header. Additionally, UI-SPEC L152 explicitly states scope_ribbon is reserved for list/leaf screens only — the topbar sg-scope-pill is the scope signal on Overview pages.
- **Fix:** Removed `<.scope_ribbon copy={scope_copy(@admin_scope)} />` from organization_live.ex render; removed the now-unused `scope_copy/1` private function; added explanatory comment referencing UI-SPEC L152.
- **Files modified:** lib/sigra/admin/live/organization_live.ex
- **Commit:** 7ebf970f

**2. [Rule 1 - Bug] Phantom pagination navs on both audit explorer pages**
- **Found during:** Task 2
- **Issue:** Both `audit_index_live.ex` and `audit_user_live.ex` used `<nav :if={@meta}>` which renders the pagination nav whenever meta is non-nil — including when all results fit on one page (e.g., 5 results, page_size 25). This produces a "Page 1" display with disabled prev/next controls — the phantom affordance the D-09 / must_have truth explicitly prohibits.
- **Fix:** Changed nav `:if` guard to `@meta && multi_page?(@meta)` on both files; added `multi_page?/1` private function (identical body to users_index_live.ex L513-517) to each file.
- **Files modified:** lib/sigra/admin/live/audit_index_live.ex, lib/sigra/admin/live/audit_user_live.ex
- **Commit:** 8832dc6e

## Known Stubs

None. All pages render real data from context/assigns; no hardcoded empty values or placeholder text were introduced.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes were introduced. Changes are page-local markup/IA corrections only, consistent with the T-189-05/T-189-06/T-189-07 disposition in the plan's threat model.

## Self-Check: PASSED

Files confirmed:
- lib/sigra/admin/live/organization_live.ex: FOUND (modified)
- lib/sigra/admin/live/audit_index_live.ex: FOUND (modified)
- lib/sigra/admin/live/audit_user_live.ex: FOUND (modified)

Commits confirmed:
- 7ebf970f: FOUND (fix organization_live scope_ribbon)
- 8832dc6e: FOUND (fix audit explorer honest pagination)

Compile: `mix compile --warnings-as-errors` exits 0 (verified with MIX_DEPS_PATH pointing at main repo deps).
