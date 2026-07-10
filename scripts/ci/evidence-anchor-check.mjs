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
import { isStructuralAnchor, GEOMETRY_ONLY_CLASSES } from './lib/anchor.mjs';

// ---------------------------------------------------------------------------
// Resolve cheerio from the playwright subproject node_modules (D-09/Plan 01).
// cheerio is installed in test/example/priv/playwright/, not at the repo root.
// ---------------------------------------------------------------------------
const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');
const PW = path.join(ROOT, 'test', 'example', 'priv', 'playwright');
const _require = createRequire(path.join(PW, 'package.json'));

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

// isStructuralAnchor and GEOMETRY_ONLY_CLASSES are imported from ./lib/anchor.mjs
// (Phase 217 Plan 01 extraction — keeps these shared for panel-forced-floor-check.mjs reuse)

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

// Resolve cheerio from the playwright subproject node_modules (D-09/Plan 01) —
// relocated to AFTER the no-bundles guard (Phase 220 D-10): a bundle-free
// fast_checks checkout must exit 0 above without cheerio being installed.
const { load: cheerioLoad } = _require('cheerio');

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
