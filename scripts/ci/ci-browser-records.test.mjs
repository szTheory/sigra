import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const cli = new URL('./ci-browser-records.mjs', import.meta.url).pathname;
const identity = { run_id: '253123', run_attempt: '1', source_sha: 'a'.repeat(40),
  event: 'pull_request', workflow_ref: 'szTheory/sigra/.github/workflows/ci.yml@refs/heads/phase253',
  workflow_sha: 'b'.repeat(40), classifier_result: 'success', docs_only: 'false' };

function report(specs, projects) {
  const suites = specs.map((file, index) => ({ title: file, file, specs: [{ id: `spec-${index}`,
    title: `selected case ${index}`, file, tests: projects.filter((project) => project !== 'mobile' ||
      !/passkeys-hooks|passkey-login|passkey-options/.test(file)).map((project) => ({
        projectId: project, projectName: project, expectedStatus: 'passed', status: 'expected',
        results: [{ retry: 0, status: 'passed', duration: 1, startTime: '2026-10-13T00:00:00Z' }],
      })) }] }));
  const count = suites.reduce((sum, suite) => sum + suite.specs[0].tests.length, 0);
  return { config: { projects: projects.map((name) => ({ id: name, name })) }, suites, errors: [],
    stats: { expected: count, unexpected: 0, flaky: 0, skipped: 0, startTime: '2026-10-13T00:00:00Z', duration: 10 } };
}

function nonAdminFixture(directory) {
  const specs = ['golden-path', 'ga-uat-shift-left', 'passkeys-hooks', 'organizations', 'passkey-login', 'passkey-options'].map((name) => `tests/${name}.spec.ts`);
  const native = report(specs, ['chromium', 'mobile']);
  const selection = structuredClone(native);
  for (const suite of selection.suites) for (const spec of suite.specs) for (const selected of spec.tests) selected.results = [];
  writeFileSync(join(directory, 'non-admin-smoke.json'), JSON.stringify(native));
  writeFileSync(join(directory, 'non-admin-smoke.selection.json'), JSON.stringify(selection));
  const record = { schema_version: 'sigra.browser-execution-record/v1', ...identity, seam: 'non_admin_smoke',
    selected_steps: [{ id: 'non_admin_smoke', outcome: 'success', conclusion: 'success',
      reports: [{ path: 'non-admin-smoke.json', selection_path: 'non-admin-smoke.selection.json' }] }] };
  writeFileSync(join(directory, 'execution-record.json'), JSON.stringify(record));
}

function invoke(directory, extra = []) {
  const identityPath = join(directory, 'identity.json');
  writeFileSync(identityPath, JSON.stringify(identity));
  return spawnSync(process.execPath, [cli, '--verify-seam', 'non_admin_smoke', '--directory', directory,
    '--identity', identityPath, '--native-result', 'success', ...extra], { encoding: 'utf8' });
}

test('a selected full browser seam requires its complete native report', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-record-tracer-'));
  try {
    nonAdminFixture(directory);
    const positive = invoke(directory);
    assert.equal(positive.status, 0, positive.stderr);
    assert.equal(JSON.parse(positive.stdout).status, 'passed');
    writeFileSync(join(directory, 'non-admin-smoke.json'), '{}');
    assert.notEqual(invoke(directory).status, 0, 'empty native report cannot be green');
    rmSync(join(directory, 'non-admin-smoke.json'));
    assert.notEqual(invoke(directory).status, 0, 'missing native report cannot be green');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
