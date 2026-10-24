import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { browserInvocations } from './ci-browser-command.mjs';

const expectedDefinitions = {
  admin_behavior: { specs: ['admin-user-operations', 'impersonation', 'admin-audit', 'admin-theme', 'admin-coherence-sweep',
    'admin-modal-interaction', 'admin-flow-platform-admin', 'admin-flow-support-investigator', 'admin-flow-org-admin'],
    projects: ['chromium'], reports: ['admin-behavior.json'] },
  admin_checkpoints: { specs: ['admin-checkpoints'], projects: ['admin-checkpoints-chromium', 'admin-checkpoints-mobile', 'admin-checkpoints-dark'],
    reports: ['admin-checkpoints.json'] },
  design_gallery: { specs: ['admin-design'], projects: ['admin-design-chromium', 'admin-design-mobile', 'admin-design-dark'],
    reports: ['design-gallery-pr-behavior.json'] },
  non_admin_smoke: { specs: ['golden-path', 'ga-uat-shift-left', 'passkeys-hooks', 'organizations', 'passkey-login', 'passkey-options'],
    projects: ['chromium', 'mobile'], reports: ['non-admin-smoke.json'] },
  demo_showcase: { specs: ['demo-showcase'], projects: ['demo-showcase-chromium'], reports: ['demo-showcase.json'] },
};

