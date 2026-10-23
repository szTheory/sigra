#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SELF = fileURLToPath(import.meta.url);
const MAX_MS = 20 * 60 * 1000;
const SCOPES = { admin_behavior: { port: 4141, database: 'sigra_254_admin_behavior', browserPath: 'admin_behavior' }, non_admin_smoke: { port: 4142, database: 'sigra_254_non_admin_smoke', browserPath: 'non_admin_smoke' } };
const hash = (data) => createHash('sha256').update(data).digest('hex');

export function parseArgs(argv) {
  const options = { mode: 'current', checkOnly: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--check-only') options.checkOnly = true;
    else if (['--root', '--output', '--scope', '--mode'].includes(argv[i]) && argv[i + 1]) options[argv[i].slice(2)] = argv[++i];
    else throw new Error(`unknown_or_incomplete_argument:${argv[i]}`);
  }
  if (!options.root || !options.output || !SCOPES[options.scope] || options.mode !== 'current') throw new Error('usage: ci-prep-profile.mjs --root <repo> --output <new-json> --scope admin_behavior|non_admin_smoke --mode current [--check-only]');
  return options;
}

export function parseActionSteps(source) {
  const steps = {};
  const lines = source.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const name = lines[i].match(/^    - name: (.+)$/)?.[1];
    if (!name) continue;
    let end = i + 1;
    while (end < lines.length && !/^    - name: |^  outputs:|^runs:/.test(lines[end])) end++;
    const bodyLines = lines.slice(i + 1, end);
    const body = bodyLines.join('\n');
    const runIndex = bodyLines.findIndex((line) => /^      run: \|$/.test(line));
    let run = null;
    if (runIndex >= 0) {
      const runLines = [];
      for (let j = runIndex + 1; j < bodyLines.length; j++) {
        if (bodyLines[j] && !/^        /.test(bodyLines[j])) break;
        runLines.push(bodyLines[j].replace(/^        /, ''));
      }
      run = `${runLines.join('\n')}\n`;
    }
    if (!run) {
      const inline = body.match(/^      run: (.+)$/m)?.[1];
      if (inline) steps[name] = [inline.trim()];
      continue;
    }
    steps[name] = run.split('\n').map((line) => line.replace(/^        /, '')).filter((line) => line.trim());
    i = end - 1;
  }
  return steps;
}

export function parseBrowserMatrix(source, scope) {
  const lines = source.split('\n');
  const index = lines.findIndex((line) => line.trim() === `- seam: ${scope}`);
  if (index < 0) throw new Error(`scope_not_found:${scope}`);
  let browserLine = null;
  for (let i = index + 1; i < lines.length; i++) {
    if (/^[ \t]*- seam: /.test(lines[i]) || /^[ \t]*services:/.test(lines[i])) break;
    const match = lines[i].match(/^[ \t]+browsers: (.+)$/);
    if (match) { browserLine = match[1].trim(); break; }
  }
  if (!browserLine) throw new Error(`scope_not_found:${scope}`);
  return browserLine;
}

export function runMeasuredCommand({ label, command, cwd, env, timeoutMs, logPath, clock = () => Number(process.hrtime.bigint()) / 1e6 }) {
  const start = clock();
  const result = spawnSync('/bin/bash', ['-lc', command], { cwd, env, encoding: 'utf8', timeout: Math.max(1, timeoutMs), killSignal: 'SIGKILL', maxBuffer: 16 * 1024 * 1024 });
  const elapsed = Math.max(0, clock() - start);
  const log = `${result.stdout ?? ''}${result.stderr ?? ''}${result.error ? `\n${result.error.message}\n` : ''}`;
  fs.writeFileSync(logPath, log);
  return { name: label, command, exit_code: result.status, signal: result.signal, error: result.error?.message ?? null, duration_ms: Math.round(elapsed), status: result.status === 0 ? 'measured' : 'failed', log_path: logPath, log_sha256: hash(log), ...(result.status === 0 ? {} : { log_excerpt: sanitizeLog(log).slice(-4000) }) };
}

