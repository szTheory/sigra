---
phase: 055-readme-exdoc-entry-paths
plan: 01
subsystem: docs
tags: [readme, security, ga, hexdocs]

requires: []
provides:
  - Root SECURITY.md for coordinated disclosure
  - README "Production readiness & GA evidence" with Executed/Waived framing and tag-scoped evidence URLs
affects: [hexdocs-readers, integrators]

key-files:
  created:
    - SECURITY.md
  modified:
    - README.md

key-decisions:
  - "ExDoc resolves local .md links only for registered extras; README UAT pointer uses (uat-ci-coverage.md) once that extra exists (phase 02 wiring)."
  - "Tag-scoped GitHub blob URLs (v0.2.0) for .planning evidence in README per D-05."

requirements-completed: [DOC-01]

duration: 25min
completed: 2026-04-22
---

# Phase 55 Plan 01 Summary

**DOC-01:** README now carries an above-the-fold **Production readiness & GA evidence** map with honest Executed/Waived language, tag-scoped pointers to v1.4 planning artifacts, a HexDocs bridge to `ga-evidence`, and a coordinated-disclosure path via new **SECURITY.md**.

## Task Commits

Implementation delivered with repo commits tagged `docs(phase-55): …` (see `git log --grep=55`).

## Self-Check: PASSED

- `mix compile --warnings-as-errors` — PASS
- `MIX_ENV=dev mix docs --warnings-as-errors` — PASS (after extras + link hygiene in plan 02 companion commit)
- Plan acceptance greps for SECURITY.md and README section — PASS

## Deviations

- **ExDoc link model:** Relative `](docs/uat-ci-coverage.md)` and `](.planning/...)` links in published extras fail ExDoc basename resolution; resolved by registering `docs/uat-ci-coverage.md` as an extra and using `(uat-ci-coverage.md)` in README, plus GitHub URLs for `.planning/` targets in other extras (see plan 02 / MAINTAINING / CHANGELOG / audit-semantics edits).
