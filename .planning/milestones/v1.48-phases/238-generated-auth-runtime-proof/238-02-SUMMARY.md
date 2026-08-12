---
phase: 238-generated-auth-runtime-proof
plan: 02
subsystem: testing
tags: [playwright, generated-auth, mailbox, b2c]
requires:
  - phase: 238-01
    provides: Fresh canonical B2C generated-host lifecycle and focused runtime harness.
provides:
  - Bounded mailbox extractors for confirmation, magic-link, and password-reset routes.
  - One serial rendered B2C email-authentication journey.
affects: [238-03, 238-04, AUTH-01]
tech-stack:
  added: []
  patterns: [Playwright expect.poll mailbox readiness, generated-host route normalization]
key-files:
  created:
    - test/example/priv/playwright/tests/generated-auth.spec.ts
  modified:
    - test/example/priv/playwright/fixtures/mailbox.ts
key-decisions:
  - "Mailbox selection uses exact recipients, route-specific links, newest timestamps, and generated-host URL normalization."
  - "The email journey remains one serial browser test using rendered controls, without context calls or cookie manipulation."
patterns-established:
  - "Use bounded expect.poll rather than elapsed-time sleeps for development-mailbox readiness."
requirements-completed: [AUTH-01]
coverage:
  - id: D1
    description: Rendered registration, confirmation, password, logout, magic-link, and reset flow against a fresh B2C host.
    requirement: AUTH-01
    verification:
      - kind: automated_ui
        ref: scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth
        status: unknown
    human_judgment: true
    rationale: Local PostgreSQL and fresh generated host are unavailable; CI must execute the focused browser proof.
duration: 13min
completed: 2026-08-05
status: complete
---

# Phase 238 Plan 02: Generated Email Authentication Journey Summary

**A serial generated-host Playwright journey now covers registration, confirmation, password login/logout, magic-link consumption, and password reset with deterministic development-mailbox links.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-08-05T14:50:00Z
- **Completed:** 2026-08-05T15:03:52Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced mailbox elapsed-time retrying with typed, bounded `expect.poll` extraction for confirmation, magic-link, and reset URLs.
- Matched mailbox recipients exactly, selected the newest purpose-specific message, validated mailbox JSON, and normalized links to the generated host.
- Added one serial browser-visible B2C journey through all AUTH-01 email transitions, including old-password rejection after reset.

## Task Commits

1. **Task 1: Register and confirm through a no-sleep development mailbox** - `1aa1b7c9` (test), `3e8e23e7` (feat), `be287695` (fix)
2. **Task 2: Complete password, logout, magic-link, and reset journeys in the same serial test** - `30f647cc` (test)

## Files Created/Modified

- `test/example/priv/playwright/fixtures/mailbox.ts` - Typed route-aware mailbox polling and auth-link wrappers.
- `test/example/priv/playwright/tests/generated-auth.spec.ts` - Single serial rendered email-auth journey for the generated B2C host.

## Decisions Made

- Selected only exact-recipient messages and normalized absolute or relative auth links to the active generated host to keep bearer-link navigation in scope.
- Used LiveView connection, URL, role, label, form, and visible-flash signals only; no sleeps or direct auth/session manipulation were added.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test contract] Preserved the explicit `expect.poll` mailbox contract**
- **Found during:** Task 1
- **Issue:** The initial chained formatting implemented polling but did not contain the plan-required `expect.poll` contract string.
- **Fix:** Used the direct `expect.poll(...)` form without changing bounded polling behavior.
- **Files modified:** `test/example/priv/playwright/fixtures/mailbox.ts`
- **Verification:** Static contract scan confirms `expect.poll`; no sleep APIs appear in the fixture or journey.
- **Committed in:** `be287695`

**Total deviations:** 1 auto-fixed (Rule 1).

## Issues Encountered

- The focused Playwright invocation is not runnable locally: it reaches the test but fails at `ERR_CONNECTION_REFUSED` before first navigation because no fresh generated host/PostgreSQL is available. Test discovery, source contracts, and diff checks pass; the fresh-host browser command remains CI-only.

## Known Stubs

None.

## User Setup Required

None - CI provisions the disposable generated B2C host.

## Next Phase Readiness

- Plans 238-03 through 238-05 can reuse the route-aware mailbox fixture and serial generated-host journey.
- CI must run `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth` after its allowlisted spec entry point is available.

## Self-Check: PASSED

- Both owned Playwright files exist.
- All four task commits exist in git history.
- Playwright discovers the serial journey in chromium and mobile projects; source checks confirm bounded `expect.poll` and no sleep APIs.

---
*Phase: 238-generated-auth-runtime-proof*
*Completed: 2026-08-05*
