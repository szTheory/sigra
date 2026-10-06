import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const DISPOSITIONS = new Set(['release-blocking', 'release-relevant', 'separate-follow-up']);
const KINDS = new Set(['committed', 'dirty']);
const repository = 'szTheory/sigra';
const phaseArtifacts = [
  '.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json',
  '.planning/phases/247-release-candidate-and-repository-readiness/247-01-tdd-red-evidence.json',
  '.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs',
  '.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs',
];

function lexicallySorted(values) {
  return values.every((value, index) => index === 0 || values[index - 1] <= value);
}

function sameSet(left, right) {
  const a = [...new Set(left)].sort();
  const b = [...new Set(right)].sort();
  return a.length === left.length && b.length === right.length && a.length === b.length && a.every((value, index) => value === b[index]);
}

function pathKeys(rows, kind) {
  return rows.filter(row => row.kind === kind).map(row => row.path);
}

function validateSnapshot(snapshot, observed) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  const requiredArrays = ['commits', 'paths', 'pull_requests', 'raw_status'];
  for (const key of requiredArrays) {
    if (!Array.isArray(snapshot?.[key])) add(`${key}_not_array`, `The immutable entry snapshot must contain ${key} as an array, including when empty.`);
  }

  const commits = Array.isArray(snapshot?.commits) ? snapshot.commits : [];
  const paths = Array.isArray(snapshot?.paths) ? snapshot.paths : [];
  const pullRequests = Array.isArray(snapshot?.pull_requests) ? snapshot.pull_requests : [];
  const rawStatus = Array.isArray(snapshot?.raw_status) ? snapshot.raw_status : [];

  const commitShas = commits.map(row => row?.sha);
  if (commitShas.some(sha => !/^[0-9a-f]{40}$/.test(sha ?? ''))) add('commit_sha_invalid', 'Every inherited commit must have a full Git SHA.');
  if (new Set(commitShas).size !== commitShas.length) add('duplicate_commit_sha', 'Inherited commit SHAs must be unique.');
  if (!lexicallySorted(commitShas)) add('commit_order_invalid', 'Inherited commits must sort by SHA.');
  for (const row of commits) {
    if (!DISPOSITIONS.has(row?.disposition)) add('commit_disposition_invalid', `Commit ${row?.sha ?? '(missing SHA)'} has no valid release disposition.`);
    if (![row?.reason, row?.source, row?.preservation_location].every(value => typeof value === 'string' && value.trim())) {
      add('commit_disposition_incomplete', `Commit ${row?.sha ?? '(missing SHA)'} must include a reason, source, and preservation location.`);
    }
    if (!Array.isArray(row?.changed_paths)) add('commit_paths_not_array', `Commit ${row?.sha ?? '(missing SHA)'} must list changed paths as an array.`);
  }

  const pathIds = paths.map(row => `${row?.kind ?? ''}\0${row?.path ?? ''}`);
  if (new Set(pathIds).size !== pathIds.length) add('duplicate_path_key', 'Path identities must be unique by kind plus path.');
  if (!lexicallySorted(pathIds)) add('path_order_invalid', 'Path records must sort by kind plus path.');
  for (const row of paths) {
    if (!KINDS.has(row?.kind) || typeof row?.path !== 'string' || !row.path.trim()) add('path_identity_invalid', 'Every path record needs a committed/dirty kind and nonempty path.');
    if (!DISPOSITIONS.has(row?.disposition)) add('path_disposition_invalid', `Path ${row?.path ?? '(missing path)'} has no valid release disposition.`);
    if (![row?.reason, row?.source, row?.preservation_location].every(value => typeof value === 'string' && value.trim())) {
      add('path_disposition_incomplete', `Path ${row?.path ?? '(missing path)'} must include a reason, source, and preservation location.`);
    }
  }

  const prNumbers = pullRequests.map(row => row?.number);
  if (prNumbers.some(number => !Number.isInteger(number) || number < 1)) add('pull_request_number_invalid', 'Every open PR must have a positive integer number.');
  if (new Set(prNumbers).size !== prNumbers.length) add('duplicate_pull_request_number', 'Open PR numbers must be unique.');
  if (prNumbers.some((number, index) => index > 0 && prNumbers[index - 1] > number)) add('pull_request_order_invalid', 'PR records must sort by number.');
  for (const row of pullRequests) {
    if (!/^[0-9a-f]{40}$/.test(row?.head_sha ?? '') || typeof row?.base !== 'string' || !row.base.trim()) add('pull_request_identity_invalid', `PR #${row?.number ?? '(missing number)'} needs its head SHA and base.`);
    if (!Array.isArray(row?.changed_files)) add('pull_request_files_not_array', `PR #${row?.number ?? '(missing number)'} must record changed files as an array.`);
    if (!DISPOSITIONS.has(row?.disposition)) add('pull_request_disposition_invalid', `PR #${row?.number ?? '(missing number)'} has no valid release disposition.`);
    if (![row?.reason, row?.source, row?.preservation_location].every(value => typeof value === 'string' && value.trim())) {
      add('pull_request_disposition_incomplete', `PR #${row?.number ?? '(missing number)'} must include a reason, source, and preservation location.`);
    }
  }

  const entry = snapshot?.source ?? {};
  const observedPulls = Array.isArray(observed?.pull_requests) ? observed.pull_requests : [];
  const recordedPullKeys = pullRequests.map(row => `${row.number}:${row.head_sha}:${row.base}`);
  const currentPullKeys = observedPulls.map(row => `${row.number}:${row.head_sha}:${row.base}`);
  if (!sameSet(prNumbers, observedPulls.map(row => row.number))) add('pull_request_population_mismatch', 'The live open PR number set differs from the immutable entry snapshot.');
  if (!sameSet(recordedPullKeys, currentPullKeys)) add('pull_request_identity_mismatch', 'A live PR head or base differs from its immutable entry identity.');
  if (entry.trusted_main_sha !== observed?.trusted_main_sha) add('trusted_main_identity_mismatch', 'Live main no longer matches the trusted main SHA in the entry snapshot.');
  if (entry.merge_base_sha !== observed?.merge_base_sha) add('merge_base_identity_mismatch', 'The actual merge base differs from the immutable entry snapshot.');
  if (entry.inherited_checkout?.head_sha !== observed?.inherited_head_sha) add('inherited_head_identity_mismatch', 'The inherited HEAD differs from the immutable entry snapshot.');
  if (entry.inherited_checkout?.branch !== observed?.branch) add('inherited_branch_identity_mismatch', 'The inherited branch differs from the immutable entry snapshot.');

  if (!sameSet(commitShas, observed?.commit_shas ?? [])) add('inherited_commit_population_mismatch', 'The inherited commit SHA set differs from merge-base..inherited HEAD.');
  if (!sameSet(pathKeys(paths, 'committed'), observed?.committed_paths ?? [])) add('committed_path_population_mismatch', 'The committed path set differs from all changed paths in inherited commits.');
  const recordedDirty = paths.filter(row => row.kind === 'dirty').map(row => `${row.status ?? ''}\0${row.path}`);
  const currentDirty = (observed?.dirty_paths ?? []).map(row => `${row.status ?? ''}\0${row.path}`);
  if (!sameSet(recordedDirty, currentDirty)) add('dirty_path_population_mismatch', 'The inherited modified/untracked path set differs from the immutable raw status snapshot.');

  for (const raw of rawStatus) {
    const matching = paths.find(row => row.kind === 'dirty' && row.path === raw.path && row.status === raw.status);
    if (!matching) add('raw_status_unaccounted', `Raw status entry ${raw.status} ${raw.path} has no dirty-path disposition.`);
  }
  return { valid: errors.length === 0, errors };
}

