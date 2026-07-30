#!/usr/bin/env bash
# Self-test for quality-findings-monotonic.sh: proves the guard exits non-zero
# when open_findings INCREASE vs merge-base, and exits 0 on no-change or a decrease.
#
# Hermetic: operates entirely inside a mktemp -d throwaway git repo.
# No files are created in the real repo; git status of the real repo is
# unchanged after this script runs.
#
# Test cases (D-21, RESEARCH Test Map RATCHET-02):
#   A: 3→4 count increase MUST exit non-zero (the down-ratchet's core invariant)
#   B: no-change run MUST exit 0
#   C: 4→3 decrease (improvement) MUST exit 0 (down-ratchet is allowed)
#   D: documented proof that a bogus JSON key cannot silently defeat the parse
#      (the Test-D lesson analog: the guard must parse the specific open_findings key,
#      not silently skip rows with an unrecognized structure)
#
# Floor-rebase declaration mechanism (231-05, guides/reference/floor-rebase-declarations.json):
#   E: no declarations file present + increase -> still fails (unchanged default)
#   F: declaration present but prior_totals do not match the real ledger -> still fails
#   G: declaration whose prior_totals/new_totals exactly match the real transition -> passes
#   H: an increase beyond the declared new floor is NOT authorized by the same
#      declaration -> still fails (proves one-time-use, not a reusable escape hatch)
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
REAL_GUARD="${SCRIPT_DIR}/quality-findings-monotonic.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Build a hermetic throwaway git repo that mirrors the guard's directory
# expectations:
#   ROOT/scripts/ci/quality-findings-monotonic.sh  (the guard binary)
#   ROOT/guides/reference/admin-render-sha.json     (the ledger)
# The guard derives ROOT from its own location:
#   ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# so the guard must live at ROOT/scripts/ci/ in the temp repo.
# --------------------------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
REPO="$TMPDIR_ROOT/test-repo"
mkdir -p "$REPO"

# Set up git with a local identity so commits work in CI (no global config needed).
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@quality-findings-monotonic.test"
git -C "$REPO" config user.name "Findings Monotonic Guard Self-Test"

# Create the directory skeleton.
mkdir -p "$REPO/scripts/ci"
mkdir -p "$REPO/guides/reference"

# Copy the real guard binary into the temp repo at the expected location.
cp "$REAL_GUARD" "$REPO/scripts/ci/quality-findings-monotonic.sh"
chmod +x "$REPO/scripts/ci/quality-findings-monotonic.sh"

# ---- Minimal valid admin-render-sha.json with initial open_findings counts ----
# Schema: { "schema_version": 1, "cells": { "<surface>": { "<cell>": { "render_sha256": null, "open_findings": N } } } }
# We start with users-index-live/light-desktop-populated=3 and user-show-live/light-desktop-populated=0.

LEDGER_PATH="$REPO/guides/reference/admin-render-sha.json"
cat > "$LEDGER_PATH" <<'JSON'
{
  "schema_version": 1,
  "notes": "Test fixture for quality-findings-monotonic self-test.",
  "cells": {
    "users-index-live": {
      "light-desktop-populated": { "render_sha256": null, "open_findings": 3 }
    },
    "user-show-live": {
      "light-desktop-populated": { "render_sha256": null, "open_findings": 0 }
    }
  }
}
JSON

# Commit the baseline.
git -C "$REPO" add guides/reference/admin-render-sha.json scripts/ci/quality-findings-monotonic.sh
git -C "$REPO" commit -q -m "baseline: users-index-live=3, user-show-live=0"
BASE_COMMIT=$(git -C "$REPO" rev-parse HEAD)

# ---- Test A: 3→4 increase MUST exit non-zero --------------------------
echo "Test A: open_findings 3→4 increase is caught by the guard (must exit non-zero)"

# Mutate the working tree: bump users-index-live from 3 → 4 (do NOT commit).
node -e "
const fs = require('fs');
const p = '$LEDGER_PATH';
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.cells['users-index-live']['light-desktop-populated']['open_findings'] = 4;
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"
node -e "
const fs = require('fs');
const d = JSON.parse(fs.readFileSync('$LEDGER_PATH', 'utf8'));
const v = d.cells['users-index-live']['light-desktop-populated']['open_findings'];
if (v !== 4) { console.error('FATAL: Test A fixture mutation failed, got ' + v); process.exit(2); }
"

GUARD_STDERR_A="$TMPDIR_ROOT/stderr_a.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_A"
)
GUARD_EXIT_A=$?
set -e

if [[ "$GUARD_EXIT_A" -ne 0 ]]; then
  pass "Guard exited non-zero ($GUARD_EXIT_A) on 3→4 increase"
else
  fail "Guard exited 0 (should have been non-zero) on 3→4 increase"
fi

if grep -q "open findings increased" "$GUARD_STDERR_A" 2>/dev/null; then
  pass "Guard stderr contains 'open findings increased' on 3→4 increase"
else
  fail "Guard stderr does NOT contain 'open findings increased'; actual stderr: $(cat "$GUARD_STDERR_A")"
