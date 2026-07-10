---
phase: 216-harness-foundation-award-gradient
plan: "08"
subsystem: admin-eval-harness
tags: [probe-engine, board-scoping, gap-closure, evidence-anchor, d22-finding-shape]
dependency_graph:
  requires: [216-06-SUMMARY.md, 216-07-SUMMARY.md]
  provides: [board-scoped-probes, d22-findings-shape, w1-anchor-check-fix]
  affects: [evidence-anchor-check, admin-eval-spec, probe-engine, 216-09-PLAN.md]
tech_stack:
  added: []
  patterns:
    - "boardRoot?.querySelectorAll pattern: probe element-scan uses document.querySelector(sel) || document as root"
    - "AxeBuilder.include(boardRoot): board-scoped axe analysis"
    - "enrichFindingsForBundle: sha256(surface NUL class NUL anchor) D-22 finding_id"
    - "findingRef fallback: finding_id || [surface, effectiveClass, anchor].filter(Boolean).join('::')"
key_files:
  modified:
    - test/example/priv/playwright/lib/eval/probes.ts
    - test/example/priv/playwright/tests/admin-eval.spec.ts
    - scripts/ci/evidence-anchor-check.mjs
    - scripts/ci/evidence-anchor-check.test.mjs
decisions:
  - "Gap 1 fix: board-scope all element-scan probes via boardRoot arg; design-token reads remain global on document.documentElement"
  - "D-22 enrichment: enrichFindingsForBundle called in writeBundleLocal before writing findings.json; adds class/surface/finding_id; keeps probe_class for gate/warn split compat"
  - "GEOMETRY_ONLY_CLASSES updated to 'below-fold-primary' (was stale 'below-fold' that matched no emitter)"
  - "evidence-anchor-check reads probe_class as fallback for class (effectiveClass) so raw emitter shape never prints undefined"
  - "D-12 PROBE_IDS import deferred: CJS/ESM interop risk with Playwright transform; FOLLOW-UP marker in probes.ts"
metrics:
  duration: "~10m"
  completed: "2026-07-04"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 4
status: complete
---

# Phase 216 Plan 08: Board-Root Probe Scoping + D-22 Finding Shape (Gap 1 + W1) Summary

**One-liner:** Board-root-scoped probe engine (all 9 probes query boardRoot subtree) + D-22 finding enrichment (finding_id/surface/class) + W1 evidence-anchor-check correction (real class strings, no undefined ids).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Thread board root through probe engine (Gap 1) | dc2c0a55 | probes.ts |
| 2 | Board-scope spec + in-scope seeded tests + probe #4 + D-22 enrichment | 21eb7d27 | admin-eval.spec.ts, probes.ts |
| 3 | W1 — align evidence-anchor-check to D-22 shape + real class strings | da99e976 | evidence-anchor-check.mjs, evidence-anchor-check.test.mjs |

## What Was Built

### Task 1 — Board-root-scoped probe engine (probes.ts)

Added `boardRoot?: string` parameter to all 7 element-scanning probes
(`probeOffTokenSpacing`, `probeMisalignment`, `probeSizeWeightBudget`,
`probeEmberReservedFor`, `probeOffScaleRadiusShadowControl`, `probeFocusRing`,
`probeBelowFoldPrimary`). Inside each `page.evaluate`, the pattern is:

```
const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
if (!boardRoot) return [];
const candidates = boardRoot.querySelectorAll('[class*="sg-"]');
```

Design-token reads (`--sg-space-*`, `--sg-radius-*`, `--sg-control-*`, `--sg-color-ember*`)
remain on `document.documentElement` / `:root` (prohibition honored).

Probe #4 ember: EMBER_RESERVED_SELECTORS query stays document-wide (membership test);
candidate scan moves to boardRoot.

Probe #6 target-size: `AxeBuilder.include(boardRoot)` when boardRoot provided.

Probe #9 below-fold: fold via `document.documentElement.clientHeight` stays global;
primary-selector candidate scan moves to boardRoot. Comment added: fold is a viewport
property, semantically N/A for isolated gallery boards.

`runAllProbes` extended with `root?: string` option. When provided, `boardSelector`
defaults to `root` for probe #8.

### Task 2 — Board-scoped spec call + in-scope seeded tests + D-22 enrichment (admin-eval.spec.ts)

