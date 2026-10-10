import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { validateTerminalStatusRecord } from '../249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs';

const REPOSITORY = 'szTheory/sigra';
const ROOT = process.cwd();
const PHASE_DIR = '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat';
const OWNER_DIR = '.planning/phases/249-publish-and-prove-sigra-1-6-0';
const SNAPSHOT_PATH = `${PHASE_DIR}/250-249-SOURCE-SNAPSHOT.json`;
const EVIDENCE_REF = 'refs/heads/evidence/phase-249-final-acceptance';
const ACCEPTANCE_PATH = `${OWNER_DIR}/249-FINAL-ACCEPTANCE.json`;
const TERMINAL_PATH = `${OWNER_DIR}/249-TERMINAL-STATUS.json`;
const RECEIPT_PATH = `${OWNER_DIR}/249-RELEASE-RECEIPT.json`;
const PRESERVATION_PATH = `${OWNER_DIR}/249-PRESERVATION.json`;
const CLOSEOUT_PATH = `${OWNER_DIR}/249-CLOSEOUT.json`;
const HISTORICAL_MAIN = '08300af1740fea8b77d5928a182688acbf103edc';
const PACKAGE_SOURCE = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const ACCEPTED_LOSS = Object.freeze({
  path: '.planning/HANDOFF.json', status: ' M', sha256: '00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148',
  authorization: 'accept reality and move on accordingly', authorized_by: 'user', authorized_at: '2026-10-09',
  audit_record_ref: 'refs/phase-249-preservation/plan-08-preservation-record-v4',
  audit_record_commit_sha: '96581c2b555a11b50b6efece9c25a5b1f8e0e456',
  audit_record_sha256: 'b47304df684b3eda5916730072a481d91113f6fca76bd0f9507e24387f3f4ad3',
});
const SHA = /^[0-9a-f]{40}$/;
const DIGEST = /^[0-9a-f]{64}$/;

function hash(bytes) { return createHash('sha256').update(bytes).digest('hex'); }
function run(command, args, options = {}) {
  return execFileSync(command, args, { cwd: ROOT, encoding: 'buffer', maxBuffer: 32 * 1024 * 1024, ...options });
}
function runText(command, args, options = {}) { return run(command, args, options).toString('utf8').trimEnd(); }
function git(...args) { return runText('git', args); }
function ghJson(endpoint) { return JSON.parse(runText('gh', ['api', endpoint])); }
function optionalGitJson(ref, file) {
  const bytes = run('git', ['show', `${ref}:${file}`]);
  return { value: JSON.parse(bytes.toString('utf8')), bytes, blob_sha: git('rev-parse', '--verify', `${ref}:${file}`), sha256: hash(bytes) };
}
function add(blockers, code) { if (!blockers.includes(code)) blockers.push(code); }
function requirement(blockers) { return { status: blockers.length ? 'unsatisfied' : 'satisfied', blockers }; }

