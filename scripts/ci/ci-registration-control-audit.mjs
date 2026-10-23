#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SCHEMA = 'sigra.phase253.registration-control-timeout-assessment/v1';
const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));

function git(args, cwd) {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr.trim() || `git ${args.join(' ')} failed`);
  return result.stdout.trim();
}

function parseArgs(argv) {
  if (argv.length === 6 && argv[0] === '--analyze' && argv[1] === '--native' && argv[2] && argv[3] === '--cleanup' && argv[4] && argv[5] === '--output') {
    throw new Error('usage: --analyze --native <json> --cleanup <json> --output <json>');
  }
  if (argv.length === 7 && argv[0] === '--analyze' && argv[1] === '--native' && argv[2] && argv[3] === '--cleanup' && argv[4] && argv[5] === '--output' && argv[6]) {
    return { mode: 'analyze', native: path.resolve(argv[2]), cleanup: path.resolve(argv[4]), output: path.resolve(argv[6]) };
  }
  if (argv.length === 2 && argv[0] === '--check-assessment' && argv[1]) return { mode: 'check', assessment: path.resolve(argv[1]) };
  throw new Error('usage: --analyze --native <json> --cleanup <json> --output <json> | --check-assessment <json>');
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function inspectEvidence(nativePath, cleanupPath, cwd) {
  const native = readJson(nativePath);
  const cleanup = readJson(cleanupPath);
  const attempt = native.attempts?.length === 1 ? native.attempts[0] : null;
  assert(native.schema_version === 'sigra.phase253.registration-control-evidence/v1', 'unexpected native evidence schema');
  assert(native.status === 'halted' && attempt?.observed_outcome === 'halted', 'original native command must remain halted');
  assert(attempt.slot_id === 'R-DIAG-CONTROL-DARK' && attempt.project === 'admin-eval-dark', 'unexpected native command identity');
  assert(attempt.execution_duration_ms === 121252 && attempt.charged_duration_ms === 121252, 'original 121252 ms charge changed');
  assert(attempt.registration?.server_post_confirmed === false, 'native POST observation changed');
  assert(attempt.files?.native_json == null, 'a native Playwright report was fabricated');
  assert(attempt.log_redactions?.test_log?.signal === 'SIGKILL', 'original timeout signal missing');
  assert(/ETIMEDOUT/.test(attempt.log_redactions?.test_log?.error ?? ''), 'original timeout error missing');
  assert(cleanup.status === 'complete' && cleanup.native_slot_invalid === true, 'cleanup must remain separate and completed');
  assert(cleanup.cleanup_duration_ms === 112 && cleanup.exit_code === 0 && cleanup.database_absent_confirmed === true, 'cleanup evidence changed');
  assert(cleanup.original_native_slot_still_failed === true, 'cleanup cannot make the native slot pass');
  assert(cleanup.cumulative_charge_ms_including_post_halt_cleanup === 243044, 'cumulative charge changed');
  assert(sha256(fs.readFileSync(nativePath)) === cleanup.owner_evidence_sha256, 'cleanup does not bind the exact native evidence bytes');

  const sourceHead = native.source?.checkout_head;
  assert(sourceHead && attempt.source_commit === sourceHead, 'native source commit identity mismatch');
  assert(JSON.stringify(attempt.source_blobs) === JSON.stringify(native.source.blobs), 'attempt source blob map differs from frozen source');
  const sourceHashes = {};
  for (const [file, expectedBlob] of Object.entries(native.source.blobs ?? {})) {
    const actualBlob = git(['rev-parse', `${sourceHead}:${file}`], cwd);
    assert(actualBlob === expectedBlob, `frozen source blob changed: ${file}`);
    sourceHashes[file] = { commit: sourceHead, blob: actualBlob };
  }

  const rawRoot = `${nativePath}.raw`;
  const logHashes = {};
  for (const name of ['test_log', 'app_log']) {
    const record = attempt.files?.[name];
    assert(record?.path && /^[a-f0-9]{64}$/.test(record.sha256), `missing sanitized ${name} identity`);
    const file = path.join(rawRoot, record.path);
    const bytes = fs.readFileSync(file);
    assert(bytes.length === record.bytes && sha256(bytes) === record.sha256, `${name} bytes differ from the retained receipt`);
    logHashes[name] = { path: path.relative(cwd, file), sha256: record.sha256, bytes: bytes.length };
  }
  const testLog = fs.readFileSync(path.join(rawRoot, attempt.files.test_log.path), 'utf8');
  const completed = [...testLog.matchAll(/^\s*(?:✓|✔)\s*(\d+)\s+.*registration (?:waits for explicitly released LiveView readiness|stops when LiveView readiness is never released|fails when the readiness wait is deliberately broken|detects a deliberate same-account collision|retains the first forced assertion failure trace).*?(?:\((\d+(?:\.\d+)?)s\))?\s*$/gm)];
  assert(testLog.includes('registration waits for explicitly released LiveView readiness') && testLog.includes('16.5s'), 'missing held-readiness progress observation');
  assert(testLog.includes('registration stops when LiveView readiness is never released') && testLog.includes('2.3s'), 'missing never-released progress observation');
  assert(testLog.includes('registration fails when the readiness wait is deliberately broken') && testLog.includes('1.8s'), 'missing broken-readiness progress observation');
  assert(!testLog.includes('6 failed') && !testLog.includes('5 passed'), 'test log has an unsupported fabricated summary');

  const observations = {
    test_progress: [
      { test: 'registration waits for explicitly released LiveView readiness', elapsed: '16.5s', outcome: 'failed' },
      { test: 'registration stops when LiveView readiness is never released', elapsed: '2.3s', outcome: 'observed in progress log; no native report' },
      { test: 'registration fails when the readiness wait is deliberately broken', elapsed: '1.8s', outcome: 'observed in progress log; no native report' },
    ],
    selected_order: ['held-readiness positive started before deliberate collision; collision was last started among the visible registration controls'],
    held_signal_source_mismatch: 'Saved source shows a click while the LiveView websocket is still held, followed by release and a second click. This proves the test submits before release; it does not prove that this caused the historical timeout.',
    account_source_mismatch: 'Saved source uses the same project-derived account for the delayed positive and deliberate collision. This proves account-role reuse; it does not establish the historical registration failure cause.',
    transport: 'No native transport observation is recorded. WebSocket is explicitly routed; long-poll bypass is unproved.',
    native_final_error: null,
    native_report: null,
  };
  return {
    schema_version: SCHEMA,
    status: 'halted',
    native_outcome: 'failed',
    native_acceptance: false,
    source_commit: sourceHead,
    native_evidence_sha256: sha256(fs.readFileSync(nativePath)),
    cleanup_evidence_sha256: sha256(fs.readFileSync(cleanupPath)),
    source_hashes: sourceHashes,
    log_hashes: logHashes,
    native_duration_ms: 121252,
    cleanup_duration_ms: 112,
    cumulative_charge_ms: 243044,
    database_absent_after_cleanup: true,
    native_report_present: false,
    native_final_error: null,
    cause_status: 'unproved_native_until_recovery',
    observations,
  };
}

function checkAssessment(file, cwd) {
  const assessment = readJson(file);
  assert(assessment.schema_version === SCHEMA, 'assessment schema mismatch');
  assert(assessment.status === 'halted' && assessment.native_outcome === 'failed', 'assessment must preserve the failed native outcome');
  assert(assessment.native_acceptance === false && assessment.native_report_present === false, 'assessment must not claim native acceptance');
  assert(assessment.native_duration_ms === 121252 && assessment.cleanup_duration_ms === 112 && assessment.cumulative_charge_ms === 243044, 'assessment charge values changed');
  assert(assessment.cause_status === 'unproved_native_until_recovery', 'assessment must keep native cause unproved');
  assert(assessment.native_final_error === null && assessment.observations?.native_final_error === null, 'assessment fabricated a native final error');
  for (const [source, identity] of Object.entries(assessment.source_hashes ?? {})) {
    assert(git(['rev-parse', `${identity.commit}:${source}`], cwd) === identity.blob, `assessment source hash changed: ${source}`);
  }
  for (const [, identity] of Object.entries(assessment.log_hashes ?? {})) {
    const bytes = fs.readFileSync(path.resolve(cwd, identity.path));
    assert(bytes.length === identity.bytes && sha256(bytes) === identity.sha256, `assessment log hash changed: ${identity.path}`);
  }
  assert(Object.keys(assessment.source_hashes ?? {}).length > 0 && Object.keys(assessment.log_hashes ?? {}).length === 2, 'assessment is missing source or log identities');
}

try {
  const args = parseArgs(process.argv.slice(2));
  const cwd = git(['rev-parse', '--show-toplevel'], process.cwd());
  if (args.mode === 'analyze') {
    const assessment = inspectEvidence(args.native, args.cleanup, cwd);
    fs.mkdirSync(path.dirname(args.output), { recursive: true });
    fs.writeFileSync(args.output, `${JSON.stringify(assessment, null, 2)}\n`, { flag: 'wx' });
    checkAssessment(args.output, cwd);
    process.stdout.write(`wrote halted assessment: ${args.output}\n`);
  } else {
    checkAssessment(args.assessment, cwd);
    process.stdout.write(`assessment valid; native cause remains unproved: ${args.assessment}\n`);
  }
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
