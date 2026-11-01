import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

test('phase 250 canary contract tests pass', () => {
  const result = spawnSync('mix', ['test', 'test/sigra/planning/phase_250_canary_contract_test.exs'], {
    cwd: new URL('../..', import.meta.url),
    encoding: 'utf8',
    env: process.env,
  });

  assert.equal(result.error, undefined, `could not run ExUnit target: ${result.error?.message ?? ''}`);
  assert.equal(result.status, 0, `ExUnit canary target failed:
${result.stdout}
${result.stderr}`);
});
