// P12 (230-09-PLAN.md) — mechanical enforcement.
//
//   MUST NOT record a wall-clock or per-job claim without the verbatim run ID and the
//   command that produced it; a claim without a run ID is not evidence.
//
// Subject: .planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md
// (substitutable via GSD_PROHIB_SUBJECT).
//
// STRUCTURAL AND OFFLINE BY DESIGN. This guard does NOT resolve run IDs against the
// GitHub API, for two reasons: (1) that would put `gh`, a token, and transient 5xx on the
// pull_request critical path, and a red PR for a reason unrelated to the diff is exactly
// the tax this milestone exists to remove; (2) GitHub retains workflow runs ~400 days, so
// a resolving guard carries a built-in expiry and would later be "fixed" by deleting it.
// The prohibition demands PROVENANCE — that the ID and the producing command are on the
// record — not liveness.
//
// What silently breaks if this guard is deleted: a slot claiming "16m52s" with no run ID
// and no command, i.e. the precedent failure in
// .planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md — "code-level reads that never executed
// the specs" — reappearing as a number nobody can re-derive.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, parseEvidenceSlots } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const slots = parseEvidenceSlots(readSubject(LEDGER));

test('the ledger parse finds a non-trivial set of observation slots', () => {
  assert.ok(
    slots.length >= 4,
    `only ${slots.length} BEFORE-*/AFTER-* slot(s) parsed. An emptied or restructured ledger ` +
      `would make every assertion below vacuously true — the parse broke, this is not a pass.`,
  );
});

test('every slot declares a Status in the allowed grammar', () => {
  for (const s of slots) {
    assert.ok(
      s.statusRaw,
      `slot ${s.name} has no \`Status:\` line. A slot with no status is neither captured nor ` +
        `honestly booked as pending — it is silence, which reads as evidence to a skimming reader.`,
    );
    assert.match(
      s.statusRaw,
      /^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/,
      `slot ${s.name} has Status "${s.statusRaw}", which is neither ` +
        `\`captured (run <id>)\` nor \`pending (<reason>)\`.`,
    );
  }
});

test('every captured slot names at least one run ID in its Status', () => {
  const captured = slots.filter((s) => s.captured);
  assert.ok(
    captured.length >= 3,
    `only ${captured.length} captured slot(s) — too few for this assertion to mean anything.`,
  );
  for (const s of captured) {
    assert.ok(
      s.statusRunIds.length >= 1,
      `captured slot ${s.name} cites no run ID in its Status line ("${s.statusRaw}"). ` +
        `A claim without a run ID is not evidence.`,
    );
  }
});

test('every captured slot carries a fenced block naming the producing command', () => {
  for (const s of slots.filter((x) => x.captured)) {
    assert.ok(
      s.fenced.length >= 1,
      `captured slot ${s.name} has no fenced block. The command that produced the numbers must ` +
        `be on the record so a reader can re-derive them.`,
    );
    const hasCommand = s.fenced.some(
      (b) => b.includes('ci-run-metrics.sh') || /\bgh (run|pr|api)\b/.test(b),
    );
    assert.ok(
      hasCommand,
      `captured slot ${s.name} has fenced blocks but none invokes the committed instrument ` +
        `(\`ci-run-metrics.sh\`) or \`gh\`. Output pasted with no producing command is a number ` +
        `nobody can reproduce.`,
    );
  }
});

test('each captured slot Status run ID also appears in that slot body', () => {
  for (const s of slots.filter((x) => x.captured)) {
    for (const id of s.statusRunIds) {
      const occurrences = s.runIds.filter((r) => r === id).length;
      assert.ok(
        occurrences >= 2,
        `slot ${s.name} declares run ${id} in its Status but the id appears ${occurrences} time(s) ` +
          `in the slot — the Status is not corroborated by the recorded commands or output.`,
      );
    }
  }
});

test('a pending slot books its obligation instead of claiming a number', () => {
  for (const s of slots.filter((x) => x.pending)) {
    assert.match(
      s.statusRaw,
      /pending \(.*obligation.*\)/i,
      `pending slot ${s.name} does not name its obligation ("${s.statusRaw}"). A pending slot ` +
        `must say WHY it cannot be captured, or it reads as an evidence hole.`,
    );
    assert.ok(
      s.fenced.length >= 1,
      `pending slot ${s.name} records no capture command. A deferred observation without the ` +
        `exact command to run later is a dropped obligation, not a booked one.`,
    );
  }
});
