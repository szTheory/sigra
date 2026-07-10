#!/usr/bin/env node
/**
 * award-guard.test.mjs — hermetic self-test for award-guard.mjs.
 *
 * Creates a throwaway git repo, commits a base admin-award-ledger.json fixture,
 * mutates the working-tree ledger, runs award-guard.mjs --base <base_commit>,
 * and asserts exit code + stderr for each D-20 condition:
 *
 *   Case 1: axis A1→A2 with UNCHANGED verified_at_sha  → FAIL "climb without fresh render"
 *   Case 2: band typed A2 while axes min is A1          → FAIL "band != min"
 *   Case 3: axis raised with rendered:false             → FAIL "rendered is not true"
 *   Case 3b: raised axis with bogus evidence_ref        → FAIL "evidence_ref does not resolve"
 *   Case 4: axis A1→A0 (decrease)                      → FAIL "decreased vs merge-base"
 *   Case 5a: no-change                                  → PASS
 *   Case 5b: legit climb (A1→A2 + fresh sha + valid refs) → PASS
 *
 * Hermetic: the temp repo is cleaned up on exit; the real repo is unchanged.
 *
 * Usage:
 *   node scripts/ci/award-guard.test.mjs
 */

import { execSync, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const SCRIPT_DIR = dirname(__filename);
const REAL_GUARD = join(SCRIPT_DIR, 'award-guard.mjs');
const REAL_PROBE_IDS = join(SCRIPT_DIR, 'lib', 'eval-probe-ids.mjs');

// --------------------------------------------------------------------------
// Counters
// --------------------------------------------------------------------------
let PASS = 0;
let FAIL = 0;

function pass(msg) { console.log(`  PASS: ${msg}`); PASS++; }
function fail(msg) { console.error(`  FAIL: ${msg}`); FAIL++; }

// --------------------------------------------------------------------------
// Temp repo setup
// --------------------------------------------------------------------------
const TMPDIR_ROOT = mkdtempSync(join(tmpdir(), 'award-guard-test-'));

function cleanup() {
  try { rmSync(TMPDIR_ROOT, { recursive: true, force: true }); } catch (_) {}
}
process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(130); });
process.on('SIGTERM', () => { cleanup(); process.exit(143); });

const REPO = join(TMPDIR_ROOT, 'test-repo');
mkdirSync(REPO, { recursive: true });
mkdirSync(join(REPO, 'scripts', 'ci', 'lib'), { recursive: true });
mkdirSync(join(REPO, 'guides', 'reference'), { recursive: true });

// Git init
function git(...args) {
  return execSync(['git', '-C', REPO, ...args].join(' '), { encoding: 'utf8' });
}
git('init -q');
git('config user.email "test@award-guard.test"');
git('config user.name "Award Guard Self-Test"');

// Copy real guard + probe-ids lib into temp repo
copyFileSync(REAL_GUARD, join(REPO, 'scripts', 'ci', 'award-guard.mjs'));
copyFileSync(REAL_PROBE_IDS, join(REPO, 'scripts', 'ci', 'lib', 'eval-probe-ids.mjs'));

// --------------------------------------------------------------------------
// Base ledger fixture: one cell at A1/A1/A1/A1, band A1, verified_at_sha
// set to a stable value, rendered:true, resolving evidence_ref.
// --------------------------------------------------------------------------
const BASE_SHA = 'abc1234deadbeef';

const BASE_LEDGER = {
  schema_version: 1,
  notes: 'Test fixture for award-guard self-test.',
  cells: {
    'users-index-live': {
      axes: {
        token_fidelity: 'A1',
        rhythm: 'A1',
        a11y_polish: 'A1',
        states: 'A1',
      },
      band: 'A1',
      verified_at_sha: BASE_SHA,
      rendered: true,
      evidence_ref: ['probe:off-token-spacing', 'probe:focus-ring', 'test:assertUserResultEquivalence'],
    },
  },
};

const LEDGER_PATH = join(REPO, 'guides', 'reference', 'admin-award-ledger.json');

function writeLedger(obj) {
  writeFileSync(LEDGER_PATH, JSON.stringify(obj, null, 2) + '\n', 'utf8');
}

writeLedger(BASE_LEDGER);

// Stage and commit base
execSync(`git -C "${REPO}" add guides/reference/admin-award-ledger.json scripts/ci/award-guard.mjs "scripts/ci/lib/eval-probe-ids.mjs"`, { encoding: 'utf8' });
git('commit -q -m "baseline: users-index-live at A1"');
const BASE_COMMIT = git('rev-parse HEAD').trim();

