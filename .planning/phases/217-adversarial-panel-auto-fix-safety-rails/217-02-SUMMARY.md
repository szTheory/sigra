---
phase: 217-adversarial-panel-auto-fix-safety-rails
plan: "02"
subsystem: fix-queue
tags: [fix-queue, open-findings, tdd, autofix, harness, d-12]
requires: ["217-01"]
provides: [fix-queue-build.mjs, fix-queue-lint.sh, fix-queue.json, harness-chain]
affects:
  - scripts/ci/fix-queue-build.mjs
  - scripts/ci/fix-queue-lint.sh
  - scripts/ci/admin-eval-harness.sh
  - guides/reference/fix-queue.json
  - guides/reference/admin-render-sha.json
tech_stack:
  added: []
  patterns:
    - "TDD RED/GREEN for fix-queue-build.mjs and fix-queue-lint.sh"
    - "Sole-writer D-12: fix-queue-build.mjs is the only open_findings writer"
    - "Systemic collapse: anchor recurring across >=2 surfaces -> ONE parent (floated top)"
    - "Derived-field guard: fix-queue-lint.sh recomputes auto_eligible/priority, fails on drift"
    - "Pitfall-3 ordering: fix-queue-build.mjs chains before quality-findings-monotonic.sh"
key_files:
  created:
    - scripts/ci/fix-queue-build.mjs
    - scripts/ci/fix-queue-build.test.mjs
    - scripts/ci/fix-queue-lint.sh
    - scripts/ci/fix-queue-lint.test.sh
    - guides/reference/fix-queue.json
  modified:
    - scripts/ci/admin-eval-harness.sh
    - guides/reference/admin-render-sha.json
decisions:
  - "fix-queue-build.mjs is the SOLE writer of open_findings in admin-render-sha.json (D-12)"
  - "Systemic collapse: same (class, anchor) on >=2 surfaces -> ONE high-priority parent entry"
  - "fix_class taxonomy for probe findings: off-scale-radius-shadow-control=token; focus-ring=component; class-chain-anchored=judgment; all others=judgment"
  - "open_findings per cell = unique finding_ids (pre-collapse) for that cell key across all boards, minus settled"
  - "fix-queue-lint.sh uses total_uncollapsed (sum of surfaces_affected.length for systemic + 1 per normal) as the upper bound for open_findings validation"
metrics:
  duration: "13m 30s"
  completed: "2026-07-04T18:18:55Z"
  tasks_completed: 3
  files_created: 5
  files_modified: 2
status: complete
---

# Phase 217 Plan 02: Fix Queue + Sole open_findings Writer Summary

Deterministic fix queue built: `fix-queue-build.mjs` derives `guides/reference/fix-queue.json` from findings.json bundles (open = built - settled), becomes the sole writer of `open_findings` in `admin-render-sha.json`, collapses cross-surface anchors into systemic parents; `fix-queue-lint.sh` recomputes every derived field; harness chains the builder before `quality-findings-monotonic.sh` (Pitfall 3).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| T1 RED | fix-queue-build.test.mjs failing tests | 3948b1c1 | scripts/ci/fix-queue-build.test.mjs |
| T1 GREEN | fix-queue-build.mjs sole writer + fix-queue.json | efdae465 | scripts/ci/fix-queue-build.mjs, scripts/ci/fix-queue-build.test.mjs, guides/reference/fix-queue.json, guides/reference/admin-render-sha.json |
| T2 RED | fix-queue-lint.test.sh failing tests | 136b606d | scripts/ci/fix-queue-lint.test.sh |
| T2 GREEN | fix-queue-lint.sh recomputes derived fields | 7cb2a466 | scripts/ci/fix-queue-lint.sh |
| T3 | Chain builder into harness (Pitfall 3 ordering) | 94668814 | scripts/ci/admin-eval-harness.sh |

## Verification Results

All plan verification criteria pass:

- `node scripts/ci/fix-queue-build.test.mjs` — 28/28 PASS
- `bash scripts/ci/fix-queue-lint.test.sh` — 4/4 PASS
- `bash scripts/ci/fix-queue-lint.sh` — PASS (116 queue entries validated)
- `bash scripts/ci/quality-findings-monotonic.sh --base HEAD` — PASS (16 cells checked)
- `grep -rn 'admin-panel.sh|admin-autofix-loop.sh' .github/workflows/*.yml` — no matches (no new CI wiring)

## Key Design Decisions

