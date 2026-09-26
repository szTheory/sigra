import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const SCRIPT = path.join(ROOT, 'scripts/ci/measure-playwright-drift.mjs');
const CI = await readFile(path.join(ROOT, '.github/workflows/ci.yml'), 'utf8');
const MEASURE_WORKFLOW = await readFile(path.join(ROOT, '.github/workflows/phase-244-playwright-measure.yml'), 'utf8');
const MEASURE_RUNNER = await readFile(path.join(ROOT, 'scripts/ci/run-playwright-drift.sh'), 'utf8');
const SOURCE_SHA = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: ROOT, encoding: 'utf8' }).stdout.trim();

function command(args) {
  return spawnSync(process.execPath, [SCRIPT, ...args], { cwd: ROOT, encoding: 'utf8' });
}

async function writeJson(directory, name, value) {
  const file = path.join(directory, name);
  await writeFile(file, JSON.stringify(value));
  return file;
}

async function provenanceFixture(directory) {
  const manifest = {
    schema_version: 3,
    workflow_name: 'Phase 244 Playwright measurement',
    event: 'workflow_dispatch',
    head_branch: 'phase-244/measure-test',
    source_sha: SOURCE_SHA,
    run_id: '1234567890',
    run_url: `https://github.com/szTheory/sigra/actions/runs/1234567890`,
    runner: { image: 'ubuntu-24.04', os: 'Linux' },
    artifact_identifier: 'phase-244-playwright-measurement-1234567890',
    scope: 'full',
    inventory: [],
    inventory_count: 0,
    inventory_sha256: '0'.repeat(64),
    rendered_paths: { render_a: [], render_b: [] },
    missing_paths: { render_a: [], render_b: [] },
    extra_paths: { render_a: [], render_b: [] },
    package_versions: { render_a: '1.59.1', render_b: '1.62.1' },
    package_trios: {
      render_a: { '@playwright/test': '1.59.1', playwright: '1.59.1', 'playwright-core': '1.59.1' },
      render_b: { '@playwright/test': '1.62.1', playwright: '1.62.1', 'playwright-core': '1.62.1' },
    },
    package_trio_statuses: { render_a: 'verified', render_b: 'verified' },
    chromium_revisions: { render_a: '1217', render_b: '1234' },
    chromium_versions: { render_a: '147.0.7727.15', render_b: '151.0.7922.34' },
    browser_manifests: {
      render_a: { url: 'https://example.invalid/v1.59.1/packages/playwright-core/browsers.json', sha256: '1'.repeat(64) },
      render_b: { url: 'https://example.invalid/v1.62.1/packages/playwright-core/browsers.json', sha256: '2'.repeat(64) },
    },
    browser_manifest_statuses: { render_a: 'verified', render_b: 'verified' },
    comparator: { name: 'ImageMagick compare -metric AE -fuzz 0%', package: 'imagemagick=test', version: 'ImageMagick 6.9.12' },
    results: [],
    total_changed_pixels: 0,
    diagnostics: [],
    verdict: 'zero-drift',
  };
  const manifestBytes = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`);
  const manifestFile = path.join(directory, 'measurement.json');
  await writeFile(manifestFile, manifestBytes);
  const sourceDir = path.join(directory, 'artifact-source');
  await mkdir(sourceDir);
  await writeFile(path.join(sourceDir, 'measurement.json'), manifestBytes);
  const archive = path.join(directory, 'measurement.zip');
  const zipped = spawnSync('zip', ['-q', '-r', archive, 'measurement.json'], { cwd: sourceDir, encoding: 'utf8' });
  assert.equal(zipped.status, 0, zipped.stderr);
  const archiveBytes = await readFile(archive);
  const run = {
    id: 1234567890,
    name: 'Phase 244 Playwright measurement',
    path: '.github/workflows/phase-244-playwright-measure.yml',
    event: 'workflow_dispatch',
    head_branch: 'phase-244/measure-test',
    head_sha: SOURCE_SHA,
    status: 'completed',
    conclusion: 'success',
  };
  const artifact = {
    total_count: 1,
    artifacts: [{
      id: 9876,
      name: 'phase-244-playwright-measurement-1234567890',
      expired: false,
      digest: `sha256:${createHash('sha256').update(archiveBytes).digest('hex')}`,
      workflow_run: { id: 1234567890 },
    }],
  };
  return {
    manifest,
    manifestBytes,
    run,
    artifact,
    files: {
      manifest: manifestFile,
      run: await writeJson(directory, 'run.json', run),
      artifact: await writeJson(directory, 'artifact.json', artifact),
      archive,
    },
  };
}

async function verifyProvenance(fixture, overrides = {}) {
  const args = ['verify-provenance', '--manifest', fixture.files.manifest, '--run-json', fixture.files.run,
    '--artifact-json', fixture.files.artifact, '--artifact-zip', fixture.files.archive, '--source-sha', SOURCE_SHA];
  return command(overrides.args ?? args);
}

function authorizationFixture() {
  const sha = SOURCE_SHA;
  const baseSha = 'b'.repeat(40);
  const contexts = [
    { name: 'ci-gate', app: { id: 333 }, head_sha: sha, status: 'completed', conclusion: 'success' },
    { name: 'Library tests', app: { id: 444 }, head_sha: sha, status: 'completed', conclusion: 'success' },
  ];
  return {
    measurement: { source_sha: sha, run_id: '1234567890', verdict: 'zero-drift' },
    provenance: { run_id: 1234567890, head_sha: sha, manifest_sha256: 'a'.repeat(64), artifact_id: 9876 },
    pr: { number: 213, state: 'open', head: { sha, ref: 'phase-244/measurement' }, base: { ref: 'main', sha: baseSha }, mergeable: true, mergeable_state: 'clean' },
    main: { sha: baseSha, name: 'main' },
    head_ref: { object: { sha } },
    rules: [{ type: 'required_status_checks', parameters: { required_status_checks: [{ context: 'ci-gate', integration_id: 333 }] } },
      { type: 'workflows', parameters: { workflows: [{ path: '.github/workflows/ci.yml', ref: 'main', repository_id: 1, sha: 'c'.repeat(40) }] } }],
    protection: { contexts: ['Library tests'], checks: [{ context: 'Library tests', app_id: 444 }] },
    check_runs: { complete: true, total_count: contexts.length, pages: [{ check_runs: contexts }] },
    statuses: { complete: true, total_count: 0, pages: [{ statuses: [] }] },
    workflow_runs: { complete: true, total_count: 1, pages: [{ workflow_runs: [
      { id: 8801, path: '.github/workflows/ci.yml', head_sha: sha, status: 'completed', conclusion: 'success' },
    ] }] },
    repository_id: 1,
  };
}

async function evaluateAuthorization(record, directory) {
  const input = await writeJson(directory, 'authorization.json', record);
  return command(['evaluate-eligibility', '--authorization-json', input]);
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
    package_versions: { render_a: '1.59.1', render_b: '1.62.1' },
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

test('recorded outcome verification accepts drift but keeps it ineligible for merge', async () => {
  const inventory = trackedInventory();
  const manifest = validManifest(inventory);
  manifest.results[0].changed_pixels = 1;
  manifest.results[0].result = 'drift';
  manifest.verdict = 'drift';
  const result = await verifyWith({ measurement: manifest, decision_eligibility: { verdict: 'drift', merge_eligible: false } }, ['--validate-recorded-outcome']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /"verdict":"drift"/);
  assert.match(result.stdout, /"merge_eligible":false/);
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
  assert.match(MEASURE_WORKFLOW, /default:\s*full/);
  assert.match(MEASURE_WORKFLOW, /RUNNER_IMAGE:\s*ubuntu-24\.04/);
});

test('full measurement installs both Playwright OS dependency sets before either capture', () => {
  const prepareDeps = MEASURE_RUNNER.indexOf('prepare_system_dependencies 1.59.1');
  const prepareCandidateDeps = MEASURE_RUNNER.indexOf('prepare_system_dependencies 1.62.1');
  const captureA = MEASURE_RUNNER.indexOf('run_capture render-a');
  const captureB = MEASURE_RUNNER.indexOf('run_capture render-b');
  assert.ok(prepareDeps >= 0 && prepareCandidateDeps > prepareDeps);
  assert.ok(captureA > prepareCandidateDeps && captureB > captureA);
  assert.match(MEASURE_RUNNER, /npx playwright install-deps chromium webkit/);
  assert.match(MEASURE_RUNNER, /union of both package versions' browser OS dependencies/);
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

test('one differing pixel leaves a nonzero workflow outcome and a verifiable drift manifest', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-pixel-manifest-'));
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
    const changed = path.join(renderB, inventory.paths[0]);
    assert.equal(spawnSync('convert', [changed, '-fill', 'black', '-draw', 'point 0,0', changed], { encoding: 'utf8' }).status, 0);
    await writeFile(versionFile, 'ImageMagick 6.9.12\nimagemagick=8:6.9.12.98+dfsg1-5.2build2\n');
    const inventoryFile = path.join(directory, 'inventory.json');
    await writeFile(inventoryFile, JSON.stringify(inventory));
    const manifestFile = path.join(directory, 'measurement.json');
    const trioA = JSON.stringify({ '@playwright/test': '1.59.1', playwright: '1.59.1', 'playwright-core': '1.59.1' });
    const trioB = JSON.stringify({ '@playwright/test': '1.62.1', playwright: '1.62.1', 'playwright-core': '1.62.1' });
    const result = spawnSync(process.execPath, [SCRIPT, 'build-manifest', '--source-sha', SOURCE_SHA, '--run-id', '9876543210',
      '--branch', 'phase-244/measurement', '--scope', 'full', '--inventory-file', inventoryFile,
      '--render-a', renderA, '--render-b', renderB, '--artifact-dir', artifacts,
      '--package-a', '1.59.1', '--package-b', '1.62.1', '--package-trio-a', trioA, '--package-trio-b', trioB,
      '--package-trio-status-a', 'verified', '--package-trio-status-b', 'verified',
      '--chromium-revision-a', '1217', '--chromium-revision-b', '1234', '--chromium-version-a', '147.0.7727.15', '--chromium-version-b', '151.0.7922.34',
      '--browser-manifest-url-a', 'https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json',
      '--browser-manifest-url-b', 'https://raw.githubusercontent.com/microsoft/playwright/v1.62.1/packages/playwright-core/browsers.json',
      '--browser-manifest-sha-a', 'a'.repeat(64), '--browser-manifest-sha-b', 'b'.repeat(64),
      '--browser-manifest-status-a', 'verified', '--browser-manifest-status-b', 'verified',
      '--runner-image', 'ubuntu-24.04', '--artifact-identifier', 'phase-244-run-9876543210',
      '--run-url', 'https://github.com/szTheory/sigra/actions/runs/9876543210',
      '--comparator-version-file', versionFile, '--expected-imagemagick-package', '8:6.9.12.98+dfsg1-5.2build2', '--output', manifestFile], {
      cwd: ROOT, encoding: 'utf8',
    });
    assert.notEqual(result.status, 0, 'pixel drift must fail the measurement job');
    const manifest = JSON.parse(await readFile(manifestFile, 'utf8'));
    assert.equal(manifest.verdict, 'drift');
    assert.ok(manifest.results.some((entry) => entry.changed_pixels > 0));
    const verified = command(['verify', '--manifest', manifestFile, '--source-sha', SOURCE_SHA, '--validate-recorded-outcome']);
    assert.equal(verified.status, 0, verified.stderr);
    assert.match(verified.stdout, /"merge_eligible":false/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('structured run and artifact APIs bind the exact manifest bytes and archive digest', async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-provenance-'));
  try {
    const fixture = await provenanceFixture(directory);
    const accepted = await verifyProvenance(fixture);
    assert.equal(accepted.status, 0, accepted.stderr);
    assert.match(accepted.stdout, /"manifest_sha256":"[a-f0-9]{64}"/);
    assert.match(accepted.stdout, /"artifact_id":9876/);

    const rejected = [
      ['run ID', (value) => { value.id += 1; }],
      ['run conclusion', (value) => { value.conclusion = 'failure'; }],
      ['workflow path', (value) => { value.path = '.github/workflows/other.yml'; }],
      ['event', (value) => { value.event = 'push'; }],
      ['branch', (value) => { value.head_branch = 'main'; }],
      ['source SHA', (value) => { value.head_sha = 'f'.repeat(40); }],
      ['run status', (value) => { value.status = 'in_progress'; }],
    ];
    for (const [label, mutate] of rejected) {
      await t.test(`rejects mismatched ${label}`, async () => {
        const fixtureDir = path.join(directory, label.replaceAll(' ', '-'));
        await mkdir(fixtureDir);
        const value = await provenanceFixture(fixtureDir);
        const run = structuredClone(value.run);
        mutate(run);
        const runFile = await writeJson(fixtureDir, 'mutated-run.json', run);
        const result = await verifyProvenance(value, { args: [
          'verify-provenance', '--manifest', value.files.manifest, '--run-json', runFile,
          '--artifact-json', value.files.artifact, '--artifact-zip', value.files.archive, '--source-sha', SOURCE_SHA,
        ] });
        assert.notEqual(result.status, 0, result.stdout);
      });
    }

    const badArtifact = structuredClone(fixture.artifact);
    badArtifact.artifacts[0].digest = `sha256:${'f'.repeat(64)}`;
    const badArtifactFile = await writeJson(directory, 'bad-artifact.json', badArtifact);
    const digestMismatch = await verifyProvenance(fixture, { args: [
      'verify-provenance', '--manifest', fixture.files.manifest, '--run-json', fixture.files.run,
      '--artifact-json', badArtifactFile, '--artifact-zip', fixture.files.archive, '--source-sha', SOURCE_SHA,
    ] });
    assert.notEqual(digestMismatch.status, 0, digestMismatch.stdout);

    const alteredBytes = Buffer.from(await readFile(fixture.files.archive));
    alteredBytes[alteredBytes.length - 1] ^= 0xff;
    await writeFile(fixture.files.archive, alteredBytes);
    const archiveTamper = await verifyProvenance(fixture);
    assert.notEqual(archiveTamper.status, 0, archiveTamper.stdout);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('merge eligibility requires a current PR, base, complete policies, and exact successful checks', async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'phase-244-eligibility-'));
  try {
    const valid = authorizationFixture();
    const success = await evaluateAuthorization(valid, directory);
    assert.equal(success.status, 0, success.stderr);
    assert.match(success.stdout, /"merge_eligible":true/);

    const rejects = [
      ['measured drift', (r) => { r.measurement.verdict = 'drift'; }],
      ['closed PR', (r) => { r.pr.state = 'closed'; }],
      ['missing live head ref', (r) => { r.head_ref = null; }],
      ['measured source and PR head mismatch', (r) => { r.pr.head.sha = 'd'.repeat(40); }],
      ['stale base SHA', (r) => { r.main.sha = 'e'.repeat(40); }],
      ['nonmergeable PR', (r) => { r.pr.mergeable = false; }],
      ['nonclean merge state', (r) => { r.pr.mergeable_state = 'blocked'; }],
      ['missing required result', (r) => { r.check_runs.pages[0].check_runs.pop(); r.check_runs.total_count -= 1; }],
      ['duplicate required result', (r) => { r.check_runs.pages[0].check_runs.push(structuredClone(r.check_runs.pages[0].check_runs[0])); r.check_runs.total_count += 1; }],
      ['failed required result', (r) => { r.check_runs.pages[0].check_runs[0].conclusion = 'failure'; }],
      ['skipped required result', (r) => { r.check_runs.pages[0].check_runs[0].conclusion = 'skipped'; }],
      ['wrong required result SHA', (r) => { r.check_runs.pages[0].check_runs[0].head_sha = 'f'.repeat(40); }],
      ['incomplete check-run pagination', (r) => { r.check_runs.complete = false; }],
      ['incomplete status pagination', (r) => { r.statuses.complete = false; }],
      ['missing required workflow', (r) => { r.workflow_runs.pages[0].workflow_runs = []; r.workflow_runs.total_count = 0; }],
      ['empty policy', (r) => { r.rules = []; r.protection = { contexts: [], checks: [] }; }],
      ['unknown policy response', (r) => { r.rules = { message: 'not an array' }; }],
      ['missing classic protection policy', (r) => { r.protection = null; }],
    ];
    for (const [label, mutate] of rejects) {
      await t.test(`fails closed for ${label}`, async () => {
        const record = structuredClone(valid);
        mutate(record);
        const result = await evaluateAuthorization(record, directory);
        if (['empty policy', 'unknown policy response', 'missing classic protection policy'].includes(label)) {
          assert.notEqual(result.status, 0, result.stdout);
        } else {
          assert.equal(result.status, 0, result.stderr);
          assert.match(result.stdout, /"merge_eligible":false/);
        }
      });
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
