import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

let evaluateEvidence;
try {
  ({ evaluateEvidence } = await import('./verify-247-readiness.mjs'));
} catch {
  // Keep the RED run assertion-shaped until the planned verifier exists.
}

const tuple = {
  candidateSha: '0e773d3614a242e4fbcdd34c418ecb8a307703d6',
  reviewedBaseSha: 'd135cbce343947499a0810736c500ef5f1cb5c32',
  mainSha: 'a494f3ee3878da93aab4f70712ffddeefd77a802',
};
const ci = {
  run_id: 37800067568, run_attempt: 1, head_sha: tuple.candidateSha,
  workflow_path: '.github/workflows/ci.yml', conclusion: 'success',
  job: { id: 113389612910, name: 'ci-gate', head_sha: tuple.candidateSha, run_attempt: 1, conclusion: 'success' },
};
const authoritativeCi = { id: ci.run_id, run_attempt: 1, head_sha: tuple.candidateSha, path: '.github/workflows/ci.yml', conclusion: 'success', job: ci.job };

const blockedApprovalInput = {
  proposal: {
    authorization_status: 'pending',
    candidate_sha: tuple.candidateSha,
    reviewed_base_sha: tuple.reviewedBaseSha,
    main_sha: tuple.mainSha,
  },
  authorization: null,
  readiness: {},
  dryRunReceipt: {},
  live: {},
};

test('pending authorization cannot approve a candidate tuple', () => {
  const result = evaluateEvidence
    ? evaluateEvidence(blockedApprovalInput)
    : { status: 'implementation_missing', blockers: [] };

  assert.equal(result.status, 'blocked');
  assert.ok(result.blockers.some((blocker) => blocker.id === 'authorization_pending'));
});

