---
phase: 216-harness-foundation-award-gradient
plan: "02"
subsystem: admin-eval-harness
tags: [ledger, award-gradient, finding-id, schema, data]
dependency_graph:
  requires: [216-01]
  provides: [admin-award-ledger.json, settled-findings.tsv, admin-render-sha.json, admin-eval-schema.md]
  affects: [guides/reference/admin-quality-ledger.md]
tech_stack:
  added: []
  patterns: [forward-only-ledger, finding-id-contract, award-band-min-axes, tsv-suppression-set]
key_files:
  created:
    - guides/reference/admin-award-ledger.json
    - guides/reference/admin-render-sha.json
    - guides/reference/settled-findings.tsv
    - guides/reference/admin-eval-schema.md
  modified:
    - guides/reference/admin-quality-ledger.md
decisions:
  - "Award band floor A0 on all four axes at phase start (token_fidelity/rhythm/a11y_polish/states); climbing happens only against a fresh render in Plan 07"
  - "render_sha256 and open_findings consolidated in admin-render-sha.json (not split) so quality-findings-monotonic.sh has ONE authoritative source"
  - "finding_id = sha256(surface NUL class NUL anchor) locked as 216 substrate key; Phase 217 must match this — seam flagged UNRESOLVED in admin-eval-schema.md per D-22"
  - "Tier column-4 grammar frozen; award data in JSON sibling only; no 5th column, no decorator"
  - "Pilots capped at A2 (not A3) per D-25 since persona-JTBD panel not re-run at HEAD"
metrics:
  duration: "~5 minutes"
  completed_date: "2026-07-03"
  tasks_completed: 3
  files_created: 4
  files_modified: 1
status: complete
---

# Phase 216 Plan 02: Schema Ledgers + finding_id Contract Summary

Committed four schema artifacts (award-ledger JSON, render-sha JSON, settled-findings TSV, eval-schema doc) and appended cross-references to the markdown ledger's two pilot cells — locking the forward-only signal grammar and the cross-phase finding_id contract before the guards in Wave 2 consume them.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author admin-award-ledger.json + admin-render-sha.json with two pilot surfaces | 8498f785 | guides/reference/admin-award-ledger.json, guides/reference/admin-render-sha.json |
| 2 | Author settled-findings.tsv + finding_id key contract doc (cross-phase-217 seam) | 3fba7135 | guides/reference/settled-findings.tsv, guides/reference/admin-eval-schema.md |
| 3 | Cross-reference JSON award ledger from markdown ledger without touching column-4 grammar | 8b80927e | guides/reference/admin-quality-ledger.md |

## What Was Built

**admin-award-ledger.json** — Award vector store, schema_version 1, with `users-index-live` and `user-show-live` seeded at floor band A0 on all four axes. `band` is the derived `min(axes)`; `rendered: false`; `verified_at_sha: null`; `evidence_ref: []`. A `notes` field points to `admin-eval-schema.md`. Schema validation: `node -e` confirms `band == min(axes)` and `rendered` is boolean for each cell.

**admin-render-sha.json** — Render SHA256 + open-finding count store, schema_version 1. Cells keyed `<theme>-<viewport>-<state>` (8 cells each for `light-desktop-*` and `dark-desktop-*` × 4 states per pilot surface). All `render_sha256: null`, `open_findings: 0` — populated by the harness in Plan 07. Consolidation rationale documented in both the file's `notes` field and in `admin-eval-schema.md`.

**settled-findings.tsv** — Suppression set with 7-column header comment (`finding_id`, `surface`, `class`, `anchor`, `disposition`, `waived_by`, `note`), zero data rows (correct — no findings are settled at phase start). The file is sorted by `finding_id` trivially (no data). Ready for `settled-findings-lint.sh` (Plan 04) to target.

