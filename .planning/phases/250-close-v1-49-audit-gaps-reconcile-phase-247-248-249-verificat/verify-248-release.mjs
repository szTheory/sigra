import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, renameSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = process.cwd();
const PHASE_DIR = '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat';
const SNAPSHOT_PATH = join(ROOT, PHASE_DIR, '250-248-SOURCE-SNAPSHOT.json');
const PROOF_PATH = join(ROOT, PHASE_DIR, '250-CANARY-PROOF.json');
const SUCCESS = {
  tag: 'v1.6.0', sourceSha: '9e80cb78d6374b1ed4074d5fef6b613fee879dca',
  releaseRunId: 37875238705, releaseAttempt: 3, ciRunId: 37875238741, ciAttempt: 2,
  ciGateJobId: 113654406257, successArtifactId: 11594782728,
};

const text = (value) => typeof value === 'string' ? value : '';
const sha256 = (data) => createHash('sha256').update(data).digest('hex');
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const validProbeId = (value) => typeof value === 'string' && /^[a-f0-9-]{16,64}$/.test(value);
const req = (status, blockers) => ({ status: blockers.length ? 'unsatisfied' : status, blockers });
const canonicalize = (value) => Array.isArray(value) ? value.map(canonicalize)
  : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])])) : value;
const canonicalJson = (value) => JSON.stringify(canonicalize(value));
const validTimestamp = (value) => typeof value === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(value) && Number.isFinite(Date.parse(value));
const wholeSecond = (value) => typeof value === 'string' ? value.replace(/\.\d+Z$/, 'Z') : value;

function command(file, args, options = {}) {
  return spawnSync(file, args, { encoding: Object.hasOwn(options, 'encoding') ? options.encoding : 'utf8', maxBuffer: 16 * 1024 * 1024, ...options });
}

function ghJson(endpoint) {
  const result = command('gh', ['api', endpoint]);
  if (result.status !== 0) throw new Error('github_api_unavailable');
  try { return JSON.parse(result.stdout); } catch { throw new Error('github_api_invalid_json'); }
}

function secretNames(args) {
  const result = command('gh', ['secret', 'list', '--repo', 'szTheory/sigra', ...args, '--json', 'name']);
  if (result.status !== 0) throw new Error('github_secret_name_query_failed');
  try {
    const parsed = JSON.parse(result.stdout);
    return parsed.map((item) => item.name).filter((name) => typeof name === 'string').sort();
  } catch { throw new Error('github_secret_name_response_invalid'); }
}

export function downloadArtifact(artifactId, expected, { apiJson = ghJson, execute = command, tempDirectory = tmpdir() } = {}) {
  const metadata = apiJson(`repos/szTheory/sigra/actions/artifacts/${artifactId}`);
  const result = execute('gh', ['api', `repos/szTheory/sigra/actions/artifacts/${artifactId}/zip`], { encoding: null });
  if (result.status !== 0 || !Buffer.isBuffer(result.stdout)) return { metadata, retrieval: { status: 'failed', reason: 'artifact_download_failed' } };
  const bytes = result.stdout;
  const actualDigest = `sha256:${sha256(bytes)}`;
  const retrieval = { status: 'passed', sha256: '', receipt: null };
  if (metadata.digest !== actualDigest) return { metadata, retrieval: { status: 'failed', reason: 'artifact_digest_mismatch', observed_digest: actualDigest } };

  const zipPath = join(tempDirectory, `sigra-artifact-${process.pid}-${artifactId}.zip`);
  try {
    writeFileSync(zipPath, bytes, { flag: 'wx', mode: 0o600 });
    const listing = execute('unzip', ['-Z1', zipPath]);
    if (listing.status !== 0) return { metadata, retrieval: { status: 'failed', reason: 'artifact_archive_invalid' } };
    const names = listing.stdout.split(/\r?\n/).filter(Boolean);
    const jsonName = names.find((name) => name === expected.receipt_name || name.endsWith(`/${expected.receipt_name}`));
    if (!jsonName) return { metadata, retrieval: { status: 'failed', reason: 'artifact_receipt_missing' } };
    const extracted = execute('unzip', ['-p', zipPath, jsonName]);
    if (extracted.status !== 0) return { metadata, retrieval: { status: 'failed', reason: 'artifact_receipt_unreadable' } };
    let receipt;
    try { receipt = JSON.parse(extracted.stdout); } catch { return { metadata, retrieval: { status: 'failed', reason: 'artifact_receipt_invalid_json' } }; }
    retrieval.sha256 = sha256(extracted.stdout);
    retrieval.receipt = expected.map_receipt(receipt);
    retrieval.status = 'passed';
    return { metadata, retrieval };
  } finally {
    try { unlinkSync(zipPath); } catch { /* temporary evidence archive cleanup is best effort */ }
  }
}

function runMetadata(id) {
  const run = ghJson(`repos/szTheory/sigra/actions/runs/${id}`);
  return {
    id: run.id, attempt: run.run_attempt, workflow_id: run.workflow_id, workflow_name: run.name, workflow_path: run.path?.replace(/@.*$/, ''),
    display_title: run.display_title, event: run.event, branch: run.head_branch, head_sha: run.head_sha,
    url: run.html_url, started_at: run.run_started_at, status: run.status, conclusion: run.conclusion, created_at: run.created_at, updated_at: run.updated_at,
  };
}

function artifactMetadata(id) {
  const artifact = ghJson(`repos/szTheory/sigra/actions/artifacts/${id}`);
  return {
    id: artifact.id, name: artifact.name, digest: artifact.digest,
    expired: artifact.expired, expires_at: artifact.expires_at, run_id: artifact.workflow_run?.id ?? null,
  };
}

function onlyNames(values) {
  return Array.isArray(values) ? [...new Set(values.filter((value) => typeof value === 'string'))].sort() : [];
}

