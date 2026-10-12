import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { evaluateSnapshot as evaluate248, checkReport as check248Report } from './verify-248-release.mjs';
import { evaluateSnapshot as evaluate249, checkReport as check249Report } from './verify-249-release.mjs';

const OWNER_PHASE = {
  'CONF-01': '246', 'CONF-02': '246', 'CONF-03': '246',
  'READY-01': '247', 'READY-02': '247',
  'AUTO-01': '248', 'AUTO-02': '248',
  'REL-01': '249', 'REL-02': '249',
};
const OWNER_DIR = {
  '246': '246-generated-confirmation-recovery',
  '247': '247-release-candidate-and-repository-readiness',
  '248': '248-exact-source-release-gate',
  '249': '249-publish-and-prove-sigra-1-6-0',
};
const MILESTONE_PHASES = [246, 247, 248, 249, 250, 251];
const TRACE_PATH = '.planning/REQUIREMENTS.md';
const CLOSE_DIR = '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat';
const AUDIT_PATH = '.planning/v1.49-MILESTONE-AUDIT.md';
const ACCEPTANCE_PATH = CLOSE_DIR + '/250-ACCEPTANCE-AMENDMENT.json';
const PHASE251_DIR = '.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps';
const PHASE251_PACKET_PATH = PHASE251_DIR + '/251-247-RECONCILIATION.json';
const PHASE251_FEASIBILITY_PATH = PHASE251_DIR + '/251-EVIDENCE-FEASIBILITY.json';
const PHASE251_HISTORICAL_OWNER_COMMIT = '0e7a2835ebd0d7a1e791ad4dbc73955270108ed1';
const ACCEPTED_READY_IDS = ['READY-01', 'READY-02'];
const ACCEPTED_READY_BLOCKER_IDS = [
  'authorization_pending',
  'candidate_diff_digest_missing',
  'dry_run_tuple_mismatch',
  'exact_head_ci_source_missing',
  'fresh_inherited_dispositions_missing',
  'fresh_pr_dispositions_incomplete',
  'live_candidate_tuple_changed',
  'readiness_tuple_mismatch',
];

const PHASE251_PACKAGE_CHECK_SOURCES = {
  package_version: [['candidate', 'mix.exs', 'candidate_version_1_6_0'], ['published', 'mix.exs', 'published_version_1_6_0']],
  package_metadata: [['candidate', 'mix.exs', 'candidate_package_metadata_sigra_1_6_0'], ['published', 'mix.exs', 'published_package_metadata_sigra_1_6_0']],
  release_manifest: [['candidate', '.release-please-manifest.json', 'manifest_version_1_6_0']],
  release_config: [['candidate', 'release-please-config.json', 'release_config_elixir_changelog']],
  changelog: [['candidate', 'CHANGELOG.md', 'candidate_changelog_1_6_0'], ['published', 'CHANGELOG.md', 'published_changelog_1_6_0']],
  tag_target: [['published', 'mix.exs', 'tag_v1_6_0_targets_published_commit']],
  hexdocs_source_reference: [['published', 'mix.exs', 'hexdocs_uses_version_source_ref'], ['published', 'lib/sigra.ex', 'published_module_source']],
  published_tag_guide: [['published', 'guides/introduction/upgrading-to-v1.6.md', 'published_guide_present']],
  readme_guide_link: [['candidate', 'README.md', 'candidate_readme_guide_link'], ['published', 'README.md', 'published_readme_guide_link']],
  adopter_shipped_changes: [['candidate', 'guides/introduction/upgrading-to-v1.6.md', 'guide_shipped_changes'], ['candidate', 'test/example/priv/playwright/tests/organizations.spec.ts', 'generated_host_regression_coverage']],
  adopter_compatibility: [['candidate', 'guides/introduction/upgrading-to-v1.6.md', 'guide_compatibility_constraints']],
  generated_host_action: [['candidate', 'guides/introduction/upgrading-to-v1.6.md', 'guide_host_actions'], ['candidate', 'test/example/priv/playwright/tests/organizations.spec.ts', 'host_action_test_coverage']],
  version_requirement: [['candidate', 'guides/introduction/upgrading-to-v1.6.md', 'guide_version_requirement'], ['candidate', 'mix.exs', 'candidate_package_version_requirement']],
  update_check_path: [['candidate', 'guides/introduction/upgrading-to-v1.6.md', 'guide_update_and_check_steps'], ['candidate', 'README.md', 'readme_points_to_upgrade_guide']],
};

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function readSource(root, relative, overrides = {}) {
  if (Object.hasOwn(overrides, relative)) {
    const override = overrides[relative];
    if (override === null) return null;
    const original = existsSync(path.join(root, relative)) ? readFileSync(path.join(root, relative), 'utf8') : '';
    return typeof override === 'function' ? override(original) : override;
  }
  const absolute = path.join(root, relative);
  return existsSync(absolute) ? readFileSync(absolute, 'utf8') : null;
}

