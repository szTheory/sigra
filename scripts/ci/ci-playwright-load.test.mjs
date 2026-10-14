// Offline contract: the real admin-eval spec and its canonicalizer load under the
// pinned Node 20 / Playwright 1.59.1 transform without a Playwright CLI, browser,
// application or network (Phase 253 plan 36, CIREL-01).
//
// Run: ASDF_NODEJS_VERSION=20.18.1 asdf exec node --test scripts/ci/ci-playwright-load.test.mjs
//
// Successful loading here proves only that collection works. It is NOT native or hosted
// acceptance and says nothing about the historical CR-DARK-FIRST registration cause.

import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const PW_DIR = join(REPO, 'test', 'example', 'priv', 'playwright');
const requireFromPw = createRequire(join(PW_DIR, 'package.json'));

// Git blob of canonicalize.ts before the repair (static `import { parseFragment } from 'parse5'`).
const OLD_CANONICALIZE_BLOB = '52112f070ab060a79f856f8f6b556a3aee65a9a4';

const FIXTURE_HTML =
  '<div role="navigation" class="sg-nav b-class" data-testid="main-nav" data-phx-id="a">' +
  '<a href="/admin/users?vsn=abc123&page=1" class="sg-link">Users</a><span aria-label="badge">3</span></div>';

const FIRST_TITLES = [
  'registration waits for explicitly released LiveView readiness',
  'registration stops when LiveView readiness is never released',
  'registration fails when the readiness wait is deliberately broken',
  'registration detects a deliberate same-account collision',
  'registration retains the first forced assertion failure trace',
];
const SECOND_TITLES = [
  'registration starts from a fresh database and context',
  'registration discards trace after a passing control',
];
const ORIGINAL_BOARD_TITLE = 'render bundle: board-mg-9/populated';

function pwPath(rel) {
  return join(PW_DIR, 'node_modules', 'playwright', rel);
}

// Worker run in a fresh Node process. Denies child processes and network so a regression
// that launches a CLI, browser or server fails loudly instead of silently spending one.
const WORKER = String.raw`
const path = require('node:path');
const PW = process.env.LOAD_PW_DIR;
const mode = process.env.LOAD_MODE;
const denied = [];
const cp = require('node:child_process');
for (const name of ['spawn','spawnSync','exec','execSync','execFile','execFileSync','fork']) {
  cp[name] = (...args) => { denied.push(name); throw new Error('denied child_process.' + name + ' ' + String(args[0])); };
}
for (const mod of ['node:net','node:http','node:https','node:tls','node:dgram']) {
  const m = require(mod);
  for (const name of ['connect','createConnection','request','get','createSocket']) {
    if (typeof m[name] === 'function') m[name] = () => { denied.push(mod + '.' + name); throw new Error('denied ' + mod + '.' + name); };
  }
}
const out = (o) => process.stdout.write('\n@@RESULT@@' + JSON.stringify(o) + '\n');
(async () => {
  process.chdir(PW);
  const transform = require(path.join(PW, 'node_modules/playwright/lib/transform/transform.js'));
  if (mode === 'import') {
    try {
      await transform.requireOrImport(process.env.LOAD_FILE);
      out({ ok: true, denied });
    } catch (e) {
      out({ ok: false, message: String(e && e.message), code: e && e.code, denied });
    }
  } else if (mode === 'transformed') {
    const fs = require('node:fs');
    const file = process.env.LOAD_FILE;
    const code = transform.transformHook(fs.readFileSync(file, 'utf8'), file).code;
    out({ code, denied });
  } else if (mode === 'hash') {
    const mod = await transform.requireOrImport(process.env.LOAD_FILE);
    const ret = mod.renderSha256(process.env.LOAD_HTML);
    out({ isPromise: typeof ret.then === 'function', hash: await ret, denied });
  } else if (mode === 'collect') {
    const { loadConfigFromFile } = require(path.join(PW, 'node_modules/playwright/lib/common/configLoader.js'));
    const { loadTestFile } = require(path.join(PW, 'node_modules/playwright/lib/common/testLoader.js'));
    const config = await loadConfigFromFile(path.join(PW, 'playwright.config.ts'));
    const errors = [];
    const suite = await loadTestFile(path.join(PW, 'tests/admin-eval.spec.ts'), config, errors);
    out({ errors, titles: suite.allTests().map((t) => t.title), denied });
  } else if (mode === 'recovery-summary') {
    const { loadConfigFromFile } = require(path.join(PW, 'node_modules/playwright/lib/common/configLoader.js'));
    const { loadTestFile } = require(path.join(PW, 'node_modules/playwright/lib/common/testLoader.js'));
    const config = await loadConfigFromFile(path.join(PW, process.env.LOAD_CONFIG));
    const errors = [];
    const suite = await loadTestFile(path.join(PW, 'tests/admin-eval.spec.ts'), config, errors);
    const titles = suite.allTests().map((t) => t.title);
    const projects = {};
    for (const p of config.projects) {
      const project = p.project;
      projects[project.name] = {
        use: JSON.parse(JSON.stringify(project.use)), retries: project.retries, timeout: project.timeout,
        testMatch: String(project.testMatch), testDir: project.testDir, outputDir: project.outputDir,
        expect: project.expect, workers: p.workers, fullyParallel: p.fullyParallel,
        selected: titles.filter((title) => project.grep.test(title)),
      };
    }
    out({ errors, projects, workers: config.config.workers, fullyParallel: config.config.fullyParallel,
      reporter: config.config.reporter, projectNames: config.projects.map((p) => p.project.name), denied });
  } else if (mode === 'bundle') {
    // bundle.ts uses import.meta.url, so it only loads as ESM: the caller copies it into a
    // type:module tree. Loading the real config first registers Playwright's ESM loader.
    const { loadConfigFromFile } = require(path.join(PW, 'node_modules/playwright/lib/common/configLoader.js'));
    await loadConfigFromFile(path.join(PW, 'playwright.config.ts'));
    const mod = await transform.requireOrImport(process.env.LOAD_FILE);
    const result = await mod.writeBundle({
      appGitSha: process.env.LOAD_SHA, surface: 'load-contract', theme: 'light', viewport: 'desktop',
      state: 'populated', outerHTML: process.env.LOAD_HTML, pngBuffer: Buffer.from([0]),
      axeJson: {}, facts: {}, findings: [{ probe_class: 'x', anchor: 'a', description: 'd', severity: 'warn' }],
    });
    out({ result, denied });
  }
})().catch((e) => { out({ fatal: String(e && e.stack || e), denied }); process.exit(1); });
`;

