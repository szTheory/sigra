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
const RETRY_MARKER_PATH = `${PHASE_DIR}/253-15-SHARED-RETRY-USED.json`;
const DIRTY_CONFIG = {
  path: '.planning/config.json', status: ' M', porcelain: ' M .planning/config.json',
  ref: 'refs/gsd/phase253-recovery-execution-unrelated-config',
  blob: 'ab8aa3007f17294e2f224d4ac8482522b79bda24',
  sha256: '8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d'
};
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

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

function assertDirtyConfigPreserved(root) {
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
            error: result.error ?? null, attachments: result.attachments ?? [] });
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

function portAvailable(port) {
  return new Promise((resolve) => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(false); });
    socket.once('error', (error) => { socket.destroy(); resolve(error.code === 'ECONNREFUSED'); });
    socket.setTimeout(1500, () => { socket.destroy(); resolve(false); });
  });
}

async function waitReady(child, url, deadline) {
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
  // Scrub Mix's development configuration output before a receipt hashes it.
  // The persisted log is the input to every later digest check.
  let redactedSecretFields = 0;
  const original = fs.readFileSync(log, 'utf8');
  const sanitized = original.replace(/((?:"?secret_key_base"?|:secret_key_base)\s*(?::|=>)\s*")((?:\\.|[^"\\])*)(")/g, (_match, prefix, value, suffix) => {
    if (value === '[REDACTED]') return `${prefix}${value}${suffix}`;
    redactedSecretFields += 1;
    return `${prefix}[REDACTED]${suffix}`;
  });
  if (sanitized !== original) fs.writeFileSync(log, sanitized);
  if (thrownError) return { exit_code: null, signal: null, error: thrownError.message, redacted_secret_fields: redactedSecretFields };
  return { exit_code: result.status, signal: result.signal, error: result.error?.message ?? null, redacted_secret_fields: redactedSecretFields };
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
    const receipt = { name: item.name, argv: [item.command, ...item.args], exit_code: result.exit_code, duration_ms: duration, log: receiptFile(`${evidenceFile}.raw`, item.name, log), redacted_secret_fields: result.redacted_secret_fields };
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

function verifyRevisionData(evidence, freeze, baseDir) {
  const errors = [];
  if (evidence?.schema_version !== REPLAN_SCHEMA || evidence.freeze_sha256 !== freeze?.freeze_sha256) errors.push('evidence does not match the frozen revision');
  if (evidence?.source?.checkout_head !== freeze?.source?.checkout_head || JSON.stringify(evidence?.source?.blobs) !== JSON.stringify(freeze?.source?.blobs)) errors.push('evidence source identity differs from the frozen revision');
  if (evidence.historical?.preceding_order !== 'unknown' || evidence.limits?.historical_charge_ms !== freeze?.ledger?.historical_charge_ms) errors.push('historical uncertainty or spent charge was not preserved');
  if (evidence.preparation_status !== 'passed') errors.push('common dependency preparation is missing or incomplete');
  if (!Array.isArray(evidence.attempts) || !Array.isArray(evidence.preparation_receipts)) errors.push('preparation or attempt ledger is absent');
  else {
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
    const prepCharge = evidence.preparation_receipts.reduce((sum, item) => sum + (Number(item.duration_ms) || 0), 0);
    if (prepCharge !== evidence.limits.preparation_charge_ms) errors.push('preparation charge does not match its command receipts');
    if (prepCharge > freeze.preparation.max_duration_ms) errors.push('common preparation exceeded its frozen 116,232 ms ceiling');
    if (attemptCharge + evidence.limits.historical_charge_ms + prepCharge !== evidence.limits.charged_duration_ms) errors.push('cumulative charged time does not match native receipt durations');
    if (evidence.limits.charged_duration_ms > freeze.ledger.d19.max_charged_duration_ms) errors.push('D-19 charged time exceeds its frozen 18-minute allowance');
    if (browserLaunches !== evidence.limits.browser_launches) errors.push('browser launch count differs from native receipts');
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
    observed_outcome: 'setup_failed', registration: { server_post_confirmed: false, success_flash_asserted: false }, files: {}, toolchain: evidence.toolchain
  };
  const paths = Object.fromEntries(['setup_log', 'app_log', 'test_log', 'drop_log'].map((name) => [name, path.join(attemptDir, `${name.replaceAll('_', '-')}.log`)]));
  const reportPath = path.join(attemptDir, 'playwright-report.json');
  const playwrightDir = path.join(root, 'test/example/priv/playwright');
  const exampleDir = path.join(root, 'test/example');
  let app = null; let terminalError = null;
  try {
    const setup = runLogged('mix', ['ecto.setup'], exampleDir, env, paths.setup_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
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
    const drop = runLogged('mix', ['ecto.drop', '--quiet'], exampleDir, env, paths.drop_log, Math.max(1, deadline - Number(process.hrtime.bigint()) / 1e6));
    attempt.database.drop_exit_code = drop.exit_code;
    if (drop.exit_code !== 0) terminalError = [terminalError, `database drop failed with exit ${drop.exit_code ?? 'null'}`].filter(Boolean).join('; ');
    try { fs.rmSync(env.MIX_BUILD_PATH, { recursive: true, force: true }); attempt.build_directory_removed = !fs.existsSync(env.MIX_BUILD_PATH); }
    catch (error) { attempt.build_directory_removed = false; terminalError = [terminalError, `Mix build cleanup failed: ${error.message}`].filter(Boolean).join('; '); }
  }
  for (const [name, file] of Object.entries(paths)) {
    if (!fs.existsSync(file)) fs.writeFileSync(file, `${name} command did not start${terminalError ? `: ${terminalError}` : ''}\n`);
    else if (!fs.statSync(file).size) fs.writeFileSync(file, `${name} command produced no output\n`);
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
  const checked = verifyRevisionData(evidence, freeze, rawBase);
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
    const loaded = loadRevisionEvidence(freezePath, evidenceFile, root);
    const freeze = loaded.freeze;
    const latest = loaded.evidence;
    const result = verifyRevisionData(latest, freeze, `${evidenceFile}.raw`);
    if (!result.ok) console.error(`native revision receipt rejected:\n- ${result.errors.join('\n- ')}`);
    else console.log(`native revision receipts verified: ${latest.attempts.length}/2 plan15 diagnostics; ${latest.limits.browser_launches} launches; ${latest.limits.charged_duration_ms} ms charged; status=${latest.status}`);
    return result;
  } catch (error) { console.error(`native revision receipt rejected: ${error.message}`); return { ok: false, errors: [error.message] }; }
}

export function attemptDirectory(baseDir, slotId, attemptNumber) {
  return path.join(baseDir, `${slotId}-attempt-${String(attemptNumber).padStart(2, '0')}`);
}

export function createAttemptDirectory(baseDir, slotId, attemptNumber = 1) {
  if (!/^[A-Z0-9-]+$/.test(slotId) || !Number.isInteger(attemptNumber) || attemptNumber < 1) throw new Error('invalid frozen attempt directory identity');
  const directory = path.join(baseDir, slotId, `attempt-${String(attemptNumber).padStart(2, '0')}`);
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
  if (args.mode === 'create-revision') {
    const freeze = createRevision(args.output);
    console.log(`registration revision frozen before results: ${path.relative(ROOT, args.output)} (${freeze.source.checkout_head})`);
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
