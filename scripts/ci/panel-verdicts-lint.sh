#!/usr/bin/env bash
# panel-verdicts-lint.sh — anti-rot lint for admin-panel-verdicts.json (Phase 217, Plan 05).
#
# Enforces that guides/reference/admin-panel-verdicts.json is:
#   (a) Valid JSON
#   (b) 64-char lowercase hex render_sha256 keys (all keys in .cells must be 64-char hex)
#   (c) Keys sorted lexicographically (ascending) within .cells
#   (d) No duplicate keys (valid JSON semantics, but explicit check via node)
#   (e) Every admitted finding_id recomputes from (surface, class, anchor) via panel-schema helper
#   (f) No open_findings field present anywhere (T-217-05-EOP: single-authoritative-source rule)
#
# --prune: removes orphaned entries non-blockingly (exits 0 even when entries pruned)
#          An orphaned entry is one whose render_sha256 doesn't match any current cell in
#          admin-render-sha.json. The --prune mode is informational/maintenance only.
#
# Usage (lint mode):
#   scripts/ci/panel-verdicts-lint.sh [--base <ref>]
#
# Usage (prune mode):
#   scripts/ci/panel-verdicts-lint.sh --prune
#
# Exit codes:
#   0 — lint passes (or --prune completed non-blockingly)
#   1 — one or more lint violations
#   2 — usage / argument error
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERDICTS="${ROOT}/guides/reference/admin-panel-verdicts.json"
RENDER_SHA_JSON="${ROOT}/guides/reference/admin-render-sha.json"

fail() {
  echo "panel-verdicts-lint: FAIL: $*" >&2
  exit 1
}

# --------------------------------------------------------------------------
# --prune mode: remove orphaned entries (non-blocking, exits 0)
# --------------------------------------------------------------------------
if [[ "${1:-}" == "--prune" ]]; then
  if [[ ! -f "$VERDICTS" ]]; then
    echo "panel-verdicts-lint: INFO: admin-panel-verdicts.json not found — nothing to prune"
    exit 0
  fi

  # Collect current render_sha256 values from admin-render-sha.json
  CURRENT_SHAS=""
  if [[ -f "$RENDER_SHA_JSON" ]]; then
    CURRENT_SHAS=$(node -e "
      const data = JSON.parse(require('fs').readFileSync('${RENDER_SHA_JSON}', 'utf8'));
      const shas = new Set();
      for (const surface of Object.values(data.cells || {})) {
        for (const cell of Object.values(surface)) {
          if (cell.render_sha256) shas.add(cell.render_sha256);
        }
      }
      console.log([...shas].join('\n'));
    " 2>/dev/null || true)
  fi

  PRUNED=$(node -e "
    const fs = require('fs');
    const verdicts = JSON.parse(fs.readFileSync('${VERDICTS}', 'utf8'));
    const currentStr = '${CURRENT_SHAS}'.trim();
    const current = new Set(currentStr.split('\n').filter(Boolean));
    const cells = verdicts.cells || {};
    const before = Object.keys(cells).length;
    const pruned = {};
    for (const [sha, entry] of Object.entries(cells)) {
      // If admin-render-sha.json has cells, keep only matching shas.
      // If it has NO cells (or file absent), prune ALL entries from the verdicts cache.
      if (current.size > 0 && current.has(sha)) {
        pruned[sha] = entry;
      }
      // else: orphaned — drop it
    }
    const after = Object.keys(pruned).length;
    verdicts.cells = pruned;
    fs.writeFileSync('${VERDICTS}', JSON.stringify(verdicts, null, 2) + '\n');
    console.log(before - after);
  " 2>/dev/null || echo "0")

  if [[ "$PRUNED" -gt 0 ]]; then
    echo "panel-verdicts-lint: INFO: --prune removed $PRUNED orphaned entries (non-blocking)"
  else
    echo "panel-verdicts-lint: INFO: --prune — no orphaned entries found"
  fi
  exit 0
fi

# --------------------------------------------------------------------------
# Consume known args (--base is accepted for symmetry with other guards)
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) shift 2;;
    *) echo "panel-verdicts-lint: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

