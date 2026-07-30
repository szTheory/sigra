// P14 (231-04-PLAN.md) — mechanical enforcement.
//
//   MUST NOT reintroduce a string-method call on `el.className` anywhere in the eval probe
//   source. `className` is an `SVGAnimatedString` (not a plain string) on SVG elements, so
//   `el.className.includes(...)` (or any other string method on that same property chain)
//   throws `TypeError: el.className.includes is not a function` the moment the probe's
//   candidate scan reaches an SVG node. That crash is what clustered the chromium/dark
//   failures on `board-mg-2` (all four states) plus `board-summary_chip` and
//   `board-field_help` on push run `30472016250` — `probes.ts:380`'s
//   `el.className.includes('ember')`, fixed by this same plan to derive from `classList`.
//
// Subject: test/example/priv/playwright/lib/eval/probes.ts (via GSD_PROHIB_SUBJECT).
//
// What this guard proves: no `<expr>.className` property-access chain in the probe source is
// immediately followed by a `.<method>()` call. It is purely static analysis over one file's
// text.
//
// What this guard deliberately does NOT cover: whether the fix is behaviourally correct
// against a real SVG element in a real browser. That is the `admin-eval-mobile` project
// passing in CI (Playwright's iPhone 13 / WebKit project, plus the chromium/dark boards this
// crash actually hit) — plan 231-05 observes that run and reads its result. This guard cannot
// substitute for that observation; it only makes the specific crash class non-reintroducible
// without CI noticing.
//
// What silently breaks if this guard is deleted: a future edit re-adds (or a similar new
// probe adds) a string method on `el.className`, every SVG-bearing board in the render matrix
// reds at harness phase (a), and the failure surfaces as a wall of probe-crash noise that
// looks like real design-token findings rather than the one-line TypeError it actually is —
// exactly the unread-red pattern this phase exists to remove.
//
// ANTI-VACUITY / D-12 NEGATIVE CONTROL. `probes.ts:176` and `:237` both read `.className` for
// truthiness only, inside a ternary, and neither throws. D-12 names those two lines explicitly
// as NOT the bug and instructs that they not be "fixed". A guard that only asserts the crash
// pattern is absent would pass just as well against a gutted or renamed file with no
// `className` in it at all — so this file also asserts those two safe reads are still present,
// making the guard falsifiable in both directions.
//
// WHY A LOCAL, LINE-PRESERVING COMMENT STRIPPER INSTEAD OF `_lib.mjs`'s `stripJsComments`.
// `stripJsComments` removes block comments with `.replace(/\/\*[\s\S]*?\*\//g, '')` BEFORE
// splitting into lines, which collapses embedded newlines and changes the file's total line
// count (884 raw vs 761 stripped, measured against this file) — useless for reporting an
// offending LINE NUMBER, which this guard's failure message needs. `_lib.mjs` is also outside
// this plan's `files_modified` fence, so it is not extended here. The stripper below walks the
// subject one line at a time, tracks in-block-comment state across lines, and always emits
// exactly one output line per input line.
//
// WHY THE VIOLATION PATTERN REQUIRES A LEADING DOT. `probes.ts` (Probe #8, `card-in-card`,
// lines ~709-746, pre-existing and out of this plan's scope) destructures a LOCAL variable
// also named `className` from `element.getAttribute('class') ?? ''` — always a plain string,
// never `SVGAnimatedString` — and calls `.split(' ')` on it. A bare `className\s*\.\s*\w+`
// pattern matches that safe local-variable call too, which is a false positive: the crash this
// guard exists to catch is specifically a PROPERTY-ACCESS CHAIN (`<expr>.className.method()`),
// never a bare identifier. Requiring a leading `.` before `className` distinguishes the two
// syntactically without needing type information.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject } from './_lib.mjs';

const SUBJECT = 'test/example/priv/playwright/lib/eval/probes.ts';

/**
 * Strip `//` and `/* *\/` comments from `text`, one line at a time, so the output has
 * EXACTLY the same number of lines as the input (block comments are blanked in place, never
 * removed wholesale) and offending matches can be mapped back to a real line number.
 */
