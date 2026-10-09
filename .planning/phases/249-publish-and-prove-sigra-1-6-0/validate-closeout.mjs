import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const REPOSITORY = 'szTheory/sigra';
const DISPOSITIONS = new Set(['release-blocking', 'release-relevant', 'separate-follow-up']);
const PRESERVATION_STATES = new Set(['blocked', 'preserve-in-place', 'preserved']);
const SHA = /^[0-9a-f]{40}$/;
const DIGEST = /^[0-9a-f]{64}$/;
const MODULE_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_ROOT = path.resolve(MODULE_DIR, '../../..');
const SELF_ARTIFACTS = [
  '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json',
  '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-04-SUMMARY.md',
];

function run(command, args, cwd, maxBuffer = 64 * 1024 * 1024) {
  return execFileSync(command, args, { cwd, encoding: 'buffer', maxBuffer });
}

function runText(command, args, cwd, maxBuffer) {
  return run(command, args, cwd, maxBuffer).toString('utf8').trimEnd();
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function sortRows(rows, key) {
  return [...rows].sort((left, right) => {
    const a = key(left);
    const b = key(right);
    return a < b ? -1 : a > b ? 1 : 0;
  });
}

function unique(rows, key) {
  const values = rows.map(key);
  return new Set(values).size === values.length;
}

function equalList(left, right) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function statusRows(buffer, worktreePath) {
  const fields = buffer.toString('utf8').split('\0');
  const rows = [];
  for (let index = 0; index < fields.length; index += 1) {
    const item = fields[index];
    if (!item) continue;
    const status = item.slice(0, 2);
    const relativePath = item.slice(3);
    let originalPath = null;
    if (status.includes('R') || status.includes('C')) originalPath = fields[++index] ?? null;
    const resolved = path.resolve(worktreePath, relativePath);
    const relativeToRoot = path.relative(worktreePath, resolved);
    if (relativeToRoot === '..' || relativeToRoot.startsWith(`..${path.sep}`) || path.isAbsolute(relativeToRoot)) {
      throw new Error('Git status returned a path outside its worktree');
    }
    let contentState = 'regular-file';
    let contentSha256 = null;
    try {
      const stat = fs.lstatSync(resolved);
      if (stat.isSymbolicLink()) {
        contentState = 'symlink-target';
        contentSha256 = sha256(Buffer.from(fs.readlinkSync(resolved)));
      } else if (stat.isFile()) {
        contentSha256 = sha256(fs.readFileSync(resolved));
      } else {
        contentState = stat.isDirectory() ? 'directory-or-submodule' : 'non-regular-file';
      }
    } catch (error) {
      if (error.code === 'ENOENT') contentState = 'deleted';
      else throw error;
    }
    rows.push({
      path: relativePath,
      status,
      original_path: originalPath,
      content_state: contentState,
      sha256: contentSha256,
    });
  }
  return sortRows(rows, dirtyKey);
}

function dirtyKey(row) {
  return `${row.path}\0${row.status}\0${row.original_path ?? ''}\0${row.content_state ?? ''}\0${row.sha256 ?? ''}`;
}

function parseWorktrees(buffer) {
  const rows = [];
  let current = null;
  for (const field of buffer.toString('utf8').split('\0')) {
    if (field.startsWith('worktree ')) {
      if (current) rows.push(current);
      current = { path: field.slice('worktree '.length), branch: null, head_sha: null, detached: false, locked: false, prunable: false };
    } else if (current && field.startsWith('HEAD ')) {
      current.head_sha = field.slice(5);
    } else if (current && field.startsWith('branch refs/heads/')) {
      current.branch = field.slice('branch refs/heads/'.length);
    } else if (current && field === 'detached') {
      current.detached = true;
    } else if (current && field.startsWith('locked')) {
      current.locked = true;
    } else if (current && field.startsWith('prunable')) {
      current.prunable = true;
    }
  }
  if (current) rows.push(current);
  return sortRows(rows, row => row.path);
}

function liveWorktrees(repoRoot) {
  const listed = parseWorktrees(run('git', ['worktree', 'list', '--porcelain', '-z'], repoRoot));
  return listed.map(row => {
    const status = run('git', ['-C', row.path, 'status', '--porcelain=v1', '-z', '-uall'], repoRoot);
    return {
      ...row,
      read_status: 'complete',
      dirty_paths: statusRows(status, row.path),
    };
  });
}

function parsePaginatedArrays(bytes) {
  const value = JSON.parse(bytes.toString('utf8'));
  if (!Array.isArray(value)) throw new Error('Paginated GitHub response was not an array of pages');
  if (!value.every(Array.isArray)) throw new Error('A GitHub pagination page was not an array');
  return value.flat();
}

function livePullRequests(repoRoot) {
  const bytes = run('gh', ['api', '--paginate', '--slurp', `repos/${REPOSITORY}/pulls?state=open&per_page=100`], repoRoot);
  const rows = parsePaginatedArrays(bytes).map(row => ({
    number: row.number,
    title: row.title,
    base_ref: row.base?.ref,
    base_sha: row.base?.sha,
    head_ref: row.head?.ref,
    head_sha: row.head?.sha,
    url: row.html_url,
  }));
  if (rows.some(row => !Number.isInteger(row.number) || !row.base_ref || !SHA.test(row.base_sha ?? '') || !row.head_ref || !SHA.test(row.head_sha ?? '') || !row.url)) {
    throw new Error('A live open PR is missing an identity field');
  }
  if (!unique(rows, row => row.number)) throw new Error('GitHub returned duplicate open PR numbers');
  return sortRows(rows, row => String(row.number).padStart(12, '0'));
}

function liveChangedFiles(repoRoot, number) {
  const endpoint = `repos/${REPOSITORY}/pulls/${number}/files?per_page=100`;
  const rows = parsePaginatedArrays(run('gh', ['api', '--paginate', '--slurp', endpoint], repoRoot))
    .map(row => ({ path: row.filename, status: row.status }));
  if (rows.some(row => typeof row.path !== 'string' || typeof row.status !== 'string') || !unique(rows, row => row.path)) {
    throw new Error(`PR #${number} changed-file inventory is invalid`);
  }
  return { endpoint, status: 'complete', files: sortRows(rows, row => `${row.path}\0${row.status}`) };
}

function evidenceTransition(repoRoot, anchorSha, currentSha, allowedPaths) {
  if (anchorSha === currentSha) return { valid: true, changed_paths: [] };
  let ancestor = false;
  try {
    execFileSync('git', ['-C', repoRoot, 'merge-base', '--is-ancestor', anchorSha, currentSha], { stdio: 'ignore' });
    ancestor = true;
  } catch {
    ancestor = false;
  }
  const changed = run('git', ['-C', repoRoot, 'diff', '--name-only', '-z', `${anchorSha}..${currentSha}`], repoRoot).toString('utf8')
    .split('\0').filter(Boolean);
  const allowed = new Set(allowedPaths);
  return { valid: ancestor === undefined && changed.every(relativePath => allowed.has(relativePath)), changed_paths: sortRows(changed, value => value) };
}

export function sortLedger(ledger) {
  return {
    ...ledger,
    worktrees: sortRows(ledger.worktrees ?? [], row => row.path).map(row => ({
      ...row,
      dirty_paths: sortRows(row.dirty_paths ?? [], dirtyKey),
    })),
    pull_requests: sortRows(ledger.pull_requests ?? [], row => String(row.number).padStart(12, '0')).map(row => ({
      ...row,
      changed_files: sortRows(row.changed_files ?? [], file => `${file.path}\0${file.status}`),
    })),
  };
}

export function validateInventory(ledger, live) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  if (ledger?.repository !== REPOSITORY || live?.repository !== REPOSITORY) add('repository_mismatch', 'Both snapshots must identify szTheory/sigra.');
  for (const source of ['worktrees', 'pull_requests']) {
    for (const snapshotName of ['ledger', 'live']) {
      const status = snapshotName === 'ledger' ? ledger?.source_status?.[source] : live?.source_status?.[source];
      if (status?.status !== 'complete' || status?.pagination_complete !== true) {
        add(`${snapshotName}_${source}_incomplete`, `${snapshotName} ${source} read must be complete, including pagination.`);
      }
    }
  }

  const ledgerWorktrees = Array.isArray(ledger?.worktrees) ? ledger.worktrees : [];
  const liveWorktrees = Array.isArray(live?.worktrees) ? live.worktrees : [];
  for (const [name, rows] of [['ledger', ledgerWorktrees], ['live', liveWorktrees]]) {
    if (!unique(rows, row => row.path)) add(`${name}_worktree_duplicate`, `${name} worktree paths must be unique.`);
    for (const row of rows) {
      if (typeof row.path !== 'string' || !row.path || !SHA.test(row.head_sha ?? '') || row.read_status !== 'complete' || !Array.isArray(row.dirty_paths)) {
        add(`${name}_worktree_invalid`, `${name} worktrees require path, full HEAD, complete status read and dirty-path array.`);
      }
      if (!unique(row.dirty_paths ?? [], dirtyKey)) add(`${name}_dirty_path_duplicate`, `${name} dirty path identities must be unique in ${row.path}.`);
      for (const dirty of row.dirty_paths ?? []) {
        const hasDigest = DIGEST.test(dirty.sha256 ?? '');
        const hashlessState = ['deleted', 'directory-or-submodule', 'non-regular-file'].includes(dirty.content_state);
        if (!hasDigest && !(dirty.sha256 === null && hashlessState)) add(`${name}_dirty_content_hash_invalid`, `${name} dirty path ${row.path}:${dirty.path} needs a content hash or explicit hashless state.`);
      }
    }
  }
  const ledgerByPath = new Map(ledgerWorktrees.map(row => [row.path, row]));
  const liveByPath = new Map(liveWorktrees.map(row => [row.path, row]));
  if (!equalList([...ledgerByPath.keys()].sort(), [...liveByPath.keys()].sort())) add('worktree_population_mismatch', 'The exact registered worktree path set differs from the live set.');
  const evidence = ledger?.evidence_artifacts ?? {};
  if (evidence.worktree_path && (!Array.isArray(evidence.paths) || evidence.paths.length === 0 || !SHA.test(evidence.anchor_head_sha ?? ''))) {
    add('evidence_artifact_anchor_invalid', 'Self-evidencing outputs need one declared worktree, full captured anchor HEAD and exact path allowlist.');
  }
  for (const expected of ledgerWorktrees) {
    const current = liveByPath.get(expected.path);
    if (!current) continue;
    const selfWorktree = expected.path === evidence.worktree_path;
    if (expected.branch !== current.branch) add('worktree_branch_mismatch', `Worktree branch changed for ${expected.path}.`);
    if (expected.head_sha !== current.head_sha) {
      const transition = live.evidence_transitions?.[expected.path];
      const transitionPaths = Array.isArray(transition?.changed_paths) ? transition.changed_paths : [];
      if (!selfWorktree || !Array.isArray(evidence.paths) || transition?.valid !== true || transitionPaths.some(relativePath => !evidence.paths.includes(relativePath))) {
        add('worktree_head_mismatch', `Worktree HEAD changed outside the declared phase evidence transition for ${expected.path}.`);
      }
    }
    const ignored = new Set(selfWorktree ? evidence.paths ?? [] : []);
    const expectedDirty = sortRows((expected.dirty_paths ?? []).filter(row => !ignored.has(row.path)), dirtyKey).map(dirtyKey);
    const currentDirty = sortRows((current.dirty_paths ?? []).filter(row => !ignored.has(row.path)), dirtyKey).map(dirtyKey);
    if (!equalList(expectedDirty, currentDirty)) add('dirty_path_population_mismatch', `The dirty path/status/content-hash inventory changed for ${expected.path}.`);
  }

  const ledgerPRs = Array.isArray(ledger?.pull_requests) ? ledger.pull_requests : [];
  const livePRs = Array.isArray(live?.pull_requests) ? live.pull_requests : [];
  for (const [name, rows] of [['ledger', ledgerPRs], ['live', livePRs]]) {
    if (!unique(rows, row => row.number)) add(`${name}_pr_duplicate`, `${name} open PR numbers must be unique.`);
    for (const row of rows) {
      if (!Number.isInteger(row.number) || row.number < 1 || !SHA.test(row.head_sha ?? '') || !SHA.test(row.base_sha ?? '') || !row.base_ref || !row.head_ref || !row.url) {
        add(`${name}_pr_invalid`, `${name} PR rows require number, full base/head SHAs, refs and URL.`);
      }
    }
  }
  const prIdentity = row => JSON.stringify([row.number, row.title, row.base_ref, row.base_sha, row.head_ref, row.head_sha, row.url]);
  const expectedPRs = sortRows(ledgerPRs, row => String(row.number).padStart(12, '0')).map(prIdentity);
  const currentPRs = sortRows(livePRs, row => String(row.number).padStart(12, '0')).map(prIdentity);
  if (!equalList(expectedPRs, currentPRs)) add('pull_request_population_or_identity_mismatch', 'The exact current open PR identity set differs from the ledger.');
  return { valid: errors.length === 0, errors };
}

