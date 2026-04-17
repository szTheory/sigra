#!/usr/bin/env bash
# Phase 35 / ROADMAP SC6: assert curated admin checkpoint PNG bundle size/count.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="${1:-${ROOT}/test/example/priv/playwright/artifacts/admin-checkpoints}"
MIN_BYTES="${MIN_BYTES:-5000}"
MIN_COUNT="${MIN_COUNT:-15}"

fail() {
  echo "admin-artifact-bundle-contract: FAIL: $*" >&2
  exit 1
}

if [[ ! -d "${ARTIFACT_ROOT}" ]]; then
  fail "artifact root missing: ${ARTIFACT_ROOT}"
fi

mapfile -t pngs < <(find "${ARTIFACT_ROOT}" -type f -name '*.png' 2>/dev/null || true)
count="${#pngs[@]}"

if ((count < MIN_COUNT)); then
  fail "expected at least ${MIN_COUNT} PNG files under ${ARTIFACT_ROOT}, found ${count}"
fi

bad_sizes=()
for f in "${pngs[@]}"; do
  sz="$(wc -c <"${f}" | tr -d ' ')"
  if ((sz < MIN_BYTES)); then
    bad_sizes+=("${f} (${sz} bytes < ${MIN_BYTES})")
  fi
done

if ((${#bad_sizes[@]} > 0)); then
  fail "PNG size check failed: ${bad_sizes[*]}"
fi

echo "OK: admin-artifact-bundle-contract (${count} PNGs, each >= ${MIN_BYTES} bytes)"
