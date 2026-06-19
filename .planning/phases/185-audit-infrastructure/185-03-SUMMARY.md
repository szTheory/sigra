---
phase: 185-audit-infrastructure
plan: "03"
subsystem: playwright-snapshot-infrastructure
tags:
  - playwright
  - visual-regression
  - axe
  - ci
  - design-system
dependency_graph:
  requires:
    - test/example/lib/example_web/live/admin/design_gallery_live.ex (produced by plan 185-01)
    - scripts/ci/snapshot-canary-guard.sh (pre-existing; extended here)
  provides:
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - admin-design-{chromium,mobile,dark} Playwright project trio
    - test/example/priv/playwright/snapshot-allowlist-design (empty steady-state)
    - 51 board PNG baselines (17 boards x 3 projects)
    - design-lane drift guard + recapture-gate steps in CI
  affects:
    - .github/workflows/ci.yml (design board run + design drift guard)
    - test/example/lib/example_web/components/layouts/root.html.heex (sigra_admin.css link repair)
tech_stack:
  added: []
  patterns:
    - Element-scoped toHaveScreenshot on page.locator('#board-{name}') (vs full-page checkpoints)
    - Per-test admin registration in beforeEach (isolated browser context auth)
    - Option B slug_of() second sed alternation for -admin-design-* suffix
    - Paired axe (wcag2a+wcag2aa) assertion per board
key_files:
  created:
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - test/example/priv/playwright/snapshot-allowlist-design
    - test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/ (51 PNGs)
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - scripts/ci/snapshot-canary-guard.sh
    - scripts/ci/snapshot-recapture-gate.sh
    - .github/workflows/ci.yml
    - test/example/lib/example_web/live/admin/design_gallery_live.ex (a11y dl-wrap fix)
    - test/example/lib/example_web/components/layouts/root.html.heex (sigra_admin.css link repair)
decisions:
  - Auth via per-test registerUser in beforeEach, not beforeAll on a separate page — each Playwright test runs in an isolated browser context, so a separate-page registration never authenticates the test page
  - Each summary_chip board variant wrapped in its own <dl class="sg-metric-grid"> (caption <span>s kept as valid siblings) to satisfy axe dlitem; stat self-wraps so needed no change
  - Linked sigra_admin.css in the example root layout to repair a phase 184-02 extraction that orphaned the sg-* design system in the hand-maintained example (installer golden already linked it)
  - Baselines captured locally on PORT=4011 (4000 was occupied by Docker), MIX_ENV=dev, against the styled admin
metrics:
  duration: "~90m (incl. checkpoint diagnosis + regression repair)"
  completed: "2026-06-14T15:40:00Z"
---

# Phase 185 Plan 03: admin-design Playwright Board-Snapshot Lane Summary

## One-liner
Wired the `admin-design-{chromium,mobile,dark}` Playwright board-snapshot lane
(element-scoped capture + paired axe) over the 185-01 gallery, captured 51 initial
PNG baselines, and extended the canary/recapture guards and CI — repairing a
phase-184 design-system regression that was blocking meaningful capture.

## What Was Built

### Task 1 (auto, executor): admin-design spec + config + empty allowlist
- `tests/admin-design.spec.ts` — element-scoped `assertBoardScreenshot` on
  `page.locator('#board-{name}')` + `assertNoAxeViolations`; 12 component +
  5 group board IDs; `board-notice` is the designated canary.
- `playwright.config.ts` — `admin-design-{chromium,mobile,dark}` project trio,
  `ADMIN_DESIGN_SPEC` regex, testIgnore extensions on chromium/mobile.
- `snapshot-allowlist-design` — empty (comments only), steady state.

### Task 2 (auto, executor): guard extensions + CI wiring
- `snapshot-canary-guard.sh` — `slug_of()` second sed alternation (Option B)
  strips `-admin-design-{chromium,mobile,dark}.png`.
- `snapshot-recapture-gate.sh` — design-lane (a2)/(b2) steps.
- `ci.yml` — design board run step in `example_playwright_smoke` + design-lane
  drift guard step in `snapshot_drift_guard` (canary `board-notice`).

### Task 3 (checkpoint, human-verify — driven by orchestrator): initial baselines
- 51 styled board PNG baselines captured (17 boards x 3 projects) and committed.

