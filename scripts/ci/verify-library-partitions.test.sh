#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$ROOT/scripts/ci/verify-library-partitions.sh"
COMBINED="/tmp/sigra-library-partitions.json"
TIMING_1="/tmp/sigra-library-1-timings.json"
TIMING_2="/tmp/sigra-library-2-timings.json"

fail() { printf 'verify-library-partitions.test: FAIL: %s\n' "$*" >&2; exit 1; }
[[ -x "$VERIFIER" ]] || fail "verifier must exist and be executable"

printf 'verify-library-partitions.test: PASS\n'