export function validateDispositions(ledger) {
  const errors = [];
  const blockers = [];
  const add = (code, message) => errors.push({ code, message });
  if (!Array.isArray(ledger?.worktrees) || !Array.isArray(ledger?.pull_requests)) {
    add('ledger_arrays_missing', 'The ledger must contain worktrees and pull_requests arrays.');
    return { valid: false, blocked: true, closeout_status: 'blocked', errors, blockers };
  }
  for (const worktree of ledger.worktrees) {
    for (const dirty of worktree.dirty_paths ?? []) {
      const record = dirty.preservation;
      if (!DIGEST.test(dirty.sha256 ?? '') && dirty.content_state !== 'deleted' && dirty.content_state !== 'directory-or-submodule' && dirty.content_state !== 'non-regular-file') {
        add('dirty_hash_missing', `Dirty path ${worktree.path}:${dirty.path} lacks a SHA-256 content identity.`);
      }
      if (!record || !['owner', 'target', 'action', 'state', 'reason', 'source'].every(key => typeof record[key] === 'string' && record[key].trim()) || !PRESERVATION_STATES.has(record.state)) {
        add('dirty_preservation_incomplete', `Dirty path ${worktree.path}:${dirty.path} lacks a complete preservation decision or blocker.`);
        continue;
      }
      if (record.state !== 'preserved') blockers.push({ worktree_path: worktree.path, path: dirty.path, state: record.state, reason: record.reason });
    }
  }
  for (const pullRequest of ledger.pull_requests) {
    const decision = pullRequest.disposition;
    if (!decision || !DISPOSITIONS.has(decision.category)) {
      add('pr_disposition_missing', `Open PR #${pullRequest.number} must have exactly one locked disposition.`);
      continue;
    }
    if (typeof decision.reason !== 'string' || !decision.reason.trim() || !Array.isArray(decision.sources) || decision.sources.length === 0 || decision.sources.some(source => typeof source !== 'string' || !source.trim())) {
      add('pr_disposition_source_missing', `Open PR #${pullRequest.number} needs a source-backed reason.`);
    }
    if (pullRequest.files_read?.status !== 'complete' || !Array.isArray(pullRequest.changed_files) || typeof pullRequest.files_read?.endpoint !== 'string') {
      add('pr_changed_files_incomplete', `Open PR #${pullRequest.number} needs a complete changed-file source read.`);
    }
    if (pullRequest.is_release_please_candidate === true && typeof decision.candidate_eligibility !== 'string') {
      add('release_please_eligibility_missing', `Release Please PR #${pullRequest.number} needs a separate eligibility statement.`);
    }
  }
  return {
    valid: errors.length === 0,
    blocked: blockers.length > 0,
    closeout_status: blockers.length ? 'blocked' : 'ready',
    errors,
    blockers,
  };
}

