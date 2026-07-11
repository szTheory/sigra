#!/usr/bin/env bash
# scripts/ci/upgrade-smoke.test.sh
#
# Offline self-test for scripts/ci/lib/resolve-sigra-source.sh (HARD-01 /
# Phase 222). Proves the resolver durably excludes the immutable Hex stray
# `1.20.0` and never depends on a hand-maintained per-release version floor.
# Runs fully hermetic via a stub `mix` on PATH that echoes a canned
# `mix hex.info sigra` "Recent releases" block — no network call.
#
# Test cases:
#   A: default exclusion (1.20.0) — resolver selects the real GA 1.3.0, never
#      the numerically higher-sorting stray.
#   B: comma-configurable exclusion list — SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS
#      "1.20.0,1.3.0" selects the next real release, 1.2.0.
#   C: empty candidate set after exclusion fails closed (non-zero exit, FAIL
#      message) rather than silently picking nothing.
#   D: SOURCE_SERIES=0.3 still selects within the 0.3 series — the series
#      regex is unaffected by the exclusion.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="${SCRIPT_DIR}/lib/resolve-sigra-source.sh"

if [[ ! -f "$RESOLVER" ]]; then
  echo "FATAL: resolver lib not found at ${RESOLVER}" >&2
  exit 2
fi

# shellcheck source=scripts/ci/lib/resolve-sigra-source.sh
source "$RESOLVER"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

STUB_BIN_DIR=""
# shellcheck disable=SC2329 # invoked indirectly via `trap ... EXIT` below
cleanup() {
  if [[ -n "$STUB_BIN_DIR" && -d "$STUB_BIN_DIR" ]]; then
    rm -rf "$STUB_BIN_DIR"
  fi
}
trap cleanup EXIT

STUB_BIN_DIR="$(mktemp -d)"
cat >"${STUB_BIN_DIR}/mix" <<'STUB'
#!/usr/bin/env bash
# Stub for `mix hex.info sigra` — canned "Recent releases" block covering the
# live immutable stray (1.20.0), the real 1.x GA series, and a 0.3.x series
# for the series-regex case (D). Matches the live-verified format from
# 222-RESEARCH.md Finding 1: two-space-indented "X.Y.Z (date)" lines.
cat <<'RELEASES'
sigra
  Repo: https://github.com/szTheory/sigra

Config: {:sigra, "~> 1.20"}

Releases:
  Recent releases:
  1.20.0 (2026-04-28)
  1.3.0 (2026-07-10)
  1.2.0 (2026-07-10)
  1.1.0 (2026-06-13)
  1.0.0 (2026-06-03)
  0.3.5 (2026-01-01)
  0.3.2 (2025-12-01)
  0.2.9 (2025-11-01)
RELEASES
STUB
chmod +x "${STUB_BIN_DIR}/mix"
export PATH="${STUB_BIN_DIR}:${PATH}"

# ---- Test A: default exclusion selects the real GA, not the stray -------
echo "Test A: default exclusion (1.20.0) selects real GA 1.3.0, not the stray"

unset SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS 2>/dev/null || true
SOURCE_SERIES="1"
RESULT_A="$(resolve_latest_sigra_source)"

if [[ "$RESULT_A" == "1.3.0" ]]; then
  pass "Test A: resolver selected 1.3.0 (never the stray 1.20.0)"
else
  fail "Test A: resolver selected '${RESULT_A}', expected 1.3.0"
fi

# ---- Test B: comma-configurable exclusion list --------------------------
echo "Test B: comma-configurable exclusion list"

SOURCE_SERIES="1"
SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS="1.20.0,1.3.0"
RESULT_B="$(resolve_latest_sigra_source)"
unset SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS

if [[ "$RESULT_B" == "1.2.0" ]]; then
  pass "Test B: resolver selected 1.2.0 after excluding 1.20.0 and 1.3.0"
else
  fail "Test B: resolver selected '${RESULT_B}', expected 1.2.0"
fi

# ---- Test C: empty candidate set after exclusion fails closed -----------
echo "Test C: empty candidate set after exclusion fails closed"

SOURCE_SERIES="1"
SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS="1.20.0,1.3.0,1.2.0,1.1.0,1.0.0"
set +e
OUTPUT_C="$(resolve_latest_sigra_source 2>&1)"
EXIT_C=$?
set -e
unset SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS

if [[ "$EXIT_C" -ne 0 ]] && printf '%s' "$OUTPUT_C" | grep -q "FAIL:"; then
  pass "Test C: resolver fails closed (exit ${EXIT_C}) with a FAIL message on empty candidates"
else
  fail "Test C: resolver did not fail closed (exit ${EXIT_C}); output: ${OUTPUT_C}"
fi

# ---- Test D: series regex is unaffected by the exclusion ----------------
echo "Test D: SOURCE_SERIES=0.3 still selects within the 0.3 series"

SOURCE_SERIES="0.3"
RESULT_D="$(resolve_latest_sigra_source)"

if [[ "$RESULT_D" == "0.3.5" ]]; then
  pass "Test D: resolver selected 0.3.5 within the configured 0.3 series"
else
  fail "Test D: resolver selected '${RESULT_D}', expected 0.3.5"
fi

# ---- Summary -------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "upgrade-smoke.test: FAIL"
  exit 1
fi

echo "upgrade-smoke.test: PASS"
exit 0
