import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

let evaluateEvidence;
let bindPhase251PackageSourceEvidence;
try {
  ({ evaluateEvidence, bindPhase251PackageSourceEvidence } = await import('./verify-247-readiness.mjs'));
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
  const fullBefore = { ...before, openPullRequestNumbers: [224], openPullRequestIdentities: open, openPullRequestPagination: { complete: true, page_count: 1, observed_rows: 1 } };
  assert.equal(fullPullRequestIdentity(open[0]), `224:${'a'.repeat(40)}:${'b'.repeat(40)}:main`);
  assert.equal(liveSnapshotStable(fullBefore, { ...fullBefore, openPullRequestIdentities: [{ ...open[0], head_sha: 'c'.repeat(40) }] }), false);
  assert.equal(liveSnapshotStable(fullBefore, { ...fullBefore, openPullRequestPagination: { complete: false } }), false);
});

test('paginated PR capture distinguishes complete empty, one-page, 100-plus, duplicate, null, and reordered sets', async () => {
  const { normalizePaginatedPullRequests, liveSnapshotStable } = await import('./verify-247-readiness.mjs');
  assert.equal(typeof normalizePaginatedPullRequests, 'function');
  const row = (number, head = String(number).padStart(40, '0')) => ({
    number, head_sha: head, base_sha: 'b'.repeat(40), base_ref: 'main', state: 'open',
  });
  const empty = normalizePaginatedPullRequests([[]]);
  assert.deepEqual(empty.rows, []);
  assert.equal(empty.pagination.complete, true);
  assert.equal(empty.pagination.observed_rows, 0);
  assert.equal(normalizePaginatedPullRequests([]).pagination.complete, false);

  for (const count of [1, 100, 101]) {
    const rows = Array.from({ length: count }, (_, index) => row(index + 1));
    const pages = [rows.slice(0, 100), ...(rows.length > 100 ? [rows.slice(100)] : [])];
    const result = normalizePaginatedPullRequests(pages.reverse());
    assert.equal(result.pagination.complete, true, `${count} rows should be complete`);
    assert.equal(result.pagination.observed_rows, count);
    assert.equal(result.rows[0].number, 1);
    assert.equal(result.rows.at(-1).number, count);
  }

  assert.equal(normalizePaginatedPullRequests([[row(1), row(1, 'c'.repeat(40))]]).pagination.complete, false);
  assert.equal(normalizePaginatedPullRequests([[{ ...row(1), base_sha: null }]]).pagination.complete, false);
  const before = {
    pullRequest: { number: 224, state: 'OPEN', headSha: 'a'.repeat(40), baseSha: 'b'.repeat(40) },
    main: { sha: 'c'.repeat(40) }, openPullRequestNumbers: [1], openPullRequestIdentities: [row(1)],
    openPullRequestPagination: { complete: true, page_count: 1, observed_rows: 1 },
  };
  assert.equal(liveSnapshotStable(before, { ...before, openPullRequestIdentities: [row(1, 'd'.repeat(40))] }), false);
  assert.equal(liveSnapshotStable(before, { ...before, openPullRequestPagination: { complete: false } }), false);
});

