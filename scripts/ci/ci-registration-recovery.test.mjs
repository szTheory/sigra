import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { attemptDirectory, captureOwnedDatabaseAbsence, runLogged, validateSanitizedCommandLog, verifyDiagnosticData, verifyNativeAttempt, verifyRevisionFreezeBinding } from './ci-registration-recovery.mjs';
import * as recovery from './ci-registration-recovery.mjs';
import { createRegistrationNativeTreeFixture, fixtureFileSha256, SELECTED_TITLE, SYNTHETIC_LABEL } from './fixtures/registration-native-tree.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const runner = path.join(root, 'scripts/ci/ci-registration-repro.sh');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-recovery-red-'));

// Ordinary runner contracts must never open a server or socket (D-11). Any attempt is
// recorded and refused; the final test of this file asserts the record stays empty.
const networkAttempts = [];
const originalConnect = net.Socket.prototype.connect;
const originalListen = net.Server.prototype.listen;
net.Socket.prototype.connect = function guardedConnect(...args) {
  networkAttempts.push(['connect', JSON.stringify(args[0])]);
  throw new Error('ordinary registration runner contracts must not open sockets');
};
net.Server.prototype.listen = function guardedListen(...args) {
  networkAttempts.push(['listen', JSON.stringify(args[0])]);
  throw new Error('ordinary registration runner contracts must not start servers');
};

test('diagnostic verification rejects caller-written success without native receipts', () => {
  const evidence = path.join(temporary, 'forged-success.json');
  fs.writeFileSync(evidence, JSON.stringify({
    schema_version: 'sigra.phase253.registration-recovery-evidence/v1',
    status: 'not_reproduced',
    requirements: { 'CIREL-01': 'unsatisfied' },
    attempts: [{ project: 'admin-eval', outcome: 'passed' }]
  }));

  const result = spawnSync(runner, ['--verify-diagnostic', evidence], { encoding: 'utf8' });

  assert.equal(result.status, 3, `${result.stdout}\n${result.stderr}`);
  assert.match(result.stderr, /native report|native receipts/i);
});

test('the original controls and acceptance verification modes remain unavailable', () => {
  const evidence = path.join(temporary, 'legacy-forged.json');
  fs.writeFileSync(evidence, JSON.stringify({ status: 'fixed', projects: [] }));

  for (const mode of ['--verify-controls', '--verify-acceptance']) {
    const result = spawnSync(runner, [mode, evidence], { encoding: 'utf8' });
    assert.equal(result.status, 3, `${mode}: ${result.stdout}\n${result.stderr}`);
  }
});

test('control verification requires native outcomes instead of caller-written passed status', () => {
  assert.equal(typeof recovery.verifyControlEvidenceData, 'function');
  const result = recovery.verifyControlEvidenceData(
    { status: 'passed', attempts: [], limits: { used_slots: [] } },
    {},
    temporary,
  );
  assert.equal(result.ok, false);
  assert.ok(result.errors.length > 0);
});

test('control recovery ledger carries every prior charge and maps each unused reservation once', () => {
  assert.equal(typeof recovery.buildControlRecoveryLedger, 'function');
  const ledger = recovery.buildControlRecoveryLedger({
    charges: [3768, 3743, 26373, 46803, 40993, 121252, 112],
    physicalPlaywrightLaunches: 4,
    spentReservations: ['D19-DIAG-01', 'R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE', 'R-DIAG-CONTROL-DARK'],
    retryUsed: 1,
    retryAvailable: 0,
    preparationMaximumMs: 116232,
    preparationUsedMs: 3743
  });

  assert.equal(ledger.prior_charge_ms, 243044);
  assert.equal(ledger.preparation_remaining_ms, 112489);
  assert.equal(ledger.launch_unit, 'playwright_cli_process');
  assert.deepEqual(ledger.slots.map(({ id, maps_from, project }) => [id, maps_from, project]), [
    ['CR-DARK-FIRST', 'R-CONTROL-FIRST-DESKTOP', ['admin-eval-dark']],
    ['CR-DESKTOP-MOBILE-FIRST', 'R-CONTROL-FIRST-MOBILE', ['admin-eval', 'admin-eval-mobile']],
    ['CR-DESKTOP-SECOND', 'R-CONTROL-SECOND-DESKTOP', ['admin-eval']],
    ['CR-MOBILE-SECOND', 'R-CONTROL-SECOND-MOBILE', ['admin-eval-mobile']],
    ['CR-DARK-SECOND', 'R-CONTROL-SECOND-DARK', ['admin-eval-dark']]
  ]);
  assert.equal(ledger.d19_max_ms, 955533);
  assert.equal(ledger.total_max_ms, 3295533);
});

test('control recovery ledger refuses altered charges, reopened retries, or duplicate reservation mappings', () => {
  assert.equal(typeof recovery.buildControlRecoveryLedger, 'function');
  const valid = {
    charges: [3768, 3743, 26373, 46803, 40993, 121252, 112],
    physicalPlaywrightLaunches: 4,
    spentReservations: ['D19-DIAG-01', 'R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE', 'R-DIAG-CONTROL-DARK'],
    retryUsed: 1,
    retryAvailable: 0,
    preparationMaximumMs: 116232,
    preparationUsedMs: 3743
  };
  for (const mutate of [
    (input) => { input.charges[5] = 121251; },
    (input) => { input.retryAvailable = 1; },
    (input) => { input.retryUsed = 0; },
    (input) => { input.spentReservations.push('R-CONTROL-FIRST-DESKTOP'); },
    (input) => { input.physicalPlaywrightLaunches = 3; },
    (input) => { input.preparationUsedMs = 3744; }
  ]) {
    const input = structuredClone(valid);
    mutate(input);
    assert.throws(() => recovery.buildControlRecoveryLedger(input), /historical|retry|reservation|launch|preparation/i);
  }
});

function processGone(pid) {
  try { process.kill(pid, 0); return false; } catch (error) { return error.code === 'ESRCH'; }
}

// Fixture process tree: the child spawns a grandchild that ignores SIGTERM, waits for the
// grandchild's ready line, then publishes both PIDs atomically (write + rename) so the test can
// wait on a directory event instead of sleeping.
function treeScript(readyDir, { childExitsAfterReady = false } = {}) {
  const grandchild = 'process.on("SIGTERM",()=>{}); process.stdout.write("READY "+process.pid+"\\n"); setInterval(()=>{},1e6)';
  return `
const fs = require("node:fs"); const path = require("node:path");
const grandchild = require("node:child_process").spawn(process.execPath, ["-e", ${JSON.stringify(grandchild)}], { stdio: ["ignore", "pipe", "inherit"] });
grandchild.stdout.once("data", (chunk) => {
  const pids = { child: process.pid, grandchild: Number(String(chunk).trim().split(" ")[1]) };
  const tmp = path.join(${JSON.stringify(readyDir)}, "tree.tmp");
  fs.writeFileSync(tmp, JSON.stringify(pids));
  fs.renameSync(tmp, path.join(${JSON.stringify(readyDir)}, "tree.json"));
  ${childExitsAfterReady ? 'process.exit(0);' : 'process.on("SIGTERM", () => process.exit(0)); setInterval(() => {}, 1e6);'}
});`;
}