function validAcceptance(snapshot) {
  const blockers = [];
  const ref = snapshot?.evidence_ref;
  const acceptance = ref?.acceptance;
  const terminal = ref?.terminal;
  if (ref?.name !== EVIDENCE_REF || !SHA.test(ref?.commit_sha ?? '')) add(blockers, 'passing named evidence ref identity is missing or malformed');
  const acceptanceBytes = Buffer.from(ref?.acceptance_json_base64 ?? '', 'base64');
  if (!SHA.test(ref?.acceptance_blob_sha ?? '') || !DIGEST.test(ref?.acceptance_sha256 ?? '')
    || acceptanceBytes.toString('base64') !== ref?.acceptance_json_base64 || hash(acceptanceBytes) !== ref?.acceptance_sha256) add(blockers, 'acceptance artifact digest does not match its captured identity');
  if (acceptance?.verdict !== 'passed' || acceptance?.errors?.length || acceptance?.final_main_sha !== HISTORICAL_MAIN
    || acceptance?.package_source_sha !== PACKAGE_SOURCE) add(blockers, 'historical acceptance is blocked or binds the wrong source/main identity');
  if (terminal?.verdict !== 'passed' || terminal?.final_validation?.verdict !== 'passed'
    || terminal?.final_validation?.errors?.length || terminal?.final_validation?.blockers?.length) add(blockers, 'terminal record is not a passing acceptance seal');
  const canonical = terminal?.canonical_acceptance;
  if (canonical?.path !== ACCEPTANCE_PATH || canonical?.blob_sha !== ref?.acceptance_blob_sha
    || canonical?.commit_sha !== ref?.acceptance_commit_sha || canonical?.sha256 !== ref?.acceptance_sha256
    || canonical?.verdict !== 'passed') add(blockers, 'terminal canonical acceptance commit/blob/digest identity mismatch');
  if (!SHA.test(ref?.acceptance_commit_sha ?? '') || !SHA.test(ref?.terminal_commit_sha ?? '')
    || !SHA.test(ref?.terminal_blob_sha ?? '') || !DIGEST.test(ref?.terminal_sha256 ?? '')
    || Buffer.from(ref?.terminal_json_base64 ?? '', 'base64').toString('base64') !== ref?.terminal_json_base64
    || hash(Buffer.from(ref?.terminal_json_base64 ?? '', 'base64')) !== ref?.terminal_sha256) add(blockers, 'terminal record digest or commit/blob identity is missing or mismatched');
  const validation = terminal ? validateTerminalStatusRecord(terminal, {
    canonical_blob_sha: ref?.acceptance_blob_sha,
    canonical_commit_sha: ref?.acceptance_commit_sha,
  }) : { valid: false, errors: [{ code: 'terminal_record_missing' }] };
  if (!validation.valid) add(blockers, `terminal status validation failed: ${validation.errors.map(row => row.code).join(',')}`);
  if (acceptance?.final_main_ci?.head_sha !== HISTORICAL_MAIN || acceptance?.final_main_ci?.ci_gate?.head_sha !== HISTORICAL_MAIN
    || acceptance?.final_main_ci?.conclusion !== 'success' || acceptance?.final_main_ci?.ci_gate?.conclusion !== 'success') add(blockers, 'historical release-main ci-gate identity is not passing on the exact historical SHA');
  const loss = snapshot?.accepted_loss;
  if (!loss || loss.path !== ACCEPTED_LOSS.path || loss.status !== ACCEPTED_LOSS.status || loss.sha256 !== ACCEPTED_LOSS.sha256
    || loss.authorization !== ACCEPTED_LOSS.authorization || loss.authorized_by !== ACCEPTED_LOSS.authorized_by
    || loss.authorized_at !== ACCEPTED_LOSS.authorized_at || loss.audit_record_ref !== ACCEPTED_LOSS.audit_record_ref
    || loss.audit_record_commit_sha !== ACCEPTED_LOSS.audit_record_commit_sha || loss.audit_record_sha256 !== ACCEPTED_LOSS.audit_record_sha256) add(blockers, 'the exact user-authorized HANDOFF accepted-loss record changed or is incomplete');
  if (loss?.bytes_recovered !== false || loss?.bytes_preserved !== false) add(blockers, 'historical HANDOFF bytes must remain explicitly unrecovered and unpreserved');
  return blockers;
}

