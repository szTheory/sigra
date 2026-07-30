// P16 (231-10-PLAN.md) — mechanical enforcement.
//
//   MUST NOT grade the demotion receipt's consequence on the run's trigger. D-19:
//   `ci-observe.yml`'s `Verdict` step carried a branch that warned instead of failing when
//   `RUN_EVENT = "schedule"`, so a demoted construct could silently stop executing on the
//   nightly while the receipt only warned. That branch carried its own removal condition in a
//   comment ("REMOVAL CONDITION: Phase 231 GATE-01 ... delete this branch so the schedule lane
//   fails like the push lane does") and `MAINTAINING.md:255-262`'s residual 4 recorded the same
//   commitment. Phase 231 GATE-02/GATE-04 fixed the nightly's only two reds (run `30425416933`:
//   23/25 green), so the premise for the leniency — a nightly baseline of 0 pass / 9 fail
//   making a tenth red unreadable — is gone.
//
// Subject: .github/workflows/ci-observe.yml (via GSD_PROHIB_SUBJECT).
//
// What this guard proves: the `Verdict` step's shell body, over COMMENT-STRIPPED content, has
// no conditional keyed on the run trigger that exits zero, no warn-instead-of-fail annotation
// string, and its final terminal branch is the unconditional `exit 1` — so the schedule lane
// now fails exactly as the push lane does.
//
// Comments are stripped first (`stripYamlComments`), following `p06`'s precedent: this
// workflow documents its own design in prose that necessarily contains the tokens being
// asserted on (its own header explains the leniency it once carried, and the removal-condition
// comment itself names `RUN_EVENT` and `schedule`), so the guard must assert on EFFECTIVE
// shell content, never on what the file says about itself.
//
// What silently breaks if this guard is deleted: a future edit could reintroduce a
// trigger-dependent early exit (by any route — a new `if [ "$RUN_EVENT" = ... ]` branch, a
// renamed env var carrying the same value, etc.) and the receipt would go back to warning
// instead of failing on the one lane nobody reads by default, with nothing left to notice.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, jobBlock, stripYamlComments } from './_lib.mjs';

const SUBJECT = '.github/workflows/ci-observe.yml';

/**
 * Slice a single named step's block out of a job block's text (from its `- name:` header up
 * to, but not including, the next step at the same indent). Mirrors `p05`'s local
 * `stepBlockById` helper — no other guard needs step-granularity extraction by name yet, so
 * this stays local rather than a premature `_lib.mjs` addition.
 */
function stepBlockByName(jobBlockText, name) {
  const nameRe = new RegExp(`^ {6}- name:\\s*${name}\\s*$`, 'm');
  const nameMatch = nameRe.exec(jobBlockText);
  if (!nameMatch) return null;
  const after = jobBlockText.slice(nameMatch.index + 1);
  const nextHeader = after.match(/\n {6}- /);
  const end = nextHeader ? nameMatch.index + 1 + nextHeader.index : jobBlockText.length;
  return jobBlockText.slice(nameMatch.index, end);
}

/** Extract the `run: |` body text from a step block, or null if none is found. */
function runBody(stepBlockText) {
  if (!stepBlockText) return null;
  const m = stepBlockText.match(/^ {8}run:\s*\|?\s*\n([\s\S]*)$/m);
  return m ? m[1] : null;
}

/**
 * Find the schedule-lane-leniency violation in a verdict step's shell body, or return null
 * when it is clean. A pure function over the extracted body so both the real subject and the
 * negative control fixture below run through the identical check.
 */
function leniencyIssue(body) {
  if (!body || body.trim() === '') {
    return 'the parse broke, this is not a pass — verdict step body not found';
  }
  if (/::warning::Demotion receipt FAILED/.test(body)) {
    return 'the warn-instead-of-fail annotation string ("::warning::Demotion receipt FAILED") ' +
      'survives — a demoted construct can silently stop executing on the nightly while the ' +
      'receipt merely warns instead of failing';
  }
  const triggerConditionalExitZero = /if\s*\[\s*"\$RUN_EVENT"\s*=\s*"[^"]+"\s*\][\s\S]{0,400}?exit 0/;
  if (triggerConditionalExitZero.test(body)) {
    return 'a trigger-dependent early exit survives (a `$RUN_EVENT` conditional that reaches ' +
      '`exit 0`) — the receipt\'s consequence must not depend on which lane observed it';
  }
  const trimmed = body.trimEnd();
  if (!/\bexit 1\s*$/.test(trimmed)) {
    return `the shell body's final line is not the unconditional \`exit 1\` terminal branch ` +
      `(found: ${JSON.stringify(trimmed.split('\n').pop())})`;
  }
  return null;
}

const raw = readSubject(SUBJECT);
const ci = stripYamlComments(raw);
const receiptBlock = jobBlock(ci, 'demotion_receipt');
const verdictBody = runBody(stepBlockByName(receiptBlock ?? '', 'Verdict'));

test('the parse locates the demotion_receipt job and its Verdict step body', () => {
  assert.ok(
    receiptBlock,
    'job `demotion_receipt` not found in ci-observe.yml — the parse broke, this is not a pass',
  );
  assert.ok(
    verdictBody && verdictBody.trim() !== '',
    'the parse broke, this is not a pass — Verdict step run: body not found',
  );
});

test('no trigger-dependent early exit and no warn-instead-of-fail branch survives', () => {
  const issue = leniencyIssue(verdictBody);
  assert.equal(issue, null, issue ?? '');
});

test('the GATE-03 boundary note at the top of the file is byte-unchanged', () => {
  assert.match(
    raw,
    /BOUNDARY WITH PHASE 231/,
    'the `BOUNDARY WITH PHASE 231 (GATE-03)` note is gone. It documents that these jobs only ' +
      'observe and report and are deliberately absent from `ci-gate.needs` — that boundary is ' +
      'unrelated to D-19\'s deletion and must survive it untouched.',
  );
});

test('negative control: a fixture reintroducing a trigger-dependent early exit fails the guard', () => {
  const fixture = `
          set -euo pipefail
          VERDICT="$(jq -r '.verdict' demotion-observation.json)"
          if [ "$VERDICT" = "PASS" ]; then
            exit 0
          fi
          if [ "$RUN_EVENT" = "schedule" ]; then
            echo "::warning::Demotion receipt FAILED on the scheduled lane."
            exit 0
          fi
          exit 1
`;
  const issue = leniencyIssue(fixture);
  assert.ok(
    issue !== null,
    'a fixture that reintroduces a `$RUN_EVENT`-keyed early exit must fail the guard — a guard ' +
      'that only passes on the real file is not falsifiable',
  );
});
