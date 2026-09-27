#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "verify-playwright-source-tree: FAIL: $*" >&2
  exit 1
}

[[ "$#" -eq 3 ]] || fail "usage: $0 <reference-root> <install-root> <expected-playwright-version>"
REFERENCE_ROOT="$(cd "$1" 2>/dev/null && pwd -P)" || fail "reference root does not exist: $1"
INSTALL_ROOT="$(cd "$2" 2>/dev/null && pwd -P)" || fail "install root does not exist: $2"
EXPECTED_VERSION="$3"
[[ "$EXPECTED_VERSION" == 1.59.1 || "$EXPECTED_VERSION" == 1.62.1 ]] || \
  fail "unsupported expected Playwright version: $EXPECTED_VERSION"

node - "$REFERENCE_ROOT" "$INSTALL_ROOT" "$EXPECTED_VERSION" <<'NODE'
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const [referenceRoot, installRoot, expectedVersion] = process.argv.slice(2);
const dependencyPaths = new Set([
  'test/example/priv/playwright/package.json',
  'test/example/priv/playwright/package-lock.json',
]);
const packageNames = ['@playwright/test', 'playwright', 'playwright-core'];
const fail = (message) => {
  console.error(`verify-playwright-source-tree: FAIL: ${message}`);
  process.exit(1);
};

function walk(root, relative = '') {
  const entries = fs.readdirSync(path.join(root, relative), { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name));
  const paths = [];
  for (const entry of entries) {
    const child = relative ? `${relative}/${entry.name}` : entry.name;
    if (entry.name === 'node_modules') continue;
    if (entry.isDirectory()) paths.push(...walk(root, child));
    else paths.push(child);
  }
  return paths;
}

function digest(root, relative) {
  const absolute = path.join(root, relative);
  const info = fs.lstatSync(absolute);
  const hash = crypto.createHash('sha256');
  if (info.isSymbolicLink()) hash.update(`symlink\0${fs.readlinkSync(absolute)}`);
  else if (info.isFile()) hash.update(`file\0${fs.readFileSync(absolute)}`);
  else hash.update(`${info.mode}\0${info.size}`);
  return hash.digest('hex');
}

function readJson(root, relative, side) {
  const file = path.join(root, relative);
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`${side} ${relative} is missing or invalid JSON (${error.message})`);
  }
}

function requireVersion(actual, name, expected, side, source) {
  if (actual !== expected) {
    fail(`${side} ${source}: ${name} version expected ${expected}, got ${actual ?? 'missing'}`);
  }
}

function verifyPackageVersions(root, side, expected) {
  const manifestPath = [...dependencyPaths][0];
  const lockPath = [...dependencyPaths][1];
  const manifest = readJson(root, manifestPath, side);
  const lock = readJson(root, lockPath, side);
  const dependencyMaps = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];

  for (const name of packageNames) {
    for (const mapName of dependencyMaps) {
      const value = manifest[mapName]?.[name];
      if (value !== undefined) {
        requireVersion(value, name, expected, side, manifestPath);
      }
    }
    const lockVersion = lock.packages?.[`node_modules/${name}`]?.version;
    requireVersion(lockVersion, name, expected, side, lockPath);
  }
  return { manifest, lock };
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function normalizeManifest(manifest) {
  const normalized = clone(manifest);
  for (const mapName of ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies']) {
    for (const name of packageNames) delete normalized[mapName]?.[name];
  }
  return normalized;
}

function normalizeLock(lock) {
  const normalized = clone(lock);
  for (const [key, record] of Object.entries(normalized.packages ?? {})) {
    if (packageNames.some((name) => key === `node_modules/${name}`)) {
      delete normalized.packages[key];
      continue;
    }
    for (const field of ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies']) {
      for (const name of packageNames) delete record[field]?.[name];
    }
  }
  for (const [name, record] of Object.entries(normalized.dependencies ?? {})) {
    if (packageNames.includes(name)) {
      delete normalized.dependencies[name];
      continue;
    }
    for (const nameToRemove of packageNames) delete record.requires?.[nameToRemove];
  }
  return normalized;
}

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}

const referencePaths = walk(referenceRoot).filter((file) => !dependencyPaths.has(file));
const installPaths = walk(installRoot).filter((file) => !dependencyPaths.has(file));
const referenceSet = new Set(referencePaths);
const installSet = new Set(installPaths);
const allPaths = [...new Set([...referencePaths, ...installPaths])].sort();
for (const relative of allPaths) {
  if (!referenceSet.has(relative)) fail(`install-only path: ${relative}`);
  if (!installSet.has(relative)) fail(`reference-only path: ${relative}`);
  if (digest(referenceRoot, relative) !== digest(installRoot, relative)) {
    fail(`content mismatch: ${relative}`);
  }
}

const referencePackages = verifyPackageVersions(referenceRoot, 'reference', '1.62.1');
const installPackages = verifyPackageVersions(installRoot, 'install', expectedVersion);
if (JSON.stringify(stable(normalizeManifest(referencePackages.manifest))) !==
    JSON.stringify(stable(normalizeManifest(installPackages.manifest)))) {
  fail(`${[...dependencyPaths][0]} has unexpected changes outside the Playwright package trio`);
}
if (JSON.stringify(stable(normalizeLock(referencePackages.lock))) !==
    JSON.stringify(stable(normalizeLock(installPackages.lock)))) {
  fail(`${[...dependencyPaths][1]} has unexpected changes outside the Playwright package trio`);
}

console.log(`verify-playwright-source-tree: PASS: source tree matches; Playwright trio ${expectedVersion}`);
NODE
