#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/ci/library-partitions.sh"
FORMATTER_TEST="$ROOT/test/support/ci/ex_unit_timing_formatter_test.exs"

fail() { printf 'library-partitions.test: FAIL: %s\n' "$*" >&2; exit 1; }
digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

[[ -x "$RUNNER" ]] || fail "runner must exist and be executable"
grep -Fq '/tmp/sigra-library-partitions.json' "$RUNNER" || fail "combined path is not fixed"
grep -Fq '/tmp/sigra-library-1-timings.json' "$RUNNER" || fail "partition 1 timing path is not fixed"
grep -Fq '/tmp/sigra-library-2-timings.json' "$RUNNER" || fail "partition 2 timing path is not fixed"
grep -Fq 'Sigra.CI.ExUnitTimingFormatter' "$RUNNER" || fail "timing formatter is absent"
grep -Fq 'ExUnit.CLIFormatter' "$RUNNER" || fail "CLI formatter is absent"
grep -Eq 'run_partition[[:space:]]+1.*run_partition[[:space:]]+2' <(tr '\n' ' ' <"$RUNNER") ||
  fail "partitions are not sequential"

verify_formatter_test_receipt_ownership() {
  local source="$1"

  grep -Fq 'path = "/tmp/sigra-library-scaffold-timings.json"' "$source" ||
    fail "formatter write contract does not own the scaffold receipt path"
}

verify_formatter_test_receipt_ownership "$FORMATTER_TEST"

for forbidden in --slowest --trace 'eval ' 'mix test --exclude scaffold'; do
  if grep -Fq -- "$forbidden" "$RUNNER"; then
    fail "runner contains forbidden command surface: $forbidden"
  fi
done

test_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-library-partitions-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

mutated_formatter_test="$test_root/formatter-test-mutated.exs"
sed 's|path = "/tmp/sigra-library-scaffold-timings.json"|path = "/tmp/sigra-library-1-timings.json"|' \
  "$FORMATTER_TEST" >"$mutated_formatter_test"

if (verify_formatter_test_receipt_ownership "$mutated_formatter_test") 2>/dev/null; then
  fail "ordinary-path formatter mutation was accepted"
fi

# These single-quoted lines intentionally write a child script without expanding
# its environment in this parent process.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${1:-}" == "run" ]]; then' \
  '  printf "1\\ttest/a_test.exs\\n2\\ttest/b_test.exs\\n"' \
  '  exit 0' \
  'fi' \
  'if [[ "${1:-}" == "test" ]]; then' \
  '  partition="${MIX_TEST_PARTITION:?}"' \
  '  if [[ "${FAKE_FAIL_PARTITION:-}" == "$partition" ]]; then exit 23; fi' \
  '  jq -n --arg partition "$partition" '\''{schema_version:1,partition:$partition,tests:[{file:(if $partition == "1" then "test/a_test.exs" else "test/b_test.exs" end),module:"FakeTest",name:"test fake",time_us:1,outcome:"passed"}],total:1,passed:1,failed:0,skipped:0,excluded:0,invalid:0}'\'' >"${SIGRA_EXUNIT_TIMING_PATH:?}"' \
  '  if [[ "$partition" == "1" ]]; then cp "${SIGRA_EXUNIT_TIMING_PATH:?}" "${FAKE_PARTITION_1_COPY:?}"; fi' \
  '  exit 0' \
  'fi' \
  'exit 99' >"$test_root/bin/mix"
chmod +x "$test_root/bin/mix"

partition_1_copy="$test_root/partition-1-before-partition-2.json"
PATH="$test_root/bin:$PATH" FAKE_PARTITION_1_COPY="$partition_1_copy" bash "$RUNNER"
partition_1_sha_before="$(digest "$partition_1_copy")"
jq -e '
  .schema_version == "sigra.library-partitions/v1" and
  .execution_mode == "sequential" and
  .ordinary_universe.paths == ["test/a_test.exs", "test/b_test.exs"] and
  [.partitions[].conclusion] == ["success", "success"] and
  [.partitions[].exit_status] == [0, 0] and
  all(.partitions[]; .duration_ms == (.end_ms - .start_ms) and .duration_ms > 0)
' /tmp/sigra-library-partitions.json >/dev/null || fail "success receipt is invalid"
partition_1_sha_after="$(digest /tmp/sigra-library-1-timings.json)"
[[ "$partition_1_sha_after" == "$partition_1_sha_before" ]] ||
  fail "partition 2 changed partition 1 timing receipt"

set +e
PATH="$test_root/bin:$PATH" FAKE_FAIL_PARTITION=1 bash "$RUNNER"
failure_status=$?
set -e
[[ "$failure_status" == 23 ]] || fail "first child status was not propagated"
jq -e '
  .partitions[0].conclusion == "failure" and
  .partitions[0].exit_status == 23 and
  .partitions[1].conclusion == "not_run" and
  .partitions[1].exit_status == 0
' /tmp/sigra-library-partitions.json >/dev/null || fail "failure receipt concealed child status"

printf 'library-partitions.test: PASS\n'
