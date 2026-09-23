// P21 (241-03-PLAN.md) — MAINTAINING.md parity leg for the honest-skip set.
//
// Subject: MAINTAINING.md (substitutable via GSD_PROHIB_SUBJECT). The manifest and
// p10 are secondary artifacts and are always read from their real locations. This
// guard is offline and runnable on a plane: it makes no network call and needs no
// token. Legs 1-3 (id resolution, step-parent, and display-name parity) deliberately
// belong to p10-no-undocumented-demotion.test.mjs rather than being duplicated here;
// p10 carries the example_playwright_shard matrix.seam display-name exception and
// tolerates comments between install_smoke's job key and name. The gate column is
// deliberately not parsed: turning this into a YAML-expression evaluator would rot on
// every unrelated ci.yml edit.

import test from 'node:test';
import assert from 'node:assert/strict';
import { parseSkipManifest, readRepoFile, readSubject } from './_lib.mjs';

const MANIFEST = '.github/ci-skip-manifest.tsv';
const P10 = 'scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs';
const rows = parseSkipManifest(readRepoFile(MANIFEST));
const maintaining = readSubject('MAINTAINING.md');

function honestSkipSection(text) {
  const match = text.match(
    /^### Honest-skip set after Phase 230[\s\S]*?(?=^#### Accepted residuals introduced by Phase 230|\z)/m,
  );
  return match?.[0] ?? '';
}

const section = honestSkipSection(maintaining);

test('the manifest and honest-skip section parse to non-vacuous inputs', () => {
  assert.ok(
    rows.length >= 15,
    `manifest parsed ${rows.length} rows, expected at least 15 — the parse broke, this is not a pass.`,
  );
  assert.ok(
    section.length > 0,
    'MAINTAINING.md honest-skip section was not located or is empty — the parse broke, this is not a pass.',
  );
});

test('every manifest id and step parent is documented in the honest-skip section', () => {
  const missing = [];
  for (const row of rows) {
    if (!section.includes(row.id)) {
      missing.push(`manifest row kind=${row.kind} id=${row.id} is missing from MAINTAINING.md's honest-skip section.`);
    }
    if (row.kind === 'step') {
      if (!section.includes(row.parentJobId)) {
        missing.push(
          `manifest row kind=step id=${row.id} has parent_job_id=${row.parentJobId}, which is missing from MAINTAINING.md's honest-skip section.`,
        );
      }
    }
  }
  assert.equal(missing.length, 0, missing.join('\n'));
});

test('p10 retains ownership of the three ci.yml parity legs delegated by p21', () => {
  const p10 = readRepoFile(P10);
  for (const delegatedTest of [
    'every manifest id resolves to a real construct in ci.yml',
    'every step row names a parent that is itself a manifest job row',
    'display_name matches the construct name ci.yml actually declares',
  ]) {
    assert.ok(
      p10.includes(delegatedTest),
      `p10 must retain delegated leg "${delegatedTest}"; the three legs p21 does not implement are owned there, and their disappearance is a failure of this guard.`,
    );
  }
});
