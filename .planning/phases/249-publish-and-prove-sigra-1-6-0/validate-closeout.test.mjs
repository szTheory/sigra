import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

let validatorApi;
try {
  validatorApi = await import('./validate-closeout.mjs');
} catch (error) {
  if (error.code !== 'ERR_MODULE_NOT_FOUND' || !String(error.url).endsWith('/validate-closeout.mjs')) throw error;
  validatorApi = {};
}

function invoke(name, ...args) {
  assert.equal(typeof validatorApi[name], 'function', `validate-closeout.mjs must export ${name}()`);
  return validatorApi[name](...args);
}

const sha = value => value.repeat(40).slice(0, 40);
const digest = value => value.repeat(64).slice(0, 64);
const promotionPaths = [
  '.github/ci-skip-manifest.tsv',
  '.github/workflows/ci.yml',
  '.github/workflows/release-please.yml',
  '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json',
  'doc/llms.txt',
  'scripts/ci/check-docs-index.sh',
  'scripts/ci/check-docs-index.test.sh',
  'scripts/ci/honest-skip-verdict.sh',
  'scripts/ci/honest-skip-verdict.test.sh',
  'scripts/ci/refresh-release-docs.sh',
  'scripts/ci/refresh-release-docs.test.sh',
  'scripts/ci/release-public-proof.sh',
  'scripts/ci/release-public-proof.test.sh',
  'test/sigra/planning/phase_232_playwright_economics_test.exs',
  'test/sigra/planning/phase_249_release_docs_contract_test.exs',
];

function fixture() {
  const worktree = {
    path: '/repo',
    branch: 'main',
    head_sha: sha('a'),
    read_status: 'complete',
    dirty_paths: [{ path: 'notes/a.md', status: '??', sha256: digest('b') }],
  };
  const pullRequest = {
    number: 302,
    title: 'chore(main): release 1.6.1',
    base_ref: 'main',
    base_sha: sha('d'),
    head_ref: 'release-please--branches--main',
    head_sha: sha('c'),
    url: 'https://github.com/szTheory/sigra/pull/302',
    files_read: { status: 'complete', endpoint: 'repos/szTheory/sigra/pulls/302/files?per_page=100' },
    changed_files: [{ path: 'mix.exs', status: 'modified' }],
    disposition: {
      category: 'release-relevant',
      reason: 'Release Please candidate; exact-head required CI still gates eligibility.',
      sources: ['https://github.com/szTheory/sigra/pull/302'],
      candidate_eligibility: 'pending-exact-head-ci',
    },
  };
  const ledger = {
    schema_version: 1,
    repository: 'szTheory/sigra',
    observed_at: '2026-10-09T12:00:00.000Z',
    inventory_status: 'complete',
    source_status: {
      worktrees: { status: 'complete', pagination_complete: true },
      pull_requests: { status: 'complete', pagination_complete: true },
    },
    worktrees: [worktree],
    pull_requests: [pullRequest],
  };
  const live = structuredClone(ledger);
  return { ledger, live };
}

function acceptedHandoffLossFixture() {
  const { ledger, live } = fixture();
  const worktreePath = '/Users/jon/projects/sigra';
  const historical = {
    path: '.planning/HANDOFF.json',
    status: ' M',
    content_state: 'regular-file',
    sha256: '00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148',
    preservation: {
      schema_version: 1,
      state: 'accepted-loss',
      owner: 'Historical Phase 249 GSD handoff revision; exact former bytes were not recovered',
      target: 'accepted-loss exception for this exact historical identity',
      action: 'Record the user-authorized loss without claiming byte recovery; preserve every other inherited path.',
      reason: 'The recovery audit found no copy of these bytes. The user accepted this exact loss so Phase 249 can continue.',
      source: 'Prior live inventory at 2026-10-09T13:37:04.730Z; source HEAD 978a83f9822d907a8ac5f1b6f422d622ebc969e0.',
      source_head_sha: '978a83f9822d907a8ac5f1b6f422d622ebc969e0',
    },
  };
  ledger.worktrees[0].path = worktreePath;
  ledger.worktrees[0].inherited_dirty_paths = [historical];
  ledger.worktrees[0].dirty_paths = [];
  live.worktrees[0].path = worktreePath;
  live.worktrees[0].dirty_paths = [];
  ledger.accepted_loss_exceptions = [{
    schema_version: 1,
    disposition: 'accepted-loss',
    worktree_path: worktreePath,
    path: '.planning/HANDOFF.json',
    status: ' M',
    sha256: historical.sha256,
    source_head_sha: '978a83f9822d907a8ac5f1b6f422d622ebc969e0',
    authorized_by: 'user',
    authorized_at: '2026-10-09',
    authorization: 'accept reality and move on accordingly',
    scope: 'This exact historical .planning/HANDOFF.json revision only; every other missing or unverified path remains blocked.',
    reason: 'The historical bytes were not recovered after the recorded local, GitHub, worktree-file and artifact-metadata audit. The user accepted this exact loss so Phase 249 can continue; no claim is made that the bytes were preserved.',
    audit_record: {
      path: '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-PRESERVATION.json',
      revision: 4,
      ref: 'refs/phase-249-preservation/plan-08-preservation-record-v4',
      commit_sha: '96581c2b555a11b50b6efece9c25a5b1f8e0e456',
      sha256: 'b47304df684b3eda5916730072a481d91113f6fca76bd0f9507e24387f3f4ad3',
      target_sha256: historical.sha256,
    },
  }];
  return { ledger, live, historical };
}

