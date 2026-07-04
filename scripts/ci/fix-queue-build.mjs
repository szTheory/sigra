#!/usr/bin/env node
/**
 * fix-queue-build.mjs — deterministic fix-queue builder (Phase 217, Plan 02, D-12).
 *
 * Two outputs (one builder, two outputs — kills the two-producer drift hazard):
 *   1. guides/reference/fix-queue.json   — committed, sorted, open-set fix queue
 *   2. guides/reference/admin-render-sha.json — open_findings field per (surface, cell)
 *      (this builder is the SOLE writer of open_findings; render_sha256 is untouched)
 *
 * Algorithm:
 *   (a) Read all findings.json bundles under eval/<sha>/<surface>/<cell>/findings.json
 *   (b) Deduplicate by finding_id (same anchor can appear multiple times in a bundle)
 *   (c) Subtract settled rows from settled-findings.tsv → open set
 *   (d) Classify each open finding: fix_class ∈ {token, copy, component, judgment}
 *       - off-scale-radius-shadow-control → token
 *       - class-chain-anchored (anchor contains [class*=...] or similar) → judgment (D-12)
 *       - focus-ring → component
 *       - all others → judgment
 *   (e) DERIVE auto_eligible = fix_class ∈ {copy, token}  (NEVER trust a typed bit)
 *   (f) DERIVE systemic_group = sha256(class + NUL + anchor)
 *   (g) Systemic collapse: any anchor recurring across >=2 surfaces → one high-priority parent
 *   (h) DERIVE priority: systemic > high > normal
 *   (i) Sort: systemic parents first, then by priority desc, then by finding_id asc
 *   (j) Write fix-queue.json (committed, must diff cleanly vs merge-base)
 *   (k) Recompute open_findings per (surface, cell) in admin-render-sha.json (per cell key match)
 *
 * Environment overrides (for hermetic self-test):
 *   FQ_EVAL_DIR         — override the default eval directory path
 *   FQ_SETTLED_TSV      — override settled-findings.tsv path
 *   FQ_RENDER_SHA_JSON  — override admin-render-sha.json path
 *   FQ_QUEUE_JSON       — override fix-queue.json output path
 *
 * Usage:
 *   node scripts/ci/fix-queue-build.mjs
 *   (or: bash scripts/ci/admin-eval-harness.sh → chains this automatically)
 */

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const __dir = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dir, '..', '..');

// Path overrides for hermetic tests
const EVAL_DIR       = process.env.FQ_EVAL_DIR       || join(ROOT, 'test', 'example', 'priv', 'playwright', 'eval');
const SETTLED_TSV    = process.env.FQ_SETTLED_TSV    || join(ROOT, 'guides', 'reference', 'settled-findings.tsv');
const RENDER_SHA_JSON = process.env.FQ_RENDER_SHA_JSON || join(ROOT, 'guides', 'reference', 'admin-render-sha.json');
const QUEUE_JSON     = process.env.FQ_QUEUE_JSON     || join(ROOT, 'guides', 'reference', 'fix-queue.json');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function sha256hex(str) {
  return createHash('sha256').update(str).digest('hex');
}

/**
 * findingId — byte-identical to Phase 216 / panel-schema.mjs formula:
 *   sha256(surface + NUL + class + NUL + anchor)
 */
function findingId(surface, klass, anchor) {
  return createHash('sha256')
    .update(surface + '\0' + klass + '\0' + anchor)
    .digest('hex');
}

/**
 * systemic_group — collapse key that treats same (class, anchor) across surfaces as one group:
 *   sha256(class + NUL + anchor)
 */
function systemicGroup(klass, anchor) {
  return sha256hex(klass + '\0' + anchor);
}

/**
 * Classify fix_class from a probe finding.
 *
 * Classification rules (D-12/D-13):
 *   - class-chain-anchored anchor (anchor contains [class*=], [class~=], [class^=], [class$=])
 *     → judgment (auto-editing class= would change the finding_id that identifies them)
 *   - off-scale-radius-shadow-control → token (off-scale CSS value → nearest on-scale token)
 *   - focus-ring → component (needs component fix, human queue)
 *   - below-fold-primary → judgment (layout decision, not deterministically safe)
 *   - size-weight-budget → judgment (font budget is a system-wide concern)
 *   - misalignment → judgment (sub-pixel offsets require visual/layout inspection)
 *   - fallback → judgment
 *
 * NOTE: copy class is reserved for panel-finding copy-text findings (not probe findings).
 * No probe finding class maps to copy in the current taxonomy.
 */
