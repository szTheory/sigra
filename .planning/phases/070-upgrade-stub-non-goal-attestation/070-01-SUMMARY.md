---
phase: 070-upgrade-stub-non-goal-attestation
plan: "01"
subsystem: docs
tags: [exdoc, upgrading, v1.10, planning-milestones]

requires: []
provides:
  - v1.10 upgrade guide aligned with v1.8 stub conventions
  - ExDoc extras registration after upgrading-to-v1.8.md
affects: []

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - guides/introduction/upgrading-to-v1.10.md
  modified:
    - mix.exs

key-decisions:
  - "ExDoc 0.40 validates local markdown links only for registered extras; skip_undefined_reference_warnings_on on the new guide allows relative `.planning/` links without pulling milestone files into the extras bundle."

patterns-established: []

requirements-completed:
  - ACF-05

duration: 15min
completed: 2026-04-23
---

# Phase 70 plan 01 summary

**Shipped the v1.10 upgrade stub and wired it into ExDoc** so adopters see the same planning-milestone vs Hex SemVer framing as earlier upgrade pages, with working `mix docs --warnings-as-errors`.

## Performance

- **Tasks:** 2
- **Files modified:** 2

## Task commits

Single commit bundles both tasks (task 1’s `mix docs` verify requires the extra to be registered first).

1. **Add upgrading-to-v1.10.md + mix.exs** — see git log `070-01`

## Files created/modified

- `guides/introduction/upgrading-to-v1.10.md` — v1.9 pointer, checklist, see-also links to v1.8/v1.7 HTML, adopter scope link
- `mix.exs` — extras entry after `upgrading-to-v1.8.md`; `skip_undefined_reference_warnings_on` for that guide

## Verification

- Plan acceptance greps: PASS
- `MIX_ENV=dev mix docs --warnings-as-errors`: PASS

## Self-Check: PASSED
