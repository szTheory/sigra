#!/usr/bin/env bash
# Phase 230 (D-21 / SC-5): the committed CI wall-clock / per-job measurement instrument.
#
# Contract: this is the ONE script that produces every "how long did a CI job take" or
# "did this run execute that job/step" claim made anywhere in Phase 230 -- and downstream,
# Phase 235's FAST-01 verdict. No wall-clock or per-job claim in this milestone is valid
# unless it was produced by invoking this script against a real run and citing the run ID
# (`.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` -- "code-level reads that never
# executed the specs" is the precedent failure mode this exists to remove).
#
# Two modes:
#   --jobs <run_id>   Single-run mode: a per-job breakdown of one run (D-24 / SC-1 / SC-2
#                      evidence). Never combined with the window sweep below -- a 40-run
#                      per-job sweep would be 40 API round-trips on its own; --jobs stays
#                      exactly one round-trip.
#   (no --jobs)        Window mode: reproduces REQUIREMENTS.md:9-13's baseline table --
#                      groups the last `--limit` runs of `--workflow` by trigger event and
#                      emits `trigger | n | mean | p50 | max | outcomes`, so an AFTER table
#                      is a plain diff against the committed baseline.
#
# p50 definition (stated here so it can never be silently reinterpreted -- an undefined
# p50 is exactly the ambiguity D-21 exists to remove): sort durations ascending, take the
# element at 0-based index floor(n/2).
#
# Duration rule (both modes): clamp negative raw durations at 0. Skipped/cancelled jobs
# and runs can report a `completedAt` a second or so *before* `startedAt`/`createdAt`
# (observed on `Upgrade smoke` and `notify_release_lane_rot` in run 30390832059) -- clamp,
# never emit a negative number. Never filter on `conclusion` for a duration -- a
# `continue-on-error: true` job/run that concludes "failure" (e.g. admin_eval_render)
# still burned real runner time and must be counted.
#
# Window `--mode`: `wall` (default) = `updatedAt - createdAt`, queue-inclusive -- this is
# the baseline's method (`230-RESEARCH.md` § D-21, reproduced to within 0.1m of
# REQUIREMENTS.md:9-13). `jobspan` = `max(job.completedAt) - min(job.startedAt)` across a
# run's jobs -- excludes queue time, so it is expected to read strictly lower than `wall`
# on the same window.
#
# Consumers:
#   - scripts/ci/ci-run-metrics.test.sh -- hermetic self-test, wired into `fast_checks`
#     (.github/workflows/ci.yml) so this contract cannot silently rot
#   - .planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md -- the phase's
#     observed-run evidence ledger; every fenced block in it is this script's verbatim stdout
#
# Security: never echoes GH_TOKEN or any secret. Reads only public `gh run list` /
# `gh run view` run metadata. `gh` is invoked bare (resolved via PATH) so the self-test can
# shadow it with a recording stub -- no network call, no GH_TOKEN, in the self-test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO="szTheory/sigra"
WORKFLOW="ci.yml"
LIMIT=40
SINCE=""
EVENT=""
MODE="wall"
FORMAT="table"
RUN_ID=""
RESERVATION_ID=""
REGISTER_LOCK=""
SOURCE_PAGES=""
UNTIL=""
THRESHOLD=720
COLLECT=false
REPLAY=false
EVALUATE_COMPARISON=false
VALIDATE_COMPARISON_PLAN=false
REGISTER_COMPARISON_RUN=false
COLLECT_PRODUCER_SOURCE=false
PRODUCER_SOURCE_SHA=""
CONTRACT_FILE=""
BEFORE_BUNDLE=""
AFTER_BUNDLE=""
REGISTRATIONS_FILE=""
PREFLIGHT=false
PREFLIGHT_OUTPUT=""
SOURCE_BUNDLE=""
TARGET_BRANCH="main"
CUTOFF=""
REDIRECT_TO_VALIDATE=""
ARTIFACT_JSON=""
RUN_JSON=""
ARCHIVE_PATH=""
ARCHIVE_OUTPUT=""
LOG_TO_REDACT=""
REDACTED_OUTPUT=""
VERIFY_BASELINE=false
DIAGNOSE_V1=false
DIAGNOSIS_OUTPUT=""
BASELINE_FILE=""
BASELINE_SOURCE_BUNDLE=""
COLLECT_COMPARISON=false
WATCH_COMPARISON_RUNS=false
WATCH_OUTPUT_DIR=""
COMPARISON_ROLE=""
COMPARISON_ATTEMPT_SCOPED=false
REQUEST_BUDGET_LEDGER=""
COMPARISON_RUNS_FILE=""
COMPARISON_SOURCE_REF=""
API_CONTRACT_SHA256=""
WATCHER_LOCK_PIDS=()
BOUNDED_REQUEST=""
REQUEST_METHOD="GET"
REQUEST_BODY=""
COLLECT_PREPARATION=false
ASSEMBLE_COMPARISON=false
BOUNDED_ARTIFACT=false
CAPTURE_RECEIPT_FILE=""
FAILED_JOB_ID=""
FAILED_JOB_RECEIPT=""
TIMEOUT_ANNOTATIONS=""
API_BUDGET_OWNER=""
API_STARTED=0
API_REQUESTS=0
API_STOP_REASON=""
API_RESET_AT=""
API_UNKNOWN='[]'
API_CORE_REMAINING=""
API_LEDGER=""
API_COMPLETED=false
API_REQUEST_LOG='[]'
API_LAST_ERROR=""
API_TEMP_DIR=""
API_LAST_RATE_REQUEST=0
API_RATE_CHECK_IN_FLIGHT=false

api_elapsed_seconds() {
  local elapsed injected
  elapsed=$(( $(date +%s) - API_STARTED ))
  if [[ "${CI_METRICS_TEST_MODE:-0}" == 1 && "${CI_METRICS_TEST_ELAPSED_SECONDS:-}" =~ ^[0-9]+$ ]]; then
    injected="$CI_METRICS_TEST_ELAPSED_SECONDS"
    (( injected > elapsed )) && elapsed="$injected"
  fi
  printf '%s' "$elapsed"
}

api_cleanup() {
  local pid
  for pid in "${WATCHER_LOCK_PIDS[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
  WATCHER_LOCK_PIDS=()
  if [[ "$API_COMPLETED" != true ]]; then api_write_ledger incomplete; fi
  [[ -n "$API_TEMP_DIR" && -d "$API_TEMP_DIR" ]] && rm -rf "$API_TEMP_DIR"
}

watcher_release_locks() {
  local pid
  for pid in "${WATCHER_LOCK_PIDS[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
  WATCHER_LOCK_PIDS=()
}

watcher_acquire_process_lock() {
  local run_id="$1" lock_path ready_path pid tries
  lock_path="${REQUEST_BUDGET_LEDGER}.watcher-${run_id}.lock"
  ready_path="$WATCH_OUTPUT_DIR/.lock-${run_id}-$$"
  rm -f "$ready_path"
  python3 - "$lock_path" "$ready_path" "$$" <<'PY' &
import fcntl, os, pathlib, sys, time
path, ready, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3])
path.parent.mkdir(parents=True, exist_ok=True)
with path.open('a+') as stream:
    try:
        fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit(3)
    ready.write_text('locked')
    while os.getppid() == parent:
        time.sleep(.1)
PY
  pid=$!
  for tries in {1..100}; do
    [[ -s "$ready_path" ]] && break
    if ! kill -0 "$pid" 2>/dev/null; then wait "$pid" 2>/dev/null || true; API_COMPLETED=true; fail "comparison_watcher_already_active:${run_id}"; fi
    sleep 0.01
  done
  [[ -s "$ready_path" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; API_COMPLETED=true; fail "comparison_watcher_lock_timeout:${run_id}"; }
  rm -f "$ready_path"
  WATCHER_LOCK_PIDS+=("$pid")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) RUN_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --workflow) WORKFLOW="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --since) SINCE="$2"; shift 2;;
    --until) UNTIL="$2"; shift 2;;
    --event) EVENT="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --source-pages) SOURCE_PAGES="$2"; shift 2;;
    --threshold) THRESHOLD="$2"; shift 2;;
    --collect) COLLECT=true; shift;;
    --collect-comparison) COLLECT_COMPARISON=true; shift;;
    --watch-comparison-runs) WATCH_COMPARISON_RUNS=true; shift;;
    --watch-output-dir) WATCH_OUTPUT_DIR="$2"; shift 2;;
    --comparison-role) COMPARISON_ROLE="$2"; shift 2;;
    --request-budget-ledger) REQUEST_BUDGET_LEDGER="$2"; shift 2;;
    --bounded-request) BOUNDED_REQUEST="$2"; shift 2;;
    --collect-preparation) COLLECT_PREPARATION=true; shift;;
    --assemble-comparison) ASSEMBLE_COMPARISON=true; shift;;
    --bounded-artifact-download) BOUNDED_ARTIFACT=true; shift;;
    --capture-receipt) CAPTURE_RECEIPT_FILE="$2"; shift 2;;
    --collect-failed-job-log) FAILED_JOB_ID="$2"; shift 2;;
    --failed-job-receipt) FAILED_JOB_RECEIPT="$2"; shift 2;;
    --timeout-annotations) TIMEOUT_ANNOTATIONS="$2"; shift 2;;
    --request-method) REQUEST_METHOD="$2"; shift 2;;
    --request-body) REQUEST_BODY="$2"; shift 2;;
    --replay) REPLAY=true; shift;;
    --evaluate-comparison) EVALUATE_COMPARISON=true; shift;;
    --validate-comparison-plan) VALIDATE_COMPARISON_PLAN=true; shift;;
    --register-comparison-run) REGISTER_COMPARISON_RUN=true; shift;;
    --collect-producer-source) COLLECT_PRODUCER_SOURCE=true; shift;;
    --producer-source-sha) PRODUCER_SOURCE_SHA="$2"; shift 2;;
    --contract) CONTRACT_FILE="$2"; shift 2;;
    --before-bundle) BEFORE_BUNDLE="$2"; shift 2;;
    --baseline-source-bundle) BASELINE_SOURCE_BUNDLE="$2"; shift 2;;
    --after-bundle) AFTER_BUNDLE="$2"; shift 2;;
    --registrations) REGISTRATIONS_FILE="$2"; shift 2;;
    --preflight) PREFLIGHT=true; shift;;
    --preflight-output) PREFLIGHT_OUTPUT="$2"; shift 2;;
    --run-id) RUN_ID="$2"; shift 2;;
    --reservation-id) RESERVATION_ID="$2"; shift 2;;
    --source-bundle) SOURCE_BUNDLE="$2"; shift 2;;
    --branch) TARGET_BRANCH="$2"; shift 2;;
    --cutoff) CUTOFF="$2"; shift 2;;
    --validate-redirect) REDIRECT_TO_VALIDATE="$2"; shift 2;;
    --validate-artifact-json) ARTIFACT_JSON="$2"; shift 2;;
    --run-json) RUN_JSON="$2"; shift 2;;
    --extract-timing-zip) ARCHIVE_PATH="$2"; shift 2;;
    --output-dir) ARCHIVE_OUTPUT="$2"; shift 2;;
    --redact-log) LOG_TO_REDACT="$2"; shift 2;;
    --redacted-output) REDACTED_OUTPUT="$2"; shift 2;;
    --verify-baseline) VERIFY_BASELINE=true; shift;;
    --diagnose-v1) DIAGNOSE_V1=true; shift;;
    --output) DIAGNOSIS_OUTPUT="$2"; shift 2;;
    --baseline) BASELINE_FILE="$2"; shift 2;;
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "ci-run-metrics: FAIL: $*" >&2
  exit 1
}

validate_download_redirect() {
  local value="$1"
  python3 - "$value" <<'PY'
import sys
from urllib.parse import urlsplit

try:
    u = urlsplit(sys.argv[1])
    host = (u.hostname or "").lower()
    port = u.port
    valid_host = host == "pipelines.actions.githubusercontent.com" or (
        host.endswith(".blob.core.windows.net")
        and host[:-len(".blob.core.windows.net")].startswith("productionresultssa")
        and host[:-len(".blob.core.windows.net")][len("productionresultssa"):].isdigit()
        and host[:-len(".blob.core.windows.net")].count(".") == 0
    )
    ok = (u.scheme.lower() == "https" and valid_host and not u.username and not u.password
          and not u.fragment and port in (None, 443) and bool(u.path) and u.path.startswith("/"))
except Exception:
    ok = False
    host = ""

if not ok:
    print("download_redirect_rejected", file=sys.stderr)
    raise SystemExit(1)
print(host)
PY
}

