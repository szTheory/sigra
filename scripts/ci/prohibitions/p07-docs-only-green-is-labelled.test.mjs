// P7 (230-05-PLAN.md) — mechanical enforcement.
//
//   MUST NOT report a required context green on a docs-only PR without recording, in the
//   durable honest-skip artifact, exactly what was skipped and what still ran; a green that
//   asserted nothing must be labelled as such.
//
// Subject: MAINTAINING.md (substitutable via GSD_PROHIB_SUBJECT).
// Secondary: .github/ci-skip-manifest.tsv and .github/workflows/ci.yml.
//
// Two obligations, both checkable: the durable artifact must ENUMERATE the skip set (and
// agree with the machine-readable manifest), and the run itself must SAY SO in its own log
// via the D-23 all_skipped line — so a green context that asserted nothing is labelled in
// the one place a reader actually looks.
//
// ROT-SURFACE BAN. This guard also refuses the three drift shapes that had already crept
// into MAINTAINING.md before Phase 230 closed: `ci.yml:<line>` citations (two of the three
// present were already wrong), a hardcoded ExUnit file count, and a hardcoded job duration.
// Deleting a rot surface beats validating it: a line-number validator can only prove a line
// EXISTS, never that it still means what the prose claims.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, parseSkipManifest, stripYamlComments } from './_lib.mjs';

const doc = readSubject('MAINTAINING.md');
const SECTION_RE = /### Honest-skip set after Phase 230[\s\S]*?(?=\n#### |\n### |$)/;

test('the honest-skip section exists and is substantive', () => {
  const section = doc.match(SECTION_RE);
  assert.ok(
    section,
    'MAINTAINING.md has no `### Honest-skip set after Phase 230` section. Without the durable ' +
      'artifact, a docs-only PR reports five green required contexts and nothing anywhere ' +
      'records that they asserted nothing.',
  );
  assert.ok(
    section[0].length > 800,
    `the honest-skip section is only ${section[0].length} characters — too short to enumerate ` +
      `three tiers. A section header with no content is not a record.`,
  );
});

test('all three tiers are enumerated', () => {
  const section = doc.match(SECTION_RE)[0];
  for (const tier of ['Tier A', 'Tier B', 'Tier C']) {
    assert.ok(
      section.includes(tier),
      `the honest-skip section does not enumerate ${tier}. Tier A/B are event-gated and Tier C ` +
        `is diff-gated — collapsing them loses the distinction between "skipped because of the ` +
        `event" and "skipped because of the diff", which are different audit questions.`,
    );
  }
  assert.ok(
    /fail-open/i.test(section),
    'the section does not state the fail-open polarity. A reader who assumes fail-closed will ' +
      'misjudge every skip in the list.',
  );
});

test('the prose enumerates the same tier-B constructs as the manifest', () => {
  const section = doc.match(SECTION_RE)[0];
  const tierB = parseSkipManifest(readRepoFile('.github/ci-skip-manifest.tsv'))
    .filter((r) => r.tier === 'B');
  assert.ok(tierB.length >= 2, `manifest yielded ${tierB.length} tier-B rows — the parse broke.`);
  for (const r of tierB) {
    assert.ok(
      section.includes(r.id),
      `tier-B construct \`${r.id}\` is in the machine-readable manifest but not in the prose ` +
        `enumeration. Prose is meant to RENDER the manifest; when they disagree there are two ` +
        `oracles and no way to tell which rotted.`,
    );
  }
});

test('the run labels a docs-only green in its own log', () => {
  const ci = stripYamlComments(readRepoFile('.github/workflows/ci.yml'));
  assert.match(
    ci,
    /docs-only fast path: every Playwright seam was skipped/,
    'the seam aggregator no longer emits the D-23 docs-only line. That line is what makes a ' +
      'green context which asserted nothing SAY SO in its own log, and it is Phase 231 ' +
      "GATE-03's designated input for telling a correct skip from a rotted one.",
  );
});

test('no line-number, file-count or duration rot surface is reintroduced', () => {
  const scoped = doc.match(SECTION_RE)[0];
  const lineCitations = [...scoped.matchAll(/ci\.yml:\d+/g)].map((m) => m[0]);
  assert.deepEqual(
    lineCitations,
    [],
    `the honest-skip section cites ci.yml by line number: ${JSON.stringify(lineCitations)}. Two ` +
      `of the three such citations that shipped were ALREADY WRONG. Cite the job id, the step ` +
      `id, or the quoted literal — anchors that move with the code.`,
  );
  const counts = [...scoped.matchAll(/\b\d+ ExUnit files\b/g)].map((m) => m[0]);
  assert.deepEqual(
    counts,
    [],
    `the section hardcodes an ExUnit file count: ${JSON.stringify(counts)}. It was written as ` +
      `"13" and was 14 within one phase. Describe the directory, not the census.`,
  );
  const durations = [...scoped.matchAll(/~\d+\s*min\b/g)].map((m) => m[0]);
  assert.deepEqual(
    durations,
    [],
    `the section hardcodes a job duration: ${JSON.stringify(durations)}. The shipped one said ` +
      `"~60 min" for a job whose ceiling is now 15 and which measures under 4. Point at ` +
      `\`timeout-minutes\` instead.`,
  );
});
