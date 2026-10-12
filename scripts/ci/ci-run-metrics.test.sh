#!/usr/bin/env bash
# Self-test for ci-run-metrics.sh (Phase 230 / D-21 / SC-5).
#
# Hermetic: no real `gh` CLI or network call. A recording stub `gh` is placed first on
# PATH; it logs every invocation's argv and returns a scripted `gh run view --json jobs`
# payload so each case can assert exactly what the script under test computed.
#
# Test cases (mirrors the plan's <behavior> block):
#   A: canned run -> per-job table with name, conclusion, duration in both `Ns` and
#      `NmSSs` form.
#   B: `Admin eval render + probe (evidence only, not a merge gate)` (conclusion
#      "failure", continue-on-error) appears with duration 1053s / 17m33s -- NOT
#      filtered out for a non-"success" conclusion.
#   C: `Upgrade smoke` has a `completedAt` 1s before `startedAt` -> reported duration is
#      `0`, never negative.
#   D: unknown flag -> exit 2, `ci-run-metrics: FAIL: unknown arg: <arg>` on stderr,
#      fail-closed with ZERO recorded `gh` invocations (arg parsing fails before any
#      gh call is made).
#   E: `gh` absent from PATH -> exit non-zero, `ci-run-metrics: FAIL:` on stderr.
#   F: `gh` exits non-zero -> exit non-zero, `ci-run-metrics: FAIL:` on stderr, no
#      partial table on stdout.
#   G: empty job list -> exit non-zero, `ci-run-metrics: FAIL:` on stderr, no partial
#      table on stdout.
#   H: `--format json` emits valid JSON with the same duration/clamp/filter semantics.
#
# Task 2 (windowed baseline-reproduction mode) cases:
#   I: window mode emits the exact header `| trigger | n | mean | p50 | max | outcomes |`
#      and correct per-trigger n/mean/p50/max/outcomes, pinning the p50 index rule
#      (sort ascending, 0-based index floor(n/2)) against BOTH a fixed odd-length group
#      (pull_request, n=5) and a fixed even-length group (push, n=4).
#   J: a run whose `updatedAt` precedes its `createdAt` (schedule, n=1) reports duration
#      `0`, never negative -- same clamp rule as the single-run mode.
#   K: `--mode jobspan` produces a strictly smaller mean than `--mode wall` on the exact
#      same canned window (job-span excludes queue time).
#   L: an empty run list (`gh run list` returns `[]`) -> exit non-zero, `ci-run-metrics:
#      FAIL:` on stderr, no partial table on stdout (fail-closed).
#
# No network access and no GH_TOKEN are required or read anywhere in this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ci-run-metrics.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
: > "$GH_STUB_LOG"

# Canned `gh run view --json jobs --jq '.jobs'` payload: one job with a large real
# duration that concludes "failure" under continue-on-error (b), and one job whose
# completedAt precedes its startedAt by 1s (a), exactly mirroring run 30390832059.
CANNED_JOBS='[
  {"name":"Admin eval render + probe (evidence only, not a merge gate)","conclusion":"failure","startedAt":"2026-07-28T19:11:21Z","completedAt":"2026-07-28T19:28:54Z"},
  {"name":"Upgrade smoke (published source series -> local candidate)","conclusion":"skipped","startedAt":"2026-07-28T19:11:14Z","completedAt":"2026-07-28T19:11:13Z"},
  {"name":"Fast checks (milestone/installer/contracts/snapshot/ledger guards)","conclusion":"success","startedAt":"2026-07-28T19:11:11Z","completedAt":"2026-07-28T19:11:31Z"}
]'

# Canned `gh run list --json databaseId,event,createdAt,updatedAt,conclusion` window
# (Task 2). Three trigger groups deliberately sized to pin the p50 index rule:
#   pull_request (n=5, odd)  -- wall durations sorted [60,120,180,240,300]s
#   push         (n=4, even) -- wall durations sorted [60,180,300,420]s
#   schedule     (n=1)       -- updatedAt 1s BEFORE createdAt -> raw -1s, clamp to 0
WINDOW_FULL_RUNS='[
  {"databaseId":2001,"event":"pull_request","conclusion":"success","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:01:00Z"},
  {"databaseId":2002,"event":"pull_request","conclusion":"success","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:02:00Z"},
  {"databaseId":2003,"event":"pull_request","conclusion":"failure","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:03:00Z"},
  {"databaseId":2004,"event":"pull_request","conclusion":"success","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:04:00Z"},
  {"databaseId":2005,"event":"pull_request","conclusion":"cancelled","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:05:00Z"},
  {"databaseId":3001,"event":"push","conclusion":"success","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:01:00Z"},
  {"databaseId":3002,"event":"push","conclusion":"success","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:03:00Z"},
  {"databaseId":3003,"event":"push","conclusion":"success","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:05:00Z"},
  {"databaseId":3004,"event":"push","conclusion":"failure","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:07:00Z"},
  {"databaseId":4001,"event":"schedule","conclusion":"skipped","createdAt":"2026-01-01T00:00:01Z","updatedAt":"2026-01-01T00:00:00Z"}
]'

# Per-run job lists for the pull_request group only (2001-2005), used by `--mode
# jobspan`. Each job starts 20s after its run's createdAt, so jobspan is exactly
# 20s less than wall for every one of these five runs -- a fixed, reproducible gap.
JOBS_2001='{"jobs":[{"name":"job","conclusion":"success","startedAt":"2026-01-01T00:00:20Z","completedAt":"2026-01-01T00:01:00Z"}]}'
JOBS_2002='{"jobs":[{"name":"job","conclusion":"success","startedAt":"2026-01-01T00:00:20Z","completedAt":"2026-01-01T00:02:00Z"}]}'
JOBS_2003='{"jobs":[{"name":"job","conclusion":"failure","startedAt":"2026-01-01T00:00:20Z","completedAt":"2026-01-01T00:03:00Z"}]}'
JOBS_2004='{"jobs":[{"name":"job","conclusion":"success","startedAt":"2026-01-01T00:00:20Z","completedAt":"2026-01-01T00:04:00Z"}]}'
JOBS_2005='{"jobs":[{"name":"job","conclusion":"cancelled","startedAt":"2026-01-01T00:00:20Z","completedAt":"2026-01-01T00:05:00Z"}]}'

cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
# Recording stub for \`gh\` (test-only). Logs argv, returns a scripted response.
set -euo pipefail
echo "\$*" >> "${GH_STUB_LOG}"
if [[ "\${1:-}" == "run" && "\${2:-}" == "list" ]]; then
  case "\${GH_STUB_MODE:-}" in
    window_full)
      echo '${WINDOW_FULL_RUNS}'
      exit 0
      ;;
    window_empty)
      echo '[]'
      exit 0
      ;;
  esac
  echo "gh stub: unexpected 'run list' invocation for mode \${GH_STUB_MODE:-}: \$*" >&2
  exit 1
fi
if [[ "\${1:-}" == "run" && "\${2:-}" == "view" ]]; then
  RUN_ID_ARG="\${3:-}"
  case "\${GH_STUB_MODE:-ok}" in
    ok)
      echo '${CANNED_JOBS}'
      exit 0
      ;;
    empty)
      echo '[]'
      exit 0
      ;;
    nonzero)
      echo "gh stub: simulated failure" >&2
      exit 1
      ;;
    window_full)
      case "\$RUN_ID_ARG" in
        2001) echo '${JOBS_2001}';;
        2002) echo '${JOBS_2002}';;
        2003) echo '${JOBS_2003}';;
        2004) echo '${JOBS_2004}';;
        2005) echo '${JOBS_2005}';;
        *)
          echo "gh stub: no jobspan fixture stubbed for run \${RUN_ID_ARG}" >&2
          exit 1
          ;;
      esac
      exit 0
      ;;
  esac
fi
echo "gh stub: unexpected invocation: \$*" >&2
exit 1
STUB
chmod +x "${STUB_BIN_DIR}/gh"

run_script() {
  # Runs the script with the stub PATH and captures stdout/stderr/exit separately.
  local out err rc
  out="${TMPDIR_ROOT}/stdout"
  err="${TMPDIR_ROOT}/stderr"
  set +e
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" "$@" >"$out" 2>"$err"
  rc=$?
  set -e
  echo "$rc"
}

# ---- Test A/B/C: canned run -> table with clamp + no-filter -------------
echo "Test A/B/C: --jobs <id> emits a per-job table; 1053s/17m33s failure row not filtered; negative duration clamped to 0"
: > "$GH_STUB_LOG"
GH_STUB_MODE="ok"
export GH_STUB_MODE
RC=$(run_script --jobs 30390832059 --repo szTheory/sigra)
export GH_STUB_MODE=""
OUT="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC" -eq 0 ]] \
  && echo "$OUT" | grep -qE 'Admin eval render.*failure.*1053s.*17m33s' \
  && echo "$OUT" | grep -qE 'Upgrade smoke.*skipped[[:space:]]+0s[[:space:]]+0m0s' \
  && ! echo "$OUT" | grep -q -- '-1s'; then
  pass "table row present for failing job at 1053s/17m33s; negative duration clamped to 0s (exit ${RC})"
else
  fail "exit=${RC} output=<${OUT}>"
fi

# ---- Test D: unknown flag -> exit 2, zero gh invocations ----------------
echo "Test D: unknown flag -> exit 2, ci-run-metrics: FAIL: unknown arg, ZERO gh invocations"
: > "$GH_STUB_LOG"
RC=$(run_script --bogus-flag)
ERR="$(cat "${TMPDIR_ROOT}/stderr")"
CALL_COUNT_D=$(wc -l <"$GH_STUB_LOG" | tr -d ' ')

