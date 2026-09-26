#!/usr/bin/env bash
# Phase 244: validate every Chromium browser-cache family against the exact
# Playwright version locked for the example test tooling.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="${ROOT}/.github/workflows/ci.yml"
LOCKFILE="${ROOT}/test/example/priv/playwright/package-lock.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow) WORKFLOW="$2"; shift 2;;
    --lockfile) LOCKFILE="$2"; shift 2;;
    *) echo "playwright-cache-key-guard: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "playwright-cache-key-guard: FAIL: $*" >&2
  exit 1
}

[[ -f "$WORKFLOW" ]] || fail "workflow file not found: ${WORKFLOW}"
[[ -f "$LOCKFILE" ]] || fail "lockfile not found: ${LOCKFILE}"

key_lines="$(grep -oE 'playwright-chromium(-webkit)?-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+' "$WORKFLOW" || true)"
key_count="$(printf '%s\n' "$key_lines" | sed '/^$/d' | wc -l | tr -d ' ')"
[[ "$key_count" -eq 5 ]] || fail "expected all 5 Playwright cache keys, found ${key_count} in ${WORKFLOW}"

chromium_count=0
webkit_count=0
while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  if [[ "$key" =~ ^playwright-chromium-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+$ ]]; then
    chromium_count=$((chromium_count + 1))
  elif [[ "$key" =~ ^playwright-chromium-webkit-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+$ ]]; then
    webkit_count=$((webkit_count + 1))
  else
    fail "unrecognized Playwright cache key: ${key}"
  fi
done <<< "$key_lines"
[[ "$chromium_count" -gt 0 ]] || fail "missing chromium-only cache-key family in ${WORKFLOW}"
[[ "$webkit_count" -gt 0 ]] || fail "missing chromium-webkit cache-key family in ${WORKFLOW}"

lockfile_version="$(node -e 'const l=require(process.argv[1]); const p=l.packages?.["node_modules/@playwright/test"]; if(p) process.stdout.write(p.version);' "$LOCKFILE")"
[[ "$lockfile_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "no valid node_modules/@playwright/test version found in ${LOCKFILE}"

while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  key_version="${key#playwright-chromium-}"
  key_version="${key_version#webkit-}"
  key_version="${key_version%-v*}"
  [[ "$key_version" == "$lockfile_version" ]] || fail "cache key ${key} (${WORKFLOW}) != lockfile @playwright/test version ${lockfile_version} (${LOCKFILE})"
done <<< "$key_lines"

echo "playwright-cache-key-guard: PASS (${key_count} keys: ${chromium_count} chromium, ${webkit_count} chromium-webkit; all match ${lockfile_version})"
