import test from 'node:test';
import assert from 'node:assert/strict';
import { validateSnapshot, validationSnapshot, validateCheckout } from './validate-release-readiness.mjs';

function emptySnapshot() {
  return {
    source: {
      trusted_main_sha: 'a'.repeat(40),
      merge_base_sha: 'b'.repeat(40),
      inherited_checkout: {
        path: '/repo',
        branch: 'release-work',
        head_sha: 'c'.repeat(40),
      },
    },
    commits: [],
    paths: [],
    pull_requests: [],
    raw_status: [],
  };
}

function emptyObservation() {
  return {
    trusted_main_sha: 'a'.repeat(40),
    merge_base_sha: 'b'.repeat(40),
    inherited_head_sha: 'c'.repeat(40),
    branch: 'release-work',
    commit_shas: [],
    committed_paths: [],
    dirty_paths: [],
    pull_requests: [],
  };
}

test('rejects an omitted live pull request', () => {
  const snapshot = emptySnapshot();
  snapshot.pull_requests = [{
    number: 42,
    head_sha: 'd'.repeat(40),
    base: 'main',
    disposition: 'separate-follow-up',
    reason: 'Independent maintenance change.',
    source: 'https://github.com/example/repo/pull/42',
    preservation_location: 'GitHub open PR #42',
  }];
  const observed = emptyObservation();
  observed.pull_requests = [];

  const result = validateSnapshot(snapshot, observed);

  assert.equal(result.valid, false);
  assert.ok(result.errors.some(error => error.code === 'pull_request_population_mismatch'));
});

test('rejects duplicate kind-plus-path identities', () => {
  const snapshot = emptySnapshot();
  const row = {
    kind: 'committed',
    path: 'lib/example.ex',
    disposition: 'release-relevant',
    reason: 'Package source needs review.',
    source: 'commit deadbeef',
    preservation_location: '/repo@release-work',
  };
  snapshot.paths = [row, { ...row }];

  const result = validateSnapshot(snapshot, emptyObservation());

  assert.equal(result.valid, false);
  assert.ok(result.errors.some(error => error.code === 'duplicate_path_key'));
});

test('accepts explicitly empty populations when fresh observations are empty', () => {
  const result = validateSnapshot(emptySnapshot(), emptyObservation());

  assert.deepEqual(result, { valid: true, errors: [] });
});

test('validates the latest additive inventory while preserving the immutable entry snapshot', () => {
  const entry = emptySnapshot();
  const current = emptySnapshot();
  current.source.trusted_main_sha = 'd'.repeat(40);
  const ledger = { entry_snapshot: entry, current_snapshot: current };

  assert.equal(validationSnapshot(ledger), current);
  assert.equal(ledger.entry_snapshot, entry);
  assert.equal(ledger.entry_snapshot.source.trusted_main_sha, 'a'.repeat(40));
});

test('accepts only a clean candidate pinned to reviewed source with exact Phase 246 evidence', () => {
  const sha = 'e'.repeat(40);
  const selection = {
    status: 'ready',
    selected_source_sha: sha,
    candidate_worktree: { path: '/repo/tmp/phase-247-candidate', head_sha: sha },
    phase_246_evidence: {
      source_sha: '90ec16f72a71d33224c0816ad77762e2e7262c76',
      required_jobs: { 'ci-gate': 'success', install_smoke: 'success', generated_admin_playwright_smoke: 'success' },
      reviewed_pr: 288,
      promotion_commit: sha,
    },
    included_paths: [
      'priv/templates/sigra.install/core/confirmation_live.ex',
      'test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex',
      'scripts/ci/generated-confirmation-probe.exs',
      'test/sigra/install/auth_ui_contract_test.exs',
    ].map(path => ({ path, reviewed_source_sha: '90ec16f72a71d33224c0816ad77762e2e7262c76', reviewed_blob_matches: true, protected_main_sha: sha, reviewed_pr: 288 })),
  };

  const observed = { exists: true, head_sha: sha, status: '', live_main_sha: sha, local_origin_main_sha: sha };
  assert.deepEqual(validateCheckout(selection, observed), { valid: true, errors: [] });
  assert.ok(validateCheckout(selection, { ...observed, head_sha: 'f'.repeat(40), status: '?? artifact' }).errors.some(error => error.code === 'candidate_worktree_head_mismatch'));
});