**admin-eval-schema.md** — Human-readable contract document covering:
- `finding_id = sha256(surface + "\0" + class + "\0" + anchor)` byte-level formula with Node.js code snippet
- Cross-phase 217 seam flagged as UNRESOLVED (D-22): 216 substrate uses `class`, 217 requirement text says `lens+question`; reconciliation path recommended but not decided unilaterally
- Ledger authoritative-role table (which file each guard reads)
- A0..A3 band semantics (additive) + `band = min(axes)` + `Open = total − settled` rules
- Anchor-identity rule (structural selector / `data-*` hook, never prose/line-number)
- TSV column specification and lint invariants
- Both JSON schemas with comment annotations

**admin-quality-ledger.md** — Two edits only:
- `users-index-live` evidence column: appended one sentence cross-referencing `admin-award-ledger.json`
- `user-show-live` evidence column: appended one sentence cross-referencing `admin-award-ledger.json`
- New prose subsection "Award Sub-Score (Phase 216+)" explaining award data is in the JSON sibling, tier column-4 is frozen at bare `[012]`, and pointing to `admin-eval-schema.md`
- No tier values changed; no 5th column; no decorators; `quality-ledger-monotonic.sh --base HEAD` PASS (36 cells)

## Deviations from Plan

None — plan executed exactly as written. All four artifacts created per specification, column-4 grammar preserved, monotonic guard verified.

## Threat Mitigations Implemented

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-216-02-DECOR | Award data placed in JSON sibling only; column-4 grammar explicitly preserved; monotonic guard verified after edit (36 cells PASS) |
| T-216-02-KEY | finding_id formula written byte-level exactly in admin-eval-schema.md; Phase 217 seam flagged UNRESOLVED as required by D-22 — not silently resolved |
| T-216-02-SETTLE | Empty-at-start suppression set; columns include `disposition` + `waived_by` + `note` for attributability; zero pre-waived findings |
| T-216-02-BAND | band == min(axes) authored and schema-verified by node check; band is documented as derived-not-typed |

## Downstream Consumer Map

| Artifact | Consumed By | When |
|----------|-------------|------|
| admin-award-ledger.json | `scripts/ci/award-guard.mjs` (Plan 05) | fast_checks lane |
| admin-render-sha.json | `scripts/ci/stale-render-guard.sh` (Plan 04), `scripts/ci/quality-findings-monotonic.sh` (Plan 04) | fast_checks lane |
| settled-findings.tsv | `scripts/ci/settled-findings-lint.sh` (Plan 04), Phase 217 AUTOFIX-01 fix-queue | fast_checks lane / Phase 217 |
| admin-eval-schema.md | Phase 217 planning (finding_id reconciliation) | Joint 216/217 planning |
| admin-quality-ledger.md xref | Human discoverability; guard unchanged | N/A (no new machine consumer) |

## Known Stubs

- `admin-award-ledger.json`: all axes `A0`, `rendered: false`, `verified_at_sha: null`, `evidence_ref: []` — intentional skeleton; climbing to A1/A2 happens in Plan 07 against fresh renders
- `admin-render-sha.json`: all `render_sha256: null`, `open_findings: 0` — intentional skeleton; populated by harness in Plan 07

These stubs are by-design for this plan (data/schema-only plan; guards and render harness land in Plans 04/05/07). They do NOT prevent the plan's goal (locking the schema grammar before Wave 2 guards are written).

## Threat Flags

None — this plan creates no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. All artifacts are committed reference files read by CI guards.

## Self-Check: PASSED

- [x] guides/reference/admin-award-ledger.json — FOUND
- [x] guides/reference/admin-render-sha.json — FOUND
- [x] guides/reference/settled-findings.tsv — FOUND
- [x] guides/reference/admin-eval-schema.md — FOUND
- [x] guides/reference/admin-quality-ledger.md xref — FOUND
- [x] Task 1 commit 8498f785 — FOUND
- [x] Task 2 commit 3fba7135 — FOUND
- [x] Task 3 commit 8b80927e — FOUND
