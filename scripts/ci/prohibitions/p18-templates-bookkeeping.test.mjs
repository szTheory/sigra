// P18 (241-05) — prevent bookkeeping vocabulary leaking through priv/templates.
// The V3 matcher is deliberately wide. The raw total is reported on each run;
// the pair-keyed allowlist is the only disposition for the committed SVG false positive.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  allowlistedBookkeepingHit,
  assertCleanSurface,
  bookkeepingMatches,
  measurementReport,
  scanBookkeeping,
} from './_p18-lib.mjs';

test('tracked priv/templates/ contain no V3 bookkeeping vocabulary outside the allowlist', () => {
  const result = scanBookkeeping('priv-templates');
  console.log(measurementReport(result));
  assertCleanSurface(result, 'template bookkeeping vocabulary hit outside allowlist');
});

test('an allowlisted SVG token does not suppress a second bookkeeping token on its line', () => {
  const fixture = 'test/fixtures/prohibitions/p18-template-allowlist-shadow.ex';
  const text = readFileSync(fixture, 'utf8');
  const line = text.split('\n')[1];
  const allowlist = [{
    path: fixture,
    match: '373-12',
    index: 25,
    anchor: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0',
  }, {
    path: fixture,
    match: '373-12',
    index: 44,
    anchor: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0',
  }];
  const hits = bookkeepingMatches(line).map((hit) => ({
    path: fixture,
    line: 2,
    text: line,
    ...hit,
    allowlisted: allowlistedBookkeepingHit(fixture, line, hit, allowlist),
  }));
  const result = { outsideAllowlist: hits.filter((hit) => !hit.allowlisted).length, hits };

  assert.deepEqual(hits.map((hit) => [hit.match, hit.allowlisted]), [
    ['373-12', true],
    ['373-12', true],
    ['Phase 241', false],
  ]);
  assert.throws(
    () => assertCleanSurface(result, 'template bookkeeping vocabulary hit outside allowlist'),
    /Phase 241/,
  );
});
