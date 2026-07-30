#!/usr/bin/env bash
# Self-test for honest-skip-verdict.sh (Phase 231 / GATE-03 / D-01, D-03, D-04).
#
# Hermetic: the script under test invokes no `gh` and makes no network call by
# design (it reads only two committed repo files plus lane-result strings
# passed via --lane / --from-json / env), so this self-test needs no PATH
# stub at all -- unlike ci-demotion-observer.test.sh's recording `gh` stub.
#
# Test cases:
#   A: shipped manifest, pull_request, all nine lanes success -> exit 0.
#   B: upgrade_smoke skipped on pull_request -> exit 0, reported as a
#      legitimate event-gated skip.
#   C: upgrade_smoke skipped on push -> exit 1, reason names the lane AND
#      the event.
#   D: library_tests_dep_off skipped on pull_request, docs-only true -> exit 0.
#   E: same, docs-only false -> exit 1, reason names the lane.
#   F: same, docs-only empty -> exit 1, output carries the empty-input NOTE.
#   G: example_playwright_smoke skipped on pull_request -> exit 1; it is not
#      in the allow-set on any event.
#   H: a lane result of `failure` -> exit 1 (ci.yml:1831's behaviour preserved
#      inside the script).
#   I: a lane result of `cancelled` -> exit 1; a superseded run is never
#      waved through.
#   J: every lane result empty -> exit 1 with the broken-wiring message,
#      never a pass.
#   K: fixture manifest with zero lane-set rows -> exit 1 with the literal
#      broken-parse phrase.
#   L: fixture manifest whose upgrade_smoke gate names a branch, lane skipped
#      on pull_request -> exit 1 even though the skip was allowed; the reason
#      quotes the gate.
#   M: --force-rot-probe on an all-green pull_request map -> exit 1, output
#      names example_playwright_smoke.
#   N: the same map without the flag -> exit 0 and no probe banner appears,
#      proving the probe is a no-op by default.
#   O: unknown flag -> exit 2.
#   P: --format json output parses and carries a lane entry per lane plus a
#      top-level verdict.
#   Q: positive control -- the shipped manifest yields at least five
#      lane-set rows including upgrade_smoke and library_tests_dep_off.
#   R: workflow cross-check positive control -- the shipped ci.yml's
#      ci-gate needs and the script's lane list agree modulo the
#      input-provider exclusion (`changes`).
#   S: workflow cross-check negative control -- a fixture workflow missing a
#      lane from ci-gate.needs exits 1 naming it.
#   T: static wiring -- the shipped ci-gate job actually invokes this script
#      (plan 231-09, D-02): the "Honest-skip verdict (GATE-03)" step exists,
#      sits before the legacy "Verify required release CI lanes" step in
#      list order, invokes honest-skip-verdict.sh, and its env carries the
#      docs-only, event-name and probe keys.
#
# No network access and no GitHub access token are required or read anywhere in this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/honest-skip-verdict.sh"
REAL_MANIFEST="$(cd "${SCRIPT_DIR}/../.." && pwd)/.github/ci-skip-manifest.tsv"
REAL_WORKFLOW="$(cd "${SCRIPT_DIR}/../.." && pwd)/.github/workflows/ci.yml"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi
if [[ ! -f "$REAL_MANIFEST" ]]; then
  echo "FATAL: manifest not found at ${REAL_MANIFEST}" >&2
  exit 2
fi
if [[ ! -f "$REAL_WORKFLOW" ]]; then
  echo "FATAL: workflow not found at ${REAL_WORKFLOW}" >&2
  exit 2
fi

PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then rm -rf "$TMPDIR_ROOT"; fi
}
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
PAYLOAD_FILE="${TMPDIR_ROOT}/payload.json"

BASE_LANE_JSON='{
  "install_golden_contract": "success",
  "library_tests": "success",
  "library_tests_dep_off": "success",
  "install_smoke": "success",
  "upgrade_smoke": "success",
  "example_http_smoke": "success",
  "example_playwright_smoke": "success",
  "generated_admin_playwright_smoke": "success",
  "fast_checks": "success"
}'

