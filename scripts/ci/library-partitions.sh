#!/usr/bin/env bash
# Fixed sequential producer for exhaustive ordinary-library partition evidence.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RECEIPT_PATH="/tmp/sigra-library-partitions.json"
MANIFEST_1="/tmp/sigra-library-partition-1.paths"
MANIFEST_2="/tmp/sigra-library-partition-2.paths"
TIMING_1="/tmp/sigra-library-1-timings.json"
TIMING_2="/tmp/sigra-library-2-timings.json"
MAX_DURATION_MS=86400000

declare -a start_ms=(0 0 0) end_ms=(0 0 0) duration_ms=(0 0 0) status=(0 0 0)
declare -a conclusion=(not_run not_run not_run)

fail() { printf 'library-partitions: FAIL: %s\n' "$*" >&2; }
clock_ms() { python3 -c 'import time; print(time.monotonic_ns() // 1000000)'; }

emit_manifests() {
  env MIX_ENV=test mix run --no-compile --no-start -r test/support/ci/library_test_partitions.exs -e \
    'for id <- [1, 2], path <- Sigra.CI.LibraryTestPartitions.partition(id), do: IO.puts("#{id}\t#{path}")'
}

manifest_sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

normalize_timing_paths() {
  local timing="$1" temporary
  temporary="$(mktemp "${timing}.tmp.XXXXXX")" || return 1

  jq --arg root_prefix "$ROOT/" '
    if all(.tests[]; (.file | startswith("test/")) or (.file | startswith($root_prefix + "test/"))) then
      .tests |= map(if .file | startswith($root_prefix) then .file |= ltrimstr($root_prefix) else . end)
    else
      error("timing receipt contains a path outside the repository test tree")
    end
  ' "$timing" >"$temporary" || { rm -f "$temporary"; return 1; }

  chmod 600 "$temporary" && mv -f "$temporary" "$timing"
}

write_receipt() {
  local temporary
  umask 077
  temporary="$(mktemp "${RECEIPT_PATH}.tmp.XXXXXX")" || return 1

  jq -n \
    --argjson universe_paths "$(cat "$MANIFEST_1" "$MANIFEST_2" | LC_ALL=C sort | jq -Rsc 'split("\n")[:-1]')" \
    --argjson p1_paths "$(jq -Rsc 'split("\n")[:-1]' "$MANIFEST_1")" \
    --argjson p2_paths "$(jq -Rsc 'split("\n")[:-1]' "$MANIFEST_2")" \
    --arg p1_sha "$(manifest_sha "$MANIFEST_1")" --arg p2_sha "$(manifest_sha "$MANIFEST_2")" \
    --argjson p1_start "${start_ms[1]}" --argjson p1_end "${end_ms[1]}" \
    --argjson p1_duration "${duration_ms[1]}" --arg p1_conclusion "${conclusion[1]}" \
    --argjson p1_status "${status[1]}" \
    --argjson p2_start "${start_ms[2]}" --argjson p2_end "${end_ms[2]}" \
    --argjson p2_duration "${duration_ms[2]}" --arg p2_conclusion "${conclusion[2]}" \
    --argjson p2_status "${status[2]}" \
    '{schema_version:"sigra.library-partitions/v1", execution_mode:"sequential",
      ordinary_universe:{paths:$universe_paths,count:($universe_paths|length),missing:[],stale:[],duplicate:[],scaffold_leaks:[]},
      partitions:[
        {id:1,paths:$p1_paths,manifest_sha256:$p1_sha,timing_receipt_path:"/tmp/sigra-library-1-timings.json",start_ms:$p1_start,end_ms:$p1_end,duration_ms:$p1_duration,conclusion:$p1_conclusion,exit_status:$p1_status},
        {id:2,paths:$p2_paths,manifest_sha256:$p2_sha,timing_receipt_path:"/tmp/sigra-library-2-timings.json",start_ms:$p2_start,end_ms:$p2_end,duration_ms:$p2_duration,conclusion:$p2_conclusion,exit_status:$p2_status}
      ]}' >"$temporary" || { rm -f "$temporary"; return 1; }

  chmod 600 "$temporary" && mv -f "$temporary" "$RECEIPT_PATH"
}

run_partition() {
  local id="$1" manifest timing
  local -a paths
  manifest="/tmp/sigra-library-partition-${id}.paths"
  timing="/tmp/sigra-library-${id}-timings.json"
  mapfile -t paths <"$manifest"
  ((${#paths[@]} > 0)) || { fail "partition ${id} is empty"; status[id]=1; conclusion[id]=failure; return 1; }
  rm -f "$timing"
  start_ms[id]="$(clock_ms)" || return 1
  MIX_TEST_PARTITION="$id" SIGRA_EXUNIT_TIMING_PATH="$timing" \
    mix test "${paths[@]}" --formatter ExUnit.CLIFormatter --formatter Sigra.CI.ExUnitTimingFormatter
  status[id]=$?
  end_ms[id]="$(clock_ms)" || return 1
  while ((end_ms[id] <= start_ms[id])); do end_ms[id]="$(clock_ms)" || return 1; done
  duration_ms[id]=$((end_ms[id] - start_ms[id]))
  if ((duration_ms[id] > MAX_DURATION_MS)); then status[id]=1; fi
  if ((status[id] == 0)) && ! normalize_timing_paths "$timing"; then status[id]=1; fi
  if ((status[id] == 0)) && [[ -f "$timing" && ! -L "$timing" ]]; then
    conclusion[id]=success
    return 0
  fi
  conclusion[id]=failure
  if ((status[id] == 0)); then status[id]=1; fi
  return "${status[$id]}"
}

cd "$ROOT" || { fail "repository root unavailable"; exit 1; }
rm -f "$RECEIPT_PATH" "$MANIFEST_1" "$MANIFEST_2" "$TIMING_1" "$TIMING_2"

manifest_lines="$(emit_manifests)" || { fail "partition oracle failed"; exit 1; }
printf '%s\n' "$manifest_lines" | awk -F '\t' '$1 == "1" {print $2}' >"$MANIFEST_1"
printf '%s\n' "$manifest_lines" | awk -F '\t' '$1 == "2" {print $2}' >"$MANIFEST_2"

first_status=0
partition_1_digest=""
run_partition 1 || first_status=$?
if ((first_status == 0)); then
  [[ -f "$TIMING_1" && ! -L "$TIMING_1" ]] || {
    fail "partition 1 timing receipt is not a regular non-symlink file"
    first_status=1
  }
fi
if ((first_status == 0)); then
  partition_1_digest="$(manifest_sha "$TIMING_1")" || {
    fail "could not digest partition 1 timing receipt"
    first_status=1
  }
fi
if ((first_status == 0)); then run_partition 2 || first_status=$?; fi
if ((first_status == 0)); then
  if [[ ! -f "$TIMING_1" || -L "$TIMING_1" ]] ||
    [[ "$(manifest_sha "$TIMING_1")" != "$partition_1_digest" ]]; then
    fail "partition 2 changed partition 1 timing receipt"
    status[2]=1
    conclusion[2]=failure
    first_status=1
  fi
fi
write_receipt || { fail "could not publish raw combined receipt"; exit 1; }
exit "$first_status"
