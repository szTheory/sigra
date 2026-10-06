import test from 'node:test';
import assert from 'node:assert/strict';
import { validateSnapshot } from './validate-release-readiness.mjs';

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