function whenTreeReady(readyDir) {
  const file = path.join(readyDir, 'tree.json');
  return new Promise((resolve) => {
    const watcher = fs.watch(readyDir, () => {
      if (fs.existsSync(file)) { watcher.close(); resolve(JSON.parse(fs.readFileSync(file, 'utf8'))); }
    });
    if (fs.existsSync(file)) { watcher.close(); resolve(JSON.parse(fs.readFileSync(file, 'utf8'))); }
  });
}

test('bounded process runner terminates a stalled child and its grandchild and records the real timeout', { timeout: 30000 }, async () => {
  const log = path.join(temporary, 'stalled-tree.log');
  const childScript = 'require("node:child_process").spawn(process.execPath,["-e",' + JSON.stringify('setTimeout(()=>process.stdout.write("grandchild-finished\\n"),1800)') + '],{stdio:["ignore",1,2]}); setTimeout(()=>{},5000)';
  const result = await recovery.runLoggedTree(process.execPath, ['-e', childScript], root, process.env, log, 350, 100);
  assert.equal(result.timed_out, true);
  assert.notEqual(result.signal, null);
  assert.ok(result.duration_ms >= 350);
  assert.equal(processGone(-result.pid), true, 'the whole owned process group is gone when the runner resolves');
  assert.equal(fs.readFileSync(log, 'utf8').includes('grandchild-finished'), false);
});

test('abort escalates to SIGKILL for a SIGTERM-resistant grandchild after the child exits first', { timeout: 30000 }, async () => {
  const readyDir = fs.mkdtempSync(path.join(temporary, 'tree-abort-'));
  const controller = new AbortController();
  const pending = recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir)], root, process.env, path.join(readyDir, 'run.log'), 60000, 200, { signal: controller.signal });
  const tree = await whenTreeReady(readyDir);
  controller.abort();
  const result = await pending;

  assert.equal(result.aborted, true);
  assert.equal(result.timed_out, false);
  assert.deepEqual(result.group_signals, ['SIGTERM', 'SIGKILL']);
  assert.equal(result.descendants_reaped, true);
  assert.equal(processGone(tree.child), true);
  assert.equal(processGone(tree.grandchild), true);
  assert.equal(processGone(-result.pid), true);
});

test('a real deadline reaps a SIGTERM-resistant descendant and keeps the actual timeout and duration', { timeout: 30000 }, async () => {
  const readyDir = fs.mkdtempSync(path.join(temporary, 'tree-deadline-'));
  const result = await recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir)], root, process.env, path.join(readyDir, 'run.log'), 1500, 200);
  assert.equal(result.timed_out, true);
  assert.ok(result.duration_ms >= 1500);
  assert.equal(result.descendants_reaped, true);
  assert.equal(processGone(-result.pid), true);
  if (fs.existsSync(path.join(readyDir, 'tree.json'))) {
    const tree = JSON.parse(fs.readFileSync(path.join(readyDir, 'tree.json'), 'utf8'));
    assert.equal(processGone(tree.grandchild), true);
  }
});

test('a clean child exit never leaves a SIGTERM-resistant descendant running', { timeout: 30000 }, async () => {
  const readyDir = fs.mkdtempSync(path.join(temporary, 'tree-orphan-'));
  const pending = recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir, { childExitsAfterReady: true })], root, process.env, path.join(readyDir, 'run.log'), 60000, 200);
  const result = await pending;
  const tree = JSON.parse(fs.readFileSync(path.join(readyDir, 'tree.json'), 'utf8'));

  assert.equal(result.exit_code, 0);
  assert.equal(result.timed_out, false);
  assert.equal(result.descendants_reaped, true);
  assert.equal(processGone(tree.grandchild), true);
});

test('the legacy revision freeze entrypoint refuses a clean candidate and spent records without native work', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'legacy-create' });
  try {
    const freeze = path.join(fixture.base, 'registration-revision.json');
    const create = fixture.run(['--create-revision', '--output', freeze]);

    assert.equal(create.status, 3, `${create.stdout}\n${create.stderr}`);
    assert.match(create.stderr, /preserved config status|zero-native-launch preparation ledger/i);
    assert.equal(fs.existsSync(freeze), false);
    assert.deepEqual(fixture.stubCalls(), []);
  } finally { fixture.cleanup(); }
});

test('runner floors fractional millisecond process timeouts before spawnSync', () => {
  const log = path.join(temporary, 'fractional-timeout.log');
  const result = runLogged(process.execPath, ['-e', 'setTimeout(() => {}, 200)'], root, process.env, log, 118654.22791698575);

  assert.equal(result.error, null);
  assert.equal(result.exit_code, 0);
  assert.match(fs.readFileSync(log, 'utf8'), /^$/);
});

test('browser attempt output gets a unique directory beside preserved preflight logs', () => {
  const slotDirectory = path.join(temporary, 'D19-DIAG-01');
  fs.mkdirSync(slotDirectory, { recursive: true });
  fs.writeFileSync(path.join(slotDirectory, 'runner-preflight-error.log'), 'preserved exact runner error\n');

  const attempt = attemptDirectory(temporary, 'D19-DIAG-01', 1);

  assert.notEqual(attempt, slotDirectory);
  assert.equal(fs.readFileSync(path.join(slotDirectory, 'runner-preflight-error.log'), 'utf8'), 'preserved exact runner error\n');
  assert.equal(fs.existsSync(attempt), false);
});

test('revision attempt directory creates the missing slot parent before any native setup', () => {
  assert.equal(typeof recovery.createAttemptDirectory, 'function');
  if (typeof recovery.createAttemptDirectory !== 'function') return;
  const base = path.join(temporary, 'new-revision-output');
  const attempt = recovery.createAttemptDirectory(base, 'R-DIAG-DESKTOP');
  assert.equal(fs.existsSync(attempt), true);
  assert.equal(path.relative(base, attempt), path.join('R-DIAG-DESKTOP', 'attempt-01'));
});

test('revision attempt directory collisions preserve existing native artifacts', () => {
  const base = path.join(temporary, 'collision-output');
  const existing = path.join(base, 'R-DIAG-DESKTOP', 'attempt-01');
  fs.mkdirSync(existing, { recursive: true });
  const marker = path.join(existing, 'prior-receipt.log');
  fs.writeFileSync(marker, 'preserve the existing attempt');

  assert.throws(() => recovery.createAttemptDirectory(base, 'R-DIAG-DESKTOP'), /refusing to overwrite/);
  assert.equal(fs.readFileSync(marker, 'utf8'), 'preserve the existing attempt');
});

function fakeSocketFactory(script) {
  return () => {
    const socket = new EventEmitter();
    socket.destroyed = false;
    socket.destroy = () => { socket.destroyed = true; };
    socket.setTimeout = (_ms, callback) => { socket.timeoutCallback = callback; };
    process.nextTick(() => script(socket));
    return socket;
  };
}

