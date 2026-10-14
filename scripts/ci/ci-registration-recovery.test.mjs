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

// Waits on the condition (the atomically renamed tree.json), not on a sleep. fs.watch alone is not
// enough on macOS: the FSEvents stream starts asynchronously, so a rename that lands before it is
// running is never reported and the wait hangs (a source of the 253-39 load flake). A short
// existence poll backs the watcher up; whichever sees the file first settles the wait once.
function whenTreeReady(readyDir) {
  const file = path.join(readyDir, 'tree.json');
  return new Promise((resolve) => {
    let watcher = null;
    let poller = null;
    const check = () => {
      if (!poller || !fs.existsSync(file)) return;
      clearInterval(poller); poller = null;
      watcher?.close();
      resolve(JSON.parse(fs.readFileSync(file, 'utf8')));
    };
    poller = setInterval(check, 20);
    try { watcher = fs.watch(readyDir, check); } catch { /* the poll alone still settles the wait */ }
    check();
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

// ---- Plan 39: four-slot load recovery contracts (synthetic subprocess boundaries; no native work) ----
const LOAD_CHARGES = [3768, 3743, 26373, 46803, 40993, 121252, 112, 33409];
const LOAD_SPENT = ['D19-DIAG-01', 'R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE', 'R-DIAG-CONTROL-DARK', 'CR-DARK-FIRST'];
const loadLedgerInput = () => ({
  charges: [...LOAD_CHARGES], physicalPlaywrightLaunches: 5, spentReservations: [...LOAD_SPENT],
  retryUsed: 1, retryAvailable: 0, preparationMaximumMs: 116232, preparationUsedMs: 3743
});

test('load recovery ledger starts at 276453 ms, five launches and six spent identities with exactly four unused mappings', () => {
  const ledger = recovery.buildLoadRecoveryLedger(loadLedgerInput());
  assert.equal(ledger.prior_charge_ms, 276453);
  assert.equal(ledger.prior_playwright_cli_launches, 5);
  assert.deepEqual(ledger.spent_reservations, LOAD_SPENT);
  assert.deepEqual(ledger.slots.map(({ id, maps_from, projects }) => [id, maps_from, projects]), [
    ['CR-DESKTOP-MOBILE-FIRST', 'R-CONTROL-FIRST-MOBILE', ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']],
    ['CR-DESKTOP-SECOND', 'R-CONTROL-SECOND-DESKTOP', ['admin-eval']],
    ['CR-MOBILE-SECOND', 'R-CONTROL-SECOND-MOBILE', ['admin-eval-mobile']],
    ['CR-DARK-SECOND', 'R-CONTROL-SECOND-DARK', ['admin-eval-dark']]
  ]);
  assert.ok(ledger.slots.every((slot) => slot.max_duration_ms === 120000 && slot.work_ms === 105000 && slot.cleanup_ms === 15000));
  assert.deepEqual(ledger.slots.map((slot) => slot.rows), [16, 2, 2, 2]);
  assert.equal(ledger.required_rows, 22);
  assert.equal(ledger.d19_max_ms, 868942);
  assert.equal(ledger.total_max_ms, 3208942);
  assert.equal(ledger.physical_cli_launch_max, 18);
});

test('load recovery ledger rejects altered charges, reopened retries, reset counters and reopened spent slots', () => {
  for (const mutate of [
    (input) => { input.charges[7] = 33408; },
    (input) => { input.charges.pop(); },
    (input) => { input.retryAvailable = 1; },
    (input) => { input.retryUsed = 0; },
    (input) => { input.spentReservations.pop(); },
    (input) => { input.spentReservations.push('CR-DESKTOP-MOBILE-FIRST'); },
    (input) => { input.physicalPlaywrightLaunches = 4; },
    (input) => { input.preparationUsedMs = 0; }
  ]) {
    const input = loadLedgerInput(); mutate(input);
    assert.throws(() => recovery.buildLoadRecoveryLedger(input), /historical|retry|reservation|launch|preparation/i);
  }
});

test('the 22 required project and title rows are the exact 16 + 2 + 2 + 2 packing, with no CLI grep', () => {
  const slots = recovery.loadRecoverySlotDefinitions();
  const pairs = slots.flatMap((slot) => recovery.loadRequiredPairs(slot));
  assert.equal(pairs.length, 22);
  assert.equal(new Set(pairs.map((item) => `${item.project}|${item.title}`)).size, 22);
  const first = recovery.loadRequiredPairs(slots[0]);
  for (const project of ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']) {
    assert.equal(first.filter((item) => item.project === project && item.title !== 'render bundle: board-mg-9/populated').length, 5);
  }
  assert.equal(first.filter((item) => item.title === 'render bundle: board-mg-9/populated').map((item) => item.project).join(), 'admin-eval-dark');
  for (const slot of slots) {
    assert.ok(slot.argv.every((arg) => !/^(-g|--grep)/.test(arg)), 'CLI grep would override the per-project selection');
    assert.equal(slot.argv.filter((arg) => arg.startsWith('--project=')).length, slot.projects.length);
    assert.ok(slot.argv.includes('--workers=1') && slot.argv.includes('--retries=0') && slot.argv.includes('--trace=retain-on-failure'));
  }
  assert.deepEqual(slots.map((slot) => slot.expected_cli_exit), [1, 0, 0, 0]);
  assert.equal(new Set(slots.flatMap((slot) => Object.values(slot.collision_account_sha256))).size, 3);
});

test('project collision accounts match the shared browser helper exactly', async () => {
  const helper = await import(path.join(root, 'test/example/priv/playwright/helpers/registrationControls.mjs'));
  for (const project of ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']) {
    for (const purpose of ['held-positive', 'broken-readiness-positive', 'forced-trace-positive', 'collision']) {
      assert.equal(recovery.loadControlAccount(project, purpose), helper.registrationControlAccount(project, purpose));
    }
  }
});

test('the scoped config inherits every production setting and only narrows projects with a per-project grep', () => {
  const config = fs.readFileSync(path.join(root, 'test/example/priv/playwright/playwright.registration-recovery.config.ts'), 'utf8');
  assert.match(config, /import productionConfig from '\.\/playwright\.config';/);
  assert.match(config, /\.\.\.productionConfig,\s*\n\s*projects: selected/);
  assert.match(config, /\{ \.\.\.project, grep: exactTitles/);
  for (const forbidden of [/\bworkers\s*:/, /\bretries\s*:/, /\btimeout\s*:/, /\bfullyParallel\s*:/, /\buse\s*:/, /\breporter\s*:/, /\bdevices\b/, /\bcolorScheme\b/, /test\.fail/]) {
    assert.doesNotMatch(config, forbidden);
  }
  assert.match(config, /requires SIGRA_REGISTRATION_CONTROL_STAGE=first\|second/);
});

// ---- synthetic four-slot runner harness ----
function loadHarness() {
  const base = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-load-')));
  const checkout = path.join(base, 'checkout');
  const pwPackage = path.join(checkout, 'test/example/priv/playwright/node_modules/@playwright/test/package.json');
  fs.mkdirSync(path.dirname(pwPackage), { recursive: true });
  fs.writeFileSync(pwPackage, JSON.stringify({ version: '1.59.1' }));
  const ledgerBase = recovery.buildLoadRecoveryLedger(loadLedgerInput());
  const freeze = {
    schema_version: 'sigra.phase253.registration-load-recovery-freeze/v1', status: 'frozen_before_results', plan: '253-39',
    source: { repository: 'synthetic', checkout_head: 'a'.repeat(40), blobs: { 'scripts/x': 'b'.repeat(40) } },
    tools: { playwright: '1.59.1', ecto_sql: '3.13.5', phoenix_live_view: '1.1.28' },
    selection: { spec: 'tests/admin-eval.spec.ts' },
    ledger: {
      prior_charge_ms: 276453, prior_playwright_cli_launches: 5, spent_reservations: [...LOAD_SPENT], preparation_remaining_ms: 112489,
      retry_used: 1, retry_available: 0, slots: ledgerBase.slots, d19: { cap_ms: 1200000, max_with_remaining_preparation: 868942 },
      shared_cap_ms: 3480000, physical_cli_launch_max: 18, cleanup_reserve_ms: 15000
    }
  };
  freeze.freeze_sha256 = sha(JSON.stringify(freeze));
  const freezeFile = path.join(base, 'freeze.json'); const evidenceFile = path.join(base, 'evidence.json');
  fs.writeFileSync(freezeFile, `${JSON.stringify(freeze, null, 2)}\n`);
  const evidence = {
    schema_version: 'sigra.phase253.registration-load-recovery-evidence/v1', status: 'ready', freeze_path: 'freeze.json',
    freeze_sha256: sha(fs.readFileSync(freezeFile)), source: structuredClone(freeze.source), attempts: [], reservation: null, preserved_revisions: [],
    limits: {
      prior_charge_ms: 276453, preparation_charge_ms: 0, preparation_remaining_ms: 112489, charged_duration_ms: 276453,
      physical_playwright_cli_launches: 5, used_slots: [...LOAD_SPENT], max_d19_ms: 868942, max_total_ms: 3480000,
      max_physical_playwright_cli_launches: 18, retry_used: 1, retry_available: 0
    }
  };
  fs.writeFileSync(evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
  fs.mkdirSync(`${evidenceFile}.raw`);
  const calls = [];
  const zip = path.join(base, 'trace.zip'); fs.writeFileSync(zip, 'z'.repeat(64));
  const fakePsql = (counts) => { let index = 0; return (program, args) => { calls.push(['psql', args.find((item) => item.startsWith('target=')) ? 'account-or-db' : 'x']); return { status: 0, stdout: `${counts[Math.min(index++, counts.length - 1)]}\n` }; }; };
  const reportFor = (slot, runId) => ({
    config: {}, errors: [],
    suites: [{
      title: 'admin-eval.spec.ts', file: 'admin-eval.spec.ts', specs: [], suites: [{
        title: 'x', file: 'admin-eval.spec.ts',
        specs: recovery.loadRequiredPairs(slot).map((pair, index) => {
          const expected = slot.project_selections.find((item) => item.project === pair.project).expected[pair.title];
          const annotations = [];
          if (pair.title !== 'render bundle: board-mg-9/populated') annotations.push({ type: 'sigra-registration-control-context', description: `${runId}:${crypto.randomUUID()}` });
          if (pair.title === 'registration detects a deliberate same-account collision') annotations.push({ type: 'sigra-registration-control-result', description: JSON.stringify({ collision_email_sha256: slot.collision_account_sha256[pair.project], first_registration_succeeded: true, duplicate_response_confirmed: true }) });
          if (pair.title === 'registration starts from a fresh database and context') annotations.push({ type: 'sigra-registration-control-result', description: JSON.stringify({ prior_collision_account_email_sha256: slot.collision_account_sha256[pair.project], fresh_database_account_created: true }) });
          const failed = expected === 'expected_failure';
          const marker = { 'registration stops when LiveView readiness is never released': 'phx-connected', 'registration fails when the readiness wait is deliberately broken': 'data-sigra-never-connected', 'registration retains the first forced assertion failure trace': 'toHaveURL' }[pair.title];
          return {
            title: pair.title, file: 'admin-eval.spec.ts', ok: !failed,
            tests: [{ projectName: pair.project, expectedStatus: 'passed', status: failed ? 'unexpected' : 'expected', annotations,
              results: [{ status: failed ? 'failed' : 'passed', duration: 10, workerIndex: index, error: failed ? { message: `expect ${marker} failed` } : undefined, attachments: failed ? [{ name: 'trace', path: zip }] : [], annotations: [] }] }]
          };
        })
      }]
    }]
  });
  const makeDeps = ({ cliExit = null, postLine = true, accountCounts = [0, 1], absenceCounts = [0], validate = () => {} } = {}) => {
  const absenceRun = fakePsql(absenceCounts); const accountRun = fakePsql(accountCounts);
  return {
    validate, enforcePaths: false, enforceNode: false, skipPreservation: true,
    portAvailable: async () => true, waitReady: async () => 200, stopApp: async () => {},
    holdAwake: () => { calls.push(['hold-awake']); return { held: true, platform: 'darwin', argv: ['/usr/bin/caffeinate', '-i', '-s', '-m', '-w', String(process.pid)], release: () => calls.push(['release-awake']) }; },
    spawnApp: (program, args, options) => { calls.push(['app', program, ...args]); if (postLine) fs.writeSync(options.stdio[1], 'POST /users/log_in\n'); return { pid: 4242, exitCode: null, signalCode: null }; },
    runTree: async (program, args, cwd, env, log, timeoutMs) => {
      calls.push(['tree', program, ...args]);
      fs.writeFileSync(log, `${path.basename(program)} ${args[0]} ok\n`);
      if (program.endsWith('/playwright')) {
        const slot = freeze.ledger.slots.find((item) => env.SIGRA_CONTROL_RUN_ID.startsWith(item.id.toLowerCase()));
        assert.equal(env.SIGRA_REGISTRATION_CONTROL_STAGE, slot.control_stage);
        assert.equal(args.filter((arg) => /^(-g|--grep)/.test(arg)).length, 0);
        fs.writeFileSync(env.SIGRA_PLAYWRIGHT_JSON, JSON.stringify(reportFor(slot, env.SIGRA_CONTROL_RUN_ID)));
        return { pid: 777, exit_code: cliExit ?? slot.expected_cli_exit, signal: null, error: null, timed_out: false, duration_ms: 5, group_signals: [], descendants_reaped: true };
      }
      return { pid: 1, exit_code: 0, signal: null, error: null, timed_out: false, duration_ms: 1, group_signals: [], descendants_reaped: true };
    },
    captureAbsence: (options) => recovery.captureOwnedDatabaseAbsence({ ...options, run: absenceRun }),
    captureAccount: (options) => recovery.captureOwnedAccountCount({ ...options, run: accountRun }),
    sanitizeTrace: (source, destination) => { fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL); return { entries: 3, navigation: true, submission: true }; }
  }; };
  return { base, checkout, freeze, freezeFile, evidenceFile, calls, makeDeps, read: () => JSON.parse(fs.readFileSync(evidenceFile, 'utf8')), clean: () => fs.rmSync(base, { recursive: true, force: true }) };
}
const sha = (data) => crypto.createHash('sha256').update(data).digest('hex');

test('one unused slot runs exactly one Playwright CLI process and records 16 exact first rows', async () => {
  const h = loadHarness();
  try {
    const result = await recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps());
    assert.equal(result.rows, 16);
    assert.equal(h.calls.filter((call) => call[0] === 'tree' && call[1].endsWith('/playwright')).length, 1);
    assert.equal(h.calls.filter((call) => call[0] === 'tree' && call[1] === 'mix' && call[2] === 'ecto.setup').length, 1);
    const evidence = h.read();
    assert.equal(evidence.status, 'first_complete');
    assert.equal(evidence.limits.physical_playwright_cli_launches, 6);
    assert.deepEqual(evidence.limits.used_slots, [...LOAD_SPENT, 'CR-DESKTOP-MOBILE-FIRST']);
    assert.equal(evidence.limits.charged_duration_ms, 276453 + evidence.attempts[0].charged_duration_ms);
    assert.equal(evidence.attempts[0].lifecycle.rows, 16);
    assert.equal(evidence.attempts[0].lifecycle.playwright_cli_processes, 1);
    assert.equal(evidence.attempts[0].files.traces.length, 9);
    const verdict = recovery.verifyLoadRecoveryEvidenceData(evidence, h.freeze, `${h.evidenceFile}.raw`, 'first', sha(fs.readFileSync(h.freezeFile)));
    assert.deepEqual(verdict.errors, []);
    assert.equal(h.calls.filter((call) => call[0] === 'psql').length, 1, 'first slot needs only the database absence proof');
  } finally { h.clean(); }
});

test('all four slots run once in order, each second slot proves its collision account absent then created', async () => {
  const h = loadHarness();
  try {
    for (const slot of recovery.loadRecoverySlotDefinitions()) await recovery.runLoadRecoverySlot(h.freezeFile, slot.id, h.evidenceFile, h.checkout, h.makeDeps());
    const evidence = h.read();
    assert.equal(evidence.status, 'complete');
    assert.equal(evidence.attempts.reduce((sum, item) => sum + item.lifecycle.rows, 0), 22);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 9);
    for (const attempt of evidence.attempts.slice(1)) {
      assert.equal(attempt.prior_collision_absence.count, 0);
      assert.equal(attempt.created_account.count, 1);
      assert.equal(attempt.prior_collision_absence.account_email_sha256, h.freeze.ledger.slots[attempt.sequence - 1].collision_account_sha256[attempt.project]);
    }
    const verdict = recovery.verifyLoadRecoveryEvidenceData(evidence, h.freeze, `${h.evidenceFile}.raw`, 'complete', sha(fs.readFileSync(h.freezeFile)));
    assert.deepEqual(verdict.errors, []);
    await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DARK-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|consumed|already|order/i);
  } finally { h.clean(); }
});

test('the spent CR-DARK-FIRST slot and every spent identity are refused before any setup', async () => {
  const h = loadHarness();
  try {
    for (const id of ['CR-DARK-FIRST', 'R-DIAG-CONTROL-DARK', 'R-CONTROL-FIRST-DESKTOP']) {
      await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, id, h.evidenceFile, h.checkout, h.makeDeps()), /spent|only the four/i);
    }
    assert.deepEqual(h.calls, []);
    assert.equal(h.read().status, 'ready');
  } finally { h.clean(); }
});

test('reopened retry, counter reset, out-of-order slot and source drift reject before setup', async () => {
  for (const [mutate, pattern, slot, validate] of [
    [(e) => { e.limits.retry_available = 1; }, /retry/i, 'CR-DESKTOP-MOBILE-FIRST'],
    [(e) => { e.limits.charged_duration_ms = 0; e.limits.prior_charge_ms = 0; }, /counter reset|reset/i, 'CR-DESKTOP-MOBILE-FIRST'],
    [(e) => { e.limits.used_slots.push('CR-DESKTOP-MOBILE-FIRST'); }, /already consumed/i, 'CR-DESKTOP-MOBILE-FIRST'],
    [() => {}, /frozen order/i, 'CR-MOBILE-SECOND'],
    [() => {}, /source identity/i, 'CR-DESKTOP-MOBILE-FIRST', () => { throw new Error('frozen load recovery source identity mismatch for scripts/x'); }]
  ]) {
    const h = loadHarness();
    try {
      const evidence = h.read(); mutate(evidence);
      fs.writeFileSync(h.evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
      await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, slot, h.evidenceFile, h.checkout, h.makeDeps(validate ? { validate } : {})), pattern);
      assert.deepEqual(h.calls, [], String(pattern));
    } finally { h.clean(); }
  }
});

test('an unexpected native result is charged, halts the ledger and refuses a further command', async () => {
  const h = loadHarness();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps({ cliExit: 0 })), /exit does not match/i);
    const evidence = h.read();
    assert.equal(evidence.status, 'halted');
    assert.ok(evidence.limits.charged_duration_ms > 276453);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 6);
    assert.equal(recovery.verifyLoadRecoveryEvidenceData(evidence, h.freeze, `${h.evidenceFile}.raw`, 'first', sha(fs.readFileSync(h.freezeFile))).ok, false);
    const before = h.calls.length;
    await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|reserved/i);
    assert.equal(h.calls.length, before);
  } finally { h.clean(); }
});

