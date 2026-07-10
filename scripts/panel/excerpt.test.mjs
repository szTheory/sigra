#!/usr/bin/env node
/**
 * excerpt.test.mjs — hermetic self-test for excerpt.mjs (Phase 217, Plan 05).
 *
 * Tests:
 *   1. Volatile attributes (data-phx-*, nonce, id^=phx-, csrf, ?vsn=) are stripped.
 *   2. Structural anchors (data-testid, data-sg-*, role, aria-label, semantic sg-* classes)
 *      are RETAINED so a subsequent evidence-anchor-check resolves them.
 *   3. Text-node length is capped deterministically; running excerpt twice on the same
 *      input yields byte-identical output (pure/deterministic).
 *
 * RED phase: all tests fail (excerpt.mjs does not exist yet).
 */

import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');

// Import the module under test (fails at RED phase because it doesn't exist yet)
let excerptHtml;
try {
  const mod = await import('./excerpt.mjs');
  excerptHtml = mod.excerptHtml;
} catch (err) {
  console.error('FAIL: excerpt.mjs not found or has errors:', err.message);
  process.exit(1);
}

let pass = 0;
let fail = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    pass++;
  } catch (err) {
    console.error(`  FAIL: ${name}: ${err.message}`);
    fail++;
  }
}

// ---------------------------------------------------------------------------
// Test 1: Volatile attributes are stripped
// ---------------------------------------------------------------------------
console.log('\nTest 1: volatile attribute stripping');

test('strips data-phx- attributes', () => {
  const html = '<div data-phx-session="abc123" data-phx-view="UserLive" class="sg-layout">hello</div>';
  const result = excerptHtml(html);
  assert.ok(!result.includes('data-phx-session'), 'data-phx-session should be stripped');
  assert.ok(!result.includes('data-phx-view'), 'data-phx-view should be stripped');
});

test('strips nonce attribute', () => {
  const html = '<script nonce="xyz789">window.foo=1;</script>';
  const result = excerptHtml(html);
  assert.ok(!result.includes('nonce='), 'nonce should be stripped');
  assert.ok(!result.includes('xyz789'), 'nonce value should be stripped');
});

test('strips id attributes that start with phx-', () => {
  const html = '<div id="phx-FhAaBbCc" data-testid="user-row">content</div>';
  const result = excerptHtml(html);
  assert.ok(!result.includes('phx-FhAaBbCc'), 'phx- id should be stripped');
});

test('strips csrf token meta tag (name=csrf-token)', () => {
  const html = '<meta name="csrf-token" content="deadbeef1234" />';
  const result = excerptHtml(html);
  assert.ok(!result.includes('deadbeef1234'), 'csrf token value should be stripped');
});

test('strips ?vsn= query parameters from href values', () => {
  const html = '<link href="/assets/app.css?vsn=abcdef12" rel="stylesheet"/>';
  const result = excerptHtml(html);
  assert.ok(!result.includes('vsn=abcdef12'), '?vsn= query param should be stripped');
});

// ---------------------------------------------------------------------------
// Test 2: Structural anchors are retained
// ---------------------------------------------------------------------------
console.log('\nTest 2: structural anchor retention');

test('retains data-testid attribute', () => {
  const html = '<button data-testid="submit-btn" class="sg-btn">Save</button>';
  const result = excerptHtml(html);
  assert.ok(result.includes('data-testid'), 'data-testid should be retained');
  assert.ok(result.includes('submit-btn'), 'data-testid value should be retained');
});

test('retains data-sg-* attributes', () => {
  const html = '<nav data-sg-surface="users-index" data-sg-variant="primary">nav</nav>';
  const result = excerptHtml(html);
  assert.ok(result.includes('data-sg-surface'), 'data-sg-surface should be retained');
  assert.ok(result.includes('users-index'), 'data-sg-surface value should be retained');
  assert.ok(result.includes('data-sg-variant'), 'data-sg-variant should be retained');
});

test('retains role attribute', () => {
  const html = '<div role="navigation" class="sg-nav">menu</div>';
  const result = excerptHtml(html);
  assert.ok(result.includes('role='), 'role attribute should be retained');
  assert.ok(result.includes('navigation'), 'role value should be retained');
});

test('retains aria-label attribute', () => {
  const html = '<button aria-label="Close dialog" class="sg-btn-icon">X</button>';
  const result = excerptHtml(html);
  assert.ok(result.includes('aria-label'), 'aria-label should be retained');
  assert.ok(result.includes('Close dialog'), 'aria-label value should be retained');
});

test('retains semantic sg-* classes', () => {
  const html = '<div class="sg-layout sg-surface data-phx-extra">content</div>';
  const result = excerptHtml(html);
  assert.ok(result.includes('sg-layout'), 'sg-layout class should be retained');
  assert.ok(result.includes('sg-surface'), 'sg-surface class should be retained');
});

test('structural anchor round-trip: [data-testid="user-row"] resolves after excerpting', () => {
  const html = `
    <table data-phx-session="abc">
      <tr data-testid="user-row" data-sg-variant="active" role="row" aria-label="User entry">
        <td class="sg-cell sg-cell--name">Alice</td>
      </tr>
    </table>`;
  const result = excerptHtml(html);
  // All structural anchors for evidence-anchor-check must survive
  assert.ok(result.includes('data-testid="user-row"'), 'data-testid must round-trip');
  assert.ok(result.includes('data-sg-variant'), 'data-sg-variant must round-trip');
  assert.ok(result.includes('role='), 'role must round-trip');
  assert.ok(result.includes('aria-label'), 'aria-label must round-trip');
  assert.ok(result.includes('sg-cell'), 'sg-* class must round-trip');
  // And volatile must be gone
  assert.ok(!result.includes('data-phx-session'), 'data-phx-session must be stripped');
});

// ---------------------------------------------------------------------------
// Test 3: Pure / deterministic (text cap, idempotent)
// ---------------------------------------------------------------------------
console.log('\nTest 3: determinism and text-length capping');

test('running excerptHtml twice on the same input yields byte-identical output', () => {
  const html = `
    <div data-phx-main="true" data-testid="main-layout" class="sg-layout">
      <h1 class="sg-heading" aria-label="Page title">Users</h1>
      <p>This is a long paragraph: ${'x'.repeat(500)}</p>
    </div>`;
  const result1 = excerptHtml(html);
  const result2 = excerptHtml(html);
  assert.strictEqual(result1, result2, 'excerptHtml must be deterministic (same input → same output)');
});

test('text node content is capped to prevent prompt bloat', () => {
  // A very long text node should be truncated in the output
  const longText = 'A'.repeat(2000);
  const html = `<p data-testid="long-text">${longText}</p>`;
  const result = excerptHtml(html);
  // The output should not contain the full 2000-char string
  assert.ok(result.length < 1500, `excerpt output should be capped (got ${result.length} chars for 2000-char input)`);
});

test('empty input returns empty-ish result without throwing', () => {
  const result = excerptHtml('');
  assert.ok(typeof result === 'string', 'empty input should return a string');
});

test('volatile-only DOM returns structurally minimal output', () => {
  const html = '<div data-phx-session="abc" id="phx-123" nonce="nnn"></div>';
  const result = excerptHtml(html);
  assert.ok(!result.includes('abc'), 'volatile session data must not appear');
  assert.ok(!result.includes('phx-123'), 'phx- id must not appear');
  assert.ok(!result.includes('nnn'), 'nonce value must not appear');
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log(`\nexcerpt.test.mjs: ${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
