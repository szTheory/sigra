// P18 (241-05) — prevent literal .planning/ paths leaking into shipped source.
// The planning-path class is deliberately narrower than the V3 bookkeeping
// vocabulary used by its sibling: D-23 keeps HexDocs traceability prose out of scope.

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  measurementReport,
  scanBookkeeping,
} from './_p18-lib.mjs';

test('tracked lib/ and priv/templates/ contain no literal .planning/ path', () => {
  const result = scanBookkeeping('planning-paths', { pattern: /\.planning\// });
  console.log(measurementReport(result));

  const planningPathHits = result.hits.filter((hit) => hit.text.includes('.planning/'));
  assert.equal(
    planningPathHits.length,
    0,
    planningPathHits.length === 0
      ? ''
      : `P18 DIRTY SURFACE: planning-directory literal .planning/ at ${planningPathHits[0].path}:${planningPathHits[0].line} ${planningPathHits[0].text}`,
  );
});
