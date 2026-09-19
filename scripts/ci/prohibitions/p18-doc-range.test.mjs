// P18 (241-06) — prevent new planning-artifact references in HexDocs doc ranges.
//
// This is deliberately narrower than R1's ratchet. The hard-fail asks whether a
// token with zero historical occurrences has appeared; R1 asks whether the known
// historical bookkeeping total is shrinking. Conflating those questions would make
// either instrument dishonest. The list below was measured at execution HEAD: its
// alternatives each measured zero in lib/ doc ranges. Non-zero historical tokens
// (for example `Phase NNN` and `D-NN`) belong to R1, never this hard fail.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  docRangeScan,
  docRangeTotal,
  P18InstrumentFailure,
} from './_p18-lib.mjs';

const PARITY_MANIFEST_PATH = 'test/fixtures/prohibitions/p18-doc-range-parity.tsv';
const RATCHET_BASELINE_PATH = 'scripts/ci/prohibitions/p18-ratchet-baseline.tsv';

const HARD_FAIL_TOKENS = [
  ['planning directory', /\.planning\//g],
  ['plan artifact filename', /-PLAN\.md/g],
  ['summary artifact filename', /-SUMMARY\.md/g],
  ['todos directory', /\btodos\//g],
  ['lowercase phase identifier', /\bphase[-_]\d{1,3}\b/g],
  ['criterion identifier', /\bSC-\d\b/g],
  ['requirement identifier', /\bREQ-[A-Z0-9]/g],
];

function hardFailViolations(result) {
  const violations = [];
  for (const [label, pattern] of HARD_FAIL_TOKENS) {
    for (const [token, count] of result.tokenHits) {
      if (pattern.test(token)) violations.push(`${label}=${token} (${count})`);
      pattern.lastIndex = 0;
    }
  }
  return violations;
}

function parityRows() {
  const lines = readFileSync(PARITY_MANIFEST_PATH, 'utf8')
    .split('\n')
    .map((line) => line.replace(/\r$/, ''))
    .filter((line) => line !== '' && !line.startsWith('#'));
  const [header, ...rows] = lines;

  assert.equal(
    header,
    'subject\texpected_total_hits\treference',
    'P18 D-30 PARITY: manifest header must name subject, expected_total_hits, and reference',
  );

  return rows.map((row) => {
    const [subject, expectedTotalHits, reference] = row.split('\t');
    assert.ok(
      subject && /^\d+$/.test(expectedTotalHits ?? '') && reference,
      `P18 D-30 PARITY: malformed manifest row ${JSON.stringify(row)}`,
    );
    return { subject, expectedTotalHits: Number(expectedTotalHits), reference };
  });
}

function r1Baseline() {
  const row = readFileSync(RATCHET_BASELINE_PATH, 'utf8')
    .split('\n')
    .map((line) => line.replace(/\r$/, ''))
    .find((line) => line.startsWith('R1\t'));
  const [, baseline] = row?.split('\t') ?? [];

  assert.ok(
    /^\d+$/.test(baseline ?? ''),
    'P18 D-30 PARITY: R1 baseline row must contain a numeric baseline',
  );
  return Number(baseline);
}

test('tracked lib/ doc ranges contain no zero-at-HEAD planning-artifact tokens', () => {
  const result = docRangeScan('lib');
  assert.ok(
    result.docRanges > 0,
    'P18 INSTRUMENT FAILURE: doc-range walker found zero doc ranges — this is not a clean surface.',
  );

  const violations = hardFailViolations(result);

  console.log(
    `doc_ranges=${result.docRanges} total_hits=${result.totalHits} distinct_sites=${result.distinctSites} distinct_files=${result.distinctFiles}`,
  );
  assert.equal(
    violations.length,
    0,
    violations.length === 0
      ? ''
      : `P18 DIRTY SURFACE: doc-range planning artifact ${violations.join(', ')} in ${process.env.GSD_PROHIB_SUBJECT ?? 'lib/'}`,
  );
});

test('doc-range walker distinguishes an instrument failure from a dirty surface', () => {
  assert.ok(P18InstrumentFailure);
});

test('D-30 parity manifest pins every accepted and rejected fixture to Phase-237 totals', () => {
  const rows = parityRows();
  assert.equal(rows.length, 4, 'P18 D-30 PARITY: manifest must cover all four fixture subjects');
  const mismatches = [];

  for (const { subject, expectedTotalHits, reference } of rows) {
    const previousSubject = process.env.GSD_PROHIB_SUBJECT;
    process.env.GSD_PROHIB_SUBJECT = `test/fixtures/prohibitions/${subject}`;

    try {
      const result = docRangeScan('lib');
      if (result.totalHits !== expectedTotalHits) {
        mismatches.push(
          `${subject} expected ${expectedTotalHits} token hit(s) from ${reference}, got ${result.totalHits}`,
        );
      }
    } finally {
      if (previousSubject === undefined) delete process.env.GSD_PROHIB_SUBJECT;
      else process.env.GSD_PROHIB_SUBJECT = previousSubject;
    }
  }

  assert.deepEqual(mismatches, [], `P18 D-30 PARITY: ${mismatches.join('; ')}`);
});

test('D-30 parity compares the real doc-range total to the committed R1 baseline', () => {
  assert.equal(
    docRangeTotal('lib'),
    r1Baseline(),
    'P18 D-30 PARITY: real lib/ total must equal the R1 baseline row',
  );
});
