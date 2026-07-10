---
phase: 216-harness-foundation-award-gradient
plan: "06"
subsystem: admin-eval-harness
tags: [playwright, visual-probes, eval-harness, stale-render-guard, bundle-capture]
dependency_graph:
  requires: ["216-01", "216-03", "216-05"]
  provides: [HARNESS-01-capture, HARNESS-03-probes, HARNESS-02-stale-render-capture-side]
  affects: [admin-eval-ci-lane, quality-ledger-pipeline]
tech_stack:
  added: []
  patterns:
    - page.evaluate getComputedStyle live --sg-* reads (never toHaveCSS #12629)
    - box-shadow focus-ring diff (not outline — sg-focus-ring is box-shadow)
    - @axe-core/playwright target-size explicit enable
    - card-in-card check lifted verbatim from admin-design.spec.ts
    - hermetic mktemp git self-test pattern (cloned from quality-ledger-monotonic)
    - playwright.config.ts ADD (not fork) project registration pattern
key_files:
  created:
    - test/example/priv/playwright/lib/eval/probes.ts
    - test/example/priv/playwright/tests/admin-eval.spec.ts
    - scripts/ci/stale-render-guard.sh
    - scripts/ci/stale-render-guard.test.sh
  modified:
    - test/example/priv/playwright/playwright.config.ts
decisions:
  - "probes.ts reads --sg-* via getComputedStyle().getPropertyValue() (live :root reads, never duplicated JS constant table — D-12)"
  - "admin-eval.spec.ts uses __dirname instead of bundle.ts import.meta.url (CJS/ESM compatibility with Playwright transform — Rule 3 deviation)"
  - "Gate/warn split enforced: admin-eval (DPR1) hard-gates; -mobile/-dark collect findings as warn (D-15)"
  - "stale-render-guard.sh: absence=FAIL (opposite of tier guard skip), git plumbing only — never mtime"
metrics:
  duration: "~17 minutes"
  completed: "2026-07-03"
  tasks_completed: 3
  tasks_total: 3
  files_created: 4
  files_modified: 1
status: complete
---

# Phase 216 Plan 06: Render/Probe Engine Summary

Implements the render+probe engine for the Sigra admin eval harness: nine deterministic visual probes, the Playwright spec that renders the gallery matrix and writes bundles, three new playwright projects (admin-eval/-mobile/-dark), and the stale-render trust guard.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | probes.ts — nine in-browser visual probes | bffe6087 | test/example/priv/playwright/lib/eval/probes.ts |
| 2 | admin-eval.spec.ts + playwright.config.ts | 44bfe644 | tests/admin-eval.spec.ts, playwright.config.ts |
| 3 | stale-render-guard.sh + .test.sh | 8a884b0d | scripts/ci/stale-render-guard.sh, stale-render-guard.test.sh |

## What Was Built

### Task 1: probes.ts — nine in-browser visual probes

Nine deterministic probes matching `eval-probe-ids.mjs` canonical IDs exactly. Each runs via `page.evaluate` reading the live `--sg-*` scale off `:root`:

- **#1 off-token-spacing** (gate): padding not on live `--sg-space-*` scale (±0.5px tolerance), reads `paddingTop/Right/Bottom/Left` longhands
- **#2 misalignment** (warn): sub-pixel offset detection (1-6px range)
- **#3 size-weight-budget** (warn): >5 distinct font-sizes or >3 distinct font-weights
- **#4 ember-reserved-for** (gate): ember accent outside reserved selected/ownership context
- **#5 off-scale-radius-shadow-control** (gate for radius+control, warn for shadow): reads four corner longhands (`borderTopLeftRadius` etc.), never shorthand
- **#6 target-size** (gate): `@axe-core/playwright` with explicit `target-size: { enabled: true }` (rule is disabled by default — Pitfall 1)
- **#7 focus-ring** (gate): `.focus()` then diff computed `box-shadow` AND `outline` — PASS if either changes (authored as `--sg-focus-ring` box-shadow, not outline)
- **#8 card-in-card** (gate): lifted VERBATIM from `admin-design.spec.ts:349-361`, honors `data-sg-card-nesting-audit-only`
- **#9 below-fold-primary** (warn): primary actions below `documentElement.clientHeight` fold line

All probes honor `data-sg-<probe>-audit-only` suppression attributes (D-14). The `runAllProbes()` export demotes gate→warn in non-gate projects (D-15).

### Task 2: admin-eval.spec.ts + playwright.config.ts

**admin-eval.spec.ts** renders the `/admin/_design` gallery matrix via `waitForLiveViewReady` (VERBATIM from `admin-design.spec.ts`), iterates `GROUP_BOARDS × {populated,zero,loading,error}` states, runs all nine probes, and writes bundles via `writeBundleLocal` (CJS-compatible `__dirname` path resolver — see deviation below).

Seeded-defect + clean-cell assertions for probes #1/#5/#6/#7/#8 prove each probe actually fires (Nyquist requirement). Gate/warn split enforced: `admin-eval` (DPR1) hard-fails on gate-severity findings; `-mobile` and `-dark` collect findings as warn-only.

**playwright.config.ts** additions (ADD, not fork per D-03):
- Added `ADMIN_EVAL_SPEC = /admin-eval\.spec\.ts/` constant
- Excluded `ADMIN_EVAL_SPEC` from `chromium` and `mobile` `testIgnore` arrays
- Appended three projects: `admin-eval` (Desktop Chrome), `admin-eval-mobile` (iPhone 13), `admin-eval-dark` (colorScheme:'dark')
- All 53 existing tests in chromium/mobile remain unchanged

### Task 3: stale-render-guard.sh + stale-render-guard.test.sh

**stale-render-guard.sh** implements all D-07/D-08 conditions:
1. **Absence** — no `bundle.json` under `eval/` → hard FAIL (not skip)
2. **SHA mismatch** — `bundle.app_git_sha != git HEAD`
3. **Unreachable SHA** — `git cat-file -e <sha>` fails loudly
4. **Admin source newer** — `git diff --name-only <bundle_sha> HEAD -- <admin globs>` non-empty

Admin globs: `lib/sigra/admin`, `lib/sigra/admin.ex`, `lib/sigra/live_view/admin_scope.ex`, `priv/templates/sigra.install/admin`, `test/example/priv/static/assets/sigra_admin.css`. Git plumbing only — never mtime.

**stale-render-guard.test.sh** — hermetic scaffold (cloned from `quality-ledger-monotonic.test.sh` pattern), 12 test cases all passing: A=sha-match-PASS, B=sha-mismatch-FAIL, C=empty-eval-dir-FAIL, D=unreachable-sha-FAIL, E=admin-source-newer-FAIL, F1/F2=glob-matching-verified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] bundle.ts import.meta.url incompatible with Playwright CJS transform**
- **Found during:** Task 2
- **Issue:** `bundle.ts` (from Plan 03) uses `import.meta.url` (ESM) to resolve `PW_ROOT`. Playwright's CJS transform cannot process `import.meta.url`, causing `ReferenceError: exports is not defined` when `admin-eval.spec.ts` imports from `bundle.ts`. Adding `"type": "module"` to `package.json` would break `passkeys-hooks.spec.ts` which uses `__dirname`.
- **Fix:** `admin-eval.spec.ts` implements `writeBundleLocal()` inline using `__dirname` (CJS-compatible) with identical bundle-write semantics. Does NOT modify `bundle.ts` (Plan 03 artifact), does NOT fork its contract (same files written, same bundle.json schema).
- **Files modified:** `test/example/priv/playwright/tests/admin-eval.spec.ts`
- **Commit:** 44bfe644