export function evaluateSnapshot(snapshot) {
  const rel01 = validAcceptance(snapshot);
  const source = snapshot?.source;
  const publicProof = snapshot?.public_release;
  const receipt = snapshot?.receipt;
  if (source?.package_source_sha !== PACKAGE_SOURCE) add(rel01, 'immutable package-source SHA is missing or mismatched');
  if (source?.historical_release_main_sha !== HISTORICAL_MAIN || source?.historical_release_main_sha === source?.package_source_sha
    || snapshot?.evidence_ref?.acceptance?.final_main_sha !== HISTORICAL_MAIN) add(rel01, 'historical release-main SHA is missing, conflated, or mismatched');
  if (publicProof?.verdict !== 'passed' || publicProof?.version !== '1.6.0' || publicProof?.tag !== 'v1.6.0'
    || publicProof?.package_source_sha !== PACKAGE_SOURCE || publicProof?.versioned_docs_url !== 'https://sigra.hexdocs.pm/1.6.0/Sigra.html'
    || !String(publicProof?.source_url ?? '').startsWith('https://github.com/sztheory/sigra/blob/v1.6.0/')
    || !DIGEST.test(publicProof?.checksum ?? '')) add(rel01, 'live public Hex/docs/tag/source/checksum proof does not join package source 9e80cb…');
  if (receipt?.package_source_sha !== PACKAGE_SOURCE || receipt?.blob_sha !== snapshot?.evidence_ref?.acceptance?.receipt?.blob_sha
    || receipt?.sha256 !== snapshot?.evidence_ref?.acceptance?.receipt?.sha256) add(rel01, 'release receipt source or historical acceptance identity mismatch');
  if (snapshot?.historical_ci?.run_id !== Number(snapshot?.evidence_ref?.acceptance?.final_main_ci?.run_id)
    || snapshot?.historical_ci?.attempt !== snapshot?.evidence_ref?.acceptance?.final_main_ci?.attempt
    || snapshot?.historical_ci?.workflow_path !== '.github/workflows/ci.yml'
    || snapshot?.historical_ci?.head_sha !== HISTORICAL_MAIN || snapshot?.historical_ci?.job?.id !== Number(snapshot?.evidence_ref?.acceptance?.final_main_ci?.ci_gate?.job_id)
    || snapshot?.historical_ci?.job?.head_sha !== HISTORICAL_MAIN || snapshot?.historical_ci?.job?.name !== 'ci-gate'
    || snapshot?.historical_ci?.job?.conclusion !== 'success' || snapshot?.historical_ci?.job?.attempt !== snapshot?.historical_ci?.attempt) add(rel01, 'historical exact-head ci-gate run/job/attempt is missing or mismatched');

  const rel02 = [];
  const currentSha = source?.current_protected_main_sha;
  if (!SHA.test(currentSha ?? '') || currentSha === HISTORICAL_MAIN || currentSha === PACKAGE_SOURCE) add(rel02, 'fresh protected main SHA is missing or conflated with historical source/main');
  if (source?.historical_is_ancestor !== true || snapshot?.evidence_ref?.acceptance?.final_main_sha !== HISTORICAL_MAIN) add(rel02, 'historical release main is not proven as the accepted ancestor of current protected main');
  const ci = snapshot?.current_ci;
  if (ci?.workflow_path !== '.github/workflows/ci.yml' || ci?.event !== 'push' || ci?.branch !== 'main'
    || ci?.head_sha !== currentSha || ci?.job?.head_sha !== currentSha || ci?.job?.name !== 'ci-gate'
    || ci?.job?.attempt !== ci?.attempt || !Number.isInteger(ci?.run_id) || !Number.isInteger(ci?.job?.id)) add(rel02, 'current ci-gate run/job/attempt identity is absent or stale for the exact current main SHA');
  if (ci?.conclusion !== 'success') add(rel02, `current CI workflow run concluded ${ci?.conclusion ?? 'unknown'} for the exact current main SHA`);
  if (ci?.job?.conclusion !== 'success') add(rel02, `current ci-gate job concluded ${ci?.job?.conclusion ?? 'unknown'} for the exact current main SHA`);
  if (receipt?.current_blob_sha !== receipt?.blob_sha || receipt?.blob_sha !== snapshot?.evidence_ref?.acceptance?.receipt?.blob_sha) add(rel02, 'current main release receipt blob differs from the accepted immutable receipt');
  const inventory = snapshot?.inventory;
  if (inventory?.worktrees_read_status !== 'complete' || !Array.isArray(inventory?.worktrees) || inventory.worktrees.length === 0) add(rel02, 'registered worktree raw-status capture is missing or incomplete');
  for (const row of inventory?.worktrees ?? []) {
    const bytes = Buffer.from(row.raw_status_base64 ?? '', 'base64');
    if (!row.path || !row.branch && row.detached !== true || !DIGEST.test(row.raw_status_sha256 ?? '')
      || bytes.toString('base64') !== row.raw_status_base64 || hash(bytes) !== row.raw_status_sha256
      || bytes.length !== row.raw_status_bytes || row.clean !== (bytes.length === 0) || !row.clean) {
      add(rel02, `worktree raw porcelain status is dirty, malformed, or incomplete: ${row.path ?? 'unknown worktree'}`);
    }
  }
  if (inventory?.pull_requests_read_status !== 'complete' || !Array.isArray(inventory?.pull_requests)) add(rel02, 'fresh open-PR identity capture is missing or incomplete');
  const seen = new Set();
  for (const pr of inventory?.pull_requests ?? []) {
    const key = `${pr.number}:${pr.base_sha}:${pr.head_sha}`;
    if (!Number.isInteger(pr.number) || !SHA.test(pr.base_sha ?? '') || !SHA.test(pr.head_sha ?? '') || seen.has(pr.number)) add(rel02, `open PR identity is malformed or duplicated: #${pr.number ?? '?'}`);
    seen.add(pr.number);
    if (pr.disposition_identity_match !== true || !['release-blocking', 'release-relevant', 'separate-follow-up'].includes(pr.disposition)) add(rel02, `open PR #${pr.number} has no disposition matching its current base/head identity`);
  }
  if (!snapshot?.captured_at || Number.isNaN(Date.parse(snapshot.captured_at))) add(rel02, 'source snapshot capture timestamp is missing or invalid');
  const requirements = { 'REL-01': requirement(rel01), 'REL-02': requirement(rel02) };
  return { requirements, blockers: Object.entries(requirements).flatMap(([key, value]) => value.blockers.map(message => `${key}: ${message}`)) };
}

export function reportIdentity(snapshot, evaluation) {
  return {
    requirements: Object.fromEntries(Object.entries(evaluation.requirements).map(([key, value]) => [key, value.status])),
    package_source_sha: snapshot.source?.package_source_sha ?? null,
    historical_release_main_sha: snapshot.source?.historical_release_main_sha ?? null,
    current_protected_main_sha: snapshot.source?.current_protected_main_sha ?? null,
    evidence_ref: snapshot.evidence_ref?.name ?? null,
    evidence_ref_commit: snapshot.evidence_ref?.commit_sha ?? null,
    evidence_acceptance_blob: snapshot.evidence_ref?.acceptance_blob_sha ?? null,
    evidence_terminal_blob: snapshot.evidence_ref?.terminal_blob_sha ?? null,
    historical_ci_run_id: snapshot.historical_ci?.run_id ?? null,
    historical_ci_job_id: snapshot.historical_ci?.job?.id ?? null,
    current_ci_run_id: snapshot.current_ci?.run_id ?? null,
    current_ci_job_id: snapshot.current_ci?.job?.id ?? null,
    receipt_blob_sha: snapshot.receipt?.blob_sha ?? null,
    worktree_count: snapshot.inventory?.worktrees?.length ?? null,
    pull_request_count: snapshot.inventory?.pull_requests?.length ?? null,
    accepted_loss_sha256: snapshot.accepted_loss?.sha256 ?? null,
    historical_report_sha256: snapshot.historical_report?.sha256 ?? null,
  };
}

