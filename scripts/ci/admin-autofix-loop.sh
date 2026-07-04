#!/usr/bin/env bash
# admin-autofix-loop.sh — apply auto_eligible fix-queue entries as atomic commits,
# re-render after each, and auto-revert via `git revert` if any of FOUR rails trips.
#
# Plan 217-06, D-14 (plus RESEARCH.md Open Question #1 resolved as rail 4).
#
# SAFETY RULESET (CRITICAL — do not bypass):
#   (1) One fix per commit (git add -A && git commit).
#   (2) Auto-revert via `git revert --no-edit HEAD` (a NEW commit — NEVER reset/force-push).
#   (3) LLM strictly OUT of the apply path — fix-apply.mjs is deterministic arithmetic/ruleset only.
#   (4) CSS files are out of scope — fix-apply.mjs enforces the apply surface boundary.
#   (5) This script must NEVER be wired into any CI lane — it is an operator/nightly tool.
#   (6) eval/autofix-state.json is gitignored — persisted poison-set for never-retry.
#
# FOUR RAILS (any one trips → git revert + waive + poison):
#   Rail 1: quality-findings-monotonic.sh count increased vs pre-loop sha.
#   Rail 2: award-guard.mjs min(axes) decreased vs pre-loop admin-award-ledger.json snapshot.
#   Rail 3: any deterministic gate flip / anchor resolution failure (harness non-zero exit).
#   Rail 4: committed baseline PNG drift vs pre-loop sha (snapshot-canary-guard.sh --base <pre-loop-sha>).
#
# Usage:
#   bash scripts/ci/admin-autofix-loop.sh [--max-fixes N] [--dry-run] [--queue PATH]
#
# Options:
#   --max-fixes N     Maximum number of fixes to attempt per run (default: 5).
#   --dry-run         Simulate without committing or reverting.
#   --queue PATH      Path to fix-queue.json (default: guides/reference/fix-queue.json).
#   --target-file MAP File mapping from surface → heex file path (JSON, optional).
#                     When absent, the loop maps surface names to known admin LiveView files.
#
# State files:
#   eval/autofix-state.json  — persisted poison-set + loop resume state (gitignored).
#   SIGRA_EXAMPLE_URL must be set if admin-eval-harness.sh needs a running server.
#
# Prerequisites:
#   - git (with user.email/user.name configured)
#   - node (for fix-apply.mjs, award-guard.mjs, fix-queue-build.mjs)
#   - admin-eval-harness.sh dependencies (if re-render is not skipped)
#   - A booted example app at SIGRA_EXAMPLE_URL (if re-render is enabled)
#
# DO NOT WIRE THIS SCRIPT INTO ANY CI LANE.
set -euo pipefail

# --------------------------------------------------------------------------
# Repo root
# --------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
MAX_FIXES=5
DRY_RUN=0
QUEUE_PATH="${ROOT}/guides/reference/fix-queue.json"
SKIP_RENDER=0  # Set to 1 in test environments (test double injects counts directly)

# --------------------------------------------------------------------------
# Arg parse
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-fixes)  MAX_FIXES="$2";      shift 2;;
    --dry-run)    DRY_RUN=1;           shift;;
    --queue)      QUEUE_PATH="$2";     shift 2;;
    --skip-render) SKIP_RENDER=1;      shift;;
    *) echo "admin-autofix-loop: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

# --------------------------------------------------------------------------
# State file (gitignored — see .gitignore)
# --------------------------------------------------------------------------
STATE_DIR="${ROOT}/eval"
STATE_FILE="${STATE_DIR}/autofix-state.json"

mkdir -p "$STATE_DIR"

