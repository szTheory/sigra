#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const phase247 = path.join(repoRoot, '.planning/phases/247-release-candidate-and-repository-readiness');
const reconciliationPath = path.join(here, '250-247-RECONCILIATION.json');
const reportPath = path.join(phase247, '247-VERIFICATION.md');
const proposalPath = path.join(phase247, '247-10-REBIND-PROPOSAL.json');
const readinessPath = path.join(phase247, '247-RELEASE-READINESS.json');
const dryRunPath = path.join(phase247, '247-HEX-DRY-RUN-RECEIPT.json');
const validationPath = path.join(phase247, '247-VALIDATION.md');
const playrightPath = path.join(phase247, '247-09-PLAYWRIGHT-RESULT.json');
const approvalPath = path.join(phase247, '247-CANDIDATE-APPROVAL.json');

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function safeCommand(command, args) {
  try {
    return { ok: true, stdout: execFileSync(command, args, { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() };
  } catch {
    return { ok: false, stdout: '' };
  }
}

function sameTuple(a, b) {
  return Boolean(a && b && a.candidateSha === b.candidateSha && a.reviewedBaseSha === b.reviewedBaseSha && a.mainSha === b.mainSha);
}

function orderedUnique(values) {
  return [...new Set(values)].sort((a, b) => a.localeCompare(b));
}

export function joinPopulation({ observedIds, dispositions, label, root = repoRoot }) {
  const blockers = [];
  if (!Array.isArray(observedIds) || !Array.isArray(dispositions)) {
    return { status: 'blocked', observedIds: [], dispositionIds: [], preservationRefs: [], blockers: [`${label}_population_or_dispositions_missing`] };
  }
  const observed = orderedUnique(observedIds.map(String));
  const dispositionIds = dispositions.map((item) => String(item?.id ?? ''));
  if (observedIds.some((id) => !String(id)) || new Set(observedIds.map(String)).size !== observedIds.length) blockers.push(`${label}_observed_ids_invalid`);
  if (dispositionIds.some((id) => !id) || new Set(dispositionIds).size !== dispositionIds.length) blockers.push(`${label}_disposition_ids_invalid`);
  if (JSON.stringify(orderedUnique(dispositionIds)) !== JSON.stringify(observed)) blockers.push(`${label}_population_mismatch`);
  for (const row of dispositions) {
    if (!row?.decision || !validPreservationReference(row.preservation_ref, row.id, row.decision, root)) blockers.push(`${label}_disposition_or_preservation_incomplete`);
  }
  const rows = [...dispositions].sort((a, b) => String(a?.id ?? '').localeCompare(String(b?.id ?? '')));
  return {
    status: blockers.length ? 'blocked' : 'passed',
    observedIds: observed,
    dispositionIds: rows.map((row) => String(row.id)),
    preservationRefs: rows.map((row) => ({ id: String(row.id), ref: row.preservation_ref?.ref ?? null, commitSha: row.preservation_ref?.commit_sha ?? null, recordPath: row.preservation_ref?.record_path ?? null, recordSha256: row.preservation_ref?.record_sha256 ?? null })),
    blockers: [...new Set(blockers)].sort(),
  };
}

function validPreservationReference(reference, dispositionId, decision, root) {
  if (!reference || typeof reference !== 'object'
    || !/^refs\/(?:heads|tags)\/[A-Za-z0-9._/-]+$/.test(reference.ref ?? '')
    || !/^[0-9a-f]{40}$/.test(reference.commit_sha ?? '')
    || !/^(?!\/)(?!.*(?:^|\/)\.\.(?:\/|$))[A-Za-z0-9._/-]+\.json$/.test(reference.record_path ?? '')
    || !/^[0-9a-f]{64}$/.test(reference.record_sha256 ?? '')) return false;
  try {
    const commit = execFileSync('git', ['rev-parse', '--verify', `${reference.ref}^{commit}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    if (commit !== reference.commit_sha) return false;
    const bytes = execFileSync('git', ['show', `${reference.ref}:${reference.record_path}`], { cwd: root, encoding: 'buffer', stdio: ['ignore', 'pipe', 'ignore'] });
    if (sha256(bytes) !== reference.record_sha256) return false;
    const record = JSON.parse(bytes.toString('utf8'));
    return String(record.id) === String(dispositionId) && record.decision === decision;
  } catch { return false; }
}

export function liveSnapshotStable(before, after) {
  return Boolean(before && after
    && before.pullRequest?.number === after.pullRequest?.number
    && before.pullRequest?.state === after.pullRequest?.state
    && before.pullRequest?.headSha === after.pullRequest?.headSha
    && before.pullRequest?.baseSha === after.pullRequest?.baseSha
    && before.main?.sha === after.main?.sha
    && JSON.stringify(orderedUnique((before.openPullRequestNumbers ?? []).map(String))) === JSON.stringify(orderedUnique((after.openPullRequestNumbers ?? []).map(String))));
}

function exactHeadCiErrors(receipt, authoritative, expected) {
  const { run_id: runId, attempt, head_sha: headSha } = expected ?? {};
  if (!receipt || !authoritative || !receipt.job) return ['exact_head_ci_source_missing'];
  const job = receipt.job;
  const receiptMatches = receipt.run_id === runId && receipt.run_attempt === attempt && receipt.head_sha === headSha
    && receipt.workflow_path === '.github/workflows/ci.yml' && receipt.conclusion === 'success'
    && job.name === 'ci-gate' && Number.isInteger(job.id) && job.id > 0 && job.head_sha === headSha
    && job.run_attempt === attempt && job.conclusion === 'success';
  const authorityMatches = authoritative.id === runId && authoritative.run_attempt === attempt && authoritative.head_sha === headSha
    && authoritative.path === '.github/workflows/ci.yml' && authoritative.conclusion === 'success'
    && authoritative.job?.id === job.id && authoritative.job?.name === 'ci-gate'
    && authoritative.job?.head_sha === headSha && authoritative.job?.run_attempt === attempt
    && authoritative.job?.conclusion === 'success';
  const errors = [];
  if (!receiptMatches) errors.push('exact_head_ci_receipt_mismatch');
  if (!authorityMatches) errors.push('exact_head_ci_authoritative_run_mismatch');
  return errors;
}

export function evaluateEvidence({ proposal, authorization, readiness, dryRunReceipt, live, liveAfter, objects = {}, remoteSourceObjects = {}, exactHeadCiReceipt = null, authoritativeCi = null }) {
  const proposalTuple = {
    candidateSha: proposal?.candidate_sha ?? null,
    reviewedBaseSha: proposal?.reviewed_base_sha ?? null,
    mainSha: proposal?.main_sha ?? null,
  };
  const readinessChecked = readiness?.final_validation?.checked ?? {};
  const readinessTuple = {
    candidateSha: readinessChecked.source_sha ?? readiness?.candidate?.current_pr_head_sha ?? null,
    reviewedBaseSha: readinessChecked.pr_base_sha ?? readiness?.candidate?.pr_base_sha ?? null,
    mainSha: readinessChecked.live_main_sha ?? null,
  };
  const liveTuple = {
    candidateSha: live?.pullRequest?.headSha ?? null,
    reviewedBaseSha: live?.pullRequest?.baseSha ?? null,
    mainSha: live?.main?.sha ?? null,
  };
  const blockers = [];
  if (proposal?.authorization_status !== 'approved' || !authorization?.immutable || !sameTuple(authorization?.tuple, proposalTuple)) {
    blockers.push({ id: 'authorization_pending', message: 'No immutable approval proves the exact proposed candidate/base/main tuple.', identities: proposalTuple });
  }
  if (!objects[proposalTuple.candidateSha]) blockers.push({ id: 'candidate_object_unavailable', message: 'The proposed child candidate commit is unavailable in the local immutable object database.', identities: { candidateSha: proposalTuple.candidateSha } });
  if (!objects[readinessTuple.candidateSha]) blockers.push({ id: 'readiness_candidate_object_unavailable', message: 'The prior readiness candidate commit is unavailable in the local immutable object database.', identities: { candidateSha: readinessTuple.candidateSha } });
  const candidateRemote = remoteSourceObjects.candidate ?? null;
  if (!candidateRemote?.available || candidateRemote.sourceBlobs?.some((blob) => !blob.matches)) blockers.push({ id: 'candidate_source_blobs_unverified', message: 'The proposed candidate source blobs are unavailable or differ from the proposal claims.', identities: { candidateSha: proposalTuple.candidateSha, sourceBlobs: candidateRemote?.sourceBlobs ?? [] } });
  const oldBaseline = proposal?.stale_artifacts?.find((item) => item.path?.endsWith('247-CANDIDATE-DIFF-BASELINE.json'));
  if (!oldBaseline || oldBaseline.bound_candidate_sha !== proposalTuple.candidateSha) blockers.push({ id: 'candidate_diff_digest_missing', message: 'No raw-diff digest and byte count are bound to the proposed child candidate.', identities: { candidateSha: proposalTuple.candidateSha, availableBaselineCandidateSha: oldBaseline?.bound_candidate_sha ?? null } });
  if (!sameTuple(readinessTuple, proposalTuple)) blockers.push({ id: 'readiness_tuple_mismatch', message: 'The saved readiness ledger is bound to a different candidate/base/main tuple.', identities: { proposal: proposalTuple, readiness: readinessTuple } });
  if (!sameTuple(liveTuple, proposalTuple) || live?.pullRequest?.state !== 'OPEN') blockers.push({ id: 'live_candidate_tuple_changed', message: 'The current pull request state or candidate/base/main refs differ from the proposed tuple.', identities: { proposal: proposalTuple, live: liveTuple, prState: live?.pullRequest?.state ?? null } });
  if (liveAfter && !liveSnapshotStable(live, liveAfter)) blockers.push({ id: 'live_refs_changed_during_capture', message: 'PR #224, main, or the open-PR population changed while evidence was being captured.', identities: { before: liveTuple, after: { candidateSha: liveAfter.pullRequest?.headSha ?? null, reviewedBaseSha: liveAfter.pullRequest?.baseSha ?? null, mainSha: liveAfter.main?.sha ?? null } } });
  if (dryRunReceipt?.verdict !== 'passed' || dryRunReceipt?.dry_run_outcome !== 'success' || dryRunReceipt?.requested_sha !== proposalTuple.candidateSha || dryRunReceipt?.checked_out_sha !== proposalTuple.candidateSha || dryRunReceipt?.reviewed_base_sha !== proposalTuple.reviewedBaseSha || dryRunReceipt?.live_base_sha !== proposalTuple.mainSha) {
    blockers.push({ id: 'dry_run_tuple_mismatch', message: 'The existing authenticated dry-run receipt does not prove the proposed tuple.', identities: { requestedSha: dryRunReceipt?.requested_sha ?? null, checkedOutSha: dryRunReceipt?.checked_out_sha ?? null, reviewedBaseSha: dryRunReceipt?.reviewed_base_sha ?? null, liveBaseSha: dryRunReceipt?.live_base_sha ?? null, runId: dryRunReceipt?.run_id ?? null, attempt: dryRunReceipt?.run_attempt ?? null } });
  }
  const ciExpected = {
    run_id: proposal?.ci?.run_id ?? readiness?.candidate?.review_check_state?.updated_head_ci?.run_id ?? null,
    attempt: proposal?.ci?.attempt ?? readiness?.candidate?.review_check_state?.updated_head_ci?.attempt ?? null,
    head_sha: proposal?.ci?.head_sha ?? readiness?.candidate?.review_check_state?.updated_head_ci?.head_sha ?? proposalTuple.candidateSha,
  };
  const ciErrors = exactHeadCiErrors(exactHeadCiReceipt, authoritativeCi, ciExpected);
  for (const id of ciErrors) blockers.push({ id, message: 'Exact-head CI receipt does not match the referenced authoritative workflow run and ci-gate job metadata.', identities: ciExpected });
  const population = joinPopulation({
    observedIds: live?.openPullRequestNumbers ?? null,
    dispositions: live?.openPullRequestDispositions ?? null,
    label: 'open_pr',
  });
  if (population.status !== 'passed') blockers.push({ id: 'fresh_pr_dispositions_incomplete', message: 'Fresh open-PR observations do not have ordered, unique dispositions and recoverable preservation references.', identities: { population } });
  const inherited = live?.inheritedWork;
  if (inherited?.observed !== true || !Array.isArray(inherited.observedIds) || !Array.isArray(inherited.dispositions)) {
    blockers.push({ id: 'fresh_inherited_dispositions_missing', message: 'A fresh inherited-work population with complete dispositions and preservation identities is absent.', identities: { checkoutHead: live?.checkout?.head ?? null, recordedObservation: proposal?.inventory_observations?.inherited_checkout?.head_sha ?? null } });
  } else {
    const inheritedPopulation = joinPopulation({ observedIds: inherited.observedIds, dispositions: inherited.dispositions, label: 'inherited_work' });
    if (inheritedPopulation.status !== 'passed') blockers.push({ id: 'fresh_inherited_dispositions_incomplete', message: 'Fresh inherited-work observations do not have exact, unique disposition and preservation-record joins.', identities: { population: inheritedPopulation } });
  }
  const sourceEvidence = {
    exactHeadCi: {
      proposalRunId: proposal?.ci?.run_id ?? readiness?.candidate?.review_check_state?.updated_head_ci?.run_id ?? null,
      proposalAttempt: proposal?.ci?.attempt ?? readiness?.candidate?.review_check_state?.updated_head_ci?.attempt ?? null,
      proposalHeadSha: proposal?.ci?.head_sha ?? readiness?.candidate?.review_check_state?.updated_head_ci?.head_sha ?? null,
      standaloneReceiptPath: path.relative(repoRoot, playrightPath),
      standaloneReceiptPresent: existsSync(playrightPath),
      receiptStatus: ciErrors.length ? 'blocked' : 'passed',
      authoritativeRunId: authoritativeCi?.id ?? null,
    },
    candidateSourceAudit: {
      version: proposal?.candidate_source_audit?.version ?? null,
      sourceRef: proposal?.candidate_source_audit?.source_ref ?? null,
      expectedBlobs: proposal?.candidate_source_audit?.candidate_source_blobs ?? {},
    },
    historicalPlan05: {
      summaryPath: '.planning/phases/247-release-candidate-and-repository-readiness/247-05-SUMMARY.md',
      requirementsCompletedClaim: ['READY-01'],
      independentVerificationPending: true,
      checkpointArtifactPath: '.planning/phases/247-release-candidate-and-repository-readiness/247-05-CHECKPOINT.md',
      checkpointArtifactPresent: existsSync(path.join(phase247, '247-05-CHECKPOINT.md')),
    },
    previousDryRun: { runId: dryRunReceipt?.run_id ?? null, attempt: dryRunReceipt?.run_attempt ?? null, candidateSha: dryRunReceipt?.requested_sha ?? null, verdict: dryRunReceipt?.verdict ?? null },
    oldReadiness: { candidateSha: readinessTuple.candidateSha, reviewedBaseSha: readinessTuple.reviewedBaseSha, mainSha: readinessTuple.mainSha, checkedAt: readiness?.final_validation?.checked_at ?? null },
    diffBaseline: readJson(path.join(phase247, '247-CANDIDATE-DIFF-BASELINE.json')),
  };
  const checks = [
    { id: 'approval', status: blockers.some((x) => x.id === 'authorization_pending') ? 'blocked' : 'passed' },
    { id: 'candidate_source', status: blockers.some((x) => ['candidate_object_unavailable', 'candidate_source_blobs_unverified', 'candidate_diff_digest_missing', 'live_candidate_tuple_changed'].includes(x.id)) ? 'blocked' : 'passed' },
    { id: 'readiness_and_ci', status: blockers.some((x) => ['readiness_candidate_object_unavailable', 'readiness_tuple_mismatch', 'exact_head_ci_source_missing', 'exact_head_ci_receipt_mismatch', 'exact_head_ci_authoritative_run_mismatch'].includes(x.id)) ? 'blocked' : 'passed' },
    { id: 'dry_run', status: blockers.some((x) => x.id === 'dry_run_tuple_mismatch') ? 'blocked' : 'passed' },
    { id: 'dispositions_and_preservation', status: blockers.some((x) => ['fresh_pr_dispositions_incomplete', 'fresh_inherited_dispositions_missing', 'fresh_inherited_dispositions_incomplete'].includes(x.id)) ? 'blocked' : 'passed' },
  ].sort((a, b) => a.id.localeCompare(b.id));
  const ready01Blockers = new Set(['authorization_pending', 'candidate_object_unavailable', 'candidate_source_blobs_unverified', 'candidate_diff_digest_missing', 'readiness_candidate_object_unavailable', 'readiness_tuple_mismatch', 'live_candidate_tuple_changed', 'live_refs_changed_during_capture', 'dry_run_tuple_mismatch', 'exact_head_ci_source_missing', 'exact_head_ci_receipt_mismatch', 'exact_head_ci_authoritative_run_mismatch']);
  const ready02Blockers = new Set(['authorization_pending', 'candidate_object_unavailable', 'candidate_source_blobs_unverified', 'candidate_diff_digest_missing', 'readiness_candidate_object_unavailable', 'readiness_tuple_mismatch', 'live_candidate_tuple_changed', 'live_refs_changed_during_capture', 'fresh_pr_dispositions_incomplete', 'fresh_inherited_dispositions_missing', 'fresh_inherited_dispositions_incomplete']);
  const requirementVerdicts = {
    'READY-01': blockers.some((x) => ready01Blockers.has(x.id)) ? 'unsatisfied' : 'satisfied',
    'READY-02': blockers.some((x) => ready02Blockers.has(x.id)) ? 'unsatisfied' : 'satisfied',
  };
  return {
    status: blockers.length ? 'blocked' : 'passed',
    proposalTuple,
    readinessTuple,
    liveTuple,
    sourceEvidence,
    checks,
    blockers: blockers.sort((a, b) => a.id.localeCompare(b.id)),
    requirementVerdicts,
    identityRows: [
      { kind: 'proposal_child_candidate', sha: proposalTuple.candidateSha, objectAvailable: Boolean(objects[proposalTuple.candidateSha]) },
      { kind: 'readiness_parent_candidate', sha: readinessTuple.candidateSha, objectAvailable: Boolean(objects[readinessTuple.candidateSha]) },
      { kind: 'live_pull_request_head', sha: liveTuple.candidateSha, state: live?.pullRequest?.state ?? null },
      { kind: 'live_main', sha: liveTuple.mainSha },
    ].sort((a, b) => a.kind.localeCompare(b.kind)),
  };
}

function ghJson(endpoint) {
  return JSON.parse(execFileSync('gh', ['api', endpoint], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }));
}

function captureExactHeadCi(readiness) {
  const expected = readiness?.candidate?.review_check_state?.updated_head_ci;
  if (!expected?.run_id || !existsSync(playrightPath)) return { receipt: null, authoritative: null };
  try {
    const run = ghJson(`repos/szTheory/sigra/actions/runs/${expected.run_id}`);
    const jobs = ghJson(`repos/szTheory/sigra/actions/runs/${expected.run_id}/jobs`).jobs ?? [];
    const job = jobs.find((row) => row.name === 'ci-gate' && row.run_attempt === expected.attempt) ?? null;
    return {
      receipt: readJson(playrightPath),
      authoritative: { id: run.id, run_attempt: run.run_attempt, head_sha: run.head_sha, path: run.path?.replace(/@.*$/, ''), conclusion: run.conclusion,
        job: job ? { id: job.id, name: job.name, head_sha: job.head_sha, run_attempt: job.run_attempt, conclusion: job.conclusion } : null },
    };
  } catch { return { receipt: existsSync(playrightPath) ? readJson(playrightPath) : null, authoritative: null }; }
}

function captureRemoteCommit(sha, expectedBlobs = {}) {
  try {
    const commit = ghJson(`repos/szTheory/sigra/commits/${sha}`);
    const treeSha = commit.commit?.tree?.sha ?? null;
    const tree = treeSha ? ghJson(`repos/szTheory/sigra/git/trees/${treeSha}?recursive=1`) : null;
    const entries = new Map((tree?.tree ?? []).filter((entry) => entry.type === 'blob').map((entry) => [entry.path, entry.sha]));
    const sourceBlobs = Object.entries(expectedBlobs).sort(([a], [b]) => a.localeCompare(b)).map(([file, expectedSha]) => ({ path: file, expectedSha, observedSha: entries.get(file) ?? null, matches: expectedSha === null ? null : entries.get(file) === expectedSha }));
    return { available: true, sha: commit.sha, parents: (commit.parents ?? []).map((parent) => parent.sha).sort(), treeSha, sourceBlobs };
  } catch {
    return { available: false, sha, parents: [], treeSha: null, sourceBlobs: Object.entries(expectedBlobs).sort(([a], [b]) => a.localeCompare(b)).map(([file, expectedSha]) => ({ path: file, expectedSha, observedSha: null, matches: expectedSha === null ? null : false })) };
  }
}

function objectAvailable(sha) {
  return Boolean(sha && safeCommand('git', ['cat-file', '-e', `${sha}^{commit}`]).ok);
}

function captureLive() {
  const pr = ghJson('repos/szTheory/sigra/pulls/224');
  const openPullRequests = ghJson('repos/szTheory/sigra/pulls?state=open&per_page=100');
  const main = ghJson('repos/szTheory/sigra/commits/main');
  const head = safeCommand('git', ['rev-parse', 'HEAD']).stdout || null;
  const branch = safeCommand('git', ['branch', '--show-current']).stdout || null;
  const status = safeCommand('git', ['status', '--porcelain=v1', '--untracked-files=all']).stdout;
  return {
    pullRequest: { number: pr.number, state: pr.state, headSha: pr.head?.sha ?? null, headRef: pr.head?.ref ?? null, baseSha: pr.base?.sha ?? null, baseRef: pr.base?.ref ?? null, updatedAt: pr.updated_at ?? null },
    main: { sha: main.sha ?? null, treeSha: main.commit?.tree?.sha ?? null },
    openPullRequestNumbers: openPullRequests.map((item) => item.number).sort((a, b) => a - b),
    openPullRequestCount: openPullRequests.length,
    openPullRequestDispositions: null,
    inheritedWork: null,
    checkout: { head, branch, clean: status === '', porcelainEntryCount: status ? status.split('\n').length : 0 },
  };
}

function artifactIdentity(file) {
  const bytes = readFileSync(file);
  const gitBlob = safeCommand('git', ['hash-object', file]).stdout || null;
  return { path: path.relative(repoRoot, file), sha256: sha256(bytes), bytes: bytes.length, gitBlob };
}

export function captureEvidence({ capturedAt = new Date().toISOString(), live = captureLive() } = {}) {
  const proposal = readJson(proposalPath);
  const readiness = readJson(readinessPath);
  const dryRunReceipt = readJson(dryRunPath);
  const auth = existsSync(approvalPath) ? readJson(approvalPath) : null;
  const exactHeadCi = captureExactHeadCi(readiness);
  const objectShas = [proposal.candidate_sha, proposal.candidate_ancestry?.parent_sha, readiness.final_validation?.checked?.source_sha, proposal.reviewed_base_sha, proposal.main_sha, live.main.sha, live.pullRequest.headSha].filter(Boolean);
  const localObjects = Object.fromEntries([...new Set(objectShas)].map((sha) => [sha, objectAvailable(sha)]));
  const candidateRemote = captureRemoteCommit(proposal.candidate_sha, proposal.candidate_source_audit?.candidate_source_blobs ?? {});
  const readinessRemote = captureRemoteCommit(readiness.final_validation?.checked?.source_sha, Object.fromEntries(Object.keys(proposal.candidate_source_audit?.candidate_source_blobs ?? {}).map((file) => [file, null])));
  const remoteObjects = { [candidateRemote.sha]: candidateRemote.available, [readinessRemote.sha]: readinessRemote.available };
  const objects = Object.fromEntries([...new Set(objectShas)].map((sha) => [sha, localObjects[sha] || remoteObjects[sha] === true]));
  const liveAfter = captureLive();
  const evaluation = evaluateEvidence({ proposal, authorization: auth, readiness, dryRunReceipt, live, liveAfter, objects, remoteSourceObjects: { candidate: candidateRemote, readiness: readinessRemote }, exactHeadCiReceipt: exactHeadCi.receipt, authoritativeCi: exactHeadCi.authoritative });
  const evidenceFiles = [proposalPath, readinessPath, dryRunPath, validationPath, path.join(phase247, '247-05-SUMMARY.md'), path.join(phase247, '247-08-SUMMARY.md'), path.join(phase247, '247-CANDIDATE-DIFF-BASELINE.json')];
  const result = {
    schema_version: 1,
    repository: 'szTheory/sigra',
    captured_at: capturedAt,
    status: evaluation.status,
    source_capture: {
      repo_root: repoRoot,
      branch: live.checkout?.branch ?? null,
      checkout_head: live.checkout?.head ?? null,
      checkout_clean: live.checkout?.clean ?? null,
      current_main: live.main,
      current_pr_224: live.pullRequest,
      current_open_pull_requests: { count: live.openPullRequestCount, numbers: live.openPullRequestNumbers },
      live_after_capture: { main: liveAfter.main, pullRequest: liveAfter.pullRequest, openPullRequestNumbers: liveAfter.openPullRequestNumbers },
      object_availability: Object.fromEntries(Object.entries(objects).sort(([a], [b]) => a.localeCompare(b))),
      local_object_availability: Object.fromEntries(Object.entries(localObjects).sort(([a], [b]) => a.localeCompare(b))),
      remote_source_objects: [candidateRemote, readinessRemote].sort((a, b) => String(a.sha).localeCompare(String(b.sha))),
      approval_path: path.relative(repoRoot, approvalPath),
      approval_present: Boolean(auth),
      approval_status: proposal.authorization_status,
      evidence_files: evidenceFiles.map(artifactIdentity).sort((a, b) => a.path.localeCompare(b.path)),
      verifier_artifacts: [artifactIdentity(path.join(here, 'verify-247-readiness.mjs')), artifactIdentity(path.join(here, 'verify-247-readiness.test.mjs'))].sort((a, b) => a.path.localeCompare(b.path)),
    },
    candidate_tuples: {
      proposal: evaluation.proposalTuple,
      saved_readiness: evaluation.readinessTuple,
      live_observation: evaluation.liveTuple,
      approved: auth?.tuple ?? null,
    },
    evidence: evaluation.sourceEvidence,
    checks: evaluation.checks,
    blockers: evaluation.blockers,
    requirement_verdicts: evaluation.requirementVerdicts,
    identity_rows: evaluation.identityRows,
  };
  return result;
}

export function buildReport(reconciliation) {
  const jsonBytes = `${JSON.stringify(reconciliation, null, 2)}\n`;
  const digest = sha256(jsonBytes);
  const blockers = reconciliation.blockers.map((item) => `| ${item.id} | ${item.message} |`).join('\n');
  const evidence = reconciliation.evidence;
  return `# Phase 247 Independent Verification\n\n<!-- reconciliation: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json -->\n<!-- reconciliation-sha256: ${digest} -->\n\n- **Status:** ${reconciliation.status === 'passed' ? 'passed' : 'gaps_found'}\n- **Captured at:** ${reconciliation.captured_at}\n- **Source checkout:** \`${reconciliation.source_capture.branch ?? 'unknown'}\` at \`${reconciliation.source_capture.checkout_head ?? 'unknown'}\`\n- **Current PR #224:** ${reconciliation.source_capture.current_pr_224.state} at \`${reconciliation.source_capture.current_pr_224.headSha}\`, base \`${reconciliation.source_capture.current_pr_224.baseSha}\`\n- **Current main:** \`${reconciliation.source_capture.current_main.sha}\`\n- **Approval:** ${reconciliation.source_capture.approval_status}; immutable approval present: ${reconciliation.source_capture.approval_present}\n- **Saved readiness tuple:** candidate \`${reconciliation.candidate_tuples.saved_readiness.candidateSha}\`, base \`${reconciliation.candidate_tuples.saved_readiness.reviewedBaseSha}\`, main \`${reconciliation.candidate_tuples.saved_readiness.mainSha}\`\n- **Proposed tuple:** candidate \`${reconciliation.candidate_tuples.proposal.candidateSha}\`, base \`${reconciliation.candidate_tuples.proposal.reviewedBaseSha}\`, main \`${reconciliation.candidate_tuples.proposal.mainSha}\`\n- **Exact-head CI:** run \`${evidence.exactHeadCi.proposalRunId}\`, attempt \`${evidence.exactHeadCi.proposalAttempt}\`, head \`${evidence.exactHeadCi.proposalHeadSha}\`; standalone source present: ${evidence.exactHeadCi.standaloneReceiptPresent}\n- **Authenticated dry-run:** run \`${evidence.previousDryRun.runId}\`, attempt \`${evidence.previousDryRun.attempt}\`, candidate \`${evidence.previousDryRun.candidateSha}\`, verdict \`${evidence.previousDryRun.verdict}\`\n- **Open PR population:** ${reconciliation.source_capture.current_open_pull_requests.count}; fresh complete disposition join: ${reconciliation.checks.find((x) => x.id === 'dispositions_and_preservation').status}\n\n## Requirement Verdicts\n\n| Requirement | Verdict | Reason |\n|---|---|---|\n| READY-01 | ${reconciliation.requirement_verdicts['READY-01']} | Candidate approval, exact source, CI, readiness, and authenticated dry-run do not join to one tuple. |\n| READY-02 | ${reconciliation.requirement_verdicts['READY-02']} | Fresh open-PR and inherited-work dispositions with recoverable preservation identities are incomplete. |\n\n## Reconciliation Blockers\n\n| Blocker | Finding |\n|---|---|\n${blockers}\n\n## Preserved Historical Evidence\n\nThe earlier readiness ledger and dry-run receipt remain unchanged. The readiness ledger records candidate \`${evidence.oldReadiness.candidateSha}\`, base \`${evidence.oldReadiness.reviewedBaseSha}\`, and main \`${evidence.oldReadiness.mainSha}\`. The receipt records run \`${evidence.previousDryRun.runId}\` on candidate \`${evidence.previousDryRun.candidateSha}\`; it cannot prove the pending child tuple. The historical proposal remains \`authorization_status: pending\`.\n\n## Evidence References\n\nThe source identities and SHA-256 hashes for every input artifact, object availability, live PR/main observation, CI run, and dry-run identity are recorded in the linked reconciliation JSON. READY-01/02 remain owned by Phase 247; Phase 250 contributes verification evidence only. This report does not claim either requirement as satisfied.\n`;
}

export function checkReport(markdown, reconciliation) {
  const expected = buildReport(reconciliation);
  const expectedDigest = expected.match(/reconciliation-sha256: ([a-f0-9]{64})/)?.[1];
  const claimedDigest = markdown.match(/reconciliation-sha256: ([a-f0-9]{64})/)?.[1];
  const verdictsMatch = markdown.includes(`| READY-01 | ${reconciliation.requirement_verdicts['READY-01']} |`) && markdown.includes(`| READY-02 | ${reconciliation.requirement_verdicts['READY-02']} |`);
  const blockersMatch = reconciliation.blockers.every((item) => markdown.includes(`| ${item.id} |`));
  const identities = [reconciliation.captured_at, reconciliation.source_capture.current_pr_224?.headSha, reconciliation.source_capture.current_pr_224?.baseSha, reconciliation.source_capture.current_main?.sha, reconciliation.candidate_tuples.proposal?.candidateSha, reconciliation.candidate_tuples.proposal?.reviewedBaseSha, reconciliation.candidate_tuples.proposal?.mainSha, reconciliation.evidence.exactHeadCi?.proposalRunId, reconciliation.evidence.exactHeadCi?.proposalAttempt, reconciliation.evidence.previousDryRun?.runId, reconciliation.evidence.previousDryRun?.attempt].filter((value) => value !== null && value !== undefined).map(String);
  const identitiesMatch = identities.every((identity) => markdown.includes(identity));
  const noPhase250Ownership = !/Phase 250 (?:owns|implements|satisfies) READY-0[12]/i.test(markdown);
  return { valid: expectedDigest === claimedDigest && verdictsMatch && blockersMatch && identitiesMatch && noPhase250Ownership, expectedDigest, claimedDigest, verdictsMatch, blockersMatch, identitiesMatch, noPhase250Ownership };
}

function writeCapture() {
  const reconciliation = captureEvidence();
  writeFileSync(reconciliationPath, `${JSON.stringify(reconciliation, null, 2)}\n`);
  const report = buildReport(reconciliation).replace('\n## Evidence References\n', "\nPlan 247-05's summary claims READY-01 operational completion through Plans 06–08 and records that independent Phase 247 verification remained pending. This is preserved as historical narrative, not promoted to an independent requirement verdict. Its referenced checkpoint artifact is absent from the captured source set. The input hashes for Plan 247-05 and Plan 247-08 summaries are included in the reconciliation.\n\n## Evidence References\n");
  writeFileSync(reportPath, report);
  process.stdout.write(`${JSON.stringify({ status: reconciliation.status, report: path.relative(repoRoot, reportPath), reconciliation: path.relative(repoRoot, reconciliationPath), blockers: reconciliation.blockers.map((x) => x.id) }, null, 2)}\n`);
}

if (process.argv[2] === '--check-report') {
  const file = path.resolve(process.argv[3] ?? '');
  const reconciliation = readJson(reconciliationPath);
  const result = checkReport(readFileSync(file, 'utf8'), reconciliation);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.valid) process.exitCode = 1;
} else if (process.argv[2] === '--capture') {
  writeCapture();
}
