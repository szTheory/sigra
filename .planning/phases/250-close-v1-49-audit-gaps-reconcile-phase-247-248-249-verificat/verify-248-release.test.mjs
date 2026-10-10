import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { evaluateSnapshot, checkReport, normalizeControllerProof, captureCanaryTerminalReceipts, downloadArtifact } from './verify-248-release.mjs';

const sourceSha = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const canarySha = 'a7e1c8c25db17412c895b20e0f5c0cee45594d30';
const digest = (letter) => `sha256:${letter.repeat(64)}`;

function captureTerminalFixtures(failureReceipt, cancellationReceipt, mutate = (value) => value, invalidJsonId = null) {
  const failureRun = { id: 38059634695, attempt: 1, workflow_id: 380517407, workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml', url: 'https://github.com/szTheory/sigra/actions/runs/38059634695', started_at: '2026-10-10T10:00:00Z', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'failure' };
  const cancellationRun = { id: 38059640000, attempt: 1, workflow_id: 380517407, workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml', url: 'https://github.com/szTheory/sigra/actions/runs/38059640000', started_at: '2026-10-10T10:00:00Z', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'cancelled' };
  const observerRun = { id: 38059640100, attempt: 1, workflow_id: 379162190, workflow_path: '.github/workflows/release-run-observer.yml', url: 'https://github.com/szTheory/sigra/actions/runs/38059640100', started_at: '2026-10-10T10:01:00Z', event: 'workflow_run', branch: 'main', head_sha: canarySha, conclusion: 'success' };
  const failureArtifact = { id: 11671884955, name: `release-canary-failure-${failureRun.id}-${failureRun.attempt}-${failureReceipt.canary.probe_id}`, digest: '', expired: false, workflow_run: { id: failureRun.id } };
  const cancellationArtifact = { id: 11671884956, name: `release-canary-cancellation-${cancellationRun.id}-${cancellationRun.attempt}`, digest: '', expired: false, workflow_run: { id: observerRun.id } };
  const producerProof = {
    source_failure: { run_id: failureRun.id, attempt: failureRun.attempt, workflow_id: failureRun.workflow_id, artifact: failureArtifact, receipt: failureReceipt },
    source_cancellation: { run_id: cancellationRun.id, attempt: cancellationRun.attempt, workflow_id: cancellationRun.workflow_id,
      observer_run_id: String(observerRun.id), observer_attempt: observerRun.attempt, observer_workflow_id: observerRun.workflow_id,
      artifact: cancellationArtifact, receipt: cancellationReceipt },
  };
  const artifacts = new Map([[failureArtifact.id, failureArtifact], [cancellationArtifact.id, cancellationArtifact]]);
  const receipts = new Map([[failureArtifact.id, failureReceipt], [cancellationArtifact.id, cancellationReceipt]]);
  const archives = new Map([...receipts].map(([id, receipt]) => [id, Buffer.from(JSON.stringify(receipt))]));
  for (const [id, bytes] of archives) artifacts.get(id).digest = `sha256:${createHash('sha256').update(bytes).digest('hex')}`;
  const downloadCalls = [];
  const captured = captureCanaryTerminalReceipts({ producerProof, failureRun, cancellationRun, observerRun,
    failureArtifacts: [failureArtifact], cancellationArtifacts: [cancellationArtifact],
    downloadArtifactFn: (id, expected) => {
      downloadCalls.push({ id, receiptName: expected.receipt_name });
      const artifact = artifacts.get(id);
      const archived = archives.get(id);
      const downloaded = artifact ? downloadArtifact(id, expected, {
        apiJson: () => artifact,
        execute: (file, args) => {
          if (file === 'gh') return { status: 0, stdout: archived };
          if (file === 'unzip' && args[0] === '-Z1') return { status: 0, stdout: `${expected.receipt_name}\n` };
          if (file === 'unzip' && args[0] === '-p') return { status: 0, stdout: id === invalidJsonId ? Buffer.from('{malformed') : archived };
          return { status: 2, stdout: '' };
        },
      }) : { metadata: null, retrieval: { status: 'failed', reason: 'artifact_missing' } };
      return mutate(downloaded, id);
    } });
  return { ...captured, downloadCalls };
}

function snapshot() {
  const failureReceipt = { receipt_kind: 'canary', canary: { scenario: 'failure', probe_id: 'a'.repeat(32) }, terminal_verdict: 'failure', source_run_id: 38059634695, source_run_attempt: 1, source_workflow_id: 380517407, source_workflow_name: 'Release Receipt Canary', source_workflow_path: '.github/workflows/release-receipt-canary.yml', source_run_url: 'https://github.com/szTheory/sigra/actions/runs/38059634695', source_started_at: '2026-10-10T10:00:00Z', source_observed_at: '2026-10-10T10:01:00Z', recorded_at: '2026-10-10T10:01:00Z', source_event: 'workflow_dispatch', source_ref: 'refs/heads/main', source_sha: canarySha, source_repository: 'szTheory/sigra' };
  const cancellationReceipt = { receipt_kind: 'canary', canary: { scenario: 'cancellation', probe_id: 'b'.repeat(32) }, terminal_verdict: 'cancelled', source_run_id: 38059640000, source_run_attempt: 1, source_workflow_id: 380517407, source_workflow_name: 'Release Receipt Canary', source_workflow_path: '.github/workflows/release-receipt-canary.yml', source_run_url: 'https://github.com/szTheory/sigra/actions/runs/38059640000', source_started_at: '2026-10-10T10:00:00Z', source_observed_at: '2026-10-10T10:01:00Z', recorded_at: '2026-10-10T10:01:00Z', source_event: 'workflow_dispatch', source_ref: 'refs/heads/main', source_sha: canarySha, source_repository: 'szTheory/sigra', observer_run: { id: '38059640100', attempt: 1, workflow_id: 379162190, url: 'https://github.com/szTheory/sigra/actions/runs/38059640100', started_at: '2026-10-10T10:01:00Z', observed_at: '2026-10-10T10:02:00Z' } };
  const capturedReceipts = captureTerminalFixtures(failureReceipt, cancellationReceipt);
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
      controller: { expected_id: 38059620000, expected_attempt: 1, expected_workflow_id: 380517406, expected_artifact_id: 11671884954, run: { id: 38059620000, attempt: 1, workflow_id: 380517406, event: 'workflow_dispatch', branch: 'main', workflow_path: '.github/workflows/release-receipt-canary-controller.yml', head_sha: canarySha, conclusion: 'success' }, artifact: { id: 11671884954, name: 'release-canary-controller-38059620000-1', run_id: 38059620000, digest: digest('2'), expired: false, retrieved: { status: 'passed' } }, proof_file_sha256: '3'.repeat(64), expected_proof_sha256: '3'.repeat(64), local_proof_file_sha256: '3'.repeat(64) },
      controller_proof: { status: 'passed', source_failure_receipts: 1, source_cancellation_receipts: 1, credential_values_recorded: false,
        source_failure: { run_id: 38059634695, attempt: 1, workflow_id: 380517407, workflow_path: '.github/workflows/release-receipt-canary.yml', event: 'workflow_dispatch', ref: 'refs/heads/main', sha: canarySha, conclusion: 'failure', artifact: { id: 11671884955, name: capturedReceipts.failureArtifactRetrieved.artifact_name, digest: capturedReceipts.failureArtifactRetrieved.artifact_digest, expires_at: '2026-11-01T00:00:00Z' }, receipt: failureReceipt },
        source_cancellation: { run_id: 38059640000, attempt: 1, workflow_id: 380517407, workflow_path: '.github/workflows/release-receipt-canary.yml', event: 'workflow_dispatch', ref: 'refs/heads/main', sha: canarySha, conclusion: 'cancelled', artifact: { id: 11671884956, name: capturedReceipts.cancellationArtifactRetrieved.artifact_name, digest: capturedReceipts.cancellationArtifactRetrieved.artifact_digest, expires_at: '2026-11-01T00:00:00Z' }, observer_run_id: '38059640100', observer_attempt: 1, observer_workflow_id: 379162190, observer_workflow_path: '.github/workflows/release-run-observer.yml', observer_event: 'workflow_run', observer_ref: 'refs/heads/main', observer_conclusion: 'success', receipt: cancellationReceipt } },
      credential_values_recorded: false,
      failure: { expected_id: 38059634695, expected_attempt: 1, run: { id: 38059634695, attempt: 1, workflow_id: 380517407, workflow_path: '.github/workflows/release-receipt-canary.yml', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'failure' }, artifacts: [{ status: 'validated', id: 11671884955, name: capturedReceipts.failureArtifactRetrieved.artifact_name, digest: capturedReceipts.failureArtifactRetrieved.artifact_digest, run_id: 38059634695, expired: false }], artifact_retrieved: capturedReceipts.failureArtifactRetrieved },
      cancellation: { expected_id: 38059640000, run: { id: 38059640000, attempt: 1, workflow_id: 380517407, workflow_path: '.github/workflows/release-receipt-canary.yml', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'cancelled' }, observer: { run_id: '38059640100', attempt: 1, workflow_id: 379162190, workflow_path: '.github/workflows/release-run-observer.yml', event: 'workflow_run', ref: 'refs/heads/main', event_source_run_id: 38059640000, source_sha: canarySha, conclusion: 'success' }, artifacts: [{ id: 11671884956, name: capturedReceipts.cancellationArtifactRetrieved.artifact_name, digest: capturedReceipts.cancellationArtifactRetrieved.artifact_digest, run_id: 38059640100, expired: false }], artifact_retrieved: capturedReceipts.cancellationArtifactRetrieved },
    },
  };
}