function captureFixture(t) {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-closeout-capture-'));
  const bin = path.join(repo, 'bin');
  const closeoutPath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json';
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q', '--initial-branch=main');
  git('config', 'user.name', 'Closeout Fixture');
  git('config', 'user.email', 'closeout-fixture@example.invalid');
  fs.mkdirSync(path.dirname(path.join(repo, closeoutPath)), { recursive: true });
  fs.writeFileSync(path.join(repo, closeoutPath), '{"baseline":true}\n');
  git('add', closeoutPath);
  git('commit', '-m', 'capture fixture baseline');
  fs.mkdirSync(bin);
  const ghPath = path.join(bin, 'gh');
  fs.writeFileSync(ghPath, '#!/bin/sh\nprintf "[[]]\\n"\n');
  fs.chmodSync(ghPath, 0o755);
  return { repo, closeoutPath, ghPath };
}

function withGhStub(ghPath, action) {
  const oldPath = process.env.PATH;
  process.env.PATH = `${path.dirname(ghPath)}${path.delimiter}${oldPath ?? ''}`;
  try { return action(); } finally {
    if (oldPath === undefined) delete process.env.PATH;
    else process.env.PATH = oldPath;
  }
}

function preservedFixture(t) {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-closeout-preservation-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q');
  git('config', 'user.name', 'Closeout Fixture');
  git('config', 'user.email', 'closeout-fixture@example.invalid');
  fs.writeFileSync(path.join(repo, 'anchor.txt'), 'anchor\n');
  git('add', 'anchor.txt');
  git('commit', '-m', 'anchor');
  const anchor = git('rev-parse', 'HEAD');
  const sourcePath = 'notes/a.md';
  const contents = Buffer.from('recoverable bytes\n');
  const contentSha = createHash('sha256').update(contents).digest('hex');
  fs.mkdirSync(path.dirname(path.join(repo, sourcePath)), { recursive: true });
  fs.writeFileSync(path.join(repo, sourcePath), contents);
  const { ledger, live } = fixture();
  ledger.worktrees[0].path = repo;
  live.worktrees[0].path = repo;
  ledger.worktrees[0].head_sha = anchor;
  live.worktrees[0].head_sha = anchor;
  ledger.worktrees[0].dirty_paths[0] = {
    path: sourcePath,
    status: '??',
    content_state: 'regular-file',
    sha256: contentSha,
  };
  live.worktrees[0].dirty_paths = [];
  git('add', sourcePath);
  git('commit', '-m', 'preserve inherited bytes');
  const preservedObject = git('rev-parse', 'HEAD');
  const ref = 'refs/phase-249-preservation/fixture';
  git('update-ref', ref, preservedObject);
  git('checkout', '-q', '--detach', anchor);
  ledger.worktrees[0].dirty_paths[0].preservation = {
    owner: 'fixture owner',
    target: ref,
    action: 'Preserve the exact path under a durable Git ref.',
    state: 'preserved',
    reason: 'Fixture verifies recoverability.',
    source: 'Synthetic test worktree and content hash.',
    ref,
    object_sha: preservedObject,
    paths: [{ path: sourcePath, status: '??', content_state: 'regular-file', sha256: contentSha }],
  };
  return { repo, ledger, live, sourcePath, contentSha, ref, git };
}

function promotionFixture() {
  const headSha = sha('a');
  const baseSha = sha('b');
  const receipt = {
    version: '1.6.0',
    package_source_sha: sha('c'),
    package_source_ci: {
      run_id: '37875238741',
      attempt: 2,
      head_sha: sha('c'),
      ci_gate_job_id: '113654406257',
      ci_gate_conclusion: 'success',
    },
  };
  const promotion = {
    schema_version: 1,
    verdict: 'promoted',
    repository: 'szTheory/sigra',
    pr: {
      number: 349,
      url: 'https://github.com/szTheory/sigra/pull/349',
      state: 'closed',
      merged: true,
      title: 'feat(249): prove the Sigra 1.6.0 release',
      base_ref: 'main',
      base_sha: baseSha,
      head_ref: 'gsd/phase-249-09-candidate',
      head_sha: headSha,
      head_repository: 'szTheory/sigra',
      author_login: 'contributor',
    },
    head_sha: headSha,
    base_sha: baseSha,
    files_read: { status: 'complete', file_count: promotionPaths.length },
    changed_paths: [...promotionPaths],
    review: {
      type: 'github',
      result: 'approved',
      commit_sha: headSha,
      reviewer_login: 'independent-reviewer',
      author_login: 'contributor',
      submitted_at: '2026-10-09T20:00:00Z',
    },
    required_ci: {
      check_name: 'ci-gate',
      workflow: '.github/workflows/ci.yml',
      event: 'pull_request',
      status: 'completed',
      conclusion: 'success',
      head_sha: headSha,
      run_id: '400',
      attempt: 1,
      job_id: '401',
      job_name: 'ci-gate',
      job_head_sha: headSha,
      job_status: 'completed',
      job_conclusion: 'success',
    },
    merge: { merged: true, method: 'squash', merge_sha: sha('d'), merged_at: '2026-10-09T21:00:00Z' },
    release_receipt: {
      path: '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json',
      sha256: digest('e'),
      blob_sha: sha('f'),
      version: receipt.version,
      package_source_sha: receipt.package_source_sha,
      package_source_ci: receipt.package_source_ci,
    },
  };
  const constraints = {
    expected_head_sha: headSha,
    expected_base_sha: baseSha,
    allowed_paths: promotionPaths,
    release_receipt: receipt,
    release_receipt_sha256: digest('e'),
    release_receipt_blob_sha: sha('f'),
    internal_review_sha256: digest('1'),
  };
  return { promotion, constraints, headSha, baseSha };
}

