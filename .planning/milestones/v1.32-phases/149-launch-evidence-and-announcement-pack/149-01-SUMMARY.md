---
phase: 149-launch-evidence-and-announcement-pack
plan: 01
subsystem: docs
tags: [launch, evidence, release, docs]
requires:
  - phase: 145-1-0-contract-and-release-truth
    provides: Sigra 1.0 contract, SemVer boundary, and public non-goals
  - phase: 146-release-gate-and-maintainer-runbook
    provides: release gate matrix, publish procedure, and first-14-day hotfix policy
  - phase: 147-upgrade-and-migration-lanes
    provides: upgrade and migration guidance
  - phase: 148-evaluator-funnel-and-first-run-dx
    provides: demo showcase and evaluator proof boundaries
provides:
  - canonical repo-owned Hex 1.0.0 announcement narrative
  - honest Sigra alternatives comparison with non-fit guidance
  - compact launch evidence bundle with post-publish placeholders
affects: [README, CHANGELOG, ExDoc, AI routing, release announcement]
tech-stack:
  added: []
  patterns: [repo-resident launch pack, link-aggregator evidence page, boundary-first alternatives table]
key-files:
  created:
    - docs/launch/v1.0/announcement.md
    - docs/launch/v1.0/alternatives.md
    - docs/launch/v1.0/evidence.md
  modified: []
key-decisions:
  - "Kept launch copy repo-owned and Hex 1.0.0 keyed, with internal planning labels excluded from announcement copy."
  - "Used exact post-publish placeholder tokens for facts that cannot exist before the real release."
  - "Positioned alternatives by ownership, scope, risk, operations, and upgrade posture instead of universal superiority."
patterns-established:
  - "Launch docs link to canonical proof and contract surfaces rather than duplicating release matrices."
  - "Evidence docs state what is not proven alongside what is proven."
requirements-completed: [LAUNCH-01, LAUNCH-02, LAUNCH-03]
duration: 8 min
completed: 2026-06-01
---

# Phase 149 Plan 01: Launch Pack Source Docs Summary

**Canonical Hex 1.0.0 launch announcement, alternatives comparison, and evidence bundle with bounded proof language**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-01T15:12:00Z
- **Completed:** 2026-06-01T15:20:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Created `docs/launch/v1.0/announcement.md` as the canonical repo-owned Hex 1.0.0 launch narrative.
- Created `docs/launch/v1.0/alternatives.md` with explicit comparison axes and "when not to choose Sigra" guidance.
- Created `docs/launch/v1.0/evidence.md` as a compact evidence router with exact `POST_PUBLISH_*` placeholders and proof boundaries.

## Task Commits

1. **Task 1: Create the canonical 1.0 announcement narrative and audience guidance** - `583ea52f`
2. **Task 2: Create the honest alternatives comparison with explicit non-fit guidance** - `d7a942ca`
3. **Task 3: Create the attachable evidence bundle with explicit proof boundaries** - `ed51883e`

## Files Created/Modified

- `docs/launch/v1.0/announcement.md` - Hex 1.0.0 announcement, audience guidance, proof links, and first-14-day triage pointer.
- `docs/launch/v1.0/alternatives.md` - alternatives comparison across `phx.gen.auth`, Pow/Guardian/Ueberauth-style composition, hosted auth, and Sigra's hybrid model.
- `docs/launch/v1.0/evidence.md` - launch evidence bundle with release proof links, post-publish placeholders, pinned-link policy, and "does not prove" boundaries.

## Decisions Made

- Used repo-relative path labels in launch docs where plan checks require exact source paths.
- Kept `v1.32` out of announcement copy and framed public launch text around Hex `1.0.0`.
- Preserved post-publish honesty by leaving final Hex, HexDocs, GitHub Release, and release-ref CI facts as placeholders.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

One acceptance command initially failed because the new docs linked by relative Markdown path but did not include all exact repo path strings required by the plan grep checks. The docs were adjusted to include those exact source paths while preserving valid relative links.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 149-02. The canonical launch pack exists and can now be routed through README, CHANGELOG, ExDoc, GitHub Release guidance, and AI-facing indexes.

---
*Phase: 149-launch-evidence-and-announcement-pack*
*Completed: 2026-06-01*
