#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFIER="${SCRIPT_DIR}/verify-library-install-golden.sh"
RECEIPT="/tmp/sigra-library-install-golden.json"
DIAGNOSTIC="/tmp/sigra-install-golden-diagnostics.json"

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
    printf 'verify-library-install-golden.test: refusing unsafe cleanup: %s\n' "$TMP_ROOT" >&2
  fi
  rm -f "$RECEIPT" "$DIAGNOSTIC"
}
trap cleanup EXIT

FIXTURE_ROOT="$TMP_ROOT/fixture-repo"
HERMETIC_BIN="$TMP_ROOT/hermetic-bin"

prepare_fixture_repo() {
  local path tool
  mkdir -p "$FIXTURE_ROOT/scripts/ci" "$HERMETIC_BIN"
  cp "$VERIFIER" "$FIXTURE_ROOT/scripts/ci/verify-library-install-golden.sh"

  for path in \
    test/sigra/install/features/passkeys_js_test.exs \
    test/sigra/install/generator_passkeys_opt_out_test.exs \
    test/sigra/install/golden_diff_test.exs \
    test/sigra/install/idempotency_test.exs \
    test/sigra/install/vault_promotion_test.exs \
    test/upgrade_test.exs; do
    mkdir -p "$FIXTURE_ROOT/$(dirname "$path")"
    printf 'defmodule Fixture do\n  @moduletag :scaffold\nend\n' >"$FIXTURE_ROOT/$path"
  done

  mkdir -p "$FIXTURE_ROOT/test/misleading"
  printf '# @moduletag :scaffold\n' >"$FIXTURE_ROOT/test/misleading/comment_test.exs"
  printf '@moduletag :scaffold_extra\n' >"$FIXTURE_ROOT/test/misleading/substring_test.exs"
  git -C "$FIXTURE_ROOT" init -q
  git -C "$FIXTURE_ROOT" add test scripts/ci/verify-library-install-golden.sh

  for tool in bash dirname find git grep jq mktemp rm sort; do
    ln -s "$(command -v "$tool")" "$HERMETIC_BIN/$tool"
  done
}

verify_fixture() {
  PATH="$HERMETIC_BIN" "$HERMETIC_BIN/bash" \
    "$FIXTURE_ROOT/scripts/ci/verify-library-install-golden.sh" 2>&1
}

write_valid() {
  jq -n '{
    schema_version: "sigra.library-install-golden/v1",
    receiver_paths: [
      "test/sigra/install/features/passkeys_js_test.exs",
      "test/sigra/install/generator_passkeys_opt_out_test.exs",
      "test/sigra/install/golden_diff_test.exs",
      "test/sigra/install/idempotency_test.exs",
      "test/sigra/install/vault_promotion_test.exs",
      "test/upgrade_test.exs"
    ],
    start_ms: 1000,
    end_ms: 1100,
    duration_ms: 100,
    exit_status: 0,
    conclusion: "success",
    worker_ceiling: 2,
    prepared_fixture: true,
    diagnostic_path: "/tmp/sigra-install-golden-diagnostics.json"
  }' >"$RECEIPT"
  jq -n '{
    schema_version: "sigra.install-fixture-diagnostics/v1",
    phases: {phx_new: 10, deps_get: 10, baseline_compile: 10, installer: 10, receiver_compile_runtime: 10, checkout_copy: 10},
    copy_mode: "copy",
    variant_count: 6,
    worker_count: 2,
    partitions: ["a", "b", "c", "d", "e", "f"],
    ports: [41001, 41002, 41003, 41004, 41005, 41006],
    failed_paths: [],
    raw_install_duration_ms: 100
  }' >"$DIAGNOSTIC"
}

verify_passes() {
  local output status
  set +e
  output="$(bash "$VERIFIER" 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 0 && "$output" == "verify-library-install-golden: PASS" ]]
}

verify_fails() {
  local label="$1" output status
  set +e
  output="$(bash "$VERIFIER" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]] && grep -q 'verify-library-install-golden: FAIL' <<<"$output" \
    && ! grep -q 'verify-library-install-golden: PASS' <<<"$output"; then
    pass "$label"
  else
    fail "$label status=${status}, output=${output}"
  fi
}

