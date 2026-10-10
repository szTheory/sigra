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
