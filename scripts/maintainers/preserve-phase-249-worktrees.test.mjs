import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

import { preservePath } from './preserve-phase-249-worktrees.mjs';

function fixture(t) {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-phase-249-preserve-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  const status = relativePath => execFileSync('git', ['status', '--porcelain=v1', '--', relativePath], { cwd: repo, encoding: 'utf8' }).replace(/\n$/, '');
  git('init', '-q', '--initial-branch=main');
  git('config', 'user.name', 'Phase 249 Fixture');
  git('config', 'user.email', 'phase-249-fixture@example.invalid');
  fs.mkdirSync(path.join(repo, 'notes'));
  fs.writeFileSync(path.join(repo, 'notes/change.md'), 'baseline\n');
  fs.writeFileSync(path.join(repo, 'anchor.txt'), 'anchor\n');
  git('add', 'notes/change.md', 'anchor.txt');
  git('commit', '-m', 'fixture baseline');
  return { repo, git, status };
}

function digest(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function preservationRow(repo, contents = Buffer.from('inherited change\n')) {
  const relativePath = 'notes/change.md';
  fs.writeFileSync(path.join(repo, relativePath), contents);
  return {
    path: relativePath,
    status: ' M',
    content_state: 'regular-file',
    sha256: digest(contents),
  };
}

const details = ref => ({
  owner: 'Phase 249 preservation fixture',
  target: ref,
  action: 'Pin the exact path under a local preservation ref, verify it, then clean only that path.',
  reason: 'The fixture verifies recoverability before source cleanup.',
  source: 'Disposable Git worktree fixture with exact status and SHA-256 captured before the call.',
});

test('pins and reads back exact bytes before cleaning only the selected tracked path', t => {
  const { repo, git, status } = fixture(t);
  const row = preservationRow(repo);
  const expectedHead = git('rev-parse', 'HEAD');
  const expectedBranch = git('branch', '--show-current');
  const expectedIndexTree = git('write-tree');
  fs.writeFileSync(path.join(repo, 'notes/leave-alone.md'), 'another inherited path\n');
  const ref = 'refs/phase-249-preservation/fixture-tracked';

  const proof = preservePath({
    repoRoot: repo,
    worktreePath: repo,
    row,
    expectedHead,
    ...details(ref),
    ref,
  });

  assert.equal(proof.state, 'preserved');
  assert.equal(proof.source_head_sha, expectedHead);
  assert.equal(proof.ref, ref);
  assert.equal(git('rev-parse', `${ref}^{commit}`), proof.object_sha);
  assert.equal(git('show', `${ref}:notes/change.md`), 'inherited change');
  assert.equal(status('notes/change.md'), '');
  assert.equal(status('notes/leave-alone.md'), '?? notes/leave-alone.md');
  assert.equal(git('rev-parse', 'HEAD'), expectedHead);
  assert.equal(git('branch', '--show-current'), expectedBranch);
  assert.equal(git('write-tree'), expectedIndexTree);
  assert.deepEqual(proof.paths, [{
    path: 'notes/change.md',
    status: ' M',
    content_state: 'regular-file',
    sha256: row.sha256,
  }]);
});

test('hash drift blocks before a ref is written or the source path is changed', t => {
  const { repo, git, status } = fixture(t);
  const row = preservationRow(repo);
  const pathOnDisk = path.join(repo, row.path);
  fs.writeFileSync(pathOnDisk, 'concurrent replacement\n');
  const before = fs.readFileSync(pathOnDisk);
  const ref = 'refs/phase-249-preservation/fixture-hash-drift';

  assert.throws(() => preservePath({ repoRoot: repo, worktreePath: repo, row, expectedHead: git('rev-parse', 'HEAD'), ...details(ref), ref }), /hash|drift/i);

  assert.deepEqual(fs.readFileSync(pathOnDisk), before);
  assert.throws(() => git('rev-parse', '--verify', ref));
  assert.equal(status(row.path), ' M notes/change.md');
});

test('an existing ref with different recovered bytes blocks without overwriting either source or ref', t => {
  const { repo, git, status } = fixture(t);
  const base = git('rev-parse', 'HEAD');
  fs.writeFileSync(path.join(repo, 'notes/change.md'), 'different ref bytes\n');
  git('add', 'notes/change.md');
  git('commit', '-m', 'existing preservation object');
  const existing = git('rev-parse', 'HEAD');
  const ref = 'refs/phase-249-preservation/fixture-collision';
  git('update-ref', ref, existing);
  git('reset', '--hard', base);
  const row = preservationRow(repo, Buffer.from('new source bytes\n'));
  const sourceBytes = fs.readFileSync(path.join(repo, row.path));

  assert.throws(() => preservePath({ repoRoot: repo, worktreePath: repo, row, expectedHead: base, ...details(ref), ref }), /ref.*collision|collision/i);

  assert.deepEqual(fs.readFileSync(path.join(repo, row.path)), sourceBytes);
  assert.equal(git('rev-parse', `${ref}^{commit}`), existing);
  assert.equal(git('show', `${ref}:notes/change.md`), 'different ref bytes');
  assert.equal(status(row.path), ' M notes/change.md');
});
