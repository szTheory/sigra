#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const SHA_RE = /^[0-9a-f]{40}$/;

function fail(message) {
  console.error(`measure-playwright-drift: FAIL: ${message}`);
  process.exitCode = 1;
}

function argValue(args, name) {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  return result;
}

function imageCommand(name) {
  const override = process.env[`PHASE244_${name.toUpperCase()}_BIN`];
  return override || name;
}

function assertSafeInventoryPath(value) {
  if (typeof value !== 'string' || value.length === 0 || value.includes('\\')) {
    throw new Error('inventory path must be a non-empty repository-relative POSIX path');
  }
  if (path.posix.isAbsolute(value) || value.split('/').some((part) => part === '..' || part === '.')) {
    throw new Error(`unsafe inventory path: ${value}`);
  }
  if (!/^test\/example\/priv\/playwright\/tests\/[^/]+-snapshots\/[^/]+\.png$/.test(value)) {
    throw new Error(`path is outside the committed Playwright snapshot inventory: ${value}`);
  }
  return value;
}

function gitInventory(sourceSha) {
  if (!SHA_RE.test(sourceSha ?? '')) throw new Error('source SHA must be 40 lowercase hexadecimal characters');
  const result = run('git', ['ls-tree', '-r', '--name-only', sourceSha, '--', 'test/example/priv/playwright/tests']);
  if (result.status !== 0) throw new Error(`git ls-tree failed: ${result.stderr.trim()}`);
  return result.stdout.split(/\r?\n/).filter((entry) => entry && /^test\/example\/priv\/playwright\/tests\/[^/]+-snapshots\/[^/]+\.png$/.test(entry)).map(assertSafeInventoryPath).sort();
}

function samePaths(expected, actual) {
  const left = [...expected].sort();
  const right = [...actual].map(assertSafeInventoryPath).sort();
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function requireRunIdentity(manifest, sourceSha) {
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    throw new Error('manifest must be a JSON object');
  }
  if (manifest.source_sha !== sourceSha) throw new Error('manifest source_sha does not match the requested source SHA');
  if (!SHA_RE.test(manifest.source_sha ?? '')) throw new Error('manifest source_sha is malformed');
  if (!/^\d+$/.test(String(manifest.run_id ?? ''))) throw new Error('manifest run_id is missing or malformed');
  if (typeof manifest.workflow_name !== 'string' || manifest.workflow_name !== 'Phase 244 Playwright measurement') {
    throw new Error('manifest workflow_name does not identify the Phase 244 measurement workflow');
  }
  if (manifest.event !== 'workflow_dispatch' || typeof manifest.head_branch !== 'string' || !manifest.head_branch.startsWith('phase-244/')) {
    throw new Error('manifest is not bound to an authorized phase-244 workflow_dispatch branch');
  }
  if (manifest.package_versions?.render_a !== '1.59.1' || manifest.package_versions?.render_b !== '1.59.1') {
    throw new Error('manifest package versions must both identify the locked 1.59.1 baseline');
  }
  if (!/^\d+$/.test(String(manifest.chromium_revisions?.render_a ?? '')) ||
      !/^\d+$/.test(String(manifest.chromium_revisions?.render_b ?? ''))) {
    throw new Error('manifest Chromium revisions are missing or malformed');
  }
  if (typeof manifest.comparator?.name !== 'string' || typeof manifest.comparator?.version !== 'string' ||
      !manifest.comparator.version.includes('ImageMagick')) {
    throw new Error('manifest comparator identity is missing or malformed');
  }
}

