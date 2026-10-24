import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { captureRunnerImage, verifyRunnerImage, normalizeImageOS } from './ci-runner-image.mjs';

const rows = [
  { group: 'Operating System', detail: 'Ubuntu\n24.04.5\nLTS' },
  { group: 'Runner Image', detail: 'Image: ubuntu-24.04\nVersion: 20261012.334.1\nIncluded Software: https://github.com/actions/runner-images/blob/ubuntu24/20261012.334/images/ubuntu/Ubuntu2404-Readme.md\nImage Release: https://github.com/actions/runner-images/releases/tag/ubuntu24%2F20261012.334' },
];
const inputs = () => ({ imageData: Buffer.from(JSON.stringify(rows, null, 2) + '\n'),
  osRelease: Buffer.from('NAME="Ubuntu"\nID=ubuntu\nVERSION_ID="24.04"\n'), machine: 'x86_64',
  env: { ImageOS: 'ubuntu24', ImageVersion: '20261012.334.1', GITHUB_REPOSITORY: 'szTheory/sigra',
    GITHUB_RUN_ID: '40035537413', GITHUB_RUN_ATTEMPT: '1', GITHUB_SHA: 'a'.repeat(40),
    GITHUB_JOB: 'example_playwright_shard', MATRIX_SEAM: 'design_gallery', TOKEN: 'SECRET' },
  now: '2026-10-23T22:44:00Z' });

test('captures exact official file bytes and verifies aliases without recording unrelated environment', () => {
  const source = inputs();
  const proof = captureRunnerImage(source);
  assert.equal(proof.status, 'verified');
  assert.equal(proof.runner_image.image_os, 'ubuntu24');
  assert.deepEqual(Buffer.from(proof.image_file.base64, 'base64'), source.imageData);
  assert.equal(proof.image_file.sha256, createHash('sha256').update(source.imageData).digest('hex'));
  assert.equal(proof.identity.matrix_seam, 'design_gallery');
  assert.equal(verifyRunnerImage({ proof, ...source }).status, 'verified');
  assert.ok(!JSON.stringify(proof).includes('SECRET'));
  assert.equal(normalizeImageOS('ubuntu-24.04'), 'ubuntu24');
  assert.equal(normalizeImageOS('ubuntu-22.04'), null);
});

test('a stale file and newer environment fail closed instead of choosing either version', () => {
  const source = inputs();
  source.env.ImageVersion = '20261023.334.3';
  const proof = captureRunnerImage(source);
  assert.equal(proof.status, 'image_identity_conflict');
  assert.equal(proof.file_image.image_version, '20261012.334.1');
  assert.equal(proof.environment_image.image_version, '20261023.334.3');
  assert.equal(proof.runner_image, null);
  assert.equal(verifyRunnerImage({ proof, ...source }).status, 'image_identity_conflict');
});

test('invalid JSON, duplicate rows and ambiguous fields never become verified', () => {
  for (const imageData of [Buffer.from('SECRET malformed {'), Buffer.from('{}'),
    Buffer.from(JSON.stringify([...rows, rows[1]])),
    Buffer.from(JSON.stringify([{ ...rows[1], detail: rows[1].detail + '\nVersion: 20261023.334.3' }]))]) {
    const proof = captureRunnerImage({ ...inputs(), imageData });
    assert.equal(proof.status, 'image_identity_unavailable');
    assert.equal(proof.runner_image, null);
    assert.ok(!JSON.stringify(proof).includes('SECRET'));
  }
});

test('changing either raw file, its proof hash, parsed values or the job identity is rejected', () => {
  const source = inputs();
  const proof = captureRunnerImage(source);
  for (const changed of [
    { ...source, imageData: Buffer.concat([source.imageData, Buffer.from('\n')]) },
    { ...source, osRelease: Buffer.concat([source.osRelease, Buffer.from('\n')]) },
    { ...source, machine: 'aarch64' },
    { ...source, env: { ...source.env, GITHUB_RUN_ATTEMPT: '2' } },
    { ...source, env: { ...source.env, GITHUB_SHA: 'b'.repeat(40) } },
    { ...source, env: { ...source.env, MATRIX_SEAM: 'admin_checkpoints' } },
  ]) assert.equal(verifyRunnerImage({ proof, ...changed }).status, 'image_identity_conflict');
  const changedHash = structuredClone(proof);
  changedHash.image_file.sha256 = '0'.repeat(64);
  assert.equal(verifyRunnerImage({ proof: changedHash, ...source }).status, 'image_identity_conflict');
  const changedParsed = structuredClone(proof);
  changedParsed.runner_image.image_version = '20261023.334.3';
  assert.equal(verifyRunnerImage({ proof: changedParsed, ...source }).status, 'image_identity_conflict');
});

test('missing or invalid machine, source, version, seam and OS identity fail closed', () => {
  const source = inputs();
  for (const changed of [{ ...source, machine: 'other' },
    { ...source, osRelease: Buffer.from('ID=ubuntu\nVERSION_ID="26.04"\n') },
    { ...source, env: { ...source.env, GITHUB_SHA: undefined } },
    { ...source, env: { ...source.env, ImageVersion: 'SECRET' } },
    { ...source, env: { ...source.env, MATRIX_SEAM: '../SECRET' } }]) {
    const result = captureRunnerImage(changed);
    assert.equal(result.status, 'image_identity_unavailable');
    assert.ok(!JSON.stringify(result).includes('SECRET'));
  }
});

test('CLI refuses path overrides and existing outputs; malformed proofs produce safe JSON', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sigra-image-test-'));
  try {
    const path = join(directory, 'proof.json');
    writeFileSync(path, 'SECRET invalid json');
    const cli = new URL('./ci-runner-image.mjs', import.meta.url).pathname;
    const malformed = spawnSync(process.execPath, [cli, 'verify', '--proof', path], { encoding: 'utf8' });
    assert.equal(malformed.status, 1);
    assert.equal(JSON.parse(malformed.stdout).status, 'image_identity_unavailable');
    assert.ok(!malformed.stderr.includes('SECRET') && !malformed.stdout.includes('SECRET'));
    const existing = spawnSync(process.execPath, [cli, 'capture', '--output', path], { encoding: 'utf8' });
    assert.equal(existing.status, 1);
    assert.equal(readFileSync(path, 'utf8'), 'SECRET invalid json');
    const override = spawnSync(process.execPath, [cli, 'capture', '--image-file', path], { encoding: 'utf8' });
    assert.equal(override.status, 2);
  } finally { rmSync(directory, { recursive: true }); }
});