**1. fix_class taxonomy for probe findings**
The existing probe classes map as follows:
- `off-scale-radius-shadow-control` → `token` (off-scale CSS value; auto-eligible)
- `focus-ring` → `component` (component fix needed; human queue)
- `misalignment`, `below-fold-primary`, `size-weight-budget` → `judgment` (human queue)
- Class-chain-anchored anchors (`[class*=...]`) → always `judgment` per D-12 (auto-editing `class=` would change the finding_id that identifies them)
- `copy` reserved for panel findings (no current probe class maps to copy)

**2. Systemic collapse algorithm**
Group by `systemic_group = sha256(class + NUL + anchor)`. Any group with unique anchor appearing across >=2 distinct board surfaces produces ONE high-priority parent entry (floated to top) with `surfaces_affected: [...]`. The 116 queue entries include 84 systemic parents and 32 normal single-surface findings.

**3. open_findings per cell (before vs after collapse)**
The admin-render-sha.json open_findings values are the PER-CELL unique finding_id counts BEFORE systemic collapse (raw deduplicated count per cell key). The fix queue (116 entries) uses systemic collapse so its length is smaller. The lint guard validates open_findings against `total_uncollapsed` = sum(surfaces_affected.length for systemic) + count(normal) — NOT against queue.length, which would be incorrect.

**4. Old open_findings writers removed**
Prior to this plan, `open_findings` in admin-render-sha.json was hand-maintained (869/784 — clearly stale). Now the sole writer is `fix-queue-build.mjs`, which computed the correct values: 197 (light cells) and 181 (dark cells), derived from actual bundle data via deduplication by finding_id.

**5. Pitfall 3 ordering**
`fix-queue-build.mjs` is chained as Phase (a2) in the harness — after Playwright writes bundles but before `quality-findings-monotonic.sh` reads `open_findings`. This ensures no window where `open_findings` is unset or stale when the monotonic guard runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test workspace uses wrong eval dir level**
- **Found during:** Task 1 GREEN (test debugging)
- **Issue:** The test fixture was passing `FQ_EVAL_DIR = workDir/eval/sha` (sha-level) but the builder expects `workDir/eval` (top-level containing sha dirs)
- **Fix:** Updated `makeWorkspace` to pass `join(workDir, 'eval')` as `FQ_EVAL_DIR` instead of the sha-level path
- **Files modified:** `scripts/ci/fix-queue-build.test.mjs`
- **Commit:** efdae465

**2. [Rule 1 - Bug] Lint open_findings check used queue.length as upper bound (incorrect)**
- **Found during:** Task 2 GREEN (real data test)
- **Issue:** `queue.length=116` (after systemic collapse) < `open_findings=197` (pre-collapse per-cell count), causing false failures on real data
- **Fix:** Replaced `queue.length` upper bound with `total_uncollapsed` = sum(systemic surfaces_affected.length) + count(normal entries) — the pre-collapse count that correctly bounds per-cell open_findings
- **Files modified:** `scripts/ci/fix-queue-lint.sh`
- **Commit:** 7cb2a466

**3. [Rule 1 - Bug] Shell apostrophe in Node -e code causes syntax error**
- **Found during:** Task 2 GREEN (Test 4 debugging)
- **Issue:** Comment text "it can't" with apostrophe in the Node `-e` inline code caused `SyntaxError: Unexpected end of input` when the shell expanded the single-quoted heredoc
- **Fix:** Replaced "it can't" with "it cannot" in the comment
- **Files modified:** `scripts/ci/fix-queue-lint.sh`
- **Commit:** 7cb2a466

## Known Stubs

None. All outputs are fully derived from real bundle data.

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag: drift-window-closed | guides/reference/admin-render-sha.json | open_findings now derived by sole writer (T-217-02-DRIFT mitigated; dual-writer window eliminated) |

T-217-02-EOP (panel findings inflating open_findings): confirmed mitigated — builder reads only `findings.json`, never `panel-findings.json`.
T-217-02-PARSE (JSON/TSV parsing): confirmed mitigated — JSON.parse only, no shell interpolation of finding text.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| scripts/ci/fix-queue-build.mjs | FOUND |
| scripts/ci/fix-queue-build.test.mjs | FOUND |
| scripts/ci/fix-queue-lint.sh | FOUND |
| scripts/ci/fix-queue-lint.test.sh | FOUND |
| guides/reference/fix-queue.json | FOUND |
| guides/reference/admin-render-sha.json | FOUND |
| scripts/ci/admin-eval-harness.sh | FOUND |
| commit 3948b1c1 (T1 RED) | FOUND |
| commit efdae465 (T1 GREEN) | FOUND |
| commit 136b606d (T2 RED) | FOUND |
| commit 7cb2a466 (T2 GREEN) | FOUND |
| commit 94668814 (T3 harness chain) | FOUND |
