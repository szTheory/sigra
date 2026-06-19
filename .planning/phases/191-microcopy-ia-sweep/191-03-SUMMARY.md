---
phase: 191-microcopy-ia-sweep
plan: "03"
subsystem: admin-quality-ledger
tags: [quality-ledger, branding-live, d9-ia, d10-microcopy, monotonic-guard]
depends_on: [191-02]
requires: [COPY-01, COPY-03]
provides: [branding-live-l3-row, d9-d10-rescore]
affects:
  - guides/reference/admin-quality-ledger.md
tech_stack:
  added: []
  patterns: [ledger-row-append, monotonic-guard]
key_files:
  created: []
  modified:
    - guides/reference/admin-quality-ledger.md
decisions:
  - "branding-live L3 row appended at Tier 1 — page passes all required L3 axes but has not undergone an award-grade micro-interaction pass; compliance, not award-grade"
  - "D9/D10 re-score on all 6 existing L3 rows: all remain Tier 1 — the Phase 191 voice pass delivers compliance, not award-grade differentiation"
  - "Evidence for branding-live: admin-modal-interaction ConfirmDialog APG gates + Phase 191 voice pass inline notation (no dedicated checkpoint PNG, branding_live not in the 8 standard checkpoints)"
  - "No tier values decreased; monotonic guard passes 35 cells vs HEAD"
metrics:
  duration: "3 minutes"
  completed: "2026-06-18"
  tasks_completed: 1
  tasks_total: 1
  files_created: 0
  files_modified: 1
status: complete
---

# Phase 191 Plan 03: Quality Ledger Branding-Live Row + D9/D10 Re-score Summary

Added the `branding-live` L3 row to the admin quality ledger (D-11 deliverable), closing the maintainer-pinned explicit-scoring todo deferred from Phase 189. Re-scored existing L3 rows on D9 IA and D10 Microcopy axes — all remain Tier 1 (compliant, not award-grade). Monotonic guard passes.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add branding-live L3 row and re-score D9/D10 on all L3 rows | 975218f4 | guides/reference/admin-quality-ledger.md |

## What Was Built

### Task 1 — Admin quality ledger update

**guides/reference/admin-quality-ledger.md — 1 row addition:**
- Appended `branding-live` L3 row at Tier 1, after `audit-user-live`, before the L4 rows
- Evidence: `admin-modal-interaction.spec.ts` (ConfirmDialog APG gates + axe-while-open) + Phase 191 voice pass inline notation (D9 IA: GOV.UK page arch, verb-first, scope-visible; D10 Microcopy: brand-book-aligned, no leaked internals, no synonym drift)
- L3 row count: 6 → 7

**D9/D10 re-score assessment for all 7 L3 rows:**

| Row | Pre-pass tier | Post-pass tier | Rationale |
|-----|--------------|---------------|-----------|
| index-live | 1 | 1 | Copy now passes D9/D10 rubric; terse, verb-first, no drift. Compliant, not award-grade. |
| organization-live | 1 | 1 | Same. "organization" spelled out, member/user boundary respected post-pass. |
| users-index-live | 1 | 1 | Same. chip_label coherence added (COPY-03). |
| user-show-live | 1 | 1 | Improved: passive voice removed, leaked internal fixed (WR-04), session-count heading clarified. Within Ratified bar. |
| audit-index-live | 1 | 1 | 0 violations pre-pass; no change needed. |
| audit-user-live | 1 | 1 | 0 violations pre-pass; no change needed. |
| branding-live | — | 1 | New row. Tier 1: passes required L3 axes; no award-grade polish pass yet. |

**No existing tier values changed.** The monotonic guard confirms no regressions.

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "branding-live" guides/reference/admin-quality-ledger.md` = 1 | PASS |
| L3 row count = 7 (was 6) | PASS |
| branding-live tier = 1 (integer, column 4) | PASS |
| No existing tier decreased | PASS |
| `bash scripts/ci/quality-ledger-monotonic.sh` exits 0 — 35 cells checked | PASS |

## Deviations from Plan

None. Plan executed exactly as written.

## Known Stubs

None. The `branding-live` row is fully wired with executable evidence references. No placeholder copy or TODOs remain.

## Threat Flags

None. This plan modifies only the quality ledger documentation file (no auth-boundary strings, no runtime code, no package installs). The T-191-04 mitigation (monotonic guard) was verified: `quality-ledger-monotonic.sh` exits 0.

## Self-Check: PASSED

- guides/reference/admin-quality-ledger.md exists: FOUND
- Commit 975218f4 exists: FOUND
- `grep -c "branding-live" guides/reference/admin-quality-ledger.md` = 1: CONFIRMED
- L3 rows = 7: CONFIRMED
- `bash scripts/ci/quality-ledger-monotonic.sh` exits 0: CONFIRMED
- No deletions in commit: CONFIRMED
- No untracked files: CONFIRMED
