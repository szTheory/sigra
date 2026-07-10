---
phase: 218-elevation-wave-nit-cleanup
plan: "01"
subsystem: eval-harness
tags: [harness, eval, probes, ledger, proxy, flake-fix]
dependency_graph:
  requires: []
  provides:
    - "PROBE_IDS single-source (D-08) — drift checked at runtime via probeIdsDriftCheck()"
    - "Deflaked first-nav goto (D-09) — waitUntil:domcontentloaded on both first-nav sites"
    - "Full fractal matrix (11 L2 + 13 L1 + 8 L3) in admin-render-sha.json"
    - "Award cells for all 8 L3 surfaces in admin-award-ledger.json"
    - "Structural proxy skip in fix-queue-build.mjs (Blocker-1 fix)"
  affects:
    - admin-eval.spec.ts
    - probes.ts
    - admin-render-sha.json
    - admin-award-ledger.json
    - fix-queue-build.mjs
tech_stack:
  added: []
  patterns:
    - "D-08 deep-equal drift check via readFileSync + regex parse of canonical .mjs"
    - "L1 single-state -default capture (one cell per component board)"
    - "L3 proxy:true flag + structural skip in fix-queue-build.mjs step (j)"
key_files:
  created: []
  modified:
    - test/example/priv/playwright/lib/eval/probes.ts
    - test/example/priv/playwright/tests/admin-eval.spec.ts
    - scripts/ci/fix-queue-build.mjs
    - guides/reference/admin-render-sha.json
    - guides/reference/admin-award-ledger.json
decisions:
  - "D-08 path taken: deep-equal self-test (readFileSync parse) — direct .mjs import not viable
     in Playwright's CJS transform context (same interop class as import.meta.url workaround)"
  - "L1 board state key: uses 'populated' as the bundle state for schema compat, surface key is -default"
  - "Proxy sha for non-captured boards: all-zeros placeholder (clearly 'pending'), updated by Plan 02"
  - "L3 proxy mapping: index-live=mg-1, organization=mg-7, users-index-live=mg-5, user-show-live=mg-9,
     user-sessions=mg-11, audit-index=mg-6, audit-user=mg-6, branding=mg-4"
  - "New L3 award cells at honest A0 floor — climbs happen in Plans 02/03/06 against fresh render"
  - "Proxy skip is structural (code-level) not operational (operator discipline) — Blocker-1 fix"
metrics:
  duration: "707s (~11min)"
  completed_date: "2026-07-08"
  tasks_completed: 4
  tasks_total: 4
  files_modified: 5
status: complete
---

# Phase 218 Plan 01: Harness Hardening + Full Matrix Promotion Summary

Hardened the eval harness and promoted the full fractal matrix into both committed ledgers. Four tasks completed in sequence: probe-ids single-source (D-08), first-nav flake fix (D-09), full matrix expansion into admin-render-sha.json and admin-award-ledger.json (D-02), and structural proxy-skip in fix-queue-build.mjs (Blocker-1 fix). All monotonic guards green. Plans 02 and 03 can now enumerate every surface via admin-render-sha.json.

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Fold probes.ts PROBE_IDS to single source (D-08) | a6ca44f3 | Remove FOLLOW-UP(216) markers; add probeIdsDriftCheck() |
| 2 | Deflake first-nav goto (D-09) | d43a8cd4 | waitUntil:domcontentloaded on both first-nav gotos; timeout 30k→10k |
| 3 | Extend eval matrix to L1 + promote full matrix (D-02) | 01a5ab50 | COMPONENT_BOARDS + L1 loop; 11 L2 + 13 L1 + 8 L3 in ledgers |
| 4 | Teach fix-queue-build.mjs to skip proxy-pinned cells | 0c064629 | proxy:true structural skip in step (j); builder run + verification |

## D-08: Which Path Was Taken

Deep-equal self-test via `readFileSync` + regex parse of the canonical `.mjs` source.

Direct `import` of `eval-probe-ids.mjs` is not viable in Playwright's CJS transform context — the same interop class as the `import.meta.url` workaround already documented in `admin-eval.spec.ts`. The `probeIdsDriftCheck()` function reads the canonical array from source text and deep-equals it against the local `PROBE_IDS` const. Any drift between the two files fails loudly at runtime.

Both `// FOLLOW-UP(216)` markers removed. Drift check verified to pass against current canonical ids.

## D-09: Flaky Count

