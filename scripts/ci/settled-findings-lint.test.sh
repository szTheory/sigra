#!/usr/bin/env bash
# Self-test for settled-findings-lint.sh (D-22).
#
# Hermetic: operates entirely inside a mktemp -d throwaway directory.
# No files are created in the real repo; git status of the real repo is
# unchanged after this script runs.
#
# Test cases:
#   A: sorted empty file (header-only) PASSES
#   B: unsorted 2-row fixture FAILS
#   C: duplicate finding_id fixture FAILS
#   D: --add round-trip PASSES (add row, re-lint, assert sorted + valid)
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

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_GUARD="${SCRIPT_DIR}/settled-findings-lint.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

TMPDIR_ROOT="$(mktemp -d)"

# The guard reads the TSV from guides/reference/settled-findings.tsv relative
# to ROOT (2 dirs up from its own location). We replicate that layout in a
# standalone temp directory so the guard can resolve ROOT correctly.
mkdir -p "$TMPDIR_ROOT/scripts/ci"
mkdir -p "$TMPDIR_ROOT/guides/reference"

# Copy the real guard into the temp tree.
cp "$REAL_GUARD" "$TMPDIR_ROOT/scripts/ci/settled-findings-lint.sh"
chmod +x "$TMPDIR_ROOT/scripts/ci/settled-findings-lint.sh"

TSV="$TMPDIR_ROOT/guides/reference/settled-findings.tsv"

GUARD="$TMPDIR_ROOT/scripts/ci/settled-findings-lint.sh"

# Two valid finding_ids (sha256 hex, 64 chars) for fixtures.
# id_a < id_b lexicographically (to form a correctly sorted pair).
ID_A="0000000000000000000000000000000000000000000000000000000000000001"
ID_B="0000000000000000000000000000000000000000000000000000000000000002"
HEADER="# finding_id	surface	class	anchor	disposition	waived_by	note"

# ---- Test A: sorted empty file (header-only) PASSES -------------------
echo "Test A: sorted empty file (header-only) passes"

printf '%s\n' "$HEADER" > "$TSV"

STDERR_A="$TMPDIR_ROOT/stderr_a.txt"
set +e
bash "$GUARD" >"$TMPDIR_ROOT/stdout_a.txt" 2>"$STDERR_A"
GUARD_EXIT_A=$?
set -e

if [[ "$GUARD_EXIT_A" -eq 0 ]]; then
  pass "Test A: header-only file exits 0"
else
  fail "Test A: header-only file exited non-zero ($GUARD_EXIT_A); stderr: $(cat "$STDERR_A")"
fi

# ---- Test B: unsorted 2-row fixture FAILS -----------------------------
echo "Test B: unsorted 2-row fixture fails"

# Write rows with ID_B before ID_A — reversed order = unsorted.
{
  printf '%s\n' "$HEADER"
  printf '%s\tusers-index-live\toff-token-spacing\t.sg-btn\twaived\tjon\tnote-b\n' "$ID_B"
  printf '%s\tusers-index-live\toff-token-spacing\t.sg-chip\twaived\tjon\tnote-a\n' "$ID_A"
} > "$TSV"

STDERR_B="$TMPDIR_ROOT/stderr_b.txt"
set +e
bash "$GUARD" >"$TMPDIR_ROOT/stdout_b.txt" 2>"$STDERR_B"
GUARD_EXIT_B=$?
set -e

if [[ "$GUARD_EXIT_B" -ne 0 ]]; then
  pass "Test B: unsorted fixture exits non-zero ($GUARD_EXIT_B)"
else
  fail "Test B: unsorted fixture exited 0 (should have been non-zero)"
fi

if grep -q "not sorted" "$STDERR_B" 2>/dev/null; then
  pass "Test B: stderr contains 'not sorted'"
else
  fail "Test B: stderr does NOT contain 'not sorted'; actual: $(cat "$STDERR_B")"
fi

# ---- Test C: duplicate finding_id fixture FAILS -----------------------
echo "Test C: duplicate finding_id fixture fails"

