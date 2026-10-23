import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { evaluateSnapshot, checkReport, normalizeControllerProof, captureCanaryTerminalReceipts, downloadArtifact, reportIdentity, selectProducerProof } from './verify-248-release.mjs';
import { audit } from './verify-v149-traceability.mjs';

const sourceSha = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const canarySha = 'a7e1c8c25db17412c895b20e0f5c0cee45594d30';
const digest = (letter) => `sha256:${letter.repeat(64)}`;

function produceCanaryReceipt({ id, scenario, probeId, startedAt, observedAt, observerRun = null }) {
  const directory = mkdtempSync(join(tmpdir(), 'sigra-receipt-producer-'));
  const inputPath = join(directory, 'input.json');
  const outputPath = join(directory, 'canary-receipt.json');
  const sourceRun = { id: String(id), attempt: 1, workflow_id: 380517407,
    workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml',
    url: `https://github.com/szTheory/sigra/actions/runs/${id}`, started_at: startedAt, observed_at: observedAt };
  const input = { schema_version: 1, receipt_kind: 'canary', canary: { probe_id: probeId, scenario },
    source_event: 'workflow_dispatch', source: { repository: 'szTheory/sigra', ref: 'refs/heads/main', sha: canarySha },
    source_run: sourceRun, terminal_verdict: scenario === 'failure' ? 'failure' : 'cancelled', observer_run: observerRun };
  writeFileSync(inputPath, JSON.stringify(input));
  try {
    const result = spawnSync('bash', ['scripts/ci/release-receipt.sh', '--mode', 'canary', '--input', inputPath,
      '--output', outputPath, '--expected-workflow-id', String(sourceRun.workflow_id)], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(readFileSync(outputPath, 'utf8'));
  } finally { rmSync(directory, { recursive: true, force: true }); }
}

function captureTerminalFixtures(failureReceipt, cancellationReceipt, mutate = (value) => value, invalidJsonId = null) {
  const failureRun = { id: 38059634695, attempt: 1, workflow_id: 380517407, workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml', display_title: 'release-receipt-canary-failure-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', url: 'https://github.com/szTheory/sigra/actions/runs/38059634695', started_at: '2026-10-10T10:00:00Z', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'failure' };
  const cancellationRun = { id: 38059640000, attempt: 1, workflow_id: 380517407, workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml', display_title: 'release-receipt-canary-cancellation-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', url: 'https://github.com/szTheory/sigra/actions/runs/38059640000', started_at: '2026-10-10T10:00:00Z', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'cancelled' };
  const observerRun = { id: 38059640100, attempt: 1, workflow_id: 379162190, workflow_name: 'Release Run Observer', workflow_path: '.github/workflows/release-run-observer.yml', url: 'https://github.com/szTheory/sigra/actions/runs/38059640100', started_at: '2026-10-10T10:01:00Z', event: 'workflow_run', branch: 'main', head_sha: canarySha, conclusion: 'success' };
  const failureArtifact = { id: 11671884955, name: `release-canary-failure-${failureRun.id}-${failureRun.attempt}-${failureReceipt.probe_id}`, digest: '', expired: false, expires_at: '2026-11-01T00:00:00Z', workflow_run: { id: failureRun.id } };
  const cancellationArtifact = { id: 11671884956, name: `release-canary-cancellation-${cancellationRun.id}-${cancellationRun.attempt}`, digest: '', expired: false, expires_at: '2026-11-01T00:00:00Z', workflow_run: { id: observerRun.id } };
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
  const failureReceipt = produceCanaryReceipt({ id: 38059634695, scenario: 'failure', probeId: 'a'.repeat(32), startedAt: '2026-10-10T10:00:00Z', observedAt: '2026-10-10T10:01:00Z' });
  const cancellationReceipt = produceCanaryReceipt({ id: 38059640000, scenario: 'cancellation', probeId: 'b'.repeat(32), startedAt: '2026-10-10T10:00:00Z', observedAt: '2026-10-10T10:01:00Z',
    observerRun: { id: '38059640100', attempt: 1, workflow_id: 379162190, url: 'https://github.com/szTheory/sigra/actions/runs/38059640100', started_at: '2026-10-10T10:01:00Z', observed_at: '2026-10-10T10:02:00Z' } });
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
      failure: { expected_id: 38059634695, expected_attempt: 1, run: { id: 38059634695, attempt: 1, workflow_id: 380517407, workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml', display_title: 'release-receipt-canary-failure-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', url: 'https://github.com/szTheory/sigra/actions/runs/38059634695', started_at: '2026-10-10T10:00:00Z', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'failure' }, artifacts: [{ status: 'validated', id: 11671884955, name: capturedReceipts.failureArtifactRetrieved.artifact_name, digest: capturedReceipts.failureArtifactRetrieved.artifact_digest, run_id: 38059634695, expired: false, expires_at: '2026-11-01T00:00:00Z' }], artifact_retrieved: capturedReceipts.failureArtifactRetrieved },
      cancellation: { expected_id: 38059640000, run: { id: 38059640000, attempt: 1, workflow_id: 380517407, workflow_name: 'Release Receipt Canary', workflow_path: '.github/workflows/release-receipt-canary.yml', display_title: 'release-receipt-canary-cancellation-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', url: 'https://github.com/szTheory/sigra/actions/runs/38059640000', started_at: '2026-10-10T10:00:00Z', event: 'workflow_dispatch', branch: 'main', head_sha: canarySha, conclusion: 'cancelled' }, observer: { run_id: '38059640100', attempt: 1, workflow_id: 379162190, workflow_path: '.github/workflows/release-run-observer.yml', url: 'https://github.com/szTheory/sigra/actions/runs/38059640100', started_at: '2026-10-10T10:01:00Z', event: 'workflow_run', ref: 'refs/heads/main', event_source_run_id: 38059640000, source_sha: canarySha, conclusion: 'success' }, artifacts: [{ id: 11671884956, name: capturedReceipts.cancellationArtifactRetrieved.artifact_name, digest: capturedReceipts.cancellationArtifactRetrieved.artifact_digest, run_id: 38059640100, expired: false, expires_at: '2026-11-01T00:00:00Z' }], artifact_retrieved: capturedReceipts.cancellationArtifactRetrieved },
    },
  };
}

test('accepts only exact source, scope and terminal-artifact identities', () => {
  const current = snapshot();
  assert.equal(Object.hasOwn(current.canary.failure.artifact_retrieved.receipt, 'canary'), false);
  assert.equal(current.canary.failure.artifact_retrieved.receipt.probe_id, 'a'.repeat(32));
  assert.equal(current.canary.failure.artifact_retrieved.receipt.scenario, 'failure');
  assert.equal(Object.hasOwn(current.canary.cancellation.artifact_retrieved.receipt, 'canary'), false);
  assert.equal(current.canary.cancellation.artifact_retrieved.receipt.probe_id, 'b'.repeat(32));
  assert.equal(current.canary.cancellation.artifact_retrieved.receipt.scenario, 'cancellation');
  const result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-01'].status, 'satisfied');
  assert.equal(result.requirements['AUTO-02'].status, 'satisfied');
  const report = `# Phase 248 Verification\n\n<!-- phase248-evidence ${JSON.stringify(reportIdentity({ ...current, requirements: result.requirements }))} -->\n\nHistorical verification (2026-10-08): gaps_found.\n`;
  assert.deepEqual(checkReport(report, current, result), []);

  const ownerReport = `---\nphase: 248-exact-source-release-gate\nstatus: gaps_found\nowner_requirements: [AUTO-01, AUTO-02]\n---\n\n<!-- phase248-evidence ${JSON.stringify(reportIdentity({ ...current, requirements: result.requirements }))} -->\n\nHistorical verification (2026-10-08): gaps_found.\n`;
  const traceability = audit(process.cwd(), { overrides: {
    '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-248-SOURCE-SNAPSHOT.json': JSON.stringify({ ...current, requirements: result.requirements }),
    '.planning/phases/248-exact-source-release-gate/248-VERIFICATION.md': ownerReport,
  } });
  assert.equal(traceability.owners['248'].requirements.find(({ id }) => id === 'AUTO-02').status, 'satisfied');
  assert.equal(traceability.blockers.some(({ id, message }) => id === 'AUTO-02' && message.includes('Phase 248 report fails its recomputed source check')), false);
});

test('reconciles a controller archive-download failure only after both live terminal receipts validate', () => {
  const current = snapshot();
  current.canary.controller.run.conclusion = 'failure';
  current.canary.controller.artifact.internal_proof_status = 'blocked';
  current.canary.controller.artifact.internal_proof_reason = 'failure_receipt_digest_or_json_validation_failed';
  current.canary.controller_proof_source = 'independent_terminal_artifact_revalidation';
  current.canary.controller_reconciliation = {
    status: 'passed', mode: 'independent_terminal_artifact_revalidation',
    failure_code: 'gh_api_unknown_output_flag', controller_run_id: current.canary.controller.expected_id,
    controller_artifact_id: current.canary.controller.expected_artifact_id,
  };
  let result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-02'].status, 'satisfied');

  current.canary.cancellation.artifact_retrieved.status = 'blocked';
  result = evaluateSnapshot(current);
  assert.equal(result.requirements['AUTO-02'].status, 'unsatisfied');
  assert.ok(result.blockers.some((item) => item.includes('controller run identity or conclusion mismatch')));

  const wrongFailure = snapshot();
  wrongFailure.canary.controller.run.conclusion = 'failure';
  wrongFailure.canary.controller.artifact.internal_proof_status = 'blocked';
  wrongFailure.canary.controller.artifact.internal_proof_reason = 'failure_receipt_digest_or_json_validation_failed';
  wrongFailure.canary.controller_proof_source = 'independent_terminal_artifact_revalidation';
  wrongFailure.canary.controller_reconciliation = {
    status: 'passed', mode: 'independent_terminal_artifact_revalidation',
    failure_code: 'some_other_controller_failure', controller_run_id: wrongFailure.canary.controller.expected_id,
    controller_artifact_id: wrongFailure.canary.controller.expected_artifact_id,
  };
  assert.equal(evaluateSnapshot(wrongFailure).requirements['AUTO-02'].status, 'unsatisfied');
});

test('selects independent receipt records only for the exact failed controller artifact and source', () => {
  const current = snapshot();
  const controller = current.canary.controller.run;
  const failureReceipt = current.canary.controller_proof.source_failure.receipt;
  const cancellationReceipt = current.canary.controller_proof.source_cancellation.receipt;
  const failureArtifact = {
    id: 11671884955,
    name: `release-canary-failure-${failureReceipt.source_run_id}-1-${failureReceipt.probe_id}`,
    digest: digest('e'), expires_at: '2026-11-01T00:00:00Z',
  };
  const cancellationArtifact = {
    id: 11671884956,
    name: `release-canary-cancellation-${cancellationReceipt.source_run_id}-1`,
    digest: digest('f'), expires_at: '2026-11-01T00:00:00Z',
  };
  const independent = {
    schema_version: 1, status: 'pass', credential_values_recorded: false,
    source_failure: {
      run_id: failureReceipt.source_run_id, attempt: failureReceipt.source_run_attempt,
      workflow_id: failureReceipt.source_workflow_id, workflow_path: failureReceipt.source_workflow_path,
      event: failureReceipt.source_event, ref: failureReceipt.source_ref, sha: failureReceipt.source_sha,
      conclusion: 'failure', artifact: failureArtifact, receipt: failureReceipt,
    },
    source_cancellation: {
      run_id: cancellationReceipt.source_run_id, attempt: cancellationReceipt.source_run_attempt,
      workflow_id: cancellationReceipt.source_workflow_id, workflow_path: cancellationReceipt.source_workflow_path,
      event: cancellationReceipt.source_event, ref: cancellationReceipt.source_ref, sha: cancellationReceipt.source_sha,
      conclusion: 'cancelled', artifact: cancellationArtifact,
      observer_run_id: cancellationReceipt.observer_run.id, observer_attempt: cancellationReceipt.observer_run.attempt,
      observer_workflow_id: cancellationReceipt.observer_run.workflow_id,
      observer_workflow_path: '.github/workflows/release-run-observer.yml', observer_event: 'workflow_dispatch',
      observer_ref: 'refs/heads/main', observer_conclusion: 'success', receipt: cancellationReceipt,
    },
    source_sha: failureReceipt.source_sha,
    controller_run: {
      id: controller.id, attempt: controller.attempt, workflow_id: controller.workflow_id,
      workflow_path: controller.workflow_path, event: controller.event, ref: `refs/heads/${controller.branch}`,
      sha: controller.head_sha, conclusion: 'failure', artifact: {
        id: current.canary.controller.expected_artifact_id,
        name: `release-canary-controller-${controller.id}-${controller.attempt}`,
        digest: digest('2'), expires_at: '2026-11-01T00:00:00Z', proof_sha256: '3'.repeat(64),
      },
    },
    controller_outcome: {
      run_id: controller.id, conclusion: 'failure', failure_code: 'gh_api_unknown_output_flag',
      failed_step: 'Read-only preflight and exact-run orchestration',
    },
  };
  const artifact = {
    id: independent.controller_run.artifact.id, name: independent.controller_run.artifact.name,
    digest: independent.controller_run.artifact.digest, expires_at: independent.controller_run.artifact.expires_at,
    expired: false, run_id: controller.id,
  };
  const selection = selectProducerProof({
    proof: independent,
    controllerRun: { ...controller, conclusion: 'failure' },
    controllerArtifact: artifact,
    controllerArtifactDownload: {
      metadata: { ...artifact, workflow_run: { id: controller.id } },
      retrieval: { status: 'passed', sha256: '3'.repeat(64), receipt: { status: 'blocked', reason: 'failure_receipt_digest_or_json_validation_failed' } },
    },
    controllerArtifactProof: { status: 'blocked', reason: 'failure_receipt_digest_or_json_validation_failed' },
    controllerLocalSha: '3'.repeat(64),
  });
  assert.equal(selection.producerProof.status, 'passed');
  assert.equal(selection.source, 'independent_terminal_artifact_revalidation');
  assert.equal(selection.reconciliation.failure_code, 'gh_api_unknown_output_flag');

  const mismatch = selectProducerProof({
    proof: independent,
    controllerRun: { ...controller, conclusion: 'failure' },
    controllerArtifact: { ...artifact, digest: digest('0') },
    controllerArtifactDownload: {
      metadata: { ...artifact, workflow_run: { id: controller.id } },
      retrieval: { status: 'passed', sha256: '3'.repeat(64), receipt: { status: 'blocked', reason: 'failure_receipt_digest_or_json_validation_failed' } },
    },
    controllerArtifactProof: { status: 'blocked', reason: 'failure_receipt_digest_or_json_validation_failed' },
    controllerLocalSha: '3'.repeat(64),
  });
  assert.equal(mismatch.producerProof.status, 'blocked');
  assert.equal(mismatch.reconciliation.status, 'blocked');
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
  const badObserverUrl = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884956
    ? { ...downloaded, retrieval: { ...downloaded.retrieval, receipt: { ...downloaded.retrieval.receipt, observer_run: { ...downloaded.retrieval.receipt.observer_run, url: 'https://github.com/szTheory/sigra/actions/runs/1' } } } } : downloaded);
  assert.equal(badObserverUrl.cancellationArtifactRetrieved.status, 'blocked');
  const badArtifactBytes = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884955
    ? { ...downloaded, retrieval: { ...downloaded.retrieval, status: 'failed', reason: 'artifact_digest_mismatch', receipt: null } } : downloaded);
  assert.equal(badArtifactBytes.failureArtifactRetrieved.status, 'blocked');
  const wrongArtifactOwner = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded, id) => id === 11671884956
    ? { ...downloaded, metadata: { ...downloaded.metadata, workflow_run: { id: 1 } } } : downloaded);
  assert.equal(wrongArtifactOwner.cancellationArtifactRetrieved.status, 'blocked');
  const malformedDownloadedReceipt = captureTerminalFixtures(failureReceipt, cancellationReceipt, (downloaded) => downloaded, 11671884955);
  assert.equal(malformedDownloadedReceipt.failureArtifactRetrieved.status, 'blocked');

  assert.equal(captureTerminalFixtures({ ...failureReceipt, probe_id: undefined }, cancellationReceipt).failureArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures({ ...failureReceipt, probe_id: 'c'.repeat(32) }, cancellationReceipt).failureArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures({ ...failureReceipt, scenario: undefined }, cancellationReceipt).failureArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures({ ...failureReceipt, scenario: 'cancellation' }, cancellationReceipt).failureArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures(failureReceipt, { ...cancellationReceipt, probe_id: undefined }).cancellationArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures(failureReceipt, { ...cancellationReceipt, probe_id: 'd'.repeat(32) }).cancellationArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures(failureReceipt, { ...cancellationReceipt, scenario: undefined }).cancellationArtifactRetrieved.status, 'blocked');
  assert.equal(captureTerminalFixtures(failureReceipt, { ...cancellationReceipt, scenario: 'failure' }).cancellationArtifactRetrieved.status, 'blocked');
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