if [[ "$RC" -eq 2 ]] \
  && echo "$ERR" | grep -q 'ci-run-metrics: FAIL: unknown arg: --bogus-flag' \
  && [[ "$CALL_COUNT_D" -eq 0 ]]; then
  pass "exit 2, correct message, zero gh calls (fail-closed before any gh invocation)"
else
  fail "exit=${RC} stderr=<${ERR}> gh_call_count=${CALL_COUNT_D}"
fi

# ---- Test E: gh absent from PATH -> non-zero exit, FAIL message ---------
echo "Test E: gh absent from PATH -> non-zero exit, ci-run-metrics: FAIL: message"
EMPTY_PATH_DIR="${TMPDIR_ROOT}/empty-bin"
mkdir -p "$EMPTY_PATH_DIR"
set +e
PATH="${EMPTY_PATH_DIR}:/usr/bin:/bin" bash "$SCRIPT" --jobs 1 >"${TMPDIR_ROOT}/stdout" 2>"${TMPDIR_ROOT}/stderr"
RC_E=$?
set -e
ERR_E="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_E="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_E" -ne 0 ]] && echo "$ERR_E" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_E" ]]; then
  pass "exit non-zero (${RC_E}), FAIL message, no partial stdout"
else
  fail "exit=${RC_E} stderr=<${ERR_E}> stdout=<${OUT_E}>"
fi

# ---- Test F: gh exits non-zero -> non-zero exit, no partial output ------
echo "Test F: gh exits non-zero -> non-zero exit, ci-run-metrics: FAIL: message, no partial table"
: > "$GH_STUB_LOG"
GH_STUB_MODE="nonzero"
export GH_STUB_MODE
RC_F=$(run_script --jobs 30390832059)
export GH_STUB_MODE=""
ERR_F="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_F="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_F" -ne 0 ]] && echo "$ERR_F" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_F" ]]; then
  pass "exit non-zero (${RC_F}) on gh failure, no partial table emitted"
else
  fail "exit=${RC_F} stderr=<${ERR_F}> stdout=<${OUT_F}>"
fi

# ---- Test G: empty job list -> non-zero exit, no partial output ---------
echo "Test G: empty job list -> non-zero exit, ci-run-metrics: FAIL: message, no partial table"
: > "$GH_STUB_LOG"
GH_STUB_MODE="empty"
export GH_STUB_MODE
RC_G=$(run_script --jobs 30390832059)
export GH_STUB_MODE=""
ERR_G="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_G="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_G" -ne 0 ]] && echo "$ERR_G" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_G" ]]; then
  pass "exit non-zero (${RC_G}) on empty job list, no partial table emitted"
else
  fail "exit=${RC_G} stderr=<${ERR_G}> stdout=<${OUT_G}>"
fi

# ---- Test H: --format json emits valid JSON with same semantics ---------
echo "Test H: --format json emits valid JSON; failure-conclusion job present; negative duration clamped"
: > "$GH_STUB_LOG"
GH_STUB_MODE="ok"
export GH_STUB_MODE
RC_H=$(run_script --jobs 30390832059 --format json)
export GH_STUB_MODE=""
OUT_H="$(cat "${TMPDIR_ROOT}/stdout")"

JSON_OK=0
if echo "$OUT_H" | python3 -c "
import json, sys
data = json.load(sys.stdin)
jobs = {j['name']: j for j in data}
admin = jobs.get('Admin eval render + probe (evidence only, not a merge gate)')
upgrade = jobs.get('Upgrade smoke (published source series -> local candidate)')
assert admin is not None, 'admin eval render job missing'
assert admin['conclusion'] == 'failure', admin
assert admin['duration_seconds'] == 1053, admin
assert upgrade is not None, 'upgrade smoke job missing'
assert upgrade['duration_seconds'] == 0, upgrade
" 2>"${TMPDIR_ROOT}/json-check-err"; then
  JSON_OK=1
fi

if [[ "$RC_H" -eq 0 && "$JSON_OK" -eq 1 ]]; then
  pass "--format json valid, duration/clamp/no-filter semantics match table mode"
else
  fail "exit=${RC_H} json_check=<$(cat "${TMPDIR_ROOT}/json-check-err" 2>/dev/null)> output=<${OUT_H}>"
fi

# ---- Test I/J: window mode header + p50 (odd n=5, even n=4) + clamp ------
echo "Test I/J: window --mode wall table header, per-trigger n/mean/p50/max/outcomes, negative clamp"
: > "$GH_STUB_LOG"
GH_STUB_MODE="window_full"
export GH_STUB_MODE
RC_I=$(run_script --limit 40 --format table)
export GH_STUB_MODE=""
OUT_I="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_I" -eq 0 ]] \
  && echo "$OUT_I" | grep -qF '| trigger | n | mean | p50 | max | outcomes |' \
  && echo "$OUT_I" | grep -qF '| pull_request | 5 | 3.0m | 3.0m | 5.0m | 3 pass / 2 fail |' \
  && echo "$OUT_I" | grep -qF '| push | 4 | 4.0m | 5.0m | 7.0m | 3 pass / 1 fail |' \
  && echo "$OUT_I" | grep -qF '| schedule | 1 | 0.0m | 0.0m | 0.0m | 0 pass / 1 fail |'; then
  pass "exact header + odd(n=5)/even(n=4) p50 index rule + negative-duration clamp all correct (exit ${RC_I})"
else
  fail "exit=${RC_I} output=<${OUT_I}>"
fi

# ---- Test K: --mode jobspan strictly smaller than --mode wall (same window) ---
echo "Test K: --mode jobspan produces a strictly smaller mean than --mode wall on the identical canned window"
: > "$GH_STUB_LOG"
GH_STUB_MODE="window_full"
export GH_STUB_MODE
RC_WALL=$(run_script --limit 40 --event pull_request --mode wall --format json)
OUT_WALL="$(cat "${TMPDIR_ROOT}/stdout")"
RC_JOBSPAN=$(run_script --limit 40 --event pull_request --mode jobspan --format json)
OUT_JOBSPAN="$(cat "${TMPDIR_ROOT}/stdout")"
export GH_STUB_MODE=""

JOBSPAN_OK=0
if [[ "$RC_WALL" -eq 0 && "$RC_JOBSPAN" -eq 0 ]] && python3 -c "
import json, sys
wall = json.loads('''${OUT_WALL}''')[0]
jobspan = json.loads('''${OUT_JOBSPAN}''')[0]
assert wall['mean_seconds'] == 180, wall
assert jobspan['mean_seconds'] == 160, jobspan
assert jobspan['mean_seconds'] < wall['mean_seconds'], (jobspan, wall)
" 2>"${TMPDIR_ROOT}/jobspan-check-err"; then
  JOBSPAN_OK=1
fi

if [[ "$JOBSPAN_OK" -eq 1 ]]; then
  pass "jobspan mean (160s) strictly less than wall mean (180s) on the same window"
else
  fail "wall_rc=${RC_WALL} jobspan_rc=${RC_JOBSPAN} check=<$(cat "${TMPDIR_ROOT}/jobspan-check-err" 2>/dev/null)> wall=<${OUT_WALL}> jobspan=<${OUT_JOBSPAN}>"
fi

# ---- Test L: empty run list -> fail-closed, no partial table -------------
echo "Test L: empty run list -> non-zero exit, ci-run-metrics: FAIL: message, no partial table"
: > "$GH_STUB_LOG"
GH_STUB_MODE="window_empty"
export GH_STUB_MODE
RC_L=$(run_script --limit 40 --format table)
export GH_STUB_MODE=""
ERR_L="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_L="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_L" -ne 0 ]] && echo "$ERR_L" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_L" ]]; then
  pass "exit non-zero (${RC_L}) on empty run list, no partial table emitted"
else
  fail "exit=${RC_L} stderr=<${ERR_L}> stdout=<${OUT_L}>"
fi