function runWorker(mode, env = {}) {
  const res = spawnSync(process.execPath, ['-e', WORKER], {
    cwd: tmpdir(),
    encoding: 'utf8',
    env: { PATH: process.env.PATH, HOME: process.env.HOME, LOAD_PW_DIR: PW_DIR, LOAD_MODE: mode, ...env },
    timeout: 60_000,
  });
  const marker = '@@RESULT@@';
  const line = (res.stdout || '').split('\n').find((l) => l.startsWith(marker));
  assert.ok(line, `worker ${mode} produced no result (status ${res.status}): ${res.stderr}`);
  const parsed = JSON.parse(line.slice(marker.length));
  assert.deepEqual(parsed.denied, [], `worker ${mode} attempted a denied process/network call`);
  return parsed;
}

test('runtime and dependency identities are the frozen ones', () => {
  assert.equal(process.version, 'v20.18.1', 'run under asdf Node 20.18.1');
  assert.equal(requireFromPw('playwright/package.json').version, '1.59.1');
  assert.equal(JSON.parse(readFileSync(join(PW_DIR, 'node_modules', 'parse5', 'package.json'), 'utf8')).version, '8.0.1');
});

test('preserved static-import canonicalizer fails under the real pinned CJS transform (RED)', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'sigra-old-canon-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const oldSource = execFileSync('git', ['cat-file', 'blob', OLD_CANONICALIZE_BLOB], { cwd: REPO, encoding: 'utf8' });
  assert.match(oldSource, /import \{ parseFragment \} from 'parse5';/);
  mkdirSync(join(dir, 'lib'));
  const file = join(dir, 'lib', 'canonicalize.ts');
  writeFileSync(file, oldSource);
  symlinkSync(join(PW_DIR, 'node_modules'), join(dir, 'node_modules'));
  writeFileSync(join(dir, 'package.json'), '{"name":"old-canon","private":true}');

  const result = runWorker('import', { LOAD_FILE: file });
  assert.equal(result.ok, false);
  assert.match(result.message, /require\(\) of ES Module .*parse5.* not supported/);
});

