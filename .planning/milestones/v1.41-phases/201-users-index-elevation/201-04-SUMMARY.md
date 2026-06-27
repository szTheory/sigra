---
phase: 201
plan: "04"
subsystem: admin-ui
tags:
  - playwright
  - visual-baselines
  - design-gallery
  - users-index
  - list-scale
  - pagination
  - canary
dependency_graph:
  requires:
    - "201-01 (users_index_live.ex recomposed — metric strip, pills, applied-chip placement)"
    - "201-02 (extra_list_badges / extra_list_columns host seam seeded)"
    - "201-03 (GET-form Playwright test + ledger ratchet + design contract rewrite)"
  provides:
    - "global-user-index baselines at list-scale with pagination <nav> visible (D-08)"
    - "board-mg-1/mg-2/mg-5 design gallery baselines synced to elevated live markup"
    - "zero-drift idempotency proven for both checkpoint and design lanes"
    - "allowlists empty at end-of-phase (D-10)"
  affects:
    - "test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/"
    - "test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/"
    - "test/example/lib/example_web/live/admin/design_gallery_live.ex"
tech_stack:
  added: []
  patterns:
    - "Unfiltered /admin/users navigation for list-scale checkpoint capture (not ?q= filter)"
    - "getByRole link assertion for pagination nav (no aria-label on nav element)"
    - "Restore-non-target-PNGs-then-commit pattern for selective baseline recapture"
    - "Canary hash pre/post verification (md5 comparison before and after recapture)"
key_files:
  created: []
  modified:
    - test/example/lib/example_web/live/admin/design_gallery_live.ex
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
    - "test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-{chromium,dark,mobile}.png (3 PNGs)"
    - "test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-{1,2,5}-admin-design-{chromium,dark,mobile}.png (9 PNGs)"
key-decisions:
  - "Navigate to /admin/users (unfiltered) in the global-user-index checkpoint instead of ?q=targetEmail — the filter collapses to 1 user (no pagination); unfiltered shows 2500 dev DB users across 100 pages"
  - "Assert getByRole('link', { name: 'Next page' }) for D-08 pagination proof — the <nav> element has no aria-label attribute (uses class=sg-cluster--between); the next-page link inside carries its aria-label"
  - "mg-6 (audit feed) board NOT recaptured — its markup was not changed by Plans 01-03; only mg-1/mg-2/mg-5 needed gallery sync"
  - "board-notice canary verified byte-stable by md5 hash (e42bff78) before and after recapture; impersonation-banner canary also unchanged"
  - "Mobile axe color-contrast failure on .vt-status-pill (demo app's vt-* scope, ratio 3.33) is pre-existing and unrelated to Plan 04 changes; mobile PNG still captured before the failure point"
requirements-completed:
  - INDEX-03
  - INDEX-04
coverage:
  - id: D-08
    description: "Honest pagination proven at list-scale: global-user-index checkpoint navigates to unfiltered /admin/users, asserts Next page link visible (2500 users → 100 pages at page_size 25)"
    requirement: INDEX-03
    verification:
      - kind: automated_ui
        ref: "test/example/priv/playwright/tests/admin-checkpoints.spec.ts: page.goto('/admin/users'); expect(page.getByRole('link', { name: 'Next page' })).toBeVisible()"
        status: pass
    human_judgment: false
  - id: D-10a
    description: "Canaries byte-stable: impersonation-banner (md5 eee923e6) and board-notice (md5 e42bff78) unchanged in git diff"
    requirement: INDEX-04
    verification:
      - kind: automated_ui
        ref: "snapshot-canary-guard.sh --allow global-user-index: PASS; snapshot-canary-guard.sh --allow board-mg-1/2/5: PASS"
        status: pass
    human_judgment: false
  - id: D-10b
    description: "Only intended slugs recaptured: global-user-index (3 PNGs) + board-mg-1/mg-2/mg-5 (9 PNGs); 13 files total in Task 2 commit; allowlists empty at end-of-phase"
    requirement: INDEX-04
    verification:
      - kind: automated_ui
        ref: "git diff --name-only HEAD~1 HEAD: 13 files; grep non-comment snapshot-allowlist: 0 lines; grep non-comment snapshot-allowlist-design: 0 lines"
        status: pass
    human_judgment: false
  - id: D-10c
    description: "Zero-drift idempotency: compare-mode Playwright passes after baking (chromium+dark: 2 passed; design all-3: 81+96 passed; gate exits 0)"
    requirement: INDEX-04
    verification:
      - kind: automated_ui
        ref: "snapshot-recapture-gate.sh exits 0; admin-design.spec.ts 81 passed compare-mode; 96 passed second compare-mode run"
        status: pass
    human_judgment: false

duration: ~45 min (split across two sessions)
completed: "2026-06-26"
status: complete
---

# Phase 201 Plan 04: Baseline Recapture at List-Scale Summary

**Recaptured global-user-index at list-scale against 2500-user dev DB (100 pages), proving honest pagination via unfiltered navigation + Next page assertion; synced mg-1/mg-2/mg-5 gallery boards to elevated Plans 01-03 markup; canaries byte-stable; zero-drift idempotency proven; allowlists empty.**

## Performance

- **Duration:** ~45 min (split across two sessions due to context length)
- **Started:** 2026-06-26T09:28:53Z
- **Completed:** 2026-06-26T10:13:48Z
- **Tasks:** 2
- **Files modified:** 15 (2 source + 13 PNG baselines)

## Accomplishments