test('port availability reads an injected connect seam and opens no socket', async () => {
  const occupied = await recovery.portAvailable(25311, { connect: fakeSocketFactory((socket) => socket.emit('connect')) });
  const refused = await recovery.portAvailable(25311, { connect: fakeSocketFactory((socket) => socket.emit('error', Object.assign(new Error('refused'), { code: 'ECONNREFUSED' }))) });
  const unknown = await recovery.portAvailable(25311, { connect: fakeSocketFactory((socket) => socket.emit('error', Object.assign(new Error('boom'), { code: 'EACCES' }))) });
  const stalled = await recovery.portAvailable(25311, { connect: fakeSocketFactory((socket) => socket.timeoutCallback()) });

  assert.equal(occupied, false, 'a successful connect means the fixture port is occupied');
  assert.equal(refused, true, 'ECONNREFUSED means the port is free');
  assert.equal(unknown, false, 'any other error is not proof of availability');
  assert.equal(stalled, false, 'a stalled probe is not proof of availability');
  assert.deepEqual(networkAttempts, []);
});

test('readiness fails immediately when the app child already exited before HTTP readiness', async () => {
  const probes = [];
  const result = await recovery.waitReady({ exitCode: 1, signalCode: null }, 'http://127.0.0.1:1/', Number(process.hrtime.bigint()) / 1e6 + 1000, { probe: async (url) => { probes.push(url); return 200; } });
  assert.equal(result, null);
  assert.deepEqual(probes, []);
});

test('readiness polls an injected probe on an injected clock until HTTP 200 or the deadline', async () => {
  let clock = 1000;
  const sleeps = [];
  const options = (statuses) => ({
    now: () => clock,
    sleep: async (ms) => { sleeps.push(ms); clock += ms; },
    probe: async () => statuses.shift() ?? null
  });
  const ready = await recovery.waitReady({ exitCode: null, signalCode: null }, 'http://127.0.0.1:1/', 1600, options([null, 503, 200]));
  assert.equal(ready, 200);
  assert.equal(sleeps.length, 2);

  clock = 1000; sleeps.length = 0;
  const expired = await recovery.waitReady({ exitCode: null, signalCode: null }, 'http://127.0.0.1:1/', 1100, options([]));
  assert.equal(expired, null);
  assert.ok(sleeps.reduce((sum, ms) => sum + ms, 0) <= 100, 'readiness never sleeps past its deadline');
  assert.deepEqual(networkAttempts, []);
});

test('one-use infrastructure retry requires the independently reviewed Chromium bootstrap failure', () => {
  assert.equal(typeof recovery.validateInfrastructureRetry, 'function');
  if (typeof recovery.validateInfrastructureRetry !== 'function') return;
  const reviewed = {
    evidence_sha256: 'evidence-hash',
    test_log_sha256: 'test-log-hash',
    native_attempt_charge_ms: 26373,
    total_charge_ms: 33884,
    status: 'independently_classified_infrastructure',
    retry_used: false,
    shared_retry_allowance: 1,
    failure: 'Chromium headless shell SIGTRAP at macOS Mach port bootstrap_check_in with Permission denied (1100), before selected test began'
  };
  const prior = {
    status: 'halted', freeze_sha256: 'freeze-hash',
    limits: { historical_charge_ms: 3768, preparation_charge_ms: 3743, charged_duration_ms: 33884, browser_launches: 1, used_slots: ['R-DIAG-DESKTOP'] },
    attempts: [{ slot_id: 'R-DIAG-DESKTOP', project: 'admin-eval', charged_duration_ms: 26373,
      test_started: false, failure_classification: 'infrastructure', server: { http_status: 200 },
      database: { setup_exit_code: 0, drop_exit_code: 0 }, browser: { launched: true }, files: { test_log: { sha256: 'test-log-hash' } } }]
  };
  assert.deepEqual(recovery.validateInfrastructureRetry(prior, reviewed), { ok: true, errors: [] });
  const mutations = [
    (record, review) => { review.retry_used = true; },
    (record) => { record.attempts[0].test_started = true; },
    (record) => { record.attempts[0].database.drop_exit_code = 1; },
    (record) => { record.attempts[0].files.test_log.sha256 = 'changed'; },
    (record, review) => { review.failure = 'unclassified'; },
    (record) => { record.limits.charged_duration_ms = 0; }
  ];
  for (const mutate of mutations) {
    const record = structuredClone(prior); const review = structuredClone(reviewed);
    mutate(record, review);
    assert.equal(recovery.validateInfrastructureRetry(record, review).ok, false);
  }

});

test('the infrastructure retry entrypoint rejects mismatched or ineligible preserved evidence in a clean candidate', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'retry' });
  try {
    const output = path.join(fixture.base, 'retry-freeze.json');
    const reservation = path.join(fixture.base, 'retry-reservation.json');
    const review = path.join(fixture.base, 'retry-review.json');
    const create = () => fixture.run(['--create-infrastructure-retry', '--freeze', fixture.freezePath, '--evidence', fixture.evidencePath, '--review', review, '--output', output, '--reservation', reservation]);

    fs.writeFileSync(review, `${JSON.stringify({ evidence_sha256: 'f'.repeat(64), status: 'independently_classified_infrastructure' })}\n`);
    const mismatched = create();
    assert.equal(mismatched.status, 3, `${mismatched.stdout}\n${mismatched.stderr}`);
    assert.match(mismatched.stderr, /digest does not match preserved bytes/);

    fs.writeFileSync(review, `${JSON.stringify({ evidence_sha256: fixtureFileSha256(fixture.evidencePath), status: 'independently_classified_infrastructure', retry_used: false, shared_retry_allowance: 1 })}\n`);
    const ineligible = create();
    assert.equal(ineligible.status, 3, `${ineligible.stdout}\n${ineligible.stderr}`);
    assert.match(ineligible.stderr, /infrastructure retry rejected/);

    assert.equal(fs.existsSync(output), false);
    assert.equal(fs.existsSync(reservation), false);
    assert.deepEqual(fixture.stubCalls(), []);
  } finally { fixture.cleanup(); }
});

test('revision evidence binds to the freeze file digest while validating its internal digest separately', () => {
  const freeze = { schema_version: 'sigra.phase253.registration-replan-freeze/v1', status: 'frozen_before_results', payload: 'frozen' };
  freeze.freeze_sha256 = crypto.createHash('sha256').update(JSON.stringify(freeze)).digest('hex');
  const fileHash = crypto.createHash('sha256').update(`${JSON.stringify(freeze, null, 2)}\n`).digest('hex');
  const evidence = { freeze_sha256: fileHash };
  assert.notEqual(freeze.freeze_sha256, fileHash, 'pretty-printed on-disk freeze bytes have their own digest');
  assert.equal(verifyRevisionFreezeBinding(evidence, freeze, fileHash), true);
  assert.equal(verifyRevisionFreezeBinding(evidence, freeze, freeze.freeze_sha256), false);
  freeze.freeze_sha256 = 'forged';
  assert.equal(verifyRevisionFreezeBinding(evidence, freeze, fileHash), false);
});

