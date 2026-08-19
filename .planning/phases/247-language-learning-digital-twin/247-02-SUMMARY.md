---
phase: 247-language-learning-digital-twin
plan: 02
subsystem: offline-media
tags: [pwa, cache-storage, indexeddb, webcrypto, playwright]
requires:
  - phase: 247-01
    provides: Authenticated lesson tracer, media manifest, account-partitioned markers, and worker shell
provides:
  - Fail-closed immutable-media verification and marker-last promotion
  - Deterministic Chromium proof of media integrity failures and recovery
affects: [247-03, offline-lease, account-partition]
tech-stack:
  added: []
  patterns: [full-buffer SHA-256 verification, marker-last cache promotion, bounded worker failure control]
key-files:
  created: []
  modified:
    - test/example/priv/static/assets/js/learning_twin.js
    - test/example/priv/playwright/tests/twin-offline.spec.ts
    - test/example/lib/example/learning_twin.ex
    - test/example/priv/static/learning-twin-worker.js
key-decisions:
  - "A cached response never represents availability without its matching partition/version marker."
  - "The worker's one-shot cache failure control carries only the bounded cache-write-failed enum."
patterns-established:
  - "Verify body size and SHA-256, await Cache.put, then write the IndexedDB marker."
requirements-completed: [OFF-01]
coverage:
  - id: D1
    description: Immutable lesson media is verified and promoted marker-last only after both assets cache successfully.
    requirement: OFF-01
    verification:
      - kind: automated_ui
        ref: "twin-offline.spec.ts#media integrity"
        status: pass
    human_judgment: false
  - id: D2
    description: Corrupt, short, interrupted, cache-write-failed, and orphan-cache media remain unavailable and retryable.
    requirement: OFF-01
    verification:
      - kind: automated_ui
        ref: "twin-offline.spec.ts#media integrity"
        status: pass
    human_judgment: false
duration: 32min
completed: 2026-08-19
status: complete
---

# Phase 247 Plan 02: Immutable Media Integrity Summary

**The lesson now proves exact immutable bytes before marker-last promotion, preventing corrupt, interrupted, rejected, and orphaned media from appearing offline-ready.**

## Performance

- **Duration:** 32 min
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- Added exact byte-size and Web Crypto SHA-256 validation before an awaited Cache Storage write and account/version marker creation.
- Added accessible prepare, verifying, retry, and available states with a stable runtime readiness hook.
- Added deterministic Chromium cases for valid, short, same-size corrupt, interrupted, one-shot cache-write failure, orphan-cache, and recovery paths with direct storage inspection.

## Task Commits

1. **Task 1: Fail closed across the complete immutable-media promotion matrix** - `fb309815` (test), `c436f886` (feat)

## Files Created/Modified

- `test/example/priv/static/assets/js/learning_twin.js` - Verifies and promotes media marker-last; rejects every bounded failure condition.
- `test/example/priv/playwright/tests/twin-offline.spec.ts` - Chromium media-integrity and storage-state matrix.
- `test/example/lib/example/learning_twin.ex` - Accessible offline prepare/retry control surface.
- `test/example/priv/static/learning-twin-worker.js` - One-shot, enum-only cache failure control.

## Decisions Made

- Cache presence without a matching partition/version marker is an orphan and cannot activate offline availability.
- The injected write failure is consumed once and exposes only `cache-write-failed`, never stored bytes, digests, partitions, or credentials.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical UI/worker support] Added the required control surface and bounded worker message seam.**
- **Found during:** Task 1
- **Issue:** The tracer auto-installed media and had neither the specified offline CTA/error states nor a deterministic worker-backed cache-write failure control.
- **Fix:** Added the accessible panel, stable readiness hook, and enum-only worker acknowledgement.
- **Files modified:** `test/example/lib/example/learning_twin.ex`, `test/example/priv/static/learning-twin-worker.js`
- **Verification:** Focused Chromium matrix and tracer passed.
- **Committed in:** `c436f886`

**2. [Rule 3 - Blocking verification environment] Started the isolated PostgreSQL-backed Phoenix example host for browser verification.**
- **Found during:** Task 1
- **Issue:** No local application server was listening for the pinned Chromium command.
- **Fix:** Used the existing `tmp/db.env` endpoint and launched the host only for deterministic test execution.
- **Verification:** `npm test -- twin-offline.spec.ts --project=chromium` passed all six tests.

---

**Total deviations:** 2 auto-fixed (Rule 2: 1, Rule 3: 1).
**Impact on plan:** Both changes were required to prove the planned UI and cache failure contract; no scope expansion occurred.

## Issues Encountered

- The original tracer assumed automatic installation. It now waits on the stable runtime hook and explicitly selects the approved offline CTA before asserting availability.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The media layer now fails closed and exposes only account-partitioned, marker-backed availability for lease and account-isolation work in Plan 03.

## Self-Check: PASSED

- Confirmed all four modified implementation and test files exist.
- Confirmed task commits `fb309815` and `c436f886` exist in git history.
- Passed `mix format --check-formatted test/example/lib/example/learning_twin.ex` and `npm test -- twin-offline.spec.ts --project=chromium` (6 passed).