test('shared definitions preserve exact CI specs, projects, filters, retry count, and report paths', () => {
  for (const [seam, expected] of Object.entries(expectedDefinitions)) {
    const policy = browserInvocations(seam, 'pull_request');
    assert.equal(policy.length, 1);
    assert.equal(policy[0].id, seam);
    assert.deepEqual(policy[0].invocations.map((entry) => entry.specs.map((spec) => spec.replace(/^tests\//, '').replace(/\.spec\.ts$/, ''))),
      [expected.specs], `${seam} exact spec list`);
    assert.deepEqual(policy[0].invocations.map((entry) => entry.projects), [expected.projects], `${seam} project inventory`);
    assert.deepEqual(policy[0].invocations.map((entry) => entry.reportPath), expected.reports);
    for (const entry of policy[0].invocations) {
      assert.equal(entry.retries, 0);
      assert.equal(entry.selectionPath, entry.reportPath.replace(/\.json$/, '.selection.json'));
    }
  }
  assert.equal(browserInvocations('design_gallery', 'pull_request')[0].invocations[0].grepInvert, '@snapshot');
  const nonPr = browserInvocations('design_gallery', 'push')[0];
  assert.equal(nonPr.id, 'design_gallery_snapshots');
  assert.deepEqual(nonPr.invocations.map(({ grep, grepInvert }) => [grep, grepInvert]), [
    ['@snapshot', null], [null, '@snapshot'],
  ]);
  assert.deepEqual(nonPr.invocations.map((entry) => entry.reportPath), [
    'design-gallery-nonpr-snapshots.json', 'design-gallery-nonpr-behavior.json',
  ]);
  assert.deepEqual(browserInvocations('design_gallery', 'push')[0].invocations.map((entry) => entry.selectionPath), [
    'design-gallery-nonpr-snapshots.selection.json', 'design-gallery-nonpr-behavior.selection.json',
  ]);
});

test('the shared demo showcase list command produces the real native selection', () => {
  const output = mkdtempSync(join(tmpdir(), 'sigra-browser-selection-'));
  try {
    const cli = new URL('./ci-browser-command.mjs', import.meta.url).pathname;
    const result = spawnSync(process.execPath, [cli, 'list', '--seam', 'demo_showcase', '--event', 'pull_request',
      '--output-root', output], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    const report = JSON.parse(readFileSync(join(output, 'demo-showcase.selection.json'), 'utf8'));
    const selected = [];
    const visit = (suites) => suites.forEach((suite) => {
      for (const spec of suite.specs ?? []) for (const item of spec.tests) selected.push([item.projectName, spec.file.split('/').at(-1)]);
      if (suite.suites) visit(suite.suites);
    });
    visit(report.suites);
    assert.ok(selected.length > 0, 'native Playwright selection must contain tests');
    assert.ok(selected.every(([project, spec]) => project === 'demo-showcase-chromium' && spec === 'demo-showcase.spec.ts'));
    assert.deepEqual(new Set(selected.map(([project]) => project)), new Set(['demo-showcase-chromium']));
  } finally { rmSync(output, { recursive: true, force: true }); }
});

test('native Playwright selections match exact spec/project identities for every seam and event', () => {
  const expected = {
    admin_behavior: [['admin-user-operations', 'chromium'], ['impersonation', 'chromium'], ['admin-audit', 'chromium'],
      ['admin-theme', 'chromium'], ['admin-coherence-sweep', 'chromium'], ['admin-modal-interaction', 'chromium'],
      ['admin-flow-platform-admin', 'chromium'], ['admin-flow-support-investigator', 'chromium'], ['admin-flow-org-admin', 'chromium']],
    admin_checkpoints: [['admin-checkpoints', 'admin-checkpoints-chromium'], ['admin-checkpoints', 'admin-checkpoints-mobile'],
      ['admin-checkpoints', 'admin-checkpoints-dark']],
    design_gallery: [['admin-design', 'admin-design-chromium'], ['admin-design', 'admin-design-mobile'], ['admin-design', 'admin-design-dark'],
      ['admin-design.setup.ts', 'admin-design-setup-chromium'], ['admin-design.setup.ts', 'admin-design-setup-mobile'],
      ['admin-design.setup.ts', 'admin-design-setup-dark']],
    non_admin_smoke: [['golden-path', 'chromium'], ['golden-path', 'mobile'], ['ga-uat-shift-left', 'chromium'], ['ga-uat-shift-left', 'mobile'],
      ['passkeys-hooks', 'chromium'], ['organizations', 'chromium'], ['organizations', 'mobile'], ['passkey-login', 'chromium'],
      ['passkey-options', 'chromium']],
    demo_showcase: [['demo-showcase', 'demo-showcase-chromium']],
  };
  const cli = new URL('./ci-browser-command.mjs', import.meta.url).pathname;
  const output = mkdtempSync(join(tmpdir(), 'sigra-browser-all-selections-'));
  try {
    for (const seam of Object.keys(expected)) for (const event of ['pull_request', 'push']) {
      const root = join(output, `${seam}-${event}`);
      const result = spawnSync(process.execPath, [cli, 'list', '--seam', seam, '--event', event, '--output-root', root], {
        encoding: 'utf8', maxBuffer: 64 * 1024 * 1024,
      });
      assert.equal(result.status, 0, `${seam}/${event}: ${result.stderr || result.stdout}`);
      const selected = new Set();
      for (const entry of browserInvocations(seam, event)[0].invocations) {
        const report = JSON.parse(readFileSync(join(root, entry.selectionPath), 'utf8'));
        const visit = (suites) => suites.forEach((suite) => {
          for (const spec of suite.specs ?? []) for (const item of spec.tests)
            selected.add(JSON.stringify([spec.file.replace(/\.spec\.ts$/, '').split('/').at(-1), item.projectName]));
          if (suite.suites) visit(suite.suites);
        });
        visit(report.suites);
      }
      assert.deepEqual([...selected].sort(), expected[seam].map((row) => JSON.stringify(row)).sort(), `${seam}/${event} native identity drift`);
    }
  } finally { rmSync(output, { recursive: true, force: true }); }
});

test('demo showcase selection preserves report identities and zero retries', () => {
  assert.deepEqual(browserInvocations('demo_showcase', 'pull_request'), [{
    id: 'demo_showcase',
    invocations: [{
      specs: ['tests/demo-showcase.spec.ts'],
      projects: ['demo-showcase-chromium'],
      projectArgs: ['demo-showcase-chromium'],
      grep: null,
      grepInvert: null,
      retries: 0,
      selectionPath: 'demo-showcase.selection.json',
      reportPath: 'demo-showcase.json',
    }],
  }]);
});
