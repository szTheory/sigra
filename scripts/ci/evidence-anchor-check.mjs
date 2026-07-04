#!/usr/bin/env node
/**
 * Phase 216 (HARNESS-FOUNDATION): evidence-anchor integrity check (D-09).
 *
 * For each captured bundle under test/example/priv/playwright/eval/<app_git_sha>/**\/,
 * reads dom.html + findings.json and asserts that every finding's structural
 * DOM anchor is present in the captured DOM (cheerio HTML-mode selection).
 *
 * A finding whose anchor is absent from the DOM fails CI — this makes
 * cite-and-flip impossible by construction (D-09): a finding must cite a
 * structural selector / data-* hook that resolves against the rendered output,
 * never a line number or prose description.
 *
 * Geometry-only finding classes (misalignment, below-fold, focus-ring) cannot
 * be re-evaluated here (no layout engine — D-09/D-11), but they MUST still carry
 * a structural anchor field. The presence of the anchor in the DOM is still
 * asserted; the geometry value itself is not re-checked.
 *
 * Security invariant (T-216-04-INJECT):
 *   - findings.json is JSON-parsed (never eval'd or shell-interpolated).
 *   - anchor runs through cheerio $() ONLY — never passed to eval/shell.
 *
 * Usage:
 *   node scripts/ci/evidence-anchor-check.mjs [--bundles-dir <path>]
 *
 * Exit codes:
 *   0 — all anchors present (or no bundles found)
 *   1 — one or more anchors absent
 *   2 — usage / argument error
 */

import { readFileSync, existsSync } from 'node:fs';
import { readdirSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// ---------------------------------------------------------------------------
// Resolve cheerio from the playwright subproject node_modules (D-09/Plan 01).
// cheerio is installed in test/example/priv/playwright/, not at the repo root.
// ---------------------------------------------------------------------------
const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');
const PW = path.join(ROOT, 'test', 'example', 'priv', 'playwright');
const _require = createRequire(path.join(PW, 'package.json'));
const { load: cheerioLoad } = _require('cheerio');

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
let bundlesDir = path.join(PW, 'eval');

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--bundles-dir') {
    bundlesDir = args[i + 1];
    i++;
  } else {
    console.error(`evidence-anchor-check: FAIL: unknown arg: ${args[i]}`);
    process.exit(2);
  }
}

// ---------------------------------------------------------------------------
// Anchor format validation — a valid anchor MUST look like a CSS selector or
// data-* hook, never plain prose or a line number. We reject anchors that:
//   - Are plain prose (natural-language phrase without selector syntax)
//   - Look like a file:line reference (path/to/file.ex:123)
//   - Are empty or whitespace-only
//
// A structural selector must start with one of:
//   - '.' (class selector)      e.g. .sg-btn
//   - '#' (id selector)         e.g. #surface-root
//   - '[' (attribute selector)  e.g. [data-testid="foo"]
//   - ':' (pseudo-class)        e.g. :root
//   - A single valid HTML tag name (e.g. "button", "div") — not multi-word prose
//
// CSS descendant combinator patterns (e.g. "div .sg-btn") are allowed, but
// prose phrases (e.g. "the Save button label") are rejected because:
//   - They start with a word that contains uppercase letters mid-sentence, OR
//   - They match the natural-language pattern (multiple space-separated plain words
//     without any selector-syntax character like '.', '#', '[', ':', '>')
//
// This is a structural check, not a full CSS parse.
// (D-09 + T-216-04-INJECT)
// ---------------------------------------------------------------------------

/**
 * Returns true if the anchor string looks like valid CSS selector syntax.
 * Returns false if it looks like prose or a line-number reference.
 */
