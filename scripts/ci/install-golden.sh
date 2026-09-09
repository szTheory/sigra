#!/usr/bin/env bash
# Fixed receiver for the measured install/scaffold leg. Preparation is caused
# by this child, so it remains inside library-economics.sh's install markers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIAGNOSTIC_PATH="/tmp/sigra-install-golden-diagnostics.json"
readonly ROOT
readonly DIAGNOSTIC_PATH

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

if ((child_status != 0)); then exit "$child_status"; fi

if [[ ! -f "$DIAGNOSTIC_PATH" || -L "$DIAGNOSTIC_PATH" ]]; then
  fail "diagnostic receipt is missing or unsafe"
  exit 1
fi

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
    has("verdict")
  then error("invalid fixture diagnostic schema")
  else [.phases[]] | add
  end
' "$DIAGNOSTIC_PATH")" || { fail "diagnostic receipt failed exact-schema validation"; exit 1; }

if ((phase_sum > raw_duration)); then
  fail "diagnostic phase sum exceeds measured runner duration"
  exit 1
fi

umask 077
diagnostic_temp="$(mktemp "${DIAGNOSTIC_PATH}.tmp.XXXXXX")" || {
  fail "could not create diagnostic temporary file"
  exit 1
}
if ! jq --argjson raw "$raw_duration" '. + {raw_install_duration_ms: $raw}' \
  "$DIAGNOSTIC_PATH" >"$diagnostic_temp"; then
  rm -f "$diagnostic_temp"
  fail "could not finalize diagnostic receipt"
  exit 1
fi
chmod 600 "$diagnostic_temp"
mv -f "$diagnostic_temp" "$DIAGNOSTIC_PATH"