export function checkReport(report, snapshot, evaluation = evaluateSnapshot(snapshot)) {
  const errors = [];
  const historicalBytes = Buffer.from(snapshot.historical_report?.raw_bytes_base64 ?? '', 'base64');
  if (historicalBytes.toString('base64') !== snapshot.historical_report?.raw_bytes_base64
    || hash(historicalBytes) !== snapshot.historical_report?.raw_bytes_sha256
    || hash(Buffer.from(historicalBytes.toString('utf8').trimEnd())) !== snapshot.historical_report?.sha256) errors.push('historical_report_snapshot_invalid');
  const historyMarker = '\n<details>\n<summary>Historical Phase 249 report preserved verbatim</summary>\n\n`````markdown\n';
  const historyStart = report.indexOf(historyMarker);
  const closeMarker = '\n`````\n</details>';
  if (historyStart < 0) errors.push('historical_report_missing');
  else {
    const bodyStart = historyStart + historyMarker.length;
    const bodyEnd = report.indexOf(closeMarker, bodyStart);
    if (bodyEnd < 0 || hash(Buffer.from(report.slice(bodyStart, bodyEnd).trimEnd())) !== snapshot.historical_report?.sha256) errors.push('historical_report_identity_mismatch');
  }
  const currentReport = historyStart < 0 ? report : report.slice(0, historyStart);
  const match = currentReport.match(/<!-- phase249-evidence ([^\n]+) -->/);
  if (!match) return ['report_evidence_identity_missing'];
  let embedded;
  try { embedded = JSON.parse(match[1]); } catch { return ['report_evidence_identity_invalid']; }
  if (JSON.stringify(embedded) !== JSON.stringify(reportIdentity(snapshot, evaluation))) errors.push('report_source_identity_mismatch');
  const headerStatus = currentReport.match(/^status: ([^\n]+)$/m)?.[1];
  const expectedStatus = Object.values(evaluation.requirements).every(row => row.status === 'satisfied') ? 'passed' : 'gaps_found';
  const expectedRequirements = Object.fromEntries(Object.entries(evaluation.requirements).map(([key, value]) => [key, value.status]));
  if (JSON.stringify(embedded.requirements) !== JSON.stringify(expectedRequirements)
    || headerStatus !== expectedStatus || !currentReport.includes(`**Status:** ${expectedStatus}`)) errors.push('report_requirement_mismatch');
  if (/historical bytes (?:were )?(?:recovered|preserved)/i.test(currentReport)) errors.push('report_misstates_accepted_loss');
  if (!currentReport.includes('accepted-with-recorded-loss') || !currentReport.includes(snapshot.accepted_loss?.authorization ?? '')) errors.push('report_accepted_loss_exception_missing');
  return errors;
}

export function freshnessErrors(captured, current) {
  const errors = [];
  for (const [label, left, right] of [
    ['protected main', captured.source?.current_protected_main_sha, current.source?.current_protected_main_sha],
    ['package source', captured.source?.package_source_sha, current.source?.package_source_sha],
    ['historical release main', captured.source?.historical_release_main_sha, current.source?.historical_release_main_sha],
    ['acceptance ref', captured.evidence_ref?.commit_sha, current.evidence_ref?.commit_sha],
    ['acceptance blob', captured.evidence_ref?.acceptance_blob_sha, current.evidence_ref?.acceptance_blob_sha],
    ['terminal blob', captured.evidence_ref?.terminal_blob_sha, current.evidence_ref?.terminal_blob_sha],
    ['receipt blob', captured.receipt?.current_blob_sha, current.receipt?.current_blob_sha],
  ]) if (left !== right) errors.push(`source identity changed since capture: ${label}`);
  const ciIdentity = value => [value?.run_id, value?.attempt, value?.workflow_path, value?.event, value?.branch, value?.head_sha, value?.conclusion,
    value?.job?.id, value?.job?.name, value?.job?.head_sha, value?.job?.conclusion, value?.job?.attempt];
  if (JSON.stringify(ciIdentity(captured.current_ci)) !== JSON.stringify(ciIdentity(current.current_ci))) errors.push('current exact-main CI identity changed since capture');
  const worktrees = value => (value?.inventory?.worktrees ?? []).map(row => [row.path, row.branch, row.detached, row.read_status, row.raw_status_base64, row.raw_status_sha256, row.raw_status_bytes, row.clean]).sort((a, b) => String(a[0]).localeCompare(String(b[0])));
  if (JSON.stringify(worktrees(captured)) !== JSON.stringify(worktrees(current))) errors.push('registered worktree population or raw porcelain status changed since capture');
  if ((current.inventory?.worktrees ?? []).some(row => !row.clean || row.read_status !== 'complete')) errors.push('fresh raw worktree capture is dirty or incomplete');
  const prs = value => (value?.inventory?.pull_requests ?? []).map(row => [row.number, row.base_ref, row.base_sha, row.head_ref, row.head_sha, row.disposition, row.disposition_identity_match]).sort((a, b) => a[0] - b[0]);
  if (JSON.stringify(prs(captured)) !== JSON.stringify(prs(current))) errors.push('open PR population, exact tuple, or disposition changed since capture');
  if (current.inventory?.pull_requests_read_status !== 'complete') errors.push('fresh open PR query is incomplete');
  if (JSON.stringify([captured.receipt?.blob_sha, captured.receipt?.sha256]) !== JSON.stringify([current.receipt?.blob_sha, current.receipt?.sha256])) errors.push('accepted release receipt identity changed since capture');
  if (JSON.stringify([captured.public_release?.version, captured.public_release?.tag, captured.public_release?.package_source_sha, captured.public_release?.checksum, captured.public_release?.verdict])
    !== JSON.stringify([current.public_release?.version, current.public_release?.tag, current.public_release?.package_source_sha, current.public_release?.checksum, current.public_release?.verdict])) errors.push('public release identity changed since capture');
  return errors;
}

