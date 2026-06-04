---
phase: 157-overview-landings-highest-effort
plan: "02"
subsystem: admin-ui
tags: [live-view, overview, deferred-load, accessibility, skeleton, archetype]
dependency_graph:
  requires: []
  provides:
    - org-overview-connected-gate
    - org-overview-front-door-archetype
    - admin-design-contract-phase-157
  affects:
    - lib/sigra/admin/live/organization_live.ex
    - guides/reference/admin-design-contract.md
tech_stack:
  added: []
  patterns:
    - connected?(socket) deferred load gate in mount/3
    - skeleton shapes for three deferred data regions
    - inline alarm notice with role="status" opt-in
    - aria-busy on loading section container
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/organization_live.ex
    - guides/reference/admin-design-contract.md
decisions:
  - "Alarm content uses HEEx inline conditional (not raw/1) to pass inline text + <a> inside notice/1 slot — avoids nested-<p> (D-07)"
  - "locked_summary/1 removed since its only call site (Scoped attention card) was deleted"
  - "Five skeleton shapes in posture strip cluster match the five stat_links (Total/Confirmed/MFA/Passkeys/Locked)"
  - "Three skeleton shapes in Members section, two in Pending invitations — representative fixed counts per RESEARCH.md recommendation"
metrics:
  duration: "~6 minutes"
  completed: "2026-06-04"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 2
---

# Phase 157 Plan 02: Org Overview Redesign — Front-Door Archetype + Deferred Load Summary

## One-liner

Org Overview split to connected?-gate mount, "Scoped attention" card deleted (D-07 fold), alarm `<.notice tone={:risk|:ok}>` promoted above the task grid, five posture strip skeletons + three members + two invitations skeletons for three deferred data regions.

## What Was Built

### Task 1: Split mount/3 with connected? gate (commit 3dc19797)

Replaced the synchronous `mount/3` in `lib/sigra/admin/live/organization_live.ex` (formerly lines 14-28) with a two-branch connected?-gate structure following the pattern from Landmine 5 and RESEARCH.md:

- `runtime_config!()`, `admin_scope`, and `organization_name/1` called BEFORE the gate (all safe pre-gate: no DB calls, raises fast on misconfiguration for both mounts)
- Base assigns (`sigra_config`, `organization_name`, `page_title`) assigned to socket before the gate
- Connected branch: calls all three queries inline (`Query.summary_counts/2`, `Detail.member_roster/2`, `Detail.pending_invitations/2`), assigns `loading: false`
- Disconnected branch: assigns `loading: true`, empty `summary_counts: %{}`, `members: []`, `pending_invitations: []` — no DB calls

### Task 2: Redesign render/1 — delete old card, front-door archetype, skeleton shapes (commit 23b482ed)

Rewrote `render/1` to implement the shared front-door archetype (D-04/D-05) with deferred load state (D-01/D-02):

**Deletions (hard-fail boundaries):**
- Entire "Scoped attention" card (old lines 59-84) — D-07 fold, removes the nested-`<p>` `<.notice>` at old lines 73-78
- `sg-posture-strip__risk` anchor block (old lines 86-94) — Landmine 4

**New archetype order (LAND-01/02/03):**
1. `<header class="sg-page-header">` — unchanged content
2. `<.notice :if={not @loading} tone={:risk|:ok} role="status">` — alarm, first child after header, inline content only (D-07, Landmine 1, Landmine 3)
3. `<div class="sg-grid sg-grid--2">` — task_card grid (primary content)
4. `<section class="sg-card sg-posture-strip ...">` with `aria-busy={if @loading, do: "true"}` — 5 skeletons when loading, 5 stat_links when loaded (D-02, Landmine 8)
5. Members section (Org-only demoted tail, D-05) — 3 skeletons when loading, existing list/empty when loaded
6. Pending invitations section (Org-only demoted tail, D-05) — 2 skeletons when loading, existing list/empty when loaded

Also removed `locked_summary/1` helper (only caller was the deleted Scoped attention card).

### Task 3: Update admin-design-contract.md Overview Archetype (commit faac46f0)

Updated the "Overview Archetype" section in `guides/reference/admin-design-contract.md` (lines 135-167):

1. Replaced old "Current component composition" code block with the Phase 157 archetype showing the new canonical order (alarm before task grid, posture strip with `aria-busy`, Org tail below shared archetype)
2. Added Org-variant note: "Items 1–4 are byte-coherent across Global and Org Overviews. Org appends a demoted scoped-detail tail..."
3. Replaced stale Notes block: removed "Document current state" note about sg-posture-strip__risk; replaced with current-state notes on inline-only alarm, D-07 enforcement, and deferred load pattern

## Verification Results

All plan verification checks pass:

| Check | Result |
|-------|--------|
| `mix test test/example/test/example_web/admin_shell_test.exs` | 6 tests, 0 failures |
| `grep ... "sg-posture-strip__risk" \| grep -c` | 0 |
| `grep "Scoped attention\|Risk queue\|Evidence boundary" organization_live.ex` | empty |
| `grep "connected?(socket)" organization_live.ex` | match found |
| `grep "Org appends a demoted scoped-detail tail" admin-design-contract.md` | 1 match |
| `grep "organization_name" ... \| head -5` | `{@organization_name}` in `<h1>` confirmed |
| Full example app test suite (187 tests) | 0 failures |

## Deviations from Plan

### Auto-fixed Issues

None.

### Design Decisions Made During Execution

**1. HEEx inline conditional for alarm content**
- **Found during:** Task 2
- **Issue:** Plan spec showed content like `"N accounts need review — <a>Review now</a>"` but using `raw/1` with interpolated HTML would be unsafe and not idiomatic
- **Fix:** Used HEEx `<%= if @needs_review > 0 do %>` inside the notice slot to render inline text nodes + `<a href={...}>` — no block `<p>` children, fully inline, D-07 compliant
- **Files modified:** `lib/sigra/admin/live/organization_live.ex`

**2. locked_summary/1 removal**
- **Found during:** Task 2
- **Decision:** Removed the `locked_summary/1` private function since its only call site was the "Scoped attention" card being deleted — cleaner than leaving dead code that generates compiler warnings

## Known Stubs

None. All data flows are wired: connected branch runs real queries; disconnected branch assigns verified empty defaults. No placeholder text or hardcoded empty values that flow to UI rendering.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. The three DB queries are now only called on the connected (WebSocket) mount — a strictly more conservative load pattern than the previous synchronous-on-HTTP mount. All trust boundary mitigations from the plan's threat model are implemented as specified (T-157-02a through T-157-02d).

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `lib/sigra/admin/live/organization_live.ex` | FOUND |
| `guides/reference/admin-design-contract.md` | FOUND |
| `.planning/phases/157-overview-landings-highest-effort/157-02-SUMMARY.md` | FOUND |
| commit 3dc19797 (Task 1) | FOUND |
| commit 23b482ed (Task 2) | FOUND |
| commit faac46f0 (Task 3) | FOUND |
