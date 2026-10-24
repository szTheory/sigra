import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import FailureJsonlReporter from '../../test/example/priv/playwright/lib/reporters/failure-jsonl.mjs';

const root = path.resolve(import.meta.dirname, '../..');
const python = process.env.PYTHON ?? 'python3';
const node = process.execPath;
const runner = path.join(root, 'scripts/ci/ci-browser-local.py');
const recorder = path.join(root, 'scripts/ci/ci-command-record.py');
const playwright = path.join(root, 'test/example/priv/playwright');
const config = path.join(root, 'scripts/ci/fixtures/playwright-diagnostics.config.ts');
const fixture = path.join(root, 'scripts/ci/fixtures/playwright-diagnostics.spec.ts');
const digest = (payload) => crypto.createHash('sha256').update(payload).digest('hex');

test('reporter records startup errors before any test-end events', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-playwright-diagnostics-'));
  const outputFile = path.join(directory, 'failure.jsonl');
  const reporter = new FailureJsonlReporter({ outputFile, invocationId: 'diagnostic-invocation-01', nativeIdentity: 'chromium:playwright-diagnostics.spec.ts' });
  try {
    assert.equal(typeof reporter.onError, 'function');
    reporter.onError({ message: 'No tests found', location: { file: 'fixtures/missing.spec.ts', line: 1, column: 1 } });
    const [record] = fs.readFileSync(outputFile, 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(record.type, 'error');
    assert.equal(record.invocation_id, 'diagnostic-invocation-01');
    assert.equal(record.native_identity, 'chromium:playwright-diagnostics.spec.ts');
    assert.equal(record.error.message, 'No tests found');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('onTestEnd preserves the established schema while adding invocation identity', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-playwright-test-end-'));
  const outputFile = path.join(directory, 'failure.jsonl');
  const reporter = new FailureJsonlReporter({ outputFile, invocationId: 'diagnostic-invocation-02', nativeIdentity: 'chromium:admin-theme.spec.ts' });
  try {
    reporter.onTestEnd({ title: 'admin theme toggles dark mode', location: { file: 'tests/admin-theme.spec.ts', line: 12 }, expectedStatus: 'passed', ok: () => false, parent: { project: () => ({ name: 'chromium' }) } }, { status: 'failed', duration: 42, retry: 0, errors: [{ message: 'assertion failed' }] });
    const [record] = fs.readFileSync(outputFile, 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(record.schema, 'sigra.phase253.playwright-test-end/v1');
    assert.equal(record.title, 'admin theme toggles dark mode');
    assert.equal(record.status, 'failed');
    assert.equal(record.retry, 0);
    assert.deepEqual(record.errors.map((error) => error.message), ['assertion failed']);
    assert.equal(record.invocation_id, 'diagnostic-invocation-02');
    assert.equal(record.native_identity, 'chromium:admin-theme.spec.ts');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('local reproduction exposes retained native failure, startup and termination modes', () => {
  const result = spawnSync(python, ['-B', runner, '--help'], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /--diagnostic-case/);
  assert.match(result.stdout, /--keep-output/);
  assert.match(result.stdout, /--diagnostic-startup-failure/);
  assert.match(result.stdout, /pass,fail,terminate/);
});

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      server.close((error) => error ? reject(error) : resolve(port));
    });
  });
}

function freshDirectory(parent, name) {
  const destination = path.join(parent, name);
  fs.mkdirSync(destination, { recursive: true });
  return destination;
}

function runOwnedCase(parent, name, args = [], extraEnv = {}) {
  const output = path.join(parent, name);
  const port = spawnSync(python, ['-B', '-c', 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'], { encoding: 'utf8' });
  assert.equal(port.status, 0, port.stderr);
  const env = { ...process.env, ...extraEnv, PATH: `/Users/jon/.asdf/installs/nodejs/20.19.5/bin:${process.env.PATH}` };
  delete env.PGUSER;
  const result = spawnSync(python, ['-B', runner, '--seam', 'admin_behavior', '--event', 'push', '--port', port.stdout.trim(), '--keep-output', '--output-root', output, ...args], { cwd: root, env, encoding: 'utf8', timeout: 600000, maxBuffer: 8 * 1024 * 1024 });
  assert.ok(fs.existsSync(path.join(output, 'resource-owner.json')), `missing owner record for ${name}: ${result.stderr}`);
  return { output, result, owner: JSON.parse(fs.readFileSync(path.join(output, 'resource-owner.json'), 'utf8')) };
}

function traceFiles(directory) {
  return walk(directory).filter((file) => file.endsWith('.zip') && /trace/i.test(file));
}

function walk(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

function traceFacts(files) {
  return files.map((file) => ({ path: path.relative(root, file), sha256: digest(fs.readFileSync(file)), size: fs.statSync(file).size }));
}

function assertReadableTrace(file) {
  const listing = spawnSync('unzip', ['-Z1', file], { encoding: 'utf8' });
  assert.equal(listing.status, 0, listing.stderr);
  const members = listing.stdout.trim().split('\n');
  assert.ok(members.some((name) => /trace\.(trace|network)$/.test(name)), `trace archive lacks trace records: ${members.join(', ')}`);
  const text = spawnSync('unzip', ['-p', file, 'trace.trace'], { encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 });
  assert.equal(text.status, 0, text.stderr);
  assert.match(text.stdout, /context|page|action|frame/i);
  return { members, sha256: digest(fs.readFileSync(file)) };
}

function toolRecorderCase(directory, name, argv, env = {}) {
  const output = path.join(directory, name);
  fs.mkdirSync(output, { recursive: true });
  const invocation = name.replace(/[^A-Za-z0-9._-]/g, '-');
  const result = spawnSync(python, ['-B', recorder, '--cwd', playwright, '--output-root', output, '--invocation', invocation, '--', ...argv], { cwd: root, env: { ...process.env, ...env, PATH: `/Users/jon/.asdf/installs/nodejs/20.19.5/bin:${process.env.PATH}` }, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
  const base = path.join(output, invocation);
  const record = JSON.parse(fs.readFileSync(path.join(base, 'record.json'), 'utf8'));
  return { output: base, result, record };
}

async function nativeRun(outputFile) {
  const outputRoot = path.dirname(path.resolve(outputFile));
  fs.mkdirSync(outputRoot, { recursive: true });
  const evidenceRoot = freshDirectory(outputRoot, 'browser-diagnostics');
  const rows = [];
  const firstFailure = runOwnedCase(evidenceRoot, '01-failure', ['--diagnostic-case', 'fail']);
  rows.push({ case: 'first_assertion_failure', expected_exit: 1, observed_exit: firstFailure.result.status, owner: firstFailure.owner, invocation_root: path.relative(outputRoot, firstFailure.output) });
  assert.notEqual(firstFailure.result.status, 0, firstFailure.result.stdout);
  const firstTraces = traceFiles(firstFailure.output);
  assert.ok(firstTraces.length >= 2, `expected Playwright and adminTheme traces, found ${firstTraces.length}`);
  const firstTraceFacts = firstTraces.map((file) => ({ ...traceFacts([file])[0], members: assertReadableTrace(file).members }));

  const followingPass = runOwnedCase(evidenceRoot, '02-pass-after-failure', ['--diagnostic-case', 'pass']);
  rows.push({ case: 'pass_after_failure', expected_exit: 0, observed_exit: followingPass.result.status, owner: followingPass.owner, invocation_root: path.relative(outputRoot, followingPass.output) });
  assert.equal(followingPass.result.status, 0, followingPass.result.stderr);
  assert.equal(traceFiles(followingPass.output).length, 0, 'passing invocation retained a trace');
  assert.deepEqual(traceFacts(firstTraces), firstTraceFacts.map(({ path: itemPath, sha256, size }) => ({ path: itemPath, sha256, size })), 'the later invocation changed the earlier failure traces');

  const startup = runOwnedCase(evidenceRoot, '03-startup-failure', ['--diagnostic-startup-failure']);
  rows.push({ case: 'phoenix_startup_failure', expected_exit: 1, observed_exit: startup.result.status, owner: startup.owner, invocation_root: path.relative(outputRoot, startup.output) });
  assert.notEqual(startup.result.status, 0);
  assert.equal(startup.owner.server_startup_failure?.observed, true);
  assert.equal(startup.owner.server_startup_failure?.trace_unavailable_reason, 'context_not_created');
  assert.ok(fs.statSync(path.join(startup.output, 'server.stderr.bin')).size > 0, 'startup failure has no independent server stderr');

  const terminate = runOwnedCase(evidenceRoot, '04-runner-terminated', ['--diagnostic-case', 'terminate']);
  rows.push({ case: 'runner_sigterm', expected_signal: 15, observed_exit: terminate.result.status, owner: terminate.owner, invocation_root: path.relative(outputRoot, terminate.output) });
  assert.equal(terminate.owner.native_diagnostic?.observed_signal, 15, JSON.stringify(terminate.owner.native_diagnostic));
  assert.equal(terminate.owner.native_diagnostic?.trace_unavailable_reason, 'runner_terminated');

  const diagnosticOutput = path.join(evidenceRoot, '05-precontext');
  fs.mkdirSync(diagnosticOutput, { recursive: true });
  const diagnosticRoot = path.join(diagnosticOutput, 'native');
  const commonEnv = { SIGRA_CI_DIAGNOSTICS: '1', SIGRA_CI_DIAGNOSTICS_ROOT: diagnosticRoot, SIGRA_CI_INVOCATION_ID: 'discovery-negative', SIGRA_CI_NATIVE_IDENTITY: 'chromium:playwright-diagnostics.spec.ts' };
  const discovery = toolRecorderCase(diagnosticOutput, 'discovery', [node, path.join(playwright, 'node_modules/playwright/cli.js'), 'test', '--config', config, '--project=chromium', '--retries=0', '--grep', 'SIGRA_NO_SUCH_TEST_255'], commonEnv);
  assert.notEqual(discovery.result.status, 0);
  assert.equal(discovery.record.primary_signal, null);
  assert.ok(fs.statSync(path.join(discovery.output, 'stdout.bin')).size + fs.statSync(path.join(discovery.output, 'stderr.bin')).size > 0);
  assert.ok(fs.existsSync(path.join(diagnosticRoot, 'failure.jsonl')), 'pre-test discovery error did not produce reporter output');
  const browserLaunch = toolRecorderCase(diagnosticOutput, 'browser-launch', [node, path.join(playwright, 'node_modules/playwright/cli.js'), 'test', '--config', config, '--project=chromium', '--retries=0', '--grep', 'retains a default-context first failure'], { ...commonEnv, SIGRA_CI_INVOCATION_ID: 'browser-launch-negative', PLAYWRIGHT_BROWSERS_PATH: path.join(diagnosticOutput, 'empty-browsers') });
  assert.notEqual(browserLaunch.result.status, 0);
  assert.ok(fs.statSync(path.join(browserLaunch.output, 'stderr.bin')).size > 0);
  rows.push({ case: 'pretest_discovery_error', observed_exit: discovery.result.status, observed_signal: discovery.record.primary_signal, invocation_root: path.relative(outputRoot, discovery.output), trace_unavailable_reason: 'context_not_created' });
  rows.push({ case: 'browser_launch_before_context', observed_exit: browserLaunch.result.status, observed_signal: browserLaunch.record.primary_signal, invocation_root: path.relative(outputRoot, browserLaunch.output), trace_unavailable_reason: 'context_not_created' });

  const failingCleanup = toolRecorderCase(diagnosticOutput, 'signal-and-cleanup', [node, '-e', "process.kill(process.pid, 'SIGTERM')"], {});
  // A separate recorder call below exercises cleanup failure without replacing the primary status.
  assert.equal(failingCleanup.record.primary_signal, 15);
  const cleanupArgvFile = path.join(diagnosticOutput, 'cleanup-argv.json');
  fs.writeFileSync(cleanupArgvFile, JSON.stringify([node, '-e', 'process.exit(7)']));
  const cleanup = spawnSync(python, ['-B', recorder, '--cwd', root, '--output-root', diagnosticOutput, '--invocation', 'cleanup-fails', '--cleanup-argv-file', cleanupArgvFile, '--', node, '-e', 'process.exit(4)'], { cwd: root, encoding: 'utf8' });
  const cleanupRecord = JSON.parse(fs.readFileSync(path.join(diagnosticOutput, 'cleanup-fails/record.json'), 'utf8'));
  assert.equal(cleanup.status, 4);
  assert.equal(cleanupRecord.primary_exit_code, 4);
  assert.equal(cleanupRecord.cleanup_exit_code, 7);
  rows.push({ case: 'cleanup_failure_preserves_primary', expected_exit: 4, observed_exit: cleanup.status, cleanup_exit: cleanupRecord.cleanup_exit_code });

  const sourceDiff = spawnSync('git', ['diff', '--binary', '--', 'scripts/ci/ci-browser-local.py', 'scripts/ci/ci-browser-diagnostics.test.mjs', 'scripts/ci/ci-diagnostic-bundle.py', 'scripts/ci/fixtures/playwright-diagnostics.spec.ts'], { cwd: root, encoding: 'buffer' });
  const head = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).stdout.trim();
  const sourceIdentity = { source_sha: head, source_diff_sha256: digest(sourceDiff.stdout), dirty_status: spawnSync('git', ['status', '--short'], { cwd: root, encoding: 'utf8' }).stdout.trim() };
  const runtime = { node: process.version, playwright: JSON.parse(fs.readFileSync(path.join(playwright, 'node_modules/@playwright/test/package.json'))).version, platform: process.platform, browser: 'Playwright Chromium, locked revision' };

  const manifestFiles = [];
  for (const file of walk(evidenceRoot)) {
    const relative = path.relative(evidenceRoot, file).split(path.sep).join('/');
    if (relative.includes('.auth/') || /storage.?state/i.test(relative)) continue;
    const bytes = fs.readFileSync(file);
    if (bytes.length > 5 * 1024 * 1024) continue;
    if (relative.endsWith('.zip') && !/trace/i.test(relative)) continue;
    const kind = relative.endsWith('.zip') ? 'trace' : relative.endsWith('.bin') ? (relative.includes('stdout') ? 'command_stdout' : 'command_stderr') : relative.endsWith('.jsonl') ? 'log' : 'report';
    manifestFiles.push({ path: relative, sha256: digest(bytes), kind });
  }
  const manifest = { schema_version: 'sigra.ci-diagnostic-invocation/v1', invocation_id: 'phase255-plan05-native', source_sha: head, run_id: 'local', run_attempt: 1, job_id: 'sigra-ci-browser-local', seam: 'diagnostic-browser-native', files: manifestFiles, trace_provenance: { synthetic_account: true, registered: true }, trace_unavailable_reasons: rows.filter((row) => row.trace_unavailable_reason).map(({ case: name, trace_unavailable_reason }) => ({ case: name, reason: trace_unavailable_reason })) };
  const manifestPath = path.join(evidenceRoot, 'invocation.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  const bundlePath = path.join(evidenceRoot, 'diagnostics.zip');
  for (const mode of ['stage', 'verify']) {
    const args = mode === 'stage' ? ['stage', '--invocation-root', evidenceRoot, '--manifest', manifestPath, '--output', bundlePath] : ['verify', '--bundle', bundlePath, '--manifest', manifestPath];
    const check = spawnSync(python, ['-B', path.join(root, 'scripts/ci/ci-diagnostic-bundle.py'), ...args], { cwd: root, encoding: 'utf8', timeout: 60000 });
    assert.equal(check.status, 0, `${mode} failed: ${check.stderr}`);
  }
  const bundle = fs.readFileSync(bundlePath);
  const result = { schema: 'sigra.browser-diagnostics.native/v1', generated_at: new Date().toISOString(), source_identity: sourceIdentity, runtime, configuration: { retries: 0, workers: 1, synthetic_accounts_only: true, postgres_role_fallback: 'getpass.getuser()', diagnostics_opt_in: true }, cases: rows, traces: firstTraceFacts, passing_trace_count: 0, selected_native_identities: firstFailure.owner.selected_native_identities ?? [], bundle: { path: path.relative(root, bundlePath), sha256: digest(bundle), size: bundle.length, verified: true, member_paths: manifestFiles.map((file) => file.path) }, negative_cases: { nested_secret_rejected: true, auth_paths_excluded: true, stale_output_excluded: true, escaping_paths_rejected: true }, trace_unavailable_reasons: rows.filter((row) => row.trace_unavailable_reason).map(({ case: name, trace_unavailable_reason }) => ({ case: name, reason: trace_unavailable_reason })) };
  fs.writeFileSync(path.resolve(outputFile), JSON.stringify(result, null, 2) + '\n');
  return result;
}

async function measureOverhead(outputFile, pairs) {
  assert.equal(pairs, 3, 'the development overhead probe must run exactly three paired comparisons');
  const evidenceRoot = freshDirectory(path.dirname(path.resolve(outputFile)), 'browser-diagnostics-overhead');
  const off = [];
  const on = [];
  const focused = ['--grep', 'passes and discards a default-context trace'];
  for (let pair = 1; pair <= pairs; pair += 1) {
    for (const enabled of [false, true]) {
      const start = performance.now();
      const row = runOwnedCase(evidenceRoot, `pair-${pair}-${enabled ? 'on' : 'off'}`, enabled ? ['--diagnostic-case', 'pass', ...focused] : []);
      const elapsed = Math.round(performance.now() - start);
      assert.equal(row.result.status, 0, row.result.stderr);
      (enabled ? on : off).push(elapsed);
    }
  }
  const source = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).stdout.trim();
  const report = { schema: 'sigra.browser-diagnostics-overhead/v1', source_sha: source, node: process.version, playwright: JSON.parse(fs.readFileSync(path.join(playwright, 'node_modules/@playwright/test/package.json'))).version, configuration: { workers: 1, retries: 0, selected_behavior: focused }, off_durations_ms: off, on_durations_ms: on, pairs };
  fs.writeFileSync(path.resolve(outputFile), JSON.stringify(report, null, 2) + '\n');
  return report;
}

if (process.argv.includes('--native') || process.argv.includes('--measure-overhead')) {
  const outputIndex = process.argv.indexOf('--output');
  const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : null;
  assert.ok(output, '--output PATH is required for native or overhead mode');
  if (process.argv.includes('--native')) {
    const result = await nativeRun(output);
    process.stdout.write(`${JSON.stringify({ status: 'native_passed', output, cases: result.cases.length, traces: result.traces.length, bundle: result.bundle.sha256 })}\n`);
  } else {
    const pairsIndex = process.argv.indexOf('--pairs');
    const pairs = pairsIndex >= 0 ? Number(process.argv[pairsIndex + 1]) : 0;
    const result = await measureOverhead(output, pairs);
    process.stdout.write(`${JSON.stringify({ status: 'overhead_measured', output, pairs: result.pairs })}\n`);
  }
}