function captureWorktrees() {
  const records = [];
  const fields = run('git', ['worktree', 'list', '--porcelain', '-z']).toString('utf8').split('\0');
  let current = null;
  for (const field of fields) {
    if (field.startsWith('worktree ')) {
      if (current) records.push(current);
      current = { path: field.slice(9), branch: null, head_sha: null, detached: false, locked: false, prunable: false };
    } else if (current && field.startsWith('HEAD ')) current.head_sha = field.slice(5);
    else if (current && field.startsWith('branch refs/heads/')) current.branch = field.slice(18);
    else if (current && field === 'detached') current.detached = true;
    else if (current && field.startsWith('locked')) current.locked = true;
    else if (current && field.startsWith('prunable')) current.prunable = true;
  }
  if (current) records.push(current);
  return records.map(row => {
    try {
      const raw = run('git', ['-C', row.path, 'status', '--porcelain=v1', '-z', '-uall']);
      return { ...row, read_status: 'complete', raw_status_base64: raw.toString('base64'), raw_status_sha256: hash(raw), raw_status_bytes: raw.length, clean: raw.length === 0 };
    } catch (error) { return { ...row, read_status: 'failed', read_error: error.message, raw_status_base64: null, raw_status_sha256: null, raw_status_bytes: null, clean: false }; }
  }).sort((a, b) => a.path.localeCompare(b.path));
}

function capturePullRequests() {
  const pages = JSON.parse(runText('gh', ['api', '--paginate', '--slurp', `repos/${REPOSITORY}/pulls?state=open&per_page=100`]));
  if (!Array.isArray(pages) || !pages.every(Array.isArray)) throw new Error('Open PR pagination did not return complete page arrays.');
  const old = JSON.parse(fs.readFileSync(`${ROOT}/${CLOSEOUT_PATH}`, 'utf8'));
  const prior = new Map((old.pull_requests ?? []).map(pr => [pr.number, pr]));
  return pages.flat().map(pr => {
    const priorRow = prior.get(pr.number);
    const identityMatches = priorRow?.base_sha === pr.base?.sha && priorRow?.head_sha === pr.head?.sha;
    return {
      number: pr.number, title: pr.title, base_ref: pr.base?.ref, base_sha: pr.base?.sha,
      head_ref: pr.head?.ref, head_sha: pr.head?.sha, url: pr.html_url,
      disposition: identityMatches ? priorRow?.disposition?.category ?? null : null,
      disposition_reason: identityMatches ? priorRow?.disposition?.reason ?? null : null,
      disposition_identity_match: identityMatches,
      prior_base_sha: priorRow?.base_sha ?? null, prior_head_sha: priorRow?.head_sha ?? null,
    };
  }).sort((a, b) => a.number - b.number);
}

function currentMainCi(mainSha) {
  const response = ghJson(`repos/${REPOSITORY}/actions/runs?head_sha=${mainSha}&per_page=100`);
  const runs = (response.workflow_runs ?? []).filter(run => run.head_sha === mainSha && run.head_branch === 'main' && run.path === '.github/workflows/ci.yml' && run.event === 'push');
  runs.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)) || b.id - a.id);
  if (!runs.length) return null;
  const run = runs[0];
  const attempt = run.run_attempt;
  const jobsResponse = ghJson(`repos/${REPOSITORY}/actions/runs/${run.id}/attempts/${attempt}/jobs?per_page=100`);
  const job = (jobsResponse.jobs ?? []).find(item => item.name === 'ci-gate' && item.head_sha === mainSha && item.run_attempt === attempt);
  return { run_id: run.id, attempt, head_sha: run.head_sha, workflow_path: run.path, event: run.event, branch: run.head_branch, status: run.status, conclusion: run.conclusion, url: run.html_url,
    job: job ? { id: job.id, name: job.name, head_sha: job.head_sha, conclusion: job.conclusion, attempt: job.run_attempt, url: job.html_url } : null };
}

