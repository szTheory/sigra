#!/usr/bin/env bash
# Phase 216 (HARNESS-FOUNDATION): merge-blocking quality findings monotonic guard.
# Fails CI if any cell in guides/reference/admin-render-sha.json increased its
# open_findings count vs the merge-base ref.
#
# This is a structural clone of quality-ledger-monotonic.sh with the comparator
# INVERTED: the tier guard fails on DECREASE (tier must go up); this guard fails
# on INCREASE (open findings must go down). See PATTERNS.md D-21.
#
# skip-on-empty-base divergence (D-08/D-21):
#   The tier guard skips when BASE has zero cells (initial commit, no decrease possible).
#   For findings, an increase from 0 IS a regression — so skip ONLY when the ledger
#   FILE is absent at base (true initial commit). When the file exists with zero rows
#   (cells all have open_findings:0), an increase from 0 must be caught.
#
# 231-05 (D-08 reconciliation, floor-rebase mechanism): this guard previously had NO
# sanctioned way to re-establish the floor when the MEASUREMENT BASIS itself changes
# (e.g. the harness that produces admin-render-sha.json was broken and is now fixed,
# so the old floor undercounted rather than representing a real, achieved improvement).
# guides/reference/floor-rebase-declarations.json (optional; ABSENT BY DEFAULT) is the
# sanctioned, auditable, fail-closed escape hatch:
#   - Absent file: behavior is byte-for-byte identical to before this section existed.
#     An increase still fails. This is what makes it not a loosening.
#   - A declaration is VERIFIED, never trusted: every prior_totals/new_totals entry it
#     claims is cross-checked against the ACTUAL BASE and HEAD ledger content below; a
#     single mismatch anywhere in a declaration invalidates that ENTIRE declaration
#     (no partial credit, no cherry-picking one matching cell out of a stale entry).
#   - One-time transition: a declaration's new_totals values are FIXED at authoring
#     time. Any further drift beyond those exact values no longer matches HEAD, so the
#     declaration stops validating and a fresh declaration is required — the same
#     declaration can never be reused to permit a second, different increase.
#   - Declarations accumulate in the array as a permanent historical record; old
#     entries naturally go inert once BASE moves past their commit (their prior_totals
#     stop matching), so nothing needs pruning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="guides/reference/admin-render-sha.json"
DECLARATIONS="guides/reference/floor-rebase-declarations.json"
BASE="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "quality-findings-monotonic: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "quality-findings-monotonic: FAIL: $*" >&2
  exit 1
}

# Extract <surface>/<cell>\t<open_findings> lines from admin-render-sha.json on stdin.
# Uses node (builtin in any JS environment) to parse JSON — avoids a jq dependency.
# Output format: "surface/cell\tN" one line per cell.
extract_open_counts() {
  node -e "
const chunks = [];
process.stdin.on('data', c => chunks.push(c));
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(chunks.join('')); } catch(e) { process.exit(0); }
  const cells = data.cells || {};
  for (const surface of Object.keys(cells)) {
    for (const cell of Object.keys(cells[surface])) {
      const val = cells[surface][cell];
      const n = (typeof val === 'object' && val !== null && 'open_findings' in val)
        ? Number(val.open_findings) : 0;
      process.stdout.write(surface + '/' + cell + '\t' + n + '\n');
    }
  }
});
"
}

# Load BASE counts.
# If the file is absent at BASE (true initial commit), skip entirely — no baseline exists.
# If the file EXISTS at BASE but has zero counts, we MUST compare (an increase from 0 is a regression).
BASE_JSON=$(git -C "$ROOT" show "${BASE}:${LEDGER}" 2>/dev/null || true)

if [[ -z "$BASE_JSON" ]]; then
  echo "quality-findings-monotonic: INFO: ledger absent at ${BASE}:${LEDGER} — skipping (initial commit)"
  exit 0
fi

BASE_LEDGER_TMP="$(mktemp)"
trap 'rm -f "$BASE_LEDGER_TMP"' EXIT
printf '%s' "$BASE_JSON" > "$BASE_LEDGER_TMP"

DECL_PATH="${ROOT}/${DECLARATIONS}"
if [[ ! -f "$DECL_PATH" ]]; then
  DECL_PATH="/dev/null"