# Write two rows both using ID_A (duplicate).
{
  printf '%s\n' "$HEADER"
  printf '%s\tusers-index-live\toff-token-spacing\t.sg-btn\twaived\tjon\tnote-1\n' "$ID_A"
  printf '%s\tusers-index-live\toff-token-spacing\t.sg-chip\twaived\tjon\tnote-2\n' "$ID_A"
} > "$TSV"

STDERR_C="$TMPDIR_ROOT/stderr_c.txt"
set +e
bash "$GUARD" >"$TMPDIR_ROOT/stdout_c.txt" 2>"$STDERR_C"
GUARD_EXIT_C=$?
set -e

if [[ "$GUARD_EXIT_C" -ne 0 ]]; then
  pass "Test C: duplicate finding_id exits non-zero ($GUARD_EXIT_C)"
else
  fail "Test C: duplicate finding_id exited 0 (should have been non-zero)"
fi

if grep -q "duplicate" "$STDERR_C" 2>/dev/null; then
  pass "Test C: stderr contains 'duplicate'"
else
  fail "Test C: stderr does NOT contain 'duplicate'; actual: $(cat "$STDERR_C")"
fi

# ---- Test D: --add round-trip PASSES ----------------------------------
echo "Test D: --add round-trip passes (add ID_B first, then ID_A, assert sorted + lint passes)"

# Reset to empty file.
printf '%s\n' "$HEADER" > "$TSV"

# --add ID_B first.
STDERR_D1="$TMPDIR_ROOT/stderr_d1.txt"
set +e
bash "$GUARD" \
  --add "$ID_B" \
  --surface "users-index-live" \
  --class "off-token-spacing" \
  --anchor ".sg-btn" \
  --disposition "waived" \
  --waived-by "jon" \
  --note "test note B" \
  2>"$STDERR_D1"
EXIT_D1=$?
set -e

if [[ "$EXIT_D1" -eq 0 ]]; then
  pass "Test D: --add ID_B exited 0"
else
  fail "Test D: --add ID_B exited non-zero ($EXIT_D1); stderr: $(cat "$STDERR_D1")"
fi

# --add ID_A second (which sorts before ID_B — tests that re-sort happens correctly).
STDERR_D2="$TMPDIR_ROOT/stderr_d2.txt"
set +e
bash "$GUARD" \
  --add "$ID_A" \
  --surface "user-show-live" \
  --class "focus-ring" \
  --anchor ".sg-link" \
  --disposition "resolved" \
  --waived-by "" \
  --note "test note A" \
  2>"$STDERR_D2"
EXIT_D2=$?
set -e

if [[ "$EXIT_D2" -eq 0 ]]; then
  pass "Test D: --add ID_A exited 0"
else
  fail "Test D: --add ID_A exited non-zero ($EXIT_D2); stderr: $(cat "$STDERR_D2")"
fi

# Verify the file now has ID_A before ID_B (sorted).
FIRST_ID=$(grep -v '^#' "$TSV" | head -1 | cut -f1)
if [[ "$FIRST_ID" == "$ID_A" ]]; then
  pass "Test D: after --add both rows, first row is ID_A (correctly sorted)"
else
  fail "Test D: first row is '$FIRST_ID', expected ID_A ($ID_A) — sort did not work"
fi

# Now lint the file — it should pass.
STDERR_D3="$TMPDIR_ROOT/stderr_d3.txt"
set +e
bash "$GUARD" >"$TMPDIR_ROOT/stdout_d3.txt" 2>"$STDERR_D3"
EXIT_D3=$?
set -e

if [[ "$EXIT_D3" -eq 0 ]]; then
  pass "Test D: lint of --add result exits 0 (round-trip valid)"
else
  fail "Test D: lint of --add result exited non-zero ($EXIT_D3); stderr: $(cat "$STDERR_D3")"
fi

# ---- Summary -----------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "settled-findings-lint.test: FAIL"
  exit 1
fi

echo "settled-findings-lint.test: PASS"
exit 0