test('a verified preservation ref and exact path hash allow the source worktree to be clean', t => {
  const { repo, ledger, live } = preservedFixture(t);
  const result = invoke('validatePreservation', ledger, live, { repoRoot: repo });
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  assert.equal(result.blocked, false);
  assert.equal(result.closeout_status, 'ready');
});

test('a preserved change without a durable ref remains blocked', t => {
  const { repo, ledger, live } = preservedFixture(t);
  delete ledger.worktrees[0].dirty_paths[0].preservation.ref;
  const result = invoke('validatePreservation', ledger, live, { repoRoot: repo });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some(error => error.code === 'preservation_ref_missing'));
});

test('a ref that cannot recover the recorded content hash remains blocked', t => {
  const { repo, ledger, live } = preservedFixture(t);
  ledger.worktrees[0].dirty_paths[0].preservation.paths[0].sha256 = digest('f');
  const result = invoke('validatePreservation', ledger, live, { repoRoot: repo });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some(error => error.code === 'preservation_content_mismatch'));
});

test('a newly appearing dirty path remains blocked after preservation', t => {
  const { repo, ledger, live } = preservedFixture(t);
  live.worktrees[0].dirty_paths.push({ path: 'notes/new.md', status: '??', content_state: 'regular-file', sha256: digest('a') });
  const result = invoke('validatePreservation', ledger, live, { repoRoot: repo });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some(error => error.code === 'preservation_new_dirty_path'));
});

test('the exact user-authorized historical handoff loss is explicit and remains labeled', t => {
  const { repo } = preservedFixture(t);
  const { ledger, live } = acceptedHandoffLossFixture();
  const disposition = invoke('validateDispositions', ledger);
  assert.equal(disposition.valid, true, JSON.stringify(disposition.errors));
  assert.equal(disposition.blocked, false);
  assert.equal(disposition.closeout_status, 'accepted-with-recorded-loss');
  assert.equal(disposition.accepted_losses.length, 1);
  const preservation = invoke('validatePreservation', ledger, live, { repoRoot: repo });
  assert.equal(preservation.valid, true, JSON.stringify(preservation.errors));
  assert.equal(preservation.blocked, false);
  assert.equal(preservation.closeout_status, 'accepted-with-recorded-loss');
  assert.equal(preservation.accepted_losses[0].sha256, '00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148');
});

test('the accepted historical handoff loss fails closed if authorization or identity changes', () => {
  const { ledger: missingAuthorization } = acceptedHandoffLossFixture();
  delete missingAuthorization.accepted_loss_exceptions[0].authorized_by;
  const missingResult = invoke('validateDispositions', missingAuthorization);
  assert.equal(missingResult.valid, false);
  assert.ok(missingResult.errors.some(error => error.code === 'accepted_loss_authorization_invalid'));

  const { ledger: wrongIdentity } = acceptedHandoffLossFixture();
  wrongIdentity.worktrees[0].inherited_dirty_paths[0].sha256 = digest('f');
  const identityResult = invoke('validateDispositions', wrongIdentity);
  assert.equal(identityResult.valid, false);
  assert.ok(identityResult.errors.some(error => error.code === 'accepted_loss_authorization_invalid'));
});

test('the accepted-loss exception cannot hide a currently dirty source path', t => {
  const { repo } = preservedFixture(t);
  const { ledger, live, historical } = acceptedHandoffLossFixture();
  live.worktrees[0].dirty_paths = [{ path: historical.path, status: historical.status, content_state: historical.content_state, sha256: historical.sha256 }];
  const result = invoke('validatePreservation', ledger, live, { repoRoot: repo });
  assert.equal(result.valid, false);
  assert.equal(result.blocked, true);
  assert.ok(result.errors.some(error => error.code === 'accepted_loss_source_path_dirty'));
});

test('later phase outputs cannot hide behind names, prefixes, or a legacy path allowlist', () => {
  const laterPaths = [
    '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md',
    '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-EXECUTION-HANDOFF.md',
    '.planning/phases/249-publish-and-prove-sigra-1-6-0/COVERAGE.md',
    '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-08-PLAN.md',
    '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-08-SUMMARY.md',
  ];
  for (const evidencePath of laterPaths) {
    const { ledger, live } = fixture();
    ledger.evidence_artifacts = {
      worktree_path: '/repo',
      anchor_head_sha: ledger.worktrees[0].head_sha,
      paths: ['.planning/phases/249-publish-and-prove-sigra-1-6-0/*'],
    };
    live.worktrees[0].dirty_paths.push({ path: evidencePath, status: '??', content_state: 'regular-file', sha256: digest('e') });
    const result = invoke('validateInventory', ledger, live);
    assert.equal(result.valid, false, `${evidencePath} must remain visible as a new dirty path`);
    assert.ok(result.errors.some(error => error.code === 'dirty_path_population_mismatch'));
  }
});

test('an exact reviewed head, required ci-gate, receipt and scoped diff can be promoted', () => {
  const { promotion, constraints } = promotionFixture();
  const result = invoke('validatePromotion', promotion, constraints);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  assert.equal(result.blocked, false);
});