fi

# ---- Test B: no-change run MUST exit 0 --------------------------------
echo "Test B: no-change run exits 0 (guard is not trivially always-failing)"

# Restore the working tree to match the committed state.
git -C "$REPO" checkout -- guides/reference/admin-render-sha.json

GUARD_STDERR_B="$TMPDIR_ROOT/stderr_b.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_B"
)
GUARD_EXIT_B=$?
set -e

if [[ "$GUARD_EXIT_B" -eq 0 ]]; then
  pass "Guard exited 0 on no-change run"
else
  fail "Guard exited non-zero ($GUARD_EXIT_B) on no-change run; stderr: $(cat "$GUARD_STDERR_B")"
fi

# ---- Test C: 4→3 decrease (improvement) MUST exit 0 ------------------
echo "Test C: 4→3 decrease exits 0 (down-ratchet is allowed — open count reduced)"

# Restore the working tree to committed baseline (open_findings=3).
git -C "$REPO" checkout -- guides/reference/admin-render-sha.json

# Commit an intermediate state where users-index-live=4, then test a decrease back to 3.
# Actually: base=3, head=2 should also pass. Let's use a direct decrease: base=3, set HEAD=2.
node -e "
const fs = require('fs');
const p = '$LEDGER_PATH';
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.cells['users-index-live']['light-desktop-populated']['open_findings'] = 2;
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"

GUARD_STDERR_C="$TMPDIR_ROOT/stderr_c.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_C"
)
GUARD_EXIT_C=$?
set -e

if [[ "$GUARD_EXIT_C" -eq 0 ]]; then
  pass "Guard exited 0 on 3→2 decrease (findings reduction is allowed)"
else
  fail "Guard exited non-zero ($GUARD_EXIT_C) on 3→2 decrease (should have been 0); stderr: $(cat "$GUARD_STDERR_C")"
fi

if grep -q "open findings increased" "$GUARD_STDERR_C" 2>/dev/null; then
  fail "Guard stderr incorrectly contains 'open findings increased' on a 3→2 decrease"
else
  pass "Guard stderr has no 'open findings increased' on a 3→2 decrease"
fi

# ---- Test D: increase from 0 IS a regression (D-08/D-21 divergence from tier guard) -----
# WHY: The tier guard skips when BASE has zero cells (initial commit).
# For findings, the guard ONLY skips when the ledger FILE is ABSENT at base.
# When the file exists and user-show-live has open_findings:0 at base, an increase to 1
# MUST be caught — it is a real regression, not an "initial commit" scenario.
# This test proves that behavior empirically.
echo "Test D: increase from 0 IS caught (not silently skipped — D-08/D-21 divergence)"

# Restore the working tree to committed baseline.
git -C "$REPO" checkout -- guides/reference/admin-render-sha.json

# Mutate working tree: bump user-show-live from 0 → 1 (an increase from zero — should FAIL).
node -e "
const fs = require('fs');
const p = '$LEDGER_PATH';
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.cells['user-show-live']['light-desktop-populated']['open_findings'] = 1;
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"

GUARD_STDERR_D="$TMPDIR_ROOT/stderr_d.txt"
set +e
(
  cd "$REPO"
  bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$GUARD_STDERR_D"
)
GUARD_EXIT_D=$?
set -e

# Expected: guard exits non-zero — an increase from 0 IS a regression for the findings guard.
# (Contrast the tier guard, which skips when base has zero cells.)
if [[ "$GUARD_EXIT_D" -ne 0 ]]; then
  pass "Test D: increase from 0 → 1 correctly exits non-zero (not skipped)"
else
  fail "Test D: guard incorrectly exited 0 on a 0→1 increase (should have been non-zero)"
fi

if grep -q "open findings increased" "$GUARD_STDERR_D" 2>/dev/null; then
  pass "Test D: stderr contains 'open findings increased' confirming 0→1 is caught"
else
  fail "Test D: stderr does NOT contain 'open findings increased'; actual stderr: $(cat "$GUARD_STDERR_D")"
fi

# ==========================================================================
# 231-05: floor-rebase declaration mechanism (guides/reference/
# floor-rebase-declarations.json). Four required cases proving the
# declaration is verified, not trusted, and authorizes exactly one
# transition. Tests E and G are the ones that prove this did not just
# punch a hole -- an absent/mismatched declaration must still fail exactly
# like before this mechanism existed.
# ==========================================================================

DECL_PATH="$REPO/guides/reference/floor-rebase-declarations.json"

# ---- Test E: absent declaration + increase -> fails (no hole punched) ----
# Restates Test A's outcome explicitly for this section: with no declarations
# file at all, an increase is caught exactly as before this mechanism existed.
echo ""
echo "Test E: no declarations file present + increase -> exit non-zero (unchanged from before)"

git -C "$REPO" checkout -- guides/reference/admin-render-sha.json
rm -f "$DECL_PATH"

