#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFIER="${SCRIPT_DIR}/verify-library-economics.sh"
RECEIPT="/tmp/sigra-library-economics.json"

PASS=0
FAIL=0
pass() { printf '  PASS: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
cleanup() { rm -f "$RECEIPT"; }
trap cleanup EXIT

write_receipt() {
  local ordinary="$1" install="$2"
  jq -n --argjson ordinary "$ordinary" --argjson install "$install" '{
    schema_version: "sigra.library-economics/v1",
    timing_receipt_path: "/tmp/sigra-library-1-timings.json",
    install_leg_ran: true,
    classes: {
      ordinary: {start_ms: 1000, end_ms: (1000 + $ordinary), duration_ms: $ordinary, conclusion: "success", exit_status: 0},
      install_scaffold: {start_ms: 3000, end_ms: (3000 + $install), duration_ms: $install, conclusion: "success", exit_status: 0}
    }
  }' >"$RECEIPT"
}

run_expect_pass() {
  local label="$1"
  set +e
  local output
  output="$(bash "$VERIFIER" 2>&1)"
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]] && grep -q 'verify-library-economics: PASS' <<<"$output"; then
    pass "$label"
  else
    fail "$label (rc=${rc}): ${output}"
  fi
}

echo "Test A: equality at ratio 2.0 is accepted"
write_receipt 2000 1000
run_expect_pass "2.0 ratio boundary passes"

echo "Test B: install equal to ordinary is accepted"
write_receipt 1000 1000
run_expect_pass "non-dominance equality passes"

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "verify-library-economics.test: FAIL"; exit 1; fi
echo "verify-library-economics.test: PASS"