test('an exact reviewed head with successful CI is ready for native protected merge', () => {
  const { promotion, constraints } = promotionFixture();
  promotion.verdict = 'ready-to-merge';
  promotion.pr.state = 'open';
  promotion.pr.merged = false;
  promotion.merge = null;
  const result = invoke('validatePromotion', promotion, constraints);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  assert.equal(result.closeout_status, 'ready-to-merge');
});

test('a changed promotion head or base blocks the receipt', () => {
  const { promotion, constraints } = promotionFixture();
  promotion.head_sha = sha('f');
  promotion.base_sha = sha('e');
  const result = invoke('validatePromotion', promotion, constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_head_mismatch'));
  assert.ok(result.errors.some(error => error.code === 'promotion_base_mismatch'));
});

test('promotion without successful ci-gate evidence is blocked', () => {
  const { promotion, constraints } = promotionFixture();
  promotion.required_ci = null;
  const result = invoke('validatePromotion', promotion, constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_ci_gate_missing'));
});

test('promotion without the immutable artifact-derived release receipt is blocked', () => {
  const { promotion, constraints } = promotionFixture();
  promotion.release_receipt = null;
  const result = invoke('validatePromotion', promotion, constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_receipt_missing'));
});

test('promotion with an unrelated diff path is blocked', () => {
  const { promotion, constraints } = promotionFixture();
  promotion.changed_paths.push('README.md');
  const result = invoke('validatePromotion', promotion, constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_diff_path_unrelated'));
});

test('promotion blocks incomplete file pagination and a diff missing an allowlisted path', () => {
  const incomplete = promotionFixture();
  incomplete.promotion.files_read.status = 'failed';
  let result = invoke('validatePromotion', incomplete.promotion, incomplete.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_files_incomplete'));

  const missingPath = promotionFixture();
  missingPath.promotion.changed_paths.pop();
  result = invoke('validatePromotion', missingPath.promotion, missingPath.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_diff_path_set_mismatch'));
});

test('promotion blocks a review attached to an older head or authored by the PR author', () => {
  const stale = promotionFixture();
  stale.promotion.review.commit_sha = sha('f');
  let result = invoke('validatePromotion', stale.promotion, stale.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_review_missing'));

  const selfReview = promotionFixture();
  selfReview.promotion.review.reviewer_login = selfReview.promotion.pr.author_login;
  result = invoke('validatePromotion', selfReview.promotion, selfReview.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_review_missing'));
});

test('promotion accepts only an exact-head internal review artifact whose captured bytes match', () => {
  const { promotion, constraints, headSha } = promotionFixture();
  promotion.review = {
    type: 'internal',
    result: 'passed',
    reviewer_login: 'codex-internal-review',
    commit_sha: headSha,
    source_path: '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-10-CANDIDATE.json',
    source_sha256: constraints.internal_review_sha256,
  };
  assert.equal(invoke('validatePromotion', promotion, constraints).valid, true);
  promotion.review.source_sha256 = digest('2');
  const result = invoke('validatePromotion', promotion, constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_review_missing'));
});

test('promotion blocks skipped, failed, or wrong-head ci-gate job evidence', () => {
  const skipped = promotionFixture();
  skipped.promotion.required_ci.job_status = 'skipped';
  let result = invoke('validatePromotion', skipped.promotion, skipped.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_ci_gate_missing'));

  const failed = promotionFixture();
  failed.promotion.required_ci.job_conclusion = 'failure';
  result = invoke('validatePromotion', failed.promotion, failed.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_ci_gate_missing'));

  const wrongHead = promotionFixture();
  wrongHead.promotion.required_ci.job_head_sha = sha('f');
  result = invoke('validatePromotion', wrongHead.promotion, wrongHead.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_ci_gate_missing'));
});

test('promotion only accepts the immutable receipt blob and squash merge evidence', () => {
  const receipt = promotionFixture();
  receipt.promotion.release_receipt.blob_sha = sha('a');
  let result = invoke('validatePromotion', receipt.promotion, receipt.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_receipt_mismatch'));

  const merge = promotionFixture();
  merge.promotion.merge.method = 'merge';
  result = invoke('validatePromotion', merge.promotion, merge.constraints);
  assert.ok(result.errors.some(error => error.code === 'promotion_merge_missing'));
});

test('an exact complete inventory accepts a successful empty PR query', () => {
  const { ledger, live } = fixture();
  ledger.pull_requests = [];
  live.pull_requests = [];
  const result = invoke('validateInventory', ledger, live);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
});

test('Phase 249 promotion PRs receive a source-backed release disposition during capture', () => {
  const pr = {
    number: 304,
    title: 'feat(249): prove the Sigra 1.6.0 release',
    base_ref: 'main',
    head_ref: 'gsd/phase-249-09-candidate',
    url: 'https://github.com/szTheory/sigra/pull/304',
  };
  const disposition = invoke('phase249PromotionDisposition', pr);
  assert.equal(disposition.category, 'release-relevant');
  assert.deepEqual(disposition.sources, [pr.url]);
  assert.equal(disposition.candidate_eligibility, 'pending-exact-head-ci');
  assert.equal(invoke('phase249PromotionDisposition', { ...pr, head_ref: 'release-please--branches--main' }), null);
});

test('a missing live PR fails exact population comparison', () => {
  const { ledger, live } = fixture();
  live.pull_requests = [];
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('duplicate PR identities fail even when their heads match', () => {
  const { ledger, live } = fixture();
  ledger.pull_requests.push(structuredClone(ledger.pull_requests[0]));
  live.pull_requests.push(structuredClone(live.pull_requests[0]));
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a missing worktree fails exact population comparison', () => {
  const { ledger, live } = fixture();
  live.worktrees = [];
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('duplicate worktree identities fail even when their heads match', () => {
  const { ledger, live } = fixture();
  ledger.worktrees.push(structuredClone(ledger.worktrees[0]));
  live.worktrees.push(structuredClone(live.worktrees[0]));
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a failed or partial PR query cannot be accepted as an empty queue', () => {
  const { ledger, live } = fixture();
  ledger.pull_requests = [];
  live.pull_requests = [];
  ledger.source_status.pull_requests = { status: 'failed', pagination_complete: false };
  live.source_status.pull_requests = { status: 'failed', pagination_complete: false };
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a captured partial inventory remains blocked even if live reads now succeed', () => {
  const { ledger, live } = fixture();
  ledger.inventory_status = 'blocked';
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a dirty path omitted from the ledger fails even if its worktree HEAD is unchanged', () => {
  const { ledger, live } = fixture();
  live.worktrees[0].dirty_paths.push({ path: 'notes/b.md', status: '??', sha256: digest('d') });
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a changed dirty-path content hash fails even when path and status match', () => {
  const { ledger, live } = fixture();
  live.worktrees[0].dirty_paths[0].sha256 = digest('e');
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a worktree status read failure cannot be represented as a clean worktree', () => {
  const { ledger, live } = fixture();
  live.worktrees[0].read_status = 'failed';
  live.worktrees[0].dirty_paths = [];
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('only an exact committed output with provenance can explain a HEAD transition', () => {
  const { ledger, live } = fixture();
  const evidencePath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json';
  const output = {
    path: evidencePath,
    producer: 'validate-closeout --mode inventory',
    source_commit: ledger.worktrees[0].head_sha,
    artifact_identity_sha256: digest('f'),
    capture_boundary: {
      captured_at: ledger.observed_at,
      worktree_path: '/repo',
      source_head_sha: ledger.worktrees[0].head_sha,
      source_path_status: 'clean',
      source_path_sha256: digest('a'),
    },
  };
  ledger.evidence_artifacts = { worktree_path: '/repo', anchor_head_sha: ledger.worktrees[0].head_sha, output_provenance: [output] };
  live.worktrees[0].head_sha = sha('e');
  live.evidence_transitions = { '/repo': { valid: true, changed_paths: [evidencePath], output_provenance: [output] } };
  const result = invoke('validateInventory', ledger, live);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  live.evidence_transitions['/repo'].changed_paths = ['scripts/unrelated.sh'];
  assert.equal(invoke('validateInventory', ledger, live).valid, false, 'unrelated committed paths cannot use the output transition');
});

test('the live evidence-transition probe verifies exact output bytes and refuses later unrelated commits', t => {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-closeout-transition-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q');
  git('config', 'user.name', 'Closeout Fixture');
  git('config', 'user.email', 'closeout-fixture@example.invalid');
  const evidencePath = '.planning/phases/249/249-CLOSEOUT.json';
  fs.mkdirSync(path.dirname(path.join(repo, evidencePath)), { recursive: true });
  fs.writeFileSync(path.join(repo, evidencePath), '{"baseline":true}\n');
  git('add', evidencePath);
  git('commit', '-m', 'anchor');
  const anchor = git('rev-parse', 'HEAD');
  const output = {
    path: evidencePath,
    producer: 'validate-closeout --mode inventory',
    source_commit: anchor,
    artifact_identity_sha256: null,
    capture_boundary: {
      captured_at: '2026-10-09T12:00:00.000Z',
      worktree_path: repo,
      source_head_sha: anchor,
      source_path_status: 'clean',
      source_path_sha256: createHash('sha256').update(fs.readFileSync(path.join(repo, evidencePath))).digest('hex'),
    },
  };
  const artifact = { evidence_artifacts: { worktree_path: repo, anchor_head_sha: anchor, output_provenance: [output] }, captured: true };
  output.artifact_identity_sha256 = invoke('artifactIdentitySha256', artifact);
  fs.writeFileSync(path.join(repo, evidencePath), `${JSON.stringify(artifact, null, 2)}\n`);
  git('add', evidencePath);
  git('commit', '-m', 'capture inventory evidence');
  const allowedHead = git('rev-parse', 'HEAD');
  const allowed = invoke('evidenceTransition', repo, anchor, allowedHead, [output]);
  assert.equal(allowed.valid, true, JSON.stringify(allowed));
  assert.deepEqual(allowed.changed_paths, [evidencePath]);
  fs.writeFileSync(path.join(repo, 'unrelated.txt'), 'not allowed\n');
  git('add', 'unrelated.txt');
  git('commit', '-m', 'unrelated change');
  const unrelatedHead = git('rev-parse', 'HEAD');
  const rejected = invoke('evidenceTransition', repo, anchor, unrelatedHead, [output]);
  assert.equal(rejected.valid, false);
  output.artifact_identity_sha256 = digest('f');
  assert.equal(invoke('evidenceTransition', repo, anchor, allowedHead, [output]).valid, false);
});

test('a later dirty declared output still blocks preservation and terminal cleanliness', () => {
  const { ledger, live } = fixture();
  const outputPath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-08-SUMMARY.md';
  const row = {
    path: outputPath,
    status: '??',
    content_state: 'regular-file',
    sha256: digest('f'),
    preservation: {
      owner: 'Phase 249',
      target: 'refs/phase-249-preservation/fixture',
      action: 'Preserve exact phase output bytes.',
      state: 'preserved',
      reason: 'Fixture verifies that output bytes remain visible to terminal checks.',
      source: 'Synthetic raw porcelain row.',
      ref: 'refs/phase-249-preservation/fixture',
      object_sha: sha('e'),
      paths: [{ path: outputPath, status: '??', content_state: 'regular-file', sha256: digest('f') }],
    },
  };
  ledger.worktrees[0].dirty_paths = [row];
  ledger.worktrees[0].inherited_dirty_paths = [row];
  ledger.evidence_artifacts = {
    worktree_path: '/repo',
    anchor_head_sha: ledger.worktrees[0].head_sha,
    output_provenance: [{
      path: outputPath,
      producer: 'gsd-executor',
      source_commit: ledger.worktrees[0].head_sha,
      artifact_identity_sha256: digest('f'),
      capture_boundary: {
        captured_at: ledger.observed_at,
        worktree_path: '/repo',
        source_head_sha: ledger.worktrees[0].head_sha,
        source_path_status: 'clean',
        source_path_sha256: null,
      },
    }],
  };
  live.worktrees[0].dirty_paths = structuredClone(ledger.worktrees[0].dirty_paths);
  const result = invoke('validatePreservation', ledger, live, { repoRoot: '/repo' });
  assert.ok(result.errors.some(error => error.code === 'preservation_source_not_clean'));
});

function finalProofFixture() {
  const mainSha = sha('d');
  const packageSourceSha = sha('a');
  const receipt = {
    schema: 1,
    package: 'sigra',
    version: '1.6.0',
    tag: 'v1.6.0',
    package_source_sha: packageSourceSha,
    package_source_ci: {
      run_id: '37875238741',
      attempt: 2,
      head_sha: packageSourceSha,
      workflow: '.github/workflows/ci.yml',
      ci_gate_job_id: '113654406257',
      ci_gate_conclusion: 'success',
    },
    hex: {
      package_url: 'https://hex.pm/packages/sigra/1.6.0',
      release_api_url: 'https://hex.pm/api/packages/sigra/releases/1.6.0',
      checksum: digest('b'),
    },
    versioned_docs_url: 'https://sigra.hexdocs.pm/1.6.0/Sigra.html',
    source_reference: {
      href: 'https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1',
      resolved_tag: 'v1.6.0',
      resolved_commit_sha: packageSourceSha,
      path: 'lib/sigra.ex',
      content_blob_sha: sha('c'),
    },
  };
  const receiptSha256 = digest('e');
  const receiptBlobSha = sha('f');
  const promotion = {
    schema_version: 1,
    verdict: 'promoted',
    pr: { number: 349, url: 'https://github.com/szTheory/sigra/pull/349' },
    head_sha: sha('1'),
    base_sha: sha('2'),
    changed_paths: ['.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json'],
    review: { result: 'approved', commit_sha: sha('1') },
    required_ci: { check_name: 'ci-gate', conclusion: 'success', head_sha: sha('1'), run_id: '400', attempt: 1, job_id: '401' },
    merge: { merged: true, merge_sha: mainSha },
    release_receipt: {
      path: '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json',
      sha256: receiptSha256,
      version: receipt.version,
      package_source_sha: packageSourceSha,
      package_source_ci: receipt.package_source_ci,
    },
  };
  const liveMain = {
    observed_at: '2026-10-09T14:00:00.000Z',
    current_main_sha: mainSha,
    promotion_merge_on_main: true,
    receipt: {
      path: promotion.release_receipt.path,
      exists: true,
      blob_sha: receiptBlobSha,
      sha256: receiptSha256,
      value: structuredClone(receipt),
    },
    ci: {
      workflow: '.github/workflows/ci.yml',
      status: 'completed',
      conclusion: 'success',
      head_sha: mainSha,
      run_id: '500',
      attempt: 1,
      url: 'https://github.com/szTheory/sigra/actions/runs/500',
      ci_gate: {
        name: 'ci-gate',
        job_id: '501',
        status: 'completed',
        conclusion: 'success',
        head_sha: mainSha,
        url: 'https://github.com/szTheory/sigra/actions/runs/500/job/501',
      },
    },
  };
  const publicProof = {
    schema: 1,
    package: 'sigra',
    version: receipt.version,
    tag: receipt.tag,
    package_source_sha: receipt.package_source_sha,
    package_source_ci: structuredClone(receipt.package_source_ci),
    hex: structuredClone(receipt.hex),
    versioned_docs_url: receipt.versioned_docs_url,
    source_reference: structuredClone(receipt.source_reference),
    verdict: 'passed',
  };
  const { ledger, live } = fixture();
  ledger.worktrees[0].dirty_paths = [];
  ledger.pull_requests = [];
  live.worktrees[0].dirty_paths = [];
  live.pull_requests = [];
  const proofInputs = {
    receipt,
    receipt_sha256: receiptSha256,
    receipt_blob_sha: receiptBlobSha,
    promotion,
    live_main: liveMain,
    public_proof: publicProof,
    ledger,
    live_inventory: live,
    live_main_sha: mainSha,
    main_proof: {
      schema_version: 1,
      protected_main_sha: mainSha,
      receipt_blob_sha: receiptBlobSha,
      verdict: 'passed',
    },
    repo_root: os.tmpdir(),
  };
  return { ...proofInputs, mainSha, packageSourceSha };
}

test('post-merge proof requires the completed ci-gate run to match protected main exactly', () => {
  const proof = finalProofFixture();
  const result = invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  });
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  proof.live_main.ci.head_sha = sha('9');
  assert.ok(invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  }).errors.some(error => error.code === 'final_main_ci_head_mismatch'));
});

test('a successful workflow with a failed or missing ci-gate does not prove final main', () => {
  const proof = finalProofFixture();
  proof.live_main.ci.ci_gate.conclusion = 'failure';
  let result = invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  });
  assert.ok(result.errors.some(error => error.code === 'final_main_ci_gate_invalid'));
  proof.live_main.ci.ci_gate = null;
  result = invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  });
  assert.ok(result.errors.some(error => error.code === 'final_main_ci_gate_invalid'));
});

test('missing receipt on protected main blocks post-merge proof', () => {
  const proof = finalProofFixture();
  proof.live_main.receipt = { path: proof.promotion.release_receipt.path, exists: false };
  const result = invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  });
  assert.ok(result.errors.some(error => error.code === 'final_main_receipt_missing'));
});

test('the package-source identity cannot be replaced by the later protected-main SHA', () => {
  const proof = finalProofFixture();
  proof.live_main.receipt.value.package_source_sha = proof.mainSha;
  const result = invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  });
  assert.ok(result.errors.some(error => error.code === 'final_main_receipt_identity_mismatch'));
});

test('an open promotion record without a protected merge remains blocked even if main has unrelated green CI', () => {
  const proof = finalProofFixture();
  proof.promotion.verdict = 'blocked';
  proof.promotion.merge = null;
  const result = invoke('validatePostMerge', proof.promotion, proof.receipt, proof.live_main, {
    receipt_sha256: proof.receipt_sha256,
    receipt_blob_sha: proof.receipt_blob_sha,
  });
  assert.ok(result.errors.some(error => error.code === 'promotion_not_merged'));
});

test('final acceptance requires a source-backed disposition for every newly open PR', () => {
  const proof = finalProofFixture();
  proof.ledger.pull_requests = [structuredClone(fixture().ledger.pull_requests[0])];
  proof.live_inventory.pull_requests = structuredClone(proof.ledger.pull_requests);
  proof.ledger.pull_requests[0].disposition = null;
  proof.live_inventory.pull_requests[0].disposition = null;
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'pr_disposition_missing'));
});

test('final acceptance blocks when an empty PR inventory was captured from a failed query', () => {
  const proof = finalProofFixture();
  proof.ledger.source_status.pull_requests = { status: 'failed', pagination_complete: false };
  proof.live_inventory.source_status.pull_requests = { status: 'failed', pagination_complete: false };
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'ledger_pull_requests_incomplete'));
});

test('final acceptance blocks a newly dirty worktree path', () => {
  const proof = finalProofFixture();
  proof.live_inventory.worktrees[0].dirty_paths.push({ path: 'notes/new.md', status: '??', content_state: 'regular-file', sha256: digest('9') });
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'dirty_path_population_mismatch'));
});

test('final acceptance blocks changed bytes behind a declared preservation ref', t => {
  const preserved = preservedFixture(t);
  const proof = finalProofFixture();
  proof.ledger = preserved.ledger;
  proof.live_inventory = preserved.live;
  proof.repo_root = preserved.repo;
  proof.ledger.worktrees[0].dirty_paths[0].preservation.paths[0].sha256 = digest('9');
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'preservation_content_mismatch'));
});

