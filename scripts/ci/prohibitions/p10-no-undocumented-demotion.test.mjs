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
  jobLevelIfs,
} from './_lib.mjs';

const rows = parseSkipManifest(readSubject('.github/ci-skip-manifest.tsv'));
const ci = stripYamlComments(readRepoFile('.github/workflows/ci.yml'));
const blocks = jobBlocks(ci);
const NON_PR = /github\.event_name != 'pull_request'/;

/**
 * Locate a STEP's own `if:` expression by its `id:` line, scoped to the text
 * before the next step boundary (` {6}- name:`) or the end of the block.
 * `ci` has already had its comments stripped before this runs, so no
 * comment prose sits between a step's `id:` and its `if:` line.
 */
function stepIf(blockText, stepId) {
  const idMatch = new RegExp(`^ {8}id: ${stepId}\\s*$`, 'm').exec(blockText);
  if (!idMatch) return null;
  const rest = blockText.slice(idMatch.index);
  const boundary = /\n {6}- name:/.exec(rest.slice(1));
  const scope = boundary ? rest.slice(0, boundary.index + 1) : rest;
  const ifMatch = /^ {8}if:[ \t]*(.+)$/m.exec(scope);
  return ifMatch ? normalizeExpr(ifMatch[1]) : null;
}

test('the manifest parses to a populated, tiered enumeration', () => {
  assert.ok(
    rows.length >= 11,
    `manifest parsed ${rows.length} rows; expected at least 11. Phase 231 GATE-02 / D-06 ` +
      'deleted the `generated_admin_playwright_smoke` row (tier A): that job no longer ' +
      'declares a gate at all, so it can no longer skip and does not belong in an ' +
      'honest-skip enumeration -- the prior floor of 12 moved down by exactly the one row removed.',
  );
  const counts = { A: 0, B: 0, C: 0 };
  for (const r of rows) counts[r.tier] = (counts[r.tier] ?? 0) + 1;
  assert.ok(
    counts.A >= 8,
    `tier A has ${counts.A} rows, expected >= 8 — the parse broke. Phase 231 GATE-02 / D-06 ` +
      'removed `generated_admin_playwright_smoke` from tier A because its stale ' +
      "`github.head_ref == 'ship/v1.42-ci-gate-remediation'` condition was deleted from " +
      'ci.yml outright (not replaced), dropping the prior floor of 9 by exactly that one row.',
  );
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

test('gate column matches the if: expression ci.yml actually declares (Phase 231 GATE-02 / GATE-03)', () => {
  // The check that would have caught GATE-02's own defect: a manifest row
  // whose recorded `gate` disagrees with the real `if:` ci.yml declares is a
  // condition that reads plausibly and verifies nothing. This is the first
  // test in the suite that makes the manifest's `gate` column load-bearing.
  let checked = 0;
  for (const r of rows) {
    if (r.kind === 'job' && r.gateLevel === 'step') {
      // The four ruleset-required tier-C lanes (example_unit_smoke,
      // install_smoke, example_http_smoke, example_playwright_smoke) record
      // a step-level docs-only gate under a JOB id; the manifest carries no
      // step id for these rows to resolve which inner step unambiguously.
      // No direct if:-vs-gate comparison is attempted for them here -- the
      // rotted-gate-string check below still applies to their gate text.
      continue;
    }
    let actual;
    if (r.kind === 'job') {
      const block = blocks.find(([id]) => id === r.id);
      assert.ok(
        block,
        `manifest row \`${r.id}\` names a job ci.yml does not have — the parse broke, this is not a pass.`,
      );
      const ifs = jobLevelIfs(block[1]);
      assert.equal(
        ifs.length,
        1,
        `job \`${r.id}\` declares ${ifs.length} job-level if: lines; expected exactly 1 to ` +
          "compare against the manifest's gate column — the parse broke, this is not a pass.",
      );
      [actual] = ifs;
    } else {
      const parentBlock = blocks.find(([id]) => id === r.parentJobId);
      assert.ok(
        parentBlock,
        `step row \`${r.id}\`'s parent_job_id \`${r.parentJobId}\` was not found in ci.yml.`,
      );
      actual = stepIf(parentBlock[1], r.id);
      assert.ok(
        actual,
        `step row \`${r.id}\` has no if: line ci.yml can resolve near its id: — the parse broke, this is not a pass.`,
      );
    }
    checked += 1;
    assert.equal(
      actual,
      normalizeExpr(r.gate),
      `manifest row \`${r.id}\` records gate "${r.gate}", but ci.yml's actual condition is ` +
        `"${actual}". A gate column that disagrees with the real if: is exactly Phase 231 ` +
        "GATE-02's defect class: a condition that reads plausibly and verifies nothing.",
    );
  }
  assert.ok(
    checked >= 8,
    `gate-column comparison resolved for ${checked} rows; expected at least 8 — the parse ` +
      'broke, this is not a pass.',
  );
});

test('no manifest gate string references a branch name or a literal commit SHA (Phase 231 GATE-03)', () => {
  // A gate keyed to github.head_ref, a branch path, or a SHA is a rotted
  // condition by construction: head_ref is empty on every non-pull_request
  // event and stale the moment the branch merges, and a SHA-pinned gate can
  // never match a future run. This is exactly GATE-02's own defect
  // (`github.head_ref == 'ship/v1.42-ci-gate-remediation'`) -- forbidding the
  // pattern structurally is stronger than fixing this one instance.
  const ROTTED = [
    {
      re: /github\.head_ref/,
      why: 'github.head_ref is empty on every non-pull_request event and stale the moment the branch merges',
    },
    {
      re: /\bship\//,
      why: 'a literal branch path is attacker-nameable on a fork PR and stale by construction once the branch merges',
    },
    {
      re: /\b[0-9a-f]{7,40}\b/,
      why: 'a literal commit SHA can never match a future run, so the gate is dead on arrival',
    },
  ];
  for (const r of rows) {
    for (const { re, why } of ROTTED) {
      assert.ok(
        !re.test(r.gate),
        `manifest row \`${r.id}\` records gate "${r.gate}", which matches ${re} — ${why}. ` +
          'This is Phase 231 GATE-02\'s own defect class (the stale ' +
          "`github.head_ref == 'ship/v1.42-ci-gate-remediation'` clause); forbidding the " +
          'pattern structurally is stronger than fixing one instance.',
      );
    }
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
