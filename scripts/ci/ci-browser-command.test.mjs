import test from 'node:test';
import assert from 'node:assert/strict';
import { browserInvocations } from './ci-browser-command.mjs';

test('demo showcase selection preserves the real CI spec, project, retries, and report names', () => {
  assert.deepEqual(browserInvocations('demo_showcase', 'pull_request'), [{
    id: 'demo_showcase',
    invocations: [{
      specs: ['tests/demo-showcase.spec.ts'],
      projects: ['demo-showcase-chromium'],
      grep: null,
      retries: 0,
      selectionPath: 'demo-showcase.selection.json',
      reportPath: 'demo-showcase.json',
    }],
  }]);
});