export function normalizeControllerProof(proof) {
  const failure = proof?.source_failure ?? null;
  const cancellation = proof?.source_cancellation ?? null;
  const sourceMatchesReceipt = (record, scenario, verdict) => record?.receipt?.schema_version === 1
    && record?.receipt?.receipt_kind === 'canary' && validProbeId(record?.receipt?.probe_id)
    && record?.receipt?.scenario === scenario && record?.receipt?.terminal_verdict === verdict
    && record?.receipt?.source_repository === 'szTheory/sigra'
    && String(record?.receipt?.source_run_id ?? '') === String(record?.run_id ?? '')
    && record?.receipt?.source_run_attempt === record?.attempt
    && record?.receipt?.source_event === record?.event
    && record?.receipt?.source_ref === record?.ref && record?.receipt?.source_sha === record?.sha
    && record?.receipt?.source_workflow_id === record?.workflow_id
    && record?.receipt?.source_workflow_path === record?.workflow_path?.replace(/@.*$/, '')
    && record?.receipt?.source_workflow_name === 'Release Receipt Canary'
    && record?.receipt?.source_run_url === `https://github.com/szTheory/sigra/actions/runs/${record?.run_id}`
    && validTimestamp(record?.receipt?.source_started_at) && validTimestamp(record?.receipt?.source_observed_at)
    && validTimestamp(record?.receipt?.recorded_at);
  const valid = proof?.schema_version === 1 && proof.status === 'pass'
    && failure?.conclusion === 'failure' && failure?.receipt?.terminal_verdict === 'failure'
    && cancellation?.conclusion === 'cancelled' && cancellation?.receipt?.terminal_verdict === 'cancelled'
    && sourceMatchesReceipt(failure, 'failure', 'failure') && failure.receipt.observer_run === null
    && sourceMatchesReceipt(cancellation, 'cancellation', 'cancelled')
    && failure.receipt.probe_id !== cancellation.receipt.probe_id
    && cancellation.receipt.observer_run && typeof cancellation.receipt.observer_run === 'object'
    && String(cancellation.observer_run_id) === String(cancellation.receipt.observer_run?.id)
    && cancellation.observer_attempt === cancellation.receipt.observer_run?.attempt
    && cancellation.observer_workflow_id === cancellation.receipt.observer_run?.workflow_id
    && /^https:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/[1-9][0-9]*$/.test(text(cancellation.receipt.observer_run?.url))
    && validTimestamp(cancellation.receipt.observer_run?.started_at)
    && validTimestamp(cancellation.receipt.observer_run?.observed_at)
    && cancellation.receipt.observer_run.url === `https://github.com/szTheory/sigra/actions/runs/${cancellation.receipt.observer_run.id}`
    && validTimestamp(failure.receipt.source_started_at) && validTimestamp(cancellation.receipt.source_started_at)
    && proof.credential_values_recorded === false;
  return {
    status: valid ? 'passed' : 'blocked',
    source_failure_receipts: failure?.receipt ? 1 : 0,
    source_cancellation_receipts: cancellation?.receipt ? 1 : 0,
    credential_values_recorded: proof?.credential_values_recorded ?? null,
    source_failure: failure ? { run_id: failure.run_id, attempt: failure.attempt, workflow_id: failure.workflow_id,
      workflow_path: failure.workflow_path, event: failure.event, ref: failure.ref, sha: failure.sha,
      conclusion: failure.conclusion, artifact: failure.artifact, receipt: failure.receipt } : null,
    source_cancellation: cancellation ? { run_id: cancellation.run_id, attempt: cancellation.attempt,
      workflow_id: cancellation.workflow_id, workflow_path: cancellation.workflow_path, event: cancellation.event,
      ref: cancellation.ref, sha: cancellation.sha, conclusion: cancellation.conclusion, artifact: cancellation.artifact,
      observer_run_id: cancellation.observer_run_id, observer_attempt: cancellation.observer_attempt,
      observer_workflow_id: cancellation.observer_workflow_id, observer_workflow_path: cancellation.observer_workflow_path,
      observer_event: cancellation.observer_event, observer_ref: cancellation.observer_ref,
      observer_conclusion: cancellation.observer_conclusion, receipt: cancellation.receipt } : null,
    retrieval: proof?.retrieval ?? null,
  };
}