test('accepts only exact source, scope and terminal-artifact identities', () => {
  const result = evaluateSnapshot(snapshot());
  assert.equal(result.requirements['AUTO-01'].status, 'satisfied');
  assert.equal(result.requirements['AUTO-02'].status, 'satisfied');
});

test('capture joins both downloaded terminal receipts to producer proof and authoritative artifact metadata', () => {
  const valid = snapshot();
  assert.equal(valid.canary.failure.artifact_retrieved.status, 'passed');
  assert.equal(valid.canary.failure.artifact_retrieved.artifact_id, 11671884955);
  assert.equal(valid.canary.failure.artifact_retrieved.artifact_digest, valid.canary.failure.artifacts[0].digest);
  assert.equal(valid.canary.cancellation.artifact_retrieved.status, 'passed');
  assert.equal(valid.canary.cancellation.artifact_retrieved.artifact_id, 11671884956);
  assert.equal(valid.canary.cancellation.artifact_retrieved.artifact_digest, valid.canary.cancellation.artifacts[0].digest);
  assert.deepEqual(captureTerminalFixtures(valid.canary.controller_proof.source_failure.receipt, valid.canary.controller_proof.source_cancellation.receipt).downloadCalls,
    [{ id: 11671884955, receiptName: 'canary-receipt.json' }, { id: 11671884956, receiptName: 'release-cancellation.json' }]);

  const failureReceipt = valid.canary.controller_proof.source_failure.receipt;
  const cancellationReceipt = valid.canary.controller_proof.source_cancellation.receipt;
  const badSourceIdentity = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884955
    ? { ...downloaded, retrieval: { ...downloaded.retrieval, receipt: { ...downloaded.retrieval.receipt, source_run_id: 1 } } } : downloaded);
  assert.equal(badSourceIdentity.failureArtifactRetrieved.status, 'blocked');
  const badObserverIdentity = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884956
    ? { ...downloaded, retrieval: { ...downloaded.retrieval, receipt: { ...downloaded.retrieval.receipt, observer_run: { ...downloaded.retrieval.receipt.observer_run, attempt: 9 } } } } : downloaded);
  assert.equal(badObserverIdentity.cancellationArtifactRetrieved.status, 'blocked');
  const badArtifactBytes = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884955
    ? { ...downloaded, retrieval: { ...downloaded.retrieval, status: 'failed', reason: 'artifact_digest_mismatch', receipt: null } } : downloaded);
  assert.equal(badArtifactBytes.failureArtifactRetrieved.status, 'blocked');
  const wrongArtifactOwner = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884956
    ? { ...downloaded, metadata: { ...downloaded.metadata, workflow_run: { id: 1 } } } : downloaded);
  assert.equal(wrongArtifactOwner.cancellationArtifactRetrieved.status, 'blocked');
  const malformedDownloadedReceipt = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded) => downloaded, 11671884955);
  assert.equal(malformedDownloadedReceipt.failureArtifactRetrieved.status, 'blocked');
});