test('final acceptance compares the live public source destination with the committed receipt', () => {
  const proof = finalProofFixture();
  proof.public_proof.source_reference.href = 'https://github.com/sztheory/sigra/blob/v1.6.0/README.md';
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'public_source_identity_mismatch'));
});

test('final acceptance rejects an advanced protected main head without refreshed exact-head proof', () => {
  const proof = finalProofFixture();
  proof.live_main_sha = sha('8');
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'final_main_advanced'));
});

test('complete exact public, protected-main and clean-inventory evidence passes final acceptance', () => {
  const proof = finalProofFixture();
  const result = invoke('validateFinalAcceptance', proof);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  assert.equal(result.verdict, 'passed');
});

test('final acceptance requires the durable post-merge proof artifact', () => {
  const proof = finalProofFixture();
  proof.main_proof = null;
  const result = invoke('validateFinalAcceptance', proof);
  assert.ok(result.errors.some(error => error.code === 'final_main_proof_missing'));
});

test('the inventory fingerprint includes every raw worktree status row, including evidence outputs', () => {
  const { ledger, live } = fixture();
  const evidencePath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json';
  ledger.evidence_artifacts = { worktree_path: '/repo', anchor_head_sha: ledger.worktrees[0].head_sha, paths: [evidencePath] };
  const initial = invoke('inventoryFingerprint', ledger, live);
  live.worktrees[0].dirty_paths.push({ path: evidencePath, status: ' M', content_state: 'regular-file', sha256: digest('f') });
  assert.notEqual(invoke('inventoryFingerprint', ledger, live), initial);
  live.worktrees[0].dirty_paths.push({ path: 'notes/new.md', status: '??', content_state: 'regular-file', sha256: digest('9') });
  assert.notEqual(invoke('inventoryFingerprint', ledger, live), initial);
});

