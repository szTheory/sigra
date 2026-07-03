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
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="guides/reference/admin-render-sha.json"
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

declare -A BASE_COUNTS=()
while IFS=$'\t' read -r item cnt; do
  BASE_COUNTS["$item"]="$cnt"
done < <(echo "$BASE_JSON" | extract_open_counts)

# Load HEAD counts from the working tree.
declare -A HEAD_COUNTS=()
while IFS=$'\t' read -r item cnt; do
  HEAD_COUNTS["$item"]="$cnt"
done < <(extract_open_counts < "${ROOT}/${LEDGER}")

violations=0
for item in "${!HEAD_COUNTS[@]}"; do
  head_count="${HEAD_COUNTS[$item]}"
  base_count="${BASE_COUNTS[$item]:-0}"
  # INVERTED comparator vs tier guard: FAIL when count INCREASED (open findings went up).
  # The tier guard uses `head_tier -lt base_tier` (decrease = fail).
  # This guard uses `head > base` (increase = fail).
  if (( head_count > base_count )); then
    echo "quality-findings-monotonic: FAIL: open findings increased for '${item}': ${base_count} → ${head_count}" >&2
    violations=1
  fi
done

if [[ "$violations" -ne 0 ]]; then exit 1; fi
echo "quality-findings-monotonic: PASS (${#HEAD_COUNTS[@]} cells checked vs ${BASE})"