# Invokers -- output-capturing (status swallowed) and rc-capturing (output
# discarded). Two functions because a single helper hides every rc.
run_verdict() {
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  bash "$SCRIPT" --manifest "$REAL_MANIFEST" --workflow "$REAL_WORKFLOW" \
    --from-json "$PAYLOAD_FILE" "$@" 2>&1 || true
}
run_verdict_rc() {
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  set +e
  bash "$SCRIPT" --manifest "$REAL_MANIFEST" --workflow "$REAL_WORKFLOW" \
    --from-json "$PAYLOAD_FILE" "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  echo "$rc"
}

# ---- A: shipped manifest, pull_request, all nine success -> exit 0 --------
echo "Test A: all nine lanes success on pull_request -> exit 0"
OUT_A="$(run_verdict "$BASE_LANE_JSON" --event pull_request --docs-only false)"
RC_A="$(run_verdict_rc "$BASE_LANE_JSON" --event pull_request --docs-only false)"
if [[ "$RC_A" -eq 0 ]] && ! grep -q "^  FAIL " <<<"$OUT_A"; then
  pass "A: exit 0, no FAIL lines"
else
  fail "A: rc=${RC_A}, output: ${OUT_A}"
fi

# ---- B: upgrade_smoke skipped on pull_request -> exit 0 -------------------
echo "Test B: upgrade_smoke skipped on pull_request -> exit 0 (legitimate)"
P_B="$(jq '.upgrade_smoke = "skipped"' <<<"$BASE_LANE_JSON")"
OUT_B="$(run_verdict "$P_B" --event pull_request --docs-only false)"
RC_B="$(run_verdict_rc "$P_B" --event pull_request --docs-only false)"
if [[ "$RC_B" -eq 0 ]] && grep -q "upgrade_smoke" <<<"$OUT_B" && grep -q "legitimately gated" <<<"$OUT_B"; then
  pass "B: exit 0, upgrade_smoke reported as legitimately gated"
else
  fail "B: rc=${RC_B}, output: ${OUT_B}"
fi

# ---- C: upgrade_smoke skipped on push -> exit 1 ----------------------------
echo "Test C: upgrade_smoke skipped on push -> exit 1, names lane AND event"
OUT_C="$(run_verdict "$P_B" --event push --docs-only false)"
RC_C="$(run_verdict_rc "$P_B" --event push --docs-only false)"
if [[ "$RC_C" -eq 1 ]] && grep -q "upgrade_smoke" <<<"$OUT_C" && grep -q "event 'push'" <<<"$OUT_C"; then
  pass "C: exit 1, reason names upgrade_smoke and the push event"
else
  fail "C: rc=${RC_C}, output: ${OUT_C}"
fi

# ---- D: library_tests_dep_off skipped, docs-only true -> exit 0 -----------
echo "Test D: library_tests_dep_off skipped, docs-only true -> exit 0"
P_DE="$(jq '.library_tests_dep_off = "skipped"' <<<"$BASE_LANE_JSON")"
OUT_D="$(run_verdict "$P_DE" --event pull_request --docs-only true)"
RC_D="$(run_verdict_rc "$P_DE" --event pull_request --docs-only true)"
if [[ "$RC_D" -eq 0 ]] && grep -q "library_tests_dep_off" <<<"$OUT_D"; then
  pass "D: exit 0, docs-only true legitimizes the skip"
else
  fail "D: rc=${RC_D}, output: ${OUT_D}"
fi

# ---- E: same, docs-only false -> exit 1 ------------------------------------
echo "Test E: library_tests_dep_off skipped, docs-only false -> exit 1"
OUT_E="$(run_verdict "$P_DE" --event pull_request --docs-only false)"
RC_E="$(run_verdict_rc "$P_DE" --event pull_request --docs-only false)"
if [[ "$RC_E" -eq 1 ]] && grep -q "library_tests_dep_off" <<<"$OUT_E"; then
  pass "E: exit 1, reason names library_tests_dep_off"
else
  fail "E: rc=${RC_E}, output: ${OUT_E}"
fi

