// P1 (230-01-PLAN.md) — mechanical enforcement.
//
//   MUST NOT state a CI performance win that was not produced by the committed
//   measurement method; every wall-clock or per-job claim carries a verbatim run ID and
//   the `ci-run-metrics.sh` invocation that produced it.
//
// Subject: the phase evidence ledger (substitutable via GSD_PROHIB_SUBJECT).
//
// DISCLOSED RESIDUAL. The clause "constitutes a performance-win claim" is a semantic
// judgment: a regex over duration tokens both over-matches (prose citing a baseline) and
// under-matches (a paraphrased win carrying no number). What IS mechanized — and is the
// operative half — is that the committed instrument is the recorded producer for every
// captured observation. See MAINTAINING.md § Accepted residuals.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, parseEvidenceSlots } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const raw = readSubject(LEDGER);
const slots = parseEvidenceSlots(raw);

test('the ledger exposes enough captured observations to assert against', () => {
  const captured = slots.filter((s) => s.captured);
  assert.ok(
    captured.length >= 3,
    `only ${captured.length} captured slot(s) parsed — the parse broke, this is not a pass.`,
  );
});

test('the committed instrument is named somewhere in the ledger', () => {
  assert.match(
    raw,
    /ci-run-metrics\.sh/,
    'the ledger never invokes scripts/ci/ci-run-metrics.sh. D-21 makes that script the ONE ' +
      'producer of any wall-clock or per-job claim in this milestone; a ledger that never ' +
      'names it is asserting numbers by some uncommitted method.',
  );
});

test('every captured slot records the command that produced its numbers', () => {
  for (const s of slots.filter((x) => x.captured)) {
    const producer = s.fenced.some(
      (b) => b.includes('ci-run-metrics.sh') || /\bgh (run|pr|api)\b/.test(b),
    );
    assert.ok(
      producer,
      `captured slot ${s.name} records no producing command. A performance number with no ` +
        `committed method behind it is exactly the v1.42 failure mode ` +
        `(.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md) this ledger exists to prevent.`,
    );
  }
});

test('duration claims inside a captured slot sit alongside that slot run ID', () => {
  for (const s of slots.filter((x) => x.captured)) {
    const durations = [...s.text.matchAll(/\b\d+m\d+s\b/g)].map((m) => m[0]);
    if (durations.length === 0) continue;
    assert.ok(
      s.statusRunIds.length >= 1,
      `slot ${s.name} states duration(s) ${durations.join(', ')} but cites no run ID. ` +
        `A duration without a run ID cannot be re-derived, so it is a claim, not evidence.`,
    );
  }
});
