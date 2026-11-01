import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(testDir, '../..');
const localSuite = path.join(testDir, 'prune-stale-branches.test.sh');
const remoteSuite = path.join(testDir, 'prune-stale-branches.remote.test.sh');

function runSuite(suite) {
  return spawnSync('bash', [suite], { cwd: repoRoot, encoding: 'utf8' });
}

function runGit(cwd, ...args) {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' });
  assert.equal(result.status, 0, `${args.join(' ')}\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  return result.stdout.trim();
}

function installCoordinator(repo) {
  const result = spawnSync('bash', [path.join(testDir, 'repo-mutation-coordinator.sh'), 'install', '--repo', repo], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, `${result.stdout ?? ''}${result.stderr ?? ''}`);
}

function makeForgedReadinessRepo() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-prune-forged-readiness-'));
  const repo = path.join(tempDir, 'repo');
  fs.mkdirSync(repo);
  runGit(repo, 'init', '-q', '--initial-branch=main');
  runGit(repo, 'config', 'user.name', 'GSD Fixture');
  runGit(repo, 'config', 'user.email', 'gsd-fixture@example.invalid');
  runGit(repo, 'config', 'gc.auto', '0');
  runGit(repo, 'config', 'maintenance.auto', 'false');
  fs.writeFileSync(path.join(repo, 'root.txt'), 'fixture root\n');
  runGit(repo, 'add', 'root.txt');
  runGit(repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: root');
  const rootOid = runGit(repo, 'rev-parse', 'HEAD');
  runGit(repo, 'branch', 'stale/merged', rootOid);

  const phaseDir = '.planning/phases/245-branch-prune-local-and-remote';
  const snapshot = `${phaseDir}/245-LOCAL-REFS.tsv`;
  const evidence = `${phaseDir}/245-EVIDENCE.json`;
  const prState = `${phaseDir}/245-OPEN-PR-STATE.json`;
  const safety = `${phaseDir}/245-SAFETY-PUBLISH.tsv`;
  const allowlist = `${phaseDir}/245-BRANCH-DELETE-ALLOWLIST.tsv`;
  for (const file of [snapshot, evidence, prState, safety, allowlist]) {
    fs.mkdirSync(path.dirname(path.join(repo, file)), { recursive: true });
  }
  const captured = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'capture-local', '--repo', repo, '--output', path.join(repo, snapshot)], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  assert.equal(captured.status, 0, `${captured.stdout ?? ''}${captured.stderr ?? ''}`);
  fs.writeFileSync(path.join(repo, evidence), JSON.stringify({
    schema_version: 1,
    readiness: {
      phase_244_status: 'complete',
      phase_244_verification: 'passed',
      ref_dependent_disposition: 'resolved',
    },
  }, null, 2) + '\n');
  fs.writeFileSync(path.join(repo, prState), JSON.stringify({
    schema_version: 1,
    repository: 'szTheory/sigra',
    actor: 'fixture-user',
    limit: 1000,
    captured_at: '2026-09-27T00:00:00Z',
    pull_requests: [],
  }) + '\n');
  fs.writeFileSync(path.join(repo, safety), 'side\tref\toid\ttype\treason\n');
  runGit(repo, 'add', snapshot, evidence, prState, safety);
  runGit(repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit asserted readiness');
  const baselineCommit = runGit(repo, 'rev-parse', 'HEAD');
  fs.writeFileSync(path.join(repo, allowlist), `side\tref\toid\ttype\treason\nlocal\trefs/heads/stale/merged\t${rootOid}\tcommit\tmerged fixture branch\n`);
  runGit(repo, 'add', allowlist);
  runGit(repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: exact local allowlist');
  const allowlistCommit = runGit(repo, 'rev-parse', 'HEAD');

  const binDir = path.join(tempDir, 'bin');
  fs.mkdirSync(binDir);
  const gh = path.join(binDir, 'gh');
  fs.writeFileSync(gh, `#!/usr/bin/env bash\nset -euo pipefail\ncase "$1 $2" in\n  'auth status') exit 0 ;;\n  'api user') printf '%s\\n' fixture-user ;;\n  'pr list') printf '%s\\n' '[]' ;;\n  *) echo 'unexpected gh invocation' >&2; exit 2 ;;\nesac\n`);
  fs.chmodSync(gh, 0o755);
  return { tempDir, repo, binDir, snapshot, evidence, prState, safety, allowlist, baselineCommit, allowlistCommit };
}

function makeCapturedReadinessRepo() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-prune-readiness-'));
  const repo = path.join(tempDir, 'repo');
  const bare = path.join(tempDir, 'origin.git');
  runGit(tempDir, 'clone', '-q', '--shared', repoRoot, repo);
  runGit(repo, 'config', 'user.name', 'GSD Fixture');
  runGit(repo, 'config', 'user.email', 'gsd-fixture@example.invalid');
  runGit(repo, 'config', 'gc.auto', '0');
  runGit(repo, 'config', 'maintenance.auto', 'false');
  runGit(repo, 'checkout', '-q', '-b', 'fixture-prune-readiness');
  runGit(tempDir, 'init', '-q', '--bare', '--initial-branch=main', bare);
  runGit(repo, 'remote', 'set-url', 'origin', bare);
  runGit(repo, 'push', '-q', 'origin', 'HEAD:refs/heads/main');
  runGit(repo, 'fetch', '-q', 'origin');
  runGit(repo, 'remote', 'set-head', 'origin', 'main');

  // Make the disposable clone self-contained: readiness is based on committed
  // Phase 244 inputs, which may be present in the source checkout as working
  // tree artifacts but are intentionally not assumed to be in its current HEAD.
  const readinessSources = [
    '.planning/state.json',
    '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-VERIFICATION.md',
    '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json',
    '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-04-SUMMARY.md',
    '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-08-SUMMARY.md',
    '.planning/todos/resolved/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md',
    '.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md',
    '.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-ESCALATED.log',
    '.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md',
  ];
  const fixtureSourceCommit = runGit(repo, 'rev-parse', 'HEAD');
  for (const source of readinessSources) {
    const sourceFile = path.join(repoRoot, source);
    assert.ok(fs.existsSync(sourceFile), `required readiness fixture source missing: ${source}`);
    const destination = path.join(repo, source);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    let contents = fs.readFileSync(sourceFile, 'utf8');
    if (source.endsWith('260926-gzb-SUMMARY.md') || source.endsWith('260926-dzu-SUMMARY.md')) {
      contents = contents.replace(/^source_commit:.*$/m, `source_commit: ${fixtureSourceCommit}`);
    }
    fs.writeFileSync(destination, contents);
  }
  runGit(repo, 'add', ...readinessSources);
  runGit(repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit Phase 244 readiness sources');

  const phaseDir = '.planning/phases/245-branch-prune-local-and-remote';
  const readiness = `${phaseDir}/245-READINESS.json`;
  const snapshot = `${phaseDir}/245-LOCAL-REFS.tsv`;
  const prState = `${phaseDir}/245-OPEN-PR-STATE.json`;
  const safety = `${phaseDir}/245-SAFETY-PUBLISH.tsv`;
  const allowlist = `${phaseDir}/245-BRANCH-DELETE-ALLOWLIST.tsv`;
  const binDir = path.join(tempDir, 'bin');
  fs.mkdirSync(binDir);
  const gh = path.join(binDir, 'gh');
  fs.writeFileSync(gh, `#!/usr/bin/env bash\nset -euo pipefail\ncase "$1 $2" in\n  'auth status') exit 0 ;;\n  'api user') printf '%s\\n' fixture-user ;;\n  'pr list') printf '%s\\n' '[]' ;;\n  *) echo 'unexpected gh invocation' >&2; exit 2 ;;\nesac\n`);
  fs.chmodSync(gh, 0o755);
  const rootOid = runGit(repo, 'rev-parse', 'HEAD');
  runGit(repo, 'branch', 'stale/merged', rootOid);

  const capture = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'capture-readiness', '--repo', repo], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  assert.equal(capture.status, 0, `${capture.stdout ?? ''}${capture.stderr ?? ''}`);
  const readinessReceipt = JSON.parse(fs.readFileSync(path.join(repo, readiness), 'utf8'));
  assert.equal(readinessReceipt.status, 'ready', JSON.stringify(readinessReceipt.blocked_reasons, null, 2));

  const inventory = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'capture-local', '--repo', repo, '--output', path.join(repo, snapshot)], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  assert.equal(inventory.status, 0, `${inventory.stdout ?? ''}${inventory.stderr ?? ''}`);
  fs.writeFileSync(path.join(repo, prState), JSON.stringify({
    schema_version: 1,
    repository: 'szTheory/sigra',
    actor: 'fixture-user',
    limit: 1000,
    captured_at: '2026-09-27T00:00:00Z',
    pull_requests: [],
  }) + '\n');
  fs.writeFileSync(path.join(repo, safety), 'side\tref\toid\ttype\treason\n');
  runGit(repo, 'add', readiness, snapshot, prState, safety);
  runGit(repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit readiness and inventory');
  const inventoryCommit = runGit(repo, 'rev-parse', 'HEAD');
  fs.writeFileSync(path.join(repo, allowlist), `side\tref\toid\ttype\treason\nlocal\trefs/heads/stale/merged\t${rootOid}\tcommit\tmerged fixture branch\n`);
  runGit(repo, 'add', allowlist);
  runGit(repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit exact local allowlist');
  const allowlistCommit = runGit(repo, 'rev-parse', 'HEAD');
  return { tempDir, repo, bare, binDir, readiness, snapshot, prState, safety, allowlist, inventoryCommit, allowlistCommit, rootOid };
}

function readinessApplyArgs(fixture, readinessCommit = fixture.inventoryCommit) {
  installCoordinator(fixture.repo);
  return [
    '--repo', fixture.repo,
    '--apply',
    '--snapshot-commit', fixture.inventoryCommit,
    '--snapshot', fixture.snapshot,
    '--allowlist-commit', fixture.allowlistCommit,
    '--allowlist', fixture.allowlist,
    '--readiness-commit', readinessCommit,
    '--readiness', fixture.readiness,
    '--pr-state-commit', fixture.inventoryCommit,
    '--pr-state', fixture.prState,
    '--safety-list', fixture.safety,
  ];
}

function commitSourceChange(fixture, sourcePath, mutate) {
  const absolute = path.join(fixture.repo, sourcePath);
  mutate(absolute);
  runGit(fixture.repo, 'add', '--', sourcePath);
  runGit(fixture.repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', `fixture: mutate ${path.basename(sourcePath)}`);
}

test('runtime-probed local apply retains or deletes only its eligible fixture ref and preserves snapshot objects', (t) => {
  const result = runSuite(localSuite);
  assert.equal(result.status, 0, `${result.stdout ?? ''}${result.stderr ?? ''}`);
  t.diagnostic(result.stdout.trimEnd());
});

test('remote leases preserve concurrent origin refs and PR identity checks reject incomplete results', (t) => {
  const result = runSuite(remoteSuite);
  assert.equal(result.status, 0, `${result.stdout ?? ''}${result.stderr ?? ''}`);
  t.diagnostic(result.stdout.trimEnd());
});

test('top-level prune runner invokes local and remote suites once without nesting', () => {
  const runner = fs.readFileSync(fileURLToPath(import.meta.url), 'utf8');
  const localSource = fs.readFileSync(localSuite, 'utf8');
  assert.equal((runner.match(/runSuite\(localSuite\)/g) ?? []).length, 1);
  assert.equal((runner.match(/runSuite\(remoteSuite\)/g) ?? []).length, 1);
  assert.doesNotMatch(localSource, /prune-stale-branches\.remote\.test\.sh/);
});

test('rejects self-asserted readiness before an apply mode can delete refs', () => {
  const fixture = makeForgedReadinessRepo();
  try {
    installCoordinator(fixture.repo);
    const result = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'local', '--repo', fixture.repo, '--apply',
      '--snapshot-commit', fixture.allowlistCommit, '--snapshot', fixture.snapshot,
      '--allowlist-commit', fixture.allowlistCommit, '--allowlist', fixture.allowlist,
      '--evidence-commit', fixture.allowlistCommit, '--evidence', fixture.evidence,
      '--pr-state-commit', fixture.baselineCommit, '--pr-state', fixture.prState,
      '--safety-list', fixture.safety], {
      cwd: repoRoot,
      encoding: 'utf8',
      env: { ...process.env, PATH: `${fixture.binDir}:${process.env.PATH}` },
    });
    assert.notEqual(result.status, 0, `forged readiness was accepted:\n${result.stdout ?? ''}${result.stderr ?? ''}`);
    assert.equal(runGit(fixture.repo, 'show-ref', '--verify', '--quiet', 'refs/heads/stale/merged'), '');
  } finally {
    fs.rmSync(fixture.tempDir, { recursive: true, force: true });
  }
});

