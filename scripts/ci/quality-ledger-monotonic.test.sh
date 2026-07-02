#!/usr/bin/env bash
# Self-test for quality-ledger-monotonic.sh: proves the guard exits non-zero
# on a Tier-2 → Tier-1 decrease and exits 0 on a no-change run.
#
# Hermetic: operates entirely inside a mktemp -d throwaway git repo.
# No files are created in the real repo; git status of the real repo is
# unchanged after this script runs.
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
REAL_GUARD="${SCRIPT_DIR}/quality-ledger-monotonic.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Build a hermetic throwaway git repo that mirrors the guard's directory
# expectations:
#   ROOT/scripts/ci/quality-ledger-monotonic.sh   (the guard binary)
#   ROOT/guides/reference/admin-quality-ledger.md  (the ledger)
# The guard derives ROOT from its own location:
#   ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# so the guard must live at ROOT/scripts/ci/ in the temp repo.
# --------------------------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
REPO="$TMPDIR_ROOT/test-repo"
mkdir -p "$REPO"

# Set up git with a local identity so commits work in CI (no global config needed).
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@quality-ledger-monotonic.test"
git -C "$REPO" config user.name "Monotonic Guard Self-Test"

# Create the directory skeleton.
mkdir -p "$REPO/scripts/ci"
mkdir -p "$REPO/guides/reference"

# Copy the real guard binary into the temp repo at the expected location.
cp "$REAL_GUARD" "$REPO/scripts/ci/quality-ledger-monotonic.sh"
chmod +x "$REPO/scripts/ci/quality-ledger-monotonic.sh"

# ---- Minimal valid ledger with one Tier-2 cell -------------------------
# The guard's extract_tiers function matches rows via:
#   grep -E '^\| [a-z]'
#   awk -F'|' '{ item=$2; tier=$4; if (tier ~ /^[012]$/) print item ":" tier }'
# Column positions in a pipe-delimited markdown table:
#   | col1 | col2 | col3 | col4 | col5 |
#   ^ $1   ^ $2   ^ $3   ^ $4   ^ $5
# So column-4 is the Tier column. We need at least one row starting with
# "| " + lowercase, and its column-4 must be a bare 0, 1, or 2.

LEDGER_PATH="$REPO/guides/reference/admin-quality-ledger.md"
# Mirror the real ledger's 4-column shape: | Item | Level | Tier | Evidence |
# The guard's awk parse: $2=item, $4=tier (column-4, 1-indexed in |-delimited rows).
# Rows must match grep -E '^\| [a-z]' (start with "| " + lowercase letter).
cat > "$LEDGER_PATH" <<'LEDGER'
# Admin Quality Ledger

| item              | level  | tier | evidence                          |
| ----------------- | ------ | ---- | --------------------------------- |
| accessibility     | page   | 2    | axe gate passing; APG gates pass  |
| visual-baseline   | global | 1    | PNGs in CI checkpoint lane        |
LEDGER

# Commit the Tier-2 baseline.
git -C "$REPO" add guides/reference/admin-quality-ledger.md scripts/ci/quality-ledger-monotonic.sh
git -C "$REPO" commit -q -m "baseline: accessibility=2, visual-baseline=1"
BASE_COMMIT=$(git -C "$REPO" rev-parse HEAD)

# ---- Test A: 2 → 1 decrease MUST exit non-zero -----------------------
echo "Test A: 2→1 decrease is caught by the guard (must exit non-zero)"

# Mutate the working tree: change Tier from 2 → 1 (do NOT commit).
sed -i.bak 's/| 2    | axe gate passing/| 1    | axe gate passing/' "$LEDGER_PATH"
rm -f "${LEDGER_PATH}.bak"
grep -q '| 1    | axe gate passing' "$LEDGER_PATH" \
  || { echo "FATAL: self-test fixture mutation did not apply (heredoc reformatted?)" >&2; exit 2; }

# Run the guard; capture both exit code and stderr.
GUARD_STDERR_A="$TMPDIR_ROOT/stderr_a.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-ledger-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_A"
)
GUARD_EXIT_A=$?
set -e

if [[ "$GUARD_EXIT_A" -ne 0 ]]; then
  pass "Guard exited non-zero ($GUARD_EXIT_A) on 2→1 decrease"
else
  fail "Guard exited 0 (should have been non-zero) on 2→1 decrease"
fi

if grep -q "tier decreased" "$GUARD_STDERR_A" 2>/dev/null; then
  pass "Guard stderr contains 'tier decreased' on 2→1 decrease"
else
  fail "Guard stderr does NOT contain 'tier decreased'; actual stderr: $(cat "$GUARD_STDERR_A")"
fi

