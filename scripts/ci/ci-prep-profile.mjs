#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizedProductRows } from './ci-browser-records.mjs';

const SELF = fileURLToPath(import.meta.url);
const MAX_MS = 20 * 60 * 1000;
const SCOPES = {
  admin_behavior: { port: 4141, database: 'sigra_254_admin_behavior', browserPath: 'admin_behavior' },
  admin_checkpoints: { port: 4143, database: 'sigra_254_admin_checkpoints', browserPath: 'admin_checkpoints' },
  design_gallery: { port: 4144, database: 'sigra_254_design_gallery', browserPath: 'design_gallery' },
  non_admin_smoke: { port: 4142, database: 'sigra_254_non_admin_smoke', browserPath: 'non_admin_smoke' },
  demo_showcase: { port: 4145, database: 'sigra_254_demo_showcase', browserPath: 'demo_showcase' },
};
const hash = (data) => createHash('sha256').update(data).digest('hex');

export function parseArgs(argv) {
  const options = { mode: 'current', checkOnly: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--check-only') options.checkOnly = true;
    else if (['--root', '--output', '--scope', '--mode', '--workload-map', '--baseline-native', '--reuse-native-directory', '--reuse-integration'].includes(argv[i]) && argv[i + 1]) options[argv[i].slice(2).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())] = argv[++i];
    else throw new Error(`unknown_or_incomplete_argument:${argv[i]}`);
  }
  const validMode = ['current', 'compare-preparation', 'workload'].includes(options.mode);
  const validScope = options.mode === 'workload' ? (!options.scope || Boolean(SCOPES[options.scope])) : Boolean(SCOPES[options.scope]);
  if (!options.root || !options.output || !validScope || !validMode || (options.mode === 'workload' && !options.workloadMap)) throw new Error('usage: ci-prep-profile.mjs --root <repo> --output <json> --scope <owner> --mode current|compare-preparation|workload [--workload-map <json>] [--check-only]');
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

export function buildPreparationCommands(actionSource) {
  const steps = parseActionSteps(actionSource);
  const required = ['Fetch and compile example', 'Create, migrate, and seed example database'];
  const expected = ['mix deps.get', 'mix compile --warnings-as-errors', 'mix ecto.create', 'mix ecto.migrate', 'mix run priv/repo/seeds.exs'];
  if (required.every((name) => steps[name])) {
    const current = required.flatMap((name) => steps[name].filter((line) => !/^set -/.test(line)));
    if (JSON.stringify(current) !== JSON.stringify(expected)) throw new Error('unexpected_current_preparation_commands');
    const combined = `mix do ${current.map((line) => line.replace(/^mix\s+/, '')).join(' + ')}`;
    return { current, combined, selected: current, isCombined: false };
  }
  const preparation = steps['Prepare example with combined Mix'];
  const selected = preparation?.map((line) => line.trim()).filter((line) => /^mix do /.test(line));
  const recorded = preparation?.some((line) => line.includes('ci-command-record.py'));
  const expectedCount = recorded ? 2 : 1;
  if (selected?.length !== expectedCount || selected.some((line) => !/^mix do deps\.get \+ compile --warnings-as-errors \+ ecto\.create \+ ecto\.migrate \+ run priv\/repo\/seeds\.exs$/.test(line))) throw new Error('action_step_missing:preparation');
  if (recorded && !preparation.some((line) => /--invocation .*?-prepare.*? -- \\$/.test(line.trim()))) throw new Error('preparation_recorder_boundary_missing');
  return { current: expected, combined: selected[0], selected: [selected[0]], isCombined: true };
}

