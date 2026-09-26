import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const fixtureSuite = path.join(scriptDirectory, 'verify-playwright-source-tree.test.sh');

test('hermetic source-tree contract fixtures pass', () => {
  const result = spawnSync('bash', [fixtureSuite], {
    cwd: path.resolve(scriptDirectory, '../..'),
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
});