# ---- Test B: no-change run MUST exit 0 --------------------------------
echo "Test B: no-change run exits 0 (guard is not trivially always-failing)"

# Restore the working tree to match the committed state.
git -C "$REPO" checkout -- guides/reference/admin-quality-ledger.md

GUARD_STDERR_B="$TMPDIR_ROOT/stderr_b.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-ledger-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_B"
)
GUARD_EXIT_B=$?
set -e

if [[ "$GUARD_EXIT_B" -eq 0 ]]; then
  pass "Guard exited 0 on no-change run"
else
  fail "Guard exited non-zero ($GUARD_EXIT_B) on no-change run; stderr: $(cat "$GUARD_STDERR_B")"
fi

# ---- Test C: 1→2 increase MUST exit 0 --------------------------------
echo "Test C: 1→2 increase exits 0 (guard allows monotonic tier promotion)"

# Restore the working tree to committed baseline.
git -C "$REPO" checkout -- guides/reference/admin-quality-ledger.md

# Mutate working tree: raise visual-baseline from 1 → 2 (an allowed monotonic increase).
sed -i.bak 's/| visual-baseline   | global | 1    | PNGs in CI checkpoint lane/| visual-baseline   | global | 2    | PNGs in CI checkpoint lane/' "$LEDGER_PATH"
rm -f "${LEDGER_PATH}.bak"
grep -q '| visual-baseline   | global | 2    |' "$LEDGER_PATH" \
  || { echo "FATAL: Test C fixture mutation did not apply" >&2; exit 2; }

GUARD_STDERR_C="$TMPDIR_ROOT/stderr_c.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-ledger-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_C"
)
GUARD_EXIT_C=$?
set -e

if [[ "$GUARD_EXIT_C" -eq 0 ]]; then
  pass "Guard exited 0 on 1→2 increase (monotonic promotion is allowed)"
else
  fail "Guard exited non-zero ($GUARD_EXIT_C) on 1→2 increase (should have been 0); stderr: $(cat "$GUARD_STDERR_C")"
fi

if grep -q "tier decreased" "$GUARD_STDERR_C" 2>/dev/null; then
  fail "Guard stderr incorrectly contains 'tier decreased' on a 1→2 increase"
else
  pass "Guard stderr has no 'tier decreased' on a 1→2 increase"
fi

# ---- Test D: decorated column-4 ("2*") is invisible to the guard parse ------
# WHY: The ledger doc explicitly forbids decorators on tier cells (e.g. "2*", "2+")
# because the guard's awk parse uses /^[012]$/ — a strict match that rejects anything
# other than a bare 0, 1, or 2. A decorated cell like "2*" is silently skipped by
# the guard, making the row UNPROTECTED: the guard will not detect a decrease on it.
# This test proves that behavior empirically, converting the doc warning into an
# enforced contract so future authors understand the consequence before they use decorators.
echo "Test D: decorated column-4 ('2*') is invisible to the guard parse (exits 0, row unprotected)"

# Restore the working tree to committed baseline.
git -C "$REPO" checkout -- guides/reference/admin-quality-ledger.md

# Mutate working tree: change accessibility tier from "2" → "2*" (decorated).
# The base commit has accessibility=2. After this mutation, the working tree has "2*".
# Because "2*" does not match /^[012]$/, the guard skips the row entirely —
# the decrease from 2→(invisible) is not detected, and the guard exits 0.
sed -i.bak 's/| accessibility     | page   | 2    | axe gate passing/| accessibility     | page   | 2*   | axe gate passing/' "$LEDGER_PATH"
rm -f "${LEDGER_PATH}.bak"
grep -q '| accessibility     | page   | 2\*   |' "$LEDGER_PATH" \
  || { echo "FATAL: Test D fixture mutation did not apply" >&2; exit 2; }

GUARD_STDERR_D="$TMPDIR_ROOT/stderr_d.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-ledger-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_D"
)
GUARD_EXIT_D=$?
set -e

# Expected: guard exits 0 — the "2*" row is invisible to the awk parse, so no
# decrease is detected. This is the DOCUMENTED-BUT-DANGEROUS behavior: the row
# loses protection the moment a decorator is added.
if [[ "$GUARD_EXIT_D" -eq 0 ]]; then
  pass "Test D: decorated '2*' is invisible to the guard parse (exits 0, not protected)"
else
  fail "Test D: unexpected non-zero exit ($GUARD_EXIT_D) on decorated '2*' cell; stderr: $(cat "$GUARD_STDERR_D")"
fi

# ---- Summary -----------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "quality-ledger-monotonic.test: FAIL"
  exit 1
fi

echo "quality-ledger-monotonic.test: PASS"
exit 0
