import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const script = path.resolve('scripts/ci/ci-baseline-source-preflight.mjs');
const root = path.resolve('.');
const contract = '.planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json';
const bundle = '.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz';
const baseline = '.planning/phases/252-measure-current-ci/252-BASELINE.json';
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

test('real frozen source resolves every retained identity and digest', () => {
  const output = path.join(os.tmpdir(), `source-ready-${process.pid}.json`);
  try {
    const run = spawnSync(process.execPath, [script, '--root', root, '--contract', contract, '--bundle', bundle, '--output', output], { encoding: 'utf8' });
    assert.equal(run.status, 0, `${run.stdout}\n${run.stderr}`);
    const result = JSON.parse(readFileSync(output, 'utf8'));
    assert.equal(result.status, 'ready');
    assert.equal(result.synthetic, false);
    assert.equal(result.sources.length, 2);
    assert.ok(result.sources.every((source) => source.commit_matches && source.tree_matches && source.workflow_matches && source.workload_files.every((file) => file.matches)));
  } finally { rmSync(output, { force: true }); }
});

test('wrong bundle bytes block with the exact archive digest mismatch', () => {
  const temp = mkdtempSync(path.join(os.tmpdir(), 'source-preflight-'));
  try {
    const badBundle = path.join(temp, 'bad.tar.gz');
    const output = path.join(temp, 'result.json');
    writeFileSync(badBundle, 'not the frozen source bundle');
    const run = spawnSync(process.execPath, [script, '--root', root, '--contract', contract, '--bundle', badBundle, '--output', output], { encoding: 'utf8' });
    assert.notEqual(run.status, 0);
    const result = JSON.parse(readFileSync(output, 'utf8'));
    assert.equal(result.status, 'blocked');
    assert.ok(result.checks.some((check) => check.id === 'source_bundle_sha256' && check.expected && check.actual === sha256(readFileSync(badBundle))));
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('--check-only validates without writing an output record', () => {
  const temp = mkdtempSync(path.join(os.tmpdir(), 'source-preflight-check-'));
  try {
    const output = path.join(temp, 'must-not-exist.json');
    const run = spawnSync(process.execPath, [script, '--root', root, '--contract', contract, '--bundle', bundle, '--output', output, '--check-only'], { encoding: 'utf8' });
    assert.equal(run.status, 0, `${run.stdout}\n${run.stderr}`);
    assert.equal(requireExists(output), false);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

function requireExists(file) {
  try { readFileSync(file); return true; } catch { return false; }
}
