import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { remainingMs, stopProcess, waitForReady } from './ci-registration-setup-diagnostic.mjs';

const script = fileURLToPath(new URL('./ci-registration-setup-diagnostic.mjs', import.meta.url));

function git(cwd, args) {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
}

function fixture() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-setup-test-'));
  const repo = path.join(dir, 'repo');
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(path.join(repo, 'test/example'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'test/example/deps/jose/include'), { recursive: true });
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(repo, 'test/example/README'), 'fixture\n');
  fs.writeFileSync(path.join(repo, 'test/example/deps/jose/include/jose_jwt.hrl'), 'fixture header\n');
  git(repo, ['init', '-q']);
  git(repo, ['add', 'test/example']);
  git(repo, ['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture']);
  const mix = path.join(bin, 'mix');
  fs.writeFileSync(mix, `#!/bin/sh
case "$1" in
  deps.get) exit 0 ;;
  ecto.setup)
    if [ "\${SIGRA_SETUP_TEST_MODE:-}" = success ]; then exit 0; fi
    if [ "\${SIGRA_SETUP_TEST_MODE:-}" = symlink ]; then
      node -e 'const fs = require("node:fs"); const path = require("node:path"); const base = path.join(process.env.MIX_BUILD_PATH, "lib/jose"); fs.mkdirSync(base, {recursive: true}); const source = fs.realpathSync("deps/jose/include"); fs.symlinkSync(path.relative(base, source), path.join(base, "include")); if (!fs.existsSync(path.join(base, "include/jose_jwt.hrl"))) { console.error("JOSE include link is broken"); process.exit(43); } console.log("JOSE include link resolved at " + process.env.MIX_BUILD_PATH);'
      exit $?
    fi
    echo "forced setup failure" >&2; exit 42 ;;
  ecto.drop) exit 0 ;;
  phx.server) exec node -e 'require("node:http").createServer((_, res) => {res.statusCode=200;res.end("ready")}).listen(Number(process.env.PORT), "127.0.0.1")' ;;
  *) echo "unexpected mix command: $*" >&2; exit 99 ;;
esac
`, { mode: 0o755 });
  return { dir, repo, bin };
}

test('setup failure keeps nonzero command evidence and never starts a server or browser', () => {
  const f = fixture();
  try {
    const output = path.join(f.dir, 'diagnostic.json');
    const result = spawnSync(process.execPath, [script, '--root', f.repo, '--output', output], {
      env: { ...process.env, PATH: `${f.bin}${path.delimiter}${process.env.PATH}` }, encoding: 'utf8', timeout: 10_000
    });
    assert.equal(result.status, 1, result.stderr);
    const evidence = JSON.parse(fs.readFileSync(output, 'utf8'));
    assert.equal(evidence.status, 'setup_failed');
    assert.equal(evidence.project_launches.length, 1);
    assert.equal(evidence.project_launches[0].app_pid, undefined);
    assert.equal(evidence.limits.automatic_retries, 0);
    assert.equal(evidence.limits.browser_invocations, 0);
    const failures = evidence.commands.filter((command) => command.exit_code !== 0);
    assert.equal(failures.length, 1);
    assert.equal(failures[0].label, 'admin-eval.db');
    assert.equal(failures[0].exit_code, 42);
    assert.match(fs.readFileSync(failures[0].log_path, 'utf8'), /forced setup failure/);
  } finally {
    fs.rmSync(f.dir, { recursive: true, force: true });
  }
});

