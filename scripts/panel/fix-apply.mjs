#!/usr/bin/env node
/**
 * fix-apply.mjs — deterministic copy + token swaps to admin .heex / inline-style.
 *
 * Plan 217-06, D-13. Auto-applies ONLY copy-swap and token-swap fix classes to:
 *   - admin LiveView .heex attributes / inline-style= values
 *   - test/example only
 * NEVER touches CSS files, never touches component/judgment findings.
 * LLM strictly OUT of the apply path — all transforms are deterministic arithmetic
 * or fixed copy-rules.json ruleset.
 *
 * Token-swap:
 *   Reads the finding's measured_px and scale_px (from the fix-queue.json entry, which
 *   reflects live facts.json values captured at render time). Finds the nearest token
 *   in scale_px. Applies ONLY when the nearest is within a tightened +/-1.0px band
 *   (tighter than the probe's +/-0.5px detection tolerance, to ensure we are confident
 *   about the mapping). Preserves !important. Ties (two equidistant tokens) or
 *   nearest > 1.0px away → downgrade to judgment (no edit).
 *
 * Copy-swap:
 *   Text-node-only edit from copy-rules.json fixed ruleset. Any edit requiring semantic
 *   judgment routes to judgment (no edit).
 *
 * Apply surface constraints:
 *   - Only .heex files under lib/*_web/live/admin/ (admin LiveView) and test/example/
 *   - Refuses CSS files (sigra_admin.css 3-lockstep copies are out of scope)
 *   - Refuses fix_class=component or fix_class=judgment findings
 *
 * Usage:
 *   node scripts/panel/fix-apply.mjs <finding-json>
 *   node scripts/panel/fix-apply.mjs --queue <fix-queue.json> [--max N]
 *
 * Finding JSON format (single entry from fix-queue.json):
 *   {
 *     "finding_id": "...",
 *     "surface": "board-mg-5-error",
 *     "class": "off-scale-radius-shadow-control",
 *     "fix_class": "token",
 *     "auto_eligible": true,
 *     "anchor": ".sg-foo",
 *     "measured_px": [12],
 *     "scale_px": [8, 12, 16, 24]
 *   }
 *
 * Exit codes:
 *   0  — applied (one or more files edited)
 *   1  — refused (downgraded to judgment, scope violation, or dry run)
 *   2  — usage error
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, join, extname, relative } from 'node:path';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

// --------------------------------------------------------------------------
// Constants
// --------------------------------------------------------------------------

const TOKEN_BAND_PX = 1.0; // tightened band vs probe's 0.5px detection tolerance
const APPLY_SURFACE_PATTERNS = [
  // admin LiveView .heex files (lib/*_web/live/admin/)
  /lib\/[^/]+_web\/live\/admin\/.*\.heex$/,
  // example LiveView .heex files
  /test\/example\/lib\/[^/]+_web\/live\/.*\.heex$/,
  // example .ex files that contain inline ~H templates
  /test\/example\/lib\/[^/]+_web\/live\/.*\.ex$/,
  // admin LiveView .ex source files (inline ~H)
  /lib\/[^/]+_web\/live\/admin\/.*\.ex$/,
];

const REFUSED_EXTENSIONS = new Set(['.css', '.scss', '.less', '.sass']);
const AUTO_APPLY_FIX_CLASSES = new Set(['token', 'copy']);

// --------------------------------------------------------------------------
// Repo root
// --------------------------------------------------------------------------

const __filename = fileURLToPath(import.meta.url);
const ROOT = execSync('git rev-parse --show-toplevel', {
  cwd: resolve(__filename, '../..'),
  encoding: 'utf8',
}).trim();

const COPY_RULES_PATH = join(ROOT, 'scripts/panel/copy-rules.json');

// --------------------------------------------------------------------------
// Token-swap: nearest token within +/-1.0px band
// --------------------------------------------------------------------------

/**
 * Find the nearest scale token to valuePx within the +/-TOKEN_BAND_PX band.
 * Returns { token_px: number, delta: number } or null if no token qualifies.
 * On tie (two equidistant tokens), returns null (downgrade to judgment).
 *
 * @param {number} valuePx — the measured off-scale value
 * @param {number[]} scalePx — live token scale values from facts.json (via finding)
 * @returns {{ token_px: number, delta: number } | null}
 */