test('each diagnostic uses its own physical Mix build for setup, server and cleanup', () => {
  const first = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-build-first-'));
  const second = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-build-second-'));
  try {
    const inherited = { ...process.env, MIX_BUILD_PATH: '/shared/compiled-at-port-4011', PORT: '4011' };
    const one = recovery.diagnosticEnvironment({ port: 25311 }, 'first_database', first, inherited);
    const two = recovery.diagnosticEnvironment({ port: 25312 }, 'second_database', second, inherited);
    assert.equal(one.MIX_BUILD_PATH, path.join(fs.realpathSync(first), 'mix-build'));
    assert.equal(two.MIX_BUILD_PATH, path.join(fs.realpathSync(second), 'mix-build'));
    assert.notEqual(one.MIX_BUILD_PATH, two.MIX_BUILD_PATH);
    assert.equal(fs.existsSync(one.MIX_BUILD_PATH), false);
    assert.equal(one.PORT, '25311');
    assert.equal(two.PORT, '25312');
    assert.notEqual(one.PORT, inherited.PORT);
    assert.notEqual(two.PORT, inherited.PORT);
    for (const command of ['setup', 'server', 'drop']) {
      const log = path.join(first, `${command}.log`);
      const receipt = runLogged(process.execPath, ['-e', 'process.stdout.write(JSON.stringify({build:process.env.MIX_BUILD_PATH,port:process.env.PORT,database:process.env.PGDATABASE}))'], root, one, log, 2000);
      assert.equal(receipt.exit_code, 0);
      assert.deepEqual(JSON.parse(fs.readFileSync(log, 'utf8')), { build: one.MIX_BUILD_PATH, port: '25311', database: 'first_database' });
    }
  } finally {
    fs.rmSync(first, { recursive: true, force: true });
    fs.rmSync(second, { recursive: true, force: true });
  }
});

test('command logs remove development signing keys before a receipt hashes their bytes', () => {
  const log = path.join(temporary, 'development-key.log');
  const receipt = runLogged(process.execPath, ['-e', 'process.stdout.write("Mix config: secret_key_base: " + JSON.stringify("synthetic-development-key") + "\\n")'], root, process.env, log, 2000);
  assert.equal(receipt.exit_code, 0);
  assert.equal(receipt.redacted_secret_fields, 1);
  const bytes = fs.readFileSync(log);
  assert.equal(bytes.includes(Buffer.from('synthetic-development-key')), false);
  assert.match(bytes.toString(), /secret_key_base: "\[REDACTED\]"/);
  const digest = crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(log)).digest('hex'), digest);
});

test('command logs redact the complete seeded demo credentials block before hashing', () => {
  const log = path.join(temporary, 'synthetic-demo-credentials.log');
  const output = [
    'migration complete',
    '',
    '=== Demo Credentials ===',
    '[synthetic] synthetic@example.invalid SYNTHETIC-SEEDED-PASSWORD (fixture)',
    '',
    'seed process complete',
    ''
  ].join('\n');
  const receipt = runLogged(process.execPath, ['-e', `process.stdout.write(${JSON.stringify(output)})`], root, process.env, log, 2000);
  const bytes = fs.readFileSync(log);
  const sanitized = bytes.toString();

  assert.equal(receipt.exit_code, 0);
  assert.equal(receipt.redacted_credential_blocks, 1);
  assert.equal(bytes.includes(Buffer.from('SYNTHETIC-SEEDED-PASSWORD')), false);
  assert.equal(bytes.includes(Buffer.from('synthetic@example.invalid')), false);
  assert.match(sanitized, /=== Demo Credentials ===\n\[REDACTED seeded demo credentials\]/);
  assert.match(sanitized, /seed process complete/);
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), crypto.createHash('sha256').update(fs.readFileSync(log)).digest('hex'));
});

test('a complete synthetic committed tree verifies through the real shell CLI with zero native commands', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'native-positive' });
  try {
    const result = fixture.verify();
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
    assert.match(result.stdout, /2\/2 plan15 diagnostics; 2 launches; 32000 ms charged/);
    assert.match(result.stdout, /synthetic-native-fixture/);
    assert.deepEqual(fixture.readEvidence().attempts.map((attempt) => attempt.observed_outcome), ['passed', 'passed']);
    assert.deepEqual(fixture.stubCalls(), [], 'verification must not run setup, browser or database commands');
    assert.equal(fixture.git(['status', '--porcelain']), '', 'verification leaves the committed candidate clean');
  } finally { fixture.cleanup(); }
});

test('the synthetic fixture never reads active phase records, refs or the checkout under test', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'isolation' });
  try {
    assert.notEqual(fs.realpathSync(fixture.root), fs.realpathSync(root));
    assert.equal(fixture.git(['for-each-ref', '--format=%(refname)']).split('\n').filter((ref) => ref.startsWith('refs/gsd/')).length, 0);
    assert.equal(fixture.git(['log', '--format=%ae']).split('\n').every((email) => email.endsWith('@example.invalid')), true);
    const historical = JSON.stringify(fixture.readFreeze().historical);
    assert.equal(historical.includes('de53d1c80f4a67b73a5e5078959c2c88ad75abe8'), false);
    assert.equal(fixture.readFreeze().source.repository, 'synthetic/native-fixture');
    assert.equal(fixture.readFreeze().provenance.synthetic_native_fixture, SYNTHETIC_LABEL);
    assert.equal(fixture.readEvidence().provenance.accepted_as_native_proof, false);
  } finally { fixture.cleanup(); }
});

test('revision CLI rejects null, empty, and fake evidence before trusting caller status', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'forged-inventory' });
  try {
    const cases = [
      ['null', 'null\n'],
      ['empty', '{}\n'],
      ['fake', `${JSON.stringify({ schema_version: 'sigra.phase253.registration-replan-evidence/v1', status: 'diagnosis_incomplete', attempts: [], limits: { browser_launches: 2, charged_duration_ms: 121680 } })}\n`]
    ];
    for (const [label, contents] of cases) {
      const evidence = path.join(fixture.base, `forged-${label}.json`);
      fs.writeFileSync(evidence, contents);
      const result = fixture.run(['--verify-diagnostic', evidence, '--revision']);
      assert.equal(result.status, 3, `${label}: ${result.stdout}\n${result.stderr}`);
    }
    assert.deepEqual(fixture.stubCalls(), []);
  } finally { fixture.cleanup(); }
});

test('revision CLI rejects slot usage counters that do not match native attempts', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'slot-count-drift' });
  try {
    fixture.rewriteEvidence((evidence) => { evidence.limits.used_slots = []; });
    const result = fixture.verify();
    assert.equal(result.status, 3, `${result.stdout}\n${result.stderr}`);
    assert.match(result.stderr, /slot/i);
  } finally { fixture.cleanup(); }
});

