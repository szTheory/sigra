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
PREFLIGHT=false
PREFLIGHT_OUTPUT=""
SOURCE_BUNDLE=""
TARGET_BRANCH="main"
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
    --preflight) PREFLIGHT=true; shift;;
    --preflight-output) PREFLIGHT_OUTPUT="$2"; shift 2;;
    --run-id) RUN_ID="$2"; shift 2;;
    --source-bundle) SOURCE_BUNDLE="$2"; shift 2;;
    --branch) TARGET_BRANCH="$2"; shift 2;;
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "ci-run-metrics: FAIL: $*" >&2
  exit 1
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
    >"${API_LEDGER}.tmp" && mv "${API_LEDGER}.tmp" "$API_LEDGER"
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

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

if [[ "$MODE" != "wall" && "$MODE" != "jobspan" ]]; then
  fail "unknown --mode: ${MODE} (expected wall|jobspan)"
fi

if [[ "$COLLECT" == true && "$REPLAY" == true ]]; then
  fail "--collect and --replay are mutually exclusive"
fi
if [[ "$PREFLIGHT" == true ]]; then
  run_preflight
  exit $?
fi
if [[ "$COLLECT" == true ]]; then
  collect_family
  exit 0
fi
if [[ "$REPLAY" == true ]]; then
  [[ -n "$SOURCE_BUNDLE" ]] || fail "--replay requires --source-bundle"
  if [[ -z "$RUN_ID" ]]; then RUN_ID="$(jq -r '.run_id // empty' "$SOURCE_BUNDLE/manifest.json" 2>/dev/null || true)"; fi
  [[ -n "$RUN_ID" ]] || fail "source manifest has no run id"
  replay_family "$SOURCE_BUNDLE" "$FORMAT"
  exit 0
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
