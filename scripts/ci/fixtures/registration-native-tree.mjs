// Synthetic committed-tree fixtures for the Phase 253 registration runner contracts.
//
// Everything here is TEST-ONLY. The helper builds a temporary Git repository, commits
// the sources the real verifier binds to, and writes internally consistent synthetic
// freeze / evidence / log / native-report files. It never copies or reads the active
// GSD phase records or refs, opens no socket, and starts no server, browser or database.
// Every artifact carries the `synthetic-native-fixture` provenance marker, which the live
// accepted-only predicates in ci-registration-recovery.mjs reject.
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const SYNTHETIC_LABEL = 'synthetic-native-fixture/v1';
export const FIXTURE_PHASE_DIR = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks';
export const SELECTED_TITLE = 'render bundle: board-mg-9/populated';
export const FIXTURE_PROJECTS = ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'];
export const FIXTURE_IDENTITY = { name: 'Synthetic Fixture', email: 'synthetic-fixture@example.invalid' };

const CI_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REPLAN_SCHEMA = 'sigra.phase253.registration-replan-evidence/v1';
const REPLAN_FREEZE_SCHEMA = 'sigra.phase253.registration-replan-freeze/v1';

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
// The two real, executed entrypoints are copied byte-for-byte; every other bound source is a
// small synthetic placeholder so the fixture needs no lockfile, workflow or Playwright tree.
const COPIED_SOURCES = {
  'scripts/ci/ci-registration-repro.sh': path.join(CI_DIR, 'ci-registration-repro.sh'),
  'scripts/ci/ci-registration-recovery.mjs': path.join(CI_DIR, 'ci-registration-recovery.mjs')
};
// Programs a native run would call. The recording stubs reject and log any invocation.
const STUBBED_PROGRAMS = ['mix', 'npm', 'npx', 'playwright', 'psql', 'createdb', 'dropdb', 'pg_isready', 'curl', 'wget', 'docker', 'chromium'];

const sha256 = (data) => crypto.createHash('sha256').update(data).digest('hex');
const fileSha256 = (file) => sha256(fs.readFileSync(file));
const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
// Must match revisionFreezeDigest() in ci-registration-recovery.mjs: the digest of the freeze
// without its own freeze_sha256 key, in on-disk key order.
const internalFreezeDigest = (freeze) => sha256(JSON.stringify(Object.fromEntries(Object.entries(freeze).filter(([key]) => key !== 'freeze_sha256'))));

function gitEnv() {
  return {
    ...process.env,
    GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: os.devNull,
    GIT_AUTHOR_NAME: FIXTURE_IDENTITY.name, GIT_AUTHOR_EMAIL: FIXTURE_IDENTITY.email,
    GIT_COMMITTER_NAME: FIXTURE_IDENTITY.name, GIT_COMMITTER_EMAIL: FIXTURE_IDENTITY.email
  };
}

function git(root, args) {
  const result = spawnSync('git', ['-C', root, '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', ...args], { encoding: 'utf8', env: gitEnv() });
  if (result.status !== 0) throw new Error(`fixture git ${args.join(' ')} failed: ${result.stderr}`);
  return result.stdout.trim();
}

function sourceContents(file) {
  const real = COPIED_SOURCES[file];
  if (real) return fs.readFileSync(real);
  return Buffer.from(`// ${SYNTHETIC_LABEL} placeholder for ${file}\n`);
}

function nativeReport(project, title, { duration = 4321 } = {}) {
  return {
    config: { projects: FIXTURE_PROJECTS.map((name) => ({ name })) },
    suites: [{
      title: 'admin-eval.spec.ts', file: 'admin-eval.spec.ts', specs: [],
      suites: [{
        title: 'Admin eval (synthetic)', file: 'admin-eval.spec.ts',
        specs: [{
          title, ok: true, file: 'admin-eval.spec.ts',
          tests: [{
            annotations: [], expectedStatus: 'passed', projectId: project, projectName: project, status: 'expected',
            results: [{ status: 'passed', duration, errors: [], retry: 0, attachments: [], annotations: [] }]
          }]
        }]
      }]
    }],
    errors: [],
    stats: { expected: 1, skipped: 0, unexpected: 0, flaky: 0 }
  };
}