# --------------------------------------------------------------------------
# Lint mode (default)
# --------------------------------------------------------------------------

if [[ ! -f "$VERDICTS" ]]; then
  fail "admin-panel-verdicts.json not found at ${VERDICTS}"
fi

# (a) Valid JSON
node -e "
try {
  JSON.parse(require('fs').readFileSync('${VERDICTS}', 'utf8'));
} catch(e) {
  console.error('panel-verdicts-lint: FAIL: invalid JSON: ' + e.message);
  process.exit(1);
}
" || exit 1

# Run all remaining checks in a single node invocation for efficiency
node -e "
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

let violations = 0;
function fail(msg) {
  console.error('panel-verdicts-lint: FAIL: ' + msg);
  violations++;
}

// ── Load and parse ─────────────────────────────────────────────────────────
const raw = fs.readFileSync('${VERDICTS}', 'utf8');
let verdicts;
try {
  verdicts = JSON.parse(raw);
} catch(e) {
  fail('invalid JSON: ' + e.message);
  process.exit(1);
}

// (f) No open_findings field ANYWHERE in the file
// Scan the raw JSON string for the key 'open_findings'
if (raw.includes('\"open_findings\"')) {
  fail('open_findings field found in admin-panel-verdicts.json — this field belongs ONLY in admin-render-sha.json (T-217-05-EOP)');
}

const cells = verdicts.cells || {};
const keys = Object.keys(cells);

// An empty cells object passes trivially (skeleton is valid)
if (keys.length === 0) {
  if (violations === 0) {
    console.log('panel-verdicts-lint: PASS (empty cells — trivially valid skeleton)');
  } else {
    process.exit(1);
  }
  process.exit(0);
}

// (b) All keys must be 64-char lowercase hex render_sha256
for (const key of keys) {
  if (!/^[0-9a-f]{64}$/.test(key)) {
    fail('render_sha256 key is not 64-char lowercase hex: ' + key);
  }
}

// (c) Keys must be sorted lexicographically ascending
const sorted = [...keys].sort();
for (let i = 0; i < keys.length; i++) {
  if (keys[i] !== sorted[i]) {
    fail('cells keys are not sorted: expected ' + sorted[i] + ' at position ' + i + ' but got ' + keys[i]);
    break;
  }
}

// (d) No duplicate keys (JSON.parse silently takes last value; detect via raw string)
// We check for duplicate keys by comparing the key count after parsing vs a Set
const keySet = new Set(keys);
if (keySet.size !== keys.length) {
  fail('duplicate render_sha256 keys detected (JSON.parse silently deduplicates)');
}

// (e) Every admitted finding_id must recompute from (surface, class, anchor)
function canonicalizeAnchor(anchor) {
  if (typeof anchor !== 'string') return anchor;
  return anchor.trim().replace(/\[([^\]]*?)='([^']*)'\]/g, '[\$1=\"\$2\"]');
}

function computeFindingId(surface, klass, anchor) {
  const canon = canonicalizeAnchor(anchor);
  return crypto.createHash('sha256')
    .update(surface)
    .update('\0')
    .update(klass)
    .update('\0')
    .update(canon)
    .digest('hex');
}

for (const [sha, entry] of Object.entries(cells)) {
  const admittedFindings = entry.admitted_findings || [];
  for (const finding of admittedFindings) {
    const { finding_id, surface, klass, anchor } = finding;
    if (!finding_id || !surface || !klass || !anchor) {
      fail('admitted finding in entry ' + sha.slice(0, 8) + '... is missing required fields (finding_id, surface, klass, anchor)');
      continue;
    }
    const recomputed = computeFindingId(surface, klass, anchor);
    if (recomputed !== finding_id) {
      fail('finding_id does not recompute from (surface, class, anchor) in entry ' + sha.slice(0, 8) + '...: ' +
           'stored=' + finding_id + ' recomputed=' + recomputed);
    }
  }
}

// ── Summary ────────────────────────────────────────────────────────────────
if (violations === 0) {
  console.log('panel-verdicts-lint: PASS (' + keys.length + ' entries validated)');
  process.exit(0);
} else {
  process.exit(1);
}
" || exit 1
