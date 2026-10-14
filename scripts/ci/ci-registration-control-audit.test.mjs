import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  registrationControlAccount,
  runHeldRegistrationControl,
} from '../../test/example/priv/playwright/helpers/registrationControls.mjs';

const CLI = path.resolve('scripts/ci/ci-registration-control-audit.mjs');
const PROJECT = 'sigra_253_control_admin_eval_dark_mv78a7kk_28426';

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-registration-control-audit-'));
  const sourcePath = 'test/example/priv/playwright/tests/admin-eval.spec.ts';
  const source = 'export const frozenSource = true;\n';
  const testLog = [
    'Running 6 tests using 1 worker',
    '  ✓ 1 [admin-eval-dark] › render bundle (3.2s)',
    '  ✘ 2 [admin-eval-dark] › registration waits for explicitly released LiveView readiness (16.5s)',
    '  ✓ 3 [admin-eval-dark] › registration stops when LiveView readiness is never released (2.3s)',
    '  ✓ 4 [admin-eval-dark] › registration fails when the readiness wait is deliberately broken (1.8s)',
    '  - 5 [admin-eval-dark] › registration detects a deliberate same-account collision',
    '  - 6 [admin-eval-dark] › registration retains the first forced assertion failure trace',
    '  1 failed',
  ].join('\n') + '\n';
  const appLog = 'HTTP server ready; status=200\n';
  fs.mkdirSync(path.dirname(path.join(root, sourcePath)), { recursive: true });
  fs.writeFileSync(path.join(root, sourcePath), source);
  const init = spawnSync('git', ['init', '-q'], { cwd: root, encoding: 'utf8' });
  assert.equal(init.status, 0, init.stderr);
  const add = spawnSync('git', ['add', sourcePath], { cwd: root, encoding: 'utf8' });
  assert.equal(add.status, 0, add.stderr);
  const commit = spawnSync('git', ['-c', 'user.name=fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'frozen fixture'], { cwd: root, encoding: 'utf8' });
  assert.equal(commit.status, 0, commit.stderr);
  const head = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).stdout.trim();
  const blob = spawnSync('git', ['rev-parse', `HEAD:${sourcePath}`], { cwd: root, encoding: 'utf8' }).stdout.trim();
  const logDir = path.join(root, 'native.json.raw');
  fs.mkdirSync(logDir);
  fs.writeFileSync(path.join(logDir, 'test-log.log'), testLog);
  fs.writeFileSync(path.join(logDir, 'app-log.log'), appLog);
  const native = {
    schema_version: 'sigra.phase253.registration-control-evidence/v1',
    status: 'halted',
    source: { checkout_head: head, blobs: { [sourcePath]: blob } },
    attempts: [{
      slot_id: 'R-DIAG-CONTROL-DARK',
      project: 'admin-eval-dark',
      observed_outcome: 'halted',
      execution_duration_ms: 121252,
      charged_duration_ms: 121252,
      source_commit: head,
      source_blobs: { [sourcePath]: blob },
      files: {
        test_log: { path: 'test-log.log', sha256: sha256(testLog), bytes: Buffer.byteLength(testLog) },
        app_log: { path: 'app-log.log', sha256: sha256(appLog), bytes: Buffer.byteLength(appLog) },
        native_json: null,
      },
      log_redactions: {
        test_log: { exit_code: null, signal: 'SIGKILL', error: 'spawnSync playwright ETIMEDOUT' },
        app_log: { redacted_secret_fields: 0 },
      },
      registration: { server_post_confirmed: false },
    }],
  };
  const cleanup = {
    status: 'complete',
    owner_evidence: 'native.json',
    owner_evidence_sha256: sha256(`${JSON.stringify(native, null, 2)}\n`),
    native_slot_invalid: true,
    exit_code: 0,
    database_absent_confirmed: true,
    cleanup_duration_ms: 112,
    cumulative_charge_ms_including_post_halt_cleanup: 243044,
    original_native_slot_still_failed: true,
  };
  const nativePath = path.join(root, 'native.json');
  const cleanupPath = path.join(root, 'cleanup.json');
  const assessmentPath = path.join(root, 'assessment.json');
  fs.writeFileSync(nativePath, `${JSON.stringify(native, null, 2)}\n`);
  fs.writeFileSync(cleanupPath, `${JSON.stringify(cleanup, null, 2)}\n`);
  return { root, nativePath, cleanupPath, assessmentPath, native, cleanup, sourcePath, logDir };
}

function run(args, cwd) {
  return spawnSync(process.execPath, [CLI, ...args], { cwd, encoding: 'utf8' });
}

test('offline audit writes an exact failed timeout assessment from frozen sources and sanitized logs', (t) => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  const result = run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root);
  assert.equal(result.status, 0, result.stderr);
  const assessment = JSON.parse(fs.readFileSync(f.assessmentPath, 'utf8'));
  assert.equal(assessment.status, 'halted');
  assert.equal(assessment.native_outcome, 'failed');
  assert.equal(assessment.native_duration_ms, 121252);
  assert.equal(assessment.cleanup_duration_ms, 112);
  assert.equal(assessment.cumulative_charge_ms, 243044);
  assert.equal(assessment.cause_status, 'unproved_native_until_recovery');
  assert.equal(assessment.native_acceptance, false);
  assert.deepEqual(assessment.observations.test_progress.map((row) => row.elapsed), ['16.5s', '2.3s', '1.8s']);
  assert.match(assessment.observations.selected_order.join(' '), /collision/);
  assert.equal(assessment.source_hashes[f.sourcePath].blob, f.native.source.blobs[f.sourcePath]);
  assert.equal(run(['--check-assessment', f.assessmentPath], f.root).status, 0);
});

