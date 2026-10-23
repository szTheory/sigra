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

function coverageDirectory(directory, { sourceSha, project = 'chromium', caseTitle = 'actual useful case', result = 'passed',
  seam = 'admin_behavior', classification = 'product' }) {
  mkdirSync(directory, { recursive: true });
  const native = report(['tests/admin-behavior.spec.ts'], [project]);
  const selected = structuredClone(native);
  const item = native.suites[0].specs[0].tests[0];
  const intentionalSkip = classification === 'intentional_skip';
  const identityId = JSON.stringify([project, 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', caseTitle]);
  const selectedItem = selected.suites[0].specs[0].tests[0];
  if (intentionalSkip) item.results = [];
  else item.results[0].status = result;
  item.status = result === 'skipped' ? 'skipped' : 'expected';
  item.expectedStatus = intentionalSkip ? 'skipped' : 'passed';
  selectedItem.status = item.status;
  selectedItem.expectedStatus = item.expectedStatus;
  if (result === 'skipped' || intentionalSkip) {
    native.stats.expected = 0;
    native.stats.skipped = 1;
    selected.stats.expected = 0;
    selected.stats.skipped = 1;
  }
  native.suites[0].specs[0].title = caseTitle;
  selected.suites[0].specs[0].title = caseTitle;
  for (const suite of selected.suites) for (const spec of suite.specs) for (const test of spec.tests) test.results = [];
  const reportPath = 'native.json';
  const selectionPath = 'selection.json';
  writeFileSync(join(directory, reportPath), JSON.stringify(native));
  writeFileSync(join(directory, selectionPath), JSON.stringify(selected));
  const descriptor = { schema_version: 'sigra.browser-coverage-source/v1', source_sha: sourceSha,
    workflow_sha256: 'c'.repeat(64), configuration_sha256: 'd'.repeat(64), lock_sha256: 'e'.repeat(64),
    event: 'pull_request', seam, owner: seam,
    project_inventory: [project], selected_inventory: [{
      id: identityId, project, spec: 'tests/admin-behavior.spec.ts', title: caseTitle, owner: seam, classification,
      ...(intentionalSkip ? { policy_id: 'source-policy-1' } : {}),
    }],
    excluded_inventory: [],
    skip_policies: intentionalSkip ? [{ id: 'source-policy-1', owner: seam,
      source_path: 'test/example/priv/playwright/playwright.config.ts', source_sha256: 'd'.repeat(64),
      selector: `intentional skip: ${caseTitle}`, identities: [identityId] }] : [],
    reports: [{ path: reportPath, selection_path: selectionPath, sha256: hash(join(directory, reportPath)),
      selection_sha256: hash(join(directory, selectionPath)), source_sha: sourceSha }] };
  writeFileSync(join(directory, 'coverage-source.json'), JSON.stringify(descriptor));
}

function compareCoverage(before, after, mapping, extra = []) {
  return spawnSync(process.execPath, [cli, '--compare-coverage', '--before-directory', before,
    '--after-directory', after, '--mapping', mapping, ...extra], { encoding: 'utf8' });
}

test('coverage CLI accepts identical native product identities and rejects equal-count substitutions', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-coverage-compare-'));
  try {
    const before = join(directory, 'before');
    const after = join(directory, 'after');
    const mapping = join(directory, 'mapping.json');
    coverageDirectory(before, { sourceSha: '1'.repeat(40) });
    coverageDirectory(after, { sourceSha: '2'.repeat(40) });
    writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [
      { before: ['chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'],
        after: ['chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'], owner: 'admin_behavior', kind: 'product' },
    ] }));
    const same = compareCoverage(before, after, mapping);
    assert.equal(same.status, 0, same.stderr);
    assert.equal(JSON.parse(same.stdout).status, 'passed');
    coverageDirectory(after, { sourceSha: '2'.repeat(40), caseTitle: 'substituted case' });
    const substituted = compareCoverage(before, after, mapping);
    assert.notEqual(substituted.status, 0, 'equal counts with a different product case must fail');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('coverage CLI rejects changed actual status, excluded work and reports with a wrong digest', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-coverage-status-'));
  try {
    const before = join(directory, 'before');
    const after = join(directory, 'after');
    const mapping = join(directory, 'mapping.json');
    coverageDirectory(before, { sourceSha: '1'.repeat(40) });
    coverageDirectory(after, { sourceSha: '2'.repeat(40), result: 'skipped' });
    writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [
      { before: ['chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'],
        after: ['chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'], owner: 'admin_behavior', kind: 'product' },
    ] }));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'passed to skipped cannot be hidden');
    const descriptorPath = join(after, 'coverage-source.json');
    const descriptor = JSON.parse(readFileSync(descriptorPath, 'utf8'));
    descriptor.reports[0].sha256 = '0'.repeat(64);
    writeFileSync(descriptorPath, JSON.stringify(descriptor));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'native report without matching digest cannot be trusted');
    descriptor.reports[0].source_sha = '3'.repeat(40);
    descriptor.reports[0].sha256 = hash(join(after, 'native.json'));
    writeFileSync(descriptorPath, JSON.stringify(descriptor));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'native report bound to another source cannot be trusted');
    descriptor.reports[0].source_sha = '2'.repeat(40);
    descriptor.excluded_inventory = [{ identity: ['chromium', 'tests/other.spec.ts', ['tests/other.spec.ts'], 'spec-x', 'excluded case'],
      owner: 'admin_behavior', reason: 'unexpected exclusion' }];
    writeFileSync(descriptorPath, JSON.stringify(descriptor));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'newly excluded identity must fail');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('setup dependency rows remain separate and cannot replace product coverage', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-coverage-setup-'));
  try {
    const before = join(directory, 'before');
    const after = join(directory, 'after');
    const mapping = join(directory, 'mapping.json');
    for (const [target, sourceSha] of [[before, '1'.repeat(40)], [after, '2'.repeat(40)]])
      coverageDirectory(target, { sourceSha, project: 'admin-design-setup-chromium', seam: 'design_gallery', classification: 'setup' });
    const id = ['admin-design-setup-chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'];
    writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [
      { before: id, after: id, owner: 'design_gallery', kind: 'setup' },
    ] }));
    const result = compareCoverage(before, after, mapping);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).before_rows, 0);
    assert.equal(JSON.parse(result.stdout).before_setup_rows, 1);
    writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [
      { before: id, after: id, owner: 'design_gallery', kind: 'product' },
    ] }));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'setup dependency cannot be promoted into product coverage');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('intentional skip parity requires the same exact identity and explicit source policy', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-coverage-skip-'));
  try {
    const before = join(directory, 'before');
    const after = join(directory, 'after');
    const mapping = join(directory, 'mapping.json');
    for (const [target, sourceSha] of [[before, '1'.repeat(40)], [after, '2'.repeat(40)]])
      coverageDirectory(target, { sourceSha, result: 'skipped', classification: 'intentional_skip' });
    const id = ['chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'];
    writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [
      { before: id, after: id, owner: 'admin_behavior', kind: 'product' },
    ] }));
    const positive = compareCoverage(before, after, mapping);
    assert.equal(positive.status, 0, positive.stderr);
    const descriptorPath = join(after, 'coverage-source.json');
    const descriptor = JSON.parse(readFileSync(descriptorPath, 'utf8'));
    descriptor.skip_policies = [];
    writeFileSync(descriptorPath, JSON.stringify(descriptor));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'unbound skip allowlisting must fail');
    descriptor.skip_policies = [{ id: 'source-policy-1', owner: 'admin_behavior',
      source_path: 'test/example/priv/playwright/playwright.config.ts', source_sha256: 'd'.repeat(64),
      selector: 'intentional skip: actual useful case', identities: [JSON.stringify(id)] }];
    descriptor.selected_inventory[0].classification = 'product';
    writeFileSync(descriptorPath, JSON.stringify(descriptor));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'skip cannot be silently admitted without explicit policy');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('all five owners require one-to-one product mappings', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-coverage-owners-'));
  try {
    for (const [index, seam] of seams.entries()) {
      const before = join(directory, `before-${seam}`);
      const after = join(directory, `after-${seam}`);
      const mapping = join(directory, `${seam}.json`);
      coverageDirectory(before, { sourceSha: String(index + 1).repeat(40), seam });
      coverageDirectory(after, { sourceSha: (index + 11).toString(16).repeat(40), seam });
      const id = ['chromium', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'];
      const row = { before: id, after: id, owner: seam, kind: 'product' };
      writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [row] }));
      const comparison = compareCoverage(before, after, mapping);
      assert.equal(comparison.status, 0, `${seam} mapping: ${comparison.stderr}`);
      writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [row, row] }));
      assert.notEqual(compareCoverage(before, after, mapping).status, 0, `${seam} duplicate owner mapping`);
    }
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('a missing mobile case cannot be concealed by retaining the chromium count', () => {
  const directory = mkdtempSync(join(tmpdir(), 'browser-coverage-mobile-'));
  try {
    const before = join(directory, 'before');
    const after = join(directory, 'after');
    const mapping = join(directory, 'mapping.json');
    coverageDirectory(before, { sourceSha: '1'.repeat(40), project: 'mobile' });
    coverageDirectory(after, { sourceSha: '2'.repeat(40), project: 'chromium' });
    const mobile = ['mobile', 'tests/admin-behavior.spec.ts', ['tests/admin-behavior.spec.ts'], 'spec-0', 'actual useful case'];
    writeFileSync(mapping, JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: [
      { before: mobile, after: mobile, owner: 'admin_behavior', kind: 'product' },
    ] }));
    assert.notEqual(compareCoverage(before, after, mapping).status, 0, 'missing mobile product identity must fail');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('non-PR design gallery keeps both snapshot and behavior invocations', () => {
  const policy = bodyPolicy('design_gallery', 'push');
  assert.equal(policy.length, 1);
  assert.equal(policy[0].id, 'design_gallery_snapshots');
  assert.deepEqual(policy[0].invocations.map((invocation) => invocation.path), [
    'design-gallery-nonpr-snapshots.json', 'design-gallery-nonpr-behavior.json',
  ]);
});