export function sanitizeLog(log) {
  return log
    .replace(/([\w.+-]+@[\w.-]+\s+)[^\s]+/g, '$1[redacted]')
    .replace(/((?:password|token|secret|api[_-]?key)\s*[:=]\s*)[^\s,;]+/gi, '$1[redacted]')
    .replace(/\bgh[pousr]_[A-Za-z0-9_]{20,}\b/g, '[redacted-token]');
}

export function buildProfileRecord({ sourceSha, scope, components, capturedAt = new Date().toISOString() }) {
  return {
    schema_version: 'sigra.phase254.prep-profile-scope/v1', captured_at: capturedAt,
    status: components.some((item) => (item.status === 'failed' || item.status === 'blocked' || (item.exit_code !== undefined && item.exit_code !== 0)) && !item.recovered_by) ? 'blocked' : 'profiled',
    source_sha: sourceSha, scope, components,
    acceptance: 'development evidence only; not a hosted speed result and does not renew acceptance allowance',
  };
}

export function mergeProfileRecords(...records) {
  const identities = new Set(records.map((record) => record.source_sha));
  if (identities.size !== 1) throw new Error('source_identity_mismatch');
  const scopes = {};
  for (const record of records) {
    if (scopes[record.scope]) throw new Error(`duplicate_scope:${record.scope}`);
    scopes[record.scope] = record;
  }
  return { schema_version: 'sigra.phase254.prep-profile/v1', captured_at: new Date().toISOString(), source_sha: records[0]?.source_sha, status: Object.values(scopes).length === 2 && Object.values(scopes).every((item) => item.status === 'profiled') ? 'profiled' : 'blocked', scopes, cost_interpretation: 'Observed command durations are distinct from possible savings. Regex buckets, the 293-second outer boot bucket and test_execution:5 are not component profiles.', native_github_timings: Object.values(scopes)[0]?.source?.native_github_timings ?? null, instrumentation_costs: Object.values(scopes)[0]?.source?.instrumentation ?? null, phase253_candidate_behavior: Object.values(scopes)[0]?.source?.phase253_candidate_behavior ?? [], hosted_comparison_runs_started: false, acceptance_status: 'not_started', speed_target_claimed: false };
}

function digest(file) { return fs.existsSync(file) ? hash(fs.readFileSync(file)) : null; }
function git(root, ...args) { const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8' }); return result.status === 0 ? result.stdout.trim() : null; }
export function versionFromOutput(program, stdout) {
  const lines = stdout.trim().split('\n').map((line) => line.trim());
  return program === 'elixir' ? (lines.find((line) => line.startsWith('Elixir ')) ?? null) : lines[0] ?? null;
}
function commandVersion(program, args, cwd, env) {
  const result = spawnSync(program, args, { cwd, env, encoding: 'utf8', timeout: 15_000 });
  if (result.status !== 0) return null;
  return versionFromOutput(program, result.stdout);
}
function getStatus(url, timeout = 1500) {
  return new Promise((resolve) => { const req = http.get(url, { timeout }, (res) => { res.resume(); res.on('end', () => resolve(res.statusCode)); }); req.on('timeout', () => req.destroy()); req.on('error', () => resolve(null)); });
}
function portAvailable(port) {
  return new Promise((resolve) => { const socket = net.connect({ host: '127.0.0.1', port }); socket.once('connect', () => { socket.destroy(); resolve(false); }); socket.once('error', (error) => { socket.destroy(); resolve(error.code === 'ECONNREFUSED'); }); socket.setTimeout(1500, () => { socket.destroy(); resolve(false); }); });
}
async function stop(child) {
  if (!child?.pid || child.exitCode !== null || child.signalCode !== null) return;
  try { process.kill(-child.pid, 'SIGTERM'); } catch { child.kill('SIGTERM'); }
  let timer;
  await Promise.race([new Promise((resolve) => child.once('exit', resolve)), new Promise((resolve) => { timer = setTimeout(resolve, 3000); })]);
  clearTimeout(timer);
  if (child.exitCode === null && child.signalCode === null) { try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); } }
}

