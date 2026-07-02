---
phase: 199-foundation-tier-2-scorecard-stress-fixtures
plan: "04"
subsystem: testing
tags: [playwright, admin-ui, audit, pagination, fixtures, e2e]

# Dependency graph
requires:
  - phase: 199-03
    provides: "Seeded admin@demo.tasklane.test with >=25 audit events and 36-user bulk cohort (FIXT-01, FIXT-02)"
provides:
  - "Un-skipped MG-5/MG-6 content-equivalence test passing against >=25-event seeded fixture (FIXT-01 behaviorally proven)"
  - "Both snapshot allowlists reset to empty steady-state (D-15)"
  - "Tracked admin-design-mg5-6-content-equivalence-data-dependent todo resolved"
affects:
  - 200-admin-ui
  - 204-snapshot-recapture

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deterministic seed targeting in Playwright: use ?q=<email> URL filter to pin test navigation to a known-sufficient fixture user rather than relying on insertion-order first-row heuristics"

key-files:
  created: []
  modified:
    - "test/example/priv/playwright/tests/admin-design.spec.ts"

key-decisions:
  - "Filter /admin/users to admin@demo.tasklane.test via ?q= rather than take first-listed row — users index orders by inserted_at DESC and the harness login user is always newest with only ~3 events"
  - "Zero PNG baselines moved — content-equivalence test asserts structure/text, not pixels, so no recapture was needed (confirmed empirically, Task 2 finding)"

patterns-established:
  - "Seed-dependent Playwright assertions must target fixture users deterministically (URL query filter) rather than relying on index ordering — index ordering is an implementation detail that harness login users pollute"

requirements-completed: [FIXT-01]

coverage:
  - id: D1
    description: "MG-5/MG-6 content-equivalence test un-skipped and passing — desktop/mobile representation equivalence proven for admin users list and per-user audit (FIXT-01)"
    requirement: FIXT-01
    verification:
      - kind: automated_ui
        ref: "test/example/priv/playwright/tests/admin-design.spec.ts#MG-5 and MG-6 desktop and mobile representations are content-equivalent"
        status: pass
    human_judgment: false
  - id: D2
    description: "Per-user audit pagination (Previous page / Next page) renders when seeded admin has >=25 audit events"
    requirement: FIXT-01
    verification:
      - kind: automated_ui
        ref: "test/example/priv/playwright/tests/admin-design.spec.ts#MG-5 and MG-6 desktop and mobile representations are content-equivalent"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both snapshot allowlists (snapshot-allowlist, snapshot-allowlist-design) are empty/comments-only at end-of-phase (D-15)"
    verification:
      - kind: other
        ref: "grep -vE '^\\s*#|^\\s*$' test/example/priv/playwright/snapshot-allowlist — returns empty"
        status: pass
    human_judgment: false
  - id: D4
    description: "Tracked todo .planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md resolved to todos/resolved/"
    verification:
      - kind: other
        ref: "test -f .planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md — file absent"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-06-25
status: complete
---

# Phase 199 Plan 04: Un-Skip Content-Equivalence Test Summary

**MG-5/MG-6 content-equivalence test un-skipped and passing via deterministic ?q= seed-admin URL filter, proving >=25-event audit pagination renders (FIXT-01, D-13/D-15)**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-25T00:00:00Z
- **Completed:** 2026-06-25T00:25:00Z
- **Tasks:** 4 (1–3 completed in prior executor; Task 4 human-verify ran, found defect, this executor applied fix)
- **Files modified:** 1

## Accomplishments

- Un-skipped MG-5/MG-6 content-equivalence test in admin-design.spec.ts and fixed a real defect found during human verification
- Per-user audit pagination assertion now deterministically targets admin@demo.tasklane.test (>=25 events) instead of the harness-login user (newest, ~3 events only)
- Zero PNG baselines moved — the test asserts DOM structure/text, not pixels; no recapture was needed
- Both allowlists confirmed empty (comments-only); tracked todo confirmed in resolved/
- content-equivalence test passes: 1 passed (7.0s)