function readHistoricalSource(root, commit, relative, overrides = {}) {
  const key = `git:${commit}:${relative}`;
  if (Object.hasOwn(overrides, key)) {
    const override = overrides[key];
    if (override === null) return null;
    let original = null;
    try {
      original = execFileSync('git', ['show', `${commit}:${relative}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    } catch { /* a missing commit or path is an unavailable historical source */ }
    return typeof override === 'function' ? override(original ?? '') : override;
  }
  try {
    return execFileSync('git', ['show', `${commit}:${relative}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  } catch {
    return null;
  }
}

function normalizedRequirementVerdict(value) {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (normalized === 'satisfied' || normalized === 'passed' || normalized === 'complete') return 'satisfied';
  if (normalized === 'unsatisfied' || normalized === 'authorization_pending' || normalized === 'partial' || normalized === 'gaps_found') return 'unsatisfied';
  return 'missing';
}

function reportRequirementVerdict(text, id) {
  const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return text.match(new RegExp(`^\\|\\s*${escaped}\\s*\\|\\s*([^|]+)\\|`, 'm'))?.[1]?.trim() ?? null;
}

function readJson(root, relative, blockers, overrides) {
  const text = readSource(root, relative, overrides);
  if (text === null) {
    blockers.push({ id: 'SOURCE', message: `Missing source artifact ${relative}.`, identity: relative });
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    blockers.push({ id: 'SOURCE', message: `Malformed JSON in ${relative}: ${error.message}`, identity: relative });
    return null;
  }
}

function reportStatus(text) {
  const frontmatter = text.match(/^---\s*\n([\s\S]*?)\n---/);
  const frontStatus = frontmatter?.[1].match(/^status:\s*([\w-]+)/m)?.[1];
  const proseStatus = text.match(/^\s*- \*\*Status:\*\*\s*([\w-]+)/m)?.[1];
  if (frontStatus || proseStatus) return (frontStatus || proseStatus).toLowerCase();
  if (/<!--\s*phase-251-reconciliation:/.test(text)) {
    const readyVerdicts = ['READY-01', 'READY-02'].map((id) => normalizedRequirementVerdict(reportRequirementVerdict(text, id)));
    return readyVerdicts.every((status) => status === 'satisfied') ? 'passed' : 'gaps_found';
  }
  return 'missing';
}

function yamlRequirementClaims(text) {
  const frontmatter = text.match(/^---\s*\n([\s\S]*?)\n---/);
  if (!frontmatter) return [];
  const field = frontmatter[1].match(/^requirements-completed:\s*(.*)$/m)?.[1]?.trim() ?? '';
  if (field === '[]' || field === '' || field === 'null') return [];
  return [...field.matchAll(/[A-Z]+-\d+/g)].map((match) => match[0]);
}

function htmlJson(text, marker) {
  const match = text.match(new RegExp(`<!--\\s*${marker}\\s*(\\{[^\\n]*?\\})\\s*-->`));
  if (!match) return null;
  try { return JSON.parse(match[1]); } catch { return null; }
}

function add(blockers, id, message, identity = null) {
  blockers.push({ id, message, ...(identity === null ? {} : { identity }) });
}

function readAcceptanceAmendment(root, blockers, overrides = {}) {
  const text = readSource(root, ACCEPTANCE_PATH, overrides);
  if (text === null) {
    add(blockers, 'ACCEPTANCE', 'Missing the Phase 250 acceptance amendment.', ACCEPTANCE_PATH);
    return { valid: false, hash: null, ids: [], historicalSource: null };
  }

  let amendment;
  try {
    amendment = JSON.parse(text);
  } catch (error) {
    add(blockers, 'ACCEPTANCE', 'Malformed Phase 250 acceptance amendment: ' + error.message, ACCEPTANCE_PATH);
    return { valid: false, hash: sha256(text), ids: [], historicalSource: null };
  }

  const sourcePath = '.planning/phases/' + OWNER_DIR['247'] + '/247-VERIFICATION.md';
  const reconciliationPath = CLOSE_DIR + '/250-247-RECONCILIATION.json';
  const packetPath = CLOSE_DIR + '/250-247-TUPLE-DECISION-PACKET.json';
  const historicalCommit = amendment.pre_amendment_commit;
  const historicalOwnerText = typeof historicalCommit === 'string'
    ? readHistoricalSource(root, historicalCommit, sourcePath, overrides) : null;
  const historicalReconciliationText = typeof historicalCommit === 'string'
    ? readHistoricalSource(root, historicalCommit, reconciliationPath, overrides) : null;
  const historicalPacketText = typeof historicalCommit === 'string'
    ? readHistoricalSource(root, historicalCommit, packetPath, overrides) : null;
  const currentReconciliationText = readSource(root, reconciliationPath, overrides);
  const currentPacketText = readSource(root, packetPath, overrides);
  let reconciliation = null;
  if (historicalReconciliationText !== null) {
    try { reconciliation = JSON.parse(historicalReconciliationText); } catch {
      add(blockers, 'ACCEPTANCE', 'The cited Phase 247 reconciliation is malformed.', reconciliationPath);
    }
  }
  const actualIds = [...new Set((reconciliation?.blockers ?? []).map(({ id }) => id))].sort();
  const expectedIds = [...ACCEPTED_READY_BLOCKER_IDS].sort();
  const exactIds = (left, right) => JSON.stringify(left) === JSON.stringify(right);
  const exceptionRows = Array.isArray(amendment.exceptions) ? amendment.exceptions : [];
  const exactExceptionIds = exceptionRows.map((row) => row?.id).sort();
  const historicalHashes = {
    ownerReportSha256: historicalOwnerText === null ? null : sha256(historicalOwnerText),
    reconciliationSha256: historicalReconciliationText === null ? null : sha256(historicalReconciliationText),
    tuplePacketSha256: historicalPacketText === null ? null : sha256(historicalPacketText),
  };
  const historicalSourcesAvailable = Object.values(historicalHashes).every(Boolean);
  const historicalSourcesUnchanged = historicalSourcesAvailable
    && currentReconciliationText !== null
    && currentPacketText !== null
    && sha256(currentReconciliationText) === historicalHashes.reconciliationSha256
    && sha256(currentPacketText) === historicalHashes.tuplePacketSha256;
  const valid =
    amendment.schema_version === 1
    && amendment.record_type === 'phase_acceptance_amendment'
    && amendment.phase === 250
    && amendment.approval?.source === 'user decision in the active conversation'
    && amendment.approval?.approved_scope === 'Phase 250 acceptance and audit bookkeeping only'
    && typeof amendment.approval?.basis === 'string'
    && amendment.approval.basis.includes('READY-01')
    && amendment.approval.basis.includes('READY-02')
    && amendment.revised_phase_acceptance?.phase_only === true
    && amendment.revised_phase_acceptance?.accepted_exception_ids?.join(',') === ACCEPTED_READY_IDS.join(',')
    && amendment.revised_phase_acceptance?.verified_requirement_count === 7
    && amendment.revised_phase_acceptance?.total_requirement_count === 9
    && amendment.revised_phase_acceptance?.owner_verdicts_remain_unsatisfied === true
    && amendment.revised_phase_acceptance?.requirement_checkboxes_remain_unchecked === true
    && amendment.revised_phase_acceptance?.milestone_pass_claim === false
    && amendment.revised_phase_acceptance?.milestone_archived === false
    && exactIds(exactExceptionIds, [...ACCEPTED_READY_IDS].sort())
    && exactIds(actualIds, expectedIds)
    && exactIds((Array.isArray(amendment.accepted_reconciliation_blocker_ids) ? amendment.accepted_reconciliation_blocker_ids : []).slice().sort(), expectedIds)
    && reconciliation?.status === 'blocked'
    && historicalCommit === PHASE251_HISTORICAL_OWNER_COMMIT
    && historicalSourcesAvailable
    && historicalHashes.ownerReportSha256 === exceptionRows[0]?.source_sha256
    && historicalSourcesUnchanged
    && exceptionRows.every((row) => row && (
      row.owner_phase === 247
      && row.owner_verdict === 'unsatisfied'
      && row.acceptance === 'accepted_exception'
      && row.source === sourcePath
      && row.source_sha256 === historicalHashes.ownerReportSha256
      && row.reconciliation === reconciliationPath
      && row.reconciliation_sha256 === historicalHashes.reconciliationSha256
      && row.tuple_packet === packetPath
      && row.tuple_packet_sha256 === historicalHashes.tuplePacketSha256
    ));

  if (!valid) {
    add(blockers, 'ACCEPTANCE', 'Phase 250 historical amendment cannot be verified against its immutable owner report, reconciliation, and tuple packet sources.', {
      path: ACCEPTANCE_PATH,
      amendmentSha256: sha256(text),
      historicalCommit: historicalCommit ?? null,
      historicalSourcesAvailable,
      historicalSourcesUnchanged,
      actualExceptionIds: exactExceptionIds,
      actualReconciliationBlockerIds: actualIds,
    });
  }
  return {
    valid,
    hash: sha256(text),
    ids: valid ? [...ACCEPTED_READY_IDS] : [],
    historicalSource: valid ? {
      commit: historicalCommit,
      ownerReportPath: sourcePath,
      ownerReportSha256: historicalHashes.ownerReportSha256,
      reconciliationPath,
      reconciliationSha256: historicalHashes.reconciliationSha256,
      tuplePacketPath: packetPath,
      tuplePacketSha256: historicalHashes.tuplePacketSha256,
    } : null,
  };
}

function canaryProofMatchesSnapshot(proof, snapshot, proofHash) {
  const canary = snapshot?.canary;
  const failure = canary?.failure;
  const cancellation = canary?.cancellation;
  const failureRetrieved = failure?.artifact_retrieved;
  const cancellationRetrieved = cancellation?.artifact_retrieved;
  const failureReceipt = failureRetrieved?.receipt;
  const cancellationReceipt = cancellationRetrieved?.receipt;
  const sameReceipt = (left, right) => JSON.stringify(left) === JSON.stringify(right);
  const failureOk =
    failureRetrieved?.status === 'passed'
    && String(proof?.source_failure?.run_id) === String(failure?.run?.id)
    && String(proof?.source_failure?.attempt) === String(failure?.run?.attempt)
    && String(proof?.source_failure?.workflow_id) === String(failure?.run?.workflow_id)
    && proof?.source_failure?.conclusion === 'failure'
    && String(proof?.source_failure?.artifact?.id) === String(failureRetrieved?.artifact_id)
    && proof?.source_failure?.artifact?.digest === failureRetrieved?.artifact_digest
    && sameReceipt(proof?.source_failure?.receipt, failureReceipt)
    && failureReceipt?.scenario === 'failure'
    && failureReceipt?.terminal_verdict === 'failure'
    && String(failureReceipt?.source_run_id) === String(failure?.run?.id);
  const cancellationOk =
    cancellationRetrieved?.status === 'passed'
    && String(proof?.source_cancellation?.run_id) === String(cancellation?.run?.id)
    && String(proof?.source_cancellation?.attempt) === String(cancellation?.run?.attempt)
    && String(proof?.source_cancellation?.workflow_id) === String(cancellation?.run?.workflow_id)
    && proof?.source_cancellation?.conclusion === 'cancelled'
    && String(proof?.source_cancellation?.artifact?.id) === String(cancellationRetrieved?.artifact_id)
    && proof?.source_cancellation?.artifact?.digest === cancellationRetrieved?.artifact_digest
    && sameReceipt(proof?.source_cancellation?.receipt, cancellationReceipt)
    && cancellationReceipt?.scenario === 'cancellation'
    && cancellationReceipt?.terminal_verdict === 'cancelled'
    && String(cancellationReceipt?.source_run_id) === String(cancellation?.run?.id)
    && proof?.source_cancellation?.observer_conclusion === 'success'
    && String(proof?.source_cancellation?.observer_run_id) === String(cancellation?.observer?.run_id);
  return canary?.proof_status === 'passed'
    && canary?.proof_sha256 === proofHash
    && canary?.credential_values_recorded === false
    && proof?.status === 'pass'
    && proof?.credential_values_recorded === false
    && failureOk
    && cancellationOk;
}

function scanSummaryClaims(root, overrides = {}) {
  const phasesRoot = path.join(root, '.planning/phases');
  const claims = [];
  for (const directory of readdirSync(phasesRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory())) {
    const phase = directory.name.match(/^(\d+)/)?.[1];
    for (const file of readdirSync(path.join(phasesRoot, directory.name)).filter((name) => name.endsWith('-SUMMARY.md'))) {
      const relative = `.planning/phases/${directory.name}/${file}`;
      const text = readSource(root, relative, overrides);
      if (text === null) continue;
      for (const requirement of yamlRequirementClaims(text)) claims.push({ requirement, phase, file: relative });
    }
  }
  return claims;
}

function discoverNyquist(root, overrides = {}) {
  const phasesRoot = path.join(root, '.planning/phases');
  const compliantPhases = [];
  const partialPhases = [];
  const notValidatedPhases = [];
  const missingPhases = [];
  const rows = [];

  for (const phase of MILESTONE_PHASES) {
    const directory = readdirSync(phasesRoot, { withFileTypes: true })
      .find((entry) => entry.isDirectory() && entry.name.startsWith(`${phase}-`));
    if (!directory) {
      missingPhases.push(phase);
      rows.push({ phase, status: 'missing', path: null, sha256: null });
      continue;
    }

    const validationPath = `.planning/phases/${directory.name}/${phase}-VALIDATION.md`;
    const text = readSource(root, validationPath, overrides);
    if (text === null) {
      missingPhases.push(phase);
      rows.push({ phase, status: 'missing', path: validationPath, sha256: null });
      continue;
    }

    const frontmatter = text.match(/^---\s*\n([\s\S]*?)\n---/m)?.[1] ?? '';
    const status = frontmatter.match(/^status:\s*([^\s#]+)/m)?.[1]?.toLowerCase() ?? 'draft';
    const nyquist = frontmatter.match(/^nyquist_compliant:\s*(true|false)\s*$/mi)?.[1]?.toLowerCase();
    const waveZero = frontmatter.match(/^wave_0_complete:\s*(true|false)\s*$/mi)?.[1]?.toLowerCase();
    let classification;
    if (status !== 'validated') {
      classification = 'not_validated';
      notValidatedPhases.push(phase);
    } else if (nyquist === 'true' && waveZero === 'true') {
      classification = 'compliant';
      compliantPhases.push(phase);
    } else {
      classification = 'partial';
      partialPhases.push(phase);
    }
    rows.push({ phase, status: classification, path: validationPath, sha256: sha256(text) });
  }

  return {
    compliantPhases,
    partialPhases,
    notValidatedPhases,
    missingPhases,
    overall: partialPhases.length || notValidatedPhases.length || missingPhases.length ? 'partial' : 'compliant',
    rows,
  };
}

function requirementRows(requirementsText) {
  const rows = new Map();
  for (const match of requirementsText.matchAll(/^- \[([ xX])\] \*\*([A-Z]+-\d+)\*\*:\s*(.*)$/gm)) {
    const id = match[2];
    rows.set(id, { checked: match[1].toLowerCase() === 'x', description: match[3].trim() });
  }
  return rows;
}

function reportRequirementStatus(phase, id, text, parsed) {
  if (!text) return 'missing';
  const overall = reportStatus(text);
  const packetKey = id.replace('-', '');
  const specific = parsed?.requirement_verdicts?.[id]
    ?? parsed?.requirements?.[packetKey]?.verdict
    ?? parsed?.requirements?.[id];
  if (typeof specific === 'string') return normalizedRequirementVerdict(specific);
  if (specific?.status) return normalizedRequirementVerdict(specific.status);
  const table = phase === '247' ? reportRequirementVerdict(text, id) : null;
  if (table) return normalizedRequirementVerdict(table);
  if (overall === 'passed') return 'satisfied';
  return 'unsatisfied';
}

function exactStringSet(actual, expected) {
  return Array.isArray(actual)
    && Array.isArray(expected)
    && actual.length === expected.length
    && new Set(actual).size === actual.length
    && actual.every((value) => expected.includes(value));
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

const preservationRecordCache = new Set();
const preservationRefResolutionCache = new Map();

function preservationRecordsMatch(root, references, observedIds, dispositions, dirtyItems) {
  if (!Array.isArray(references) || !exactStringSet(references.map((row) => row?.id), observedIds)) return false;
  if (!Array.isArray(dispositions) || !exactStringSet(dispositions.map((row) => row?.id), observedIds)) return false;
  if (!references.every((row) => typeof row.ref === 'string' && typeof row.commitSha === 'string'
    && /^[a-f0-9]{40}$/.test(row.commitSha) && typeof row.recordPath === 'string'
    && /^records\/[A-Za-z0-9._/-]+\.json$/.test(row.recordPath)
    && typeof row.recordSha256 === 'string' && /^[a-f0-9]{64}$/.test(row.recordSha256))) return false;

  const dispositionById = new Map(dispositions.map((row) => [row.id, row]));
  const dirtyById = new Map((Array.isArray(dirtyItems) ? dirtyItems : []).map((row) => [row.id, row]));
  const cacheKey = `${root}\0${sha256(JSON.stringify({ references, dispositions, dirtyItems }))}`;
  if (preservationRecordCache.has(cacheKey)) return true;

  const resolvedReferences = [];
  for (const reference of references) {
    const refKey = `${root}\0${reference.ref}`;
    let resolved = preservationRefResolutionCache.get(refKey);
    if (resolved === undefined) {
      try { resolved = execFileSync('git', ['rev-parse', '--verify', `${reference.ref}^{commit}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); }
      catch { resolved = null; }
      preservationRefResolutionCache.set(refKey, resolved);
    }
    if (resolved !== reference.commitSha) return false;
    resolvedReferences.push({ ...reference, resolvedCommit: resolved });
  }
  const input = resolvedReferences.map(({ resolvedCommit, recordPath }) => `${resolvedCommit}:${recordPath}`).join('\n') + '\n';
  let output;
  try {
    output = execFileSync('git', ['cat-file', '--batch'], { cwd: root, input, encoding: null, maxBuffer: 64 * 1024 * 1024, stdio: ['pipe', 'pipe', 'ignore'] });
  } catch { return false; }

  let offset = 0;
  for (const reference of resolvedReferences) {
    const disposition = dispositionById.get(reference.id);
    const capturedItem = dirtyById.get(reference.id);
    const isCapturedDirtyPath = capturedItem?.kind === 'dirty_path';
    if (capturedItem && !isCapturedDirtyPath) return false;
    const dirtyItem = isCapturedDirtyPath ? capturedItem : null;
    const expectedReference = disposition?.preservation_ref;
    if (!disposition || typeof disposition.decision !== 'string' || !disposition.decision
      || typeof disposition.reason !== 'string' || !disposition.reason
      || !disposition.source || typeof disposition.source !== 'object'
      || reference.ref !== expectedReference?.ref
      || reference.commitSha !== expectedReference?.commit_sha
      || reference.recordPath !== expectedReference?.record_path
      || reference.recordSha256 !== expectedReference?.record_sha256) return false;
    if (isCapturedDirtyPath) {
      const source = disposition.source;
      if (typeof capturedItem.worktree_path !== 'string' || !capturedItem.worktree_path
        || !/^[a-f0-9]{40}$/.test(capturedItem.worktree_head_sha ?? '')
        || typeof capturedItem.worktree_branch !== 'string' || !capturedItem.worktree_branch
        || typeof capturedItem.status !== 'string' || !capturedItem.status
        || typeof capturedItem.path !== 'string' || !capturedItem.path
        || !(capturedItem.original_path === null || typeof capturedItem.original_path === 'string')
        || capturedItem.source_byte_readable !== true
        || !/^[a-f0-9]{64}$/.test(capturedItem.source_byte_sha256 ?? '')
        || source.worktree_path !== capturedItem.worktree_path
        || source.head_sha !== capturedItem.worktree_head_sha
        || source.status !== capturedItem.status
        || source.path !== capturedItem.path
        || (source.kind !== undefined && source.kind !== 'dirty_path')
        || (source.worktree_branch !== undefined && source.worktree_branch !== capturedItem.worktree_branch)
        || (source.original_path !== undefined && source.original_path !== capturedItem.original_path)) return false;
    } else if (disposition.source.worktree_path || disposition.source.kind === 'dirty_path') return false;
    const headerEnd = output.indexOf(0x0a, offset);
    if (headerEnd < 0) return false;
    const header = output.toString('utf8', offset, headerEnd).split(' ');
    if (header.length !== 3 || header[1] !== 'blob' || !/^\d+$/.test(header[2])) return false;
    const size = Number(header[2]);
    const contentStart = headerEnd + 1;
    const contentEnd = contentStart + size;
    if (contentEnd >= output.length || output[contentEnd] !== 0x0a) return false;
    const content = output.subarray(contentStart, contentEnd);
    offset = contentEnd + 1;
    if (sha256(content) !== reference.recordSha256) return false;
    let record;
    try { record = JSON.parse(content.toString('utf8')); } catch { return false; }
    if (record?.id !== reference.id || record.decision !== disposition.decision
      || record.reason !== disposition.reason
      || stableJson(record.source) !== stableJson(disposition.source)
      || (record.source_byte_sha256 ?? null) !== (dirtyItem?.source_byte_sha256 ?? null)
      || !record.captured_source || record.captured_source.id !== disposition.id
      || (isCapturedDirtyPath
        ? (record.kind !== 'dirty_path' || record.captured_source.kind !== 'dirty_path'
          || record.captured_source.worktree_path !== disposition.source.worktree_path
          || record.captured_source.worktree_head_sha !== disposition.source.head_sha
          || record.captured_source.status !== disposition.source.status
          || record.captured_source.path !== disposition.source.path
          || record.captured_source.worktree_branch !== dirtyItem.worktree_branch
          || (record.captured_source.original_path ?? null) !== (dirtyItem.original_path ?? null)
          || (record.captured_source.source_byte_sha256 ?? null) !== (dirtyItem?.source_byte_sha256 ?? null)
          )
        : disposition.source.path
          ? (record.captured_source.kind !== 'committed_path' || record.captured_source.source_commit_sha !== disposition.source.commit_sha
            || record.captured_source.path !== disposition.source.path)
          : (record.captured_source.kind !== 'commit' || record.captured_source.commit_sha !== disposition.source.commit_sha))) return false;
    if (isCapturedDirtyPath) {
      const encoded = record.source_bytes_base64;
      if (typeof encoded !== 'string' || encoded.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) return false;
      const sourceBytes = Buffer.from(encoded, 'base64');
      if (sourceBytes.toString('base64') !== encoded
        || dirtyItem?.source_byte_readable !== true
        || !/^[a-f0-9]{64}$/.test(dirtyItem?.source_byte_sha256 ?? '')
        || sha256(sourceBytes) !== record.source_byte_sha256
        || sha256(sourceBytes) !== dirtyItem.source_byte_sha256) return false;
      if (capturedItem.status.includes('D')) {
        const tombstone = record.source_absence_proof;
        if (!tombstone || tombstone.kind !== 'worktree-deletion-tombstone'
          || tombstone.worktree_path !== capturedItem.worktree_path
          || tombstone.head_sha !== capturedItem.worktree_head_sha
          || tombstone.status !== capturedItem.status
          || tombstone.path !== capturedItem.path
          || tombstone.source_byte_sha256 !== sha256(sourceBytes)
          || record.captured_source.status !== capturedItem.status
          || record.captured_source.path !== capturedItem.path
          || record.captured_source.worktree_head_sha !== capturedItem.worktree_head_sha) return false;
      } else if (record.source_absence_proof !== undefined) return false;
    }
  }
  if (offset !== output.length) return false;
  preservationRecordCache.add(cacheKey);
  return true;
}

function readyOwnerEvidenceRows(text) {
  const rows = new Map();
  const header = '| Requirement | Phase | Status | Owner Report | Current Packet | Packet SHA-256 |';
  if (!text.includes(header)) return rows;
  for (const line of text.split('\n')) {
    const match = line.match(/^\|\s*(READY-0[12])\s*\|\s*Phase 247\s*\|[^|]*\|\s*([^|]+)\|\s*([^|]+)\|\s*([a-f0-9]{64})\s*\|$/);
    if (match) rows.set(match[1], { ownerReport: match[2].trim(), packet: match[3].trim(), packetSha256: match[4] });
  }
  return rows;
}

function validateReadyOwnerEvidenceRows(text, owner, blockers) {
  const rows = readyOwnerEvidenceRows(text);
  for (const id of ACCEPTED_READY_IDS) {
    const row = rows.get(id);
    if (!row || row.ownerReport !== owner?.path || row.packet !== PHASE251_PACKET_PATH
      || row.packetSha256 !== owner?.reconciliationSha256) {
      add(blockers, id, 'REQUIREMENTS.md traceability row lacks the exact Phase 247 owner report reference and current Phase 251 packet path/digest.', {
        expected: { ownerReport: owner?.path, packet: PHASE251_PACKET_PATH, packetSha256: owner?.reconciliationSha256 ?? null },
        actual: row ?? null,
      });
    }
  }
  return rows;
}

const phase251PackageBytesCache = new Map();

function phase251ExactPackageBytes(root, source) {
  if (!source || typeof source.commit_sha !== 'string' || typeof source.path !== 'string'
    || source.read_status !== 'readable' || source.trust_status !== 'trusted_exact_api_blob_match') return null;
  const cacheKey = `${root}\0${source.commit_sha}\0${source.path}\0${source.git_blob_oid}\0${source.sha256}`;
  if (phase251PackageBytesCache.has(cacheKey)) return phase251PackageBytesCache.get(cacheKey);
  try {
    const blobOid = execFileSync('git', ['rev-parse', `${source.commit_sha}:${source.path}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    const bytes = execFileSync('git', ['show', `${source.commit_sha}:${source.path}`], { cwd: root, encoding: 'buffer', maxBuffer: 16 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] });
    const verified = blobOid === source.git_blob_oid && blobOid === source.api_blob_oid
      && sha256(bytes) === source.sha256 && source.sha256 === source.api_sha256 ? bytes : null;
    phase251PackageBytesCache.set(cacheKey, verified);
    return verified;
  } catch { phase251PackageBytesCache.set(cacheKey, null); return null; }
}

export function phase251AuditAssertion(root, id, bytes, source) {
  if (!bytes?.length) return false;
  const text = bytes.toString('utf8');
  const hasGuide = /# Upgrade to Sigra v1\.6\.0/.test(text);
  const readmeLink = /\[[^\]]+\]\(guides\/introduction\/upgrading-to-v1\.6\.md(?:#[^)]*)?\)/i.test(text);
  const versionedMix = /@version\s+"1\.6\.0"/.test(text) && /version:\s*@version/.test(text);
  switch (id) {
    case 'candidate_version_1_6_0': case 'published_version_1_6_0': return versionedMix;
    case 'candidate_package_metadata_sigra_1_6_0': case 'published_package_metadata_sigra_1_6_0': return versionedMix && /app:\s*:sigra/.test(text);
    case 'manifest_version_1_6_0': try { return JSON.parse(text)['.'] === '1.6.0'; } catch { return false; }
    case 'release_config_elixir_changelog': try { const config = JSON.parse(text); return config['release-type'] === 'elixir' && config.packages?.['.']?.['changelog-path'] === 'CHANGELOG.md'; } catch { return false; }
    case 'candidate_changelog_1_6_0': case 'published_changelog_1_6_0': return /^## \[1\.6\.0\]/m.test(text);
    case 'tag_v1_6_0_targets_published_commit': {
      try { return versionedMix && execFileSync('git', ['rev-parse', '--verify', 'refs/tags/v1.6.0^{commit}'], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() === source.commit_sha; } catch { return false; }
    }
    case 'hexdocs_uses_version_source_ref': return versionedMix && /source_ref:\s*"v#\{@version\}"/.test(text);
    case 'published_module_source': return /^defmodule Sigra/m.test(text) && /@moduledoc/.test(text);
    case 'published_guide_present': return hasGuide;
    case 'candidate_readme_guide_link': case 'published_readme_guide_link': case 'readme_points_to_upgrade_guide': return readmeLink;
    case 'guide_shipped_changes': return hasGuide && /pasted six-digit codes/i.test(text) && /retry after an invalid code/i.test(text);
    case 'generated_host_regression_coverage': return /test\(['"`].*(?:organization|confirmation)/i.test(text) && /expect\(/.test(text);
    case 'guide_compatibility_constraints': return /Elixir `~> 1\.18`/.test(text) && /Phoenix `~> 1\.8`/.test(text) && /Phoenix LiveView `~> 1\.1`/.test(text);
    case 'guide_host_actions': return /mix deps\.update sigra/.test(text) && /selectively adopt/i.test(text) && /mix sigra\.install/.test(text);
    case 'host_action_test_coverage': return /test\(['"`].*organizations UX/i.test(text) && /await expect\(/.test(text);
    case 'guide_version_requirement': return /~> 1\.6\.0/.test(text);
    case 'candidate_package_version_requirement': return versionedMix;
    case 'guide_update_and_check_steps': return /mix deps\.update sigra/.test(text) && /mix deps\.tree/.test(text) && /host checks/i.test(text);
    default: return false;
  }
}

function phase251Ready01Complete(root, packet, feasibility) {
  const ready = packet?.requirements?.READY01;
  const feasible = feasibility?.requirements?.READY01;
  const checks = ready?.package_adopter?.checks;
  const tuple = ready?.exact_tuple;
  const approval = ready?.contemporaneous_approval;
  const expectedTuple = feasible?.candidate_tuple;
  const expectedPublished = feasible?.published_release_source?.commit_sha;
  const packageCheckIds = [
    'package_version', 'package_metadata', 'release_manifest', 'release_config', 'changelog', 'tag_target',
    'hexdocs_source_reference', 'published_tag_guide', 'readme_guide_link', 'adopter_shipped_changes',
    'adopter_compatibility', 'generated_host_action', 'version_requirement', 'update_check_path',
  ];
  const candidatePaths = [
    '.release-please-manifest.json', 'release-please-config.json', 'mix.exs', 'CHANGELOG.md', 'README.md',
    'guides/introduction/upgrading-to-v1.6.md', 'test/example/priv/playwright/tests/organizations.spec.ts',
  ];
  const publishedPaths = ['mix.exs', 'CHANGELOG.md', 'README.md', 'guides/introduction/upgrading-to-v1.6.md', 'lib/sigra.ex'];
  const requiredTupleFields = ['candidate_sha', 'reviewed_base_sha', 'protected_main_sha', 'published_source_sha', 'ci_head_sha', 'readiness_sha256', 'dry_run_sha256'];
  const tupleComplete = tuple && requiredTupleFields.every((field) => typeof tuple[field] === 'string' && tuple[field].length > 0)
    && tuple.candidate_sha === tuple.ci_head_sha
    && tuple.candidate_sha === expectedTuple?.candidate_sha
    && tuple.reviewed_base_sha === expectedTuple?.reviewed_base_sha
    && tuple.protected_main_sha === expectedTuple?.protected_main_sha
    && tuple.published_source_sha === expectedPublished;
  const approvalRecord = approval?.record;
  const approvalComplete = approval?.status === 'approved'
    && approval?.contemporaneous === true
    && typeof approval.record_sha256 === 'string'
    && /^[a-f0-9]{64}$/.test(approval.record_sha256)
    && approval.record_sha256 === sha256(JSON.stringify(approvalRecord))
    && approvalRecord?.decision === 'approved'
    && typeof approvalRecord?.source_identity === 'string'
    && approvalRecord.source_identity.length > 0
    && Number.isFinite(Date.parse(approvalRecord.approved_at))
    && approvalRecord.tuple_sha256 === sha256(JSON.stringify(tuple))
    && approval.tuple_sha256 === approvalRecord.tuple_sha256;
  const sources = ready?.package_adopter?.sources;
  const sourceBytesComplete = Array.isArray(sources) && sources.length > 0 && sources.every((source) =>
    typeof source?.source_identity === 'string'
    && typeof source?.commit_sha === 'string'
    && typeof source?.path === 'string'
    && source.read_status === 'readable'
    && source.trust_status === 'trusted_exact_api_blob_match'
    && typeof source.git_blob_oid === 'string'
    && source.git_blob_oid === source.api_blob_oid
    && typeof source.sha256 === 'string'
    && source.sha256 === source.api_sha256
    && phase251ExactPackageBytes(root, source) !== null
  );
  const sourceIdentity = (identity, commitSha, sourcePath) => sources?.some((source) =>
    source.source_identity === identity
    && source.commit_sha === commitSha
    && source.path === sourcePath
    && source.read_status === 'readable'
    && source.trust_status === 'trusted_exact_api_blob_match'
  );
  const sourceRecord = (identity, commitSha, sourcePath) => {
    const matches = Array.isArray(sources) ? sources.filter((source) => source.source_identity === identity
      && source.commit_sha === commitSha && source.path === sourcePath) : [];
    return matches.length === 1 ? matches[0] : null;
  };
  const exactPackageSourceSet = Array.isArray(ready?.package_adopter?.source_paths)
    && candidatePaths.every((sourcePath) => ready.package_adopter.source_paths.includes(sourcePath) && sourceIdentity(`candidate:${tuple?.candidate_sha}`, tuple?.candidate_sha, sourcePath))
    && publishedPaths.every((sourcePath) => ready.package_adopter.source_paths.includes(sourcePath) && sourceIdentity(`published_tag:v1.6.0:${tuple?.published_source_sha}`, tuple?.published_source_sha, sourcePath));
  const packageCheckSourcesComplete = packageCheckIds.every((id) => {
    const check = checks?.[id];
    const required = PHASE251_PACKAGE_CHECK_SOURCES[id] ?? [];
    if (!check || check.result !== 'pass' || !Array.isArray(check.source_refs) || !Array.isArray(check.source_assertions)
      || !required.length || check.source_refs.length !== required.length || check.source_assertions.length !== required.length) return false;
    const expected = required.map(([scope, sourcePath, assertion]) => {
      const identity = scope === 'candidate' ? `candidate:${tuple?.candidate_sha}` : `published_tag:v1.6.0:${tuple?.published_source_sha}`;
      const commitSha = scope === 'candidate' ? tuple?.candidate_sha : tuple?.published_source_sha;
      return { identity, commitSha, sourcePath, assertion, source: sourceRecord(identity, commitSha, sourcePath) };
    });
    if (expected.some((item) => !item.source)) return false;
    const refKeys = check.source_refs.map((ref) => `${ref?.source_identity}:${ref?.commit_sha}:${ref?.path}`).sort();
    const expectedKeys = expected.map((item) => `${item.identity}:${item.commitSha}:${item.sourcePath}`).sort();
    if (new Set(refKeys).size !== refKeys.length || JSON.stringify(refKeys) !== JSON.stringify(expectedKeys)) return false;
    const refsMatch = expected.every((item) => {
      const ref = check.source_refs.find((candidate) => candidate.source_identity === item.identity
        && candidate.commit_sha === item.commitSha && candidate.path === item.sourcePath);
      return phase251ExactPackageBytes(root, item.source) !== null
        && item.source.trust_status === 'trusted_exact_api_blob_match'
        && item.source.read_status === 'readable'
        && item.source.git_blob_oid === item.source.api_blob_oid
        && item.source.sha256 === item.source.api_sha256
        && ref?.git_blob_oid === item.source.git_blob_oid && ref?.sha256 === item.source.sha256;
    });
    const assertionsMatch = expected.every((item) => {
      const assertion = check.source_assertions.find((candidate) => candidate?.id === item.assertion);
      const bytes = phase251ExactPackageBytes(root, item.source);
      const actual = bytes ? phase251AuditAssertion(root, item.assertion, bytes, item.source) : null;
      return assertion?.result === (actual === true ? 'pass' : actual === null ? 'unreadable' : 'mismatch')
        && assertion.expected === true && assertion.actual === actual
        && assertion.source_identity === item.identity && assertion.commit_sha === item.commitSha
        && assertion.path === item.sourcePath && assertion.git_blob_oid === item.source.git_blob_oid
        && assertion.sha256 === item.source.sha256;
    });
    return refsMatch && assertionsMatch;
  });
  const packageComplete = ready?.package_adopter?.acceptance_satisfied === true
    && checks && packageCheckIds.every((id) => checks[id]?.result === 'pass' && typeof checks[id].evidence_detail === 'string' && checks[id].evidence_detail.length > 0 && /^No finding\b/i.test(checks[id].finding_detail ?? ''))
    && sourceBytesComplete
    && exactPackageSourceSet
    && packageCheckSourcesComplete;
  return feasible?.source_feasibility === 'ready'
    && feasible?.capture_allowed === true
    && ready?.source_feasibility === 'ready'
    && ready?.capture_allowed === true
    && ready?.verdict === 'satisfied'
    && Array.isArray(ready?.blockers) && ready.blockers.length === 0
    && Array.isArray(ready?.findings) && ready.findings.length === 0
    && tupleComplete
    && approvalComplete
    && packageComplete;
}

function phase251Ready02Complete(root, packet, feasibility) {
  const ready = packet?.requirements?.READY02;
  const feasible = feasibility?.requirements?.READY02;
  const population = ready?.open_pr_population;
  const prJoin = population?.disposition_join;
  const inherited = ready?.inherited_work;
  const inheritedJoin = inherited?.disposition_join;
  const identities = (rows) => Array.isArray(rows) ? rows.map((row) => `${row.number}:${row.head_sha}:${row.base_sha}:${row.base_ref}`) : [];
  const before = identities(population?.before);
  const after = identities(population?.after);
  const observed = Array.isArray(prJoin?.observedIds) ? prJoin.observedIds : [];
  const prDispositions = Array.isArray(prJoin?.dispositionIds) ? prJoin.dispositionIds : [];
  const inheritedObserved = Array.isArray(inheritedJoin?.observedIds) ? inheritedJoin.observedIds : [];
  const inheritedDispositions = Array.isArray(inheritedJoin?.dispositionIds) ? inheritedJoin.dispositionIds : [];
  const preservationRefs = Array.isArray(inheritedJoin?.preservationRefs) ? inheritedJoin.preservationRefs : [];
  const inheritedCount = Number(inherited?.commit_count ?? 0) + Number(inherited?.path_count ?? 0);
  const sourceInventory = packet?.source_capture?.local_inherited_work;
  const identityRows = sourceInventory?.inherited_commit_shas;
  const pathRows = sourceInventory?.inherited_paths;
  const dirtyRows = sourceInventory?.inherited_dirty_entries;
  const sourceDispositions = sourceInventory?.inherited_dispositions;
  const worktreeRows = inherited?.worktrees;
  const expectedInheritedIds = () => {
    if (![identityRows, pathRows, dirtyRows, sourceDispositions, worktreeRows].every(Array.isArray)) return null;
    if (identityRows.some((sha) => typeof sha !== 'string' || !/^[a-f0-9]{40}$/.test(sha))
      || pathRows.some((sourcePath) => typeof sourcePath !== 'string' || !sourcePath)
      || dirtyRows.some((row) => !row || typeof row.id !== 'string' || !row.id)
      || sourceDispositions.some((row) => !row || typeof row.id !== 'string' || !row.id)) return null;
    const statusRows = [];
    for (const worktree of worktreeRows) {
      if (!worktree || typeof worktree.path !== 'string' || !worktree.path
        || typeof worktree.head_sha !== 'string' || !/^[a-f0-9]{40}$/.test(worktree.head_sha)
        || !Array.isArray(worktree.status_entries)) return null;
      for (const entry of worktree.status_entries) {
        if (!entry || typeof entry.status !== 'string' || !entry.status
          || typeof entry.path !== 'string' || !entry.path
          || entry.source_byte_readable !== true || !/^[a-f0-9]{64}$/.test(entry.source_byte_sha256 ?? '')) return null;
        statusRows.push({ ...entry, worktree_path: worktree.path, worktree_head_sha: worktree.head_sha });
      }
    }
    const statusIds = statusRows.map((entry) => `dirty:${entry.worktree_path}:${entry.worktree_head_sha}:${entry.status}:${entry.path}:${entry.source_byte_sha256}`);
    const capturedStatusRows = [];
    if (!Array.isArray(sourceInventory?.worktrees)) return null;
    for (const worktree of sourceInventory.worktrees) {
      if (!worktree || typeof worktree.path !== 'string' || !worktree.path
        || typeof worktree.head_sha !== 'string' || !/^[a-f0-9]{40}$/.test(worktree.head_sha)
        || !Array.isArray(worktree.status_entries)) return null;
      for (const entry of worktree.status_entries) {
        if (!entry || typeof entry.status !== 'string' || !entry.status
          || typeof entry.path !== 'string' || !entry.path
          || entry.source_byte_readable !== true || !/^[a-f0-9]{64}$/.test(entry.source_byte_sha256 ?? '')) return null;
        capturedStatusRows.push(`dirty:${worktree.path}:${worktree.head_sha}:${entry.status}:${entry.path}:${entry.source_byte_sha256}`);
      }
    }
    const dirtyIds = dirtyRows.map((row) => row.id);
    const expectedDirtyIds = statusRows.map((entry) => `dirty:${entry.worktree_path}:${entry.worktree_head_sha}:${entry.status}:${entry.path}:${entry.source_byte_sha256}`);
    if (!exactStringSet(capturedStatusRows, statusIds) || !exactStringSet(dirtyIds, expectedDirtyIds)) return null;
    const expected = [...identityRows.map((sha) => `commit:${sha}`), ...pathRows.map((sourcePath) => `path:${sourcePath}`), ...statusIds];
    if (new Set(expected).size !== expected.length) return null;
    if (!exactStringSet(sourceDispositions.map((row) => row.id), expected)) return null;
    return expected;
  };
  const expectedIds = expectedInheritedIds();
  const completeWorktrees = (inventory) => Array.isArray(inventory?.raw_status)
    && inventory.raw_status.every((entry) => typeof entry?.path === 'string'
      && entry.source_byte_readable === true && /^[a-f0-9]{64}$/.test(entry.source_byte_sha256 ?? ''))
    && Array.isArray(inventory.worktrees)
    && inventory.worktrees.length > 0
    && inventory.worktrees.every((worktree) => worktree.status_readable === true
      && typeof worktree.status_bytes === 'string'
      && worktree.status_sha256 === sha256(worktree.status_bytes)
      && Array.isArray(worktree.status_entries)
      && worktree.status_entries_readable === true
      && worktree.status_entries.every((entry) => typeof entry?.path === 'string'
        && entry.source_byte_readable === true && /^[a-f0-9]{64}$/.test(entry.source_byte_sha256 ?? '')));
  const sourceRoot = sourceInventory?.worktrees?.find((worktree) => worktree.path === sourceInventory.repository_root);
  const sourceInventoryComplete = sourceInventory?.inventory_complete === true
    && sourceRoot?.status_sha256 === sourceInventory?.raw_status_sha256
    && completeWorktrees(sourceInventory);
  const inheritedInventoryComplete = completeWorktrees(inherited);
  const populationMatches = population?.stable === true
    && population?.complete === true
    && population.before_count === before.length
    && population.after_count === after.length
    && exactStringSet(before, after)
    && exactStringSet(observed, before)
    && exactStringSet(prDispositions, observed)
    && prJoin?.status === 'passed'
    && Array.isArray(prJoin?.blockers) && prJoin.blockers.length === 0;
  const inheritedMatches = sourceInventoryComplete
    && inheritedInventoryComplete
    && expectedIds !== null
    && exactStringSet(inheritedObserved, expectedIds)
    && inheritedJoin?.status === 'passed'
    && Array.isArray(inheritedJoin?.blockers) && inheritedJoin.blockers.length === 0
    && exactStringSet(inheritedDispositions, expectedIds)
    && (inheritedCount === 0 ? preservationRefs.length === 0 : preservationRecordsMatch(root, preservationRefs, expectedIds, sourceDispositions, dirtyRows));
  const historicalInventoryNote = 'Prior inventory is historical; Task 3 must capture a fresh complete open-PR and inherited-work inventory before dispositions.';
  const findingsAreHistoricalOnly = Array.isArray(ready?.findings)
    && ready.findings.every((finding) => finding === historicalInventoryNote);
  return feasible?.source_feasibility === 'ready'
    && feasible?.capture_allowed === true
    && ready?.source_feasibility === 'ready'
    && ready?.capture_allowed === true
    && ready?.verdict === 'satisfied'
    && Array.isArray(ready?.blockers) && ready.blockers.length === 0
    && findingsAreHistoricalOnly
    && populationMatches
    && inheritedMatches;
}

function collectOwnerSources(root, blockers, overrides = {}) {
  const owners = {};
  const sourceIdentities = [];
  for (const phase of ['246', '247', '248', '249']) {
    const reportPath = `.planning/phases/${OWNER_DIR[phase]}/${phase}-VERIFICATION.md`;
    const reportText = readSource(root, reportPath, overrides);
    const status = reportText ? reportStatus(reportText) : 'missing';
    const report = { phase, path: reportPath, status, reportSha256: reportText === null ? null : sha256(reportText) };
    let parsed = null;
    let recomputedRequirements = null;

    if (phase === '247') {
      const markerPath = reportText?.match(/<!--\s*phase-251-reconciliation:\s*([^\s]+)\s*-->/)?.[1];
      const markerHash = reportText?.match(/<!--\s*phase-251-reconciliation-sha256:\s*([a-f0-9]{64})\s*-->/)?.[1];
      if (markerPath !== PHASE251_PACKET_PATH || !markerHash) {
        for (const id of ACCEPTED_READY_IDS) add(blockers, id, 'Phase 247 verification lacks the exact Phase 251 reconciliation path and digest.');
      }
      else {
        const reconciliationText = readSource(root, PHASE251_PACKET_PATH, overrides);
        const feasibilityText = readSource(root, PHASE251_FEASIBILITY_PATH, overrides);
        const packetHash = reconciliationText === null ? null : sha256(reconciliationText);
        const feasibilityHash = feasibilityText === null ? null : sha256(feasibilityText);
        if (!reconciliationText || packetHash !== markerHash) {
          for (const id of ACCEPTED_READY_IDS) add(blockers, id, 'Phase 247 verification is stale against the exact Phase 251 packet digest.', { path: PHASE251_PACKET_PATH, expected: markerHash, actual: packetHash });
        } else {
          try {
            parsed = JSON.parse(reconciliationText);
          } catch (error) {
            add(blockers, 'READY-01', `Phase 251 reconciliation packet is malformed: ${error.message}`, PHASE251_PACKET_PATH);
            parsed = null;
          }
          let feasibility = null;
          try {
            feasibility = feasibilityText === null ? null : JSON.parse(feasibilityText);
          } catch (error) {
            add(blockers, 'READY-01', `Phase 251 source-feasibility record is malformed: ${error.message}`, PHASE251_FEASIBILITY_PATH);
          }
          if (!feasibility) add(blockers, 'READY-01', 'Phase 251 source-feasibility record is missing.', PHASE251_FEASIBILITY_PATH);
          if (parsed && feasibility) {
            report.reconciliation = PHASE251_PACKET_PATH;
            report.reconciliationSha256 = markerHash;
            report.capturedAt = parsed.captured_at ?? null;
            report.sourceFeasibility = { path: PHASE251_FEASIBILITY_PATH, sha256: feasibilityHash };
            report.packetOwnerPhase = parsed.owner_phase ?? null;
            sourceIdentities.push({ phase, path: PHASE251_PACKET_PATH, sha256: markerHash, ownerPhase: parsed.owner_phase, status: parsed.status });
            sourceIdentities.push({ phase, path: PHASE251_FEASIBILITY_PATH, sha256: feasibilityHash, status: feasibility.status });
            const correctPacketOwner = parsed.phase === 251 && parsed.owner_phase === 247;
            if (!correctPacketOwner) add(blockers, 'READY-01', 'Phase 251 packet ownership does not identify the Phase 247 owner report.', { packetPhase: parsed.phase, ownerPhase: parsed.owner_phase });
            const recordedFeasibility = parsed.source_feasibility;
            const feasibilityBound = recordedFeasibility?.path === PHASE251_FEASIBILITY_PATH && recordedFeasibility?.sha256 === feasibilityHash;
            if (!feasibilityBound) {
              add(blockers, 'READY-01', 'Phase 251 packet does not bind the exact source-feasibility artifact bytes.', { packet: recordedFeasibility ?? null, expected: { path: PHASE251_FEASIBILITY_PATH, sha256: feasibilityHash } });
            }
            report.phase251BindingValid = correctPacketOwner && feasibilityBound;
            report.requirementVerdicts = {};
            for (const id of ACCEPTED_READY_IDS) {
              const key = id.replace('-', '');
              const packetVerdict = parsed.requirement_verdicts?.[id];
              const nestedVerdict = parsed.requirements?.[key]?.verdict;
              const tableVerdict = reportRequirementVerdict(reportText, id);
              const normalizedPacket = normalizedRequirementVerdict(packetVerdict);
              const nestedConsistent = normalizedRequirementVerdict(nestedVerdict) === normalizedPacket;
              const rowBound = tableVerdict !== null && normalizedRequirementVerdict(tableVerdict) === normalizedPacket;
              if (normalizedPacket === 'missing' || !nestedConsistent) add(blockers, id, 'Phase 251 packet requirement verdict is missing or conflicts with its owner detail.', { packetVerdict, nestedVerdict });
              if (!rowBound) add(blockers, id, 'Phase 247 owner table verdict differs from the exact Phase 251 packet verdict.', { tableVerdict, packetVerdict });
              if (feasibility.status !== 'ready' && normalizedPacket === 'satisfied') add(blockers, id, 'Phase 251 claims a pass while its complete evidence-feasibility record is not ready.', { feasibilityStatus: feasibility.status });
              const complete = id === 'READY-01'
                ? phase251Ready01Complete(root, parsed, feasibility)
                : phase251Ready02Complete(root, parsed, feasibility);
              if (normalizedPacket === 'satisfied' && !complete) add(blockers, id, 'Phase 251 reports a pass without complete source-bound package check refs/assertions, exact tuple approval, and inventory joins.', PHASE251_PACKET_PATH);
              const currentStatus = normalizedPacket === 'satisfied' && complete && rowBound && nestedConsistent ? 'satisfied' : 'unsatisfied';
              report.requirementVerdicts[id] = currentStatus;
              if (normalizedPacket === 'unsatisfied') {
                const detail = parsed.requirements?.[key] ?? {};
                const itemBlockers = Array.isArray(detail.blockers) ? detail.blockers : [];
                const itemFindings = Array.isArray(detail.findings) ? detail.findings : [];
                for (const message of [...itemBlockers, ...itemFindings]) add(blockers, id, `Phase 251 ${id}: ${message}`, PHASE251_PACKET_PATH);
                if (id === 'READY-01' && packetVerdict === 'authorization_pending') add(blockers, id, 'Phase 251 READY-01 is authorization_pending: no recoverable contemporaneous approval binds the exact candidate/source/CI/readiness/dry-run record.', PHASE251_PACKET_PATH);
              }
            }
            for (const item of parsed.blockers ?? []) {
              const id = item?.includes?.('local_inherited') || item?.includes?.('open_pr') ? 'READY-02' : null;
              if (id) add(blockers, id, `Phase 251 packet blocker: ${item}`, PHASE251_PACKET_PATH);
            }
          }
        }
      }
    }

    if (phase === '248') {
      const snapshotPath = `${CLOSE_DIR}/250-248-SOURCE-SNAPSHOT.json`;
      const snapshot = readJson(root, snapshotPath, blockers, overrides);
      parsed = htmlJson(reportText ?? '', 'phase248-evidence');
      if (!parsed) add(blockers, 'AUTO-01', 'Phase 248 report has no parseable source-evidence identity.');
      else {
        report.evidence = {
          sourceSha: parsed.source_sha ?? null,
          releaseRunId: parsed.release_run_id ?? null,
          ciRunId: parsed.ci_run_id ?? null,
          failureRunId: parsed.failure_run_id ?? null,
          failureArtifactId: parsed.failure_artifact_id ?? null,
          cancellationRunId: parsed.cancellation_run_id ?? null,
          cancellationArtifactId: parsed.cancellation_artifact_id ?? null,
        };
        if (snapshot) {
          const evaluation = evaluate248(snapshot);
          recomputedRequirements = evaluation.requirements;
          for (const error of check248Report(reportText ?? '', snapshot, evaluation)) {
            for (const id of Object.keys(OWNER_PHASE).filter((requirementId) => OWNER_PHASE[requirementId] === phase)) {
              add(blockers, id, `Phase 248 report fails its recomputed source check: ${error}.`, snapshotPath);
            }
          }
          for (const [id, expected] of Object.entries(recomputedRequirements)) {
            const embedded = parsed?.requirements?.[id];
            const embeddedStatus = typeof embedded === 'string' ? embedded.toLowerCase() : embedded?.status?.toLowerCase();
            if (embeddedStatus !== expected.status) add(blockers, id, `Phase 248 embedded requirement verdict ${embeddedStatus ?? 'missing'} differs from recomputed source verdict ${expected.status}.`, snapshotPath);
          }
          const exactSource = snapshot.tag?.target_sha;
          if (parsed.source_sha !== exactSource) add(blockers, 'AUTO-01', 'Phase 248 report source SHA differs from captured tag source.', { report: parsed.source_sha, snapshot: exactSource });
          const proofPath = `${CLOSE_DIR}/250-CANARY-PROOF.json`;
          const proofText = readSource(root, proofPath, overrides);
          const proof = proofText ? JSON.parse(proofText) : null;
          if (!proof) add(blockers, 'AUTO-02', 'Hosted canary proof artifact is missing or malformed.', proofPath);
          else {
            const proofHash = sha256(proofText);
            if (proofHash !== snapshot.canary?.proof_sha256) add(blockers, 'AUTO-02', 'Hosted canary proof digest differs from the captured Phase 248 source snapshot.', { proofPath, expected: snapshot.canary?.proof_sha256, actual: proofHash });
            if (!canaryProofMatchesSnapshot(proof, snapshot, proofHash)) {
              add(blockers, 'AUTO-02', 'Hosted failure/cancellation proof does not match the captured receipt, artifact, observer, and exact-source identities.', {
                proofStatus: proof.status,
                expectedProofStatus: snapshot.canary?.proof_status,
                controllerRunId: proof.controller_run?.id ?? null,
                failureRunId: proof.source_failure?.run_id ?? null,
                cancellationRunId: proof.source_cancellation?.run_id ?? null,
                snapshotFailureRunId: snapshot.canary?.failure?.run?.id ?? null,
                snapshotCancellationRunId: snapshot.canary?.cancellation?.run?.id ?? null,
              });
            }
          }
          report.sourceSnapshot = snapshotPath;
          report.snapshotCapturedAt = snapshot.captured_at ?? null;
          report.evidenceIdentities = { tag: snapshot.tag?.target_sha, releaseRun: snapshot.release_run?.id, ciRun: snapshot.ci_run?.id, successArtifact: snapshot.success_artifact?.id, canaryProofSha256: snapshot.canary?.proof_sha256 };
          sourceIdentities.push({ phase, path: snapshotPath, capturedAt: snapshot.captured_at, identities: report.evidenceIdentities });
        }
      }
    }

    if (phase === '249') {
      const snapshotPath = `${CLOSE_DIR}/250-249-SOURCE-SNAPSHOT.json`;
      const snapshot = readJson(root, snapshotPath, blockers, overrides);
      parsed = htmlJson(reportText ?? '', 'phase249-evidence');
      if (!parsed) add(blockers, 'REL-01', 'Phase 249 report has no parseable source-evidence identity.');
      else if (snapshot) {
        const evaluation = evaluate249(snapshot);
        recomputedRequirements = evaluation.requirements;
        for (const error of check249Report(reportText ?? '', snapshot, evaluation)) {
          for (const id of Object.keys(OWNER_PHASE).filter((requirementId) => OWNER_PHASE[requirementId] === phase)) {
            add(blockers, id, `Phase 249 report fails its recomputed source check: ${error}.`, snapshotPath);
          }
        }
        for (const [id, expected] of Object.entries(recomputedRequirements)) {
          const embedded = parsed?.requirements?.[id];
          const embeddedStatus = typeof embedded === 'string' ? embedded.toLowerCase() : embedded?.status?.toLowerCase();
          if (embeddedStatus !== expected.status) add(blockers, id, `Phase 249 embedded requirement verdict ${embeddedStatus ?? 'missing'} differs from recomputed source verdict ${expected.status}.`, snapshotPath);
        }
        const evidence = snapshot.evidence_ref ?? {};
        const acceptedLoss = snapshot.accepted_loss ?? {};
        const currentSha = snapshot.source?.current_protected_main_sha;
        if (parsed.package_source_sha !== snapshot.source?.package_source_sha || parsed.historical_release_main_sha !== snapshot.source?.historical_release_main_sha || parsed.current_protected_main_sha !== currentSha || parsed.evidence_ref_commit !== evidence.commit_sha) {
          add(blockers, 'REL-02', 'Phase 249 report source identity differs from the captured current-main/evidence-ref snapshot.', { report: { packageSource: parsed.package_source_sha, historicalMain: parsed.historical_release_main_sha, currentMain: parsed.current_protected_main_sha, evidenceRefCommit: parsed.evidence_ref_commit }, snapshot: { packageSource: snapshot.source?.package_source_sha, historicalMain: snapshot.source?.historical_release_main_sha, currentMain: currentSha, evidenceRefCommit: evidence.commit_sha } });
        }
        if (parsed.accepted_loss_sha256 !== acceptedLoss.sha256 || acceptedLoss.bytes_recovered !== false || acceptedLoss.bytes_preserved !== false) {
          add(blockers, 'REL-02', 'Accepted historical HANDOFF loss identity is changed or incorrectly described as recovered/preserved.', { expectedSha256: acceptedLoss.sha256, reportSha256: parsed.accepted_loss_sha256, bytesRecovered: acceptedLoss.bytes_recovered, bytesPreserved: acceptedLoss.bytes_preserved });
        }
        const lossSection = reportText?.match(/^## Accepted historical loss\s*\n([\s\S]*?)(?=^## |\s*$)/m)?.[1] ?? '';
        if (!/accepted-with-recorded-loss/.test(lossSection) || !/not recovered/i.test(lossSection) || !/not preserved/i.test(lossSection) || /\b(?:was|were|is|are|has been|have been)\s+(?!not\b)(?:recovered|preserved)\b/i.test(lossSection)) {
          add(blockers, 'REL-02', 'Phase 249 report does not preserve the accepted-loss wording that the historical bytes remain unrecovered and unpreserved.');
        }
        const currentCi = snapshot.current_ci ?? {};
        if (currentCi.conclusion !== 'success' || currentCi.job?.conclusion !== 'success') {
          add(blockers, 'REL-02', 'Current-main CI workflow or ci-gate failed for the captured exact SHA.', { runId: currentCi.run_id, sha: currentCi.head_sha, workflowConclusion: currentCi.conclusion, ciGateConclusion: currentCi.job?.conclusion });
        }
        for (const pr of snapshot.inventory?.pull_requests ?? []) {
          if ([302, 306, 307, 308, 309].includes(pr.number) && (!pr.disposition || pr.disposition_identity_match !== true)) {
            add(blockers, 'REL-02', `Open PR #${pr.number} has no disposition matching its captured base/head identity.`, { baseSha: pr.base_sha, headSha: pr.head_sha });
          }
        }
        const livePath = `${CLOSE_DIR}/250-05-CURRENT-INVENTORY.json`;
        // Plan 05's inventory predates the Plan 10 source snapshot and must remain historical.
        const live = null;
        if (live) {
          const capturedIds = (snapshot.inventory?.pull_requests ?? []).map((pr) => pr.number).sort((a, b) => a - b);
          const liveIds = [...(live.pull_requests?.open_ids ?? [])].sort((a, b) => a - b);
          if (live.main?.sha !== currentSha) add(blockers, 'REL-02', 'Fresh GitHub main observation differs from the Phase 249 current-main snapshot.', { snapshot: currentSha, live: live.main?.sha });
          if (live.current_main_ci?.head_sha !== live.main?.sha || live.current_main_ci?.conclusion !== 'success' || live.current_main_ci?.ci_gate_conclusion !== 'success') {
            add(blockers, 'REL-02', 'Fresh current-main CI workflow is not successful on the exact observed main SHA (the ci-gate job result is recorded separately).', { runId: live.current_main_ci?.run_id, headSha: live.current_main_ci?.head_sha, mainSha: live.main?.sha, workflowConclusion: live.current_main_ci?.conclusion, ciGateConclusion: live.current_main_ci?.ci_gate_conclusion });
          }
          if (live.pull_requests?.read_status !== 'complete' || live.pull_requests?.open_count !== liveIds.length || live.pull_requests?.open_count !== capturedIds.length || JSON.stringify(liveIds) !== JSON.stringify(capturedIds)) {
            add(blockers, 'REL-02', 'Fresh pull-request inventory is incomplete or differs from the Phase 249 captured population.', { snapshotCount: capturedIds.length, liveCount: live.pull_requests?.open_count, snapshotIds: capturedIds, liveIds });
          }
          for (const pr of live.pull_requests?.unresolved ?? []) {
            if (!pr.disposition) add(blockers, 'REL-02', `Fresh open PR #${pr.number} has no disposition at its current base/head identity.`, { baseSha: pr.base_sha, headSha: pr.head_sha });
          }
          report.liveInventory = { path: livePath, capturedAt: live.captured_at, mainSha: live.main?.sha, ciRunId: live.current_main_ci?.run_id, ciConclusion: live.current_main_ci?.conclusion, ciGateConclusion: live.current_main_ci?.ci_gate_conclusion, openPrCount: live.pull_requests?.open_count, unresolvedPrs: (live.pull_requests?.unresolved ?? []).map(({ number, base_sha, head_sha }) => ({ number, base_sha, head_sha })) };
          sourceIdentities.push({ phase, path: livePath, ...report.liveInventory });
        }
        report.sourceSnapshot = snapshotPath;
        report.snapshotCapturedAt = snapshot.captured_at ?? null;
        report.evidenceIdentities = { ...snapshot.source, evidenceRef: evidence.name, evidenceRefCommit: evidence.commit_sha, historicalCiRunId: snapshot.historical_ci?.run_id, currentCiRunId: currentCi.run_id, currentCiJobId: currentCi.job?.id, acceptedLossSha256: acceptedLoss.sha256 };
        sourceIdentities.push({ phase, path: snapshotPath, capturedAt: snapshot.captured_at, identities: report.evidenceIdentities });
      }
    }

    report.requirements = Object.keys(OWNER_PHASE).filter((id) => OWNER_PHASE[id] === phase).map((id) => ({
      id,
      status: phase === '247'
        ? (report.phase251BindingValid ? report.requirementVerdicts?.[id] ?? 'unsatisfied' : 'unsatisfied')
        : recomputedRequirements?.[id]?.status ?? reportRequirementStatus(phase, id, reportText, parsed),
    }));
    owners[phase] = report;
    if (status === 'missing') {
      for (const [id, owner] of Object.entries(OWNER_PHASE)) if (owner === phase) add(blockers, id, `Owner Phase ${phase} verification report is missing; requirement is orphaned.`, reportPath);
    }
    if (status !== 'passed') {
      for (const requirement of report.requirements) {
        if (requirement.status !== 'satisfied') add(blockers, requirement.id, `Canonical owner Phase ${phase} verifier is ${status}; requirement verdict is ${requirement.status}.`, { report: reportPath, reportSha256: report.reportSha256 });
      }
    }
  }
  return { owners, sourceIdentities };
}

export function audit(root = process.cwd(), options = {}) {
  const blockers = [];
  const requirementsText = readSource(root, TRACE_PATH, options.overrides);
  if (requirementsText === null) add(blockers, 'TRACEABILITY', `Missing ${TRACE_PATH}.`);
  const rows = requirementRows(requirementsText ?? '');
  const claims = scanSummaryClaims(root, options.overrides);
  const { owners, sourceIdentities } = collectOwnerSources(root, blockers, options.overrides);
  const readyEvidenceRows = validateReadyOwnerEvidenceRows(requirementsText ?? '', owners['247'], blockers);
  const amendment = readAcceptanceAmendment(root, blockers, options.overrides);
  if (amendment.valid) {
    sourceIdentities.push({ phase: '250', path: ACCEPTANCE_PATH, sha256: amendment.hash });
    sourceIdentities.push({ phase: '250-historical', ...amendment.historicalSource });
  }
  const requirementList = Object.entries(OWNER_PHASE).map(([id, phase]) => {
    const row = rows.get(id);
    const owner = owners[phase];
    const ownerReport = owner?.requirements?.find((item) => item.id === id);
    const allClaims = claims.filter((claim) => claim.requirement === id);
    const wrongOwners = allClaims.filter((claim) => claim.phase !== phase);
    if (!row) add(blockers, id, 'Requirement is absent from the original milestone traceability table.');
    if (wrongOwners.length) add(blockers, id, `Requirement is claimed outside original owner Phase ${phase}, including Phase 250.`, wrongOwners.map(({ file }) => file));
    const ownerStatus = owner?.status ?? 'missing';
    const verificationStatus = ownerReport?.status ?? ownerStatus;
    const readyEvidenceBound = phase !== '247' || !ACCEPTED_READY_IDS.includes(id)
      || (readyEvidenceRows.get(id)?.ownerReport === owner?.path
        && readyEvidenceRows.get(id)?.packet === PHASE251_PACKET_PATH
        && readyEvidenceRows.get(id)?.packetSha256 === owner?.reconciliationSha256);
    const status = verificationStatus === 'satisfied' && readyEvidenceBound ? 'satisfied' : ownerStatus === 'missing' ? 'orphaned' : 'unsatisfied';
    if (verificationStatus !== 'satisfied' && allClaims.length) {
      add(blockers, id, `Summary frontmatter claims ${id} although owner Phase ${phase} requirement verdict is ${verificationStatus} (overall report: ${ownerStatus}); plan completion does not satisfy the milestone requirement.`, allClaims.map(({ file }) => file));
    }
    if (status === 'satisfied' && row && !row.checked) add(blockers, id, 'Verification is passing but REQUIREMENTS.md remains unchecked; traceability needs reconciliation.', { phase });
    if (status !== 'satisfied' && row?.checked) add(blockers, id, 'REQUIREMENTS.md is checked although the canonical owner verifier remains unsatisfied.', { phase });
    const historicalException = amendment.valid && amendment.ids.includes(id);
    return {
      id,
      phase,
      description: row?.description ?? 'Requirement row missing',
      traceability: row?.checked ? 'complete' : 'open',
      status,
      acceptance_status: status === 'satisfied' ? 'verified' : 'unaccepted',
      historical_phase_250_exception: historicalException,
      verification_status: verificationStatus,
      owner_report_status: ownerStatus,
      claimed_by_plans: [...new Set(allClaims.filter((claim) => claim.phase === phase).map((claim) => path.basename(claim.file, '-SUMMARY.md')))],
      completed_by_plans: [...new Set(allClaims.filter((claim) => claim.phase === phase).map((claim) => path.basename(claim.file, '-SUMMARY.md')))],
      evidence: status === 'satisfied' ? `Canonical Phase ${phase} requirement-level verdict is satisfied; overall report status is ${ownerStatus}.` : `Canonical Phase ${phase} requirement-level verdict is ${verificationStatus}; overall report status is ${ownerStatus}; see named source blockers.`,
    };
  });

  const unique = new Map();
  for (const blocker of blockers) {
    const key = `${blocker.id}\0${blocker.message}\0${JSON.stringify(blocker.identity ?? null)}`;
    if (!unique.has(key)) unique.set(key, blocker);
  }
  const deduped = [...unique.values()];
  const unacceptedBlockers = deduped;
  const historicalExceptions = amendment.valid ? amendment.ids.map((id) => ({
    id,
    acceptance_status: 'accepted_exception',
    scope: 'Phase 250 closeout only',
    owner_verification_status: 'unsatisfied',
    source: amendment.historicalSource,
  })) : [];
  const satisfied = requirementList.filter((row) => row.status === 'satisfied').length;
  const status = satisfied === requirementList.length && unacceptedBlockers.length === 0
    ? 'passed'
    : 'gaps_found';
  const groupSatisfied = (ids) => ids.every((id) => requirementList.find((row) => row.id === id)?.status === 'satisfied');
  const integrationGroups = [
    ['CONF-01', 'CONF-02', 'CONF-03'],
    ['READY-01', 'READY-02'],
    ['AUTO-01'],
    ['AUTO-02'],
    ['REL-01', 'REL-02'],
  ];
  const flowGroups = [
    ['CONF-01', 'CONF-02', 'CONF-03'],
    ['READY-01', 'READY-02'],
    ['AUTO-01', 'AUTO-02'],
    ['REL-01', 'REL-02'],
  ];
  const completeGroups = integrationGroups.filter(groupSatisfied).length;
  const completeFlows = flowGroups.filter(groupSatisfied).length;
  const packetIdentity = sourceIdentities.find((item) => item.path === PHASE251_PACKET_PATH);
  return {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    status,
    milestoneStatus: status === 'passed' ? 'passed' : 'incomplete',
    acceptanceAmendment: amendment.valid ? { path: ACCEPTANCE_PATH, sha256: amendment.hash, historicalSource: amendment.historicalSource } : null,
    acceptedExceptionCount: 0,
    historicalExceptionCount: historicalExceptions.length,
    unacceptedBlockerCount: unacceptedBlockers.length,
    score: { requirements: `${satisfied}/${requirementList.length}`, phases: '4/6', integration: `${completeGroups}/${integrationGroups.length}`, flows: `${completeFlows}/${flowGroups.length}` },
    currentReadiness: {
      packetPath: PHASE251_PACKET_PATH,
      packetSha256: packetIdentity?.sha256 ?? null,
      ownerPhase: 247,
      ready01: requirementList.find((row) => row.id === 'READY-01')?.status ?? 'missing',
      ready02: requirementList.find((row) => row.id === 'READY-02')?.status ?? 'missing',
      blockers: deduped.filter((row) => row.id === 'READY-01' || row.id === 'READY-02'),
    },
    nyquist: discoverNyquist(root, options.overrides),
    requirements: requirementList,
    owners,
    sourceIdentities,
    historicalExceptions,
    blockers: unacceptedBlockers,
    sourceBlockers: deduped,
    orphaned: requirementList.filter((row) => row.status === 'orphaned').map(({ id }) => id),
    contradictions: unacceptedBlockers.filter((item) => /differs|claims|outside original|mismatch|changed|recovered\/preserved|unchecked/i.test(item.message)),
  };
}

export function renderAudit(result) {
  const gsdStatus = result.status;
  const requirementsYaml = result.requirements.map((row) => [
    `    - id: "${row.id}"`, `      status: "${row.status}"`, `      acceptance_status: "${row.acceptance_status}"`, `      phase: "${row.phase}"`,
    `      historical_phase_250_exception: ${row.historical_phase_250_exception}`,
    `      claimed_by_plans: [${row.claimed_by_plans.map((value) => `"${value}"`).join(', ')}]`,
    `      completed_by_plans: [${row.completed_by_plans.map((value) => `"${value}"`).join(', ')}]`,
    `      verification_status: "${row.verification_status}"`, `      owner_report_status: "${row.owner_report_status}"`, `      evidence: "${row.evidence.replaceAll('"', "'")}"`,
  ].join('\n')).join('\n');
  const blockerYaml = result.blockers.map((row) => `  - id: "${row.id}"\n    message: "${row.message.replaceAll('"', "'")}"${row.identity === undefined ? '' : `\n    identity: "${JSON.stringify(row.identity).replaceAll('"', "'")}"`}`).join('\n');
  const requirementRowsMd = result.requirements.map((row) => `| ${row.id} | ${row.phase} | ${row.traceability} | ${row.verification_status} | ${row.acceptance_status} | **${row.status}** | ${row.evidence} |`).join('\n');
  const ownerRows = Object.values(result.owners).map((row) => `| ${row.phase} | ${row.status} | ${row.reportSha256 ?? 'missing'} | ${row.snapshotCapturedAt ?? row.capturedAt ?? 'not captured'} |`).join('\n');
  const blockerRows = result.blockers.map((row) => `- **${row.id}:** ${row.message}${row.identity === undefined ? '' : ` Identity: \`${JSON.stringify(row.identity)}\`.`}`).join('\n');
  const ready01 = result.requirements.find((row) => row.id === 'READY-01');
  const ready02 = result.requirements.find((row) => row.id === 'READY-02');
  const requirementStatus = (id) => result.requirements.find((row) => row.id === id)?.status ?? 'missing';
  const groupStatus = (ids) => ids.every((id) => requirementStatus(id) === 'satisfied') ? 'complete' : 'incomplete';
  const readinessReason = (row) => row?.status === 'satisfied' ? 'The Phase 247 owner verdict passes its complete Phase 251 source joins.' : row?.evidence ?? 'The Phase 247 owner verdict is unavailable.';
  const historical = result.acceptanceAmendment?.historicalSource;
  const historyParagraph = historical
    ? `Phase 250's two exceptions remain historical phase-only decisions. Amendment SHA-256 ${result.acceptanceAmendment.sha256}; original owner report at commit \`${historical.commit}\` SHA-256 ${historical.ownerReportSha256}; Phase 250 reconciliation SHA-256 ${historical.reconciliationSha256}; tuple packet SHA-256 ${historical.tuplePacketSha256}. They do not satisfy current READY requirements.`
    : 'The Phase 250 historical amendment could not be verified; its source is a blocker and it grants no current READY acceptance.';
  const readReadyBlockers = result.currentReadiness.blockers.map(({ message }) => message);
  const readyBlockerSummary = readReadyBlockers.length ? readReadyBlockers.join(' ') : 'No READY-specific source blockers were reported.';
  const integrationReady = ready01?.status === 'satisfied' && ready02?.status === 'satisfied';
  const integrationRows = [
    `    - requirement: "CONF-01/02/03"\n      status: "${groupStatus(['CONF-01', 'CONF-02', 'CONF-03'])}"\n      evidence: "Original confirmation owner verifications."`,
    `    - requirement: "READY-01/02"\n      status: "${integrationReady ? 'complete' : 'incomplete'}"\n      evidence: "${readyBlockerSummary.replaceAll('"', "'")}"`,
    `    - requirement: "AUTO-01"\n      status: "${requirementStatus('AUTO-01') === 'satisfied' ? 'complete' : 'incomplete'}"\n      evidence: "${requirementStatus('AUTO-01')} from its Phase 248 owner verification."`,
    `    - requirement: "AUTO-02"\n      status: "${requirementStatus('AUTO-02') === 'satisfied' ? 'complete' : 'incomplete'}"\n      evidence: "${requirementStatus('AUTO-02')} from its Phase 248 owner verification."`,
    `    - requirement: "REL-01/02"\n      status: "${groupStatus(['REL-01', 'REL-02'])}"\n      evidence: "Original release owner verifications."`,
  ].join('\n');
  const flowRows = [
    `    - name: "Confirmation requirements to owner verification"\n      status: "${groupStatus(['CONF-01', 'CONF-02', 'CONF-03'])}"\n      evidence: "CONF-01/02/03 original-owner results."`,
    `    - name: "Phase 247 readiness tuple and dispositions"\n      status: "${integrationReady ? 'complete' : 'incomplete'}"\n      evidence: "READY-01 ${ready01?.status ?? 'missing'}; READY-02 ${ready02?.status ?? 'missing'}; packet ${result.currentReadiness.packetPath} SHA-256 ${result.currentReadiness.packetSha256 ?? 'missing'}."`,
    `    - name: "Phase 248 hosted terminal receipt retrieval"\n      status: "${groupStatus(['AUTO-01', 'AUTO-02'])}"\n      evidence: "AUTO-01/02 source-derived owner results."`,
    `    - name: "Phase 249 current-main release and PR reconciliation"\n      status: "${groupStatus(['REL-01', 'REL-02'])}"\n      evidence: "REL-01/02 source-derived owner results."`,
  ].join('\n');
  const currentReadinessYaml = [
    `current_ready_statuses:`,
    `  READY-01: "${result.currentReadiness.ready01}"`,
    `  READY-02: "${result.currentReadiness.ready02}"`,
    `current_ready_packet: "${result.currentReadiness.packetPath}"`,
    `current_ready_packet_sha256: "${result.currentReadiness.packetSha256 ?? 'missing'}"`,
    `current_ready_owner_phase: 247`,
    `historical_phase_250_exception_count: ${result.historicalExceptionCount}`,
    `historical_phase_250_exception_ids: [${result.historicalExceptions.map(({ id }) => id).join(', ')}]`,
    `historical_phase_250_owner_commit: "${historical?.commit ?? 'unavailable'}"`,
  ].join('\n');
  return `---
milestone: v1.49
audited: ${result.capturedAt}
status: ${gsdStatus}
source_audit_status: ${result.status}
milestone_status: ${result.milestoneStatus}
acceptance_amendment_sha256: ${result.acceptanceAmendment?.sha256 ?? 'missing'}
${currentReadinessYaml}
accepted_exception_count: 0
accepted_exception_ids: []
unaccepted_blocker_count: ${result.unacceptedBlockerCount}
scores:
  requirements: ${result.score.requirements}
  phases: ${result.score.phases}
  integration: ${result.score.integration}
  flows: ${result.score.flows}
nyquist:
  compliant_phases: [${result.nyquist.compliantPhases.join(', ')}]
  partial_phases: [${result.nyquist.partialPhases.join(', ')}]
  not_validated_phases: [${result.nyquist.notValidatedPhases.join(', ')}]
  missing_phases: [${result.nyquist.missingPhases.join(', ')}]
  overall: "${result.nyquist.overall}"
gaps:
  requirements:
${requirementsYaml}
  integration:
${integrationRows}
  integration_review:
    wiring: "${result.score.integration} handoff groups are source-verified"
    gaps: "${integrationReady ? '0' : '1'} readiness group remains incomplete"
    source: "Source-derived original-owner requirement results"
  flows:
${flowRows}
tech_debt:
  - phase: "247"
    items: ["${readinessReason(ready01).replaceAll('"', "'")}", "${readinessReason(ready02).replaceAll('"', "'")}"]
blockers:
${blockerYaml}
source_identities:
${result.sourceIdentities.map((item) => `  - phase: "${item.phase}"\n    path: "${item.path}"\n    captured_at: "${item.capturedAt ?? 'not captured'}"\n    identity: "${JSON.stringify(item).replaceAll('"', "'")}"`).join('\n')}
orphaned: [${result.orphaned.map((value) => `"${value}"`).join(', ')}]
contradiction_count: ${result.contradictions.length}
---

# v1.49 — RELEASE-1.6.0 Milestone Audit

## Outcome

The strict milestone status is **${gsdStatus}** at **${result.score.requirements} requirements**. The milestone ${result.milestoneStatus === 'passed' ? 'meets all nine owner-verification and traceability checks' : 'remains incomplete and unarchived because at least one original-owner requirement is unsatisfied or blocked'}. Current readiness comes from Phase 247's exact Phase 251 packet binding: READY-01 is **${ready01?.status ?? 'missing'}** and READY-02 is **${ready02?.status ?? 'missing'}**. ${historyParagraph}

## Requirements Coverage

This matrix cross-references original assignments, owner verifications, summary frontmatter, and REQUIREMENTS.md. A completed plan summary does not override an owner verifier that remains blocked.

| Requirement | Owner | Traceability | Owner verifier | Acceptance | Audit result | Evidence |
|---|---:|---|---|---|---|---|
${requirementRowsMd}

## Historical Phase 250 Exceptions

${historyParagraph}

## Current READY Evidence

Owner Phase 247 report: \`${result.owners['247']?.path}\` (SHA-256 ${result.owners['247']?.reportSha256 ?? 'missing'}). Current packet: \`${result.currentReadiness.packetPath}\` (SHA-256 ${result.currentReadiness.packetSha256 ?? 'missing'}). READY-01: **${ready01?.status ?? 'missing'}**. READY-02: **${ready02?.status ?? 'missing'}**. ${readyBlockerSummary}

## Source Reports

| Phase | Verifier status | Report SHA-256 | Snapshot captured |
|---:|---|---|---|
${ownerRows}

Distinct release identities remain separate: Phase 249 package source is ${result.owners['249']?.evidenceIdentities?.package_source_sha ?? '9e80cb78d6374b1ed4074d5fef6b613fee879dca'}; historical release main and current protected main are recorded separately in the source snapshot. The historical HANDOFF identity remains accepted-with-recorded-loss, with its bytes unrecovered and unpreserved.

## Unaccepted Blockers and Contradictions

${blockerRows || 'None.'}

## Integration and End-to-End Flows

${result.score.integration} of five handoff groups and ${result.score.flows} of four end-to-end flows are source-verified. Each group follows its original-owner requirement rows. No new release, canary, publish, merge, or workflow dispatch was performed for this audit.

## Nyquist Coverage

${result.nyquist.rows.map((row) => `- Phase ${row.phase}: **${row.status.replaceAll('_', ' ')}**${row.path ? ` — \`${row.path}\`${row.sha256 ? ` (SHA-256 ${row.sha256})` : ''}` : ''}`).join('\n')}
Overall: ${result.nyquist.overall}.

## Route

Keep v1.49 unarchived while the current audit is incomplete. Continue only from the live GSD phase state; Phase 250's historical acceptance does not change READY-01/02. Resolve each named owner-evidence blocker and regenerate this audit from the resulting Phase 247 verdicts before claiming milestone completion.
`;
}

export function checkAudit(root, auditPath = AUDIT_PATH, overrides = {}) {
  const expected = audit(root, { overrides });
  const actual = readSource(root, auditPath, overrides);
  if (actual === null) return { valid: false, errors: [`Missing generated audit ${auditPath}.`], expected };
  const errors = [];
  const frontmatter = actual.match(/^---\s*\n([\s\S]*?)\n---/m)?.[1] ?? '';
  if (!/^milestone:\s*v1\.49$/m.test(frontmatter) || !/^audited:\s*\S+/m.test(frontmatter)) errors.push('Audit is missing v1.49 generated frontmatter.');
  const auditedAt = frontmatter.match(/^audited:\s*(\S+)$/m)?.[1];
  const recordedStatus = frontmatter.match(/^status:\s*([\w-]+)/m)?.[1];
  if (recordedStatus !== expected.status) errors.push(`Audit status does not match computed GSD status ${expected.status}.`);
  if (frontmatter.match(/^source_audit_status:\s*([\w-]+)/m)?.[1] !== expected.status) errors.push(`Audit source status does not match computed ${expected.status}.`);
  if (frontmatter.match(/^milestone_status:\s*([\w-]+)/m)?.[1] !== expected.milestoneStatus) errors.push('Audit milestone status does not match the computed incomplete/complete result.');
  if (frontmatter.match(/^  requirements:\s*(\d+\/\d+)$/m)?.[1] !== expected.score.requirements) errors.push(`Audit score does not match computed ${expected.score.requirements}.`);
  const expectedReady01 = `  READY-01: "${expected.currentReadiness.ready01}"`;
  const expectedReady02 = `  READY-02: "${expected.currentReadiness.ready02}"`;
  if (!frontmatter.includes(expectedReady01) || !frontmatter.includes(expectedReady02)) errors.push('Audit current READY statuses do not match their Phase 247 owner verdicts.');
  for (const row of expected.requirements) {
    const exactRow = `| ${row.id} | ${row.phase} | ${row.traceability} | ${row.verification_status} | ${row.acceptance_status} | **${row.status}** | ${row.evidence} |`;
    if (!actual.includes(exactRow)) errors.push(`Audit requirement row ${row.id} differs from the source-derived owner verdict or traceability state.`);
  }
  if (auditedAt && actual !== renderAudit({ ...expected, capturedAt: auditedAt })) errors.push('Audit prose, historical exception provenance, counts, blockers, or route differ from the complete source-derived rendering.');
  for (const blocker of expected.blockers) if (!actual.includes(blocker.id)) errors.push(`Audit omits blocker identity ${blocker.id}.`);
  return { valid: errors.length === 0, errors, expected };
}

function main() {
  const args = process.argv.slice(2);
  const root = process.cwd();
  if (args[0] === '--check-sources') {
    const result = audit(root);
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    return;
  }
  if (args[0] === '--write-audit') {
    const destination = args[1] ?? AUDIT_PATH;
    const result = audit(root);
    writeFileSync(path.join(root, destination), renderAudit(result));
    process.stdout.write(`${JSON.stringify({ status: result.status, score: result.score, blockerCount: result.blockers.length, destination }, null, 2)}\n`);
    return;
  }
  if (args[0] === '--check-audit') {
    const checked = checkAudit(root, args[1] ?? AUDIT_PATH);
    process.stdout.write(`${JSON.stringify({ valid: checked.valid, errors: checked.errors, status: checked.expected.status, score: checked.expected.score, blockerCount: checked.expected.blockers.length }, null, 2)}\n`);
    if (!checked.valid) process.exitCode = 1;
    return;
  }
  process.stderr.write('Usage: verify-v149-traceability.mjs --check-sources | --write-audit [path] | --check-audit [path]\n');
  process.exitCode = 2;
}

if (import.meta.url === `file://${process.argv[1]}`) main();
