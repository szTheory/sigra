// P15 (231-10-PLAN.md) — mechanical enforcement.
//
//   MUST NOT let the Playwright GitHub Pages publisher boot the example app without first
//   seeding it. D-17: `playwright-github-pages.yml` went straight from `Setup example dev DB`
//   to `Boot example app in background` with no `Run demo seeds` step, while all four
//   example-booting jobs in ci.yml run one (`:1288`, `:1950`, `:2258`, `:2506`) — without ~30
//   seeded loadtest users the admin users index never paginates and the checkpoint spec's
//   next-page link never renders, which is exactly how scheduled run `30432494488` failed, in
//   all three checkpoint projects, at `admin-checkpoints.spec.ts:230`.
//
// Subject: .github/workflows/playwright-github-pages.yml (via GSD_PROHIB_SUBJECT).
//
// What this guard proves: the publish job's step list contains exactly one seeds step, it sits
// strictly between DB setup and app boot, and it carries no `if:` condition — a guarded copy
// in a workflow with no diff-classification (`changes`) job would evaluate empty, never run,
// and look like coverage. That is worse than no step at all: it hides the same gap behind
// something that reads like a fix.
//
// What silently breaks if this guard is deleted: a future edit could drop the seeds step (or
// reorder it after boot, or gate it on a condition this workflow can never satisfy) and nothing
// would notice until the next scheduled run failed the same way, weeks later.
//
// Comments are stripped before parsing (`stripYamlComments`) for the same reason `p06`
// explains: an explanatory comment placed near a step (e.g. recording why the seeds block was
// copied from the `admin_eval_render` variant) can contain the literal token `seeds.exs` in
// prose, and a naive text match would misattribute that prose to whichever step it happens to
// trail.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, jobBlock, stripYamlComments } from './_lib.mjs';

const SUBJECT = '.github/workflows/playwright-github-pages.yml';

/**
 * Extract the ordered step list from a job block's `steps:` section. Each entry carries its
 * `name` (or a `uses:`-derived label when unnamed), whether it declares a step-level `if:`,
 * and its raw (comment-stripped) text for the seeds-script content check.
 */
function stepList(jobBlockText) {
  const m = jobBlockText.match(/\n {4}steps:\n([\s\S]*)$/);
  if (!m) return [];
  const body = m[1];
  return body
    .split(/(?=^ {6}- )/m)
    .filter((s) => s.trim() !== '')
    .map((block) => {
      const nameMatch = block.match(/^ {6}- name:\s*(.+)$/m);
      const usesMatch = block.match(/^ {6}- uses:\s*(.+)$/m);
      return {
        name: nameMatch ? nameMatch[1].trim() : (usesMatch ? `uses:${usesMatch[1].trim()}` : '(unnamed)'),
        hasCondition: /^ {8}if:/m.test(block),
        text: block,
      };
    });
}

/**
 * Find the seeds-before-boot violation in a step list, or return null when the ordering is
 * correct. A pure function over parsed steps so both the real subject and the two negative
 * control fixtures below run through the identical check — the assertions are falsifiable, not
 * merely present.
 */
function seedsOrderingIssue(steps) {
  if (steps.length === 0) {
    return 'the parse broke, this is not a pass — zero steps extracted from the publish job';
  }
  const dbIndex = steps.findIndex((s) => s.name === 'Setup example dev DB');
  const bootIndex = steps.findIndex((s) => s.name.startsWith('Boot example app'));
  if (dbIndex === -1 || bootIndex === -1) {
    return `could not locate the DB-setup or app-boot step (db=${dbIndex}, boot=${bootIndex}) — the parse broke, this is not a pass`;
  }
  const seedsIndices = steps
    .map((s, i) => (/run:.*seeds\.exs/.test(s.text) ? i : -1))
    .filter((i) => i !== -1);
  if (seedsIndices.length === 0) {
    return 'no step invokes priv/repo/seeds.exs — the publisher boots the app without seeding it, ' +
      'which is exactly how scheduled run 30432494488 failed (admin users index never paginates, ' +
      "the checkpoint spec's next-page link never renders)";
  }
  if (seedsIndices.length > 1) {
    return `${seedsIndices.length} steps invoke seeds.exs, expected exactly one`;
  }
  const seedsIndex = seedsIndices[0];
  if (!(dbIndex < seedsIndex && seedsIndex < bootIndex)) {
    return `the seeds step (index ${seedsIndex}) does not sit strictly between DB setup ` +
      `(index ${dbIndex}) and app boot (index ${bootIndex})`;
  }
  const seedsStep = steps[seedsIndex];
  if (seedsStep.hasCondition) {
    const ifLine = seedsStep.text.match(/^ {8}if:.*/m)?.[0]?.trim();
    return `the seeds step declares a condition (${ifLine}). This workflow has no diff-classification ` +
      '(`changes`) job, so a conditional seeds step evaluates empty, never runs, and looks like ' +
      'coverage — worse than no step at all.';
  }
  return null;
}

const ci = stripYamlComments(readSubject(SUBJECT));
const publishBlock = jobBlock(ci, 'publish');

test('the parse locates the publish job and its step list is non-empty', () => {
  assert.ok(
    publishBlock,
    'job `publish` not found in playwright-github-pages.yml — the parse broke, this is not a pass',
  );
  const steps = stepList(publishBlock);
  assert.ok(
    steps.length > 0,
    'the parse broke, this is not a pass — zero steps extracted from the publish job',
  );
});

test('a demo-seeds step exists, unconditional, strictly between DB setup and app boot', () => {
  const steps = stepList(publishBlock);
  const issue = seedsOrderingIssue(steps);
  assert.equal(issue, null, issue ?? '');
});

test('negative control: a fixture omitting the seeds step fails the guard', () => {
  const fixture = `  publish:
    name: Publish Playwright site
    steps:
      - uses: actions/checkout@abc
      - name: Setup example dev DB
        working-directory: test/example
        run: mix ecto.create && mix ecto.migrate
      - name: Boot example app in background
        working-directory: test/example
        run: mix phx.server &
`;
  const issue = seedsOrderingIssue(stepList(fixture));
  assert.match(
    issue ?? '',
    /no step invokes priv\/repo\/seeds\.exs/,
    'a fixture with no seeds step must fail the guard — a guard that only passes on the real ' +
      'file is not falsifiable',
  );
});

test('negative control: a fixture whose seeds step sits after boot fails the guard', () => {
  const fixture = `  publish:
    name: Publish Playwright site
    steps:
      - uses: actions/checkout@abc
      - name: Setup example dev DB
        working-directory: test/example
        run: mix ecto.create && mix ecto.migrate
      - name: Boot example app in background
        working-directory: test/example
        run: mix phx.server &
      - name: Run demo seeds
        working-directory: test/example
        run: mix run priv/repo/seeds.exs
`;
  const issue = seedsOrderingIssue(stepList(fixture));
  assert.match(
    issue ?? '',
    /does not sit strictly between/,
    'a fixture whose seeds step sits after boot must fail the guard on ordering, not on absence',
  );
});
