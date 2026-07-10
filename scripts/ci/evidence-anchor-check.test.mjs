#!/usr/bin/env node
/**
 * Self-test for evidence-anchor-check.mjs (D-09 / T-216-04-CITE).
 *
 * Hermetic: creates a temporary bundle directory in os.tmpdir(), runs the
 * guard via child_process.spawnSync, and cleans up on exit. No files are
 * created in the real repo.
 *
 * Test cases:
 *   A: finding with a present anchor → exit 0  (guard does not false-fail)
 *   B: finding with an absent anchor → exit 1  (cite-and-flip caught)
 *   C: finding with a prose anchor (not a CSS selector) → exit 1
 *      (format rejection before cheerio; prevents selector injection and
 *       rejects ambiguous claims that could never be reproduced)
 *   D: geometry-only class (focus-ring) with a present anchor → exit 0
 *      (anchor still checked; geometry value not re-evaluated)
 *   E: geometry-only class (focus-ring) with an ABSENT anchor → exit 1
 *      (geometry findings still need a resolvable DOM anchor)
 */

import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const GUARD = path.resolve(path.dirname(__filename), 'evidence-anchor-check.mjs');

let pass = 0;
let fail = 0;
const tmpRoots = [];

process.on('exit', () => {
  for (const d of tmpRoots) {
    try { rmSync(d, { recursive: true, force: true }); } catch (_) {}
  }
});

function ok(label) { console.log(`  PASS: ${label}`); pass++; }
function ko(label) { console.error(`  FAIL: ${label}`); fail++; }

/**
 * Create a bundle directory with dom.html + findings.json.
 * Returns the bundles root dir path.
 */
function makeBundleDir(html, findings) {
  const root = mkdtempSync(path.join(tmpdir(), 'ev-anchor-test-'));
  tmpRoots.push(root);
  // Mimic: eval/<sha>/<surface>/<cell>/
  const bundleDir = path.join(root, 'eval', 'abc1234', 'users-index-live', 'light-desktop-populated');
  mkdirSync(bundleDir, { recursive: true });
  writeFileSync(path.join(bundleDir, 'dom.html'), html, 'utf8');
  writeFileSync(path.join(bundleDir, 'findings.json'), JSON.stringify(findings), 'utf8');
  return path.join(root, 'eval');
}

/**
 * Run the guard with a given bundles-dir and return { exitCode, stdout, stderr }.
 */
function runGuard(bundlesDir) {
  const result = spawnSync(process.execPath, [GUARD, '--bundles-dir', bundlesDir], {
    encoding: 'utf8',
  });
  return {
    exitCode: result.status ?? 1,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  };
}