test('historical inherited base and head are resolved from the recorded source, never current main', async () => {
  const { mkdtempSync, writeFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const { verifyHistoricalInheritedIdentity } = await import('./verify-247-readiness.mjs');
  const root = mkdtempSync(join(tmpdir(), 'readiness-historical-base-'));
  try {
    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'config', 'user.email', 'fixture@example.invalid']);
    execFileSync('git', ['-C', root, 'config', 'user.name', 'Fixture']);
    writeFileSync(join(root, 'source.txt'), 'base\n');
    execFileSync('git', ['-C', root, 'add', 'source.txt']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'historical base']);
    const base = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    writeFileSync(join(root, 'source.txt'), 'inherited\n');
    execFileSync('git', ['-C', root, 'commit', '-qam', 'recorded inherited head']);
    const inheritedHead = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    writeFileSync(join(root, 'source.txt'), 'current\n');
    execFileSync('git', ['-C', root, 'commit', '-qam', 'later current checkout']);
    const currentHead = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    const readiness = { entry_snapshot: { source: { merge_base_sha: base, inherited_checkout: { head_sha: inheritedHead } } } };

    const exact = verifyHistoricalInheritedIdentity(readiness, currentHead, root);
    assert.equal(exact.base_sha, base);
    assert.equal(exact.inherited_head_sha, inheritedHead);
    assert.equal(exact.base_is_ancestor_of_inherited_head, true);
    assert.equal(exact.inherited_head_is_ancestor_of_current, true);
    assert.deepEqual(exact.blockers, []);
    const substituted = verifyHistoricalInheritedIdentity({ entry_snapshot: { source: {
      merge_base_sha: currentHead, inherited_checkout: { head_sha: inheritedHead },
    } } }, currentHead, root);
    assert.ok(substituted.blockers.includes('recorded_inherited_base_relationship_invalid'));
  } finally { rmSync(root, { recursive: true, force: true }); }
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
  const { checkReport, buildReport } = await import('./verify-247-readiness.mjs');
  const reconciliation = JSON.parse(readFileSync(new URL('./250-247-RECONCILIATION.json', import.meta.url), 'utf8'));
  const report = buildReport(reconciliation);
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
function immutablePackageSource(identity, commitSha, path) {
  let bytes;
  let gitBlobOid;
  try {
    bytes = execFileSync('git', ['show', `${commitSha}:${path}`], { stdio: ['ignore', 'pipe', 'ignore'] });
    gitBlobOid = execFileSync('git', ['rev-parse', `${commitSha}:${path}`], { encoding: 'utf8' }).trim();
  } catch {
    return { source_identity: identity, commit_sha: commitSha, path, read_status: 'missing',
      trust_status: 'trusted_exact_commit_404', http_status: 404 };
  }
  return { source_identity: identity, commit_sha: commitSha, path, read_status: 'readable',
    trust_status: 'trusted_exact_api_blob_match', git_blob_oid: gitBlobOid, api_blob_oid: gitBlobOid,
    sha256: createHash('sha256').update(bytes).digest('hex'), api_sha256: createHash('sha256').update(bytes).digest('hex') };
}
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
        ...phase251CandidatePaths.map((path) => immutablePackageSource(phase251CandidateIdentity, phase251CandidateSha, path)),
        ...phase251PublishedPaths.map((path) => immutablePackageSource(phase251PublishedIdentity, phase251PublishedSha, path)),
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

function bindPackageCheckEvidence(input, requirements) {
  const ready01 = input.requirements.READY01;
  const adopter = ready01.package_adopter;
  adopter.sources = ready01.sources;
  for (const [name, requiredSources] of Object.entries(requirements)) {
    const check = adopter.checks[name];
    check.source_identity = requiredSources.map((required) => required.identity).join(' + ');
    check.evidence_detail = `Fixture source bytes are read from their immutable commits for ${name}.`;
    check.finding_detail = `No finding: ${name} source predicates were evaluated.`;
  }
  bindPhase251PackageSourceEvidence(input);
}

function bindExactApprovalEvidence(ready01) {
  const exactTuple = {
    candidate_sha: phase251CandidateSha,
    reviewed_base_sha: tuple.reviewedBaseSha,
    protected_main_sha: tuple.mainSha,
  };
  const owner = {
    identity: 'historical_owner_report:0e7a2835ebd0d7a1e791ad4dbc73955270108ed1',
    commit_sha: '0e7a2835ebd0d7a1e791ad4dbc73955270108ed1',
    path: '.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md',
    read_status: 'readable', trust_status: 'trusted_exact_api_blob_match',
    git_blob_oid: 'da60a96544dcb1dff301e416930e183e021f0b6e',
    sha256: 'd34f94f861b5fc4983138efadd26ae3b93336bb0b3b8e63afcf1c866fd709e39',
  };
  const review = { id: 12345, state: 'APPROVED', submitted_at: '2026-10-08T18:00:00Z', commit_id: phase251CandidateSha };
  ready01.historical_owner_source = owner;
  ready01.time_window = { start: '2026-10-08T17:41:43Z', end: '2026-10-09T00:56:51Z', complete: true };
  ready01.approval_history = {
    complete: true,
    window: { start: ready01.time_window.start, end: ready01.time_window.end },
    reviews: { status: 200, page_count: 1, item_count: 1, response_sha256: 'a'.repeat(64), events: [review] },
    timeline: { status: 200, page_count: 1, item_count: 1, response_sha256: 'b'.repeat(64), interval_events: [] },
  };
  ready01.approval_record = {
    review_id: review.id, event: review.state, submitted_at: review.submitted_at,
    owner_report_sha256: owner.sha256,
    candidate_tuple: exactTuple,
    exact_head_ci: { run_id: 37819712610, attempt: 1, head_sha: phase251CandidateSha },
    readiness_record: {
      path: '.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json',
      sha256: 'c'.repeat(64), tuple: exactTuple,
    },
    dry_run_receipt: {
      path: '.planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json',
      sha256: 'd'.repeat(64), tuple: exactTuple, authenticated: true, publishing: false,
    },
  };
  ready01.approval_event = 'found';
}

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

