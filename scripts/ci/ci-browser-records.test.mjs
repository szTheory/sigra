import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { bodyPolicy } from './ci-browser-records.mjs';

const cli = new URL('./ci-browser-records.mjs', import.meta.url).pathname;
const hash = (path) => createHash('sha256').update(readFileSync(path)).digest('hex');
const workflowHash = () => hash(new URL('../../.github/workflows/ci.yml', import.meta.url));
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
  const record = { schema_version: 'sigra.browser-execution-record/v1', ...identity, workflow_file_sha256: workflowHash(), seam: 'non_admin_smoke',
    selected_steps: [{ id: 'non_admin_smoke', outcome: 'success', conclusion: 'success',
      reports: [{ path: 'non-admin-smoke.json', selection_path: 'non-admin-smoke.selection.json',
        sha256: hash(join(directory, 'non-admin-smoke.json')), selection_sha256: hash(join(directory, 'non-admin-smoke.selection.json')) }] }] };
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

const seams = ['non_admin_smoke', 'admin_behavior', 'admin_checkpoints', 'design_gallery', 'demo_showcase'];
function fullFixture(directory, current = identity) {
  for (const seam of seams) {
    const target = join(directory, `browser-execution-${seam}-${current.run_id}-${current.run_attempt}`);
    mkdirSync(target, { recursive: true });
    const record = { schema_version: 'sigra.browser-execution-record/v1', ...current, workflow_file_sha256: workflowHash(), seam, selected_steps: [] };
    for (const policy of bodyPolicy(seam, current.event)) {
      const step = { id: policy.id, outcome: 'success', conclusion: 'success', reports: [] };
      for (const invocation of policy.invocations) {
        const native = report(invocation.specs, invocation.projects);
        if (seam === 'design_gallery') {
          const setup = report(['admin-design.setup.ts'], invocation.projects.map((project) => project.replace('admin-design-', 'admin-design-setup-')));
          native.config.projects.push(...setup.config.projects);
          native.suites.push(...setup.suites);
          native.stats.expected += setup.stats.expected;
        }
        const selection = structuredClone(native);
        for (const suite of selection.suites) for (const spec of suite.specs) for (const selected of spec.tests) selected.results = [];
        writeFileSync(join(target, invocation.path), JSON.stringify(native));
        writeFileSync(join(target, invocation.selection_path), JSON.stringify(selection));
        step.reports.push({ path: invocation.path, selection_path: invocation.selection_path,
          sha256: hash(join(target, invocation.path)), selection_sha256: hash(join(target, invocation.selection_path)) });
      }
      record.selected_steps.push(step);
    }
    writeFileSync(join(target, 'execution-record.json'), JSON.stringify(record));
  }
}
function aggregate(directory, current = identity, native = 'success') {
  const path = join(directory, 'identity.json');
  writeFileSync(path, JSON.stringify(current));
  return spawnSync(process.execPath, [cli, '--verify', '--directory', directory, '--identity', path,
    '--native-result', native], { encoding: 'utf8' });
}
test('exactly five browser producers and all native selections are required', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-record-set-'));
  try {
    fullFixture(directory);
    const positive = aggregate(directory);
    assert.equal(positive.status, 0, positive.stderr);
    assert.equal(JSON.parse(positive.stdout).seams.length, 5);
    rmSync(join(directory, `browser-execution-demo_showcase-${identity.run_id}-1`), { recursive: true });
    assert.notEqual(aggregate(directory).status, 0, 'missing producer cannot be green');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('adversarial record identity, shape, outcome and report controls fail closed', async (t) => {
  const mutations = {
    'null record': (r) => null,
    'empty record': () => ({}),
    'unknown seam': (r) => ({ ...r, seam: 'other' }),
    'case variant': (r) => ({ ...r, seam: 'NON_ADMIN_SMOKE' }),
    'space variant': (r) => ({ ...r, seam: 'non_admin_smoke ' }),
    'unicode variant': (r) => ({ ...r, seam: 'non_аdmin_smoke' }),
    'wrong run': (r) => ({ ...r, run_id: '253124' }),
    'wrong attempt': (r) => ({ ...r, run_attempt: '2' }),
    'wrong source': (r) => ({ ...r, source_sha: 'c'.repeat(40) }),
    'wrong workflow': (r) => ({ ...r, workflow_sha: 'c'.repeat(40) }),
    'wrong event': (r) => ({ ...r, event: 'push' }),
    'no selected body': (r) => ({ ...r, selected_steps: [] }),
    'duplicate selected body': (r) => ({ ...r, selected_steps: [...r.selected_steps, ...r.selected_steps] }),
    'unexpected skip': (r) => { r.selected_steps[0].outcome = r.selected_steps[0].conclusion = 'skipped'; return r; },
    'cancelled body': (r) => { r.selected_steps[0].outcome = r.selected_steps[0].conclusion = 'cancelled'; return r; },
    'masked failed body': (r) => { r.selected_steps[0].outcome = 'failure'; return r; },
    'missing reports': (r) => { r.selected_steps[0].reports = []; return r; },
    'wrong hash': (r) => { r.selected_steps[0].reports[0].sha256 = '0'.repeat(64); return r; },
    'traversal': (r) => { r.selected_steps[0].reports[0].path = '../non-admin-smoke.json'; return r; },
  };
  for (const [name, mutate] of Object.entries(mutations)) await t.test(name, () => {
    const directory = mkdtempSync(join(tmpdir(), 'browser-record-negative-'));
    try {
      fullFixture(directory);
      const path = join(directory, `browser-execution-non_admin_smoke-${identity.run_id}-1/execution-record.json`);
      writeFileSync(path, JSON.stringify(mutate(JSON.parse(readFileSync(path, 'utf8')))));
      assert.notEqual(aggregate(directory).status, 0, name);
    } finally { rmSync(directory, { recursive: true, force: true }); }
  });
});

test('only a successful actual PR classifier exempts all five selected bodies', () => {
  for (const [event, classifier_result, docs_only, succeeds] of [
    ['pull_request', 'success', 'true', true], ['pull_request', 'failure', 'true', false],
    ['pull_request', 'success', 'TRUE', false], ['pull_request', 'success', '', false],
    ['workflow_dispatch', 'success', 'true', false], ['push', 'success', 'true', false],
  ]) {
    const directory = mkdtempSync(join(tmpdir(), 'browser-record-docs-'));
    try {
      const current = { ...identity, event, classifier_result, docs_only };
      fullFixture(directory, current);
      for (const seam of seams) {
        const path = join(directory, `browser-execution-${seam}-${identity.run_id}-1/execution-record.json`);
        const record = JSON.parse(readFileSync(path, 'utf8'));
        for (const step of record.selected_steps) { step.outcome = step.conclusion = 'skipped'; step.reports = []; }
        writeFileSync(path, JSON.stringify(record));
      }
      assert.equal(aggregate(directory, current).status === 0, succeeds, `${event}/${classifier_result}/${docs_only}`);
      if (succeeds) assert.notEqual(aggregate(directory, current, 'failure').status, 0, 'records never override native failure');
    } finally { rmSync(directory, { recursive: true, force: true }); }
  }
});

test('missing unknown duplicate and symlink producers cannot pass', () => {
  for (const kind of ['empty', 'singleton', 'unknown', 'duplicate', 'symlink']) {
    const directory = mkdtempSync(join(tmpdir(), 'browser-record-intake-'));
    try {
      fullFixture(directory);
      if (kind === 'empty' || kind === 'singleton') for (const seam of seams.slice(kind === 'singleton' ? 1 : 0))
        rmSync(join(directory, `browser-execution-${seam}-${identity.run_id}-1`), { recursive: true });
      if (kind === 'unknown' || kind === 'duplicate') mkdirSync(join(directory, `browser-execution-${kind}-${identity.run_id}-1`));
      if (kind === 'symlink') {
        const path = join(directory, `browser-execution-demo_showcase-${identity.run_id}-1`);
        rmSync(path, { recursive: true }); symlinkSync(tmpdir(), path);
      }
      assert.notEqual(aggregate(directory).status, 0, kind);
    } finally { rmSync(directory, { recursive: true, force: true }); }
  }
});

test('native reports cannot lose tests, fail, retry, truncate or change project selection', () => {
  for (const kind of ['missing-test', 'wrong-project', 'failed', 'retry', 'malformed', 'symlink', 'missing-selection', 'all-skipped']) {
    const directory = mkdtempSync(join(tmpdir(), 'browser-native-negative-'));
    try {
      nonAdminFixture(directory);
      const path = join(directory, 'non-admin-smoke.json');
      const recordPath = join(directory, 'execution-record.json');
      const native = JSON.parse(readFileSync(path));
      if (kind === 'missing-test') { native.suites[0].specs[0].tests.pop(); native.stats.expected--; }
      if (kind === 'wrong-project') native.suites[0].specs[0].tests[0].projectName = 'mobile';
      if (kind === 'failed') native.suites[0].specs[0].tests[0].results[0].status = 'failed';
      if (kind === 'retry') native.suites[0].specs[0].tests[0].results[0].retry = 1;
      if (kind === 'all-skipped') for (const suite of native.suites) for (const entry of suite.specs[0].tests) {
        entry.status = entry.expectedStatus = 'skipped'; entry.results = [];
      }
      if (kind === 'all-skipped') { native.stats.skipped = native.stats.expected; native.stats.expected = 0; }
      writeFileSync(path, kind === 'malformed' ? '{"config":' : JSON.stringify(native));
      const record = JSON.parse(readFileSync(recordPath)); record.selected_steps[0].reports[0].sha256 = hash(path);
      writeFileSync(recordPath, JSON.stringify(record));
      if (kind === 'symlink') { rmSync(path); symlinkSync(join(directory, 'non-admin-smoke.selection.json'), path); }
      if (kind === 'missing-selection') rmSync(join(directory, 'non-admin-smoke.selection.json'));
      assert.notEqual(invoke(directory).status, 0, kind);
    } finally { rmSync(directory, { recursive: true, force: true }); }
  }
});

test('the producer records actual selected outcomes and copies only native report files', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-record-writer-'));
  try {
    const reports = join(directory, 'reports'); mkdirSync(reports); nonAdminFixture(reports);
    const output = join(directory, 'output');
    const result = spawnSync(process.execPath, [cli, '--record', '--directory', output,
      '--reports-directory', reports, '--seam', 'non_admin_smoke'], { encoding: 'utf8', env: {
        ...process.env, GITHUB_RUN_ID: identity.run_id, GITHUB_RUN_ATTEMPT: identity.run_attempt,
        GITHUB_SHA: identity.source_sha, GITHUB_EVENT_NAME: identity.event,
        GITHUB_WORKFLOW_REF: identity.workflow_ref, GITHUB_WORKFLOW_SHA: identity.workflow_sha,
        CLASSIFIER_RESULT: identity.classifier_result, DOCS_ONLY: identity.docs_only,
        SELECTED_STEPS_JSON: JSON.stringify({ non_admin_smoke: { outcome: 'success', conclusion: 'success' } }),
      } });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(invoke(output).status, 0, 'record writer output must pass the actual validator');
    assert.equal(JSON.parse(readFileSync(join(output, 'execution-record.json'))).selected_steps[0].outcome, 'success');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
