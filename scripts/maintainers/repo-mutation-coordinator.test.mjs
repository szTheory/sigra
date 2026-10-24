import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const suite = path.join(testDir, 'repo-mutation-coordinator.test.sh');

test('coordinator probes symbolic HEAD support before target installation and gates supported mutations', () => {
  const result = spawnSync('bash', [suite], { cwd: path.resolve(testDir, '../..'), encoding: 'utf8' });
  assert.equal(result.status, 0, `${result.stdout ?? ''}${result.stderr ?? ''}`);
});
