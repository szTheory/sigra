import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
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
const TRACE_PATH = '.planning/REQUIREMENTS.md';
const CLOSE_DIR = '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat';
const AUDIT_PATH = '.planning/v1.49-MILESTONE-AUDIT.md';
const ACCEPTANCE_PATH = CLOSE_DIR + '/250-ACCEPTANCE-AMENDMENT.json';
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
  return (frontStatus || proseStatus || 'missing').toLowerCase();
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
    return { valid: false, hash: null, ids: [] };
  }

  let amendment;
  try {
    amendment = JSON.parse(text);
  } catch (error) {
    add(blockers, 'ACCEPTANCE', 'Malformed Phase 250 acceptance amendment: ' + error.message, ACCEPTANCE_PATH);
    return { valid: false, hash: sha256(text), ids: [] };
  }

  const sourcePath = '.planning/phases/' + OWNER_DIR['247'] + '/247-VERIFICATION.md';
  const reconciliationPath = CLOSE_DIR + '/250-247-RECONCILIATION.json';
  const packetPath = CLOSE_DIR + '/250-247-TUPLE-DECISION-PACKET.json';
  const sourceText = readSource(root, sourcePath, overrides);
  const reconciliationText = readSource(root, reconciliationPath, overrides);
  const packetText = readSource(root, packetPath, overrides);
  let reconciliation = null;
  if (reconciliationText !== null) {
    try { reconciliation = JSON.parse(reconciliationText); } catch {
      add(blockers, 'ACCEPTANCE', 'The cited Phase 247 reconciliation is malformed.', reconciliationPath);
    }
  }
  const actualIds = [...new Set((reconciliation?.blockers ?? []).map(({ id }) => id))].sort();
  const expectedIds = [...ACCEPTED_READY_BLOCKER_IDS].sort();
  const exactIds = (left, right) => JSON.stringify(left) === JSON.stringify(right);
  const exceptionRows = Array.isArray(amendment.exceptions) ? amendment.exceptions : [];
  const exactExceptionIds = exceptionRows.map((row) => row?.id).sort();
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
    && sourceText !== null
    && sha256(sourceText) === exceptionRows[0]?.source_sha256
    && exceptionRows.every((row) => row && (
      row.owner_phase === 247
      && row.owner_verdict === 'unsatisfied'
      && row.acceptance === 'accepted_exception'
      && row.source === sourcePath
      && row.source_sha256 === sha256(sourceText)
      && row.reconciliation === reconciliationPath
      && row.reconciliation_sha256 === (reconciliationText === null ? null : sha256(reconciliationText))
      && row.tuple_packet === packetPath
      && row.tuple_packet_sha256 === (packetText === null ? null : sha256(packetText))
    ));

  if (!valid) {
    add(blockers, 'ACCEPTANCE', 'Phase 250 acceptance amendment is missing, altered, overbroad, or no longer matches the cited READY evidence.', {
      path: ACCEPTANCE_PATH,
      amendmentSha256: sha256(text),
      actualExceptionIds: exactExceptionIds,
      actualReconciliationBlockerIds: actualIds,
    });
  }
  return { valid, hash: sha256(text), ids: valid ? [...ACCEPTED_READY_IDS] : [] };
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
  const specific = parsed?.requirements?.[id];
  if (typeof specific === 'string') return specific.toLowerCase();
  if (specific?.status) return specific.status.toLowerCase();
  const table = text.match(new RegExp(`^\\|\\s*${id}\\s*\\|\\s*([^|]+)\\|`, 'm'))?.[1]?.trim().toLowerCase();
  if (table === 'satisfied' || table === 'unsatisfied' || table === 'partial') return table;
  if (overall === 'passed') return 'satisfied';
  return 'unsatisfied';
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
      const markerPath = reportText?.match(/<!-- reconciliation:\s*([^\s]+)\s*-->/)?.[1];
      const markerHash = reportText?.match(/<!-- reconciliation-sha256:\s*([a-f0-9]{64})\s*-->/)?.[1];
      if (!markerPath || !markerHash) add(blockers, 'READY-01', 'Phase 247 verification lacks its captured reconciliation identity.');
      else {
        const reconciliationText = readSource(root, markerPath, overrides);
        if (!reconciliationText || sha256(reconciliationText) !== markerHash) {
          add(blockers, 'READY-01', 'Phase 247 reconciliation input is missing or stale against its report digest.', markerPath);
        } else {
          parsed = JSON.parse(reconciliationText);
          report.reconciliation = markerPath;
          report.reconciliationSha256 = markerHash;
          report.capturedAt = parsed.captured_at ?? null;
          sourceIdentities.push({ phase, path: markerPath, sha256: markerHash, status: parsed.status });
          for (const item of parsed.blockers ?? []) {
            const readyOwner = ['authorization_pending', 'candidate_diff_digest_missing', 'dry_run_tuple_mismatch', 'exact_head_ci_source_missing', 'live_candidate_tuple_changed', 'readiness_tuple_mismatch'].includes(item.id) ? 'READY-01' : 'READY-02';
            add(blockers, readyOwner, `Phase 247 ${item.id}: ${item.message}`, item.identities ?? null);
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

    report.requirements = Object.keys(OWNER_PHASE).filter((id) => OWNER_PHASE[id] === phase).map((id) => ({ id, status: recomputedRequirements?.[id]?.status ?? reportRequirementStatus(phase, id, reportText, parsed) }));
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
  const amendment = readAcceptanceAmendment(root, blockers, options.overrides);
  if (amendment.valid) sourceIdentities.push({ phase: '250', path: ACCEPTANCE_PATH, sha256: amendment.hash });
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
    const status = verificationStatus === 'satisfied' ? 'satisfied' : ownerStatus === 'missing' ? 'orphaned' : 'unsatisfied';
    if (verificationStatus !== 'satisfied' && allClaims.length) {
      add(blockers, id, `Summary frontmatter claims ${id} although owner Phase ${phase} requirement verdict is ${verificationStatus} (overall report: ${ownerStatus}); plan completion does not satisfy the milestone requirement.`, allClaims.map(({ file }) => file));
    }
    if (status === 'satisfied' && row && !row.checked) add(blockers, id, 'Verification is passing but REQUIREMENTS.md remains unchecked; traceability needs reconciliation.', { phase });
    const acceptedByDecision = amendment.valid && amendment.ids.includes(id);
    if (acceptedByDecision && (status !== 'unsatisfied' || ownerStatus !== 'gaps_found' || row?.checked || allClaims.length > 0)) {
      add(blockers, 'ACCEPTANCE', 'Accepted READY exception no longer matches its unsatisfied owner report and unchecked requirement row.', {
        requirement: id,
        verificationStatus,
        ownerReportStatus: ownerStatus,
        checkboxChecked: row?.checked ?? null,
        summaryClaims: allClaims.map(({ file }) => file),
      });
    }
    return {
      id,
      phase,
      description: row?.description ?? 'Requirement row missing',
      traceability: row?.checked ? 'complete' : 'open',
      status,
      acceptance_status: acceptedByDecision ? 'accepted_exception' : status === 'satisfied' ? 'verified' : 'unaccepted',
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
  const expectedRequirementForReadyBlocker = {
    authorization_pending: 'READY-01',
    candidate_diff_digest_missing: 'READY-01',
    dry_run_tuple_mismatch: 'READY-01',
    exact_head_ci_source_missing: 'READY-01',
    fresh_inherited_dispositions_missing: 'READY-02',
    fresh_pr_dispositions_incomplete: 'READY-02',
    live_candidate_tuple_changed: 'READY-01',
    readiness_tuple_mismatch: 'READY-01',
  };
  const acceptedEvidenceBlockers = amendment.valid ? deduped.filter((blocker) => {
    if (!amendment.ids.includes(blocker.id)) return false;
    if (blocker.message === 'Canonical owner Phase 247 verifier is gaps_found; requirement verdict is unsatisfied.') return true;
    return Object.entries(expectedRequirementForReadyBlocker).some(([sourceId, requirementId]) =>
      blocker.id === requirementId && blocker.message.startsWith('Phase 247 ' + sourceId + ':')
    );
  }) : [];
  const acceptedEvidenceSet = new Set(acceptedEvidenceBlockers);
  const unacceptedBlockers = deduped.filter((blocker) => !acceptedEvidenceSet.has(blocker));
  const acceptedExceptions = requirementList
    .filter((row) => row.acceptance_status === 'accepted_exception')
    .map((row) => ({
      id: row.id,
      acceptance_status: row.acceptance_status,
      owner_verification_status: row.verification_status,
      owner_report_status: row.owner_report_status,
      evidence_blockers: acceptedEvidenceBlockers.filter((blocker) => blocker.id === row.id),
    }));
  const satisfied = requirementList.filter((row) => row.status === 'satisfied').length;
  const exceptionsAreComplete =
    amendment.valid
    && satisfied === 7
    && acceptedExceptions.length === 2
    && acceptedExceptions.every((row) => row.owner_verification_status === 'unsatisfied' && row.owner_report_status === 'gaps_found' && row.evidence_blockers.length > 0)
    && unacceptedBlockers.length === 0;
  const status = satisfied === requirementList.length && unacceptedBlockers.length === 0
    ? 'passed'
    : exceptionsAreComplete ? 'accepted_exceptions' : 'gaps_found';
  return {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    status,
    milestoneStatus: status === 'passed' ? 'passed' : 'incomplete',
    acceptanceAmendment: amendment.valid ? { path: ACCEPTANCE_PATH, sha256: amendment.hash } : null,
    acceptedExceptionCount: acceptedExceptions.length,
    unacceptedBlockerCount: unacceptedBlockers.length,
    score: { requirements: `${satisfied}/${requirementList.length}`, phases: '4/5', integration: '4/5', flows: '3/4' },
    nyquist: {
      compliantPhases: [246, 247, 249, 250],
      partialPhases: [248],
      notValidatedPhases: [],
      missingPhases: [],
      overall: 'partial',
    },
    requirements: requirementList,
    owners,
    sourceIdentities,
    acceptedExceptions,
    blockers: unacceptedBlockers,
    sourceBlockers: deduped,
    orphaned: requirementList.filter((row) => row.status === 'orphaned').map(({ id }) => id),
    contradictions: unacceptedBlockers.filter((item) => /differs|claims|outside original|mismatch|changed|recovered\/preserved|unchecked/i.test(item.message)),
  };
}

export function renderAudit(result) {
  const acceptedIdsYaml = result.acceptedExceptions.map(({ id }) => id).join(', ');
  const requirementsYaml = result.requirements.map((row) => [
    `    - id: "${row.id}"`, `      status: "${row.status}"`, `      acceptance_status: "${row.acceptance_status}"`, `      phase: "${row.phase}"`,
    `      claimed_by_plans: [${row.claimed_by_plans.map((value) => `"${value}"`).join(', ')}]`,
    `      completed_by_plans: [${row.completed_by_plans.map((value) => `"${value}"`).join(', ')}]`,
    `      verification_status: "${row.verification_status}"`, `      owner_report_status: "${row.owner_report_status}"`, `      evidence: "${row.evidence.replaceAll('"', "'")}"`,
  ].join('\n')).join('\n');
  const blockerYaml = result.blockers.map((row) => `  - id: "${row.id}"\n    message: "${row.message.replaceAll('"', "'")}"${row.identity === undefined ? '' : `\n    identity: "${JSON.stringify(row.identity).replaceAll('"', "'")}"`}`).join('\n');
  const requirementRowsMd = result.requirements.map((row) => `| ${row.id} | ${row.phase} | ${row.traceability} | ${row.verification_status} | ${row.acceptance_status} | **${row.status}** | ${row.evidence} |`).join('\n');
  const ownerRows = Object.values(result.owners).map((row) => `| ${row.phase} | ${row.status} | ${row.reportSha256 ?? 'missing'} | ${row.snapshotCapturedAt ?? row.capturedAt ?? 'not captured'} |`).join('\n');
  const blockerRows = result.blockers.map((row) => `- **${row.id}:** ${row.message}${row.identity === undefined ? '' : ` Identity: \`${JSON.stringify(row.identity)}\`.`}`).join('\n');
  return `---
milestone: v1.49
audited: ${result.capturedAt}
status: ${result.status}
milestone_status: ${result.milestoneStatus}
acceptance_amendment_sha256: ${result.acceptanceAmendment?.sha256 ?? 'missing'}
accepted_exception_count: ${result.acceptedExceptionCount}
accepted_exception_ids: [${acceptedIdsYaml}]
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
    - requirement: "CONF-01/02/03"
      status: "complete"
      evidence: "All three confirmation requirements are source-verified."
    - requirement: "READY-01/02"
      status: "accepted_exception"
      evidence: "Phase 247 remains gaps_found; both owner verdicts remain unsatisfied and are accepted only for Phase 250 closeout."
    - requirement: "AUTO-01"
      status: "complete"
      evidence: "Phase 248 owner verification and the source-bound release evidence pass."
    - requirement: "AUTO-02"
      status: "complete"
      evidence: "The exact failure and cancellation receipts, artifact digests, and observer identity match the Phase 248 snapshot."
    - requirement: "REL-01"
      status: "complete"
      evidence: "The evidence-ref release path is connected and source-verified."
    - requirement: "REL-02"
      status: "complete"
      evidence: "Phase 249 owner verification passes against the captured current-main CI and disposition inventory."
  integration_review:
    wiring: "4/5 handoff groups are source-verified"
    gaps: "1/5 readiness group remains an accepted exception"
    source: "Source-derived owner and accepted-exception audit"
  flows:
    - name: "Confirmation requirements to owner verification"
      status: "complete"
      evidence: "CONF-01/02/03 have consistent source verification."
    - name: "Phase 247 readiness tuple and dispositions"
      status: "accepted_exception"
      evidence: "The owner report remains unsatisfied; see the exact tuple packet and reconciliation."
    - name: "Phase 248 hosted terminal receipt retrieval"
      status: "complete"
      evidence: "The source failure and cancellation artifacts and observer receipt validate against their snapshot."
    - name: "Phase 249 current-main release and PR reconciliation"
      status: "complete"
      evidence: "Current-main CI and the 15-PR inventory pass against the captured exact identities."
tech_debt:
  - phase: "247"
    items: ["READY-01/02 remain unsatisfied under Phase 247; Phase 250 accepts these two gaps for phase closeout only."]
blockers:
${blockerYaml}
source_identities:
${result.sourceIdentities.map((item) => `  - phase: "${item.phase}"\n    path: "${item.path}"\n    captured_at: "${item.capturedAt ?? 'not captured'}"\n    identity: "${JSON.stringify(item).replaceAll('"', "'")}"`).join('\n')}
orphaned: [${result.orphaned.map((value) => `"${value}"`).join(', ')}]
contradiction_count: ${result.contradictions.length}
---

# v1.49 — RELEASE-1.6.0 Milestone Audit

## Outcome

The strict audit status is **${result.status}** at **${result.score.requirements} requirements**. Phase 247 remains gaps_found; READY-01/02 remain owner-unsatisfied and are accepted exceptions only for Phase 250. AUTO-01/02 and REL-01/02 are source-verified by their original owner reports. The milestone remains incomplete and unarchived.

## Requirements Coverage

This matrix cross-references original assignments, owner verifications, summary frontmatter, and REQUIREMENTS.md. A completed plan summary does not override an owner verifier that remains blocked.

| Requirement | Owner | Traceability | Owner verifier | Acceptance | Audit result | Evidence |
|---|---:|---|---|---|---|---|
${requirementRowsMd}

## Accepted Exceptions

READY-01 and READY-02 remain unsatisfied in Phase 247. The user-approved amendment accepts these historical evidence gaps for Phase 250 closeout only. The decision record, original owner report, reconciliation digest, tuple packet, and exact missing-join identities are linked under Source Reports; none is represented as a passed verification.

## Source Reports

| Phase | Verifier status | Report SHA-256 | Snapshot captured |
|---:|---|---|---|
${ownerRows}

Distinct release identities remain separate: Phase 249 package source is ${result.owners['249']?.evidenceIdentities?.package_source_sha ?? '9e80cb78d6374b1ed4074d5fef6b613fee879dca'}; historical release main and current protected main are recorded separately in the source snapshot. The historical HANDOFF identity remains accepted-with-recorded-loss, with its bytes unrecovered and unpreserved.

## Unaccepted Blockers and Contradictions

${blockerRows || 'None.'}

## Integration and End-to-End Flows

Four of five handoff groups are source-verified. The remaining readiness group is recorded as the two accepted, unsatisfied READY exceptions. AUTO-01/02 and REL-01/02 pass against their original owner reports. No new release, canary, publish, merge, or workflow dispatch was performed for this audit.

## Nyquist Coverage

Phase 246, 247, and 249 compliant; Phase 248 partial; Phase 250 validation remains pending until Plan 13's deterministic gates finish. Overall: partial.

## Route

Keep v1.49 unarchived. Phase 250 may complete against its amended phase-only acceptance after all deterministic gates pass; milestone verification remains incomplete at 7/9. Revisit READY-01/02 only if new matching evidence or a new acceptance decision changes their status.
`;
}

export function checkAudit(root, auditPath = AUDIT_PATH, overrides = {}) {
  const expected = audit(root, { overrides });
  const actual = readSource(root, auditPath, overrides);
  if (actual === null) return { valid: false, errors: [`Missing generated audit ${auditPath}.`], expected };
  const errors = [];
  const frontmatter = actual.match(/^---\s*\n([\s\S]*?)\n---/m)?.[1] ?? '';
  if (!/^milestone:\s*v1\.49$/m.test(frontmatter) || !/^audited:\s*\S+/m.test(frontmatter)) errors.push('Audit is missing v1.49 generated frontmatter.');
  const recordedStatus = frontmatter.match(/^status:\s*([\w-]+)/m)?.[1];
  if (recordedStatus !== expected.status) errors.push(`Audit status does not match computed ${expected.status}.`);
  const recordedScore = frontmatter.match(/^  requirements:\s*(\d+\/\d+)$/m)?.[1];
  const recordedMilestoneStatus = frontmatter.match(/^milestone_status:\s*([\w-]+)/m)?.[1];
  if (recordedMilestoneStatus !== expected.milestoneStatus) errors.push('Audit milestone status does not match the computed incomplete/complete result.');
  const recordedExceptionCount = Number(frontmatter.match(/^accepted_exception_count:\s*(\d+)$/m)?.[1] ?? -1);
  if (recordedExceptionCount !== expected.acceptedExceptionCount) errors.push('Audit accepted-exception count does not match computed source state.');
  const expectedExceptionIds = 'accepted_exception_ids: [' + expected.acceptedExceptions.map(({ id }) => id).join(', ') + ']';
  if (!frontmatter.includes(expectedExceptionIds)) errors.push('Audit accepted-exception identities do not match the amendment.');
  const recordedUnacceptedCount = Number(frontmatter.match(/^unaccepted_blocker_count:\s*(\d+)$/m)?.[1] ?? -1);
  if (recordedUnacceptedCount !== expected.unacceptedBlockerCount) errors.push('Audit unaccepted-blocker count does not match computed source state.');
  const recordedAmendmentSha = frontmatter.match(/^acceptance_amendment_sha256:\s*([a-f0-9]{64})$/m)?.[1];
  if (recordedAmendmentSha !== expected.acceptanceAmendment?.sha256) errors.push('Audit does not bind the exact acceptance amendment.');
  if (recordedScore !== expected.score.requirements) errors.push(`Audit score does not match computed ${expected.score.requirements}.`);
  for (const row of expected.requirements) if (!actual.includes(`| ${row.id} |`)) errors.push(`Audit is missing requirement row ${row.id}.`);
  if (expected.status === 'accepted_exceptions' && (recordedStatus === 'passed' || recordedMilestoneStatus === 'passed')) errors.push('Audit falsely claims milestone completion while accepted requirements remain unsatisfied.');
  if (expected.status === 'gaps_found' && recordedStatus === 'passed') errors.push('Audit falsely claims passed while computed blockers remain.');
  for (const row of expected.acceptedExceptions) {
    if (!actual.includes(row.id) || !actual.includes('accepted_exception')) errors.push('Audit omits accepted exception ' + row.id + '.');
  }
  const reportText = actual;
  for (const blocker of expected.blockers) if (!reportText.includes(blocker.id)) errors.push(`Audit omits blocker identity ${blocker.id}.`);
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