fi

# Single node pass: extract BASE/HEAD counts, validate any floor-rebase declarations
# against the ACTUAL ledger content (never trusted at face value), and emit one
# violation line per undeclared increase. Authorization info goes to stderr so it
# shows up in the CI log without contaminating the VIOLATIONS capture below.
VIOLATIONS=$(BASE_LEDGER_PATH="$BASE_LEDGER_TMP" HEAD_LEDGER_PATH="${ROOT}/${LEDGER}" DECL_PATH="$DECL_PATH" node -e '
const fs = require("node:fs");

function extractCounts(data) {
  const out = {};
  const cells = (data && data.cells) || {};
  for (const surface of Object.keys(cells)) {
    for (const cell of Object.keys(cells[surface])) {
      const val = cells[surface][cell];
      if (typeof val === "object" && val !== null && "open_findings" in val) {
        out[surface + "/" + cell] = Number(val.open_findings);
      }
    }
  }
  return out;
}

const baseCounts = extractCounts(JSON.parse(fs.readFileSync(process.env.BASE_LEDGER_PATH, "utf8")));
const headCounts = extractCounts(JSON.parse(fs.readFileSync(process.env.HEAD_LEDGER_PATH, "utf8")));

let declarations = [];
try {
  const raw = fs.readFileSync(process.env.DECL_PATH, "utf8");
  const parsed = JSON.parse(raw);
  if (Array.isArray(parsed.declarations)) declarations = parsed.declarations;
} catch (e) {
  // Absent, empty, or invalid declarations file — fail-closed default (no authorizations).
}

// A declaration authorizes an item ONLY if EVERY entry it claims — both prior_totals
// and new_totals — exactly matches the ACTUAL base/head ledger content. One mismatch
// anywhere invalidates the WHOLE declaration (no partial credit for a stale or
// hand-fudged entry). This is what makes the declaration verified, not trusted.
const authorizedItems = new Map(); // item -> run_id that authorized it
for (const decl of declarations) {
  if (!decl || typeof decl !== "object") continue;
  const priorTotals = decl.prior_totals && typeof decl.prior_totals === "object" ? decl.prior_totals : null;
  const newTotals = decl.new_totals && typeof decl.new_totals === "object" ? decl.new_totals : null;
  if (!priorTotals || !newTotals || !decl.run_id) continue; // malformed — ignore, never partially trust

  let valid = true;
  for (const [key, val] of Object.entries(priorTotals)) {
    if ((baseCounts[key] ?? 0) !== Number(val)) { valid = false; break; }
  }
  if (valid) {
    for (const [key, val] of Object.entries(newTotals)) {
      if ((headCounts[key] ?? 0) !== Number(val)) { valid = false; break; }
    }
  }
  if (valid) {
    for (const key of Object.keys(newTotals)) authorizedItems.set(key, decl.run_id);
    process.stderr.write(
      "quality-findings-monotonic: INFO: declaration " + decl.run_id +
      " verified and authorizes " + Object.keys(newTotals).length + " cell(s)\n"
    );
  } else {
    process.stderr.write(
      "quality-findings-monotonic: INFO: declaration " + (decl.run_id || "<unnamed>") +
      " does not match the actual base/head ledger content — ignored, not authorizing anything\n"
    );
  }
}

const violations = [];
for (const item of Object.keys(headCounts)) {
  const headCount = headCounts[item];
  const baseCount = baseCounts[item] ?? 0;
  // INVERTED comparator vs tier guard: FAIL when count INCREASED (open findings went up).
  if (headCount > baseCount) {
    if (authorizedItems.has(item)) continue; // verified declaration covers this exact transition
    violations.push("open findings increased for \x27" + item + "\x27: " + baseCount + " → " + headCount);
  }
}

if (violations.length > 0) {
  process.stdout.write(violations.join("\n") + "\n");
}
')

if [[ -n "$VIOLATIONS" ]]; then
  echo "$VIOLATIONS" | while IFS= read -r line; do
    [[ -n "$line" ]] && echo "quality-findings-monotonic: FAIL: $line" >&2
  done
  exit 1
fi
echo "quality-findings-monotonic: PASS (checked vs ${BASE})"
