#!/usr/bin/env bash
# Hermetic self-test for scripts/ci/capture-green-04-evidence.sh.
#
# OFFLINE BY DESIGN: every GitHub read is served by a recording `gh` stub on PATH, and the
# collector runs inside a throwaway git repository so its D-13 `git status` /
# `git rev-parse HEAD` assertions have real git state to read. No token, no network, no
# dispatch.
#
# THE STUB REPRODUCES THE SHAPE THE REAL API EMITS, NOT THE SHAPE THE CODE WISHES FOR.
# All twenty leg objects are generated from a single `1..20` loop whose `name` is the
# workflow's `name:` value plus a ` (N)` matrix suffix (ci.yml:556-560). `FAKE_JOB_NAME_SHAPE`
# drives that suffixing, and the `bare_job_names` negative control is produced by the SAME
# generator with the shape flipped — so the harness can never drift into proving a payload
# shape the Actions API never produces.
#
# NOT WIRED INTO ci.yml, deliberately: neither capture-fast-01-remeasurement.test.sh nor
# capture-terminal-ratification-evidence.test.sh has a CI caller either. This collector is
# operator-invoked once, on a clean tree at the final committed HEAD.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-green-04-evidence.sh"
test -x "$COLLECTOR" || { echo "collector not executable: $COLLECTOR" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/out" "$TMP/repo"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  ok   - $*"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL - $*" >&2; }
check() { if [[ "$1" == 0 ]]; then ok "$2"; else bad "$2"; fi; }

# --- throwaway git repository -------------------------------------------------
git -C "$TMP/repo" init -q -b main
git -C "$TMP/repo" config user.email "selftest@example.invalid"
git -C "$TMP/repo" config user.name "selftest"
echo "fixture" >"$TMP/repo/fixture.txt"
git -C "$TMP/repo" add fixture.txt
git -C "$TMP/repo" commit -q -m "fixture"
REAL_HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"

DISPATCH_RUN_ID=35400000001
WINDOW_START="2026-09-17T00:00:00Z"
WINDOW_END="2026-09-18T00:00:00Z"

# --- recording gh stub --------------------------------------------------------
cat >"$TMP/bin/gh" <<'STUB_EOF'
#!/usr/bin/env bash
set -uo pipefail
JOB_NAME="Generated admin Playwright smoke (GREEN-04 repeat)"
CI_JOB_NAME="Generated admin Playwright smoke"
MODE="${FAKE_MODE:-ok}"
SHAPE="${FAKE_JOB_NAME_SHAPE:-suffixed}"
SC2="${FAKE_SC2_MODE:-ok}"
LEGS="${FAKE_LEG_COUNT:-20}"
TOTAL="${FAKE_TOTAL_COUNT:-$LEGS}"
DISPATCH_RUN_ID="${FAKE_DISPATCH_RUN_ID:-35400000001}"
MAIN_RUN_IDS=(35365693716 35365693717)
printf '%s\n' "$*" >>"$FAKE_GH_LOG"

if [[ "${1:-}" == api && "${2:-}" == rate_limit ]]; then
  if [[ "$MODE" == rate_limited ]]; then echo 10; else echo 251; fi
  exit 0
fi

emit_legs() {
  # SINGLE GENERATOR for every mode. `suffixed` is the shape the real Actions API emits for
  # a matrix job; `bare` is the negative control, and it is produced here rather than as a
  # second hand-written payload so the two can never drift apart.
  local i name concl
  printf '{"total_count":%s,"jobs":[' "$TOTAL"
  for (( i = 1; i <= LEGS; i++ )); do
    (( i > 1 )) && printf ','
    if [[ "$SHAPE" == bare ]]; then name="$JOB_NAME"; else name="$JOB_NAME ($i)"; fi
    concl='"success"'
    if [[ "$MODE" == leg_in_progress && "$i" == 7 ]]; then concl='null'; fi
    printf '{"id":%s,"run_id":%s,"name":"%s","conclusion":%s,"html_url":"https://github.com/szTheory/sigra/actions/runs/%s/job/%s"}' \
      "$(( 1000 + i ))" "$DISPATCH_RUN_ID" "$name" "$concl" "$DISPATCH_RUN_ID" "$(( 1000 + i ))"
  done
  printf ']}\n'
}

emit_main_jobs() {
  # SINGLE GENERATOR for every SC-2 `main` payload, exactly as emit_legs is for SC-1. `ok`
  # reproduces the shape the Actions API emits for a `main` ci.yml run; every other mode is a
  # negative control produced by the SAME generator, so a guard can never be proven against a
  # payload shape the API does not emit.
  local main_id="$1"
  local gate_name="ci-gate" smoke_name="$CI_JOB_NAME"
  local gate_concl='"success"' smoke_concl='"success"'
  case "$SC2" in
    ok) ;;
    # A matrixed/renamed smoke job: the anchored selector matches ZERO jobs.
    smoke_renamed) smoke_name="Generated admin Playwright smoke (shard 1)" ;;
    gate_renamed)  gate_name="ci-gate-v2" ;;
    # Job present but still running/queued: conclusion is null, not a verdict.
    smoke_null)    smoke_concl='null' ;;
    gate_null)     gate_concl='null' ;;
  esac
  printf '{"total_count":3,"jobs":[{"id":%s,"run_id":%s,"name":"%s","conclusion":%s,"html_url":"https://x/1"},{"id":%s,"run_id":%s,"name":"%s","conclusion":%s,"html_url":"https://x/2"},{"id":%s,"run_id":%s,"name":"Admin eval render + probe","conclusion":"failure","html_url":"https://x/3"}]}\n' \
    "$(( main_id + 1 ))" "$main_id" "$gate_name" "$gate_concl" \
    "$(( main_id + 2 ))" "$main_id" "$smoke_name" "$smoke_concl" \
    "$(( main_id + 3 ))" "$main_id"
}

