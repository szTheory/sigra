#!/usr/bin/env node
// Capture the runner's own image record before tool setup can affect measurements.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { machine as currentMachine } from 'node:os';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const SCHEMA = 'sigra.ci-runner-image/v2';
// GitHub documents Set up job / Runner Image as the inventory for the exact
// runner. The image build writes this file separately from ImageVersion env.
// Always use the native file, for every role and regardless of which is newer.
const AUTHORITY = 'runner_native_image_file';
const IMAGE_PATH = '/imagegeneration/imagedata.json';
const OS_PATH = '/etc/os-release';
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const safe = (value, pattern) => typeof value === 'string' && pattern.test(value) ? value : null;

export function normalizeImageOS(value) {
  if (value === 'ubuntu24' || value === 'ubuntu-24.04') return 'ubuntu24';
  return null;
}

function identityFromEnvironment(env) {
  return {
    repository: safe(env.GITHUB_REPOSITORY, /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/),
    run_id: safe(env.GITHUB_RUN_ID, /^[1-9][0-9]*$/),
    run_attempt: safe(env.GITHUB_RUN_ATTEMPT, /^[1-9][0-9]*$/),
    source_sha: safe(env.GITHUB_SHA, /^[0-9a-f]{40}$/),
    job: safe(env.GITHUB_JOB, /^[A-Za-z_][A-Za-z0-9_-]*$/),
    matrix_seam: env.MATRIX_SEAM === undefined || env.MATRIX_SEAM === '' ? null
      : safe(env.MATRIX_SEAM, /^[a-z][a-z0-9_]*$/),
  };
}

function parseImageData(bytes) {
  const rows = JSON.parse(bytes.toString('utf8'));
  if (!Array.isArray(rows)) throw new Error('image_data_not_array');
  const images = rows.filter((row) => row && row.group === 'Runner Image');
  if (images.length !== 1 || typeof images[0].detail !== 'string') throw new Error('runner_image_row_not_unique');
  const lines = images[0].detail.split(/\r?\n/);
  const names = lines.filter((line) => line.startsWith('Image: '));
  const versions = lines.filter((line) => line.startsWith('Version: '));
  if (names.length !== 1 || versions.length !== 1) throw new Error('runner_image_fields_not_unique');
  const imageOS = normalizeImageOS(names[0].slice(7));
  const imageVersion = safe(versions[0].slice(9), /^[0-9]{8}\.[0-9]+\.[0-9]+$/);
  if (!imageOS || !imageVersion) throw new Error('runner_image_fields_invalid');
  return { image_os: imageOS, image_version: imageVersion };
}

function osIdentity(bytes) {
  const values = {};
  for (const line of bytes.toString('utf8').split(/\r?\n/)) {
    const match = /^(ID|VERSION_ID)=(?:"([a-zA-Z0-9_.-]+)"|([a-zA-Z0-9_.-]+))$/.exec(line);
    if (match) {
      if (values[match[1]] !== undefined) throw new Error('os_release_fields_not_unique');
      values[match[1]] = match[2] ?? match[3];
    }
  }
  if (values.ID !== 'ubuntu' || values.VERSION_ID !== '24.04') throw new Error('os_release_not_ubuntu_24_04');
  return { id: values.ID, version_id: values.VERSION_ID };
}

export function captureRunnerImage({ imageData, osRelease, machine, env, now = new Date().toISOString() }) {
  const imageBytes = Buffer.from(imageData);
  const osBytes = Buffer.from(osRelease);
  const environment = {
    image_os: normalizeImageOS(env.ImageOS),
    image_version: safe(env.ImageVersion, /^[0-9]{8}\.[0-9]+\.[0-9]+$/),
  };
  const identity = identityFromEnvironment(env);
  const result = { schema_version: SCHEMA, identity_authority: AUTHORITY,
    captured_at: now, status: 'image_identity_unavailable',
    image_file: { path: IMAGE_PATH, sha256: hash(imageBytes) },
    os_release_file: { path: OS_PATH, sha256: hash(osBytes) },
    machine: safe(machine, /^(x86_64|aarch64)$/), identity,
    environment_image: environment, environment_agrees: false,
    file_image: null, runner_image: null, diagnostics: [] };
  try {
    result.file_image = parseImageData(imageBytes);
    result.os_release = osIdentity(osBytes);
  } catch (error) {
    // JSON parsing messages may contain input bytes; use fixed diagnostics only.
    result.diagnostics.push(error instanceof SyntaxError ? 'image_data_json_invalid' : error.message);
    return result;
  }
  // Preserve the exact valid runner-owned file bytes, not a reserialized version.
  result.image_file.base64 = imageBytes.toString('base64');
  result.os_release_file.base64 = osBytes.toString('base64');
  if (!result.machine || Object.entries(identity).some(([key, value]) => key !== 'matrix_seam' && value === null)
      || (env.MATRIX_SEAM && identity.matrix_seam === null)) {
    result.diagnostics.push('runner_environment_identity_missing_or_invalid');
    return result;
  }
  result.environment_agrees = environment.image_os === result.file_image.image_os
    && environment.image_version === result.file_image.image_version;
  if (!result.environment_agrees) {
    result.diagnostics.push('runner_file_and_environment_disagree');
  }
  result.status = 'verified';
  result.runner_image = result.file_image;
  return result;
}

