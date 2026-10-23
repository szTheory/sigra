import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { evaluateSnapshot, checkReport, reportIdentity, freshnessErrors, validateSourceReference, validateHistoricalAncestorComparison, renderReport } from './verify-249-release.mjs';

const packageSha = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const historicalMain = '08300af1740fea8b77d5928a182688acbf103edc';
const currentMain = '6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5';
const digest = (letter) => letter.repeat(64);
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');

function snapshot() {
  const acceptance = {
    verdict: 'passed', recorded_at: '2026-10-10T00:01:05Z', package_source_sha: packageSha,
    final_main_sha: historicalMain, errors: [],
    public_release: { verdict: 'passed', source_commit_sha: packageSha },
    final_main_ci: { run_id: 38003573391, attempt: 1, workflow: '.github/workflows/ci.yml', head_sha: historicalMain, conclusion: 'success', ci_gate: { job_id: 114069179560, head_sha: historicalMain, conclusion: 'success' } },
    receipt: { blob_sha: 'receipt-blob', sha256: digest('a') },
    inventory: { worktree_count: 1, pull_request_count: 1, dirty_path_count: 0, worktree_read_status: 'complete', pull_request_read_status: 'complete' },
  };
  const acceptanceBytes = Buffer.from(JSON.stringify(acceptance));
  const terminal = {
    schema_version: 1, phase: 249, plan: '12', verdict: 'passed', final_validation: { verdict: 'passed', errors: [], blockers: [] },
    canonical_acceptance: { path: '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-ACCEPTANCE.json', blob_sha: 'a'.repeat(40), commit_sha: 'a'.repeat(40), sha256: hash(acceptanceBytes), verdict: 'passed' },
    evidence_commits: { phase_evidence_commit_sha: 'c'.repeat(40), summary_commit_sha: 'd'.repeat(40) },
    post_ref_write_status: { paths: ['/repo'], worktrees: [{ path: '/repo', raw_status_base64: '', raw_status_sha256: hash(Buffer.alloc(0)), raw_status_bytes: 0, clean: true }] },
  };
  const terminalBytes = Buffer.from(JSON.stringify(terminal));
  const historicalReportBytes = Buffer.from('# Old report\nstatus: gaps_found\n');
  return {
    schema_version: 1, captured_at: '2026-10-10T16:00:00Z', repository: 'szTheory/sigra',
    source: {
      package_source_sha: packageSha, historical_release_main_sha: historicalMain, current_protected_main_sha: currentMain, historical_is_ancestor: true,
      historical_ancestor_evidence: {
        provider: 'GitHub Compare API', url: `https://api.github.com/repos/szTheory/sigra/compare/${historicalMain}...${currentMain}`,
        observed_at: '2026-10-10T16:00:00Z', status: 'ahead', ahead_by: 1, behind_by: 0,
        response_keys: ['ahead_by', 'base_commit', 'behind_by', 'merge_base_commit', 'status', 'url'],
        base_sha: historicalMain, head_sha: currentMain, merge_base_sha: historicalMain, verdict: 'passed',
      },
    },
    evidence_ref: { name: 'refs/heads/evidence/phase-249-final-acceptance', commit_sha: 'f'.repeat(40), acceptance_commit_sha: 'a'.repeat(40), acceptance_blob_sha: 'a'.repeat(40), acceptance_sha256: hash(acceptanceBytes), acceptance_json_base64: acceptanceBytes.toString('base64'), terminal_commit_sha: 'f'.repeat(40), terminal_blob_sha: '2'.repeat(40), terminal_sha256: hash(terminalBytes), terminal_json_base64: terminalBytes.toString('base64'), acceptance, terminal },
    receipt: { path: 'receipt.json', package_source_sha: packageSha, blob_sha: 'receipt-blob', sha256: digest('a'), current_blob_sha: 'receipt-blob' },
    public_release: { verdict: 'passed', version: '1.6.0', tag: 'v1.6.0', package_source_sha: packageSha, versioned_docs_url: 'https://sigra.hexdocs.pm/1.6.0/Sigra.html', source_url: 'https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1', checksum: digest('f') },
    historical_ci: { run_id: 38003573391, attempt: 1, workflow_path: '.github/workflows/ci.yml', head_sha: historicalMain, conclusion: 'success', job: { id: 114069179560, name: 'ci-gate', head_sha: historicalMain, conclusion: 'success', attempt: 1 } },
    current_ci: { run_id: 38061391571, attempt: 1, workflow_path: '.github/workflows/ci.yml', event: 'push', branch: 'main', head_sha: currentMain, conclusion: 'success', job: { id: 114241911167, name: 'ci-gate', head_sha: currentMain, conclusion: 'success', attempt: 1 } },
    inventory: { worktrees_read_status: 'complete', pull_requests_read_status: 'complete', worktrees: [{ path: '/repo', branch: 'main', head_sha: currentMain, read_status: 'complete', raw_status_base64: '', raw_status_sha256: hash(Buffer.alloc(0)), raw_status_bytes: 0, clean: true }], pull_requests: [{ number: 302, base_sha: currentMain, head_sha: '1'.repeat(40), disposition: 'separate-follow-up', disposition_identity_match: true }] },
    accepted_loss: { path: '.planning/HANDOFF.json', status: ' M', sha256: '00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148', authorization: 'accept reality and move on accordingly', authorized_by: 'user', authorized_at: '2026-10-09', audit_record_ref: 'refs/phase-249-preservation/plan-08-preservation-record-v4', audit_record_commit_sha: '96581c2b555a11b50b6efece9c25a5b1f8e0e456', audit_record_sha256: 'b47304df684b3eda5916730072a481d91113f6fca76bd0f9507e24387f3f4ad3', bytes_recovered: false, bytes_preserved: false },
    historical_report: { path: '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md', sha256: hash(Buffer.from(historicalReportBytes.toString('utf8').trimEnd())), raw_bytes_sha256: hash(historicalReportBytes), raw_bytes_base64: historicalReportBytes.toString('base64'), captured_at: '2026-10-10T15:59:00Z' },
  };
}