export function captureCanaryTerminalReceipts({ producerProof, failureRun, cancellationRun, observerRun, failureArtifacts, cancellationArtifacts, downloadArtifactFn = downloadArtifact }) {
  const captureOne = ({ key, run, ownerRun, artifacts, receiptName, scenario, conclusion }) => {
    const record = producerProof?.[key];
    const expected = record?.artifact;
    const probe = record?.receipt?.probe_id;
    const expectedName = key === 'source_failure'
      ? `release-canary-failure-${run?.id}-${run?.attempt}-${probe}`
      : `release-canary-cancellation-${run?.id}-${run?.attempt}`;
    const list = Array.isArray(artifacts) ? artifacts : [];
    const matches = list.filter((item) => item?.id === expected?.id && item?.name === expectedName);
    if (!run || !ownerRun || !expected || matches.length !== 1) return { status: 'blocked', reason: 'terminal_artifact_identity_missing', receipt: null };
    const listed = matches[0];
    const listedOwner = listed.workflow_run?.id ?? listed.run_id;
    const expectedOwner = ownerRun.id;
    if (listed.expired !== false || listedOwner !== expectedOwner || listed.digest !== expected.digest
      || listed.expires_at !== expected.expires_at
      || expected.name !== expectedName || !/^sha256:[a-f0-9]{64}$/.test(text(expected.digest))) {
      return { status: 'blocked', reason: 'terminal_artifact_metadata_mismatch', receipt: null };
    }
    let downloaded;
    try {
      downloaded = downloadArtifactFn(expected.id, { receipt_name: receiptName, map_receipt: (receipt) => receipt });
    } catch {
      return { status: 'blocked', reason: 'terminal_artifact_download_failed', receipt: null };
    }
    const metadata = downloaded?.metadata;
    const retrieval = downloaded?.retrieval;
    const downloadedOwner = metadata?.workflow_run?.id ?? metadata?.run_id;
    const receipt = retrieval?.receipt;
    const sourceRef = run.branch ? `refs/heads/${run.branch}` : null;
    const downloadedMatches = metadata?.id === expected.id && metadata?.name === expectedName
      && metadata?.digest === expected.digest && metadata?.expired === false
      && metadata?.expires_at === expected.expires_at && downloadedOwner === expectedOwner;
    const sameAsProducer = canonicalJson(receipt) === canonicalJson(record.receipt);
    const receiptMatches = retrieval?.status === 'passed' && /^[a-f0-9]{64}$/.test(text(retrieval.sha256))
      && receipt?.schema_version === 1 && receipt?.receipt_kind === 'canary'
      && validProbeId(receipt?.probe_id) && receipt?.scenario === scenario && receipt?.terminal_verdict === conclusion
      && run.display_title === `release-receipt-canary-${scenario}-${receipt.probe_id}`
      && receipt?.source_repository === 'szTheory/sigra'
      && String(receipt?.source_run_id ?? '') === String(run.id) && receipt?.source_run_attempt === run.attempt
      && receipt?.source_workflow_id === run.workflow_id && receipt?.source_workflow_path === run.workflow_path
      && receipt?.source_workflow_name === run.workflow_name && receipt?.source_run_url === run.url
      && wholeSecond(receipt?.source_started_at) === wholeSecond(run.started_at)
      && validTimestamp(receipt?.source_observed_at) && validTimestamp(receipt?.recorded_at)
      && receipt?.source_event === run.event && receipt?.source_ref === sourceRef && receipt?.source_sha === run.head_sha;
    const observerMatches = key !== 'source_cancellation' || (String(receipt?.observer_run?.id ?? '') === String(ownerRun.id)
      && receipt?.observer_run?.attempt === ownerRun.attempt && receipt?.observer_run?.workflow_id === ownerRun.workflow_id
      && receipt?.observer_run?.url === ownerRun.url && wholeSecond(receipt?.observer_run?.started_at) === wholeSecond(ownerRun.started_at)
      && validTimestamp(receipt?.observer_run?.observed_at));
    if (!downloadedMatches || !sameAsProducer || !receiptMatches || !observerMatches) return { status: 'blocked', reason: 'terminal_receipt_identity_mismatch', receipt: null };
    return { status: 'passed', sha256: retrieval.sha256, artifact_id: metadata.id, artifact_name: metadata.name,
      artifact_digest: metadata.digest, receipt };
  };

  return {
    failureArtifactRetrieved: captureOne({ key: 'source_failure', run: failureRun, ownerRun: failureRun,
      artifacts: failureArtifacts, receiptName: 'canary-receipt.json', scenario: 'failure', conclusion: 'failure' }),
    cancellationArtifactRetrieved: captureOne({ key: 'source_cancellation', run: cancellationRun, ownerRun: observerRun,
      artifacts: cancellationArtifacts, receiptName: 'release-cancellation.json', scenario: 'cancellation', conclusion: 'cancelled' }),
  };
}