# ---- Summary -------------------------------------------------------------
run_window_extension_tests() {
echo "Test V: snapshot replay reads verified files offline without contacting gh"
before_replay_calls="$(wc -l <"$WINDOW_API_LOG" | tr -d ' ')"
if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --replay --source-bundle "$WINDOW_BUNDLE" --format json >"${TMPDIR_ROOT}/snapshot-replay.json" 2>"${TMPDIR_ROOT}/snapshot-replay.err" \
  && jq -e '.status=="complete" and .populations.pull_request.run_count==100 and .populations.pull_request.api_total_count==125 and .populations.manual_records==1 and .populations.release_push_records==1' "${TMPDIR_ROOT}/snapshot-replay.json" >/dev/null \
  && [[ "$(wc -l <"$WINDOW_API_LOG" | tr -d ' ')" -eq "$before_replay_calls" ]]; then
  pass "source bundle replays offline with API totals and outcomes intact"
else fail "snapshot replay error=$(cat "${TMPDIR_ROOT}/snapshot-replay.err") output=$(cat "${TMPDIR_ROOT}/snapshot-replay.json" 2>/dev/null)"; fi

echo "Test V2: replay exposes source-backed cohort ranks, stages, provenance and unknowns"
if jq -e '. as $r |
  ($r.ranked_by_wait.pull_request.n >= 1) and ($r.ranked_by_runner.pull_request.n >= 1) and
  (($r.ranked_by_wait.pull_request.rows|map(.identity)|unique|length) == ($r.ranked_by_wait.pull_request.rows|length)) and
  ($r.stage_costs.pull_request.setup.status == "measured") and
  ($r.stage_costs.pull_request.cache_restore_download.status == "measured" and $r.stage_costs.pull_request.cache_restore_download.total == (5 * $r.stage_costs.pull_request.cache_restore_download.n)) and
  ($r.cache_outcome.browser_binaries == "miss") and
  ($r.runner_image.pull_request.runner_os == "Linux" and $r.runner_image.pull_request.image_version == "20261001.1") and
  ($r.configured_versions.pull_request.playwright == "1.59.1") and
  ($r.observed_versions.pull_request.playwright.value == null) and
  ($r.observed_versions.pull_request.playwright.reason != null) and
  ($r.reporter_overhead.playwright.status == "unmeasured") and
  ($r.required_result_wait.status == "unknown") and
  ($r.instrumented_full_pr.complete == false and $r.instrumented_full_pr.status == "insufficient_data") and
  ($r.cohorts.docs_only.status == "measured" and $r.cohorts.docs_only.n == 1) and
  ([$r.test_rows[]|select(.source=="exunit")]|length)==0 and
  ([$r.test_rows[]|select(.source=="playwright")]|length)==1 and
  $r.test_rows[0].suite_elapsed_ms == 125 and $r.test_rows[0].sum_test_duration_ms == 100
' "${TMPDIR_ROOT}/snapshot-replay.json" >/dev/null; then
  pass "replay separates rankings, stages, cache, runtime and zero-sample unknowns"
else fail "replay metrics missing or fabricated: $(jq -c '{ranked_by_wait,ranked_by_runner,stage_costs,cache_outcome,runner_image,configured_versions,observed_versions,reporter_overhead,test_rows,cohorts}' "${TMPDIR_ROOT}/snapshot-replay.json" 2>/dev/null)"; fi

echo "Test V3: current failures stay bounded and one-off red evidence is not called flaky"
if jq -e '
  (.failure_analysis.inspected_family_count <= 12) and
  (all(.failure_analysis.per_event_counts[]; . <= 4)) and
  ([.failure_analysis.failure_signatures.signatures[]]|length <= 3) and
  ([.failure_class.application_test_failure[]?|select(.outcome=="failure")]|length == 1) and
  (.failure_signatures.status == "unknown") and (.diagnostics_status.missing_count > 0) and
  ([.failure_analysis.failure_signatures.signatures[].references[]?|select(.run_id != null and .attempt != null and .log_reference != null)]|length == 0) and
  (all(.failure_analysis.families[]; .outcome != "failure" or .failure_class == "application_test_failure" or .failure_class == "unknown_failure"))
' "${TMPDIR_ROOT}/snapshot-replay.json" >/dev/null; then
  pass "failure shortlist inspects at most twelve families, cites current evidence, and reports unknown when diagnostics are incomplete"
else fail "failure analysis invalid: $(jq -c '{failure_analysis,failure_signatures,failure_class}' "${TMPDIR_ROOT}/snapshot-replay.json" 2>/dev/null)"; fi

echo "Test W: concurrent lock, interruption ledger, and request ceiling are enforced"
LOCKED_BUNDLE="${TMPDIR_ROOT}/locked-bundle"
mkdir "${LOCKED_BUNDLE}.lock"
printf '{"owner":"test"}\n' >"${LOCKED_BUNDLE}.lock/owner.json"
locked_before="$(shasum -a 256 "${LOCKED_BUNDLE}.lock/owner.json" | awk '{print $1}')"
set +e
PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --collect --cutoff 2026-10-12T00:00:00Z --source-bundle "$LOCKED_BUNDLE" >/dev/null 2>&1
locked_rc=$?
set -e
locked_after="$(shasum -a 256 "${LOCKED_BUNDLE}.lock/owner.json" | awk '{print $1}')"
if [[ "$locked_rc" -ne 0 && "$locked_before" == "$locked_after" && ! -e "$LOCKED_BUNDLE" ]]; then pass "an active snapshot lock prevents mutation"; else fail "lock rc=$locked_rc before=$locked_before after=$locked_after"; fi

INTERRUPTED_BUNDLE="${TMPDIR_ROOT}/interrupted-bundle"
set +e
CI_METRICS_TEST_MODE=1 CI_METRICS_TEST_INTERRUPT_AFTER_POPULATION=pull_request PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --collect --cutoff 2026-10-12T00:00:00Z --source-bundle "$INTERRUPTED_BUNDLE" >/dev/null 2>"${TMPDIR_ROOT}/interrupted.err"
interrupt_rc=$?
set -e
if [[ "$interrupt_rc" -eq 130 ]] && jq -e '.status=="incomplete" and .stop_reason=="interrupted" and .request_count==5 and .selection_ledger.populations[0].population=="pull_request" and (.selection_ledger.populations[0].selected_run_ids|length)==100' "$INTERRUPTED_BUNDLE/manifest.json" >/dev/null && jq -e '.status=="incomplete" and .request_count==5 and (.requests|length)==5' "$INTERRUPTED_BUNDLE/request-ledger.json" >/dev/null; then
  pass "signal interruption leaves request and selected-run ledgers with incomplete status"
else fail "interruption rc=$interrupt_rc manifest=$(cat "$INTERRUPTED_BUNDLE/manifest.json" 2>/dev/null) ledger=$(cat "$INTERRUPTED_BUNDLE/request-ledger.json" 2>/dev/null) err=$(cat "${TMPDIR_ROOT}/interrupted.err")"; fi
if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --replay --source-bundle "$INTERRUPTED_BUNDLE" --format json >"${TMPDIR_ROOT}/interrupted-replay.json" 2>"${TMPDIR_ROOT}/interrupted-replay.err" \
  && jq -e '.status=="incomplete" and (.selection_ledger.populations[0].selected_run_ids|length)==100' "${TMPDIR_ROOT}/interrupted-replay.json" >/dev/null; then pass "incomplete snapshots replay their verified ledgers offline"; else fail "incomplete replay failed: $(cat "${TMPDIR_ROOT}/interrupted-replay.err")"; fi

LIMIT_BUNDLE="${TMPDIR_ROOT}/request-limit-bundle"
set +e
CI_METRICS_TEST_MODE=1 CI_METRICS_TEST_PRIOR_REQUESTS=599 PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --collect --cutoff 2026-10-12T00:00:00Z --source-bundle "$LIMIT_BUNDLE" >/dev/null 2>&1
limit_rc=$?
set -e
if [[ "$limit_rc" -ne 0 ]] && jq -e '.status=="incomplete" and .request_count==600 and .stop_reason=="request_limit_exhausted"' "$LIMIT_BUNDLE/manifest.json" >/dev/null; then pass "request 600 is allowed and the following event query is stopped"; else fail "request limit rc=$limit_rc manifest=$(cat "$LIMIT_BUNDLE/manifest.json" 2>/dev/null)"; fi

echo "Test X: redirect validation accepts only the exact HTTPS hosts and never echoes signed queries"
redirect_good=0
for url in 'https://pipelines.actions.githubusercontent.com/download/file?sig=SECRET_VALUE' 'https://productionresultssa123.blob.core.windows.net/container/file?sig=SECRET_VALUE'; do
  redirect_host="$(PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --validate-redirect "$url" 2>/dev/null || true)"
  if [[ "$redirect_host" == pipelines.actions.githubusercontent.com || "$redirect_host" == productionresultssa123.blob.core.windows.net ]]; then redirect_good=$((redirect_good+1)); fi
  ! grep -F 'SECRET_VALUE' <<<"$redirect_host" >/dev/null || redirect_good=0
done
redirect_bad=0
for url in 'http://pipelines.actions.githubusercontent.com/x' 'https://evil.pipelines.actions.githubusercontent.com/x' 'https://productionresultssa123evil.blob.core.windows.net/x' 'https://user@pipelines.actions.githubusercontent.com/x' 'https://pipelines.actions.githubusercontent.com/x#fragment' 'https://pipelines.actions.githubusercontent.com:444/x' 'https://pipelines.actions.githubusercontent.com' 'https://pipelines.actions.githubusercontent.com.evil.test/x' 'https://127.0.0.1/x'; do
  if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --validate-redirect "$url" >/dev/null 2>&1; then redirect_bad=$((redirect_bad+1)); fi
done
if [[ "$redirect_good" -eq 2 && "$redirect_bad" -eq 0 ]]; then pass "both exact hosts accepted; downgrade, deceptive host, credentials, fragment, port, path and IP rejected"; else fail "redirect accepts=$redirect_good rejects=$redirect_bad"; fi

echo "Test Y: artifact provenance, bounded ZIP handling, and log redaction fail closed"
cat >"${TMPDIR_ROOT}/artifact-run.json" <<'JSON'
{"id":5000,"head_sha":"sha-5000"}
JSON
cat >"${TMPDIR_ROOT}/artifact.json" <<'JSON'
{"id":77,"name":"playwright-report-5000","digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","expired":false,"workflow_run":{"id":5000,"head_sha":"sha-5000"},"archive_download_url":"https://api.github.com/download?sig=DO_NOT_RETAIN"}
JSON
if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --validate-artifact-json "${TMPDIR_ROOT}/artifact.json" --run-json "${TMPDIR_ROOT}/artifact-run.json" >"${TMPDIR_ROOT}/artifact-valid.json" \
  && jq -e '.status=="verified" and .artifact_id==77 and .run_id==5000' "${TMPDIR_ROOT}/artifact-valid.json" >/dev/null; then
  pass "GitHub artifact ID, producing run, SHA and digest are source-bound"
else fail "valid artifact rejected: $(cat "${TMPDIR_ROOT}/artifact-valid.json" 2>/dev/null)"; fi
jq '.workflow_run.id=5001' "${TMPDIR_ROOT}/artifact.json" >"${TMPDIR_ROOT}/artifact-wrong-run.json"
jq '.workflow_run.head_sha="other-sha"' "${TMPDIR_ROOT}/artifact.json" >"${TMPDIR_ROOT}/artifact-wrong-sha.json"
jq '.expired=true' "${TMPDIR_ROOT}/artifact.json" >"${TMPDIR_ROOT}/artifact-expired.json"
if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --validate-artifact-json "${TMPDIR_ROOT}/artifact-wrong-run.json" --run-json "${TMPDIR_ROOT}/artifact-run.json" | jq -e '.diagnostic=="artifact_origin_mismatch"' >/dev/null \
  && PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --validate-artifact-json "${TMPDIR_ROOT}/artifact-wrong-sha.json" --run-json "${TMPDIR_ROOT}/artifact-run.json" | jq -e '.diagnostic=="artifact_origin_mismatch"' >/dev/null \
  && PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --validate-artifact-json "${TMPDIR_ROOT}/artifact-expired.json" --run-json "${TMPDIR_ROOT}/artifact-run.json" | jq -e '.status=="expired_input"' >/dev/null; then
  pass "wrong-run, wrong-SHA and expired artifacts are diagnostics, not measurements"
else fail "artifact binding/expiry validation accepted unsafe metadata"; fi
python3 - "${TMPDIR_ROOT}" <<'PY'
import pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(root / "timing-good.zip", "w") as z:
    z.writestr("nested/timing.json", '{"duration":12}')
    z.writestr("test-results/pixel.png", b"synthetic screenshot fixture")
with zipfile.ZipFile(root / "timing-traversal.zip", "w") as z:
    z.writestr("../timing.json", '{"duration":12}')
with zipfile.ZipFile(root / "timing-oversized.zip", "w") as z:
    z.writestr("timing.json", '{"duration":' + '1' * (64 * 1024 * 1024) + '}')
PY
if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --extract-timing-zip "${TMPDIR_ROOT}/timing-good.zip" --output-dir "${TMPDIR_ROOT}/timing-out" | jq -e '.status=="accepted" and .skipped_non_json_members==["pixel.png"]' >/dev/null \
  && ! PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --extract-timing-zip "${TMPDIR_ROOT}/timing-traversal.zip" --output-dir "${TMPDIR_ROOT}/timing-bad-out" >/dev/null 2>&1 \
  && ! PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --extract-timing-zip "${TMPDIR_ROOT}/timing-oversized.zip" --output-dir "${TMPDIR_ROOT}/timing-large-out" >/dev/null 2>&1; then
  pass "timing JSON extracts while traversal and 64 MiB members are rejected"
else fail "ZIP member validation failed"; fi
printf '%s\n' 'ghp_abcdefghijklmnopqrstuvwxyz1234567890' 'Authorization: Bearer secret-token' 'password=cleartext' 'AWS_SECRET_ACCESS_KEY=aws-cleartext' 'https://blob.example/file?sig=SIGNED_QUERY' >"${TMPDIR_ROOT}/sensitive.log"
if PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --redact-log "${TMPDIR_ROOT}/sensitive.log" --redacted-output "${TMPDIR_ROOT}/redacted.log" \
  && ! grep -F 'ghp_abcdefghijklmnopqrstuvwxyz1234567890' "${TMPDIR_ROOT}/redacted.log" >/dev/null \
  && ! grep -F 'secret-token' "${TMPDIR_ROOT}/redacted.log" >/dev/null \
  && ! grep -F 'cleartext' "${TMPDIR_ROOT}/redacted.log" >/dev/null \
  && ! grep -F 'aws-cleartext' "${TMPDIR_ROOT}/redacted.log" >/dev/null \
  && ! grep -F 'SIGNED_QUERY' "${TMPDIR_ROOT}/redacted.log" >/dev/null; then pass "known token, bearer, password and signed-query patterns are redacted"; else fail "sensitive log content survived redaction"; fi
}

echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "ci-run-metrics.test: FAIL"
  exit 1
fi

echo "ci-run-metrics.test: PASS"

# ---- Source-complete wall-mode contract (Phase 235-16) ------------------
echo "Test M: retained source pages are the authoritative wall-mode input"
cat >"${TMPDIR_ROOT}/source-pages.json" <<'JSON'
{
  "resource":"GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs",
  "query":{"created":"2026-08-03T21:37:08Z..2026-08-04T01:00:00Z","per_page":100},
  "requested_pages":[1,2],"terminal_page":2,"exhausted":true,
  "pages":[
    {"page":1,"returned_count":10,"runs":[
      {"run_id":11,"url":"https://example.test/11","event":"pull_request","conclusion":"failure","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:07Z"},
      {"run_id":10,"url":"https://example.test/10","event":"pull_request","conclusion":"success","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:07Z"},
      {"run_id":12,"url":"https://example.test/12","event":"pull_request","conclusion":"cancelled","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:08Z"},
      {"run_id":13,"url":"https://example.test/13","event":"pull_request","conclusion":"timed_out","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:09Z"},
      {"run_id":14,"url":"https://example.test/14","event":"pull_request","conclusion":"neutral","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:10Z"},
      {"run_id":15,"url":"https://example.test/15","event":"pull_request","conclusion":"skipped","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:11Z"},
      {"run_id":16,"url":"https://example.test/16","event":"pull_request","conclusion":"stale","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:12Z"},
      {"run_id":17,"url":"https://example.test/17","event":"pull_request","conclusion":"action_required","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:13Z"},
      {"run_id":18,"url":"https://example.test/18","event":"pull_request","conclusion":"startup_failure","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:14Z"},
      {"run_id":19,"url":"https://example.test/19","event":"pull_request","conclusion":"success","created_at":"2026-08-03T21:37:08Z","updated_at":"2026-08-03T21:49:15Z"}
    ]},
    {"page":2,"returned_count":0,"runs":[]}
  ]
}
JSON
set +e
PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --source-pages "${TMPDIR_ROOT}/source-pages.json" --mode wall --event pull_request --since 2026-08-03T21:37:08Z --until 2026-08-04T01:00:00Z --threshold 720 --format json >"${TMPDIR_ROOT}/source-out" 2>"${TMPDIR_ROOT}/source-err"
RC_M=$?
set -e
if [[ "$RC_M" -eq 0 ]] && jq -e '
  .eligible_pr_run_count == 10 and .statistics.p50_seconds == 723 and
  .verdict == "miss" and .status == "measured" and
  .runs[0].run_id == 10 and .runs[1].run_id == 11 and
  .selected_poles.median_run_id == 15 and .selected_poles.maximum_run_id == 19
' "${TMPDIR_ROOT}/source-out" >/dev/null; then
  pass "source pages preserve all conclusions, boundary equality, and stable run-id ordering"
else
  fail "source mode exit=${RC_M} stderr=<$(cat "${TMPDIR_ROOT}/source-err")> output=<$(cat "${TMPDIR_ROOT}/source-out")>"
fi

echo "Test N: source chronology, completeness, duplicates, and strict threshold fail closed"
SOURCE_FAULTS_OK=1
for mutation in \
  '.pages[0].runs[0].updated_at="2026-08-03T21:37:07Z"' \
  '.requested_pages=[1,3]' \
  '.pages[1].returned_count=1' \
  '.pages[0].runs[1].run_id=.pages[0].runs[0].run_id' \
  '.pages[0].runs[0].conclusion=""'; do
  jq "$mutation" "${TMPDIR_ROOT}/source-pages.json" >"${TMPDIR_ROOT}/mutant.json"
  if PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --source-pages "${TMPDIR_ROOT}/mutant.json" --mode wall --event pull_request --since 2026-08-03T21:37:08Z --until 2026-08-04T01:00:00Z --threshold 720 --format json >/dev/null 2>&1; then SOURCE_FAULTS_OK=0; fi
done
if [[ "$SOURCE_FAULTS_OK" -eq 1 ]]; then pass "source-page faults rejected"; else fail "a source-page fault was accepted"; fi