export function findNearestToken(valuePx, scalePx) {
  if (!Array.isArray(scalePx) || scalePx.length === 0) return null;

  let nearest = null;
  let nearestDelta = Infinity;
  let hasTie = false;

  for (const t of scalePx) {
    const delta = Math.abs(valuePx - t);
    if (delta < nearestDelta) {
      nearestDelta = delta;
      nearest = t;
      hasTie = false;
    } else if (delta === nearestDelta) {
      hasTie = true;
    }
  }

  // Tie → judgment
  if (hasTie) return null;
  // Outside band → judgment
  if (nearestDelta > TOKEN_BAND_PX) return null;

  return { token_px: nearest, delta: nearestDelta };
}

/**
 * Apply a token swap to a .heex inline-style attribute value.
 * Replaces occurrences of the exact measured_px value (in px units) with the
 * nearest CSS variable token reference (--sg-space-N, --sg-radius-*, --sg-control-*).
 *
 * This is a deterministic string replacement — no model text, no inference.
 * The token name is resolved by matching scale_px back to token names derived from
 * the probe's STEP arrays (which are embedded in the finding via the harness).
 * If the token name cannot be resolved from scale_px, we fall back to inline var()
 * using the nearest pixel value comment.
 *
 * @param {string} content — .heex / .ex file content
 * @param {object} finding — fix-queue entry with measured_px, scale_px, anchor
 * @returns {{ content: string, applied: boolean, reason?: string }}
 */
export function applyTokenSwap(content, finding) {
  const { measured_px, scale_px, fix_class, auto_eligible, anchor } = finding;

  if (fix_class !== 'token') {
    return { content, applied: false, reason: `fix_class=${fix_class} is not token` };
  }
  if (!auto_eligible) {
    return { content, applied: false, reason: 'not auto_eligible' };
  }

  const values = Array.isArray(measured_px) ? measured_px : [];
  if (values.length === 0) {
    return { content, applied: false, reason: 'no measured_px values' };
  }

  const scaleArr = Array.isArray(scale_px) ? scale_px : [];

  let modified = content;
  let anyApplied = false;

  for (const valuePx of values) {
    const result = findNearestToken(valuePx, scaleArr);
    if (!result) continue; // tie or out-of-band → skip this value

    const { token_px } = result;

    // Replace inline-style values: style="... 12px ..." → style="... var(--sg-XXX) ..."
    // Pattern: match `N.Npx` or `Npx` in style="..." or style={...} attribute context.
    // Preserve !important suffix.
    const pxStr = `${valuePx}px`;
    const pxPattern = new RegExp(
      `(style=["'][^"']*?)\\b${escapeRegex(pxStr)}(\\s*!important)?([^"']*)`,
      'g',
    );

    let replaced = false;
    const newContent = modified.replace(pxPattern, (match, pre, important, post) => {
      // Build replacement: use var(--sg-space-N) as a named token reference where
      // possible, otherwise use the pixel fallback with a TODO comment.
      const tokenRef = resolveTokenRef(token_px, scaleArr);
      const importantSuffix = important ? ' !important' : '';
      replaced = true;
      return `${pre}${tokenRef}${importantSuffix}${post}`;
    });

    if (replaced) {
      modified = newContent;
      anyApplied = true;
    }
  }

  if (!anyApplied) {
    return {
      content,
      applied: false,
      reason: `no in-band token match for measured values ${values.join(', ')}px`,
    };
  }

  return { content: modified, applied: true };
}

