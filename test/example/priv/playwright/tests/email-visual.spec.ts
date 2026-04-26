import { test, expect } from '@playwright/test';
import { resolve } from 'node:path';
import { existsSync } from 'node:fs';

// Phase 86 D-86-03: email visual regression spec.
//
// Locked matrix: 9 templates × 2 engines × 2 themes = 36 baselines.
// Viewport: 640×1200 (matches base_layout/1 email card width).
// Diff tolerance: maxDiffPixels 50 per D-86-03 and D-86-11.
//
// This spec runs under four dedicated Playwright projects defined in
// playwright.config.ts:
//   - email-visual-chromium-light
//   - email-visual-chromium-dark
//   - email-visual-webkit-light
//   - email-visual-webkit-dark
//
// Each project sets viewport, colorScheme, and snapshotPathTemplate.
// The spec reads the engine and theme from the project name so each test
// produces a uniquely named snapshot: `{template}__{engine}__{theme}.png`.
//
// HTML inputs are deterministic files pre-rendered by `mix sigra.email.snapshot`
// with frozen fixtures per D-86-04 (time=2026-04-17 12:00:00Z, ip=203.0.113.42).
// Playwright opens them via file:// so no running Phoenix server is needed.
//
// To regenerate baselines after a template change:
//   1. MIX_ENV=test mix sigra.email.snapshot
//   2. cd test/example/priv/playwright
//   3. npx playwright test tests/email-visual.spec.ts --update-snapshots
//   4. Review git diff on __snapshots__/email-visual.spec.ts/ before committing.
//      Document the reason for the visual change in the commit message.

// Locked 9-template slug list per D-86-03. Double-underscore is the field
// separator in the committed baseline filenames (template__engine__theme).
const TEMPLATES = [
  'lockout-notification',
  'suspicious-login',
  'email-change-confirmation',
  'email-change-notification',
  'email-changed',
  'password-changed',
  'deletion-scheduled',
  'deletion-cancelled',
  'deletion-finalized',
] as const;

// Pre-rendered HTML lives at test/example/priv/email_snapshots/{slug}.html.
// __dirname = test/example/priv/playwright/tests; go up two levels to priv/.
const SNAPSHOT_HTML_DIR = resolve(__dirname, '..', '..', 'email_snapshots');

/**
 * Extract engine and theme from the current Playwright project name.
 * Project names follow the pattern `email-visual-{engine}-{theme}`.
 * Returns e.g. `{ engine: 'chromium', theme: 'light' }`.
 */
function parseProject(projectName: string): { engine: string; theme: string } {
  // email-visual-chromium-light → ['email', 'visual', 'chromium', 'light']
  const parts = projectName.split('-');
  // parts[2] = engine, parts[3] = theme
  const engine = parts[2] ?? 'chromium';
  const theme = parts[3] ?? 'light';
  return { engine, theme };
}

for (const template of TEMPLATES) {
  test(`email-visual: ${template}`, async ({ page }, testInfo) => {
    const { engine, theme } = parseProject(testInfo.project.name);

    const htmlPath = resolve(SNAPSHOT_HTML_DIR, `${template}.html`);

    // Guard: pre-rendered HTML must exist. Run `MIX_ENV=test mix sigra.email.snapshot`
    // if this fails (the HTML files are generated on the fly, not committed).
    if (!existsSync(htmlPath)) {
      throw new Error(
        `Pre-rendered email HTML not found: ${htmlPath}\n` +
          `Run \`MIX_ENV=test mix sigra.email.snapshot\` to generate it.`,
      );
    }

    // Open the pre-rendered HTML via file:// — no running Phoenix server needed.
    // The colorScheme is set by the Playwright project (playwright.config.ts).
    await page.goto(`file://${htmlPath}`);

    // Wait for layout to stabilize (inline CSS emails have no JS, but ensure
    // any browser-default font loading or paint is complete).
    await page.waitForLoadState('load');

    // Snapshot name encodes template, engine, and theme so all 36 baselines
    // live under a single flat `__snapshots__/email-visual.spec.ts/` directory.
    // The expect.toHaveScreenshot.pathTemplate in playwright.config.ts routes
    // baselines there without a project-name suffix.
    //
    // Locked baseline names (36 cells, D-86-03):
    //   lockout-notification__chromium__light, lockout-notification__chromium__dark
    //   lockout-notification__webkit__light, lockout-notification__webkit__dark
    //   deletion-finalized__webkit__dark (last cell in the matrix)
    //   (full set: 9 templates × 2 engines × 2 themes)
    //
    // maxDiffPixels: 50 per D-86-03 and D-86-11 — catches real layout breaks
    // without failing on font-rendering micro-differences between CI and local.
    // The per-project default in playwright.config.ts also sets maxDiffPixels: 50
    // so the inline value here documents the tolerance explicitly.
    await expect(page).toHaveScreenshot(`${template}__${engine}__${theme}.png`, {
      fullPage: true,
      maxDiffPixels: 50,
    });
  });
}
