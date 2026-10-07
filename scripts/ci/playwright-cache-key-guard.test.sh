#!/usr/bin/env bash
# Hermetic contract tests for both Playwright browser cache-key families.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/playwright-cache-key-guard.sh"
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

write_workflow() {
  local path="$1" chromium="${2:-1.62.1}" webkit="${3:-1.62.1}" suffix="${4:-v3}"
  : > "$path"
  if [[ "$chromium" != none ]]; then
    printf '%s\n' \
      "browser_cache_key: playwright-chromium-${chromium}-${suffix}" \
      "browser_cache_key: playwright-chromium-${chromium}-${suffix}" >> "$path"
  fi
  if [[ "$webkit" != none ]]; then
    printf '%s\n' \
      "browser_cache_key: playwright-chromium-webkit-${webkit}-${suffix}" \
      "browser_cache_key: playwright-chromium-webkit-${webkit}-${suffix}" \
      "browser_cache_key: playwright-chromium-webkit-${webkit}-${suffix}" >> "$path"
  fi
}

write_lockfile() {
  local path="$1" version="${2:-1.62.1}"
  if [[ "$version" == none ]]; then
    printf '{"packages":{"node_modules/other":{"version":"1.0.0"}}}\n' > "$path"
  else
    printf '{"packages":{"node_modules/@playwright/test":{"version":"%s"}}}\n' "$version" > "$path"
  fi
}

run_guard() { bash "$SCRIPT" --workflow "$1" --lockfile "$2"; }

# A: every cache key in both browser-set families agrees with the lock.
WF="$TMPDIR_ROOT/all.yml"; LF="$TMPDIR_ROOT/all-lock.json"
write_workflow "$WF"; write_lockfile "$LF"
if OUT="$(run_guard "$WF" "$LF" 2>&1)"; then
  [[ "$OUT" == *'5 keys: 2 chromium, 3 chromium-webkit'* && "$OUT" == *'1.62.1'* ]] && pass 'all five cache keys agree' || fail "unexpected success output: $OUT"
else fail "matching fixtures rejected: $OUT"; fi

# B/C: stale chromium-only or chromium-webkit variants fail independently.
for FAMILY in chromium webkit; do
  WF="$TMPDIR_ROOT/stale-${FAMILY}.yml"
  if [[ "$FAMILY" == chromium ]]; then write_workflow "$WF" 1.59.1 1.62.1; else write_workflow "$WF" 1.62.1 1.59.1; fi
  if OUT="$(run_guard "$WF" "$LF" 2>&1)"; then fail "stale ${FAMILY} family passed"; else [[ "$OUT" == *'!= lockfile'* ]] && pass "stale ${FAMILY} family fails" || fail "wrong stale ${FAMILY} diagnostic: $OUT"; fi
done

# D/E: either missing browser-set family fails closed.
for FAMILY in chromium webkit; do
  WF="$TMPDIR_ROOT/missing-${FAMILY}.yml"
  if [[ "$FAMILY" == chromium ]]; then write_workflow "$WF" none 1.62.1; else write_workflow "$WF" 1.62.1 none; fi
  if OUT="$(run_guard "$WF" "$LF" 2>&1)"; then fail "missing ${FAMILY} family passed"; else [[ "$OUT" == *'expected all 5'* ]] && pass "missing ${FAMILY} family fails" || fail "wrong missing ${FAMILY} diagnostic: $OUT"; fi
done

# F: cache version with no -vN token is not accepted.
WF="$TMPDIR_ROOT/no-suffix.yml"; write_workflow "$WF" 1.62.1 1.62.1 none
if OUT="$(run_guard "$WF" "$LF" 2>&1)"; then fail 'missing suffix passed'; else pass 'missing suffix rejected'; fi

# G: missing lock entry and unknown option remain errors.
write_lockfile "$TMPDIR_ROOT/no-lock.json" none
if OUT="$(run_guard "$TMPDIR_ROOT/all.yml" "$TMPDIR_ROOT/no-lock.json" 2>&1)"; then fail 'missing lock entry passed'; else [[ "$OUT" == *'no valid'* ]] && pass 'missing lock entry rejected' || fail "wrong lock diagnostic: $OUT"; fi
if OUT="$(bash "$SCRIPT" --unknown 2>&1)"; then fail 'unknown argument passed'; else [[ "$OUT" == *'unknown arg'* ]] && pass 'unknown argument rejected' || fail "wrong argument diagnostic: $OUT"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
echo 'playwright-cache-key-guard.test: PASS'
