#!/usr/bin/env node
/**
 * award-guard.mjs — D-20 verify-then-climb guard for admin-award-ledger.json.
 *
 * Reads HEAD's guides/reference/admin-award-ledger.json from the working tree
 * and the BASE version via `git show <base>:guides/reference/admin-award-ledger.json`.
 * Fails CI if any of the four D-20 conditions are violated:
 *
 *   (a) An axis band rose vs base but verified_at_sha did NOT change
 *       → climb without fresh render.
 *   (b) band !== min(axes)
 *       → inconsistent derived value; guard recomputes min, never trusts the typed band.
 *   (c) Any raised axis has rendered:false OR an evidence_ref that does not resolve.
 *       → fabricated/unresolvable evidence.
 *   (d) Any axis band DECREASED vs merge-base.
 *       → silent down-ratchet.
 *
 * A no-change run exits 0. A legitimate climb (axis up + fresh verified_at_sha
 * + resolving evidence_ref) exits 0.
 *
 * Usage:
 *   node scripts/ci/award-guard.mjs [--base <git-ref>]   (default: HEAD)
 *
 * The BASE ref is the merge-base commit emitted by ci.yml's `id: base` step
 * after Plan 01's D-10 fix.
 */

import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolveEvidenceRef } from './lib/eval-probe-ids.mjs';

// --------------------------------------------------------------------------
// Arg parse
// --------------------------------------------------------------------------
let base = 'HEAD';
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--base' && args[i + 1]) {
    base = args[i + 1];
    i++;
  } else {
    console.error(`award-guard: FAIL: unknown arg: ${args[i]}`);
    process.exit(2);
  }
}

// --------------------------------------------------------------------------
// Repo root
// --------------------------------------------------------------------------
const __filename = fileURLToPath(import.meta.url);
const SCRIPT_DIR = resolve(__filename, '../..');  // scripts/ci/../../ = repo root
const ROOT = execSync('git rev-parse --show-toplevel', { cwd: SCRIPT_DIR, encoding: 'utf8' }).trim();
const LEDGER_REL = 'guides/reference/admin-award-ledger.json';
const LEDGER_ABS = resolve(ROOT, LEDGER_REL);

// --------------------------------------------------------------------------
// Ordinal mapping  A0..A3 → 0..3
// --------------------------------------------------------------------------
const BAND_ORD = { A0: 0, A1: 1, A2: 2, A3: 3 };
const AXES = ['token_fidelity', 'rhythm', 'a11y_polish', 'states'];

function bandOrd(b) {
  const v = BAND_ORD[b];
  if (v === undefined) throw new Error(`unknown band value: ${b}`);
  return v;
}

function minBand(axes) {
  let min = 3;
  for (const axis of AXES) {
    const v = bandOrd(axes[axis]);
    if (v < min) min = v;
  }
  // return canonical string
  return Object.keys(BAND_ORD)[min]; // A0..A3 indexed by ordinal
}

// --------------------------------------------------------------------------
// Load HEAD ledger from working tree
// --------------------------------------------------------------------------
let headLedger;
try {
  const raw = readFileSync(LEDGER_ABS, 'utf8');
  headLedger = JSON.parse(raw);
} catch (err) {
  console.error(`award-guard: FAIL: cannot read HEAD ledger at ${LEDGER_REL}: ${err.message}`);
  process.exit(1);
}

// --------------------------------------------------------------------------
// Load BASE ledger via git show (mirrors quality-ledger-monotonic.sh idiom)
// --------------------------------------------------------------------------
let baseLedger = null;
try {
  const raw = execSync(`git -C "${ROOT}" show "${base}:${LEDGER_REL}"`, { encoding: 'utf8' });
  baseLedger = JSON.parse(raw);
} catch (_err) {
  // Missing base file = initial commit; skip comparison per monotonic-guard idiom.
  console.log(`award-guard: INFO: no base ledger at ${base}:${LEDGER_REL} — skipping comparison (initial commit)`);
  process.exit(0);
}

// --------------------------------------------------------------------------
// Compare HEAD cells vs BASE cells
// --------------------------------------------------------------------------
const headCells = headLedger.cells ?? {};
const baseCells = (baseLedger && baseLedger.cells) ? baseLedger.cells : {};

let violations = 0;
let checked = 0;

function fail(surface, reason) {
  console.error(`award-guard: FAIL: ${surface}: ${reason}`);
  violations++;
}

for (const [surface, cell] of Object.entries(headCells)) {
  checked++;
  const base_cell = baseCells[surface];

  const headAxes = cell.axes ?? {};
  const baseAxes = (base_cell && base_cell.axes) ? base_cell.axes : {};

  // (b) band != min(axes): recompute min — never trust the typed band
  let computedMin;
  try {
    computedMin = minBand(headAxes);
  } catch (err) {
    fail(surface, `invalid axis band value — ${err.message}`);
    continue;
  }

  if (cell.band !== computedMin) {
    fail(surface, `band != min(axes): typed band is ${cell.band} but min(${AXES.map(a => headAxes[a]).join(',')}) = ${computedMin}`);
  }

  // Per-axis checks vs base
  for (const axis of AXES) {
    const headBand = headAxes[axis];
    const baseBand = baseAxes[axis];

    if (headBand === undefined) {
      fail(surface, `missing axis: ${axis}`);
      continue;
    }

    let headOrd;
    try {
      headOrd = bandOrd(headBand);
    } catch (err) {
      fail(surface, `invalid band for axis ${axis}: ${headBand}`);
      continue;
    }

    if (baseBand === undefined) {
      // No base axis — skip per-axis comparison (new surface).
      continue;
    }

    let baseOrd;
    try {
      baseOrd = bandOrd(baseBand);
    } catch (_err) {
      // If base had an invalid value, skip comparison for this axis.
      continue;
    }

    const rose = headOrd > baseOrd;
    const fell = headOrd < baseOrd;

    // (d) Any axis decreased vs merge-base
    if (fell) {
      fail(surface, `axis ${axis} decreased vs merge-base: ${baseBand} → ${headBand}`);
    }

    // Checks that apply only when an axis rose
    if (rose) {
      // (a) Climb without fresh render: verified_at_sha must have changed
      const headSha = cell.verified_at_sha ?? null;
      const baseSha = (base_cell && base_cell.verified_at_sha !== undefined)
        ? base_cell.verified_at_sha
        : null;
      if (headSha === baseSha) {
        fail(surface, `axis ${axis} rose (${baseBand} → ${headBand}) but verified_at_sha did not change (${headSha ?? 'null'}) — climb without fresh render`);
      }

      // (c) Raised axis must have rendered:true AND all evidence_refs must resolve
      if (cell.rendered !== true) {
        fail(surface, `axis ${axis} rose (${baseBand} → ${headBand}) but rendered is not true`);
      }

      const refs = Array.isArray(cell.evidence_ref) ? cell.evidence_ref : [];
      if (refs.length === 0) {
        fail(surface, `axis ${axis} rose (${baseBand} → ${headBand}) but evidence_ref is empty`);
      } else {
        for (const ref of refs) {
          if (!resolveEvidenceRef(ref)) {
            fail(surface, `axis ${axis} rose (${baseBand} → ${headBand}) but evidence_ref does not resolve: "${ref}"`);
          }
        }
      }
    }
  }
}

if (violations > 0) {
  process.exit(1);
}

console.log(`award-guard: PASS (${checked} cell${checked === 1 ? '' : 's'} checked vs ${base})`);
process.exit(0);
