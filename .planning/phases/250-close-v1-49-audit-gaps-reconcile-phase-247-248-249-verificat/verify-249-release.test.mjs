import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateSnapshot, checkReport } from './verify-249-release.mjs';

const packageSha = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const historicalMain = '08300af1740fea8b77d5928a182688acbf103edc';
const currentMain = '6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5';
const digest = (letter) => letter.repeat(64);

function snapshot() {
  const acceptance = {
    verdict: 'passed', recorded_at: '2026-10-10T00:01:05Z', package_source_sha: packageSha,
    final_main_sha: historicalMain, errors: [],
    public_release: { verdict: 'passed', source_commit_sha: packageSha },
    final_main_ci: { head_sha: historicalMain, conclusion: 'success', ci_gate: { head_sha: historicalMain, conclusion: 'success' } },
    receipt: { blob_sha: 'receipt-blob', sha256: digest('a') },
    inventory: { worktree_count: 1, pull_request_count: 1, dirty_path_count: 0, worktree_read_status: 'complete', pull_request_read_status: 'complete' },
  };
  const terminal = {
    verdict: 'passed', final_validation: { verdict: 'passed', errors: [], blockers: [] },
    canonical_acceptance: { path: 'acceptance.json', blob_sha: 'acceptance-blob', commit_sha: 'a'.repeat(40), sha256: digest('b'), verdict: 'passed' },
    evidence_commits: { phase_evidence_commit_sha: 'c'.repeat(40), summary_commit_sha: 'd'.repeat(40) },
    post_ref_write_status: { paths: ['/repo'], worktrees: [{ path: '/repo', raw_status_base64: '', raw_status_sha256: digest('e'), raw_status_bytes: 0, clean: true }] },
  };
  return {
    schema_version: 1, captured_at: '2026-10-10T16:00:00Z', repository: 'szTheory/sigra',
    source: { package_source_sha: packageSha, historical_release_main_sha: historicalMain, current_protected_main_sha: currentMain, historical_is_ancestor: true },
    evidence_ref: { name: 'refs/heads/evidence/phase-249-final-acceptance', commit_sha: 'f'.repeat(40), acceptance_blob_sha: 'acceptance-blob', acceptance_sha256: digest('b'), terminal_blob_sha: 'terminal-blob', terminal_sha256: digest('c'), acceptance, terminal },
    receipt: { path: 'receipt.json', package_source_sha: packageSha, blob_sha: 'receipt-blob', sha256: digest('a'), current_blob_sha: 'receipt-blob' },
    public_release: { verdict: 'passed', version: '1.6.0', tag: 'v1.6.0', package_source_sha: packageSha, versioned_docs_url: 'https://sigra.hexdocs.pm/1.6.0/Sigra.html', source_url: 'https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1', checksum: digest('f') },
    historical_ci: { run_id: 38003573391, attempt: 1, head_sha: historicalMain, conclusion: 'success', job: { id: 114069179560, name: 'ci-gate', head_sha: historicalMain, conclusion: 'success', attempt: 1 } },
    current_ci: { run_id: 38061391571, attempt: 1, head_sha: currentMain, conclusion: 'failure', job: { id: 114241911167, name: 'ci-gate', head_sha: currentMain, conclusion: 'success', attempt: 1 } },
    inventory: { worktrees: [{ path: '/repo', branch: 'main', head_sha: currentMain, raw_status_base64: '', raw_status_sha256: digest('e'), raw_status_bytes: 0, clean: true }], pull_requests: [{ number: 302, base_sha: currentMain, head_sha: '1'.repeat(40), disposition: 'separate-follow-up' }] },
    accepted_loss: { path: '.planning/HANDOFF.json', status: ' M', sha256: '00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148', authorization: 'accept reality and move on accordingly', authorized_by: 'user', bytes_recovered: false, bytes_preserved: false },
  };
}

test('joins public release and terminal acceptance while keeping all three SHAs distinct', () => {
  const result = evaluateSnapshot(snapshot());
  assert.equal(result.requirements['REL-01'].status, 'satisfied');
  assert.equal(result.requirements['REL-02'].status, 'satisfied');
});

test('blocks REL-01 when public source or evidence-ref acceptance identity drifts', () => {
  const current = snapshot();
  current.public_release.package_source_sha = historicalMain;
  current.evidence_ref.terminal.canonical_acceptance.blob_sha = 'stale-blob';
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

test('checks the report against requirement verdicts and complete captured identities', () => {
  const current = snapshot();
  const evaluation = evaluateSnapshot(current);
  const report = `# Phase 249 Verification\n\n<!-- phase249-evidence ${JSON.stringify({ requirements: { 'REL-01': 'satisfied', 'REL-02': 'satisfied' }, package_source_sha: packageSha, historical_release_main_sha: historicalMain, current_protected_main_sha: currentMain, evidence_ref: current.evidence_ref.name, evidence_ref_commit: current.evidence_ref.commit_sha, current_ci_run_id: current.current_ci.run_id, current_ci_job_id: current.current_ci.job.id, receipt_blob_sha: current.receipt.blob_sha })} -->\n`;
  assert.deepEqual(checkReport(report, current, evaluation), []);
  assert.ok(checkReport(report.replace('38061391571', '1'), current, evaluation).includes('report_source_identity_mismatch'));
  assert.ok(checkReport(report.replace('"REL-02":"satisfied"', '"REL-02":"unsatisfied"'), current, evaluation).includes('report_requirement_mismatch'));
});