# ---- Phase 252: bounded preflight, guarded collect, immutable replay ------
echo "Test O: preflight and collection route every live request through explicit guarded GET"
GH_API_BIN="${TMPDIR_ROOT}/gh-api-bin"
HOST_PATH="$PATH"
mkdir -p "$GH_API_BIN"
GH_API_LOG="${TMPDIR_ROOT}/gh-api-calls.log"
: >"$GH_API_LOG"
cat >"${GH_API_BIN}/gh" <<'GHAPI'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --version ]]; then echo 'gh version test'; exit 0; fi
printf '%s\n' "$*" >>"${GH_API_LOG}"
[[ "${1:-}" == api && "${2:-}" == --method && "${3:-}" == GET ]] || { echo 'expected explicit GET' >&2; exit 2; }
endpoint="${4:-}"
case "$endpoint" in
  rate_limit|/rate_limit)
    if [[ "${GH_API_MODE:-}" == rate403 ]]; then echo 'HTTP 403 rate limit; x-ratelimit-reset: 1900000000' >&2; exit 1; fi
    if [[ "${GH_API_MODE:-}" == transient && ! -e "${GH_API_FAIL_ONCE_FILE}" ]]; then touch "$GH_API_FAIL_ONCE_FILE"; echo 'HTTP 503 temporary service failure' >&2; exit 1; fi
    if [[ "${GH_API_MODE:-}" == core ]]; then echo '{"resources":{"core":{"remaining":250,"reset":1900000000}}}'; else echo '{"resources":{"core":{"remaining":5000,"reset":1900000000}}}'; fi;;
  /repos/szTheory/sigra/branches/main/protection/required_status_checks) echo '{"contexts":["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"]}';;
  /repos/szTheory/sigra/rules/branches/main) echo '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"Library tests"},{"context":"Example unit smoke (ExUnit + ConnTest)"},{"context":"Install smoke (fresh phx.new + sigra.install)"},{"context":"Example HTTP smoke (boot + curl critical routes)"},{"context":"Example Playwright smoke (full lifecycle)"}]}}]';;
  /repos/szTheory/sigra/rulesets\?per_page=100) echo '[{"id":8123,"name":"main-checks","target":"branch","enforcement":"active"}]';;
  /repos/szTheory/sigra/actions/runs/38144377407) echo '{"id":38144377407,"head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","event":"pull_request","path":".github/workflows/ci.yml","run_attempt":1,"created_at":"2026-10-10T10:00:00Z"}';;
  /repos/szTheory/sigra/actions/runs/38144377407/attempts/1/jobs\?per_page=100) echo '{"jobs":[{"id":1101,"name":"Library tests","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z","conclusion":"success"},{"id":1102,"name":"Example unit smoke (ExUnit + ConnTest)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z","conclusion":"success"},{"id":1103,"name":"Install smoke (fresh phx.new + sigra.install)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z","conclusion":"success"},{"id":1104,"name":"Example HTTP smoke (boot + curl critical routes)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z","conclusion":"success"},{"id":1105,"name":"Example Playwright smoke (full lifecycle)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z","conclusion":"success"}]}';;
  /repos/szTheory/sigra/commits/40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8/check-runs\?per_page=100) echo '{"check_runs":[{"id":2101,"external_id":"1101","name":"Library tests","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","status":"completed","conclusion":"success","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z"},{"id":2102,"external_id":"1102","name":"Example unit smoke (ExUnit + ConnTest)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","status":"completed","conclusion":"success","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z"},{"id":2103,"external_id":"1103","name":"Install smoke (fresh phx.new + sigra.install)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","status":"completed","conclusion":"success","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z"},{"id":2104,"external_id":"1104","name":"Example HTTP smoke (boot + curl critical routes)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","status":"completed","conclusion":"success","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z"},{"id":2105,"external_id":"1105","name":"Example Playwright smoke (full lifecycle)","head_sha":"40e0a7b9fa6c31953e4c1dc3e2cced41f77071d8","status":"completed","conclusion":"success","started_at":"2026-10-10T10:01:00Z","completed_at":"2026-10-10T10:02:00Z"}]}';;
  *) echo "unhandled endpoint: $endpoint" >&2; exit 1;;
esac
GHAPI
chmod +x "${GH_API_BIN}/gh"
export GH_API_LOG
PREFLIGHT_FILE="${TMPDIR_ROOT}/preflight.json"
if PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --preflight --preflight-output "$PREFLIGHT_FILE" >/dev/null 2>"${TMPDIR_ROOT}/preflight.err" \
  && jq -e '.status == "ready" and (.checkout.sha|length)>0 and .workflow.git_blob_sha != "" and (.effective_required_contexts|length)==5' "$PREFLIGHT_FILE" >/dev/null \
  && [[ "$(wc -l <"$GH_API_LOG" | tr -d ' ')" -eq 4 ]] \
  && ! grep -v -- '--method GET' "$GH_API_LOG" >/dev/null; then
  pass "preflight reports current five contexts and guards all four initial requests"
else
  fail "preflight failed: $(cat "${TMPDIR_ROOT}/preflight.err" 2>/dev/null) preflight=$(cat "$PREFLIGHT_FILE" 2>/dev/null) calls=$(cat "$GH_API_LOG" 2>/dev/null)"
fi

echo "Test O2: time, core-rate, 600-request boundary, and one transient retry are enforced before calls"
before_calls="$(wc -l <"$GH_API_LOG" | tr -d ' ')"
set +e
CI_METRICS_TEST_MODE=1 CI_METRICS_TEST_ELAPSED_SECONDS=3600 PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --preflight --preflight-output "${TMPDIR_ROOT}/time-stop.json" >/dev/null 2>&1
time_rc=$?
set -e
after_time_calls="$(wc -l <"$GH_API_LOG" | tr -d ' ')"
if [[ "$time_rc" -eq 2 && "$before_calls" -eq "$after_time_calls" ]] && jq -e '.stop_reason == "time_limit_exhausted" and .request_count == 0' "${TMPDIR_ROOT}/time-stop-request-ledger.json" >/dev/null; then
  pass "60-minute boundary stops before the first request and writes an incomplete ledger"
else fail "time boundary rc=$time_rc calls=$before_calls->$after_time_calls ledger=$(cat "${TMPDIR_ROOT}/time-stop-request-ledger.json" 2>/dev/null)"; fi

CI_METRICS_TEST_MODE=1 CI_METRICS_TEST_PRIOR_REQUESTS=596 PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --preflight --preflight-output "${TMPDIR_ROOT}/request-boundary.json" >/dev/null 2>&1
if jq -e '.request_count == 600 and .status == "ready"' "${TMPDIR_ROOT}/request-boundary.json" >/dev/null && [[ "$(jq '.requests|length' "${TMPDIR_ROOT}/request-boundary-request-ledger.json")" -eq 4 ]]; then
  pass "request 600 is allowed and no 601st request is made"
else fail "600-request boundary ledger=$(cat "${TMPDIR_ROOT}/request-boundary-request-ledger.json" 2>/dev/null)"; fi

set +e
GH_API_MODE=core PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --preflight --preflight-output "${TMPDIR_ROOT}/core-stop.json" >/dev/null 2>&1
core_rc=$?
set -e
if [[ "$core_rc" -eq 2 ]] && jq -e '.request_count == 1 and .stop_reason == "core_rate_limit_stop"' "${TMPDIR_ROOT}/core-stop-request-ledger.json" >/dev/null; then
  pass "core budget at 250 stops before the next API request"
else fail "core budget rc=$core_rc ledger=$(cat "${TMPDIR_ROOT}/core-stop-request-ledger.json" 2>/dev/null)"; fi
if jq -e '.status=="blocked" and (.missing_capabilities|length)>0' "${TMPDIR_ROOT}/core-stop.json" >/dev/null; then
  pass "blocked hosted preflight names its missing capability while offline tests continue"
else fail "blocked preflight diagnostic=$(cat "${TMPDIR_ROOT}/core-stop.json" 2>/dev/null)"; fi

before_rate403="$(wc -l <"$GH_API_LOG" | tr -d ' ')"
set +e
GH_API_MODE=rate403 PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --preflight --preflight-output "${TMPDIR_ROOT}/rate403.json" >/dev/null 2>&1
rate403_rc=$?
set -e
after_rate403="$(wc -l <"$GH_API_LOG" | tr -d ' ')"
if [[ "$rate403_rc" -eq 2 && $((after_rate403-before_rate403)) -eq 1 ]] && jq -e '.stop_reason == "http_rate_limit" and .reset_or_retry_at == "1900000000"' "${TMPDIR_ROOT}/rate403-request-ledger.json" >/dev/null; then
  pass "403/429 rate response records reset time and is never retried immediately"
else fail "rate stop rc=$rate403_rc calls=$before_rate403->$after_rate403 ledger=$(cat "${TMPDIR_ROOT}/rate403-request-ledger.json" 2>/dev/null)"; fi

GH_API_FAIL_ONCE_FILE="${TMPDIR_ROOT}/transient-seen"
GH_API_MODE=transient GH_API_FAIL_ONCE_FILE="$GH_API_FAIL_ONCE_FILE" PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --preflight --preflight-output "${TMPDIR_ROOT}/transient.json" >/dev/null 2>&1
if jq -e '.status == "ready" and .request_count == 5' "${TMPDIR_ROOT}/transient.json" >/dev/null && [[ "$(jq '[.requests[]|select(.=="rate_limit")]|length' "${TMPDIR_ROOT}/transient-request-ledger.json")" -eq 2 ]]; then
  pass "a transient GET is retried once and both requests count against the budget"
else fail "transient retry ledger=$(cat "${TMPDIR_ROOT}/transient-request-ledger.json" 2>/dev/null)"; fi

echo "Test P: one PR family collects to a hash-checked offline replay with equal-duration job identities"
SOURCE_DIR="${TMPDIR_ROOT}/family"
if PATH="${GH_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --collect --run-id 38144377407 --source-bundle "$SOURCE_DIR" >/dev/null 2>"${TMPDIR_ROOT}/collect.err" \
  && PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$SOURCE_DIR" --format json >"${TMPDIR_ROOT}/replay.json" 2>"${TMPDIR_ROOT}/replay.err" \
  && jq -e '.status == "measured" and .first_attempt_required_wait_seconds == 120 and .eventual_required_wait_seconds == 120 and .runner_seconds == 300 and .family_observation_count == 1 and .revision_count == 1 and (.literal_outcomes.check_runs|length)==5 and (.diagnostics|length)==0' "${TMPDIR_ROOT}/replay.json" >/dev/null \
  && jq -e '.required_contexts|length==5' "$SOURCE_DIR/manifest.json" >/dev/null \
  && [[ "$(jq -r '.request_count' "$SOURCE_DIR/request-ledger.json")" -eq 7 ]]; then
  pass "five required contexts replay to a 120-second endpoint and 300 equal-job seconds without gh"
