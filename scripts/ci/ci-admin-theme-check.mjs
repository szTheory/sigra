#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { stopProcess, waitForReady } from './ci-registration-setup-diagnostic.mjs';

const SELF = fileURLToPath(import.meta.url);
const MAX_MS = 20 * 60 * 1000;
const MODES = ['tracer', 'individual', 'file', 'state-controls', 'all'];
const CASES = [
  'renders stable topbar controls and overview notice before deferred app JS',
  'persists Light, Dark, and System without global DaisyUI theme state',
  'users summary metrics expose accessible help on desktop and mobile',
  'workspace navigation stays inside the LiveView session',
  'admin page loading rail follows route-level LiveView navigation',
  'user detail uses breadcrumbs for filtered list context',
  'overview keeps notices and task cards without duplicate info sections',
  'keeps primary button hover contrast readable in dark mode',
  'auth branding theme picker updates login and email previews',
  'auth branding details field help works on hover, keyboard, and touch',
  'auth branding color changes update local previews before save',
  'auth branding color input updates previews before a LiveView round trip',
  'auth branding save toast can be dismissed',
  'auth branding restore defaults is explicit and confirmed',
  'auth branding discard changes only clears the unsaved preview',
  'auth branding color palettes keep swatches and hex values aligned',
  'keyboard navigation uses radiogroup semantics',
  'tone notice and status chip pairs meet WCAG AA in light and dark (axe-skipped soft backgrounds)',
];

const sha = (value) => crypto.createHash('sha256').update(value).digest('hex');
const readSha = (file) => fs.existsSync(file) ? sha(fs.readFileSync(file)) : null;
const now = () => Number(process.hrtime.bigint()) / 1e6;

export function parseArgs(argv) {
  const options = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (['--root', '--mode', '--output'].includes(argv[i]) && argv[i + 1]) options[argv[i].slice(2)] = argv[++i];
    else throw new Error(`unknown_or_incomplete_argument:${argv[i]}`);
  }
  if (!options.root || !options.output || !MODES.includes(options.mode)) throw new Error(`usage: ci-admin-theme-check.mjs --root <repo> --mode ${MODES.join('|')} --output <new-json>`);
  return { ...options, root: path.resolve(options.root), output: path.resolve(options.output) };
}