test('a prior collision account that already exists in the new database halts before browser work', async () => {
  const h = loadHarness();
  try {
    await recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps());
    const treeBefore = h.calls.filter((call) => call[0] === 'tree' && call[1].endsWith('/playwright')).length;
    await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-SECOND', h.evidenceFile, h.checkout, h.makeDeps({ accountCounts: [1] })), /not absent/i);
    assert.equal(h.calls.filter((call) => call[0] === 'tree' && call[1].endsWith('/playwright')).length, treeBefore);
    assert.equal(h.read().status, 'halted');
  } finally { h.clean(); }
});

test('native load attempt verification rejects corrupted receipts one predicate at a time', async () => {
  const h = loadHarness();
  try {
    await recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps());
    const raw = `${h.evidenceFile}.raw`;
    const good = h.read().attempts[0];
    assert.equal(recovery.verifyNativeLoadAttempt(structuredClone(good), h.freeze, raw).ok, true);
    for (const [name, mutate, pattern] of [
      ['argv', (a) => { a.argv.push('--grep=x'); }, /argv|grep/i],
      ['cli exit', (a) => { a.playwright_cli.exit_code = 0; }, /exit/i],
      ['two processes', (a) => { a.lifecycle.playwright_cli_processes = 2; }, /one physical/i],
      ['overrun', (a) => { a.charged_duration_ms = 120001; }, /120,000|charge/i],
      ['source', (a) => { a.source_commit = 'c'.repeat(40); }, /source/i],
      ['trace count', (a) => { a.files.traces.pop(); }, /trace count/i],
      ['wrong database namespace', (a) => { a.database.name = 'other_db'; }, /namespace/i],
      ['lifecycle', (a) => { a.lifecycle.worker_indexes = []; }, /lifecycle/i]
    ]) {
      const attempt = structuredClone(good); mutate(attempt);
      const verdict = recovery.verifyNativeLoadAttempt(attempt, h.freeze, raw);
      assert.equal(verdict.ok, false, name);
      assert.match(verdict.errors.join(';'), pattern, name);
    }
    const spent = structuredClone(good); spent.slot_id = 'CR-DARK-FIRST';
    assert.equal(recovery.verifyNativeLoadAttempt(spent, h.freeze, raw).ok, false);
  } finally { h.clean(); }
});

test('load recovery freeze creation and checks refuse a candidate without the preserved native records', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'load' });
  try {
    const out = path.join(fixture.root, 'out-freeze.json');
    assert.throws(() => recovery.createLoadRecoveryFreeze(out, fixture.root));
    assert.equal(fs.existsSync(out), false);
    assert.throws(() => recovery.validateLoadRecoveryFreeze(fixture.root, { schema_version: 'x' }), /malformed|digest/i);
  } finally { fixture.cleanup?.(); }
});

// 253-40 regression: the host slept three times inside one native window (pmset: 744 s, 923 s,
// 753 s) and the single armed deadline timer never fired, so the CLI ran ~29 minutes. These
// synthetic trees model that discontinuity offline by moving the runner's injected clocks the way
// sleep moves them; nothing here waits on a race: each test waits on a published tree.json, then
// on the runner's own result.
function clockJump() {
  let offset = 0;
  return { now: (base) => () => base() + offset, jump: (ms) => { offset += ms; } };
}

test('a wall-clock jump past the deadline (host sleep) kills the whole tree at the next watchdog tick', { timeout: 30000 }, async () => {
  const readyDir = fs.mkdtempSync(path.join(temporary, 'tree-wall-sleep-'));
  const wall = clockJump();
  const pending = recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir)], root, process.env, path.join(readyDir, 'run.log'), 120000, 200,
    { wallNow: wall.now(() => Date.now()) });
  const tree = await whenTreeReady(readyDir);
  wall.jump(15 * 60 * 1000);
  const result = await pending;

  assert.equal(result.timed_out, true, 'the deadline is enforced on the wall clock, not only the armed monotonic timer');
  assert.ok(result.duration_ms < 120000, 'the monotonic clock alone never reached the deadline');
  assert.ok(result.wall_duration_ms >= 120000);
  assert.equal(result.suspended, true, 'a wall/monotonic skew beyond the gap threshold is recorded as host suspension');
  assert.deepEqual(result.group_signals, ['SIGTERM', 'SIGKILL'], 'SIGTERM, then exactly one SIGKILL for the SIGTERM-resistant grandchild');
  assert.equal(result.descendants_reaped, true);
  assert.equal(processGone(tree.child), true);
  assert.equal(processGone(tree.grandchild), true);
  assert.equal(processGone(-result.pid), true);
});

test('both clocks jumping across a sleep are caught as a tick gap and enforce the deadline', { timeout: 30000 }, async () => {
  const readyDir = fs.mkdtempSync(path.join(temporary, 'tree-both-sleep-'));
  const clock = clockJump();
  const pending = recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir)], root, process.env, path.join(readyDir, 'run.log'), 120000, 200, {
    monotonicNow: clock.now(() => Number(process.hrtime.bigint()) / 1e6),
    wallNow: clock.now(() => Date.now())
  });
  const tree = await whenTreeReady(readyDir);
  clock.jump(923 * 1000);
  const result = await pending;

  assert.equal(result.timed_out, true);
  assert.equal(result.suspended, true);
  assert.ok(result.max_tick_gap_ms >= 900000, `tick gap ${result.max_tick_gap_ms} records the sleep`);
  assert.equal(result.group_signals.filter((name) => name === 'SIGKILL').length, 1);
  assert.equal(processGone(tree.grandchild), true);
  assert.equal(processGone(-result.pid), true);
});

test('an uneventful bounded run records no suspension and its wall duration', { timeout: 30000 }, async () => {
  const result = await recovery.runLoggedTree(process.execPath, ['-e', 'setTimeout(() => {}, 50)'], root, process.env, path.join(temporary, 'quiet-tree.log'), 20000, 200);
  assert.equal(result.exit_code, 0);
  assert.equal(result.timed_out, false);
  assert.equal(result.suspended, false);
  assert.ok(Number.isInteger(result.wall_duration_ms));
  assert.deepEqual(result.group_signals, []);
});

test('deadline escalation sends SIGKILL at most once under parallel load', { timeout: 60000 }, async () => {
  const runs = Array.from({ length: 6 }, async (_, index) => {
    const readyDir = fs.mkdtempSync(path.join(temporary, `tree-parallel-${index}-`));
    const controller = new AbortController();
    const pending = recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir)], root, process.env, path.join(readyDir, 'run.log'), 30000, 50, { signal: controller.signal });
    const tree = await whenTreeReady(readyDir);
    controller.abort();
    return { tree, result: await pending };
  });
  for (const { tree, result } of await Promise.all(runs)) {
    assert.deepEqual(result.group_signals, ['SIGTERM', 'SIGKILL']);
    assert.equal(result.descendants_reaped, true);
    assert.equal(processGone(tree.grandchild), true);
    assert.equal(processGone(-result.pid), true);
  }
});

test('a group that dies slowly after SIGKILL still receives exactly one SIGKILL (253-39 flake)', { timeout: 30000 }, async () => {
  // Deterministic model of a loaded host: the owned group stays visible for 400 ms after SIGKILL,
  // so the deadline escalation and the reap poll both reach the kill decision while it is alive.
  const readyDir = fs.mkdtempSync(path.join(temporary, 'tree-slow-death-'));
  let killedAt = null;
  const killProcess = (pid, name) => {
    if (name === 'SIGKILL') killedAt ??= Number(process.hrtime.bigint()) / 1e6;
    if (name === 0 && (killedAt === null || Number(process.hrtime.bigint()) / 1e6 - killedAt < 400)) return true;
    return process.kill(pid, name);
  };
  const controller = new AbortController();
  const pending = recovery.runLoggedTree(process.execPath, ['-e', treeScript(readyDir)], root, process.env, path.join(readyDir, 'run.log'), 30000, 100, { signal: controller.signal, killProcess });
  const tree = await whenTreeReady(readyDir);
  controller.abort();
  const result = await pending;

  assert.deepEqual(result.group_signals, ['SIGTERM', 'SIGKILL']);
  assert.equal(result.descendants_reaped, true);
  assert.equal(processGone(tree.grandchild), true);
  assert.equal(processGone(-result.pid), true);
});

test('the host sleep assertion is caffeinate bound to the runner pid on macOS and absent elsewhere', () => {
  const spawned = [];
  const fakeSpawn = (program, args) => { spawned.push([program, ...args]); return { pid: 9001, on: () => {}, kill: (name) => spawned.push(['kill', name]) }; };
  const held = recovery.holdHostAwake({ platform: 'darwin', spawnProcess: fakeSpawn, pid: 4321, exists: () => true });
  assert.equal(held.held, true);
  assert.deepEqual(spawned[0], ['/usr/bin/caffeinate', '-i', '-s', '-m', '-w', '4321']);
  held.release();
  assert.deepEqual(spawned[1], ['kill', 'SIGTERM']);

  const linux = recovery.holdHostAwake({ platform: 'linux', spawnProcess: () => assert.fail('no assertion needed off macOS') });
  assert.equal(linux.held, false);
  assert.throws(() => recovery.holdHostAwake({ platform: 'darwin', spawnProcess: fakeSpawn, exists: () => false }), /caffeinate/);
  assert.throws(() => recovery.holdHostAwake({ platform: 'darwin', spawnProcess: () => ({}), exists: () => true }), /could not be started/);
});

test('a load slot holds the host awake for the whole window and refuses before any charge when it cannot', async () => {
  const h = loadHarness();
  try {
    await recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps());
    const kinds = h.calls.map((call) => call[0]);
    assert.ok(kinds.indexOf('hold-awake') < kinds.indexOf('tree'), 'held before the first native command');
    assert.equal(kinds.at(-1), 'release-awake', 'released only after the ledger is written');
    assert.equal(h.read().attempts[0].host.sleep_assertion_held, true);
    assert.equal(h.read().attempts[0].host.suspension_detected, false);
  } finally { h.clean(); }

  const refused = loadHarness();
  try {
    const before = refused.read();
    await assert.rejects(() => recovery.runLoadRecoverySlot(refused.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', refused.evidenceFile, refused.checkout,
      { ...refused.makeDeps(), holdAwake: () => { throw new Error('macOS sleep assertion could not be started'); } }), /sleep assertion/);
    assert.deepEqual(refused.read(), before, 'no reservation, used slot or charge when the host cannot be kept awake');
    assert.equal(refused.calls.filter((call) => call[0] === 'tree').length, 0);
  } finally { refused.clean(); }
});

test('a host sleep inside the browser command halts the slot, charges the wall time and still drops the owned database', async () => {
  const h = loadHarness();
  const realNow = Date.now;
  const timeouts = [];
  try {
    const deps = h.makeDeps();
    const inner = deps.runTree;
    deps.runTree = async (program, args, cwd, env, log, timeoutMs, ...rest) => {
      timeouts.push([path.basename(program), args[0], timeoutMs]);
      const result = await inner(program, args, cwd, env, log, timeoutMs, ...rest);
      if (!program.endsWith('/playwright')) return result;
      Date.now = () => realNow() + 1765488;
      return { ...result, timed_out: true, suspended: true, wall_duration_ms: 1765488 };
    };
    await assert.rejects(() => recovery.runLoadRecoverySlot(h.freezeFile, 'CR-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, deps), /host suspension/);
    Date.now = realNow;
    const evidence = h.read();
    assert.match(evidence.stop_reason, /host suspension \(system sleep or a stalled runner event loop\) was detected/, 'the runner itself halts on suspension, not only the verifier');
    const attempt = evidence.attempts[0];
    assert.equal(evidence.status, 'halted');
    assert.equal(attempt.host.suspension_detected, true);
    assert.ok(attempt.wall_duration_ms >= 1765488);
    assert.equal(attempt.charged_duration_ms, Math.max(attempt.execution_duration_ms, attempt.wall_duration_ms), 'the charge never hides the sleep');
    assert.equal(evidence.limits.charged_duration_ms, 276453 + attempt.charged_duration_ms);
    const drop = timeouts.find(([program, verb]) => program === 'mix' && verb === 'ecto.drop');
    assert.ok(drop[2] >= 5000, `the owned drop keeps a bounded floor after an overrun (got ${drop[2]} ms)`);
    assert.equal(attempt.database.drop_exit_code, 0);
    assert.ok(attempt.database.absence_receipt, 'the owned database absence is still proven');
    assert.equal(recovery.verifyNativeLoadAttempt(structuredClone(attempt), h.freeze, `${h.evidenceFile}.raw`).ok, false);
    assert.match(recovery.verifyNativeLoadAttempt(structuredClone(attempt), h.freeze, `${h.evidenceFile}.raw`).errors.join('; '), /host suspension/);
  } finally { Date.now = realNow; h.clean(); }
});

// ---- Plan 48: R2 load-recovery revision (synthetic subprocess boundaries; no native work) ----
const R2_SPENT = [...LOAD_SPENT, 'CR-DESKTOP-MOBILE-FIRST'];
const R2_CHARGES = [...LOAD_CHARGES, 655, 1765488];
const r2LedgerInput = () => ({
  charges: [...R2_CHARGES], physicalPlaywrightLaunches: 6, spentReservations: [...R2_SPENT],
  retryUsed: 1, retryAvailable: 0, preparationUsedMs: 4398
});
const R2_APPROVE = {
  schema_version: 'sigra.phase253.load-recovery-budget-approval/v1', decision: 'approve', retry_granted: 1,
  caps: { new_allowance_ms: 645000, d19_cap_ms: 2687596, d19_launch_max: 11, shared_cap_ms: 5027596, physical_cli_max: 20 }
};
const R2_APPROVE_NO_RETRY = {
  schema_version: 'sigra.phase253.load-recovery-budget-approval/v1', decision: 'approve-without-retry', retry_granted: 0,
  caps: { new_allowance_ms: 525000, d19_cap_ms: 2567596, d19_launch_max: 10, shared_cap_ms: 4907596, physical_cli_max: 19 }
};

test('R2 ledger carries 2042596 ms, six launches and seven spent identities, with the reviewed R2 caps', () => {
  const ledger = recovery.buildLoadRecoveryLedgerR2(r2LedgerInput());
  assert.equal(ledger.prior_charge_ms, 2042596);
  assert.equal(ledger.prior_playwright_cli_launches, 6);
  assert.deepEqual(ledger.spent_reservations, R2_SPENT);
  assert.equal(ledger.preparation_used_ms, 4398);
  assert.equal(ledger.preparation_reserve_ms, 30000);
  assert.equal(ledger.retry_used, 1);
  assert.equal(ledger.retry_available, 0);
  assert.deepEqual(ledger.caps.approve, R2_APPROVE.caps);
  assert.deepEqual(ledger.caps['approve-without-retry'], R2_APPROVE_NO_RETRY.caps);
  assert.equal(ledger.required_rows, 22);
});

test('R2 ledger rejects any other carried input', () => {
  for (const mutate of [
    (input) => { input.charges[9] = 1765487; },
    (input) => { input.charges.pop(); },
    (input) => { input.charges[8] = 654; },
    (input) => { input.retryAvailable = 1; },
    (input) => { input.retryUsed = 0; },
    (input) => { input.spentReservations.pop(); },
    (input) => { input.spentReservations.reverse(); },
    (input) => { input.physicalPlaywrightLaunches = 5; },
    (input) => { input.preparationUsedMs = 3743; }
  ]) {
    const input = r2LedgerInput(); mutate(input);
    assert.throws(() => recovery.buildLoadRecoveryLedgerR2(input), /historical|retry|reservation|launch|preparation|carried/i);
  }
});

test('R2 slots keep the identical 22-row selection under CR2-DESKTOP-MOBILE-FIRST plus the three unused seconds and one retry declaration', () => {
  const v1 = recovery.loadRecoverySlotDefinitions();
  const r2 = recovery.loadRecoverySlotDefinitionsR2();
  assert.deepEqual(r2.map((slot) => slot.id), ['CR2-DESKTOP-MOBILE-FIRST', 'CR-DESKTOP-SECOND', 'CR-MOBILE-SECOND', 'CR-DARK-SECOND', 'CR2-INFRA-RETRY']);
  assert.equal(r2[0].maps_from, 'CR-DESKTOP-MOBILE-FIRST');
  for (const [index, slot] of v1.entries()) {
    const { id: _id, maps_from: _maps, ...rest } = slot;
    const { id: _rid, maps_from: _rmaps, ...restR2 } = r2[index];
    assert.deepEqual(restR2, rest, `selection of ${slot.id} must be byte-identical to the frozen one`);
  }
  assert.deepEqual(r2.slice(0, 4).map((slot) => slot.rows), [16, 2, 2, 2]);
  assert.equal(r2[0].expected_cli_exit, 1);
  const retry = r2[4];
  assert.equal(retry.max_duration_ms, 120000);
  assert.equal(retry.selection ?? null, null);
  assert.equal(retry.project_selections, undefined);
  assert.equal(retry.rows, 0);
  assert.equal(r2.slice(0, 4).reduce((sum, slot) => sum + slot.rows, 0), 22);
});

test('v1 and R2 evidence are never accepted by the other revision, and the R2 modes refuse any other path', () => {
  const v1 = loadHarness();
  const r2 = loadHarnessR2();
  try {
    assert.equal(recovery.verifyLoadRecoveryEvidenceData(r2.read(), r2.freeze, `${r2.evidenceFile}.raw`, 'first', sha(fs.readFileSync(r2.freezeFile))).ok, false);
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR2(v1.read(), v1.freeze, `${v1.evidenceFile}.raw`, 'first', sha(fs.readFileSync(v1.freezeFile))).ok, false);
    const script = path.join(root, 'scripts/ci/ci-registration-recovery.mjs');
    const stray = path.join(temporary, 'stray-r2-freeze.json');
    const created = spawnSync(process.execPath, [script, '--create-load-recovery-r2', '--output', stray], { encoding: 'utf8', cwd: root });
    assert.equal(created.status, 3);
    assert.match(created.stderr, /reviewed phase artifact path/);
    assert.equal(fs.existsSync(stray), false);
    const checked = spawnSync(process.execPath, [script, '--check-load-recovery-freeze', stray], { encoding: 'utf8', cwd: root });
    assert.equal(checked.status, 3);
  } finally { v1.clean(); r2.clean(); }
});

test('R2 freeze creation and validation refuse a candidate without the preserved native records', () => {
  const fixture = createRegistrationNativeTreeFixture({ label: 'load-r2' });
  try {
    const out = path.join(fixture.root, 'out-freeze-r2.json');
    assert.throws(() => recovery.createLoadRecoveryFreezeR2(out, fixture.root));
    assert.equal(fs.existsSync(out), false);
    assert.throws(() => recovery.validateLoadRecoveryFreezeR2(fixture.root, { schema_version: 'x' }), /malformed|digest/i);
  } finally { fixture.cleanup?.(); }
});

// ---- synthetic R2 runner harness ----
function loadHarnessR2() {
  const base = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-load-r2-')));
  const checkout = path.join(base, 'checkout');
  const pwPackage = path.join(checkout, 'test/example/priv/playwright/node_modules/@playwright/test/package.json');
  fs.mkdirSync(path.dirname(pwPackage), { recursive: true });
  fs.writeFileSync(pwPackage, JSON.stringify({ version: '1.59.1' }));
  const ledger = recovery.buildLoadRecoveryLedgerR2(r2LedgerInput());
  const freeze = {
    schema_version: 'sigra.phase253.registration-load-recovery-freeze/v2', status: 'frozen_before_results', plan: '253-48', revision: 'r2',
    source: { repository: 'synthetic', checkout_head: 'a'.repeat(40), blobs: { 'scripts/x': 'b'.repeat(40) } },
    tools: { playwright: '1.59.1', ecto_sql: '3.13.5', phoenix_live_view: '1.1.28' },
    selection: { spec: 'tests/admin-eval.spec.ts' },
    historical: { infrastructure_halt: { slot_id: 'CR-DESKTOP-MOBILE-FIRST', cause: 'host_sleep', retryable: false, charged_ms: 1765488, fix_commit: 'cf578a567e4c01e6e9e904c2ca8c01bec85345d0', root_cause: { file: '.planning/debug/resolved/253-native-deadline-not-enforced.md', sha256: 'c'.repeat(64) } } },
    ledger
  };
  freeze.freeze_sha256 = sha(JSON.stringify(freeze));
  const freezeFile = path.join(base, 'freeze-r2.json'); const evidenceFile = path.join(base, 'evidence-r2.json');
  fs.writeFileSync(freezeFile, `${JSON.stringify(freeze, null, 2)}\n`);
  const writeEvidence = (approval) => {
    const evidence = {
      schema_version: 'sigra.phase253.registration-load-recovery-evidence/v2', revision: 'r2', status: 'ready', freeze_path: 'freeze-r2.json',
      freeze_sha256: sha(fs.readFileSync(freezeFile)), source: structuredClone(freeze.source), attempts: [], preparation: null, reservation: null, preserved_revisions: [],
      infrastructure_halts: [structuredClone(freeze.historical.infrastructure_halt)], infrastructure_retry: null,
      approval: { decision: approval.decision, retry_granted: approval.retry_granted },
      limits: {
        prior_charge_ms: 2042596, preparation_charge_ms: 0, preparation_remaining_ms: 30000, charged_duration_ms: 2042596,
        physical_playwright_cli_launches: 6, used_slots: [...R2_SPENT], max_d19_ms: approval.caps.d19_cap_ms, max_total_ms: approval.caps.shared_cap_ms,
        max_d19_physical_playwright_cli_launches: approval.caps.d19_launch_max, max_physical_playwright_cli_launches: approval.caps.physical_cli_max,
        retry_used: 1, retry_available: 0, infra_retry: { granted: approval.retry_granted, used: 0 }
      }
    };
    fs.writeFileSync(evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
    fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  };
  writeEvidence(R2_APPROVE);
  const calls = [];
  const zip = path.join(base, 'trace.zip'); fs.writeFileSync(zip, 'z'.repeat(64));
  const fakePsql = (counts) => { let index = 0; return () => { calls.push(['psql']); return { status: 0, stdout: `${counts[Math.min(index++, counts.length - 1)]}\n` }; }; };
  const allSlots = [...freeze.ledger.slots.slice(0, 4)];
  const reportFor = (slot, runId, { failRow = false } = {}) => ({
    config: {}, errors: [],
    suites: [{
      title: 'admin-eval.spec.ts', file: 'admin-eval.spec.ts', specs: [], suites: [{
        title: 'x', file: 'admin-eval.spec.ts',
        specs: recovery.loadRequiredPairs(slot).map((pair, index) => {
          let expected = slot.project_selections.find((item) => item.project === pair.project).expected[pair.title];
          const annotations = [];
          if (pair.title !== 'render bundle: board-mg-9/populated') annotations.push({ type: 'sigra-registration-control-context', description: `${runId}:${crypto.randomUUID()}` });
          if (pair.title === 'registration detects a deliberate same-account collision') annotations.push({ type: 'sigra-registration-control-result', description: JSON.stringify({ collision_email_sha256: slot.collision_account_sha256[pair.project], first_registration_succeeded: true, duplicate_response_confirmed: true }) });
          if (pair.title === 'registration starts from a fresh database and context') annotations.push({ type: 'sigra-registration-control-result', description: JSON.stringify({ prior_collision_account_email_sha256: slot.collision_account_sha256[pair.project], fresh_database_account_created: true }) });
          let failed = expected === 'expected_failure';
          const marker = { 'registration stops when LiveView readiness is never released': 'phx-connected', 'registration fails when the readiness wait is deliberately broken': 'data-sigra-never-connected', 'registration retains the first forced assertion failure trace': 'toHaveURL' }[pair.title];
          const broken = failRow && index === 0 && !failed;
          return {
            title: pair.title, file: 'admin-eval.spec.ts', ok: !failed && !broken,
            tests: [{ projectName: pair.project, expectedStatus: 'passed', status: failed || broken ? 'unexpected' : 'expected', annotations,
              results: [{ status: failed || broken ? 'failed' : 'passed', duration: 10, workerIndex: index, error: failed ? { message: `expect ${marker} failed` } : broken ? { message: 'unexpected assertion failure' } : undefined, attachments: failed ? [{ name: 'trace', path: zip }] : [], annotations: [] }] }]
          };
        })
      }]
    }]
  });
  const awakeFor = () => ({ held: true, platform: 'darwin', argv: ['/usr/bin/caffeinate', '-i', '-s', '-m', '-w', String(process.pid)], pid: 4321, release: () => calls.push(['release-awake']) });
  const makeDeps = ({ cliExit = null, postLine = true, accountCounts = [0, 1], absenceCounts = [0], validate = () => {}, approval = R2_APPROVE,
    suspendBrowser = false, suspendFlag = false, failRow = false, probeHost = null, holderAlive = () => true, diagnosticFile = null, checkDiagnostic = null } = {}) => {
    const absenceRun = fakePsql(absenceCounts); const accountRun = fakePsql(accountCounts);
    return {
      validate, enforcePaths: false, enforceNode: false, skipPreservation: true, diagnosticFile,
      readApproval: () => approval, holderAlive,
      checkDiagnostic: checkDiagnostic ?? ((_root, file) => { if (!file) throw new Error('infrastructure retry requires a committed diagnostic'); return { file, sha256: 'd'.repeat(64) }; }),
      probeHost: probeHost ?? (async () => { calls.push(['probe-host']); return { awake: awakeFor(), host_awake: { holder_pid: 4321, ac_power: true, assertions_sha256: 'e'.repeat(64), checked_at: '2026-10-14T08:00:00.000Z' } }; }),
      portAvailable: async () => true, waitReady: async () => 200, stopApp: async () => {},
      spawnApp: (program, args, options) => { calls.push(['app', program, ...args]); if (postLine) fs.writeSync(options.stdio[1], 'POST /users/log_in\n'); return { pid: 4242, exitCode: null, signalCode: null }; },
      runTree: async (program, args, cwd, env, log, timeoutMs) => {
        calls.push(['tree', program, ...args]);
        fs.writeFileSync(log, `${path.basename(program)} ${args[0]} ok\n`);
        if (program.endsWith('/playwright')) {
          const given = args.slice(2, -1);
          const slot = allSlots.find((item) => JSON.stringify(item.argv) === JSON.stringify(given));
          assert.equal(env.SIGRA_REGISTRATION_CONTROL_STAGE, slot.control_stage);
          assert.equal(args.filter((arg) => /^(-g|--grep)/.test(arg)).length, 0);
          if (suspendBrowser) return { pid: 777, exit_code: null, signal: 'SIGTERM', error: null, timed_out: true, suspended: true, duration_ms: 5, wall_duration_ms: 5, group_signals: ['SIGTERM'], descendants_reaped: true };
          fs.writeFileSync(env.SIGRA_PLAYWRIGHT_JSON, JSON.stringify(reportFor(slot, env.SIGRA_CONTROL_RUN_ID, { failRow })));
          return { pid: 777, exit_code: cliExit ?? slot.expected_cli_exit, signal: null, error: null, timed_out: false, suspended: suspendFlag, duration_ms: 5, group_signals: [], descendants_reaped: true };
        }
        return { pid: 1, exit_code: 0, signal: null, error: null, timed_out: false, duration_ms: 1, group_signals: [], descendants_reaped: true };
      },
      captureAbsence: (options) => recovery.captureOwnedDatabaseAbsence({ ...options, run: absenceRun }),
      captureAccount: (options) => recovery.captureOwnedAccountCount({ ...options, run: accountRun }),
      sanitizeTrace: (source, destination) => { fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL); return { entries: 3, navigation: true, submission: true }; }
    };
  };
  return { base, checkout, freeze, freezeFile, evidenceFile, calls, makeDeps, writeEvidence, read: () => JSON.parse(fs.readFileSync(evidenceFile, 'utf8')), clean: () => fs.rmSync(base, { recursive: true, force: true }) };
}

test('every spent identity, including CR-DESKTOP-MOBILE-FIRST, is refused by the R2 runner before any spawn', async () => {
  const h = loadHarnessR2();
  try {
    for (const id of [...R2_SPENT, 'R-CONTROL-FIRST-DESKTOP']) {
      await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, id, h.evidenceFile, h.checkout, h.makeDeps()), /spent|only the/i, id);
    }
    assert.deepEqual(h.calls, []);
    assert.equal(h.read().status, 'ready');
  } finally { h.clean(); }
});