export function collectLiveInventory({ repoRoot = DEFAULT_ROOT, ledger = null } = {}) {
  const observedAt = new Date().toISOString();
  let worktrees = [];
  let pullRequests = [];
  const sourceStatus = {
    worktrees: { status: 'failed', pagination_complete: false, method: 'git worktree list --porcelain -z and per-worktree git status --porcelain=v1 -z -uall' },
    pull_requests: { status: 'failed', pagination_complete: false, method: 'gh api --paginate --slurp repos/szTheory/sigra/pulls?state=open&per_page=100' },
  };
  try {
    worktrees = liveWorktrees(repoRoot);
    sourceStatus.worktrees = { ...sourceStatus.worktrees, status: 'complete', pagination_complete: true, count: worktrees.length, observed_at: observedAt };
  } catch {
    sourceStatus.worktrees.read_error = 'Git worktree/status read failed; no empty-state inference is permitted.';
  }
  try {
    pullRequests = livePullRequests(repoRoot);
    sourceStatus.pull_requests = { ...sourceStatus.pull_requests, status: 'complete', pagination_complete: true, count: pullRequests.length, observed_at: observedAt };
  } catch {
    sourceStatus.pull_requests.read_error = 'GitHub open-PR pagination failed; no empty-queue inference is permitted.';
  }
  const evidenceTransitions = {};
  if (ledger?.evidence_artifacts?.worktree_path && Array.isArray(ledger.evidence_artifacts.paths)) {
    const anchor = ledger.worktrees?.find(row => row.path === ledger.evidence_artifacts.worktree_path);
    const current = worktrees.find(row => row.path === ledger.evidence_artifacts.worktree_path);
    if (anchor && current) {
      try {
        evidenceTransitions[current.path] = evidenceTransition(repoRoot, anchor.head_sha, current.head_sha, ledger.evidence_artifacts.paths);
      } catch {
        evidenceTransitions[current.path] = { valid: false, changed_paths: [], read_error: 'Evidence-only history transition could not be proven.' };
      }
    }
  }
  return {
    repository: REPOSITORY,
    observed_at: observedAt,
    source_status: sourceStatus,
    worktrees,
    pull_requests: pullRequests,
    evidence_transitions: evidenceTransitions,
  };
}

