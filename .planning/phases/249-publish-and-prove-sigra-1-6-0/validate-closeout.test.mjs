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
    pr: { number: 349, url: 'https://github.com/szTheory/sigra/pull/349' },
    head_sha: headSha,
    base_sha: baseSha,
    changed_paths: ['scripts/ci/release-public-proof.sh'],
    review: { result: 'approved', commit_sha: headSha },
    required_ci: { check_name: 'ci-gate', conclusion: 'success', head_sha: headSha, run_id: '400', attempt: 1, job_id: '401' },
    merge: { merged: true, merge_sha: sha('d') },
    release_receipt: {
      path: '249-RELEASE-RECEIPT.json',
      sha256: digest('e'),
      version: receipt.version,
      package_source_sha: receipt.package_source_sha,
      package_source_ci: receipt.package_source_ci,
    },
  };
  const constraints = {
    expected_head_sha: headSha,
    expected_base_sha: baseSha,
    allowed_paths: ['scripts/ci/release-public-proof.sh'],
    release_receipt: receipt,
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

test('declared phase evidence outputs do not masquerade as newly inherited dirty paths', () => {
  const { ledger, live } = fixture();
  const evidencePath = '.planning/249-CLOSEOUT.json';
  ledger.evidence_artifacts = { worktree_path: '/repo', anchor_head_sha: ledger.worktrees[0].head_sha, paths: [evidencePath] };
  ledger.worktrees[0].dirty_paths[0].preservation = {
    owner: 'shared inherited checkout; author unresolved',
    target: '/repo (preserve in place)',
    action: 'Leave untouched until an approved scoped ref is verified.',
    state: 'blocked',
    reason: 'The source work is shared and no exact preservation destination is approved.',
    source: 'Captured path and content hash.',
  };
  live.worktrees[0].dirty_paths.push({ path: evidencePath, status: '??', content_state: 'regular-file', sha256: digest('e') });
  const result = invoke('validatePreservation', ledger, live, { repoRoot: '/repo' });
  assert.equal(result.errors.some(error => error.code === 'preservation_new_dirty_path'), false);
});

test('an exact reviewed head, required ci-gate, receipt and scoped diff can be promoted', () => {
  const { promotion, constraints } = promotionFixture();
  const result = invoke('validatePromotion', promotion, constraints);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  assert.equal(result.blocked, false);
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

test('an exact complete inventory accepts a successful empty PR query', () => {
  const { ledger, live } = fixture();
  ledger.pull_requests = [];
  live.pull_requests = [];
  const result = invoke('validateInventory', ledger, live);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
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

test('only the declared self-evidencing output paths are excluded from inherited dirty-path comparison', () => {
  const { ledger, live } = fixture();
  ledger.evidence_artifacts = { worktree_path: '/repo', anchor_head_sha: ledger.worktrees[0].head_sha, paths: ['.planning/249-CLOSEOUT.json'] };
  live.evidence_transitions = { '/repo': { valid: true, changed_paths: [] } };
  live.worktrees[0].dirty_paths.push({
    path: '.planning/249-CLOSEOUT.json', status: '??', sha256: digest('f'), content_state: 'regular-file', original_path: null,
  });
  const result = invoke('validateInventory', ledger, live);
  assert.equal(result.valid, true, JSON.stringify(result.errors));
  live.worktrees[0].dirty_paths.push({ path: 'notes/omitted.md', status: '??', sha256: digest('a') });
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('a later HEAD is allowed only when its complete commit diff stays within self-output paths', () => {
  const { ledger, live } = fixture();
  ledger.evidence_artifacts = { worktree_path: '/repo', anchor_head_sha: ledger.worktrees[0].head_sha, paths: ['.planning/249-CLOSEOUT.json'] };
  live.worktrees[0].head_sha = sha('e');
  live.evidence_transitions = { '/repo': { valid: true, changed_paths: ['.planning/249-CLOSEOUT.json'] } };
  assert.equal(invoke('validateInventory', ledger, live).valid, true);
  live.evidence_transitions['/repo'].changed_paths = ['scripts/unrelated.sh'];
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
});

test('the live evidence-transition probe accepts only descendant commits limited to its allowlist', t => {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-closeout-transition-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q');
  git('config', 'user.name', 'Closeout Fixture');
  git('config', 'user.email', 'closeout-fixture@example.invalid');
  fs.writeFileSync(path.join(repo, 'release-proof.json'), '{}\n');
  git('add', 'release-proof.json');
  git('commit', '-m', 'anchor');
  const anchor = git('rev-parse', 'HEAD');
  fs.writeFileSync(path.join(repo, 'release-proof.json'), '{"ok":true}\n');
  git('add', 'release-proof.json');
  git('commit', '-m', 'allowed evidence output');
  const allowedHead = git('rev-parse', 'HEAD');
  const allowed = invoke('evidenceTransition', repo, anchor, allowedHead, ['release-proof.json']);
  assert.deepEqual(allowed, { valid: true, changed_paths: ['release-proof.json'] });
  fs.writeFileSync(path.join(repo, 'unrelated.txt'), 'not allowed\n');
  git('add', 'unrelated.txt');
  git('commit', '-m', 'unrelated change');
  const unrelatedHead = git('rev-parse', 'HEAD');
  const rejected = invoke('evidenceTransition', repo, anchor, unrelatedHead, ['release-proof.json']);
  assert.equal(rejected.valid, false);
  assert.deepEqual(rejected.changed_paths, ['release-proof.json', 'unrelated.txt']);
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

test('the inventory fingerprint ignores only declared self-evidence paths', () => {
  const { ledger, live } = fixture();
  const evidencePath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json';
  ledger.evidence_artifacts = { worktree_path: '/repo', anchor_head_sha: ledger.worktrees[0].head_sha, paths: [evidencePath] };
  const initial = invoke('inventoryFingerprint', ledger, live);
  live.worktrees[0].dirty_paths.push({ path: evidencePath, status: ' M', content_state: 'regular-file', sha256: digest('f') });
  assert.equal(invoke('inventoryFingerprint', ledger, live), initial);
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
