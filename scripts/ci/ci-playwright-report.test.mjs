import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { normalizeReport } from './ci-playwright-report.mjs';
import { browserInvocations } from './ci-browser-command.mjs';

const configPath = new URL('../../test/example/priv/playwright/playwright.config.ts', import.meta.url);
const workflowPath = new URL('../../.github/workflows/ci.yml', import.meta.url);
const cliPath = new URL('./ci-playwright-report.mjs', import.meta.url);

test('Playwright JSON output is opt-in beside the existing human-readable reporters', async () => {
  const config = await readFile(configPath, 'utf8');

  assert.match(config, /process\.env\.SIGRA_PLAYWRIGHT_JSON/);
  assert.match(config, /\['list'\]/);
  assert.match(config, /\['html',\s*\{\s*open:\s*'never',\s*outputFolder:\s*invocationOutputRoot \? path\.join\(invocationOutputRoot, 'html-report'\) : 'playwright-report\/html'\s*\}\]/);
  assert.match(config, /\['json',\s*\{\s*outputFile:\s*[^}]+\}\]/);
  assert.match(config, /reporters\.push/);
  assert.match(config, /reporter:\s*reporters/);
  assert.match(config, /fullyParallel:\s*false/);
  assert.match(config, /workers:\s*1/);
  assert.match(config, /retries:\s*0/);
});

test('the five browser seams use shared selection commands and retain their reports', async () => {
  const workflow = await readFile(workflowPath, 'utf8');
  const shard = workflow.split('  example_playwright_shard:', 2)[1]?.split('\n  example_playwright_smoke:', 2)[0];
  assert.ok(shard, 'expected the example_playwright_shard job');
  const expectedSeams = [
    'admin_behavior',
    'admin_checkpoints',
    'design_gallery',
    'non_admin_smoke',
    'demo_showcase',
  ];

  const actualSeams = [...shard.matchAll(/^\s+- seam: ([a-z_]+)\s*$/gm)].map((match) => match[1]);
  assert.deepEqual(actualSeams, expectedSeams);
  for (const seam of expectedSeams) {
    assert.ok(shard.includes(`ci-browser-command.mjs list --seam ${seam}`), `missing shared native list for ${seam}`);
    assert.ok(shard.includes(`ci-browser-command.mjs run --seam ${seam}`), `missing shared run for ${seam}`);
  }
  const reports = [
    ...browserInvocations('admin_behavior', 'pull_request')[0].invocations,
    ...browserInvocations('admin_checkpoints', 'pull_request')[0].invocations,
    ...browserInvocations('design_gallery', 'pull_request')[0].invocations,
    ...browserInvocations('design_gallery', 'push')[0].invocations,
    ...browserInvocations('non_admin_smoke', 'pull_request')[0].invocations,
    ...browserInvocations('demo_showcase', 'pull_request')[0].invocations,
  ];
  assert.equal(reports.length, 7);
  assert.equal(new Set(reports.map((entry) => entry.reportPath)).size, 7);
  assert.ok(reports.every((entry) => entry.retries === 0));
  assert.ok(reports.every((entry) => entry.selectionPath.endsWith('.selection.json')));
});

function result(retry, status, duration, startTime = '2026-10-12T18:00:00.000Z') {
  return {
    workerIndex: 0,
    parallelIndex: 0,
    status,
    duration,
    retry,
    startTime,
    errors: [],
    stdout: [],
    stderr: [],
    attachments: [],
  };
}