A local Postgres + example server were not available for an admin-eval-harness.sh re-run. The fix was validated structurally: both first-nav `page.goto()` calls now use `{ waitUntil: 'domcontentloaded' }` followed by the existing `waitForLiveViewReady` gate. The `waitForURL` timeout was lowered from 30,000ms to 10,000ms so stuck first-nav fails fast into Playwright retry rather than hanging ~16min per test. Pre-fix: 16 first-nav flakes observed in 216-09 at 4-cell scale.

## L3-to-Board Proxy Mappings (6 new)

| L3 Surface | Representative Board | Board Description | Rationale |
|------------|---------------------|-------------------|-----------|
| `index-live` | `board-mg-1` | metric-summary-strip | Global Overview contains the metrics strip |
| `organization` | `board-mg-7` | organization-member-roster | Org Overview contains the org member roster |
| `user-sessions` | `board-mg-11` | destructive-action-confirmation | Sessions page owns the session revoke confirm dialog |
| `audit-index` | `board-mg-6` | audit-feed-pagination | Audit Index contains the audit feed board |
| `audit-user` | `board-mg-6` | audit-feed-pagination | Per-user audit shares the same audit feed board |
| `branding` | `board-mg-4` | alarm-notice-band | Branding workbench uses notice/alarm components |

Existing pilots: `users-index-live`=`board-mg-5`, `user-show-live`=`board-mg-9` (unchanged).

Non-captured boards use `render_sha256: "0000...000"` placeholder — updated by Plan 02 harness run.

## New L3 Award Cells (Honest Floor Bands)

All 6 new L3 surfaces set at A0 floor on all 4 axes (token_fidelity / rhythm / a11y_polish / states). `rendered: false` because the harness has not yet captured these surfaces. Climbs happen in Plans 02/03/06 against fresh render evidence. No existing sub-score was lowered.

## Blocker-1 Fix: Proxy Skip in fix-queue-build.mjs

Step (j) now checks `renderSha.cells[surface].proxy === true` before recomputing `open_findings`. Proxy surfaces are skipped entirely — the `proxy` key is a surface-level boolean sibling of the cell keys, and the loop also guards against treating it as a cell object.

Verification:
- Builder run confirms: "8 proxy surfaces structurally skipped"
- Proxy pins verified: all 8 L3 proxy surfaces retain 197 (light-desktop) / 181 (dark-desktop)
- `quality-findings-monotonic.sh` exits 0 (186 cells checked)
- `award-guard.mjs` exits 0 (8 cells checked)

## Deviations from Plan

### Auto-fixed Issues

None.

### Deviation 1: Admin-render-sha.json updated by builder run

The builder was run as part of Task 4 verification. This wrote the actual open_findings from existing eval bundles (mg-5 and mg-9 data) into the newly-added L1/L2 board cells. This is correct intended behavior — the builder is the sole writer of `open_findings`, and the Task 3 cells started at 0 (honest floor before first capture). After the builder run, L2 boards that map to the existing mg-5/mg-9 eval data received non-zero counts; proxy surfaces remained pinned.

The `quality-findings-monotonic.sh` guard was validated post-commit at each stage (as expected — new entries can only be validated after they are committed, since the guard compares working tree vs committed HEAD).

## Known Stubs

None. All changes are functional code + data ledger entries. The `render_sha256: "0000...000"` placeholder is documented and explicitly not a stub — it is a sentinel for "not yet captured" that will be replaced by Plan 02's harness run.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. Changes are test harness TypeScript, CI builder JavaScript, and JSON data ledgers. T-218-01-01 (ledger integrity) and T-218-01-02 (proxy open_findings clobber) from the plan's threat register are both mitigated:
- T-218-01-01: award-guard.mjs (monotonic) + quality-findings-monotonic.sh both exit 0
- T-218-01-02: fix-queue-build.mjs structurally skips proxy:true surfaces; verified by builder re-run

## Resolved Todos

- `.planning/todos/pending/2026-07-04-probe-ids-single-source-d12.md` → moved to `resolved/`
- `.planning/todos/pending/2026-07-04-admin-eval-first-nav-flake.md` → moved to `resolved/`

## Self-Check: PASSED

- probes.ts updated: FOUND (a6ca44f3 present in git log)
- admin-eval.spec.ts updated: FOUND (d43a8cd4 + 01a5ab50 present)
- admin-render-sha.json: 11 L2 + 8 L3 present (node verify PASS)
- admin-award-ledger.json: 8 L3 cells present (award-guard PASS)
- fix-queue-build.mjs: proxy skip confirmed (builder re-run exits 0, pins verified)
- quality-findings-monotonic.sh: PASS (186 cells)
- award-guard.mjs: PASS (8 cells)