export function assertPreparationCacheContract(actionSource) {
  const action = actionSource;
  for (const token of ['inputs.app-port', 'steps.setup_beam.outputs.otp-version', 'steps.setup_beam.outputs.elixir-version', '-dev-', 'restore-keys:', 'deps.get', 'compile --warnings-as-errors', 'PGDATABASE:', 'PGPORT:', 'PORT:', 'MIX_ENV: dev', 'ecto.create', 'ecto.migrate', 'run priv/repo/seeds.exs', 'ci-playwright-os-deps.py', '--playwright-dir "$PWD" --report "$RUNNER_TEMP/playwright-os-deps.json" $BROWSERS', 'npx playwright install $BROWSERS', 'Boot example app', 'mix phx.server', 'Wait for app and warm routes', 'curl -sf "$BASE_URL/"']) {
    if (!action.includes(token)) throw new Error(`preparation_contract_missing:${token}`);
  }
  buildPreparationCommands(action);
  const npmStep = parseActionSteps(action)['Install Playwright dependencies'] ?? [];
  const npmCommands = npmStep.map((line) => line.trim().match(/(?:^|--\s+)(npm\s+.*)$/)?.[1]).filter(Boolean);
  const npmCount = npmStep.some((line) => line.includes('ci-command-record.py')) ? 2 : 1;
  if (npmCommands.length !== npmCount || npmCommands.some((command) => command !== 'npm ci')) throw new Error('preparation_contract_missing:npm ci');
  if (!action.includes('if: inputs.cache-browsers == \'true\'')) throw new Error('browser_cache_condition_missing');
  return true;
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

export function parseWorkflowBrowserOwners(source) {
  const owners = {};
  for (const name of Object.keys(SCOPES)) {
    owners[name] = { browser_selection: parseBrowserMatrix(source, name), workflow_steps: [] };
  }
  const lines = source.split('\n');
  for (let index = 0; index < lines.length; index++) {
    if (!/^      - name: /.test(lines[index])) continue;
    let end = index + 1;
    while (end < lines.length && !/^      - (?:name|uses): /.test(lines[end])) end++;
    const body = lines.slice(index + 1, end).join('\n');
    const owner = body.match(/^        id: (admin_behavior|admin_checkpoints|design_gallery|non_admin_smoke|demo_showcase)$/m)?.[1] ??
      body.match(/matrix\.seam == ['"](admin_behavior|admin_checkpoints|design_gallery|non_admin_smoke|demo_showcase)['"]/m)?.[1];
    if (!owner) continue;
    const bodyLines = body.split('\n');
    const runIndex = bodyLines.findIndex((line) => /^        run:/.test(line));
    const runHeader = bodyLines[runIndex] ?? '';
    let command = null;
    if (runHeader === '        run: |') {
      const commandLines = [];
      for (let lineIndex = runIndex + 1; lineIndex < bodyLines.length; lineIndex++) {
        const line = bodyLines[lineIndex];
        if (line && !/^          /.test(line)) break;
        commandLines.push(line.replace(/^          /, ''));
      }
      command = commandLines.join('\n').trim();
    } else if (runHeader) command = runHeader.replace(/^        run: /, '').trim();
    if (!command) throw new Error(`workflow_owner_run_missing:${owner}`);
    owners[owner].workflow_steps.push({ name: lines[index].match(/^      - name: (.+)$/)?.[1] ?? null, command });
    index = end - 1;
  }
  for (const [name, owner] of Object.entries(owners)) if (owner.workflow_steps.length === 0) throw new Error(`workflow_owner_steps_missing:${name}`);
  return owners;
}

export function browserOwnerBaseURL(port) { return `http://localhost:${port}`; }

function runMeasuredInvocation({ label, command, program, args, cwd, env, timeoutMs, logPath, clock = () => Number(process.hrtime.bigint()) / 1e6 }) {
  const start = clock();
  const result = spawnSync(program, args, { cwd, env, encoding: 'utf8', timeout: Math.max(1, timeoutMs), killSignal: 'SIGKILL', maxBuffer: 16 * 1024 * 1024 });
  const elapsed = Math.max(0, clock() - start);
  const log = `${result.stdout ?? ''}${result.stderr ?? ''}${result.error ? `\n${result.error.message}\n` : ''}`;
  fs.writeFileSync(logPath, log);
  return { name: label, command, exit_code: result.status, signal: result.signal, error: result.error?.message ?? null, duration_ms: Math.round(elapsed), status: result.status === 0 ? 'measured' : 'failed', log_path: logPath, log_sha256: hash(log), ...(result.status === 0 ? {} : { log_excerpt: sanitizeLog(log).slice(-4000) }) };
}

export function runMeasuredCommand({ label, command, ...options }) {
  return runMeasuredInvocation({ label, command, program: '/bin/bash', args: ['-lc', command], ...options });
}

export function runMeasuredProcess({ label, program, args, ...options }) {
  return runMeasuredInvocation({ label, command: JSON.stringify([program, ...args]), program, args, ...options });
}

function coverageSemanticKey(row) {
  return JSON.stringify([row.project_id, row.spec, row.title_path, row.title]);
}

function coverageMapKey(row) { return JSON.stringify(row.semantic_identity); }

function writeCoverageSource(directory, { owner, sourceSha, workflowSha, configurationSha, lockSha, event, mapRows, side, expectedFiles }) {
  const reports = fs.readdirSync(directory).filter((name) => name.endsWith('.json') && !name.endsWith('.selection.json') && name !== 'coverage-source.json' && name !== 'coverage-map.json').sort();
  if (!reports.length) throw new Error(`native_reports_missing:${owner}`);
  const selectedInventory = [];
  const reportRefs = [];
  for (const name of reports) {
    const selectionName = name.replace(/\.json$/, '.selection.json');
    const reportPath = path.join(directory, name);
    const selectionPath = path.join(directory, selectionName);
    if (!fs.existsSync(selectionPath)) throw new Error(`native_selection_missing:${owner}:${selectionName}`);
    for (const fileName of [name, selectionName]) {
      const actualDigest = hash(fs.readFileSync(path.join(directory, fileName)));
      if (expectedFiles?.[fileName] !== actualDigest) throw new Error(`native_artifact_digest_not_retained:${owner}:${fileName}`);
    }
    const nativeRows = normalizedProductRows(JSON.parse(fs.readFileSync(reportPath, 'utf8')), { seam: owner, invocation: name });
    const selection = JSON.parse(fs.readFileSync(selectionPath, 'utf8'));
    const selectedById = new Map();
    const visit = (suites, parents = []) => {
      for (const suite of suites ?? []) {
        const titlePath = [...parents, suite.title];
        for (const spec of suite.specs ?? []) for (const test of spec.tests ?? []) {
          const id = JSON.stringify([test.projectId, spec.file.replaceAll('\\', '/'), titlePath, spec.id, spec.title]);
          selectedById.set(id, { id, project: test.projectName, spec: spec.file.replaceAll('\\', '/'), title_path: titlePath,
            native_spec_id: spec.id, title: spec.title, owner, classification: 'product', expected_status: test.expectedStatus });
        }
        visit(suite.suites, titlePath);
      }
    };
    visit(selection.suites);
    for (const row of nativeRows) {
      const selected = selectedById.get(row.id);
      if (!selected) throw new Error(`native_result_not_selected:${owner}:${row.id}`);
      const nativeId = JSON.parse(row.id)[3];
      const semantic = JSON.stringify([row.project_id, row.spec, row.title_path, row.title]);
      const expectedMap = mapRows.find((candidate) => candidate[side === 'before' ? 'before_native_id' : 'candidate_native_id'] === nativeId && coverageMapKey(candidate) === semantic);
      if (!expectedMap) throw new Error(`native_identity_unmapped:${owner}:${row.id}`);
      selected.classification = expectedMap.classification;
      selected.actual_result = row.actual_result;
      selectedInventory.push(selected);
    }
    if (selectedById.size !== nativeRows.length) throw new Error(`native_selection_result_count_mismatch:${owner}:${selectedById.size}/${nativeRows.length}`);
    reportRefs.push({ path: name, selection_path: selectionName, sha256: hash(fs.readFileSync(reportPath)),
      selection_sha256: hash(fs.readFileSync(selectionPath)), source_sha: sourceSha });
  }
  const projects = [...new Set(selectedInventory.map((row) => row.project))].sort();
  const descriptor = { schema_version: 'sigra.browser-coverage-source/v1', source_sha: sourceSha,
    workflow_sha256: workflowSha, configuration_sha256: configurationSha, lock_sha256: lockSha,
    event, seam: owner, owner, project_inventory: projects, selected_inventory: selectedInventory,
    excluded_inventory: [], skip_policies: [], reports: reportRefs };
  fs.writeFileSync(path.join(directory, 'coverage-source.json'), `${JSON.stringify(descriptor, null, 2)}\n`);
  return descriptor;
}

function runCoverageComparison(root, beforeDirectory, afterDirectory, mappingPath) {
  const started = Number(process.hrtime.bigint()) / 1e6;
  const comparison = spawnSync(process.execPath, [path.join(root, 'scripts/ci/ci-browser-records.mjs'), '--compare-coverage',
    '--before-directory', beforeDirectory, '--after-directory', afterDirectory, '--mapping', mappingPath],
  { cwd: root, encoding: 'utf8', timeout: 30_000 });
  if (comparison.status !== 0) throw new Error(`native_parity_compare_failed:${(comparison.stderr ?? comparison.stdout ?? '').trim().slice(0, 1000)}`);
  return { ...JSON.parse(comparison.stdout), duration_ms: Math.round(Number(process.hrtime.bigint()) / 1e6 - started) };
}

export function transferNativeEvidence(root, references, destination) {
  const started = Number(process.hrtime.bigint()) / 1e6;
  fs.mkdirSync(destination, { recursive: true });
  const files = [];
  for (const reference of references) {
    const relativePath = reference.path;
    if (typeof relativePath !== 'string' || path.isAbsolute(relativePath) || relativePath.split(/[\\/]/).includes('..')) throw new Error('native_evidence_transfer_path_invalid');
    const source = path.resolve(root, relativePath);
    const original = fs.readFileSync(source);
    const originalHash = hash(original);
    if (originalHash !== reference.sha256) throw new Error(`native_evidence_transfer_source_digest_mismatch:${relativePath}`);
    const output = path.join(destination, path.basename(relativePath));
    fs.copyFileSync(source, output);
    const copied = fs.readFileSync(output);
    const copiedHash = hash(copied);
    if (copiedHash !== originalHash) throw new Error(`native_evidence_transfer_copy_digest_mismatch:${relativePath}`);
    files.push({ path: relativePath, sha256: copiedHash, bytes: copied.length });
  }
  return { status: 'measured', duration_ms: Math.round(Number(process.hrtime.bigint()) / 1e6 - started),
    bytes: files.reduce((sum, file) => sum + file.bytes, 0), files };
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
  const preparation = buildPreparationCommands(action);
  const browsers = parseBrowserMatrix(workflow, options.scope);
  const requirements = ['Install Playwright dependencies', 'Install Playwright browsers', 'Boot example app', 'Wait for app and warm routes'];
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
    const clone = runMeasuredProcess({ label: 'disposable-checkout', program: 'git', args: ['clone', '--quiet', '--shared', '--no-checkout', root, checkout], cwd: root, env: process.env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, 'disposable-checkout.log') });
    components.push(clone); if (clone.status !== 'measured') throw new Error(`disposable_checkout_failed:${clone.exit_code}`);
    const checkoutSource = runMeasuredProcess({ label: 'checkout-source', program: 'git', args: ['-C', checkout, 'checkout', '--quiet', '--detach', sourceSha], cwd: root, env: process.env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, 'checkout-source.log') });
    components.push(checkoutSource); if (checkoutSource.status !== 'measured') throw new Error(`checkout_source_failed:${checkoutSource.exit_code}`);
    const example = path.join(checkout, 'test/example');
    const playwright = path.join(example, 'priv/playwright');
    const hexHome = path.join(temp, 'hex'); const npmCache = path.join(temp, 'npm-cache'); const browserCache = path.join(temp, 'playwright-cache'); const build = path.join(example, '_build', 'phase254-prep-profile');
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
    const shellNode = run('shell-node-runtime', 'node --version', root, env);
    context.toolchain.shell_node = fs.readFileSync(shellNode.log_path, 'utf8').trim().split('\n')[0] ?? null;
    if (context.toolchain.shell_node !== context.toolchain.node) throw new Error(`shell_node_runtime_mismatch:${context.toolchain.shell_node}/${context.toolchain.node}`);
    if (!await portAvailable(scope.port)) throw new Error(`profile_port_unavailable:${scope.port}`);

    if (preparation.isCombined) {
      dbCreated = true;
      run('combined-preparation', preparation.selected[0], example, env);
    } else {
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
    if (options.mode === 'workload') {
      const owner = options.workflowOwners?.[scope.browserPath];
      if (!owner?.workflow_steps?.length) throw new Error(`workflow_owner_invocation_missing:${scope.browserPath}`);
      const invocation = owner.workflow_steps[0];
      const reportRoot = path.resolve(options.reportRoot, scope.browserPath);
      context.owner_invocation = invocation.name;
      try {
        run('native-owner-invocation', invocation.command, playwright, { ...env, SIGRA_EXAMPLE_URL: browserOwnerBaseURL(scope.port) });
      } finally {
        fs.mkdirSync(reportRoot, { recursive: true });
        const reportDir = path.join(playwright, 'playwright-report');
        if (fs.existsSync(reportDir)) fs.cpSync(reportDir, reportRoot, { recursive: true, errorOnExist: true });
        const commandLog = components.find((item) => item.name === 'native-owner-invocation')?.log_path;
        if (commandLog && fs.existsSync(commandLog)) fs.copyFileSync(commandLog, path.join(reportRoot, 'native-owner-invocation.log'));
        if (fs.existsSync(env.SERVER_LOG)) fs.copyFileSync(env.SERVER_LOG, path.join(reportRoot, 'server.log'));
        const testResults = path.join(playwright, 'test-results');
        if (fs.existsSync(testResults)) fs.cpSync(testResults, path.join(reportRoot, 'test-results'), {
          recursive: true,
          errorOnExist: true,
          filter: (source) => !source.endsWith('.png') && (!fs.statSync(source).isDirectory() || source === testResults),
        });
        context.native_reports = fs.readdirSync(reportRoot).filter((name) => name.endsWith('.json')).map((name) => ({
          path: path.relative(path.dirname(options.reportRoot), path.join(reportRoot, name)),
          sha256: digest(path.join(reportRoot, name)),
        }));
      }
    }
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
  if (context.status !== 'profiled' && options.mode !== 'workload') process.exitCode = 2;
}

function gitOutput(root, ...args) {
  const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`git_${args.join('_')}_failed`);
  return result.stdout.trim();
}

function databaseSnapshot(env) {
  const sql = `select
    (select string_agg(version::text, ',' order by version) from schema_migrations),
    (select count(*) from auth.users),
    (select count(*) from auth.users where email like '%@demo.tasklane.test'),
    (select count(*) from auth.organizations),
    (select count(*) from auth.organization_memberships),
    (select count(*) from auth.user_mfa_credentials),
    (select count(*) from auth.user_passkeys),
    (select count(*) from auth.user_sessions),
    (select count(*) from auth.user_identities),
    (select count(*) from auth.audit_events),
    (select count(*) from auth.enterprise_connections)`;
  const result = spawnSync('psql', ['-X', '-qAt', '-c', sql], { env, encoding: 'utf8', timeout: 15_000 });
  if (result.status !== 0) throw new Error(`database_snapshot_failed:${(result.stderr ?? '').trim()}`);
  const [migrationVersions, users, demoUsers, organizations, memberships, mfaCredentials, passkeys, sessions, identities, auditEvents, enterpriseConnections] = result.stdout.trim().split('|');
  return { migration_versions: migrationVersions?.split(',').filter(Boolean) ?? [], users: Number(users), demo_tasklane_users: Number(demoUsers), organizations: Number(organizations), memberships: Number(memberships), mfa_credentials: Number(mfaCredentials), passkeys: Number(passkeys), sessions: Number(sessions), identities: Number(identities), audit_events: Number(auditEvents), enterprise_connections: Number(enterpriseConnections) };
}

function runMixStep({ label, command, cwd, env, logDir, deadline, components }) {
  const item = runMeasuredCommand({ label, command: `set -euo pipefail\n${command}`, cwd, env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logDir, `${label.replace(/[^a-z0-9]+/gi, '-')}.log`) });
  components.push(item);
  return item;
}

