#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRODUCER="${SCRIPT_DIR}/library-economics.sh"
RECEIPT="/tmp/sigra-library-economics.json"
TIMINGS="/tmp/sigra-library-1-timings.json"

PASS=0
FAIL=0
pass() { printf '  PASS: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }

TMP_ROOT="$(mktemp -d)"
cleanup() {
  local temp_parent
  temp_parent="$(cd "$(dirname "$TMP_ROOT")" && pwd -P)"
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" && "$(basename "$TMP_ROOT")" == tmp.* \
    && "$temp_parent" == "$(cd "${TMPDIR:-/tmp}" && pwd -P)" ]]; then
    rm -rf "$TMP_ROOT"
  else
    printf 'library-economics.test: refusing unsafe cleanup: %s\n' "$TMP_ROOT" >&2
  fi
  [[ ! -d "$RECEIPT" ]] || rmdir "$RECEIPT"
  rm -f "$RECEIPT" "$TIMINGS"
}
trap cleanup EXIT

STUB_BIN="${TMP_ROOT}/bin"
CALLS="${TMP_ROOT}/mix-calls.log"
CLOCK_VALUES="${TMP_ROOT}/clock-values"
mkdir -p "$STUB_BIN"
: >"$CALLS"
printf '1000\n2000\n2000\n3000\n' >"$CLOCK_VALUES"

cat >"${STUB_BIN}/python3" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
value="$(head -n 1 "$SIGRA_TEST_CLOCK_VALUES")"
tail -n +2 "$SIGRA_TEST_CLOCK_VALUES" >"${SIGRA_TEST_CLOCK_VALUES}.next"
mv "${SIGRA_TEST_CLOCK_VALUES}.next" "$SIGRA_TEST_CLOCK_VALUES"
printf '%s\n' "$value"
STUB

cat >"${STUB_BIN}/mix" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|partition=%s|timing=%s\n' "$*" "${MIX_TEST_PARTITION:-}" "${SIGRA_EXUNIT_TIMING_PATH:-}" >>"$SIGRA_TEST_MIX_CALLS"
if [[ "$1" == "test" ]]; then
  if [[ "${SIGRA_TEST_SIGNAL_ORDINARY:-false}" == "true" ]]; then
    kill -TERM "$PPID"
  fi
  if [[ "${SIGRA_TEST_SKIP_TIMING:-false}" != "true" ]]; then
    printf '{"schema_version":1,"partition":"ordinary","tests":[],"total":0,"passed":0,"failed":0,"skipped":0,"excluded":0,"invalid":0}\n' >"$SIGRA_EXUNIT_TIMING_PATH"
  fi
  exit "${SIGRA_TEST_ORDINARY_STATUS:-0}"
fi
exit "${SIGRA_TEST_INSTALL_STATUS:-0}"
STUB
chmod +x "${STUB_BIN}/python3" "${STUB_BIN}/mix"

echo "Test A: fixed successful commands emit both receipts"
rm -f "$RECEIPT" "$TIMINGS"
set +e
OUTPUT="$(PATH="${STUB_BIN}:${PATH}" SIGRA_TEST_CLOCK_VALUES="$CLOCK_VALUES" SIGRA_TEST_MIX_CALLS="$CALLS" bash "$PRODUCER" 2>&1)"
RC=$?
set -e

if [[ "$RC" -eq 0 ]]; then pass "producer exits zero"; else fail "producer rc=${RC}: ${OUTPUT}"; fi
if [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "2" ]] \
  && sed -n '1p' "$CALLS" | grep -Fq 'test --exclude scaffold --formatter ExUnit.CLIFormatter --formatter Sigra.CI.ExUnitTimingFormatter|partition=ordinary|timing=/tmp/sigra-library-1-timings.json' \
  && sed -n '2p' "$CALLS" | grep -Fq 'ci.install_golden|partition=|timing='; then
  pass "ordinary and install commands ran once in fixed order"
else
  fail "unexpected command trace: $(tr '\n' ';' <"$CALLS")"
fi

if jq -e '
  (keys | sort) == (["classes", "install_leg_ran", "schema_version", "timing_receipt_path"] | sort) and
  .schema_version == "sigra.library-economics/v1" and
  .timing_receipt_path == "/tmp/sigra-library-1-timings.json" and
  .install_leg_ran == true and
  (.classes | keys | sort) == (["install_scaffold", "ordinary"] | sort) and
  .classes.ordinary.duration_ms == 1000 and
  .classes.install_scaffold.duration_ms == 1000
' "$RECEIPT" >/dev/null 2>&1; then
  pass "exact two-class receipt carries raw integer timings"
else
  fail "receipt missing or malformed"
fi

if jq -e '.partition == "ordinary" and .schema_version == 1' "$TIMINGS" >/dev/null 2>&1; then
  pass "ordinary child produced the per-test timing receipt"
else
  fail "per-test timing receipt missing"
fi