function historicalMainCi(acceptance) {
  const stored = acceptance.final_main_ci;
  const run = ghJson(`repos/${REPOSITORY}/actions/runs/${stored.run_id}`);
  const attempt = stored.attempt;
  const jobs = ghJson(`repos/${REPOSITORY}/actions/runs/${stored.run_id}/attempts/${attempt}/jobs?per_page=100`);
  const job = (jobs.jobs ?? []).find(item => item.name === 'ci-gate' && item.id === Number(stored.ci_gate?.job_id));
  return { run_id: run.id, attempt: run.run_attempt, head_sha: run.head_sha, workflow_path: run.path, conclusion: run.conclusion, url: run.html_url,
    job: job ? { id: job.id, name: job.name, head_sha: job.head_sha, conclusion: job.conclusion, attempt: job.run_attempt, url: job.html_url } : null };
}

function publicProof(receipt) {
  const sourceCheck = validateSourceReference(receipt.source_reference);
  if (!sourceCheck.valid) return { verdict: 'blocked', version: null, tag: 'v1.6.0', package_source_sha: null,
    checksum: null, expected_checksum: receipt.hex?.checksum ?? null, hex_url: receipt.hex?.package_url ?? null,
    versioned_docs_url: 'https://sigra.hexdocs.pm/1.6.0/Sigra.html', versioned_docs_status: 'not_requested',
    source_url: receipt.source_reference?.href ?? null, source_status: 'not_requested',
    source_blob_sha: receipt.source_reference?.content_blob_sha ?? null, source_url_validation: sourceCheck.reason };
  const apiBytes = runText('curl', ['-fsSL', '--max-time', '30', 'https://hex.pm/api/packages/sigra/releases/1.6.0']);
  const release = JSON.parse(apiBytes);
  const docs = runText('curl', ['-sSL', '--max-time', '30', '-o', '/dev/null', '-w', '%{http_code} %{url_effective}', 'https://sigra.hexdocs.pm/1.6.0/Sigra.html']);
  const sourceStatus = runText('curl', ['-sSL', '--max-time', '30', '--max-redirs', '0', '-o', '/dev/null', '-w', '%{http_code} %{url_effective}', '--', sourceCheck.href]);
  const tagRef = ghJson(`repos/${REPOSITORY}/git/ref/tags/v1.6.0`);
  let tagSha = tagRef.object?.sha ?? null;
  if (tagRef.object?.type === 'tag') tagSha = ghJson(`repos/${REPOSITORY}/git/tags/${tagSha}`).object?.sha ?? null;
  const apiChecksum = release.checksum ?? release?.docs?.checksum ?? null;
  const isPass = release.version === '1.6.0' && apiChecksum === receipt.hex.checksum && tagSha === PACKAGE_SOURCE
    && docs.startsWith('200 ') && sourceStatus.startsWith('200 ') && receipt.source_reference.resolved_commit_sha === PACKAGE_SOURCE;
  return { verdict: isPass ? 'passed' : 'blocked', version: release.version, tag: 'v1.6.0', package_source_sha: tagSha,
    checksum: apiChecksum, expected_checksum: receipt.hex.checksum, hex_url: receipt.hex.package_url,
    versioned_docs_url: 'https://sigra.hexdocs.pm/1.6.0/Sigra.html', versioned_docs_status: docs,
    source_url: receipt.source_reference.href, source_status: sourceStatus, source_blob_sha: receipt.source_reference.content_blob_sha };
}

export function validateSourceReference(reference) {
  const sourcePath = reference?.path;
  const href = reference?.href;
  if (typeof sourcePath !== 'string' || !/^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*$/.test(sourcePath)
    || sourcePath.split('/').some((part) => part === '.' || part === '..')) return { valid: false, reason: 'source_path_invalid' };
  if (typeof href !== 'string' || href.includes('%') || href.includes('\\') || href.includes('?')) return { valid: false, reason: 'source_url_invalid' };
  let parsed;
  try { parsed = new URL(href); } catch { return { valid: false, reason: 'source_url_invalid' }; }
  const canonical = `https://github.com/szTheory/sigra/blob/v1.6.0/${sourcePath}`;
  const allowedHash = parsed.hash === '' || /^#L[1-9][0-9]*(?:-L[1-9][0-9]*)?$/.test(parsed.hash);
  if (parsed.protocol !== 'https:' || parsed.hostname !== 'github.com' || parsed.username || parsed.password || parsed.port
    || parsed.search || !allowedHash || parsed.pathname !== `/szTheory/sigra/blob/v1.6.0/${sourcePath}`
    || href !== `${canonical}${parsed.hash}`) return { valid: false, reason: 'source_url_not_canonical' };
  return { valid: true, href };
}

