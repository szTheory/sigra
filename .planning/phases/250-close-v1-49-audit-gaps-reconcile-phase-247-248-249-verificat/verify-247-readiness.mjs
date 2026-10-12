#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
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
const phase251Dir = path.resolve(here, '../251-close-ready-01-and-ready-02-release-readiness-gaps');
const phase251FeasibilityPath = path.join(phase251Dir, '251-EVIDENCE-FEASIBILITY.json');
const phase251ReconciliationPath = path.join(phase251Dir, '251-247-RECONCILIATION.json');
const phase251SummaryPath = path.join(phase251Dir, '251-EVIDENCE-SUMMARY.md');
const phase251CandidateTuple = {
  candidate_sha: '0e773d3614a242e4fbcdd34c418ecb8a307703d6',
  reviewed_base_sha: 'd135cbce343947499a0810736c500ef5f1cb5c32',
  protected_main_sha: 'a494f3ee3878da93aab4f70712ffddeefd77a802',
};
const phase251PublishedSource = {
  tag: 'v1.6.0',
  tag_ref: 'refs/tags/v1.6.0',
  commit_sha: '9e80cb78d6374b1ed4074d5fef6b613fee879dca',
};
const phase251ApprovalWindow = {
  start: '2026-10-08T17:41:43Z',
  end: '2026-10-09T00:56:51Z',
};
const phase251OwnerReportSource = {
  identity: 'historical_owner_report:0e7a2835ebd0d7a1e791ad4dbc73955270108ed1',
  commit_sha: '0e7a2835ebd0d7a1e791ad4dbc73955270108ed1',
  path: '.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md',
  git_blob_oid: 'da60a96544dcb1dff301e416930e183e021f0b6e',
  sha256: 'd34f94f861b5fc4983138efadd26ae3b93336bb0b3b8e63afcf1c866fd709e39',
};
const phase251ExactHeadCi = { run_id: 37819712610, attempt: 1, head_sha: phase251CandidateTuple.candidate_sha };

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function safeCommand(command, args, cwd = repoRoot) {
  try {
    return { ok: true, stdout: execFileSync(command, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() };
  } catch {
    return { ok: false, stdout: '' };
  }
}

function safeCommandBytes(command, args, cwd = repoRoot) {
  try {
    return { ok: true, stdout: execFileSync(command, args, { cwd, stdio: ['ignore', 'pipe', 'ignore'] }) };
  } catch {
    return { ok: false, stdout: Buffer.alloc(0) };
  }
}

function sameTuple(a, b) {
  return Boolean(a && b && a.candidateSha === b.candidateSha && a.reviewedBaseSha === b.reviewedBaseSha && a.mainSha === b.mainSha);
}

const phase251RequiredSources = {
  READY01: [
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, '.release-please-manifest.json'],
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, 'release-please-config.json'],
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, 'mix.exs'],
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, 'CHANGELOG.md'],
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, 'README.md'],
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, 'guides/introduction/upgrading-to-v1.6.md'],
    ['candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6', phase251CandidateTuple.candidate_sha, 'test/example/priv/playwright/tests/organizations.spec.ts'],
    ['published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca', phase251PublishedSource.commit_sha, 'mix.exs'],
    ['published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca', phase251PublishedSource.commit_sha, 'CHANGELOG.md'],
    ['published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca', phase251PublishedSource.commit_sha, 'README.md'],
    ['published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca', phase251PublishedSource.commit_sha, 'guides/introduction/upgrading-to-v1.6.md'],
    ['published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca', phase251PublishedSource.commit_sha, 'lib/sigra.ex'],
  ],
};

const phase251PackageCheckNames = [
  'package_version', 'package_metadata', 'release_manifest', 'release_config', 'changelog',
  'tag_target', 'hexdocs_source_reference', 'published_tag_guide', 'readme_guide_link',
  'adopter_shipped_changes', 'adopter_compatibility', 'generated_host_action',
  'version_requirement', 'update_check_path',
];

const candidateIdentity = `candidate:${phase251CandidateTuple.candidate_sha}`;
const publishedIdentity = `published_tag:${phase251PublishedSource.tag}:${phase251PublishedSource.commit_sha}`;
const candidateSource = (sourcePath, assertions) => ({ identity: candidateIdentity, commit_sha: phase251CandidateTuple.candidate_sha, path: sourcePath, assertions });
const publishedSource = (sourcePath, assertions) => ({ identity: publishedIdentity, commit_sha: phase251PublishedSource.commit_sha, path: sourcePath, assertions });

// Each assertion is a stable, check-specific claim against an immutable source record.
// The source_ref repeats the complete source identity so downstream audits can join it
// without trusting the free-form evidence_detail/finding_detail strings.
export const phase251PackageCheckRequirements = {
  package_version: [candidateSource('mix.exs', ['candidate_version_1_6_0']), publishedSource('mix.exs', ['published_version_1_6_0'])],
  package_metadata: [candidateSource('mix.exs', ['candidate_package_metadata_sigra_1_6_0']), publishedSource('mix.exs', ['published_package_metadata_sigra_1_6_0'])],
  release_manifest: [candidateSource('.release-please-manifest.json', ['manifest_version_1_6_0'])],
  release_config: [candidateSource('release-please-config.json', ['release_config_elixir_changelog'])],
  changelog: [candidateSource('CHANGELOG.md', ['candidate_changelog_1_6_0']), publishedSource('CHANGELOG.md', ['published_changelog_1_6_0'])],
  tag_target: [publishedSource('mix.exs', ['tag_v1_6_0_targets_published_commit'])],
  hexdocs_source_reference: [publishedSource('mix.exs', ['hexdocs_uses_version_source_ref']), publishedSource('lib/sigra.ex', ['published_module_source'])],
  published_tag_guide: [publishedSource('guides/introduction/upgrading-to-v1.6.md', ['published_guide_present'])],
  readme_guide_link: [candidateSource('README.md', ['candidate_readme_guide_link']), publishedSource('README.md', ['published_readme_guide_link'])],
  adopter_shipped_changes: [candidateSource('guides/introduction/upgrading-to-v1.6.md', ['guide_shipped_changes']), candidateSource('test/example/priv/playwright/tests/organizations.spec.ts', ['generated_host_regression_coverage'])],
  adopter_compatibility: [candidateSource('guides/introduction/upgrading-to-v1.6.md', ['guide_compatibility_constraints'])],
  generated_host_action: [candidateSource('guides/introduction/upgrading-to-v1.6.md', ['guide_host_actions']), candidateSource('test/example/priv/playwright/tests/organizations.spec.ts', ['host_action_test_coverage'])],
  version_requirement: [candidateSource('guides/introduction/upgrading-to-v1.6.md', ['guide_version_requirement']), candidateSource('mix.exs', ['candidate_package_version_requirement'])],
  update_check_path: [candidateSource('guides/introduction/upgrading-to-v1.6.md', ['guide_update_and_check_steps']), candidateSource('README.md', ['readme_points_to_upgrade_guide'])],
};

function trustedReadableSource(source) {
  return source?.read_status === 'readable'
    && typeof source.trust_status === 'string'
    && source.trust_status.startsWith('trusted_')
    && /^[a-f0-9]{40}$/.test(source.git_blob_oid ?? '')
    && source.git_blob_oid === source.api_blob_oid
    && /^[a-f0-9]{64}$/.test(source.sha256 ?? '')
    && source.sha256 === source.api_sha256;
}

function readVerifiedPackageSource(source) {
  if (!trustedReadableSource(source)) return null;
  const blob = safeCommand('git', ['rev-parse', `${source.commit_sha}:${source.path}`]);
  const bytes = safeCommandBytes('git', ['show', `${source.commit_sha}:${source.path}`]);
  if (!blob.ok || blob.stdout !== source.git_blob_oid || !bytes.ok
    || sha256(bytes.stdout) !== source.sha256) return null;
  return bytes.stdout;
}