# ---- F: same, docs-only empty -> exit 1, empty-input NOTE present ---------
echo "Test F: library_tests_dep_off skipped, docs-only empty -> exit 1, NOTE"
OUT_F="$(run_verdict "$P_DE" --event pull_request --docs-only "")"
RC_F="$(run_verdict_rc "$P_DE" --event pull_request --docs-only "")"
if [[ "$RC_F" -eq 1 ]] && grep -q "library_tests_dep_off" <<<"$OUT_F" \
   && grep -q "docs_only input never arrived" <<<"$OUT_F"; then
  pass "F: exit 1, empty-docs-only NOTE present"
else
  fail "F: rc=${RC_F}, output: ${OUT_F}"
fi

# ---- G: example_playwright_smoke skipped on pull_request -> exit 1 --------
echo "Test G: example_playwright_smoke skipped on pull_request -> exit 1"
P_G="$(jq '.example_playwright_smoke = "skipped"' <<<"$BASE_LANE_JSON")"
OUT_G="$(run_verdict "$P_G" --event pull_request --docs-only false)"
RC_G="$(run_verdict_rc "$P_G" --event pull_request --docs-only false)"
if [[ "$RC_G" -eq 1 ]] && grep -q "example_playwright_smoke" <<<"$OUT_G"; then
  pass "G: exit 1, not in the allow-set on any event"
else
  fail "G: rc=${RC_G}, output: ${OUT_G}"
fi

# ---- H: a lane result of failure -> exit 1 ---------------------------------
echo "Test H: install_smoke=failure -> exit 1"
P_H="$(jq '.install_smoke = "failure"' <<<"$BASE_LANE_JSON")"
OUT_H="$(run_verdict "$P_H" --event pull_request --docs-only false)"
RC_H="$(run_verdict_rc "$P_H" --event pull_request --docs-only false)"
if [[ "$RC_H" -eq 1 ]] && grep -q "install_smoke" <<<"$OUT_H"; then
  pass "H: exit 1 on a failure result (ci.yml:1831 behaviour preserved)"
else
  fail "H: rc=${RC_H}, output: ${OUT_H}"
fi

# ---- I: a lane result of cancelled -> exit 1 -------------------------------
echo "Test I: install_smoke=cancelled -> exit 1"
P_I="$(jq '.install_smoke = "cancelled"' <<<"$BASE_LANE_JSON")"
OUT_I="$(run_verdict "$P_I" --event pull_request --docs-only false)"
RC_I="$(run_verdict_rc "$P_I" --event pull_request --docs-only false)"
if [[ "$RC_I" -eq 1 ]] && grep -q "install_smoke" <<<"$OUT_I"; then
  pass "I: exit 1, a cancelled lane is never waved through"
else
  fail "I: rc=${RC_I}, output: ${OUT_I}"
fi

# ---- J: every lane result empty -> exit 1, broken-wiring message ----------
echo "Test J: every lane result empty -> exit 1 (broken wiring, never a pass)"
EMPTY_LANE_JSON='{
  "install_golden_contract": "", "library_tests": "", "library_tests_dep_off": "",
  "install_smoke": "", "upgrade_smoke": "", "example_http_smoke": "",
  "example_playwright_smoke": "", "generated_admin_playwright_smoke": "", "fast_checks": ""
}'
OUT_J="$(run_verdict "$EMPTY_LANE_JSON" --event pull_request --docs-only false)"
RC_J="$(run_verdict_rc "$EMPTY_LANE_JSON" --event pull_request --docs-only false)"
if [[ "$RC_J" -eq 1 ]] && grep -q "nothing-to-check-so-pass" <<<"$OUT_J"; then
  pass "J: exit 1, an empty result map is a broken wiring, not a pass"
else
  fail "J: rc=${RC_J}, output: ${OUT_J}"
fi

