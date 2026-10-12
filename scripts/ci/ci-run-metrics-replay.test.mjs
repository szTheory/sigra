import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const script = path.resolve('scripts/ci/ci-run-metrics.sh');
const hash = (value) => createHash('sha256').update(value).digest('hex');

test('snapshot replay emits explicit zero-sample unknowns and distinct cost dimensions', () => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'sigra-replay-contract-'));
  try {
    mkdirSync(path.join(root, 'raw', 'populations'), { recursive: true });
    mkdirSync(path.join(root, 'source'), { recursive: true });
    const request = JSON.stringify({ schema_version: 'sigra.ci-run-metrics/request-ledger-v1', requests: [] });
    const selection = JSON.stringify({ schema_version: 'sigra.ci-run-metrics/selection-ledger-v1', populations: [] });
    writeFileSync(path.join(root, 'request-ledger.json'), request);
    writeFileSync(path.join(root, 'selection-ledger.json'), selection);
    const rawSources = {
      'rate-limit.json': JSON.stringify({ resources: { core: { remaining: 5000 } } }),
      'effective-rules.json': JSON.stringify([]),
      'branch-protection.json': JSON.stringify({ status: 'not_configured' }),
      'rulesets.json': JSON.stringify([]),
    };
    const sourceHashes = {};
    for (const [filename, contents] of Object.entries(rawSources)) {
      writeFileSync(path.join(root, 'raw', filename), contents);
      sourceHashes[filename.replace('.json', '').replaceAll('-', '_')] = hash(contents);
    }
    const workflowSource = 'name: CI\n';
    writeFileSync(path.join(root, 'source', 'ci.yml'), workflowSource);
    const populations = {};
    for (const name of ['pull_request', 'push_main', 'schedule', 'manual', 'release_push']) {
      const population = JSON.stringify({ population: name, api_total_count: 0, population_capped: false, population_exhausted: true, runs: [], records: [] });
      writeFileSync(path.join(root, 'raw', 'populations', `${name}.json`), population);
      populations[name] = hash(population);
    }
    const manifest = {
      schema_version: 'sigra.ci-run-metrics/snapshot-v1', repository: 'szTheory/sigra', workflow: 'ci.yml',
      cutoff_utc: '2026-10-12T00:00:00Z', window_start_utc: '2026-09-12T00:00:00Z', status: 'complete',
      stop_reason: null, request_count: 0, source_sha: 'fixture',
      workflow_sha256: hash(workflowSource),
      source_file_sha256: { 'ci.yml': hash(workflowSource) },
      source_sha256: { request_ledger: hash(request), selection_ledger: hash(selection), ...sourceHashes, ...populations },
      populations: {
        pull_request: { population: 'pull_request', api_total_count: 0, population_capped: false, population_exhausted: true, runs: [] },
        push_main: { population: 'push_main', api_total_count: 0, population_capped: false, population_exhausted: true, runs: [] },
        schedule: { population: 'schedule', api_total_count: 0, population_capped: false, population_exhausted: true, runs: [] },
        manual: { population: 'manual', event: 'workflow_dispatch', api_total_count: 0, records: [] },
        release_push: { population: 'release_push', event: 'push', records: [] },
      },
    };
    writeFileSync(path.join(root, 'manifest.json'), JSON.stringify(manifest));
    const output = execFileSync('bash', [script, '--replay', '--source-bundle', root, '--format', 'json'], { encoding: 'utf8' });
    const replay = JSON.parse(output);
    assert.equal(replay.ranked_by_wait?.pull_request?.status, 'insufficient_data');
    assert.equal(replay.ranked_by_wait?.pull_request?.n, 0);
    assert.equal(replay.ranked_by_runner?.pull_request?.n, 0);
    assert.equal(replay.stage_costs?.pull_request?.setup?.status, 'unknown');
    assert.equal(replay.cache_outcome?.browser_binaries, 'unknown');
    assert.equal(replay.instrumentation_baseline?.exunit?.status, 'historical_baseline');
    assert.equal(replay.instrumentation_baseline?.exunit?.instrumentation_overhead_us, -60547);
    assert.equal(replay.cohorts?.docs_only?.status, 'insufficient_data');
    assert.equal(replay.cohorts?.docs_only?.n, 0);
    assert.equal(replay.failure_signatures?.status, 'no_current_flake_identified');
    assert.equal(replay.failure_analysis?.inspected_family_count, 0);
    assert.notEqual(replay.ranked_by_wait, replay.ranked_by_runner);

    const prPath = path.join(root, 'raw', 'populations', 'pull_request.json');
    const cancelledRun = { id: 42, event: 'pull_request', head_sha: 'sha-42', conclusion: 'cancelled', created_at: '2026-10-11T00:00:00Z', updated_at: '2026-10-11T00:01:00Z', run_attempt: 1, attempt_jobs: {} };
    const prPopulation = JSON.stringify({ population: 'pull_request', api_total_count: 1, population_capped: false, population_exhausted: true, runs: [cancelledRun], records: [] });
    writeFileSync(prPath, prPopulation);
    manifest.source_sha256.pull_request = hash(prPopulation);
    manifest.populations.pull_request.runs = [cancelledRun];
    writeFileSync(path.join(root, 'manifest.json'), JSON.stringify(manifest));
    const cancellationReplay = JSON.parse(execFileSync('bash', [script, '--replay', '--source-bundle', root, '--format', 'json'], { encoding: 'utf8' }));
    assert.equal(cancellationReplay.failure_class?.cancellation_unclassified?.length, 1);

    const jobPath = path.join(root, 'raw', 'families', '52', 'jobs-attempt-1.json');
    mkdirSync(path.dirname(jobPath), { recursive: true });
    const jobs = JSON.stringify({ jobs: [{ id: 5201, name: 'Library tests', started_at: '2026-10-11T00:01:00Z', completed_at: '2026-10-11T00:02:00Z', conclusion: 'success', steps: [] }] });
    writeFileSync(jobPath, jobs);
    const mainRun = { id: 52, event: 'push', head_branch: 'main', head_sha: 'sha-52', conclusion: 'success', created_at: '2026-10-11T00:00:00Z', run_attempt: 1, attempt_jobs: { '1': { path: 'raw/families/52/jobs-attempt-1.json', sha256: hash(jobs) } } };
    const mainPopulation = JSON.stringify({ population: 'push_main', api_total_count: 1, population_capped: false, population_exhausted: true, runs: [mainRun], records: [] });
    writeFileSync(path.join(root, 'raw', 'populations', 'push_main.json'), mainPopulation);
    manifest.source_sha256.push_main = hash(mainPopulation);
    manifest.populations.push_main.runs = [mainRun];
    writeFileSync(path.join(root, 'manifest.json'), JSON.stringify(manifest));
    const singleReplay = JSON.parse(execFileSync('bash', [script, '--replay', '--source-bundle', root, '--format', 'json'], { encoding: 'utf8' }));
    assert.equal(singleReplay.ranked_by_runner?.main?.n, 1);
    assert.equal(singleReplay.ranked_by_runner?.main?.total_seconds, 60);
    assert.equal(singleReplay.ranked_by_runner?.main?.limitation, 'single_observation');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