PAGE="$(printf '%s' "$*" | sed -n 's/.*page=\([0-9][0-9]*\).*/\1/p')"

if [[ "$*" == *"/runs/${DISPATCH_RUN_ID}/jobs?"* ]]; then
  case "$PAGE" in
    1) if (( LEGS == 0 )); then printf '{"total_count":%s,"jobs":[]}\n' "$TOTAL"; else emit_legs; fi ;;
    *) printf '{"total_count":%s,"jobs":[]}\n' "$TOTAL" ;;
  esac
  exit 0
fi

for main_id in "${MAIN_RUN_IDS[@]}"; do
  if [[ "$*" == *"/runs/${main_id}/jobs?"* ]]; then
    case "$PAGE" in
      1) emit_main_jobs "$main_id" ;;
      *) printf '{"total_count":3,"jobs":[]}\n' ;;
    esac
    exit 0
  fi
done

if [[ "$*" == *"workflows/ci.yml/runs?"* ]]; then
  case "$PAGE" in
    1) printf '{"total_count":2,"workflow_runs":[{"id":%s,"conclusion":"failure","html_url":"https://x/r1"},{"id":%s,"conclusion":"failure","html_url":"https://x/r2"}]}\n' \
         "${MAIN_RUN_IDS[0]}" "${MAIN_RUN_IDS[1]}" ;;
    *) printf '{"total_count":2,"workflow_runs":[]}\n' ;;
  esac
  exit 0
fi

if [[ "$*" == *"/actions/runs/${DISPATCH_RUN_ID}" ]]; then
  printf '{"head_sha":"%s","created_at":"%s"}\n' \
    "${FAKE_HEAD_SHA:-deadbeef}" "${FAKE_RUN_CREATED_AT:-2026-09-17T12:00:00Z}"
  exit 0
fi

echo "unexpected gh invocation: $*" >&2
exit 1
STUB_EOF
chmod +x "$TMP/bin/gh"

run_collector() {
  # usage: [SELFTEST_MIN_RUNS=N|default] run_collector <label> <output-path> [ENV=VAL ...]
  #
  # The stub window holds two `main` runs, which is below the collector's compiled-in floor,
  # so every ordinary call states the weaker floor explicitly. `SELFTEST_MIN_RUNS=default`
  # appends nothing and is how the default-floor RED case is driven — which also proves the
  # compiled-in default is greater than 2 without the self-test naming its value.
  local label="$1" out="$2"; shift 2
  local min_runs="${SELFTEST_MIN_RUNS:-2}"
  local extra=()
  if [[ "$min_runs" != default ]]; then extra=(--min-main-runs "$min_runs"); fi
  # D-6: bash 3.2 errors on "${arr[@]}" for an EMPTY array under `set -u`.
  ( cd "$TMP/repo" && env "$@" \
      FAKE_GH_LOG="$TMP/${label}.calls" \
      PATH="$TMP/bin:$PATH" \
      "$COLLECTOR" --output "$out" --run-id "$DISPATCH_RUN_ID" \
        --main-window-start "$WINDOW_START" --main-window-end "$WINDOW_END" \
        ${extra[@]+"${extra[@]}"} \
      >"$TMP/${label}.out" 2>"$TMP/${label}.err" )
}

echo "capture-green-04-evidence.test"

