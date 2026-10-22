#!/usr/bin/env bash
# Phase 230 (FAST-06 / D-16, D-18): Playwright browser cache key version-drift guard.
#
# Contract: asserts the version embedded in .github/workflows/ci.yml's
# Playwright browser cache key (`playwright-chromium-webkit-<version>-vN`)
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
# Phase 231 (GATE-04 / C-6): the `-vN` suffix segment is a boundary marker
# the workflow re-tokens whenever the cached browser SET changes (-v1 -> -v2
# when admin_eval_render started needing webkit too, see ci.yml's Playwright
# browser cache comment). The extraction below matches ANY `-vN` token
# rather than hard-coding `-v1`, so a future re-token advances the marker
# without also silently turning this guard's "no cache key found" fail-closed
# path into a real failure over an unrelated-looking cause.
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
#   key: ${{ runner.os }}-playwright-chromium-webkit-1.59.1-v2
# Extract the literal version between the browser-set segment and the -vN
# suffix, where N is any version token (not hard-coded to -v1 -- see the
# Phase 231 / C-6 comment above). No fallback: if the pattern is absent,
# key_version stays empty and the guard below fails closed rather than
# silently passing.
key_version="$(grep -oE 'playwright-chromium-webkit-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+' "$WORKFLOW" \
  | head -1 \
  | sed -E 's/^playwright-chromium-webkit-([0-9]+\.[0-9]+\.[0-9]+)-v[0-9]+$/\1/')" || true
[[ -n "$key_version" ]] || fail "no Playwright browser cache key (playwright-chromium-webkit-<version>-vN) found in ${WORKFLOW}"

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

# Provenance (230-09, FAST-06 evidence capture): CI run 30412458437 is the
# cache-seeding run for AFTER-PR-WARM in 230-EVIDENCE.md. It saved the
# Playwright browser cache under key Linux-playwright-chromium-webkit-1.59.1-v1
# on 2026-07-29 (miss half of the FAST-06 pair). This comment is the one
# non-Markdown, non-.planning/ change carried by the commit that triggers the
# warm run observing the corresponding cache hit.