test('a synthetic R2 first slot writes an R2 ledger that the first-stage verifier accepts', async () => {
  const h = loadHarnessR2();
  try {
    const result = await recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps());
    assert.equal(result.rows, 16);
    assert.equal(h.calls.filter((call) => call[0] === 'tree' && call[1].endsWith('/playwright')).length, 1);
    const evidence = h.read();
    assert.equal(evidence.schema_version, 'sigra.phase253.registration-load-recovery-evidence/v2');
    assert.equal(evidence.status, 'first_complete');
    assert.equal(evidence.limits.physical_playwright_cli_launches, 7);
    assert.deepEqual(evidence.limits.used_slots, [...R2_SPENT, 'CR2-DESKTOP-MOBILE-FIRST']);
    assert.equal(evidence.limits.charged_duration_ms, 2042596 + evidence.attempts[0].charged_duration_ms);
    assert.equal(evidence.attempts[0].files.traces.length, 9);
    const verdict = recovery.verifyLoadRecoveryEvidenceDataR2(evidence, h.freeze, `${h.evidenceFile}.raw`, 'first', sha(fs.readFileSync(h.freezeFile)));
    assert.deepEqual(verdict.errors, []);
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR2(evidence, h.freeze, `${h.evidenceFile}.raw`, 'complete', sha(fs.readFileSync(h.freezeFile))).ok, false);
  } finally { h.clean(); }
});

test('R2 runs all four regular slots once in order and verifies the complete 22-row proof', async () => {
  const h = loadHarnessR2();
  try {
    for (const id of ['CR2-DESKTOP-MOBILE-FIRST', 'CR-DESKTOP-SECOND', 'CR-MOBILE-SECOND', 'CR-DARK-SECOND']) {
      await recovery.runLoadRecoverySlotR2(h.freezeFile, id, h.evidenceFile, h.checkout, h.makeDeps());
    }
    const evidence = h.read();
    assert.equal(evidence.status, 'complete');
    assert.equal(evidence.attempts.reduce((sum, item) => sum + item.lifecycle.rows, 0), 22);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 10);
    const verdict = recovery.verifyLoadRecoveryEvidenceDataR2(evidence, h.freeze, `${h.evidenceFile}.raw`, 'complete', sha(fs.readFileSync(h.freezeFile)));
    assert.deepEqual(verdict.errors, []);
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR-DARK-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|consumed|already|order/i);
  } finally { h.clean(); }
});

test('R2 refuses out-of-order slots, a reopened original retry, a counter reset and a slot outside the frozen table', async () => {
  for (const [mutate, pattern, slot] of [
    [() => {}, /frozen order/i, 'CR-MOBILE-SECOND'],
    [(e) => { e.limits.retry_available = 1; }, /retry/i, 'CR2-DESKTOP-MOBILE-FIRST'],
    [(e) => { e.limits.charged_duration_ms = 0; e.limits.prior_charge_ms = 0; }, /reset/i, 'CR2-DESKTOP-MOBILE-FIRST'],
    [() => {}, /only the/i, 'CR-UNKNOWN']
  ]) {
    const h = loadHarnessR2();
    try {
      const evidence = h.read(); mutate(evidence);
      fs.writeFileSync(h.evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
      await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, slot, h.evidenceFile, h.checkout, h.makeDeps()), pattern);
      assert.deepEqual(h.calls, [], String(pattern));
    } finally { h.clean(); }
  }
});

// ---- Plan 48 task 2: budget approval, host-sleep preflight, infrastructure retry, terminal-evidence binding ----
const gitIn = (cwd, ...args) => {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' });
  assert.equal(result.status, 0, `git ${args.join(' ')}: ${result.stderr}`);
  return result.stdout.trim();
};
function approvalRepo() {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-approval-')));
  gitIn(dir, 'init', '-q'); gitIn(dir, 'config', 'user.email', 'test@example.test'); gitIn(dir, 'config', 'user.name', 'test'); gitIn(dir, 'config', 'commit.gpgsign', 'false');
  const phase = ['.planning', 'phases', '253-fix-flaky-ci-and-preserve-required-checks'].join('/');
  fs.mkdirSync(path.join(dir, phase), { recursive: true });
  const budget = path.join(dir, phase, '253-LOAD-RECOVERY-BUDGETS-R2.md');
  fs.writeFileSync(budget, '# budgets r2\n');
  const freezeFile = path.join(dir, phase, '253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json');
  const freeze = { schema_version: 'sigra.phase253.registration-load-recovery-freeze/v2', budget: { file: `${phase}/253-LOAD-RECOVERY-BUDGETS-R2.md`, sha256: sha(fs.readFileSync(budget)) } };
  fs.writeFileSync(freezeFile, `${JSON.stringify(freeze)}\n`);
  gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'seed');
  return { dir, phase, budget, freezeFile, freeze, approval: path.join(dir, phase, '253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json'), clean: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

test('recording a budget approval is exclusive, binds the budget and freeze hashes, and a reject writes nothing', () => {
  const r = approvalRepo();
  try {
    assert.throws(() => recovery.recordBudgetApproval({ decision: 'reject', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'no' }, r.dir, { enforcePaths: false }), /reject|grants no capacity|decision/i);
    assert.throws(() => recovery.recordBudgetApproval({ decision: 'maybe', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'x' }, r.dir, { enforcePaths: false }), /decision/i);
    assert.equal(fs.existsSync(r.approval), false);
    const record = recovery.recordBudgetApproval({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'approve exactly as written' }, r.dir, { enforcePaths: false, now: () => '2026-10-14T08:00:00.000Z' });
    const onDisk = JSON.parse(fs.readFileSync(r.approval, 'utf8'));
    assert.deepEqual(onDisk, record);
    assert.equal(onDisk.schema_version, 'sigra.phase253.load-recovery-budget-approval/v1');
    assert.equal(onDisk.decision, 'approve');
    assert.equal(onDisk.decided_by, 'Jon (operator), recorded by executor from checkpoint response');
    assert.equal(onDisk.decision_text, 'approve exactly as written');
    assert.equal(onDisk.budget_sha256, sha(fs.readFileSync(r.budget)));
    assert.equal(onDisk.freeze_sha256, sha(fs.readFileSync(r.freezeFile)));
    assert.deepEqual(onDisk.caps, R2_APPROVE.caps);
    assert.equal(onDisk.retry_granted, 1);
    assert.equal(onDisk.recorded_at, '2026-10-14T08:00:00.000Z');
    assert.throws(() => recovery.recordBudgetApproval({ decision: 'approve-without-retry', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'again' }, r.dir, { enforcePaths: false }), /EEXIST|exist|exclusive/i);
    assert.equal(JSON.parse(fs.readFileSync(r.approval, 'utf8')).decision, 'approve', 'the first record is never overwritten');
  } finally { r.clean(); }
});

test('an approval for approve-without-retry grants no infrastructure retry and a budget mismatch refuses to record', () => {
  const r = approvalRepo();
  try {
    const record = recovery.recordBudgetApproval({ decision: 'approve-without-retry', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'no retry' }, r.dir, { enforcePaths: false });
    assert.equal(record.retry_granted, 0);
    assert.deepEqual(record.caps, R2_APPROVE_NO_RETRY.caps);
    fs.rmSync(r.approval);
    fs.writeFileSync(r.budget, '# budgets r2 (edited)\n');
    assert.throws(() => recovery.recordBudgetApproval({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'x' }, r.dir, { enforcePaths: false }), /budget/i);
    assert.equal(fs.existsSync(r.approval), false);
  } finally { r.clean(); }
});

test('a run needs a committed approval record bound to the budget document and the freeze', () => {
  const r = approvalRepo();
  try {
    assert.throws(() => recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze), /absent|missing/i);
    recovery.recordBudgetApproval({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'ok' }, r.dir, { enforcePaths: false });
    assert.throws(() => recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze), /committed/i);
    gitIn(r.dir, 'add', '-A'); gitIn(r.dir, 'commit', '-q', '-m', 'approval');
    const good = recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze);
    assert.equal(good.decision, 'approve');
    assert.equal(good.retry_granted, 1);
    fs.writeFileSync(r.approval, `${fs.readFileSync(r.approval, 'utf8')} `);
    assert.throws(() => recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze), /committed|differs/i);
    gitIn(r.dir, 'checkout', '--', '.');
    const edited = JSON.parse(fs.readFileSync(r.approval, 'utf8')); edited.budget_sha256 = 'f'.repeat(64);
    fs.writeFileSync(r.approval, `${JSON.stringify(edited, null, 2)}\n`); gitIn(r.dir, 'add', '-A'); gitIn(r.dir, 'commit', '-q', '-m', 'bad budget');
    assert.throws(() => recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze), /budget/i);
    edited.budget_sha256 = sha(fs.readFileSync(r.budget)); edited.freeze_sha256 = 'f'.repeat(64);
    fs.writeFileSync(r.approval, `${JSON.stringify(edited, null, 2)}\n`); gitIn(r.dir, 'add', '-A'); gitIn(r.dir, 'commit', '-q', '-m', 'bad freeze');
    assert.throws(() => recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze), /freeze/i);
    edited.freeze_sha256 = sha(fs.readFileSync(r.freezeFile)); edited.caps = { ...edited.caps, d19_cap_ms: edited.caps.d19_cap_ms + 1 };
    fs.writeFileSync(r.approval, `${JSON.stringify(edited, null, 2)}\n`); gitIn(r.dir, 'add', '-A'); gitIn(r.dir, 'commit', '-q', '-m', 'bad caps');
    assert.throws(() => recovery.readCommittedApproval(r.dir, r.freezeFile, r.freeze), /caps/i);
  } finally { r.clean(); }
});

const PMSET_AC = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t100%; charged; 0:00 remaining present: true\n";
const PMSET_BATTERY = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t80%; discharging; 3:00 remaining present: true\n";
const pmsetAssertions = (pid, names = ['PreventUserIdleSystemSleep', 'PreventSystemSleep']) => `Assertion status system-wide:\n   PreventUserIdleSystemSleep    1\nListed by owning process:\n${names.map((name) => `   pid ${pid}(caffeinate): [0x0001] 00:00:05 ${name} named: "caffeinate command-line tool"`).join('\n')}\n`;
function hostProbeHarness({ batt = PMSET_AC, assertions = pmsetAssertions(4321), alive = true, holderPid = 4321 } = {}) {
  const events = [];
  let clock = 0;
  return {
    events,
    options: {
      platform: 'darwin',
      pmset: (args) => { events.push(['pmset', args.join(' ')]); return { status: 0, stdout: args[1] === 'batt' ? batt : assertions }; },
      holdAwake: () => { events.push(['hold']); return { held: true, platform: 'darwin', pid: holderPid, argv: ['/usr/bin/caffeinate'], release: () => events.push(['release']) }; },
      isAlive: () => alive,
      now: () => { clock += 1500; return clock; },
      sleep: async () => {},
      waitMs: 3000
    }
  };
}

