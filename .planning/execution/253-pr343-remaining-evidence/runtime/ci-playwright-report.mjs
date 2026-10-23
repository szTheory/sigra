#!/usr/bin/env node

import { randomUUID } from 'node:crypto';
import { open, readFile, rename, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const RESULT_STATUSES = new Set(['passed', 'failed', 'timedOut', 'skipped', 'interrupted']);
const TEST_SUMMARY_STATUSES = new Set(['skipped', 'expected', 'unexpected', 'flaky']);
const EXPECTED_STATUSES = RESULT_STATUSES;

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function nonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function validDate(value) {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}

function safePath(value) {
  return value.replaceAll('\\', '/');
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function makeBase({ seam, invocation }) {
  return {
    schema_version: 1,
    source_format: 'playwright-json',
    report_format_contract: 'playwright-json-1.59.1',
    seam,
    invocation,
    unit: 'ms',
    tests: [],
    selected_count: null,
    skipped_count: null,
    excluded_count: null,
    excluded_count_reason: 'native_json_does_not_include_excluded_cases',
    suite_started_at: null,
    suite_elapsed_ms: null,
    sum_test_duration_ms: null,
    complete: false,
    incomplete_reasons: [],
    reporter_overhead: {
      status: 'unmeasured',
      overhead_ms: null,
      unit: 'ms',
      reason: 'paired_same_selection_runs_not_recorded',
    },
  };
}

function addReason(reasons, reason) {
  if (!reasons.includes(reason)) reasons.push(reason);
}

/** Validate and normalize a native Playwright 1.59.1 JSON report. */
export function normalizeReport(report, identity) {
  const normalized = makeBase(identity ?? {});
  const reasons = normalized.incomplete_reasons;

  if (!nonEmptyString(normalized.seam) || !nonEmptyString(normalized.invocation)) {
    addReason(reasons, 'invocation_identity_missing');
  }
  if (!isRecord(report) || !isRecord(report.config) || !Array.isArray(report.config.projects)
    || !Array.isArray(report.suites) || !Array.isArray(report.errors) || !isRecord(report.stats)) {
    addReason(reasons, 'report_invalid_shape');
    return normalized;
  }

  const projects = new Map();
  for (const project of report.config.projects) {
    if (!isRecord(project) || !nonEmptyString(project.id) || !nonEmptyString(project.name)
      || projects.has(project.id) || [...projects.values()].some((existing) => existing.name === project.name)) {
      addReason(reasons, 'project_identity_invalid');
      continue;
    }
    projects.set(project.id, { id: project.id, name: project.name });
  }

  const stats = report.stats;
  const statsCounts = ['expected', 'unexpected', 'flaky', 'skipped'];
  if (!validDate(stats.startTime) || !Number.isFinite(stats.duration) || stats.duration < 0
    || statsCounts.some((key) => !Number.isInteger(stats[key]) || stats[key] < 0)) {
    addReason(reasons, 'report_stats_invalid');
  } else {
    normalized.suite_started_at = stats.startTime;
    normalized.suite_elapsed_ms = stats.duration;
    normalized.skipped_count = stats.skipped;
  }
  if (report.errors.length > 0) addReason(reasons, 'report_has_errors');

  const identities = new Set();
  let selectedCount = 0;
  const observedSummaryCounts = { expected: 0, unexpected: 0, flaky: 0, skipped: 0 };

  function visitSuites(suites, ancestors = []) {
    if (!Array.isArray(suites)) {
      addReason(reasons, 'suite_invalid_shape');
      return;
    }
    for (const suite of suites) {
      if (!isRecord(suite) || !nonEmptyString(suite.title) || !nonEmptyString(suite.file)
        || !Array.isArray(suite.specs) || (suite.suites !== undefined && !Array.isArray(suite.suites))) {
        addReason(reasons, 'suite_invalid_shape');
        continue;
      }
      const suitePath = [...ancestors, suite.title];
      for (const spec of suite.specs) {
        if (!isRecord(spec) || !nonEmptyString(spec.id) || !nonEmptyString(spec.title)
          || !nonEmptyString(spec.file) || !Array.isArray(spec.tests)) {
          addReason(reasons, 'spec_invalid_shape');
          continue;
        }
        for (const selectedTest of spec.tests) {
          selectedCount += 1;
          if (!isRecord(selectedTest) || !nonEmptyString(selectedTest.projectId)
            || !nonEmptyString(selectedTest.projectName) || !EXPECTED_STATUSES.has(selectedTest.expectedStatus)
            || !TEST_SUMMARY_STATUSES.has(selectedTest.status) || !Array.isArray(selectedTest.results)) {
            addReason(reasons, 'selected_result_missing_or_invalid');
            continue;
          }
          const project = projects.get(selectedTest.projectId);
          if (!project || project.name !== selectedTest.projectName) addReason(reasons, 'project_identity_mismatch');
          const testId = JSON.stringify([
            selectedTest.projectId,
            safePath(spec.file),
            suitePath,
            spec.id,
            spec.title,
          ]);

          if (selectedTest.results.length === 0) {
            if (selectedTest.status !== 'skipped' || selectedTest.expectedStatus !== 'skipped') {
              addReason(reasons, 'selected_result_missing_or_invalid');
              continue;
            }
            const key = `${testId}\u0000unreported`;
            if (identities.has(key)) addReason(reasons, 'duplicate_result_identity');
            identities.add(key);
            normalized.tests.push({
              test_id: testId,
              project: selectedTest.projectName,
              project_id: selectedTest.projectId,
              seam: normalized.seam,
              invocation: normalized.invocation,
              spec_file: safePath(spec.file),
              suite_path: suitePath,
              title: spec.title,
              retry: null,
              result: 'skipped',
              duration_ms: null,
              unit: 'ms',
              start_time: null,
            });
            observedSummaryCounts.skipped += 1;
            continue;
          }

          for (const result of selectedTest.results) {
            if (!isRecord(result) || !Number.isInteger(result.retry) || result.retry < 0
              || !RESULT_STATUSES.has(result.status) || !Number.isFinite(result.duration) || result.duration < 0
              || !validDate(result.startTime)) {
              addReason(reasons, !isRecord(result) || !Number.isFinite(result?.duration) || result?.duration < 0
                ? 'invalid_duration'
                : !isRecord(result) || !RESULT_STATUSES.has(result?.status)
                  ? 'invalid_result_status'
                  : 'result_identity_or_start_time_invalid');
              continue;
            }
            const key = `${testId}\u0000${result.retry}`;
            if (identities.has(key)) addReason(reasons, 'duplicate_result_identity');
            identities.add(key);
            normalized.tests.push({
              test_id: testId,
              project: selectedTest.projectName,
              project_id: selectedTest.projectId,
              seam: normalized.seam,
              invocation: normalized.invocation,
              spec_file: safePath(spec.file),
              suite_path: suitePath,
              title: spec.title,
              retry: result.retry,
              result: result.status,
              duration_ms: result.duration,
              unit: 'ms',
              start_time: result.startTime,
            });
          }

          switch (selectedTest.status) {
            case 'expected': observedSummaryCounts.expected += 1; break;
            case 'unexpected': observedSummaryCounts.unexpected += 1; break;
            case 'flaky': observedSummaryCounts.flaky += 1; break;
            case 'skipped': observedSummaryCounts.skipped += 1; break;
          }
        }
      }
      if (suite.suites) visitSuites(suite.suites, suitePath);
    }
  }

  visitSuites(report.suites);
  normalized.selected_count = selectedCount;
  if (selectedCount === 0) addReason(reasons, 'selected_results_missing');
  if (statsCounts.every((key) => Number.isInteger(stats[key]) && stats[key] >= 0)
    && statsCounts.some((key) => observedSummaryCounts[key] !== stats[key])) {
    addReason(reasons, 'selected_count_mismatch');
  }

  normalized.tests.sort((left, right) => compareText(left.test_id, right.test_id)
    || (left.retry ?? -1) - (right.retry ?? -1) || compareText(left.result, right.result));
  normalized.complete = reasons.length === 0;
  if (normalized.complete) {
    normalized.sum_test_duration_ms = normalized.tests.reduce((sum, row) => sum + (row.duration_ms ?? 0), 0);
  }
  return normalized;
}

async function writeAtomically(outputPath, content) {
  const destination = resolve(outputPath);
  const temporary = `${destination}.tmp-${process.pid}-${randomUUID()}`;
  let handle;
  try {
    handle = await open(temporary, 'wx', 0o600);
    await handle.writeFile(content, 'utf8');
    await handle.sync();
    await handle.close();
    handle = undefined;
    await rename(temporary, destination);
  } catch (error) {
    if (handle) await handle.close().catch(() => {});
    await unlink(temporary).catch(() => {});
    throw error;
  }
}

function parseArgs(args) {
  const parsed = {};
  for (let index = 0; index < args.length; index += 1) {
    const flag = args[index];
    if (!['--input', '--seam', '--invocation', '--output'].includes(flag)) {
      throw new Error(`unknown argument: ${flag}`);
    }
    if (parsed[flag] !== undefined || !args[index + 1] || args[index + 1].startsWith('--')) {
      throw new Error(`missing or duplicate value for ${flag}`);
    }
    parsed[flag] = args[index + 1];
    index += 1;
  }
  for (const flag of ['--input', '--seam', '--invocation', '--output']) {
    if (!nonEmptyString(parsed[flag])) throw new Error(`required argument missing: ${flag}`);
  }
  const options = {
    input: parsed['--input'],
    seam: parsed['--seam'],
    invocation: parsed['--invocation'],
    output: parsed['--output'],
  };
  if (resolve(options.input) === resolve(options.output)) {
    throw new Error('input_and_output_must_differ');
  }
  return options;
}

async function runCli(args) {
  const options = parseArgs(args);
  let report;
  let inputError;
  try {
    const input = await readFile(options.input, 'utf8');
    try {
      report = JSON.parse(input);
    } catch {
      inputError = 'input_invalid_json';
    }
  } catch (error) {
    inputError = 'input_unavailable';
  }

  const normalized = inputError
    ? makeBase(options)
    : normalizeReport(report, options);
  if (inputError) addReason(normalized.incomplete_reasons, inputError);
  try {
    await writeAtomically(options.output, `${JSON.stringify(normalized, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`ci-playwright-report: output_write_failed: ${error.message}\n`);
    return 2;
  }
  if (!normalized.complete) {
    process.stderr.write(`ci-playwright-report: incomplete report: ${normalized.incomplete_reasons.join(', ')}\n`);
    return 2;
  }
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  runCli(process.argv.slice(2)).then((status) => {
    process.exitCode = status;
  }).catch((error) => {
    process.stderr.write(`ci-playwright-report: ${error.message}\n`);
    process.exitCode = 2;
  });
}