export function evaluatePhase251PackageAssertion(id, sourceBytes, source = {}) {
  if (!Buffer.isBuffer(sourceBytes) || sourceBytes.length === 0) return false;
  const text = sourceBytes.toString('utf8');
  const guideHasVersion = /# Upgrade to Sigra v1\.6\.0/.test(text);
  const readmeHasGuide = /\[[^\]]+\]\(guides\/introduction\/upgrading-to-v1\.6\.md(?:#[^)]*)?\)/i.test(text);
  const changelogHasVersion = /^## \[1\.6\.0\]/m.test(text);
  const mixHasVersion = /@version\s+"1\.6\.0"/.test(text) && /version:\s*@version/.test(text);
  switch (id) {
    case 'candidate_version_1_6_0':
    case 'published_version_1_6_0': return mixHasVersion;
    case 'candidate_package_metadata_sigra_1_6_0':
    case 'published_package_metadata_sigra_1_6_0': return /app:\s*:sigra/.test(text) && mixHasVersion;
    case 'manifest_version_1_6_0': {
      try { return JSON.parse(text)['.'] === '1.6.0'; } catch { return false; }
    }
    case 'release_config_elixir_changelog': {
      try { const cfg = JSON.parse(text); return cfg['release-type'] === 'elixir' && cfg.packages?.['.']?.['changelog-path'] === 'CHANGELOG.md'; } catch { return false; }
    }
    case 'candidate_changelog_1_6_0':
    case 'published_changelog_1_6_0': return changelogHasVersion;
    case 'tag_v1_6_0_targets_published_commit': {
      const target = safeCommand('git', ['rev-parse', '--verify', 'refs/tags/v1.6.0^{commit}']);
      return target.ok && target.stdout === source.commit_sha && mixHasVersion;
    }
    case 'hexdocs_uses_version_source_ref': return /source_ref:\s*"v#\{@version\}"/.test(text) && mixHasVersion;
    case 'published_module_source': return /^defmodule Sigra/m.test(text) && /@moduledoc/.test(text);
    case 'published_guide_present': return guideHasVersion;
    case 'candidate_readme_guide_link':
    case 'readme_points_to_upgrade_guide': return readmeHasGuide;
    case 'published_readme_guide_link': return readmeHasGuide;
    case 'guide_shipped_changes': return guideHasVersion && /pasted six-digit codes/i.test(text) && /retry after an invalid code/i.test(text);
    case 'generated_host_regression_coverage': return /test\(['"`].*(?:organization|confirmation)/i.test(text) && /expect\(/.test(text);
    case 'guide_compatibility_constraints': return /Elixir `~> 1\.18`/.test(text) && /Phoenix `~> 1\.8`/.test(text) && /Phoenix LiveView `~> 1\.1`/.test(text);
    case 'guide_host_actions': return /mix deps\.update sigra/.test(text) && /selectively adopt/i.test(text) && /mix sigra\.install/.test(text);
    case 'host_action_test_coverage': return /test\(['"`].*organizations UX/i.test(text) && /await expect\(/.test(text);
    case 'guide_version_requirement': return /~> 1\.6\.0/.test(text);
    case 'candidate_package_version_requirement': return mixHasVersion;
    case 'guide_update_and_check_steps': return /mix deps\.update sigra/.test(text) && /mix deps\.tree/.test(text) && /host checks/i.test(text);
    default: return false;
  }
}

function phase251SliceSourceBlockers(requirementName, requirement) {
  const blockers = [];
  if (!requirement || !Array.isArray(requirement.sources)) return [`${requirementName}_sources_missing`];
  const expected = phase251RequiredSources[requirementName] ?? [];
  for (const [identity, commitSha, sourcePath] of expected) {
    const source = requirement.sources.find((item) => item?.source_identity === identity && item?.commit_sha === commitSha && item?.path === sourcePath);
    if (!source) blockers.push(`${requirementName}_source_identity_missing:${identity}:${sourcePath}`);
    else if (!trustedReadableSource(source) && !(source.read_status === 'missing' && source.trust_status === 'trusted_exact_commit_404')) {
      blockers.push(`${requirementName}_source_unreadable_or_untrusted:${identity}:${sourcePath}`);
    }
  }
  for (const source of requirement.sources) {
    if (source?.read_status === 'unreadable' || source?.trust_status === 'untrusted' || source?.trust_status?.startsWith('untrusted_')) {
      blockers.push(`${requirementName}_source_unreadable_or_untrusted:${source.source_identity ?? 'unknown'}:${source.path ?? 'unknown'}`);
    }
  }
  return [...new Set(blockers)].sort();
}

function namedPackageCheckFailure(packageAdopter, sourceRecords = packageAdopter?.sources ?? []) {
  if (!packageAdopter?.checks || typeof packageAdopter.checks !== 'object') return ['package_adopter_checks_missing'];
  return phase251PackageCheckNames.flatMap((name) => {
    const check = packageAdopter.checks[name];
    if (!check || !['pass', 'missing', 'mismatch', 'unreadable'].includes(check.result)) return [`package_check_missing:${name}`];
    const requirements = phase251PackageCheckRequirements[name] ?? [];
    const refs = check.source_refs;
    const assertions = check.source_assertions;
    const key = (ref) => `${ref?.identity ?? ref?.source_identity}:${ref?.commit_sha}:${ref?.path}`;
    const expectedKeys = requirements.map(key).sort();
    const actualKeys = Array.isArray(refs) ? refs.map(key).sort() : [];
    const sourceMap = new Map(sourceRecords.map((source) => [key(source), source]));
    const validSourceForResult = (source) => trustedReadableSource(source)
      || (check.result !== 'pass' && source?.read_status === 'missing'
        && source?.trust_status === 'trusted_exact_commit_404' && source?.http_status === 404);
    const refFailures = !requirements.length || !Array.isArray(refs)
      || refs.length !== requirements.length || new Set(actualKeys).size !== actualKeys.length
      || JSON.stringify(actualKeys) !== JSON.stringify(expectedKeys)
      || requirements.some((required) => {
        const source = sourceMap.get(key(required));
        const ref = refs.find((item) => key(item) === key(required));
        return !validSourceForResult(source) || !validSourceForResult(ref)
          || source.git_blob_oid !== ref.git_blob_oid || source.sha256 !== ref.sha256;
      });
    if (refFailures) return [`package_check_source_refs_invalid:${name}`];

    const expectedAssertions = requirements.flatMap((required) => required.assertions.map((id) => ({
      id, identity: required.identity, commit_sha: required.commit_sha, path: required.path,
      source: sourceMap.get(key(required)),
    }))).sort((a, b) => a.id.localeCompare(b.id));
    const actualAssertions = Array.isArray(assertions) ? assertions : [];
    const sourceResults = expectedAssertions.map((expected) => {
      const bytes = readVerifiedPackageSource(expected.source);
      return { expected, bytes, actual: bytes ? evaluatePhase251PackageAssertion(expected.id, bytes, expected.source) : null };
    });
    const assertionFailures = actualAssertions.length !== expectedAssertions.length
      || new Set(actualAssertions.map((item) => item?.id)).size !== actualAssertions.length
        || expectedAssertions.some((expected) => {
        const actual = actualAssertions.find((item) => item?.id === expected.id);
        const source = expected.source;
          const proof = sourceResults.find((item) => item.expected.id === expected.id);
          return !source || !actual || !proof || !['pass', 'missing', 'mismatch', 'unreadable'].includes(actual.result)
          || actual.expected !== true || typeof actual.actual !== 'boolean' || proof.actual === null
          || actual.actual !== proof.actual || (actual.result === 'pass' && proof.actual !== true)
          || (source.read_status === 'missing' && (actual.result !== 'missing' || actual.actual !== false))
          || actual.source_identity !== expected.identity || actual.commit_sha !== expected.commit_sha
          || actual.path !== expected.path || actual.git_blob_oid !== source.git_blob_oid || actual.sha256 !== source.sha256;
      });
    if (assertionFailures) return [`package_check_source_assertions_invalid:${name}`];
    if (check.result === 'pass' && actualAssertions.some((item) => item.result !== 'pass' || item.actual !== true)) {
      return [`package_check_source_assertions_invalid:${name}`];
    }
    if (check.result !== 'pass') return [`package_check_${check.result}:${name}`];
    if (![check.source_identity, check.evidence_detail, check.finding_detail].every((value) => typeof value === 'string' && value.trim())
      || !check.finding_detail.startsWith('No finding:')) return [`package_check_evidence_incomplete:${name}`];
    return [];
  });
}

export function bindPhase251PackageSourceEvidence(feasibility) {
  const ready01 = feasibility?.requirements?.READY01;
  const adopter = ready01?.package_adopter;
  if (!ready01 || !adopter?.checks || !Array.isArray(ready01.sources)) {
    throw new Error('READY-01 source records or package checks are missing.');
  }
  adopter.sources = ready01.sources;
  for (const [name, requirements] of Object.entries(phase251PackageCheckRequirements)) {
    const check = adopter.checks[name];
    if (!check || !['pass', 'missing', 'mismatch', 'unreadable'].includes(check.result)) {
      throw new Error(`READY-01 package check ${name} has no recognized result.`);
    }
    const records = requirements.map((required) => {
      const source = ready01.sources.find((item) => item.source_identity === required.identity
        && item.commit_sha === required.commit_sha && item.path === required.path);
      if (!source) throw new Error(`READY-01 ${name} source record is missing: ${required.identity}:${required.path}`);
      return { identity: required.identity, ...structuredClone(source) };
    });
    check.source_refs = records;
    check.source_assertions = requirements.flatMap((required) => required.assertions.map((id) => {
      const source = records.find((item) => item.identity === required.identity && item.commit_sha === required.commit_sha && item.path === required.path);
      const bytes = readVerifiedPackageSource(source);
      const actual = bytes ? evaluatePhase251PackageAssertion(id, bytes, source) : false;
      const assertionResult = !bytes && source.read_status === 'missing' ? 'missing' : actual ? 'pass' : 'mismatch';
      return { id, result: assertionResult, expected: true, actual,
        source_identity: required.identity, commit_sha: required.commit_sha, path: required.path,
        git_blob_oid: source.git_blob_oid, sha256: source.sha256 };
    }));
    const assertionsPass = check.source_assertions.every((assertion) => assertion.result === 'pass' && assertion.actual === true);
    check.result = assertionsPass ? 'pass' : check.source_assertions.some((assertion) => assertion.result === 'missing') ? 'missing' : 'mismatch';
  }
  return feasibility;
}

function exactHistoricalApprovalFailure(ready01) {
  const failures = [];
  const history = ready01?.approval_history;
  const owner = ready01?.historical_owner_source;
  const record = ready01?.approval_record;
  const timeWindow = ready01?.time_window;
  const sameTuple = (value) => value?.candidate_sha === phase251CandidateTuple.candidate_sha
    && value?.reviewed_base_sha === phase251CandidateTuple.reviewed_base_sha
    && value?.protected_main_sha === phase251CandidateTuple.protected_main_sha;
  const exactOwner = owner?.identity === phase251OwnerReportSource.identity
    && owner?.commit_sha === phase251OwnerReportSource.commit_sha
    && owner?.path === phase251OwnerReportSource.path
    && owner?.git_blob_oid === phase251OwnerReportSource.git_blob_oid
    && owner?.sha256 === phase251OwnerReportSource.sha256
    && owner?.read_status === 'readable'
    && typeof owner?.trust_status === 'string' && owner.trust_status.startsWith('trusted_');
  if (!exactOwner) failures.push('historical_owner_source_untrusted');
  const reviewsComplete = ready01?.history_complete === true
    && history?.complete === true
    && history?.reviews?.status === 200
    && Number.isInteger(history?.reviews?.page_count) && history.reviews.page_count > 0
    && Number.isInteger(history?.reviews?.item_count) && Array.isArray(history?.reviews?.events)
    && history.reviews.events.length === history.reviews.item_count
    && history?.timeline?.status === 200
    && Number.isInteger(history?.timeline?.page_count) && history.timeline.page_count > 0
    && Number.isInteger(history?.timeline?.item_count) && Array.isArray(history?.timeline?.interval_events)
    && /^[a-f0-9]{64}$/.test(history?.reviews?.response_sha256 ?? '')
    && /^[a-f0-9]{64}$/.test(history?.timeline?.response_sha256 ?? '');
  const exactWindow = timeWindow?.complete === true
    && timeWindow.start === phase251ApprovalWindow.start
    && timeWindow.end === phase251ApprovalWindow.end
    && history?.window?.start === phase251ApprovalWindow.start
    && history?.window?.end === phase251ApprovalWindow.end;
  if (!reviewsComplete || !exactWindow) failures.push('approval_history_incomplete');
  const eventTime = Date.parse(record?.submitted_at ?? '');
  const windowStart = Date.parse(phase251ApprovalWindow.start);
  const windowEnd = Date.parse(phase251ApprovalWindow.end);
  const review = history?.reviews?.events?.find((item) => String(item?.id) === String(record?.review_id));
  if (!record || !review || review.state !== 'APPROVED'
    || review.commit_id !== phase251CandidateTuple.candidate_sha
    || record.event !== 'APPROVED'
    || record.submitted_at !== review.submitted_at
    || !Number.isFinite(eventTime) || eventTime < windowStart || eventTime >= windowEnd
    || !exactOwner || record.owner_report_sha256 !== owner.sha256) failures.push('approval_event_not_exact_or_contemporaneous');
  if (!sameTuple(record?.candidate_tuple)) failures.push('approval_candidate_tuple_mismatch');
  const ci = record?.exact_head_ci;
  if (ci?.run_id !== phase251ExactHeadCi.run_id || ci?.attempt !== phase251ExactHeadCi.attempt
    || ci?.head_sha !== phase251ExactHeadCi.head_sha) failures.push('approval_exact_head_ci_mismatch');
  const readiness = record?.readiness_record;
  if (readiness?.path !== '.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json'
    || !/^[a-f0-9]{64}$/.test(readiness?.sha256 ?? '') || !sameTuple(readiness?.tuple)) failures.push('approval_readiness_record_mismatch');
  const dryRun = record?.dry_run_receipt;
  if (dryRun?.path !== '.planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json'
    || !/^[a-f0-9]{64}$/.test(dryRun?.sha256 ?? '') || !sameTuple(dryRun?.tuple)
    || dryRun?.authenticated !== true || dryRun?.publishing !== false) failures.push('approval_dry_run_receipt_mismatch');
  return [...new Set(failures)].sort();
}

/** Evaluate source feasibility independently from each requirement's acceptance verdict. */
export function evaluatePhase251Feasibility(feasibility) {
  const result = structuredClone(feasibility ?? {});
  result.requirements ??= {};
  const ready01 = result.requirements.READY01 ?? {};
  const ready02 = result.requirements.READY02 ?? {};
  const sourceBlockers = (name, requirement) => {
    const blockers = phase251SliceSourceBlockers(name, requirement);
    if (requirement?.source_feasibility === 'blocked' && !blockers.length) blockers.push(`${name}_preflight_source_blocked`);
    return blockers;
  };
  const blockers01 = sourceBlockers('READY01', ready01);
  const blockers02 = sourceBlockers('READY02', ready02);
  ready01.blockers = [...new Set([...(ready01.blockers ?? []), ...blockers01])].sort();
  ready02.blockers = [...new Set([...(ready02.blockers ?? []), ...blockers02])].sort();
  ready01.source_feasibility = blockers01.length ? 'blocked' : 'ready';
  ready02.source_feasibility = blockers02.length ? 'blocked' : 'ready';
  ready01.capture_allowed = ready01.source_feasibility === 'ready';
  ready02.capture_allowed = ready02.source_feasibility === 'ready';

  const findings = [];
  const tuple = ready01.candidate_tuple ?? {};
  if (tuple.candidate_sha !== phase251CandidateTuple.candidate_sha
    || tuple.reviewed_base_sha !== phase251CandidateTuple.reviewed_base_sha
    || tuple.protected_main_sha !== phase251CandidateTuple.protected_main_sha) findings.push('candidate_tuple_mismatch');
  const published = ready01.published_release_source ?? {};
  if (published.tag !== phase251PublishedSource.tag || published.tag_ref !== phase251PublishedSource.tag_ref
    || published.commit_sha !== phase251PublishedSource.commit_sha) findings.push('published_tag_identity_mismatch');
  const packageFailures = namedPackageCheckFailure(ready01.package_adopter, ready01.sources);
  findings.push(...packageFailures);
  const approvalFailures = exactHistoricalApprovalFailure(ready01);
  findings.push(...approvalFailures);
  const approvalUnavailable = ready01.approval_event !== 'found'
    || approvalFailures.includes('historical_owner_source_untrusted')
    || approvalFailures.includes('approval_history_incomplete');
  if (approvalUnavailable) findings.push('authorization_pending');
  ready01.findings = [...new Set([...(ready01.findings ?? []), ...findings])].sort();
  ready01.package_adopter ??= {};
  ready01.package_adopter.sources ??= ready01.sources;
  ready01.package_adopter.acceptance_satisfied = ready01.capture_allowed
    && tuple.candidate_sha === phase251CandidateTuple.candidate_sha
    && tuple.reviewed_base_sha === phase251CandidateTuple.reviewed_base_sha
    && tuple.protected_main_sha === phase251CandidateTuple.protected_main_sha
    && published.tag === phase251PublishedSource.tag
    && published.tag_ref === phase251PublishedSource.tag_ref
    && published.commit_sha === phase251PublishedSource.commit_sha
    && packageFailures.length === 0
    && ready01.history_complete === true
    && ready01.approval_event === 'found'
    && approvalFailures.length === 0;
  ready01.verdict = ready01.package_adopter.acceptance_satisfied ? 'satisfied'
    : (approvalUnavailable ? 'authorization_pending' : 'unsatisfied');
  ready02.verdict = ready02.capture_allowed && ready02.verdict === 'satisfied' ? 'satisfied' : 'unsatisfied';
  result.status = ready01.capture_allowed || ready02.capture_allowed ? 'ready' : 'blocked';
  result.blockers = result.status === 'blocked' ? [...new Set([...ready01.blockers, ...ready02.blockers])].sort() : [];
  result.requirements.READY01 = ready01;
  result.requirements.READY02 = ready02;
  return result;
}

export function runPhase251Capture(feasibility, captureSlice) {
  const evaluated = evaluatePhase251Feasibility(feasibility);
  if (evaluated.status === 'blocked') return { status: 'blocked', requirements: evaluated.requirements, blockers: evaluated.blockers, captured: [] };
  const captured = [];
  for (const name of ['READY01', 'READY02']) {
    const requirement = evaluated.requirements[name];
    if (!requirement.capture_allowed) continue;
    captured.push(captureSlice(name, requirement));
  }
  return { status: 'ready', requirements: evaluated.requirements, captured };
}

function verifyPhase251PreflightBinding(feasibility) {
  const blockers = [];
  if (feasibility?.status !== 'ready') blockers.push('preflight_top_level_not_ready');
  const sourceHead = feasibility?.active_checkout?.head;
  if (!/^[a-f0-9]{40}$/.test(sourceHead ?? '')
    || !safeCommand('git', ['merge-base', '--is-ancestor', sourceHead, 'HEAD']).ok) blockers.push('preflight_checkout_head_not_ancestor');
  const allowedPaths = new Set([
    '.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json',
    '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs',
    '.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs',
    '.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs',
    '.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs',
    '.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-05-task1-red-evidence.json',
    '.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-05-task2-red-evidence.json',
  ]);
  // Plan 05 runs from the root-pinned sequential base supplied by the execution
  // packet. Earlier orchestrator-owned planning commits are already in this
  // base; only commits added after that boundary are subject to the narrow file
  // allow-list below.
  const executionBase = '4f9672a7ec34ba33b1e1d6e7e7add1b8949015bf';
  if (!safeCommand('git', ['merge-base', '--is-ancestor', sourceHead, executionBase]).ok
    || !safeCommand('git', ['merge-base', '--is-ancestor', executionBase, 'HEAD']).ok) {
    blockers.push('pinned_plan05_execution_base_unavailable_or_unrelated');
  }
  const commits = safeCommand('git', ['rev-list', '--reverse', `${executionBase}..HEAD`]).stdout.split('\n').filter(Boolean);
  for (const commit of commits) {
    const paths = safeCommand('git', ['diff-tree', '--no-commit-id', '--name-only', '-r', commit]).stdout.split('\n').filter(Boolean);
    if (!paths.length || paths.some((file) => !allowedPaths.has(file))) blockers.push(`unexpected_post_preflight_commit:${commit}`);
  }
  for (const blob of feasibility?.source_blobs ?? []) {
    if (blob.read_status === 'missing') continue;
    const resolved = safeCommand('git', ['rev-parse', `${blob.commit_sha}:${blob.path}`]);
    if (!resolved.ok || resolved.stdout !== blob.git_blob_oid || !safeCommand('git', ['cat-file', '-e', `${blob.commit_sha}:${blob.path}`]).ok) {
      blockers.push(`preflight_source_blob_changed:${blob.source_identity}:${blob.path}`);
    }
  }
  return [...new Set(blockers)].sort();
}

export function normalizePaginatedPullRequests(pages) {
  const errors = [];
  if (!Array.isArray(pages) || pages.length === 0) errors.push('pages_missing');
  else if (pages.some((page) => !Array.isArray(page))) errors.push('page_not_array');
  const sourceRows = Array.isArray(pages) ? pages.flatMap((page) => Array.isArray(page) ? page : []) : [];
  const rows = sourceRows.map((row) => ({
    number: row?.number ?? null,
    head_sha: row?.head_sha ?? row?.head?.sha ?? null,
    base_sha: row?.base_sha ?? row?.base?.sha ?? null,
    base_ref: row?.base_ref ?? row?.base?.ref ?? null,
    state: row?.state ?? null,
  })).sort((a, b) => Number(a.number) - Number(b.number));
  const identities = rows.map(fullPullRequestIdentity);
  if (identities.some((identity) => !identity)) errors.push('identity_missing_or_invalid');
  const numbers = rows.map((row) => row.number);
  if (new Set(numbers).size !== numbers.length) errors.push('duplicate_pull_request_number');
  return {
    rows,
    pagination: { complete: errors.length === 0, page_count: Array.isArray(pages) ? pages.length : 0,
      per_page: 100, observed_rows: sourceRows.length, errors: [...new Set(errors)].sort() },
  };
}

export function verifyHistoricalInheritedIdentity(readiness, currentHead, root = repoRoot) {
  const source = readiness?.entry_snapshot?.source ?? {};
  const baseSha = source.merge_base_sha ?? null;
  const inheritedHeadSha = source.inherited_checkout?.head_sha ?? null;
  const baseObjectAvailable = Boolean(baseSha && safeCommand('git', ['cat-file', '-e', `${baseSha}^{commit}`], root).ok);
  const inheritedHeadObjectAvailable = Boolean(inheritedHeadSha && safeCommand('git', ['cat-file', '-e', `${inheritedHeadSha}^{commit}`], root).ok);
  const baseIsAncestor = baseObjectAvailable && inheritedHeadObjectAvailable
    && safeCommand('git', ['merge-base', '--is-ancestor', baseSha, inheritedHeadSha], root).ok;
  const inheritedHeadIsAncestor = inheritedHeadObjectAvailable && Boolean(currentHead)
    && safeCommand('git', ['merge-base', '--is-ancestor', inheritedHeadSha, currentHead], root).ok;
  const blockers = [];
  if (!baseObjectAvailable || !inheritedHeadObjectAvailable) blockers.push('local_inherited_commit_base_unavailable');
  if (baseObjectAvailable && inheritedHeadObjectAvailable && !baseIsAncestor) blockers.push('recorded_inherited_base_relationship_invalid');
  if (inheritedHeadObjectAvailable && currentHead && !inheritedHeadIsAncestor) blockers.push('recorded_inherited_head_not_ancestor_of_current');
  return { source_path: '.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json#entry_snapshot.source',
    base_sha: baseSha, inherited_head_sha: inheritedHeadSha, current_head_sha: currentHead,
    base_object_available: baseObjectAvailable, inherited_head_object_available: inheritedHeadObjectAvailable,
    base_is_ancestor_of_inherited_head: baseIsAncestor, inherited_head_is_ancestor_of_current: inheritedHeadIsAncestor,
    recovery: baseObjectAvailable && inheritedHeadObjectAvailable ? 'read-back from local Git object database' : 'object unavailable', blockers };
}

function readOnlyPullRequestDetails(pullRequests) {
  return pullRequests.map((row) => {
    const pullRequest = ghJson(`repos/szTheory/sigra/pulls/${row.number}`);
    const filePages = ghJsonPaginated(`repos/szTheory/sigra/pulls/${row.number}/files?per_page=100`);
    const files = filePages.rows.map((file) => ({ filename: file.filename ?? null, status: file.status ?? null,
      additions: Number.isInteger(file.additions) ? file.additions : null,
      deletions: Number.isInteger(file.deletions) ? file.deletions : null,
      patch_sha256: typeof file.patch === 'string' ? sha256(file.patch) : null }));
    const complete = filePages.pages.length > 0 && filePages.pages.every(Array.isArray)
      && files.every((file) => typeof file.filename === 'string' && file.filename.length > 0)
      && new Set(files.map((file) => file.filename)).size === files.length
      && fullPullRequestIdentity({ number: pullRequest.number, head_sha: pullRequest.head?.sha,
        base_sha: pullRequest.base?.sha, base_ref: pullRequest.base?.ref }) === fullPullRequestIdentity(row);
    return { ...row, title: pullRequest.title ?? null, url: pullRequest.html_url ?? null,
      draft: pullRequest.draft ?? null, file_pagination: { complete, page_count: filePages.pages.length,
        per_page: 100, observed_rows: files.length }, files: files.sort((a, b) => a.filename.localeCompare(b.filename)) };
  }).sort((a, b) => a.number - b.number);
}

function readOnlyLiveSnapshot({ includePullRequestDetails = true } = {}) {
  const pageResult = ghJsonPaginated('repos/szTheory/sigra/pulls?state=open&per_page=100');
  const normalized = normalizePaginatedPullRequests(pageResult.pages);
  const main = ghJson('repos/szTheory/sigra/commits/main');
  const snapshot = {
    captured_at: new Date().toISOString(),
    open_pull_requests: normalized.rows,
    pagination: normalized.pagination,
    main: { sha: main.sha ?? null, tree_sha: main.commit?.tree?.sha ?? null },
  };
  if (includePullRequestDetails) snapshot.pull_request_details = readOnlyPullRequestDetails(normalized.rows);
  return snapshot;
}

function statusEntries(statusBytes, worktreePath, headSha) {
  const entries = [];
  const parts = Buffer.from(statusBytes).toString('utf8').split('\0');
  for (let index = 0; index < parts.length; index += 1) {
    const record = parts[index];
    if (!record) continue;
    const status = record.slice(0, 2);
    const relativePath = record.slice(3);
    const originalPath = status.includes('R') || status.includes('C') ? (parts[index + 1] ?? null) : null;
    if (originalPath !== null) index += 1;
    const absolutePath = path.resolve(worktreePath, relativePath);
    let sourceBytes = null;
    try {
      sourceBytes = readFileSync(absolutePath);
    } catch {
      if (headSha && status.includes('D')) {
        const prior = safeCommandBytes('git', ['show', `${headSha}:${relativePath}`], worktreePath);
        if (prior.ok) sourceBytes = prior.stdout;
      }
    }
    entries.push({ status, path: relativePath, original_path: originalPath, source_byte_readable: sourceBytes !== null,
      source_byte_sha256: sourceBytes === null ? null : sha256(sourceBytes) });
  }
  return entries.sort((a, b) => a.path.localeCompare(b.path) || a.status.localeCompare(b.status));
}

export function localInheritedSnapshot(baseSha = null, root = repoRoot) {
  const repoRootResult = safeCommand('git', ['rev-parse', '--show-toplevel'], root);
  const actualRoot = repoRootResult.stdout;
  const head = safeCommand('git', ['rev-parse', 'HEAD'], root).stdout;
  const branch = safeCommand('git', ['branch', '--show-current'], root).stdout;
  const statusResult = safeCommandBytes('git', ['status', '--porcelain=v1', '--untracked-files=all', '-z'], root);
  const statusBytes = statusResult.stdout.toString('utf8');
  const rawStatus = statusEntries(statusResult.stdout, actualRoot || root, head);
  const worktreeResult = safeCommand('git', ['worktree', 'list', '--porcelain'], root);
  const worktreeText = worktreeResult.stdout;
  const worktrees = worktreeText.split(/\n\n/).filter(Boolean).map((block) => {
    const lines = block.split('\n');
    const worktreePath = lines.find((line) => line.startsWith('worktree '))?.slice(9) ?? null;
    const worktreeHead = lines.find((line) => line.startsWith('HEAD '))?.slice(5) ?? null;
    const worktreeBranch = lines.find((line) => line.startsWith('branch '))?.slice(7) ?? null;
    const status = worktreePath ? safeCommandBytes('git', ['status', '--porcelain=v1', '--untracked-files=all', '-z'], worktreePath) : { ok: false, stdout: Buffer.alloc(0) };
    const statusText = status.stdout.toString('utf8');
    const entries = worktreePath ? statusEntries(status.stdout, worktreePath, worktreeHead) : [];
    return { path: worktreePath, head_sha: worktreeHead, branch: worktreeBranch, status_readable: status.ok,
      status_bytes: statusText, status_sha256: sha256(status.stdout), status_entries: entries,
      status_entries_readable: entries.every((entry) => entry.source_byte_readable) };
  }).sort((a, b) => String(a.path).localeCompare(String(b.path)));
  const baseAvailable = Boolean(baseSha && safeCommand('git', ['cat-file', '-e', `${baseSha}^{commit}`], root).ok);
  const commits = baseAvailable ? safeCommand('git', ['rev-list', `${baseSha}..${head}`], root).stdout.split('\n').filter(Boolean) : [];
  const commitPaths = baseAvailable
    ? [...new Set(safeCommand('git', ['log', '--no-renames', '--format=', '--name-only', `${baseSha}..${head}`], root).stdout.split('\n').filter(Boolean))].sort()
    : [];
  const inheritedDirtyEntries = worktrees.flatMap((worktree) => worktree.status_entries.map((entry) => ({
    id: `dirty:${worktree.path}:${worktree.head_sha}:${entry.status}:${entry.path}:${entry.source_byte_sha256 ?? 'unreadable'}`,
    kind: 'dirty_path', worktree_path: worktree.path, worktree_head_sha: worktree.head_sha,
    worktree_branch: worktree.branch, status: entry.status, path: entry.path, original_path: entry.original_path,
    source_byte_readable: entry.source_byte_readable, source_byte_sha256: entry.source_byte_sha256,
  })));
  return { repository_root: actualRoot, head_sha: head, branch, base_sha: baseSha,
    inventory_complete: baseAvailable && statusResult.ok && worktreeResult.ok && worktrees.every((row) => row.status_readable && row.status_entries_readable),
    raw_status: rawStatus, raw_status_sha256: sha256(statusBytes), worktrees,
    inherited_commit_shas: commits.sort(), inherited_paths: commitPaths, inherited_dirty_entries: inheritedDirtyEntries };
}

function inheritedWorkItems(local) {
  return [
    ...local.inherited_commit_shas.map((sha) => ({ id: `commit:${sha}`, kind: 'commit', commit_sha: sha })),
    ...local.inherited_paths.map((itemPath) => ({ id: `path:${itemPath}`, kind: 'committed_path', path: itemPath, source_commit_sha: local.head_sha })),
    ...(local.inherited_dirty_entries ?? []),
  ];
}

export function buildPhase251Packet(feasibility, evaluated, before, after, local, blockers, { root = local.repository_root ?? repoRoot } = {}) {
  const ready01 = evaluated.requirements.READY01;
  const ready02 = evaluated.requirements.READY02;
  const beforeIds = (before?.open_pull_requests ?? []).map(fullPullRequestIdentity);
  const afterIds = (after?.open_pull_requests ?? []).map(fullPullRequestIdentity);
  const validSnapshot = (snapshot) => Boolean(snapshot?.pagination?.complete === true
    && Number.isInteger(snapshot.pagination.page_count) && snapshot.pagination.page_count > 0
    && snapshot.pagination.observed_rows === snapshot.open_pull_requests?.length);
  const prStable = Boolean(validSnapshot(before) && validSnapshot(after)
    && beforeIds.every(Boolean) && afterIds.every(Boolean)
    && new Set(before?.open_pull_requests?.map((row) => row.number)).size === before?.open_pull_requests?.length
    && new Set(after?.open_pull_requests?.map((row) => row.number)).size === after?.open_pull_requests?.length
    && JSON.stringify([...beforeIds].sort()) === JSON.stringify([...afterIds].sort()));
  const mainStable = Boolean(before?.main?.sha && before.main.sha === after?.main?.sha);
  const prJoin = joinPopulation({ observedIds: afterIds.filter(Boolean), dispositions: after?.dispositions ?? [], label: 'open_pr', root });
  const inheritedItems = inheritedWorkItems(local);
  const inheritedJoin = joinPopulation({ observedIds: inheritedItems, dispositions: local.inherited_dispositions ?? [], label: 'inherited_work', root });
  const ready02Satisfied = ready02.capture_allowed && prStable && mainStable && prJoin.status === 'passed'
    && inheritedJoin.status === 'passed' && local.inventory_complete && local.worktrees.every((row) => row.status_readable);
  const ready01Satisfied = Boolean(ready01.package_adopter?.acceptance_satisfied);
  ready01.verdict = ready01Satisfied ? 'satisfied' : (ready01.approval_event !== 'found' ? 'authorization_pending' : 'unsatisfied');
  ready02.verdict = ready02Satisfied ? 'satisfied' : 'unsatisfied';
  const capturedAt = new Date().toISOString();
  const feasibilitySha = sha256(readFileSync(phase251FeasibilityPath));
  const captureId = `phase251-${sha256(`${capturedAt}:${feasibilitySha}:${before?.main?.sha ?? ''}:${after?.main?.sha ?? ''}:${local.head_sha ?? ''}:${local.raw_status_sha256 ?? ''}`).slice(0, 20)}`;
  return {
    schema_version: 1,
    phase: 251,
    owner_phase: 247,
    repository: 'szTheory/sigra',
    captured_at: capturedAt,
    capture_id: captureId,
    source_feasibility: { path: path.relative(repoRoot, phase251FeasibilityPath), sha256: feasibilitySha },
    source_capture: { before, after, stable_open_pr_identity: prStable, stable_main_identity: mainStable, local_inherited_work: local },
    candidate_tuple: ready01.candidate_tuple ?? phase251CandidateTuple,
    published_release_source: ready01.published_release_source ?? phase251PublishedSource,
    package_adopter: ready01.package_adopter ?? null,
    requirement_verdicts: { 'READY-01': ready01.verdict, 'READY-02': ready02.verdict },
    requirements: {
      READY01: { source_feasibility: ready01.source_feasibility, capture_allowed: ready01.capture_allowed,
        verdict: ready01.verdict, blockers: ready01.blockers, findings: ready01.findings ?? [],
        history_complete: ready01.history_complete, time_window: ready01.time_window ?? null,
        historical_owner_source: ready01.historical_owner_source ?? null,
        approval_history: ready01.approval_history ?? null, approval_record: ready01.approval_record ?? null,
        package_adopter: ready01.package_adopter ?? null },
      READY02: { source_feasibility: ready02.source_feasibility, capture_allowed: ready02.capture_allowed,
        verdict: ready02.verdict, blockers: [...ready02.blockers, ...blockers,
          ...(prStable ? [] : ['open_pr_population_changed_or_incomplete']),
          ...(mainStable ? [] : ['protected_main_changed_or_unavailable']),
          ...(prJoin.status === 'passed' ? [] : prJoin.blockers),
          ...(inheritedJoin.status === 'passed' ? [] : inheritedJoin.blockers)], findings: ready02.findings ?? [],
        open_pr_population: { before_count: before?.open_pull_requests?.length ?? null, after_count: after?.open_pull_requests?.length ?? null,
          before: before?.open_pull_requests ?? null, after: after?.open_pull_requests ?? null, stable: prStable,
          complete: Boolean(before?.pagination?.complete && after?.pagination?.complete), disposition_join: prJoin },
        inherited_work: { commit_count: local.inherited_commit_shas.length, path_count: local.inherited_paths.length,
          raw_status: local.raw_status, worktrees: local.worktrees, disposition_join: inheritedJoin } },
    },
    blockers: [...blockers, ...(prStable ? [] : ['open_pr_population_changed_or_incomplete']),
      ...(mainStable ? [] : ['protected_main_changed_or_unavailable']),
      ...(prJoin.status === 'passed' ? [] : prJoin.blockers), ...(inheritedJoin.status === 'passed' ? [] : inheritedJoin.blockers)],
  };
}

export function buildPhase251Summary(packet) {
  const digest = sha256(`${JSON.stringify(packet, null, 2)}\n`);
  const r1 = packet.requirements.READY01;
  const r2 = packet.requirements.READY02;
  return `# Phase 251 Evidence Summary\n\n- **Packet:** \`.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-247-RECONCILIATION.json\`\n- **Packet capture ID:** \`${packet.capture_id}\`\n- **Packet SHA-256:** \`${digest}\`\n- **Captured at:** ${packet.captured_at}\n- **Candidate tuple:** \`${packet.candidate_tuple.candidate_sha}\` / \`${packet.candidate_tuple.reviewed_base_sha}\` / \`${packet.candidate_tuple.protected_main_sha}\`\n- **Published release:** \`${packet.published_release_source.tag}\` → \`${packet.published_release_source.commit_sha}\`\n\n| Requirement | Verdict | Source ready | Capture allowed |\n|---|---|---|---|\n| READY-01 | ${r1.verdict} | ${r1.source_feasibility} | ${r1.capture_allowed} |\n| READY-02 | ${r2.verdict} | ${r2.source_feasibility} | ${r2.capture_allowed} |\n\n## Findings\n\n${[...r1.findings, ...r1.blockers, ...r2.findings, ...r2.blockers, ...packet.blockers].map((item) => `- ${item}`).join('\n') || '- None recorded.'}\n`;
}

export function buildPhase251OwnerReport(packet) {
  const digest = sha256(`${JSON.stringify(packet, null, 2)}\n`);
  const r1 = packet.requirements.READY01;
  const r2 = packet.requirements.READY02;
  return `# Phase 247 Release Readiness Verification\n\n<!-- phase-251-reconciliation: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-247-RECONCILIATION.json -->\n<!-- phase-251-capture-id: ${packet.capture_id} -->\n<!-- phase-251-reconciliation-sha256: ${digest} -->\n\nThis owner report records fresh Phase 251 evidence. Phase 247 remains the owner of READY-01 and READY-02.\n\n- **Captured at:** ${packet.captured_at}\n- **Candidate tuple:** \`${packet.candidate_tuple.candidate_sha}\` / \`${packet.candidate_tuple.reviewed_base_sha}\` / \`${packet.candidate_tuple.protected_main_sha}\`\n- **Published release source:** \`${packet.published_release_source.tag}\` at \`${packet.published_release_source.commit_sha}\`\n\n| Requirement | Verdict | Evidence status |\n|---|---|---|\n| READY-01 | ${r1.verdict} | ${[...r1.blockers, ...r1.findings].join('; ') || 'complete source-bound approval and package evidence'} |\n| READY-02 | ${r2.verdict} | ${[...r2.blockers, ...r2.findings].join('; ') || 'complete live inventory and preservation joins'} |\n\nThe linked packet contains the source identities, captured populations, and blockers. This report does not promote missing or untrusted evidence to a pass.\n`;
}

function verifyCaptureOutputsBeforeRewrite(paths, capturedLocal, localRecords, preservation, root) {
  const current = localInheritedSnapshot(capturedLocal.base_sha, root);
  if (current.head_sha !== capturedLocal.head_sha || current.raw_status_sha256 !== capturedLocal.raw_status_sha256) {
    throw new Error('Source checkout changed after READY-02 inventory capture; refusing to replace evidence outputs.');
  }
  const itemsById = new Map(localRecords.map((record) => [record.id, record]));
  const dirtyItems = inheritedWorkItems(capturedLocal).filter((item) => item.kind === 'dirty_path'
    && item.worktree_path === capturedLocal.repository_root);
  for (const outputPath of paths) {
    const dirtyItem = dirtyItems.find((item) => item.path === outputPath);
    if (!dirtyItem) continue;
    const record = itemsById.get(dirtyItem.id);
    const reference = preservation.references.get(dirtyItem.id);
    if (!record || !validPreservationReference(reference, dirtyItem.id, record.decision, root, dirtyItem.source_byte_sha256)) {
      throw new Error(`Dirty evidence output ${outputPath} lacks a verified scoped preservation record.`);
    }
    const currentSha = sha256(readFileSync(path.resolve(root, outputPath)));
    if (currentSha !== dirtyItem.source_byte_sha256) throw new Error(`Evidence output ${outputPath} changed after preservation read-back.`);
  }
}

export function prDisposition(detail) {
  const filenames = (detail?.files ?? []).map((file) => file.filename).filter(Boolean);
  const releasePaths = filenames.filter((filename) => /^(mix\.exs|\.release-please-manifest\.json|release-please-config\.json|CHANGELOG\.md|README\.md|lib\/|priv\/templates\/|guides\/introduction\/upgrading-to-v1\.6\.md)$/.test(filename));
  const releaseWorkflowPaths = filenames.filter((filename) => /^\.github\/workflows\/(hex-publish|release-please)\.yml$/.test(filename));
  if (releasePaths.length || releaseWorkflowPaths.length) {
    const reviewed = [...releasePaths, ...releaseWorkflowPaths].sort();
    return { decision: 'release-relevant', reason: `Current diff touches release source or release workflow paths (${reviewed.join(', ')}); retain for separate source review before any candidate decision.` };
  }
  if ((detail?.title ?? '').toLowerCase().includes('phase 244 evidence')) {
    return { decision: 'separate-follow-up', reason: `Draft Phase 244 evidence PR #${detail.number} is an independent historical measurement change with ${filenames.length} current diff paths; it remains outside the exact release candidate.` };
  }
  return { decision: 'separate-follow-up', reason: `Current PR #${detail.number} changes ${filenames.length} files outside the package and release workflow source set; retain it as independent follow-up work.` };
}

function preservationRecordForItem(item, decision, reason, source, detail = {}) {
  return { id: item.id, kind: item.kind, decision, reason, source,
    source_byte_sha256: item.source_byte_sha256 ?? null, captured_source: item, detail };
}

function exactDirtyBytes(item) {
  if (item.kind !== 'dirty_path') return null;
  try { return readFileSync(path.resolve(item.worktree_path, item.path)); }
  catch {
    if (item.status?.includes('D')) {
      const prior = safeCommandBytes('git', ['show', `${item.worktree_head_sha}:${item.path}`], item.worktree_path);
      if (prior.ok) return prior.stdout;
    }
    return null;
  }
}

export function createScopedPreservationRef(records, captureHead, root) {
  const tempRoot = mkdtempSync(path.join(tmpdir(), 'phase251-preservation-'));
  const recordsDir = path.join(tempRoot, 'records');
  mkdirSync(recordsDir, { recursive: true });
  const recordRows = records.map((record) => {
    const filename = `${sha256(record.id).slice(0, 40)}.json`;
    const recordPath = `records/${filename}`;
    const bytes = Buffer.from(`${JSON.stringify(record, null, 2)}\n`);
    if (record.source_bytes_base64) {
      const sourceBytes = Buffer.from(record.source_bytes_base64, 'base64');
      if (!record.source_byte_sha256 || sha256(sourceBytes) !== record.source_byte_sha256) {
        throw new Error(`Captured source bytes do not match their digest for ${record.id}.`);
      }
    }
    writeFileSync(path.join(recordsDir, filename), bytes);
    return { id: record.id, decision: record.decision, record_path: recordPath,
      record_sha256: sha256(bytes), source_byte_sha256: record.captured_source?.source_byte_sha256 ?? null, bytes };
  });
  const indexPath = path.join(tempRoot, 'index');
  const gitDir = safeCommand('git', ['rev-parse', '--absolute-git-dir'], root).stdout;
  if (!gitDir) throw new Error('Cannot resolve Git metadata for scoped preservation ref.');
  const env = { ...process.env, GIT_INDEX_FILE: indexPath };
  try {
    execFileSync('git', ['--git-dir', gitDir, 'read-tree', captureHead], { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
    execFileSync('git', ['--git-dir', gitDir, '--work-tree', tempRoot, 'add', '-A', '--', 'records'], { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
    const tree = execFileSync('git', ['--git-dir', gitDir, 'write-tree'], { cwd: root, env, encoding: 'utf8' }).trim();
    const commitSha = execFileSync('git', ['--git-dir', gitDir, 'commit-tree', tree, '-p', captureHead,
      '-m', 'preserve Phase 251 READY-02 inventory records'], { cwd: root, encoding: 'utf8' }).trim();
    const scope = sha256(`${captureHead}:${recordRows.map((row) => row.id).join('\n')}`).slice(0, 12);
    const ref = `refs/heads/phase251-preservation/${new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14)}-${scope}`;
    execFileSync('git', ['--git-dir', gitDir, 'update-ref', ref, commitSha], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
    const references = new Map();
    for (const row of recordRows) {
      const readback = execFileSync('git', ['--git-dir', gitDir, 'show', `${ref}:${row.record_path}`], { cwd: root, encoding: 'buffer', maxBuffer: 32 * 1024 * 1024 });
      if (sha256(readback) !== row.record_sha256) throw new Error(`Preservation read-back hash mismatch for ${row.id}.`);
      const parsed = JSON.parse(readback.toString('utf8'));
      if (parsed.id !== row.id || parsed.decision !== row.decision
        || (row.source_byte_sha256 && parsed.captured_source?.source_byte_sha256 !== row.source_byte_sha256)) {
        throw new Error(`Preservation read-back identity mismatch for ${row.id}.`);
      }
      references.set(row.id, { ref, commit_sha: commitSha, record_path: row.record_path,
        record_sha256: row.record_sha256, ...(row.source_byte_sha256 ? { source_byte_sha256: row.source_byte_sha256 } : {}) });
    }
    return { ref, commit_sha: commitSha, capture_head: captureHead, records: recordRows.length,
      readback_verified: references.size === recordRows.length, references };
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
}

export function checkPhase251Artifacts(packet, summary, ownerReport) {
  const bytes = `${JSON.stringify(packet, null, 2)}\n`;
  const digest = sha256(bytes);
  const summaryCaptureIds = [...summary.matchAll(/\*\*Packet capture ID:\*\* `([^`]+)`/g)].map((match) => match[1]);
  const ownerCaptureIds = [...ownerReport.matchAll(/<!-- phase-251-capture-id: ([^ ]+) -->/g)].map((match) => match[1]);
  const captureId = packet.capture_id;
  const captureIdMatches = /^[a-z0-9-]+$/.test(captureId ?? '')
    && summaryCaptureIds.length === 1 && ownerCaptureIds.length === 1
    && summaryCaptureIds[0] === captureId && ownerCaptureIds[0] === captureId;
  return {
    valid: captureIdMatches
      && summary.includes(`Packet SHA-256:** \`${digest}\``)
      && ownerReport.includes(`phase-251-reconciliation-sha256: ${digest}`)
      && packet.requirement_verdicts?.['READY-01'] === packet.requirements?.READY01?.verdict
      && packet.requirement_verdicts?.['READY-02'] === packet.requirements?.READY02?.verdict
      && packet.candidate_tuple?.candidate_sha !== packet.published_release_source?.commit_sha,
    packet_sha256: digest,
    capture_id: captureId ?? null,
    capture_id_matches: captureIdMatches,
    verdicts_match: packet.requirement_verdicts?.['READY-01'] === packet.requirements?.READY01?.verdict
      && packet.requirement_verdicts?.['READY-02'] === packet.requirements?.READY02?.verdict,
  };
}

function writePhase251Capture() {
  const feasibility = readJson(phase251FeasibilityPath);
  const bindingBlockers = verifyPhase251PreflightBinding(feasibility);
  const gated = runPhase251Capture(feasibility, (name) => name);
  if (gated.status === 'blocked') {
    process.stdout.write(`${JSON.stringify({ status: 'blocked', blockers: [...bindingBlockers, ...(gated.blockers ?? [])], outputs_written: [] }, null, 2)}\n`);
    process.exitCode = 1;
    return;
  }
  if (bindingBlockers.length) throw new Error(`Preflight source binding failed: ${bindingBlockers.join(', ')}`);
  const rate = ghJson('rate_limit');
  const remaining = rate?.resources?.core?.remaining;
  let liveBefore = null;
  let liveAfter = null;
  const captureBlockers = [];
  let liveCaptureFailure = null;
  if (!Number.isInteger(remaining) || remaining <= 250) {
    captureBlockers.push('github_core_rate_limit_at_or_below_250');
  } else if (gated.captured.includes('READY02')) {
    try { liveBefore = readOnlyLiveSnapshot(); }
    catch (error) {
      liveCaptureFailure = error.message;
      captureBlockers.push('github_live_population_unavailable');
    }
  }
  const readinessLedger = readJson(readinessPath);
  const checkoutHead = safeCommand('git', ['rev-parse', 'HEAD']).stdout;
  const historicalIdentity = verifyHistoricalInheritedIdentity(readinessLedger, checkoutHead);
  const local = localInheritedSnapshot(historicalIdentity.base_sha);
  local.historical_identity = historicalIdentity;
  captureBlockers.push(...historicalIdentity.blockers);
  if (!local.inventory_complete) captureBlockers.push('local_inherited_commit_base_unavailable');
  const localItems = inheritedWorkItems(local);
  const localRecords = localItems.map((item) => {
    let decision = 'separate-follow-up';
    let reason = 'This exact inherited item is preserved as independent work outside the candidate tuple.';
    const sourcePaths = item.kind === 'committed_path' ? [item.path]
      : item.kind === 'commit' ? safeCommand('git', ['diff-tree', '--no-commit-id', '--name-only', '-r', item.commit_sha]).stdout.split('\n').filter(Boolean)
        : [item.path];
    const releasePaths = sourcePaths.filter((itemPath) => /^(mix\.exs|\.release-please-manifest\.json|release-please-config\.json|CHANGELOG\.md|README\.md|lib\/|priv\/templates\/|guides\/introduction\/upgrading-to-v1\.6\.md|\.github\/workflows\/(hex-publish|release-please)\.yml$)/.test(itemPath));
    if (releasePaths.length) {
      decision = 'release-relevant';
      reason = `Inherited source touches release/package paths (${releasePaths.sort().join(', ')}); retain for source review before any candidate decision.`;
    }
    if (item.kind === 'dirty_path' && !item.source_byte_readable) {
      decision = 'release-blocking';
      reason = `Dirty worktree path ${item.worktree_path}:${item.path} could not be read and hashed exactly; READY-02 remains blocked.`;
    }
    const record = preservationRecordForItem(item, decision, reason,
      item.kind === 'commit' ? { commit_sha: item.commit_sha }
        : item.kind === 'committed_path' ? { commit_sha: item.source_commit_sha, path: item.path }
          : { worktree_path: item.worktree_path, head_sha: item.worktree_head_sha, status: item.status, path: item.path },
      { source_paths: sourcePaths });
    const dirtyBytes = exactDirtyBytes(item);
    if (dirtyBytes) record.source_bytes_base64 = dirtyBytes.toString('base64');
    if (item.kind === 'dirty_path' && item.status.includes('D')) {
      if (!dirtyBytes || !item.source_byte_readable) throw new Error(`Deleted inherited path lacks captured preimage bytes: ${item.id}`);
      record.source_absence_proof = { kind: 'worktree-deletion-tombstone', worktree_path: item.worktree_path,
        head_sha: item.worktree_head_sha, status: item.status, path: item.path, source_byte_sha256: sha256(dirtyBytes) };
    }
    return record;
  });
  let localPreservation = { records: 0, readback_verified: false, references: new Map() };
  try {
    localPreservation = createScopedPreservationRef(localRecords, local.head_sha, repoRoot);
    local.inherited_dispositions = localRecords.map((record) => ({ id: record.id, decision: record.decision,
      reason: record.reason, source: record.source, preservation_ref: localPreservation.references.get(record.id) }));
  } catch (error) {
    captureBlockers.push(`inherited_preservation_ref_failed:${error.message}`);
    local.inherited_dispositions = [];
  }
  local.preservation = { ref: localPreservation.ref ?? null, commit_sha: localPreservation.commit_sha ?? null,
    record_count: localPreservation.records ?? 0, readback_verified: localPreservation.readback_verified ?? false };
  const prDetails = liveBefore?.pull_request_details ?? [];
  const detailComplete = liveBefore?.open_pull_requests?.length === prDetails.length
    && prDetails.every((detail) => detail.file_pagination?.complete === true
      && fullPullRequestIdentity(detail) && fullPullRequestIdentity(detail) === fullPullRequestIdentity(liveBefore.open_pull_requests.find((row) => row.number === detail.number)));
  const prRecords = detailComplete ? prDetails.map((detail) => {
    const identity = fullPullRequestIdentity(detail);
    const item = { id: identity, kind: 'pull_request', identity, number: detail.number };
    const disposition = prDisposition(detail);
    return preservationRecordForItem(item, disposition.decision, disposition.reason, { pull_request_identity: identity },
      { title: detail.title, url: detail.url, draft: detail.draft, file_pagination: detail.file_pagination, files: detail.files });
  }) : [];
  let prPreservation = { records: 0, readback_verified: false, references: new Map() };
  try {
    if (prRecords.length) prPreservation = createScopedPreservationRef(prRecords, checkoutHead, repoRoot);
    liveBefore.dispositions = prRecords.map((record) => ({ id: record.id, decision: record.decision,
      reason: record.reason, source: record.source, preservation_ref: prPreservation.references.get(record.id) }));
  } catch (error) {
    captureBlockers.push(`open_pr_preservation_ref_failed:${error.message}`);
    if (liveBefore) liveBefore.dispositions = [];
  }
  if (!detailComplete) captureBlockers.push('open_pr_diff_details_missing_or_incomplete');
  if (liveBefore) liveBefore.preservation = { ref: prPreservation.ref ?? null, commit_sha: prPreservation.commit_sha ?? null,
    record_count: prPreservation.records ?? 0, readback_verified: prPreservation.readback_verified ?? false };
  const localAfter = localInheritedSnapshot(historicalIdentity.base_sha);
  const localStable = local.raw_status_sha256 === localAfter.raw_status_sha256
    && local.head_sha === localAfter.head_sha
    && JSON.stringify(inheritedWorkItems(local).map((item) => item.id).sort()) === JSON.stringify(inheritedWorkItems(localAfter).map((item) => item.id).sort());
  local.stable_during_capture = localStable;
  if (!localStable) captureBlockers.push('inherited_work_population_changed_during_capture');
  if (liveBefore && !liveCaptureFailure) {
    try {
      liveAfter = readOnlyLiveSnapshot({ includePullRequestDetails: false });
      if (liveBefore.dispositions) liveAfter.dispositions = liveBefore.dispositions;
      if (liveBefore.preservation) liveAfter.preservation = liveBefore.preservation;
    } catch (error) {
      liveCaptureFailure = error.message;
      captureBlockers.push('github_live_population_recheck_unavailable');
    }
    if (liveAfter && (!liveBefore.pagination.complete || !liveAfter.pagination.complete)) captureBlockers.push('open_pr_pagination_incomplete');
  }
  const packet = buildPhase251Packet(feasibility, { requirements: gated.requirements }, liveBefore, liveAfter, local, captureBlockers);
  packet.source_capture.local_population_stable_during_capture = localStable;
  packet.source_capture.preservation = { local: local.preservation, open_pull_requests: liveBefore?.preservation ?? null };
  if (liveCaptureFailure) packet.source_capture.failure = { message: liveCaptureFailure };
  const jsonBytes = `${JSON.stringify(packet, null, 2)}\n`;
  const summary = buildPhase251Summary(packet);
  const report = buildPhase251OwnerReport(packet);
  verifyCaptureOutputsBeforeRewrite([phase251ReconciliationPath, phase251SummaryPath, reportPath].map((file) => path.relative(repoRoot, file)),
    local, localRecords, localPreservation, repoRoot);
  writeFileSync(phase251ReconciliationPath, jsonBytes);
  writeFileSync(phase251SummaryPath, summary);
  writeFileSync(reportPath, report);
  process.stdout.write(`${JSON.stringify({ status: packet.requirements.READY02.verdict === 'satisfied' ? 'passed' : 'gaps_found',
    reconciliation: path.relative(repoRoot, phase251ReconciliationPath), summary: path.relative(repoRoot, phase251SummaryPath), owner_report: path.relative(repoRoot, reportPath),
    requirement_verdicts: packet.requirement_verdicts, blockers: packet.blockers }, null, 2)}\n`);
}

function checkPhase251Files() {
  const packet = readJson(phase251ReconciliationPath);
  const result = checkPhase251Artifacts(packet, readFileSync(phase251SummaryPath, 'utf8'), readFileSync(reportPath, 'utf8'));
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.valid) process.exitCode = 1;
}

export function resolveExactHeadCiIdentity(proposal, readiness) {
  const saved = readiness?.candidate?.review_check_state?.updated_head_ci ?? {};
  return {
    run_id: proposal?.ci?.run_id ?? saved.run_id ?? null,
    attempt: proposal?.ci?.attempt ?? saved.attempt ?? null,
    head_sha: proposal?.ci?.head_sha ?? saved.head_sha ?? proposal?.candidate_sha ?? null,
  };
}

function orderedUnique(values) {
  return [...new Set(values)].sort((a, b) => a.localeCompare(b));
}

export function joinPopulation({ observedIds, dispositions, label, root = repoRoot }) {
  const blockers = [];
  if (!Array.isArray(observedIds) || !Array.isArray(dispositions)) {
    return { status: 'blocked', observedIds: [], dispositionIds: [], preservationRefs: [], blockers: [`${label}_population_or_dispositions_missing`] };
  }
  const identity = (value) => value && typeof value === 'object'
    ? value.id ?? [value.repository ?? '', value.number, value.head_sha ?? value.headSha, value.base_sha ?? value.baseSha, value.base_ref ?? value.baseRef].join(':')
    : String(value ?? '');
  const observed = orderedUnique(observedIds.map(identity));
  const dispositionIds = dispositions.map((item) => identity(item?.identity ?? item?.id));
  if (observedIds.some((id) => !identity(id)) || new Set(observedIds.map(identity)).size !== observedIds.length) blockers.push(`${label}_observed_ids_invalid`);
  if (dispositionIds.some((id) => !id) || new Set(dispositionIds).size !== dispositionIds.length) blockers.push(`${label}_disposition_ids_invalid`);
  if (JSON.stringify(orderedUnique(dispositionIds)) !== JSON.stringify(observed)) blockers.push(`${label}_population_mismatch`);
  for (const row of dispositions) {
    const rowId = identity(row?.identity ?? row?.id);
    const observedRow = observedIds.find((item) => identity(item) === rowId);
    if (!row?.decision || !validPreservationReference(row.preservation_ref, rowId, row.decision, root, observedRow?.source_byte_sha256)) blockers.push(`${label}_disposition_or_preservation_incomplete`);
  }
  const rows = [...dispositions].sort((a, b) => identity(a?.identity ?? a?.id).localeCompare(identity(b?.identity ?? b?.id)));
  return {
    status: blockers.length ? 'blocked' : 'passed',
    observedIds: observed,
    dispositionIds: rows.map((row) => identity(row.identity ?? row.id)),
    preservationRefs: rows.map((row) => ({ id: identity(row.identity ?? row.id), ref: row.preservation_ref?.ref ?? null, commitSha: row.preservation_ref?.commit_sha ?? null, recordPath: row.preservation_ref?.record_path ?? null, recordSha256: row.preservation_ref?.record_sha256 ?? null })),
    blockers: [...new Set(blockers)].sort(),
  };
}

function validPreservationReference(reference, dispositionId, decision, root, expectedSourceByteSha256) {
  if (!reference || typeof reference !== 'object'
    || !/^refs\/(?:heads|tags)\/[A-Za-z0-9._/-]+$/.test(reference.ref ?? '')
    || !/^[0-9a-f]{40}$/.test(reference.commit_sha ?? '')
    || !/^(?!\/)(?!.*(?:^|\/)\.\.(?:\/|$))[A-Za-z0-9._/-]+\.json$/.test(reference.record_path ?? '')
    || !/^[0-9a-f]{64}$/.test(reference.record_sha256 ?? '')) return false;
  try {
    const commit = execFileSync('git', ['rev-parse', '--verify', `${reference.ref}^{commit}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    if (commit !== reference.commit_sha) return false;
    const bytes = execFileSync('git', ['show', `${reference.ref}:${reference.record_path}`], { cwd: root, encoding: 'buffer', maxBuffer: 32 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] });
    if (sha256(bytes) !== reference.record_sha256) return false;
    const record = JSON.parse(bytes.toString('utf8'));
    return String(record.id) === String(dispositionId) && record.decision === decision
      && (!reference.source_byte_sha256 || record.source_byte_sha256 === reference.source_byte_sha256)
      && (!expectedSourceByteSha256 || record.source_byte_sha256 === expectedSourceByteSha256);
  } catch { return false; }
}

export function liveSnapshotStable(before, after) {
  const fullIdentities = (snapshot) => snapshot?.openPullRequestIdentities
    ? snapshot.openPullRequestIdentities.some((item) => !fullPullRequestIdentity(item))
      ? 'invalid'
      : JSON.stringify([...snapshot.openPullRequestIdentities].map(fullPullRequestIdentity).sort())
    : null;
  const beforeIdentities = fullIdentities(before);
  const afterIdentities = fullIdentities(after);
  const validPopulation = (snapshot) => {
    if (!Array.isArray(snapshot?.openPullRequestIdentities)) return true;
    return snapshot.openPullRequestPagination?.complete === true
      && Number.isInteger(snapshot.openPullRequestPagination.page_count)
      && snapshot.openPullRequestPagination.page_count > 0
      && snapshot.openPullRequestPagination.observed_rows === snapshot.openPullRequestIdentities.length
      && snapshot.openPullRequestIdentities.length === (snapshot.openPullRequestNumbers ?? []).length
      && new Set(snapshot.openPullRequestIdentities.map((row) => row?.number)).size === snapshot.openPullRequestIdentities.length;
  };
  return Boolean(before && after
    && before.pullRequest?.number === after.pullRequest?.number
    && before.pullRequest?.state === after.pullRequest?.state
    && before.pullRequest?.headSha === after.pullRequest?.headSha
    && before.pullRequest?.baseSha === after.pullRequest?.baseSha
    && before.main?.sha === after.main?.sha
    && JSON.stringify(orderedUnique((before.openPullRequestNumbers ?? []).map(String))) === JSON.stringify(orderedUnique((after.openPullRequestNumbers ?? []).map(String)))
    && beforeIdentities !== 'invalid' && afterIdentities !== 'invalid'
    && validPopulation(before) && validPopulation(after)
    && (beforeIdentities === null && afterIdentities === null || beforeIdentities !== null && beforeIdentities === afterIdentities)
    && (before.openPullRequestPagination?.complete !== false && after.openPullRequestPagination?.complete !== false));
}

export function fullPullRequestIdentity(item) {
  const number = Number(item?.number);
  const headSha = item?.head_sha ?? item?.headSha ?? item?.head?.sha;
  const baseSha = item?.base_sha ?? item?.baseSha ?? item?.base?.sha;
  const baseRef = item?.base_ref ?? item?.baseRef ?? item?.base?.ref ?? item?.base;
  if (!Number.isInteger(number) || number < 1 || !/^[a-f0-9]{40}$/.test(headSha ?? '')
    || !/^[a-f0-9]{40}$/.test(baseSha ?? '') || typeof baseRef !== 'string' || !baseRef) return null;
  return `${number}:${headSha}:${baseSha}:${baseRef}`;
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

export function evaluateEvidence({ proposal, authorization, readiness, dryRunReceipt, live, liveAfter, objects = {}, remoteSourceObjects = {}, exactHeadCiReceipt = null, authoritativeCi = null, exactHeadCiDiagnostic = null }) {
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
  const ciExpected = resolveExactHeadCiIdentity(proposal, readiness);
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
      proposalRunId: ciExpected.run_id,
      proposalAttempt: ciExpected.attempt,
      proposalHeadSha: ciExpected.head_sha,
      standaloneReceiptPath: path.relative(repoRoot, playrightPath),
      standaloneReceiptPresent: existsSync(playrightPath),
      receiptStatus: ciErrors.length ? 'blocked' : 'passed',
      authoritativeRunId: authoritativeCi?.id ?? null,
      captureDiagnostic: exactHeadCiDiagnostic,
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

function ghJsonPaginated(endpoint) {
  const pages = JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', endpoint], {
    cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 32 * 1024 * 1024,
  }));
  if (!Array.isArray(pages) || pages.some((page) => !Array.isArray(page))) throw new Error('GitHub pagination did not return complete array pages.');
  return { pages, rows: pages.flat() };
}

export function captureExactHeadCi(proposal, readiness, {
  receiptPath = playrightPath,
  exists = existsSync,
  readReceipt = readJson,
  ghJson: query = ghJson,
} = {}) {
  const expected = resolveExactHeadCiIdentity(proposal, readiness);
  if (!expected.run_id || !exists(receiptPath)) return { expected, receipt: null, authoritative: null, diagnostic: null };
  let receipt;
  try {
    receipt = readReceipt(receiptPath);
  } catch {
    return { expected, receipt: null, authoritative: null, diagnostic: 'exact_head_ci_receipt_invalid' };
  }
  try {
    const run = query(`repos/szTheory/sigra/actions/runs/${expected.run_id}`);
    const jobs = query(`repos/szTheory/sigra/actions/runs/${expected.run_id}/jobs?per_page=100`).jobs ?? [];
    const job = jobs.find((row) => row.name === 'ci-gate' && row.run_attempt === expected.attempt) ?? null;
    const authoritative = { id: run.id, run_attempt: run.run_attempt, head_sha: run.head_sha, path: run.path?.replace(/@.*$/, ''), conclusion: run.conclusion,
      job: job ? { id: job.id, name: job.name, head_sha: job.head_sha, run_attempt: job.run_attempt, conclusion: job.conclusion } : null };
    const identityMatches = authoritative.id === expected.run_id && authoritative.run_attempt === expected.attempt
      && authoritative.head_sha === expected.head_sha && authoritative.path === '.github/workflows/ci.yml';
    return { expected, receipt, authoritative: identityMatches ? authoritative : null,
      diagnostic: identityMatches ? null : 'exact_head_ci_authoritative_identity_mismatch' };
  } catch {
    return { expected, receipt, authoritative: null, diagnostic: 'exact_head_ci_authoritative_unavailable' };
  }
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
  const openPullRequestPages = ghJsonPaginated('repos/szTheory/sigra/pulls?state=open&per_page=100');
  const openPullRequests = openPullRequestPages.rows;
  const main = ghJson('repos/szTheory/sigra/commits/main');
  const head = safeCommand('git', ['rev-parse', 'HEAD']).stdout || null;
  const branch = safeCommand('git', ['branch', '--show-current']).stdout || null;
  const status = safeCommand('git', ['status', '--porcelain=v1', '--untracked-files=all']).stdout;
  return {
    pullRequest: { number: pr.number, state: pr.state, headSha: pr.head?.sha ?? null, headRef: pr.head?.ref ?? null, baseSha: pr.base?.sha ?? null, baseRef: pr.base?.ref ?? null, updatedAt: pr.updated_at ?? null },
    main: { sha: main.sha ?? null, treeSha: main.commit?.tree?.sha ?? null },
    openPullRequestNumbers: openPullRequests.map((item) => item.number).sort((a, b) => a - b),
    openPullRequestIdentities: openPullRequests.map((item) => ({
      number: item.number, head_sha: item.head?.sha ?? null, base_sha: item.base?.sha ?? null,
      base_ref: item.base?.ref ?? null, state: item.state ?? null,
    })).sort((a, b) => a.number - b.number),
    openPullRequestPagination: {
      complete: openPullRequestPages.pages.length > 0 && openPullRequestPages.pages.every(Array.isArray),
      page_count: openPullRequestPages.pages.length,
      per_page: 100,
      observed_rows: openPullRequests.length,
    },
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
  const exactHeadCi = captureExactHeadCi(proposal, readiness);
  const objectShas = [proposal.candidate_sha, proposal.candidate_ancestry?.parent_sha, readiness.final_validation?.checked?.source_sha, proposal.reviewed_base_sha, proposal.main_sha, live.main.sha, live.pullRequest.headSha].filter(Boolean);
  const localObjects = Object.fromEntries([...new Set(objectShas)].map((sha) => [sha, objectAvailable(sha)]));
  const candidateRemote = captureRemoteCommit(proposal.candidate_sha, proposal.candidate_source_audit?.candidate_source_blobs ?? {});
  const readinessRemote = captureRemoteCommit(readiness.final_validation?.checked?.source_sha, Object.fromEntries(Object.keys(proposal.candidate_source_audit?.candidate_source_blobs ?? {}).map((file) => [file, null])));
  const remoteObjects = { [candidateRemote.sha]: candidateRemote.available, [readinessRemote.sha]: readinessRemote.available };
  const objects = Object.fromEntries([...new Set(objectShas)].map((sha) => [sha, localObjects[sha] || remoteObjects[sha] === true]));
  const liveAfter = captureLive();
  const evaluation = evaluateEvidence({ proposal, authorization: auth, readiness, dryRunReceipt, live, liveAfter, objects, remoteSourceObjects: { candidate: candidateRemote, readiness: readinessRemote }, exactHeadCiReceipt: exactHeadCi.receipt, authoritativeCi: exactHeadCi.authoritative, exactHeadCiDiagnostic: exactHeadCi.diagnostic });
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
} else if (process.argv[2] === '--capture-251') {
  try { writePhase251Capture(); }
  catch (error) {
    process.stderr.write(`${JSON.stringify({ status: 'blocked', error: error.message, outputs_written: [] }, null, 2)}\n`);
    process.exitCode = 1;
  }
} else if (process.argv[2] === '--check-251') {
  try { checkPhase251Files(); }
  catch (error) {
    process.stderr.write(`${JSON.stringify({ valid: false, error: error.message }, null, 2)}\n`);
    process.exitCode = 1;
  }
}
