// P8 (230-06-PLAN.md) — mechanical enforcement.
//
//   MUST NOT claim a ~62s saving for the browser cache; only about 14s of the measured 61s
//   install is cacheable browser download, the ~33s system-dependency install is not
//   cacheable, and on a cache miss the post-job upload of ~400-500MB of binaries is new
//   cost that did not exist before. The honest claim is that a cache hit was logged, with
//   the measured install-step and post-step durations recorded.
//
// Subject: the phase evidence ledger (substitutable via GSD_PROHIB_SUBJECT).
//
// DISCLOSED RESIDUAL. A negative claim proved by regex is evadable by paraphrase — "don't
// overclaim anywhere in prose" is a reading task. What is mechanized is the POSITIVE
// content contract the prohibition itself specifies (a logged cache hit, with both the
// hit and the miss durations recorded) plus a ban on the specific overclaim shape.
// See MAINTAINING.md § Accepted residuals.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const raw = readSubject(LEDGER);

test('the ledger discusses the browser cache at all', () => {
  assert.match(
    raw,
    /cache/i,
    'the ledger never mentions the browser cache — the parse broke, or FAST-06 lost its ' +
      'evidence entirely. Either way this is not a pass.',
  );
});

test('a cache HIT and a cache MISS are both on the record', () => {
  assert.match(
    raw,
    /cache hit/i,
    'no cache hit is recorded. FAST-06\'s honest claim is precisely "a cache hit was logged"; ' +
      'without that observation there is no evidence at all.',
  );
  assert.match(
    raw,
    /cache (miss|not found)/i,
    'no cache miss is recorded. Without the miss side there is nothing to compare the hit ' +
      'against, and any saving figure is unfalsifiable.',
  );
});

test('the measured install-step durations are recorded for both branches', () => {
  const seconds = [...raw.matchAll(/\b(\d{1,4})\s?s\b/g)].map((m) => Number(m[1]));
  assert.ok(
    seconds.filter((n) => n > 0).length >= 2,
    'fewer than two measured step durations are recorded near the cache evidence. The honest ' +
      'claim this prohibition permits IS the pair of measured durations; without them there is ' +
      'nothing but an assertion.',
  );
});

test('the specific ~62s saving overclaim is not made', () => {
  // SCOPED DELIBERATELY to the figure the prohibition names. An earlier, broader version of
  // this assertion (any saving verb near any seconds figure) flagged the ledger's own HONEST
  // negative disclosure — "did **not** show the predicted ~15-25s saving: miss **36s** vs hit
  // **180s**" — as an overclaim. Distinguishing an affirmative claim from a negated one in
  // prose is the semantic residual disclosed in MAINTAINING.md § Accepted residuals; a guard
  // that reds on honesty is worse than no guard, so this bans only the named shape.
  const overclaims = [...raw.matchAll(/\bsav(?:e|es|ed|ing|ings)\b[^.\n]{0,40}?\b6[0-9]\s?s\b/gi)]
    .map((m) => m[0].trim())
    .filter((s) => !/\bnot\b|\bno\b|\bnever\b/i.test(s));
  assert.deepEqual(
    overclaims,
    [],
    `the ledger claims a ~60s cache saving: ${JSON.stringify(overclaims)}. Only ~14s of the ` +
      `measured install is cacheable browser download; the ~33s system-dependency install is ` +
      `not cacheable, and a miss adds a new ~400-500MB post-job upload that did not exist ` +
      `before. Record the measured step durations instead of a net figure.`,
  );
});
