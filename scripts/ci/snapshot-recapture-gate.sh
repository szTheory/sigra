#!/usr/bin/env bash
# Phase 158 (ADMIN-UI-COHERENCE): automated stand-in for the human
# "review the Playwright HTML report before committing re-recorded baselines" gate.
#
# Run AFTER a deliberate `npx playwright test --update-snapshots` (and after
# restoring any non-intended PNGs). All-green == approval — no human review.
#
# Usage:
#   scripts/ci/snapshot-recapture-gate.sh <intended-slug> [<intended-slug> ...]
#
# Env:
#   SIGRA_EXAMPLE_URL   base URL of the booted example app (default http://localhost:4011)
#   RUN_PARITY=1        also run the admin-generated installer-parity lane (slow)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PW="${ROOT}/test/example/priv/playwright"
SIGRA_EXAMPLE_URL="${SIGRA_EXAMPLE_URL:-http://localhost:4011}"

if [[ $# -lt 1 ]]; then
  echo "snapshot-recapture-gate: FAIL: usage: $(basename "$0") <intended-slug>..." >&2
  exit 2
fi

declare -a ALLOW_ARGS=()
for s in "$@"; do
  ALLOW_ARGS+=(--allow "$s")
done

echo "snapshot-recapture-gate: (a) compare-mode admin checkpoints across 3 projects"
( cd "$PW" && CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" \
    npx playwright test tests/admin-checkpoints.spec.ts \
      --project=admin-checkpoints-chromium \
      --project=admin-checkpoints-mobile \
      --project=admin-checkpoints-dark )

echo "snapshot-recapture-gate: (b) drift/canary guard (only intended slugs changed, and all did)"
bash "${ROOT}/scripts/ci/snapshot-canary-guard.sh" --base HEAD --require-all "${ALLOW_ARGS[@]}"

echo "snapshot-recapture-gate: (c) ExUnit component byte-goldens"
( cd "$ROOT" && MIX_ENV=test mix test test/sigra/admin/components_test.exs )

if [[ "${RUN_PARITY:-0}" == "1" ]]; then
  echo "snapshot-recapture-gate: (d) admin-generated installer-parity lane"
  ( cd "$ROOT" && bash scripts/ci/admin-acceptance-smoke.sh )
else
  echo "snapshot-recapture-gate: (d) parity lane skipped (set RUN_PARITY=1 to include; verified in CI)"
fi

echo "snapshot-recapture-gate: PASS — all-green, recording approved (no human review needed)"