/**
 * Build a complete synthetic committed tree plus a verifiable native-revision receipt.
 *
 * The returned object exposes small mutation helpers that keep every OTHER digest
 * internally consistent, so a test can corrupt exactly one predicate at a time.
 */
export function createRegistrationNativeTreeFixture(options = {}) {
  const label = options.label ?? 'tree';
  const base = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), `sigra-253-native-tree-${label}-`)));
  const root = path.join(base, 'candidate');
  fs.mkdirSync(root);
  git(root, ['init', '-q', '-b', 'main']);

  // Commit 1: the sources the verifier binds to.
  for (const file of SOURCE_FILES) {
    const target = path.join(root, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, sourceContents(file));
  }
  fs.chmodSync(path.join(root, 'scripts/ci/ci-registration-repro.sh'), 0o755);
  git(root, ['add', '--all']);
  git(root, ['commit', '-q', '-m', 'synthetic fixture sources']);
  const sourceHead = git(root, ['rev-parse', 'HEAD']);
  const blobs = Object.fromEntries(SOURCE_FILES.map((file) => [file, git(root, ['rev-parse', `${sourceHead}:${file}`])]));

  // Synthetic historical records (stand-ins for the spent original records).
  const phaseDir = path.join(root, FIXTURE_PHASE_DIR);
  const history = {};
  for (const [key, name] of [
    ['original_freeze', '253-RECOVERY-REGISTRATION-FREEZE.json'],
    ['original_evidence', '253-RECOVERY-REGISTRATION-EVIDENCE.json'],
    ['terminal_diagnostic', '253-09-TERMINAL-DIAGNOSTIC.json'],
    ['recovery_capture', '253-ADDITIONAL-EXECUTION-CAPTURE.json']
  ]) {
    const file = path.join(phaseDir, name);
    writeJson(file, { synthetic_native_fixture: SYNTHETIC_LABEL, record: key, status: 'halted' });
    history[key] = { path: path.relative(root, file), sha256: fileSha256(file) };
  }

  const freezePath = path.join(phaseDir, '253-38-SYNTHETIC-REGISTRATION-FREEZE.json');
  const evidencePath = path.join(phaseDir, '253-38-SYNTHETIC-REGISTRATION-EVIDENCE.json');
  const rawDir = `${evidencePath}.raw`;
  const provenance = { synthetic_native_fixture: SYNTHETIC_LABEL, accepted_as_native_proof: false };

  const slots = [
    ['R-DIAG-DESKTOP', 1, 'admin-eval', 15_000],
    ['R-DIAG-MOBILE', 2, 'admin-eval-mobile', 12_000]
  ].map(([id, sequence, project]) => ({
    id, owner_plan: 15, sequence, kind: 'diagnostic', stage: 'D19', project, max_duration_ms: 120_000, title: SELECTED_TITLE,
    argv: [`--project=${project}`, `--grep=${SELECTED_TITLE}`, '--workers=1', '--retries=0', '--trace=retain-on-failure'],
    selection: { spec: 'tests/admin-eval.spec.ts', title: SELECTED_TITLE, cases: null }
  }));

  const historicalCharge = 3_000;
  const preparationCharge = 2_000;
  const freeze = {
    schema_version: REPLAN_FREEZE_SCHEMA, status: 'frozen_before_results', frozen_at: '2026-01-01T00:00:00.000Z',
    source: { repository: 'synthetic/native-fixture', checkout_head: sourceHead, tracked_worktree_clean_except_exact_preserved_config: false, blobs },
    historical: {
      original_freeze_path: history.original_freeze.path, original_freeze_sha256: history.original_freeze.sha256,
      original_evidence_path: history.original_evidence.path, original_evidence_sha256: history.original_evidence.sha256,
      terminal_diagnostic_path: history.terminal_diagnostic.path, terminal_diagnostic_sha256: history.terminal_diagnostic.sha256,
      recovery_capture_path: history.recovery_capture.path, recovery_capture_sha256: history.recovery_capture.sha256,
      spent_slot_id: 'D19-DIAG-01', spent_browser_launches: 0, spent_charged_ms: historicalCharge,
      preceding_order: 'unknown'
    },
    preparation: { id: 'D19-COMMON-PREPARATION', max_duration_ms: 116_232, charged_duration_ms: preparationCharge },
    ledger: {
      historical_charge_ms: historicalCharge,
      spent_reservations: [{ id: 'D19-DIAG-01', browser_launches: 0, charged_ms: historicalCharge, outcome: 'synthetic_halted' }],
      slots,
      d19: { regular_command_reservations: 8, each_max_duration_ms: 120_000, max_charged_duration_ms: 1_080_000 },
      shared_retry_count: 1, max_new_browser_launches: 18,
      max_charged_duration_ms: 3_480_000, max_total_charged_ms_including_historical: 3_480_000
    },
    provenance
  };

  const attempts = slots.map((slot, index) => {
    const duration = [15_000, 12_000][index];
    const started = 1_000_000_000_000n + BigInt(index) * 100_000_000_000n;
    const attemptDir = path.join(rawDir, slot.id, 'attempt-01');
    fs.mkdirSync(attemptDir, { recursive: true });
    const reference = (name, contents) => {
      const file = path.join(attemptDir, name);
      fs.writeFileSync(file, contents);
      return { path: path.relative(rawDir, file), sha256: fileSha256(file), bytes: fs.statSync(file).size };
    };
    const files = {
      playwright_report: reference('playwright-report.json', JSON.stringify(nativeReport(slot.project, SELECTED_TITLE))),
      traces: [],
      setup_log: reference('setup-log.log', `${SYNTHETIC_LABEL}: database setup complete for ${slot.project}\n`),
      app_log: reference('app-log.log', `${SYNTHETIC_LABEL}: app listening for ${slot.project}\n`),
      test_log: reference('test-log.log', `${SYNTHETIC_LABEL}: 1 passed (${slot.project})\n`),
      drop_log: reference('drop-log.log', `${SYNTHETIC_LABEL}: database dropped\n`)
    };
    return {
      slot_id: slot.id, sequence: slot.sequence, stage: 'D19', project: slot.project, argv: structuredClone(slot.argv),
      source_commit: sourceHead, source_blobs: structuredClone(blobs),
      started_monotonic_ns: started.toString(), ended_monotonic_ns: (started + BigInt(duration) * 1_000_000n).toString(),
      execution_duration_ms: duration, charged_duration_ms: duration,
      database: { name: `sigra_253_recovery_${slot.project.replaceAll('-', '_')}_synthetic_${index + 1}`, setup_exit_code: 0, drop_exit_code: 0 },
      server: { port: 25311 + index, http_status: 200, app_pid: 4242 + index },
      browser: { launched: true, exit_code: 0 },
      observed_outcome: 'passed',
      registration: { server_post_confirmed: true, success_flash_asserted: true },
      files,
      toolchain: { node: 'v20.18.1', playwright: '1.59.1', mix: 'synthetic', ecto_sql: '3.13.5', phoenix_live_view: '1.1.28' },
      build_directory_removed: true, build_path: '/synthetic/fixture/mix-build', terminal_diagnostic: null
    };
  });

  const attemptCharge = attempts.reduce((sum, item) => sum + item.charged_duration_ms, 0);
  const evidence = {
    schema_version: REPLAN_SCHEMA, status: 'diagnosis_incomplete',
    freeze_path: path.relative(root, freezePath), freeze_sha256: null,
    source: { checkout_head: sourceHead, blobs: structuredClone(blobs) },
    historical: { ...structuredClone(freeze.historical), preceding_order: 'unknown' },
    preparation_status: 'passed',
    preparation_receipts: [{ label: 'synthetic-preparation', duration_ms: preparationCharge, exit_code: 0 }],
    attempts,
    limits: {
      historical_charge_ms: historicalCharge, preparation_charge_ms: preparationCharge,
      charged_duration_ms: historicalCharge + preparationCharge + attemptCharge,
      browser_launches: attempts.length, used_slots: attempts.map((item) => item.slot_id),
      max_charged_duration_ms: freeze.ledger.max_charged_duration_ms, max_new_browser_launches: freeze.ledger.max_new_browser_launches
    },
    provenance
  };

  const stubBin = path.join(base, 'stub-bin');
  const stubRecord = path.join(base, 'stub-calls.log');
  fs.mkdirSync(stubBin);
  fs.writeFileSync(stubRecord, '');
  for (const program of STUBBED_PROGRAMS) {
    const file = path.join(stubBin, program);
    fs.writeFileSync(file, `#!/bin/sh\nprintf '%s\\n' "${program} $*" >> '${stubRecord}'\nexit 97\n`);
    fs.chmodSync(file, 0o755);
  }

  const fixture = {
    base, root, phaseDir, freezePath, evidencePath, rawDir, sourceHead, blobs, history,
    runner: path.join(root, 'scripts/ci/ci-registration-repro.sh'),
    recoveryModule: path.join(root, 'scripts/ci/ci-registration-recovery.mjs'),
    stubBin, stubRecord,
    readFreeze: () => readJson(freezePath),
    readEvidence: () => readJson(evidencePath),
    attemptFor: (slotId) => readJson(evidencePath).attempts.find((item) => item.slot_id === slotId),
    reportPath(slotId) {
      const attempt = readJson(evidencePath).attempts.find((item) => item.slot_id === slotId);
      return path.join(rawDir, attempt.files.playwright_report.path);
    },
    /** Rewrite the freeze; keeps its internal digest valid and rebinds the evidence to the new file bytes. */
    rewriteFreeze(mutate, { rebind = true, internalDigest = true } = {}) {
      const next = readJson(freezePath);
      mutate(next);
      if (internalDigest) {
        delete next.freeze_sha256;
        next.freeze_sha256 = internalFreezeDigest(next);
      }
      writeJson(freezePath, next);
      if (rebind) fixture.rewriteEvidence((item) => { item.freeze_sha256 = fileSha256(freezePath); });
      return next;
    },
    rewriteEvidence(mutate) {
      const next = readJson(evidencePath);
      mutate(next);
      writeJson(evidencePath, next);
      return next;
    },
    /** Rewrite a native report and (by default) keep the retained-file digest consistent with it. */
    rewriteReport(slotId, mutate, { updateDigest = true } = {}) {
      const evidence = readJson(evidencePath);
      const attempt = evidence.attempts.find((item) => item.slot_id === slotId);
      const file = path.join(rawDir, attempt.files.playwright_report.path);
      const report = readJson(file);
      mutate(report, attempt);
      fs.writeFileSync(file, JSON.stringify(report));
      if (updateDigest) {
        attempt.files.playwright_report.sha256 = fileSha256(file);
        attempt.files.playwright_report.bytes = fs.statSync(file).size;
        writeJson(evidencePath, evidence);
      }
    },
    appendRaw(slotId, name, text) {
      const attempt = readJson(evidencePath).attempts.find((item) => item.slot_id === slotId);
      fs.appendFileSync(path.join(rawDir, attempt.files[name].path), text);
    },
    env: () => ({ ...process.env, PATH: `${stubBin}${path.delimiter}${process.env.PATH}`, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: os.devNull }),
    /** Invoke the copied shell entrypoint from the temporary committed root. */
    run(args, extra = {}) {
      return spawnSync(fixture.runner, args, { cwd: root, encoding: 'utf8', env: fixture.env(), ...extra });
    },
    verify(extra) { return fixture.run(['--verify-diagnostic', evidencePath, '--revision'], extra); },
    verifySavedNative(extra) { return fixture.run(['--verify-saved-native', evidencePath], extra); },
    /** Recorded native setup/browser/database invocations (must stay empty). */
    stubCalls: () => fs.readFileSync(stubRecord, 'utf8').split('\n').filter(Boolean),
    git: (args) => git(root, args),
    commitAll(message = 'synthetic fixture records') {
      git(root, ['add', '--all']);
      git(root, ['commit', '-q', '-m', message]);
      return git(root, ['rev-parse', 'HEAD']);
    },
    cleanup() { fs.rmSync(base, { recursive: true, force: true }); }
  };

  writeJson(freezePath, (() => { freeze.freeze_sha256 = internalFreezeDigest(freeze); return freeze; })());
  evidence.freeze_sha256 = fileSha256(freezePath);
  writeJson(evidencePath, evidence);
  fixture.headWithRecords = fixture.commitAll('synthetic fixture freeze and receipts');
  return fixture;
}

export function fixtureFileSha256(file) { return fileSha256(file); }