async function profileScope(options) {
  const root = path.resolve(options.root);
  const output = path.resolve(options.output);
  const sourceSha = git(root, 'rev-parse', 'HEAD');
  if (!sourceSha) throw new Error('source_commit_unavailable');
  const actionPath = path.join(root, '.github/actions/example-playwright-boot/action.yml');
  const workflowPath = path.join(root, '.github/workflows/ci.yml');
  const action = fs.readFileSync(actionPath, 'utf8');
  const workflow = fs.readFileSync(workflowPath, 'utf8');
  const steps = parseActionSteps(action);
  const browsers = parseBrowserMatrix(workflow, options.scope);
  const requirements = ['Fetch and compile example', 'Create, migrate, and seed example database', 'Install Playwright dependencies', 'Install Playwright browsers', 'Boot example app', 'Wait for app and warm routes'];
  for (const name of requirements) if (!steps[name]) throw new Error(`action_step_missing:${name}`);
  const actionHash = hash(action);
  const workflowHash = hash(workflow);
  if (options.checkOnly) {
    console.log(JSON.stringify({ status: 'ready', source_sha: sourceSha, action_sha256: actionHash, workflow_sha256: workflowHash, scope: options.scope, browsers }));
    return;
  }
  if (fs.existsSync(output)) throw new Error(`refusing_to_overwrite_profile:${output}`);

  const temp = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), `sigra-254-${options.scope}-`)));
  const logDir = path.join(temp, 'logs'); fs.mkdirSync(logDir);
  const deadline = Date.now() + MAX_MS;
  const comparisonContract = JSON.parse(fs.readFileSync(path.join(root, '.planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json'), 'utf8'));
  const nativeJobsPath = path.join(root, '.planning/phases/252-measure-current-ci/252-run-family-38144377407-retry1/raw/jobs-attempt-1.json');
  const nativeJobs = JSON.parse(fs.readFileSync(nativeJobsPath, 'utf8'));
  const nativeJob = nativeJobs.jobs.find((job) => job.name === 'Example Playwright shard (admin_behavior)');
  const nativeBoot = nativeJob?.steps.find((step) => step.name === 'Boot isolated example app');
  const nativeStepSeconds = nativeBoot ? Math.max(0, Math.round((Date.parse(nativeBoot.completed_at) - Date.parse(nativeBoot.started_at)) / 1000)) : null;
  const candidateFiles = ['ci-registration-setup-diagnostic.mjs', 'ci-playwright-report.mjs', 'ci-registration-recovery.mjs'];
  const metadata = { source_sha: sourceSha, source_dirty: false, action_sha256: actionHash, workflow_sha256: workflowHash, scope: options.scope, browser_selection: browsers.split(/\s+/), cache_identity: 'cold task-local cache; no GitHub restore cache', cold_warm_identity: { current_run: 'cold', warm_run: 'not_run; task-local cache was not reused' }, instrumentation: comparisonContract.instrumentation, native_github_timings: { source_file: path.relative(root, nativeJobsPath), source_file_sha256: digest(nativeJobsPath), run_id: nativeJob?.run_id, run_attempt: nativeJob?.run_attempt, job_id: nativeJob?.id, outer_boot_action_step: nativeBoot ? { name: nativeBoot.name, started_at: nativeBoot.started_at, completed_at: nativeBoot.completed_at, duration_seconds: nativeStepSeconds, status: 'measured_outer_composite_step_only' } : { status: 'unknown', reason: 'saved job record has no Boot isolated example app step' }, setup_beam_internal: { status: 'unknown', reason: 'composite action internals are not represented as separate steps in saved GitHub job timing' }, cache_restore_internal: { status: 'unknown', reason: 'composite action internals are not represented as separate steps in saved GitHub job timing' } }, phase253_candidate_behavior: candidateFiles.map((file) => ({ file, sha256: digest(path.join(root, 'scripts/ci', file)), phase: 253, cost: { status: 'unknown', reason: 'Not independently timed by the preparation action; no synthetic allocation is made.' } })) };
  const components = [];
  const context = { status: 'ready', source: metadata, toolchain: {}, components };
  const saveFailed = (error) => {
    context.status = 'blocked'; context.failure = { message: error.message }; context.completed_at = new Date().toISOString(); context.duration_ms = Date.now() - (context.started_epoch ?? Date.now());
    if (components.some((item) => item.exit_code !== undefined && item.exit_code !== 0 && !item.recovered_by)) context.status = 'blocked';
    const result = buildProfileRecord({ sourceSha, scope: options.scope, components, capturedAt: context.started_at });
    Object.assign(result, context);
    fs.mkdirSync(path.dirname(output), { recursive: true }); fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, { flag: 'wx' });
  };
  const run = (name, shell, cwd, env) => {
    if (Date.now() >= deadline) throw new Error('scope_deadline_20_minutes_reached');
    const item = runMeasuredCommand({ label: name, command: `set -euo pipefail\n${shell}`, cwd, env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, `${name.replace(/[^a-z0-9]+/gi, '-')}.log`) });
    components.push(item);
    if (item.status !== 'measured') throw new Error(`${name}_failed_exit_${item.exit_code ?? item.signal ?? item.error}`);
    return item;
  };

  context.started_at = new Date().toISOString(); context.started_epoch = Date.now();
  let app = null;
  let dbCreated = false;
  const scope = SCOPES[options.scope];
  try {
    const checkout = path.join(temp, 'repo');
    const clone = runMeasuredCommand({ label: 'disposable-checkout', command: `git clone --quiet --shared --no-checkout ${JSON.stringify(root)} ${JSON.stringify(checkout)} && git -C ${JSON.stringify(checkout)} checkout --quiet --detach ${sourceSha}`, cwd: root, env: process.env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, 'disposable-checkout.log') });
    components.push(clone); if (clone.status !== 'measured') throw new Error(`disposable_checkout_failed:${clone.exit_code}`);
    const example = path.join(checkout, 'test/example');
    const playwright = path.join(example, 'priv/playwright');
    const hexHome = path.join(temp, 'hex'); const npmCache = path.join(temp, 'npm-cache'); const browserCache = path.join(temp, 'playwright-cache'); const build = path.join(temp, 'build');
    for (const dir of [hexHome, npmCache, browserCache, build]) fs.mkdirSync(dir, { recursive: true });
    const env = { ...process.env, HEX_HOME: hexHome, npm_config_cache: npmCache, PLAYWRIGHT_BROWSERS_PATH: browserCache, MIX_ENV: 'dev', MIX_BUILD_PATH: build, PORT: String(scope.port), PGHOST: process.env.PGHOST ?? '127.0.0.1', PGPORT: process.env.PGPORT ?? '5432', PGUSER: process.env.PGUSER ?? 'postgres', PGPASSWORD: process.env.PGPASSWORD ?? 'postgres', PGDATABASE: `${scope.database}_${process.pid}`, SERVER_LOG: path.join(logDir, 'server.log'), BASE_URL: `http://127.0.0.1:${scope.port}`, WARMUP_PATHS: options.scope === 'admin_behavior' ? '/admin/users' : '/users/log_in', BROWSERS: browsers, CACHE_HIT: 'false', CI: 'true' };
    env.PGDATABASE = `${scope.database}_${process.pid}`;
    metadata.database = env.PGDATABASE; metadata.port = scope.port;
    context.toolchain = { node: commandVersion('node', ['--version'], root, process.env), elixir: commandVersion('elixir', ['--version'], root, process.env), erlang: commandVersion('erl', ['-noshell', '-eval', 'io:format("~s", [erlang:system_info(otp_release)]), halt().'], root, process.env), playwright: JSON.parse(fs.readFileSync(path.join(root, 'test/example/priv/playwright/package-lock.json'), 'utf8')).packages['node_modules/playwright']?.version ?? JSON.parse(fs.readFileSync(path.join(root, 'test/example/priv/playwright/package-lock.json'), 'utf8')).packages['node_modules/@playwright/test']?.version ?? null };
    const nodeMajor = Number((context.toolchain.node ?? '').replace(/^v/, '').split('.')[0]);
    if (nodeMajor !== 20) {
      const listing = spawnSync('asdf', ['list', 'nodejs'], { cwd: root, encoding: 'utf8', timeout: 15_000 });
      let node20 = listing.status === 0 ? (listing.stdout.match(/(?:^|\n)\s*(20\.\d+\.\d+)\s*(?:\n|$)/g) ?? []).map((line) => line.trim()).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))[0] : null;
      if (!node20) {
        node20 = '20.19.5';
        const asdf = spawnSync('asdf', ['install', 'nodejs', node20], { cwd: root, encoding: 'utf8', timeout: Math.max(1, deadline - Date.now()) });
        components.push({ name: `provision-node-${node20}`, command: `asdf install nodejs ${node20}`, exit_code: asdf.status, duration_ms: null, status: asdf.status === 0 ? 'measured' : 'failed', output: `${asdf.stdout ?? ''}${asdf.stderr ?? ''}`.slice(-2000) });
        if (asdf.status !== 0) throw new Error('node_20_provision_failed');
      }
      const nodeDir = spawnSync('asdf', ['where', 'nodejs', node20], { cwd: root, encoding: 'utf8', timeout: 15_000 });
      if (nodeDir.status !== 0) throw new Error(`node_20_path_unavailable:${node20}`);
      env.PATH = `${path.join(nodeDir.stdout.trim(), 'bin')}:${process.env.PATH}`;
      context.toolchain.node = commandVersion('node', ['--version'], root, env);
    }
    if (Number((context.toolchain.node ?? '').replace(/^v/, '').split('.')[0]) !== 20) throw new Error(`node_20_required_actual_${context.toolchain.node ?? 'unknown'}`);
    if (!await portAvailable(scope.port)) throw new Error(`profile_port_unavailable:${scope.port}`);

    const fetchCompileEnv = { ...env, PGDATABASE: env.PGDATABASE };
    const fetchCompileCommands = steps['Fetch and compile example'].filter((line) => !/^set -/.test(line));
    if (fetchCompileCommands.length !== 2) throw new Error(`unexpected_fetch_compile_commands:${fetchCompileCommands.length}`);
    run('dependency-fetch', fetchCompileCommands[0], example, fetchCompileEnv);
    run('example-compilation', fetchCompileCommands[1], example, fetchCompileEnv);
    const dbSetup = steps['Create, migrate, and seed example database'].join('\n');
    for (const line of dbSetup.split('\n')) {
      if (/^set -/.test(line)) continue;
      if (/^mix ecto\.create/.test(line)) dbCreated = true;
      run(`database-${line.replace(/[^a-z0-9]+/gi, '-')}`, line, example, env);
    }
    run('npm-ci', steps['Install Playwright dependencies'].join('\n'), playwright, env);
    const browserCommand = steps['Install Playwright browsers'].join('\n');
    run('playwright-browser-install', browserCommand, playwright, env);

    const bootLine = steps['Boot example app'].find((line) => line.includes('mix phx.server'));
    if (!bootLine) throw new Error('boot_command_missing');
    const serverFd = fs.openSync(env.SERVER_LOG, 'w');
    try { app = spawn('bash', ['-lc', bootLine.replace(/ > .* 2>&1 &$/, '')], { cwd: example, env, detached: true, stdio: ['ignore', serverFd, serverFd] }); }
    finally { fs.closeSync(serverFd); }
    app.on('error', (error) => { context.server_error = error.message; });
    const readyStart = Number(process.hrtime.bigint()) / 1e6;
    const readyUntil = Math.min(deadline, Date.now() + 90_000);
    let readyStatus = null;
    while (Date.now() < readyUntil && app.exitCode === null && app.signalCode === null) {
      readyStatus = await getStatus(`${env.BASE_URL}/`);
      if (readyStatus === 200) break;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    components.push({ name: 'app-readiness', command: steps['Wait for app and warm routes'].join('\n').split('\n').filter((line) => /curl|sleep|for i/.test(line)), exit_code: readyStatus === 200 ? 0 : 1, status: readyStatus === 200 ? 'measured' : 'failed', duration_ms: Math.round(Number(process.hrtime.bigint()) / 1e6 - readyStart), http_status: readyStatus });
    if (readyStatus !== 200) throw new Error(`app_not_ready_http_${readyStatus ?? 'unavailable'}`);
    const warmup = [];
    for (const route of env.WARMUP_PATHS.split(/\s+/).filter(Boolean)) {
      const start = Number(process.hrtime.bigint()) / 1e6; const status = await getStatus(`${env.BASE_URL}${route}`);
      warmup.push({ route, http_status: status, exit_code: status && status < 400 ? 0 : 22, duration_ms: Math.round(Number(process.hrtime.bigint()) / 1e6 - start), status: status && status < 400 ? 'measured' : 'failed' });
    }
    components.push({ name: 'route-warming', status: warmup.some((item) => item.status === 'failed') ? 'blocked' : 'measured', exit_code: warmup.some((item) => item.status === 'failed') ? 1 : 0, routes: warmup });
    if (warmup.some((item) => item.status === 'failed')) throw new Error('route_warming_failed');
    context.status = 'profiled';
  } catch (error) {
    context.status = 'blocked'; context.failure = { message: error.message };
  } finally {
    await stop(app);
    if (dbCreated && fs.existsSync(path.join(temp, 'repo/test/example/mix.exs'))) {
      const example = path.join(temp, 'repo/test/example');
      const env = { ...process.env, HEX_HOME: path.join(temp, 'hex'), MIX_ENV: 'dev', MIX_BUILD_PATH: path.join(temp, 'build'), PORT: String(scope.port), PGHOST: process.env.PGHOST ?? '127.0.0.1', PGPORT: process.env.PGPORT ?? '5432', PGUSER: process.env.PGUSER ?? 'postgres', PGPASSWORD: process.env.PGPASSWORD ?? 'postgres', PGDATABASE: `${scope.database}_${process.pid}` };
      const cleanup = runMeasuredCommand({ label: 'database-cleanup', command: 'mix ecto.drop --quiet', cwd: example, env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, 'database-cleanup.log') });
      components.push(cleanup);
      if (cleanup.status !== 'measured') {
        const recovery = runMeasuredCommand({ label: 'database-cleanup-recovery', command: `dropdb --if-exists ${env.PGDATABASE}`, cwd: example, env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, 'database-cleanup-recovery.log') });
        components.push(recovery);
        if (recovery.status === 'measured') cleanup.recovered_by = 'database-cleanup-recovery';
        else context.cleanup_error = `database_drop_and_recovery_failed:${cleanup.exit_code}/${recovery.exit_code}`;
      }
    }
    if (components.some((item) => item.exit_code !== undefined && item.exit_code !== 0 && !item.recovered_by)) context.status = 'blocked';
    context.completed_at = new Date().toISOString(); context.duration_ms = Date.now() - context.started_epoch;
    context.cleanup = { server_stopped: !app || (app.exitCode !== null || app.signalCode !== null), database_drop_recorded: components.some((item) => item.name === 'database-cleanup'), task_local_cache_removed: true };
    const profile = buildProfileRecord({ sourceSha, scope: options.scope, components, capturedAt: context.started_at });
    Object.assign(profile, context);
    fs.mkdirSync(path.dirname(output), { recursive: true }); fs.writeFileSync(output, `${JSON.stringify(profile, null, 2)}\n`, { flag: 'wx' });
    fs.rmSync(temp, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ status: context.status, scope: options.scope, output, duration_ms: context.duration_ms, failure: context.failure ?? null }));
  if (context.status !== 'profiled') process.exitCode = 2;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.checkOnly) {
    const root = path.resolve(options.root);
    const action = fs.readFileSync(path.join(root, '.github/actions/example-playwright-boot/action.yml'), 'utf8');
    const workflow = fs.readFileSync(path.join(root, '.github/workflows/ci.yml'), 'utf8');
    const scopeSteps = parseActionSteps(action);
    for (const name of ['Fetch and compile example', 'Create, migrate, and seed example database', 'Install Playwright dependencies', 'Install Playwright browsers', 'Boot example app', 'Wait for app and warm routes']) if (!scopeSteps[name]) throw new Error(`action_step_missing:${name}`);
    console.log(JSON.stringify({ status: 'ready', source_sha: git(root, 'rev-parse', 'HEAD'), action_sha256: hash(action), workflow_sha256: hash(workflow), scope: options.scope, browsers: parseBrowserMatrix(workflow, options.scope) }));
    return;
  }
  await profileScope(options);
}

if (process.argv[1] && path.resolve(process.argv[1]) === SELF) main().catch((error) => { console.error(error.message); process.exitCode = 2; });
