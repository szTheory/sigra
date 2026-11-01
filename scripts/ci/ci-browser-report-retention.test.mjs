import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Use the actual installed Playwright reporter and repository configuration. No
// browser, server or network is needed to exercise its output-directory cleanup.
test('HTML reporting preserves the separately collected selection JSON', () => {
  const dir = mkdtempSync(join(tmpdir(), 'browser-report-retention-'));
  const config = fileURLToPath(new URL('../../test/example/priv/playwright/playwright.config.ts', import.meta.url));
  const runtime = fileURLToPath(new URL('../../test/example/priv/playwright/node_modules/@playwright/test/index.js', import.meta.url));
  const cli = fileURLToPath(new URL('../../test/example/priv/playwright/node_modules/@playwright/test/cli.js', import.meta.url));
  try {
    writeFileSync(join(dir, 'playwright.config.ts'), `import base from ${JSON.stringify(config)}; export default {...base, testDir: ${JSON.stringify(dir)}, testMatch: 'retention.spec.ts', projects: [{name: 'chromium'}], webServer: undefined, globalSetup: undefined, outputDir: ${JSON.stringify(join(dir, 'results'))}};`);
    writeFileSync(join(dir, 'retention.spec.ts'), `import {test, expect} from ${JSON.stringify(runtime)}; test('receipt retained', () => expect(1).toBe(1));`);
    mkdirSync(join(dir, 'playwright-report'));
    const selection = join(dir, 'playwright-report', 'retention.selection.json');
    const args = [cli, 'test', '--config', join(dir, 'playwright.config.ts')];
    const selected = spawnSync(process.execPath, [...args, '--list', '--reporter=json'], {cwd: dir, encoding: 'utf8'});
    assert.equal(selected.status, 0, selected.stderr);
    writeFileSync(selection, selected.stdout);
    const executed = spawnSync(process.execPath, args, {cwd: dir, encoding: 'utf8', env: {...process.env, SIGRA_PLAYWRIGHT_JSON: join(dir, 'playwright-report', 'retention.json'), PLAYWRIGHT_HTML_OPEN: 'never'}});
    assert.equal(executed.status, 0, executed.stderr);
    assert.equal(readFileSync(selection, 'utf8'), selected.stdout, 'HTML reporter must not delete the independent test selection');
    assert.ok(JSON.parse(readFileSync(join(dir, 'playwright-report', 'retention.json'))).suites.length > 0);
  } finally { rmSync(dir, {recursive: true, force: true}); }
});