test('a parent dry-run receipt cannot prove its changed child candidate', async () => {
  const { evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const input = {
    proposal: { ...blockedApprovalInput.proposal, authorization_status: 'approved' },
    authorization: { immutable: true, tuple },
    readiness: { final_validation: { checked: { source_sha: tuple.candidateSha, pr_base_sha: tuple.reviewedBaseSha, live_main_sha: tuple.mainSha } } },
    dryRunReceipt: {
      verdict: 'passed',
      dry_run_outcome: 'success',
      requested_sha: 'd76d7f2306f6099063a80a420d2d8a4e04c7785f',
      checked_out_sha: 'd76d7f2306f6099063a80a420d2d8a4e04c7785f',
      reviewed_base_sha: tuple.reviewedBaseSha,
      live_base_sha: tuple.mainSha,
      run_id: 37803817504,
      run_attempt: 1,
    },
    live: { pullRequest: { state: 'OPEN', headSha: tuple.candidateSha, baseSha: tuple.reviewedBaseSha }, main: { sha: tuple.mainSha }, openPullRequestNumbers: [], openPullRequestDispositions: [], inheritedWork: { observed: true, dispositions: [] } },
    objects: { [tuple.candidateSha]: true },
  };

  const result = evaluateEvidence(input);
  assert.equal(result.status, 'blocked');
  assert.ok(result.blockers.some((blocker) => blocker.id === 'dry_run_tuple_mismatch'));
});

test('fresh empty populations are valid only when observations and dispositions both say empty', async () => {
  const { joinPopulation } = await import('./verify-247-readiness.mjs');
  assert.deepEqual(joinPopulation({ observedIds: [], dispositions: [], label: 'pr' }), {
    status: 'passed', observedIds: [], dispositionIds: [], preservationRefs: [], blockers: [],
  });
  assert.ok(joinPopulation({ observedIds: [224], dispositions: [], label: 'pr' }).blockers.includes('pr_population_mismatch'));
});

test('duplicate dispositions and missing preservation identities fail closed', async () => {
  const { joinPopulation } = await import('./verify-247-readiness.mjs');
  const result = joinPopulation({
    observedIds: [224, 266],
    dispositions: [
      { id: 224, decision: 'retain', preservation_ref: 'refs/evidence/224', preservation_ref_recoverable: true },
      { id: 224, decision: 'retain', preservation_ref: 'refs/evidence/224-copy', preservation_ref_recoverable: true },
    ],
    label: 'pr',
  });
  assert.equal(result.status, 'blocked');
  assert.ok(result.blockers.includes('pr_disposition_ids_invalid'));
  assert.ok(result.blockers.includes('pr_population_mismatch'));
});

test('READY requirement verdicts include every blocker relevant to their predicates', async () => {
  const { evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const input = {
    proposal: { ...blockedApprovalInput.proposal, authorization_status: 'approved', stale_artifacts: [{ path: '247-CANDIDATE-DIFF-BASELINE.json', bound_candidate_sha: tuple.candidateSha }], ci: { run_id: ci.run_id, attempt: ci.run_attempt, head_sha: tuple.candidateSha } },
    authorization: { immutable: true, tuple },
    readiness: { final_validation: { checked: { source_sha: tuple.candidateSha, pr_base_sha: tuple.reviewedBaseSha, live_main_sha: tuple.mainSha } } },
    dryRunReceipt: { verdict: 'passed', dry_run_outcome: 'success', requested_sha: tuple.candidateSha, checked_out_sha: tuple.candidateSha, reviewed_base_sha: tuple.reviewedBaseSha, live_base_sha: tuple.mainSha },
    live: { pullRequest: { state: 'OPEN', headSha: tuple.candidateSha, baseSha: tuple.reviewedBaseSha }, main: { sha: tuple.mainSha }, openPullRequestNumbers: [], openPullRequestDispositions: [], inheritedWork: { observed: true, observedIds: [], dispositions: [] } },
    objects: { [tuple.candidateSha]: true, [tuple.reviewedBaseSha]: true },
    remoteSourceObjects: { candidate: { available: true, sourceBlobs: [{ path: 'mix.exs', matches: false }] } },
    exactHeadCiReceipt: ci, authoritativeCi,
  };
  const result = evaluateEvidence(input);
  assert.equal(result.blockers.some((blocker) => blocker.id === 'candidate_source_blobs_unverified'), true);
  assert.equal(result.requirementVerdicts['READY-01'], 'unsatisfied');
});

test('inherited work is joined by exact observed IDs and decision rows', async () => {
  const { evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const result = evaluateEvidence({
    ...blockedApprovalInput,
    live: { ...blockedApprovalInput.live, openPullRequestNumbers: [], openPullRequestDispositions: [], inheritedWork: { observed: true, observedIds: ['work-a'], dispositions: [] } },
  });
  assert.equal(result.requirementVerdicts['READY-02'], 'unsatisfied');
  assert.ok(result.blockers.some((blocker) => blocker.id === 'fresh_inherited_dispositions_incomplete'));
});

test('valid exact-head CI joins pass, while stale receipt and authoritative metadata fail', async () => {
  const { evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const input = {
    proposal: { ...blockedApprovalInput.proposal, authorization_status: 'approved', stale_artifacts: [{ path: '247-CANDIDATE-DIFF-BASELINE.json', bound_candidate_sha: tuple.candidateSha }], ci: { run_id: ci.run_id, attempt: ci.run_attempt, head_sha: tuple.candidateSha } },
    authorization: { immutable: true, tuple },
    readiness: { final_validation: { checked: { source_sha: tuple.candidateSha, pr_base_sha: tuple.reviewedBaseSha, live_main_sha: tuple.mainSha } } },
    dryRunReceipt: { verdict: 'passed', dry_run_outcome: 'success', requested_sha: tuple.candidateSha, checked_out_sha: tuple.candidateSha, reviewed_base_sha: tuple.reviewedBaseSha, live_base_sha: tuple.mainSha },
    live: { pullRequest: { state: 'OPEN', headSha: tuple.candidateSha, baseSha: tuple.reviewedBaseSha }, main: { sha: tuple.mainSha }, openPullRequestNumbers: [], openPullRequestDispositions: [], inheritedWork: { observed: true, observedIds: [], dispositions: [] } },
    objects: { [tuple.candidateSha]: true, [tuple.reviewedBaseSha]: true },
    remoteSourceObjects: { candidate: { available: true, sourceBlobs: [{ path: 'mix.exs', matches: true }] } },
    exactHeadCiReceipt: ci, authoritativeCi,
  };
  const valid = evaluateEvidence(input);
  assert.equal(valid.checks.find((row) => row.id === 'readiness_and_ci').status, 'passed');
  assert.equal(valid.requirementVerdicts['READY-01'], 'satisfied');
  const stale = evaluateEvidence({ ...input, exactHeadCiReceipt: { ...ci, run_attempt: 2 } });
  assert.ok(stale.blockers.some((row) => row.id === 'exact_head_ci_receipt_mismatch'));
  assert.equal(stale.requirementVerdicts['READY-01'], 'unsatisfied');
  const wrongRun = evaluateEvidence({ ...input, authoritativeCi: { ...authoritativeCi, head_sha: 'f'.repeat(40) } });
  assert.ok(wrongRun.blockers.some((row) => row.id === 'exact_head_ci_authoritative_run_mismatch'));
});

test('capture queries the proposal CI identity instead of stale saved-readiness CI', async () => {
  const { captureExactHeadCi, evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const proposalCi = { run_id: 37819712610, attempt: 3, head_sha: tuple.candidateSha };
  const proposal = { ...blockedApprovalInput.proposal, authorization_status: 'approved', ci: proposalCi,
    stale_artifacts: [{ path: '247-CANDIDATE-DIFF-BASELINE.json', bound_candidate_sha: tuple.candidateSha }] };
  const readiness = { candidate: { review_check_state: { updated_head_ci: ci } },
    final_validation: { checked: { source_sha: tuple.candidateSha, pr_base_sha: tuple.reviewedBaseSha, live_main_sha: tuple.mainSha } } };
  const receipt = { ...ci, run_id: proposalCi.run_id, run_attempt: proposalCi.attempt, head_sha: proposalCi.head_sha,
    job: { ...ci.job, id: 12345, run_attempt: proposalCi.attempt } };
  const run = { id: proposalCi.run_id, run_attempt: proposalCi.attempt, head_sha: proposalCi.head_sha,
    path: '.github/workflows/ci.yml@main', conclusion: 'success' };
  const job = { id: 12345, name: 'ci-gate', head_sha: proposalCi.head_sha, run_attempt: proposalCi.attempt, conclusion: 'success' };
  const endpoints = [];
  const captured = captureExactHeadCi(proposal, readiness, {
    exists: () => true,
    readReceipt: () => receipt,
    ghJson: (endpoint) => { endpoints.push(endpoint); return endpoint.endsWith('/jobs?per_page=100') ? { jobs: [job] } : run; },
  });
  assert.equal(captured.expected.run_id, proposalCi.run_id);
  assert.deepEqual(endpoints, [
    `repos/szTheory/sigra/actions/runs/${proposalCi.run_id}`,
    `repos/szTheory/sigra/actions/runs/${proposalCi.run_id}/jobs?per_page=100`,
  ]);
  const evaluated = evaluateEvidence({ proposal, authorization: { immutable: true, tuple }, readiness,
    dryRunReceipt: { verdict: 'passed', dry_run_outcome: 'success', requested_sha: tuple.candidateSha, checked_out_sha: tuple.candidateSha, reviewed_base_sha: tuple.reviewedBaseSha, live_base_sha: tuple.mainSha },
    live: { pullRequest: { state: 'OPEN', headSha: tuple.candidateSha, baseSha: tuple.reviewedBaseSha }, main: { sha: tuple.mainSha }, openPullRequestNumbers: [], openPullRequestDispositions: [], inheritedWork: { observed: true, observedIds: [], dispositions: [] } },
    objects: { [tuple.candidateSha]: true }, remoteSourceObjects: { candidate: { available: true, sourceBlobs: [{ path: 'mix.exs', matches: true }] } },
    exactHeadCiReceipt: captured.receipt, authoritativeCi: captured.authoritative });
  assert.equal(evaluated.blockers.some((item) => item.id.startsWith('exact_head_ci_')), false);
  const staleAuthority = captureExactHeadCi(proposal, readiness, {
    exists: () => true, readReceipt: () => receipt,
    ghJson: (endpoint) => endpoint.endsWith('/jobs?per_page=100') ? { jobs: [job] } : { ...run, head_sha: 'f'.repeat(40) },
  });
  assert.equal(staleAuthority.authoritative, null);
  assert.equal(staleAuthority.diagnostic, 'exact_head_ci_authoritative_identity_mismatch');
});

test('malformed exact-head CI receipt is parsed once and returns a bounded blocking diagnostic', async () => {
  const { captureExactHeadCi } = await import('./verify-247-readiness.mjs');
  let reads = 0;
  const captured = captureExactHeadCi({ ci: ci }, {}, {
    exists: () => true,
    readReceipt: () => { reads += 1; throw new SyntaxError('sensitive raw input text'); },
    ghJson: () => assert.fail('metadata lookup must not run after receipt parse failure'),
  });
  assert.equal(reads, 1);
  assert.equal(captured.receipt, null);
  assert.equal(captured.authoritative, null);
  assert.equal(captured.diagnostic, 'exact_head_ci_receipt_invalid');
});

test('preservation refs need a resolvable commit and matching record bytes', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const { createHash } = await import('node:crypto');
  const { joinPopulation } = await import('./verify-247-readiness.mjs');
  const root = mkdtempSync(join(tmpdir(), 'readiness-preservation-'));
  try {
    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'config', 'user.email', 'fixture@example.invalid']);
    execFileSync('git', ['-C', root, 'config', 'user.name', 'Fixture']);
    mkdirSync(join(root, 'records'));
    const bytes = Buffer.from(`${JSON.stringify({ id: '224', decision: 'retain' })}\n`);
    writeFileSync(join(root, 'records/224.json'), bytes);
    execFileSync('git', ['-C', root, 'add', 'records/224.json']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'preserve record']);
    const commit = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    execFileSync('git', ['-C', root, 'update-ref', 'refs/heads/preservation/224', commit]);
    const exactReference = { ref: 'refs/heads/preservation/224', commit_sha: commit, record_path: 'records/224.json', record_sha256: createHash('sha256').update(bytes).digest('hex'), decision: 'retain' };
    const valid = joinPopulation({ observedIds: [224], dispositions: [{ id: 224, decision: 'retain', preservation_ref: exactReference }], label: 'pr', root });
    assert.equal(valid.status, 'passed');
    const missing = joinPopulation({ observedIds: [224], dispositions: [{ id: 224, decision: 'retain', preservation_ref: null }], label: 'pr', root });
    assert.equal(missing.status, 'blocked');
    const changed = joinPopulation({ observedIds: [224], dispositions: [{ id: 224, decision: 'retain', preservation_ref: { ...exactReference, record_sha256: '0'.repeat(64) } }], label: 'pr', root });
    assert.equal(changed.status, 'blocked');
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('reconciliation identity rows and blockers are deterministically ordered', async () => {
  const { evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const input = {
    ...blockedApprovalInput,
    live: { pullRequest: { state: 'CLOSED', headSha: '64071b81a131fcfe4068a91d4814da478f13b084', baseSha: '9b90dd709f80eeb683e0d1dbdda514a5d1c60756' }, main: { sha: '6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5' }, openPullRequestNumbers: [], openPullRequestDispositions: [], inheritedWork: null },
  };
  const first = evaluateEvidence(input);
  const second = evaluateEvidence(input);
  assert.deepEqual(first.identityRows.map((row) => row.kind), [...first.identityRows.map((row) => row.kind)].sort());
  assert.deepEqual(first.blockers.map((row) => row.id), [...first.blockers.map((row) => row.id)].sort());
  assert.deepEqual(first, second);
});

test('a concurrent PR or main move invalidates the captured live snapshot', async () => {
  const { liveSnapshotStable, fullPullRequestIdentity } = await import('./verify-247-readiness.mjs');
  const before = {
    pullRequest: { number: 224, state: 'OPEN', headSha: 'candidate-a', baseSha: 'base-a' },
    main: { sha: 'main-a' },
    openPullRequestNumbers: [266, 224],
  };
  assert.equal(liveSnapshotStable(before, { ...before, openPullRequestNumbers: [224, 266] }), true);
  assert.equal(liveSnapshotStable(before, { ...before, main: { sha: 'main-b' } }), false);
  const open = [{ number: 224, head_sha: 'a'.repeat(40), base_sha: 'b'.repeat(40), base_ref: 'main' }];
  const fullBefore = { ...before, openPullRequestNumbers: [224], openPullRequestIdentities: open, openPullRequestPagination: { complete: true } };
  assert.equal(fullPullRequestIdentity(open[0]), `224:${'a'.repeat(40)}:${'b'.repeat(40)}:main`);
  assert.equal(liveSnapshotStable(fullBefore, { ...fullBefore, openPullRequestIdentities: [{ ...open[0], head_sha: 'c'.repeat(40) }] }), false);
  assert.equal(liveSnapshotStable(fullBefore, { ...fullBefore, openPullRequestPagination: { complete: false } }), false);
});

test('candidate source blob drift blocks the tuple even when the commit object exists', async () => {
  const { evaluateEvidence } = await import('./verify-247-readiness.mjs');
  const result = evaluateEvidence({
    ...blockedApprovalInput,
    objects: { [tuple.candidateSha]: true },
    remoteSourceObjects: { candidate: { available: true, sourceBlobs: [{ path: 'mix.exs', matches: false }] } },
  });
  assert.ok(result.blockers.some((blocker) => blocker.id === 'candidate_source_blobs_unverified'));
});

test('canonical report validation requires captured time and exact tuple/run identities', async () => {
  const { checkReport } = await import('./verify-247-readiness.mjs');
  const reconciliation = JSON.parse(readFileSync(new URL('./250-247-RECONCILIATION.json', import.meta.url), 'utf8'));
  const report = readFileSync(new URL('../247-release-candidate-and-repository-readiness/247-VERIFICATION.md', import.meta.url), 'utf8');
  assert.equal(checkReport(report, reconciliation).valid, true);
  const missingIdentity = report.replace(`- **Captured at:** ${reconciliation.captured_at}\n`, '');
  assert.equal(checkReport(missingIdentity, reconciliation).identitiesMatch, false);
});

const phase251CandidateSha = '0e773d3614a242e4fbcdd34c418ecb8a307703d6';
const phase251PublishedSha = '9e80cb78d6374b1ed4074d5fef6b613fee879dca';
const phase251CandidateIdentity = 'candidate:' + phase251CandidateSha;
const phase251PublishedIdentity = 'published_tag:v1.6.0:' + phase251PublishedSha;
const phase251CandidatePaths = [
  '.release-please-manifest.json', 'release-please-config.json', 'mix.exs', 'CHANGELOG.md',
  'README.md', 'guides/introduction/upgrading-to-v1.6.md',
  'test/example/priv/playwright/tests/organizations.spec.ts',
];
const phase251PublishedPaths = [
  'mix.exs', 'CHANGELOG.md', 'README.md', 'guides/introduction/upgrading-to-v1.6.md', 'lib/sigra.ex',
];
const phase251CheckNames = [
  'package_version', 'package_metadata', 'release_manifest', 'release_config', 'changelog',
  'tag_target', 'hexdocs_source_reference', 'published_tag_guide', 'readme_guide_link',
  'adopter_shipped_changes', 'adopter_compatibility', 'generated_host_action',
  'version_requirement', 'update_check_path',
];
const phase251ReadyFeasibilityFixture = {
  status: 'ready',
  requirements: {
    READY01: {
      source_feasibility: 'ready',
      capture_allowed: true,
      verdict: 'authorization_pending',
      history_complete: true,
      approval_event: 'absent',
      candidate_tuple: {
        candidate_sha: phase251CandidateSha,
        reviewed_base_sha: tuple.reviewedBaseSha,
        protected_main_sha: tuple.mainSha,
      },
      published_release_source: {
        tag: 'v1.6.0',
        tag_ref: 'refs/tags/v1.6.0',
        commit_sha: phase251PublishedSha,
      },
      sources: [
        ...phase251CandidatePaths.map((path) => ({
          source_identity: phase251CandidateIdentity,
          commit_sha: phase251CandidateSha,
          path,
          read_status: 'readable',
          trust_status: 'trusted_exact_api_blob_match',
          git_blob_oid: 'a'.repeat(40),
          sha256: 'b'.repeat(64),
        })),
        ...phase251PublishedPaths.map((path) => ({
          source_identity: phase251PublishedIdentity,
          commit_sha: phase251PublishedSha,
          path,
          read_status: 'readable',
          trust_status: 'trusted_exact_api_blob_match',
          git_blob_oid: 'c'.repeat(40),
          sha256: 'd'.repeat(64),
        })),
      ],
      package_adopter: {
        acceptance_satisfied: true,
        checks: Object.fromEntries(phase251CheckNames.map((name) => [name, {
          result: 'pass',
          source_identity: phase251CandidateIdentity + '+' + phase251PublishedIdentity,
          evidence_detail: 'fixture binds exact source identities and bytes',
          finding_detail: 'No finding: fixture has complete source-bound evidence.',
        }])),
      },
    },
    READY02: { source_feasibility: 'ready', capture_allowed: true, verdict: 'unsatisfied', sources: [] },
  },
};
const expectedPackageAcceptanceFixtureNames = [
  'candidateShaMismatch', 'publishedTagShaMismatch', 'packageMetadataMissing', 'packageMetadataMismatch',
  'manifestMissing', 'manifestMismatch', 'releaseConfigMissing', 'releaseConfigMismatch',
  'changelogMissing', 'changelogMismatch', 'tagTargetMismatch', 'hexdocsSourceRefMismatch',
  'publishedTagGuideAbsent', 'candidateAdopterPathAbsent', 'readmeGuideLinkMismatch',
  'adopterShippedChangesIncomplete', 'adopterCompatibilityIncomplete', 'generatedHostActionMissing',
  'versionRequirementMissing', 'updateCheckPathIncomplete',
];
const packageAcceptanceFixtures = expectedPackageAcceptanceFixtureNames.map((name) => ({ name }));
const executedPackageAcceptanceFixtureNames = [];

function applyPackageAcceptanceFixture(input, name) {
  const aliases = {
    packageMetadataMissing: 'package_metadata', packageMetadataMismatch: 'package_metadata',
    manifestMissing: 'release_manifest', manifestMismatch: 'release_manifest',
    releaseConfigMissing: 'release_config', releaseConfigMismatch: 'release_config',
    changelogMissing: 'changelog', changelogMismatch: 'changelog', tagTargetMismatch: 'tag_target',
    hexdocsSourceRefMismatch: 'hexdocs_source_reference', publishedTagGuideAbsent: 'published_tag_guide',
    candidateAdopterPathAbsent: 'adopter_shipped_changes', readmeGuideLinkMismatch: 'readme_guide_link',
    adopterShippedChangesIncomplete: 'adopter_shipped_changes',
    adopterCompatibilityIncomplete: 'adopter_compatibility', generatedHostActionMissing: 'generated_host_action',
    versionRequirementMissing: 'version_requirement', updateCheckPathIncomplete: 'update_check_path',
  };
  if (name === 'candidateShaMismatch') input.requirements.READY01.candidate_tuple.candidate_sha = 'f'.repeat(40);
  else if (name === 'publishedTagShaMismatch') input.requirements.READY01.published_release_source.commit_sha = 'e'.repeat(40);
  else if (name === 'publishedTagGuideAbsent') {
    const source = input.requirements.READY01.sources.find((item) => item.source_identity === phase251PublishedIdentity && item.path === 'guides/introduction/upgrading-to-v1.6.md');
    Object.assign(source, { read_status: 'missing', trust_status: 'trusted_exact_commit_404', http_status: 404 });
  }
  if (aliases[name]) {
    input.requirements.READY01.package_adopter.checks[aliases[name]] = {
      result: name.endsWith('Missing') || name.endsWith('Absent') ? 'missing' : 'mismatch',
    };
  }
}

test('package acceptance fixture registry is exact and unique', () => {
  assert.equal(packageAcceptanceFixtures.length, 20);
  assert.equal(new Set(packageAcceptanceFixtures.map((fixture) => fixture.name)).size, 20);
  assert.deepEqual(
    [...packageAcceptanceFixtures.map((fixture) => fixture.name)].sort(),
    [...expectedPackageAcceptanceFixtureNames].sort(),
  );
});

for (const fixture of packageAcceptanceFixtures) {
  test('Phase 251 package acceptance fixture ' + fixture.name, async () => {
    executedPackageAcceptanceFixtureNames.push(fixture.name);
    const { evaluatePhase251Feasibility } = await import('./verify-247-readiness.mjs');
    assert.equal(typeof evaluatePhase251Feasibility, 'function');
    const input = structuredClone(phase251ReadyFeasibilityFixture);
    applyPackageAcceptanceFixture(input, fixture.name);
    const result = evaluatePhase251Feasibility(input);
    assert.equal(result.requirements.READY01.source_feasibility, 'ready');
    assert.equal(result.requirements.READY01.capture_allowed, true);
    assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
    assert.notEqual(result.requirements.READY01.verdict, 'satisfied');
    assert.equal(result.requirements.READY02.source_feasibility, 'ready');
    assert.equal(result.requirements.READY02.capture_allowed, true);
    if (fixture.name === 'publishedTagGuideAbsent') {
      assert.equal(result.requirements.READY01.package_adopter.checks.published_tag_guide.result, 'missing');
      assert.ok(result.requirements.READY01.package_adopter.sources.some((source) => source.source_identity === phase251PublishedIdentity
        && source.path === 'guides/introduction/upgrading-to-v1.6.md'
        && source.read_status === 'missing'
        && source.trust_status === 'trusted_exact_commit_404'
        && source.http_status === 404));
    }
  });
}

test.after('all package acceptance fixtures execute exactly once', () => {
  assert.deepEqual(
    [...executedPackageAcceptanceFixtureNames].sort(),
    [...expectedPackageAcceptanceFixtureNames].sort(),
  );
});

test('an unreadable READY-01 source blocks only READY-01 capture', async () => {
  const { evaluatePhase251Feasibility } = await import('./verify-247-readiness.mjs');
  assert.equal(typeof evaluatePhase251Feasibility, 'function');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  input.requirements.READY01.sources.push({
    source_identity: phase251CandidateIdentity,
    commit_sha: phase251CandidateSha,
    path: 'mix.exs',
    read_status: 'unreadable',
    trust_status: 'untrusted',
  });
  const result = evaluatePhase251Feasibility(input);
  assert.equal(result.requirements.READY01.source_feasibility, 'blocked');
  assert.equal(result.requirements.READY01.capture_allowed, false);
  assert.equal(result.requirements.READY02.source_feasibility, 'ready');
  assert.equal(result.requirements.READY02.capture_allowed, true);
});

test('the phase capture gate runs only independently capture-ready requirement slices', async () => {
  const { runPhase251Capture } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  input.requirements.READY01.sources[0].read_status = 'unreadable';
  const visited = [];
  const result = runPhase251Capture(input, (name) => {
    visited.push(name);
    return name;
  });
  assert.deepEqual(visited, ['READY02']);
  assert.deepEqual(result.captured, ['READY02']);
  assert.equal(result.requirements.READY01.capture_allowed, false);
  assert.equal(result.requirements.READY02.capture_allowed, true);
});

test('all-slices-blocked preflight does not call a capture writer', async () => {
  const { runPhase251Capture } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  input.requirements.READY01.sources[0].read_status = 'unreadable';
  delete input.requirements.READY02.sources;
  let writes = 0;
  const result = runPhase251Capture(input, () => { writes += 1; });
  assert.equal(result.status, 'blocked');
  assert.deepEqual(result.captured, []);
  assert.equal(writes, 0);
});

test('population joins retain full pull-request identity rather than only its number', async () => {
  const { joinPopulation } = await import('./verify-247-readiness.mjs');
  const observed = [{ number: 224, head_sha: 'a'.repeat(40), base_sha: 'b'.repeat(40), base_ref: 'main' }];
  const joined = joinPopulation({ observedIds: observed, dispositions: [{
    identity: { ...observed[0], head_sha: 'c'.repeat(40) }, decision: 'retain', preservation_ref: null,
  }], label: 'open_pr' });
  assert.equal(joined.status, 'blocked');
  assert.ok(joined.blockers.includes('open_pr_population_mismatch'));
});
