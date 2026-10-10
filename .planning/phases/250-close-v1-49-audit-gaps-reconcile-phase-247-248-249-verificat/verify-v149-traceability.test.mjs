import assert from 'node:assert/strict';
import path from 'node:path';
import test from 'node:test';
import { audit, checkAudit, renderAudit } from './verify-v149-traceability.mjs';

const repoRoot = path.resolve('.');

test('strict matrix keeps all nine milestone requirements and preserves known gaps', () => {
  const result = audit(repoRoot);
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.requirements.length, 9);
  assert.equal(result.score.requirements, '5/9');
  assert.equal(result.score.integration, '3/5');
  assert.equal(result.score.flows, '1/4');
  assert.deepEqual(result.nyquist.missingPhases, [250]);
  assert.equal(result.nyquist.overall, 'partial');
  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.status, 'unsatisfied');
  assert.ok(result.blockers.some(({ id }) => id === 'READY-01'));
  assert.ok(result.blockers.some(({ id }) => id === 'AUTO-02'));
  assert.ok(result.blockers.some(({ id }) => id === 'REL-02'));
});

test('generated audit reports integration review and Nyquist gaps from source state', () => {
  const result = audit(repoRoot);
  const report = renderAudit(result);
  assert.match(report, /requirements: 5\/9/);
  assert.match(report, /owner_report_status: "gaps_found"/);
  assert.match(report, /integration: 3\/5/);
  assert.match(report, /2\/5 broken at the evidence\/acceptance join/);
  assert.match(report, /missing_phases: \[250\]/);
  assert.match(report, /status: "blocked"/);
});

test('second audit run is deterministic apart from capture time', () => {
  const first = audit(repoRoot);
  const second = audit(repoRoot);
  assert.deepEqual({ ...first, capturedAt: null }, { ...second, capturedAt: null });
});

test('owner source identity changes are reported against their requirement rows', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md':
        (source) => source.replace('current_protected_main_sha":"6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5', 'current_protected_main_sha":"deadbeef'),
    },
  });
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /identity/i.test(row.message)));
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

test('missing hosted failure/cancellation proof remains an AUTO-02 blocker', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PROOF.json': null,
    },
  });
  assert.ok(result.blockers.some((row) => row.id === 'AUTO-02' && /canary|artifact/i.test(row.message)));
});

test('fresh current-main and open-PR inventory is bound to the owner snapshot', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-05-CURRENT-INVENTORY.json':
        (source) => source.replace('6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5', 'deadbeef'),
    },
  });
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /fresh GitHub main observation/i.test(row.message)));
});

test('a Phase 250 summary cannot claim original owner requirements', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-04-SUMMARY.md':
        (source) => source.replace('requirements-completed: []', 'requirements-completed: [REL-02]'),
    },
  });
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /phase 250|owner/i.test(row.message)));
});

test('a hand-edited 8/9 or passed audit cannot override computed source gaps', () => {
  const result = checkAudit(repoRoot, '.planning/v1.49-MILESTONE-AUDIT.md', {
    '.planning/v1.49-MILESTONE-AUDIT.md': (source) => source.replace('status: gaps_found', 'status: passed').replace('requirements: 5/9', 'requirements: 8/9'),
  });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((message) => /status does not match/i.test(message)));
});
