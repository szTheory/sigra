import test from 'node:test';

import assert from 'node:assert/strict';

import { docRangeMeasurement } from './_p18-lib.mjs';

// Hard-fail only the doc-range alternatives measured at zero at this HEAD:
// planning paths, PLAN/SUMMARY filenames, todos/, lowercase phase IDs, SC/REQ/INV
// identifiers. At this HEAD, capitalized "Phase N" has 67 hits, D-NN has 259,
// Pitfall N has 10, and -CONTEXT.md has 1; all stay on R1's ratchet. The other
// alternatives in the committed Phase 237 token set measure zero here.
// The hard-fail asks whether a planning artifact appeared where none existed;
// R1 asks whether historical bookkeeping is shrinking. They are distinct
// instruments over one HexDocs-rendered surface.
const HARD_FAIL_SOURCE = String.raw`\.planning/|-PLAN\.md|-SUMMARY\.md|\btodos/\b|\bphase[-_]\d{1,3}\b|\bSC-\d\b|\bREQ-[A-Z0-9]|\bINV-\d`;

test('p18 hard-fails planning artifacts inside HexDocs-rendered doc ranges', () => {
  const result = docRangeMeasurement('lib', HARD_FAIL_SOURCE);
  assert.ok(result.filesMeasured > 0, 'doc-range file list is empty — instrument failure');
  assert.ok(result.ranges > 0, 'doc-range walker found zero doc attributes — instrument failure');
  console.log(`doc_ranges=${result.ranges} files=${result.filesMeasured} hard_fail_hits=${result.total}`);
  assert.equal(result.total, 0, `planning artifact hits inside HexDocs doc ranges: ${result.hits.join('; ')}`);
});
