import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { audit, checkAudit, renderAudit } from './verify-v149-traceability.mjs';
import { phase251PackageCheckRequirements } from './verify-247-readiness.mjs';

const repoRoot = path.resolve('.');
const closeDir = '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat';
const acceptancePath = closeDir + '/250-ACCEPTANCE-AMENDMENT.json';
const phase251Dir = '.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps';
const phase251PacketPath = phase251Dir + '/251-247-RECONCILIATION.json';
const phase251FeasibilityPath = phase251Dir + '/251-EVIDENCE-FEASIBILITY.json';
const phase247ReportPath = '.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md';
const historicalCommit = '0e7a2835ebd0d7a1e791ad4dbc73955270108ed1';

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function ownerEvidenceFixture({ ready01 = false, ready02 = false } = {}) {
  const packet = JSON.parse(readFileSync(path.join(repoRoot, phase251PacketPath), 'utf8'));
  const report = readFileSync(path.join(repoRoot, phase247ReportPath), 'utf8');
  const feasibility = JSON.parse(readFileSync(path.join(repoRoot, phase251FeasibilityPath), 'utf8'));

  const ready01Verdict = ready01 ? 'satisfied' : packet.requirement_verdicts['READY-01'];
  const ready02Verdict = ready02 ? 'satisfied' : packet.requirement_verdicts['READY-02'];
  packet.requirement_verdicts = { 'READY-01': ready01Verdict, 'READY-02': ready02Verdict };

  const first = packet.requirements.READY01;
  if (ready01) {
    first.source_feasibility = 'ready';
    first.capture_allowed = true;
    first.verdict = 'satisfied';
    first.blockers = [];
    first.findings = [];
    first.package_adopter.acceptance_satisfied = true;
    for (const check of Object.values(first.package_adopter.checks)) {
      check.result = 'pass';
      check.finding_detail = 'No finding: complete fixture source evidence.';
    }
    for (const [index, source] of first.package_adopter.sources.entries()) {
      source.read_status = 'readable';
      source.trust_status = 'trusted_exact_api_blob_match';
      source.git_blob_oid = source.git_blob_oid ?? `${index}`.padStart(40, 'a');
      source.api_blob_oid = source.git_blob_oid;
      source.sha256 = source.sha256 ?? `${index}`.padStart(64, 'b');
      source.api_sha256 = source.sha256;
    }
    for (const [name, requiredSources] of Object.entries(phase251PackageCheckRequirements)) {
      const check = first.package_adopter.checks[name];
      check.source_refs = requiredSources.map((required) => structuredClone(first.package_adopter.sources.find((source) =>
        source.source_identity === required.identity && source.commit_sha === required.commit_sha && source.path === required.path)));
      check.source_assertions = requiredSources.flatMap((required) => required.assertions.map((id) => {
        const source = first.package_adopter.sources.find((item) => item.source_identity === required.identity
          && item.commit_sha === required.commit_sha && item.path === required.path);
        return { id, result: 'pass', expected: true, actual: true, source_identity: required.identity,
          commit_sha: required.commit_sha, path: required.path, git_blob_oid: source.git_blob_oid, sha256: source.sha256 };
      }));
    }
    const tuple = {
      candidate_sha: '0e773d3614a242e4fbcdd34c418ecb8a307703d6',
      reviewed_base_sha: 'd135cbce343947499a0810736c500ef5f1cb5c32',
      protected_main_sha: 'a494f3ee3878da93aab4f70712ffddeefd77a802',
      published_source_sha: '9e80cb78d6374b1ed4074d5fef6b613fee879dca',
      ci_head_sha: '0e773d3614a242e4fbcdd34c418ecb8a307703d6',
      readiness_sha256: 'a'.repeat(64),
      dry_run_sha256: 'b'.repeat(64),
    };
    first.exact_tuple = tuple;
    const approvalRecord = {
      decision: 'approved',
      source_identity: 'review-event:fixture-approval',
      approved_at: '2026-10-11T19:00:00Z',
      tuple_sha256: sha256(JSON.stringify(tuple)),
    };
    first.contemporaneous_approval = {
      status: 'approved',
      contemporaneous: true,
      record: approvalRecord,
      record_sha256: sha256(JSON.stringify(approvalRecord)),
      tuple_sha256: approvalRecord.tuple_sha256,
    };
    feasibility.requirements.READY01.source_feasibility = 'ready';
    feasibility.requirements.READY01.capture_allowed = true;
  }

  const second = packet.requirements.READY02;
  if (ready02) {
    second.source_feasibility = 'ready';
    second.capture_allowed = true;
    second.verdict = 'satisfied';
    second.blockers = [];
    second.findings = [];
    second.open_pr_population.stable = true;
    second.open_pr_population.complete = true;
    second.open_pr_population.disposition_join = {
      ...second.open_pr_population.disposition_join,
      status: 'passed',
      dispositionIds: [...second.open_pr_population.disposition_join.observedIds],
      blockers: [],
    };
    second.inherited_work.disposition_join = { status: 'passed', blockers: [] };
    packet.source_capture.local_inherited_work.inventory_complete = true;
    packet.blockers = packet.blockers.filter((blocker) => !/local_inherited|open_pr/.test(blocker));
    feasibility.requirements.READY02.source_feasibility = 'ready';
    feasibility.requirements.READY02.capture_allowed = true;
  }

  const feasibilityText = `${JSON.stringify(feasibility, null, 2)}\n`;
  packet.source_feasibility.sha256 = sha256(feasibilityText);
  const packetText = `${JSON.stringify(packet, null, 2)}\n`;
  const packetHash = sha256(packetText);
  const verdictRow = (id, verdict, evidence) => `| ${id} | ${verdict} | ${evidence} |`;
  const updatedReport = report
    .replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`)
    .replace(/^\| READY-01 \|[^\n]*$/m, verdictRow('READY-01', ready01Verdict, ready01 ? 'complete exact-source tuple and approval evidence' : 'authorization_pending: historical approval unavailable'))
    .replace(/^\| READY-02 \|[^\n]*$/m, verdictRow('READY-02', ready02Verdict, ready02 ? 'complete fresh inventory and preservation joins' : 'local_inherited_commit_base_unavailable; PR dispositions incomplete'));
  const traceability = readFileSync(path.join(repoRoot, '.planning/REQUIREMENTS.md'), 'utf8')
    .replace(/^- \[[ xX]\] \*\*READY-01\*\*:/m, `- [${ready01 ? 'x' : ' '}] **READY-01**:`)
    .replace(/^- \[[ xX]\] \*\*READY-02\*\*:/m, `- [${ready02 ? 'x' : ' '}] **READY-02**:`);

  return {
    packet,
    packetText,
    report: updatedReport,
    traceability,
    overrides: {
      [phase251PacketPath]: packetText,
      [phase251FeasibilityPath]: feasibilityText,
      [phase247ReportPath]: updatedReport,
      '.planning/REQUIREMENTS.md': traceability,
    },
  };
}

test('historical Phase 250 amendment resolves the original owner report from its immutable commit', () => {
  const result = audit(repoRoot);
  assert.equal(result.acceptanceAmendment?.historicalSource?.commit, historicalCommit);
  assert.equal(result.acceptanceAmendment?.historicalSource?.ownerReportSha256, 'd34f94f861b5fc4983138efadd26ae3b93336bb0b3b8e63afcf1c866fd709e39');
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.score.requirements, '7/9');
  assert.deepEqual(result.requirements.filter(({ id }) => id.startsWith('READY-')).map(({ status, acceptance_status }) => ({ status, acceptance_status })), [
    { status: 'unsatisfied', acceptance_status: 'unaccepted' },
    { status: 'unsatisfied', acceptance_status: 'unaccepted' },
  ]);
});

test('source-derived readiness fixtures score 7/9, 8/9, and 9/9 without stale milestone prose', () => {
  const cases = [
    { ready01: false, ready02: false, score: '7/9', passedReady: 0 },
    { ready01: true, ready02: false, score: '8/9', passedReady: 1 },
    { ready01: false, ready02: true, score: '8/9', passedReady: 1 },
    { ready01: true, ready02: true, score: '9/9', passedReady: 2 },
  ];
  for (const fixture of cases) {
    const evidence = ownerEvidenceFixture(fixture);
    const result = audit(repoRoot, { overrides: evidence.overrides });
    const rendered = renderAudit(result);
    assert.equal(result.score.requirements, fixture.score);
    assert.equal(result.requirements.filter(({ id }) => id.startsWith('READY-') && id && result.requirements.find((row) => row.id === id)?.status === 'satisfied').length, fixture.passedReady);
    assert.equal(result.milestoneStatus, fixture.score === '9/9' ? 'passed' : 'incomplete');
    assert.match(rendered, new RegExp(`requirements: ${fixture.score.replace('/', '\\/')}`));
    assert.match(rendered, new RegExp(`strict milestone status is \\*\\*${fixture.score === '9/9' ? 'passed' : 'gaps_found'}\\*\\* at \\*\\*${fixture.score.replace('/', '\\/')} requirements`));
    if (fixture.score !== '7/9') assert.doesNotMatch(rendered, /7\/9/);
  }
});

test('independent audit rejects a satisfied READY-01 row whose guide ref points to candidate bytes', () => {
  const evidence = ownerEvidenceFixture({ ready01: true });
  const check = evidence.packet.requirements.READY01.package_adopter.checks.published_tag_guide;
  check.source_refs[0] = structuredClone(evidence.packet.requirements.READY01.package_adopter.sources.find((source) =>
    source.source_identity === 'candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6'
      && source.path === 'guides/introduction/upgrading-to-v1.6.md'));
  evidence.packetText = `${JSON.stringify(evidence.packet, null, 2)}\n`;
  const packetHash = sha256(evidence.packetText);
  evidence.overrides[phase251PacketPath] = evidence.packetText;
  evidence.report = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
  evidence.overrides[phase247ReportPath] = evidence.report;

  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.status, 'unsatisfied');
  assert.ok(result.blockers.some(({ id, message }) => id === 'READY-01' && /source-bound|package check|guide/i.test(message)));
});

test('stale Phase 247 packet binding and wrong-phase ownership cannot satisfy READY', () => {
  const stale = ownerEvidenceFixture({ ready02: true });
  stale.overrides[phase247ReportPath] = stale.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${'0'.repeat(64)}`);
  const staleResult = audit(repoRoot, { overrides: stale.overrides });
  assert.equal(staleResult.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
  assert.ok(staleResult.blockers.some(({ id, message }) => id === 'READY-02' && /packet|reconciliation|digest/i.test(message)));

  const wrongOwner = ownerEvidenceFixture({ ready02: true });
  wrongOwner.packet.owner_phase = 251;
  wrongOwner.packetText = `${JSON.stringify(wrongOwner.packet, null, 2)}\n`;
  const wrongHash = sha256(wrongOwner.packetText);
  wrongOwner.overrides[phase251PacketPath] = wrongOwner.packetText;
  wrongOwner.overrides[phase247ReportPath] = wrongOwner.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${wrongHash}`);
  const wrongOwnerResult = audit(repoRoot, { overrides: wrongOwner.overrides });
  assert.equal(wrongOwnerResult.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
  assert.ok(wrongOwnerResult.blockers.some(({ id, message }) => id === 'READY-02' && /owner phase/i.test(message)));
});

test('corrupted historical Phase 250 source bytes block the amendment audit', () => {
  const historicalPath = `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md`;
  const result = audit(repoRoot, {
    overrides: {
      [`git:${historicalCommit}:${historicalPath}`]: '# altered historical owner report\n',
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.blockers.some(({ id, message }) => id === 'ACCEPTANCE' && /historical|amendment/i.test(message)));
});

test('a changed Phase 250 tuple packet is rejected even when current READY evidence is valid', () => {
  const evidence = ownerEvidenceFixture();
  const packetPath = closeDir + '/250-247-TUPLE-DECISION-PACKET.json';
  const result = audit(repoRoot, { overrides: { ...evidence.overrides, [packetPath]: '{"altered":true}\n' } });
  assert.ok(result.blockers.some(({ id, message }) => id === 'ACCEPTANCE' && /historical|amendment/i.test(message)));
  assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.acceptance_status, 'unaccepted');
});

test('strict matrix keeps READY unsatisfied while preserving two historical phase-only exceptions', () => {
  const result = audit(repoRoot);
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.milestoneStatus, 'incomplete');
  assert.equal(result.requirements.length, 9);
  assert.equal(result.score.requirements, '7/9');
  assert.equal(result.score.phases, '4/6');
  assert.equal(result.score.integration, '4/5');
  assert.equal(result.score.flows, '3/4');
  assert.equal(result.acceptedExceptionCount, 0);
  assert.equal(result.historicalExceptionCount, 2);
  assert.ok(result.unacceptedBlockerCount > 0);
  assert.deepEqual(result.historicalExceptions.map(({ id }) => id), ['READY-01', 'READY-02']);

  for (const id of ['READY-01', 'READY-02']) {
    const row = result.requirements.find((requirement) => requirement.id === id);
    assert.equal(row?.status, 'unsatisfied');
    assert.equal(row?.verification_status, 'unsatisfied');
    assert.equal(row?.owner_report_status, 'gaps_found');
    assert.equal(row?.acceptance_status, 'unaccepted');
    assert.equal(row?.traceability, 'open');
    assert.equal(row?.historical_phase_250_exception, true);
  }

  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-02')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-02')?.status, 'satisfied');
  assert.ok(result.sourceBlockers.some(({ id }) => id === 'READY-01'));
  assert.ok(result.sourceBlockers.some(({ id }) => id === 'READY-02'));
});

test('generated audit separates historical exceptions from current readiness and never claims milestone completion', () => {
  const report = renderAudit(audit(repoRoot));
  assert.match(report, /^status: gaps_found$/m);
  assert.match(report, /^source_audit_status: gaps_found$/m);
  assert.match(report, /^milestone_status: incomplete$/m);
  assert.match(report, /^  requirements: 7\/9$/m);
  assert.match(report, /^accepted_exception_count: 0$/m);
  assert.match(report, /^historical_phase_250_exception_count: 2$/m);
  assert.match(report, /^historical_phase_250_exception_ids: \[READY-01, READY-02\]$/m);
  assert.match(report, /acceptance_status: "unaccepted"/);
  assert.match(report, /strict milestone status is \*\*gaps_found\*\*/);
  assert.match(report, /do not satisfy current READY requirements/);
  assert.doesNotMatch(report, /^status: passed$/m);
  assert.doesNotMatch(report, /9\/9/);
});

test('audit checker rejects a READY matrix row that contradicts the current owner verdict', () => {
  const sourceAudit = renderAudit(audit(repoRoot));
  const forgedAudit = sourceAudit.replace(
    '| READY-02 | 247 | open | unsatisfied | unaccepted | **unsatisfied** |',
    '| READY-02 | 247 | open | satisfied | verified | **satisfied** |',
  );
  const checked = checkAudit(repoRoot, '.planning/v1.49-MILESTONE-AUDIT.md', {
    '.planning/v1.49-MILESTONE-AUDIT.md': forgedAudit,
  });
  assert.equal(checked.valid, false);
  assert.ok(checked.errors.some((message) => /requirement row READY-02 differs/i.test(message)));
});

test('audit discovers current Nyquist classifications from every v1.49 phase record', () => {
  const result = audit(repoRoot);
  assert.deepEqual(result.nyquist.compliantPhases, [246, 248, 249, 250]);
  assert.deepEqual(result.nyquist.partialPhases, [247]);
  assert.deepEqual(result.nyquist.notValidatedPhases, [251]);
  assert.deepEqual(result.nyquist.missingPhases, []);
  assert.equal(result.nyquist.overall, 'partial');
  assert.match(renderAudit(result), /Phase 248: \*\*compliant\*\*/);
  assert.match(renderAudit(result), /Phase 247: \*\*partial\*\*/);
  assert.match(renderAudit(result), /Phase 251: \*\*not validated\*\*/);
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
  assert.equal(result.status, 'gaps_found');
  assert.ok(result.unacceptedBlockerCount > 0);
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
      [acceptancePath]: (source) => {
        const amendment = JSON.parse(source);
        amendment.revised_phase_acceptance.accepted_exception_ids.push('AUTO-02');
        return `${JSON.stringify(amendment, null, 2)}\n`;
      },
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.acceptedExceptionCount, 0);
  assert.ok(result.blockers.some((row) => row.id === 'ACCEPTANCE'));
  assert.deepEqual(result.historicalExceptions, []);
});

test('a current owner report change does not rewrite authentic Phase 250 historical acceptance', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md':
        (source) => source + '\n',
    },
  });
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.acceptanceAmendment?.historicalSource?.commit, historicalCommit);
  assert.ok(!result.blockers.some((row) => row.id === 'ACCEPTANCE'));
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

test('a hand-edited passed or 9/9 audit cannot override computed current owner evidence', () => {
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
  assert.ok(checked.errors.some((message) => /source-derived|requirement row|prose/i.test(message)));
});

test('source audit report must bind historical exception evidence and exact decision hash', () => {
  const sourceAudit = renderAudit(audit(repoRoot));
  const forgedAudit = sourceAudit.replace(/acceptance_amendment_sha256: [a-f0-9]{64}/, 'acceptance_amendment_sha256: ' + '0'.repeat(64));
  const checked = checkAudit(repoRoot, '.planning/v1.49-MILESTONE-AUDIT.md', {
    '.planning/v1.49-MILESTONE-AUDIT.md': forgedAudit,
  });
  assert.equal(checked.valid, false);
  assert.ok(checked.errors.some((message) => /source-derived|historical exception/i.test(message)));
});
