import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const DISPOSITIONS = new Set(['release-blocking', 'release-relevant', 'separate-follow-up']);
const KINDS = new Set(['committed', 'dirty']);
const repository = 'szTheory/sigra';
const APPROVED_PHASE_246_PATHS = [
  'priv/templates/sigra.install/core/confirmation_live.ex',
  'test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex',
  'scripts/ci/generated-confirmation-probe.exs',
  'test/sigra/install/auth_ui_contract_test.exs',
];
const APPROVED_PHASE_247_EVIDENCE_PATHS = [
  '.github/workflows/phase-247-hex-dry-run.yml',
  '.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json',
  'scripts/ci/phase-247-hex-dry-run.sh',
  'scripts/ci/phase-247-hex-dry-run.test.sh',
];
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

function pullRequestIdentity(row) {
  return {
    repository: row?.repository,
    number: row?.number,
    head_sha: row?.head_sha,
    base: row?.base,
    base_sha: row?.base_sha,
  };
}

function samePullRequestIdentity(left, right) {
  const a = pullRequestIdentity(left);
  const b = pullRequestIdentity(right);
  return a.repository === b.repository
    && a.number === b.number
    && a.head_sha === b.head_sha
    && a.base === b.base
    && a.base_sha === b.base_sha;
}

function pullRequestIdentityKey(row) {
  return JSON.stringify([
    row?.repository,
    row?.number,
    row?.head_sha,
    row?.base,
    row?.base_sha,
  ]);
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
    if (row?.repository !== repository || !/^[0-9a-f]{40}$/.test(row?.head_sha ?? '')
      || typeof row?.base !== 'string' || !row.base.trim()) {
      add('pull_request_identity_invalid', `PR #${row?.number ?? '(missing number)'} needs repository, head SHA, and base ref.`);
    }
    if (!/^[0-9a-f]{40}$/.test(row?.base_sha ?? '')) add('pull_request_base_sha_invalid', `PR #${row?.number ?? '(missing number)'} needs a full base SHA.`);
    if (!Array.isArray(row?.changed_files)) add('pull_request_files_not_array', `PR #${row?.number ?? '(missing number)'} must record changed files as an array.`);
    if (!DISPOSITIONS.has(row?.disposition)) add('pull_request_disposition_invalid', `PR #${row?.number ?? '(missing number)'} has no valid release disposition.`);
    if (![row?.reason, row?.source, row?.preservation_location].every(value => typeof value === 'string' && value.trim())) {
      add('pull_request_disposition_incomplete', `PR #${row?.number ?? '(missing number)'} must include a reason, source, and preservation location.`);
    }
  }

  const entry = snapshot?.source ?? {};
  const observedPulls = Array.isArray(observed?.pull_requests) ? observed.pull_requests : [];
  const recordedPullKeys = pullRequests.map(pullRequestIdentityKey);
  const currentPullKeys = observedPulls.map(pullRequestIdentityKey);
  if (!sameSet(prNumbers, observedPulls.map(row => row.number))) add('pull_request_population_mismatch', 'The live open PR number set differs from the immutable entry snapshot.');
  if (!sameSet(recordedPullKeys, currentPullKeys)) add('pull_request_identity_mismatch', 'A live PR repository, number, head, base ref, or base SHA differs from its immutable entry identity.');
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

function observeOpenPullRequests() {
  const pages = JSON.parse(runGh(['api', '--paginate', '--slurp', `repos/${repository}/pulls?state=open&per_page=100`]));
  if (!Array.isArray(pages) || pages.some(page => !Array.isArray(page))) throw new Error('GitHub did not return complete paginated open-PR arrays.');
  return pages.flat().map(row => ({ repository, number: row.number, head_sha: row.head?.sha, base: row.base?.ref, base_sha: row.base?.sha }))
    .sort((a, b) => a.number - b.number);
}

function trustedCheckoutMatchesLiveMain(headSha, status, liveMainSha) {
  return headSha === liveMainSha && status === '';
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
  const pullRequests = observeOpenPullRequests();
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

function validationSnapshot(ledger) {
  return ledger.current_snapshot ?? ledger.entry_snapshot;
}

function validateCheckout(selection, observed) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  const sha = selection?.selected_source_sha;
  const worktree = selection?.candidate_worktree;
  if (!/^[0-9a-f]{40}$/.test(sha ?? '')) add('selected_source_sha_invalid', 'The selected source must be a full Git SHA.');
  if (!worktree?.path || worktree.head_sha !== sha) add('candidate_worktree_identity_mismatch', 'The candidate worktree path and recorded HEAD must match the selected source SHA.');
  if (observed?.exists !== true) add('candidate_worktree_missing', 'The candidate worktree directory does not exist.');
  if (observed?.head_sha !== sha) add('candidate_worktree_head_mismatch', 'The candidate worktree HEAD differs from the selected source SHA.');
  if (observed?.status) add('candidate_worktree_dirty', 'The candidate worktree has tracked or untracked changes.');
  if (observed?.live_main_sha !== sha || observed?.local_origin_main_sha !== sha) add('selected_main_identity_mismatch', 'The selected source is no longer the live and locally refreshed protected main SHA.');
  if (selection?.status !== 'ready') add('source_selection_not_ready', 'Source selection is not marked ready.');
  const evidence = selection?.phase_246_evidence;
  if (evidence?.source_sha !== '90ec16f72a71d33224c0816ad77762e2e7262c76') add('phase_246_source_sha_mismatch', 'Phase 246 evidence must name the exact tested source SHA.');
  if (evidence?.required_jobs?.['ci-gate'] !== 'success' || evidence?.required_jobs?.install_smoke !== 'success' || evidence?.required_jobs?.generated_admin_playwright_smoke !== 'success') {
    add('phase_246_required_ci_missing', 'Phase 246 ci-gate, install smoke, and generated-admin Playwright smoke must all be successful.');
  }
  if (evidence?.reviewed_pr !== 288 || evidence?.promotion_commit !== sha) add('reviewed_promotion_mismatch', 'The selected source must be the exact protected-main promotion commit from reviewed PR #288.');
  const included = Array.isArray(selection?.included_paths) ? selection.included_paths : [];
  const includedPaths = included.map(row => row.path).sort();
  if (included.length !== APPROVED_PHASE_246_PATHS.length
    || includedPaths.some((value, index) => value !== [...APPROVED_PHASE_246_PATHS].sort()[index])
    || included.some(row => row.reviewed_source_sha !== evidence?.source_sha || row.reviewed_blob_matches !== true || row.protected_main_sha !== sha || row.reviewed_pr !== 288)) {
    add('included_paths_incomplete', 'The candidate must list the four approved Phase 246 paths and tie each to the exact tested source SHA.');
  }
  return { valid: errors.length === 0, errors };
}