export function captureSnapshot() {
  const evidenceCommit = git('rev-parse', '--verify', `${EVIDENCE_REF}^{commit}`);
  const acceptance = optionalGitJson(EVIDENCE_REF, ACCEPTANCE_PATH);
  const terminal = optionalGitJson(EVIDENCE_REF, TERMINAL_PATH);
  const acceptanceCommit = git('log', '-1', '--format=%H', EVIDENCE_REF, '--', ACCEPTANCE_PATH);
  const terminalCommit = git('log', '-1', '--format=%H', EVIDENCE_REF, '--', TERMINAL_PATH);
  const receipt = JSON.parse(fs.readFileSync(`${ROOT}/${RECEIPT_PATH}`, 'utf8'));
  const preservation = JSON.parse(fs.readFileSync(`${ROOT}/${PRESERVATION_PATH}`, 'utf8'));
  const loss = preservation.accepted_loss_paths?.find(row => row.path === ACCEPTED_LOSS.path);
  const main = ghJson(`repos/${REPOSITORY}/commits/main`).sha;
  const currentCi = currentMainCi(main);
  const currentReceipt = ghJson(`repos/${REPOSITORY}/contents/${RECEIPT_PATH}?ref=${main}`).sha;
  let ancestor = false;
  try { execFileSync('git', ['merge-base', '--is-ancestor', HISTORICAL_MAIN, main], { cwd: ROOT, stdio: 'ignore' }); ancestor = true; } catch {}
  const publicRelease = publicProof(receipt);
  const historicalCi = historicalMainCi(acceptance.value);
  const historicalReportBytes = fs.readFileSync(`${ROOT}/${OWNER_DIR}/249-VERIFICATION.md`);
  const currentInventory = { worktrees: captureWorktrees(), pull_requests: capturePullRequests(), worktrees_read_status: 'complete', pull_requests_read_status: 'complete' };
  if (currentInventory.worktrees.some(row => row.read_status !== 'complete')) currentInventory.worktrees_read_status = 'failed';
  return {
    schema_version: 1, captured_at: new Date().toISOString(), repository: REPOSITORY,
    source: { package_source_sha: receipt.package_source_sha, historical_release_main_sha: HISTORICAL_MAIN, current_protected_main_sha: main, historical_is_ancestor: ancestor },
    evidence_ref: { name: EVIDENCE_REF, commit_sha: evidenceCommit, acceptance_commit_sha: acceptanceCommit, acceptance_blob_sha: acceptance.blob_sha, acceptance_sha256: acceptance.sha256, acceptance_json_base64: acceptance.bytes.toString('base64'), acceptance: acceptance.value,
      terminal_commit_sha: terminalCommit, terminal_blob_sha: terminal.blob_sha, terminal_sha256: terminal.sha256, terminal_json_base64: terminal.bytes.toString('base64'), terminal: terminal.value },
    receipt: { path: RECEIPT_PATH, package_source_sha: receipt.package_source_sha, blob_sha: git('rev-parse', `${HISTORICAL_MAIN}:${RECEIPT_PATH}`), sha256: hash(run('git', ['show', `${HISTORICAL_MAIN}:${RECEIPT_PATH}`])), current_blob_sha: currentReceipt },
    public_release: publicRelease,
    historical_ci: historicalCi,
    current_ci: currentCi,
    inventory: currentInventory,
    historical_report: { path: `${OWNER_DIR}/249-VERIFICATION.md`, sha256: hash(Buffer.from(historicalReportBytes.toString('utf8').trimEnd())), raw_bytes_sha256: hash(historicalReportBytes), raw_bytes_base64: historicalReportBytes.toString('base64'), captured_at: new Date().toISOString() },
    accepted_loss: loss ? { ...ACCEPTED_LOSS, bytes_recovered: loss.disposition?.bytes_recovered ?? false, bytes_preserved: loss.disposition?.bytes_preserved ?? false } : null,
  };
}

