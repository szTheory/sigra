---
phase: 149-launch-evidence-and-announcement-pack
plan: 03
subsystem: testing
tags: [launch, docs-contract, exunit, ci]
requires:
  - phase: 149-launch-evidence-and-announcement-pack
    provides: launch pack docs and public/AI routing
provides:
  - shell contract for launch pack docs, routes, placeholders, and overclaim boundaries
  - ExUnit planning test for cross-file launch routing and claim boundaries
affects: [docs, CI, release evidence, AI routing]
tech-stack:
  added: []
  patterns: [fast docs shell contract, cross-file planning ExUnit test]
key-files:
  created:
    - scripts/ci/launch-pack-contract.sh
    - test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs
  modified:
    - docs/launch/v1.0/alternatives.md
    - docs/launch/v1.0/evidence.md
key-decisions:
  - "Used a fast shell contract for required files, routes, post-publish placeholders, root `llms.txt` pointer-only shape, and unsupported overclaim phrases."
  - "Added a focused ExUnit planning test to lock content, routing, and threat-boundary assertions across launch docs and indexes."
patterns-established:
  - "Docs launch claims are guarded by both shell contract checks and source-level ExUnit assertions."
  - "Root `llms.txt` must stay pointer-only and must not grow a second `## Pages` taxonomy."
requirements-completed: [LAUNCH-01, LAUNCH-02, LAUNCH-03, LAUNCH-04]
duration: 2 min
completed: 2026-06-01
---

# Phase 149 Plan 03: Launch Contract Checks Summary

**Fast shell and ExUnit contracts guarding launch docs, routes, placeholders, and overclaim boundaries**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-01T15:23:00Z
- **Completed:** 2026-06-01T15:25:33Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `scripts/ci/launch-pack-contract.sh` with repo-root resolution, required launch doc checks, route checks, placeholder checks, forbidden-claim checks, and root `llms.txt` pointer-only validation.
- Added `test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` with three tests covering launch-pack content, publication/routing, and threat boundaries.
- Re-ran shell contract, focused ExUnit test, and `mix docs --warnings-as-errors` successfully.

## Task Commits

1. **Task 1: Add a fast shell contract for launch routes, placeholders, and forbidden claims** - `300a86bc`
2. **Task 2: Add a Phase 149 planning test for cross-file routing and claim boundaries** - `23e17f41`

## Files Created/Modified

- `scripts/ci/launch-pack-contract.sh` - Fast shell contract for launch pack docs, routes, placeholders, AI index shape, and unsupported claim phrases.
- `test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` - ExUnit regression coverage for Phase 149 launch content and routing.
- `docs/launch/v1.0/alternatives.md` - Added exact lowercase hosted-auth wording for contract checks.
- `docs/launch/v1.0/evidence.md` - Added exact `main blob URLs` wording for contract checks.

## Decisions Made

- Kept the forbidden-phrase checks focused on unsupported positive guarantees, while allowing proof-boundary language that explicitly says what Sigra does not prove.
- Used string assertions rather than broad regexes so comments and unrelated copy are less likely to satisfy the checks accidentally.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The first contract run exposed two missing exact strings expected by the plan (`hosted auth` and `main blob URLs`). Both were added to the launch docs without changing the release claims. The focused ExUnit command emits existing `Chimeway.Repo` connection log noise about missing `:database` configuration, but the targeted tests pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 149 is ready for phase-level verification. All launch-pack docs, routes, AI pointers, and contract checks are present.

---
*Phase: 149-launch-evidence-and-announcement-pack*
*Completed: 2026-06-01*