# --- ok -----------------------------------------------------------------------
run_collector ok "$TMP/out/ok.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD"
check $? "ok: collector exits 0"
if [[ -s "$TMP/out/ok.json" ]]; then ok "ok: receipt written"; else bad "ok: receipt missing ($(cat "$TMP/ok.err"))"; fi
jq -e '.sc1.leg_count == 20 and .sc1.verdict == "pass"' "$TMP/out/ok.json" >/dev/null
check $? "ok: sc1.leg_count == 20 and verdict == pass"
jq -e '[.sc1.legs[].matrix_repeat] == [range(1;21)]' "$TMP/out/ok.json" >/dev/null
check $? "ok: matrix_repeat is exactly [1..20], ascending"
jq -e '.sc1.jobs_filter == "latest" and .sc2.jobs_filter == "latest"' "$TMP/out/ok.json" >/dev/null
check $? "ok: jobs_filter recorded as latest on both sides (D-11)"
jq -e --arg h "$REAL_HEAD" '.head_sha == $h and .clean_tree == true' "$TMP/out/ok.json" >/dev/null
check $? "ok: receipt is self-dating (head_sha + clean_tree)"
jq -e '.sc2.runs | length == 2 and (map(.run_id) == (map(.run_id) | sort))' "$TMP/out/ok.json" >/dev/null
check $? "ok: sc2.runs sorted by run_id ascending"
jq -e '.sc2.ci_gate_conclusions.success == 2 and .sc2.flake_attributable_red_count == 0' "$TMP/out/ok.json" >/dev/null
check $? "ok: sc2 verdict computed from JOB conclusions, not the run conclusion (D-08)"
jq -e '.sc2.runs | all(.run_conclusion == "failure")' "$TMP/out/ok.json" >/dev/null
check $? "ok: run-level main conclusion is failure yet ci-gate is green — the D-09 misattribution"
jq -e '.sc2.caveat | test("example_unit_smoke") and test("nine-of-ten")' "$TMP/out/ok.json" >/dev/null
check $? "ok: sc2.caveat names the example_unit_smoke nine-of-ten gap (D-10)"
grep -q 'filter=latest&per_page=100&page=1' "$TMP/ok.calls"
check $? "ok: every read passes filter=latest and per_page=100"
jq -e '.sc2.min_runs == 2' "$TMP/out/ok.json" >/dev/null
check $? "ok: the floor actually used is recorded in the receipt (D-1)"
jq -e '.sc2.window.dispatch_run_created_at == "2026-09-17T12:00:00Z"
       and (.sc2.window.binding | type == "string" and length > 0)' "$TMP/out/ok.json" >/dev/null
check $? "ok: window records the dispatch run's created_at + the enforced binding (D-5)"

# --- expected-failure helper --------------------------------------------------
expect_fail() {
  # usage: expect_fail <label> <token> <output-path> [ENV=VAL ...]
  local label="$1" token="$2" out="$3"; shift 3
  run_collector "$label" "$out" "$@"
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then ok "$label: exits non-zero"; else bad "$label: exited 0, expected failure"; fi
  if grep -q "$token" "$TMP/${label}.err"; then
    ok "$label: stderr names \`$token\`"
  else
    bad "$label: stderr does not name \`$token\` (got: $(tr '\n' ' ' <"$TMP/${label}.err"))"
  fi
  if [[ ! -e "$out" ]]; then ok "$label: no receipt at the --output path"; else bad "$label: receipt written despite failure"; fi
}

expect_fail bare_job_names no_matrix_suffix "$TMP/out/bare.json" \
  FAKE_MODE=ok FAKE_JOB_NAME_SHAPE=bare FAKE_HEAD_SHA="$REAL_HEAD"
expect_fail truncated total_count_disagreement "$TMP/out/truncated.json" \
  FAKE_MODE=ok FAKE_LEG_COUNT=30 FAKE_TOTAL_COUNT=45 FAKE_HEAD_SHA="$REAL_HEAD"
expect_fail empty_jobs insufficient_legs "$TMP/out/empty.json" \
  FAKE_MODE=ok FAKE_LEG_COUNT=0 FAKE_TOTAL_COUNT=0 FAKE_HEAD_SHA="$REAL_HEAD"
expect_fail leg_in_progress leg_without_conclusion "$TMP/out/inprogress.json" \
  FAKE_MODE=leg_in_progress FAKE_HEAD_SHA="$REAL_HEAD"
expect_fail head_mismatch evidence_run_head_sha_is_not_final_committed_head "$TMP/out/headmismatch.json" \
  FAKE_MODE=ok FAKE_HEAD_SHA=0000000000000000000000000000000000000000

# --- SC-2 selector matched zero jobs (CR-01, first half) ----------------------
# Both arms are driven by the same generator that produces the `ok` payload, so the RED is
# observed against the shape the Actions API really emits.
expect_fail sc2_smoke_job_renamed sc2_job_not_found "$TMP/out/sc2-smoke-renamed.json" \
  FAKE_MODE=ok FAKE_SC2_MODE=smoke_renamed FAKE_HEAD_SHA="$REAL_HEAD"
