import test from 'node:test';
import assert from 'node:assert/strict';

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
    head_ref: 'release-please--branches--main',
    head_sha: sha('c'),
    url: 'https://github.com/szTheory/sigra/pull/302',
    files_read: 'complete',
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

test('a dirty path omitted from the ledger fails even if its worktree HEAD is unchanged', () => {
  const { ledger, live } = fixture();
  live.worktrees[0].dirty_paths.push({ path: 'notes/b.md', status: '??', sha256: digest('d') });
  assert.equal(invoke('validateInventory', ledger, live).valid, false);
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