test('joins public release and terminal acceptance while keeping all three SHAs distinct', () => {
  const result = evaluateSnapshot(snapshot());
  assert.equal(result.requirements['REL-01'].status, 'satisfied', JSON.stringify(result.requirements['REL-01'].blockers));
  assert.equal(result.requirements['REL-02'].status, 'satisfied', JSON.stringify(result.requirements['REL-02'].blockers));
});

test('source reference accepts only the canonical HTTPS GitHub source path', () => {
  const valid = { href: 'https://github.com/szTheory/sigra/blob/v1.6.0/lib/sigra.ex#L1', path: 'lib/sigra.ex' };
  assert.deepEqual(validateSourceReference(valid), { valid: true, href: valid.href });
  const lowercaseRepoPath = 'https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1';
  assert.deepEqual(validateSourceReference({ ...valid, href: lowercaseRepoPath }), { valid: true, href: lowercaseRepoPath });
  const uppercaseRepoPath = 'https://github.com/SZTHEORY/SIGRA/blob/v1.6.0/lib/sigra.ex#L1';
  assert.deepEqual(validateSourceReference({ ...valid, href: uppercaseRepoPath }), { valid: true, href: uppercaseRepoPath });
  for (const href of [
    'http://github.com/szTheory/sigra/blob/v1.6.0/lib/sigra.ex',
    'https://user@github.com/szTheory/sigra/blob/v1.6.0/lib/sigra.ex',
    'https://github.com:8443/szTheory/sigra/blob/v1.6.0/lib/sigra.ex',
    'https://evil.example/szTheory/sigra/blob/v1.6.0/lib/sigra.ex',
    'https://github.com/szTheory/sigra/blob/v1.6.0/lib/%252e%252e/secrets',
    'https://github.com/szTheory/sigra/blob/v1.6.0/lib/sigra.ex?next=https://evil.example',
    'https://github.com/sztheory/sigra-fork/blob/v1.6.0/lib/sigra.ex#L1',
    'https://github.com/sztheory/sigra/blob/V1.6.0/lib/sigra.ex#L1',
    'https://github.com/sztheory/sigra/blob/v1.6.0/lib/Sigra.ex#L1',
  ]) assert.equal(validateSourceReference({ ...valid, href }).valid, false, href);
  assert.equal(validateSourceReference({ ...valid, path: '../secret' }).valid, false);
});

test('accepts only a source-bound GitHub compare proof of historical ancestry', () => {
  const ahead = {
    url: `https://api.github.com/repos/szTheory/sigra/compare/${historicalMain}...${currentMain}`,
    status: 'ahead', ahead_by: 22, behind_by: 0,
    base_commit: { sha: historicalMain }, merge_base_commit: { sha: historicalMain },
    commits: [{ sha: currentMain }],
  };
  assert.equal(validateHistoricalAncestorComparison(ahead, historicalMain, currentMain), true);
  assert.equal(validateHistoricalAncestorComparison({ ...ahead, status: 'identical', ahead_by: 0 }, historicalMain, currentMain), true);
  for (const changed of [
    { ...ahead, behind_by: 1 },
    { ...ahead, status: 'diverged' },
    { ...ahead, url: `https://api.github.com/repos/szTheory/sigra/compare/${historicalMain}...${historicalMain}` },
    { ...ahead, base_commit: { sha: currentMain } },
    { ...ahead, merge_base_commit: { sha: currentMain } },
  ]) assert.equal(validateHistoricalAncestorComparison(changed, historicalMain, currentMain), false);
});

test('blocks REL-01 when public source or evidence-ref acceptance identity drifts', () => {
  const current = snapshot();
  current.public_release.package_source_sha = historicalMain;
  current.evidence_ref.terminal.canonical_acceptance.blob_sha = 'b'.repeat(40);
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['REL-01'].status, 'unsatisfied');
  assert.ok(result.requirements['REL-01'].blockers.length >= 2);
});