expect_fail sc2_gate_job_renamed sc2_job_not_found "$TMP/out/sc2-gate-renamed.json" \
  FAKE_MODE=ok FAKE_SC2_MODE=gate_renamed FAKE_HEAD_SHA="$REAL_HEAD"

# --- SC-2 matched job with no conclusion (CR-01, second half) ------------------
# A DIFFERENT token from the absent-job case above (D-2): a job that is present but still
# queued/running means the capture ran too early; an absent job means the selector is wrong.
expect_fail sc2_smoke_conclusion_null sc2_job_conclusion_null "$TMP/out/sc2-smoke-null.json" \
  FAKE_MODE=ok FAKE_SC2_MODE=smoke_null FAKE_HEAD_SHA="$REAL_HEAD"
expect_fail sc2_gate_conclusion_null sc2_job_conclusion_null "$TMP/out/sc2-gate-null.json" \
  FAKE_MODE=ok FAKE_SC2_MODE=gate_null FAKE_HEAD_SHA="$REAL_HEAD"
for null_label in sc2_smoke_conclusion_null sc2_gate_conclusion_null; do
  if ! grep -q 'sc2_job_not_found' "$TMP/${null_label}.err"; then
    ok "$null_label: does NOT collapse into the absent-job token (D-2)"
  else
    bad "$null_label: stderr names sc2_job_not_found — the two cases were collapsed"
  fi
done

# --- degenerate `main` window (CR-02, first half) ------------------------------
SELFTEST_MIN_RUNS=default expect_fail default_min_runs_floor insufficient_main_runs \
  "$TMP/out/minruns.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD"
SELFTEST_MIN_RUNS=0 expect_fail min_runs_malformed min_main_runs_malformed \
  "$TMP/out/minruns-malformed.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD"

# --- window unrelated to the dispatch run (CR-02, second half) -----------------
expect_fail window_excludes_dispatch main_window_excludes_dispatch_run \
  "$TMP/out/windowexcludes.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD" \
  FAKE_RUN_CREATED_AT=2026-09-19T00:00:00Z
if ! grep -q '/jobs?' "$TMP/window_excludes_dispatch.calls"; then
  ok "window_excludes_dispatch: no collection call issued after the binding assertion"
else
  bad "window_excludes_dispatch: a /jobs? call was issued for an unbound window"
fi

expect_fail rate_limited rate_limit_too_low "$TMP/out/ratelimited.json" \
  FAKE_MODE=rate_limited FAKE_HEAD_SHA="$REAL_HEAD"
if ! grep -q '/jobs?' "$TMP/rate_limited.calls"; then
  ok "rate_limited: no collection call issued after the preflight"
else
  bad "rate_limited: a /jobs? call was issued after a failed rate-limit preflight"
fi

# --- dirty_tree ---------------------------------------------------------------
echo "uncommitted" >"$TMP/repo/dirty.txt"
expect_fail dirty_tree dirty_tree "$TMP/out/dirty.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD"
if ! grep -q '/jobs?' "$TMP/dirty_tree.calls"; then
  ok "dirty_tree: no /jobs? call issued after the D-13 assertion"
else
  bad "dirty_tree: a /jobs? call was issued on a dirty tree"
fi
rm -f "$TMP/repo/dirty.txt"

# --- unknown flag -------------------------------------------------------------
( cd "$TMP/repo" && FAKE_GH_LOG="$TMP/unknown.calls" PATH="$TMP/bin:$PATH" \
    "$COLLECTOR" --output "$TMP/out/x.json" --run-id "$DISPATCH_RUN_ID" \
      --main-window-start "$WINDOW_START" --main-window-end "$WINDOW_END" \
      --repo other/repo >/dev/null 2>"$TMP/unknown.err" )
if [[ $? -ne 0 ]] && grep -q 'unknown_argument' "$TMP/unknown.err"; then
  ok "unknown flag: rejected (the window is not caller-steerable)"
else
  bad "unknown flag: accepted"
fi

# --- determinism --------------------------------------------------------------
run_collector det_a "$TMP/out/det-a.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD"
run_collector det_b "$TMP/out/det-b.json" FAKE_MODE=ok FAKE_HEAD_SHA="$REAL_HEAD"
cmp -s "$TMP/out/det-a.json" "$TMP/out/det-b.json"
check $? "determinism: two captures of the same window are byte-identical"

echo
echo "pass=$PASS fail=$FAIL"
if (( FAIL > 0 )); then
  echo "capture-green-04-evidence.test: FAIL"
  exit 1
fi
echo "capture-green-04-evidence.test: PASS"
