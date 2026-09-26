#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
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
  if (args.includes('--inventory-only') && !samePaths(expected, manifest.inventory)) {
    throw new Error(`manifest path set differs from the ${expected.length}-path inventory at ${sourceSha}`);
  }
  if (!manifest.inventory.every((entry) => expected.includes(assertSafeInventoryPath(entry)))) {
    throw new Error('manifest includes a path outside the tracked inventory at the requested source SHA');
  }
  for (const entry of manifest.results) {
    assertSafeInventoryPath(entry.path);
    if (!Number.isInteger(entry.width) || entry.width <= 0 || !Number.isInteger(entry.height) || entry.height <= 0) {
      throw new Error(`invalid dimensions for ${entry.path}`);
    }
    if (!Number.isInteger(entry.changed_pixels) || (!inventoryOnly && entry.changed_pixels !== 0)) {
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
  console.log(JSON.stringify({ valid: true, source_sha: sourceSha, run_id: manifest.run_id, paths: manifest.inventory.length }));
}

function strictAeOutput(stderr) {
  const match = stderr.match(/^\s*(\d+)\s*$/);
  if (!match) throw new Error(`ImageMagick AE output is unavailable or malformed: ${JSON.stringify(stderr.trim())}`);
  const count = Number(match[1]);
  if (!Number.isSafeInteger(count)) throw new Error('ImageMagick AE count is outside the safe integer range');
  return count;
}

function compare(args) {
  const [left, right, diff] = args;
  if (!left || !right || !diff || args.length !== 3) throw new Error('compare requires <render-a.png> <render-b.png> <diff.png>');
  const result = run('compare', ['-metric', 'AE', '-fuzz', '0%', left, right, diff]);
  if (result.status !== 0 && result.status !== 1) {
    throw new Error(`ImageMagick compare failed (exit ${result.status}): ${result.stderr.trim()}`);
  }
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
  }

  await mkdir(path.join(artifactDir, 'render-a'), { recursive: true });
  await mkdir(path.join(artifactDir, 'render-b'), { recursive: true });
  await mkdir(path.join(artifactDir, 'diffs'), { recursive: true });
  const results = [];
  for (const relativePath of selected) {
    if (missingPaths.has(relativePath)) continue;
    const renderAFile = path.posix.join('render-a', relativePath);
    const renderBFile = path.posix.join('render-b', relativePath);
    const diffFile = path.posix.join('diffs', relativePath.replace(/\.png$/, '.diff.png'));
    const absoluteA = path.join(artifactDir, renderAFile);
    const absoluteB = path.join(artifactDir, renderBFile);
    const absoluteDiff = path.join(artifactDir, diffFile);
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
    const dimensionsA = run('identify', ['-format', '%w %h', absoluteA]);
    const dimensionsB = run('identify', ['-format', '%w %h', absoluteB]);
    if (dimensionsA.status !== 0 || dimensionsB.status !== 0) {
      diagnostics.push(`could not read PNG dimensions for ${relativePath}`);
      continue;
    }
    if (dimensionsA.stdout !== dimensionsB.stdout) {
      diagnostics.push(`render dimensions differ for ${relativePath}`);
      continue;
    }
    const [width, height] = dimensionsA.stdout.trim().split(/\s+/).map(Number);
    const compareResult = run('compare', ['-metric', 'AE', '-fuzz', '0%', absoluteA, absoluteB, absoluteDiff]);
    if (compareResult.status !== 0 && compareResult.status !== 1) {
      diagnostics.push(`ImageMagick compare failed for ${relativePath}: ${compareResult.stderr.trim()}`);
      continue;
    }
    let changedPixels;
    try {
      changedPixels = strictAeOutput(compareResult.stderr);
    } catch (error) {
      diagnostics.push(`${relativePath}: ${error.message}`);
      continue;
    }
    results.push({ path: relativePath, width, height, changed_pixels: changedPixels, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
  }
  const comparatorVersion = comparatorVersionFile ? (await readFile(comparatorVersionFile, 'utf8')).trim() : 'unknown';
  const manifest = {
    schema_version: 1,
    workflow_name: 'Phase 244 Playwright measurement',
    event: 'workflow_dispatch',
    head_branch: branch,
    source_sha: sourceSha,
    run_id: runId,
    scope,
    inventory: selected,
    rendered_paths: scope === 'full' ? { render_a: actualA, render_b: actualB } : { render_a: selected, render_b: selected },
    package_versions: { render_a: packageA ?? 'unknown', render_b: packageB ?? 'unknown' },
    chromium_revisions: { render_a: revisionA ?? 'unknown', render_b: revisionB ?? 'unknown' },
    comparator: { name: 'ImageMagick compare -metric AE -fuzz 0%', version: comparatorVersion },
    results,
    diagnostics: [
      ...(captureStatusA === '0' ? [] : [`render-a capture exited ${captureStatusA}`]),
      ...(captureStatusB === '0' ? [] : [`render-b capture exited ${captureStatusB}`]),
      ...diagnostics,
    ],
    verdict: captureStatusA !== '0' || captureStatusB !== '0' || diagnostics.length > 0
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