function renderReport(snapshot) {
  const evaluation = evaluateSnapshot(snapshot);
  const identity = reportIdentity(snapshot, evaluation);
  const status = Object.values(evaluation.requirements).every(row => row.status === 'satisfied') ? 'passed' : 'gaps_found';
  const historical = Buffer.from(snapshot.historical_report?.raw_bytes_base64 ?? '', 'base64');
  const historicalText = historical.toString('utf8');
  const lines = [
    '---', 'phase: 249-publish-and-prove-sigra-1-6-0', `verified: ${snapshot.captured_at}`, `status: ${status}`,
    `source_snapshot: ${PHASE_DIR}/250-249-SOURCE-SNAPSHOT.json`, 'owner_requirements: [REL-01, REL-02]', '---', '',
    '# Phase 249: Publish and Prove Sigra 1.6.0 Verification Report', '',
    '**Phase Goal:** Adopters can install documented Sigra 1.6.0, and maintainers can trace it to the exact gated source while finishing in a clean repository state.',
    `**Verified:** ${snapshot.captured_at}`, `**Status:** ${status}`, '**Re-verification:** Yes — independently joined the terminal acceptance ref and fresh public/main/inventory evidence.', '',
    `<!-- phase249-evidence ${JSON.stringify(identity)} -->`, '', '## Current Evidence Boundary', '',
    `- **REL-01: ${evaluation.requirements['REL-01'].status}.** Hex 1.6.0, versioned docs, source URL, checksum, and tag resolve to package source \`${snapshot.source.package_source_sha}\`. Historical acceptance is \`${snapshot.evidence_ref.name}\` at ${snapshot.evidence_ref.commit_sha}; its acceptance blob ${snapshot.evidence_ref.acceptance_blob_sha} and passing terminal record validate against historical release main ${snapshot.source.historical_release_main_sha}. Exact historical ci-gate: run ${snapshot.historical_ci.run_id}, attempt ${snapshot.historical_ci.attempt}, job ${snapshot.historical_ci.job?.id}.`,
    `- **REL-02: ${evaluation.requirements['REL-02'].status}.** Current protected main ${snapshot.source.current_protected_main_sha} is recorded separately. Its exact ci-gate is run ${snapshot.current_ci?.run_id ?? 'missing'}, attempt ${snapshot.current_ci?.attempt ?? 'missing'}, job ${snapshot.current_ci?.job?.id ?? 'missing'} (${snapshot.current_ci?.job?.conclusion ?? 'missing'}); the containing CI run concluded ${snapshot.current_ci?.conclusion ?? 'missing'}. The current receipt blob is ${snapshot.receipt.current_blob_sha}. Fresh inventory has ${snapshot.inventory.worktrees.length} registered worktrees and ${snapshot.inventory.pull_requests.length} open PRs.`,
    '', '## Accepted historical loss', '',
    `The exact historical \`${snapshot.accepted_loss.path}\` revision is accepted-with-recorded-loss under the user's authorization dated ${snapshot.accepted_loss.authorized_at}: “${snapshot.accepted_loss.authorization}.” Its identity is SHA-256 \`${snapshot.accepted_loss.sha256}\`; those historical bytes were not recovered and were not preserved.`,
    '', '## Current blockers', '', ...(evaluation.blockers.length ? evaluation.blockers.map(row => `- ${row}`) : ['- None.']), '',
    '## Historical verification context', '',
    'The earlier `gaps_found` report records the state before the later terminal acceptance ref and current post-canary main. Its historical observations remain unchanged; this report uses the new immutable acceptance identity and freshly observed current PR/worktree state.', '',
    '<details>', '<summary>Historical Phase 249 report preserved verbatim</summary>', '', '`````markdown',
    historicalText.endsWith('\n') ? historicalText.slice(0, -1) : historicalText,
    '`````', '</details>', '',
  ];
  return lines.join('\n');
}

function main() {
  const args = process.argv.slice(2);
  if (args[0] === '--capture') {
    const snapshot = captureSnapshot();
    fs.writeFileSync(`${ROOT}/${SNAPSHOT_PATH}`, `${JSON.stringify(snapshot, null, 2)}\n`);
    const evaluation = evaluateSnapshot(snapshot);
    console.log(JSON.stringify({ snapshot: SNAPSHOT_PATH, requirements: evaluation.requirements }, null, 2));
    if (Object.values(evaluation.requirements).some(row => row.status === 'unsatisfied')) process.exitCode = 1;
    return;
  }
  const snapshot = JSON.parse(fs.readFileSync(`${ROOT}/${SNAPSHOT_PATH}`, 'utf8'));
  if (args[0] === '--write-report') {
    const target = args[1];
    fs.writeFileSync(`${ROOT}/${target}`, renderReport(snapshot));
    console.log(JSON.stringify({ report: target, requirements: evaluateSnapshot(snapshot).requirements }, null, 2));
    return;
  }
  if (args[0] === '--check-report') {
    const target = args[1];
    const fresh = captureSnapshot();
    const errors = [...checkReport(fs.readFileSync(`${ROOT}/${target}`, 'utf8'), snapshot), ...freshnessErrors(snapshot, fresh)];
    if (errors.length) { console.error(JSON.stringify({ status: 'fail', errors })); process.exitCode = 1; return; }
    console.log(JSON.stringify({ status: 'pass', requirements: evaluateSnapshot(snapshot).requirements }));
    return;
  }
  const result = evaluateSnapshot(snapshot);
  console.log(JSON.stringify(result, null, 2));
  if (result.blockers.length) process.exitCode = 1;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
