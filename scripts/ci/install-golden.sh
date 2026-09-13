#!/usr/bin/env bash
# Fixed receiver for the measured install/scaffold leg. Preparation is caused
# by this child, so it remains inside library-economics.sh's install markers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIAGNOSTIC_PATH="/tmp/sigra-install-golden-diagnostics.json"
RECEIPT_PATH="/tmp/sigra-library-install-golden.json"
readonly ROOT
readonly DIAGNOSTIC_PATH
readonly RECEIPT_PATH

receiver_paths=(
  test/sigra/install/features/passkeys_js_test.exs
  test/sigra/install/generator_passkeys_opt_out_test.exs
  test/sigra/install/golden_diff_test.exs
  test/sigra/install/idempotency_test.exs
  test/sigra/install/vault_promotion_test.exs
  test/upgrade_test.exs
)
readonly receiver_paths

cd "$ROOT"
export SIGRA_INSTALL_GOLDEN_PREPARED=1
rm -f "$RECEIPT_PATH" "$DIAGNOSTIC_PATH"

clock_ms() {
  python3 -c 'import time; print(time.monotonic_ns() // 1000000)'
}

fail() { printf 'install-golden: FAIL: %s\n' "$*" >&2; }

child_pid=""
forward_signal() {
  local signal="$1"
  if [[ -n "$child_pid" ]]; then kill -"$signal" "$child_pid" 2>/dev/null || true; fi
}
trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM

runner_start="$(clock_ms)" || { fail "monotonic clock failed"; exit 1; }
mix test "${receiver_paths[@]}" &
child_pid=$!
set +e
wait "$child_pid"
child_status=$?
set -e
child_pid=""
if ! runner_end="$(clock_ms)"; then
  fail "monotonic clock failed"
  if ((child_status != 0)); then exit "$child_status"; else exit 1; fi
fi
raw_duration=$((runner_end - runner_start))
if ((raw_duration <= 0)); then raw_duration=1; fi

final_status="$child_status"
if ((child_status == 0)); then
  if [[ ! -f "$DIAGNOSTIC_PATH" || -L "$DIAGNOSTIC_PATH" ]]; then
    fail "diagnostic receipt is missing or unsafe"
    final_status=1
  else
    phase_sum="$(jq -er '
      if (keys | sort) != (["copy_mode", "failed_paths", "partitions", "phases", "ports", "schema_version", "variant_count", "worker_count"] | sort) or
        .schema_version != "sigra.install-fixture-diagnostics/v1" or
        (.phases | keys | sort) != (["baseline_compile", "checkout_copy", "deps_get", "installer", "phx_new", "receiver_compile_runtime"] | sort) or
        ([.phases[] | select(type != "number" or floor != . or . <= 0)] | length) != 0 or
        .variant_count != 6 or .worker_count != 2 or
        (.copy_mode != "copy" and .copy_mode != "reflink") or
        (.partitions | length) < 6 or (.ports | length) < 6 or
        ((.partitions | unique | length) != (.partitions | length)) or
        ((.ports | unique | length) != (.ports | length)) or
        (.failed_paths | type) != "array" or (.failed_paths | length) != 0 or
        has("verdict")
      then error("invalid fixture diagnostic schema")
      else [.phases[]] | add
      end
    ' "$DIAGNOSTIC_PATH")" || {
      fail "diagnostic receipt failed exact-schema validation"
      final_status=1
      phase_sum=""
    }

    if [[ -n "$phase_sum" ]] && ((phase_sum > raw_duration)); then
      fail "diagnostic phase sum exceeds measured runner duration"
      final_status=1
    fi

    if ((final_status == 0)); then
      umask 077
      diagnostic_temp="$(mktemp "${DIAGNOSTIC_PATH}.tmp.XXXXXX")" || {
        fail "could not create diagnostic temporary file"
        final_status=1
        diagnostic_temp=""
      }
      if [[ -n "${diagnostic_temp:-}" ]]; then
        if ! jq --argjson raw "$raw_duration" '. + {raw_install_duration_ms: $raw}' \
          "$DIAGNOSTIC_PATH" >"$diagnostic_temp"; then
          rm -f "$diagnostic_temp"
          fail "could not finalize diagnostic receipt"
          final_status=1
        else
          chmod 600 "$diagnostic_temp"
          mv -f "$diagnostic_temp" "$DIAGNOSTIC_PATH"
        fi
      fi
    fi
  fi
fi

if ((final_status == 0)); then conclusion="success"; else conclusion="failure"; fi
receiver_json="$(printf '%s\n' "${receiver_paths[@]}" | jq -R -s 'split("\n")[:-1]')" || {
  fail "could not encode receiver paths"
  exit 1
}
umask 077
receipt_temp="$(mktemp "${RECEIPT_PATH}.tmp.XXXXXX")" || {
  fail "could not create install receipt temporary file"
  exit 1
}
if ! jq -n \
  --arg schema_version "sigra.library-install-golden/v1" \
  --argjson receiver_paths "$receiver_json" \
  --argjson start_ms "$runner_start" \
  --argjson end_ms "$runner_end" \
  --argjson duration_ms "$raw_duration" \
  --argjson exit_status "$final_status" \
  --arg conclusion "$conclusion" \
  --argjson worker_ceiling 2 \
  --argjson prepared_fixture true \
  --arg diagnostic_path "$DIAGNOSTIC_PATH" \
  '{schema_version: $schema_version, receiver_paths: $receiver_paths,
    start_ms: $start_ms, end_ms: $end_ms, duration_ms: $duration_ms,
    exit_status: $exit_status, conclusion: $conclusion,
    worker_ceiling: $worker_ceiling, prepared_fixture: $prepared_fixture,
    diagnostic_path: $diagnostic_path}' >"$receipt_temp"; then
  rm -f "$receipt_temp"
  fail "could not write install receipt"
  exit 1
fi
chmod 600 "$receipt_temp"
mv -f "$receipt_temp" "$RECEIPT_PATH"

exit "$final_status"