function classifyFixClass(klass, anchor) {
  // D-12: class-chain-anchored findings are ALWAYS judgment (changing class= would alter finding_id)
  if (isClassChainAnchored(anchor)) {
    return 'judgment';
  }

  switch (klass) {
    case 'off-scale-radius-shadow-control':
      return 'token';
    case 'focus-ring':
      return 'component';
    case 'misalignment':
    case 'below-fold-primary':
    case 'size-weight-budget':
    default:
      return 'judgment';
  }
}

/**
 * Detect class-chain-anchored selectors (D-12).
 * These use CSS attribute selectors on the `class` attribute:
 *   [class*="..."], [class~="..."], [class^="..."], [class$="..."], [class="..."]
 */
function isClassChainAnchored(anchor) {
  return /\[class[*~^$]?=/.test(anchor);
}

/**
 * Walk all findings.json files under a directory tree.
 * Yields: { surface, cell, finding }
 */
function* walkFindings(evalDir) {
  if (!existsSync(evalDir)) return;

  // Structure: eval/<sha>/<surface>/<cell>/findings.json
  for (const sha of readdirSync(evalDir)) {
    const shaDir = join(evalDir, sha);
    if (!statSync(shaDir).isDirectory()) continue;
    for (const surface of readdirSync(shaDir)) {
      const surfDir = join(shaDir, surface);
      if (!statSync(surfDir).isDirectory()) continue;
      for (const cell of readdirSync(surfDir)) {
        const cellDir = join(surfDir, cell);
        if (!statSync(cellDir).isDirectory()) continue;
        const findingsPath = join(cellDir, 'findings.json');
        if (!existsSync(findingsPath)) continue;
        let findings;
        try {
          findings = JSON.parse(readFileSync(findingsPath, 'utf8'));
        } catch {
          console.error(`fix-queue-build: WARN: could not parse ${findingsPath}`);
          continue;
        }
        if (!Array.isArray(findings)) continue;
        for (const finding of findings) {
          yield { surface, cell, finding };
        }
      }
    }
  }
}

/**
 * Load the settled-findings.tsv suppression set.
 * Returns a Set<finding_id> of settled IDs.
 */
function loadSettled(tsvPath) {
  const settled = new Set();
  if (!existsSync(tsvPath)) return settled;
  const lines = readFileSync(tsvPath, 'utf8').split('\n');
  for (const line of lines) {
    if (!line || line.startsWith('#')) continue;
    const cols = line.split('\t');
    if (cols.length >= 1 && cols[0].length === 64) {
      settled.add(cols[0]);
    }
  }
  return settled;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

// (a) Walk all findings.json bundles and collect unique findings by finding_id
// Map: finding_id → { finding_id, surface, class, anchor, lens, severity, surfaces: Set<surface> }
const builtMap = new Map(); // finding_id → canonical entry + surfaces seen

for (const { surface, cell, finding } of walkFindings(EVAL_DIR)) {
  const klass = finding.class || finding.probe_class || '';
  const anchor = finding.anchor || '';
  const severity = finding.severity || 'warn';
  const lens = finding.lens || null;

  // Compute or trust the finding_id (bundles should already have it, but recompute for safety)
  const fid = finding.finding_id || findingId(surface, klass, anchor);

  if (builtMap.has(fid)) {
    // Track all surfaces where this finding appears
    builtMap.get(fid).surfaces.add(surface);
    // Also track cells
    builtMap.get(fid).cells.add(cell);
  } else {
    builtMap.set(fid, {
      finding_id: fid,
      surface,     // canonical surface (first seen)
      class: klass,
      anchor,
      lens,
      severity,
      surfaces: new Set([surface]),
      cells: new Set([cell]),
    });
  }
}

// (b) Load settled set
const settledSet = loadSettled(SETTLED_TSV);

// (c) Compute open set = built - settled
const openEntries = [];
for (const [fid, entry] of builtMap) {
  if (!settledSet.has(fid)) {
    openEntries.push(entry);
  }
}

// (d-f) Classify each open finding and compute derived fields
const fixQueueEntries = openEntries.map(entry => {
  const fix_class = classifyFixClass(entry.class, entry.anchor);
  const auto_eligible = fix_class === 'copy' || fix_class === 'token';
  const sg = systemicGroup(entry.class, entry.anchor);
  const surfaceCount = entry.surfaces.size;

  return {
    finding_id: entry.finding_id,
    surface: entry.surface,
    class: entry.class,
    anchor: entry.anchor,
    lens: entry.lens,
    severity: entry.severity,
    fix_class,
    auto_eligible,
    systemic_group: sg,
    // priority will be set after systemic collapse
    _surfaces: entry.surfaces,
    _cells: entry.cells,
    _surface_count: surfaceCount,
  };
});

// (g) Systemic collapse:
// Group by systemic_group. Any group with >=2 surfaces → systemic parent.
// Keep only ONE entry per (systemic_group) for cross-surface anchors.
// Single-surface findings are kept as-is with priority 'normal'.

// Build map: systemic_group → all entries with that group
const sgMap = new Map();
for (const entry of fixQueueEntries) {
  const sg = entry.systemic_group;
  if (!sgMap.has(sg)) sgMap.set(sg, []);
  sgMap.get(sg).push(entry);
}

const collapsed = [];
for (const [sg, entries] of sgMap) {
  // Count unique surfaces across all entries in this group
  const allSurfaces = new Set();
  for (const e of entries) {
    for (const s of e._surfaces) allSurfaces.add(s);
  }

  if (allSurfaces.size >= 2) {
    // Systemic: collapse to one parent entry (use the first entry as representative)
    const rep = entries[0];
    collapsed.push({
      finding_id: rep.finding_id,
      surface: rep.surface,
      class: rep.class,
      anchor: rep.anchor,
      lens: rep.lens,
      severity: rep.severity,
      fix_class: rep.fix_class,
      auto_eligible: rep.auto_eligible,
      systemic_group: sg,
      priority: 'systemic',
      surfaces_affected: [...allSurfaces].sort(),
    });
  } else {
    // Single-surface — keep all entries as individual findings
    for (const e of entries) {
      collapsed.push({
        finding_id: e.finding_id,
        surface: e.surface,
        class: e.class,
        anchor: e.anchor,
        lens: e.lens,
        severity: e.severity,
        fix_class: e.fix_class,
        auto_eligible: e.auto_eligible,
        systemic_group: e.systemic_group,
        priority: 'normal',
      });
    }
  }
}

// (h) Sort: systemic first, then by priority (systemic > high > normal), then finding_id asc
const priorityOrder = { systemic: 0, high: 1, normal: 2 };
collapsed.sort((a, b) => {
  const pa = priorityOrder[a.priority] ?? 99;
  const pb = priorityOrder[b.priority] ?? 99;
  if (pa !== pb) return pa - pb;
  return a.finding_id.localeCompare(b.finding_id);
});

// (i) Write fix-queue.json (committed, sorted)
writeFileSync(QUEUE_JSON, JSON.stringify(collapsed, null, 2) + '\n');
console.log(`fix-queue-build: wrote ${collapsed.length} entries to fix-queue.json`);

// (j) Recompute open_findings per (admin-surface, cell-key) in admin-render-sha.json
// Strategy:
//   - For each cell key in admin-render-sha.json (e.g. "light-desktop-populated"),
//     count unique open finding_ids from ALL board bundles whose cell matches that key.
//   - Write the same count to ALL admin surfaces in admin-render-sha.json for that cell key.
//   This aggregates all board findings into the admin-surface view.

// Build: cellKey → Set<finding_id> (open, deduplicated across all board surfaces)
const cellOpenCounts = new Map(); // cellKey → Set<finding_id>

for (const [fid, entry] of builtMap) {
  if (settledSet.has(fid)) continue; // skip settled
  for (const cell of entry.cells) {
    if (!cellOpenCounts.has(cell)) cellOpenCounts.set(cell, new Set());
    cellOpenCounts.get(cell).add(fid);
  }
}

// Read and update admin-render-sha.json
const renderSha = JSON.parse(readFileSync(RENDER_SHA_JSON, 'utf8'));

for (const surface of Object.keys(renderSha.cells || {})) {
  for (const cellKey of Object.keys(renderSha.cells[surface] || {})) {
    const openSet = cellOpenCounts.get(cellKey);
    const openCount = openSet ? openSet.size : 0;
    // Preserve render_sha256; only update open_findings
    renderSha.cells[surface][cellKey].open_findings = openCount;
  }
}

writeFileSync(RENDER_SHA_JSON, JSON.stringify(renderSha, null, 2) + '\n');
console.log(`fix-queue-build: updated open_findings in admin-render-sha.json (${Object.keys(renderSha.cells).length} surfaces)`);
