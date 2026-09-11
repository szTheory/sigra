#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/install-golden.sh"
RECEIPT="/tmp/sigra-library-install-golden.json"

PASS=0
FAIL=0
pass() { printf '  PASS: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }

TMP_ROOT="$(mktemp -d)"
cleanup() {
  local parent
  parent="$(cd "$(dirname "$TMP_ROOT")" && pwd -P)"
  if [[ -d "$TMP_ROOT" && "$(basename "$TMP_ROOT")" == tmp.* \
    && "$parent" == "$(cd "${TMPDIR:-/tmp}" && pwd -P)" ]]; then
    rm -rf "$TMP_ROOT"
  else
    printf 'install-golden.test: refusing unsafe cleanup: %s\n' "$TMP_ROOT" >&2
  fi
  rm -f "/tmp/sigra-install-golden-diagnostics.json"
  rm -f "$RECEIPT"
}
trap cleanup EXIT

STUB_BIN="${TMP_ROOT}/bin"
CALLS="${TMP_ROOT}/calls"
DIAGNOSTIC="/tmp/sigra-install-golden-diagnostics.json"
mkdir -p "$STUB_BIN"
: >"$CALLS"

cat >"${STUB_BIN}/mix" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|prepared=%s\n' "$*" "${SIGRA_INSTALL_GOLDEN_PREPARED:-}" >>"$SIGRA_TEST_CALLS"
if [[ "${SIGRA_TEST_SKIP_DIAGNOSTIC:-false}" != "true" ]]; then
  cat >"/tmp/sigra-install-golden-diagnostics.json" <<'JSON'
{"schema_version":"sigra.install-fixture-diagnostics/v1","phases":{"phx_new":1,"deps_get":1,"baseline_compile":1,"installer":1,"receiver_compile_runtime":1,"checkout_copy":1},"copy_mode":"copy","variant_count":6,"worker_count":2,"partitions":["a","b","c","d","e","f"],"ports":[41001,41002,41003,41004,41005,41006],"failed_paths":[]}
JSON
fi
# The production runner measures whole-child monotonic time and requires the
# six positive diagnostic phases (sum = 6ms) to fit inside it. Keep this stub
# deterministically above that lower bound instead of relying on process-start
# overhead, which can complete in under 6ms on a warm machine.
sleep 0.02
if [[ "${SIGRA_TEST_SIGNAL:-false}" == "true" ]]; then
  kill -TERM "$$"
fi
exit "${SIGRA_TEST_STATUS:-0}"
STUB
chmod +x "${STUB_BIN}/mix"

EXPECTED='test test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/vault_promotion_test.exs test/upgrade_test.exs|prepared=1'

run_runner() {
  : >"$CALLS"
  rm -f "$DIAGNOSTIC"
  rm -f "$RECEIPT"
  set +e
  RUNNER_OUTPUT="$(PATH="${STUB_BIN}:${PATH}" SIGRA_TEST_CALLS="$CALLS" "$@" bash "$RUNNER" 2>&1)"
  RUNNER_RC=$?
  set -e
}

echo "Test A: exact six paths execute once under fixed prepared mode"
run_runner env SIGRA_INSTALL_GOLDEN_PREPARED=attacker
if [[ "$RUNNER_RC" -eq 0 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]] \
  && [[ "$(cat "$CALLS")" == "$EXPECTED" ]]; then
  pass "fixed receiver universe executes exactly once in prepared mode"
else
  fail "fixed invocation rc=${RUNNER_RC}, calls=$(tr '\n' ';' <"$CALLS"), output=${RUNNER_OUTPUT}"
fi

echo "Test A2: successful child publishes the exact atomic receipt"
if jq -e '
  (keys | sort) == (["conclusion", "diagnostic_path", "duration_ms", "end_ms", "exit_status", "prepared_fixture", "receiver_paths", "schema_version", "start_ms", "worker_ceiling"] | sort) and
  .schema_version == "sigra.library-install-golden/v1" and
  .receiver_paths == [
    "test/sigra/install/features/passkeys_js_test.exs",
    "test/sigra/install/generator_passkeys_opt_out_test.exs",
    "test/sigra/install/golden_diff_test.exs",
    "test/sigra/install/idempotency_test.exs",
    "test/sigra/install/vault_promotion_test.exs",
    "test/upgrade_test.exs"
  ] and
  .start_ms >= 0 and .end_ms > .start_ms and
  .duration_ms == (.end_ms - .start_ms) and
  .exit_status == 0 and .conclusion == "success" and
  .worker_ceiling == 2 and .prepared_fixture == true and
  .diagnostic_path == "/tmp/sigra-install-golden-diagnostics.json"
' "$RECEIPT" >/dev/null 2>&1 && [[ ! -L "$RECEIPT" ]]; then
  pass "successful receipt has the exact raw schema and outcome"
else
  fail "successful receipt missing or malformed"
fi

if jq -e '
  .schema_version == "sigra.install-fixture-diagnostics/v1" and
  .raw_install_duration_ms > 0 and
  ([.phases[]] | add) <= .raw_install_duration_ms and
  (.phases | keys | sort) == (["baseline_compile", "checkout_copy", "deps_get", "installer", "phx_new", "receiver_compile_runtime"] | sort) and
  .variant_count == 6 and .worker_count == 2 and has("verdict") == false
' "$DIAGNOSTIC" >/dev/null; then
  pass "diagnostic phases are complete, bounded, and non-authoritative"
else
  fail "diagnostic receipt missing or malformed"
fi

echo "Test B: child status is process authority"
run_runner env SIGRA_TEST_STATUS=37
if [[ "$RUNNER_RC" -eq 37 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]]; then
  pass "child status 37 is preserved"
else
  fail "child status rc=${RUNNER_RC}, output=${RUNNER_OUTPUT}"
fi

if jq -e '
  .exit_status == 37 and .conclusion == "failure" and
  .duration_ms == (.end_ms - .start_ms) and .duration_ms > 0
' "$RECEIPT" >/dev/null 2>&1; then
  pass "failed child still publishes raw failure evidence"
else
  fail "failed child did not publish a failure receipt"
fi

echo "Test C: signal failure is not converted to green"
run_runner env SIGRA_TEST_SIGNAL=true
if [[ "$RUNNER_RC" -eq 143 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]]; then
  pass "TERM status is preserved"
else
  fail "signal status rc=${RUNNER_RC}, output=${RUNNER_OUTPUT}"
fi

echo "Test D: source exposes no caller-controlled command seam"
if ! grep -Eq 'eval|\$@|SIGRA_(INSTALL_)?COMMAND|bash -c' "$RUNNER" \
  && [[ "$(grep -c 'test/sigra/install/features/passkeys_js_test.exs' "$RUNNER")" == "1" ]] \
  && [[ "$(grep -c 'test/upgrade_test.exs' "$RUNNER")" == "1" ]]; then
  pass "runner source is fixed and each endpoint path appears once"
else
  fail "runner contains a dynamic command seam or duplicated endpoint"
fi

echo "Test E: missing diagnostics fail a successful child closed"
run_runner env SIGRA_TEST_SKIP_DIAGNOSTIC=true
if [[ "$RUNNER_RC" -ne 0 ]] && grep -q 'diagnostic receipt' <<<"$RUNNER_OUTPUT"; then
  pass "missing diagnostics cannot produce a green install leg"
else
  fail "missing diagnostic rc=${RUNNER_RC}, output=${RUNNER_OUTPUT}"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "install-golden.test: FAIL"; exit 1; fi
echo "install-golden.test: PASS"
