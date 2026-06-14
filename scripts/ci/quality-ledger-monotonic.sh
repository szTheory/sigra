#!/usr/bin/env bash
# Phase 185 (AUDIT-INFRA): merge-blocking quality ledger monotonic guard.
# Fails CI if any tier cell in guides/reference/admin-quality-ledger.md decreased vs base ref.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="guides/reference/admin-quality-ledger.md"
BASE="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "quality-ledger-monotonic: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "quality-ledger-monotonic: FAIL: $*" >&2
  exit 1
}

extract_tiers() {
  grep -E '^\| [a-z]' | awk -F'|' '{
    item=gensub(/^ +| +$/, "", "g", $2)
    tier=gensub(/^ +| +$/, "", "g", $4)
    if (tier ~ /^[012]$/) print item ":" tier
  }'
}

declare -A BASE_TIERS=()
while IFS=: read -r item tier; do
  BASE_TIERS["$item"]="$tier"
done < <(git -C "$ROOT" show "${BASE}:${LEDGER}" 2>/dev/null | extract_tiers)

if [[ ${#BASE_TIERS[@]} -eq 0 ]]; then
  echo "quality-ledger-monotonic: INFO: no base tiers at ${BASE}:${LEDGER} — skipping (initial commit)"
  exit 0
fi

declare -A HEAD_TIERS=()
while IFS=: read -r item tier; do
  HEAD_TIERS["$item"]="$tier"
done < <(extract_tiers < "${ROOT}/${LEDGER}")

violations=0
for item in "${!HEAD_TIERS[@]}"; do
  head_tier="${HEAD_TIERS[$item]}"
  base_tier="${BASE_TIERS[$item]:-}"
  if [[ -n "$base_tier" && "$head_tier" -lt "$base_tier" ]]; then
    echo "quality-ledger-monotonic: FAIL: tier decreased for '${item}': ${base_tier} → ${head_tier}" >&2
    violations=1
  fi
done

if [[ "$violations" -ne 0 ]]; then exit 1; fi
echo "quality-ledger-monotonic: PASS (${#HEAD_TIERS[@]} cells checked vs ${BASE})"
