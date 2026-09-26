import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
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

test('inventory-only verification accepts complete captures while preserving measured drift', async () => {
  const inventory = trackedInventory();
  const manifest = validManifest(inventory);
  manifest.results[0].changed_pixels = 11;
  manifest.verdict = 'drift';
  const inventoryResult = await verifyWith(manifest, ['--inventory-only']);
  assert.equal(inventoryResult.status, 0, inventoryResult.stderr);
  assert.match(inventoryResult.stdout, /"paths":115/);
  const exactResult = await verifyWith(manifest, ['--expect-count', '115']);
  assert.notEqual(exactResult.status, 0);
  assert.match(exactResult.stderr, /verdict is drift/);
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
  const result = await verifyWith(manifest, ['--expect-count', String(inventory.paths.length)]);
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

async function tinyPng(directory, name, color) {
  const file = path.join(directory, name);
  const generated = spawnSync('convert', ['-size', '2x2', `xc:${color}`, file], { encoding: 'utf8' });
  assert.equal(generated.status, 0, generated.stderr);
  return file;
}

test('exact comparator accepts identical decoded pixels and reports a one-pixel difference', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-pixels-'));
  try {
    const whiteA = await tinyPng(directory, 'white-a.png', 'white');
    const whiteB = await tinyPng(directory, 'white-b.png', 'white');
    const changed = path.join(directory, 'changed.png');
    assert.equal(spawnSync('convert', [whiteA, '-fill', 'black', '-draw', 'point 0,0', changed], { encoding: 'utf8' }).status, 0);
    const equal = command(['compare', whiteA, whiteB, path.join(directory, 'equal.diff.png')]);
    assert.equal(equal.status, 0, equal.stderr);
    assert.match(equal.stdout, /"changed_pixels":0/);
    const drift = command(['compare', whiteA, changed, path.join(directory, 'drift.diff.png')]);
    assert.equal(drift.status, 1);
    assert.match(drift.stdout, /"changed_pixels":(?:[1-9]\d*)/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('dimension mismatch is rejected before pixel comparison', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-dimensions-'));
  try {
    const one = await tinyPng(directory, 'one.png', 'white');
    const two = path.join(directory, 'two.png');
    assert.equal(spawnSync('convert', ['-size', '3x2', 'xc:white', two], { encoding: 'utf8' }).status, 0);
    const result = command(['compare', one, two, path.join(directory, 'diff.png')]);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /dimensions differ/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('malformed AE output and an unavailable comparator fail closed', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-comparator-'));
  try {
    const image = await tinyPng(directory, 'image.png', 'white');
    const malformed = path.join(directory, 'malformed-compare');
    await writeFile(malformed, '#!/bin/sh\nprintf "not-a-metric\\n" >&2\nexit 1\n', { mode: 0o755 });
    const malformedResult = spawnSync(process.execPath, [SCRIPT, 'compare', image, image, path.join(directory, 'bad.diff.png')], {
      cwd: ROOT, encoding: 'utf8', env: { ...process.env, PHASE244_COMPARE_BIN: malformed },
    });
    assert.notEqual(malformedResult.status, 0);
    assert.match(malformedResult.stderr, /malformed/);
    const unavailable = spawnSync(process.execPath, [SCRIPT, 'compare', image, image, path.join(directory, 'missing.diff.png')], {
      cwd: ROOT, encoding: 'utf8', env: { ...process.env, PHASE244_COMPARE_BIN: path.join(directory, 'absent') },
    });
    assert.notEqual(unavailable.status, 0);
    assert.match(unavailable.stderr, /ENOENT|not found/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('manifest records missing and extra renders against the source inventory', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-inventory-'));
  const inventory = trackedInventory();
  const renderA = path.join(directory, 'a');
  const renderB = path.join(directory, 'b');
  const artifacts = path.join(directory, 'artifacts');
  const versionFile = path.join(directory, 'comparator-version.txt');
  try {
    const png = await tinyPng(directory, 'pixel.png', 'white');
    for (const root of [renderA, renderB]) {
      for (const imagePath of inventory.paths) {
        const destination = path.join(root, imagePath);
        await mkdir(path.dirname(destination), { recursive: true });
        await writeFile(destination, await readFile(png));
      }
    }
    await rm(path.join(renderA, inventory.paths[0]));
    const extraRelative = 'test/example/priv/playwright/tests/admin-checkpoints-snapshots/extra-admin-checkpoints-chromium.png';
    const extra = path.join(renderB, extraRelative);
    await mkdir(path.dirname(extra), { recursive: true });
    await writeFile(extra, await readFile(png));
    await writeFile(versionFile, 'ImageMagick 6.9.12-98\nimagemagick=8:6.9.12.98+dfsg1-5.2build2\n');
    await writeFile(path.join(directory, 'inventory.json'), JSON.stringify(inventory));
    const compareMarker = path.join(directory, 'compare-was-called');
    const failIfCalled = path.join(directory, 'fail-if-called');
    await writeFile(failIfCalled, `#!/bin/sh\nprintf called > '${compareMarker}'\nexit 2\n`, { mode: 0o755 });
    const output = path.join(directory, 'manifest.json');
    const result = spawnSync(process.execPath, [SCRIPT, 'build-manifest', '--source-sha', SOURCE_SHA, '--run-id', '1',
      '--branch', 'phase-244/test', '--scope', 'full', '--inventory-file', path.join(directory, 'inventory.json'),
      '--render-a', renderA, '--render-b', renderB, '--artifact-dir', artifacts, '--package-a', '1.59.1', '--package-b', '1.59.1',
      '--chromium-revision-a', '1', '--chromium-revision-b', '1', '--comparator-version-file', versionFile,
      '--expected-imagemagick-package', '8:6.9.12.98+dfsg1-5.2build2', '--output', output], {
      cwd: ROOT, encoding: 'utf8', env: { ...process.env, PHASE244_COMPARE_BIN: failIfCalled },
    });
    assert.notEqual(result.status, 0, result.stdout);
    const manifest = JSON.parse(await readFile(output, 'utf8'));
    assert.equal(manifest.inventory_count, 115);
    assert.match(manifest.inventory_sha256, /^[0-9a-f]{64}$/);
    assert.ok(manifest.missing_paths.render_a.includes(inventory.paths[0]));
    assert.ok(manifest.extra_paths.render_b.includes(extraRelative));
    assert.notEqual(manifest.verdict, 'zero-drift');
    assert.notEqual(spawnSync('test', ['-f', compareMarker]).status, 0, 'inventory mismatch must stop before pixel comparison');
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
