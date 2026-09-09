#!/usr/bin/env bash
# Fixed two-leg producer for Phase 235.1 library-suite economics evidence.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RECEIPT_PATH="/tmp/sigra-library-economics.json"
TIMING_PATH="/tmp/sigra-library-1-timings.json"

ordinary_start=0
ordinary_end=0
ordinary_duration=0
ordinary_status=0
ordinary_conclusion="not_run"
install_start=0
install_end=0
install_duration=0
install_status=0
install_conclusion="not_run"
install_leg_ran=false

fail() { printf 'library-economics: FAIL: %s\n' "$*" >&2; }

clock_ms() {
  python3 -c 'import time; print(time.monotonic_ns() // 1000000)'
}

measured_duration() {
  local class="$1" start="$2" end="$3" duration
  duration=$((end - start))
  if ((duration <= 0)); then
    fail "non-positive ${class} duration is invalid raw evidence"
    return 1
  fi
  if ((duration > 86400000)); then
    fail "${class} duration exceeds the 24-hour evidence bound"
    return 1
  fi
  printf '%s\n' "$duration"
}

write_receipt() {
  local temp_path

  [[ "$RECEIPT_PATH" == "/tmp/sigra-library-economics.json" ]] || {
    fail "receipt path is not allowlisted"
    return 1
  }
  [[ ! -d "$RECEIPT_PATH" ]] || {
    fail "receipt path is a directory"
    return 1
  }

  umask 077
  temp_path="$(mktemp "${RECEIPT_PATH}.tmp.XXXXXX")" || {
    fail "could not create private receipt temporary file"
    return 1
  }

  if ! jq -n \
    --arg schema "sigra.library-economics/v1" \
    --arg timing_path "$TIMING_PATH" \
    --argjson install_ran "$install_leg_ran" \
    --argjson ordinary_start "$ordinary_start" \
    --argjson ordinary_end "$ordinary_end" \
    --argjson ordinary_duration "$ordinary_duration" \
    --arg ordinary_conclusion "$ordinary_conclusion" \
    --argjson ordinary_status "$ordinary_status" \
    --argjson install_start "$install_start" \
    --argjson install_end "$install_end" \
    --argjson install_duration "$install_duration" \
    --arg install_conclusion "$install_conclusion" \
    --argjson install_status "$install_status" \
    '{schema_version: $schema, timing_receipt_path: $timing_path,
      install_leg_ran: $install_ran,
      classes: {
        ordinary: {start_ms: $ordinary_start, end_ms: $ordinary_end,
          duration_ms: $ordinary_duration, conclusion: $ordinary_conclusion,
          exit_status: $ordinary_status},
        install_scaffold: {start_ms: $install_start, end_ms: $install_end,
          duration_ms: $install_duration, conclusion: $install_conclusion,
          exit_status: $install_status}
      }}' >"$temp_path"; then
    rm -f "$temp_path"
    fail "could not encode receipt"
    return 1
  fi

  chmod 600 "$temp_path" || {
    rm -f "$temp_path"
    fail "could not set private receipt permissions"
    return 1
  }
  mv -f "$temp_path" "$RECEIPT_PATH" || {
    rm -f "$temp_path"
    fail "could not atomically publish receipt"
    return 1
  }
}

finish() {
  local intended_status="$1" receipt_status=0
  write_receipt || receipt_status=$?
  if ((intended_status != 0)); then
    exit "$intended_status"
  fi
  exit "$receipt_status"
}

trap 'ordinary_conclusion="failure"; ordinary_status=130; finish 130' INT
trap 'ordinary_conclusion="failure"; ordinary_status=143; finish 143' TERM

cd "$ROOT" || { fail "repository root unavailable"; exit 1; }
rm -f "$TIMING_PATH"

ordinary_start="$(clock_ms)" || { fail "monotonic clock failed"; exit 1; }
MIX_TEST_PARTITION=ordinary \
SIGRA_EXUNIT_TIMING_PATH="$TIMING_PATH" \
mix test --exclude scaffold \
  --formatter ExUnit.CLIFormatter \
  --formatter Sigra.CI.ExUnitTimingFormatter
ordinary_status=$?
ordinary_end="$(clock_ms)" || { fail "monotonic clock failed"; exit 1; }
if ! ordinary_duration="$(measured_duration ordinary "$ordinary_start" "$ordinary_end")"; then
  ordinary_conclusion="failure"
  finish 1
fi

if ((ordinary_status != 0)); then
  ordinary_conclusion="failure"
  finish "$ordinary_status"
fi

if [[ ! -f "$TIMING_PATH" || -L "$TIMING_PATH" ]]; then
  ordinary_conclusion="failure"
  fail "ordinary command emitted no safe per-test timing receipt"
  finish 1
fi
ordinary_conclusion="success"

install_leg_ran=true
install_start="$(clock_ms)" || { fail "monotonic clock failed"; finish 1; }
mix ci.install_golden
install_status=$?
install_end="$(clock_ms)" || { fail "monotonic clock failed"; finish 1; }
if ! install_duration="$(measured_duration install_scaffold "$install_start" "$install_end")"; then
  install_conclusion="failure"
  finish 1
fi
if ((install_status == 0)); then
  install_conclusion="success"
else
  install_conclusion="failure"
fi

finish "$install_status"
