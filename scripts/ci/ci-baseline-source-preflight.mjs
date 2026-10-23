#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const EXPECTED = [
  { identity: 'application_sha', sha: 'd4dcc1939bd1f1590f6ca01d55b861e31acc745f', ref: 'refs/gsd/phase254/baseline-application' },
  { identity: 'producer_source_sha', sha: 'cc8cd273bfe8bbbfbab6b33564efdede4d9f0d17', ref: 'refs/gsd/phase254/baseline-producer' },
];
const TREE = 'bcda2b1eb386bdbaaf1bde2b6f034e0c7ee74452';
const BUNDLE_SHA = '95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30';
const SELF = fileURLToPath(import.meta.url);
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
function args(argv) {
  const result = { checkOnly: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--check-only') result.checkOnly = true;
    else if (['--root', '--contract', '--bundle', '--output'].includes(argv[i]) && argv[i + 1]) result[argv[i].slice(2)] = argv[++i];
    else throw new Error(`unknown_or_incomplete_argument:${argv[i]}`);
  }
  for (const key of ['root', 'contract', 'bundle', 'output']) if (!result[key]) throw new Error(`missing_argument:--${key}`);
  return result;
}
function git(root, ...cmd) {
  try { return execFileSync('git', ['-C', root, ...cmd], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); }
  catch { return null; }
}
function blob(root, commit, file) {
  const result = spawnSync('git', ['-C', root, 'show', `${commit}:${file}`], { encoding: 'buffer', stdio: ['ignore', 'pipe', 'ignore'] });
  return result.status === 0 ? result.stdout : null;
}

export function inspect({ root, contractPath, bundlePath }) {
  const checks = [];
  const add = (id, expected, actual) => checks.push({ id, expected, actual, matches: expected === actual });
  const contract = JSON.parse(readFileSync(contractPath, 'utf8'));
  const captureFile = path.join(path.dirname(contractPath), '..', '254-speed-up-the-measured-slow-jobs', '254-BASELINE-PREFLIGHT.json');
  const capture = JSON.parse(readFileSync(captureFile, 'utf8'));
  const bundleHash = existsSync(bundlePath) ? sha256(readFileSync(bundlePath)) : null;
  add('source_bundle_sha256', BUNDLE_SHA, bundleHash);
  add('contract_bundle_sha256', contract.baseline_identity.source_bundle_sha256, bundleHash);
  const sources = [];
  for (const expected of EXPECTED) {
    const commit = git(root, 'rev-parse', '--verify', `${expected.sha}^{commit}`);
    const retained = git(root, 'rev-parse', '--verify', expected.ref);
    const tree = commit ? git(root, 'rev-parse', `${commit}^{tree}`) : null;
    const source = { ...expected, commit_matches: commit === expected.sha && retained === expected.sha, retained_ref_value: retained, actual_commit: commit, tree: tree, tree_matches: tree === TREE, workload_files: [] };
    const workload = capture.sources.find((item) => item.identity === expected.identity);
    const workflowPath = '.github/workflows/ci.yml';
    const workflowBytes = commit ? blob(root, commit, workflowPath) : null;
    const workflowHash = workflowBytes === null ? null : sha256(workflowBytes);
    source.workflow_sha256 = workflowHash;
    source.workflow_matches = workflowHash === workload?.workflow_sha256 && workflowHash === contract.baseline_identity.workflow_file_sha256;
    for (const declared of workload?.workload_files ?? []) {
      const blobBytes = commit ? blob(root, commit, declared.path) : null;
      const actual = blobBytes === null ? null : sha256(blobBytes);
      source.workload_files.push({ path: declared.path, expected: declared.expected_sha256, actual, matches: actual === declared.expected_sha256 });
    }
    add(`${expected.identity}.commit`, expected.sha, commit);
    add(`${expected.identity}.retained_ref`, expected.sha, retained);
    add(`${expected.identity}.tree`, TREE, tree);
    add(`${expected.identity}.workflow_sha256`, workload?.workflow_sha256, workflowHash);
    for (const file of source.workload_files) add(`${expected.identity}.blob:${file.path}`, file.expected, file.actual);
    sources.push(source);
  }
  add('contract_application_sha', EXPECTED[0].sha, contract.baseline_identity.application_sha);
  add('contract_producer_sha', EXPECTED[1].sha, contract.baseline_identity.producer_source_sha);
  add('contract_workflow_sha256', capture.sources[0]?.workflow_sha256, contract.baseline_identity.workflow_file_sha256);
  const archiveVerifier = path.join(root, 'scripts/ci/ci-run-metrics.sh');
  const baselinePath = path.join(path.dirname(contractPath), '252-BASELINE.json');
  const archiveCheck = spawnSync('bash', [archiveVerifier, '--verify-baseline', '--source-bundle', bundlePath, '--baseline', baselinePath], { cwd: root, encoding: 'utf8', timeout: 120000 });
  checks.push({ id: 'archive_verifier', expected: 'ready', actual: archiveCheck.status === 0 ? 'ready' : (archiveCheck.stderr || archiveCheck.stdout || `exit_${archiveCheck.status}`).trim(), matches: archiveCheck.status === 0 });
  return {
    schema_version: 'sigra.phase254.source-readiness/v1', captured_at: new Date().toISOString(),
    status: checks.every((check) => check.matches) ? 'ready' : 'blocked', synthetic: false,
    source_identities: EXPECTED.map(({ identity, sha, ref }) => ({ identity, sha, retained_ref: ref })),
    paths: { root: path.resolve(root), contract: path.resolve(contractPath), bundle: path.resolve(bundlePath) },
    sources, checks,
    acceptance_status: 'not_started', hosted_cache_or_image_readiness: 'not_inferred',
  };
}

try {
  const options = args(process.argv.slice(2));
  const record = inspect({ root: path.resolve(options.root), contractPath: path.resolve(options.root, options.contract), bundlePath: path.resolve(options.root, options.bundle) });
  if (!options.checkOnly) {
    const output = path.resolve(options.root, options.output);
    mkdirSync(path.dirname(output), { recursive: true });
    writeFileSync(output, `${JSON.stringify(record, null, 2)}\n`);
  }
  console.log(JSON.stringify({ status: record.status, checks_failed: record.checks.filter((check) => !check.matches).map((check) => check.id), output: options.checkOnly ? null : options.output }));
  if (record.status !== 'ready') process.exitCode = 2;
} catch (error) {
  console.error(error.message);
  process.exitCode = 2;
}