function captureSnapshot() {
  const proof = JSON.parse(readFileSync(PROOF_PATH, 'utf8'));
  const tagObject = ghJson('repos/szTheory/sigra/git/ref/tags/v1.6.0').object;
  const release = runMetadata(SUCCESS.releaseRunId);
  const ci = runMetadata(SUCCESS.ciRunId);
  const ciJobs = ghJson(`repos/szTheory/sigra/actions/runs/${SUCCESS.ciRunId}/jobs?per_page=100`).jobs ?? [];
  const ciGate = ciJobs.find((job) => job.name === 'ci-gate');
  const success = downloadArtifact(SUCCESS.successArtifactId, {
    receipt_name: 'release-result.json',
    map_receipt: (receipt) => ({
      verdict: receipt.terminal_verdict, tag: receipt.tag, source_sha: receipt.source_sha,
      release_run_id: Number(receipt.release_run_id), release_attempt: receipt.release_run_attempt,
      gate_run_id: Number(receipt.gate?.ci_run_id), gate_attempt: ci.attempt,
      gate_job_id: Number(ciGate?.id), gate_conclusion: receipt.gate?.verdict === 'pass' ? 'success' : receipt.gate?.verdict,
      gate_sha: receipt.gate?.head_sha,
    }),
  });
  const releaseAutomation = secretNames(['--env', 'release-automation']);
  const hexPublish = secretNames(['--env', 'hex-publish']);
  const repoSecrets = secretNames([]);
  const environments = {};
  for (const name of ['release-automation', 'hex-publish']) {
    const environment = ghJson(`repos/szTheory/sigra/environments/${name}`);
    const policies = ghJson(`repos/szTheory/sigra/environments/${name}/deployment-branch-policies`);
    environments[name] = {
      secret_names: name === 'release-automation' ? releaseAutomation : hexPublish,
      policy: {
        branch_names: onlyNames((policies.branch_policies ?? []).filter((row) => row.type === 'branch').map((row) => row.name)),
        can_admins_bypass: environment.can_admins_bypass,
        protected_branches: environment.deployment_branch_policy?.protected_branches,
        custom_branch_policies: environment.deployment_branch_policy?.custom_branch_policies,
      },
    };
  }
  const preflight = command('bash', ['scripts/ci/release-environment-preflight.sh', '--repository', 'szTheory/sigra',
    '--require-release-token', String(releaseAutomation.includes('RELEASE_PLEASE_TOKEN')),
    '--require-hex-dry-run-key', String(hexPublish.includes('HEX_DRY_RUN_API_KEY')),
    '--require-hex-publish-key', String(hexPublish.includes('HEX_API_KEY'))]);
  const controller = runMetadata(proof.controller_run.id);
  const controllerArtifact = artifactMetadata(proof.controller_run.artifact.id);
  const controllerArtifactDownload = downloadArtifact(proof.controller_run.artifact.id, {
    receipt_name: 'release-canary-proof.json',
    map_receipt: (receipt) => receipt,
  });
  const producerProof = normalizeControllerProof(controllerArtifactDownload.retrieval.receipt);
  const failureRunId = producerProof.source_failure?.run_id ?? proof.source_failure?.id;
  const cancellationRunId = producerProof.source_cancellation?.run_id ?? proof.source_cancellation?.run_id;
  const observerRunId = producerProof.source_cancellation?.observer_run_id ?? null;
  const sourceFailureArtifactRecords = failureRunId ? (ghJson(`repos/szTheory/sigra/actions/runs/${failureRunId}/artifacts?per_page=100`).artifacts ?? []) : [];
  const sourceFailure = failureRunId ? runMetadata(failureRunId) : null;
  const controllerProofPath = join(ROOT, PHASE_DIR, proof.controller_proof_file);
  const controllerLocalSha = sha256(readFileSync(controllerProofPath));
  const sourceCancellation = cancellationRunId ? runMetadata(cancellationRunId) : null;
  const observer = observerRunId ? runMetadata(observerRunId) : null;
  const cancellationArtifactRecords = observer
    ? (ghJson(`repos/szTheory/sigra/actions/runs/${observer.id}/artifacts?per_page=100`).artifacts ?? [])
    : [];
  const terminalReceiptCaptures = captureCanaryTerminalReceipts({ producerProof,
    failureRun: sourceFailure, cancellationRun: sourceCancellation, observerRun: observer,
    failureArtifacts: sourceFailureArtifactRecords, cancellationArtifacts: cancellationArtifactRecords });
  const sourceFailureArtifacts = sourceFailureArtifactRecords.map((item) => ({ id: item.id, name: item.name, digest: item.digest, expired: item.expired, expires_at: item.expires_at, run_id: item.workflow_run?.id ?? null }));
  const cancellationArtifacts = cancellationArtifactRecords.map((item) => ({ id: item.id, name: item.name, digest: item.digest, expired: item.expired, expires_at: item.expires_at, run_id: item.workflow_run?.id ?? null }));
  const snapshot = {
    schema_version: 1,
    captured_at: new Date().toISOString(),
    repository: 'szTheory/sigra',
    tag: { name: SUCCESS.tag, object_sha: tagObject.sha, object_type: tagObject.type, target_sha: tagObject.type === 'tag' ? ghJson(`repos/szTheory/sigra/git/tags/${tagObject.sha}`).object.sha : tagObject.sha },
    release_run: release,
    ci_run: { ...ci, job: ciGate ? { id: ciGate.id, name: ciGate.name, head_sha: ciGate.head_sha, conclusion: ciGate.conclusion, run_attempt: ciGate.run_attempt } : null },
    success_artifact: { ...success.metadata, run_id: success.metadata.workflow_run?.id ?? null, retrieved: success.retrieval },
    environments,
    repository_secret_names: repoSecrets,
    preflight: { exit_code: preflight.status, output: text(preflight.stdout).trim().split(/\r?\n/).filter(Boolean), error: preflight.status === 0 ? null : 'environment_preflight_failed' },
    canary: {
      proof_status: proof.status,
      proof_sha256: sha256(readFileSync(PROOF_PATH)),
      proof_captured_at: proof.captured_at,
      proof_reason: proof.reason,
      source_sha: proof.source_failure.sha,
      controller: { expected_id: proof.controller_run.id, expected_attempt: proof.controller_run.attempt, expected_workflow_id: proof.controller_run.workflow_id, expected_artifact_id: proof.controller_run.artifact.id, run: controller, artifact: { ...controllerArtifact, retrieved: controllerArtifactDownload.retrieval }, proof_file_sha256: controllerArtifactDownload.retrieval.sha256, expected_proof_sha256: proof.controller_run.artifact.proof_sha256, local_proof_file_sha256: controllerLocalSha },
      failure: { expected_id: failureRunId ?? null, expected_attempt: producerProof.source_failure?.attempt ?? proof.source_failure?.attempt ?? null, run: sourceFailure, controlled_failure_step_conclusion: proof.source_failure?.controlled_failure_step_conclusion ?? null, receipt_job_conclusion: proof.source_failure?.receipt_job_conclusion ?? null, artifacts: sourceFailureArtifacts, artifact_retrieved: terminalReceiptCaptures.failureArtifactRetrieved },
      cancellation: { expected_id: cancellationRunId ?? null, run: sourceCancellation, proof_dispatch_attempted: proof.source_cancellation?.dispatch_attempted ?? Boolean(producerProof.source_cancellation), proof_reason: proof.source_cancellation?.reason ?? null, artifacts: cancellationArtifacts,
        observer: observer ? { run_id: observer.id, attempt: observer.attempt, workflow_id: observer.workflow_id, workflow_path: observer.workflow_path?.replace(/@.*$/, ''), event: observer.event, ref: `refs/heads/${observer.branch}`, source_sha: producerProof.source_cancellation?.sha, conclusion: observer.conclusion, event_source_run_id: cancellationRunId } : null,
        artifact_retrieved: terminalReceiptCaptures.cancellationArtifactRetrieved },
      controller_proof: producerProof,
      credential_values_recorded: proof.credential_values_recorded ?? null,
    },
  };
  const evaluation = evaluateSnapshot(snapshot);
  snapshot.requirements = evaluation.requirements;
  snapshot.blockers = evaluation.blockers;
  const temp = `${SNAPSHOT_PATH}.tmp-${process.pid}`;
  writeFileSync(temp, `${JSON.stringify(snapshot, null, 2)}\n`, { mode: 0o600 });
  renameSync(temp, SNAPSHOT_PATH);
  return snapshot;
}

function validateSuccess(snapshot) {
  const blockers = [];
  const { tag, release_run: release, ci_run: ci, success_artifact: artifact } = snapshot;
  if (tag?.name !== SUCCESS.tag || tag?.target_sha !== SUCCESS.sourceSha) blockers.push('exact release tag/source SHA mismatch');
  if (release?.id !== SUCCESS.releaseRunId || release?.attempt !== SUCCESS.releaseAttempt || release?.workflow_path !== '.github/workflows/release-please.yml' || release?.event !== 'push' || release?.branch !== 'main' || release?.head_sha !== SUCCESS.sourceSha || release?.conclusion !== 'success') blockers.push('recorded Release Please run identity or conclusion mismatch');
  if (ci?.id !== SUCCESS.ciRunId || ci?.attempt !== SUCCESS.ciAttempt || ci?.workflow_path !== '.github/workflows/ci.yml' || ci?.head_sha !== SUCCESS.sourceSha || ci?.conclusion !== 'success') blockers.push('recorded exact-source CI run mismatch');
  if (ci?.job?.id !== SUCCESS.ciGateJobId || ci?.job?.name !== 'ci-gate' || ci?.job?.head_sha !== SUCCESS.sourceSha || ci?.job?.conclusion !== 'success' || ci?.job?.run_attempt !== SUCCESS.ciAttempt) blockers.push('recorded ci-gate job identity mismatch');
  if (artifact?.id !== SUCCESS.successArtifactId || artifact?.name !== `release-result-1.6.0-${SUCCESS.releaseRunId}` || artifact?.run_id !== SUCCESS.releaseRunId || artifact?.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(artifact?.digest))) blockers.push('success artifact identity, ownership, digest, or retention mismatch');
  const retrieved = artifact?.retrieved;
  const receipt = retrieved?.receipt;
  if (retrieved?.status !== 'passed' || !/^[a-f0-9]{64}$/.test(text(retrieved?.sha256))) blockers.push('retrieved success artifact content digest validation mismatch');
  if (receipt?.verdict !== 'success' || receipt?.tag !== SUCCESS.tag || receipt?.source_sha !== SUCCESS.sourceSha || receipt?.release_run_id !== SUCCESS.releaseRunId || receipt?.release_attempt !== SUCCESS.releaseAttempt) blockers.push('retrieved success receipt Release Please identity mismatch');
  if (receipt?.gate_run_id !== SUCCESS.ciRunId || receipt?.gate_attempt !== SUCCESS.ciAttempt || receipt?.gate_job_id !== SUCCESS.ciGateJobId || receipt?.gate_conclusion !== 'success' || receipt?.gate_sha !== SUCCESS.sourceSha) blockers.push('retrieved success receipt CI gate identity mismatch');
  return blockers;
}