async function verifyManifest(args) {
  const file = argValue(args, '--manifest');
  const sourceSha = argValue(args, '--source-sha');
  if (!file || !sourceSha) throw new Error('verify requires --manifest and --source-sha');
  const manifest = JSON.parse(await readFile(file, 'utf8'));
  requireRunIdentity(manifest, sourceSha);
  const inventoryOnly = args.includes('--inventory-only');
  if (!inventoryOnly && manifest.verdict !== 'zero-drift') throw new Error(`manifest verdict is ${manifest.verdict ?? 'missing'}`);
  const expected = gitInventory(sourceSha);
  const expectCountArg = argValue(args, '--expect-count');
  const expectCount = expectCountArg === undefined && args.includes('--inventory-only')
    ? expected.length
    : Number(expectCountArg);
  if (!Number.isInteger(expectCount) || expectCount < 1) throw new Error('--expect-count must be a positive integer');
  if (!Array.isArray(manifest.results) || manifest.results.length !== expectCount) {
    throw new Error(`manifest must contain exactly ${expectCount} result(s)`);
  }
  if (!Array.isArray(manifest.inventory) || !samePaths(manifest.inventory, manifest.results.map((entry) => entry.path))) {
    throw new Error('manifest inventory and result paths do not match exactly');
  }
  if (manifest.schema_version === 2) {
    const inventoryHash = createHash('sha256').update(`${manifest.inventory.join('\n')}\n`).digest('hex');
    if (manifest.inventory_count !== manifest.inventory.length || manifest.inventory_sha256 !== inventoryHash) {
      throw new Error('manifest inventory count/hash does not match its path list');
    }
  }
  if (args.includes('--inventory-only') && !samePaths(expected, manifest.inventory)) {
    throw new Error(`manifest path set differs from the ${expected.length}-path inventory at ${sourceSha}`);
  }
  if (!manifest.inventory.every((entry) => expected.includes(assertSafeInventoryPath(entry)))) {
    throw new Error('manifest includes a path outside the tracked inventory at the requested source SHA');
  }
  for (const entry of manifest.results) {
    assertSafeInventoryPath(entry.path);
    const dimensionValid = manifest.schema_version === 2
      ? Number.isInteger(entry.width_a) && entry.width_a > 0 && Number.isInteger(entry.height_a) && entry.height_a > 0 &&
        Number.isInteger(entry.width_b) && entry.width_b > 0 && Number.isInteger(entry.height_b) && entry.height_b > 0
      : Number.isInteger(entry.width) && entry.width > 0 && Number.isInteger(entry.height) && entry.height > 0;
    if (!dimensionValid && entry.result !== 'missing' && entry.result !== 'inconclusive') {
      throw new Error(`invalid dimensions for ${entry.path}`);
    }
    if (manifest.verdict === 'zero-drift' && (!Number.isInteger(entry.changed_pixels) || entry.changed_pixels !== 0 || entry.result === 'dimension-mismatch')) {
      throw new Error(`comparison is not exact zero drift for ${entry.path}`);
    }
    if (!entry.render_a || !entry.render_b || !entry.diff) throw new Error(`render/diff artifact path missing for ${entry.path}`);
  }
  if (args.includes('--inventory-only') && (
    !samePaths(expected, manifest.rendered_paths?.render_a ?? []) ||
    !samePaths(expected, manifest.rendered_paths?.render_b ?? [])
  )) {
    throw new Error('one or both rendered path sets differ from the complete tracked inventory');
  }
  if (manifest.schema_version === 2 && manifest.verdict === 'zero-drift' && (
    manifest.total_changed_pixels !== 0 || manifest.missing_paths?.render_a?.length || manifest.missing_paths?.render_b?.length ||
    manifest.extra_paths?.render_a?.length || manifest.extra_paths?.render_b?.length
  )) {
    throw new Error('zero-drift verdict has changed pixels or inventory differences');
  }
  console.log(JSON.stringify({ valid: true, source_sha: sourceSha, run_id: manifest.run_id, paths: manifest.inventory.length }));
}

