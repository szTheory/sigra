#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const MAX_MS = 20 * 60 * 1000;
const PROJECTS = [
  ['admin-eval', 25311],
  ['admin-eval-mobile', 25312],
  ['admin-eval-dark', 25313]
];

export function remainingMs(deadline, now = Date.now()) {
  return Math.max(0, deadline - now);
}

function digest(file) {
  return fs.existsSync(file) ? crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') : null;
}

function command(program, args, options) {
  const fd = fs.openSync(options.log, 'w');
  let result;
  try {
    result = spawnSync(program, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: ['ignore', fd, fd],
      timeout: Math.max(1, options.timeout),
      killSignal: 'SIGKILL'
    });
  } finally {
    fs.closeSync(fd);
  }
  return {
    exit_code: result.status,
    signal: result.signal,
    error: result.error?.message ?? null,
    log_path: options.log,
    log_sha256: digest(options.log)
  };
}

function requestStatus(url) {
  return new Promise((resolve) => {
    const req = http.get(url, { timeout: 2000 }, (res) => {
      res.resume();
      res.on('end', () => resolve(res.statusCode));
    });
    req.on('timeout', () => req.destroy());
    req.on('error', () => resolve(null));
  });
}

function portAvailable(port) {
  return new Promise((resolve) => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(false); });
    socket.once('error', (error) => { socket.destroy(); resolve(error.code === 'ECONNREFUSED'); });
    socket.setTimeout(2000, () => { socket.destroy(); resolve(false); });
  });
}

export async function waitForReady(child, url, deadline, request = requestStatus) {
  const readinessDeadline = Math.min(deadline, Date.now() + 90_000);
  while (remainingMs(readinessDeadline) > 0) {
    if (child.exitCode !== null || child.signalCode !== null) return null;
    const status = await request(url);
    if (status === 200) return status;
    await new Promise((resolve) => setTimeout(resolve, Math.min(250, remainingMs(readinessDeadline))));
  }
  return null;
}

export async function stopProcess(child) {
  if (!child?.pid || child.exitCode !== null || child.signalCode !== null) return;
  try { process.kill(-child.pid, 'SIGTERM'); } catch { child.kill('SIGTERM'); }
  let timer;
  await Promise.race([
    new Promise((resolve) => child.once('exit', resolve)),
    new Promise((resolve) => { timer = setTimeout(resolve, 5000); })
  ]);
  clearTimeout(timer);
  if (child.exitCode === null && child.signalCode === null) {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); }
  }
}

function parseArgs(argv) {
  if (argv.length !== 4 || argv[0] !== '--root' || argv[2] !== '--output' || !argv[1] || !argv[3]) {
    throw new Error('usage: ci-registration-setup-diagnostic.mjs --root <repo> --output <new-evidence.json>');
  }
  return { root: path.resolve(argv[1]), output: path.resolve(argv[3]) };
}

