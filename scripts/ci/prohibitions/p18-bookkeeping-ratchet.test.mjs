// P18 (241-06) — independent monotonic-decrease bookkeeping counters.
// Each counter owns a different surface and vocabulary. Do not fuse them: a
// decrease in one surface cannot pay for an increase in another. Zero is not
// a target; these tests enforce only non-increase against committed baselines.

import { execFileSync } from 'node:child_process';
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  BOOKKEEPING_V3_RE,
  docRangeScan,
  P18InstrumentFailure,
} from './_p18-lib.mjs';
import { REPO_ROOT } from './_lib.mjs';

const DEFAULT_BASELINE = 'scripts/ci/prohibitions/p18-ratchet-baseline.tsv';
const EXPECTED_COUNTERS = ['R1', 'R2', 'R3'];

function baselinePath() {
  // Resolve at call time. A module-load read would silently ignore a fixture
  // override in a warm test process and make the independent RED proof false.
  return process.env.GSD_P18_BASELINE || DEFAULT_BASELINE;
}

function loadBaselines() {
  const relPath = baselinePath();
  const path = resolve(REPO_ROOT, relPath);
  if (!existsSync(path)) {
    throw new P18InstrumentFailure(
      `baseline not found at ${path} — a missing baseline is a broken run, never a clean pass`,
    );
  }

  const rows = readFileSync(path, 'utf8')
    .split('\n')
    .map((line) => line.replace(/\r$/, ''))
    .filter((line) => line !== '' && !line.startsWith('#'));
  if (rows.shift() !== 'counter\tbaseline\tsurface') {
    throw new P18InstrumentFailure(`malformed baseline header in ${relPath}`);
  }

  const baselines = new Map();
  for (const row of rows) {
    const [counter, rawBaseline, surface] = row.split('\t');
    if (!counter || !/^(0|[1-9]\d*)$/.test(rawBaseline ?? '') || !surface) {
      throw new P18InstrumentFailure(`malformed baseline row in ${relPath}: ${row}`);
    }
    if (baselines.has(counter)) {
      throw new P18InstrumentFailure(`duplicate baseline counter ${counter} in ${relPath}`);
    }
    baselines.set(counter, Number(rawBaseline));
  }
  if (baselines.size !== EXPECTED_COUNTERS.length || EXPECTED_COUNTERS.some((id) => !baselines.has(id))) {
    throw new P18InstrumentFailure(`baseline must contain exactly ${EXPECTED_COUNTERS.join(', ')} in ${relPath}`);
  }
  return baselines;
}

function trackedLibFiles() {
  const stdout = execFileSync('git', ['ls-files', 'lib/*.ex', 'lib/*.exs'], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  });
  const files = stdout.split('\n').filter(Boolean);
  if (files.length === 0) {
    throw new P18InstrumentFailure('R2 found no tracked lib Elixir files — refusing to report success on no input');
  }
  return files;
}

function r2CommentLineTotal() {
  let commentLines = 0;
  let matchedLines = 0;
  for (const path of trackedLibFiles()) {
    for (const line of readFileSync(resolve(REPO_ROOT, path), 'utf8').split('\n')) {
      if (!/^\s*#/.test(line)) continue;
      commentLines += 1;
      if (BOOKKEEPING_V3_RE.test(line)) matchedLines += 1;
    }
  }
  if (commentLines === 0) {
    throw new P18InstrumentFailure('R2 found zero comment-only lines — this is not a measurable comment surface');
  }
  return matchedLines;
}

function packagedDocsFiles() {
  const stdout = execFileSync('git', ['ls-files', 'docs', 'README.md', 'CHANGELOG.md'], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  });
  const files = stdout.split('\n').filter(Boolean);
  if (files.length === 0) {
    throw new P18InstrumentFailure('R3 found no packaged-docs files — refusing to report success on no input');
  }
  return files;
}

function r3PlanningPathTotal() {
  let total = 0;
  for (const path of packagedDocsFiles()) {
    total += [...readFileSync(resolve(REPO_ROOT, path), 'utf8').matchAll(/\.planning\//g)].length;
  }
  return total;
}

function assertNotIncreased(counter, measured) {
  const baseline = loadBaselines().get(counter);
  console.log(`${counter} measured=${measured} baseline=${baseline} pass=decrease-or-equal zero-is-not-the-target`);
  assert.ok(
    measured <= baseline,
    `P18 RATCHET REGRESSION ${counter}: measured=${measured} exceeds baseline=${baseline}; ` +
      'zero is explicitly not the target, but an increase is a regression.',
  );
}

test('R1: narrower Phase-237 vocabulary in lib doc ranges does not increase', () => {
  const result = docRangeScan('lib');
  assert.ok(
    result.docRanges > 0,
    'P18 INSTRUMENT FAILURE: R1 found zero doc ranges — this is not a clean surface.',
  );
  assertNotIncreased('R1', result.totalHits);
});

test('R2: wide Phase-239 V3 vocabulary in lib comment-only lines does not increase', () => {
  assertNotIncreased('R2', r2CommentLineTotal());
});

test('R3: literal .planning/ occurrences in packaged docs do not increase', () => {
  assertNotIncreased('R3', r3PlanningPathTotal());
});
