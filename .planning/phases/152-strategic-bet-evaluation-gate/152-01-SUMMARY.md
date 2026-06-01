---
phase: "152"
plan: "01"
subsystem: "planning"
tags:
  - "strategic-bets"
  - "scim"
  - "lockspire"
  - "threadline"
dependency_graph:
  requires: ["STRAT-01", "STRAT-02", "STRAT-03"]
  provides: ["Strategic bet evaluation decisions"]
  affects: []
tech_stack:
  added: []
  patterns: []
key_files:
  created:
    - ".planning/decisions/002-strategic-bets-v1.33.md"
  modified: []
metrics:
  duration_minutes: 2
  completed_at: "2026-06-01T21:23:33Z"
---

# Phase 152 Plan 01: Create Strategic Bets Evaluation Document Summary

Created the formal evaluation document for v1.33 strategic bets to enforce the Diminishing Returns Wall criteria for greenfield enterprise feature requests.

## Key Decisions

- **Diminishing Returns Wall**: Overriding requires an enterprise adopter contract explicitly blocked by the lack of the feature.
- **SCIM**: Deferred until explicitly blocked. Scope restricted to adopting `ex_scim` instead of a custom minimal implementation.
- **sigra_lockspire Glue**: Deferred until both libraries are fully stable.
- **Threadline Correlation**: Deferred until a stable upstream injection seam exists.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED
