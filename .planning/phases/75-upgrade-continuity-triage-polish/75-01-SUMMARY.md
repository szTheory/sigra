---
phase: 75-upgrade-continuity-triage-polish
plan: 01
subsystem: docs
tags: [exdoc, upgrading, hexdocs]

requires: []
provides:
  - v1.12 upgrade stub guide and ExDoc extra registration
affects: []

tech-stack:
  added: []
  patterns:
    - "Hex-facing .planning pointers use GitHub blob URLs in shipped guides"

key-files:
  created:
    - guides/introduction/upgrading-to-v1.12.md
  modified:
    - mix.exs
    - docs/uat-ci-coverage.md

key-decisions:
  - "Replaced relative ../.planning/v1.12-UAT-EVIDENCE.md link in docs/uat-ci-coverage.md with blob URL so mix docs --warnings-as-errors passes (ExDoc cannot resolve .planning paths)."

patterns-established: []

requirements-completed:
  - TRN-01

duration: 15min
completed: 2026-04-23
---

# Phase 75 — Plan 01 Summary

**v1.12 upgrade stub (`upgrading-to-v1.12.md`) with trust-bundle blob links, registered in `mix.exs` extras, plus ExDoc-clean evidence pointer in `uat-ci-coverage.md`.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added thin v1.12 upgrade page matching 75-CONTEXT / plan verbatim structure.
- Inserted ExDoc extra immediately after v1.11 upgrade guide in `mix.exs`.
- Unblocked `mix docs --warnings-as-errors` by fixing broken file reference in `docs/uat-ci-coverage.md`.

## Task Commits

1. **Task 1: Add upgrading-to-v1.12.md** — `734c615` (docs)
2. **Task 2: Register extras + ExDoc gate** — `5ecbe5b` (docs; includes `uat-ci-coverage.md` blob-link fix)

## Deviations from Plan

### Auto-fixed Issues

**1. ExDoc undefined reference in `docs/uat-ci-coverage.md`**

- **Found during:** Task 2 (`mix docs --warnings-as-errors`)
- **Issue:** ExDoc warned on `../.planning/v1.12-UAT-EVIDENCE.md` (file not in doc bundle); build failed before v1.12-specific skip logic mattered.
- **Fix:** Use canonical GitHub blob URL for the evidence index in § v1.12 launch evidence.
- **Files modified:** `docs/uat-ci-coverage.md`
- **Verification:** `mix docs --warnings-as-errors` exits 0
- **Committed in:** `5ecbe5b`

**Total deviations:** 1 (required for green docs build)

## Issues Encountered

None beyond the ExDoc gate above.

## Next Phase Readiness

TRN-01 satisfied; TRN-02 can wire discovery links against the new guide.

## Self-Check: PASSED

- Acceptance greps for task 1 passed; `MIX_ENV=test mix compile --warnings-as-errors` passed.
- Task 2 line-order check passed; `mix docs --warnings-as-errors` passed.
- No `skip_undefined_reference_warnings_on` entry needed for `upgrading-to-v1.12.md`.

---
*Phase: 75-upgrade-continuity-triage-polish*
*Completed: 2026-04-23*
