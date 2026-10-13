import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { attemptDirectory, runLogged, verifyDiagnosticData, verifyNativeAttempt, verifyRevisionFreezeBinding } from './ci-registration-recovery.mjs';
import * as recovery from './ci-registration-recovery.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const runner = path.join(root, 'scripts/ci/ci-registration-repro.sh');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-recovery-red-'));
const acceptedEvidence = path.join(root, '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-VERIFIED-REGISTRATION-EVIDENCE.json');

function copyAcceptedReceipt(label, mutateEvidence = () => {}, mutateReport = null) {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), `sigra-253-saved-${label}-`));
  const evidencePath = path.join(base, 'evidence.json');
  const rawSource = `${acceptedEvidence}.raw`;
  const rawPath = `${evidencePath}.raw`;
  fs.copyFileSync(acceptedEvidence, evidencePath);
  fs.cpSync(rawSource, rawPath, { recursive: true });
  const evidence = JSON.parse(fs.readFileSync(evidencePath, 'utf8'));
  mutateEvidence(evidence, rawPath);
  if (mutateReport && evidence.attempts?.[0]?.files?.playwright_report) {
    const reference = evidence.attempts[0].files.playwright_report;
    const reportPath = path.join(rawPath, reference.path);
    const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
    const updateDigest = mutateReport(report, evidence.attempts[0]);
    fs.writeFileSync(reportPath, JSON.stringify(report));
    if (updateDigest) reference.sha256 = crypto.createHash('sha256').update(fs.readFileSync(reportPath)).digest('hex');
  }
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  return { base, evidencePath, evidence };
}

function verifySavedReceipt(evidencePath) {
  return spawnSync(runner, ['--verify-diagnostic', evidencePath, '--revision'], { encoding: 'utf8' });
}

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

