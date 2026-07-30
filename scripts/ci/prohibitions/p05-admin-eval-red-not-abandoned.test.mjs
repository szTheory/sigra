// P5 (230-04-PLAN.md), INVERTED in Phase 231 (231-06-PLAN.md, D-11 step 4 / C-3).
//
// Phase 230 demoted `admin_eval_render` off the pull_request lane and masked it with a
// JOB-level `continue-on-error: true`, deliberately, because its downstream guards
// (b1-b6) had never once run to completion in CI. Plan 231-05 observed them do so (run
// 30512523387, job 90775422130, `admin-eval-harness: PASS -- all phases green`), which is
// D-11 step 4's precondition: only now is removing the mask honest, not premature.
//
// MUST NOT reinstate the job-level mask now that the lane is proven green. A red on the
// unmasked lane is the signal working for the first time; the answer is to fix the cause
// or file it with a diagnosis and an owner (D-15), never to re-mask.
//
// MUST retain the STEP-level `continue-on-error: true` under `id: admin_eval_harness`
// (D-13) -- it is what lets partial evidence bundles upload as CI artifacts before the
// re-fail step (`if: steps.admin_eval_harness.outcome == 'failure'`) turns the job red.
// Losing it destroys the only artifact an investigator has when the harness dies. The two
// flags sit at different indents (job: four spaces, step: eight), and only the four-space
// one is forbidden below.
//
// Subject: .github/workflows/ci.yml (substitutable via GSD_PROHIB_SUBJECT).
//
// FORWARD-ONLY RATCHET, NOT SELF-RETIRING. This guard is no longer one-directional: the
// same assertion that once demanded the job-level mask now forbids it, permanently. It no
// longer references GATE-04's REQUIREMENTS.md coverage row -- that assertion's only
// purpose was to prove the follow-up still existed, and the follow-up is this inversion.
//
// What silently breaks if this guard is deleted: nothing stops a future edit from
// reinstating the job-level mask (hiding an unread red again, the exact abandonment the
// pre-inversion guard forbade) or removing the step-level flag (losing the
// evidence-upload path the moment the harness actually dies).

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, stripYamlComments, jobBlock, jobLevelIfs } from './_lib.mjs';

const ci = stripYamlComments(readSubject('.github/workflows/ci.yml'));
const block = jobBlock(ci, 'admin_eval_render');

/**
 * Slice out a single step's text (from its `- name:`/`- uses:` header up to, but not
 * including, the next step at the same indent) by locating a step-level `id:` line and
 * walking outward. Kept local rather than promoted to `_lib.mjs` -- no other guard needs
 * step-granularity yet, and a premature shared helper is its own kind of drift.
 */
function stepBlockById(jobBlockText, stepId) {
  const idRe = new RegExp(`^ {8}id:\\s*${stepId}\\s*$`, 'm');
  const idMatch = idRe.exec(jobBlockText);
  if (!idMatch) return null;
  const before = jobBlockText.slice(0, idMatch.index);
  const priorHeaders = [...before.matchAll(/^ {6}- .*$/gm)];
  const stepStart = priorHeaders.length > 0 ? priorHeaders[priorHeaders.length - 1].index : 0;
  const after = jobBlockText.slice(idMatch.index);
  const nextHeader = after.match(/\n {6}- /);
  const stepEnd = nextHeader ? idMatch.index + nextHeader.index : jobBlockText.length;
  return jobBlockText.slice(stepStart, stepEnd);
}

test('the admin_eval_render lane still exists', () => {
  assert.ok(
    block,
    'job `admin_eval_render` is gone. Deleting the lane is not demoting it — the harness guards ' +
      'downstream of its Playwright phase (stale-render-guard.sh, the fix-queue/anchor checks) ' +
      'would then never run anywhere, which is the abandonment this prohibition forbids.',
  );
});

test('it is demoted off the pull_request lane, not merely disabled', () => {
  const ifs = jobLevelIfs(block);
  assert.ok(ifs.length >= 1, 'admin_eval_render declares no job-level `if:` — the parse broke.');
  assert.ok(
    ifs.some((e) => /github\.event_name != 'pull_request'/.test(e)),
    `admin_eval_render's condition is ${JSON.stringify(ifs)}. FAST-03 demotes it to non-PR ` +
      `events; a different condition means the demotion was replaced by something else.`,
  );
});

test('the job-level mask cannot be reinstated (D-11 step 4, forward-only ratchet)', () => {
  assert.doesNotMatch(
    block,
    /^ {4}continue-on-error:\s*true\s*$/m,
    '`continue-on-error: true` was reinstated on the admin_eval_render JOB. Phase 231 proved the ' +
      'harness runs green end-to-end in CI (plan 231-05, run 30512523387, job 90775422130, ' +
      '`admin-eval-harness: PASS — all phases green`) and removed this mask so a red harness now ' +
      'reddens the run (D-11 step 4). Reinstating it hides an unread red again — D-15 forbids ' +
      'answering a red harness that way. Fix the cause or file it with a diagnosis and an owner; ' +
      'do not re-mask.',
  );
});

test('the step-level artifact-upload flag under id: admin_eval_harness is retained (D-13)', () => {
  const stepText = stepBlockById(block, 'admin_eval_harness');
  assert.ok(
    stepText,
    'no step with `id: admin_eval_harness` found in admin_eval_render — the parse broke, this is ' +
      'not a pass.',
  );
  assert.match(
    stepText,
    /^ {8}continue-on-error:\s*true\s*$/m,
    'the STEP-level `continue-on-error: true` under `id: admin_eval_harness` is gone. D-13 retains ' +
      'this permanently: it is what lets partial evidence bundles upload as CI artifacts before the ' +
      're-fail step (`if: steps.admin_eval_harness.outcome == \'failure\'`) turns the job red. ' +
      'Losing it destroys the only artifact an investigator has when the harness dies.',
  );
});