test('setup-only entrypoint completes three isolated fixture ports within its budget', () => {
  const f = fixture();
  try {
    const output = path.join(f.dir, 'diagnostic.json');
    const result = spawnSync(process.execPath, [script, '--root', f.repo, '--output', output], {
      env: { ...process.env, PATH: `${f.bin}${path.delimiter}${process.env.PATH}`, SIGRA_SETUP_TEST_MODE: 'success' },
      encoding: 'utf8', timeout: 15_000
    });
    assert.equal(result.status, 0, result.stderr);
    const evidence = JSON.parse(fs.readFileSync(output, 'utf8'));
    assert.equal(evidence.status, 'setup_passed');
    assert.deepEqual(evidence.project_launches.map((project) => project.port), [25311, 25312, 25313]);
    for (const project of evidence.project_launches) {
      assert.equal(project.server_ready, true);
      assert.equal(project.http_status, 200);
      assert.equal(project.drop.exit_code, 0);
      assert.equal(project.browser_invocations, 0);
      assert.equal(project.port_available_before_launch, true);
      assert.ok(project.app_log_sha256);
    }
    assert.equal(evidence.duration_seconds < 1200, true);
    assert.equal(evidence.limits.automatic_retries, 0);
  } finally {
    fs.rmSync(f.dir, { recursive: true, force: true });
  }
});

test('symlinked TMPDIR still gives Mix a resolvable JOSE include path', () => {
  const f = fixture();
  try {
    const alias = path.join(f.dir, 'temp-alias');
    fs.symlinkSync(fs.realpathSync(f.dir), alias, 'dir');
    const canonicalTemp = fs.realpathSync(alias);
    assert.notEqual(alias, canonicalTemp);
    const output = path.join(f.dir, 'diagnostic.json');
    const result = spawnSync(process.execPath, [script, '--root', f.repo, '--output', output], {
      env: {
        ...process.env, TMPDIR: alias, PATH: `${f.bin}${path.delimiter}${process.env.PATH}`,
        SIGRA_SETUP_TEST_MODE: 'symlink'
      },
      encoding: 'utf8', timeout: 15_000
    });
    const evidence = JSON.parse(fs.readFileSync(output, 'utf8'));
    assert.equal(result.status, 0, JSON.stringify(evidence.failure));
    assert.equal(evidence.status, 'setup_passed');
    assert.deepEqual(evidence.project_launches.map((project) => project.port), [25311, 25312, 25313]);
    for (const command of evidence.commands.filter((item) => item.label.endsWith('.db'))) {
      const log = fs.readFileSync(command.log_path, 'utf8');
      const build = log.match(/JOSE include link resolved at (.+)/)?.[1];
      assert.ok(build, log);
      assert.ok(build.startsWith(`${canonicalTemp}${path.sep}`), build);
    }
  } finally {
    fs.rmSync(f.dir, { recursive: true, force: true });
  }
});

test('existing terminal evidence and dirty source are rejected before output mutation', () => {
  const f = fixture();
  try {
    const output = path.join(f.dir, 'diagnostic.json');
    fs.writeFileSync(output, '{"status":"terminal"}\n');
    const original = fs.readFileSync(output);
    const args = [script, '--root', f.repo, '--output', output];
    const existing = spawnSync(process.execPath, args, { encoding: 'utf8', timeout: 10_000 });
    assert.equal(existing.status, 2);
    assert.deepEqual(fs.readFileSync(output), original);
    fs.unlinkSync(output);
    fs.writeFileSync(path.join(f.repo, 'test/example/README'), 'dirty\n');
    const dirty = spawnSync(process.execPath, args, { encoding: 'utf8', timeout: 10_000 });
    assert.equal(dirty.status, 2);
    assert.equal(fs.existsSync(output), false);
  } finally {
    fs.rmSync(f.dir, { recursive: true, force: true });
  }
});

test('deadline clamps at zero and owned process group is stopped', async () => {
  assert.equal(remainingMs(100, 101), 0);
  assert.equal(remainingMs(100, 95), 5);
  let requests = 0;
  assert.equal(await waitForReady({ exitCode: null, signalCode: null }, 'http://127.0.0.1:1/', Date.now() - 1, () => { requests++; return 200; }), null);
  assert.equal(requests, 0);
  const child = spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { detached: true, stdio: 'ignore' });
  assert.ok(child.pid);
  await stopProcess(child);
  assert.notEqual(child.exitCode ?? child.signalCode, null);
});