# ---- K: manifest with zero lane-set rows -> exit 1, literal phrase --------
echo "Test K: manifest with zero lane-set rows -> exit 1 (non-vacuity)"
ZERO_MANIFEST="${TMPDIR_ROOT}/zero-manifest.tsv"
{
  printf 'tier\tkind\tid\tparent_job_id\tdisplay_name\tgate_level\tgate\tobserver\n'
  printf 'A\tjob\tsome_other_job\t-\tSome other job\tjob\tx\tignore\n'
} > "$ZERO_MANIFEST"
printf '%s' "$BASE_LANE_JSON" > "$PAYLOAD_FILE"
set +e
OUT_K="$(bash "$SCRIPT" --manifest "$ZERO_MANIFEST" --workflow "$REAL_WORKFLOW" \
  --from-json "$PAYLOAD_FILE" --event pull_request --docs-only false 2>&1)"
RC_K=$?
set -e
if [[ "$RC_K" -eq 1 ]] && grep -q "the parse broke, this is not a pass" <<<"$OUT_K"; then
  pass "K: an empty lane-set intersection is a broken parse, not a clean run"
else
  fail "K: rc=${RC_K}, output: ${OUT_K}"
fi

# ---- L: rotted upgrade_smoke gate, skipped, allowed -> exit 1 -------------
echo "Test L: upgrade_smoke gate rewritten to a branch, still skipped -> exit 1"
ROTTED_MANIFEST="${TMPDIR_ROOT}/rotted-manifest.tsv"
awk -F'\t' 'BEGIN{OFS="\t"}
  $3 == "upgrade_smoke" { $7 = "github.event_name != '\''pull_request'\'' || github.head_ref == '\''ship/rot-test-fixture'\''" }
  { print }
' "$REAL_MANIFEST" > "$ROTTED_MANIFEST"
printf '%s' "$P_B" > "$PAYLOAD_FILE"
set +e
OUT_L="$(bash "$SCRIPT" --manifest "$ROTTED_MANIFEST" --workflow "$REAL_WORKFLOW" \
  --from-json "$PAYLOAD_FILE" --event pull_request --docs-only false 2>&1)"
RC_L=$?
set -e
if [[ "$RC_L" -eq 1 ]] && grep -q "upgrade_smoke" <<<"$OUT_L" \
   && grep -q "rotted" <<<"$OUT_L" && grep -q "head_ref" <<<"$OUT_L"; then
  pass "L: an allowed skip still fails on a rotted gate; reason quotes the cell"
else
  fail "L: rc=${RC_L}, output: ${OUT_L}"
fi

# ---- M: --force-rot-probe on an all-green map -> exit 1 -------------------
echo "Test M: --force-rot-probe on an all-green pull_request map -> exit 1"
OUT_M="$(run_verdict "$BASE_LANE_JSON" --event pull_request --docs-only false --force-rot-probe)"
RC_M="$(run_verdict_rc "$BASE_LANE_JSON" --event pull_request --docs-only false --force-rot-probe)"
if [[ "$RC_M" -eq 1 ]] && grep -q "example_playwright_smoke" <<<"$OUT_M" \
   && grep -q "ROT PROBE ACTIVE" <<<"$OUT_M"; then
  pass "M: exit 1, output names example_playwright_smoke and carries the probe banner"
else
  fail "M: rc=${RC_M}, output: ${OUT_M}"
fi

# ---- N: identical map without the flag -> exit 0, no probe banner ---------
echo "Test N: same map without --force-rot-probe -> exit 0, no probe banner"
OUT_N="$(run_verdict "$BASE_LANE_JSON" --event pull_request --docs-only false)"
RC_N="$(run_verdict_rc "$BASE_LANE_JSON" --event pull_request --docs-only false)"
if [[ "$RC_N" -eq 0 ]] && ! grep -q "ROT PROBE ACTIVE" <<<"$OUT_N"; then
  pass "N: exit 0, the probe flag is a total no-op when unset"
else
  fail "N: rc=${RC_N}, output: ${OUT_N}"
fi

# ---- O: unknown flag -> exit 2 ---------------------------------------------
echo "Test O: unknown flag -> exit 2"
set +e
bash "$SCRIPT" --bogus >/dev/null 2>&1
RC_O=$?
set -e
if [[ "$RC_O" -eq 2 ]]; then
  pass "O: exit 2 on an unrecognized flag"
else
  fail "O: expected exit 2, got ${RC_O}"