test('stable ordering is independent of API and worktree enumeration order', () => {
  const { ledger } = fixture();
  ledger.worktrees.push({ ...structuredClone(ledger.worktrees[0]), path: '/other' });
  ledger.pull_requests.push({ ...structuredClone(ledger.pull_requests[0]), number: 219 });
  const sorted = invoke('sortLedger', ledger);
  assert.deepEqual(sorted.worktrees.map(row => row.path), ['/other', '/repo']);
  assert.deepEqual(sorted.pull_requests.map(row => row.number), [219, 302]);
});

test('capture records exact closeout provenance only from a clean output-path boundary', t => {
  const { repo, ghPath, closeoutPath } = captureFixture(t);
  const ledger = withGhStub(ghPath, () => invoke('captureLedger', { repoRoot: repo }));
  const root = ledger.worktrees.find(row => row.path === fs.realpathSync(repo));
  assert.equal(ledger.inventory_status, 'complete');
  assert.deepEqual(ledger.evidence_artifacts.collisions, []);
  assert.equal(root.dirty_paths.some(row => row.path === closeoutPath), false);
  assert.equal(ledger.evidence_artifacts.output_provenance.length, 1);
  assert.equal(ledger.evidence_artifacts.output_provenance[0].capture_boundary.source_path_status, 'clean');
  assert.equal(
    ledger.evidence_artifacts.output_provenance[0].artifact_identity_sha256,
    invoke('artifactIdentitySha256', ledger),
  );
});