function isStructuralAnchor(anchor) {
  if (typeof anchor !== 'string' || anchor.trim() === '') return false;
  const a = anchor.trim();

  // Reject source file:line references
  if (/\.(ex|exs|ts|tsx|js|jsx):\d+/.test(a)) return false;

  // Valid structural selectors must start with a selector-syntax character.
  // Allowed starting characters: . # [ : or a single bare HTML tag name.
  const firstChar = a[0];
  if (['.', '#', '[', ':'].includes(firstChar)) return true;

  // Bare HTML tag name — must be a single word matching known tag pattern,
  // optionally followed by CSS combinators and additional selectors.
  // Pattern: starts with a lowercase letter, can have alphanumeric/hyphen,
  // then optionally whitespace-combinator patterns or attribute/class/id suffixes.
  // Reject if the first "word" contains uppercase (likely prose, e.g. "the Save button").
  // After the tag name, a structural selector must be followed ONLY by selector
  // syntax characters — not arbitrary words with uppercase letters (prose).
  // The descendant combinator is a space, but only valid if what follows is a
  // selector token (.class, #id, [attr], :pseudo, tag-name), not uppercase prose.
  if (/^[a-z][a-z0-9-]*([.#\[: >~+*,]|$)/.test(a) && !/^[a-z][a-z0-9-]+\s+[A-Z]/.test(a)) return true;

  // Anything else (prose phrases, line numbers, descriptions) is rejected.
  return false;
}

// ---------------------------------------------------------------------------
// Geometry-only classes (D-09/D-11):
// These probes compute spatial facts (misalignment, below-fold position,
// focus-ring rendering) that require a live layout engine at capture time.
// The anchor-presence check still runs for these — we assert the anchor
// resolves in the DOM — but we do NOT re-check the geometry value here.
//
// Source of truth: the probe_class literals emitted by probes.ts (216-08).
// Real emitter strings: 'misalignment', 'focus-ring', 'below-fold-primary'.
// (The old entry 'below-fold' did not match any emitted class — replaced with
// 'below-fold-primary' so the geometry-note branch is reachable on real bundles.)
// ---------------------------------------------------------------------------
const GEOMETRY_ONLY_CLASSES = new Set([
  'misalignment',
  'below-fold-primary',
  'focus-ring',
]);

// ---------------------------------------------------------------------------
// Walk the bundles directory recursively, collecting all cell directories
// that contain both dom.html and findings.json.
// ---------------------------------------------------------------------------
function findBundleDirs(dir) {
  const results = [];
  if (!existsSync(dir)) return results;
  try {
    for (const entry of readdirSync(dir)) {
      const full = path.join(dir, entry);
      const stat = statSync(full);
      if (!stat.isDirectory()) continue;
      const domFile = path.join(full, 'dom.html');
      const findingsFile = path.join(full, 'findings.json');
      if (existsSync(domFile) && existsSync(findingsFile)) {
        results.push(full);
      } else {
        // Recurse into subdirectories
        results.push(...findBundleDirs(full));
      }
    }
  } catch (_) {
    // Directory not accessible — skip
  }
  return results;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
const bundleDirs = findBundleDirs(bundlesDir);

if (bundleDirs.length === 0) {
  console.log(`evidence-anchor-check: INFO: no bundles found under ${bundlesDir} — nothing to check`);
  process.exit(0);
}

let checkedFindings = 0;
let checkedBundles = 0;

for (const dir of bundleDirs) {
  checkedBundles++;
  const html = readFileSync(path.join(dir, 'dom.html'), 'utf8');
  const findingsRaw = readFileSync(path.join(dir, 'findings.json'), 'utf8');

  let findings;
  try {
    findings = JSON.parse(findingsRaw);
  } catch (err) {
    console.error(`evidence-anchor-check: FAIL: invalid JSON in ${path.join(dir, 'findings.json')}: ${err.message}`);
    process.exitCode = 1;
    continue;
  }

  if (!Array.isArray(findings)) {
    console.error(`evidence-anchor-check: FAIL: findings.json must be an array in ${dir}`);
    process.exitCode = 1;
    continue;
  }

  // Load the captured DOM in HTML mode (do NOT pass { xmlMode: true } — D-09).
  const $ = cheerioLoad(html);

  for (const finding of findings) {
    checkedFindings++;
    const { finding_id, anchor, class: probeClass, surface, probe_class: rawProbeClass } = finding;
    // Resolve the effective class string: D-22-enriched bundles carry 'class';
    // raw emitter shape (pre-enrichment) carries 'probe_class' only (W1, 216-08).
    const effectiveClass = probeClass || rawProbeClass;

    // Compute a stable finding reference for FAIL messages (W1, 216-08).
    // Use finding_id when present (D-22-enriched bundles); otherwise fall back to a
    // stable surface::class::anchor identifier so FAIL messages never print `undefined`.
    const findingRef = finding_id || [surface, effectiveClass, anchor].filter(Boolean).join('::');

    // Validate anchor format — must be a structural selector, never prose (D-09).
    if (!isStructuralAnchor(anchor)) {
      console.error(
        `evidence-anchor-check: FAIL: anchor is not a structural selector for ${findingRef}: ${JSON.stringify(anchor)}`
      );
      process.exitCode = 1;
      continue;
    }

    // Run the anchor through cheerio $() ONLY — never eval/shell-interpolated (T-216-04-INJECT).
    let matchCount;
    try {
      matchCount = $(anchor).length;
    } catch (err) {
      console.error(
        `evidence-anchor-check: FAIL: cheerio selector error for ${findingRef}: ${anchor} — ${err.message}`
      );
      process.exitCode = 1;
      continue;
    }

    if (matchCount === 0) {
      const geometryNote = GEOMETRY_ONLY_CLASSES.has(effectiveClass)
        ? ' (geometry-class finding: anchor must still resolve in DOM even though geometry value is not re-checked here)'
        : '';
      console.error(
        `evidence-anchor-check: FAIL: anchor absent for ${findingRef}: ${anchor}${geometryNote}`
      );
      process.exitCode = 1;
    }
  }
}

if (process.exitCode !== 1) {
  console.log(
    `evidence-anchor-check: PASS (${checkedBundles} bundle(s), ${checkedFindings} finding(s) checked)`
  );
}
