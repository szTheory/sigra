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

# Route each intended slug to the lane(s) whose snapshot dir actually contains
# it. The checkpoint lane (step b) and design lane (step b2) keep DISJOINT
# snapshot dirs, and snapshot-canary-guard's --require-all demands every allowed
# slug changed IN THAT lane. Passing the same --allow set to both lanes (the old
# behavior) made single-lane recapture impossible — the opposite lane always
# failed --require-all. Glob the working tree (so newly-recorded, still-untracked
# PNGs route correctly too).
CK_SNAP_DIR="${PW}/tests/admin-checkpoints.spec.ts-snapshots"
DESIGN_SNAP_DIR="${PW}/tests/admin-design.spec.ts-snapshots"

declare -a CK_ALLOW=()
declare -a DESIGN_ALLOW=()
for s in "$@"; do
  matched=0
  ck_hits=("${CK_SNAP_DIR}/${s}"-admin-checkpoints-*.png)
  design_hits=("${DESIGN_SNAP_DIR}/${s}"-admin-design-*.png)
  if [[ -e "${ck_hits[0]}" ]]; then
    CK_ALLOW+=("$s")
    matched=1
  fi
  if [[ -e "${design_hits[0]}" ]]; then
    DESIGN_ALLOW+=("$s")
    matched=1
  fi
  if [[ "$matched" -eq 0 ]]; then
    echo "snapshot-recapture-gate: FAIL: intended slug '${s}' not found in either lane's snapshot dir" >&2
    echo "  checkpoint dir: ${CK_SNAP_DIR}" >&2
    echo "  design dir:     ${DESIGN_SNAP_DIR}" >&2
    exit 2
  fi
done

if [[ "${RECAPTURE_DRYRUN:-0}" == "1" ]]; then
  echo "snapshot-recapture-gate: DRYRUN — per-lane slug routing (no Playwright/mix run):"
  echo "  CK_ALLOW=${CK_ALLOW[*]:-(none)}"
  echo "  DESIGN_ALLOW=${DESIGN_ALLOW[*]:-(none)}"
  exit 0
fi

echo "snapshot-recapture-gate: (a) compare-mode admin checkpoints across 3 projects"
( cd "$PW" && CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" \
    npx playwright test tests/admin-checkpoints.spec.ts \
      --project=admin-checkpoints-chromium \
      --project=admin-checkpoints-mobile \
      --project=admin-checkpoints-dark )

echo "snapshot-recapture-gate: (b) drift/canary guard (only intended slugs changed, and all did)"
# --require-all only when this lane actually owns an intended slug; with none, the
# lane still runs its full drift/canary check (any unintended change still fails).
declare -a CK_GUARD_ARGS=(--base HEAD)
if [[ ${#CK_ALLOW[@]} -gt 0 ]]; then
  CK_GUARD_ARGS+=(--require-all)
  for s in "${CK_ALLOW[@]}"; do CK_GUARD_ARGS+=(--allow "$s"); done
fi
bash "${ROOT}/scripts/ci/snapshot-canary-guard.sh" "${CK_GUARD_ARGS[@]}"

echo "snapshot-recapture-gate: (a2) compare-mode admin design gallery across 3 projects"
( cd "$PW" && CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" \
    npx playwright test tests/admin-design.spec.ts \
      --project=admin-design-chromium \
      --project=admin-design-mobile \
      --project=admin-design-dark )

echo "snapshot-recapture-gate: (b2) drift/canary guard — design lane"
declare -a DESIGN_GUARD_ARGS=(--base HEAD --allowlist "${PW}/snapshot-allowlist-design" --canary board-notice)
if [[ ${#DESIGN_ALLOW[@]} -gt 0 ]]; then
  DESIGN_GUARD_ARGS+=(--require-all)
  for s in "${DESIGN_ALLOW[@]}"; do DESIGN_GUARD_ARGS+=(--allow "$s"); done
fi
SNAP_DIR="${DESIGN_SNAP_DIR}" \
  bash "${ROOT}/scripts/ci/snapshot-canary-guard.sh" "${DESIGN_GUARD_ARGS[@]}"

echo "snapshot-recapture-gate: (c) ExUnit component byte-goldens"
( cd "$ROOT" && MIX_ENV=test mix test test/sigra/admin/components_test.exs )

if [[ "${RUN_PARITY:-0}" == "1" ]]; then
  echo "snapshot-recapture-gate: (d) admin-generated installer-parity lane"
  ( cd "$ROOT" && bash scripts/ci/admin-acceptance-smoke.sh )
else
  echo "snapshot-recapture-gate: (d) parity lane skipped (set RUN_PARITY=1 to include; verified in CI)"
fi

echo "snapshot-recapture-gate: PASS — all-green, recording approved (no human review needed)"
