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

run_expect_fail() {
  local label="$1" diagnostic="$2"
  set +e
  local output
  output="$(bash "$VERIFIER" 2>&1)"
  local rc=$?
  set -e
  if [[ "$rc" -ne 0 ]] && grep -q "$diagnostic" <<<"$output"; then
    pass "$label"
  else
    fail "$label (rc=${rc}, expected=${diagnostic}): ${output}"
  fi
}

mutate() {
  local filter="$1"
  local next="${RECEIPT}.next"
  jq "$filter" "$RECEIPT" >"$next"
  mv "$next" "$RECEIPT"
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

echo "Test C: one-unit boundary violations are rejected independently"
write_receipt 2001 1000
run_expect_fail "2.0 plus one millisecond fails" "comparability predicate failed"
write_receipt 1000 1001
run_expect_fail "install one millisecond above ordinary fails" "non-dominance predicate failed"

echo "Test D: numeric and arithmetic mutations fail exact raw timing validation"
for spec in \
  'zero|.classes.ordinary.duration_ms = 0 | .classes.ordinary.end_ms = .classes.ordinary.start_ms' \
  'negative|.classes.ordinary.duration_ms = -1 | .classes.ordinary.end_ms = (.classes.ordinary.start_ms - 1)' \
  'fractional|.classes.ordinary.duration_ms = 1.5 | .classes.ordinary.end_ms = 1001.5' \
  'arithmetic|.classes.ordinary.end_ms = 9999' \
  'huge|.classes.ordinary.duration_ms = 9007199254740991 | .classes.ordinary.end_ms = 9007199254741991'; do
  label="${spec%%|*}"; filter="${spec#*|}"
  write_receipt 1000 1000
  mutate "$filter"
  run_expect_fail "${label} timing fails" "predicate failed"
done

echo "Test E: exact schema and class shape mutations fail"
for spec in \
  'missing top key|del(.timing_receipt_path)' \
  'extra top key|.extra = true' \
  'empty classes|.classes = {}' \
  'one class|del(.classes.install_scaffold)' \
  'null classes|.classes = null' \
  'extra class|.classes.other = .classes.ordinary' \
  'missing class key|del(.classes.ordinary.exit_status)' \
  'extra class key|.classes.ordinary.pass = true' \
  'failed conclusion|.classes.ordinary.conclusion = "failure"' \
  'nonzero exit|.classes.ordinary.exit_status = 9' \
  'false execution fact|.install_leg_ran = false'; do
  label="${spec%%|*}"; filter="${spec#*|}"
  write_receipt 1000 1000
  mutate "$filter"
  run_expect_fail "$label fails" "predicate failed"
done

echo "Test F: producer-owned verdict and threshold fields cannot override raw values"
write_receipt 2001 1000
mutate '.pass = true | .ratio_threshold = 999'
run_expect_fail "forged verdict and threshold are rejected" "predicate failed"

echo "Test G: malformed, empty, duplicate, and oversized evidence fails closed"
printf 'not-json\n' >"$RECEIPT"
run_expect_fail "malformed JSON fails" "malformed JSON"
: >"$RECEIPT"
run_expect_fail "empty input fails" "receipt is empty"
printf '%s\n' '{"schema_version":"sigra.library-economics/v1","schema_version":"sigra.library-economics/v1","timing_receipt_path":"/tmp/sigra-library-1-timings.json","install_leg_ran":true,"classes":{"ordinary":{"start_ms":1,"end_ms":2,"duration_ms":1,"conclusion":"success","exit_status":0},"install_scaffold":{"start_ms":3,"end_ms":4,"duration_ms":1,"conclusion":"success","exit_status":0}}}' >"$RECEIPT"
run_expect_fail "duplicate keys fail" "duplicate evidence key"
dd if=/dev/zero bs=65537 count=1 2>/dev/null | tr '\0' x >"$RECEIPT"
run_expect_fail "oversized evidence fails" "exceeds 65536-byte bound"

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "verify-library-economics.test: FAIL"; exit 1; fi
echo "verify-library-economics.test: PASS"
