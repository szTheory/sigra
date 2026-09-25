// P20 (240-02-PLAN.md) — mechanical enforcement.
//
//   MUST NOT let `.github/workflows/green-04-evidence.yml`'s job body drift from `ci.yml`'s
//   `generated_admin_playwright_smoke` step list (ci.yml:1401-1533). The GREEN-04 n>=20 proof is
//   only evidence ABOUT `ci-gate`'s lane while the two step lists agree. D-02 states the premise:
//   twenty green runs of a SIBLING harness say nothing about the lane that reds `ci-gate`. Drop
//   `Install Playwright browsers` from the copy and the smoke still "runs" — against no browsers —
//   and reports twenty greens that mean nothing.
//
// Subject: .github/workflows/green-04-evidence.yml (via GSD_PROHIB_SUBJECT).
// Reference (read from its real location, never substituted): .github/workflows/ci.yml.
//
// STRUCTURAL AND OFFLINE BY DESIGN — no gh, no token, no network. Standing constraint: guards
// never hit a live API on the PR critical path, because a red PR for a reason unrelated to the
// diff is exactly the tax this milestone exists to remove. This guard reads two committed files
// and compares them; it can be run on a plane.
//
// WHAT THIS GUARD PROVES: the evidence job and the live job have the same number of steps, the
// same step names in the same order, byte-identical step bodies modulo the ONE documented D-02
// exception (artifact `name:` values carrying a `-${{ matrix.repeat }}` suffix, which
// `actions/upload-artifact` v7 forces because it errors on a duplicate artifact name within one
// run), and the same four load-bearing command invocations.
//
// WHAT SILENTLY BREAKS IF THIS GUARD IS DELETED: someone edits `ci.yml`'s smoke job — adds a
// setup step, changes the acceptance-smoke target, bumps the phx_new archive — and the evidence
// workflow keeps proving something about a lane that no longer exists. D-03 asked for exactly
// this, because "any drift makes the proof worthless" is unenforceable by comment, and a comment
// alone is the "green gate that verified nothing" pattern this milestone exists to remove.
//
// NON-VACUITY FLOOR: a parse yielding zero steps from EITHER side is reported as a failure, never
// as a pass (`_lib.mjs`'s "the parse broke, this is not a pass" convention).
//
// Comments are stripped on BOTH sides before any content assertion (`stripYamlComments`) for the
// reason `p06` and `p15` document: explanatory prose near a step can contain that step's tokens
// verbatim — this workflow's own header comment quotes three of the four load-bearing commands —
// and a naive text match would misattribute prose to whichever step it happens to trail.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, jobBlock, stripYamlComments } from './_lib.mjs';

const SUBJECT = '.github/workflows/green-04-evidence.yml';
const REFERENCE = '.github/workflows/ci.yml';
const REF_JOB = 'generated_admin_playwright_smoke';
const EVIDENCE_JOB = 'green_04_evidence_repeat';

/** The four invocations that ARE the lane. Any of them present on one side only is drift. */
const LOAD_BEARING = [
  'npm ci',
  'npx playwright install --with-deps chromium webkit',
  'mix archive.install --force hex phx_new 1.8.8',
  'scripts/ci/admin-acceptance-smoke.sh --test all',
];

/**
 * Extract the ordered step list from a job block's `steps:` section. Each entry carries its
 * `name` (or a `uses:`-derived label when unnamed), whether it declares a step-level `if:`,
 * and its raw (comment-stripped) text.
 *
 * Copied verbatim from p15-pages-publisher-seeds-before-boot.test.mjs:40-56 — same parse, same
 * indentation contract, deliberately not abstracted into _lib.mjs so each guard's extractor stays
 * legible beside its own assertions.
 */
