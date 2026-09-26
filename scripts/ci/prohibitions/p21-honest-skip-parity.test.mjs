// P21 (241-03-PLAN.md) — honest-skip documentation parity.
//
// Subject: MAINTAINING.md (substitutable via GSD_PROHIB_SUBJECT). The manifest and
// the delegated p10 guard are always read from their committed, real locations.
// This guard is offline and can be run on a plane: it makes no network call and
// needs neither `gh` nor a token.
//
// Legs 1–3 (id resolution, step-parent, and display-name parity) belong to
// p10-no-undocumented-demotion.test.mjs and are deliberately not duplicated here.
// That guard carries the `example_playwright_shard` matrix-name exception and the
// intervening comments before `install_smoke`'s name; duplicating either parser would
// create a second owner of the same assertion. The manifest `gate` column is likewise
// deliberately not parsed here: evaluating GHA expressions would turn this parity
// guard into a brittle YAML-expression evaluator.

import test from 'node:test';
import assert from 'node:assert/strict';
import { parseSkipManifest, readRepoFile, readSubject } from './_lib.mjs';

const MANIFEST_ROWS_FLOOR = 16;
const DELEGATED_P10_TESTS = [
  'every manifest id resolves to a real construct in ci.yml',
  'every step row names a parent that is itself a manifest job row',
  'display_name matches the construct name ci.yml actually declares',
];

const rows = parseSkipManifest(readRepoFile('.github/ci-skip-manifest.tsv'));
const maintaining = readSubject('MAINTAINING.md');
const p10 = readRepoFile('scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs');
const ACTIVE_IDS_START = '<!-- honest-skip-active-ids:start -->';
const ACTIVE_IDS_END = '<!-- honest-skip-active-ids:end -->';

function honestSkipSection(text) {
  const heading = /^### Honest-skip set after Phase 230[^\n]*$/m.exec(text);
  assert.ok(
    heading,
    'MAINTAINING.md has no honest-skip heading — the section locator broke, this is not a pass.',
  );
  const afterHeading = text.slice(heading.index + heading[0].length);
  const nextHeading = /^### /m.exec(afterHeading);
  const section = nextHeading ? afterHeading.slice(0, nextHeading.index) : afterHeading;
  assert.ok(
    section.trim().length > 0,
    'MAINTAINING.md honest-skip section is empty — the section locator broke, this is not a pass.',
  );
  return section;
}

function documentedActiveIds(section) {
  const start = section.indexOf(ACTIVE_IDS_START);
  const end = section.indexOf(ACTIVE_IDS_END);
  assert.ok(
    start >= 0 && end > start,
    'MAINTAINING.md has no delimited active honest-skip id list — the documentation inventory locator broke, this is not a pass.',
  );

  const entries = section.slice(start + ACTIVE_IDS_START.length, end)
    .split('\n')
    .map((line) => /^\s*-\s+`([^`]+)`\s*$/.exec(line))
    .filter(Boolean)
    .map((match) => match[1]);

  assert.ok(entries.length > 0, 'MAINTAINING.md active honest-skip id list is empty — this is not a pass.');
  assert.equal(
    new Set(entries).size,
    entries.length,
    'MAINTAINING.md active honest-skip id list has duplicate entries — it is not a reliable inventory.',
  );
  return new Set(entries);
}

function expectedActiveIds(rows) {
  return new Set(rows.flatMap((row) => row.kind === 'step' ? [row.id, row.parentJobId] : [row.id]));
}

const section = honestSkipSection(maintaining);
const documentedIds = documentedActiveIds(section);
const expectedIds = expectedActiveIds(rows);

test('the manifest and honest-skip section are non-vacuously available', () => {
  assert.ok(
    rows.length >= MANIFEST_ROWS_FLOOR,
    `manifest parsed ${rows.length} rows; expected at least ${MANIFEST_ROWS_FLOOR} — the parse broke, this is not a pass.`,
  );
  assert.ok(
    section.trim().length > 0,
    'honest-skip section is empty — the section locator broke, this is not a pass.',
  );
});

test('the active honest-skip inventory exactly matches manifest ids and required step parents', () => {
  const missing = [...expectedIds].filter((id) => !documentedIds.has(id));
  const stale = [...documentedIds].filter((id) => !expectedIds.has(id));

  assert.deepEqual(
    missing,
    [],
    `MAINTAINING.md active honest-skip ids omit manifest ids or required step parents: ${missing.join(', ')}`,
  );
  assert.deepEqual(
    stale,
    [],
    `MAINTAINING.md documents stale active honest-skip ids absent from the manifest: ${stale.join(', ')}`,
  );
});

test('p10 continues to own the three delegated ci.yml parity legs', () => {
  for (const delegatedTest of DELEGATED_P10_TESTS) {
    assert.ok(
      p10.includes(delegatedTest),
      `p10-no-undocumented-demotion.test.mjs no longer declares \`${delegatedTest}\`. The three legs this guard does not implement are owned there, and their disappearance is a failure of this guard.`,
    );
  }
});
