// P18 (241-05) — prevent bookkeeping vocabulary leaking through priv/templates.
// The V3 matcher is deliberately wide. The raw total is reported on each run;
// the pair-keyed allowlist is the only disposition for the committed SVG false positive.

import test from 'node:test';

import {
  assertCleanSurface,
  measurementReport,
  scanBookkeeping,
} from './_p18-lib.mjs';

test('tracked priv/templates/ contain no V3 bookkeeping vocabulary outside the allowlist', () => {
  const result = scanBookkeeping('priv-templates');
  console.log(measurementReport(result));
  assertCleanSurface(result, 'template bookkeeping vocabulary hit outside allowlist');
});