test('the host preflight proves AC power, the caffeinate holder and both pmset assertions, and records their hash', async () => {
  const h = hostProbeHarness();
  const result = await recovery.probeHostSleepSafety(h.options);
  assert.equal(result.host_awake.holder_pid, 4321);
  assert.equal(result.host_awake.ac_power, true);
  assert.equal(result.host_awake.assertions_sha256, sha(pmsetAssertions(4321)));
  assert.match(result.host_awake.checked_at, /^\d{4}-\d{2}-\d{2}T/);
  assert.equal(result.awake.held, true);
  assert.deepEqual(h.events.map((event) => event[0]).filter((kind) => kind !== 'pmset'), ['hold']);
  assert.ok(h.events.findIndex((event) => event[0] === 'pmset' && event[1] === '-g batt') < h.events.findIndex((event) => event[0] === 'hold'), 'AC power is proven before the holder starts');
  result.awake.release();
});

test('the host preflight refuses, and releases any holder, for battery power, a dead holder or missing assertions', async () => {
  const battery = hostProbeHarness({ batt: PMSET_BATTERY });
  await assert.rejects(() => recovery.probeHostSleepSafety(battery.options), /AC power/i);
  assert.equal(battery.events.some((event) => event[0] === 'hold'), false, 'no holder is started on battery');

  for (const [name, options, pattern] of [
    ['dead holder', { alive: false }, /holder.*not running|not running/i],
    ['other pid', { assertions: pmsetAssertions(9999) }, /assertion/i],
    ['missing PreventSystemSleep', { assertions: pmsetAssertions(4321, ['PreventUserIdleSystemSleep']) }, /PreventSystemSleep/],
    ['missing PreventUserIdleSystemSleep', { assertions: pmsetAssertions(4321, ['PreventSystemSleep']) }, /PreventUserIdleSystemSleep/]
  ]) {
    const h = hostProbeHarness(options);
    await assert.rejects(() => recovery.probeHostSleepSafety(h.options), pattern, name);
    assert.deepEqual(h.events.filter((event) => event[0] !== 'pmset').map((event) => event[0]), ['hold', 'release'], `${name}: holder released`);
  }
  await assert.rejects(() => recovery.probeHostSleepSafety({ ...hostProbeHarness().options, platform: 'linux' }), /macOS|darwin/i);
});

test('an R2 run refuses before the predebit when approval is missing or the host proof fails', async () => {
  for (const [label, overrides, pattern] of [
    ['approval absent', { readApproval: () => { throw new Error('R2 budget approval record is absent'); } }, /approval/i],
    ['host proof fails', { probeHost: async () => { throw new Error('host is not on AC power'); } }, /AC power/i]
  ]) {
    const h = loadHarnessR2();
    try {
      const before = h.read();
      await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, { ...h.makeDeps(), ...overrides }), pattern, label);
      assert.deepEqual(h.read(), before, `${label}: no reservation, used slot or charge`);
      assert.equal(h.calls.filter((call) => call[0] === 'tree' || call[0] === 'app').length, 0, label);
    } finally { h.clean(); }
  }
});

test('the approval decides the ceilings that the run enforces', async () => {
  const h = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps({ approval: R2_APPROVE_NO_RETRY })), /approval caps differ/i);
    assert.deepEqual(h.calls, []);
  } finally { h.clean(); }
});

test('the R2 verifier rejects a receipt without its host_awake proof and any suspended receipt', async () => {
  const h = loadHarnessR2();
  try {
    await recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps());
    const evidence = h.read();
    assert.deepEqual(evidence.attempts[0].host_awake, { holder_pid: 4321, ac_power: true, assertions_sha256: 'e'.repeat(64), checked_at: '2026-10-14T08:00:00.000Z' });
    const verify = (mutate) => { const copy = structuredClone(evidence); mutate(copy.attempts[0]); return recovery.verifyLoadRecoveryEvidenceDataR2(copy, h.freeze, `${h.evidenceFile}.raw`, 'first', sha(fs.readFileSync(h.freezeFile))); };
    assert.equal(verify(() => {}).ok, true);
    for (const [name, mutate, pattern] of [
      ['no host_awake', (a) => { delete a.host_awake; }, /host_awake/],
      ['not on AC', (a) => { a.host_awake.ac_power = false; }, /host_awake/],
      ['no assertion hash', (a) => { a.host_awake.assertions_sha256 = 'x'; }, /host_awake/],
      ['suspended true', (a) => { a.host.suspended = true; }, /suspended/],
      ['suspension detected', (a) => { a.host.suspension_detected = true; }, /suspension/],
      ['charge below the larger clock', (a) => { a.wall_duration_ms = a.charged_duration_ms + 10; }, /charge/]
    ]) {
      const verdict = verify(mutate);
      assert.equal(verdict.ok, false, name);
      assert.match(verdict.errors.join(';'), pattern, name);
    }
  } finally { h.clean(); }
});

test('a host sleep halts as halted_infrastructure, stays charged and counted, and blocks every regular slot until the retry', async () => {
  const h = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps({ suspendBrowser: true })), /work deadline|suspension/i);
    const evidence = h.read();
    assert.equal(evidence.status, 'halted_infrastructure');
    assert.equal(evidence.attempts[0].observed_outcome, 'halted_infrastructure');
    assert.equal(evidence.infrastructure_retry.eligible, true);
    assert.equal(evidence.infrastructure_retry.halted_slot, 'CR2-DESKTOP-MOBILE-FIRST');
    assert.equal(evidence.infrastructure_retry.cause, 'host_sleep');
    assert.equal(evidence.infrastructure_halts.length, 2);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 7);
    assert.equal(evidence.limits.charged_duration_ms, 2042596 + evidence.attempts[0].charged_duration_ms);
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR2(evidence, h.freeze, `${h.evidenceFile}.raw`, 'first', sha(fs.readFileSync(h.freezeFile))).ok, false);
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR-DESKTOP-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|reserved|halted/i);
  } finally { h.clean(); }
});

test('CR2-INFRA-RETRY runs once, needs a committed diagnostic and a granted retry, and re-runs the identical frozen selection', async () => {
  const h = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps()), /halted_infrastructure|infrastructure/i);
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps({ suspendBrowser: true })));
    const callsBefore = h.calls.length;
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps()), /diagnostic/i);
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json', checkDiagnostic: () => { throw new Error('diagnostic is not committed'); } })), /not committed/i);
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json', approval: R2_APPROVE_NO_RETRY })), /retry|caps/i);
    assert.equal(h.calls.length, callsBefore, 'every refusal happens before any spawn');

    const result = await recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json' }));
    assert.equal(result.rows, 16);
    const evidence = h.read();
    assert.equal(evidence.status, 'first_complete');
    assert.equal(evidence.attempts.length, 2);
    assert.equal(evidence.attempts[1].slot_id, 'CR2-INFRA-RETRY');
    assert.equal(evidence.attempts[1].retry_of, 'CR2-DESKTOP-MOBILE-FIRST');
    assert.deepEqual(evidence.attempts[1].argv, evidence.attempts[0].argv);
    assert.equal(evidence.infrastructure_retry.used, true);
    assert.deepEqual(evidence.infrastructure_retry.diagnostic, { file: 'diag.json', sha256: 'd'.repeat(64) });
    assert.equal(evidence.limits.infra_retry.used, 1);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 8);
    assert.deepEqual(evidence.limits.used_slots, [...R2_SPENT, 'CR2-DESKTOP-MOBILE-FIRST', 'CR2-INFRA-RETRY']);
    assert.equal(evidence.limits.charged_duration_ms, 2042596 + evidence.attempts[0].charged_duration_ms + evidence.attempts[1].charged_duration_ms);
    const freezeHash = sha(fs.readFileSync(h.freezeFile));
    const verdict = recovery.verifyLoadRecoveryEvidenceDataR2(evidence, h.freeze, `${h.evidenceFile}.raw`, 'first', freezeHash);
    assert.deepEqual(verdict.errors, [], 'the original stays in attempts and the pair counts as one slot outcome');

    const drifted = structuredClone(evidence); drifted.attempts[1].argv = drifted.attempts[1].argv.filter((arg) => arg !== '--project=admin-eval-dark');
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR2(drifted, h.freeze, `${h.evidenceFile}.raw`, 'first', freezeHash).ok, false, 'a retry with another selection is rejected');
    const noDiagnostic = structuredClone(evidence); noDiagnostic.infrastructure_retry.diagnostic = null;
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR2(noDiagnostic, h.freeze, `${h.evidenceFile}.raw`, 'first', freezeHash).ok, false, 'a retry without a recorded diagnostic is rejected');

    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json' })), /halted_infrastructure|infrastructure|already/i, 'the retry is usable once');
  } finally { h.clean(); }
});

test('the retry is never available after an assertion failure, a non-suspension halt, a second infrastructure halt or approve-without-retry', async () => {
  const noSuspension = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(noSuspension.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', noSuspension.evidenceFile, noSuspension.checkout, noSuspension.makeDeps({ cliExit: 0 })), /exit does not match/i);
    assert.equal(noSuspension.read().status, 'halted');
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(noSuspension.freezeFile, 'CR2-INFRA-RETRY', noSuspension.evidenceFile, noSuspension.checkout, noSuspension.makeDeps({ diagnosticFile: 'diag.json' })), /halted_infrastructure|infrastructure/i);
  } finally { noSuspension.clean(); }

  const assertion = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(assertion.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', assertion.evidenceFile, assertion.checkout, assertion.makeDeps({ suspendFlag: true, failRow: true })));
    assert.equal(assertion.read().status, 'halted', 'a suspension that also shows an assertion failure is terminal');
  } finally { assertion.clean(); }

  const second = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(second.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', second.evidenceFile, second.checkout, second.makeDeps({ suspendBrowser: true })));
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(second.freezeFile, 'CR2-INFRA-RETRY', second.evidenceFile, second.checkout, second.makeDeps({ diagnosticFile: 'diag.json', suspendBrowser: true })));
    const evidence = second.read();
    assert.equal(evidence.status, 'halted', 'a second infrastructure halt is terminal');
    assert.equal(evidence.limits.infra_retry.used, 1);
    assert.equal(evidence.attempts.length, 2);
  } finally { second.clean(); }

  const withoutRetry = loadHarnessR2();
  try {
    withoutRetry.writeEvidence(R2_APPROVE_NO_RETRY);
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(withoutRetry.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', withoutRetry.evidenceFile, withoutRetry.checkout, withoutRetry.makeDeps({ approval: R2_APPROVE_NO_RETRY, suspendBrowser: true })));
    assert.equal(withoutRetry.read().status, 'halted', 'no retry was granted, so the infrastructure halt is terminal');
  } finally { withoutRetry.clean(); }
});

test('a lost caffeinate holder at the end of the window is an infrastructure halt', async () => {
  const h = loadHarnessR2();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR2(h.freezeFile, 'CR2-DESKTOP-MOBILE-FIRST', h.evidenceFile, h.checkout, h.makeDeps({ holderAlive: () => false })), /holder/i);
    const evidence = h.read();
    assert.equal(evidence.status, 'halted_infrastructure');
    assert.equal(evidence.infrastructure_retry.cause, 'holder_lost');
    assert.equal(evidence.attempts[0].host.holder_alive_at_end, false);
  } finally { h.clean(); }
});

test('accepted evidence verifies by git ancestry and object reads after a later committed runner change, while a live check still demands the working tree', () => {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-terminal-')));
  try {
    gitIn(dir, 'init', '-q'); gitIn(dir, 'config', 'user.email', 'test@example.test'); gitIn(dir, 'config', 'user.name', 'test'); gitIn(dir, 'config', 'commit.gpgsign', 'false');
    fs.writeFileSync(path.join(dir, 'runner.mjs'), 'export const fixed = true;\n');
    gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'fixed runner');
    const fixed = gitIn(dir, 'rev-parse', 'HEAD');
    fs.writeFileSync(path.join(dir, 'other.txt'), 'x\n');
    gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'freeze point');
    const frozenHead = gitIn(dir, 'rev-parse', 'HEAD');
    const freeze = { source: { checkout_head: frozenHead, blobs: { 'runner.mjs': gitIn(dir, 'rev-parse', `${frozenHead}:runner.mjs`) } }, fixed_runner: { commit: fixed } };
    assert.equal(recovery.verifyFrozenSourceBindingR2(dir, freeze, { terminal: false }), frozenHead);
    fs.writeFileSync(path.join(dir, 'runner.mjs'), 'export const fixed = true; export const later = 1;\n');
    gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'later runner change');
    assert.throws(() => recovery.verifyFrozenSourceBindingR2(dir, freeze, { terminal: false }), /identity mismatch/i, 'a live check still demands working-tree equality');
    assert.equal(recovery.verifyFrozenSourceBindingR2(dir, freeze, { terminal: true }), gitIn(dir, 'rev-parse', 'HEAD'), 'accepted evidence is not silently invalidated');
    const forged = structuredClone(freeze); forged.source.blobs['runner.mjs'] = '0'.repeat(40);
    assert.throws(() => recovery.verifyFrozenSourceBindingR2(dir, forged, { terminal: true }), /blob mismatch/i, 'nor silently re-accepted when the frozen blob differs');
    const notAncestor = structuredClone(freeze); notAncestor.fixed_runner.commit = frozenHead; notAncestor.source.checkout_head = fixed;
    assert.throws(() => recovery.verifyFrozenSourceBindingR2(dir, notAncestor, { terminal: true }), /ancestor|blob mismatch/i);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('the standalone host preflight prints nothing to the ledger and releases its holder', async () => {
  const h = hostProbeHarness();
  const line = await recovery.preflightHostSleep(h.options);
  const parsed = JSON.parse(line);
  assert.equal(parsed.holder_pid, 4321);
  assert.equal(parsed.ac_power, true);
  assert.deepEqual(h.events.map((event) => event[0]).filter((kind) => kind !== 'pmset'), ['hold', 'release']);
});

test('the approval recorder CLI refuses a reject decision and writes nothing', () => {
  const script = path.join(root, 'scripts/ci/ci-registration-recovery.mjs');
  const out = path.join(temporary, 'approval-reject.json');
  const result = spawnSync(process.execPath, [script, '--record-budget-approval', '--decision', 'reject', '--budget', path.join(temporary, 'b.md'), '--freeze', path.join(temporary, 'f.json'), '--output', out, '--decision-text', 'no'], { encoding: 'utf8', cwd: root });
  assert.equal(result.status, 3);
  assert.match(result.stderr, /decision/i);
  assert.equal(fs.existsSync(out), false);
});

test('ordinary registration runner contracts opened no server or socket', () => {
  assert.deepEqual(networkAttempts, []);
});

// ---- Phase 253 plan 59: per-test JSONL reporter, attempt diagnostics preservation, R3 verifier ----
const REPORTER_FILE = path.join(root, 'test/example/priv/playwright/lib/reporters/failure-jsonl.mjs');
const FAKE_SECRET = 'FAKE-SECRET-KEY-BASE-0123456789abcdef-not-real';

function fakeTest(title, project = 'admin-eval') {
  return { title, location: { file: '/x/tests/admin-eval.spec.ts', line: 12 }, expectedStatus: 'passed', ok() { return this.__ok; }, parent: { project: () => ({ name: project }) }, __ok: true };
}

async function writeFakeJsonl(file) {
  const { default: Reporter } = await import(REPORTER_FILE);
  const reporter = new Reporter({ outputFile: file });
  const a = fakeTest('passing one'); const b = fakeTest('passing two'); const c = fakeTest('failing three'); c.__ok = false;
  reporter.onTestEnd(a, { status: 'passed', duration: 11, retry: 0, errors: [] });
  reporter.onTestEnd(b, { status: 'passed', duration: 12, retry: 0, errors: [] });
  reporter.onTestEnd(c, { status: 'failed', duration: 13, retry: 0, errors: [{ message: '\u001b[31mError: expect(received).toBeVisible()\u001b[39m\nTimeout', location: { file: '/x/a.ts', line: 3, column: 4 } }] });
  return reporter; // onEnd is deliberately never called
}

function launchedAttempt(extra = {}) {
  return { slot_id: 'R3-A', playwright_cli: { launched: true }, ...extra };
}

test('failure JSONL reporter appends one fsynced line per finished test without onEnd', async () => {
  const file = path.join(temporary, 'reporter', 'tests.jsonl');
  const reporter = await writeFakeJsonl(file);
  assert.equal(reporter.printsToStdio(), false);
  const lines = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
  assert.equal(lines.length, 3);
  assert.deepEqual(lines.map((l) => l.status), ['passed', 'passed', 'failed']);
  assert.ok(lines.every((l) => l.schema === 'sigra.phase253.playwright-test-end/v1'));
  assert.equal(lines[2].project, 'admin-eval');
  assert.equal(lines[2].title, 'failing three');
  assert.equal(lines[2].ok, false);
  assert.equal(lines[2].expected_status, 'passed');
  assert.equal(lines[2].duration_ms, 13);
  assert.equal(lines[2].errors.length, 1);
  assert.doesNotMatch(lines[2].errors[0].message, /\u001b/);
  assert.match(lines[2].errors[0].message, /^Error: expect\(received\)\.toBeVisible\(\)/);
  assert.deepEqual(lines[2].errors[0].location, { file: '/x/a.ts', line: 3, column: 4 });
});

test('failure JSONL reporter fsyncs every line and truncates oversized messages to 8192 bytes', async (t) => {
  const file = path.join(temporary, 'reporter-fsync', 'tests.jsonl');
  const calls = [];
  const original = fs.fsyncSync;
  fs.fsyncSync = (fd) => { calls.push(fd); return original(fd); };
  t.after(() => { fs.fsyncSync = original; });
  const { default: Reporter } = await import(REPORTER_FILE);
  const reporter = new Reporter({ outputFile: file });
  const huge = fakeTest('huge'); huge.__ok = false;
  reporter.onTestEnd(huge, { status: 'failed', duration: 1, retry: 0, errors: [{ message: 'é'.repeat(20000) }] });
  reporter.onTestEnd(fakeTest('ok'), { status: 'passed', duration: 1, retry: 0, errors: [] });
  assert.equal(calls.length, 2);
  const [first] = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
  assert.ok(Buffer.byteLength(first.errors[0].message) <= 8192);
  assert.ok(first.errors[0].message.length > 1000);
});

test('failure JSONL reporter refuses to run without an output file', async () => {
  const { default: Reporter } = await import(REPORTER_FILE);
  assert.throws(() => new Reporter({}), /outputFile/);
});

function diagnosticsTree(name) {
  const base = path.join(temporary, name);
  const tempRoot = path.join(base, 'temp');
  const outputDir = path.join(tempRoot, 'test-results');
  fs.mkdirSync(path.join(outputDir, 'case-one'), { recursive: true });
  fs.mkdirSync(path.join(outputDir, 'case-two'), { recursive: true });
  fs.writeFileSync(path.join(outputDir, 'case-one', 'error-context.md'), `# Page snapshot\n"secret_key_base": "${FAKE_SECRET}"\n- heading "Register"\n`);
  fs.writeFileSync(path.join(outputDir, 'case-two', 'error-context.md'), '# Page snapshot\n- button "Go"\n');
  fs.writeFileSync(path.join(outputDir, 'case-two', 'trace.zip'), 'not preserved');
  const rawDir = path.join(base, 'raw');
  const rawAttempt = path.join(rawDir, 'R3-A', 'attempt-01');
  fs.mkdirSync(rawAttempt, { recursive: true });
  return { base, tempRoot, outputDir, rawDir, rawAttempt, jsonlPath: path.join(tempRoot, 'tests.jsonl') };
}

