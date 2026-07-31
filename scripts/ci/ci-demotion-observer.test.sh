#!/usr/bin/env bash
# Self-test for ci-demotion-observer.sh (Phase 230 / AFTER-PUSH closure).
#
# Hermetic: no real `gh` CLI and no network call. A recording stub `gh` is placed first
# on PATH; it logs every invocation's argv and returns a scripted
# `gh run view --json jobs,event,createdAt,updatedAt,databaseId` payload, so each case
# can assert both what the script computed AND how many `gh` round-trips it made.
#
# The canned payload mirrors the real AFTER-NONPR run 30414885679: admin_eval_render
# concluding `failure` under continue-on-error with a real 1074s duration, and the
# design_gallery_snapshots STEP nested inside the `Example Playwright smoke
# (full lifecycle)` job with a real 436s duration.
#
# Test cases:
#   A: canned green non-PR run -> exit 0, both constructs PASS, EXACTLY one `gh` call.
#   B: admin_eval_render `conclusion: failure` with a real duration -> still PASS. The
#      receipt asserts EXECUTION, not success -- this is the case that keeps the
#      deliberately-retained continue-on-error red (Phase 231 GATE-04) from reddening it.
#   C: admin_eval_render `skipped` -> exit 1, reason names the rotted demotion.
#   D: the design_gallery_snapshots STEP `skipped` -> exit 1.
#   E: a construct absent from the run (renamed job) -> exit 1. Renaming is the #1 rot
#      mode and must never read as "nothing to check, so pass".
#   F: THE FAIL-OPEN HOLE. An unfinished construct: `status: in_progress`,
#      `conclusion: ""`, `completedAt: "0001-01-01T00:00:00Z"`. The Actions API really
#      serializes it this way, and ci-run-metrics.sh's negative-duration clamp turns it
#      into `0s` -- byte-identical to a skip -- while `conclusion != "skipped"` passes on
#      "". Must exit 1 on the status check BEFORE any duration inference.
#   G: `completedAt == startedAt` on a `success` construct -> exit 1 (green on a no-op).
#   H: a job elsewhere in the run `cancelled` -> exit 1 (FAST-04: a non-PR run keys its
#      concurrency group on its own run_id, so a cancellation there is not supersession).
#   I: a job elsewhere in the run `timed_out` -> exit 1 (FAST-07).
#   J: empty job list -> exit 1, fail-closed.
#   K: `gh` absent from PATH -> exit 1.
#   L: `gh` exits non-zero -> exit 1.
#   M: unknown flag -> exit 2 with ZERO recorded `gh` invocations (arg parsing fails
#      before any round-trip).
#   N: `--from-json` -> identical verdicts with ZERO `gh` calls; `--format json` emits
#      valid JSON carrying a top-level `verdict`.
#   O: NON-VACUITY. A manifest that parses to zero `assert` rows -> exit 1. Without this,
#      an emptied or reformatted manifest would make every run trivially green.
#   P: a kind=step row whose parent_job_id has no matching kind=job row -> exit 1 (the
#      parent's display_name is unresolvable, so the lookup would silently find nothing).
#   Q: the SHIPPED manifest yields at least the two tier-B assert rows -- a positive
#      control proving cases A-N ran against a realistic assert set, not an empty one.
#
# No network access and no GH_TOKEN are required or read anywhere in this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ci-demotion-observer.sh"
REAL_MANIFEST="$(cd "${SCRIPT_DIR}/../.." && pwd)/.github/ci-skip-manifest.tsv"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi
if [[ ! -f "$REAL_MANIFEST" ]]; then
  echo "FATAL: manifest not found at ${REAL_MANIFEST}" >&2
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
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
PAYLOAD_FILE="${TMPDIR_ROOT}/payload.json"
: > "$GH_STUB_LOG"

EVAL_NAME="Admin eval render + probe (hard signal on push/schedule/dispatch; not in ci-gate)"
PW_NAME="Example Playwright shard (design_gallery)"
SNAP_NAME="Run design gallery behavior and snapshots"

