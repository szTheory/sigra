// P5 (230-04-PLAN.md) — mechanical enforcement.
//
//   MUST NOT hide the admin-eval lane's unread red by demoting it and then abandoning the
//   fix; the demotion is explicitly a precondition of Phase 231's GATE-04, not a substitute
//   for it.
//
// Subject: .github/workflows/ci.yml (substitutable via GSD_PROHIB_SUBJECT).
// Secondary: .planning/REQUIREMENTS.md — GATE-04 must still be a tracked, open requirement.
//
// DELIBERATELY ONE-DIRECTIONAL. A tempting stronger form asserts that
// `continue-on-error: true` must DISAPPEAR once GATE-04 is marked Complete — self-retiring,
// but it writes part of Phase 231's exit condition into a Phase 230 guard and would red
// 231's own work mid-flight. Scope boundary respected: this guard only proves the follow-up
// still exists and the lane was not silently deleted.
//
// What silently breaks if this guard is deleted: the demotion becomes the fix. The 17m33s
// unread red leaves the PR lane, GATE-04 quietly falls off REQUIREMENTS.md, and nothing
// ever runs those harness guards again.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, stripYamlComments, jobBlock, jobLevelIfs } from './_lib.mjs';

const ci = stripYamlComments(readSubject('.github/workflows/ci.yml'));
const block = jobBlock(ci, 'admin_eval_render');

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

test('the unread red is retained and visible, not masked away', () => {
  assert.match(
    block,
    /^ {4}continue-on-error:\s*true\s*$/m,
    '`continue-on-error: true` was removed from admin_eval_render. Phase 230 retains it ' +
      'DELIBERATELY (D-11): the two underlying harness defects are unfixed, and removing the ' +
      'flag without fixing them would turn an unread red into a hard gate failure. Removing it ' +
      'is Phase 231 GATE-04\'s job, together with the fix.',
  );
});

test('GATE-04 is still tracked as an open follow-up', () => {
  const reqs = readRepoFile('.planning/REQUIREMENTS.md');
  assert.match(
    reqs,
    /GATE-04/,
    'GATE-04 no longer appears in REQUIREMENTS.md. The demotion was explicitly a PRECONDITION ' +
      'of that requirement; deleting the requirement converts the demotion into the fix, which ' +
      'is precisely the abandonment this prohibition names.',
  );
  const row = reqs.split('\n').find((l) => /\|\s*GATE-04\s*\|/.test(l));
  assert.ok(
    row,
    'GATE-04 has no coverage row in REQUIREMENTS.md, so nothing records which phase owns it.',
  );
  assert.ok(
    !/\bComplete\b/.test(row),
    `GATE-04's coverage row reads "${row.trim()}". If it is genuinely complete, this guard has ` +
      `served its purpose and should be retired together with the continue-on-error assertion ` +
      `above — deliberately, in Phase 231, not silently.`,
  );
});