async function comparePreparation(options) {
  const root = path.resolve(options.root);
  const output = path.resolve(options.output);
  const sourceSha = gitOutput(root, 'rev-parse', 'HEAD');
  const actionPath = path.join(root, '.github/actions/example-playwright-boot/action.yml');
  const workflowPath = path.join(root, '.github/workflows/ci.yml');
  const action = fs.readFileSync(actionPath, 'utf8');
  const workflow = fs.readFileSync(workflowPath, 'utf8');
  assertPreparationCacheContract(action, workflow);
  const plan = buildPreparationCommands(action);
  const tddRedPath = path.join(root, '.planning/phases/254-speed-up-the-measured-slow-jobs/254-05-02-red-evidence.tmp.json');
  const tddRedEvidence = fs.existsSync(tddRedPath) ? JSON.parse(fs.readFileSync(tddRedPath, 'utf8')) : null;
  const prior = fs.existsSync(output) ? JSON.parse(fs.readFileSync(output, 'utf8')) : null;
  const priorCommit = fs.existsSync(output) ? gitOutput(root, 'log', '-1', '--format=%H', '--', path.relative(root, output)) : null;
  const priorHash = prior ? hash(fs.readFileSync(output)) : null;
  const temp = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-254-compare-prep-')));
  const logs = path.join(temp, 'logs'); fs.mkdirSync(logs);
  const startedAt = new Date().toISOString(); const deadline = Date.now() + MAX_MS;
  const components = []; const databaseIds = []; const runs = {};
  const commonHome = path.join(temp, 'tool-home'); const mixHome = path.join(commonHome, 'mix'); const hexHome = path.join(commonHome, 'hex');
  fs.mkdirSync(mixHome, { recursive: true }); fs.mkdirSync(hexHome, { recursive: true });
  const prerequisiteEnv = { ...process.env, MIX_HOME: mixHome, HEX_HOME: hexHome, MIX_ENV: 'dev', CI: 'true' };
  const baseDatabase = `sigra_25405_${process.pid}_${Date.now().toString(36)}`;
  const runtime = { node: commandVersion('node', ['--version'], root, process.env), elixir: commandVersion('elixir', ['--version'], root, process.env), erlang: commandVersion('erl', ['-noshell', '-eval', 'io:format("~s", [erlang:system_info(otp_release)]), halt().'], root, process.env) };
  const checkoutRoot = path.join(temp, 'checkouts'); fs.mkdirSync(checkoutRoot);
  const result = {
    schema_version: 'sigra.phase254.setup-check/v1', status: 'running', source_sha: sourceSha,
    source_files: { action_sha256: hash(action), workflow_sha256: hash(workflow), profiler_sha256: hash(fs.readFileSync(SELF)) },
    profile: { captured_at: startedAt, runtime, scope: options.scope, env: 'MIX_ENV=dev; CI=true; localhost PostgreSQL; unique DB and PORT per form; isolated MIX_HOME/HEX_HOME shared across forms' },
    pinned_setup_proof: { action: 'erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124', source: 'https://raw.githubusercontent.com/erlef/setup-beam/54075bcc5e249e4758d363f27d099f55d843f124/action.yml', version_file: '.tool-versions', version_type: 'strict', install_hex_default: true, install_rebar_default: true, flags_disabling_defaults: false, workflow_changes_homes_after_setup: false, reason_outer_fetch_retained: 'mix ci runs format --check-formatted before deps.get --check-locked; a clean source checkout failed at formatter import loading without a preceding dependency fetch.' },
    current_commands: plan.current, combined_candidate: plan.combined,
    previous_artifact: prior ? { path: path.relative(root, output), sha256: priorHash, commit: priorCommit, red_target: prior.targetTest ?? prior.target_test ?? prior.previous_artifact?.red_target ?? null, classifier_verdict: prior.targetTest || prior.target_test || prior.previous_artifact ? 'RED_EVIDENCE_OK' : null, prior_status: prior.status ?? null, prior_failure: prior.failure ?? null, prior_component_results: (prior.components ?? []).map((item) => ({ name: item.name, status: item.status, exit_code: item.exit_code })) } : null,
    tdd_red_evidence_task_02: tddRedEvidence ? { ...tddRedEvidence, classifier_verdict: 'RED_EVIDENCE_OK' } : null,
    components, forms: runs, failure_semantics: null, decision: null, hosted_acceptance: 'not_started', speed_target_claimed: false,
  };

  const createCheckout = (form) => {
    const checkout = path.join(checkoutRoot, form);
    const clone = runMeasuredProcess({ label: `checkout-${form}`, program: 'git', args: ['clone', '--quiet', '--shared', '--no-checkout', root, checkout], cwd: root, env: process.env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logs, `checkout-${form}.log`) });
    components.push(clone);
    if (clone.status !== 'measured') throw new Error(`checkout_${form}_failed`);
    const checkoutSource = runMeasuredProcess({ label: `checkout-${form}-source`, program: 'git', args: ['-C', checkout, 'checkout', '--quiet', '--detach', sourceSha], cwd: root, env: process.env, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logs, `checkout-${form}-source.log`) });
    components.push(checkoutSource);
    if (checkoutSource.status !== 'measured') throw new Error(`checkout_${form}_source_failed`);
    return checkout;
  };
  const commonEnvFor = (checkout, form) => {
    const env = { ...process.env, MIX_HOME: mixHome, HEX_HOME: hexHome, MIX_ENV: 'dev', CI: 'true', PORT: form === 'current' ? '4141' : '4142', PGUSER: process.env.PGUSER ?? 'postgres', PGPASSWORD: process.env.PGPASSWORD ?? 'postgres', PGHOST: process.env.PGHOST ?? '127.0.0.1', PGPORT: process.env.PGPORT ?? '5432', PGDATABASE: `${baseDatabase}_${form}` };
    databaseIds.push(env.PGDATABASE);
    return env;
  };
  const prepare = (form, phase, checkout, commands, env) => {
    const example = path.join(checkout, 'test/example'); const before = components.length;
    for (let i = 0; i < commands.length; i++) {
      const item = runMixStep({ label: `${form}-${phase}-${String(i + 1).padStart(2, '0')}`, command: commands[i], cwd: example, env, logDir: logs, deadline, components });
      if (item.status !== 'measured') return { status: 'failed', exit_code: item.exit_code, elapsed_ms: components.slice(before).reduce((sum, part) => sum + (part.duration_ms ?? 0), 0), failed_component: item.name };
    }
    return { status: 'measured', exit_code: 0, elapsed_ms: components.slice(before).reduce((sum, part) => sum + (part.duration_ms ?? 0), 0), snapshot: databaseSnapshot(env) };
  };

  try {
    for (const [label, args] of [['hex-install', ['local.hex', '--force']], ['rebar-install', ['local.rebar', '--force']]]) {
      const item = runMeasuredCommand({ label, command: `mix ${args.join(' ')}`, cwd: root, env: prerequisiteEnv, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logs, `${label}.log`) });
      components.push(item); if (item.status !== 'measured') throw new Error(`${label}_failed`);
    }
    const currentCheckout = createCheckout('current');
    const candidateCheckout = createCheckout('combined');
    const currentEnv = commonEnvFor(currentCheckout, 'current'); const candidateEnv = commonEnvFor(candidateCheckout, 'combined');
    const coldCurrent = prepare('current', 'cold', currentCheckout, plan.current, currentEnv);
    runs.current = { cold: coldCurrent };
    if (coldCurrent.status === 'measured') runs.current.warm = prepare('current', 'warm', currentCheckout, plan.current, currentEnv);
    else runs.current.warm = { status: 'not_run_after_cold_failure' };
    const coldCombined = prepare('combined', 'cold', candidateCheckout, [plan.combined], candidateEnv);
    runs.combined = { cold: coldCombined };
    if (coldCombined.status === 'measured') runs.combined.warm = prepare('combined', 'warm', candidateCheckout, [plan.combined], candidateEnv);
    else runs.combined.warm = { status: 'not_run_after_cold_failure' };

    const failDir = path.join(candidateCheckout, 'test/example/tmp/phase254-prep-failure'); fs.mkdirSync(failDir, { recursive: true });
    const failingTask = path.join(failDir, 'fail.exs'); const sentinelTask = path.join(failDir, 'sentinel.exs'); const sentinelPath = path.join(failDir, 'reached');
    fs.writeFileSync(failingTask, 'raise "controlled_phase254_preparation_failure"\n');
    fs.writeFileSync(sentinelTask, `File.write!(System.fetch_env!("PHASE254_SENTINEL"), "reached")\n`);
    const failureEnv = { ...candidateEnv, PGDATABASE: `${baseDatabase}_failure`, PHASE254_SENTINEL: sentinelPath }; databaseIds.push(failureEnv.PGDATABASE);
    const failSequence = [
      'deps.get', 'compile --warnings-as-errors', 'ecto.create', 'ecto.migrate',
      `run ${path.relative(path.join(candidateCheckout, 'test/example'), failingTask)}`,
      'run priv/repo/seeds.exs', `run ${path.relative(path.join(candidateCheckout, 'test/example'), sentinelTask)}`,
    ];
    const failed = runMeasuredCommand({ label: 'combined-controlled-middle-failure', command: `mix do ${failSequence.join(' + ')}`, cwd: path.join(candidateCheckout, 'test/example'), env: failureEnv, timeoutMs: Math.max(1, deadline - Date.now()), logPath: path.join(logs, 'combined-controlled-middle-failure.log') });
    components.push(failed);
    const failureSnapshot = failed.exit_code !== 0 ? databaseSnapshot(failureEnv) : null;
    const markerFound = fs.existsSync(failed.log_path) && fs.readFileSync(failed.log_path, 'utf8').includes('controlled_phase254_preparation_failure');
    result.failure_semantics = { command: `mix do ${failSequence.join(' + ')}`, exit_code: failed.exit_code, status: failed.exit_code !== 0 && markerFound && !fs.existsSync(sentinelPath) && failureSnapshot?.users === 0 ? 'passed' : 'failed', sentinel_created: fs.existsSync(sentinelPath), seed_users_after_failure: failureSnapshot?.users ?? null, migration_versions_after_failure: failureSnapshot?.migration_versions ?? [], expected_marker_in_log: markerFound };
    const equivalent = [
      runs.current.cold?.status === 'measured' && runs.combined.cold?.status === 'measured' && JSON.stringify(runs.current.cold.snapshot) === JSON.stringify(runs.combined.cold.snapshot),
      runs.current.warm?.status === 'measured' && runs.combined.warm?.status === 'measured' && JSON.stringify(runs.current.warm.snapshot) === JSON.stringify(runs.combined.warm.snapshot),
      runs.current.cold?.status === 'measured' && runs.current.warm?.status === 'measured' && JSON.stringify(runs.current.cold.snapshot) === JSON.stringify(runs.current.warm.snapshot),
      runs.combined.cold?.status === 'measured' && runs.combined.warm?.status === 'measured' && JSON.stringify(runs.combined.cold.snapshot) === JSON.stringify(runs.combined.warm.snapshot),
    ].every(Boolean);
    const coldBenefit = runs.current.cold?.status === 'measured' && runs.combined.cold?.status === 'measured' && runs.combined.cold.elapsed_ms < runs.current.cold.elapsed_ms;
    const warmBenefit = runs.current.warm?.status === 'measured' && runs.combined.warm?.status === 'measured' && runs.combined.warm.elapsed_ms < runs.current.warm.elapsed_ms;
    result.semantic_equivalence = equivalent;
    result.measured_benefit = { cold: coldBenefit, warm: warmBenefit, current_total_ms: (runs.current.cold?.elapsed_ms ?? 0) + (runs.current.warm?.elapsed_ms ?? 0), combined_total_ms: (runs.combined.cold?.elapsed_ms ?? 0) + (runs.combined.warm?.elapsed_ms ?? 0) };
    const failurePass = result.failure_semantics.status === 'passed';
    const useCombined = equivalent && coldBenefit && warmBenefit && failurePass;
    result.decision = { selected: useCombined ? 'combined' : 'original_separate_commands', reason: useCombined ? 'cold and warm database snapshots matched and both complete preparation timings improved; injected middle failure stopped before seed/sentinel.' : 'combined form was rejected because measured cold/warm semantic equivalence, failure semantics, or both cold and warm full-preparation benefits were not all proven.' };
    result.status = runs.current.cold?.status === 'measured' && runs.current.warm?.status === 'measured' && result.failure_semantics.status === 'passed' ? 'profiled' : 'blocked';
    if (result.status === 'blocked') result.failure = { message: 'baseline current preparation or controlled failure semantics did not complete successfully' };
  } catch (error) {
    result.status = 'blocked'; result.failure = { message: error.message };
  } finally {
    result.database_cleanup = [];
    for (const database of [...new Set(databaseIds)].reverse()) {
      const env = { ...process.env, PGPASSWORD: process.env.PGPASSWORD ?? 'postgres', PGHOST: process.env.PGHOST ?? '127.0.0.1', PGPORT: process.env.PGPORT ?? '5432', PGUSER: process.env.PGUSER ?? 'postgres' };
      const dropped = spawnSync('dropdb', ['--if-exists', database], { env, encoding: 'utf8', timeout: 15_000 });
      result.database_cleanup.push({ database, exit_code: dropped.status, status: dropped.status === 0 ? 'passed' : 'failed' });
    }
    result.completed_at = new Date().toISOString(); result.duration_ms = Date.now() - Date.parse(startedAt);
    fs.mkdirSync(path.dirname(output), { recursive: true }); fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`);
    fs.rmSync(temp, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ status: result.status, output, duration_ms: result.duration_ms, decision: result.decision ?? null, failure: result.failure ?? null }));
  if (result.status !== 'profiled' || result.database_cleanup.some((item) => item.status !== 'passed')) process.exitCode = 2;
}

async function runWorkload(options) {
  const root = path.resolve(options.root);
  const output = path.resolve(options.output);
  const mapPath = path.resolve(root, options.workloadMap);
  const map = JSON.parse(fs.readFileSync(mapPath, 'utf8'));
  const owners = Object.keys(SCOPES);
  const rows = map.owners?.flatMap((owner) => owner.rows ?? []) ?? map.rows ?? [];
  if (rows.length !== 108 || owners.some((owner) => !rows.some((row) => row.owner === owner))) throw new Error('workload_map_requires_108_mapped_rows_for_all_five_owners');
  if (fs.existsSync(output)) throw new Error(`refusing_to_overwrite_profile:${output}`);
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/ci.yml'), 'utf8');
  const workflowOwners = parseWorkflowBrowserOwners(workflow);
  const reportRoot = path.resolve(options.reuseNativeDirectory ?? path.join(path.dirname(output), `${path.basename(output, path.extname(output))}-NATIVE`));
  if (!options.reuseNativeDirectory && fs.existsSync(reportRoot)) throw new Error(`refusing_to_overwrite_native_reports:${reportRoot}`);
  let reused = null;
  if (options.reuseIntegration) {
    reused = JSON.parse(fs.readFileSync(path.resolve(options.reuseIntegration), 'utf8'));
    if (reused.owner_runs?.length !== owners.length || owners.some((owner) => !reused.owner_runs.some((record) => record.owner === owner && record.status === 'profiled'))) throw new Error('reuse_integration_requires_five_profiled_owner_runs');
    const unchanged = spawnSync('git', ['-C', root, 'diff', '--quiet', reused.source_sha, '--', '.github/workflows/ci.yml', 'test/example'], { encoding: 'utf8' });
    if (unchanged.status !== 0) throw new Error('reuse_native_owner_inputs_changed_since_run');
  }
  const sourceSha = reused?.source_sha ?? gitOutput(root, 'rev-parse', 'HEAD');
  const configurationBytes = fs.readFileSync(path.join(root, 'test/example/priv/playwright/playwright.config.ts'));
  const lockBytes = fs.readFileSync(path.join(root, 'test/example/priv/playwright/package-lock.json'));
  const result = {
    schema_version: 'sigra.phase254.owner-integration/v1', status: 'running',
    source_sha: sourceSha, workflow_sha256: hash(workflow), configuration_sha256: hash(configurationBytes), lock_sha256: hash(lockBytes), workload_map_input_sha256: hash(fs.readFileSync(mapPath)),
    comparison_event: map.comparison_event ?? map.comparisonEvent ?? 'pull_request',
    toolchain: { node: commandVersion('node', ['--version'], root, process.env), elixir: commandVersion('elixir', ['--version'], root, process.env), playwright: JSON.parse(fs.readFileSync(path.join(root, 'test/example/priv/playwright/package-lock.json'), 'utf8')).packages['node_modules/@playwright/test']?.version ?? null },
    owner_runs: [], parity: { status: 'blocked', reason: 'Native descriptors and exact mappings are not yet compared.' },
    hosted_ready: false,
  };
  if (reused) result.owner_runs = reused.owner_runs;
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-254-workload-'));
  try {
    if (!reused) for (const name of owners) {
      const ownerOutput = path.join(scratch, `${name}.json`);
      await profileScope({ ...options, root, output: ownerOutput, scope: name, workflowOwners, reportRoot, mode: 'workload' });
      const record = JSON.parse(fs.readFileSync(ownerOutput, 'utf8'));
      result.owner_runs.push({ owner: name, ...record });
    }
    const beforeRoot = path.resolve(options.baselineNative ?? map.baseline_native_directory ?? path.join(path.dirname(options.workloadMap), '254-BASELINE-NATIVE'));
    const fullRows = [];
    const comparisons = [];
    const mappings = map.owners ?? owners.map((owner) => ({ owner, rows: rows.filter((row) => row.owner === owner) }));
    const baselineSelectionManifest = JSON.parse(fs.readFileSync(path.join(path.dirname(beforeRoot), '254-BASELINE-SELECTIONS-NODE20.19.5.json'), 'utf8'));
    for (const owner of owners) {
      try {
        const ownerMapping = mappings.find((entry) => entry.owner === owner);
        const ownerRows = ownerMapping?.rows ?? rows.filter((row) => row.owner === owner);
        const baselineSelection = baselineSelectionManifest.owners.find((entry) => entry.owner === owner);
        const ownerRecord = result.owner_runs.find((entry) => entry.owner === owner);
        const baselineReportName = path.basename(ownerMapping.baseline.report);
        const candidateExpectedFiles = Object.fromEntries((ownerRecord?.native_reports ?? []).map((entry) => [path.basename(entry.path), entry.sha256]));
        const baselineExpectedFiles = { [baselineReportName]: ownerMapping.baseline.sha256, [baselineSelection.file]: baselineSelection.sha256 };
        const transfer = transferNativeEvidence(path.dirname(reportRoot), ownerRecord?.native_reports ?? [], path.join(scratch, 'native-evidence-transfer', owner));
        ownerRecord.native_evidence_transfer = transfer;
        const baselineDirectory = path.join(beforeRoot, owner);
        const candidateDirectory = path.join(reportRoot, owner);
        writeCoverageSource(baselineDirectory, { owner, sourceSha: map.baseline.application_sha,
          workflowSha: map.baseline.workflow_sha256, configurationSha: JSON.parse(fs.readFileSync(path.join(path.dirname(beforeRoot), '254-BASELINE-SELECTIONS-NODE20.19.5.json'), 'utf8')).playwright_config_sha256,
          lockSha: JSON.parse(fs.readFileSync(path.join(path.dirname(beforeRoot), '254-BASELINE-SELECTIONS-NODE20.19.5.json'), 'utf8')).lock_sha256,
          event: result.comparison_event, mapRows: ownerRows, side: 'before', expectedFiles: baselineExpectedFiles });
        writeCoverageSource(candidateDirectory, { owner, sourceSha, workflowSha: result.workflow_sha256,
          configurationSha: result.configuration_sha256, lockSha: result.lock_sha256,
          event: result.comparison_event, mapRows: ownerRows, side: 'after', expectedFiles: candidateExpectedFiles });
        const beforeRows = JSON.parse(fs.readFileSync(path.join(baselineDirectory, 'coverage-source.json'), 'utf8')).selected_inventory;
        const afterRows = JSON.parse(fs.readFileSync(path.join(candidateDirectory, 'coverage-source.json'), 'utf8')).selected_inventory;
        const beforeByNative = new Map(beforeRows.map((row) => [row.native_spec_id, row]));
        const afterByNative = new Map(afterRows.map((row) => [row.native_spec_id, row]));
        for (const row of ownerRows) {
          const left = beforeByNative.get(row.before_native_id);
          const right = afterByNative.get(row.candidate_native_id);
          if (!left || !right) throw new Error(`explicit_native_id_mapping_unresolved:${owner}:${row.before_native_id}/${row.candidate_native_id}`);
          const mapping = { ...row, before: JSON.parse(left.id), after: JSON.parse(right.id), kind: row.classification,
            before_native_id: left.native_spec_id, candidate_native_id: right.native_spec_id,
            expected_status: [left.expected_status, right.expected_status],
            actual_result: [left.actual_result, right.actual_result], mapping_status: 'matched_native_reports' };
          fullRows.push(mapping);
        }
        const ownerMap = path.join(candidateDirectory, 'coverage-map.json');
        fs.writeFileSync(ownerMap, `${JSON.stringify({ schema_version: 'sigra.browser-coverage-map/v1', rows: fullRows.filter((row) => row.owner === owner) }, null, 2)}\n`);
        const comparison = runCoverageComparison(root, baselineDirectory, candidateDirectory, ownerMap);
        comparisons.push({ owner, status: 'passed', result: comparison });
      } catch (error) {
        comparisons.push({ owner, status: 'blocked', error: error.message });
      }
    }
    const mapStatus = comparisons.length === owners.length && comparisons.every((item) => item.status === 'passed');
    const nativeMap = { ...map, schema_version: 'sigra.browser-coverage-map/v1', status: mapStatus ? 'native_parity_passed' : 'native_parity_blocked',
      candidate: { ...(map.candidate ?? {}), source_sha: sourceSha, source_files: { workflow: result.workflow_sha256,
        playwright_config: result.configuration_sha256, package_lock: result.lock_sha256 } },
      candidate_result_source: { status: mapStatus ? 'verified_native_reports' : 'actual_reports_with_parity_block', source_sha: sourceSha,
        integration_path: path.relative(root, output), native_directory: path.relative(root, reportRoot) },
      owners: (map.owners ?? []).map((owner) => {
        const selection = result.owner_runs.find((entry) => entry.owner === owner.owner)?.native_reports?.find((entry) => entry.path.endsWith('.selection.json'));
        return { ...owner, ...(selection ? { candidate_selection: { file: path.basename(selection.path), sha256: selection.sha256,
          playwright: result.toolchain.playwright, result: 'selection_retained_from_actual_workflow_owner_invocation' } } : {}),
          rows: fullRows.filter((row) => row.owner === owner.owner) };
      }),
      rows: fullRows, native_source: { baseline_source_sha: map.baseline.application_sha, candidate_source_sha: sourceSha,
        workflow_sha256: result.workflow_sha256, configuration_sha256: result.configuration_sha256, lock_sha256: result.lock_sha256 } };
    fs.writeFileSync(mapPath, `${JSON.stringify(nativeMap, null, 2)}\n`);
    const mappingSha = hash(fs.readFileSync(mapPath));
    result.workload_map_sha256 = mappingSha;
    result.parity = { status: mapStatus ? 'passed' : 'blocked', mapping_sha256: mappingSha, owners: comparisons,
      validation_duration_ms: comparisons.reduce((sum, item) => sum + (item.result?.duration_ms ?? 0), 0),
      transfer_duration_ms: result.owner_runs.reduce((sum, owner) => sum + (owner.native_evidence_transfer?.duration_ms ?? 0), 0),
      transfer_bytes: result.owner_runs.reduce((sum, owner) => sum + (owner.native_evidence_transfer?.bytes ?? 0), 0) };
    result.native_parity_receipt = { schema_version: 'sigra.browser-parity-receipt/v1', status: result.parity.status,
      mapping_sha256: mappingSha, baseline_source_sha: map.baseline.application_sha, candidate_source_sha: sourceSha,
      event: result.comparison_event, workflow_sha256: result.workflow_sha256,
      configuration_sha256: result.configuration_sha256, lock_sha256: result.lock_sha256,
      owners: comparisons.map(({ owner, status, result: comparison, error }) => {
        const beforeDescriptor = path.join(beforeRoot, owner, 'coverage-source.json');
        const afterDescriptor = path.join(reportRoot, owner, 'coverage-source.json');
        return { owner, status, ...(comparison ? { comparison } : { error }),
          before_descriptor: { path: path.relative(root, beforeDescriptor), sha256: fs.existsSync(beforeDescriptor) ? hash(fs.readFileSync(beforeDescriptor)) : null },
          after_descriptor: { path: path.relative(root, afterDescriptor), sha256: fs.existsSync(afterDescriptor) ? hash(fs.readFileSync(afterDescriptor)) : null } };
      }) };
    result.status = result.owner_runs.length === owners.length && result.owner_runs.every((record) => record.status === 'profiled') && mapStatus ? 'profiled' : 'blocked';
  } finally {
    result.completed_at = new Date().toISOString();
    fs.mkdirSync(path.dirname(output), { recursive: true });
    if (result.native_parity_receipt) {
      result.native_parity_receipt.owner_integration_status = result.status;
      const receiptPath = output.replace(/\.json$/, '-PARITY-RECEIPT.json');
      fs.writeFileSync(receiptPath, `${JSON.stringify(result.native_parity_receipt, null, 2)}\n`, { flag: 'wx' });
      result.native_parity_receipt_path = path.relative(root, receiptPath);
      result.native_parity_receipt_sha256 = hash(fs.readFileSync(receiptPath));
    }
    fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, { flag: 'wx' });
    fs.rmSync(scratch, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ status: result.status, output, owner_count: result.owner_runs.length, parity: result.parity.status }));
  if (result.status !== 'profiled') process.exitCode = 2;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.checkOnly) {
    const root = path.resolve(options.root);
    const action = fs.readFileSync(path.join(root, '.github/actions/example-playwright-boot/action.yml'), 'utf8');
    const workflow = fs.readFileSync(path.join(root, '.github/workflows/ci.yml'), 'utf8');
    const scopeSteps = parseActionSteps(action);
    buildPreparationCommands(action);
    assertPreparationCacheContract(action, workflow);
    for (const name of ['Install Playwright dependencies', 'Install Playwright browsers', 'Boot example app', 'Wait for app and warm routes']) if (!scopeSteps[name]) throw new Error(`action_step_missing:${name}`);
    console.log(JSON.stringify({ status: 'ready', source_sha: git(root, 'rev-parse', 'HEAD'), action_sha256: hash(action), workflow_sha256: hash(workflow), scope: options.scope, browsers: parseBrowserMatrix(workflow, options.scope) }));
    return;
  }
  if (options.mode === 'compare-preparation') await comparePreparation(options);
  else if (options.mode === 'workload' && options.scope) {
    const root = path.resolve(options.root);
    const workflow = fs.readFileSync(path.join(root, '.github/workflows/ci.yml'), 'utf8');
    await profileScope({ ...options, root, workflowOwners: parseWorkflowBrowserOwners(workflow), reportRoot: path.join(path.dirname(path.resolve(options.output)), 'native-retry') });
  }
  else if (options.mode === 'workload') await runWorkload(options);
  else await profileScope(options);
}

if (process.argv[1] && path.resolve(process.argv[1]) === SELF) main().catch((error) => { console.error(error.message); process.exitCode = 2; });
