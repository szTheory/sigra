#!/usr/bin/env bash
# Self-test for stale-render-guard.sh (Phase 216 Plan 06, HARNESS-02).
#
# Hermetic: operates entirely inside a mktemp -d throwaway git repo.
# No files are created in the real repo; git status of the real repo is
# unchanged after this script runs.
#
# Test cases:
#   A: sha-match, no source changes → PASS
#   B: sha-mismatch (bundle at wrong sha) → FAIL
#   C: empty eval dir (no bundles) → FAIL
#   D: unreachable sha → FAIL + loud error
#   E: admin source newer than bundle → FAIL
#   F: admin glob matching unit test (targeted admin paths are caught)
#
# Usage: bash scripts/ci/stale-render-guard.test.sh
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
REAL_GUARD="${SCRIPT_DIR}/stale-render-guard.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Helper: create a bundle.json with a given app_git_sha in a repo
# --------------------------------------------------------------------------
make_bundle() {
  local repo="$1"
  local sha="$2"
  local surface="${3:-test-surface}"
  local cell="${4:-light-desktop-populated}"
  local dir="${repo}/test/example/priv/playwright/eval/${sha}/${surface}/${cell}"
  mkdir -p "$dir"
  cat > "${dir}/bundle.json" <<EOF
{
  "app_git_sha": "${sha}",
  "surface": "${surface}",
  "cell": "${cell}",
  "render_sha256": "deadbeefdeadbeef1234567890abcdef1234567890abcdef1234567890abcdef",
  "findings_summary": { "total": 0, "gate": 0, "warn": 0 }
}
EOF
}

# --------------------------------------------------------------------------
# Helper: scaffold a fresh hermetic git repo with required structure
# --------------------------------------------------------------------------
make_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@stale-render-guard.test"
  git -C "$repo" config user.name "Stale Render Guard Self-Test"

  mkdir -p "$repo/scripts/ci"
  mkdir -p "$repo/lib/sigra/admin"
  mkdir -p "$repo/test/example/priv/static/assets"
  mkdir -p "$repo/priv/templates/sigra.install/admin"

  cp "$REAL_GUARD" "$repo/scripts/ci/stale-render-guard.sh"
  chmod +x "$repo/scripts/ci/stale-render-guard.sh"

  # Seed admin source files so the guard has something to diff against
  echo "/* admin css */" > "$repo/test/example/priv/static/assets/sigra_admin.css"
  echo "# admin module" > "$repo/lib/sigra/admin.ex"
  echo "# admin policy" > "$repo/lib/sigra/admin/policy.ex"
  echo "/* admin template */" > "$repo/priv/templates/sigra.install/admin/sigra_admin.css"

  git -C "$repo" add .
  git -C "$repo" commit -q -m "initial baseline"
  git -C "$repo" rev-parse HEAD
}

# --------------------------------------------------------------------------
# Create the temporary working directory now (after helpers are defined)
# --------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d)"

# --------------------------------------------------------------------------
# Test A: sha-match, no source changes → PASS
# --------------------------------------------------------------------------
echo "Test A: sha-match + no source changes → PASS"
REPO_A="$TMPDIR_ROOT/repo-a"
BASE_SHA_A=$(make_repo "$REPO_A")
make_bundle "$REPO_A" "$BASE_SHA_A"