function runGit(args, cwd = process.cwd()) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trimEnd();
}

function runGh(args, cwd = process.cwd()) {
  return execFileSync('gh', args, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trim();
}

function parseStatus(text) {
  return text ? text.split('\n').filter(Boolean).map(line => ({ status: line.slice(0, 2), path: line.slice(3) })) : [];
}

function observe(snapshot) {
  const repoRoot = runGit(['rev-parse', '--show-toplevel']);
  const inherited = snapshot.source.inherited_checkout;
  const branch = runGit(['branch', '--show-current']);
  const currentHead = runGit(['rev-parse', 'HEAD']);
  const remoteMain = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const localMain = runGit(['rev-parse', '--verify', 'refs/remotes/origin/main']);
  const mergeBase = runGit(['merge-base', remoteMain, inherited.head_sha]);
  const commitShas = runGit(['rev-list', `${mergeBase}..${inherited.head_sha}`]).split('\n').filter(Boolean).sort();
  const committedPaths = [...new Set(runGit(['log', '--no-renames', '--format=', '--name-only', `${mergeBase}..${inherited.head_sha}`]).split('\n').filter(Boolean))].sort();
  const rawStatus = parseStatus(runGit(['status', '--porcelain=v1', '-uall']));
  const allowed = new Set(snapshot.phase_artifacts ?? phaseArtifacts);
  const dirtyPaths = rawStatus.filter(row => !allowed.has(row.path)).map(row => ({ ...row })).sort((a, b) => `${a.status}\0${a.path}` < `${b.status}\0${b.path}` ? -1 : 1);
  const ownCommits = runGit(['rev-list', `${inherited.head_sha}..${currentHead}`]).split('\n').filter(Boolean).sort();
  const ownCommitDetails = ownCommits.map(sha => ({
    sha,
    subject: runGit(['show', '-s', '--format=%s', sha]),
    paths: runGit(['diff-tree', '--no-renames', '--no-commit-id', '--name-only', '-r', sha]).split('\n').filter(Boolean).sort(),
  }));
  const pullRequests = JSON.parse(runGh(['pr', 'list', '--repo', repository, '--state', 'open', '--limit', '1000', '--json', 'number,headRefOid,baseRefName']))
    .map(row => ({ number: row.number, head_sha: row.headRefOid, base: row.baseRefName }))
    .sort((a, b) => a.number - b.number);
  return {
    repo_root: repoRoot,
    trusted_main_sha: remoteMain,
    local_origin_main_sha: localMain,
    merge_base_sha: mergeBase,
    inherited_head_sha: inherited.head_sha,
    branch,
    current_head_sha: currentHead,
    commit_shas: commitShas,
    committed_paths: committedPaths,
    dirty_paths: dirtyPaths,
    pull_requests: pullRequests,
    own_commits: ownCommitDetails,
  };
}

function stableIdentity(observation) {
  return JSON.stringify({
    trusted_main_sha: observation.trusted_main_sha,
    local_origin_main_sha: observation.local_origin_main_sha,
    merge_base_sha: observation.merge_base_sha,
    inherited_head_sha: observation.inherited_head_sha,
    branch: observation.branch,
    commit_shas: observation.commit_shas,
    committed_paths: observation.committed_paths,
    dirty_paths: observation.dirty_paths,
    pull_requests: observation.pull_requests,
    own_commits: observation.own_commits,
  });
}

function validateWorkingCopy(snapshot, observed) {
  const errors = [];
  const source = snapshot.source ?? snapshot.entry_snapshot?.source;
  const allowed = new Set(snapshot.phase_artifacts ?? phaseArtifacts);
  const checkpointMetadata = new Set(['.planning/STATE.md', '.planning/HANDOFF.json']);
  if (observed.repo_root !== source.inherited_checkout.path) errors.push({ code: 'repository_root_changed', message: 'Validation is running from a different repository root.' });
  if (observed.local_origin_main_sha !== source.trusted_main_sha) errors.push({ code: 'origin_main_not_refreshed', message: 'The local origin/main ref does not match the live trusted main SHA.' });
  if (observed.current_head_sha !== source.inherited_checkout.head_sha) {
    if (!observed.own_commits.length) errors.push({ code: 'inherited_head_moved', message: 'HEAD moved without an allowed Phase 247 artifact commit.' });
    for (const commit of observed.own_commits) {
      const pathsAreScoped = commit.paths.length > 0 && commit.paths.every(file => allowed.has(file));
      const isTaskCommit = /^(feat|test|fix)\(247-01\):/.test(commit.subject) && pathsAreScoped;
      const isCheckpointCommit = commit.subject === 'docs(247-01): record phase 246 evidence checkpoint'
        && commit.paths.length > 0 && commit.paths.every(file => checkpointMetadata.has(file));
      if (!isTaskCommit && !isCheckpointCommit) {
        errors.push({ code: 'unexpected_post_snapshot_commit', message: `Post-snapshot commit ${commit.sha} is not scoped to this plan's artifact files.` });
      }
    }
  }
  return errors;
}

async function validateInventoryFile(artifactPath) {
  const absoluteArtifact = path.resolve(artifactPath);
  const ledger = JSON.parse(fs.readFileSync(absoluteArtifact, 'utf8'));
  const snapshot = ledger.entry_snapshot;
  if (!snapshot || typeof snapshot !== 'object') throw new Error('The ledger is missing its immutable entry_snapshot.');

  const liveContext = { ...ledger, source: snapshot.source };
  let observed = observe(liveContext);
  let collectedAgain = observe(liveContext);
  let collectionError = null;
  if (stableIdentity(observed) !== stableIdentity(collectedAgain)) {
    observed = collectedAgain;
    collectedAgain = observe(liveContext);
    if (stableIdentity(observed) !== stableIdentity(collectedAgain)) {
      collectionError = { code: 'observation_changed_during_collection', message: 'Git or GitHub source identity changed during collection; one recapture was attempted and the observations remained unstable.' };
    }
  }

  const result = validateSnapshot(snapshot, observed);
  const errors = [...result.errors, ...validateWorkingCopy(ledger, observed)];
  if (collectionError) errors.push(collectionError);
  const final = {
    valid: errors.length === 0,
    status: errors.length === 0 ? 'ready' : 'blocked',
    checked_at: new Date().toISOString(),
    checked: {
      commits: observed.commit_shas.length,
      committed_paths: observed.committed_paths.length,
      dirty_paths: observed.dirty_paths.length,
      open_pull_requests: observed.pull_requests.length,
      trusted_main_sha: observed.trusted_main_sha,
      merge_base_sha: observed.merge_base_sha,
      inherited_head_sha: observed.inherited_head_sha,
    },
    diagnostics: errors,
  };
  ledger.validation_observations ??= [];
  ledger.validation_observations.push(final);
  ledger.inventory_validation = final;
  fs.writeFileSync(absoluteArtifact, `${JSON.stringify(ledger, null, 2)}\n`);
  console.log(JSON.stringify(final, null, 2));
  return final.valid;
}

export { validateSnapshot };

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [stageFlag, stage, artifact] = process.argv.slice(2);
  if (stageFlag !== '--stage' || stage !== 'inventory' || !artifact) {
    console.error('Usage: node validate-release-readiness.mjs --stage inventory <ledger.json>');
    process.exitCode = 2;
  } else {
    try {
      const valid = await validateInventoryFile(artifact);
      if (!valid) process.exitCode = 1;
    } catch (error) {
      console.error(JSON.stringify({ valid: false, status: 'blocked', diagnostics: [{ code: 'inventory_validation_error', message: error.message }] }, null, 2));
      process.exitCode = 1;
    }
  }
}