## Verification Results
- 51 PNG baselines present (17 x 3) — PASS
- Chromium re-run WITHOUT `--update`: 17/17 pass (deterministic visual match + axe 0 violations) — PASS
- `snapshot-allowlist-design` empty (steady state) — PASS
- Design-lane canary guard exits 0 (`board-notice` canary intact) — PASS
- `bash -n` both guard scripts — PASS
- `ci.yml` valid YAML; 5 `admin-design` references — PASS
- D-04 isolation test (`design_gallery_isolation_test.exs`): 1 test, 0 failures (gallery still never templated) — PASS
- Example app `mix compile --warnings-as-errors`: clean — PASS
- Visual confirmation: `board-notice` shows all 5 tones as styled alert boxes; MG-1 renders 4 styled metric cards; boards render inside the real admin shell (Rail Accent brand, topbar, sidebar) — PASS

## Deviations from Plan

Three fixes were required during the checkpoint that the plan did not anticipate.
All are committed atomically and attributed.

1. **Auth pattern (e7c69f3e, fix in admin-design.spec.ts).** The spec as written
   registered the admin once in `beforeAll` on a separate, closed page. Playwright
   isolates each test in its own browser context, so the test pages were never
   authenticated — every `goto('/admin/_design')` 302-redirected to login and
   `waitForLiveViewReady` timed out (all 17 boards failed). Fixed to register a
   fresh `platform-admin+` user in `beforeEach` on the test's own page, mirroring
   admin-checkpoints.spec.ts. Unique per-test email; gallery uses static literal
   assigns so the email never appears in any screenshot (deterministic).

2. **a11y dlitem (fc83ee72, fix in design_gallery_live.ex — a 185-01 defect).**
   `summary_chip` emits bare `<dt>/<dd>` with no `<dl>` of its own; the standalone
   `board-summary_chip` wrapped chips in plain `<div>`s, failing the full-page axe
   `dlitem` rule. Wrapped each variant in `<dl class="sg-metric-grid">` (caption
   `<span>`s kept as valid siblings). (A separate 185-01 tone/icon attr-type fix
   landed earlier in commit 2367e2ca via the Wave 1 post-merge gate.)

3. **sigra_admin.css link (d8922a7d — repair of a phase 184-02 regression).**
   The example admin (and the new gallery) rendered FULLY UNSTYLED. Root cause:
   commit 575c190b (184-02) extracted the `sg-*` admin design system into
   `sigra_admin.css` and reduced `app.css` to `vt-*` only, updating the installer
   golden layout fixture to link `sigra_admin.css` — but never added that `<link>`
   to the hand-maintained example's own `root.html.heex`. The `sg-*` layout
   primitives (`sg-stack`/`sg-grid`/`sg-container`) live only in the orphaned
   `sigra_admin.css`, so all content collapsed to bare block flow. Added the link,
   matching `priv/templates/sigra.install/admin/layouts_admin_injection.ex:10`.
   Verified both `/admin` and `/admin/_design` render correctly styled again.

## Cross-phase implication (flagged for follow-up)
The 184-02 regression means the **styled admin-checkpoints baselines** (last
recaptured in phase 183, commit 0433e1a4) are mismatched against the
post-184 unstyled render on `main` — i.e. the `admin-checkpoints` CI lane was
likely failing on `main`. This d8922a7d fix restores the styling those baselines
expect, so it should re-align that lane too — but the admin-checkpoints lane
should be re-confirmed green (and re-captured if any residual drift remains).
Recommended: a quick follow-up to run the admin-checkpoints lane and confirm.

## Threat Flags
None. T-185-06/07/08/SC accepted as planned (static synthetic data, dev-only
route, bounded CI runtime, no new packages).

## Self-Check

### Created files exist:
- test/example/priv/playwright/tests/admin-design.spec.ts ✓
- test/example/priv/playwright/snapshot-allowlist-design ✓
- test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/ (51 PNGs) ✓

### Commits exist:
- c7d108d8 feat(185-03): admin-design spec + playwright.config.ts + empty allowlist ✓
- b7328e25 feat(185-03): guard extensions + CI wiring for design lane ✓
- e7c69f3e fix(185-03): register admin per-test in beforeEach ✓
- fc83ee72 fix(185-01): wrap summary_chip boards in <dl> ✓
- d8922a7d fix(185): link sigra_admin.css in example root layout ✓
- 24785876 feat(185): capture initial admin-design board PNG baselines ✓

## Self-Check: PASSED
