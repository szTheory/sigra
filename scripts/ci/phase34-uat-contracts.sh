#!/usr/bin/env bash
# Mechanical checks for Phase 34 /gsd-verify-work closure without human
# confirmation. See .planning/milestones/v1.2-phases/34-*/34-UAT.md for the
# user-observable mapping; this script enforces the Phase 34-02 PLAN grep
# contracts on 28-VERIFICATION.md plus smoke harness parseability (34-01 SUMMARY).
# Phases 27-35 (v1.2 Admin Dashboard) are archived under
# .planning/milestones/v1.2-phases/ once the milestone closed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VFY="${ROOT}/.planning/milestones/v1.2-phases/28-user-operations-surface/28-VERIFICATION.md"
SMOKE="${ROOT}/scripts/ci/admin-acceptance-smoke.sh"

fail() {
  echo "phase34-uat-contracts: FAIL: $*" >&2
  exit 1
}

echo "==> phase34-uat-contracts: bash -n admin-acceptance-smoke.sh"
bash -n "${SMOKE}"

echo "==> phase34-uat-contracts: 28-VERIFICATION.md structure (Phase 34 Plan 02)"
[[ -f "${VFY}" ]] || fail "missing ${VFY}"
grep -q "Observable Truths" "${VFY}" || fail "missing heading Observable Truths"
grep -Eq '\(library\)|\(test/example\)|\(generated host / CI\)' "${VFY}" || fail "missing evidence lane tags"
n_user_rows="$(grep -E 'USER-0[1-5]' "${VFY}" | wc -l | tr -d ' ')"
[[ "${n_user_rows}" -ge 5 ]] || fail "expected >= 5 USER-0x lines, got ${n_user_rows}"
lines="$(wc -l < "${VFY}" | tr -d ' ')"
[[ "${lines}" -ge 80 ]] || fail "expected >= 80 lines in 28-VERIFICATION.md, got ${lines}"
grep -q "admin-acceptance-smoke.sh --test" "${VFY}" || fail "missing admin-acceptance-smoke.sh --test commands"
grep -q "Disconfirmation" "${VFY}" || fail "missing Disconfirmation section"
grep -Eq 'VFY-01 generated host|Phase 30|human-UAT|UAT' "${VFY}" || fail "missing VFY-01 / Phase 30 / human-UAT / UAT cross-refs"
n_cmd_lines="$(grep -E 'mix test|playwright test|admin-acceptance-smoke' "${VFY}" | wc -l | tr -d ' ')"
[[ "${n_cmd_lines}" -ge 6 ]] || fail "expected >= 6 command reference lines, got ${n_cmd_lines}"

echo "OK: phase34-uat-contracts (bash -n smoke + 28-VERIFICATION.md contracts)"
