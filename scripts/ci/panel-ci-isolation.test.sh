#!/usr/bin/env bash
# panel-ci-isolation.test.sh — self-test for JUDGE-CI-01 / SC-5 (Phase 217, Plan 03).
#
# Negative-assertion CI-isolation proof:
#   Test 1: greps real .github/workflows/*.yml and asserts NO run: line invokes
#           the panel orchestrator or auto-fix loop orchestrator.
#   Test 2: asserts the 5 required-check job names do NOT depend on any panel/loop step.
#   Test 3: a synthetic workflow fixture that DOES wire the panel orchestrator makes
#           the test fail (proves the assertion has teeth).
#
# Grep hygiene: the two script basenames are assembled via shell variables at runtime
# rather than embedding the verbatim literal that a future negative grep would match.
# The assert-absent literal must NOT appear verbatim in any non-test checked-in file.
#
# Usage:
#   bash scripts/ci/panel-ci-isolation.test.sh
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*" >&2; ((FAIL++)) || true; }

# --------------------------------------------------------------------------
# Script basenames assembled at runtime (grep-hygiene: not verbatim literals)
# --------------------------------------------------------------------------
_PANEL_SFX="panel.sh"
_PANEL_PFX="admin-"
PANEL_SCRIPT="${_PANEL_PFX}${_PANEL_SFX}"        # admin-panel.sh

_LOOP_SFX="autofix-loop.sh"
LOOP_SCRIPT="${_PANEL_PFX}${_LOOP_SFX}"          # admin-autofix-loop.sh

# --------------------------------------------------------------------------
# Locate the repo root (assume CWD is repo root or navigate up)
# --------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"

# --------------------------------------------------------------------------
# Test 1: Real workflows — assert panel + loop are NOT wired as run: steps
# --------------------------------------------------------------------------
echo
echo "Test 1: Real workflows do not invoke panel/loop orchestrators"

# We grep for run: lines that contain the panel/loop basenames.
# spawnSync-style: use -l (print filenames) + -r to scan all *.yml.
PANEL_HITS=$(grep -rn "run:.*${PANEL_SCRIPT}" "${WORKFLOWS_DIR}"/*.yml 2>/dev/null || true)
LOOP_HITS=$(grep -rn "run:.*${LOOP_SCRIPT}" "${WORKFLOWS_DIR}"/*.yml 2>/dev/null || true)

if [ -z "$PANEL_HITS" ] && [ -z "$LOOP_HITS" ]; then
  pass "No run: step invokes ${PANEL_SCRIPT} or ${LOOP_SCRIPT} in any workflow"
else
  [ -n "$PANEL_HITS" ] && fail "Found run: step invoking ${PANEL_SCRIPT}: ${PANEL_HITS}"
  [ -n "$LOOP_HITS" ]  && fail "Found run: step invoking ${LOOP_SCRIPT}: ${LOOP_HITS}"
fi

# --------------------------------------------------------------------------
# Test 2: The 5 required-check job names do not depend on panel/loop steps
# --------------------------------------------------------------------------
echo
echo "Test 2: 5 required-check jobs exclude panel/loop dependencies"

# The 5 required-check job names (byte-identical to GitHub ruleset strings)
REQUIRED_JOB_NAMES=(
  "Library tests"
  "Example unit smoke"
  "Install smoke"
  "Example HTTP smoke"
  "Example Playwright smoke"
)

# Scan all workflow files for any step under a job matching a required-check
# name that invokes the panel/loop scripts.
# Strategy: grep the full workflow text for any line that has both a required
# job name context and the panel/loop script name. Since YAML is line-based,
# a simpler approach is to grep the combined workflow content for panel/loop
# script names (already done in Test 1 — if Test 1 passes, no run: step
# invokes them anywhere, which means the required-check jobs can't depend on them).
# Test 2 adds a positive assertion: the job name strings ARE present in the workflow.
WORKFLOW_CONTENT=$(cat "${WORKFLOWS_DIR}"/*.yml 2>/dev/null || true)

ALL_JOBS_PRESENT=true
for JOB_NAME in "${REQUIRED_JOB_NAMES[@]}"; do
  # Match job names that begin with the required-check prefix (the actual workflow
  # name may have trailing parenthetical context, e.g. "Example unit smoke (ExUnit + ConnTest)").
  # Use grep -c (not -q) to avoid SIGPIPE under set -o pipefail: grep -q exits after
  # the first match, sending SIGPIPE to echo, which pipefail treats as a failure.
  MATCH_COUNT=$(echo "$WORKFLOW_CONTENT" | grep -cE "^    name: ${JOB_NAME}( |[[:space:]]|$)" || true)
  if [ "${MATCH_COUNT:-0}" -gt 0 ]; then
    : # found
  else
    fail "Required-check job '${JOB_NAME}' not found in workflows — name may have drifted"
    ALL_JOBS_PRESENT=false
  fi
done

if [ "$ALL_JOBS_PRESENT" = "true" ]; then
  # Double-check: none of the required-check job bodies invoke the panel/loop
  # (already guaranteed by Test 1, but stated explicitly for Test 2 semantics)
  if [ -z "$PANEL_HITS" ] && [ -z "$LOOP_HITS" ]; then
    pass "All 5 required-check job names present and none invoke panel/loop orchestrators"
  else
    fail "Required-check jobs present but panel/loop wiring detected (see Test 1 output)"
  fi
fi

# --------------------------------------------------------------------------
# Test 3: Synthetic fixture — panel wiring makes the assertion fail (teeth)
# --------------------------------------------------------------------------
echo
echo "Test 3: Synthetic fixture with panel wiring is correctly detected as a violation"

TMPDIR_ROOT=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT INT TERM

SYNTHETIC_WORKFLOW="${TMPDIR_ROOT}/synthetic.yml"

# Build the synthetic workflow. The run: step must contain the panel script
# basename — assembled via shell concatenation so the verbatim literal does
# not appear in the non-run: prose sections of this file.
# (The literal only appears inside the heredoc content for the synthetic YAML,
# which is a test fixture, not a real workflow.)
cat > "$SYNTHETIC_WORKFLOW" <<SYNTH_EOF
name: Synthetic CI (test fixture — panel wired)
on: [push]
jobs:
  fast_checks:
    name: Fast checks
    runs-on: ubuntu-latest
    steps:
      - name: Run panel orchestrator (WIRED — should be detected)
        run: bash scripts/${_PANEL_PFX}${_PANEL_SFX}
SYNTH_EOF

# Now grep the synthetic workflow for the panel script — expect a hit
SYNTH_HITS=$(grep -n "run:.*${PANEL_SCRIPT}" "$SYNTHETIC_WORKFLOW" 2>/dev/null || true)
if [ -n "$SYNTH_HITS" ]; then
  pass "Synthetic fixture correctly detected as wired: ${SYNTH_HITS}"
else
  fail "Synthetic fixture was NOT detected as wired — assertion has no teeth"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo
echo "panel-ci-isolation self-test: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
