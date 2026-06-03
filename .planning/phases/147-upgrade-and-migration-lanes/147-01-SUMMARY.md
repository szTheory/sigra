---
phase: 147-upgrade-and-migration-lanes
plan: 01
subsystem: infra
tags: [ci, upgrade, hex, smoke]
requires:
  - phase: 146-release-gate-and-maintainer-runbook
    provides: release_ref_guard pattern and canonical CI smoke job shape
provides:
  - Published-consumer upgrade harness from latest Hex 0.3.x to local candidate source
  - Dedicated `upgrade_smoke` CI job separated from `install_smoke`
affects: [release-evidence, ci, upgrade-path]
tech-stack:
  added: []
  patterns: [runtime version resolution from Hex, published-to-path upgrade lane]
key-files:
  created:
    - scripts/ci/upgrade-smoke.sh
  modified:
    - .github/workflows/ci.yml
key-decisions:
  - "Resolve latest published 0.3.x at runtime by default and only allow explicit validated overrides."
  - "Keep upgrade proof as a separate CI job id from install_smoke so release evidence stays unambiguous."
patterns-established:
  - "Consumer upgrade smoke must prove install->upgrade->compile->migrate->runtime route continuity."
requirements-completed: [UPGRADE-02]
duration: 20min
completed: 2026-05-31
---

# Phase 147 Plan 01: Upgrade And Migration Lanes Summary

**Dedicated latest-published 0.3.x to local candidate upgrade smoke harness with a distinct CI upgrade_smoke lane**

## Performance

- **Duration:** 20 min
- **Started:** 2026-05-31T17:44:24Z
- **Completed:** 2026-05-31T18:04:43Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `scripts/ci/upgrade-smoke.sh` that resolves the latest published Hex `0.3.x` release at runtime, supports validated override via `SIGRA_UPGRADE_SMOKE_START_VERSION`, and fails fast on invalid/missing versions.
- Implemented end-to-end upgrade proof in the same generated app: install from published dep, switch to local path dep, run `mix sigra.upgrade --allow-dirty --yes`, then compile/migrate/runtime route checks.
- Added a dedicated `upgrade_smoke` job in `.github/workflows/ci.yml` with `needs: release_ref_guard`, matching existing smoke-job setup patterns while keeping `install_smoke` separate.

## Task Commits

1. **Task 1: Create the latest-published-0.3.x to candidate upgrade harness** - `430131d` (feat)
2. **Task 2: Add a distinct `upgrade_smoke` job to canonical CI** - `58dbfa0` (chore)

## Files Created/Modified
- `scripts/ci/upgrade-smoke.sh` - Published-to-candidate upgrade harness with validation, compile/migrate gates, and runtime route probe.
- `.github/workflows/ci.yml` - New `upgrade_smoke` CI job invoking the new harness.

## Decisions Made
- Resolve and log published start version dynamically from Hex instead of pinning a fixed patch version.
- Keep upgrade lane evidence isolated from greenfield install evidence by using separate CI job IDs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed inline Elixir quoting in mix.exs patch failure message**
- **Found during:** Task 1 verification run
- **Issue:** Inline Elixir string quoting caused token parse failure.
- **Fix:** Simplified failure message string to avoid embedded quote delimiter conflicts.
- **Files modified:** `scripts/ci/upgrade-smoke.sh`
- **Verification:** `bash scripts/ci/upgrade-smoke.sh` progressed past mix.exs patch step.
- **Committed in:** `430131d`

**2. [Rule 2 - Missing Critical] Added default `CLOAK_KEY` for runtime boot check**
- **Found during:** Task 1 verification run
- **Issue:** Generated app boot failed because `CLOAK_KEY` was unset.
- **Fix:** Exported default `CLOAK_KEY` matching existing smoke-lane convention.
- **Files modified:** `scripts/ci/upgrade-smoke.sh`
- **Verification:** Runtime boot progressed past vault initialization.
- **Committed in:** `430131d`

**3. [Rule 1 - Bug] Made harness rerunnable by dropping/recreating DB before migrate steps**
- **Found during:** Task 1 repeated verification runs
- **Issue:** Existing DB state caused duplicate-table migration errors on rerun.
- **Fix:** Added explicit `mix ecto.drop --force || true` before create/migrate checks.
- **Files modified:** `scripts/ci/upgrade-smoke.sh`
- **Verification:** Repeated runs completed migration phases cleanly.
- **Committed in:** `430131d`

**4. [Rule 1 - Bug] Hardened runtime probe for real local binding/status behavior**
- **Found during:** Task 1 runtime probe verification
- **Issue:** Probe used strict `curl -f` and `localhost` resolution behavior that failed despite healthy server.
- **Fix:** Probe now accepts 200/3xx responses and targets `127.0.0.1` explicitly.
- **Files modified:** `scripts/ci/upgrade-smoke.sh`
- **Verification:** `bash scripts/ci/upgrade-smoke.sh` exits 0 with `runtime route check passed`.
- **Committed in:** `430131d`

---

**Total deviations:** 4 auto-fixed (4 rule-1/2 correctness fixes)
**Impact on plan:** All changes were in-scope reliability fixes required for deterministic upgrade-lane proof.

## Issues Encountered

- Runtime boot probe repeatedly failed until route-status handling and explicit host binding were corrected; resolved in the harness.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 147 now has canonical CI evidence for published-consumer upgrade posture.
- Ready for subsequent migration-lane documentation plans.

## Verification Commands Run

- `bash scripts/ci/upgrade-smoke.sh`
- `rg -n '^  upgrade_smoke:|Upgrade smoke \(latest published 0\.3\.x -> local 1\.0\.0 candidate\)|scripts/ci/upgrade-smoke\.sh' .github/workflows/ci.yml`

## Self-Check: PASSED

- Found summary file: `.planning/phases/147-upgrade-and-migration-lanes/147-01-SUMMARY.md`
- Found task commit `430131d` in git history
- Found task commit `58dbfa0` in git history
