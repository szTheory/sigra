---
phase: 197-playwright-lanes-design-gallery-re-gate
plan: "02"
subsystem: ci
tags: [playwright, ci, failure-surfacing, guards, aggregator]
dependency_graph:
  requires: []
  provides: [guarded-playwright-seams, aggregator-gate, corrected-staging-guard]
  affects: [.github/workflows/ci.yml, example_playwright_smoke]
tech_stack:
  added: []
  patterns: [github-actions-step-guard, step-id-outcome, aggregator-pattern]
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Added if: ${{ !cancelled() }} + id: to each of 5 Playwright test steps so an early seam failure no longer masks later seams"
  - "Aggregator step uses if: always() and iterates steps.<id>.outcome; exits 1 on any failure to preserve hard-gate integrity"
  - "Staging step guard changed from if: success() to if: ${{ steps.admin_checkpoints.outcome == 'success' }} (Pitfall 4 fix)"
  - "webkit install retained (D-04: three mobile projects use iPhone 13 = webkit; drop is infeasible)"
  - "No matrix sharding added (D-03: serial workers:1 by design)"
  - "Criterion 1b (time reduction) is modestly met: webkit non-droppable, serial-by-design; reliability is the real win"
metrics:
  duration: "~2 minutes"
  completed: "2026-06-20"
  tasks_completed: 2
  files_modified: 1
status: complete
---

# Phase 197 Plan 02: PW-01 Failure-Surfacing Guards + Aggregator Summary

Guarded all 5 Playwright test seams in `example_playwright_smoke` with `!cancelled()` + step ids, added an `always()` aggregator that re-fails the job on any seam failure, and corrected the checkpoint-staging guard from `success()` to a seam-specific outcome check.

## What Was Built

PW-01 criterion 1a: an early Playwright seam failure no longer masks later seams. All 5 seams now run independently and surface their outcomes. The job still hard-gates via the aggregator step. The `Stage admin checkpoint PNGs` step now stages based on whether the checkpoints seam specifically passed, not on cumulative job success.

### Task 1: id + !cancelled() guard on all 5 test steps (D-01)

Each of the 5 `npx playwright test` steps in `example_playwright_smoke` received:
- A stable `id:` for outcome referencing by the aggregator
- `if: ${{ !cancelled() }}` so each seam runs unless the job was cancelled (not merely because a prior seam failed)

Step ids assigned:
- `admin_behavior` — Run admin behavior browser truth (chromium)
- `admin_checkpoints` — Run admin checkpoints (chromium, mobile, dark-chromium)
- `design_gallery` — Run design gallery boards (chromium, mobile, dark)
- `non_admin_smoke` — Run non-admin example browser smoke
- `demo_showcase` — Run demo-showcase spec (demo-showcase-chromium)

No `run:` bodies, `working-directory`, `env`, or `continue-on-error` keys were changed. webkit install at line 937 is unchanged.

Commit: `062525e2`

### Task 2: Aggregator step + corrected staging guard (D-02 / Pitfall 4)

**Aggregator "Aggregate Playwright step outcomes"** — added with `if: always()`, positioned before the `Dump example app log (on failure)` step. Its `run:` body:
1. Sets `set -euo pipefail`
2. Iterates all 5 step outcomes via `${{ steps.<id>.outcome }}`
3. Exits 1 with `::error::one or more Playwright seams failed` if any equals `failure`
4. Echoes "all seams passed" otherwise

This is the load-bearing integrity control for T-197-03: without it, `!cancelled()` guards would allow later seams to run after an early failure and the job would silently go green.

**Staging step guard fix** — `Stage admin checkpoint PNGs` step changed from:
```yaml
if: success()
```
to:
```yaml
if: ${{ steps.admin_checkpoints.outcome == 'success' }}
```
Pitfall 4: `success()` evaluates cumulative job status, which goes `failure` after any guarded seam fails — so the PNG staging was silently skipping even when the checkpoints seam itself passed. The seam-specific outcome check decouples staging from unrelated seam failures.

Commit: `e657a514`

## Verification Results

| Check | Result |
|-------|--------|
| `grep -cE 'if: \$\{\{ !cancelled\(\) \}\}'` >= 5 | PASS (5) |
| Aggregator step exists with `if: always()` | PASS |
| Aggregator references all 5 step outcome ids | PASS (all 5) |
| Aggregator exits 1 on failure | PASS |
| Staging guard is `steps.admin_checkpoints.outcome == 'success'` | PASS |
| webkit install unchanged | PASS (line 937) |
| YAML valid (`python3 yaml.safe_load`) | PASS |
| phase_58 ExUnit contract test | PASS (1 test, 0 failures) |

## Deviations from Plan

None — plan executed exactly as written.

## Success Criteria Assessment

**PW-01 criterion 1a** — MET: an early-step failure no longer masks later steps. All 5 seams run independently under `!cancelled()` guards and expose their outcomes via step ids. The job hard-gates via the `always()` aggregator.

**PW-01 criterion 1b** — MODESTLY MET (as designed): webkit cannot be dropped (three mobile projects use `iPhone 13` = webkit; D-04 lever b is infeasible). The 5 launches are serial by design (`workers:1`, disjoint `--project` sets), so launch consolidation yields near-zero wall-clock improvement. The real win is reliability (all failures surface in one run), not time reduction. No time-reduction target encoded as a must_have per plan objective.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. Edits are confined to workflow YAML.

## Self-Check: PASSED

- `.github/workflows/ci.yml` — modified (verified)
- Commit `062525e2` — exists (Task 1)
- Commit `e657a514` — exists (Task 2)