test('repaired canonicalizer is transformed to a native dynamic import, not require', () => {
  const file = join(PW_DIR, 'lib', 'eval', 'canonicalize.ts');
  const { code } = runWorker('transformed', { LOAD_FILE: file });
  assert.match(code, /import\(['"]parse5['"]\)/);
  assert.doesNotMatch(code, /require\(['"]parse5['"]\)/);
  assert.doesNotMatch(code, /Promise\.resolve\(\)\.then\(\(\) => .*require\(['"]parse5/);
});

test('repaired renderSha256 resolves to a stable 64-hex hash and still detects semantic change', () => {
  const file = join(PW_DIR, 'lib', 'eval', 'canonicalize.ts');
  const a = runWorker('hash', { LOAD_FILE: file, LOAD_HTML: FIXTURE_HTML });
  const again = runWorker('hash', { LOAD_FILE: file, LOAD_HTML: FIXTURE_HTML });
  const volatile = runWorker('hash', {
    LOAD_FILE: file,
    LOAD_HTML: FIXTURE_HTML.replace('data-phx-id="a"', 'data-phx-id="zzz"').replace('vsn=abc123', 'vsn=other'),
  });
  const changed = runWorker('hash', { LOAD_FILE: file, LOAD_HTML: FIXTURE_HTML.replace('>Users<', '>People<') });
  assert.equal(a.isPromise, true);
  assert.match(a.hash, /^[0-9a-f]{64}$/);
  assert.equal(a.hash, again.hash);
  assert.equal(a.hash, volatile.hash);
  assert.notEqual(a.hash, changed.hash);
});

test('canonicalize.test.ts keeps all 17 cases and passes under the pinned transform', () => {
  const source = readFileSync(join(PW_DIR, 'lib', 'eval', 'canonicalize.test.ts'), 'utf8');
  assert.equal((source.match(/^test\('/gm) || []).length, 17);
  const runner = String.raw`
    const path = require('node:path');
    const PW = process.env.LOAD_PW_DIR;
    process.chdir(PW);
    require(path.join(PW, 'node_modules/playwright/lib/transform/transform.js'))
      .requireOrImport(path.join(PW, 'lib/eval/canonicalize.test.ts'))
      .catch((e) => { console.error(e); process.exit(1); });
  `;
  const res = spawnSync(process.execPath, ['-e', runner], {
    cwd: tmpdir(),
    encoding: 'utf8',
    env: { PATH: process.env.PATH, HOME: process.env.HOME, LOAD_PW_DIR: PW_DIR },
    timeout: 60_000,
  });
  assert.equal(res.status, 0, res.stdout + res.stderr);
  assert.match(res.stdout, /canonicalize\.test\.ts: 17 passed, 0 failed/);
});

test('written bundle manifest carries a concrete render_sha256 matching the canonical hash', (t) => {
  // bundle.ts resolves its output root relative to its own location, so a copy in a
  // type:module temp tree writes under the temp dir and leaves the project eval/ untouched.
  const dir = mkdtempSync(join(tmpdir(), 'sigra-bundle-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  mkdirSync(join(dir, 'lib', 'eval'), { recursive: true });
  for (const f of ['bundle.ts', 'canonicalize.ts']) {
    writeFileSync(join(dir, 'lib', 'eval', f), readFileSync(join(PW_DIR, 'lib', 'eval', f)));
  }
  symlinkSync(join(PW_DIR, 'node_modules'), join(dir, 'node_modules'));
  writeFileSync(join(dir, 'package.json'), '{"name":"bundle-copy","private":true,"type":"module"}');
  const sha = 'a'.repeat(40);
  const parsed = runWorker('bundle', {
    LOAD_FILE: join(dir, 'lib', 'eval', 'bundle.ts'), LOAD_SHA: sha, LOAD_HTML: FIXTURE_HTML,
  });
  assert.ok(parsed.result, JSON.stringify(parsed));
  const { result } = parsed;
  const manifest = JSON.parse(readFileSync(join(result.bundleDir, 'bundle.json'), 'utf8'));
  assert.equal(typeof manifest.render_sha256, 'string');
  assert.match(manifest.render_sha256, /^[0-9a-f]{64}$/);
  assert.equal(manifest.render_sha256, result.renderSha);
  assert.deepEqual(Object.keys(manifest), ['app_git_sha', 'surface', 'cell', 'render_sha256', 'findings_summary']);
  assert.equal(manifest.cell, 'light-desktop-populated');
  assert.deepEqual(manifest.findings_summary, { total: 1, gate: 0, warn: 1 });
  assert.ok(realpathSync(result.bundleDir).startsWith(realpathSync(dir)), 'bundle written outside the temp tree');
  assert.ok(existsSync(join(result.bundleDir, 'dom.html')));
});

test('spec writeBundleLocal and captureSurface await the asynchronous hash', () => {
  const spec = readFileSync(join(PW_DIR, 'tests', 'admin-eval.spec.ts'), 'utf8');
  assert.match(spec, /async function writeBundleLocal\(opts: WriteBundleOpts\): Promise<string>/);
  assert.match(spec, /const renderSha = await renderSha256\(opts\.outerHTML\);/);
  assert.match(spec, /await writeBundleLocal\(\{/);
  const bundle = readFileSync(join(PW_DIR, 'lib', 'eval', 'bundle.ts'), 'utf8');
  assert.match(bundle, /export async function writeBundle\(opts: WriteBundleOptions\): Promise<WriteBundleResult>/);
  assert.match(bundle, /const renderSha = await renderSha256\(opts\.outerHTML\);/);
});

function collect(stage) {
  const result = runWorker('collect', stage ? { SIGRA_REGISTRATION_CONTROL_STAGE: stage } : {});
  assert.deepEqual(result.errors, [], 'collection reported load errors');
  assert.ok(result.titles.length > 0, 'empty inventory');
  return result.titles;
}

test('first-stage collection registers exactly the five first controls and the original board title', () => {
  const titles = collect('first');
  for (const title of FIRST_TITLES) assert.equal(titles.filter((x) => x === title).length, 1, title);
  for (const title of SECOND_TITLES) assert.ok(!titles.includes(title), `unexpected second-stage ${title}`);
  assert.equal(titles.filter((x) => x === ORIGINAL_BOARD_TITLE).length, 1);
});

test('second-stage collection registers exactly the two second controls and the original board title', () => {
  const titles = collect('second');
  for (const title of SECOND_TITLES) assert.equal(titles.filter((x) => x === title).length, 1, title);
  for (const title of FIRST_TITLES) assert.ok(!titles.includes(title), `unexpected first-stage ${title}`);
  assert.equal(titles.filter((x) => x === ORIGINAL_BOARD_TITLE).length, 1);
});

test('unstaged collection registers no controls but keeps the original board title', () => {
  const titles = collect(undefined);
  for (const title of [...FIRST_TITLES, ...SECOND_TITLES]) assert.ok(!titles.includes(title), title);
  assert.equal(titles.filter((x) => x === ORIGINAL_BOARD_TITLE).length, 1);
});

function recoverySummary(stage) {
  return runWorker('recovery-summary', { LOAD_CONFIG: 'playwright.registration-recovery.config.ts', SIGRA_REGISTRATION_CONTROL_STAGE: stage });
}
const EVAL_PROJECTS = ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'];

test('recovery config collects the exact first-stage rows per project: 5 + 5 + 6 = 16', () => {
  const summary = recoverySummary('first');
  assert.deepEqual(summary.errors, []);
  assert.deepEqual(summary.projectNames, EVAL_PROJECTS);
  assert.deepEqual(summary.projects['admin-eval'].selected, FIRST_TITLES);
  assert.deepEqual(summary.projects['admin-eval-mobile'].selected, FIRST_TITLES);
  assert.deepEqual(summary.projects['admin-eval-dark'].selected, [...FIRST_TITLES, ORIGINAL_BOARD_TITLE]);
});

test('recovery config collects exactly the two second-stage rows in each project', () => {
  const summary = recoverySummary('second');
  assert.deepEqual(summary.errors, []);
  for (const name of EVAL_PROJECTS) assert.deepEqual(summary.projects[name].selected, SECOND_TITLES, name);
});

test('recovery config inherits production device, theme, use, worker, retry, timeout and reporter settings', () => {
  const production = runWorker('recovery-summary', { LOAD_CONFIG: 'playwright.config.ts' });
  const recovery = recoverySummary('first');
  assert.equal(recovery.workers, production.workers);
  assert.equal(recovery.fullyParallel, production.fullyParallel);
  assert.deepEqual(recovery.reporter, production.reporter);
  for (const name of EVAL_PROJECTS) {
    for (const key of ['use', 'retries', 'timeout', 'testMatch', 'testDir', 'outputDir', 'expect', 'workers', 'fullyParallel']) {
      assert.deepEqual(recovery.projects[name][key], production.projects[name][key], `${name}.${key}`);
    }
  }
  assert.equal(recovery.projects['admin-eval-dark'].use.colorScheme, 'dark');
  assert.equal(recovery.projects['admin-eval-mobile'].use.isMobile, true);
});

test('recovery config fails closed without an explicit control stage', () => {
  const res = spawnSync(process.execPath, ['-e', WORKER], {
    cwd: tmpdir(), encoding: 'utf8', timeout: 60_000,
    env: { PATH: process.env.PATH, HOME: process.env.HOME, LOAD_PW_DIR: PW_DIR, LOAD_MODE: 'recovery-summary', LOAD_CONFIG: 'playwright.registration-recovery.config.ts' },
  });
  assert.notEqual(res.status, 0);
  assert.match(res.stdout + res.stderr, /requires SIGRA_REGISTRATION_CONTROL_STAGE=first\|second/);
});