function nativeReport() {
  return {
    config: {
      projects: [{ id: 'chromium-id', name: 'chromium' }, { id: 'mobile-id', name: 'mobile' }],
    },
    suites: [
      {
        title: 'admin',
        file: 'tests/admin.spec.ts',
        specs: [
          {
            id: 'admin-test-id',
            title: 'keeps equal duration one',
            file: 'tests/admin.spec.ts',
            ok: true,
            tests: [
              {
                projectName: 'chromium',
                projectId: 'chromium-id',
                expectedStatus: 'passed',
                status: 'flaky',
                results: [result(0, 'failed', 200), result(1, 'passed', 200, '2026-10-12T18:00:01.000Z')],
              },
            ],
          },
          {
            id: 'admin-test-id-2',
            title: 'keeps equal duration two',
            file: 'tests/admin.spec.ts',
            ok: true,
            tests: [
              {
                projectName: 'mobile',
                projectId: 'mobile-id',
                expectedStatus: 'passed',
                status: 'expected',
                results: [result(0, 'passed', 200)],
              },
            ],
          },
          {
            id: 'admin-test-skipped',
            title: 'keeps skipped selection visible',
            file: 'tests/admin.spec.ts',
            ok: true,
            tests: [
              {
                projectName: 'chromium',
                projectId: 'chromium-id',
                expectedStatus: 'skipped',
                status: 'skipped',
                results: [],
              },
            ],
          },
        ],
      },
    ],
    errors: [],
    stats: {
      startTime: '2026-10-12T18:00:00.000Z',
      duration: 1250,
      expected: 1,
      unexpected: 0,
      flaky: 1,
      skipped: 1,
    },
  };
}

test('normalizes identity, retry, result and millisecond durations without merging ties', () => {
  const normalized = normalizeReport(nativeReport(), { seam: 'admin_behavior', invocation: 'behavior' });

  assert.equal(normalized.complete, true);
  assert.equal(normalized.seam, 'admin_behavior');
  assert.equal(normalized.invocation, 'behavior');
  assert.equal(normalized.unit, 'ms');
  assert.equal(normalized.selected_count, 3);
  assert.equal(normalized.skipped_count, 1);
  assert.equal(normalized.excluded_count, null);
  assert.equal(normalized.excluded_count_reason, 'native_json_does_not_include_excluded_cases');
  assert.equal(normalized.suite_elapsed_ms, 1250);
  assert.equal(normalized.sum_test_duration_ms, 600);
  assert.notEqual(normalized.sum_test_duration_ms, normalized.suite_elapsed_ms);
  const actualResults = normalized.tests.map((row) => [row.project, row.retry, row.result, row.duration_ms])
    .sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)));
  assert.deepEqual(actualResults, [
    ['chromium', 0, 'failed', 200],
    ['chromium', 1, 'passed', 200],
    ['chromium', null, 'skipped', null],
    ['mobile', 0, 'passed', 200],
  ].sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right))));
  assert.equal(new Set(normalized.tests.map((row) => row.test_id)).size, 3);
  assert.equal(normalized.reporter_overhead.status, 'unmeasured');
  assert.equal(normalized.reporter_overhead.overhead_ms, null);
  assert.equal(normalized.reporter_overhead.unit, 'ms');
  assert.equal(normalized.reporter_overhead.reason, 'paired_same_selection_runs_not_recorded');
  assert.equal(JSON.parse(JSON.stringify(normalized)).reporter_overhead.overhead_ms, null);
});

test('stable identity order is independent of native suite order when durations tie', () => {
  const report = nativeReport();
  const first = normalizeReport(report, { seam: 'admin_behavior', invocation: 'behavior' });
  report.suites[0].specs.reverse();
  const replay = normalizeReport(report, { seam: 'admin_behavior', invocation: 'behavior' });

  assert.ok(Array.isArray(first.tests));
  assert.ok(Array.isArray(replay.tests));
  assert.deepEqual(replay.tests, first.tests);
});