test('a published-guide pass cannot cite candidate guide bytes', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  bindPackageCheckEvidence(input, phase251PackageCheckRequirements);
  const ready01 = input.requirements.READY01;
  ready01.approval_event = 'found';
  const check = ready01.package_adopter.checks.published_tag_guide;
  check.source_refs[0] = structuredClone(ready01.sources.find((source) => source.source_identity === phase251CandidateIdentity
    && source.path === 'guides/introduction/upgrading-to-v1.6.md'));

  const result = evaluatePhase251Feasibility(input);
  assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
  assert.notEqual(result.requirements.READY01.verdict, 'satisfied');
});

test('a correct exact-tag source record and its digest-bound assertion can pass', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  const ready01 = input.requirements.READY01;
  bindExactApprovalEvidence(ready01);
  const guide = ready01.sources.find((source) => source.source_identity === phase251PublishedIdentity
    && source.path === 'guides/introduction/upgrading-to-v1.6.md');
  Object.assign(guide, { read_status: 'readable', trust_status: 'trusted_exact_api_blob_match', git_blob_oid: 'e'.repeat(40), sha256: 'f'.repeat(64) });
  bindPackageCheckEvidence(input, phase251PackageCheckRequirements);

  const result = evaluatePhase251Feasibility(input);
  assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
  assert.equal(result.requirements.READY01.package_adopter.checks.published_tag_guide.result, 'mismatch');
  assert.equal(result.requirements.READY01.package_adopter.checks.readme_guide_link.result, 'mismatch');
  assert.equal(result.requirements.READY01.verdict, 'unsatisfied');
});

test('a forged passing README check cannot replace absent immutable source bytes', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  bindPackageCheckEvidence(input, phase251PackageCheckRequirements);
  const check = input.requirements.READY01.package_adopter.checks.readme_guide_link;
  check.result = 'pass';
  check.finding_detail = 'No finding: forged result label.';
  check.source_assertions = check.source_assertions.map((assertion) => ({ ...assertion, result: 'pass', actual: true }));

  const result = evaluatePhase251Feasibility(input);
  assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
  assert.equal(result.requirements.READY01.package_adopter.checks.readme_guide_link.result, 'pass');
  assert.ok(result.requirements.READY01.findings.includes('package_check_source_assertions_invalid:readme_guide_link'));
});

test('a generic approval flag cannot replace an exact contemporaneous approval tuple', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  const ready01 = input.requirements.READY01;
  bindPackageCheckEvidence(input, phase251PackageCheckRequirements);
  bindExactApprovalEvidence(ready01);
  ready01.approval_record.submitted_at = '2026-10-09T01:10:00Z';
  ready01.approval_history.reviews.events[0].submitted_at = ready01.approval_record.submitted_at;

  const result = evaluatePhase251Feasibility(input);
  assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
  assert.equal(result.requirements.READY01.verdict, 'unsatisfied');
  assert.equal(result.requirements.READY02.verdict, 'unsatisfied');
  assert.equal(result.requirements.READY02.source_feasibility, 'ready');
});

