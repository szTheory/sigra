#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT/scripts/ci/hex-remediation-verify.sh"
INCOMPLETE="$ROOT/test/fixtures/prohibitions/p22-hex-evidence-incomplete.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

output="$(bash "$VERIFY" validate "$INCOMPLETE" "$TMP_DIR/receipt.json" 2>&1)" && status=0 || status=$?
if [[ "$status" -eq 0 ]]; then
  fail "incomplete evidence must never validate"
fi

[[ "$output" == *"missing required evidence slot"* ]] ||
  fail "incomplete evidence should fail with a required-slot diagnostic, got: $output"

echo "PASS: incomplete evidence is rejected with an attributable required-slot diagnostic"
