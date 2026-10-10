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
const CONTROLLER_PROOF_PATH = join(ROOT, PHASE_DIR, '250-CANARY-CONTROLLER-PROOF-38059620443.json');
const SUCCESS = {
  tag: 'v1.6.0', sourceSha: '9e80cb78d6374b1ed4074d5fef6b613fee879dca',
  releaseRunId: 37875238705, releaseAttempt: 3, ciRunId: 37875238741, ciAttempt: 2,
  ciGateJobId: 113654406257, successArtifactId: 11594782728,
};

const text = (value) => typeof value === 'string' ? value : '';
const sha256 = (data) => createHash('sha256').update(data).digest('hex');
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const req = (status, blockers) => ({ status: blockers.length ? 'unsatisfied' : status, blockers });

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

function downloadArtifact(artifactId, expected) {
  const metadata = ghJson(`repos/szTheory/sigra/actions/artifacts/${artifactId}`);
  const result = command('gh', ['api', `repos/szTheory/sigra/actions/artifacts/${artifactId}/zip`], { encoding: null });
  if (result.status !== 0 || !Buffer.isBuffer(result.stdout)) return { metadata, retrieval: { status: 'failed', reason: 'artifact_download_failed' } };
  const bytes = result.stdout;
  const actualDigest = `sha256:${sha256(bytes)}`;
  const retrieval = { status: 'passed', sha256: '', receipt: null };
  if (metadata.digest !== actualDigest) return { metadata, retrieval: { status: 'failed', reason: 'artifact_digest_mismatch', observed_digest: actualDigest } };

  const zipPath = join(tmpdir(), `sigra-artifact-${process.pid}-${artifactId}.zip`);
  try {
    writeFileSync(zipPath, bytes, { flag: 'wx', mode: 0o600 });
    const listing = command('unzip', ['-Z1', zipPath]);
    if (listing.status !== 0) return { metadata, retrieval: { status: 'failed', reason: 'artifact_archive_invalid' } };
    const names = listing.stdout.split(/\r?\n/).filter(Boolean);
    const jsonName = names.find((name) => name === expected.receipt_name || name.endsWith(`/${expected.receipt_name}`));
    if (!jsonName) return { metadata, retrieval: { status: 'failed', reason: 'artifact_receipt_missing' } };
    const extracted = command('unzip', ['-p', zipPath, jsonName]);
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
    id: run.id, attempt: run.run_attempt, workflow_id: run.workflow_id, workflow_path: run.path,
    event: run.event, branch: run.head_branch, head_sha: run.head_sha,
    status: run.status, conclusion: run.conclusion, created_at: run.created_at, updated_at: run.updated_at,
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
  const sourceFailure = runMetadata(proof.source_failure.id);
  const controllerArtifact = artifactMetadata(proof.controller_run.artifact.id);
  const controllerArtifactDownload = downloadArtifact(proof.controller_run.artifact.id, {
    receipt_name: 'release-canary-proof.json',
    map_receipt: (receipt) => ({ status: receipt.status, receipts: receipt.receipts?.length ?? 0, credential_values_recorded: receipt.credential_values_recorded ?? null }),
  });
  const sourceFailureArtifacts = ghJson(`repos/szTheory/sigra/actions/runs/${proof.source_failure.id}/artifacts?per_page=100`).artifacts ?? [];
  const controllerLocalSha = sha256(readFileSync(CONTROLLER_PROOF_PATH));
  const sourceCancellation = proof.source_cancellation?.run_id ? runMetadata(proof.source_cancellation.run_id) : null;
  const cancellationArtifacts = sourceCancellation
    ? (ghJson(`repos/szTheory/sigra/actions/runs/${sourceCancellation.id}/artifacts?per_page=100`).artifacts ?? []).map((item) => ({ id: item.id, name: item.name, digest: item.digest, expired: item.expired, run_id: item.workflow_run?.id ?? null }))
    : [];
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
      controller: { expected_id: proof.controller_run.id, expected_attempt: proof.controller_run.attempt, run: controller, artifact: { ...controllerArtifact, retrieved: controllerArtifactDownload.retrieval }, proof_file_sha256: controllerArtifactDownload.retrieval.sha256, expected_proof_sha256: proof.controller_run.artifact.proof_sha256, local_proof_file_sha256: controllerLocalSha },
      failure: { expected_id: proof.source_failure.id, expected_attempt: proof.source_failure.attempt, run: sourceFailure, controlled_failure_step_conclusion: proof.source_failure.controlled_failure_step_conclusion, receipt_job_conclusion: proof.source_failure.receipt_job_conclusion, artifacts: sourceFailureArtifacts.map((item) => ({ id: item.id, name: item.name, digest: item.digest, expired: item.expired, run_id: item.workflow_run?.id ?? null })) },
      cancellation: { expected_id: proof.source_cancellation?.run_id ?? null, run: sourceCancellation, proof_dispatch_attempted: proof.source_cancellation?.dispatch_attempted ?? false, proof_reason: proof.source_cancellation?.reason ?? null, artifacts: cancellationArtifacts },
      controller_proof: { status: controllerArtifactDownload.retrieval.receipt?.status ?? null, source_failure_receipts: controllerArtifactDownload.retrieval.receipt?.receipts ?? 0, credential_values_recorded: controllerArtifactDownload.retrieval.receipt?.credential_values_recorded ?? null },
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
  if (controllerArtifact?.id !== 11671884954 || controllerArtifact?.run_id !== canary?.controller?.expected_id || controllerArtifact?.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(controllerArtifact?.digest)) || controllerArtifact?.retrieved?.status !== 'passed' || canary?.controller?.proof_file_sha256 !== canary?.controller?.expected_proof_sha256 || canary?.controller?.local_proof_file_sha256 !== canary?.controller?.expected_proof_sha256) auto02.push('controller proof artifact identity, digest, or retrieval validation mismatch');
  if (canary?.controller_proof?.status !== 'passed' || canary?.controller_proof?.source_failure_receipts !== 1) auto02.push('controller proof does not contain a validated failure receipt');
  const failure = canary?.failure;
  if (!failure?.run || failure.run.id !== failure.expected_id || failure.run.attempt !== failure.expected_attempt || failure.run.workflow_path !== '.github/workflows/release-receipt-canary.yml' || failure.run.head_sha !== canary.source_sha || failure.run.conclusion !== 'failure') auto02.push('failure canary run identity or controlled failure conclusion mismatch');
  const failureArtifacts = Array.isArray(failure?.artifacts) ? failure.artifacts : [];
  const failureArtifact = failureArtifacts.find((item) => item.run_id === failure?.expected_id && item.name === `release-canary-failure-${failure.expected_id}-${failure.expected_attempt}`);
  if (!failureArtifact || failureArtifact.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(failureArtifact.digest))) auto02.push('failure artifact is missing, expired, or has a malformed digest');
  const cancellation = canary?.cancellation;
  if (!cancellation?.run || cancellation.run.id !== cancellation.expected_id || cancellation.run.workflow_path !== '.github/workflows/release-receipt-canary.yml' || cancellation.run.head_sha !== canary.source_sha || cancellation.run.conclusion !== 'cancelled') auto02.push('cancellation source run is missing or mismatched');
  if (cancellation?.observer?.workflow_path !== '.github/workflows/release-run-observer.yml' || cancellation.observer.event_source_run_id !== cancellation.expected_id || cancellation.observer.source_sha !== canary.source_sha || cancellation.observer.conclusion !== 'success') auto02.push('cancellation observer identity or conclusion mismatch');
  const cancellationArtifacts = Array.isArray(cancellation?.artifacts) ? cancellation.artifacts : [];
  const cancellationArtifact = cancellationArtifacts.find((item) => item.run_id === cancellation?.observer?.run_id && item.name === `release-canary-cancellation-${cancellation.expected_id}-${cancellation.run?.attempt}`);
  if (!cancellationArtifact || cancellationArtifact.expired !== false || !/^sha256:[a-f0-9]{64}$/.test(text(cancellationArtifact.digest))) auto02.push('observer cancellation artifact is missing, expired, or has a malformed digest');
  if (failure?.artifact_retrieved?.status !== 'passed' || !/^[a-f0-9]{64}$/.test(text(failure?.artifact_retrieved?.sha256)) || failure?.artifact_retrieved?.receipt?.source_run_id !== failure?.expected_id || failure?.artifact_retrieved?.receipt?.source_sha !== canary?.source_sha || failure?.artifact_retrieved?.receipt?.scenario !== 'failure' || failure?.artifact_retrieved?.receipt?.verdict !== 'failure') auto02.push('retrieved failure receipt identity or digest validation mismatch');
  if (cancellation?.artifact_retrieved?.status !== 'passed' || !/^[a-f0-9]{64}$/.test(text(cancellation?.artifact_retrieved?.sha256)) || cancellation?.artifact_retrieved?.receipt?.source_run_id !== cancellation?.expected_id || cancellation?.artifact_retrieved?.receipt?.source_sha !== canary?.source_sha || cancellation?.artifact_retrieved?.receipt?.scenario !== 'cancellation' || cancellation?.artifact_retrieved?.receipt?.observer_run_id !== cancellation?.observer?.run_id || cancellation?.artifact_retrieved?.receipt?.verdict !== 'cancelled') auto02.push('retrieved cancellation receipt identity or digest validation mismatch');
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