test('revision CLI rejects forged, mismatched, duplicated, and over-budget saved receipts', () => {
  const findSelectedSpec = (report) => {
    const visit = (suite) => {
      for (const spec of suite.specs ?? []) {
        if (spec.title === SELECTED_TITLE) return spec;
      }
      for (const child of suite.suites ?? []) {
        const found = visit(child);
        if (found) return found;
      }
      return null;
    };
    return report.suites.map(visit).find(Boolean);
  };
  const cases = [
    ['singleton wrong project', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts = [evidence.attempts[0]]; evidence.attempts[0].project = 'admin-eval-dark'; }), /attempt identity differs from its frozen slot/],
    ['duplicate spent slot', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts.push(structuredClone(evidence.attempts[0])); }), /was reused/],
    ['source commit drift', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.source.checkout_head = 'different-source'; }), /evidence source identity differs/],
    ['source blob drift', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.source.blobs['scripts/ci/ci-registration-recovery.mjs'] = 'different-blob'; }), /evidence source identity differs/],
    ['over-counted launches', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.limits.browser_launches += 1; }), /browser launch count differs/],
    ['over-time charge', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts[0].charged_duration_ms = 120001; }), /exceeded its frozen 120,000 ms command/],
    ['missing database drop', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts[0].database.drop_exit_code = null; }), /database setup or drop did not succeed/],
    ['missing browser report', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts[0].files.playwright_report = null; }), /native Playwright report is missing/],
    ['changed sanitized log digest', (fixture) => fixture.appendRaw('R-DIAG-DESKTOP', 'setup_log', 'changed after receipt\n'), /native setup_log digest mismatch/],
    ['byte-variant selected title', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { findSelectedSpec(report).title += '\u200b'; }), /exactly one byte-exact selected/],
    ['native expectedStatus mismatch', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { findSelectedSpec(report).tests[0].expectedStatus = 'skipped'; }), /expectedStatus and result status disagree/],
    ['native result status mismatch', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { findSelectedSpec(report).tests[0].results[0].status = 'failed'; }), /expectedStatus and result status disagree/],
    ['empty native report', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { report.suites = []; }), /contains no results/],
    ['monotonic end before start', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts[0].ended_monotonic_ns = '1'; }), /monotonic duration is absent or inconsistent/],
    ['committed head not in history', (fixture) => {
      fixture.rewriteFreeze((freeze) => { freeze.source.checkout_head = 'b'.repeat(40); });
      fixture.rewriteEvidence((evidence) => { evidence.source.checkout_head = 'b'.repeat(40); });
    }, /not in the current repository history|frozen source commit/],
    ['internal freeze digest forged', (fixture) => fixture.rewriteFreeze((freeze) => { freeze.freeze_sha256 = '0'.repeat(64); }, { internalDigest: false }), /does not match the frozen revision/],
    ['file freeze digest drift', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.freeze_sha256 = '1'.repeat(64); }), /does not match the frozen revision/],
    ['historical bytes changed', (fixture) => fs.appendFileSync(path.join(fixture.root, fixture.history.original_evidence.path), ' '), /frozen historical evidence bytes changed/],
    ['spent slot reused', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts[0].slot_id = 'D19-DIAG-01'; evidence.limits.used_slots[0] = 'D19-DIAG-01'; }), /does not identify a frozen slot/],
    ['frozen title byte variant', (fixture) => {
      const variant = `${SELECTED_TITLE}\u200b`;
      fixture.rewriteFreeze((freeze) => { for (const slot of freeze.ledger.slots) { slot.title = variant; slot.argv[1] = `--grep=${variant}`; } });
      fixture.rewriteEvidence((evidence) => { for (const attempt of evidence.attempts) attempt.argv[1] = `--grep=${variant}`; });
      fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { report.suites[0].suites[0].specs[0].title = variant; });
      fixture.rewriteReport('R-DIAG-MOBILE', (report) => { report.suites[0].suites[0].specs[0].title = variant; });
    }, /frozen selected title is not the reviewed byte-exact title/],
    ['wrong project bytes', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { report.suites[0].suites[0].specs[0].tests[0].projectName = 'admin-eval\u200b'; }), /exactly one byte-exact selected/],
    ['null native inventory', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { report.config.projects = null; }), /project inventory is incomplete/],
    ['empty native inventory', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { report.config.projects = []; }), /project inventory is incomplete/],
    ['single native inventory', (fixture) => fixture.rewriteReport('R-DIAG-DESKTOP', (report) => { report.config.projects = [{ name: 'admin-eval' }]; }), /project inventory is incomplete/],
    ['preparation counter drift', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.limits.preparation_charge_ms += 1; evidence.limits.charged_duration_ms += 1; }), /preparation charge does not match its command receipts/],
    ['preparation receipt reset', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.preparation_receipts = []; }), /preparation charge does not match its command receipts/],
    ['total charge laundered', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.limits.charged_duration_ms -= 1000; }), /cumulative charged time does not match/],
    ['historical charge reset', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.limits.historical_charge_ms = 0; evidence.limits.charged_duration_ms -= 3000; }), /historical uncertainty or spent charge was not preserved/],
    ['launch count reset', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.limits.browser_launches = 0; }), /browser launch count differs/],
    ['cli exit disagreement', (fixture) => fixture.rewriteEvidence((evidence) => { evidence.attempts[0].browser.exit_code = 1; }), /disagrees with the Playwright process exit/]
  ];

  for (const [label, mutate, reason] of cases) {
    const fixture = createRegistrationNativeTreeFixture({ label: label.replaceAll(' ', '-') });
    try {
      assert.equal(fixture.verify().status, 0, `${label}: the unmutated fixture is the positive control`);
      mutate(fixture);
      const result = fixture.verify();
      assert.equal(result.status, 3, `${label}: ${result.stdout}\n${result.stderr}`);
      assert.match(result.stderr, reason, `${label} must be rejected for its own predicate`);
      assert.doesNotMatch(result.stderr, /ENOENT|preserved config/, `${label} must not be rejected by an unrelated setup fault`);
      assert.deepEqual(fixture.stubCalls(), [], label);
    } finally { fixture.cleanup(); }
  }
});

test('the real shell refuses a run in a clean candidate before setup or browser work, and a stale frozen blob is rejected', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'stale-source' });
  try {
    const output = path.join(fixture.base, 'run-output.json');
    const refused = fixture.run(['--run-revision', fixture.freezePath, '--slot', 'R-DIAG-DESKTOP', '--output', output]);
    assert.equal(refused.status, 3, `${refused.stdout}\n${refused.stderr}`);
    assert.match(refused.stderr, /preserved config status/);
    assert.equal(fs.existsSync(output), false);

    const file = 'scripts/ci/ci-registration-recovery.mjs';
    fixture.rewriteFreeze((freeze) => { freeze.source.blobs[file] = 'a'.repeat(40); });
    fixture.rewriteEvidence((evidence) => { evidence.source.blobs[file] = 'a'.repeat(40); });
    const stale = fixture.verify();
    assert.equal(stale.status, 3, `${stale.stdout}\n${stale.stderr}`);
    assert.match(stale.stderr, /frozen Git source blob mismatch/);
    assert.deepEqual(fixture.stubCalls(), []);
  } finally { fixture.cleanup(); }
});

