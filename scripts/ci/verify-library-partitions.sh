#!/usr/bin/env bash
# Independent fail-closed authority for Phase 235.1 ordinary partition evidence.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMBINED="/tmp/sigra-library-partitions.json"
TIMING_1="/tmp/sigra-library-1-timings.json"
TIMING_2="/tmp/sigra-library-2-timings.json"
MAX_COMBINED_BYTES=1048576
MAX_TIMING_BYTES=10485760

fail() { printf 'verify-library-partitions: FAIL: %s\n' "$*" >&2; exit 1; }

bound_json() {
  local path="$1" maximum="$2" size duplicate_path
  [[ -f "$path" && ! -L "$path" ]] || fail "$path must be a regular non-symlink file"
  size="$(wc -c <"$path" | tr -d ' ')" || fail "cannot size $path"
  [[ "$size" =~ ^[0-9]+$ ]] || fail "$path size is not an integer"
  ((size > 0 && size <= maximum)) || fail "$path violates the byte bound"
  jq -e . "$path" >/dev/null 2>&1 || fail "$path is malformed JSON"
  duplicate_path="$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join(".")' "$path" | LC_ALL=C sort | uniq -d | head -n 1)"
  [[ -z "$duplicate_path" ]] || fail "$path contains duplicate key path: $duplicate_path"
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

bound_json "$COMBINED" "$MAX_COMBINED_BYTES"
bound_json "$TIMING_1" "$MAX_TIMING_BYTES"
bound_json "$TIMING_2" "$MAX_TIMING_BYTES"

jq -e '
  type == "object" and
  (keys | sort) == (["execution_mode","ordinary_universe","partitions","schema_version"] | sort) and
  .schema_version == "sigra.library-partitions/v1" and .execution_mode == "sequential" and
  (.ordinary_universe | type) == "object" and
  (.ordinary_universe | keys | sort) == (["count","duplicate","missing","paths","scaffold_leaks","stale"] | sort) and
  (.ordinary_universe.paths | type) == "array" and
  (.ordinary_universe.count | type) == "number" and
  (.ordinary_universe.count | floor) == .ordinary_universe.count and
  .ordinary_universe.count > 1 and .ordinary_universe.count <= 100000 and
  .ordinary_universe.count == (.ordinary_universe.paths | length) and
  .ordinary_universe.paths == (.ordinary_universe.paths | sort) and
  (.ordinary_universe.paths | unique | length) == .ordinary_universe.count and
  all(.ordinary_universe.paths[]; type == "string" and startswith("test/") and endswith("_test.exs")) and
  .ordinary_universe.missing == [] and .ordinary_universe.stale == [] and
  .ordinary_universe.duplicate == [] and .ordinary_universe.scaffold_leaks == [] and
  (.partitions | type) == "array" and (.partitions | length) == 2 and
  [.partitions[].id] == [1,2]
' "$COMBINED" >/dev/null 2>&1 || fail "combined receipt exact schema or universe predicate failed"

cd "$ROOT" || fail "repository root unavailable"
oracle="$(env MIX_ENV=test mix run --no-compile --no-start -r test/support/ci/library_test_partitions.exs -e \
  'for id <- [1, 2], path <- Sigra.CI.LibraryTestPartitions.partition(id), do: IO.puts("#{id}\t#{path}")')" \
  || fail "fresh partition oracle failed"

for id in 1 2; do
  timing="/tmp/sigra-library-${id}-timings.json"
  expected_timing="$timing"
  manifest="$(mktemp "${TMPDIR:-/tmp}/sigra-library-${id}.XXXXXX")" || fail "cannot create manifest"
  trap 'rm -f "${manifest:-}"' EXIT
  printf '%s\n' "$oracle" | awk -F '\t' -v id="$id" '$1 == id {print $2}' >"$manifest"
  [[ -s "$manifest" ]] || fail "partition $id is empty"
  manifest_json="$(jq -Rsc 'split("\n")[:-1]' "$manifest")" || fail "cannot encode partition $id"
  manifest_sha="$(sha256 "$manifest")" || fail "cannot digest partition $id"

  jq -e --argjson id "$id" --arg timing "$expected_timing" --argjson paths "$manifest_json" --arg sha "$manifest_sha" '
    .partitions[($id - 1)] |
    type == "object" and
    (keys | sort) == (["conclusion","duration_ms","end_ms","exit_status","id","manifest_sha256","paths","start_ms","timing_receipt_path"] | sort) and
    .id == $id and .paths == $paths and .paths == (.paths | sort) and (.paths | length) > 0 and
    .manifest_sha256 == $sha and .timing_receipt_path == $timing and
    (.start_ms | type) == "number" and (.start_ms | floor) == .start_ms and .start_ms >= 0 and
    (.end_ms | type) == "number" and (.end_ms | floor) == .end_ms and .end_ms > .start_ms and
    (.duration_ms | type) == "number" and (.duration_ms | floor) == .duration_ms and
    .duration_ms > 0 and .duration_ms <= 86400000 and .duration_ms == (.end_ms - .start_ms) and
    .conclusion == "success" and .exit_status == 0
  ' "$COMBINED" >/dev/null 2>&1 || fail "partition $id manifest, timing, or outcome predicate failed"

  jq -e --arg partition "$id" --argjson paths "$manifest_json" '
    type == "object" and
    (keys | sort) == (["excluded","failed","invalid","partition","passed","schema_version","skipped","tests","total"] | sort) and
    .schema_version == 1 and .partition == $partition and
    ([.total,.passed,.failed,.skipped,.excluded,.invalid] | all(.[]; type == "number" and floor == . and . >= 0)) and
    .total > 0 and .total <= 100000 and
    .failed == 0 and .invalid == 0 and
    (.passed + .failed + .skipped + .excluded + .invalid) == .total and
    (.tests | type) == "array" and (.tests | length) == .total and
    all(.tests[];
      type == "object" and
      (keys | sort) == (["file","module","name","outcome","time_us"] | sort) and
      (.file | type) == "string" and (.file | IN($paths[])) and
      (.module | type) == "string" and (.module | length) > 0 and
      (.name | type) == "string" and (.name | length) > 0 and
      (.outcome | IN("passed","skipped","excluded")) and
      (.time_us | type) == "number" and (.time_us | floor) == .time_us and .time_us >= 0 and .time_us <= 86400000000) and
    ([.tests[] | [.file,.module,.name]] | unique | length) == .total and
    .tests == (.tests | sort_by([-(.time_us),.file,.module,.name])) and
    ([.tests[].file] | unique | sort) == $paths
  ' "$timing" >/dev/null 2>&1 || fail "partition $id per-test receipt predicate failed"

  rm -f "$manifest"
  trap - EXIT
done

combined_paths="$(jq -c '.ordinary_universe.paths' "$COMBINED")"
oracle_paths="$(printf '%s\n' "$oracle" | cut -f2- | LC_ALL=C sort | jq -Rsc 'split("\n")[:-1]')"
[[ "$combined_paths" == "$oracle_paths" ]] || fail "ordinary universe drifted from the fresh oracle"

p1_paths="$(jq -c '.partitions[0].paths' "$COMBINED")"
p2_paths="$(jq -c '.partitions[1].paths' "$COMBINED")"
jq -en --argjson p1 "$p1_paths" --argjson p2 "$p2_paths" --argjson universe "$oracle_paths" '
  (($p1 + $p2) | sort) == $universe and (($p1 + $p2) | unique | length) == ($p1 | length) + ($p2 | length)
' >/dev/null || fail "partition ownership is not exhaustive and disjoint"

first="$(jq -r '.partitions[0].duration_ms' "$COMBINED")"
second="$(jq -r '.partitions[1].duration_ms' "$COMBINED")"
if ((first >= second)); then maximum="$first" minimum="$second"; else maximum="$second" minimum="$first"; fi
((maximum * 1000 <= minimum * 2000)) || fail "comparability predicate failed: max/min exceeds 2.0"

printf 'verify-library-partitions: PASS\n'