echo "Test A: exact independently derived receipt passes"
write_valid
if verify_passes; then pass "valid receipt and diagnostics pass"; else fail "valid evidence rejected"; fi

echo "Test A0: production verifier passes with a hermetic no-rg tool path"
prepare_fixture_repo
write_valid
set +e
fixture_output="$(verify_fixture)"
fixture_status=$?
set -e
if [[ "$fixture_status" -eq 0 && "$fixture_output" == "verify-library-install-golden: PASS" ]]; then
  pass "tracked exact ownership passes without ripgrep"
else
  fail "hermetic no-rg verifier failed status=${fixture_status}, output=${fixture_output}"
fi

echo "Test B: each receipt truth pole fails independently"
mutations=(
  'del(.schema_version)'
  '.schema_version = "sigra.library-install-golden/v0"'
  '.receiver_paths |= .[0:5]'
  '.receiver_paths[0] = .receiver_paths[1]'
  '.receiver_paths |= reverse'
  '.receiver_paths[0] = "test/forged_test.exs"'
  '.start_ms = -1'
  '.end_ms = 1099'
  '.duration_ms = 99'
  '.exit_status = 1'
  '.conclusion = "failure"'
  '.worker_ceiling = 3'
  '.prepared_fixture = false'
  '.diagnostic_path = "/tmp/forged.json"'
  '.verified = true'
)
for mutation in "${mutations[@]}"; do
  write_valid
  jq "$mutation" "$RECEIPT" >"${TMP_ROOT}/mutated.json"
  mv "${TMP_ROOT}/mutated.json" "$RECEIPT"
  verify_fails "receipt mutation rejected: ${mutation}"
done

echo "Test C: each diagnostic truth pole fails independently"
diagnostic_mutations=(
  'del(.schema_version)'
  '.schema_version = "sigra.install-fixture-diagnostics/v0"'
  '.phases |= del(.installer)'
  '.phases.installer = 0'
  '.copy_mode = "symlink"'
  '.variant_count = 5'
  '.worker_count = 3'
  '.partitions[1] = .partitions[0]'
  '.ports[1] = .ports[0]'
  '.failed_paths = ["test/upgrade_test.exs"]'
  '.raw_install_duration_ms = 99'
  '.verdict = true'
)
for mutation in "${diagnostic_mutations[@]}"; do
  write_valid
  jq "$mutation" "$DIAGNOSTIC" >"${TMP_ROOT}/mutated.json"
  mv "${TMP_ROOT}/mutated.json" "$DIAGNOSTIC"
  verify_fails "diagnostic mutation rejected: ${mutation}"
done

echo "Test D: missing and unsafe evidence fails closed"
write_valid
rm -f "$RECEIPT"
verify_fails "missing install receipt rejected"
write_valid
rm -f "$DIAGNOSTIC"
verify_fails "missing diagnostics rejected"
write_valid
mv "$DIAGNOSTIC" "${TMP_ROOT}/diagnostic.json"
ln -s "${TMP_ROOT}/diagnostic.json" "$DIAGNOSTIC"
verify_fails "symlink diagnostics rejected"

echo "Test E: unsafe tracked scaffold ownership fails closed"
unsafe_path="test/unsafe owner_test.exs"
printf '@moduletag :scaffold\n' >"$FIXTURE_ROOT/$unsafe_path"
git -C "$FIXTURE_ROOT" add "$unsafe_path"
write_valid
set +e
fixture_output="$(verify_fixture)"
fixture_status=$?
set -e
if [[ "$fixture_status" -ne 0 ]] && grep -q 'verify-library-install-golden: FAIL' <<<"$fixture_output"; then
  pass "unsafe delimiter-bearing ownership path rejected"
else
  fail "unsafe ownership path accepted status=${fixture_status}, output=${fixture_output}"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if ((FAIL > 0)); then echo "verify-library-install-golden.test: FAIL"; exit 1; fi
echo "verify-library-install-golden.test: PASS"