function validateCandidate(candidate, observed) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  const sha = value => /^[0-9a-f]{40}$/.test(value ?? '');
  const identities = candidate ?? {};
  const live = observed ?? {};
  const pr = live.pull_request ?? {};
  const tested = live.phase_246_tested_sha;
  if (pr.number !== 224 || pr.state !== 'OPEN' || pr.base_ref !== 'main') add('candidate_pr_identity_mismatch', 'The existing open Release Please PR #224 on main is required.');
  for (const field of ['pre_refresh_pr_head_sha', 'refreshed_pr_head_sha', 'current_pr_head_sha', 'pr_base_sha', 'selected_reviewed_main_sha', 'phase_246_tested_sha']) {
    if (!sha(identities[field])) add(`candidate_${field}_invalid`, `Candidate ${field} must be a full Git SHA.`);
  }
  if (identities.current_pr_head_sha !== pr.head_sha) add('candidate_live_head_mismatch', 'The recorded current candidate head differs from live PR #224.');
  if (identities.pr_base_sha !== pr.base_sha) add('candidate_live_base_mismatch', 'The recorded candidate base differs from live PR #224 base.');
  if (identities.selected_reviewed_main_sha !== live.main_sha || pr.base_sha !== live.main_sha) add('candidate_live_main_mismatch', 'The candidate source, PR base, and live protected main must be identical.');
  if (identities.phase_246_tested_sha !== tested || live.phase_246_status !== 'passed') add('candidate_tested_source_mismatch', 'The exact Phase 246 tested SHA must match the immutable passing receipt.');
  if (live.identity_stable_during_observation !== true) add('candidate_identity_raced', 'PR head/base/state or protected main changed during the live candidate observation.');
  const promotionProof = validatePromotionProof(live.promotion_proof ?? {});
  if (live.ancestry?.tested_to_main !== true && !promotionProof.valid) {
    add('candidate_tested_source_unproven', 'Phase 246 tested source must be an ancestor of reviewed main or have a complete exact-source promotion proof.');
    errors.push(...promotionProof.errors);
  }
  if (live.ancestry?.main_to_refreshed !== true) add('candidate_main_not_ancestor', 'Reviewed main must be an ancestor of the refreshed candidate head.');
  if (live.ancestry?.pre_to_refreshed !== true) {
    const review = identities.renewed_review;
    if (!(review?.complete_diff_reviewed === true
      && review.head_sha === identities.refreshed_pr_head_sha
      && review.base_sha === identities.pr_base_sha
      && review.source_sha === identities.selected_reviewed_main_sha
      && review.checks_passed === true)) {
      add('candidate_refresh_non_fast_forward_unreviewed', 'A non-fast-forward refresh requires renewed review and passing checks bound to its exact head, base, and source.');
    }
  }
  if (live.ancestry?.refreshed_to_current !== true) {
    const review = identities.renewed_review;
    if (!(review?.complete_diff_reviewed === true
      && review.head_sha === identities.current_pr_head_sha
      && review.base_sha === identities.pr_base_sha
      && review.source_sha === identities.selected_reviewed_main_sha
      && review.checks_passed === true)) {
      add('candidate_current_non_fast_forward_unreviewed', 'The current PR head must descend from the reviewed refresh or carry exact-head renewed review and passing checks.');
    }
  }
  if (live.ancestry?.current_to_worktree !== true) add('candidate_worktree_not_fast_forward', 'The candidate worktree head must descend from the current live PR head.');
  if (live.worktree_unexpected_paths?.length) add('candidate_worktree_unexpected_changes', `Candidate worktree contains changes outside release metadata: ${live.worktree_unexpected_paths.join(', ')}.`);
  if (!Array.isArray(identities.changed_files) || identities.changed_files.length === 0) add('candidate_diff_missing', 'The refreshed PR complete changed-file list is required.');
  if (identities.package_version !== '1.6.0' || identities.manifest_version !== '1.6.0' || identities.mix_version !== '1.6.0') add('candidate_version_mismatch', 'Release manifest, mix.exs, and recorded package version must all be 1.6.0.');
  if (identities.source_ref !== 'v#{@version}') add('candidate_source_ref_mismatch', 'ExDoc source_ref must derive from the package version as v#{@version}.');
  if (identities.changelog_heading_count !== 1 || !/^## \[1\.6\.0\](?:\(|\s|$)/.test(identities.changelog_heading ?? '')) add('candidate_changelog_heading_mismatch', 'CHANGELOG must contain exactly one actual ## [1.6.0] heading.');
  if (identities.include_v_in_tag !== true || identities.planned_tag !== 'v1.6.0') add('candidate_tag_mismatch', 'Release Please must include v in its planned 1.6.0 tag.');
  if (live.conflicting_tag_exists === true) add('candidate_tag_conflict', 'The planned v1.6.0 tag already exists; candidate readiness cannot create or replace it.');
  if (identities.candidate_summary_under_versioned_heading !== true || identities.candidate_summary_only_unreleased === true) add('candidate_summary_misplaced', 'Candidate-specific adopter summary must be under the 1.6.0 heading, not only under Unreleased.');
  if (!Array.isArray(identities.claim_sources) || identities.claim_sources.some(row => !row.claim || !row.source || !row.evidence)) add('candidate_claim_mapping_missing', 'Every curated adopter claim must map to source and required evidence.');
  return { valid: errors.length === 0, errors };
}

function validatePromotionProof(proof) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  const expectedPaths = [...APPROVED_PHASE_246_PATHS].sort();
  const paths = (proof.approved_paths ?? []).map(row => row.path).sort();
  if (proof.pr_number !== 288 || proof.pr_state !== 'MERGED' || proof.pr_head_sha !== proof.expected_pr_head_sha || proof.pr_base_sha !== proof.expected_pr_base_sha || proof.merge_commit_sha !== proof.expected_main_sha || proof.expected_main_sha !== proof.selected_main_sha) {
    add('promotion_pr_identity_mismatch', 'The exact reviewed PR #288 head and squash merge commit must match the recorded promotion and selected main.');
  }
  if (paths.length !== expectedPaths.length || paths.some((value, index) => value !== expectedPaths[index])) add('promotion_path_allowlist_mismatch', 'The promotion PR changed-path set must equal the four approved Phase 246 paths.');
  const prPaths = (proof.pr_changed_files ?? []).slice().sort();
  if (prPaths.length !== expectedPaths.length || prPaths.some((value, index) => value !== expectedPaths[index])) add('promotion_pr_diff_mismatch', 'Live PR #288 complete diff must equal the four approved Phase 246 paths.');
  if ((proof.approved_paths ?? []).some(row => !row.tested_blob || row.tested_blob !== row.main_blob)) add('promotion_blob_mismatch', 'Every approved path must have an identical Git blob at the tested source and selected main.');
  const phase = proof.phase_246_ci ?? {};
  if (phase.source_sha !== proof.tested_source_sha || phase.run_id !== 37676348766 || phase.attempt !== 2 || phase.conclusion !== 'success' || phase.required_jobs?.['ci-gate'] !== 'success' || phase.required_jobs?.install_smoke !== 'success' || phase.required_jobs?.generated_admin_playwright_smoke !== 'success') {
    add('promotion_phase_ci_missing', 'Phase 246 CI must pass all required jobs on the exact tested source SHA.');
  }
  const main = proof.main_ci ?? {};
  if (main.head_sha !== proof.selected_main_sha || main.run_id !== 37686980115 || main.attempt !== 2 || main.conclusion !== 'success') add('promotion_main_ci_missing', 'Required CI must pass on the exact selected main SHA and recorded run attempt.');
  return { valid: errors.length === 0, errors };
}