test('preserveAttemptDiagnostics copies sanitized JSONL and error-context files with hashed receipts', async () => {
  const t = diagnosticsTree('diag-preserve');
  await writeFakeJsonl(t.jsonlPath);
  const result = recovery.preserveAttemptDiagnostics(t);
  assert.equal(result.jsonl.path, path.join('R3-A', 'attempt-01', 'diagnostics', 'tests.jsonl'));
  assert.equal(result.jsonl.sha256, crypto.createHash('sha256').update(fs.readFileSync(path.join(t.rawDir, result.jsonl.path))).digest('hex'));
  assert.equal(result.per_test.length, 3);
  assert.equal(result.error_contexts.length, 2);
  for (const ref of result.error_contexts) {
    const body = fs.readFileSync(path.join(t.rawDir, ref.path), 'utf8');
    assert.doesNotMatch(body, new RegExp(FAKE_SECRET));
    assert.equal(ref.sha256, crypto.createHash('sha256').update(body).digest('hex'));
  }
  assert.ok(result.error_contexts.some((ref) => /\[REDACTED\]/.test(fs.readFileSync(path.join(t.rawDir, ref.path), 'utf8'))));
  assert.equal(fs.readdirSync(path.join(t.rawAttempt, 'diagnostics')).some((name) => /trace/.test(name)), false);
});

test('preserveAttemptDiagnostics records an absent JSONL and refuses to overwrite', async () => {
  const t = diagnosticsTree('diag-absent');
  const result = recovery.preserveAttemptDiagnostics(t);
  assert.equal(result.jsonl, null);
  assert.deepEqual(result.per_test, []);
  assert.throws(() => recovery.preserveAttemptDiagnostics(t), /EEXIST|already exists|refus/i);
});

test('preserveAttemptDiagnostics preserves what finished before a deadline kill and tolerates a truncated last line', async () => {
  const t = diagnosticsTree('diag-killed');
  await writeFakeJsonl(t.jsonlPath);
  fs.appendFileSync(t.jsonlPath, '{"schema":"sigra.phase253.playwright-test-end/v1","title":"cut off');
  const result = recovery.preserveAttemptDiagnostics(t);
  assert.equal(result.per_test.length, 3);
  assert.equal(result.truncated_tail, true);
});

test('preserveAttemptDiagnostics redacts a JSON-escaped secret inside a decoded error message', async () => {
  const t = diagnosticsTree('diag-json-secret');
  const { default: Reporter } = await import(REPORTER_FILE);
  const reporter = new Reporter({ outputFile: t.jsonlPath });
  const failing = fakeTest('leaky'); failing.__ok = false;
  reporter.onTestEnd(failing, { status: 'failed', duration: 1, retry: 0, errors: [{ message: `config: {"secret_key_base": "${FAKE_SECRET}"}` }] });
  const result = recovery.preserveAttemptDiagnostics(t);
  const body = fs.readFileSync(path.join(t.rawDir, result.jsonl.path), 'utf8');
  assert.doesNotMatch(body, new RegExp(FAKE_SECRET));
  assert.match(body, /REDACTED/);
  assert.deepEqual(recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics: result }), t.rawDir), { ok: true, errors: [] });
});

test('verifyAttemptDiagnosticsR3 accepts hashed receipts and an unlaunched attempt without diagnostics', async () => {
  const t = diagnosticsTree('diag-verify-ok');
  await writeFakeJsonl(t.jsonlPath);
  const diagnostics = recovery.preserveAttemptDiagnostics(t);
  assert.deepEqual(recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics }), t.rawDir), { ok: true, errors: [] });
  assert.deepEqual(recovery.verifyAttemptDiagnosticsR3({ slot_id: 'R3-B', playwright_cli: { launched: false } }, t.rawDir), { ok: true, errors: [] });
});

test('verifyAttemptDiagnosticsR3 rejects a launched attempt lacking, tampering or malforming per-test JSONL', async () => {
  const t = diagnosticsTree('diag-verify-bad');
  await writeFakeJsonl(t.jsonlPath);
  const diagnostics = recovery.preserveAttemptDiagnostics(t);
  const missing = recovery.verifyAttemptDiagnosticsR3(launchedAttempt({}), t.rawDir);
  assert.equal(missing.ok, false);
  assert.match(missing.errors.join(';'), /per-test JSONL/);
  const absent = recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics: { ...diagnostics, jsonl: null } }), t.rawDir);
  assert.equal(absent.ok, false);
  const jsonlFile = path.join(t.rawDir, diagnostics.jsonl.path);
  const original = fs.readFileSync(jsonlFile, 'utf8');
  fs.writeFileSync(jsonlFile, original.replace('failing three', 'failing THREE'));
  const tampered = recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics }), t.rawDir);
  assert.equal(tampered.ok, false);
  assert.match(tampered.errors.join(';'), /sha256|hash/i);
  const malformed = `${original}{not json}\n`;
  fs.writeFileSync(jsonlFile, malformed);
  const forged = { ...diagnostics, jsonl: { ...diagnostics.jsonl, sha256: crypto.createHash('sha256').update(malformed).digest('hex'), bytes: Buffer.byteLength(malformed) } };
  const bad = recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics: forged }), t.rawDir);
  assert.equal(bad.ok, false);
  assert.match(bad.errors.join(';'), /malformed/);
  fs.writeFileSync(jsonlFile, original);
  const ctx = path.join(t.rawDir, diagnostics.error_contexts[0].path);
  fs.writeFileSync(ctx, 'changed');
  const ctxTampered = recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics }), t.rawDir);
  assert.equal(ctxTampered.ok, false);
  const escape = recovery.verifyAttemptDiagnosticsR3(launchedAttempt({ diagnostics: { ...diagnostics, jsonl: { ...diagnostics.jsonl, path: '../../etc/passwd' } } }), t.rawDir);
  assert.equal(escape.ok, false);
});

// ---- Phase 253 plan 60 task 1: R3 ledger, R2-lineage history reader and freeze ----
const R3_SPENT = [...R2_SPENT, 'CR2-DESKTOP-MOBILE-FIRST'];
const R3_CHARGES = [...R2_CHARGES, 743, 107343];
const r3LedgerInput = () => ({
  charges: [...R3_CHARGES], physicalPlaywrightLaunches: 7, spentReservations: [...R3_SPENT],
  retryUsed: 1, retryAvailable: 0, preparationUsedMs: 5141
});
const R3_APPROVE = {
  schema_version: 'sigra.phase253.load-recovery-budget-approval/v2', decision: 'approve', retry_granted: 1,
  caps: { new_allowance_ms: 910000, d19_cap_ms: 3060682, d19_launch_max: 12, shared_cap_ms: 5400682, physical_cli_max: 21 }
};
const R3_APPROVE_NO_RETRY = {
  schema_version: 'sigra.phase253.load-recovery-budget-approval/v2', decision: 'approve-without-retry', retry_granted: 0,
  caps: { new_allowance_ms: 670000, d19_cap_ms: 2820682, d19_launch_max: 11, shared_cap_ms: 5160682, physical_cli_max: 20 }
};
const PHASE_REL = ['.planning', 'phases', '253-fix-flaky-ci-and-preserve-required-checks'].join('/');

test('R3 ledger carries 2150682 ms, seven launches and eight spent identities, with the reviewed R3 caps', () => {
  const ledger = recovery.buildLoadRecoveryLedgerR3(r3LedgerInput());
  assert.equal(ledger.prior_charge_ms, 2150682);
  assert.equal(2042596 + 743 + 107343, 2150682);
  assert.equal(ledger.prior_playwright_cli_launches, 7);
  assert.deepEqual(ledger.spent_reservations, R3_SPENT);
  assert.equal(ledger.spent_reservations.length, 8);
  assert.equal(ledger.preparation_used_ms, 5141);
  assert.equal(ledger.preparation_reserve_ms, 10000);
  assert.equal(ledger.retry_used, 1);
  assert.equal(ledger.retry_available, 0);
  assert.deepEqual(ledger.expired_identities, ['CR2-INFRA-RETRY']);
  assert.deepEqual(ledger.retired_identities, ['CR-DESKTOP-SECOND', 'CR-MOBILE-SECOND', 'CR-DARK-SECOND']);
  assert.deepEqual(ledger.caps.approve, R3_APPROVE.caps);
  assert.deepEqual(ledger.caps['approve-without-retry'], R3_APPROVE_NO_RETRY.caps);
  assert.equal(ledger.required_rows, 22);
  assert.equal(ledger.headroom_ms, 15000);
});

test('R3 caps follow the reviewed arithmetic: preparation, four regular windows, one retry and explicit headroom', () => {
  const ledger = recovery.buildLoadRecoveryLedgerR3(r3LedgerInput());
  assert.equal(ledger.caps.approve.new_allowance_ms, 10000 + 240000 + 3 * 135000 + 240000 + 15000);
  assert.equal(ledger.caps.approve.d19_cap_ms, 2150682 + 910000);
  assert.equal(ledger.caps.approve.shared_cap_ms, 3060682 + 9 * 240000 + 3 * 60000);
  assert.equal(ledger.caps.approve.d19_launch_max, 7 + 5);
  assert.equal(ledger.caps.approve.physical_cli_max, 12 + 9);
  assert.equal(ledger.caps['approve-without-retry'].new_allowance_ms, 910000 - 240000);
  assert.equal(ledger.caps['approve-without-retry'].physical_cli_max, 20);
});

test('R3 ledger rejects any other carried input', () => {
  for (const mutate of [
    (input) => { input.charges[11] = 107342; },
    (input) => { input.charges[10] = 742; },
    (input) => { input.charges.pop(); },
    (input) => { input.charges = [...R2_CHARGES]; },
    (input) => { input.retryAvailable = 1; },
    (input) => { input.retryUsed = 0; },
    (input) => { input.spentReservations.pop(); },
    (input) => { input.spentReservations = [...R2_SPENT]; },
    (input) => { input.spentReservations.reverse(); },
    (input) => { input.physicalPlaywrightLaunches = 6; },
    (input) => { input.preparationUsedMs = 4398; }
  ]) {
    const input = r3LedgerInput(); mutate(input);
    assert.throws(() => recovery.buildLoadRecoveryLedgerR3(input), /historical|retry|reservation|launch|preparation|carried/i);
  }
});

test('R3 slots keep the identical 22-row selection under new identities, with setup separated from the browser window', () => {
  const v1 = recovery.loadRecoverySlotDefinitions();
  const r3 = recovery.loadRecoverySlotDefinitionsR3();
  assert.deepEqual(r3.map((slot) => slot.id), ['CR3-DESKTOP-MOBILE-FIRST', 'CR3-DESKTOP-SECOND', 'CR3-MOBILE-SECOND', 'CR3-DARK-SECOND', 'CR3-INFRA-RETRY']);
  assert.deepEqual(r3.map((slot) => slot.maps_from), ['CR2-DESKTOP-MOBILE-FIRST', 'CR-DESKTOP-SECOND', 'CR-MOBILE-SECOND', 'CR-DARK-SECOND', 'CR3-INFRA-RETRY']);
  const timing = ({ setup_ms, work_ms, cleanup_ms, command_ms, max_duration_ms }) => ({ setup_ms, work_ms, cleanup_ms, command_ms, max_duration_ms });
  assert.deepEqual(timing(r3[0]), { setup_ms: 60000, work_ms: 165000, cleanup_ms: 15000, command_ms: 180000, max_duration_ms: 240000 });
  for (const slot of r3.slice(1, 4)) assert.deepEqual(timing(slot), { setup_ms: 60000, work_ms: 60000, cleanup_ms: 15000, command_ms: 75000, max_duration_ms: 135000 }, slot.id);
  assert.equal(r3[4].max_duration_ms, 240000);
  assert.equal(r3[4].retry, true);
  assert.equal(r3[4].selection ?? null, null);
  assert.equal(r3[4].rows, 0);
  for (const [index, slot] of v1.entries()) {
    const strip = ({ id, maps_from, setup_ms, work_ms, cleanup_ms, command_ms, max_duration_ms, ...rest }) => rest; // eslint-disable-line no-unused-vars
    assert.deepEqual(strip(r3[index]), strip(slot), `selection, projects, argv, ports and expected CLI exit of ${slot.id} are byte-identical`);
  }
  assert.deepEqual(r3.slice(0, 4).map((slot) => slot.rows), [16, 2, 2, 2]);
  assert.equal(r3.slice(0, 4).reduce((sum, slot) => sum + slot.rows, 0), 22);
  assert.equal(r3[0].expected_cli_exit, 1);
});

function r3LineageRepo() {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-r3-lineage-')));
  gitIn(dir, 'init', '-q'); gitIn(dir, 'config', 'user.email', 'test@example.test'); gitIn(dir, 'config', 'user.name', 'test'); gitIn(dir, 'config', 'commit.gpgsign', 'false');
  const put = (relative, text) => { const target = path.join(dir, relative); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, text); return target; };
  const evidenceRel = `${PHASE_REL}/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json`;
  const logRel = 'CR2-DESKTOP-MOBILE-FIRST/attempt-01/test-log.log';
  const prepRel = 'preparation/mix_version.log';
  put(`${evidenceRel}.raw/${logRel}`, 'synthetic test log\n'); put(`${evidenceRel}.raw/${prepRel}`, 'Mix 1.19\n');
  const reference = (rel, text) => ({ path: rel, sha256: sha(text), bytes: Buffer.byteLength(text) });
  const evidence = {
    status: 'halted', attempts: [{ slot_id: 'CR2-DESKTOP-MOBILE-FIRST', charged_duration_ms: 107343, observed_outcome: 'halted', files: { test_log: reference(logRel, 'synthetic test log\n') } }],
    preparation: { duration_ms: 743, receipts: [{ name: 'mix_version', log: reference(prepRel, 'Mix 1.19\n') }] },
    limits: { prior_charge_ms: 2042596, preparation_charge_ms: 743, charged_duration_ms: 2150682, physical_playwright_cli_launches: 7, used_slots: [...R3_SPENT], retry_used: 1, retry_available: 0, infra_retry: { granted: 1, used: 0 } },
    infrastructure_retry: null, preserved_revisions: []
  };
  put(evidenceRel, `${JSON.stringify(evidence, null, 2)}\n`);
  put(`${PHASE_REL}/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json`, '{"synthetic":"r2 freeze"}\n');
  put(`${PHASE_REL}/253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`, '{"synthetic":"r2 approval"}\n');
  put(`${PHASE_REL}/253-LOAD-RECOVERY-BUDGETS-R2.md`, '# r2 budget\n');
  put('.planning/debug/253-r2-native-controls-all-fail.md', '# root cause\n');
  gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'lineage');
  const hashOf = (rel) => sha(fs.readFileSync(path.join(dir, rel)));
  const lineage = {
    evidence: { file: evidenceRel, sha256: hashOf(evidenceRel) }, freeze: { file: `${PHASE_REL}/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json`, sha256: hashOf(`${PHASE_REL}/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json`) },
    approval: { file: `${PHASE_REL}/253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`, sha256: hashOf(`${PHASE_REL}/253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`) },
    budget: { file: `${PHASE_REL}/253-LOAD-RECOVERY-BUDGETS-R2.md`, sha256: hashOf(`${PHASE_REL}/253-LOAD-RECOVERY-BUDGETS-R2.md`) }
  };
  const olderHistory = () => ({ charges: [...R2_CHARGES], artifacts: [{ path: 'older/record', sha256: 'a'.repeat(64) }], frozenBlobs: {}, control: { accepted: { toolchain: { mix: '1.19.5' } } } });
  return { dir, evidenceRel, logRel, lineage, evidence, deps: { olderHistory, lineage, skipPreservedRevisions: true }, put, clean: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

test('the R3 history reader re-hashes the R2 lineage and reads the carried 2150682 ms ledger from preserved bytes', () => {
  const r = r3LineageRepo();
  try {
    const history = recovery.readLoadHistoryR3(r.dir, r.deps);
    assert.deepEqual(history.ledger, recovery.buildLoadRecoveryLedgerR3(r3LedgerInput()));
    assert.deepEqual(history.charges, R3_CHARGES);
    assert.equal(history.terminalHalt.slot_id, 'CR2-DESKTOP-MOBILE-FIRST');
    assert.equal(history.terminalHalt.charged_ms, 107343);
    assert.equal(history.terminalHalt.preparation_ms, 743);
    assert.equal(history.terminalHalt.terminal, true);
    assert.equal(history.terminalHalt.infrastructure, false);
    assert.equal(history.terminalHalt.retryable, false);
    assert.equal(history.terminalHalt.root_cause.file, '.planning/debug/253-r2-native-controls-all-fail.md');
    assert.equal(history.terminalHalt.root_cause.sha256, sha('# root cause\n'));
    assert.deepEqual(history.terminalHalt.expired_identities, ['CR2-INFRA-RETRY']);
    const paths = history.artifacts.map((item) => item.path);
    for (const name of ['253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json', '253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json', '253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json', '253-LOAD-RECOVERY-BUDGETS-R2.md']) {
      assert.ok(paths.includes(`${PHASE_REL}/${name}`), name);
    }
    assert.ok(paths.includes(`${r.evidenceRel}.raw/${r.logRel}`), 'every R2 raw receipt is re-hashed');
    assert.ok(paths.includes('older/record'), 'the older lineage is carried');
    assert.ok(history.artifacts.every((item) => /^[0-9a-f]{64}$/.test(item.sha256)));
  } finally { r.clean(); }
});

test('the R3 history reader refuses changed R2 evidence, freeze, approval, budget or raw receipts, a missing root cause and a wrong carried ledger', () => {
  for (const [label, mutate, pattern] of [
    ['evidence', (r) => fs.appendFileSync(path.join(r.dir, r.lineage.evidence.file), ' '), /R2 evidence/i],
    ['freeze', (r) => fs.appendFileSync(path.join(r.dir, r.lineage.freeze.file), ' '), /R2 freeze/i],
    ['approval', (r) => fs.appendFileSync(path.join(r.dir, r.lineage.approval.file), ' '), /R2 approval/i],
    ['budget', (r) => fs.appendFileSync(path.join(r.dir, r.lineage.budget.file), ' '), /R2 budget/i],
    ['raw receipt', (r) => fs.appendFileSync(path.join(r.dir, `${r.evidenceRel}.raw/${r.logRel}`), 'tampered'), /raw/i],
    ['root cause missing', (r) => fs.rmSync(path.join(r.dir, '.planning/debug/253-r2-native-controls-all-fail.md')), /root.cause/i],
    ['root cause uncommitted edit', (r) => fs.appendFileSync(path.join(r.dir, '.planning/debug/253-r2-native-controls-all-fail.md'), 'edit'), /root.cause/i],
    ['wrong charge', (r) => {
      const evidence = structuredClone(r.evidence); evidence.attempts[0].charged_duration_ms = 107342;
      fs.writeFileSync(path.join(r.dir, r.lineage.evidence.file), `${JSON.stringify(evidence, null, 2)}\n`);
      r.deps.lineage = { ...r.lineage, evidence: { ...r.lineage.evidence, sha256: sha(fs.readFileSync(path.join(r.dir, r.lineage.evidence.file))) } };
    }, /2150682|107343|receipt differs/i]
  ]) {
    const r = r3LineageRepo();
    try {
      mutate(r);
      assert.throws(() => recovery.readLoadHistoryR3(r.dir, r.deps), pattern, label);
    } finally { r.clean(); }
  }
});

function r3FreezeRepo() {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-r3-freeze-')));
  gitIn(dir, 'init', '-q'); gitIn(dir, 'config', 'user.email', 'test@example.test'); gitIn(dir, 'config', 'user.name', 'test'); gitIn(dir, 'config', 'commit.gpgsign', 'false');
  fs.mkdirSync(path.join(dir, PHASE_REL), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'lineage'), { recursive: true });
  const budget = path.join(dir, PHASE_REL, '253-LOAD-RECOVERY-BUDGETS-R3.md');
  fs.writeFileSync(budget, '# budgets r3\n');
  fs.writeFileSync(path.join(dir, 'src/a.txt'), 'a\n'); fs.writeFileSync(path.join(dir, 'src/b.txt'), 'b\n'); fs.writeFileSync(path.join(dir, 'lineage/x.txt'), 'x\n');
  gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'seed');
  const history = {
    ledger: recovery.buildLoadRecoveryLedgerR3(r3LedgerInput()), charges: [...R3_CHARGES],
    terminalHalt: { slot_id: 'CR2-DESKTOP-MOBILE-FIRST', cause: 'work_deadline', terminal: true, infrastructure: false, retryable: false, charged_ms: 107343, preparation_ms: 743, root_cause: { file: '.planning/debug/253-r2-native-controls-all-fail.md', sha256: 'c'.repeat(64) } },
    artifacts: [{ path: 'lineage/x.txt', sha256: sha('x\n') }], frozenBlobs: {},
    control: { accepted: { toolchain: { mix: '1.19.5', ecto_sql: '3.13.5', phoenix_live_view: '1.1.28' } } }
  };
  const deps = {
    enforceNode: false, assertCheckout: () => {}, assertConfig: () => {}, readHistory: () => history, sourceFiles: () => ['src/a.txt', 'src/b.txt'],
    requiredSources: () => ['src/a.txt'], importClosure: () => ['src/a.txt', 'src/b.txt'], runtimeIdentity: () => ({ packages: {}, transform_sha256: {} })
  };
  return { dir, budget, history, deps, out: path.join(dir, PHASE_REL, '253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json'), clean: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

test('R3 freeze creation, check and init produce a ready ledger whose caps equal the R3 budget document', () => {
  const r = r3FreezeRepo();
  try {
    const freeze = recovery.createLoadRecoveryFreezeR3(r.out, r.dir, r.deps);
    assert.equal(freeze.schema_version, 'sigra.phase253.registration-load-recovery-freeze/v3');
    assert.equal(freeze.revision, 'r3');
    assert.equal(freeze.status, 'frozen_before_results');
    assert.equal(freeze.budget.sha256, sha(fs.readFileSync(r.budget)));
    assert.equal(freeze.budget.grants_capacity, false);
    assert.equal(freeze.ledger.required_rows, 22);
    assert.deepEqual(freeze.historical.terminal_halt, r.history.terminalHalt);
    assert.deepEqual(freeze.historical.spent_reservations, R3_SPENT);
    assert.deepEqual(freeze.ledger.caps.approve, R3_APPROVE.caps);
    assert.deepEqual(freeze.ledger.caps['approve-without-retry'], R3_APPROVE_NO_RETRY.caps);
    assert.deepEqual(freeze.ledger.slots.map((slot) => slot.id), ['CR3-DESKTOP-MOBILE-FIRST', 'CR3-DESKTOP-SECOND', 'CR3-MOBILE-SECOND', 'CR3-DARK-SECOND', 'CR3-INFRA-RETRY']);
    assert.throws(() => recovery.createLoadRecoveryFreezeR3(r.out, r.dir, r.deps), /overwrite/i);

    const head = recovery.validateLoadRecoveryFreezeR3(r.dir, JSON.parse(fs.readFileSync(r.out, 'utf8')), { deps: r.deps });
    assert.equal(head, gitIn(r.dir, 'rev-parse', 'HEAD'));

    const evidenceFile = path.join(r.dir, PHASE_REL, '253-LOAD-RECOVERY-NATIVE-EVIDENCE-R3.json');
    const evidence = recovery.initializeLoadRecoveryEvidenceR3(r.out, evidenceFile, r.dir, { validate: () => {}, readApproval: () => R3_APPROVE });
    assert.equal(evidence.schema_version, 'sigra.phase253.registration-load-recovery-evidence/v3');
    assert.equal(evidence.status, 'ready');
    assert.equal(evidence.limits.charged_duration_ms, 2150682);
    assert.equal(evidence.limits.prior_charge_ms, 2150682);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 7);
    assert.deepEqual(evidence.limits.used_slots, R3_SPENT);
    assert.equal(evidence.limits.preparation_remaining_ms, 10000);
    assert.equal(evidence.limits.max_d19_ms, R3_APPROVE.caps.d19_cap_ms);
    assert.equal(evidence.limits.max_total_ms, R3_APPROVE.caps.shared_cap_ms);
    assert.equal(evidence.limits.max_physical_playwright_cli_launches, R3_APPROVE.caps.physical_cli_max);
    assert.equal(evidence.limits.max_d19_physical_playwright_cli_launches, R3_APPROVE.caps.d19_launch_max);
    assert.deepEqual(evidence.limits.infra_retry, { granted: 1, used: 0 });
    assert.deepEqual(evidence.prior_terminal_halts, [r.history.terminalHalt]);
    assert.deepEqual(evidence.infrastructure_halts, []);
    assert.equal(fs.existsSync(`${evidenceFile}.raw`), true);
    assert.throws(() => recovery.initializeLoadRecoveryEvidenceR3(r.out, evidenceFile, r.dir, { validate: () => {}, readApproval: () => R3_APPROVE }), /overwrite/i);
  } finally { r.clean(); }
});