test('the explicit revision CLI freezes before results and accepts a named diagnostic slot', () => {
  const freeze = path.join(temporary, 'registration-revision.json');
  const evidence = path.join(temporary, 'registration-revision-evidence.json');
  const create = spawnSync(runner, ['--create-revision', '--output', freeze], { encoding: 'utf8' });

  assert.equal(create.status, 3, 'a terminal ledger cannot be reopened by the old generic revision entrypoint');
  assert.match(create.stderr, /zero-native-launch preparation ledger/i);
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

  const phase = path.join(root, '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks');
  const freeze = path.join(temporary, 'reviewed-infrastructure-retry.json');
  const reservation = path.join(temporary, 'reviewed-infrastructure-retry-reservation.json');
  const create = spawnSync(runner, ['--create-infrastructure-retry', '--freeze', path.join(phase, '253-REPLAN-REGISTRATION-FREEZE-REVISION-03.json'), '--evidence', path.join(phase, '253-REPLAN-REGISTRATION-EVIDENCE.json'), '--review', path.join(phase, '253-15-INFRASTRUCTURE-RETRY-REVIEW.json'), '--output', freeze, '--reservation', reservation], { encoding: 'utf8' });
  assert.equal(create.status, 0, `${create.stdout}\n${create.stderr}`);
  const retryFreeze = JSON.parse(fs.readFileSync(freeze, 'utf8'));
  assert.equal(retryFreeze.infrastructure_retry.count, 1);
  assert.equal(retryFreeze.ledger.historical_charge_ms, 33884);
  assert.deepEqual(retryFreeze.ledger.slots.map((slot) => slot.id), ['R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE']);
  assert.equal(JSON.parse(fs.readFileSync(reservation, 'utf8')).status, 'reserved');
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
    const inherited = { ...process.env, MIX_BUILD_PATH: '/shared/compiled-at-port-4011' };
    const one = recovery.diagnosticEnvironment({ port: 25311 }, 'first_database', first, inherited);
    const two = recovery.diagnosticEnvironment({ port: 25312 }, 'second_database', second, inherited);
    assert.equal(one.MIX_BUILD_PATH, path.join(fs.realpathSync(first), 'mix-build'));
    assert.equal(two.MIX_BUILD_PATH, path.join(fs.realpathSync(second), 'mix-build'));
    assert.notEqual(one.MIX_BUILD_PATH, two.MIX_BUILD_PATH);
    assert.equal(fs.existsSync(one.MIX_BUILD_PATH), false);
    assert.equal(one.PORT, '25311');
    assert.equal(two.PORT, '25312');
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

test('the saved desktop and mobile native Playwright receipts verify through the real shell CLI', () => {
  const fixture = copyAcceptedReceipt('native-positive');
  try {
    const result = verifySavedReceipt(fixture.evidencePath);
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
    assert.match(result.stdout, /2\/2 plan15 diagnostics; 2 launches; 121680 ms charged/);
    assert.deepEqual(fixture.evidence.attempts.map((attempt) => attempt.observed_outcome), ['passed', 'passed']);
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('revision CLI rejects slot usage counters that do not match native attempts', () => {
  const fixture = copyAcceptedReceipt('slot-count-drift', (evidence) => { evidence.limits.used_slots = []; });
  try {
    const result = verifySavedReceipt(fixture.evidencePath);
    assert.equal(result.status, 3, `${result.stdout}\n${result.stderr}`);
    assert.match(result.stderr, /slot/i);
  } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
});

test('revision CLI rejects forged, mismatched, duplicated, and over-budget saved receipts', () => {
  const findSelectedSpec = (report) => {
    const visit = (suite) => {
      for (const spec of suite.specs ?? []) {
        if (spec.title === 'render bundle: board-mg-9/populated') return spec;
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
    ['singleton wrong project', (evidence) => { evidence.attempts = [evidence.attempts[0]]; evidence.attempts[0].project = 'admin-eval-dark'; }],
    ['duplicate spent slot', (evidence) => { evidence.attempts.push(structuredClone(evidence.attempts[0])); }],
    ['source commit drift', (evidence) => { evidence.source.checkout_head = 'different-source'; }],
    ['source blob drift', (evidence) => { evidence.source.blobs['scripts/ci/ci-registration-recovery.mjs'] = 'different-blob'; }],
    ['over-counted launches', (evidence) => { evidence.limits.browser_launches += 1; }],
    ['over-time charge', (evidence) => { evidence.attempts[0].charged_duration_ms = 120001; }],
    ['missing database drop', (evidence) => { evidence.attempts[0].database.drop_exit_code = null; }],
    ['missing browser report', (evidence) => { evidence.attempts[0].files.playwright_report = null; }],
    ['changed sanitized log digest', (evidence, rawPath) => { fs.appendFileSync(path.join(rawPath, evidence.attempts[0].files.setup_log.path), 'changed after receipt\n'); }]
  ];

  for (const [label, mutateEvidence] of cases) {
    const fixture = copyAcceptedReceipt(label.replaceAll(' ', '-'), mutateEvidence);
    try {
      const result = verifySavedReceipt(fixture.evidencePath);
      assert.equal(result.status, 3, `${label}: ${result.stdout}\n${result.stderr}`);
    } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
  }

  const reportCases = [
    ['byte-variant selected title', (report) => { findSelectedSpec(report).title += '\u200b'; return true; }],
    ['native expectedStatus mismatch', (report) => { findSelectedSpec(report).tests[0].expectedStatus = 'skipped'; return true; }],
    ['native result status mismatch', (report) => { findSelectedSpec(report).tests[0].results[0].status = 'failed'; return true; }],
    ['empty native report', (report) => { report.suites = []; return true; }]
  ];
  for (const [label, mutateReport] of reportCases) {
    const fixture = copyAcceptedReceipt(label.replaceAll(' ', '-'), () => {}, mutateReport);
    try {
      const result = verifySavedReceipt(fixture.evidencePath);
      assert.equal(result.status, 3, `${label}: ${result.stdout}\n${result.stderr}`);
    } finally { fs.rmSync(fixture.base, { recursive: true, force: true }); }
  }

  const exitMismatch = copyAcceptedReceipt('cli-exit-disagreement', (evidence) => { evidence.attempts[0].browser.exit_code = 1; });
  try {
    const result = verifySavedReceipt(exitMismatch.evidencePath);
    assert.equal(result.status, 3, `${result.stdout}\n${result.stderr}`);
  } finally { fs.rmSync(exitMismatch.base, { recursive: true, force: true }); }
});

test('the real shell refuses to restart a terminal native receipt before setup or browser work', () => {
  const phase = path.join(root, '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks');
  const result = spawnSync(runner, [
    '--run-revision', path.join(phase, '253-15-INFRASTRUCTURE-RETRY-FREEZE-REVISION-03.json'),
    '--slot', 'R-DIAG-CONTROL-DARK', '--output', acceptedEvidence
  ], { encoding: 'utf8' });
  assert.equal(result.status, 3, `${result.stdout}\n${result.stderr}`);
  assert.match(result.stderr, /refusing to continue terminal evidence/);
});

test('the dirty config must still match its exact preserved bytes and SHA-256', () => {
  assert.equal(typeof recovery.assertDirtyConfigPreserved, 'function');
  if (typeof recovery.assertDirtyConfigPreserved !== 'function') return;
  assert.doesNotThrow(() => recovery.assertDirtyConfigPreserved(root));
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

test.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
