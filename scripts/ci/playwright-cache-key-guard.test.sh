#!/usr/bin/env bash
# Self-test for playwright-cache-key-guard.sh (Phase 230 / FAST-06 / D-16, D-18).
#
# Hermetic: no network access, no `gh` CLI, no token. Every case runs
# against a hand-written minimal workflow + lockfile fixture pair written
# into a `mktemp -d` sandbox and passed via the guard's `--workflow` /
# `--lockfile` flags.
#
# Test cases (mirrors the plan's <behavior> block):
#   A: matching fixture pair (-v2 shape) -> exit 0, PASS line names both versions.
#   B: mismatched versions -> exit 1, FAIL line names both versions + both paths.
#   C: workflow fixture has no Playwright cache key at all -> exit 1 (absent
#      key is drift, not an exemption).
#   D: lockfile fixture has no @playwright/test entry -> exit 1.
#   E: unknown flag -> exit 2 with an unknown-arg message on stderr.
#   F: workflow fixture has the browser-set + version segment but NO -vN
#      suffix token at all -> exit 1. Phase 231 / C-6: proves generalizing
#      the extraction from a hard-coded -v1 to "any -vN" did not also make
#      the -vN token itself optional -- a fail-closed guard must not become
#      fail-open on the very thing it was generalized to accept.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/playwright-cache-key-guard.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"

write_workflow() {
  # $1 = path, $2 = version to embed in the cache key (empty = omit the key entirely)
  # $3 = version-token suffix without its leading dash, e.g. "v2" (defaults to
  #      "v2"; pass the literal string "none" to omit the -vN suffix entirely
  #      while still embedding the browser-set + version segment -- Test F)
  local path="$1" version="$2" suffix="${3:-v2}"
  if [[ -n "$version" ]]; then
    local key_tail="${version}"
    if [[ "$suffix" != "none" ]]; then
      key_tail="${version}-${suffix}"
    fi
    cat > "$path" <<EOF
      - name: Cache Playwright browsers
        id: playwright_browsers_cache
        uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0
        with:
          path: ~/.cache/ms-playwright
          key: \${{ runner.os }}-playwright-chromium-webkit-${key_tail}
          restore-keys: \${{ runner.os }}-playwright-chromium-webkit-
EOF
  else
    cat > "$path" <<'EOF'
      - name: Some unrelated step
        run: echo "no playwright cache key here"
EOF
  fi
}

write_lockfile() {
  # $1 = path, $2 = version to embed (empty = omit the @playwright/test entry)
  local path="$1" version="$2"
  if [[ -n "$version" ]]; then
    cat > "$path" <<EOF
{
  "packages": {
    "node_modules/@playwright/test": {
      "version": "${version}",
      "resolved": "https://registry.npmjs.org/@playwright/test/-/test-${version}.tgz",
      "dev": true
    }
  }
}
EOF
  else
    cat > "$path" <<'EOF'
{
  "packages": {
    "node_modules/some-other-dep": {
      "version": "1.0.0"
    }
  }
}
EOF
  fi
}

# ---- Test A: matching fixture pair -> exit 0 ----------------------------
echo "Test A: matching versions -> exit 0, PASS line names both versions"

WF_A="${TMPDIR_ROOT}/ci-a.yml"
LF_A="${TMPDIR_ROOT}/package-lock-a.json"
write_workflow "$WF_A" "1.59.1"
write_lockfile "$LF_A" "1.59.1"

set +e
OUT_A="$(bash "$SCRIPT" --workflow "$WF_A" --lockfile "$LF_A" 2>&1)"
EXIT_A=$?
set -e

if [[ "$EXIT_A" -eq 0 ]]; then
  pass "Test A: guard exits 0 on matching fixtures"
else
  fail "Test A: guard exited ${EXIT_A} on matching fixtures; output: ${OUT_A}"
fi

if [[ "$OUT_A" == *"1.59.1"* && "$OUT_A" == *"PASS"* ]]; then
  pass "Test A: PASS line names the matching version"
else
  fail "Test A: PASS line missing or does not name 1.59.1; output: ${OUT_A}"
fi

# ---- Test B: mismatched versions -> exit 1 -------------------------------
echo "Test B: mismatched versions -> exit 1, FAIL line names both versions + both paths"