test('R3 freeze validation rejects a changed budget document, ledger, digest, source blob, lineage record or missing required source', () => {
  const r = r3FreezeRepo();
  try {
    const freeze = recovery.createLoadRecoveryFreezeR3(r.out, r.dir, r.deps);
    const check = (value, deps = r.deps) => recovery.validateLoadRecoveryFreezeR3(r.dir, value, { deps });
    const redigest = (value) => { value.freeze_sha256 = sha(JSON.stringify(Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'freeze_sha256')))); return value; };
    assert.throws(() => check({ schema_version: 'x' }), /malformed|digest/i);
    assert.throws(() => check({ ...structuredClone(freeze), schema_version: 'sigra.phase253.registration-load-recovery-freeze/v2' }), /malformed|digest/i);
    const ledger = structuredClone(freeze); ledger.ledger.caps.approve.shared_cap_ms += 1; redigest(ledger);
    assert.throws(() => check(ledger), /ledger/i);
    const lineage = structuredClone(freeze); lineage.historical.artifacts[0].sha256 = 'f'.repeat(64); redigest(lineage);
    assert.throws(() => check(lineage), /preserved R3 history|lineage|history changed/i);
    const blob = structuredClone(freeze); blob.source.blobs['src/a.txt'] = '0'.repeat(40); redigest(blob);
    assert.throws(() => check(blob), /identity mismatch/i);
    const missing = structuredClone(freeze); delete missing.source.blobs['src/a.txt']; redigest(missing);
    assert.throws(() => check(missing), /omits required source|identity/i);
    const omitted = structuredClone(freeze); delete omitted.source.blobs['src/b.txt']; redigest(omitted);
    assert.throws(() => check(omitted), /omits actual imported runtime source/i);
    fs.appendFileSync(r.budget, 'edited\n');
    assert.throws(() => check(freeze), /budget document differs/i);
  } finally { r.clean(); }
});

test('R3 freeze blobs pin the R2 source list plus the product, diagnostics and audit sources', () => {
  const extras = recovery.LOAD_R3_EXTRA_SOURCES;
  assert.deepEqual(extras, [
    'lib/sigra/auth.ex',
    'test/example/lib/example/accounts.ex',
    'test/example/lib/example/accounts/user.ex',
    'test/example/lib/example_web/live/registration_live.ex',
    'priv/templates/sigra.install/core/registration_live.ex',
    'test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/registration_live.ex',
    'test/example/priv/playwright/lib/reporters/failure-jsonl.mjs',
    'scripts/ci/ci-registration-control-audit.test.mjs'
  ]);
  for (const file of extras) assert.equal(fs.existsSync(path.join(root, file)), true, file);
  const list = recovery.loadR3SourceFileList(root);
  for (const file of [...recovery.loadSourceFileList(root), ...extras]) assert.ok(list.includes(file), file);
});

test('v1, R2 and R3 evidence are never accepted by another revision, and the R3 modes refuse any other path', () => {
  const r3 = loadHarnessR3();
  const r2 = loadHarnessR2();
  try {
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR3(r2.read(), r2.freeze, `${r2.evidenceFile}.raw`, 'first', sha(fs.readFileSync(r2.freezeFile))).ok, false);
    assert.equal(recovery.verifyLoadRecoveryEvidenceDataR2(r3.read(), r3.freeze, `${r3.evidenceFile}.raw`, 'first', sha(fs.readFileSync(r3.freezeFile))).ok, false);
    const script = path.join(root, 'scripts/ci/ci-registration-recovery.mjs');
    const stray = path.join(temporary, 'stray-r3-freeze.json');
    const created = spawnSync(process.execPath, [script, '--create-load-recovery-r3', '--output', stray], { encoding: 'utf8', cwd: root });
    assert.equal(created.status, 3);
    assert.match(created.stderr, /reviewed phase artifact path/);
    assert.equal(fs.existsSync(stray), false);
    for (const mode of [['--check-load-recovery-freeze', stray], ['--init-load-recovery', '--freeze', stray, '--output', path.join(temporary, 'e.json')], ['--verify-load-recovery', stray, '--stage', 'first']]) {
      const result = spawnSync(process.execPath, [script, ...mode], { encoding: 'utf8', cwd: root });
      assert.equal(result.status, 3, mode[0]);
    }
  } finally { r3.clean(); r2.clean(); }
});

test('every spent, expired and retired identity is refused by the R3 runner before any spawn', async () => {
  const h = loadHarnessR3();
  try {
    for (const id of [...R3_SPENT, 'CR2-INFRA-RETRY', 'CR-DESKTOP-SECOND', 'CR-MOBILE-SECOND', 'CR-DARK-SECOND', 'R-CONTROL-FIRST-DESKTOP']) {
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, id, h.evidenceFile, h.checkout, h.makeDeps()), /spent|expired|retired|only the/i, id);
    }
    assert.deepEqual(h.calls, []);
    assert.equal(h.read().status, 'ready');
  } finally { h.clean(); }
});

// ---- synthetic R3 runner harness: injected clocks, host probe, holders, process trees and per-test JSONL ----
function loadHarnessR3() {
  const base = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-load-r3-')));
  const checkout = path.join(base, 'checkout');
  const pwPackage = path.join(checkout, 'test/example/priv/playwright/node_modules/@playwright/test/package.json');
  fs.mkdirSync(path.dirname(pwPackage), { recursive: true });
  fs.writeFileSync(pwPackage, JSON.stringify({ version: '1.59.1' }));
  const ledger = recovery.buildLoadRecoveryLedgerR3(r3LedgerInput());
  const terminalHalt = { slot_id: 'CR2-DESKTOP-MOBILE-FIRST', cause: 'work_deadline', terminal: true, infrastructure: false, retryable: false, charged_ms: 107343, preparation_ms: 743, root_cause: { file: '.planning/debug/253-r2-native-controls-all-fail.md', sha256: 'c'.repeat(64) } };
  const freeze = {
    schema_version: 'sigra.phase253.registration-load-recovery-freeze/v3', status: 'frozen_before_results', plan: '253-60', revision: 'r3',
    source: { repository: 'synthetic', checkout_head: 'a'.repeat(40), blobs: { 'scripts/x': 'b'.repeat(40) } },
    tools: { playwright: '1.59.1', ecto_sql: '3.13.5', phoenix_live_view: '1.1.28' },
    selection: { spec: 'tests/admin-eval.spec.ts' },
    historical: { terminal_halt: terminalHalt, spent_reservations: [...R3_SPENT] },
    ledger
  };
  freeze.freeze_sha256 = sha(JSON.stringify(freeze));
  const freezeFile = path.join(base, 'freeze-r3.json'); const evidenceFile = path.join(base, 'evidence-r3.json');
  fs.writeFileSync(freezeFile, `${JSON.stringify(freeze, null, 2)}\n`);
  const writeEvidence = (approval) => {
    const evidence = {
      schema_version: 'sigra.phase253.registration-load-recovery-evidence/v3', revision: 'r3', status: 'ready', freeze_path: 'freeze-r3.json',
      freeze_sha256: sha(fs.readFileSync(freezeFile)), source: structuredClone(freeze.source), attempts: [], preparation: null, reservation: null, preserved_revisions: [],
      prior_terminal_halts: [structuredClone(terminalHalt)], infrastructure_halts: [], infrastructure_retry: null,
      approval: { decision: approval.decision, retry_granted: approval.retry_granted },
      limits: {
        prior_charge_ms: 2150682, preparation_charge_ms: 0, preparation_remaining_ms: 10000, charged_duration_ms: 2150682,
        physical_playwright_cli_launches: 7, used_slots: [...R3_SPENT], max_d19_ms: approval.caps.d19_cap_ms, max_total_ms: approval.caps.shared_cap_ms,
        max_d19_physical_playwright_cli_launches: approval.caps.d19_launch_max, max_physical_playwright_cli_launches: approval.caps.physical_cli_max,
        retry_used: 1, retry_available: 0, infra_retry: { granted: approval.retry_granted, used: 0 }
      }
    };
    fs.writeFileSync(evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
    fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  };
  writeEvidence(R3_APPROVE);
  const calls = []; const timeouts = []; const readyDeadlines = []; const envs = [];
  const zip = path.join(base, 'trace.zip'); fs.writeFileSync(zip, 'z'.repeat(64));
  const fakePsql = (counts) => { let index = 0; return () => { calls.push(['psql']); return { status: 0, stdout: `${counts[Math.min(index++, counts.length - 1)]}\n` }; }; };
  const allSlots = [...freeze.ledger.slots.slice(0, 4)];
  const markerFor = (title) => ({ 'registration stops when LiveView readiness is never released': 'phx-connected', 'registration fails when the readiness wait is deliberately broken': 'data-sigra-never-connected', 'registration retains the first forced assertion failure trace': 'toHaveURL' }[title]);
  const reportFor = (slot, runId, { failRow = false } = {}) => ({
    config: {}, errors: [],
    suites: [{
      title: 'admin-eval.spec.ts', file: 'admin-eval.spec.ts', specs: [], suites: [{
        title: 'x', file: 'admin-eval.spec.ts',
        specs: recovery.loadRequiredPairs(slot).map((pair, index) => {
          const expected = slot.project_selections.find((item) => item.project === pair.project).expected[pair.title];
          const annotations = [];
          if (pair.title !== 'render bundle: board-mg-9/populated') annotations.push({ type: 'sigra-registration-control-context', description: `${runId}:${crypto.randomUUID()}` });
          if (pair.title === 'registration detects a deliberate same-account collision') annotations.push({ type: 'sigra-registration-control-result', description: JSON.stringify({ collision_email_sha256: slot.collision_account_sha256[pair.project], first_registration_succeeded: true, duplicate_response_confirmed: true }) });
          if (pair.title === 'registration starts from a fresh database and context') annotations.push({ type: 'sigra-registration-control-result', description: JSON.stringify({ prior_collision_account_email_sha256: slot.collision_account_sha256[pair.project], fresh_database_account_created: true }) });
          const failed = expected === 'expected_failure';
          const broken = failRow && index === 0 && !failed;
          return {
            title: pair.title, file: 'admin-eval.spec.ts', ok: !failed && !broken,
            tests: [{ projectName: pair.project, expectedStatus: 'passed', status: failed || broken ? 'unexpected' : 'expected', annotations,
              results: [{ status: failed || broken ? 'failed' : 'passed', duration: 10, workerIndex: index, error: failed ? { message: `expect ${markerFor(pair.title)} failed` } : broken ? { message: 'unexpected assertion failure' } : undefined, attachments: failed ? [{ name: 'trace', path: zip }] : [], annotations: [] }] }]
          };
        })
      }]
    }]
  });
  const jsonlFor = (slot, { failRow = false, count = Infinity } = {}) => recovery.loadRequiredPairs(slot).slice(0, count).map((pair, index) => {
    const expected = slot.project_selections.find((item) => item.project === pair.project).expected[pair.title];
    const failed = expected === 'expected_failure'; const broken = failRow && index === 0 && !failed;
    const message = failed ? `Error: expect ${markerFor(pair.title)} failed\n  at spec` : broken ? 'Error: unexpected assertion failure\n  at spec' : null;
    return JSON.stringify({
      schema: 'sigra.phase253.playwright-test-end/v1', project: pair.project, title: pair.title, file: 'admin-eval.spec.ts', line: 10 + index,
      status: failed || broken ? 'failed' : 'passed', expected_status: 'passed', ok: !broken && (failed ? true : true), duration_ms: 10 + index, retry: 0,
      errors: message ? [{ message, location: { file: 'admin-eval.spec.ts', line: 10 + index, column: 1 } }] : []
    });
  });
  const awakeFor = () => ({ held: true, platform: 'darwin', argv: ['/usr/bin/caffeinate', '-i', '-s', '-m', '-w', String(process.pid)], pid: 4321, release: () => calls.push(['release-awake']) });
  const makeDeps = ({ cliExit = null, postLine = true, accountCounts = [0, 1], absenceCounts = [0], validate = () => {}, approval = R3_APPROVE,
    suspendBrowser = false, suspendFlag = false, failRow = false, probeHost = null, holderAlive = () => true, diagnosticFile = null, checkDiagnostic = null,
    setupMs = 5, setupWallExtra = 0, bootMs = 2, cliMs = 5, setupExit = 0, setupTimedOut = false, setupSuspended = false, setupError = null,
    cliTimedOut = false, killedRows = 2, noJsonl = false, errorContext = true, jsonlCount = Infinity } = {}) => {
    const absenceRun = fakePsql(absenceCounts); const accountRun = fakePsql(accountCounts);
    let monoOffset = 0n; let wallOffset = 0;
    const advance = (ms) => { monoOffset += BigInt(Math.round(ms * 1e6)); wallOffset += ms; };
    return {
      validate, enforcePaths: false, enforceNode: false, skipPreservation: true, diagnosticFile,
      monotonicNs: () => process.hrtime.bigint() + monoOffset, wallMs: () => Date.now() + wallOffset,
      readApproval: () => approval, holderAlive,
      checkDiagnostic: checkDiagnostic ?? ((_root, file) => { if (!file) throw new Error('infrastructure retry requires a committed diagnostic'); return { file, sha256: 'd'.repeat(64) }; }),
      probeHost: probeHost ?? (async () => { calls.push(['probe-host']); return { awake: awakeFor(), host_awake: { holder_pid: 4321, ac_power: true, assertions_sha256: 'e'.repeat(64), checked_at: '2026-10-14T08:00:00.000Z' } }; }),
      portAvailable: async () => true, waitReady: async (_app, _url, deadline) => { readyDeadlines.push(deadline); advance(bootMs); return 200; }, stopApp: async () => {},
      spawnApp: (program, args, options) => { calls.push(['app', program, ...args]); if (postLine) fs.writeSync(options.stdio[1], 'POST /users/log_in\n'); return { pid: 4242, exitCode: null, signalCode: null }; },
      runTree: async (program, args, cwd, env, log, timeoutMs) => {
        calls.push(['tree', program, ...args]); timeouts.push([path.basename(program), args[0], timeoutMs]);
        fs.writeFileSync(log, `${path.basename(program)} ${args[0]} ok\n`);
        if (program.endsWith('/playwright')) {
          envs.push(env);
          const given = args.slice(2, -1);
          const slot = allSlots.find((item) => JSON.stringify(item.argv) === JSON.stringify(given));
          assert.equal(env.SIGRA_REGISTRATION_CONTROL_STAGE, slot.control_stage);
          assert.equal(args.filter((arg) => /^(-g|--grep)/.test(arg)).length, 0);
          assert.ok(env.SIGRA_PLAYWRIGHT_FAILURE_JSONL?.startsWith(path.dirname(env.SIGRA_PLAYWRIGHT_JSON)), 'the per-test JSONL lives under the attempt temp root');
          if (!noJsonl) fs.writeFileSync(env.SIGRA_PLAYWRIGHT_FAILURE_JSONL, `${jsonlFor(slot, { failRow, count: cliTimedOut || suspendBrowser ? killedRows : jsonlCount }).join('\n')}\n`);
          const outputDir = args.find((arg) => arg.startsWith('--output=')).slice('--output='.length);
          if (errorContext) {
            fs.mkdirSync(path.join(outputDir, 'case-one'), { recursive: true });
            fs.writeFileSync(path.join(outputDir, 'case-one', 'error-context.md'), '# Page snapshot\n- heading "Register"\n');
          }
          advance(cliMs);
          if (suspendBrowser) return { pid: 777, exit_code: null, signal: 'SIGTERM', error: null, timed_out: true, suspended: true, duration_ms: cliMs, wall_duration_ms: cliMs, group_signals: ['SIGTERM'], descendants_reaped: true };
          if (cliTimedOut) return { pid: 777, exit_code: null, signal: 'SIGTERM', error: null, timed_out: true, suspended: false, duration_ms: cliMs, wall_duration_ms: cliMs, group_signals: ['SIGTERM'], descendants_reaped: true };
          fs.writeFileSync(env.SIGRA_PLAYWRIGHT_JSON, JSON.stringify(reportFor(slot, env.SIGRA_CONTROL_RUN_ID, { failRow })));
          return { pid: 777, exit_code: cliExit ?? slot.expected_cli_exit, signal: null, error: null, timed_out: false, suspended: suspendFlag, duration_ms: cliMs, group_signals: [], descendants_reaped: true };
        }
        if (program === 'mix' && args[0] === 'ecto.setup') {
          advance(setupMs); wallOffset += setupWallExtra;
          return { pid: 1, exit_code: setupError ? null : setupExit, signal: null, error: setupError, timed_out: setupTimedOut, suspended: setupSuspended, duration_ms: setupMs, wall_duration_ms: setupMs, group_signals: [], descendants_reaped: true };
        }
        advance(1);
        return { pid: 1, exit_code: 0, signal: null, error: null, timed_out: false, duration_ms: 1, group_signals: [], descendants_reaped: true };
      },
      captureAbsence: (options) => recovery.captureOwnedDatabaseAbsence({ ...options, run: absenceRun }),
      captureAccount: (options) => recovery.captureOwnedAccountCount({ ...options, run: accountRun }),
      sanitizeTrace: (source, destination) => { fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL); return { entries: 3, navigation: true, submission: true }; }
    };
  };
  return { base, checkout, freeze, freezeFile, evidenceFile, calls, timeouts, readyDeadlines, envs, makeDeps, writeEvidence, read: () => JSON.parse(fs.readFileSync(evidenceFile, 'utf8')), clean: () => fs.rmSync(base, { recursive: true, force: true }) };
}