test('captures and verifies a source-pinned Phase 244 readiness receipt', () => {
  const fixture = makeCapturedReadinessRepo();
  try {
    const receipt = JSON.parse(fs.readFileSync(path.join(fixture.repo, fixture.readiness), 'utf8'));
    assert.equal(receipt.status, 'ready');
    assert.match(receipt.source_commit, /^[0-9a-f]{40}$/);
    assert.equal(receipt.sources.length, 9);
    assert.ok(receipt.sources.every((source) => source.commit === receipt.source_commit && /^[0-9a-f]{40}$/.test(source.blob_oid)));
    const result = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'verify-readiness', '--repo', fixture.repo,
      '--readiness-commit', fixture.inventoryCommit, '--readiness', fixture.readiness], { cwd: repoRoot, encoding: 'utf8' });
    assert.equal(result.status, 0, `${result.stdout ?? ''}${result.stderr ?? ''}`);
  } finally {
    fs.rmSync(fixture.tempDir, { recursive: true, force: true });
  }
});

test('D-05 local apply stays fail-closed after a branch moves and keeps snapshotted objects readable', () => {
  const fixture = makeCapturedReadinessRepo();
  try {
    // Make the ref differ from its snapshotted OID before apply. D-05 blocks
    // every local deletion until a shared worktree/ref coordinator exists, so
    // this path must stop before reaching any compare-and-delete mutation hook.
    fs.writeFileSync(path.join(fixture.repo, 'race-move.txt'), 'concurrent branch move\n');
    runGit(fixture.repo, 'add', 'race-move.txt');
    runGit(fixture.repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: race target');
    const movedOid = runGit(fixture.repo, 'rev-parse', 'HEAD');
    runGit(fixture.repo, 'update-ref', 'refs/heads/stale/merged', movedOid, fixture.rootOid);

    const result = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'local', ...readinessApplyArgs(fixture)], {
      cwd: repoRoot,
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: `${fixture.binDir}:${process.env.PATH}`,
      },
    });
    const combined = `${result.stdout ?? ''}${result.stderr ?? ''}`;
    assert.notEqual(result.status, 0, `D-05 local apply unexpectedly proceeded:\n${combined}`);
    assert.match(combined, /local_ref_identity_conflict/);
    assert.ok(combined.includes(`expected=${fixture.rootOid}`), `snapshotted OID missing from failure receipt:\n${combined}`);
    assert.ok(combined.includes(`actual=${movedOid}`), `moved OID missing from failure receipt:\n${combined}`);
    assert.equal(runGit(fixture.repo, 'rev-parse', 'refs/heads/stale/merged'), movedOid);
    assert.equal(runGit(fixture.repo, 'cat-file', '-e', `${fixture.rootOid}^{commit}`), '');
    assert.equal(runGit(fixture.repo, 'cat-file', '-e', `${movedOid}^{commit}`), '');

    const verify = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'verify-objects', '--repo', fixture.repo,
      '--snapshot-commit', fixture.inventoryCommit, '--snapshot', fixture.snapshot], { cwd: repoRoot, encoding: 'utf8' });
    assert.equal(verify.status, 0, `${verify.stdout ?? ''}${verify.stderr ?? ''}`);
    assert.match(verify.stdout, /PASS: all direct and peeled objects/);
  } finally {
    fs.rmSync(fixture.tempDir, { recursive: true, force: true });
  }
});

