import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { audit, checkAudit, phase251AuditAssertion, renderAudit } from './verify-v149-traceability.mjs';
import { evaluatePhase251PackageAssertion, phase251PackageCheckRequirements } from './verify-247-readiness.mjs';

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
  const ready02Verdict = ready02 ? 'satisfied' : 'unsatisfied';
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
    for (const [name, requiredSources] of Object.entries(phase251PackageCheckRequirements)) {
      const check = first.package_adopter.checks[name];
      check.source_refs = requiredSources.map((required) => structuredClone(first.package_adopter.sources.find((source) =>
        source.source_identity === required.identity && source.commit_sha === required.commit_sha && source.path === required.path)));
      check.source_assertions = requiredSources.flatMap((required) => required.assertions.map((id) => {
        const source = first.package_adopter.sources.find((item) => item.source_identity === required.identity
          && item.commit_sha === required.commit_sha && item.path === required.path);
        let bytes = null;
        try { bytes = execFileSync('git', ['show', `${source.commit_sha}:${source.path}`], { stdio: ['ignore', 'pipe', 'ignore'] }); } catch { /* exact 404 remains missing */ }
        const actual = bytes ? evaluatePhase251PackageAssertion(id, bytes, source) : false;
        return { id, result: !bytes ? 'missing' : actual ? 'pass' : 'mismatch', expected: true, actual, source_identity: required.identity,
          commit_sha: required.commit_sha, path: required.path, git_blob_oid: source.git_blob_oid, sha256: source.sha256 };
      }));
      check.result = check.source_assertions.every((item) => item.result === 'pass') ? 'pass'
        : check.source_assertions.some((item) => item.result === 'missing') ? 'missing' : 'mismatch';
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
    // Keep the complete current proof intact; audit() rechecks every source row and preserved blob.
    assert.equal(second.verdict, 'satisfied');
  } else {
    second.verdict = 'unsatisfied';
    second.blockers = ['Fixture records READY-02 as unproven.'];
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
    .replace(/^- \[[ xX]\] \*\*READY-02\*\*:/m, `- [${ready02 ? 'x' : ' '}] **READY-02**:`)
    .replace(/^\| READY-01 \|.*$/m, `| READY-01 | Phase 247 | ${ready01 ? 'Complete; Phase 247 owner verdict satisfied' : 'Unsatisfied; current Phase 251 owner evidence'} | ${phase247ReportPath} | ${phase251PacketPath} | ${packetHash} |`)
    .replace(/^\| READY-02 \|.*$/m, `| READY-02 | Phase 247 | ${ready02 ? 'Complete; Phase 247 owner verdict satisfied' : 'Unsatisfied; current Phase 251 owner evidence'} | ${phase247ReportPath} | ${phase251PacketPath} | ${packetHash} |`);

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

let forgedRefSequence = 0;
function commitPreservationVariant(oldRef, mutateRecord, label) {
  const record = JSON.parse(execFileSync('git', ['show', `${oldRef.commit_sha}:${oldRef.record_path}`], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }));
  mutateRecord(record);
  const recordBytes = Buffer.from(`${JSON.stringify(record, null, 2)}\n`);
  const blob = execFileSync('git', ['hash-object', '-w', '--stdin'], { input: recordBytes, encoding: 'utf8' }).trim();
  const recordsTree = execFileSync('git', ['mktree'], { input: `100644 blob ${blob}\t${oldRef.record_path.slice('records/'.length)}\n`, encoding: 'utf8' }).trim();
  const tree = execFileSync('git', ['mktree'], { input: `040000 tree ${recordsTree}\trecords\n`, encoding: 'utf8' }).trim();
  const commitSha = execFileSync('git', ['commit-tree', tree, '-p', oldRef.commit_sha, '-m', `test ${label} preservation record`], { encoding: 'utf8' }).trim();
  const ref = `refs/heads/test-phase251-${label}-${process.pid}-${++forgedRefSequence}`;
  execFileSync('git', ['update-ref', ref, commitSha]);
  return { ref, commitSha, recordSha256: sha256(recordBytes), cleanup: () => execFileSync('git', ['update-ref', '-d', ref]) };
}

function rebindPacketAndReport(evidence, previousPacketHash = sha256(evidence.packetText)) {
  evidence.packetText = `${JSON.stringify(evidence.packet, null, 2)}\n`;
  const packetHash = sha256(evidence.packetText);
  evidence.overrides[phase251PacketPath] = evidence.packetText;
  evidence.report = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
  evidence.overrides[phase247ReportPath] = evidence.report;
  evidence.overrides['.planning/REQUIREMENTS.md'] = evidence.overrides['.planning/REQUIREMENTS.md'].replaceAll(previousPacketHash, packetHash)
    .split('\n').map((line) => /^\|\s*READY-0[12]\s*\|/.test(line) ? line.replace(/[a-f0-9]{64}(?=\s*\|$)/, packetHash) : line).join('\n');
}

