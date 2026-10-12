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
SOURCE_PAGES=""
UNTIL=""
THRESHOLD=720
COLLECT=false
REPLAY=false
EVALUATE_COMPARISON=false
CONTRACT_FILE=""
BEFORE_BUNDLE=""
AFTER_BUNDLE=""
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
BASELINE_FILE=""
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
  if [[ "$API_COMPLETED" != true ]]; then api_write_ledger incomplete; fi
  [[ -n "$API_TEMP_DIR" && -d "$API_TEMP_DIR" ]] && rm -rf "$API_TEMP_DIR"
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
    --replay) REPLAY=true; shift;;
    --evaluate-comparison) EVALUATE_COMPARISON=true; shift;;
    --contract) CONTRACT_FILE="$2"; shift 2;;
    --before-bundle) BEFORE_BUNDLE="$2"; shift 2;;
    --after-bundle) AFTER_BUNDLE="$2"; shift 2;;
    --preflight) PREFLIGHT=true; shift;;
    --preflight-output) PREFLIGHT_OUTPUT="$2"; shift 2;;
    --run-id) RUN_ID="$2"; shift 2;;
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
import json, os, pathlib, re, stat, sys, zipfile
archive, destination = sys.argv[1:]
max_total, max_member, max_members = 512 * 1024 * 1024, 64 * 1024 * 1024, 10000
allowed = {"report.json", "playwright-report.json", "test-results.json", "timing.json", "ci-timing.json", "metrics.json", "manifest.json", "ci-measurement-metadata.json", "ci-exunit-timing.json", "admin-behavior.json", "admin-checkpoints.json", "design-gallery-pr-behavior.json", "design-gallery-nonpr-snapshots.json", "design-gallery-nonpr-behavior.json", "non-admin-smoke.json", "demo-showcase.json"}
try:
    os.makedirs(destination, exist_ok=True)
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        if len(infos) > max_members: raise ValueError("archive_member_limit_exceeded")
        total, seen, selected, skipped = 0, set(), [], []
        for info in infos:
            name = info.filename
            if "\\" in name or name.startswith("/") or re.match(r"^[A-Za-z]:", name): raise ValueError("unsafe_archive_path")
            if any(part in ("..", "") for part in pathlib.PurePosixPath(name).parts): raise ValueError("unsafe_archive_path")
            mode = (info.external_attr >> 16) & 0xffff
            if stat.S_ISLNK(mode): raise ValueError("archive_symlink_rejected")
            if info.is_dir(): continue
            if info.file_size > max_member: raise ValueError("archive_member_limit_exceeded")
            total += info.file_size
            if total > max_total: raise ValueError("archive_total_limit_exceeded")
            if name in seen: raise ValueError("duplicate_archive_member")
            seen.add(name)
            if pathlib.PurePosixPath(name).name.lower() not in allowed:
                if pathlib.PurePosixPath(name).suffix.lower() == ".json": raise ValueError("unexpected_archive_json")
                skipped.append(pathlib.PurePosixPath(name).name[:128])
                continue
            selected.append(info)
        if not selected: raise ValueError("expected_timing_json_missing")
        used, output = set(), []
        for info in selected:
            basename = pathlib.PurePosixPath(info.filename).name
            if basename in used: raise ValueError("duplicate_archive_basename")
            used.add(basename)
            target = os.path.join(destination, basename); temp = target + ".tmp"; written = 0
            with zf.open(info) as src, open(temp, "wb") as dst:
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk: break
                    written += len(chunk)
                    if written > max_member or total - info.file_size + written > max_total: raise ValueError("archive_expansion_limit_exceeded")
                    dst.write(chunk)
            if written != info.file_size: raise ValueError("archive_member_size_mismatch")
            with open(temp, "rb") as f: json.load(f)
            os.replace(temp, target); output.append({"member":info.filename,"path":target,"bytes":written})
        print(json.dumps({"status":"accepted","members":output,"skipped_non_json_members":skipped[:100]}, sort_keys=True))
except Exception as exc:
    print(str(exc) if isinstance(exc, ValueError) else "archive_invalid", file=sys.stderr)
    raise SystemExit(1)
PY
}

