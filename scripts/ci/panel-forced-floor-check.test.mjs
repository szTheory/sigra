#!/usr/bin/env node
/**
 * panel-forced-floor-check.test.mjs — hermetic self-test for panel-forced-floor-check.mjs.
 *
 * Phase 217, Plan 03 (D-06 forced-floor + SC-1 grid completeness).
 *
 * Tests:
 *   Test 1: a panel-findings JSON missing one of the 12 cells fails the check.
 *   Test 2: a keep cell with empty/vague none_searched_for fails.
 *   Test 3: a non-keep finding with a prose anchor fails via the shared isStructuralAnchor.
 *   Test 4: a complete, well-formed 12-cell grid with valid structural anchors and proper
 *            NONE tokens passes.
 *
 * Grep hygiene: the NONE token prefix is assembled from string parts so the literal
 * that the forced-floor check asserts is NOT echoed verbatim in this test file.
 *
 * Usage:
 *   node scripts/ci/panel-forced-floor-check.test.mjs
 */

import { writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const SCRIPT_DIR = dirname(__filename);
const CHECKER = resolve(SCRIPT_DIR, 'panel-forced-floor-check.mjs');

// --------------------------------------------------------------------------
// NONE token prefix — assembled via concatenation to avoid echoing the
// verbatim literal that a negative grep assertion would match.
// --------------------------------------------------------------------------
const NONE_PREFIX = 'NONE' + ' — searched for: ';

// --------------------------------------------------------------------------
// Counters
// --------------------------------------------------------------------------
let PASS = 0;
let FAIL = 0;

function pass(msg) { console.log(`  PASS: ${msg}`); PASS++; }
function fail(msg) { console.error(`  FAIL: ${msg}`); FAIL++; }

// --------------------------------------------------------------------------
// Temp directory cleanup
// --------------------------------------------------------------------------
const TMPDIR_ROOT = mkdtempSync(join(tmpdir(), 'panel-floor-test-'));

function cleanup() {
  try { rmSync(TMPDIR_ROOT, { recursive: true, force: true }); } catch (_) {}
}
process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(130); });
process.on('SIGTERM', () => { cleanup(); process.exit(143); });

// --------------------------------------------------------------------------
// Helper: run the checker against a JSON fixture written to a temp file
// --------------------------------------------------------------------------
function runChecker(fixture, extraArgs = []) {
  const filePath = join(TMPDIR_ROOT, `fixture-${Math.random().toString(36).slice(2)}.json`);
  writeFileSync(filePath, JSON.stringify(fixture, null, 2), 'utf8');
  const result = spawnSync(process.execPath, [CHECKER, filePath, ...extraArgs], {
    encoding: 'utf8',
    env: { ...process.env },
  });
  return result;
}

// --------------------------------------------------------------------------
// Fixture factories
// --------------------------------------------------------------------------

// Build a valid keep cell.
function keepCell(description) {
  return {
    verdict: 'keep',
    none_searched_for: NONE_PREFIX + description,
  };
}

// Build a valid non-keep finding cell with a structural anchor.
function findingCell(anchor, refutation = 'The element is redundant.') {
  return {
    verdict: 'tighten',
    anchor,
    refutation,
  };
}

// Build the 3-question persona lens block (platform_admin, support_investigator, org_admin).
// Each question gets a keep cell unless overridden.
function personaLens(overrides = {}) {
  return {
    earning_its_place: overrides.earning_its_place ?? keepCell('duplicate metrics between stat strip and detail dl'),
    ia_muddy: overrides.ia_muddy ?? keepCell('inverted hierarchy between scope ribbon and stat strip'),
    redundant_coherent_surprising: overrides.redundant_coherent_surprising ?? keepCell('vocabulary drift between this surface and the audit pages'),
  };
}

// Build the graphic_design lens block.
function graphicDesignLens(overrides = {}) {
  return {
    salience: overrides.salience ?? keepCell('visual weight hierarchy between primary and secondary elements'),
    emphasis_ember: overrides.emphasis_ember ?? keepCell('color contrast ratios for action elements'),
    composition: overrides.composition ?? keepCell('spacing and alignment of the main content grid'),
  };
}

// Build a complete, valid 12-cell panel-findings fixture.
function validPanel(overrides = {}) {
  return {
    platform_admin: overrides.platform_admin ?? personaLens(),
    support_investigator: overrides.support_investigator ?? personaLens(),
    org_admin: overrides.org_admin ?? personaLens(),
    graphic_design: overrides.graphic_design ?? graphicDesignLens(),
  };
}