# Canned green non-PR payload, mirroring run 30414885679.
BASE_PAYLOAD="$(jq -n \
  --arg eval_name "$EVAL_NAME" --arg pw_name "$PW_NAME" --arg snap_name "$SNAP_NAME" '
{
  databaseId: 30414885679,
  event: "workflow_dispatch",
  createdAt: "2026-07-29T01:40:00Z",
  updatedAt: "2026-07-29T02:04:41Z",
  jobs: [
    { name: $eval_name, status: "completed", conclusion: "failure",
      startedAt: "2026-07-29T01:43:39Z", completedAt: "2026-07-29T02:01:33Z", steps: [] },
    { name: "Fast checks (milestone/installer/contracts/snapshot/ledger guards)",
      status: "completed", conclusion: "success",
      startedAt: "2026-07-29T01:40:10Z", completedAt: "2026-07-29T01:40:36Z", steps: [] },
    { name: $pw_name, status: "completed", conclusion: "success",
      startedAt: "2026-07-29T01:30:00Z", completedAt: "2026-07-29T02:03:58Z",
      steps: [
        { name: "Run design gallery boards (chromium, mobile, dark)", status: "completed",
          conclusion: "success", startedAt: "2026-07-29T01:52:32Z", completedAt: "2026-07-29T01:56:42Z" },
        { name: $snap_name, status: "completed", conclusion: "success",
          startedAt: "2026-07-29T01:56:42Z", completedAt: "2026-07-29T02:03:58Z" }
      ] }
  ]
}')"

cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
# Recording stub for \`gh\` (test-only). Logs argv, returns the scripted payload.
set -euo pipefail
echo "\$*" >> "${GH_STUB_LOG}"
if [[ -n "\${GH_STUB_FAIL:-}" ]]; then
  echo "gh: simulated failure" >&2
  exit 1
fi
cat "${PAYLOAD_FILE}"
STUB
chmod +x "${STUB_BIN_DIR}/gh"

# Run the observer with the stub `gh` first on PATH. $1 = payload JSON, rest = argv.
run_observer() {
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  : > "$GH_STUB_LOG"
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" "$@" 2>&1 || true
}
run_observer_rc() {
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  : > "$GH_STUB_LOG"
  set +e
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  echo "$rc"
}
# NOTE: `grep -c .` PRINTS 0 and EXITS 1 on no match, so `|| echo 0` would emit a second
# zero and every arithmetic comparison against it would be a syntax error. Swallow the
# exit status instead of appending a fallback line.
gh_call_count() {
  local n
  n="$(grep -c . "$GH_STUB_LOG" 2>/dev/null || true)"
  echo "${n:-0}"
}

# ---- A: canned green non-PR run -> exit 0, both PASS, exactly one gh call ----
echo "Test A: canned green non-PR run -> exit 0, both constructs PASS, one gh call"
OUT_A="$(run_observer "$BASE_PAYLOAD")"
RC_A="$(run_observer_rc "$BASE_PAYLOAD")"
CALLS_A="$(gh_call_count)"
if [[ "$RC_A" -eq 0 ]] && grep -q "admin_eval_render" <<<"$OUT_A" \
   && grep -q "design_gallery_snapshots" <<<"$OUT_A" \
   && ! grep -q "FAIL" <<<"$OUT_A" && [[ "$CALLS_A" -eq 1 ]]; then
  pass "A: exit 0, both constructs reported, exactly ${CALLS_A} gh call"
else
  fail "A: rc=${RC_A}, gh calls=${CALLS_A}, output: ${OUT_A}"
fi

# ---- B: failure conclusion with real duration still PASSes -------------------
echo "Test B: admin_eval_render conclusion=failure with real duration -> PASS"
if grep -qE "admin_eval_render.*failure.*1074s.*PASS" <<<"$OUT_A"; then
  pass "B: a failing-but-executed construct passes the receipt"
else
  fail "B: expected admin_eval_render failure/1074s/PASS, got: ${OUT_A}"
fi

# ---- C: admin_eval_render skipped -> exit 1 ---------------------------------
echo "Test C: admin_eval_render skipped -> exit 1"
P_C="$(jq --arg n "$EVAL_NAME" '(.jobs[] | select(.name == $n)) |= (.conclusion = "skipped" | .completedAt = .startedAt)' <<<"$BASE_PAYLOAD")"
RC_C="$(run_observer_rc "$P_C")"; OUT_C="$(run_observer "$P_C")"
if [[ "$RC_C" -eq 1 ]] && grep -q "FAIL admin_eval_render" <<<"$OUT_C" && grep -q "rotted" <<<"$OUT_C"; then
  pass "C: exit 1 and the reason names the rotted demotion"
else
  fail "C: rc=${RC_C}, output: ${OUT_C}"
fi

