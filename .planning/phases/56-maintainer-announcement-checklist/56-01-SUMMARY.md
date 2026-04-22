---
phase: 56-maintainer-announcement-checklist
plan: 01
subsystem: infra
tags:
  - maintaining
  - hexdocs
  - documentation
  - release-process

requires: []
provides:
  - MAINT-01 announcement checklist in MAINTAINING.md with Ship vs Announce, roles, tag-scoped .planning evidence URLs, and optional comms guidance
affects:
  - maintainer-docs
tech-stack:
  added: []
  patterns:
    - "HexDocs-safe links: relative for packaged docs; tag GitHub blob URLs for .planning evidence"
key-files:
  created: []
  modified:
    - MAINTAINING.md
key-decisions:
  - "Used GitHub-style heading anchors for in-doc cross-links to Release automation, Manual release, and Installer golden sections"
patterns-established:
  - "First public launch section sits between Release automation and Manual release per D-01"
requirements-completed:
  - MAINT-01
duration: 25min
completed: 2026-04-22
---

# Phase 56: Maintainer announcement checklist — Plan 01 summary

**MAINT-01: `MAINTAINING.md` now routes first public Hex shippers through Release automation, then a role-based First public launch checklist with tag-pinned GA evidence and explicitly optional comms rows.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-22 (session)
- **Completed:** 2026-04-22
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Intro sentence under `# Maintaining Sigra` ties first public Hex release to **Release automation** and **`First public launch (announcement checklist)`** before the installer golden section.
- New **First public launch** section with link policy, Assignment (Release captain + Roster), Ship table (in-doc anchors + v0.2.0 blob URLs + packaged docs), and optional Announce rows with D-16 tone guardrails.

## Task commits

1. **Task 1: Maintainer intro — discoverability sentence** — `05b0083` (docs)
2. **Task 2: First public launch (announcement checklist) section body** — `db6d65d` (docs)

## Files created/modified

- `MAINTAINING.md` — Maintainer runbook extended for first public launch without duplicating ship numbered steps.

## Decisions made

- Followed plan anchors `#release-automation-default`, `#manual-release-checklist-emergency-or-pre-automation`, `#installer-golden-ci-contract-phase-50` for GitHub preview compatibility.

## Deviations from plan

None — plan executed as written.

## Issues encountered

None.

## Next phase readiness

Maintainer announcement checklist is in-repo; no USER-SETUP.

## Self-check: PASSED

All plan `<acceptance_criteria>` greps and `mix compile --warnings-as-errors` / `mix docs --warnings-as-errors` were re-run successfully after Task 2.

---
*Phase: 56-maintainer-announcement-checklist*