function evaluateSnapshot(snapshot) {
  const blockers = [];
  if (snapshot?.schema_version !== 1 || snapshot?.repository !== 'szTheory/sigra' || !/^\d{4}-\d\d-\d\dT/.test(text(snapshot?.captured_at))) blockers.push('snapshot schema, repository, or capture time is invalid');
  if (containsCredentialValue(snapshot)) blockers.push('snapshot contains a credential-value field or claims credential values were recorded');
  const auto01 = [...blockers];
  const required = { 'release-automation': ['RELEASE_PLEASE_TOKEN'], 'hex-publish': ['HEX_DRY_RUN_API_KEY', 'HEX_API_KEY'] };
  for (const [environment, names] of Object.entries(required)) {
    const observed = onlyNames(snapshot?.environments?.[environment]?.secret_names);
    for (const name of names) if (!observed.includes(name)) auto01.push(`${environment} is missing required environment secret name ${name}`);
    const policy = snapshot?.environments?.[environment]?.policy;
    if (!same(onlyNames(policy?.branch_names), ['main']) || policy?.can_admins_bypass !== false || policy?.protected_branches !== false || policy?.custom_branch_policies !== true) auto01.push(`${environment} deployment policy must allow only main with admin bypass disabled`);
  }
  if (onlyNames(snapshot?.repository_secret_names).length) auto01.push('repository-level secret names are present');
  if (snapshot?.preflight?.exit_code !== 0) auto01.push('live release environment preflight did not pass');
  auto01.push(...validateSuccess(snapshot));

  const auto02 = [];
  const canary = snapshot?.canary;
  if (canary?.proof_status !== 'passed') auto02.push(`hosted canary proof is ${text(canary?.proof_status) || 'missing'}; a blocked proof cannot establish terminal receipts`);
  if (!/^[a-f0-9]{64}$/.test(text(canary?.proof_sha256))) auto02.push('canary proof digest is missing or malformed');
  if (canary?.credential_values_recorded !== false || canary?.controller_proof?.credential_values_recorded !== false) auto02.push('canary evidence does not establish that credential values were excluded');
  if (canary?.controller?.run?.id !== canary?.controller?.expected_id || canary?.controller?.run?.attempt !== canary?.controller?.expected_attempt || canary?.controller?.run?.conclusion !== 'success' || canary?.controller?.run?.workflow_path !== '.github/workflows/release-receipt-canary-controller.yml' || canary?.controller?.run?.head_sha !== canary?.source_sha) auto02.push('controller run identity or conclusion mismatch');
  const controllerArtifact = canary?.controller?.artifact;
  if (canary?.controller?.run?.event !== 'workflow_dispatch' || canary?.controller?.run?.branch !== 'main' || canary?.controller?.run?.workflow_id !== canary?.controller?.expected_workflow_id) auto02.push('controller run event, branch, or workflow ID mismatch');
  if (!Number.isInteger(controllerArtifact?.id) || controllerArtifact?.id !== canary?.controller?.expected_artifact_id || controllerArtifact?.run_id !== canary?.controller?.expected_id || controllerArtifact?.name !== `release-canary-controller-${canary?.controller?.expected_id}-${canary?.controller?.expected_attempt}` || controllerArtifact?.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(controllerArtifact?.digest)) || controllerArtifact?.retrieved?.status !== 'passed' || canary?.controller?.proof_file_sha256 !== canary?.controller?.expected_proof_sha256 || canary?.controller?.local_proof_file_sha256 !== canary?.controller?.expected_proof_sha256) auto02.push('controller proof artifact identity, digest, or retrieval validation mismatch');
  if (canary?.controller_proof?.status !== 'passed' || canary?.controller_proof?.source_failure_receipts !== 1 || canary?.controller_proof?.source_cancellation_receipts !== 1) auto02.push('controller proof does not contain both validated producer receipts');
  const producerFailure = canary?.controller_proof?.source_failure;
  const producerCancellation = canary?.controller_proof?.source_cancellation;
  const failure = canary?.failure;
  const cancellation = canary?.cancellation;
  if (!failure?.run || failure.run.id !== failure.expected_id || failure.run.attempt !== failure.expected_attempt || failure.run.workflow_path !== '.github/workflows/release-receipt-canary.yml' || failure.run.head_sha !== canary.source_sha || failure.run.conclusion !== 'failure') auto02.push('failure canary run identity or controlled failure conclusion mismatch');
  if (String(producerFailure?.run_id ?? '') !== String(failure?.expected_id ?? '') || producerFailure?.attempt !== failure?.expected_attempt || producerFailure?.workflow_id !== failure?.run?.workflow_id || producerFailure?.workflow_path !== failure?.run?.workflow_path || producerFailure?.event !== failure?.run?.event || producerFailure?.ref !== `refs/heads/${failure?.run?.branch}` || producerFailure?.sha !== canary?.source_sha || producerFailure?.conclusion !== 'failure') auto02.push('controller producer failure record does not join the authoritative run metadata');
  const failureArtifacts = Array.isArray(failure?.artifacts) ? failure.artifacts : [];
  const failureProbe = producerFailure?.receipt?.probe_id;
  if (!validProbeId(failureProbe) || producerFailure?.receipt?.schema_version !== 1
    || producerFailure?.receipt?.receipt_kind !== 'canary' || producerFailure?.receipt?.scenario !== 'failure'
    || producerFailure?.receipt?.terminal_verdict !== 'failure'
    || failure?.run?.display_title !== `release-receipt-canary-failure-${failureProbe}`) auto02.push('producer failure receipt has an invalid canary identity');
  const cancellationProbe = producerCancellation?.receipt?.probe_id;
  if (!validProbeId(cancellationProbe) || cancellationProbe === failureProbe
    || producerCancellation?.receipt?.schema_version !== 1 || producerCancellation?.receipt?.receipt_kind !== 'canary'
    || producerCancellation?.receipt?.scenario !== 'cancellation'
    || producerCancellation?.receipt?.terminal_verdict !== 'cancelled'
    || cancellation?.run?.display_title !== `release-receipt-canary-cancellation-${cancellationProbe}`) auto02.push('producer cancellation receipt has an invalid canary identity');
  const failureArtifact = failureArtifacts.find((item) => String(item.run_id) === String(failure?.expected_id) && item.name === `release-canary-failure-${failure.expected_id}-${failure.expected_attempt}-${failureProbe}`);
  if (!failureArtifact || failureArtifact.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(failureArtifact.digest))) auto02.push('failure artifact is missing, expired, or has a malformed digest');
  if (producerFailure?.artifact?.id !== failureArtifact?.id || producerFailure?.artifact?.name !== failureArtifact?.name
    || producerFailure?.artifact?.digest !== failureArtifact?.digest || producerFailure?.artifact?.expires_at !== failureArtifact?.expires_at) auto02.push('producer failure artifact does not join the authoritative artifact listing');
  if (!cancellation?.run || cancellation.run.id !== cancellation.expected_id || cancellation.run.workflow_path !== '.github/workflows/release-receipt-canary.yml' || cancellation.run.head_sha !== canary.source_sha || cancellation.run.conclusion !== 'cancelled') auto02.push('cancellation source run is missing or mismatched');
  if (String(producerCancellation?.run_id ?? '') !== String(cancellation?.expected_id ?? '') || producerCancellation?.attempt !== cancellation?.run?.attempt || producerCancellation?.workflow_id !== cancellation?.run?.workflow_id || producerCancellation?.workflow_path !== cancellation?.run?.workflow_path || producerCancellation?.event !== cancellation?.run?.event || producerCancellation?.ref !== `refs/heads/${cancellation?.run?.branch}` || producerCancellation?.sha !== canary?.source_sha || producerCancellation?.conclusion !== 'cancelled') auto02.push('controller producer cancellation record does not join the authoritative run metadata');
  if (cancellation?.observer?.workflow_path !== '.github/workflows/release-run-observer.yml' || cancellation.observer.event_source_run_id !== cancellation.expected_id || cancellation.observer.source_sha !== canary.source_sha || cancellation.observer.conclusion !== 'success') auto02.push('cancellation observer identity or conclusion mismatch');
  if (String(producerCancellation?.observer_run_id ?? '') !== String(cancellation?.observer?.run_id ?? '') || producerCancellation?.observer_attempt !== cancellation?.observer?.attempt || producerCancellation?.observer_workflow_id !== cancellation?.observer?.workflow_id || producerCancellation?.observer_workflow_path !== cancellation?.observer?.workflow_path || producerCancellation?.observer_event !== cancellation?.observer?.event || producerCancellation?.observer_ref !== cancellation?.observer?.ref || producerCancellation?.observer_conclusion !== cancellation?.observer?.conclusion) auto02.push('producer observer identity fields do not join the authoritative observer run metadata');
  if (String(producerCancellation?.receipt?.observer_run?.id ?? '') !== String(producerCancellation?.observer_run_id ?? '') || producerCancellation?.receipt?.observer_run?.attempt !== producerCancellation?.observer_attempt || producerCancellation?.receipt?.observer_run?.workflow_id !== producerCancellation?.observer_workflow_id) auto02.push('embedded cancellation receipt observer identity mismatch');
  if (producerFailure?.receipt?.observer_run !== null) auto02.push('failure receipt unexpectedly contains an observer run');
  if (String(producerFailure?.receipt?.source_run_id ?? '') !== String(producerFailure?.run_id ?? '') || producerFailure?.receipt?.source_run_attempt !== producerFailure?.attempt
    || String(producerCancellation?.receipt?.source_run_id ?? '') !== String(producerCancellation?.run_id ?? '') || producerCancellation?.receipt?.source_run_attempt !== producerCancellation?.attempt
    || producerFailure?.receipt?.source_repository !== 'szTheory/sigra' || producerCancellation?.receipt?.source_repository !== 'szTheory/sigra') auto02.push('producer receipt source identity fields do not join their run records');
  const cancellationArtifacts = Array.isArray(cancellation?.artifacts) ? cancellation.artifacts : [];
  const cancellationArtifact = cancellationArtifacts.find((item) => String(item.run_id) === String(cancellation?.observer?.run_id) && item.name === `release-canary-cancellation-${cancellation.expected_id}-${cancellation.run?.attempt}`);
  if (!cancellationArtifact || cancellationArtifact.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(cancellationArtifact.digest))) auto02.push('observer cancellation artifact is missing, expired, or has a malformed digest');
  if (producerCancellation?.artifact?.id !== cancellationArtifact?.id || producerCancellation?.artifact?.name !== cancellationArtifact?.name
    || producerCancellation?.artifact?.digest !== cancellationArtifact?.digest || producerCancellation?.artifact?.expires_at !== cancellationArtifact?.expires_at) auto02.push('producer cancellation artifact does not join the authoritative artifact listing');
  const failureRetrieved = failure?.artifact_retrieved;
  if (failureRetrieved?.status !== 'passed' || !/^[a-f0-9]{64}$/.test(text(failureRetrieved?.sha256))
    || failureRetrieved?.artifact_id !== failureArtifact?.id || failureRetrieved?.artifact_name !== failureArtifact?.name
    || failureRetrieved?.artifact_digest !== failureArtifact?.digest
    || String(failureRetrieved?.receipt?.source_run_id ?? '') !== String(failure?.expected_id ?? '')
    || failureRetrieved?.receipt?.source_run_attempt !== failure?.expected_attempt
    || failureRetrieved?.receipt?.source_workflow_id !== failure?.run?.workflow_id
    || failureRetrieved?.receipt?.source_workflow_path !== '.github/workflows/release-receipt-canary.yml'
    || failureRetrieved?.receipt?.source_event !== failure?.run?.event
    || failureRetrieved?.receipt?.source_ref !== `refs/heads/${failure?.run?.branch}`
    || failureRetrieved?.receipt?.source_sha !== canary?.source_sha
    || canonicalJson(failureRetrieved?.receipt) !== canonicalJson(producerFailure?.receipt)
    || failureRetrieved?.receipt?.schema_version !== 1 || failureRetrieved?.receipt?.receipt_kind !== 'canary'
    || !validProbeId(failureRetrieved?.receipt?.probe_id) || failureRetrieved?.receipt?.scenario !== 'failure'
    || failureRetrieved?.receipt?.source_repository !== 'szTheory/sigra'
    || failureRetrieved?.receipt?.source_workflow_name !== failure?.run?.workflow_name
    || failureRetrieved?.receipt?.source_run_url !== failure?.run?.url
    || wholeSecond(failureRetrieved?.receipt?.source_started_at) !== wholeSecond(failure?.run?.started_at)
    || !validTimestamp(failureRetrieved?.receipt?.source_observed_at) || !validTimestamp(failureRetrieved?.receipt?.recorded_at)
    || failureRetrieved?.receipt?.observer_run !== null || failureRetrieved?.receipt?.terminal_verdict !== 'failure') auto02.push('retrieved failure receipt identity or digest validation mismatch');
  const cancellationRetrieved = cancellation?.artifact_retrieved;
  if (cancellationRetrieved?.status !== 'passed' || !/^[a-f0-9]{64}$/.test(text(cancellationRetrieved?.sha256))
    || cancellationRetrieved?.artifact_id !== cancellationArtifact?.id || cancellationRetrieved?.artifact_name !== cancellationArtifact?.name
    || cancellationRetrieved?.artifact_digest !== cancellationArtifact?.digest
    || String(cancellationRetrieved?.receipt?.source_run_id ?? '') !== String(cancellation?.expected_id ?? '')
    || cancellationRetrieved?.receipt?.source_run_attempt !== cancellation?.run?.attempt
    || cancellationRetrieved?.receipt?.source_workflow_id !== cancellation?.run?.workflow_id
    || cancellationRetrieved?.receipt?.source_workflow_path !== '.github/workflows/release-receipt-canary.yml'
    || cancellationRetrieved?.receipt?.source_event !== cancellation?.run?.event
    || cancellationRetrieved?.receipt?.source_ref !== `refs/heads/${cancellation?.run?.branch}`
    || cancellationRetrieved?.receipt?.source_sha !== canary?.source_sha
    || canonicalJson(cancellationRetrieved?.receipt) !== canonicalJson(producerCancellation?.receipt)
    || cancellationRetrieved?.receipt?.schema_version !== 1 || cancellationRetrieved?.receipt?.receipt_kind !== 'canary'
    || !validProbeId(cancellationRetrieved?.receipt?.probe_id) || cancellationRetrieved?.receipt?.scenario !== 'cancellation'
    || cancellationRetrieved?.receipt?.source_repository !== 'szTheory/sigra'
    || cancellationRetrieved?.receipt?.source_workflow_name !== cancellation?.run?.workflow_name
    || cancellationRetrieved?.receipt?.source_run_url !== cancellation?.run?.url
    || wholeSecond(cancellationRetrieved?.receipt?.source_started_at) !== wholeSecond(cancellation?.run?.started_at)
    || !validTimestamp(cancellationRetrieved?.receipt?.source_observed_at) || !validTimestamp(cancellationRetrieved?.receipt?.recorded_at)
    || String(cancellationRetrieved?.receipt?.observer_run?.id ?? '') !== String(cancellation?.observer?.run_id ?? '')
    || cancellationRetrieved?.receipt?.observer_run?.attempt !== cancellation?.observer?.attempt
    || cancellationRetrieved?.receipt?.observer_run?.workflow_id !== cancellation?.observer?.workflow_id
    || cancellationRetrieved?.receipt?.observer_run?.url !== cancellation?.observer?.url
    || wholeSecond(cancellationRetrieved?.receipt?.observer_run?.started_at) !== wholeSecond(cancellation?.observer?.started_at)
    || !validTimestamp(cancellationRetrieved?.receipt?.observer_run?.observed_at)
    || cancellationRetrieved?.receipt?.terminal_verdict !== 'cancelled') auto02.push('retrieved cancellation receipt identity or digest validation mismatch');
  auto02.push(...validateSuccess(snapshot).map((item) => `established success path: ${item}`));

  const requirements = {
    'AUTO-01': req('satisfied', auto01),
    'AUTO-02': req('satisfied', auto02),
  };
  return { requirements, blockers: [...auto01.map((item) => `AUTO-01: ${item}`), ...auto02.map((item) => `AUTO-02: ${item}`)] };
}

