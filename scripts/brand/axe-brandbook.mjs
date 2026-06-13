#!/usr/bin/env node
// axe accessibility check for brandbook/index.html
// Usage: node scripts/brand/axe-brandbook.mjs
// Exits 0 on zero violations; non-zero otherwise.
//
// Prerequisites:
//   - python3 available on PATH
//   - playwright-core + @axe-core/playwright already installed at
//     test/example/priv/playwright/node_modules/ (no separate npm install needed)

import { createRequire } from 'module';
import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Reuse playwright-core from the existing test/example install — avoids a duplicate install.
// The createRequire with the playwright package.json dir as the base ensures Node resolves
// playwright-core from that location's node_modules, not from scripts/brand/node_modules/.
const playwrightBase = new URL(
  '../../test/example/priv/playwright/',
  import.meta.url
).pathname;
const require = createRequire(playwrightBase + 'package.json');
const { chromium } = require('playwright-core');
const { default: AxeBuilder } = require('@axe-core/playwright');

const brandbookDir = resolve(__dirname, '../../brandbook');
const PORT = 7743; // hardcoded; low-collision port for local use

// Start a short-lived python3 static server to serve brandbook/ over localhost.
// Using http://localhost rather than file:// avoids potential CORS ambiguity
// with @axe-core/playwright's page.evaluate() script injection.
const server = spawn(
  'python3',
  ['-m', 'http.server', String(PORT), '--directory', brandbookDir],
  { stdio: 'ignore' }
);

// Wait until the server is ready to accept connections (poll, max ~5 seconds).
// A fixed sleep is not reliable across machines — poll until we get a response.
await (async () => {
  const { request } = await import('http');
  for (let i = 0; i < 25; i++) {
    const ok = await new Promise(res => {
      const req = request({ hostname: '127.0.0.1', port: PORT, path: '/', method: 'HEAD' }, () => res(true));
      req.on('error', () => res(false));
      req.setTimeout(300, () => { req.destroy(); res(false); });
      req.end();
    });
    if (ok) break;
    await new Promise(r => setTimeout(r, 200));
  }
})();

let exitCode = 0;
try {
  const browser = await chromium.launch({ headless: true });
  // axe-playwright's finishRun() calls page.context().newPage() internally.
  // Use browser.newContext() → context.newPage() to ensure a proper BrowserContext
  // is available (browser.newPage() does not satisfy this requirement).
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(`http://localhost:${PORT}/index.html`);

  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();

  if (violations.length === 0) {
    console.log('axe: PASS — zero violations on brandbook/index.html');
  } else {
    console.error(`axe: FAIL — ${violations.length} violation(s):`);
    for (const v of violations) {
      console.error(`  [${v.impact}] ${v.id}: ${v.description}`);
      for (const node of v.nodes.slice(0, 2)) {
        console.error(`    node: ${node.target.join(', ')}`);
      }
    }
    exitCode = 1;
  }

  await context.close();
  await browser.close();
} finally {
  server.kill();
}

process.exit(exitCode);