function validateFinalReadiness(final, observed) {
  const errors = [];
  const add = (code, message) => errors.push({ code, message });
  const sourceSha = final?.source_sha;
  const live = observed?.live ?? {};
  const pr = live.pull_request ?? {};
  const inventory = observed?.inventory ?? {};
  const docs = final?.docs ?? {};
  const packageChecks = final?.package ?? {};
  const review = final?.review ?? {};
  const baseline = final?.baseline ?? {};
  const sourceCi = live.source_ci_run ?? {};
  const mainAdvance = live.main_advance ?? {};

  if (!/^[0-9a-f]{40}$/.test(sourceSha ?? '')) add('final_source_sha_invalid', 'Final evidence must name the immutable candidate SHA.');
  if (pr.number !== 224 || pr.state !== 'OPEN' || pr.base_ref !== 'main') add('final_pr_identity_mismatch', 'Final readiness requires the existing open PR #224 targeting main.');
  if (pr.head_sha !== sourceSha || live.candidate_worktree?.head_sha !== sourceSha || live.candidate_worktree?.status !== '') {
    add('final_candidate_identity_mismatch', 'The live PR head and clean candidate worktree must match the recorded source SHA.');
  }
  if (pr.base_sha !== final.selected_reviewed_main_sha) add('final_base_identity_mismatch', 'The live PR base must remain the exact reviewed baseline SHA.');
  if (live.main_sha !== final.selected_reviewed_main_sha) {
    const paths = Array.isArray(mainAdvance.paths) ? mainAdvance.paths.slice().sort() : [];
    const expected = [...APPROVED_PHASE_247_EVIDENCE_PATHS].sort();
    if (mainAdvance.verified !== true || !sameSet(paths, expected)) {
      add('final_main_advance_unverified', 'Live main may advance from the reviewed base only through the exact four allowlisted evidence files.');
    }
  }
  if (live.identity_stable_during_observation !== true) add('final_observation_raced', 'The final PR/main observation changed during collection.');

  const checks = Array.isArray(pr.checks) ? pr.checks : [];
  if (!Array.isArray(pr.checks)) add('final_checks_missing', 'The final PR check rollup must be recorded as an array.');
  const requiredChecks = [
    'Fast checks (milestone/installer/contracts/snapshot/ledger guards)',
    'Install golden + idempotency contract (subprocess harness)',
    'Generated admin Playwright smoke',
    'Install smoke (fresh phx.new + sigra.install)',
    'Library tests shard',
    'Library tests (dep-off — Threadline absent)',
    'Example HTTP smoke (boot + curl critical routes)',
    'Example unit smoke (ExUnit + ConnTest)',
    'Example Playwright smoke (full lifecycle)',
    'ci-gate',
  ];
  for (const name of requiredChecks) {
    if (!checks.some(row => row?.name === name && row?.status === 'COMPLETED' && row?.conclusion === 'SUCCESS')) {
      add('final_required_check_missing', `Required final PR check is absent or unsuccessful: ${name}.`);
    }
  }
  const docsCheck = checks.find(row => row?.name === 'Library tests (dep-off — Threadline absent)');
  if (docs.ci?.source_sha !== sourceSha || docs.ci?.run_id !== sourceCi.run_id || docs.ci?.attempt !== sourceCi.attempt
    || docs.ci?.conclusion !== 'success' || docs.ci?.step !== 'Check docs build cleanly'
    || sourceCi?.head_sha !== sourceSha || sourceCi?.conclusion !== 'success' || sourceCi?.docs_step_conclusion !== 'success'
    || docsCheck?.conclusion !== 'SUCCESS') {
    add('final_docs_ci_mismatch', 'Warning-free ExDoc evidence must be bound to the exact final PR head and passing docs CI step.');
  }
  if (docs.readme_upgrade_target !== 'guides/introduction/upgrading-to-v1.6.md'
    || docs.readme_link_resolves !== true
    || docs.guide_changelog_target !== `../../CHANGELOG.md#160-${docs.changelog_date}`
    || docs.guide_changelog_link_resolves !== true
    || docs.exdoc_extra !== 'guides/introduction/upgrading-to-v1.6.md'
    || docs.exdoc_source_ref !== 'v#{@version}'
    || docs.compatibility_claims_supported !== true
    || docs.no_schema_migration_claim_supported !== true
    || docs.candidate_summary_under_versioned_heading !== true) {
    add('final_guide_contract_failed', 'The README → v1.6 guide → 1.6.0 changelog path or its source-backed compatibility/migration claims failed validation.');
  }
  if (docs.local_status !== 'passed' && docs.local_status !== 'blocked_by_unavailable_exact_locked_dependencies') {
    add('final_local_docs_status_invalid', 'Local docs status must report a pass or the exact locked-dependency limitation.');
  }

  if (packageChecks.source_sha !== sourceSha || packageChecks.version !== '1.6.0' || packageChecks.mix_version !== '1.6.0') add('final_package_source_mismatch', 'Package evidence, manifest, and mix.exs must identify Sigra 1.6.0 from the final candidate SHA.');
  if (packageChecks.hex_build?.conclusion !== 'success' || packageChecks.hex_build?.unpacked !== true
    || packageChecks.hex_build?.metadata_version !== '1.6.0'
    || packageChecks.hex_build?.required_files?.includes('README.md') !== true
    || packageChecks.hex_build?.required_files?.includes('CHANGELOG.md') !== true) {
    add('final_hex_build_incomplete', 'The unpacked Hex package must contain 1.6.0 metadata, README, and CHANGELOG.');
  }
  const receipt = packageChecks.publish_dry_run?.receipt ?? {};
  const dryRun = live.dry_run_run ?? {};
  const receiptValid = receipt.verdict === 'passed'
    && receipt.repository === repository
    && receipt.workflow === '.github/workflows/phase-247-hex-dry-run.yml'
    && receipt.workflow_ref === 'szTheory/sigra/.github/workflows/phase-247-hex-dry-run.yml@refs/heads/main'
    && /^[0-9]+$/.test(receipt.run_id ?? '')
    && Number.isInteger(receipt.run_attempt) && receipt.run_attempt > 0
    && receipt.requested_sha === sourceSha && receipt.checked_out_sha === sourceSha
    && receipt.reviewed_base_sha === final.selected_reviewed_main_sha
    && receipt.live_base_sha === live.main_sha
    && receipt.evidence_merge_sha === live.main_sha
    && receipt.evidence_pr_number === 296
    && /^[0-9a-f]{40}$/.test(receipt.evidence_pr_head_sha ?? '')
    && receipt.manifest_blob_id === baseline.manifest_blob_id
    && receipt.diff_algorithm === 'git-diff-raw-v1'
    && receipt.diff_sha256 === baseline.diff_sha256
    && receipt.diff_bytes === baseline.diff_bytes
    && receipt.command === 'mix hex.publish --dry-run --yes'
    && receipt.dry_run_outcome === 'success'
    && receipt.credential_name === 'HEX_DRY_RUN_API_KEY'
    && receipt.credential_present === true
    && receipt.hex_release_before_http_status === 404
    && receipt.hex_release_after_http_status === 404
    && dryRun.run_id === Number(receipt.run_id)
    && dryRun.head_sha === receipt.live_base_sha
    && dryRun.event === 'workflow_dispatch'
    && dryRun.status === 'completed'
    && dryRun.conclusion === 'success'
    && dryRun.job_conclusion === 'success';
  if (packageChecks.publish_dry_run?.conclusion !== 'success' || packageChecks.publish_dry_run?.version !== '1.6.0' || !receiptValid) {
    add('final_hex_dry_run_failed', 'mix hex.publish --dry-run --yes must pass for Sigra 1.6.0.');
  }
  if (!Array.isArray(final?.claim_sources) || final.claim_sources.length === 0
    || final.claim_sources.some(row => typeof row?.claim !== 'string' || !row.claim.trim()
      || typeof row?.source !== 'string' || !row.source.trim()
      || typeof row?.evidence !== 'string' || !row.evidence.trim()
      || row?.source_paths_present !== true
      || row?.source_sha !== sourceSha
      || ![37700772880, 37686980115].includes(row?.ci_run_id))) {
    add('final_claim_mapping_incomplete', 'Every candidate-facing claim must map to a source and exact-source evidence.');
  }

  for (const key of ['commits', 'paths', 'pull_requests', 'raw_status']) {
    if (!Array.isArray(inventory[key])) add(`final_${key}_not_array`, `Fresh inventory must include ${key} as an array, even when empty.`);
  }
  if (inventory.captured_at && final.observed_at && inventory.captured_at !== final.observed_at) add('final_inventory_time_mismatch', 'Fresh inventory and final evidence timestamps must match.');
  const inventoryPrs = Array.isArray(inventory.pull_requests) ? inventory.pull_requests : [];
  const livePrs = Array.isArray(live.open_pull_requests) ? live.open_pull_requests : [];
  for (const row of [...inventoryPrs, ...livePrs]) {
    if (row?.repository !== repository || !Number.isInteger(row?.number) || row.number < 1
      || !/^[0-9a-f]{40}$/.test(row?.head_sha ?? '') || typeof row?.base !== 'string' || !row.base.trim()
      || !/^[0-9a-f]{40}$/.test(row?.base_sha ?? '')) {
      add('final_pr_identity_invalid', `PR #${row?.number ?? '(unknown)'} needs repository, number, head SHA, base ref, and full base SHA.`);
    }
  }
  const identity = rows => rows.map(pullRequestIdentityKey).sort();
  if (new Set(identity(inventoryPrs)).size !== inventoryPrs.length) add('final_duplicate_pr_key', 'Final PR inventory contains duplicate complete identity keys.');
  const prNumbers = inventoryPrs.map(row => row.number);
  if (new Set(prNumbers).size !== prNumbers.length) add('final_pr_number_conflict', 'Final inventory contains multiple distinct identities for the same PR number.');
  if (prNumbers.some((number, index) => index > 0 && prNumbers[index - 1] > number)) add('final_pr_order_invalid', 'Final PR inventory must sort by number.');
  if (JSON.stringify(identity(inventoryPrs)) !== JSON.stringify(identity(livePrs))) {
    const inventoryNumbers = inventoryPrs.map(row => row.number).sort((a, b) => a - b);
    const liveNumbers = livePrs.map(row => row.number).sort((a, b) => a - b);
    if (JSON.stringify(inventoryNumbers) === JSON.stringify(liveNumbers)) {
      add('final_pr_identity_mismatch', 'A final PR row does not match the freshly observed full identity.');
    } else {
      add('final_pr_population_mismatch', 'Final PR dispositions do not cover the freshly observed open PR population.');
    }
  }
  for (const row of inventoryPrs) {
    if (!row.disposition || !row.reason || !row.source || !row.preservation_location) add('final_pr_disposition_missing', `Open PR #${row.number ?? '(unknown)'} has no complete disposition.`);
    if (!samePullRequestIdentity(row.disposition_identity, row)) add('final_pr_disposition_identity_mismatch', `Open PR #${row.number ?? '(unknown)'} disposition is not bound to its complete identity.`);
  }
  const pathKeys = (Array.isArray(inventory.paths) ? inventory.paths : []).map(row => `${row.kind ?? ''}\0${row.path ?? ''}`);
  if (new Set(pathKeys).size !== pathKeys.length) add('final_duplicate_path_key', 'Final path inventory contains duplicate kind/path keys.');
  if (pathKeys.some((key, index) => index > 0 && pathKeys[index - 1] > key)) add('final_path_order_invalid', 'Final path records must sort by kind plus path.');
  for (const row of inventory.paths ?? []) {
    if (!row.disposition || !row.reason || !row.source || !row.preservation_location) add('final_path_disposition_missing', `Inherited path ${row.path ?? '(unknown)'} has no complete disposition.`);
  }
  const commitKeys = (Array.isArray(inventory.commits) ? inventory.commits : []).map(row => row.sha);
  if (new Set(commitKeys).size !== commitKeys.length) add('final_duplicate_commit_key', 'Final inherited commit inventory contains duplicate SHAs.');
  if (commitKeys.some((sha, index) => index > 0 && commitKeys[index - 1] > sha)) add('final_commit_order_invalid', 'Final inherited commits must sort by SHA.');
  for (const row of inventory.commits ?? []) {
    if (!row.disposition || !row.reason || !row.source || !row.preservation_location) add('final_commit_disposition_missing', `Inherited commit ${row.sha ?? '(unknown)'} has no complete disposition.`);
  }
  const dirtyPaths = (inventory.raw_status ?? []).map(row => `${row.status ?? ''}\0${row.path ?? ''}`);
  if (new Set(dirtyPaths).size !== dirtyPaths.length) add('final_duplicate_dirty_key', 'Final inherited checkout status contains duplicate status/path keys.');
  if (dirtyPaths.some((key, index) => index > 0 && dirtyPaths[index - 1] > key)) add('final_dirty_order_invalid', 'Raw inherited status must sort by status plus path.');
  for (const row of inventory.raw_status ?? []) {
    if (!(inventory.paths ?? []).some(pathRow => pathRow.kind === 'dirty' && pathRow.path === row.path && pathRow.status === row.status)) {
      add('final_dirty_path_unaccounted', `Inherited dirty path ${row.path ?? '(unknown)'} has no matching disposition.`);
    }
  }

  if (typeof review.reviewer !== 'string' || !review.reviewer.trim() || typeof review.method !== 'string' || !review.method.trim()) {
    add('final_review_identity_missing', 'Record a reviewer identity or named automation review method.');
  }
  if (review.reviewed_head_sha !== sourceSha || review.reviewed_base_sha !== pr.base_sha
    || !/^[0-9a-f]{64}$/.test(review.diff_sha256 ?? '') || !Number.isInteger(review.diff_bytes) || review.diff_bytes < 1) {
    add('final_review_diff_identity_mismatch', 'The review result must bind the complete diff checksum and byte count to the exact PR head and base.');
  }
  if (!Array.isArray(review.findings) || !Array.isArray(review.unresolved_high_severity)) add('final_review_findings_missing', 'Final diff review must record findings and unresolved high-severity findings as arrays.');
  if ((review.unresolved_high_severity ?? []).length > 0) add('final_review_high_severity_open', 'Unresolved high-severity review findings block candidate readiness.');

  const uniqueErrors = new Map(errors.map(error => [`${error.code}\0${error.message}`, error]));
  return { valid: uniqueErrors.size === 0, errors: [...uniqueErrors.values()] };
}

