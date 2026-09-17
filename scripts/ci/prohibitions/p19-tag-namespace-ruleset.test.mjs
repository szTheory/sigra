// P19 (238-02-PLAN.md) — mechanical enforcement.
//
//   MUST assert that the live GitHub tag ruleset `tag-namespace` (a `target: "tag"` server-side
//   ruleset restricting `v*` tag creation outside a three-component release shape) is mirrored,
//   by its `target` field, in the committed snapshot `.github/rulesets/tag-namespace.json`. The
//   ruleset itself is Settings-managed — there is no git-side record of it except this snapshot
//   — so a guard that never reads the snapshot could not tell "someone deleted the ruleset in
//   Settings" from "the ruleset never existed" or "the ruleset was quietly repointed at branches
//   instead of tags".
//
// Subject: .github/rulesets/tag-namespace.json (via GSD_PROHIB_SUBJECT).
//
// STRUCTURAL AND OFFLINE BY DESIGN, mirroring p12 (`p12-run-id-provenance.test.mjs:1-20`). This
// guard does NOT call the GitHub API, use a token, or touch the network. Two reasons: (1) doing
// so would put `gh`, a token, and a transient 5xx on the pull_request critical path, and a red PR
// for a reason unrelated to the diff is exactly the tax this milestone exists to remove; (2) the
// live-vs-committed drift comparison already has a home — `ci-observe.yml`'s non-gate lane, which
// carries the default `GITHUB_TOKEN` and Metadata: read is enough for the two-step ruleset read.
// This guard is the PR-lane half only: it asserts the committed snapshot has the right shape, not
// that the live object still matches it today.
//
// What silently breaks if this guard is deleted: `.github/rulesets/tag-namespace.json` could be
// hand-edited to any shape — including `target: "branch"`, which would silently claim a
// branch-target ruleset guards the tag namespace — and nothing on the pull_request critical path
// would notice. The live-vs-committed drift check in `ci-observe.yml` runs only after merge
// (`workflow_run` executes the default-branch copy only, per CONTEXT D-11's honest caveat), so
// this guard is the only check that runs on every PR touching the snapshot.
//
// Non-vacuity floor and negative control follow the p17 idiom
// (`p17-no-playwright-retry-wrapper.test.mjs`, tests 1 and "negative control"): a parse that
// silently matches nothing must not report green, and the guard must be observed failing against
// a known-bad shape in the same commit it is born, or the claim that it protects anything is
// unfalsifiable.
//
// This slice asserts only `target === "tag"` — the thinnest true body per 238-02 task 1's "do
// not build any layer beyond what this one path needs". It does NOT assert `enforcement`,
// `conditions`, `rules`, or `bypass_actors` here; those are candidates for a later plan's
// expansion, not this tracer. It also does NOT assert the bypass actor list (CONTEXT D-10): that
// field is returned only to callers with write access to the ruleset, so at CI/anonymous
// permission level an empty array and a populated one are indistinguishable, and asserting it
// here would be a vacuous green.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile } from './_lib.mjs';

const RULESET_SUBJECT = '.github/rulesets/tag-namespace.json';
const KNOWN_BAD_FIXTURE = 'test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json';

const rawSnapshot = readSubject(RULESET_SUBJECT); // the ONE substitutable subject in this file
const snapshot = JSON.parse(rawSnapshot);

/**
 * Pure checker over ANY parsed ruleset-shaped object. Returns `null` when clean, or a NAMED,
 * explanatory string otherwise. Never a boolean: the message is what a reviewer reads to know
 * what a mismatch means.
 */
function rulesetShapeIssue(obj) {
  if (obj === null || typeof obj !== 'object') {
    return 'the parsed value is not an object at all — the parse broke, this is not a pass';
  }
  if (typeof obj.target !== 'string' || obj.target.length === 0) {
    return 'the ruleset object carries no `target` field — the parse broke, this is not a pass';
  }
  if (obj.target !== 'tag') {
    return (
      `the ruleset's \`target\` is \`${obj.target}\`, not \`tag\` — this snapshot no longer ` +
      'represents a tag-namespace guard, or the guard was silently repointed at branches'
    );
  }
  return null;
}

test('the snapshot parse produced an object with a target field at all (non-vacuity floor)', () => {
  assert.ok(
    snapshot !== null && typeof snapshot === 'object' && typeof snapshot.target === 'string' &&
      snapshot.target.length > 0,
    'the committed snapshot has no readable `target` field — the parse broke, this is not a pass',
  );
});

test('the committed snapshot targets tags, not branches', () => {
  const issue = rulesetShapeIssue(snapshot);
  assert.equal(issue, null, issue ?? '');
});

test('negative control: an inline object carrying the branch target fails the guard', () => {
  const badObject = { target: 'branch', name: 'tag-namespace', enforcement: 'active' };
  const issue = rulesetShapeIssue(badObject);
  assert.ok(
    issue !== null,
    'an object carrying the wrong target must fail the guard — a guard that only passes on the ' +
      'real snapshot is not falsifiable',
  );
});

test('the committed known-bad fixture also fails the guard (secondary artifact, not the subject)', () => {
  // Read via readRepoFile, never readSubject — only ONE artifact is substitutable per _lib.mjs's
  // one-subject rule, and that is RULESET_SUBJECT above.
  const fixtureRaw = readRepoFile(KNOWN_BAD_FIXTURE);
  const fixtureObj = JSON.parse(fixtureRaw);
  const issue = rulesetShapeIssue(fixtureObj);
  assert.ok(
    issue !== null,
    `the committed known-bad fixture at ${KNOWN_BAD_FIXTURE} must fail the guard`,
  );
});
