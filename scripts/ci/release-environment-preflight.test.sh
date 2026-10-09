#!/usr/bin/env bash
# Hermetic exact-main deployment policy and boolean secret-presence contract.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/release-environment-preflight.sh"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

write_environment() {
  local name="$1"
  local protected="${2:-false}"
  local custom="${3:-true}"
  local policy_json
  if [[ $# -ge 4 ]]; then
    policy_json="$4"
  else
    policy_json='{"total_count":1,"branch_policies":[{"id":1,"name":"main","type":"branch"}]}'
  fi
  mkdir -p "$TMP/policies/$name"
  printf '{"name":"%s","can_admins_bypass":false,"deployment_branch_policy":{"protected_branches":%s,"custom_branch_policies":%s}}\n' \
    "$name" "$protected" "$custom" > "$TMP/policies/$name/environment.json"
  printf '%s\n' "$policy_json" > "$TMP/policies/$name/branch-policies.json"
}

write_valid_fixtures() {
  rm -rf "$TMP/policies"
  write_environment release-automation
  write_environment hex-publish
}

run_preflight() {
  set +e
  OUT="$(bash "$SCRIPT" --repository szTheory/sigra --policy-dir "$TMP/policies" \
    --require-release-token true --require-hex-dry-run-key true \
    --require-hex-publish-key true 2>&1)"
  RC=$?
  set -e
}

echo "Test A: both environments allow exactly main and all required names are present"
write_valid_fixtures
run_preflight
if [[ "$RC" -eq 0 ]] && grep -q 'release-automation: main' <<<"$OUT" && grep -q 'hex-publish: main' <<<"$OUT"; then
  pass "exact-main environments are accepted without displaying secret values"
else
  fail "valid exact-main policy rejected (rc=$RC): $OUT"
fi

echo "Test B: missing environment or policy response -> rejected"
write_valid_fixtures
rm -rf "$TMP/policies/release-automation"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "missing environment policy is rejected"; else fail "missing environment policy accepted"; fi

echo "Test C: all-branches, protected-branches, or disabled custom policy -> rejected"
write_valid_fixtures
write_environment release-automation true true
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "protected-branches policy is rejected"; else fail "protected-branches policy accepted"; fi
write_valid_fixtures
write_environment release-automation false false
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "disabled custom-branch policy is rejected"; else fail "disabled custom-branch policy accepted"; fi
write_valid_fixtures
python3 - "$TMP/policies/release-automation/environment.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as source:
    policy = json.load(source)
policy["can_admins_bypass"] = True
with open(path, "w", encoding="utf-8") as target:
    json.dump(policy, target)
PY
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "admin bypass is rejected"; else fail "admin bypass accepted"; fi

echo "Test D: zero, multiple, wildcard, or tag policy -> rejected"
write_valid_fixtures
write_environment release-automation false true '{"total_count":0,"branch_policies":[]}'
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "zero branch policies are rejected"; else fail "zero branch policies accepted"; fi
write_valid_fixtures
write_environment release-automation false true '[{"id":1,"name":"main","type":"branch"},{"id":2,"name":"release/*","type":"branch"}]'
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "multiple or broad branch policies are rejected"; else fail "multiple branch policies accepted"; fi
write_valid_fixtures
write_environment release-automation false true '[{"id":1,"name":"v*","type":"tag"}]'
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "tag policy is rejected"; else fail "tag policy accepted"; fi

echo "Test E: missing required credential name -> rejected without exposing a value"
write_valid_fixtures
set +e
OUT="$(bash "$SCRIPT" --repository szTheory/sigra --policy-dir "$TMP/policies" \
  --require-release-token false --require-hex-dry-run-key true \
  --require-hex-publish-key true 2>&1)"
RC=$?
set -e
if [[ "$RC" -ne 0 ]] && ! grep -q 'ghp_' <<<"$OUT"; then pass "missing release token is rejected without secret output"; else fail "missing token was not safely rejected: $OUT"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "release-environment-preflight.test: FAIL"
  exit 1
fi
echo "release-environment-preflight.test: PASS"