# Load or initialize state
if [[ -f "$STATE_FILE" ]]; then
  POISON_IDS=$(node -e "
    const fs = require('fs');
    const s = JSON.parse(fs.readFileSync('${STATE_FILE}', 'utf8'));
    const p = s.poison_set || [];
    console.log(JSON.stringify(p));
  ")
else
  POISON_IDS='[]'
  node -e "
    const fs = require('fs');
    fs.writeFileSync('${STATE_FILE}', JSON.stringify({
      schema_version: 1,
      note: 'Persisted poison-set for admin-autofix-loop. Never retry these finding_ids.',
      poison_set: [],
      last_run: null,
    }, null, 2) + '\n');
  "
fi

# --------------------------------------------------------------------------
# Helper: add finding to poison-set + settled-findings.tsv
# --------------------------------------------------------------------------
add_to_poison() {
  local finding_id="$1"
  local surface="$2"
  local fix_class="$3"
  local anchor="$4"
  local reason="$5"

  # Update poison-set in state file
  node -e "
    const fs = require('fs');
    const p = '${STATE_FILE}';
    const s = JSON.parse(fs.readFileSync(p, 'utf8'));
    if (!s.poison_set.includes('${finding_id}')) {
      s.poison_set.push('${finding_id}');
    }
    s.last_run = new Date().toISOString();
    fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
  "

  # Add to settled-findings.tsv (disposition=waived, waived_by=autofix-217)
  # Guard against duplicate (settled-findings-lint.sh --add will fail on dup; catch it)
  set +e
  bash "${ROOT}/scripts/ci/settled-findings-lint.sh" --add "${finding_id}" \
    --surface "${surface}" \
    --class "${fix_class}" \
    --anchor "${anchor}" \
    --disposition waived \
    --waived-by autofix-217 \
    --note "rail-revert: ${reason}" 2>/dev/null
  local add_exit=$?
  set -e
  if [[ $add_exit -ne 0 ]]; then
    echo "admin-autofix-loop: INFO: finding ${finding_id} may already be in settled-findings.tsv (skipping duplicate add)"
  fi
}

# --------------------------------------------------------------------------
# Helper: load fix-queue and filter eligible entries (not in poison-set)
# --------------------------------------------------------------------------
load_eligible() {
  node -e "
    const fs = require('fs');
    const queue = JSON.parse(fs.readFileSync('${QUEUE_PATH}', 'utf8'));
    const poisonIds = new Set(${POISON_IDS});
    const eligible = queue
      .filter(f => f.auto_eligible && !poisonIds.has(f.finding_id))
      .sort((a, b) => {
        // Highest priority first: systemic before normal, then by finding_id for determinism
        const pOrder = { systemic: 0, high: 1, normal: 2 };
        const pa = pOrder[a.priority] ?? 99;
        const pb = pOrder[b.priority] ?? 99;
        if (pa !== pb) return pa - pb;
        return a.finding_id.localeCompare(b.finding_id);
      })
      .slice(0, ${MAX_FIXES});
    console.log(JSON.stringify(eligible));
  "
}

# --------------------------------------------------------------------------
# Helper: surface name → target file path heuristic
# Map board-mg-N-state → design_gallery_live.ex (the test fixture surface);
# all other admin surfaces → known LiveView files.
# --------------------------------------------------------------------------
surface_to_file() {
  local surface="$1"
  # All board-mg-* and board-cfg-* surfaces are rendered by design_gallery_live.ex
  if [[ "$surface" =~ ^board- ]]; then
    echo "${ROOT}/test/example/lib/example_web/live/admin/design_gallery_live.ex"
    return
  fi
  # Known admin LiveViews (surface name maps to snake_case .ex file)
  case "$surface" in
    users-index-live)    echo "${ROOT}/lib/sigra_web/live/admin/users_index_live.ex";;
    user-show-live)      echo "${ROOT}/lib/sigra_web/live/admin/user_show_live.ex";;
    user-sessions-live)  echo "${ROOT}/lib/sigra_web/live/admin/user_sessions_live.ex";;
    audit-index-live)    echo "${ROOT}/lib/sigra_web/live/admin/audit_index_live.ex";;
    audit-user-live)     echo "${ROOT}/lib/sigra_web/live/admin/audit_user_live.ex";;
    org-overview-live)   echo "${ROOT}/lib/sigra_web/live/admin/org_overview_live.ex";;
    branding-live)       echo "${ROOT}/lib/sigra_web/live/admin/branding_live.ex";;
    *)
      echo "";;
  esac
}

# --------------------------------------------------------------------------
# Pre-loop: snapshot pre-loop sha + ledger copy
# --------------------------------------------------------------------------
PRE_LOOP_SHA=$(git -C "$ROOT" rev-parse HEAD)
PRE_LOOP_LEDGER_JSON=$(cat "${ROOT}/guides/reference/admin-award-ledger.json" 2>/dev/null || echo '{}')
PRE_LOOP_FINDINGS_JSON=$(cat "${ROOT}/guides/reference/admin-render-sha.json" 2>/dev/null || echo '{}')

echo "admin-autofix-loop: START — pre-loop sha=${PRE_LOOP_SHA}, max-fixes=${MAX_FIXES}, dry-run=${DRY_RUN}"
echo "admin-autofix-loop: queue=${QUEUE_PATH}"

# --------------------------------------------------------------------------
# Helper: run rail checks after a fix commit
# Returns 0 if ALL rails pass, 1 if any rail trips.
# Sets TRIPPED_RAIL variable on failure.
# --------------------------------------------------------------------------
TRIPPED_RAIL=""