function stepList(jobBlockText) {
  const m = jobBlockText.match(/\n {4}steps:\n([\s\S]*)$/);
  if (!m) return [];
  const body = m[1];
  return body
    .split(/(?=^ {6}- )/m)
    .filter((s) => s.trim() !== '')
    .map((block) => {
      const nameMatch = block.match(/^ {6}- name:\s*(.+)$/m);
      const usesMatch = block.match(/^ {6}- uses:\s*(.+)$/m);
      return {
        name: nameMatch ? nameMatch[1].trim() : (usesMatch ? `uses:${usesMatch[1].trim()}` : '(unnamed)'),
        hasCondition: /^ {8}if:/m.test(block),
        text: block,
      };
    });
}

/**
 * Canonicalize a step body for comparison.
 *
 * The `-${{ matrix.repeat }}` suffix does NOT live on any STEP NAME — the copied step names
 * (`Upload generated admin review bundle (main, 14d retention)` and its three siblings) are
 * byte-identical on both sides. It lives inside each upload step's BODY, on its `with.name:`
 * value. So the normalisation is applied where the divergence actually is: a body-level
 * `name: <value>-${{ matrix.repeat }}` compares equal to `name: <value>`. That is the one and
 * only tolerated body difference; every other body edit still reports as drift.
 *
 * Blank lines are dropped because `stripYamlComments` replaces each full-line comment with an
 * empty line, and the two files legitimately carry different explanatory prose. Trailing
 * whitespace is trimmed for the same reason.
 */
function normalize(stepText) {
  return stepText
    .replace(/(^\s*name:\s*\S+?)-\$\{\{\s*matrix\.repeat\s*\}\}[ \t]*$/gm, '$1')
    .split('\n')
    .map((line) => line.replace(/[ \t]+$/, ''))
    .filter((line) => line !== '')
    .join('\n');
}

const tick = (s) => `\`${s}\``;

/**
 * Return a description of the first parity violation between the reference job's steps and the
 * evidence copy's steps, or null when they agree. A pure function over parsed steps so the real
 * pair and the known-bad fixture run through IDENTICAL code — the p15/p19 house idiom, which is
 * what makes the assertion falsifiable rather than merely present.
 */
function parityIssue(refSteps, evSteps) {
  if (refSteps.length === 0 || evSteps.length === 0) {
    return 'the parse broke, this is not a pass — zero steps extracted ' +
      `(ci.yml#${REF_JOB}=${refSteps.length}, ${EVIDENCE_JOB}=${evSteps.length})`;
  }

  const refNames = refSteps.map((s) => s.name);
  const evNames = evSteps.map((s) => s.name);

  if (refSteps.length !== evSteps.length) {
    const missing = refNames.filter((n) => !evNames.includes(n));
    const extra = evNames.filter((n) => !refNames.includes(n));
    return `step-count drift: ci.yml#${REF_JOB} has ${refSteps.length} steps, ` +
      `${SUBJECT}#${EVIDENCE_JOB} has ${evSteps.length}` +
      (missing.length ? ` — missing from the evidence copy: ${missing.map(tick).join(', ')}` : '') +
      (extra.length ? ` — present only in the evidence copy: ${extra.map(tick).join(', ')}` : '') +
      '. The evidence copy is no longer the lane it claims to prove (D-02).';
  }

  for (let i = 0; i < refSteps.length; i += 1) {
    if (refNames[i] !== evNames[i]) {
      return `step-name drift at index ${i}: ci.yml#${REF_JOB} has ${tick(refNames[i])}, ` +
        `${EVIDENCE_JOB} has ${tick(evNames[i])}`;
    }
  }

  for (let i = 0; i < refSteps.length; i += 1) {
    const a = normalize(refSteps[i].text);
    const b = normalize(evSteps[i].text);
    if (a !== b) {
      const al = a.split('\n');
      const bl = b.split('\n');
      const j = al.findIndex((line, k) => line !== bl[k]);
      return `step-body drift at index ${i} (${tick(refNames[i])}): ` +
        `ci.yml line ${tick(al[j] ?? '(absent)')} vs evidence copy ${tick(bl[j] ?? '(absent)')}. ` +
        'The only tolerated body difference is the `-${{ matrix.repeat }}` artifact-name suffix ' +
        '(D-02 exception 1).';
    }
  }

  for (const cmd of LOAD_BEARING) {
    const inRef = refSteps.some((s) => s.text.includes(cmd));
    const inEv = evSteps.some((s) => s.text.includes(cmd));
    if (inRef !== inEv) {
      return `command drift: ${tick(cmd)} is present on ` +
        `${inRef ? `ci.yml#${REF_JOB}` : `${EVIDENCE_JOB}`} but absent on ` +
        `${inRef ? `${EVIDENCE_JOB}` : `ci.yml#${REF_JOB}`}`;
    }
  }

  return null;
}