test('blocks REL-02 for current-head CI mismatch, dirty raw status, changed receipt or missing PR disposition', () => {
  const current = snapshot();
  current.current_ci.job.head_sha = historicalMain;
  current.inventory.worktrees[0].raw_status_base64 = 'IHgg';
  current.inventory.worktrees[0].raw_status_bytes = 3;
  current.inventory.worktrees[0].clean = true;
  current.receipt.current_blob_sha = 'other-blob';
  current.inventory.pull_requests[0].disposition = null;
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['REL-02'].status, 'unsatisfied');
  assert.ok(result.requirements['REL-02'].blockers.length >= 4);
});

test('rejects a historical acceptance ref that points at a different main identity', () => {
  const current = snapshot();
  current.evidence_ref.acceptance.final_main_sha = currentMain;
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['REL-01'].status, 'unsatisfied');
  assert.equal(result.requirements['REL-02'].status, 'unsatisfied');
});

test('blocks REL-02 when compare evidence does not bind exact historical and current SHAs', () => {
  const current = snapshot();
  current.source.historical_ancestor_evidence.merge_base_sha = currentMain;
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['REL-02'].status, 'unsatisfied');
  assert.ok(result.requirements['REL-02'].blockers.some(item => item.includes('exact source-bound compare evidence')));
});

test('rejects terminal digest drift and a disposition copied from stale PR identities', () => {
  const current = snapshot();
  current.evidence_ref.terminal_json_base64 = Buffer.from('stale terminal').toString('base64');
  current.inventory.pull_requests[0].disposition_identity_match = false;
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['REL-01'].status, 'unsatisfied');
  assert.equal(result.requirements['REL-02'].status, 'unsatisfied');
  assert.ok(result.requirements['REL-02'].blockers.some(item => item.includes('matching its current base/head identity')));
});

test('blocks REL-02 when the exact current-main CI run fails despite a successful ci-gate job', () => {
  const current = snapshot();
  current.current_ci.conclusion = 'failure';
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['REL-02'].status, 'unsatisfied');
  assert.ok(result.requirements['REL-02'].blockers.some(item => item.includes('current CI workflow run concluded failure')));
});

test('requires current source identities and raw inventories to remain unchanged at report check', () => {
  const captured = snapshot();
  assert.deepEqual(freshnessErrors(captured, snapshot()), []);
  const current = snapshot();
  current.inventory.pull_requests[0].head_sha = '2'.repeat(40);
  current.inventory.worktrees[0].raw_status_base64 = 'IHgg';
  current.inventory.worktrees[0].raw_status_bytes = 3;
  current.inventory.worktrees[0].raw_status_sha256 = hash(Buffer.from(' x '));
  current.inventory.worktrees[0].clean = false;
  const errors = freshnessErrors(captured, current);
  assert.ok(errors.includes('open PR population, exact tuple, or disposition changed since capture'));
  assert.ok(errors.includes('registered worktree population or raw porcelain status changed since capture'));
  assert.ok(errors.includes('fresh raw worktree capture is dirty or incomplete'));
});

test('checks the report against requirement verdicts and complete captured identities', () => {
  const current = snapshot();
  const evaluation = evaluateSnapshot(current);
  const report = [
    '---', 'status: passed', '---', '# Phase 249 Verification', '', '**Status:** passed', '',
    `<!-- phase249-evidence ${JSON.stringify(reportIdentity(current, evaluation))} -->`, '',
    `The historical path is accepted-with-recorded-loss: ${current.accepted_loss.authorization}.`, '',
    '<details>', '<summary>Historical Phase 249 report preserved verbatim</summary>', '', '`````markdown',
    Buffer.from(current.historical_report.raw_bytes_base64, 'base64').toString('utf8').trimEnd(),
    '`````', '</details>', '',
  ].join('\n');
  assert.deepEqual(checkReport(report, current, evaluation), []);
  assert.ok(checkReport(report.replace('38061391571', '1'), current, evaluation).includes('report_source_identity_mismatch'));
  assert.ok(checkReport(report.replace('"REL-02":"satisfied"', '"REL-02":"unsatisfied"'), current, evaluation).includes('report_requirement_mismatch'));
});

test('checks nested historical details without truncating the preserved report', () => {
  const current = snapshot();
  const historicalText = 'Legacy report with a nested details block.\n<details>\n<summary>Earlier report</summary>\n\n`````\ninner\n`````\n</details>\n\nTrailing history remains included.';
  const historicalBytes = Buffer.from(historicalText);
  current.historical_report = {
    path: '.planning/phases/249/249-VERIFICATION.md',
    raw_bytes_base64: historicalBytes.toString('base64'), raw_bytes_sha256: hash(historicalBytes),
    sha256: hash(Buffer.from(historicalText.trimEnd())), captured_at: '2026-10-10T16:00:00Z',
  };
  assert.deepEqual(checkReport(renderReport(current), current), []);
});