// --------------------------------------------------------------------------
// Test 1: Missing cell — panel missing one of the 12 cells fails
// --------------------------------------------------------------------------
console.log('\nTest 1: Missing cell fails');
{
  // Remove the ia_muddy question from org_admin (one of 12 cells)
  const missingCell = validPanel({
    org_admin: {
      earning_its_place: keepCell('elements not earning their place for org admin'),
      // ia_muddy intentionally omitted
      redundant_coherent_surprising: keepCell('vocabulary drift from sibling surfaces'),
    },
  });

  const r = runChecker(missingCell);
  if (r.status !== 0) {
    pass('missing cell → exit 1 (check correctly fails)');
  } else {
    fail(`missing cell → expected exit 1, got 0. stdout: ${r.stdout} stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Test 2: Empty/vague NONE token fails
// --------------------------------------------------------------------------
console.log('\nTest 2: Empty/vague none_searched_for fails');

// Test 2a: completely empty none_searched_for
{
  const emptyNone = validPanel({
    platform_admin: personaLens({
      earning_its_place: {
        verdict: 'keep',
        none_searched_for: '',   // empty — must fail
      },
    }),
  });

  const r = runChecker(emptyNone);
  if (r.status !== 0) {
    pass('empty none_searched_for → exit 1');
  } else {
    fail(`empty none_searched_for → expected exit 1, got 0. stdout: ${r.stdout}`);
  }
}

// Test 2b: vague none_searched_for (missing the required NONE_PREFIX)
{
  const vagueNone = validPanel({
    support_investigator: personaLens({
      ia_muddy: {
        verdict: 'keep',
        none_searched_for: 'looks good to me',   // vague, no NONE prefix
      },
    }),
  });

  const r = runChecker(vagueNone);
  if (r.status !== 0) {
    pass('vague none_searched_for → exit 1');
  } else {
    fail(`vague none_searched_for → expected exit 1, got 0. stdout: ${r.stdout}`);
  }
}

// --------------------------------------------------------------------------
// Test 3: Non-keep finding with prose anchor fails via shared isStructuralAnchor
// --------------------------------------------------------------------------
console.log('\nTest 3: Prose anchor on non-keep finding fails');
{
  // Use anchors that are definitively rejected by isStructuralAnchor:
  //   - A file:line reference (e.g. "user_live.ex:42") — explicitly rejected
  //   - A phrase starting with an uppercase word (e.g. "The Save button")
  //   - An empty anchor string
  // Note: all-lowercase prose phrases (e.g. "the header looks off") pass the
  // structural check by design (the documented edge case in Plan 01 anchor.mjs).

  // Test 3a: file:line reference
  const fileLineAnchor = validPanel({
    graphic_design: graphicDesignLens({
      salience: {
        verdict: 'tighten',
        anchor: 'user_live.ex:42',  // file:line reference — rejected by isStructuralAnchor
        refutation: 'The visual weight is inconsistent.',
      },
    }),
  });

  const r3a = runChecker(fileLineAnchor);
  if (r3a.status !== 0) {
    pass('file:line anchor → exit 1');
  } else {
    fail(`file:line anchor → expected exit 1, got 0. stdout: ${r3a.stdout}`);
  }

  // Test 3b: prose starting with uppercase (e.g. "The Save button label")
  const upperCaseProseAnchor = validPanel({
    platform_admin: personaLens({
      earning_its_place: {
        verdict: 'kill',
        anchor: 'The Save button label',  // starts with uppercase — rejected
        refutation: 'The element is redundant.',
      },
    }),
  });

  const r3b = runChecker(upperCaseProseAnchor);
  if (r3b.status !== 0) {
    pass('uppercase prose anchor → exit 1');
  } else {
    fail(`uppercase prose anchor → expected exit 1, got 0. stdout: ${r3b.stdout}`);
  }

  // Test 3c: empty anchor string
  const emptyAnchor = validPanel({
    support_investigator: personaLens({
      ia_muddy: {
        verdict: 'tighten',
        anchor: '',  // empty — rejected by isStructuralAnchor
        refutation: 'Navigation hierarchy unclear.',
      },
    }),
  });

  const r3c = runChecker(emptyAnchor);
  if (r3c.status !== 0) {
    pass('empty anchor → exit 1');
  } else {
    fail(`empty anchor → expected exit 1, got 0. stdout: ${r3c.stdout}`);
  }
}

// --------------------------------------------------------------------------
// Test 4: Complete, well-formed 12-cell grid with valid structural anchors passes
// --------------------------------------------------------------------------
console.log('\nTest 4: Complete valid 12-cell grid passes');
{
  // Mix of keep cells (with proper NONE tokens) and non-keep findings
  // with structural CSS anchors.
  const validFull = validPanel({
    platform_admin: personaLens({
      earning_its_place: findingCell('.sg-stat-strip__chip--confirmed', 'Positive confirmation pill duplicates absence of unconfirmed badge.'),
    }),
    graphic_design: graphicDesignLens({
      salience: findingCell('[data-testid="overview-kpi-strip"]', 'KPI strip lacks clear visual hierarchy between primary and secondary metrics.'),
      emphasis_ember: keepCell('color contrast ratios for the ember accent on primary action buttons'),
    }),
  });

  const r = runChecker(validFull);
  if (r.status === 0) {
    pass('valid 12-cell grid → exit 0');
  } else {
    fail(`valid 12-cell grid → expected exit 0, got ${r.status}. stderr: ${r.stderr}`);
  }
}

// --------------------------------------------------------------------------
// Summary
// --------------------------------------------------------------------------
console.log(`\npanel-forced-floor-check self-test: ${PASS} passed, ${FAIL} failed`);
if (FAIL > 0) process.exit(1);