validate_artifact_metadata() {
  local artifact="$1" run="$2"
  jq -n --slurpfile a "$artifact" --slurpfile r "$run" '
    ($a[0]) as $artifact | ($r[0]) as $run |
    if $artifact.expired==true then {status:"expired_input",diagnostic:"expired_input"}
    elif (($artifact.id|type)!="number" or ($artifact.id|floor)!=$artifact.id) then {status:"unknown",diagnostic:"artifact_id_invalid"}
    elif (($artifact.digest // "")|test("^sha256:[0-9a-f]{64}$")|not) then {status:"unknown",diagnostic:"artifact_digest_unavailable"}
    elif (($artifact.workflow_run.id|tostring)!=($run.id|tostring) or $artifact.workflow_run.head_sha!=$run.head_sha) then {status:"unknown",diagnostic:"artifact_origin_mismatch"}
    else {status:"verified",artifact_id:$artifact.id,run_id:$run.id,source_sha:$run.head_sha,digest:$artifact.digest} end
  '
}

extract_timing_archive() {
  local zip="$1" destination="$2"
  python3 - "$zip" "$destination" <<'PY'
import hashlib, json, os, pathlib, re, stat, sys, zipfile
archive, destination = sys.argv[1:]
max_total, max_member, max_members = 512 * 1024 * 1024, 64 * 1024 * 1024, 10000
allowed = {"report.json", "playwright-report.json", "test-results.json", "timing.json", "ci-timing.json", "metrics.json", "manifest.json", "ci-measurement-metadata.json", "ci-exunit-timing-main.json", "ci-exunit-timing-threadline-guard.json", "admin-behavior.json", "admin-checkpoints.json", "design-gallery-pr-behavior.json", "design-gallery-nonpr-snapshots.json", "design-gallery-nonpr-behavior.json", "non-admin-smoke.json", "demo-showcase.json", "coverage-source.json", "execution-record.json"}
try:
    os.makedirs(destination, exist_ok=True)
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        if len(infos) > max_members: raise ValueError("archive_member_limit_exceeded")
        total, seen, selected, skipped = 0, set(), [], []
        for info in infos:
            name = info.filename
            if "\\" in name or name.startswith("/") or re.match(r"^[A-Za-z]:", name): raise ValueError("unsafe_archive_path")
            if any(part in ("..", "", ".") for part in pathlib.PurePosixPath(name).parts): raise ValueError("unsafe_archive_path")
            mode = (info.external_attr >> 16) & 0xffff
            if stat.S_ISLNK(mode): raise ValueError("archive_symlink_rejected")
            if info.is_dir(): continue
            if info.file_size > max_member: raise ValueError("archive_member_limit_exceeded")
            total += info.file_size
            if total > max_total: raise ValueError("archive_total_limit_exceeded")
            if name in seen: raise ValueError("duplicate_archive_member")
            seen.add(name)
            basename = pathlib.PurePosixPath(name).name.lower()
            native_coverage = basename in allowed or basename.endswith(".selection.json")
            if not native_coverage:
                if pathlib.PurePosixPath(name).suffix.lower() == ".json": raise ValueError("unexpected_archive_json")
                skipped.append(pathlib.PurePosixPath(name).name[:128])
                continue
            selected.append(info)
        if not selected: raise ValueError("expected_timing_json_missing")
        used, output = set(), []
        for info in selected:
            relative = pathlib.PurePosixPath(info.filename)
            basename = relative.name
            # Preserve nested native report paths referenced by coverage-source.json;
            # keep legacy timing artifacts flat for existing consumers.
            native_path = basename == "coverage-source.json" or basename.endswith(".selection.json") or basename in {"report.json", "playwright-report.json", "test-results.json"}
            output_path = relative.as_posix() if native_path else basename
            if output_path in used: raise ValueError("duplicate_archive_path")
            used.add(output_path)
            target = os.path.join(destination, output_path); os.makedirs(os.path.dirname(target), exist_ok=True); temp = target + ".tmp"; written = 0
            with zf.open(info) as src, open(temp, "wb") as dst:
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk: break
                    written += len(chunk)
                    if written > max_member or total - info.file_size + written > max_total: raise ValueError("archive_expansion_limit_exceeded")
                    dst.write(chunk)
            if written != info.file_size: raise ValueError("archive_member_size_mismatch")
            with open(temp, "rb") as f: json.load(f)
            os.replace(temp, target); output.append({"member":info.filename,"path":target,"bytes":written,"sha256":hashlib.sha256(pathlib.Path(target).read_bytes()).hexdigest()})
        print(json.dumps({"status":"accepted","members":output,"skipped_non_json_members":skipped[:100]}, sort_keys=True))
except Exception as exc:
    print(str(exc) if isinstance(exc, ValueError) else "archive_invalid", file=sys.stderr)
    raise SystemExit(1)
PY
}

redact_log_file() {
  local source="$1" destination="$2" extent="${3:-excerpt}"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$source" "$destination" "$extent" <<'PY'
import pathlib, sys
from ci_metrics_security import sanitize_failure_log
source, destination = map(pathlib.Path, sys.argv[1:3])
report = sanitize_failure_log(source.read_bytes(), max_output_bytes=1024*1024) if sys.argv[3]=='full' else sanitize_failure_log(source.read_bytes())
destination.parent.mkdir(parents=True, exist_ok=True)
temp = destination.with_suffix(destination.suffix + ".tmp")
temp.write_text(report["text"], encoding="utf-8")
temp.replace(destination)
PY
}

extract_snapshot_bundle() {
  local archive="$1" destination="$2"
  python3 - "$archive" "$destination" <<'PY'
import os, pathlib, shutil, sys, tarfile
archive, destination = map(pathlib.Path, sys.argv[1:])
max_total, max_member, max_members = 768 * 1024 * 1024, 128 * 1024 * 1024, 20000
try:
    destination.mkdir(parents=True, exist_ok=False)
    total = 0
    with tarfile.open(archive, 'r:gz') as tf:
        members = tf.getmembers()
        if len(members) > max_members: raise ValueError('snapshot_member_limit_exceeded')
        for member in members:
            name = member.name
            path = pathlib.PurePosixPath(name)
            if '\\' in name or path.is_absolute() or any(part in ('', '.', '..') for part in path.parts):
                raise ValueError('unsafe_snapshot_path')
            if member.issym() or member.islnk() or not (member.isdir() or member.isfile()):
                raise ValueError('unsafe_snapshot_member_type')
            if member.size > max_member: raise ValueError('snapshot_member_limit_exceeded')
            total += member.size
            if total > max_total: raise ValueError('snapshot_total_limit_exceeded')
            target = destination.joinpath(*path.parts)
            if destination not in target.parents and target != destination: raise ValueError('unsafe_snapshot_path')
            if member.isdir(): target.mkdir(parents=True, exist_ok=True); continue
            target.parent.mkdir(parents=True, exist_ok=True)
            source = tf.extractfile(member)
            if source is None: raise ValueError('snapshot_member_unreadable')
            with source, target.open('xb') as output: shutil.copyfileobj(source, output, 1024 * 1024)
            if target.stat().st_size != member.size: raise ValueError('snapshot_member_size_mismatch')
except Exception as exc:
    shutil.rmtree(destination, ignore_errors=True)
    print(str(exc) if isinstance(exc, ValueError) else 'snapshot_archive_invalid', file=sys.stderr)
    raise SystemExit(1)
PY
}

api_external_reserve() {
  local endpoint="$1" elapsed timeout_cmd
  if (( API_LAST_RATE_REQUEST > 0 && API_REQUESTS - API_LAST_RATE_REQUEST >= 100 )); then
    local rate_file="${API_TEMP_DIR:-${TMPDIR:-/tmp}}/ci-metrics-rate-refresh-$$-${API_REQUESTS}.json"
    api_get rate_limit "$rate_file" || return 1
    if [[ -n "$API_LEDGER" && -f "$rate_file" ]]; then
      mkdir -p "${API_LEDGER%/*}/raw/rate-limits"
      cp "$rate_file" "${API_LEDGER%/*}/raw/rate-limits/${API_REQUESTS}.json" 2>/dev/null || true
    fi
  fi
  elapsed="$(api_elapsed_seconds)"
  (( elapsed < 3600 )) || { api_stop time_limit_exhausted "" "$endpoint"; return 1; }
  (( API_REQUESTS < 600 )) || { api_stop request_limit_exhausted "" "$endpoint"; return 1; }
  [[ -z "$API_CORE_REMAINING" || "$API_CORE_REMAINING" -gt 250 ]] || { api_stop core_rate_limit_stop "$API_RESET_AT" "$endpoint"; return 1; }
  timeout_cmd="$(command -v timeout || command -v gtimeout || true)"
  [[ -n "$timeout_cmd" ]] || { api_stop request_deadline_enforcer_unavailable "" "$endpoint"; return 1; }
  request_budget_reserve "$endpoint" || { api_stop "$API_STOP_REASON" "$API_RESET_AT" "$endpoint"; return 1; }
  if [[ "$API_CORE_REMAINING" =~ ^[0-9]+$ ]]; then API_CORE_REMAINING=$((API_CORE_REMAINING - 1)); fi
  ((API_REQUESTS+=1))
  API_REQUEST_LOG="$(jq -cn --arg endpoint "$endpoint" --argjson prior "$API_REQUEST_LOG" '$prior + [$endpoint]')"
  api_write_ledger collecting
}

api_download_no_follow() {
  local url="$1" destination="$2" category="$3" token="" host host_kind headers body status_code location location_count elapsed timeout_cmd attempt rc log_cap_bytes
  [[ "$url" == https://api.github.com/* ]] || { api_stop download_api_origin_rejected "" "$category"; return 1; }
  if [[ -n "${GH_TOKEN:-}" ]]; then token="$GH_TOKEN"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then token="$GITHUB_TOKEN"
  else token="$(gh auth token 2>/dev/null || true)"; fi
  [[ -n "$token" ]] || { api_stop download_auth_unavailable "" "$category"; return 1; }
  host_kind=api
  log_cap_bytes=0
  [[ "$category" == job-log:* ]] && log_cap_bytes=1048576
  for ((hop=0; hop<=3; hop++)); do
    if [[ "$host_kind" == api ]]; then host=api.github.com; else host="$host_kind"; fi
    api_external_reserve "download:${category}:${host}" || return 1
    elapsed="$(api_elapsed_seconds)"; timeout_cmd="$(command -v timeout || command -v gtimeout || true)"
    local request_timeout=$((3600-elapsed)); (( request_timeout > 30 )) && request_timeout=30
    headers="${API_TEMP_DIR:-${TMPDIR:-/tmp}}/ci-download-headers-$$-${API_REQUESTS}"
    body="${API_TEMP_DIR:-${TMPDIR:-/tmp}}/ci-download-body-$$-${API_REQUESTS}"
    attempt=0
    while :; do
      set +e
      if [[ "$host_kind" == api ]]; then
        if (( log_cap_bytes > 0 )); then
          status_code="$(printf 'header = "Authorization: Bearer %s"\n' "$token" | "$timeout_cmd" --signal=TERM "${request_timeout}s" curl --config - --silent --show-error --max-redirs 0 --request GET --max-time "$request_timeout" --max-filesize "$log_cap_bytes" --dump-header "$headers" --output "$body" --write-out '%{http_code}' "$url" 2>/dev/null)"
        else
          status_code="$(printf 'header = "Authorization: Bearer %s"\n' "$token" | "$timeout_cmd" --signal=TERM "${request_timeout}s" curl --config - --silent --show-error --max-redirs 0 --request GET --max-time "$request_timeout" --dump-header "$headers" --output "$body" --write-out '%{http_code}' "$url" 2>/dev/null)"
        fi
      else
        if (( log_cap_bytes > 0 )); then
          status_code="$("$timeout_cmd" --signal=TERM "${request_timeout}s" curl --silent --show-error --max-redirs 0 --request GET --max-time "$request_timeout" --max-filesize "$log_cap_bytes" --dump-header "$headers" --output "$body" --write-out '%{http_code}' "$url" 2>/dev/null)"
        else
          status_code="$("$timeout_cmd" --signal=TERM "${request_timeout}s" curl --silent --show-error --max-redirs 0 --request GET --max-time "$request_timeout" --dump-header "$headers" --output "$body" --write-out '%{http_code}' "$url" 2>/dev/null)"
        fi
      fi
      rc=$?
      set -e
      if (( rc != 0 )); then status_code=000; fi
      [[ "$status_code" =~ ^[0-9]{3}$ ]] || status_code=000
      if [[ "$status_code" == 403 || "$status_code" == 429 ]]; then
        location="$(awk 'BEGIN{IGNORECASE=1} tolower($1)=="retry-after:"||tolower($1)=="x-ratelimit-reset:" {gsub("\\r",""); print $2; exit}' "$headers" 2>/dev/null || true)"
        request_budget_record_response "$API_CORE_REMAINING" "$location" "http_rate_limit"
        api_stop http_rate_limit "$location" "$category"; rm -f "$headers" "$body"; return 1
      fi
      if [[ "$status_code" =~ ^5(00|02|03|04)$ || "$status_code" == 000 ]]; then
        if (( attempt == 0 )) && (( API_REQUESTS < 600 )) && (( $(api_elapsed_seconds) < 3600 )); then
          attempt=1; api_external_reserve "download:${category}:${host}:retry" || return 1; continue
        fi
        api_stop download_unavailable "" "$category"; rm -f "$headers" "$body"; return 1
      fi
      break
    done
    if [[ "$status_code" == 200 ]]; then
      if (( log_cap_bytes > 0 )) && (( $(wc -c <"$body") > log_cap_bytes )); then
        api_stop failed_log_input_too_large "" "$category"; rm -f "$headers" "$body"; return 1
      fi
      mkdir -p "$(dirname "$destination")"; mv "$body" "$destination"; rm -f "$headers"; return 0
    fi
    if [[ "$status_code" =~ ^30[12378]$ ]]; then
      location_count="$(awk 'BEGIN{IGNORECASE=1} tolower($1)=="location:" {n++} END{print n+0}' "$headers" 2>/dev/null || echo 0)"
      location="$(awk 'BEGIN{IGNORECASE=1} tolower($1)=="location:" {sub(/^[^:]*:[[:space:]]*/,""); gsub("\\r",""); print; n++} END{if(n!=1) exit 1}' "$headers" 2>/dev/null || true)"
      rm -f "$headers" "$body"
      if [[ "$location_count" != 1 || -z "$location" || "$hop" -eq 3 ]]; then api_stop download_redirect_rejected "" "$category"; return 1; fi
      if ! host="$(validate_download_redirect "$location" 2>/dev/null)"; then api_stop download_redirect_rejected "" "$category"; return 1; fi
      url="$location"; token=""; host_kind="$host"; continue
    fi
    rm -f "$headers" "$body"
    if [[ "$status_code" == 410 || "$status_code" == 404 ]]; then api_stop expired_input "" "$category"; else api_stop download_unavailable "" "$category"; fi
    return 1
  done
  api_stop download_redirect_rejected "" "$category"
}

# All new GitHub reads, including the first rate-limit preflight, pass through
# this single bounded GET helper. The source bundle's ledger is rewritten after
# every response so an interruption leaves a useful, durable diagnostic.
api_write_ledger() {
  [[ -n "$API_LEDGER" ]] || return 0
  mkdir -p "$(dirname "$API_LEDGER")"
  jq -n --arg status "${1:-incomplete}" --arg stop_reason "$API_STOP_REASON" \
    --arg reset_at "$API_RESET_AT" --arg contract_sha256 "$API_CONTRACT_SHA256" --argjson request_count "$API_REQUESTS" \
    --argjson unknown_inputs "$API_UNKNOWN" --argjson requests "$API_REQUEST_LOG" \
    '{status:$status,request_count:$request_count,stop_reason:(if $stop_reason=="" then null else $stop_reason end),reset_or_retry_at:(if $reset_at=="" then null else $reset_at end),unknown_inputs:$unknown_inputs,requests:$requests} + (if $contract_sha256=="" then {} else {contract_sha256:$contract_sha256} end)' \
    >"${API_LEDGER}.tmp" && mv "${API_LEDGER}.tmp" "$API_LEDGER" && { sync "$API_LEDGER" 2>/dev/null || sync 2>/dev/null || true; }
}

api_stop() {
  API_STOP_REASON="$1"
  [[ -n "${2:-}" ]] && API_RESET_AT="$2"
  API_UNKNOWN="$(jq -cn --arg reason "$1" --arg endpoint "${3:-unknown}" '[{reason:$reason,endpoint:$endpoint}]')"
  api_write_ledger incomplete
  return 1
}

request_budget_reserve() {
  [[ -n "$REQUEST_BUDGET_LEDGER" ]] || return 0
  [[ -s "$CONTRACT_FILE" && -s "$REQUEST_BUDGET_LEDGER" ]] || { API_STOP_REASON=request_budget_ledger_missing; return 1; }
  local result reason remaining
  result="$(PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" "$1" "${API_BUDGET_OWNER:-collector}" <<'PY'
import json,pathlib,sys
from ci_metrics_security import comparison_request_budget_reserve
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
try:
    print(json.dumps(comparison_request_budget_reserve(contract,pathlib.Path(sys.argv[2]),sys.argv[3],owner=sys.argv[4])))
except (OSError,ValueError,TypeError) as error:
    print(json.dumps({'error':str(error)})); raise SystemExit(1)
PY
)" || { reason="$(jq -r '.error // "request_budget_reservation_failed"' <<<"$result")"; API_STOP_REASON="$reason"; return 1; }
  remaining="$(jq -r '.core_remaining // empty' <<<"$result")"
  if [[ "$remaining" =~ ^[0-9]+$ ]]; then
    local pre_request=$((remaining + 1))
    if [[ "$API_CORE_REMAINING" =~ ^[0-9]+$ ]]; then (( pre_request < API_CORE_REMAINING )) && API_CORE_REMAINING="$pre_request"; else API_CORE_REMAINING="$pre_request"; fi
  fi
  return 0
}

request_budget_record_response() {
  [[ -n "$REQUEST_BUDGET_LEDGER" ]] || return 0
  local core="${1:-}" reset="${2:-}" stop="${3:-}"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" "$core" "$reset" "$stop" <<'PY'
import json,pathlib,sys
from ci_metrics_security import comparison_request_budget_record_response
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
number=lambda value: int(value) if value.isdigit() else None
comparison_request_budget_record_response(contract,pathlib.Path(sys.argv[2]),core_remaining=number(sys.argv[3]),reset_at=number(sys.argv[4]),stop_reason=sys.argv[5] or None)
PY
}

api_get() {
  local endpoint="$1" output_file="$2" method="${3:-GET}" body="${4:-}" response rc attempt err_file elapsed remaining reset timeout_cmd
  if [[ "$endpoint" != "rate_limit" && "$endpoint" != "/rate_limit" && "$API_RATE_CHECK_IN_FLIGHT" != true && "$API_LAST_RATE_REQUEST" -gt 0 ]] && (( API_REQUESTS - API_LAST_RATE_REQUEST >= 100 )); then
    API_RATE_CHECK_IN_FLIGHT=true
    local rate_file="${API_LEDGER%/*}/rate-limit-refresh-${API_REQUESTS}.json"
    if ! api_get rate_limit "$rate_file"; then API_RATE_CHECK_IN_FLIGHT=false; return 1; fi
    API_RATE_CHECK_IN_FLIGHT=false
    [[ -d "${API_LEDGER%/*}/raw/rate-limits" ]] && cp "$rate_file" "${API_LEDGER%/*}/raw/rate-limits/${API_REQUESTS}.json" || true
  fi
  elapsed="$(api_elapsed_seconds)"
  (( elapsed < 3600 )) || { api_stop time_limit_exhausted "" "$endpoint"; return 1; }
  (( API_REQUESTS < 600 )) || { api_stop request_limit_exhausted "" "$endpoint"; return 1; }
  timeout_cmd="$(command -v timeout || command -v gtimeout || true)"
  [[ -n "$timeout_cmd" ]] || { api_stop request_deadline_enforcer_unavailable "" "$endpoint"; return 1; }
  if [[ -n "$API_CORE_REMAINING" ]] && (( API_CORE_REMAINING <= 250 )); then
    api_stop core_rate_limit_stop "$API_RESET_AT" "$endpoint"; return 1
  fi
  attempt=0
  while :; do
    request_budget_reserve "$endpoint" || { api_stop "$API_STOP_REASON" "$API_RESET_AT" "$endpoint"; return 1; }
    if [[ "$API_CORE_REMAINING" =~ ^[0-9]+$ ]]; then
      (( API_CORE_REMAINING > 250 )) || { api_stop core_rate_limit_stop "$API_RESET_AT" "$endpoint"; return 1; }
      API_CORE_REMAINING=$((API_CORE_REMAINING - 1))
    fi
    ((API_REQUESTS+=1))
    API_REQUEST_LOG="$(jq -cn --arg endpoint "$endpoint" --argjson prior "$API_REQUEST_LOG" '$prior + [$endpoint]')"
    err_file="${TMPDIR:-/tmp}/ci-run-metrics-gh-error.$$"
    local request_timeout=$((3600-elapsed))
    (( request_timeout > 30 )) && request_timeout=30
    (( request_timeout > 0 )) || { api_stop time_limit_exhausted "" "$endpoint"; return 1; }
    set +e
    local request_args=(api --method "$method" "$endpoint")
    [[ -z "$body" ]] || request_args+=(--input "$body")
    "$timeout_cmd" --signal=TERM "${request_timeout}s" gh "${request_args[@]}" >"${output_file}.tmp" 2>"$err_file"
    rc=$?
    set -e
    response="$(cat "$err_file" 2>/dev/null || true)"
    rm -f "$err_file"
    API_LAST_ERROR="$response"
    if (( rc == 0 )); then
      mv "${output_file}.tmp" "$output_file"
      if [[ "$endpoint" == "rate_limit" || "$endpoint" == "/rate_limit" ]]; then
        local observed_remaining
        observed_remaining="$(jq -r '.resources.core.remaining // empty' "$output_file" 2>/dev/null || true)"
        if [[ "$observed_remaining" =~ ^[0-9]+$ ]]; then
          if [[ "$API_CORE_REMAINING" =~ ^[0-9]+$ ]]; then
            (( observed_remaining < API_CORE_REMAINING )) && API_CORE_REMAINING="$observed_remaining"
          else
            API_CORE_REMAINING="$observed_remaining"
          fi
        fi
        API_RESET_AT="$(jq -r '.resources.core.reset // empty' "$output_file" 2>/dev/null || true)"
        API_LAST_RATE_REQUEST="$API_REQUESTS"
        request_budget_record_response "$API_CORE_REMAINING" "$API_RESET_AT" ""
      fi
      api_write_ledger collecting
      return 0
    fi
    rm -f "${output_file}.tmp"
    if [[ "$response" =~ (HTTP[[:space:]]+)?(403|429) ]]; then
      reset="$(printf '%s' "$response" | sed -nE 's/.*(retry-after|x-ratelimit-reset)[^0-9]*([0-9]+).*/\2/ip' | head -1)"
      [[ -n "$reset" ]] && API_RESET_AT="$reset"
      request_budget_record_response "$API_CORE_REMAINING" "$API_RESET_AT" "http_rate_limit"
      api_stop http_rate_limit "$API_RESET_AT" "$endpoint"
      return 1
    fi
    if [[ "$method" == GET ]] && (( attempt == 0 )) && [[ "$response" =~ (HTTP[[:space:]]+)?(500|502|503|504)|timed[[:space:]]out|connection[[:space:]]reset|temporary[[:space:]]failure ]]; then
      attempt=1
      # Retry is a counted request and still must fit both limits.
      elapsed="$(api_elapsed_seconds)"
      (( API_REQUESTS < 600 && elapsed < 3600 )) || { api_stop retry_budget_exhausted "" "$endpoint"; return 1; }
      continue
    fi
    api_stop source_unavailable "" "$endpoint"
    return 1
  done
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}

approved_required_contexts() {
  printf '%s\n' '["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"]'
}

derive_required_contexts() {
  local effective="$1" protection="$2" rules_json='[]' protection_json='{}'
  [[ -s "$effective" ]] && rules_json="$(cat "$effective")"
  [[ -s "$protection" ]] && protection_json="$(cat "$protection")"
  jq -cn --argjson approved "$(approved_required_contexts)" --argjson rules "$rules_json" --argjson protection "$protection_json" '
    ($rules // []) as $ruleset_rules |
    ([$ruleset_rules[]? | select(.type=="required_status_checks") | .parameters.required_status_checks[]?] | unique_by(.context)) as $effective_rows |
    ([$effective_rows[].context] | unique) as $effective_contexts |
    ([$protection.contexts[]?] | unique) as $branch_contexts |
    (if ($effective_contexts|length)>0 then $effective_contexts else $branch_contexts end) as $actual |
    (if ($effective_contexts|length)>0 then "effective_rules" else "branch_protection" end) as $source |
    (if $source=="effective_rules" then [$effective_rows[] | {key:.context,value:(.integration_id // .app_id // null)}]
      else [$branch_contexts[] as $context | {key:$context,value:([$protection.checks[]? | select(.context==$context) | .app_id][0] // null)}] end | from_entries) as $app_ids |
    (if $source=="effective_rules" then [$ruleset_rules[]? | select(.type=="required_status_checks") | . as $rule | $rule.parameters.required_status_checks[]? as $check | {context:$check.context,app_id:($check.integration_id // $check.app_id // null),ruleset_id:$rule.ruleset_id,ruleset_source:$rule.ruleset_source,source:"effective_rules"}]
      else [$branch_contexts[] as $context | {context:$context,app_id:([$protection.checks[]? | select(.context==$context) | .app_id][0] // null),ruleset_id:null,ruleset_source:null,source:"branch_protection"}] end) as $provenance |
    {expected:$approved,actual:$actual,app_ids:$app_ids,source:$source,provenance:$provenance,changed:(($actual|sort)!=($approved|sort)),diagnostics:(if ($actual|sort)==($approved|sort) then [] else [{reason:"required_rules_changed",expected:$approved,actual:$actual,source:$source}] end)}'
}

collect_window() {
  [[ "$REPO" == "szTheory/sigra" ]] || fail "collect_repo_mismatch"
  [[ "$WORKFLOW" == "ci.yml" ]] || fail "collect_workflow_mismatch"
  [[ -n "$SOURCE_BUNDLE" && -n "$CUTOFF" ]] || fail "window_collect_requires_cutoff_and_source_bundle"
  [[ "$CUTOFF" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || fail "cutoff_must_be_utc_rfc3339"
  jq -en --arg cutoff "$CUTOFF" 'try ($cutoff|fromdateiso8601) catch false' >/dev/null || fail "cutoff_invalid"
  [[ ! -e "$SOURCE_BUNDLE" ]] || fail "source_bundle_already_exists"

  local lock="${SOURCE_BUNDLE}.lock" stage="${SOURCE_BUNDLE}.staging" tmp since cutoff_epoch total_count page page_file page_count selected_json selected_count population_name event branch endpoint runs_json capped exhausted stop_reason detail_note manifest_status workflow_sha workflow_blob tree_sha request_hash selection_hash request_count manual_json release_json source_hashes required_contexts required_provenance required_info active_rules manual_hash release_hash producer_refs producer_sha producer_dir producer_tree_sha producer_parent_valid workflow_content producer_meta
  mkdir -p "$(dirname "$SOURCE_BUNDLE")"
  [[ ! -e "$stage" ]] || fail "source_bundle_staging_exists"
  mkdir "$lock" 2>/dev/null || fail "source_bundle_locked"
  printf '{"pid":%s,"started_at":"%s"}\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$lock/owner.json"
  mkdir -p "$stage/raw/populations"
  mkdir -p "$stage/source"
  cp "$ROOT/.github/workflows/ci.yml" "$stage/source/ci.yml"
  cp "$ROOT/scripts/ci/ci-run-metrics.sh" "$stage/source/ci-run-metrics.sh"
  cp "$ROOT/scripts/ci/ci_metrics_security.py" "$stage/source/ci_metrics_security.py"
  cp "$ROOT/scripts/ci/exunit_timing_contract.py" "$stage/source/exunit_timing_contract.py"
  cp "$ROOT/scripts/ci/ci-playwright-report.mjs" "$stage/source/ci-playwright-report.mjs"
  cp "$ROOT/scripts/ci/ci-playwright-report.test.mjs" "$stage/source/ci-playwright-report.test.mjs"
  cp "$ROOT/scripts/ci/sigra-dep-off.sh" "$stage/source/sigra-dep-off.sh"
  cp "$ROOT/mix.exs" "$stage/source/mix.exs"
  cp "$ROOT/test/support/ci_timing_formatter.ex" "$stage/source/ci_timing_formatter.ex"
  cp "$ROOT/test/test_helper.exs" "$stage/source/test_helper.exs"
  cp "$ROOT/test/example/priv/playwright/playwright.config.ts" "$stage/source/playwright.config.ts"
  cp "$ROOT/test/example/priv/playwright/package-lock.json" "$stage/source/playwright-package-lock.json"
  if [[ -n "$COMPARISON_SOURCE_REF" ]]; then
    local source_target source_path
    while IFS='|' read -r source_target source_path; do
      git -C "$ROOT" show "${COMPARISON_SOURCE_REF}:${source_path}" >"$stage/source/$source_target" || fail "comparison_source_file_unavailable:$source_path"
    done <<'SOURCE_PATHS'
ci.yml|.github/workflows/ci.yml
ci-playwright-report.mjs|scripts/ci/ci-playwright-report.mjs
ci-playwright-report.test.mjs|scripts/ci/ci-playwright-report.test.mjs
sigra-dep-off.sh|scripts/ci/sigra-dep-off.sh
mix.exs|mix.exs
ci_timing_formatter.ex|test/support/ci_timing_formatter.ex
test_helper.exs|test/test_helper.exs
playwright.config.ts|test/example/priv/playwright/playwright.config.ts
playwright-package-lock.json|test/example/priv/playwright/package-lock.json
SOURCE_PATHS
  fi
  API_LEDGER="$stage/request-ledger.json"
  API_STARTED="$(date +%s)"
  API_COMPLETED=false
  API_REQUESTS=0
  API_STOP_REASON=""
  API_RESET_AT=""
  API_CORE_REMAINING=""
  API_UNKNOWN='[]'
  API_REQUEST_LOG='[]'
  API_LAST_RATE_REQUEST=0
  API_RATE_CHECK_IN_FLIGHT=false
  if [[ "${CI_METRICS_TEST_MODE:-0}" == 1 && "${CI_METRICS_TEST_PRIOR_REQUESTS:-}" =~ ^[0-9]+$ ]] && (( CI_METRICS_TEST_PRIOR_REQUESTS <= 600 )); then API_REQUESTS="$CI_METRICS_TEST_PRIOR_REQUESTS"; fi
  API_LAST_ERROR=""
  API_TEMP_DIR=""
  tmp="$(mktemp -d)"
  API_TEMP_DIR="$tmp"
  API_STOP_REASON=""
  API_RESET_AT=""
  API_CORE_REMAINING=""
  API_UNKNOWN='[]'
  API_REQUEST_LOG='[]'
  if [[ "${CI_METRICS_TEST_MODE:-0}" == 1 && "${CI_METRICS_TEST_PRIOR_REQUESTS:-}" =~ ^[0-9]+$ ]] && (( CI_METRICS_TEST_PRIOR_REQUESTS <= 600 )); then API_REQUESTS="$CI_METRICS_TEST_PRIOR_REQUESTS"; fi
  : >"$stage/selection-ledger.json"
  printf '{"schema_version":"sigra.ci-run-metrics/selection-ledger-v1","cutoff_utc":"%s","populations":[]}\n' "$CUTOFF" >"$stage/selection-ledger.json"
  jq -n --arg cutoff "$CUTOFF" --arg status incomplete --arg repo "$REPO" --arg workflow "$WORKFLOW" '{schema_version:"sigra.ci-run-metrics/snapshot-v1",repository:$repo,workflow:$workflow,cutoff_utc:$cutoff,status:$status,request_count:0,stop_reason:"collection_in_progress",populations:{}}' >"$stage/manifest.json"
  window_collect_interrupt() {
    API_STOP_REASON="interrupted"
    api_write_ledger incomplete
    local interrupted_dir="$stage"
    [[ -d "$stage" ]] || interrupted_dir="$SOURCE_BUNDLE"
    mkdir -p "$interrupted_dir"
    jq -n --arg repo "$REPO" --arg workflow "$WORKFLOW" --arg cutoff "$CUTOFF" --arg since "${since:-}" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson requests "$API_REQUESTS" --argjson selections "$(cat "$interrupted_dir/selection-ledger.json" 2>/dev/null || echo '{}')" --arg request_hash "$(sha256_file "$interrupted_dir/request-ledger.json" 2>/dev/null || echo '')" --arg selection_hash "$(sha256_file "$interrupted_dir/selection-ledger.json" 2>/dev/null || echo '')" '{schema_version:"sigra.ci-run-metrics/snapshot-v1",repository:$repo,workflow:$workflow,cutoff_utc:$cutoff,window_start_utc:(if $since=="" then null else $since end),status:"incomplete",stop_reason:"interrupted",interrupted_at_utc:$at,request_count:$requests,selection_ledger:$selections,source_sha256:{request_ledger:$request_hash,selection_ledger:$selection_hash},populations:{}}' >"$interrupted_dir/manifest.json"
    sync 2>/dev/null || true
    mv "$stage" "$SOURCE_BUNDLE" 2>/dev/null || true
    rm -rf "$lock" "$API_TEMP_DIR"
    exit 130
  }
  trap 'window_collect_interrupt' INT TERM HUP

  # Check rate budget before any population query, then refresh live rules inside
  # the same shared request guard used by Plan 01.
  if ! api_get rate_limit "$tmp/rate-limit.json"; then API_STOP_REASON="${API_STOP_REASON:-rate_limit_preflight}"; fi
  if [[ -z "$API_STOP_REASON" ]]; then
    api_get "/repos/${REPO}/rules/branches/${TARGET_BRANCH}" "$tmp/effective-rules.json" || API_STOP_REASON="${API_STOP_REASON:-effective_rules_unavailable}"
  fi
  if [[ -z "$API_STOP_REASON" ]]; then
    api_get "/repos/${REPO}/branches/${TARGET_BRANCH}/protection/required_status_checks" "$tmp/branch-protection.json" || { if [[ "$API_LAST_ERROR" =~ 404 ]]; then jq -n '{status:"not_configured",http_status:404}' >"$tmp/branch-protection.json"; API_STOP_REASON=""; else API_STOP_REASON="${API_STOP_REASON:-branch_protection_unavailable}"; fi; }
  fi
  if [[ -z "$API_STOP_REASON" ]]; then api_get "/repos/${REPO}/rulesets?per_page=100" "$tmp/rulesets.json" || API_STOP_REASON="${API_STOP_REASON:-active_rulesets_unavailable}"; fi
  [[ -s "$tmp/rate-limit.json" ]] && cp "$tmp/rate-limit.json" "$stage/raw/rate-limit.json"
  [[ -s "$tmp/effective-rules.json" ]] && cp "$tmp/effective-rules.json" "$stage/raw/effective-rules.json"
  [[ -s "$tmp/branch-protection.json" ]] && cp "$tmp/branch-protection.json" "$stage/raw/branch-protection.json"
  [[ -s "$tmp/rulesets.json" ]] && cp "$tmp/rulesets.json" "$stage/raw/rulesets.json"

  cutoff_epoch="$(jq -nr --arg t "$CUTOFF" '$t|fromdateiso8601')"
  since="$(jq -nr --argjson t "$cutoff_epoch" '($t-2592000)|todateiso8601')"
  local collect_one_population
  collect_one_population() {
    local name="$1" ev="$2" br="$3" out="$stage/raw/populations/$1.json"
    local p=1 total='' response returned filtered valid id registration
    local selected_file="$tmp/${name}-selected.json" filtered_file="$tmp/${name}-filtered.json" pages_file="$tmp/${name}-pages.json"
    printf '[]\n' >"$selected_file"
    printf '[]\n' >"$pages_file"
    if [[ -n "$COMPARISON_RUNS_FILE" ]]; then
      if [[ "$name" != pull_request ]]; then
        jq -n --arg name "$name" --arg event "$ev" '{population:$name,event:$event,api_total_count:0,population_capped:false,population_exhausted:true,selected_run_ids:[],runs:[],pages:[],detail_status:"complete"}' >"$out"
        return 0
      fi
      while IFS= read -r registration; do
        [[ -n "$registration" ]] || continue
        id="$(jq -r '.run_id' <<<"$registration")"
        attempt="$(jq -r '.run_attempt // empty' <<<"$registration")"
        sample_id="$(jq -r '.sample_id // .run_id' <<<"$registration")"
        API_BUDGET_OWNER="sample:${id}:${attempt:-legacy}"
        page_file="$tmp/${name}-run-${sample_id}.json"
        endpoint="/repos/${REPO}/actions/runs/${id}"
        [[ -z "$attempt" ]] || endpoint+="/attempts/${attempt}"
        api_get "$endpoint" "$page_file" || { API_STOP_REASON="${API_STOP_REASON:-registered_run_unavailable}"; break; }
        PYTHONPATH="$ROOT/scripts/ci" python3 - "$registration" "$page_file" <<'PY' || { API_STOP_REASON="registered_run_identity_mismatch"; break; }
import json,pathlib,sys
from ci_metrics_security import validate_registered_run_observation
registration=json.loads(sys.argv[1]); run=json.loads(pathlib.Path(sys.argv[2]).read_text())
errors=validate_registered_run_observation(registration,run)
if errors: raise SystemExit(','.join(errors))
PY
        jq -cn --arg sample_id "$sample_id" --argjson attempt "${attempt:-0}" --slurpfile prior "$selected_file" --slurpfile run "$page_file" '$prior[0]+[($run[0]+{comparison_sample_id:$sample_id,comparison_attempt:(if $attempt==0 then null else $attempt end)})]' >"$selected_file.tmp" && mv "$selected_file.tmp" "$selected_file"
        jq -cn --arg id "$id" --arg sample_id "$sample_id" --arg sha "$(sha256_file "$page_file")" --slurpfile prior "$pages_file" '$prior[0]+[{registered_run_id:($id|tonumber),sample_id:$sample_id,response_sha256:$sha}]' >"$pages_file.tmp" && mv "$pages_file.tmp" "$pages_file"
      done < <(jq -c '.[]' "$COMPARISON_RUNS_FILE")
      total="$(jq 'length' "$selected_file")"
      jq -n --arg cutoff "$CUTOFF" --arg population "$name" --arg since "$since" --argjson total "$total" --slurpfile selected "$selected_file" --slurpfile pages "$pages_file" '{population:$population,event:"pull_request",branch:null,created_window:{after:$since,before:$cutoff},api_total_count:$total,population_capped:false,population_exhausted:true,selected_run_ids:[$selected[0][].id],runs:$selected[0],pages:$pages[0],detail_status:"pending",selection_source:"authenticated_comparison_registrations"}' >"$out"
      api_write_ledger collecting
      return 0
    fi
    while (( $(jq 'length' "$selected_file") < 100 )); do
      endpoint="/repos/${REPO}/actions/workflows/${WORKFLOW}/runs?event=${ev}"
      [[ -n "$br" ]] && endpoint+="&branch=${br}"
      endpoint+="&created=${since}..${CUTOFF}&per_page=100&page=${p}"
      page_file="$tmp/${name}-page-${p}.json"
      if ! api_get "$endpoint" "$page_file"; then break; fi
      jq -e '(.total_count|type)=="number" and (.workflow_runs|type)=="array"' "$page_file" >/dev/null || { API_STOP_REASON="population_response_invalid:${name}"; break; }
      [[ -n "$total" ]] || total="$(jq -r '.total_count' "$page_file")"
      returned="$(jq '.workflow_runs|length' "$page_file")"
      jq -cn --argjson p "$p" --argjson n "$returned" --slurpfile raw "$page_file" --slurpfile before "$pages_file" '$before[0] + [{page:$p,returned_count:$n,response:$raw[0]}]' >"$pages_file.tmp"
      mv "$pages_file.tmp" "$pages_file"
      jq -c --arg ev "$ev" --arg br "$br" --argjson lo "$(jq -nr --arg t "$since" '$t|fromdateiso8601')" --argjson hi "$cutoff_epoch" '[.workflow_runs[] | select(.event==$ev) | select(($br=="") or .head_branch==$br) | select((try (.created_at|fromdateiso8601) catch -1) >= $lo and (try (.created_at|fromdateiso8601) catch -1) <= $hi)]' "$page_file" >"$filtered_file"
      jq -cn --slurpfile before "$selected_file" --slurpfile page "$filtered_file" '$before[0] + $page[0]' >"$selected_file.tmp"
      mv "$selected_file.tmp" "$selected_file"
      jq -n --arg cutoff "$CUTOFF" --arg population "$name" --argjson page "$p" --argjson ids "$(jq -c '[.[]|.id]' "$selected_file")" --slurpfile previous "$stage/selection-ledger.json" '{schema_version:"sigra.ci-run-metrics/selection-ledger-v1",cutoff_utc:$cutoff,populations:($previous[0].populations | map(select(.population!=$population)) + [{population:$population,last_page:$page,selected_run_ids:$ids}])}' >"$stage/selection-ledger.json.tmp" && mv "$stage/selection-ledger.json.tmp" "$stage/selection-ledger.json"
      sync "$stage/selection-ledger.json" 2>/dev/null || sync 2>/dev/null || true
      if [[ "${CI_METRICS_TEST_MODE:-0}" == 1 && "${CI_METRICS_TEST_INTERRUPT_AFTER_POPULATION:-}" == "$name" ]]; then kill -INT "$$"; fi
      p=$((p+1))
      (( returned == 100 )) || break
      (( p <= 10 )) || { API_STOP_REASON="population_page_bound:${name}"; break; }
    done
    total="${total:-0}"
    jq -c '.[0:100]' "$selected_file" >"$selected_file.capped"
    mv "$selected_file.capped" "$selected_file"
    selected_count="$(jq 'length' "$selected_file")"
    capped=false; exhausted=false
    (( total > selected_count )) && capped=true
    [[ "$capped" == false ]] && exhausted=true
    jq -n --arg name "$name" --arg event "$ev" --arg branch "$br" --arg since "$since" --arg cutoff "$CUTOFF" --argjson total "$total" --slurpfile selected "$selected_file" --slurpfile pages "$pages_file" --argjson capped "$capped" --argjson exhausted "$exhausted" '{population:$name,event:$event,branch:(if $branch=="" then null else $branch end),created_window:{after:$since,before:$cutoff},api_total_count:$total,population_capped:$capped,population_exhausted:$exhausted,selected_run_ids:[$selected[0][].id],runs:$selected[0],pages:$pages[0],detail_status:"pending"}' >"$out"
    api_write_ledger collecting
  }

  collect_attempt_details() {
    local selected failed priority all_rows row id event run attempts attempt needed family_dir jobs_file jobs_status attempts_json paths_status paths_json pr_number docs_flag docs_rule skip_seen workload details_json details_file enrichments='[]' reserve=108 max_attempt measurement_target sample_id attempt_first
    local selected_file="$tmp/all-selected-runs.json" failed_file="$tmp/failed-selected-runs.json" priority_file="$tmp/prioritized-runs.json" enrichments_file="$tmp/family-enrichments.json"
    local pull_request_origin merge_commit_origin comparison_repo_file
    if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr && -n "$COMPARISON_RUNS_FILE" ]]; then
      comparison_repo_file="$stage/raw/comparison-repository.json"
      api_get "/repos/${REPO}" "$comparison_repo_file" || { API_STOP_REASON="comparison_repository_identity_unavailable"; return; }
    fi
    jq -cn --slurpfile pr "$stage/raw/populations/pull_request.json" --slurpfile push "$stage/raw/populations/push_main.json" --slurpfile night "$stage/raw/populations/schedule.json" '[($pr[0].runs[]|{population:"pull_request",run:.}),($push[0].runs[]|{population:"push_main",run:.}),($night[0].runs[]|{population:"schedule",run:.})]' >"$selected_file"
    jq -c '[.[] | select(.run.conclusion=="failure") | select(.population=="pull_request" or .population=="push_main" or .population=="schedule")] | sort_by(.run.created_at) | reverse | .[0:12]' "$selected_file" >"$failed_file"
    measurement_target="$(jq -r '[.[] | select(.population=="pull_request" and .run.conclusion=="success")] | sort_by(.run.created_at) | reverse | .[0].run.id // empty' "$selected_file")"
    if [[ -n "$COMPARISON_RUNS_FILE" ]]; then
      cp "$selected_file" "$priority_file"
    else jq -cn --arg target "$measurement_target" --slurpfile failed "$failed_file" --slurpfile selected "$selected_file" '
      ($selected[0] | sort_by(.run.created_at) | reverse) as $ordered |
      ([($ordered | map(select(.population=="pull_request" and (.run.id|tostring)==$target)) | .[0]),($ordered | map(select(.population=="push_main" and .run.conclusion=="success")) | .[0]),($ordered | map(select(.population=="schedule" and .run.conclusion=="success")) | .[0])] | map(select(.!=null)) | unique_by([.population,.run.id])) as $anchors |
      ($selected[0] | .[0:3]) as $recent |
      ($anchors + $recent + $failed[0]) | unique_by([.population,.run.id])
    ' "$selected_file" >"$priority_file"; fi
    printf '[]\n' >"$enrichments_file"
    producer_refs='{}'
    while IFS= read -r row; do
      [[ -n "$row" ]] || continue
      id="$(jq -r '.run.id' <<<"$row")"
      event="$(jq -r '.run.event' <<<"$row")"
      run="$(jq -c '.run' <<<"$row")"
      attempts="$(jq -r '.run.run_attempt // 1' <<<"$row")"
      sample_id="$(jq -r '.run.comparison_sample_id // .run.id' <<<"$row")"
      pull_request_origin='{}'; merge_commit_origin='{}'
      if [[ "$COMPARISON_ATTEMPT_SCOPED" == true ]]; then
        attempts="$(jq -r '.run.comparison_attempt // empty' <<<"$row")"
        [[ "$attempts" =~ ^[1-9][0-9]*$ ]] || { API_STOP_REASON="comparison_attempt_missing"; break; }
        attempt_first="$attempts"
      else attempt_first=1; fi
      if [[ ! "$id" =~ ^[0-9]+$ || ! "$attempts" =~ ^[1-9][0-9]*$ ]] || (( attempts > 100 )); then
        jq -cn --slurpfile prior "$enrichments_file" --argjson id "${id:-0}" '$prior[0] + [{run_id:$id,detail_status:"invalid_run_attempt_count",attempt_jobs:{},changed_paths_status:"unknown",workload:"unknown",diagnostics:["run_identity_or_attempt_count_invalid"]}]' >"$enrichments_file.tmp"
        mv "$enrichments_file.tmp" "$enrichments_file"
        continue
      fi
      family_dir="$stage/raw/families/$sample_id"
      mkdir -p "$family_dir"
      if [[ "$COMPARISON_ATTEMPT_SCOPED" == true ]]; then
        jq -c 'del(.comparison_sample_id,.comparison_attempt)' <<<"$run" >"$family_dir/run.json"
      else printf '%s\n' "$run" >"$family_dir/run.json"; fi
      needed=1
      # Reserve a bounded pass for the twelve newest failed families: at most
      # one artifact metadata read, and the initial request plus three possible
      # redirects for each artifact and failed-job log.
      if (( API_REQUESTS + needed + reserve > 600 )); then
        jq -cn --slurpfile prior "$enrichments_file" --argjson id "$id" '$prior[0] + [{run_id:$id,detail_status:"detail_unavailable_budget",attempt_jobs:{},changed_paths_status:"detail_unavailable_budget",workload:"unknown",diagnostics:["detail_unavailable_budget"]}]' >"$enrichments_file.tmp"
        mv "$enrichments_file.tmp" "$enrichments_file"
        jq --argjson id "$id" --arg reason detail_unavailable_budget '.unknown_inputs += [{reason:$reason,run_id:$id}]' "$API_LEDGER" >"$API_LEDGER.tmp" && mv "$API_LEDGER.tmp" "$API_LEDGER"
        continue
      fi
      jobs_status=complete
      attempts_json='{}'
      for ((attempt=attempt_first; attempt<=attempts; attempt++)); do
        jobs_file="$tmp/family-${id}-attempt-${attempt}-jobs.json"
        if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
          jobs_response="$tmp/family-${id}-attempt-${attempt}-jobs-page.json"
          jobs_collected='[]'; jobs_total=''; jobs_page=1
          while (( jobs_page <= 100 )); do
            if ! api_get "/repos/${REPO}/actions/runs/${id}/attempts/${attempt}/jobs?per_page=100&page=${jobs_page}" "$jobs_response"; then
              jobs_status="${API_STOP_REASON:-attempt_jobs_unavailable}"; break
            fi
            page_count="$(jq -r 'if (.jobs|type)=="array" and (.total_count|type)=="number" then (.jobs|length) else -1 end' "$jobs_response")"
            page_total="$(jq -r '.total_count // -1' "$jobs_response")"
            if (( page_count < 0 )) || [[ -n "$jobs_total" && "$jobs_total" != "$page_total" ]]; then
              jobs_status=attempt_jobs_pagination_inconsistent; break
            fi
            jobs_total="$page_total"
            jobs_collected="$(jq -cn --argjson prior "$jobs_collected" --slurpfile current "$jobs_response" '$prior + $current[0].jobs')"
            (( page_count < 100 )) && break
            jobs_page=$((jobs_page + 1))
          done
          if [[ "$jobs_status" == complete ]]; then
            [[ "$jobs_page" -le 100 && "$(jq 'length' <<<"$jobs_collected")" == "$jobs_total" ]] || jobs_status=attempt_jobs_pagination_incomplete
            if [[ "$jobs_status" == complete ]]; then jq -cn --argjson total "$jobs_total" --argjson jobs "$jobs_collected" '{total_count:$total,jobs:$jobs}' >"$jobs_file"; fi
          fi
        else
          if ! api_get "/repos/${REPO}/actions/runs/${id}/attempts/${attempt}/jobs?per_page=100" "$jobs_file"; then
            jobs_status="${API_STOP_REASON:-attempt_jobs_unavailable}"
          fi
        fi
        [[ "$jobs_status" == complete ]] || break
        cp "$jobs_file" "$family_dir/jobs-attempt-${attempt}.json"
        attempts_json="$(jq -cn --argjson prior "$attempts_json" --argjson attempt "$attempt" --arg path "raw/families/$sample_id/jobs-attempt-${attempt}.json" --arg hash "$(sha256_file "$family_dir/jobs-attempt-${attempt}.json")" --arg endpoint "/repos/${REPO}/actions/runs/${id}/attempts/${attempt}/jobs?per_page=100" '$prior + {($attempt|tostring):{path:$path,sha256:$hash,endpoint:$endpoint}}')"
      done
      paths_status=unavailable
      changed_path_pages='[]'
      paths_json='[]'
      local paths_file="$tmp/family-${id}-paths.json"
      printf '[]\n' >"$paths_file"
      pr_number="$(jq -r '.pull_requests[0].number // empty' <<<"$run")"
      if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr && "$event" == pull_request ]]; then
        if [[ ! "$pr_number" =~ ^[1-9][0-9]*$ ]]; then api_stop comparison_pull_request_number_invalid "" "$id"; break; fi
        local pr_api_file="$tmp/family-${id}-pull-request.json" merge_api_file="$tmp/family-${id}-merge-commit.json" merge_sha
        if ! api_get "/repos/${REPO}/pulls/${pr_number}" "$pr_api_file"; then break; fi
        merge_sha="$(jq -r '.merge_commit_sha // empty' "$pr_api_file")"
        if [[ ! "$merge_sha" =~ ^[0-9a-f]{40}$ ]] || ! api_get "/repos/${REPO}/git/commits/${merge_sha}" "$merge_api_file"; then
          api_stop comparison_merge_commit_unavailable "" "$id"; break
        fi
        if ! PYTHONPATH="$ROOT/scripts/ci" python3 - "$family_dir/run.json" "$pr_api_file" "$merge_api_file" <<'PY'
import json,pathlib,sys
from ci_metrics_security import validate_repaired_pr_origin
run,pr,commit=[json.loads(pathlib.Path(path).read_text()) for path in sys.argv[1:]]
errors=validate_repaired_pr_origin(run,pr,commit)
if errors: raise SystemExit(','.join(errors))
PY
        then api_stop comparison_pull_request_or_merge_origin_invalid "" "$id"; break; fi
        cp "$pr_api_file" "$family_dir/pull-request.json"
        cp "$merge_api_file" "$family_dir/merge-commit.json"
        pull_request_origin="$(jq -cn --arg path "raw/families/$sample_id/pull-request.json" --arg sha256 "$(sha256_file "$family_dir/pull-request.json")" --arg endpoint "/repos/${REPO}/pulls/${pr_number}" '{path:$path,sha256:$sha256,endpoint:$endpoint}')"
        merge_commit_origin="$(jq -cn --arg path "raw/families/$sample_id/merge-commit.json" --arg sha256 "$(sha256_file "$family_dir/merge-commit.json")" --arg endpoint "/repos/${REPO}/git/commits/${merge_sha}" '{path:$path,sha256:$sha256,endpoint:$endpoint}')"
      fi
      if [[ "$event" == pull_request && "$pr_number" =~ ^[1-9][0-9]*$ && "$jobs_status" == complete ]] && (( API_REQUESTS + 1 + reserve <= 600 )); then
        local changed_file="$tmp/family-${id}-changed-paths.json" page=1 total_paths=0
        while :; do
          if ! api_get "/repos/${REPO}/pulls/${pr_number}/files?per_page=100&page=${page}" "$changed_file"; then paths_status="${API_STOP_REASON:-changed_paths_unavailable}"; break; fi
          jq -e 'type=="array"' "$changed_file" >/dev/null || { paths_status=changed_paths_invalid; break; }
          total_paths=$((total_paths + $(jq 'length' "$changed_file")))
          jq -cn --slurpfile before "$paths_file" --slurpfile current "$changed_file" '$before[0] + $current[0]' >"$paths_file.tmp"
          mv "$paths_file.tmp" "$paths_file"
          cp "$changed_file" "$family_dir/changed-paths-page-${page}.json"
          changed_path_pages="$(jq -cn --argjson prior "$changed_path_pages" --argjson page "$page" --arg path "raw/families/$sample_id/changed-paths-page-${page}.json" --arg sha256 "$(sha256_file "$family_dir/changed-paths-page-${page}.json")" '$prior + [{page:$page,path:$path,sha256:$sha256}]')"
          (( $(jq 'length' "$changed_file") == 100 )) || { paths_status=complete; break; }
          # One authenticated non-document path proves this is not a docs-only
          # PR, even when GitHub caps a large PR's file listing at 3,000 files.
          # Keep the listing explicitly partial; full execution is checked from
          # the actual selected-attempt jobs, required checks and native reports.
          if [[ -n "$COMPARISON_RUNS_FILE" ]] && [[ "$(jq -r '.[].filename' "$paths_file" | bash "$ROOT/scripts/ci/docs-only-classify.sh" | sed -n 's/^docs_only=//p')" == false ]]; then
            paths_status=non_docs_witness
            break
          fi
          (( API_REQUESTS + 1 + reserve <= 600 )) || { paths_status=detail_unavailable_budget; break; }
          page=$((page+1))
        done
      elif [[ "$event" == pull_request ]]; then paths_status=changed_paths_unavailable_budget; fi
      docs_flag="$(jq -r 'if .changes.docs_only==true then "true" elif .changes.docs_only==false then "false" else "unknown" end' <<<"$run")"
      if [[ "$paths_status" == complete || "$paths_status" == non_docs_witness ]]; then
        docs_rule="$(jq -r '.[].filename' "$paths_file" | bash "$ROOT/scripts/ci/docs-only-classify.sh" 2>/dev/null | sed -n 's/^docs_only=//p')"
      else docs_rule=unknown; fi
      skip_seen=false
      if [[ "$jobs_status" == complete ]]; then
        skip_seen="$(jq -r '[.jobs[]? | select(.name|test("Library tests|Example unit smoke|Install smoke|Example HTTP smoke|Example Playwright")) | select(.conclusion=="skipped")] | length>0' "$family_dir/jobs-attempt-${attempts}.json" 2>/dev/null || echo false)"
      fi
      workload=unknown
      if [[ "$paths_status" == complete && "$docs_rule" == true && "$skip_seen" == true ]]; then workload=docs_only
      elif [[ ( "$paths_status" == complete || "$paths_status" == non_docs_witness ) && "$docs_rule" == false && "$jobs_status" == complete && "$skip_seen" == false ]]; then workload=full
      fi
      local diagnostic="[]" artifact_meta="$tmp/family-${id}-artifacts.json" artifact_record='{}' log_record='{}' job_id artifact_row artifact_id expected_digest artifact_zip="$family_dir/timing-artifact.zip" artifact_out="$family_dir/timing" artifact_status
      if jq -e --argjson id "$id" '[.[] | select(.run.id==$id)]|length>0' "$failed_file" >/dev/null; then
        if api_get "/repos/${REPO}/actions/runs/${id}/artifacts?per_page=100" "$artifact_meta"; then
            jq '{total_count,artifacts:[.artifacts[]? | {id,name,size_in_bytes,expired,digest,created_at,expires_at,workflow_run:{id:.workflow_run.id,head_sha:.workflow_run.head_sha,run_attempt:.workflow_run.run_attempt,repository_id:.workflow_run.repository_id}}]}' "$artifact_meta" >"$family_dir/artifacts-metadata.json"
          artifact_row="$(jq -c '[.artifacts[]? | select((.name|ascii_downcase|test("timing|playwright|test-results|report")))][0] // empty' "$artifact_meta")"
          if [[ -n "$artifact_row" ]]; then
            artifact_id="$(jq -r '.id' <<<"$artifact_row")"
            expected_digest="$(jq -r '.digest // empty' <<<"$artifact_row")"
            artifact_status="$(jq -c -n --argjson artifact "$artifact_row" --argjson run "$run" 'if $artifact.expired==true then {status:"expired_input",diagnostic:"expired_input"} elif (($artifact.id|type)!="number" or ($artifact.id|floor)!=$artifact.id) then {status:"unknown",diagnostic:"artifact_id_invalid"} elif (($artifact.digest//"")|test("^sha256:[0-9a-f]{64}$")|not) then {status:"unknown",diagnostic:"artifact_digest_unavailable"} elif (($artifact.workflow_run.id|tostring)!=($run.id|tostring) or $artifact.workflow_run.head_sha!=$run.head_sha) then {status:"unknown",diagnostic:"artifact_origin_mismatch"} else {status:"pending_download",artifact_id:$artifact.id,run_id:$run.id,source_sha:$run.head_sha,digest:$artifact.digest} end')"
            if [[ "$(jq -r '.status' <<<"$artifact_status")" == pending_download ]]; then
              if api_download_no_follow "https://api.github.com/repos/${REPO}/actions/artifacts/${artifact_id}/zip" "$artifact_zip" "artifact:${id}"; then
                local actual_digest
                actual_digest="sha256:$(sha256_file "$artifact_zip")"
                if [[ "$actual_digest" == "$expected_digest" ]] && extract_timing_archive "$artifact_zip" "$artifact_out" >"$tmp/extract-${id}.json" 2>"$tmp/extract-${id}.err"; then
                  artifact_record="$(jq -cn --arg archive_sha256 "${actual_digest#sha256:}" --slurpfile accepted "$tmp/extract-${id}.json" '$accepted[0] + {archive_sha256:$archive_sha256}')"
                else
                  artifact_record="$(jq -cn --arg reason "$(if [[ "$actual_digest" != "$expected_digest" ]]; then echo artifact_digest_mismatch; else cat "$tmp/extract-${id}.err"; fi)" '{status:"unknown",diagnostic:$reason}')"
                  rm -rf "$artifact_zip" "$artifact_out"
                fi
              else
                artifact_record="$(jq -cn --arg reason "${API_STOP_REASON:-artifact_download_unavailable}" '{status:"unknown",diagnostic:$reason}')"
              fi
            else
              artifact_record="$artifact_status"
            fi
          else
            artifact_record='{"status":"unknown","diagnostic":"artifact_unavailable"}'
          fi
        else artifact_record="$(jq -cn --arg reason "${API_STOP_REASON:-artifact_unavailable}" '{status:"unknown",diagnostic:$reason}')"; fi
        job_id="$(jq -r '[.jobs[]? | select(.conclusion=="failure" or .conclusion=="timed_out") | .id][0] // empty' "$family_dir/jobs-attempt-${attempts}.json" 2>/dev/null || true)"
        if [[ "$job_id" =~ ^[1-9][0-9]*$ ]] && api_download_no_follow "https://api.github.com/repos/${REPO}/actions/jobs/${job_id}/logs" "$tmp/job-${id}.log" "job-log:${id}"; then
          redact_log_file "$tmp/job-${id}.log" "$family_dir/failed-job.log"
          local log_hash; log_hash="$(sha256_file "$family_dir/failed-job.log")"
          log_record="$(jq -cn --arg hash "$log_hash" --arg path "raw/families/$sample_id/failed-job.log" '{status:"retained_redacted",path:$path,sha256:$hash}')"
        else
          log_record="$(jq -cn --arg reason "${API_STOP_REASON:-diagnostics_unknown}" '{status:"diagnostics_unknown",diagnostic:$reason}')"
          # A failed diagnostic excerpt is recorded as unknown, but it does not
          # invalidate independently complete event populations or cost inputs.
          # Hard rate-limit and budget stops still halt the whole collection.
          [[ "$API_STOP_REASON" == download_unavailable || "$API_STOP_REASON" == expired_input ]] && API_STOP_REASON=""
        fi
        jq -e . <<<"$artifact_record" >/dev/null || fail "artifact_diagnostic_invalid:${id}"
        jq -e . <<<"$log_record" >/dev/null || fail "log_diagnostic_invalid:${id}"
        diagnostic="$(jq -cn --argjson artifact "$artifact_record" --argjson log "$log_record" '[{kind:"artifact",result:$artifact},{kind:"failed_job_log",result:$log}]')"
      fi
      local registered_for_comparison=false
      if [[ -n "$COMPARISON_RUNS_FILE" ]] && jq -e --argjson id "$id" 'any(.[]; .run_id==$id)' "$COMPARISON_RUNS_FILE" >/dev/null; then registered_for_comparison=true; fi
      if [[ "$event" == pull_request && ("$id" == "$measurement_target" || "$registered_for_comparison" == true) && "$workload" == full && "$jobs_status" == complete ]]; then
        local check_file="$family_dir/check-runs.json" target_artifacts="$family_dir/artifacts" artifact_manifest="$family_dir/artifact-evidence.json" artifact_index=0 artifact_row_target target_artifact_id target_digest target_zip target_dir target_hash target_extract
        mkdir -p "$target_artifacts"
        if api_get "/repos/${REPO}/commits/$(jq -r '.head_sha' "$family_dir/run.json")/check-runs?per_page=100" "$tmp/family-${id}-check-runs.json"; then
          cp "$tmp/family-${id}-check-runs.json" "$check_file"
        else jq -n --arg reason "${API_STOP_REASON:-check_runs_unavailable}" '{status:"unknown",reason:$reason}' >"$check_file"; fi
        if api_get "/repos/${REPO}/actions/runs/${id}/artifacts?per_page=100" "$artifact_meta"; then
          jq '{total_count,artifacts:[.artifacts[]? | {id,name,size_in_bytes,expired,digest,created_at,expires_at,workflow_run:{id:.workflow_run.id,head_sha:.workflow_run.head_sha,run_attempt:.workflow_run.run_attempt,repository_id:.workflow_run.repository_id}}]}' "$artifact_meta" >"$family_dir/artifacts-metadata.json"
          printf '[]\n' >"$artifact_manifest"
          while IFS= read -r artifact_row_target; do
            [[ -n "$artifact_row_target" ]] || continue
            target_artifact_id="$(jq -r '.id' <<<"$artifact_row_target")"
            target_digest="$(jq -r '.digest // empty' <<<"$artifact_row_target")"
            target_zip="$target_artifacts/${target_artifact_id}.zip"
            target_dir="$target_artifacts/${target_artifact_id}"
            target_extract='{"status":"unknown","diagnostic":"artifact_not_downloaded"}'
            local artifact_attempt_ok=true
            if [[ "$COMPARISON_ATTEMPT_SCOPED" == true || "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]] && ! PYTHONPATH="$ROOT/scripts/ci" python3 - "$artifact_row_target" "$family_dir/run.json" "$family_dir/jobs-attempt-${attempts}.json" "$attempts" "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" <<'PY'
import json,pathlib,sys
from ci_metrics_security import legacy_playwright_artifact_matches_attempt
artifact=json.loads(sys.argv[1]); run=json.loads(pathlib.Path(sys.argv[2]).read_text()); attempt=int(sys.argv[4]); repaired=sys.argv[5]=='repaired_control_pr'
api_attempt=(artifact.get('workflow_run') or {}).get('run_attempt')
if repaired: valid=type(api_attempt) is int and api_attempt==attempt
elif api_attempt is not None: valid=api_attempt==attempt
else: valid=(artifact.get('name') or '').endswith(f"-{run['id']}-{attempt}") or legacy_playwright_artifact_matches_attempt(artifact,run,json.loads(pathlib.Path(sys.argv[3]).read_text()).get('jobs') or [],attempt)
raise SystemExit(0 if valid else 1)
PY
            then continue; fi
            if [[ "$artifact_attempt_ok" == true ]] && jq -e --argjson run "$run" '.expired!=true and (.id|type)=="number" and (.digest|test("^sha256:[0-9a-f]{64}$")) and (.workflow_run.id|tostring)==($run.id|tostring) and .workflow_run.head_sha==$run.head_sha' <<<"$artifact_row_target" >/dev/null \
              && api_download_no_follow "https://api.github.com/repos/${REPO}/actions/artifacts/${target_artifact_id}/zip" "$target_zip" "artifact:${id}:${target_artifact_id}"; then
              target_hash="sha256:$(sha256_file "$target_zip")"
              if [[ "$target_hash" == "$target_digest" ]] && extract_timing_archive "$target_zip" "$target_dir" >"$tmp/target-extract-${target_artifact_id}.json" 2>"$tmp/target-extract-${target_artifact_id}.err"; then
                target_extract="$(jq -cn --arg archive_sha256 "${target_hash#sha256:}" --arg path "raw/families/${sample_id}/artifacts/${target_artifact_id}" --slurpfile extraction "$tmp/target-extract-${target_artifact_id}.json" '$extraction[0] + {status:"accepted",archive_sha256:$archive_sha256,path:$path}')"
              else target_extract="$(jq -cn --arg reason "$(if [[ "$target_hash" != "$target_digest" ]]; then echo artifact_digest_mismatch; else cat "$tmp/target-extract-${target_artifact_id}.err"; fi)" '{status:"unknown",diagnostic:$reason}')"; rm -rf "$target_zip" "$target_dir"; fi
            else target_extract="$(jq -cn --arg reason "${API_STOP_REASON:-artifact_identity_or_digest_invalid}" '{status:"unknown",diagnostic:$reason}')"; fi
            jq -cn --slurpfile prior "$artifact_manifest" --argjson artifact "$artifact_row_target" --argjson result "$target_extract" '$prior[0] + [{artifact:$artifact,result:$result}]' >"$artifact_manifest.tmp" && mv "$artifact_manifest.tmp" "$artifact_manifest"
            artifact_index=$((artifact_index+1))
            [[ -z "$API_STOP_REASON" ]] || break
    done < <(jq -c --argjson attempt "$attempts" --argjson attempt_scoped "$COMPARISON_ATTEMPT_SCOPED" '[.artifacts[]? | select((.name|ascii_downcase|test("timing|playwright|measurement-metadata|browser-execution")) and ((.name|ascii_downcase|startswith("sigra-ci-"))|not))] | sort_by(.name,.id) | .[]' "$artifact_meta")
        else jq -n --arg reason "${API_STOP_REASON:-artifact_metadata_unavailable}" '{status:"unknown",reason:$reason}' >"$artifact_manifest"; fi
        while IFS= read -r producer_meta; do
          [[ -s "$producer_meta" ]] || continue
          producer_sha="$(jq -r '.source_sha // empty' "$producer_meta")"
          [[ "$producer_sha" =~ ^[0-9a-f]{40}$ ]] || continue
          if jq -e --arg sha "$producer_sha" 'has($sha)' <<<"$producer_refs" >/dev/null; then continue; fi
          producer_dir="$family_dir/producer-source/$producer_sha"
          mkdir -p "$producer_dir"
          if api_get "/repos/${REPO}/commits/${producer_sha}" "$tmp/producer-commit-${producer_sha}.json" \
            && api_get "/repos/${REPO}/git/trees/$(jq -r '.commit.tree.sha' "$tmp/producer-commit-${producer_sha}.json")?recursive=1" "$tmp/producer-tree-${producer_sha}.json" \
            && api_get "/repos/${REPO}/contents/.github/workflows/ci.yml?ref=${producer_sha}" "$tmp/producer-workflow-${producer_sha}.json"; then
            cp "$tmp/producer-commit-${producer_sha}.json" "$producer_dir/commit.json"
            cp "$tmp/producer-tree-${producer_sha}.json" "$producer_dir/tree.json"
            cp "$tmp/producer-workflow-${producer_sha}.json" "$producer_dir/workflow-content.json"
            workflow_content="$producer_dir/ci.yml"
            if jq -r '.content' "$producer_dir/workflow-content.json" | tr -d '\n' | base64 -d >"$workflow_content" 2>/dev/null; then
              producer_tree_sha="$(jq -r '.commit.tree.sha // empty' "$producer_dir/commit.json")"
              producer_parent_valid="$(jq -c --arg sha "$producer_sha" --argjson run "$run" '.sha==$sha and ([.parents[].sha]|sort)==([$run.pull_requests[0].head.sha,$run.pull_requests[0].base.sha]|sort) and ($run.pull_requests|length)==1' "$producer_dir/commit.json")"
              if [[ "$producer_parent_valid" == true ]] && jq -e --arg tree "$producer_tree_sha" --arg workflow "$(git hash-object "$workflow_content")" '.sha==$tree and any(.tree[]; .path==".github/workflows/ci.yml" and .type=="blob" and .sha==$workflow)' "$producer_dir/tree.json" >/dev/null; then
                producer_refs="$(jq -cn --arg sha "$producer_sha" --arg c "raw/families/${sample_id}/producer-source/${producer_sha}/commit.json" --arg ch "$(sha256_file "$producer_dir/commit.json")" --arg t "raw/families/${sample_id}/producer-source/${producer_sha}/tree.json" --arg th "$(sha256_file "$producer_dir/tree.json")" --arg w "raw/families/${sample_id}/producer-source/${producer_sha}/ci.yml" --arg wh "$(sha256_file "$workflow_content")" --arg raw "raw/families/${sample_id}/producer-source/${producer_sha}/workflow-content.json" --arg rh "$(sha256_file "$producer_dir/workflow-content.json")" --argjson prior "$producer_refs" '$prior + {($sha):{commit_path:$c,commit_sha256:$ch,tree_path:$t,tree_sha256:$th,workflow_path:$w,workflow_sha256:$wh,workflow_api_path:$raw,workflow_api_sha256:$rh}}')"
              else api_stop producer_source_origin_unverified "" "$producer_sha"; fi
            else api_stop producer_workflow_content_unavailable "" "$producer_sha"; fi
          fi
          [[ -z "$API_STOP_REASON" ]] || break
        done < <(find "$target_artifacts" -mindepth 2 -maxdepth 2 -name ci-measurement-metadata.json -type f 2>/dev/null | sort)
      fi
      details_file="$tmp/family-${id}-detail.json"
      jq -cn --argjson id "$id" --arg sample_id "$sample_id" --arg status "$jobs_status" --arg paths_status "$paths_status" --arg workload "$workload" --arg docs_only "$docs_flag" --argjson attempts "$attempts_json" --slurpfile paths "$paths_file" --argjson skip_seen "$skip_seen" --argjson diagnostic "$diagnostic" '{run_id:$id,sample_id:$sample_id,detail_status:$status,attempt_count:($attempts|length),attempt_jobs:$attempts,changed_path_pages:[],changed_paths_status:$paths_status,changed_paths:$paths[0],changes_docs_only:(if $docs_only=="unknown" then null else ($docs_only=="true") end),docs_path_classification:(if $paths_status=="complete" then "captured" else "unknown" end),observed_expected_skip:$skip_seen,workload:$workload,artifact_diagnostics:$diagnostic,diagnostics:(if $status=="complete" then [] else [$status] end)}' >"$details_file" || fail "family_detail_json_invalid:${id}"
      jq -n --slurpfile detail "$details_file" --arg sample_id "$sample_id" --argjson attempt "$attempts" --arg run_hash "$(sha256_file "$family_dir/run.json")" --arg artifact_path "$(if [[ -s "$family_dir/artifact-evidence.json" ]]; then echo "raw/families/$sample_id/artifact-evidence.json"; fi)" --arg artifact_hash "$(if [[ -s "$family_dir/artifact-evidence.json" ]]; then sha256_file "$family_dir/artifact-evidence.json"; fi)" --arg check_hash "$(if [[ -s "$family_dir/check-runs.json" ]]; then sha256_file "$family_dir/check-runs.json"; fi)" --arg metadata_hash "$(if [[ -s "$family_dir/artifacts-metadata.json" ]]; then sha256_file "$family_dir/artifacts-metadata.json"; fi)" --argjson attempts "$attempts_json" --argjson producer_refs "$producer_refs" --argjson changed_path_pages "$changed_path_pages" --argjson pull_request "$pull_request_origin" --argjson merge_commit "$merge_commit_origin" '{schema_version:"sigra.ci-run-metrics/family-detail-v1",run_id:$detail[0].run_id,sample_id:$sample_id,run_attempt:$attempt,source_run_sha256:$run_hash,attempt_jobs:$attempts,changed_path_pages:$changed_path_pages,detail_status:$detail[0].detail_status,changed_paths_status:$detail[0].changed_paths_status,changes_docs_only:$detail[0].changes_docs_only,workload:$detail[0].workload,observed_expected_skip:$detail[0].observed_expected_skip,artifact_metadata_sha256:(if $metadata_hash=="" then null else $metadata_hash end),artifact_evidence:(if $artifact_path=="" then null else {path:$artifact_path,sha256:$artifact_hash} end),pull_request:(if $pull_request.path==null then null else $pull_request end),merge_commit:(if $merge_commit.path==null then null else $merge_commit end),check_runs_sha256:(if $check_hash=="" then null else $check_hash end),producer_commits:$producer_refs,artifact_diagnostics:$detail[0].artifact_diagnostics}' >"$family_dir/manifest.json"
      jq -cn --slurpfile prior "$enrichments_file" --slurpfile detail "$details_file" '$prior[0] + [$detail[0]]' >"$enrichments_file.tmp"
      mv "$enrichments_file.tmp" "$enrichments_file"
      api_write_ledger collecting
      [[ -z "$API_STOP_REASON" ]] || break
    done <<<"$(jq -c '.[]' "$priority_file")"
    for population_name in pull_request push_main schedule; do
      local population_file="$stage/raw/populations/${population_name}.json"
      jq --slurpfile details "$enrichments_file" '.runs |= map(. as $r | . + ([$details[0][] | select((.sample_id != null and .sample_id==($r.comparison_sample_id // ($r.id|tostring))) or (.sample_id == null and .run_id==$r.id))][0] // {detail_status:"detail_unavailable_budget",workload:"unknown",attempt_jobs:{}}))' "$population_file" >"$population_file.tmp" && mv "$population_file.tmp" "$population_file"
    done
  }

  if [[ -z "$API_STOP_REASON" ]]; then collect_one_population pull_request pull_request ""; fi
  if [[ -z "$API_STOP_REASON" ]]; then collect_one_population push_main push main; fi
  if [[ -z "$API_STOP_REASON" ]]; then collect_one_population schedule schedule ""; fi
  if [[ -z "$API_STOP_REASON" ]]; then collect_one_population manual workflow_dispatch ""; fi
  if [[ -z "$API_STOP_REASON" ]]; then collect_one_population release_push push ""; fi
  for population_name in pull_request push_main schedule manual release_push; do
    [[ -s "$stage/raw/populations/${population_name}.json" ]] || jq -n --arg name "$population_name" '{population:$name,event:null,api_total_count:null,population_capped:null,population_exhausted:null,selected_run_ids:[],runs:[],pages:[],detail_status:"unavailable"}' >"$stage/raw/populations/${population_name}.json"
  done
  if [[ -z "$API_STOP_REASON" ]]; then collect_attempt_details; fi
  # Keep primary cohorts distinct; move non-main rows from the broad push scan
  # into release diagnostics, never into the main-push denominator.
  release_json="$(jq -c '.runs | map(select((.head_branch // "") | startswith("release/") or startswith("release-") or startswith("releases/")))' "$stage/raw/populations/release_push.json")"
  jq --argjson rows "$release_json" '.runs=$rows | .selected_run_ids=[$rows[].id] | .detail_status="pending"' "$stage/raw/populations/release_push.json" >"$tmp/release.json" && mv "$tmp/release.json" "$stage/raw/populations/release_push.json"
  manual_json="$(jq -c '.runs' "$stage/raw/populations/manual.json")"

  request_count="$API_REQUESTS"
  manifest_status=complete
  [[ -n "$API_STOP_REASON" ]] && manifest_status=incomplete
  workflow_blob="$(git hash-object "$stage/source/ci.yml" 2>/dev/null || echo unavailable)"
  workflow_sha="$(sha256_file "$stage/source/ci.yml")"
  tree_sha="${COMPARISON_SOURCE_REF:-$(git rev-parse HEAD 2>/dev/null || echo unavailable)}"
  source_hashes="$(jq -cn --arg workflow "$(sha256_file "$stage/source/ci.yml")" --arg collector "$(sha256_file "$stage/source/ci-run-metrics.sh")" --arg security "$(sha256_file "$stage/source/ci_metrics_security.py")" --arg exunit_contract "$(sha256_file "$stage/source/exunit_timing_contract.py")" --arg playwright "$(sha256_file "$stage/source/ci-playwright-report.mjs")" --arg playwright_config "$(sha256_file "$stage/source/playwright.config.ts")" --arg playwright_lock "$(sha256_file "$stage/source/playwright-package-lock.json")" --arg exunit "$(sha256_file "$stage/source/ci_timing_formatter.ex")" --arg helper "$(sha256_file "$stage/source/test_helper.exs")" --arg report_test "$(sha256_file "$stage/source/ci-playwright-report.test.mjs")" --arg mix "$(sha256_file "$stage/source/mix.exs")" --arg dep_off "$(sha256_file "$stage/source/sigra-dep-off.sh")" '{"ci.yml":$workflow,"ci-run-metrics.sh":$collector,"ci_metrics_security.py":$security,"exunit_timing_contract.py":$exunit_contract,"ci-playwright-report.mjs":$playwright,"playwright.config.ts":$playwright_config,"playwright-package-lock.json":$playwright_lock,"ci_timing_formatter.ex":$exunit,"test_helper.exs":$helper,"ci-playwright-report.test.mjs":$report_test,"mix.exs":$mix,"sigra-dep-off.sh":$dep_off}')"
  required_info="$(derive_required_contexts "$stage/raw/effective-rules.json" "$stage/raw/branch-protection.json")"
  required_contexts="$(jq -c '.actual' <<<"$required_info")"
  if [[ -n "$COMPARISON_RUNS_FILE" && "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    contract_apps="$(jq -c '.required_check_apps' "$CONTRACT_FILE")"
    [[ "$(jq -c '.app_ids' <<<"$required_info")" == "$contract_apps" ]] || API_STOP_REASON="repaired_required_check_apps_differ_from_frozen_rules"
  fi
  required_provenance="$(jq -c '.provenance' <<<"$required_info")"
  active_rules="$(jq -c '[.[]? | select(.enforcement=="active") | {id,name,target,enforcement}] | sort_by(.id)' "$stage/raw/rulesets.json" 2>/dev/null || echo '[]')"
  api_write_ledger "$manifest_status"
  request_hash="$(sha256_file "$API_LEDGER")"
  selection_hash="$(sha256_file "$stage/selection-ledger.json")"
  pr_hash="$(sha256_file "$stage/raw/populations/pull_request.json")"
  push_hash="$(sha256_file "$stage/raw/populations/push_main.json")"
  night_hash="$(sha256_file "$stage/raw/populations/schedule.json")"
  manual_hash="$(sha256_file "$stage/raw/populations/manual.json")"
  release_hash="$(sha256_file "$stage/raw/populations/release_push.json")"
  jq -n --arg repo "$REPO" --arg workflow "$WORKFLOW" --arg cutoff "$CUTOFF" --arg captured "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg since "$since" --arg status "$manifest_status" --arg stop "$API_STOP_REASON" --arg sha "$tree_sha" --arg workflow_sha "$workflow_sha" --arg workflow_blob "$workflow_blob" --arg source_hashes "$source_hashes" --argjson required_contexts "$required_contexts" --argjson required_expected "$(jq -c '.expected' <<<"$required_info")" --argjson required_changed "$(jq -c '.changed' <<<"$required_info")" --argjson required_diagnostics "$(jq -c '.diagnostics' <<<"$required_info")" --arg required_source "$(jq -r '.source' <<<"$required_info")" --argjson required_provenance "$required_provenance" --argjson active_rules "$active_rules" --arg request_hash "$request_hash" --arg selection_hash "$selection_hash" --arg pr_hash "$pr_hash" --arg push_hash "$push_hash" --arg night_hash "$night_hash" --arg manual_hash "$manual_hash" --arg release_hash "$release_hash" --arg rate_hash "$(sha256_file "$stage/raw/rate-limit.json")" --arg rules_hash "$(sha256_file "$stage/raw/effective-rules.json")" --arg protection_hash "$(sha256_file "$stage/raw/branch-protection.json")" --arg rulesets_hash "$(sha256_file "$stage/raw/rulesets.json")" --argjson requests "$request_count" --slurpfile pr "$stage/raw/populations/pull_request.json" --slurpfile push "$stage/raw/populations/push_main.json" --slurpfile night "$stage/raw/populations/schedule.json" --slurpfile manual "$stage/raw/populations/manual.json" --slurpfile release "$stage/raw/populations/release_push.json" '{schema_version:"sigra.ci-run-metrics/snapshot-v1",repository:$repo,workflow:$workflow,cutoff_utc:$cutoff,captured_at_utc:$captured,window_start_utc:$since,status:$status,stop_reason:(if $stop=="" then null else $stop end),request_count:$requests,source_sha:$sha,workflow_sha256:$workflow_sha,workflow_blob_sha:$workflow_blob,required_contexts:$required_contexts,expected_required_contexts:$required_expected,required_context_source:$required_source,required_rules_changed:$required_changed,required_rules_diagnostics:$required_diagnostics,required_rule_provenance:$required_provenance,active_rulesets:$active_rules,source_file_sha256:($source_hashes|fromjson),source_sha256:{request_ledger:$request_hash,selection_ledger:$selection_hash,pull_request:$pr_hash,push_main:$push_hash,schedule:$night_hash,manual:$manual_hash,release_push:$release_hash,rate_limit:$rate_hash,effective_rules:$rules_hash,branch_protection:$protection_hash,rulesets:$rulesets_hash},populations:{pull_request:$pr[0],push_main:$push[0],schedule:$night[0],manual:{population:"manual",event:"workflow_dispatch",api_total_count:$manual[0].api_total_count,records:$manual[0].runs},release_push:{population:"release_push",event:"push",records:$release[0].runs}}}' >"$stage/manifest.json"
  if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    jq --argjson apps "$(jq -c '.app_ids' <<<"$required_info")" '.required_check_apps=$apps' "$stage/manifest.json" >"$stage/manifest.json.tmp" && mv "$stage/manifest.json.tmp" "$stage/manifest.json"
  fi
  sync 2>/dev/null || true
  rm -rf "$tmp"
  API_TEMP_DIR=""
  mv "$stage" "$SOURCE_BUNDLE"
  API_COMPLETED=true
  trap - INT TERM HUP
  rm -rf "$lock"
  printf '%s\n' "snapshot manifest: $SOURCE_BUNDLE/manifest.json" "status: $manifest_status; requests: $request_count"
  [[ "$manifest_status" == complete ]]
}

watch_comparison_runs() {
  [[ -s "$CONTRACT_FILE" && -s "$REGISTRATIONS_FILE" && -s "$REQUEST_BUDGET_LEDGER" && -n "$WATCH_OUTPUT_DIR" ]] || fail "watcher_inputs_missing"
  mkdir -p "$WATCH_OUTPUT_DIR"
  local owner run_id registration run_file poll_index interval status_json result_file previous_file previous_status rate_preflight_done=false
  owner="repaired-control:${COMPARISON_ROLE}:$(sha256_file "$CONTRACT_FILE")"
  interval=60
  [[ "${CI_METRICS_TEST_MODE:-0}" != 1 ]] || interval="${CI_METRICS_TEST_WATCH_INTERVAL_SECONDS:-60}"
  [[ "$interval" =~ ^[0-9]+$ ]] || fail "watcher_interval_invalid"
  while IFS= read -r registration; do
    [[ -n "$registration" ]] || continue
    run_id="$(jq -r '.run_id' <<<"$registration")"
    [[ "$run_id" =~ ^[1-9][0-9]*$ ]] || fail "watcher_run_id_invalid"
    watcher_acquire_process_lock "$run_id"
    PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" "$run_id" "$owner" <<'PY' || fail "comparison_watcher_claim_failed"
import json,pathlib,sys
from ci_metrics_security import comparison_watcher_start
c=json.loads(pathlib.Path(sys.argv[1]).read_text())
comparison_watcher_start(c,pathlib.Path(sys.argv[2]),sys.argv[3],owner=sys.argv[4])
PY
    poll_index=0
    previous_file="$(find "$WATCH_OUTPUT_DIR" -maxdepth 1 -type f -name "run-${run_id}-poll-*.json" -print | sort -t- -k4,4n | tail -1)"
    if [[ -n "$previous_file" ]]; then
      poll_index="${previous_file##*-poll-}"
      poll_index="${poll_index%.json}"
      [[ "$poll_index" =~ ^[1-9][0-9]*$ ]] || fail "comparison_watcher_resume_receipt_invalid:${run_id}"
      PYTHONPATH="$ROOT/scripts/ci" python3 - "$previous_file" "$registration" <<'PY' || fail "comparison_watcher_resume_origin_invalid:${run_id}"
import json,pathlib,sys
from ci_metrics_security import validate_registered_run_observation
run=json.loads(pathlib.Path(sys.argv[1]).read_text()); registration=json.loads(sys.argv[2])
errors=validate_registered_run_observation(registration,run)
if errors or run.get('status') not in ('queued','in_progress','completed'):
    raise SystemExit(','.join(errors) or 'comparison_watcher_status_invalid')
PY
      previous_status="$(jq -r '.status' "$previous_file")"
      if [[ "$previous_status" == completed ]]; then watcher_release_locks; continue; fi
    fi
    if [[ "$rate_preflight_done" != true ]]; then
      api_get rate_limit "$WATCH_OUTPUT_DIR/rate-limit.json" || fail "comparison_watcher_rate_preflight_failed:${API_STOP_REASON}"
      rate_preflight_done=true
    fi
    while :; do
      poll_index=$((poll_index+1))
      result_file="$WATCH_OUTPUT_DIR/run-${run_id}-poll-${poll_index}.json"
      api_get "/repos/${REPO}/actions/runs/${run_id}" "$result_file" || fail "comparison_watcher_read_failed:${run_id}:${API_STOP_REASON}"
      PYTHONPATH="$ROOT/scripts/ci" python3 - "$result_file" "$registration" <<'PY' || fail "comparison_watcher_origin_changed:${run_id}"
import json,pathlib,sys
from ci_metrics_security import validate_registered_run_observation
run=json.loads(pathlib.Path(sys.argv[1]).read_text()); registration=json.loads(sys.argv[2])
errors=validate_registered_run_observation(registration,run)
if errors: raise SystemExit(','.join(errors))
if run.get('status') not in ('queued','in_progress','completed'):
    raise SystemExit('comparison_watcher_status_invalid')
PY
      status_json="$(jq -r '.status' "$result_file")"
      [[ "$status_json" != completed ]] || break
      (( poll_index < 60 )) || fail "comparison_watcher_poll_limit_exhausted:${run_id}"
      if [[ "${CI_METRICS_TEST_MODE:-0}" != 1 || "${CI_METRICS_TEST_NO_SLEEP:-0}" != 1 ]]; then sleep "$interval"; fi
    done
    watcher_release_locks
  done < <(jq -c '.[]' "$COMPARISON_RUNS_FILE")
  jq -n --arg owner "$owner" --argjson interval "$interval" --argjson polls "$(find "$WATCH_OUTPUT_DIR" -maxdepth 1 -name 'run-*-poll-*.json' | wc -l | tr -d ' ')" --argjson requests "$API_REQUESTS" '{status:"complete",owner:$owner,interval_seconds:$interval,poll_count:$polls,request_count:$requests}'
}

collect_comparison() {
  [[ -s "$CONTRACT_FILE" && -s "$REGISTRATIONS_FILE" && -n "$REQUEST_BUDGET_LEDGER" && -n "$SOURCE_BUNDLE" ]] || fail "--collect-comparison requires --contract, --registrations, --request-budget-ledger and --source-bundle"
  [[ "$COMPARISON_ROLE" == before || "$COMPARISON_ROLE" == after ]] || fail "--comparison-role must be before or after"
  local tmp contract_window_end contract_hash registration_hash budget_hash watcher_requests watcher_poll_count repository_identity
  COMPARISON_ATTEMPT_SCOPED="$(jq -r '.sample_identity == "run_id+run_attempt"' "$CONTRACT_FILE")"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-comparison-collect.XXXXXX")"
  COMPARISON_RUNS_FILE="$tmp/registered-runs.json"
  if ! PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REGISTRATIONS_FILE" "$COMPARISON_ROLE" "$COMPARISON_RUNS_FILE" "$RESERVATION_ID" <<'PY'
import json,pathlib,sys
from ci_metrics_security import comparison_registered_runs
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
ledger=json.loads(pathlib.Path(sys.argv[2]).read_text())
rows=comparison_registered_runs(contract,ledger,sys.argv[3])
if sys.argv[5]:
    rows=[row for row in rows if row['reservation_id']==sys.argv[5]]
    if len(rows)!=1: raise SystemExit('exact_registered_reservation_missing')
pathlib.Path(sys.argv[4]).write_text(json.dumps(rows,sort_keys=True,separators=(',',':')))
PY
  then rm -rf "$tmp"; fail "comparison_role_has_no_registered_runs_or_registration_invalid"; fi
  python3 - "$CONTRACT_FILE" "$ROOT" <<'PY' || { rm -rf "$tmp"; fail "native_coverage_map_missing_or_invalid_collection_blocked"; }
import hashlib,json,pathlib,sys
contract=json.loads(pathlib.Path(sys.argv[1]).read_text()); root=pathlib.Path(sys.argv[2]).resolve()
spec=contract.get('native_coverage_comparison') or {}
relative=spec.get('mapping_path'); expected=spec.get('mapping_sha256')
if not isinstance(relative,str) or pathlib.PurePosixPath(relative).is_absolute() or '..' in pathlib.PurePosixPath(relative).parts: raise SystemExit(1)
path=(root/relative).resolve()
if root not in path.parents or not path.is_file() or not isinstance(expected,str) or hashlib.sha256(path.read_bytes()).hexdigest()!=expected: raise SystemExit(1)
mapping=json.loads(path.read_text())
if mapping.get('schema_version')!='sigra.browser-coverage-map/v1' or not isinstance(mapping.get('rows'),list) or not mapping['rows']: raise SystemExit(1)
owners={'admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase'}
rows=mapping['rows']
if len(rows)!=108 or {row.get('owner') for row in rows}!=owners or any(row.get('kind') not in ('product','setup') or not all(isinstance(row.get(k),list) and len(row[k])==5 for k in ('before','after')) for row in rows): raise SystemExit(1)
if {owner:sum(row.get('owner')==owner for row in rows) for owner in owners}!={'admin_behavior':43,'admin_checkpoints':3,'design_gallery':42,'non_admin_smoke':16,'demo_showcase':4}: raise SystemExit(1)
for side in ('before','after'):
    ids=[json.dumps(row[side],separators=(',',':')) for row in rows]
    if len(ids)!=len(set(ids)): raise SystemExit(1)
receipt_relative=spec.get('parity_receipt_path'); receipt_expected=spec.get('parity_receipt_sha256')
if not isinstance(receipt_relative,str) or pathlib.PurePosixPath(receipt_relative).is_absolute() or '..' in pathlib.PurePosixPath(receipt_relative).parts: raise SystemExit(1)
receipt_path=(root/receipt_relative).resolve()
if root not in receipt_path.parents or not receipt_path.is_file() or not isinstance(receipt_expected,str) or hashlib.sha256(receipt_path.read_bytes()).hexdigest()!=receipt_expected: raise SystemExit(1)
receipt=json.loads(receipt_path.read_text())
if receipt.get('schema_version')!='sigra.browser-parity-receipt/v1' or receipt.get('status')!='passed' or receipt.get('owner_integration_status')!='profiled' or receipt.get('mapping_sha256')!=expected: raise SystemExit(1)
if receipt.get('event')!='pull_request': raise SystemExit(1)
sys.path.insert(0,str(root/'scripts/ci'))
from ci_metrics_security import validate_profiled_receipt_sources
validate_profiled_receipt_sources(contract,receipt,root)
comparisons=receipt.get('owners')
owners={'admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase'}
if not isinstance(comparisons,list) or len(comparisons)!=5 or {row.get('owner') for row in comparisons}!=owners or any(row.get('status')!='passed' for row in comparisons): raise SystemExit(1)
PY
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" <<'PY' || { rm -rf "$tmp"; fail "request_budget_ledger_contract_or_readback_invalid"; }
import json,pathlib,sys
from ci_metrics_security import initialize_comparison_request_budget
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
initialize_comparison_request_budget(contract,pathlib.Path(sys.argv[2]))
PY
  if [[ "$COMPARISON_ATTEMPT_SCOPED" == true || "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$COMPARISON_ROLE" "$ROOT" <<'PY' || { rm -rf "$tmp"; fail "comparison_native_inventory_preflight_failed"; }
import json,pathlib,sys
from ci_metrics_security import comparison_native_inventories
comparison_native_inventories(json.loads(pathlib.Path(sys.argv[1]).read_text()),sys.argv[2],pathlib.Path(sys.argv[3]))
PY
    COMPARISON_SOURCE_REF="$(jq -r --arg role "$COMPARISON_ROLE" 'if $role=="before" then .baseline_application_sha else .candidate_identity.application_sha end' "$CONTRACT_FILE")"
  fi
  contract_window_end="$(jq -r '.window.end_utc // empty' "$CONTRACT_FILE")"
  [[ "$contract_window_end" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { rm -rf "$tmp"; fail "comparison_window_end_invalid"; }
  CUTOFF="$contract_window_end"
  API_BUDGET_OWNER="comparison:${COMPARISON_ROLE}:preflight"
  if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    API_CONTRACT_SHA256="$(PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" <<'PY'
import json,pathlib,sys
from ci_metrics_security import comparison_contract_sha256
print(comparison_contract_sha256(json.loads(pathlib.Path(sys.argv[1]).read_text())))
PY
)"
    WATCH_OUTPUT_DIR="${REQUEST_BUDGET_LEDGER}.watcher-${COMPARISON_ROLE}-${API_CONTRACT_SHA256}"
    mkdir -p "$WATCH_OUTPUT_DIR"
    API_LEDGER="${WATCH_OUTPUT_DIR}.request-ledger.json"
    API_TEMP_DIR="$WATCH_OUTPUT_DIR"
    API_STARTED="$(jq -r '.started_at_epoch // empty' "$REQUEST_BUDGET_LEDGER")"; [[ "$API_STARTED" =~ ^[0-9]+$ ]] || API_STARTED="$(date +%s)"
    API_REQUESTS=0; API_STOP_REASON=""; API_RESET_AT=""; API_CORE_REMAINING=""; API_UNKNOWN='[]'; API_REQUEST_LOG='[]'; API_LAST_RATE_REQUEST=0; API_RATE_CHECK_IN_FLIGHT=false
    if [[ -s "$API_LEDGER" ]]; then
      jq -e --arg contract "$API_CONTRACT_SHA256" '.contract_sha256==$contract and (.requests|type)=="array"' "$API_LEDGER" >/dev/null || { rm -rf "$tmp"; fail "comparison_watcher_ledger_identity_invalid"; }
      API_REQUESTS="$(jq -r '.request_count' "$API_LEDGER")"
      API_REQUEST_LOG="$(jq -c '.requests' "$API_LEDGER")"
      API_CORE_REMAINING="$(jq -r '.core_remaining // empty' "$API_LEDGER")"
      API_RESET_AT="$(jq -r '.reset_or_retry_at // empty' "$API_LEDGER")"
    fi
    API_BUDGET_OWNER="comparison:${COMPARISON_ROLE}:watcher"
    trap 'watcher_release_locks' EXIT INT TERM HUP
    watch_comparison_runs >"$tmp/watcher-result.json"
    watcher_requests="$API_REQUESTS"
    watcher_poll_count="$(jq -r '.poll_count' "$tmp/watcher-result.json")"
    watcher_release_locks
    trap - EXIT INT TERM HUP
    API_TEMP_DIR=""; API_LEDGER=""; API_BUDGET_OWNER=""; API_CONTRACT_SHA256=""
  else
    watcher_requests=0; watcher_poll_count=0
  fi
  collect_window
  if [[ "$watcher_requests" -gt 0 ]]; then
    mkdir -p "$SOURCE_BUNDLE/raw/watcher"
    cp -R "$WATCH_OUTPUT_DIR"/. "$SOURCE_BUNDLE/raw/watcher/"
    cp "${WATCH_OUTPUT_DIR}.request-ledger.json" "$SOURCE_BUNDLE/raw/watcher-request-ledger.json"
    cp "$WATCH_OUTPUT_DIR/rate-limit.json" "$SOURCE_BUNDLE/raw/watcher-rate-limit.json"
    jq --slurpfile watched "${WATCH_OUTPUT_DIR}.request-ledger.json" '.requests += ($watched[0].requests // [])' "$SOURCE_BUNDLE/request-ledger.json" >"$tmp/request-ledger-combined.json"
    mv "$tmp/request-ledger-combined.json" "$SOURCE_BUNDLE/request-ledger.json"
    watcher_hashes="$(find "$SOURCE_BUNDLE/raw/watcher" -maxdepth 1 -type f -print0 | xargs -0 shasum -a 256 | awk '{print $2 ":" $1}' | jq -Rn '[inputs|split(":")|{path:.[0],sha256:.[1]}]')"
    jq --arg hash "$(sha256_file "$SOURCE_BUNDLE/request-ledger.json")" --argjson count "$watcher_requests" --argjson polls "$watcher_poll_count" --argjson receipts "$watcher_hashes" '.request_count += $count | .source_sha256.request_ledger=$hash | .watcher_receipts=$receipts | .watcher_poll_count=$polls' "$SOURCE_BUNDLE/manifest.json" >"$tmp/manifest-watcher.json"
    mv "$tmp/manifest-watcher.json" "$SOURCE_BUNDLE/manifest.json"
  fi
  if [[ "$COMPARISON_ATTEMPT_SCOPED" == true || "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    PYTHONPATH="$ROOT/scripts/ci" python3 - "$SOURCE_BUNDLE" "$CONTRACT_FILE" "$COMPARISON_RUNS_FILE" "$COMPARISON_ROLE" "$ROOT" <<'PY' || fail "attempt_scoped_raw_family_materialization_failed"
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1]).resolve(); contract=json.loads(pathlib.Path(sys.argv[2]).read_text())
registrations=json.loads(pathlib.Path(sys.argv[3]).read_text()); role=sys.argv[4]
project_root=pathlib.Path(sys.argv[5]).resolve()
from ci_metrics_security import comparison_native_inventories, validate_producer_commit, validate_workflow_source, validate_producer_binding, validate_repaired_pr_origin, comparison_runner_images, validate_repaired_control_metadata, repaired_cache_stratum
inventories=comparison_native_inventories(contract,role,project_root)
expected_sha=contract.get('baseline_application_sha') if role=='before' else (contract.get('candidate_identity') or {}).get('application_sha')
expected_producer_sha=(contract.get('baseline_identity') or {}).get('producer_source_sha') if role=='before' else (contract.get('candidate_identity') or {}).get('producer_source_sha')
workflow_sha=contract.get('baseline_workflow_sha256') if role=='before' else (contract.get('candidate_identity') or {}).get('workflow_file_sha256')
workload_sha=contract.get('baseline_workload_revision_sha256') if role=='before' else (contract.get('candidate_identity') or {}).get('workload_revision_sha256')
instrument=contract.get('instrumentation_identity') or {}
if not expected_sha or not expected_producer_sha or not workflow_sha or not workload_sha or not instrument.get('exunit') or not instrument.get('playwright'):
    raise SystemExit('frozen_attempt_source_or_instrumentation_identity_missing')
families=[]
for registration in registrations:
    run_id=str(registration['run_id']); run_path=root/'raw'/'families'/str(registration.get('sample_id') or run_id)/'run.json'
    run=json.loads(run_path.read_text())
    attempt=int(registration.get('run_attempt') or run.get('run_attempt') or 0)
    if attempt < 1: raise SystemExit('raw_attempt_number_missing')
    sample_id=str(registration.get('sample_id') or run_id)
    family=root/'raw'/'families'/sample_id
    detail=json.loads((family/'manifest.json').read_text())
    if str(run.get('id'))!=run_id or run.get('run_attempt')!=attempt or run.get('head_sha')!=expected_sha or detail.get('detail_status')!='complete':
        raise SystemExit(f'raw_attempt_identity_or_detail_invalid:{sample_id}')
    if contract.get('sample_identity')=='run_id+run_attempt':
        if not (run.get('run_started_at') or run.get('queued_at')) or (run.get('run_started_at') or run.get('queued_at'))!=registration.get('attempt_origin_at'):
            raise SystemExit(f'raw_attempt_origin_missing_or_changed:{sample_id}')
    elif run.get('created_at') != registration.get('created_at'):
        raise SystemExit(f'raw_original_creation_time_changed:{sample_id}')
    attempt_ref=(detail.get('attempt_jobs') or {}).get(str(attempt))
    if not isinstance(attempt_ref,dict) or attempt_ref.get('path')!=f'raw/families/{sample_id}/jobs-attempt-{attempt}.json':
        raise SystemExit(f'raw_attempt_jobs_missing:{sample_id}')
    jobs_file=(root/attempt_ref['path']).resolve()
    if root not in jobs_file.parents or hashlib.sha256(jobs_file.read_bytes()).hexdigest()!=attempt_ref.get('sha256'):
        raise SystemExit(f'raw_attempt_jobs_hash_invalid:{sample_id}')
    jobs=json.loads(jobs_file.read_text()).get('jobs')
    if not isinstance(jobs,list) or any(str(j.get('run_id'))!=run_id or j.get('run_attempt')!=attempt or j.get('head_sha')!=expected_sha for j in jobs):
        raise SystemExit(f'raw_attempt_job_origin_invalid:{sample_id}')
    evidence_ref=detail.get('artifact_evidence') or {}
    evidence_path=(root/evidence_ref.get('path','')).resolve()
    if root not in evidence_path.parents or not evidence_path.is_file() or hashlib.sha256(evidence_path.read_bytes()).hexdigest()!=evidence_ref.get('sha256'):
        raise SystemExit(f'raw_attempt_artifact_evidence_missing:{sample_id}')
    evidence=json.loads(evidence_path.read_text()); metadata=[]
    for row in evidence:
        artifact=row.get('artifact') or {}; result=row.get('result') or {}; artifact_name=artifact.get('name') or ''
        if result.get('status')!='accepted': continue
        api_attempt=(artifact.get('workflow_run') or {}).get('run_attempt')
        if api_attempt is not None and api_attempt!=attempt: raise SystemExit(f'artifact_other_attempt:{sample_id}:{artifact_name}')
        aid=str(artifact.get('id','')); extracted=family/'artifacts'/aid
        if not aid.isdigit() or not extracted.is_dir(): continue
        for path in extracted.rglob('ci-measurement-metadata.json'):
            meta=json.loads(path.read_text()); meta_attempt=str(meta.get('run_attempt',''))
            job_name=meta.get('job_name'); seam=meta.get('matrix_seam')
            expected_job=f'Example Playwright shard ({seam})' if job_name=='Example Playwright shard' and seam else job_name
            matching=[job for job in jobs if job.get('name')==expected_job]
            if (str(meta.get('run_id'))!=run_id or meta_attempt!=str(attempt) or meta.get('source_sha')!=expected_producer_sha
                    or meta.get('event')!='pull_request' or len(matching)!=1):
                raise SystemExit(f'attempt_measurement_metadata_origin_invalid:{sample_id}:{artifact_name}')
            if matching[0].get('conclusion')!='success':
                raise SystemExit(f"attempt_measurement_job_not_successful:{sample_id}:{expected_job}:{matching[0].get('conclusion')}")
            metadata.append((meta,artifact_name))
    if not metadata: raise SystemExit(f'attempt_measurement_metadata_missing:{sample_id}')
    producer=[(m,n) for m,n in metadata if m.get('job_name')=='Library tests shard' or m.get('job_name')=='Example Playwright shard']
    if not any(m.get('job_name')=='Library tests shard' for m,_ in producer) or not all(any(m.get('job_name')=='Example Playwright shard' and m.get('matrix_seam')==owner for m,_ in producer) for owner in ('admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase')):
        raise SystemExit(f'attempt_measurement_owner_metadata_incomplete:{sample_id}')
    producer_ref=(detail.get('producer_commits') or {}).get(expected_producer_sha) or {}
    def proof_file(key, digest_key):
        path=(root/producer_ref.get(key,'')).resolve()
        if root not in path.parents or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=producer_ref.get(digest_key):
            raise SystemExit(f'producer_source_proof_missing:{sample_id}:{key}')
        return path.read_bytes()
    commit=json.loads(proof_file('commit_path','commit_sha256')); tree=json.loads(proof_file('tree_path','tree_sha256'))
    workflow=proof_file('workflow_path','workflow_sha256')
    if validate_producer_commit(expected_producer_sha,commit,run) or validate_workflow_source(expected_producer_sha,tree,workflow,workflow_sha,commit.get('commit',{}).get('tree',{}).get('sha')):
        raise SystemExit(f'producer_source_proof_invalid:{sample_id}')
    local_tree=__import__('subprocess').check_output(['git','-C',str(project_root),'rev-parse',expected_sha+'^{tree}'],text=True).strip()
    if commit.get('commit',{}).get('tree',{}).get('sha')!=local_tree: raise SystemExit(f'producer_checkout_tree_changed:{sample_id}')
    derived=[]
    for owner,inventory in inventories.items():
        named=[row for row in evidence if (row.get('result') or {}).get('status')=='accepted' and (row.get('artifact') or {}).get('name')==f'example-playwright-{owner}-{run_id}']
        if len(named)!=1: raise SystemExit(f'native_report_artifact_missing:{sample_id}:{owner}')
        artifact=named[0]['artifact']; extracted=family/'artifacts'/str(artifact['id'])
        descriptor=inventory['descriptor']; retained=descriptor['reports'][0]
        reports=list(extracted.rglob(pathlib.Path(retained['path']).name))
        if len(reports)!=1: raise SystemExit(f'native_report_member_missing:{sample_id}:{owner}')
        output=family/'artifacts'/'derived-native'/owner; output.mkdir(parents=True,exist_ok=False)
        raw_report=reports[0].read_bytes(); (output/'report.json').write_bytes(raw_report)
        (output/'selection.json').write_bytes(inventory['selection'])
        updated={**descriptor,'source_sha':expected_sha,'inventory_source_sha':inventory['inventory_source_sha'],
            'workflow_sha256':workflow_sha,'inventory_workflow_sha256':descriptor['workflow_sha256'],
            'workflow_amendment_authorization_sha256':inventory.get('workflow_authorization_sha256'),
            'reports':[{**retained,'source_sha':expected_sha,'path':'report.json','selection_path':'selection.json','sha256':hashlib.sha256(raw_report).hexdigest(),'selection_sha256':hashlib.sha256(inventory['selection']).hexdigest()}]}
        (output/'coverage-source.json').write_text(json.dumps(updated,sort_keys=True,separators=(',',':')))
        derived.append({'owner':owner,'artifact_id':artifact['id'],'report_member_path':str(reports[0].relative_to(root)),
            'directory':str(output.relative_to(root)),'file_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir()}})
    detail['derived_native_coverage']=derived
    (family/'manifest.json').write_text(json.dumps(detail,sort_keys=True,separators=(',',':')))
    repaired=contract.get('comparison_kind')=='repaired_control_pr'
    images=comparison_runner_images([m for m,_ in producer],require_proof=(repaired or contract.get('runner_image_proof_required') is True))
    cache_stratum='not_warm'; cache_components={}; eligible_cache_scopes={}
    if repaired:
        if len(run.get('pull_requests') or [])!=1: raise SystemExit('repaired_control_pull_request_origin_missing')
        pr_ref,merge_ref=detail.get('pull_request'),detail.get('merge_commit')
        if not isinstance(pr_ref,dict) or not isinstance(merge_ref,dict): raise SystemExit('repaired_control_pull_request_receipt_missing')
        pr_path=(root/pr_ref.get('path','')).resolve(); merge_path=(root/merge_ref.get('path','')).resolve()
        if root not in pr_path.parents or root not in merge_path.parents or not pr_path.is_file() or not merge_path.is_file():
            raise SystemExit('repaired_control_pull_request_receipt_path_invalid')
        if hashlib.sha256(pr_path.read_bytes()).hexdigest()!=pr_ref.get('sha256') or hashlib.sha256(merge_path.read_bytes()).hexdigest()!=merge_ref.get('sha256'):
            raise SystemExit('repaired_control_pull_request_receipt_hash_invalid')
        pr=json.loads(pr_path.read_text()); merge=json.loads(merge_path.read_text())
        registration=next((item for item in registrations if item.get('run_id')==int(run_id)
            and (item.get('run_attempt') is None or item.get('run_attempt')==attempt)),None)
        if registration is None: raise SystemExit('repaired_control_registration_for_raw_pr_missing')
        if validate_repaired_pr_origin(run,pr,merge,registration): raise SystemExit('repaired_control_pr_merge_origin_mismatch')
        expected_ref=f"refs/pull/{pr['number']}/merge"
        eligibility=contract.get('cache_eligibility') or {}
        repository_path=root/'raw'/'comparison-repository.json'
        if not repository_path.is_file(): raise SystemExit('repaired_control_repository_default_branch_missing')
        repository=json.loads(repository_path.read_text())
        default_ref='refs/heads/'+str(repository.get('default_branch') or '')
        if default_ref!=eligibility.get('default_branch_ref') or repository.get('id')!=1207487684:
            raise SystemExit('repaired_control_repository_default_branch_identity_mismatch')
        role_keys=(eligibility.get('expected_keys') or {}).get(role) or {}
        owner_set={'library','admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase'}
        if not isinstance(default_ref,str) or not default_ref.startswith('refs/heads/') or set(role_keys)!=owner_set:
            raise SystemExit('repaired_control_cache_eligibility_contract_missing')
        expected_by_owner={}
        for owner,components in role_keys.items():
            if not isinstance(components,dict) or not components or any(not isinstance(key,str) or not key for key in components.values()):
                raise SystemExit(f'repaired_control_cache_expected_keys_invalid:{owner}')
            expected_by_owner[owner]=components
        base_ref=(pr.get('base') or {}).get('ref'); head_ref=(pr.get('head') or {}).get('ref')
        eligible_cache_scopes={default_ref}
        if isinstance(base_ref,str) and base_ref:
            eligible_cache_scopes.add('refs/heads/'+base_ref)
        if (isinstance(head_ref,str) and head_ref
                and ((pr.get('head') or {}).get('repo') or {}).get('id')==1207487684):
            eligible_cache_scopes.add('refs/heads/'+head_ref)
        eligible_cache_scopes.add(expected_ref)
        metadata_errors=validate_repaired_control_metadata([m for m,_ in producer],expected_ref=expected_ref,
            eligible_scopes=eligible_cache_scopes,expected_keys=expected_by_owner)
        if metadata_errors: raise SystemExit('repaired_control_metadata_invalid:'+','.join(metadata_errors))
        if len(images)!=6: raise SystemExit('repaired_control_runner_image_owner_set_incomplete')
        cache_stratum,cache_components=repaired_cache_stratum([m for m,_ in producer])
    families.append({'reservation_id':registration['reservation_id'],'pair_id':registration['pair_id'],'family_role':role,'run_id':int(run_id),
        'run_attempt':attempt,'sample_id':sample_id,'created_at':run.get('created_at'),'attempt_origin_at':registration['attempt_origin_at'],
        'conclusion':run.get('conclusion'),'workload':detail.get('workload'),'workload_sha':workload_sha,
        'source_workload_revision_sha256':workload_sha,'coverage_map_sha256':contract['native_coverage_comparison']['mapping_sha256'],'workflow_sha256':workflow_sha,
        'runner_class':images,'runner_image':images,'cache_stratum':cache_stratum,
        'cache_components':cache_components,'eligible_cache_scopes':sorted(eligible_cache_scopes),
        'cache_key_scope':{owner:{key:{'matched_cache_key':value.get('matched_cache_key'),'scope':value.get('scope'),'ref':value.get('ref'),'exact_key':value.get('exact_key'),'cache_hit':value.get('cache_hit'),'conditions':value.get('conditions')} for key,value in (row.get('cache_outcome') or {}).items() if isinstance(value,dict)} for owner,row in ((m.get('matrix_seam') or 'library',m) for m,_ in producer)},
        'exunit_instrumentation':instrument['exunit'],'playwright_instrumentation':instrument['playwright'],'attempts':[]})
manifest_path=root/'manifest.json'; manifest=json.loads(manifest_path.read_text())
manifest['comparison_families']=families
manifest['measured_pr_identity']={'application_sha':expected_sha,'workflow_revision':expected_sha,'workflow_file_sha256':workflow_sha,'workload_revision_sha256':workload_sha}
manifest_path.write_text(json.dumps(manifest,sort_keys=True,separators=(',',':'))+'\n')
PY
  fi
  # Run the independent hosted-origin verifier against every retained raw family.
  # This is separate from snapshot hash replay and binds early registration, PR
  # head/base, all attempts, required checks, and artifact API/archive origins.
  local origin_results="$tmp/origin-verification.json" origin_status=passed origin_error
  printf '[]\n' >"$origin_results"
  while IFS= read -r registration; do
    [[ -n "$registration" ]] || continue
    jq --arg kind "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" \
      '. + (if $kind=="repaired_control_pr" then {comparison_kind:$kind} else {} end)' \
      <<<"$registration" >"$tmp/registration.json"
    if ! python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --mode comparison-family \
      --evidence "$SOURCE_BUNDLE" --registration "$tmp/registration.json" \
      --required-contexts "$(jq -c '.required_contexts' "$CONTRACT_FILE")" \
      --required-app-ids "$(jq -c '.required_check_apps' "$CONTRACT_FILE")" >"$tmp/origin-one.json" 2>"$tmp/origin-one.err"; then
      origin_status=insufficient_data
      origin_error="$(tr '\n' ' ' <"$tmp/origin-one.err" | cut -c1-500)"
      jq -cn --slurpfile prior "$origin_results" --argjson run_id "$(jq '.run_id' <<<"$registration")" --arg error "$origin_error" '$prior[0]+[{run_id:$run_id,status:"failed",error:$error}]' >"$origin_results.tmp" && mv "$origin_results.tmp" "$origin_results"
    else jq -cn --slurpfile prior "$origin_results" --slurpfile result "$tmp/origin-one.json" '$prior[0]+[$result[0]]' >"$origin_results.tmp" && mv "$origin_results.tmp" "$origin_results"; fi
  done < <(jq -c '.[]' "$COMPARISON_RUNS_FILE")
  cp "$origin_results" "$SOURCE_BUNDLE/comparison-origin-verification.json"
  contract_hash="$(PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" <<'PY'
import json,pathlib,sys
from ci_metrics_security import comparison_contract_sha256
print(comparison_contract_sha256(json.loads(pathlib.Path(sys.argv[1]).read_text())))
PY
)"
  local registered_count
  registered_count="$(jq 'length' "$COMPARISON_RUNS_FILE")"
  repository_identity='null'
  if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    local repo_file="$SOURCE_BUNDLE/raw/comparison-repository.json"
    if [[ -s "$repo_file" ]] && jq -e '.id==1207487684 and (.default_branch|type)=="string" and .default_branch!=""' "$repo_file" >/dev/null; then
      repository_identity="$(jq -cn --arg path "raw/comparison-repository.json" --arg sha256 "$(sha256_file "$repo_file")" --arg endpoint "/repos/${REPO}" --slurpfile repo "$repo_file" '{path:$path,sha256:$sha256,endpoint:$endpoint,repository_id:$repo[0].id,default_branch:$repo[0].default_branch}')"
    else
      origin_status=insufficient_data
    fi
  fi
  registration_hash="$(sha256_file "$REGISTRATIONS_FILE")"
  budget_hash="$(sha256_file "$REQUEST_BUDGET_LEDGER")"
  jq --arg role "$COMPARISON_ROLE" --arg contract_sha256 "$contract_hash" --arg registrations_sha256 "$registration_hash" --arg request_budget_sha256 "$budget_hash" --argjson registered_runs "$(cat "$COMPARISON_RUNS_FILE")" --argjson origin_verification "$(cat "$origin_results")" --argjson repository_identity "$repository_identity" --arg origin_status "$origin_status" '.comparison_collection={role:$role,contract_sha256:$contract_sha256,registrations_sha256:$registrations_sha256,request_budget_ledger_sha256:$request_budget_sha256,registered_runs:$registered_runs,repository_identity:$repository_identity,origin_status:$origin_status,origin_verification:$origin_verification,parity_status:"pending_native_comparison"}' "$SOURCE_BUNDLE/manifest.json" >"$SOURCE_BUNDLE/manifest.json.tmp" && mv "$SOURCE_BUNDLE/manifest.json.tmp" "$SOURCE_BUNDLE/manifest.json"
  sync "$SOURCE_BUNDLE/manifest.json" 2>/dev/null || sync 2>/dev/null || true
  rm -rf "$tmp"
  printf '{"status":"collected","role":"%s","registered_families":%s,"origin_status":"%s","parity_status":"pending_native_comparison","request_budget_ledger_sha256":"%s"}\n' "$COMPARISON_ROLE" "$registered_count" "$origin_status" "$budget_hash"
}

collect_family() {
  [[ "$REPO" == "szTheory/sigra" ]] || fail "collect_repo_mismatch"
  [[ "$WORKFLOW" == "ci.yml" ]] || fail "collect_workflow_mismatch"
  [[ "$RUN_ID" =~ ^[0-9]+$ ]] || fail "collect_requires_numeric_run_id"
  [[ -n "$SOURCE_BUNDLE" ]] || fail "collect_requires_source_bundle"
  [[ ! -e "$SOURCE_BUNDLE" ]] || fail "source_bundle_already_exists"
  mkdir -p "$SOURCE_BUNDLE/raw"
  API_LEDGER="$SOURCE_BUNDLE/request-ledger.json"
  API_STARTED="$(date +%s)"
  API_COMPLETED=false
  API_REQUEST_LOG='[]'
  if [[ "${CI_METRICS_TEST_MODE:-0}" == 1 && "${CI_METRICS_TEST_PRIOR_REQUESTS:-}" =~ ^[0-9]+$ ]] && (( CI_METRICS_TEST_PRIOR_REQUESTS <= 600 )); then API_REQUESTS="$CI_METRICS_TEST_PRIOR_REQUESTS"; else API_REQUESTS=0; fi
  api_write_ledger collecting
  local tmp branch_protection effective_rules rulesets run jobs checks source_sha state branch clean workflow_hash cutoff local_sha local_branch
  tmp="$(mktemp -d)"
  API_TEMP_DIR="$tmp"
  trap api_cleanup EXIT
  trap 'api_write_ledger incomplete; [[ -n "$API_TEMP_DIR" && -d "$API_TEMP_DIR" ]] && rm -rf "$API_TEMP_DIR"; exit 130' INT TERM HUP
  # First live request itself goes through the shared cap/clock/retry helper.
  if ! api_get rate_limit "$tmp/rate-limit.json"; then
    printf '%s\n' "$API_UNKNOWN" >"$SOURCE_BUNDLE/missing-capabilities.json"
    return 1
  fi
  # Fetch active ruleset discovery and effective branch rules under the same guard.
  if ! api_get "/repos/${REPO}/rules/branches/${TARGET_BRANCH}" "$tmp/effective-rules.json"; then
    api_stop branch_rules_unavailable "" "effective branch rules"
  else
    cp "$tmp/effective-rules.json" "$SOURCE_BUNDLE/raw/effective-rules.json"
  fi
  if ! api_get "/repos/${REPO}/branches/${TARGET_BRANCH}/protection/required_status_checks" "$tmp/branch-protection.json"; then
    if [[ "$API_LAST_ERROR" =~ 404 ]]; then
      jq -n '{status:"not_configured",http_status:404}' >"$tmp/branch-protection.json"
      API_STOP_REASON=""
      API_UNKNOWN='[]'
    else
      api_stop branch_protection_unavailable "" "branch protection"
      printf '%s\n' "$API_UNKNOWN" >"$SOURCE_BUNDLE/missing-capabilities.json"
      return 1
    fi
  else
    cp "$tmp/branch-protection.json" "$SOURCE_BUNDLE/raw/branch-protection.json"
  fi
  cp "$tmp/branch-protection.json" "$SOURCE_BUNDLE/raw/branch-protection.json"
  if ! api_get "/repos/${REPO}/rulesets?per_page=100" "$tmp/rulesets.json"; then
    api_stop active_rulesets_unavailable "" "active rulesets"
  else
    cp "$tmp/rulesets.json" "$SOURCE_BUNDLE/raw/rulesets.json"
  fi
  if ! api_get "/repos/${REPO}/actions/runs/${RUN_ID}" "$tmp/run.json"; then
    api_stop run_metadata_unavailable "" "workflow run"
  else
    cp "$tmp/run.json" "$SOURCE_BUNDLE/raw/run.json"
  fi
  run="$tmp/run.json"
  source_sha="$(jq -r '.head_sha // empty' "$run")"
  if [[ "$(jq -r '.id // empty' "$run")" != "$RUN_ID" || -z "$source_sha" || "$(jq -r '.run_attempt // empty' "$run")" == "" || "$(jq -r '.event // empty' "$run")" != "pull_request" || "$(jq -r '.path // ""' "$run")" != ".github/workflows/ci.yml" || "$(jq -r '.repository.id // empty' "$run")" != 1207487684 ]]; then
    api_stop run_identity_mismatch "" "run identity"
  fi
  local attempt_id
  attempt_id="$(jq -r '.run_attempt' "$run")"
  local all_jobs='[]' attempt_num
  for ((attempt_num=1; attempt_num<=attempt_id; attempt_num++)); do
    if ! api_get "/repos/${REPO}/actions/runs/${RUN_ID}/attempts/${attempt_num}/jobs?per_page=100" "$tmp/jobs-attempt-${attempt_num}.json"; then
      api_stop jobs_unavailable "" "attempt ${attempt_num} jobs"
      printf '%s\n' "$API_UNKNOWN" >"$SOURCE_BUNDLE/missing-capabilities.json"
      return 1
    fi
    cp "$tmp/jobs-attempt-${attempt_num}.json" "$SOURCE_BUNDLE/raw/jobs-attempt-${attempt_num}.json"
    all_jobs="$(jq -cn --argjson attempt "$attempt_num" --argjson prior "$all_jobs" --slurpfile current "$SOURCE_BUNDLE/raw/jobs-attempt-${attempt_num}.json" '$prior + (($current[0].jobs // []) | map(. + {attempt:$attempt}))')"
  done
  jq -cn --argjson jobs "$all_jobs" '{jobs:$jobs}' >"$SOURCE_BUNDLE/raw/jobs.json"
  if ! api_get "/repos/${REPO}/commits/${source_sha}/check-runs?per_page=100" "$tmp/check-runs.json"; then
    api_stop check_runs_unavailable "" "check runs"
  else
    cp "$tmp/check-runs.json" "$SOURCE_BUNDLE/raw/check-runs.json"
  fi
  local approved required actual required_json rules_changed required_info job_cost last_required diagnostics attempt_hashes
  approved="$(approved_required_contexts)"
  required_info="$(derive_required_contexts "$tmp/effective-rules.json" "$tmp/branch-protection.json")"
  actual="$(jq -c '.actual' <<<"$required_info")"
  required_json="$actual"
  rules_changed="$(jq -r '.changed' <<<"$required_info")"
  cp "$tmp/rate-limit.json" "$SOURCE_BUNDLE/raw/rate-limit.json"
  cp "$tmp/branch-protection.json" "$SOURCE_BUNDLE/raw/branch-protection.json"
  cp "$tmp/effective-rules.json" "$SOURCE_BUNDLE/raw/effective-rules.json"
  cp "$tmp/rulesets.json" "$SOURCE_BUNDLE/raw/rulesets.json"
  attempt_hashes='{}'
  for ((attempt_num=1; attempt_num<=attempt_id; attempt_num++)); do
    attempt_hashes="$(jq -cn --arg key "jobs_attempt_${attempt_num}" --arg hash "$(sha256_file "$SOURCE_BUNDLE/raw/jobs-attempt-${attempt_num}.json")" --argjson prior "$attempt_hashes" '$prior + {($key):$hash}')"
  done
  # Bundle every raw response with hashes before computing any timing.
  jq -n --arg repo "$REPO" --arg workflow "$WORKFLOW" --argjson run_id "$RUN_ID" \
    --argjson attempt "$attempt_id" --arg sha "$source_sha" --argjson rules "$required_json" \
    --argjson expected "$approved" --argjson rules_changed "$rules_changed" --arg required_source "$(jq -r '.source' <<<"$required_info")" --argjson rules_diagnostics "$(jq -c '.diagnostics' <<<"$required_info")" \
    --argjson rulesets "$(jq -c '[.[]? | select(.enforcement=="active") | {id,name,target,enforcement}]' "$SOURCE_BUNDLE/raw/rulesets.json")" \
    --arg branch "$(jq -r '.head_branch // empty' "$run")" --arg url "$(jq -r '.html_url // empty' "$run")" \
    --arg conclusion "$(jq -r '.conclusion // empty' "$run")" --argjson all_attempts "$attempt_id" \
    --arg run_hash "$(sha256_file "$SOURCE_BUNDLE/raw/run.json")" \
    --arg jobs_hash "$(sha256_file "$SOURCE_BUNDLE/raw/jobs.json")" \
    --arg checks_hash "$(sha256_file "$SOURCE_BUNDLE/raw/check-runs.json")" \
    --arg rules_hash "$(sha256_file "$SOURCE_BUNDLE/raw/effective-rules.json")" \
    --arg protection_hash "$(sha256_file "$SOURCE_BUNDLE/raw/branch-protection.json")" \
    --arg rulesets_hash "$(sha256_file "$SOURCE_BUNDLE/raw/rulesets.json")" \
    --arg rate_hash "$(sha256_file "$SOURCE_BUNDLE/raw/rate-limit.json")" --argjson attempt_hashes "$attempt_hashes" \
    '{schema_version:"sigra.ci-run-metrics/family-v1",repository:$repo,workflow:$workflow,event:"pull_request",branch:$branch,run_id:$run_id,attempt:$attempt,attempts_collected:$all_attempts,source_sha:$sha,revisions:[{source_sha:$sha,run_id:$run_id,attempt:$attempt,associated_pull_requests:[]}],run_url:$url,literal_conclusion:$conclusion,required_contexts:$rules,approved_contexts:$expected,required_context_source:$required_source,required_rules_changed:$rules_changed,required_rules_diagnostics:$rules_diagnostics,active_rulesets:$rulesets,raw_sha256:($attempt_hashes + {run:$run_hash,jobs:$jobs_hash,check_runs:$checks_hash,effective_rules:$rules_hash,branch_protection:$protection_hash,rulesets:$rulesets_hash,rate_limit:$rate_hash})}' >"$SOURCE_BUNDLE/manifest.json"
  rm -rf "$tmp"
  api_write_ledger complete
  jq --arg sha256 "$(sha256_file "$SOURCE_BUNDLE/request-ledger.json")" '.request_ledger_sha256=$sha256' "$SOURCE_BUNDLE/manifest.json" >"$SOURCE_BUNDLE/manifest.json.tmp"
  mv "$SOURCE_BUNDLE/manifest.json.tmp" "$SOURCE_BUNDLE/manifest.json"
  API_COMPLETED=true
  API_TEMP_DIR=""
  trap - EXIT INT TERM HUP
  replay_family "$SOURCE_BUNDLE" json
}

run_preflight() {
  [[ -n "$PREFLIGHT_OUTPUT" ]] || fail "--preflight requires --preflight-output"
  API_LEDGER="${PREFLIGHT_OUTPUT%.json}-request-ledger.json"
  API_STARTED="$(date +%s)"
  API_COMPLETED=false
  API_REQUEST_LOG='[]'
  if [[ "${CI_METRICS_TEST_MODE:-0}" == 1 && "${CI_METRICS_TEST_PRIOR_REQUESTS:-}" =~ ^[0-9]+$ ]] && (( CI_METRICS_TEST_PRIOR_REQUESTS <= 600 )); then API_REQUESTS="$CI_METRICS_TEST_PRIOR_REQUESTS"; else API_REQUESTS=0; fi
  API_STOP_REASON=""
  API_RESET_AT=""
  API_CORE_REMAINING=""
  API_UNKNOWN='[]'
  API_LAST_ERROR=""
  local tmp sha branch dirty workflow_hash utc cutoff status missing effective rulesets protection approved current status_code capability toolchain ruleset_provenance
  tmp="$(mktemp -d)"
  API_TEMP_DIR="$tmp"
  trap api_cleanup EXIT
  trap 'api_write_ledger incomplete; [[ -n "$API_TEMP_DIR" && -d "$API_TEMP_DIR" ]] && rm -rf "$API_TEMP_DIR"; exit 130' INT TERM HUP
  utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cutoff="$utc"
  sha="$(git rev-parse HEAD)"
  branch="$(git branch --show-current)"
  dirty="$(git status --porcelain=v1 --untracked-files=all | jq -Rsc 'split("\n") | map(select(length>0))')"
  workflow_hash="$(git hash-object .github/workflows/ci.yml)"
  local gh_version pins
  gh_version="$(GH_NO_UPDATE_NOTIFIER=1 gh --version 2>/dev/null | head -1 || echo unavailable)"
  pins="$(tr '\n' ';' <.tool-versions 2>/dev/null || echo unavailable)"
  toolchain="$(jq -cn --arg gh_path "$(command -v gh || echo unavailable)" --arg gh "$gh_version" --arg bash "$BASH_VERSION" --arg jq "$(jq --version 2>/dev/null || echo unavailable)" --arg project_pins "$pins" '{gh_path:$gh_path,gh:$gh,bash:$bash,jq:$jq,project_runtime_pins:$project_pins}')"
  approved="$(approved_required_contexts)"
  missing='[]'
  status=ready
  if ! api_get rate_limit "$tmp/rate-limit.json"; then
    status=blocked; missing="$(jq -cn --arg reason "$API_STOP_REASON" '["github_rate_limit_preflight:"+$reason]')"
  fi
  if [[ "$status" == ready ]]; then
    if api_get "/repos/${REPO}/branches/${TARGET_BRANCH}/protection/required_status_checks" "$tmp/branch-protection.json"; then
      cp "$tmp/branch-protection.json" "${PREFLIGHT_OUTPUT%.json}-branch-protection.json"
    elif [[ "$API_LAST_ERROR" =~ 404 ]]; then
      jq -n '{status:"not_configured",http_status:404}' >"$tmp/branch-protection.json"
      cp "$tmp/branch-protection.json" "${PREFLIGHT_OUTPUT%.json}-branch-protection.json"
      API_STOP_REASON=""
      API_UNKNOWN='[]'
    else
      status=blocked; missing="$(jq -cn --arg reason "$API_STOP_REASON" '["branch_protection_source:"+$reason]')"
    fi
  fi
  if [[ "$status" == ready ]]; then
    if api_get "/repos/${REPO}/rules/branches/${TARGET_BRANCH}" "$tmp/effective-rules.json"; then
      cp "$tmp/effective-rules.json" "${PREFLIGHT_OUTPUT%.json}-effective-rules.json"
    else
      status=blocked; missing="$(jq -cn --arg reason "$API_STOP_REASON" '["effective_branch_rules_source:"+$reason]')"
    fi
  fi
  if [[ "$status" == ready ]]; then
    if api_get "/repos/${REPO}/rulesets?per_page=100" "$tmp/rulesets.json"; then
      cp "$tmp/rulesets.json" "${PREFLIGHT_OUTPUT%.json}-active-rulesets.json"
      ruleset_provenance="$(jq -c '[.[]? | select(.enforcement=="active") | {id,name,target,enforcement}]' "$tmp/rulesets.json")"
    else
      status=blocked; missing="$(jq -cn --arg reason "$API_STOP_REASON" '["active_rulesets_source:"+$reason]')"
    fi
  fi
  [[ -n "${ruleset_provenance:-}" ]] || ruleset_provenance='[]'
  required_info="$(derive_required_contexts "$tmp/effective-rules.json" "$tmp/branch-protection.json")"
  current="$(jq -c '.actual' <<<"$required_info")"
  if [[ "$status" == ready && "$(jq -r '.changed' <<<"$required_info")" == true ]]; then
    status=blocked
    missing="$(jq -cn --argjson expected "$approved" --argjson actual "$current" '[{reason:"required_rules_changed",expected:$expected,actual:$actual}]')"
  fi
  api_write_ledger "$([[ "$status" == ready ]] && echo complete || echo incomplete)"
  jq -n --arg status "$status" --arg checkout_sha "$sha" --arg branch "$branch" \
    --arg workflow_blob_sha "$workflow_hash" --arg cutoff "$cutoff" --arg captured_at "$utc" \
    --argjson dirty_paths "$dirty" --argjson toolchain "$toolchain" --argjson expected "$approved" \
    --argjson current "$current" --argjson active_rulesets "$ruleset_provenance" --argjson missing "$missing" --argjson requests "$API_REQUESTS" \
    --arg core_remaining "$API_CORE_REMAINING" --arg core_reset "$API_RESET_AT" \
    --arg ledger "$API_LEDGER" --arg run_url "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID:-38144377407}" \
    --arg rules_url "https://api.github.com/repos/${REPO}/rules/branches/${TARGET_BRANCH}" \
    --arg rulesets_url "https://api.github.com/repos/${REPO}/rulesets" \
    --arg branch_protection_url "https://api.github.com/repos/${REPO}/branches/${TARGET_BRANCH}/protection/required_status_checks" \
    '{schema_version:"sigra.ci-run-metrics/preflight-v1",status:$status,checkout:{sha:$checkout_sha,branch:$branch,dirty_paths:$dirty_paths},workflow:{path:".github/workflows/ci.yml",git_blob_sha:$workflow_blob_sha},toolchain:$toolchain,source_urls:{workflow_run:$run_url,effective_branch_rules:$rules_url,branch_protection:$branch_protection_url,active_rulesets:$rulesets_url},cutoff_utc:$cutoff,captured_at_utc:$captured_at,expected_required_contexts:$expected,effective_required_contexts:$current,required_rules_changed:(($current|sort) != ($expected|sort)),active_rulesets:$active_rulesets,core_rate_remaining:(try ($core_remaining|tonumber) catch null),core_rate_reset_at:(try ($core_reset|tonumber) catch null),request_count:$requests,request_ledger:$ledger,missing_capabilities:$missing}' \
    >"${PREFLIGHT_OUTPUT}.tmp" && mv "${PREFLIGHT_OUTPUT}.tmp" "$PREFLIGHT_OUTPUT"
  rm -rf "$tmp"
  API_COMPLETED=true
  API_TEMP_DIR=""
  trap - EXIT INT TERM HUP
  [[ "$status" == ready ]] || return 2
  return 0
}

register_comparison_run() {
  [[ -s "$CONTRACT_FILE" && -n "$REGISTRATIONS_FILE" && "$RUN_ID" =~ ^[1-9][0-9]*$ && -n "$RESERVATION_ID" ]] || fail "comparison registration requires --contract, --registrations, --reservation-id and --run-id"
  python3 - "$CONTRACT_FILE" "$RESERVATION_ID" "$RUN_ID" <<'PY' || fail "comparison registration reservation or predeclared window invalid"
import json,pathlib,sys
c=json.loads(pathlib.Path(sys.argv[1]).read_text())
matches=[r for r in c.get('family_reservations',[]) if r.get('reservation_id')==sys.argv[2]]
if c.get('status')!='ready' or len(matches)!=1:
    raise SystemExit(1)
r=matches[0]
if c.get('sample_identity')=='run_id+run_attempt' and (str(r.get('run_id'))!=sys.argv[3] or type(r.get('run_attempt')) is not int or r['run_attempt']<1): raise SystemExit(1)
w=c.get('window') or {}
if not w.get('start_utc') or not w.get('end_utc') or (c.get('candidate_identity') or {}).get('status'):
    raise SystemExit(1)
PY
  if jq -e 'has("comparison_schedule")' "$CONTRACT_FILE" >/dev/null; then
    [[ -n "$REQUEST_BUDGET_LEDGER" ]] || fail "scheduled comparison registration requires --request-budget-ledger"
    PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" <<'PY' || fail "request_budget_ledger_contract_or_readback_invalid"
import json,pathlib,sys
from ci_metrics_security import initialize_comparison_request_budget
initialize_comparison_request_budget(json.loads(pathlib.Path(sys.argv[1]).read_text()),pathlib.Path(sys.argv[2]))
PY
    API_BUDGET_OWNER="sample:${RUN_ID}:$(jq -r --arg rid "$RESERVATION_ID" '.family_reservations[]|select(.reservation_id==$rid)|.run_attempt // "legacy"' "$CONTRACT_FILE")"
  fi
  local tmp run_file output_tmp
  REGISTER_LOCK="${REGISTRATIONS_FILE}.lock"
  mkdir -p "$(dirname "$REGISTRATIONS_FILE")"
  mkdir "$REGISTER_LOCK" 2>/dev/null || fail "comparison registration ledger is locked"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-comparison-register.XXXXXX")"
  run_file="$tmp/run.json"; output_tmp="${REGISTRATIONS_FILE}.tmp.$$"
  API_LEDGER="${REGISTRATIONS_FILE}.requests.json"
  API_STARTED="$(date +%s)"; API_REQUESTS=0; API_STOP_REASON=""; API_RESET_AT=""; API_UNKNOWN='[]'; API_CORE_REMAINING=""; API_REQUEST_LOG='[]'; API_LAST_RATE_REQUEST=0; API_RATE_CHECK_IN_FLIGHT=false
  API_TEMP_DIR="$tmp"
  trap 'api_cleanup; rm -rf "$REGISTER_LOCK"' EXIT INT TERM HUP
  api_get rate_limit "$tmp/rate-limit.json" || fail "comparison registration rate preflight blocked"
  local run_endpoint registered_attempt
  registered_attempt="$(jq -r --arg rid "$RESERVATION_ID" 'if .sample_identity=="run_id+run_attempt" then (.family_reservations[]|select(.reservation_id==$rid)|.run_attempt) else empty end' "$CONTRACT_FILE")"
  run_endpoint="/repos/${REPO}/actions/runs/${RUN_ID}"
  [[ -z "$registered_attempt" ]] || run_endpoint+="/attempts/${registered_attempt}"
  api_get "$run_endpoint" "$run_file" || fail "comparison run identity unavailable"
  local pr_file merge_file pr_number merge_sha
  pr_file="$tmp/pull-request.json"; merge_file="$tmp/merge-commit.json"
  if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    pr_number="$(jq -r '.pull_requests[0].number // empty' "$run_file")"
    [[ "$pr_number" =~ ^[1-9][0-9]*$ ]] || fail "comparison_pull_request_minimal_identity_invalid"
    api_get "/repos/${REPO}/pulls/${pr_number}" "$pr_file" || fail "comparison_pull_request_api_identity_unavailable"
    merge_sha="$(jq -r '.merge_commit_sha // empty' "$pr_file")"
    [[ "$merge_sha" =~ ^[0-9a-f]{40}$ ]] || fail "comparison_pull_request_merge_sha_invalid"
    api_get "/repos/${REPO}/git/commits/${merge_sha}" "$merge_file" || fail "comparison_pull_request_merge_commit_unavailable"
  else
    printf '{}\n' >"$pr_file"; printf '{}\n' >"$merge_file"
  fi
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REGISTRATIONS_FILE" "$RESERVATION_ID" "$run_file" "$output_tmp" "$pr_file" "$merge_file" <<'PY'
import hashlib,json,os,pathlib,sys
from ci_metrics_security import register_comparison_run
contract_path,ledger_path,run_path,out_path,pr_path,merge_path=map(pathlib.Path,(sys.argv[1],sys.argv[2],sys.argv[4],sys.argv[5],sys.argv[6],sys.argv[7]))
reservation_id=sys.argv[3]
contract=json.loads(contract_path.read_text()); run=json.loads(run_path.read_text())
ledger=json.loads(ledger_path.read_text()) if ledger_path.exists() else None
raw=run_path.read_bytes()
pr_raw=pr_path.read_bytes(); merge_raw=merge_path.read_bytes()
created=register_comparison_run(contract,reservation_id,run,ledger,hashlib.sha256(raw).hexdigest(),raw,
    json.loads(pr_raw),json.loads(merge_raw),pr_raw,merge_raw)
fd=os.open(out_path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
with os.fdopen(fd,'w') as stream:
    json.dump(created,stream,sort_keys=True,separators=(',',':')); stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
PY
  mv "$output_tmp" "$REGISTRATIONS_FILE"
  sync "$REGISTRATIONS_FILE" 2>/dev/null || sync 2>/dev/null || true
  api_write_ledger complete
  API_COMPLETED=true; API_TEMP_DIR=""
  rm -rf "$tmp" "$REGISTER_LOCK"
  trap - EXIT INT TERM HUP
  jq -n --arg reservation "$RESERVATION_ID" --arg run "$RUN_ID" --arg hash "$(jq -r '.records[-1].record_sha256' "$REGISTRATIONS_FILE")" '{status:"registered",reservation_id:$reservation,run_id:$run,record_sha256:$hash}'
}

collect_producer_source() {
  [[ -n "$SOURCE_BUNDLE" && -n "$RUN_ID" && "$RUN_ID" =~ ^[1-9][0-9]*$ && "$PRODUCER_SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "producer source collection requires --source-bundle, --run-id and --producer-source-sha"
  [[ ! -e "$SOURCE_BUNDLE" ]] || fail "producer source output already exists"
  mkdir -p "$(dirname "$SOURCE_BUNDLE")"
  local lock="${SOURCE_BUNDLE}.lock" tmp commit_file tree_file content_file workflow_file tree_sha
  mkdir "$lock" 2>/dev/null || fail "producer source output is locked"
  mkdir -p "$SOURCE_BUNDLE/raw" || fail "producer source output could not be created"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-producer-source.XXXXXX")"
  API_LEDGER="$SOURCE_BUNDLE/request-ledger.json"
  API_STARTED="$(date +%s)"; API_REQUESTS=0; API_STOP_REASON=""; API_RESET_AT=""; API_UNKNOWN='[]'; API_CORE_REMAINING=""; API_REQUEST_LOG='[]'; API_LAST_RATE_REQUEST=0; API_RATE_CHECK_IN_FLIGHT=false
  API_TEMP_DIR="$tmp"
  trap 'api_cleanup; rm -rf "$tmp" "$lock"' EXIT INT TERM HUP
  commit_file="$tmp/commit.json"; tree_file="$tmp/tree.json"; content_file="$tmp/workflow-content.json"; workflow_file="$tmp/ci.yml"
  api_get rate_limit "$tmp/rate-limit.json" || fail "producer source rate preflight blocked"
  api_get "/repos/${REPO}/actions/runs/${RUN_ID}" "$tmp/run.json" || fail "producer source workflow run unavailable"
  api_get "/repos/${REPO}/commits/${PRODUCER_SOURCE_SHA}" "$commit_file" || fail "producer commit unavailable"
  tree_sha="$(jq -r '.commit.tree.sha // empty' "$commit_file")"
  [[ "$tree_sha" =~ ^[0-9a-f]{40}$ ]] || fail "producer commit tree identity unavailable"
  api_get "/repos/${REPO}/git/trees/${tree_sha}?recursive=1" "$tree_file" || fail "producer workflow tree unavailable"
  api_get "/repos/${REPO}/contents/.github/workflows/ci.yml?ref=${PRODUCER_SOURCE_SHA}" "$content_file" || fail "producer workflow content unavailable"
  python3 - "$content_file" "$workflow_file" <<'PY'
import base64,json,pathlib,sys
record=json.loads(pathlib.Path(sys.argv[1]).read_text())
if record.get("encoding")!="base64" or not isinstance(record.get("content"),str): raise SystemExit("workflow_content_encoding_invalid")
pathlib.Path(sys.argv[2]).write_bytes(base64.b64decode(record["content"]))
PY
  cp "$tmp/run.json" "$SOURCE_BUNDLE/raw/run.json"
  cp "$tmp/rate-limit.json" "$SOURCE_BUNDLE/raw/rate-limit.json"
  cp "$commit_file" "$SOURCE_BUNDLE/raw/commit.json"
  cp "$tree_file" "$SOURCE_BUNDLE/raw/tree.json"
  cp "$content_file" "$SOURCE_BUNDLE/raw/workflow-content.json"
  cp "$workflow_file" "$SOURCE_BUNDLE/raw/ci.yml"
  api_write_ledger complete
  API_COMPLETED=true
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$SOURCE_BUNDLE" "$PRODUCER_SOURCE_SHA" <<'PY'
import hashlib,json,pathlib,sys
from ci_metrics_security import validate_producer_commit,validate_workflow_source
root=pathlib.Path(sys.argv[1]); sha=sys.argv[2]
run=json.loads((root/'raw/run.json').read_text()); commit=json.loads((root/'raw/commit.json').read_text()); tree=json.loads((root/'raw/tree.json').read_text()); workflow=(root/'raw/ci.yml').read_bytes()
expected_tree_sha=(commit.get('commit') or {}).get('tree',{}).get('sha')
errors=validate_producer_commit(sha,commit,run)+validate_workflow_source(sha,tree,workflow,hashlib.sha256(workflow).hexdigest(),expected_tree_sha)
if errors: raise SystemExit(','.join(errors))
files={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'raw').iterdir() if p.is_file()}
request_hash=hashlib.sha256((root/'request-ledger.json').read_bytes()).hexdigest()
(root/'manifest.json').write_text(json.dumps({'schema_version':'sigra.ci-producer-source/v1','run_id':run['id'],'producer_source_sha':sha,'pull_request_number':run['pull_requests'][0]['number'],'pr_head_sha':run['pull_requests'][0]['head']['sha'],'pr_base_sha':run['pull_requests'][0]['base']['sha'],'validated':True,'request_ledger_sha256':request_hash,'raw_sha256':files},sort_keys=True,indent=2)+'\n')
PY
  sync 2>/dev/null || true
  API_TEMP_DIR=""; rm -rf "$tmp" "$lock"; trap - EXIT INT TERM HUP
  cat "$SOURCE_BUNDLE/manifest.json"
}

replay_family() {
  local bundle="$1" output_format="${2:-json}" required_changed required_info derived_contexts manifest_contexts manifest_expected manifest_source rules_valid run created check_data jobs_json contexts check_lines last_created wait runner diagnostics
  [[ -d "$bundle" && -s "$bundle/manifest.json" ]] || fail source_bundle_missing
  [[ -s "$bundle/raw/run.json" && -s "$bundle/raw/jobs.json" && -s "$bundle/raw/check-runs.json" ]] || fail source_bundle_raw_input_missing
  jq -e '.schema_version == "sigra.ci-run-metrics/family-v1" and .repository == "szTheory/sigra" and .workflow == "ci.yml" and (.raw_sha256 | type == "object")' "$bundle/manifest.json" >/dev/null || fail source_manifest_invalid
  for name in run jobs check-runs effective-rules branch-protection rulesets rate-limit; do
    file="$bundle/raw/${name}.json"
    expected="$(jq -r --arg key "${name//-/_}" '.raw_sha256[$key] // empty' "$bundle/manifest.json")"
    case "$name" in
      check-runs) expected="$(jq -r '.raw_sha256.check_runs // empty' "$bundle/manifest.json")";;
      effective-rules) expected="$(jq -r '.raw_sha256.effective_rules // empty' "$bundle/manifest.json")";;
      branch-protection) expected="$(jq -r '.raw_sha256.branch_protection // empty' "$bundle/manifest.json")";;
      rate-limit) expected="$(jq -r '.raw_sha256.rate_limit // empty' "$bundle/manifest.json")";;
    esac
    [[ -n "$expected" && "$(sha256_file "$file")" == "$expected" ]] || fail "source_hash_mismatch:${name}"
  done
  local attempt_num attempt_limit
  attempt_limit="$(jq -r '.attempts_collected // 0' "$bundle/manifest.json")"
  for ((attempt_num=1; attempt_num<=attempt_limit; attempt_num++)); do
    file="$bundle/raw/jobs-attempt-${attempt_num}.json"
    expected="$(jq -r --arg key "jobs_attempt_${attempt_num}" '.raw_sha256[$key] // empty' "$bundle/manifest.json")"
    [[ -n "$expected" && -s "$file" && "$(sha256_file "$file")" == "$expected" ]] || fail "source_hash_mismatch:jobs-attempt-${attempt_num}"
  done
  local manifest_repo manifest_run manifest_sha manifest_attempt run_sha run_event run_workflow run_attempt
  manifest_repo="$(jq -r .repository "$bundle/manifest.json")"
  manifest_run="$(jq -r .run_id "$bundle/manifest.json")"
  manifest_attempt="$(jq -r '.attempt // 1' "$bundle/manifest.json")"
  manifest_sha="$(jq -r .source_sha "$bundle/manifest.json")"
  run_sha="$(jq -r '.head_sha // empty' "$bundle/raw/run.json")"
  run_event="$(jq -r '.event // empty' "$bundle/raw/run.json")"
  run_workflow="$(jq -r '.path // empty' "$bundle/raw/run.json")"
  run_attempt="$(jq -r '.run_attempt // empty' "$bundle/raw/run.json")"
  [[ "$manifest_repo" == "$REPO" && "$manifest_run" == "$RUN_ID" && "$manifest_sha" == "$run_sha" && -n "$run_attempt" && "$manifest_attempt" == "$run_attempt" && "$(jq -r '.id // empty' "$bundle/raw/run.json")" == "$RUN_ID" && "$(jq -r '.repository.id // empty' "$bundle/raw/run.json")" == 1207487684 && "$run_event" == "pull_request" && "$run_workflow" == ".github/workflows/ci.yml" ]] || fail source_identity_mismatch
  ledger_sha="$(jq -r '.request_ledger_sha256 // empty' "$bundle/manifest.json")"
  [[ -n "$ledger_sha" && "$(sha256_file "$bundle/request-ledger.json")" == "$ledger_sha" ]] || fail request_ledger_hash_mismatch
  required_info="$(derive_required_contexts "$bundle/raw/effective-rules.json" "$bundle/raw/branch-protection.json")"
  derived_contexts="$(jq -c '.actual' <<<"$required_info")"
  manifest_contexts="$(jq -c '.required_contexts // []' "$bundle/manifest.json")"
  manifest_expected="$(jq -c '.approved_contexts // .expected_required_contexts // []' "$bundle/manifest.json")"
  manifest_source="$(jq -r '.required_context_source // empty' "$bundle/manifest.json")"
  required_changed="$(jq -r 'if has("required_rules_changed") then .required_rules_changed else true end' "$bundle/manifest.json")"
  rules_valid=false
  if [[ "$(jq -cn --argjson actual "$derived_contexts" --argjson expected "$(approved_required_contexts)" --argjson manifest_actual "$manifest_contexts" --argjson manifest_expected "$manifest_expected" --arg source "$manifest_source" --arg derived_source "$(jq -r '.source' <<<"$required_info")" --arg changed "$required_changed" '($actual|sort)==($expected|sort) and ($manifest_actual|sort)==($actual|sort) and ($manifest_expected|sort)==($expected|sort) and ($source=="" or $source==$derived_source) and $changed=="false"')" == true ]]; then
    rules_valid=true
  else
    required_changed=true
  fi
  local binding_json
  binding_json="$(PYTHONPATH="$ROOT/scripts/ci" python3 - "$bundle" "$manifest_repo" <<'PY'
import hashlib,json,pathlib,sys
from ci_metrics_security import bind_required_checks_by_attempt
root=pathlib.Path(sys.argv[1]); repo=sys.argv[2]
run=json.loads((root/'raw/run.json').read_text()); manifest=json.loads((root/'manifest.json').read_text())
ledger=json.loads((root/'request-ledger.json').read_text()); requests=set(ledger.get('requests',[]))
attempts=int(manifest.get('attempts_collected',0)); jobs_by_attempt={}
for attempt in range(1,attempts+1):
    endpoint=f"/repos/{repo}/actions/runs/{run.get('id')}/attempts/{attempt}/jobs?per_page=100"
    if endpoint not in requests: raise SystemExit(f"family_attempt_request_missing:{attempt}")
    path=root/f'raw/jobs-attempt-{attempt}.json'
    expected=(manifest.get('raw_sha256') or {}).get(f'jobs_attempt_{attempt}')
    if not expected or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
        raise SystemExit(f"family_attempt_hash_mismatch:{attempt}")
    jobs_by_attempt[str(attempt)]=json.loads(path.read_text()).get('jobs',[])
checks=json.loads((root/'raw/check-runs.json').read_text()).get('check_runs',[])
errors,endpoints,runner=bind_required_checks_by_attempt(run,jobs_by_attempt,checks,manifest.get('required_contexts') or [],repo)
if errors: raise SystemExit(','.join(errors))
latest=str(manifest.get('attempt',1)); required=manifest.get('required_contexts') or []
if set((endpoints.get(latest) or {})) != set(required): raise SystemExit('latest_attempt_required_context_set_incomplete')
print(json.dumps({'endpoints':endpoints,'runner_seconds':runner},sort_keys=True,separators=(',',':')))
PY
  )" || fail family_required_check_api_binding_invalid
  contexts="$(jq -r '.required_contexts[]?' "$bundle/manifest.json")"
  run="$bundle/raw/run.json"
  created="$(jq -r '.created_at // empty' "$run")"
  [[ -n "$created" ]] || fail run_created_at_missing
  # Completion endpoint is accepted only when every current required check is
  # successful, has valid timestamps, and maps by external_id to an actual job.
  diagnostics='[]'
  local first_contexts='{}' eventual_contexts='{}' latest_attempt first_wait wait_value fatal context attempt endpoint
  local -a check_attempts
  latest_attempt="$(jq -r '.attempt // 1' "$bundle/manifest.json")"
  fatal=false
  first_contexts='{}'
  eventual_contexts='{}'
  if [[ "$latest_attempt" == 1 ]]; then check_attempts=(1); else check_attempts=(1 "$latest_attempt"); fi
  while IFS= read -r context; do
    for attempt in "${check_attempts[@]}"; do
      endpoint="$(jq -c --argjson e "$binding_json" --arg attempt "$attempt" --arg context "$context" '.endpoints[$attempt][$context] // null' <<<"$binding_json")"
      [[ "$endpoint" != null ]] || continue
      started="$(jq -r '.started_at // empty' <<<"$endpoint")"
      completed="$(jq -r '.completed_at // empty' <<<"$endpoint")"
      if [[ "$(jq -r '.status' <<<"$endpoint")" != completed || "$(jq -r '.conclusion' <<<"$endpoint")" != success || -z "$started" || -z "$completed" || "$(jq -nr --arg s "$started" --arg c "$completed" 'try (($s|fromdateiso8601) <= ($c|fromdateiso8601)) catch false')" != true ]]; then
        diagnostics="$(jq -c --arg name "$context" --argjson attempt "$attempt" '. + [{reason:"required_context_incomplete",context:$name,attempt:$attempt}]' <<<"$diagnostics")"
        [[ "$attempt" == "$latest_attempt" ]] && fatal=true
      else
        if [[ "$attempt" == 1 ]]; then first_contexts="$(jq -cn --argjson contexts "$first_contexts" --arg name "$context" --arg value "$completed" '$contexts + {($name):$value}')"; fi
        if [[ "$attempt" == "$latest_attempt" ]]; then eventual_contexts="$(jq -cn --argjson contexts "$eventual_contexts" --arg name "$context" --arg value "$completed" '$contexts + {($name):$value}')"; fi
      fi
    done
  done < <(jq -r '.required_contexts[]' "$bundle/manifest.json")
  required_count="$(jq '.required_contexts | length' "$bundle/manifest.json")"
  local first_count eventual_count
  first_count="$(jq -r 'length' <<<"$first_contexts")"
  eventual_count="$(jq -r 'length' <<<"$eventual_contexts")"
  if (( first_count != required_count )); then
    diagnostics="$(jq -c --argjson found "$first_count" --argjson required "$required_count" '. + [{reason:"first_attempt_required_contexts_incomplete",found:$found,required:$required}]' <<<"$diagnostics")"
  fi
  if (( eventual_count != required_count )); then
    diagnostics="$(jq -c --argjson found "$eventual_count" --argjson required "$required_count" '. + [{reason:"eventual_required_contexts_incomplete",found:$found,required:$required}]' <<<"$diagnostics")"
    fatal=true
  fi
  first_wait=null
  wait_value=null
  if (( first_count == required_count )) && [[ "$required_changed" != true ]]; then first_wait="$(jq -nr --arg created "$created" --argjson contexts "$first_contexts" '[ $contexts[] | fromdateiso8601 ] | max - ($created|fromdateiso8601)')"; fi
  if (( eventual_count == required_count )) && [[ "$required_changed" != true ]]; then wait_value="$(jq -nr --arg created "$created" --argjson contexts "$eventual_contexts" '[ $contexts[] | fromdateiso8601 ] | max - ($created|fromdateiso8601)')"; fi
  if [[ "$required_changed" == true ]]; then
    diagnostics="$(jq -c '. + ["required_rules_changed"]' <<<"$diagnostics")"
    fatal=true
  fi
  runner="$(jq -r '.runner_seconds' <<<"$binding_json")"
  if [[ "$runner" == null ]]; then diagnostics="$(jq -c '. + [{reason:"runner_timing_incomplete"}]' <<<"$diagnostics")"; fatal=true; fi
  local result revision_count
  revision_count="$(jq -r '(.revisions // [{source_sha:.source_sha}]) | length' "$bundle/manifest.json")"
  if (( revision_count > 1 )); then
    diagnostics="$(jq -c '. + [{reason:"family_revision_source_incomplete",revision_count:'"$revision_count"'}]' <<<"$diagnostics")"
    fatal=true
    first=null
    wait_value=null
  fi
  result="$(jq -cn --argjson first "$first_wait" --argjson eventual "$wait_value" --argjson runner "$runner" --argjson diagnostics "$diagnostics" --argjson fatal "$fatal" --argjson revision_count "$revision_count" --slurpfile manifest "$bundle/manifest.json" --slurpfile checks "$bundle/raw/check-runs.json" --slurpfile run_data "$bundle/raw/run.json" '{first_attempt_required_wait_seconds:$first,eventual_required_wait_seconds:$eventual,initial_wait_seconds:null,runner_seconds:$runner,family_observation_count:1,revision_count:$revision_count,revisions:($manifest[0].revisions // [{source_sha:$manifest[0].source_sha}]),literal_outcomes:{run_conclusion:$run_data[0].conclusion,check_runs:[$checks[0].check_runs[]? | {id,name,status,conclusion}]},diagnostics:$diagnostics,status:(if $fatal then "unknown" else "measured" end)}')"
  if [[ "$output_format" == json ]]; then printf '%s\n' "$result" | jq -S .; else printf '%s\n' "$result"; fi
}

replay_snapshot() {
  local bundle="$1" manifest="$1/manifest.json" name expected file result
  [[ -s "$manifest" ]] || fail source_manifest_missing
  jq -e '.schema_version=="sigra.ci-run-metrics/snapshot-v1" and .repository=="szTheory/sigra" and .workflow=="ci.yml" and (.status=="complete" or .status=="incomplete") and (.source_sha256|type)=="object"' "$manifest" >/dev/null || fail source_manifest_invalid
  if [[ "$(jq -r '.status' "$manifest")" == incomplete ]]; then
    for name in request_ledger selection_ledger; do
      expected="$(jq -r --arg key "$name" '.source_sha256[$key] // empty' "$manifest")"
      case "$name" in request_ledger) file="$bundle/request-ledger.json";; selection_ledger) file="$bundle/selection-ledger.json";; esac
      [[ -n "$expected" && -s "$file" && "$(sha256_file "$file")" == "$expected" ]] || fail "snapshot_hash_mismatch:${name}"
    done
    jq -S '{schema_version,repository,workflow,cutoff_utc,window_start_utc,status,stop_reason,request_count,selection_ledger}' "$manifest"
    return 0
  fi
  for name in request_ledger selection_ledger pull_request push_main schedule manual release_push rate_limit effective_rules branch_protection rulesets; do
    case "$name" in
      request_ledger) file="$bundle/request-ledger.json";;
      selection_ledger) file="$bundle/selection-ledger.json";;
      *) file="$bundle/raw/populations/${name}.json";;
    esac
    case "$name" in
      rate_limit|effective_rules|branch_protection|rulesets) file="$bundle/raw/${name//_/-}.json";;
      manual) file="$bundle/raw/populations/manual.json";;
      release_push) file="$bundle/raw/populations/release_push.json";;
    esac
    expected="$(jq -r --arg key "$name" '.source_sha256[$key] // empty' "$manifest")"
    [[ -n "$expected" && -s "$file" && "$(sha256_file "$file")" == "$expected" ]] || fail "snapshot_hash_mismatch:${name}"
  done
  local source_name source_path source_expected
  while IFS= read -r source_name; do
    source_path="$bundle/source/$source_name"
    source_expected="$(jq -r --arg name "$source_name" '.source_file_sha256[$name]' "$manifest")"
    [[ -s "$source_path" && "$(sha256_file "$source_path")" == "$source_expected" ]] || fail "snapshot_source_file_hash_mismatch:${source_name}"
  done < <(jq -r '.source_file_sha256|keys[]' "$manifest")
  result="$(jq -c '(.comparison_collection != null) as $comparison | {schema_version,repository,workflow,cutoff_utc,captured_at_utc,window_start_utc,status,stop_reason,request_count,source_sha,workflow_sha256,workflow_blob_sha,required_contexts,required_rule_provenance,active_rulesets,source_file_sha256,source_sha256,measured_pr_workflow_sha256,replay_tool_sha256,measured_pr_identity,comparison_families:(.comparison_families // null),source_runs:([.populations|to_entries[]|select(.key=="pull_request" or .key=="push_main" or .key=="schedule") as $pop | $pop.value.runs[]? | {event:$pop.key,id,html_url,head_sha,run_attempt,conclusion,created_at,updated_at,detail_status,workload,changes_docs_only} + (if $comparison then {attempt_jobs,pull_requests,path,run_started_at,queued_at} else {} end) ]|sort_by(.event,.created_at,.id)),populations:{pull_request:{api_total_count:.populations.pull_request.api_total_count,population_capped:.populations.pull_request.population_capped,population_exhausted:.populations.pull_request.population_exhausted,run_count:(.populations.pull_request.runs|length),outcomes:(.populations.pull_request.runs|group_by(.conclusion)|map({key:(.[0].conclusion // "unknown"),value:length})|from_entries)},push_main:{api_total_count:.populations.push_main.api_total_count,population_capped:.populations.push_main.population_capped,population_exhausted:.populations.push_main.population_exhausted,run_count:(.populations.push_main.runs|length),outcomes:(.populations.push_main.runs|group_by(.conclusion)|map({key:(.[0].conclusion // "unknown"),value:length})|from_entries)},schedule:{api_total_count:.populations.schedule.api_total_count,population_capped:.populations.schedule.population_capped,population_exhausted:.populations.schedule.population_exhausted,run_count:(.populations.schedule.runs|length),outcomes:(.populations.schedule.runs|group_by(.conclusion)|map({key:(.[0].conclusion // "unknown"),value:length})|from_entries)},manual_records:(.populations.manual.records|length),release_push_records:(.populations.release_push.records|length)}}' "$manifest")"
  local metrics_file
  metrics_file="$(mktemp "${TMPDIR:-/tmp}/ci-run-metrics-replay.XXXXXX")"
  python3 - "$bundle" "$ROOT" >"$metrics_file" <<'PY'
import datetime, hashlib, json, pathlib, re, subprocess, sys
root = pathlib.Path(sys.argv[1]); project = pathlib.Path(sys.argv[2]); manifest = json.loads((root/'manifest.json').read_text())
sys.path.insert(0, str(project/'scripts'/'ci'))
sys.path.insert(0, str(root/'source'))
from exunit_timing_contract import validate as validate_exunit_timing
from ci_metrics_security import deduplicate_physical_jobs, validate_check_bindings, validate_general_job_identity, validate_producer_binding, validate_producer_commit, validate_workflow_source, verified_failure_log, verify_snapshot_hashes
integrity_errors=verify_snapshot_hashes(root)
if integrity_errors:
    print(json.dumps({'status':'unknown','diagnostics':integrity_errors},sort_keys=True),file=sys.stderr)
    raise SystemExit(1)
approved_required_contexts=['Library tests','Example unit smoke (ExUnit + ConnTest)','Install smoke (fresh phx.new + sigra.install)','Example HTTP smoke (boot + curl critical routes)','Example Playwright smoke (full lifecycle)']
try:
    effective=json.loads((root/'raw'/'effective-rules.json').read_text())
    protection=json.loads((root/'raw'/'branch-protection.json').read_text())
    effective_contexts=sorted({x['context'] for rule in effective if rule.get('type')=='required_status_checks' for x in (rule.get('parameters') or {}).get('required_status_checks',[]) if isinstance(x,dict) and isinstance(x.get('context'),str)})
    branch_contexts=sorted({x for x in protection.get('contexts',[]) if isinstance(x,str)})
    derived_contexts=effective_contexts or branch_contexts
except (OSError,ValueError,TypeError,AttributeError):
    derived_contexts=[]
snapshot_rules_valid=(derived_contexts==sorted(approved_required_contexts)
    and manifest.get('required_contexts')==derived_contexts
    and manifest.get('expected_required_contexts') in (None,approved_required_contexts)
    and manifest.get('required_rules_changed') in (None,False))
events = {'pull_request':'pull_request','push_main':'main','schedule':'nightly'}
stages = ['setup','cache_restore_download','compile','database_startup','app_boot','test_execution','artifact_upload','other']
wait_rows={k:[] for k in events.values()}; runner_rows={k:[] for k in events.values()}; stage_values={k:{s:[] for s in stages} for k in events.values()}
cache={}; images={}; configured={}; observed={}; test_rows=[]; overhead={'playwright':{'status':'unmeasured','overhead_ms':None},'exunit':{'status':'unknown','overhead_us':None}}
instrumentation_baseline={'exunit':{'status':'unknown','source':'.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json'}}
try:
    baseline_path=root/'source'/'252-03-EXUNIT-TIMING.json'
    if not baseline_path.is_file(): baseline_path=project/'.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json'
    baseline=json.loads(baseline_path.read_text())
    if baseline.get('complete') is True:
        instrumentation_baseline['exunit']={'status':'historical_baseline','source':'.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json','observed_at_utc':baseline.get('observed_at_utc'),'instrumentation_overhead_us':baseline.get('instrumentation_overhead_us'),'method':baseline.get('overhead_method'),'samples':baseline.get('samples')}
except (OSError,ValueError): pass
failure_candidates=[]; signature_groups={}; failure_bins={k:[] for k in ['application_test_failure','infrastructure_failure','superseded_cancellation','cancellation_unclassified','expected_skip','unexpected_skip','missing_job','unknown_failure']}; missing_diagnostics=[]
required_wait_candidates=[]; instrumented_full_candidates=[]
def epoch(v):
    if not v: return None
    try: return datetime.datetime.fromisoformat(v.replace('Z','+00:00')).timestamp()
    except (ValueError, TypeError): return None
def result(vals, unit):
    return {'status':'measured','n':len(vals),'unit':unit,'total':round(sum(vals),6),'limitation':'single_observation' if len(vals)==1 else None} if vals else {'status':'unknown','n':0,'unit':unit,'total':None,'reason':'no_complete_source_timestamps'}
def source_bound_full_pr(run, runid):
    """Read current artifact-evidence bundles and bind timings to their producing jobs."""
    if not snapshot_rules_valid:
        return None, ['required_rules_changed_or_unverified']
    family=root/'raw'/'families'/runid
    diagnostics=[]
    try:
        fm=json.loads((family/'manifest.json').read_text())
        run_raw=family/'run.json'
        if not run_raw.is_file() or hashlib.sha256(run_raw.read_bytes()).hexdigest()!=fm.get('source_run_sha256'):
            return None, ['source_run_hash_mismatch']
        evidence_ref=fm.get('artifact_evidence') or {}
        evidence_path=root/evidence_ref.get('path','')
        if not evidence_ref.get('sha256') or not evidence_path.is_file() or hashlib.sha256(evidence_path.read_bytes()).hexdigest()!=evidence_ref.get('sha256'):
            return None, ['artifact_evidence_hash_mismatch']
        evidence=json.loads(evidence_path.read_text())
        checks_path=family/'check-runs.json'
        if not checks_path.is_file() or hashlib.sha256(checks_path.read_bytes()).hexdigest()!=fm.get('check_runs_sha256'):
            return None, ['check_runs_hash_mismatch']
        checks=json.loads(checks_path.read_text()).get('check_runs',[])
        expected_contexts=manifest.get('required_contexts',[])
        refs=run.get('attempt_jobs') or {}
        jobs_by_attempt={}
        for attempt,ref in refs.items():
            jp=family/pathlib.Path(ref.get('path') or '').name
            if not jp.is_file() or hashlib.sha256(jp.read_bytes()).hexdigest()!=ref.get('sha256'): continue
            try: jobs_by_attempt[str(attempt)]=json.loads(jp.read_text()).get('jobs',[])
            except Exception: continue
        latest_attempt=str(run.get('run_attempt') or max([int(x) for x in jobs_by_attempt] or [1]))
        check_errors=validate_check_bindings(run,int(latest_attempt),jobs_by_attempt.get(latest_attempt,[]),checks,expected_contexts)
        diagnostics.extend(check_errors)
        by_name={}
        for check in checks:
            if check.get('head_sha')!=run.get('head_sha') or check.get('app',{}).get('slug')!='github-actions': continue
            by_name[check.get('name')]=check
        endpoints=[by_name.get(name) for name in expected_contexts]
        if check_errors or not expected_contexts or any(not check or check.get('status')!='completed' or check.get('conclusion')!='success' or not epoch(check.get('completed_at')) for check in endpoints):
            diagnostics.append('required_contexts_incomplete_or_unbound')
        else:
            completed=max(epoch(check.get('completed_at')) for check in endpoints)
            created=epoch(run.get('created_at'))
            if created is not None and completed>=created:
                required_wait_candidates.append({'run_id':runid,'attempt':run.get('run_attempt'),'head_sha':run.get('head_sha'),'created_at':run.get('created_at'),'completed_at':max(check.get('completed_at') for check in endpoints),'seconds':round(completed-created,6),'url':run.get('html_url'),'contexts':expected_contexts})
            else: diagnostics.append('required_context_endpoint_invalid')
        files=[]; metadata=[]
        for item in evidence:
            art=item.get('artifact') or {}; accepted=item.get('result') or {}
            if accepted.get('status')!='accepted': continue
            aid=str(art.get('id','')); wf=art.get('workflow_run') or {}
            archive=family/'artifacts'/f'{aid}.zip'
            digest=accepted.get('archive_sha256')
            api_digest=(art.get('digest') or '').removeprefix('sha256:')
            if (not aid or art.get('expired') is not False or str(wf.get('id'))!=runid or wf.get('head_sha')!=run.get('head_sha')
                or not archive.is_file() or not digest or hashlib.sha256(archive.read_bytes()).hexdigest()!=digest
                or (api_digest and api_digest!=digest)):
                diagnostics.append('artifact_origin_or_digest_mismatch'); continue
            # The collector may have recorded an absolute extraction path from
            # its temporary staging directory. That path is not portable after
            # bundling; locate extracted members only under this verified
            # family's numeric artifact ID.
            base=family/'artifacts'/aid
            if not aid.isdigit() or base.resolve().parent != (family/'artifacts').resolve() or not base.is_dir():
                diagnostics.append('artifact_extraction_path_invalid'); continue
            for member in accepted.get('members',[]):
                member_path=pathlib.PurePosixPath(member.get('member',''))
                if not member_path.parts or member_path.is_absolute() or any(part in ('','.','..') for part in member_path.parts): continue
                path=base/member_path
                if not path.is_file(): path=base/member_path.name
                if base.resolve() not in path.resolve().parents: diagnostics.append('artifact_member_path_invalid'); continue
                if not path.is_file(): continue
                files.append((art,path))
                if member_path.name=='ci-measurement-metadata.json':
                    try: meta=json.loads(path.read_text())
                    except Exception: continue
                    try: att=str(int(meta.get('run_attempt',-1)))
                    except (TypeError,ValueError): att='-1'
                    job_name=meta.get('job_name'); seam=meta.get('matrix_seam')
                    expected_job_name=(f'Example Playwright shard ({seam})' if job_name=='Example Playwright shard' and seam else job_name)
                    matching=[j for j in jobs_by_attempt.get(att,[]) if j.get('name')==expected_job_name]
                    valid=(job_name and len(matching)==1 and not validate_producer_binding(run,matching[0],art,meta,expected_job_name)
                        and isinstance(meta.get('source_sha'),str) and re.fullmatch(r'[0-9a-f]{40}',meta.get('source_sha')))
                    if valid: metadata.append((meta,matching[0],art))
                    elif job_name in ('Library tests shard','Example Playwright shard'):
                        diagnostics.append('producer_metadata_not_bound_to_successful_job')
        # Produce five checked Playwright measurements from the pinned native JSON format.
        expected_pw={
          'admin-behavior.json':('admin_behavior','admin-behavior'),
          'admin-checkpoints.json':('admin_checkpoints','admin-checkpoints'),
          'design-gallery-pr-behavior.json':('design_gallery','design-gallery-pr-behavior'),
          'non-admin-smoke.json':('non_admin_smoke','non-admin-smoke'),
          'demo-showcase.json':('demo_showcase','demo-showcase'),
        }
        pw_reports={}; pw_meta={}
        for meta,job,art in metadata:
            if meta.get('job_name')=='Example Playwright shard' and meta.get('matrix_seam'):
                pw_meta[meta.get('matrix_seam')]=(meta,job)
        for art,path in files:
            name=path.name
            if name in expected_pw:
                seam,invocation=expected_pw[name]
                meta_job=pw_meta.get(seam)
                if not meta_job: continue
                meta,job=meta_job
                producer_errors=validate_producer_binding(run,job,art,meta,job.get('name',''))
                if producer_errors:
                    diagnostics.extend(producer_errors)
                    continue
                try: native=json.loads(path.read_text())
                except Exception: native={}
                git_identity=(native.get('config') or {}).get('metadata',{}).get('ci',{})
                if git_identity.get('commitHash')!=meta.get('source_sha') or not str(git_identity.get('prHref','')).endswith('/pull/'+str((run.get('pull_requests') or [{}])[0].get('number',''))):
                    diagnostics.append('playwright_source_identity_mismatch'); continue
                node=root/'source'/'ci-playwright-report.mjs'
                if not node.is_file(): continue
                output=path.with_suffix('.normalized.json')
                proc=subprocess.run(['node',str(node),'--input',str(path),'--seam',seam,'--invocation',invocation,'--output',str(output)],capture_output=True,text=True)
                if proc.returncode==0:
                    try: normalized=json.loads(output.read_text())
                    except Exception: normalized={}
                    if normalized.get('complete') is True:
                        pw_reports[seam]=(normalized,meta,job)
                        for row in normalized.get('tests',[]):
                            test_rows.append({'source':'playwright','identity':f"{runid}:{meta.get('run_attempt')}:{seam}:{row.get('test_id')}:{row.get('retry')}",'run_id':runid,'attempt':meta.get('run_attempt'),'sha':meta.get('source_sha'),'seam':seam,'test_id':row.get('test_id'),'name':row.get('title'),'duration_ms':row.get('duration_ms'),'result':row.get('result'),'unit':'ms'})
                output.unlink(missing_ok=True)
        expected_exunit={'main':'ci-exunit-timing-main.json','threadline_guard':'ci-exunit-timing-threadline-guard.json'}
        exunit_by_invocation={}; exunit_paths={}
        for artifact,path in files:
            if path.name in expected_exunit.values():
                if path.name in exunit_paths: diagnostics.append('duplicate_exunit_timing_report')
                exunit_paths[path.name]=(artifact,path)
        exunit_reports=[]; exunit_payloads={}; exunit_artifact_names={}
        ex_meta=next((m for m,j,_ in metadata if m.get('job_name')=='Library tests shard'),None)
        for invocation,filename in expected_exunit.items():
            artifact_path=exunit_paths.get(filename)
            artifact,path=artifact_path if artifact_path else ({},None)
            report={}
            if path:
                if not ex_meta:
                    diagnostics.append('exunit_producer_metadata_missing')
                    continue
                ex_job=next((j for j in jobs_by_attempt.get(str(ex_meta.get('run_attempt')),[]) if j.get('name')=='Library tests shard'),None)
                if not ex_job or validate_producer_binding(run,ex_job,artifact,ex_meta,ex_job.get('name','')):
                    diagnostics.append('exunit_timing_artifact_not_bound_to_library_job_upload')
                    continue
                try: report=json.loads(path.read_text())
                except Exception: report={}
                exunit_payloads[invocation]=report
                exunit_artifact_names[invocation]=artifact.get('name')
        exunit_validation=validate_exunit_timing(
            ex_meta or {}, exunit_payloads, exunit_artifact_names, runid,
            ex_meta.get('run_attempt') if ex_meta else None,
        )
        diagnostics.extend(exunit_validation['diagnostics'])
        exunit_by_invocation=exunit_validation['normalized']
        exunit_reports=exunit_validation['reports']
        if not ex_meta or int(ex_meta.get('run_attempt',-1)) not in [int(a) for a in refs]: exunit_by_invocation={}
        expected_seams=set(x[0] for x in expected_pw.values())
        if set(pw_reports)!=expected_seams: diagnostics.append('complete_playwright_seam_timing_missing')
        producer_sources={m.get('source_sha') for m,_,_ in metadata if m.get('job_name')=='Library tests shard' or m.get('job_name')=='Example Playwright shard'}
        producer_commit_refs=(fm.get('producer_commits') or {})
        for producer_sha in producer_sources:
            ref=producer_commit_refs.get(producer_sha) or {}
            commit_path=root/ref.get('commit_path','')
            tree_path=root/ref.get('tree_path','')
            workflow_path=root/ref.get('workflow_path','')
            if (not ref.get('commit_sha256') or not commit_path.is_file() or hashlib.sha256(commit_path.read_bytes()).hexdigest()!=ref.get('commit_sha256')
                or not ref.get('tree_sha256') or not tree_path.is_file() or hashlib.sha256(tree_path.read_bytes()).hexdigest()!=ref.get('tree_sha256')
                or not ref.get('workflow_sha256') or not workflow_path.is_file() or hashlib.sha256(workflow_path.read_bytes()).hexdigest()!=ref.get('workflow_sha256')):
                diagnostics.append('producer_merge_commit_evidence_missing')
                continue
            try:
                commit=json.loads(commit_path.read_text())
                tree=json.loads(tree_path.read_text())
            except Exception: diagnostics.append('producer_merge_commit_evidence_invalid'); continue
            diagnostics.extend(validate_producer_commit(producer_sha,commit,run))
            expected_tree_sha=(commit.get('commit') or {}).get('tree',{}).get('sha')
            diagnostics.extend(validate_workflow_source(producer_sha,tree,workflow_path.read_bytes(),ref.get('workflow_sha256'),expected_tree_sha))
        if len(producer_sources)>1:
            diagnostics.append('producer_source_revision_mismatch')
        if diagnostics: return None, sorted(set(diagnostics))
        for invocation,report in exunit_by_invocation.items():
            for row in report.get('tests',[]):
                test_rows.append({'source':'exunit','identity':f"{runid}:{ex_meta.get('run_attempt')}:{invocation}:{row.get('test_id')}",'run_id':runid,'attempt':ex_meta.get('run_attempt'),'sha':ex_meta.get('source_sha'),'invocation':invocation,'test_id':row.get('test_id'),'name':row.get('name'),'duration_us':row.get('duration_us'),'result':row.get('result'),'unit':'microsecond'})
        producer_rows=[(ex_meta,next(j for j in jobs_by_attempt[str(ex_meta['run_attempt'])] if j.get('name')=='Library tests shard'))]
        producer_rows.extend((meta,job) for _,meta,job in pw_reports.values())
        costs=[]; stage={s:0.0 for s in stages}; cache_vector={}; runner_classes=[]; producer_attempts={}
        for meta,job in producer_rows:
            started=epoch(job.get('started_at')); ended=epoch(job.get('completed_at'))
            if started is None or ended is None or ended<started: return None,['producer_job_timing_missing']
            costs.append(round(ended-started,6))
            image=meta.get('runner_image') or {}; runner_classes.append({'os':meta.get('runner_os'),'arch':meta.get('runner_arch'),'image_os':image.get('image_os'),'image_version':image.get('image_version')})
            key=meta.get('job_name')+((':'+str(meta.get('matrix_seam'))) if meta.get('matrix_seam') else '')
            cache_vector[key]=meta.get('cache_outcome') or {}
            producer_attempts[key]={'attempt':int(meta.get('run_attempt')),'job_id':job.get('id'),'source_sha':meta.get('source_sha'),'job_seconds':round(ended-started,6)}
            for step in job.get('steps',[]):
                a,b=epoch(step.get('started_at')),epoch(step.get('completed_at'))
                if a is None or b is None or b<a: continue
                n=(step.get('name') or '').lower()
                bucket=('cache_restore_download' if re.search(r'cache|download|restore',n) else 'compile' if re.search(r'compile|deps|install dependencies',n) else 'database_startup' if re.search(r'database|postgres|mysql',n) else 'app_boot' if re.search(r'boot|start server|application',n) else 'test_execution' if re.search(r'test|playwright|exunit|mix ci',n) else 'artifact_upload' if re.search(r'upload artifact',n) else 'setup' if re.search(r'setup|checkout|install erlang|install elixir|install node',n) else 'other')
                stage[bucket]+=b-a
        run_runner_seconds=0.0; run_attempts=[]
        counted_jobs, physical_history=deduplicate_physical_jobs(jobs_by_attempt)
        counted_ids={(str(row['attempt']),str(row['job'].get('id'))) for row in counted_jobs}
        for attempt,jobs in sorted(jobs_by_attempt.items(),key=lambda item:int(item[0])):
            attempt_rows=[]; attempt_seconds=0.0
            for job in jobs:
                a,b=epoch(job.get('started_at')),epoch(job.get('completed_at')); observed_seconds=round(b-a,6) if a is not None and b is not None and b>=a else None
                counted=(str(attempt),str(job.get('id'))) in counted_ids
                seconds=observed_seconds if counted else (0.0 if observed_seconds is not None else None)
                if seconds is not None: run_runner_seconds+=seconds; attempt_seconds+=seconds
                attempt_rows.append({'job_id':job.get('id'),'name':job.get('name'),'conclusion':job.get('conclusion'),'runner_seconds':seconds,'api_reported_runner_seconds':observed_seconds,'counted_physical_job':counted})
            run_attempts.append({'attempt':int(attempt),'runner_seconds':round(attempt_seconds,6),'jobs':sorted(attempt_rows,key=lambda row:(row['name'] or '',int(row['job_id'] or 0)))})
        exunit_over=exunit_by_invocation.get('main',{}).get('instrumentation_overhead_us')
        pw_over={seam:report.get('reporter_overhead') for seam,(report,_,_) in sorted(pw_reports.items())}
        return {'run_id':runid,'attempt':run.get('run_attempt'),'created_at':run.get('created_at'),'application_revision':run.get('head_sha'),'producer_source_sha':ex_meta.get('source_sha'),'workflow_revision':run.get('head_sha'),'workflow_sha256':None,'source_url':run.get('html_url'),'required_contexts':expected_contexts,'required_result_wait_seconds':required_wait_candidates[-1]['seconds'] if required_wait_candidates and required_wait_candidates[-1]['run_id']==runid else None,'runner_seconds':round(run_runner_seconds,6),'run_attempts':run_attempts,'instrumentation_producer_job_seconds':round(sum(costs),6),'producer_job_count':len(producer_rows),'producer_attempts':producer_attempts,'step_costs':{k:round(v,6) for k,v in stage.items()},'exunit_test_duration_us':sum(x.get('test_duration_sum_us',0) for x in exunit_by_invocation.values()),'exunit_invocations':exunit_reports,'exunit_instrumentation_overhead_us':exunit_over,'playwright_test_duration_ms':sum(r.get('sum_test_duration_ms',0) for r,_,_ in pw_reports.values()),'playwright_reporter_overhead':pw_over,'playwright_seams':sorted(pw_reports),'cache_stratum':cache_vector,'runner_classes':runner_classes,'observed_versions':{'elixir':ex_meta.get('observed_versions',{}).get('elixir'),'node':next((m.get('observed_versions',{}).get('node') for m,j,_ in metadata if m.get('job_name')=='Example Playwright shard'),None),'playwright':next((m.get('observed_versions',{}).get('playwright') for m,j,_ in metadata if m.get('job_name')=='Example Playwright shard'),None)},'configured_versions':{'elixir':ex_meta.get('configured_versions',{}).get('elixir'),'node':next((m.get('configured_versions',{}).get('node') for m,j,_ in metadata if m.get('job_name')=='Example Playwright shard'),None),'playwright':next((m.get('configured_versions',{}).get('playwright') for m,j,_ in metadata if m.get('job_name')=='Example Playwright shard'),None)}},[]
    except (OSError,ValueError,TypeError,KeyError) as error:
        return None,['source_evidence_invalid:'+type(error).__name__]
full_pr_runs=[r for r in manifest.get('populations',{}).get('pull_request',{}).get('runs',[]) if r.get('workload')=='full' and r.get('conclusion')=='success']
latest_instrumented_pr=(max(full_pr_runs,key=lambda r:(r.get('created_at',''),int(r.get('id',0)))).get('id') if full_pr_runs else None)
for pop,key in events.items():
    for run in manifest.get('populations',{}).get(pop,{}).get('runs',[]):
        runid=str(run.get('id','')); created=epoch(run.get('created_at'))
        if manifest.get('repository')!='szTheory/sigra':
            raise SystemExit('snapshot_repository_identity_invalid')
        seen_physical_job_ids=set()
        if run.get('conclusion') in ('failure','timed_out','cancelled','skipped'):
            failure_candidates.append({'event':key,'run':run,'created_epoch':created if created is not None else -1})
        refs=run.get('attempt_jobs') or {}
        for attempt,ref in sorted(refs.items(),key=lambda x:int(x[0])):
            rel=(ref.get('path') or f'raw/families/{runid}/jobs-attempt-{attempt}.json').replace(f'raw/families/{runid}/','')
            jobfile=(root/ref['path']) if manifest.get('comparison_collection') else root/'raw'/'families'/runid/pathlib.Path(rel).name
            if not jobfile.is_file() or hashlib.sha256(jobfile.read_bytes()).hexdigest()!=ref.get('sha256'): continue
            try: jobs=json.loads(jobfile.read_text()).get('jobs',[])
            except Exception: continue
            for job in jobs:
                identity_errors=validate_general_job_identity(run,int(attempt),job,manifest['repository'],request_bound=True)
                if identity_errors:
                    raise SystemExit(','.join(identity_errors))
                jid=str(job.get('id','')); started=epoch(job.get('started_at')); ended=epoch(job.get('completed_at'))
                if not jid or jid in seen_physical_job_ids: continue
                seen_physical_job_ids.add(jid)
                identity=f'{runid}:{attempt}:{jid}'
                if started is not None and ended is not None and ended>=started:
                    duration=ended-started
                    runner_rows[key].append({'identity':identity,'run_id':runid,'attempt':int(attempt),'job_id':jid,'job_name':job.get('name'),'seconds':duration})
                    if created is not None and ended>=created: wait_rows[key].append({'identity':identity,'run_id':runid,'attempt':int(attempt),'job_id':jid,'job_name':job.get('name'),'seconds':ended-created,'queue_seconds':max(0,started-created),'execution_seconds':duration})
                for step in job.get('steps',[]):
                    a,b=epoch(step.get('started_at')),epoch(step.get('completed_at'))
                    if a is None or b is None or b<a or (started is not None and a<started) or (ended is not None and b>ended): continue
                    n=(step.get('name') or '').lower()
                    stage=('cache_restore_download' if re.search(r'cache|download|restore',n) else 'compile' if re.search(r'compile|deps|install dependencies',n) else 'database_startup' if re.search(r'database|postgres|mysql',n) else 'app_boot' if re.search(r'boot|start server|application',n) else 'test_execution' if re.search(r'test|playwright|exunit|mix ci',n) else 'artifact_upload' if re.search(r'upload artifact',n) else 'setup' if re.search(r'setup|checkout|install erlang|install elixir|install node',n) else 'other')
                    stage_values[key][stage].append(b-a)
        # Generic job/API metadata is not producer proof. Cache, runner, runtime,
        # overhead and test claims are populated only by source_bound_full_pr,
        # after the complete artifact/job/upload/source chain has been checked.
        if pop=='pull_request' and run.get('workload')=='full' and run.get('conclusion')=='success' and run.get('id')==latest_instrumented_pr:
            sample,diagnostics=source_bound_full_pr(run,runid)
            if sample:
                instrumented_full_candidates.append(sample)
                overhead['playwright']={'status':'measured','seams':sample.get('playwright_reporter_overhead')}
            elif diagnostics: run['_instrumentation_diagnostics']=diagnostics
failures=[]
for event in events.values():
    candidates=sorted((x for x in failure_candidates if x['event']==event),key=lambda x:(-x['created_epoch'],-int(x['run'].get('id',0))))[:4]
    failures.extend(candidates)
failures=sorted(failures,key=lambda x:(-x['created_epoch'],-int(x['run'].get('id',0))))[:12]
for item in failures:
    run=item['run']; runid=str(run.get('id')); conclusion=run.get('conclusion'); attempt=max([int(x) for x in (run.get('attempt_jobs') or {'1':{}})] or [1])
    family=root/'raw'/'families'/runid; logpath=family/'failed-job.log'; detailpath=family/'manifest.json'; ref=None; diagnostic='missing'
    if logpath.is_file() and detailpath.is_file():
        try:
            detail=json.loads(detailpath.read_text()); logdiag=next((d.get('result',{}) for d in detail.get('artifact_diagnostics',[]) if d.get('kind')=='failed_job_log'),{})
            candidate=logdiag.get('path')
            expected_path=f'raw/families/{runid}/failed-job.log'
            if logdiag.get('status')=='retained_redacted' and candidate==expected_path:
                verified_failure_log(root,candidate,logdiag.get('sha256'))
                ref=candidate; diagnostic='available'
        except Exception: pass
    category='unknown_failure'; signature=None
    if conclusion=='skipped': category='expected_skip' if run.get('workload')=='docs_only' or run.get('observed_expected_skip') is True else 'unexpected_skip'
    elif conclusion=='cancelled': category='superseded_cancellation' if run.get('run_attempt',1)>1 or run.get('superseded_by_run_id') else 'cancellation_unclassified'
    elif conclusion in ('timed_out',): category='infrastructure_failure'
    elif not (run.get('attempt_jobs') or {}): category='missing_job'
    elif ref:
        try: text=verified_failure_log(root,ref,logdiag.get('sha256')).decode('utf-8','replace')
        except Exception: text=''
        if re.search(r'(?i)(expect\(|assertionerror|assert\s+)',text):
            category='application_test_failure'
            match=re.search(r'(?im)^.*(?:expect\(|assertionerror|assert\s+).*$' ,text)
            if match: signature=re.sub(r'\s+',' ',re.sub(r'\d+','<n>',match.group(0))).strip()[:200]
        elif re.search(r'(?i)(network|runner lost|database unavailable|connection refused|timed out)',text): category='infrastructure_failure'
        else: category='unknown_failure'
    else: missing_diagnostics.append({'event':item['event'],'run_id':runid,'attempt':attempt,'missing':'redacted_failed_job_log'})
    entry={'event':item['event'],'run_id':runid,'attempt':attempt,'outcome':conclusion,'failure_class':category,'diagnostics_status':diagnostic,'log_reference':ref}
    failure_bins[category].append(entry); failures_item=entry.copy()
    if signature: signature_groups.setdefault(signature,[]).append({'event':item['event'],'run_id':runid,'attempt':attempt,'log_reference':ref})
    failures_item.pop('event',None)
recurring=[{'signature':sig,'occurrences':len(refs),'references':sorted(refs,key=lambda r:(r['event'],r['run_id'],r['attempt']))} for sig,refs in signature_groups.items() if len(refs)>=2]
recurring=sorted(recurring,key=lambda x:(-x['occurrences'],x['signature']))[:3]
failure_analysis={'inspected_family_count':len(failures),'per_event_counts':{event:sum(1 for x in failures if x['event']==event) for event in events.values()},'families':failures,'failure_class':failure_bins,'failure_signatures':{'status':'recurring_signatures_found' if recurring else ('unknown' if missing_diagnostics else 'no_current_flake_identified'),'signatures':recurring,'missing_inputs':missing_diagnostics,'proposed_repeat_checks':(['repeat the isolated browser selection with readiness diagnostics'] if not recurring else [])},'diagnostics_status':{'status':'unknown' if missing_diagnostics or any(e['failure_class']=='unknown_failure' for rows in failure_bins.values() for e in rows) else 'sufficient','available_count':sum(1 for rows in failure_bins.values() for e in rows if e['diagnostics_status']=='available'),'missing_count':len(missing_diagnostics)}}
for rows in list(wait_rows.values())+list(runner_rows.values()): rows.sort(key=lambda x:(-x['seconds'],x['identity']))
rank=lambda rows: {'status':'measured','n':len(rows),'total_seconds':round(sum(x['seconds'] for x in rows),6),'rows':rows,'limitation':'single_observation' if len(rows)==1 else None} if rows else {'status':'insufficient_data','n':0,'total_seconds':None,'rows':[],'reason':'no_complete_source_timestamps'}
cohorts={}
for name,workload in [('full','full'),('docs_only','docs_only')]:
    eligible=[r for r in manifest['populations']['pull_request']['runs'] if r.get('workload')==workload]
    sampled={x['run_id'] for x in wait_rows['pull_request'] if x['run_id'] in {str(r['id']) for r in eligible}}
    cohorts[name]={'status':'measured' if sampled else 'insufficient_data','n':len(sampled),'run_count':len(eligible),'run_ids':sorted(sampled),'limitation':'single_observation' if len(sampled)==1 else (None if sampled else 'no_complete_source_timestamps')}
observed_defaults={runtime:{'value':None,'reason':'measurement_artifact_unavailable'} for runtime in ['elixir','node','playwright']}
configured_defaults={runtime:None for runtime in ['elixir','node','playwright']}
image_defaults={'runner_os':None,'runner_arch':None,'image_os':None,'image_version':None}
initial_wait={k:rank([{'identity':r['identity'],'run_id':r['run_id'],'attempt':r['attempt'],'seconds':r['queue_seconds']} for r in rows]) for k,rows in wait_rows.items()}
critical_wait={k:rank(rows) for k,rows in wait_rows.items()}
job_execution={k:rank([{'identity':r['identity'],'run_id':r['run_id'],'attempt':r['attempt'],'job_id':r['job_id'],'seconds':r['seconds']} for r in rows]) for k,rows in runner_rows.items()}
out={'ranked_by_wait':{k:rank(v) for k,v in wait_rows.items()},'ranked_by_runner':{k:rank(v) for k,v in runner_rows.items()},'initial_wait':initial_wait,'critical_path_wait':critical_wait,'job_execution':job_execution,'dag_dependency_gaps':{k:{'status':'unknown','n':0,'reason':'dependency_edges_not_exposed_by_saved_job_api'} for k in events.values()},'stage_costs':{k:{s:result(v,'seconds') for s,v in values.items()} for k,values in stage_values.items()},'cache_outcome':cache or {'library_deps':'unknown','example_deps':'unknown','browser_binaries':'unknown'},'runner_image':{k:images.get(k,image_defaults) for k in events.values()},'configured_versions':{k:configured.get(k,configured_defaults) for k in events.values()},'observed_versions':{k:observed.get(k,observed_defaults) for k in events.values()},'test_rows':sorted(test_rows,key=lambda r:r['identity']),'reporter_overhead':overhead,'instrumentation_baseline':instrumentation_baseline,'cohorts':cohorts,'failure_analysis':failure_analysis,'failure_signatures':failure_analysis['failure_signatures'],'diagnostics_status':failure_analysis['diagnostics_status'],'failure_class':failure_bins}
out['required_result_wait']={'status':'unknown','n':0,'seconds':None,'reason':('required_rules_changed_or_unverified' if not snapshot_rules_valid else 'no_complete_source_bound_full_pr_required_check_endpoint')}
out['instrumented_full_pr']={'complete':False,'status':'insufficient_data','diagnostics':['no_source_bound_full_pr_family_has_all_required_contexts_and_both_test_timing_artifacts'],'producing_run_id':None,'source_sha':None,'attempt':None,'job_cost_seconds':None,'step_costs':None,'test_costs':None}
if required_wait_candidates:
    wait=sorted(required_wait_candidates,key=lambda x:(x['created_at'],int(x['run_id'])))[-1]
    out['required_result_wait']={'status':'measured','n':1,'seconds':wait['seconds'],'unit':'seconds','run_id':wait['run_id'],'attempt':wait['attempt'],'source_sha':wait['head_sha'],'source_url':wait['url'],'required_contexts':wait['contexts'],'completed_at':wait['completed_at'],'limitation':'single_observation'}
if instrumented_full_candidates:
    sample=sorted(instrumented_full_candidates,key=lambda x:(x.get('created_at',''),int(x['run_id'])))[-1]
    out['instrumented_full_pr']={'complete':True,'status':'measured','diagnostics':[],'producing_run_id':sample['run_id'],'source_sha':sample['application_revision'],'application_revision':sample['application_revision'],'producer_source_sha':sample['producer_source_sha'],'workflow_revision':sample['workflow_revision'],'workflow_sha256':manifest.get('measured_pr_workflow_sha256'),'source_url':sample['source_url'],'attempt':sample['attempt'],'job_cost_seconds':sample['runner_seconds'],'runner_seconds':sample['runner_seconds'],'run_attempts':sample['run_attempts'],'instrumentation_producer_job_seconds':sample['instrumentation_producer_job_seconds'],'producer_job_count':sample['producer_job_count'],'producer_attempts':sample['producer_attempts'],'step_costs':sample['step_costs'],'test_costs':{'exunit_test_duration_us':sample['exunit_test_duration_us'],'exunit_invocations':sample['exunit_invocations'],'playwright_test_duration_ms':sample['playwright_test_duration_ms']},'exunit_instrumentation':{'identity':'Sigra.TestSupport.CiTimingFormatter/v1','overhead_us':sample['exunit_instrumentation_overhead_us']},'playwright_instrumentation':{'identity':'ci-playwright-report.mjs/playwright-json-1.59.1','overhead':sample['playwright_reporter_overhead']},'playwright_seams':sample['playwright_seams'],'cache_stratum':sample['cache_stratum'],'runner_classes':sample['runner_classes']}
    out['observed_versions']['pull_request']=sample['observed_versions']; out['configured_versions']['pull_request']=sample['configured_versions']; out['cache_outcome']=sample['cache_stratum']; out['runner_image']['pull_request']=sample['runner_classes'][0] if sample['runner_classes'] else image_defaults
    exunit_baseline=instrumentation_baseline.get('exunit',{})
    exunit_overhead=exunit_baseline.get('instrumentation_overhead_us') if exunit_baseline.get('status')=='historical_baseline' else None
    out['reporter_overhead']['exunit']={'status':'measured' if exunit_overhead is not None else 'unmeasured','overhead_us':exunit_overhead,'method':exunit_baseline.get('method'),'source':exunit_baseline.get('source'),'samples':exunit_baseline.get('samples'),'reason':None if exunit_overhead is not None else 'historical_five_pair_baseline_unavailable'}
    out['reporter_overhead']['playwright']={'status':'measured' if any((x or {}).get('status')=='measured' for x in sample['playwright_reporter_overhead'].values()) else 'unmeasured','overhead_ms':None,'per_seam':sample['playwright_reporter_overhead'],'reason':'paired_same_selection_runs_not_recorded'}
else:
    reasons=sorted({d for r in manifest.get('populations',{}).get('pull_request',{}).get('runs',[]) for d in r.get('_instrumentation_diagnostics',[])})
    if reasons: out['instrumented_full_pr']['diagnostics']=reasons
print(json.dumps(out,separators=(',',':')))
PY
  jq --slurpfile metrics "$metrics_file" '. + $metrics[0]' <<<"$result" >"$metrics_file.merged"
  result="$(cat "$metrics_file.merged")"
  rm -f "$metrics_file" "$metrics_file.merged"
  if [[ "$FORMAT" == json ]]; then jq -S . <<<"$result"; else jq -r '[.populations|to_entries[]|[.key,(.value.run_count // .value.records // 0)]|@tsv]|.[]|@tsv' <<<"$result"; fi
}

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

if [[ "$MODE" != "wall" && "$MODE" != "jobspan" ]]; then
  fail "unknown --mode: ${MODE} (expected wall|jobspan)"
fi

if [[ "$BOUNDED_ARTIFACT" == true ]]; then
  [[ -s "$CONTRACT_FILE" && -n "$REQUEST_BUDGET_LEDGER" && -s "$ARTIFACT_JSON" && -s "$RUN_JSON" && -n "$DIAGNOSIS_OUTPUT" && ! -e "$DIAGNOSIS_OUTPUT" ]] || fail "bounded_artifact_inputs_missing"
  validate_artifact_metadata "$ARTIFACT_JSON" "$RUN_JSON" | jq -e '.status=="verified"' >/dev/null || fail "bounded_artifact_origin_invalid"
  API_STARTED="$(date +%s)"; API_TEMP_DIR="$(mktemp -d)"; API_LEDGER="${DIAGNOSIS_OUTPUT}.requests.json"
  api_get rate_limit "$API_TEMP_DIR/rate.json" || fail "bounded_artifact_rate_preflight_blocked"
  artifact_id="$(jq -r '.id' "$ARTIFACT_JSON")"
  api_download_no_follow "https://api.github.com/repos/${REPO}/actions/artifacts/${artifact_id}/zip" "$API_TEMP_DIR/artifact.zip" "artifact:${artifact_id}" || fail "bounded_artifact_download_failed"
  python3 - "$API_TEMP_DIR/artifact.zip" "$ARTIFACT_JSON" <<'PYARTIFACT' || fail "bounded_artifact_digest_invalid"
import hashlib,json,pathlib,sys
expected=json.loads(pathlib.Path(sys.argv[2]).read_text())['digest']
if 'sha256:'+hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest()!=expected: raise SystemExit(1)
PYARTIFACT
  mv "$API_TEMP_DIR/artifact.zip" "$DIAGNOSIS_OUTPUT"
  api_write_ledger complete
  API_COMPLETED=true
  rm -rf "$API_TEMP_DIR"
  exit 0
fi

if [[ "$ASSEMBLE_COMPARISON" == true ]]; then
  [[ -s "$CONTRACT_FILE" && -s "$SOURCE_PAGES" && -n "$SOURCE_BUNDLE" ]] || fail "assembly_requires_contract_snapshot_index_and_new_destination"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$SOURCE_PAGES" "$SOURCE_BUNDLE" <<'PY'
import json,pathlib,hashlib,sys
from ci_metrics_security import assemble_comparison_snapshots
contract=json.loads(pathlib.Path(sys.argv[1]).read_text()); rows=json.loads(pathlib.Path(sys.argv[2]).read_text())
paths=[]
for row in rows:
    root=pathlib.Path(row['path']).resolve()
    if hashlib.sha256((root/'manifest.json').read_bytes()).hexdigest()!=row['manifest_sha256']: raise ValueError('assembly_manifest_digest_invalid')
    paths.append(root)
print(json.dumps(assemble_comparison_snapshots(contract,paths,pathlib.Path(sys.argv[3])),sort_keys=True))
PY
  exit $?
fi

if [[ -n "$FAILED_JOB_ID" ]]; then
  [[ -s "$CONTRACT_FILE" && -s "$FAILED_JOB_RECEIPT" && -n "$REQUEST_BUDGET_LEDGER" && -n "$DIAGNOSIS_OUTPUT" && ! -e "$DIAGNOSIS_OUTPUT" ]] || fail "failed_job_log_inputs_missing"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" "$FAILED_JOB_RECEIPT" "$FAILED_JOB_ID" "$TIMEOUT_ANNOTATIONS" <<'PY' || fail "failed_job_log_identity_invalid"
import json,pathlib,sys
from ci_metrics_security import initialize_comparison_request_budget
c=json.loads(pathlib.Path(sys.argv[1]).read_text()); initialize_comparison_request_budget(c,pathlib.Path(sys.argv[2]))
jobs=json.loads(pathlib.Path(sys.argv[3]).read_text()).get('jobs',[])
matches=[job for job in jobs if str(job.get('id'))==sys.argv[4]]
if len(matches)!=1: raise SystemExit(1)
if matches[0].get('conclusion') not in ('failure','timed_out'):
    if matches[0].get('conclusion')!='cancelled' or not sys.argv[5]: raise SystemExit(1)
    annotations=pathlib.Path(sys.argv[5]); rows=json.loads(annotations.read_text())
    requests=json.loads(pathlib.Path(str(annotations)+'.requests.json').read_text()).get('requests') or []
    endpoint=f'/repos/szTheory/sigra/check-runs/{sys.argv[4]}/annotations'
    if endpoint not in requests or not any(row.get('annotation_level')=='failure' and 'exceeded the maximum execution time' in row.get('message','') for row in rows): raise SystemExit(1)
job=matches[0]; baseline=c['baseline_identity']
if not ((job.get('run_id')==baseline.get('run_id',job.get('run_id')) and job.get('run_attempt')==baseline['preparation_attempt'] and job.get('head_sha')==c['baseline_application_sha'])
        or job.get('head_sha')==c['candidate_identity']['application_sha']): raise SystemExit(1)
PY
  mkdir -p "$(dirname "$DIAGNOSIS_OUTPUT")"
  API_LEDGER="${DIAGNOSIS_OUTPUT}.requests.json"; API_STARTED="$(date +%s)"; API_BUDGET_OWNER="preparation-failed-log"
  API_TEMP_DIR="$(mktemp -d)"
  trap api_cleanup EXIT INT TERM HUP
  api_get rate_limit "$API_TEMP_DIR/rate.json" || fail "failed_job_log_rate_preflight_blocked"
  api_download_no_follow "https://api.github.com/repos/${REPO}/actions/jobs/${FAILED_JOB_ID}/logs" "$API_TEMP_DIR/log" "job-log:${FAILED_JOB_ID}" || fail "failed_job_log_unavailable"
  redact_log_file "$API_TEMP_DIR/log" "$DIAGNOSIS_OUTPUT" full
  api_write_ledger complete; API_COMPLETED=true
  rm -rf "$API_TEMP_DIR"
  trap - EXIT INT TERM HUP
  exit 0
fi

if [[ "$COLLECT_PREPARATION" == true ]]; then
  [[ -s "$CONTRACT_FILE" && -s "$RUN_JSON" && -n "$REQUEST_BUDGET_LEDGER" && -n "$SOURCE_BUNDLE" ]] || fail "preparation_collection_inputs_missing"
  [[ "$COMPARISON_ROLE" == before || "$COMPARISON_ROLE" == after ]] || fail "preparation_role_invalid"
  prep_tmp="$(mktemp -d)"
  COMPARISON_RUNS_FILE="$prep_tmp/early-registration.json"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$RUN_JSON" "$REQUEST_BUDGET_LEDGER" "$COMPARISON_ROLE" "$COMPARISON_RUNS_FILE" <<'PY' || fail "preparation_early_run_identity_invalid"
import json,pathlib,sys
from ci_metrics_security import initialize_comparison_request_budget, _utc
c=json.loads(pathlib.Path(sys.argv[1]).read_text()); run=json.loads(pathlib.Path(sys.argv[2]).read_text()); role=sys.argv[4]
budget=initialize_comparison_request_budget(c,pathlib.Path(sys.argv[3]))
expected=c['baseline_application_sha'] if role=='before' else c['candidate_identity']['application_sha']
prs=run.get('pull_requests') or []; origin=run.get('run_started_at') or run.get('queued_at')
if (run.get('status') not in ('queued','in_progress') or run.get('conclusion') is not None or run.get('head_sha')!=expected
        or run.get('event')!='pull_request' or run.get('path')!='.github/workflows/ci.yml' or len(prs)!=1
        or run.get('repository',{}).get('id')!=1207487684 or not origin or not isinstance(run.get('run_attempt'),int)
        or not budget['started_at_epoch']-5 <= _utc(origin).timestamp() <= budget['started_at_epoch']+3600): raise SystemExit(1)
pr=prs[0]
if pr.get('head',{}).get('sha')!=expected: raise SystemExit(1)
identity=c['baseline_identity'] if role=='before' else c['candidate_identity']
if identity.get('branch'):
    if (run['run_attempt']!=identity.get('preparation_attempt',1) or pr['head'].get('ref')!=identity['branch']
            or pr['base'].get('sha')!=identity['parent_main_sha']): raise SystemExit(1)
elif role=='before' and (run['id']!=identity['run_id'] or run['run_attempt']!=identity['preparation_attempt'] or pr['number']!=331): raise SystemExit(1)
row={'reservation_id':'preparation-'+role,'pair_id':'preparation-only','family_role':role,
     'run_id':run['id'],'run_attempt':run['run_attempt'],'sample_id':f"{run['id']}-attempt-{run['run_attempt']}",
     'head_sha':expected,'created_at':run['created_at'],'attempt_origin_at':origin,'event':run['event'],
     'workflow_path':run['path'],'pull_request_number':pr['number'],'pull_request_head_sha':pr['head']['sha'],
     'pull_request_base_sha':pr['base']['sha']}
pathlib.Path(sys.argv[5]).write_text(json.dumps([row],sort_keys=True,separators=(',',':')))
PY
  COMPARISON_ATTEMPT_SCOPED=true
  COMPARISON_SOURCE_REF="$(jq -r --arg role "$COMPARISON_ROLE" 'if $role=="before" then .baseline_application_sha else .candidate_identity.application_sha end' "$CONTRACT_FILE")"
  CUTOFF="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  API_BUDGET_OWNER="preparation:${COMPARISON_ROLE}"
  collect_window
  cp "$RUN_JSON" "$SOURCE_BUNDLE/preparation-early-run.json"
  cp "$COMPARISON_RUNS_FILE" "$SOURCE_BUNDLE/preparation-registration.json"
  jq '.[0]' "$COMPARISON_RUNS_FILE" >"$prep_tmp/registration.json"
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --mode comparison-family --evidence "$SOURCE_BUNDLE" \
    --registration "$prep_tmp/registration.json" --required-contexts "$(jq -c '.required_contexts' "$CONTRACT_FILE")" >"$SOURCE_BUNDLE/preparation-origin-verification.json"
  rm -rf "$prep_tmp"
  exit 0
fi

if [[ -n "$BOUNDED_REQUEST" ]]; then
  [[ -s "$CONTRACT_FILE" && -n "$REQUEST_BUDGET_LEDGER" && -n "$DIAGNOSIS_OUTPUT" && ! -e "$DIAGNOSIS_OUTPUT" ]] || fail "bounded_request_requires_contract_budget_and_new_output"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$BOUNDED_REQUEST" "$REQUEST_METHOD" "$REQUEST_BODY" "$COMPARISON_ROLE" "$RESERVATION_ID" <<'PY' || fail "bounded_request_not_authorized"
import json,pathlib,re,sys
c=json.loads(pathlib.Path(sys.argv[1]).read_text()); endpoint,method,body,role,reservation_id=sys.argv[2:]
if method=='GET':
    if not (endpoint=='rate_limit' or endpoint.startswith('/repos/szTheory/sigra/')): raise SystemExit(1)
elif method=='PATCH':
    identity=c.get('baseline_identity') if role=='before' else c.get('candidate_identity') if role=='after' else None
    payload=json.loads(pathlib.Path(body).read_text()) if body else {}
    if (not identity or endpoint not in c.get('authorized_mutations',[])
            or endpoint!='/repos/szTheory/sigra/git/refs/heads/'+identity['branch']
            or not identity['branch'].startswith('evidence/phase254-')
            or payload!={'sha':identity['application_sha'],'force':False}): raise SystemExit(1)
elif method=='POST':
    if endpoint not in c.get('authorized_mutations',[]) or not (endpoint=='/repos/szTheory/sigra/pulls' or re.fullmatch(r'/repos/szTheory/sigra/actions/runs/[1-9][0-9]*/rerun',endpoint)): raise SystemExit(1)
    if c.get('sample_identity')=='run_id+run_attempt':
        matches=[row for row in c.get('family_reservations',[]) if row.get('reservation_id')==reservation_id]
        if len(matches)!=1 or body or endpoint!=f"/repos/szTheory/sigra/actions/runs/{matches[0]['run_id']}/rerun" or (role and role!=matches[0]['family_role']): raise SystemExit(1)
    if endpoint.endswith('/pulls'):
        payload=json.loads(pathlib.Path(body).read_text())
        if payload.get('draft') is not True or payload.get('base')!='main' or not payload.get('head','').startswith('evidence/phase254-'): raise SystemExit(1)
        if c.get('preparation_order'):
            identity=c.get('baseline_identity') if role=='before' else c.get('candidate_identity') if role=='after' else None
            if not identity or payload['head']!=identity['branch']: raise SystemExit(1)
else: raise SystemExit(1)
PY
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" <<'PY'
import json,pathlib,sys
from ci_metrics_security import initialize_comparison_request_budget
initialize_comparison_request_budget(json.loads(pathlib.Path(sys.argv[1]).read_text()),pathlib.Path(sys.argv[2]))
PY
  mkdir -p "$(dirname "$DIAGNOSIS_OUTPUT")"
  API_LEDGER="${DIAGNOSIS_OUTPUT}.requests.json"
  API_STARTED="$(date +%s)"; API_BUDGET_OWNER="preparation-driver"
  API_TEMP_DIR="$(mktemp -d)"
  trap api_cleanup EXIT INT TERM HUP
  if [[ "$BOUNDED_REQUEST" != rate_limit ]]; then
    api_get rate_limit "$API_TEMP_DIR/rate.json" || fail "bounded_request_rate_preflight_blocked"
  fi
  if [[ "$REQUEST_METHOD" == PATCH ]]; then
    source_ref_endpoint="${BOUNDED_REQUEST/\/git\/refs\//\/git\/ref\/}"
    api_get "$source_ref_endpoint" "${DIAGNOSIS_OUTPUT}.previous-ref.json" || fail "source_update_previous_ref_unavailable"
    python3 - "$CONTRACT_FILE" "$COMPARISON_ROLE" "${DIAGNOSIS_OUTPUT}.previous-ref.json" <<'PYREF' || fail "source_update_previous_ref_changed_no_update_sent"
import json,pathlib,sys
c=json.loads(pathlib.Path(sys.argv[1]).read_text()); role=sys.argv[2]
identity=c['baseline_identity'] if role=='before' else c['candidate_identity']
previous=json.loads(pathlib.Path(sys.argv[3]).read_text())
if previous.get('object',{}).get('sha')!=identity.get('reviewed_source'): raise SystemExit(1)
PYREF
  fi
  if [[ "$REQUEST_METHOD" == POST ]] && jq -e '.sample_identity=="run_id+run_attempt"' "$CONTRACT_FILE" >/dev/null; then
    [[ -n "$REGISTRATIONS_FILE" && -s "$CAPTURE_RECEIPT_FILE" ]] || fail "measured_trigger_requires_registration_ledger_and_previous_capture_receipt"
    measured_run="$(jq -r --arg rid "$RESERVATION_ID" '.family_reservations[]|select(.reservation_id==$rid)|.run_id' "$CONTRACT_FILE")"
    api_get "/repos/${REPO}/actions/runs/${measured_run}" "${DIAGNOSIS_OUTPUT}.previous-run.json" || fail "measured_trigger_previous_run_unavailable"
    PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$RESERVATION_ID" "$REGISTRATIONS_FILE" "${DIAGNOSIS_OUTPUT}.previous-run.json" "$CAPTURE_RECEIPT_FILE" "$ROOT" <<'PY' || fail "measured_trigger_prerequisite_failed_no_rerun_sent"
import json,pathlib,sys
from ci_metrics_security import validate_next_comparison_trigger
c=json.loads(pathlib.Path(sys.argv[1]).read_text()); registrations=pathlib.Path(sys.argv[3])
validate_next_comparison_trigger(c,sys.argv[2],json.loads(registrations.read_text()) if registrations.exists() else None,
    json.loads(pathlib.Path(sys.argv[4]).read_text()),json.loads(pathlib.Path(sys.argv[5]).read_text()),pathlib.Path(sys.argv[6]))
PY
  fi
  if [[ "$REQUEST_METHOD" == POST || "$REQUEST_METHOD" == PATCH ]]; then
    PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REQUEST_BUDGET_LEDGER" "$BOUNDED_REQUEST" "$REQUEST_BODY" "$COMPARISON_ROLE" "$RESERVATION_ID" <<'PY' || fail "preparation_mutation_already_spent_or_limit_reached"
import hashlib,json,pathlib,sys,time
from ci_metrics_security import _comparison_budget_read,_comparison_budget_append,validate_comparison_pass_reservation
c=json.loads(pathlib.Path(sys.argv[1]).read_text()); path=pathlib.Path(sys.argv[2]); ledger=_comparison_budget_read(path,c)
if c.get('sample_identity')=='run_id+run_attempt': validate_comparison_pass_reservation(c,path,sys.argv[6])
prior=[row for row in ledger['records'] if row.get('kind')=='mutation']
key=sys.argv[6] if c.get('sample_identity')=='run_id+run_attempt' else sys.argv[5] if c.get('preparation_order') else sys.argv[3]
if len(prior)>=c.get('maximum_mutations',0) or any(row.get('mutation_key',row['endpoint'])==key for row in prior): raise SystemExit(1)
if c.get('preparation_order') and (len(prior)>=len(c['preparation_order']) or c['preparation_order'][len(prior)]!=key): raise SystemExit(1)
_comparison_budget_append(path,ledger,{'kind':'mutation','endpoint':sys.argv[3], 'at_epoch':int(time.time()),
    'mutation_key':key,
    'body_sha256':hashlib.sha256(pathlib.Path(sys.argv[4]).read_bytes()).hexdigest() if sys.argv[4] else None})
PY
  fi
  api_get "$BOUNDED_REQUEST" "$DIAGNOSIS_OUTPUT" "$REQUEST_METHOD" "$REQUEST_BODY" || fail "bounded_request_failed_no_mutation_retry"
  api_write_ledger complete
  API_COMPLETED=true
  rm -rf "$API_TEMP_DIR"
  trap - EXIT INT TERM HUP
  exit 0
fi

if [[ "$WATCH_COMPARISON_RUNS" == true ]]; then
  [[ -s "$CONTRACT_FILE" && -s "$REGISTRATIONS_FILE" && -n "$REQUEST_BUDGET_LEDGER" && -n "$WATCH_OUTPUT_DIR" ]] || fail "--watch-comparison-runs requires --contract, --registrations, --request-budget-ledger and --watch-output-dir"
  [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]] || fail "comparison_watcher_requires_repaired_control_pr"
  [[ "$REQUEST_METHOD" == GET ]] || fail "repaired_control_measurement_get_only"
  local_watch_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-comparison-watch.XXXXXX")"
  COMPARISON_RUNS_FILE="$local_watch_tmp/registered-runs.json"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REGISTRATIONS_FILE" "$COMPARISON_ROLE" "$COMPARISON_RUNS_FILE" <<'PY' || { rm -rf "$local_watch_tmp"; fail "comparison_watcher_registration_invalid"; }
import json,pathlib,sys
from ci_metrics_security import comparison_registered_runs
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
ledger=json.loads(pathlib.Path(sys.argv[2]).read_text())
rows=comparison_registered_runs(contract,ledger,sys.argv[3])
pathlib.Path(sys.argv[4]).write_text(json.dumps(rows,sort_keys=True,separators=(',',':')))
PY
  mkdir -p "$WATCH_OUTPUT_DIR"
  API_LEDGER="${WATCH_OUTPUT_DIR}.request-ledger.json"
  API_CONTRACT_SHA256="$(PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" <<'PY'
import json,pathlib,sys
from ci_metrics_security import comparison_contract_sha256
print(comparison_contract_sha256(json.loads(pathlib.Path(sys.argv[1]).read_text())))
PY
)"
  API_STARTED="$(jq -r '.started_at_epoch // empty' "$REQUEST_BUDGET_LEDGER")"; [[ "$API_STARTED" =~ ^[0-9]+$ ]] || API_STARTED="$(date +%s)"
  API_REQUESTS=0; API_STOP_REASON=""; API_RESET_AT=""; API_CORE_REMAINING=""; API_UNKNOWN='[]'; API_REQUEST_LOG='[]'; API_LAST_RATE_REQUEST=0; API_RATE_CHECK_IN_FLIGHT=false; API_TEMP_DIR="$WATCH_OUTPUT_DIR"; API_BUDGET_OWNER="comparison:${COMPARISON_ROLE}:watcher"
  if [[ -s "$API_LEDGER" ]]; then
    jq -e --arg contract "$API_CONTRACT_SHA256" '.contract_sha256==$contract and (.requests|type)=="array"' "$API_LEDGER" >/dev/null || { rm -rf "$local_watch_tmp"; fail "comparison_watcher_ledger_identity_invalid"; }
    API_REQUESTS="$(jq -r '.request_count' "$API_LEDGER")"
    API_REQUEST_LOG="$(jq -c '.requests' "$API_LEDGER")"
    API_CORE_REMAINING="$(jq -r '.core_remaining // empty' "$API_LEDGER")"
    API_RESET_AT="$(jq -r '.reset_or_retry_at // empty' "$API_LEDGER")"
  fi
  trap 'watcher_release_locks' EXIT INT TERM HUP
  watch_comparison_runs
  api_write_ledger complete; API_COMPLETED=true
  watcher_release_locks
  trap - EXIT INT TERM HUP
  rm -rf "$local_watch_tmp"
  exit 0
fi

if [[ "$DIAGNOSE_V1" == true ]]; then
  [[ -f "$SOURCE_BUNDLE" && -f "$BASELINE_FILE" && -n "$DIAGNOSIS_OUTPUT" ]] || fail "--diagnose-v1 requires archived --source-bundle, --baseline and --output"
  diagnosis_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-diagnosis.XXXXXX")"
  trap 'rm -rf "$diagnosis_tmp"' EXIT
  extract_snapshot_bundle "$SOURCE_BUNDLE" "$diagnosis_tmp/bundle" || fail "source_bundle_archive_invalid"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$diagnosis_tmp/bundle" "$SOURCE_BUNDLE" "$BASELINE_FILE" "$DIAGNOSIS_OUTPUT" "$ROOT" <<'PY'
import json, pathlib, subprocess, sys
from ci_metrics_security import diagnose_snapshot
bundle, archive, baseline, output, root = map(pathlib.Path, sys.argv[1:])
result = diagnose_snapshot(bundle, archive, baseline)
result['analyzer'] = {'path': 'scripts/ci/ci_metrics_security.py',
    'source_revision': subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
    'sha256': __import__('hashlib').sha256((root / 'scripts/ci/ci_metrics_security.py').read_bytes()).hexdigest()}
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'status': result['status'], 'records': len(result['records']), 'output': str(output)}))
raise SystemExit(1 if result['source_errors'] else 0)
PY
  exit $?
fi

if [[ "$COLLECT" == true && "$REPLAY" == true ]]; then
  fail "--collect and --replay are mutually exclusive"
fi
if [[ "$VERIFY_BASELINE" == true ]]; then
  [[ -n "$SOURCE_BUNDLE" && -n "$BASELINE_FILE" ]] || fail "--verify-baseline requires --source-bundle and --baseline"
  FORMAT=json
  [[ -s "$BASELINE_FILE" ]] || fail "baseline_missing"
  verify_dir="$SOURCE_BUNDLE"; verify_tmp=""
  if [[ ! -d "$SOURCE_BUNDLE" ]]; then
    verify_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-run-metrics-verify.XXXXXX")"
    verify_tmp="$(cd "$verify_tmp" && pwd -P)"
    extract_snapshot_bundle "$SOURCE_BUNDLE" "$verify_tmp/bundle" || fail "source_bundle_archive_invalid"
    verify_dir="$verify_tmp/bundle"
  fi
  replay_file="$(mktemp "${TMPDIR:-/tmp}/ci-run-metrics-expected.XXXXXX")"
  replay_snapshot "$verify_dir" >"$replay_file"
  python3 - "$verify_dir" "$BASELINE_FILE" "$replay_file" "$SOURCE_BUNDLE" <<'PY'
import datetime, hashlib, json, pathlib, sys
bundle, baseline_path, replay_path, bundle_input = map(pathlib.Path, sys.argv[1:])
baseline = json.loads(baseline_path.read_text()); replay = json.loads(replay_path.read_text())
manifest = json.loads((bundle/'manifest.json').read_text())
expected = ['Library tests','Example unit smoke (ExUnit + ConnTest)','Install smoke (fresh phx.new + sigra.install)','Example HTTP smoke (boot + curl critical routes)','Example Playwright smoke (full lifecycle)']
problems=[]
def fail(reason, detail=None):
    item={'reason':reason}
    if detail is not None: item['detail']=detail
    problems.append(item)
try:
    cutoff=datetime.datetime.fromisoformat(manifest['cutoff_utc'].replace('Z','+00:00'))
    captured=datetime.datetime.fromisoformat(manifest['captured_at_utc'].replace('Z','+00:00'))
    now=datetime.datetime.now(datetime.timezone.utc)
    if cutoff > captured or captured > now + datetime.timedelta(minutes=5) or now-cutoff > datetime.timedelta(days=30): fail('cutoff_not_current')
except Exception: fail('cutoff_invalid')
if manifest.get('status') != 'complete': fail('source_snapshot_incomplete',manifest.get('stop_reason'))
baseline_for_compare=baseline.copy(); bundle_hash=baseline_for_compare.pop('source_bundle_sha256',None)
if not isinstance(bundle_hash,str) or not bundle_hash: fail('source_bundle_hash_missing')
elif not bundle_input.is_file() or hashlib.sha256(bundle_input.read_bytes()).hexdigest()!=bundle_hash: fail('source_bundle_hash_mismatch')
if baseline_for_compare != replay: fail('baseline_replay_mismatch')
if sorted(manifest.get('required_contexts') or []) != sorted(expected) or manifest.get('required_rules_changed') is True or manifest.get('required_context_source') not in (None,'effective_rules','branch_protection'): fail('required_context_set_changed',manifest.get('required_contexts'))
provenance=manifest.get('required_rule_provenance') or []
if {x.get('context') for x in provenance} != set(expected) or (manifest.get('required_context_source') in (None,'effective_rules') and any(not isinstance(x.get('ruleset_id'),int) for x in provenance)) or (manifest.get('required_context_source')=='branch_protection' and any(x.get('source')!='branch_protection' for x in provenance)): fail('required_context_provenance_incomplete')
for event,key in [('pull_request','pull_request'),('main_push','push_main'),('nightly','schedule')]:
    pop=manifest.get('populations',{}).get(key,{})
    if (pop.get('api_total_count') or 0)>0:
        if not any(r.get('detail_status')=='complete' and r.get('attempt_jobs') for r in pop.get('runs',[])):
            fail('event_has_no_complete_family',event)
if replay.get('cohorts',{}).get('full',{}).get('n',0)<1: fail('full_pr_measurement_missing')
if replay.get('instrumented_full_pr',{}).get('complete') is not True: fail('instrumented_full_pr_incomplete',replay.get('instrumented_full_pr',{}).get('diagnostics'))
if replay.get('required_result_wait',{}).get('status') != 'measured': fail('required_result_wait_unavailable')
if replay.get('instrumentation_baseline',{}).get('exunit',{}).get('status') not in ('historical_baseline','measured'): fail('exunit_overhead_unavailable')
if replay.get('reporter_overhead',{}).get('playwright',{}).get('status') not in ('measured','unmeasured'): fail('playwright_overhead_disclosure_missing')
print(json.dumps({'status':'ready' if not problems else 'insufficient_data','source_sha':manifest.get('source_sha'),'cutoff_utc':manifest.get('cutoff_utc'),'diagnostics':problems},sort_keys=True))
raise SystemExit(0 if not problems else 1)
PY
  verify_rc=$?
  rm -f "$replay_file"
  [[ -z "$verify_tmp" ]] || rm -rf "$verify_tmp"
  exit "$verify_rc"
fi
if [[ "$VALIDATE_COMPARISON_PLAN" == true ]]; then
  [[ -s "$CONTRACT_FILE" ]] || fail "--validate-comparison-plan requires --contract"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$REGISTRATIONS_FILE" <<'PY'
import json, pathlib, sys
from ci_metrics_security import validate_comparison_plan, validate_comparison_schedule
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
issues=validate_comparison_plan(contract)
if sys.argv[2]:
    ledger=json.loads(pathlib.Path(sys.argv[2]).read_text())
    issues.extend(validate_comparison_schedule(contract,ledger.get('records') or []))
print(json.dumps({'status':'valid' if not issues else 'invalid','diagnostics':sorted(set(issues))},sort_keys=True))
raise SystemExit(0 if not issues else 1)
PY
  exit $?
fi
if [[ "$COLLECT_COMPARISON" == true ]]; then
  [[ "$COLLECT" != true && "$EVALUATE_COMPARISON" != true && "$REGISTER_COMPARISON_RUN" != true ]] || fail "--collect-comparison cannot be combined with other collector modes"
  if [[ -s "$CONTRACT_FILE" ]] && [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    [[ "$REQUEST_METHOD" == GET ]] || fail "repaired_control_measurement_get_only"
  fi
  collect_comparison
  exit 0
fi
if [[ "$EVALUATE_COMPARISON" == true ]]; then
  [[ -s "$CONTRACT_FILE" && -d "$BEFORE_BUNDLE" && -d "$AFTER_BUNDLE" ]] || fail "--evaluate-comparison requires --contract and extracted --before-bundle/--after-bundle directories"
  if [[ "$(jq -r '.comparison_kind // empty' "$CONTRACT_FILE")" == repaired_control_pr ]]; then
    [[ "$REQUEST_METHOD" == GET ]] || fail "repaired_control_measurement_get_only"
  fi
  FORMAT=json
  before_json="$(mktemp "${TMPDIR:-/tmp}/ci-comparison-before.XXXXXX")"
  after_json="$(mktemp "${TMPDIR:-/tmp}/ci-comparison-after.XXXXXX")"
  replay_snapshot "$BEFORE_BUNDLE" >"$before_json"
  replay_snapshot "$AFTER_BUNDLE" >"$after_json"
  PYTHONPATH="$ROOT/scripts/ci" python3 - "$CONTRACT_FILE" "$before_json" "$after_json" "$REGISTRATIONS_FILE" "$BASELINE_SOURCE_BUNDLE" "$BEFORE_BUNDLE" "$AFTER_BUNDLE" "$ROOT" <<'PY'
import datetime, hashlib, json, math, pathlib, subprocess, sys
from ci_metrics_security import derive_comparison_family_costs, validate_comparison_reservations
contract, before, after = map(lambda p: json.loads(pathlib.Path(p).read_text()), sys.argv[1:4])
registrations = json.loads(pathlib.Path(sys.argv[4]).read_text()) if sys.argv[4] else None
baseline_bundle_path=pathlib.Path(sys.argv[5]) if sys.argv[5] else None
bundle_paths={'before':pathlib.Path(sys.argv[6]),'after':pathlib.Path(sys.argv[7])}
project_root=pathlib.Path(sys.argv[8]).resolve()
issues=[]; families=[]; paired=[]
native_parity={'status':'insufficient_data','comparisons':[]}
def issue(code, detail=None):
    row={'reason':code}
    if detail is not None: row['detail']=detail
    issues.append(row)
if contract.get('status') != 'ready': issue('contract_not_ready',contract.get('status'))
if contract.get('pair_count') != 20 or contract.get('primary_family_count') != 40: issue('contract_sample_size_invalid')
if contract.get('window_duration_hours') != 48: issue('contract_window_invalid')
expected_bundle=(contract.get('baseline_identity') or {}).get('source_bundle_sha256')
if not expected_bundle:
    issue('baseline_source_bundle_identity_missing')
elif baseline_bundle_path is None or not baseline_bundle_path.is_file():
    issue('baseline_source_bundle_required')
elif hashlib.sha256(baseline_bundle_path.read_bytes()).hexdigest()!=expected_bundle:
    issue('baseline_source_bundle_hash_mismatch')
before_identity=before.get('measured_pr_identity') or {}
after_identity=after.get('measured_pr_identity') or {}
candidate=contract.get('candidate_identity') or {}
if not candidate.get('application_sha') or not candidate.get('workflow_revision') or not candidate.get('workload_revision_sha256') or not candidate.get('workflow_file_sha256'): issue('candidate_identity_not_predeclared')
if before_identity.get('application_sha') != contract.get('baseline_application_sha'): issue('before_source_identity_mismatch')
if before_identity.get('workflow_file_sha256') != contract.get('baseline_workflow_sha256'): issue('before_workflow_identity_mismatch')
if before_identity.get('workload_revision_sha256') != contract.get('baseline_workload_revision_sha256'): issue('before_workload_identity_mismatch')
if after_identity.get('application_sha') != candidate.get('application_sha'): issue('after_source_identity_mismatch')
if after_identity.get('workflow_revision') != candidate.get('workflow_revision'): issue('after_workflow_revision_mismatch')
if after_identity.get('workflow_file_sha256') != candidate.get('workflow_file_sha256'): issue('after_workflow_identity_mismatch')
if after_identity.get('workload_revision_sha256') != candidate.get('workload_revision_sha256'): issue('after_workload_identity_mismatch')
window=contract.get('window') or {}
try:
    window_start=datetime.datetime.fromisoformat(window['start_utc'].replace('Z','+00:00'))
    window_end=datetime.datetime.fromisoformat(window['end_utc'].replace('Z','+00:00'))
    if window_end-window_start != datetime.timedelta(hours=48): issue('comparison_window_duration_mismatch')
except Exception: issue('comparison_window_not_predeclared')
source_runs=(before.get('source_runs') or [])+(after.get('source_runs') or [])
reservation_issues=validate_comparison_reservations(contract,(before.get('comparison_families') or [])+(after.get('comparison_families') or []),source_runs,registrations)
for code in reservation_issues: issue(code)
if registrations:
    registration_by_run={str(row.get('run_id')):row for row in registrations.get('records',[])}
    origin_results=[]
    for label, data in [('before',before),('after',after)]:
        for row in data.get('comparison_families') or []:
            registration=(
                (next((candidate for candidate in registrations.get('records',[]) if candidate.get('reservation_id')==row.get('reservation_id')),None)
                 if row.get('reservation_id') else None)
                or next((candidate for candidate in registrations.get('records',[]) if str(candidate.get('run_id'))==str(row.get('run_id'))
                         and candidate.get('run_attempt')==row.get('run_attempt')),None)
                or registration_by_run.get(str(row.get('run_id'))))
            if registration is None:
                issue(label+'_family_registration_missing',row.get('run_id')); continue
            if contract.get('comparison_kind')=='repaired_control_pr':
                registration={**registration,'comparison_kind':'repaired_control_pr'}
            result=subprocess.run([sys.executable,str(project_root/'scripts/ci/ci-hosted-gate-verify.py'),
                '--mode','comparison-family','--evidence',str(bundle_paths[label]),
                '--registration-json',json.dumps(registration,separators=(',',':')),
                '--required-contexts',json.dumps(contract.get('required_contexts') or []),
                '--required-app-ids',json.dumps(contract.get('required_check_apps') or {})],capture_output=True,text=True)
            if result.returncode:
                issue(label+'_independent_origin_verification_failed',{'run_id':row.get('run_id'),'error':result.stderr.strip()[:500]})
            else: origin_results.append(json.loads(result.stdout))
    available_families=sum(len(data.get('comparison_families') or []) for data in (before,after))
    native_parity['origins_verified']=len(origin_results)
    native_parity['origin_status']='passed' if available_families and len(origin_results)==available_families else 'insufficient_data'
else:
    issue('comparison_registrations_missing_for_origin_verification')
before_rows={r.get('pair_id'):r for r in (before.get('comparison_families') or []) if r.get('family_role')=='before'}
after_rows={r.get('pair_id'):r for r in (after.get('comparison_families') or []) if r.get('family_role')=='after'}
coverage=contract.get('native_coverage_comparison') or {}
mapping_relative=coverage.get('mapping_path'); mapping_digest=coverage.get('mapping_sha256')
try:
    mapping_path=(project_root/mapping_relative).resolve()
    if project_root not in mapping_path.parents or not mapping_path.is_file() or hashlib.sha256(mapping_path.read_bytes()).hexdigest()!=mapping_digest:
        raise ValueError('mapping_path_digest_or_scope_invalid')
    mapping=json.loads(mapping_path.read_text())
    owners={'admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase'}
    mapping_rows=mapping.get('rows',[])
    expected_owner_counts={'admin_behavior':43,'admin_checkpoints':3,'design_gallery':42,'non_admin_smoke':16,'demo_showcase':4}
    if mapping.get('schema_version')!='sigra.browser-coverage-map/v1' or len(mapping_rows)!=108 or {row.get('owner') for row in mapping_rows}!=owners or {owner:sum(row.get('owner')==owner for row in mapping_rows) for owner in owners}!=expected_owner_counts:
        raise ValueError('mapping_schema_or_owner_coverage_invalid')
    native_results=[]
    with __import__('tempfile').TemporaryDirectory(prefix='sigra-native-parity-') as native_tmp:
        native_tmp=pathlib.Path(native_tmp)
        for pair_id in sorted(set(before_rows)&set(after_rows)):
            b,a=before_rows[pair_id],after_rows[pair_id]
            for owner in sorted(owners):
                owner_rows=[row for row in mapping_rows if row.get('owner')==owner]
                if not owner_rows: raise ValueError(f'mapping_owner_rows_missing:{owner}')
                owner_map=native_tmp/f'{pair_id}-{owner}.json'
                owner_map.write_text(json.dumps({'schema_version':'sigra.browser-coverage-map/v1','rows':owner_rows},separators=(',',':')))
                native_dirs=[]
                for label,family_row in [('before',b),('after',a)]:
                    raw_sample_id=(f"{family_row.get('run_id')}-attempt-{family_row.get('run_attempt')}" if contract.get('sample_identity')=='run_id+run_attempt' else str(family_row.get('run_id')))
                    family_dir=bundle_paths[label]/'raw'/'families'/raw_sample_id/'artifacts'
                    descriptors=list(family_dir.rglob('coverage-source.json')) if family_dir.is_dir() else []
                    matches=[]
                    for descriptor in descriptors:
                        try: doc=json.loads(descriptor.read_text())
                        except (OSError,ValueError): continue
                        if doc.get('owner')==owner and doc.get('seam')==owner: matches.append((descriptor.parent,doc))
                    if len(matches)!=1: raise ValueError(f'{label}_native_descriptor_count:{pair_id}:{owner}:{len(matches)}')
                    native_dir,descriptor=matches[0]
                    raw_run=json.loads((bundle_paths[label]/'raw'/'families'/raw_sample_id/'run.json').read_text())
                    if descriptor.get('source_sha')!=raw_run.get('head_sha'):
                        raise ValueError(f'{label}_native_descriptor_source_mismatch:{pair_id}:{owner}')
                    native_dirs.append(native_dir)
                result=subprocess.run(['node',str(project_root/'scripts/ci/ci-browser-records.mjs'),'--compare-coverage',
                    '--before-directory',str(native_dirs[0]),'--after-directory',str(native_dirs[1]),'--mapping',str(owner_map)],capture_output=True,text=True)
                if result.returncode: raise ValueError(f'coverage_comparator:{pair_id}:{owner}:{result.stderr.strip()[:300]}')
                native_results.append({'pair_id':pair_id,'owner':owner,'result':json.loads(result.stdout)})
    available_pairs=len(set(before_rows)&set(after_rows))
    if not available_pairs or len(native_results)!=available_pairs*5: raise ValueError(f'native_comparison_count:{len(native_results)}')
    native_parity['pairs_compared']=available_pairs
    native_parity['comparisons']=native_results
    native_parity['status']='passed'
except Exception as error:
    native_parity['diagnostic']=str(error)
    issue('native_coverage_parity_unverified',str(error))
# Cost is incurred by observed runs, including failed or unpaired runs whose
# successful-comparison family was never materialized. Reservations that have
# not actually been registered are not observations and incur no assumed cost.
cost_observations={}; attempt_scoped=contract.get('sample_identity')=='run_id+run_attempt'
def observe_cost(label, row):
    run_id=row.get('run_id'); attempt=row.get('run_attempt') if attempt_scoped else None
    key=(str(run_id),attempt)
    if key in cost_observations:
        saved_label,saved=cost_observations[key]
        if saved_label!=label: issue('cost_observation_role_conflict',{'run_id':run_id,'run_attempt':attempt})
        return saved
    if contract.get('comparison_schedule'):
        if not str(run_id).isdigit() or (attempt_scoped and (type(attempt) is not int or attempt<1)):
            raw={'status':'unknown','runner_seconds':None,'runner_known_subtotal_seconds':0,
                 'diagnostics':['cost_observation_identity_invalid']}
        else:
            records=(registrations or {}).get('records') or []
            origin_registration=next((item for item in records if item.get('reservation_id')==row.get('reservation_id')),None)
            if origin_registration is None:
                origin_registration=next((item for item in records if str(item.get('run_id'))==str(run_id)
                    and (not attempt_scoped or item.get('run_attempt')==attempt)),None)
            raw=derive_comparison_family_costs(bundle_paths[label],run_id,
                contract.get('required_contexts') or [],run_attempt=attempt,
                repaired=contract.get('comparison_kind')=='repaired_control_pr',registration=origin_registration,
                expected_app_ids=contract.get('required_check_apps') if contract.get('comparison_kind')=='repaired_control_pr' else None)
    else:
        raw={**row,'status':'complete'}
    observed={**row,**raw,'family_role':label,'run_id':run_id,'run_attempt':attempt,
              'cost_status':raw.get('status'),'raw_attempt_costs':raw.get('attempt_costs',[])}
    cost_observations[key]=(label,observed)
    if observed.get('runner_seconds') is None:
        issue(label+'_observed_runner_cost_unknown',{'run_id':run_id,'run_attempt':attempt,
              'known_subtotal_seconds':observed.get('runner_known_subtotal_seconds',0),
              'diagnostics':raw.get('diagnostics') or raw.get('runner_diagnostics') or []})
    return observed
for label,data in [('before',before),('after',after)]:
    for row in data.get('comparison_families') or []: observe_cost(label,row)
for row in (registrations or {}).get('records') or []:
    if row.get('family_role') in bundle_paths: observe_cost(row['family_role'],row)
for label, data in [('before',before),('after',after)]:
    if data.get('status') != 'complete': issue(label+'_snapshot_incomplete')
    rows=data.get('comparison_families')
    if not isinstance(rows,list): issue(label+'_family_inputs_missing'); continue
    if len(rows) != 20: issue(label+'_family_count',len(rows))
    seen=set()
    for row in rows:
        if contract.get('comparison_schedule'):
            raw=observe_cost(label,row)
            if raw.get('cost_status')!='complete': issue(label+'_raw_family_invalid',{'run_id':row.get('run_id'),'diagnostics':raw.get('diagnostics')}); continue
            row={**row,'created_at':raw.get('created_at'),'conclusion':raw.get('conclusion'),
                 'required_result_wait_seconds':raw.get('required_result_wait_seconds'),
                 'pull_request_number':raw.get('pull_request_number'),'pull_request_merge_sha':raw.get('pull_request_merge_sha'),
                 'runner_seconds':raw.get('runner_seconds'),'runner_known_subtotal_seconds':raw.get('runner_known_subtotal_seconds'),
                 'runner_unknown_jobs':raw.get('runner_unknown_jobs'),'raw_attempt_costs':raw.get('attempt_costs'),
                 'required_context_missing':raw.get('missing_required_contexts')}
            if raw.get('runner_diagnostics') or raw.get('runner_unknown_jobs'):
                issue(label+'_family_runner_cost_unknown',{'run_id':row.get('run_id'),'known_subtotal_seconds':raw.get('runner_known_subtotal_seconds'),'unknown_jobs':raw.get('runner_unknown_jobs'),'diagnostics':raw.get('runner_diagnostics')})
            if raw.get('required_result_wait_seconds') is None:
                issue(label+'_family_required_wait_unknown',{'run_id':row.get('run_id'),'missing_contexts':raw.get('missing_required_contexts'),'diagnostics':raw.get('wait_diagnostics')})
        if contract.get('sample_identity')=='run_id+run_attempt' or contract.get('comparison_kind')=='repaired_control_pr':
            expected_source_workload=contract.get('baseline_workload_revision_sha256') if label=='before' else candidate.get('workload_revision_sha256')
            if row.get('source_workload_revision_sha256')!=expected_source_workload or row.get('workload_sha')!=expected_source_workload:
                issue(label+'_family_source_workload_identity_mismatch',row.get('sample_id'))
            if row.get('coverage_map_sha256')!=mapping_digest:
                issue(label+'_family_coverage_map_identity_mismatch',row.get('sample_id'))
        ident=(row.get('pair_id'),row.get('family_role'))
        if ident in seen: issue(label+'_duplicate_family',ident)
        seen.add(ident); families.append((label,row))
        if row.get('family_role') not in ('before','after'): issue(label+'_invalid_family_role',ident)
        if row.get('conclusion') != 'success': issue(label+'_family_not_successful',{'identity':ident,'conclusion':row.get('conclusion')})
        if not isinstance(row.get('required_result_wait_seconds'),(int,float)) or not isinstance(row.get('runner_seconds'),(int,float)): issue(label+'_family_cost_missing',ident)
        attempts=row.get('attempts',[])
        retries=[a for a in attempts if a.get('retry') is True]
        if len(retries)>1 or any(a.get('classification')!='infrastructure_failure' or not a.get('diagnosed') for a in retries): issue(label+'_retry_policy_violation',ident)
    if len(seen)!=20: issue(label+'_unique_family_count',len(seen))
before_rows={r.get('pair_id'):r for label,r in families if label=='before' and r.get('family_role')=='before'}
after_rows={r.get('pair_id'):r for label,r in families if label=='after' and r.get('family_role')=='after'}
if set(before_rows)!=set(after_rows) or len(before_rows)!=20: issue('pair_identity_mismatch')
for pair_id in sorted(set(before_rows)&set(after_rows)):
    b,a=before_rows[pair_id],after_rows[pair_id]
    # Source revisions differ by design; actual useful-work equivalence is also
    # independently proven above by the complete native coverage comparison.
    identity_field='coverage_map_sha256' if contract.get('sample_identity')=='run_id+run_attempt' or contract.get('comparison_kind')=='repaired_control_pr' else 'workload_sha'
    fields=['workload',identity_field,'runner_class','runner_image','cache_stratum','exunit_instrumentation','playwright_instrumentation']
    if contract.get('comparison_kind')=='repaired_control_pr':
        fields.append('cache_components')
        eligibility=contract.get('cache_eligibility') or {}
        role_keys=eligibility.get('expected_keys') or {}
        default_ref=eligibility.get('default_branch_ref')
        if not isinstance(default_ref,str) or not default_ref.startswith('refs/heads/'):
            issue('repaired_cache_default_branch_identity_missing',pair_id)
        for side,row in [('before',b),('after',a)]:
            cache=row.get('cache_key_scope')
            owners={'library','admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase'}
            expected_by_owner=role_keys.get(side) or {}
            if not isinstance(cache,dict) or set(cache)!=owners or set(expected_by_owner)!=owners:
                issue(side+'_repaired_cache_owner_evidence_incomplete',pair_id)
            else:
                expected_ref=f"refs/pull/{row.get('pull_request_number')}/merge"
                eligible=set(row.get('eligible_cache_scopes') or [])
                eligible.add(default_ref)
                eligible.add(expected_ref)
                components={}
                for owner in sorted(owners):
                    values=cache.get(owner)
                    expected_components=expected_by_owner.get(owner)
                    if not isinstance(values,dict) or set(values)!=set(expected_components or {}):
                        issue(side+'_repaired_cache_component_set_invalid',{'pair_id':pair_id,'owner':owner})
                        continue
                    components[owner]=sorted(values)
                    for component,value in values.items():
                        if (not isinstance(value,dict) or value.get('cache_hit') is not True or value.get('exact_key') is not True
                                or value.get('fallback_used') is True or value.get('restore_kind')=='fallback'
                                or value.get('matched_cache_key')!=expected_components.get(component)
                                or value.get('ref')!=expected_ref or value.get('scope') not in eligible
                                or not isinstance(value.get('conditions'),list) or not value.get('conditions')):
                            issue(side+'_repaired_cache_identity_or_eligibility_invalid',{'pair_id':pair_id,'owner':owner,'component':component})
                row['cache_components']=components
    mismatch=[field for field in fields if b.get(field)!=a.get(field)]
    if 'runner_image' in mismatch: issue('runner_image_drift',{'pair_id':pair_id,'before':b.get('runner_image'),'after':a.get('runner_image')})
    if mismatch: issue('pair_not_equivalent',{'pair_id':pair_id,'fields':mismatch}); continue
    paired.append((pair_id,b,a))
    if b.get('conclusion')!='success' or a.get('conclusion')!='success': continue
    if not isinstance(b.get('required_result_wait_seconds'),(int,float)) or not isinstance(a.get('required_result_wait_seconds'),(int,float)): continue
    if not isinstance(b.get('runner_seconds'),(int,float)) or not isinstance(a.get('runner_seconds'),(int,float)): continue
comparable_pairs=[(b,a) for _,b,a in paired if b.get('conclusion')=='success' and a.get('conclusion')=='success'
    and isinstance(b.get('required_result_wait_seconds'),(int,float))
    and isinstance(a.get('required_result_wait_seconds'),(int,float))
    and isinstance(b.get('runner_seconds'),(int,float))
    and isinstance(a.get('runner_seconds'),(int,float))]
wait_before=[b['required_result_wait_seconds'] for b,a in comparable_pairs]
wait_after=[a['required_result_wait_seconds'] for b,a in comparable_pairs]
def observed_total(label):
    rows=[row for side,row in cost_observations.values() if side==label]
    known=sum(row.get('runner_known_subtotal_seconds',row.get('runner_seconds') or 0) for row in rows)
    total=None if any(row.get('runner_seconds') is None for row in rows) else sum(row['runner_seconds'] for row in rows)
    return total,known
runner_before,runner_before_known=observed_total('before')
runner_after,runner_after_known=observed_total('after')
def median(xs):
    xs=sorted(xs); n=len(xs)
    return (xs[(n-1)//2]+xs[n//2])/2 if n else None
def p95(xs):
    xs=sorted(xs); return xs[math.ceil(.95*len(xs))-1] if xs else None
if len(paired)!=20 or len(wait_before)!=20: issue('insufficient_equivalent_successful_pairs',len(wait_before))
allocations=contract.get('cache_stratum_allocation') or []
if not allocations: issue('cache_stratum_allocation_missing')
else:
    expected_alloc={str(row.get('stratum_id')):row.get('pair_count') for row in allocations}
    actual_alloc={}
    for _,b,_ in paired: actual_alloc[str(b.get('cache_stratum'))]=actual_alloc.get(str(b.get('cache_stratum')),0)+1
    if actual_alloc!=expected_alloc: issue('cache_stratum_allocation_mismatch',{'expected':expected_alloc,'actual':actual_alloc})
metrics={'pair_count':len(paired),'comparable_successful_pairs':len(wait_before),'baseline_median_seconds':median(wait_before),'candidate_median_seconds':median(wait_after),'baseline_p95_seconds':p95(wait_before),'candidate_p95_seconds':p95(wait_after),'baseline_runner_seconds':runner_before,'candidate_runner_seconds':runner_after,'baseline_runner_known_subtotal_seconds':runner_before_known,'candidate_runner_known_subtotal_seconds':runner_after_known,'family_attempt_costs':[{'pair_id':row.get('pair_id'),'family_role':side,'run_id':row.get('run_id'),'run_attempt':row.get('run_attempt'),'conclusion':row.get('conclusion'),'cost_status':row.get('cost_status'),'runner_seconds':row.get('runner_seconds'),'known_subtotal_seconds':row.get('runner_known_subtotal_seconds',row.get('runner_seconds')),'unknown_jobs':row.get('runner_unknown_jobs',[]),'attempts':row.get('raw_attempt_costs',[])} for side,row in cost_observations.values()],'p95_method':'nearest-rank ceil(0.95*n); for n=20 this is sorted value 19','overhead_disclosure':contract.get('instrumentation_overhead'),'native_parity':native_parity}
performance_verdict='pass' if len(wait_before)==20 and median(wait_after)<=.8*median(wait_before) and p95(wait_after)<=p95(wait_before) and runner_after is not None and runner_before is not None and runner_after<=runner_before else ('miss' if len(wait_before)==20 else 'insufficient_data')
if not issues and len(wait_before)==20:
    verdict='pass' if performance_verdict=='pass' and native_parity.get('status')=='passed' and native_parity.get('origin_status')=='passed' else 'miss' if performance_verdict=='miss' else 'insufficient_data'
else: verdict='insufficient_data'
print(json.dumps({'status':verdict,'performance_verdict':performance_verdict,'metrics':metrics,'diagnostics':issues},sort_keys=True))
PY
  rc=$?
  rm -f "$before_json" "$after_json"
  exit "$rc"
fi
if [[ "$COLLECT_PRODUCER_SOURCE" == true ]]; then
  collect_producer_source
  exit 0
fi
if [[ "$REGISTER_COMPARISON_RUN" == true ]]; then
  register_comparison_run
  exit 0
fi
if [[ "$PREFLIGHT" == true ]]; then
  run_preflight
  exit $?
fi
if [[ "$COLLECT" == true ]]; then
  if [[ -n "$CUTOFF" ]]; then collect_window; else collect_family; fi
  exit 0
fi
if [[ "$REPLAY" == true ]]; then
  [[ -n "$SOURCE_BUNDLE" ]] || fail "--replay requires --source-bundle"
  replay_dir="$SOURCE_BUNDLE"; replay_tmp=""
  if [[ ! -d "$SOURCE_BUNDLE" ]]; then
    replay_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-run-metrics-replay.XXXXXX")"
    replay_tmp="$(cd "$replay_tmp" && pwd -P)"
    extract_snapshot_bundle "$SOURCE_BUNDLE" "$replay_tmp/bundle" || fail "source_bundle_archive_invalid"
    replay_dir="$replay_tmp/bundle"
  fi
  if [[ "$(jq -r '.schema_version // empty' "$replay_dir/manifest.json" 2>/dev/null || true)" == "sigra.ci-run-metrics/snapshot-v1" ]]; then
    if [[ -n "$BASELINE_FILE" ]]; then
      [[ ! -e "$BASELINE_FILE" ]] || fail "baseline_output_already_exists"
      replay_snapshot "$replay_dir" >"$BASELINE_FILE.tmp"
      mv "$BASELINE_FILE.tmp" "$BASELINE_FILE"
    else replay_snapshot "$replay_dir"; fi
    [[ -z "$replay_tmp" ]] || rm -rf "$replay_tmp"
    exit 0
  fi
  if [[ -z "$RUN_ID" ]]; then RUN_ID="$(jq -r '.run_id // empty' "$SOURCE_BUNDLE/manifest.json" 2>/dev/null || true)"; fi
  [[ -n "$RUN_ID" ]] || fail "source manifest has no run id"
  replay_family "$SOURCE_BUNDLE" "$FORMAT"
  exit 0
fi
if [[ -n "$REDIRECT_TO_VALIDATE" ]]; then
  validate_download_redirect "$REDIRECT_TO_VALIDATE"
  exit $?
fi
if [[ -n "$ARTIFACT_JSON" || -n "$RUN_JSON" ]]; then
  [[ -n "$ARTIFACT_JSON" && -n "$RUN_JSON" ]] || fail "artifact validation requires --validate-artifact-json and --run-json"
  validate_artifact_metadata "$ARTIFACT_JSON" "$RUN_JSON"
  exit 0
fi
if [[ -n "$ARCHIVE_PATH" ]]; then
  [[ -n "$ARCHIVE_OUTPUT" && -s "$ARCHIVE_PATH" ]] || fail "timing ZIP validation requires --output-dir and an existing archive"
  extract_timing_archive "$ARCHIVE_PATH" "$ARCHIVE_OUTPUT"
  exit $?
fi
if [[ -n "$LOG_TO_REDACT" || -n "$REDACTED_OUTPUT" ]]; then
  [[ -n "$LOG_TO_REDACT" && -n "$REDACTED_OUTPUT" && -s "$LOG_TO_REDACT" ]] || fail "log redaction requires --redact-log and --redacted-output with an existing input"
  redact_log_file "$LOG_TO_REDACT" "$REDACTED_OUTPUT"
  exit $?
fi

if [[ -z "$SOURCE_PAGES" ]] && ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI not found on PATH"
fi

if [[ -n "$SOURCE_PAGES" ]]; then
  [[ "$MODE" == "wall" ]] || fail "source-pages requires --mode wall"
  [[ "$FORMAT" == "json" ]] || fail "source-pages requires --format json"
  [[ "$EVENT" == "pull_request" ]] || fail "source-pages requires --event pull_request"
  [[ -n "$SINCE" && -n "$UNTIL" ]] || fail "source-pages requires --since and --until"
  [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || fail "threshold must be a non-negative integer"
  [[ -s "$SOURCE_PAGES" ]] || fail "source_pages_missing_or_empty"

  jq -e --arg since "$SINCE" --arg until "$UNTIL" '
    . as $s |
    $s.resource == "GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs" and
    $s.query.created == ($since + ".." + $until) and $s.query.per_page == 100 and
    ($s.requested_pages | type == "array" and length == ($s.pages | length) and . == [range(1; length + 1)]) and
    ([$s.pages[].page] == $s.requested_pages) and
    $s.terminal_page == ($s.requested_pages[-1]) and $s.exhausted == true and
    ($s.pages | type == "array" and length > 0) and
    all($s.pages[]; (.page | type) == "number" and
      (.returned_count | type) == "number" and (.runs | type) == "array" and .returned_count == (.runs | length)) and
    all($s.pages[0:-1][]; .returned_count > 0) and
    ($s.pages[-1].returned_count == 0) and
    all($s.pages[].runs[];
      (.run_id | type) == "number" and (.url | type) == "string" and (.url | length) > 0 and
      (.event | type) == "string" and
      ((.conclusion == null) or ((.conclusion | type) == "string" and (.conclusion | length) > 0)) and
      (.created_at | type) == "string" and (.updated_at | type) == "string") and
    ([$s.pages[].runs[].run_id] | length == (unique | length))
  ' "$SOURCE_PAGES" >/dev/null || fail "source_pages_shape_invalid"

  SOURCE_RESULT="$(jq -e --arg since "$SINCE" --arg until "$UNTIL" --argjson threshold "$THRESHOLD" '
    [.pages[].runs[]
      | select(.event == "pull_request" and (.conclusion | type) == "string" and (.conclusion | length) > 0)
      | select(.created_at >= $since and .created_at <= $until)
      | (((.created_at | fromdateiso8601) // error("created_at_invalid")) as $created
        | ((.updated_at | fromdateiso8601) // error("updated_at_invalid")) as $updated
        | if $updated < $created then error("run_chronology_invalid") else . end
        | . + {wall_seconds: ($updated - $created)})]
    | sort_by(.wall_seconds, .run_id) as $runs
    | ($runs | length) as $n
    | if $n < 10 then
        {runs:$runs, eligible_pr_run_count:$n, statistics:null, selected_poles:null,
         verdict:null, status:"insufficient_population",
         diagnostics:["requires_at_least_10_terminal_pull_request_runs"]}
      else
        ($runs[($n / 2 | floor)]) as $median
        | ($runs[-1]) as $maximum
        | (($runs | map(.wall_seconds) | add) / $n) as $mean
        | {runs:$runs, eligible_pr_run_count:$n,
           statistics:{mode:"wall",ordering:"{wall_seconds, run_id}",mean_seconds:$mean,
             p50_seconds:$median.wall_seconds,max_seconds:$maximum.wall_seconds,
             outcomes:($runs | group_by(.conclusion) | map({key:.[0].conclusion,value:length}) | from_entries)},
           selected_poles:{median_run_id:$median.run_id,maximum_run_id:$maximum.run_id},
           verdict:(if $n < 10 then null elif $median.wall_seconds < $threshold then "pass" else "miss" end),
           status:(if $n < 10 then "insufficient_population" else "measured" end),
           diagnostics:(if $n < 10 then ["requires_at_least_10_terminal_pull_request_runs"] else [] end)}
      end
    | {schema_version:"sigra.ci-run-metrics/source-pages-v1",mode:"wall",event:"pull_request",
       since:$since,until:$until,threshold_seconds:$threshold} + .
  ' "$SOURCE_PAGES")" || fail "source_pages_semantics_invalid"
  printf '%s\n' "$SOURCE_RESULT" | jq -S .
  exit 0
fi

# ---------------------------------------------------------------------------
# Single-run mode: --jobs <run_id>
# ---------------------------------------------------------------------------
if [[ -n "$RUN_ID" ]]; then
  JOBS_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs --jq '.jobs')" || fail "gh run view failed for run ${RUN_ID}"

  JOB_COUNT="$(echo "$JOBS_JSON" | jq 'length')"
  if [[ -z "$JOB_COUNT" || "$JOB_COUNT" -eq 0 ]]; then
    fail "run ${RUN_ID} has an empty job list"
  fi

  DURATION_JQ='
    .[] as $j
    | (($j.completedAt|fromdate) - ($j.startedAt|fromdate)) as $raw
    | (if $raw < 0 then 0 else $raw end) as $dur
  '

  case "$FORMAT" in
    json)
      echo "$JOBS_JSON" | jq "[ ${DURATION_JQ} | {name: \$j.name, conclusion: \$j.conclusion, duration_seconds: \$dur} ]"
      ;;
    table)
      {
        printf 'job\tconclusion\tduration_s\tduration\n'
        echo "$JOBS_JSON" | jq -r "
          ${DURATION_JQ}
          | (\$dur / 60 | floor) as \$m
          | (\$dur - (\$m * 60)) as \$s
          | \"\(\$j.name)\t\(\$j.conclusion)\t\(\$dur)s\t\(\$m)m\(\$s)s\"
        "
      } | column -t -s $'\t'
      ;;
  esac
  exit 0
fi

# ---------------------------------------------------------------------------
# Window mode: baseline-reproduction (no --jobs)
# ---------------------------------------------------------------------------
RUNS_JSON="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$LIMIT" --json databaseId,event,createdAt,updatedAt,conclusion)" || fail "gh run list failed"

RUN_COUNT="$(echo "$RUNS_JSON" | jq 'length')"
if [[ -z "$RUN_COUNT" || "$RUN_COUNT" -eq 0 ]]; then
  fail "run list is empty (workflow=${WORKFLOW}, limit=${LIMIT})"
fi

FILTERED_RUNS="$RUNS_JSON"
if [[ -n "$SINCE" ]]; then
  FILTERED_RUNS="$(echo "$FILTERED_RUNS" | jq --arg since "$SINCE" 'map(select(.createdAt >= $since))')"
fi
if [[ -n "$EVENT" ]]; then
  FILTERED_RUNS="$(echo "$FILTERED_RUNS" | jq --arg event "$EVENT" 'map(select(.event == $event))')"
fi

FILTERED_COUNT="$(echo "$FILTERED_RUNS" | jq 'length')"
if [[ -z "$FILTERED_COUNT" || "$FILTERED_COUNT" -eq 0 ]]; then
  fail "no runs remain after --since/--event filtering (workflow=${WORKFLOW}, limit=${LIMIT})"
fi

if [[ "$MODE" == "wall" ]]; then
  ENTRIES="$(echo "$FILTERED_RUNS" | jq '
    [.[] | (((.updatedAt|fromdate) - (.createdAt|fromdate)) as $raw
      | (if $raw < 0 then 0 else $raw end)) as $dur
    | {event: .event, conclusion: .conclusion, duration: $dur}]
  ')"
else
  # jobspan: one `gh run view --json jobs` round-trip per run in the (already
  # since/event-filtered) window.
  ENTRIES="[]"
  while IFS= read -r row; do
    id="$(echo "$row" | jq -r '.databaseId')"
    ev="$(echo "$row" | jq -r '.event')"
    concl="$(echo "$row" | jq -r '.conclusion')"
    JOBS_FOR_RUN="$(gh run view "$id" --repo "$REPO" --json jobs)" || fail "gh run view failed for run ${id} (jobspan sweep)"
    dur="$(echo "$JOBS_FOR_RUN" | jq '
      (.jobs | map(.completedAt|fromdate) | max) as $maxc
      | (.jobs | map(.startedAt|fromdate) | min) as $mins
      | (($maxc - $mins) as $raw | if $raw < 0 then 0 else $raw end)
    ')" || fail "empty or malformed job list for run ${id} (jobspan sweep)"
    ENTRIES="$(echo "$ENTRIES" | jq --arg event "$ev" --arg conclusion "$concl" --argjson duration "$dur" '. + [{event: $event, conclusion: $conclusion, duration: $duration}]')"
  done < <(echo "$FILTERED_RUNS" | jq -c '.[]')
fi

STATS="$(echo "$ENTRIES" | jq '
  group_by(.event) | map({
    trigger: .[0].event,
    n: length,
    durations: (map(.duration) | sort),
    pass: (map(select(.conclusion == "success")) | length)
  } | . + {
    fail: (.n - .pass),
    mean: ((.durations | add) / .n),
    p50: (.durations[(.n / 2 | floor)]),
    max: (.durations | max)
  })
')"

case "$FORMAT" in
  json)
    echo "$STATS" | jq '[.[] | {trigger, n, mean_seconds: .mean, p50_seconds: .p50, max_seconds: .max, pass, fail}]'
    ;;
  table)
    {
      printf '| trigger | n | mean | p50 | max | outcomes |\n'
      printf '| --- | --- | --- | --- | --- | --- |\n'
      echo "$STATS" | jq -r '.[] | [.trigger, .n, .mean, .p50, .max, .pass, .fail] | @tsv' \
        | while IFS=$'\t' read -r trigger n mean p50 max passn failn; do
            mean_m=$(awk -v s="$mean" 'BEGIN{printf "%.1f", s/60}')
            p50_m=$(awk -v s="$p50" 'BEGIN{printf "%.1f", s/60}')
            max_m=$(awk -v s="$max" 'BEGIN{printf "%.1f", s/60}')
            printf '| %s | %s | %sm | %sm | %sm | %s pass / %s fail |\n' \
              "$trigger" "$n" "$mean_m" "$p50_m" "$max_m" "$passn" "$failn"
          done
    }
    ;;
esac