test('capture inventories later verification, handoff, coverage, plan, and summary outputs as raw paths', t => {
  const { repo, ghPath } = captureFixture(t);
  const paths = [
    '249-VERIFICATION.md',
    '249-EXECUTION-HANDOFF.md',
    'COVERAGE.md',
    '249-08-PLAN.md',
    '249-08-SUMMARY.md',
  ].map(name => `.planning/phases/249-publish-and-prove-sigra-1-6-0/${name}`);
  for (const relativePath of paths) {
    fs.writeFileSync(path.join(repo, relativePath), 'later output\n');
  }
  const ledger = withGhStub(ghPath, () => invoke('captureLedger', { repoRoot: repo }));
  const root = ledger.worktrees.find(row => row.path === fs.realpathSync(repo));
  assert.deepEqual(paths, paths.filter(relativePath => root.dirty_paths.some(row => row.path === relativePath)));
  assert.equal(ledger.evidence_artifacts.output_provenance.some(output => paths.includes(output.path)), false);
});

test('a pre-dirty closeout output is recorded as inherited collision and never excluded', t => {
  const { repo, ghPath, closeoutPath } = captureFixture(t);
  fs.writeFileSync(path.join(repo, closeoutPath), '{"uncommitted":true}\n');
  const currentBytes = fs.readFileSync(path.join(repo, closeoutPath));
  const ledger = withGhStub(ghPath, () => invoke('captureLedger', { repoRoot: repo }));
  const root = ledger.worktrees.find(row => row.path === fs.realpathSync(repo));
  assert.equal(ledger.inventory_status, 'blocked');
  assert.deepEqual(ledger.evidence_artifacts.output_provenance, []);
  assert.equal(ledger.evidence_artifacts.collisions.length, 1);
  assert.equal(ledger.evidence_artifacts.collisions[0].path, closeoutPath);
  assert.ok(root.dirty_paths.some(row => row.path === closeoutPath));
  assert.deepEqual(fs.readFileSync(path.join(repo, closeoutPath)), currentBytes);
});

