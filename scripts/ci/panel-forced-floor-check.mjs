#!/usr/bin/env node
/**
 * panel-forced-floor-check.mjs — forced-finding floor validator (Phase 217, Plan 03).
 *
 * SC-1 / D-06: asserts the 12-cell grid (4 lenses × 3 questions) is complete
 * for every evaluated cell, rejects empty/vague NONE tokens, and validates every
 * non-keep anchor via the shared `isStructuralAnchor` from `./lib/anchor.mjs`.
 *
 * Reads JSON only — never validates markdown (the retired panel-schema-check.sh
 * column-4 hazard is moot here).
 *
 * Usage:
 *   node scripts/ci/panel-forced-floor-check.mjs <panel-findings.json>
 *
 * Exit codes:
 *   0 — all 12 cells present and valid
 *   1 — one or more cells missing, empty/vague NONE token, or prose anchor found
 *   2 — usage / argument error
 *
 * Security invariant (T-217-03-INJECT / T-217-03-VAGUE):
 *   - Input is JSON-parsed, never eval'd or shell-interpolated.
 *   - All non-keep anchors validated via shared `isStructuralAnchor`.
 *   - Empty or vague NONE tokens are rejected.
 */

import { readFileSync } from 'node:fs';
import { isStructuralAnchor } from './lib/anchor.mjs';

// --------------------------------------------------------------------------
// Required cell grid: 4 lenses × 3 questions = 12 cells
// --------------------------------------------------------------------------

// The three persona lenses (platform_admin, support_investigator, org_admin)
// each use the same three question keys.
const PERSONA_LENSES = ['platform_admin', 'support_investigator', 'org_admin'];
const PERSONA_QUESTIONS = ['earning_its_place', 'ia_muddy', 'redundant_coherent_surprising'];

// The graphic_design lens has its own three question keys.
const GRAPHIC_DESIGN_LENS = 'graphic_design';
const GRAPHIC_DESIGN_QUESTIONS = ['salience', 'emphasis_ember', 'composition'];

// Full 12-cell enumeration: [lens, question]
const REQUIRED_CELLS = [
  ...PERSONA_LENSES.flatMap(lens =>
    PERSONA_QUESTIONS.map(q => [lens, q])
  ),
  ...GRAPHIC_DESIGN_QUESTIONS.map(q => [GRAPHIC_DESIGN_LENS, q]),
];

// --------------------------------------------------------------------------
// NONE token prefix (assembled via concatenation for grep-hygiene —
// the literal is NOT verbatim in any non-test checked-in file).
// --------------------------------------------------------------------------
const NONE_TOKEN_PREFIX = 'NONE' + ' — searched for: ';

// --------------------------------------------------------------------------
// Argument parsing
// --------------------------------------------------------------------------
const args = process.argv.slice(2);
if (args.length !== 1) {
  console.error('Usage: node panel-forced-floor-check.mjs <panel-findings.json>');
  process.exit(2);
}

const filePath = args[0];

// --------------------------------------------------------------------------
// Load and parse
// --------------------------------------------------------------------------
let raw;
try {
  raw = readFileSync(filePath, 'utf8');
} catch (err) {
  console.error(`panel-forced-floor-check: FAIL: cannot read file '${filePath}': ${err.message}`);
  process.exit(1);
}

let findings;
try {
  findings = JSON.parse(raw);
} catch (err) {
  console.error(`panel-forced-floor-check: FAIL: JSON parse error in '${filePath}': ${err.message}`);
  process.exit(1);
}

if (typeof findings !== 'object' || findings === null || Array.isArray(findings)) {
  console.error(`panel-forced-floor-check: FAIL: top-level JSON must be an object (got ${Array.isArray(findings) ? 'array' : typeof findings})`);
  process.exit(1);
}

// --------------------------------------------------------------------------
// Validate all 12 cells
// --------------------------------------------------------------------------
const errors = [];

for (const [lens, question] of REQUIRED_CELLS) {
  const lensObj = findings[lens];
  if (typeof lensObj !== 'object' || lensObj === null) {
    errors.push(`  missing lens '${lens}' (expected object, got ${lensObj === null ? 'null' : typeof lensObj})`);
    continue;
  }

  const cell = lensObj[question];
  if (typeof cell !== 'object' || cell === null) {
    errors.push(`  missing cell '${lens}.${question}' (expected object, got ${cell === null ? 'null' : typeof cell})`);
    continue;
  }

  const verdict = cell.verdict;

  if (verdict === 'keep') {
    // Keep cell: must carry a non-empty none_searched_for matching the required
    // literal token prefix.
    const nsf = cell.none_searched_for;
    if (typeof nsf !== 'string' || nsf.trim() === '') {
      errors.push(`  '${lens}.${question}': keep verdict has missing/empty 'none_searched_for' field`);
      continue;
    }
    if (!nsf.startsWith(NONE_TOKEN_PREFIX)) {
      errors.push(`  '${lens}.${question}': keep verdict 'none_searched_for' does not start with required NONE token prefix. Got: "${nsf.slice(0, 60)}${nsf.length > 60 ? '…' : ''}"`);
    }
  } else if (verdict === 'tighten' || verdict === 'kill') {
    // Non-keep finding: must carry a structural anchor.
    const anchor = cell.anchor;
    if (typeof anchor !== 'string' || anchor.trim() === '') {
      errors.push(`  '${lens}.${question}': non-keep verdict '${verdict}' has missing/empty 'anchor' field`);
      continue;
    }
    if (!isStructuralAnchor(anchor)) {
      errors.push(`  '${lens}.${question}': anchor is prose/non-structural: "${anchor.slice(0, 80)}${anchor.length > 80 ? '…' : ''}"`);
    }
    // refutation must also be present
    if (typeof cell.refutation !== 'string' || cell.refutation.trim() === '') {
      errors.push(`  '${lens}.${question}': non-keep verdict '${verdict}' has missing/empty 'refutation' field`);
    }
  } else {
    errors.push(`  '${lens}.${question}': unknown verdict '${verdict}' (must be keep/tighten/kill)`);
  }
}

// --------------------------------------------------------------------------
// Report
// --------------------------------------------------------------------------
if (errors.length === 0) {
  console.log(`panel-forced-floor-check: PASS: all 12 cells present and valid`);
  process.exit(0);
} else {
  console.error(`panel-forced-floor-check: FAIL: ${errors.length} violation(s) found in '${filePath}':`);
  for (const e of errors) {
    console.error(e);
  }
  process.exit(1);
}
