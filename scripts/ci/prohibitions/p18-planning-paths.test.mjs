import test from 'node:test';

import {
  PLANNING_PATH_REGEX_SOURCE,
  assertClean,
  reportScan,
  scanP18,
} from './_p18-lib.mjs';

test('p18 rejects planning-directory paths from the adopter surface', () => {
  const result = scanP18({
    tier: 'adopter-surface',
    vocabularySource: PLANNING_PATH_REGEX_SOURCE,
  });
  reportScan(result);
  assertClean(result, 'planning-directory path');
});