async function main() {
  const { root, output } = parseArgs(process.argv.slice(2));
  if (fs.existsSync(output)) throw new Error(`refusing to overwrite setup evidence: ${output}`);
  const head = spawnSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' });
  if (head.status !== 0) throw new Error('cannot identify source checkout');
  const dirty = spawnSync('git', ['-C', root, 'diff', '--quiet']);
  const staged = spawnSync('git', ['-C', root, 'diff', '--cached', '--quiet']);
  if (dirty.status !== 0 || staged.status !== 0) throw new Error('tracked source changes must be committed before setup diagnostic');

  const start = Date.now();
  const deadline = start + MAX_MS;
  const artifactDir = `${output}.logs`;
  // Mix creates relative dependency links; macOS TMPDIR may spell /private/var as /var.
  const workDir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-setup-')));
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.mkdirSync(artifactDir);
  const evidence = {
    schema_version: 'sigra.phase253.registration-setup-diagnostic/v1',
    status: 'running', source_checkout_head: head.stdout.trim(),
    started_at: new Date(start).toISOString(),
    limits: { max_project_launches: 3, max_duration_seconds: 1200, automatic_retries: 0, browser_invocations: 0 },
    project_launches: [], commands: []
  };
  const save = () => fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`);
  fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`, { flag: 'wx' });
  const run = (label, program, args, cwd, env = process.env) => {
    if (!remainingMs(deadline)) throw new Error('20-minute setup deadline reached');
    const result = command(program, args, {
      cwd, env, timeout: remainingMs(deadline), log: path.join(artifactDir, `${label}.log`)
    });
    evidence.commands.push({ label, program, args, ...result });
    save();
    if (result.exit_code !== 0) throw new Error(`${label} failed: exit ${result.exit_code}, signal ${result.signal ?? 'none'}; ${result.error ?? ''}`);
    return result;
  };
  let app = null;
  try {
    const checkout = path.join(workDir, 'repo');
    run('clone', 'git', ['clone', '--quiet', '--shared', '--no-checkout', root, checkout], root);
    run('checkout', 'git', ['-C', checkout, 'checkout', '--quiet', '--detach', head.stdout.trim()], root);
    const example = path.join(checkout, 'test/example');
    const hexHome = path.join(workDir, 'hex');
    fs.mkdirSync(hexHome);
    const baseEnv = { ...process.env, HEX_HOME: hexHome, MIX_ENV: 'dev' };
    run('deps-get', 'mix', ['deps.get', '--check-locked'], example, baseEnv);

    for (const [project, port] of PROJECTS) {
      if (evidence.project_launches.length >= 3) throw new Error('three-launch ceiling reached');
      const database = `sigra_253_setup_${start}_${project.replaceAll('-', '_')}_${process.pid}`;
      const env = {
        ...baseEnv, MIX_BUILD_PATH: path.join(workDir, `build-${project}`),
        PORT: String(port), SIGRA_EXAMPLE_BIND: '127.0.0.1',
        PGHOST: process.env.PGHOST ?? '127.0.0.1', PGPORT: process.env.PGPORT ?? '58624',
        PGUSER: process.env.PGUSER ?? 'postgres', PGPASSWORD: process.env.PGPASSWORD ?? 'postgres',
        PGDATABASE: database
      };
      const projectResult = { project, port, database, server_ready: false, browser_invocations: 0 };
      evidence.project_launches.push(projectResult);
      save();
      try {
        projectResult.setup = run(`${project}.db`, 'mix', ['ecto.setup'], example, env);
        projectResult.port_available_before_launch = await portAvailable(port);
        save();
        if (!projectResult.port_available_before_launch) throw new Error(`port ${port} is occupied before ${project} launch`);
        const appLog = path.join(artifactDir, `${project}.app.log`);
        const fd = fs.openSync(appLog, 'w');
        try {
          app = spawn('mix', ['phx.server'], { cwd: example, env, stdio: ['ignore', fd, fd], detached: true });
          app.on('error', (error) => { projectResult.app_launch_error = error.message; });
        } finally {
          fs.closeSync(fd);
        }
        projectResult.app_pid = app.pid ?? null;
        projectResult.app_log_path = appLog;
        projectResult.app_launch_error = app.pid ? null : 'mix phx.server did not spawn';
        save();
        if (!app.pid) throw new Error(projectResult.app_launch_error ?? 'mix phx.server did not spawn');
        const status = await waitForReady(app, `http://127.0.0.1:${port}/`, deadline);
        projectResult.http_status = status;
        projectResult.server_ready = status === 200;
        projectResult.app_exit_code_before_shutdown = app.exitCode;
        projectResult.app_signal_before_shutdown = app.signalCode;
        projectResult.app_log_sha256 = digest(appLog);
        save();
        if (!projectResult.server_ready) throw new Error(`${project} did not reach HTTP 200 on ${port}`);
      } finally {
        await stopProcess(app);
        app = null;
        projectResult.app_log_sha256 = projectResult.app_log_path ? digest(projectResult.app_log_path) : null;
        projectResult.drop = command('mix', ['ecto.drop', '--quiet'], {
          cwd: example, env, timeout: Math.max(1, remainingMs(deadline)),
          log: path.join(artifactDir, `${project}.drop.log`)
        });
        save();
      }
      if (projectResult.drop.exit_code !== 0) throw new Error(`${project} database cleanup failed: exit ${projectResult.drop.exit_code}`);
    }
    evidence.status = 'setup_passed';
  } catch (error) {
    await stopProcess(app);
    evidence.status = 'setup_failed';
    evidence.failure = { message: error.message };
    process.exitCode = 1;
  } finally {
    evidence.completed_at = new Date().toISOString();
    evidence.duration_seconds = Math.floor((Date.now() - start) / 1000);
    save();
    fs.rmSync(workDir, { recursive: true, force: true });
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 2; });
}