function rekeyCapturedDirtyIdentity(packet, dirty, { status = dirty.status, sourceByteSha256 = dirty.source_byte_sha256 } = {}) {
  const oldId = dirty.id;
  const oldDigest = dirty.source_byte_sha256;
  const newId = `dirty:${dirty.worktree_path}:${dirty.worktree_head_sha}:${status}:${dirty.path}:${sourceByteSha256}`;
  const local = packet.source_capture.local_inherited_work;
  const inherited = packet.requirements.READY02.inherited_work;
  const dirtyRow = local.inherited_dirty_entries.find((row) => row.id === oldId);
  dirtyRow.id = newId;
  dirtyRow.status = status;
  dirtyRow.source_byte_sha256 = sourceByteSha256;
  local.inherited_dispositions.find((row) => row.id === oldId).id = newId;
  for (const inventory of [local, inherited]) {
    for (const worktree of inventory.worktrees ?? []) {
      if (worktree.path !== dirty.worktree_path || worktree.head_sha !== dirty.worktree_head_sha) continue;
      const entry = worktree.status_entries.find((row) => row.path === dirty.path && row.source_byte_sha256 === oldDigest);
      assert.ok(entry, `captured status row missing for ${oldId}`);
      entry.status = status;
      entry.source_byte_sha256 = sourceByteSha256;
    }
  }
  if (local.repository_root === dirty.worktree_path) {
    const rawEntry = local.raw_status?.find((row) => row.path === dirty.path && row.source_byte_sha256 === oldDigest);
    assert.ok(rawEntry, `raw status row missing for ${oldId}`);
    rawEntry.status = status;
    rawEntry.source_byte_sha256 = sourceByteSha256;
    for (const inventory of [local, inherited]) {
      const rootWorktree = inventory.worktrees?.find((row) => row.path === local.repository_root);
      if (!rootWorktree) continue;
      rootWorktree.status_bytes = rootWorktree.status_entries.map((row) => `${row.status} ${row.path}\0`).join('');
      rootWorktree.status_sha256 = sha256(rootWorktree.status_bytes);
    }
    local.raw_status_sha256 = local.worktrees.find((row) => row.path === local.repository_root).status_sha256;
  }
  const join = inherited.disposition_join;
  join.observedIds = join.observedIds.map((id) => id === oldId ? newId : id);
  join.dispositionIds = join.dispositionIds.map((id) => id === oldId ? newId : id);
  join.preservationRefs.find((row) => row.id === oldId).id = newId;
  return newId;
}

test('historical Phase 250 amendment resolves the original owner report from its immutable commit', () => {
  const result = audit(repoRoot);
  assert.equal(result.acceptanceAmendment?.historicalSource?.commit, historicalCommit);
  assert.equal(result.acceptanceAmendment?.historicalSource?.ownerReportSha256, 'd34f94f861b5fc4983138efadd26ae3b93336bb0b3b8e63afcf1c866fd709e39');
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.score.requirements, '8/9');
  assert.deepEqual(result.requirements.filter(({ id }) => id.startsWith('READY-')).map(({ status, acceptance_status }) => ({ status, acceptance_status })), [
    { status: 'unsatisfied', acceptance_status: 'unaccepted' },
    { status: 'satisfied', acceptance_status: 'verified' },
  ]);
});

test('ownerDerivedSevenEightNine requires complete Phase 247 evidence for every counted READY item', () => {
  const cases = [
    { ready01: false, ready02: false, score: '7/9', passedReady: 0 },
    { ready01: true, ready02: false, score: '7/9', passedReady: 0 },
    { ready01: false, ready02: true, score: '8/9', passedReady: 1 },
    { ready01: true, ready02: true, score: '8/9', passedReady: 1 },
  ];
  for (const fixture of cases) {
    const evidence = ownerEvidenceFixture(fixture);
    const result = audit(repoRoot, { overrides: evidence.overrides });
    const rendered = renderAudit(result);
    assert.equal(result.score.requirements, fixture.score);
    assert.equal(result.requirements.filter(({ id }) => id.startsWith('READY-') && id && result.requirements.find((row) => row.id === id)?.status === 'satisfied').length, fixture.passedReady);
    assert.equal(result.milestoneStatus, fixture.score === '9/9' ? 'passed' : 'incomplete', JSON.stringify(result.blockers));
    assert.match(rendered, new RegExp(`requirements: ${fixture.score.replace('/', '\\/')}`));
    assert.match(rendered, new RegExp(`strict milestone status is \\*\\*${fixture.score === '9/9' ? 'passed' : 'gaps_found'}\\*\\* at \\*\\*${fixture.score.replace('/', '\\/')} requirements`));
    if (fixture.score !== '7/9') assert.doesNotMatch(rendered, /7\/9/);
  }
});

test('phase250ExceptionNotReadyPass cannot increase current READY counts', () => {
  const evidence = ownerEvidenceFixture({ ready01: false, ready02: true });
  const tracePath = '.planning/REQUIREMENTS.md';
  evidence.overrides[tracePath] = evidence.overrides[tracePath]
    .replace(/^- \[ \] \*\*READY-01\*\*:/m, '- [x] **READY-01**:');
  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.score.requirements, '8/9');
  assert.ok(result.historicalExceptions.every(({ scope }) => scope === 'Phase 250 closeout only'));
  assert.deepEqual(result.requirements.filter(({ id }) => id.startsWith('READY-')).map(({ status }) => status), ['unsatisfied', 'satisfied']);
});

