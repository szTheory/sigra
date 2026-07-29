#!/usr/bin/env bash
# Phase 230 (FAST-06 / D-16, D-18): Playwright browser cache key version-drift guard.
#
# Contract: asserts the version embedded in .github/workflows/ci.yml's
# Playwright browser cache key (`playwright-chromium-webkit-<version>-v1`)
# equals the resolved `@playwright/test` version in
# test/example/priv/playwright/package-lock.json. package.json declares
# "@playwright/test": "^1.48.0" while the lockfile currently resolves
# 1.59.1 -- a literal version in the cache key means a future lockfile bump
# can leave the workflow key unchanged, an exact cache-hit then restores the
# OLD browser revision directory, the hit branch skips the full install, and
# Playwright fails at test time with a missing-executable error. This guard
# is what makes that failure loud in fast_checks instead of silent inside a
# passing example_playwright_smoke run.
#
# Does NOT cover: the browser set ("chromium-webkit") encoded in the same
# key. That is D-16's concern, asserted structurally by plan 06 Task 1's
# ci.yml verify block (a single-occurrence grep), not by this script.
#
# Consumer: fast_checks (every PR and push).
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

# The cache key line has the shape:
#   key: ${{ runner.os }}-playwright-chromium-webkit-1.59.1-v1
# Extract the literal version between the browser-set segment and the -v1
# suffix. No fallback: if the pattern is absent, key_version stays empty and
# the guard below fails closed rather than silently passing.
key_version="$(grep -oE 'playwright-chromium-webkit-[0-9]+\.[0-9]+\.[0-9]+-v1' "$WORKFLOW" \
  | head -1 \
  | sed -E 's/^playwright-chromium-webkit-([0-9]+\.[0-9]+\.[0-9]+)-v1$/\1/')" || true
[[ -n "$key_version" ]] || fail "no Playwright browser cache key (playwright-chromium-webkit-<version>-v1) found in ${WORKFLOW}"

# The lockfile entry has the shape:
#   "node_modules/@playwright/test": {
#     "version": "1.59.1",
#     ...
# "version" is always the first field after the block opens, so scanning
# two lines past the header is sufficient and does not depend on a JSON
# parser being installed.
lockfile_version="$(grep -A 2 '"node_modules/@playwright/test": {' "$LOCKFILE" \
  | grep -m1 '"version"' \
  | sed -E 's/.*"version": *"([^"]+)".*/\1/')" || true
[[ -n "$lockfile_version" ]] || fail "no node_modules/@playwright/test entry found in ${LOCKFILE}"

[[ "$key_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "workflow cache key version '${key_version}' (from ${WORKFLOW}) is not a valid semver shape"
[[ "$lockfile_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "lockfile @playwright/test version '${lockfile_version}' (from ${LOCKFILE}) is not a valid semver shape"

if [[ "$key_version" != "$lockfile_version" ]]; then
  fail "cache key version ${key_version} (${WORKFLOW}) != lockfile @playwright/test version ${lockfile_version} (${LOCKFILE})"
fi

echo "playwright-cache-key-guard: PASS (key version ${key_version} matches lockfile ${lockfile_version})"