test('an exact review cannot satisfy READY-01 when any candidate, CI, readiness, or dry-run identity differs', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const mutations = [
    (approval) => { approval.candidate_tuple.candidate_sha = 'f'.repeat(40); },
    (approval) => { approval.exact_head_ci.run_id += 1; },
    (approval) => { approval.readiness_record.sha256 = 'invalid'; },
    (approval) => { approval.readiness_record.tuple.protected_main_sha = 'f'.repeat(40); },
    (approval) => { approval.dry_run_receipt.sha256 = 'invalid'; },
    (approval) => { approval.dry_run_receipt.tuple.reviewed_base_sha = 'f'.repeat(40); },
    (approval) => { approval.dry_run_receipt.authenticated = false; },
  ];
  for (const mutate of mutations) {
    const input = structuredClone(phase251ReadyFeasibilityFixture);
    const ready01 = input.requirements.READY01;
    bindPackageCheckEvidence(input, phase251PackageCheckRequirements);
    bindExactApprovalEvidence(ready01);
    mutate(ready01.approval_record);
    const result = evaluatePhase251Feasibility(input);
    assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
    assert.equal(result.requirements.READY01.verdict, 'unsatisfied');
    assert.equal(result.requirements.READY02.verdict, 'unsatisfied');
  }
});

test('complete history with no approval stays authorization_pending and preserves READY-02', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const input = structuredClone(phase251ReadyFeasibilityFixture);
  const ready01 = input.requirements.READY01;
  bindPackageCheckEvidence(input, phase251PackageCheckRequirements);
  ready01.approval_history = {
    complete: true,
    window: { start: '2026-10-08T17:41:43Z', end: '2026-10-09T00:56:51Z' },
    reviews: { status: 200, page_count: 1, item_count: 0, response_sha256: 'a'.repeat(64), events: [] },
    timeline: { status: 200, page_count: 1, item_count: 46, response_sha256: 'b'.repeat(64), interval_events: [] },
  };
  ready01.time_window = { start: '2026-10-08T17:41:43Z', end: '2026-10-09T00:56:51Z', complete: true };
  ready01.approval_event = 'absent';

  const result = evaluatePhase251Feasibility(input);
  assert.equal(result.requirements.READY01.verdict, 'authorization_pending');
  assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
  assert.equal(result.requirements.READY02.verdict, 'unsatisfied');
  assert.equal(result.requirements.READY02.source_feasibility, 'ready');
});