check_rails() {
  local commit_sha="$1"
  TRIPPED_RAIL=""

  # Rail 1: quality-findings-monotonic.sh — count must not increase vs pre-loop sha
  set +e
  RAIL1_OUT=$(bash "${ROOT}/scripts/ci/quality-findings-monotonic.sh" --base "${PRE_LOOP_SHA}" 2>&1)
  RAIL1_EXIT=$?
  set -e
  if [[ $RAIL1_EXIT -ne 0 ]]; then
    TRIPPED_RAIL="rail-1-monotonic: ${RAIL1_OUT}"
    return 1
  fi

  # Rail 2: award-guard.mjs min(axes) — must not decrease vs pre-loop snapshot
  # Write the pre-loop ledger to a temp file for comparison
  local TMP_LEDGER
  TMP_LEDGER=$(mktemp)
  echo "$PRE_LOOP_LEDGER_JSON" > "$TMP_LEDGER"
  # award-guard reads HEAD vs git show BASE; we inject via a temp git object
  # Simpler: write the pre-loop ledger to a temp branch/ref and compare.
  # Award guard uses git show BASE:ledger — we cannot easily inject without a commit.
  # APPROACH: compare min(axes) directly via node using the snapshotted JSON.
  set +e
  RAIL2_OUT=$(node -e "
    const fs = require('fs');
    const headLedgerPath = '${ROOT}/guides/reference/admin-award-ledger.json';
    const preLedger = ${PRE_LOOP_LEDGER_JSON};
    const headLedger = JSON.parse(fs.readFileSync(headLedgerPath, 'utf8'));
    const BAND_ORD = { A0: 0, A1: 1, A2: 2, A3: 3 };
    const AXES = ['token_fidelity', 'rhythm', 'a11y_polish', 'states'];
    const minBand = (axes) => {
      let min = 3;
      for (const a of AXES) { const v = BAND_ORD[axes[a]]; if (v < min) min = v; }
      return min;
    };
    const headCells = headLedger.cells || {};
    const baseCells = preLedger.cells || {};
    let violations = 0;
    for (const [surface, cell] of Object.entries(headCells)) {
      const baseCell = baseCells[surface];
      if (!baseCell) continue;
      const headMin = minBand(cell.axes || {});
      const baseMin = minBand(baseCell.axes || {});
      if (headMin < baseMin) {
        process.stderr.write('admin-autofix-loop: rail-2: award band floor breach: ' + surface + ' ' + baseMin + '->' + headMin + '\n');
        violations++;
      }
    }
    if (violations > 0) process.exit(1);
    process.stdout.write('admin-autofix-loop: rail-2: award guard PASS\n');
  " 2>&1)
  RAIL2_EXIT=$?
  rm -f "$TMP_LEDGER"
  set -e
  if [[ $RAIL2_EXIT -ne 0 ]]; then
    TRIPPED_RAIL="rail-2-award-floor: ${RAIL2_OUT}"
    return 1
  fi

  # Rail 3: deterministic gate / anchor resolution
  # Re-run fix-queue-lint.sh and evidence-anchor-check.mjs (no render needed — committed state)
  if [[ "$SKIP_RENDER" -eq 0 ]]; then
    set +e
    RAIL3_OUT=$(bash "${ROOT}/scripts/ci/fix-queue-lint.sh" 2>&1)
    RAIL3_EXIT=$?
    set -e
    if [[ $RAIL3_EXIT -ne 0 ]]; then
      TRIPPED_RAIL="rail-3-queue-lint: ${RAIL3_OUT}"
      return 1
    fi
    set +e
    RAIL3B_OUT=$(node "${ROOT}/scripts/ci/evidence-anchor-check.mjs" 2>&1)
    RAIL3B_EXIT=$?
    set -e
    if [[ $RAIL3B_EXIT -ne 0 ]]; then
      TRIPPED_RAIL="rail-3-anchor-check: ${RAIL3B_OUT}"
      return 1
    fi
  fi

  # Rail 4: snapshot-canary-guard.sh baseline-PNG drift vs pre-loop sha
  # This is a fast_checks step the harness itself does NOT run, so a .heex/inline-style
  # fix that perturbs a committed baseline PNG would otherwise pass the loop yet fail
  # fast_checks later on the PR carrying the auto-fix commits.
  set +e
  RAIL4_OUT=$(bash "${ROOT}/scripts/ci/snapshot-canary-guard.sh" --base "${PRE_LOOP_SHA}" 2>&1)
  RAIL4_EXIT=$?
  set -e
  if [[ $RAIL4_EXIT -ne 0 ]]; then
    TRIPPED_RAIL="rail-4-snapshot-canary: ${RAIL4_OUT}"
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------
ELIGIBLE_JSON=$(load_eligible)
ELIGIBLE_COUNT=$(node -e "console.log(JSON.parse(process.argv[1]).length)" "$ELIGIBLE_JSON")

echo "admin-autofix-loop: ${ELIGIBLE_COUNT} auto-eligible findings (after poison-set filter, capped at ${MAX_FIXES})"

if [[ "$ELIGIBLE_COUNT" -eq 0 ]]; then
  echo "admin-autofix-loop: DONE — no eligible findings to apply"
  exit 0
fi

APPLIED_COUNT=0
REVERTED_COUNT=0
SKIPPED_COUNT=0

for i in $(seq 0 $((ELIGIBLE_COUNT - 1))); do
  FINDING=$(node -e "
    const q = JSON.parse(process.argv[1]);
    console.log(JSON.stringify(q[$i]));
  " "$ELIGIBLE_JSON")

  FINDING_ID=$(node -e "console.log(JSON.parse(process.argv[1]).finding_id)" "$FINDING")
  SURFACE=$(node -e "console.log(JSON.parse(process.argv[1]).surface)" "$FINDING")
  FIX_CLASS=$(node -e "console.log(JSON.parse(process.argv[1]).fix_class)" "$FINDING")
  ANCHOR=$(node -e "console.log(JSON.parse(process.argv[1]).anchor)" "$FINDING")

  echo ""
  echo "admin-autofix-loop: [${i}] applying finding_id=${FINDING_ID} fix_class=${FIX_CLASS} surface=${SURFACE}"

  # Map surface → target file
  TARGET_FILE=$(surface_to_file "$SURFACE")
  if [[ -z "$TARGET_FILE" ]]; then
    echo "admin-autofix-loop: SKIP: no target file for surface=${SURFACE}"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "admin-autofix-loop: SKIP: target file not found: ${TARGET_FILE}"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # Write finding to temp file for fix-apply.mjs
  FINDING_TMP=$(mktemp /tmp/autofix-finding-XXXXXX.json)
  echo "$FINDING" > "$FINDING_TMP"

  # Apply fix
  set +e
  APPLY_OUT=$(node "${ROOT}/scripts/panel/fix-apply.mjs" "$FINDING_TMP" "$TARGET_FILE" 2>&1)
  APPLY_EXIT=$?
  rm -f "$FINDING_TMP"
  set -e

  if [[ $APPLY_EXIT -ne 0 ]]; then
    echo "admin-autofix-loop: REFUSED: fix-apply refused (${APPLY_OUT})"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "admin-autofix-loop: DRY-RUN: would commit ${FINDING_ID} to ${TARGET_FILE}"
    # Restore file
    git -C "$ROOT" checkout -- "$TARGET_FILE" 2>/dev/null || true
    continue
  fi

  # Commit the fix (one fix per commit)
  git -C "$ROOT" add -A
  COMMIT_MSG="autofix(217-06): ${FIX_CLASS} swap on ${SURFACE} — ${ANCHOR}

finding_id: ${FINDING_ID}
fix_class: ${FIX_CLASS}
surface: ${SURFACE}
anchor: ${ANCHOR}
"
  git -C "$ROOT" commit -m "$COMMIT_MSG"
  FIX_COMMIT=$(git -C "$ROOT" rev-parse --short HEAD)
  echo "admin-autofix-loop: COMMITTED: ${FIX_COMMIT} — ${FINDING_ID}"

  # Re-render (if not skipped by test double)
  if [[ "$SKIP_RENDER" -eq 0 ]]; then
    echo "admin-autofix-loop: re-rendering after fix (admin-eval-harness.sh)..."
    set +e
    RENDER_OUT=$(bash "${ROOT}/scripts/ci/admin-eval-harness.sh" 2>&1)
    RENDER_EXIT=$?
    set -e
    if [[ $RENDER_EXIT -ne 0 ]]; then
      echo "admin-autofix-loop: WARN: harness exited non-zero (rail 3 will catch specific failures)"
    fi
  fi

  # Run FOUR rails
  if check_rails "$FIX_COMMIT"; then
    echo "admin-autofix-loop: PASS: all 4 rails green for ${FINDING_ID}"
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
  else
    echo "admin-autofix-loop: REVERT: ${TRIPPED_RAIL}"
    # Auto-revert via `git revert --no-edit HEAD` (a NEW commit — NEVER reset/force-push)
    git -C "$ROOT" revert --no-edit HEAD
    REVERT_COMMIT=$(git -C "$ROOT" rev-parse --short HEAD)
    echo "admin-autofix-loop: REVERTED: new commit ${REVERT_COMMIT} reverts ${FIX_COMMIT}"

    # Add to poison-set + settled-findings.tsv
    add_to_poison "$FINDING_ID" "$SURFACE" "$FIX_CLASS" "$ANCHOR" "$TRIPPED_RAIL"
    echo "admin-autofix-loop: WAIVED: ${FINDING_ID} added to poison-set and settled-findings.tsv"
    REVERTED_COUNT=$((REVERTED_COUNT + 1))
  fi
done

echo ""
echo "admin-autofix-loop: DONE — applied=${APPLIED_COUNT}, reverted=${REVERTED_COUNT}, skipped=${SKIPPED_COUNT}"
echo "admin-autofix-loop: DO NOT wire this script into any CI lane."