else
  fail "collect/replay failed: $(cat "${TMPDIR_ROOT}/collect.err" "${TMPDIR_ROOT}/replay.err" 2>/dev/null) replay=$(cat "${TMPDIR_ROOT}/replay.json" 2>/dev/null) manifest=$(cat "$SOURCE_DIR/manifest.json" 2>/dev/null)"
fi

echo "Test Q: altered rules and incomplete or unbound required contexts remain unknown"
INCOMPLETE_DIR="${TMPDIR_ROOT}/incomplete-family"
cp -R "$SOURCE_DIR" "$INCOMPLETE_DIR"
jq '(.check_runs[] | select(.name=="Library tests") | .completed_at)=null' "$INCOMPLETE_DIR/raw/check-runs.json" >"${TMPDIR_ROOT}/incomplete-checks.json"
mv "${TMPDIR_ROOT}/incomplete-checks.json" "$INCOMPLETE_DIR/raw/check-runs.json"
hash="$(shasum -a 256 "$INCOMPLETE_DIR/raw/check-runs.json" | awk '{print $1}')"
jq --arg hash "$hash" '.raw_sha256.check_runs=$hash' "$INCOMPLETE_DIR/manifest.json" >"${TMPDIR_ROOT}/incomplete-manifest.json"
mv "${TMPDIR_ROOT}/incomplete-manifest.json" "$INCOMPLETE_DIR/manifest.json"
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$INCOMPLETE_DIR" --format json >"${TMPDIR_ROOT}/incomplete-result.json"
if jq -e '.status=="unknown" and .eventual_required_wait_seconds==null and any(.diagnostics[]; .reason=="required_context_incomplete")' "${TMPDIR_ROOT}/incomplete-result.json" >/dev/null; then
  pass "a missing required-check timestamp yields unknown, never a numeric wait"
else fail "incomplete context result=$(cat "${TMPDIR_ROOT}/incomplete-result.json")"; fi

UNBOUND_DIR="${TMPDIR_ROOT}/unbound-family"
cp -R "$SOURCE_DIR" "$UNBOUND_DIR"
jq '(.check_runs[0].id)=999999 | (.check_runs[0].external_id)="999999"' "$UNBOUND_DIR/raw/check-runs.json" >"${TMPDIR_ROOT}/unbound-checks.json"
mv "${TMPDIR_ROOT}/unbound-checks.json" "$UNBOUND_DIR/raw/check-runs.json"
hash="$(shasum -a 256 "$UNBOUND_DIR/raw/check-runs.json" | awk '{print $1}')"
jq --arg hash "$hash" '.raw_sha256.check_runs=$hash' "$UNBOUND_DIR/manifest.json" >"${TMPDIR_ROOT}/unbound-manifest.json"
mv "${TMPDIR_ROOT}/unbound-manifest.json" "$UNBOUND_DIR/manifest.json"
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$UNBOUND_DIR" --format json >"${TMPDIR_ROOT}/unbound-result.json"
if jq -e '.status=="unknown" and .eventual_required_wait_seconds==null and any(.diagnostics[]; .reason=="required_context_unbound")' "${TMPDIR_ROOT}/unbound-result.json" >/dev/null; then
  pass "check-run to job ID mismatch is reported as required_context_unbound"
else fail "unbound context result=$(cat "${TMPDIR_ROOT}/unbound-result.json")"; fi

CHANGED_DIR="${TMPDIR_ROOT}/changed-rules-family"
cp -R "$SOURCE_DIR" "$CHANGED_DIR"
jq '.required_rules_changed=true' "$CHANGED_DIR/manifest.json" >"${TMPDIR_ROOT}/changed-manifest.json"
mv "${TMPDIR_ROOT}/changed-manifest.json" "$CHANGED_DIR/manifest.json"
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$CHANGED_DIR" --format json >"${TMPDIR_ROOT}/changed-result.json"
if jq -e '.status=="unknown" and .eventual_required_wait_seconds==null and any(.diagnostics[]; .=="required_rules_changed")' "${TMPDIR_ROOT}/changed-result.json" >/dev/null; then
  pass "a changed effective rule set invalidates timing without replacing the endpoint"
else fail "changed rules result=$(cat "${TMPDIR_ROOT}/changed-result.json")"; fi

TAMPERED_DIR="${TMPDIR_ROOT}/tampered-family"
cp -R "$SOURCE_DIR" "$TAMPERED_DIR"
jq '.head_branch="tampered"' "$TAMPERED_DIR/raw/run.json" >"${TMPDIR_ROOT}/tampered-run.json"
mv "${TMPDIR_ROOT}/tampered-run.json" "$TAMPERED_DIR/raw/run.json"
set +e
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$TAMPERED_DIR" --format json >"${TMPDIR_ROOT}/tampered-result.json" 2>"${TMPDIR_ROOT}/tampered.err"
tampered_rc=$?
set -e
if [[ "$tampered_rc" -ne 0 ]] && grep -q 'source_hash_mismatch:run' "${TMPDIR_ROOT}/tampered.err"; then
  pass "a changed retained response is rejected by its saved SHA-256"
else fail "tampered rc=$tampered_rc error=$(cat "${TMPDIR_ROOT}/tampered.err")"; fi

echo "Test R: first-attempt and eventual endpoints stay separate while every rerun job contributes cost"
MULTI_DIR="${TMPDIR_ROOT}/multi-attempt-family"
cp -R "$SOURCE_DIR" "$MULTI_DIR"
jq '{jobs:[.jobs[] | .id += 100 | .attempt=2 | .started_at="2026-10-10T10:03:00Z" | .completed_at="2026-10-10T10:04:00Z"]}' "$MULTI_DIR/raw/jobs.json" >"$MULTI_DIR/raw/jobs-attempt-2.json"
jq -s '{jobs:(.[0].jobs + .[1].jobs)}' "$MULTI_DIR/raw/jobs.json" "$MULTI_DIR/raw/jobs-attempt-2.json" >"${TMPDIR_ROOT}/multi-jobs.json"
mv "${TMPDIR_ROOT}/multi-jobs.json" "$MULTI_DIR/raw/jobs.json"
jq '(.run_attempt)=2' "$MULTI_DIR/raw/run.json" >"${TMPDIR_ROOT}/multi-run.json"
mv "${TMPDIR_ROOT}/multi-run.json" "$MULTI_DIR/raw/run.json"
jq '(.check_runs) as $checks | .check_runs += ($checks | map(.id -= 900 | .external_id="attempt-2" | .started_at="2026-10-10T10:03:00Z" | .completed_at="2026-10-10T10:04:00Z"))' "$MULTI_DIR/raw/check-runs.json" >"${TMPDIR_ROOT}/multi-checks.json"
mv "${TMPDIR_ROOT}/multi-checks.json" "$MULTI_DIR/raw/check-runs.json"
run_hash="$(shasum -a 256 "$MULTI_DIR/raw/run.json" | awk '{print $1}')"
jobs_hash="$(shasum -a 256 "$MULTI_DIR/raw/jobs.json" | awk '{print $1}')"
checks_hash="$(shasum -a 256 "$MULTI_DIR/raw/check-runs.json" | awk '{print $1}')"
attempt2_hash="$(shasum -a 256 "$MULTI_DIR/raw/jobs-attempt-2.json" | awk '{print $1}')"
jq --arg run "$run_hash" --arg jobs "$jobs_hash" --arg checks "$checks_hash" --arg attempt2 "$attempt2_hash" \
  '.attempt=2 | .attempts_collected=2 | .raw_sha256.run=$run | .raw_sha256.jobs=$jobs | .raw_sha256.check_runs=$checks | .raw_sha256.jobs_attempt_2=$attempt2' \
  "$MULTI_DIR/manifest.json" >"${TMPDIR_ROOT}/multi-manifest.json"
mv "${TMPDIR_ROOT}/multi-manifest.json" "$MULTI_DIR/manifest.json"
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$MULTI_DIR" --format json >"${TMPDIR_ROOT}/multi-result.json"
if jq -e '.status=="measured" and .first_attempt_required_wait_seconds==120 and .eventual_required_wait_seconds==240 and .runner_seconds==600' "${TMPDIR_ROOT}/multi-result.json" >/dev/null; then
  pass "rerun completion extends eventual wait and both attempts' five distinct jobs count"
else fail "multi-attempt result=$(cat "${TMPDIR_ROOT}/multi-result.json")"; fi

echo "Test S: multi-revision records remain one family and cannot claim an unmeasured endpoint"
REVISION_DIR="${TMPDIR_ROOT}/multi-revision-family"
cp -R "$SOURCE_DIR" "$REVISION_DIR"
jq '.revisions += [{source_sha:"second-revision-sha",run_id:38144377408,attempt:1,associated_pull_requests:[123]}]' "$REVISION_DIR/manifest.json" >"${TMPDIR_ROOT}/revision-manifest.json"
mv "${TMPDIR_ROOT}/revision-manifest.json" "$REVISION_DIR/manifest.json"
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$REVISION_DIR" --format json >"${TMPDIR_ROOT}/revision-result.json"
if jq -e '.status=="unknown" and .family_observation_count==1 and .revision_count==2 and .eventual_required_wait_seconds==null and any(.diagnostics[]; .reason=="family_revision_source_incomplete")' "${TMPDIR_ROOT}/revision-result.json" >/dev/null; then
  pass "multiple source revisions are represented once and remain unknown without each revision's source bundle"
else fail "multi-revision result=$(cat "${TMPDIR_ROOT}/revision-result.json")"; fi