test('a dirty handoff is surfaced as a preserve-before-rewrite guard and capture leaves its bytes untouched', t => {
  const { repo, ghPath } = captureFixture(t);
  const handoffPath = '.planning/HANDOFF.json';
  const handoffBytes = Buffer.from('{"prior":"must remain recoverable"}\n');
  fs.writeFileSync(path.join(repo, handoffPath), handoffBytes);
  const ledger = withGhStub(ghPath, () => invoke('captureLedger', { repoRoot: repo }));
  assert.deepEqual(ledger.planning_mutation_guards, [{
    path: handoffPath,
    status: '??',
    sha256: createHash('sha256').update(handoffBytes).digest('hex'),
    before_rewrite: 'Preserve or commit these exact bytes before any update or cleanup; stop if read-back cannot be proven.',
  }]);
  assert.deepEqual(fs.readFileSync(path.join(repo, handoffPath)), handoffBytes);
});

test('a validated accepted-loss record survives a refreshed read-only inventory', t => {
  const { repo, ghPath } = captureFixture(t);
  const { ledger: prior } = acceptedHandoffLossFixture();
  const refreshed = withGhStub(ghPath, () => invoke('captureLedger', { repoRoot: repo, previousLedgerInput: prior }));
  assert.deepEqual(refreshed.accepted_loss_exceptions, prior.accepted_loss_exceptions);
});

test('each dirty path needs an explicit preservation decision and exact hash', () => {
  const { ledger } = fixture();
  ledger.worktrees[0].dirty_paths[0].preservation = {
    owner: 'inherited shared checkout; author unresolved',
    target: '/repo (preserve in place)',
    action: 'Leave untouched until a scoped preservation ref is verified.',
    state: 'blocked',
    reason: 'The shared checkout contains inherited changes with unresolved individual ownership.',
    source: 'git status porcelain and SHA-256 inventory captured for this worktree path.',
  };
  const result = invoke('validateDispositions', ledger);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  assert.equal(result.blocked, true);
});

test('an unclassified PR fails disposition validation', () => {
  const { ledger } = fixture();
  delete ledger.pull_requests[0].disposition;
  assert.equal(invoke('validateDispositions', ledger).valid, false);
});

test('a dirty path with no preservation record fails disposition validation', () => {
  const { ledger } = fixture();
  assert.equal(invoke('validateDispositions', ledger).valid, false);
});