reset_fixture() {
  rm -f "$RECEIPT" "$TIMINGS"
  : >"$CALLS"
  printf '%s\n' "${1:-1000}" "${2:-2000}" "${3:-2000}" "${4:-3000}" >"$CLOCK_VALUES"
}

run_producer() {
  set +e
  PRODUCER_OUTPUT="$(PATH="${STUB_BIN}:${PATH}" SIGRA_TEST_CLOCK_VALUES="$CLOCK_VALUES" \
    SIGRA_TEST_MIX_CALLS="$CALLS" "$@" bash "$PRODUCER" 2>&1)"
  PRODUCER_RC=$?
  set -e
}

echo "Test B: ordinary failure is retained and skips install"
reset_fixture
run_producer env SIGRA_TEST_ORDINARY_STATUS=23
if [[ "$PRODUCER_RC" -eq 23 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]] \
  && jq -e '.install_leg_ran == false and .classes.ordinary.exit_status == 23 and .classes.ordinary.conclusion == "failure" and .classes.install_scaffold.conclusion == "not_run"' "$RECEIPT" >/dev/null; then
  pass "ordinary status 23 survives receipt publication and install is skipped"
else
  fail "ordinary failure contract rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi

echo "Test C: install failure is retained after both legs"
reset_fixture
run_producer env SIGRA_TEST_INSTALL_STATUS=37
if [[ "$PRODUCER_RC" -eq 37 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "2" ]] \
  && jq -e '.install_leg_ran == true and .classes.ordinary.exit_status == 0 and .classes.install_scaffold.exit_status == 37 and .classes.install_scaffold.conclusion == "failure"' "$RECEIPT" >/dev/null; then
  pass "install status 37 survives receipt publication"
else
  fail "install failure contract rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi

echo "Test D: missing same-run timing receipt fails before install"
reset_fixture
run_producer env SIGRA_TEST_SKIP_TIMING=true
if [[ "$PRODUCER_RC" -ne 0 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]] \
  && grep -q 'no safe per-test timing receipt' <<<"$PRODUCER_OUTPUT" \
  && jq -e '.install_leg_ran == false and .classes.ordinary.conclusion == "failure"' "$RECEIPT" >/dev/null; then
  pass "missing timing evidence fails closed without duplicate or install run"
else
  fail "missing timing contract rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi

echo "Test E: signal status is retained in diagnostic receipt"
reset_fixture
run_producer env SIGRA_TEST_SIGNAL_ORDINARY=true
if [[ "$PRODUCER_RC" -eq 143 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]] \
  && jq -e '.install_leg_ran == false and .classes.ordinary.exit_status == 143 and .classes.ordinary.conclusion == "failure"' "$RECEIPT" >/dev/null; then
  pass "TERM exits 143 and retains diagnostic evidence"
else
  fail "signal contract rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi

echo "Test F: receipt-write failure cannot turn a successful run green"
reset_fixture
mkdir "$RECEIPT"
run_producer env
if [[ "$PRODUCER_RC" -ne 0 ]] && grep -q 'receipt path is a directory' <<<"$PRODUCER_OUTPUT"; then
  pass "publication failure exits non-zero with a diagnostic"
else
  fail "receipt-write failure rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi
rmdir "$RECEIPT"

echo "Test F2: receipt-write failure never masks an ordinary child status"
reset_fixture
mkdir "$RECEIPT"
run_producer env SIGRA_TEST_ORDINARY_STATUS=41
if [[ "$PRODUCER_RC" -eq 41 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]]; then
  pass "ordinary status 41 wins over receipt publication failure"
else
  fail "child/write precedence rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi
rmdir "$RECEIPT"

echo "Test G: zero measured duration is rejected rather than synthesized"
reset_fixture 1000 1000 2000 3000
run_producer env
if [[ "$PRODUCER_RC" -ne 0 ]] && grep -q 'non-positive ordinary duration' <<<"$PRODUCER_OUTPUT"; then
  pass "zero duration fails as invalid raw evidence"
else
  fail "zero duration rc=${PRODUCER_RC}, output=${PRODUCER_OUTPUT}"
fi

echo "Test H: prepared-fixture reset remains inside install timing markers"
install_start_line="$(grep -n 'install_start=.*clock_ms' "$PRODUCER" | cut -d: -f1)"
diagnostic_reset_line="$(grep -n 'rm -f.*sigra-install-golden-diagnostics' "$PRODUCER" | cut -d: -f1)"
install_call_line="$(grep -n '^mix ci.install_golden$' "$PRODUCER" | cut -d: -f1)"
install_end_line="$(grep -n 'install_end=.*clock_ms' "$PRODUCER" | cut -d: -f1)"
if [[ -n "$diagnostic_reset_line" ]] \
  && ((install_start_line < diagnostic_reset_line)) \
  && ((diagnostic_reset_line < install_call_line)) \
  && ((install_call_line < install_end_line)); then
  pass "all prepared-fixture state begins inside the measured install interval"
else
  fail "prepared fixture marker order is not start < reset < child < end"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "library-economics.test: FAIL"; exit 1; fi
echo "library-economics.test: PASS"