test('normalizes the controller producer schema without rewriting its pass or run_id fields', () => {
  const current = snapshot();
  const producer = { schema_version: 1, status: 'pass', credential_values_recorded: false,
    source_failure: current.canary.controller_proof.source_failure,
    source_cancellation: current.canary.controller_proof.source_cancellation,
    retrieval: { failure_zip_sha256: 'd'.repeat(64), cancellation_zip_sha256: 'f'.repeat(64) } };
  const normalized = normalizeControllerProof(producer);
  assert.equal(normalized.status, 'passed');
  assert.equal(normalized.source_failure.run_id, 38059634695);
  assert.equal(normalized.source_cancellation.receipt.terminal_verdict, 'cancelled');
  assert.equal(normalized.source_failure_receipts, 1);
  assert.equal(normalized.source_cancellation_receipts, 1);
  const invalid = normalizeControllerProof({ ...producer, source_cancellation: { ...producer.source_cancellation, conclusion: 'success' } });
  assert.equal(invalid.status, 'blocked');
  const sourceIdentityDrift = normalizeControllerProof({ ...producer, source_failure: { ...producer.source_failure, ref: 'refs/heads/other' } });
  assert.equal(sourceIdentityDrift.status, 'blocked');
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
  current.canary.cancellation.artifact_retrieved.receipt = { ...current.canary.cancellation.artifact_retrieved.receipt,
    observer_run: { ...current.canary.cancellation.artifact_retrieved.receipt.observer_run, id: '9' } };
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
  assert.ok(result.requirements['AUTO-02'].blockers.length >= 2);
});

test('rejects contradictory terminal source outcome and observer attempt identity', () => {
  const current = snapshot();
  current.canary.controller_proof.source_failure.conclusion = 'success';
  current.canary.controller_proof.source_cancellation.observer_attempt = 2;
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
  assert.ok(result.requirements['AUTO-02'].blockers.some((item) => item.includes('failure')));
  assert.ok(result.requirements['AUTO-02'].blockers.some((item) => item.includes('observer')));
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
