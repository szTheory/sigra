import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateSnapshot, checkReport } from './verify-248-release.mjs';

const sourceSha = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const canarySha = 'a7e1c8c25db17412c895b20e0f5c0cee45594d30';
const digest = (letter) => `sha256:${letter.repeat(64)}`;

function snapshot() {
  return {
    schema_version: 1,
    captured_at: '2026-10-10T15:00:00Z',
    repository: 'szTheory/sigra',
    tag: { name: 'v1.6.0', target_sha: sourceSha },
    release_run: { id: 37875238705, attempt: 3, workflow_path: '.github/workflows/release-please.yml', event: 'push', branch: 'main', head_sha: sourceSha, conclusion: 'success' },
    ci_run: { id: 37875238741, attempt: 2, workflow_path: '.github/workflows/ci.yml', head_sha: sourceSha, conclusion: 'success', job: { id: 113654406257, name: 'ci-gate', head_sha: sourceSha, conclusion: 'success', run_attempt: 2 } },
    success_artifact: { id: 11594782728, name: 'release-result-1.6.0-37875238705', digest: digest('a'), run_id: 37875238705, expired: false, retrieved: { status: 'passed', sha256: 'b'.repeat(64), receipt: { verdict: 'success', tag: 'v1.6.0', source_sha: sourceSha, release_run_id: 37875238705, release_attempt: 3, gate_run_id: 37875238741, gate_attempt: 2, gate_job_id: 113654406257, gate_conclusion: 'success', gate_sha: sourceSha } } },
    environments: {
      'release-automation': { secret_names: ['RELEASE_PLEASE_TOKEN'], policy: { branch_names: ['main'], can_admins_bypass: false, protected_branches: false, custom_branch_policies: true } },
      'hex-publish': { secret_names: ['HEX_API_KEY', 'HEX_DRY_RUN_API_KEY'], policy: { branch_names: ['main'], can_admins_bypass: false, protected_branches: false, custom_branch_policies: true } },
    },
    repository_secret_names: [],
    preflight: { exit_code: 0 },
    canary: {
      source_sha: canarySha,
      proof_status: 'passed', proof_sha256: 'c'.repeat(64),
      controller: { expected_id: 38059620000, expected_attempt: 1, run: { id: 38059620000, attempt: 1, workflow_path: '.github/workflows/release-receipt-canary-controller.yml', head_sha: canarySha, conclusion: 'success' }, artifact: { id: 11671884954, run_id: 38059620000, digest: digest('2'), expired: false, retrieved: { status: 'passed' } }, proof_file_sha256: '3'.repeat(64), expected_proof_sha256: '3'.repeat(64), local_proof_file_sha256: '3'.repeat(64) },
      controller_proof: { status: 'passed', source_failure_receipts: 1, credential_values_recorded: false },
      credential_values_recorded: false,
      failure: { expected_id: 38059634695, expected_attempt: 1, run: { id: 38059634695, attempt: 1, workflow_path: '.github/workflows/release-receipt-canary.yml', head_sha: canarySha, conclusion: 'failure' }, artifacts: [{ status: 'validated', id: 11671884955, name: 'release-canary-failure-38059634695-1', digest: digest('d'), run_id: 38059634695, expired: false }], artifact_retrieved: { status: 'passed', sha256: 'e'.repeat(64), receipt: { scenario: 'failure', source_run_id: 38059634695, source_attempt: 1, source_sha: canarySha, verdict: 'failure' } } },
      cancellation: { expected_id: 38059640000, run: { id: 38059640000, attempt: 1, workflow_path: '.github/workflows/release-receipt-canary.yml', head_sha: canarySha, conclusion: 'cancelled' }, observer: { run_id: 38059640100, workflow_path: '.github/workflows/release-run-observer.yml', event_source_run_id: 38059640000, source_sha: canarySha, conclusion: 'success' }, artifacts: [{ id: 11671884956, name: 'release-canary-cancellation-38059640000-1', digest: digest('f'), run_id: 38059640100, expired: false }], artifact_retrieved: { status: 'passed', sha256: '1'.repeat(64), receipt: { scenario: 'cancellation', source_run_id: 38059640000, source_attempt: 1, source_sha: canarySha, observer_run_id: 38059640100, verdict: 'cancelled' } } },
    },
  };
}

test('accepts only exact source, scope and terminal-artifact identities', () => {
  const result = evaluateSnapshot(snapshot());
  assert.equal(result.requirements['AUTO-01'].status, 'satisfied');
  assert.equal(result.requirements['AUTO-02'].status, 'satisfied');
});

test('keeps AUTO-02 unsatisfied when the recorded failure attempt has no artifact', () => {
  const current = snapshot();
  current.canary.proof_status = 'blocked';
  current.canary.failure.artifacts = [];
  current.canary.cancellation = { expected_source_run_id: 38059640000, artifact: null, run: null, observer: null };
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
  assert.ok(result.requirements['AUTO-02'].blockers.some((item) => item.includes('failure artifact')));
  assert.ok(result.requirements['AUTO-02'].blockers.some((item) => item.includes('cancellation artifact')));
});

test('rejects missing environment names, widened branch policy, and repository copies', () => {
  const current = snapshot();
  current.environments['release-automation'].secret_names = [];
  current.environments['hex-publish'].policy.branch_names = ['main', 'release/*'];
  current.repository_secret_names = ['HEX_API_KEY'];
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-01'].status, 'unsatisfied');
  assert.ok(result.requirements['AUTO-01'].blockers.length >= 3);
});

test('rejects stale source and CI gate identity even when both runs succeeded', () => {
  const current = snapshot();
  current.ci_run.head_sha = 'f'.repeat(40);
  current.ci_run.job.head_sha = 'f'.repeat(40);
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-01'].status, 'unsatisfied');
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
});

test('rejects an artifact whose ID, digest, run owner, or receipt identity changed', () => {
  const current = snapshot();
  current.canary.failure.artifacts[0].id = 99;
  current.canary.failure.artifacts[0].run_id = 7;
  current.canary.failure.artifacts[0].digest = digest('0');
  current.canary.cancellation.artifact_retrieved.receipt.observer_run_id = 9;
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
  assert.ok(result.requirements['AUTO-02'].blockers.length >= 2);
});

test('fails closed when the success artifact identity or canary source SHA changes', () => {
  const current = snapshot();
  current.success_artifact.id = 9;
  current.canary.source_sha = 'f'.repeat(40);
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-01'].status, 'unsatisfied');
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
});

test('checks canonical report status and the full source and artifact identity tuple', () => {
  const current = snapshot();
  const report = `# Phase 248 Verification\n\n<!-- phase248-evidence ${JSON.stringify({ requirements: { 'AUTO-01': 'satisfied', 'AUTO-02': 'satisfied' }, tag: 'v1.6.0', source_sha: sourceSha, release_run_id: 37875238705, ci_run_id: 37875238741, ci_gate_job_id: 113654406257, failure_run_id: 38059634695, cancellation_run_id: 38059640000, failure_artifact_id: 11671884955, cancellation_artifact_id: 11671884956 })} -->\n\n## Historical verification (2026-10-08)\n\nStatus: gaps_found\n`;
  const evaluation = evaluateSnapshot(current);
  assert.deepEqual(checkReport(report, current, evaluation), []);
  assert.ok(checkReport(report.replace('38059634695', '1'), current, evaluation).includes('report_source_identity_mismatch'));
  assert.ok(checkReport(report.replace('"AUTO-02":"satisfied"', '"AUTO-02":"unsatisfied"'), current, evaluation).includes('report_requirement_mismatch'));
});
