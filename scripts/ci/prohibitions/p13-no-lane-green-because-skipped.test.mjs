// P13 (230-09-PLAN.md) — mechanical enforcement.
//
//   MUST NOT report a lane green on the basis that it was skipped; every demotion in this
//   phase is recorded together with the receiving lane observed executing the demoted work
//   with a non-zero test count.
//
// Subject: the phase evidence ledger (substitutable via GSD_PROHIB_SUBJECT).
// Secondary: .github/ci-skip-manifest.tsv — the enumeration of what was demoted.
//
// P3 is the same rule scoped to the gallery lane; this is the general form, driven off the
// manifest so a NEW demotion added later is automatically in scope rather than needing the
// guard to be remembered and edited.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, parseEvidenceSlots, parseSkipManifest } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const slots = parseEvidenceSlots(readSubject(LEDGER));
const captured = slots.filter((s) => s.captured);
const asserted = parseSkipManifest(readRepoFile('.github/ci-skip-manifest.tsv'))
  .filter((r) => r.observer === 'assert');

test('the manifest yields the demoted constructs this rule applies to', () => {
  assert.ok(
    asserted.length >= 2,
    `manifest yielded ${asserted.length} assert row(s); expected at least the two Phase 230 ` +
      `demotions — the parse broke, this is not a pass.`,
  );
});

test('every demoted construct appears in a captured observation slot', () => {
  for (const row of asserted) {
    const seen = captured.some((s) => s.text.includes(row.id));
    assert.ok(
      seen,
      `demoted construct \`${row.id}\` is named in the skip manifest but appears in no captured ` +
        `slot of the ledger. A demotion whose receiving lane was never observed is a lane ` +
        `reported green because it was skipped.`,
    );
  }
});

test('no demoted construct is recorded as skipped on the receiving lane', () => {
  for (const row of asserted) {
    for (const s of captured) {
      const skipped = new RegExp(`${row.id}\\s+skipped`).test(s.text);
      assert.ok(
        !skipped,
        `slot ${s.name} records \`${row.id}\` as skipped. The receiving lane is where the ` +
          `demoted work must actually execute; a skip there means the demotion rotted and the ` +
          `green means nothing (ci-gate counts a skip as a pass).`,
      );
    }
  }
});