// ---------------------------------------------------------------------------
// Test A: present anchor → exit 0
// ---------------------------------------------------------------------------
console.log('Test A: finding with present anchor exits 0');
{
  const html = `<html><body>
    <div data-testid="admin-users-desktop-results">
      <span class="sg-applied-chip">tag</span>
    </div>
  </body></html>`;
  const findings = [{
    finding_id: 'a'.repeat(64),
    surface: 'users-index-live',
    class: 'off-token-spacing',
    anchor: '[data-testid="admin-users-desktop-results"] .sg-applied-chip',
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 0) ok('present anchor exits 0');
  else ko(`present anchor expected exit 0, got ${exitCode}; stderr: ${stderr}`);
  if (!stderr.includes('FAIL')) ok('no FAIL in stderr for present anchor');
  else ko(`unexpected FAIL in stderr: ${stderr}`);
}

// ---------------------------------------------------------------------------
// Test B: absent anchor → exit 1
// ---------------------------------------------------------------------------
console.log('Test B: finding with absent anchor exits 1');
{
  const html = `<html><body>
    <div data-testid="admin-users-desktop-results">
      <span class="some-other-class">tag</span>
    </div>
  </body></html>`;
  const findings = [{
    finding_id: 'b'.repeat(64),
    surface: 'users-index-live',
    class: 'off-token-spacing',
    // .sg-applied-chip is NOT in the DOM above
    anchor: '[data-testid="admin-users-desktop-results"] .sg-applied-chip',
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 1) ok('absent anchor exits 1');
  else ko(`absent anchor expected exit 1, got ${exitCode}; stderr: ${stderr}`);
  if (stderr.includes('anchor absent')) ok('stderr contains "anchor absent"');
  else ko(`expected "anchor absent" in stderr; got: ${stderr}`);
}

// ---------------------------------------------------------------------------
// Test C: prose anchor (not a CSS selector) → exit 1
// A prose anchor like "the Save button label" cannot be a CSS selector.
// The guard must reject it before passing it to cheerio (D-09 format check +
// T-216-04-INJECT: anchors must be structural selectors only).
// ---------------------------------------------------------------------------
console.log('Test C: prose anchor (not a selector) exits 1');
{
  const html = `<html><body><button>Save</button></body></html>`;
  const findings = [{
    finding_id: 'c'.repeat(64),
    surface: 'users-index-live',
    class: 'off-token-spacing',
    // Prose, not a CSS selector — must be rejected
    anchor: 'the Save button label',
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 1) ok('prose anchor exits 1');
  else ko(`prose anchor expected exit 1, got ${exitCode}; stderr: ${stderr}`);
  if (stderr.includes('not a structural selector')) ok('stderr contains "not a structural selector"');
  else ko(`expected "not a structural selector" in stderr; got: ${stderr}`);
}

// ---------------------------------------------------------------------------
// Test D: geometry-only class (focus-ring) with PRESENT anchor → exit 0
// Even though focus-ring geometry cannot be re-evaluated here (D-09/D-11),
// the anchor must still resolve in the captured DOM.
// ---------------------------------------------------------------------------
console.log('Test D: geometry-only class (focus-ring) with present anchor exits 0');
{
  const html = `<html><body>
    <button class="sg-btn" data-testid="submit-btn">Submit</button>
  </body></html>`;
  const findings = [{
    finding_id: 'd'.repeat(64),
    surface: 'user-show-live',
    class: 'focus-ring',
    anchor: '.sg-btn[data-testid="submit-btn"]',
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 0) ok('geometry-only (focus-ring) with present anchor exits 0');
  else ko(`expected exit 0, got ${exitCode}; stderr: ${stderr}`);
  if (!stderr.includes('FAIL')) ok('no FAIL in stderr for geometry finding with present anchor');
  else ko(`unexpected FAIL in stderr: ${stderr}`);
}

// ---------------------------------------------------------------------------
// Test E: geometry-only class (focus-ring) with ABSENT anchor → exit 1
// Geometry findings must still have a structural anchor that resolves in the DOM.
// ---------------------------------------------------------------------------
console.log('Test E: geometry-only class (focus-ring) with absent anchor exits 1');
{
  const html = `<html><body>
    <button class="sg-btn">Submit</button>
  </body></html>`;
  const findings = [{
    finding_id: 'e'.repeat(64),
    surface: 'user-show-live',
    class: 'focus-ring',
    // .sg-btn--primary does NOT exist in the DOM above
    anchor: '.sg-btn--primary',
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 1) ok('geometry-only (focus-ring) with absent anchor exits 1');
  else ko(`expected exit 1, got ${exitCode}; stderr: ${stderr}`);
  if (stderr.includes('anchor absent')) ok('stderr contains "anchor absent" for geometry finding');
  else ko(`expected "anchor absent" in stderr; got: ${stderr}`);
}

// ---------------------------------------------------------------------------
// Test W1: raw emitter shape (no finding_id/class at top level) with absent anchor
// Proves the surface::class::anchor fallback fires and 'undefined' is never printed.
//
// The real probes.ts emitter (before D-22 enrichment) produces:
//   { probe_class, anchor, description, severity, ... }
// without a top-level `class` or `finding_id`. On absent anchors the guard must
// print a real identifier (the surface::probeClass::anchor fallback), never `undefined`.
//
// This validates the W1 fix in evidence-anchor-check.mjs (216-08).
// ---------------------------------------------------------------------------
console.log('Test W1: raw emitter shape (probe_class only, no finding_id/class) — no undefined id in FAIL');
{
  const html = `<html><body>
    <div data-testid="some-board">present</div>
  </body></html>`;
  // Raw probe finding shape: probe_class present, no top-level class/finding_id.
  // The anchor is absent from the DOM so we get a FAIL message.
  const findings = [{
    probe_class: 'off-token-spacing',
    surface: 'board-mg-5-populated',
    // NOTE: no 'class' or 'finding_id' at top level — this is the raw emitter shape
    anchor: '.sg-absent-element',
    description: 'padding off token scale',
    severity: 'gate',
    measured_px: [7],
    scale_px: [4, 8, 12, 16],
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 1) ok('W1: raw emitter shape absent anchor exits 1');
  else ko(`W1: expected exit 1, got ${exitCode}; stderr: ${stderr}`);
  // The FAIL message must NOT contain the literal string 'undefined'
  if (!stderr.includes('undefined')) ok('W1: FAIL message does not contain "undefined"');
  else ko(`W1: FAIL message printed undefined — guard did not apply fallback; stderr: ${stderr}`);
  // The FAIL message must contain the surface::class::anchor fallback pattern
  if (stderr.includes('board-mg-5-populated::off-token-spacing::.sg-absent-element')) {
    ok('W1: FAIL message contains surface::class::anchor fallback');
  } else {
    ko(`W1: expected surface::class::anchor fallback in stderr; got: ${stderr}`);
  }
}

// ---------------------------------------------------------------------------
// Test W2: geometry-note branch fires for below-fold-primary class (real emitter string)
// Proves GEOMETRY_ONLY_CLASSES contains 'below-fold-primary' (the real probe_class,
// not the old stale entry 'below-fold') so the geometry-note path is reachable on
// real bundles (W1, 216-08).
// ---------------------------------------------------------------------------
console.log('Test W2: geometry-note fires for below-fold-primary class (real emitter string)');
{
  const html = `<html><body>
    <div data-testid="some-board">present</div>
  </body></html>`;
  // Use the D-22-enriched shape: class=probe_class (as produced by enrichFindingsForBundle)
  const findings = [{
    finding_id: 'f'.repeat(64),
    surface: 'board-mg-5-populated',
    class: 'below-fold-primary',
    // Anchor is absent from the DOM so we get a FAIL + geometry-note
    anchor: '.sg-btn--primary',
    probe_class: 'below-fold-primary',
    description: 'primary action below fold',
    severity: 'warn',
    top_px: 1200,
    fold_px: 900,
  }];
  const bundlesDir = makeBundleDir(html, findings);
  const { exitCode, stderr } = runGuard(bundlesDir);
  if (exitCode === 1) ok('W2: below-fold-primary absent anchor exits 1');
  else ko(`W2: expected exit 1, got ${exitCode}; stderr: ${stderr}`);
  // The geometry-note parenthetical must appear in the FAIL message
  if (stderr.includes('geometry-class finding')) ok('W2: geometry-note appears in FAIL message for below-fold-primary');
  else ko(`W2: expected geometry-class note in stderr for below-fold-primary; got: ${stderr}`);
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('');
console.log('----------------------------------------');
console.log(`Results: ${pass} passed, ${fail} failed`);
console.log('----------------------------------------');

if (fail > 0) {
  console.error('evidence-anchor-check.test: FAIL');
  process.exit(1);
}
console.log('evidence-anchor-check.test: PASS');
process.exit(0);