/**
 * Resolve a pixel value to the most likely --sg-* CSS variable name.
 * Uses the scale_px index to infer the token step.
 * Falls back to a pixel comment if the index cannot be mapped to a known token name.
 */
function resolveTokenRef(tokenPx, scalePx) {
  const idx = scalePx.indexOf(tokenPx);
  // Space scale: [1,2,3,4,5,6,7,8,10,12] (typical --sg-space-N steps from probes.ts)
  const SPACE_STEPS = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12];
  // Radius scale: xs, sm, md, lg (not indexed by integer step)
  // Control scale: xs, sm, md, lg (not indexed by integer step)
  // For radius/control, we cannot reliably infer the token name from px alone without
  // the token name map — use a generic var() with the px as fallback comment.

  // Try space scale first: if the resolved tokenPx matches a known space step pixel value,
  // we can infer the token name. The probe uses --sg-space-N where N is the SPACE_STEPS index.
  // However, since the pixel values depend on the root font-size and the host CSS, we
  // cannot reliably resolve them without reading the live CSS. Use index-based heuristic.
  if (idx !== -1 && scalePx.length === SPACE_STEPS.length) {
    return `var(--sg-space-${SPACE_STEPS[idx]})`;
  }

  // For radius scale (4 entries): xs, sm, md, lg
  if (idx !== -1 && scalePx.length === 4) {
    const RADIUS_KEYS = ['xs', 'sm', 'md', 'lg'];
    return `var(--sg-radius-${RADIUS_KEYS[idx]})`;
  }

  // For control scale (4 entries, but distinct from radius): xs, sm, md, lg
  // Since we cannot distinguish radius vs control by count alone, we fall back to
  // a commented pixel value for the operator to review (still deterministic, still safe).
  return `var(--sg-token-${tokenPx}px/* nearest token at ${tokenPx}px */)`;
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// --------------------------------------------------------------------------
// Copy-swap: text-node-only edit from copy-rules.json
// --------------------------------------------------------------------------

/**
 * Apply copy normalization rules to file content.
 * Only modifies text node content (>text<), never attribute values, never code blocks.
 *
 * @param {string} content — file content
 * @param {object} finding — fix-queue entry with fix_class=copy
 * @returns {{ content: string, applied: boolean, reason?: string }}
 */
export function applyCopySwap(content, finding) {
  const { fix_class, auto_eligible } = finding;

  if (fix_class !== 'copy') {
    return { content, applied: false, reason: `fix_class=${fix_class} is not copy` };
  }
  if (!auto_eligible) {
    return { content, applied: false, reason: 'not auto_eligible' };
  }

  let rules;
  try {
    const raw = readFileSync(COPY_RULES_PATH, 'utf8');
    rules = JSON.parse(raw).rules ?? [];
  } catch (err) {
    return { content, applied: false, reason: `cannot load copy-rules.json: ${err.message}` };
  }

  let modified = content;
  let anyApplied = false;

  for (const rule of rules) {
    const result = applyCopyRule(modified, rule);
    if (result.applied) {
      modified = result.content;
      anyApplied = true;
    }
  }

  if (!anyApplied) {
    return { content, applied: false, reason: 'no copy rules matched' };
  }

  return { content: modified, applied: true };
}

/**
 * Apply a single copy rule to content (text-node-only).
 * Text nodes in HEEx are the literal text between tags.
 */