test('the refreshed Phase 251 source artifact binds every named package check to trusted source refs', async () => {
  const { phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  const feasibility = JSON.parse(readFileSync(new URL('../251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json', import.meta.url), 'utf8'));
  const ready01 = feasibility.requirements.READY01;
  const checks = ready01.package_adopter.checks;
  for (const [name, requirements] of Object.entries(phase251PackageCheckRequirements)) {
    const check = checks[name];
    assert.ok(Array.isArray(check.source_refs), `${name} source_refs are missing`);
    assert.equal(check.source_refs.length, requirements.length, `${name} source_refs are incomplete`);
    assert.ok(Array.isArray(check.source_assertions), `${name} source_assertions are missing`);
    const actualKeys = check.source_refs.map((ref) => `${ref.identity}:${ref.commit_sha}:${ref.path}`).sort();
    const expectedKeys = requirements.map((source) => `${source.identity}:${source.commit_sha}:${source.path}`).sort();
    assert.deepEqual(actualKeys, expectedKeys, `${name} source_refs differ from the Plan04 mapping`);
    for (const required of requirements) {
      const source = ready01.sources.find((item) => item.source_identity === required.identity
        && item.commit_sha === required.commit_sha && item.path === required.path);
      const ref = check.source_refs.find((item) => item.identity === required.identity
        && item.commit_sha === required.commit_sha && item.path === required.path);
      assert.ok(source, `${name} source record is missing: ${required.path}`);
      assert.equal(ref.git_blob_oid, source.git_blob_oid);
      assert.equal(ref.sha256, source.sha256);
      assert.match(source.trust_status, /^trusted_/);
    }
    assert.deepEqual(check.source_assertions.map((item) => item.id).sort(),
      requirements.flatMap((source) => source.assertions).sort(), `${name} assertions differ from the Plan04 mapping`);
  }
  const guide = checks.published_tag_guide.source_refs[0];
  assert.equal(guide.read_status, 'missing');
  assert.equal(guide.trust_status, 'trusted_exact_commit_404');
  assert.equal(guide.http_status, 404);
  assert.equal(checks.published_tag_guide.result, 'missing');
  assert.equal(checks.readme_guide_link.result, 'mismatch');
});

test('semantic READY verdicts and blockers are stable when capture timestamps differ', async () => {
  const { evaluatePhase251Feasibility } = await import('./verify-247-readiness.mjs');
  const first = structuredClone(phase251ReadyFeasibilityFixture);
  const second = structuredClone(phase251ReadyFeasibilityFixture);
  first.captured_at = '2026-10-11T21:00:00Z';
  second.captured_at = '2026-10-11T22:00:00Z';

  const a = evaluatePhase251Feasibility(first);
  const b = evaluatePhase251Feasibility(second);
  for (const key of ['verdict', 'source_feasibility', 'capture_allowed', 'findings', 'blockers']) {
    assert.deepEqual(a.requirements.READY01[key], b.requirements.READY01[key]);
    assert.deepEqual(a.requirements.READY02[key], b.requirements.READY02[key]);
  }
  assert.equal(a.requirements.READY01.verdict, 'authorization_pending');
});

test('Phase 251 artifact check rejects a mixed capture ID across packet, summary, and owner report', async () => {
  const { checkPhase251Artifacts } = await import('./verify-247-readiness.mjs');
  const packet = {
    capture_id: 'phase251-0123456789abcdefabcd',
    candidate_tuple: { candidate_sha: phase251CandidateSha },
    published_release_source: { commit_sha: phase251PublishedSha },
    requirement_verdicts: { 'READY-01': 'authorization_pending', 'READY-02': 'unsatisfied' },
    requirements: { READY01: { verdict: 'authorization_pending' }, READY02: { verdict: 'unsatisfied' } },
  };
  const digest = createHash('sha256').update(`${JSON.stringify(packet, null, 2)}\n`).digest('hex');
  const summary = `- **Packet capture ID:** \`${packet.capture_id}\`\n- **Packet SHA-256:** \`${digest}\``;
  const owner = `<!-- phase-251-capture-id: ${packet.capture_id} -->\n<!-- phase-251-reconciliation-sha256: ${digest} -->`;
  assert.equal(checkPhase251Artifacts(packet, summary, owner).valid, true);
  assert.equal(checkPhase251Artifacts(packet, summary.replace(packet.capture_id, 'phase251-other'), owner).valid, false);
  assert.equal(checkPhase251Artifacts(packet, summary, owner.replace(packet.capture_id, 'phase251-other')).valid, false);
});

test('secondary-worktree dirty paths stay in the READY-02 disposition and preservation join', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const { createHash } = await import('node:crypto');
  const { localInheritedSnapshot, buildPhase251Packet } = await import('./verify-247-readiness.mjs');
  assert.equal(typeof localInheritedSnapshot, 'function');
  assert.equal(typeof buildPhase251Packet, 'function');

  const root = mkdtempSync(join(tmpdir(), 'readiness-secondary-worktree-'));
  const secondary = join(tmpdir(), `readiness-secondary-${process.pid}-${Date.now()}`);
  try {
    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'config', 'user.email', 'fixture@example.invalid']);
    execFileSync('git', ['-C', root, 'config', 'user.name', 'Fixture']);
    writeFileSync(join(root, 'tracked.txt'), 'base\n');
    execFileSync('git', ['-C', root, 'add', 'tracked.txt']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'fixture base']);
    const base = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    execFileSync('git', ['-C', root, 'worktree', 'add', '-qb', 'secondary', secondary, base]);
    const dirtyBytes = Buffer.from('secondary-only\n');
    writeFileSync(join(secondary, 'secondary-only.txt'), dirtyBytes);

    const local = localInheritedSnapshot(base, root);
    const secondaryRow = local.worktrees.find((row) => row.branch === 'refs/heads/secondary');
    const dirty = secondaryRow?.status_entries ?? [];
    assert.deepEqual(dirty.map((row) => ({ path: row.path, status: row.status, source_byte_sha256: row.source_byte_sha256 })), [
      { path: 'secondary-only.txt', status: '??', source_byte_sha256: createHash('sha256').update(dirtyBytes).digest('hex') },
    ]);

    const packetInput = (dispositions) => {
      const localWithDispositions = { ...local, inherited_dispositions: dispositions };
      const before = { open_pull_requests: [], pagination: { complete: true, page_count: 1, observed_rows: 0 }, main: { sha: 'a'.repeat(40) } };
      const after = { open_pull_requests: [], pagination: { complete: true, page_count: 1, observed_rows: 0 }, main: { sha: 'a'.repeat(40) } };
      const evaluated = { requirements: {
        READY01: { capture_allowed: true, verdict: 'authorization_pending', blockers: [], findings: [], package_adopter: { acceptance_satisfied: false } },
        READY02: { capture_allowed: true, verdict: 'unsatisfied', blockers: [], findings: [] },
      } };
      return buildPhase251Packet({}, evaluated, before, after, localWithDispositions, [], { root });
    };
    const dirtyIdentity = `dirty:${secondaryRow.path}:${secondaryRow.head_sha}:??:secondary-only.txt:${createHash('sha256').update(dirtyBytes).digest('hex')}`;
    const missing = packetInput([]);
    assert.equal(missing.requirements.READY02.verdict, 'unsatisfied');
    assert.ok(missing.requirements.READY02.inherited_work.disposition_join.blockers.includes('inherited_work_population_mismatch'));

    mkdirSync(join(root, 'preservation'), { recursive: true });
    const recordBytes = Buffer.from(`${JSON.stringify({ id: dirtyIdentity, decision: 'separate-follow-up', source_byte_sha256: createHash('sha256').update(dirtyBytes).digest('hex') })}\n`);
    writeFileSync(join(root, 'preservation/secondary.json'), recordBytes);
    execFileSync('git', ['-C', root, 'add', 'preservation/secondary.json']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'preserve secondary worktree item']);
    const commit = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    execFileSync('git', ['-C', root, 'update-ref', 'refs/heads/preservation/secondary', commit]);
    const preservationRef = { ref: 'refs/heads/preservation/secondary', commit_sha: commit, record_path: 'preservation/secondary.json', record_sha256: createHash('sha256').update(recordBytes).digest('hex'), source_byte_sha256: createHash('sha256').update(dirtyBytes).digest('hex') };
    const disposition = { id: dirtyIdentity, decision: 'separate-follow-up', preservation_ref: preservationRef };
    const valid = packetInput([disposition]);
    assert.equal(valid.requirements.READY02.verdict, 'satisfied');
    assert.equal(valid.requirements.READY02.inherited_work.disposition_join.status, 'passed');

    const duplicate = packetInput([disposition, disposition]);
    assert.equal(duplicate.requirements.READY02.verdict, 'unsatisfied');
    assert.ok(duplicate.requirements.READY02.inherited_work.disposition_join.blockers.includes('inherited_work_disposition_ids_invalid'));

    const wrongBytes = packetInput([{ ...disposition, preservation_ref: { ...preservationRef, record_sha256: '0'.repeat(64) } }]);
    assert.equal(wrongBytes.requirements.READY02.verdict, 'unsatisfied');
    assert.equal(wrongBytes.requirements.READY02.inherited_work.disposition_join.status, 'blocked');
  } finally {
    try { execFileSync('git', ['-C', root, 'worktree', 'remove', '--force', secondary]); } catch {}
    rmSync(root, { recursive: true, force: true });
  }
});

