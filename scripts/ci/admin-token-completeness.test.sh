#!/usr/bin/env bash
# Self-test for admin-token-completeness.sh: proves the guard fails on token/doc
# divergence and passes on matched sets. Hermetic: mktemp CSS + doc fixtures,
# no real-repo side effects.
#
# Tests:
#   A — matched sets → exit 0
#   B — CSS token missing from doc → exit non-zero; stderr names the missing token
#   C — doc token absent from CSS → exit non-zero; stderr names the stale row
#   D — dual light/dark :root both scanned → exit 0 (dark-only token counted)
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
REAL_GUARD="${SCRIPT_DIR}/admin-token-completeness.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Create hermetic temp directory for CSS + doc fixtures.
# The guard accepts --css and --doc overrides, so no real-repo mutation needed.
# --------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d)"

# --------------------------------------------------------------------------
# Test A: matched sets — CSS defines --sg-a and --sg-b in light :root;
# doc lists both. Expect exit 0.
# --------------------------------------------------------------------------
echo "Test A: matched sets exits 0"

CSS_A="${TMPDIR_ROOT}/css_a.css"
DOC_A="${TMPDIR_ROOT}/doc_a.md"

cat > "$CSS_A" <<'CSS'
:root {
  --sg-a: red;
  --sg-b: blue;
}

@media (prefers-color-scheme: dark) {
  :root {
    --sg-a: pink;
  }
}

.foo {
  color: var(--sg-a);
}
CSS

cat > "$DOC_A" <<'DOC'
| `--sg-a` | red | Primary color |
| `--sg-b` | blue | Secondary color |
DOC

set +e
STDOUT_A="${TMPDIR_ROOT}/stdout_a.txt"
STDERR_A="${TMPDIR_ROOT}/stderr_a.txt"
bash "$REAL_GUARD" --css "$CSS_A" --doc "$DOC_A" >"$STDOUT_A" 2>"$STDERR_A"
EXIT_A=$?
set -e

if [[ "$EXIT_A" -eq 0 ]]; then
  pass "Matched sets exits 0"
else
  fail "Matched sets exited non-zero ($EXIT_A); stderr: $(cat "$STDERR_A"); stdout: $(cat "$STDOUT_A")"
fi

if grep -q "PASS" "$STDOUT_A" 2>/dev/null; then
  pass "Matched sets emits PASS in stdout"
else
  fail "Matched sets did not emit PASS; stdout: $(cat "$STDOUT_A")"
fi

# --------------------------------------------------------------------------
# Test B: CSS token missing from doc — CSS defines --sg-a and --sg-b, doc
# lists only --sg-a. Expect exit non-zero; stderr should name --sg-b as
# undocumented.
# --------------------------------------------------------------------------
echo "Test B: CSS token missing from doc exits non-zero"

CSS_B="${TMPDIR_ROOT}/css_b.css"
DOC_B="${TMPDIR_ROOT}/doc_b.md"

cat > "$CSS_B" <<'CSS'
:root {
  --sg-a: red;
  --sg-b: blue;
}
CSS

cat > "$DOC_B" <<'DOC'
| `--sg-a` | red | Primary color |
DOC

set +e
STDOUT_B="${TMPDIR_ROOT}/stdout_b.txt"
STDERR_B="${TMPDIR_ROOT}/stderr_b.txt"
bash "$REAL_GUARD" --css "$CSS_B" --doc "$DOC_B" >"$STDOUT_B" 2>"$STDERR_B"
EXIT_B=$?
set -e

if [[ "$EXIT_B" -ne 0 ]]; then
  pass "CSS token missing from doc exits non-zero ($EXIT_B)"
else
  fail "CSS token missing from doc exited 0 (expected non-zero)"
fi

if grep -q "\-\-sg-b" "$STDERR_B" 2>/dev/null; then
  pass "Stderr names --sg-b as undocumented"
else
  fail "Stderr does not name --sg-b; actual stderr: $(cat "$STDERR_B")"
fi

# --------------------------------------------------------------------------
# Test C: doc token absent from CSS — CSS defines only --sg-a; doc lists
# --sg-a and --sg-c. Expect exit non-zero; stderr should name --sg-c as
# stale doc row.
# --------------------------------------------------------------------------
echo "Test C: doc token absent from CSS exits non-zero"

CSS_C="${TMPDIR_ROOT}/css_c.css"
DOC_C="${TMPDIR_ROOT}/doc_c.md"

cat > "$CSS_C" <<'CSS'
:root {
  --sg-a: red;
}
CSS

cat > "$DOC_C" <<'DOC'
| `--sg-a` | red | Primary color |
| `--sg-c` | green | Stale token |
DOC

set +e
STDOUT_C="${TMPDIR_ROOT}/stdout_c.txt"
STDERR_C="${TMPDIR_ROOT}/stderr_c.txt"
bash "$REAL_GUARD" --css "$CSS_C" --doc "$DOC_C" >"$STDOUT_C" 2>"$STDERR_C"
EXIT_C=$?
set -e

if [[ "$EXIT_C" -ne 0 ]]; then
  pass "Doc token absent from CSS exits non-zero ($EXIT_C)"
else
  fail "Doc token absent from CSS exited 0 (expected non-zero)"
fi

if grep -q "\-\-sg-c" "$STDERR_C" 2>/dev/null; then
  pass "Stderr names --sg-c as stale doc row"
else
  fail "Stderr does not name --sg-c; actual stderr: $(cat "$STDERR_C")"
fi

# --------------------------------------------------------------------------
# Test D: dual light/dark :root both scanned.
# --sg-a is defined in the light :root; --sg-b is defined ONLY in the dark
# @media :root (not in the light :root). The doc lists both --sg-a and --sg-b.
# A single-:root scan would miss --sg-b and report it as stale.
# This test asserts exit 0, proving the dark :root block is also scanned.
# --------------------------------------------------------------------------
echo "Test D: dark @media :root block is scanned (dual :root, expect exit 0)"

CSS_D="${TMPDIR_ROOT}/css_d.css"
DOC_D="${TMPDIR_ROOT}/doc_d.md"

cat > "$CSS_D" <<'CSS'
:root {
  --sg-a: red;
}

@media (prefers-color-scheme: dark) {
  :root {
    --sg-b: navy;
  }
}

.foo {
  color: var(--sg-a);
  background: var(--sg-b);
}
CSS

cat > "$DOC_D" <<'DOC'
| `--sg-a` | red | Light primary |
| `--sg-b` | navy | Dark-only token |
DOC

set +e
STDOUT_D="${TMPDIR_ROOT}/stdout_d.txt"
STDERR_D="${TMPDIR_ROOT}/stderr_d.txt"
bash "$REAL_GUARD" --css "$CSS_D" --doc "$DOC_D" >"$STDOUT_D" 2>"$STDERR_D"
EXIT_D=$?
set -e

if [[ "$EXIT_D" -eq 0 ]]; then
  pass "Dual :root (light + dark @media) exits 0 — dark block scanned"
else
  fail "Dual :root test failed (exit $EXIT_D) — dark :root may not be scanned; stderr: $(cat "$STDERR_D"); stdout: $(cat "$STDOUT_D")"
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
  echo "admin-token-completeness.test: FAIL"
  exit 1
fi

echo "admin-token-completeness.test: PASS"
exit 0
