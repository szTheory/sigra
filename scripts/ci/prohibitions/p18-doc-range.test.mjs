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

import {
  docRangeScan,
  P18InstrumentFailure,
} from './_p18-lib.mjs';

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

test('lowercase string sigil doc ranges are scanned for hard-fail tokens', () => {
  const fixture = 'test/fixtures/prohibitions/p18-doc-range-lowercase-sigil.ex';
  const previousSubject = process.env.GSD_PROHIB_SUBJECT;
  process.env.GSD_PROHIB_SUBJECT = fixture;

  try {
    const result = docRangeScan('lib');
    assert.equal(result.docRanges, 2, 'fixture must include normal and lowercase-sigil doc ranges');
    assert.deepEqual(hardFailViolations(result), ['planning directory=.planning/ (1)']);
  } finally {
    if (previousSubject === undefined) delete process.env.GSD_PROHIB_SUBJECT;
    else process.env.GSD_PROHIB_SUBJECT = previousSubject;
  }
});
