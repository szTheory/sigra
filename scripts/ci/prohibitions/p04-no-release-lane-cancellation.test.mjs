// P4 (230-04-PLAN.md) — mechanical enforcement.
//
//   MUST NOT allow a push-to-main, tag or scheduled release-path run to be cancelled or
//   queued by the new concurrency grouping; release integrity outranks PR latency, and
//   queueing on main compounds the release lane's 30-minute polling ceiling.
//
// Subject: .github/workflows/ci.yml (substitutable via GSD_PROHIB_SUBJECT).
//
// The RUNTIME half is permanent: scripts/ci/ci-demotion-observer.sh fail-closes when any
// job in a non-pull_request run concludes `cancelled` or `timed_out`, so this clause is
// enforced both structurally here and observationally on every future push.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, stripYamlComments, normalizeExpr } from './_lib.mjs';

const ci = stripYamlComments(readSubject('.github/workflows/ci.yml'));

test('a top-level concurrency block is declared', () => {
  assert.match(
    ci,
    /^concurrency:/m,
    'no top-level `concurrency:` block — the parse broke, or the grouping was removed entirely.',
  );
});

test('the concurrency group keys non-PR events on their own run id', () => {
  const group = ci.match(/^concurrency:\s*\n\s+group:\s*(.+)$/m);
  assert.ok(group, 'concurrency group expression not found — the parse broke, this is not a pass.');
  const normalized = normalizeExpr(group[1]);
  assert.ok(
    /github\.event\.pull_request\.number \|\| github\.run_id/.test(normalized),
    `concurrency group is "${normalized}". It must fall back to \`github.run_id\` for non-PR ` +
      `events: run_id is unique per run, which gives every push, tag and scheduled run a group ` +
      `of ONE — structurally impossible to cancel or queue. Grouping on github.ref instead ` +
      `(SEED-005's proposal) puts two rapid main pushes in one group.`,
  );
});

test('cancel-in-progress is a bare boolean, never an expression', () => {
  const cip = ci.match(/^\s+cancel-in-progress:\s*(.+)$/m);
  assert.ok(cip, '`cancel-in-progress` not found under the concurrency block.');
  const value = cip[1].trim();
  assert.ok(
    value === 'true' || value === 'false',
    `cancel-in-progress is \`${value}\`. It must be a bare boolean. An expression that renders ` +
      `the STRING "false" is truthy to GitHub and cancels anyway — the exact trap D-13 records, ` +
      `and it would cancel release-path runs.`,
  );
});

test('no release-path event is excluded from the run-id fallback', () => {
  // The fallback only protects events that carry no pull_request context. If a trigger-level
  // change ever made `github.event.pull_request.number` resolvable on a push, the group would
  // stop being a group-of-one.
  const triggers = ci.match(/^on:\s*\n([\s\S]*?)^\S/m);
  assert.ok(triggers, 'the `on:` trigger block was not found — the parse broke.');
  assert.ok(
    /push:/.test(triggers[1]) && /pull_request:/.test(triggers[1]),
    'the workflow no longer declares both push and pull_request triggers; the concurrency ' +
      'reasoning above assumed exactly that pair, so it must be re-derived rather than assumed.',
  );
});