export function captureLedger({ repoRoot = DEFAULT_ROOT, includeChangedFiles = true } = {}) {
  const live = collectLiveInventory({ repoRoot });
  const rows = live.pull_requests.map(pullRequest => {
    let files = { endpoint: `repos/${REPOSITORY}/pulls/${pullRequest.number}/files?per_page=100`, status: 'failed', files: [] };
    if (includeChangedFiles && live.source_status.pull_requests.status === 'complete') {
      try {
        files = liveChangedFiles(repoRoot, pullRequest.number);
      } catch {
        files = { ...files, read_error: 'Complete changed-file pagination failed; disposition is blocked until refreshed.' };
      }
    }
    const releasePlease = /^chore\(main\): release /.test(pullRequest.title ?? '') && pullRequest.head_ref === 'release-please--branches--main';
    return {
      ...pullRequest,
      files_read: { status: files.status, endpoint: files.endpoint },
      changed_files: files.files,
      is_release_please_candidate: releasePlease,
      disposition: null,
    };
  });
  const worktrees = live.worktrees.map(worktree => ({
    ...worktree,
    dirty_paths: worktree.dirty_paths.map(dirty => ({ ...dirty, preservation: null })),
  }));
  const rootWorktree = worktrees.find(row => row.path === repoRoot);
  const selfArtifactCollisions = rootWorktree?.dirty_paths.filter(row => SELF_ARTIFACTS.includes(row.path)) ?? [];
  const ledger = {
    schema_version: 1,
    repository: REPOSITORY,
    observed_at: live.observed_at,
    inventory_status: live.source_status.worktrees.status === 'complete' && live.source_status.pull_requests.status === 'complete' && selfArtifactCollisions.length === 0 ? 'complete' : 'blocked',
    closeout_status: 'blocked-until-dispositions-and-preservation',
    source_status: live.source_status,
    evidence_artifacts: {
      worktree_path: repoRoot,
      anchor_head_sha: rootWorktree?.head_sha ?? null,
      paths: SELF_ARTIFACTS,
      reason: 'The ledger and its summary are self-evidencing phase outputs; exclude only these exact paths from inherited dirty-path identity and permit only commits touching these paths after the captured anchor.',
      collisions: selfArtifactCollisions.map(row => ({ path: row.path, status: row.status, sha256: row.sha256 })),
    },
    worktrees,
    pull_requests: rows,
    notes: [
      'This is a live read-only inventory. No worktree, file, or PR was modified by capture.',
      'Content is represented by SHA-256 identities; file contents are not copied into this ledger.',
      'The clean-closeout claim remains blocked until Plan 05 verifies durable preservation for every inherited dirty path.',
      ...(selfArtifactCollisions.length ? ['A phase output path was already dirty before capture; inventory is blocked until its ownership is resolved.'] : []),
    ],
  };
  return sortLedger(ledger);
}