function strictAeOutput(stderr) {
  // ImageMagick 6 emits `AE (normalized AE)`, e.g. `1 (0.25)`; the
  // integer is the only decision metric and the optional ratio is syntax-checked.
  const match = stderr.match(/^\s*(\d+)(?:\s+\(((?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\))?\s*\r?\n?$/);
  if (!match) throw new Error(`ImageMagick AE output is unavailable or malformed: ${JSON.stringify(stderr.trim())}`);
  if (match[2] !== undefined && Number(match[2]) > 1) throw new Error('ImageMagick normalized AE metric is outside [0,1]');
  const count = Number(match[1]);
  if (!Number.isSafeInteger(count)) throw new Error('ImageMagick AE count is outside the safe integer range');
  return count;
}

function compare(args) {
  const [left, right, diff] = args;
  if (!left || !right || !diff || args.length !== 3) throw new Error('compare requires <render-a.png> <render-b.png> <diff.png>');
  const identify = imageCommand('identify');
  const dimensionsA = run(identify, ['-format', '%w %h', left]);
  const dimensionsB = run(identify, ['-format', '%w %h', right]);
  if (dimensionsA.status !== 0 || dimensionsB.status !== 0) {
    throw new Error(`ImageMagick identify failed (A=${dimensionsA.status}, B=${dimensionsB.status})`);
  }
  const parseDimensions = (value) => {
    const match = value.trim().match(/^(\d+)\s+(\d+)$/);
    if (!match) throw new Error(`ImageMagick returned malformed dimensions: ${JSON.stringify(value)}`);
    return { width: Number(match[1]), height: Number(match[2]) };
  };
  const sizeA = parseDimensions(dimensionsA.stdout);
  const sizeB = parseDimensions(dimensionsB.stdout);
  if (sizeA.width !== sizeB.width || sizeA.height !== sizeB.height) {
    throw new Error(`image dimensions differ: ${sizeA.width}x${sizeA.height} != ${sizeB.width}x${sizeB.height}`);
  }
  const result = run(imageCommand('compare'), ['-metric', 'AE', '-fuzz', '0%', left, right, diff]);
  if (result.status !== 0 && result.status !== 1) {
    throw new Error(`ImageMagick compare failed (exit ${result.status}): ${result.stderr.trim()}`);
  }
  if (result.stdout.trim()) throw new Error(`unexpected ImageMagick compare stdout: ${JSON.stringify(result.stdout)}`);
  const changedPixels = strictAeOutput(result.stderr);
  console.log(JSON.stringify({ changed_pixels: changedPixels, diff }));
  if (changedPixels !== 0) process.exitCode = 1;
}

async function buildManifest(args) {
  const sourceSha = argValue(args, '--source-sha');
  const runId = argValue(args, '--run-id');
  const branch = argValue(args, '--branch');
  const scope = argValue(args, '--scope');
  const inventoryFile = argValue(args, '--inventory-file');
  const renderA = argValue(args, '--render-a');
  const renderB = argValue(args, '--render-b');
  const artifactDir = argValue(args, '--artifact-dir');
  const revisionA = argValue(args, '--chromium-revision-a');
  const revisionB = argValue(args, '--chromium-revision-b');
  const packageA = argValue(args, '--package-a');
  const packageB = argValue(args, '--package-b');
  const comparatorVersionFile = argValue(args, '--comparator-version-file');
  const captureStatusA = argValue(args, '--capture-status-a') ?? '0';
  const captureStatusB = argValue(args, '--capture-status-b') ?? '0';
  const output = argValue(args, '--output');
  if (!sourceSha || !runId || !branch || !scope || !inventoryFile || !renderA || !renderB || !artifactDir || !output) {
    throw new Error('build-manifest is missing required arguments');
  }
  if (!SHA_RE.test(sourceSha) || !/^\d+$/.test(runId) || !branch.startsWith('phase-244/')) {
    throw new Error('build-manifest has invalid run identity');
  }
  if (!['tracer', 'full'].includes(scope)) throw new Error('scope must be tracer or full');
  const fullInventory = gitInventory(sourceSha);
  const suppliedInventory = JSON.parse(await readFile(inventoryFile, 'utf8'));
  if (suppliedInventory.source_sha !== sourceSha || !samePaths(fullInventory, suppliedInventory.paths ?? [])) {
    throw new Error('inventory input does not match git ls-tree at the requested source SHA');
  }
  const selected = scope === 'tracer'
    ? fullInventory.filter((entry) => entry.endsWith('-admin-checkpoints-chromium.png')).slice(0, 1)
    : fullInventory;
  if (selected.length === 0) throw new Error('the measured source SHA has no eligible tracked PNGs');

  const diagnostics = [];
  const missingPaths = new Set();
  for (const relativePath of selected) {
    const sourceA = path.join(renderA, relativePath);
    const sourceB = path.join(renderB, relativePath);
    const aStat = run('test', ['-f', sourceA]);
    const bStat = run('test', ['-f', sourceB]);
    if (aStat.status !== 0 || bStat.status !== 0) {
      diagnostics.push(`required screenshot was not rendered in both roots: ${relativePath}`);
      missingPaths.add(relativePath);
    }
  }
  let actualA = [];
  let actualB = [];
  if (scope === 'full') {
    actualA = await listPngs(renderA);
    actualB = await listPngs(renderB);
    if (!samePaths(fullInventory, actualA)) diagnostics.push('render-a path set differs from the tracked PNG inventory');
    if (!samePaths(fullInventory, actualB)) diagnostics.push('render-b path set differs from the tracked PNG inventory');
  } else {
    actualA = selected.filter((entry) => !missingPaths.has(entry));
    actualB = [...actualA];
  }

  await mkdir(path.join(artifactDir, 'render-a'), { recursive: true });
  await mkdir(path.join(artifactDir, 'render-b'), { recursive: true });
  await mkdir(path.join(artifactDir, 'diffs'), { recursive: true });
  const results = [];
  for (const relativePath of selected) {
    const renderAFile = path.posix.join('render-a', relativePath);
    const renderBFile = path.posix.join('render-b', relativePath);
    const diffFile = path.posix.join('diffs', relativePath.replace(/\.png$/, '.diff.png'));
    const absoluteA = path.join(artifactDir, renderAFile);
    const absoluteB = path.join(artifactDir, renderBFile);
    const absoluteDiff = path.join(artifactDir, diffFile);
    if (missingPaths.has(relativePath)) {
      results.push({ path: relativePath, width_a: null, height_a: null, width_b: null, height_b: null, changed_pixels: null, result: 'missing', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    await mkdir(path.dirname(absoluteA), { recursive: true });
    await mkdir(path.dirname(absoluteB), { recursive: true });
    await mkdir(path.dirname(absoluteDiff), { recursive: true });
    try {
      await copyFile(path.join(renderA, relativePath), absoluteA);
      await copyFile(path.join(renderB, relativePath), absoluteB);
    } catch (error) {
      diagnostics.push(`could not copy render artifact for ${relativePath}: ${error.message}`);
      continue;
    }
    const dimensionsA = run(imageCommand('identify'), ['-format', '%w %h', absoluteA]);
    const dimensionsB = run(imageCommand('identify'), ['-format', '%w %h', absoluteB]);
    if (dimensionsA.status !== 0 || dimensionsB.status !== 0) {
      diagnostics.push(`could not read PNG dimensions for ${relativePath}: A=${dimensionsA.stderr.trim()} B=${dimensionsB.stderr.trim()}`);
      continue;
    }
    const dimensionPattern = /^(\d+)\s+(\d+)$/;
    const parsedA = dimensionsA.stdout.trim().match(dimensionPattern);
    const parsedB = dimensionsB.stdout.trim().match(dimensionPattern);
    if (!parsedA || !parsedB || parsedA.slice(1).some((value) => Number(value) < 1) || parsedB.slice(1).some((value) => Number(value) < 1)) {
      diagnostics.push(`malformed ImageMagick dimensions for ${relativePath}: A=${JSON.stringify(dimensionsA.stdout)} B=${JSON.stringify(dimensionsB.stdout)}`);
      continue;
    }
    const [widthA, heightA] = parsedA.slice(1).map(Number);
    const [widthB, heightB] = parsedB.slice(1).map(Number);
    if (widthA !== widthB || heightA !== heightB) {
      diagnostics.push(`render dimensions differ for ${relativePath}: ${widthA}x${heightA} != ${widthB}x${heightB}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'dimension-mismatch', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    const compareResult = run(imageCommand('compare'), ['-metric', 'AE', '-fuzz', '0%', absoluteA, absoluteB, absoluteDiff]);
    if (compareResult.status !== 0 && compareResult.status !== 1) {
      diagnostics.push(`ImageMagick compare failed for ${relativePath} (exit ${compareResult.status}): ${compareResult.stderr.trim()}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'inconclusive', comparator_exit: compareResult.status, comparator_stderr: compareResult.stderr, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    if (compareResult.stdout.trim()) {
      diagnostics.push(`unexpected ImageMagick compare stdout for ${relativePath}: ${JSON.stringify(compareResult.stdout)}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'inconclusive', comparator_exit: compareResult.status, comparator_stdout: compareResult.stdout, comparator_stderr: compareResult.stderr, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    let changedPixels;
    try {
      changedPixels = strictAeOutput(compareResult.stderr);
    } catch (error) {
      diagnostics.push(`${relativePath}: ${error.message}; raw stderr=${JSON.stringify(compareResult.stderr)}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'inconclusive', comparator_exit: compareResult.status, comparator_stderr: compareResult.stderr, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: changedPixels, result: changedPixels === 0 ? 'equal' : 'drift', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
  }
  const comparatorVersion = comparatorVersionFile ? (await readFile(comparatorVersionFile, 'utf8')).trim() : 'unknown';
  const expectedPackageVersion = argValue(args, '--expected-imagemagick-package');
  if (!expectedPackageVersion || !comparatorVersion.includes(`imagemagick=${expectedPackageVersion}`)) {
    throw new Error(`ImageMagick package identity mismatch: expected imagemagick=${expectedPackageVersion ?? 'unset'}`);
  }
  const expectedSet = scope === 'full' ? fullInventory : selected;
  const missingA = expectedSet.filter((entry) => !actualA.includes(entry));
  const missingB = expectedSet.filter((entry) => !actualB.includes(entry));
  const extraA = actualA.filter((entry) => !expectedSet.includes(entry));
  const extraB = actualB.filter((entry) => !expectedSet.includes(entry));
  const inventoryHash = createHash('sha256').update(`${selected.join('\n')}\n`).digest('hex');
  const manifest = {
    schema_version: 2,
    workflow_name: 'Phase 244 Playwright measurement',
    event: 'workflow_dispatch',
    head_branch: branch,
    source_sha: sourceSha,
    run_id: runId,
    scope,
    inventory: selected,
    inventory_count: selected.length,
    inventory_sha256: inventoryHash,
    missing_paths: { render_a: missingA, render_b: missingB },
    extra_paths: { render_a: extraA, render_b: extraB },
    rendered_paths: { render_a: actualA, render_b: actualB },
    package_versions: { render_a: packageA ?? 'unknown', render_b: packageB ?? 'unknown' },
    chromium_revisions: { render_a: revisionA ?? 'unknown', render_b: revisionB ?? 'unknown' },
    comparator: { name: 'ImageMagick compare -metric AE -fuzz 0%', package: `imagemagick=${expectedPackageVersion}`, version: comparatorVersion },
    results,
    total_changed_pixels: results.reduce((sum, entry) => sum + (Number.isSafeInteger(entry.changed_pixels) ? entry.changed_pixels : 0), 0),
    diagnostics: [
      ...(captureStatusA === '0' ? [] : [`render-a capture exited ${captureStatusA}`]),
      ...(captureStatusB === '0' ? [] : [`render-b capture exited ${captureStatusB}`]),
      ...diagnostics,
    ],
    verdict: captureStatusA !== '0' || captureStatusB !== '0' || diagnostics.length > 0 || results.some((entry) => entry.result !== 'equal') || missingA.length > 0 || missingB.length > 0 || extraA.length > 0 || extraB.length > 0
      ? 'inconclusive'
      : results.some((entry) => entry.changed_pixels > 0) ? 'drift' : 'zero-drift',
  };
  await writeFile(output, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  if (manifest.verdict !== 'zero-drift') throw new Error(`measurement verdict is ${manifest.verdict}; see manifest and diff artifacts`);
  console.log(JSON.stringify({ valid: true, source_sha: sourceSha, run_id: runId, paths: results.length, verdict: manifest.verdict }));
}

async function listPngs(root) {
  const snapshotRoot = path.join(root, 'test/example/priv/playwright/tests');
  const result = run('find', [snapshotRoot, '-type', 'f', '-path', '*-snapshots/*.png', '-print']);
  if (result.status !== 0) throw new Error(`could not list rendered PNGs under ${root}`);
  return result.stdout.split(/\r?\n/).filter(Boolean).map((file) => path.relative(root, file).split(path.sep).join('/')).map(assertSafeInventoryPath).sort();
}

async function main() {
  const [, , command, ...args] = process.argv;
  if (command === 'verify') return await verifyManifest(args);
  if (command === 'compare') return compare(args);
  if (command === 'build-manifest') return await buildManifest(args);
  if (command === 'inventory') {
    const sourceSha = argValue(args, '--source-sha');
    if (!sourceSha) throw new Error('inventory requires --source-sha');
    console.log(JSON.stringify({ source_sha: sourceSha, paths: gitInventory(sourceSha) }, null, 2));
    return;
  }
  throw new Error('usage: measure-playwright-drift.mjs inventory|compare|verify ...');
}

main().catch((error) => fail(error.message));