redact_log_file() {
  local source="$1" destination="$2"
  python3 - "$source" "$destination" <<'PY'
import pathlib, re, sys
source, destination = map(pathlib.Path, sys.argv[1:])
text = source.read_bytes().decode("utf-8", "replace")
for pattern, replacement in [
    (r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b", "[REDACTED_TOKEN]"),
    (r"(?i)\bBearer\s+[^\s,;]+", "Bearer [REDACTED]"),
    (r"(?i)\b(?:gh[_-]?token|github[_-]?(?:token|pat)|aws[_-]?(?:access[_-]?key[_-]?id|secret[_-]?access[_-]?key)|client[_-]?secret|access[_-]?token|refresh[_-]?token|private[_-]?key)\s*[:=]\s*[^\s,\"']+", "[REDACTED_CREDENTIAL]"),
    (r"(?i)\b(token|secret|password|api[_-]?key)\s*[:=]\s*[^\s,\"']+", r"\1=[REDACTED]"),
    (r"https?://[^\s?#]+\?[^\s#]+", "[SIGNED_URL_REDACTED]"),
]:
    text = re.sub(pattern, replacement, text)
destination.parent.mkdir(parents=True, exist_ok=True)
temp = destination.with_suffix(destination.suffix + ".tmp")
temp.write_text(text, encoding="utf-8")
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
  ((API_REQUESTS+=1))
  API_REQUEST_LOG="$(jq -cn --arg endpoint "$endpoint" --argjson prior "$API_REQUEST_LOG" '$prior + [$endpoint]')"
  api_write_ledger collecting
}

api_download_no_follow() {
  local url="$1" destination="$2" category="$3" token="" host host_kind headers body status_code location location_count elapsed timeout_cmd attempt rc
  [[ "$url" == https://api.github.com/* ]] || { api_stop download_api_origin_rejected "" "$category"; return 1; }
  if [[ -n "${GH_TOKEN:-}" ]]; then token="$GH_TOKEN"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then token="$GITHUB_TOKEN"
  else token="$(gh auth token 2>/dev/null || true)"; fi
  [[ -n "$token" ]] || { api_stop download_auth_unavailable "" "$category"; return 1; }
  host_kind=api
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
        status_code="$(printf 'header = "Authorization: Bearer %s"\n' "$token" | "$timeout_cmd" --signal=TERM "${request_timeout}s" curl --config - --silent --show-error --max-redirs 0 --request GET --max-time "$request_timeout" --dump-header "$headers" --output "$body" --write-out '%{http_code}' "$url" 2>/dev/null)"
      else
        status_code="$("$timeout_cmd" --signal=TERM "${request_timeout}s" curl --silent --show-error --max-redirs 0 --request GET --max-time "$request_timeout" --dump-header "$headers" --output "$body" --write-out '%{http_code}' "$url" 2>/dev/null)"
      fi
      rc=$?
      set -e
      if (( rc != 0 )); then status_code=000; fi
      [[ "$status_code" =~ ^[0-9]{3}$ ]] || status_code=000
      if [[ "$status_code" == 403 || "$status_code" == 429 ]]; then
        location="$(awk 'BEGIN{IGNORECASE=1} tolower($1)=="retry-after:"||tolower($1)=="x-ratelimit-reset:" {gsub("\\r",""); print $2; exit}' "$headers" 2>/dev/null || true)"
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
    --arg reset_at "$API_RESET_AT" --argjson request_count "$API_REQUESTS" \
    --argjson unknown_inputs "$API_UNKNOWN" --argjson requests "$API_REQUEST_LOG" \
    '{status:$status,request_count:$request_count,stop_reason:(if $stop_reason=="" then null else $stop_reason end),reset_or_retry_at:(if $reset_at=="" then null else $reset_at end),unknown_inputs:$unknown_inputs,requests:$requests}' \
    >"${API_LEDGER}.tmp" && mv "${API_LEDGER}.tmp" "$API_LEDGER" && { sync "$API_LEDGER" 2>/dev/null || sync 2>/dev/null || true; }
}

api_stop() {
  API_STOP_REASON="$1"
  [[ -n "${2:-}" ]] && API_RESET_AT="$2"
  API_UNKNOWN="$(jq -cn --arg reason "$1" --arg endpoint "${3:-unknown}" '[{reason:$reason,endpoint:$endpoint}]')"
  api_write_ledger incomplete
  return 1
}

api_get() {
  local endpoint="$1" output_file="$2" response rc attempt err_file elapsed remaining reset timeout_cmd
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
    ((API_REQUESTS+=1))
    API_REQUEST_LOG="$(jq -cn --arg endpoint "$endpoint" --argjson prior "$API_REQUEST_LOG" '$prior + [$endpoint]')"
    err_file="${TMPDIR:-/tmp}/ci-run-metrics-gh-error.$$"
    local request_timeout=$((3600-elapsed))
    (( request_timeout > 30 )) && request_timeout=30
    (( request_timeout > 0 )) || { api_stop time_limit_exhausted "" "$endpoint"; return 1; }
    set +e
    "$timeout_cmd" --signal=TERM "${request_timeout}s" gh api --method GET "$endpoint" >"${output_file}.tmp" 2>"$err_file"
    rc=$?
    set -e
    response="$(cat "$err_file" 2>/dev/null || true)"
    rm -f "$err_file"
    API_LAST_ERROR="$response"
    if (( rc == 0 )); then
      mv "${output_file}.tmp" "$output_file"
      if [[ "$endpoint" == "rate_limit" || "$endpoint" == "/rate_limit" ]]; then
        API_CORE_REMAINING="$(jq -r '.resources.core.remaining // empty' "$output_file" 2>/dev/null || true)"
        API_RESET_AT="$(jq -r '.resources.core.reset // empty' "$output_file" 2>/dev/null || true)"
        API_LAST_RATE_REQUEST="$API_REQUESTS"
      fi
      api_write_ledger collecting
      return 0
    fi
    rm -f "${output_file}.tmp"
    if [[ "$response" =~ (HTTP[[:space:]]+)?(403|429) ]]; then
      reset="$(printf '%s' "$response" | sed -nE 's/.*(retry-after|x-ratelimit-reset)[^0-9]*([0-9]+).*/\2/ip' | head -1)"
      [[ -n "$reset" ]] && API_RESET_AT="$reset"
      api_stop http_rate_limit "$API_RESET_AT" "$endpoint"
      return 1
    fi
    if (( attempt == 0 )) && [[ "$response" =~ (HTTP[[:space:]]+)?(500|502|503|504)|timed[[:space:]]out|connection[[:space:]]reset|temporary[[:space:]]failure ]]; then
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

collect_window() {
  [[ "$REPO" == "szTheory/sigra" ]] || fail "collect_repo_mismatch"
  [[ "$WORKFLOW" == "ci.yml" ]] || fail "collect_workflow_mismatch"
  [[ -n "$SOURCE_BUNDLE" && -n "$CUTOFF" ]] || fail "window_collect_requires_cutoff_and_source_bundle"
  [[ "$CUTOFF" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || fail "cutoff_must_be_utc_rfc3339"
  jq -en --arg cutoff "$CUTOFF" 'try ($cutoff|fromdateiso8601) catch false' >/dev/null || fail "cutoff_invalid"
  [[ ! -e "$SOURCE_BUNDLE" ]] || fail "source_bundle_already_exists"

  local lock="${SOURCE_BUNDLE}.lock" stage="${SOURCE_BUNDLE}.staging" tmp since cutoff_epoch total_count page page_file page_count selected_json selected_count population_name event branch endpoint runs_json capped exhausted stop_reason detail_note manifest_status workflow_sha workflow_blob tree_sha request_hash selection_hash request_count manual_json release_json source_hashes required_contexts required_provenance active_rules
  mkdir -p "$(dirname "$SOURCE_BUNDLE")"
  [[ ! -e "$stage" ]] || fail "source_bundle_staging_exists"
  mkdir "$lock" 2>/dev/null || fail "source_bundle_locked"
  printf '{"pid":%s,"started_at":"%s"}\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$lock/owner.json"
  mkdir -p "$stage/raw/populations"
  mkdir -p "$stage/source"
  cp "$ROOT/.github/workflows/ci.yml" "$stage/source/ci.yml"
  cp "$ROOT/scripts/ci/ci-run-metrics.sh" "$stage/source/ci-run-metrics.sh"
  cp "$ROOT/scripts/ci/ci-playwright-report.mjs" "$stage/source/ci-playwright-report.mjs"
  cp "$ROOT/scripts/ci/ci-playwright-report.test.mjs" "$stage/source/ci-playwright-report.test.mjs"
  cp "$ROOT/test/support/ci_timing_formatter.ex" "$stage/source/ci_timing_formatter.ex"
  cp "$ROOT/test/test_helper.exs" "$stage/source/test_helper.exs"
  cp "$ROOT/test/example/priv/playwright/playwright.config.ts" "$stage/source/playwright.config.ts"
  cp "$ROOT/test/example/priv/playwright/package-lock.json" "$stage/source/playwright-package-lock.json"
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
    local p=1 total='' response returned filtered valid
    local selected_file="$tmp/${name}-selected.json" filtered_file="$tmp/${name}-filtered.json" pages_file="$tmp/${name}-pages.json"
    printf '[]\n' >"$selected_file"
    printf '[]\n' >"$pages_file"
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
    local selected failed priority all_rows row id event run attempts attempt needed family_dir jobs_file jobs_status attempts_json paths_status paths_json pr_number docs_flag docs_rule skip_seen workload details_json details_file enrichments='[]' reserve=108 max_attempt measurement_target
    local selected_file="$tmp/all-selected-runs.json" failed_file="$tmp/failed-selected-runs.json" priority_file="$tmp/prioritized-runs.json" enrichments_file="$tmp/family-enrichments.json"
    jq -cn --slurpfile pr "$stage/raw/populations/pull_request.json" --slurpfile push "$stage/raw/populations/push_main.json" --slurpfile night "$stage/raw/populations/schedule.json" '[($pr[0].runs[]|{population:"pull_request",run:.}),($push[0].runs[]|{population:"push_main",run:.}),($night[0].runs[]|{population:"schedule",run:.})]' >"$selected_file"
    jq -c '[.[] | select(.run.conclusion=="failure") | select(.population=="pull_request" or .population=="push_main" or .population=="schedule")] | sort_by(.run.created_at) | reverse | .[0:12]' "$selected_file" >"$failed_file"
    measurement_target="$(jq -r '[.[] | select(.population=="pull_request" and .run.conclusion=="success")] | sort_by(.run.created_at) | reverse | .[0].run.id // empty' "$selected_file")"
    jq -cn --arg target "$measurement_target" --slurpfile failed "$failed_file" --slurpfile selected "$selected_file" '
      ($selected[0] | sort_by(.run.created_at) | reverse) as $ordered |
      ([($ordered | map(select(.population=="pull_request" and (.run.id|tostring)==$target)) | .[0]),($ordered | map(select(.population=="push_main" and .run.conclusion=="success")) | .[0]),($ordered | map(select(.population=="schedule" and .run.conclusion=="success")) | .[0])] | map(select(.!=null)) | unique_by([.population,.run.id])) as $anchors |
      ($selected[0] | .[0:3]) as $recent |
      ($anchors + $recent + $failed[0]) | unique_by([.population,.run.id])
    ' "$selected_file" >"$priority_file"
    printf '[]\n' >"$enrichments_file"
    while IFS= read -r row; do
      [[ -n "$row" ]] || continue
      id="$(jq -r '.run.id' <<<"$row")"
      event="$(jq -r '.run.event' <<<"$row")"
      run="$(jq -c '.run' <<<"$row")"
      attempts="$(jq -r '.run.run_attempt // 1' <<<"$row")"
      if [[ ! "$id" =~ ^[0-9]+$ || ! "$attempts" =~ ^[1-9][0-9]*$ ]] || (( attempts > 100 )); then
        jq -cn --slurpfile prior "$enrichments_file" --argjson id "${id:-0}" '$prior[0] + [{run_id:$id,detail_status:"invalid_run_attempt_count",attempt_jobs:{},changed_paths_status:"unknown",workload:"unknown",diagnostics:["run_identity_or_attempt_count_invalid"]}]' >"$enrichments_file.tmp"
        mv "$enrichments_file.tmp" "$enrichments_file"
        continue
      fi
      family_dir="$stage/raw/families/$id"
      mkdir -p "$family_dir"
      printf '%s\n' "$run" >"$family_dir/run.json"
      needed="$attempts"
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
      for ((attempt=1; attempt<=attempts; attempt++)); do
        jobs_file="$tmp/family-${id}-attempt-${attempt}-jobs.json"
        if ! api_get "/repos/${REPO}/actions/runs/${id}/attempts/${attempt}/jobs?per_page=100" "$jobs_file"; then
          jobs_status="${API_STOP_REASON:-attempt_jobs_unavailable}"
          break
        fi
        cp "$jobs_file" "$family_dir/jobs-attempt-${attempt}.json"
        attempts_json="$(jq -cn --argjson prior "$attempts_json" --argjson attempt "$attempt" --arg path "raw/families/$id/jobs-attempt-${attempt}.json" --arg hash "$(sha256_file "$jobs_file")" '$prior + {($attempt|tostring):{path:$path,sha256:$hash}}')"
      done
      paths_status=unavailable
      paths_json='[]'
      local paths_file="$tmp/family-${id}-paths.json"
      printf '[]\n' >"$paths_file"
      pr_number="$(jq -r '.pull_requests[0].number // empty' <<<"$run")"
      if [[ "$event" == pull_request && "$pr_number" =~ ^[1-9][0-9]*$ && "$jobs_status" == complete ]] && (( API_REQUESTS + 1 + reserve <= 600 )); then
        local changed_file="$tmp/family-${id}-changed-paths.json" page=1 total_paths=0
        while :; do
          if ! api_get "/repos/${REPO}/pulls/${pr_number}/files?per_page=100&page=${page}" "$changed_file"; then paths_status="${API_STOP_REASON:-changed_paths_unavailable}"; break; fi
          jq -e 'type=="array"' "$changed_file" >/dev/null || { paths_status=changed_paths_invalid; break; }
          total_paths=$((total_paths + $(jq 'length' "$changed_file")))
          jq -cn --slurpfile before "$paths_file" --slurpfile current "$changed_file" '$before[0] + $current[0]' >"$paths_file.tmp"
          mv "$paths_file.tmp" "$paths_file"
          cp "$changed_file" "$family_dir/changed-paths-page-${page}.json"
          (( $(jq 'length' "$changed_file") == 100 )) || { paths_status=complete; break; }
          (( API_REQUESTS + 1 + reserve <= 600 )) || { paths_status=detail_unavailable_budget; break; }
          page=$((page+1))
        done
      elif [[ "$event" == pull_request ]]; then paths_status=changed_paths_unavailable_budget; fi
      docs_flag="$(jq -r 'if .changes.docs_only==true then "true" elif .changes.docs_only==false then "false" else "unknown" end' <<<"$run")"
      if [[ "$paths_status" == complete ]]; then
        docs_rule="$(jq -r '.[].filename' "$paths_file" | bash "$ROOT/scripts/ci/docs-only-classify.sh" 2>/dev/null | sed -n 's/^docs_only=//p')"
      else docs_rule=unknown; fi
      skip_seen=false
      if [[ "$jobs_status" == complete ]]; then
        skip_seen="$(jq -r '[.jobs[]? | select(.name|test("Library tests|Example unit smoke|Install smoke|Example HTTP smoke|Example Playwright")) | select(.conclusion=="skipped")] | length>0' "$family_dir/jobs-attempt-${attempts}.json" 2>/dev/null || echo false)"
      fi
      workload=unknown
      if [[ "$paths_status" == complete && "$docs_rule" == true && "$skip_seen" == true ]]; then workload=docs_only
      elif [[ "$paths_status" == complete && "$docs_rule" == false && "$jobs_status" == complete && "$skip_seen" == false ]]; then workload=full
      fi
      local diagnostic="[]" artifact_meta="$tmp/family-${id}-artifacts.json" artifact_record='{}' log_record='{}' job_id artifact_row artifact_id expected_digest artifact_zip="$family_dir/timing-artifact.zip" artifact_out="$family_dir/timing" artifact_status
      if jq -e --argjson id "$id" '[.[] | select(.run.id==$id)]|length>0' "$failed_file" >/dev/null; then
        if api_get "/repos/${REPO}/actions/runs/${id}/artifacts?per_page=100" "$artifact_meta"; then
            jq '{total_count,artifacts:[.artifacts[]? | {id,name,size_in_bytes,expired,digest,created_at,expires_at,workflow_run:{id:.workflow_run.id,head_sha:.workflow_run.head_sha}}]}' "$artifact_meta" >"$family_dir/artifacts-metadata.json"
          artifact_row="$(jq -c '[.artifacts[]? | select((.name|ascii_downcase|test("timing|playwright|test-results|report")))][0] // empty' "$artifact_meta")"
          if [[ -n "$artifact_row" ]]; then
            artifact_id="$(jq -r '.id' <<<"$artifact_row")"
            expected_digest="$(jq -r '.digest // empty' <<<"$artifact_row")"
            artifact_status="$(jq -c -n --argjson artifact "$artifact_row" --argjson run "$run" 'if $artifact.expired==true then {status:"expired_input",diagnostic:"expired_input"} elif (($artifact.id|type)!="number" or ($artifact.id|floor)!=$artifact.id) then {status:"unknown",diagnostic:"artifact_id_invalid"} elif (($artifact.digest//"")|test("^sha256:[0-9a-f]{64}$")|not) then {status:"unknown",diagnostic:"artifact_digest_unavailable"} elif (($artifact.workflow_run.id|tostring)!=($run.id|tostring) or $artifact.workflow_run.head_sha!=$run.head_sha) then {status:"unknown",diagnostic:"artifact_origin_mismatch"} else {status:"verified",artifact_id:$artifact.id,run_id:$run.id,source_sha:$run.head_sha,digest:$artifact.digest} end')"
            if [[ "$(jq -r '.status' <<<"$artifact_status")" == verified ]] && api_download_no_follow "https://api.github.com/repos/${REPO}/actions/artifacts/${artifact_id}/zip" "$artifact_zip" "artifact:${id}"; then
              local actual_digest
              actual_digest="sha256:$(sha256_file "$artifact_zip")"
              if [[ "$actual_digest" == "$expected_digest" ]] && extract_timing_archive "$artifact_zip" "$artifact_out" >"$tmp/extract-${id}.json" 2>"$tmp/extract-${id}.err"; then
                artifact_record="$(jq -cn --arg archive_sha256 "${actual_digest#sha256:}" --slurpfile accepted "$tmp/extract-${id}.json" '$accepted[0] + {archive_sha256:$archive_sha256}')"
              else
                artifact_record="$(jq -cn --arg reason "$(if [[ "$actual_digest" != "$expected_digest" ]]; then echo artifact_digest_mismatch; else cat "$tmp/extract-${id}.err"; fi)" '{status:"unknown",diagnostic:$reason}')"
                rm -rf "$artifact_zip" "$artifact_out"
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
          log_record="$(jq -cn --arg hash "$log_hash" --arg path "raw/families/$id/failed-job.log" '{status:"retained_redacted",path:$path,sha256:$hash}')"
        else
          log_record="$(jq -cn --arg reason "${API_STOP_REASON:-diagnostics_unknown}" '{status:"diagnostics_unknown",diagnostic:$reason}')"
        fi
        jq -e . <<<"$artifact_record" >/dev/null || fail "artifact_diagnostic_invalid:${id}"
        jq -e . <<<"$log_record" >/dev/null || fail "log_diagnostic_invalid:${id}"
        diagnostic="$(jq -cn --argjson artifact "$artifact_record" --argjson log "$log_record" '[{kind:"artifact",result:$artifact},{kind:"failed_job_log",result:$log}]')"
      fi
      if [[ "$event" == pull_request && "$id" == "$measurement_target" && "$workload" == full && "$jobs_status" == complete ]]; then
        local check_file="$family_dir/check-runs.json" target_artifacts="$family_dir/artifacts" artifact_manifest="$family_dir/artifact-evidence.json" artifact_index=0 artifact_row_target target_artifact_id target_digest target_zip target_dir target_hash target_extract
        mkdir -p "$target_artifacts"
        if api_get "/repos/${REPO}/commits/$(jq -r '.head_sha' "$family_dir/run.json")/check-runs?per_page=100" "$tmp/family-${id}-check-runs.json"; then
          cp "$tmp/family-${id}-check-runs.json" "$check_file"
        else jq -n --arg reason "${API_STOP_REASON:-check_runs_unavailable}" '{status:"unknown",reason:$reason}' >"$check_file"; fi
        if api_get "/repos/${REPO}/actions/runs/${id}/artifacts?per_page=100" "$artifact_meta"; then
          jq '{total_count,artifacts:[.artifacts[]? | {id,name,size_in_bytes,expired,digest,created_at,expires_at,workflow_run:{id:.workflow_run.id,head_sha:.workflow_run.head_sha}}]}' "$artifact_meta" >"$family_dir/artifacts-metadata.json"
          printf '[]\n' >"$artifact_manifest"
          while IFS= read -r artifact_row_target; do
            [[ -n "$artifact_row_target" ]] || continue
            target_artifact_id="$(jq -r '.id' <<<"$artifact_row_target")"
            target_digest="$(jq -r '.digest // empty' <<<"$artifact_row_target")"
            target_zip="$target_artifacts/${target_artifact_id}.zip"
            target_dir="$target_artifacts/${target_artifact_id}"
            target_extract='{"status":"unknown","diagnostic":"artifact_not_downloaded"}'
            if jq -e --argjson run "$run" '.expired!=true and (.id|type)=="number" and (.digest|test("^sha256:[0-9a-f]{64}$")) and (.workflow_run.id|tostring)==($run.id|tostring) and .workflow_run.head_sha==$run.head_sha' <<<"$artifact_row_target" >/dev/null \
              && api_download_no_follow "https://api.github.com/repos/${REPO}/actions/artifacts/${target_artifact_id}/zip" "$target_zip" "artifact:${id}:${target_artifact_id}"; then
              target_hash="sha256:$(sha256_file "$target_zip")"
              if [[ "$target_hash" == "$target_digest" ]] && extract_timing_archive "$target_zip" "$target_dir" >"$tmp/target-extract-${target_artifact_id}.json" 2>"$tmp/target-extract-${target_artifact_id}.err"; then
                target_extract="$(jq -cn --arg archive_sha256 "${target_hash#sha256:}" --arg path "raw/families/${id}/artifacts/${target_artifact_id}" --slurpfile extraction "$tmp/target-extract-${target_artifact_id}.json" '$extraction[0] + {status:"accepted",archive_sha256:$archive_sha256,path:$path}')"
              else target_extract="$(jq -cn --arg reason "$(if [[ "$target_hash" != "$target_digest" ]]; then echo artifact_digest_mismatch; else cat "$tmp/target-extract-${target_artifact_id}.err"; fi)" '{status:"unknown",diagnostic:$reason}')"; rm -rf "$target_zip" "$target_dir"; fi
            else target_extract="$(jq -cn --arg reason "${API_STOP_REASON:-artifact_identity_or_digest_invalid}" '{status:"unknown",diagnostic:$reason}')"; fi
            jq -cn --slurpfile prior "$artifact_manifest" --argjson artifact "$artifact_row_target" --argjson result "$target_extract" '$prior[0] + [{artifact:$artifact,result:$result}]' >"$artifact_manifest.tmp" && mv "$artifact_manifest.tmp" "$artifact_manifest"
            artifact_index=$((artifact_index+1))
            [[ -z "$API_STOP_REASON" ]] || break
          done < <(jq -c '[.artifacts[]? | select((.name|ascii_downcase|test("timing|playwright|measurement-metadata")))] | sort_by(.name,.id) | .[]' "$artifact_meta")
        else jq -n --arg reason "${API_STOP_REASON:-artifact_metadata_unavailable}" '{status:"unknown",reason:$reason}' >"$artifact_manifest"; fi
      fi
      details_file="$tmp/family-${id}-detail.json"
      jq -cn --argjson id "$id" --arg status "$jobs_status" --arg paths_status "$paths_status" --arg workload "$workload" --arg docs_only "$docs_flag" --argjson attempts "$attempts_json" --slurpfile paths "$paths_file" --argjson skip_seen "$skip_seen" --argjson diagnostic "$diagnostic" '{run_id:$id,detail_status:$status,attempt_count:($attempts|length),attempt_jobs:$attempts,changed_paths_status:$paths_status,changed_paths:$paths[0],changes_docs_only:(if $docs_only=="unknown" then null else ($docs_only=="true") end),docs_path_classification:(if $paths_status=="complete" then "captured" else "unknown" end),observed_expected_skip:$skip_seen,workload:$workload,artifact_diagnostics:$diagnostic,diagnostics:(if $status=="complete" then [] else [$status] end)}' >"$details_file" || fail "family_detail_json_invalid:${id}"
      jq -n --slurpfile detail "$details_file" --arg run_hash "$(sha256_file "$family_dir/run.json")" --arg artifact_path "$(if [[ -s "$family_dir/artifact-evidence.json" ]]; then echo "raw/families/$id/artifact-evidence.json"; fi)" --arg artifact_hash "$(if [[ -s "$family_dir/artifact-evidence.json" ]]; then sha256_file "$family_dir/artifact-evidence.json"; fi)" --arg check_hash "$(if [[ -s "$family_dir/check-runs.json" ]]; then sha256_file "$family_dir/check-runs.json"; fi)" --argjson attempts "$attempts_json" '{schema_version:"sigra.ci-run-metrics/family-detail-v1",run_id:$detail[0].run_id,source_run_sha256:$run_hash,attempt_jobs:$attempts,detail_status:$detail[0].detail_status,changed_paths_status:$detail[0].changed_paths_status,changes_docs_only:$detail[0].changes_docs_only,workload:$detail[0].workload,observed_expected_skip:$detail[0].observed_expected_skip,artifact_evidence:(if $artifact_path=="" then null else {path:$artifact_path,sha256:$artifact_hash} end),check_runs_sha256:(if $check_hash=="" then null else $check_hash end),artifact_diagnostics:$detail[0].artifact_diagnostics}' >"$family_dir/manifest.json"
      jq -cn --slurpfile prior "$enrichments_file" --slurpfile detail "$details_file" '$prior[0] + [$detail[0]]' >"$enrichments_file.tmp"
      mv "$enrichments_file.tmp" "$enrichments_file"
      api_write_ledger collecting
      [[ -z "$API_STOP_REASON" ]] || break
    done <<<"$(jq -c '.[]' "$priority_file")"
    for population_name in pull_request push_main schedule; do
      local population_file="$stage/raw/populations/${population_name}.json"
      jq --slurpfile details "$enrichments_file" '.runs |= map(. as $r | . + ([$details[0][] | select(.run_id==$r.id)][0] // {detail_status:"detail_unavailable_budget",workload:"unknown",attempt_jobs:{}}))' "$population_file" >"$population_file.tmp" && mv "$population_file.tmp" "$population_file"
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
  workflow_blob="$(git hash-object "$ROOT/.github/workflows/ci.yml" 2>/dev/null || echo unavailable)"
  workflow_sha="$(sha256_file "$ROOT/.github/workflows/ci.yml")"
  tree_sha="$(git rev-parse HEAD 2>/dev/null || echo unavailable)"
  source_hashes="$(jq -cn --arg workflow "$(sha256_file "$stage/source/ci.yml")" --arg collector "$(sha256_file "$stage/source/ci-run-metrics.sh")" --arg playwright "$(sha256_file "$stage/source/ci-playwright-report.mjs")" --arg playwright_config "$(sha256_file "$stage/source/playwright.config.ts")" --arg playwright_lock "$(sha256_file "$stage/source/playwright-package-lock.json")" --arg exunit "$(sha256_file "$stage/source/ci_timing_formatter.ex")" --arg helper "$(sha256_file "$stage/source/test_helper.exs")" --arg report_test "$(sha256_file "$stage/source/ci-playwright-report.test.mjs")" '{"ci.yml":$workflow,"ci-run-metrics.sh":$collector,"ci-playwright-report.mjs":$playwright,"playwright.config.ts":$playwright_config,"playwright-package-lock.json":$playwright_lock,"ci_timing_formatter.ex":$exunit,"test_helper.exs":$helper,"ci-playwright-report.test.mjs":$report_test}')"
  required_contexts="$(jq -c '[.[]? | select(.type=="required_status_checks") | .parameters.required_status_checks[]?.context] | unique' "$stage/raw/effective-rules.json" 2>/dev/null || echo '[]')"
  required_provenance="$(jq -c '[.[]? | select(.type=="required_status_checks") | {context:.parameters.required_status_checks[]?.context,ruleset_id:.ruleset_id,ruleset_source:.ruleset_source}]' "$stage/raw/effective-rules.json" 2>/dev/null || echo '[]')"
  active_rules="$(jq -c '[.[]? | select(.enforcement=="active") | {id,name,target,enforcement}] | sort_by(.id)' "$stage/raw/rulesets.json" 2>/dev/null || echo '[]')"
  api_write_ledger "$manifest_status"
  request_hash="$(sha256_file "$API_LEDGER")"
  selection_hash="$(sha256_file "$stage/selection-ledger.json")"
  pr_hash="$(sha256_file "$stage/raw/populations/pull_request.json")"
  push_hash="$(sha256_file "$stage/raw/populations/push_main.json")"
  night_hash="$(sha256_file "$stage/raw/populations/schedule.json")"
  jq -n --arg repo "$REPO" --arg workflow "$WORKFLOW" --arg cutoff "$CUTOFF" --arg captured "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg since "$since" --arg status "$manifest_status" --arg stop "$API_STOP_REASON" --arg sha "$tree_sha" --arg workflow_sha "$workflow_sha" --arg workflow_blob "$workflow_blob" --arg source_hashes "$source_hashes" --argjson required_contexts "$required_contexts" --argjson required_provenance "$required_provenance" --argjson active_rules "$active_rules" --arg request_hash "$request_hash" --arg selection_hash "$selection_hash" --arg pr_hash "$pr_hash" --arg push_hash "$push_hash" --arg night_hash "$night_hash" --arg rate_hash "$(sha256_file "$stage/raw/rate-limit.json")" --arg rules_hash "$(sha256_file "$stage/raw/effective-rules.json")" --arg protection_hash "$(sha256_file "$stage/raw/branch-protection.json")" --arg rulesets_hash "$(sha256_file "$stage/raw/rulesets.json")" --argjson requests "$request_count" --slurpfile pr "$stage/raw/populations/pull_request.json" --slurpfile push "$stage/raw/populations/push_main.json" --slurpfile night "$stage/raw/populations/schedule.json" --slurpfile manual "$stage/raw/populations/manual.json" --slurpfile release "$stage/raw/populations/release_push.json" '{schema_version:"sigra.ci-run-metrics/snapshot-v1",repository:$repo,workflow:$workflow,cutoff_utc:$cutoff,captured_at_utc:$captured,window_start_utc:$since,status:$status,stop_reason:(if $stop=="" then null else $stop end),request_count:$requests,source_sha:$sha,workflow_sha256:$workflow_sha,workflow_blob_sha:$workflow_blob,required_contexts:$required_contexts,required_rule_provenance:$required_provenance,active_rulesets:$active_rules,source_file_sha256:($source_hashes|fromjson),source_sha256:{request_ledger:$request_hash,selection_ledger:$selection_hash,pull_request:$pr_hash,push_main:$push_hash,schedule:$night_hash,rate_limit:$rate_hash,effective_rules:$rules_hash,branch_protection:$protection_hash,rulesets:$rulesets_hash},populations:{pull_request:$pr[0],push_main:$push[0],schedule:$night[0],manual:{population:"manual",event:"workflow_dispatch",api_total_count:$manual[0].api_total_count,records:$manual[0].runs},release_push:{population:"release_push",event:"push",records:$release[0].runs}}}' >"$stage/manifest.json"
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
  if [[ -z "$source_sha" || "$(jq -r '.event // empty' "$run")" != "pull_request" || "$(jq -r '.path // ""' "$run")" != ".github/workflows/ci.yml" ]]; then
    api_stop run_identity_mismatch "" "run identity"
  fi
  local attempt_id
  attempt_id="$(jq -r '.run_attempt // 1' "$run")"
  local all_jobs='[]' attempt_num
  for ((attempt_num=1; attempt_num<=attempt_id; attempt_num++)); do
    if ! api_get "/repos/${REPO}/actions/runs/${RUN_ID}/attempts/${attempt_num}/jobs?per_page=100" "$tmp/jobs-attempt-${attempt_num}.json"; then
      api_stop jobs_unavailable "" "attempt ${attempt_num} jobs"
      printf '%s\n' "$API_UNKNOWN" >"$SOURCE_BUNDLE/missing-capabilities.json"
      return 1
    fi
    cp "$tmp/jobs-attempt-${attempt_num}.json" "$SOURCE_BUNDLE/raw/jobs-attempt-${attempt_num}.json"
    all_jobs="$(jq -cn --argjson attempt "$attempt_num" --argjson prior "$all_jobs" --slurpfile current "$tmp/jobs-attempt-${attempt_num}.json" '$prior + (($current[0].jobs // []) | map(. + {attempt:$attempt}))')"
  done
  jq -cn --argjson jobs "$all_jobs" '{jobs:$jobs}' >"$SOURCE_BUNDLE/raw/jobs.json"
  if ! api_get "/repos/${REPO}/commits/${source_sha}/check-runs?per_page=100" "$tmp/check-runs.json"; then
    api_stop check_runs_unavailable "" "check runs"
  else
    cp "$tmp/check-runs.json" "$SOURCE_BUNDLE/raw/check-runs.json"
  fi
  local approved required actual required_json rules_changed job_cost last_required diagnostics attempt_hashes
  approved='["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"]'
  actual="$(jq -c '[.[]? | select(.type == "required_status_checks") | .parameters.required_status_checks[]?.context] | unique' "$tmp/effective-rules.json")"
  [[ "$actual" != "null" ]] || actual='[]'
  required_json="$(jq -cn --argjson current "$actual" --argjson approved "$approved" '$current')"
  rules_changed=false
  [[ "$(jq -cn --argjson a "$actual" --argjson b "$approved" '$a|sort == ($b|sort)')" == true ]] || rules_changed=true
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
    --argjson expected "$approved" --argjson rules_changed "$rules_changed" \
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
    '{schema_version:"sigra.ci-run-metrics/family-v1",repository:$repo,workflow:$workflow,event:"pull_request",branch:$branch,run_id:$run_id,attempt:$attempt,attempts_collected:$all_attempts,source_sha:$sha,revisions:[{source_sha:$sha,run_id:$run_id,attempt:$attempt,associated_pull_requests:[]}],run_url:$url,literal_conclusion:$conclusion,required_contexts:$rules,approved_contexts:$expected,active_rulesets:$rulesets,required_rules_changed:$rules_changed,raw_sha256:($attempt_hashes + {run:$run_hash,jobs:$jobs_hash,check_runs:$checks_hash,effective_rules:$rules_hash,branch_protection:$protection_hash,rulesets:$rulesets_hash,rate_limit:$rate_hash})}' >"$SOURCE_BUNDLE/manifest.json"
  rm -rf "$tmp"
  api_write_ledger complete
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
  approved='["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"]'
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
  current='[]'
  if [[ -s "$tmp/effective-rules.json" ]]; then
    current="$(jq -c '[.[]? | select(.type == "required_status_checks") | .parameters.required_status_checks[]?.context] | unique' "$tmp/effective-rules.json" 2>/dev/null || echo '[]')"
  fi
  if [[ "$current" == '[]' && -s "$tmp/branch-protection.json" ]]; then
    current="$(jq -c '[.contexts[]?] | unique' "$tmp/branch-protection.json" 2>/dev/null || echo '[]')"
  fi
  if [[ "$status" == ready && "$(jq -cn --argjson a "$current" --argjson b "$approved" '$a|sort == ($b|sort)')" != true ]]; then
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

replay_family() {
  local bundle="$1" output_format="${2:-json}" required_changed run created check_data jobs_json contexts check_lines last_created wait runner diagnostics
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
  run_attempt="$(jq -r '.run_attempt // 1' "$bundle/raw/run.json")"
  [[ "$manifest_repo" == "$REPO" && "$manifest_run" == "$RUN_ID" && "$manifest_sha" == "$run_sha" && "$manifest_attempt" == "$run_attempt" && "$run_event" == "pull_request" && "$run_workflow" == ".github/workflows/ci.yml" ]] || fail source_identity_mismatch
  required_changed="$(jq -r '.required_rules_changed' "$bundle/manifest.json")"
  contexts="$(jq -r '.required_contexts[]?' "$bundle/manifest.json")"
  run="$bundle/raw/run.json"
  created="$(jq -r '.created_at // empty' "$run")"
  [[ -n "$created" ]] || fail run_created_at_missing
  # Completion endpoint is accepted only when every current required check is
  # successful, has valid timestamps, and maps by external_id to an actual job.
  check_lines="$(jq -c --argjson required "$(jq -c '.required_contexts' "$bundle/manifest.json")" '
    .check_runs[]? | select(.name as $n | $required | index($n))
  ' "$bundle/raw/check-runs.json")"
  diagnostics='[]'
  local first_contexts='{}' eventual_contexts='{}' latest_attempt check_attempt job_attempt mapped_job first_wait wait_value fatal
  latest_attempt="$(jq -r '.attempt // 1' "$bundle/manifest.json")"
  fatal=false
  while IFS= read -r check; do
    [[ -n "$check" ]] || continue
    cid="$(jq -r '.id // empty' <<<"$check")"
    name="$(jq -r '.name // empty' <<<"$check")"
    external="$(jq -r '.external_id // empty | tostring' <<<"$check")"
    check_sha="$(jq -r '.head_sha // empty' <<<"$check")"
    status="$(jq -r '.status // empty' <<<"$check")"
    conclusion="$(jq -r '.conclusion // empty' <<<"$check")"
    started="$(jq -r '.started_at // empty' <<<"$check")"
    completed="$(jq -r '.completed_at // empty' <<<"$check")"
    if [[ "$required_changed" == true ]]; then diagnostics="$(jq -c '. + ["required_rules_changed"] | unique' <<<"$diagnostics")"; fatal=true; break; fi
    mapped_job="$(jq -c --arg check_id "$cid" --arg external "$external" --arg name "$name" --arg sha "$manifest_sha" '
      [.jobs[]? | select(((.id|tostring)==$check_id or (.id|tostring)==$external) and .head_sha==$sha and .name==$name)] | if length==1 then .[0] else null end
    ' "$bundle/raw/jobs.json")"
    if [[ "$mapped_job" == null ]]; then
      diagnostics="$(jq -c --arg name "$name" --arg check_id "$cid" '. + [{reason:"required_context_unbound",context:$name,check_id:$check_id}]' <<<"$diagnostics")"
      fatal=true
      continue
    fi
    job_attempt="$(jq -r '.attempt // .run_attempt // 1' <<<"$mapped_job")"
    if [[ "$check_sha" != "$manifest_sha" || -z "$started" || -z "$completed" || "$(jq -nr --arg s "$started" --arg c "$completed" 'try (($s|fromdateiso8601) <= ($c|fromdateiso8601)) catch false')" != true ]]; then
      diagnostics="$(jq -c --arg name "$name" --argjson attempt "$job_attempt" '. + [{reason:"required_context_incomplete",context:$name,attempt:$attempt}]' <<<"$diagnostics")"
      [[ "$job_attempt" == "$latest_attempt" ]] && fatal=true
      continue
    fi
    if [[ "$status" != completed || "$conclusion" != success ]]; then
      diagnostics="$(jq -c --arg name "$name" --argjson attempt "$job_attempt" --arg conclusion "$conclusion" '. + [{reason:"required_context_incomplete",context:$name,attempt:$attempt,conclusion:$conclusion}]' <<<"$diagnostics")"
      [[ "$job_attempt" == "$latest_attempt" ]] && fatal=true
      continue
    fi
    if [[ "$job_attempt" == 1 ]]; then
      first_contexts="$(jq -cn --argjson contexts "$first_contexts" --arg name "$name" --arg value "$completed" '$contexts + {($name):$value}')"
    fi
    if [[ "$job_attempt" == "$latest_attempt" ]]; then
      eventual_contexts="$(jq -cn --argjson contexts "$eventual_contexts" --arg name "$name" --arg value "$completed" '$contexts + {($name):$value}')"
    fi
  done <<<"$check_lines"
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
  if (( first_count == required_count )); then first_wait="$(jq -nr --arg created "$created" --argjson contexts "$first_contexts" '[ $contexts[] | fromdateiso8601 ] | max - ($created|fromdateiso8601)')"; fi
  if (( eventual_count == required_count )) && [[ "$required_changed" != true ]]; then wait_value="$(jq -nr --arg created "$created" --argjson contexts "$eventual_contexts" '[ $contexts[] | fromdateiso8601 ] | max - ($created|fromdateiso8601)')"; fi
  [[ "$required_changed" == true ]] && fatal=true
  runner="$(jq -r 'if any(.jobs[]?; .conclusion != "skipped" and (.started_at == null or .completed_at == null)) then null else ([.jobs[]? | select(.conclusion != "skipped" and .started_at != null and .completed_at != null) | ((.completed_at|fromdateiso8601)-(.started_at|fromdateiso8601)) | select(.>=0)] | add // null) end' "$bundle/raw/jobs.json")"
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
  for name in request_ledger selection_ledger pull_request push_main schedule rate_limit effective_rules branch_protection rulesets; do
    case "$name" in
      request_ledger) file="$bundle/request-ledger.json";;
      selection_ledger) file="$bundle/selection-ledger.json";;
      *) file="$bundle/raw/populations/${name}.json";;
    esac
    case "$name" in
      rate_limit|effective_rules|branch_protection|rulesets) file="$bundle/raw/${name//_/-}.json";;
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
  result="$(jq -c '{schema_version,repository,workflow,cutoff_utc,captured_at_utc,window_start_utc,status,stop_reason,request_count,source_sha,workflow_sha256,workflow_blob_sha,required_contexts,required_rule_provenance,active_rulesets,source_file_sha256,source_sha256,comparison_families:(.comparison_families // null),source_runs:([.populations|to_entries[]|select(.key=="pull_request" or .key=="push_main" or .key=="schedule") as $pop | $pop.value.runs[]? | {event:$pop.key,id,html_url,head_sha,run_attempt,conclusion,created_at,updated_at,detail_status,workload,changes_docs_only} ]|sort_by(.event,.created_at,.id)),populations:{pull_request:{api_total_count:.populations.pull_request.api_total_count,population_capped:.populations.pull_request.population_capped,population_exhausted:.populations.pull_request.population_exhausted,run_count:(.populations.pull_request.runs|length),outcomes:(.populations.pull_request.runs|group_by(.conclusion)|map({key:(.[0].conclusion // "unknown"),value:length})|from_entries)},push_main:{api_total_count:.populations.push_main.api_total_count,population_capped:.populations.push_main.population_capped,population_exhausted:.populations.push_main.population_exhausted,run_count:(.populations.push_main.runs|length),outcomes:(.populations.push_main.runs|group_by(.conclusion)|map({key:(.[0].conclusion // "unknown"),value:length})|from_entries)},schedule:{api_total_count:.populations.schedule.api_total_count,population_capped:.populations.schedule.population_capped,population_exhausted:.populations.schedule.population_exhausted,run_count:(.populations.schedule.runs|length),outcomes:(.populations.schedule.runs|group_by(.conclusion)|map({key:(.[0].conclusion // "unknown"),value:length})|from_entries)},manual_records:(.populations.manual.records|length),release_push_records:(.populations.release_push.records|length)}}' "$manifest")"
  local metrics_file
  metrics_file="$(mktemp "${TMPDIR:-/tmp}/ci-run-metrics-replay.XXXXXX")"
  python3 - "$bundle" "$ROOT" >"$metrics_file" <<'PY'
import datetime, hashlib, json, pathlib, re, sys
root = pathlib.Path(sys.argv[1]); project = pathlib.Path(sys.argv[2]); manifest = json.loads((root/'manifest.json').read_text())
events = {'pull_request':'pull_request','push_main':'main','schedule':'nightly'}
stages = ['setup','cache_restore_download','compile','database_startup','app_boot','test_execution','artifact_upload','other']
wait_rows={k:[] for k in events.values()}; runner_rows={k:[] for k in events.values()}; stage_values={k:{s:[] for s in stages} for k in events.values()}
cache={}; images={}; configured={}; observed={}; test_rows=[]; overhead={'playwright':{'status':'unmeasured','overhead_ms':None},'exunit':{'status':'unknown','overhead_us':None}}
instrumentation_baseline={'exunit':{'status':'unknown','source':'.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json'}}
try:
    baseline=json.loads((project/'.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json').read_text())
    if baseline.get('complete') is True:
        instrumentation_baseline['exunit']={'status':'historical_baseline','source':'.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json','observed_at_utc':baseline.get('observed_at_utc'),'instrumentation_overhead_us':baseline.get('instrumentation_overhead_us'),'method':baseline.get('overhead_method')}
except (OSError,ValueError): pass
failure_candidates=[]; signature_groups={}; failure_bins={k:[] for k in ['application_test_failure','infrastructure_failure','superseded_cancellation','cancellation_unclassified','expected_skip','unexpected_skip','missing_job','unknown_failure']}; missing_diagnostics=[]
def epoch(v):
    if not v: return None
    try: return datetime.datetime.fromisoformat(v.replace('Z','+00:00')).timestamp()
    except (ValueError, TypeError): return None
def result(vals, unit):
    return {'status':'measured','n':len(vals),'unit':unit,'total':round(sum(vals),6),'limitation':'single_observation' if len(vals)==1 else None} if vals else {'status':'unknown','n':0,'unit':unit,'total':None,'reason':'no_complete_source_timestamps'}
for pop,key in events.items():
    for run in manifest.get('populations',{}).get(pop,{}).get('runs',[]):
        runid=str(run.get('id','')); created=epoch(run.get('created_at'))
        if run.get('conclusion') in ('failure','timed_out','cancelled','skipped'):
            failure_candidates.append({'event':key,'run':run,'created_epoch':created if created is not None else -1})
        refs=run.get('attempt_jobs') or {}
        for attempt,ref in sorted(refs.items(),key=lambda x:int(x[0])):
            rel=(ref.get('path') or f'raw/families/{runid}/jobs-attempt-{attempt}.json').replace(f'raw/families/{runid}/','')
            jobfile=root/'raw'/'families'/runid/pathlib.Path(rel).name
            if not jobfile.is_file() or hashlib.sha256(jobfile.read_bytes()).hexdigest()!=ref.get('sha256'): continue
            try: jobs=json.loads(jobfile.read_text()).get('jobs',[])
            except Exception: continue
            for job in jobs:
                jid=str(job.get('id','')); started=epoch(job.get('started_at')); ended=epoch(job.get('completed_at'))
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
        # Artifact facts are joined only when the API-accepted digest and producing run identity exist.
        family=root/'raw'/'families'/runid; metadata_path=family/'timing'/'ci-measurement-metadata.json'
        details=run.get('artifact_diagnostics') or []
        accepted=next((d.get('result',{}) for d in details if d.get('kind')=='artifact' and d.get('result',{}).get('status')=='accepted'),None)
        archive=family/'timing-artifact.zip'
        if metadata_path.is_file() and accepted and accepted.get('archive_sha256') and archive.is_file():
            try: meta=json.loads(metadata_path.read_text())
            except Exception: meta={}
            latest=str(max([int(x) for x in refs] or [1])); expected_sha=run.get('head_sha'); expected_attempt=int(latest)
            seam=meta.get('matrix_seam')
            archive_hash=hashlib.sha256(archive.read_bytes()).hexdigest()
            try: meta_attempt=int(meta.get('run_attempt',-1))
            except (TypeError,ValueError): meta_attempt=-1
            latest_jobs=json.loads((family/f'jobs-attempt-{latest}.json').read_text()).get('jobs',[]) if (family/f'jobs-attempt-{latest}.json').is_file() else []
            job_bound=any(j.get('name')==meta.get('job_name') for j in latest_jobs)
            if (archive_hash==accepted.get('archive_sha256') and meta.get('repository')=='szTheory/sigra' and str(meta.get('run_id'))==runid and meta_attempt==expected_attempt and meta.get('source_sha')==expected_sha and meta.get('event')==run.get('event') and seam and job_bound):
                image=meta.get('runner_image') or {}
                images[key]={'runner_os':meta.get('runner_os'),'runner_arch':meta.get('runner_arch'),'image_os':image.get('image_os'),'image_version':image.get('image_version')}
                configured[key]=meta.get('configured_versions',{})
                observed[key]=meta.get('observed_versions',{})
                cache.update(meta.get('cache_outcome',{}))
                timing=family/'timing'
                for path in timing.glob('*.json'):
                    if path.name in ('ci-measurement-metadata.json','ci-exunit-timing.json'): continue
                    try: report=json.loads(path.read_text())
                    except Exception: continue
                    if report.get('seam')!=seam or not report.get('complete'): continue
                    for row in report.get('tests',[]):
                        test_rows.append({'source':'playwright','identity':f"{runid}:{expected_attempt}:{seam}:{row.get('test_id')}",'run_id':runid,'attempt':expected_attempt,'sha':expected_sha,'seam':seam,'test_id':row.get('test_id'),'name':row.get('title'),'duration_ms':row.get('duration_ms'),'suite_elapsed_ms':report.get('suite_elapsed_ms'),'sum_test_duration_ms':report.get('sum_test_duration_ms')})
                    overhead['playwright']=report.get('reporter_overhead',overhead['playwright'])
                exunit=timing/'ci-exunit-timing.json'
                if exunit.is_file():
                    try: report=json.loads(exunit.read_text())
                    except Exception: report={}
                    if report.get('complete') and report.get('unit')=='microsecond':
                        for row in report.get('tests',[]): test_rows.append({'source':'exunit','identity':f"{runid}:{expected_attempt}:{row.get('test_id')}",'run_id':runid,'attempt':expected_attempt,'sha':expected_sha,'test_id':row.get('test_id'),'name':row.get('name'),'duration_us':row.get('duration_us')})
                        overhead['exunit']={'status':'measured','instrumentation_overhead_us':report.get('instrumentation_overhead_us'),'method':report.get('instrumentation_overhead_method')}
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
            if logdiag.get('status')=='retained_redacted' and hashlib.sha256(logpath.read_bytes()).hexdigest()==logdiag.get('sha256'):
                ref=logdiag.get('path'); diagnostic='available'
        except Exception: pass
    category='unknown_failure'; signature=None
    if conclusion=='skipped': category='expected_skip' if run.get('workload')=='docs_only' or run.get('observed_expected_skip') is True else 'unexpected_skip'
    elif conclusion=='cancelled': category='superseded_cancellation' if run.get('run_attempt',1)>1 or run.get('superseded_by_run_id') else 'cancellation_unclassified'
    elif conclusion in ('timed_out',): category='infrastructure_failure'
    elif not (run.get('attempt_jobs') or {}): category='missing_job'
    elif ref:
        text=(root/ref).read_text(errors='replace') if (root/ref).is_file() else ''
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
out['required_result_wait']={'status':'unknown','n':0,'seconds':None,'reason':'no_complete_source_bound_full_pr_required_check_endpoint'}
out['instrumented_full_pr']={'complete':False,'status':'insufficient_data','diagnostics':['no_source_bound_full_pr_family_has_all_required_contexts_and_both_test_timing_artifacts'],'producing_run_id':None,'source_sha':None,'attempt':None,'job_cost_seconds':None,'step_costs':None,'test_costs':None}
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

if [[ "$COLLECT" == true && "$REPLAY" == true ]]; then
  fail "--collect and --replay are mutually exclusive"
fi
if [[ "$VERIFY_BASELINE" == true ]]; then
  [[ -n "$SOURCE_BUNDLE" && -n "$BASELINE_FILE" ]] || fail "--verify-baseline requires --source-bundle and --baseline"
  [[ -s "$BASELINE_FILE" ]] || fail "baseline_missing"
  verify_dir="$SOURCE_BUNDLE"; verify_tmp=""
  if [[ ! -d "$SOURCE_BUNDLE" ]]; then
    verify_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-run-metrics-verify.XXXXXX")"
    extract_snapshot_bundle "$SOURCE_BUNDLE" "$verify_tmp/bundle" || fail "source_bundle_archive_invalid"
    verify_dir="$verify_tmp/bundle"
  fi
  replay_file="$(mktemp "${TMPDIR:-/tmp}/ci-run-metrics-expected.XXXXXX")"
  replay_snapshot "$verify_dir" >"$replay_file"
  python3 - "$verify_dir" "$BASELINE_FILE" "$replay_file" <<'PY'
import datetime, json, pathlib, sys
bundle, baseline_path, replay_path = map(pathlib.Path, sys.argv[1:])
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
if baseline != replay: fail('baseline_replay_mismatch')
if sorted(manifest.get('required_contexts') or []) != sorted(expected): fail('required_context_set_changed',manifest.get('required_contexts'))
provenance=manifest.get('required_rule_provenance') or []
if {x.get('context') for x in provenance} != set(expected) or any(not isinstance(x.get('ruleset_id'),int) for x in provenance): fail('required_context_provenance_incomplete')
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
if [[ "$EVALUATE_COMPARISON" == true ]]; then
  [[ -s "$CONTRACT_FILE" && -d "$BEFORE_BUNDLE" && -d "$AFTER_BUNDLE" ]] || fail "--evaluate-comparison requires --contract and extracted --before-bundle/--after-bundle directories"
  before_json="$(mktemp "${TMPDIR:-/tmp}/ci-comparison-before.XXXXXX")"
  after_json="$(mktemp "${TMPDIR:-/tmp}/ci-comparison-after.XXXXXX")"
  replay_snapshot "$BEFORE_BUNDLE" >"$before_json"
  replay_snapshot "$AFTER_BUNDLE" >"$after_json"
  python3 - "$CONTRACT_FILE" "$before_json" "$after_json" <<'PY'
import json, math, pathlib, sys
contract, before, after = map(lambda p: json.loads(pathlib.Path(p).read_text()), sys.argv[1:])
issues=[]; families=[]; paired=[]
def issue(code, detail=None):
    row={'reason':code}
    if detail is not None: row['detail']=detail
    issues.append(row)
if contract.get('status') != 'ready': issue('contract_not_ready',contract.get('status'))
if contract.get('pair_count') != 20 or contract.get('primary_family_count') != 40: issue('contract_sample_size_invalid')
if contract.get('window_duration_hours') != 48: issue('contract_window_invalid')
if before.get('source_sha') != contract.get('baseline_application_sha'): issue('before_source_identity_mismatch')
if before.get('workflow_sha256') != contract.get('baseline_workflow_sha256'): issue('before_workflow_identity_mismatch')
if after.get('source_sha') != contract.get('candidate_application_sha'): issue('after_source_identity_mismatch')
if after.get('workflow_sha256') != contract.get('candidate_workflow_sha256'): issue('after_workflow_identity_mismatch')
for label, data in [('before',before),('after',after)]:
    if data.get('status') != 'complete': issue(label+'_snapshot_incomplete')
    rows=data.get('comparison_families')
    if not isinstance(rows,list): issue(label+'_family_inputs_missing'); continue
    if len(rows) != 20: issue(label+'_family_count',len(rows))
    seen=set()
    for row in rows:
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
    fields=['workload','workload_sha','runner_class','cache_stratum','exunit_instrumentation','playwright_instrumentation']
    mismatch=[field for field in fields if b.get(field)!=a.get(field)]
    if mismatch: issue('pair_not_equivalent',{'pair_id':pair_id,'fields':mismatch}); continue
    paired.append((pair_id,b,a))
    if b.get('conclusion')!='success' or a.get('conclusion')!='success': continue
    if not isinstance(b.get('required_result_wait_seconds'),(int,float)) or not isinstance(a.get('required_result_wait_seconds'),(int,float)): continue
    if not isinstance(b.get('runner_seconds'),(int,float)) or not isinstance(a.get('runner_seconds'),(int,float)): continue
wait_before=[b['required_result_wait_seconds'] for _,b,a in paired if b.get('conclusion')=='success' and a.get('conclusion')=='success']
wait_after=[a['required_result_wait_seconds'] for _,b,a in paired if b.get('conclusion')=='success' and a.get('conclusion')=='success']
runner_before=sum(b['runner_seconds'] for _,b,a in paired if b.get('conclusion')=='success' and a.get('conclusion')=='success')
runner_after=sum(a['runner_seconds'] for _,b,a in paired if b.get('conclusion')=='success' and a.get('conclusion')=='success')
def median(xs):
    xs=sorted(xs); n=len(xs)
    return (xs[(n-1)//2]+xs[n//2])/2 if n else None
def p95(xs):
    xs=sorted(xs); return xs[math.ceil(.95*len(xs))-1] if xs else None
if len(paired)!=20 or len(wait_before)!=20: issue('insufficient_equivalent_successful_pairs',len(wait_before))
metrics={'pair_count':len(paired),'comparable_successful_pairs':len(wait_before),'baseline_median_seconds':median(wait_before),'candidate_median_seconds':median(wait_after),'baseline_p95_seconds':p95(wait_before),'candidate_p95_seconds':p95(wait_after),'baseline_runner_seconds':runner_before,'candidate_runner_seconds':runner_after,'p95_method':'nearest-rank ceil(0.95*n); for n=20 this is sorted value 19','overhead_disclosure':contract.get('instrumentation_overhead')}
if not issues and len(wait_before)==20:
    verdict='pass' if median(wait_after)<=.8*median(wait_before) and p95(wait_after)<=p95(wait_before) and runner_after<=runner_before else 'miss'
else: verdict='insufficient_data'
print(json.dumps({'status':verdict,'metrics':metrics,'diagnostics':issues},sort_keys=True))
PY
  rc=$?
  rm -f "$before_json" "$after_json"
  exit "$rc"
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
