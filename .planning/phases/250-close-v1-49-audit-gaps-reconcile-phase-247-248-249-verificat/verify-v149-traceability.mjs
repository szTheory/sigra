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
            if (proof.status !== 'passed' || proof.source_failure?.receipt_artifact?.status !== 'retrieved' || proof.source_cancellation?.artifact?.status !== 'retrieved') {
              add(blockers, 'AUTO-02', `Hosted failure/cancellation receipts are not both validated (proof ${proof.status}; failure ${proof.source_failure?.receipt_artifact?.status ?? 'missing'}; cancellation ${proof.source_cancellation?.artifact?.status ?? 'missing'}).`, { controllerRunId: proof.controller_run?.id ?? null, failureRunId: proof.source_failure?.id ?? null, cancellationRunId: proof.source_cancellation?.run_id ?? null });
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
        const live = readJson(root, livePath, blockers, overrides);
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
    return {
      id,
      phase,
      description: row?.description ?? 'Requirement row missing',
      traceability: row?.checked ? 'complete' : 'open',
      status,
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
  const satisfied = requirementList.filter((row) => row.status === 'satisfied').length;
  return {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    status: satisfied === requirementList.length && deduped.length === 0 ? 'passed' : 'gaps_found',
    score: { requirements: `${satisfied}/${requirementList.length}`, phases: '1/5', integration: '3/5', flows: '1/4' },
    nyquist: {
      compliantPhases: [246, 247, 249],
      partialPhases: [248],
      notValidatedPhases: [],
      missingPhases: [250],
      overall: 'partial',
    },
    requirements: requirementList,
    owners,
    sourceIdentities,
    blockers: deduped,
    orphaned: requirementList.filter((row) => row.status === 'orphaned').map(({ id }) => id),
    contradictions: deduped.filter((item) => /differs|claims|outside original|mismatch|changed|recovered\/preserved|unchecked/i.test(item.message)),
  };
}

export function renderAudit(result) {
  const requirementsYaml = result.requirements.map((row) => [
    `    - id: "${row.id}"`, `      status: "${row.status}"`, `      phase: "${row.phase}"`,
    `      claimed_by_plans: [${row.claimed_by_plans.map((value) => `"${value}"`).join(', ')}]`,
    `      completed_by_plans: [${row.completed_by_plans.map((value) => `"${value}"`).join(', ')}]`,
    `      verification_status: "${row.verification_status}"`, `      owner_report_status: "${row.owner_report_status}"`, `      evidence: "${row.evidence.replaceAll('"', "'")}"`,
  ].join('\n')).join('\n');
  const blockerYaml = result.blockers.map((row) => `  - id: "${row.id}"\n    message: "${row.message.replaceAll('"', "'")}"${row.identity === undefined ? '' : `\n    identity: "${JSON.stringify(row.identity).replaceAll('"', "'")}"`}`).join('\n');
  const requirementRowsMd = result.requirements.map((row) => `| ${row.id} | ${row.phase} | ${row.traceability} | ${row.verification_status} | **${row.status}** | ${row.evidence} |`).join('\n');
  const ownerRows = Object.values(result.owners).map((row) => `| ${row.phase} | ${row.status} | ${row.reportSha256 ?? 'missing'} | ${row.snapshotCapturedAt ?? row.capturedAt ?? 'not captured'} |`).join('\n');
  const blockerRows = result.blockers.map((row) => `- **${row.id}:** ${row.message}${row.identity === undefined ? '' : ` Identity: \`${JSON.stringify(row.identity)}\`.`}`).join('\n');
  return `---
milestone: v1.49
audited: ${result.capturedAt}
status: ${result.status}
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
      status: "blocked"
      evidence: "Phase 247 remains gaps_found because approval, exact tuple, dry-run and fresh disposition joins are incomplete."
    - requirement: "AUTO-01"
      status: "partial"
      evidence: "The release wiring is evidenced, while credential-scope proof remains unresolved."
    - requirement: "AUTO-02"
      status: "blocked"
      evidence: "Hosted failure and cancellation artifacts are absent; the canary proof remains blocked."
    - requirement: "REL-01"
      status: "complete"
      evidence: "The evidence-ref release path is connected and source-verified."
    - requirement: "REL-02"
      status: "blocked"
      evidence: "The current-main workflow failed despite a successful ci-gate, and five PR dispositions remain missing."
  integration_review:
    wiring: "3/5 downstream release handoffs evidenced"
    gaps: "2/5 broken at the evidence/acceptance join"
    source: "Read-only cross-phase integration checker"
  flows:
    - name: "Confirmation requirements to owner verification"
      status: "complete"
      evidence: "CONF-01/02/03 have consistent source verification."
    - name: "Phase 247 readiness tuple and dispositions"
      status: "blocked"
      evidence: "Candidate approval, exact tuple, dry-run and inherited dispositions do not join."
    - name: "Phase 248 hosted terminal receipt retrieval"
      status: "blocked"
      evidence: "Failure and cancellation artifacts are not validated."
    - name: "Phase 249 current-main release and PR reconciliation"
      status: "blocked"
      evidence: "Current-main workflow failure and five missing PR dispositions remain."
tech_debt:
  - phase: "247"
    items: ["Candidate approval, tuple joins, exact-head source receipt, and fresh disposition evidence remain incomplete."]
  - phase: "248"
    items: ["Hosted failure/cancellation artifact retrieval remains incomplete."]
  - phase: "249"
    items: ["Current-main workflow failed and PR dispositions are missing for #302, #306, #307, #308, and #309."]
blockers:
${blockerYaml}
source_identities:
${result.sourceIdentities.map((item) => `  - phase: "${item.phase}"\n    path: "${item.path}"\n    captured_at: "${item.capturedAt ?? 'not captured'}"\n    identity: "${JSON.stringify(item).replaceAll('"', "'")}"`).join('\n')}
orphaned: [${result.orphaned.map((value) => `"${value}"`).join(', ')}]
contradiction_count: ${result.contradictions.length}
---

# v1.49 — RELEASE-1.6.0 Milestone Audit

## Outcome

The strict audit remains **${result.status}** at **${result.score.requirements} requirements**. Canonical Phase 247, 248, and 249 reports have been captured against their linked evidence identities, but the source reports remain gaps_found. The result preserves the completed Phase 246 confirmation rows and does not promote original owner rows or claim any Phase 250 requirement ownership.

## Requirements Coverage

This matrix cross-references original assignments, owner verifications, summary frontmatter, and REQUIREMENTS.md. A completed plan summary does not override an owner verifier that remains blocked.

| Requirement | Owner | Traceability | Owner verifier | Audit result | Evidence |
|---|---:|---|---|---|---|
${requirementRowsMd}

## Source Reports

| Phase | Verifier status | Report SHA-256 | Snapshot captured |
|---:|---|---|---|
${ownerRows}

Distinct release identities remain separate: Phase 249 package source is ${result.owners['249']?.evidenceIdentities?.package_source_sha ?? '9e80cb78d6374b1ed4074d5fef6b613fee879dca'}; historical release main and current protected main are recorded separately in the source snapshot. The historical HANDOFF identity remains accepted-with-recorded-loss, with its bytes unrecovered and unpreserved.

## Blockers and Contradictions

${blockerRows || 'None.'}

## Integration and End-to-End Flows

The read-only integration review finds 3/5 downstream release handoffs evidenced, with 2/5 broken at the evidence/acceptance join. CONF-01/02/03 and REL-01 are wired; READY-01/02 and AUTO-02 remain blocked, AUTO-01 is partial, and REL-02 is blocked by current-main CI and missing dispositions. No new release, canary, publish, merge, or workflow dispatch was performed for this audit.

## Nyquist Coverage

Phase 246 compliant; Phase 247 compliant; Phase 248 partial; Phase 249 compliant; Phase 250 missing validation evidence. Overall: partial.

## Route

Keep v1.49 unarchived. Phase 250 plan reporting may complete with this blocked audit record; milestone verification and closure remain incomplete. Revisit only the named blockers when authorized evidence changes. Do not repeat the consumed canary retry.
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
  if (recordedScore !== expected.score.requirements) errors.push(`Audit score does not match computed ${expected.score.requirements}.`);
  for (const row of expected.requirements) if (!actual.includes(`| ${row.id} |`)) errors.push(`Audit is missing requirement row ${row.id}.`);
  if (expected.status === 'gaps_found' && recordedStatus === 'passed') errors.push('Audit falsely claims passed while computed blockers remain.');
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
