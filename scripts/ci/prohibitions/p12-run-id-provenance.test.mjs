// P12 (230-09-PLAN.md, 236-05-PLAN.md) — mechanical, offline provenance enforcement.
//
// A captured observation must retain its verbatim run ID, the command that produced it, and
// corroboration inside the same slot. `readSubject()` keeps a single injected-subject seam for
// committed fail-first fixtures while transparently finding archived default ledgers.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, parseEvidenceSlots } from './_lib.mjs';

const PHASE_230_LEDGER =
  '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const PHASE_236_LEDGER =
  '.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md';

const DEFAULT_LEDGER_SPECS = Object.freeze([
  {
    label: 'Phase 230 evidence ledger',
    path: PHASE_230_LEDGER,
    minSlots: 4,
    minCaptured: 3,
  },
  {
    label: 'Phase 236 evidence ledger',
    path: PHASE_236_LEDGER,
    minSlots: 3,
    minCaptured: 3,
  },
]);

const ledgerSpecs = process.env.GSD_PROHIB_SUBJECT
  ? [
      {
        label: `injected evidence subject ${process.env.GSD_PROHIB_SUBJECT}`,
        path: PHASE_236_LEDGER,
        minSlots: 3,
        minCaptured: 3,
      },
    ]
  : DEFAULT_LEDGER_SPECS;

const ledgers = ledgerSpecs.map((spec) => ({
  ...spec,
  slots: parseEvidenceSlots(readSubject(spec.path)),
}));

for (const ledger of ledgers) {
  test(`${ledger.label}: the parse finds a non-trivial set of observation slots`, () => {
    assert.ok(
      ledger.slots.length >= ledger.minSlots,
      `${ledger.label} parsed only ${ledger.slots.length} BEFORE-*/AFTER-* slot(s), below its ` +
        `${ledger.minSlots}-slot floor — the parse broke, this is not a pass.`,
    );
  });

  test(`${ledger.label}: every slot declares a Status in the allowed grammar`, () => {
    for (const slot of ledger.slots) {
      assert.ok(
        slot.statusRaw,
        `${ledger.label} slot ${slot.name} has no \`Status:\` line. A slot with no status is ` +
          'neither captured nor honestly booked as pending — it is silence, which reads as evidence.',
      );
      assert.match(
        slot.statusRaw,
        /^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/,
        `${ledger.label} slot ${slot.name} has Status "${slot.statusRaw}", which is neither ` +
          '\`captured (run <id>)\` nor \`pending (<reason>)\`.',
      );
    }
  });

  test(`${ledger.label}: every captured slot names at least one Status run ID`, () => {
    const captured = ledger.slots.filter((slot) => slot.captured);
    assert.ok(
      captured.length >= ledger.minCaptured,
      `${ledger.label} has only ${captured.length} captured slot(s), below its ` +
        `${ledger.minCaptured}-captured-slot floor — the parse broke, this is not a pass.`,
    );
    for (const slot of captured) {
      assert.ok(
        slot.statusRunIds.length >= 1,
        `${ledger.label} slot ${slot.name} cites no run ID in its Status line ` +
          `("${slot.statusRaw}"). A claim without a run ID is not evidence.`,
      );
    }
  });

  test(`${ledger.label}: every captured slot records a producing command`, () => {
    for (const slot of ledger.slots.filter((candidate) => candidate.captured)) {
      assert.ok(
        slot.fenced.length >= 1,
        `${ledger.label} slot ${slot.name} has no fenced block. The command that produced the ` +
          'numbers must be on the record so a reader can re-derive them.',
      );
      const hasCommand = slot.fenced.some(
        (block) => block.includes('ci-run-metrics.sh') || /\bgh (run|pr|api)\b/.test(block),
      );
      assert.ok(
        hasCommand,
        `${ledger.label} slot ${slot.name} has fenced blocks but none invokes the committed ` +
          'instrument (\`ci-run-metrics.sh\`) or \`gh\`. Output pasted with no producing command ' +
          'is a number nobody can reproduce.',
      );
    }
  });

  test(`${ledger.label}: each captured Status run ID is corroborated in its slot body`, () => {
    for (const slot of ledger.slots.filter((candidate) => candidate.captured)) {
      for (const id of slot.statusRunIds) {
        const occurrences = slot.runIds.filter((runId) => runId === id).length;
        assert.ok(
          occurrences >= 2,
          `${ledger.label} slot ${slot.name} declares run ${id} in its Status but the id appears ` +
            `${occurrences} time(s) in the slot — the Status is not corroborated by the recorded ` +
            'commands or output.',
        );
      }
    }
  });

  test(`${ledger.label}: each pending slot books its obligation instead of claiming a number`, () => {
    for (const slot of ledger.slots.filter((candidate) => candidate.pending)) {
      assert.match(
        slot.statusRaw,
        /pending \(.*obligation.*\)/i,
        `${ledger.label} slot ${slot.name} does not name its obligation ("${slot.statusRaw}"). ` +
          'A pending slot must say WHY it cannot be captured, or it reads as an evidence hole.',
      );
      assert.ok(
        slot.fenced.length >= 1,
        `${ledger.label} slot ${slot.name} records no capture command. A deferred observation ` +
          'without the exact command to run later is a dropped obligation, not a booked one.',
      );
    }
  });
}