fi

# ---- P: --format json parses, one lane entry per lane + top-level verdict -
echo "Test P: --format json parses with 9 lane entries and a top-level verdict"
printf '%s' "$BASE_LANE_JSON" > "$PAYLOAD_FILE"
set +e
OUT_P="$(bash "$SCRIPT" --manifest "$REAL_MANIFEST" --workflow "$REAL_WORKFLOW" \
  --from-json "$PAYLOAD_FILE" --event pull_request --docs-only false --format json 2>&1)"
RC_P=$?
set -e
if [[ "$RC_P" -eq 0 ]] \
   && jq -e '(.lanes | length) == 9 and .verdict == "PASS"' >/dev/null 2>&1 <<<"$OUT_P"; then
  pass "P: valid JSON, 9 lane entries, top-level verdict PASS"
else
  fail "P: rc=${RC_P}, output: ${OUT_P}"
fi

# ---- Q: positive control -- shipped manifest yields >= 5 lane-set rows ----
echo "Test Q: the shipped manifest yields the expected lane-set rows"
SHIPPED_MANIFEST_IDS="$(awk -F'\t' '
  /^#/ { next }
  /^[[:space:]]*$/ { next }
  $1 == "tier" { next }
  { print $3 }
' "$REAL_MANIFEST")"
if [[ -z "$SHIPPED_MANIFEST_IDS" ]]; then
  fail "Q: manifest extraction yielded nothing -- the parse broke, this is not a pass"
else
  LANE_SET=(install_golden_contract library_tests library_tests_dep_off install_smoke \
    upgrade_smoke example_http_smoke example_playwright_smoke \
    generated_admin_playwright_smoke fast_checks)
  HIT=0
  for id in "${LANE_SET[@]}"; do
    grep -qx "$id" <<<"$SHIPPED_MANIFEST_IDS" && HIT=$((HIT + 1))
  done
  if [[ "$HIT" -ge 5 ]] && grep -qx "upgrade_smoke" <<<"$SHIPPED_MANIFEST_IDS" \
     && grep -qx "library_tests_dep_off" <<<"$SHIPPED_MANIFEST_IDS"; then
    pass "Q: shipped manifest yields ${HIT} lane-set rows (>= 5), including upgrade_smoke and library_tests_dep_off"
  else
    fail "Q: shipped manifest yielded only ${HIT} lane-set rows: ${SHIPPED_MANIFEST_IDS}"
  fi
fi

