---
phase: 220-terminal-ratification
plan: 01
subsystem: ci
tags: [ci, evidence-anchor, cheerio, fast_checks, node]

# Dependency graph
requires:
  - phase: 219-baseline-recapture-canary-reconciliation
    provides: "Phase 219 recapture run 29051223765 discovered fast_checks red on branch (Cannot find module 'cheerio')"
provides:
  - "evidence-anchor-check.mjs no longer crashes on a bundle-free fast_checks checkout"
  - "Closed cheerio TODO (D-10 resolution)"
affects: [220-02, 220-03, 220-04, terminal-ship-pr]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Lazy/deferred require() placement to make a module order-independent of a later npm ci step in CI"]

key-files:
  created: []
  modified:
    - scripts/ci/evidence-anchor-check.mjs
    - .planning/todos/pending/2026-07-09-fastchecks-cheerio-missing-dep.md (moved)
    - .planning/todos/done/2026-07-09-fastchecks-cheerio-missing-dep.md (created via move)

key-decisions:
  - "D-10: relocate the runtime cheerio require to after the no-bundles guard, rather than reordering the ci.yml npm-ci step or adding cheerio to a root package.json"

patterns-established:
  - "Pattern: defer a subproject-scoped createRequire() resolution call to immediately before its first actual use, when an early-exit path in the same module doesn't need it — keeps the module runnable even when the dependency isn't installed yet at that point in the CI job"

requirements-completed: [RATIFY-01]

coverage:
  - id: D1
    description: "evidence-anchor-check.mjs resolves cheerio only after the no-bundles guard; a bundle-free invocation exits 0 without touching cheerio"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "node -e static-check (cheerio require line 107 > no-bundles guard line 99)"
        status: pass
      - kind: other
        ref: "node scripts/ci/evidence-anchor-check.mjs --bundles-dir <empty-dir> (exit 0)"
        status: pass
      - kind: other
        ref: "node scripts/ci/evidence-anchor-check.mjs (bundles present, PASS 132 bundles / 3808 findings)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The authoritative proof that fast_checks no longer crashes for lack of cheerio on a bundle-free CI checkout at ci.yml:145"
    requirement: "RATIFY-01"
    verification: []
    human_judgment: true
    rationale: "PI-2 (per plan): cheerio is present locally via test/example/priv/playwright, so the CI step-ordering crash is not locally reproducible. The authoritative signal is the fast_checks job on the terminal ship PR."
  - id: D3
    description: "Folded cheerio TODO closed — moved to done/ with status: done and a D-10 resolution note"
    requirement: "RATIFY-01"
    verification:
      - kind: other
        ref: "test -f .planning/todos/done/2026-07-09-fastchecks-cheerio-missing-dep.md && grep 'status: done'"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-09
status: complete
---

# Phase 220 Plan 01: Fix fast_checks cheerio break Summary

**Relocated the runtime `cheerio` require in `evidence-anchor-check.mjs` to after the no-bundles early-exit guard (D-10), so a bundle-free `fast_checks` checkout exits 0 without needing cheerio installed, while the deterministic evidence-anchor gate stays fully armed wherever bundles exist.**

## Performance

- **Duration:** ~6 min
- **Tasks:** 2 completed
- **Files modified:** 2 (1 code, 1 TODO moved)

## Accomplishments
- `scripts/ci/evidence-anchor-check.mjs` no longer throws `Cannot find module 'cheerio'` on a bundle-free checkout — the `_require('cheerio')` call moved from module-top (was line 47) to immediately after the `bundleDirs.length === 0` guard (now line 107, guard at line 99)
- Verified statically (require line > guard line), functionally (empty-bundles-dir run exits 0), and against local real bundles (PASS: 132 bundles, 3808 findings checked — gate stays armed)
- Closed the folded `2026-07-09-fastchecks-cheerio-missing-dep.md` TODO, moved from `pending/` to `done/` with a resolution note citing D-10 and Phase 220

## Task Commits

Each task was committed atomically:

1. **Task 1: Relocate the cheerio require below the no-bundles guard (D-10)** - `46e7b005` (fix)
2. **Task 2: Close the folded cheerio TODO (D-10)** - `ba9760a2` (docs)

**Plan metadata:** (final commit follows this SUMMARY)

## Files Created/Modified
- `scripts/ci/evidence-anchor-check.mjs` - cheerio's `_require('cheerio')` call relocated from module-top to immediately after the no-bundles early-exit guard; `createRequire(...)` factory binding left in place (it never resolves cheerio, only `_require('cheerio')` does)
- `.planning/todos/done/2026-07-09-fastchecks-cheerio-missing-dep.md` - moved from `pending/`, `status: done`, resolution note added citing D-10

## Decisions Made
- D-10 (locked by plan, applied as specified): fix via lazy-require relocation, not a ci.yml job reorder (rejected as fragile/positional) and not a new root `package.json` cheerio dependency (rejected — would add supply-chain surface for an already-present transitive dep)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both automated verification commands and the acceptance criteria in the plan passed on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The mechanical fix and static/local proof are complete. The authoritative confirmation — that `fast_checks` step 145 no longer crashes for lack of cheerio on a genuinely bundle-free CI checkout — is deferred to CI on the terminal ship PR per PI-2 (not locally reproducible, since cheerio is present locally via `test/example/priv/playwright`). This should be watched when 220's terminal PR runs `fast_checks`.
- No blockers for continuing to the next plan in Phase 220 (terminal-ratification).

---
*Phase: 220-terminal-ratification*
*Completed: 2026-07-09*
