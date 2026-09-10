#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/ci/library-partitions.sh"

fail() { printf 'library-partitions.test: FAIL: %s\n' "$*" >&2; exit 1; }

[[ -x "$RUNNER" ]] || fail "runner must exist and be executable"
grep -Fq '/tmp/sigra-library-partitions.json' "$RUNNER" || fail "combined path is not fixed"
grep -Fq '/tmp/sigra-library-1-timings.json' "$RUNNER" || fail "partition 1 timing path is not fixed"
grep -Fq '/tmp/sigra-library-2-timings.json' "$RUNNER" || fail "partition 2 timing path is not fixed"
grep -Fq 'Sigra.CI.ExUnitTimingFormatter' "$RUNNER" || fail "timing formatter is absent"
grep -Fq 'ExUnit.CLIFormatter' "$RUNNER" || fail "CLI formatter is absent"
grep -Eq 'run_partition[[:space:]]+1.*run_partition[[:space:]]+2' <(tr '\n' ' ' <"$RUNNER") ||
  fail "partitions are not sequential"

for forbidden in --slowest --trace 'eval ' 'mix test --exclude scaffold'; do
  if grep -Fq -- "$forbidden" "$RUNNER"; then
    fail "runner contains forbidden command surface: $forbidden"
  fi
done

printf 'library-partitions.test: PASS\n'