STDERR_A="$TMPDIR_ROOT/stderr_a.txt"
set +e
( cd "$REPO_A" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_A" )
EXIT_A=$?
set -e

if [[ "$EXIT_A" -eq 0 ]]; then
  pass "A: guard exits 0 when bundle sha matches HEAD and no source changes"
else
  fail "A: guard exited non-zero ($EXIT_A) on matching sha; stderr: $(cat "$STDERR_A")"
fi

if grep -q "FAIL" "$STDERR_A" 2>/dev/null; then
  fail "A: guard stderr contains FAIL on a valid bundle"
else
  pass "A: guard stderr has no FAIL on a valid bundle"
fi

# --------------------------------------------------------------------------
# Test B: sha-mismatch → FAIL
# --------------------------------------------------------------------------
echo "Test B: sha-mismatch → FAIL"
REPO_B="$TMPDIR_ROOT/repo-b"
BASE_SHA_B=$(make_repo "$REPO_B")

# Bundle claims BASE_SHA_B. Now move HEAD forward with a new commit.
echo "/* modified for test B */" >> "$REPO_B/lib/sigra/admin.ex"
git -C "$REPO_B" add lib/sigra/admin.ex
git -C "$REPO_B" commit -q -m "test B: move HEAD forward"
HEAD_B=$(git -C "$REPO_B" rev-parse HEAD)

# Bundle was written at BASE_SHA_B, but HEAD is now HEAD_B
make_bundle "$REPO_B" "$BASE_SHA_B"

STDERR_B="$TMPDIR_ROOT/stderr_b.txt"
set +e
( cd "$REPO_B" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_B" )
EXIT_B=$?
set -e

if [[ "$EXIT_B" -ne 0 ]]; then
  pass "B: guard exits non-zero on sha mismatch (bundle at $BASE_SHA_B, HEAD at $HEAD_B)"
else
  fail "B: guard exited 0 on sha mismatch (should have failed)"
fi

if grep -q "FAIL" "$STDERR_B" 2>/dev/null; then
  pass "B: guard stderr contains FAIL on sha mismatch"
else
  fail "B: guard stderr does not contain FAIL; actual: $(cat "$STDERR_B")"
fi

# --------------------------------------------------------------------------
# Test C: empty eval dir (no bundles) → FAIL
# --------------------------------------------------------------------------
echo "Test C: empty eval dir (no bundles) → FAIL"
REPO_C="$TMPDIR_ROOT/repo-c"
BASE_SHA_C=$(make_repo "$REPO_C")
# No eval/ dir created at all

STDERR_C="$TMPDIR_ROOT/stderr_c.txt"
set +e
( cd "$REPO_C" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_C" )
EXIT_C=$?
set -e

if [[ "$EXIT_C" -ne 0 ]]; then
  pass "C: guard exits non-zero when no bundles found (absence = hard FAIL per D-08)"
else
  fail "C: guard exited 0 on empty eval dir (should have failed)"
fi

if grep -q "no bundle" "$STDERR_C" 2>/dev/null; then
  pass "C: guard stderr mentions 'no bundle' on absent bundles"
else
  fail "C: guard stderr does not mention 'no bundle'; actual: $(cat "$STDERR_C")"
fi

# --------------------------------------------------------------------------
# Test D: unreachable sha → FAIL + loud error
# --------------------------------------------------------------------------
echo "Test D: unreachable sha (sha-mismatch triggers before unreachable check) → FAIL"
REPO_D="$TMPDIR_ROOT/repo-d"
BASE_SHA_D=$(make_repo "$REPO_D")
# Create a bundle with a fake sha that doesn't exist in this repo
FAKE_SHA="aabbccddaabbccddaabbccddaabbccddaabbccdd"
make_bundle "$REPO_D" "$FAKE_SHA"

STDERR_D="$TMPDIR_ROOT/stderr_d.txt"
set +e
( cd "$REPO_D" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_D" )
EXIT_D=$?
set -e

if [[ "$EXIT_D" -ne 0 ]]; then
  pass "D: guard exits non-zero on unreachable/mismatched sha"
else
  fail "D: guard exited 0 on unreachable sha (should have failed)"
fi

if grep -q "FAIL" "$STDERR_D" 2>/dev/null; then
  pass "D: guard stderr contains FAIL on unreachable sha"
else
  fail "D: guard stderr does not contain FAIL; actual: $(cat "$STDERR_D")"
fi

# --------------------------------------------------------------------------
# Test E: admin source newer than bundle → FAIL
# --------------------------------------------------------------------------
echo "Test E: admin source changed after bundle capture → FAIL"
REPO_E="$TMPDIR_ROOT/repo-e"
BASE_SHA_E=$(make_repo "$REPO_E")
# Create a bundle at BASE_SHA_E
make_bundle "$REPO_E" "$BASE_SHA_E"

# Now modify an admin source file and commit (HEAD moves forward of bundle sha)
echo "/* modified post-bundle */" >> "$REPO_E/test/example/priv/static/assets/sigra_admin.css"
git -C "$REPO_E" add test/example/priv/static/assets/sigra_admin.css
git -C "$REPO_E" commit -q -m "test E: admin source changed after bundle"
# HEAD is now ahead of BASE_SHA_E, and the bundle still claims BASE_SHA_E

STDERR_E="$TMPDIR_ROOT/stderr_e.txt"
set +e
( cd "$REPO_E" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_E" )
EXIT_E=$?
set -e

if [[ "$EXIT_E" -ne 0 ]]; then
  pass "E: guard exits non-zero when admin source is newer than bundle"
else
  fail "E: guard exited 0 when admin source changed after bundle (should have failed)"
fi

if grep -q "FAIL" "$STDERR_E" 2>/dev/null; then
  pass "E: guard stderr contains FAIL when admin source newer"
else
  fail "E: guard stderr does not contain FAIL; actual: $(cat "$STDERR_E")"
fi

# --------------------------------------------------------------------------
# Test F: admin glob matching — targeted admin paths are caught
# --------------------------------------------------------------------------
echo "Test F1: lib/sigra/admin/ changes trigger the guard"
REPO_F="$TMPDIR_ROOT/repo-f"
BASE_SHA_F=$(make_repo "$REPO_F")
make_bundle "$REPO_F" "$BASE_SHA_F"

# Modify lib/sigra/admin/policy.ex and commit (HEAD moves past bundle sha)
echo "# admin policy v2" > "$REPO_F/lib/sigra/admin/policy.ex"
git -C "$REPO_F" add lib/sigra/admin/policy.ex
git -C "$REPO_F" commit -q -m "test F1: modify lib/sigra/admin/"

STDERR_F1="$TMPDIR_ROOT/stderr_f1.txt"
set +e
( cd "$REPO_F" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_F1" )
EXIT_F1=$?
set -e

if [[ "$EXIT_F1" -ne 0 ]]; then
  pass "F1: lib/sigra/admin/ changes trigger the guard (sha-mismatch or source-newer)"
else
  fail "F1: lib/sigra/admin/ change not caught; stderr: $(cat "$STDERR_F1")"
fi

echo "Test F2: priv/templates/sigra.install/admin/ changes trigger the guard"
REPO_F2="$TMPDIR_ROOT/repo-f2"
BASE_SHA_F2=$(make_repo "$REPO_F2")
make_bundle "$REPO_F2" "$BASE_SHA_F2"

# Modify the template admin CSS and commit
echo "/* admin template v2 */" > "$REPO_F2/priv/templates/sigra.install/admin/sigra_admin.css"
git -C "$REPO_F2" add priv/templates/sigra.install/admin/sigra_admin.css
git -C "$REPO_F2" commit -q -m "test F2: modify admin template CSS"

STDERR_F2="$TMPDIR_ROOT/stderr_f2.txt"
set +e
( cd "$REPO_F2" && bash scripts/ci/stale-render-guard.sh 2>"$STDERR_F2" )
EXIT_F2=$?
set -e

if [[ "$EXIT_F2" -ne 0 ]]; then
  pass "F2: priv/templates/sigra.install/admin/ changes trigger the guard"
else
  fail "F2: priv/templates/sigra.install/admin/ change not caught; stderr: $(cat "$STDERR_F2")"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "stale-render-guard.test: FAIL"
  exit 1
fi

echo "stale-render-guard.test: PASS"
exit 0
