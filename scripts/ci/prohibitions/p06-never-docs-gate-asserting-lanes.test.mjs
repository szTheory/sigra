// P6 (230-05-PLAN.md) — mechanical enforcement.
//
//   MUST NOT gate off the lanes that assert on the very files a docs-only PR changes;
//   `fast_checks` and `library_tests` run in full on every event, because removing them
//   for a docs-only PR is a coverage hole in exactly the dimension the change touches.
//
// Subject: .github/workflows/ci.yml (substitutable via GSD_PROHIB_SUBJECT).
//
// What silently breaks if this guard is deleted: a docs-only PR reports every required
// context green while the only lanes that read `.planning/**` and `guides/**` -- the
// exact paths such a PR changes -- were skipped. `ci-gate` counts a skip as a pass, so
// nothing anywhere would say so.

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  readSubject, jobBlocks, jobBlock, jobNeeds, stripYamlComments, NEVER_DOCS_GATED,
} from './_lib.mjs';

// Comments are stripped first: ci.yml documents its own docs-only design in prose that
// necessarily contains the token `docs_only`, and this guard asserts on effective
// workflow content, not on what the file says about itself.
const ci = stripYamlComments(readSubject('.github/workflows/ci.yml'));

test('the workflow parse locates every lane this prohibition names', () => {
  const ids = jobBlocks(ci).map(([id]) => id);
  for (const id of NEVER_DOCS_GATED) {
    assert.ok(
      ids.includes(id),
      `job \`${id}\` was not found by the job walk. Either it was renamed/removed, or the ` +
        `parse broke — this is not a pass. Found: ${ids.join(', ')}`,
    );
  }
});

test('lanes whose guards read .planning and guides carry no docs_only reference', () => {
  for (const id of NEVER_DOCS_GATED) {
    const block = jobBlock(ci, id);
    assert.ok(block, `job \`${id}\` missing — the parse broke, this is not a pass`);
    const hits = [...block.matchAll(/docs_only/g)].length;
    assert.equal(
      hits,
      0,
      `job \`${id}\` references docs_only ${hits} time(s). Gating it removes coverage in the ` +
        `one dimension a docs-only PR touches: its guards (milestone-verification-gate.sh, ` +
        `getting-started-contract.sh) and the ExUnit files under test/sigra/planning/ read ` +
        `.planning/** and guides/** directly.`,
    );
  }
});

test('those same lanes do not depend on the changes job', () => {
  for (const id of NEVER_DOCS_GATED) {
    const block = jobBlock(ci, id);
    assert.ok(block, `job \`${id}\` missing — the parse broke, this is not a pass`);
    const needs = jobNeeds(block);
    assert.ok(
      !needs.includes('changes'),
      `job \`${id}\` declares \`needs: changes\` (${needs.join(', ')}). Even without a docs_only ` +
        `expression, a needs-edge on \`changes\` lets a failure there skip this lane — the same ` +
        `coverage hole by another route.`,
    );
  }
});
