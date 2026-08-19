---
phase: 247-language-learning-digital-twin
plan: 01
subsystem: authenticated offline lesson
tags: [phoenix, ecto, service-worker, indexeddb, cache-storage, playwright]
requires:
  - phase: 246-hosted-and-direct-login-ceremonies
    provides: cookie-backed current-Scope browser boundary
provides:
  - Account-partitioned offline lesson lease and replay receipt storage
  - Worker-gated, integrity-verified media installation and offline shell
  - Deterministic Chromium tracer for offline study and accepted replay
affects: [247-02, 247-03, 247-04, 247-05, 247-06]
tech-stack:
  added: []
  patterns: [marker-last Cache Storage promotion, account-partitioned IndexedDB activation, current-Scope replay receipt]
key-files:
  created: [test/example/lib/example/learning_twin.ex, test/example/priv/static/learning-twin-worker.js, test/example/priv/playwright/tests/twin-offline.spec.ts]
  modified: [test/example/lib/example_web/router.ex, test/example/lib/example_web.ex]
key-decisions:
  - "The worker caches only the generic shell and its runtime assets; authenticated lesson documents are always network-only."
  - "A lease partition and verified media markers are required before cached lesson state is activated."
requirements-completed: [TWIN-01, OFF-01, OFF-02]
coverage:
  - id: D1
    description: Authenticated lesson with verified offline media and shell-gated activation
    requirement: TWIN-01
    verification:
      - kind: automated_ui
        ref: "twin-offline.spec.ts#tracer: authenticated learner installs media, studies offline, and replays once"
        status: pass
    human_judgment: false
  - id: D2
    description: Account-partitioned lease and one durable accepted replay receipt
    requirement: OFF-02
    verification:
      - kind: automated_ui
        ref: "twin-offline.spec.ts#tracer: authenticated learner installs media, studies offline, and replays once"
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-08-19
status: complete
---

# Phase 247 Plan 01: Language-Learning Digital Twin Tracer Summary

**A cookie-authenticated Phoenix lesson now verifies two immutable media assets before partitioned offline use and records one current-Scope-authorized replay receipt.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-08-19T01:49:00Z
- **Completed:** 2026-08-19T02:05:25Z
- **Tasks:** 1
- **Files modified:** 10

## Accomplishments

- Added host-owned auth-schema leases and idempotent replay receipts with binary IDs, expiry/index constraints, and microsecond timestamps.
- Added authenticated lesson, bootstrap, immutable media, and CSRF-protected replay routes rooted exclusively in current Scope.
- Added a root-served `/app/` worker, generic credential-free offline shell, marker-last browser runtime, and deterministic Chromium tracer.

## Task Commits

1. **Task 1: Trace one authenticated lesson through verified install, offline study, and accepted replay** - `d169ac81` (test), `3fec30ca` (feat)

## Files Created/Modified

- `test/example/lib/example/learning_twin.ex` - lease/receipt schemas, host context, controller, and lesson LiveView.
- `test/example/priv/repo/migrations/20260819000000_create_learning_twin_tables.exs` - durable lease and receipt tables.
- `test/example/priv/static/assets/js/learning_twin.js` - digest verification, cache/IndexedDB promotion, offline gating, and replay.
- `test/example/priv/static/learning-twin-worker.js` - scoped shell caching and navigation fallback.
- `test/example/priv/playwright/tests/twin-offline.spec.ts` - browser storage and offline tracer proof.

## Decisions Made

- Kept all browser-held data bounded to lesson state, opaque partition metadata, markers, and replay payloads; authentication remains the HttpOnly session/current-Scope boundary.
- Returned the generic shell for offline navigation and let it render cached lesson state only after every partition, lease, marker, and cache gate passes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking environment] Started the repository-isolated PostgreSQL endpoint**
- **Found during:** Task 1
- **Issue:** The planned migration command could not connect to the configured local database endpoint.
- **Fix:** Used `scripts/db/up.sh`, then executed the migration and focused tests with the generated isolated environment.
- **Verification:** `MIX_ENV=test mix ecto.migrate` reported all migrations up; focused ExUnit tests passed.

---

**Total deviations:** 1 auto-fixed (Rule 3: 1).
**Impact on plan:** No product scope change; enabled deterministic local verification.

## Issues Encountered

The initial RED tracer could not reach an application server, as expected before the runtime existed. After implementation, a service-worker readiness promise was moved after navigation because page navigation invalidates the previous execution context; the final tracer uses readiness hooks rather than sleeps.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The bounded host contracts, worker scope, storage names, and deterministic tracer are ready for the negative-state and boundary matrix plans.

## Self-Check: PASSED

- Confirmed all created host, worker, shell, runtime, migration, and tracer files exist.
- Confirmed `d169ac81` and `3fec30ca` exist in git history.
- Passed `mix format --check-formatted`, migration, focused ExUnit tests, and the Chromium tracer.
