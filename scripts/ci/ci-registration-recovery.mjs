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
  'test/example/priv/playwright/playwright.config.ts',
  'test/example/priv/playwright/tests/admin-eval.spec.ts',
  'test/example/priv/playwright/helpers/adminFlows.ts',
  'test/example/priv/playwright/package-lock.json',
  '.github/workflows/ci.yml'
];
const TOTAL_CAP_MS = 58 * 60 * 1000;
const D19_CAP_MS = 20 * 60 * 1000;
const PROJECT_SLOT_MS = 2 * 60 * 1000;
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

function checkCleanCandidate(root) {
  const head = git(['-C', root, 'rev-parse', 'HEAD']);
  const status = run('git', ['-C', root, 'status', '--porcelain', '--untracked-files=all']);
  if (status.status !== 0) throw new Error('cannot read checkout status');
  if (status.stdout.trim()) throw new Error('candidate checkout must be clean before freezing or running recovery');
  return head;
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
          found.push({ title: spec.title, file: spec.file ?? suite.file ?? '', project: test.projectName ?? '', status: result.status, duration: result.duration });
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
  if (fs.existsSync(output)) throw new Error(`refusing to overwrite recovery freeze: ${output}`);
  const head = checkCleanCandidate(root);
  const preflightPath = path.join(root, PHASE_DIR, '253-09-PREFLIGHT-SETUP.json');
  const preflight = readJson(preflightPath);
  const runnerFailurePath = path.join(root, PHASE_DIR, '253-09-RUNNER-PREFLIGHT-FAILURE.json');
  const runnerFailure = readJson(runnerFailurePath);
  if (preflight.schema_version !== 'sigra.phase253.registration-preflight/v1' || preflight.status !== 'passed' || preflight.exit_code !== 0 || preflight.playwright_version !== '1.59.1') {
    throw new Error('measured lockfile Playwright restore is missing or failed');
  }
  if (Math.ceil(Number(BigInt(preflight.ended_monotonic_ns) - BigInt(preflight.started_monotonic_ns)) / 1e6) !== preflight.duration_ms) {
    throw new Error('preflight setup receipt duration does not match its monotonic timestamps');
  }
  if (runnerFailure.schema_version !== 'sigra.phase253.registration-runner-preflight-failure/v1' || runnerFailure.browser_launches !== 0 || runnerFailure.child_processes_spawned?.length !== 0 || runnerFailure.slot !== 'D19-DIAG-01') {
    throw new Error('the preserved runner timeout receipt is missing, malformed, or claims a browser launch');
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
      { path: `${PHASE_DIR}/253-RECOVERY-REGISTRATION-FREEZE-REVISION-03.json`, sha256: 'e57467bb0ce7b57337cd36dd67922d4c63582710c17dcd7073a5be9348a8aa00', commit: '094dc5a7913a24fd0126e321a9a854eec7bf8130' }
    ],
    ledger: {
      slots, max_launches: 19, max_charged_duration_ms: TOTAL_CAP_MS,
      prelaunch_setup: {
        components: [
          { path: path.relative(root, preflightPath), sha256: fileHash(preflightPath), duration_ms: preflight.duration_ms, purpose: 'locked Playwright npm ci restore' },
          { path: path.relative(root, runnerFailurePath), sha256: fileHash(runnerFailurePath), duration_ms: runnerFailure.tool_reported_wall_time_ms, purpose: 'runner timeout preflight failure before child process startup' }
        ],
        duration_ms: preflight.duration_ms + runnerFailure.tool_reported_wall_time_ms,
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
  if (thrownError) return { exit_code: null, signal: null, error: thrownError.message };
  return { exit_code: result.status, signal: result.signal, error: result.error?.message ?? null };
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
  const attemptDir = path.join(baseDir, slot.id);
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
  const appEnv = {
    ...process.env, MIX_ENV: 'dev', PGHOST: process.env.PGHOST ?? '127.0.0.1',
    PGPORT: process.env.PGPORT ?? '58624', PGUSER: process.env.PGUSER ?? 'postgres',
    PGPASSWORD: process.env.PGPASSWORD ?? 'postgres', PGDATABASE: databaseName,
    PORT: String(project.port), SIGRA_EXAMPLE_BIND: '127.0.0.1'
  };
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
      evidence.prior_zero_launch_start = {
        freeze_path: evidence.freeze_path, freeze_sha256: evidence.freeze_sha256,
        source_commit: evidence.source?.checkout_head,
        preservation_commit: '6079a15aa'
      };
      evidence.preflight_failure = {
        path: `${PHASE_DIR}/253-09-RUNNER-PREFLIGHT-FAILURE.json`,
        sha256: fileHash(path.join(root, PHASE_DIR, '253-09-RUNNER-PREFLIGHT-FAILURE.json')),
        charged_duration_ms: freeze.ledger.prelaunch_setup.duration_ms,
        browser_launches: 0
      };
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