const referenceBlock = jobBlock(stripYamlComments(readRepoFile(REFERENCE)), REF_JOB);
const evidenceBlock = jobBlock(stripYamlComments(readSubject(SUBJECT)), EVIDENCE_JOB);

test('the evidence job step list matches ci.yml generated_admin_playwright_smoke', () => {
  assert.ok(
    referenceBlock,
    `job \`${REF_JOB}\` not found in ${REFERENCE} — the parse broke, this is not a pass`,
  );
  assert.ok(
    evidenceBlock,
    `job \`${EVIDENCE_JOB}\` not found in the subject — the parse broke, this is not a pass`,
  );
  const issue = parityIssue(stepList(referenceBlock), stepList(evidenceBlock));
  assert.equal(issue, null, issue ?? '');
});

test('non-vacuity floor: both parses find steps and the acceptance-smoke invocation', () => {
  const refSteps = stepList(referenceBlock ?? '');
  const evSteps = stepList(evidenceBlock ?? '');
  assert.ok(
    refSteps.length > 0 && evSteps.length > 0,
    `the parse broke, this is not a pass — ref=${refSteps.length}, evidence=${evSteps.length}`,
  );
  const smoke = 'scripts/ci/admin-acceptance-smoke.sh --test all';
  assert.ok(
    refSteps.some((s) => s.text.includes(smoke)),
    `the parse broke, this is not a pass — ci.yml#${REF_JOB} yielded no acceptance-smoke step`,
  );
  assert.ok(
    evSteps.some((s) => s.text.includes(smoke)),
    'the parse broke, this is not a pass — the subject yielded no acceptance-smoke step',
  );
  assert.equal(
    parityIssue([], evSteps)?.startsWith('the parse broke'),
    true,
    'an empty parse must be reported as a failure, never as a pass',
  );
  assert.equal(
    parityIssue(refSteps, [])?.startsWith('the parse broke'),
    true,
    'an empty parse must be reported as a failure, never as a pass',
  );
});

test('negative control: the committed drift fixture fails the guard', () => {
  const fixture = stripYamlComments(
    readRepoFile('test/fixtures/prohibitions/p20-green-04-step-drift.yml'),
  );
  const fixtureBlock = jobBlock(fixture, EVIDENCE_JOB);
  assert.ok(fixtureBlock, `fixture is missing job \`${EVIDENCE_JOB}\` — the fixture, not the guard, is broken`);
  const fixtureSteps = stepList(fixtureBlock);
  assert.ok(
    fixtureSteps.length > 0,
    'the fixture must parse to a non-empty step list so its red comes from the clause under test, ' +
      'not from an empty parse',
  );
  const issue = parityIssue(stepList(referenceBlock ?? ''), fixtureSteps);
  assert.notEqual(
    issue,
    null,
    'a fixture with the `Install Playwright browsers` step deleted must fail the guard — a guard ' +
      'that only passes on the real file is not falsifiable',
  );
  assert.match(
    issue ?? '',
    /Install Playwright browsers/,
    'the failure must name the dropped step, not merely report a count',
  );
});