test('the dirty config rule is exact when a checkout carries it and absent for a clean candidate', () => {
  assert.equal(typeof recovery.assertDirtyConfigPreserved, 'function');
  const fixture = createRegistrationNativeTreeFixture({ label: 'config-integrity' });
  try {
    assert.doesNotThrow(() => recovery.assertDirtyConfigPreserved(fixture.root), 'a clean candidate has no dirty-config requirement');

    const configPath = path.join(fixture.root, '.planning/config.json');
    fs.writeFileSync(configPath, '{"synthetic":"committed"}\n');
    fixture.commitAll('synthetic committed config');
    const dirtyBytes = '{"synthetic":"operator edit"}\n';
    fs.writeFileSync(configPath, dirtyBytes);
    const blob = fixture.git(['hash-object', '-w', configPath]);
    const ref = 'refs/synthetic-fixture/preserved-config';
    fixture.git(['update-ref', ref, blob]);
    const identity = {
      path: '.planning/config.json', status: ' M', porcelain: ' M .planning/config.json', ref, blob,
      sha256: crypto.createHash('sha256').update(dirtyBytes).digest('hex')
    };

    assert.throws(() => recovery.assertDirtyConfigPreserved(fixture.root), /authorized SHA-256 and Git blob/, 'a dirty config must match the real authorized identity');
    assert.doesNotThrow(() => recovery.assertDirtyConfigPreserved(fixture.root, identity));
    fs.appendFileSync(configPath, '\n');
    assert.throws(() => recovery.assertDirtyConfigPreserved(fixture.root, identity), /authorized SHA-256 and Git blob/);
  } finally { fixture.cleanup(); }
});

test('synthetic evidence is labeled and rejected by the accepted-only saved-native audit mode', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'accepted-only' });
  try {
    const snapshot = () => crypto.createHash('sha256').update(JSON.stringify([
      fs.readFileSync(fixture.evidencePath, 'utf8'), fs.readFileSync(fixture.freezePath, 'utf8'),
      fs.readdirSync(fixture.rawDir, { recursive: true }).sort()
    ])).digest('hex');
    const before = snapshot();

    const labeled = fixture.verifySavedNative();
    assert.equal(labeled.status, 3, `${labeled.stdout}\n${labeled.stderr}`);
    assert.match(labeled.stderr, /synthetic native fixture/i);
    assert.equal(snapshot(), before, 'the audit mode is read-only');

    // Stripping the marker does not make fixture history acceptable: its temporary Git identity is still synthetic.
    fixture.rewriteFreeze((freeze) => { delete freeze.provenance; });
    fixture.rewriteEvidence((evidence) => { delete evidence.provenance; });
    const ordinary = fixture.verify();
    assert.equal(ordinary.status, 0, `${ordinary.stdout}\n${ordinary.stderr}`);
    const stripped = fixture.verifySavedNative();
    assert.equal(stripped.status, 3, `${stripped.stdout}\n${stripped.stderr}`);
    assert.match(stripped.stderr, /synthetic/i);
    assert.deepEqual(fixture.stubCalls(), []);
  } finally { fixture.cleanup(); }
});

test('the saved-native audit mode is declared but never invoked by ordinary CI, and no ordinary contract reads active phase records', () => {
  const declared = fs.readFileSync(path.join(root, 'scripts/ci/ci-registration-recovery.mjs'), 'utf8');
  assert.match(declared, /--verify-saved-native/);
  const workflows = path.join(root, '.github/workflows');
  if (fs.existsSync(workflows)) {
    for (const name of fs.readdirSync(workflows)) {
      assert.equal(fs.readFileSync(path.join(workflows, name), 'utf8').includes('--verify-saved-native'), false, `${name} must not invoke the saved-history audit`);
    }
  }
  const activePhaseRecords = new RegExp(['\\.planning', 'phases', '253-'].join('/'));
  for (const file of ['scripts/ci/ci-registration-recovery.test.mjs', 'scripts/ci/ci-registration-repro.test.sh']) {
    assert.doesNotMatch(fs.readFileSync(path.join(root, file), 'utf8'), activePhaseRecords, `${file} must not read active phase records`);
  }
});