test('ownerReportReferenceRequired rejects READY evidence rows that omit the canonical owner report', () => {
  const evidence = ownerEvidenceFixture({ ready02: true });
  const requirementPath = '.planning/REQUIREMENTS.md';
  const traceability = evidence.overrides[requirementPath];
  const table = traceability.replace(
    '| Requirement | Phase | Status |',
    '| Requirement | Phase | Status | Owner Report | Current Packet | Packet SHA-256 |',
  ).replace(
    '| READY-02 | Phase 247 | Unsatisfied; current Phase 251 packet |',
    `| READY-02 | Phase 247 | Unsatisfied; current Phase 251 packet | ${phase247ReportPath} | ${phase251PacketPath} | ${sha256(evidence.packetText)} |`,
  );
  evidence.overrides[requirementPath] = table.replace(
    /^\| READY-02 \|[^\n]*$/m,
    (row) => row.replace(phase247ReportPath, '.planning/phases/250/250-VERIFICATION.md'),
  );

  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied', JSON.stringify(result.blockers.filter(({ id }) => id === 'READY-02')));
  assert.ok(result.blockers.some(({ id, message }) => id === 'READY-02' && /owner report reference/i.test(message)));
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

test('independent audit rejects claimed READY-01 pass when exact source predicates fail', () => {
  const evidence = ownerEvidenceFixture({ ready01: true });
  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.status, 'unsatisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
});

test('independent audit reads exact source bytes before accepting forged README predicates', () => {
  const evidence = ownerEvidenceFixture({ ready01: true });
  const priorPacketHash = sha256(evidence.packetText);
  const ready = evidence.packet.requirements.READY01;
  for (const [index, source] of ready.package_adopter.sources.entries()) {
    source.read_status = 'readable';
    source.trust_status = 'trusted_exact_api_blob_match';
    source.git_blob_oid = `${index}`.padStart(40, 'a');
    source.api_blob_oid = source.git_blob_oid;
    source.sha256 = `${index}`.padStart(64, 'b');
    source.api_sha256 = source.sha256;
  }
  for (const check of Object.values(evidence.packet.requirements.READY01.package_adopter.checks)) {
    check.result = 'pass';
    check.finding_detail = 'No finding: forged booleans only.';
    check.source_refs = check.source_refs.map((ref) => structuredClone(ready.package_adopter.sources.find((source) =>
      source.source_identity === ref.source_identity && source.commit_sha === ref.commit_sha && source.path === ref.path)));
    check.source_assertions = check.source_assertions.map((item) => ({ ...item, result: 'pass', expected: true, actual: true }));
    for (const assertion of check.source_assertions) {
      const source = ready.package_adopter.sources.find((row) => row.source_identity === assertion.source_identity
        && row.commit_sha === assertion.commit_sha && row.path === assertion.path);
      assertion.git_blob_oid = source.git_blob_oid;
      assertion.sha256 = source.sha256;
    }
  }
  evidence.packetText = `${JSON.stringify(evidence.packet, null, 2)}\n`;
  const packetHash = sha256(evidence.packetText);
  evidence.overrides[phase251PacketPath] = evidence.packetText;
  evidence.report = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
  evidence.overrides[phase247ReportPath] = evidence.report;
  evidence.overrides['.planning/REQUIREMENTS.md'] = evidence.overrides['.planning/REQUIREMENTS.md'].replaceAll(priorPacketHash, packetHash).split('\n').map((line) =>
    /^\|\s*READY-0[12]\s*\|/.test(line) ? line.replace(/[a-f0-9]{64}(?=\s*\|$)/, packetHash) : line).join('\n');

  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.status, 'unsatisfied');
});

test('independent audit rejects a coherently omitted captured worktree status identity', () => {
  const evidence = ownerEvidenceFixture({ ready02: true });
  assert.equal(audit(repoRoot, { overrides: evidence.overrides }).requirements.find(({ id }) => id === 'READY-02')?.status, 'satisfied');
  const packet = evidence.packet;
  const local = packet.source_capture.local_inherited_work;
  const dirty = local.inherited_dirty_entries[0];
  const join = packet.requirements.READY02.inherited_work.disposition_join;
  for (const rows of [join.observedIds, join.dispositionIds, join.preservationRefs]) {
    const index = rows.findIndex((row) => (typeof row === 'string' ? row : row.id) === dirty.id);
    assert.notEqual(index, -1);
    rows.splice(index, 1);
  }
  const priorPacketHash = sha256(evidence.packetText);
  evidence.packetText = `${JSON.stringify(packet, null, 2)}\n`;
  evidence.overrides[phase251PacketPath] = evidence.packetText;
  const packetHash = sha256(evidence.packetText);
  evidence.report = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
  evidence.overrides['.planning/REQUIREMENTS.md'] = evidence.overrides['.planning/REQUIREMENTS.md'].replaceAll(priorPacketHash, packetHash);
  evidence.overrides[phase247ReportPath] = evidence.report;

  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied', JSON.stringify(result.blockers.filter(({ id }) => id === 'READY-02')));

  for (const mutate of [
    (packet) => { packet.requirements.READY02.inherited_work.disposition_join.preservationRefs[0].commitSha = 'f'.repeat(40); },
    (packet) => { packet.source_capture.local_inherited_work.inherited_dispositions[0].decision = 'release-relevant'; },
    (packet) => { packet.source_capture.local_inherited_work.inherited_dispositions[0].reason = 'altered preserved decision reason'; },
    (packet) => { packet.source_capture.local_inherited_work.inherited_dispositions[0].source.commit_sha = 'f'.repeat(40); },
  ]) {
    const changed = ownerEvidenceFixture({ ready02: true });
    const priorHash = sha256(changed.packetText);
    mutate(changed.packet);
    changed.packetText = `${JSON.stringify(changed.packet, null, 2)}\n`;
    const changedHash = sha256(changed.packetText);
    changed.overrides[phase251PacketPath] = changed.packetText;
    changed.report = changed.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${changedHash}`);
    changed.overrides[phase247ReportPath] = changed.report;
    changed.overrides['.planning/REQUIREMENTS.md'] = changed.overrides['.planning/REQUIREMENTS.md'].replaceAll(priorHash, changedHash)
      .split('\n').map((line) => /^\|\s*READY-0[12]\s*\|/.test(line) ? line.replace(/[a-f0-9]{64}(?=\s*\|$)/, changedHash) : line).join('\n');
    const changedResult = audit(repoRoot, { overrides: changed.overrides });
    assert.equal(changedResult.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
  }
});

test('independent audit binds every dirty-row metadata field to its canonical status row', () => {
  const positive = ownerEvidenceFixture({ ready02: true });
  assert.equal(audit(repoRoot, { overrides: positive.overrides }).requirements.find(({ id }) => id === 'READY-02')?.status, 'satisfied');
  const mutations = [
    ['path', (dirty) => { dirty.path = 'forged/path-that-never-appeared-in-status.txt'; }],
    ['original_path', (dirty) => { dirty.original_path = 'forged/original.txt'; }],
    ['status', (dirty) => { dirty.status = 'MM'; }],
    ['worktree_path', (dirty) => { dirty.worktree_path = '/tmp/forged-worktree'; }],
    ['worktree_head_sha', (dirty) => { dirty.worktree_head_sha = 'f'.repeat(40); }],
    ['worktree_branch', (dirty) => { dirty.worktree_branch = 'refs/heads/forged-branch'; }],
    ['source_byte_sha256', (dirty) => { dirty.source_byte_sha256 = sha256('forged source bytes'); }],
    ['source_byte_readable', (dirty) => { dirty.source_byte_readable = false; }],
    ['kind', (dirty) => { dirty.kind = 'committed_path'; }],
  ];
  for (const [index, [field, mutate]] of mutations.entries()) {
    const evidence = ownerEvidenceFixture({ ready02: true });
    const packet = evidence.packet;
    const dirty = packet.source_capture.local_inherited_work.inherited_dirty_entries[0];
    const disposition = packet.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.id === dirty.id);
    const joinRef = packet.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === dirty.id);
    const oldRef = structuredClone(disposition.preservation_ref);
    mutate(dirty);
    const source = { ...disposition.source };
    if (field === 'path') source.path = dirty.path;
    if (field === 'original_path') source.original_path = dirty.original_path;
    if (field === 'status') source.status = dirty.status;
    if (field === 'worktree_path') source.worktree_path = dirty.worktree_path;
    if (field === 'worktree_head_sha') source.head_sha = dirty.worktree_head_sha;
    if (field === 'worktree_branch') source.worktree_branch = dirty.worktree_branch;
    if (field === 'source_byte_sha256') source.source_byte_sha256 = dirty.source_byte_sha256;
    if (field === 'kind') source.kind = dirty.kind;
    disposition.source = source;
    const variant = commitPreservationVariant(oldRef, (record) => {
      record.source = source;
      record.captured_source.path = source.path;
      record.captured_source.original_path = source.original_path;
      record.captured_source.status = source.status;
      record.captured_source.worktree_path = source.worktree_path;
      record.captured_source.worktree_head_sha = source.head_sha;
      record.captured_source.worktree_branch = source.worktree_branch;
      record.captured_source.source_byte_sha256 = dirty.source_byte_sha256;
      record.captured_source.kind = dirty.kind;
      if (field === 'source_byte_sha256') {
        record.source_byte_sha256 = dirty.source_byte_sha256;
        record.source_bytes_base64 = Buffer.from('forged source bytes').toString('base64');
      }
      if (field === 'kind') record.kind = dirty.kind;
    }, `dirty-row-field-${index}`);
    disposition.preservation_ref = { ...oldRef, ref: variant.ref, commit_sha: variant.commitSha, record_sha256: variant.recordSha256 };
    Object.assign(joinRef, { ref: variant.ref, commitSha: variant.commitSha, recordSha256: variant.recordSha256 });
    rebindPacketAndReport(evidence);
    try {
      const result = audit(repoRoot, { overrides: evidence.overrides });
      assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied', `dirty ${field} relabel`);
    } finally { variant.cleanup(); }
  }

  const evidence = ownerEvidenceFixture({ ready02: true });
  const rootInventory = evidence.packet.source_capture.local_inherited_work;
  rootInventory.worktrees.find((row) => row.path === rootInventory.repository_root).status_entries[0].original_path = 'forged/original.txt';
  rebindPacketAndReport(evidence);
  assert.equal(audit(repoRoot, { overrides: evidence.overrides }).requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied',
    'source and READY-02 status-row metadata must match exactly');
});

test('independent audit rejects nonexistent preservation refs and altered decision provenance', () => {
  const evidence = ownerEvidenceFixture({ ready02: true });
  const packet = evidence.packet;
  const row = packet.source_capture.local_inherited_work.inherited_dispositions[0];
  const reference = packet.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((item) => item.id === row.id);
  reference.ref = 'refs/heads/definitely-nonexistent-phase251';
  const priorPacketHash = sha256(evidence.packetText);
  evidence.packetText = `${JSON.stringify(packet, null, 2)}\n`;
  evidence.overrides[phase251PacketPath] = evidence.packetText;
  const packetHash = sha256(evidence.packetText);
  evidence.report = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
  evidence.overrides['.planning/REQUIREMENTS.md'] = evidence.overrides['.planning/REQUIREMENTS.md'].replaceAll(priorPacketHash, packetHash);
  evidence.overrides[phase247ReportPath] = evidence.report;

  const result = audit(repoRoot, { overrides: evidence.overrides });
  assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied', JSON.stringify(result.blockers.filter(({ id }) => id === 'READY-02')));
});

test('independent audit rejects coherently committed preservation bytes that do not match the captured digest', () => {
  const evidence = ownerEvidenceFixture({ ready02: true });
  const packet = evidence.packet;
  const disposition = packet.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.source?.worktree_path);
  const joinRef = packet.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === disposition.id);
  const oldRef = disposition.preservation_ref;
  const forgedRecord = JSON.parse(execFileSync('git', ['show', `${oldRef.commit_sha}:${oldRef.record_path}`], { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 }));
  const decoded = Buffer.from(forgedRecord.source_bytes_base64, 'base64');
  assert.equal(sha256(decoded), forgedRecord.source_byte_sha256);
  decoded[0] = decoded[0] ^ 1;
  forgedRecord.source_bytes_base64 = decoded.toString('base64');
  const recordBytes = Buffer.from(`${JSON.stringify(forgedRecord, null, 2)}\n`);
  const blob = execFileSync('git', ['hash-object', '-w', '--stdin'], { input: recordBytes, encoding: 'utf8' }).trim();
  const recordsTree = execFileSync('git', ['mktree'], { input: `100644 blob ${blob}\t${oldRef.record_path.slice('records/'.length)}\n`, encoding: 'utf8' }).trim();
  const tree = execFileSync('git', ['mktree'], { input: `040000 tree ${recordsTree}\trecords\n`, encoding: 'utf8' }).trim();
  const commitSha = execFileSync('git', ['commit-tree', tree, '-p', oldRef.commit_sha, '-m', 'test forged preservation source bytes'], { encoding: 'utf8' }).trim();
  const ref = `refs/heads/test-phase251-forged-preservation-${process.pid}`;
  execFileSync('git', ['update-ref', ref, commitSha]);
  try {
    const recordSha256 = sha256(recordBytes);
    disposition.preservation_ref = { ...oldRef, ref, commit_sha: commitSha, record_sha256: recordSha256 };
    Object.assign(joinRef, { ref, commitSha, recordSha256 });
    const priorPacketHash = sha256(evidence.packetText);
    evidence.packetText = `${JSON.stringify(packet, null, 2)}\n`;
    const packetHash = sha256(evidence.packetText);
    evidence.overrides[phase251PacketPath] = evidence.packetText;
    evidence.report = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
    evidence.overrides[phase247ReportPath] = evidence.report;
    evidence.overrides['.planning/REQUIREMENTS.md'] = evidence.overrides['.planning/REQUIREMENTS.md'].replaceAll(priorPacketHash, packetHash)
      .split('\n').map((line) => /^\|\s*READY-0[12]\s*\|/.test(line) ? line.replace(/[a-f0-9]{64}(?=\s*\|$)/, packetHash) : line).join('\n');
    const result = audit(repoRoot, { overrides: evidence.overrides });
    assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
  } finally {
    execFileSync('git', ['update-ref', '-d', ref]);
  }
});

test('independent audit selects dirty-path proof from the captured dirty identity, not relabeled source metadata', () => {
  const evidence = ownerEvidenceFixture({ ready02: true });
  const dirty = evidence.packet.source_capture.local_inherited_work.inherited_dirty_entries[0];
  const disposition = evidence.packet.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.id === dirty.id);
  const joinRef = evidence.packet.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === dirty.id);
  const oldRef = structuredClone(disposition.preservation_ref);
  assert.equal(audit(repoRoot, { overrides: evidence.overrides }).requirements.find(({ id }) => id === 'READY-02')?.status, 'satisfied');
  const fakeSource = { kind: 'committed_path', commit_sha: disposition.source.head_sha, path: disposition.source.path };
  disposition.source = fakeSource;
  const variant = commitPreservationVariant(oldRef, (record) => {
    record.kind = 'committed_path';
    record.source = fakeSource;
    delete record.source_bytes_base64;
    delete record.source_absence_proof;
    record.captured_source = { id: dirty.id, kind: 'committed_path', source_commit_sha: fakeSource.commit_sha, path: fakeSource.path };
  }, 'dirty-kind-relabel');
  disposition.preservation_ref = { ...oldRef, ref: variant.ref, commit_sha: variant.commitSha, record_sha256: variant.recordSha256 };
  Object.assign(joinRef, { ref: variant.ref, commitSha: variant.commitSha, recordSha256: variant.recordSha256 });
  rebindPacketAndReport(evidence);
  try {
    const result = audit(repoRoot, { overrides: evidence.overrides });
    assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
  } finally { variant.cleanup(); }
});

test('independent audit uses the captured deletion status for tombstone validation', () => {
  const evidence = ownerEvidenceFixture({ ready02: true });
  const packet = evidence.packet;
  const dirty = packet.source_capture.local_inherited_work.inherited_dirty_entries[0];
  const disposition = packet.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.id === dirty.id);
  const joinRef = packet.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === dirty.id);
  const oldRef = structuredClone(disposition.preservation_ref);
  const oldId = dirty.id;
  const deletedId = rekeyCapturedDirtyIdentity(packet, dirty, { status: ' D' });
  disposition.id = deletedId;
  disposition.preservation_ref = { ...oldRef };
  joinRef.id = deletedId;
  const variant = commitPreservationVariant(oldRef, (record) => {
    record.id = deletedId;
    record.captured_source.id = deletedId;
    // Keep the source/record mislabeled as a modification and remove its tombstone.
    delete record.source_absence_proof;
  }, 'deletion-status-relabel');
  disposition.preservation_ref = { ...oldRef, ref: variant.ref, commit_sha: variant.commitSha, record_sha256: variant.recordSha256 };
  Object.assign(joinRef, { ref: variant.ref, commitSha: variant.commitSha, recordSha256: variant.recordSha256 });
  assert.notEqual(deletedId, oldId);
  rebindPacketAndReport(evidence);
  try {
    const result = audit(repoRoot, { overrides: evidence.overrides });
    assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied');
  } finally { variant.cleanup(); }
});

test('dirty source identity controls reject worktree, head, path, original path, and branch relabels', () => {
  const mutations = [
    (source) => { source.worktree_path = '/tmp/wrong-worktree'; },
    (source) => { source.head_sha = 'f'.repeat(40); },
    (source) => { source.path = 'other/path.md'; },
    (source) => { source.original_path = 'renamed/path.md'; },
    (source) => { source.worktree_branch = 'refs/heads/wrong-branch'; },
  ];
  for (const [index, mutate] of mutations.entries()) {
    const evidence = ownerEvidenceFixture({ ready02: true });
    const packet = evidence.packet;
    const dirty = packet.source_capture.local_inherited_work.inherited_dirty_entries[0];
    const disposition = packet.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.id === dirty.id);
    const joinRef = packet.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === dirty.id);
    const oldRef = structuredClone(disposition.preservation_ref);
    const alteredSource = { ...disposition.source };
    mutate(alteredSource);
    disposition.source = alteredSource;
    const variant = commitPreservationVariant(oldRef, (record) => {
      record.source = alteredSource;
      if (alteredSource.worktree_path) record.captured_source.worktree_path = alteredSource.worktree_path;
      if (alteredSource.head_sha) record.captured_source.worktree_head_sha = alteredSource.head_sha;
      if (alteredSource.path) record.captured_source.path = alteredSource.path;
      if (Object.hasOwn(alteredSource, 'original_path')) record.captured_source.original_path = alteredSource.original_path;
      if (alteredSource.worktree_branch) record.captured_source.worktree_branch = alteredSource.worktree_branch;
    }, `dirty-identity-${index}`);
    disposition.preservation_ref = { ...oldRef, ref: variant.ref, commit_sha: variant.commitSha, record_sha256: variant.recordSha256 };
    Object.assign(joinRef, { ref: variant.ref, commitSha: variant.commitSha, recordSha256: variant.recordSha256 });
    rebindPacketAndReport(evidence);
    try {
      const result = audit(repoRoot, { overrides: evidence.overrides });
      assert.equal(result.requirements.find(({ id }) => id === 'READY-02')?.status, 'unsatisfied', `relabel ${index}`);
    } finally { variant.cleanup(); }
  }
});

test('valid captured dirty modification, empty-byte payload, and tombstoned deletion remain provable', () => {
  const modified = ownerEvidenceFixture({ ready02: true });
  assert.equal(audit(repoRoot, { overrides: modified.overrides }).requirements.find(({ id }) => id === 'READY-02')?.status, 'satisfied');

  const empty = ownerEvidenceFixture({ ready02: true });
  const emptyPacket = empty.packet;
  const emptyDirty = emptyPacket.source_capture.local_inherited_work.inherited_dirty_entries[0];
  const emptyDisposition = emptyPacket.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.id === emptyDirty.id);
  const emptyJoinRef = emptyPacket.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === emptyDirty.id);
  const emptyOldRef = structuredClone(emptyDisposition.preservation_ref);
  const emptyDigest = sha256(Buffer.alloc(0));
  const emptyId = rekeyCapturedDirtyIdentity(emptyPacket, emptyDirty, { sourceByteSha256: emptyDigest });
  emptyDisposition.id = emptyId;
  emptyJoinRef.id = emptyId;
  const emptyVariant = commitPreservationVariant(emptyOldRef, (record) => {
    record.id = emptyId;
    record.source_byte_sha256 = emptyDigest;
    record.source_bytes_base64 = '';
    record.captured_source.id = emptyId;
    record.captured_source.source_byte_sha256 = emptyDigest;
  }, 'empty-dirty-bytes');
  emptyDisposition.preservation_ref = { ...emptyOldRef, ref: emptyVariant.ref, commit_sha: emptyVariant.commitSha, record_sha256: emptyVariant.recordSha256 };
  Object.assign(emptyJoinRef, { ref: emptyVariant.ref, commitSha: emptyVariant.commitSha, recordSha256: emptyVariant.recordSha256 });
  rebindPacketAndReport(empty);

  const deleted = ownerEvidenceFixture({ ready02: true });
  const deletedPacket = deleted.packet;
  const deletedDirty = deletedPacket.source_capture.local_inherited_work.inherited_dirty_entries[0];
  const deletedDisposition = deletedPacket.source_capture.local_inherited_work.inherited_dispositions.find((row) => row.id === deletedDirty.id);
  const deletedJoinRef = deletedPacket.requirements.READY02.inherited_work.disposition_join.preservationRefs.find((row) => row.id === deletedDirty.id);
  const deletedOldRef = structuredClone(deletedDisposition.preservation_ref);
  const deletedId = rekeyCapturedDirtyIdentity(deletedPacket, deletedDirty, { status: ' D' });
  deletedDisposition.id = deletedId;
  deletedDisposition.source.status = ' D';
  deletedJoinRef.id = deletedId;
  const deletedVariant = commitPreservationVariant(deletedOldRef, (record) => {
    record.id = deletedId;
    record.source.status = ' D';
    record.captured_source.id = deletedId;
    record.captured_source.status = ' D';
    record.source_absence_proof = { kind: 'worktree-deletion-tombstone', worktree_path: deletedDirty.worktree_path,
      head_sha: deletedDirty.worktree_head_sha, status: ' D', path: deletedDirty.path, source_byte_sha256: deletedDirty.source_byte_sha256 };
  }, 'valid-deletion-tombstone');
  deletedDisposition.preservation_ref = { ...deletedOldRef, ref: deletedVariant.ref, commit_sha: deletedVariant.commitSha, record_sha256: deletedVariant.recordSha256 };
  Object.assign(deletedJoinRef, { ref: deletedVariant.ref, commitSha: deletedVariant.commitSha, recordSha256: deletedVariant.recordSha256 });
  rebindPacketAndReport(deleted);

  try {
    assert.equal(audit(repoRoot, { overrides: empty.overrides }).requirements.find(({ id }) => id === 'READY-02')?.status, 'satisfied');
    const deletedResult = audit(repoRoot, { overrides: deleted.overrides });
    assert.equal(deletedResult.requirements.find(({ id }) => id === 'READY-02')?.status, 'satisfied', JSON.stringify(deletedResult.blockers.filter(({ id }) => id === 'READY-02')));
  } finally { emptyVariant.cleanup(); deletedVariant.cleanup(); }
});

test('every declared package source assertion has an independent implemented predicate', () => {
  const ownerSource = readFileSync(new URL('./verify-247-readiness.mjs', import.meta.url), 'utf8');
  const auditSource = readFileSync(new URL('./verify-v149-traceability.mjs', import.meta.url), 'utf8');
  const allMapped = Object.values(phase251PackageCheckRequirements).flatMap((sources) => sources.flatMap((source) => source.assertions));
  for (const [label, source] of [['owner', ownerSource], ['independent audit', auditSource]]) {
    const switchBody = source.match(/switch \(id\) \{([\s\S]*?)\n\s*default: return false;/)?.[1] ?? '';
    const implemented = new Set([...switchBody.matchAll(/case '([^']+)'/g)].map((match) => match[1]));
    for (const id of allMapped) assert.ok(implemented.has(id), `${label} has no predicate for ${id}`);
  }
  assert.ok(allMapped.includes('candidate_package_version_requirement'));
});

test('candidate package version requirement has passing 1.6.0 and failing 1.5.0 byte controls', () => {
  const bytes = execFileSync('git', ['show', '0e773d3614a242e4fbcdd34c418ecb8a307703d6:mix.exs']);
  const source = { commit_sha: '0e773d3614a242e4fbcdd34c418ecb8a307703d6' };
  const invalidVersion = Buffer.from(bytes.toString('utf8').replace('@version "1.6.0"', '@version "1.5.0"'));
  assert.notDeepEqual(invalidVersion, bytes);
  assert.equal(evaluatePhase251PackageAssertion('candidate_package_version_requirement', bytes, source), true);
  assert.equal(evaluatePhase251PackageAssertion('candidate_package_version_requirement', invalidVersion, source), false);
  assert.equal(phase251AuditAssertion(repoRoot, 'candidate_package_version_requirement', bytes, source), true);
  assert.equal(phase251AuditAssertion(repoRoot, 'candidate_package_version_requirement', invalidVersion, source), false);
});

test('independent audit rejects each changed READY-01 check source or result identity', () => {
  const mutations = [
    (check) => { check.source_refs[0].path = 'README.md'; },
    (check) => { check.source_refs[0].commit_sha = 'f'.repeat(40); },
    (check) => { check.source_refs[0].git_blob_oid = 'f'.repeat(40); },
    (check) => { check.source_refs[0].sha256 = '0'.repeat(64); },
    (check) => { check.source_assertions[0].result = 'fail'; },
    (check) => { check.result = 'mismatch'; },
    (check) => { check.finding_detail = 'mismatch: source predicate failed.'; },
  ];
  for (const mutate of mutations) {
    const evidence = ownerEvidenceFixture({ ready01: true });
    mutate(evidence.packet.requirements.READY01.package_adopter.checks.published_tag_guide);
    const packetText = `${JSON.stringify(evidence.packet, null, 2)}\n`;
    const packetHash = sha256(packetText);
    evidence.overrides[phase251PacketPath] = packetText;
    evidence.overrides[phase247ReportPath] = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
    const result = audit(repoRoot, { overrides: evidence.overrides });
    assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.status, 'unsatisfied');
  }
});

test('an exact-tag guide or README 404 independently blocks a claimed READY-01 pass', () => {
  for (const sourcePath of ['guides/introduction/upgrading-to-v1.6.md', 'README.md']) {
    const evidence = ownerEvidenceFixture({ ready01: true });
    const source = evidence.packet.requirements.READY01.package_adopter.sources.find((item) =>
      item.source_identity === 'published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca' && item.path === sourcePath);
    Object.assign(source, { read_status: 'missing', trust_status: 'trusted_exact_commit_404', http_status: 404 });
    delete source.git_blob_oid;
    delete source.api_blob_oid;
    delete source.sha256;
    delete source.api_sha256;
    const packetText = `${JSON.stringify(evidence.packet, null, 2)}\n`;
    const packetHash = sha256(packetText);
    evidence.overrides[phase251PacketPath] = packetText;
    evidence.overrides[phase247ReportPath] = evidence.report.replace(/phase-251-reconciliation-sha256: [a-f0-9]{64}/, `phase-251-reconciliation-sha256: ${packetHash}`);
    const result = audit(repoRoot, { overrides: evidence.overrides });
    assert.equal(result.requirements.find(({ id }) => id === 'READY-01')?.status, 'unsatisfied');
  }
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

test('strict matrix keeps READY-01 unsatisfied while READY-02 is source-proven and preserves historical phase-only exceptions', () => {
  const result = audit(repoRoot);
  assert.equal(result.status, 'gaps_found');
  assert.equal(result.milestoneStatus, 'incomplete');
  assert.equal(result.requirements.length, 9);
  assert.equal(result.score.requirements, '8/9');
  assert.equal(result.score.phases, '4/6');
  assert.equal(result.score.integration, '4/5');
  assert.equal(result.score.flows, '3/4');
  assert.equal(result.acceptedExceptionCount, 0);
  assert.equal(result.historicalExceptionCount, 2);
  assert.ok(result.unacceptedBlockerCount > 0);
  assert.deepEqual(result.historicalExceptions.map(({ id }) => id), ['READY-01', 'READY-02']);

  const ready01 = result.requirements.find(({ id }) => id === 'READY-01');
  assert.equal(ready01?.status, 'unsatisfied');
  assert.equal(ready01?.verification_status, 'unsatisfied');
  assert.equal(ready01?.owner_report_status, 'gaps_found');
  assert.equal(ready01?.acceptance_status, 'unaccepted');
  assert.equal(ready01?.traceability, 'open');
  assert.equal(ready01?.historical_phase_250_exception, true);
  const ready02 = result.requirements.find(({ id }) => id === 'READY-02');
  assert.equal(ready02?.status, 'satisfied');
  assert.equal(ready02?.verification_status, 'satisfied');
  assert.equal(ready02?.owner_report_status, 'gaps_found');
  assert.equal(ready02?.acceptance_status, 'verified');
  assert.equal(ready02?.traceability, 'complete');
  assert.equal(ready02?.historical_phase_250_exception, true);

  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'AUTO-02')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-01')?.status, 'satisfied');
  assert.equal(result.requirements.find(({ id }) => id === 'REL-02')?.status, 'satisfied');
  assert.ok(result.sourceBlockers.some(({ id }) => id === 'READY-01'));
  assert.ok(!result.sourceBlockers.some(({ id }) => id === 'READY-02'));
});

test('generated audit separates historical exceptions from current readiness and never claims milestone completion', () => {
  const report = renderAudit(audit(repoRoot));
  assert.match(report, /^status: gaps_found$/m);
  assert.match(report, /^source_audit_status: gaps_found$/m);
  assert.match(report, /^milestone_status: incomplete$/m);
  assert.match(report, /^  requirements: 8\/9$/m);
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
    '| READY-01 | 247 | open | unsatisfied | unaccepted | **unsatisfied** |',
    '| READY-01 | 247 | open | satisfied | verified | **satisfied** |',
  );
  const checked = checkAudit(repoRoot, '.planning/v1.49-MILESTONE-AUDIT.md', {
    '.planning/v1.49-MILESTONE-AUDIT.md': forgedAudit,
  });
  assert.equal(checked.valid, false);
  assert.ok(checked.errors.some((message) => /requirement row READY-01 differs/i.test(message)));
});

test('audit discovers current Nyquist classifications from every v1.49 phase record', () => {
  const result = audit(repoRoot);
  assert.deepEqual(result.nyquist.compliantPhases, [246, 248, 249, 250, 251]);
  assert.deepEqual(result.nyquist.partialPhases, [247]);
  assert.deepEqual(result.nyquist.notValidatedPhases, []);
  assert.deepEqual(result.nyquist.missingPhases, []);
  assert.equal(result.nyquist.overall, 'partial');
  assert.match(renderAudit(result), /Phase 248: \*\*compliant\*\*/);
  assert.match(renderAudit(result), /Phase 247: \*\*partial\*\*/);
  assert.match(renderAudit(result), /Phase 251: \*\*compliant\*\*/);
});

test('Nyquist classification changes when a current validation record changes', () => {
  const result = audit(repoRoot, {
    overrides: {
      '.planning/phases/248-exact-source-release-gate/248-VALIDATION.md': (source) =>
        source.replace('nyquist_compliant: true', 'nyquist_compliant: false'),
    },
  });
  assert.deepEqual(result.nyquist.compliantPhases, [246, 249, 250, 251]);
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
  assert.ok(!result.blockers.some((row) => row.id === 'READY-02'));
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