function parseArgs(args) {
  const result = { mode: null, ledgerPath: null };
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--mode') result.mode = args[++index];
    else if (args[index] === '--ledger') result.ledgerPath = args[++index];
    else throw new Error(`Unknown argument: ${args[index]}`);
  }
  if (!result.mode || !result.ledgerPath) throw new Error('Usage: validate-closeout.mjs --ledger <path> --mode capture|inventory|dispositions');
  return result;
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }
  const ledgerPath = path.resolve(DEFAULT_ROOT, args.ledgerPath);
  if (args.mode === 'capture') {
    const ledger = captureLedger({ repoRoot: DEFAULT_ROOT });
    fs.mkdirSync(path.dirname(ledgerPath), { recursive: true });
    const temporaryPath = `${ledgerPath}.tmp-${process.pid}`;
    fs.writeFileSync(temporaryPath, `${JSON.stringify(ledger, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(temporaryPath, ledgerPath);
    const summary = { valid: ledger.inventory_status === 'complete', inventory_status: ledger.inventory_status, worktrees: ledger.worktrees.length, dirty_paths: ledger.worktrees.reduce((sum, row) => sum + row.dirty_paths.length, 0), pull_requests: ledger.pull_requests.length, changed_file_reads_failed: ledger.pull_requests.filter(row => row.files_read.status !== 'complete').map(row => row.number) };
    console.log(JSON.stringify(summary, null, 2));
    process.exitCode = summary.valid && summary.changed_file_reads_failed.length === 0 ? 0 : 1;
    return;
  }
  let ledger;
  try {
    ledger = JSON.parse(fs.readFileSync(ledgerPath, 'utf8'));
  } catch {
    console.error(JSON.stringify({ valid: false, code: 'ledger_read_failed', path: ledgerPath }));
    process.exitCode = 1;
    return;
  }
  const live = collectLiveInventory({ repoRoot: DEFAULT_ROOT, ledger });
  const inventory = validateInventory(ledger, live);
  const result = args.mode === 'inventory' ? inventory
    : args.mode === 'dispositions' ? { inventory, dispositions: validateDispositions(ledger) }
      : null;
  if (!result) {
    console.error('Unsupported mode; use capture, inventory or dispositions.');
    process.exitCode = 2;
    return;
  }
  console.log(JSON.stringify(result, null, 2));
  const valid = args.mode === 'inventory' ? result.valid : result.inventory.valid && result.dispositions.valid;
  process.exitCode = valid ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