function run(program, args, options, deadline) {
  if (Date.now() >= deadline) throw new Error('20-minute deadline reached');
  const start = now();
  const result = spawnSync(program, args, { cwd: options.cwd, env: options.env, encoding: 'utf8', timeout: Math.max(1, deadline - Date.now()), killSignal: 'SIGKILL', maxBuffer: 32 * 1024 * 1024 });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}${result.error ? `\n${result.error.message}\n` : ''}`;
  fs.writeFileSync(options.log, output, { mode: 0o600 });
  const safeExcerpt = output.replace(/([\w.+-]+@[\w.-]+\s+)[^\s]+/g, '$1[redacted]').replace(/((?:password|token|secret|api[_-]?key)\s*[:=]\s*)[^\s,;]+/gi, '$1[redacted]').replace(/\bgh[pousr]_[A-Za-z0-9_]{20,}\b/g, '[redacted-token]').slice(-4000);
  return { command: [program, ...args], exit_code: result.status, signal: result.signal, error: result.error?.message ?? null, duration_ms: Math.round(now() - start), log_sha256: sha(output), log_excerpt: result.status === 0 ? undefined : safeExcerpt, log_path: options.log };
}

function reservePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      if (!address || typeof address === 'string') return reject(new Error('port_reservation_failed'));
      const port = address.port;
      server.close((error) => error ? reject(error) : resolve(port));
    });
  });
}

function git(root, ...args) {
  const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`git_${args.join('_')}_failed`);
  return result.stdout.trim();
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (fs.existsSync(options.output)) throw new Error(`refusing_to_overwrite_diagnostic:${options.output}`);
  const source = git(options.root, 'rev-parse', 'HEAD');
  const ownedSource = ['test/example/priv/playwright/fixtures/adminTheme.ts', 'test/example/priv/playwright/tests/admin-theme.spec.ts', 'scripts/ci/ci-admin-theme-prep.test.mjs', 'scripts/ci/ci-admin-theme-check.mjs'];
  const dirty = spawnSync('git', ['-C', options.root, 'diff', '--quiet', 'HEAD', '--', ...ownedSource]);
  const staged = spawnSync('git', ['-C', options.root, 'diff', '--cached', '--quiet', '--', ...ownedSource]);
  if (dirty.status !== 0 || staged.status !== 0) throw new Error('tracked_source_changes_must_be_committed_before_browser_check');
  const start = Date.now();
  const deadline = start + MAX_MS;
  const temp = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-254-admin-theme-')));
  const checkout = path.join(temp, 'repo');
  const logs = path.join(temp, 'logs');
  const localLogs = `${options.output}.logs`;
  fs.mkdirSync(logs, { recursive: true, mode: 0o700 });
  fs.mkdirSync(localLogs, { recursive: true, mode: 0o700 });
  const record = {
    schema_version: 'sigra.phase254.admin-theme-check/v1',
    status: 'running', mode: options.mode, source_sha: source,
    started_at: new Date(start).toISOString(),
    limits: { max_duration_seconds: 1200, max_workers: 1, retries: 0, hosted_runs: 0 },
    source_digests: {}, commands: [], browser_invocations: [], state_controls: [],
    interpretation: 'Local browser development diagnostics only; these results do not prove the CISPEED hosted median, p95, or runner-cost targets.',
  };
  const save = () => fs.writeFileSync(options.output, `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600 });
  save();
  let app = null;
  let dbName = null;
  let dbOwned = false;
  let failure = null;
  let browserPath = null;
  let cleanupContext = null;
  let nodePath = process.env.PATH;
  let port = null;
  try {
    const clone = run('git', ['clone', '--quiet', '--shared', '--no-checkout', options.root, checkout], { cwd: options.root, env: process.env, log: path.join(logs, 'clone.log') }, deadline);
    record.commands.push({ name: 'checkout-clone', ...clone }); save();
    if (clone.exit_code !== 0) throw new Error(`clone_failed:${clone.exit_code}`);
    const checkoutCmd = run('git', ['-C', checkout, 'checkout', '--quiet', '--detach', source], { cwd: checkout, env: process.env, log: path.join(logs, 'checkout.log') }, deadline);
    record.commands.push({ name: 'source-checkout', ...checkoutCmd }); save();
    if (checkoutCmd.exit_code !== 0) throw new Error(`source_checkout_failed:${checkoutCmd.exit_code}`);

    const nodeInstall = spawnSync('asdf', ['where', 'nodejs', '20.18.1'], { encoding: 'utf8', timeout: 15000 });
    if (nodeInstall.status !== 0) throw new Error('pinned_node_20.18.1_unavailable');
    nodePath = `${path.join(nodeInstall.stdout.trim(), 'bin')}:${nodePath}`;
    const env = {
      ...process.env, PATH: nodePath, MIX_ENV: 'dev', PORT: '',
      PGHOST: process.env.PGHOST ?? '127.0.0.1', PGPORT: process.env.PGPORT ?? '5432', PGUSER: process.env.PGUSER ?? 'postgres', PGPASSWORD: process.env.PGPASSWORD ?? 'postgres',
      PGDATABASE: '', SIGRA_EXAMPLE_BIND: '127.0.0.1',
    };
    const nodeVersion = spawnSync('node', ['--version'], { cwd: checkout, env, encoding: 'utf8' }).stdout.trim();
    if (nodeVersion !== 'v20.18.1') throw new Error(`pinned_node_mismatch:${nodeVersion}`);
    const dbHealth = run('psql', ['-d', 'postgres', '-Atqc', 'select 1'], { cwd: checkout, env, log: path.join(logs, 'postgres-health.log') }, deadline);
    record.commands.push({ name: 'postgres-readiness', ...dbHealth }); save();
    if (dbHealth.exit_code !== 0 || !dbHealth.log_excerpt?.trim() && fs.readFileSync(path.join(logs, 'postgres-health.log'), 'utf8').trim() !== '1') throw new Error('configured_postgres_unavailable_or_unauthorized');
    port = await reservePort();
    env.PORT = String(port);
    env.SIGRA_EXAMPLE_URL = `http://127.0.0.1:${port}`;
    env.MIX_BUILD_PATH = path.join(temp, 'build');
    env.HEX_HOME = path.join(temp, 'hex');
    env.PLAYWRIGHT_BROWSERS_PATH = path.join(temp, 'browsers');
    fs.mkdirSync(env.HEX_HOME, { recursive: true });
    fs.mkdirSync(env.PLAYWRIGHT_BROWSERS_PATH, { recursive: true });
    const example = path.join(checkout, 'test/example');
    const playwright = path.join(example, 'priv/playwright');
    cleanupContext = { example, env };
    for (const [name, command] of [['dependency-fetch', ['deps.get', '--check-locked']], ['compile', ['compile', '--warnings-as-errors']]]) {
      const result = run('mix', command, { cwd: example, env, log: path.join(logs, `${name}.log`) }, deadline);
      record.commands.push({ name, ...result }); save();
      if (result.exit_code !== 0) throw new Error(`${name}_failed:${result.exit_code}`);
    }
    const npm = run('npm', ['ci'], { cwd: playwright, env, log: path.join(logs, 'npm-ci.log') }, deadline);
    record.commands.push({ name: 'pinned-playwright-dependencies', ...npm }); save();
    if (npm.exit_code !== 0) throw new Error(`npm_ci_failed:${npm.exit_code}`);
    const playwrightVersion = spawnSync('node', ['-p', "require('./node_modules/@playwright/test/package.json').version"], { cwd: playwright, env, encoding: 'utf8' });
    if (playwrightVersion.status !== 0 || playwrightVersion.stdout.trim() !== '1.59.1') throw new Error(`pinned_playwright_mismatch:${playwrightVersion.stdout?.trim()}`);
    const install = run('node', ['node_modules/@playwright/test/cli.js', 'install', 'chromium'], { cwd: playwright, env, log: path.join(logs, 'browser-install.log') }, deadline);
    record.commands.push({ name: 'chromium-install', ...install }); save();
    if (install.exit_code !== 0) throw new Error(`chromium_install_failed:${install.exit_code}`);

    const sourceFiles = [
      'scripts/ci/ci-admin-theme-check.mjs',
      'scripts/ci/ci-admin-theme-prep.test.mjs',
      'test/example/priv/playwright/fixtures/adminTheme.ts',
      'test/example/priv/playwright/tests/admin-theme.spec.ts',
      'test/example/priv/playwright/playwright.config.ts',
      'test/example/priv/playwright/package-lock.json',
    ];
    for (const relative of sourceFiles) record.source_digests[relative] = readSha(path.join(checkout, relative));
    browserPath = { example, playwright, env };

    async function startApp(suffix) {
      dbName = `sigra_254_theme_${process.pid}_${suffix.replace(/[^a-z0-9]+/gi, '_').slice(0, 32)}`.toLowerCase();
      env.PGDATABASE = dbName;
      for (const [name, args] of [['database-create', ['ecto.create', '--quiet']], ['database-migrate', ['ecto.migrate', '--quiet']]]) {
        const result = run('mix', args, { cwd: example, env, log: path.join(logs, `${suffix}-${name}.log`) }, deadline);
        record.commands.push({ name: `${suffix}-${name}`, ...result }); save();
        if (result.exit_code !== 0) throw new Error(`${suffix}_${name}_failed:${result.exit_code}`);
        if (name === 'database-create') dbOwned = true;
      }
      const seeds = run('mix', ['run', 'priv/repo/seeds.exs'], { cwd: example, env, log: path.join(logs, `${suffix}-seeds.log`) }, deadline);
      record.commands.push({ name: `${suffix}-database-seed`, ...seeds }); save();
      if (seeds.exit_code !== 0) throw new Error(`${suffix}_seed_failed:${seeds.exit_code}`);
      const serverLog = path.join(logs, `${suffix}-server.log`);
      const fd = fs.openSync(serverLog, 'w', 0o600);
      try { app = spawn('mix', ['phx.server'], { cwd: example, env, detached: true, stdio: ['ignore', fd, fd] }); }
      finally { fs.closeSync(fd); }
      const ready = await waitForReady(app, env.SIGRA_EXAMPLE_URL, deadline);
      record.state_controls.push({ name: `${suffix}-app-readiness`, passed: ready === 200, http_status: ready, database_identity: dbName }); save();
      if (ready !== 200) throw new Error(`${suffix}_app_not_ready:${ready ?? 'no-response'}`);
    }
    async function stopApp() {
      await stopProcess(app); app = null;
      if (dbName && dbOwned) {
        const drop = run('mix', ['ecto.drop', '--quiet'], { cwd: example, env, log: path.join(logs, `${dbName}-drop.log`) }, deadline);
        record.commands.push({ name: 'database-drop', ...drop }); save();
        if (drop.exit_code !== 0) throw new Error(`database_drop_failed:${drop.exit_code}`);
        dbName = null; dbOwned = false;
      }
    }
    async function invoke(label, grep, testFile) {
      const diagPath = path.join(logs, `${label}-safe-controls.json`);
      const jsonPath = path.join(logs, `${label}-native.json`);
      const commandEnv = { ...env, SIGRA_ADMIN_THEME_DIAGNOSTICS: diagPath, SIGRA_PLAYWRIGHT_JSON: jsonPath };
      const args = ['node_modules/@playwright/test/cli.js', 'test', testFile, '--project=chromium', '--workers=1', '--retries=0'];
      if (grep) args.push('--grep', grep.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
      const result = run('node', args, { cwd: playwright, env: commandEnv, log: path.join(logs, `${label}.log`) }, deadline);
      const diagnostic = fs.existsSync(diagPath) ? JSON.parse(fs.readFileSync(diagPath, 'utf8')) : null;
      const native = fs.existsSync(jsonPath) ? JSON.parse(fs.readFileSync(jsonPath, 'utf8')) : null;
      const ids = diagnostic?.consumer_context_ids ?? [];
      const requiresFixture = !label.includes('lockout');
      const fixturePassed = !requiresFixture || (!!diagnostic && diagnostic.cleanup_complete === true && ids.length > 0 && new Set(ids).size === ids.length && diagnostic.registered_admin_count === 1 && diagnostic.storage_mode === 0o600);
      const passed = result.exit_code === 0 && !!native && fixturePassed;
      const item = { name: label, selected_title: grep, command: result.command, exit_code: result.exit_code, signal: result.signal, duration_ms: result.duration_ms, log_sha256: result.log_sha256, log_excerpt: result.log_excerpt, native_report_sha256: readSha(jsonPath), native_report_status: native ? { passed: native.stats?.expected ?? null, failed: native.stats?.unexpected ?? null, skipped: native.stats?.skipped ?? null } : null, safe_state: diagnostic ? { registered_admin_count: diagnostic.registered_admin_count, storage_filename: diagnostic.storage_filename, storage_mode: diagnostic.storage_mode, database_identity: diagnostic.database_identity, context_creation_count: ids.length, consumer_context_ids: ids, cleanup_complete: diagnostic.cleanup_complete } : requiresFixture ? null : { anonymous_default_context: true, separate_target_registered_by_original_test: true, real_failed_login_lockout_assertions: result.exit_code === 0 }, status: passed ? 'passed' : 'failed' };
      record.browser_invocations.push(item); save();
      if (!requiresFixture && passed) record.state_controls.push({ name: 'real-lockout-control', passed: true, behavior: 'separate target registered through the UI and locked by five real failed passwords from the default anonymous context' });
      if (!passed) throw new Error(`browser_invocation_failed:${label}:exit_${result.exit_code}`);
    }

    let selections;
    if (options.mode === 'tracer') selections = [['tracer-topbar', CASES[0]]];
    else if (options.mode === 'individual') selections = CASES.map((title, index) => [`individual-${String(index + 1).padStart(2, '0')}`, title]);
    else if (options.mode === 'file' || options.mode === 'all') selections = [['full-file', null]];
    else selections = [['lockout-control', null]];
    if (options.mode === 'state-controls') selections = [['lockout-control', 'overview notice action link is visibly actionable']];
    if (options.mode === 'all') selections = [...CASES.map((title, index) => [`individual-${String(index + 1).padStart(2, '0')}`, title]), ['full-file', null], ['lockout-control', 'overview notice action link is visibly actionable']];

    for (const [index, [label, title]] of selections.entries()) {
      await startApp(`${index + 1}-${label}`);
      await invoke(label, title, 'tests/admin-theme.spec.ts');
      if (label === 'full-file') {
        const last = record.browser_invocations.at(-1);
        if (last.safe_state.context_creation_count !== CASES.length || new Set(last.safe_state.consumer_context_ids).size !== CASES.length) throw new Error('full_file_context_identity_control_failed');
      }
      await stopApp();
    }
    const authLeaks = [];
    const authDir = path.join(playwright, 'test-results', '.auth');
    if (fs.existsSync(authDir)) authLeaks.push(...fs.readdirSync(authDir).map((name) => path.join(authDir, name)));
    for (const cacheDir of [env.HEX_HOME, env.MIX_BUILD_PATH, env.PLAYWRIGHT_BROWSERS_PATH, path.join(playwright, 'test-results')]) {
      if (!fs.existsSync(cacheDir)) continue;
      const pending = [cacheDir];
      while (pending.length) {
        const current = pending.pop();
        for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
          const child = path.join(current, entry.name);
          if (entry.isDirectory()) pending.push(child);
          else if (/^admin-theme-.*\.json$/i.test(entry.name)) authLeaks.push(child);
        }
      }
    }
    if (authLeaks.length) throw new Error('temporary_auth_files_remain_after_invocation');
    const workflow = fs.readFileSync(path.join(checkout, '.github/workflows/ci.yml'), 'utf8');
    const authPathListed = /(?:test-results\/\.auth|\.auth\/admin-theme)/.test(workflow);
    if (authPathListed) throw new Error('auth_storage_path_configured_for_workflow_upload_or_cache');
    record.state_controls.push({ name: 'auth-artifact-exclusion', passed: true, remaining_auth_files: 0, workflow_contains_auth_storage_path: false, upload_or_cache_path_checked: 'Playwright test-results, scoped task-local Mix/Hex/browser caches, and workflow source' });
    record.status = 'passed';
  } catch (error) {
    failure = error.message;
    record.failure = { message: failure };
    record.status = 'blocked';
  } finally {
    if (app) await stopProcess(app);
    if (dbName && dbOwned && cleanupContext) {
      const drop = run('dropdb', ['--if-exists', dbName], { cwd: cleanupContext.example, env: cleanupContext.env, log: path.join(logs, 'database-drop-after-failure.log') }, deadline);
      record.commands.push({ name: 'database-drop-after-failure', ...drop });
      record.cleanup = { ...(record.cleanup ?? {}), database_name: dbName, database_drop_exit: drop.exit_code, database_restored: drop.exit_code === 0 };
      if (drop.exit_code !== 0 && !failure) { failure = 'owned_database_cleanup_failed'; record.status = 'blocked'; record.failure = { message: failure }; }
      if (drop.exit_code === 0) { dbName = null; dbOwned = false; }
      save();
    }
    record.completed_at = new Date().toISOString();
    record.duration_seconds = Math.round((Date.now() - start) / 1000);
    fs.rmSync(temp, { recursive: true, force: true });
    record.cleanup = { ...(record.cleanup ?? {}), checkout_removed: !fs.existsSync(checkout), scoped_temp_removed: !fs.existsSync(temp) };
    fs.writeFileSync(options.output, `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600 });
  }
  console.log(JSON.stringify({ status: record.status, mode: options.mode, duration_seconds: record.duration_seconds, output: options.output, failure }));
  if (record.status !== 'passed') process.exitCode = 2;
}

if (process.argv[1] && path.resolve(process.argv[1]) === SELF) main().catch((error) => { console.error(error.message); process.exitCode = 2; });