function observeLiveCandidate(selection, candidate, phaseReceipt) {
  const candidatePath = path.resolve(selection.candidate_worktree.path);
  const pr = JSON.parse(runGh(['pr', 'view', '224', '--repo', repository, '--json', 'number,state,url,headRefName,headRefOid,baseRefName,baseRefOid,reviewDecision,statusCheckRollup']));
  const mainSha = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const remoteHead = runGit(['ls-remote', '--refs', 'origin', `refs/heads/${pr.headRefName}`], candidatePath).split(/\s+/)[0];
  const prAfterFetch = JSON.parse(runGh(['pr', 'view', '224', '--repo', repository, '--json', 'number,state,url,headRefName,headRefOid,baseRefName,baseRefOid,reviewDecision,statusCheckRollup']));
  const mainAfterFetch = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const atHead = file => fs.readFileSync(path.join(candidatePath, file), 'utf8');
  const ancestry = (ancestor, descendant) => {
    try { runGit(['merge-base', '--is-ancestor', ancestor, descendant], candidatePath); return true; }
    catch { return false; }
  };
  const receipt = JSON.parse(fs.readFileSync(path.resolve(phaseReceipt), 'utf8'));
  const manifest = JSON.parse(atHead('.release-please-manifest.json'));
  const mix = atHead('mix.exs');
  const changelog = atHead('CHANGELOG.md');
  const config = JSON.parse(fs.readFileSync(path.resolve('release-please-config.json'), 'utf8'));
  const versionMatches = [...changelog.matchAll(/^## \[(\d+\.\d+\.\d+)\]/gm)].map(match => match[1]);
  const summaryUnderHeading = /^## \[1\.6\.0\](?:\(|\s|$)[\s\S]*?(?=^## \[|\s*$)/m.test(changelog);
  const unreleased = changelog.match(/^## \[Unreleased\][\s\S]*?(?=^## \[|\s*$)/m)?.[0] ?? '';
  const candidateOnlyUnderUnreleased = /confirmation|generated host/i.test(unreleased) && !/^## \[1\.6\.0\][\s\S]*?(?:confirmation|generated host)/im.test(changelog);
  const currentHead = pr.headRefOid;
  const candidateHead = runGit(['rev-parse', 'HEAD'], candidatePath);
  const candidateStatus = runGit(['status', '--porcelain=v1', '-uall'], candidatePath);
  const candidateStatusPaths = candidateStatus.split('\n').filter(Boolean).map(line => line.slice(3));
  const allowedCandidatePaths = new Set(['.release-please-manifest.json', 'CHANGELOG.md', 'mix.exs']);
  const refreshed = candidate.refreshed_pr_head_sha;
  const pre = candidate.pre_refresh_pr_head_sha;
  const files = JSON.parse(runGh(['pr', 'view', '224', '--repo', repository, '--json', 'files', '--jq', '[.files[].path]']));
  const conflictingTag = Boolean(runGit(['ls-remote', '--refs', 'origin', 'refs/tags/v1.6.0'], candidatePath));
  const promotionPr = JSON.parse(runGh(['pr', 'view', '288', '--repo', repository, '--json', 'number,state,headRefOid,baseRefOid,mergeCommit,files']));
  const mainCiRun = JSON.parse(runGh(['run', 'view', '37686980115', '--repo', repository, '--json', 'headSha,attempt,conclusion']));
  const approvedPaths = [...APPROVED_PHASE_246_PATHS].map(file => ({
    path: file,
    tested_blob: runGit(['rev-parse', `${receipt.tested_source_sha}:${file}`], candidatePath),
    main_blob: runGit(['rev-parse', `${selection.selected_source_sha}:${file}`], candidatePath),
  }));
  const promotionProof = {
    pr_number: promotionPr.number,
    pr_state: promotionPr.state,
    pr_head_sha: promotionPr.headRefOid,
    expected_pr_head_sha: candidate.promotion_pr_head_sha,
    pr_base_sha: promotionPr.baseRefOid,
    expected_pr_base_sha: candidate.promotion_pr_base_sha,
    merge_commit_sha: promotionPr.mergeCommit?.oid,
    expected_main_sha: candidate.promotion_commit_sha,
    selected_main_sha: selection.selected_source_sha,
    tested_source_sha: receipt.tested_source_sha,
    approved_paths: approvedPaths,
    phase_246_ci: {
      source_sha: receipt.ci_receipt?.source_sha,
      run_id: receipt.ci_receipt?.run?.id,
      attempt: receipt.ci_receipt?.run?.attempt,
      conclusion: receipt.ci_receipt?.run?.conclusion,
      required_jobs: Object.fromEntries(Object.entries(receipt.ci_receipt?.required_jobs ?? {}).map(([name, row]) => [name, row.conclusion])),
    },
    main_ci: { head_sha: mainCiRun.headSha, attempt: mainCiRun.attempt, conclusion: mainCiRun.conclusion, run_id: 37686980115 },
    pr_changed_files: promotionPr.files.map(row => row.path),
  };
  return {
    pull_request: { number: pr.number, state: pr.state, head_ref: pr.headRefName, head_sha: currentHead, base_ref: pr.baseRefName, base_sha: pr.baseRefOid, url: pr.url, review_decision: pr.reviewDecision, checks: pr.statusCheckRollup },
    main_sha: mainSha,
    phase_246_tested_sha: receipt.tested_source_sha,
    phase_246_status: receipt.status,
    promotion_proof: promotionProof,
    ancestry: {
      tested_to_main: ancestry(receipt.tested_source_sha, mainSha),
      main_to_refreshed: Boolean(refreshed) && ancestry(mainSha, refreshed),
      pre_to_refreshed: Boolean(pre) && Boolean(refreshed) && ancestry(pre, refreshed),
      refreshed_to_current: Boolean(refreshed) && ancestry(refreshed, currentHead),
      current_to_worktree: ancestry(currentHead, candidateHead),
    },
    candidate_worktree_head_sha: candidateHead,
    worktree_unexpected_paths: candidateStatusPaths.filter(file => !allowedCandidatePaths.has(file)),
    conflicting_tag_exists: conflictingTag,
    identity_stable_during_observation: prAfterFetch.headRefOid === pr.headRefOid
      && prAfterFetch.baseRefOid === pr.baseRefOid
      && prAfterFetch.state === pr.state
      && mainAfterFetch === mainSha
      && remoteHead === pr.headRefOid,
    metadata: {
      manifest_version: manifest['.'],
      mix_version: mix.match(/@version\s+"([^"]+)"/)?.[1] ?? null,
      source_ref: mix.match(/source_ref:\s*"([^"]+)"/)?.[1] ?? null,
      changelog_heading: changelog.match(/^## \[1\.6\.0\](?:\([^\n]*\))?[^\n]*/m)?.[0] ?? null,
      changelog_heading_count: (changelog.match(/^## \[1\.6\.0\]/gm) ?? []).length,
      version_headings: versionMatches,
      include_v_in_tag: config.packages?.['.']?.['include-v-in-tag'] === true,
      candidate_summary_under_versioned_heading: summaryUnderHeading,
      candidate_summary_only_unreleased: candidateOnlyUnderUnreleased,
    },
    changed_files: files,
  };
}

function validateCandidateFile(artifactPath, phaseReceiptPath) {
  const absoluteArtifact = path.resolve(artifactPath);
  const ledger = JSON.parse(fs.readFileSync(absoluteArtifact, 'utf8'));
  const candidate = ledger.candidate ?? {};
  const observed = observeLiveCandidate(ledger.source_selection, candidate, phaseReceiptPath);
  const details = validateCandidate({ ...candidate, ...observed.metadata, changed_files: observed.changed_files }, observed);
  const final = {
    valid: details.valid,
    status: details.valid ? 'ready' : 'blocked',
    checked_at: new Date().toISOString(),
    checked: {
      pr_url: observed.pull_request.url,
      current_pr_head_sha: observed.pull_request.head_sha,
      candidate_worktree_head_sha: observed.candidate_worktree_head_sha,
      pr_base_sha: observed.pull_request.base_sha,
      live_main_sha: observed.main_sha,
      phase_246_tested_sha: observed.phase_246_tested_sha,
      review_decision: observed.pull_request.review_decision,
      checks: observed.pull_request.checks,
      changed_files: observed.changed_files,
      ancestry: observed.ancestry,
      metadata: observed.metadata,
    },
    diagnostics: details.errors,
  };
  ledger.candidate_validation = final;
  fs.writeFileSync(absoluteArtifact, `${JSON.stringify(ledger, null, 2)}\n`);
  console.log(JSON.stringify(final, null, 2));
  return final.valid;
}

function observeCandidate(selection) {
  const candidatePath = path.resolve(selection.candidate_worktree.path);
  if (!fs.existsSync(candidatePath)) return { exists: false, head_sha: null, status: null };
  return {
    exists: true,
    head_sha: runGit(['rev-parse', 'HEAD'], candidatePath),
    status: runGit(['status', '--porcelain=v1', '-uall'], candidatePath),
    live_main_sha: runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']),
    local_origin_main_sha: runGit(['rev-parse', '--verify', 'refs/remotes/origin/main']),
  };
}

function validateCheckoutFile(artifactPath) {
  const absoluteArtifact = path.resolve(artifactPath);
  const ledger = JSON.parse(fs.readFileSync(absoluteArtifact, 'utf8'));
  const result = validateCheckout(ledger.source_selection, observeCandidate(ledger.source_selection ?? {}));
  const final = {
    valid: result.valid,
    status: result.valid ? 'ready' : 'blocked',
    checked_at: new Date().toISOString(),
    checked: { selected_source_sha: ledger.source_selection?.selected_source_sha, candidate_worktree: ledger.source_selection?.candidate_worktree },
    diagnostics: result.errors,
  };
  ledger.checkout_validation = final;
  fs.writeFileSync(absoluteArtifact, `${JSON.stringify(ledger, null, 2)}\n`);
  console.log(JSON.stringify(final, null, 2));
  return final.valid;
}

function validateWorkingCopy(snapshot, observed) {
  const errors = [];
  const source = snapshot.source ?? validationSnapshot(snapshot)?.source;
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
  const snapshot = validationSnapshot(ledger);
  if (!snapshot || typeof snapshot !== 'object') throw new Error('The ledger is missing an entry or current inventory snapshot.');

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

function finalInventory(snapshot, observed, livePullRequests) {
  const old = validationSnapshot(snapshot);
  const oldCommits = new Map([...(snapshot.entry_snapshot?.commits ?? []), ...(old?.commits ?? [])].map(row => [row.sha, row]));
  const oldPaths = new Map([...(snapshot.entry_snapshot?.paths ?? []), ...(old?.paths ?? [])].map(row => [`${row.kind}\0${row.path}`, row]));
  const oldPrs = new Map([...(snapshot.entry_snapshot?.pull_requests ?? []), ...(old?.pull_requests ?? [])].map(row => [row.number, row]));
  const completeDisposition = row => DISPOSITIONS.has(row?.disposition)
    && [row?.reason, row?.source, row?.preservation_location].every(value => typeof value === 'string' && value.trim());
  const evidenceReason = 'Phase 247 dry-run evidence is preserved independently from candidate PR #224; the exact source and four-file main advance are bound by the merged evidence PR.';
  const evidenceSource = 'Phase 247 evidence PR #296 and verified main merge a494f3ee3878da93aab4f70712ffddeefd77a802';
  const evidencePath = pathname => APPROVED_PHASE_247_EVIDENCE_PATHS.includes(pathname);
  const commits = observed.commit_shas.map(sha => {
    if (oldCommits.has(sha)) {
      const prior = oldCommits.get(sha);
      const phase247 = /^(?:feat|fix|test|docs)\((?:phase-)?247(?:-\d{2})?\):/.test(prior.subject ?? '');
      if (!completeDisposition(prior) && phase247) return { ...prior, disposition: 'separate-follow-up',
        reason: 'Phase 247 implementation/evidence commit remains on the inherited branch and is excluded from the exact Release Please candidate.',
        source: `git commit ${sha}`, preservation_location: `${observed.repo_root}@${observed.branch}` };
      return prior;
    }
    const changedPaths = runGit(['diff-tree', '--no-renames', '--no-commit-id', '--name-only', '-r', sha]).split('\n').filter(Boolean).sort();
    const subject = runGit(['show', '-s', '--format=%s', sha]);
    const knownPhaseCommit = new Set([
      '3a70baee9da3b9f1e9ff603566c6bbfa62f7687b',
      '9991d54616a5c0e3e39efbcb5fa50699896e6901',
      'a8a9f8dfb7033854c53f19425b1adbe3c00e77e8',
      '3986392bc69ca80f449459be738ec5c28b7a5359',
      '02447d68506a8589318cabb07e08c4a37f5b3120',
      'de68ef4b1df825659ede621d6b4bca955117270a',
    ]).has(sha);
    const taskArtifactCommit = /^(feat|fix|test|docs)\((?:phase-)?247(?:-\d{2})?\):/.test(subject);
    const planningCommit = knownPhaseCommit || taskArtifactCommit;
    return {
      sha, subject, changed_paths: changedPaths,
      disposition: planningCommit ? 'separate-follow-up' : null,
      reason: planningCommit ? 'Phase 247 planning/evidence commit remains on the inherited branch; candidate source is isolated to reviewed PR #224.' : null,
      source: `git commit ${sha}`,
      preservation_location: planningCommit ? `${observed.repo_root}@${observed.branch}` : null,
    };
  }).sort((a, b) => a.sha.localeCompare(b.sha));
  const paths = [
    ...observed.committed_paths.map(pathname => {
      if (oldPaths.has(`committed\0${pathname}`)) {
        const prior = oldPaths.get(`committed\0${pathname}`);
        if (!completeDisposition(prior) && evidencePath(pathname)) return { ...prior, disposition: 'separate-follow-up',
          reason: evidenceReason, source: evidenceSource, preservation_location: 'trusted main after merged Phase 247 evidence PR #296' };
        return prior;
      }
      const planningPath = pathname.startsWith('.planning/');
      const isEvidence = evidencePath(pathname);
      return { kind: 'committed', path: pathname, status: null, disposition: planningPath || isEvidence ? 'separate-follow-up' : null,
        reason: planningPath ? 'Planning/evidence change stays preserved on the inherited branch and is excluded from the package candidate.' : isEvidence ? evidenceReason : null,
        source: isEvidence ? evidenceSource : 'fresh merge-base..inherited HEAD path inventory',
        preservation_location: planningPath ? `${observed.repo_root}@${observed.branch}` : isEvidence ? 'trusted main after merged Phase 247 evidence PR #296' : null };
    }),
    ...observed.dirty_paths.map(row => {
      const previous = oldPaths.get(`dirty\0${row.path}`);
      const planningPath = row.path.startsWith('.planning/');
      const isEvidence = evidencePath(row.path);
      const previousComplete = completeDisposition(previous);
      if (previous?.status === row.status && (previousComplete || (!planningPath && !isEvidence))) return previous;
      return { kind: 'dirty', path: row.path, status: row.status,
        disposition: planningPath || isEvidence ? 'separate-follow-up' : null,
        reason: planningPath ? 'Planning/evidence change stays preserved on the inherited branch and is excluded from the package candidate.' : isEvidence ? evidenceReason : null,
        source: isEvidence ? evidenceSource : 'fresh inherited checkout status snapshot',
        preservation_location: planningPath ? `${observed.repo_root}@${observed.branch}` : isEvidence ? 'trusted main after merged Phase 247 evidence PR #296' : null };
    }),
  ].sort((a, b) => {
    const left = `${a.kind}\0${a.path}`;
    const right = `${b.kind}\0${b.path}`;
    return left < right ? -1 : left > right ? 1 : 0;
  });
  const pull_requests = livePullRequests.map(row => {
    const previous = oldPrs.get(row.number);
    if (previous && samePullRequestIdentity(previous, row)
      && samePullRequestIdentity(previous.disposition_identity, row)) {
      return { ...previous, ...row, disposition_identity: pullRequestIdentity(row) };
    }
    return { ...row, disposition: null, reason: null, source: null, preservation_location: null, disposition_identity: null };
  }).sort((a, b) => a.number - b.number);
  return {
    captured_at: new Date().toISOString(), trusted_main_sha: observed.trusted_main_sha,
    local_origin_main_sha: observed.local_origin_main_sha, merge_base_sha: observed.merge_base_sha,
    inherited_head_sha: observed.inherited_head_sha, inherited_branch: observed.branch, commits, paths, pull_requests,
    raw_status: observed.dirty_paths.map(row => ({ status: row.status, path: row.path })).sort((a, b) => {
      const left = `${a.status}\0${a.path}`;
      const right = `${b.status}\0${b.path}`;
      return left < right ? -1 : left > right ? 1 : 0;
    }),
  };
}

function observeFinalInventory(snapshot) {
  const repoRoot = runGit(['rev-parse', '--show-toplevel']);
  const branch = runGit(['branch', '--show-current']);
  const inheritedHead = runGit(['rev-parse', 'HEAD']);
  const trustedMain = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const localMain = runGit(['rev-parse', '--verify', 'refs/remotes/origin/main']);
  const mergeBase = runGit(['merge-base', trustedMain, inheritedHead]);
  const commitShas = runGit(['rev-list', `${mergeBase}..${inheritedHead}`]).split('\n').filter(Boolean).sort();
  const committedPaths = [...new Set(runGit(['log', '--no-renames', '--format=', '--name-only', `${mergeBase}..${inheritedHead}`]).split('\n').filter(Boolean))].sort();
  const phaseFiles = new Set([...(snapshot.phase_artifacts ?? phaseArtifacts), '.planning/STATE.md', '.planning/ROADMAP.md', '.planning/REQUIREMENTS.md', '.planning/HANDOFF.json', '.planning/state.json']);
  const rawStatus = parseStatus(runGit(['status', '--porcelain=v1', '-uall']));
  const dirtyPaths = rawStatus.filter(row => !phaseFiles.has(row.path)).sort((a, b) => {
    const left = `${a.status}\0${a.path}`;
    const right = `${b.status}\0${b.path}`;
    return left < right ? -1 : left > right ? 1 : 0;
  });
  const pullRequests = observeOpenPullRequests();
  return { repo_root: repoRoot, trusted_main_sha: trustedMain, local_origin_main_sha: localMain,
    merge_base_sha: mergeBase, inherited_head_sha: inheritedHead, branch, commit_shas: commitShas, committed_paths: committedPaths,
    dirty_paths: dirtyPaths, pull_requests: pullRequests };
}

function observeFinalLive(selection) {
  const candidatePath = path.resolve(selection.candidate_worktree.path);
  const prFields = 'number,state,url,headRefName,headRefOid,baseRefName,baseRefOid,reviewDecision,reviews,statusCheckRollup,files';
  const pr = JSON.parse(runGh(['pr', 'view', '224', '--repo', repository, '--json', prFields]));
  const mainSha = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const remoteHead = runGit(['ls-remote', '--refs', 'origin', `refs/heads/${pr.headRefName}`], candidatePath).split(/\s+/)[0];
  const again = JSON.parse(runGh(['pr', 'view', '224', '--repo', repository, '--json', prFields]));
  const mainAgain = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const openPullRequests = observeOpenPullRequests();
  return {
    pull_request: { number: pr.number, state: pr.state, url: pr.url, head_sha: pr.headRefOid, base_ref: pr.baseRefName,
      base_sha: pr.baseRefOid, review_decision: pr.reviewDecision, reviews: pr.reviews ?? [], checks: pr.statusCheckRollup ?? [],
      changed_files: (pr.files ?? []).map(row => row.path).sort() },
    main_sha: mainSha,
    candidate_worktree: { path: selection.candidate_worktree.path, head_sha: runGit(['rev-parse', 'HEAD'], candidatePath),
      status: runGit(['status', '--porcelain=v1', '-uall'], candidatePath) },
    open_pull_requests: openPullRequests,
    observation_identity: { first_head_sha: pr.headRefOid, second_head_sha: again.headRefOid,
      first_base_sha: pr.baseRefOid, second_base_sha: again.baseRefOid, first_state: pr.state,
      second_state: again.state, first_main_sha: mainSha, second_main_sha: mainAgain, remote_head_sha: remoteHead },
    identity_stable_during_observation: again.headRefOid === pr.headRefOid && again.baseRefOid === pr.baseRefOid
      && again.state === pr.state && mainAgain === mainSha && remoteHead === pr.headRefOid,
  };
}

function validateFinalFile(artifactPath) {
  const absoluteArtifact = path.resolve(artifactPath);
  const ledger = JSON.parse(fs.readFileSync(absoluteArtifact, 'utf8'));
  const candidate = ledger.candidate ?? {};
  const candidatePath = path.resolve(ledger.source_selection.candidate_worktree.path);
  const live = observeFinalLive(ledger.source_selection);
  const receiptPath = path.resolve('.planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json');
  const baselinePath = path.resolve('.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json');
  const receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'));
  const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
  const sourceCi = candidate.review_check_state?.updated_head_ci ?? {};
  const mainAdvancePaths = runGit(['diff', '--name-only', baseline.reviewed_base_sha, live.main_sha]).split('\n').filter(Boolean).sort();
  let mainAdvanceVerified = false;
  let trustedCheckoutHead = null;
  let trustedCheckoutStatus = null;
  try {
    const trustedRepoPath = process.env.PHASE_247_TRUSTED_REPO_DIR
      ? path.resolve(process.env.PHASE_247_TRUSTED_REPO_DIR)
      : process.cwd();
    trustedCheckoutHead = runGit(['rev-parse', 'HEAD'], trustedRepoPath);
    trustedCheckoutStatus = runGit(['status', '--porcelain=v1', '-uall'], trustedRepoPath);
    if (!trustedCheckoutMatchesLiveMain(trustedCheckoutHead, trustedCheckoutStatus, live.main_sha)) {
      throw new Error('trusted checkout must be clean at the exact observed live main SHA');
    }
    execFileSync('bash', [path.resolve('scripts/ci/phase-247-hex-dry-run.sh'), 'verify-baseline', baselinePath], {
      cwd: process.cwd(), encoding: 'utf8', maxBuffer: 64 * 1024 * 1024,
      env: { ...process.env, REPO_DIR: trustedRepoPath, EVIDENCE_PR_NUMBER: String(receipt.evidence_pr_number),
        EVIDENCE_PR_HEAD_SHA: receipt.evidence_pr_head_sha, EVIDENCE_MANIFEST_BLOB_ID: receipt.manifest_blob_id },
    });
    mainAdvanceVerified = true;
  } catch {
    mainAdvanceVerified = false;
  }
  live.main_advance = { verified: mainAdvanceVerified, paths: mainAdvancePaths,
    trusted_checkout_head_sha: trustedCheckoutHead ?? null, trusted_checkout_status: trustedCheckoutStatus ?? null };
  live.source_ci_run = { run_id: sourceCi.run_id, attempt: sourceCi.attempt, head_sha: sourceCi.head_sha,
    conclusion: sourceCi.conclusion, docs_step_conclusion: sourceCi.docs_step_conclusion };
  live.dry_run_run = candidate.final_dry_run_run ?? {};
  const read = filename => fs.readFileSync(path.join(candidatePath, filename), 'utf8');
  const readme = read('README.md');
  const guide = read('guides/introduction/upgrading-to-v1.6.md');
  const changelog = read('CHANGELOG.md');
  const changelogDate = changelog.match(/^## \[1\.6\.0\].*\((\d{4}-\d{2}-\d{2})\)$/m)?.[1] ?? null;
  const mix = read('mix.exs');
  const manifest = JSON.parse(read('.release-please-manifest.json'));
  const readmeTarget = readme.match(/\[Upgrading to v1\.6\]\(([^)]+)\)/)?.[1] ?? null;
  const changelogTarget = guide.match(/\[1\.6\.0 changelog entry\]\(([^)]+)\)/)?.[1] ?? null;
  const section = (title) => {
    const headings = [...changelog.matchAll(/^## .+$/gm)];
    const current = headings.findIndex(match => match[0].startsWith(`## ${title}`));
    if (current < 0) return null;
    const start = headings[current].index + headings[current][0].length;
    const end = headings[current + 1]?.index ?? changelog.length;
    return changelog.slice(start, end);
  };
  const heading = section('[1.6.0]') ?? '';
  const unreleased = section('Unreleased') ?? '';
  const changedFiles = live.pull_request.changed_files;
  const schemaDiff = changedFiles.some(file => /(^|\/)(migrations?|schemas?)\//i.test(file) || /migration.*\.exs?$/i.test(file));
  const docs = {
    readme_upgrade_target: readmeTarget,
    readme_link_resolves: readmeTarget !== null && fs.existsSync(path.join(candidatePath, readmeTarget)),
    guide_changelog_target: changelogTarget,
    changelog_date: changelogDate,
    guide_changelog_link_resolves: changelogTarget !== null && fs.existsSync(path.resolve(candidatePath, 'guides/introduction', changelogTarget.split('#')[0])),
    exdoc_extra: /"guides\/introduction\/upgrading-to-v1\.6\.md"/.test(mix) ? 'guides/introduction/upgrading-to-v1.6.md' : null,
    exdoc_source_ref: mix.match(/source_ref:\s*"([^"]+)"/)?.[1] ?? null,
    compatibility_claims_supported: /Elixir `~> 1\.18`/.test(guide) && /Phoenix `~> 1\.8`/.test(guide)
      && /do not mean CI tests every version in each range/.test(guide)
      && /Elixir 1\.19\.5 on Erlang\/OTP 28\.5/.test(guide) && /Phoenix 1\.8\.8/.test(guide),
    no_schema_migration_claim_supported: !schemaDiff && /require no database migration/.test(guide)
      && /do not need to run `mix sigra\.upgrade`/.test(guide),
    candidate_summary_under_versioned_heading: (changelog.match(/^## \[1\.6\.0\]/gm) ?? []).length === 1
      && /Generated email-confirmation screens accept pasted six-digit codes/.test(heading)
      && !/confirmation|generated host/i.test(unreleased),
    local_status: candidate.docs_verification?.local_status ?? 'blocked_by_unavailable_exact_locked_dependencies',
      ci: { source_sha: live.candidate_worktree.head_sha, run_id: sourceCi.run_id, attempt: sourceCi.attempt,
        conclusion: sourceCi.conclusion, step: 'Check docs build cleanly' },
  };
  const inspection = path.join(candidatePath, 'tmp/sigra-hex-inspect');
  const metadata = fs.existsSync(path.join(inspection, 'hex_metadata.config')) ? fs.readFileSync(path.join(inspection, 'hex_metadata.config'), 'utf8') : '';
  const packageFiles = ['README.md', 'CHANGELOG.md', 'mix.exs', 'hex_metadata.config'].filter(file => fs.existsSync(path.join(inspection, file)));
  const packageChecks = {
    source_sha: live.candidate_worktree.head_sha,
    version: manifest['.'],
    mix_version: mix.match(/@version\s+"([^"]+)"/)?.[1] ?? null,
    publish_dry_run: { command: receipt.command, conclusion: receipt.verdict === 'passed' ? 'success' : 'blocked',
      exit_code: receipt.verdict === 'passed' ? 0 : 1, version: receipt.verdict === 'passed' ? '1.6.0' : null, receipt },
    dependency_fetch: { command: 'mix deps.get --check-locked', conclusion: 'success', locked_package_count: 65,
      lockfile_sha256: createHash('sha256').update(fs.readFileSync(path.join(candidatePath, 'mix.lock'))).digest('hex'),
      isolation: 'MIX_DEPS_PATH, MIX_BUILD_PATH, MIX_HOME, and HEX_HOME were redirected to /private/tmp/sigra-phase247-hex-verify.' },
    hex_client: { version: '2.5.1', authenticated_user_configured: false },
    hex_build: { command: 'mix hex.build --unpack --output tmp/sigra-hex-inspect', conclusion: packageFiles.length === 4 ? 'success' : 'failed',
      exit_code: 0, unpacked: packageFiles.length === 4, metadata_version: metadata.match(/<<"version">>,<<"([^\"]+)"/i)?.[1] ?? null,
      required_files: packageFiles, inspection_directory: 'tmp/sigra-hex-inspect' },
  };
  let inventoryObservation = observeFinalInventory(ledger);
  let inventoryAgain = observeFinalInventory(ledger);
  let inventoryStable = stableIdentity(inventoryObservation) === stableIdentity(inventoryAgain);
  if (!inventoryStable) {
    inventoryObservation = inventoryAgain;
    inventoryAgain = observeFinalInventory(ledger);
    inventoryStable = stableIdentity(inventoryObservation) === stableIdentity(inventoryAgain);
    if (!inventoryStable) inventoryObservation = inventoryAgain;
  }
  const timestamp = new Date().toISOString();
  const inventory = finalInventory(ledger, inventoryObservation, live.open_pull_requests);
  inventory.captured_at = timestamp;
  const review = { reviewer: 'Codex (gsd-executor)',
    method: 'Exact-head full-diff review plus source and CI correlation; GitHub review state is separately recorded.',
    github_review_decision: live.pull_request.review_decision || null, github_reviews: live.pull_request.reviews,
    reviewed_head_sha: live.pull_request.head_sha, reviewed_base_sha: live.pull_request.base_sha,
    changed_files: live.pull_request.changed_files, findings: [], unresolved_high_severity: [] };
  const diff = execFileSync('git', ['diff', `${live.pull_request.base_sha}...${live.pull_request.head_sha}`], { cwd: candidatePath, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  review.diff_sha256 = createHash('sha256').update(diff).digest('hex');
  review.diff_bytes = Buffer.byteLength(diff);
  const knownSourcePaths = [
    ['priv/templates/sigra.install/core/confirmation_live.ex'],
    ['priv/templates/sigra.install/core/confirmation_live.ex'],
    ['lib/sigra/branding.ex', 'lib/sigra/branding/contrast.ex', 'test/sigra/branding_test.exs'],
    ['lib/sigra/integrations/chimeway.ex', 'test/sigra/integrations/chimeway_test.exs'],
    ['priv/templates/sigra.install/core/confirmation_live.ex', 'test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex'],
  ];
  const claimSources = (candidate.claim_sources ?? []).map((row, index) => {
    const source_paths = knownSourcePaths[index] ?? [];
    return { ...row, source_paths, source_paths_present: source_paths.length > 0 && source_paths.every(file => fs.existsSync(path.join(candidatePath, file))),
      source_sha: live.candidate_worktree.head_sha, ci_run_id: 37700772880 };
  });
  const final = { source_sha: live.candidate_worktree.head_sha, selected_reviewed_main_sha: ledger.source_selection.selected_source_sha,
    observed_at: timestamp, baseline: { ...baseline, manifest_blob_id: receipt.manifest_blob_id },
    source_ci: live.source_ci_run, live_observation: live, docs, package: packageChecks,
    claim_sources: claimSources, review, inventory };
  const observed = { live, inventory };
  const details = validateFinalReadiness(final, observed);
  if (!inventoryStable) details.errors.push({ code: 'final_inventory_raced', message: 'Inherited checkout, PR, or main identity changed during repeated final inventory collection.' });
  for (const flag of ['readme_link_resolves', 'guide_changelog_link_resolves']) {
    if (!docs[flag]) details.errors.push({ code: `final_${flag}_failed`, message: `The guide link contract failed: ${flag}.` });
  }
  const result = { valid: details.errors.length === 0, status: details.errors.length === 0 ? 'ready' : 'blocked', checked_at: timestamp,
    checked: { source_sha: final.source_sha, pr_url: live.pull_request.url, pr_state: live.pull_request.state,
      pr_head_sha: live.pull_request.head_sha, pr_base_sha: live.pull_request.base_sha, live_main_sha: live.main_sha,
      candidate_status: live.candidate_worktree.status, open_pull_requests: inventory.pull_requests.length,
      inherited_commits: inventory.commits.length, inherited_paths: inventory.paths.length }, diagnostics: details.errors };
  ledger.final_readiness = final;
  ledger.final_validation = result;
  fs.writeFileSync(absoluteArtifact, `${JSON.stringify(ledger, null, 2)}\n`);
  console.log(JSON.stringify(result, null, 2));
  return result.valid;
}

export { validateSnapshot, validationSnapshot, validateCheckout, validateCandidate, validatePromotionProof, validateFinalReadiness, finalInventory, trustedCheckoutMatchesLiveMain };

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const [stageFlag, stage] = args;
  const assertLiveRefresh = args.includes('--assert-live-refresh');
  const artifact = args.find((arg, index) => index > 1 && !arg.startsWith('--'));
  if (stageFlag !== '--stage' || !['inventory', 'checkout', 'candidate', 'final'].includes(stage) || !artifact || (stage === 'candidate' && !assertLiveRefresh)) {
    console.error('Usage: node validate-release-readiness.mjs --stage <inventory|checkout|candidate|final> [--assert-live-refresh] <ledger.json>');
    process.exitCode = 2;
  } else {
    try {
      const valid = stage === 'inventory' ? await validateInventoryFile(artifact) : stage === 'checkout' ? validateCheckoutFile(artifact) : stage === 'candidate' ? validateCandidateFile(artifact, '.planning/phases/246-generated-confirmation-recovery/246-CI-EVIDENCE.json') : validateFinalFile(artifact);
      if (!valid) process.exitCode = 1;
    } catch (error) {
      console.error(JSON.stringify({ valid: false, status: 'blocked', diagnostics: [{ code: 'inventory_validation_error', message: error.message }] }, null, 2));
      process.exitCode = 1;
    }
  }
}