- `captureSurface` receives new `boardId: string` parameter; passes `root: '#' + boardId` to `runAllProbes`
- Render-matrix loop passes `boardId` from the iteration variable
- `enrichFindingsForBundle(surface, findings)`: maps raw probe findings to D-22 shape by adding `class: f.probe_class`, `surface`, and `finding_id = sha256(surface NUL class NUL anchor)`. `probe_class` kept for gate/warn split compatibility.
- `writeBundleLocal` calls `enrichFindingsForBundle` before writing `findings.json`
- All seeded-defect tests (#1, #5, #7) now inject into `#probe-scope-root` wrapper and pass `root: '#probe-scope-root'` to the probe
- NEW probe #4 ember-reserved-for seeded test: sg-ember outside reserved context → gate finding; sg-ember inside `[data-selected="true"]` → not flagged
- Clean-baseline test: `probeOffTokenSpacing` and `probeFocusRing` called per-board with `root: '#'+id` and flattened

### Task 3 — W1 evidence-anchor-check fix (evidence-anchor-check.mjs + test.mjs)

- `const { finding_id, anchor, class: probeClass, surface, probe_class: rawProbeClass } = finding;`
- `const effectiveClass = probeClass || rawProbeClass;` — handles both D-22-enriched (has `class`) and raw emitter shape (has `probe_class` only)
- `const findingRef = finding_id || [surface, effectiveClass, anchor].filter(Boolean).join('::');` — used in all three FAIL messages; never prints `undefined`
- `GEOMETRY_ONLY_CLASSES`: replaced stale `'below-fold'` with `'below-fold-primary'` (real probe_class emitter string); geometry-note branch is now reachable on real bundles
- `GEOMETRY_ONLY_CLASSES.has(effectiveClass)` replaces `.has(probeClass)`

New test cases in `evidence-anchor-check.test.mjs`:
- **Test W1**: raw emitter shape (probe_class, no class/finding_id) with absent anchor; asserts FAIL message contains `surface::class::anchor` fallback and NOT `undefined`
- **Test W2**: `below-fold-primary` class with absent anchor; asserts geometry-note fires

Total: 15/15 cases pass (was 10/10 A–E, now adds W1 + W2).

## Deviations from Plan

### Deferred (not auto-fixable)

**D-12 fold: PROBE_IDS import deferred**
- **Found during:** Task 2 planning
- **Issue:** The plan asks to import PROBE_IDS from `scripts/ci/lib/eval-probe-ids.mjs` instead of the duplicate in `probes.ts`. Playwright transforms TS files with a CJS transform; the `scripts/ci/lib/*.mjs` files use `export` (ESM). The import would require either `createRequire` workarounds or a tsconfig path alias — neither is clean without risk to the scoping fix.
- **Action:** Left a `// FOLLOW-UP(216): import PROBE_IDS from scripts/ci/lib/eval-probe-ids.mjs (D-12 single-source)` marker in probes.ts. Documented in SUMMARY.
- **Impact:** IDs are identical at this commit; no functional regression. D-12 drift risk remains.

### Auto-fix (Rule 1)

**effectiveClass fallback for raw emitter shape (W1)**
- **Found during:** Task 3 self-test run
- **Issue:** The plan's `findingRef` formula used `probeClass` (from `class: probeClass` destructuring), which is `undefined` for raw emitter findings that only have `probe_class`. The `.filter(Boolean)` silently dropped it, producing `surface::anchor` instead of `surface::class::anchor`.
- **Fix:** Added `probe_class: rawProbeClass` to destructure; `effectiveClass = probeClass || rawProbeClass`; all FAIL messages + GEOMETRY_ONLY_CLASSES use `effectiveClass`.
- **Files:** `scripts/ci/evidence-anchor-check.mjs`
- **Commit:** da99e976

## Verification Results

| Check | Result |
|-------|--------|
| `node scripts/ci/evidence-anchor-check.test.mjs` | **15/15 PASS** (A, B, C, D, E, W1, W2) |
| `npx tsx -e "import('./lib/eval/probes.ts')"` | **OK** (clean import) |
| `grep document.querySelectorAll probes.ts` | **1 hit** (ember reserved-context only, allowed) |
| No `document.querySelectorAll` candidate loops remain | **CONFIRMED** |
| Design-token reads on document.documentElement | **CONFIRMED** |
| `enrichFindingsForBundle` writes D-22 shape | **CONFIRMED** |
| GEOMETRY_ONLY_CLASSES matches real emitter strings | **CONFIRMED** (misalignment, focus-ring, below-fold-primary) |

## Known Stubs

None — all wired.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries beyond what the plan's threat model covers.

## Self-Check

**Commits:**
- dc2c0a55: `feat(216-08): board-root scope all nine probe element-scan loops (Gap 1 fix)`
- 21eb7d27: `feat(216-08): board-scope spec runAllProbes call + in-scope seeded-defect tests + D-22 enrichment`
- da99e976: `fix(216-08): W1 — align evidence-anchor-check to real emitter shape + D-22 class strings`

**Files:**
- `/Users/jon/projects/sigra/test/example/priv/playwright/lib/eval/probes.ts` ✓
- `/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-eval.spec.ts` ✓
- `/Users/jon/projects/sigra/scripts/ci/evidence-anchor-check.mjs` ✓
- `/Users/jon/projects/sigra/scripts/ci/evidence-anchor-check.test.mjs` ✓

## Self-Check: PASSED