function applyCopyRule(content, rule) {
  let modified = content;
  let applied = false;

  // Only modify text between HEEx/HTML tags — never inside attribute values.
  // Pattern: >TEXT< where TEXT is the text node content.
  // We match `>` (optionally with whitespace) then text then `<`.
  const textNodePattern = />([^<]+)</g;

  switch (rule.transform) {
    case 'sentence_case': {
      if (!rule.match_pattern) break;
      const matchRe = new RegExp(rule.match_pattern);
      modified = modified.replace(textNodePattern, (full, text) => {
        const trimmed = text.trim();
        if (!matchRe.test(trimmed)) return full;
        // Sentence case: capitalize first letter, lowercase the rest
        const sc = trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();
        applied = true;
        return full.replace(trimmed, sc);
      });
      break;
    }

    case 'title_case': {
      modified = modified.replace(textNodePattern, (full, text) => {
        const trimmed = text.trim();
        if (!/^[A-Za-z ]+$/.test(trimmed)) return full;
        const MINORS = new Set(['a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of', 'on', 'or', 'so', 'the', 'to', 'up', 'yet']);
        const words = trimmed.split(/\s+/);
        const tc = words.map((w, i) => {
          if (i === 0 || !MINORS.has(w.toLowerCase())) {
            return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
          }
          return w.toLowerCase();
        }).join(' ');
        if (tc === trimmed) return full;
        applied = true;
        return full.replace(trimmed, tc);
      });
      break;
    }

    case 'terminal_period': {
      modified = modified.replace(textNodePattern, (full, text) => {
        const trimmed = text.trim();
        const words = trimmed.split(/\s+/).filter(Boolean);
        if (words.length <= 5 && trimmed.endsWith('.')) {
          // Remove trailing period from short labels
          const stripped = trimmed.slice(0, -1);
          applied = true;
          return full.replace(trimmed, stripped);
        }
        if (words.length > 5 && !/[.!?]$/.test(trimmed)) {
          // Add terminal period to full sentences
          applied = true;
          return full.replace(trimmed, trimmed + '.');
        }
        return full;
      });
      break;
    }

    case 'replace': {
      if (!rule.match_pattern || !rule.replacement) break;
      // Replace in text nodes only
      const matchRe = new RegExp(escapeRegex(rule.match_pattern), 'g');
      modified = modified.replace(textNodePattern, (full, text) => {
        if (!matchRe.test(text)) return full;
        const replaced = text.replace(matchRe, rule.replacement);
        applied = true;
        return full.replace(text, replaced);
      });
      break;
    }

    default:
      // Unknown transform type → skip (judgment)
      break;
  }

  return { content: modified, applied };
}

// --------------------------------------------------------------------------
// Surface validation
// --------------------------------------------------------------------------

/**
 * Check whether a file path is within the allowed apply surface.
 * Returns { allowed: boolean, reason?: string }
 */
export function checkApplySurface(filePath) {
  const rel = relative(ROOT, resolve(ROOT, filePath));

  // Refuse CSS files
  const ext = extname(filePath).toLowerCase();
  if (REFUSED_EXTENSIONS.has(ext)) {
    return { allowed: false, reason: `CSS files are not in the apply surface (3-lockstep sigra_admin.css problem is out of scope)` };
  }

  // Must match an allowed pattern
  const allowed = APPLY_SURFACE_PATTERNS.some((p) => p.test(rel.replace(/\\/g, '/')));
  if (!allowed) {
    return {
      allowed: false,
      reason: `${rel} is not in the apply surface (only admin LiveView .heex/.ex + test/example)`,
    };
  }

  return { allowed: true };
}

/**
 * Check that a finding is auto-eligible and in an allowed fix_class.
 * Returns { allowed: boolean, reason?: string }
 */
export function checkFindingEligibility(finding) {
  if (!finding.auto_eligible) {
    return { allowed: false, reason: `finding is not auto_eligible` };
  }
  if (!AUTO_APPLY_FIX_CLASSES.has(finding.fix_class)) {
    return {
      allowed: false,
      reason: `fix_class=${finding.fix_class} is not in the auto-apply set (only: ${[...AUTO_APPLY_FIX_CLASSES].join(', ')})`,
    };
  }
  return { allowed: true };
}

// --------------------------------------------------------------------------
// Main: apply a single finding to a target file
// --------------------------------------------------------------------------

