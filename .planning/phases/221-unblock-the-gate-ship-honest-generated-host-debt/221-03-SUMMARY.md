---
phase: 221-unblock-the-gate-ship-honest-generated-host-debt
plan: 03
subsystem: infra
tags: [ci, hex, upgrade-smoke, gate, release-pin]

# Dependency graph
requires: ["221-02"]
provides:
  - "upgrade_smoke job in ci.yml pinned to SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0 via the sanctioned override (Option 4a / D-13)"
affects: [221-04, 221-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Job-level env: block on a GitHub Actions job, sitting alongside runs-on/if/needs, to feed a script-level override var (no algorithm change)"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "Pin value is 1.3.0, matching the Option 4a / D-13 decision reversal recorded in 221-CONTEXT.md/221-RESEARCH.md — publish/retire alone cannot green the gate because sort -V orders 1.20.0 > 1.3.0 and mix hex.retire leaves 1.20.0 visible in mix hex.info"
  - "No change to resolve_latest_sigra_source, --warnings-as-errors, or any other job — this plan is a single env line, not a gate-algorithm change"
  - "Did not claim gate-green in this plan: upgrade_smoke is skipped on PRs (if: github.event_name != 'pull_request') and only runs on push-to-main; the override also rejects an unpublished pin (v1.3.0 is not yet published — confirmed live via mix hex.info sigra), so the terminal gate-green proof is explicitly deferred to Plan 05 after Plan 04 publishes v1.3.0"

requirements-completed: [PUB-01]

coverage:
  - id: D1
    description: "The upgrade_smoke job in ci.yml sets env SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0, pinning the smoke's published floor above the stray 1.20.0 via the existing sanctioned override"
    requirement: "PUB-01"
    verification:
      - kind: unit
        ref: "grep -n 'SIGRA_UPGRADE_SMOKE_START_VERSION' .github/workflows/ci.yml -> matches 'SIGRA_UPGRADE_SMOKE_START_VERSION: \"1.3.0\"' at the upgrade_smoke job level; python3 -c \"import yaml,sys;yaml.safe_load(open('.github/workflows/ci.yml'))\" parses clean"
        status: pass
    human_judgment: false
  - id: D2
    description: "The env var name in ci.yml byte-matches the one upgrade-smoke.sh reads, and the honest resolution proof is recorded (local snippet resolves 1.20.0 today; pin only takes effect once v1.3.0 is published; gate-green is push-to-main only)"
    requirement: "PUB-01"
    verification:
      - kind: unit
        ref: "grep -q 'SIGRA_UPGRADE_SMOKE_START_VERSION' scripts/ci/upgrade-smoke.sh && grep -q 'SIGRA_UPGRADE_SMOKE_START_VERSION: \"1.3.0\"' .github/workflows/ci.yml (both matched); local reproduction of upgrade-smoke.sh:44-53's sed/grep/sort snippet against live mix hex.info sigra resolved 1.20.0 (unpinned) and confirmed 1.3.0 is not yet published"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-10
status: complete
---

# Phase 221 Plan 03: Pin upgrade_smoke Start Version to 1.3.0 Summary

**Added `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` as a job-level `env:` on the `upgrade_smoke` job in `.github/workflows/ci.yml`, using the existing published+in-series override in `upgrade-smoke.sh` to pin the smoke's tested floor above the stray `1.20.0` Hex release — no gate-algorithm change, and gate-green is explicitly deferred to Plan 05 (push-to-main, after Plan 04 publishes v1.3.0).**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-07-10T16:43:00Z
- **Completed:** 2026-07-10T16:51:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added a job-level `env:` block to the `upgrade_smoke` job (between `needs: release_ref_guard` and `services:`) containing `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"`, with a comment citing Phase 221 / D-13 (Option 4a) and noting the durable retired-filter is deferred to HARD-01 / Phase 222
- `git diff` scoped to exactly the 6-line addition on the `upgrade_smoke` job header — no touch to `resolve_latest_sigra_source`, `--warnings-as-errors`, or any other job/step
- YAML parses clean (`python3 -c "import yaml,sys;yaml.safe_load(open('.github/workflows/ci.yml'))"`)
- Cross-checked the env var name byte-matches the one `upgrade-smoke.sh:17` reads (`SIGRA_UPGRADE_SMOKE_START_VERSION`)
- Reproduced the exact `upgrade-smoke.sh:44-53` resolution snippet locally against live Hex (`mix hex.info sigra`): unpinned resolution today is `1.20.0` (the stray release — confirmed present alongside `1.1.0`/`1.0.0`); confirmed `1.3.0` is not yet published on Hex, so the override would currently reject the pin if actually invoked — proving the pin's effect is honestly gated on Plan 04's publish, not claimed here

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0 to the upgrade_smoke job** - `f507992c` (feat)
2. **Task 2: Document the local resolution proof (deferred-green, published-gated)** - verification-only, no file edit; folded into this SUMMARY (no separate commit — `files_modified: []` per plan)

## Files Created/Modified
- `.github/workflows/ci.yml` - added job-level `env: SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` to the `upgrade_smoke` job, with a Phase 221/D-13 provenance comment

## Decisions Made
- Pin value `1.3.0` matches the Option 4a / D-13 decision reversal (research proved publish/retire alone cannot green the gate: `sort -V` orders `1.20.0 > 1.3.0`, and `mix hex.retire` leaves `1.20.0` visible in `mix hex.info`)
- Scope discipline: single `env:` key addition only — verified via `git diff` that no other job, step, or script logic changed
- Explicitly did NOT claim gate-green in this plan — `upgrade_smoke` is `if: github.event_name != 'pull_request'` (skipped on PRs, runs only on push-to-`main`), and the override in `upgrade-smoke.sh:56-77` validates the pinned version is published before using it. Since v1.3.0 is not yet published (confirmed live), the terminal gate-green proof belongs to Plan 05, sequenced after Plan 04's publish per D-14.

## Deviations from Plan

None - plan executed exactly as written. Task 2 was verification-only (no `<files>` listed in the plan) and its proof is recorded here rather than as a separate commit, matching the plan's own task structure.

## Issues Encountered

None. Confirmed via live `mix hex.info sigra` (public read, no auth needed) that the unpinned resolution today is `1.20.0` and `1.3.0` is not yet published — both expected, pre-Plan-04 states.

## User Setup Required

None - no external service configuration required. Hex publish (the step that makes this pin take effect) is Plan 04, and per `221-CONTEXT.md`/ROADMAP is an operator-gated Hex write step in Phase 223's runbook lineage, not automated here.

## Next Phase Readiness
- The `upgrade_smoke` job is pinned and ready to green on push-to-`main` once v1.3.0 is published (Plan 04)
- Plan 05 owns the terminal push-to-main gate-green observation — do not treat this plan's local verification as that proof
- No blocking issues for Plan 04

---
*Phase: 221-unblock-the-gate-ship-honest-generated-host-debt*
*Completed: 2026-07-10*

## Self-Check: PASSED

`.github/workflows/ci.yml` found on disk with `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` present at the `upgrade_smoke` job level (verified via `grep`). Task 1 commit `f507992c` verified present in `git log --oneline -5`. Task 2 recorded no separate commit per plan design (verification-only, `<files></files>` empty).