test('clean secondary worktrees do not create phantom dirty inherited items', async () => {
  const { mkdtempSync, writeFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const { localInheritedSnapshot } = await import('./verify-247-readiness.mjs');
  const root = mkdtempSync(join(tmpdir(), 'readiness-clean-worktree-'));
  const secondary = join(tmpdir(), `readiness-clean-${process.pid}-${Date.now()}`);
  try {
    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'config', 'user.email', 'fixture@example.invalid']);
    execFileSync('git', ['-C', root, 'config', 'user.name', 'Fixture']);
    writeFileSync(join(root, 'tracked.txt'), 'base\n');
    execFileSync('git', ['-C', root, 'add', 'tracked.txt']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'fixture base']);
    const base = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    execFileSync('git', ['-C', root, 'worktree', 'add', '-qb', 'secondary', secondary, base]);
    const local = localInheritedSnapshot(base, root);
    assert.ok(local.worktrees.every((row) => row.status_entries.length === 0));
    assert.deepEqual(local.inherited_dirty_entries, []);
  } finally {
    try { execFileSync('git', ['-C', root, 'worktree', 'remove', '--force', secondary]); } catch {}
    rmSync(root, { recursive: true, force: true });
  }
});

test('scoped preservation records read back exact item identity and PR dispositions cite current source paths', async () => {
  const { mkdtempSync, writeFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const { createScopedPreservationRef, prDisposition, joinPopulation } = await import('./verify-247-readiness.mjs');
  const root = mkdtempSync(join(tmpdir(), 'readiness-scoped-preservation-'));
  try {
    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'config', 'user.email', 'fixture@example.invalid']);
    execFileSync('git', ['-C', root, 'config', 'user.name', 'Fixture']);
    writeFileSync(join(root, 'base.txt'), 'base\n');
    execFileSync('git', ['-C', root, 'add', 'base.txt']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'fixture base']);
    const head = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    const record = { id: '17:' + 'a'.repeat(40) + ':' + 'b'.repeat(40) + ':main', kind: 'pull_request',
      decision: 'release-relevant', reason: 'Release source requires separate review.', source_byte_sha256: null,
      captured_source: { id: '17:' + 'a'.repeat(40) + ':' + 'b'.repeat(40) + ':main' },
      detail: { files: ['mix.exs'] } };
    const preservation = createScopedPreservationRef([record], head, root);
    const reference = preservation.references.get(record.id);
    const joined = joinPopulation({ observedIds: [record.id], dispositions: [{ id: record.id, decision: record.decision, preservation_ref: reference }], label: 'pr', root });
    assert.equal(preservation.readback_verified, true);
    assert.equal(joined.status, 'passed');
    assert.equal(prDisposition({ number: 17, title: 'Update package metadata', files: [{ filename: 'mix.exs' }] }).decision, 'release-relevant');
    assert.equal(prDisposition({ number: 18, title: 'Update test fixture', files: [{ filename: 'test/fixture.ex' }] }).decision, 'separate-follow-up');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('package checks reject wrong path, commit, blob, digest, and assertion identity', async () => {
  const { evaluatePhase251Feasibility, phase251PackageCheckRequirements } = await import('./verify-247-readiness.mjs');
  for (const mutate of [
    (check) => { check.source_refs[0].path = 'README.md'; },
    (check) => { check.source_refs[0].commit_sha = 'f'.repeat(40); },
    (check) => { check.source_refs[0].git_blob_oid = 'f'.repeat(40); },
    (check) => { check.source_refs[0].sha256 = '0'.repeat(64); },
    (check) => { check.source_assertions[0].id = 'unrelated_assertion'; },
  ]) {
    const input = structuredClone(phase251ReadyFeasibilityFixture);
    const ready01 = input.requirements.READY01;
    ready01.approval_event = 'found';
    const guide = ready01.sources.find((source) => source.source_identity === phase251PublishedIdentity
      && source.path === 'guides/introduction/upgrading-to-v1.6.md');
    Object.assign(guide, { read_status: 'readable', trust_status: 'trusted_exact_api_blob_match', git_blob_oid: 'e'.repeat(40), sha256: 'f'.repeat(64) });
    bindPackageCheckEvidence(input, phase251PackageCheckRequirements);
    mutate(ready01.package_adopter.checks.published_tag_guide);
    const result = evaluatePhase251Feasibility(input);
    assert.equal(result.requirements.READY01.package_adopter.acceptance_satisfied, false);
  }
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
