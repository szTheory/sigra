// P3 (230-03-PLAN.md) — mechanical enforcement.
//
//   MUST NOT report the design-gallery lane green on the basis that a step was skipped or
//   that a grep matched nothing; a demotion is honest only when the receiving lane is
//   observed executing the demoted work with a non-zero test count.
//
// Subject: the phase evidence ledger (substitutable via GSD_PROHIB_SUBJECT).
//
// This is the ledger half. The RUNTIME half is permanent and lives in
// scripts/ci/ci-demotion-observer.sh, which fail-closes when the gallery snapshot step
// reports `skipped` or a zero duration on a non-pull_request run — so this clause is
// enforced both on the record and on every future run.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, parseEvidenceSlots } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const slots = parseEvidenceSlots(readSubject(LEDGER));
const captured = slots.filter((s) => s.captured);

test('captured slots exist for the receiving lane to be observed in', () => {
  assert.ok(
    captured.length >= 3,
    `only ${captured.length} captured slot(s) — the parse broke, this is not a pass.`,
  );
});

test('the gallery snapshot lane is observed executing, not skipped', () => {
  const mentioning = captured.filter((s) => /design_gallery_snapshots/.test(s.text));
  assert.ok(
    mentioning.length >= 1,
    'no captured slot mentions design_gallery_snapshots. The demoted work must be observed on ' +
      'the lane that received it, or the demotion is unproven.',
  );
  // Format-tolerant on purpose: the ledger records this as prose ("executes 84 tests:
  // `Running 84 tests using 1 worker` … `84 passed`"), not as a fixed table column. Keying on
  // one layout would red the shipped ledger while proving nothing about the claim.
  const executed = mentioning.some((s) =>
    [...s.text.matchAll(/\b(\d+)\s+(?:passed|tests)\b/g)].some((m) => Number(m[1]) > 0),
  );
  assert.ok(
    executed,
    'a captured slot names design_gallery_snapshots but records no non-zero executed test count ' +
      'anywhere in that slot. A lane reported green because its step was skipped — or because a ' +
      '--grep matched nothing — has asserted nothing at all.',
  );

  const skippedNearby = mentioning.some((s) =>
    /design_gallery_snapshots[\s\S]{0,120}?\bskipped\b/.test(s.text),
  );
  assert.ok(
    !skippedNearby,
    'a captured slot records design_gallery_snapshots as skipped on the receiving lane. That is ' +
      'the demotion rotting: the work left the PR lane and never arrived anywhere.',
  );
});

test('a non-zero executed test count is on the record for the demoted work', () => {
  const counts = captured
    .flatMap((s) => [...s.text.matchAll(/\b(\d+)\s+passed\b/g)])
    .map((m) => Number(m[1]));
  assert.ok(
    counts.length >= 1,
    'no captured slot records an executed test count (`N passed`). "The step ran" is not the ' +
      'claim; "the step ran the tests" is.',
  );
  assert.ok(
    counts.some((n) => n > 0),
    `every recorded test count is zero (${counts.join(', ')}). A grep that matched nothing ` +
      `reports success — that is the precise failure this prohibition names.`,
  );
});
