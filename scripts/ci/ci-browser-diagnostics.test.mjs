import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import FailureJsonlReporter from '../../test/example/priv/playwright/lib/reporters/failure-jsonl.mjs';

test('reporter records startup errors before any test-end events', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-playwright-diagnostics-'));
  const outputFile = path.join(root, 'failure.jsonl');
  const reporter = new FailureJsonlReporter({
    outputFile,
    invocationId: 'diagnostic-invocation-01',
    nativeIdentity: 'chromium:playwright-diagnostics.spec.ts',
  });

  try {
    assert.equal(typeof reporter.onError, 'function', 'reporter must capture pre-test errors independently of onTestEnd');
    reporter.onError({ message: 'No tests found', location: { file: 'fixtures/missing.spec.ts', line: 1, column: 1 } });

    const [record] = fs.readFileSync(outputFile, 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(record.type, 'error');
    assert.equal(record.invocation_id, 'diagnostic-invocation-01');
    assert.equal(record.native_identity, 'chromium:playwright-diagnostics.spec.ts');
    assert.equal(record.error.message, 'No tests found');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('onTestEnd keeps the established event schema and fields while adding invocation identity', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-playwright-test-end-'));
  const outputFile = path.join(root, 'failure.jsonl');
  const reporter = new FailureJsonlReporter({
    outputFile,
    invocationId: 'diagnostic-invocation-02',
    nativeIdentity: 'chromium:admin-theme.spec.ts',
  });

  try {
    reporter.onTestEnd({
      title: 'admin theme toggles dark mode',
      location: { file: 'tests/admin-theme.spec.ts', line: 12 },
      expectedStatus: 'passed',
      ok: () => false,
      parent: { project: () => ({ name: 'chromium' }) },
    }, {
      status: 'failed',
      duration: 42,
      retry: 0,
      errors: [{ message: 'assertion failed' }],
    });

    const [record] = fs.readFileSync(outputFile, 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(record.schema, 'sigra.phase253.playwright-test-end/v1');
    assert.equal(record.title, 'admin theme toggles dark mode');
    assert.equal(record.status, 'failed');
    assert.equal(record.retry, 0);
    assert.deepEqual(record.errors.map((error) => error.message), ['assertion failed']);
    assert.equal(record.invocation_id, 'diagnostic-invocation-02');
    assert.equal(record.native_identity, 'chromium:admin-theme.spec.ts');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('local reproduction exposes a retained native diagnostics mode', () => {
  const runner = spawnSync('python3', ['-B', 'scripts/ci/ci-browser-local.py', '--help'], {
    cwd: path.resolve(import.meta.dirname, '../..'),
    encoding: 'utf8',
  });

  assert.equal(runner.status, 0, runner.stderr);
  assert.match(runner.stdout, /--diagnostic-case/);
  assert.match(runner.stdout, /--keep-output/);
});