## Task Commits

Each task was committed atomically:

1. **Task 1: Un-skip MG-5/MG-6 content-equivalence test** - `6e6d9936` (feat)
2. **Task 2: Empirical blast radius — zero PNG moved, no recapture needed** - (no commit; confirmed empirically, documented)
3. **Task 3: Reset allowlists to empty, resolve todo** - `c2940a45` (chore)
4. **Task 4 defect fix: Target seeded >=25-event admin in per-user audit pagination assertion** - `bcbbfad5` (fix)

## Files Created/Modified

- `test/example/priv/playwright/tests/admin-design.spec.ts` — Un-skipped content-equivalence test; replaced `goto('/admin/users')` before per-user audit assertion with `goto('/admin/users?q=admin%40demo.tasklane.test')` to deterministically target the seeded >=25-event admin

## Decisions Made

- **Deterministic seed targeting via ?q= URL filter:** Rather than relying on the users index ordering (inserted_at DESC), the test now filters the page to the seeded admin using the search form's `?q=` parameter. This makes the assertion immune to harness-login user ordering pollution.
- **No PNG recapture:** Empirically confirmed zero baseline drift — content-equivalence test asserts only DOM structure/text equivalence between desktop and mobile representations, never makes pixel/screenshot assertions. Canaries (impersonation-banner, board-notice) byte-stable.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed per-user audit pagination assertion targeting wrong user**

- **Found during:** Task 4 human-verify gate — the human ran the un-skipped test and it FAILED
- **Issue:** The plan's assumption that "admin stays first-listed with >=25 events" was incorrect. The admin users index orders by `inserted_at DESC`; the harness-created platform-admin login user (`platform-admin+dg-...@example.test`) is always newest and thus first-listed with only ~3 audit events. The seeded admin (29 events, sufficient for pagination) is buried below it and the 36-user bulk cohort, so `.first()` never reached it. Pagination requires page_size 25; ~3 events fit on one page — no Previous/Next — assertion failed at line 387.
- **Fix:** Replaced `await page.goto('/admin/users')` (line 368) with `await page.goto('/admin/users?q=admin%40demo.tasklane.test')` so the search form filters to exactly the seeded admin before taking the first "Open user" link. The pagination assertion (Previous page / Next page) is preserved unchanged — no assertion weakened.
- **Files modified:** `test/example/priv/playwright/tests/admin-design.spec.ts`
- **Verification:** `SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium -g "content-equivalent" --reporter=line` → 1 passed (7.0s)
- **Committed in:** `bcbbfad5`

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in test navigation assumption)
**Impact on plan:** The fix is test-navigation logic only. No implementation code changed, no screenshot assertions added or removed. The pagination assertion still proves FIXT-01: "pagination renders on the >=25-event fixture user." The deviation was found and fixed via the human-verify gate working as designed.

## Issues Encountered

- The plan's Task 1 instruction that "plan 03 seeded the bulk cohort BEFORE personas so admin stays first-listed" did not hold at runtime — the Playwright harness creates its OWN platform-admin login user per test run (newer insertion timestamp than any seed), which always wins first-listed position. The human-verify gate caught this before the phase was marked complete.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 199 (foundation-tier-2-scorecard-stress-fixtures) is complete and green on its own (D-15)
- FIXT-01 behaviorally proven: >=25-event seeded admin drives pagination rendering; content-equivalence test passes
- FIXT-02 (bulk cohort breadth) proven via plan 03 seeds + seeds_test contract lock
- Both snapshot allowlists empty; both canaries byte-stable; todo resolved
- Ready for Phase 200 or any phase that depends on the scorecard stress fixture baseline

---
*Phase: 199-foundation-tier-2-scorecard-stress-fixtures*
*Completed: 2026-06-25*