# ---- D: the nested step skipped -> exit 1 -----------------------------------
echo "Test D: design_gallery_snapshots step skipped -> exit 1"
P_D="$(jq --arg n "$SNAP_NAME" '(.jobs[].steps[]? | select(.name == $n)) |= (.conclusion = "skipped" | .completedAt = .startedAt)' <<<"$BASE_PAYLOAD")"
RC_D="$(run_observer_rc "$P_D")"; OUT_D="$(run_observer "$P_D")"
if [[ "$RC_D" -eq 1 ]] && grep -q "FAIL design_gallery_snapshots" <<<"$OUT_D"; then
  pass "D: exit 1 on a skipped nested step"
else
  fail "D: rc=${RC_D}, output: ${OUT_D}"
fi

# ---- E: construct absent (renamed job) -> exit 1 ----------------------------
echo "Test E: a renamed/absent construct -> exit 1 (rot, not 'nothing to check')"
P_E="$(jq --arg n "$EVAL_NAME" '(.jobs[] | select(.name == $n)).name = "Admin eval render RENAMED"' <<<"$BASE_PAYLOAD")"
RC_E="$(run_observer_rc "$P_E")"; OUT_E="$(run_observer "$P_E")"
if [[ "$RC_E" -eq 1 ]] && grep -q "not found in the run by name" <<<"$OUT_E"; then
  pass "E: exit 1 and the reason names the rename"
else
  fail "E: rc=${RC_E}, output: ${OUT_E}"
fi

# ---- F: THE FAIL-OPEN HOLE -- in_progress + zero-date completedAt -----------
echo "Test F: in_progress with completedAt 0001-01-01 and empty conclusion -> exit 1"
P_F="$(jq --arg n "$EVAL_NAME" '(.jobs[] | select(.name == $n)) |= (.status = "in_progress" | .conclusion = "" | .completedAt = "0001-01-01T00:00:00Z")' <<<"$BASE_PAYLOAD")"
RC_F="$(run_observer_rc "$P_F")"; OUT_F="$(run_observer "$P_F")"
if [[ "$RC_F" -eq 1 ]] && grep -q "not 'completed'" <<<"$OUT_F"; then
  pass "F: fail-closed on a non-terminal construct before any duration inference"
else
  fail "F: rc=${RC_F}, output: ${OUT_F}"
fi

# ---- G: zero duration on a success -> exit 1 (green on no-op) ---------------
echo "Test G: completedAt == startedAt on a success -> exit 1"
P_G="$(jq --arg n "$SNAP_NAME" '(.jobs[].steps[]? | select(.name == $n)).completedAt = "2026-07-29T01:56:42Z"' <<<"$BASE_PAYLOAD")"
RC_G="$(run_observer_rc "$P_G")"; OUT_G="$(run_observer "$P_G")"
if [[ "$RC_G" -eq 1 ]] && grep -q "green on a no-op" <<<"$OUT_G"; then
  pass "G: exit 1 on a zero-duration success"
else
  fail "G: rc=${RC_G}, output: ${OUT_G}"
fi

# ---- H: a cancelled job elsewhere in the run -> exit 1 ----------------------
echo "Test H: any cancelled job in the run -> exit 1"
P_H="$(jq '.jobs += [{name: "Some other job", status: "completed", conclusion: "cancelled", startedAt: "2026-07-29T01:40:00Z", completedAt: "2026-07-29T01:41:00Z", steps: []}]' <<<"$BASE_PAYLOAD")"
RC_H="$(run_observer_rc "$P_H")"; OUT_H="$(run_observer "$P_H")"
if [[ "$RC_H" -eq 1 ]] && grep -q "cancelled jobs" <<<"$OUT_H"; then
  pass "H: exit 1 on a cancellation anywhere in a non-PR run"
else
  fail "H: rc=${RC_H}, output: ${OUT_H}"
fi

# ---- I: a timed_out job elsewhere in the run -> exit 1 ---------------------
echo "Test I: any timed_out job in the run -> exit 1"
P_I="$(jq '.jobs += [{name: "Some slow job", status: "completed", conclusion: "timed_out", startedAt: "2026-07-29T01:40:00Z", completedAt: "2026-07-29T02:40:00Z", steps: []}]' <<<"$BASE_PAYLOAD")"
RC_I="$(run_observer_rc "$P_I")"; OUT_I="$(run_observer "$P_I")"
if [[ "$RC_I" -eq 1 ]] && grep -q "timed-out jobs" <<<"$OUT_I"; then
  pass "I: exit 1 on a timeout anywhere in the run"
else
  fail "I: rc=${RC_I}, output: ${OUT_I}"
