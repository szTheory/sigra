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
const CLOSEOUT_PATH = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json';

function run(command, args, cwd, maxBuffer = 64 * 1024 * 1024) {
  return execFileSync(command, args, { cwd, encoding: 'buffer', maxBuffer });
}

function runText(command, args, cwd, maxBuffer) {
  return run(command, args, cwd, maxBuffer).toString('utf8').trimEnd();
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

export function artifactIdentitySha256(value) {
  const normalized = structuredClone(value);
  for (const output of normalized?.evidence_artifacts?.output_provenance ?? []) {
    output.artifact_identity_sha256 = null;
  }
  return sha256(Buffer.from(JSON.stringify(normalized)));
}

function validOutputProvenance(output, rootPath, anchorSha) {
  const boundary = output?.capture_boundary;
  if (typeof output?.path !== 'string' || !output.path || path.isAbsolute(output.path) || output.path.split(/[\\/]/).includes('..')) return false;
  return typeof output.producer === 'string' && output.producer.trim().length > 0
    && output.source_commit === anchorSha
    && DIGEST.test(output.artifact_identity_sha256 ?? '')
    && typeof boundary?.captured_at === 'string' && !Number.isNaN(Date.parse(boundary.captured_at))
    && boundary.worktree_path === rootPath
    && boundary.source_head_sha === anchorSha
    && boundary.source_path_status === 'clean'
    && (boundary.source_path_sha256 === null || DIGEST.test(boundary.source_path_sha256 ?? ''));
}

function committedPathDigest(repoRoot, commitSha, relativePath) {
  try {
    return sha256(run('git', ['-C', repoRoot, 'show', `${commitSha}:${relativePath}`], repoRoot));
  } catch {
    return null;
  }
}

function verifyOutputArtifact(repoRoot, currentSha, output) {
  try {
    const bytes = run('git', ['-C', repoRoot, 'show', `${currentSha}:${output.path}`], repoRoot);
    const value = JSON.parse(bytes.toString('utf8'));
    const embedded = value?.evidence_artifacts?.output_provenance?.find(row => row.path === output.path);
    return embedded
      && JSON.stringify(embedded) === JSON.stringify(output)
      && artifactIdentitySha256(value) === output.artifact_identity_sha256;
  } catch {
    return false;
  }
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

export function evidenceTransition(repoRoot, anchorSha, currentSha, outputProvenance) {
  if (anchorSha === currentSha) return { valid: true, changed_paths: [], output_provenance: [] };
  let ancestor = false;
  try {
    execFileSync('git', ['-C', repoRoot, 'merge-base', '--is-ancestor', anchorSha, currentSha], { stdio: 'ignore' });
    ancestor = true;
  } catch {
    ancestor = false;
  }
  const changed = run('git', ['-C', repoRoot, 'diff', '--name-only', '-z', `${anchorSha}..${currentSha}`], repoRoot).toString('utf8')
    .split('\0').filter(Boolean);
  const outputs = Array.isArray(outputProvenance) ? outputProvenance : [];
  const uniqueOutputs = unique(outputs, row => row?.path);
  const expectedPaths = sortRows(outputs.map(row => row.path), value => value);
  const changedPaths = sortRows(changed, value => value);
  let directChild = false;
  try {
    const parents = runText('git', ['-C', repoRoot, 'rev-list', '--parents', '-n', '1', currentSha], repoRoot).split(' ');
    directChild = parents.length === 2 && parents[1] === anchorSha;
  } catch {
    directChild = false;
  }
  const descriptorsValid = outputs.length > 0 && uniqueOutputs && outputs.every(output => {
    if (!validOutputProvenance(output, repoRoot, anchorSha)) return false;
    if (committedPathDigest(repoRoot, anchorSha, output.path) !== output.capture_boundary.source_path_sha256) return false;
    return verifyOutputArtifact(repoRoot, currentSha, output);
  });
  const exactPathSet = equalList(expectedPaths, changedPaths);
  return {
    valid: ancestor && directChild && descriptorsValid && exactPathSet,
    changed_paths: changedPaths,
    output_provenance: outputs,
  };
}

export function sortLedger(ledger) {
  return {
    ...ledger,
    evidence_artifacts: ledger.evidence_artifacts ? {
      ...ledger.evidence_artifacts,
      output_provenance: sortRows(ledger.evidence_artifacts.output_provenance ?? [], row => row.path ?? ''),
    } : ledger.evidence_artifacts,
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

export function inventoryFingerprint(ledger, live) {
  const stableSource = source => {
    const value = live?.source_status?.[source] ?? {};
    return {
      status: value.status ?? null,
      pagination_complete: value.pagination_complete ?? false,
      count: value.count ?? null,
      method: value.method ?? null,
      read_error: value.read_error ?? null,
    };
  };
  const worktrees = sortRows((live?.worktrees ?? []).map(row => {
    return {
      path: row.path,
      branch: row.branch ?? null,
      head_sha: row.head_sha ?? null,
      detached: row.detached ?? false,
      locked: row.locked ?? false,
      prunable: row.prunable ?? false,
      read_status: row.read_status ?? null,
      dirty_paths: sortRows((row.dirty_paths ?? []).map(dirty => ({
        path: dirty.path,
        status: dirty.status,
        original_path: dirty.original_path ?? null,
        content_state: dirty.content_state ?? null,
        sha256: dirty.sha256 ?? null,
      })), dirtyKey),
    };
  }), row => row.path);
  const pullRequests = sortRows((live?.pull_requests ?? []).map(row => ({
    number: row.number,
    title: row.title,
    base_ref: row.base_ref,
    base_sha: row.base_sha,
    head_ref: row.head_ref,
    head_sha: row.head_sha,
    url: row.url,
  })), row => String(row.number).padStart(12, '0'));
  const snapshot = {
    repository: live?.repository ?? null,
    source_status: { worktrees: stableSource('worktrees'), pull_requests: stableSource('pull_requests') },
    worktrees,
    pull_requests: pullRequests,
  };
  return sha256(Buffer.from(JSON.stringify(snapshot)));
}

export function validateInventory(ledger, live) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  if (ledger?.repository !== REPOSITORY || live?.repository !== REPOSITORY) add('repository_mismatch', 'Both snapshots must identify szTheory/sigra.');
  if (ledger?.inventory_status !== 'complete') add('ledger_inventory_not_complete', 'A blocked or partial captured inventory cannot pass live validation.');
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
  if (Array.isArray(evidence.collisions) && evidence.collisions.length > 0) add('evidence_artifact_collision', 'A phase output path was already dirty before capture and must be resolved explicitly.');
  const outputProvenance = Array.isArray(evidence.output_provenance) ? evidence.output_provenance : [];
  if (evidence.worktree_path && (outputProvenance.length === 0 || !SHA.test(evidence.anchor_head_sha ?? ''))) {
    add('evidence_artifact_anchor_invalid', 'Evidence transitions need a full source commit and at least one provenance-bound exact output.');
  }
  if (outputProvenance.length > 0) {
    if (!unique(outputProvenance, row => row?.path)) add('evidence_output_duplicate', 'Evidence output paths must be unique.');
    for (const output of outputProvenance) {
      if (!validOutputProvenance(output, evidence.worktree_path, evidence.anchor_head_sha)) {
        add('evidence_output_provenance_invalid', `Evidence output ${output?.path ?? '(unknown)'} lacks a producer, exact identity, source commit, hash, or clean capture boundary.`);
      }
    }
  }
  for (const expected of ledgerWorktrees) {
    const current = liveByPath.get(expected.path);
    if (!current) continue;
    const selfWorktree = expected.path === evidence.worktree_path;
    if (expected.branch !== current.branch) add('worktree_branch_mismatch', `Worktree branch changed for ${expected.path}.`);
    if (expected.head_sha !== current.head_sha) {
      const transition = live.evidence_transitions?.[expected.path];
      const transitionPaths = Array.isArray(transition?.changed_paths) ? transition.changed_paths : [];
      const expectedOutputPaths = selfWorktree ? sortRows(outputProvenance.map(output => output.path), value => value) : [];
      const transitionedOutputPaths = sortRows(transitionPaths, value => value);
      const verifiedOutputs = Array.isArray(transition?.output_provenance) ? transition.output_provenance : [];
      const sameProvenance = JSON.stringify(verifiedOutputs) === JSON.stringify(outputProvenance);
      if (!selfWorktree || transition?.valid !== true || !equalList(transitionedOutputPaths, expectedOutputPaths) || !sameProvenance) {
        add('worktree_head_mismatch', `Worktree HEAD changed outside the declared phase evidence transition for ${expected.path}.`);
      }
    }
    if (selfWorktree) {
      for (const output of outputProvenance) {
        if ((expected.dirty_paths ?? []).some(row => row.path === output.path)) {
          add('evidence_output_collision', `Evidence output ${output.path} was already dirty at its declared clean capture boundary.`);
        }
      }
    }
    const expectedDirty = sortRows(expected.dirty_paths ?? [], dirtyKey).map(dirtyKey);
    const currentDirty = sortRows(current.dirty_paths ?? [], dirtyKey).map(dirtyKey);
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
    for (const dirty of worktree.inherited_dirty_paths ?? worktree.dirty_paths ?? []) {
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

function recoveryPathKey(row) {
  return JSON.stringify([row.path, row.status, row.content_state, row.sha256]);
}

function recoveredBlobHashes(repoRoot, commitSha, relativePath) {
  const commits = runText('git', ['rev-list', '--parents', '-n', '1', commitSha], repoRoot).split(' ').slice(0, 4);
  const hashes = new Set();
  for (const commit of commits) {
    const entries = run('git', ['ls-tree', '-rz', '-r', '--full-tree', commit], repoRoot).toString('utf8').split('\0');
    for (const entry of entries) {
      if (!entry) continue;
      const separator = entry.indexOf('\t');
      if (separator < 0 || entry.slice(separator + 1) !== relativePath) continue;
      const [mode, type, objectSha] = entry.slice(0, separator).split(' ');
      if (type !== 'blob' || !/^[0-7]{6}$/.test(mode ?? '') || !SHA.test(objectSha ?? '')) continue;
      hashes.add(sha256(run('git', ['cat-file', 'blob', objectSha], repoRoot)));
    }
  }
  return hashes;
}

export function validatePreservation(ledger, live, { repoRoot = DEFAULT_ROOT } = {}) {
  const errors = [];
  const blockers = [];
  const add = (code, message) => errors.push({ code, message });
  const inventory = validateInventory(ledger, live);
  for (const error of inventory.errors) {
    if (error.code !== 'dirty_path_population_mismatch') errors.push(error);
  }
  if (!Array.isArray(ledger?.worktrees) || !Array.isArray(live?.worktrees)) {
    add('preservation_worktrees_missing', 'Complete ledger and live worktree arrays are required.');
    return { valid: false, blocked: true, closeout_status: 'invalid', errors, blockers };
  }

  const liveByPath = new Map(live.worktrees.map(worktree => [worktree.path, worktree]));
  const preservationGroups = new Map();
  for (const worktree of ledger.worktrees) {
    const current = liveByPath.get(worktree.path);
    if (!current) continue;
    const baseline = worktree.inherited_dirty_paths ?? worktree.dirty_paths ?? [];
    const currentRows = current.dirty_paths ?? [];
    const currentByIdentity = new Map(currentRows.map(row => [dirtyKey(row), row]));
    const currentByPath = new Map(currentRows.map(row => [row.path, row]));
    const baselineByIdentity = new Map(baseline.map(row => [dirtyKey(row), row]));

    for (const dirty of baseline) {
      const record = dirty.preservation;
      if (!record || !PRESERVATION_STATES.has(record.state)) {
        add('preservation_decision_missing', `Inherited path ${worktree.path}:${dirty.path} has no valid preservation decision.`);
        continue;
      }
      const currentExact = currentByIdentity.has(dirtyKey(dirty));
      const currentAtPath = currentByPath.get(dirty.path);
      if (record.state === 'preserved') {
        if (currentAtPath) add('preservation_source_not_clean', `Preserved path ${worktree.path}:${dirty.path} is still dirty in its source worktree.`);
        if (!record.ref || !/^refs\/phase-249-preservation\/[A-Za-z0-9._/-]+$/.test(record.ref) || record.ref.includes('..')) {
          add('preservation_ref_missing', `Preserved path ${worktree.path}:${dirty.path} needs a named refs/phase-249-preservation/* ref.`);
          continue;
        }
        if (!Array.isArray(record.paths) || record.paths.length === 0 || !SHA.test(record.object_sha ?? '')) {
          add('preservation_path_set_invalid', `Preserved path ${worktree.path}:${dirty.path} needs a full ref object SHA and exact path set.`);
          continue;
        }
        const group = preservationGroups.get(record.ref) ?? { worktree_path: worktree.path, object_sha: record.object_sha, rows: [], declarations: [] };
        group.rows.push(dirty);
        group.declarations.push(record.paths);
        if (group.object_sha !== record.object_sha || group.worktree_path !== worktree.path) {
          add('preservation_ref_reused', `Preservation ref ${record.ref} is assigned to different objects or source worktrees.`);
        }
        preservationGroups.set(record.ref, group);
      } else {
        if (!currentExact) add('preservation_source_drift', `Unpreserved path ${worktree.path}:${dirty.path} no longer matches its captured bytes/status.`);
        blockers.push({ worktree_path: worktree.path, path: dirty.path, state: record.state, reason: record.reason });
      }
    }

    for (const row of currentRows) {
      const prior = baselineByIdentity.get(dirtyKey(row));
      if (prior?.preservation?.state === 'preserved') {
        add('preservation_source_not_clean', `Preserved path ${worktree.path}:${row.path} reappeared in the source worktree.`);
      } else if (!prior) {
        add('preservation_new_dirty_path', `New or changed dirty path ${worktree.path}:${row.path} is absent from the preservation ledger.`);
      }
    }
  }

  for (const [ref, group] of preservationGroups) {
    let resolvedSha;
    try {
      resolvedSha = runText('git', ['rev-parse', '--verify', `${ref}^{commit}`], repoRoot);
    } catch {
      add('preservation_ref_unresolvable', `Preservation ref ${ref} does not resolve to a commit.`);
      continue;
    }
    if (resolvedSha !== group.object_sha) add('preservation_ref_object_mismatch', `Preservation ref ${ref} resolves to ${resolvedSha}, not its recorded object SHA.`);
    const expectedPaths = sortRows(group.rows.map(({ path: relativePath, status, content_state, sha256: digestValue }) => ({ path: relativePath, status, content_state, sha256: digestValue })), recoveryPathKey);
    for (const declaration of group.declarations) {
      const declared = sortRows(declaration, recoveryPathKey);
      if (!equalList(declared.map(recoveryPathKey), expectedPaths.map(recoveryPathKey))) {
        const hashMismatch = declared.some(row => expectedPaths.some(expected => expected.path === row.path && expected.sha256 !== row.sha256));
        add(hashMismatch ? 'preservation_content_mismatch' : 'preservation_path_set_mismatch', `Preservation ref ${ref} does not declare the exact captured source path set and content hashes.`);
        break;
      }
    }
    for (const expected of expectedPaths) {
      if (!DIGEST.test(expected.sha256 ?? '') || !['regular-file', 'symlink-target'].includes(expected.content_state)) {
        add('preservation_content_unverifiable', `Preserved path ${group.worktree_path}:${expected.path} has no recoverable regular-file content hash.`);
        continue;
      }
      try {
        const hashes = recoveredBlobHashes(repoRoot, resolvedSha, expected.path);
        if (!hashes.has(expected.sha256)) add('preservation_content_mismatch', `Preservation ref ${ref} cannot recover the captured bytes for ${expected.path}.`);
      } catch {
        add('preservation_content_mismatch', `Preservation ref ${ref} cannot read the captured bytes for ${expected.path}.`);
      }
    }
  }

  const dispositions = validateDispositions(ledger);
  errors.push(...dispositions.errors);
  blockers.push(...dispositions.blockers);
  const uniqueBlockers = [...new Map(blockers.map(blocker => [JSON.stringify(blocker), blocker])).values()];
  return {
    valid: errors.length === 0,
    blocked: errors.length > 0 || uniqueBlockers.length > 0,
    closeout_status: errors.length > 0 ? 'invalid' : uniqueBlockers.length > 0 ? 'blocked' : 'ready',
    errors,
    blockers: uniqueBlockers,
  };
}

function sameJson(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function validatePromotion(promotion, constraints = {}) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  if (promotion?.schema_version !== 1) add('promotion_schema_invalid', 'Promotion evidence must declare schema_version 1.');
  const receipt = promotion?.release_receipt;
  const expectedReceipt = constraints.release_receipt;
  if (!receipt || !expectedReceipt) {
    if (promotion?.verdict === 'promoted' || !promotion?.blockers?.some(row => row.code === 'release_receipt_missing')) {
      add('promotion_receipt_missing', 'Promotion evidence must include the artifact-derived 1.6.0 release receipt or explicitly block on its absence.');
    }
  } else if (receipt.package_source_sha !== expectedReceipt.package_source_sha
    || receipt.version !== expectedReceipt.version
    || !sameJson(receipt.package_source_ci, expectedReceipt.package_source_ci)
    || (constraints.release_receipt_sha256 && receipt.sha256 !== constraints.release_receipt_sha256)) {
    add('promotion_receipt_mismatch', 'Promotion evidence changed the immutable package-source receipt identity.');
  }
  if (expectedReceipt && (!SHA.test(expectedReceipt.package_source_sha ?? '')
    || expectedReceipt.package_source_ci?.head_sha !== expectedReceipt.package_source_sha
    || expectedReceipt.package_source_ci?.ci_gate_conclusion !== 'success'
    || !/^\d+$/.test(String(expectedReceipt.package_source_ci?.run_id ?? ''))
    || !Number.isInteger(expectedReceipt.package_source_ci?.attempt)
    || expectedReceipt.package_source_ci.attempt < 1
    || typeof expectedReceipt.package_source_ci?.ci_gate_job_id !== 'string')) {
    add('promotion_receipt_invalid', 'The immutable receipt must bind successful ci-gate evidence to the package-source SHA.');
  }

  if (promotion?.verdict === 'blocked') {
    if (!Array.isArray(promotion.blockers) || promotion.blockers.length === 0
      || promotion.blockers.some(row => typeof row.code !== 'string' || !row.code.trim() || typeof row.reason !== 'string' || !row.reason.trim())) {
      add('promotion_blocker_missing', 'A blocked promotion needs explicit coded reasons.');
    }
    return { valid: errors.length === 0, blocked: true, closeout_status: errors.length ? 'invalid' : 'blocked', errors };
  }
  if (promotion?.verdict !== 'promoted') add('promotion_verdict_invalid', 'Promotion verdict must be promoted or blocked.');

  if (!SHA.test(constraints.expected_head_sha ?? '') || promotion?.head_sha !== constraints.expected_head_sha) {
    add('promotion_head_mismatch', 'The promotion head must equal the exact reviewed candidate head.');
  }
  if (!SHA.test(constraints.expected_base_sha ?? '') || promotion?.base_sha !== constraints.expected_base_sha) {
    add('promotion_base_mismatch', 'The promotion base must equal the protected-main base captured for review.');
  }
  if (!Number.isInteger(promotion?.pr?.number) || promotion.pr.number < 1 || typeof promotion.pr.url !== 'string' || !promotion.pr.url.startsWith('https://github.com/szTheory/sigra/pull/')) {
    add('promotion_pr_identity_missing', 'Promotion evidence needs a canonical Sigra pull request identity.');
  }
  if (!Array.isArray(promotion?.changed_paths) || promotion.changed_paths.length === 0) {
    add('promotion_diff_missing', 'Promotion evidence needs the complete changed-path set.');
  } else {
    const allowed = new Set(constraints.allowed_paths ?? []);
    for (const changedPath of promotion.changed_paths) {
      if (typeof changedPath !== 'string' || !changedPath || !allowed.has(changedPath)) {
        add('promotion_diff_path_unrelated', `Promotion diff path ${String(changedPath)} is outside the exact phase allowlist.`);
      }
    }
    if (new Set(promotion.changed_paths).size !== promotion.changed_paths.length) add('promotion_diff_duplicate_path', 'Promotion diff paths must be unique.');
  }
  if (promotion?.review?.result !== 'approved' || promotion.review.commit_sha !== promotion.head_sha) {
    add('promotion_review_missing', 'The exact candidate head needs an approved review.');
  }
  const requiredCi = promotion?.required_ci;
  if (requiredCi?.check_name !== (constraints.required_check_name ?? 'ci-gate')
    || requiredCi.conclusion !== 'success'
    || requiredCi.head_sha !== promotion?.head_sha
    || typeof requiredCi.run_id !== 'string'
    || !/^\d+$/.test(requiredCi.run_id)
    || !Number.isInteger(requiredCi.attempt)
    || requiredCi.attempt < 1
    || typeof requiredCi.job_id !== 'string'
    || !/^\d+$/.test(requiredCi.job_id)) {
    add('promotion_ci_gate_missing', 'Successful ci-gate evidence must identify a run, attempt, job and exact candidate head.');
  }
  if (promotion?.merge?.merged !== true || !SHA.test(promotion.merge.merge_sha ?? '')) {
    add('promotion_merge_missing', 'Promotion requires a protected-main merge result and full merge SHA.');
  }
  return { valid: errors.length === 0, blocked: errors.length > 0, closeout_status: errors.length ? 'blocked' : 'ready', errors };
}

const RECEIPT_PATH = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json';
const PROMOTION_PATH = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-PROMOTION.json';
const MAIN_CI_WORKFLOW = '.github/workflows/ci.yml';

function promotionDetails(record) {
  if (record && Object.hasOwn(record, 'promotion')) return { record, promotion: record.promotion, verdict: record.verdict };
  return { record, promotion: record, verdict: record?.verdict };
}

export function validatePostMerge(promotionRecord, expectedReceipt, liveMain, constraints = {}) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  const { record, promotion, verdict } = promotionDetails(promotionRecord);
  const receiptPath = constraints.receipt_path ?? RECEIPT_PATH;
  if (!record || verdict !== 'promoted' || !promotion || promotion.merge?.merged !== true || !SHA.test(promotion.merge?.merge_sha ?? '')) {
    add('promotion_not_merged', 'The scoped promotion record does not contain a verified protected-main merge.');
  }
  if (record?.pr && (!Number.isInteger(record.pr.number) || !record.pr.url?.startsWith('https://github.com/szTheory/sigra/pull/'))) {
    add('promotion_pr_identity_invalid', 'The promotion PR identity is not a canonical Sigra pull request.');
  }
  if (verdict === 'promoted' && (!record?.pr || promotion?.review?.result !== 'approved' || promotion.review.commit_sha !== promotion.head_sha)) {
    add('promotion_review_missing', 'The exact merged promotion candidate lacks a matching PR and approved review identity.');
  }
  if (liveMain?.source_status === 'failed' || !SHA.test(liveMain?.current_main_sha ?? '')) {
    add('final_main_identity_missing', 'The current protected-main SHA could not be read as a full commit identity.');
  }
  if (liveMain?.current_main_sha_after && liveMain.current_main_sha_after !== liveMain.current_main_sha) {
    add('final_main_advanced', 'Protected main advanced during proof capture; refresh all evidence on the new head.');
  }
  if (verdict === 'promoted' && liveMain?.promotion_merge_on_main !== true) {
    add('promotion_merge_not_on_main', 'The recorded promotion merge is not proven to be an ancestor of the current protected-main head.');
  }

  const receipt = liveMain?.receipt;
  if (!receipt || receipt.exists !== true || !receipt.value) {
    add('final_main_receipt_missing', 'The sanitized release receipt is absent from current protected main.');
  } else {
    if (receipt.path !== receiptPath || (record?.release_receipt?.path && record.release_receipt.path !== receiptPath)) {
      add('final_main_receipt_path_mismatch', 'Protected main does not expose the receipt at its canonical Phase 249 path.');
    }
    if (!SHA.test(receipt.blob_sha ?? '') || (constraints.receipt_blob_sha && receipt.blob_sha !== constraints.receipt_blob_sha)) {
      add('final_main_receipt_blob_mismatch', 'The protected-main receipt blob differs from the immutable committed receipt.');
    }
    if (!DIGEST.test(receipt.sha256 ?? '') || (constraints.receipt_sha256 && receipt.sha256 !== constraints.receipt_sha256)) {
      add('final_main_receipt_hash_mismatch', 'The protected-main receipt bytes differ from the immutable committed receipt.');
    }
    if (!expectedReceipt || !sameJson(receipt.value, expectedReceipt)) {
      add('final_main_receipt_identity_mismatch', 'The protected-main receipt changed the immutable package-source, artifact or public release identity.');
    }
    if (receipt.value?.package_source_sha === liveMain?.current_main_sha) {
      add('final_main_source_identity_conflated', 'The later protected-main SHA must remain separate from the immutable package-source SHA.');
    }
  }
  const promotionReceipt = promotion?.release_receipt ?? record?.release_receipt;
  if (promotionReceipt && expectedReceipt && (promotionReceipt.version !== expectedReceipt.version
    || promotionReceipt.package_source_sha !== expectedReceipt.package_source_sha
    || !sameJson(promotionReceipt.package_source_ci, expectedReceipt.package_source_ci)
    || (constraints.receipt_sha256 && promotionReceipt.sha256 !== constraints.receipt_sha256))) {
    add('promotion_receipt_identity_mismatch', 'The scoped promotion record does not preserve the immutable receipt identity.');
  }

  const ci = liveMain?.ci;
  if (ci && ci.head_sha !== liveMain?.current_main_sha) {
    add('final_main_ci_head_mismatch', 'The ordinary CI run head SHA differs from the current protected-main SHA.');
  }
  if (!ci || ci.workflow !== MAIN_CI_WORKFLOW || ci.status !== 'completed' || ci.conclusion !== 'success'
    || !/^\d+$/.test(String(ci.run_id ?? ''))
    || !Number.isInteger(ci.attempt) || ci.attempt < 1 || typeof ci.url !== 'string') {
    add('final_main_ci_invalid', 'A completed successful ordinary CI run on the current protected-main SHA is missing.');
  }
  const gate = ci?.ci_gate;
  if (gate && gate.head_sha !== liveMain?.current_main_sha) {
    add('final_main_ci_gate_head_mismatch', 'The ci-gate job head SHA differs from the current protected-main SHA.');
  }
  if (!gate || gate.name !== 'ci-gate' || gate.status !== 'completed' || gate.conclusion !== 'success'
    || !/^\d+$/.test(String(gate.job_id ?? '')) || typeof gate.url !== 'string') {
    add('final_main_ci_gate_invalid', 'A completed successful ci-gate job on the exact current protected-main SHA is missing.');
  }
  return {
    valid: errors.length === 0,
    blocked: errors.length > 0,
    verdict: errors.length === 0 ? 'passed' : 'blocked',
    final_main_sha: liveMain?.current_main_sha ?? null,
    receipt_path: receiptPath,
    receipt_blob_sha: receipt?.blob_sha ?? null,
    receipt_sha256: receipt?.sha256 ?? null,
    ci: ci ? { workflow: ci.workflow, run_id: ci.run_id, attempt: ci.attempt, url: ci.url, head_sha: ci.head_sha, conclusion: ci.conclusion,
      ci_gate: gate ? { job_id: gate.job_id, url: gate.url, head_sha: gate.head_sha, conclusion: gate.conclusion } : null } : null,
    errors,
  };
}

export function validatePublicIdentity(receipt, publicProof) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  if (!receipt || !publicProof || publicProof.verdict !== 'passed') {
    add('public_proof_incomplete', 'A live passing public-release proof is required for final acceptance.');
  } else {
    if (publicProof.package !== receipt.package || publicProof.version !== receipt.version || publicProof.tag !== receipt.tag
      || publicProof.package_source_sha !== receipt.package_source_sha
      || !sameJson(publicProof.package_source_ci, receipt.package_source_ci)) {
      add('public_source_identity_mismatch', 'The live tag, package or source CI identity differs from the immutable receipt.');
    }
    if (!sameJson(publicProof.hex, receipt.hex) || publicProof.versioned_docs_url !== receipt.versioned_docs_url
      || !sameJson(publicProof.source_reference, receipt.source_reference)) {
      add('public_source_identity_mismatch', 'The live Hex, versioned docs or resolving source destination differs from the immutable receipt.');
    }
  }
  return { valid: errors.length === 0, errors };
}

export function validateFinalAcceptance(proof) {
  const errors = [];
  const blockers = [];
  const add = (code, message) => errors.push({ code, message });
  const mainProof = validatePostMerge(proof?.promotion, proof?.receipt, proof?.live_main, {
    receipt_path: proof?.receipt_path ?? RECEIPT_PATH,
    receipt_sha256: proof?.receipt_sha256,
    receipt_blob_sha: proof?.receipt_blob_sha,
  });
  errors.push(...mainProof.errors);
  if (proof?.live_main_sha && proof.live_main?.current_main_sha !== proof.live_main_sha) {
    add('final_main_advanced', 'The independently refreshed protected-main SHA differs from the captured exact-head proof.');
  }
  if (!proof?.main_proof) {
    add('final_main_proof_missing', 'The durable post-merge protected-main evidence artifact is required for final acceptance.');
  } else if (proof.main_proof.verdict !== mainProof.verdict
    || proof.main_proof.protected_main_sha !== mainProof.final_main_sha
    || proof.main_proof.receipt_blob_sha !== mainProof.receipt_blob_sha) {
    add('final_main_proof_stale', 'The durable post-merge proof differs from the revalidated live source identities.');
  }
  const publicResult = validatePublicIdentity(proof?.receipt, proof?.public_proof);
  errors.push(...publicResult.errors);

  const inventory = validateInventory(proof?.ledger, proof?.live_inventory);
  errors.push(...inventory.errors);
  const preservation = validatePreservation(proof?.ledger, proof?.live_inventory, { repoRoot: proof?.repo_root ?? DEFAULT_ROOT });
  errors.push(...preservation.errors);
  blockers.push(...preservation.blockers);
  const dispositions = validateDispositions(proof?.ledger);
  errors.push(...dispositions.errors);
  blockers.push(...dispositions.blockers);
  const uniqueBlockers = [...new Map(blockers.map(blocker => [JSON.stringify(blocker), blocker])).values()];
  return {
    valid: errors.length === 0 && uniqueBlockers.length === 0,
    blocked: errors.length > 0 || uniqueBlockers.length > 0,
    verdict: errors.length === 0 && uniqueBlockers.length === 0 ? 'passed' : 'blocked',
    errors,
    blockers: uniqueBlockers,
    inventory: { valid: inventory.valid, worktrees: proof?.live_inventory?.worktrees?.length ?? 0, pull_requests: proof?.live_inventory?.pull_requests?.length ?? 0 },
    post_merge: mainProof,
    public_release: publicResult,
    preservation: { valid: preservation.valid, blocked: preservation.blocked, closeout_status: preservation.closeout_status, blocker_count: preservation.blockers.length },
    dispositions: { valid: dispositions.valid, blocked: dispositions.blocked, blocker_count: dispositions.blockers.length },
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
  if (ledger?.evidence_artifacts?.worktree_path && Array.isArray(ledger.evidence_artifacts.output_provenance)) {
    const anchor = ledger.worktrees?.find(row => row.path === ledger.evidence_artifacts.worktree_path);
    const current = worktrees.find(row => row.path === ledger.evidence_artifacts.worktree_path);
    if (anchor && current) {
      try {
        evidenceTransitions[current.path] = evidenceTransition(repoRoot, anchor.head_sha, current.head_sha, ledger.evidence_artifacts.output_provenance);
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

export function captureLedger({ repoRoot = DEFAULT_ROOT, includeChangedFiles = true, previousLedgerInput = null } = {}) {
  repoRoot = fs.realpathSync(repoRoot);
  const live = collectLiveInventory({ repoRoot });
  const closeoutAbsolutePath = path.join(repoRoot, CLOSEOUT_PATH);
  let previousLedger = previousLedgerInput;
  if (!previousLedger) {
    try { previousLedger = JSON.parse(fs.readFileSync(closeoutAbsolutePath, 'utf8')); } catch { previousLedger = null; }
  }
  const previousWorktrees = new Map((previousLedger?.worktrees ?? []).map(row => [row.path, row]));
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
    const previous = (previousLedger?.pull_requests ?? []).find(row => JSON.stringify([row.number, row.title, row.base_ref, row.base_sha, row.head_ref, row.head_sha, row.url])
      === JSON.stringify([pullRequest.number, pullRequest.title, pullRequest.base_ref, pullRequest.base_sha, pullRequest.head_ref, pullRequest.head_sha, pullRequest.url]));
    const sameChangedFiles = previous?.files_read?.status === 'complete'
      && files.status === 'complete'
      && equalList(
        sortRows(previous.changed_files ?? [], file => `${file.path}\0${file.status}`).map(file => `${file.path}\0${file.status}`),
        sortRows(files.files, file => `${file.path}\0${file.status}`).map(file => `${file.path}\0${file.status}`),
      );
    return {
      ...pullRequest,
      files_read: { status: files.status, endpoint: files.endpoint },
      changed_files: files.files,
      is_release_please_candidate: releasePlease,
      disposition: sameChangedFiles ? previous.disposition ?? null : null,
    };
  });
  const worktrees = live.worktrees.map(worktree => ({
    ...worktree,
    dirty_paths: worktree.dirty_paths.map(({ preservation: _preservation, ...dirty }) => dirty),
    inherited_dirty_paths: (() => {
      const previous = previousWorktrees.get(worktree.path);
      const prior = previous?.inherited_dirty_paths ?? previous?.dirty_paths ?? [];
      const rowsByIdentity = new Map(prior.map(dirty => [dirtyKey(dirty), structuredClone(dirty)]));
      for (const current of worktree.dirty_paths) {
        const priorRow = rowsByIdentity.get(dirtyKey(current));
        if (priorRow?.preservation) rowsByIdentity.set(dirtyKey(current), { ...current, preservation: priorRow.preservation });
        else if (!priorRow) rowsByIdentity.set(dirtyKey(current), { ...current, preservation: null });
      }
      return sortRows([...rowsByIdentity.values()], dirtyKey);
    })(),
  }));
  const rootWorktree = worktrees.find(row => row.path === repoRoot);
  const outputCollisions = rootWorktree?.dirty_paths.filter(row => row.path === CLOSEOUT_PATH) ?? [];
  const outputProvenance = [];
  if (rootWorktree && outputCollisions.length === 0) {
    outputProvenance.push({
      path: CLOSEOUT_PATH,
      producer: 'node validate-closeout.mjs --mode capture',
      source_commit: rootWorktree.head_sha,
      artifact_identity_sha256: null,
      capture_boundary: {
        captured_at: live.observed_at,
        worktree_path: rootWorktree.path,
        source_head_sha: rootWorktree.head_sha,
        source_path_status: 'clean',
        source_path_sha256: committedPathDigest(repoRoot, rootWorktree.head_sha, CLOSEOUT_PATH),
      },
    });
  }
  const changedFileReadsComplete = rows.every(row => row.files_read.status === 'complete');
  const ledger = {
    schema_version: 1,
    repository: REPOSITORY,
    observed_at: live.observed_at,
    inventory_status: live.source_status.worktrees.status === 'complete'
      && live.source_status.pull_requests.status === 'complete'
      && changedFileReadsComplete
      && outputCollisions.length === 0 ? 'complete' : 'blocked',
    closeout_status: 'blocked-until-dispositions-and-preservation',
    source_status: live.source_status,
    evidence_artifacts: {
      worktree_path: rootWorktree?.path ?? repoRoot,
      anchor_head_sha: rootWorktree?.head_sha ?? null,
      output_provenance: outputProvenance,
      reason: 'Only a committed exact output with a verified producer, source commit, canonical artifact hash, and clean capture boundary may explain one evidence-only HEAD transition. Raw dirty status is never filtered.',
      collisions: outputCollisions.map(row => ({ path: row.path, status: row.status, sha256: row.sha256 })),
    },
    worktrees,
    pull_requests: rows,
    notes: [
      'This is a live read-only inventory. No worktree, file, or PR was modified by capture.',
      'Content is represented by SHA-256 identities; file contents are not copied into this ledger.',
      'The clean-closeout claim remains blocked until every inherited dirty path has a verified preservation ref and all worktree statuses are empty.',
      ...(outputCollisions.length ? ['The closeout output path was already dirty at the capture boundary; it remains an inherited path and cannot be overwritten by this capture.'] : []),
      ...(!changedFileReadsComplete ? ['At least one open PR changed-file read is incomplete; the inventory is blocked.'] : []),
    ],
    capture_completed_at: new Date().toISOString(),
  };
  const sorted = sortLedger(ledger);
  for (const output of sorted.evidence_artifacts.output_provenance) {
    output.artifact_identity_sha256 = artifactIdentitySha256(sorted);
  }
  return sortLedger(sorted);
}

function githubJson(repoRoot, endpoint) {
  try {
    const bytes = run('gh', ['api', endpoint], repoRoot);
    return { ok: true, value: JSON.parse(bytes.toString('utf8')) };
  } catch (error) {
    const stderr = Buffer.isBuffer(error.stderr) ? error.stderr.toString('utf8') : '';
    const status = stderr.match(/HTTP (\d{3})/i)?.[1] ?? null;
    return { ok: false, status, rate_limited: status === '403' || status === '429' };
  }
}

function readLocalPromotion(repoRoot) {
  const ref = 'evidence/phase-249-promotion';
  try {
    const commit = runText('git', ['rev-parse', '--verify', `${ref}^{commit}`], repoRoot);
    const bytes = run('git', ['show', `${ref}:${PROMOTION_PATH}`], repoRoot);
    return { ref, commit_sha: commit, sha256: sha256(bytes), value: JSON.parse(bytes.toString('utf8')) };
  } catch {
    return { ref, commit_sha: null, sha256: null, value: null };
  }
}

function localReceipt(repoRoot) {
  try {
    const bytes = fs.readFileSync(path.join(repoRoot, RECEIPT_PATH));
    const blobSha = execFileSync('git', ['hash-object', '--stdin'], { cwd: repoRoot, input: bytes, encoding: 'utf8' }).trim();
    return {
      value: JSON.parse(bytes.toString('utf8')),
      sha256: sha256(bytes),
      blob_sha: blobSha,
    };
  } catch {
    return { value: null, sha256: null, blob_sha: null };
  }
}

function readProtectedMainProof(repoRoot, promotion) {
  const rate = githubJson(repoRoot, 'rate_limit');
  const remaining = Number(rate.value?.resources?.core?.remaining);
  if (!rate.ok || !Number.isInteger(remaining) || remaining <= 250) {
    return {
      source_status: 'failed',
      rate_limit: { status: rate.status, core_remaining: Number.isInteger(remaining) ? remaining : null },
      current_main_sha: null,
      current_main_sha_after: null,
      promotion_merge_on_main: false,
      receipt: { path: RECEIPT_PATH, exists: false },
      ci: null,
    };
  }

  const promotionBits = promotionDetails(promotion?.value);
  let latest = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const mainResponse = githubJson(repoRoot, `repos/${REPOSITORY}/commits/main`);
    if (!mainResponse.ok || !SHA.test(mainResponse.value?.sha ?? '')) {
      return { source_status: mainResponse.rate_limited ? 'rate_limited' : 'failed', current_main_sha: null, current_main_sha_after: null, promotion_merge_on_main: false, receipt: { path: RECEIPT_PATH, exists: false }, ci: null };
    }
    const currentMainSha = mainResponse.value.sha;
    const proof = {
      observed_at: new Date().toISOString(),
      source_status: 'complete',
      current_main_sha: currentMainSha,
      current_main_sha_after: null,
      promotion_merge_on_main: false,
      receipt: { path: RECEIPT_PATH, exists: false },
      ci: null,
    };

    const mergeSha = promotionBits.promotion?.merge?.merge_sha;
    if (promotionBits.verdict === 'promoted' && SHA.test(mergeSha ?? '')) {
      if (mergeSha === currentMainSha) proof.promotion_merge_on_main = true;
      else {
        const comparison = githubJson(repoRoot, `repos/${REPOSITORY}/compare/${mergeSha}...${currentMainSha}`);
        if (comparison.rate_limited) {
          proof.source_status = 'rate_limited';
          break;
        }
        proof.promotion_merge_on_main = comparison.ok && ['ahead', 'identical'].includes(comparison.value?.status);
      }
    }

    const receiptResponse = githubJson(repoRoot, `repos/${REPOSITORY}/contents/${RECEIPT_PATH}?ref=${currentMainSha}`);
    if (receiptResponse.ok) {
      const encoded = String(receiptResponse.value.content ?? '').replace(/\s/g, '');
      try {
        const bytes = Buffer.from(encoded, 'base64');
        const value = JSON.parse(bytes.toString('utf8'));
        proof.receipt = {
          path: receiptResponse.value.path,
          exists: true,
          blob_sha: receiptResponse.value.sha,
          sha256: sha256(bytes),
          value,
        };
      } catch {
        proof.receipt = { path: receiptResponse.value.path ?? RECEIPT_PATH, exists: true, blob_sha: receiptResponse.value.sha ?? null, sha256: null, value: null, content_status: 'invalid' };
      }
    } else if (receiptResponse.rate_limited) {
      proof.source_status = 'rate_limited';
      break;
    } else if (receiptResponse.status !== '404') {
      proof.receipt.read_status = 'failed';
    }

    const runsResponse = githubJson(repoRoot, `repos/${REPOSITORY}/actions/runs?head_sha=${currentMainSha}&per_page=100`);
    if (runsResponse.ok) {
      const candidates = (runsResponse.value.workflow_runs ?? []).filter(run => run.path === MAIN_CI_WORKFLOW && run.head_sha === currentMainSha);
      candidates.sort((left, right) => (right.run_number ?? 0) - (left.run_number ?? 0));
      const run = candidates[0];
      if (run) {
        const attemptNumber = Number(run.run_attempt);
        const ci = {
          workflow: run.path,
          status: run.status,
          conclusion: run.conclusion,
          head_sha: run.head_sha,
          run_id: String(run.id),
          attempt: attemptNumber,
          url: run.html_url,
          ci_gate: null,
        };
        if (run.status === 'completed' && Number.isInteger(attemptNumber) && attemptNumber > 0) {
          const jobsResponse = githubJson(repoRoot, `repos/${REPOSITORY}/actions/runs/${run.id}/attempts/${attemptNumber}/jobs?per_page=100`);
          if (jobsResponse.ok) {
            const gates = (jobsResponse.value.jobs ?? []).filter(job => job.name === 'ci-gate' && job.head_sha === currentMainSha
              && job.run_attempt === attemptNumber && job.status === 'completed');
            if (gates.length === 1) {
              const gate = gates[0];
              ci.ci_gate = { name: gate.name, job_id: String(gate.id), status: gate.status, conclusion: gate.conclusion, head_sha: gate.head_sha, url: gate.html_url };
            }
          } else if (jobsResponse.rate_limited) {
            proof.source_status = 'rate_limited';
            break;
          }
        }
        proof.ci = ci;
      }
    } else if (runsResponse.rate_limited) {
      proof.source_status = 'rate_limited';
      break;
    }

    const afterResponse = githubJson(repoRoot, `repos/${REPOSITORY}/commits/main`);
    if (!afterResponse.ok || !SHA.test(afterResponse.value?.sha ?? '')) {
      proof.source_status = afterResponse.rate_limited ? 'rate_limited' : 'failed';
      latest = proof;
      break;
    }
    proof.current_main_sha_after = afterResponse.value.sha;
    latest = proof;
    if (proof.current_main_sha_after === currentMainSha) return proof;
  }
  if (latest) return latest;
  return { source_status: 'failed', current_main_sha: null, current_main_sha_after: null, promotion_merge_on_main: false, receipt: { path: RECEIPT_PATH, exists: false }, ci: null };
}

function writeJsonArtifact(repoRoot, outputPath, value) {
  const absolutePath = path.resolve(repoRoot, outputPath);
  const relativePath = path.relative(repoRoot, absolutePath);
  if (relativePath === '..' || relativePath.startsWith(`..${path.sep}`) || path.isAbsolute(relativePath)) {
    throw new Error('Evidence output must stay inside the repository.');
  }
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  const temporaryPath = `${absolutePath}.tmp-${process.pid}`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporaryPath, absolutePath);
  return absolutePath;
}

function parseArgs(args) {
  const result = { mode: null, ledgerPath: null, outputPath: null, publicProofPath: null, mainProofPath: null };
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--mode') result.mode = args[++index];
    else if (args[index] === '--ledger') result.ledgerPath = args[++index];
    else if (args[index] === '--output') result.outputPath = args[++index];
    else if (args[index] === '--public-proof') result.publicProofPath = args[++index];
    else if (args[index] === '--main-proof') result.mainProofPath = args[++index];
    else throw new Error(`Unknown argument: ${args[index]}`);
  }
  if (!result.mode || !result.ledgerPath) throw new Error('Usage: validate-closeout.mjs --ledger <path> --mode capture|inventory|dispositions|preservation|promotion|post-merge|final [--public-proof <path>] [--main-proof <path>] [--output <path>]');
  if (['promotion', 'post-merge', 'final'].includes(result.mode) && !result.outputPath) throw new Error(`${result.mode} mode requires --output <path>.`);
  if (result.mode === 'final' && (!result.publicProofPath || !result.mainProofPath)) throw new Error('Final mode requires --public-proof and --main-proof paths.');
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
    if (ledger.evidence_artifacts.collisions?.length) {
      console.error(JSON.stringify({
        valid: false,
        inventory_status: 'blocked',
        code: 'evidence_output_collision',
        collisions: ledger.evidence_artifacts.collisions,
        message: 'The closeout output path is already dirty; preserve or commit it before refreshing this artifact.',
      }, null, 2));
      process.exitCode = 1;
      return;
    }
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
  if (args.mode === 'post-merge') {
    const promotion = readLocalPromotion(DEFAULT_ROOT);
    const receipt = localReceipt(DEFAULT_ROOT);
    const liveMain = readProtectedMainProof(DEFAULT_ROOT, promotion);
    const validation = validatePostMerge(promotion.value, receipt.value, liveMain, {
      receipt_path: RECEIPT_PATH,
      receipt_sha256: receipt.sha256,
      receipt_blob_sha: receipt.blob_sha,
    });
    const record = {
      schema_version: 1,
      phase: 249,
      plan: '06',
      repository: REPOSITORY,
      recorded_at: new Date().toISOString(),
      promotion: {
        ref: promotion.ref,
        commit_sha: promotion.commit_sha,
        sha256: promotion.sha256,
        verdict: promotion.value?.verdict ?? 'missing',
        pr: promotion.value?.promotion?.pr ?? null,
        merge: promotion.value?.promotion?.merge ?? null,
      },
      protected_main_sha: liveMain.current_main_sha,
      receipt_path: RECEIPT_PATH,
      receipt_blob_sha: liveMain.receipt?.blob_sha ?? null,
      receipt_sha256: liveMain.receipt?.sha256 ?? null,
      package_source_sha: receipt.value?.package_source_sha ?? null,
      package_source_ci: receipt.value?.package_source_ci ?? null,
      ci: validation.ci,
      live_main: liveMain,
      verdict: validation.verdict,
      errors: validation.errors,
    };
    writeJsonArtifact(DEFAULT_ROOT, args.outputPath, record);
    console.log(JSON.stringify({ verdict: record.verdict, protected_main_sha: record.protected_main_sha, receipt_present: liveMain.receipt?.exists === true, ci_gate: validation.ci?.ci_gate?.conclusion ?? null, errors: validation.errors }, null, 2));
    process.exitCode = validation.valid ? 0 : 1;
    return;
  }
  if (args.mode === 'final') {
    let publicProof = null;
    let mainProof = null;
    try { publicProof = JSON.parse(fs.readFileSync(path.resolve(DEFAULT_ROOT, args.publicProofPath), 'utf8')); } catch { /* Missing/invalid proof is a recorded blocker. */ }
    try { mainProof = JSON.parse(fs.readFileSync(path.resolve(DEFAULT_ROOT, args.mainProofPath), 'utf8')); } catch { /* Missing/invalid proof is a recorded blocker. */ }
    const promotion = readLocalPromotion(DEFAULT_ROOT);
    const receipt = localReceipt(DEFAULT_ROOT);
    const liveInventory = collectLiveInventory({ repoRoot: DEFAULT_ROOT, ledger });
    const rate = githubJson(DEFAULT_ROOT, 'rate_limit');
    const coreRemaining = Number(rate.value?.resources?.core?.remaining);
    let liveMainSha = null;
    if (rate.ok && Number.isInteger(coreRemaining) && coreRemaining > 250) {
      const mainResponse = githubJson(DEFAULT_ROOT, `repos/${REPOSITORY}/commits/main`);
      if (mainResponse.ok && SHA.test(mainResponse.value?.sha ?? '')) liveMainSha = mainResponse.value.sha;
    }
    const proof = {
      receipt: receipt.value,
      receipt_sha256: receipt.sha256,
      receipt_blob_sha: receipt.blob_sha,
      promotion: promotion.value,
      live_main: mainProof?.live_main ?? null,
      main_proof: mainProof,
      live_main_sha: liveMainSha,
      public_proof: publicProof,
      ledger,
      live_inventory: liveInventory,
      repo_root: DEFAULT_ROOT,
    };
    const validation = validateFinalAcceptance(proof);
    const evidencePaths = new Set(ledger.evidence_artifacts?.paths ?? []);
    const evidenceWorktreePath = ledger.evidence_artifacts?.worktree_path;
    const inventoryFingerprintValue = inventoryFingerprint(ledger, liveInventory);
    const inheritedDirtyPathCount = liveInventory.worktrees.reduce((sum, worktree) => sum + worktree.dirty_paths
      .filter(row => worktree.path !== evidenceWorktreePath || !evidencePaths.has(row.path)).length, 0);
    const record = {
      schema_version: 1,
      phase: 249,
      plan: '06',
      repository: REPOSITORY,
      recorded_at: new Date().toISOString(),
      package_source_sha: receipt.value?.package_source_sha ?? null,
      package_source_ci: receipt.value?.package_source_ci ?? null,
      final_main_sha: validation.post_merge.final_main_sha,
      final_main_ci: validation.post_merge.ci,
      receipt: {
        path: RECEIPT_PATH,
        blob_sha: validation.post_merge.receipt_blob_sha,
        sha256: validation.post_merge.receipt_sha256,
      },
      public_release: publicProof ? {
        verdict: publicProof.verdict ?? 'blocked',
        hex_url: publicProof.hex?.package_url ?? receipt.value?.hex?.package_url ?? null,
        versioned_docs_url: publicProof.versioned_docs_url ?? receipt.value?.versioned_docs_url ?? null,
        source_href: publicProof.source_reference?.href ?? receipt.value?.source_reference?.href ?? null,
        source_commit_sha: publicProof.source_reference?.resolved_commit_sha ?? receipt.value?.source_reference?.resolved_commit_sha ?? null,
      } : { verdict: 'blocked', reason: 'Public release proof could not be read.' },
      closeout_ledger_sha256: sha256(fs.readFileSync(ledgerPath)),
      inventory_fingerprint_sha256: inventoryFingerprintValue,
      inventory: {
        worktree_count: liveInventory.worktrees.length,
        pull_request_count: liveInventory.pull_requests.length,
        dirty_path_count: inheritedDirtyPathCount,
        worktree_read_status: liveInventory.source_status.worktrees.status,
        pull_request_read_status: liveInventory.source_status.pull_requests.status,
      },
      verdict: validation.verdict,
      errors: validation.errors,
      blockers: validation.blockers,
    };
    writeJsonArtifact(DEFAULT_ROOT, args.outputPath, record);
    console.log(JSON.stringify({ verdict: record.verdict, final_main_sha: record.final_main_sha, public_release: record.public_release.verdict, inventory: record.inventory, errors: validation.errors, blocker_count: validation.blockers.length }, null, 2));
    process.exitCode = validation.valid ? 0 : 1;
    return;
  }
  const live = collectLiveInventory({ repoRoot: DEFAULT_ROOT, ledger });
  const inventory = validateInventory(ledger, live);
  const dispositionResult = validateDispositions(ledger);
  const preservationResult = validatePreservation(ledger, live, { repoRoot: DEFAULT_ROOT });
  const result = args.mode === 'inventory' ? inventory
    : args.mode === 'dispositions' ? {
      inventory,
      dispositions: {
        valid: dispositionResult.valid,
        blocked: dispositionResult.blocked,
        closeout_status: dispositionResult.closeout_status,
        errors: dispositionResult.errors,
        blocker_count: dispositionResult.blockers.length,
        blocker_examples: dispositionResult.blockers.slice(0, 8),
      },
    }
      : args.mode === 'preservation' ? preservationResult
        : args.mode === 'promotion' ? (() => {
          const receiptRelativePath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json';
          const receiptAbsolutePath = path.join(DEFAULT_ROOT, receiptRelativePath);
          const validationRelativePath = '.planning/phases/249-publish-and-prove-sigra-1-6-0/249-05-VALIDATION.json';
          const validationAbsolutePath = path.join(DEFAULT_ROOT, validationRelativePath);
          let receipt = null;
          let receiptHash = null;
          let validationEvidenceHash = null;
          try {
            const receiptBytes = fs.readFileSync(receiptAbsolutePath);
            receipt = JSON.parse(receiptBytes.toString('utf8'));
            receiptHash = sha256(receiptBytes);
          } catch {
            // An unavailable release receipt is recorded as a blocker below.
          }
          try {
            validationEvidenceHash = sha256(fs.readFileSync(validationAbsolutePath));
          } catch {
            // An unavailable local verification record is recorded as a blocker below.
          }
          const unresolved = ledger.worktrees.flatMap(worktree => (worktree.inherited_dirty_paths ?? worktree.dirty_paths ?? [])
            .filter(dirty => dirty.preservation?.state !== 'preserved')
            .map(dirty => ({ worktree_path: worktree.path, path: dirty.path, status: dirty.status, sha256: dirty.sha256 })));
          const blockers = [];
          if (!receipt) blockers.push({ code: 'release_receipt_missing', reason: 'The immutable 1.6.0 artifact-derived release receipt could not be read.' });
          if (!validationEvidenceHash) blockers.push({ code: 'validation_evidence_missing', reason: 'The focused tests, exact-source docs comparison and full source CI result are not available in the Plan 05 validation artifact.' });
          if (!preservationResult.valid || preservationResult.blocked) {
            blockers.push({
              code: 'preservation_blocked',
              reason: `${preservationResult.blockers.length} inherited dirty paths lack approved ownership and verified durable preservation refs; see the exact path/status/hash rows in 249-CLOSEOUT.json.`,
              closeout_ledger_sha256: sha256(fs.readFileSync(ledgerPath)),
              unresolved_path_count: unresolved.length,
            });
          }
          blockers.push({
            code: 'scoped_pr_not_opened',
            reason: 'No Plan 05 phase-scoped PR has been opened. Promotion requires unblocked preservation, internal review, exact-head ci-gate and protected merge evidence.',
          });
          const promotionRecord = {
            schema_version: 1,
            phase: 249,
            plan: '05',
            recorded_at: new Date().toISOString(),
            verdict: 'blocked',
            release_receipt: receipt ? {
              path: receiptRelativePath,
              sha256: receiptHash,
              version: receipt.version,
              package_source_sha: receipt.package_source_sha,
              package_source_ci: receipt.package_source_ci,
            } : null,
            validation_evidence: validationEvidenceHash ? {
              path: validationRelativePath,
              sha256: validationEvidenceHash,
            } : null,
            promotion: null,
            closeout: {
              path: path.relative(DEFAULT_ROOT, ledgerPath),
              sha256: sha256(fs.readFileSync(ledgerPath)),
              preservation_status: preservationResult.closeout_status,
              unresolved_path_count: unresolved.length,
              unresolved_paths: unresolved,
            },
            blockers,
          };
          const validation = validatePromotion(promotionRecord, {
            release_receipt: receipt,
            release_receipt_sha256: receiptHash,
          });
          const outputPath = path.resolve(DEFAULT_ROOT, args.outputPath);
          const relativeOutput = path.relative(DEFAULT_ROOT, outputPath);
          if (relativeOutput === '..' || relativeOutput.startsWith(`..${path.sep}`) || path.isAbsolute(relativeOutput)) {
            throw new Error('Promotion evidence output must stay inside the repository.');
          }
          fs.mkdirSync(path.dirname(outputPath), { recursive: true });
          const temporaryPath = `${outputPath}.tmp-${process.pid}`;
          fs.writeFileSync(temporaryPath, `${JSON.stringify(promotionRecord, null, 2)}\n`, { mode: 0o600 });
          fs.renameSync(temporaryPath, outputPath);
          return { record: promotionRecord, validation };
        })()
      : null;
  if (!result) {
    console.error('Unsupported mode; use capture, inventory, dispositions, preservation, promotion, post-merge or final.');
    process.exitCode = 2;
    return;
  }
  console.log(JSON.stringify(result, null, 2));
  const valid = args.mode === 'inventory' ? result.valid
    : args.mode === 'preservation' ? result.valid && !result.blocked
      : args.mode === 'promotion' ? result.validation.valid && !result.validation.blocked
      : result.inventory.valid && result.dispositions.valid;
  process.exitCode = valid ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
