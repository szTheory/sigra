// P11 (230-09-PLAN.md) — mechanical enforcement.
//
//   MUST NOT narrow or weaken a success criterion at verification time to make it pass;
//   SC-2's restatement was made before the check was written and is recorded with its
//   evidence, and any further restatement must be recorded the same way rather than
//   applied silently.
//
// Subject: the phase evidence ledger (substitutable via GSD_PROHIB_SUBJECT).
//
// THE DISCLOSED RESIDUAL — READ THIS BEFORE TRUSTING A GREEN.
// The prohibition has two halves. Its OPERATIVE half — "recorded ... rather than applied
// silently" — is fully mechanizable and is what this guard enforces: a restatement must
// exist as a named section carrying its evidence. Its MOTIVATIONAL half — whether a
// recorded rewording is a legitimate correction or a weakening that made the criterion
// pass — is a semantic comparison of two English criteria against original intent. No
// check that reads this repository can decide it, and adopting a mechanical proxy in order
// to close the item would ITSELF be the substitution this prohibition forbids.
//
// So: this guard makes a narrowing impossible to perform SILENTLY. It does not, and does
// not claim to, decide whether a recorded narrowing was justified. That judgment is
// carried as a named accepted residual in MAINTAINING.md § Accepted residuals, with
// ordinary code review of the recorded diff as its backstop — an activity that already
// happens on every PR and creates no new blocking gate.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const raw = readSubject(LEDGER);

const RESTATEMENT_RE = /^##\s+Restated Success Criterion\s*\(([^)]+)\)\s*$/gm;
const sections = [...raw.matchAll(RESTATEMENT_RE)];

test('the ledger declares at least one restatement section', () => {
  assert.ok(
    sections.length >= 1,
    'no `## Restated Success Criterion (SC-N)` section found. This phase DID restate SC-2 ' +
      '(a job whose condition evaluates false is present with a `skipped` conclusion rather ' +
      'than absent). A restatement that leaves no record is, by definition, one applied ' +
      'silently — which is the whole of what this prohibition forbids.',
  );
});

test('every restatement names the success criterion it restates', () => {
  for (const m of sections) {
    assert.match(
      m[1],
      /SC-\d+/,
      `a restatement section is headed "(${m[1]})", which names no SC identifier. A restatement ` +
        `that does not say WHICH criterion it changes cannot be reviewed against the original.`,
    );
  }
});

test('every restatement carries evidence, not just an assertion', () => {
  const body = raw.split(/^##\s+Restated Success Criterion/m).slice(1);
  assert.ok(body.length >= 1, 'restatement section body did not split — the parse broke.');
  for (const b of body) {
    const section = b.split(/^##\s+/m)[0];
    const hasRunId = /\b\d{8,12}\b/.test(section);
    const hasCommandOrRef = /```|ci-run-metrics\.sh|\bgh \b|ROADMAP\.md|EVIDENCE\.md/.test(section);
    assert.ok(
      hasRunId || hasCommandOrRef,
      'a restatement section carries neither a run ID nor a command/artifact reference. The ' +
        'prohibition requires a restatement be "recorded with its evidence"; prose asserting a ' +
        'new wording, with nothing to check it against, is the silent narrowing wearing a heading.',
    );
  }
});
