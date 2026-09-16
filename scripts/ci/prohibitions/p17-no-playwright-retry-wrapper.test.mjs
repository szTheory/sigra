// P17 (236-03-PLAN.md) — mechanical enforcement.
//
//   MUST NOT add a retry wrapper to the Playwright surface — `retries` above 0, a `retries`
//   value read from `process.env`, a per-project `retries:` override, `test.describe.configure({
//   retries ... })`, `page.waitForTimeout(`, or `test.slow(` — anywhere in
//   `test/example/priv/playwright/playwright.config.ts` or its specs. Recovering a failed
//   attempt masks the isolation evidence the flake investigation this phase performed depends
//   on (see 236-DIAGNOSIS.md and 236-EVIDENCE.md's reproduction difficulty section: 80
//   uncontended local attempts produced zero failures, 50 attempts under genuine CPU contention
//   produced 41 — a retry wrapper would have recovered the second attempt and re-labelled a
//   genuine, shipped product race as transient infrastructure noise).
//
// Subject: test/example/priv/playwright/playwright.config.ts (via GSD_PROHIB_SUBJECT).
// Secondary: every test/example/priv/playwright/tests/*.spec.ts, read from its real location —
// never through readSubject, since only ONE artifact is substitutable per the `_lib.mjs`
// contract.
//
// Comments are stripped first (`stripJsComments`), following `p02`'s precedent, made concrete
// here: `playwright.config.ts:15-16` documents its own compliance in prose — "Retries stay at
// zero everywhere; CI shard commands repeat --retries=0 explicitly" — and that sentence contains
// the literal word `retries`. A naive `/retries/` match would red the SHIPPED, compliant file
// precisely for explaining that it is correct. Every content assertion below therefore runs over
// comment-stripped text, never raw text.
//
// What silently breaks if this guard is deleted: a well-meant "just retry it" fix — wiring
// `PLAYWRIGHT_RETRIES` back in, adding `retries: 1`, or reaching for `waitForTimeout`/`test.slow`
// to paper over timing — would recover the flake into silence without fixing the underlying
// product race, and nothing would catch it before it landed on `main`.
//
// Six patterns, ALL applied to the SAME checker function against whatever text is given —
// deliberately NOT split into "config patterns" vs "spec patterns". The D-26 known-bad fixture
// packs all three violation flavors (process.env-sourced retries, waitForTimeout, test.slow)
// into ONE file standing in for the config via GSD_PROHIB_SUBJECT; a split checker that only ran
// "spec patterns" against the real, clean specs would leave the substituted fixture unable to go
// RED on those flavors, and the guard could never be observed red (standing constraint 6).
//
// This guard asserts nothing about `trace`. `trace` is not a retry wrapper, and a leftover
// diagnostic `trace: 'on'` from the 236-01 reproduction would red `fast_checks` during the very
// diagnosis this phase performs — that leak is caught by review, not by this guard.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { readSubject, readRepoFile, stripJsComments, REPO_ROOT } from './_lib.mjs';

const CONFIG_SUBJECT = 'test/example/priv/playwright/playwright.config.ts';
const SPEC_DIR = 'test/example/priv/playwright/tests';

const configText = stripJsComments(readSubject(CONFIG_SUBJECT));

function listSpecFiles() {
  const dir = resolve(REPO_ROOT, SPEC_DIR);
  return readdirSync(dir).filter((f) => f.endsWith('.spec.ts'));
}

const specFiles = listSpecFiles();
const specTexts = specFiles.map((name) => ({
  name,
  text: stripJsComments(readRepoFile(`${SPEC_DIR}/${name}`)),
}));

/**
 * Pure checker over ANY text — the config subject or a spec — for the six retry-wrapper
 * patterns. Returns `null` when clean, or a NAMED, explanatory string when it finds a wrapper.
 * Never returns a boolean: the message is what a reviewer reads to know what masking a fix
 * would introduce.
 */
function retryWrapperIssue(text) {
  if (/retries\s*:[^\n,}]*process\.env/.test(text)) {
    return (
      'a `retries` value is read from `process.env` — recovering a failed attempt via an ' +
      'env-controlled retry count masks the isolation evidence a flake investigation depends on'
    );
  }
  if (/test\.describe\.configure\(\s*\{\s*retries/.test(text)) {
    return (
      'a `test.describe.configure({ retries ... })` override reintroduces a retry wrapper at ' +
      'the suite level, bypassing the global `retries: 0`'
    );
  }
  if (/waitForTimeout\(/.test(text)) {
    return (
      'a `page.waitForTimeout(` call papers over timing instead of asserting on a real ' +
      'readiness signal — exactly the kind of masking a retry wrapper would also provide'
    );
  }
  if (/test\.slow\(/.test(text)) {
    return '`test.slow(` widens timeouts to hide a flake instead of fixing the underlying race';
  }
  const retriesLines = [...text.matchAll(/\bretries\s*:\s*([^\n,}]+)/g)];
  for (const m of retriesLines) {
    const value = m[1].trim();
    if (value !== '0') {
      return (
        `a \`retries:\` line has value \`${value}\`, not the required literal \`0\` — ` +
        'recovering a failed attempt masks the isolation evidence a flake investigation depends on'
      );
    }
  }
  return null;
}

test('the config parse locates a `retries:` line at all (non-vacuity floor)', () => {
  const found = [...configText.matchAll(/\bretries\s*:\s*[^\n,}]+/g)];
  assert.ok(
    found.length > 0,
    'no `retries:` line found in the config subject — the parse broke, this is not a pass',
  );
});

test('the spec walk finds at least 10 tests/*.spec.ts files (non-vacuity floor)', () => {
  assert.ok(
    specFiles.length >= 10,
    `spec walk found ${specFiles.length} spec files (there are 20 at HEAD) — the parse broke, ` +
      'this is not a pass',
  );
});

test('the config subject carries no retry wrapper', () => {
  const issue = retryWrapperIssue(configText);
  assert.equal(issue, null, issue ?? '');
});

test('no tests/*.spec.ts file carries a retry wrapper', () => {
  for (const { name, text } of specTexts) {
    const issue = retryWrapperIssue(text);
    assert.equal(issue, null, issue ? `${name}: ${issue}` : '');
  }
});

test('negative control: a fixture reintroducing a retry wrapper fails the guard', () => {
  const fixture = `
    export default defineConfig({
      retries: Number(process.env.PLAYWRIGHT_RETRIES ?? 1),
      use: {
        baseURL: 'http://localhost:4017',
      },
    });
    test('x', async ({ page }) => {
      await page.waitForTimeout(500);
      test.slow();
    });
  `;
  const issue = retryWrapperIssue(fixture);
  assert.ok(
    issue !== null,
    'a fixture that reintroduces a retry wrapper must fail the guard — a guard that only ' +
      'passes on the real file is not falsifiable',
  );
});