// ---- Phase 253 plan 60 task 2: R3 setup-phase run path with preserved per-test diagnostics ----
const R3_FIRST = 'CR3-DESKTOP-MOBILE-FIRST';
const r3Verify = (h, evidence, stage = 'first') => recovery.verifyLoadRecoveryEvidenceDataR3(evidence, h.freeze, `${h.evidenceFile}.raw`, stage, sha(fs.readFileSync(h.freezeFile)));

test('a synthetic R3 first slot runs setup under its own 60000 ms deadline and leaves the full 165000 ms work deadline intact', async () => {
  const h = loadHarnessR3();
  try {
    const result = await recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps({ setupMs: 30000, bootMs: 2000, cliMs: 40000 }));
    assert.equal(result.rows, 16);
    const [setupCall, , playwrightCall] = [h.timeouts.find((t) => t[1] === 'ecto.setup'), null, h.timeouts.find((t) => t[0] === 'playwright')];
    assert.ok(setupCall[2] <= 60000 && setupCall[2] > 59900, `setup is bounded by its own 60000 ms, got ${setupCall[2]}`);
    assert.ok(playwrightCall[2] <= 163000 && playwrightCall[2] > 162800, `the 30000 ms setup did not shrink the browser window: ${playwrightCall[2]} remains after a 2000 ms boot`);
    const evidence = h.read();
    const attempt = evidence.attempts[0];
    assert.equal(evidence.schema_version, 'sigra.phase253.registration-load-recovery-evidence/v3');
    assert.equal(evidence.status, 'first_complete');
    assert.equal(attempt.slot_id, R3_FIRST);
    assert.deepEqual(attempt.stage_deadlines, { setup_ms: 60000, command_ms: 180000, work_ms: 165000, cleanup_ms: 15000, cleanup_reserved: true });
    assert.ok(attempt.setup_charge_ms >= 30000 && attempt.setup_charge_ms < 30100, `setup charge ${attempt.setup_charge_ms}`);
    assert.equal(attempt.charged_duration_ms, attempt.setup_charge_ms + attempt.command_charge_ms);
    assert.ok(attempt.command_charge_ms >= 42000 && attempt.command_charge_ms < 42200, `command charge ${attempt.command_charge_ms}`);
    assert.equal(evidence.limits.charged_duration_ms, 2150682 + attempt.charged_duration_ms);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 8);
    assert.deepEqual(evidence.limits.used_slots, [...R3_SPENT, R3_FIRST]);
    assert.ok(h.readyDeadlines[0] > 0);
    assert.deepEqual(r3Verify(h, evidence).errors, []);
    assert.equal(r3Verify(h, evidence, 'complete').ok, false);
  } finally { h.clean(); }
});

test('the slot charge is setup max(monotonic, wall) plus command max(monotonic, wall), each judged on its own clocks', async () => {
  const h = loadHarnessR3();
  try {
    await recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps({ setupMs: 20000, setupWallExtra: 3000, cliMs: 10000 }));
    const attempt = h.read().attempts[0];
    const setupMax = Math.max(attempt.setup_timing.execution_ms, attempt.setup_timing.wall_ms);
    const commandMax = Math.max(attempt.command_timing.execution_ms, attempt.command_timing.wall_ms);
    assert.ok(attempt.setup_timing.wall_ms - attempt.setup_timing.execution_ms >= 2999, 'wall ran ahead of the monotonic clock during setup');
    assert.equal(attempt.setup_charge_ms, setupMax);
    assert.equal(attempt.command_charge_ms, commandMax);
    assert.equal(attempt.charged_duration_ms, setupMax + commandMax);
    assert.ok(attempt.charged_duration_ms >= Math.max(attempt.execution_duration_ms, attempt.wall_duration_ms), 'never below the larger whole-window clock');
    assert.ok(attempt.charged_duration_ms <= 240000);
  } finally { h.clean(); }
});

test('a setup failure or a setup overrun halts before any CLI launch, stays charged and still drops the owned database', async () => {
  for (const [label, options, pattern] of [
    ['non-zero exit', { setupExit: 1, setupMs: 4000 }, /setup failed/i],
    ['deadline kill', { setupTimedOut: true, setupExit: 0, setupMs: 61000 }, /setup failed|setup.*deadline/i],
    ['overrun without a kill', { setupMs: 61000 }, /setup.*60000|overran/i]
  ]) {
    const h = loadHarnessR3();
    try {
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps(options)), pattern, label);
      const evidence = h.read();
      const attempt = evidence.attempts[0];
      assert.equal(evidence.status, 'halted', label);
      assert.equal(attempt.playwright_cli.launched, false, label);
      assert.equal(h.calls.some((call) => call[0] === 'tree' && call[1].endsWith('/playwright')), false, `${label}: no CLI`);
      assert.equal(h.calls.some((call) => call[0] === 'app'), false, `${label}: no app boot`);
      assert.equal(h.calls.some((call) => call[0] === 'tree' && call[2] === 'ecto.drop'), true, `${label}: owned database dropped`);
      assert.equal(evidence.limits.physical_playwright_cli_launches, 7, `${label}: launches unchanged`);
      assert.ok(attempt.setup_charge_ms >= options.setupMs, `${label}: setup is charged`);
      assert.equal(attempt.charged_duration_ms, attempt.setup_charge_ms + attempt.command_charge_ms, label);
      assert.equal(evidence.limits.charged_duration_ms, 2150682 + attempt.charged_duration_ms, label);
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-DESKTOP-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|reserved|halted/i, label);
    } finally { h.clean(); }
  }
});

test('the CLI env carries the per-test JSONL path and the preserved diagnostics are hashed receipts on a pass', async () => {
  const h = loadHarnessR3();
  try {
    await recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps());
    assert.match(h.envs[0].SIGRA_PLAYWRIGHT_FAILURE_JSONL, /tests\.jsonl$/);
    const attempt = h.read().attempts[0];
    const rawDir = `${h.evidenceFile}.raw`;
    assert.equal(attempt.diagnostics.jsonl.path, path.join(R3_FIRST, 'attempt-01', 'diagnostics', 'tests.jsonl'));
    assert.equal(attempt.diagnostics.per_test.length, 16);
    assert.equal(attempt.diagnostics.error_contexts.length, 1);
    assert.equal(sha(fs.readFileSync(path.join(rawDir, attempt.diagnostics.jsonl.path))), attempt.diagnostics.jsonl.sha256);
    assert.deepEqual(recovery.verifyAttemptDiagnosticsR3(attempt, rawDir), { ok: true, errors: [] });
    assert.equal(attempt.per_test_rows.length, 16);
    assert.deepEqual(Object.keys(attempt.per_test_rows[0]).sort(), ['duration_ms', 'first_error_line', 'project', 'status', 'title']);
    assert.equal(fs.existsSync(h.envs[0].SIGRA_PLAYWRIGHT_FAILURE_JSONL), false, 'the temp copy is gone, the receipt remains');
  } finally { h.clean(); }
});

test('diagnostics are preserved on an assertion failure and a deadline kill, and the verifier needs them', async () => {
  const failed = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(failed.freezeFile, R3_FIRST, failed.evidenceFile, failed.checkout, failed.makeDeps({ failRow: true })));
    const attempt = failed.read().attempts[0];
    assert.equal(attempt.diagnostics.per_test.length, 16);
    assert.equal(attempt.assertion_failure_observed, true);
    assert.ok(attempt.per_test_rows.some((row) => /unexpected assertion failure/.test(row.first_error_line ?? '')), 'the failing row names its first error line');
    const rawDir = `${failed.evidenceFile}.raw`;
    assert.deepEqual(recovery.verifyAttemptDiagnosticsR3(attempt, rawDir), { ok: true, errors: [] });
  } finally { failed.clean(); }

  const killed = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(killed.freezeFile, R3_FIRST, killed.evidenceFile, killed.checkout, killed.makeDeps({ cliTimedOut: true, killedRows: 2 })), /work deadline/i);
    const evidence = killed.read();
    const attempt = evidence.attempts[0];
    assert.equal(evidence.status, 'halted');
    assert.equal(attempt.playwright_cli.launched, true);
    assert.equal(attempt.diagnostics.per_test.length, 2, 'both rows that finished before the kill are preserved');
    const rawDir = `${killed.evidenceFile}.raw`;
    const lines = fs.readFileSync(path.join(rawDir, attempt.diagnostics.jsonl.path), 'utf8').trim().split('\n');
    assert.equal(lines.length, 2);
    assert.equal(attempt.per_test_rows.length, 2);
    assert.equal(evidence.stop_record.slot_id, R3_FIRST);
    assert.equal(evidence.stop_record.per_test_rows.length, 2);
  } finally { killed.clean(); }

  const none = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(none.freezeFile, R3_FIRST, none.evidenceFile, none.checkout, none.makeDeps({ noJsonl: true })), /per-test JSONL/i);
    assert.equal(none.read().status, 'halted', 'an attempt that launched the CLI without a preserved JSONL is rejected');
  } finally { none.clean(); }
});

test('R3 runs all four regular slots once in order and verifies the complete 22-row proof', async () => {
  const h = loadHarnessR3();
  try {
    for (const id of ['CR3-DESKTOP-MOBILE-FIRST', 'CR3-DESKTOP-SECOND', 'CR3-MOBILE-SECOND', 'CR3-DARK-SECOND']) {
      await recovery.runLoadRecoverySlotR3(h.freezeFile, id, h.evidenceFile, h.checkout, h.makeDeps());
    }
    const evidence = h.read();
    assert.equal(evidence.status, 'complete');
    assert.equal(evidence.attempts.reduce((sum, item) => sum + item.lifecycle.rows, 0), 22);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 11);
    assert.deepEqual(r3Verify(h, evidence, 'complete').errors, []);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-DARK-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|consumed|already|order/i);
  } finally { h.clean(); }
});

test('R3 refuses out-of-order slots, a reopened original retry, a counter reset, caps drift and a slot outside the frozen table', async () => {
  for (const [mutate, pattern, slot] of [
    [() => {}, /frozen order/i, 'CR3-MOBILE-SECOND'],
    [(e) => { e.limits.retry_available = 1; }, /retry/i, R3_FIRST],
    [(e) => { e.limits.charged_duration_ms = 0; e.limits.prior_charge_ms = 0; }, /reset/i, R3_FIRST],
    [(e) => { e.limits.max_d19_ms += 1; }, /approval caps differ/i, R3_FIRST],
    [() => {}, /only the/i, 'CR3-UNKNOWN']
  ]) {
    const h = loadHarnessR3();
    try {
      const evidence = h.read(); mutate(evidence);
      fs.writeFileSync(h.evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, slot, h.evidenceFile, h.checkout, h.makeDeps()), pattern);
      assert.deepEqual(h.calls, [], String(pattern));
    } finally { h.clean(); }
  }
});

test('R3 preparation is a bounded 10000 ms toolchain probe routed by the R3 evidence only', async () => {
  const h = loadHarnessR3();
  try {
    const run = async (override = {}) => recovery.prepareLoadRecoveryR3(h.freezeFile, h.evidenceFile, h.checkout, { validate: () => {}, readApproval: () => R3_APPROVE, skipPreservation: true,
      runTree: async (program, args, cwd, env, log, timeoutMs) => { h.timeouts.push([program, args[0], timeoutMs]); fs.writeFileSync(log, `${program} ${args[0]}\n`); return { exit_code: 0, duration_ms: 2, timed_out: false, ...override }; } });
    const result = await run();
    assert.equal(result.status, 'ready');
    const evidence = h.read();
    assert.equal(evidence.preparation.receipts.length, 2);
    assert.ok(h.timeouts.every((entry) => entry[2] <= 10000 && entry[2] > 9000));
    assert.equal(evidence.limits.preparation_charge_ms, evidence.preparation.duration_ms);
    assert.equal(evidence.limits.charged_duration_ms, 2150682 + evidence.preparation.duration_ms);
    await assert.rejects(run, /only available once/i);
  } finally { h.clean(); }
  const failing = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.prepareLoadRecoveryR3(failing.freezeFile, failing.evidenceFile, failing.checkout, { validate: () => {}, readApproval: () => R3_APPROVE, skipPreservation: true,
      runTree: async (program, args, cwd, env, log) => { fs.writeFileSync(log, 'x'); return { exit_code: 1, duration_ms: 1, timed_out: false }; } }), /failed/i);
    assert.equal(failing.read().status, 'halted');
  } finally { failing.clean(); }
});

test('the R3 run refuses any freeze or evidence outside the reviewed R3 paths', async () => {
  const h = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, { ...h.makeDeps(), enforcePaths: true }), /reviewed R3 freeze/i);
    assert.deepEqual(h.calls, []);
    const script = path.join(root, 'scripts/ci/ci-registration-recovery.mjs');
    for (const mode of [['--prepare-load-recovery', '--freeze', h.freezeFile, '--output', h.evidenceFile], ['--run-load-recovery', h.freezeFile, '--slot', R3_FIRST, '--output', h.evidenceFile]]) {
      const result = spawnSync(process.execPath, [script, ...mode], { encoding: 'utf8', cwd: root });
      assert.equal(result.status, 3, mode[0]);
    }
  } finally { h.clean(); }
});

