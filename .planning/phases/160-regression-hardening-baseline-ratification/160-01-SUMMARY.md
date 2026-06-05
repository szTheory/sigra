---
phase: 160-regression-hardening-baseline-ratification
plan: 01
subsystem: ui
tags: [admin, dark-mode, wcag, css, liveview, filter]

requires:
  - phase: 159
    provides: NaiveDateTime head in organization_live.ex format_date/1 (D-08 prereq)

provides:
  - Dark-mode --sg-color-brand-strong WCAG-AA CSS override (#fdba74) in app.css dark :root block
  - lib/sigra/admin.ex with public needs_review/1 shared helper
  - All ?locked=true alarm/card hrefs replaced with ?needs_review=true in index_live.ex and organization_live.ex
  - :needs_review OR-filter clause in query.ex (locked_at IS NOT NULL OR deleted_at IS NOT NULL)
  - "needs_review" added to @quick_filter_keys and chip_label in users_index_live.ex
  - D-08 verify-only confirmations: notice/1 div.sg-text-sm wrapper, NaiveDateTime head in format_date/1

affects:
  - 160-02 (parity lane relies on correct filter semantics)
  - 160-03 (dark baseline re-records consume the brand-strong CSS fix)
  - 160-04 (milestone audit cites D-06 and D-07 fixes as closed)

tech-stack:
  added: []
  patterns:
    - "Shared admin utilities extracted to lib/sigra/admin.ex (module-level, not defp)"
    - "OR-filter semantic via or_where for needs_review; AND-filter keys stay separate"

key-files:
  created:
    - lib/sigra/admin.ex
  modified:
    - test/example/priv/static/assets/css/app.css
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
    - lib/sigra/admin/users/query.ex
    - lib/sigra/admin/live/users_index_live.ex

key-decisions:
  - "D-06: --sg-color-brand-strong override placed in unlayered dark :root block (established token foundation, not a component rule)"
  - "D-07: Fix the LINK not the count; introduce needs_review OR-filter key so alarm reconciles without visible text change"
  - "IN-03: Extract needs_review/1 to Sigra.Admin module; remove local defp from both LiveViews"

patterns-established:
  - "Shared admin utilities live in lib/sigra/admin.ex, not as private defp in individual LiveViews"
  - "OR-filter semantics use or_where/2; false-value clause is pass-through (not an AND-negation)"

requirements-completed:
  - GATE-01

duration: 15min
completed: 2026-06-05
---

# Phase 160 Plan 01: Regression Hardening — D-06/D-07/D-08 Summary

**Dark WCAG-AA CSS fix (#fdba74 brand-strong override), needs-review OR-filter with reconciled alarm links, and shared Sigra.Admin helper extraction**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-05T13:42:00Z
- **Completed:** 2026-06-05T13:57:00Z
- **Tasks:** 3 (Tasks 1-3)
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments

- Fixed dark-mode WCAG-AA contrast gap: `--sg-color-brand-strong` now overrides to `#fdba74` in the dark `:root` block, covering all brand-soft+brand-strong surfaces (scope-pill, scope-switch, nav-link, badge--brand, breadcrumb, filter chip)
- Fixed D-07 alarm count/link mismatch: all three alarm/card hrefs in `index_live.ex` and both in `organization_live.ex` now point to `?needs_review=true`; `query.ex` has an OR-filter clause so the deep-link destination matches the counted set (locked OR deleted)
- Extracted byte-identical `needs_review/1` defp from both LiveViews into a shared `Sigra.Admin.needs_review/1` public function (IN-03)
- Confirmed D-08 verify-only: `notice/1` wraps slot in `div.sg-text-sm` (not `p`); `format_date/1` in `organization_live.ex` has `%NaiveDateTime{}` head — both already resolved, no unexpected regression

## Task Commits

1. **Task 1: Dark brand-strong CSS override + Sigra.Admin shared helper** - `36bc1cf7` (feat)
2. **Task 2: D-07 needs-review link + filter fix** - `e0df0f3c` (fix)
3. **Task 3: D-08 verify-only** — no code changes; both assertions confirmed holding

## Files Created/Modified

- `lib/sigra/admin.ex` — New shared admin utilities module with public `needs_review/1`
- `test/example/priv/static/assets/css/app.css` — Added `--sg-color-brand-strong: #fdba74` to dark `:root` block; removed redundant scoped chip color rule
- `lib/sigra/admin/live/index_live.ex` — 3 hrefs updated to `?needs_review=true`; local `defp needs_review/1` removed; calls `Sigra.Admin.needs_review/1`
- `lib/sigra/admin/live/organization_live.ex` — 2 hrefs updated to `?needs_review=true`; same dedup as index_live.ex
- `lib/sigra/admin/users/query.ex` — Added `:needs_review` `apply_filter` clause using `or_where` for locked OR deleted union
- `lib/sigra/admin/live/users_index_live.ex` — Added `"needs_review"` to `@quick_filter_keys`; added `chip_label("needs_review", nil)` -> `"Needs review"` clause

## Decisions Made

- CSS token override for `--sg-color-brand-strong` placed inside the existing unlayered dark `:root` block — this is the established token foundation, not a component rule violation. The "all CSS in @layer sg-components" rule governs component rules, not `:root` token declarations.
- Chip dark override kept as an empty block with updated comment (not removed entirely) to preserve the block structure and comment explaining why the rule is now superseded by the global token.
- `needs_review` OR-filter uses `or_where/2` so it correctly returns the union of locked+deleted; the `false` value clause is a pass-through (no restriction on "not needs_review" view).

## Deviations from Plan

None — plan executed exactly as written.

## D-08 Confirmation

- **org-notice-nested-p:** `notice/1` in `components.ex:306` wraps slot in `<div class="sg-text-sm">` — confirmed no `<p>` wrapper. 19/19 component tests pass.
- **admin-format-date-naivedatetime:** `organization_live.ex:194` has `defp format_date(%NaiveDateTime{} = ndt)` head above the nil/fallback heads — confirmed present.

Both D-08 todos closed as resolved.

## Issues Encountered

None. Pre-existing Chimeway.Repo connection noise in test output is unrelated to this plan.

## Next Phase Readiness

- Dark baseline re-records (Plan 03) can now proceed — the `--sg-color-brand-strong` CSS fix is the intended delta that causes dark checkpoint re-records
- Parity lane (Plan 02) can verify `?needs_review=true` filter through the generated admin path
- All three alarm/card deep-links in both overview LiveViews are now semantically correct

---

## Self-Check: PASSED

Files confirmed present:
- `lib/sigra/admin.ex` — FOUND
- `test/example/priv/static/assets/css/app.css` contains `--sg-color-brand-strong: #fdba74` — FOUND

Commits confirmed:
- `36bc1cf7` (Task 1) — FOUND
- `e0df0f3c` (Task 2) — FOUND

mix test test/sigra/admin/ — 74 tests, 0 failures
mix test test/sigra/admin/components_test.exs — 19 tests, 0 failures
mix compile --no-optional-deps — clean (no warnings or errors)

---
*Phase: 160-regression-hardening-baseline-ratification*
*Completed: 2026-06-05*
