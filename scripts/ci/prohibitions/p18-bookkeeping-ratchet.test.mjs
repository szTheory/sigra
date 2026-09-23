import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { REPO_ROOT } from './_lib.mjs';
import {
  docRangeTotal,
  libraryCommentBookkeepingLines,
  packagedPlanningPathOccurrences,
} from './_p18-lib.mjs';

function readBaseline(counter) {
  const path = process.env.GSD_P18_BASELINE || 'scripts/ci/prohibitions/p18-ratchet-baseline.tsv';
  const absolute = resolve(REPO_ROOT, path);
  let text;
  try {
    text = readFileSync(absolute, 'utf8');
  } catch {
    throw new Error(`INSTRUMENT FAILURE: cannot read baseline at ${absolute}`);
  }
  const row = text.split('\n').find((line) => line.startsWith(`${counter}\t`));
  if (!row) throw new Error(`INSTRUMENT FAILURE: missing ${counter} baseline row in ${absolute}`);
  const [, raw] = row.split('\t');
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`INSTRUMENT FAILURE: invalid ${counter} baseline value ${JSON.stringify(raw)}`);
  }
  return value;
}

function assertRatchet(counter, measured, baseline) {
  console.log(`${counter} measured=${measured} baseline=${baseline}`);
  assert.ok(
    measured <= baseline,
    `${counter} increased from ${baseline} to ${measured}; this is a monotonic-decrease ratchet, and zero is not the target`,
  );
}

test('R1 lib doc-range bookkeeping does not increase', () => {
  assertRatchet('R1', docRangeTotal('lib'), readBaseline('R1'));
});

test('R2 lib comment-only bookkeeping lines do not increase', () => {
  assertRatchet('R2', libraryCommentBookkeepingLines(), readBaseline('R2'));
});

test('R3 packaged-doc planning-path occurrences do not increase', () => {
  assertRatchet('R3', packagedPlanningPathOccurrences(), readBaseline('R3'));
});