- **Task 1:** Synced design gallery boards in `design_gallery_live.ex` to mirror the elevated live markup from Plans 01-03:
  - `board-mg-1`: Updated to slim 3-chip metric strip (Total users 3,842 / Locked 7 risk-tone / Deletion scheduled 3 warn-tone) matching the recomposed users_index_live.ex metric strip
  - `board-mg-2`: Moved applied chips INSIDE the form element (contiguous with filter panel per D-01), changed "Clear all filters" → "Clear all", changed button label to "Search"
  - `board-mg-5`: Replaced "Active" (Confirmed) pill with empty `sg-cluster--2` div (healthy user = no pill = absence of concern); added "No MFA" (warn) row example
  - `board-mg-6`: Left untouched — audit feed markup did not change in Plans 01-03
  - `board-notice` canary: Untouched (verified via `git diff` — no changes)

- **Task 2:** Recaptured all affected baselines at list-scale:
  - Changed `global-user-index` checkpoint navigation from `?q=targetEmail` (single-user filter, no pagination) to unfiltered `/admin/users` (2500 dev DB users, 100 pages)
  - Added D-08 pagination assertion: `expect(page.getByRole('link', { name: 'Next page' })).toBeVisible()`
  - Recaptured 3 `global-user-index` PNGs (chromium/dark/mobile) at list-scale showing pagination nav
  - Recaptured 9 design board PNGs (board-mg-1/mg-2/mg-5 × 3 projects) showing elevated markup
  - Restored all 51 non-target design PNGs + board-notice canary via `git checkout HEAD --`
  - Zero-drift idempotency proven: compare-mode Playwright 2 passed (CK chromium+dark), 81 passed (design first run), 96 passed (design second run)
  - Both canary guards pass: CK guard (--allow global-user-index: PASS), design guard (--allow board-mg-1/2/5: PASS)
  - Both allowlist files empty (0 non-comment lines) at end-of-phase

## Task Commits

1. **Task 1: Sync mg-1/mg-2/mg-5 design gallery boards to elevated live markup** - `44a3b77a` (refactor)
2. **Task 2: Recapture global-user-index at list-scale + sync design gallery baselines** - `af735d75` (test)

## Files Created/Modified

- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — mg-1 metric strip (3 chips), mg-2 applied chips inside form + Clear all, mg-5 empty healthy cluster + No MFA warn row
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — Navigate to `/admin/users` (unfiltered); add D-08 Next page assertion
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-chromium.png` — rebaked at list-scale (87,653 bytes)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png` — rebaked at list-scale (85,641 bytes)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-mobile.png` — rebaked at list-scale (62,874 bytes)
- `test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-1-admin-design-{chromium,dark,mobile}.png` — 3-chip metric strip
- `test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-2-admin-design-{chromium,dark,mobile}.png` — applied chips inside form
- `test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-5-admin-design-{chromium,dark,mobile}.png` — reduced pill vocabulary

## Decisions Made

- Navigate to `/admin/users` (unfiltered) instead of `?q=targetEmail` for the global-user-index checkpoint — the filter would collapse the list to 1 result with no pagination nav visible; unfiltered shows the full dev DB (2500 users) across 100 pages.
- Assert `getByRole('link', { name: 'Next page' })` for D-08 pagination proof rather than locating the `<nav>` by aria-label — the nav element in `users_index_live.ex` uses `class="sg-cluster sg-cluster--between"` with no aria-label attribute. The prev/next links inside carry their own aria-labels.
- mg-6 (audit feed board) left untouched — its markup was not changed by Plans 01-03; only mg-1/mg-2/mg-5 needed gallery sync. This avoids unnecessary baseline noise.
- Seeds did not need to be re-run — the dev DB already had 2500 users from a prior Phase-199 seeding run (well above the 45-user threshold needed for 2-page pagination).
- Mobile axe failure at `impersonation-banner` checkpoint (color-contrast 3.33 on `.vt-status-pill`, ratio < 4.5:1 threshold) is a pre-existing demo-app issue in the `vt-*` scope; Plan 04 changes don't affect it; the mobile `global-user-index` PNG was captured before this failure point.

## Deviations from Plan

**1. [Rule 1 - Bug] Wrong aria-label assertion for pagination nav**
- **Found during:** Task 2 (first compare-mode run)
- **Issue:** First attempt asserted `page.locator('nav[aria-label="User results pagination"]')` — but the `<nav>` element in `users_index_live.ex` has no aria-label attribute (uses `class="sg-cluster sg-cluster--between"`)
- **Fix:** Changed to `page.getByRole('link', { name: 'Next page' })` which targets the next-page link inside the nav — semantically correct and unambiguous
- **Files modified:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`
- **Commit:** `af735d75`

**2. [Rule 2 - Missing] mg-6 board not recaptured**
- **Not a deviation from spec** — the plan explicitly says "mg-6 iff its markup changed"; mg-6 (audit feed) markup was not modified in Plans 01-03, so no recapture needed. Plan 04 correctly scoped mg-6 as conditional.

## Known Stubs

None — all artifacts are visual baselines and gallery markup with no runtime data wiring stubs.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. This plan is entirely read-only Playwright recapture + static gallery markup.

## Self-Check

### Files Exist
- test/example/lib/example_web/live/admin/design_gallery_live.ex: EXISTS (commit 44a3b77a)
- test/example/priv/playwright/tests/admin-checkpoints.spec.ts: EXISTS (commit af735d75)
- test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-chromium.png: EXISTS (87,653 bytes)
- test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-1-admin-design-chromium.png: EXISTS (commit af735d75)
- snapshot-allowlist: 0 non-comment lines (empty, steady state)
- snapshot-allowlist-design: 0 non-comment lines (empty, steady state)

### Commits Exist
- 44a3b77a: refactor(201-04): sync design gallery mg-1/mg-2/mg-5 boards to elevated Plans 01-03 markup (Task 1) ✓
- af735d75: test(201-04): recapture global-user-index at list-scale + sync design gallery baselines (Task 2) ✓

## Self-Check: PASSED