test('audit rejects changed source, changed logs, altered charge, and a fabricated native result', (t) => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  const valid = run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root);
  assert.equal(valid.status, 0, valid.stderr);
  const originalNative = fs.readFileSync(f.nativePath, 'utf8');
  const originalTestLog = fs.readFileSync(path.join(f.logDir, 'test-log.log'), 'utf8');

  let altered = JSON.parse(originalNative);
  altered.source.blobs[f.sourcePath] = '0000000000000000000000000000000000000000';
  fs.writeFileSync(f.nativePath, JSON.stringify(altered));
  assert.notEqual(run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root).status, 0);
  fs.writeFileSync(f.nativePath, originalNative);

  fs.writeFileSync(path.join(f.logDir, 'test-log.log'), `${originalTestLog}forged pass\n`);
  assert.notEqual(run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root).status, 0);
  fs.writeFileSync(path.join(f.logDir, 'test-log.log'), originalTestLog);

  altered = JSON.parse(originalNative);
  altered.attempts[0].charged_duration_ms = 121251;
  fs.writeFileSync(f.nativePath, JSON.stringify(altered));
  assert.notEqual(run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root).status, 0);
  altered.attempts[0].charged_duration_ms = 121252;
  altered.attempts[0].files.native_json = { path: 'report.json', sha256: 'a'.repeat(64), bytes: 4 };
  fs.writeFileSync(f.nativePath, JSON.stringify(altered));
  assert.notEqual(run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root).status, 0);
});

test('assessment checker rejects altered hashes, changed evidence, and native-acceptance claims', (t) => {
  const f = fixture();
  t.after(() => fs.rmSync(f.root, { recursive: true, force: true }));
  const valid = run(['--analyze', '--native', f.nativePath, '--cleanup', f.cleanupPath, '--output', f.assessmentPath], f.root);
  assert.equal(valid.status, 0, valid.stderr);
  const assessment = JSON.parse(fs.readFileSync(f.assessmentPath, 'utf8'));
  assessment.native_acceptance = true;
  fs.writeFileSync(f.assessmentPath, JSON.stringify(assessment));
  assert.notEqual(run(['--check-assessment', f.assessmentPath], f.root).status, 0);
  assessment.native_acceptance = false;
  assessment.source_hashes[f.sourcePath].blob = 'f'.repeat(40);
  fs.writeFileSync(f.assessmentPath, JSON.stringify(assessment));
  assert.notEqual(run(['--check-assessment', f.assessmentPath], f.root).status, 0);
  assessment.source_hashes[f.sourcePath].blob = f.native.source.blobs[f.sourcePath];
  assessment.native_outcome = 'passed';
  fs.writeFileSync(f.assessmentPath, JSON.stringify(assessment));
  assert.notEqual(run(['--check-assessment', f.assessmentPath], f.root).status, 0);
});

test('shared held-registration control releases readiness before submit', async () => {
  const events = [];
  const annotations = [];
  let released = false;
  let posts = 0;
  const page = {
    click() {
      events.push(released ? 'submit' : 'submit-while-held');
      if (released) posts += 1;
    },
  };
  await runHeldRegistrationControl({
    page,
    waitForHold: async () => { events.push('hold'); },
    fill: async () => { events.push('fill'); },
    submit: async (actualPage) => actualPage.click(),
    assertNoPostWhileHeld: async () => { assert.equal(posts, 0); },
    release: () => { released = true; events.push('release'); },
    waitUntilReady: async () => { events.push('ready'); },
    refillAfterReady: async () => { events.push('refill'); },
    assertSuccess: async () => { events.push('success'); },
    annotate: (stage) => annotations.push(stage),
  });
  assert.deepEqual(events, ['hold', 'fill', 'release', 'ready', 'refill', 'submit', 'success']);
  assert.deepEqual(annotations, [
    'connection_hold_observed', 'fill', 'connection_released', 'readiness_ready', 'readiness_refill', 'submit', 'original_assertion',
  ]);
  assert.equal(posts, 1);
});

test('shared held-registration control requires refillAfterReady before any page interaction', async () => {
  const events = [];
  await assert.rejects(
    runHeldRegistrationControl({
      page: {},
      waitForHold: async () => { events.push('hold'); },
      fill: async () => { events.push('fill'); },
      submit: async () => { events.push('submit'); },
      assertNoPostWhileHeld: async () => {},
      release: () => {},
      waitUntilReady: async () => {},
      assertSuccess: async () => {},
    }),
    TypeError,
  );
  assert.deepEqual(events, []);
});

test('shared control isolates the positive account from the deliberate collision account', () => {
  const positive = registrationControlAccount('admin-eval-dark', 'held-positive');
  const collision = registrationControlAccount('admin-eval-dark', 'collision');
  assert.notEqual(positive, collision);
});

test('shared control reuses exactly one account within the deliberate collision', () => {
  const firstCollision = registrationControlAccount('admin-eval-dark', 'collision');
  const secondCollision = registrationControlAccount('admin-eval-dark', 'collision');
  assert.equal(firstCollision, secondCollision);
});
