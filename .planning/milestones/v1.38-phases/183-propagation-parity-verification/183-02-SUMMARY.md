---
plan: 183-02
phase: 183
status: complete
completed: 2026-06-13
requirements:
  - BRAND2-13
  - BRAND2-14
commits:
  - 0433e1a4 (test: recapture admin Playwright baselines for D4 logo)
subsystem: admin-ui / playwright-baselines
tags:
  - playwright
  - snapshot-recapture
  - D4-logo
  - admin-checkpoints
dependency_graph:
  requires:
    - 183-01 (D4 logo propagated to installer + example + tests green)
  provides:
    - BRAND2-13 (recaptured admin Playwright baselines reflecting D4 lockup)
    - BRAND2-14 (hygiene gate: parseability, no stray binaries, mix test, git clean)
  affects:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/
    - test/example/priv/playwright/snapshot-allowlist
tech_stack:
  added: []
  patterns:
    - Playwright --update-snapshots=all for deliberate full logo change
    - Canary PNG restore via git checkout -- immediately after update-snapshots
    - snapshot-recapture-gate.sh 3-step approval (compare + canary guard + ExUnit goldens)
key_files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts (Rule 3 blocker fixes)
    - test/example/priv/playwright/snapshot-allowlist (7 slugs added then reset to empty)
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/*.png (21 recaptured)
decisions:
  - Recaptured 7 non-canary slugs × 3 projects = 21 PNGs with D4 logo visible in every admin topbar
  - Restored 3 impersonation-banner canary PNGs to pre-recapture state
  - Snapshot-allowlist reset to empty steady state after gate passes
  - Rule 3 fixes applied to 3 stale Playwright selectors that blocked recapture
metrics:
  duration: ~90 minutes
  completed: 2026-06-13T06:42:38Z
  tasks: 2
  files: 24
---

# Phase 183 Plan 02 Summary — Playwright Baseline Recapture + Hygiene

## Outcome

21 admin Playwright baselines recaptured with D4 Linked Rail logo visible in every admin topbar. 3 impersonation-banner canary PNGs byte-identical to pre-recapture state. snapshot-recapture-gate.sh exits 0. snapshot-allowlist reset to empty steady state. All 6 SVGs parse, no stray binaries, example test suite 213/0, git status clean.

## Per-task

**Task 1 — Baseline recapture + gate + allowlist reset (0433e1a4).**

Pre-execution: Confirmed Wave 1 (183-01) complete at HEAD, port 4011 free, dev server recompiled with PORT=4011 to avoid compile-env mismatch.

Allowlist updated from 4 slugs to 7 (added: audit-explorer, global-user-index, org-scoped-admin). Dev server booted on port 4011. `--update-snapshots=all` run across 3 projects (chromium/mobile/dark) — 24 PNGs re-generated. Impersonation-banner canary PNGs immediately restored via `git checkout --` — 3 PNGs unchanged. Gate run with SIGRA_EXAMPLE_URL=http://localhost:4011:
- Step (a) compare-mode: 3/3 pass
- Step (b) canary guard --require-all: 7 intended slugs changed, canary unchanged (PASS)
- Step (c) ExUnit component byte-goldens: 24/0

Post-gate: snapshot-allowlist reset to empty steady state (comments only). Dev server killed.

**Task 2 — Hygiene sweep.**

- All 6 admin lockup + companion mark SVGs parse as valid XML via xmllint
- No stray binaries outside `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/`
- brandbook/ size: 604KB (unchanged, within expected range)
- Root `mix test`: 2381 tests, 2 failures, 12 skipped — 2 pre-existing failures confirmed (see below)
- Example `mix test`: 213 tests, 0 failures (79 excluded) — fully green
- git status: clean (zero uncommitted files)

## Deviations from Plan

### Auto-fixed Issues (Rule 3 — Blocking)

The Playwright `--update-snapshots=all` run failed on the first attempt because the spec contained 3 stale selectors left over from the "Polish admin overview metrics" commit (`b9cbb7a7`, on branch, pre-Phase-183). These selectors were correct at the time the test was written but the admin UI was updated before Phase 183 ran, making the spec unable to navigate through the page sequence needed for recapture.

**1. [Rule 3 - Blocking] sg-metric-link__value → sg-metric__number for global-overview**
- **Found during:** Task 1 first Playwright run
- **Issue:** `await expect(page.locator('.sg-metric-link__value').first()).toBeVisible()` — the admin overview no longer uses the `metric_link` component. It was updated to `summary_chip` which uses class `.sg-metric__number`. The old CSS class no longer exists on the page.
- **Fix:** Changed selector to `.sg-metric__number`.
- **Files modified:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`

**2. [Rule 3 - Blocking] Remove stale sg-metric__number wait for org-overview**
- **Found during:** Task 1 second Playwright run (after fix #1)
- **Issue:** `await expect(page.locator('.sg-metric__number').first()).toBeVisible()` — the org-overview page does not have metrics at all. It shows a "Support members / Investigate org events" launcher layout, not a metrics strip. The `.sg-metric__number` never appears.
- **Fix:** Removed the sg-metric__number wait for org-overview; kept the `.sg-notice` wait which IS on that page.
- **Files modified:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`

**3. [Rule 3 - Blocking] Remove stale "Back to user" page_back link for user-audit**
- **Found during:** Task 1 second Playwright run (after fix #1+#2 passed org-overview)
- **Issue:** `await expect(page.getByRole('link', { name: 'Back to user' })).toBeVisible()` — the audit user page no longer has a `page_back/1` component. Navigation is via breadcrumbs (Overview / Users / email / Audit). The `page_back/1` component exists in components.ex but is not used in any admin LiveView.
- **Fix:** Removed the stale `page_back` link assertion. The `getByText('Global audit explorer')` assertion on the next line is sufficient to confirm the page is loaded.
- **Files modified:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`

## Pre-existing failures (NOT caused by this milestone)

Root `mix test` completed with **2 pre-existing failures** (same as documented in 183-01-SUMMARY):

- `test/sigra/install/isolation_test.exs:86` — template count 52 vs 49. Pre-existing template count drift.
- `test/mix/tasks/sigra.install_test.exs:166` — `auth.ex:554` undefined EEx binding `app_name`. Pre-existing generated-template bug.

These are byte-identical to the failures on the main merge-base. Neither failure was introduced by Phase 183. BRAND2-14's literal "mix test exits 0" cannot be claimed because of these; instead: confirmed all 183-related tests pass and no new failures were introduced.

## Gate Results

| Check | Result |
|-------|--------|
| snapshot-recapture-gate.sh step (a) compare-mode | PASS (3/3) |
| snapshot-recapture-gate.sh step (b) canary guard --require-all | PASS (7 slugs changed, canary unchanged) |
| snapshot-recapture-gate.sh step (c) ExUnit component goldens | PASS (24/0) |
| Impersonation-banner canary unchanged | PASS (0 changes) |
| Non-canary PNGs changed | PASS (21 of 21) |
| snapshot-allowlist empty steady state | PASS (0 active slugs) |
| 6 SVGs parse (xmllint) | PASS |
| No stray binaries | PASS |
| brandbook/ size | 604KB (expected) |
| Root mix test | 2381 tests, 2 pre-existing failures |
| Example mix test | 213 tests, 0 failures |
| git status clean | PASS |

## must_have status

- ✅ All 7 non-canary admin-checkpoints slugs recaptured (D4 lockup in topbar) (BRAND2-13)
- ✅ Impersonation-banner canary PNGs byte-identical to pre-recapture state (BRAND2-13)
- ✅ snapshot-recapture-gate.sh exits 0 with 7 slugs declared (BRAND2-13)
- ✅ snapshot-allowlist empty (comments only) after gate (BRAND2-13)
- ✅ All 6 SVGs parse; no stray binaries; brandbook size correct (BRAND2-14)
- ⚠ mix test exits 0 (BRAND2-14): 2 pre-existing failures prevent literal exit 0; confirmed 0 NEW failures

## Self-Check: PASSED

Verified:
- 0433e1a4 commit exists: `git log --oneline -1` confirms
- 21 non-canary PNGs changed: `git diff --name-only HEAD~1 HEAD ...snapshots/ | grep -v impersonation-banner | wc -l` = 21
- 0 canary PNGs changed: confirmed
- allowlist empty: grep confirms 0 active slugs
- 6 SVGs parse: xmllint confirms
- git status clean: no uncommitted files
