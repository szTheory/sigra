import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const runner = path.join(root, 'scripts/ci/ci-registration-repro.sh');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-recovery-red-'));

test('diagnostic verification rejects caller-written success without native receipts', () => {
  const evidence = path.join(temporary, 'forged-success.json');
  fs.writeFileSync(evidence, JSON.stringify({
    schema_version: 'sigra.phase253.registration-recovery-evidence/v1',
    status: 'not_reproduced',
    requirements: { 'CIREL-01': 'unsatisfied' },
    attempts: [{ project: 'admin-eval', outcome: 'passed' }]
  }));

  const result = spawnSync(runner, ['--verify-diagnostic', evidence], { encoding: 'utf8' });

  assert.equal(result.status, 3, `${result.stdout}\n${result.stderr}`);
  assert.match(result.stderr, /native report|native receipts/i);
});

test('the original controls and acceptance verification modes remain unavailable', () => {
  const evidence = path.join(temporary, 'legacy-forged.json');
  fs.writeFileSync(evidence, JSON.stringify({ status: 'fixed', projects: [] }));

  for (const mode of ['--verify-controls', '--verify-acceptance']) {
    const result = spawnSync(runner, [mode, evidence], { encoding: 'utf8' });
    assert.equal(result.status, 3, `${mode}: ${result.stdout}\n${result.stderr}`);
  }
});

test.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