node -e "
const fs = require('fs');
const p = '$LEDGER_PATH';
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.cells['users-index-live']['light-desktop-populated']['open_findings'] = 4;
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"

STDERR_E="$TMPDIR_ROOT/stderr_e.txt"
set +e
( cd "$REPO" && bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$STDERR_E" )
GUARD_EXIT_E=$?
set -e

if [[ "$GUARD_EXIT_E" -ne 0 ]]; then
  pass "Test E: no declarations file, 3→4 increase still exits non-zero"
else
  fail "Test E: no declarations file should still fail a 3→4 increase (got 0)"
fi

# ---- Test F: declaration present but does not match the real ledger -> fails ----
echo ""
echo "Test F: declaration whose totals do not match the real ledger -> exit non-zero"

mkdir -p "$(dirname "$DECL_PATH")"
node -e "
const fs = require('fs');
const decl = {
  schema_version: 1,
  declarations: [
    {
      id: 'test-mismatched-declaration',
      run_id: '00000000000',
      job_id: '11111111111',
      commit_sha: 'deadbeef',
      reason: 'deliberately WRONG prior_totals for Test F -- must be rejected',
      // WRONG: real base is 3, this declares 999 -- must not validate.
      prior_totals: { 'users-index-live/light-desktop-populated': 999 },
      new_totals: { 'users-index-live/light-desktop-populated': 4 }
    }
  ]
};
fs.writeFileSync('$DECL_PATH', JSON.stringify(decl, null, 2) + '\n');
"

STDERR_F="$TMPDIR_ROOT/stderr_f.txt"
set +e
( cd "$REPO" && bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$STDERR_F" )
GUARD_EXIT_F=$?
set -e

if [[ "$GUARD_EXIT_F" -ne 0 ]] && grep -q "does not match" "$STDERR_F" 2>/dev/null; then
  pass "Test F: mismatched declaration is rejected and the increase still fails"
else
  fail "Test F: a declaration whose prior_totals do not match the real ledger should still fail (got $GUARD_EXIT_F); stderr: $(cat "$STDERR_F")"
fi

# ---- Test G: a matching, verified declaration authorizes the exact transition -> passes ----
echo ""
echo "Test G: declaration whose totals exactly match the real base/head ledger -> exit 0"

node -e "
const fs = require('fs');
const decl = {
  schema_version: 1,
  declarations: [
    {
      id: 'test-matching-declaration',
      run_id: '22222222222',
      job_id: '33333333333',
      commit_sha: 'cafef00d',
      reason: 'Test G -- prior_totals/new_totals exactly match the real 3->4 transition.',
      prior_totals: { 'users-index-live/light-desktop-populated': 3 },
      new_totals: { 'users-index-live/light-desktop-populated': 4 }
    }
  ]
};
fs.writeFileSync('$DECL_PATH', JSON.stringify(decl, null, 2) + '\n');
"

STDERR_G="$TMPDIR_ROOT/stderr_g.txt"
set +e
( cd "$REPO" && bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$STDERR_G" )
GUARD_EXIT_G=$?
set -e

if [[ "$GUARD_EXIT_G" -eq 0 ]] && grep -q "verified and authorizes" "$STDERR_G" 2>/dev/null; then
  pass "Test G: a verified, matching declaration authorizes the exact declared transition"
else
  fail "Test G: a declaration matching the real ledger exactly should pass (got $GUARD_EXIT_G); stderr: $(cat "$STDERR_G")"
fi

# ---- Test H: an increase BEYOND the declared new floor still fails (one-time use) ----
# Proves the same declaration cannot be reused to permit further, larger drift: once
# the ledger moves past the exact new_totals value the declaration named, HEAD no
# longer matches and the declaration stops validating.
echo ""
echo "Test H: increase beyond the declared new floor -> exit non-zero (not reusable for further drift)"

# The declaration from Test G still names new_totals=4. Push HEAD to 5 (beyond it).
node -e "
const fs = require('fs');
const p = '$LEDGER_PATH';
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
d.cells['users-index-live']['light-desktop-populated']['open_findings'] = 5;
fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
"

STDERR_H="$TMPDIR_ROOT/stderr_h.txt"
set +e
( cd "$REPO" && bash scripts/ci/quality-findings-monotonic.sh --base "$BASE_COMMIT" 2>"$STDERR_H" )
GUARD_EXIT_H=$?
set -e

if [[ "$GUARD_EXIT_H" -ne 0 ]]; then
  pass "Test H: drift beyond the declared new floor (4→5) is NOT authorized by the stale declaration, still fails"
else
  fail "Test H: an increase beyond the declared new floor should still fail (got 0) -- the declaration must not be reusable for unlimited drift"
fi

# Cleanup: remove the test declarations file and restore the ledger so later tests
# in this file (none currently follow, but keep the pattern) are not affected.
rm -f "$DECL_PATH"
git -C "$REPO" checkout -- guides/reference/admin-render-sha.json

# ---- Summary -----------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "quality-findings-monotonic.test: FAIL"
  exit 1
fi

echo "quality-findings-monotonic.test: PASS"
exit 0