fi

# ---- J: empty job list -> exit 1 -------------------------------------------
echo "Test J: empty job list -> exit 1 (fail-closed)"
RC_J="$(run_observer_rc "$(jq '.jobs = []' <<<"$BASE_PAYLOAD")")"
if [[ "$RC_J" -eq 1 ]]; then
  pass "J: exit 1 on an empty job list"
else
  fail "J: expected exit 1, got ${RC_J}"
fi

# ---- K: gh absent from PATH -> exit 1 --------------------------------------
echo "Test K: gh absent from PATH -> exit 1"
set +e
EMPTY_BIN="${TMPDIR_ROOT}/emptybin"; mkdir -p "$EMPTY_BIN"
PATH="${EMPTY_BIN}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" >/dev/null 2>&1
RC_K=$?
set -e
if [[ "$RC_K" -ne 0 ]]; then
  pass "K: non-zero exit when gh is unavailable"
else
  fail "K: expected non-zero, got ${RC_K}"
fi

# ---- L: gh exits non-zero -> exit 1 ----------------------------------------
echo "Test L: gh exits non-zero -> exit 1"
printf '%s' "$BASE_PAYLOAD" > "$PAYLOAD_FILE"
set +e
GH_STUB_FAIL=1 PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" >/dev/null 2>&1
RC_L=$?
set -e
if [[ "$RC_L" -eq 1 ]]; then
  pass "L: exit 1 when gh fails"
else
  fail "L: expected exit 1, got ${RC_L}"
fi

# ---- M: unknown flag -> exit 2 with ZERO gh calls ---------------------------
echo "Test M: unknown flag -> exit 2, zero gh invocations"
: > "$GH_STUB_LOG"
set +e
PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --bogus >/dev/null 2>&1
RC_M=$?
set -e
CALLS_M="$(gh_call_count)"
if [[ "$RC_M" -eq 2 && "$CALLS_M" -eq 0 ]]; then
  pass "M: exit 2 before any gh round-trip (${CALLS_M} calls)"
else
  fail "M: rc=${RC_M}, gh calls=${CALLS_M}"
fi

# ---- N: --from-json -> zero gh calls, valid JSON with a verdict -------------
echo "Test N: --from-json -> zero gh calls, valid JSON carrying a verdict"
FROM_JSON_FILE="${TMPDIR_ROOT}/from.json"
printf '%s' "$BASE_PAYLOAD" > "$FROM_JSON_FILE"
: > "$GH_STUB_LOG"
set +e
OUT_N="$(PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --from-json "$FROM_JSON_FILE" --manifest "$REAL_MANIFEST" --format json 2>&1)"
RC_N=$?
set -e
CALLS_N="$(gh_call_count)"
if [[ "$RC_N" -eq 0 && "$CALLS_N" -eq 0 ]] \
   && jq -e '.verdict == "PASS" and (.constructs | length) >= 2' >/dev/null 2>&1 <<<"$OUT_N"; then
  pass "N: --from-json made ${CALLS_N} gh calls and emitted a valid PASS verdict"
else
  fail "N: rc=${RC_N}, gh calls=${CALLS_N}, output: ${OUT_N}"
fi

# ---- O: NON-VACUITY -- a manifest with zero assert rows -> exit 1 -----------
echo "Test O: manifest parsing to zero assert rows -> exit 1 (non-vacuity)"
EMPTY_MANIFEST="${TMPDIR_ROOT}/empty-manifest.tsv"
{
  printf '# a manifest whose assert rows have all been removed\n'
  printf 'tier\tkind\tid\tparent_job_id\tdisplay_name\tgate_level\tgate\tobserver\n'
  printf 'A\tjob\tinstall_matrix\t-\tInstall matrix (flag combinations)\tjob\tx\tignore\n'
} > "$EMPTY_MANIFEST"
printf '%s' "$BASE_PAYLOAD" > "$PAYLOAD_FILE"
set +e
OUT_O="$(PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$EMPTY_MANIFEST" 2>&1)"
RC_O=$?
set -e
if [[ "$RC_O" -eq 1 ]] && grep -q "the parse broke, this is not a pass" <<<"$OUT_O"; then
  pass "O: an empty assert set is a broken parse, not a clean run"
else
  fail "O: rc=${RC_O}, output: ${OUT_O}"
fi