WF_B="${TMPDIR_ROOT}/ci-b.yml"
LF_B="${TMPDIR_ROOT}/package-lock-b.json"
write_workflow "$WF_B" "1.59.1"
write_lockfile "$LF_B" "1.60.0"

set +e
OUT_B="$(bash "$SCRIPT" --workflow "$WF_B" --lockfile "$LF_B" 2>&1)"
EXIT_B=$?
set -e

if [[ "$EXIT_B" -eq 1 ]]; then
  pass "Test B: guard exits 1 on mismatched versions"
else
  fail "Test B: guard exited ${EXIT_B} (expected 1) on mismatched versions; output: ${OUT_B}"
fi

if [[ "$OUT_B" == *"FAIL"* && "$OUT_B" == *"1.59.1"* && "$OUT_B" == *"1.60.0"* \
      && "$OUT_B" == *"$WF_B"* && "$OUT_B" == *"$LF_B"* ]]; then
  pass "Test B: FAIL line names both versions and both file paths"
else
  fail "Test B: FAIL line missing expected content; output: ${OUT_B}"
fi

# ---- Test C: no cache key in workflow at all -> exit 1 -------------------
echo "Test C: workflow fixture has no Playwright cache key -> exit 1 (not silently exempt)"

WF_C="${TMPDIR_ROOT}/ci-c.yml"
LF_C="${TMPDIR_ROOT}/package-lock-c.json"
write_workflow "$WF_C" ""
write_lockfile "$LF_C" "1.59.1"

set +e
OUT_C="$(bash "$SCRIPT" --workflow "$WF_C" --lockfile "$LF_C" 2>&1)"
EXIT_C=$?
set -e

if [[ "$EXIT_C" -eq 1 ]]; then
  pass "Test C: guard exits 1 when the workflow has no Playwright cache key"
else
  fail "Test C: guard exited ${EXIT_C} (expected 1) with no cache key present; output: ${OUT_C}"
fi

# ---- Test D: no @playwright/test entry in lockfile -> exit 1 -------------
echo "Test D: lockfile fixture has no @playwright/test entry -> exit 1"

WF_D="${TMPDIR_ROOT}/ci-d.yml"
LF_D="${TMPDIR_ROOT}/package-lock-d.json"
write_workflow "$WF_D" "1.59.1"
write_lockfile "$LF_D" ""

set +e
OUT_D="$(bash "$SCRIPT" --workflow "$WF_D" --lockfile "$LF_D" 2>&1)"
EXIT_D=$?
set -e

if [[ "$EXIT_D" -eq 1 ]]; then
  pass "Test D: guard exits 1 when the lockfile has no @playwright/test entry"
else
  fail "Test D: guard exited ${EXIT_D} (expected 1) with no lockfile entry; output: ${OUT_D}"
fi

# ---- Test E: unknown flag -> exit 2 --------------------------------------
echo "Test E: unknown flag -> exit 2 with an unknown-arg message on stderr"

set +e
OUT_E="$(bash "$SCRIPT" --bogus-flag 2>&1)"
EXIT_E=$?
set -e

if [[ "$EXIT_E" -eq 2 && "$OUT_E" == *"unknown arg"* ]]; then
  pass "Test E: guard exits 2 with an unknown-arg message on --bogus-flag"
else
  fail "Test E: guard exited ${EXIT_E} (expected 2) or missing unknown-arg message; output: ${OUT_E}"
fi

# ---- Test F: browser-set + version present but no -vN suffix -> exit 1 --
echo "Test F: no -vN suffix token at all -> exit 1 (generalizing -v1 to -vN did not make -vN optional)"

WF_F="${TMPDIR_ROOT}/ci-f.yml"
LF_F="${TMPDIR_ROOT}/package-lock-f.json"
write_workflow "$WF_F" "1.59.1" "none"
write_lockfile "$LF_F" "1.59.1"

set +e
OUT_F="$(bash "$SCRIPT" --workflow "$WF_F" --lockfile "$LF_F" 2>&1)"
EXIT_F=$?
set -e

if [[ "$EXIT_F" -eq 1 ]]; then
  pass "Test F: guard exits 1 when the workflow key has no -vN suffix token"
else
  fail "Test F: guard exited ${EXIT_F} (expected 1) with no -vN suffix present; output: ${OUT_F}"
fi

# ---- Summary -------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "playwright-cache-key-guard.test: FAIL"
  exit 1
fi

echo "playwright-cache-key-guard.test: PASS"
exit 0