function containsCredentialValue(value) {
  if (!value || typeof value !== 'object') return false;
  return Object.entries(value).some(([key, item]) => /^(?:secret|credential)_values?$/i.test(key)
    || (key === 'credential_values_recorded' && item !== false)
    || containsCredentialValue(item));
}

function reportIdentity(snapshot) {
  return {
    requirements: Object.fromEntries(Object.entries(snapshot.requirements ?? {}).map(([key, value]) => [key, value.status])),
    tag: snapshot.tag?.name ?? null,
    source_sha: snapshot.tag?.target_sha ?? null,
    release_run_id: snapshot.release_run?.id ?? null,
    ci_run_id: snapshot.ci_run?.id ?? null,
    ci_gate_job_id: snapshot.ci_run?.job?.id ?? null,
    failure_run_id: snapshot.canary?.failure?.run?.id ?? null,
    cancellation_run_id: snapshot.canary?.cancellation?.run?.id ?? null,
    failure_artifact_id: snapshot.canary?.failure?.artifacts?.[0]?.id ?? null,
    cancellation_artifact_id: snapshot.canary?.cancellation?.artifacts?.[0]?.id ?? null,
  };
}

function checkReport(report, snapshot, evaluation = evaluateSnapshot(snapshot)) {
  const errors = [];
  if (!report.includes('2026-10-08') || !report.includes('gaps_found')) errors.push('historical_gap_classification_missing');
  const match = report.match(/<!-- phase248-evidence ([^\n]+) -->/);
  if (!match) return [...errors, 'report_evidence_identity_missing'];
  let embedded;
  try { embedded = JSON.parse(match[1]); } catch { return [...errors, 'report_evidence_identity_invalid']; }
  const current = reportIdentity({ ...snapshot, requirements: evaluation.requirements });
  const normalized = { ...embedded };
  for (const key of Object.keys(current)) if (!(key in normalized)) normalized[key] = null;
  if (!same(normalized, current)) errors.push('report_source_identity_mismatch');
  const expected = Object.fromEntries(Object.entries(evaluation.requirements).map(([key, value]) => [key, value.status]));
  if (!same(embedded.requirements, expected)) errors.push('report_requirement_mismatch');
  return errors;
}

