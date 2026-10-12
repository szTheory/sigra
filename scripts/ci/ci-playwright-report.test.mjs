import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const configPath = new URL('../../test/example/priv/playwright/playwright.config.ts', import.meta.url);
const workflowPath = new URL('../../.github/workflows/ci.yml', import.meta.url);

test('Playwright JSON output is opt-in beside the existing human-readable reporters', async () => {
  const config = await readFile(configPath, 'utf8');

  assert.match(config, /process\.env\.SIGRA_PLAYWRIGHT_JSON/);
  assert.match(config, /\['list'\]/);
  assert.match(config, /\['html',\s*\{\s*open:\s*'never'\s*\}\]/);
  assert.match(config, /\['json',\s*\{\s*outputFile:\s*[^}]+\}\]/);
  assert.match(config, /reporters\.push/);
  assert.match(config, /reporter:\s*reporters/);
  assert.match(config, /fullyParallel:\s*false/);
  assert.match(config, /workers:\s*1/);
  assert.match(config, /retries:\s*0/);
});

test('the five existing browser seam identifiers and selection commands stay in place', async () => {
  const workflow = await readFile(workflowPath, 'utf8');
  const shard = workflow.split('  example_playwright_shard:', 2)[1]?.split('\n  example_playwright_smoke:', 2)[0];
  assert.ok(shard, 'expected the example_playwright_shard job');
  const expectedSeams = [
    'admin_behavior',
    'admin_checkpoints',
    'design_gallery',
    'non_admin_smoke',
    'demo_showcase',
  ];

  const actualSeams = [...shard.matchAll(/^\s+- seam: ([a-z_]+)\s*$/gm)].map((match) => match[1]);
  assert.deepEqual(actualSeams, expectedSeams);
  assert.equal((shard.match(/npx playwright test \\\n/g) ?? []).length, 7);
  for (const selection of [
    'tests/admin-user-operations.spec.ts',
    'tests/admin-checkpoints.spec.ts',
    "--grep-invert '@snapshot'",
    "--grep '@snapshot'",
    'tests/golden-path.spec.ts',
    'tests/demo-showcase.spec.ts',
  ]) {
    assert.ok(shard.includes(selection), `missing existing selection ${selection}`);
  }
  assert.equal((shard.match(/--retries=0/g) ?? []).length, 7);
});
