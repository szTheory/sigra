# Plan 35-03 Summary

**Objective:** axe-core + Playwright screenshot baselines for five admin checkpoints × three projects (SC3).

**Delivered:**
- `@axe-core/playwright` devDependency + lockfile update.
- `assertNoAxeViolations` using WCAG2 A/AA tags only; `assertCheckpointScreenshot` pairs axe with viewport `toHaveScreenshot` (`maxDiffPixels` / `maxDiffPixelRatio` tuned for stability).
- `playwright.config.ts`: `snapshotPathTemplate` without OS suffix for cross-runner baselines.
- **15** PNG snapshots under `tests/admin-checkpoints.spec.ts-snapshots/`.
- Example `layouts.ex`: `alt=""` on navbar logo for **image-alt** compliance on org pages during impersonation checkpoint.

**Verify:** `cd test/example/priv/playwright && npm ci && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark`

**Deviation from PLAN literal:** `fullPage: false` (viewport) instead of `fullPage: true` because audit/LiveView pages produced unstable full-page heights run-to-run.