function writeReport(snapshot) {
  const evaluation = evaluateSnapshot(snapshot);
  snapshot.requirements = evaluation.requirements;
  snapshot.blockers = evaluation.blockers;
  const identity = reportIdentity(snapshot);
  const reportPath = join(ROOT, '.planning/phases/248-exact-source-release-gate/248-VERIFICATION.md');
  const old = readFileSync(reportPath, 'utf8');
  const historical = old.slice(old.indexOf('## Goal Achievement'));
  const lines = [
    '---', 'phase: 248-exact-source-release-gate', `verified: ${snapshot.captured_at}`, 'status: gaps_found',
    `source_snapshot: ${PHASE_DIR}/250-248-SOURCE-SNAPSHOT.json`, 'owner_requirements: [AUTO-01, AUTO-02]', '---', '',
    '# Phase 248: Exact-Source Release Gate Verification Report', '',
    '**Phase Goal:** Maintainers can prove the existing release lane evaluated the exact source that it will publish and can diagnose every result.',
    `**Verified:** ${snapshot.captured_at}`, '**Status:** gaps_found', '**Re-verification:** Yes — refreshed from recorded source IDs and current protected-environment metadata.', '',
    `<!-- phase248-evidence ${JSON.stringify(identity)} -->`, '',
    '## Current Evidence Boundary', '',
    `- **AUTO-01: ${evaluation.requirements['AUTO-01'].status}.** Environment names and main-only policy metadata were independently queried; repository-level secret names were absent. The live name-only preflight ${snapshot.preflight.exit_code === 0 ? 'passed' : 'failed'}. Tag ${snapshot.tag.name} resolves to ${snapshot.tag.target_sha}; Release Please run ${snapshot.release_run.id} attempt ${snapshot.release_run.attempt} and ci-gate job ${snapshot.ci_run.job?.id ?? 'missing'} in CI run ${snapshot.ci_run.id} were checked against that exact source. The retained success artifact is ${snapshot.success_artifact.id} (${snapshot.success_artifact.name}); retrieval and receipt identity validation ${snapshot.success_artifact.retrieved.status === 'passed' ? 'passed' : 'failed'}.`,
    `- **AUTO-02: ${evaluation.requirements['AUTO-02'].status}.** The authorized hosted canary proof is ${snapshot.canary.proof_status} (${snapshot.canary.proof_reason ?? 'no blocker recorded'}). Failure source run ${snapshot.canary.failure.run?.id ?? 'missing'} conclusion: ${snapshot.canary.failure.run?.conclusion ?? 'missing'}; matching failure artifact: ${snapshot.canary.failure.artifacts?.length ? snapshot.canary.failure.artifacts.map((item) => `#${item.id} ${item.name}`).join(', ') : 'none'}. Cancellation source run: ${snapshot.canary.cancellation.run?.id ?? 'not dispatched'}; observer artifact: ${snapshot.canary.cancellation.artifacts?.length ? snapshot.canary.cancellation.artifacts.map((item) => `#${item.id} ${item.name}`).join(', ') : 'none'}. The blocked proof has no validated failure or cancellation receipt, so a success receipt cannot satisfy AUTO-02.`,
    '', '## Current Blockers', '', ...evaluation.blockers.map((item) => `- ${item}`), '',
    '## Historical verification (2026-10-08)', '',
    'The earlier `gaps_found` result remains the historical record: protected environment names were absent then, and hosted failure/cancellation artifact retrieval had not been observed. Current environment metadata closes the environment-name/policy gap; the canary run remains blocked and does not close the hosted terminal-receipt gap.', '',
    historical,
  ];
  writeFileSync(reportPath, `${lines.join('\n').trimEnd()}\n`);
  return reportPath;
}

function main() {
  const args = process.argv.slice(2);
  if (args[0] === '--capture') {
    const snapshot = captureSnapshot();
    console.log(JSON.stringify({ captured: SNAPSHOT_PATH, requirements: snapshot.requirements }, null, 2));
    return;
  }
  const snapshot = JSON.parse(readFileSync(SNAPSHOT_PATH, 'utf8'));
  if (args[0] === '--check-report') {
    const report = readFileSync(args[1], 'utf8');
    const errors = checkReport(report, snapshot);
    if (errors.length) { console.error(JSON.stringify({ status: 'fail', errors })); process.exitCode = 1; return; }
    console.log(JSON.stringify({ status: 'pass', requirements: snapshot.requirements, source_sha: snapshot.tag.target_sha }));
    return;
  }
  if (args[0] === '--write-report') {
    console.log(JSON.stringify({ report: writeReport(snapshot), requirements: snapshot.requirements }, null, 2));
    return;
  }
  const result = evaluateSnapshot(snapshot);
  console.log(JSON.stringify(result, null, 2));
  if (result.blockers.length) process.exitCode = 1;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) main();

export { evaluateSnapshot, checkReport, reportIdentity };
