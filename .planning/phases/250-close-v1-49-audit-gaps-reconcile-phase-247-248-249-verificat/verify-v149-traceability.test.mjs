import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { audit } from './verify-v149-traceability.mjs';

const repoRoot = path.resolve('.');

test('strict matrix keeps all nine milestone requirements and preserves known gaps', () => {
  const result = audit(repoRoot);
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.requirements.length, 9);
  assert.equal(result.score.requirements, '3/9');
  assert.ok(result.blockers.some(({ id }) => id === 'READY-01'));
  assert.ok(result.blockers.some(({ id }) => id === 'AUTO-02'));
  assert.ok(result.blockers.some(({ id }) => id === 'REL-02'));
});

test('second audit run is deterministic apart from capture time', () => {
  const first = audit(repoRoot);
  const second = audit(repoRoot);
  assert.deepEqual({ ...first, capturedAt: null }, { ...second, capturedAt: null });
});

test('owner source identity changes are reported against their requirement rows', () => {
  const scratch = mkdtempSync(path.join(os.tmpdir(), 'v149-trace-'));
  try {
    const result = audit(repoRoot, {
      overrides: {
        '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md':
          (source) => source.replace('current_protected_main_sha":"6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5', 'current_protected_main_sha":"deadbeef'),
      },
    });
    assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /identity/i.test(row.message)));
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
});

test('accepted historical handoff loss must remain explicitly unrecovered', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md':
        (source) => source.replace('were not recovered and were not preserved', 'were recovered and preserved'),
    },
  });
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /accepted-loss|recovered|preserved/i.test(row.message)));
});