export function verifyRunnerImage({ proof, imageData, osRelease, machine, env, now = new Date().toISOString() }) {
  const current = captureRunnerImage({ imageData, osRelease, machine, env, now });
  const compact = { schema_version: SCHEMA, identity_authority: AUTHORITY, status: 'image_identity_conflict',
    captured_at: proof?.captured_at ?? null, verified_at: now,
    image_file_sha256: current.image_file.sha256, os_release_sha256: current.os_release_file.sha256,
    machine: current.machine, identity: current.identity, runner_image: null,
    environment_image: current.environment_image, environment_agrees: current.environment_agrees,
    diagnostics: [] };
  if (proof?.schema_version !== SCHEMA || proof?.identity_authority !== AUTHORITY || proof?.status !== 'verified') {
    compact.diagnostics.push('early_image_proof_not_verified');
    return compact;
  }
  for (const key of ['image_file', 'os_release_file']) {
    const stored = proof[key];
    if (typeof stored?.base64 !== 'string') {
      compact.diagnostics.push('early_image_bytes_missing');
      return compact;
    }
    const decoded = Buffer.from(stored.base64, 'base64');
    if (stored.path !== current[key].path || decoded.toString('base64') !== stored.base64 || hash(decoded) !== stored.sha256
        || stored.sha256 !== current[key].sha256) {
      compact.diagnostics.push('runner_image_bytes_changed_or_invalid');
      return compact;
    }
  }
  // Reconstruct the early values from their retained original bytes, so modified
  // parsed fields cannot be accepted just because the file hashes still match.
  const earlyEnvironment = {
    image_os: normalizeImageOS(proof.environment_image?.image_os),
    image_version: safe(proof.environment_image?.image_version, /^[0-9]{8}\.[0-9]+\.[0-9]+$/),
  };
  const reconstructed = captureRunnerImage({ imageData: Buffer.from(proof.image_file.base64, 'base64'),
    osRelease: Buffer.from(proof.os_release_file.base64, 'base64'), machine,
    env: { ...env, ImageOS: earlyEnvironment.image_os, ImageVersion: earlyEnvironment.image_version },
    now: proof.captured_at });
  const fields = ['machine', 'identity', 'environment_image', 'environment_agrees', 'file_image', 'runner_image', 'os_release'];
  if (current.status !== 'verified' || reconstructed.status !== 'verified'
      || fields.some((key) => JSON.stringify(proof[key]) !== JSON.stringify(reconstructed[key]))) {
    compact.diagnostics.push('runner_image_or_job_identity_changed');
    return compact;
  }
  compact.status = 'verified';
  compact.runner_image = current.runner_image;
  compact.early_environment_image = earlyEnvironment;
  compact.environment_changed = JSON.stringify(earlyEnvironment) !== JSON.stringify(current.environment_image);
  compact.diagnostics.push(...current.diagnostics);
  if (compact.environment_changed) compact.diagnostics.push('runner_image_environment_changed');
  return compact;
}

function systemInputs() {
  return { imageData: readFileSync(IMAGE_PATH), osRelease: readFileSync(OS_PATH), machine: currentMachine(), env: process.env };
}

export function captureFromSystem() {
  return captureRunnerImage(systemInputs());
}

export function verifyFromSystem(proof) {
  return verifyRunnerImage({ proof, ...systemInputs() });
}

function main(args) {
  if (args.length !== 3 || !['capture', 'verify'].includes(args[0])
      || args[1] !== (args[0] === 'capture' ? '--output' : '--proof')) {
    process.stderr.write('usage: ci-runner-image.mjs capture --output NEW.json | verify --proof FILE.json\n');
    return 2;
  }
  let result;
  try {
    if (args[0] === 'capture') {
      try {
        result = captureFromSystem();
      } catch {
        result = { schema_version: SCHEMA, identity_authority: AUTHORITY, status: 'image_identity_unavailable', diagnostics: ['runner_image_files_unavailable'] };
      }
      writeFileSync(args[2], JSON.stringify(result, null, 2) + '\n', { flag: 'wx' });
      process.stdout.write(JSON.stringify({ status: result.status, diagnostics: result.diagnostics }) + '\n');
    } else {
      result = verifyFromSystem(JSON.parse(readFileSync(args[2], 'utf8')));
      process.stdout.write(JSON.stringify(result) + '\n');
    }
  } catch {
    process.stdout.write(JSON.stringify({ schema_version: SCHEMA, identity_authority: AUTHORITY, status: 'image_identity_unavailable', diagnostics: ['runner_image_proof_io_or_json_invalid'] }) + '\n');
    return 1;
  }
  return result.status === 'verified' ? 0 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) process.exitCode = main(process.argv.slice(2));