# ---- P: step row with an unresolvable parent -> exit 1 ----------------------
echo "Test P: kind=step row whose parent has no kind=job row -> exit 1"
ORPHAN_MANIFEST="${TMPDIR_ROOT}/orphan-manifest.tsv"
{
  printf 'tier\tkind\tid\tparent_job_id\tdisplay_name\tgate_level\tgate\tobserver\n'
  printf 'B\tjob\tadmin_eval_render\t-\t%s\tjob\tx\tassert\n' "$EVAL_NAME"
  printf 'B\tstep\tdesign_gallery_snapshots\tno_such_job\t%s\tstep\tx\tassert\n' "$SNAP_NAME"
} > "$ORPHAN_MANIFEST"
printf '%s' "$BASE_PAYLOAD" > "$PAYLOAD_FILE"
set +e
OUT_P="$(PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$ORPHAN_MANIFEST" 2>&1)"
RC_P=$?
set -e
if [[ "$RC_P" -eq 1 ]] && grep -q "no matching kind=job row" <<<"$OUT_P"; then
  pass "P: exit 1 when a step row's parent display_name is unresolvable"
else
  fail "P: rc=${RC_P}, output: ${OUT_P}"
fi

# ---- Q: positive control on the SHIPPED manifest ---------------------------
echo "Test Q: the shipped manifest yields the two tier-B assert rows"
SHIPPED_ASSERTS="$(awk -F'\t' '/^#/{next} $1=="tier"{next} $8=="assert"{print $3}' "$REAL_MANIFEST")"
if grep -qx "admin_eval_render" <<<"$SHIPPED_ASSERTS" \
   && grep -qx "design_gallery_snapshots" <<<"$SHIPPED_ASSERTS" \
   && [[ "$(grep -c . <<<"$SHIPPED_ASSERTS")" -eq 2 ]]; then
  pass "Q: shipped manifest asserts exactly the two Phase 230 demotions"
else
  fail "Q: shipped manifest assert set is: ${SHIPPED_ASSERTS}"
fi

# ---- R: this script's OWN output is not a valid --from-json payload --------
# Regression pin for the ci-observe.yml wiring bug observed on run 30463975230:
# the render step fed `demotion-observation.json` (this script's output, an
# object carrying .verdict/.constructs) back into --from-json, which consumes a
# RUN payload (an object carrying .jobs). The shapes are deliberately distinct.
# This case proves the confusion fails CLOSED rather than rendering an empty or
# misleading receipt.
echo "Test R: observer output fed back into --from-json -> exit 1, not a silent empty receipt"
printf '%s' "$BASE_PAYLOAD" > "$PAYLOAD_FILE"
OWN_OUTPUT="${TMPDIR_ROOT}/own-output.json"
set +e
PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --format json > "$OWN_OUTPUT" 2>/dev/null
OUT_R="$(bash "$SCRIPT" --from-json "$OWN_OUTPUT" --format table 2>&1)"
RC_R=$?
set -e
if [[ "$RC_R" -ne 0 ]] && grep -q "not an object carrying a .jobs array" <<<"$OUT_R"; then
  pass "R: observer output rejected by --from-json (fail-closed)"
else
  fail "R: rc=${RC_R}, output: ${OUT_R}"
fi

# ---- S: ci-observe.yml never passes the observation file to --from-json ----
# The static half of the same regression pin. R proves the shapes are not
# interchangeable; S proves the shipped workflow does not make that mistake.
# Non-vacuity: the anchor assertion below flunks if --from-json disappears from
# the workflow entirely, so a rename can never make this test silently green.
echo "Test S: ci-observe.yml passes a run payload -- never demotion-observation.json -- to --from-json"
OBSERVE_WF="$(cd "${SCRIPT_DIR}/../.." && pwd)/.github/workflows/ci-observe.yml"
FROM_JSON_ARGS="$(grep -oE '\-\-from-json[[:space:]]+[^[:space:]]+' "$OBSERVE_WF" | awk '{print $2}')"
if [[ -z "$FROM_JSON_ARGS" ]]; then
  fail "S: no --from-json invocation found in ${OBSERVE_WF} -- the parse broke, this is not a pass"
elif grep -q 'demotion-observation.json' <<<"$FROM_JSON_ARGS"; then
  fail "S: ci-observe.yml feeds the observer's own output back into --from-json: ${FROM_JSON_ARGS}"
else
  pass "S: every --from-json argument is a run payload ($(tr '\n' ' ' <<<"$FROM_JSON_ARGS"))"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "ci-demotion-observer.test: FAIL"
  exit 1
fi
echo "ci-demotion-observer.test: PASS"
