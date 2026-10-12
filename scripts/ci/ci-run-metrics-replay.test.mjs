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
    const request = JSON.stringify({ schema_version: 'sigra.ci-run-metrics/request-ledger-v1', requests: [] });
    const selection = JSON.stringify({ schema_version: 'sigra.ci-run-metrics/selection-ledger-v1', populations: [] });
    writeFileSync(path.join(root, 'request-ledger.json'), request);
    writeFileSync(path.join(root, 'selection-ledger.json'), selection);
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
      source_sha256: { request_ledger: hash(request), selection_ledger: hash(selection), ...populations },
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
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