# ---- R: workflow cross-check positive control ------------------------------
echo "Test R: shipped ci.yml's ci-gate needs agree with the script's lane list"
SHIPPED_NEEDS="$(awk '
  /^  ci-gate:[[:space:]]*$/ { in_job=1; next }
  in_job && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { in_job=0 }
  in_job && /^    needs:[[:space:]]*$/ { in_needs=1; next }
  in_job && in_needs {
    if ($0 ~ /^      - [A-Za-z0-9_.-]+[[:space:]]*$/) {
      line=$0
      sub(/^      - /, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      next
    } else {
      in_needs=0
    }
  }
' "$REAL_WORKFLOW")"
if [[ -z "$SHIPPED_NEEDS" ]]; then
  fail "R: could not extract any ci-gate needs: entries -- the parse broke, this is not a pass"
else
  LANE_SET=(install_golden_contract library_tests library_tests_dep_off install_smoke \
    upgrade_smoke example_http_smoke example_playwright_smoke \
    generated_admin_playwright_smoke fast_checks)
  MISMATCH=""
  while IFS= read -r need; do
    [[ "$need" == "changes" ]] && continue
    grep -qx "$need" <<<"$(printf '%s\n' "${LANE_SET[@]}")" || MISMATCH="${MISMATCH}${need} "
  done <<<"$SHIPPED_NEEDS"
  for lane in "${LANE_SET[@]}"; do
    grep -qx "$lane" <<<"$SHIPPED_NEEDS" || MISMATCH="${MISMATCH}${lane} "
  done
  if [[ -z "$MISMATCH" ]]; then
    pass "R: shipped ci-gate.needs and the script's lane list agree modulo 'changes'"
  else
    fail "R: mismatch between shipped ci-gate.needs and the lane list: ${MISMATCH}"
  fi
fi

# ---- S: workflow cross-check negative control ------------------------------
echo "Test S: a fixture workflow missing a lane from ci-gate.needs -> exit 1"
MISSING_LANE_WORKFLOW="${TMPDIR_ROOT}/missing-lane.yml"
cat > "$MISSING_LANE_WORKFLOW" <<'FIXTURE'
name: CI
on:
  pull_request:
jobs:
  ci-gate:
    name: ci-gate
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs:
      - install_golden_contract
      - library_tests
      - library_tests_dep_off
      - install_smoke
      - upgrade_smoke
      - example_http_smoke
      - example_playwright_smoke
      - fast_checks
    if: always()
    steps:
      - name: noop
        run: echo hi
FIXTURE
printf '%s' "$BASE_LANE_JSON" > "$PAYLOAD_FILE"
set +e
OUT_S="$(bash "$SCRIPT" --manifest "$REAL_MANIFEST" --workflow "$MISSING_LANE_WORKFLOW" \
  --from-json "$PAYLOAD_FILE" --event pull_request --docs-only false 2>&1)"
RC_S=$?
set -e
if [[ "$RC_S" -eq 1 ]] && grep -q "generated_admin_playwright_smoke" <<<"$OUT_S"; then
  pass "S: exit 1, names the lane missing from ci-gate.needs"
else
  fail "S: rc=${RC_S}, output: ${OUT_S}"
fi

# ---- T: static wiring -- ci-gate actually invokes the verdict script ------
echo "Test T: ci-gate's own step list invokes honest-skip-verdict.sh ahead of the legacy loop"
CI_GATE_BLOCK="$(awk '
  /^  ci-gate:[[:space:]]*$/ { in_job=1; print; next }
  in_job && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { in_job=0 }
  in_job { print }
' "$REAL_WORKFLOW")"
if [[ -z "$CI_GATE_BLOCK" ]]; then
  fail "T: could not extract the ci-gate job block from ${REAL_WORKFLOW} -- the parse broke, this is not a pass"
else
  VERDICT_LINE="$(grep -n '^      - name: Honest-skip verdict (GATE-03)$' <<<"$CI_GATE_BLOCK" | head -1 | cut -d: -f1)"
  LEGACY_LINE="$(grep -n '^      - name: Verify required release CI lanes$' <<<"$CI_GATE_BLOCK" | head -1 | cut -d: -f1)"
  INVOKES_SCRIPT="$(grep -c 'honest-skip-verdict\.sh' <<<"$CI_GATE_BLOCK" || true)"
  HAS_DOCS_ONLY="$(grep -c 'DOCS_ONLY:' <<<"$CI_GATE_BLOCK" || true)"
  HAS_EVENT_NAME="$(grep -c 'EVENT_NAME:' <<<"$CI_GATE_BLOCK" || true)"
  HAS_PROBE="$(grep -c 'FORCE_ROT_PROBE:' <<<"$CI_GATE_BLOCK" || true)"
  if [[ -n "$VERDICT_LINE" && -n "$LEGACY_LINE" && "$VERDICT_LINE" -lt "$LEGACY_LINE" \
        && "$INVOKES_SCRIPT" -ge 1 && "$HAS_DOCS_ONLY" -ge 1 && "$HAS_EVENT_NAME" -ge 1 && "$HAS_PROBE" -ge 1 ]]; then
    pass "T: ci-gate invokes honest-skip-verdict.sh before the legacy loop, env carries docs-only/event-name/probe keys"
  else
    fail "T: verdict_line=${VERDICT_LINE:-<missing>} legacy_line=${LEGACY_LINE:-<missing>} invokes=${INVOKES_SCRIPT:-0} docs_only=${HAS_DOCS_ONLY:-0} event_name=${HAS_EVENT_NAME:-0} probe=${HAS_PROBE:-0}"
  fi
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "honest-skip-verdict.test: FAIL"
  exit 1
fi
echo "honest-skip-verdict.test: PASS"
