---
phase: 149-launch-evidence-and-announcement-pack
plan: 02
subsystem: docs
tags: [launch, exdoc, changelog, llms]
requires:
  - phase: 149-launch-evidence-and-announcement-pack
    provides: canonical launch announcement, alternatives comparison, and evidence bundle
provides:
  - README, CHANGELOG, GitHub Release guidance, and ExDoc routing to the launch pack
  - curated `doc/llms.txt` launch-pack entries
  - pointer-only root `llms.txt`
affects: [README, CHANGELOG, ExDoc, AI routing, release process]
tech-stack:
  added: []
  patterns: [single-source launch routing, pointer-only root llms file, forced staging of generated docs index]
key-files:
  created:
    - llms.txt
  modified:
    - README.md
    - CHANGELOG.md
    - mix.exs
    - docs/NEXT-STEPS-MANUAL.md
    - doc/llms.txt
    - docs/launch/v1.0/announcement.md
    - docs/launch/v1.0/evidence.md
key-decisions:
  - "Kept root `llms.txt` pointer-only and left `doc/llms.txt` as the single full AI-consumption taxonomy."
  - "Published launch docs through existing `Docs` ExDoc grouping rather than inventing a new documentation group."
  - "Changed launch-pack internal proof links to ExDoc-style `.html` links while preserving literal repo paths for source checks."
patterns-established:
  - "Release surfaces route to `docs/launch/v1.0/announcement.md` as the canonical public 1.0 story."
  - "Generated `doc/llms.txt` changes under the ignored docs tree require force staging."
requirements-completed: [LAUNCH-01, LAUNCH-03, LAUNCH-04]
duration: 3 min
completed: 2026-06-01
---

# Phase 149 Plan 02: Launch Routing Summary

**Launch pack routed through README, changelog, ExDoc extras, GitHub Release guidance, and AI-consumption indexes**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-01T15:20:00Z
- **Completed:** 2026-06-01T15:23:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added launch-pack entry points to README, CHANGELOG, `mix.exs` ExDoc extras, and manual GitHub Release guidance.
- Curated `doc/llms.txt` with launch announcement, alternatives, evidence, changelog, and security routing.
- Added root `llms.txt` as a pointer-only file to the generated AI index and published HexDocs index.

## Task Commits

1. **Task 1: Publish the launch pack through README, changelog guidance, ExDoc, and the GitHub Release drafting step** - `aa3c2919`
2. **Task 2: Curate the AI indexes around the canonical 1.0 paths and add a pointer-only root `llms.txt`** - `6451cd89`

## Files Created/Modified

- `README.md` - Added top-level launch announcement, alternatives, and evidence links.
- `CHANGELOG.md` - Added version-clear Unreleased launch-pack guidance.
- `mix.exs` - Added all three launch docs to ExDoc extras under the existing `Docs` grouping.
- `docs/NEXT-STEPS-MANUAL.md` - Pointed hand-cut GitHub Release body drafting at the launch announcement and evidence bundle.
- `doc/llms.txt` - Added generated AI-consumption launch routes.
- `llms.txt` - Added pointer-only root AI-discovery file.
- `docs/launch/v1.0/announcement.md` and `docs/launch/v1.0/evidence.md` - Adjusted proof links for ExDoc warnings-as-errors compatibility.

## Decisions Made

- Kept the changelog as routing guidance rather than duplicating who-should-upgrade prose.
- Kept AI routing in one generated taxonomy plus a minimal root pointer.
- Force-staged `doc/llms.txt` because the generated docs tree is intentionally ignored.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

`mix docs --warnings-as-errors` initially failed on flattened ExDoc links from launch docs to the release runbook. The links were changed to `.html` targets while keeping exact repo path strings in text for contract checks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 149-03. Public and AI-facing routes now converge on the canonical launch pack and can be locked with shell and ExUnit contract checks.

---
*Phase: 149-launch-evidence-and-announcement-pack*
*Completed: 2026-06-01*
