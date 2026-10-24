import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const SCRIPT = path.join(ROOT, 'scripts/ci/measure-playwright-drift.mjs');
const CI = await readFile(path.join(ROOT, '.github/workflows/ci.yml'), 'utf8');
const MEASURE_WORKFLOW = await readFile(path.join(ROOT, '.github/workflows/phase-244-playwright-measure.yml'), 'utf8');
const SOURCE_SHA = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: ROOT, encoding: 'utf8' }).stdout.trim();

function command(args) {
  return spawnSync(process.execPath, [SCRIPT, ...args], { cwd: ROOT, encoding: 'utf8' });
}

function trackedInventory() {
  const result = command(['inventory', '--source-sha', SOURCE_SHA]);
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

function validManifest(inventory) {
  return {
    schema_version: 1,
    workflow_name: 'Phase 244 Playwright measurement',
    event: 'workflow_dispatch',
    head_branch: 'phase-244/measure-test',
    source_sha: SOURCE_SHA,
    run_id: '1234567890',
    scope: 'full',
    inventory: inventory.paths,
    rendered_paths: { render_a: inventory.paths, render_b: inventory.paths },
    package_versions: { render_a: '1.59.1', render_b: '1.59.1' },
    chromium_revisions: { render_a: '1217', render_b: '1217' },
    comparator: { name: 'ImageMagick compare -metric AE -fuzz 0%', version: 'ImageMagick 6.9.12' },
    results: inventory.paths.map((snapshot) => ({
      path: snapshot,
      width: 1280,
      height: 720,
      changed_pixels: 0,
      render_a: `render-a/${snapshot}`,
      render_b: `render-b/${snapshot}`,
      diff: `diffs/${snapshot.replace(/\.png$/, '.diff.png')}`,
    })),
    diagnostics: [],
    verdict: 'zero-drift',
  };
}

async function verifyWith(manifest, flags = ['--inventory-only']) {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-manifest-'));
  const file = path.join(directory, 'manifest.json');
  try {
    await writeFile(file, JSON.stringify(manifest));
    return command(['verify', '--manifest', file, '--source-sha', SOURCE_SHA, ...flags]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

function extractFinalMainGuard() {
  const step = CI.match(/      - name: Require release tag ref for manual release evidence([\s\S]*?)(?=      - name:)/)?.[1];
  assert.ok(step, 'release-ref guard step must exist');
  const script = step.match(/        run: \|\n((?:          .*\n)+)/)?.[1];
  assert.ok(script, 'release-ref guard must have an executable run block');
  return script.split('\n').map((line) => line.replace(/^ {10}/, '')).join('\n');
}

function runFinalMainGuard({ event = 'workflow_dispatch', enabled = 'true', ref = 'refs/heads/main', recapture = '', failProbe = 'false', rotProbe = 'false' } = {}) {
  return spawnSync('bash', ['-euo', 'pipefail', '-c', extractFinalMainGuard()], {
    cwd: ROOT,
    encoding: 'utf8',
    env: {
      ...process.env,
      EVENT_NAME: event,
      PHASE_244_FINAL_MAIN: enabled,
      REF: ref,
      GITHUB_REF: ref,
      RECAPTURE_BRANCH: recapture,
      FORCE_FAIL_PROBE: failProbe,
      FORCE_ROT_PROBE: rotProbe,
    },
  });
}

test('inventory is derived from the source commit and contains the complete tracked PNG set', () => {
  const inventory = trackedInventory();
  assert.equal(inventory.source_sha, SOURCE_SHA);
  assert.equal(inventory.paths.length, 115);
  assert.ok(inventory.paths.every((entry) => /^test\/example\/priv\/playwright\/tests\/[^/]+-snapshots\/[^/]+\.png$/.test(entry)));
  assert.deepEqual(inventory.paths, [...inventory.paths].sort());
});

test('a complete same-source Ubuntu receipt verifies', async () => {
  const inventory = trackedInventory();
  const result = await verifyWith(validManifest(inventory));
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /"valid":true/);
});

test('an incomplete capture path set fails closed', async () => {
  const inventory = trackedInventory();
  const manifest = validManifest(inventory);
  manifest.inventory.pop();
  manifest.rendered_paths.render_a.pop();
  manifest.results.pop();
  const result = await verifyWith(manifest);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /result\(s\)|path set differs/);
});

test('an extra or traversal path cannot enter the inventory', async () => {
  const inventory = trackedInventory();
  const manifest = validManifest(inventory);
  manifest.inventory[0] = '../outside.png';
  manifest.rendered_paths.render_a[0] = '../outside.png';
  manifest.rendered_paths.render_b[0] = '../outside.png';
  manifest.results[0] = { path: '../outside.png', width: 1, height: 1, changed_pixels: 0, render_a: 'a', render_b: 'b', diff: 'c' };
  const result = await verifyWith(manifest);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unsafe inventory path/);
});

test('any changed pixel prevents a zero-drift verdict', async () => {
  const inventory = trackedInventory();
  const manifest = validManifest(inventory);
  manifest.results[0].changed_pixels = 1;
  const result = await verifyWith(manifest);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /not exact zero drift/);
});

test('the final-main route admits only the exact safe dispatch inputs', () => {
  assert.equal(runFinalMainGuard().status, 0);
  assert.notEqual(runFinalMainGuard({ ref: 'refs/heads/phase-244/measure' }).status, 0);
  assert.notEqual(runFinalMainGuard({ ref: 'refs/tags/v1.0.0' }).status, 0);
  assert.notEqual(runFinalMainGuard({ enabled: 'false' }).status, 0);
  assert.notEqual(runFinalMainGuard({ recapture: 'candidate-branch' }).status, 0);
  assert.notEqual(runFinalMainGuard({ failProbe: 'true' }).status, 0);
  assert.notEqual(runFinalMainGuard({ rotProbe: 'true' }).status, 0);
  assert.equal(runFinalMainGuard({ enabled: 'false', recapture: 'candidate-branch' }).status, 0);
});

test('measurement workflow is read-only and gated to explicit phase-244 branch dispatches', () => {
  assert.match(MEASURE_WORKFLOW, /contents:\s*read/);
  assert.match(MEASURE_WORKFLOW, /inputs\.phase_244_measure == true/);
  assert.match(MEASURE_WORKFLOW, /github\.ref_type == 'branch'/);
  assert.match(MEASURE_WORKFLOW, /startsWith\(github\.ref, 'refs\/heads\/phase-244\/'\)/);
  assert.doesNotMatch(MEASURE_WORKFLOW, /contents:\s*write/);
});