function nativeFixture({ project = 'admin-eval', outcome = 'passed', slotKind = 'diagnostic' } = {}) {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-native-fixture-'));
  const hash = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const write = (name, contents) => {
    const file = path.join(base, name);
    fs.writeFileSync(file, contents);
    return { path: name, sha256: hash(file), bytes: fs.statSync(file).size };
  };
  const freeze = {
    schema_version: 'sigra.phase253.registration-recovery-freeze/v1', status: 'frozen_before_results',
    source: { checkout_head: 'candidate-abc', blobs: { 'scripts/ci/ci-registration-recovery.mjs': 'blob-abc' } },
    selection: { test_title: 'render bundle: board-mg-9/populated', projects: ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'] },
    historical: { original_evidence_sha256: 'historical-evidence-hash', preceding_order: 'unknown' },
    ledger: {
      max_launches: 19, max_charged_duration_ms: 58 * 60 * 1000,
      d19: { max_charged_duration_ms: 20 * 60 * 1000 }, prelaunch_setup: { duration_ms: 0 },
      slots: [{ id: 'D19-DIAG-01', sequence: 1, kind: slotKind, stage: 'D19', project, max_duration_ms: 120_000 }]
    }
  };
  const report = {
    suites: [{ file: 'tests/admin-eval.spec.ts', specs: [{
      title: 'render bundle: board-mg-9/populated', file: 'tests/admin-eval.spec.ts',
      tests: [{ projectName: project, results: [{ status: outcome === 'passed' ? 'expected' : 'failed' }] }]
    }] }]
  };
  const files = {
    setup_log: write('setup.log', 'database setup complete\n'),
    app_log: write('app.log', 'Phoenix server started\n'),
    test_log: write('test.log', 'Playwright completed\n'),
    drop_log: write('drop.log', 'database dropped\n'),
    playwright_report: write('report.json', JSON.stringify(report))
  };
  const attempt = {
    slot_id: 'D19-DIAG-01', sequence: 1, stage: 'D19', project, source_commit: 'candidate-abc',
    started_monotonic_ns: '1000000000', ended_monotonic_ns: '16000000000', execution_duration_ms: 15_000,
    prelaunch_setup_ms: 0, charged_duration_ms: 15_000, server: { http_status: 200 },
    database: { name: 'sigra_253_recovery_admin_eval_fixture', drop_exit_code: 0 },
    browser: { launched: true, exit_code: outcome === 'passed' ? 0 : 1 },
    observed_outcome: outcome, files, toolchain: {
      playwright_version: '1.59.1', ecto_sql_version: '3.13.5', phoenix_live_view_version: '1.1.28'
    }, traces: []
  };
  if (outcome !== 'passed') attempt.files.traces = [write('trace.zip', 'trace bytes')];
  return { base, freeze, attempt, hash };
}

test('native receipt accepts the selected project only with matching report, logs, exit and drop', () => {
  const fixture = nativeFixture();
  try {
    assert.deepEqual(verifyNativeAttempt(fixture.attempt, fixture.freeze, fixture.base), { ok: true, errors: [] });
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('diagnostic ledger accepts one accurately charged, source-bound native attempt', () => {
  const fixture = nativeFixture();
  try {
    const freeze = { ...fixture.freeze, freeze_sha256: 'freeze-bytes-hash' };
    const evidence = {
      schema_version: 'sigra.phase253.registration-recovery-evidence/v1', status: 'running',
      freeze_sha256: 'freeze-bytes-hash', source: structuredClone(freeze.source),
      historical: { original_evidence_sha256: 'historical-evidence-hash', preceding_order: 'unknown' },
      attempts: [fixture.attempt],
      limits: { browser_launches: 1, charged_duration_ms: 15_000, max_launches: 19, max_charged_duration_ms: 58 * 60 * 1000 }
    };
    assert.equal(verifyDiagnosticData(evidence, freeze, fixture.base).ok, true);

    evidence.limits.browser_launches = 0;
    const forgedCounter = verifyDiagnosticData(evidence, freeze, fixture.base);
    assert.equal(forgedCounter.ok, false);
    assert.ok(forgedCounter.errors.some((message) => message.includes('launch counter')));
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('native receipt rejects source drift, a wrong project, and a missing report', () => {
  for (const mutate of [
    (item) => { item.source_commit = 'different-source'; },
    (item) => { item.project = 'admin-eval-dark'; },
    (item) => { item.files.playwright_report = null; }
  ]) {
    const fixture = nativeFixture();
    try {
      mutate(fixture.attempt);
      assert.equal(verifyNativeAttempt(fixture.attempt, fixture.freeze, fixture.base).ok, false);
    } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
  }
});

test('native receipt rejects an empty report, absent database drop and changed log digest', () => {
  for (const mutate of [
    (item, fixture) => {
      const ref = item.files.playwright_report;
      fs.writeFileSync(path.join(fixture.base, ref.path), JSON.stringify({ suites: [] }));
      ref.sha256 = fixture.hash(path.join(fixture.base, ref.path));
    },
    (item) => { item.database.drop_exit_code = null; },
    (item, fixture) => { fs.appendFileSync(path.join(fixture.base, item.files.test_log.path), 'changed\n'); }
  ]) {
    const fixture = nativeFixture();
    try {
      mutate(fixture.attempt, fixture);
      assert.equal(verifyNativeAttempt(fixture.attempt, fixture.freeze, fixture.base).ok, false);
    } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
  }
});

test('native receipt rejects a failed browser without a retained failure trace', () => {
  const fixture = nativeFixture({ outcome: 'failed' });
  try {
    fixture.attempt.files.traces = [];
    const result = verifyNativeAttempt(fixture.attempt, fixture.freeze, fixture.base);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((message) => message.includes('retained native trace')));
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('native receipt rejects uncharged controls and attempts over the slot limit', () => {
  const control = nativeFixture({ slotKind: 'control' });
  try { assert.equal(verifyNativeAttempt(control.attempt, control.freeze, control.base).ok, false); }
  finally { fs.rmSync(control.base, { recursive: true, force: true }); }

  const tooLong = nativeFixture();
  try {
    tooLong.attempt.charged_duration_ms = 120_001;
    assert.equal(verifyNativeAttempt(tooLong.attempt, tooLong.freeze, tooLong.base).ok, false);
  } finally { fs.rmSync(tooLong.base, { recursive: true, force: true }); }
});

const CONTROL_BOARD = 'render bundle: board-mg-9/populated';
const SAFE_MARKER = '[REDACTED seeded demo credentials]';

const FIXTURE_ENV = { PGHOST: '127.0.0.1', PGPORT: '55432', PGUSER: 'postgres', PGPASSWORD: 'synthetic-not-retained' };

function psqlDouble({ stdout = '0\n', status = 0, signal = null, error = undefined, calls = [] } = {}) {
  return (program, args, options) => { calls.push({ program, args, options }); return { status, signal, stdout, stderr: '', error }; };
}

function controlFixture({ setupLog = `migrated\n=== Demo Credentials ===\n${SAFE_MARKER}\n\nseed done\n`, quietDrop = false, absence = {} } = {}) {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-control-fixture-'));
  const hash = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const write = (name, contents) => {
    const file = path.join(base, name);
    fs.writeFileSync(file, contents);
    return { path: name, sha256: hash(file), bytes: fs.statSync(file).size };
  };
  const blobs = { 'scripts/ci/ci-registration-recovery.mjs': 'blob-abc' };
  const slot = {
    id: 'CR-FIXTURE', sequence: 1, stage: 'first', project: 'admin-eval', max_duration_ms: 120_000,
    argv: ['--project=admin-eval'], selected_titles: [CONTROL_BOARD], expected: { [CONTROL_BOARD]: 'pass' }
  };
  const freeze = { source: { checkout_head: 'candidate-abc', blobs }, ledger: { slots: [slot] } };
  const report = { suites: [{ file: 'tests/admin-eval.spec.ts', specs: [{
    title: CONTROL_BOARD, file: 'tests/admin-eval.spec.ts',
    tests: [{ projectName: 'admin-eval', expectedStatus: 'passed', status: 'expected', results: [{ status: 'expected' }] }]
  }] }], errors: [] };
  const files = {
    setup_log: write('setup.log', setupLog),
    app_log: write('app.log', 'Phoenix server started\n'),
    test_log: write('test.log', 'Playwright completed\n'),
    drop_log: write('drop.log', quietDrop ? '' : 'database dropped\n'),
    playwright_report: write('report.json', JSON.stringify(report))
  };
  const databaseName = 'sigra_253_control_fixture_abc';
  const absenceLog = path.join(base, 'database-absence.log');
  const receipt = captureOwnedDatabaseAbsence({ database: databaseName, env: FIXTURE_ENV, cwd: base, log: absenceLog, deadline: Number(process.hrtime.bigint()) / 1e6 + 5000, run: psqlDouble(absence) });
  files.database_absence = { path: 'database-absence.log', sha256: hash(absenceLog), bytes: fs.statSync(absenceLog).size };
  const started = BigInt(receipt.started_monotonic_ns) - 5_000_000_000n;
  const ended = BigInt(receipt.ended_monotonic_ns) + 5_000_000_000n;
  const duration = Math.ceil(Number(ended - started) / 1e6);
  const attempt = {
    slot_id: slot.id, sequence: 1, stage: 'first', project: 'admin-eval', argv: slot.argv,
    source_commit: 'candidate-abc', source_blobs: blobs,
    started_monotonic_ns: started.toString(), ended_monotonic_ns: ended.toString(), execution_duration_ms: duration, charged_duration_ms: duration,
    database: { name: databaseName, setup_exit_code: 0, drop_exit_code: 0, connection: { host: '127.0.0.1', port: '55432', user: 'postgres', maintenance_database: 'postgres' }, absence_receipt: receipt },
    server: { http_status: 200, app_pid: 4242 }, browser: { launched: true, exit_code: 0 },
    build_directory_removed: true, build_path: '/tmp/fixture/mix-build', files
  };
  return { base, freeze, attempt, write, hash, absenceLog };
}

test('control receipt accepts the exact safe seeded-credentials redaction marker', () => {
  const fixture = controlFixture();
  try {
    const result = recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base);
    assert.deepEqual(result, { ok: true, errors: [] });
    assert.equal(validateSanitizedCommandLog(fs.readFileSync(path.join(fixture.base, 'setup.log'), 'utf8')).ok, true);
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('sanitized-log validation rejects plaintext credentials, near-match markers, keys and auth headers', () => {
  const header = '=== Demo Credentials ===';
  const variants = {
    plaintext_row: `${header}\nsynthetic@example.invalid SYNTHETIC-PASSWORD\n`,
    marker_after_plaintext: `${header}\nsynthetic@example.invalid SYNTHETIC-PASSWORD\n${SAFE_MARKER}\n`,
    extra_row: `${header}\n${SAFE_MARKER}\nsynthetic@example.invalid SYNTHETIC-PASSWORD\n`,
    altered_case: `${header}\n[redacted seeded demo credentials]\n\n`,
    altered_space: `${header}\n[REDACTED  seeded demo credentials]\n\n`,
    trailing_space: `${header}\n${SAFE_MARKER} \n\n`,
    crlf: `${header}\n${SAFE_MARKER}\r\n\n`,
    marker_missing: `${header}\n`,
    orphan_marker: `${SAFE_MARKER}\n`,
    signing_key: 'secret_key_base: "synthetic-signing-key"\n',
    set_cookie: 'Set-Cookie: _app=synthetic\n',
    cookie_header: 'Cookie: _app=synthetic\n',
    authorization: 'authorization: Bearer synthetic\n'
  };
  for (const [name, text] of Object.entries(variants)) {
    assert.equal(validateSanitizedCommandLog(text).ok, false, name);
  }
  assert.equal(validateSanitizedCommandLog(`${header}\n${SAFE_MARKER}\n\nafter\n`).ok, true);
  assert.equal(validateSanitizedCommandLog(`${header}\n${SAFE_MARKER}`).ok, true);
  assert.equal(validateSanitizedCommandLog('secret_key_base: "[REDACTED]"\n').ok, true);
});

test('control receipt rejects a hash-bound log carrying an injected credential row', () => {
  const fixture = controlFixture({ setupLog: `=== Demo Credentials ===\nsynthetic@example.invalid SYNTHETIC-PASSWORD\n\n` });
  try {
    const result = recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((message) => /setup_log contains an unsanitized credential block/.test(message)));
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('absence capture runs one bounded parameterized psql query against the owned database only', () => {
  const calls = [];
  const log = path.join(temporary, 'absence-capture.log');
  const receipt = captureOwnedDatabaseAbsence({ database: 'sigra_253_control_dark_abc_1', env: FIXTURE_ENV, cwd: root, log, deadline: Number(process.hrtime.bigint()) / 1e6 + 3000, run: psqlDouble({ calls }) });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].program, 'psql');
  assert.deepEqual(calls[0].args.slice(0, 5), ['-X', '-v', 'ON_ERROR_STOP=1', '-v', 'target=sigra_253_control_dark_abc_1']);
  assert.ok(calls[0].args.includes('-A') && calls[0].args.includes('-t'));
  assert.equal(calls[0].args[calls[0].args.indexOf('-d') + 1], 'postgres');
  assert.match(calls[0].options.input, /datname = :'target'/);
  assert.ok(calls[0].options.timeout >= 1 && calls[0].options.timeout <= 3000);
  assert.equal(JSON.stringify(receipt).includes('synthetic-not-retained'), false);
  assert.equal(receipt.stdout_count, 0);
  assert.equal(fs.readFileSync(log, 'utf8'), '0\n');
  assert.throws(() => captureOwnedDatabaseAbsence({ database: 'sigra_test', env: FIXTURE_ENV, cwd: root, log, deadline: Date.now() + 1000, run: psqlDouble() }), /synthetic control namespace/);
  assert.throws(() => captureOwnedDatabaseAbsence({ database: 'sigra_253_control_x; DROP', env: FIXTURE_ENV, cwd: root, log, deadline: Date.now() + 1000, run: psqlDouble() }), /synthetic control namespace/);
});

test('a quiet zero-byte drop log is accepted only with the independent zero-row absence receipt', () => {
  const fixture = controlFixture({ quietDrop: true });
  try {
    assert.equal(fixture.attempt.files.drop_log.bytes, 0);
    assert.deepEqual(recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base), { ok: true, errors: [] });
    delete fixture.attempt.database.absence_receipt;
    const result = recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((message) => /drop log is empty/.test(message)));
    assert.ok(result.errors.some((message) => /absence receipt is missing/.test(message)));
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('database absence verification rejects failed, forged, wrong-name, present-row and null receipts', () => {
  const rejections = {
    null_receipt: (item) => { item.database.absence_receipt = null; },
    wrong_database: (item) => { item.database.absence_receipt.database = 'sigra_253_control_other'; },
    wrong_target_argv: (item) => { item.database.absence_receipt.argv[4] = 'target=sigra_253_control_other'; },
    altered_query: (item) => { item.database.absence_receipt.query = "SELECT 0;\n"; },
    nonzero_exit: (item) => { item.database.absence_receipt.exit_code = 2; },
    timed_out: (item) => { item.database.absence_receipt.timed_out = true; },
    signal: (item) => { item.database.absence_receipt.signal = 'SIGKILL'; },
    count_forged: (item) => { item.database.absence_receipt.stdout_count = 1; },
    wrong_connection: (item) => { item.database.absence_receipt.connection.port = '5432'; },
    password_retained: (item) => { item.database.absence_receipt.connection.password = 'x'; },
    missing_log_reference: (item) => { delete item.files.database_absence; },
    altered_digest: (item) => { item.files.database_absence.sha256 = 'f'.repeat(64); },
    outside_window: (item) => { item.database.absence_receipt.started_monotonic_ns = '1'; }
  };
  for (const [name, mutate] of Object.entries(rejections)) {
    const fixture = controlFixture({ quietDrop: true });
    try {
      mutate(fixture.attempt);
      assert.equal(recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base).ok, false, name);
    } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
  }
  for (const absence of [{ stdout: '1\n' }, { stdout: '' }, { stdout: '0\nextra\n' }, { status: 2, stdout: '' }, { error: Object.assign(new Error('timed out'), { code: 'ETIMEDOUT' }), status: null, signal: 'SIGKILL', stdout: '' }]) {
    const fixture = controlFixture({ quietDrop: true, absence });
    try {
      assert.equal(recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base).ok, false, JSON.stringify(absence));
    } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
  }
});

test('an empty drop log with a wrong digest or failed drop exit is not proven by absence alone', () => {
  const fixture = controlFixture({ quietDrop: true });
  try {
    fixture.attempt.database.drop_exit_code = 1;
    assert.equal(recovery.verifyNativeControlAttempt(fixture.attempt, fixture.freeze, fixture.base).ok, false);
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('ordinary registration runner contracts opened no server or socket', () => {
  assert.deepEqual(networkAttempts, []);
});

test.after(() => {
  net.Socket.prototype.connect = originalConnect;
  net.Server.prototype.listen = originalListen;
  fs.rmSync(temporary, { recursive: true, force: true });
});
