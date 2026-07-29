// P10 (230-08-PLAN.md) — mechanical enforcement.
//
//   MUST NOT let a demotion made in this phase enter Phase 231 as an undocumented
//   baseline; every job or step this phase causes to skip on a PR is enumerated with its
//   condition, so a rotted gate is distinguishable from a correct one.
//
// Subject: .github/ci-skip-manifest.tsv (substitutable via GSD_PROHIB_SUBJECT).
// Secondary: .github/workflows/ci.yml.
//
// THIS IS THE HIGHEST-VALUE GUARD IN THE SET. It fails in BOTH directions: an
// event-gated construct that is missing from the manifest (an undocumented demotion), and
// a manifest row naming a construct ci.yml no longer has (a stale entry). Phase 231's
// GATE-03 and Phase 235's GATE-05 both consume this enumeration, so a drifted manifest
// silently corrupts two downstream phases.
//
// ANTI-VACUITY. ci.yml uses TWO syntaxes for the same predicate — bare
// (`if: github.event_name != 'pull_request'`) and wrapped
// (`if: ${{ !cancelled() && github.event_name != 'pull_request' && ... }}`) — and the form
// a naive regex drops is the tier-B STEP, the single most important entry. Everything below
// runs on normalized text, and the floors exist so that an extractor which matches nothing
// fails loudly instead of comparing an empty set to an empty set.

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  readSubject, readRepoFile, parseSkipManifest, stripYamlComments, jobBlocks, normalizeExpr,
} from './_lib.mjs';

const rows = parseSkipManifest(readSubject('.github/ci-skip-manifest.tsv'));
const ci = stripYamlComments(readRepoFile('.github/workflows/ci.yml'));
const blocks = jobBlocks(ci);
const NON_PR = /github\.event_name != 'pull_request'/;

test('the manifest parses to a populated, tiered enumeration', () => {
  assert.ok(rows.length >= 12, `manifest parsed ${rows.length} rows; expected at least 12.`);
  const counts = { A: 0, B: 0, C: 0 };
  for (const r of rows) counts[r.tier] = (counts[r.tier] ?? 0) + 1;
  assert.ok(counts.A >= 9, `tier A has ${counts.A} rows, expected >= 9 — the parse broke.`);
  assert.ok(counts.B >= 2, `tier B has ${counts.B} rows, expected >= 2 (the Phase 230 demotions).`);
  assert.ok(counts.C >= 5, `tier C has ${counts.C} rows, expected >= 5.`);
});

test('every manifest id resolves to a real construct in ci.yml', () => {
  for (const r of rows) {
    if (r.kind === 'job') {
      assert.ok(
        blocks.some(([id]) => id === r.id),
        `manifest row \`${r.id}\` (tier ${r.tier}) names a job that does not exist in ci.yml. ` +
          `A manifest that drifts into fiction is worse than none: GATE-03 and GATE-05 both ` +
          `read it as the authority on what a legitimate skip looks like.`,
      );
    } else {
      assert.ok(
        new RegExp(`^\\s+id: ${r.id}\\s*$`, 'm').test(ci),
        `manifest row \`${r.id}\` names a step id absent from ci.yml.`,
      );
    }
  }
});

test('every step row names a parent that is itself a manifest job row', () => {
  for (const r of rows.filter((x) => x.kind === 'step')) {
    assert.ok(
      rows.some((j) => j.kind === 'job' && j.id === r.parentJobId),
      `step row \`${r.id}\` has parent_job_id \`${r.parentJobId}\`, which has no kind=job row. ` +
        `The observer resolves a step's owning job through that row (the Actions API returns ` +
        `names, never ids), so an orphan row is an unresolvable lookup.`,
    );
  }
});

test('display_name matches the construct name ci.yml actually declares', () => {
  for (const r of rows) {
    const needle = r.kind === 'job'
      ? new RegExp(`^ {4}name: ${r.displayName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, 'm')
      : new RegExp(`name: ${r.displayName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, 'm');
    assert.ok(
      needle.test(ci),
      `manifest row \`${r.id}\` records display_name "${r.displayName}", which ci.yml does not ` +
        `declare. The observer looks constructs up BY NAME, so a drifted display_name makes it ` +
        `silently blind while the id-facing checks still pass.`,
    );
  }
});

test('no event-gated job in ci.yml is missing from the manifest', () => {
  const documented = new Set(rows.map((r) => r.id));
  const undocumented = [];
  for (const [id, block] of blocks) {
    const ifs = [...block.matchAll(/^ {4}if:[ \t]*(.+)$/gm)].map((m) => normalizeExpr(m[1]));
    if (ifs.some((e) => NON_PR.test(e)) && !documented.has(id)) undocumented.push(id);
  }
  assert.deepEqual(
    undocumented,
    [],
    `these jobs are gated off the pull_request lane but appear in no manifest row: ` +
      `${undocumented.join(', ')}. An undocumented demotion enters Phase 231 as a baseline ` +
      `nobody can distinguish from a rotted gate — ci-gate counts both as a pass.`,
  );
});

test('the lanes that must never be gated are absent from the manifest', () => {
  // The negative control. A guard with only positive assertions is not falsifiable.
  for (const id of ['fast_checks', 'library_tests', 'library_tests_shard']) {
    assert.ok(
      !rows.some((r) => r.id === id),
      `\`${id}\` appears in the skip manifest. It is documented as deliberately NEVER skipped; ` +
        `listing it as a legitimate skip inverts the very distinction this file exists to draw.`,
    );
  }
});
