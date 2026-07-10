---
phase: 218-elevation-wave-nit-cleanup
plan: 10
subsystem: infra
tags: [docker, uat, bash, dev-dx]

# Dependency graph
requires:
  - phase: 218-elevation-wave-nit-cleanup
    provides: 218-REVIEW.md WR-05 finding (reap_stale_uat_stacks single-label filter contradicting its own comment)
provides:
  - reap_stale_uat_stacks in scripts/uat/up.sh now unions dev.sigra.proxy-host AND dev.local.proxy-host, mirroring the proxy_host_claimants precedent, so vendor-neutral-only-labeled UAT stacks are reaped instead of leaking
affects: [scripts/uat/up.sh, future sibling-lib UAT DX work]

# Tech tracking
tech-stack:
  added: []
  patterns: ["dual-label docker ps union + sort -u for cross-label discovery, matching proxy_host_claimants"]

key-files:
  created: []
  modified:
    - scripts/uat/up.sh

key-decisions:
  - "Ran two separate `docker ps -a` invocations (one per proxy-host label) and combined with `sort -u`, rather than a single OR-style filter, because docker's --filter semantics AND multiple label filters within one query — the same constraint that shaped the existing proxy_host_claimants precedent."

patterns-established:
  - "Dual-label docker label union: query once per label variant, pipe through sort -u, tolerate per-leg failure with || true — reusable pattern already established by proxy_host_claimants and now applied to reap_stale_uat_stacks."

requirements-completed: [ELEVATE-02]

coverage:
  - id: D1
    description: "reap_stale_uat_stacks queries both dev.sigra.proxy-host and dev.local.proxy-host labels (union + sort -u) so a stack labeled only with the vendor-neutral label is reaped instead of leaking"
    requirement: "ELEVATE-02"
    verification:
      - kind: other
        ref: "bash -n scripts/uat/up.sh (syntax clean)"
        status: pass
      - kind: other
        ref: "awk/grep over reap_stale_uat_stacks() body: dev.local.proxy-host|dev.sigra.proxy-host count == 3 (>= 2 required)"
        status: pass
    human_judgment: false

# Metrics
duration: 3min
completed: 2026-07-09
status: complete
---

# Phase 218 Plan 10: Union proxy-host labels in UAT reaper Summary

**Fixed `reap_stale_uat_stacks` in `scripts/uat/up.sh` to actually query both the vendor-neutral `dev.local.proxy-host` and legacy `dev.sigra.proxy-host` labels (union + sort -u), closing the gap where the function's own comment claimed dual-label coverage it didn't implement.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-09T18:16:00Z
- **Completed:** 2026-07-09T18:19:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- `reap_stale_uat_stacks` now runs one `docker ps -a` query per proxy-host label (`dev.sigra.proxy-host` and `dev.local.proxy-host`), each still requiring `label=com.docker.compose.project`, and dedupes the combined output with `sort -u` — mirroring the existing `proxy_host_claimants` dual-label union precedent.
- Each leg tolerates its own docker-command failure via `|| true` so a hiccup on one label query never aborts the reaper.
- All existing safety invariants preserved unchanged: `SIGRA_UAT_REAP` opt-out, `command -v docker` / `docker ps` availability guards, the "never reap the current project" check, and the "only reap projects with zero running containers" gate.

## Task Commits

Each task was committed atomically:

1. **Task 1: Union both proxy-host labels in reap_stale_uat_stacks (WR-05)** - `1a6831c8` (fix)

**Plan metadata:** (pending — final docs commit follows this summary)

## Files Created/Modified
- `scripts/uat/up.sh` - `reap_stale_uat_stacks` now unions `dev.sigra.proxy-host` and `dev.local.proxy-host` label queries via two `docker ps -a` invocations piped through `sort -u`, instead of a single-label filter that contradicted its own comment.

## Decisions Made
- Used two sequential `docker ps -a` calls (one per label) combined with `sort -u`, rather than attempting a single OR-style `--filter` expression, since Docker CLI filters are ANDed within one invocation — same constraint the pre-existing `proxy_host_claimants` helper already worked around. This keeps the fix idiomatically consistent with that precedent.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- WR-05 from 218-REVIEW.md is closed; the reaper now behaves as its comment describes.
- This was the final incomplete plan (218-10) in Phase 218 (elevation-wave-nit-cleanup) — all 10 plans in this phase are now complete.
- No blockers for downstream phases (219: Baseline Recapture + Canary Reconciliation).

---
*Phase: 218-elevation-wave-nit-cleanup*
*Completed: 2026-07-09*

## Self-Check: PASSED
- FOUND: scripts/uat/up.sh
- FOUND: .planning/phases/218-elevation-wave-nit-cleanup/218-10-SUMMARY.md
- FOUND: commit 1a6831c8