for (const invalidCase of ['missing', 'dirty', 'stale', 'contradictory', 'incomplete']) {
  test(`all apply modes fail closed for ${invalidCase} Phase 244 readiness inputs`, () => {
    const fixture = makeCapturedReadinessRepo();
    try {
      const verificationPath = '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-VERIFICATION.md';
      const evidencePath = '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json';
      let readinessCommit = fixture.inventoryCommit;
      if (invalidCase === 'missing') {
        fs.rmSync(path.join(fixture.repo, verificationPath));
        runGit(fixture.repo, 'add', '--', verificationPath);
        runGit(fixture.repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: remove verification source');
        const capture = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'capture-readiness', '--repo', fixture.repo], { cwd: repoRoot, encoding: 'utf8' });
        assert.equal(capture.status, 0, `${capture.stdout ?? ''}${capture.stderr ?? ''}`);
        runGit(fixture.repo, 'add', fixture.readiness);
        runGit(fixture.repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit blocked readiness');
        readinessCommit = runGit(fixture.repo, 'rev-parse', 'HEAD');
      } else if (invalidCase === 'dirty') {
        fs.appendFileSync(path.join(fixture.repo, verificationPath), '\nlocal uncommitted change\n');
      } else if (invalidCase === 'stale') {
        commitSourceChange(fixture, verificationPath, (file) => fs.appendFileSync(file, '\ncommitted source change\n'));
      } else if (invalidCase === 'contradictory') {
        commitSourceChange(fixture, evidencePath, (file) => {
          const evidence = JSON.parse(fs.readFileSync(file, 'utf8'));
          evidence.pr_disposition.decision_inputs.pr_state = 'OPEN';
          fs.writeFileSync(file, `${JSON.stringify(evidence, null, 2)}\n`);
        });
        const capture = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'capture-readiness', '--repo', fixture.repo], { cwd: repoRoot, encoding: 'utf8' });
        assert.equal(capture.status, 0, `${capture.stdout ?? ''}${capture.stderr ?? ''}`);
        runGit(fixture.repo, 'add', fixture.readiness);
        runGit(fixture.repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit contradictory readiness');
        readinessCommit = runGit(fixture.repo, 'rev-parse', 'HEAD');
      } else if (invalidCase === 'incomplete') {
        commitSourceChange(fixture, evidencePath, (file) => {
          const evidence = JSON.parse(fs.readFileSync(file, 'utf8'));
          delete evidence.final_main_consumer_receipt.example_playwright_shards.design_gallery;
          fs.writeFileSync(file, `${JSON.stringify(evidence, null, 2)}\n`);
        });
        const capture = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), 'capture-readiness', '--repo', fixture.repo], { cwd: repoRoot, encoding: 'utf8' });
        assert.equal(capture.status, 0, `${capture.stdout ?? ''}${capture.stderr ?? ''}`);
        runGit(fixture.repo, 'add', fixture.readiness);
        runGit(fixture.repo, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'commit', '-q', '-m', 'fixture: commit incomplete readiness');
        readinessCommit = runGit(fixture.repo, 'rev-parse', 'HEAD');
      }

      const refsBefore = runGit(fixture.repo, 'show-ref');
      const originBefore = runGit(fixture.bare, 'for-each-ref', '--format=%(refname)%09%(objectname)', 'refs/heads');
      for (const mode of ['local', 'tracking', 'remote', 'safety-publish']) {
        const result = spawnSync('bash', [path.join(testDir, 'prune-stale-branches.sh'), mode, ...readinessApplyArgs(fixture, readinessCommit)], {
          cwd: repoRoot,
          encoding: 'utf8',
        });
        const combined = `${result.stdout ?? ''}${result.stderr ?? ''}`;
        assert.notEqual(result.status, 0, `${invalidCase}/${mode} unexpectedly accepted invalid readiness:\n${combined}`);
        assert.match(combined, /d01_readiness_/, `${invalidCase}/${mode} did not stop at the D-01 readiness gate:\n${combined}`);
        assert.equal(runGit(fixture.repo, 'show-ref'), refsBefore, `${invalidCase}/${mode} changed local refs`);
        assert.equal(runGit(fixture.bare, 'for-each-ref', '--format=%(refname)%09%(objectname)', 'refs/heads'), originBefore, `${invalidCase}/${mode} changed origin refs`);
      }
    } finally {
      fs.rmSync(fixture.tempDir, { recursive: true, force: true });
    }
  });
}
