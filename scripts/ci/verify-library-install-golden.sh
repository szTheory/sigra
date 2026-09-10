#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RECEIPT_PATH="/tmp/sigra-library-install-golden.json"
DIAGNOSTIC_PATH="/tmp/sigra-install-golden-diagnostics.json"
readonly ROOT RECEIPT_PATH DIAGNOSTIC_PATH

fail() {
  printf 'verify-library-install-golden: FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$RECEIPT_PATH" && ! -L "$RECEIPT_PATH" ]] || fail "install receipt must be a regular non-symlink file"
[[ -f "$DIAGNOSTIC_PATH" && ! -L "$DIAGNOSTIC_PATH" ]] || fail "diagnostics must be a regular non-symlink file"

cd "$ROOT"

live_receivers="$(
  rg -l '^[[:space:]]*@moduletag[[:space:]]+:scaffold\b' test --glob '*_test.exs' \
    | LC_ALL=C sort \
    | jq -R -s 'split("\n")[:-1]'
)" || fail "could not derive live scaffold ownership"

[[ "$(jq 'length' <<<"$live_receivers")" -eq 6 ]] || fail "live scaffold ownership must contain exactly six receivers"

receipt_duration="$(jq -er --argjson live "$live_receivers" --arg diagnostic "$DIAGNOSTIC_PATH" '
  if (keys | sort) != (["conclusion", "diagnostic_path", "duration_ms", "end_ms", "exit_status", "prepared_fixture", "receiver_paths", "schema_version", "start_ms", "worker_ceiling"] | sort)
    then error("unexpected receipt keys")
  elif .schema_version != "sigra.library-install-golden/v1"
    then error("invalid schema version")
  elif .receiver_paths != $live or (.receiver_paths | length) != 6 or (.receiver_paths | unique | length) != 6
    then error("receiver paths do not equal live scaffold ownership")
  elif (.start_ms | type) != "number" or (.start_ms | floor) != .start_ms or .start_ms < 0 or
       (.end_ms | type) != "number" or (.end_ms | floor) != .end_ms or .end_ms <= .start_ms or
       (.duration_ms | type) != "number" or (.duration_ms | floor) != .duration_ms or .duration_ms <= 0 or
       .duration_ms != (.end_ms - .start_ms)
    then error("invalid raw duration arithmetic")
  elif .exit_status != 0 or .conclusion != "success"
    then error("install execution did not succeed")
  elif .worker_ceiling != 2
    then error("worker ceiling is not two")
  elif .prepared_fixture != true
    then error("prepared fixture was not proven")
  elif .diagnostic_path != $diagnostic
    then error("diagnostic path is not fixed")
  else .duration_ms
  end
' "$RECEIPT_PATH")" || fail "install receipt failed independent validation"

jq -e --argjson duration "$receipt_duration" '
  if (keys | sort) != (["copy_mode", "failed_paths", "partitions", "phases", "ports", "raw_install_duration_ms", "schema_version", "variant_count", "worker_count"] | sort)
    then error("unexpected diagnostic keys")
  elif .schema_version != "sigra.install-fixture-diagnostics/v1"
    then error("invalid diagnostic schema version")
  elif (.phases | keys | sort) != (["baseline_compile", "checkout_copy", "deps_get", "installer", "phx_new", "receiver_compile_runtime"] | sort) or
       ([.phases[] | select(type != "number" or floor != . or . <= 0)] | length) != 0
    then error("invalid diagnostic phases")
  elif .variant_count != 6 or .worker_count != 2
    then error("invalid diagnostic worker or variant count")
  elif (.copy_mode != "copy" and .copy_mode != "reflink")
    then error("unsafe diagnostic copy mode")
  elif (.partitions | type) != "array" or (.partitions | length) < 6 or
       (.partitions | unique | length) != (.partitions | length) or
       (.ports | type) != "array" or (.ports | length) < 6 or
       (.ports | unique | length) != (.ports | length)
    then error("diagnostic isolation identities are incomplete or duplicated")
  elif (.failed_paths | type) != "array" or (.failed_paths | length) != 0
    then error("diagnostics report failed receivers")
  elif (.raw_install_duration_ms | type) != "number" or
       (.raw_install_duration_ms | floor) != .raw_install_duration_ms or
       .raw_install_duration_ms != $duration or
       ([.phases[]] | add) > .raw_install_duration_ms
    then error("diagnostic timing does not match raw receipt")
  elif has("verdict")
    then error("producer-owned verdict is forbidden")
  else true
  end
' "$DIAGNOSTIC_PATH" >/dev/null || fail "diagnostics failed independent validation"

printf 'verify-library-install-golden: PASS\n'