test('rejects malformed, empty, truncated, duplicate and invalid-duration reports as incomplete', () => {
  const cases = [
    [null, 'report_invalid_shape'],
    [{ ...nativeReport(), suites: [] }, 'selected_count_mismatch'],
    [{ ...nativeReport(), stats: { ...nativeReport().stats, expected: 2 } }, 'selected_count_mismatch'],
    (() => {
      const report = nativeReport();
      report.suites[0].specs[0].tests[0].results.push(result(1, 'passed', 200));
      return [report, 'duplicate_result_identity'];
    })(),
    (() => {
      const report = nativeReport();
      report.suites[0].specs[0].tests[0].results[0].duration = -1;
      return [report, 'invalid_duration'];
    })(),
    (() => {
      const report = nativeReport();
      report.suites[0].specs[0].tests[0].results[0].status = undefined;
      return [report, 'invalid_result_status'];
    })(),
    (() => {
      const report = nativeReport();
      report.suites[0].specs[0].tests[0].projectName = 'mobile';
      return [report, 'project_identity_mismatch'];
    })(),
    (() => {
      const report = nativeReport();
      report.errors.push({ message: 'reporter interrupted before suite finish' });
      return [report, 'report_has_errors'];
    })(),
  ];

  for (const [report, reason] of cases) {
    const normalized = normalizeReport(report, { seam: 'admin_behavior', invocation: 'behavior' });
    assert.equal(normalized.complete, false, reason);
    assert.ok(Array.isArray(normalized.incomplete_reasons));
    assert.ok(normalized.incomplete_reasons.includes(reason), reason);
  }
});

test('CLI writes incomplete output atomically and retains a nonzero status for missing or malformed input', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'sigra-playwright-report-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const input = join(directory, 'missing.json');
  const output = join(directory, 'normalized.json');
  const args = ['--input', input, '--seam', 'admin_behavior', '--invocation', 'behavior', '--output', output];

  const missing = spawnSync(process.execPath, [cliPath.pathname, ...args], { encoding: 'utf8' });
  assert.notEqual(missing.status, 0);
  const missingOutput = JSON.parse(await readFile(output, 'utf8'));
  assert.equal(missingOutput.complete, false);
  assert.ok(missingOutput.incomplete_reasons.includes('input_unavailable'));
  assert.equal(missingOutput.reporter_overhead.overhead_ms, null);

  await writeFile(input, '{"suites":[', 'utf8');
  const malformed = spawnSync(process.execPath, [cliPath.pathname, ...args], { encoding: 'utf8' });
  assert.notEqual(malformed.status, 0);
  const malformedOutput = JSON.parse(await readFile(output, 'utf8'));
  assert.equal(malformedOutput.complete, false);
  assert.ok(malformedOutput.incomplete_reasons.includes('input_invalid_json'));
  await writeFile(input, JSON.stringify(nativeReport()), 'utf8');
  const valid = spawnSync(process.execPath, [cliPath.pathname, ...args], { encoding: 'utf8' });
  assert.equal(valid.status, 0, valid.stderr);
  assert.equal(JSON.parse(await readFile(output, 'utf8')).complete, true);
  assert.deepEqual((await readdir(directory)).sort(), ['missing.json', 'normalized.json']);
});

test('CLI keeps a write failure visible and does not publish a partial output', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'sigra-playwright-report-write-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const input = join(directory, 'report.json');
  const output = join(directory, 'missing-parent', 'normalized.json');
  await writeFile(input, JSON.stringify(nativeReport()), 'utf8');

  const result = spawnSync(process.execPath, [cliPath.pathname,
    '--input', input,
    '--seam', 'admin_behavior',
    '--invocation', 'behavior',
    '--output', output,
  ], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /output_write_failed/);
  await assert.rejects(readFile(output), { code: 'ENOENT' });
});

test('CLI refuses to overwrite its raw Playwright input with normalized output', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'sigra-playwright-report-input-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const input = join(directory, 'report.json');
  const raw = JSON.stringify(nativeReport());
  await writeFile(input, raw, 'utf8');

  const result = spawnSync(process.execPath, [cliPath.pathname,
    '--input', input,
    '--seam', 'admin_behavior',
    '--invocation', 'behavior',
    '--output', input,
  ], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /input_and_output_must_differ/);
  assert.equal(await readFile(input, 'utf8'), raw);
});
