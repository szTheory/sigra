import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
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
