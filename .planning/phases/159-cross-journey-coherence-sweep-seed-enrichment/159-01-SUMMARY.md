---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
plan: "01"
subsystem: ui
tags: [admin, liverview, components, organization, member-roster, deletion-scheduled]

# Dependency graph
requires: []
provides:
  - "deletion_scheduled? boolean field in member_row type and shape_member_row/1 (detail.ex)"
  - "Roster deletion-scheduled pill in organization_live.ex (data-tone=warn)"
  - "Expanded format_date/1 in organization_live.ex (DateTime + NaiveDateTime + nil + catch-all)"
  - "notice/1 in components.ex wraps slot in <div> not <p>"
affects:
  - "159-02 (coherence sweep may reference deletion pill layout)"
  - "159-03 (seed enrichment adds deleted_at to trigger the pill)"
  - "159-04 (Playwright assertions verify pill presence)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "host-struct safety: Map.get/2 over direct field access for derived booleans on host user struct"
    - "roster pill ordering: role → locked → deletion_scheduled → confirmed → unconfirmed"
    - "notice/1 uses <div> not <p> for slot wrapper to allow block-level slot content"

key-files:
  created: []
  modified:
    - lib/sigra/admin/organizations/detail.ex
    - lib/sigra/admin/live/organization_live.ex
    - lib/sigra/admin/components.ex

key-decisions:
  - "Use Map.get(user, :deleted_at) not user.deleted_at in shape_member_row/1 for host-struct safety on older installs"
  - "Keep format_date/1 in organization_live.ex as date-only (%Y-%m-%d), no HH:MM — separate from components.ex version"
  - "notice/1 <p>→<div> is safe because all 3 call sites pass only inline text (confirmed in RESEARCH.md)"

patterns-established:
  - "Deletion-scheduled pill uses data-tone=warn and text 'Deletion scheduled' (same as users_index_live.ex)"
  - "format_date/1 four-clause pattern: DateTime, NaiveDateTime, nil, catch-all returning em-dash"

requirements-completed:
  - FIXT-02

# Metrics
duration: 15min
completed: 2026-06-04
---

# Phase 159 Plan 01: Org-roster deletion pill + notice/1 div fix + NaiveDateTime format_date

**Three targeted lib-owned code fixes: deletion_scheduled? field in org member roster, NaiveDateTime safety in format_date/1, and notice/1 HTML correctness via <p>-to-<div> swap**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-04T00:00:00Z
- **Completed:** 2026-06-04T00:15:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added `deletion_scheduled?: boolean()` to `@type member_row` and derived it via `Map.get(user, :deleted_at)` in `shape_member_row/1` — host-struct safe for older installs missing the field
- Added roster deletion-scheduled pill after the Locked pill in organization_live.ex (`data-tone="warn"`, text "Deletion scheduled") — mirrors users_index_live.ex:355 exactly
- Expanded `format_date/1` in organization_live.ex from 2 clauses to 4: DateTime, NaiveDateTime, nil, catch-all — NaiveDateTime inputs no longer silently render "—"
- Fixed `notice/1` in components.ex: slot wrapper changed from `<p class="sg-text-sm">` to `<div class="sg-text-sm">` eliminating nested-block-in-p HTML invalidity hazard

## Task Commits

Each task was committed atomically:

1. **Task 1: Add deletion_scheduled? to detail.ex shape_member_row/1** - `8fbeedc0` (feat)
2. **Task 2: Add roster deletion pill to organization_live.ex + expand format_date/1** - `75be3bae` (feat)
3. **Task 3: Fix notice/1 nested-p hazard in components.ex** - `81eeeb57` (fix)

## Files Created/Modified
- `lib/sigra/admin/organizations/detail.ex` - Added `deletion_scheduled?: boolean()` to `@type member_row`; added `deletion_scheduled?: not is_nil(Map.get(user, :deleted_at))` to `shape_member_row/1`
- `lib/sigra/admin/live/organization_live.ex` - Added deletion-scheduled pill in roster template; expanded `format_date/1` to 4 clauses including NaiveDateTime
- `lib/sigra/admin/components.ex` - Changed `notice/1` slot wrapper from `<p>` to `<div>`

## Decisions Made
- Used `Map.get(user, :deleted_at)` (not `user.deleted_at`) in `shape_member_row/1` for host-struct safety — consistent with all other derived booleans in the function
- Kept `format_date/1` in organization_live.ex as date-only (`%Y-%m-%d`) — the shared `components.ex` version includes time, which would be a visual regression here
- Did not add `ArgumentError` raise to local `format_date/1` catch-all — maintains existing "silent fallback to —" contract of this file

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Deps not yet fetched in worktree (fresh worktree); ran `mix deps.get` before compile verification. Compilation clean after deps fetch.
- No live Postgres DB in worktree environment; `mix test` was verified to compile cleanly ("Generated sigra app") but DB-dependent test execution requires a running Postgres.

## Known Stubs

None — all three changes wire live data. The deletion pill will silently not render until Plan 03 adds `deleted_at` to seed data (by design: `deletion_scheduled?` is `false` when `deleted_at` is nil, which is correct behavior).

## Next Phase Readiness
- Code side of FIXT-02 complete: data shape (detail.ex) + template (organization_live.ex) both updated
- Plan 03 provides the seed data (`deleted_at` on a seed user) to trigger the pill
- Plan 04 provides the Playwright assertion that verifies the pill renders
- notice/1 fix is immediately live for all 3 call sites (organization_live, index_live, user_show_live)

---
*Phase: 159-cross-journey-coherence-sweep-seed-enrichment*
*Completed: 2026-06-04*