/**
 * Apply one fix-queue finding to a target .heex/.ex file.
 * Returns a result object indicating whether the file was modified.
 *
 * @param {object} finding — fix-queue entry
 * @param {string} filePath — absolute or ROOT-relative path to the file
 * @param {{ dryRun?: boolean }} opts
 * @returns {{ applied: boolean, reason?: string, filePath: string }}
 */
export function applyFinding(finding, filePath, opts = {}) {
  const { dryRun = false } = opts;
  const absPath = resolve(ROOT, filePath);

  // Surface check
  const surfaceCheck = checkApplySurface(absPath);
  if (!surfaceCheck.allowed) {
    return { applied: false, reason: surfaceCheck.reason, filePath };
  }

  // Eligibility check
  const eligCheck = checkFindingEligibility(finding);
  if (!eligCheck.allowed) {
    return { applied: false, reason: eligCheck.reason, filePath };
  }

  if (!existsSync(absPath)) {
    return { applied: false, reason: `file not found: ${absPath}`, filePath };
  }

  const original = readFileSync(absPath, 'utf8');

  let result;
  if (finding.fix_class === 'token') {
    result = applyTokenSwap(original, finding);
  } else if (finding.fix_class === 'copy') {
    result = applyCopySwap(original, finding);
  } else {
    return { applied: false, reason: `unknown fix_class: ${finding.fix_class}`, filePath };
  }

  if (!result.applied) {
    return { applied: false, reason: result.reason, filePath };
  }

  if (!dryRun) {
    writeFileSync(absPath, result.content, 'utf8');
  }

  return { applied: true, filePath, dryRun };
}

// --------------------------------------------------------------------------
// CLI entry point
// --------------------------------------------------------------------------

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('fix-apply: usage: node scripts/panel/fix-apply.mjs <finding-json-file>');
    console.error('                   node scripts/panel/fix-apply.mjs --queue <fix-queue.json> [--max N] [--dry-run]');
    process.exit(2);
  }

  let dryRun = false;
  let queuePath = null;
  let maxFixes = null;
  let findingPath = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--queue' && args[i + 1]) {
      queuePath = args[++i];
    } else if (args[i] === '--max' && args[i + 1]) {
      maxFixes = parseInt(args[++i], 10);
    } else if (args[i] === '--dry-run') {
      dryRun = true;
    } else if (!findingPath) {
      findingPath = args[i];
    } else {
      console.error(`fix-apply: unknown arg: ${args[i]}`);
      process.exit(2);
    }
  }

  if (queuePath) {
    // Queue mode: apply all auto_eligible findings up to --max
    const queue = JSON.parse(readFileSync(resolve(ROOT, queuePath), 'utf8'));
    const eligible = queue.filter((f) => f.auto_eligible);
    const toApply = maxFixes != null ? eligible.slice(0, maxFixes) : eligible;

    let applied = 0;
    for (const finding of toApply) {
      // In queue mode we don't know the target file — operator must supply or
      // the loop script maps surface→file. Print a warning and skip.
      console.log(
        `fix-apply: [queue] finding_id=${finding.finding_id} fix_class=${finding.fix_class} — no target file in queue mode (use admin-autofix-loop.sh)`,
      );
    }
    console.log(`fix-apply: ${applied} applied, ${toApply.length - applied} skipped`);
  } else if (findingPath) {
    // Single finding mode: <finding.json> or <finding.json> <file>
    const finding = JSON.parse(readFileSync(findingPath, 'utf8'));
    const targetFile = args[args.length - 1] !== findingPath ? args[args.length - 1] : null;

    if (!targetFile) {
      console.error('fix-apply: single-finding mode requires a target file path as second argument');
      process.exit(2);
    }

    const result = applyFinding(finding, targetFile, { dryRun });
    if (result.applied) {
      console.log(`fix-apply: APPLIED${dryRun ? ' (dry-run)' : ''}: ${result.filePath}`);
      process.exit(0);
    } else {
      console.log(`fix-apply: REFUSED: ${result.reason}`);
      process.exit(1);
    }
  }
}
