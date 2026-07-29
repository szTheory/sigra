// P2 (230-02-PLAN.md) — mechanical enforcement.
//
//   MUST NOT reduce or drop the axe WCAG signal while relocating it; the three design
//   projects (Desktop Chrome, iPhone 13, dark) each keep a full-document WCAG 2.1/2.2 AA
//   scan on every PR.
//
// Subject: test/example/priv/playwright/tests/admin-design.spec.ts (via GSD_PROHIB_SUBJECT).
// Secondary: playwright.config.ts (the three projects) and ci.yml (the PR-lane filter).
//
// What silently breaks if this guard is deleted: the axe test acquires a `@snapshot` tag —
// or the PR-lane step's `--grep-invert '@snapshot'` starts excluding it — and the WCAG scan
// leaves the pull_request lane entirely while the gallery still reports green.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, stripYamlComments, stripJsComments } from './_lib.mjs';

const SPEC = 'test/example/priv/playwright/tests/admin-design.spec.ts';
// Comments stripped: the spec documents that its axe scan "carries no `.include()`", so
// matching raw text would red the shipped file precisely for explaining that it is correct.
const spec = stripJsComments(readSubject(SPEC));

const AXE_TITLE = 'axe: full-page WCAG 2.1/2.2 AA on the design gallery';

test('the full-page axe test is declared exactly once', () => {
  const decls = [...spec.matchAll(/test\(\s*'axe:[^']*'/g)].map((m) => m[0]);
  assert.equal(
    decls.length,
    1,
    `expected exactly one axe test declaration, found ${decls.length}: ${JSON.stringify(decls)}. ` +
      `Zero means the WCAG signal was dropped while being "relocated"; more than one means the ` +
      `scan was silently re-scoped.`,
  );
  assert.ok(
    spec.includes(AXE_TITLE),
    `the axe test title changed. The PR-lane filter and this guard both key on it; a renamed ` +
      `title is how the scan leaves the PR lane without anyone noticing.`,
  );
});

test('the axe test carries no @snapshot tag', () => {
  const line = spec.split('\n').find((l) => l.includes(AXE_TITLE)) ?? '';
  assert.ok(
    !/\{\s*tag\s*:/.test(line),
    `the axe test declares a tag options object: "${line.trim()}". The PR lane runs ` +
      `--grep-invert '@snapshot', so tagging this test sweeps the entire WCAG scan off every ` +
      `pull request while the lane still reports green.`,
  );
});

test('the scan is full-document — no element scoping was introduced', () => {
  const helper = spec.match(/async function assertNoAxeViolations[\s\S]*?\n}/);
  assert.ok(helper, 'assertNoAxeViolations helper not found — the parse broke, this is not a pass.');
  assert.ok(
    !/\.include\(/.test(helper[0]),
    'assertNoAxeViolations applies an `.include(selector)` restriction. That converts a ' +
      'full-document WCAG scan into an element-scoped one — a reduction of signal, which is ' +
      'exactly what this prohibition forbids during relocation.',
  );
  for (const tag of ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']) {
    assert.ok(
      helper[0].includes(tag),
      `the axe tag set no longer includes \`${tag}\`. Dropping a tag narrows the standard the ` +
        `gallery is held to.`,
    );
  }
});

test('all three design projects still run the spec on the PR lane', () => {
  const ci = stripYamlComments(readRepoFile('.github/workflows/ci.yml'));
  const prStep = ci.match(/id: design_gallery\n[\s\S]*?(?=- name:|\n {6}- )/);
  assert.ok(prStep, 'the PR-lane design_gallery step was not found — the parse broke.');
  for (const project of ['admin-design-chromium', 'admin-design-mobile', 'admin-design-dark']) {
    assert.ok(
      prStep[0].includes(project),
      `project \`${project}\` is not passed to the PR-lane gallery step. The three projects are ` +
        `the viewport and theme axes on which repeated axe scans are genuinely non-redundant ` +
        `(color-contrast and target-size evaluate computed style); dropping one drops coverage.`,
    );
  }
  assert.ok(
    prStep[0].includes('--grep-invert'),
    'the PR-lane gallery step no longer uses --grep-invert. If it switched to --grep, the axe ' +
      'test (untagged) would stop running on pull requests entirely.',
  );
});
