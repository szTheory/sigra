#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$ROOT/scripts/ci/verify-library-partitions.sh"
COMBINED="/tmp/sigra-library-partitions.json"
TIMING_1="/tmp/sigra-library-1-timings.json"
TIMING_2="/tmp/sigra-library-2-timings.json"

fail() { printf 'verify-library-partitions.test: FAIL: %s\n' "$*" >&2; exit 1; }
[[ -x "$VERIFIER" ]] || fail "verifier must exist and be executable"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-library-verifier-test.XXXXXX")"
trap 'rm -rf "$test_root"; rm -f "$COMBINED" "$TIMING_1" "$TIMING_2"' EXIT

oracle="$(cd "$ROOT" && env MIX_ENV=test mix run --no-compile --no-start -r test/support/ci/library_test_partitions.exs -e \
  'for id <- [1, 2], path <- Sigra.CI.LibraryTestPartitions.partition(id), do: IO.puts("#{id}\t#{path}")')"

for id in 1 2; do
  paths="$(printf '%s\n' "$oracle" | awk -F '\t' -v id="$id" '$1 == id {print $2}' | jq -Rsc 'split("\n")[:-1]')"
  jq -n --arg partition "$id" --argjson paths "$paths" '
    ($paths | map({file:.,module:"Sigra.PartitionContractTest",name:("test " + .),time_us:1,outcome:"passed"})) as $tests |
    {failed:0,excluded:0,invalid:0,partition:$partition,passed:($tests|length),schema_version:1,skipped:0,tests:$tests,total:($tests|length)}
  ' >"/tmp/sigra-library-${id}-timings.json"
done

p1_paths="$(printf '%s\n' "$oracle" | awk -F '\t' '$1 == "1" {print $2}' | jq -Rsc 'split("\n")[:-1]')"
p2_paths="$(printf '%s\n' "$oracle" | awk -F '\t' '$1 == "2" {print $2}' | jq -Rsc 'split("\n")[:-1]')"
p1_sha="$(printf '%s\n' "$oracle" | awk -F '\t' '$1 == "1" {print $2}' | shasum -a 256 | awk '{print $1}')"
p2_sha="$(printf '%s\n' "$oracle" | awk -F '\t' '$1 == "2" {print $2}' | shasum -a 256 | awk '{print $1}')"
universe="$(printf '%s\n' "$oracle" | cut -f2- | LC_ALL=C sort | jq -Rsc 'split("\n")[:-1]')"

jq -n --argjson universe "$universe" --argjson p1 "$p1_paths" --argjson p2 "$p2_paths" \
  --arg p1_sha "$p1_sha" --arg p2_sha "$p2_sha" '
  {schema_version:"sigra.library-partitions/v1",execution_mode:"sequential",
   ordinary_universe:{paths:$universe,count:($universe|length),missing:[],stale:[],duplicate:[],scaffold_leaks:[]},
   partitions:[
    {id:1,paths:$p1,manifest_sha256:$p1_sha,timing_receipt_path:"/tmp/sigra-library-1-timings.json",start_ms:100,end_ms:200,duration_ms:100,conclusion:"success",exit_status:0},
    {id:2,paths:$p2,manifest_sha256:$p2_sha,timing_receipt_path:"/tmp/sigra-library-2-timings.json",start_ms:300,end_ms:450,duration_ms:150,conclusion:"success",exit_status:0}]}
' >"$COMBINED"

cp "$COMBINED" "$test_root/combined.valid"
cp "$TIMING_1" "$test_root/timing1.valid"
cp "$TIMING_2" "$test_root/timing2.valid"

restore_valid() {
  rm -f "$COMBINED" "$TIMING_1" "$TIMING_2"
  cp "$test_root/combined.valid" "$COMBINED"
  cp "$test_root/timing1.valid" "$TIMING_1"
  cp "$test_root/timing2.valid" "$TIMING_2"
}

expect_fail() {
  local label="$1" output rc
  set +e
  output="$(cd "$ROOT" && bash "$VERIFIER" 2>&1)"
  rc=$?
  set -e
  ((rc != 0)) || fail "$label mutation passed"
  [[ "$output" != *"verify-library-partitions: PASS"* ]] || fail "$label emitted PASS"
  restore_valid
}

baseline="$(cd "$ROOT" && bash "$VERIFIER")"
[[ "$baseline" == "verify-library-partitions: PASS" ]] || fail "valid receipt did not pass"

printf '{' >"$COMBINED"
expect_fail malformed

jq '.extra = true' "$test_root/combined.valid" >"$COMBINED"
expect_fail extra-key

sed 's/"schema_version"/"schema_version":"duplicate","schema_version"/' "$test_root/combined.valid" >"$COMBINED"
expect_fail duplicate-key

jq '.partitions[0].conclusion = "failure" | .partitions[0].exit_status = 23' "$test_root/combined.valid" >"$COMBINED"
expect_fail failed-child

jq '.ordinary_universe.paths |= .[1:] | .ordinary_universe.count -= 1' "$test_root/combined.valid" >"$COMBINED"
expect_fail universe-drift

jq '.partitions[0].manifest_sha256 = "0000"' "$test_root/combined.valid" >"$COMBINED"
expect_fail digest

jq '.partitions[0].end_ms += 1' "$test_root/combined.valid" >"$COMBINED"
expect_fail arithmetic

jq '.partitions[1].start_ms = 500 | .partitions[1].end_ms = 801 | .partitions[1].duration_ms = 301' "$test_root/combined.valid" >"$COMBINED"
expect_fail ratio

jq '.partitions |= reverse' "$test_root/combined.valid" >"$COMBINED"
expect_fail partition-order

jq '.ordinary_universe.scaffold_leaks = ["test/upgrade_test.exs"]' "$test_root/combined.valid" >"$COMBINED"
expect_fail scaffold-leak

jq '.tests[0].file = "test/leak_test.exs"' "$test_root/timing1.valid" >"$TIMING_1"
expect_fail receipt-membership

jq '.tests |= reverse' "$test_root/timing1.valid" >"$TIMING_1"
expect_fail timing-order

jq '.tests[0].outcome = "failed" | .failed = 1 | .passed -= 1' "$test_root/timing1.valid" >"$TIMING_1"
expect_fail failed-test

rm -f "$TIMING_1"
ln -s "$test_root/timing1.valid" "$TIMING_1"
expect_fail symlink

head -c 10485761 /dev/zero | tr '\0' x >"$TIMING_1"
expect_fail oversized

printf 'verify-library-partitions.test: PASS\n'
