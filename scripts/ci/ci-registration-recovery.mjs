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

export function assertDirtyConfigPreserved(root) {
  const file = path.join(root, DIRTY_CONFIG.path);
  const bytes = fs.readFileSync(file);
  if (sha256(bytes) !== DIRTY_CONFIG.sha256 || git(['-C', root, 'hash-object', file]) !== DIRTY_CONFIG.blob) {
    throw new Error('the unrelated planning config no longer matches its authorized SHA-256 and Git blob');
  }
  if (!bytes.equals(readGitBlob(root, DIRTY_CONFIG.ref))) {
    throw new Error('the unrelated planning config does not match the exact bytes in its preservation ref');
  }
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
            status: result.status, duration: result.duration, result_count: test.results?.length ?? 0,
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

export function portAvailable(port) {
  return new Promise((resolve) => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(false); });
    socket.once('error', (error) => { socket.destroy(); resolve(error.code === 'ECONNREFUSED'); });
    socket.setTimeout(1500, () => { socket.destroy(); resolve(false); });
  });
}

export async function waitReady(child, url, deadline) {
  while (Number(process.hrtime.bigint()) / 1e6 < deadline) {
    if (child.exitCode !== null || child.signalCode !== null) return null;
    const status = await httpStatus(url);
    if (status === 200) return status;
    const remaining = Math.max(0, deadline - Number(process.hrtime.bigint()) / 1e6);
    await new Promise((resolve) => setTimeout(resolve, Math.min(250, remaining)));
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

export function runLoggedTree(program, args, cwd, env, log, timeoutMs, cleanupGraceMs = 250) {
  return new Promise((resolve) => {
    const started = process.hrtime.bigint();
    const fd = fs.openSync(log, 'w');
    let child;
    let settled = false;
    let timedOut = false;
    let error = null;
    let signal = null;
    let exitCode = null;
    let killTimer = null;
    const finish = () => {
      if (settled) return;
      settled = true;
      clearTimeout(deadlineTimer);
      clearTimeout(killTimer);
      fs.closeSync(fd);
      const redactions = sanitizeCommandLog(log);
      resolve({
        exit_code: exitCode, signal, error, timed_out: timedOut,
        duration_ms: Math.ceil(Number(process.hrtime.bigint() - started) / 1e6),
        ...redactions
      });
    };
    const terminateGroup = (name) => {
      if (!child?.pid) return;
      try { process.kill(-child.pid, name); } catch {
        try { child.kill(name); } catch { /* already exited */ }
      }
    };
    const deadlineTimer = setTimeout(() => {
      timedOut = true;
      terminateGroup('SIGTERM');
      killTimer = setTimeout(() => terminateGroup('SIGKILL'), Math.max(1, cleanupGraceMs));
    }, Math.max(1, Math.floor(timeoutMs)));
    try {
      child = spawn(program, args, { cwd, env, stdio: ['ignore', fd, fd], detached: true });
      child.once('error', (cause) => { error = cause.message; });
      child.once('exit', (code, childSignal) => {
        exitCode = code;
        signal = childSignal;
      });
      child.once('close', finish);
    } catch (cause) {
      error = cause.message;
      finish();
    }
  });
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

export function verifyRevisionAttempt(attempt, freeze, baseDir) {
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!attempt || typeof attempt !== 'object') return { ok: false, errors: ['attempt is missing'] };
  const slot = freeze.ledger.slots.find((item) => item.id === attempt.slot_id);
  if (!slot) fail('attempt does not identify a frozen slot');
  else {
    if (slot.owner_plan !== 15 || slot.kind !== 'diagnostic' || slot.stage !== 'D19') fail('attempt consumed a slot not owned by plan15');
    if (attempt.project !== slot.project || attempt.sequence !== slot.sequence) fail('attempt identity differs from its frozen slot');
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
      const tests = playReportTests(report);
      if (!tests.length) fail('native Playwright report contains no results');
      const selected = tests.filter((item) => item.title === slot.title && item.project === attempt.project && path.basename(item.file) === 'admin-eval.spec.ts');
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

function verifyRevisionFile(evidenceFile, root = ROOT) {
  try {
    const evidence = readJson(evidenceFile);
    if (typeof evidence.freeze_path !== 'string' || !evidence.freeze_path) throw new Error('evidence does not name its frozen source');
    const freezePath = path.resolve(root, evidence.freeze_path);
    const freeze = readJson(freezePath);
    validateFrozenRevisionProvenance(root, freeze);
    const freezeFileHash = fileHash(freezePath);
    const result = verifyRevisionData(evidence, freeze, `${evidenceFile}.raw`, freezeFileHash);
    if (!result.ok) console.error(`native revision receipt rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`native revision receipts verified: ${evidence.attempts.length}/2 plan15 diagnostics; ${evidence.limits.browser_launches} launches; ${evidence.limits.charged_duration_ms} ms charged; status=${evidence.status}`);
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
    || failedDark.native_report_present !== false
    || failedDark.limits?.retry_count_used !== 1 || failedDark.limits?.retry_count_available !== 0
    || cleanup.original_native_slot_still_failed !== true || cleanup.database_absent_confirmed !== true
    || cleanup.cleanup_duration_ms !== 112 || cleanup.cumulative_charge_ms_including_post_halt_cleanup !== 243044) {
    throw new Error('preserved native history differs from the exact failed/accepted charge and retry records');
  }
  const artifacts = CONTROL_RECOVERY_PRIOR.map(({ file }) => ({ path: file, sha256: fileHash(path.join(root, file)) }));
  if (artifacts.some((item) => !item.sha256)) throw new Error('a prior native record is missing an exact byte identity');
  return { ledger, artifacts, terminal, original, accepted, failedDark, cleanup, charges };
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
    started_monotonic_ns: started.toString(), database: { name: database, setup_exit_code: null, drop_exit_code: null },
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
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log']) {
    if (!fs.existsSync(tempPaths[name])) fs.writeFileSync(tempPaths[name], `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    const target = path.join(rawAttempt, `${name.replaceAll('_', '-')}.log`);
    fs.copyFileSync(tempPaths[name], target, fs.constants.COPYFILE_EXCL);
    attempt.files[name] = receiptFile(rawDir, `sanitized ${name}`, target);
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
  for (const name of ['setup_log', 'app_log', 'test_log', 'drop_log', 'playwright_report']) {
    const reference = attempt.files?.[name]; const file = confinedFile(baseDir, reference);
    if (!file || !fs.existsSync(file)) { fail(`sanitized native ${name.replaceAll('_', ' ')} is missing`); continue; }
    if (!reference.sha256 || fileHash(file) !== reference.sha256) fail(`sanitized native ${name.replaceAll('_', ' ')} digest mismatch`);
    if (!fs.statSync(file).size) fail(`sanitized native ${name.replaceAll('_', ' ')} is empty`);
    if (name.endsWith('_log') && /(?:=== Demo Credentials ===|secret_key_base: "(?!\[REDACTED\])|Set-Cookie:|authorization:)/i.test(fs.readFileSync(file, 'utf8'))) fail(`${name} contains an unsanitized credential block or auth header`);
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
    started_monotonic_ns: started.toString(), database: { name: db, setup_exit_code: null, drop_exit_code: null },
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
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `physical Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
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

async function main() {
  const args = parseArgs(process.argv.slice(2));
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
