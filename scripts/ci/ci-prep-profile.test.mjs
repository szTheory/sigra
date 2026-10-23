import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { buildProfileRecord, mergeProfileRecords, parseActionSteps, parseArgs, parseBrowserMatrix, runMeasuredCommand, sanitizeLog, versionFromOutput } from './ci-prep-profile.mjs';

test('profile CLI accepts source-bound preparation comparison mode', () => {
  assert.deepEqual(parseArgs(['--root', '.', '--scope', 'admin_behavior', '--mode', 'compare-preparation', '--output', 'setup.json']), {
    root: '.', scope: 'admin_behavior', mode: 'compare-preparation', output: 'setup.json', checkOnly: false,
  });
});

test('profile command extraction follows the checked action source', () => {
  const action = `runs:\n  steps:\n    - name: Fetch and compile example\n      run: |\n        set -euo pipefail\n        mix deps.get\n        mix compile --warnings-as-errors\n    - name: Install Playwright dependencies\n      run: npm ci\n`;
  assert.deepEqual(parseActionSteps(action), {
    'Fetch and compile example': ['set -euo pipefail', 'mix deps.get', 'mix compile --warnings-as-errors'],
    'Install Playwright dependencies': ['npm ci'],
  });
});

test('browser selection comes from each workflow matrix scope', () => {
  const workflow = `      matrix:\n        include:\n          - seam: admin_behavior\n            browsers: chromium\n          - seam: non_admin_smoke\n            browsers: chromium webkit\n    services:\n`;
  assert.equal(parseBrowserMatrix(workflow, 'admin_behavior'), 'chromium');
  assert.equal(parseBrowserMatrix(workflow, 'non_admin_smoke'), 'chromium webkit');
  assert.throws(() => parseBrowserMatrix(workflow, 'missing'), /scope_not_found/);
});

test('measured subprocess retains failure, exit and monotonic elapsed time', () => {
  const temp = mkdtempSync(path.join(os.tmpdir(), 'prep-profile-step-'));
  try {
    const result = runMeasuredCommand({ label: 'intentional-failure', command: `node -e 'console.error("intentional-failure"); process.exit(7)'`, cwd: temp, env: process.env, timeoutMs: 10000, logPath: path.join(temp, 'command.log'), clock: (() => { let now = 50; return () => (now += 4); })() });
    assert.equal(result.exit_code, 7);
    assert.ok(result.duration_ms >= 0);
    assert.match(readFileSync(result.log_path, 'utf8'), /intentional-failure/);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('unavailable native steps remain unknown, while command failures remain measured', () => {
  const record = buildProfileRecord({ sourceSha: 'abc', scope: 'admin_behavior', components: [{ name: 'mix-deps', status: 'measured', exit_code: 1, duration_ms: 125 }, { name: 'setup-beam', status: 'unknown', reason: 'local GitHub action timing unavailable' }] });
  assert.deepEqual(record.components.map((component) => component.status), ['measured', 'unknown']);
  assert.equal(record.components[0].exit_code, 1);
  assert.equal(record.status, 'blocked');
});

test('scope merge preserves each original source-bound record and refuses source mismatch', () => {
  const one = buildProfileRecord({ sourceSha: 'abc', scope: 'admin_behavior', components: [] });
  const two = buildProfileRecord({ sourceSha: 'abc', scope: 'non_admin_smoke', components: [] });
  const merged = mergeProfileRecords(one, two);
  assert.deepEqual(Object.keys(merged.scopes).sort(), ['admin_behavior', 'non_admin_smoke']);
  assert.throws(() => mergeProfileRecords(one, buildProfileRecord({ sourceSha: 'different', scope: 'non_admin_smoke', components: [] })), /source_identity_mismatch/);
});

test('Elixir version records the Elixir line rather than OTP banner', () => {
  assert.equal(versionFromOutput('elixir', 'Erlang/OTP 28\nElixir 1.19.5 (compiled with Erlang/OTP 28)\n'), 'Elixir 1.19.5 (compiled with Erlang/OTP 28)');
  assert.equal(versionFromOutput('node', 'v20.18.1\n'), 'v20.18.1');
});

test('diagnostic log excerpts remove seeded credentials and labeled secrets', () => {
  const output = sanitizeLog('grace@demo.test GraceDemoPass1!Acme\napi_key=abc123\nghp_abcdefghijklmnopqrstuvwxyz012345');
  assert.doesNotMatch(output, /GraceDemoPass|abc123|ghp_abcdefghijklmnopqrstuvwxyz/);
  assert.match(output, /\[redacted\]/);
});
