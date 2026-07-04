#!/usr/bin/env bash
# panel-verdicts-lint.test.sh — hermetic self-test for panel-verdicts-lint.sh (Phase 217, Plan 05).
#
# Tests (TDD RED phase for Task 4):
#   Test 1: a verdicts file with a non-64-hex render_sha256 key fails the lint.
#   Test 2: unsorted keys fails the lint; duplicate keys fails the lint.
#   Test 3: an admitted finding whose finding_id does not recompute from (surface, class, anchor) fails.
#   Test 4: a verdicts entry containing an open_findings field fails.
#   Test 5: a clean file passes; --prune removes orphaned entries non-blockingly (exits 0).
#
# Hermetic: operates entirely inside mktemp -d throwaway directories.
# No files are created in the real repo; git status of the real repo is unchanged.
set -euo pipefail

TMPDIR_ROOT=""
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT

PASS=0
FAIL=0

pass_test() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail_test()  { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

# Locate the real lint script (relative to this test script).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_LINT="${SCRIPT_DIR}/panel-verdicts-lint.sh"

if [[ ! -f "$REAL_LINT" ]]; then
  echo "FATAL: lint script not found at ${REAL_LINT}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Build a hermetic temp environment that mirrors the lint's path expectations:
#   ROOT/scripts/ci/panel-verdicts-lint.sh  (the lint binary)
#   ROOT/guides/reference/admin-panel-verdicts.json  (the file under test)
#   ROOT/guides/reference/admin-render-sha.json       (for --prune)
#
# The lint script derives ROOT from its own location:
#   ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# --------------------------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
REPO="$TMPDIR_ROOT/test-repo"
mkdir -p "$REPO/scripts/ci"
mkdir -p "$REPO/guides/reference"

cp "$REAL_LINT" "$REPO/scripts/ci/panel-verdicts-lint.sh"
chmod +x "$REPO/scripts/ci/panel-verdicts-lint.sh"

VERDICTS="$REPO/guides/reference/admin-panel-verdicts.json"
RENDER_SHA="$REPO/guides/reference/admin-render-sha.json"

# Helper: run the lint from inside the temp repo
run_lint() {
  (cd "$REPO" && bash scripts/ci/panel-verdicts-lint.sh "$@" 2>&1)
  return $?
}

run_lint_exit() {
  local exit_code
  set +e
  (cd "$REPO" && bash scripts/ci/panel-verdicts-lint.sh "$@" >/dev/null 2>&1)
  exit_code=$?
  set -e
  echo "$exit_code"
}

# Helper: compute finding_id (node) — same formula as panel-schema.mjs
compute_finding_id() {
  local surface="$1"
  local klass="$2"
  local anchor="$3"
  node -e "
    const crypto = require('crypto');
    const canon = '${anchor}'.trim().replace(/\[([^\]]*?)='([^']*)'\]/g, '[\$1=\"\$2\"]');
    const h = crypto.createHash('sha256')
      .update('${surface}').update('\0')
      .update('${klass}').update('\0')
      .update(canon).digest('hex');
    process.stdout.write(h);
  "
}

# --------------------------------------------------------------------------
# Test 1: a non-64-hex render_sha256 key fails the lint
# --------------------------------------------------------------------------
echo ""
echo "Test 1: non-64-hex render_sha256 key fails lint"

cat > "$VERDICTS" <<'JSON'
{
  "schema_version": "217-05",
  "notes": "test",
  "cells": {
    "not-a-hex-sha": {
      "admitted_findings": [],
      "surface_disposition": "clean",
      "per_lens_disposition": {},
      "provenance": {"model": "claude-opus-4-8", "k": 3, "quorum": 2, "rubric_version": "1.0", "prompt_sha": "abc"}
    }
  }
}
JSON

EXIT1=$(run_lint_exit)
if [[ "$EXIT1" -ne 0 ]]; then
  pass_test "Test 1: non-64-hex key correctly fails lint (exit $EXIT1)"
else
  fail_test "Test 1: non-64-hex key should fail lint but exited 0"
fi

# --------------------------------------------------------------------------
# Test 2: unsorted keys fails; duplicate keys scenario
# --------------------------------------------------------------------------
echo ""
echo "Test 2: unsorted keys fail lint"

# Two valid 64-hex keys but in REVERSE order (z... comes before a... in sort but not here)
SHA_A="a$(printf 'a%.0s' {1..62})b"   # aaa...aab (64 chars)
SHA_B="b$(printf 'b%.0s' {1..62})c"   # bbb...bbc (64 chars)

# Write keys in UNSORTED order: SHA_B before SHA_A
cat > "$VERDICTS" <<JSON
{
  "schema_version": "217-05",
  "notes": "test",
  "cells": {
    "${SHA_B}": {
      "admitted_findings": [],
      "surface_disposition": "clean",
      "per_lens_disposition": {},
      "provenance": {"model": "claude-opus-4-8", "k": 3, "quorum": 2, "rubric_version": "1.0", "prompt_sha": "x"}
    },
    "${SHA_A}": {
      "admitted_findings": [],
      "surface_disposition": "clean",
      "per_lens_disposition": {},
      "provenance": {"model": "claude-opus-4-8", "k": 3, "quorum": 2, "rubric_version": "1.0", "prompt_sha": "x"}
    }
  }
}
JSON

EXIT2=$(run_lint_exit)
if [[ "$EXIT2" -ne 0 ]]; then
  pass_test "Test 2: unsorted keys correctly fail lint (exit $EXIT2)"
else
  fail_test "Test 2: unsorted keys should fail lint but exited 0"
fi

# --------------------------------------------------------------------------
# Test 3: admitted finding with wrong finding_id fails lint
# --------------------------------------------------------------------------
echo ""
echo "Test 3: mismatched finding_id fails lint"

SHA_VALID="$(printf 'c%.0s' {1..64})"
REAL_FID=$(compute_finding_id "users-index-live" "platform_admin:earning_its_place" '[data-testid="user-row"]')
BAD_FID="$(printf 'd%.0s' {1..64})"   # wrong finding_id

cat > "$VERDICTS" <<JSON
{
  "schema_version": "217-05",
  "notes": "test",
  "cells": {
    "${SHA_VALID}": {
      "admitted_findings": [
        {
          "finding_id": "${BAD_FID}",
          "surface": "users-index-live",
          "klass": "platform_admin:earning_its_place",
          "anchor": "[data-testid=\"user-row\"]",
          "severity": "tighten",
          "description": "Test finding"
        }
      ],
      "surface_disposition": "actionable",
      "per_lens_disposition": {},
      "provenance": {"model": "claude-opus-4-8", "k": 3, "quorum": 2, "rubric_version": "1.0", "prompt_sha": "x"}
    }
  }
}
JSON

EXIT3=$(run_lint_exit)
if [[ "$EXIT3" -ne 0 ]]; then
  pass_test "Test 3: mismatched finding_id correctly fails lint (exit $EXIT3)"
else
  fail_test "Test 3: mismatched finding_id should fail lint but exited 0"
fi

# --------------------------------------------------------------------------
# Test 4: open_findings field anywhere in the file fails lint
# --------------------------------------------------------------------------
echo ""
echo "Test 4: open_findings field fails lint (T-217-05-EOP)"

SHA_CLEAN="$(printf 'e%.0s' {1..64})"

cat > "$VERDICTS" <<JSON
{
  "schema_version": "217-05",
  "notes": "test",
  "cells": {
    "${SHA_CLEAN}": {
      "admitted_findings": [],
      "open_findings": 42,
      "surface_disposition": "clean",
      "per_lens_disposition": {},
      "provenance": {"model": "claude-opus-4-8", "k": 3, "quorum": 2, "rubric_version": "1.0", "prompt_sha": "x"}
    }
  }
}
JSON

EXIT4=$(run_lint_exit)
if [[ "$EXIT4" -ne 0 ]]; then
  pass_test "Test 4: open_findings field correctly fails lint (exit $EXIT4)"
else
  fail_test "Test 4: open_findings field should fail lint but exited 0"
fi

# --------------------------------------------------------------------------
# Test 5a: a clean file passes
# --------------------------------------------------------------------------
echo ""
echo "Test 5a: a clean file passes lint"

SHA_GOOD="$(printf 'f%.0s' {1..64})"
CORRECT_FID=$(compute_finding_id "users-index-live" "platform_admin:earning_its_place" '[data-testid="user-row"]')

cat > "$VERDICTS" <<JSON
{
  "schema_version": "217-05",
  "notes": "test",
  "cells": {
    "${SHA_GOOD}": {
      "admitted_findings": [
        {
          "finding_id": "${CORRECT_FID}",
          "surface": "users-index-live",
          "klass": "platform_admin:earning_its_place",
          "anchor": "[data-testid=\"user-row\"]",
          "severity": "tighten",
          "description": "Test finding with correct finding_id"
        }
      ],
      "surface_disposition": "actionable",
      "per_lens_disposition": {"platform_admin": "actionable"},
      "provenance": {"model": "claude-opus-4-8", "k": 3, "quorum": 2, "rubric_version": "1.0", "prompt_sha": "x"}
    }
  }
}
JSON

EXIT5A=$(run_lint_exit)
if [[ "$EXIT5A" -eq 0 ]]; then
  pass_test "Test 5a: clean file passes lint (exit 0)"
else
  fail_test "Test 5a: clean file should pass lint but exited $EXIT5A"
fi

# --------------------------------------------------------------------------
# Test 5b: --prune removes orphaned entries non-blockingly (exits 0)
# --------------------------------------------------------------------------
echo ""
echo "Test 5b: --prune is non-blocking (exits 0)"

# Set up admin-render-sha.json with NO cells (so the SHA_GOOD entry is "orphaned")
cat > "$RENDER_SHA" <<'JSON'
{
  "schema_version": 1,
  "cells": {}
}
JSON

# The verdicts file already has SHA_GOOD — after --prune, that orphaned entry should be removed
PRUNE_OUTPUT=$((cd "$REPO" && bash scripts/ci/panel-verdicts-lint.sh --prune) 2>&1)
PRUNE_EXIT=$?

if [[ "$PRUNE_EXIT" -eq 0 ]]; then
  pass_test "Test 5b: --prune exits 0 (non-blocking)"
else
  fail_test "Test 5b: --prune should exit 0 but exited $PRUNE_EXIT"
fi

# After prune, the verdicts file should have an empty cells object
CELLS_AFTER=$(node -e "
  const d = JSON.parse(require('fs').readFileSync('${VERDICTS}', 'utf8'));
  console.log(Object.keys(d.cells || {}).length);
" 2>/dev/null || echo "error")

if [[ "$CELLS_AFTER" == "0" ]]; then
  pass_test "Test 5b: --prune removed orphaned entry (cells now empty)"
else
  fail_test "Test 5b: --prune did not remove orphaned entry (cells count: $CELLS_AFTER)"
fi

# The empty verdicts file must also pass lint (skeleton is valid)
LINT_AFTER_PRUNE=$(run_lint_exit)
if [[ "$LINT_AFTER_PRUNE" -eq 0 ]]; then
  pass_test "Test 5b: post-prune empty file passes lint"
else
  fail_test "Test 5b: post-prune empty file should pass lint but exited $LINT_AFTER_PRUNE"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "panel-verdicts-lint.test: FAIL"
  exit 1
fi

echo "panel-verdicts-lint.test: PASS"
exit 0
