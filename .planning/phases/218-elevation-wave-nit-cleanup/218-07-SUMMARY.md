---
phase: 218-elevation-wave-nit-cleanup
plan: 07
subsystem: testing
tags: [ci, determinism, fix-queue, node]

requires:
  - phase: 218-elevation-wave-nit-cleanup
    provides: 218-REVIEW.md CR-01 finding (systemic-parent rep selection is filesystem-order dependent)
provides:
  - Order-independent systemic-parent representative selection in fix-queue-build.mjs
  - Sorted readdirSync walks (sha/surface/cell) in walkFindings
  - Hermetic determinism regression test proving rep selection is order-independent
affects: [219-baseline-recapture-canary-reconciliation]

tech-stack:
  added: []
  patterns:
    - "Lowest-finding_id-wins tie-break for cross-surface systemic collapse (localeCompare-minimum over a copied array, never mutate the source array)"
    - "Forward + reverse seeding-order dual-run hermetic test pattern to prove order-independence without touching real repo files"

key-files:
  created: []
  modified:
    - scripts/ci/fix-queue-build.mjs
    - scripts/ci/fix-queue-build.test.mjs

key-decisions:
  - "Systemic-parent rep is chosen by lowest finding_id (localeCompare-minimum), not entries[0], eliminating dependence on readdirSync order"
  - "Also sorted the three readdirSync walks in walkFindings (belt-and-suspenders per CR-01) even though the rep fix alone is sufficient, since unsorted walks are still a latent order-dependence risk for any future entries[]-order-sensitive logic"
  - "Did NOT regenerate guides/reference/fix-queue.json in this plan — the eval bundle source dir is gitignored, so live-building here would clobber the 116-entry committed snapshot; fix is forward-only, applied at the next full-harness regeneration (Phase 219)"

requirements-completed: [ELEVATE-01]

coverage:
  - id: D1
    description: "fix-queue-build.mjs systemic-parent rep selection is order-independent (lowest finding_id of the group, not entries[0])"
    requirement: "ELEVATE-01"
    verification:
      - kind: unit
        ref: "scripts/ci/fix-queue-build.test.mjs#Test 5: CR-01 determinism — systemic parent finding_id is order-independent"
        status: pass
    human_judgment: false
  - id: D2
    description: "walkFindings directory walks (sha/surface/cell) are sorted for deterministic traversal"
    requirement: "ELEVATE-01"
    verification:
      - kind: unit
        ref: "scripts/ci/fix-queue-build.test.mjs (full suite, 36/36)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed guides/reference/fix-queue.json remains byte-unchanged (forward-only fix, no live regeneration against gitignored eval bundles)"
    requirement: "ELEVATE-01"
    verification:
      - kind: other
        ref: "git diff --exit-code -- guides/reference/fix-queue.json"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-07-09
status: complete
---

# Phase 218 Plan 07: Fix-Queue Determinism (CR-01) Summary

**Made the fix-queue builder's systemic-parent representative selection independent of filesystem/readdir order by picking the lowest finding_id instead of `entries[0]`, and proved it with a hermetic dual-seeding-order regression test.**

## Performance

- **Duration:** 12min
- **Started:** 2026-07-09T17:49:XX Z (approx, from init context)
- **Completed:** 2026-07-09T17:51:31Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments

- Closed the CR-01 critical determinism hole: `scripts/ci/fix-queue-build.mjs` no longer picks the systemic-parent rep as `entries[0]` (order-dependent on `readdirSync`); it now picks the entry with the lowest `finding_id` via `localeCompare` over a copied array.
- Sorted all three `readdirSync` walks in `walkFindings` (`evalDir`, `shaDir`, `surfDir`) so finding discovery order is deterministic on any filesystem (belt-and-suspenders alongside the rep fix).
- Added a hermetic regression test (Test 5) that seeds a 3-surface systemic group whose directory-name order diverges from finding_id order, runs the builder twice (forward and reverse seeding order), and asserts the resulting systemic parent `finding_id` is identical both times.
- Suite assertion count rose from 28/28 (baseline) to 36/36 (all green), comfortably exceeding the plan's >=29 floor.
- Confirmed the committed `guides/reference/fix-queue.json` is byte-unchanged (`git diff --exit-code` clean) — no live regeneration occurred since the eval bundle source directory is gitignored and not present in the repo.

## Task Commits

Each task was committed atomically:

1. **Task 1: Make systemic-parent rep selection order-independent in fix-queue-build.mjs** - `80dfb0f0` (fix)
2. **Task 2: Add a hermetic determinism regression test + prove the committed queue is untouched** - `7f2f65c7` (test)

_No TDD gate applies to this plan (`tdd` not set on either task); commits follow standard fix/test convention._

## Files Created/Modified

- `scripts/ci/fix-queue-build.mjs` - `walkFindings` walks sorted via `.sort()` on each `readdirSync` call; systemic-collapse branch now selects `rep` as the lowest-`finding_id` entry of the group (copied array, source `entries` left unmutated); inline comment at the collapse site updated to describe the new selection rule.
- `scripts/ci/fix-queue-build.test.mjs` - Added Test 5 (CR-01 determinism regression): seeds a systemic group across 3 surfaces with names/finding_ids in divergent sort orders, builds twice (forward + reverse seeding order), asserts identical systemic parent `finding_id` both times, plus a fixture-sanity assertion confirming the test setup actually exercises order divergence.

## Decisions Made

- Systemic-parent rep selection: lowest `finding_id` (localeCompare-minimum), computed from a copied array so the original `entries` ordering (used elsewhere for surface aggregation) is left untouched.
- Also sorted the `walkFindings` readdir walks even though the rep fix alone would have been sufficient for the reported CR-01 symptom — this removes a second latent order-dependence surface per the plan's "belt and suspenders" framing.
- Deliberately did not run the live builder against the real eval directory or touch `guides/reference/fix-queue.json` — the eval bundle source (`test/example/priv/playwright/eval/`) is gitignored and absent from the repo tree; running the builder here would read an empty/partial directory and clobber the 116-entry committed artifact. The determinism proof is entirely hermetic (mktemp workspace, `FQ_*` env overrides). The next full-harness regeneration (Phase 219) will emit the corrected deterministic ordering into the committed file.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `node scripts/ci/fix-queue-build.test.mjs` — 36/36 assertions pass (>=29 required), including the new determinism regression.
- `git diff --exit-code -- guides/reference/fix-queue.json` — clean, committed queue byte-unchanged.
- `node scripts/ci/award-guard.mjs` — PASS (32 cells), unaffected.
- `bash scripts/ci/quality-findings-monotonic.sh` — PASS (186 cells vs HEAD), unaffected.

## Self-Check: PASSED

- FOUND: scripts/ci/fix-queue-build.mjs
- FOUND: scripts/ci/fix-queue-build.test.mjs
- FOUND: commit 80dfb0f0
- FOUND: commit 7f2f65c7
