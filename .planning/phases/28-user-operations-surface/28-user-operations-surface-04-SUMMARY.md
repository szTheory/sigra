---
phase: 28-user-operations-surface
plan: 4
subsystem: ui
tags: [phoenix-liveview, playwright, admin, validation]
requires:
  - phase: 28-03
    provides: admin user detail actions and return-context navigation
provides:
  - responsive admin user operations polish for mobile and desktop
  - Playwright smoke and dual-project browser proof for USER-05
  - finalized Phase 28 validation state backed by passing browser commands
affects: [phase-28-validation, admin-user-operations, browser-smoke]
tech-stack:
  added: []
  patterns: [mailbox-json confirmation extraction for browser setup, mobile-first admin operator smoke flow]
key-files:
  created: []
  modified:
    - test/example/priv/playwright/fixtures/mailbox.ts
    - test/example/priv/playwright/tests/admin-user-operations.spec.ts
    - lib/sigra/admin/live/users_index_live.ex
    - lib/sigra/admin/live/user_show_live.ex
    - test/example/lib/example_web/components/admin_shell.ex
    - lib/sigra/admin/users/query.ex
    - .planning/phases/28-user-operations-surface/28-VALIDATION.md
key-decisions:
  - "Keep the smoke path honest by proving confirmation through the confirmed=true filter instead of asserting an empty state."
  - "Read the newest confirmation email from /dev/mailbox/json to avoid stale-token flakiness in Playwright."
patterns-established:
  - "Browser setup helpers should prefer mailbox JSON over scraping the mailbox preview UI when deterministic email selection matters."
  - "Phase validation stays green only after the matching browser commands actually pass."
requirements-completed: [USER-05]
duration: 1h 20m
completed: 2026-04-16
---

# Phase 28 Plan 4: User Operations Surface Summary

**Responsive admin user operations now hold up on mobile and desktop, with a real confirmed-user search/filter/open/revoke browser path backing Phase 28 validation.**

## Performance

- **Duration:** 1h 20m
- **Started:** 2026-04-16T21:57:00Z
- **Completed:** 2026-04-16T22:45:00Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Kept the Phase 28 user index, detail page, and admin chrome usable on mobile without hiding scope or main actions.
- Corrected the Playwright smoke flow so `confirmed=true` keeps the target visible, then opens detail and revokes a session.
- Finished Phase 28 browser validation with passing mobile smoke and mobile+desktop Playwright runs.

## Task Commits

1. **Task 1: Finish responsive polish for the index, detail page, and shell chrome** - `26fce89` (feat)
2. **Task 2: Ship the browser operator journey and finalize the validation artifact** - `a454abf` (fix)
3. **Task 2 follow-up: Stabilize confirmation setup for the corrected smoke path** - `a1dd2cd` (fix)

## Files Created/Modified
- `test/example/priv/playwright/fixtures/mailbox.ts` - Switched mailbox scraping to `/dev/mailbox/json` and newest-email selection.
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts` - Smoke now proves confirmed search/filter visibility before opening detail and revoking a session.
- `lib/sigra/admin/live/users_index_live.ex` - Mobile-safe result cards and icon-label controls for the user index.
- `lib/sigra/admin/live/user_show_live.ex` - Keeps session actions visible above lower-priority detail content.
- `test/example/lib/example_web/components/admin_shell.ex` - Preserves visible Admin scope chrome and Users-first navigation.
- `lib/sigra/admin/users/query.ex` - Normalizes nested Flop params so browser-driven filters survive URL round-trips.
- `.planning/phases/28-user-operations-surface/28-VALIDATION.md` - Final Phase 28 validation state remains green with passed browser evidence.

## Decisions Made
- Used the `confirmed=true` browser assertion as the proof of confirmation instead of relying on intermediate confirmation-page URL behavior.
- Replaced mailbox UI scraping with JSON polling to make confirmation email selection deterministic under repeated local runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized nested admin query params for browser filters**
- **Found during:** Task 2 (browser operator journey)
- **Issue:** Browser-driven `/admin/users` filter requests mixed atom and string keys, causing `Ecto.CastError`.
- **Fix:** Deep-stringified `Flop.nest_filters(...)` output before building params.
- **Files modified:** `lib/sigra/admin/users/query.ex`, `test/sigra/admin/users_query_test.exs`
- **Verification:** `mix test test/sigra/admin/users_query_test.exs --max-failures 1`
- **Committed in:** `a454abf`

**2. [Rule 3 - Blocking] Added a real mobile Playwright project and stable mailbox extraction**
- **Found during:** Task 2 (browser operator journey)
- **Issue:** The validation flow needed a mobile project and deterministic confirmation setup to exercise the required smoke path.
- **Fix:** Added a dedicated mobile Playwright project, then switched confirmation-link lookup to `/dev/mailbox/json` with newest-email selection.
- **Files modified:** `test/example/priv/playwright/playwright.config.ts`, `test/example/priv/playwright/fixtures/mailbox.ts`, `test/example/priv/playwright/tests/admin-user-operations.spec.ts`
- **Verification:** `npx playwright test tests/admin-user-operations.spec.ts --project=mobile --grep @smoke`; `npx playwright test tests/admin-user-operations.spec.ts --project=mobile --project=chromium`
- **Committed in:** `a454abf`, `a1dd2cd`

---

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 3)
**Impact on plan:** All deviations were narrowly in service of the required browser proof and did not expand product scope.

## Issues Encountered
- Root full-suite validation command failed outside 28-04 scope in existing root tests, including `priv/templates/sigra.install/core/auth.ex` `passkeys?` compile errors and missing `sigra_test` database setup.
- Root `mix precommit` failed because the repo root does not define a `precommit` task.
- `cd test/example && mix precommit` failed on an unrelated existing assertion in `test/example_web/live/registration_live_test.exs:21` around passkey enrollment copy.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 28 browser coverage is complete and validation can stay green. Repository-wide closeout still needs the unrelated root suite/precommit issues resolved before a fully clean top-level gate is possible.

## Verification

- Passed: `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_filters_live_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1`
- Passed: `cd test/example/priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --grep @smoke`
- Passed: `cd test/example/priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --project=chromium`
- Failed, out of scope: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && cd test/example && mix test && cd priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=mobile --project=chromium`
- Failed, out of scope: `mix precommit`
- Failed, out of scope: `cd test/example && mix precommit`

## Self-Check

PENDING

---
*Phase: 28-user-operations-surface*
*Completed: 2026-04-16*
