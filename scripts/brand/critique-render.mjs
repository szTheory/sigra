#!/usr/bin/env node
// Phase 179 (BRAND2-04): Playwright headless render harness for per-candidate critique screenshots.
//
// Usage: node scripts/brand/critique-render.mjs <harness.html> <out-dir>
// Run from repo root. No test framework or server needed — screenshots file:// pages only.
//
// Prerequisites:
//   - playwright-core already installed at test/example/priv/playwright/node_modules/playwright-core
//   - Chromium browser cached at ~/Library/Caches/ms-playwright/chromium-1223/
//   - No additional npm install needed in scripts/brand/ for this script.

import { createRequire } from 'module';
import { writeFileSync, mkdirSync } from 'fs';
import { resolve, basename, extname } from 'path';

// Reuse playwright-core from the existing test/example install — avoids a duplicate install.
// The createRequire with the playwright package.json dir as the base ensures Node resolves
// playwright-core from that location's node_modules, not from scripts/brand/node_modules/.
const playwrightBase = new URL(
  '../../test/example/priv/playwright/',
  import.meta.url
).pathname;
const require = createRequire(playwrightBase + 'package.json');
const { chromium } = require('playwright-core');

const [, , harnessHtmlAbsPath, outDir] = process.argv;

if (!harnessHtmlAbsPath || !outDir) {
  console.error('Usage: node scripts/brand/critique-render.mjs <harness.html> <out-dir>');
  console.error('Example: node scripts/brand/critique-render.mjs /tmp/sigra-harness-smoke.html /tmp/sigra-renders/smoke');
  process.exit(1);
}

// Resolve the harness HTML to an absolute path for the file:// URL.
const harnessAbs = resolve(harnessHtmlAbsPath);
const fileUrl = `file://${harnessAbs}`;

// Derive a base name for screenshot files from the harness HTML filename.
const baseName = basename(harnessHtmlAbsPath, extname(harnessHtmlAbsPath));

// Four scale profiles covering favicon, topbar, and hero contexts.
// Width is set larger than the named size so boundary-breaking designs don't clip.
const SCALES = [
  { name: '16px-favicon', width: 64,   height: 64  },
  { name: '32px',         width: 128,  height: 128 },
  { name: '54px-topbar',  width: 800,  height: 160 },
  { name: 'hero',         width: 1200, height: 300 },
];

const COLOR_SCHEMES = ['light', 'dark'];

mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const written = [];

for (const scale of SCALES) {
  for (const scheme of COLOR_SCHEMES) {
    const page = await browser.newPage();
    await page.setViewportSize({ width: scale.width, height: scale.height });
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(fileUrl);
    const buf = await page.screenshot({ type: 'png' });
    const outPath = `${outDir}/${baseName}-${scale.name}-${scheme}.png`;
    writeFileSync(outPath, buf);
    written.push(outPath);
    await page.close();
  }
}

await browser.close();

console.log(`Wrote ${written.length} screenshots to ${outDir}:`);
written.forEach((f) => console.log(`  ${f}`));
