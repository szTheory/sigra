---
phase: 245-opaque-app-session-core
plan: 01
subsystem: auth
tags: [ecto, postgres, opaque-tokens, sha256, app-sessions]
requires:
  - phase: 243-credential-boundary-and-pipeline-foundation
    provides: Explicit first-party app-session credential boundary and fail-closed pipeline seam.
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: Locked digest-token lifecycle and post-commit response pattern.
provides:
  - Host-schema configuration seam for opaque app-session families and credentials.
  - Digest-only PostgreSQL issue and access-authentication tracer.
affects: [246-first-party-app-session-install-and-issuance]
tech-stack:
  added: []
  patterns: [host-owned Ecto schemas, dedicated family and typed credential rows, post-commit raw credential response]
key-files:
  created: [lib/sigra/app_session.ex, test/support/app_session_schemas.ex, test/sigra/app_session_test.exs]
  modified: [lib/sigra/config.ex]
key-decisions:
  - "App sessions use dedicated family and typed token rows instead of JWT metadata storage."
  - "The configuration seam accepts only paired host schema modules and enforces access_ttl < refresh_idle_ttl <= absolute_ttl."
patterns-established:
  - "Opaque credentials are generated once, persisted only as SHA-256 digests, and returned only after the transaction commits."
requirements-completed: [APP-04]
coverage:
  - id: D1
    description: Digest-only opaque app-session issue and access authentication through host-owned PostgreSQL schemas.
    requirement: APP-04
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace"
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-13
status: complete
---

# Phase 245 Plan 01: Opaque App-Session Core Summary

**Digest-only opaque access and refresh issuance with a fixed family deadline and PostgreSQL-backed access authentication through host-owned Ecto schemas.**

## Performance

- **Duration:** 14 min
- **Completed:** 2026-08-13T00:37:13Z
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Added validated `app_session` configuration with exact 900, 2,592,000, and 7,776,000-second defaults.
- Added `Sigra.AppSession.issue/4` and `authenticate/2`, retaining raw credentials only in a successful post-commit response.
- Proved one dedicated family and separate typed digest rows with the real PostgreSQL test repo.

## Task Commits

1. **Task 1: Trace one opaque app session through host-owned PostgreSQL schemas** - `c1626152` (test), `3354d1dd` (feat)

## Files Created/Modified

- `lib/sigra/config.ex` - Validates paired host schemas and strict app-session TTL ordering.
- `lib/sigra/app_session.ex` - Issues and authenticates digest-only opaque credentials.
- `test/support/app_session_schemas.ex` - Defines representative host-owned family and token schemas.
- `test/sigra/app_session_test.exs` - Exercises the full PostgreSQL tracer and fail-closed cases.

## Decisions Made

- Kept Phase 246 ownership intact: no generated schemas, migrations, installer flags, routes, or controllers were added.
- Used a dedicated family row plus append-only typed token records; no JWT `sent_to` JSON metadata is reused.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the dynamic host-schema join query**
- **Found during:** Task 1
- **Issue:** Ecto rejected the dynamically configured family schema as a static query join.
- **Fix:** Bound the configured family schema as a dynamic query source.
- **Files modified:** `lib/sigra/app_session.ex`
- **Verification:** PostgreSQL tracer passes.
- **Committed in:** `3354d1dd`

**2. [Rule 1 - Bug] Preserved microsecond precision for UTC schema fields**
- **Found during:** Task 1
- **Issue:** `:utc_datetime_usec` rejects timestamps truncated to seconds.
- **Fix:** Generate lifecycle timestamps with microsecond precision.
- **Files modified:** `lib/sigra/app_session.ex`
- **Verification:** PostgreSQL tracer passes.
- **Committed in:** `3354d1dd`

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs).

## Issues Encountered

None remaining.

## User Setup Required

None - the existing `tmp/db.env` PostgreSQL test connection was used.

## Next Phase Readiness

Phase 246 can consume the validated host-schema seam and issue/authenticate authority while owning all generated-host artifacts and issuance transport.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace` — 2 tests, 0 failures.
- `MIX_ENV=test mix test test/sigra/config_test.exs --trace` — 53 tests, 0 failures.
- Task diff contains no installer, template, router, or controller file.

## Self-Check: PASSED

- All four planned implementation/test files exist.
- Both task commits are present in git history.