## Verification Results

All plan verification checks passed:
- `npx tsx -e "import('./lib/eval/probes.ts')"` → PROBES_TS_OK
- `grep -q "getPropertyValue" lib/eval/probes.ts` → OK; `! grep -q "toHaveCSS"` → OK
- `npx playwright test --list --project=admin-eval` → 50 tests in admin-eval.spec.ts
- `grep -q "admin-eval-dark" playwright.config.ts && grep -q "admin-eval-mobile"` → EVAL_PROJECTS_OK
- `bash scripts/ci/stale-render-guard.test.sh` → 12 passed, 0 failed
- Existing chromium: 53 tests, mobile: 7 tests — both unchanged

## Self-Check

### Files Created/Modified

- [x] `test/example/priv/playwright/lib/eval/probes.ts` — created
- [x] `test/example/priv/playwright/tests/admin-eval.spec.ts` — created
- [x] `test/example/priv/playwright/playwright.config.ts` — modified
- [x] `scripts/ci/stale-render-guard.sh` — created
- [x] `scripts/ci/stale-render-guard.test.sh` — created

### Commits

- [x] bffe6087: feat(216-06): probes.ts — nine in-browser visual probes (live --sg-* reads)
- [x] 44bfe644: feat(216-06): admin-eval.spec.ts + three playwright config projects (render matrix + bundles)
- [x] 8a884b0d: feat(216-06): stale-render-guard.sh + hermetic self-test (git plumbing, absence=FAIL)

## Self-Check: PASSED
