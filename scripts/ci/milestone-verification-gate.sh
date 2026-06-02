#!/usr/bin/env bash
# Fail if a completed v1.2 roadmap phase is missing its *-VERIFICATION.md.
# Phase 35 / ROADMAP SC4. v1.2 (Admin Dashboard) phases 27-35 are archived under
# .planning/milestones/v1.2-phases/ once the milestone closed, so search all of
# .planning/ rather than only the active .planning/phases/ working set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "milestone-verification-gate: FAIL: $*" >&2
  exit 1
}

# Phases 33–34 closed via UAT + plan summaries without standalone *-VERIFICATION.md;
# extend this list when those artifacts exist.
PHASES_NEEDING_VERIFICATION=(27 28 29 30 31 32 35)

echo "==> milestone-verification-gate: checking phases ${PHASES_NEEDING_VERIFICATION[*]}"

for n in "${PHASES_NEEDING_VERIFICATION[@]}"; do
  # Match both `27-VERIFICATION.md` and decimal phases like `28-01-VERIFICATION.md`.
  found="$(
    find "${ROOT}/.planning" \( -name "${n}-VERIFICATION.md" -o -name "${n}-*-VERIFICATION.md" \) \
      2>/dev/null | head -1 || true
  )"
  if [[ -z "${found}" ]]; then
    fail "missing VERIFICATION for phase ${n}"
  fi
  grep -q "##" "${found}" || fail "${found} missing heading ##"
  grep -qi "verification" "${found}" || fail "${found} missing verification marker"
done

echo "OK: milestone-verification-gate"
