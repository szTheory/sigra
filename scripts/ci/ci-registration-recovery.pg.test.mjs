// Real-Postgres integration test for the R5 account count (253-79).
// Unlike ci-registration-recovery.test.mjs this file talks to a real server through real psql and
// mix. It creates and drops ONE database in the owned sigra_253_control_ namespace and never
// connects to example_test or sigra_test data. Unreachable Postgres is a failure, never a skip.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import * as recovery from './ci-registration-recovery.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const exampleDir = path.join(root, 'test/example');
const UNAVAILABLE = 'Postgres unavailable: source tmp/db.env (scripts/db/up.sh)';

function connectionEnv() {
  const { PGHOST, PGPORT, PGUSER, PGPASSWORD } = process.env;
  assert.ok(PGHOST && PGPORT && PGUSER, UNAVAILABLE);
  return { ...process.env, PGHOST, PGPORT, PGUSER, PGPASSWORD: PGPASSWORD ?? '' };
}

function psql(env, database, args, input) {
  return spawnSync('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-A', '-t', '-h', env.PGHOST, '-p', env.PGPORT, '-U', env.PGUSER, '-d', database, ...args], { env: { ...env, PGDATABASE: database }, input, encoding: 'utf8', timeout: 30_000 });
}

test('R5 account count against a real migrated example database', { timeout: 240_000 }, () => {
  const env = connectionEnv();
  const probe = psql(env, 'postgres', ['-c', 'select 1']);
  assert.equal(probe.status, 0, `${UNAVAILABLE}\n${probe.stderr}${probe.error?.message ?? ''}`);

  const tag = `${Date.now().toString(36)}_${process.pid}`;
  const database = `sigra_253_control_r5itest_${tag}`;
  assert.match(database, /^sigra_253_control_[a-z0-9_]+$/);
  const label = Date.now().toString(36);
  const email = `platform-admin+sigra-253-control-${label}-collision@example.test`;
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-r5-pg-'));
  const mixEnv = { ...env, MIX_ENV: 'dev', PGDATABASE: database, PORT: env.PORT ?? '4011', SIGRA_EXAMPLE_BIND: '127.0.0.1' };
  const deadline = () => Number(process.hrtime.bigint()) / 1e6 + 20_000;
  try {
    const setup = spawnSync('mix', ['ecto.setup'], { cwd: exampleDir, env: mixEnv, encoding: 'utf8', timeout: 200_000 });
    assert.equal(setup.status, 0, `mix ecto.setup failed\n${setup.stdout?.slice(-2000)}\n${setup.stderr?.slice(-2000)}`);

    const schema = recovery.accountSchemaR5(root);
    assert.equal(schema, 'auth');
    const capture = (options = {}) => recovery.captureOwnedAccountCountR5({ database, email, env, cwd: root, root, log: path.join(work, 'count.log'), deadline: deadline(), ...options });

    // (a) absent synthetic account -> count 0 through the real R5 capture
    const absent = capture();
    assert.equal(absent.exit_code, 0, absent.stderr_first_line);
    assert.equal(absent.count, 0);
    assert.equal(absent.schema_binding.name, 'auth');

    // (b) after one insert into the derived schema -> count 1
    const insert = psql(env, database, ['-v', `target=${email}`], `INSERT INTO "${schema}".users (id, email, inserted_at, updated_at) VALUES (gen_random_uuid(), :'target', now(), now());\n`);
    assert.equal(insert.status, 0, insert.stderr);
    const present = capture();
    assert.equal(present.exit_code, 0, present.stderr_first_line);
    assert.equal(present.count, 1);

    // (c) positive control: the legacy unqualified capture fails on the same database
    const legacy = recovery.captureOwnedAccountCount({ database, email, env, cwd: root, log: path.join(work, 'legacy.log'), deadline: deadline() });
    assert.equal(legacy.exit_code, 3);
    assert.equal(legacy.count, null);

    // (d) a deliberately wrong schema yields a diagnosable, redacted failure
    const wrong = capture({ schema: 'no_such_schema_r5' });
    assert.notEqual(wrong.exit_code, 0);
    assert.match(wrong.stderr_first_line, /does not exist/);
    assert.equal(JSON.stringify(wrong).includes(email), false);
    assert.equal(fs.readFileSync(path.join(work, 'count.log.stderr.log'), 'utf8').includes(email), false);
  } finally {
    {
      const drop = spawnSync('mix', ['ecto.drop', '--quiet'], { cwd: exampleDir, env: mixEnv, encoding: 'utf8', timeout: 60_000 });
      if (drop.status !== 0) spawnSync('psql', ['-X', '-h', env.PGHOST, '-p', env.PGPORT, '-U', env.PGUSER, '-d', 'postgres', '-c', `DROP DATABASE IF EXISTS "${database}"`], { env, encoding: 'utf8', timeout: 30_000 });
    }
    // (e) independent absence proof through the shared capture
    const absence = recovery.captureOwnedDatabaseAbsence({ database, env, cwd: root, log: path.join(work, 'absence.log'), deadline: deadline() });
    fs.rmSync(work, { recursive: true, force: true });
    assert.equal(absence.exit_code, 0);
    assert.equal(absence.stdout_count, 0, 'owned database must be absent after drop');
  }
});

test('Postgres unavailable fails closed with the sourcing hint', () => {
  const saved = process.env.PGHOST;
  delete process.env.PGHOST;
  try { assert.throws(() => connectionEnv(), /Postgres unavailable: source tmp\/db\.env/); } finally { if (saved !== undefined) process.env.PGHOST = saved; }
});