function stripCommentsLinePreserving(text) {
  const lines = text.split('\n');
  let inBlockComment = false;
  const out = [];
  for (const line of lines) {
    let result = '';
    let i = 0;
    let inSingle = false;
    let inDouble = false;
    let inTick = false;
    while (i < line.length) {
      if (inBlockComment) {
        const end = line.indexOf('*/', i);
        if (end === -1) { i = line.length; continue; }
        inBlockComment = false;
        i = end + 2;
        continue;
      }
      const ch = line[i];
      if (!inSingle && !inDouble && !inTick && ch === '/' && line[i + 1] === '/') break;
      if (!inSingle && !inDouble && !inTick && ch === '/' && line[i + 1] === '*') {
        const end = line.indexOf('*/', i + 2);
        if (end === -1) { inBlockComment = true; i = line.length; continue; }
        i = end + 2;
        continue;
      }
      if (ch === '\\' && (inSingle || inDouble)) {
        result += ch + (line[i + 1] ?? '');
        i += 2;
        continue;
      }
      if (ch === "'" && !inDouble && !inTick) inSingle = !inSingle;
      else if (ch === '"' && !inSingle && !inTick) inDouble = !inDouble;
      else if (ch === '`' && !inSingle && !inDouble) inTick = !inTick;
      result += ch;
      i += 1;
    }
    out.push(result);
  }
  return out.join('\n');
}

function lineAt(text, index) {
  return text.slice(0, index).split('\n').length;
}

const rawSubject = readSubject(SUBJECT);
const subject = stripCommentsLinePreserving(rawSubject);

// A property-access `.className` — the leading dot is what distinguishes an element property
// read from Probe #8's unrelated local variable of the same bare name (see header comment).
const CLASSNAME_PROPERTY_RE = /\.className\b/g;
// The crash pattern: a `.className` property read immediately followed by a further
// `.<identifier>` — i.e. a method or property call chained directly off it.
const VIOLATION_RE = /\.className\s*\.\s*[A-Za-z_][A-Za-z0-9_]*/g;

test('parse floor: the subject contains at least two `.className` property reads', () => {
  const occurrences = [...subject.matchAll(CLASSNAME_PROPERTY_RE)];
  assert.ok(
    occurrences.length >= 2,
    `found ${occurrences.length} \`.className\` property-access occurrences in ${SUBJECT}; ` +
      `expected at least 2 (the two safe reads at ~lines 176 and 237) -- the parse broke, this ` +
      `is not a pass.`,
  );
});

test('no `.className` property read is followed by a string-method invocation', () => {
  const violations = [...subject.matchAll(VIOLATION_RE)].map((m) => ({
    line: lineAt(subject, m.index),
    text: m[0],
  }));
  assert.deepEqual(
    violations,
    [],
    `found ${violations.length} \`.className\` read(s) immediately followed by a method call: ` +
      `${violations.map((v) => `line ${v.line}: \`${v.text}\``).join('; ')}. \`className\` is an ` +
      `SVGAnimatedString (not a plain string) on SVG elements -- a string method there throws ` +
      `TypeError the moment the probe scan reaches an SVG node. Derive from \`classList\` ` +
      `instead (a DOMTokenList on both HTML and SVG elements).`,
  );
});

test('D-12 negative control: the two safe truthiness reads at ~176 and ~237 survive', () => {
  const safeReads = [...subject.matchAll(CLASSNAME_PROPERTY_RE)].filter((m) => {
    const after = subject.slice(m.index + m[0].length);
    return !/^\s*\.\s*[A-Za-z_]/.test(after);
  });
  assert.ok(
    safeReads.length >= 2,
    `found ${safeReads.length} \`.className\` reads not followed by a method call; expected at ` +
      `least 2. D-12 names \`probes.ts:176\` and \`:237\` explicitly as reads that must NOT be ` +
      `"fixed" -- both read \`.className\` for truthiness only, inside a ternary, and neither ` +
      `throws. Without this negative control, the guard above would pass just as well against a ` +
      `gutted or renamed file with no \`.className\` reads left in it at all, which is exactly ` +
      `the vacuous-green failure mode this milestone exists to remove.`,
  );
});
