import assert from 'node:assert/strict';
import path from 'node:path';
import test from 'node:test';
import { audit, checkAudit, renderAudit } from './verify-v149-traceability.mjs';

const repoRoot = path.resolve('.');
const closeDir = '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat';
const acceptancePath = closeDir + '/250-ACCEPTANCE-AMENDMENT.json';

test('strict matrix keeps READY unsatisfied while accepting exactly two phase-only exceptions', () => {
  const result = audit(repoRoot);
  assert.equal(result.status, 'accepted_exceptions');
  assert.equal(result.milestoneStatus, 'incomplete');
  assert.equal(result.requirements.length, 9);
  assert.equal(result.score.requirements, '7/9');
  assert.equal(result.score.phases, '4/6');
  assert.equal(result.score.integration, '4/5');
  assert.equal(result.score.flows, '3/4');
  assert.equal(result.acceptedExceptionCount, 2);
  assert.equal(result.unacceptedBlockerCount, 0);
  assert.deepEqual(result.blockers, []);
  assert.deepEqual(result.acceptedExceptions.map(({ id }) => id), ['READY-01', 'READY-02']);

  for (const id of ['READY-01', 'READY-02']) {
    const row = result.requirements.find((requirement) => requirement.id === id);
    assert.equal(row?.status, 'unsatisfied');
    assert.equal(row?.verification_status, 'unsatisfied');
    assert.equal(row?.owner_report_status, 'gaps_found');
    assert.equal(row?.acceptance_status, 'accepted_exception');
    assert.equal(row?.traceability, 'open');
  }

  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-02')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-02')?.status, 'satisfied');
  assert.equal(result.acceptedExceptions[0].evidence_blockers.length, 7);
  assert.equal(result.acceptedExceptions[1].evidence_blockers.length, 3);
  assert.ok(result.sourceBlockers.some(({ id }) => id === 'READY-01'));
  assert.ok(result.sourceBlockers.some(({ id }) => id === 'READY-02'));
});

test('generated audit identifies the two exceptions and never claims milestone completion', () => {
  const report = renderAudit(audit(repoRoot));
  assert.match(report, /^status: gaps_found$/m);
  assert.match(report, /^source_audit_status: accepted_exceptions$/m);
  assert.match(report, /^milestone_status: incomplete$/m);
  assert.match(report, /^  requirements: 7\/9$/m);
  assert.match(report, /^accepted_exception_count: 2$/m);
  assert.match(report, /^accepted_exception_ids: \[READY-01, READY-02\]$/m);
  assert.match(report, /^unaccepted_blocker_count: 0$/m);
  assert.match(report, /acceptance_status: "accepted_exception"/);
  assert.match(report, /strict milestone status is \*\*gaps_found\*\*/);
  assert.match(report, /READY-01 and READY-02 remain unsatisfied in Phase 247/);
  assert.doesNotMatch(report, /^status: passed$/m);
  assert.doesNotMatch(report, /9\/9/);
});

test('audit discovers current Nyquist classifications from every v1.49 phase record', () => {
  const result = audit(repoRoot);
  assert.deepEqual(result.nyquist.compliantPhases, [246, 248, 249, 250]);
  assert.deepEqual(result.nyquist.partialPhases, [247]);
  assert.deepEqual(result.nyquist.notValidatedPhases, []);
  assert.deepEqual(result.nyquist.missingPhases, [251]);
  assert.equal(result.nyquist.overall, 'partial');
  assert.match(renderAudit(result), /Phase 248: \*\*compliant\*\*/);
  assert.match(renderAudit(result), /Phase 247: \*\*partial\*\*/);
  assert.match(renderAudit(result), /Phase 251: \*\*missing\*\*/);
});

test('Nyquist classification changes when a current validation record changes', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/248-exact-source-release-gate/248-VALIDATION.md': (source) =>
        source.replace('nyquist_compliant: true', 'nyquist_compliant: false'),
    },
  });
  assert.deepEqual(result.nyquist.compliantPhases, [246, 249, 250]);
  assert.deepEqual(result.nyquist.partialPhases, [247, 248]);
});

test('second audit run is deterministic apart from capture time', () => {
  const first = audit(repoRoot);
  const second = audit(repoRoot);
  assert.deepEqual({ ...first, capturedAt: null }, { ...second, capturedAt: null });
});

test('owner source identity changes remain unaccepted REL blockers', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md':
        (source) => source.replace('current_protected_main_sha":"4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97', 'current_protected_main_sha":"deadbeef'),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /identity/i.test(row.message)));
});

test('forged AUTO and REL requirement markers are checked against recomputed snapshots', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/248-exact-source-release-gate/248-VERIFICATION.md':
        (source) => source.replace('"AUTO-02":"satisfied"', '"AUTO-02":"unsatisfied"'),
      '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md':
        (source) => source.replace('"REL-02":"satisfied"', '"REL-02":"unsatisfied"'),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'AUTO-02' && /embedded requirement verdict/i.test(row.message)));
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /embedded requirement verdict/i.test(row.message)));
});

