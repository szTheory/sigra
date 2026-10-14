#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SCHEMA = 'sigra.phase253.registration-recovery-evidence/v1';
const FREEZE_SCHEMA = 'sigra.phase253.registration-recovery-freeze/v1';
const REPLAN_SCHEMA = 'sigra.phase253.registration-replan-evidence/v1';
const REPLAN_FREEZE_SCHEMA = 'sigra.phase253.registration-replan-freeze/v1';
const CONTROL_SCHEMA = 'sigra.phase253.registration-control-evidence/v1';
const CONTROL_FREEZE_SCHEMA = 'sigra.phase253.registration-control-freeze/v1';
const CONTROL_RECOVERY_SCHEMA = 'sigra.phase253.registration-control-recovery-evidence/v1';
const CONTROL_RECOVERY_FREEZE_SCHEMA = 'sigra.phase253.registration-control-recovery-freeze/v1';
const PHASE_DIR = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks';
const PROJECTS = [
  { name: 'admin-eval', port: 25311 },
  { name: 'admin-eval-mobile', port: 25312 },
  { name: 'admin-eval-dark', port: 25313 }
];
const SOURCE_FILES = [
  'scripts/ci/ci-registration-repro.sh',
  'scripts/ci/ci-registration-recovery.mjs',
  'scripts/ci/ci-registration-recovery.test.mjs',
  'scripts/ci/ci-playwright-report.mjs',
  'test/example/priv/playwright/playwright.config.ts',
  'test/example/priv/playwright/tests/admin-eval.spec.ts',
  'test/example/priv/playwright/helpers/adminFlows.ts',
  'test/example/priv/playwright/package-lock.json',
  'test/example/mix.lock',
  '.github/workflows/ci.yml'
];
const TOTAL_CAP_MS = 58 * 60 * 1000;
const D19_CAP_MS = 18 * 60 * 1000;
const PROJECT_SLOT_MS = 120_000;
const REPLAN_FREEZE_PATH = `${PHASE_DIR}/253-REPLAN-REGISTRATION-FREEZE.json`;
const REPLAN_EVIDENCE_PATH = `${PHASE_DIR}/253-REPLAN-REGISTRATION-EVIDENCE.json`;
const CONTROL_FREEZE_PATH = `${PHASE_DIR}/253-REPLAN-REGISTRATION-CONTROL-FREEZE.json`;
const CONTROL_EVIDENCE_PATH = `${PHASE_DIR}/253-16-CONTROL-EVIDENCE.json`;
const RETRY_MARKER_PATH = `${PHASE_DIR}/253-15-SHARED-RETRY-USED.json`;
const DIRTY_CONFIG = {
  path: '.planning/config.json', status: ' M', porcelain: ' M .planning/config.json',
  ref: 'refs/gsd/phase253-recovery-execution-unrelated-config',
  blob: 'ab8aa3007f17294e2f224d4ac8482522b79bda24',
  sha256: '8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d'
};
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const CONTROL_SOURCE_FILES = SOURCE_FILES.filter((file) => file !== 'scripts/ci/ci-registration-recovery.test.mjs');
const CONTROL_RECOVERY_FREEZE_PATH = `${PHASE_DIR}/253-CONTROL-RECOVERY-NATIVE-FREEZE.json`;
const CONTROL_RECOVERY_EVIDENCE_PATH = `${PHASE_DIR}/253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json`;
const CONTROL_RECOVERY_PRIOR = [
  { file: `${PHASE_DIR}/253-09-TERMINAL-DIAGNOSTIC.json`, expected: 3768 },
  { file: `${PHASE_DIR}/253-REPLAN-REGISTRATION-EVIDENCE.json`, preparationOnly: 3743, desktop: 26373 },
  { file: `${PHASE_DIR}/253-15-VERIFIED-REGISTRATION-EVIDENCE.json`, slots: ['R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE'], expected: [46803, 40993] },
  { file: `${PHASE_DIR}/253-16-CONTROL-EVIDENCE.json`, slot: 'R-DIAG-CONTROL-DARK', expected: 121252 },
  { file: `${PHASE_DIR}/253-16-POST-HALT-CLEANUP.json`, expected: 112 }
];
const CONTROL_RECOVERY_TIMEOUT_ASSESSMENT = `${PHASE_DIR}/253-CONTROL-RECOVERY-TIMEOUT-ASSESSMENT.json`;
const CONTROL_RECOVERY_RESERVED = [
  ['CR-DARK-FIRST', 'R-CONTROL-FIRST-DESKTOP', ['admin-eval-dark'], 'first'],
  ['CR-DESKTOP-MOBILE-FIRST', 'R-CONTROL-FIRST-MOBILE', ['admin-eval', 'admin-eval-mobile'], 'first'],
  ['CR-DESKTOP-SECOND', 'R-CONTROL-SECOND-DESKTOP', ['admin-eval'], 'second'],
  ['CR-MOBILE-SECOND', 'R-CONTROL-SECOND-MOBILE', ['admin-eval-mobile'], 'second'],
  ['CR-DARK-SECOND', 'R-CONTROL-SECOND-DARK', ['admin-eval-dark'], 'second']
];

const sha256 = (data) => crypto.createHash('sha256').update(data).digest('hex');
const fileHash = (file) => fs.existsSync(file) && fs.statSync(file).isFile()
  ? sha256(fs.readFileSync(file)) : null;
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
  fs.renameSync(temporary, file);
};
const run = (command, args, options = {}) => spawnSync(command, args, {
  cwd: options.cwd ?? ROOT,
  env: options.env ?? process.env,
  encoding: 'utf8',
  timeout: options.timeout ?? 30_000,
  maxBuffer: 8 * 1024 * 1024
});
const git = (args) => {
  const result = run('git', args);
  if (result.status !== 0) throw new Error(`git ${args.join(' ')} failed: ${result.stderr.trim()}`);
  return result.stdout.trim();
};

function parseArgs(argv) {
  if (argv[0] === '--create-load-recovery' && argv[1] === '--output' && argv[2] && argv.length === 3) return { mode: 'create-load-recovery', output: path.resolve(argv[2]) };
  if (argv[0] === '--record-budget-approval' && argv[1] === '--decision' && argv[2] && argv[3] === '--budget' && argv[4] && argv[5] === '--freeze' && argv[6] && argv[7] === '--output' && argv[8]
    && (argv.length === 9 || (argv.length === 11 && argv[9] === '--decision-text' && argv[10]))) {
    return { mode: 'record-budget-approval', decision: argv[2], budget: path.resolve(argv[4]), freeze: path.resolve(argv[6]), output: path.resolve(argv[8]), decisionText: argv.length === 11 ? argv[10] : '' };
  }
  if (argv[0] === '--preflight-host-sleep' && argv.length === 1) return { mode: 'preflight-host-sleep' };
  if (argv[0] === '--run-load-recovery' && argv[1] && argv[2] === '--slot' && argv[3] && argv[4] === '--output' && argv[5] && argv[6] === '--diagnostic' && argv[7] && argv.length === 8) return { mode: 'run-load-recovery', freeze: path.resolve(argv[1]), slot: argv[3], output: path.resolve(argv[5]), diagnostic: path.resolve(argv[7]) };
  if (argv[0] === '--create-load-recovery-r2' && argv[1] === '--output' && argv[2] && argv.length === 3) return { mode: 'create-load-recovery-r2', output: path.resolve(argv[2]) };
  if (argv[0] === '--create-load-recovery-r3' && argv[1] === '--output' && argv[2] && argv.length === 3) return { mode: 'create-load-recovery-r3', output: path.resolve(argv[2]) };
  if (argv[0] === '--init-load-recovery' && argv[1] === '--freeze' && argv[2] && argv[3] === '--output' && argv[4] && argv.length === 5) return { mode: 'init-load-recovery', freeze: path.resolve(argv[2]), output: path.resolve(argv[4]) };
  if (argv[0] === '--prepare-load-recovery' && argv[1] === '--freeze' && argv[2] && argv[3] === '--output' && argv[4] && argv.length === 5) return { mode: 'prepare-load-recovery', freeze: path.resolve(argv[2]), output: path.resolve(argv[4]) };
  if (argv[0] === '--run-load-recovery' && argv[1] && argv[2] === '--slot' && argv[3] && argv[4] === '--output' && argv[5] && argv.length === 6) return { mode: 'run-load-recovery', freeze: path.resolve(argv[1]), slot: argv[3], output: path.resolve(argv[5]) };
  if (argv[0] === '--verify-load-recovery' && argv[1] && argv[2] === '--stage' && ['first', 'complete'].includes(argv[3]) && argv.length === 4) return { mode: 'verify-load-recovery', evidence: path.resolve(argv[1]), stage: argv[3] };
  if (argv[0] === '--check-load-recovery-freeze' && argv[1] && argv.length === 2) return { mode: 'check-load-recovery-freeze', freeze: path.resolve(argv[1]) };
  if (argv[0] === '--create-control-recovery' && argv[1] === '--output' && argv[2] && argv.length === 3) {
    return { mode: 'create-control-recovery', output: path.resolve(argv[2]) };
  }
  if (argv[0] === '--init-control-recovery' && argv[1] === '--freeze' && argv[2] && argv[3] === '--output' && argv[4] && argv.length === 5) {
    return { mode: 'init-control-recovery', freeze: path.resolve(argv[2]), output: path.resolve(argv[4]) };
  }
  if (argv[0] === '--run-control-recovery' && argv[1] && argv[2] === '--slot' && argv[3] && argv[4] === '--output' && argv[5] && argv.length === 6) {
    return { mode: 'run-control-recovery', freeze: path.resolve(argv[1]), slot: argv[3], output: path.resolve(argv[5]) };
  }
  if (argv[0] === '--verify-control-recovery' && argv[1] && argv[2] === '--stage' && ['dark', 'first', 'complete'].includes(argv[3]) && argv.length === 4) {
    return { mode: 'verify-control-recovery', evidence: path.resolve(argv[1]), stage: argv[3] };
  }
  if (argv[0] === '--check-control-recovery-freeze' && argv[1] && argv.length === 2) {
    return { mode: 'check-control-recovery-freeze', freeze: path.resolve(argv[1]) };
  }
  if (argv[0] === '--freeze-controls' && argv[1] === '--prior' && argv[2] && argv[3] === '--output' && argv[4] && argv.length === 5) {
    return { mode: 'freeze-controls', prior: path.resolve(argv[2]), output: path.resolve(argv[4]) };
  }
  if (argv[0] === '--init-controls' && argv[1] === '--freeze' && argv[2] && argv[3] === '--output' && argv[4] && argv.length === 5) {
    return { mode: 'init-controls', freeze: path.resolve(argv[2]), output: path.resolve(argv[4]) };
  }
  if (argv[0] === '--run-revision' && argv[1] && argv[2] === '--slot' && argv[3] && argv[4] === '--output' && argv[5] && argv[6] === '--stage' && ['first', 'second'].includes(argv[7]) && argv.length === 8) {
    return { mode: 'run-control-revision', freeze: path.resolve(argv[1]), slot: argv[3], evidence: path.resolve(argv[5]), stage: argv[7] };
  }
  if (argv[0] === '--verify-controls' && argv[1] && argv[2] === '--stage' && ['first', 'complete'].includes(argv[3]) && argv[4] === '--revision' && argv.length === 5) {
    return { mode: 'verify-controls', evidence: path.resolve(argv[1]), stage: argv[3] };
  }
  if (argv[0] === '--create-revision' && argv[1] === '--output' && argv[2] && argv.length === 3) {
    return { mode: 'create-revision', output: path.resolve(argv[2]) };
  }
  if (argv[0] === '--prepare-revision' && argv[1] && argv[2] === '--evidence' && argv[3] && argv.length === 4) {
    return { mode: 'prepare-revision', freeze: path.resolve(argv[1]), evidence: path.resolve(argv[3]) };
  }
  if (argv[0] === '--run-revision' && argv[1] && argv[2] === '--slot' && argv[3] && argv[4] === '--output' && argv[5] && argv.length === 6) {
    return { mode: 'run-revision', freeze: path.resolve(argv[1]), slot: argv[3], evidence: path.resolve(argv[5]) };
  }
  if (argv[0] === '--verify-saved-native' && argv[1] && argv.length === 2) {
    // Read-only audit of saved native history; accepted-only. Never invoked by ordinary CI.
    return { mode: 'verify-saved-native', evidence: path.resolve(argv[1]) };
  }
  if (argv[0] === '--verify-diagnostic' && argv[1] && argv[2] === '--revision' && argv.length === 3) {
    return { mode: 'verify-revision', evidence: path.resolve(argv[1]) };
  }
  if (argv[0] === '--create-infrastructure-retry' && argv[1] === '--freeze' && argv[2] && argv[3] === '--evidence' && argv[4] && argv[5] === '--review' && argv[6] && argv[7] === '--output' && argv[8] && argv[9] === '--reservation' && argv[10] && argv.length === 11) {
    return { mode: 'create-infrastructure-retry', predecessor: path.resolve(argv[2]), evidence: path.resolve(argv[4]), review: path.resolve(argv[6]), output: path.resolve(argv[8]), reservation: path.resolve(argv[10]) };
  }
  if (argv[0] === '--refresh-infrastructure-retry' && argv[1] === '--freeze' && argv[2] && argv[3] === '--output' && argv[4] && argv.length === 5) return { mode: 'refresh-infrastructure-retry', predecessor: path.resolve(argv[2]), output: path.resolve(argv[4]) };
  if (argv[0] === '--create-freeze' && argv[1] === '--output' && argv[2] && argv.length === 3) {
    return { mode: 'create-freeze', output: path.resolve(argv[2]) };
  }
  if (argv[0] === '--verify-diagnostic' && argv[1] && argv.length === 2) {
    return { mode: 'verify-diagnostic', evidence: path.resolve(argv[1]) };
  }
  if (argv[0] === '--run-recovery' && argv[1] && argv[2] === '--output' && argv[3] && argv.length === 4) {
    return { mode: 'run-recovery', freeze: path.resolve(argv[1]), evidence: path.resolve(argv[3]) };
  }
  throw new Error('usage: ci-registration-recovery.mjs --create-freeze --output <freeze.json> | --run-recovery <freeze.json> --output <evidence.json> | --verify-diagnostic <evidence.json>');
}

export function validateInfrastructureRetry(prior, review) {
  const errors = [];
  const attempt = prior?.attempts?.length === 1 ? prior.attempts[0] : null;
  if (prior?.status !== 'halted') errors.push('prior native ledger is not terminal halted evidence');
  if (!attempt || attempt.slot_id !== 'R-DIAG-DESKTOP' || attempt.project !== 'admin-eval') errors.push('prior ledger does not contain exactly the spent desktop diagnostic');
  if (attempt && (attempt.failure_classification !== 'infrastructure' || attempt.test_started !== false || attempt.browser?.launched !== true)) errors.push('prior desktop outcome is not an independently diagnosed pre-test infrastructure failure');
  if (attempt && (attempt.server?.http_status !== 200 || attempt.database?.setup_exit_code !== 0 || attempt.database?.drop_exit_code !== 0)) errors.push('prior desktop setup, readiness, or cleanup receipts are incomplete');
  if (attempt && attempt.charged_duration_ms !== 26373) errors.push('prior desktop attempt charge differs from the reviewed 26,373 ms');
  if (review?.status !== 'independently_classified_infrastructure' || review.retry_used !== false || review.shared_retry_allowance !== 1) errors.push('independent review does not authorize the one unused shared retry');
  if (review?.failure !== 'Chromium headless shell SIGTRAP at macOS Mach port bootstrap_check_in with Permission denied (1100), before selected test began') errors.push('independent review does not identify the exact pre-test Chromium bootstrap failure');
  if (!attempt || attempt.files?.test_log?.sha256 !== review.test_log_sha256) errors.push('reviewed native test-log digest does not match the preserved failed attempt');
  if (prior?.limits?.historical_charge_ms !== 3768 || prior?.limits?.preparation_charge_ms !== 3743 || prior?.limits?.charged_duration_ms !== 33884) errors.push('prior historical, preparation, and native charges do not sum to 33,884 ms');
  if (prior?.limits?.browser_launches !== 1 || JSON.stringify(prior?.limits?.used_slots) !== JSON.stringify(['R-DIAG-DESKTOP'])) errors.push('prior desktop slot or browser launch accounting is inconsistent');
  if (review?.native_attempt_charge_ms !== 26373 || review?.total_charge_ms !== 33884 || review?.evidence_sha256 === undefined) errors.push('independent review lacks exact immutable evidence identity and charges');
  return { ok: errors.length === 0, errors };
}

function createInfrastructureRetry(predecessorFile, evidenceFile, reviewFile, outputFile, reservationFile, root = ROOT) {
  if ([outputFile, reservationFile].some((file) => fs.existsSync(file))) throw new Error('refusing to reuse a retry freeze or shared-retry reservation');
  const predecessor = readJson(predecessorFile); const prior = readJson(evidenceFile); const review = readJson(reviewFile);
  if (fileHash(evidenceFile) !== review.evidence_sha256 || fileHash(predecessorFile) !== prior.freeze_sha256) throw new Error('independent review or prior freeze digest does not match preserved bytes');
  const eligible = validateInfrastructureRetry(prior, review);
  if (!eligible.ok) throw new Error(`infrastructure retry rejected: ${eligible.errors.join('; ')}`);
  assertRevisionCheckout(root);
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const retrySlot = structuredClone(predecessor.ledger.slots.find((item) => item.id === 'R-DIAG-DESKTOP'));
  const mobileSlot = structuredClone(predecessor.ledger.slots.find((item) => item.id === 'R-DIAG-MOBILE'));
  retrySlot.id = 'R-INFRA-RETRY-DESKTOP'; retrySlot.sequence = 1; retrySlot.kind = 'diagnostic'; retrySlot.owner_plan = 15;
  mobileSlot.sequence = 2;
  const freeze = structuredClone(predecessor);
  freeze.source = { ...freeze.source, checkout_head: head, blobs: sourceBlobs(root, head) };
  freeze.retry_context = { original_freeze_path: path.relative(root, predecessorFile), original_freeze_sha256: fileHash(predecessorFile), original_evidence_path: path.relative(root, evidenceFile), original_evidence_sha256: fileHash(evidenceFile), review_path: path.relative(root, reviewFile), review_sha256: fileHash(reviewFile), original_source: prior.source, original_failure: prior.attempts[0].failure_detail, retry_count: 1, retry_budget: 1, retry_reason: review.failure };
  freeze.ledger.slots = [retrySlot, mobileSlot];
  freeze.ledger.historical_charge_ms = 33884;
  freeze.ledger.d19.max_charged_duration_ms = 18 * 60 * 1000;
  const reservation = { schema_version: 'sigra.phase253.registration-shared-retry/v1', status: 'reserved', retry_count: 1, budget: 1, charge_before_ms: 33884, max_duration_ms: 120000, source_commit: head, original_evidence_sha256: fileHash(evidenceFile), review_sha256: fileHash(reviewFile), slot_id: retrySlot.id };
  writeJson(reservationFile, reservation);
  freeze.infrastructure_retry = { reservation_path: path.relative(root, reservationFile), reservation_sha256: fileHash(reservationFile), used_marker_path: RETRY_MARKER_PATH, count: 1, max_duration_ms: 120000, consumed: false };
  delete freeze.freeze_sha256; freeze.freeze_sha256 = revisionFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return { freeze, reservation };
}

function refreshInfrastructureRetry(predecessorFile, outputFile, root = ROOT) {
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite an infrastructure retry source freeze');
  const predecessor = readJson(predecessorFile);
  if (!predecessor.retry_context || predecessor.infrastructure_retry?.count !== 1) throw new Error('source freeze does not carry the one reviewed infrastructure retry');
  const marker = path.resolve(root, predecessor.infrastructure_retry.used_marker_path);
  if (fs.existsSync(marker)) throw new Error('the shared infrastructure retry has already been consumed; source cannot be refreshed');
  if (predecessor.freeze_sha256 !== revisionFreezeDigest(predecessor)) throw new Error('prior retry source freeze digest is invalid');
  const priorReservations = path.resolve(root, predecessor.infrastructure_retry.reservation_path);
  if (fileHash(priorReservations) !== predecessor.infrastructure_retry.reservation_sha256) throw new Error('shared retry reservation bytes changed before source refresh');
  const oldMarker = path.resolve(root, predecessor.infrastructure_retry.used_marker_path);
  if (fs.existsSync(oldMarker)) throw new Error('the shared infrastructure retry has already been consumed; source cannot be refreshed');
  const phaseDir = path.join(root, PHASE_DIR);
  for (const [file, digest] of [
    [path.resolve(root, predecessor.retry_context.original_evidence_path), predecessor.retry_context.original_evidence_sha256],
    [path.resolve(root, predecessor.retry_context.original_freeze_path), predecessor.retry_context.original_freeze_sha256],
    [path.resolve(root, predecessor.retry_context.review_path), predecessor.retry_context.review_sha256],
    [path.join(phaseDir, '253-RECOVERY-REGISTRATION-FREEZE.json'), predecessor.historical.original_freeze_sha256],
    [path.join(phaseDir, '253-RECOVERY-REGISTRATION-EVIDENCE.json'), predecessor.historical.original_evidence_sha256],
    [path.join(phaseDir, '253-09-TERMINAL-DIAGNOSTIC.json'), predecessor.historical.terminal_diagnostic_sha256],
    [path.resolve(root, predecessor.historical.recovery_capture_path), predecessor.historical.recovery_capture_sha256]
  ]) if (fileHash(file) !== digest) throw new Error(`preserved retry source evidence changed: ${path.relative(root, file)}`);
  assertRevisionCheckout(root);
  const freeze = structuredClone(predecessor);
  freeze.supersedes_retry_source = { path: path.relative(root, predecessorFile), sha256: fileHash(predecessorFile), source_commit: predecessor.source.checkout_head, native_attempts: 0, retry_reservation_preserved: true };
  freeze.source.checkout_head = git(['-C', root, 'rev-parse', 'HEAD']);
  freeze.source.blobs = sourceBlobs(root, freeze.source.checkout_head);
  delete freeze.freeze_sha256;
  freeze.freeze_sha256 = revisionFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return freeze;
}

function checkCleanCandidate(root) {
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const status = run('git', ['-C', root, 'status', '--porcelain', '--untracked-files=all']);
  if (status.status !== 0) throw new Error('cannot read checkout status');
  if (status.stdout.trim()) throw new Error('candidate checkout must be clean before freezing or running recovery');
  return head;
}

function readGitBlob(root, reference) {
  const type = run('git', ['-C', root, 'cat-file', '-t', reference]);
  if (type.status !== 0 || type.stdout.trim() !== 'blob') throw new Error(`preservation ref is not a readable blob: ${reference}`);
  const result = spawnSync('git', ['-C', root, 'cat-file', 'blob', reference], { encoding: null, maxBuffer: 8 * 1024 * 1024 });
  if (result.status !== 0) throw new Error(`cannot read preserved bytes from ${reference}`);
  return result.stdout;
}

export function assertDirtyConfigPreserved(root, identity = DIRTY_CONFIG) {
  // A clean candidate (the server-published tree) carries no dirty config and has nothing to preserve.
  // A checkout that does carry any change to it must match the exact authorized identity.
  const status = run('git', ['-C', root, 'status', '--porcelain=v1', '--', identity.path]);
  if (status.status !== 0) throw new Error('cannot read candidate config status');
  if (!status.stdout.trim()) return { required: false };
  const file = path.join(root, identity.path);
  const bytes = fs.readFileSync(file);
  if (sha256(bytes) !== identity.sha256 || git(['-C', root, 'hash-object', file]) !== identity.blob) {
    throw new Error('the unrelated planning config no longer matches its authorized SHA-256 and Git blob');
  }
  if (!bytes.equals(readGitBlob(root, identity.ref))) {
    throw new Error('the unrelated planning config does not match the exact bytes in its preservation ref');
  }
  return { required: true };
}

function assertRevisionCheckout(root, evidenceFile = null) {
  assertDirtyConfigPreserved(root);
  const status = run('git', ['-C', root, 'status', '--porcelain=v1', '--untracked-files=all']);
  if (status.status !== 0) throw new Error('cannot read candidate checkout status');
  const expectedEvidence = evidenceFile ? path.relative(root, evidenceFile) : null;
  const lines = status.stdout.split('\n').filter(Boolean);
  const seenConfig = lines.filter((line) => line === DIRTY_CONFIG.porcelain).length;
  if (seenConfig !== 1) throw new Error(`candidate must retain exactly the preserved config status '${DIRTY_CONFIG.status}'`);
  for (const line of lines) {
    if (line === DIRTY_CONFIG.porcelain) continue;
    const code = line.slice(0, 2);
    const file = line.slice(3).replace(/^"|"$/g, '');
    if (file === RETRY_MARKER_PATH && code === '??') continue;
    if (expectedEvidence && file === expectedEvidence && [' M', '??'].includes(code)) continue;
    if (expectedEvidence && (file === `${expectedEvidence}.raw` || file.startsWith(`${expectedEvidence}.raw/`)) && code === '??') continue;
    throw new Error(`candidate checkout contains an unapproved change: ${line}`);
  }
  const staged = run('git', ['-C', root, 'diff', '--cached', '--quiet']);
  if (staged.status !== 0) throw new Error('staged changes are not allowed while running a frozen registration slot');
  const tracked = run('git', ['-C', root, 'diff', '--name-status']);
  if (tracked.status !== 0) throw new Error('cannot read tracked source changes');
  const allowedTracked = new Set([DIRTY_CONFIG.path, ...(expectedEvidence ? [expectedEvidence] : [])]);
  for (const line of tracked.stdout.split('\n').filter(Boolean)) {
    const file = line.split('\t').at(-1);
    if (!allowedTracked.has(file)) throw new Error(`tracked source changed after freeze: ${file}`);
  }
  return git(['-C', root, 'rev-parse', 'HEAD']);
}

const FIRST_CONTROLS = [
  'registration waits for explicitly released LiveView readiness',
  'registration stops when LiveView readiness is never released',
  'registration fails when the readiness wait is deliberately broken',
  'registration detects a deliberate same-account collision',
  'registration retains the first forced assertion failure trace'
];
const SECOND_CONTROLS = [
  'registration starts from a fresh database and context',
  'registration discards trace after a passing control',
  'registration regression passes after an evidenced repair'
];
const REPLAN_PROJECTS = [
  { name: 'admin-eval', port: 25311 },
  { name: 'admin-eval-mobile', port: 25312 },
  { name: 'admin-eval-dark', port: 25313 }
];

function makeRevisionSlots() {
  const selectedTitle = 'render bundle: board-mg-9/populated';
  const command = (project, title) => [
    '--project=' + project, `--grep=${title}`, '--workers=1', '--retries=0', '--trace=retain-on-failure'
  ];
  const slots = [
    { id: 'R-DIAG-DESKTOP', owner_plan: 15, sequence: 1, kind: 'diagnostic', stage: 'D19', project: 'admin-eval', max_duration_ms: PROJECT_SLOT_MS, title: selectedTitle, argv: command('admin-eval', selectedTitle) },
    { id: 'R-DIAG-MOBILE', owner_plan: 15, sequence: 2, kind: 'diagnostic', stage: 'D19', project: 'admin-eval-mobile', max_duration_ms: PROJECT_SLOT_MS, title: selectedTitle, argv: command('admin-eval-mobile', selectedTitle) },
    { id: 'R-DIAG-CONTROL-DARK', owner_plan: 16, sequence: 3, kind: 'diagnostic_with_controls', stage: 'D19', project: 'admin-eval-dark', max_duration_ms: PROJECT_SLOT_MS, title: selectedTitle, named_cases: [selectedTitle, ...FIRST_CONTROLS], argv: command('admin-eval-dark', `(${[selectedTitle, ...FIRST_CONTROLS].join('|')})`) }
  ];
  for (const [round, titles] of [['first', FIRST_CONTROLS], ['second', SECOND_CONTROLS]]) {
    for (const project of REPLAN_PROJECTS) {
      if (round === 'first' && project.name === 'admin-eval-dark') continue;
      const id = `R-CONTROL-${round.toUpperCase()}-${project.name.replace('admin-eval', '').replace(/^-/, '').toUpperCase() || 'DESKTOP'}`;
      slots.push({ id, owner_plan: 16, sequence: slots.length + 1, kind: 'control', stage: 'D19', round, project: project.name, max_duration_ms: PROJECT_SLOT_MS, named_cases: titles, argv: command(project.name, `(${titles.join('|')})`) });
    }
  }
  const regular = slots.map((slot) => ({ ...slot, selection: { spec: 'tests/admin-eval.spec.ts', title: slot.title ?? null, cases: slot.named_cases ?? null } }));
  const acceptance = [];
  for (const project of REPLAN_PROJECTS) for (let repeat = 1; repeat <= 3; repeat++) {
    acceptance.push({ id: `D20-ACCEPT-${project.name}-${repeat}`, owner_plan: 17, kind: 'acceptance', stage: 'D20', project: project.name, repeat, max_duration_ms: 240_000 });
  }
  return { regular, acceptance };
}

function createRevision(output, root = ROOT) {
  if (fs.existsSync(output)) throw new Error(`refusing to overwrite an existing revision freeze: ${output}`);
  const head = assertRevisionCheckout(root);
  const phaseDir = path.join(root, PHASE_DIR);
  const oldFreezePath = path.join(phaseDir, '253-RECOVERY-REGISTRATION-FREEZE.json');
  const oldEvidencePath = path.join(phaseDir, '253-RECOVERY-REGISTRATION-EVIDENCE.json');
  const terminalPath = path.join(phaseDir, '253-09-TERMINAL-DIAGNOSTIC.json');
  const capturePath = path.join(phaseDir, '253-ADDITIONAL-EXECUTION-CAPTURE.json');
  const predecessorPath = path.join(phaseDir, '253-REPLAN-REGISTRATION-FREEZE.json');
  const oldFreeze = readJson(oldFreezePath);
  const oldEvidence = readJson(oldEvidencePath);
  const terminal = readJson(terminalPath);
  const capture = readJson(capturePath);
  const existingEvidencePath = path.join(phaseDir, '253-REPLAN-REGISTRATION-EVIDENCE.json');
  let supersededRevision = null;
  if (fs.existsSync(existingEvidencePath)) {
    const previousEvidence = readJson(existingEvidencePath);
    const previousFreezePath = path.resolve(root, previousEvidence.freeze_path ?? '');
    const previousFreeze = readJson(previousFreezePath);
    if (!Array.isArray(previousEvidence.attempts) || previousEvidence.attempts.length !== 0
      || previousEvidence.limits?.browser_launches !== 0 || previousEvidence.limits?.used_slots?.length !== 0
      || previousEvidence.preparation_status !== 'passed') {
      throw new Error('only a zero-native-launch preparation ledger can transfer to a corrected source freeze');
    }
    supersededRevision = {
      freeze_path: path.relative(root, previousFreezePath), freeze_sha256: fileHash(previousFreezePath),
      evidence_path: path.relative(root, existingEvidencePath), evidence_sha256: fileHash(existingEvidencePath),
      source_commit: previousFreeze.source.checkout_head, preparation_charge_ms: previousEvidence.limits.preparation_charge_ms,
      native_attempts: 0, browser_launches: 0, capacity_added: false
    };
  }
  if (terminal.status !== 'halted' || terminal.attempt?.slot !== 'D19-DIAG-01' || terminal.attempt?.browser_launched !== false || terminal.attempt?.charged_duration_ms !== 3768) {
    throw new Error('the original terminal diagnostic does not prove the spent 3,768 ms zero-launch slot');
  }
  if (oldEvidence.status !== 'halted' || oldEvidence.limits?.browser_launches !== 0 || oldEvidence.limits?.charged_duration_ms !== 3768) {
    throw new Error('the original registration evidence does not preserve the halted zero-launch charge');
  }
  if (capture.dirty_config?.status !== DIRTY_CONFIG.status || capture.dirty_config?.sha256 !== DIRTY_CONFIG.sha256
    || capture.dirty_config?.ref !== DIRTY_CONFIG.ref || capture.dirty_config?.blob !== DIRTY_CONFIG.blob) {
    throw new Error('the prior capture does not match the exact unrelated config preservation');
  }
  const slots = makeRevisionSlots();
  const freeze = {
    schema_version: REPLAN_FREEZE_SCHEMA, status: 'frozen_before_results', frozen_at: new Date().toISOString(),
    source: { repository: 'szTheory/sigra', checkout_head: head, tracked_worktree_clean_except_exact_preserved_config: true, blobs: sourceBlobs(root, head) },
    historical: {
      original_freeze_path: path.relative(root, oldFreezePath), original_freeze_sha256: fileHash(oldFreezePath),
      original_evidence_path: path.relative(root, oldEvidencePath), original_evidence_sha256: fileHash(oldEvidencePath),
      terminal_diagnostic_path: path.relative(root, terminalPath), terminal_diagnostic_sha256: fileHash(terminalPath),
      recovery_capture_path: path.relative(root, capturePath), recovery_capture_sha256: fileHash(capturePath),
      spent_slot_id: 'D19-DIAG-01', spent_browser_launches: 0, spent_charged_ms: 3768,
      rejected_original_log_hashes: terminal.redacted_logs.map((entry) => ({ path: entry.path, sha256: entry.sha256, accepted_as_native_receipt: false })),
      preceding_order: 'unknown', preceding_order_reason: 'The archived original preceding-order log is absent.'
    },
    supersedes_zero_work_freeze: fs.existsSync(predecessorPath) && path.resolve(output) !== path.resolve(predecessorPath)
      ? { path: path.relative(root, predecessorPath), sha256: fileHash(predecessorPath), native_work_started: false, preparation_work_started: false, capacity_added: false }
      : null,
    supersedes_source_revision: supersededRevision,
    preparation: { id: 'D19-COMMON-PREPARATION', max_duration_ms: 116232, charged_duration_ms: supersededRevision?.preparation_charge_ms ?? 0, inherited_from: supersededRevision?.freeze_path ?? null, allowed: ['npm ci using the existing lockfile', 'node --version', 'Playwright --version', 'mix --version', 'MIX_ENV=dev mix deps version observation'], prohibits: ['application boot', 'HTTP request', 'browser launch', 'endpoint compilation', 'database setup'] },
    ledger: {
      historical_charge_ms: 3768, spent_reservations: [{ id: 'D19-DIAG-01', browser_launches: 0, charged_ms: 3768, outcome: 'halted_setup_and_drop_exit_1' }],
      slots: slots.regular, acceptance_slots: slots.acceptance,
      d19: { regular_command_reservations: 8, each_max_duration_ms: 120000, max_charged_duration_ms: 1080000, retry: { count: 1, max_duration_ms: 120000, requires_independent_infrastructure_diagnosis: true } },
      d20: { acceptance_command_reservations: 9, each_max_duration_ms: 240000, max_charged_duration_ms: 2160000, retry: { count: 1, max_duration_ms: 240000, requires_independent_infrastructure_diagnosis: true } },
      shared_retry_count: 1, max_new_browser_launches: 18, max_charged_duration_ms: TOTAL_CAP_MS,
      max_total_charged_ms_including_historical: 58 * 60 * 1000,
      unused_slot_mapping: [
        { id: 'R-DIAG-DESKTOP', old_slot: 'D19-DIAG-02', owner: '253-15' },
        { id: 'R-DIAG-MOBILE', old_slot: 'D19-DIAG-03', owner: '253-15' },
        { id: 'R-DIAG-CONTROL-DARK', old_slot: 'D19-CONTROL-03', owner: '253-16', combined: true },
        { id: 'R-CONTROL-FIRST-DESKTOP', old_slot: 'D19-CONTROL-01', owner: '253-16' },
        { id: 'R-CONTROL-FIRST-MOBILE', old_slot: 'D19-CONTROL-02', owner: '253-16' },
        { id: 'R-CONTROL-SECOND-DESKTOP', old_slot: 'D19-CONTROL-04', owner: '253-16' },
        { id: 'R-CONTROL-SECOND-MOBILE', old_slot: 'D19-CONTROL-05', owner: '253-16' },
        { id: 'R-CONTROL-SECOND-DARK', old_slot: 'D19-CONTROL-06', owner: '253-16' }
      ]
    },
    tools: { playwright_required: '1.59.1', playwright_lock_blob: sourceBlobs(root, head)['test/example/priv/playwright/package-lock.json'], ecto_sql: null, phoenix_live_view: null },
    stop_conditions: ['source or config mismatch', 'missing/empty/forged native report', 'process and report status mismatch', 'failed setup/drop/cleanup', 'port collision', 'slot or cumulative clock exhaustion', 'unknown infrastructure outcome']
  };
  freeze.freeze_sha256 = sha256(JSON.stringify(freeze));
  writeJson(output, freeze);
  return freeze;
}

function sourceBlobs(root, head) {
  return Object.fromEntries(SOURCE_FILES.map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`])]));
}

function checkFrozenSource(root, freeze) {
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const ancestor = run('git', ['-C', root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]);
  if (ancestor.status !== 0) throw new Error(`candidate commit ${freeze.source.checkout_head} is not an ancestor of ${head}`);
  const status = run('git', ['-C', root, 'status', '--porcelain', '--untracked-files=all']);
  if (status.status !== 0) throw new Error('cannot read checkout status after freeze');
  const evidencePrefix = `${PHASE_DIR}/253-RECOVERY-REGISTRATION-EVIDENCE.json`;
  const allowedUntracked = status.stdout.split('\n').filter(Boolean).every((line) => {
    const file = line.slice(3).replace(/^"|"$/g, '');
    return file === evidencePrefix || file.startsWith(`${evidencePrefix}.raw/`);
  });
  const trackedClean = run('git', ['-C', root, 'diff', '--quiet']).status === 0
    && run('git', ['-C', root, 'diff', '--cached', '--quiet']).status === 0;
  if (!trackedClean || !allowedUntracked) throw new Error('tracked source or unrelated untracked checkout changes are not allowed after freeze');
  for (const [file, expected] of Object.entries(freeze.source.blobs)) {
    const actual = git(['-C', root, 'hash-object', file]);
    if (actual !== expected) throw new Error(`source identity mismatch for ${file}: ${actual}`);
  }
  return head;
}

function playReportTests(report) {
  const found = [];
  const visit = (suite) => {
    for (const spec of suite.specs ?? []) {
      for (const test of spec.tests ?? []) {
        for (const result of test.results ?? []) {
          found.push({ title: spec.title, file: spec.file ?? suite.file ?? '', project: test.projectName ?? '',
            expected_status: test.expectedStatus ?? null, summary_status: test.status ?? null,
            status: result.status, duration: result.duration, worker_index: result.workerIndex ?? null, result_count: test.results?.length ?? 0,
            error: result.error ?? null, attachments: result.attachments ?? [],
            annotations: test.annotations ?? [], result_annotations: result.annotations ?? [] });
        }
      }
    }
    for (const child of suite.suites ?? []) visit(child);
  };
  for (const suite of report.suites ?? []) visit(suite);
  return found;
}

function confinedFile(baseDir, reference) {
  if (!reference || typeof reference.path !== 'string' || path.isAbsolute(reference.path)) return null;
  const resolved = path.resolve(baseDir, reference.path);
  const relative = path.relative(baseDir, resolved);
  if (relative.startsWith('..') || path.isAbsolute(relative)) return null;
  return resolved;
}

export function verifyNativeAttempt(attempt, freeze, baseDir) {
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!attempt || typeof attempt !== 'object') return { ok: false, errors: ['attempt is missing'] };
  const slot = freeze.ledger?.slots?.find((item) => item.id === attempt.slot_id);
  if (!slot) fail('attempt does not identify a frozen slot');
  else {
    if (slot.kind !== 'diagnostic' || slot.stage !== 'D19') fail('attempt consumed a non-diagnostic or non-D19 slot');
    if (slot.project !== attempt.project) fail('attempt project does not match its frozen slot');
    if (slot.sequence !== attempt.sequence) fail('attempt order does not match its frozen slot');
    if (!Number.isFinite(attempt.charged_duration_ms) || attempt.charged_duration_ms < 0 || attempt.charged_duration_ms > slot.max_duration_ms) fail('attempt exceeds or omits its reserved slot time');
    const expectedSetupMs = slot.sequence === 1 ? freeze.ledger.prelaunch_setup?.duration_ms : 0;
    if (attempt.prelaunch_setup_ms !== expectedSetupMs) fail('prelaunch dependency setup charge differs from its frozen receipt');
  }
  if (attempt.source_commit !== freeze.source.checkout_head) fail('attempt source commit differs from the freeze');
  const startNs = BigInt(attempt.started_monotonic_ns ?? 0);
  const endNs = BigInt(attempt.ended_monotonic_ns ?? 0);
  if (startNs <= 0n || endNs <= startNs) fail('attempt monotonic start/end timestamps are missing or invalid');
  else if (Math.ceil(Number(endNs - startNs) / 1e6) !== attempt.execution_duration_ms) fail('attempt execution duration does not match its monotonic timestamps');
  if (attempt.charged_duration_ms !== attempt.execution_duration_ms + (attempt.prelaunch_setup_ms ?? 0)) fail('attempt total charge omits or duplicates prelaunch setup');
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    const reference = attempt.files?.[name];
    const file = confinedFile(baseDir, reference);
    if (!file || !fs.existsSync(file)) { fail(`missing native ${name.replaceAll('_', ' ')}`); continue; }
    if (!reference.sha256 || fileHash(file) !== reference.sha256) fail(`native ${name.replaceAll('_', ' ')} digest mismatch`);
    if (fs.statSync(file).size === 0) fail(`native ${name.replaceAll('_', ' ')} is empty`);
  }
  if (attempt.database?.drop_exit_code !== 0) fail('database drop did not succeed');
  if (!attempt.database?.name || !/^sigra_253_recovery_[a-z0-9_]+$/.test(attempt.database.name)) fail('database identity is absent or outside the synthetic recovery namespace');
  if (attempt.server?.http_status !== 200 && attempt.browser?.launched) fail('browser launched without an HTTP 200 application readiness receipt');
  if (attempt.browser?.launched) {
    if (!Number.isInteger(attempt.browser.exit_code)) fail('browser command exit code is missing');
    const reportRef = attempt.files?.playwright_report;
    const reportPath = confinedFile(baseDir, reportRef);
    if (!reportPath || !fs.existsSync(reportPath)) fail('native Playwright report is missing');
    else {
      if (!reportRef.sha256 || fileHash(reportPath) !== reportRef.sha256) fail('native Playwright report digest mismatch');
      try {
        const report = readJson(reportPath);
        const tests = playReportTests(report);
        if (!tests.length) fail('native Playwright report contains no test results');
        const selected = tests.filter((item) => item.title === freeze.selection.test_title && item.project === attempt.project);
        if (!selected.length) fail('native report omits the exact selected project/test');
        if (selected.some((item) => item.status === 'skipped' || item.status === 'interrupted')) fail('selected native test did not complete');
        const passed = selected.every((item) => item.status === 'expected');
        if ((attempt.browser.exit_code === 0) !== passed) fail('native report result disagrees with the browser command exit');
        if (attempt.observed_outcome !== (passed ? 'passed' : 'failed')) fail('caller classification disagrees with the native browser result');
      } catch (error) {
        if (error instanceof SyntaxError) fail('native Playwright report is malformed JSON');
        else fail(`native Playwright report could not be read: ${error.message}`);
      }
    }
    if (attempt.browser.exit_code !== 0) {
      const traceRefs = attempt.files?.traces ?? [];
      const validTrace = traceRefs.some((reference) => {
        const file = confinedFile(baseDir, reference);
        return file && fs.existsSync(file) && reference.sha256 && fileHash(file) === reference.sha256 && fs.statSync(file).size > 0;
      });
      if (!validTrace) fail('failed browser attempt has no retained native trace with a verified digest');
    }
  } else {
    if (attempt.browser?.exit_code !== null) fail('setup-only attempt must record a null browser exit');
    if (attempt.observed_outcome !== 'setup_failed') fail('setup-only attempt is not classified as a setup failure');
  }
  for (const name of ['playwright_version', 'ecto_sql_version', 'phoenix_live_view_version']) {
    if (!attempt.toolchain?.[name]) fail(`observed toolchain omits ${name}`);
  }
  return { ok: errors.length === 0, errors };
}

export function verifyDiagnosticData(evidence, freeze, baseDir) {
  const errors = [];
  if (evidence?.schema_version !== SCHEMA) errors.push('unrecognized recovery evidence schema');
  if (!freeze || freeze.schema_version !== FREEZE_SCHEMA || freeze.status !== 'frozen_before_results') errors.push('new recovery freeze is missing or invalid');
  if (evidence?.freeze_sha256 !== freeze?.freeze_sha256) errors.push('evidence is not bound to the committed freeze bytes');
  if (evidence?.source?.checkout_head !== freeze?.source?.checkout_head) errors.push('evidence source differs from the recovery freeze');
  if (JSON.stringify(evidence?.source?.blobs) !== JSON.stringify(freeze?.source?.blobs)) errors.push('evidence source blob map differs from the recovery freeze');
  if (evidence?.historical?.preceding_order !== 'unknown') errors.push('unavailable preceding test order is not preserved as unknown');
  if (evidence?.historical?.original_evidence_sha256 !== freeze?.historical?.original_evidence_sha256) errors.push('original evidence identity does not match the freeze');
  const attempts = evidence?.attempts;
  if (!Array.isArray(attempts)) errors.push('attempt list is missing');
  else {
    const seen = new Set();
    let launches = 0;
    let charged = 0;
    let d19 = 0;
    const diagnostics = freeze.ledger?.slots?.filter((item) => item.kind === 'diagnostic') ?? [];
    for (const [index, attempt] of attempts.entries()) {
      if (seen.has(attempt.slot_id)) errors.push(`duplicate slot ${attempt.slot_id}`);
      seen.add(attempt.slot_id);
      if (diagnostics[index]?.id !== attempt.slot_id) errors.push('diagnostic slot order differs from the frozen project order');
      const result = verifyNativeAttempt(attempt, freeze, baseDir);
      errors.push(...result.errors.map((message) => `${attempt.project ?? 'unknown project'}: ${message}`));
      charged += Number(attempt.charged_duration_ms) || 0;
      if (attempt.browser?.launched) launches++;
      if (attempt.stage === 'D19') d19 += Number(attempt.charged_duration_ms) || 0;
    }
    if (launches !== evidence?.limits?.browser_launches) errors.push('browser launch counter does not match native attempt records');
    if (charged !== evidence?.limits?.charged_duration_ms) errors.push('cumulative charged duration does not match the attempt ledger');
    if (launches > freeze.ledger.max_launches) errors.push('shared launch ceiling exceeded');
    if (charged > freeze.ledger.max_charged_duration_ms) errors.push('shared charged-duration ceiling exceeded');
    if (d19 > freeze.ledger.d19.max_charged_duration_ms) errors.push('D-19 reproduction budget exceeded');
    for (const project of freeze.selection.projects) {
      const projectAttempts = attempts.filter((item) => item.project === project);
      if (projectAttempts.length > 1) errors.push(`${project} has more than one initial diagnostic slot`);
    }
    if (evidence.status === 'not_reproduced' && attempts.length !== freeze.selection.projects.length) errors.push('incomplete project set is labeled not_reproduced');
    if (!['running', 'not_reproduced', 'diagnosis_incomplete', 'halted'].includes(evidence.status)) errors.push('invalid or unsupported evidence status');
    if (evidence.status !== 'running' && evidence.status !== 'not_reproduced' && !evidence.stop_reason) errors.push('terminal incomplete evidence lacks an exact stop reason');
  }
  return { ok: errors.length === 0, errors };
}

function observedMixVersion(root, packageName) {
  const result = run('mix', ['deps'], { cwd: path.join(root, 'test/example'), timeout: 60_000 });
  if (result.status !== 0) throw new Error(`cannot observe example dependency versions: ${result.stderr.trim()}`);
  const line = result.stdout.split('\n').find((entry) => entry.startsWith(`* ${packageName} `));
  const version = line?.match(/^\* .+ ([0-9]+\.[0-9]+\.[0-9]+) /)?.[1];
  if (!version) throw new Error(`cannot identify resolved ${packageName} version`);
  return version;
}

function createFreeze(output, root = ROOT) {
  if (fs.existsSync(output)) {
    const preservedRevision = path.join(root, PHASE_DIR, '253-RECOVERY-REGISTRATION-FREEZE-REVISION-04.json');
    const preservedHash = '127c445addd23c59d871670e6b06f0b9c42714ecccecfb482e4b628483ce228a';
    if (!fs.existsSync(preservedRevision) || fileHash(preservedRevision) !== preservedHash || fileHash(output) !== preservedHash) {
      throw new Error(`refusing to overwrite an unpreserved recovery freeze: ${output}`);
    }
  }
  const head = checkCleanCandidate(root);
  const preflightPath = path.join(root, PHASE_DIR, '253-09-PREFLIGHT-SETUP.json');
  const preflight = readJson(preflightPath);
  const runnerFailurePath = path.join(root, PHASE_DIR, '253-09-RUNNER-PREFLIGHT-FAILURE.json');
  const runnerFailure = readJson(runnerFailurePath);
  const directoryCollisionPath = path.join(root, PHASE_DIR, '253-09-RUNNER-DIRECTORY-COLLISION.json');
  const directoryCollision = readJson(directoryCollisionPath);
  if (preflight.schema_version !== 'sigra.phase253.registration-preflight/v1' || preflight.status !== 'passed' || preflight.exit_code !== 0 || preflight.playwright_version !== '1.59.1') {
    throw new Error('measured lockfile Playwright restore is missing or failed');
  }
  if (Math.ceil(Number(BigInt(preflight.ended_monotonic_ns) - BigInt(preflight.started_monotonic_ns)) / 1e6) !== preflight.duration_ms) {
    throw new Error('preflight setup receipt duration does not match its monotonic timestamps');
  }
  if (runnerFailure.schema_version !== 'sigra.phase253.registration-runner-preflight-failure/v1' || runnerFailure.browser_launches !== 0 || runnerFailure.child_processes_spawned?.length !== 0 || runnerFailure.slot !== 'D19-DIAG-01') {
    throw new Error('the preserved runner timeout receipt is missing, malformed, or claims a browser launch');
  }
  if (directoryCollision.schema_version !== 'sigra.phase253.registration-runner-preflight-failure/v1' || directoryCollision.browser_launches !== 0 || directoryCollision.child_processes_spawned?.length !== 0 || directoryCollision.slot !== 'D19-DIAG-01') {
    throw new Error('the preserved raw-directory collision receipt is missing, malformed, or claims a browser launch');
  }
  const lock = readJson(path.join(root, 'test/example/priv/playwright/package-lock.json'));
  const playwrightVersion = lock.packages?.['node_modules/@playwright/test']?.version;
  if (playwrightVersion !== '1.59.1' || lock.packages?.['node_modules/playwright']?.version !== '1.59.1') {
    throw new Error('the locked Playwright version is not 1.59.1');
  }
  let installedVersion;
  try { installedVersion = readJson(path.join(root, 'test/example/priv/playwright/node_modules/@playwright/test/package.json')).version; }
  catch { throw new Error('Playwright 1.59.1 is not installed; restore the committed lockfile before freezing'); }
  if (installedVersion !== '1.59.1') throw new Error(`installed Playwright version ${installedVersion} does not match locked 1.59.1`);
  const versions = {
    ecto_sql: observedMixVersion(root, 'ecto_sql'),
    phoenix_live_view: observedMixVersion(root, 'phoenix_live_view')
  };
  const oldFreeze = readJson(path.join(root, PHASE_DIR, '253-REPRO-FREEZE.json'));
  const oldEvidence = readJson(path.join(root, PHASE_DIR, '253-REGISTRATION-EVIDENCE.json'));
  const setupReceiptPath = path.join(root, '.planning/debug/phase253-setup-final-20261013T125238Z/manifest.json');
  const originalEvidencePath = path.join(root, PHASE_DIR, '253-REGISTRATION-EVIDENCE.json');
  const slots = PROJECTS.map((project, index) => ({
    id: `D19-DIAG-${String(index + 1).padStart(2, '0')}`,
    sequence: index + 1,
    kind: 'diagnostic', stage: 'D19', project: project.name,
    max_duration_ms: PROJECT_SLOT_MS,
    selection: { spec: 'tests/admin-eval.spec.ts', test_title: oldFreeze.selection.grep, project: project.name }
  }));
  const controlRounds = [
    ['first', [
      { title: 'registration waits for explicitly released LiveView readiness', expected: 'pass after signal release' },
      { title: 'registration stops when LiveView readiness is never released', expected: 'bounded expected failure' },
      { title: 'registration fails when the readiness wait is deliberately broken', expected: 'assertion failure with retained trace' },
      { title: 'registration detects a deliberate same-account collision', expected: 'collision is detected and recorded' },
      { title: 'registration retains the first forced assertion failure trace', expected: 'assertion failure with useful trace and original exit' }
    ]],
    ['second', [
      { title: 'registration starts from a fresh database and context', expected: 'pass with a new database and context' },
      { title: 'registration discards trace after a passing control', expected: 'pass and no trace artifact' },
      { title: 'registration regression passes after an evidenced repair', expected: 'pass only after a cause-backed repair; otherwise slot expires' }
    ]]
  ];
  for (const [round, namedCases] of controlRounds) for (const project of PROJECTS) {
    slots.push({
      id: `D19-CONTROL-${String(slots.length - 2).padStart(2, '0')}`,
      sequence: slots.length + 1,
      kind: 'control', stage: 'D19', project: project.name,
      round, named_cases: namedCases,
      max_duration_ms: PROJECT_SLOT_MS,
      selection: { spec: 'tests/admin-eval.spec.ts', project: project.name, body: 'Plan 10 frozen named browser control bundle' }
    });
  }
  slots.push({ id: 'D19-INFRA-RETRY', kind: 'infrastructure_retry', stage: 'shared', flexible: true, requires_independent_diagnosis: true, max_duration_ms: PROJECT_SLOT_MS });
  for (const project of PROJECTS) for (let repeat = 1; repeat <= 3; repeat++) {
    slots.push({ id: `D20-ACCEPT-${project.name}-${repeat}`, kind: 'acceptance', stage: 'D20', project: project.name, repeat, max_duration_ms: 4 * 60 * 1000 });
  }
  const freeze = {
    schema_version: FREEZE_SCHEMA,
    status: 'frozen_before_results',
    frozen_at: new Date().toISOString(),
    source: {
      repository: 'szTheory/sigra', checkout_head: head, tracked_worktree_clean: true,
      execution_checkout: 'current clean checkout; each app/database/context is created fresh per frozen slot',
      blobs: sourceBlobs(root, head),
      playwright_lock_version: playwrightVersion,
      host_dependency_versions: versions
    },
    tools: {
      node: run('node', ['--version']).stdout.trim(),
      mix: run('mix', ['--version'], { cwd: path.join(root, 'test/example') }).stdout.trim().split('\n')[0],
      playwright_cli_version_required: '1.59.1',
      ecto_sql: versions.ecto_sql,
      phoenix_live_view: versions.phoenix_live_view
    },
    selection: {
      spec: 'tests/admin-eval.spec.ts', test_title: oldFreeze.selection.grep,
      account_selection: 'board-mg-9/populated', projects: PROJECTS.map((project) => project.name),
      retries: 0, workers: 1, fully_parallel: false, trace: 'retain-on-failure',
      isolated_database_per_slot: true, isolated_context_per_slot: true,
      five_ci_browser_seams: [
        {
          seam: 'admin_behavior', step_id: 'admin_behavior',
          specs: ['tests/admin-user-operations.spec.ts', 'tests/impersonation.spec.ts', 'tests/admin-audit.spec.ts', 'tests/admin-theme.spec.ts', 'tests/admin-coherence-sweep.spec.ts', 'tests/admin-modal-interaction.spec.ts', 'tests/admin-flow-platform-admin.spec.ts', 'tests/admin-flow-support-investigator.spec.ts', 'tests/admin-flow-org-admin.spec.ts'],
          projects: ['chromium'], retries: 0, body: 'same selected spec list for --list and execution'
        },
        {
          seam: 'admin_checkpoints', step_id: 'admin_checkpoints', specs: ['tests/admin-checkpoints.spec.ts'],
          projects: ['admin-checkpoints-chromium', 'admin-checkpoints-mobile', 'admin-checkpoints-dark'], retries: 0, body: 'same selected spec and project list for --list and execution'
        },
        {
          seam: 'design_gallery', step_ids: ['design_gallery', 'design_gallery_snapshots'], specs: ['tests/admin-design.spec.ts'],
          pull_request: { projects: ['admin-design-chromium', 'admin-design-mobile', 'admin-design-dark'], grep_invert: '@snapshot', retries: 0 },
          non_pull_request: [
            { projects: ['admin-design-chromium', 'admin-design-mobile', 'admin-design-dark'], grep: '@snapshot', retries: 0 },
            { projects: ['admin-design-chromium', 'admin-design-mobile', 'admin-design-dark'], grep_invert: '@snapshot', retries: 0 }
          ], body: 'PR behavior and non-PR snapshots plus behavior are distinct native selections'
        },
        {
          seam: 'non_admin_smoke', step_id: 'non_admin_smoke',
          specs: ['tests/golden-path.spec.ts', 'tests/ga-uat-shift-left.spec.ts', 'tests/passkeys-hooks.spec.ts', 'tests/organizations.spec.ts', 'tests/passkey-login.spec.ts', 'tests/passkey-options.spec.ts'],
          projects: ['chromium', 'mobile'], retries: 0, body: 'configured project selection for same listed and executed spec list'
        },
        {
          seam: 'demo_showcase', step_id: 'demo_showcase', specs: ['tests/demo-showcase.spec.ts'],
          projects: ['demo-showcase-chromium'], retries: 0, body: 'same selected spec and project for --list and execution'
        }
      ],
      planned_control_contracts: {
        first_bundle: 'D-08/D-09/D-10: five named native cases per project; each has a frozen expected pass/failure.',
        second_bundle: 'D-09/D-10: three named cases per project with fresh database/context and passing-trace cleanup.',
        no_silent_missing_selectors: 'Every selected case must appear in the native Playwright report; a missing selector halts evidence.'
      }
    },
    historical: {
      original_freeze_sha256: fileHash(path.join(root, PHASE_DIR, '253-REPRO-FREEZE.json')),
      original_evidence_sha256: fileHash(originalEvidencePath),
      startup_receipt_path: '.planning/debug/phase253-setup-final-20261013T125238Z/manifest.json',
      startup_receipt_sha256: fileHash(setupReceiptPath),
      original_status: oldEvidence.status,
      original_reproduction_allowance: 'exhausted; not reused',
      preceding_order: 'unknown',
      preceding_order_reason: 'The archived record names the failed project and selected test but has no preceding test order.'
    },
    superseded_unlaunched_freezes: [
      { path: `${PHASE_DIR}/253-RECOVERY-REGISTRATION-FREEZE-REVISION-01.json`, sha256: 'b20adf12b7b07ede9d11a85fd813d90c6c3f4bd7fcdf38eaf564797f06baf5db', commit: '31c966de7f5f4486cf936e83d38406764a1130bb' },
      { path: `${PHASE_DIR}/253-RECOVERY-REGISTRATION-FREEZE-REVISION-02.json`, sha256: 'e57467bb0ce7b57337cd36dd67922d4c63582710c17dcd7073a5be9348a8aa00', commit: 'e402569ad2205a99a2a63fa86aa1956896331ad5' },
      { path: `${PHASE_DIR}/253-RECOVERY-REGISTRATION-FREEZE-REVISION-03.json`, sha256: 'e57467bb0ce7b57337cd36dd67922d4c63582710c17dcd7073a5be9348a8aa00', commit: '094dc5a7913a24fd0126e321a9a854eec7bf8130' },
      { path: `${PHASE_DIR}/253-RECOVERY-REGISTRATION-FREEZE-REVISION-04.json`, sha256: '127c445addd23c59d871670e6b06f0b9c42714ecccecfb482e4b628483ce228a', commit: 'e813c4223' }
    ],
    ledger: {
      slots, max_launches: 19, max_charged_duration_ms: TOTAL_CAP_MS,
      prelaunch_setup: {
        components: [
          { path: path.relative(root, preflightPath), sha256: fileHash(preflightPath), duration_ms: preflight.duration_ms, purpose: 'locked Playwright npm ci restore' },
          { path: path.relative(root, runnerFailurePath), sha256: fileHash(runnerFailurePath), duration_ms: runnerFailure.tool_reported_wall_time_ms, purpose: 'runner timeout preflight failure before child process startup' },
          { path: path.relative(root, directoryCollisionPath), sha256: fileHash(directoryCollisionPath), duration_ms: directoryCollision.tool_reported_wall_time_ms, purpose: 'runner raw-directory collision before child process startup' }
        ],
        duration_ms: preflight.duration_ms + runnerFailure.tool_reported_wall_time_ms + directoryCollision.tool_reported_wall_time_ms,
        charged_to_slot: 'D19-DIAG-01'
      },
      control_round_order: ['first bundle: admin-eval, admin-eval-mobile, admin-eval-dark', 'second bundle: admin-eval, admin-eval-mobile, admin-eval-dark'],
      d19: { max_launches: 10, max_charged_duration_ms: D19_CAP_MS, diagnostic_and_control_slots: 9, max_minutes_per_slot: 2 },
      d20: { max_launches: 10, max_charged_duration_ms: 40 * 60 * 1000, acceptance_slots: 9, max_minutes_per_slot: 4 },
      retry: { count: 1, requires_independent_diagnosis: true, maximum_charged_minutes: 4, charged_to_occurrence_stage: true },
      rules: [
        'All setup, boot, browser, cleanup and failed-attempt elapsed time is charged to the slot and cumulative ledger.',
        'Stop before launch unless its frozen slot and full reserved time fit within every applicable remaining cap.',
        'Plan 09 may consume only D19-DIAG-01 through D19-DIAG-03; Plan 10 controls and acceptance remain reserved.',
        'Unused slots expire. No reset, borrowing, retry wrapper, implicit retry, or extra Playwright command is allowed.',
        'The optional retry is only for an independently diagnosed infrastructure failure and is never automatic.'
      ]
    },
    stop_conditions: ['source mismatch', 'report/log/trace/drop missing or digest mismatch', 'deterministic failure', 'slot limit', 'time limit', 'uncertain infrastructure classification']
  };
  freeze.freeze_sha256 = sha256(JSON.stringify(freeze));
  writeJson(output, freeze);
  return freeze;
}

function referenceFor(baseDir, file) {
  if (!file || !fs.existsSync(file) || !fs.statSync(file).isFile()) return null;
  return { path: path.relative(baseDir, file), sha256: fileHash(file), bytes: fs.statSync(file).size };
}

function httpStatus(url) {
  return new Promise((resolve) => {
    const request = http.get(url, { timeout: 1500 }, (response) => {
      response.resume();
      response.on('end', () => resolve(response.statusCode));
    });
    request.on('timeout', () => request.destroy());
    request.on('error', () => resolve(null));
  });
}

export function portAvailable(port, { connect = net.connect, timeoutMs = 1500 } = {}) {
  return new Promise((resolve) => {
    const socket = connect({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(false); });
    socket.once('error', (error) => { socket.destroy(); resolve(error.code === 'ECONNREFUSED'); });
    socket.setTimeout(timeoutMs, () => { socket.destroy(); resolve(false); });
  });
}

export async function waitReady(child, url, deadline, {
  probe = httpStatus,
  now = () => Number(process.hrtime.bigint()) / 1e6,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
} = {}) {
  while (now() < deadline) {
    if (child.exitCode !== null || child.signalCode !== null) return null;
    const status = await probe(url);
    if (status === 200) return status;
    const remaining = Math.max(0, deadline - now());
    await sleep(Math.min(250, remaining));
  }
  return null;
}

async function stopApp(child) {
  if (!child?.pid || child.exitCode !== null || child.signalCode !== null) return;
  try { process.kill(-child.pid, 'SIGTERM'); } catch { child.kill('SIGTERM'); }
  let timer;
  await Promise.race([
    new Promise((resolve) => child.once('exit', resolve)),
    new Promise((resolve) => { timer = setTimeout(resolve, 4000); })
  ]);
  clearTimeout(timer);
  if (child.exitCode === null && child.signalCode === null) {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); }
  }
}

function sanitizeCommandLog(log) {
  const original = fs.readFileSync(log, 'utf8');
  let redactedSecretFields = 0;
  const withoutSigningKeys = original.replace(/((?:"?secret_key_base"?|:secret_key_base)\s*(?::|=>)\s*")((?:\\.|[^"\\])*)(")/g, (_match, prefix, value, suffix) => {
    if (value === '[REDACTED]') return `${prefix}${value}${suffix}`;
    redactedSecretFields += 1;
    return `${prefix}[REDACTED]${suffix}`;
  });

  let redactedCredentialBlocks = 0;
  const lines = withoutSigningKeys.split(/(?<=\n)/);
  const sanitizedLines = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!/^\s*=== Demo Credentials ===\s*(?:\r?\n)?$/.test(line)) {
      sanitizedLines.push(line);
      continue;
    }

    sanitizedLines.push(line);
    const next = lines[index + 1] ?? '';
    if (next.trim() === '[REDACTED seeded demo credentials]') {
      sanitizedLines.push(next);
      index += 1;
      continue;
    }

    redactedCredentialBlocks += 1;
    let cursor = index + 1;
    while (cursor < lines.length && lines[cursor].trim() !== '') cursor += 1;
    sanitizedLines.push('[REDACTED seeded demo credentials]\n');
    index = cursor - 1;
  }
  const sanitized = sanitizedLines.join('');
  if (sanitized !== original) fs.writeFileSync(log, sanitized);
  return { redacted_secret_fields: redactedSecretFields, redacted_credential_blocks: redactedCredentialBlocks };
}

export function runLogged(program, args, cwd, env, log, timeout) {
  const fd = fs.openSync(log, 'w');
  let result;
  let thrownError = null;
  try {
    result = spawnSync(program, args, { cwd, env, stdio: ['ignore', fd, fd], timeout: Math.max(1, Math.floor(timeout)), killSignal: 'SIGKILL' });
  } catch (error) {
    thrownError = error;
  } finally {
    fs.closeSync(fd);
  }
  // Sanitize before any receipt computes a digest over this persisted log.
  const redactions = sanitizeCommandLog(log);
  if (thrownError) return { exit_code: null, signal: null, error: thrownError.message, ...redactions };
  return { exit_code: result.status, signal: result.signal, error: result.error?.message ?? null, ...redactions };
}

// A bounded process-tree runner must not trust one long relative timer: across host sleep or
// DarkWake a single armed setTimeout can stay unfired for the whole sleep, which let the 253-40
// window run ~29 minutes (the host slept three times; nothing re-checked the deadline). The
// watchdog below re-arms at most every TREE_WATCHDOG_TICK_MS and compares BOTH monotonic and
// wall-clock elapsed time against the deadline, so the first tick that runs after any resume
// kills the tree. A tick gap or wall/monotonic skew beyond TREE_SUSPEND_GAP_MS is recorded as a
// suspension (system sleep or a stalled runner event loop) so callers can refuse the timings.
export const TREE_WATCHDOG_TICK_MS = 250;
export const TREE_SUSPEND_GAP_MS = 5000;

export function runLoggedTree(program, args, cwd, env, log, timeoutMs, cleanupGraceMs = 250, {
  signal: abortSignal = null,
  tickMs = TREE_WATCHDOG_TICK_MS,
  suspendGapMs = TREE_SUSPEND_GAP_MS,
  monotonicNow = () => Number(process.hrtime.bigint()) / 1e6,
  wallNow = () => Date.now(),
  killProcess = (pid, name) => process.kill(pid, name)
} = {}) {
  return new Promise((resolve) => {
    const monoStart = monotonicNow();
    const wallStart = wallNow();
    const limit = Math.max(1, Math.floor(timeoutMs));
    const tick = Math.max(1, Math.floor(tickMs));
    const fd = fs.openSync(log, 'w');
    const grace = Math.max(1, cleanupGraceMs);
    let child;
    let settled = false;
    let timedOut = false;
    let aborted = false;
    let error = null;
    let signal = null;
    let exitCode = null;
    let durationMs = null;
    let wallDurationMs = null;
    let killTimer = null;
    let escalationTimer = null;
    let watchdogTimer = null;
    let reaping = false;
    let suspended = false;
    let maxTickGapMs = 0;
    let lastMono = monoStart;
    let lastWall = wallStart;
    let scheduledDelay = 0;
    const groupSignals = [];
    const monoElapsed = () => monotonicNow() - monoStart;
    const wallElapsed = () => wallNow() - wallStart;
    const groupAlive = () => {
      if (!child?.pid) return false;
      try { killProcess(-child.pid, 0); return true; } catch (cause) { return cause.code === 'EPERM'; }
    };
    const terminateGroup = (name) => {
      if (!child?.pid) return;
      groupSignals.push(name);
      try { killProcess(-child.pid, name); } catch {
        try { child.kill(name); } catch { /* already exited */ }
      }
    };
    // SIGKILL is sent at most once, whichever path (deadline escalation or reap poll) gets there
    // first; a cached flag let both paths send it under load (the 253-39 flake).
    const killGroupOnce = () => {
      if (!groupSignals.includes('SIGKILL')) terminateGroup('SIGKILL');
    };
    const observeClocks = () => {
      const mono = monotonicNow();
      const wall = wallNow();
      const gap = Math.max(mono - lastMono, wall - lastWall) - scheduledDelay;
      lastMono = mono;
      lastWall = wall;
      if (gap > maxTickGapMs) maxTickGapMs = Math.ceil(gap);
      const skew = Math.abs((wall - wallStart) - (mono - monoStart));
      if (gap > suspendGapMs || skew > suspendGapMs) suspended = true;
      return Math.max(mono - monoStart, wall - wallStart);
    };
    const finish = (reaped) => {
      if (settled) return;
      settled = true;
      clearTimeout(watchdogTimer);
      clearTimeout(killTimer);
      clearTimeout(escalationTimer);
      abortSignal?.removeEventListener('abort', onAbort);
      observeClocks();
      fs.closeSync(fd);
      const redactions = sanitizeCommandLog(log);
      resolve({
        pid: child?.pid ?? null,
        exit_code: exitCode, signal, error, timed_out: timedOut, aborted,
        duration_ms: durationMs ?? Math.ceil(monoElapsed()),
        wall_duration_ms: wallDurationMs ?? Math.ceil(wallElapsed()),
        suspended, max_tick_gap_ms: maxTickGapMs,
        group_signals: groupSignals, descendants_reaped: reaped,
        ...redactions
      });
    };
    // The leader exiting does not mean its owned group is gone: a descendant may ignore SIGTERM.
    // Keep escalating (SIGTERM, then SIGKILL after the cleanup grace) until the group is gone, so
    // no owned process outlives the result, and never cancel the SIGKILL when the leader exits first.
    const reap = () => {
      if (reaping || settled) return;
      reaping = true;
      durationMs = Math.ceil(monoElapsed());
      wallDurationMs = Math.ceil(wallElapsed());
      if (!groupAlive()) { finish(true); return; }
      if (!groupSignals.includes('SIGTERM')) terminateGroup('SIGTERM');
      const hardLimit = monotonicNow() + 10 * grace + 2000;
      const killAt = monotonicNow() + grace;
      const poll = () => {
        if (!groupAlive()) { finish(true); return; }
        if (monotonicNow() >= killAt) killGroupOnce();
        if (monotonicNow() >= hardLimit) { error ??= 'descendant process group did not exit'; finish(false); return; }
        killTimer = setTimeout(poll, 5);
      };
      poll();
    };
    const expire = () => {
      if (!child?.pid || settled || reaping || escalationTimer) return;
      terminateGroup('SIGTERM');
      escalationTimer = setTimeout(() => { if (!settled && groupAlive()) killGroupOnce(); }, grace);
    };
    const watchdog = () => {
      if (settled) return;
      const elapsed = observeClocks();
      if (!timedOut && elapsed >= limit) { timedOut = true; expire(); }
      scheduledDelay = timedOut ? tick : Math.max(1, Math.min(tick, Math.ceil(limit - elapsed)));
      watchdogTimer = setTimeout(watchdog, scheduledDelay);
    };
    function onAbort() { aborted = true; expire(); }
    try {
      child = spawn(program, args, { cwd, env, stdio: ['ignore', fd, fd], detached: true });
      child.once('error', (cause) => { error = cause.message; if (!child.pid) finish(true); });
      child.once('exit', (code, childSignal) => {
        exitCode = code;
        signal = childSignal;
      });
      child.once('close', reap);
      if (!settled) watchdog();
      if (abortSignal?.aborted) onAbort();
      else abortSignal?.addEventListener('abort', onAbort, { once: true });
    } catch (cause) {
      error = cause.message;
      finish(true);
    }
  });
}

// macOS will put an idle host into (maintenance) sleep in the middle of a native window; every
// process then freezes for 12-15 minutes at a time (253-40). Hold a PreventSystemSleep /
// PreventUserIdleSystemSleep assertion for the whole window, tied to the runner's PID so it can
// never outlive a crashed runner.
export function holdHostAwake({ platform = process.platform, spawnProcess = spawn, pid = process.pid, exists = fs.existsSync } = {}) {
  if (platform !== 'darwin') return { held: false, platform, argv: null, release: () => {} };
  const argv = ['/usr/bin/caffeinate', '-i', '-s', '-m', '-w', String(pid)];
  if (!exists(argv[0])) throw new Error('macOS sleep assertion unavailable: /usr/bin/caffeinate is missing');
  const holder = spawnProcess(argv[0], argv.slice(1), { stdio: 'ignore' });
  if (!holder?.pid) throw new Error('macOS sleep assertion could not be started');
  holder.on?.('error', () => {});
  return {
    held: true, platform, argv, pid: holder.pid,
    release: () => { try { holder.kill('SIGTERM'); } catch { /* already gone */ } }
  };
}

function revisionFreezeDigest(freeze) {
  return sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))));
}

function validateRevisionSource(root, freeze, evidenceFile = null) {
  const head = assertRevisionCheckout(root, evidenceFile);
  const ancestor = run('git', ['-C', root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]);
  if (ancestor.status !== 0) throw new Error(`frozen source ${freeze.source.checkout_head} is not an ancestor of ${head}`);
  for (const [file, expected] of Object.entries(freeze.source.blobs)) {
    const actual = git(['-C', root, 'hash-object', file]);
    if (actual !== expected) throw new Error(`source identity mismatch for ${file}: ${actual}`);
  }
  const phaseDir = path.join(root, PHASE_DIR);
  const identities = [
    [path.join(phaseDir, '253-RECOVERY-REGISTRATION-FREEZE.json'), freeze.historical.original_freeze_sha256],
    [path.join(phaseDir, '253-RECOVERY-REGISTRATION-EVIDENCE.json'), freeze.historical.original_evidence_sha256],
    [path.join(phaseDir, '253-09-TERMINAL-DIAGNOSTIC.json'), freeze.historical.terminal_diagnostic_sha256],
    [path.resolve(root, freeze.historical.recovery_capture_path), freeze.historical.recovery_capture_sha256]
  ];
  for (const [file, expected] of identities) if (fileHash(file) !== expected) throw new Error(`historical registration bytes changed: ${path.relative(root, file)}`);
  if (freeze.retry_context) {
    const retry = freeze.retry_context;
    if (fileHash(path.resolve(root, retry.original_evidence_path)) !== retry.original_evidence_sha256
      || fileHash(path.resolve(root, retry.original_freeze_path)) !== retry.original_freeze_sha256
      || fileHash(path.resolve(root, retry.review_path)) !== retry.review_sha256) throw new Error('infrastructure retry historical evidence or review bytes changed');
    const markerFile = path.resolve(root, freeze.infrastructure_retry.used_marker_path);
    const reservationFile = path.resolve(root, freeze.infrastructure_retry.reservation_path);
    if (fileHash(reservationFile) !== freeze.infrastructure_retry.reservation_sha256) throw new Error('shared retry reservation bytes changed');
    if (fs.existsSync(markerFile)) {
      const marker = readJson(markerFile);
      if (marker.freeze_sha256 !== freeze.freeze_sha256 || marker.retry_count !== 1 || marker.status !== 'consumed') throw new Error('shared infrastructure retry marker is malformed or belongs to another source');
    }
  }
  return head;
}

function validateFrozenRevisionProvenance(root, freeze) {
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  if (run('git', ['-C', root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]).status !== 0) throw new Error('frozen source commit is not in the current repository history');
  for (const [file, expected] of Object.entries(freeze.source.blobs ?? {})) {
    if (git(['-C', root, 'rev-parse', `${freeze.source.checkout_head}:${file}`]) !== expected) throw new Error(`frozen Git source blob mismatch for ${file}`);
  }
  const phaseDir = path.join(root, PHASE_DIR);
  const identities = [
    [path.join(phaseDir, '253-RECOVERY-REGISTRATION-FREEZE.json'), freeze.historical.original_freeze_sha256],
    [path.join(phaseDir, '253-RECOVERY-REGISTRATION-EVIDENCE.json'), freeze.historical.original_evidence_sha256],
    [path.join(phaseDir, '253-09-TERMINAL-DIAGNOSTIC.json'), freeze.historical.terminal_diagnostic_sha256],
    [path.resolve(root, freeze.historical.recovery_capture_path), freeze.historical.recovery_capture_sha256],
    [path.resolve(root, freeze.retry_context?.original_evidence_path ?? ''), freeze.retry_context?.original_evidence_sha256],
    [path.resolve(root, freeze.retry_context?.original_freeze_path ?? ''), freeze.retry_context?.original_freeze_sha256],
    [path.resolve(root, freeze.retry_context?.review_path ?? ''), freeze.retry_context?.review_sha256],
    [path.resolve(root, freeze.infrastructure_retry?.reservation_path ?? ''), freeze.infrastructure_retry?.reservation_sha256]
  ];
  for (const [file, expected] of identities) if (expected && fileHash(file) !== expected) throw new Error(`frozen historical evidence bytes changed: ${path.relative(root, file)}`);
  assertDirtyConfigPreserved(root);
}

function loadRevisionEvidence(freezeFile, evidenceFile, root, { allowRebind = false } = {}) {
  const freeze = readJson(freezeFile);
  if (freeze.schema_version !== REPLAN_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== revisionFreezeDigest(freeze)) throw new Error('registration revision freeze is malformed or has an invalid digest');
  validateRevisionSource(root, freeze, evidenceFile);
  const freezeHash = fileHash(freezeFile);
  let evidence;
  if (fs.existsSync(evidenceFile)) {
    evidence = readJson(evidenceFile);
    if (evidence.schema_version !== REPLAN_SCHEMA) throw new Error('registration evidence schema does not match the revision runner');
    if (evidence.freeze_sha256 !== freezeHash) {
      const prior = freeze.supersedes_source_revision;
      if (!allowRebind || !prior || path.resolve(root, prior.evidence_path) !== path.resolve(evidenceFile)
        || fileHash(evidenceFile) !== prior.evidence_sha256 || evidence.freeze_sha256 !== prior.freeze_sha256
        || evidence.source?.checkout_head !== prior.source_commit
        || evidence.attempts?.length !== 0 || evidence.limits?.browser_launches !== 0
        || evidence.limits?.used_slots?.length !== 0 || evidence.limits?.preparation_charge_ms !== prior.preparation_charge_ms
        || freeze.preparation.charged_duration_ms !== prior.preparation_charge_ms) {
        throw new Error('registration evidence does not match the committed revision freeze');
      }
      const priorFreezePath = path.resolve(root, prior.freeze_path);
      if (fileHash(priorFreezePath) !== prior.freeze_sha256) throw new Error('superseded source freeze bytes changed');
      evidence.source_revisions ??= [];
      evidence.source_revisions.push({ stage: 'preparation', freeze_path: prior.freeze_path, freeze_sha256: prior.freeze_sha256, source_commit: prior.source_commit, charged_duration_ms: prior.preparation_charge_ms });
      evidence.source_revisions.push({ stage: 'diagnostic', freeze_path: path.relative(root, freezeFile), freeze_sha256: freezeHash, source_commit: freeze.source.checkout_head, charged_duration_ms: 0 });
      evidence.freeze_path = path.relative(root, freezeFile);
      evidence.freeze_sha256 = freezeHash;
      evidence.source = { checkout_head: freeze.source.checkout_head, blobs: freeze.source.blobs };
      writeJson(evidenceFile, evidence);
    }
    if (!['running', 'diagnosis_incomplete', 'halted'].includes(evidence.status)) throw new Error('registration evidence has an unsupported status');
  } else {
    evidence = {
      schema_version: REPLAN_SCHEMA, status: 'running', freeze_path: path.relative(root, freezeFile), freeze_sha256: freezeHash,
      source: { checkout_head: freeze.source.checkout_head, blobs: freeze.source.blobs },
      historical: { ...freeze.historical, preceding_order: 'unknown' },
      preparation_status: freeze.retry_context ? 'passed' : 'not_started',
      preparation_receipts: [], attempts: [],
      toolchain: freeze.retry_context ? readJson(path.resolve(root, freeze.retry_context.original_evidence_path)).toolchain : undefined,
      limits: { historical_charge_ms: freeze.ledger.historical_charge_ms, preparation_charge_ms: 0, charged_duration_ms: freeze.ledger.historical_charge_ms, browser_launches: 0, used_slots: [], max_charged_duration_ms: freeze.ledger.max_charged_duration_ms, max_new_browser_launches: freeze.ledger.max_new_browser_launches }
    };
    fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  }
  return { freeze, freezeHash, evidence };
}

function receiptFile(baseDir, label, file) {
  const reference = referenceFor(baseDir, file);
  if (!reference) throw new Error(`cannot create receipt for ${label}`);
  return reference;
}

function prepareRevision(freezeFile, evidenceFile, root = ROOT) {
  const { freeze, evidence } = loadRevisionEvidence(freezeFile, evidenceFile, root);
  if (evidence.preparation_receipts.length) throw new Error('common dependency preparation is already recorded and cannot be repeated');
  if (evidence.attempts.length || evidence.limits.browser_launches) throw new Error('common preparation must precede every browser attempt');
  const prepDir = path.join(`${evidenceFile}.raw`, 'preparation');
  fs.mkdirSync(prepDir, { recursive: true });
  const playwrightDir = path.join(root, 'test/example/priv/playwright');
  const started = process.hrtime.bigint();
  const commands = [
    { name: 'locked_npm_ci', command: 'npm', args: ['ci'], cwd: playwrightDir, env: process.env },
    { name: 'node_version', command: 'node', args: ['--version'], cwd: root, env: process.env },
    { name: 'playwright_version', command: path.join(playwrightDir, 'node_modules/.bin/playwright'), args: ['--version'], cwd: playwrightDir, env: process.env },
    { name: 'mix_version', command: 'mix', args: ['--version'], cwd: path.join(root, 'test/example'), env: { ...process.env, MIX_ENV: 'dev' } },
    { name: 'host_dependency_versions', command: 'mix', args: ['deps'], cwd: path.join(root, 'test/example'), env: { ...process.env, MIX_ENV: 'dev' } }
  ];
  let failed = null;
  for (const [index, item] of commands.entries()) {
    validateRevisionSource(root, freeze, evidenceFile);
    const elapsed = Number(process.hrtime.bigint() - started) / 1e6;
    const remaining = freeze.preparation.max_duration_ms - Math.ceil(elapsed);
    if (remaining <= 0) { failed = 'common dependency preparation reached its 116,232 ms reservation before all probes completed'; break; }
    const log = path.join(prepDir, `${String(index + 1).padStart(2, '0')}-${item.name}.log`);
    const before = process.hrtime.bigint();
    const result = runLogged(item.command, item.args, item.cwd, item.env, log, remaining);
    const duration = Math.ceil(Number(process.hrtime.bigint() - before) / 1e6);
    const receipt = { name: item.name, argv: [item.command, ...item.args], exit_code: result.exit_code, duration_ms: duration, log: receiptFile(`${evidenceFile}.raw`, item.name, log), redacted_secret_fields: result.redacted_secret_fields, redacted_credential_blocks: result.redacted_credential_blocks };
    evidence.preparation_receipts.push(receipt);
    evidence.limits.preparation_charge_ms += duration;
    evidence.limits.charged_duration_ms += duration;
    if (duration + evidence.limits.preparation_charge_ms - duration > freeze.preparation.max_duration_ms) failed = 'common dependency preparation exceeded its 116,232 ms reservation';
    if (result.exit_code !== 0 || result.error) failed = `${item.name} failed with exit ${result.exit_code ?? 'null'}${result.error ? `: ${result.error}` : ''}`;
    writeJson(evidenceFile, evidence);
    if (failed) break;
  }
  if (!failed) {
    const playwright = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    const depsLog = evidence.preparation_receipts.find((item) => item.name === 'host_dependency_versions');
    const depText = fs.readFileSync(path.join(`${evidenceFile}.raw`, depsLog.log.path), 'utf8');
    const versionOf = (name) => depText.split('\n').find((line) => line.startsWith(`* ${name} `))?.match(/^\* .+ ([0-9]+\.[0-9]+\.[0-9]+) /)?.[1] ?? null;
    evidence.toolchain = { node: fs.readFileSync(path.join(`${evidenceFile}.raw`, evidence.preparation_receipts[1].log.path), 'utf8').trim(), playwright, mix: fs.readFileSync(path.join(`${evidenceFile}.raw`, evidence.preparation_receipts[3].log.path), 'utf8').split('\n')[0], ecto_sql: versionOf('ecto_sql'), phoenix_live_view: versionOf('phoenix_live_view') };
    if (playwright !== '1.59.1' || !evidence.toolchain.ecto_sql || !evidence.toolchain.phoenix_live_view) failed = 'observed dependency versions do not match the frozen locked toolchain';
  }
  evidence.preparation_status = failed ? 'failed' : 'passed';
  if (failed) { evidence.status = 'halted'; evidence.stop_reason = failed; }
  writeJson(evidenceFile, evidence);
  if (failed) throw new Error(failed);
  return { status: evidence.status, preparation_charge_ms: evidence.limits.preparation_charge_ms, toolchain: evidence.toolchain };
}

const REVISION_SELECTED_TITLE = 'render bundle: board-mg-9/populated';
const REVISION_PROJECT_NAMES = ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'];

// Exact UTF-8 equality: both sides must be well-formed strings (lone surrogates would otherwise
// collapse to U+FFFD and compare equal) with identical encoded bytes.
export function exactUtf8Equal(left, right) {
  return typeof left === 'string' && typeof right === 'string' && left.isWellFormed() && right.isWellFormed()
    && Buffer.from(left, 'utf8').equals(Buffer.from(right, 'utf8'));
}

export function verifyRevisionAttempt(attempt, freeze, baseDir) {
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!attempt || typeof attempt !== 'object') return { ok: false, errors: ['attempt is missing'] };
  const slot = freeze.ledger.slots.find((item) => item.id === attempt.slot_id);
  if (!slot) fail('attempt does not identify a frozen slot');
  else {
    if (slot.owner_plan !== 15 || slot.kind !== 'diagnostic' || slot.stage !== 'D19') fail('attempt consumed a slot not owned by plan15');
    if (!exactUtf8Equal(attempt.project, slot.project) || attempt.sequence !== slot.sequence) fail('attempt identity differs from its frozen slot');
    if (!exactUtf8Equal(slot.title, REVISION_SELECTED_TITLE)) fail('frozen selected title is not the reviewed byte-exact title');
    if (!REVISION_PROJECT_NAMES.some((name) => exactUtf8Equal(name, slot.project))) fail('frozen slot project is not a reviewed admin-eval project');
    if (!Number.isFinite(attempt.charged_duration_ms) || attempt.charged_duration_ms < 0 || attempt.charged_duration_ms > slot.max_duration_ms) fail('attempt exceeded its frozen 120,000 ms command');
    if (JSON.stringify(attempt.argv) !== JSON.stringify(slot.argv)) fail('browser argv differs from the frozen selection');
  }
  if (attempt.source_commit !== freeze.source.checkout_head || JSON.stringify(attempt.source_blobs) !== JSON.stringify(freeze.source.blobs)) fail('attempt is not bound to the frozen source commit and blobs');
  let start; let end;
  try { start = BigInt(attempt.started_monotonic_ns); end = BigInt(attempt.ended_monotonic_ns); } catch { start = 0n; end = 0n; }
  if (start <= 0n || end <= start || Math.ceil(Number(end - start) / 1e6) !== attempt.execution_duration_ms) fail('attempt monotonic duration is absent or inconsistent');
  if (attempt.charged_duration_ms !== attempt.execution_duration_ms) fail('attempt charge does not equal its measured setup/browser/drop duration');
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    const reference = attempt.files?.[name];
    const file = confinedFile(baseDir, reference);
    if (!file || !fs.existsSync(file)) { fail(`native ${name} is missing`); continue; }
    if (!reference.sha256 || fileHash(file) !== reference.sha256) fail(`native ${name} digest mismatch`);
    if (!fs.statSync(file).size) fail(`native ${name} is empty`);
  }
  if (attempt.database?.setup_exit_code !== 0 || attempt.database?.drop_exit_code !== 0) fail('database setup or drop did not succeed');
  if (!/^sigra_253_recovery_[a-z0-9_]+$/.test(attempt.database?.name ?? '')) fail('database identity is not a unique recovery database');
  if (attempt.build_directory_removed !== true || !attempt.build_path?.endsWith(`/mix-build`)) fail('attempt did not remove its unique physical Mix build');
  if (attempt.server?.http_status !== 200 || attempt.browser?.launched !== true) fail('registration browser did not launch after HTTP 200 readiness');
  if (!Number.isInteger(attempt.browser?.exit_code)) fail('native browser CLI exit is missing');
  const reportRef = attempt.files?.playwright_report;
  const reportFile = confinedFile(baseDir, reportRef);
  if (!reportFile || !fs.existsSync(reportFile)) fail('native Playwright report is missing');
  else {
    if (!reportRef.sha256 || fileHash(reportFile) !== reportRef.sha256) fail('native Playwright report digest mismatch');
    try {
      const report = readJson(reportFile);
      if (!Array.isArray(report.errors) || !Array.isArray(report.config?.projects) || !Array.isArray(report.suites)) fail('native Playwright report shape is incomplete');
      if (!Array.isArray(report.config?.projects)) fail('native Playwright project inventory is incomplete');
      const tests = playReportTests(report);
      if (!tests.length) fail('native Playwright report contains no results');
      const inventory = Array.isArray(report.config?.projects) ? report.config.projects.map((item) => item?.name) : [];
      if (!REVISION_PROJECT_NAMES.every((name) => inventory.some((entry) => exactUtf8Equal(entry, name)))) fail('native Playwright project inventory is incomplete');
      const selected = tests.filter((item) => exactUtf8Equal(item.title, slot.title) && exactUtf8Equal(item.project, attempt.project) && path.basename(item.file) === 'admin-eval.spec.ts');
      if (selected.length !== 1) fail('native Playwright report must contain exactly one byte-exact selected project/title/spec result');
      if (selected.length === 1) {
        const result = selected[0];
        if (!['expected', 'unexpected', 'flaky', 'skipped'].includes(result.summary_status)) fail('native Playwright summary status is invalid');
        if (!Number.isFinite(result.duration) || result.duration < 0) fail('native Playwright result duration is missing');
        if (result.result_count !== 1) fail('native Playwright result must have exactly one attempt with retries disabled');
        if (['skipped', 'interrupted'].includes(result.status)) fail('native selected test was skipped or interrupted');
        if (!result.expected_status || result.status !== result.expected_status) fail('native expectedStatus and result status disagree');
        const passed = result.summary_status === 'expected';
        if ((attempt.browser.exit_code === 0) !== passed) fail('native test status disagrees with the Playwright process exit');
        if (attempt.observed_outcome !== (passed ? 'passed' : 'failed')) fail('attempt classification disagrees with the native result');
        if (!passed && !result.error) fail('failed native test has no retained assertion/error detail');
      }
      if (report.errors.length && attempt.browser.exit_code === 0) fail('Playwright emitted top-level errors despite a zero exit');
    } catch (error) { fail(`native Playwright report could not be parsed: ${error.message}`); }
  }
  if (attempt.browser?.exit_code !== 0) {
    const trace = attempt.files?.traces?.some((reference) => {
      const file = confinedFile(baseDir, reference);
      return file && fs.existsSync(file) && fileHash(file) === reference.sha256 && fs.statSync(file).size > 0;
    });
    if (!trace) fail('failed browser result has no retained trace with a matching digest');
  }
  if (attempt.registration?.server_post_confirmed !== true || attempt.registration?.success_flash_asserted !== true) fail('selected registration did not prove both server POST and success flash');
  for (const key of ['playwright', 'ecto_sql', 'phoenix_live_view']) if (!attempt.toolchain?.[key]) fail(`attempt toolchain is missing ${key}`);
  return { ok: errors.length === 0, errors };
}

export function verifyRevisionFreezeBinding(evidence, freeze, freezeFileHash) {
  return freeze?.freeze_sha256 === revisionFreezeDigest(freeze) && evidence?.freeze_sha256 === freezeFileHash;
}

export function verifyRevisionData(evidence, freeze, baseDir, freezeFileHash = freeze?.freeze_sha256) {
  const errors = [];
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) return { ok: false, errors: ['native revision evidence is missing or malformed'] };
  if (!freeze || typeof freeze !== 'object' || !Array.isArray(freeze.ledger?.slots)) return { ok: false, errors: ['native revision freeze is missing or malformed'] };
  if (evidence?.schema_version !== REPLAN_SCHEMA || !verifyRevisionFreezeBinding(evidence, freeze, freezeFileHash)) errors.push('evidence does not match the frozen revision');
  if (evidence?.source?.checkout_head !== freeze?.source?.checkout_head || JSON.stringify(evidence?.source?.blobs) !== JSON.stringify(freeze?.source?.blobs)) errors.push('evidence source identity differs from the frozen revision');
  if (evidence.historical?.preceding_order !== 'unknown' || evidence.limits?.historical_charge_ms !== freeze?.ledger?.historical_charge_ms) errors.push('historical uncertainty or spent charge was not preserved');
  if (evidence.preparation_status !== 'passed') errors.push('common dependency preparation is missing or incomplete');
  if (!Array.isArray(evidence.attempts) || !Array.isArray(evidence.preparation_receipts)) errors.push('preparation or attempt ledger is absent');
  else {
    const limits = evidence.limits;
    if (!limits || typeof limits !== 'object') errors.push('native cumulative limits are missing');
    else {
      for (const key of ['historical_charge_ms', 'preparation_charge_ms', 'charged_duration_ms', 'browser_launches', 'max_charged_duration_ms', 'max_new_browser_launches']) {
        if (!Number.isSafeInteger(limits[key]) || limits[key] < 0) errors.push(`native cumulative limit ${key} is not a nonnegative integer`);
      }
      if (limits.max_charged_duration_ms !== freeze.ledger.max_charged_duration_ms || limits.max_new_browser_launches !== freeze.ledger.max_new_browser_launches) errors.push('native cumulative ceilings differ from the frozen ledger');
    }
    if (evidence.attempts.length === 0) errors.push('no native diagnostic attempt is present');
    const ids = new Set();
    let browserLaunches = 0; let attemptCharge = 0;
    for (const attempt of evidence.attempts) {
      if (ids.has(attempt.slot_id)) errors.push(`diagnostic slot ${attempt.slot_id} was reused`);
      ids.add(attempt.slot_id);
      const verified = verifyRevisionAttempt(attempt, freeze, baseDir);
      errors.push(...verified.errors.map((message) => `${attempt.project}: ${message}`));
      browserLaunches += attempt.browser?.launched ? 1 : 0;
      attemptCharge += Number(attempt.charged_duration_ms) || 0;
    }
    const usedSlots = evidence.limits?.used_slots;
    const attemptSlots = evidence.attempts.map((attempt) => attempt.slot_id);
    if (!Array.isArray(usedSlots) || JSON.stringify(usedSlots) !== JSON.stringify(attemptSlots)) errors.push('used slot ledger does not exactly match native attempt receipts');
    const prepCharge = evidence.preparation_receipts.reduce((sum, item) => sum + (Number(item.duration_ms) || 0), 0);
    if (prepCharge !== evidence.limits.preparation_charge_ms) errors.push('preparation charge does not match its command receipts');
    if (prepCharge > freeze.preparation.max_duration_ms) errors.push('common preparation exceeded its frozen 116,232 ms ceiling');
    if (attemptCharge + evidence.limits.historical_charge_ms + prepCharge !== evidence.limits.charged_duration_ms) errors.push('cumulative charged time does not match native receipt durations');
    if (evidence.limits.charged_duration_ms > freeze.ledger.d19.max_charged_duration_ms) errors.push('D-19 charged time exceeds its frozen 18-minute allowance');
    if (browserLaunches !== evidence.limits?.browser_launches) errors.push('browser launch count differs from native receipts');
    if (browserLaunches > freeze.ledger.max_new_browser_launches || evidence.limits.charged_duration_ms > freeze.ledger.max_charged_duration_ms) errors.push('shared recovery limit exceeded');
    if (evidence.limits.charged_duration_ms > freeze.ledger.max_total_charged_ms_including_historical) errors.push('58-minute historical-inclusive recovery ceiling exceeded');
    const ordered = freeze.ledger.slots.filter((slot) => slot.owner_plan === 15);
    if (evidence.attempts.some((item, index) => item.slot_id !== ordered[index]?.id)) errors.push('plan15 diagnostic slots were consumed out of order');
    if (!['running', 'diagnosis_incomplete', 'halted'].includes(evidence.status)) errors.push('evidence status is unsupported');
  }
  return { ok: errors.length === 0, errors };
}

async function runRevision(freezeFile, slotId, evidenceFile, root = ROOT) {
  const { freeze, freezeHash, evidence } = loadRevisionEvidence(freezeFile, evidenceFile, root, { allowRebind: true });
  if (evidence.status !== 'running') throw new Error(`refusing to continue terminal evidence: ${evidence.status}`);
  if (evidence.preparation_status !== 'passed') throw new Error('common dependency preparation has not passed');
  const slot = freeze.ledger.slots.find((item) => item.id === slotId);
  if (!slot || slot.owner_plan !== 15 || slot.kind !== 'diagnostic') throw new Error(`slot ${slotId} is not owned by plan15`);
  const expectedSlot = freeze.ledger.slots.filter((item) => item.owner_plan === 15)[evidence.attempts.length];
  if (slot !== expectedSlot) throw new Error(`next plan15 slot must be ${expectedSlot?.id ?? 'none'}; refusing ${slotId}`);
  if (evidence.limits.used_slots.includes(slotId)) throw new Error(`slot ${slotId} was already spent`);
  if (freeze.retry_context) {
    const markerFile = path.resolve(root, freeze.infrastructure_retry.used_marker_path);
    if (slot.id === 'R-INFRA-RETRY-DESKTOP') {
      if (fs.existsSync(markerFile)) throw new Error('the one shared infrastructure retry was already consumed');
      writeJson(markerFile, { schema_version: 'sigra.phase253.registration-shared-retry/v1', status: 'consumed', retry_count: 1, budget: 1, charge_before_ms: 33884, max_duration_ms: 120000, source_commit: freeze.source.checkout_head, freeze_sha256: freeze.freeze_sha256, original_evidence_sha256: freeze.retry_context.original_evidence_sha256, review_sha256: freeze.retry_context.review_sha256, slot_id: slot.id, consumed_at: new Date().toISOString() });
    } else if (slot.id === 'R-DIAG-MOBILE') {
      if (!fs.existsSync(markerFile) || evidence.attempts[0]?.slot_id !== 'R-INFRA-RETRY-DESKTOP' || evidence.attempts[0]?.observed_outcome !== 'passed') throw new Error('mobile diagnostic is available only after the reserved desktop retry passed');
    } else throw new Error('retry freeze exposes only the single desktop retry and conditional mobile diagnostic');
  }
  const charge = evidence.limits.charged_duration_ms;
  if (charge + slot.max_duration_ms > freeze.ledger.d19.max_charged_duration_ms) throw new Error('full 120,000 ms command does not fit in the remaining D-19 allocation');
  if (charge + slot.max_duration_ms > freeze.ledger.max_charged_duration_ms || charge + slot.max_duration_ms > freeze.ledger.max_total_charged_ms_including_historical) throw new Error('full 120,000 ms command does not fit in the remaining shared allocation');
  validateRevisionSource(root, freeze, evidenceFile);
  const project = REPLAN_PROJECTS.find((item) => item.name === slot.project);
  const rawBase = `${evidenceFile}.raw`;
  const started = process.hrtime.bigint();
  const attemptDir = createAttemptDirectory(rawBase, slot.id, 1);
  const deadline = Number(started) / 1e6 + slot.max_duration_ms;
  const unique = `${Date.now().toString(36)}_${process.pid}`;
  const db = `sigra_253_recovery_${project.name.replaceAll('-', '_')}_${unique}`.toLowerCase();
  const env = diagnosticEnvironment(project, db, attemptDir);
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: project.name, argv: slot.argv,
    source_commit: freeze.source.checkout_head, source_blobs: freeze.source.blobs,
    started_monotonic_ns: started.toString(), database: { name: db, setup_exit_code: null, drop_exit_code: null },
    server: { port: project.port, http_status: null }, browser: { launched: false, exit_code: null },
    observed_outcome: 'setup_failed', registration: { server_post_confirmed: false, success_flash_asserted: false }, files: {}, log_redactions: {}, toolchain: evidence.toolchain
  };
  const paths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(attemptDir, `${name.replaceAll('_', '-')}.log`)]));
  const reportPath = path.join(attemptDir, 'playwright-report.json');
  const playwrightDir = path.join(root, 'test/example/priv/playwright');
  const exampleDir = path.join(root, 'test/example');
  let app = null; let terminalError = null;
  try {
    const setup = runLogged('mix', ['ecto.setup'], exampleDir, env, paths.setup_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.log_redactions.setup_log = setup;
    attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0) throw new Error(`database setup failed with exit ${setup.exit_code ?? 'null'}${setup.error ? `: ${setup.error}` : ''}`);
    const fd = fs.openSync(paths.app_log, 'w');
    try { app = spawn('mix', ['phx.server'], { cwd: exampleDir, env, stdio: ['ignore', fd, fd], detached: true }); }
    finally { fs.closeSync(fd); }
    const ready = app.pid ? await waitReady(app, `http://127.0.0.1:${project.port}/`, deadline) : null;
    attempt.server.http_status = ready;
    attempt.server.app_pid = app.pid ?? null;
    if (ready !== 200) throw new Error(`Phoenix did not return HTTP 200 at port ${project.port} before the slot expired`);
    const installed = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installed !== freeze.tools.playwright_required) throw new Error(`installed Playwright ${installed} differs from frozen ${freeze.tools.playwright_required}`);
    if (Number(process.hrtime.bigint()) / 1e6 >= deadline) throw new Error('120,000 ms slot expired before browser launch');
    attempt.browser.launched = true;
    const browser = runLogged(path.join(playwrightDir, 'node_modules/.bin/playwright'), [
      'test', 'tests/admin-eval.spec.ts', `--project=${project.name}`, `--grep=${slot.title}`,
      '--retries=0', '--workers=1', '--trace=retain-on-failure', `--output=${path.join(attemptDir, 'playwright-output')}`
    ], playwrightDir, { ...env, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${project.port}`, SIGRA_PLAYWRIGHT_JSON: reportPath }, paths.test_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.log_redactions.test_log = browser;
    attempt.browser.exit_code = browser.exit_code;
    attempt.observed_outcome = browser.exit_code === 0 ? 'passed' : 'failed';
    attempt.files.playwright_report = receiptFile(rawBase, 'Playwright report', reportPath);
    const outDir = path.join(attemptDir, 'playwright-output');
    const traces = [];
    if (fs.existsSync(outDir)) for (const entry of fs.readdirSync(outDir, { recursive: true })) {
      if (String(entry).endsWith('trace.zip')) {
        const source = path.join(outDir, String(entry)); const destination = path.join(attemptDir, `trace-${traces.length + 1}.zip`);
        fs.copyFileSync(source, destination); traces.push(receiptFile(rawBase, 'trace', destination));
      }
    }
    attempt.files.traces = traces;
    attempt.registration.success_flash_asserted = browser.exit_code === 0;
    const appText = fs.readFileSync(paths.app_log, 'utf8');
    attempt.registration.server_post_confirmed = /POST \/users\/log_in/.test(appText) || /POST \/users\/register/.test(appText);
    if (browser.exit_code === 0 && !attempt.registration.server_post_confirmed) throw new Error('native server log did not confirm the registration POST');
  } catch (error) { terminalError = error.message; }
  finally {
    await stopApp(app);
    if (fs.existsSync(paths.app_log)) attempt.log_redactions.app_log = sanitizeCommandLog(paths.app_log);
    const drop = runLogged('mix', ['ecto.drop', '--quiet'], exampleDir, env, paths.drop_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.log_redactions.drop_log = drop;
    attempt.database.drop_exit_code = drop.exit_code;
    if (drop.exit_code !== 0) terminalError = [terminalError, `database drop failed with exit ${drop.exit_code ?? 'null'}`].filter(Boolean).join('; ');
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const [name, file] of Object.entries(paths)) {
    if (!fs.existsSync(file)) fs.writeFileSync(file, `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    else if (!fs.statSync(file).size) fs.writeFileSync(file, `${name} command produced no output\n`);
    attempt.log_redactions[name] ??= sanitizeCommandLog(file);
    attempt.files[name] = receiptFile(rawBase, name, file);
  }
  attempt.ended_monotonic_ns = process.hrtime.bigint().toString();
  attempt.execution_duration_ms = Math.ceil(Number(BigInt(attempt.ended_monotonic_ns) - BigInt(attempt.started_monotonic_ns)) / 1e6);
  attempt.charged_duration_ms = attempt.execution_duration_ms;
  attempt.build_path = env.MIX_BUILD_PATH;
  attempt.terminal_diagnostic = terminalError;
  evidence.attempts.push(attempt);
  evidence.limits.used_slots.push(slotId);
  evidence.limits.browser_launches += attempt.browser.launched ? 1 : 0;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  if (attempt.charged_duration_ms > slot.max_duration_ms) terminalError = [terminalError, 'slot duration ceiling exceeded'].filter(Boolean).join('; ');
  const nativeValidation = verifyRevisionAttempt(attempt, freeze, rawBase);
  if (!nativeValidation.ok) terminalError = [terminalError, ...nativeValidation.errors].filter(Boolean).join('; ');
  if (freeze.retry_context && slot.id === 'R-INFRA-RETRY-DESKTOP' && attempt.observed_outcome !== 'passed') terminalError = [terminalError, 'the independently authorized retry did not prove desktop registration; mobile diagnostic remains blocked'].filter(Boolean).join('; ');
  if (terminalError) { evidence.status = 'halted'; evidence.stop_reason = terminalError; }
  else if (evidence.attempts.length === 2) { evidence.status = 'diagnosis_incomplete'; evidence.stop_reason = 'Desktop and mobile diagnostics completed; the dark combined diagnostic/control command remains reserved for plan16.'; }
  else evidence.status = 'running';
  writeJson(evidenceFile, evidence);
  const checked = verifyRevisionData(evidence, freeze, rawBase, freezeHash);
  if (!checked.ok) {
    evidence.status = 'halted'; evidence.stop_reason = `native revision receipt verification failed: ${checked.errors.join('; ')}`;
    writeJson(evidenceFile, evidence);
    throw new Error(evidence.stop_reason);
  }
  if (terminalError) throw new Error(terminalError);
  return { status: evidence.status, slot: slotId, project: project.name, outcome: attempt.observed_outcome, browser_launched: attempt.browser.launched, charged_duration_ms: attempt.charged_duration_ms };
}

export const SYNTHETIC_NATIVE_FIXTURE_LABEL = 'synthetic-native-fixture';

export function syntheticNativeFixtureReasons(evidence, freeze, root = null) {
  const reasons = [];
  if (JSON.stringify(evidence ?? null).includes(SYNTHETIC_NATIVE_FIXTURE_LABEL) || JSON.stringify(freeze ?? null).includes(SYNTHETIC_NATIVE_FIXTURE_LABEL)) reasons.push('carries the synthetic-native-fixture provenance marker');
  if (root && typeof freeze?.source?.checkout_head === 'string') {
    const author = run('git', ['-C', root, 'log', '-1', '--format=%ae', freeze.source.checkout_head]);
    if (author.status === 0 && /@example\.invalid$/.test(author.stdout.trim())) reasons.push('frozen source commit has a synthetic fixture Git identity');
  }
  return reasons;
}

function verifyRevisionFile(evidenceFile, root = ROOT, { acceptedOnly = false } = {}) {
  try {
    const evidence = readJson(evidenceFile);
    if (typeof evidence.freeze_path !== 'string' || !evidence.freeze_path) throw new Error('evidence does not name its frozen source');
    const freezePath = path.resolve(root, evidence.freeze_path);
    const freeze = readJson(freezePath);
    validateFrozenRevisionProvenance(root, freeze);
    const freezeFileHash = fileHash(freezePath);
    const result = verifyRevisionData(evidence, freeze, `${evidenceFile}.raw`, freezeFileHash);
    const synthetic = syntheticNativeFixtureReasons(evidence, freeze, root);
    if (acceptedOnly && synthetic.length) {
      result.ok = false;
      result.errors.push(`synthetic native fixture is not accepted proof: ${synthetic.join('; ')}`);
    }
    if (!result.ok) console.error(`native revision receipt rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`native revision receipts verified: ${evidence.attempts.length}/2 plan15 diagnostics; ${evidence.limits.browser_launches} launches; ${evidence.limits.charged_duration_ms} ms charged; status=${evidence.status}${synthetic.length ? ` [${SYNTHETIC_NATIVE_FIXTURE_LABEL}: test-only, never accepted proof]` : ''}`);
    return result;
  } catch (error) { console.error(`native revision receipt rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

const CONTROL_BOARD_TITLE = 'render bundle: board-mg-9/populated';
const CONTROL_SECOND_ACTIVE = SECOND_CONTROLS.slice(0, 2);
const CONTROL_EXPECTED_FAILURE_MARKERS = {
  'registration stops when LiveView readiness is never released': 'phx-connected',
  'registration fails when the readiness wait is deliberately broken': 'data-sigra-never-connected',
  'registration retains the first forced assertion failure trace': 'toHaveURL'
};

function controlSlotDefinitions() {
  const firstPattern = `(${FIRST_CONTROLS.join('|')})`;
  const darkPattern = `(${[CONTROL_BOARD_TITLE, ...FIRST_CONTROLS].join('|')})`;
  const secondPattern = `(${CONTROL_SECOND_ACTIVE.join('|')})`;
  const browserArgs = (project, pattern) => [
    '--project=' + project, `--grep=${pattern}`, '--workers=1', '--retries=0', '--trace=retain-on-failure'
  ];
  const slots = [{
    id: 'R-DIAG-CONTROL-DARK', sequence: 1, owner_plan: 16, kind: 'diagnostic_with_controls', stage: 'first',
    project: 'admin-eval-dark', max_duration_ms: PROJECT_SLOT_MS,
    selected_titles: [CONTROL_BOARD_TITLE, ...FIRST_CONTROLS], argv: browserArgs('admin-eval-dark', darkPattern),
    expected: { [CONTROL_BOARD_TITLE]: 'pass', ...Object.fromEntries(FIRST_CONTROLS.map((title) => [title, CONTROL_EXPECTED_FAILURE_MARKERS[title] ? 'expected_failure' : 'pass'])) }
  }];
  for (const project of REPLAN_PROJECTS.filter((item) => item.name !== 'admin-eval-dark')) {
    slots.push({
      id: `R-CONTROL-FIRST-${project.name === 'admin-eval' ? 'DESKTOP' : 'MOBILE'}`,
      sequence: slots.length + 1, owner_plan: 16, kind: 'control', stage: 'first', project: project.name,
      max_duration_ms: PROJECT_SLOT_MS, selected_titles: FIRST_CONTROLS,
      argv: browserArgs(project.name, firstPattern),
      expected: Object.fromEntries(FIRST_CONTROLS.map((title) => [title, CONTROL_EXPECTED_FAILURE_MARKERS[title] ? 'expected_failure' : 'pass']))
    });
  }
  for (const project of REPLAN_PROJECTS) {
    slots.push({
      id: `R-CONTROL-SECOND-${project.name === 'admin-eval' ? 'DESKTOP' : project.name === 'admin-eval-mobile' ? 'MOBILE' : 'DARK'}`,
      sequence: slots.length + 1, owner_plan: 16, kind: 'control', stage: 'second', project: project.name,
      max_duration_ms: PROJECT_SLOT_MS, selected_titles: CONTROL_SECOND_ACTIVE,
      pending_titles: [SECOND_CONTROLS[2]], argv: browserArgs(project.name, secondPattern),
      expected: Object.fromEntries(CONTROL_SECOND_ACTIVE.map((title) => [title, 'pass']))
    });
  }
  return slots;
}

export function buildControlRecoveryLedger(input) {
  const expectedSpent = ['D19-DIAG-01', 'R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE', 'R-DIAG-CONTROL-DARK'];
  const expectedCharges = [3768, 3743, 26373, 46803, 40993, 121252, 112];
  const errors = [];
  if (!Array.isArray(input?.charges) || JSON.stringify(input.charges) !== JSON.stringify(expectedCharges)) errors.push('historical charges do not match the exact carried source receipts');
  if (input?.physicalPlaywrightLaunches !== 4) errors.push('historical Playwright CLI launch count must remain four');
  if (JSON.stringify(input?.spentReservations) !== JSON.stringify(expectedSpent)) errors.push('spent reservation inventory differs from the five closed invocations');
  if (input?.retryUsed !== 1 || input?.retryAvailable !== 0) errors.push('shared retry inventory must remain used 1, available 0');
  if (input?.preparationMaximumMs !== 116232 || input?.preparationUsedMs !== 3743) errors.push('preparation allowance differs from the preserved measured balance');
  if (errors.length) throw new Error(errors.join('; '));
  const priorCharge = input.charges.reduce((sum, value) => sum + value, 0);
  const slots = CONTROL_RECOVERY_RESERVED.map(([id, maps_from, projects, stage], index) => ({
    id, sequence: index + 1, maps_from, projects, project: projects, stage, max_duration_ms: PROJECT_SLOT_MS,
    launch_unit: 'playwright_cli_process'
  }));
  const preparationRemaining = input.preparationMaximumMs - input.preparationUsedMs;
  const d19Max = priorCharge + preparationRemaining + slots.length * PROJECT_SLOT_MS;
  const totalMax = d19Max + 9 * 240_000 + 3 * 60_000;
  if (priorCharge !== 243044 || preparationRemaining !== 112489 || d19Max !== 955533 || totalMax !== 3295533) {
    throw new Error('recovery charge arithmetic differs from the reviewed finite allocation');
  }
  return {
    prior_charge_ms: priorCharge,
    prior_playwright_cli_launches: input.physicalPlaywrightLaunches,
    spent_reservations: expectedSpent,
    retry_used: input.retryUsed,
    retry_available: input.retryAvailable,
    preparation_remaining_ms: preparationRemaining,
    slots,
    launch_unit: 'playwright_cli_process',
    engine_worker_lifecycle_accounting: 'separate_from_playwright_cli_launches',
    d19_max_ms: d19Max,
    conditional_acceptance_slots: 9,
    conditional_acceptance_ms: 2160000,
    optional_seed_checks_ms: 180000,
    total_max_ms: totalMax,
    physical_cli_launch_max: 18,
    invocation_reservations_total: 19,
    cleanup_reserve_per_command_ms: 15000,
    regular_command_ms: PROJECT_SLOT_MS
  };
}

function controlRecoveryFreezeDigest(freeze) {
  return sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))));
}

function controlRecoverySourceBlobs(root, head) {
  return Object.fromEntries(SOURCE_FILES.map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`])]));
}

function readControlRecoveryHistory(root) {
  const terminal = readJson(path.join(root, CONTROL_RECOVERY_PRIOR[0].file));
  const original = readJson(path.join(root, CONTROL_RECOVERY_PRIOR[1].file));
  const accepted = readJson(path.join(root, CONTROL_RECOVERY_PRIOR[2].file));
  const failedDark = readJson(path.join(root, CONTROL_RECOVERY_PRIOR[3].file));
  const cleanup = readJson(path.join(root, CONTROL_RECOVERY_PRIOR[4].file));
  const timeoutAssessment = readJson(path.join(root, CONTROL_RECOVERY_TIMEOUT_ASSESSMENT));
  const charges = [
    terminal.attempt?.charged_duration_ms,
    original.preparation_receipts?.reduce((sum, receipt) => sum + Number(receipt.duration_ms || 0), 0),
    original.attempts?.[0]?.charged_duration_ms,
    accepted.attempts?.find((item) => item.slot_id === 'R-INFRA-RETRY-DESKTOP')?.charged_duration_ms,
    accepted.attempts?.find((item) => item.slot_id === 'R-DIAG-MOBILE')?.charged_duration_ms,
    failedDark.attempts?.[0]?.charged_duration_ms,
    cleanup.cleanup_duration_ms
  ];
  const ledger = buildControlRecoveryLedger({
    charges, physicalPlaywrightLaunches: failedDark.limits?.physical_browser_launches,
    spentReservations: ['D19-DIAG-01', 'R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE', 'R-DIAG-CONTROL-DARK'],
    retryUsed: failedDark.limits?.retry_count_used, retryAvailable: failedDark.limits?.retry_count_available,
    preparationMaximumMs: 116232, preparationUsedMs: charges[1]
  });
  if (terminal.attempt?.charged_duration_ms !== 3768 || original.status !== 'halted'
    || original.attempts?.length !== 1 || original.limits?.browser_launches !== 1
    || accepted.status !== 'diagnosis_incomplete' || accepted.attempts?.length !== 2
    || accepted.attempts.some((item, index) => item.slot_id !== ledger.spent_reservations[index + 2] || item.charged_duration_ms !== charges[index + 3])
    || failedDark.status !== 'halted' || failedDark.attempts?.length !== 1
    || failedDark.attempts[0]?.slot_id !== 'R-DIAG-CONTROL-DARK'
    || failedDark.attempts[0]?.charged_duration_ms !== 121252
    || timeoutAssessment.native_report_present !== false
    || timeoutAssessment.native_duration_ms !== 121252
    || timeoutAssessment.cleanup_duration_ms !== 112
    || timeoutAssessment.cumulative_charge_ms !== 243044
    || failedDark.limits?.retry_count_used !== 1 || failedDark.limits?.retry_count_available !== 0
    || cleanup.original_native_slot_still_failed !== true || cleanup.database_absent_confirmed !== true
    || cleanup.cleanup_duration_ms !== 112 || cleanup.cumulative_charge_ms_including_post_halt_cleanup !== 243044) {
    throw new Error('preserved native history differs from the exact failed/accepted charge and retry records');
  }
  const artifacts = [...CONTROL_RECOVERY_PRIOR.map(({ file }) => file), CONTROL_RECOVERY_TIMEOUT_ASSESSMENT]
    .map((file) => ({ path: file, sha256: fileHash(path.join(root, file)) }));
  if (artifacts.some((item) => !item.sha256)) throw new Error('a prior native record is missing an exact byte identity');
  return { ledger, artifacts, terminal, original, accepted, failedDark, cleanup, timeoutAssessment, charges };
}

export function createControlRecoveryFreeze(outputFile, root = ROOT) {
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite the additive native control recovery freeze');
  assertRevisionCheckout(root);
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const history = readControlRecoveryHistory(root);
  const firstPattern = `(${FIRST_CONTROLS.join('|')})`;
  const darkPattern = `(${[CONTROL_BOARD_TITLE, ...FIRST_CONTROLS].join('|')})`;
  const secondPattern = `(${CONTROL_SECOND_ACTIVE.join('|')})`;
  const browserArgs = (projects, pattern) => [
    ...projects.map((project) => `--project=${project}`), `--grep=${pattern}`,
    '--workers=1', '--retries=0', '--trace=retain-on-failure'
  ];
  const slots = [
    { ...history.ledger.slots[0], project: 'admin-eval-dark', selected_titles: [CONTROL_BOARD_TITLE, ...FIRST_CONTROLS], expected: { [CONTROL_BOARD_TITLE]: 'pass', ...Object.fromEntries(FIRST_CONTROLS.map((title) => [title, CONTROL_EXPECTED_FAILURE_MARKERS[title] ? 'expected_failure' : 'pass'])) }, argv: browserArgs(['admin-eval-dark'], darkPattern) },
    { ...history.ledger.slots[1], selected_titles: FIRST_CONTROLS, expected: Object.fromEntries(FIRST_CONTROLS.map((title) => [title, CONTROL_EXPECTED_FAILURE_MARKERS[title] ? 'expected_failure' : 'pass'])), argv: browserArgs(['admin-eval', 'admin-eval-mobile'], firstPattern) },
    ...history.ledger.slots.slice(2).map((slot) => ({ ...slot, project: slot.projects[0], selected_titles: CONTROL_SECOND_ACTIVE, expected: Object.fromEntries(CONTROL_SECOND_ACTIVE.map((title) => [title, 'pass'])), argv: browserArgs(slot.projects, secondPattern) }))
  ];
  const freeze = {
    schema_version: CONTROL_RECOVERY_FREEZE_SCHEMA,
    status: 'frozen_before_results',
    plan: '253-27',
    frozen_at: new Date().toISOString(),
    source: { repository: 'szTheory/sigra', checkout_head: head, blobs: controlRecoverySourceBlobs(root, head) },
    historical: {
      artifacts: history.artifacts,
      carried_charge_ms: history.ledger.prior_charge_ms,
      physical_playwright_cli_launches: 4,
      spent_reservations: history.ledger.spent_reservations,
      spent_retry: { used: 1, available: 0 },
      failed_dark: { slot_id: 'R-DIAG-CONTROL-DARK', charged_ms: 121252, native_report_present: false, cleanup_ms: 112, database_absent: true },
      preceding_order: 'unknown',
      original_dark_failure_remains_failed: true
    },
    ledger: {
      prior_charge_ms: history.ledger.prior_charge_ms,
      prior_playwright_cli_launches: 4,
      spent_reservations: history.ledger.spent_reservations,
      preparation_remaining_ms: history.ledger.preparation_remaining_ms,
      preparation_maximum_ms: 112489,
      retry_used: 1,
      retry_available: 0,
      slots,
      d19: { cap_ms: 1200000, max_with_remaining_preparation: history.ledger.d19_max_ms },
      d20: { acceptance_slots_reserved: 9, each_max_duration_ms: 240000, reserved_ms: 2160000, retry_available: false },
      shared_cap_ms: 3480000,
      total_with_optional_seed_checks_ms: history.ledger.total_max_ms,
      physical_cli_launch_max: 18,
      invocation_reservations_total: 19,
      launch_unit: 'playwright_cli_process',
      engine_worker_lifecycle_accounting: 'separate_from_playwright_cli_launches',
      cleanup_reserve_ms: 15000,
      regular_command_ms: PROJECT_SLOT_MS,
      no_retry: true
    },
    selection: {
      spec: 'tests/admin-eval.spec.ts',
      original_title: CONTROL_BOARD_TITLE,
      first_titles: FIRST_CONTROLS,
      second_titles: CONTROL_SECOND_ACTIVE,
      deliberate_expected_failure_markers: CONTROL_EXPECTED_FAILURE_MARKERS,
      project_configuration: ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'],
      workers: 1, fully_parallel: false, retries: 0, trace: 'retain-on-failure'
    },
    tools: {
      node: process.version,
      playwright: readJson(path.join(root, 'test/example/priv/playwright/node_modules/@playwright/test/package.json')).version,
      expected_playwright: '1.59.1',
      mix: history.accepted.toolchain.mix,
      ecto_sql: history.accepted.toolchain.ecto_sql,
      phoenix_live_view: history.accepted.toolchain.phoenix_live_view
    },
    exclusions: ['no browser installation', 'no extra Playwright diagnostic launch', 'no retry', 'no acceptance command in Plan 27', 'no historical cause inferred from the failed dark run'],
    stop_conditions: ['source or history digest mismatch', 'unexpected assertion or missing native report', 'database drop/build cleanup/report/trace sanitation failure', 'command exceeds 120000 ms', 'stalled owned process group remains alive']
  };
  if (freeze.tools.playwright !== '1.59.1') throw new Error('installed Playwright differs from the locked 1.59.1 required by the recovery freeze');
  freeze.freeze_sha256 = controlRecoveryFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return freeze;
}

function validateControlRecoveryFreeze(root, freeze) {
  assertDirtyConfigPreserved(root);
  if (freeze?.schema_version !== CONTROL_RECOVERY_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== controlRecoveryFreezeDigest(freeze)) throw new Error('native control recovery freeze is malformed or its digest is invalid');
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  if (run('git', ['-C', root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]).status !== 0) throw new Error('frozen recovery source commit is not an ancestor of this checkout');
  for (const [file, expected] of Object.entries(freeze.source.blobs ?? {})) {
    if (git(['-C', root, 'hash-object', file]) !== expected) throw new Error(`frozen recovery source identity mismatch for ${file}`);
  }
  for (const artifact of freeze.historical.artifacts ?? []) {
    if (fileHash(path.join(root, artifact.path)) !== artifact.sha256) throw new Error(`preserved native history changed: ${artifact.path}`);
  }
  const history = readControlRecoveryHistory(root);
  if (JSON.stringify(history.ledger.slots.map((slot) => [slot.id, slot.maps_from])) !== JSON.stringify(freeze.ledger.slots.map((slot) => [slot.id, slot.maps_from]))) throw new Error('frozen reservation mapping differs from the reviewed unused slots');
  return head;
}

export function initializeControlRecoveryEvidence(freezeFile, evidenceFile, root = ROOT) {
  if (fs.existsSync(evidenceFile)) throw new Error('refusing to overwrite additive native control recovery evidence');
  const freeze = readJson(freezeFile);
  validateControlRecoveryFreeze(root, freeze);
  const evidence = {
    schema_version: CONTROL_RECOVERY_SCHEMA,
    status: 'ready',
    freeze_path: path.relative(root, freezeFile),
    freeze_sha256: fileHash(freezeFile),
    source: structuredClone(freeze.source),
    historical: structuredClone(freeze.historical),
    created_at: new Date().toISOString(),
    attempts: [],
    reservation: null,
    preserved_revisions: [],
    limits: {
      prior_charge_ms: freeze.ledger.prior_charge_ms,
      preparation_charge_ms: 0,
      preparation_remaining_ms: freeze.ledger.preparation_remaining_ms,
      charged_duration_ms: freeze.ledger.prior_charge_ms,
      physical_playwright_cli_launches: freeze.ledger.prior_playwright_cli_launches,
      used_slots: [...freeze.ledger.spent_reservations],
      max_d19_ms: freeze.ledger.d19.max_with_remaining_preparation,
      max_total_ms: freeze.ledger.shared_cap_ms,
      max_physical_playwright_cli_launches: freeze.ledger.physical_cli_launch_max,
      retry_used: 1,
      retry_available: 0
    }
  };
  fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  writeJson(evidenceFile, evidence);
  return evidence;
}

function preserveControlRecoveryEvidenceRevision(evidenceFile, root, evidence) {
  const relative = path.relative(root, evidenceFile);
  const bytes = fs.readFileSync(evidenceFile);
  const statusResult = run('git', ['-C', root, 'status', '--porcelain=v1', '--', relative]);
  if (statusResult.status !== 0) throw new Error('cannot capture evidence source status before replacement');
  const status = statusResult.stdout.trimEnd();
  const sha256Value = sha256(bytes);
  const blob = git(['-C', root, 'hash-object', '-w', '--', relative]);
  const ref = `refs/gsd/phase253-control-recovery-native-evidence/${sha256Value}`;
  const updated = run('git', ['-C', root, 'update-ref', ref, blob]);
  if (updated.status !== 0) throw new Error(`cannot preserve exact evidence revision under ${ref}: ${updated.stderr.trim()}`);
  if (!readGitBlob(root, ref).equals(bytes)) throw new Error(`exact evidence revision read-back failed for ${ref}`);
  evidence.preserved_revisions.push({ path: relative, status, sha256: sha256Value, blob, ref, bytes: bytes.length, read_back_exact: true });
  return evidence;
}

function writeControlRecoveryEvidence(evidenceFile, root, evidence) {
  if (fs.existsSync(evidenceFile)) preserveControlRecoveryEvidenceRevision(evidenceFile, root, evidence);
  writeJson(evidenceFile, evidence);
}

export function verifyControlRecoveryEvidenceData(evidence, freeze, baseDir, stage = 'complete', freezeFileHash = freeze?.freeze_sha256) {
  const errors = [];
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) return { ok: false, errors: ['native control recovery evidence is missing or malformed'] };
  if (freeze?.schema_version !== CONTROL_RECOVERY_FREEZE_SCHEMA || freeze.freeze_sha256 !== controlRecoveryFreezeDigest(freeze)
    || evidence.freeze_sha256 !== freezeFileHash) errors.push('evidence does not match the immutable recovery freeze');
  if (evidence.schema_version !== CONTROL_RECOVERY_SCHEMA || JSON.stringify(evidence.source) !== JSON.stringify(freeze.source)) errors.push('evidence source identity differs from the frozen commit and blobs');
  if (evidence.reservation || evidence.status === 'running') errors.push('evidence contains an unresolved predebit reservation');
  if (evidence.limits?.retry_used !== 1 || evidence.limits?.retry_available !== 0) errors.push('the spent shared retry was reopened or miscounted');
  if (evidence.limits?.prior_charge_ms !== 243044 || evidence.limits?.preparation_remaining_ms !== 112489) errors.push('carried historical charge or preparation balance changed');
  if (evidence.limits?.max_total_ms !== 3480000 || evidence.limits?.max_physical_playwright_cli_launches !== 18) errors.push('shared time or physical CLI launch ceiling changed');
  const attempts = Array.isArray(evidence.attempts) ? evidence.attempts : [];
  const count = stage === 'dark' ? 1 : stage === 'first' ? 2 : stage === 'complete' ? 5 : -1;
  if (count < 0 || attempts.length !== count) errors.push(`stage ${stage} requires exactly ${count} accepted new native command receipts`);
  const slots = freeze.ledger.slots.slice(0, Math.max(0, count));
  if (attempts.some((attempt, index) => attempt.slot_id !== slots[index]?.id)) errors.push('new commands do not match the exact unused reservation order');
  const usedSlots = [...freeze.ledger.spent_reservations, ...attempts.map((attempt) => attempt.slot_id)];
  if (JSON.stringify(evidence.limits?.used_slots) !== JSON.stringify(usedSlots)) errors.push('used reservation ledger differs from historical receipts and actual attempts');
  const measured = freeze.ledger.prior_charge_ms + attempts.reduce((sum, attempt) => sum + (Number(attempt.charged_duration_ms) || 0), 0) + (Number(evidence.limits?.preparation_charge_ms) || 0);
  if (evidence.limits?.charged_duration_ms !== measured) errors.push('cumulative charge does not equal preserved history, preparation and measured command receipts');
  const launches = freeze.ledger.prior_playwright_cli_launches + attempts.filter((attempt) => attempt.playwright_cli?.launched === true).length;
  if (evidence.limits?.physical_playwright_cli_launches !== launches || launches > freeze.ledger.physical_cli_launch_max) errors.push('physical Playwright CLI launch count differs from native receipts or exceeds its frozen ceiling');
  if (measured > freeze.ledger.d19.cap_ms || measured > freeze.ledger.shared_cap_ms) errors.push('D-19 or shared time limit was exceeded');
  if (stage === 'dark' || stage === 'first' || stage === 'complete') {
    for (const attempt of attempts) errors.push(...verifyNativeControlAttempt(attempt, freeze, baseDir).errors);
  }
  if (stage === 'dark' && evidence.status !== 'dark_complete') errors.push('dark command status is not accepted');
  if (stage !== 'dark' && evidence.status !== (stage === 'first' ? 'first_complete' : 'complete')) errors.push(`${stage} command status is not accepted`);
  return { ok: errors.length === 0, errors };
}

async function runControlRecoverySlot(freezeFile, slotId, evidenceFile, root = ROOT) {
  if (path.resolve(freezeFile) !== path.resolve(root, CONTROL_RECOVERY_FREEZE_PATH)
    || path.resolve(evidenceFile) !== path.resolve(root, CONTROL_RECOVERY_EVIDENCE_PATH)) throw new Error('control recovery accepts only the reviewed phase freeze and additive evidence paths');
  const freeze = readJson(freezeFile);
  validateControlRecoveryFreeze(root, freeze);
  const freezeHash = fileHash(freezeFile);
  if (!fs.existsSync(evidenceFile)) throw new Error('native control recovery evidence must be initialized and committed before launch');
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== CONTROL_RECOVERY_SCHEMA || evidence.freeze_sha256 !== freezeHash) throw new Error('native control evidence does not match the committed freeze');
  if (evidence.status !== 'ready' || evidence.reservation) throw new Error(`refusing to use terminal or reserved recovery evidence: ${evidence.status}`);
  const slot = freeze.ledger.slots.find((item) => item.id === slotId);
  if (!slot || slot.id !== 'CR-DARK-FIRST') throw new Error('Plan 27 may consume only the frozen CR-DARK-FIRST reservation');
  if (evidence.limits.used_slots.includes(slot.id)) throw new Error(`reservation ${slot.id} was already consumed`);
  const reserve = slot.max_duration_ms;
  const firstFourRemaining = freeze.ledger.slots.filter((item) => !evidence.limits.used_slots.includes(item.id)).length;
  if (reserve !== 120000 || evidence.limits.charged_duration_ms + reserve + 9 * 240000 > freeze.ledger.shared_cap_ms
    || evidence.limits.charged_duration_ms + firstFourRemaining * reserve > freeze.ledger.d19.cap_ms
    || evidence.limits.physical_playwright_cli_launches + firstFourRemaining + 9 > freeze.ledger.physical_cli_launch_max) {
    throw new Error('complete remaining D-19 and conditional D-20 reservations do not fit frozen limits');
  }
  const project = PROJECTS.find((item) => item.name === slot.project);
  if (!project || !(await portAvailable(project.port))) throw new Error(`frozen port ${project?.port ?? 'unknown'} is occupied before native setup`);
  const rawDir = `${evidenceFile}.raw`;
  const rawAttempt = createAttemptDirectory(rawDir, slot.id, 1);
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-control-recovery-'));
  const started = process.hrtime.bigint();
  const commandDeadline = Number(started) / 1e6 + reserve;
  const cleanupReserve = freeze.ledger.cleanup_reserve_ms;
  const workDeadline = commandDeadline - cleanupReserve;
  const database = `sigra_253_control_dark_${Date.now().toString(36)}_${process.pid}`.toLowerCase();
  const env = diagnosticEnvironment(project, database, tempRoot);
  const tempPaths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(tempRoot, `${name.replaceAll('_', '-')}.log`)]));
  const reportTemp = path.join(tempRoot, 'playwright-report.json');
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: slot.project, argv: slot.argv,
    source_commit: freeze.source.checkout_head, source_blobs: freeze.source.blobs,
    started_monotonic_ns: started.toString(), database: { name: database, setup_exit_code: null, drop_exit_code: null, connection: databaseConnectionIdentity(env) },
    server: { port: project.port, http_status: null, app_pid: null },
    browser: { launched: false, exit_code: null }, playwright_cli: { launched: false, exit_code: null },
    observed_outcome: 'setup_failed', files: {}, traces: [], trace_assertion: [], transport_observations: [],
    registration: { server_post_confirmed: false },
    toolchain: { playwright: null, ecto_sql: freeze.tools.ecto_sql, phoenix_live_view: freeze.tools.phoenix_live_view },
    build_path: env.MIX_BUILD_PATH,
    stage_deadlines: { command_ms: reserve, work_ms: reserve - cleanupReserve, cleanup_ms: cleanupReserve, cleanup_reserved: true }
  };
  evidence.status = 'running';
  evidence.reservation = { slot_id: slot.id, mapped_from: slot.maps_from, reserved_ms: reserve, predebited_at: new Date().toISOString(), source_commit: freeze.source.checkout_head };
  evidence.limits.used_slots.push(slot.id);
  writeControlRecoveryEvidence(evidenceFile, root, evidence);
  let app = null;
  let terminalError = null;
  const playwrightDir = path.join(root, 'test/example/priv/playwright');
  try {
    const setup = await runLoggedTree('mix', ['ecto.setup'], path.join(root, 'test/example'), env, tempPaths.setup_log, workDeadline - Number(process.hrtime.bigint()) / 1e6);
    attempt.setup = setup;
    attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0 || setup.timed_out) throw new Error(`fresh control database setup failed${setup.timed_out ? ' at its work deadline' : ` with exit ${setup.exit_code ?? 'null'}`}`);
    const appFd = fs.openSync(tempPaths.app_log, 'w');
    try { app = spawn('mix', ['phx.server'], { cwd: path.join(root, 'test/example'), env, stdio: ['ignore', appFd, appFd], detached: true }); }
    finally { fs.closeSync(appFd); }
    attempt.server.app_pid = app.pid ?? null;
    attempt.server.http_status = app.pid ? await waitReady(app, `http://127.0.0.1:${project.port}/`, workDeadline) : null;
    if (attempt.server.http_status !== 200) throw new Error('fresh control app did not return HTTP 200 before the reserved work deadline');
    const installed = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installed !== freeze.tools.expected_playwright) throw new Error(`installed Playwright ${installed} differs from the frozen ${freeze.tools.expected_playwright}`);
    attempt.toolchain.playwright = installed;
    attempt.browser.launched = true;
    attempt.playwright_cli.launched = true;
    const args = ['test', freeze.selection.spec, ...slot.argv, `--output=${path.join(tempRoot, 'playwright-output')}`];
    attempt.browser_command_argv = args;
    const browser = await runLoggedTree(path.join(playwrightDir, 'node_modules/.bin/playwright'), args, playwrightDir, {
      ...env, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${project.port}`,
      SIGRA_PLAYWRIGHT_JSON: reportTemp, SIGRA_REGISTRATION_CONTROL_STAGE: 'first',
      SIGRA_CONTROL_RUN_ID: `${slot.id.toLowerCase()}-${crypto.randomUUID()}`,
      SIGRA_CONTROL_ACCOUNT_PREFIX: 'platform-admin+sigra-253-control',
      PLAYWRIGHT_HTML_OUTPUT_DIR: path.join(tempRoot, 'html-report')
    }, tempPaths.test_log, workDeadline - Number(process.hrtime.bigint()) / 1e6);
    attempt.test_command = browser;
    attempt.browser.exit_code = browser.exit_code;
    attempt.playwright_cli.exit_code = browser.exit_code;
    if (browser.timed_out) throw new Error('native Playwright command reached the reserved work deadline');
    if (!fs.existsSync(reportTemp) || fs.statSync(reportTemp).size === 0) throw new Error('native Playwright JSON report is absent or empty');
    const report = readJson(reportTemp);
    const tests = playReportTests(report);
    for (const item of tests) {
      for (const attachment of item.attachments ?? []) {
        if (attachment.name !== 'trace' && !String(attachment.path ?? '').endsWith('trace.zip')) continue;
        if (!attachment.path || !fs.existsSync(attachment.path)) throw new Error(`native trace attachment for ${item.title} is missing`);
        const target = path.join(rawAttempt, `trace-${attempt.traces.length + 1}.zip`);
        const trace = sanitizeTraceFile(attachment.path, target);
        const receipt = receiptFile(rawDir, 'sanitized native trace', target);
        attempt.traces.push({ ...receipt, title: item.title, sanitization: trace });
        attachment.path = path.relative(root, target);
      }
    }
    attempt.files.traces = attempt.traces;
    const safeReport = path.join(rawAttempt, 'playwright-report.json');
    fs.writeFileSync(safeReport, `${JSON.stringify(sanitizeReportText(report), null, 2)}\n`, { flag: 'wx' });
    attempt.files.playwright_report = receiptFile(rawDir, 'sanitized native Playwright report', safeReport);
    const appBeforeSanitize = fs.existsSync(tempPaths.app_log) ? fs.readFileSync(tempPaths.app_log, 'utf8') : '';
    attempt.registration.server_post_confirmed = /POST \/users\/log_in/.test(appBeforeSanitize);
    attempt.transport_observations = tests.map((item) => ({ title: item.title, context_ids: controlAnnotations(item, 'sigra-registration-control-context'), result: controlAnnotations(item, 'sigra-registration-control-result') }));
    attempt.native_selection = { project: project.name, spec: freeze.selection.spec, selected_titles: slot.selected_titles, expected_cli_exit: 1 };
    attempt.observed_outcome = 'native_report_pending_validation';
  } catch (error) {
    terminalError = error.message;
  } finally {
    await stopApp(app);
    if (fs.existsSync(tempPaths.app_log)) attempt.log_redactions_app = sanitizeCommandLog(tempPaths.app_log);
    const cleanupRemaining = commandDeadline - Number(process.hrtime.bigint()) / 1e6;
    if (cleanupRemaining <= 0) terminalError = [terminalError, 'owned cleanup exceeded the 120,000 ms command limit'].filter(Boolean).join('; ');
    const drop = await runLoggedTree('mix', ['ecto.drop', '--quiet'], path.join(root, 'test/example'), env, tempPaths.drop_log, Math.max(1, Math.min(7000, cleanupRemaining - 5000)));
    attempt.database.drop_exit_code = drop.exit_code;
    attempt.drop_command = drop;
    if (drop.exit_code !== 0 || drop.timed_out) terminalError = [terminalError, `database drop failed${drop.timed_out ? ' at cleanup deadline' : ` with exit ${drop.exit_code ?? 'null'}`}`].filter(Boolean).join('; ');
    if (drop.exit_code === 0 && !drop.timed_out) {
      // Charged inside the same reserved cleanup window; the command deadline is never extended.
      const absenceLog = path.join(tempRoot, 'database-absence.log');
      try { attempt.database.absence_receipt = captureOwnedDatabaseAbsence({ database, env, cwd: path.join(root, 'test/example'), log: absenceLog, deadline: commandDeadline }); }
      catch (error) { terminalError = [terminalError, `independent database absence query failed: ${error.message}`].filter(Boolean).join('; '); }
    }
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    if (!fs.existsSync(tempPaths[name])) fs.writeFileSync(tempPaths[name], `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    const target = path.join(rawAttempt, `${name.replaceAll('_', '-')}.log`);
    fs.copyFileSync(tempPaths[name], target, fs.constants.COPYFILE_EXCL);
    attempt.files[name] = receiptFile(rawDir, `sanitized ${name}`, target);
  }
  const absenceTemp = path.join(tempRoot, 'database-absence.log');
  if (fs.existsSync(absenceTemp)) {
    const target = path.join(rawAttempt, 'database-absence.log');
    fs.copyFileSync(absenceTemp, target, fs.constants.COPYFILE_EXCL);
    attempt.files.database_absence = receiptFile(rawDir, 'owned database absence query log', target);
  }
  attempt.ended_monotonic_ns = process.hrtime.bigint().toString();
  attempt.execution_duration_ms = Math.ceil(Number(BigInt(attempt.ended_monotonic_ns) - BigInt(attempt.started_monotonic_ns)) / 1e6);
  attempt.charged_duration_ms = attempt.execution_duration_ms;
  if (attempt.charged_duration_ms > reserve) terminalError = [terminalError, 'native command exceeded its frozen 120,000 ms command reservation'].filter(Boolean).join('; ');
  const validation = verifyNativeControlAttempt(attempt, freeze, rawDir);
  if (!validation.ok) terminalError = [terminalError, ...validation.errors].filter(Boolean).join('; ');
  evidence.reservation = null;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  if (attempt.playwright_cli.launched) evidence.limits.physical_playwright_cli_launches += 1;
  evidence.attempts.push(attempt);
  if (terminalError) {
    evidence.status = 'halted'; evidence.stop_reason = terminalError; attempt.observed_outcome = 'halted';
  } else {
    evidence.status = 'dark_complete'; attempt.observed_outcome = 'native_dark_and_first_controls_accepted';
  }
  writeControlRecoveryEvidence(evidenceFile, root, evidence);
  fs.rmSync(tempRoot, { recursive: true, force: true });
  if (!terminalError) {
    const verified = verifyControlRecoveryEvidenceData(evidence, freeze, rawDir, 'dark', freezeHash);
    if (!verified.ok) {
      evidence.status = 'halted'; evidence.stop_reason = verified.errors.join('; ');
      writeControlRecoveryEvidence(evidenceFile, root, evidence);
      throw new Error(`native dark receipt rejected: ${verified.errors.join('; ')}`);
    }
  }
  if (terminalError) throw new Error(terminalError);
  return { status: evidence.status, slot: slot.id, charged_duration_ms: attempt.charged_duration_ms, physical_playwright_cli_launches: evidence.limits.physical_playwright_cli_launches };
}

function controlFreezeDigest(freeze) {
  return sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))));
}

export function createControlFreeze(priorEvidenceFile, outputFile, root = ROOT) {
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite the additive Plan 16 control source freeze');
  const prior = readJson(priorEvidenceFile);
  const priorFreezeFile = path.resolve(root, prior.freeze_path ?? '');
  const priorFreeze = readJson(priorFreezeFile);
  const priorFailedFile = path.join(root, REPLAN_EVIDENCE_PATH);
  const priorFailed = readJson(priorFailedFile);
  const priorAcceptedCheck = verifyRevisionFile(priorEvidenceFile, root);
  if (!priorAcceptedCheck.ok || prior.status !== 'diagnosis_incomplete' || prior.attempts?.length !== 2
    || prior.limits?.charged_duration_ms !== 121_680 || prior.limits?.browser_launches !== 2
    || JSON.stringify(prior.limits?.used_slots) !== JSON.stringify(['R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE'])) {
    throw new Error('the accepted Plan 15 sanitized receipt and its exact native counts are required before freezing Plan 16');
  }
  if (priorFailed.status !== 'halted' || priorFailed.attempts?.length !== 1
    || priorFailed.attempts[0]?.slot_id !== 'R-DIAG-DESKTOP' || priorFailed.limits?.charged_duration_ms !== 33_884
    || priorFailed.limits?.browser_launches !== 1) throw new Error('the original failed desktop receipt is missing or its preserved charge differs');
  const priorArtifacts = [
    { path: path.relative(root, priorEvidenceFile), sha256: fileHash(priorEvidenceFile), role: 'accepted sanitized Plan 15 retry and mobile proof' },
    { path: path.relative(root, priorFreezeFile), sha256: fileHash(priorFreezeFile), role: 'Plan 15 source freeze' },
    { path: path.relative(root, priorFailedFile), sha256: fileHash(priorFailedFile), role: 'immutable initial failed desktop receipt' },
    { path: path.join(PHASE_DIR, '253-15-INFRASTRUCTURE-RETRY-REVIEW.json'), sha256: fileHash(path.join(root, PHASE_DIR, '253-15-INFRASTRUCTURE-RETRY-REVIEW.json')), role: 'independent infrastructure retry classification' },
    { path: path.join(PHASE_DIR, '253-15-SHARED-RETRY-USED.json'), sha256: fileHash(path.join(root, PHASE_DIR, '253-15-SHARED-RETRY-USED.json')), role: 'consumed one-use shared retry marker' },
    { path: path.join(PHASE_DIR, '253-09-TERMINAL-DIAGNOSTIC.json'), sha256: fileHash(path.join(root, PHASE_DIR, '253-09-TERMINAL-DIAGNOSTIC.json')), role: 'earlier historical 3,768 ms failure receipt' }
  ];
  if (priorArtifacts.some((item) => !item.sha256)) throw new Error('a prior registration receipt cannot be identified by exact bytes');
  for (const artifact of priorArtifacts) {
    if (fileHash(path.resolve(root, artifact.path)) !== artifact.sha256) throw new Error(`prior registration evidence changed before freeze: ${artifact.path}`);
  }
  const attemptCharges = prior.attempts.reduce((sum, item) => sum + item.charged_duration_ms, 0);
  const historicalCharge = priorFailed.limits.charged_duration_ms + attemptCharges;
  const launchCount = priorFailed.limits.browser_launches + prior.limits.browser_launches;
  if (attemptCharges !== 87_796 || historicalCharge !== 121_680 || launchCount !== 3) throw new Error('complete native ledger arithmetic does not match 121,680 ms and three physical browser launches');
  const regularSlots = controlSlotDefinitions();
  const remainingRegularReserve = regularSlots.length * PROJECT_SLOT_MS;
  const d19Cap = 20 * 60 * 1000;
  const d20Cap = 36 * 60 * 1000;
  if (regularSlots.length !== 6 || historicalCharge + remainingRegularReserve > d19Cap) throw new Error('the six regular Plan 16 controls cannot fit inside their frozen D-19 budget');
  const head = assertRevisionCheckout(root);
  const source = Object.fromEntries(CONTROL_SOURCE_FILES.map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`]) ]));
  const exunitOwners = Object.fromEntries(['test/example/test/support/data_case.ex', 'test/support/postgres_case.ex'].map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`]) ]));
  const freeze = {
    schema_version: CONTROL_FREEZE_SCHEMA,
    status: 'frozen_before_results',
    frozen_at: new Date().toISOString(),
    source: { repository: 'szTheory/sigra', checkout_head: head, blobs: source },
    prior_artifacts: priorArtifacts,
    prior_ledger: {
      original_historical_ms: 3_768,
      initial_failed_desktop_ms: priorFailed.limits.charged_duration_ms - 3_768,
      shared_retry_ms: prior.attempts.find((item) => item.slot_id === 'R-INFRA-RETRY-DESKTOP').charged_duration_ms,
      mobile_ms: prior.attempts.find((item) => item.slot_id === 'R-DIAG-MOBILE').charged_duration_ms,
      total_charged_ms: historicalCharge,
      physical_browser_launches: launchCount,
      consumed_shared_retry_count: 1,
      prior_used_slots: ['R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE']
    },
    ledger: {
      slots: regularSlots,
      total_browser_launch_ceiling: 18,
      d19: { cap_ms: d19Cap, remaining_commands: 6, each_max_duration_ms: PROJECT_SLOT_MS, reserve_ms: remainingRegularReserve, infrastructure_retry_available: false },
      d20: { cap_ms: d20Cap, acceptance_slots_reserved: 9, each_max_duration_ms: 240_000, retry_available: false },
      shared_cap_ms: TOTAL_CAP_MS,
      no_capacity_added: true
    },
    selection: {
      spec: 'tests/admin-eval.spec.ts',
      workers: 1, retries: 0, trace: 'retain-on-failure', fully_parallel: false,
      dark_combined_original_title: CONTROL_BOARD_TITLE,
      first_titles: FIRST_CONTROLS,
      second_active_titles: CONTROL_SECOND_ACTIVE,
      second_pending_title: SECOND_CONTROLS[2],
      projects: REPLAN_PROJECTS.map((project) => project.name)
    },
    exunit_ownership: {
      source_blobs: exunitOwners,
      observed_boundary: 'Browser controls use a live MIX_ENV=dev database; ExUnit continues to use the existing Sandbox owner and allowance lifecycle. No ExUnit suite or seed ran in Plan 16.'
    },
    tools: {
      playwright_required: '1.59.1',
      ecto_sql: prior.attempts[0].toolchain.ecto_sql,
      phoenix_live_view: prior.attempts[0].toolchain.phoenix_live_view,
      observed_from_accepted_plan15_native_attempt: true
    },
    stop_conditions: ['source or prior receipt mismatch', 'unused 120,000 ms reserve does not fit', 'setup/readiness/drop/build cleanup failure', 'native report/trace mismatch', 'unexpected skip or assertion', 'collision or database/context identity mismatch', 'shared launch ceiling or D-19 clock exhaustion']
  };
  freeze.freeze_sha256 = controlFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return freeze;
}

function initializeControlEvidence(freezeFile, outputFile, root = ROOT) {
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite additive Plan 16 control evidence');
  const freeze = readJson(freezeFile);
  if (freeze.schema_version !== CONTROL_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== controlFreezeDigest(freeze)) throw new Error('control source freeze is missing or its internal digest is invalid');
  validateControlSource(root, freeze);
  const evidence = {
    schema_version: CONTROL_SCHEMA, status: 'running',
    freeze_path: path.relative(root, freezeFile), freeze_sha256: fileHash(freezeFile),
    source: structuredClone(freeze.source), prior_artifacts: structuredClone(freeze.prior_artifacts),
    created_at: new Date().toISOString(), attempts: [], reservation: null,
    pending_repair_regression: { title: freeze.selection.second_pending_title, state: 'pending_phase253_17_documented_cause' },
    limits: {
      prior_charge_ms: freeze.prior_ledger.total_charged_ms,
      charged_duration_ms: freeze.prior_ledger.total_charged_ms,
      reserved_ms: 0,
      physical_browser_launches: freeze.prior_ledger.physical_browser_launches,
      used_slots: [...freeze.prior_ledger.prior_used_slots],
      max_physical_browser_launches: freeze.ledger.total_browser_launch_ceiling,
      max_total_charged_ms: freeze.ledger.shared_cap_ms,
      d19_cap_ms: freeze.ledger.d19.cap_ms,
      d20_reserved_cap_ms: freeze.ledger.d20.cap_ms,
      d20_reserved_slots: freeze.ledger.d20.acceptance_slots_reserved,
      retry_count_used: freeze.prior_ledger.consumed_shared_retry_count,
      retry_count_available: 0
    }
  };
  writeJson(outputFile, evidence);
  return evidence;
}

function validateControlSource(root, freeze, evidenceFile = null) {
  assertDirtyConfigPreserved(root);
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  if (run('git', ['-C', root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]).status !== 0) throw new Error('control freeze source commit is not an ancestor of the execution checkout');
  for (const [file, expected] of Object.entries(freeze.source.blobs)) {
    if (git(['-C', root, 'hash-object', file]) !== expected) throw new Error(`control source identity mismatch for ${file}`);
  }
  for (const [file, expected] of Object.entries(freeze.exunit_ownership.source_blobs)) {
    if (git(['-C', root, 'hash-object', file]) !== expected) throw new Error(`ExUnit ownership source changed after freeze: ${file}`);
  }
  for (const artifact of freeze.prior_artifacts) {
    if (fileHash(path.resolve(root, artifact.path)) !== artifact.sha256) throw new Error(`prior native registration evidence changed: ${artifact.path}`);
  }
  const status = run('git', ['-C', root, 'status', '--porcelain=v1', '--untracked-files=all']);
  if (status.status !== 0) throw new Error('cannot read checkout status before native registration control');
  const expectedEvidence = evidenceFile ? path.relative(root, evidenceFile) : null;
  for (const line of status.stdout.split('\n').filter(Boolean)) {
    if (line === DIRTY_CONFIG.porcelain) continue;
    const code = line.slice(0, 2);
    const file = line.slice(3).replace(/^"|"$/g, '');
    if (expectedEvidence && file === expectedEvidence && [' M', '??'].includes(code)) continue;
    if (expectedEvidence && (file === `${expectedEvidence}.raw` || file.startsWith(`${expectedEvidence}.raw/`)) && code === '??') continue;
    throw new Error(`unexpected checkout change blocks a native control: ${line}`);
  }
  if (run('git', ['-C', root, 'diff', '--cached', '--quiet']).status !== 0) throw new Error('staged changes block a frozen native control');
  return head;
}

function controlTestError(result) {
  if (!result.error) return '';
  if (typeof result.error === 'string') return result.error;
  return [result.error.message, result.error.stack, result.error.value].filter(Boolean).join('\n');
}

function controlAnnotations(result, type) {
  return [...(result.annotations ?? []), ...(result.result_annotations ?? [])].filter((item) => item.type === type).map((item) => item.description ?? '');
}

const SAFE_DEMO_CREDENTIAL_MARKER = '[REDACTED seeded demo credentials]';
const DEMO_CREDENTIALS_HEADER = '=== Demo Credentials ===';

// Accepts a persisted command log only when every sensitive region has been replaced by the
// exact redaction line sanitizeCommandLog writes; anything else (plaintext rows, altered markers,
// unredacted signing keys, auth/session headers) is rejected rather than normalized.
export function validateSanitizedCommandLog(text) {
  const errors = [];
  if (typeof text !== 'string') return { ok: false, errors: ['command log text is missing'] };
  if (/secret_key_base"?\s*(?::|=>)\s*"(?!\[REDACTED\]")/i.test(text)) errors.push('development signing key is not redacted');
  if (/(?:set-cookie|authorization)\s*:/i.test(text) || /^[ \t]*cookie[ \t]*:/im.test(text)) errors.push('authorization or cookie header is present');
  const lines = text.split(/(?<=\n)/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.includes(DEMO_CREDENTIALS_HEADER)) {
      if (!/^\s*=== Demo Credentials ===\s*\r?\n?$/.test(line)) { errors.push('demo credentials header line carries extra content'); continue; }
      const marker = lines[index + 1];
      if (marker !== `${SAFE_DEMO_CREDENTIAL_MARKER}\n` && marker !== SAFE_DEMO_CREDENTIAL_MARKER) {
        errors.push('demo credentials block is not replaced by the exact redaction line');
        continue;
      }
      const after = lines[index + 2];
      if (after !== undefined && after.trim() !== '') errors.push('extra credential row follows the redaction line');
      index += 1;
      continue;
    }
    if (line.includes('REDACTED seeded demo credentials')) errors.push('redaction marker appears outside a demo credentials block or is altered');
  }
  return { ok: errors.length === 0, errors };
}

const EMPTY_SHA256 = crypto.createHash('sha256').update('').digest('hex');
const DATABASE_ABSENCE_SCHEMA = 'sigra.phase253.owned-database-absence/v1';
const DATABASE_ABSENCE_QUERY = "SELECT count(*) FROM pg_database WHERE datname = :'target';\n";
const OWNED_CONTROL_DATABASE = /^sigra_253_control_[a-z0-9_]+$/;

function databaseAbsenceArgv(database, connection) {
  return ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-v', `target=${database}`, '-A', '-t',
    '-h', String(connection.host), '-p', String(connection.port), '-U', String(connection.user), '-d', 'postgres'];
}

export function databaseConnectionIdentity(env) {
  return { host: String(env.PGHOST ?? ''), port: String(env.PGPORT ?? ''), user: String(env.PGUSER ?? ''), maintenance_database: 'postgres' };
}

// Independent proof that quiet `mix ecto.drop` really removed the owned database: a bounded psql
// catalog query against the maintenance database. The password stays in the environment only.
export function captureOwnedDatabaseAbsence({ database, env, cwd, log, deadline, run = spawnSync }) {
  if (!OWNED_CONTROL_DATABASE.test(database ?? '')) throw new Error('refusing to query a database outside the synthetic control namespace');
  const connection = databaseConnectionIdentity(env);
  if (!connection.host || !connection.port || !connection.user) throw new Error('database absence query needs PGHOST, PGPORT and PGUSER');
  const argv = databaseAbsenceArgv(database, connection);
  const started = process.hrtime.bigint();
  const timeout = Math.max(1, Math.floor(deadline - Number(started) / 1e6));
  let result = null; let thrown = null;
  try {
    result = run(argv[0], argv.slice(1), { cwd, env: { ...env, PGDATABASE: 'postgres' }, input: DATABASE_ABSENCE_QUERY, encoding: 'utf8', timeout, killSignal: 'SIGKILL', maxBuffer: 65536 });
  } catch (error) { thrown = error; }
  const ended = process.hrtime.bigint();
  const stdout = typeof result?.stdout === 'string' ? result.stdout : '';
  fs.writeFileSync(log, stdout);
  const error = thrown?.message ?? result?.error?.message ?? null;
  const timedOut = result?.error?.code === 'ETIMEDOUT';
  return {
    schema_version: DATABASE_ABSENCE_SCHEMA, database, argv, query: DATABASE_ABSENCE_QUERY,
    query_sha256: crypto.createHash('sha256').update(DATABASE_ABSENCE_QUERY).digest('hex'),
    connection, exit_code: result?.status ?? null, signal: result?.signal ?? null, timed_out: timedOut, error,
    started_monotonic_ns: started.toString(), ended_monotonic_ns: ended.toString(),
    duration_ms: Math.ceil(Number(ended - started) / 1e6),
    stdout_count: /^\d+\n$/.test(stdout) ? Number(stdout.trim()) : null,
    log_bytes: Buffer.byteLength(stdout), log_sha256: crypto.createHash('sha256').update(stdout).digest('hex')
  };
}

export function verifyDatabaseAbsenceReceipt(receipt, attempt, baseDir) {
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!receipt || typeof receipt !== 'object' || Array.isArray(receipt)) return { ok: false, errors: ['independent database absence receipt is missing'] };
  const database = attempt?.database?.name;
  if (receipt.schema_version !== DATABASE_ABSENCE_SCHEMA) fail('absence receipt schema is unsupported');
  if (!OWNED_CONTROL_DATABASE.test(database ?? '') || receipt.database !== database) fail('absence receipt is not for the exact owned control database');
  const connection = receipt.connection;
  const expectedConnection = attempt?.database?.connection;
  if (!connection || connection.maintenance_database !== 'postgres' || !connection.host || !connection.port || !connection.user
    || !expectedConnection || JSON.stringify(connection) !== JSON.stringify(expectedConnection)) fail('absence receipt connection differs from the owned database connection identity');
  if (JSON.stringify(receipt).match(/password/i)) fail('absence receipt retains credential material');
  if (connection && JSON.stringify(receipt.argv) !== JSON.stringify(databaseAbsenceArgv(database, connection))) fail('absence query argv is not the exact parameterized catalog query');
  if (receipt.query !== DATABASE_ABSENCE_QUERY || receipt.query_sha256 !== crypto.createHash('sha256').update(DATABASE_ABSENCE_QUERY).digest('hex')) fail('absence query text or digest was altered');
  if (receipt.exit_code !== 0 || receipt.signal !== null || receipt.timed_out !== false || receipt.error !== null) fail('absence query did not exit cleanly within its deadline');
  if (receipt.stdout_count !== 0) fail('absence query did not return exactly zero rows for the owned database');
  let started = 0n; let ended = 0n; let attemptStart = 0n; let attemptEnd = 0n;
  try { started = BigInt(receipt.started_monotonic_ns); ended = BigInt(receipt.ended_monotonic_ns); attemptStart = BigInt(attempt.started_monotonic_ns); attemptEnd = BigInt(attempt.ended_monotonic_ns); } catch { /* reported below */ }
  if (started <= 0n || ended <= started || Math.ceil(Number(ended - started) / 1e6) !== receipt.duration_ms) fail('absence query monotonic duration is missing or inconsistent');
  else if (started < attemptStart || ended > attemptEnd) fail('absence query ran outside the charged native command window');
  const reference = attempt?.files?.database_absence;
  const file = confinedFile(baseDir, reference);
  if (!file || !fs.existsSync(file)) fail('absence query log is missing');
  else {
    const bytes = fs.readFileSync(file);
    if (!reference.sha256 || fileHash(file) !== reference.sha256 || receipt.log_sha256 !== reference.sha256 || receipt.log_bytes !== bytes.length) fail('absence query log digest or size mismatch');
    if (bytes.toString('utf8') !== '0\n') fail('absence query log is not exactly a zero count');
  }
  return { ok: errors.length === 0, errors };
}

export function verifyNativeControlAttempt(attempt, freeze, baseDir) {
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!attempt || typeof attempt !== 'object') return { ok: false, errors: ['native control attempt is missing'] };
  const slot = freeze.ledger.slots.find((item) => item.id === attempt.slot_id);
  if (!slot) fail('attempt does not identify a frozen control slot');
  else {
    if (attempt.sequence !== slot.sequence || attempt.stage !== slot.stage || attempt.project !== slot.project) fail('attempt identity differs from its frozen control slot');
    if (JSON.stringify(attempt.argv) !== JSON.stringify(slot.argv)) fail('native Playwright argv differs from the frozen title/project selection');
    if (!Number.isSafeInteger(attempt.charged_duration_ms) || attempt.charged_duration_ms < 0 || attempt.charged_duration_ms > slot.max_duration_ms) fail('native control exceeded its 120,000 ms command reservation');
  }
  if (attempt.source_commit !== freeze.source.checkout_head || JSON.stringify(attempt.source_blobs) !== JSON.stringify(freeze.source.blobs)) fail('control attempt does not match the frozen source commit and blobs');
  let started = 0n; let ended = 0n;
  try { started = BigInt(attempt.started_monotonic_ns); ended = BigInt(attempt.ended_monotonic_ns); } catch { /* reported below */ }
  if (started <= 0n || ended <= started || Math.ceil(Number(ended - started) / 1e6) !== attempt.execution_duration_ms) fail('native command monotonic duration is missing or inconsistent');
  if (attempt.charged_duration_ms !== attempt.execution_duration_ms) fail('native command charge does not include its complete measured setup, boot, browser and cleanup time');
  if (attempt.database?.setup_exit_code !== 0 || attempt.database?.drop_exit_code !== 0) fail('fresh database setup or drop did not succeed');
  if (!/^sigra_253_control_[a-z0-9_]+$/.test(attempt.database?.name ?? '')) fail('database identity is outside the synthetic control namespace');
  if (attempt.server?.http_status !== 200 || !Number.isInteger(attempt.server?.app_pid)) fail('server readiness or app process identity is missing');
  if (attempt.browser?.launched !== true || !Number.isInteger(attempt.browser?.exit_code)) fail('native Playwright launch or CLI exit is missing');
  if (attempt.build_directory_removed !== true || !attempt.build_path?.endsWith('/mix-build')) fail('fresh physical Mix build was not removed after the attempt');
  const absence = verifyDatabaseAbsenceReceipt(attempt.database?.absence_receipt, attempt, baseDir);
  for (const message of absence.errors) fail(`independent database absence: ${message}`);
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log', 'playwright_report']) {
    const reference = attempt.files?.[name]; const file = confinedFile(baseDir, reference);
    if (!file || !fs.existsSync(file)) { fail(`sanitized native ${name.replaceAll('_', ' ')} is missing`); continue; }
    if (!reference.sha256 || fileHash(file) !== reference.sha256) fail(`sanitized native ${name.replaceAll('_', ' ')} digest mismatch`);
    if (!fs.statSync(file).size) {
      // Only a quiet drop may be empty, and only with a clean exit plus the independent absence proof.
      const quietDropProven = name === 'drop_log' && reference.sha256 === EMPTY_SHA256 && attempt.database?.drop_exit_code === 0 && absence.ok;
      if (!quietDropProven) fail(`sanitized native ${name.replaceAll('_', ' ')} is empty`);
    }
    if (name.endsWith('_log')) {
      const sanitation = validateSanitizedCommandLog(fs.readFileSync(file, 'utf8'));
      if (!sanitation.ok) fail(`${name} contains an unsanitized credential block or auth header: ${sanitation.errors.join('; ')}`);
    }
  }
  let tests = [];
  const reportFile = confinedFile(baseDir, attempt.files?.playwright_report);
  if (reportFile && fs.existsSync(reportFile)) {
    try {
      const report = readJson(reportFile);
      if (!Array.isArray(report.suites) || !Array.isArray(report.errors)) fail('native Playwright JSON report is structurally incomplete');
      tests = playReportTests(report);
      if (!tests.length) fail('native Playwright JSON report is empty');
      if (report.errors.length) fail('native Playwright report contains top-level errors');
    } catch (error) { fail(`native Playwright JSON report could not be parsed: ${error.message}`); }
  }
  const selected = slot?.selected_titles ?? [];
  const selectedResults = [];
  for (const title of selected) {
    const matching = tests.filter((item) => item.title === title && item.project === attempt.project && path.basename(item.file) === 'admin-eval.spec.ts');
    if (matching.length !== 1) { fail(`native report must contain exactly one selected result for ${title}`); continue; }
    const result = matching[0]; selectedResults.push({ title, result });
    if (result.result_count !== 1 || ['skipped', 'interrupted', 'flaky'].includes(result.summary_status) || result.status === 'skipped') fail(`${title} was skipped, retried, interrupted, or has multiple native results`);
    const expected = slot.expected[title];
    if (expected === 'expected_failure') {
      if (result.expected_status !== 'passed' || result.status !== 'failed' || result.summary_status !== 'unexpected') fail(`${title} did not produce its expected native assertion failure`);
      const marker = CONTROL_EXPECTED_FAILURE_MARKERS[title];
      if (!controlTestError(result).includes(marker)) fail(`${title} failure report omits its frozen original assertion marker`);
      if (!controlAnnotations(result, 'sigra-registration-control-context').length) fail(`${title} failure has no native browser-context identity annotation`);
    } else {
      if (result.expected_status !== 'passed' || result.status !== 'expected' || result.summary_status !== 'expected') fail(`${title} did not pass natively as frozen`);
    }
    const contextIds = controlAnnotations(result, 'sigra-registration-control-context');
    if (title !== CONTROL_BOARD_TITLE && (!contextIds.length || contextIds.some((value) => !/^[a-z0-9-]+:[a-f0-9-]{36}$/i.test(value)))) fail(`${title} omitted its fresh browser-context identity`);
  }
  const expectedFailures = selectedResults.filter(({ title }) => slot.expected[title] === 'expected_failure');
  const traces = attempt.files?.traces ?? [];
  if (traces.length !== expectedFailures.length) fail('retained native trace count does not exactly match the frozen expected-failure controls');
  for (const trace of traces) {
    const file = confinedFile(baseDir, trace);
    if (!file || !fs.existsSync(file) || !trace.sha256 || fileHash(file) !== trace.sha256 || fs.statSync(file).size < 22) fail('native failure trace is absent, empty, or has a digest mismatch');
  }
  const forcedTrace = traces.find((trace) => trace.title === 'registration retains the first forced assertion failure trace');
  if (forcedTrace && (!forcedTrace.sanitization?.navigation || !forcedTrace.sanitization?.submission)) fail('forced failure trace omits navigation or actual submit/click actions');
  const appLog = attempt.files?.app_log && confinedFile(baseDir, attempt.files.app_log);
  const appText = appLog && fs.existsSync(appLog) ? fs.readFileSync(appLog, 'utf8') : '';
  if (slot?.stage === 'first' && slot.project === 'admin-eval-dark' && !appText.includes('POST /users/log_in')) fail('forced failure trace command has no server-confirmed registration submission');
  const collisionResult = selectedResults.find(({ title }) => title === 'registration detects a deliberate same-account collision')?.result;
  if (collisionResult) {
    const annotations = controlAnnotations(collisionResult, 'sigra-registration-control-result').map((value) => { try { return JSON.parse(value); } catch { return null; } }).filter(Boolean);
    const collision = annotations.find((item) => item.first_registration_succeeded === true && item.duplicate_response_confirmed === true);
    if (!collision || !/^[a-f0-9]{64}$/.test(collision.collision_email_sha256 ?? '') || !appText.includes('POST /users/log_in')) fail('same-account collision lacks a persisted-first-registration receipt and duplicate response');
    attempt.collision_receipt = { account_sha256: collision?.collision_email_sha256, first_post_server_confirmed: Boolean(collision), database_name: attempt.database.name };
  }
  const forceResult = selectedResults.find(({ title }) => title === 'registration retains the first forced assertion failure trace')?.result;
  if (forceResult && (!appText.includes('POST /users/log_in') || !controlTestError(forceResult).includes('toHaveURL'))) fail('forced first assertion evidence lacks navigation, server submission, or its original assertion');
  const freshResult = selectedResults.find(({ title }) => title === 'registration starts from a fresh database and context')?.result;
  if (freshResult) {
    const annotations = controlAnnotations(freshResult, 'sigra-registration-control-result').map((value) => { try { return JSON.parse(value); } catch { return null; } }).filter(Boolean);
    const fresh = annotations.find((item) => item.fresh_database_account_created === true);
    if (!fresh || !/^[a-f0-9]{64}$/.test(fresh.prior_collision_account_email_sha256 ?? '') || !appText.includes('POST /users/log_in')) fail('fresh-state pass lacks a persisted new account after the prior collision identity was absent');
    attempt.fresh_state_receipt = { prior_collision_account_sha256: fresh?.prior_collision_account_email_sha256, new_database_name: attempt.database.name };
  }
  const tracePass = selectedResults.find(({ title }) => title === 'registration discards trace after a passing control')?.result;
  if (tracePass && traces.length) fail('passing control retained a trace despite retain-on-failure policy');
  const contextIds = selectedResults.flatMap(({ result }) => controlAnnotations(result, 'sigra-registration-control-context'));
  if (new Set(contextIds).size !== contextIds.length) fail('two selected cases reused the same browser-context identity');
  if (expectedFailures.some(({ title }) => title === 'registration waits for explicitly released LiveView readiness')) fail('the held readiness control must pass after its explicit release');
  if (slot && attempt.browser?.exit_code !== (expectedFailures.length ? 1 : 0)) fail('Playwright CLI exit does not match the frozen intended control failures');
  if (attempt.database?.name === attempt.prior_database_name) fail('control reused an earlier database identity');
  return { ok: errors.length === 0, errors };
}

export function verifyControlEvidenceData(evidence, freeze, baseDir, stage = 'complete', freezeFileHash = freeze?.freeze_sha256) {
  const errors = [];
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) return { ok: false, errors: ['native control evidence is missing or malformed'] };
  if (!freeze || freeze.schema_version !== CONTROL_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== controlFreezeDigest(freeze) || evidence.freeze_sha256 !== freezeFileHash) errors.push('control evidence does not match its immutable source freeze');
  if (evidence.schema_version !== CONTROL_SCHEMA || evidence.source?.checkout_head !== freeze?.source?.checkout_head
    || JSON.stringify(evidence.source?.blobs) !== JSON.stringify(freeze?.source?.blobs)) errors.push('control evidence source identity differs from the freeze');
  if (evidence.status === 'halted' || evidence.reservation) errors.push('control evidence contains a halted or unresolved predebit reservation');
  if (evidence.limits?.retry_count_available !== 0 || evidence.limits?.retry_count_used !== 1) errors.push('control ledger reopened or miscounted the one-use infrastructure retry');
  if (evidence.pending_repair_regression?.state !== 'pending_phase253_17_documented_cause'
    || evidence.pending_repair_regression?.title !== freeze?.selection?.second_pending_title) errors.push('cause-dependent regression title was claimed or lost instead of remaining pending');
  const requiredCount = stage === 'first' ? 3 : stage === 'complete' ? 6 : -1;
  if (requiredCount < 0) errors.push('unsupported control verification stage');
  const attempts = evidence.attempts;
  if (!Array.isArray(attempts) || attempts.length !== requiredCount) errors.push(`stage ${stage} requires exactly ${requiredCount} completed native commands`);
  const safeAttempts = Array.isArray(attempts) ? attempts : [];
  const expectedSlots = freeze?.ledger?.slots?.slice(0, requiredCount) ?? [];
  if (safeAttempts.some((item, index) => item.slot_id !== expectedSlots[index]?.id)) errors.push('control commands were missing, duplicated, or run out of frozen order');
  const frozenPriorSlots = freeze?.prior_ledger?.prior_used_slots ?? [];
  const frozenPriorCharge = Number(freeze?.prior_ledger?.total_charged_ms);
  if (!Number.isSafeInteger(frozenPriorCharge) || !Array.isArray(frozenPriorSlots)) errors.push('control freeze omits the immutable prior ledger');
  const usedSlots = evidence.limits?.used_slots;
  if (!Array.isArray(usedSlots) || JSON.stringify(usedSlots) !== JSON.stringify([...frozenPriorSlots, ...safeAttempts.map((item) => item.slot_id)])) errors.push('used-slot ledger differs from the previous immutable receipts and new native commands');
  const measuredCharge = (Number.isSafeInteger(frozenPriorCharge) ? frozenPriorCharge : 0) + safeAttempts.reduce((sum, item) => sum + (Number(item.charged_duration_ms) || 0), 0);
  if (evidence.limits?.charged_duration_ms !== measuredCharge) errors.push('cumulative charge does not equal the complete prior and new command ledgers');
  const physicalLaunches = (Number(freeze?.prior_ledger?.physical_browser_launches) || 0) + safeAttempts.filter((item) => item.browser?.launched).length;
  if (evidence.limits?.physical_browser_launches !== physicalLaunches || physicalLaunches > (freeze?.ledger?.total_browser_launch_ceiling ?? -1)) errors.push('physical browser launch count differs from native receipts or exceeds the shared ceiling');
  if (measuredCharge > (freeze?.ledger?.shared_cap_ms ?? -1) || measuredCharge > (freeze?.ledger?.d19?.cap_ms ?? -1)) errors.push('shared or D-19 native time ceiling was exceeded');
  if (freeze?.ledger?.d20?.acceptance_slots_reserved !== 9 || freeze?.ledger?.d20?.retry_available !== false) errors.push('D-20 acceptance time or retry reservation changed');
  for (const [index, attempt] of safeAttempts.entries()) {
    const result = verifyNativeControlAttempt(attempt, freeze, baseDir);
    errors.push(...result.errors.map((message) => `${attempt.project ?? 'unknown project'}: ${message}`));
    if (index > 0 && safeAttempts.slice(0, index).some((prior) => prior.database?.name === attempt.database?.name)) errors.push('two native slots reused the same physical database identity');
    if (index > 0 && safeAttempts.slice(0, index).some((prior) => prior.server?.app_pid === attempt.server?.app_pid)) errors.push('two native slots reused the same app process identity');
  }
  if (stage === 'first' && evidence.status !== 'first_complete') errors.push('first control bundle status is not complete');
  if (stage === 'complete' && evidence.status !== 'complete') errors.push('complete control bundle status is not complete');
  if (stage === 'complete') {
    const collisions = safeAttempts.filter((item) => item.collision_receipt);
    const fresh = safeAttempts.filter((item) => item.fresh_state_receipt);
    if (collisions.length !== 3 || fresh.length !== 3) errors.push('all three projects need native same-account collision and fresh-state receipts');
    for (const item of fresh) {
      const collision = collisions.find((candidate) => candidate.project === item.project);
      if (!collision || collision.database.name === item.database.name || collision.collision_receipt.account_sha256 !== item.fresh_state_receipt.prior_collision_account_sha256) errors.push(`${item.project}: fresh database does not prove the prior collision account absent before creating that same synthetic identity`);
    }
  }
  return { ok: errors.length === 0, errors };
}

function loadControlEvidence(freezeFile, evidenceFile, root = ROOT) {
  const freeze = readJson(freezeFile);
  if (freeze.schema_version !== CONTROL_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== controlFreezeDigest(freeze)) throw new Error('control source freeze is malformed or has an invalid digest');
  validateControlSource(root, freeze, evidenceFile);
  const freezeHash = fileHash(freezeFile);
  if (!fs.existsSync(evidenceFile)) throw new Error('additive native control evidence must be initialized and committed before launch');
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== CONTROL_SCHEMA || evidence.freeze_sha256 !== freezeHash) throw new Error('control evidence does not match the committed source freeze');
  return { freeze, freezeHash, evidence, rawDir: `${evidenceFile}.raw` };
}

const TRACE_SCRUBBER = String.raw`
import json,re,sys,zipfile
src,dst=sys.argv[1:3]
secret=re.compile(r'(password|cookie|authorization|_csrf_token|csrf[_-]?token|secret|api[_-]?key|passkey)([\s=:"%]+)([^&\s,";}]+)',re.I)
def scrub(v,parent=''):
    if isinstance(v,dict):
        is_password=v.get('type')=='password'
        out={}
        for k,x in v.items():
            if re.search(r'password|cookie|authorization|csrf|secret|token|api[_-]?key|passkey',k,re.I): out[k]='[REDACTED]'
            elif is_password and k in ('value','values'): out[k]='[REDACTED]'
            elif k.lower() in ('headers','requestheaders','responseheaders') and isinstance(x,list):
                out[k]=[{**h,'value':'[REDACTED]'} if isinstance(h,dict) and re.search(r'cookie|authorization|csrf|token|secret',str(h.get('name','')),re.I) else scrub(h,k) for h in x]
            else: out[k]=scrub(x,k)
        return out
    if isinstance(v,list): return [scrub(x,parent) for x in v]
    if isinstance(v,str):
        v=secret.sub(lambda m:m.group(1)+m.group(2)+'[REDACTED]',v)
        v=re.sub(r'(?i)(<input\b[^>]*type=["\']password["\'][^>]*\bvalue=)["\'][^"\']*["\']',r'\1"[REDACTED]"',v)
        return v
    return v
entries=0; redactions=0; content=[]
with zipfile.ZipFile(src,'r') as zin, zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data=zin.read(item.filename); entries+=1
        if item.filename.lower().endswith(('.json','.trace','.html','.txt')):
            try:
                raw=data.decode('utf-8')
                if item.filename.endswith('.trace') or item.filename.endswith('.json'):
                    rows=[]
                    for line in raw.splitlines():
                        try: rows.append(json.dumps(scrub(json.loads(line)),separators=(',',':')))
                        except Exception: rows.append(secret.sub(lambda m:m.group(1)+m.group(2)+'[REDACTED]',line))
                    cleaned='\n'.join(rows)+'\n'
                else: cleaned=scrub(raw)
                redactions += raw.count('[REDACTED]')-cleaned.count('[REDACTED]') if False else 0
                data=cleaned.encode('utf-8'); content.append(cleaned)
            except UnicodeDecodeError: pass
        zout.writestr(item,data)
joined='\n'.join(content).lower()
print(json.dumps({'entries':entries,'navigation':('goto' in joined or 'navigation' in joined),'submission':('submit' in joined or 'click' in joined),'redacted':redactions}))
`;

function sanitizeTraceFile(source, destination) {
  const result = spawnSync('python3', ['-c', TRACE_SCRUBBER, source, destination], { encoding: 'utf8', timeout: 10_000, maxBuffer: 1024 * 1024 });
  if (result.status !== 0) throw new Error(`native trace sanitizer failed${result.error ? `: ${result.error.message}` : `: ${result.stderr.trim()}`}`);
  let receipt;
  try { receipt = JSON.parse(result.stdout); } catch { throw new Error('native trace sanitizer returned no structural receipt'); }
  if (!Number.isSafeInteger(receipt.entries) || receipt.entries < 1) throw new Error('sanitized native trace contains no readable action records');
  return receipt;
}

function sanitizeReportText(value) {
  if (typeof value === 'string') return value
    .replace(/(password|cookie|authorization|_csrf_token|csrf[_-]?token|secret|api[_-]?key|passkey)([\s=:"%]+)([^&\s,";}]+)/gi, '$1$2[REDACTED]');
  if (Array.isArray(value)) return value.map(sanitizeReportText);
  if (value && typeof value === 'object') {
    const result = {};
    for (const [key, item] of Object.entries(value)) {
      result[key] = /password|cookie|authorization|csrf|secret|token|api[_-]?key|passkey/i.test(key) ? '[REDACTED]' : sanitizeReportText(item);
    }
    return result;
  }
  return value;
}

async function runControlRevision(freezeFile, slotId, evidenceFile, stage, root = ROOT) {
  const { freeze, freezeHash, evidence, rawDir } = loadControlEvidence(freezeFile, evidenceFile, root);
  if (evidence.status !== 'running' && evidence.status !== 'first_complete') throw new Error(`refusing to continue terminal control evidence: ${evidence.status}`);
  if (evidence.reservation) throw new Error('an earlier control command retains a predebit reservation; it cannot be retried or windowed');
  const slot = freeze.ledger.slots.find((item) => item.id === slotId);
  if (!slot || slot.stage !== stage) throw new Error(`slot ${slotId} is not a frozen ${stage} control`);
  const nextSlot = freeze.ledger.slots[evidence.attempts.length];
  if (slot.id !== nextSlot?.id) throw new Error(`next unused native control slot is ${nextSlot?.id ?? 'none'}; refusing ${slotId}`);
  if (evidence.limits.used_slots.includes(slot.id)) throw new Error(`slot ${slot.id} was already debited`);
  if (stage === 'second') {
    const first = verifyControlEvidenceData(evidence, freeze, rawDir, 'first', freezeHash);
    if (!first.ok) throw new Error(`the complete first control bundle is required before second controls: ${first.errors.join('; ')}`);
  }
  const reserve = slot.max_duration_ms;
  const pendingCommandCount = freeze.ledger.slots.length - evidence.attempts.length;
  if (reserve !== 120_000 || evidence.limits.charged_duration_ms + reserve + 9 * 240_000 > freeze.ledger.shared_cap_ms) throw new Error('full 120,000 ms command reserve plus all nine D-20 slots does not fit in the shared cap');
  if (evidence.limits.charged_duration_ms + reserve * pendingCommandCount > freeze.ledger.d19.cap_ms) throw new Error('all remaining D-19 command reserves do not fit the frozen 20-minute allocation');
  if (evidence.limits.physical_browser_launches + pendingCommandCount + 9 > freeze.ledger.total_browser_launch_ceiling) throw new Error('remaining D-19 and D-20 launches do not fit the shared launch ceiling');
  const head = validateControlSource(root, freeze, evidenceFile);
  const project = REPLAN_PROJECTS.find((item) => item.name === slot.project);
  if (!project) throw new Error('frozen project mapping is missing');
  if (!(await portAvailable(project.port))) throw new Error(`frozen port ${project.port} is occupied before native setup`);
  const rawAttempt = createAttemptDirectory(rawDir, slot.id, 1);
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-registration-control-'));
  const started = process.hrtime.bigint();
  const deadline = Number(started) / 1e6 + reserve;
  const runId = `${slot.id.toLowerCase()}-${crypto.randomUUID()}`;
  const db = `sigra_253_control_${project.name.replaceAll('-', '_')}_${Date.now().toString(36)}_${process.pid}`.toLowerCase();
  const env = diagnosticEnvironment(project, db, tempRoot);
  const tempPaths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(tempRoot, `${name.replaceAll('_', '-')}.log`)]));
  const reportTemp = path.join(tempRoot, 'playwright-report.json');
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: project.name, argv: slot.argv,
    source_commit: freeze.source.checkout_head, source_blobs: freeze.source.blobs,
    started_monotonic_ns: started.toString(), database: { name: db, setup_exit_code: null, drop_exit_code: null, connection: databaseConnectionIdentity(env) },
    server: { port: project.port, http_status: null, app_pid: null }, browser: { launched: false, exit_code: null },
    observed_outcome: 'setup_failed', files: {}, traces: [], trace_assertion: [], transport_observations: [],
    registration: { server_post_confirmed: false }, toolchain: { playwright: null, ecto_sql: freeze.tools.ecto_sql, phoenix_live_view: freeze.tools.phoenix_live_view },
    log_redactions: {}, build_path: env.MIX_BUILD_PATH
  };
  evidence.status = 'running';
  evidence.reservation = { slot_id: slot.id, stage, reserved_ms: reserve, predebited_at: new Date().toISOString(), source_commit: freeze.source.checkout_head };
  evidence.limits.reserved_ms = reserve;
  evidence.limits.used_slots.push(slot.id);
  writeJson(evidenceFile, evidence);
  let app = null; let terminalError = null; let rawReport = null; let browserArgs = null;
  try {
    const setup = runLogged('mix', ['ecto.setup'], path.join(root, 'test/example'), env, tempPaths.setup_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.log_redactions.setup_log = setup;
    attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0) throw new Error(`fresh control database setup failed with exit ${setup.exit_code ?? 'null'}`);
    const fd = fs.openSync(tempPaths.app_log, 'w');
    try { app = spawn('mix', ['phx.server'], { cwd: path.join(root, 'test/example'), env, stdio: ['ignore', fd, fd], detached: true }); }
    finally { fs.closeSync(fd); }
    const ready = app.pid ? await waitReady(app, `http://127.0.0.1:${project.port}/`, deadline) : null;
    attempt.server.http_status = ready;
    attempt.server.app_pid = app.pid ?? null;
    if (ready !== 200) throw new Error(`fresh control app did not return HTTP 200 before the frozen slot expired`);
    const playwrightDir = path.join(root, 'test/example/priv/playwright');
    const installedVersion = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installedVersion !== freeze.tools.playwright_required) throw new Error(`installed Playwright ${installedVersion} differs from the frozen ${freeze.tools.playwright_required}`);
    attempt.toolchain.playwright = installedVersion;
    if (Number(process.hrtime.bigint()) / 1e6 >= deadline) throw new Error('the 120,000 ms slot expired before browser launch');
    attempt.browser.launched = true;
    browserArgs = ['test', slot.selection?.spec ?? freeze.selection.spec, ...slot.argv, `--output=${path.join(tempRoot, 'playwright-output')}`];
    const browser = runLogged(path.join(playwrightDir, 'node_modules/.bin/playwright'), browserArgs, playwrightDir, {
      ...env, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${project.port}`,
      SIGRA_PLAYWRIGHT_JSON: reportTemp, SIGRA_REGISTRATION_CONTROL_STAGE: stage,
      SIGRA_CONTROL_RUN_ID: runId, SIGRA_CONTROL_ACCOUNT_PREFIX: 'platform-admin+sigra-253-control',
      PLAYWRIGHT_HTML_OUTPUT_DIR: path.join(tempRoot, 'html-report')
    }, tempPaths.test_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.log_redactions.test_log = browser;
    attempt.browser.exit_code = browser.exit_code;
    if (!fs.existsSync(reportTemp) || fs.statSync(reportTemp).size === 0) throw new Error('native Playwright JSON report is absent or empty');
    rawReport = readJson(reportTemp);
    const nativeTests = playReportTests(rawReport);
    const traces = [];
    for (const item of nativeTests) {
      for (const attachment of item.attachments ?? []) {
        if (attachment.name !== 'trace' && !String(attachment.path ?? '').endsWith('trace.zip')) continue;
        if (!attachment.path || !fs.existsSync(attachment.path)) throw new Error(`native trace attachment for ${item.title} is missing`);
        const target = path.join(rawAttempt, `trace-${traces.length + 1}.zip`);
        const traceSanitization = sanitizeTraceFile(attachment.path, target);
        const ref = receiptFile(rawDir, 'sanitized Playwright trace', target);
        traces.push({ ...ref, title: item.title, sanitization: traceSanitization });
        attachment.path = path.relative(root, target);
      }
    }
    attempt.files.traces = traces;
    attempt.traces = traces;
    const reportSafe = sanitizeReportText(rawReport);
    const reportPath = path.join(rawAttempt, 'playwright-report.json');
    fs.writeFileSync(reportPath, `${JSON.stringify(reportSafe, null, 2)}\n`, { flag: 'wx' });
    attempt.files.playwright_report = receiptFile(rawDir, 'sanitized Playwright report', reportPath);
    const appTextBeforeSanitize = fs.existsSync(tempPaths.app_log) ? fs.readFileSync(tempPaths.app_log, 'utf8') : '';
    attempt.registration.server_post_confirmed = /POST \/users\/log_in/.test(appTextBeforeSanitize);
    attempt.transport_observations = nativeTests.map((item) => ({
      title: item.title,
      context_ids: controlAnnotations(item, 'sigra-registration-control-context'),
      result: controlAnnotations(item, 'sigra-registration-control-result').map((value) => { try { return JSON.parse(value); } catch { return { malformed: true }; } })
    }));
    attempt.trace_assertion = traces.map((trace) => ({ title: trace.title, sha256: trace.sha256, bytes: trace.bytes, navigation: trace.sanitization.navigation, submission: trace.sanitization.submission }));
    attempt.native_selection = { project: project.name, spec: freeze.selection.spec, selected_titles: slot.selected_titles, expected_cli_exit: slot.selected_titles.some((title) => slot.expected[title] === 'expected_failure') ? 1 : 0 };
    attempt.browser_command_argv = browserArgs;
    attempt.native_exit_status = browser.exit_code;
    attempt.observed_outcome = 'native_report_pending_validation';
  } catch (error) {
    terminalError = error.message;
  } finally {
    await stopApp(app);
    if (fs.existsSync(tempPaths.app_log)) attempt.log_redactions.app_log = sanitizeCommandLog(tempPaths.app_log);
    const drop = runLogged('mix', ['ecto.drop', '--quiet'], path.join(root, 'test/example'), env, tempPaths.drop_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.log_redactions.drop_log = drop;
    attempt.database.drop_exit_code = drop.exit_code;
    if (drop.exit_code !== 0) terminalError = [terminalError, `database drop failed with exit ${drop.exit_code ?? 'null'}`].filter(Boolean).join('; ');
    else {
      const absenceLog = path.join(tempRoot, 'database-absence.log');
      try { attempt.database.absence_receipt = captureOwnedDatabaseAbsence({ database: db, env, cwd: path.join(root, 'test/example'), log: absenceLog, deadline }); }
      catch (error) { terminalError = [terminalError, `independent database absence query failed: ${error.message}`].filter(Boolean).join('; '); }
    }
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  const absenceTemp = path.join(tempRoot, 'database-absence.log');
  if (fs.existsSync(absenceTemp)) {
    const target = path.join(rawAttempt, 'database-absence.log');
    fs.copyFileSync(absenceTemp, target, fs.constants.COPYFILE_EXCL);
    attempt.files.database_absence = receiptFile(rawDir, 'owned database absence query log', target);
  }
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    const source = tempPaths[name];
    if (!fs.existsSync(source)) fs.writeFileSync(source, `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    attempt.log_redactions[name] ??= sanitizeCommandLog(source);
    const target = path.join(rawAttempt, `${name.replaceAll('_', '-')}.log`);
    fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL);
    attempt.files[name] = receiptFile(rawDir, `sanitized ${name}`, target);
  }
  if (!attempt.files.playwright_report && fs.existsSync(reportTemp) && fs.statSync(reportTemp).size > 0) {
    const reportPath = path.join(rawAttempt, 'playwright-report.json');
    const safe = sanitizeReportText(readJson(reportTemp));
    fs.writeFileSync(reportPath, `${JSON.stringify(safe, null, 2)}\n`, { flag: 'wx' });
    attempt.files.playwright_report = receiptFile(rawDir, 'sanitized Playwright report', reportPath);
  }
  attempt.ended_monotonic_ns = process.hrtime.bigint().toString();
  attempt.execution_duration_ms = Math.ceil(Number(BigInt(attempt.ended_monotonic_ns) - BigInt(attempt.started_monotonic_ns)) / 1e6);
  attempt.charged_duration_ms = attempt.execution_duration_ms;
  attempt.terminal_diagnostic = terminalError;
  const nativeValidation = verifyNativeControlAttempt(attempt, freeze, rawDir);
  if (!nativeValidation.ok) terminalError = [terminalError, ...nativeValidation.errors].filter(Boolean).join('; ');
  if (attempt.charged_duration_ms > reserve) terminalError = [terminalError, 'native command exceeded its frozen 120,000 ms slot'].filter(Boolean).join('; ');
  if (attempt.browser.launched && attempt.toolchain.playwright !== '1.59.1') terminalError = [terminalError, 'native browser did not use lockfile Playwright 1.59.1'].filter(Boolean).join('; ');
  evidence.reservation = null;
  evidence.limits.reserved_ms = 0;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  if (attempt.browser.launched) evidence.limits.physical_browser_launches += 1;
  evidence.attempts.push(attempt);
  if (!terminalError) {
    const stageAttempts = evidence.attempts.filter((item) => item.stage === stage).length;
    evidence.status = stage === 'first' && stageAttempts === 3 ? 'first_complete'
      : stage === 'second' && evidence.attempts.length === 6 ? 'complete' : 'running';
    attempt.observed_outcome = attempt.browser.exit_code === 0 ? 'native_pass' : 'expected_control_assertions_observed';
  } else {
    evidence.status = 'halted';
    evidence.stop_reason = terminalError;
    attempt.observed_outcome = 'halted';
  }
  writeJson(evidenceFile, evidence);
  fs.rmSync(tempRoot, { recursive: true, force: true });
  if (!terminalError) {
    const verificationStage = evidence.status === 'first_complete' ? 'first' : evidence.status === 'complete' ? 'complete' : null;
    if (verificationStage) {
      const result = verifyControlEvidenceData(evidence, freeze, rawDir, verificationStage, freezeHash);
      if (!result.ok) {
        evidence.status = 'halted'; evidence.stop_reason = result.errors.join('; ');
        writeJson(evidenceFile, evidence);
        throw new Error(`native control receipt rejected: ${result.errors.join('; ')}`);
      }
    }
  }
  if (terminalError) throw new Error(terminalError);
  return { status: evidence.status, slot: slot.id, project: project.name, native_exit_status: attempt.browser.exit_code, charged_duration_ms: attempt.charged_duration_ms, physical_browser_launches: evidence.limits.physical_browser_launches };
}

function verifyControlFile(evidenceFile, stage, root = ROOT) {
  try {
    const evidence = readJson(evidenceFile);
    const freezeFile = path.resolve(root, evidence.freeze_path ?? '');
    const freeze = readJson(freezeFile);
    validateControlSource(root, freeze, evidenceFile);
    const result = verifyControlEvidenceData(evidence, freeze, `${evidenceFile}.raw`, stage, fileHash(freezeFile));
    if (!result.ok) console.error(`native control evidence rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`native registration controls verified: ${evidence.attempts.length}/6 commands for stage=${stage}; ${evidence.limits.physical_browser_launches} global launches; ${evidence.limits.charged_duration_ms} ms cumulative; status=${evidence.status}; retry_available=0`);
    return result;
  } catch (error) { console.error(`native control evidence rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

function verifyControlRecoveryFile(evidenceFile, stage, root = ROOT) {
  try {
    if (path.resolve(evidenceFile) !== path.resolve(root, CONTROL_RECOVERY_EVIDENCE_PATH)) throw new Error('verification accepts only the additive Plan 27 native evidence path');
    const evidence = readJson(evidenceFile);
    const freezeFile = path.resolve(root, evidence.freeze_path ?? '');
    if (freezeFile !== path.resolve(root, CONTROL_RECOVERY_FREEZE_PATH)) throw new Error('native evidence does not point to the reviewed recovery freeze');
    const freeze = readJson(freezeFile);
    validateControlRecoveryFreeze(root, freeze);
    const result = verifyControlRecoveryEvidenceData(evidence, freeze, `${evidenceFile}.raw`, stage, fileHash(freezeFile));
    if (!result.ok) console.error(`native control recovery evidence rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`native control recovery verified: ${evidence.attempts.length} new command; ${evidence.limits.physical_playwright_cli_launches}/18 CLI launches; ${evidence.limits.charged_duration_ms} ms cumulative; retry_available=0`);
    return result;
  } catch (error) { console.error(`native control recovery evidence rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

function checkControlRecoveryFreezeFile(freezeFile, root = ROOT) {
  try {
    if (path.resolve(freezeFile) !== path.resolve(root, CONTROL_RECOVERY_FREEZE_PATH)) throw new Error('freeze check accepts only the additive Plan 27 path');
    validateControlRecoveryFreeze(root, readJson(freezeFile));
    console.log('native control recovery freeze verified: source, historical bytes, five unused mappings, carried charges and retry count match');
    return { ok: true, errors: [] };
  } catch (error) {
    console.error(`native control recovery freeze rejected: ${error.message}`);
    return { ok: false, errors: [error.message] };
  }
}

export function attemptDirectory(baseDir, slotId, attemptNumber) {
  return path.join(baseDir, `${slotId}-attempt-${String(attemptNumber).padStart(2, '0')}`);
}

export function createAttemptDirectory(baseDir, slotId, attemptNumber = 1) {
  if (!/^[A-Z0-9-]+$/.test(slotId) || !Number.isInteger(attemptNumber) || attemptNumber < 1) throw new Error('invalid frozen attempt directory identity');
  const directory = path.join(baseDir, slotId, `attempt-${String(attemptNumber).padStart(2, '0')}`);
  if (fs.existsSync(directory)) throw new Error(`refusing to overwrite an existing native attempt directory: ${directory}`);
  fs.mkdirSync(directory, { recursive: true });
  return directory;
}

// ---- Phase 253 plan 59 (D-19/D-24): per-test diagnostics preservation and verification ----
// Additive helpers for the R3 native path. They are deliberately not called from the v1 or R2
// runners: the JSONL (written by the fsync-per-test reporter named in
// SIGRA_PLAYWRIGHT_FAILURE_JSONL) and every Playwright error-context.md live under a temp tree
// that the runner removes, so they must be copied, sanitized and hashed first.
export const PER_TEST_JSONL_SCHEMA = 'sigra.phase253.playwright-test-end/v1';

function sanitizeText(text) {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-sanitize-'));
  try {
    const file = path.join(scratch, 'text');
    fs.writeFileSync(file, text);
    sanitizeCommandLog(file);
    return fs.readFileSync(file, 'utf8');
  } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
}

function parsePerTestJsonl(text) {
  const rows = []; const malformed = [];
  let truncatedTail = false;
  const segments = text.split('\n');
  const unterminated = segments.length ? segments[segments.length - 1] : '';
  segments.forEach((segment, index) => {
    if (!segment.trim()) return;
    try {
      const row = JSON.parse(segment);
      if (!row || typeof row !== 'object' || row.schema !== PER_TEST_JSONL_SCHEMA) throw new Error('schema');
      rows.push(row);
    } catch {
      if (index === segments.length - 1 && unterminated === segment) truncatedTail = true;
      else malformed.push(index + 1);
    }
  });
  return { rows, malformed, truncatedTail };
}

function findErrorContexts(dir) {
  const found = [];
  if (!fs.existsSync(dir)) return found;
  const visit = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) visit(full);
      else if (entry.isFile() && entry.name === 'error-context.md') found.push(full);
    }
  };
  visit(dir);
  return found;
}

export function preserveAttemptDiagnostics({ outputDir, jsonlPath, rawAttempt, rawDir }) {
  const diagnosticsDir = path.join(rawAttempt, 'diagnostics');
  // Non-recursive create: an existing diagnostics directory means a prior attempt, and is never overwritten.
  fs.mkdirSync(rawAttempt, { recursive: true });
  fs.mkdirSync(diagnosticsDir);
  const result = { jsonl: null, error_contexts: [], per_test: [], truncated_tail: false };

  if (jsonlPath && fs.existsSync(jsonlPath) && fs.statSync(jsonlPath).isFile()) {
    const raw = fs.readFileSync(jsonlPath, 'utf8');
    const parsed = parsePerTestJsonl(raw);
    // Sanitize both the raw bytes and each decoded message: a JSON-escaped secret field is not
    // visible to the line-oriented sanitizer until the message is decoded.
    const lines = raw.split('\n').map((segment) => {
      if (!segment.trim()) return segment;
      try {
        const row = JSON.parse(segment);
        for (const error of row.errors ?? []) if (typeof error?.message === 'string') error.message = sanitizeText(error.message);
        return JSON.stringify(row);
      } catch { return sanitizeText(segment); }
    });
    const destination = path.join(diagnosticsDir, 'tests.jsonl');
    fs.writeFileSync(destination, lines.join('\n'), { flag: 'wx' });
    sanitizeCommandLog(destination);
    result.jsonl = receiptFile(rawDir, 'per-test JSONL', destination);
    result.per_test = parsed.rows.map((row) => ({ project: row.project, title: row.title, status: row.status, ok: row.ok, errors: (row.errors ?? []).length }));
    result.truncated_tail = parsed.truncatedTail;
  }

  findErrorContexts(outputDir ?? '').forEach((source, index) => {
    const destination = path.join(diagnosticsDir, `error-context-${String(index + 1).padStart(2, '0')}.md`);
    fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL);
    sanitizeCommandLog(destination);
    result.error_contexts.push(receiptFile(rawDir, 'error-context', destination));
  });
  return result;
}

export function verifyAttemptDiagnosticsR3(attempt, baseDir) {
  const errors = [];
  const launched = attempt?.playwright_cli?.launched === true;
  const diagnostics = attempt?.diagnostics;
  const check = (reference, label) => {
    const file = confinedFile(baseDir, reference);
    if (!file || !fs.existsSync(file) || !fs.statSync(file).isFile()) { errors.push(`${label} receipt is missing or escapes the raw directory`); return null; }
    const bytes = fs.readFileSync(file);
    if (reference.sha256 !== crypto.createHash('sha256').update(bytes).digest('hex') || reference.bytes !== bytes.length) { errors.push(`${label} sha256 does not match its preserved file`); return null; }
    return bytes.toString('utf8');
  };
  if (launched && !diagnostics?.jsonl) errors.push('a launched Playwright CLI attempt carries no per-test JSONL receipt');
  if (diagnostics?.jsonl) {
    const text = check(diagnostics.jsonl, 'per-test JSONL');
    if (text !== null) {
      const parsed = parsePerTestJsonl(text);
      if (parsed.malformed.length) errors.push(`per-test JSONL has malformed line(s): ${parsed.malformed.join(',')}`);
      if (parsed.truncatedTail && diagnostics.truncated_tail !== true) errors.push('per-test JSONL has an unrecorded malformed final line');
    }
  }
  for (const [index, reference] of (diagnostics?.error_contexts ?? []).entries()) check(reference, `error-context ${index + 1}`);
  return { ok: errors.length === 0, errors };
}

export function diagnosticEnvironment(project, databaseName, attemptDir, inheritedEnv = process.env) {
  return {
    ...inheritedEnv, MIX_ENV: 'dev',
    // Never load an endpoint compiled for another attempt's port/database.
    MIX_BUILD_PATH: path.join(fs.realpathSync(attemptDir), 'mix-build'),
    PGHOST: inheritedEnv.PGHOST ?? '127.0.0.1',
    PGPORT: inheritedEnv.PGPORT ?? '58624', PGUSER: inheritedEnv.PGUSER ?? 'postgres',
    PGPASSWORD: inheritedEnv.PGPASSWORD ?? 'postgres', PGDATABASE: databaseName,
    PORT: String(project.port), SIGRA_EXAMPLE_BIND: '127.0.0.1'
  };
}

async function executeOne(freeze, freezeHash, evidence, evidenceFile, root) {
  const used = new Set(evidence.attempts.map((attempt) => attempt.slot_id));
  const slot = freeze.ledger.slots.find((item) => item.kind === 'diagnostic' && item.id.startsWith('D19-DIAG-') && !used.has(item.id));
  if (!slot) throw new Error('no unused Plan 09 diagnostic slot remains');
  const charged = evidence.attempts.reduce((sum, item) => sum + item.charged_duration_ms, 0);
  const d19Charged = evidence.attempts.filter((item) => item.stage === 'D19').reduce((sum, item) => sum + item.charged_duration_ms, 0);
  if (evidence.limits.browser_launches >= freeze.ledger.max_launches) throw new Error('shared launch ceiling reached before launch');
  if (charged + slot.max_duration_ms > freeze.ledger.max_charged_duration_ms) throw new Error('shared time reserve cannot fit this slot');
  if (d19Charged + slot.max_duration_ms > freeze.ledger.d19.max_charged_duration_ms) throw new Error('D-19 time reserve cannot fit this slot');
  checkFrozenSource(root, freeze);

  const project = PROJECTS.find((item) => item.name === slot.project);
  const prelaunchSetupMs = slot.sequence === 1 ? freeze.ledger.prelaunch_setup.duration_ms : 0;
  if (prelaunchSetupMs >= slot.max_duration_ms) throw new Error('prelaunch dependency restore consumed the entire first diagnostic slot');
  const baseDir = `${evidenceFile}.raw`;
  const attemptDir = attemptDirectory(baseDir, slot.id, evidence.attempts.length + 1);
  fs.mkdirSync(attemptDir, { recursive: false });
  const startNs = process.hrtime.bigint().toString();
  const startMs = Number(process.hrtime.bigint()) / 1e6;
  const deadline = startMs + slot.max_duration_ms - prelaunchSetupMs;
  const stamp = Date.now().toString(36);
  const databaseName = `sigra_253_recovery_${project.name.replaceAll('-', '_')}_${stamp}_${process.pid}`.toLowerCase();
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: project.name,
    source_commit: freeze.source.checkout_head, started_monotonic_ns: startNs, prelaunch_setup_ms: prelaunchSetupMs,
    server: { port: project.port, http_status: null },
    database: { name: databaseName, setup_exit_code: null, drop_exit_code: null },
    browser: { launched: false, exit_code: null },
    observed_outcome: 'setup_failed', files: {}, toolchain: { ...freeze.source.host_dependency_versions, playwright_version: freeze.tools.playwright_cli_version_required, ecto_sql_version: freeze.tools.ecto_sql, phoenix_live_view_version: freeze.tools.phoenix_live_view }
  };
  const paths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log', 'playwright_report'].map((name) => [name, path.join(attemptDir, `${name.replaceAll('_', '-')}${name === 'playwright_report' ? '.json' : '.log'}`)]));
  const exampleDir = path.join(root, 'test/example');
  const playwrightDir = path.join(exampleDir, 'priv/playwright');
  const appEnv = diagnosticEnvironment(project, databaseName, attemptDir);
  let app = null;
  let terminalError = null;
  let reportPath = null;
  let traceFiles = [];
  try {
    if (!(await portAvailable(project.port))) throw new Error(`port ${project.port} is occupied before ${project.name} setup`);
    if (Number(process.hrtime.bigint()) / 1e6 >= deadline) throw new Error('slot budget expired before database setup');
    const setup = runLogged('mix', ['ecto.setup'], exampleDir, appEnv, paths.setup_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0) throw new Error(`database setup failed with exit ${setup.exit_code ?? 'null'}${setup.error ? `: ${setup.error}` : ''}`);
    const appFd = fs.openSync(paths.app_log, 'w');
    try {
      app = spawn('mix', ['phx.server'], { cwd: exampleDir, env: appEnv, stdio: ['ignore', appFd, appFd], detached: true });
    } finally { fs.closeSync(appFd); }
    const ready = app.pid ? await waitReady(app, `http://127.0.0.1:${project.port}/`, deadline) : null;
    attempt.server.http_status = ready;
    attempt.server.app_pid = app.pid ?? null;
    if (ready !== 200) throw new Error(`application did not return HTTP 200 before the ${project.name} slot expired`);
    if (freeze.tools.playwright_cli_version_required !== '1.59.1') throw new Error('freeze does not require the approved Playwright version');
    const installedVersion = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installedVersion !== '1.59.1') throw new Error(`installed Playwright version ${installedVersion} does not match frozen 1.59.1`);
    if (Number(process.hrtime.bigint()) / 1e6 >= deadline) throw new Error('slot budget expired before browser launch');
    reportPath = paths.playwright_report;
    attempt.browser.launched = true;
    const browser = runLogged(path.join(playwrightDir, 'node_modules/.bin/playwright'), [
      'test', freeze.selection.spec, `--project=${project.name}`, `--grep=${freeze.selection.test_title}`,
      '--retries=0', '--workers=1', '--trace=retain-on-failure', `--output=${path.join(attemptDir, 'playwright-output')}`
    ], playwrightDir, {
      ...appEnv, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${project.port}`,
      SIGRA_PLAYWRIGHT_JSON: reportPath
    }, paths.test_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.browser.exit_code = browser.exit_code;
    if (browser.exit_code === 0) attempt.observed_outcome = 'passed';
    else attempt.observed_outcome = 'failed';
    const outDir = path.join(attemptDir, 'playwright-output');
    if (fs.existsSync(outDir)) {
      for (const name of fs.readdirSync(outDir, { recursive: true })) {
        if (String(name).endsWith('trace.zip')) {
          const source = path.join(outDir, String(name));
          const target = path.join(attemptDir, `trace-${traceFiles.length + 1}.zip`);
          fs.copyFileSync(source, target);
          traceFiles.push(target);
        }
      }
    }
  } catch (error) {
    terminalError = error.message;
  } finally {
    await stopApp(app);
    const drop = runLogged('mix', ['ecto.drop', '--quiet'], exampleDir, appEnv, paths.drop_log,
      Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.database.drop_exit_code = drop.exit_code;
    if (drop.exit_code !== 0) terminalError = [terminalError, `database drop failed with exit ${drop.exit_code ?? 'null'}${drop.error ? `: ${drop.error}` : ''}`].filter(Boolean).join('; ');
    // Compiled dependencies are temporary work, not retained phase evidence.
    try {
      fs.rmSync(appEnv.MIX_BUILD_PATH, { recursive: true, force: true });
      attempt.build_directory_removed = !fs.existsSync(appEnv.MIX_BUILD_PATH);
    } catch (error) {
      attempt.build_directory_removed = false;
      terminalError = [terminalError, `temporary Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; ');
    }
  }
  if (!fs.existsSync(paths.setup_log)) fs.writeFileSync(paths.setup_log, 'database setup was not started\n');
  if (!fs.existsSync(paths.app_log)) fs.writeFileSync(paths.app_log, 'application process was not started\n');
  if (!fs.existsSync(paths.test_log)) fs.writeFileSync(paths.test_log, `browser command was not started${terminalError ? `: ${terminalError}` : ''}\n`);
  if (!fs.existsSync(paths.drop_log)) fs.writeFileSync(paths.drop_log, 'database drop command was not started\n');
  for (const [name, file] of Object.entries({ setup: paths.setup_log, app: paths.app_log, test: paths.test_log, drop: paths.drop_log })) {
    if (fs.statSync(file).size === 0) fs.writeFileSync(file, `${name} command did not produce output${terminalError ? `: ${terminalError}` : ''}\n`);
  }
  attempt.files.setup_log = referenceFor(baseDir, paths.setup_log);
  attempt.files.app_log = referenceFor(baseDir, paths.app_log);
  attempt.files.test_log = referenceFor(baseDir, paths.test_log);
  attempt.files.drop_log = referenceFor(baseDir, paths.drop_log);
  attempt.files.playwright_report = reportPath ? referenceFor(baseDir, reportPath) : null;
  attempt.files.traces = traceFiles.map((file) => referenceFor(baseDir, file)).filter(Boolean);
  attempt.ended_monotonic_ns = process.hrtime.bigint().toString();
  attempt.execution_duration_ms = Math.ceil((Number(attempt.ended_monotonic_ns) - Number(attempt.started_monotonic_ns)) / 1e6);
  attempt.charged_duration_ms = attempt.execution_duration_ms + prelaunchSetupMs;
  attempt.terminal_diagnostic = terminalError;
  evidence.attempts.push(attempt);
  evidence.limits.browser_launches += attempt.browser.launched ? 1 : 0;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  evidence.limits.d19_charged_duration_ms += attempt.stage === 'D19' ? attempt.charged_duration_ms : 0;
  if (attempt.charged_duration_ms > slot.max_duration_ms) terminalError = [terminalError, 'slot duration ceiling exceeded'].filter(Boolean).join('; ');
  if (terminalError) {
    evidence.status = 'halted';
    evidence.stop_reason = terminalError;
  } else if (evidence.attempts.length === freeze.selection.projects.length) {
    evidence.status = evidence.attempts.every((item) => item.browser.exit_code === 0) ? 'not_reproduced' : 'diagnosis_incomplete';
    evidence.stop_reason = evidence.status === 'not_reproduced' ? null : 'A selected browser test failed; deterministic diagnosis stops without retry.';
    evidence.diagnosis = { cause: 'unknown', claim: 'The current bounded source run does not explain the retained historical registration failure.' };
  }
  writeJson(evidenceFile, evidence);
  const validation = verifyDiagnosticData(evidence, { ...freeze, freeze_sha256: freezeHash }, baseDir);
  if (!validation.ok) {
    evidence.status = 'halted';
    evidence.stop_reason = `native receipt verification failed: ${validation.errors.join('; ')}`;
    writeJson(evidenceFile, evidence);
    throw new Error(evidence.stop_reason);
  }
  if (terminalError) throw new Error(terminalError);
  return attempt;
}

async function runRecovery(freezeFile, evidenceFile, root = ROOT) {
  const freeze = readJson(freezeFile);
  if (freeze.schema_version !== FREEZE_SCHEMA || freeze.status !== 'frozen_before_results') throw new Error('recovery freeze is missing or not frozen before results');
  checkFrozenSource(root, freeze);
  const freezeBytes = fs.readFileSync(freezeFile);
  const freezeHash = sha256(freezeBytes);
  if (freeze.freeze_sha256 !== sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))))) {
    throw new Error('recovery freeze content digest is invalid');
  }
  let evidence;
  const baseDir = `${evidenceFile}.raw`;
  if (fs.existsSync(evidenceFile)) {
    evidence = readJson(evidenceFile);
    if (evidence.status !== 'running') throw new Error(`refusing to continue terminal evidence: ${evidence.status}`);
    if (evidence.freeze_sha256 !== freezeHash) {
      if (evidence.attempts?.length !== 0 || evidence.limits?.browser_launches !== 0 || evidence.limits?.charged_duration_ms !== 0) throw new Error('only an untouched zero-launch start ledger may be rebound to the corrected freeze');
      evidence.prior_zero_launch_starts ??= [];
      evidence.prior_zero_launch_starts.push({
        freeze_path: evidence.freeze_path, freeze_sha256: evidence.freeze_sha256,
        source_commit: evidence.source?.checkout_head,
        preservation_commit: evidence.prior_zero_launch_starts.length === 0 ? '6079a15aa' : 'e813c4223'
      });
      evidence.preflight_failures = freeze.ledger.prelaunch_setup.components
        .filter((component) => component.purpose.startsWith('runner '))
        .map((component) => ({ path: component.path, sha256: component.sha256, charged_duration_ms: component.duration_ms, browser_launches: 0 }));
      evidence.freeze_path = path.relative(root, freezeFile);
      evidence.freeze_sha256 = freezeHash;
      evidence.source = { checkout_head: freeze.source.checkout_head, blobs: freeze.source.blobs };
      evidence.limits.max_launches = freeze.ledger.max_launches;
      evidence.limits.max_charged_duration_ms = freeze.ledger.max_charged_duration_ms;
    }
    const validation = verifyDiagnosticData(evidence, { ...freeze, freeze_sha256: freezeHash }, baseDir);
    if (!validation.ok) throw new Error(`existing evidence failed native validation: ${validation.errors.join('; ')}`);
  } else {
    fs.mkdirSync(baseDir, { recursive: true });
    evidence = {
      schema_version: SCHEMA, status: 'running', freeze_path: path.relative(root, freezeFile), freeze_sha256: freezeHash,
      source: { checkout_head: freeze.source.checkout_head, blobs: freeze.source.blobs },
      historical: { original_evidence_sha256: freeze.historical.original_evidence_sha256, preceding_order: 'unknown', order_reason: freeze.historical.preceding_order_reason },
      started_at: new Date().toISOString(), attempts: [],
      limits: { browser_launches: 0, charged_duration_ms: 0, d19_charged_duration_ms: 0, retry_count: 0, max_launches: freeze.ledger.max_launches, max_charged_duration_ms: freeze.ledger.max_charged_duration_ms }
    };
    writeJson(evidenceFile, evidence);
  }
  const attempt = await executeOne(freeze, freezeHash, evidence, evidenceFile, root);
  return { status: evidence.status, project: attempt.project, outcome: attempt.observed_outcome, launched: attempt.browser.launched, charged_duration_ms: attempt.charged_duration_ms };
}

function verifyDiagnosticFile(evidenceFile, root = ROOT) {
  const evidence = readJson(evidenceFile);
  if (evidence?.schema_version !== SCHEMA || typeof evidence.freeze_path !== 'string' || !evidence.freeze_path) {
    const result = { ok: false, errors: ['native receipts are missing or use an unsupported evidence schema'] };
    console.error(`native diagnostic receipt rejected: ${result.errors[0]}`);
    return result;
  }
  const freezeFile = path.resolve(root, evidence.freeze_path ?? '');
  const freeze = readJson(freezeFile);
  const freezeHash = sha256(fs.readFileSync(freezeFile));
  const internalFreezeHash = sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))));
  if (freeze.freeze_sha256 !== internalFreezeHash) {
    const result = { ok: false, errors: ['recovery freeze internal digest is invalid'] };
    console.error(`native diagnostic receipt rejected: ${result.errors[0]}`);
    return result;
  }
  try {
    checkFrozenSource(root, freeze);
    const oldFreeze = path.join(root, PHASE_DIR, '253-REPRO-FREEZE.json');
    const oldEvidence = path.join(root, PHASE_DIR, '253-REGISTRATION-EVIDENCE.json');
    const setupReceipt = path.join(root, freeze.historical.startup_receipt_path);
    const supersededFreezes = freeze.superseded_unlaunched_freezes;
    if (fileHash(oldFreeze) !== freeze.historical.original_freeze_sha256) throw new Error('original registration freeze bytes changed');
    if (fileHash(oldEvidence) !== freeze.historical.original_evidence_sha256) throw new Error('original registration evidence bytes changed');
    if (!freeze.historical.startup_receipt_sha256 || fileHash(setupReceipt) !== freeze.historical.startup_receipt_sha256) throw new Error('previous setup receipt bytes changed or were not frozen');
    for (const component of freeze.ledger.prelaunch_setup.components) {
      if (fileHash(path.resolve(root, component.path)) !== component.sha256) throw new Error(`prelaunch receipt bytes changed: ${component.path}`);
    }
    for (const superseded of supersededFreezes) {
      const supersededFreeze = path.join(root, superseded.path);
      if (fileHash(supersededFreeze) !== superseded.sha256) throw new Error(`superseded unlaunched freeze bytes changed: ${superseded.path}`);
      if (run('git', ['-C', root, 'merge-base', '--is-ancestor', superseded.commit, git(['-C', root, 'rev-parse', 'HEAD'])]).status !== 0) throw new Error(`superseded freeze preservation commit is not in history: ${superseded.commit}`);
    }
  } catch (error) {
    const result = { ok: false, errors: [error.message] };
    console.error(`native diagnostic receipt rejected: ${error.message}`);
    return result;
  }
  const result = verifyDiagnosticData(evidence, { ...freeze, freeze_sha256: freezeHash }, `${evidenceFile}.raw`);
  if (result.ok) console.log(`native diagnostic receipts verified: ${evidence.attempts.length}/${freeze.selection.projects.length} initial projects; ${evidence.limits.browser_launches} browser launches; ${evidence.limits.charged_duration_ms}ms charged; status=${evidence.status}`);
  else console.error(`native diagnostic receipt rejected:\n- ${result.errors.join('\n- ')}`);
  return result;
}

// ---- Phase 253 plan 39: four-slot load-recovery runner (additive; legacy modes untouched) ----
const LOAD_RECOVERY_SCHEMA = 'sigra.phase253.registration-load-recovery-evidence/v1';
const LOAD_RECOVERY_FREEZE_SCHEMA = 'sigra.phase253.registration-load-recovery-freeze/v1';
const LOAD_RECOVERY_FREEZE_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-NATIVE-FREEZE.json`;
const LOAD_RECOVERY_EVIDENCE_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-NATIVE-EVIDENCE.json`;
const LOAD_RECOVERY_CONFIG = 'test/example/priv/playwright/playwright.registration-recovery.config.ts';
const LOAD_PLAYWRIGHT_DIR = 'test/example/priv/playwright';
const LOAD_SPENT = ['D19-DIAG-01', 'R-DIAG-DESKTOP', 'R-INFRA-RETRY-DESKTOP', 'R-DIAG-MOBILE', 'R-DIAG-CONTROL-DARK', 'CR-DARK-FIRST'];
const LOAD_CHARGES = [3768, 3743, 26373, 46803, 40993, 121252, 112, 33409];
const LOAD_NODE = 'v20.18.1';
const LOAD_DROP_FLOOR_MS = 5000;
const LOAD_ABSENCE_FLOOR_MS = 5000;
const LOAD_FAILED27 = {
  freeze: { file: `${PHASE_DIR}/253-CONTROL-RECOVERY-NATIVE-FREEZE.json`, sha256: 'bef539ef0803a5e035266fd2d5334b02dc87893c285114e7f70cbec3b46a0778' },
  evidence: { file: `${PHASE_DIR}/253-CONTROL-RECOVERY-NATIVE-EVIDENCE.json`, sha256: 'e9982fd5a787777cc00defacd3b88ac41edfee21e08df5e62234e6dfe2319ab0' }
};
const LOAD_EXTRA_HISTORY = [
  `${PHASE_DIR}/253-CONTROL-RECOVERY-LOAD-FAILURE-DIAGNOSTIC.json`,
  `${PHASE_DIR}/253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json`,
  `${PHASE_DIR}/253-REPLAN-REGISTRATION-CONTROL-FREEZE.json`
];
const LOAD_EXTRA_SOURCES = [
  'test/example/priv/playwright/helpers/registrationControls.mjs',
  'test/example/priv/playwright/lib/eval/canonicalize.ts',
  'test/example/priv/playwright/lib/eval/canonicalize.test.ts',
  'test/example/priv/playwright/lib/eval/bundle.ts',
  'scripts/ci/ci-playwright-load.test.mjs',
  'scripts/ci/fixtures/registration-native-tree.mjs',
  LOAD_RECOVERY_CONFIG
];
const LOAD_IMPORT_ENTRIES = ['test/example/priv/playwright/tests/admin-eval.spec.ts', LOAD_RECOVERY_CONFIG];
const LOAD_RUNTIME_PACKAGES = ['@playwright/test', 'playwright', 'playwright-core', 'parse5'];
const LOAD_TRANSFORM_FILES = ['lib/transform/transform.js', 'lib/common/testLoader.js', 'lib/common/configLoader.js'];
const LOAD_SLOT_TABLE = [
  ['CR-DESKTOP-MOBILE-FIRST', 'R-CONTROL-FIRST-MOBILE', ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'], 'first'],
  ['CR-DESKTOP-SECOND', 'R-CONTROL-SECOND-DESKTOP', ['admin-eval'], 'second'],
  ['CR-MOBILE-SECOND', 'R-CONTROL-SECOND-MOBILE', ['admin-eval-mobile'], 'second'],
  ['CR-DARK-SECOND', 'R-CONTROL-SECOND-DARK', ['admin-eval-dark'], 'second']
];
const LOAD_ACCOUNT_PURPOSES = ['held-positive', 'broken-readiness-positive', 'forced-trace-positive', 'collision'];

// Mirrors helpers/registrationControls.mjs registrationControlAccount (equality is a tested contract).
export function loadControlAccount(projectName, purpose) {
  if (!LOAD_ACCOUNT_PURPOSES.includes(purpose)) throw new TypeError(`Unknown registration control account purpose: ${purpose}`);
  const project = String(projectName).replace(/^admin-eval-?/, '').replace(/[^a-z0-9]+/gi, '') || 'desktop';
  return `platform-admin+sigra-253-control-${project.toLowerCase()}-${purpose}@example.test`;
}
const loadAccountDigest = (project, purpose) => sha256(loadControlAccount(project, purpose));

export function loadRecoverySlotDefinitions() {
  return LOAD_SLOT_TABLE.map(([id, maps_from, projects, stage], index) => {
    const titlesFor = (project) => stage === 'first'
      ? (project === 'admin-eval-dark' ? [CONTROL_BOARD_TITLE, ...FIRST_CONTROLS] : [...FIRST_CONTROLS])
      : [...CONTROL_SECOND_ACTIVE];
    const project_selections = projects.map((project) => ({
      project, titles: titlesFor(project),
      expected: Object.fromEntries(titlesFor(project).map((title) => [title, CONTROL_EXPECTED_FAILURE_MARKERS[title] ? 'expected_failure' : 'pass']))
    }));
    const rows = project_selections.reduce((sum, item) => sum + item.titles.length, 0);
    return {
      id, sequence: index + 1, maps_from, stage, projects, project: projects[0],
      port: PROJECTS.find((item) => item.name === projects[0]).port,
      max_duration_ms: PROJECT_SLOT_MS, work_ms: 105_000, cleanup_ms: 15_000,
      launch_unit: 'playwright_cli_process', config: LOAD_RECOVERY_CONFIG,
      argv: [`--config=${path.basename(LOAD_RECOVERY_CONFIG)}`, ...projects.map((project) => `--project=${project}`), '--workers=1', '--retries=0', '--trace=retain-on-failure'],
      control_stage: stage, project_selections, rows,
      expected_cli_exit: stage === 'first' ? 1 : 0,
      collision_account_sha256: Object.fromEntries(projects.map((project) => [project, loadAccountDigest(project, 'collision')]))
    };
  });
}

export function loadRequiredPairs(slot) {
  return slot.project_selections.flatMap((item) => item.titles.map((title) => ({ spec: 'admin-eval.spec.ts', project: item.project, title })));
}

export function buildLoadRecoveryLedger(input) {
  const errors = [];
  if (!Array.isArray(input?.charges) || JSON.stringify(input.charges) !== JSON.stringify(LOAD_CHARGES)) errors.push('historical charges do not match the exact eight carried components');
  if (input?.physicalPlaywrightLaunches !== 5) errors.push('historical Playwright CLI launch count must be exactly five');
  if (JSON.stringify(input?.spentReservations) !== JSON.stringify(LOAD_SPENT)) errors.push('spent reservation inventory must be the six closed identities');
  if (input?.retryUsed !== 1 || input?.retryAvailable !== 0) errors.push('retry must remain used 1, available 0');
  if (input?.preparationMaximumMs !== 116232 || input?.preparationUsedMs !== 3743) errors.push('preparation allowance differs from the preserved measured balance');
  if (errors.length) throw new Error(errors.join('; '));
  const priorCharge = input.charges.reduce((sum, value) => sum + value, 0);
  const slots = loadRecoverySlotDefinitions();
  const preparationRemaining = input.preparationMaximumMs - input.preparationUsedMs;
  const d19Max = priorCharge + preparationRemaining + slots.length * PROJECT_SLOT_MS;
  const totalMax = d19Max + 9 * 240_000 + 3 * 60_000;
  if (priorCharge !== 276453 || preparationRemaining !== 112489 || d19Max !== 868942 || totalMax !== 3208942
    || slots.reduce((sum, slot) => sum + slot.rows, 0) !== 22 || slots[0].rows !== 16 || slots.slice(1).some((slot) => slot.rows !== 2)) {
    throw new Error('load recovery arithmetic or row packing differs from the reviewed finite allocation');
  }
  return {
    prior_charge_ms: priorCharge, prior_playwright_cli_launches: 5, spent_reservations: [...LOAD_SPENT],
    retry_used: 1, retry_available: 0, preparation_remaining_ms: preparationRemaining, slots,
    launch_unit: 'playwright_cli_process', engine_worker_lifecycle_accounting: 'separate_from_playwright_cli_launches',
    d19_max_ms: d19Max, conditional_acceptance_slots: 9, conditional_acceptance_ms: 2_160_000, optional_seed_checks_ms: 180_000,
    total_max_ms: totalMax, physical_cli_launch_max: 18, cleanup_reserve_per_command_ms: 15_000, regular_command_ms: PROJECT_SLOT_MS,
    required_rows: 22
  };
}

function loadFreezeDigest(freeze) {
  return sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))));
}

// Static import closure of the runtime entrypoints: relative static/dynamic imports and requires.
export function discoverLoadImportClosure(root, entries = LOAD_IMPORT_ENTRIES) {
  const found = new Set(); const queue = [...entries];
  const pattern = /(?:from\s+|import\s*\(\s*|require\s*\(\s*|import\s+)['"](\.{1,2}\/[^'"]+)['"]/g;
  while (queue.length) {
    const file = queue.shift();
    if (found.has(file)) continue;
    const absolute = path.join(root, file);
    if (!fs.existsSync(absolute)) throw new Error(`import closure source is missing: ${file}`);
    found.add(file);
    const text = fs.readFileSync(absolute, 'utf8');
    for (const match of text.matchAll(pattern)) {
      const base = path.posix.normalize(path.posix.join(path.posix.dirname(file), match[1]));
      const candidate = ['', '.ts', '.mjs', '.js', '.json', '/index.ts'].map((suffix) => base + suffix)
        .find((item) => fs.existsSync(path.join(root, item)) && fs.statSync(path.join(root, item)).isFile());
      if (!candidate) throw new Error(`unresolved relative import ${match[1]} from ${file}`);
      if (!candidate.includes('node_modules/')) queue.push(candidate);
    }
  }
  return [...found].sort();
}

export function loadSourceFileList(root) {
  return [...new Set([...SOURCE_FILES, ...LOAD_EXTRA_SOURCES, ...discoverLoadImportClosure(root)])];
}

function loadRuntimeIdentity(root) {
  const pw = path.join(root, LOAD_PLAYWRIGHT_DIR);
  const lock = readJson(path.join(pw, 'package-lock.json'));
  const packages = {};
  for (const name of LOAD_RUNTIME_PACKAGES) {
    const entry = lock.packages?.[`node_modules/${name}`];
    const installedFile = path.join(pw, 'node_modules', name, 'package.json');
    if (!entry?.integrity || !fs.existsSync(installedFile)) throw new Error(`locked or installed metadata missing for ${name}`);
    const installed = readJson(installedFile);
    if (installed.version !== entry.version) throw new Error(`installed ${name} ${installed.version} differs from locked ${entry.version}`);
    packages[name] = { version: entry.version, integrity: entry.integrity, installed_package_json_sha256: fileHash(installedFile) };
  }
  const transform = Object.fromEntries(LOAD_TRANSFORM_FILES.map((file) => [file, fileHash(path.join(pw, 'node_modules/playwright', file))]));
  if (Object.values(transform).some((value) => !value)) throw new Error('pinned Playwright transform source is missing');
  if (packages['@playwright/test'].version !== '1.59.1' || packages.parse5.version !== '8.0.1') throw new Error('locked Playwright or parse5 version changed');
  return { packages, transform_sha256: transform };
}

function readLoadHistory(root) {
  const control = readControlRecoveryHistory(root);
  const failed27Freeze = readJson(path.join(root, LOAD_FAILED27.freeze.file));
  const failed27 = readJson(path.join(root, LOAD_FAILED27.evidence.file));
  if (fileHash(path.join(root, LOAD_FAILED27.freeze.file)) !== LOAD_FAILED27.freeze.sha256
    || fileHash(path.join(root, LOAD_FAILED27.evidence.file)) !== LOAD_FAILED27.evidence.sha256) throw new Error('failed Plan 27 freeze or evidence bytes changed');
  const attempt = failed27.attempts?.[0];
  if (failed27.status !== 'halted' || failed27.attempts?.length !== 1 || attempt?.slot_id !== 'CR-DARK-FIRST'
    || attempt.charged_duration_ms !== 33409 || attempt.playwright_cli?.launched !== true
    || failed27.limits?.charged_duration_ms !== 276453 || failed27.limits?.physical_playwright_cli_launches !== 5
    || JSON.stringify(failed27.limits?.used_slots) !== JSON.stringify(LOAD_SPENT)
    || failed27.limits?.retry_used !== 1 || failed27.limits?.retry_available !== 0) throw new Error('failed Plan 27 receipt differs from the six-spent, 276453 ms, five-launch ledger');
  const rawDir = `${path.join(root, LOAD_FAILED27.evidence.file)}.raw`;
  for (const [name, reference] of Object.entries(attempt.files ?? {})) {
    for (const item of Array.isArray(reference) ? reference : [reference]) {
      const file = confinedFile(rawDir, item);
      if (!file || fileHash(file) !== item.sha256) throw new Error(`failed Plan 27 raw readback differs: ${name}`);
    }
  }
  for (const revision of failed27.preserved_revisions ?? []) {
    if (sha256(readGitBlob(root, revision.ref)) !== revision.sha256) throw new Error(`failed Plan 27 preserved revision readback differs: ${revision.ref}`);
  }
  const charges = [...control.charges, attempt.charged_duration_ms];
  const ledger = buildLoadRecoveryLedger({
    charges, physicalPlaywrightLaunches: failed27.limits.physical_playwright_cli_launches, spentReservations: failed27.limits.used_slots,
    retryUsed: failed27.limits.retry_used, retryAvailable: failed27.limits.retry_available,
    preparationMaximumMs: 116232, preparationUsedMs: charges[1]
  });
  const historicalFiles = [...control.artifacts.map((item) => item.path), LOAD_FAILED27.freeze.file, LOAD_FAILED27.evidence.file, ...LOAD_EXTRA_HISTORY];
  const artifacts = historicalFiles.map((file) => ({ path: file, sha256: fileHash(path.join(root, file)) }));
  if (artifacts.some((item) => !item.sha256)) throw new Error('a historical record is missing an exact byte identity');
  const frozenBlobs = {
    failed27: failed27Freeze.source.blobs,
    control16: readJson(path.join(root, LOAD_EXTRA_HISTORY[2])).source.blobs
  };
  if (Object.keys(frozenBlobs.control16).length !== 9) throw new Error('original control freeze must retain nine frozen blob hashes');
  for (const set of Object.values(frozenBlobs)) for (const blob of Object.values(set)) {
    if (run('git', ['-C', root, 'cat-file', '-t', blob]).stdout.trim() !== 'blob') throw new Error(`historical frozen blob is not retrievable: ${blob}`);
  }
  return { control, ledger, artifacts, failed27, frozenBlobs, charges };
}

export function createLoadRecoveryFreeze(outputFile, root = ROOT) {
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite the additive native load recovery freeze');
  if (process.version !== LOAD_NODE) throw new Error(`load recovery must be frozen under Node ${LOAD_NODE}`);
  assertRevisionCheckout(root);
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const history = readLoadHistory(root);
  const files = loadSourceFileList(root);
  const blobs = Object.fromEntries(files.map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`])]));
  const control = history.control;
  const freeze = {
    schema_version: LOAD_RECOVERY_FREEZE_SCHEMA, status: 'frozen_before_results', plan: '253-39', frozen_at: new Date().toISOString(),
    source: { repository: 'szTheory/sigra', checkout_head: head, blobs },
    runtime: loadRuntimeIdentity(root),
    historical: {
      artifacts: history.artifacts, frozen_blob_sets: history.frozenBlobs, carried_charge_ms: history.ledger.prior_charge_ms,
      carried_components_ms: history.charges, physical_playwright_cli_launches: 5, spent_reservations: [...LOAD_SPENT],
      spent_retry: { used: 1, available: 0 }, preceding_order: 'unknown', actual_http_old_hosted: 'unknown',
      failed_dark: { slot_id: 'R-DIAG-CONTROL-DARK', charged_ms: 121252 },
      failed_cr_dark_first: { slot_id: 'CR-DARK-FIRST', charged_ms: 33409, selected_results: 0, retry_or_reuse: 'forbidden' }
    },
    ledger: {
      prior_charge_ms: history.ledger.prior_charge_ms, prior_playwright_cli_launches: 5, spent_reservations: [...LOAD_SPENT],
      preparation_remaining_ms: 112489, preparation_maximum_ms: 112489, retry_used: 1, retry_available: 0,
      slots: history.ledger.slots,
      d19: { cap_ms: 1_200_000, max_with_remaining_preparation: 868942 },
      d20: { acceptance_slots_reserved: 9, each_max_duration_ms: 240000, reserved_ms: 2_160_000, retry_available: false },
      shared_cap_ms: 3_480_000, total_with_optional_seed_checks_ms: 3208942, physical_cli_launch_max: 18,
      launch_unit: 'playwright_cli_process', engine_worker_lifecycle_accounting: 'separate_from_playwright_cli_launches',
      cleanup_reserve_ms: 15000, regular_command_ms: PROJECT_SLOT_MS, no_retry: true, required_rows: 22
    },
    selection: {
      spec: 'tests/admin-eval.spec.ts', config: path.basename(LOAD_RECOVERY_CONFIG), original_title: CONTROL_BOARD_TITLE,
      first_titles: FIRST_CONTROLS, second_titles: CONTROL_SECOND_ACTIVE, deliberate_expected_failure_markers: CONTROL_EXPECTED_FAILURE_MARKERS,
      cli_grep_forbidden: true, workers: 1, fully_parallel: false, retries: 0, trace: 'retain-on-failure'
    },
    tools: {
      node: process.version, expected_node: LOAD_NODE, playwright: '1.59.1', parse5: '8.0.1',
      mix: control.accepted.toolchain.mix, ecto_sql: control.accepted.toolchain.ecto_sql, phoenix_live_view: control.accepted.toolchain.phoenix_live_view
    },
    exclusions: ['no browser installation', 'no hidden --list or version CLI', 'no warmup', 'no duplicate full suite', 'no retry', 'no reuse of CR-DARK-FIRST', 'no acceptance command in Plan 39', 'no native or hosted work in Plan 39'],
    stop_conditions: ['source or history digest mismatch', 'unexpected assertion or missing native report', 'database drop/build cleanup/report/trace sanitation failure', 'command exceeds 120000 ms', 'stalled owned process group remains alive']
  };
  freeze.freeze_sha256 = loadFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return freeze;
}

export function validateLoadRecoveryFreeze(root, freeze) {
  assertDirtyConfigPreserved(root);
  if (freeze?.schema_version !== LOAD_RECOVERY_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== loadFreezeDigest(freeze)) throw new Error('native load recovery freeze is malformed or its digest is invalid');
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  if (run('git', ['-C', root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]).status !== 0) throw new Error('frozen load recovery source commit is not an ancestor of this checkout');
  for (const [file, expected] of Object.entries(freeze.source.blobs ?? {})) {
    if (git(['-C', root, 'hash-object', file]) !== expected) throw new Error(`frozen load recovery source identity mismatch for ${file}`);
  }
  for (const required of [...SOURCE_FILES, ...LOAD_EXTRA_SOURCES]) if (!freeze.source.blobs?.[required]) throw new Error(`freeze omits required source ${required}`);
  for (const file of discoverLoadImportClosure(root)) if (!freeze.source.blobs?.[file]) throw new Error(`freeze omits actual imported runtime source ${file}`);
  for (const artifact of freeze.historical?.artifacts ?? []) {
    if (fileHash(path.join(root, artifact.path)) !== artifact.sha256) throw new Error(`preserved native history changed: ${artifact.path}`);
  }
  if (JSON.stringify(freeze.runtime) !== JSON.stringify(loadRuntimeIdentity(root))) throw new Error('locked/installed runtime or pinned transform identity changed');
  const history = readLoadHistory(root);
  const canonical = loadRecoverySlotDefinitions();
  if (JSON.stringify(freeze.ledger?.slots) !== JSON.stringify(canonical) || JSON.stringify(history.ledger.slots) !== JSON.stringify(canonical)) throw new Error('frozen reservation mapping differs from the reviewed four unused slots');
  for (const slot of freeze.ledger.slots) if (slot.argv.some((arg) => /^(-g|--grep)(=|$)/.test(arg))) throw new Error('frozen argv carries a CLI grep that would override per-project selection');
  const l = freeze.ledger;
  if (l.prior_charge_ms !== 276453 || l.prior_playwright_cli_launches !== 5 || l.retry_used !== 1 || l.retry_available !== 0
    || l.d19?.max_with_remaining_preparation !== 868942 || l.total_with_optional_seed_checks_ms !== 3208942
    || l.shared_cap_ms !== 3480000 || l.physical_cli_launch_max !== 18 || JSON.stringify(l.spent_reservations) !== JSON.stringify(LOAD_SPENT)) throw new Error('frozen ledger totals differ from the reviewed allocation');
  return head;
}

function checkLoadRecoveryFreezeFile(freezeFile, root = ROOT) {
  try {
    if (path.resolve(freezeFile) !== path.resolve(root, LOAD_RECOVERY_FREEZE_PATH)) throw new Error('freeze check accepts only the additive Plan 39 path');
    validateLoadRecoveryFreeze(root, readJson(freezeFile));
    console.log('native load recovery freeze verified: source closure, history blobs, runtime identity, four unused slots, 276453 ms/5 launches/6 spent match');
    return { ok: true, errors: [] };
  } catch (error) {
    console.error(`native load recovery freeze rejected: ${error.message}`);
    return { ok: false, errors: [error.message] };
  }
}

export function initializeLoadRecoveryEvidence(freezeFile, evidenceFile, root = ROOT) {
  if (fs.existsSync(evidenceFile)) throw new Error('refusing to overwrite additive native load recovery evidence');
  const freeze = readJson(freezeFile);
  validateLoadRecoveryFreeze(root, freeze);
  const evidence = {
    schema_version: LOAD_RECOVERY_SCHEMA, status: 'ready',
    freeze_path: path.relative(root, freezeFile), freeze_sha256: fileHash(freezeFile),
    source: structuredClone(freeze.source), historical: structuredClone(freeze.historical),
    created_at: new Date().toISOString(), attempts: [], preparation: null, reservation: null, preserved_revisions: [],
    limits: {
      prior_charge_ms: freeze.ledger.prior_charge_ms, preparation_charge_ms: 0, preparation_remaining_ms: freeze.ledger.preparation_remaining_ms,
      charged_duration_ms: freeze.ledger.prior_charge_ms, physical_playwright_cli_launches: freeze.ledger.prior_playwright_cli_launches,
      used_slots: [...freeze.ledger.spent_reservations], max_d19_ms: freeze.ledger.d19.max_with_remaining_preparation,
      max_total_ms: freeze.ledger.shared_cap_ms, max_physical_playwright_cli_launches: freeze.ledger.physical_cli_launch_max,
      retry_used: 1, retry_available: 0
    }
  };
  fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  writeJson(evidenceFile, evidence);
  return evidence;
}

const ACCOUNT_COUNT_SCHEMA = 'sigra.phase253.owned-account-count/v1';
const ACCOUNT_COUNT_QUERY = "SELECT count(*) FROM users WHERE email = :'target';\n";

// Bounded psql count of one synthetic control account in the slot's own owned database.
// The password stays in the environment; the receipt keeps only the account digest.
export function captureOwnedAccountCount({ database, email, env, cwd, log, deadline, run: runner = spawnSync }) {
  if (!OWNED_CONTROL_DATABASE.test(database ?? '')) throw new Error('refusing to query a database outside the synthetic control namespace');
  if (!/^platform-admin\+sigra-253-control-[a-z0-9]+-[a-z-]+@example\.test$/.test(email ?? '')) throw new Error('refusing to query an account outside the synthetic control namespace');
  const connection = databaseConnectionIdentity(env);
  if (!connection.host || !connection.port || !connection.user) throw new Error('account query needs PGHOST, PGPORT and PGUSER');
  const argv = ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-v', `target=${email}`, '-A', '-t', '-h', connection.host, '-p', connection.port, '-U', connection.user, '-d', database];
  const started = process.hrtime.bigint();
  const timeout = Math.max(1, Math.floor(deadline - Number(started) / 1e6));
  let result = null; let thrown = null;
  try { result = runner(argv[0], argv.slice(1), { cwd, env: { ...env, PGDATABASE: database }, input: ACCOUNT_COUNT_QUERY, encoding: 'utf8', timeout, killSignal: 'SIGKILL', maxBuffer: 65536 }); }
  catch (error) { thrown = error; }
  const ended = process.hrtime.bigint();
  const stdout = typeof result?.stdout === 'string' ? result.stdout : '';
  fs.writeFileSync(log, stdout);
  return {
    schema_version: ACCOUNT_COUNT_SCHEMA, database, account_email_sha256: sha256(email),
    argv: argv.map((item) => (item.startsWith('target=') ? 'target=<redacted-account>' : item)), query: ACCOUNT_COUNT_QUERY,
    connection, exit_code: result?.status ?? null, timed_out: result?.error?.code === 'ETIMEDOUT',
    error: thrown?.message ?? result?.error?.message ?? null,
    started_monotonic_ns: started.toString(), ended_monotonic_ns: ended.toString(), duration_ms: Math.ceil(Number(ended - started) / 1e6),
    count: /^\d+\n$/.test(stdout) ? Number(stdout.trim()) : null, log_sha256: sha256(stdout), log_bytes: Buffer.byteLength(stdout)
  };
}

function verifyAccountCountReceipt(receipt, attempt, expectedDigest, expectedCount, label) {
  const errors = [];
  if (!receipt || receipt.schema_version !== ACCOUNT_COUNT_SCHEMA) return [`${label} account receipt is missing`];
  if (receipt.database !== attempt.database?.name) errors.push(`${label} account receipt is for another database`);
  if (receipt.account_email_sha256 !== expectedDigest) errors.push(`${label} account receipt digest is not the project's frozen collision account`);
  if (receipt.exit_code !== 0 || receipt.timed_out || receipt.error !== null) errors.push(`${label} account query did not exit cleanly`);
  if (receipt.count !== expectedCount) errors.push(`${label} account count is ${receipt.count}, expected ${expectedCount}`);
  if (JSON.stringify(receipt).match(/password/i)) errors.push(`${label} account receipt retains credential material`);
  try {
    const started = BigInt(receipt.started_monotonic_ns); const ended = BigInt(receipt.ended_monotonic_ns);
    if (started < BigInt(attempt.started_monotonic_ns) || ended > BigInt(attempt.ended_monotonic_ns) || ended <= started) errors.push(`${label} account query ran outside the charged window`);
  } catch { errors.push(`${label} account query monotonic bounds are missing`); }
  return errors;
}

export function verifyNativeLoadAttempt(attempt, freeze, baseDir) {
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!attempt || typeof attempt !== 'object') return { ok: false, errors: ['native load attempt is missing'] };
  const slot = freeze.ledger.slots.find((item) => item.id === attempt.slot_id);
  if (!slot) return { ok: false, errors: ['attempt does not identify a frozen load recovery slot'] };
  if (slot.id === 'CR-DARK-FIRST') return { ok: false, errors: ['the spent CR-DARK-FIRST slot cannot carry an accepted attempt'] };
  if (attempt.sequence !== slot.sequence || attempt.stage !== slot.stage || attempt.project !== slot.project
    || JSON.stringify(attempt.projects) !== JSON.stringify(slot.projects)) fail('attempt identity differs from its frozen slot');
  if (JSON.stringify(attempt.argv) !== JSON.stringify(slot.argv)) fail('native Playwright argv differs from the frozen project selection');
  if (attempt.argv?.some((arg) => /^(-g|--grep)(=|$)/.test(arg))) fail('a CLI grep overrides the per-project selection');
  if (!Number.isSafeInteger(attempt.charged_duration_ms) || attempt.charged_duration_ms < 0 || attempt.charged_duration_ms > slot.max_duration_ms) fail('native command exceeded its 120,000 ms reservation');
  if (attempt.source_commit !== freeze.source.checkout_head || JSON.stringify(attempt.source_blobs) !== JSON.stringify(freeze.source.blobs)) fail('attempt does not match the frozen source commit and blobs');
  let started = 0n; let ended = 0n;
  try { started = BigInt(attempt.started_monotonic_ns); ended = BigInt(attempt.ended_monotonic_ns); } catch { /* reported below */ }
  if (started <= 0n || ended <= started || Math.ceil(Number(ended - started) / 1e6) !== attempt.execution_duration_ms) fail('native command monotonic duration is missing or inconsistent');
  if (attempt.charged_duration_ms !== Math.max(attempt.execution_duration_ms, attempt.wall_duration_ms ?? 0)) fail('native command charge does not include its complete measured duration');
  if (attempt.host?.suspension_detected === true) fail('host suspension was detected during the native window');
  if (attempt.database?.setup_exit_code !== 0 || attempt.database?.drop_exit_code !== 0) fail('fresh database setup or drop did not succeed');
  if (!OWNED_CONTROL_DATABASE.test(attempt.database?.name ?? '')) fail('database identity is outside the synthetic control namespace');
  if (attempt.server?.http_status !== 200 || !Number.isInteger(attempt.server?.app_pid)) fail('server readiness or app process identity is missing');
  if (attempt.playwright_cli?.launched !== true || !Number.isInteger(attempt.playwright_cli?.exit_code) || attempt.browser?.launched !== true) fail('native Playwright CLI launch or exit is missing');
  if (attempt.lifecycle?.playwright_cli_processes !== 1) fail('a slot must consume exactly one physical Playwright CLI process');
  if (attempt.build_directory_removed !== true || !attempt.build_path?.endsWith('/mix-build')) fail('fresh physical Mix build was not removed');
  const absence = verifyDatabaseAbsenceReceipt(attempt.database?.absence_receipt, attempt, baseDir);
  for (const message of absence.errors) fail(`independent database absence: ${message}`);
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log', 'playwright_report']) {
    const reference = attempt.files?.[name]; const file = confinedFile(baseDir, reference);
    if (!file || !fs.existsSync(file)) { fail(`sanitized native ${name.replaceAll('_', ' ')} is missing`); continue; }
    if (!reference.sha256 || fileHash(file) !== reference.sha256) fail(`sanitized native ${name.replaceAll('_', ' ')} digest mismatch`);
    if (!fs.statSync(file).size && !(name === 'drop_log' && reference.sha256 === EMPTY_SHA256 && attempt.database?.drop_exit_code === 0 && absence.ok)) fail(`sanitized native ${name.replaceAll('_', ' ')} is empty`);
    if (name.endsWith('_log')) {
      const sanitation = validateSanitizedCommandLog(fs.readFileSync(file, 'utf8'));
      if (!sanitation.ok) fail(`${name} contains an unsanitized credential block or auth header: ${sanitation.errors.join('; ')}`);
    }
  }
  let tests = [];
  const reportFile = confinedFile(baseDir, attempt.files?.playwright_report);
  if (reportFile && fs.existsSync(reportFile)) {
    try {
      const report = readJson(reportFile);
      if (!Array.isArray(report.suites) || !Array.isArray(report.errors)) fail('native Playwright JSON report is structurally incomplete');
      tests = playReportTests(report);
      if (!tests.length) fail('native Playwright JSON report is empty');
      if (report.errors.length) fail('native Playwright report contains top-level errors');
    } catch (error) { fail(`native Playwright JSON report could not be parsed: ${error.message}`); }
  }
  const pairs = loadRequiredPairs(slot);
  if (tests.length !== pairs.length) fail(`native report has ${tests.length} rows, the frozen slot requires exactly ${pairs.length}`);
  const rows = [];
  for (const pair of pairs) {
    const matching = tests.filter((item) => item.title === pair.title && item.project === pair.project && path.basename(item.file) === pair.spec);
    if (matching.length !== 1) { fail(`native report must contain exactly one result for ${pair.project} / ${pair.title}`); continue; }
    const result = matching[0];
    const label = `${pair.project} / ${pair.title}`;
    rows.push({ ...pair, result });
    if (result.result_count !== 1 || ['skipped', 'interrupted', 'flaky'].includes(result.summary_status) || result.status === 'skipped') fail(`${label} was skipped, retried, interrupted, or has multiple native results`);
    const expected = slot.project_selections.find((item) => item.project === pair.project).expected[pair.title];
    if (expected === 'expected_failure') {
      if (result.expected_status !== 'passed' || result.status !== 'failed' || result.summary_status !== 'unexpected') fail(`${label} did not produce its expected native assertion failure`);
      if (!controlTestError(result).includes(CONTROL_EXPECTED_FAILURE_MARKERS[pair.title])) fail(`${label} failure report omits its frozen original assertion marker`);
    } else if (result.expected_status !== 'passed' || result.status !== 'passed' || result.summary_status !== 'expected') fail(`${label} did not pass natively as frozen`);
    const contexts = controlAnnotations(result, 'sigra-registration-control-context');
    if (pair.title !== CONTROL_BOARD_TITLE && (!contexts.length || contexts.some((value) => !/^[a-z0-9-]+:[a-f0-9-]{36}$/i.test(value)))) fail(`${label} omitted its fresh browser-context identity`);
  }
  const failures = rows.filter((row) => slot.project_selections.find((item) => item.project === row.project).expected[row.title] === 'expected_failure');
  const traces = attempt.files?.traces ?? [];
  if (traces.length !== failures.length) fail('retained native trace count does not exactly match the frozen expected-failure rows');
  for (const trace of traces) {
    const file = confinedFile(baseDir, trace);
    if (!file || !fs.existsSync(file) || !trace.sha256 || fileHash(file) !== trace.sha256 || fs.statSync(file).size < 22) fail('native failure trace is absent, empty, or has a digest mismatch');
  }
  for (const row of rows.filter((item) => item.title === 'registration retains the first forced assertion failure trace')) {
    const trace = traces.find((item) => item.title === row.title && item.project === row.project);
    if (!trace?.sanitization?.navigation || !trace.sanitization.submission) fail(`${row.project}: forced failure trace omits navigation or actual submit/click actions`);
    if (!controlTestError(row.result).includes('toHaveURL')) fail(`${row.project}: forced first assertion evidence lacks its original assertion`);
  }
  const appRef = attempt.files?.app_log && confinedFile(baseDir, attempt.files.app_log);
  const appText = appRef && fs.existsSync(appRef) ? fs.readFileSync(appRef, 'utf8') : '';
  if (!appText.includes('POST /users/log_in')) fail('no server-confirmed registration submission is present in the app log');
  const parse = (result, type) => controlAnnotations(result, type).map((value) => { try { return JSON.parse(value); } catch { return null; } }).filter(Boolean);
  const collisions = {}; const fresh = {};
  for (const row of rows) {
    if (row.title === 'registration detects a deliberate same-account collision') {
      const found = parse(row.result, 'sigra-registration-control-result').find((item) => item.first_registration_succeeded === true && item.duplicate_response_confirmed === true);
      if (!found || found.collision_email_sha256 !== slot.collision_account_sha256[row.project]) fail(`${row.project}: same-account collision lacks its persisted-first-registration receipt for this project's own account`);
      else collisions[row.project] = found.collision_email_sha256;
    }
    if (row.title === 'registration starts from a fresh database and context') {
      const found = parse(row.result, 'sigra-registration-control-result').find((item) => item.fresh_database_account_created === true);
      if (!found || found.prior_collision_account_email_sha256 !== slot.collision_account_sha256[row.project]) fail(`${row.project}: fresh-state pass lacks the project's prior collision account digest`);
      else fresh[row.project] = found.prior_collision_account_email_sha256;
    }
    if (row.title === 'registration discards trace after a passing control' && traces.some((item) => item.project === row.project && item.title === row.title)) fail('passing control retained a trace');
  }
  if (slot.stage === 'second') {
    const project = slot.project; const digest = slot.collision_account_sha256[project];
    errors.push(...verifyAccountCountReceipt(attempt.prior_collision_absence, attempt, digest, 0, 'prior collision absence before browser work'));
    errors.push(...verifyAccountCountReceipt(attempt.created_account, attempt, digest, 1, 'created account after registration'));
    if (attempt.prior_collision_absence && attempt.created_account && BigInt(attempt.prior_collision_absence.ended_monotonic_ns || 0) > BigInt(attempt.created_account.started_monotonic_ns || 0)) fail('absence query must precede the created-account query');
    if (!fresh[project]) fail('second slot has no fresh-state result');
  } else if (Object.keys(collisions).length !== slot.projects.length) fail('all three projects need their own native same-account collision receipt');
  const contextIds = rows.flatMap((row) => controlAnnotations(row.result, 'sigra-registration-control-context'));
  if (new Set(contextIds).size !== contextIds.length) fail('two selected rows reused the same browser-context identity');
  if (failures.some((row) => row.title === 'registration waits for explicitly released LiveView readiness')) fail('the held readiness control must pass after its explicit release');
  if (attempt.playwright_cli?.exit_code !== slot.expected_cli_exit) fail(`Playwright CLI exit does not match the frozen ${slot.expected_cli_exit}`);
  if (!attempt.lifecycle || attempt.lifecycle.rows !== pairs.length || !(attempt.lifecycle.worker_indexes?.length >= 1)) fail('process, worker and context lifecycle receipt is incomplete');
  attempt.collision_receipts = collisions; attempt.fresh_state_receipts = fresh;
  return { ok: errors.length === 0, errors };
}

export function verifyLoadRecoveryEvidenceData(evidence, freeze, baseDir, stage = 'complete', freezeFileHash = freeze?.freeze_sha256) {
  const errors = [];
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) return { ok: false, errors: ['native load recovery evidence is missing or malformed'] };
  if (freeze?.schema_version !== LOAD_RECOVERY_FREEZE_SCHEMA || freeze.freeze_sha256 !== loadFreezeDigest(freeze) || evidence.freeze_sha256 !== freezeFileHash) errors.push('evidence does not match the immutable load recovery freeze');
  if (evidence.schema_version !== LOAD_RECOVERY_SCHEMA || JSON.stringify(evidence.source) !== JSON.stringify(freeze?.source)) errors.push('evidence source identity differs from the frozen commit and blobs');
  if (evidence.reservation || ['running', 'halted'].includes(evidence.status)) errors.push('evidence contains an unresolved predebit reservation or a halted status');
  if (evidence.limits?.retry_used !== 1 || evidence.limits?.retry_available !== 0) errors.push('the spent shared retry was reopened or miscounted');
  if (evidence.limits?.prior_charge_ms !== 276453 || evidence.limits?.preparation_remaining_ms !== 112489) errors.push('carried historical charge or preparation balance changed');
  if (evidence.limits?.max_total_ms !== 3480000 || evidence.limits?.max_physical_playwright_cli_launches !== 18) errors.push('shared time or physical CLI launch ceiling changed');
  const attempts = Array.isArray(evidence.attempts) ? evidence.attempts : [];
  const count = stage === 'first' ? 1 : stage === 'complete' ? 4 : -1;
  if (count < 0 || attempts.length !== count) errors.push(`stage ${stage} requires exactly ${count} accepted new native command receipts`);
  const slots = (freeze?.ledger?.slots ?? []).slice(0, Math.max(0, count));
  if (attempts.some((attempt, index) => attempt.slot_id !== slots[index]?.id)) errors.push('new commands do not match the exact unused reservation order');
  if (attempts.some((attempt) => LOAD_SPENT.includes(attempt.slot_id))) errors.push('a spent reservation was reopened');
  const usedSlots = [...(freeze?.ledger?.spent_reservations ?? []), ...attempts.map((attempt) => attempt.slot_id)];
  if (JSON.stringify(evidence.limits?.used_slots) !== JSON.stringify(usedSlots)) errors.push('used reservation ledger differs from historical receipts and actual attempts');
  const measured = (freeze?.ledger?.prior_charge_ms ?? 0) + attempts.reduce((sum, attempt) => sum + (Number(attempt.charged_duration_ms) || 0), 0) + (Number(evidence.limits?.preparation_charge_ms) || 0);
  if (evidence.limits?.charged_duration_ms !== measured) errors.push('cumulative charge does not equal preserved history, preparation and measured command receipts');
  if ((evidence.limits?.preparation_charge_ms ?? 0) > 112489) errors.push('preparation exceeded its remaining allowance');
  const launches = (freeze?.ledger?.prior_playwright_cli_launches ?? 0) + attempts.filter((attempt) => attempt.playwright_cli?.launched === true).length;
  if (evidence.limits?.physical_playwright_cli_launches !== launches || launches > (freeze?.ledger?.physical_cli_launch_max ?? -1)) errors.push('physical Playwright CLI launch count differs from native receipts or exceeds its frozen ceiling');
  if (measured > (freeze?.ledger?.d19?.cap_ms ?? -1) || measured > (freeze?.ledger?.shared_cap_ms ?? -1)) errors.push('D-19 or shared time limit was exceeded');
  for (const attempt of attempts) errors.push(...verifyNativeLoadAttempt(attempt, freeze, baseDir).errors.map((message) => `${attempt.slot_id}: ${message}`));
  attempts.forEach((attempt, index) => {
    if (attempts.slice(0, index).some((prior) => prior.database?.name === attempt.database?.name)) errors.push('two native slots reused the same physical database identity');
  });
  if (stage === 'first' && evidence.status !== 'first_complete') errors.push('first command status is not accepted');
  if (stage === 'complete') {
    if (evidence.status !== 'complete') errors.push('complete status is not accepted');
    const total = attempts.reduce((sum, attempt) => sum + (attempt.lifecycle?.rows ?? 0), 0);
    if (total !== 22) errors.push(`native rows total ${total}, the complete proof requires 22`);
    for (const attempt of attempts.slice(1)) {
      const prior = attempts[0]?.collision_receipts?.[attempt.project];
      if (!prior || prior !== attempt.fresh_state_receipts?.[attempt.project] || attempts[0].database?.name === attempt.database?.name) errors.push(`${attempt.project}: fresh database does not prove the prior collision account absent before recreating it`);
    }
  }
  return { ok: errors.length === 0, errors };
}

function preserveLoadRecoveryEvidenceRevision(evidenceFile, root, evidence) {
  const relative = path.relative(root, evidenceFile);
  const bytes = fs.readFileSync(evidenceFile);
  const status = run('git', ['-C', root, 'status', '--porcelain=v1', '--', relative]);
  if (status.status !== 0) throw new Error('cannot capture evidence source status before replacement');
  const digest = sha256(bytes);
  const blob = git(['-C', root, 'hash-object', '-w', '--', relative]);
  const ref = `refs/gsd/phase253-load-recovery-native-evidence/${digest}`;
  const updated = run('git', ['-C', root, 'update-ref', ref, blob]);
  if (updated.status !== 0) throw new Error(`cannot preserve exact evidence revision under ${ref}: ${updated.stderr.trim()}`);
  if (!readGitBlob(root, ref).equals(bytes)) throw new Error(`exact evidence revision read-back failed for ${ref}`);
  evidence.preserved_revisions.push({ path: relative, status: status.stdout.trimEnd(), sha256: digest, blob, ref, bytes: bytes.length, read_back_exact: true });
}

function writeLoadRecoveryEvidence(evidenceFile, root, evidence, deps) {
  if (fs.existsSync(evidenceFile) && !deps.skipPreservation) preserveLoadRecoveryEvidenceRevision(evidenceFile, root, evidence);
  if (fs.existsSync(evidenceFile)) fs.rmSync(evidenceFile);
  writeJson(evidenceFile, evidence);
}

// Bounded preparation: toolchain version probes only (no app boot, warmup, Playwright CLI, or browser install).
export async function prepareLoadRecovery(freezeFile, evidenceFile, root = ROOT, deps = {}) {
  const d = { validate: validateLoadRecoveryFreeze, runTree: runLoggedTree, ...deps };
  const freeze = readJson(freezeFile);
  d.validate(root, freeze);
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== LOAD_RECOVERY_SCHEMA || evidence.freeze_sha256 !== fileHash(freezeFile)) throw new Error('evidence does not match the committed freeze');
  if (evidence.status !== 'ready' || evidence.reservation || evidence.preparation) throw new Error('preparation is only available once, from ready evidence');
  if (evidence.attempts.length || evidence.limits.physical_playwright_cli_launches !== freeze.ledger.prior_playwright_cli_launches) throw new Error('preparation must precede every new native command');
  const reserve = evidence.limits.preparation_remaining_ms;
  evidence.status = 'running';
  evidence.reservation = { kind: 'preparation', reserved_ms: reserve, predebited_at: new Date().toISOString() };
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  const dir = path.join(`${evidenceFile}.raw`, 'preparation'); fs.mkdirSync(dir, { recursive: true });
  const exampleDir = path.join(root, 'test/example'); const env = { ...process.env, MIX_ENV: 'dev' };
  const commands = [['mix_version', 'mix', ['--version']], ['host_dependency_versions', 'mix', ['deps']]];
  const started = process.hrtime.bigint(); const receipts = []; let failed = null;
  for (const [name, program, args] of commands) {
    const remaining = reserve - Math.ceil(Number(process.hrtime.bigint() - started) / 1e6);
    if (remaining <= 0) { failed = 'preparation reached its predebited allowance'; break; }
    const log = path.join(dir, `${name}.log`);
    const result = await d.runTree(program, args, exampleDir, env, log, remaining);
    receipts.push({ name, argv: [program, ...args], exit_code: result.exit_code, duration_ms: result.duration_ms, log: referenceFor(`${evidenceFile}.raw`, log) });
    if (result.exit_code !== 0 || result.timed_out) { failed = `${name} failed`; break; }
  }
  const duration = Math.ceil(Number(process.hrtime.bigint() - started) / 1e6);
  evidence.reservation = null; evidence.preparation = { receipts, duration_ms: duration, status: failed ? 'failed' : 'passed' };
  evidence.limits.preparation_charge_ms = duration; evidence.limits.preparation_remaining_ms = Math.max(0, reserve - duration);
  evidence.limits.charged_duration_ms += duration;
  evidence.status = failed || duration > reserve ? 'halted' : 'ready';
  if (evidence.status === 'halted') evidence.stop_reason = failed ?? 'preparation exceeded its allowance';
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  if (evidence.status === 'halted') throw new Error(evidence.stop_reason);
  return { status: evidence.status, preparation_charge_ms: duration };
}

export async function runLoadRecoverySlot(freezeFile, slotId, evidenceFile, root = ROOT, deps = {}) {
  const d = {
    validate: validateLoadRecoveryFreeze, runTree: runLoggedTree, spawnApp: spawn, waitReady, portAvailable, stopApp, holdAwake: holdHostAwake,
    captureAbsence: captureOwnedDatabaseAbsence, captureAccount: captureOwnedAccountCount, sanitizeTrace: sanitizeTraceFile,
    skipPreservation: false, enforcePaths: true, enforceNode: true, ...deps
  };
  if (slotId === 'CR-DARK-FIRST' || LOAD_SPENT.includes(slotId)) throw new Error(`reservation ${slotId} is permanently spent and cannot be run or retried`);
  if (d.enforcePaths && (path.resolve(freezeFile) !== path.resolve(root, LOAD_RECOVERY_FREEZE_PATH) || path.resolve(evidenceFile) !== path.resolve(root, LOAD_RECOVERY_EVIDENCE_PATH))) throw new Error('load recovery accepts only the reviewed phase freeze and additive evidence paths');
  if (d.enforceNode && process.version !== LOAD_NODE) throw new Error(`load recovery native commands require Node ${LOAD_NODE}`);
  const freeze = readJson(freezeFile);
  const freezeHash = fileHash(freezeFile);
  const slot = freeze.ledger?.slots?.find((item) => item.id === slotId);
  if (!slot || !LOAD_SLOT_TABLE.some(([id]) => id === slotId)) throw new Error('only the four frozen unused load recovery slots may run');
  d.validate(root, freeze);
  if (!fs.existsSync(evidenceFile)) throw new Error('native load recovery evidence must be initialized and committed before launch');
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== LOAD_RECOVERY_SCHEMA || evidence.freeze_sha256 !== freezeHash) throw new Error('native load evidence does not match the committed freeze');
  if (!['ready', 'first_complete', 'second_partial'].includes(evidence.status) || evidence.reservation) throw new Error(`refusing to use terminal or reserved recovery evidence: ${evidence.status}`);
  if (evidence.limits.used_slots.includes(slot.id)) throw new Error(`reservation ${slot.id} was already consumed`);
  if (evidence.limits.retry_used !== 1 || evidence.limits.retry_available !== 0 || evidence.limits.prior_charge_ms !== freeze.ledger.prior_charge_ms
    || evidence.limits.charged_duration_ms < freeze.ledger.prior_charge_ms) throw new Error('counter reset or reopened retry detected before setup');
  const nextSlot = freeze.ledger.slots[evidence.attempts.length];
  if (!nextSlot || nextSlot.id !== slot.id) throw new Error('slots must run in frozen order, each exactly once');
  const reserve = slot.max_duration_ms;
  const unusedRegular = freeze.ledger.slots.filter((item) => !evidence.limits.used_slots.includes(item.id)).length;
  if (reserve !== 120000 || evidence.limits.charged_duration_ms + reserve + 9 * 240000 > freeze.ledger.shared_cap_ms
    || evidence.limits.charged_duration_ms + unusedRegular * reserve > freeze.ledger.d19.cap_ms
    || evidence.limits.physical_playwright_cli_launches + unusedRegular + 9 > freeze.ledger.physical_cli_launch_max) throw new Error('remaining D-19 and conditional D-20 reservations do not fit frozen limits');
  if (!(await d.portAvailable(slot.port))) throw new Error(`frozen port ${slot.port} is occupied before native setup`);
  const project = PROJECTS.find((item) => item.name === slot.project);
  // Acquired before the predebit so a host that cannot be kept awake costs no reservation.
  const awake = d.holdAwake();
  try {
    return await runHeldLoadRecoverySlot({ d, root, freeze, slot, evidence, evidenceFile, reserve, project, awake });
  } finally { awake.release(); }
}

async function runHeldLoadRecoverySlot({ d, root, freeze, slot, evidence, evidenceFile, reserve, project, awake }) {
  const rawDir = `${evidenceFile}.raw`;
  const rawAttempt = createAttemptDirectory(rawDir, slot.id, 1);
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-load-recovery-'));
  const started = process.hrtime.bigint();
  const wallStarted = Date.now();
  const nowMs = () => Number(process.hrtime.bigint()) / 1e6;
  const commandDeadline = Number(started) / 1e6 + reserve;
  const workDeadline = commandDeadline - slot.cleanup_ms;
  // Remaining budget by whichever clock is further along: monotonic time may exclude host sleep,
  // so the wall clock independently bounds every stage of the window (253-40).
  const remainingUntil = (offsetMs) => Math.min(Number(started) / 1e6 + offsetMs - nowMs(), wallStarted + offsetMs - Date.now());
  const workRemaining = () => remainingUntil(reserve - slot.cleanup_ms);
  const database = `sigra_253_control_load_${slot.id.toLowerCase().replaceAll('-', '_')}_${Date.now().toString(36)}_${process.pid}`.toLowerCase();
  const env = diagnosticEnvironment(project, database, tempRoot);
  const tempPaths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(tempRoot, `${name.replaceAll('_', '-')}.log`)]));
  const reportTemp = path.join(tempRoot, 'playwright-report.json');
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: slot.project, projects: slot.projects, argv: slot.argv,
    source_commit: freeze.source.checkout_head, source_blobs: freeze.source.blobs, started_monotonic_ns: started.toString(),
    database: { name: database, setup_exit_code: null, drop_exit_code: null, connection: databaseConnectionIdentity(env) },
    server: { port: slot.port, http_status: null, app_pid: null }, browser: { launched: false, exit_code: null },
    playwright_cli: { launched: false, exit_code: null }, lifecycle: { playwright_cli_processes: 0, rows: 0, worker_indexes: [] },
    observed_outcome: 'setup_failed', files: {}, traces: [], registration: { server_post_confirmed: false },
    toolchain: { playwright: null, ecto_sql: freeze.tools.ecto_sql, phoenix_live_view: freeze.tools.phoenix_live_view },
    build_path: env.MIX_BUILD_PATH, stage_deadlines: { command_ms: reserve, work_ms: slot.work_ms, cleanup_ms: slot.cleanup_ms, cleanup_reserved: true },
    host: { platform: awake.platform, sleep_assertion_held: awake.held, sleep_assertion_argv: awake.argv ?? null, suspension_detected: false }
  };
  evidence.status = 'running';
  evidence.reservation = { slot_id: slot.id, mapped_from: slot.maps_from, reserved_ms: reserve, predebited_at: new Date().toISOString(), source_commit: freeze.source.checkout_head };
  evidence.limits.used_slots.push(slot.id);
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  let app = null; let terminalError = null;
  const playwrightDir = path.join(root, LOAD_PLAYWRIGHT_DIR);
  try {
    const setup = await d.runTree('mix', ['ecto.setup'], path.join(root, 'test/example'), env, tempPaths.setup_log, workRemaining());
    attempt.setup = setup; attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0 || setup.timed_out) throw new Error(`fresh database setup failed${setup.timed_out ? ' at its work deadline' : ` with exit ${setup.exit_code ?? 'null'}`}`);
    const appFd = fs.openSync(tempPaths.app_log, 'w');
    try { app = d.spawnApp('mix', ['phx.server'], { cwd: path.join(root, 'test/example'), env, stdio: ['ignore', appFd, appFd], detached: true }); }
    finally { fs.closeSync(appFd); }
    attempt.server.app_pid = app.pid ?? null;
    attempt.server.http_status = app.pid ? await d.waitReady(app, `http://127.0.0.1:${slot.port}/`, workDeadline) : null;
    if (attempt.server.http_status !== 200) throw new Error('fresh app did not return HTTP 200 before the reserved work deadline');
    const installed = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installed !== freeze.tools.playwright) throw new Error(`installed Playwright ${installed} differs from the frozen ${freeze.tools.playwright}`);
    attempt.toolchain.playwright = installed;
    if (workRemaining() <= 0) throw new Error('the reserved work deadline passed before browser launch');
    if (slot.stage === 'second') {
      const absenceLog = path.join(tempRoot, 'prior-collision-absence.log');
      attempt.prior_collision_absence = d.captureAccount({ database, email: loadControlAccount(slot.project, 'collision'), env, cwd: path.join(root, 'test/example'), log: absenceLog, deadline: workDeadline });
      attempt.files.prior_collision_absence = receiptFile(rawDir, 'prior collision absence', (() => { const target = path.join(rawAttempt, 'prior-collision-absence.log'); fs.copyFileSync(absenceLog, target, fs.constants.COPYFILE_EXCL); return target; })());
      if (attempt.prior_collision_absence.count !== 0) throw new Error('prior collision account is not absent from the newly created database');
    }
    attempt.browser.launched = true; attempt.playwright_cli.launched = true; attempt.lifecycle.playwright_cli_processes = 1;
    const args = ['test', freeze.selection.spec, ...slot.argv, `--output=${path.join(tempRoot, 'playwright-output')}`];
    attempt.browser_command_argv = args;
    const browser = await d.runTree(path.join(playwrightDir, 'node_modules/.bin/playwright'), args, playwrightDir, {
      ...env, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${slot.port}`, SIGRA_PLAYWRIGHT_JSON: reportTemp,
      SIGRA_REGISTRATION_CONTROL_STAGE: slot.control_stage, SIGRA_CONTROL_RUN_ID: `${slot.id.toLowerCase()}-${crypto.randomUUID()}`,
      SIGRA_CONTROL_ACCOUNT_PREFIX: 'platform-admin+sigra-253-control', PLAYWRIGHT_HTML_OUTPUT_DIR: path.join(tempRoot, 'html-report')
    }, tempPaths.test_log, workRemaining());
    attempt.test_command = browser; attempt.browser.exit_code = browser.exit_code; attempt.playwright_cli.exit_code = browser.exit_code; attempt.lifecycle.cli_pid = browser.pid ?? null;
    if (browser.timed_out) throw new Error('native Playwright command reached the reserved work deadline');
    if (!fs.existsSync(reportTemp) || fs.statSync(reportTemp).size === 0) throw new Error('native Playwright JSON report is absent or empty');
    const report = readJson(reportTemp);
    const tests = playReportTests(report);
    for (const item of tests) for (const attachment of item.attachments ?? []) {
      if (attachment.name !== 'trace' && !String(attachment.path ?? '').endsWith('trace.zip')) continue;
      if (!attachment.path || !fs.existsSync(attachment.path)) throw new Error(`native trace attachment for ${item.title} is missing`);
      const target = path.join(rawAttempt, `trace-${attempt.traces.length + 1}.zip`);
      const trace = d.sanitizeTrace(attachment.path, target);
      attempt.traces.push({ ...receiptFile(rawDir, 'sanitized native trace', target), title: item.title, project: item.project, sanitization: trace });
      attachment.path = path.relative(root, target);
    }
    attempt.files.traces = attempt.traces;
    const safeReport = path.join(rawAttempt, 'playwright-report.json');
    fs.writeFileSync(safeReport, `${JSON.stringify(sanitizeReportText(report), null, 2)}\n`, { flag: 'wx' });
    attempt.files.playwright_report = receiptFile(rawDir, 'sanitized native Playwright report', safeReport);
    attempt.lifecycle.rows = tests.length;
    attempt.lifecycle.worker_indexes = [...new Set(tests.flatMap((item) => (Number.isInteger(item.worker_index) ? [item.worker_index] : [])))].sort((a, b) => a - b);
    attempt.lifecycle.context_ids = tests.flatMap((item) => controlAnnotations(item, 'sigra-registration-control-context'));
    attempt.lifecycle.projects_run = [...new Set(tests.map((item) => item.project))];
    attempt.registration.server_post_confirmed = /POST \/users\/log_in/.test(fs.existsSync(tempPaths.app_log) ? fs.readFileSync(tempPaths.app_log, 'utf8') : '');
    if (slot.stage === 'second') {
      const createdLog = path.join(tempRoot, 'created-account.log');
      attempt.created_account = d.captureAccount({ database, email: loadControlAccount(slot.project, 'collision'), env, cwd: path.join(root, 'test/example'), log: createdLog, deadline: commandDeadline - slot.cleanup_ms + 5000 });
      attempt.files.created_account = receiptFile(rawDir, 'created account', (() => { const target = path.join(rawAttempt, 'created-account.log'); fs.copyFileSync(createdLog, target, fs.constants.COPYFILE_EXCL); return target; })());
    }
    attempt.observed_outcome = 'native_report_pending_validation';
  } catch (error) { terminalError = error.message; }
  finally {
    await d.stopApp(app);
    if (fs.existsSync(tempPaths.app_log)) attempt.log_redactions_app = sanitizeCommandLog(tempPaths.app_log);
    const cleanupRemaining = remainingUntil(reserve);
    if (cleanupRemaining <= 0) terminalError = [terminalError, 'owned cleanup exceeded the 120,000 ms command limit'].filter(Boolean).join('; ');
    // An overrun is already terminal, so dropping the owned database still gets a bounded floor
    // instead of a 1 ms budget that guarantees an orphaned database (253-40).
    const drop = await d.runTree('mix', ['ecto.drop', '--quiet'], path.join(root, 'test/example'), env, tempPaths.drop_log, Math.max(LOAD_DROP_FLOOR_MS, Math.min(7000, cleanupRemaining - 5000)));
    attempt.database.drop_exit_code = drop.exit_code; attempt.drop_command = drop;
    if (drop.exit_code !== 0 || drop.timed_out) terminalError = [terminalError, `database drop failed${drop.timed_out ? ' at cleanup deadline' : ` with exit ${drop.exit_code ?? 'null'}`}`].filter(Boolean).join('; ');
    if (drop.exit_code === 0 && !drop.timed_out) {
      try { attempt.database.absence_receipt = d.captureAbsence({ database, env, cwd: path.join(root, 'test/example'), log: path.join(tempRoot, 'database-absence.log'), deadline: Math.max(commandDeadline, nowMs() + LOAD_ABSENCE_FLOOR_MS) }); }
      catch (error) { terminalError = [terminalError, `independent database absence query failed: ${error.message}`].filter(Boolean).join('; '); }
    }
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    if (!fs.existsSync(tempPaths[name])) fs.writeFileSync(tempPaths[name], `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    const target = path.join(rawAttempt, `${name.replaceAll('_', '-')}.log`);
    fs.copyFileSync(tempPaths[name], target, fs.constants.COPYFILE_EXCL);
    attempt.files[name] = receiptFile(rawDir, `sanitized ${name}`, target);
  }
  const absenceTemp = path.join(tempRoot, 'database-absence.log');
  if (fs.existsSync(absenceTemp)) {
    const target = path.join(rawAttempt, 'database-absence.log');
    fs.copyFileSync(absenceTemp, target, fs.constants.COPYFILE_EXCL);
    attempt.files.database_absence = receiptFile(rawDir, 'owned database absence query log', target);
  }
  attempt.ended_monotonic_ns = process.hrtime.bigint().toString();
  attempt.execution_duration_ms = Math.ceil(Number(BigInt(attempt.ended_monotonic_ns) - BigInt(attempt.started_monotonic_ns)) / 1e6);
  attempt.wall_duration_ms = Math.ceil(Date.now() - wallStarted);
  // Charge the larger clock: monotonic time may exclude host sleep, and a charge must never hide it.
  attempt.charged_duration_ms = Math.max(attempt.execution_duration_ms, attempt.wall_duration_ms);
  attempt.host.suspension_detected = [attempt.setup, attempt.test_command, attempt.drop_command].some((result) => result?.suspended === true)
    || Math.abs(attempt.wall_duration_ms - attempt.execution_duration_ms) > TREE_SUSPEND_GAP_MS;
  if (attempt.host.suspension_detected) terminalError = [terminalError, 'host suspension (system sleep or a stalled runner event loop) was detected during the native window, so its timings cannot be accepted'].filter(Boolean).join('; ');
  if (attempt.charged_duration_ms > reserve) terminalError = [terminalError, 'native command exceeded its frozen 120,000 ms command reservation'].filter(Boolean).join('; ');
  const validation = verifyNativeLoadAttempt(attempt, freeze, rawDir);
  if (!validation.ok) terminalError = [terminalError, ...validation.errors].filter(Boolean).join('; ');
  evidence.reservation = null;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  if (attempt.playwright_cli.launched) evidence.limits.physical_playwright_cli_launches += 1;
  evidence.attempts.push(attempt);
  if (terminalError) { evidence.status = 'halted'; evidence.stop_reason = terminalError; attempt.observed_outcome = 'halted'; }
  else {
    evidence.status = evidence.attempts.length === 4 ? 'complete' : evidence.attempts.length === 1 ? 'first_complete' : 'second_partial';
    attempt.observed_outcome = 'native_rows_accepted';
  }
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  fs.rmSync(tempRoot, { recursive: true, force: true });
  if (terminalError) throw new Error(terminalError);
  return { status: evidence.status, slot: slot.id, rows: attempt.lifecycle.rows, charged_duration_ms: attempt.charged_duration_ms, physical_playwright_cli_launches: evidence.limits.physical_playwright_cli_launches };
}

function verifyLoadRecoveryFile(evidenceFile, stage, root = ROOT) {
  try {
    if (path.resolve(evidenceFile) !== path.resolve(root, LOAD_RECOVERY_EVIDENCE_PATH)) throw new Error('verification accepts only the additive Plan 39 native evidence path');
    const evidence = readJson(evidenceFile);
    const freezeFile = path.resolve(root, evidence.freeze_path ?? '');
    if (freezeFile !== path.resolve(root, LOAD_RECOVERY_FREEZE_PATH)) throw new Error('native evidence does not point to the reviewed load recovery freeze');
    const freeze = readJson(freezeFile);
    validateLoadRecoveryFreeze(root, freeze);
    const result = verifyLoadRecoveryEvidenceData(evidence, freeze, `${evidenceFile}.raw`, stage, fileHash(freezeFile));
    if (!result.ok) console.error(`native load recovery evidence rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`native load recovery verified: ${evidence.attempts.length}/4 commands; ${evidence.limits.physical_playwright_cli_launches}/18 CLI launches; ${evidence.limits.charged_duration_ms} ms cumulative; retry_available=0`);
    return result;
  } catch (error) { console.error(`native load recovery evidence rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

// ---- Phase 253 plan 48: R2 load-recovery revision (additive; the Plan 39 code above is untouched) ----
// 253-40 halted honestly: a host-sleep infrastructure fault inside the first window. R2 re-freezes the
// remaining 22 control rows on the fixed runner under new identities and a Jon-approved budget.
const LOAD_R2_FREEZE_SCHEMA = 'sigra.phase253.registration-load-recovery-freeze/v2';
const LOAD_R2_SCHEMA = 'sigra.phase253.registration-load-recovery-evidence/v2';
const LOAD_R2_APPROVAL_SCHEMA = 'sigra.phase253.load-recovery-budget-approval/v1';
const LOAD_R2_FREEZE_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json`;
const LOAD_R2_EVIDENCE_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json`;
const LOAD_R2_BUDGET_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-BUDGETS-R2.md`;
const LOAD_R2_APPROVAL_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`;
const LOAD_R2_DEBUG_PATH = '.planning/debug/resolved/253-native-deadline-not-enforced.md';
const LOAD_R2_HALTED = {
  evidence: { file: LOAD_RECOVERY_EVIDENCE_PATH, sha256: 'ec63a2410927d8f92e96b3eb4d166bcd4d8ff11061941508050e164c0d669b76' },
  freeze: { file: LOAD_RECOVERY_FREEZE_PATH, sha256: '98030037d8136b3732ca01dbe1f127181526a61a82961b270feddb7ca849cafa' }
};
const LOAD_R2_FIX_COMMIT_PREFIX = 'cf578a567';
const LOAD_R2_SPENT = [...LOAD_SPENT, 'CR-DESKTOP-MOBILE-FIRST'];
const LOAD_R2_CHARGES = [...LOAD_CHARGES, 655, 1_765_488];
const LOAD_R2_FIRST_ID = 'CR2-DESKTOP-MOBILE-FIRST';
const LOAD_R2_RETRY_ID = 'CR2-INFRA-RETRY';
const LOAD_R2_PREPARATION_MS = 30_000;
const LOAD_R2_HEADROOM_MS = 15_000;
// Equal to the rows of 253-LOAD-RECOVERY-BUDGETS-R2.md; the ledger builder recomputes them and refuses drift.
const LOAD_R2_CAP_TABLE = {
  approve: { new_allowance_ms: 645000, d19_cap_ms: 2687596, d19_launch_max: 11, shared_cap_ms: 5027596, physical_cli_max: 20 },
  'approve-without-retry': { new_allowance_ms: 525000, d19_cap_ms: 2567596, d19_launch_max: 10, shared_cap_ms: 4907596, physical_cli_max: 19 }
};

function loadR2Caps(withRetry) {
  const newAllowance = LOAD_R2_PREPARATION_MS + 4 * PROJECT_SLOT_MS + (withRetry ? PROJECT_SLOT_MS : 0) + LOAD_R2_HEADROOM_MS;
  const d19 = 2_042_596 + newAllowance;
  const d19Launches = 6 + 4 + (withRetry ? 1 : 0);
  return { new_allowance_ms: newAllowance, d19_cap_ms: d19, d19_launch_max: d19Launches, shared_cap_ms: d19 + 9 * 240_000 + 3 * 60_000, physical_cli_max: d19Launches + 9 };
}

export function loadRecoverySlotDefinitionsR2() {
  const regular = loadRecoverySlotDefinitions().map((slot, index) => (index === 0 ? { ...slot, id: LOAD_R2_FIRST_ID, maps_from: 'CR-DESKTOP-MOBILE-FIRST' } : slot));
  return [...regular, {
    id: LOAD_R2_RETRY_ID, sequence: 5, maps_from: LOAD_R2_RETRY_ID, retry: true, retry_of: 'resolved_from_halted_slot', selection: null,
    max_duration_ms: PROJECT_SLOT_MS, work_ms: 105_000, cleanup_ms: 15_000, launch_unit: 'playwright_cli_process', config: LOAD_RECOVERY_CONFIG, rows: 0
  }];
}

// The retry re-runs the halted slot's exact frozen selection once under the retry identity.
function loadR2EffectiveRetrySlot(slots, haltedId) {
  const halted = slots.slice(0, 4).find((slot) => slot.id === haltedId);
  if (!halted) throw new Error(`infrastructure retry has no frozen slot to re-run: ${haltedId}`);
  return { ...halted, id: LOAD_R2_RETRY_ID, maps_from: haltedId, retry: true, retry_of: haltedId };
}

export function buildLoadRecoveryLedgerR2(input) {
  const errors = [];
  if (!Array.isArray(input?.charges) || JSON.stringify(input.charges) !== JSON.stringify(LOAD_R2_CHARGES)) errors.push('carried historical charges do not match the exact ten carried components');
  if (input?.physicalPlaywrightLaunches !== 6) errors.push('carried Playwright CLI launch count must be exactly six');
  if (JSON.stringify(input?.spentReservations) !== JSON.stringify(LOAD_R2_SPENT)) errors.push('spent reservation inventory must be the seven closed identities');
  if (input?.retryUsed !== 1 || input?.retryAvailable !== 0) errors.push('original retry must remain used 1, available 0');
  if (input?.preparationUsedMs !== 4398) errors.push('carried preparation used must be exactly 3743 + 655 = 4398 ms');
  if (errors.length) throw new Error(errors.join('; '));
  const priorCharge = input.charges.reduce((sum, value) => sum + value, 0);
  const slots = loadRecoverySlotDefinitionsR2();
  const caps = { approve: loadR2Caps(true), 'approve-without-retry': loadR2Caps(false) };
  if (priorCharge !== 2_042_596 || JSON.stringify(caps) !== JSON.stringify(LOAD_R2_CAP_TABLE)
    || slots.slice(0, 4).reduce((sum, slot) => sum + slot.rows, 0) !== 22 || slots[0].rows !== 16 || slots.slice(1, 4).some((slot) => slot.rows !== 2)) {
    throw new Error('R2 load recovery arithmetic, caps or row packing differs from the reviewed finite allocation');
  }
  return {
    prior_charge_ms: priorCharge, prior_playwright_cli_launches: 6, spent_reservations: [...LOAD_R2_SPENT],
    retry_used: 1, retry_available: 0, preparation_used_ms: 4398, preparation_reserve_ms: LOAD_R2_PREPARATION_MS, slots,
    launch_unit: 'playwright_cli_process', engine_worker_lifecycle_accounting: 'separate_from_playwright_cli_launches',
    regular_command_ms: PROJECT_SLOT_MS, retry_command_ms: PROJECT_SLOT_MS, headroom_ms: LOAD_R2_HEADROOM_MS,
    conditional_acceptance_slots: 9, conditional_acceptance_ms: 2_160_000, optional_seed_checks_ms: 180_000, cleanup_reserve_per_command_ms: 15_000,
    caps, required_rows: 22
  };
}

function readFrozenBytesR2(root, commit, file) {
  return readGitBlob(root, `${commit}:${file}`);
}

export function readLoadHistoryR2(root) {
  const v1 = readLoadHistory(root);
  const evidenceFile = path.join(root, LOAD_R2_HALTED.evidence.file);
  const freezeFile = path.join(root, LOAD_R2_HALTED.freeze.file);
  if (fileHash(evidenceFile) !== LOAD_R2_HALTED.evidence.sha256 || fileHash(freezeFile) !== LOAD_R2_HALTED.freeze.sha256) throw new Error('halted 253-40 freeze or evidence bytes changed');
  const evidence = readJson(evidenceFile);
  const haltedFreeze = readJson(freezeFile);
  const attempt = evidence.attempts?.[0];
  const limits = evidence.limits ?? {};
  if (evidence.status !== 'halted' || evidence.attempts?.length !== 1 || attempt?.slot_id !== 'CR-DESKTOP-MOBILE-FIRST' || attempt.charged_duration_ms !== 1_765_488
    || evidence.preparation?.duration_ms !== 655 || limits.preparation_charge_ms !== 655 || limits.charged_duration_ms !== 2_042_596
    || limits.physical_playwright_cli_launches !== 6 || limits.prior_charge_ms !== 276453 || JSON.stringify(limits.used_slots) !== JSON.stringify(LOAD_R2_SPENT)
    || limits.retry_used !== 1 || limits.retry_available !== 0) throw new Error('halted 253-40 receipt differs from the 2042596 ms, six-launch, seven-spent ledger');
  const rawBase = `${evidenceFile}.raw`;
  const rawFiles = [];
  const references = [...Object.entries(attempt.files ?? {}), ...(evidence.preparation.receipts ?? []).map((receipt) => [receipt.name, receipt.log])];
  for (const [name, reference] of references) {
    for (const item of Array.isArray(reference) ? reference : [reference]) {
      const file = confinedFile(rawBase, item);
      if (!file || fileHash(file) !== item.sha256) throw new Error(`halted 253-40 raw readback differs: ${name}`);
      rawFiles.push(`${LOAD_R2_HALTED.evidence.file}.raw/${item.path}`);
    }
  }
  for (const revision of evidence.preserved_revisions ?? []) {
    if (sha256(readGitBlob(root, revision.ref)) !== revision.sha256) throw new Error(`halted 253-40 preserved revision readback differs: ${revision.ref}`);
  }
  const debugHash = fileHash(path.join(root, LOAD_R2_DEBUG_PATH));
  if (!debugHash) throw new Error('the resolved host-sleep root-cause record is missing');
  const fixCommit = run('git', ['-C', root, 'rev-parse', '--verify', `${LOAD_R2_FIX_COMMIT_PREFIX}^{commit}`]);
  if (fixCommit.status !== 0 || run('git', ['-C', root, 'merge-base', '--is-ancestor', fixCommit.stdout.trim(), 'HEAD']).status !== 0) throw new Error('the host-sleep fix commit is not an ancestor of this checkout');
  const haltedBlobs = haltedFreeze.source?.blobs ?? {};
  for (const blob of Object.values(haltedBlobs)) {
    if (run('git', ['-C', root, 'cat-file', '-t', blob]).stdout.trim() !== 'blob') throw new Error(`halted 253-40 frozen blob is not retrievable: ${blob}`);
  }
  const charges = [...v1.charges, evidence.preparation.duration_ms, attempt.charged_duration_ms];
  const ledger = buildLoadRecoveryLedgerR2({
    charges, physicalPlaywrightLaunches: limits.physical_playwright_cli_launches, spentReservations: limits.used_slots,
    retryUsed: limits.retry_used, retryAvailable: limits.retry_available, preparationUsedMs: v1.charges[1] + evidence.preparation.duration_ms
  });
  const infrastructureHalt = {
    slot_id: attempt.slot_id, cause: 'host_sleep', retryable: false, charged_ms: attempt.charged_duration_ms, preparation_ms: evidence.preparation.duration_ms,
    fix_commit: fixCommit.stdout.trim(), root_cause: { file: LOAD_R2_DEBUG_PATH, sha256: debugHash }
  };
  const lineage = [LOAD_R2_HALTED.evidence.file, LOAD_R2_HALTED.freeze.file, LOAD_R2_DEBUG_PATH, LOAD_R2_BUDGET_PATH, ...rawFiles];
  const artifacts = [...v1.artifacts, ...lineage.map((file) => ({ path: file, sha256: fileHash(path.join(root, file)) }))];
  if (artifacts.some((item) => !item.sha256)) throw new Error('an R2 lineage record is missing an exact byte identity');
  return { v1, control: v1.control, ledger, charges, halted: LOAD_R2_HALTED, infrastructureHalt, artifacts, frozenBlobs: { ...v1.frozenBlobs, halted_253_40: haltedBlobs } };
}

export function verifyFrozenSourceBindingR2(root, freeze, { terminal = false } = {}) {
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const frozen = freeze?.source?.checkout_head;
  if (!frozen || run('git', ['-C', root, 'merge-base', '--is-ancestor', frozen, head]).status !== 0) throw new Error('frozen R2 source commit is not an ancestor of this checkout');
  const fixed = freeze.fixed_runner?.commit;
  if (!fixed || run('git', ['-C', root, 'merge-base', '--is-ancestor', fixed, frozen]).status !== 0) throw new Error('the fixed runner commit is not an ancestor of the frozen R2 source commit');
  for (const [file, expected] of Object.entries(freeze.source.blobs ?? {})) {
    if (terminal) {
      // Accepted evidence stays verifiable after later committed runner changes: bind by git objects, not the working tree.
      const blob = run('git', ['-C', root, 'rev-parse', `${frozen}:${file}`]);
      if (blob.status !== 0 || blob.stdout.trim() !== expected || run('git', ['-C', root, 'cat-file', '-t', expected]).stdout.trim() !== 'blob') throw new Error(`frozen R2 source blob mismatch at the frozen commit for ${file}`);
    } else if (git(['-C', root, 'hash-object', file]) !== expected) throw new Error(`frozen R2 source identity mismatch for ${file}`);
  }
  return head;
}

function verifyFrozenHistoryBindingR2(root, freeze, { terminal = false } = {}) {
  const frozen = freeze.source.checkout_head;
  for (const artifact of freeze.historical?.artifacts ?? []) {
    const actual = terminal ? sha256(readFrozenBytesR2(root, frozen, artifact.path)) : fileHash(path.join(root, artifact.path));
    if (actual !== artifact.sha256) throw new Error(`preserved R2 history changed: ${artifact.path}`);
  }
  const budget = terminal ? sha256(readFrozenBytesR2(root, frozen, LOAD_R2_BUDGET_PATH)) : fileHash(path.join(root, LOAD_R2_BUDGET_PATH));
  if (freeze.budget?.file !== LOAD_R2_BUDGET_PATH || !budget || freeze.budget.sha256 !== budget) throw new Error('the R2 budget document differs from the frozen binding');
}

function canonicalLedgerR2(freeze) {
  return buildLoadRecoveryLedgerR2({
    charges: freeze.historical?.carried_components_ms, physicalPlaywrightLaunches: freeze.historical?.physical_playwright_cli_launches,
    spentReservations: freeze.historical?.spent_reservations, retryUsed: freeze.historical?.spent_retry?.used,
    retryAvailable: freeze.historical?.spent_retry?.available, preparationUsedMs: 4398
  });
}

export function createLoadRecoveryFreezeR2(outputFile, root = ROOT) {
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite the additive R2 load recovery freeze');
  if (process.version !== LOAD_NODE) throw new Error(`load recovery must be frozen under Node ${LOAD_NODE}`);
  assertRevisionCheckout(root);
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const history = readLoadHistoryR2(root);
  for (const artifact of history.artifacts) {
    if (sha256(readFrozenBytesR2(root, head, artifact.path)) !== artifact.sha256) throw new Error(`R2 lineage record is not committed at HEAD: ${artifact.path}`);
  }
  const files = loadSourceFileList(root);
  const blobs = Object.fromEntries(files.map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`])]));
  const freeze = {
    schema_version: LOAD_R2_FREEZE_SCHEMA, status: 'frozen_before_results', plan: '253-48', revision: 'r2', frozen_at: new Date().toISOString(),
    source: { repository: 'szTheory/sigra', checkout_head: head, blobs },
    fixed_runner: { commit: history.infrastructureHalt.fix_commit, blob: blobs['scripts/ci/ci-registration-recovery.mjs'] },
    runtime: loadRuntimeIdentity(root),
    historical: {
      artifacts: history.artifacts, frozen_blob_sets: history.frozenBlobs, carried_charge_ms: history.ledger.prior_charge_ms,
      carried_components_ms: history.charges, physical_playwright_cli_launches: 6, spent_reservations: [...LOAD_R2_SPENT],
      spent_retry: { used: 1, available: 0 }, infrastructure_halt: history.infrastructureHalt,
      halted_lineage: { evidence: { ...LOAD_R2_HALTED.evidence }, freeze: { ...LOAD_R2_HALTED.freeze } }
    },
    budget: { file: LOAD_R2_BUDGET_PATH, sha256: fileHash(path.join(root, LOAD_R2_BUDGET_PATH)), grants_capacity: false },
    ledger: history.ledger,
    selection: {
      spec: 'tests/admin-eval.spec.ts', config: path.basename(LOAD_RECOVERY_CONFIG), original_title: CONTROL_BOARD_TITLE,
      first_titles: FIRST_CONTROLS, second_titles: CONTROL_SECOND_ACTIVE, deliberate_expected_failure_markers: CONTROL_EXPECTED_FAILURE_MARKERS,
      cli_grep_forbidden: true, workers: 1, fully_parallel: false, retries: 0, trace: 'retain-on-failure'
    },
    tools: {
      node: process.version, expected_node: LOAD_NODE, playwright: '1.59.1', parse5: '8.0.1',
      mix: history.control.accepted.toolchain.mix, ecto_sql: history.control.accepted.toolchain.ecto_sql, phoenix_live_view: history.control.accepted.toolchain.phoenix_live_view
    },
    exclusions: ['no browser installation', 'no hidden --list or version CLI', 'no warmup', 'no duplicate full suite', 'no reuse of any of the seven spent identities', 'no native or hosted work without a committed Jon approval record', 'no capacity granted by this freeze'],
    stop_conditions: ['source or history digest mismatch', 'unexpected assertion or missing native report', 'database drop/build cleanup/report/trace sanitation failure', 'command exceeds 120000 ms', 'host suspension detected', 'stalled owned process group remains alive', 'AC power, caffeinate holder or pmset assertion proof missing before predebit']
  };
  freeze.freeze_sha256 = loadFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return freeze;
}

export function validateLoadRecoveryFreezeR2(root, freeze, { terminal = false } = {}) {
  assertDirtyConfigPreserved(root);
  if (freeze?.schema_version !== LOAD_R2_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== loadFreezeDigest(freeze)) throw new Error('R2 native load recovery freeze is malformed or its digest is invalid');
  const head = verifyFrozenSourceBindingR2(root, freeze, { terminal });
  for (const required of [...SOURCE_FILES, ...LOAD_EXTRA_SOURCES]) if (!freeze.source.blobs?.[required]) throw new Error(`freeze omits required source ${required}`);
  if (!terminal) for (const file of discoverLoadImportClosure(root)) if (!freeze.source.blobs?.[file]) throw new Error(`freeze omits actual imported runtime source ${file}`);
  verifyFrozenHistoryBindingR2(root, freeze, { terminal });
  if (JSON.stringify(freeze.ledger) !== JSON.stringify(canonicalLedgerR2(freeze))) throw new Error('frozen R2 ledger differs from the reviewed carried allocation');
  for (const slot of freeze.ledger.slots.slice(0, 4)) if (slot.argv.some((arg) => /^(-g|--grep)(=|$)/.test(arg))) throw new Error('frozen argv carries a CLI grep that would override per-project selection');
  if (!terminal) {
    if (JSON.stringify(freeze.runtime) !== JSON.stringify(loadRuntimeIdentity(root))) throw new Error('locked/installed runtime or pinned transform identity changed');
    const history = readLoadHistoryR2(root);
    if (JSON.stringify(history.ledger) !== JSON.stringify(freeze.ledger)) throw new Error('re-read 253-40 lineage differs from the frozen R2 ledger');
    if (JSON.stringify(history.infrastructureHalt) !== JSON.stringify(freeze.historical.infrastructure_halt)) throw new Error('re-read host-sleep halt record differs from the frozen record');
  }
  return head;
}

function checkLoadRecoveryFreezeFileR2(freezeFile, root = ROOT) {
  try {
    if (path.resolve(freezeFile) !== path.resolve(root, LOAD_R2_FREEZE_PATH)) throw new Error('freeze check accepts only the additive R2 path');
    validateLoadRecoveryFreezeR2(root, readJson(freezeFile));
    console.log('R2 native load recovery freeze verified: fixed runner pinned, 253-40 lineage re-hashed, 2042596 ms/6 launches/7 spent carried, 22 rows, no capacity granted');
    return { ok: true, errors: [] };
  } catch (error) {
    console.error(`R2 native load recovery freeze rejected: ${error.message}`);
    return { ok: false, errors: [error.message] };
  }
}

export function recordBudgetApproval({ decision, budgetFile, freezeFile, outputFile, decisionText }, root = ROOT, { enforcePaths = true, now = () => new Date().toISOString() } = {}) {
  if (!Object.hasOwn(LOAD_R2_CAP_TABLE, decision ?? '')) throw new Error(`decision ${JSON.stringify(decision)} grants no capacity: only approve or approve-without-retry are recorded`);
  if (typeof decisionText !== 'string' || !decisionText.trim()) throw new Error('the approval record needs Jon\'s decision text verbatim');
  if (enforcePaths && (path.resolve(budgetFile) !== path.resolve(root, LOAD_R2_BUDGET_PATH) || path.resolve(freezeFile) !== path.resolve(root, LOAD_R2_FREEZE_PATH)
    || path.resolve(outputFile) !== path.resolve(root, LOAD_R2_APPROVAL_PATH))) throw new Error('budget approval must use the reviewed R2 budget, freeze and approval paths');
  const freeze = readJson(freezeFile);
  if (enforcePaths) validateLoadRecoveryFreezeR2(root, freeze);
  const budgetHash = fileHash(budgetFile);
  if (!budgetHash || freeze.budget?.sha256 !== budgetHash) throw new Error('the R2 budget document differs from the freeze binding');
  const record = {
    schema_version: LOAD_R2_APPROVAL_SCHEMA, decision, decided_by: 'Jon (operator), recorded by executor from checkpoint response', decision_text: decisionText,
    budget_sha256: budgetHash, freeze_sha256: fileHash(freezeFile), caps: { ...LOAD_R2_CAP_TABLE[decision] }, retry_granted: decision === 'approve' ? 1 : 0, recorded_at: now()
  };
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, `${JSON.stringify(record, null, 2)}\n`, { flag: 'wx' });
  return record;
}

// Capacity is usable only through a record that is committed in HEAD and bound to this budget document and freeze.
export function readCommittedApproval(root, freezeFile, freeze) {
  const file = path.join(root, LOAD_R2_APPROVAL_PATH);
  if (!fs.existsSync(file)) throw new Error('R2 budget approval record is absent: capacity exists only after Jon\'s decision is recorded');
  const tracked = run('git', ['-C', root, 'ls-files', '--error-unmatch', '--', LOAD_R2_APPROVAL_PATH]);
  const inHead = run('git', ['-C', root, 'cat-file', '-e', `HEAD:${LOAD_R2_APPROVAL_PATH}`]);
  if (tracked.status !== 0 || inHead.status !== 0) throw new Error('R2 budget approval record is not committed in HEAD');
  const bytes = fs.readFileSync(file);
  if (!bytes.equals(readGitBlob(root, `HEAD:${LOAD_R2_APPROVAL_PATH}`))) throw new Error('R2 budget approval record differs from its committed bytes');
  const record = JSON.parse(bytes.toString('utf8'));
  if (record.schema_version !== LOAD_R2_APPROVAL_SCHEMA || !Object.hasOwn(LOAD_R2_CAP_TABLE, record.decision ?? '')) throw new Error('R2 budget approval record is malformed or carries an unrecognised decision');
  const budgetHash = fileHash(path.join(root, LOAD_R2_BUDGET_PATH));
  if (!budgetHash || record.budget_sha256 !== budgetHash || freeze?.budget?.sha256 !== budgetHash) throw new Error('R2 budget approval is not bound to the frozen budget document hash');
  if (record.freeze_sha256 !== fileHash(freezeFile)) throw new Error('R2 budget approval is not bound to this freeze file hash');
  if (JSON.stringify(record.caps) !== JSON.stringify(LOAD_R2_CAP_TABLE[record.decision]) || record.retry_granted !== (record.decision === 'approve' ? 1 : 0)) throw new Error('R2 budget approval caps differ from the reviewed table');
  return record;
}

export function readCommittedDiagnostic(root, file) {
  if (!file || typeof file !== 'string') throw new Error('infrastructure retry requires --diagnostic <committed diagnostic file>');
  const relative = path.isAbsolute(file) ? path.relative(root, file) : path.normalize(file);
  if (relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('the infrastructure diagnostic must live inside the checkout');
  const tracked = run('git', ['-C', root, 'ls-files', '--error-unmatch', '--', relative]);
  const inHead = run('git', ['-C', root, 'cat-file', '-e', `HEAD:${relative}`]);
  if (tracked.status !== 0 || inHead.status !== 0 || !fs.existsSync(path.join(root, relative))) throw new Error(`the infrastructure diagnostic is not committed in HEAD: ${relative}`);
  const bytes = fs.readFileSync(path.join(root, relative));
  if (!bytes.equals(readGitBlob(root, `HEAD:${relative}`))) throw new Error(`the infrastructure diagnostic differs from its committed bytes: ${relative}`);
  return { file: relative, sha256: sha256(bytes) };
}

function processAlive(pid) {
  try { process.kill(pid, 0); return true; } catch (cause) { return cause.code === 'EPERM'; }
}

function pmsetAssertionNames(text, pid) {
  const names = [];
  for (const match of String(text).matchAll(/^\s*pid\s+(\d+)\([^)]*\):\s*\[[^\]]*\]\s+\S+\s+(\w+)\s+named:/gm)) {
    if (Number(match[1]) === pid) names.push(match[2]);
  }
  return names;
}

// Native windows must not start unless the host is provably kept awake (253-40 lost ~29 minutes to
// maintenance sleep): AC power (caffeinate -s only applies on AC), the runner-owned holder alive, and
// pmset listing that holder with both sleep-prevention assertions. A failure releases the holder and throws.
export async function probeHostSleepSafety({
  platform = process.platform, pmset = (args) => run('/usr/bin/pmset', args, { timeout: 5000 }), holdAwake = holdHostAwake,
  isAlive = processAlive, now = Date.now, sleep = (ms) => new Promise((resolve) => { setTimeout(resolve, ms); }), waitMs = 3000, pollMs = 250
} = {}) {
  if (platform !== 'darwin') throw new Error('R2 native windows require a macOS (darwin) host: AC power and sleep assertions cannot be proven here');
  const battery = pmset(['-g', 'batt']);
  if (battery.status !== 0 || !/Now drawing from 'AC Power'/.test(battery.stdout ?? '')) throw new Error('R2 native windows require AC power (caffeinate -s only applies on AC); pmset -g batt did not report AC Power');
  const awake = holdAwake();
  const fail = (message) => { awake.release(); throw new Error(message); };
  if (!awake.held || !Number.isInteger(awake.pid)) fail('the runner-owned caffeinate sleep-assertion holder was not started');
  if (!isAlive(awake.pid)) fail('the runner-owned caffeinate holder is not running');
  const started = now();
  let text = '';
  for (;;) {
    const result = pmset(['-g', 'assertions']);
    text = result.stdout ?? '';
    const names = pmsetAssertionNames(text, awake.pid);
    const missing = ['PreventSystemSleep', 'PreventUserIdleSystemSleep'].filter((name) => !names.includes(name));
    if (result.status === 0 && !missing.length) break;
    if (now() - started >= waitMs) fail(`pmset -g assertions does not list the holder pid ${awake.pid} with ${missing.join(' and ')}`);
    await sleep(pollMs);
  }
  if (!isAlive(awake.pid)) fail('the runner-owned caffeinate holder is not running');
  return { awake, host_awake: { holder_pid: awake.pid, ac_power: true, assertions_sha256: sha256(text), checked_at: new Date().toISOString() } };
}

export async function preflightHostSleep(options = {}) {
  const { awake, host_awake: hostAwake } = await probeHostSleepSafety(options);
  awake.release();
  return JSON.stringify(hostAwake);
}


export function initializeLoadRecoveryEvidenceR2(freezeFile, evidenceFile, root = ROOT, deps = {}) {
  const d = { validate: validateLoadRecoveryFreezeR2, readApproval: readCommittedApproval, ...deps };
  if (fs.existsSync(evidenceFile)) throw new Error('refusing to overwrite additive R2 native load recovery evidence');
  const freeze = readJson(freezeFile);
  d.validate(root, freeze);
  const approval = d.readApproval(root, freezeFile, freeze);
  const caps = LOAD_R2_CAP_TABLE[approval.decision];
  const evidence = {
    schema_version: LOAD_R2_SCHEMA, revision: 'r2', status: 'ready',
    freeze_path: path.relative(root, freezeFile), freeze_sha256: fileHash(freezeFile),
    source: structuredClone(freeze.source), historical: structuredClone(freeze.historical),
    created_at: new Date().toISOString(), attempts: [], preparation: null, reservation: null, preserved_revisions: [],
    infrastructure_halts: [structuredClone(freeze.historical.infrastructure_halt)], infrastructure_retry: null,
    approval: { decision: approval.decision, retry_granted: approval.retry_granted },
    limits: {
      prior_charge_ms: freeze.ledger.prior_charge_ms, preparation_charge_ms: 0, preparation_remaining_ms: freeze.ledger.preparation_reserve_ms,
      charged_duration_ms: freeze.ledger.prior_charge_ms, physical_playwright_cli_launches: freeze.ledger.prior_playwright_cli_launches,
      used_slots: [...freeze.ledger.spent_reservations], max_d19_ms: caps.d19_cap_ms, max_total_ms: caps.shared_cap_ms,
      max_d19_physical_playwright_cli_launches: caps.d19_launch_max, max_physical_playwright_cli_launches: caps.physical_cli_max,
      retry_used: 1, retry_available: 0, infra_retry: { granted: approval.retry_granted, used: 0 }
    }
  };
  fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  writeJson(evidenceFile, evidence);
  return evidence;
}

export async function prepareLoadRecoveryR2(freezeFile, evidenceFile, root = ROOT, deps = {}) {
  const d = { validate: validateLoadRecoveryFreezeR2, readApproval: readCommittedApproval, runTree: runLoggedTree, ...deps };
  const freeze = readJson(freezeFile);
  d.validate(root, freeze);
  d.readApproval(root, freezeFile, freeze);
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== LOAD_R2_SCHEMA || evidence.freeze_sha256 !== fileHash(freezeFile)) throw new Error('evidence does not match the committed R2 freeze');
  if (evidence.status !== 'ready' || evidence.reservation || evidence.preparation) throw new Error('preparation is only available once, from ready evidence');
  if (evidence.attempts.length || evidence.limits.physical_playwright_cli_launches !== freeze.ledger.prior_playwright_cli_launches) throw new Error('preparation must precede every new native command');
  const reserve = evidence.limits.preparation_remaining_ms;
  evidence.status = 'running';
  evidence.reservation = { kind: 'preparation', reserved_ms: reserve, predebited_at: new Date().toISOString() };
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  const dir = path.join(`${evidenceFile}.raw`, 'preparation'); fs.mkdirSync(dir, { recursive: true });
  const exampleDir = path.join(root, 'test/example'); const env = { ...process.env, MIX_ENV: 'dev' };
  const commands = [['mix_version', 'mix', ['--version']], ['host_dependency_versions', 'mix', ['deps']]];
  const started = process.hrtime.bigint(); const receipts = []; let failed = null;
  for (const [name, program, args] of commands) {
    const remaining = reserve - Math.ceil(Number(process.hrtime.bigint() - started) / 1e6);
    if (remaining <= 0) { failed = 'preparation reached its predebited allowance'; break; }
    const log = path.join(dir, `${name}.log`);
    const result = await d.runTree(program, args, exampleDir, env, log, remaining);
    receipts.push({ name, argv: [program, ...args], exit_code: result.exit_code, duration_ms: result.duration_ms, log: referenceFor(`${evidenceFile}.raw`, log) });
    if (result.exit_code !== 0 || result.timed_out) { failed = `${name} failed`; break; }
  }
  const duration = Math.ceil(Number(process.hrtime.bigint() - started) / 1e6);
  evidence.reservation = null; evidence.preparation = { receipts, duration_ms: duration, status: failed ? 'failed' : 'passed' };
  evidence.limits.preparation_charge_ms = duration; evidence.limits.preparation_remaining_ms = Math.max(0, reserve - duration);
  evidence.limits.charged_duration_ms += duration;
  evidence.status = failed || duration > reserve ? 'halted' : 'ready';
  if (evidence.status === 'halted') evidence.stop_reason = failed ?? 'preparation exceeded its allowance';
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  if (evidence.status === 'halted') throw new Error(evidence.stop_reason);
  return { status: evidence.status, preparation_charge_ms: duration };
}

function loadR2AcceptedAttempts(evidence) {
  return evidence.attempts.filter((attempt) => attempt.observed_outcome === 'native_rows_accepted');
}

export async function runLoadRecoverySlotR2(freezeFile, slotId, evidenceFile, root = ROOT, deps = {}) {
  const d = {
    validate: validateLoadRecoveryFreezeR2, runTree: runLoggedTree, spawnApp: spawn, waitReady, portAvailable, stopApp,
    probeHost: probeHostSleepSafety, readApproval: readCommittedApproval, checkDiagnostic: readCommittedDiagnostic, holderAlive: processAlive, diagnosticFile: null,
    captureAbsence: captureOwnedDatabaseAbsence, captureAccount: captureOwnedAccountCount, sanitizeTrace: sanitizeTraceFile,
    skipPreservation: false, enforcePaths: true, enforceNode: true, ...deps
  };
  if (LOAD_R2_SPENT.includes(slotId)) throw new Error(`reservation ${slotId} is permanently spent and cannot be run or retried`);
  if (d.enforcePaths && (path.resolve(freezeFile) !== path.resolve(root, LOAD_R2_FREEZE_PATH) || path.resolve(evidenceFile) !== path.resolve(root, LOAD_R2_EVIDENCE_PATH))) throw new Error('R2 load recovery accepts only the reviewed R2 freeze and additive R2 evidence paths');
  if (d.enforceNode && process.version !== LOAD_NODE) throw new Error(`load recovery native commands require Node ${LOAD_NODE}`);
  const freeze = readJson(freezeFile);
  const freezeHash = fileHash(freezeFile);
  const regular = freeze.ledger?.slots?.slice(0, 4) ?? [];
  const isRetry = slotId === LOAD_R2_RETRY_ID;
  let slot = regular.find((item) => item.id === slotId);
  if (!slot && !isRetry) throw new Error('only the four frozen unused R2 load recovery slots and the one infrastructure retry may run');
  d.validate(root, freeze);
  const approval = d.readApproval(root, freezeFile, freeze);
  const caps = Object.hasOwn(LOAD_R2_CAP_TABLE, approval.decision ?? '') ? LOAD_R2_CAP_TABLE[approval.decision] : null;
  if (!caps) throw new Error('budget approval carries an unknown decision');
  if (!fs.existsSync(evidenceFile)) throw new Error('R2 native load recovery evidence must be initialized and committed before launch');
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== LOAD_R2_SCHEMA || evidence.freeze_sha256 !== freezeHash) throw new Error('R2 native load evidence does not match the committed freeze');
  const limits = evidence.limits;
  let diagnostic = null;
  if (isRetry) {
    if (evidence.status !== 'halted_infrastructure' || evidence.reservation) throw new Error(`the infrastructure retry needs halted_infrastructure evidence, found ${evidence.status}`);
    if (limits.used_slots.includes(LOAD_R2_RETRY_ID) || limits.infra_retry?.used !== 0 || evidence.infrastructure_retry?.used || !evidence.infrastructure_retry?.eligible) throw new Error('the infrastructure retry was already used or is not eligible');
    if (approval.retry_granted !== 1 || limits.infra_retry.granted !== 1) throw new Error('the approved budget grants no infrastructure retry');
    slot = loadR2EffectiveRetrySlot(freeze.ledger.slots, evidence.infrastructure_retry.halted_slot);
  } else {
    if (!['ready', 'first_complete', 'second_partial'].includes(evidence.status) || evidence.reservation) throw new Error(`refusing to use terminal or reserved R2 recovery evidence: ${evidence.status}`);
    if (limits.used_slots.includes(slot.id)) throw new Error(`reservation ${slot.id} was already consumed`);
  }
  if (limits.retry_used !== 1 || limits.retry_available !== 0 || limits.prior_charge_ms !== freeze.ledger.prior_charge_ms
    || limits.charged_duration_ms < freeze.ledger.prior_charge_ms) throw new Error('counter reset or reopened retry detected before setup');
  if (limits.max_d19_ms !== Math.min(caps.d19_cap_ms, freeze.ledger.caps.approve.d19_cap_ms) || limits.max_total_ms !== Math.min(caps.shared_cap_ms, freeze.ledger.caps.approve.shared_cap_ms)
    || limits.max_physical_playwright_cli_launches !== caps.physical_cli_max) throw new Error('approval caps differ from the evidence ledger');
  const accepted = loadR2AcceptedAttempts(evidence);
  const nextSlot = regular[accepted.length];
  if (!nextSlot || nextSlot.id !== (isRetry ? slot.retry_of : slot.id)) throw new Error('slots must run in frozen order, each exactly once');
  if (isRetry) {
    // Checked after the free refusals above and before any spawn or charge.
    diagnostic = d.checkDiagnostic(root, d.diagnosticFile);
  }
  const reserve = slot.max_duration_ms;
  const remaining = regular.length - accepted.length;
  const retryReserved = !isRetry && approval.retry_granted === 1 && limits.infra_retry?.used === 0 ? 1 : 0;
  if (reserve !== PROJECT_SLOT_MS
    || limits.charged_duration_ms + limits.preparation_remaining_ms + remaining * reserve + retryReserved * reserve > limits.max_d19_ms
    || limits.physical_playwright_cli_launches + remaining + retryReserved > limits.max_d19_physical_playwright_cli_launches
    || limits.charged_duration_ms + limits.preparation_remaining_ms + (remaining + retryReserved) * reserve + 9 * 240000 + 3 * 60000 > limits.max_total_ms
    || limits.physical_playwright_cli_launches + remaining + retryReserved + 9 > limits.max_physical_playwright_cli_launches) throw new Error('remaining D-19 and conditional D-20 reservations do not fit approved limits');
  if (!(await d.portAvailable(slot.port))) throw new Error(`frozen port ${slot.port} is occupied before native setup`);
  const project = PROJECTS.find((item) => item.name === slot.project);
  // The host proof runs before the predebit so an unsafe host costs no reservation.
  const { awake, host_awake: hostAwake } = await d.probeHost();
  try {
    return await runHeldLoadRecoverySlotR2({ d, root, freeze, slot, evidence, evidenceFile, reserve, project, awake, hostAwake, diagnostic });
  } finally { awake.release(); }
}

function loadR2AssertionFailure(slot, tests) {
  return loadRequiredPairs(slot).some((pair) => {
    const expected = slot.project_selections.find((item) => item.project === pair.project).expected[pair.title];
    const found = tests.filter((item) => item.title === pair.title && item.project === pair.project);
    if (found.length !== 1) return false;
    return expected === 'expected_failure' ? found[0].status === 'passed' : found[0].status !== 'passed';
  });
}

async function runHeldLoadRecoverySlotR2({ d, root, freeze, slot, evidence, evidenceFile, reserve, project, awake, hostAwake, diagnostic }) {
  const rawDir = `${evidenceFile}.raw`;
  const rawAttempt = createAttemptDirectory(rawDir, slot.id, 1);
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-load-r2-'));
  const started = process.hrtime.bigint();
  const wallStarted = Date.now();
  const nowMs = () => Number(process.hrtime.bigint()) / 1e6;
  const commandDeadline = Number(started) / 1e6 + reserve;
  const workDeadline = commandDeadline - slot.cleanup_ms;
  const remainingUntil = (offsetMs) => Math.min(Number(started) / 1e6 + offsetMs - nowMs(), wallStarted + offsetMs - Date.now());
  const workRemaining = () => remainingUntil(reserve - slot.cleanup_ms);
  const database = `sigra_253_control_load_${slot.id.toLowerCase().replaceAll('-', '_')}_${Date.now().toString(36)}_${process.pid}`.toLowerCase();
  const env = diagnosticEnvironment(project, database, tempRoot);
  const tempPaths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(tempRoot, `${name.replaceAll('_', '-')}.log`)]));
  const reportTemp = path.join(tempRoot, 'playwright-report.json');
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: slot.project, projects: slot.projects, argv: slot.argv,
    source_commit: freeze.source.checkout_head, source_blobs: freeze.source.blobs, started_monotonic_ns: started.toString(),
    database: { name: database, setup_exit_code: null, drop_exit_code: null, connection: databaseConnectionIdentity(env) },
    server: { port: slot.port, http_status: null, app_pid: null }, browser: { launched: false, exit_code: null },
    playwright_cli: { launched: false, exit_code: null }, lifecycle: { playwright_cli_processes: 0, rows: 0, worker_indexes: [] },
    observed_outcome: 'setup_failed', files: {}, traces: [], registration: { server_post_confirmed: false },
    toolchain: { playwright: null, ecto_sql: freeze.tools.ecto_sql, phoenix_live_view: freeze.tools.phoenix_live_view },
    build_path: env.MIX_BUILD_PATH, stage_deadlines: { command_ms: reserve, work_ms: slot.work_ms, cleanup_ms: slot.cleanup_ms, cleanup_reserved: true },
    host: { platform: awake.platform, sleep_assertion_held: awake.held, sleep_assertion_argv: awake.argv ?? null, suspension_detected: false, holder_alive_at_end: null },
    host_awake: hostAwake, assertion_failure_observed: false, ...(slot.retry ? { retry_of: slot.retry_of } : {})
  };
  evidence.status = 'running';
  evidence.reservation = { slot_id: slot.id, mapped_from: slot.maps_from, reserved_ms: reserve, predebited_at: new Date().toISOString(), source_commit: freeze.source.checkout_head };
  evidence.limits.used_slots.push(slot.id);
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  let app = null; let terminalError = null;
  const playwrightDir = path.join(root, LOAD_PLAYWRIGHT_DIR);
  try {
    const setup = await d.runTree('mix', ['ecto.setup'], path.join(root, 'test/example'), env, tempPaths.setup_log, workRemaining());
    attempt.setup = setup; attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0 || setup.timed_out) throw new Error(`fresh database setup failed${setup.timed_out ? ' at its work deadline' : ` with exit ${setup.exit_code ?? 'null'}`}`);
    const appFd = fs.openSync(tempPaths.app_log, 'w');
    try { app = d.spawnApp('mix', ['phx.server'], { cwd: path.join(root, 'test/example'), env, stdio: ['ignore', appFd, appFd], detached: true }); }
    finally { fs.closeSync(appFd); }
    attempt.server.app_pid = app.pid ?? null;
    attempt.server.http_status = app.pid ? await d.waitReady(app, `http://127.0.0.1:${slot.port}/`, workDeadline) : null;
    if (attempt.server.http_status !== 200) throw new Error('fresh app did not return HTTP 200 before the reserved work deadline');
    const installed = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installed !== freeze.tools.playwright) throw new Error(`installed Playwright ${installed} differs from the frozen ${freeze.tools.playwright}`);
    attempt.toolchain.playwright = installed;
    if (workRemaining() <= 0) throw new Error('the reserved work deadline passed before browser launch');
    if (slot.stage === 'second') {
      const absenceLog = path.join(tempRoot, 'prior-collision-absence.log');
      attempt.prior_collision_absence = d.captureAccount({ database, email: loadControlAccount(slot.project, 'collision'), env, cwd: path.join(root, 'test/example'), log: absenceLog, deadline: workDeadline });
      attempt.files.prior_collision_absence = receiptFile(rawDir, 'prior collision absence', (() => { const target = path.join(rawAttempt, 'prior-collision-absence.log'); fs.copyFileSync(absenceLog, target, fs.constants.COPYFILE_EXCL); return target; })());
      if (attempt.prior_collision_absence.count !== 0) throw new Error('prior collision account is not absent from the newly created database');
    }
    attempt.browser.launched = true; attempt.playwright_cli.launched = true; attempt.lifecycle.playwright_cli_processes = 1;
    const args = ['test', freeze.selection.spec, ...slot.argv, `--output=${path.join(tempRoot, 'playwright-output')}`];
    attempt.browser_command_argv = args;
    const browser = await d.runTree(path.join(playwrightDir, 'node_modules/.bin/playwright'), args, playwrightDir, {
      ...env, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${slot.port}`, SIGRA_PLAYWRIGHT_JSON: reportTemp,
      SIGRA_REGISTRATION_CONTROL_STAGE: slot.control_stage, SIGRA_CONTROL_RUN_ID: `${slot.id.toLowerCase()}-${crypto.randomUUID()}`,
      SIGRA_CONTROL_ACCOUNT_PREFIX: 'platform-admin+sigra-253-control', PLAYWRIGHT_HTML_OUTPUT_DIR: path.join(tempRoot, 'html-report')
    }, tempPaths.test_log, workRemaining());
    attempt.test_command = browser; attempt.browser.exit_code = browser.exit_code; attempt.playwright_cli.exit_code = browser.exit_code; attempt.lifecycle.cli_pid = browser.pid ?? null;
    if (browser.timed_out) throw new Error('native Playwright command reached the reserved work deadline');
    if (!fs.existsSync(reportTemp) || fs.statSync(reportTemp).size === 0) throw new Error('native Playwright JSON report is absent or empty');
    const report = readJson(reportTemp);
    const tests = playReportTests(report);
    attempt.assertion_failure_observed = loadR2AssertionFailure(slot, tests);
    for (const item of tests) for (const attachment of item.attachments ?? []) {
      if (attachment.name !== 'trace' && !String(attachment.path ?? '').endsWith('trace.zip')) continue;
      if (!attachment.path || !fs.existsSync(attachment.path)) throw new Error(`native trace attachment for ${item.title} is missing`);
      const target = path.join(rawAttempt, `trace-${attempt.traces.length + 1}.zip`);
      const trace = d.sanitizeTrace(attachment.path, target);
      attempt.traces.push({ ...receiptFile(rawDir, 'sanitized native trace', target), title: item.title, project: item.project, sanitization: trace });
      attachment.path = path.relative(root, target);
    }
    attempt.files.traces = attempt.traces;
    const safeReport = path.join(rawAttempt, 'playwright-report.json');
    fs.writeFileSync(safeReport, `${JSON.stringify(sanitizeReportText(report), null, 2)}\n`, { flag: 'wx' });
    attempt.files.playwright_report = receiptFile(rawDir, 'sanitized native Playwright report', safeReport);
    attempt.lifecycle.rows = tests.length;
    attempt.lifecycle.worker_indexes = [...new Set(tests.flatMap((item) => (Number.isInteger(item.worker_index) ? [item.worker_index] : [])))].sort((a, b) => a - b);
    attempt.lifecycle.context_ids = tests.flatMap((item) => controlAnnotations(item, 'sigra-registration-control-context'));
    attempt.lifecycle.projects_run = [...new Set(tests.map((item) => item.project))];
    attempt.registration.server_post_confirmed = /POST \/users\/log_in/.test(fs.existsSync(tempPaths.app_log) ? fs.readFileSync(tempPaths.app_log, 'utf8') : '');
    if (slot.stage === 'second') {
      const createdLog = path.join(tempRoot, 'created-account.log');
      attempt.created_account = d.captureAccount({ database, email: loadControlAccount(slot.project, 'collision'), env, cwd: path.join(root, 'test/example'), log: createdLog, deadline: commandDeadline - slot.cleanup_ms + 5000 });
      attempt.files.created_account = receiptFile(rawDir, 'created account', (() => { const target = path.join(rawAttempt, 'created-account.log'); fs.copyFileSync(createdLog, target, fs.constants.COPYFILE_EXCL); return target; })());
    }
    attempt.observed_outcome = 'native_report_pending_validation';
  } catch (error) { terminalError = error.message; }
  finally {
    await d.stopApp(app);
    if (fs.existsSync(tempPaths.app_log)) attempt.log_redactions_app = sanitizeCommandLog(tempPaths.app_log);
    const cleanupRemaining = remainingUntil(reserve);
    if (cleanupRemaining <= 0) terminalError = [terminalError, 'owned cleanup exceeded the 120,000 ms command limit'].filter(Boolean).join('; ');
    const drop = await d.runTree('mix', ['ecto.drop', '--quiet'], path.join(root, 'test/example'), env, tempPaths.drop_log, Math.max(LOAD_DROP_FLOOR_MS, Math.min(7000, cleanupRemaining - 5000)));
    attempt.database.drop_exit_code = drop.exit_code; attempt.drop_command = drop;
    if (drop.exit_code !== 0 || drop.timed_out) terminalError = [terminalError, `database drop failed${drop.timed_out ? ' at cleanup deadline' : ` with exit ${drop.exit_code ?? 'null'}`}`].filter(Boolean).join('; ');
    if (drop.exit_code === 0 && !drop.timed_out) {
      try { attempt.database.absence_receipt = d.captureAbsence({ database, env, cwd: path.join(root, 'test/example'), log: path.join(tempRoot, 'database-absence.log'), deadline: Math.max(commandDeadline, nowMs() + LOAD_ABSENCE_FLOOR_MS) }); }
      catch (error) { terminalError = [terminalError, `independent database absence query failed: ${error.message}`].filter(Boolean).join('; '); }
    }
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    if (!fs.existsSync(tempPaths[name])) fs.writeFileSync(tempPaths[name], `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    const target = path.join(rawAttempt, `${name.replaceAll('_', '-')}.log`);
    fs.copyFileSync(tempPaths[name], target, fs.constants.COPYFILE_EXCL);
    attempt.files[name] = receiptFile(rawDir, `sanitized ${name}`, target);
  }
  const absenceTemp = path.join(tempRoot, 'database-absence.log');
  if (fs.existsSync(absenceTemp)) {
    const target = path.join(rawAttempt, 'database-absence.log');
    fs.copyFileSync(absenceTemp, target, fs.constants.COPYFILE_EXCL);
    attempt.files.database_absence = receiptFile(rawDir, 'owned database absence query log', target);
  }
  attempt.ended_monotonic_ns = process.hrtime.bigint().toString();
  attempt.execution_duration_ms = Math.ceil(Number(BigInt(attempt.ended_monotonic_ns) - BigInt(attempt.started_monotonic_ns)) / 1e6);
  attempt.wall_duration_ms = Math.ceil(Date.now() - wallStarted);
  attempt.charged_duration_ms = Math.max(attempt.execution_duration_ms, attempt.wall_duration_ms);
  attempt.host.suspension_detected = [attempt.setup, attempt.test_command, attempt.drop_command].some((result) => result?.suspended === true)
    || Math.abs(attempt.wall_duration_ms - attempt.execution_duration_ms) > TREE_SUSPEND_GAP_MS;
  if (attempt.host.suspension_detected) terminalError = [terminalError, 'host suspension (system sleep or a stalled runner event loop) was detected during the native window, so its timings cannot be accepted'].filter(Boolean).join('; ');
  attempt.host.holder_alive_at_end = Number.isInteger(hostAwake?.holder_pid) ? Boolean(d.holderAlive(hostAwake.holder_pid)) : null;
  if (attempt.host.holder_alive_at_end === false) terminalError = [terminalError, 'the caffeinate sleep-assertion holder was lost during the native window (holder not running), so sleep was no longer prevented'].filter(Boolean).join('; ');
  if (attempt.charged_duration_ms > reserve) terminalError = [terminalError, 'native command exceeded its frozen 120,000 ms command reservation'].filter(Boolean).join('; ');
  const validation = verifyNativeLoadAttemptR2(attempt, freeze, rawDir);
  if (!validation.ok) terminalError = [terminalError, ...validation.errors].filter(Boolean).join('; ');
  evidence.reservation = null;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  if (attempt.playwright_cli.launched) evidence.limits.physical_playwright_cli_launches += 1;
  evidence.attempts.push(attempt);
  if (slot.retry) {
    evidence.limits.infra_retry.used = 1;
    evidence.infrastructure_retry = { ...evidence.infrastructure_retry, used: true, diagnostic };
  }
  if (terminalError) {
    // Only a host fault (suspension, lost caffeinate holder, host failure before any test ran) with no observed
    // assertion failure is infrastructure, and only the first one is retry-eligible; everything else is terminal.
    const cause = attempt.host.suspension_detected ? 'host_sleep'
      : attempt.host.holder_alive_at_end === false ? 'holder_lost'
        : (attempt.lifecycle.rows === 0 && attempt.setup?.error ? 'host_failure' : null);
    const retryable = Boolean(cause) && !attempt.assertion_failure_observed && !slot.retry
      && evidence.approval?.retry_granted === 1 && evidence.limits.infra_retry?.used === 0;
    if (cause) evidence.infrastructure_halts.push({ slot_id: slot.id, cause, retryable, charged_ms: attempt.charged_duration_ms, assertion_failure_observed: attempt.assertion_failure_observed });
    evidence.stop_reason = terminalError;
    if (retryable) {
      evidence.status = 'halted_infrastructure'; attempt.observed_outcome = 'halted_infrastructure';
      evidence.infrastructure_retry = { eligible: true, halted_slot: slot.id, cause, used: false, diagnostic: null };
    } else { evidence.status = 'halted'; attempt.observed_outcome = 'halted'; }
  } else {
    attempt.observed_outcome = 'native_rows_accepted';
    const count = loadR2AcceptedAttempts(evidence).length;
    evidence.status = count === 4 ? 'complete' : count === 1 ? 'first_complete' : 'second_partial';
  }
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  fs.rmSync(tempRoot, { recursive: true, force: true });
  if (terminalError) throw new Error(terminalError);
  return { status: evidence.status, slot: slot.id, rows: attempt.lifecycle.rows, charged_duration_ms: attempt.charged_duration_ms, physical_playwright_cli_launches: evidence.limits.physical_playwright_cli_launches };
}

function verifyHostAwakeR2(attempt) {
  const errors = [];
  const proof = attempt?.host_awake;
  if (!proof || !Number.isInteger(proof.holder_pid) || proof.ac_power !== true || !/^[0-9a-f]{64}$/.test(proof.assertions_sha256 ?? '') || typeof proof.checked_at !== 'string') {
    errors.push('R2 attempt receipt lacks its host_awake proof (AC power, caffeinate holder and pmset assertion snapshot hash)');
  }
  if (attempt?.host?.suspended === true) errors.push('R2 attempt receipt records a suspended host');
  return errors;
}

// An accepted R2 attempt: the Plan 39 predicates, judged against the effective slot (a retry carries the halted slot's selection),
// plus the host-awake proof. The charge must stay max(execution, wall), which the Plan 39 predicates already enforce.
export function verifyNativeLoadAttemptR2(attempt, freeze, baseDir) {
  const errors = [];
  let effective = freeze;
  if (attempt?.slot_id === LOAD_R2_RETRY_ID) {
    try {
      const slot = loadR2EffectiveRetrySlot(freeze.ledger.slots, attempt.retry_of);
      effective = { ...freeze, ledger: { ...freeze.ledger, slots: [...freeze.ledger.slots.slice(0, 4), slot] } };
    } catch (error) { return { ok: false, errors: [error.message] }; }
  }
  errors.push(...verifyNativeLoadAttempt(attempt, effective, baseDir).errors, ...verifyHostAwakeR2(attempt));
  return { ok: errors.length === 0, errors };
}

// The halted original of an infrastructure retry is not accepted proof, but it stays honest, charged and counted.
function verifyInfrastructureHaltedAttemptR2(attempt) {
  const errors = verifyHostAwakeR2(attempt);
  if (attempt.charged_duration_ms !== Math.max(attempt.execution_duration_ms, attempt.wall_duration_ms ?? 0)) errors.push('infrastructure-halted charge does not include its complete measured duration');
  const hostFault = attempt.host?.suspension_detected === true || attempt.host?.holder_alive_at_end === false || (attempt.lifecycle?.rows === 0 && Boolean(attempt.setup?.error));
  if (!hostFault) errors.push('infrastructure halt carries no host-sleep, lost-holder or host-failure evidence');
  if (attempt.assertion_failure_observed === true) errors.push('an observed assertion failure is never an infrastructure halt');
  if (!OWNED_CONTROL_DATABASE.test(attempt.database?.name ?? '')) errors.push('database identity is outside the synthetic control namespace');
  return errors;
}

export function verifyLoadRecoveryEvidenceDataR2(evidence, freeze, baseDir, stage = 'complete', freezeFileHash = freeze?.freeze_sha256) {
  const errors = [];
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) return { ok: false, errors: ['R2 native load recovery evidence is missing or malformed'] };
  if (freeze?.schema_version !== LOAD_R2_FREEZE_SCHEMA || freeze.freeze_sha256 !== loadFreezeDigest(freeze) || evidence.freeze_sha256 !== freezeFileHash) errors.push('evidence does not match the immutable R2 load recovery freeze');
  if (evidence.schema_version !== LOAD_R2_SCHEMA || JSON.stringify(evidence.source) !== JSON.stringify(freeze?.source)) errors.push('evidence source identity differs from the frozen commit and blobs');
  if (evidence.reservation || ['running', 'halted', 'halted_infrastructure'].includes(evidence.status)) errors.push('evidence contains an unresolved predebit reservation or a halted status');
  const caps = Object.hasOwn(LOAD_R2_CAP_TABLE, evidence.approval?.decision ?? '') ? LOAD_R2_CAP_TABLE[evidence.approval.decision] : null;
  if (!caps) errors.push('evidence carries no recognised budget approval decision');
  const limits = evidence.limits ?? {};
  if (limits.retry_used !== 1 || limits.retry_available !== 0) errors.push('the spent original retry was reopened or miscounted');
  if (limits.prior_charge_ms !== 2_042_596) errors.push('carried historical charge changed');
  if (caps && (limits.max_d19_ms !== caps.d19_cap_ms || limits.max_total_ms !== caps.shared_cap_ms || limits.max_physical_playwright_cli_launches !== caps.physical_cli_max
    || limits.max_d19_physical_playwright_cli_launches !== caps.d19_launch_max)) errors.push('approved time or physical CLI launch ceiling changed');
  if (JSON.stringify(evidence.infrastructure_halts?.[0]) !== JSON.stringify(freeze?.historical?.infrastructure_halt)) errors.push('the 253-40 host-sleep infrastructure halt is not preserved in the ledger');
  const attempts = Array.isArray(evidence.attempts) ? evidence.attempts : [];
  // An infrastructure-halted original plus its accepted retry is one slot outcome; the original stays in attempts.
  const outcomes = []; const haltedOriginals = [];
  for (let index = 0; index < attempts.length; index += 1) {
    const attempt = attempts[index];
    if (attempt.observed_outcome !== 'halted_infrastructure') { outcomes.push(attempt); continue; }
    haltedOriginals.push(attempt);
    errors.push(...verifyInfrastructureHaltedAttemptR2(attempt).map((message) => `${attempt.slot_id} (infrastructure halt): ${message}`));
    const retry = attempts[index + 1];
    if (!retry || retry.slot_id !== LOAD_R2_RETRY_ID || retry.retry_of !== attempt.slot_id) { errors.push(`infrastructure-halted ${attempt.slot_id} has no accepted ${LOAD_R2_RETRY_ID} outcome`); continue; }
    if (JSON.stringify(retry.argv) !== JSON.stringify(attempt.argv) || JSON.stringify(retry.projects) !== JSON.stringify(attempt.projects)) errors.push('the retry did not carry the identical frozen selection');
    outcomes.push(retry); index += 1;
  }
  const retryOutcomes = outcomes.filter((attempt) => attempt.slot_id === LOAD_R2_RETRY_ID);
  if (retryOutcomes.length !== haltedOriginals.length || retryOutcomes.length > 1) errors.push('at most one infrastructure retry, paired with one infrastructure-halted original, is allowed');
  if (retryOutcomes.length === 1) {
    const record = evidence.infrastructure_retry;
    if (evidence.approval?.retry_granted !== 1 || limits.infra_retry?.granted !== 1 || limits.infra_retry?.used !== 1) errors.push('the infrastructure retry was used without a granted, single-use approval');
    if (record?.used !== true || record.halted_slot !== retryOutcomes[0].retry_of || !/^[0-9a-f]{64}$/.test(record.diagnostic?.sha256 ?? '') || typeof record.diagnostic?.file !== 'string') errors.push('the infrastructure retry lacks its committed diagnostic record');
  } else if (limits.infra_retry?.used !== 0) errors.push('retry usage is recorded without a retry outcome');
  const count = stage === 'first' ? 1 : stage === 'complete' ? 4 : -1;
  if (count < 0 || outcomes.length !== count) errors.push(`stage ${stage} requires exactly ${count} accepted new native command outcomes`);
  const slots = (freeze?.ledger?.slots ?? []).slice(0, Math.max(0, count));
  if (outcomes.some((attempt, index) => (attempt.slot_id === LOAD_R2_RETRY_ID ? attempt.retry_of : attempt.slot_id) !== slots[index]?.id)) errors.push('new commands do not match the exact unused reservation order');
  if (attempts.some((attempt) => LOAD_R2_SPENT.includes(attempt.slot_id))) errors.push('a spent reservation was reopened');
  const usedSlots = [...(freeze?.ledger?.spent_reservations ?? []), ...attempts.map((attempt) => attempt.slot_id)];
  if (JSON.stringify(limits.used_slots) !== JSON.stringify(usedSlots)) errors.push('used reservation ledger differs from historical receipts and actual attempts');
  const measured = (freeze?.ledger?.prior_charge_ms ?? 0) + attempts.reduce((sum, attempt) => sum + (Number(attempt.charged_duration_ms) || 0), 0) + (Number(limits.preparation_charge_ms) || 0);
  if (limits.charged_duration_ms !== measured) errors.push('cumulative charge does not equal preserved history, preparation and measured command receipts');
  if ((limits.preparation_charge_ms ?? 0) > LOAD_R2_PREPARATION_MS) errors.push('preparation exceeded its R2 reservation');
  const launches = (freeze?.ledger?.prior_playwright_cli_launches ?? 0) + attempts.filter((attempt) => attempt.playwright_cli?.launched === true).length;
  if (limits.physical_playwright_cli_launches !== launches || (caps && launches > caps.physical_cli_max)) errors.push('physical Playwright CLI launch count differs from native receipts or exceeds its approved ceiling');
  if (caps && (measured > caps.d19_cap_ms || measured > caps.shared_cap_ms)) errors.push('approved D-19 or shared time limit was exceeded');
  for (const attempt of outcomes) errors.push(...verifyNativeLoadAttemptR2(attempt, freeze, baseDir).errors.map((message) => `${attempt.slot_id}: ${message}`));
  attempts.forEach((attempt, index) => {
    if (attempts.slice(0, index).some((prior) => prior.database?.name === attempt.database?.name)) errors.push('two native slots reused the same physical database identity');
  });
  if (stage === 'first' && evidence.status !== 'first_complete') errors.push('first command status is not accepted');
  if (stage === 'complete') {
    if (evidence.status !== 'complete') errors.push('complete status is not accepted');
    const total = outcomes.reduce((sum, attempt) => sum + (attempt.lifecycle?.rows ?? 0), 0);
    if (total !== 22) errors.push(`native rows total ${total}, the complete proof requires 22`);
    for (const attempt of outcomes.slice(1)) {
      const prior = outcomes[0]?.collision_receipts?.[attempt.project];
      if (!prior || prior !== attempt.fresh_state_receipts?.[attempt.project] || outcomes[0].database?.name === attempt.database?.name) errors.push(`${attempt.project}: fresh database does not prove the prior collision account absent before recreating it`);
    }
  }
  return { ok: errors.length === 0, errors };
}

function verifyLoadRecoveryFileR2(evidenceFile, stage, root = ROOT) {
  try {
    if (path.resolve(evidenceFile) !== path.resolve(root, LOAD_R2_EVIDENCE_PATH)) throw new Error('verification accepts only the additive R2 native evidence path');
    const evidence = readJson(evidenceFile);
    const freezeFile = path.resolve(root, evidence.freeze_path ?? '');
    if (freezeFile !== path.resolve(root, LOAD_R2_FREEZE_PATH)) throw new Error('native evidence does not point to the reviewed R2 freeze');
    const freeze = readJson(freezeFile);
    validateLoadRecoveryFreezeR2(root, freeze, { terminal: ['first_complete', 'complete'].includes(evidence.status) });
    const result = verifyLoadRecoveryEvidenceDataR2(evidence, freeze, `${evidenceFile}.raw`, stage, fileHash(freezeFile));
    if (!result.ok) console.error(`R2 native load recovery evidence rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`R2 native load recovery verified: ${evidence.attempts.length}/4 commands; ${evidence.limits.physical_playwright_cli_launches}/${evidence.limits.max_physical_playwright_cli_launches} CLI launches; ${evidence.limits.charged_duration_ms} ms cumulative; retry_available=0`);
    return result;
  } catch (error) { console.error(`R2 native load recovery evidence rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

// ---- Phase 253 plan 60: R3 load-recovery revision (additive; every v1 and R2 line above is untouched) ----
// 253-51 halted terminally and honestly on a provably awake host: 0 of 16 rows accepted because the 105000 ms work
// deadline also covered `mix ecto.setup` (24793 ms) and app boot, and two positive/collision controls failed for product
// reasons. R3 carries that charge, takes setup out of the browser work deadline (bounded and charged separately), sizes the
// windows from measured durations and requires per-test diagnostics on every attempt that launched the CLI.
const LOAD_R3_FREEZE_SCHEMA = 'sigra.phase253.registration-load-recovery-freeze/v3';
const LOAD_R3_SCHEMA = 'sigra.phase253.registration-load-recovery-evidence/v3';
const LOAD_R3_APPROVAL_SCHEMA = 'sigra.phase253.load-recovery-budget-approval/v2';
const LOAD_R3_FREEZE_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json`;
const LOAD_R3_EVIDENCE_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R3.json`;
const LOAD_R3_BUDGET_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-BUDGETS-R3.md`;
const LOAD_R3_APPROVAL_PATH = `${PHASE_DIR}/253-LOAD-RECOVERY-BUDGET-APPROVAL-R3.json`;
// The root cause of the 253-51 halt, bound by sha256 at whichever committed path currently holds it.
const LOAD_R3_DEBUG_PATHS = ['.planning/debug/253-r2-native-controls-all-fail.md', '.planning/debug/resolved/253-r2-native-controls-all-fail.md'];
const LOAD_R3_LINEAGE = {
  evidence: { file: LOAD_R2_EVIDENCE_PATH, sha256: 'be47d624e0587459671ce5bc5c25739d39dba5e5cfddea3dab2a04c6fd0b4035' },
  freeze: { file: LOAD_R2_FREEZE_PATH, sha256: 'b26d5a0cbfca38cbdc3fbf4931ce2fd0ba0cfc35df295e4fe820a259eaab43b1' },
  approval: { file: LOAD_R2_APPROVAL_PATH, sha256: 'd5c85aaae1faad8e28607cba08aac48f05a072c97947d943a74f176b9d1763b8' },
  budget: { file: LOAD_R2_BUDGET_PATH, sha256: '9bb278db0f990c6bf251118bf8ccb60764ed74e9b99742dbec2be65b7d186461' }
};
const LOAD_R3_SPENT = [...LOAD_R2_SPENT, LOAD_R2_FIRST_ID];
const LOAD_R3_CHARGES = [...LOAD_R2_CHARGES, 743, 107_343];
const LOAD_R3_EXPIRED = [LOAD_R2_RETRY_ID];
const LOAD_R3_RETIRED = ['CR-DESKTOP-SECOND', 'CR-MOBILE-SECOND', 'CR-DARK-SECOND'];
const LOAD_R3_IDS = ['CR3-DESKTOP-MOBILE-FIRST', 'CR3-DESKTOP-SECOND', 'CR3-MOBILE-SECOND', 'CR3-DARK-SECOND'];
const LOAD_R3_MAPS_FROM = [LOAD_R2_FIRST_ID, ...LOAD_R3_RETIRED];
const LOAD_R3_RETRY_ID = 'CR3-INFRA-RETRY';
const LOAD_R3_SETUP_MS = 60_000;
const LOAD_R3_CLEANUP_MS = 15_000;
const LOAD_R3_FIRST_WORK_MS = 165_000;
const LOAD_R3_SECOND_WORK_MS = 60_000;
const LOAD_R3_PREPARATION_MS = 10_000;
const LOAD_R3_HEADROOM_MS = 15_000;
// Product, diagnostics and audit sources that R3 pins in addition to the R2 source list.
export const LOAD_R3_EXTRA_SOURCES = [
  'lib/sigra/auth.ex',
  'test/example/lib/example/accounts.ex',
  'test/example/lib/example/accounts/user.ex',
  'test/example/lib/example_web/live/registration_live.ex',
  'priv/templates/sigra.install/core/registration_live.ex',
  'test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/registration_live.ex',
  'test/example/priv/playwright/lib/reporters/failure-jsonl.mjs',
  'scripts/ci/ci-registration-control-audit.test.mjs'
];
// Equal to the rows of 253-LOAD-RECOVERY-BUDGETS-R3.md; the ledger builder recomputes them and refuses drift.
const LOAD_R3_CAP_TABLE = {
  approve: { new_allowance_ms: 910000, d19_cap_ms: 3060682, d19_launch_max: 12, shared_cap_ms: 5400682, physical_cli_max: 21 },
  'approve-without-retry': { new_allowance_ms: 670000, d19_cap_ms: 2820682, d19_launch_max: 11, shared_cap_ms: 5160682, physical_cli_max: 20 }
};

export function loadRecoverySlotDefinitionsR3() {
  const timing = (workMs) => ({
    setup_ms: LOAD_R3_SETUP_MS, work_ms: workMs, cleanup_ms: LOAD_R3_CLEANUP_MS, command_ms: workMs + LOAD_R3_CLEANUP_MS,
    max_duration_ms: LOAD_R3_SETUP_MS + workMs + LOAD_R3_CLEANUP_MS
  });
  const regular = loadRecoverySlotDefinitions().map((slot, index) => ({
    ...slot, id: LOAD_R3_IDS[index], maps_from: LOAD_R3_MAPS_FROM[index], ...timing(index === 0 ? LOAD_R3_FIRST_WORK_MS : LOAD_R3_SECOND_WORK_MS)
  }));
  return [...regular, {
    id: LOAD_R3_RETRY_ID, sequence: 5, maps_from: LOAD_R3_RETRY_ID, retry: true, retry_of: 'resolved_from_halted_slot', selection: null,
    ...timing(LOAD_R3_FIRST_WORK_MS), launch_unit: 'playwright_cli_process', config: LOAD_RECOVERY_CONFIG, rows: 0
  }];
}

// The retry re-runs the halted slot's exact frozen selection and window sizes once under the retry identity.
function loadR3EffectiveRetrySlot(slots, haltedId) {
  const halted = slots.slice(0, 4).find((slot) => slot.id === haltedId);
  if (!halted) throw new Error(`infrastructure retry has no frozen slot to re-run: ${haltedId}`);
  return { ...halted, id: LOAD_R3_RETRY_ID, maps_from: haltedId, retry: true, retry_of: haltedId };
}

function loadR3Caps(withRetry) {
  const slots = loadRecoverySlotDefinitionsR3();
  const regular = slots.slice(0, 4).reduce((sum, slot) => sum + slot.max_duration_ms, 0);
  const newAllowance = LOAD_R3_PREPARATION_MS + regular + (withRetry ? slots[4].max_duration_ms : 0) + LOAD_R3_HEADROOM_MS;
  const d19 = 2_150_682 + newAllowance;
  const d19Launches = 7 + 4 + (withRetry ? 1 : 0);
  return { new_allowance_ms: newAllowance, d19_cap_ms: d19, d19_launch_max: d19Launches, shared_cap_ms: d19 + 9 * 240_000 + 3 * 60_000, physical_cli_max: d19Launches + 9 };
}

export function buildLoadRecoveryLedgerR3(input) {
  const errors = [];
  if (!Array.isArray(input?.charges) || JSON.stringify(input.charges) !== JSON.stringify(LOAD_R3_CHARGES)) errors.push('carried historical charges do not match the exact twelve carried components');
  if (input?.physicalPlaywrightLaunches !== 7) errors.push('carried Playwright CLI launch count must be exactly seven');
  if (JSON.stringify(input?.spentReservations) !== JSON.stringify(LOAD_R3_SPENT)) errors.push('spent reservation inventory must be the eight closed identities');
  if (input?.retryUsed !== 1 || input?.retryAvailable !== 0) errors.push('original retry must remain used 1, available 0');
  if (input?.preparationUsedMs !== 5141) errors.push('carried preparation used must be exactly 3743 + 655 + 743 = 5141 ms');
  if (errors.length) throw new Error(errors.join('; '));
  const priorCharge = input.charges.reduce((sum, value) => sum + value, 0);
  const slots = loadRecoverySlotDefinitionsR3();
  const caps = { approve: loadR3Caps(true), 'approve-without-retry': loadR3Caps(false) };
  if (priorCharge !== 2_150_682 || JSON.stringify(caps) !== JSON.stringify(LOAD_R3_CAP_TABLE)
    || slots.slice(0, 4).reduce((sum, slot) => sum + slot.rows, 0) !== 22 || slots[0].rows !== 16 || slots.slice(1, 4).some((slot) => slot.rows !== 2)) {
    throw new Error('R3 load recovery arithmetic, caps or row packing differs from the reviewed finite allocation');
  }
  return {
    prior_charge_ms: priorCharge, prior_playwright_cli_launches: 7, spent_reservations: [...LOAD_R3_SPENT],
    expired_identities: [...LOAD_R3_EXPIRED], retired_identities: [...LOAD_R3_RETIRED],
    retry_used: 1, retry_available: 0, preparation_used_ms: 5141, preparation_reserve_ms: LOAD_R3_PREPARATION_MS, slots,
    launch_unit: 'playwright_cli_process', engine_worker_lifecycle_accounting: 'separate_from_playwright_cli_launches',
    setup_ms: LOAD_R3_SETUP_MS, setup_charged_separately: true, cleanup_reserve_per_command_ms: LOAD_R3_CLEANUP_MS, headroom_ms: LOAD_R3_HEADROOM_MS,
    conditional_acceptance_slots: 9, conditional_acceptance_ms: 2_160_000, optional_seed_checks_ms: 180_000,
    caps, required_rows: 22
  };
}

function readLoadHistoryR3(root, deps = {}) {
  const d = { olderHistory: readLoadHistoryR2, lineage: LOAD_R3_LINEAGE, skipPreservedRevisions: false, ...deps };
  const older = d.olderHistory(root);
  for (const [name, record] of Object.entries(d.lineage)) {
    if (fileHash(path.join(root, record.file)) !== record.sha256) throw new Error(`R2 ${name} bytes changed: ${record.file}`);
  }
  const evidenceFile = path.join(root, d.lineage.evidence.file);
  const evidence = readJson(evidenceFile);
  const attempt = evidence.attempts?.[0];
  const limits = evidence.limits ?? {};
  if (evidence.status !== 'halted' || evidence.attempts?.length !== 1 || attempt?.slot_id !== LOAD_R2_FIRST_ID || attempt.charged_duration_ms !== 107_343
    || attempt.observed_outcome === 'halted_infrastructure' || evidence.infrastructure_retry?.eligible
    || evidence.preparation?.duration_ms !== 743 || limits.preparation_charge_ms !== 743 || limits.charged_duration_ms !== 2_150_682 || limits.prior_charge_ms !== 2_042_596
    || limits.physical_playwright_cli_launches !== 7 || JSON.stringify(limits.used_slots) !== JSON.stringify(LOAD_R3_SPENT)
    || limits.retry_used !== 1 || limits.retry_available !== 0 || limits.infra_retry?.used !== 0) {
    throw new Error('halted R2 receipt differs from the 2150682 ms, seven-launch, eight-spent, non-infrastructure ledger');
  }
  const rawBase = `${evidenceFile}.raw`;
  const rawFiles = [];
  const references = [...Object.entries(attempt.files ?? {}), ...(evidence.preparation.receipts ?? []).map((receipt) => [receipt.name, receipt.log])];
  for (const [name, reference] of references) {
    for (const item of Array.isArray(reference) ? reference : [reference]) {
      const file = confinedFile(rawBase, item);
      if (!file || fileHash(file) !== item.sha256) throw new Error(`halted R2 raw receipt readback differs: ${name}`);
      rawFiles.push(`${d.lineage.evidence.file}.raw/${item.path}`);
    }
  }
  if (!d.skipPreservedRevisions) {
    for (const revision of evidence.preserved_revisions ?? []) {
      if (sha256(readGitBlob(root, revision.ref)) !== revision.sha256) throw new Error(`halted R2 preserved revision readback differs: ${revision.ref}`);
    }
  }
  const rootCauseFile = LOAD_R3_DEBUG_PATHS.find((candidate) => fileHash(path.join(root, candidate)));
  if (!rootCauseFile) throw new Error('the R2 native-controls root-cause record is missing');
  let committed = null;
  try { committed = readGitBlob(root, `HEAD:${rootCauseFile}`); } catch { committed = null; }
  if (!committed || !committed.equals(fs.readFileSync(path.join(root, rootCauseFile)))) throw new Error(`the root-cause record is not committed in HEAD or differs from its committed bytes: ${rootCauseFile}`);
  const charges = [...older.charges, evidence.preparation.duration_ms, attempt.charged_duration_ms];
  const ledger = buildLoadRecoveryLedgerR3({
    charges, physicalPlaywrightLaunches: limits.physical_playwright_cli_launches, spentReservations: limits.used_slots,
    retryUsed: limits.retry_used, retryAvailable: limits.retry_available, preparationUsedMs: 4398 + evidence.preparation.duration_ms
  });
  const terminalHalt = {
    slot_id: attempt.slot_id, plan: '253-51', cause: 'work_deadline_exhausted_with_setup_inside', terminal: true, infrastructure: false, retryable: false, charged: true,
    charged_ms: attempt.charged_duration_ms, preparation_ms: evidence.preparation.duration_ms,
    root_cause: { file: rootCauseFile, sha256: fileHash(path.join(root, rootCauseFile)) },
    expired_identities: [...LOAD_R3_EXPIRED], retired_identities: [...LOAD_R3_RETIRED]
  };
  const lineageFiles = [...Object.values(d.lineage).map((record) => record.file), rootCauseFile, ...rawFiles];
  const own = lineageFiles.map((file) => ({ path: file, sha256: fileHash(path.join(root, file)) }));
  if (own.some((item) => !item.sha256)) throw new Error('an R3 lineage record is missing an exact byte identity');
  const artifacts = [...older.artifacts.filter((item) => !lineageFiles.includes(item.path)), ...own];
  return { control: older.control, ledger, charges, terminalHalt, artifacts, lineage: d.lineage, frozenBlobs: { ...older.frozenBlobs } };
}
export { readLoadHistoryR3 };

export function loadR3SourceFileList(root) {
  return [...new Set([...loadSourceFileList(root), ...LOAD_R3_EXTRA_SOURCES])];
}

export function verifyFrozenSourceBindingR3(root, freeze, { terminal = false } = {}) {
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const frozen = freeze?.source?.checkout_head;
  if (!frozen || run('git', ['-C', root, 'merge-base', '--is-ancestor', frozen, head]).status !== 0) throw new Error('frozen R3 source commit is not an ancestor of this checkout');
  for (const [file, expected] of Object.entries(freeze.source.blobs ?? {})) {
    if (terminal) {
      // Accepted evidence stays verifiable after later committed runner changes: bind by git objects, not the working tree.
      const blob = run('git', ['-C', root, 'rev-parse', `${frozen}:${file}`]);
      if (blob.status !== 0 || blob.stdout.trim() !== expected || run('git', ['-C', root, 'cat-file', '-t', expected]).stdout.trim() !== 'blob') throw new Error(`frozen R3 source blob mismatch at the frozen commit for ${file}`);
    } else if (git(['-C', root, 'hash-object', file]) !== expected) throw new Error(`frozen R3 source identity mismatch for ${file}`);
  }
  return head;
}

function verifyFrozenHistoryBindingR3(root, freeze, { terminal = false } = {}) {
  const frozen = freeze.source.checkout_head;
  for (const artifact of freeze.historical?.artifacts ?? []) {
    const actual = terminal ? sha256(readFrozenBytesR2(root, frozen, artifact.path)) : fileHash(path.join(root, artifact.path));
    if (actual !== artifact.sha256) throw new Error(`preserved R3 history changed: ${artifact.path}`);
  }
  const budget = terminal ? sha256(readFrozenBytesR2(root, frozen, LOAD_R3_BUDGET_PATH)) : fileHash(path.join(root, LOAD_R3_BUDGET_PATH));
  if (freeze.budget?.file !== LOAD_R3_BUDGET_PATH || !budget || freeze.budget.sha256 !== budget) throw new Error('the R3 budget document differs from the frozen binding');
}

function canonicalLedgerR3(freeze) {
  return buildLoadRecoveryLedgerR3({
    charges: freeze.historical?.carried_components_ms, physicalPlaywrightLaunches: freeze.historical?.physical_playwright_cli_launches,
    spentReservations: freeze.historical?.spent_reservations, retryUsed: freeze.historical?.spent_retry?.used,
    retryAvailable: freeze.historical?.spent_retry?.available, preparationUsedMs: 5141
  });
}

// Seams are injectable so the freeze flow runs offline in a temporary committed checkout.
function loadR3FreezeDeps(deps = {}) {
  return {
    enforceNode: true, assertCheckout: assertRevisionCheckout, assertConfig: assertDirtyConfigPreserved, readHistory: readLoadHistoryR3, sourceFiles: loadR3SourceFileList,
    requiredSources: () => [...SOURCE_FILES, ...LOAD_EXTRA_SOURCES, ...LOAD_R3_EXTRA_SOURCES], importClosure: discoverLoadImportClosure, runtimeIdentity: loadRuntimeIdentity, ...deps
  };
}

export function createLoadRecoveryFreezeR3(outputFile, root = ROOT, deps = {}) {
  const d = loadR3FreezeDeps(deps);
  if (fs.existsSync(outputFile)) throw new Error('refusing to overwrite the additive R3 load recovery freeze');
  if (d.enforceNode && process.version !== LOAD_NODE) throw new Error(`load recovery must be frozen under Node ${LOAD_NODE}`);
  d.assertCheckout(root);
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const history = d.readHistory(root);
  for (const artifact of history.artifacts) {
    if (sha256(readFrozenBytesR2(root, head, artifact.path)) !== artifact.sha256) throw new Error(`R3 lineage record is not committed at HEAD: ${artifact.path}`);
  }
  const budgetHash = fileHash(path.join(root, LOAD_R3_BUDGET_PATH));
  if (!budgetHash || sha256(readFrozenBytesR2(root, head, LOAD_R3_BUDGET_PATH)) !== budgetHash) throw new Error('the R3 budget document is missing or not committed at HEAD');
  const files = d.sourceFiles(root);
  const blobs = Object.fromEntries(files.map((file) => [file, git(['-C', root, 'rev-parse', `${head}:${file}`])]));
  const freeze = {
    schema_version: LOAD_R3_FREEZE_SCHEMA, status: 'frozen_before_results', plan: '253-60', revision: 'r3', frozen_at: new Date().toISOString(),
    source: { repository: 'szTheory/sigra', checkout_head: head, blobs },
    runtime: d.runtimeIdentity(root),
    historical: {
      artifacts: history.artifacts, frozen_blob_sets: history.frozenBlobs, carried_charge_ms: history.ledger.prior_charge_ms,
      carried_components_ms: history.charges, physical_playwright_cli_launches: 7, spent_reservations: [...LOAD_R3_SPENT],
      expired_identities: [...LOAD_R3_EXPIRED], retired_identities: [...LOAD_R3_RETIRED],
      spent_retry: { used: 1, available: 0 }, terminal_halt: history.terminalHalt, halted_lineage: structuredClone(history.lineage ?? LOAD_R3_LINEAGE)
    },
    budget: { file: LOAD_R3_BUDGET_PATH, sha256: budgetHash, grants_capacity: false },
    ledger: history.ledger,
    setup_accounting: {
      setup_ms: LOAD_R3_SETUP_MS, separately_bounded: true, separately_charged: true, command_deadline_starts_after_setup: true,
      setup_charge: 'max(monotonic, wall)', command_charge: 'max(monotonic, wall)', slot_charge: 'setup_charge + command_charge'
    },
    diagnostics: { per_test_jsonl_required_when_cli_launched: true, env: 'SIGRA_PLAYWRIGHT_FAILURE_JSONL', error_context_preserved: true },
    selection: {
      spec: 'tests/admin-eval.spec.ts', config: path.basename(LOAD_RECOVERY_CONFIG), original_title: CONTROL_BOARD_TITLE,
      first_titles: FIRST_CONTROLS, second_titles: CONTROL_SECOND_ACTIVE, deliberate_expected_failure_markers: CONTROL_EXPECTED_FAILURE_MARKERS,
      cli_grep_forbidden: true, workers: 1, fully_parallel: false, retries: 0, trace: 'retain-on-failure'
    },
    tools: {
      node: process.version, expected_node: LOAD_NODE, playwright: '1.59.1', parse5: '8.0.1',
      mix: history.control?.accepted?.toolchain?.mix, ecto_sql: history.control?.accepted?.toolchain?.ecto_sql, phoenix_live_view: history.control?.accepted?.toolchain?.phoenix_live_view
    },
    exclusions: ['no browser installation', 'no hidden --list or version CLI', 'no warmup', 'no duplicate full suite', 'no reuse of any of the eight spent identities', 'no reuse of the expired R2 infrastructure retry or the retired CR-*-SECOND identities', 'no native or hosted work without a committed Jon approval record bound to the R3 budget document and this freeze', 'no capacity granted by this freeze'],
    stop_conditions: ['source or history digest mismatch', 'unexpected assertion or missing native report', 'database drop/build cleanup/report/trace sanitation failure', 'setup exceeds 60000 ms', 'command exceeds its frozen command_ms', 'host suspension detected', 'stalled owned process group remains alive', 'AC power, caffeinate holder or pmset assertion proof missing before predebit', 'a launched attempt lacks its per-test JSONL receipt']
  };
  freeze.freeze_sha256 = loadFreezeDigest(freeze);
  writeJson(outputFile, freeze);
  return freeze;
}

export function validateLoadRecoveryFreezeR3(root, freeze, { terminal = false, deps = {} } = {}) {
  const d = loadR3FreezeDeps(deps);
  d.assertConfig(root);
  if (freeze?.schema_version !== LOAD_R3_FREEZE_SCHEMA || freeze.status !== 'frozen_before_results'
    || freeze.freeze_sha256 !== loadFreezeDigest(freeze)) throw new Error('R3 native load recovery freeze is malformed or its digest is invalid');
  const head = verifyFrozenSourceBindingR3(root, freeze, { terminal });
  for (const required of d.requiredSources()) if (!freeze.source.blobs?.[required]) throw new Error(`freeze omits required source ${required}`);
  if (!terminal) for (const file of d.importClosure(root)) if (!freeze.source.blobs?.[file]) throw new Error(`freeze omits actual imported runtime source ${file}`);
  verifyFrozenHistoryBindingR3(root, freeze, { terminal });
  if (JSON.stringify(freeze.ledger) !== JSON.stringify(canonicalLedgerR3(freeze))) throw new Error('frozen R3 ledger differs from the reviewed carried allocation');
  for (const slot of freeze.ledger.slots.slice(0, 4)) if (slot.argv.some((arg) => /^(-g|--grep)(=|$)/.test(arg))) throw new Error('frozen argv carries a CLI grep that would override per-project selection');
  if (!terminal) {
    if (JSON.stringify(freeze.runtime) !== JSON.stringify(d.runtimeIdentity(root))) throw new Error('locked/installed runtime or pinned transform identity changed');
    const history = d.readHistory(root);
    if (JSON.stringify(history.ledger) !== JSON.stringify(freeze.ledger)) throw new Error('re-read R2 lineage differs from the frozen R3 ledger');
    if (JSON.stringify(history.terminalHalt) !== JSON.stringify(freeze.historical.terminal_halt)) throw new Error('re-read 253-51 terminal halt record differs from the frozen record');
  }
  return head;
}

function checkLoadRecoveryFreezeFileR3(freezeFile, root = ROOT) {
  try {
    if (path.resolve(freezeFile) !== path.resolve(root, LOAD_R3_FREEZE_PATH)) throw new Error('freeze check accepts only the additive R3 path');
    validateLoadRecoveryFreezeR3(root, readJson(freezeFile));
    console.log('R3 native load recovery freeze verified: R2 lineage re-hashed, 2150682 ms/7 launches/8 spent carried, setup bounded outside the work deadline, 22 rows, no capacity granted');
    return { ok: true, errors: [] };
  } catch (error) {
    console.error(`R3 native load recovery freeze rejected: ${error.message}`);
    return { ok: false, errors: [error.message] };
  }
}

export function initializeLoadRecoveryEvidenceR3(freezeFile, evidenceFile, root = ROOT, deps = {}) {
  const d = { validate: validateLoadRecoveryFreezeR3, readApproval: loadR3UnwiredApproval, ...deps };
  if (fs.existsSync(evidenceFile)) throw new Error('refusing to overwrite additive R3 native load recovery evidence');
  const freeze = readJson(freezeFile);
  d.validate(root, freeze);
  const approval = d.readApproval(root, freezeFile, freeze);
  const caps = LOAD_R3_CAP_TABLE[approval.decision];
  const evidence = {
    schema_version: LOAD_R3_SCHEMA, revision: 'r3', status: 'ready',
    freeze_path: path.relative(root, freezeFile), freeze_sha256: fileHash(freezeFile),
    source: structuredClone(freeze.source), historical: structuredClone(freeze.historical),
    created_at: new Date().toISOString(), attempts: [], preparation: null, reservation: null, preserved_revisions: [],
    prior_terminal_halts: [structuredClone(freeze.historical.terminal_halt)], infrastructure_halts: [], infrastructure_retry: null,
    approval: { decision: approval.decision, retry_granted: approval.retry_granted },
    limits: {
      prior_charge_ms: freeze.ledger.prior_charge_ms, preparation_charge_ms: 0, preparation_remaining_ms: freeze.ledger.preparation_reserve_ms,
      charged_duration_ms: freeze.ledger.prior_charge_ms, physical_playwright_cli_launches: freeze.ledger.prior_playwright_cli_launches,
      used_slots: [...freeze.ledger.spent_reservations], max_d19_ms: caps.d19_cap_ms, max_total_ms: caps.shared_cap_ms,
      max_d19_physical_playwright_cli_launches: caps.d19_launch_max, max_physical_playwright_cli_launches: caps.physical_cli_max,
      retry_used: 1, retry_available: 0, infra_retry: { granted: approval.retry_granted, used: 0 }
    }
  };
  fs.mkdirSync(`${evidenceFile}.raw`, { recursive: true });
  writeJson(evidenceFile, evidence);
  return evidence;
}

// An accepted R3 attempt: the Plan 39 predicates, judged against the effective slot (a retry carries the halted slot's selection
// and window sizes). The v1 predicates compare the charge with max(execution, wall) of the whole window; R3 charges setup and
// command separately (a sum that can only be larger), so they are judged on an adjusted copy and the real charge is checked here.
export function verifyNativeLoadAttemptR3(attempt, freeze, baseDir) {
  const errors = [];
  if (!attempt || typeof attempt !== 'object') return { ok: false, errors: ['native load attempt is missing'] };
  let effective = freeze;
  if (attempt.slot_id === LOAD_R3_RETRY_ID) {
    try {
      const slot = loadR3EffectiveRetrySlot(freeze.ledger.slots, attempt.retry_of);
      effective = { ...freeze, ledger: { ...freeze.ledger, slots: [...freeze.ledger.slots.slice(0, 4), slot] } };
    } catch (error) { return { ok: false, errors: [error.message] }; }
  }
  const adjusted = { ...attempt, charged_duration_ms: Math.max(attempt.execution_duration_ms ?? 0, attempt.wall_duration_ms ?? 0) };
  errors.push(...verifyNativeLoadAttempt(adjusted, effective, baseDir).errors);
  attempt.collision_receipts = adjusted.collision_receipts; attempt.fresh_state_receipts = adjusted.fresh_state_receipts;
  errors.push(...verifyAttemptAccountingR3(attempt, effective.ledger.slots.find((item) => item.id === attempt.slot_id), baseDir));
  return { ok: errors.length === 0, errors };
}

// Setup is charged on its own and the command window starts where setup ends: the slot charge is their sum, and every
// attempt that launched the CLI must carry per-test diagnostics that match the preserved rows.
function verifyAttemptAccountingR3(attempt, slot, baseDir) {
  const errors = [];
  if (!slot) return ['attempt does not identify a frozen R3 slot'];
  const deadlines = attempt.stage_deadlines ?? {};
  if (deadlines.setup_ms !== slot.setup_ms || deadlines.command_ms !== slot.command_ms || deadlines.work_ms !== slot.work_ms || deadlines.cleanup_ms !== slot.cleanup_ms || deadlines.cleanup_reserved !== true) {
    errors.push('stage deadlines differ from the frozen setup, work and cleanup windows');
  }
  const setup = attempt.setup_timing; const command = attempt.command_timing;
  const wellFormed = (value) => value && Number.isSafeInteger(value.execution_ms) && Number.isSafeInteger(value.wall_ms) && value.execution_ms >= 0 && value.wall_ms >= 0;
  if (!wellFormed(setup) || !wellFormed(command)) errors.push('setup or command timing receipt is missing');
  else {
    try {
      const span = (window) => Math.ceil(Number(BigInt(window.ended_monotonic_ns) - BigInt(window.started_monotonic_ns)) / 1e6);
      if (setup.started_monotonic_ns !== attempt.started_monotonic_ns || command.ended_monotonic_ns !== attempt.ended_monotonic_ns || setup.ended_monotonic_ns !== command.started_monotonic_ns) errors.push('setup and command windows do not tile the slot window');
      if (span(setup) !== setup.execution_ms || span(command) !== command.execution_ms) errors.push('setup or command monotonic duration is inconsistent with its bounds');
    } catch { errors.push('setup or command monotonic bounds are missing'); }
    if (attempt.setup_charge_ms !== Math.max(setup.execution_ms, setup.wall_ms)) errors.push('setup charge is not max(monotonic, wall) of the setup phase');
    if (attempt.command_charge_ms !== Math.max(command.execution_ms, command.wall_ms)) errors.push('command charge is not max(monotonic, wall) of the command phase');
    if (attempt.charged_duration_ms !== attempt.setup_charge_ms + attempt.command_charge_ms) errors.push('slot charge is not the setup charge plus the command charge');
    if (attempt.setup_charge_ms > slot.setup_ms) errors.push(`setup overran its frozen ${slot.setup_ms} ms ceiling`);
    if (attempt.command_charge_ms > slot.command_ms) errors.push(`command overran its frozen ${slot.command_ms} ms window`);
  }
  if (!Number.isSafeInteger(attempt.charged_duration_ms) || attempt.charged_duration_ms > slot.max_duration_ms) errors.push(`native slot exceeded its frozen ${slot.max_duration_ms} ms reservation`);
  const diagnostics = verifyAttemptDiagnosticsR3(attempt, baseDir);
  errors.push(...diagnostics.errors);
  if (diagnostics.ok && attempt.diagnostics?.jsonl) {
    const preserved = perTestRowsFromJsonl(fs.readFileSync(confinedFile(baseDir, attempt.diagnostics.jsonl), 'utf8'));
    if (JSON.stringify(attempt.per_test_rows) !== JSON.stringify(preserved)) errors.push('per_test_rows differ from the preserved per-test JSONL');
  }
  return errors;
}

export function verifyLoadRecoveryEvidenceDataR3(evidence, freeze, baseDir, stage = 'complete', freezeFileHash = freeze?.freeze_sha256) {
  const errors = [];
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) return { ok: false, errors: ['R3 native load recovery evidence is missing or malformed'] };
  if (freeze?.schema_version !== LOAD_R3_FREEZE_SCHEMA || freeze.freeze_sha256 !== loadFreezeDigest(freeze) || evidence.freeze_sha256 !== freezeFileHash) errors.push('evidence does not match the immutable R3 load recovery freeze');
  if (evidence.schema_version !== LOAD_R3_SCHEMA || JSON.stringify(evidence.source) !== JSON.stringify(freeze?.source)) errors.push('evidence source identity differs from the frozen commit and blobs');
  if (evidence.reservation || ['running', 'halted', 'halted_infrastructure'].includes(evidence.status)) errors.push('evidence contains an unresolved predebit reservation or a halted status');
  const caps = Object.hasOwn(LOAD_R3_CAP_TABLE, evidence.approval?.decision ?? '') ? LOAD_R3_CAP_TABLE[evidence.approval.decision] : null;
  if (!caps) errors.push('evidence carries no recognised budget approval decision');
  const limits = evidence.limits ?? {};
  if (limits.retry_used !== 1 || limits.retry_available !== 0) errors.push('the spent original retry was reopened or miscounted');
  if (limits.prior_charge_ms !== 2_150_682) errors.push('carried historical charge changed');
  if (caps && (limits.max_d19_ms !== caps.d19_cap_ms || limits.max_total_ms !== caps.shared_cap_ms || limits.max_physical_playwright_cli_launches !== caps.physical_cli_max
    || limits.max_d19_physical_playwright_cli_launches !== caps.d19_launch_max)) errors.push('approved time or physical CLI launch ceiling changed');
  if (JSON.stringify(evidence.prior_terminal_halts?.[0]) !== JSON.stringify(freeze?.historical?.terminal_halt)) errors.push('the 253-51 terminal non-infrastructure halt is not preserved in the ledger');
  const attempts = Array.isArray(evidence.attempts) ? evidence.attempts : [];
  // An infrastructure-halted original plus its accepted retry is one slot outcome; the original stays in attempts.
  const outcomes = []; const haltedOriginals = [];
  for (let index = 0; index < attempts.length; index += 1) {
    const attempt = attempts[index];
    if (attempt.observed_outcome !== 'halted_infrastructure') { outcomes.push(attempt); continue; }
    haltedOriginals.push(attempt);
    errors.push(...verifyInfrastructureHaltedAttemptR3(attempt, freeze, baseDir).map((message) => `${attempt.slot_id} (infrastructure halt): ${message}`));
    const retry = attempts[index + 1];
    if (!retry || retry.slot_id !== LOAD_R3_RETRY_ID || retry.retry_of !== attempt.slot_id) { errors.push(`infrastructure-halted ${attempt.slot_id} has no accepted ${LOAD_R3_RETRY_ID} outcome`); continue; }
    if (JSON.stringify(retry.argv) !== JSON.stringify(attempt.argv) || JSON.stringify(retry.projects) !== JSON.stringify(attempt.projects)) errors.push('the retry did not carry the identical frozen selection');
    outcomes.push(retry); index += 1;
  }
  const retryOutcomes = outcomes.filter((attempt) => attempt.slot_id === LOAD_R3_RETRY_ID);
  if (retryOutcomes.length !== haltedOriginals.length || retryOutcomes.length > 1) errors.push('at most one infrastructure retry, paired with one infrastructure-halted original, is allowed');
  if (retryOutcomes.length === 1) {
    const record = evidence.infrastructure_retry;
    if (evidence.approval?.retry_granted !== 1 || limits.infra_retry?.granted !== 1 || limits.infra_retry?.used !== 1) errors.push('the infrastructure retry was used without a granted, single-use approval');
    if (record?.used !== true || record.halted_slot !== retryOutcomes[0].retry_of || !/^[0-9a-f]{64}$/.test(record.diagnostic?.sha256 ?? '') || typeof record.diagnostic?.file !== 'string') errors.push('the infrastructure retry lacks its committed diagnostic record');
  } else if (limits.infra_retry?.used !== 0) errors.push('retry usage is recorded without a retry outcome');
  const count = stage === 'first' ? 1 : stage === 'complete' ? 4 : -1;
  if (count < 0 || outcomes.length !== count) errors.push(`stage ${stage} requires exactly ${count} accepted new native command outcomes`);
  const slots = (freeze?.ledger?.slots ?? []).slice(0, Math.max(0, count));
  if (outcomes.some((attempt, index) => (attempt.slot_id === LOAD_R3_RETRY_ID ? attempt.retry_of : attempt.slot_id) !== slots[index]?.id)) errors.push('new commands do not match the exact unused reservation order');
  if (attempts.some((attempt) => LOAD_R3_SPENT.includes(attempt.slot_id) || LOAD_R3_EXPIRED.includes(attempt.slot_id) || LOAD_R3_RETIRED.includes(attempt.slot_id))) errors.push('a spent, expired or retired reservation was reopened');
  const usedSlots = [...(freeze?.ledger?.spent_reservations ?? []), ...attempts.map((attempt) => attempt.slot_id)];
  if (JSON.stringify(limits.used_slots) !== JSON.stringify(usedSlots)) errors.push('used reservation ledger differs from historical receipts and actual attempts');
  const measured = (freeze?.ledger?.prior_charge_ms ?? 0) + attempts.reduce((sum, attempt) => sum + (Number(attempt.charged_duration_ms) || 0), 0) + (Number(limits.preparation_charge_ms) || 0);
  if (limits.charged_duration_ms !== measured) errors.push('cumulative charge does not equal preserved history, preparation and measured command receipts');
  if ((limits.preparation_charge_ms ?? 0) > LOAD_R3_PREPARATION_MS) errors.push('preparation exceeded its R3 reservation');
  const launches = (freeze?.ledger?.prior_playwright_cli_launches ?? 0) + attempts.filter((attempt) => attempt.playwright_cli?.launched === true).length;
  if (limits.physical_playwright_cli_launches !== launches || (caps && launches > caps.physical_cli_max)) errors.push('physical Playwright CLI launch count differs from native receipts or exceeds its approved ceiling');
  if (caps && (measured > caps.d19_cap_ms || measured > caps.shared_cap_ms)) errors.push('approved D-19 or shared time limit was exceeded');
  for (const attempt of outcomes) errors.push(...verifyNativeLoadAttemptR3(attempt, freeze, baseDir).errors.map((message) => `${attempt.slot_id}: ${message}`));
  attempts.forEach((attempt, index) => {
    if (attempts.slice(0, index).some((prior) => prior.database?.name === attempt.database?.name)) errors.push('two native slots reused the same physical database identity');
  });
  if (stage === 'first' && evidence.status !== 'first_complete') errors.push('first command status is not accepted');
  if (stage === 'complete') {
    if (evidence.status !== 'complete') errors.push('complete status is not accepted');
    const total = outcomes.reduce((sum, attempt) => sum + (attempt.lifecycle?.rows ?? 0), 0);
    if (total !== 22) errors.push(`native rows total ${total}, the complete proof requires 22`);
    for (const attempt of outcomes.slice(1)) {
      const prior = outcomes[0]?.collision_receipts?.[attempt.project];
      if (!prior || prior !== attempt.fresh_state_receipts?.[attempt.project] || outcomes[0].database?.name === attempt.database?.name) errors.push(`${attempt.project}: fresh database does not prove the prior collision account absent before recreating it`);
    }
  }
  return { ok: errors.length === 0, errors };
}

// The halted original of an infrastructure retry is not accepted proof, but it stays honest, charged and counted.
function verifyInfrastructureHaltedAttemptR3(attempt, freeze, baseDir) {
  const errors = verifyAttemptAccountingR3(attempt, (freeze?.ledger?.slots ?? []).find((item) => item.id === attempt.slot_id), baseDir);
  const hostFault = attempt.host?.suspension_detected === true || attempt.host?.holder_alive_at_end === false || (attempt.lifecycle?.rows === 0 && Boolean(attempt.setup?.error));
  if (!hostFault) errors.push('infrastructure halt carries no host-sleep, lost-holder or host-failure evidence');
  if (attempt.assertion_failure_observed === true) errors.push('an observed assertion failure is never an infrastructure halt');
  if (!OWNED_CONTROL_DATABASE.test(attempt.database?.name ?? '')) errors.push('database identity is outside the synthetic control namespace');
  return errors;
}

function verifyLoadRecoveryFileR3(evidenceFile, stage, root = ROOT) {
  try {
    if (path.resolve(evidenceFile) !== path.resolve(root, LOAD_R3_EVIDENCE_PATH)) throw new Error('verification accepts only the additive R3 native evidence path');
    const evidence = readJson(evidenceFile);
    const freezeFile = path.resolve(root, evidence.freeze_path ?? '');
    if (freezeFile !== path.resolve(root, LOAD_R3_FREEZE_PATH)) throw new Error('native evidence does not point to the reviewed R3 freeze');
    const freeze = readJson(freezeFile);
    validateLoadRecoveryFreezeR3(root, freeze, { terminal: ['first_complete', 'complete'].includes(evidence.status) });
    const result = verifyLoadRecoveryEvidenceDataR3(evidence, freeze, `${evidenceFile}.raw`, stage, fileHash(freezeFile));
    if (!result.ok) console.error(`R3 native load recovery evidence rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`R3 native load recovery verified: ${evidence.attempts.length}/4 commands; ${evidence.limits.physical_playwright_cli_launches}/${evidence.limits.max_physical_playwright_cli_launches} CLI launches; ${evidence.limits.charged_duration_ms} ms cumulative; retry_available=0`);
    return result;
  } catch (error) { console.error(`R3 native load recovery evidence rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

function loadR3AcceptedAttempts(evidence) {
  return evidence.attempts.filter((attempt) => attempt.observed_outcome === 'native_rows_accepted');
}

function perTestRowsFromJsonl(text) {
  return parsePerTestJsonl(text).rows.map((row) => {
    const line = String(row.errors?.[0]?.message ?? '').split('\n').map((item) => item.trim()).find(Boolean) ?? null;
    return { project: row.project ?? null, title: row.title ?? null, status: row.status ?? null, first_error_line: line ? line.slice(0, 300) : null, duration_ms: row.duration_ms ?? null };
  });
}

// Bounded preparation: toolchain version probes only (no app boot, warmup, Playwright CLI, or browser install).
export async function prepareLoadRecoveryR3(freezeFile, evidenceFile, root = ROOT, deps = {}) {
  const d = { validate: validateLoadRecoveryFreezeR3, readApproval: loadR3UnwiredApproval, runTree: runLoggedTree, ...deps };
  const freeze = readJson(freezeFile);
  d.validate(root, freeze);
  d.readApproval(root, freezeFile, freeze);
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== LOAD_R3_SCHEMA || evidence.freeze_sha256 !== fileHash(freezeFile)) throw new Error('evidence does not match the committed R3 freeze');
  if (evidence.status !== 'ready' || evidence.reservation || evidence.preparation) throw new Error('preparation is only available once, from ready evidence');
  if (evidence.attempts.length || evidence.limits.physical_playwright_cli_launches !== freeze.ledger.prior_playwright_cli_launches) throw new Error('preparation must precede every new native command');
  const reserve = evidence.limits.preparation_remaining_ms;
  evidence.status = 'running';
  evidence.reservation = { kind: 'preparation', reserved_ms: reserve, predebited_at: new Date().toISOString() };
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  const dir = path.join(`${evidenceFile}.raw`, 'preparation'); fs.mkdirSync(dir, { recursive: true });
  const exampleDir = path.join(root, 'test/example'); const env = { ...process.env, MIX_ENV: 'dev' };
  const commands = [['mix_version', 'mix', ['--version']], ['host_dependency_versions', 'mix', ['deps']]];
  const started = process.hrtime.bigint(); const receipts = []; let failed = null;
  for (const [name, program, args] of commands) {
    const remaining = reserve - Math.ceil(Number(process.hrtime.bigint() - started) / 1e6);
    if (remaining <= 0) { failed = 'preparation reached its predebited allowance'; break; }
    const log = path.join(dir, `${name}.log`);
    const result = await d.runTree(program, args, exampleDir, env, log, remaining);
    receipts.push({ name, argv: [program, ...args], exit_code: result.exit_code, duration_ms: result.duration_ms, log: referenceFor(`${evidenceFile}.raw`, log) });
    if (result.exit_code !== 0 || result.timed_out) { failed = `${name} failed`; break; }
  }
  const duration = Math.ceil(Number(process.hrtime.bigint() - started) / 1e6);
  evidence.reservation = null; evidence.preparation = { receipts, duration_ms: duration, status: failed ? 'failed' : 'passed' };
  evidence.limits.preparation_charge_ms = duration; evidence.limits.preparation_remaining_ms = Math.max(0, reserve - duration);
  evidence.limits.charged_duration_ms += duration;
  evidence.status = failed || duration > reserve ? 'halted' : 'ready';
  if (evidence.status === 'halted') evidence.stop_reason = failed ?? 'preparation exceeded its allowance';
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  if (evidence.status === 'halted') throw new Error(evidence.stop_reason);
  return { status: evidence.status, preparation_charge_ms: duration };
}

function loadR3UnwiredApproval() {
  throw new Error('the R3 budget approval reader is not wired');
}

export async function runLoadRecoverySlotR3(freezeFile, slotId, evidenceFile, root = ROOT, deps = {}) {
  const d = {
    validate: validateLoadRecoveryFreezeR3, runTree: runLoggedTree, spawnApp: spawn, waitReady, portAvailable, stopApp,
    probeHost: probeHostSleepSafety, readApproval: loadR3UnwiredApproval, checkDiagnostic: readCommittedDiagnostic, holderAlive: processAlive, diagnosticFile: null,
    captureAbsence: captureOwnedDatabaseAbsence, captureAccount: captureOwnedAccountCount, sanitizeTrace: sanitizeTraceFile,
    monotonicNs: () => process.hrtime.bigint(), wallMs: () => Date.now(),
    skipPreservation: false, enforcePaths: true, enforceNode: true, ...deps
  };
  if (LOAD_R3_SPENT.includes(slotId)) throw new Error(`reservation ${slotId} is permanently spent and cannot be run or retried`);
  if (LOAD_R3_EXPIRED.includes(slotId)) throw new Error(`reservation ${slotId} is expired and can never be charged or run`);
  if (LOAD_R3_RETIRED.includes(slotId)) throw new Error(`reservation ${slotId} is retired unused and can never be run`);
  if (d.enforcePaths && (path.resolve(freezeFile) !== path.resolve(root, LOAD_R3_FREEZE_PATH) || path.resolve(evidenceFile) !== path.resolve(root, LOAD_R3_EVIDENCE_PATH))) throw new Error('R3 load recovery accepts only the reviewed R3 freeze and additive R3 evidence paths');
  if (d.enforceNode && process.version !== LOAD_NODE) throw new Error(`load recovery native commands require Node ${LOAD_NODE}`);
  const freeze = readJson(freezeFile);
  const freezeHash = fileHash(freezeFile);
  const regular = freeze.ledger?.slots?.slice(0, 4) ?? [];
  const isRetry = slotId === LOAD_R3_RETRY_ID;
  const slot = regular.find((item) => item.id === slotId);
  if (isRetry) throw new Error('the infrastructure retry is added by 253-60 task 3');
  if (!slot) throw new Error('only the four frozen unused R3 load recovery slots and the one infrastructure retry may run');
  d.validate(root, freeze);
  const approval = d.readApproval(root, freezeFile, freeze);
  const caps = Object.hasOwn(LOAD_R3_CAP_TABLE, approval.decision ?? '') ? LOAD_R3_CAP_TABLE[approval.decision] : null;
  if (!caps) throw new Error('budget approval carries an unknown decision');
  if (!fs.existsSync(evidenceFile)) throw new Error('R3 native load recovery evidence must be initialized and committed before launch');
  const evidence = readJson(evidenceFile);
  if (evidence.schema_version !== LOAD_R3_SCHEMA || evidence.freeze_sha256 !== freezeHash) throw new Error('R3 native load evidence does not match the committed freeze');
  const limits = evidence.limits;
  if (!['ready', 'first_complete', 'second_partial'].includes(evidence.status) || evidence.reservation) throw new Error(`refusing to use terminal or reserved R3 recovery evidence: ${evidence.status}`);
  if (limits.used_slots.includes(slot.id)) throw new Error(`reservation ${slot.id} was already consumed`);
  if (limits.retry_used !== 1 || limits.retry_available !== 0 || limits.prior_charge_ms !== freeze.ledger.prior_charge_ms
    || limits.charged_duration_ms < freeze.ledger.prior_charge_ms) throw new Error('counter reset or reopened retry detected before setup');
  if (limits.max_d19_ms !== Math.min(caps.d19_cap_ms, freeze.ledger.caps.approve.d19_cap_ms) || limits.max_total_ms !== Math.min(caps.shared_cap_ms, freeze.ledger.caps.approve.shared_cap_ms)
    || limits.max_physical_playwright_cli_launches !== caps.physical_cli_max) throw new Error('approval caps differ from the evidence ledger');
  const accepted = loadR3AcceptedAttempts(evidence);
  const pending = regular.slice(accepted.length);
  if (!pending[0] || pending[0].id !== slot.id) throw new Error('slots must run in frozen order, each exactly once');
  const retryReserved = approval.retry_granted === 1 && limits.infra_retry?.used === 0 ? freeze.ledger.slots[4].max_duration_ms : 0;
  const reservedMs = pending.reduce((sum, item) => sum + item.max_duration_ms, 0) + retryReserved;
  const reservedLaunches = pending.length + (retryReserved ? 1 : 0);
  if (slot.max_duration_ms !== slot.setup_ms + slot.command_ms || slot.command_ms !== slot.work_ms + slot.cleanup_ms
    || limits.charged_duration_ms + limits.preparation_remaining_ms + reservedMs > limits.max_d19_ms
    || limits.physical_playwright_cli_launches + reservedLaunches > limits.max_d19_physical_playwright_cli_launches
    || limits.charged_duration_ms + limits.preparation_remaining_ms + reservedMs + 9 * 240000 + 3 * 60000 > limits.max_total_ms
    || limits.physical_playwright_cli_launches + reservedLaunches + 9 > limits.max_physical_playwright_cli_launches) throw new Error('remaining D-19 and conditional D-20 reservations do not fit approved limits');
  if (!(await d.portAvailable(slot.port))) throw new Error(`frozen port ${slot.port} is occupied before native setup`);
  const project = PROJECTS.find((item) => item.name === slot.project);
  // The host proof runs before the predebit so an unsafe host costs no reservation.
  const { awake, host_awake: hostAwake } = await d.probeHost();
  try {
    return await runHeldLoadRecoverySlotR3({ d, root, freeze, slot, evidence, evidenceFile, project, awake, hostAwake, diagnostic: null });
  } finally { awake.release(); }
}

async function runHeldLoadRecoverySlotR3({ d, root, freeze, slot, evidence, evidenceFile, project, awake, hostAwake, diagnostic }) {
  const reserve = slot.max_duration_ms;
  const rawDir = `${evidenceFile}.raw`;
  const rawAttempt = createAttemptDirectory(rawDir, slot.id, 1);
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-load-r3-'));
  const mono = () => d.monotonicNs();
  const wallNow = () => d.wallMs();
  const ceilMs = (ns) => Math.ceil(Number(ns) / 1e6);
  const started = mono();
  const wallStarted = wallNow();
  // Each phase's remaining time is judged on both clocks, so a sleep that stops the monotonic clock still shortens the window.
  const remainingIn = (ns0, wall0, budgetMs) => Math.min(budgetMs - Number(mono() - ns0) / 1e6, budgetMs - (wallNow() - wall0));
  const database = `sigra_253_control_load_${slot.id.toLowerCase().replaceAll('-', '_')}_${Date.now().toString(36)}_${process.pid}`.toLowerCase();
  const env = diagnosticEnvironment(project, database, tempRoot);
  const tempPaths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(tempRoot, `${name.replaceAll('_', '-')}.log`)]));
  const reportTemp = path.join(tempRoot, 'playwright-report.json');
  const jsonlTemp = path.join(tempRoot, 'tests.jsonl');
  const outputTemp = path.join(tempRoot, 'playwright-output');
  const attempt = {
    slot_id: slot.id, sequence: slot.sequence, stage: slot.stage, project: slot.project, projects: slot.projects, argv: slot.argv,
    source_commit: freeze.source.checkout_head, source_blobs: freeze.source.blobs, started_monotonic_ns: started.toString(),
    database: { name: database, setup_exit_code: null, drop_exit_code: null, connection: databaseConnectionIdentity(env) },
    server: { port: slot.port, http_status: null, app_pid: null }, browser: { launched: false, exit_code: null },
    playwright_cli: { launched: false, exit_code: null }, lifecycle: { playwright_cli_processes: 0, rows: 0, worker_indexes: [] },
    observed_outcome: 'setup_failed', files: {}, traces: [], registration: { server_post_confirmed: false },
    toolchain: { playwright: null, ecto_sql: freeze.tools.ecto_sql, phoenix_live_view: freeze.tools.phoenix_live_view },
    build_path: env.MIX_BUILD_PATH,
    stage_deadlines: { setup_ms: slot.setup_ms, command_ms: slot.command_ms, work_ms: slot.work_ms, cleanup_ms: slot.cleanup_ms, cleanup_reserved: true },
    host: { platform: awake.platform, sleep_assertion_held: awake.held, sleep_assertion_argv: awake.argv ?? null, suspension_detected: false, holder_alive_at_end: null },
    host_awake: hostAwake, assertion_failure_observed: false, diagnostics: null, per_test_rows: [], ...(slot.retry ? { retry_of: slot.retry_of } : {})
  };
  evidence.status = 'running';
  evidence.reservation = { slot_id: slot.id, mapped_from: slot.maps_from, reserved_ms: reserve, predebited_at: new Date().toISOString(), source_commit: freeze.source.checkout_head };
  evidence.limits.used_slots.push(slot.id);
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  let app = null; let terminalError = null; let setupEnd = null;
  const playwrightDir = path.join(root, LOAD_PLAYWRIGHT_DIR);
  const examplePath = path.join(root, 'test/example');
  // The command window starts exactly where setup ends, so the two phases tile the slot with no uncharged gap.
  const commandStart = () => setupEnd ?? { ns: started, wall: wallStarted };
  const workRemaining = () => remainingIn(commandStart().ns, commandStart().wall, slot.work_ms);
  const commandRemaining = () => remainingIn(commandStart().ns, commandStart().wall, slot.command_ms);
  const workDeadline = () => ceilMs(commandStart().ns) + slot.work_ms;
  try {
    // Phase 1: fresh database setup, bounded and charged on its own, before any browser deadline starts.
    let setup = null;
    try { setup = await d.runTree('mix', ['ecto.setup'], examplePath, env, tempPaths.setup_log, remainingIn(started, wallStarted, slot.setup_ms)); }
    finally {
      setupEnd = { ns: mono(), wall: wallNow() };
      attempt.setup_timing = { started_monotonic_ns: started.toString(), ended_monotonic_ns: setupEnd.ns.toString(), execution_ms: ceilMs(setupEnd.ns - started), wall_ms: Math.ceil(setupEnd.wall - wallStarted) };
      attempt.setup_charge_ms = Math.max(attempt.setup_timing.execution_ms, attempt.setup_timing.wall_ms);
    }
    attempt.setup = setup; attempt.database.setup_exit_code = setup.exit_code;
    if (setup.exit_code !== 0 || setup.timed_out) throw new Error(`fresh database setup failed${setup.timed_out ? ' at its setup deadline' : ` with exit ${setup.exit_code ?? 'null'}`}`);
    if (attempt.setup_charge_ms > slot.setup_ms) throw new Error(`fresh database setup overran its frozen ${slot.setup_ms} ms ceiling`);
    // Phase 2: app boot, the CLI and owned cleanup, inside command_ms.
    const appFd = fs.openSync(tempPaths.app_log, 'w');
    try { app = d.spawnApp('mix', ['phx.server'], { cwd: examplePath, env, stdio: ['ignore', appFd, appFd], detached: true }); }
    finally { fs.closeSync(appFd); }
    attempt.server.app_pid = app.pid ?? null;
    attempt.server.http_status = app.pid ? await d.waitReady(app, `http://127.0.0.1:${slot.port}/`, workDeadline()) : null;
    if (attempt.server.http_status !== 200) throw new Error('fresh app did not return HTTP 200 before the reserved work deadline');
    const installed = readJson(path.join(playwrightDir, 'node_modules/@playwright/test/package.json')).version;
    if (installed !== freeze.tools.playwright) throw new Error(`installed Playwright ${installed} differs from the frozen ${freeze.tools.playwright}`);
    attempt.toolchain.playwright = installed;
    if (workRemaining() <= 0) throw new Error('the reserved work deadline passed before browser launch');
    if (slot.stage === 'second') {
      const absenceLog = path.join(tempRoot, 'prior-collision-absence.log');
      attempt.prior_collision_absence = d.captureAccount({ database, email: loadControlAccount(slot.project, 'collision'), env, cwd: examplePath, log: absenceLog, deadline: workDeadline() });
      attempt.files.prior_collision_absence = receiptFile(rawDir, 'prior collision absence', (() => { const target = path.join(rawAttempt, 'prior-collision-absence.log'); fs.copyFileSync(absenceLog, target, fs.constants.COPYFILE_EXCL); return target; })());
      if (attempt.prior_collision_absence.count !== 0) throw new Error('prior collision account is not absent from the newly created database');
    }
    attempt.browser.launched = true; attempt.playwright_cli.launched = true; attempt.lifecycle.playwright_cli_processes = 1;
    const args = ['test', freeze.selection.spec, ...slot.argv, `--output=${outputTemp}`];
    attempt.browser_command_argv = args;
    const browser = await d.runTree(path.join(playwrightDir, 'node_modules/.bin/playwright'), args, playwrightDir, {
      ...env, CI: 'true', SIGRA_EXAMPLE_URL: `http://127.0.0.1:${slot.port}`, SIGRA_PLAYWRIGHT_JSON: reportTemp, SIGRA_PLAYWRIGHT_FAILURE_JSONL: jsonlTemp,
      SIGRA_REGISTRATION_CONTROL_STAGE: slot.control_stage, SIGRA_CONTROL_RUN_ID: `${slot.id.toLowerCase()}-${crypto.randomUUID()}`,
      SIGRA_CONTROL_ACCOUNT_PREFIX: 'platform-admin+sigra-253-control', PLAYWRIGHT_HTML_OUTPUT_DIR: path.join(tempRoot, 'html-report')
    }, tempPaths.test_log, workRemaining());
    attempt.test_command = browser; attempt.browser.exit_code = browser.exit_code; attempt.playwright_cli.exit_code = browser.exit_code; attempt.lifecycle.cli_pid = browser.pid ?? null;
    if (browser.timed_out) throw new Error('native Playwright command reached the reserved work deadline');
    if (!fs.existsSync(reportTemp) || fs.statSync(reportTemp).size === 0) throw new Error('native Playwright JSON report is absent or empty');
    const report = readJson(reportTemp);
    const tests = playReportTests(report);
    attempt.assertion_failure_observed = loadR2AssertionFailure(slot, tests);
    for (const item of tests) for (const attachment of item.attachments ?? []) {
      if (attachment.name !== 'trace' && !String(attachment.path ?? '').endsWith('trace.zip')) continue;
      if (!attachment.path || !fs.existsSync(attachment.path)) throw new Error(`native trace attachment for ${item.title} is missing`);
      const target = path.join(rawAttempt, `trace-${attempt.traces.length + 1}.zip`);
      const trace = d.sanitizeTrace(attachment.path, target);
      attempt.traces.push({ ...receiptFile(rawDir, 'sanitized native trace', target), title: item.title, project: item.project, sanitization: trace });
      attachment.path = path.relative(root, target);
    }
    attempt.files.traces = attempt.traces;
    const safeReport = path.join(rawAttempt, 'playwright-report.json');
    fs.writeFileSync(safeReport, `${JSON.stringify(sanitizeReportText(report), null, 2)}\n`, { flag: 'wx' });
    attempt.files.playwright_report = receiptFile(rawDir, 'sanitized native Playwright report', safeReport);
    attempt.lifecycle.rows = tests.length;
    attempt.lifecycle.worker_indexes = [...new Set(tests.flatMap((item) => (Number.isInteger(item.worker_index) ? [item.worker_index] : [])))].sort((a, b) => a - b);
    attempt.lifecycle.context_ids = tests.flatMap((item) => controlAnnotations(item, 'sigra-registration-control-context'));
    attempt.lifecycle.projects_run = [...new Set(tests.map((item) => item.project))];
    attempt.registration.server_post_confirmed = /POST \/users\/log_in/.test(fs.existsSync(tempPaths.app_log) ? fs.readFileSync(tempPaths.app_log, 'utf8') : '');
    if (slot.stage === 'second') {
      const createdLog = path.join(tempRoot, 'created-account.log');
      attempt.created_account = d.captureAccount({ database, email: loadControlAccount(slot.project, 'collision'), env, cwd: examplePath, log: createdLog, deadline: workDeadline() + 5000 });
      attempt.files.created_account = receiptFile(rawDir, 'created account', (() => { const target = path.join(rawAttempt, 'created-account.log'); fs.copyFileSync(createdLog, target, fs.constants.COPYFILE_EXCL); return target; })());
    }
    attempt.observed_outcome = 'native_report_pending_validation';
  } catch (error) { terminalError = error.message; }
  finally {
    await d.stopApp(app);
    if (fs.existsSync(tempPaths.app_log)) attempt.log_redactions_app = sanitizeCommandLog(tempPaths.app_log);
    const cleanupRemaining = commandRemaining();
    if (cleanupRemaining <= 0) terminalError = [terminalError, `owned cleanup exceeded the ${slot.command_ms} ms command limit`].filter(Boolean).join('; ');
    const drop = await d.runTree('mix', ['ecto.drop', '--quiet'], examplePath, env, tempPaths.drop_log, Math.max(LOAD_DROP_FLOOR_MS, Math.min(7000, cleanupRemaining - 5000)));
    attempt.database.drop_exit_code = drop.exit_code; attempt.drop_command = drop;
    if (drop.exit_code !== 0 || drop.timed_out) terminalError = [terminalError, `database drop failed${drop.timed_out ? ' at cleanup deadline' : ` with exit ${drop.exit_code ?? 'null'}`}`].filter(Boolean).join('; ');
    if (drop.exit_code === 0 && !drop.timed_out) {
      try { attempt.database.absence_receipt = d.captureAbsence({ database, env, cwd: examplePath, log: path.join(tempRoot, 'database-absence.log'), deadline: Math.max(ceilMs(commandStart().ns) + slot.command_ms, ceilMs(mono()) + LOAD_ABSENCE_FLOOR_MS) }); }
      catch (error) { terminalError = [terminalError, `independent database absence query failed: ${error.message}`].filter(Boolean).join('; '); }
    }
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    if (!fs.existsSync(tempPaths[name])) fs.writeFileSync(tempPaths[name], `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    const target = path.join(rawAttempt, `${name.replaceAll('_', '-')}.log`);
    fs.copyFileSync(tempPaths[name], target, fs.constants.COPYFILE_EXCL);
    attempt.files[name] = receiptFile(rawDir, `sanitized ${name}`, target);
  }
  const absenceTemp = path.join(tempRoot, 'database-absence.log');
  if (fs.existsSync(absenceTemp)) {
    const target = path.join(rawAttempt, 'database-absence.log');
    fs.copyFileSync(absenceTemp, target, fs.constants.COPYFILE_EXCL);
    attempt.files.database_absence = receiptFile(rawDir, 'owned database absence query log', target);
  }
  // Diagnostics are preserved before the temp tree is removed, on a pass, an assertion failure and a deadline kill alike.
  try {
    attempt.diagnostics = preserveAttemptDiagnostics({ outputDir: outputTemp, jsonlPath: jsonlTemp, rawAttempt, rawDir });
    attempt.per_test_rows = attempt.diagnostics.jsonl ? perTestRowsFromJsonl(fs.readFileSync(path.join(rawDir, attempt.diagnostics.jsonl.path), 'utf8')) : [];
  } catch (error) { terminalError = [terminalError, `per-test diagnostics could not be preserved: ${error.message}`].filter(Boolean).join('; '); }
  const ended = mono();
  const wallEnded = wallNow();
  attempt.ended_monotonic_ns = ended.toString();
  attempt.execution_duration_ms = ceilMs(ended - started);
  attempt.wall_duration_ms = Math.ceil(wallEnded - wallStarted);
  const command = commandStart();
  attempt.command_timing = { started_monotonic_ns: command.ns.toString(), ended_monotonic_ns: ended.toString(), execution_ms: ceilMs(ended - command.ns), wall_ms: Math.ceil(wallEnded - command.wall) };
  attempt.command_charge_ms = Math.max(attempt.command_timing.execution_ms, attempt.command_timing.wall_ms);
  attempt.charged_duration_ms = (attempt.setup_charge_ms ?? 0) + attempt.command_charge_ms;
  attempt.host.suspension_detected = [attempt.setup, attempt.test_command, attempt.drop_command].some((result) => result?.suspended === true)
    || Math.abs(attempt.wall_duration_ms - attempt.execution_duration_ms) > TREE_SUSPEND_GAP_MS;
  if (attempt.host.suspension_detected) terminalError = [terminalError, 'host suspension (system sleep or a stalled runner event loop) was detected during the native window, so its timings cannot be accepted'].filter(Boolean).join('; ');
  attempt.host.holder_alive_at_end = Number.isInteger(hostAwake?.holder_pid) ? Boolean(d.holderAlive(hostAwake.holder_pid)) : null;
  if (attempt.host.holder_alive_at_end === false) terminalError = [terminalError, 'the caffeinate sleep-assertion holder was lost during the native window (holder not running), so sleep was no longer prevented'].filter(Boolean).join('; ');
  if (attempt.command_charge_ms > slot.command_ms) terminalError = [terminalError, `native command exceeded its frozen ${slot.command_ms} ms command window`].filter(Boolean).join('; ');
  if (attempt.charged_duration_ms > reserve) terminalError = [terminalError, `native slot exceeded its frozen ${reserve} ms reservation`].filter(Boolean).join('; ');
  const validation = verifyNativeLoadAttemptR3(attempt, freeze, rawDir);
  if (!validation.ok) terminalError = [terminalError, ...validation.errors].filter(Boolean).join('; ');
  evidence.reservation = null;
  evidence.limits.charged_duration_ms += attempt.charged_duration_ms;
  if (attempt.playwright_cli.launched) evidence.limits.physical_playwright_cli_launches += 1;
  evidence.attempts.push(attempt);
  if (slot.retry) {
    evidence.limits.infra_retry.used = 1;
    evidence.infrastructure_retry = { ...evidence.infrastructure_retry, used: true, diagnostic };
  }
  if (terminalError) {
    // Only a host fault (suspension, lost caffeinate holder, host failure before any test ran) with no observed
    // assertion failure is infrastructure, and only the first one is retry-eligible; everything else is terminal.
    const cause = attempt.host.suspension_detected ? 'host_sleep'
      : attempt.host.holder_alive_at_end === false ? 'holder_lost'
        : (attempt.lifecycle.rows === 0 && attempt.setup?.error ? 'host_failure' : null);
    const retryable = Boolean(cause) && !attempt.assertion_failure_observed && !slot.retry
      && evidence.approval?.retry_granted === 1 && evidence.limits.infra_retry?.used === 0;
    if (cause) evidence.infrastructure_halts.push({ slot_id: slot.id, cause, retryable, charged_ms: attempt.charged_duration_ms, assertion_failure_observed: attempt.assertion_failure_observed });
    evidence.stop_reason = terminalError;
    if (retryable) {
      evidence.status = 'halted_infrastructure'; attempt.observed_outcome = 'halted_infrastructure';
      evidence.infrastructure_retry = { eligible: true, halted_slot: slot.id, cause, used: false, diagnostic: null };
    } else { evidence.status = 'halted'; attempt.observed_outcome = 'halted'; }
    // Every terminal stop record lists what each finished test said, read from the preserved per-test JSONL.
    evidence.stop_record = {
      slot_id: slot.id, observed_outcome: attempt.observed_outcome, stop_reason: terminalError, cli_launched: attempt.playwright_cli.launched === true,
      setup_charge_ms: attempt.setup_charge_ms ?? 0, command_charge_ms: attempt.command_charge_ms, charged_duration_ms: attempt.charged_duration_ms, per_test_rows: attempt.per_test_rows
    };
  } else {
    attempt.observed_outcome = 'native_rows_accepted';
    const count = loadR3AcceptedAttempts(evidence).length;
    evidence.status = count === 4 ? 'complete' : count === 1 ? 'first_complete' : 'second_partial';
  }
  writeLoadRecoveryEvidence(evidenceFile, root, evidence, d);
  fs.rmSync(tempRoot, { recursive: true, force: true });
  if (terminalError) throw new Error(terminalError);
  return { status: evidence.status, slot: slot.id, rows: attempt.lifecycle.rows, charged_duration_ms: attempt.charged_duration_ms, physical_playwright_cli_launches: evidence.limits.physical_playwright_cli_launches };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.mode === 'create-load-recovery') {
    if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_RECOVERY_FREEZE_PATH)) throw new Error('load recovery freeze output must use the reviewed phase artifact path');
    const freeze = createLoadRecoveryFreeze(args.output);
    console.log(`load recovery freeze created before native results: ${path.relative(ROOT, args.output)} (${freeze.ledger.prior_charge_ms} ms carried; four unused reservations; retry unavailable)`);
    return;
  }
  if (args.mode === 'create-load-recovery-r2') {
    if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_R2_FREEZE_PATH)) throw new Error('R2 load recovery freeze output must use the reviewed phase artifact path');
    const freeze = createLoadRecoveryFreezeR2(args.output);
    console.log(`R2 load recovery freeze created before native results: ${path.relative(ROOT, args.output)} (${freeze.ledger.prior_charge_ms} ms carried; ${freeze.ledger.prior_playwright_cli_launches} launches; seven spent; no capacity granted)`);
    return;
  }
  if (args.mode === 'create-load-recovery-r3') {
    if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_R3_FREEZE_PATH)) throw new Error('R3 load recovery freeze output must use the reviewed phase artifact path');
    const freeze = createLoadRecoveryFreezeR3(args.output);
    console.log(`R3 load recovery freeze created before native results: ${path.relative(ROOT, args.output)} (${freeze.ledger.prior_charge_ms} ms carried; ${freeze.ledger.prior_playwright_cli_launches} launches; eight spent; no capacity granted)`);
    return;
  }
  if (args.mode === 'record-budget-approval') {
    const record = recordBudgetApproval({ decision: args.decision, budgetFile: args.budget, freezeFile: args.freeze, outputFile: args.output, decisionText: args.decisionText });
    console.log(`R2 budget approval recorded (${record.decision}; retry_granted=${record.retry_granted}; shared cap ${record.caps.shared_cap_ms} ms): ${path.relative(ROOT, args.output)}`);
    return;
  }
  if (args.mode === 'preflight-host-sleep') { console.log(await preflightHostSleep()); return; }
  const isR2Freeze = (file) => file && path.resolve(file) === path.resolve(ROOT, LOAD_R2_FREEZE_PATH);
  const isR3Freeze = (file) => file && path.resolve(file) === path.resolve(ROOT, LOAD_R3_FREEZE_PATH);
  if (args.mode === 'init-load-recovery') {
    if (isR3Freeze(args.freeze)) {
      if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_R3_EVIDENCE_PATH)) throw new Error('R3 load recovery evidence must use the reviewed R3 artifact path');
      const evidence = initializeLoadRecoveryEvidenceR3(args.freeze, args.output);
      console.log(`R3 native load recovery ledger initialized before setup: ${path.relative(ROOT, args.output)} (${evidence.limits.charged_duration_ms} ms carried; ${evidence.limits.used_slots.length} spent reservations; decision=${evidence.approval.decision})`);
      return;
    }
    if (isR2Freeze(args.freeze)) {
      if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_R2_EVIDENCE_PATH)) throw new Error('R2 load recovery evidence must use the reviewed R2 artifact path');
      const evidence = initializeLoadRecoveryEvidenceR2(args.freeze, args.output);
      console.log(`R2 native load recovery ledger initialized before setup: ${path.relative(ROOT, args.output)} (${evidence.limits.charged_duration_ms} ms carried; ${evidence.limits.used_slots.length} spent reservations; decision=${evidence.approval.decision})`);
      return;
    }
    if (path.resolve(args.freeze) !== path.resolve(ROOT, LOAD_RECOVERY_FREEZE_PATH) || path.resolve(args.output) !== path.resolve(ROOT, LOAD_RECOVERY_EVIDENCE_PATH)) throw new Error('load recovery evidence must use the reviewed phase artifact paths');
    const evidence = initializeLoadRecoveryEvidence(args.freeze, args.output);
    console.log(`native load recovery ledger initialized before setup: ${path.relative(ROOT, args.output)} (${evidence.limits.charged_duration_ms} ms carried; ${evidence.limits.used_slots.length} spent reservations; retry_available=0)`);
    return;
  }
  if (args.mode === 'check-load-recovery-freeze') {
    const ok = isR3Freeze(args.freeze) ? checkLoadRecoveryFreezeFileR3(args.freeze).ok : isR2Freeze(args.freeze) ? checkLoadRecoveryFreezeFileR2(args.freeze).ok : checkLoadRecoveryFreezeFile(args.freeze).ok;
    if (!ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'prepare-load-recovery') {
    if (isR3Freeze(args.freeze)) {
      if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_R3_EVIDENCE_PATH)) throw new Error('R3 load recovery evidence must use the reviewed R3 artifact path');
      console.log(JSON.stringify(await prepareLoadRecoveryR3(args.freeze, args.output)));
      return;
    }
    if (isR2Freeze(args.freeze)) {
      if (path.resolve(args.output) !== path.resolve(ROOT, LOAD_R2_EVIDENCE_PATH)) throw new Error('R2 load recovery evidence must use the reviewed R2 artifact path');
      console.log(JSON.stringify(await prepareLoadRecoveryR2(args.freeze, args.output)));
      return;
    }
    if (path.resolve(args.freeze) !== path.resolve(ROOT, LOAD_RECOVERY_FREEZE_PATH)) throw new Error('load recovery preparation accepts only the reviewed freeze paths');
    console.log(JSON.stringify(await prepareLoadRecovery(args.freeze, args.output)));
    return;
  }
  if (args.mode === 'run-load-recovery') {
    if (isR3Freeze(args.freeze)) { console.log(JSON.stringify(await runLoadRecoverySlotR3(args.freeze, args.slot, args.output, ROOT, { diagnosticFile: args.diagnostic ?? null }))); return; }
    if (isR2Freeze(args.freeze)) { console.log(JSON.stringify(await runLoadRecoverySlotR2(args.freeze, args.slot, args.output, ROOT, { diagnosticFile: args.diagnostic ?? null }))); return; }
    if (args.diagnostic) throw new Error('--diagnostic is only valid for the R2 infrastructure retry');
    console.log(JSON.stringify(await runLoadRecoverySlot(args.freeze, args.slot, args.output)));
    return;
  }
  if (args.mode === 'verify-load-recovery') {
    const r2 = path.resolve(args.evidence) === path.resolve(ROOT, LOAD_R2_EVIDENCE_PATH);
    const r3 = path.resolve(args.evidence) === path.resolve(ROOT, LOAD_R3_EVIDENCE_PATH);
    const verify = r3 ? verifyLoadRecoveryFileR3 : r2 ? verifyLoadRecoveryFileR2 : verifyLoadRecoveryFile;
    if (!verify(args.evidence, args.stage).ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'create-control-recovery') {
    if (path.resolve(args.output) !== path.resolve(ROOT, CONTROL_RECOVERY_FREEZE_PATH)) throw new Error('control recovery freeze output must use the reviewed phase artifact path');
    const freeze = createControlRecoveryFreeze(args.output);
    console.log(`control recovery freeze created before native results: ${path.relative(ROOT, args.output)} (${freeze.ledger.prior_charge_ms} ms carried; five new reservations; retry unavailable)`);
    return;
  }
  if (args.mode === 'init-control-recovery') {
    if (path.resolve(args.freeze) !== path.resolve(ROOT, CONTROL_RECOVERY_FREEZE_PATH)
      || path.resolve(args.output) !== path.resolve(ROOT, CONTROL_RECOVERY_EVIDENCE_PATH)) throw new Error('control recovery evidence must use the reviewed phase artifact paths');
    const evidence = initializeControlRecoveryEvidence(args.freeze, args.output);
    console.log(`native control recovery ledger initialized before setup: ${path.relative(ROOT, args.output)} (${evidence.limits.charged_duration_ms} ms carried; retry_available=0)`);
    return;
  }
  if (args.mode === 'check-control-recovery-freeze') {
    const result = checkControlRecoveryFreezeFile(args.freeze);
    if (!result.ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'run-control-recovery') {
    const result = await runControlRecoverySlot(args.freeze, args.slot, args.output);
    console.log(JSON.stringify(result));
    return;
  }
  if (args.mode === 'verify-control-recovery') {
    const result = verifyControlRecoveryFile(args.evidence, args.stage);
    if (!result.ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'create-revision') {
    const freeze = createRevision(args.output);
    console.log(`registration revision frozen before results: ${path.relative(ROOT, args.output)} (${freeze.source.checkout_head})`);
    return;
  }
  if (args.mode === 'freeze-controls') {
    const freeze = createControlFreeze(args.prior, args.output);
    console.log(`registration control source frozen before native outcomes: ${path.relative(ROOT, args.output)} (${freeze.source.checkout_head}; 6 regular slots; retry unavailable)`);
    return;
  }
  if (args.mode === 'init-controls') {
    const evidence = initializeControlEvidence(args.freeze, args.output);
    console.log(`additive Plan 16 control ledger initialized: ${path.relative(ROOT, args.output)} (${evidence.limits.charged_duration_ms} ms prior charge; ${evidence.limits.physical_browser_launches} global launches)`);
    return;
  }
  if (args.mode === 'run-control-revision') {
    const result = await runControlRevision(args.freeze, args.slot, args.evidence, args.stage);
    console.log(JSON.stringify(result));
    return;
  }
  if (args.mode === 'verify-controls') {
    const result = verifyControlFile(args.evidence, args.stage);
    if (!result.ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'create-infrastructure-retry') {
    const result = createInfrastructureRetry(args.predecessor, args.evidence, args.review, args.output, args.reservation);
    console.log(`one-use infrastructure retry frozen: ${path.relative(ROOT, args.output)} (${result.freeze.source.checkout_head})`);
    return;
  }
  if (args.mode === 'refresh-infrastructure-retry') {
    const freeze = refreshInfrastructureRetry(args.predecessor, args.output);
    console.log(`infrastructure retry source revision refreshed without new capacity: ${path.relative(ROOT, args.output)} (${freeze.source.checkout_head})`);
    return;
  }
  if (args.mode === 'prepare-revision') {
    const result = prepareRevision(args.freeze, args.evidence);
    console.log(JSON.stringify(result));
    return;
  }
  if (args.mode === 'run-revision') {
    const result = await runRevision(args.freeze, args.slot, args.evidence);
    console.log(JSON.stringify(result));
    return;
  }
  if (args.mode === 'verify-saved-native') {
    const result = verifyRevisionFile(args.evidence, ROOT, { acceptedOnly: true });
    if (!result.ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'verify-revision') {
    const result = verifyRevisionFile(args.evidence);
    if (!result.ok) process.exitCode = 3;
    return;
  }
  if (args.mode === 'create-freeze') {
    const freeze = createFreeze(args.output);
    console.log(`recovery freeze created before browser results: ${path.relative(ROOT, args.output)} (${freeze.source.checkout_head})`);
    return;
  }
  if (args.mode === 'run-recovery') {
    const result = await runRecovery(args.freeze, args.evidence);
    console.log(JSON.stringify(result));
    return;
  }
  const result = verifyDiagnosticFile(args.evidence);
  if (!result.ok) process.exitCode = 3;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 3; });
}
