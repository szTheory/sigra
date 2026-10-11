import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateSnapshot, validationSnapshot, validateCheckout, validateCandidate, validatePromotionProof, validateFinalReadiness, finalInventory, trustedCheckoutMatchesLiveMain } from './validate-release-readiness.mjs';

test('requires the clean trusted checkout to match exact observed live main', () => {
  const liveMain = 'a'.repeat(40);
  assert.equal(trustedCheckoutMatchesLiveMain(liveMain, '', liveMain), true);
  assert.equal(trustedCheckoutMatchesLiveMain('b'.repeat(40), '', liveMain), false);
  assert.equal(trustedCheckoutMatchesLiveMain(liveMain, ' M README.md', liveMain), false);
});

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

test('compares full open-PR identity including the observed base commit', () => {
  const snapshot = emptySnapshot();
  const observed = emptyObservation();
  const row = { number: 224, head_sha: 'd'.repeat(40), base: 'main', base_sha: 'a'.repeat(40),
    changed_files: [], disposition: 'release-relevant', reason: 'Selected candidate.', source: 'GitHub PR #224', preservation_location: 'GitHub' };
  snapshot.pull_requests = [row];
  observed.pull_requests = [{ ...row, base_sha: 'e'.repeat(40) }];
  const result = validateSnapshot(snapshot, observed);
  assert.ok(result.errors.some(error => error.code === 'pull_request_identity_mismatch'));
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

test('dispositions fresh dirty planning paths as preserved follow-up work', () => {
  const snapshot = { entry_snapshot: emptySnapshot(), current_snapshot: emptySnapshot() };
  const observed = {
    repo_root: '/repo',
    branch: 'release-work',
    trusted_main_sha: 'a'.repeat(40),
    local_origin_main_sha: 'a'.repeat(40),
    merge_base_sha: 'b'.repeat(40),
    inherited_head_sha: 'c'.repeat(40),
    commit_shas: [],
    committed_paths: [],
    dirty_paths: [
      { path: '.planning/phases/247/247-VALIDATION.md', status: ' M' },
      { path: 'lib/sigra/auth.ex', status: ' M' },
    ],
  };

  const inventory = finalInventory(snapshot, observed, []);
  const planningPath = inventory.paths.find(row => row.path.endsWith('247-VALIDATION.md'));
  const sourcePath = inventory.paths.find(row => row.path === 'lib/sigra/auth.ex');

  assert.equal(planningPath.disposition, 'separate-follow-up');
  assert.match(planningPath.reason, /excluded from the package candidate/);
  assert.equal(planningPath.preservation_location, '/repo@release-work');
  assert.equal(sourcePath.disposition, null);
  assert.equal(sourcePath.preservation_location, null);
});

test('repairs an unchanged legacy dirty planning path with no disposition', () => {
  const planningPath = '.planning/phases/247/247-VALIDATION.md';
  const sourcePath = 'lib/sigra/auth.ex';
  const snapshot = { entry_snapshot: emptySnapshot(), current_snapshot: emptySnapshot() };
  snapshot.current_snapshot.paths = [
    { kind: 'dirty', path: planningPath, status: '??', disposition: null, reason: null, source: 'fresh status', preservation_location: null },
    { kind: 'dirty', path: sourcePath, status: ' M', disposition: null, reason: null, source: 'fresh status', preservation_location: null },
  ];
  const observed = {
    repo_root: '/repo',
    branch: 'release-work',
    trusted_main_sha: 'a'.repeat(40),
    local_origin_main_sha: 'a'.repeat(40),
    merge_base_sha: 'b'.repeat(40),
    inherited_head_sha: 'c'.repeat(40),
    commit_shas: [],
    committed_paths: [],
    dirty_paths: [
      { path: planningPath, status: '??' },
      { path: sourcePath, status: ' M' },
    ],
  };

  const inventory = finalInventory(snapshot, observed, []);
  const planningRow = inventory.paths.find(row => row.path === planningPath);
  const sourceRow = inventory.paths.find(row => row.path === sourcePath);

  assert.equal(planningRow.disposition, 'separate-follow-up');
  assert.equal(sourceRow.disposition, null);
});

test('repairs incomplete inherited dispositions for scoped Phase 247 evidence', () => {
  const commitSha = '4'.repeat(40);
  const evidencePath = '.github/workflows/phase-247-hex-dry-run.yml';
  const snapshot = { entry_snapshot: emptySnapshot(), current_snapshot: emptySnapshot() };
  snapshot.current_snapshot.commits = [{ sha: commitSha, subject: 'test(247-05): pin trusted dry-run source', changed_paths: [evidencePath], disposition: null }];
  snapshot.current_snapshot.paths = [{ kind: 'dirty', path: evidencePath, status: ' M', disposition: null, reason: null, source: 'old status', preservation_location: null }];
  const observed = {
    repo_root: '/repo', branch: 'release-work', trusted_main_sha: 'a'.repeat(40), local_origin_main_sha: 'a'.repeat(40),
    merge_base_sha: 'b'.repeat(40), inherited_head_sha: 'c'.repeat(40), commit_shas: [commitSha],
    committed_paths: [evidencePath], dirty_paths: [{ path: evidencePath, status: ' M' }],
  };

  const inventory = finalInventory(snapshot, observed, []);
  const commit = inventory.commits.find(row => row.sha === commitSha);
  const path = inventory.paths.find(row => row.path === evidencePath);

  assert.equal(commit.disposition, 'separate-follow-up');
  assert.match(commit.reason, /excluded from the exact Release Please candidate/);
  assert.equal(path.disposition, 'separate-follow-up');
  assert.match(path.reason, /merged evidence PR/);
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

function candidateFixture() {
  const pre = 'a'.repeat(40);
  const refreshed = 'b'.repeat(40);
  const current = 'c'.repeat(40);
  const main = 'd'.repeat(40);
  const tested = 'e'.repeat(40);
  const candidate = {
    pre_refresh_pr_head_sha: pre,
    refreshed_pr_head_sha: refreshed,
    current_pr_head_sha: current,
    pr_base_sha: main,
    selected_reviewed_main_sha: main,
    phase_246_tested_sha: tested,
    changed_files: ['.release-please-manifest.json', 'mix.exs', 'CHANGELOG.md'],
    manifest_version: '1.6.0',
    mix_version: '1.6.0',
    package_version: '1.6.0',
    source_ref: 'v#{@version}',
    changelog_heading: '## [1.6.0](https://example.test/compare/v1.5.0...v1.6.0)',
    changelog_heading_count: 1,
    include_v_in_tag: true,
    planned_tag: 'v1.6.0',
    candidate_summary_under_versioned_heading: true,
    candidate_summary_only_unreleased: false,
    claim_sources: [{ claim: 'Generated confirmation screens keep their status after a retry.', source: 'confirmation_live.ex', evidence: 'Phase 246 required CI receipt' }],
  };
  const observed = {
    pull_request: { number: 224, state: 'OPEN', head_sha: current, base_sha: main, base_ref: 'main' },
    main_sha: main,
    phase_246_tested_sha: tested,
    phase_246_status: 'passed',
    identity_stable_during_observation: true,
    ancestry: { tested_to_main: true, main_to_refreshed: true, pre_to_refreshed: true, refreshed_to_current: true, current_to_worktree: true },
    conflicting_tag_exists: false,
  };
  return { candidate, observed };
}

test('accepts a consistent candidate bound to live PR, reviewed main, and tested source', () => {
  const { candidate, observed } = candidateFixture();
  assert.deepEqual(validateCandidate(candidate, observed), { valid: true, errors: [] });
});

test('rejects mismatched release version or ExDoc source reference', () => {
  const fixture = candidateFixture();
  fixture.candidate.manifest_version = '1.5.0';
  fixture.candidate.source_ref = 'main';
  const result = validateCandidate(fixture.candidate, fixture.observed);
  assert.ok(result.errors.some(error => error.code === 'candidate_version_mismatch'));
  assert.ok(result.errors.some(error => error.code === 'candidate_source_ref_mismatch'));
});

test('rejects changed live PR head, base, main, or Phase 246 tested SHA', () => {
  const cases = [
    { changed: { ...candidateFixture().observed, pull_request: { ...candidateFixture().observed.pull_request, head_sha: 'f'.repeat(40) } }, code: 'candidate_live_head_mismatch' },
    { changed: { ...candidateFixture().observed, pull_request: { ...candidateFixture().observed.pull_request, base_sha: 'f'.repeat(40) } }, code: 'candidate_live_base_mismatch' },
    { changed: { ...candidateFixture().observed, main_sha: 'f'.repeat(40) }, code: 'candidate_live_main_mismatch' },
    { changed: { ...candidateFixture().observed, phase_246_tested_sha: 'f'.repeat(40) }, code: 'candidate_tested_source_mismatch' },
  ];
  for (const row of cases) {
    const { candidate } = candidateFixture();
    assert.ok(validateCandidate(candidate, row.changed).errors.some(error => error.code === row.code), row.code);
  }
});

test('rejects a non-fast-forward refresh without exact-head renewed review and checks', () => {
  const { candidate, observed } = candidateFixture();
  observed.ancestry.pre_to_refreshed = false;
  assert.ok(validateCandidate(candidate, observed).errors.some(error => error.code === 'candidate_refresh_non_fast_forward_unreviewed'));
  candidate.renewed_review = { complete_diff_reviewed: true, head_sha: candidate.refreshed_pr_head_sha, base_sha: candidate.pr_base_sha, source_sha: candidate.selected_reviewed_main_sha, checks_passed: true };
  assert.equal(validateCandidate(candidate, observed).valid, true);
});

test('rejects a candidate summary stranded only under Unreleased', () => {
  const { candidate, observed } = candidateFixture();
  candidate.candidate_summary_under_versioned_heading = false;
  candidate.candidate_summary_only_unreleased = true;
  assert.ok(validateCandidate(candidate, observed).errors.some(error => error.code === 'candidate_summary_misplaced'));
});

function promotionFixture() {
  const tested = '1'.repeat(40);
  const main = '2'.repeat(40);
  const paths = [
    'priv/templates/sigra.install/core/confirmation_live.ex',
    'test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex',
    'scripts/ci/generated-confirmation-probe.exs',
    'test/sigra/install/auth_ui_contract_test.exs',
  ];
  return {
    pr_number: 288,
    pr_state: 'MERGED',
    pr_head_sha: '3'.repeat(40),
    expected_pr_head_sha: '3'.repeat(40),
    pr_base_sha: '4'.repeat(40),
    expected_pr_base_sha: '4'.repeat(40),
    merge_commit_sha: main,
    expected_main_sha: main,
    selected_main_sha: main,
    tested_source_sha: tested,
    approved_paths: paths.map(path => ({ path, tested_blob: '5'.repeat(40), main_blob: '5'.repeat(40) })),
    pr_changed_files: paths,
    phase_246_ci: {
      source_sha: tested,
      run_id: 37676348766,
      attempt: 2,
      conclusion: 'success',
      required_jobs: { 'ci-gate': 'success', install_smoke: 'success', generated_admin_playwright_smoke: 'success' },
    },
    main_ci: { head_sha: main, run_id: 37686980115, attempt: 2, conclusion: 'success' },
  };
}

test('accepts exact-source squash promotion with four matching blobs and both exact CI receipts', () => {
  assert.deepEqual(validatePromotionProof(promotionFixture()), { valid: true, errors: [] });
});

test('rejects a missing or extra promotion path', () => {
  const missing = promotionFixture();
  missing.approved_paths.pop();
  assert.ok(validatePromotionProof(missing).errors.some(error => error.code === 'promotion_path_allowlist_mismatch'));
  const extra = promotionFixture();
  extra.pr_changed_files.push('README.md');
  assert.ok(validatePromotionProof(extra).errors.some(error => error.code === 'promotion_pr_diff_mismatch'));
});

test('rejects promotion blob mismatches and changed PR/head/merge identities', () => {
  const blobMismatch = promotionFixture();
  blobMismatch.approved_paths[0].main_blob = '6'.repeat(40);
  assert.ok(validatePromotionProof(blobMismatch).errors.some(error => error.code === 'promotion_blob_mismatch'));
  for (const [field, value] of [
    ['pr_head_sha', '7'.repeat(40)],
    ['pr_base_sha', '9'.repeat(40)],
    ['merge_commit_sha', '8'.repeat(40)],
    ['pr_number', 287],
  ]) {
    const changed = promotionFixture();
    changed[field] = value;
    assert.ok(validatePromotionProof(changed).errors.some(error => error.code === 'promotion_pr_identity_mismatch'), field);
  }
});

test('rejects absent or failed Phase 246 and selected-main CI receipts', () => {
  const phaseFailure = promotionFixture();
  phaseFailure.phase_246_ci.required_jobs['ci-gate'] = 'failure';
  assert.ok(validatePromotionProof(phaseFailure).errors.some(error => error.code === 'promotion_phase_ci_missing'));
  const mainFailure = promotionFixture();
  mainFailure.main_ci.conclusion = 'failure';
  assert.ok(validatePromotionProof(mainFailure).errors.some(error => error.code === 'promotion_main_ci_missing'));
});

function finalReadinessFixture() {
  const sha = 'a'.repeat(40);
  const reviewedBase = 'b'.repeat(40);
  const liveBase = 'd'.repeat(40);
  const evidenceHead = 'e'.repeat(40);
  const manifestBlob = 'f'.repeat(40);
  const diffSha = 'c'.repeat(64);
  const dryRunId = 12345;
  const sourceCiId = 37800067568;
  const receipt = {
    verdict: 'passed', repository: 'szTheory/sigra', workflow: '.github/workflows/phase-247-hex-dry-run.yml',
    workflow_ref: 'szTheory/sigra/.github/workflows/phase-247-hex-dry-run.yml@refs/heads/main',
    run_id: String(dryRunId), run_attempt: 1, requested_sha: sha, checked_out_sha: sha,
    reviewed_base_sha: reviewedBase, live_base_sha: reviewedBase, evidence_pr_number: 296,
    evidence_pr_head_sha: evidenceHead, evidence_merge_sha: reviewedBase, manifest_blob_id: manifestBlob,
    diff_algorithm: 'git-diff-raw-v1', diff_sha256: diffSha, diff_bytes: 42,
    command: 'mix hex.publish --dry-run --yes', dry_run_outcome: 'success',
    credential_name: 'HEX_DRY_RUN_API_KEY', credential_present: true,
    hex_release_before_http_status: 404, hex_release_after_http_status: 404,
  };
  const checks = [
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
  ].map(name => ({ name, status: 'COMPLETED', conclusion: 'SUCCESS' }));
  const final = {
    source_sha: sha,
    selected_reviewed_main_sha: reviewedBase,
    baseline: { reviewed_base_sha: reviewedBase, candidate_sha: sha, diff_sha256: diffSha, diff_bytes: 42, manifest_blob_id: manifestBlob },
    source_ci: { run_id: sourceCiId, attempt: 1, head_sha: sha, conclusion: 'success', docs_step_conclusion: 'success' },
    observed_at: '2026-10-07T23:00:00Z',
    claim_sources: [{ claim: 'Claim', source: 'lib/sigra/auth.ex', evidence: 'CI run 37700772880', source_sha: sha, ci_run_id: 37700772880, source_paths_present: true }],
    docs: {
      readme_upgrade_target: 'guides/introduction/upgrading-to-v1.6.md',
      readme_link_resolves: true,
      guide_changelog_target: '../../CHANGELOG.md#160-2026-10-08',
      changelog_date: '2026-10-08',
      guide_changelog_link_resolves: true,
      exdoc_extra: 'guides/introduction/upgrading-to-v1.6.md',
      exdoc_source_ref: 'v#{@version}',
      compatibility_claims_supported: true,
      no_schema_migration_claim_supported: true,
      candidate_summary_under_versioned_heading: true,
      local_status: 'blocked_by_unavailable_exact_locked_dependencies',
      ci: { source_sha: sha, run_id: sourceCiId, attempt: 1, conclusion: 'success', step: 'Check docs build cleanly' },
    },
    package: {
      source_sha: sha,
      version: '1.6.0',
      mix_version: '1.6.0',
      publish_dry_run: { conclusion: 'success', version: '1.6.0', receipt },
      hex_build: { conclusion: 'success', unpacked: true, metadata_version: '1.6.0', required_files: ['README.md', 'CHANGELOG.md'] },
    },
    review: { reviewer: 'Codex', method: 'exact-head diff and CI review', reviewed_head_sha: sha, reviewed_base_sha: 'b'.repeat(40),
      diff_sha256: 'c'.repeat(64), diff_bytes: 1, findings: [], unresolved_high_severity: [] },
  };
  const observed = {
    live: {
      pull_request: { number: 224, state: 'OPEN', head_sha: sha, base_ref: 'main', base_sha: 'b'.repeat(40), checks },
      main_sha: reviewedBase,
      candidate_worktree: { head_sha: sha, status: '' },
      identity_stable_during_observation: true,
      main_advance: { verified: true, paths: [] },
      source_ci_run: { run_id: sourceCiId, attempt: 1, head_sha: sha, conclusion: 'success', docs_step_conclusion: 'success' },
      dry_run_run: { run_id: dryRunId, head_sha: reviewedBase, event: 'workflow_dispatch', status: 'completed', conclusion: 'success', job_conclusion: 'success' },
      open_pull_requests: [{ number: 224, head_sha: sha, base: 'main' }],
    },
    inventory: {
      captured_at: final.observed_at,
      commits: [],
      paths: [],
      pull_requests: [{ number: 224, head_sha: sha, base: 'main', disposition: 'release-relevant', reason: 'Selected release PR.', source: 'https://github.com/szTheory/sigra/pull/224', preservation_location: 'GitHub PR #224' }],
      raw_status: [],
    },
  };
  return { final, observed };
}

test('accepts complete final docs, package, review, and live-population evidence', () => {
  const { final, observed } = finalReadinessFixture();
  assert.deepEqual(validateFinalReadiness(final, observed), { valid: true, errors: [] });
});

test('rejects a failed Hex dry run and a changed final PR head', () => {
  const { final, observed } = finalReadinessFixture();
  final.package.publish_dry_run.conclusion = 'blocked';
  observed.live.pull_request.head_sha = 'c'.repeat(40);
  const result = validateFinalReadiness(final, observed);
  assert.ok(result.errors.some(error => error.code === 'final_hex_dry_run_failed'));
  assert.ok(result.errors.some(error => error.code === 'final_candidate_identity_mismatch'));
});

test('accepts the exact authenticated dry-run receipt and an allowlisted evidence-only main advance', () => {
  const { final, observed } = finalReadinessFixture();
  const evidencePaths = [
    '.github/workflows/phase-247-hex-dry-run.yml',
    '.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json',
    'scripts/ci/phase-247-hex-dry-run.sh',
    'scripts/ci/phase-247-hex-dry-run.test.sh',
  ];
  final.selected_reviewed_main_sha = 'b'.repeat(40);
  final.baseline.reviewed_base_sha = 'b'.repeat(40);
  final.baseline.manifest_blob_id = 'f'.repeat(40);
  final.package.publish_dry_run.receipt.reviewed_base_sha = 'b'.repeat(40);
  final.package.publish_dry_run.receipt.live_base_sha = 'd'.repeat(40);
  final.package.publish_dry_run.receipt.evidence_merge_sha = 'd'.repeat(40);
  final.package.publish_dry_run.receipt.evidence_pr_head_sha = 'e'.repeat(40);
  final.package.publish_dry_run.receipt.manifest_blob_id = 'f'.repeat(40);
  observed.live.pull_request.base_sha = 'b'.repeat(40);
  observed.live.main_sha = 'd'.repeat(40);
  observed.live.main_advance = { verified: true, paths: evidencePaths };
  observed.live.dry_run_run.head_sha = 'd'.repeat(40);
  assert.deepEqual(validateFinalReadiness(final, observed), { valid: true, errors: [] });

  observed.live.main_advance.paths.push('lib/sigra/auth.ex');
  assert.ok(validateFinalReadiness(final, observed).errors.some(error => error.code === 'final_main_advance_unverified'));
});

test('rejects stale, unauthenticated, or mismatched safe dry-run receipts', () => {
  for (const mutate of [
    receipt => { receipt.checked_out_sha = '9'.repeat(40); },
    receipt => { receipt.credential_present = false; },
    receipt => { receipt.hex_release_after_http_status = 200; },
    receipt => { receipt.diff_sha256 = '9'.repeat(64); },
  ]) {
    const { final, observed } = finalReadinessFixture();
    mutate(final.package.publish_dry_run.receipt);
    assert.ok(validateFinalReadiness(final, observed).errors.some(error => error.code === 'final_hex_dry_run_failed'));
  }
});

test('keeps the recovered dry-run receipt bound to the repaired candidate and baseline', () => {
  const candidateResult = JSON.parse(readFileSync(new URL('./247-09-PLAYWRIGHT-RESULT.json', import.meta.url), 'utf8'));
  const baseline = JSON.parse(readFileSync(new URL('./247-CANDIDATE-DIFF-BASELINE.json', import.meta.url), 'utf8'));
  const receipt = JSON.parse(readFileSync(new URL('./247-HEX-DRY-RUN-RECEIPT.json', import.meta.url), 'utf8'));
  assert.equal(receipt.run_id, '37824714823');
  assert.equal(receipt.requested_sha, candidateResult.candidate_sha);
  assert.equal(receipt.checked_out_sha, candidateResult.candidate_sha);
  assert.equal(receipt.reviewed_base_sha, baseline.reviewed_base_sha);
  assert.equal(receipt.live_base_sha, receipt.evidence_merge_sha);
  assert.equal(receipt.evidence_pr_number, 297);
  assert.equal(receipt.manifest_blob_id, '12daf4f704bbc2d4aa136d0ef678e64abce38aeb');
  assert.equal(receipt.diff_sha256, baseline.diff_sha256);
  assert.equal(receipt.diff_bytes, baseline.diff_bytes);
  assert.equal(receipt.credential_present, true);
  assert.equal(receipt.hex_release_before_http_status, 404);
  assert.equal(receipt.hex_release_after_http_status, 404);
});

test('rejects the preserved historical dry-run receipt for the repaired Playwright candidate', () => {
  const candidateResult = JSON.parse(readFileSync(new URL('./247-09-PLAYWRIGHT-RESULT.json', import.meta.url), 'utf8'));
  const historicalReceipt = JSON.parse(readFileSync(new URL('./247-STALE-HEX-DRY-RUN-RECEIPT.fixture.json', import.meta.url), 'utf8'));
  assert.notEqual(candidateResult.candidate_sha, historicalReceipt.checked_out_sha);

  const { final, observed } = finalReadinessFixture();
  const candidateSha = candidateResult.candidate_sha;
  final.source_sha = candidateSha;
  final.selected_reviewed_main_sha = historicalReceipt.reviewed_base_sha;
  final.package.source_sha = candidateSha;
  final.package.publish_dry_run.receipt = historicalReceipt;
  final.docs.ci.source_sha = candidateSha;
  final.source_ci.head_sha = candidateSha;
  final.claim_sources[0].source_sha = candidateSha;
  final.review.reviewed_head_sha = candidateSha;
  final.review.reviewed_base_sha = historicalReceipt.reviewed_base_sha;
  observed.live.pull_request.head_sha = candidateSha;
  observed.live.pull_request.base_sha = historicalReceipt.reviewed_base_sha;
  observed.live.candidate_worktree.head_sha = candidateSha;
  observed.live.main_sha = historicalReceipt.live_base_sha;
  observed.live.source_ci_run.head_sha = candidateSha;
  observed.live.dry_run_run = {
    run_id: Number(historicalReceipt.run_id),
    head_sha: historicalReceipt.live_base_sha,
    event: 'workflow_dispatch',
    status: 'completed',
    conclusion: 'success',
    job_conclusion: 'success',
  };
  observed.live.open_pull_requests[0].head_sha = candidateSha;
  observed.inventory.pull_requests[0].head_sha = candidateSha;
  observed.live.main_advance = {
    verified: true,
    paths: [
      '.github/workflows/phase-247-hex-dry-run.yml',
      '.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json',
      'scripts/ci/phase-247-hex-dry-run.sh',
      'scripts/ci/phase-247-hex-dry-run.test.sh',
    ],
  };

  const result = validateFinalReadiness(final, observed);
  assert.ok(result.errors.some(error => error.code === 'final_hex_dry_run_failed'));
});

test('rejects a broken adopter link or claim without final-source CI evidence', () => {
  const { final, observed } = finalReadinessFixture();
  final.docs.readme_link_resolves = false;
  final.claim_sources[0].source_sha = 'f'.repeat(40);
  const result = validateFinalReadiness(final, observed);
  assert.ok(result.errors.some(error => error.code === 'final_guide_contract_failed'));
  assert.ok(result.errors.some(error => error.code === 'final_claim_mapping_incomplete'));
});

test('rejects incomplete dispositions and unresolved high-severity review findings', () => {
  const { final, observed } = finalReadinessFixture();
  observed.inventory.paths.push({ kind: 'dirty', path: 'README.md' });
  final.review.unresolved_high_severity.push({ finding: 'unresolved' });
  const result = validateFinalReadiness(final, observed);
  assert.ok(result.errors.some(error => error.code === 'final_path_disposition_missing'));
  assert.ok(result.errors.some(error => error.code === 'final_review_high_severity_open'));
});

test('rejects duplicate and omitted live inventory identities while accepting explicit empty sets', () => {
  const { final, observed } = finalReadinessFixture();
  observed.inventory.pull_requests.push({ ...observed.inventory.pull_requests[0] });
  const duplicate = validateFinalReadiness(final, observed);
  assert.ok(duplicate.errors.some(error => error.code === 'final_duplicate_pr_key'));

  const empty = finalReadinessFixture();
  empty.observed.live.open_pull_requests = [];
  assert.ok(validateFinalReadiness(empty.final, empty.observed).errors.some(error => error.code === 'final_pr_population_mismatch'));
  delete empty.observed.inventory.commits;
  assert.ok(validateFinalReadiness(empty.final, empty.observed).errors.some(error => error.code === 'final_commits_not_array'));
});

function dispositionIdentity(row) {
  return {
    repository: row.repository,
    number: row.number,
    head_sha: row.head_sha,
    base: row.base,
    base_sha: row.base_sha,
  };
}

function finalInventoryForPullRequest(livePullRequest) {
  const identity = dispositionIdentity(livePullRequest);
  const saved = {
    ...livePullRequest,
    changed_files: [],
    disposition: 'release-relevant',
    reason: 'Selected release PR.',
    source: 'GitHub PR #224',
    preservation_location: 'GitHub PR #224',
    disposition_identity: identity,
  };
  const empty = emptySnapshot();
  const snapshot = { entry_snapshot: empty, current_snapshot: { ...emptySnapshot(), pull_requests: [saved] } };
  const observed = {
    repo_root: '/repo', branch: 'release-work', trusted_main_sha: 'a'.repeat(40),
    local_origin_main_sha: 'a'.repeat(40), merge_base_sha: 'b'.repeat(40),
    inherited_head_sha: 'c'.repeat(40), commit_shas: [], committed_paths: [], dirty_paths: [],
  };
  return finalInventory(snapshot, observed, [livePullRequest]);
}

test('final inventory invalidates disposition when any captured PR identity component changes', () => {
  const { final, observed } = finalReadinessFixture();
  const baseline = {
    repository: 'szTheory/sigra', number: 224, head_sha: final.source_sha,
    base: 'main', base_sha: 'b'.repeat(40), changed_files: [],
  };
  const unchangedInventory = finalInventoryForPullRequest(baseline);
  final.observed_at = unchangedInventory.captured_at;
  observed.inventory = unchangedInventory;
  observed.live.open_pull_requests = [baseline];
  assert.deepEqual(validateFinalReadiness(final, observed), { valid: true, errors: [] });

  for (const [field, value] of [
    ['head_sha', 'c'.repeat(40)],
    ['base', 'release/1.6'],
    ['base_sha', 'd'.repeat(40)],
  ]) {
    const changed = { ...baseline, [field]: value };
    const inventory = finalInventoryForPullRequest(changed);
    final.observed_at = inventory.captured_at;
    assert.equal(inventory.pull_requests[0].disposition, null, `${field} must clear the old disposition`);
    observed.inventory = inventory;
    observed.live.open_pull_requests = [changed];
    const result = validateFinalReadiness(final, observed);
    assert.ok(result.errors.some(error => /final_pr_(?:disposition_missing|identity_mismatch)/.test(error.code)),
      `${field} must fail final readiness: ${JSON.stringify(result.errors)}`);
  }
});
