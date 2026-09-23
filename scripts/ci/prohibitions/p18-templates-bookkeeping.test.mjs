import test from 'node:test';

import {
  BOOKKEEPING_REGEX_SOURCE,
  assertClean,
  reportScan,
  scanP18,
} from './_p18-lib.mjs';

test('p18 rejects bookkeeping vocabulary from priv/templates', () => {
  const result = scanP18({
    tier: 'priv-templates',
    vocabularySource: BOOKKEEPING_REGEX_SOURCE,
  });
  reportScan(result);
  assertClean(result, 'templates bookkeeping vocabulary');
});
