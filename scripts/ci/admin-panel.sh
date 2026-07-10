#!/usr/bin/env bash
# admin-panel.sh — off-CI operator entrypoint for the LLM panel judge (Phase 217, Plan 07).
#
# Fronts `scripts/panel/judge.mjs` with:
#   (a) Hammer no-op: HARD-DEGRADES to exit 0 when ANTHROPIC_API_KEY is unset.
#       This is the structural JUDGE-CI-01 guarantee — a missing key can only ever pass.
#       The warning names the env var but NEVER echoes its value.
#   (b) Bundle-freshness precondition: warn/skip (not hard-fail) if bundles are stale
#       vs HEAD — do not burn API tokens on a stale render (T-217-07-STALE).
#   (c) Pilot-surface default: runs only the two pilot surfaces unless --all is passed.
#       Prints an estimated API call count BEFORE making any calls.
#   (d) Never writes any git-tracked ledger that the deterministic guards read.
#       It invokes judge.mjs, which writes only:
#         - panel-findings.json   (gitignored — parallel to findings.json)
#         - admin-panel-verdicts.json  (committed cache, keyed on render_sha256)
#
# PROHIBITIONS (do not remove or weaken):
#   - JUDGE-CI-01: This script must NEVER be wired into any CI lane.
#   - Key safety: ANTHROPIC_API_KEY must never be echoed, logged, or committed.
#   - Ledger safety: must never write findings.json, admin-render-sha.json, or
#     any other file read by the deterministic merge-gating guards.
#
# Usage:
#   ANTHROPIC_API_KEY=... bash scripts/ci/admin-panel.sh [--all] [--dry-run]
#
# Options:
#   --all       Fan out to all surfaces (not just the two pilot surfaces).
#               Prints estimated call count first.
#   --dry-run   Print what would be run (cells + estimated calls) without running.
#
# Prerequisites:
#   - ANTHROPIC_API_KEY set in the environment (no-op skip if unset)
#   - Bundles captured at HEAD via admin-eval-harness.sh (freshness guard will warn if not)
#   - node + scripts/panel/judge.mjs dependencies installed
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JUDGE="${ROOT}/scripts/panel/judge.mjs"
RENDER_SHA_PATH="${ROOT}/guides/reference/admin-render-sha.json"
VERDICTS_PATH="${ROOT}/guides/reference/admin-panel-verdicts.json"
PW_EVAL="${ROOT}/test/example/priv/playwright/eval"

# ── Hammer no-op (JUDGE-CI-01 structural guarantee) ─────────────────────────
# A missing ANTHROPIC_API_KEY hard-degrades to exit 0 (skip-with-warning).
# This means a script wired into CI without a key can only ever PASS, never FAIL —
# it is structurally impossible for this script to block a merge via a spurious error.
# The warning names the env var by name only — never echoes its value (T-217-07-KEY).
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "admin-panel: ANTHROPIC_API_KEY not set — skipping LLM panel (JUDGE-CI-01 no-op pass)" >&2
  echo "admin-panel: To run the panel, export ANTHROPIC_API_KEY=<your-key> and re-run." >&2
  exit 0
fi

# ── Parse flags ─────────────────────────────────────────────────────────────
FAN_OUT_ALL=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --all)      FAN_OUT_ALL=true ;;
    --dry-run)  DRY_RUN=true ;;
    *)          echo "admin-panel: unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# ── Resolve HEAD SHA ─────────────────────────────────────────────────────────
app_git_sha="$(git -C "$ROOT" rev-parse HEAD)"
echo "admin-panel: app_git_sha = ${app_git_sha}"

# ── Bundle-freshness precondition (T-217-07-STALE) ──────────────────────────
# Warn/skip if bundles are stale vs HEAD — do not burn API tokens on a stale render.
# Stale = no bundle.json found for the current HEAD sha.
BUNDLE_BASE="${PW_EVAL}/${app_git_sha}"
BUNDLES_STALE=false

if [ ! -d "$BUNDLE_BASE" ]; then
  echo "admin-panel: WARNING — no bundles found for HEAD ${app_git_sha}" >&2
  echo "admin-panel: Run admin-eval-harness.sh first to capture fresh bundles." >&2
  BUNDLES_STALE=true
fi

if [ "$BUNDLES_STALE" = "true" ]; then
  echo "admin-panel: SKIP — stale bundles; no API calls made. Re-run after admin-eval-harness.sh." >&2
  exit 0
fi

# ── Surface enumeration ──────────────────────────────────────────────────────
# Pilot surfaces (two highest-priority, per Phase-217 design — avoids full fan-out cost).
# --all fans out to every surface in admin-render-sha.json.
PILOT_SURFACES=("board-mg-5-populated" "board-mg-5-zero" "board-mg-5-loading" "board-mg-5-error" "board-mg-9-populated" "board-mg-9-zero" "board-mg-9-loading" "board-mg-9-error")

if [ "$FAN_OUT_ALL" = "true" ]; then
  # Read all surfaces from admin-render-sha.json
  if [ ! -f "$RENDER_SHA_PATH" ]; then
    echo "admin-panel: ERROR — $RENDER_SHA_PATH not found" >&2
    exit 1
  fi
  mapfile -t SURFACES < <(
    node -e "
      const data = JSON.parse(require('fs').readFileSync('$RENDER_SHA_PATH','utf8'));
      Object.keys(data.cells || {}).forEach(s => console.log(s));
    "
  )
