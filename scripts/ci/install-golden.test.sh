#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/install-golden.sh"

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
}
trap cleanup EXIT

STUB_BIN="${TMP_ROOT}/bin"
CALLS="${TMP_ROOT}/calls"
mkdir -p "$STUB_BIN"
: >"$CALLS"

cat >"${STUB_BIN}/mix" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|prepared=%s\n' "$*" "${SIGRA_INSTALL_GOLDEN_PREPARED:-}" >>"$SIGRA_TEST_CALLS"
if [[ "${SIGRA_TEST_SIGNAL:-false}" == "true" ]]; then
  kill -TERM "$$"
fi
exit "${SIGRA_TEST_STATUS:-0}"
STUB
chmod +x "${STUB_BIN}/mix"

EXPECTED='test test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/vault_promotion_test.exs test/upgrade_test.exs|prepared=1'

run_runner() {
  : >"$CALLS"
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

echo "Test B: child status is process authority"
run_runner env SIGRA_TEST_STATUS=37
if [[ "$RUNNER_RC" -eq 37 ]] && [[ "$(wc -l <"$CALLS" | tr -d ' ')" == "1" ]]; then
  pass "child status 37 is preserved"
else
  fail "child status rc=${RUNNER_RC}, output=${RUNNER_OUTPUT}"
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

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "install-golden.test: FAIL"; exit 1; fi
echo "install-golden.test: PASS"
