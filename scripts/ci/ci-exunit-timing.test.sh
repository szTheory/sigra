#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OUTPUT_PATH=""
if [[ "${1:-}" == "--output" && -n "${2:-}" ]]; then
  OUTPUT_PATH=$2
  shift 2
fi

if [[ $# -ne 0 ]]; then
  echo "usage: bash scripts/ci/ci-exunit-timing.test.sh [--output PATH]" >&2
  exit 2
fi

for tool in mix node jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ci-exunit-timing.test: required tool is missing: $tool" >&2
    exit 2
  fi
done

TMP_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export MIX_ENV=test
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"

if command -v pg_isready >/dev/null 2>&1 && ! pg_isready -h "$PGHOST" -p "${PGPORT:-5432}" -U "$PGUSER" >/dev/null 2>&1; then
  echo "ci-exunit-timing.test: PostgreSQL is not accepting connections at $PGHOST:${PGPORT:-5432}" >&2
  exit 2
fi

FOCUS_TEST="test/sigra/planning/ci_timing_formatter_test.exs"
TIMED_MIX_JS='const { spawnSync } = require("node:child_process");
const started = process.hrtime.bigint();
const result = spawnSync("mix", ["test", "test/sigra/planning/ci_timing_formatter_test.exs"], { encoding: "utf8" });
const elapsedUs = Number((process.hrtime.bigint() - started) / 1000n);
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.error) process.stderr.write(`ci-exunit-timing.test: ${result.error.message}\n`);
process.stderr.write(`SIGRA_TIMING_ELAPSED_US=${elapsedUs}\n`);
process.exit(result.status === null ? 1 : result.status);'

PROBE_CODE='unless Code.ensure_loaded?(Sigra.Test.CITimingFormatter) do
  Code.require_file("test/support/ci_timing_formatter.ex")
end

formatters =
  if System.get_env("SIGRA_EXUNIT_TIMING_JSON") in [nil, ""] do
    [ExUnit.CLIFormatter]
  else
    [ExUnit.CLIFormatter, Sigra.Test.CITimingFormatter]
  end

ExUnit.start(formatters: formatters)

defmodule Sigra.CITimingProcessProbe do
  use ExUnit.Case

  test "probe keeps the original ExUnit result" do
    if System.get_env("SIGRA_EXUNIT_TIMING_FAIL") == "1" do
      assert 2 == 1
    else
      assert 1 == 1
    end
  end
end'

run_probe() {
  local log_path=$1
  shift
  local status

  if "$@" >"$log_path" 2>&1; then
    status=0
  else
    status=$?
  fi

  printf '%s\n' "$status"
}

has_write_diagnostic() {
  local log_path=$1
  local diagnostic

  diagnostic="$(sed -n 's/^SIGRA_EXUNIT_TIMING_JSON: //p' "$log_path" | tail -n 1)"
  [[ -n "$diagnostic" ]] && printf '%s\n' "$diagnostic" | jq -e '.complete == false and .diagnostic == "write_failed" and (.reason | type == "string")' >/dev/null
}

run_focus_sample() {
  local mode=$1
  local sample=$2
  local log_path=$3
  local output_path=$4
  local status elapsed_us
  local -a command

  if [[ "$mode" == "with" ]]; then
    command=(env "SIGRA_EXUNIT_TIMING_JSON=$output_path" SIGRA_EXUNIT_TIMING_INVOCATION=instrumentation_test node -e "$TIMED_MIX_JS")
  else
    command=(env -u SIGRA_EXUNIT_TIMING_JSON node -e "$TIMED_MIX_JS")
  fi

  if "${command[@]}" >"$log_path" 2>&1; then
    status=0
  else
    status=$?
  fi

  if [[ "$status" -ne 0 ]]; then
    cat "$log_path" >&2
    echo "ci-exunit-timing.test: focused suite failed in $mode sample $sample (exit $status)" >&2
    return 1
  fi

  elapsed_us="$(sed -n 's/^SIGRA_TIMING_ELAPSED_US=//p' "$log_path" | tail -n 1)"
  if [[ ! "$elapsed_us" =~ ^[0-9]+$ ]]; then
    cat "$log_path" >&2
    echo "ci-exunit-timing.test: missing elapsed microseconds for $mode sample $sample" >&2
    return 1
  fi

  if [[ "$mode" == "with" ]]; then
    if [[ ! -s "$output_path" ]] || ! jq -e '.complete == true and .unit == "microsecond" and .invocation == "instrumentation_test" and (.tests | length == 3) and all(.tests[]; .invocation == "instrumentation_test")' "$output_path" >/dev/null; then
      cat "$log_path" >&2
      echo "ci-exunit-timing.test: instrumented sample $sample did not produce a complete three-test report" >&2
      return 1
    fi
  else
    if [[ -e "$output_path" ]] || rg -q 'SIGRA_EXUNIT_TIMING_JSON:' "$log_path"; then
      cat "$log_path" >&2
      echo "ci-exunit-timing.test: uninstrumented sample $sample produced timing output" >&2
      return 1
    fi
  fi

  if ! rg -q '3 tests, 0 failures' "$log_path"; then
    cat "$log_path" >&2
    echo "ci-exunit-timing.test: focused suite $mode sample $sample did not preserve normal ExUnit output" >&2
    return 1
  fi

  printf '%s\n' "$elapsed_us"
}

PASS_PATH="$TMP_ROOT/pass.json"
PASS_LOG="$TMP_ROOT/pass.log"
printf '%s\n' '{"complete":true,"unit":"microsecond","tests":[]}' > "$PASS_PATH"
PASS_STATUS="$(run_probe "$PASS_LOG" env \
  "SIGRA_EXUNIT_TIMING_JSON=$PASS_PATH" \
  "MIX_ENV=$MIX_ENV" "PGUSER=$PGUSER" "PGPASSWORD=$PGPASSWORD" "PGHOST=$PGHOST" \
  mix run --no-start -e "$PROBE_CODE")"

if [[ "$PASS_STATUS" -ne 0 ]] || ! jq -e '.complete == true and .passed_count == 1 and .failed_count == 0 and (.tests | length == 1) and .tests[0].test_id == "Sigra.CITimingProcessProbe.test probe keeps the original ExUnit result" and .tests[0].result == "passed" and (.tests[0].duration_us >= 0)' "$PASS_PATH" >/dev/null; then
  cat "$PASS_LOG" >&2
  echo "ci-exunit-timing.test: passing ExUnit process did not produce one complete timing row" >&2
  exit 1
fi

rg -q 'Running ExUnit with seed:' "$PASS_LOG"
rg -q '1 test, 0 failures' "$PASS_LOG"

NO_OPT_IN_PATH="$TMP_ROOT/no-opt-in.json"
NO_OPT_IN_LOG="$TMP_ROOT/no-opt-in.log"
NO_OPT_IN_STATUS="$(run_probe "$NO_OPT_IN_LOG" env -u SIGRA_EXUNIT_TIMING_JSON \
  "MIX_ENV=$MIX_ENV" "PGUSER=$PGUSER" "PGPASSWORD=$PGPASSWORD" "PGHOST=$PGHOST" \
  mix run --no-start -e "$PROBE_CODE")"

if [[ "$NO_OPT_IN_STATUS" -ne 0 || -e "$NO_OPT_IN_PATH" ]] || rg -q 'SIGRA_EXUNIT_TIMING_JSON:' "$NO_OPT_IN_LOG"; then
  cat "$NO_OPT_IN_LOG" >&2
  echo "ci-exunit-timing.test: opt-out ExUnit process changed result or emitted timing output" >&2
  exit 1
fi

if ! rg -q 'Running ExUnit with seed:' "$NO_OPT_IN_LOG" || ! rg -q '1 test, 0 failures' "$NO_OPT_IN_LOG"; then
  cat "$NO_OPT_IN_LOG" >&2
  echo "ci-exunit-timing.test: opt-out process did not retain normal ExUnit CLI output" >&2
  exit 1
fi

NOT_A_DIRECTORY="$TMP_ROOT/not-a-directory"
: > "$NOT_A_DIRECTORY"
UNAVAILABLE_PATH="$NOT_A_DIRECTORY/timing.json"

PASS_UNAVAILABLE_LOG="$TMP_ROOT/pass-unavailable.log"
PASS_UNAVAILABLE_STATUS="$(run_probe "$PASS_UNAVAILABLE_LOG" env \
  "SIGRA_EXUNIT_TIMING_JSON=$UNAVAILABLE_PATH" \
  "MIX_ENV=$MIX_ENV" "PGUSER=$PGUSER" "PGPASSWORD=$PGPASSWORD" "PGHOST=$PGHOST" \
  mix run --no-start -e "$PROBE_CODE")"

if [[ "$PASS_UNAVAILABLE_STATUS" -ne 0 ]] || [[ -e "$UNAVAILABLE_PATH" ]] || ! has_write_diagnostic "$PASS_UNAVAILABLE_LOG"; then
  cat "$PASS_UNAVAILABLE_LOG" >&2
  echo "ci-exunit-timing.test: passing tests with unavailable output were not diagnosed" >&2
  exit 1
fi

FAILURE_VALID_PATH="$TMP_ROOT/failure.json"
FAILURE_VALID_LOG="$TMP_ROOT/failure.log"
FAILURE_VALID_STATUS="$(run_probe "$FAILURE_VALID_LOG" env \
  "SIGRA_EXUNIT_TIMING_JSON=$FAILURE_VALID_PATH" \
  SIGRA_EXUNIT_TIMING_FAIL=1 \
  "MIX_ENV=$MIX_ENV" "PGUSER=$PGUSER" "PGPASSWORD=$PGPASSWORD" "PGHOST=$PGHOST" \
  mix run --no-start -e "$PROBE_CODE")"

if [[ "$FAILURE_VALID_STATUS" -eq 0 ]] || ! jq -e '.complete == true and .failed_count == 1 and .tests[0].result == "failed"' "$FAILURE_VALID_PATH" >/dev/null; then
  cat "$FAILURE_VALID_LOG" >&2
  echo "ci-exunit-timing.test: deliberate failure did not retain its original nonzero result" >&2
  exit 1
fi

FAILURE_LOG="$TMP_ROOT/failure-unavailable.log"
FAILURE_STATUS="$(run_probe "$FAILURE_LOG" env \
  "SIGRA_EXUNIT_TIMING_JSON=$UNAVAILABLE_PATH" \
  SIGRA_EXUNIT_TIMING_FAIL=1 \
  "MIX_ENV=$MIX_ENV" "PGUSER=$PGUSER" "PGPASSWORD=$PGPASSWORD" "PGHOST=$PGHOST" \
  mix run --no-start -e "$PROBE_CODE")"

if [[ "$FAILURE_STATUS" -eq 0 || "$FAILURE_STATUS" -ne "$FAILURE_VALID_STATUS" ]] || [[ -e "$UNAVAILABLE_PATH" ]] || ! has_write_diagnostic "$FAILURE_LOG"; then
  cat "$FAILURE_LOG" >&2
  echo "ci-exunit-timing.test: failing tests with unavailable output lost their failure or diagnostic" >&2
  exit 1
fi

if jq -e '(.complete == true) and any(.tests[]?; .duration_us == 0 and .result == "passed")' "$UNAVAILABLE_PATH" >/dev/null 2>&1; then
  echo "ci-exunit-timing.test: unavailable output created a zero-duration success report" >&2
  exit 1
fi

WITHOUT_US=()
WITH_US=()
PAIRED_DELTA_US=()

for sample in 1 2 3 4 5; do
  without_path="$TMP_ROOT/no-timing-$sample.json"
  without_log="$TMP_ROOT/no-timing-$sample.log"
  without_value="$(run_focus_sample without "$sample" "$without_log" "$without_path")"
  WITHOUT_US+=("$without_value")

  with_path="$TMP_ROOT/timing-$sample.json"
  with_log="$TMP_ROOT/timing-$sample.log"
  with_value="$(run_focus_sample with "$sample" "$with_log" "$with_path")"
  WITH_US+=("$with_value")

  PAIRED_DELTA_US+=("$((with_value - without_value))")
done

median_of_five() {
  printf '%s\n' "$@" | sort -n | sed -n '3p'
}

INSTRUMENTATION_OVERHEAD_US="$(median_of_five "${PAIRED_DELTA_US[@]}")"
WITHOUT_JSON="$(printf '%s\n' "${WITHOUT_US[@]}" | jq -R 'tonumber' | jq -s '.')"
WITH_JSON="$(printf '%s\n' "${WITH_US[@]}" | jq -R 'tonumber' | jq -s '.')"
DELTA_JSON="$(printf '%s\n' "${PAIRED_DELTA_US[@]}" | jq -R 'tonumber' | jq -s '.')"
OBSERVED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ELIXIR_RUNTIME="$(elixir --version | tr '\n' ' ')"
MIX_RUNTIME="$(mix --version | tail -n 1)"

REPORT="$(jq -n \
  --arg observed_at "$OBSERVED_AT" \
  --arg elixir_runtime "$ELIXIR_RUNTIME" \
  --arg mix_runtime "$MIX_RUNTIME" \
  --argjson without_us "$WITHOUT_JSON" \
  --argjson with_us "$WITH_JSON" \
  --argjson paired_delta_us "$DELTA_JSON" \
  --argjson instrumentation_overhead_us "$INSTRUMENTATION_OVERHEAD_US" \
  --argjson pass_process_exit "$PASS_STATUS" \
  --argjson no_opt_in_process_exit "$NO_OPT_IN_STATUS" \
  --argjson pass_unavailable_output_exit "$PASS_UNAVAILABLE_STATUS" \
  --argjson fail_with_output_exit "$FAILURE_VALID_STATUS" \
  --argjson fail_unavailable_output_exit "$FAILURE_STATUS" \
  '{
    contract: "sigra.exunit_timing.v1",
    observed_at_utc: $observed_at,
    runtime: {elixir: $elixir_runtime, mix: $mix_runtime},
    focused_suite: "MIX_ENV=test mix test test/sigra/planning/ci_timing_formatter_test.exs",
    samples: {without_timing_us: $without_us, with_timing_us: $with_us, paired_delta_us: $paired_delta_us},
    instrumentation_overhead_us: $instrumentation_overhead_us,
    overhead_method: "median of five paired whole-mix-process elapsed-time differences (instrumented minus uninstrumented)",
    process_contract: {
      passing_process_exit: $pass_process_exit,
      opt_out_process_exit: $no_opt_in_process_exit,
      passing_process_with_unavailable_output_exit: $pass_unavailable_output_exit,
      failing_process_with_output_exit: $fail_with_output_exit,
      failing_process_with_unavailable_output_exit: $fail_unavailable_output_exit,
      unavailable_output_diagnostic: "SIGRA_EXUNIT_TIMING_JSON JSON object with complete=false and diagnostic=write_failed",
      unavailable_output_is_measurement: false
    },
    complete: true
  }')"

if [[ -n "$OUTPUT_PATH" ]]; then
  OUTPUT_TMP="$OUTPUT_PATH.tmp.$$"
  printf '%s\n' "$REPORT" > "$OUTPUT_TMP"
  mv "$OUTPUT_TMP" "$OUTPUT_PATH"
else
  printf '%s\n' "$REPORT"
fi