else
  SURFACES=("${PILOT_SURFACES[@]}")
fi

echo "admin-panel: surfaces to judge: ${SURFACES[*]}"

# ── Cell enumeration ─────────────────────────────────────────────────────────
# For each surface, read cells from admin-render-sha.json.
# Only include cells that have a render_sha256 (i.e., bundles were captured).
declare -a CELLS_TO_RUN=()

for surface in "${SURFACES[@]}"; do
  if [ ! -f "$RENDER_SHA_PATH" ]; then
    echo "admin-panel: WARNING — render-sha.json not found; skipping surface ${surface}" >&2
    continue
  fi

  mapfile -t surface_cells < <(
    node -e "
      const data = JSON.parse(require('fs').readFileSync('$RENDER_SHA_PATH','utf8'));
      const cells = data.cells?.['$surface'] || {};
      Object.entries(cells).forEach(([cell, info]) => {
        if (info.render_sha256) console.log('$surface|' + cell + '|' + info.render_sha256);
      });
    " 2>/dev/null || true
  )

  for entry in "${surface_cells[@]:-}"; do
    [ -z "$entry" ] && continue
    CELLS_TO_RUN+=("$entry")
  done
done

if [ "${#CELLS_TO_RUN[@]}" -eq 0 ]; then
  echo "admin-panel: no cells with render_sha256 found — nothing to judge" >&2
  echo "admin-panel: Run admin-eval-harness.sh first to populate render_sha256." >&2
  exit 0
fi

# ── Estimated call count (K=3 per cache-miss cell) ───────────────────────────
# Print BEFORE making any API calls so the operator can abort if needed.
# A cell with a matching content-hash in admin-panel-verdicts.json costs 0 calls (SC-2).
K=3
CACHED_COUNT=0
MISS_COUNT=0

for entry in "${CELLS_TO_RUN[@]}"; do
  render_sha="${entry##*|}"
  # Check verdicts cache
  is_cached=$(
    node -e "
      const fs = require('fs');
      const path = '$VERDICTS_PATH';
      const sha = '$render_sha';
      if (!fs.existsSync(path)) { console.log('miss'); process.exit(0); }
      const v = JSON.parse(fs.readFileSync(path,'utf8'));
      const entry = v?.cells?.[sha];
      if (!entry) { console.log('miss'); process.exit(0); }
      // Check provenance — model, k, quorum, rubric_version, prompt_sha
      const prov = entry.provenance || {};
      if (prov.model === 'claude-opus-4-8' && prov.k === $K && prov.quorum === 2) {
        console.log('hit');
      } else {
        console.log('miss');
      }
    " 2>/dev/null || echo "miss"
  )

  if [ "$is_cached" = "hit" ]; then
    ((CACHED_COUNT++)) || true
  else
    ((MISS_COUNT++)) || true
  fi
done

ESTIMATED_CALLS=$((MISS_COUNT * K))
TOTAL_CELLS=${#CELLS_TO_RUN[@]}

echo "admin-panel: ${TOTAL_CELLS} cells | ${CACHED_COUNT} cache-hits (0 calls) | ${MISS_COUNT} cache-misses (${ESTIMATED_CALLS} estimated API calls)"

if [ "$DRY_RUN" = "true" ]; then
  echo "admin-panel: --dry-run: no API calls made"
  echo "admin-panel: cells that would be judged:"
  for entry in "${CELLS_TO_RUN[@]}"; do
    surface="${entry%%|*}"
    rest="${entry#*|}"
    cell="${rest%%|*}"
    echo "  ${surface}/${cell}"
  done
  exit 0
fi

if [ "$ESTIMATED_CALLS" -gt 0 ]; then
  echo "admin-panel: estimated ${ESTIMATED_CALLS} API calls (K=${K} per cache-miss cell)"
  echo "admin-panel: proceeding with panel run..."
fi

# ── Run judge.mjs for each cell ──────────────────────────────────────────────
PASS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for entry in "${CELLS_TO_RUN[@]}"; do
  surface="${entry%%|*}"
  rest="${entry#*|}"
  cell="${rest%%|*}"
  render_sha="${entry##*|}"

  # Bundle output directory for this cell
  OUTPUT_DIR="${BUNDLE_BASE}/${surface}/${cell}"

  echo "admin-panel: judging ${surface}/${cell} (render_sha=${render_sha:0:12}...)"

  if node "$JUDGE" \
      --surface "$surface" \
      --cell "$cell" \
      --render-sha "$render_sha" \
      --output-dir "$OUTPUT_DIR" 2>&1; then
    ((PASS_COUNT++)) || true
  else
    exit_code=$?
    echo "admin-panel: judge.mjs exited ${exit_code} for ${surface}/${cell}" >&2
    ((FAIL_COUNT++)) || true
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "admin-panel: DONE — ${PASS_COUNT} passed, ${SKIP_COUNT} skipped, ${FAIL_COUNT} failed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "admin-panel: ${FAIL_COUNT} cells failed — check judge.mjs output above" >&2
  exit 1
fi

echo "admin-panel: verdicts written to ${VERDICTS_PATH} (committed; run \`git diff\` to review)"
echo "admin-panel: panel-findings.json written per-cell under ${BUNDLE_BASE}/ (gitignored)"
exit 0