// --------------------------------------------------------------------------
// Helper: run award-guard against base commit, return { code, stderr, stdout }
// --------------------------------------------------------------------------
function runGuard(ledgerObj) {
  writeLedger(ledgerObj);
  const result = spawnSync(process.execPath, [join(REPO, 'scripts', 'ci', 'award-guard.mjs'), '--base', BASE_COMMIT], {
    cwd: REPO,
    encoding: 'utf8',
    env: { ...process.env },
  });
  return {
    code: result.status,
    stderr: result.stderr ?? '',
    stdout: result.stdout ?? '',
  };
}

// Helper: restore ledger to base state (working tree matches committed fixture)
function restoreLedger() {
  writeLedger(BASE_LEDGER);
}

// --------------------------------------------------------------------------
// Case 1: axis A1→A2 with UNCHANGED verified_at_sha → FAIL "climb without fresh render"
// --------------------------------------------------------------------------
console.log('\nCase 1: axis A1→A2 with unchanged verified_at_sha → FAIL "climb without fresh render"');
{
  const ledger = JSON.parse(JSON.stringify(BASE_LEDGER));
  ledger.cells['users-index-live'].axes.a11y_polish = 'A2';
  // band and verified_at_sha left UNCHANGED (still BASE_SHA) — this triggers D-20a
  const r = runGuard(ledger);
  if (r.code !== 0) {
    pass('Guard exits non-zero on climb-without-render');
  } else {
    fail(`Guard exited 0 (expected non-zero) on climb-without-render; stdout: ${r.stdout}`);
  }
  if (r.stderr.includes('climb without fresh render')) {
    pass('Guard stderr contains "climb without fresh render"');
  } else {
    fail(`Guard stderr does not contain "climb without fresh render"; stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Case 2: band typed A2 while axes min is A1 → FAIL "band != min"
// --------------------------------------------------------------------------
console.log('\nCase 2: band typed A2 while axes min is A1 → FAIL "band != min"');
{
  const ledger = JSON.parse(JSON.stringify(BASE_LEDGER));
  // All axes stay at A1 but band is hand-typed as A2 — D-20b
  ledger.cells['users-index-live'].band = 'A2';
  const r = runGuard(ledger);
  if (r.code !== 0) {
    pass('Guard exits non-zero on band != min(axes)');
  } else {
    fail(`Guard exited 0 (expected non-zero) on band != min(axes); stdout: ${r.stdout}`);
  }
  if (r.stderr.includes('band != min(axes)')) {
    pass('Guard stderr contains "band != min(axes)"');
  } else {
    fail(`Guard stderr does not contain "band != min(axes)"; stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Case 3: axis raised with rendered:false → FAIL "rendered is not true"
// --------------------------------------------------------------------------
console.log('\nCase 3: raised axis with rendered:false → FAIL "rendered is not true"');
{
  const ledger = JSON.parse(JSON.stringify(BASE_LEDGER));
  ledger.cells['users-index-live'].axes.a11y_polish = 'A2';
  ledger.cells['users-index-live'].verified_at_sha = 'fresh-sha-999';  // changed
  ledger.cells['users-index-live'].rendered = false;  // D-20c: rendered:false
  // band stays A1 (min of A2+A1+A1+A1=A1 — still catches rendered:false before min check)
  // Actually to avoid the band!=min error let's keep band=A1 (unchanged min)
  const r = runGuard(ledger);
  if (r.code !== 0) {
    pass('Guard exits non-zero on raised axis with rendered:false');
  } else {
    fail(`Guard exited 0 (expected non-zero) on rendered:false; stdout: ${r.stdout}`);
  }
  if (r.stderr.includes('rendered is not true')) {
    pass('Guard stderr contains "rendered is not true"');
  } else {
    fail(`Guard stderr does not contain "rendered is not true"; stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Case 3b: raised axis with bogus evidence_ref → FAIL "evidence_ref does not resolve"
// --------------------------------------------------------------------------
console.log('\nCase 3b: raised axis with bogus evidence_ref → FAIL "evidence_ref does not resolve"');
{
  const ledger = JSON.parse(JSON.stringify(BASE_LEDGER));
  ledger.cells['users-index-live'].axes.a11y_polish = 'A2';
  ledger.cells['users-index-live'].verified_at_sha = 'fresh-sha-888';  // changed
  ledger.cells['users-index-live'].rendered = true;
  ledger.cells['users-index-live'].evidence_ref = ['probe:does-not-exist'];  // D-20c: bogus
  // band stays A1 (min of A2,A1,A1,A1=A1, no band!=min issue)
  const r = runGuard(ledger);
  if (r.code !== 0) {
    pass('Guard exits non-zero on unresolved evidence_ref');
  } else {
    fail(`Guard exited 0 (expected non-zero) on unresolved evidence_ref; stdout: ${r.stdout}`);
  }
  if (r.stderr.includes('evidence_ref does not resolve')) {
    pass('Guard stderr contains "evidence_ref does not resolve"');
  } else {
    fail(`Guard stderr does not contain "evidence_ref does not resolve"; stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Case 4: axis A1→A0 (decrease) → FAIL "decreased vs merge-base"
// --------------------------------------------------------------------------
console.log('\nCase 4: axis A1→A0 (decrease) → FAIL "decreased vs merge-base"');
{
  const ledger = JSON.parse(JSON.stringify(BASE_LEDGER));
  ledger.cells['users-index-live'].axes.rhythm = 'A0';  // D-20d: decrease
  // Update band to be min(A1,A0,A1,A1) = A0 so we don't get a band!=min error too
  ledger.cells['users-index-live'].band = 'A0';
  const r = runGuard(ledger);
  if (r.code !== 0) {
    pass('Guard exits non-zero on axis decrease');
  } else {
    fail(`Guard exited 0 (expected non-zero) on axis decrease; stdout: ${r.stdout}`);
  }
  if (r.stderr.includes('decreased vs merge-base')) {
    pass('Guard stderr contains "decreased vs merge-base"');
  } else {
    fail(`Guard stderr does not contain "decreased vs merge-base"; stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Case 5a: no-change → PASS
// --------------------------------------------------------------------------
console.log('\nCase 5a: no-change run → PASS');
{
  restoreLedger();
  const r = runGuard(BASE_LEDGER);
  if (r.code === 0) {
    pass('Guard exits 0 on no-change run');
  } else {
    fail(`Guard exited non-zero (${r.code}) on no-change run; stderr: ${r.stderr}`);
  }
  if (r.stdout.includes('PASS')) {
    pass('Guard stdout contains "PASS" on no-change run');
  } else {
    fail(`Guard stdout does not contain "PASS"; stdout: ${r.stdout}`);
  }
}

// --------------------------------------------------------------------------
// Case 5b: legitimate climb (A1→A2 + fresh verified_at_sha + resolving evidence) → PASS
// --------------------------------------------------------------------------
console.log('\nCase 5b: legitimate climb (A1→A2 + fresh sha + valid evidence) → PASS');
{
  const ledger = JSON.parse(JSON.stringify(BASE_LEDGER));
  // Raise a11y_polish: A1→A2
  ledger.cells['users-index-live'].axes.a11y_polish = 'A2';
  // band stays A1 (min of A2,A1,A1,A1 = A1) — correct derived value
  ledger.cells['users-index-live'].band = 'A1';
  // Fresh verified_at_sha
  ledger.cells['users-index-live'].verified_at_sha = 'new-fresh-sha-2025';
  // rendered:true, resolving evidence_ref
  ledger.cells['users-index-live'].rendered = true;
  ledger.cells['users-index-live'].evidence_ref = ['probe:focus-ring', 'probe:target-size', 'test:assertUserResultEquivalence'];
  const r = runGuard(ledger);
  if (r.code === 0) {
    pass('Guard exits 0 on legitimate climb');
  } else {
    fail(`Guard exited non-zero (${r.code}) on legitimate climb; stderr: ${r.stderr}`);
  }
  if (r.stdout.includes('PASS')) {
    pass('Guard stdout contains "PASS" on legitimate climb');
  } else {
    fail(`Guard stdout does not contain "PASS"; stdout: ${r.stdout}`);
  }
}

// --------------------------------------------------------------------------
// Summary
// --------------------------------------------------------------------------
console.log('\n----------------------------------------');
console.log(`Results: ${PASS} passed, ${FAIL} failed`);
console.log('----------------------------------------');

if (FAIL > 0) {
  console.error('award-guard.test: FAIL');
  process.exit(1);
}

console.log('award-guard.test: PASS');
process.exit(0);
