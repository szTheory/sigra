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
  printf '{"schema_version":1,"partition":"ordinary","tests":[],"total":0,"passed":0,"failed":0,"skipped":0,"excluded":0,"invalid":0}\n' >"$SIGRA_EXUNIT_TIMING_PATH"
fi
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

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "library-economics.test: FAIL"; exit 1; fi
echo "library-economics.test: PASS"
