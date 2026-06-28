#!/usr/bin/env bash
# Self-test for admin-css-conformance.sh: proves the guard exits non-zero on
# forbidden patterns and exits 0 on a clean file.
#
# Hermetic: uses mktemp CSS files, no real-repo side effects.
# No files are created or modified in the real repo; git status of the real
# repo is unchanged after this script runs.
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

# Locate the real guard script (relative to this test script).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_GUARD="${SCRIPT_DIR}/admin-css-conformance.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Create hermetic temp directory for CSS fixtures.
# The guard accepts a file path argument, so no throwaway git repo is needed.
# --------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d)"

# --------------------------------------------------------------------------
# CSS Fixtures
# --------------------------------------------------------------------------

# CLEAN_CSS: valid CSS with :root tokens using hex, and a rule using var().
# No transition: all. No hex outside :root.
CLEAN_CSS="${TMPDIR_ROOT}/clean.css"
cat > "$CLEAN_CSS" <<'CSS'
:root {
  --sg-color-x: #abc;
  --sg-color-y: #ffffff;
  --sg-color-z: #c2410c;
}

.foo {
  color: var(--sg-color-x);
  background: var(--sg-color-y);
  transition: color 0.2s ease;
}

.bar {
  color: var(--sg-color-z);
}
CSS

# TRANSITION_ALL_CSS: same as clean but adds a transition: all outside :root.
TRANSITION_ALL_CSS="${TMPDIR_ROOT}/transition-all.css"
cat > "$TRANSITION_ALL_CSS" <<'CSS'
:root {
  --sg-color-x: #abc;
}

.foo {
  color: var(--sg-color-x);
  transition: all 0.2s ease;
}
CSS

# RAW_HEX_CSS: same as clean but adds a raw hex color outside :root.
# Mirrors the real gap at sigra_admin.css line 506 (.sg-btn--danger.is-armed color: #fff).
RAW_HEX_CSS="${TMPDIR_ROOT}/raw-hex.css"
cat > "$RAW_HEX_CSS" <<'CSS'
:root {
  --sg-color-x: #abc;
}

.foo {
  color: #fff;
}
CSS

# DARK_ROOT_CSS: CSS with two :root blocks (light + @media dark), both with
# hex-only token definitions. Outside both :root blocks, only var() is used.
# Guard must exit 0 (all hex is inside :root protection).
DARK_ROOT_CSS="${TMPDIR_ROOT}/dark-root.css"
cat > "$DARK_ROOT_CSS" <<'CSS'
:root {
  --sg-color-ink: #151515;
  --sg-color-brand: #c2410c;
}

@media (prefers-color-scheme: dark) {
  :root {
    --sg-color-ink: #f4f1eb;
    --sg-color-brand: #fdba74;
  }
}

.sg-text {
  color: var(--sg-color-ink);
}

.sg-brand {
  color: var(--sg-color-brand);
}
CSS

# --------------------------------------------------------------------------
# Test A: Clean CSS exits 0
# --------------------------------------------------------------------------
echo "Test A: clean CSS exits 0"

STDERR_A="${TMPDIR_ROOT}/stderr_a.txt"
set +e
bash "$REAL_GUARD" "$CLEAN_CSS" >"${TMPDIR_ROOT}/stdout_a.txt" 2>"$STDERR_A"
EXIT_A=$?
set -e

if [[ "$EXIT_A" -eq 0 ]]; then
  pass "Guard exits 0 on clean CSS"
else
  fail "Guard exited non-zero ($EXIT_A) on clean CSS; stderr: $(cat "$STDERR_A")"
fi

if grep -q "PASS" "${TMPDIR_ROOT}/stdout_a.txt" 2>/dev/null; then
  pass "Guard emits PASS on clean CSS"
else
  fail "Guard did not emit PASS on clean CSS; stdout: $(cat "${TMPDIR_ROOT}/stdout_a.txt")"
fi

# --------------------------------------------------------------------------
# Test B: transition:all injection exits non-zero + stderr mentions the violation
# --------------------------------------------------------------------------
echo "Test B: transition:all injection exits non-zero"

STDERR_B="${TMPDIR_ROOT}/stderr_b.txt"
set +e
bash "$REAL_GUARD" "$TRANSITION_ALL_CSS" >"${TMPDIR_ROOT}/stdout_b.txt" 2>"$STDERR_B"
EXIT_B=$?
set -e

if [[ "$EXIT_B" -ne 0 ]]; then
  pass "Guard exits non-zero ($EXIT_B) on transition:all injection"
else
  fail "Guard exited 0 (should have been non-zero) on transition:all injection"
fi

