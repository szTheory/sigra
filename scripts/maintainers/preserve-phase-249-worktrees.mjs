import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const REF_PREFIX = 'refs/phase-249-preservation/';
const SHA = /^[0-9a-f]{40}$/;
const DIGEST = /^[0-9a-f]{64}$/;

function git(worktreePath, args, { env = process.env, input, encoding = 'buffer' } = {}) {
  return execFileSync('git', ['-C', worktreePath, ...args], {
    cwd: worktreePath,
    env,
    input,
    encoding,
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 64 * 1024 * 1024,
  });
}

function gitText(worktreePath, args, options = {}) {
  return git(worktreePath, args, { ...options, encoding: 'utf8' }).trimEnd();
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function parseStatus(buffer) {
  const fields = buffer.toString('utf8').split('\0');
  const rows = [];
  for (let index = 0; index < fields.length; index += 1) {
    const value = fields[index];
    if (!value) continue;
    const status = value.slice(0, 2);
    const row = { status, path: value.slice(3), original_path: null };
    if (status.includes('R') || status.includes('C')) row.original_path = fields[++index] ?? null;
    rows.push(row);
  }
  return rows;
}

function inside(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function assertSafeRelativePath(relativePath, root) {
  if (typeof relativePath !== 'string' || !relativePath || path.isAbsolute(relativePath) || relativePath.includes('\0')) {
    throw new Error('preservation path must be one non-empty worktree-relative path');
  }
  const absolutePath = path.resolve(root, relativePath);
  if (!inside(root, absolutePath)) throw new Error('preservation path escapes its source worktree');
  const parent = path.dirname(absolutePath);
  let realParent;
  try {
    realParent = fs.realpathSync(parent);
  } catch {
    throw new Error('preservation path parent cannot be read');
  }
  if (!inside(root, realParent)) throw new Error('preservation path resolves outside its source worktree');
  return absolutePath;
}

function sourceSnapshot(worktreePath, row) {
  const absolutePath = assertSafeRelativePath(row.path, worktreePath);
  let stat;
  let bytes = null;
  let contentState = 'deleted';
  try {
    stat = fs.lstatSync(absolutePath);
    if (stat.isSymbolicLink()) throw new Error('symlink preservation is unsupported; source path left untouched');
    if (!stat.isFile()) throw new Error('non-regular preservation path is unsupported; source path left untouched');
    bytes = fs.readFileSync(absolutePath);
    contentState = 'regular-file';
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  if (row.content_state && row.content_state !== contentState) {
    throw new Error(`source content state drift for ${row.path}`);
  }
  const digest = bytes === null ? null : sha256(bytes);
  if (row.sha256 !== digest) throw new Error(`source hash drift for ${row.path}`);
  return { absolutePath, bytes, stat, contentState, sha256: digest };
}

function scanSensitiveContent(bytes, relativePath) {
  if (!bytes) return;
  if (bytes.includes(0) || !Buffer.from(bytes.toString('utf8'), 'utf8').equals(bytes)) {
    throw new Error(`secret scan cannot safely inspect binary path ${relativePath}; source path left untouched`);
  }
  const text = bytes.toString('utf8');
  const checks = [
    ['private-key', /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/],
    ['github-token', /\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/],
    ['aws-access-key', /\bAKIA[0-9A-Z]{16}\b/],
    ['credential-assignment', /\b(?:secret_access_key|client_secret|access_token|api_key|private_key)\b\s*[:=]\s*["']?(?!<|\{\{|example|test|dummy|redacted)[A-Za-z0-9/+_=-]{24,}/i],
  ];
  for (const [rule, pattern] of checks) {
    if (pattern.test(text)) throw new Error(`secret-risk rule ${rule} matched ${relativePath}; source path left untouched`);
  }
}

function expectedStatusRow(worktreePath, expected) {
  const rows = parseStatus(git(worktreePath, ['status', '--porcelain=v1', '-z', '-uall']));
  const exact = rows.filter(row => row.path === expected.path);
  if (exact.length !== 1) throw new Error(`expected exactly one current status row for ${expected.path}`);
  const actual = exact[0];
  if (actual.status !== expected.status || (actual.original_path ?? null) !== (expected.original_path ?? null)) {
    throw new Error(`source status drift for ${expected.path}`);
  }
  return actual;
}

function classifyRow(row) {
  if (row.status === '??' && !row.original_path) return 'untracked';
  if (row.status === ' M' && !row.original_path) return 'modified';
  if (row.status === ' D' && !row.original_path) return 'deleted';
  throw new Error(`unsupported status ${JSON.stringify(row.status)} for ${row.path}; source path left untouched`);
}

function validateRef(ref) {
  if (typeof ref !== 'string' || !ref.startsWith(REF_PREFIX) || ref.includes('..') || !/^refs\/phase-249-preservation\/[A-Za-z0-9._/-]+$/.test(ref)) {
    throw new Error('preservation ref must be a safe refs/phase-249-preservation/* name');
  }
}

function tryResolveRef(worktreePath, ref) {
  try {
    return gitText(worktreePath, ['rev-parse', '--verify', `${ref}^{commit}`]);
  } catch {
    return null;
  }
}

function commitParent(worktreePath, commitSha) {
  const fields = gitText(worktreePath, ['rev-list', '--parents', '-n', '1', commitSha]).split(' ');
  return fields[1] ?? null;
}

function changedPaths(worktreePath, parentSha, commitSha) {
  return git(worktreePath, ['diff-tree', '--no-commit-id', '--name-only', '--no-renames', '-r', '-z', parentSha, commitSha])
    .toString('utf8').split('\0').filter(Boolean).sort();
}

function commitPathHash(worktreePath, commitSha, relativePath) {
  try {
    const bytes = git(worktreePath, ['show', `${commitSha}:${relativePath}`]);
    return sha256(bytes);
  } catch {
    return null;
  }
}

function existingRefMatches(worktreePath, refSha, sourceHead, row, kind, contentDigest) {
  if (commitParent(worktreePath, refSha) !== sourceHead) return false;
  const expectedChangedPaths = [row.path].sort();
  if (JSON.stringify(changedPaths(worktreePath, sourceHead, refSha)) !== JSON.stringify(expectedChangedPaths)) return false;
  if (kind === 'deleted') return commitPathHash(worktreePath, refSha, row.path) === null;
  return commitPathHash(worktreePath, refSha, row.path) === contentDigest;
}

function buildPreservationCommit(worktreePath, sourceHead, row, snapshot, kind, tempIndex) {
  const env = { ...process.env, GIT_INDEX_FILE: tempIndex };
  git(worktreePath, ['read-tree', sourceHead], { env });
  if (kind === 'deleted') {
    git(worktreePath, ['update-index', '--force-remove', '--', row.path], { env });
  } else {
    const blobSha = gitText(worktreePath, ['hash-object', '-w', '--stdin'], { input: snapshot.bytes });
    const mode = (snapshot.stat.mode & 0o111) === 0 ? '100644' : '100755';
    git(worktreePath, ['update-index', '--add', '--cacheinfo', mode, blobSha, row.path], { env });
  }
  const treeSha = gitText(worktreePath, ['write-tree'], { env });
  const message = [
    `Preserve Phase 249 path: ${row.path}`,
    '',
    `Source-Head: ${sourceHead}`,
    `Source-Status: ${row.status}`,
    `Content-SHA256: ${snapshot.sha256 ?? 'deleted'}`,
  ].join('\n');
  return gitText(worktreePath, ['commit-tree', treeSha, '-p', sourceHead, '-F', '-'], { input: Buffer.from(message) });
}

function verifyPinnedObject(worktreePath, ref, objectSha, sourceHead, row, kind, snapshot) {
  const resolved = gitText(worktreePath, ['rev-parse', '--verify', `${ref}^{commit}`]);
  if (resolved !== objectSha) throw new Error(`pinned preservation ref changed before read-back: ${ref}`);
  if (commitParent(worktreePath, resolved) !== sourceHead) throw new Error(`preservation ref ${ref} has an unexpected source parent`);
  if (JSON.stringify(changedPaths(worktreePath, sourceHead, resolved)) !== JSON.stringify([row.path])) {
    throw new Error(`preservation ref ${ref} does not contain the exact path set`);
  }
  if (kind === 'deleted') {
    if (commitPathHash(worktreePath, resolved, row.path) !== null) throw new Error(`preservation ref ${ref} did not preserve the deletion`);
    if (!commitPathHash(worktreePath, sourceHead, row.path)) throw new Error(`deleted source ${row.path} cannot be reconstructed from its parent`);
  } else if (commitPathHash(worktreePath, resolved, row.path) !== snapshot.sha256) {
    throw new Error(`preservation ref ${ref} cannot recover exact bytes for ${row.path}`);
  }
}

function cleanExactSourcePath(worktreePath, row, kind, snapshot) {
  expectedStatusRow(worktreePath, row);
  const fresh = sourceSnapshot(worktreePath, row);
  if (fresh.sha256 !== snapshot.sha256) throw new Error(`source hash changed immediately before cleanup for ${row.path}`);
  if (kind === 'untracked') {
    fs.unlinkSync(fresh.absolutePath);
  } else {
    git(worktreePath, ['restore', '--worktree', '--source=HEAD', '--', row.path]);
  }
  const remaining = parseStatus(git(worktreePath, ['status', '--porcelain=v1', '-z', '-uall']))
    .filter(value => value.path === row.path || value.original_path === row.path);
  if (remaining.length > 0) throw new Error(`source path ${row.path} remains dirty after exact cleanup`);
}

/**
 * Pin one source path under a compare-and-swap ref, read the object back, and
 * only then clean that same path in its original worktree.
 */
export function preservePath({
  repoRoot,
  worktreePath,
  row,
  expectedHead,
  owner,
  target,
  action,
  reason,
  source: sourceRecord,
  ref,
}) {
  if (![owner, target, action, reason, sourceRecord].every(value => typeof value === 'string' && value.trim())) {
    throw new Error('preservation requires explicit owner, target, action, reason, and source');
  }
  if (!row || typeof row.path !== 'string' || typeof row.status !== 'string') throw new Error('one exact ledger path/status row is required');
  validateRef(ref);

  const actualRoot = path.resolve(gitText(worktreePath, ['rev-parse', '--show-toplevel']));
  const suppliedRoot = fs.realpathSync(worktreePath);
  if (actualRoot !== suppliedRoot) throw new Error('source worktree path does not resolve to its Git root');
  worktreePath = actualRoot;
  const sourceHead = gitText(worktreePath, ['rev-parse', 'HEAD']);
  if (!SHA.test(sourceHead)) throw new Error('source HEAD is not a full commit identity');
  if (!SHA.test(expectedHead ?? '') || sourceHead !== expectedHead) throw new Error(`source HEAD drift for ${row.path}`);
  if (repoRoot) {
    const commonDir = directory => {
      const value = gitText(directory, ['rev-parse', '--git-common-dir']);
      return fs.realpathSync(path.resolve(directory, value));
    };
    if (commonDir(repoRoot) !== commonDir(worktreePath)) throw new Error('source worktree belongs to a different Git object/ref store');
  }
  expectedStatusRow(worktreePath, row);
  const kind = classifyRow(row);
  if (row.status !== '??' && row.status[0] !== ' ') throw new Error(`staged or conflicted status is unsupported for ${row.path}`);
  const indexBefore = gitText(worktreePath, ['write-tree']);
  const snapshot = sourceSnapshot(worktreePath, row);
  if (kind === 'deleted' && snapshot.contentState !== 'deleted') throw new Error(`deleted source path ${row.path} unexpectedly exists`);
  if (kind !== 'deleted' && snapshot.contentState !== 'regular-file') throw new Error(`source path ${row.path} is not a regular file`);
  scanSensitiveContent(snapshot.bytes, row.path);

  const oldObject = tryResolveRef(worktreePath, ref);
  let objectSha;
  let created = false;
  const tempIndex = path.join(os.tmpdir(), `phase-249-preservation-${process.pid}-${randomUUID()}.index`);
  try {
    if (oldObject) {
      if (!existingRefMatches(worktreePath, oldObject, sourceHead, row, kind, snapshot.sha256)) {
        throw new Error(`preservation ref collision at ${ref}; existing bytes differ and remain recoverable`);
      }
      objectSha = oldObject;
    } else {
      objectSha = buildPreservationCommit(worktreePath, sourceHead, row, snapshot, kind, tempIndex);
      const zero = '0'.repeat(40);
      try {
        git(worktreePath, ['update-ref', ref, objectSha, zero]);
        created = true;
      } catch {
        const racedObject = tryResolveRef(worktreePath, ref);
        if (!racedObject || !existingRefMatches(worktreePath, racedObject, sourceHead, row, kind, snapshot.sha256)) {
          throw new Error(`preservation ref compare-and-swap collision at ${ref}; source path left untouched`);
        }
        objectSha = racedObject;
      }
    }

    verifyPinnedObject(worktreePath, ref, objectSha, sourceHead, row, kind, snapshot);
    expectedStatusRow(worktreePath, row);
    const second = sourceSnapshot(worktreePath, row);
    if (second.sha256 !== snapshot.sha256 || gitText(worktreePath, ['rev-parse', 'HEAD']) !== sourceHead) {
      throw new Error(`source changed after ref verification for ${row.path}; source path left untouched`);
    }
    if (gitText(worktreePath, ['write-tree']) !== indexBefore) throw new Error('source index changed during preservation; source path left untouched');

    cleanExactSourcePath(worktreePath, row, kind, snapshot);
    if (gitText(worktreePath, ['rev-parse', 'HEAD']) !== sourceHead) throw new Error('source branch HEAD changed during exact cleanup');
    if (gitText(worktreePath, ['write-tree']) !== indexBefore) throw new Error('source index changed during exact cleanup');

    return {
      schema_version: 1,
      state: 'preserved',
      owner,
      target,
      action,
      reason,
      source_record: sourceRecord,
      worktree_path: actualRoot,
      source_head_sha: sourceHead,
      source_status: row.status,
      source_path: row.path,
      source_content_state: snapshot.contentState,
      source_sha256: snapshot.sha256,
      ref,
      object_sha: objectSha,
      ref_created: created,
      paths: [{ path: row.path, status: row.status, content_state: snapshot.contentState, sha256: snapshot.sha256 }],
      source_clean_after_readback: true,
      source_head_unchanged: true,
      source_index_unchanged: true,
    };
  } finally {
    for (const suffix of ['', '.lock']) {
      try { fs.unlinkSync(`${tempIndex}${suffix}`); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
  }
}

function parseArgs(args) {
  const values = {};
  for (let index = 0; index < args.length; index += 1) {
    const key = args[index];
    if (!key.startsWith('--') || index + 1 >= args.length) throw new Error(`invalid argument near ${key}`);
    values[key.slice(2)] = args[++index];
  }
  return values;
}

function cliRef(worktreePath, relativePath) {
  const key = sha256(Buffer.from(`${path.resolve(worktreePath)}\0${relativePath}`)).slice(0, 32);
  return `${REF_PREFIX}${key}`;
}

async function main() {
  const values = parseArgs(process.argv.slice(2));
  for (const name of ['ledger', 'worktree', 'path', 'owner', 'target', 'action', 'reason', 'source']) {
    if (!values[name]) throw new Error(`--${name} is required`);
  }
  const ledgerPath = path.resolve(values.ledger);
  const ledger = JSON.parse(fs.readFileSync(ledgerPath, 'utf8'));
  const worktree = (ledger.worktrees ?? []).find(row => path.resolve(row.path) === fs.realpathSync(values.worktree));
  if (!worktree) throw new Error(`worktree is not registered in ${ledgerPath}`);
  const row = (worktree.inherited_dirty_paths ?? worktree.dirty_paths ?? []).find(value => value.path === values.path);
  if (!row) throw new Error(`exact path ${values.path} is absent from the ledger for ${worktree.path}`);
  const ref = values.ref ?? cliRef(values.worktree, row.path);
  const proof = preservePath({
    repoRoot: values.repoRoot ?? ledger.evidence_artifacts?.worktree_path ?? process.cwd(),
    worktreePath: worktree.path,
    expectedHead: worktree.head_sha,
    row,
    owner: values.owner,
    target: values.target,
    action: values.action,
    reason: values.reason,
    source: values.source,
    ref,
  });
  process.stdout.write(`${JSON.stringify(proof, null, 2)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    process.stderr.write(`preserve-phase-249-worktrees: ${error.message}\n`);
    process.exitCode = 1;
  });
}