// ---- Phase 253 plan 60 task 3: R3 budget-approval binding, host probe, retry eligibility, halt rows and terminal evidence ----
function approvalRepoR3() {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-approval-r3-')));
  gitIn(dir, 'init', '-q'); gitIn(dir, 'config', 'user.email', 'test@example.test'); gitIn(dir, 'config', 'user.name', 'test'); gitIn(dir, 'config', 'commit.gpgsign', 'false');
  fs.mkdirSync(path.join(dir, PHASE_REL), { recursive: true });
  const budget = path.join(dir, PHASE_REL, '253-LOAD-RECOVERY-BUDGETS-R3.md');
  fs.writeFileSync(budget, '# budgets r3\n');
  const freezeFile = path.join(dir, PHASE_REL, '253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json');
  const freeze = { schema_version: 'sigra.phase253.registration-load-recovery-freeze/v3', budget: { file: `${PHASE_REL}/253-LOAD-RECOVERY-BUDGETS-R3.md`, sha256: sha(fs.readFileSync(budget)) } };
  fs.writeFileSync(freezeFile, `${JSON.stringify(freeze)}\n`);
  gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'seed');
  return { dir, budget, freezeFile, freeze, approval: path.join(dir, PHASE_REL, '253-LOAD-RECOVERY-BUDGET-APPROVAL-R3.json'), clean: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

test('recording an R3 approval is exclusive, writes the v2 record bound to the R3 budget and freeze, and anything but approve writes nothing', () => {
  const r = approvalRepoR3();
  try {
    for (const decision of ['reject', 'maybe', undefined]) {
      assert.throws(() => recovery.recordBudgetApprovalR3({ decision, budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'no' }, r.dir, { enforcePaths: false }), /decision|grants no capacity/i);
      assert.equal(fs.existsSync(r.approval), false);
    }
    assert.throws(() => recovery.recordBudgetApprovalR3({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: '  ' }, r.dir, { enforcePaths: false }), /decision text/i);
    const record = recovery.recordBudgetApprovalR3({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'approve exactly as written' }, r.dir, { enforcePaths: false, now: () => '2026-10-14T09:00:00.000Z' });
    const onDisk = JSON.parse(fs.readFileSync(r.approval, 'utf8'));
    assert.deepEqual(onDisk, record);
    assert.equal(onDisk.schema_version, 'sigra.phase253.load-recovery-budget-approval/v2');
    assert.equal(onDisk.decision, 'approve');
    assert.equal(onDisk.decision_text, 'approve exactly as written');
    assert.equal(onDisk.budget_sha256, sha(fs.readFileSync(r.budget)));
    assert.equal(onDisk.freeze_sha256, sha(fs.readFileSync(r.freezeFile)));
    assert.deepEqual(onDisk.caps, R3_APPROVE.caps);
    assert.equal(onDisk.retry_granted, 1);
    assert.equal(onDisk.recorded_at, '2026-10-14T09:00:00.000Z');
    assert.throws(() => recovery.recordBudgetApprovalR3({ decision: 'approve-without-retry', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'again' }, r.dir, { enforcePaths: false }), /EEXIST|exist|exclusive/i);
    assert.equal(JSON.parse(fs.readFileSync(r.approval, 'utf8')).decision, 'approve', 'the first record is never overwritten');
  } finally { r.clean(); }
});

test('an R3 approve-without-retry grants no retry, a budget mismatch refuses to record, and the R3 recorder pins its reviewed paths', () => {
  const r = approvalRepoR3();
  try {
    const record = recovery.recordBudgetApprovalR3({ decision: 'approve-without-retry', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'no retry' }, r.dir, { enforcePaths: false });
    assert.equal(record.retry_granted, 0);
    assert.deepEqual(record.caps, R3_APPROVE_NO_RETRY.caps);
    fs.rmSync(r.approval);
    assert.throws(() => recovery.recordBudgetApprovalR3({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: path.join(r.dir, 'elsewhere.json'), decisionText: 'x' }, r.dir), /reviewed R3 budget, freeze and approval paths/i);
    fs.writeFileSync(r.budget, '# budgets r3 (edited)\n');
    assert.throws(() => recovery.recordBudgetApprovalR3({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'x' }, r.dir, { enforcePaths: false }), /budget/i);
    assert.equal(fs.existsSync(r.approval), false);
  } finally { r.clean(); }
});

test('the approval recorder CLI routes the R3 freeze path and still refuses a reject decision without writing', () => {
  const script = path.join(root, 'scripts/ci/ci-registration-recovery.mjs');
  const out = path.join(root, PHASE_REL, '253-LOAD-RECOVERY-BUDGET-APPROVAL-R3.json');
  // Jon's R3 approval is now committed (253-63); a reject must still never write or alter it.
  const before = fs.existsSync(out) ? fs.readFileSync(out, 'utf8') : null;
  const result = spawnSync(process.execPath, [script, '--record-budget-approval', '--decision', 'reject', '--budget', path.join(root, PHASE_REL, '253-LOAD-RECOVERY-BUDGETS-R3.md'), '--freeze', path.join(root, PHASE_REL, '253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json'), '--output', out, '--decision-text', 'no'], { encoding: 'utf8', cwd: root });
  assert.equal(result.status, 3);
  assert.match(result.stderr, /decision/i);
  assert.equal(fs.existsSync(out) ? fs.readFileSync(out, 'utf8') : null, before);
});

test('an R3 run needs a committed v2 approval bound to the R3 budget and freeze, and the R2 approval is refused', () => {
  const r = approvalRepoR3();
  try {
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /absent|missing/i);
    recovery.recordBudgetApprovalR3({ decision: 'approve', budgetFile: r.budget, freezeFile: r.freezeFile, outputFile: r.approval, decisionText: 'ok' }, r.dir, { enforcePaths: false });
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /committed/i);
    gitIn(r.dir, 'add', '-A'); gitIn(r.dir, 'commit', '-q', '-m', 'approval');
    const good = recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze);
    assert.equal(good.decision, 'approve');
    assert.equal(good.retry_granted, 1);
    fs.writeFileSync(r.approval, `${fs.readFileSync(r.approval, 'utf8')} `);
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /committed|differs/i);
    gitIn(r.dir, 'checkout', '--', '.');
    const edited = JSON.parse(fs.readFileSync(r.approval, 'utf8'));
    const commit = (value, message) => { fs.writeFileSync(r.approval, `${JSON.stringify(value, null, 2)}\n`); gitIn(r.dir, 'add', '-A'); gitIn(r.dir, 'commit', '-q', '-m', message); };
    commit({ ...edited, budget_sha256: 'f'.repeat(64) }, 'bad budget');
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /budget/i);
    commit({ ...edited, freeze_sha256: 'f'.repeat(64) }, 'bad freeze');
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /freeze/i);
    commit({ ...edited, caps: { ...edited.caps, d19_cap_ms: edited.caps.d19_cap_ms + 1 } }, 'bad caps');
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /caps/i);
    commit({ ...edited, schema_version: 'sigra.phase253.load-recovery-budget-approval/v1', caps: { new_allowance_ms: 645000, d19_cap_ms: 2687596, d19_launch_max: 11, shared_cap_ms: 5027596, physical_cli_max: 20 } }, 'r2 approval shape');
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /malformed|unrecognised/i, 'the R2 approval can never unlock R3');
    commit({ ...edited, decision: 'reject' }, 'reject');
    assert.throws(() => recovery.readCommittedApprovalR3(r.dir, r.freezeFile, r.freeze), /malformed|unrecognised/i);
  } finally { r.clean(); }
});

test('an R3 run refuses before the predebit when approval is missing, unwired or the host proof fails', async () => {
  for (const [label, overrides, pattern] of [
    ['approval absent', { readApproval: () => { throw new Error('R3 budget approval record is absent'); } }, /approval/i],
    ['host proof fails', { probeHost: async () => { throw new Error('host is not on AC power'); } }, /AC power/i]
  ]) {
    const h = loadHarnessR3();
    try {
      const before = h.read();
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, { ...h.makeDeps(), ...overrides }), pattern, label);
      assert.deepEqual(h.read(), before, `${label}: no reservation, used slot or charge`);
      assert.equal(h.calls.filter((call) => call[0] === 'tree' || call[0] === 'app').length, 0, label);
    } finally { h.clean(); }
  }
  const h = loadHarnessR3();
  try {
    const { readApproval: _unused, ...withoutApproval } = h.makeDeps(); // eslint-disable-line no-unused-vars
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, withoutApproval), /approval/i, 'the default reader demands a committed R3 approval');
    assert.deepEqual(h.calls, []);
  } finally { h.clean(); }
});

test('the approval decides the ceilings that the R3 run enforces', async () => {
  const mismatch = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(mismatch.freezeFile, R3_FIRST, mismatch.evidenceFile, mismatch.checkout, mismatch.makeDeps({ approval: R3_APPROVE_NO_RETRY })), /approval caps differ/i);
    assert.deepEqual(mismatch.calls, []);
  } finally { mismatch.clean(); }
  const noRetry = loadHarnessR3();
  try {
    noRetry.writeEvidence(R3_APPROVE_NO_RETRY);
    const result = await recovery.runLoadRecoverySlotR3(noRetry.freezeFile, R3_FIRST, noRetry.evidenceFile, noRetry.checkout, noRetry.makeDeps({ approval: R3_APPROVE_NO_RETRY }));
    assert.equal(result.rows, 16);
    assert.equal(noRetry.read().limits.max_total_ms, 5160682);
  } finally { noRetry.clean(); }
  const tight = loadHarnessR3();
  try {
    const evidence = tight.read(); evidence.limits.charged_duration_ms += 20000;
    fs.writeFileSync(tight.evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(tight.freezeFile, R3_FIRST, tight.evidenceFile, tight.checkout, tight.makeDeps()), /do not fit approved limits/i);
    assert.deepEqual(tight.calls, []);
  } finally { tight.clean(); }
});

test('the R3 verifier rejects a receipt without its host proof, a suspended host, a wrong charge sum and missing diagnostics', async () => {
  const h = loadHarnessR3();
  try {
    await recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps());
    const evidence = h.read();
    assert.deepEqual(evidence.attempts[0].host_awake, { holder_pid: 4321, ac_power: true, assertions_sha256: 'e'.repeat(64), checked_at: '2026-10-14T08:00:00.000Z' });
    const verify = (mutate) => { const copy = structuredClone(evidence); mutate(copy.attempts[0]); return r3Verify(h, copy); };
    assert.equal(verify(() => {}).ok, true);
    for (const [name, mutate, pattern] of [
      ['no host_awake', (a) => { delete a.host_awake; }, /host_awake/],
      ['not on AC', (a) => { a.host_awake.ac_power = false; }, /host_awake/],
      ['no assertion hash', (a) => { a.host_awake.assertions_sha256 = 'x'; }, /host_awake/],
      ['suspended true', (a) => { a.host.suspended = true; }, /suspended/],
      ['suspension detected', (a) => { a.host.suspension_detected = true; }, /suspension/],
      ['charge below the larger clock', (a) => { a.wall_duration_ms = a.charged_duration_ms + 10; }, /charge/],
      ['charge is not the sum', (a) => { a.charged_duration_ms += 1; }, /setup charge plus the command charge/],
      ['setup charge forged', (a) => { a.setup_charge_ms += 1; a.charged_duration_ms += 1; }, /setup charge is not max/],
      ['command window forged', (a) => { a.command_timing.execution_ms += 1; }, /command/],
      ['deadlines forged', (a) => { a.stage_deadlines.work_ms = 105000; }, /stage deadlines/],
      ['no diagnostics', (a) => { a.diagnostics = null; }, /per-test JSONL/],
      ['diagnostics without jsonl', (a) => { a.diagnostics.jsonl = null; }, /per-test JSONL/],
      ['forged per-test rows', (a) => { a.per_test_rows[0].status = 'forged'; }, /per_test_rows/]
    ]) {
      const verdict = verify(mutate);
      assert.equal(verdict.ok, false, name);
      assert.match(verdict.errors.join(';'), pattern, name);
    }
    const tampered = structuredClone(evidence);
    const jsonl = path.join(`${h.evidenceFile}.raw`, tampered.attempts[0].diagnostics.jsonl.path);
    const original = fs.readFileSync(jsonl);
    fs.appendFileSync(jsonl, ' ');
    assert.match(r3Verify(h, tampered).errors.join(';'), /sha256/i, 'a changed JSONL no longer matches its receipt');
    fs.writeFileSync(jsonl, original);
  } finally { h.clean(); }
});

test('a host sleep halts as halted_infrastructure with per-test rows, stays charged and counted, and blocks every regular slot until the retry', async () => {
  const h = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps({ suspendBrowser: true })), /work deadline|suspension/i);
    const evidence = h.read();
    assert.equal(evidence.status, 'halted_infrastructure');
    assert.equal(evidence.attempts[0].observed_outcome, 'halted_infrastructure');
    assert.equal(evidence.infrastructure_retry.eligible, true);
    assert.equal(evidence.infrastructure_retry.halted_slot, R3_FIRST);
    assert.equal(evidence.infrastructure_retry.cause, 'host_sleep');
    assert.equal(evidence.infrastructure_halts.length, 1);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 8);
    assert.equal(evidence.limits.charged_duration_ms, 2150682 + evidence.attempts[0].charged_duration_ms);
    assert.equal(evidence.stop_record.per_test_rows.length, 2);
    assert.deepEqual(Object.keys(evidence.stop_record.per_test_rows[0]).sort(), ['duration_ms', 'first_error_line', 'project', 'status', 'title']);
    assert.equal(r3Verify(h, evidence).ok, false);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-DESKTOP-SECOND', h.evidenceFile, h.checkout, h.makeDeps()), /terminal|reserved|halted/i);
  } finally { h.clean(); }
});

test('CR3-INFRA-RETRY runs once, needs a committed diagnostic and a granted retry, and re-runs the identical frozen selection', async () => {
  const h = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps()), /halted_infrastructure|infrastructure/i);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps({ suspendBrowser: true })));
    const callsBefore = h.calls.length;
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps()), /diagnostic/i);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json', checkDiagnostic: () => { throw new Error('diagnostic is not committed'); } })), /not committed/i);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json', approval: R3_APPROVE_NO_RETRY })), /retry|caps/i);
    assert.equal(h.calls.length, callsBefore, 'every refusal happens before any spawn');

    const result = await recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json' }));
    assert.equal(result.rows, 16);
    const evidence = h.read();
    assert.equal(evidence.status, 'first_complete');
    assert.equal(evidence.attempts.length, 2);
    assert.equal(evidence.attempts[1].slot_id, 'CR3-INFRA-RETRY');
    assert.equal(evidence.attempts[1].retry_of, R3_FIRST);
    assert.deepEqual(evidence.attempts[1].argv, evidence.attempts[0].argv);
    assert.deepEqual(evidence.attempts[1].diagnostics.per_test.length, 16);
    assert.equal(evidence.infrastructure_retry.used, true);
    assert.deepEqual(evidence.infrastructure_retry.diagnostic, { file: 'diag.json', sha256: 'd'.repeat(64) });
    assert.equal(evidence.limits.infra_retry.used, 1);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 9);
    assert.deepEqual(evidence.limits.used_slots, [...R3_SPENT, R3_FIRST, 'CR3-INFRA-RETRY']);
    assert.equal(evidence.limits.charged_duration_ms, 2150682 + evidence.attempts[0].charged_duration_ms + evidence.attempts[1].charged_duration_ms);
    const verdict = r3Verify(h, evidence);
    assert.deepEqual(verdict.errors, [], 'the original stays in attempts and the pair counts as one slot outcome');

    const drifted = structuredClone(evidence); drifted.attempts[1].argv = drifted.attempts[1].argv.filter((arg) => arg !== '--project=admin-eval-dark');
    assert.equal(r3Verify(h, drifted).ok, false, 'a retry with another selection is rejected');
    const noDiagnostic = structuredClone(evidence); noDiagnostic.infrastructure_retry.diagnostic = null;
    assert.equal(r3Verify(h, noDiagnostic).ok, false, 'a retry without a recorded diagnostic is rejected');
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json' })), /halted_infrastructure|infrastructure|already/i, 'the retry is usable once');
  } finally { h.clean(); }
});

test('the R3 retry is never available after an assertion failure, a setup failure without suspension, a non-suspension overrun, a second infrastructure halt or approve-without-retry', async () => {
  const cases = [
    ['assertion failure', { cliExit: 0 }],
    ['assertion row failure with a suspension flag', { suspendFlag: true, failRow: true }],
    ['setup failure without suspension', { setupExit: 1 }],
    ['non-suspension setup overrun', { setupMs: 61000 }],
    ['non-suspension deadline kill', { cliTimedOut: true }]
  ];
  for (const [label, options] of cases) {
    const h = loadHarnessR3();
    try {
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, R3_FIRST, h.evidenceFile, h.checkout, h.makeDeps(options)), undefined, label);
      assert.equal(h.read().status, 'halted', label);
      await assert.rejects(() => recovery.runLoadRecoverySlotR3(h.freezeFile, 'CR3-INFRA-RETRY', h.evidenceFile, h.checkout, h.makeDeps({ diagnosticFile: 'diag.json' })), /halted_infrastructure|infrastructure/i, label);
    } finally { h.clean(); }
  }

  const second = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(second.freezeFile, R3_FIRST, second.evidenceFile, second.checkout, second.makeDeps({ suspendBrowser: true })));
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(second.freezeFile, 'CR3-INFRA-RETRY', second.evidenceFile, second.checkout, second.makeDeps({ diagnosticFile: 'diag.json', suspendBrowser: true })));
    const evidence = second.read();
    assert.equal(evidence.status, 'halted', 'a second infrastructure halt is terminal');
    assert.equal(evidence.limits.infra_retry.used, 1);
    assert.equal(evidence.attempts.length, 2);
    assert.equal(evidence.stop_record.slot_id, 'CR3-INFRA-RETRY');
    assert.equal(evidence.stop_record.per_test_rows.length, 2);
  } finally { second.clean(); }

  const withoutRetry = loadHarnessR3();
  try {
    withoutRetry.writeEvidence(R3_APPROVE_NO_RETRY);
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(withoutRetry.freezeFile, R3_FIRST, withoutRetry.evidenceFile, withoutRetry.checkout, withoutRetry.makeDeps({ approval: R3_APPROVE_NO_RETRY, suspendBrowser: true })));
    assert.equal(withoutRetry.read().status, 'halted', 'no retry was granted, so the infrastructure halt is terminal');
  } finally { withoutRetry.clean(); }
});

test('a suspension during setup and a lost caffeinate holder are infrastructure halts that never launched the CLI or lost the host', async () => {
  const setupSleep = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(setupSleep.freezeFile, R3_FIRST, setupSleep.evidenceFile, setupSleep.checkout, setupSleep.makeDeps({ setupSuspended: true, setupExit: 1 })));
    const evidence = setupSleep.read();
    assert.equal(evidence.status, 'halted_infrastructure');
    assert.equal(evidence.attempts[0].playwright_cli.launched, false);
    assert.equal(evidence.limits.physical_playwright_cli_launches, 7);
    assert.deepEqual(evidence.stop_record.per_test_rows, []);
    assert.equal(evidence.stop_record.cli_launched, false);
  } finally { setupSleep.clean(); }
  const lost = loadHarnessR3();
  try {
    await assert.rejects(() => recovery.runLoadRecoverySlotR3(lost.freezeFile, R3_FIRST, lost.evidenceFile, lost.checkout, lost.makeDeps({ holderAlive: () => false })), /holder/i);
    const evidence = lost.read();
    assert.equal(evidence.status, 'halted_infrastructure');
    assert.equal(evidence.infrastructure_retry.cause, 'holder_lost');
    assert.equal(evidence.attempts[0].host.holder_alive_at_end, false);
  } finally { lost.clean(); }
});

test('R3 accepted evidence verifies by git ancestry and object reads after a later committed runner change, while a live check still demands the working tree', () => {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-terminal-r3-')));
  try {
    gitIn(dir, 'init', '-q'); gitIn(dir, 'config', 'user.email', 'test@example.test'); gitIn(dir, 'config', 'user.name', 'test'); gitIn(dir, 'config', 'commit.gpgsign', 'false');
    fs.writeFileSync(path.join(dir, 'runner.mjs'), 'export const frozen = true;\n');
    gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'freeze point');
    const frozenHead = gitIn(dir, 'rev-parse', 'HEAD');
    const freeze = { source: { checkout_head: frozenHead, blobs: { 'runner.mjs': gitIn(dir, 'rev-parse', `${frozenHead}:runner.mjs`) } } };
    assert.equal(recovery.verifyFrozenSourceBindingR3(dir, freeze, { terminal: false }), frozenHead);
    fs.writeFileSync(path.join(dir, 'runner.mjs'), 'export const frozen = true; export const later = 1;\n');
    gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-q', '-m', 'later runner change');
    assert.throws(() => recovery.verifyFrozenSourceBindingR3(dir, freeze, { terminal: false }), /identity mismatch/i, 'init, prepare and run demand working-tree equality');
    assert.equal(recovery.verifyFrozenSourceBindingR3(dir, freeze, { terminal: true }), gitIn(dir, 'rev-parse', 'HEAD'), 'accepted evidence is not silently invalidated');
    const forged = structuredClone(freeze); forged.source.blobs['runner.mjs'] = '0'.repeat(40);
    assert.throws(() => recovery.verifyFrozenSourceBindingR3(dir, forged, { terminal: true }), /blob mismatch/i);
    const notAncestor = structuredClone(freeze); notAncestor.source.checkout_head = '1'.repeat(40);
    assert.throws(() => recovery.verifyFrozenSourceBindingR3(dir, notAncestor, { terminal: true }), /ancestor/i);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test.after(() => {
  net.Socket.prototype.connect = originalConnect;
  net.Server.prototype.listen = originalListen;
  fs.rmSync(temporary, { recursive: true, force: true });
});