if grep -q "transition: all" "$STDERR_B" 2>/dev/null; then
  pass "Guard stderr contains 'transition: all' on transition:all injection"
else
  fail "Guard stderr does not contain 'transition: all'; actual stderr: $(cat "$STDERR_B")"
fi

# --------------------------------------------------------------------------
# Test C: raw hex outside :root exits non-zero
# --------------------------------------------------------------------------
echo "Test C: raw hex outside :root exits non-zero"

STDERR_C="${TMPDIR_ROOT}/stderr_c.txt"
STDOUT_C="${TMPDIR_ROOT}/stdout_c.txt"
set +e
bash "$REAL_GUARD" "$RAW_HEX_CSS" >"$STDOUT_C" 2>"$STDERR_C"
EXIT_C=$?
set -e

if [[ "$EXIT_C" -ne 0 ]]; then
  pass "Guard exits non-zero ($EXIT_C) on raw hex outside :root"
else
  fail "Guard exited 0 (should have been non-zero) on raw hex outside :root"
fi

# Hex violation indication should appear in stderr or stdout
COMBINED_C="$(cat "$STDERR_C" "$STDOUT_C" 2>/dev/null)"
if echo "$COMBINED_C" | grep -qE '#[0-9a-fA-F]{3,8}|raw hex|FAIL'; then
  pass "Guard output contains hex violation indication on raw hex outside :root"
else
  fail "Guard output has no hex violation indication; stderr: $(cat "$STDERR_C"); stdout: $(cat "$STDOUT_C")"
fi

# --------------------------------------------------------------------------
# Test D: dual :root (light + dark media) exits 0 (all hex inside :root)
# --------------------------------------------------------------------------
echo "Test D: dual :root blocks (light + dark @media) exits 0"

STDERR_D="${TMPDIR_ROOT}/stderr_d.txt"
set +e
bash "$REAL_GUARD" "$DARK_ROOT_CSS" >"${TMPDIR_ROOT}/stdout_d.txt" 2>"$STDERR_D"
EXIT_D=$?
set -e

if [[ "$EXIT_D" -eq 0 ]]; then
  pass "Guard exits 0 on CSS with dual :root blocks (all hex inside :root)"
else
  fail "Guard exits non-zero ($EXIT_D) on dual :root CSS; stderr: $(cat "$STDERR_D"); stdout: $(cat "${TMPDIR_ROOT}/stdout_d.txt")"
fi

# --------------------------------------------------------------------------
# Test E: --css flag routes to the given file (clean file exits 0)
# --------------------------------------------------------------------------
echo "Test E: --css flag routes to a given file"

STDERR_E="${TMPDIR_ROOT}/stderr_e.txt"
set +e
bash "$REAL_GUARD" --css "$CLEAN_CSS" >"${TMPDIR_ROOT}/stdout_e.txt" 2>"$STDERR_E"
EXIT_E=$?
set -e

if [[ "$EXIT_E" -eq 0 ]]; then
  pass "--css flag routes to given clean file and exits 0"
else
  fail "--css flag test failed (exit $EXIT_E); stderr: $(cat "$STDERR_E")"
fi

# --------------------------------------------------------------------------
# Test F: positional argument overrides the default target
# --------------------------------------------------------------------------
echo "Test F: positional argument overrides the default target (transition:all file)"

STDERR_F="${TMPDIR_ROOT}/stderr_f.txt"
set +e
bash "$REAL_GUARD" "$TRANSITION_ALL_CSS" >"${TMPDIR_ROOT}/stdout_f.txt" 2>"$STDERR_F"
EXIT_F=$?
set -e

if [[ "$EXIT_F" -ne 0 ]]; then
  pass "Positional arg routes to given violation file and exits non-zero ($EXIT_F)"
else
  fail "Positional arg test failed — expected non-zero but got 0; stdout: $(cat "${TMPDIR_ROOT}/stdout_f.txt")"
fi

# --------------------------------------------------------------------------
# Verify no real-repo side effects (only scripts/ci/ should differ)
# --------------------------------------------------------------------------
echo "Test G: no real-repo side effects (git status shows no unintended changes)"

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
set +e
DIRTY_FILES=$(git -C "$REPO_ROOT" status --short 2>/dev/null | grep -v '^\?\?' | grep -v "scripts/ci/" | grep -v ".planning/" || true)
set -e

if [[ -z "$DIRTY_FILES" ]]; then
  pass "No real-repo side effects outside scripts/ci/"
else
  fail "Unexpected dirty files in real repo: ${DIRTY_FILES}"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "admin-css-conformance.test: FAIL"
  exit 1
fi

echo "admin-css-conformance.test: PASS"
exit 0