echo "Test T: non-required failure, cancellation, timeout, and skip conclusions stay literal"
OUTCOMES_DIR="${TMPDIR_ROOT}/literal-outcomes-family"
cp -R "$SOURCE_DIR" "$OUTCOMES_DIR"
jq '.check_runs += [{id:8000,name:"fixture failed",status:"completed",conclusion:"failure"},{id:8001,name:"fixture cancelled",status:"completed",conclusion:"cancelled"},{id:8002,name:"fixture timed out",status:"completed",conclusion:"timed_out"},{id:8003,name:"fixture skipped",status:"completed",conclusion:"skipped"}]' "$OUTCOMES_DIR/raw/check-runs.json" >"${TMPDIR_ROOT}/outcome-checks.json"
mv "${TMPDIR_ROOT}/outcome-checks.json" "$OUTCOMES_DIR/raw/check-runs.json"
hash="$(shasum -a 256 "$OUTCOMES_DIR/raw/check-runs.json" | awk '{print $1}')"
jq --arg hash "$hash" '.raw_sha256.check_runs=$hash' "$OUTCOMES_DIR/manifest.json" >"${TMPDIR_ROOT}/outcome-manifest.json"
mv "${TMPDIR_ROOT}/outcome-manifest.json" "$OUTCOMES_DIR/manifest.json"
PATH="${STUB_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin" bash "$SCRIPT" --replay --source-bundle "$OUTCOMES_DIR" --format json >"${TMPDIR_ROOT}/outcome-result.json"
if jq -e 'any(.literal_outcomes.check_runs[]; .conclusion=="failure") and any(.literal_outcomes.check_runs[]; .conclusion=="cancelled") and any(.literal_outcomes.check_runs[]; .conclusion=="timed_out") and any(.literal_outcomes.check_runs[]; .conclusion=="skipped")' "${TMPDIR_ROOT}/outcome-result.json" >/dev/null; then
  pass "replay retains failure, cancellation, timeout, and skip conclusions verbatim"
else fail "literal outcome result=$(cat "${TMPDIR_ROOT}/outcome-result.json")"; fi

echo "Test U: frozen cutoff keeps PR, main push and schedule populations separate and caps each at 100"
WINDOW_API_BIN="${TMPDIR_ROOT}/window-api-bin"
mkdir -p "$WINDOW_API_BIN"
WINDOW_API_LOG="${TMPDIR_ROOT}/window-api.log"
WINDOW_FIXTURE_MODE="${TMPDIR_ROOT}/window-mode"
cat >"${WINDOW_API_BIN}/gh" <<'WINDOW_GH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == api && "${2:-}" == --method && "${3:-}" == GET ]] || exit 2
endpoint="${4:-}"
printf '%s\n' "$endpoint" >>"$WINDOW_API_LOG"
case "$endpoint" in
  rate_limit)
    if [[ "${GH_API_MODE:-}" == rate403 ]]; then echo 'HTTP 403 rate limit; x-ratelimit-reset: 1900000000' >&2; exit 1; fi
    if [[ "${GH_API_MODE:-}" == transient && ! -e "${GH_API_FAIL_ONCE_FILE:-/nonexistent}" ]]; then touch "$GH_API_FAIL_ONCE_FILE"; echo 'HTTP 503 temporary service failure' >&2; exit 1; fi
    if [[ "${GH_API_MODE:-}" == core ]]; then echo '{"resources":{"core":{"remaining":250,"reset":1900000000}}}'; else echo '{"resources":{"core":{"remaining":5000,"reset":1900000000}}}'; fi;;
  *'/rules/branches/main') echo '[{"type":"required_status_checks","parameters":{"required_status_checks":[]}}]';;
  *'/branches/main/protection/required_status_checks') echo '{"status":"not_configured","http_status":404}';;
  *'/rulesets?per_page=100') echo '[]';;
  /repos/szTheory/sigra/actions/runs/*/attempts/*/jobs\?*)
    run_id="$(printf '%s' "$endpoint" | sed -nE 's#^.*/actions/runs/([0-9]+)/attempts/.*#\1#p')"
    attempt="$(printf '%s' "$endpoint" | sed -nE 's#^.*/attempts/([0-9]+)/jobs.*#\1#p')"
    if [[ "$run_id" == 5000 ]]; then job_conclusion=skipped; elif [[ "$run_id" == 5001 ]]; then job_conclusion=failure; else job_conclusion=success; fi
    jq -cn --argjson id "$run_id" --argjson attempt "$attempt" --arg conclusion "$job_conclusion" '{total_count:1,jobs:[{id:($id*100+$attempt),name:"Example Playwright smoke",head_sha:("sha-"+($id|tostring)),conclusion:$conclusion,started_at:(if $attempt==1 then "2026-10-10T10:00:00Z" else "2026-10-10T10:02:00Z" end),completed_at:(if $attempt==1 then "2026-10-10T10:01:00Z" else "2026-10-10T10:04:00Z" end),steps:[{name:"Checkout and setup",conclusion:"success",started_at:"2026-10-10T10:00:00Z",completed_at:"2026-10-10T10:00:05Z"},{name:"Restore dependencies cache",conclusion:"success",started_at:"2026-10-10T10:00:05Z",completed_at:"2026-10-10T10:00:10Z"},{name:"Compile dependencies",conclusion:"success",started_at:"2026-10-10T10:00:10Z",completed_at:"2026-10-10T10:00:20Z"},{name:"Start database",conclusion:"success",started_at:"2026-10-10T10:00:20Z",completed_at:"2026-10-10T10:00:30Z"},{name:"Boot application",conclusion:"success",started_at:"2026-10-10T10:00:30Z",completed_at:"2026-10-10T10:00:40Z"},{name:"Run selected tests",conclusion:$conclusion,started_at:"2026-10-10T10:00:40Z",completed_at:"2026-10-10T10:00:50Z"},{name:"Upload artifact",conclusion:"success",started_at:"2026-10-10T10:00:50Z",completed_at:"2026-10-10T10:00:52Z"},{name:"Optional annotation (not a required job)",conclusion:"skipped"}]}]}';;
  /repos/szTheory/sigra/pulls/*/files\?*)
    pr="$(printf '%s' "$endpoint" | sed -nE 's#^.*/pulls/([0-9]+)/files.*#\1#p')"
    case "$pr" in 123) echo '[{"filename":"docs/guide.md"}]';; 124) echo '[{"filename":"lib/sigra.ex"}]';; *) echo '[{"filename":"docs/unknown.md"}]';; esac;;
  /repos/szTheory/sigra/actions/runs/*/artifacts\?*)
    run_id="$(printf '%s' "$endpoint" | sed -nE 's#^.*/actions/runs/([0-9]+)/artifacts.*#\1#p')"
    if [[ "${WINDOW_ARTIFACT_MODE:-}" == download && "$run_id" == 5001 ]]; then
      jq -cn --argjson run "$run_id" --arg sha "sha-$run_id" --arg digest "$WINDOW_ARTIFACT_DIGEST" '{total_count:1,artifacts:[{id:77,name:("playwright-report-"+($run|tostring)),expired:false,digest:$digest,workflow_run:{id:$run,head_sha:$sha},archive_download_url:"https://api.github.com/download?sig=DO_NOT_RETAIN"}]}'
    else echo '{"total_count":0,"artifacts":[]}'; fi;;
  *'/actions/workflows/ci.yml/runs?'*)
    event="$(printf '%s' "$endpoint" | sed -nE 's/.*[?&]event=([^&]+).*/\1/p')"
    page="$(printf '%s' "$endpoint" | sed -nE 's/.*[?&]page=([0-9]+).*/\1/p')"
    case "$event" in
      pull_request) total=125; count=100; base=5000;;
      push) if [[ "$endpoint" == *'&branch=main&'* ]]; then total=2; count=2; base=6000; else total=1; count=1; base=6100; fi;;
      schedule) total=1; count=1; base=7000;;
      workflow_dispatch) total=1; count=1; base=8000;;
      *) exit 3;;
    esac
    if [[ "$event" == pull_request && "$page" == 2 ]]; then count=1; base=5100; fi
    if [[ "$event" == pull_request && "$page" -gt 2 ]]; then count=0; fi
    jq -cn --argjson total "$total" --argjson count "$count" --argjson base "$base" --arg event "$event" --arg page "$page" --arg cutoff "2026-10-12T00:00:00Z" --arg endpoint "$endpoint" '{total_count:$total,workflow_runs:[range(0;$count) as $i | (( $base+$i) as $id | {id:$id,run_number:$id,event:$event,head_branch:(if $event=="push" and ($endpoint|contains("branch=main")) then "main" elif $event=="push" then "release/1.0" elif $event=="workflow_dispatch" then "manual-probe" else "feature" end),head_sha:("sha-"+($id|tostring)),path:".github/workflows/ci.yml",run_attempt:(if $id==5001 then 2 else 1 end),pull_requests:(if $event=="pull_request" and ($id==5000 or $id==5001 or $id==5002) then [{number:(if $id==5000 then 123 elif $id==5001 then 124 else 125 end)}] else [] end),changes:{docs_only:(if $id==5000 then true elif $id==5001 then false else null end)},created_at:(if $id==5000 then "2026-09-12T00:00:00Z" elif $id==5001 then "2026-10-11T00:00:00Z" else "2026-10-10T00:00:00Z" end),updated_at:$cutoff,conclusion:(if $i%2==0 then "success" else "failure" end)})]}'
    ;;
  *) echo "unhandled $endpoint" >&2; exit 4;;
