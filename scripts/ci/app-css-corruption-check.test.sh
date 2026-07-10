#!/usr/bin/env bash
# Self-test for app-css-corruption-check.sh (SHIP-03 / D-10).
#
# Regression proof that the guard catches the orphan-after-`;` corruption
# class: a bare CSS value line immediately following a complete, single-line
# `;`-terminated declaration inside a :root block. Before the D-09 fix, the
# guard's `last_was_prop` state machine absorbed that orphan into the
# preceding declaration's multi-line-continuation branch and never flagged
# it (false negative).
#
# Test cases:
#   A: the committed corrupt fixture (test/fixtures/css/orphan_after_terminated_decl.css)
#      makes the guard exit non-zero.
#   B: a clean fixture (no orphan) makes the guard exit 0 — no false positive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GUARD="${SCRIPT_DIR}/app-css-corruption-check.sh"
CORRUPT_FIXTURE="${ROOT}/test/fixtures/css/orphan_after_terminated_decl.css"

if [[ ! -f "$GUARD" ]]; then
  echo "FATAL: guard script not found at ${GUARD}" >&2
  exit 2
fi

if [[ ! -f "$CORRUPT_FIXTURE" ]]; then
  echo "FATAL: corrupt fixture not found at ${CORRUPT_FIXTURE}" >&2
  exit 2
fi

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT

# ---- Test A: corrupt fixture exits non-zero ---------------------------
echo "Test A: orphan-after-; fixture is flagged (non-zero exit)"

set +e
bash "$GUARD" "$CORRUPT_FIXTURE" >/dev/null 2>&1
EXIT_A=$?
set -e

if [[ "$EXIT_A" -ne 0 ]]; then
  pass "Test A: guard exits non-zero ($EXIT_A) on the orphan-after-; fixture"
else
  fail "Test A: guard exited 0 on the orphan-after-; fixture (false negative — SHIP-03 not fixed)"
fi

# ---- Test B: clean fixture exits 0 (no false positive) -----------------
echo "Test B: clean CSS (no orphan) is not flagged (exit 0)"

TMPDIR_ROOT="$(mktemp -d)"
CLEAN_FIXTURE="${TMPDIR_ROOT}/clean.css"
cat > "$CLEAN_FIXTURE" <<'EOF'
:root {
  --vt-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  --vt-focus-ring: color-mix(in oklab, var(--sg-accent) 40%, transparent);
}
EOF

set +e
bash "$GUARD" "$CLEAN_FIXTURE" >/dev/null 2>&1
EXIT_B=$?
set -e

if [[ "$EXIT_B" -eq 0 ]]; then
  pass "Test B: guard exits 0 on clean CSS (no false positive)"
else
  fail "Test B: guard exited non-zero ($EXIT_B) on clean CSS (false positive)"
fi

# ---- Summary -----------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "app-css-corruption-check.test: FAIL"
  exit 1
fi

echo "app-css-corruption-check.test: PASS"
exit 0