test('accepted historical handoff loss must remain explicitly unrecovered', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md':
        (source) => source.replace('were not recovered and were not preserved', 'were recovered and preserved'),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /accepted-loss|recovered|preserved/i.test(row.message)));
});

test('missing hosted failure/cancellation proof remains an AUTO-02 blocker', () => {
  const result = audit(repoRoot, {
    overrides: {
      [closeDir + '/250-CANARY-PROOF.json']: null,
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'AUTO-02' && /canary|artifact/i.test(row.message)));
});

test('changed canary receipt identity remains an AUTO-02 blocker', () => {
  const result = audit(repoRoot, {
    overrides: {
      [closeDir + '/250-CANARY-PROOF.json']:
        (source) => source.replace('"source_run_id": "38137550871"', '"source_run_id": "999"'),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'AUTO-02' && /proof|digest/i.test(row.message)));
});

test('older Plan 05 inventory is preserved as history and ignored as a live capture', () => {
  const result = audit(repoRoot, {
    overrides: {
      [closeDir + '/250-05-CURRENT-INVENTORY.json']: '{invalid historical fixture',
    },
  });
  assert.equal(result.status, 'accepted_exceptions');
  assert.equal(result.unacceptedBlockerCount, 0);
  assert.equal(result.owners['249'].liveInventory, undefined);
  assert.ok(result.sourceIdentities.some((item) => item.path === closeDir + '/250-249-SOURCE-SNAPSHOT.json'));
  assert.ok(!result.sourceIdentities.some((item) => item.path === closeDir + '/250-05-CURRENT-INVENTORY.json'));
});

test('changing the captured current-main snapshot remains an unaccepted REL blocker', () => {
  const result = audit(repoRoot, {
    overrides: {
      [closeDir + '/250-249-SOURCE-SNAPSHOT.json']:
        (source) => source.replace('4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97', 'deadbeef'),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'REL-02'));
});

test('missing acceptance record cannot turn READY gaps into accepted exceptions', () => {
  const result = audit(repoRoot, { overrides: { [acceptancePath]: null } });
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.acceptedExceptionCount, 0);
  assert.ok(result.blockers.some((row) => row.id === 'ACCEPTANCE'));
  assert.ok(result.blockers.some((row) => row.id === 'READY-01'));
  assert.ok(result.blockers.some((row) => row.id === 'READY-02'));
});

test('an expanded exception allowlist is rejected', () => {
  const result = audit(repoRoot, {
    overrides: {
      [acceptancePath]: (source) => source.replace(
        '"accepted_exception_ids": ["READY-01", "READY-02"]',
        '"accepted_exception_ids": ["READY-01", "READY-02", "AUTO-02"]',
      ),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.acceptedExceptionCount, 0);
  assert.ok(result.blockers.some((row) => row.id === 'ACCEPTANCE'));
  assert.deepEqual(result.acceptedExceptions, []);
});

test('an owner report change invalidates the bound acceptance record', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md':
        (source) => source + '\n',
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'ACCEPTANCE'));
  assert.ok(result.blockers.some((row) => row.id === 'READY-01'));
});

test('a Phase 250 summary cannot claim original owner requirements', () => {
  const result = audit(repoRoot, {
    overrides: {
      [closeDir + '/250-04-SUMMARY.md']:
        (source) => source.replace('requirements-completed: []', 'requirements-completed: [REL-02]'),
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some((row) => row.id === 'REL-02' && /phase 250|owner/i.test(row.message)));
});

test('a hand-edited passed or 9/9 audit cannot override computed accepted exceptions', () => {
  const sourceAudit = renderAudit(audit(repoRoot));
  const forgedAudit = sourceAudit
    .replace('status: gaps_found', 'status: passed')
    .replace('milestone_status: incomplete', 'milestone_status: passed')
    .replace('requirements: 7/9', 'requirements: 9/9');
  const checked = checkAudit(repoRoot, '.planning/v1.49-MILESTONE-AUDIT.md', {
    '.planning/v1.49-MILESTONE-AUDIT.md': forgedAudit,
  });
  assert.equal(checked.valid, false);
  assert.ok(checked.errors.some((message) => /status does not match/i.test(message)));
  assert.ok(checked.errors.some((message) => /accepted requirements remain unsatisfied/i.test(message)));
});

test('source audit report must bind accepted exception evidence and exact decision hash', () => {
  const sourceAudit = renderAudit(audit(repoRoot));
  const forgedAudit = sourceAudit.replace(/acceptance_amendment_sha256: [a-f0-9]{64}/, 'acceptance_amendment_sha256: ' + '0'.repeat(64));
  const checked = checkAudit(repoRoot, '.planning/v1.49-MILESTONE-AUDIT.md', {
    '.planning/v1.49-MILESTONE-AUDIT.md': forgedAudit,
  });
  assert.equal(checked.valid, false);
  assert.ok(checked.errors.some((message) => /exact acceptance amendment/i.test(message)));
});
