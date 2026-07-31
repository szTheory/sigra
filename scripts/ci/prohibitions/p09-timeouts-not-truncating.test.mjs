// P9 (230-07-PLAN.md) — mechanical enforcement.
//
//   MUST NOT set a `timeout-minutes` tight enough to kill a run that would otherwise have
//   completed; a ceiling that truncates the pre-change baseline or the AFTER run destroys
//   the before/after pair the phase is judged on, and tightening belongs in Phase 235 once
//   the new steady state is measured.
//
// Subject: .github/workflows/ci.yml (substitutable via GSD_PROHIB_SUBJECT).
//
// DELIBERATE DUPLICATION, DISCLOSED. test/sigra/planning/phase_230_ci_timeouts_test.exs
// asserts the same invariants in this repo's native idiom and stays the primary test.
// It cannot serve as a `check_target` because GSD's prohibition-enforcement producer
// accepts only `node-test` / `lint-rule`, so this file is the enforcement surface. Keep
// the two in sync; if they ever disagree, the ExUnit file is the one humans read.
//
// The RUNTIME half is permanent: ci-demotion-observer.sh fail-closes on any `timed_out`
// conclusion, so a ceiling that actually truncates a run is caught observationally too.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, stripYamlComments, jobBlocks } from './_lib.mjs';

const MIN_TIMEOUT = 5;
const MAX_TIMEOUT = 60;

const ci = stripYamlComments(readSubject('.github/workflows/ci.yml'));
const blocks = jobBlocks(ci);
const runnerJobs = blocks.filter(([, b]) => /^ {4}runs-on:/m.test(b));

test('the job walk finds a realistic number of runner jobs', () => {
  assert.ok(
    runnerJobs.length >= 15,
    `only ${runnerJobs.length} job(s) with a \`runs-on:\` were found. A parse that matches ` +
      `almost nothing would make every assertion below vacuously true — the parse broke, this ` +
      `is not a pass.`,
  );
});

test('every runner job declares exactly one timeout-minutes', () => {
  for (const [id, block] of runnerJobs) {
    const declared = [...block.matchAll(/^ {4}timeout-minutes:\s*(-?\d+)\s*$/gm)].map((m) => m[1]);
    assert.equal(
      declared.length,
      1,
      `job \`${id}\` declares ${declared.length} job-level \`timeout-minutes\` (${declared.join(', ')}). ` +
        `Exactly one is required — a per-job count is what stops N declarations concentrated in ` +
        `one job from satisfying a file-wide total, and a job with none inherits GitHub's ` +
        `360-minute default, so a hung job burns six hours instead of failing in bounded time.`,
    );
  }
});

test('no ceiling is tight enough to truncate a run, and none is absurdly loose', () => {
  for (const [id, block] of runnerJobs) {
    const m = block.match(/^ {4}timeout-minutes:\s*(-?\d+)\s*$/m);
    const value = Number(m[1]);
    assert.ok(
      value >= MIN_TIMEOUT,
      `job \`${id}\` has timeout-minutes: ${value}, below the ${MIN_TIMEOUT}-minute floor. A ` +
        `ceiling that truncates a run destroys the before/after pair this phase is judged on; ` +
        `tightening belongs in Phase 235, once the new steady state has been measured.`,
    );
    assert.ok(
      value <= MAX_TIMEOUT,
      `job \`${id}\` has timeout-minutes: ${value}, above the ${MAX_TIMEOUT}-minute ceiling — ` +
        `an accidental 360 or a stray zero-pad defeats the point of bounding the run at all.`,
    );
  }
});

test('the two measured poles stay pinned above their observed maxima', () => {
  const poles = { example_playwright_shard: 30, generated_admin_playwright_smoke: 15 };
  for (const [id, expected] of Object.entries(poles)) {
    const hit = runnerJobs.find(([jobId]) => jobId === id);
    assert.ok(hit, `pole job \`${id}\` not found — the parse broke, this is not a pass.`);
    const value = Number(hit[1].match(/^ {4}timeout-minutes:\s*(\d+)\s*$/m)[1]);
    assert.equal(
      value,
      expected,
      `job \`${id}\` has timeout-minutes: ${value}, expected ${expected}. These two are pinned ` +
        `because they were set against MEASURED durations (the pre-shard Playwright lifecycle ` +
        `ran 28.5m with a 41.7m historical max; Phase 232 split that work across isolated ` +
        `30-minute shard ceilings). Changing one without a fresh measurement is exactly the ` +
        `guesswork this prohibition forbids.`,
    );
  }
});
