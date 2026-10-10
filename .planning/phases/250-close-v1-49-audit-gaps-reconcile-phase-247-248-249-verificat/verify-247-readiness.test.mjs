import test from 'node:test';
import assert from 'node:assert/strict';

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
