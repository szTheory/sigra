#!/usr/bin/env bash
# Hermetic tests for legacy and current Release Please start timestamps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/normalize-release-timestamp.sh"

[[ "$(bash "$SCRIPT" '2026-10-09T02:34:52Z')" == '2026-10-09T02:34:52Z' ]]
[[ "$(bash "$SCRIPT" '"2026-10-09T02:34:52Z"')" == '2026-10-09T02:34:52Z' ]]

for invalid in '' '2026-10-09T02:34:52' '"2026-10-09T02:34:52Z' 'yesterday'; do
  if bash "$SCRIPT" "$invalid" >/dev/null 2>&1; then
    echo "normalize-release-timestamp.test: accepted invalid timestamp" >&2
    exit 1
  fi
done

echo "normalize-release-timestamp.test: PASS"
