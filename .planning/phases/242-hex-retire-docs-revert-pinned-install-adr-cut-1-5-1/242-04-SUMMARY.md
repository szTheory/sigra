---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: 04
subsystem: documentation
tags: [hex, mix, dependency-resolution, changelog]
requires:
  - phase: 242-02
    provides: "Phase 242 remediation and public-evidence context"
provides:
  - "Safe three-segment Sigra dependency tuple across the core adopter journey"
  - "Accurate advisory-retirement troubleshooting guidance"
  - "Phase 242 adopter-facing notes staged under Unreleased for the 1.5.1 fold"
affects: [242-07, release-please, adopter-documentation]
actuals:
  tokens: 1292
  tasks: 2
  commits: 2
plan_head_before: 180b5f7669e6d0cea6ef80e6df04e33c3876dcbe
tech-stack:
  added: []
  patterns: ["Use the exact three-segment `~> 1.5.0` tuple in consumer-facing install sources"]
key-files:
  created: []
  modified:
    - README.md
    - guides/introduction/installation.md
    - guides/introduction/troubleshooting-install.md
    - guides/introduction/getting-started.md
    - guides/introduction/first-hour.md
    - CHANGELOG.md
key-decisions:
  - "Retirement guidance is advisory: it does not alter resolver eligibility or rewrite lockfiles."
  - "The Unreleased warning comment remains intact; Release Please owns the generated 1.5.1 heading and later fold."
requirements-completed: [REL-05, REL-06]
duration: 15min
completed: 2026-09-22
status: complete
---

# Phase 242 Plan 04: Adopter Install Journey Summary

**Core adopter documentation now pins Sigra to the maintained 1.5 line, explains the retired-release warning accurately, and stages release notes for the 1.5.1 fold.**

## Performance

- **Duration:** 15min
- **Started:** 2026-09-22T11:43:13Z
- **Completed:** 2026-09-22T11:57:55Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Updated README and installation guidance to use the exact `{:sigra, "~> 1.5.0"}` tuple and explain why broad constraints can still warn on retired `1.20.0`.
- Added consumer-focused recovery guidance that uses normal Mix resolution without claiming retirement repairs lockfiles or makes a release ineligible.
- Aligned both onboarding entry points and staged substantive Phase 242 notes beneath the preserved `## Unreleased` fold warning.

## Task Commits

Each task was committed atomically:

1. **Task 1: Make the first install and warning path safe and adopter-readable** - `a634e693` (docs)
2. **Task 2: Align onboarding prerequisites and stage the curated 1.5.1 notes** - `35ce70aa` (docs)

## Files Created/Modified

- `README.md` - presents the supported dependency tuple in the first integration path.
- `guides/introduction/installation.md` - explains the bounded 1.5 line and advisory retirement semantics.
- `guides/introduction/troubleshooting-install.md` - supplies the normal-Mix recovery path for a retired-release warning.
- `guides/introduction/getting-started.md` - aligns the prerequisite tuple.
- `guides/introduction/first-hour.md` - aligns the onboarding checklist tuple.
- `CHANGELOG.md` - stages the adopter-facing Phase 242 release notes under the preserved warning.

## Decisions Made

- Kept retirement language explicitly advisory: it warns about a selected version but neither rewrites a lockfile nor changes resolver eligibility.
- Left the generated `1.5.1` heading and Unreleased fold to Release Please and Plan 07, preserving the maintainer warning comment.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix docs --warnings-as-errors` could not run in this phase checkout because its existing development dependencies are absent. The command was attempted once after the sandbox TCP restriction was lifted and stopped before docs generation with Mix's existing "run `mix deps.get`" dependency errors. Static tuple, retirement-language, Unreleased-region, and `git diff --check` verification passed.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 07 can fold the staged notes into the Release Please-owned 1.5.1 section.
- A dependency-populated checkout is still needed to run the full documentation build.

## Self-Check: PASSED

- All six owned adopter-documentation files exist and the two task commits are present in Git history.

---
*Phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1*
*Completed: 2026-09-22*