esac
WINDOW_GH
chmod +x "$WINDOW_API_BIN/gh"
cat >"${WINDOW_API_BIN}/curl" <<'WINDOW_CURL'
#!/usr/bin/env bash
set -euo pipefail
headers="" output="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dump-header) headers="$2"; shift 2;;
    --output) output="$2"; shift 2;;
    --config) shift 2;;
    --write-out) shift 2;;
    *) if [[ "$1" == http* ]]; then url="$1"; fi; shift;;
  esac
done
[[ -n "$headers" && -n "$output" && -n "$url" ]] || exit 2
if [[ "$url" == https://api.github.com/*/actions/artifacts/77/zip ]]; then
  printf 'HTTP/1.1 302 Found\r\nLocation: https://pipelines.actions.githubusercontent.com/download/file?sig=SIGNED_URL_SENTINEL\r\n\r\n' >"$headers"
  : >"$output"; printf '302'; exit 0
elif [[ "$url" == https://api.github.com/*/actions/jobs/*/logs ]]; then
  printf 'HTTP/1.1 302 Found\r\nLocation: https://pipelines.actions.githubusercontent.com/job-log/run?sig=SIGNED_LOG_SENTINEL\r\n\r\n' >"$headers"
  : >"$output"; printf '302'; exit 0
elif [[ "$url" == https://pipelines.actions.githubusercontent.com/* ]]; then
  if [[ "$url" == */job-log/* ]]; then
    printf 'HTTP/1.1 200 OK\r\n\r\n' >"$headers"
    printf '%s\n' 'Error: expect(received).toBe(expected) at tests/admin/admin-profile.spec.ts:42:5' 'ghp_abcdefghijklmnopqrstuvwxyz1234567890' 'password=cleartext' 'https://logs.example/output?sig=SIGNED_LOG_SECRET' >"$output"
  else
    printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\n\r\n' "$(wc -c <"$WINDOW_ARTIFACT_ZIP" | tr -d ' ')" >"$headers"
    cp "$WINDOW_ARTIFACT_ZIP" "$output"
  fi
  printf '200'; exit 0
fi
printf 'HTTP/1.1 404 Not Found\r\n\r\n' >"$headers"; : >"$output"; printf '404'
WINDOW_CURL
chmod +x "$WINDOW_API_BIN/curl"
WINDOW_ARTIFACT_ZIP="${TMPDIR_ROOT}/artifact-timing.zip"
python3 - "$WINDOW_ARTIFACT_ZIP" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("ci-measurement-metadata.json", '{"schema_version":"sigra.ci-measurement-metadata/v1","repository":"szTheory/sigra","run_id":"5001","run_attempt":"2","source_sha":"sha-5001","event":"pull_request","matrix_seam":"design_gallery","job_name":"Example Playwright smoke","runner_os":"Linux","runner_arch":"X64","runner_image":{"image_os":"ubuntu22","image_version":"20261001.1"},"cache_outcome":{"example_deps":"hit","browser_binaries":"miss"},"configured_versions":{"elixir":"1.19.5-otp-28","node":"20","playwright":"1.59.1"},"observed_versions":{"elixir":{"value":"Elixir 1.19.5","reason":null},"node":{"value":"v20.19.0","reason":null},"playwright":{"value":null,"reason":"command_unavailable"}}}')
    z.writestr("design-gallery-pr-behavior.json", '{"seam":"design_gallery","complete":true,"suite_elapsed_ms":125,"sum_test_duration_ms":100,"reporter_overhead":{"status":"unmeasured","overhead_ms":null},"tests":[{"test_id":"gallery:one","title":"gallery route","duration_ms":100}]}')
    z.writestr("timing.json", '{"duration_seconds":12}')
PY
WINDOW_ARTIFACT_DIGEST="sha256:$(shasum -a 256 "$WINDOW_ARTIFACT_ZIP" | awk '{print $1}')"
export WINDOW_API_LOG
WINDOW_BUNDLE="${TMPDIR_ROOT}/window-bundle"
export GH_TOKEN=fixture-token WINDOW_ARTIFACT_MODE=download WINDOW_ARTIFACT_DIGEST WINDOW_ARTIFACT_ZIP
export CI_METRICS_TEST_MODE=1
set +e
PATH="${WINDOW_API_BIN}:${HOST_PATH}" bash "$SCRIPT" --collect --cutoff 2026-10-12T00:00:00Z --source-bundle "$WINDOW_BUNDLE" >"${TMPDIR_ROOT}/window-collect.out" 2>"${TMPDIR_ROOT}/window-collect.err"
window_rc=$?
set -e
if [[ "$window_rc" -eq 0 ]] \
  && jq -e '.status == "complete" and .cutoff_utc == "2026-10-12T00:00:00Z" and .populations.pull_request.api_total_count == 125 and .populations.pull_request.population_capped == true and (.populations.pull_request.selected_run_ids|length)==100 and .populations.pull_request.selected_run_ids[-1]==5099 and .populations.push_main.population_exhausted == true and .populations.schedule.population_exhausted == true and (.populations.manual.records|length)==1 and (.populations.release_push.records|length)==1 and (.populations.release_push.records[0].head_branch=="release/1.0") and (.populations.pull_request.runs[0].created_at|startswith("2026-09-12"))' "$WINDOW_BUNDLE/manifest.json" >/dev/null \
  && jq -e '.populations.manual.records|length==1' "$WINDOW_BUNDLE/manifest.json" >/dev/null \
  && jq -e '([.populations.pull_request.runs[]|select(.id==5000 and .workload=="docs_only")]|length)==1 and ([.populations.pull_request.runs[]|select(.id==5001 and .conclusion=="failure" and .workload=="full" and .detail_status=="complete" and (.attempt_jobs|keys|length)==2)]|length)==1 and ([.populations.pull_request.runs[]|select(.id==5002 and .workload=="unknown")]|length)==1' "$WINDOW_BUNDLE/manifest.json" >/dev/null \
  && jq -e 'any(.artifact_diagnostics[]?; .kind=="artifact" and .result.status=="accepted")' "$WINDOW_BUNDLE/raw/families/5001/manifest.json" >/dev/null \
  && jq -e 'any(.artifact_diagnostics[]?; .kind=="failed_job_log" and .result.status=="retained_redacted")' "$WINDOW_BUNDLE/raw/families/5001/manifest.json" >/dev/null \
  && jq -e '[.requests[]|select(startswith("download:artifact:"))]|length==2' "$WINDOW_BUNDLE/request-ledger.json" >/dev/null \
  && jq -e '[.requests[]|select(startswith("download:job-log:"))]|length==2' "$WINDOW_BUNDLE/request-ledger.json" >/dev/null \
  && ! grep -R -F 'SIGNED_URL_SENTINEL' "$WINDOW_BUNDLE" >/dev/null \
  && ! grep -R -F 'SIGNED_LOG_SENTINEL' "$WINDOW_BUNDLE" >/dev/null \
  && ! grep -R -F 'SIGNED_LOG_SECRET' "$WINDOW_BUNDLE" >/dev/null \
  && ! grep -R -F 'ghp_abcdefghijklmnopqrstuvwxyz1234567890' "$WINDOW_BUNDLE" >/dev/null \
  && ! grep -R -F 'cleartext' "$WINDOW_BUNDLE" >/dev/null \
  && ! grep -R -F 'DO_NOT_RETAIN' "$WINDOW_BUNDLE" >/dev/null \
  && ! jq -e '.populations.push_main.runs[] | select(.head_branch != "main")' "$WINDOW_BUNDLE/manifest.json" >/dev/null; then
  pass "fixed cutoff, 100-run cap, API totals and event separation are retained"
else
  fail "window collect rc=$window_rc stderr=$(cat "${TMPDIR_ROOT}/window-collect.err") manifest_status=$(jq -c '{status,request_count,stop_reason,artifact:.populations.pull_request.runs[]?|select(.id==5001)|.artifact_diagnostics}' "$WINDOW_BUNDLE/manifest.json" 2>/dev/null) family=$(cat "$WINDOW_BUNDLE/raw/families/5001/manifest.json" 2>/dev/null)"
fi
unset GH_TOKEN WINDOW_ARTIFACT_MODE WINDOW_ARTIFACT_DIGEST WINDOW_ARTIFACT_ZIP CI_METRICS_TEST_MODE

echo "Test Z: the retained dependency-off-only ExUnit artifact is no longer accepted as full-suite timing"
LEGACY_BUNDLE="${SCRIPT_DIR}/../../.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz"
if [[ -s "$LEGACY_BUNDLE" ]] \
  && bash "$SCRIPT" --replay --source-bundle "$LEGACY_BUNDLE" --format json >"${TMPDIR_ROOT}/legacy-replay.json" 2>"${TMPDIR_ROOT}/legacy-replay.err" \
  && jq -e '.instrumented_full_pr.complete == false and (.instrumented_full_pr.diagnostics | index("complete_exunit_main_timing_missing_or_wrong_invocation") != null) and (.instrumented_full_pr.diagnostics | index("complete_exunit_threadline_guard_timing_missing_or_wrong_invocation") != null)' "${TMPDIR_ROOT}/legacy-replay.json" >/dev/null; then
  pass "65-test dependency-off-only artifact cannot satisfy the main+child timing contract"
else
  fail "legacy timing bundle did not fail closed: $(cat "${TMPDIR_ROOT}/legacy-replay.err") $(jq -c '.instrumented_full_pr' "${TMPDIR_ROOT}/legacy-replay.json" 2>/dev/null)"
fi

run_window_extension_tests
bash "$SCRIPT_DIR/ci-run-metrics-comparison.test.sh"

echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "ci-run-metrics.test: FAIL"
  exit 1
fi

echo "ci-run-metrics.test: PASS"
exit 0
