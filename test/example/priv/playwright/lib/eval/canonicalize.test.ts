/**
 * canonicalize.test.ts — determinism self-test for renderSha256.
 *
 * Runnable via: npx tsx lib/eval/canonicalize.test.ts
 * (no Playwright browser needed — pure Node)
 *
 * Covers every bullet in the Plan 216-03 Task 1 <behavior>:
 *  1. Same outerHTML canonicalized twice → identical sha256.
 *  2. Mutating data-phx-id / data-phx-session / phx-* → SAME sha.
 *  3. Changing nonce / integrity / ?vsn= / digest fingerprint → SAME sha.
 *  4. Reordering attributes → SAME sha.
 *  5. Reordering class tokens → SAME sha.
 *  6. Adding/removing whitespace-only text nodes / collapsing whitespace → SAME sha.
 *  7. Genuine structural/semantic change → DIFFERENT sha.
 */

import { renderSha256 } from './canonicalize.ts';
import assert from 'node:assert/strict';

let passed = 0;
let failed = 0;

function test(name: string, fn: () => void): void {
  try {
    fn();
    console.log(`  PASS  ${name}`);
    passed++;
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error(`  FAIL  ${name}\n         ${msg}`);
    failed++;
  }
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const BASE_HTML = `<div role="navigation" class="sg-nav b-class" data-testid="main-nav">
  <a href="/admin/users?vsn=abc123&page=1" class="sg-link">Users</a>
  <span aria-label="badge">3</span>
</div>`;

const BASE_HTML_EXTRA_WS = `<div role="navigation" class="sg-nav b-class" data-testid="main-nav">

  <a href="/admin/users?vsn=abc123&page=1" class="sg-link">Users</a>
    <span aria-label="badge">  3  </span>

</div>`;

// ── Test 1: Same HTML twice → same SHA ────────────────────────────────────────
test('same outerHTML canonicalized twice → identical sha256', () => {
  const sha1 = renderSha256(BASE_HTML);
  const sha2 = renderSha256(BASE_HTML);
  assert.equal(sha1, sha2, 'Expected identical SHAs for identical input');
  assert.match(sha1, /^[0-9a-f]{64}$/, 'Expected 64-char lowercase hex');
});

// ── Test 2: Volatile LiveView attrs → SAME sha ───────────────────────────────
test('mutating data-phx-id value → SAME sha (volatile stripped)', () => {
  const html1 = `<div data-phx-id="phx-abc" data-testid="target">Hello</div>`;
  const html2 = `<div data-phx-id="phx-xyz-changed" data-testid="target">Hello</div>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

test('mutating data-phx-session value → SAME sha', () => {
  const html1 = `<div data-phx-session="sess1" data-testid="target">Hello</div>`;
  const html2 = `<div data-phx-session="sess2-changed" data-testid="target">Hello</div>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

test('mutating phx-* attr value → SAME sha', () => {
  const html1 = `<button phx-click="save" data-testid="btn">Save</button>`;
  const html2 = `<button phx-click="save_v2" data-testid="btn">Save</button>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

// ── Test 3: nonce / integrity / ?vsn= / digest → SAME sha ────────────────────
test('changing nonce value → SAME sha', () => {
  const html1 = `<script nonce="abc123">var x=1</script>`;
  const html2 = `<script nonce="xyz-changed">var x=1</script>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

test('changing integrity value → SAME sha', () => {
  const html1 = `<link integrity="sha256-abc" href="/app.css">`;
  const html2 = `<link integrity="sha256-xyz-changed" href="/app.css">`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

test('?vsn= fingerprint in href → SAME sha', () => {
  const html1 = `<a href="/app.js?vsn=abc123de" data-testid="link">JS</a>`;
  const html2 = `<a href="/app.js?vsn=xyz999ff" data-testid="link">JS</a>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

test('32-hex digest in href → SAME sha', () => {
  const html1 = `<a href="/app-abcdef1234567890abcdef1234567890.js" data-testid="link">JS</a>`;
  const html2 = `<a href="/app-9999999999999999aaaaaaaaaaaaaaaa.js" data-testid="link">JS</a>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

// ── Test 4: Attribute reordering → SAME sha ──────────────────────────────────
test('reordering attributes on an element → SAME sha', () => {
  const html1 = `<input type="text" name="email" role="textbox" aria-label="Email">`;
  const html2 = `<input aria-label="Email" role="textbox" name="email" type="text">`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

// ── Test 5: Class token reordering → SAME sha ────────────────────────────────
test('reordering class tokens → SAME sha', () => {
  const html1 = `<div class="sg-btn sg-btn--primary active" data-testid="submit">OK</div>`;
  const html2 = `<div class="active sg-btn--primary sg-btn" data-testid="submit">OK</div>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

// ── Test 6: Whitespace normalization → SAME sha ──────────────────────────────
test('adding whitespace-only text nodes → SAME sha', () => {
  const sha1 = renderSha256(BASE_HTML);
  const sha2 = renderSha256(BASE_HTML_EXTRA_WS);
  assert.equal(sha1, sha2, 'Extra whitespace should not change sha');
});

test('collapsing whitespace runs in text → SAME sha', () => {
  const html1 = `<span data-testid="label">Hello   World</span>`;
  const html2 = `<span data-testid="label">Hello World</span>`;
  assert.equal(renderSha256(html1), renderSha256(html2));
});

// ── Test 7: Genuine structural change → DIFFERENT sha ────────────────────────
test('different tag name → DIFFERENT sha', () => {
  const html1 = `<div data-testid="content">Hello</div>`;
  const html2 = `<span data-testid="content">Hello</span>`;
  assert.notEqual(renderSha256(html1), renderSha256(html2));
});

test('different data-testid value → DIFFERENT sha', () => {
  const html1 = `<div data-testid="original-id">Hello</div>`;
  const html2 = `<div data-testid="changed-id">Hello</div>`;
  assert.notEqual(renderSha256(html1), renderSha256(html2));
});

test('different aria-label → DIFFERENT sha', () => {
  const html1 = `<button aria-label="Close dialog" data-testid="close">X</button>`;
  const html2 = `<button aria-label="Open dialog" data-testid="close">X</button>`;
  assert.notEqual(renderSha256(html1), renderSha256(html2));
});

test('added visible text content → DIFFERENT sha', () => {
  const html1 = `<div data-testid="count">5 users</div>`;
  const html2 = `<div data-testid="count">10 users</div>`;
  assert.notEqual(renderSha256(html1), renderSha256(html2));
});

test('added child element → DIFFERENT sha', () => {
  const html1 = `<ul data-testid="list"><li>Item 1</li></ul>`;
  const html2 = `<ul data-testid="list"><li>Item 1</li><li>Item 2</li></ul>`;
  assert.notEqual(renderSha256(html1), renderSha256(html2));
});

// ── Summary ───────────────────────────────────────────────────────────────────
console.log('');
console.log(`canonicalize.test.ts: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  process.exit(1);
}
