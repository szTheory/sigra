#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
FIXTURE="$PHASE_DIR/253-CANARY-WORKFLOW.yml"
EVIDENCE="$PHASE_DIR/253-CANARY-EVIDENCE.json"
RATE_SOURCE="/tmp/sigra-253-canary-rate.json"
RULES_SOURCE="/tmp/sigra-253-effective-rules.json"
WORKFLOW_SOURCE="/tmp/sigra-253-registered-workflow.json"
REPO="szTheory/sigra"
WORKFLOW_ID="259268962"
MAX_REQUESTS=120
MAX_JOBS=45
MAX_MINUTES=60
WATCH_RESERVATION=8
SCENARIO=""
ALL_REMAINING=false
CHECK_ONLY=false
CANARY_STARTED_EPOCH=0

usage() {
  cat <<'EOF'
Usage: ci-gate-canary.sh (--scenario NAME | --remaining-scenarios) [--evidence PATH]
       ci-gate-canary.sh --check-only

Scenarios: full-pass, docs-only, actual-failure, missing-seam,
           unexpected-skip, cancelled
Runs only the sealed Phase 253 Gate Canary on a unique refs/heads/gsd/253-* branch.
--check-only validates local contracts and performs no GitHub request or mutation.
EOF
}

fail() { printf 'ci-gate-canary: FAIL: %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --scenario) (($# >= 2)) || fail '--scenario requires a value'; SCENARIO="$2"; shift 2 ;;
    --remaining-scenarios) ALL_REMAINING=true; shift ;;
    --evidence) (($# >= 2)) || fail '--evidence requires a path'; EVIDENCE="$2"; shift 2 ;;
    --check-only) CHECK_ONLY=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

if [[ "$CHECK_ONLY" == true ]]; then
  [[ -f "$FIXTURE" ]] || fail "fixture workflow missing: $FIXTURE"
  [[ -f "$ROOT/scripts/ci/ci-browser-records.mjs" && -f "$ROOT/scripts/ci/honest-skip-verdict.sh" ]] || fail 'candidate shared gate helpers missing'
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --help >/dev/null
  grep -Fq 'name: Phase 253 Gate Canary' "$FIXTURE" || fail 'fixture workflow name changed'
  grep -Fq 'workflow_dispatch:' "$FIXTURE" || fail 'fixture is not manually dispatchable'
  ! grep -Eq '^  (push|pull_request|schedule|workflow_run):' "$FIXTURE" || fail 'fixture has an unapproved trigger'
  for path in .github/workflows/ci-observe.yml .github/workflows/release-pr-automerge.yml .github/workflows/release-run-observer.yml; do
    ! rg -q 'Phase 253 Gate Canary' "$ROOT/$path" || fail "fixture name matches a downstream workflow filter: $path"
  done
  echo 'ci-gate-canary: local fixture contract passed'
  exit 0
fi

[[ "$ALL_REMAINING" == true || -n "$SCENARIO" ]] || { usage >&2; exit 2; }
[[ "$ALL_REMAINING" == false || -z "$SCENARIO" ]] || fail 'choose one scenario mode'
valid_scenario() { case "$1" in full-pass|docs-only|actual-failure|missing-seam|unexpected-skip|cancelled) return 0;; *) return 1;; esac; }
if [[ "$ALL_REMAINING" == false ]]; then valid_scenario "$SCENARIO" || fail "unknown scenario: $SCENARIO"; fi

cd "$ROOT"
[[ "$(git rev-parse --show-toplevel)" == "$ROOT" ]] || fail 'checkout root changed'
[[ -f "$FIXTURE" && -f "$RATE_SOURCE" && -f "$RULES_SOURCE" && -f "$WORKFLOW_SOURCE" ]] || fail 'frozen fixture or original preflight inputs are missing'
[[ -f "$PHASE_DIR/253-PREHOST-REVIEW.md" ]] || fail 'pre-host review report is missing'
if rg -n '^### CR-.*(ci-browser-records|honest-skip-verdict|ci-gate)' "$PHASE_DIR/253-PREHOST-REVIEW.md"; then
  fail 'pre-host review found a blocking issue in a canary gate helper'
fi
grep -Fq '259268962' "$WORKFLOW_SOURCE" || fail 'registered workflow identity differs from frozen source'
jq -e '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | sort == (["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"] | sort)' "$RULES_SOURCE" >/dev/null || fail 'effective required-check names differ from the frozen five-name contract'
for path in .github/workflows/ci-observe.yml .github/workflows/release-pr-automerge.yml .github/workflows/release-run-observer.yml; do
  if rg -q 'Phase 253 Gate Canary' "$ROOT/$path"; then fail "distinct canary name is captured by downstream workflow filter $path"; fi
done

# Never let a rerun discard deterministic diagnostics or reuse a halted freeze.
# This guard precedes every gh invocation, including local token lookup.
if [[ -f "$EVIDENCE" ]] && jq -e '.status == "halted" or ((.diagnostics // {}) | length > 0)' "$EVIDENCE" >/dev/null; then
  fail 'halted evidence requires a separately authorized new freeze; existing diagnostics cannot be retried'
fi
gh auth token >/dev/null 2>&1 || fail 'GitHub authentication is unavailable' 
INITIAL_CALLS=3
if [[ -f "$EVIDENCE" ]]; then
  REQUEST_COUNT="$(jq -r '.budget.request_count // 3' "$EVIDENCE")"
  CANARY_STARTED_EPOCH="$(jq -r '.budget.started_epoch // 0' "$EVIDENCE")"
  FIXTURE_REF="$(jq -r '.expected.fixture_ref // empty' "$EVIDENCE")"
  CANDIDATE_SHA="$(jq -r '.expected.candidate_sha // empty' "$EVIDENCE")"
  FIXTURE_SHA="$(jq -r '.expected.workflow_sha // empty' "$EVIDENCE")"
  FIXTURE_BLOB="$(jq -r '.expected.workflow_blob // empty' "$EVIDENCE")"
else
  REQUEST_COUNT="$INITIAL_CALLS"
  FIXTURE_REF=""
  CANDIDATE_SHA=""
  FIXTURE_SHA=""
  FIXTURE_BLOB=""
fi
[[ "$REQUEST_COUNT" =~ ^[0-9]+$ ]] || fail 'frozen request ledger is malformed'

check_budget() {
  local reserve="${1:-0}"
  (( REQUEST_COUNT + reserve <= MAX_REQUESTS )) || fail "GitHub request budget exhausted: used=$REQUEST_COUNT reserve=$reserve max=$MAX_REQUESTS"
  if (( CANARY_STARTED_EPOCH > 0 )); then
    (( $(date +%s) - CANARY_STARTED_EPOCH < MAX_MINUTES * 60 )) || fail "hosted canary exceeded its fixed ${MAX_MINUTES}-minute clock"
  fi
}

REQUEST_LEDGER="$PHASE_DIR/253-CANARY-REQUESTS.json"

preserve_request_ledger() {
  [[ -f "$REQUEST_LEDGER" ]] || return 0
  local sequence prior ref
  sequence="$(jq '.requests | length' "$REQUEST_LEDGER")"
  prior="$(git hash-object -w "$REQUEST_LEDGER")"
  ref="refs/gsd/phase253-07-canary-request-ledger/$sequence"
  if git show-ref --verify --quiet "$ref"; then
    [[ "$(git rev-parse "$ref")" == "$prior" ]] || fail "request ledger preservation ref changed: $ref"
  else
    git update-ref "$ref" "$prior"
  fi
  [[ "$(git show "$ref" | shasum -a 256 | awk '{print $1}')" == "$(shasum -a 256 "$REQUEST_LEDGER" | awk '{print $1}')" ]] || fail 'request ledger prior bytes failed read-back'
}

log_request() {
  [[ -f "$REQUEST_LEDGER" ]] || return 0
  local endpoint="$1" kind="${2:-observed}" reserve="${3:-0}" temp="${REQUEST_LEDGER}.tmp"
  preserve_request_ledger
  jq --arg endpoint "$endpoint" --arg kind "$kind" --argjson reserve "$reserve" \
    '.requests += [{sequence:((.requests|length)+1),endpoint:$endpoint,kind:$kind,reserved_calls:$reserve}]' \
    "$REQUEST_LEDGER" > "$temp"
  mv "$temp" "$REQUEST_LEDGER"
}

api_get() {
  local endpoint="$1" target="$2"
  check_budget 0
  ((REQUEST_COUNT += 1))
  check_budget 0
  if [[ "$endpoint" == rate_limit ]]; then
    gh api rate_limit > "$target" || fail 'GitHub rate-limit API request failed'
  else
    gh api "repos/$REPO/$endpoint" > "$target" || fail "GitHub API request failed: $endpoint"
  fi
  jq -e . "$target" >/dev/null || fail "GitHub API returned invalid JSON for $endpoint"
  log_request "GET $endpoint"
  record_budget
}

record_budget() {
  [[ -f "$EVIDENCE" ]] || return 0
  local temp="${EVIDENCE}.tmp" elapsed now
  now="$(date +%s)"
  elapsed=0
  if (( CANARY_STARTED_EPOCH > 0 )); then elapsed=$((now - CANARY_STARTED_EPOCH)); fi
  preserve_evidence
  jq --argjson count "$REQUEST_COUNT" --argjson elapsed "$elapsed" --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" \
    '.budget.request_count=$count | .budget.elapsed_seconds=$elapsed | .preserved_revisions += [{ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "$temp"
  mv "$temp" "$EVIDENCE"
}

preserve_evidence() {
  PRIOR_EVIDENCE_STATUS="$(git status --porcelain=v1 -- "$EVIDENCE" | tr -d '\n')"
  PRIOR_EVIDENCE_SHA="$(shasum -a 256 "$EVIDENCE" | awk '{print $1}')"
  local blob sequence ref
  blob="$(git hash-object -w "$EVIDENCE")"
  sequence="$(jq '.preserved_revisions | length' "$EVIDENCE")"
  ref="refs/gsd/phase253-07-canary-evidence/$sequence"
  if git show-ref --verify --quiet "$ref"; then
    [[ "$(git rev-parse "$ref")" == "$blob" ]] || fail "evidence preservation ref changed: $ref"
  else
    git update-ref "$ref" "$blob"
  fi
  [[ "$(git show "$ref" | shasum -a 256 | awk '{print $1}')" == "$PRIOR_EVIDENCE_SHA" ]] || fail 'prior evidence bytes failed read-back'
  PRIOR_EVIDENCE_REF="$ref"
}

watch_run() {
  local run_id="$1" description="$2" rate_file core_left started pid result watch_log
  rate_file="$(mktemp /tmp/253-canary-watch-rate.XXXXXX.json)"
  api_get rate_limit "$rate_file"
  core_left="$(jq -r '.resources.core.remaining // 0' "$rate_file")"
  (( core_left > 250 )) || fail "GitHub core API budget is at or below 250 before watch (remaining=$core_left)"
  check_budget "$WATCH_RESERVATION"
  ((REQUEST_COUNT += WATCH_RESERVATION))
  log_request "gh run watch $run_id --interval 60 ($description)" reserved "$WATCH_RESERVATION"
  record_budget
  started=$SECONDS
  watch_log="$(mktemp /tmp/253-canary-watch.XXXXXX.log)"
  gh run watch "$run_id" --repo szTheory/sigra --compact --interval 60 --exit-status >"$watch_log" 2>&1 &
  pid=$!
  result=0
  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS - started >= 240 )); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 5
  done
  if wait "$pid"; then result=0; else result=$?; fi
  cat "$watch_log"
  if rg -qi 'HTTP[^0-9]*(403|429)|API rate limit exceeded|secondary rate limit' "$watch_log"; then return 77; fi
  check_budget 0
  return "$result"
}

RATE_NOW="$RATE_SOURCE"
CORE_LEFT="$(jq -r '.resources.core.remaining // 0' "$RATE_NOW")"
(( CORE_LEFT > 250 )) || fail "GitHub core API budget is at or below 250 (remaining=$CORE_LEFT)"

# Freeze the three parent preflight responses byte-for-byte and prove that the
# repository evidence writer can survive the external scoped-ref push.
for pair in "rate:$RATE_SOURCE:253-CANARY-PREFLIGHT-rate.json" "rules:$RULES_SOURCE:253-CANARY-PREFLIGHT-effective-rules.json" "workflow:$WORKFLOW_SOURCE:253-CANARY-PREFLIGHT-registered-workflow.json"; do
  IFS=: read -r label source destination <<< "$pair"
  target="$PHASE_DIR/$destination"
  if [[ ! -e "$target" ]]; then cp "$source" "$target"; fi
  cmp -s "$source" "$target" || fail "frozen $label preflight bytes changed at $target"
done
if [[ ! -e "$REQUEST_LEDGER" ]]; then
  jq -n --slurpfile rate "$RATE_SOURCE" --slurpfile rules "$RULES_SOURCE" --slurpfile workflow "$WORKFLOW_SOURCE" \
    '{schema_version:"sigra.canary-request-ledger/v1",limit:120,requests:[
      {sequence:1,source:"parent preflight",endpoint:"GET /rate_limit",response:$rate[0]},
      {sequence:2,source:"parent preflight",endpoint:"GET /repos/szTheory/sigra/rules/branches/main",response:$rules[0]},
      {sequence:3,source:"parent preflight",endpoint:"GET /repos/szTheory/sigra/actions/workflows/ci.yml",response:$workflow[0]}
    ],watch_request_reservation_per_run:8,redirect_reservation_per_artifact_download:2}' > "$REQUEST_LEDGER"
fi
LEDGER_BLOB="$(git hash-object -w "$REQUEST_LEDGER")"
LEDGER_REF="refs/gsd/phase253-07-canary-preflight"
if git show-ref --verify --quiet "$LEDGER_REF"; then
  [[ "$(git rev-parse "$LEDGER_REF")" == "$LEDGER_BLOB" ]] || fail 'existing canary preflight preservation ref has different bytes'
else
  git update-ref "$LEDGER_REF" "$LEDGER_BLOB"
fi
[[ "$(git show "$LEDGER_REF" | shasum -a 256 | awk '{print $1}')" == "$(shasum -a 256 "$REQUEST_LEDGER" | awk '{print $1}')" ]] || fail 'canary evidence writer read-back did not match exact request-ledger bytes'

if [[ -z "$CANDIDATE_SHA" ]]; then
  CANDIDATE_SHA="$(git rev-parse HEAD)"
  BRANCH_SUFFIX="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  FIXTURE_REF="refs/heads/gsd/253-gate-canary-fixture-$BRANCH_SUFFIX"
  FIXTURE_BLOB="$(git hash-object -w "$FIXTURE")"
  TMP_INDEX="$(mktemp /tmp/253-canary-index.XXXXXX)"
  rm -f "$TMP_INDEX"
  export GIT_INDEX_FILE="$TMP_INDEX"
  git read-tree "$CANDIDATE_SHA"
  git update-index --add --cacheinfo "100644,$FIXTURE_BLOB,.github/workflows/ci.yml"
  FIXTURE_TREE="$(git write-tree)"
  FIXTURE_SHA="$(printf 'Phase 253 Gate Canary fixture\n' | git commit-tree "$FIXTURE_TREE" -p "$CANDIDATE_SHA")"
  unset GIT_INDEX_FILE
  rm -f "$TMP_INDEX"
  ((REQUEST_COUNT += 2)); check_budget "$WATCH_RESERVATION"
  log_request "create-only push $FIXTURE_SHA to $FIXTURE_REF"
  log_request "read back exact scoped ref $FIXTURE_REF"
  FIXTURE_BRANCH="${FIXTURE_REF#refs/heads/}"
  CANARY_STARTED_EPOCH="$(date +%s)"
  jq -n --slurpfile rate "$RATE_SOURCE" --slurpfile rules "$RULES_SOURCE" --slurpfile workflow "$WORKFLOW_SOURCE" \
    --arg candidate "$CANDIDATE_SHA" --arg fixture_ref "$FIXTURE_REF" --arg fixture_sha "$FIXTURE_SHA" --arg blob "$FIXTURE_BLOB" \
    --argjson request_count "$REQUEST_COUNT" --argjson started_epoch "$CANARY_STARTED_EPOCH" \
    '{schema_version:"sigra.hosted-gate-canary/v1",repository:"szTheory/sigra",expected:{candidate_sha:$candidate,fixture_ref:$fixture_ref,fixture_ref_state:"pending",workflow_id:259268962,workflow_path:".github/workflows/ci.yml",workflow_name:"Phase 253 Gate Canary",workflow_sha:$fixture_sha,workflow_blob:$blob},preflight:{initial_rate_limit:$rate[0],effective_rules:$rules[0],registered_workflow:$workflow[0]},budget:{max_requests:120,request_count:$request_count,initial_requests:3,max_jobs:45,max_minutes:60,watch_request_reservation:8,started_epoch:$started_epoch,actual_jobs:0},preserved_revisions:[],scenarios:{},separate_verifier:{status:"pending"}}' > "$EVIDENCE"
  preserve_evidence
  jq --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" \
    '.preserved_revisions += [{ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
  git push origin "$FIXTURE_SHA:$FIXTURE_REF" || fail 'create-only push of scoped fixture ref failed'
  git ls-remote --exit-code origin "$FIXTURE_REF" | awk -v want="$FIXTURE_SHA" '$1 == want {ok=1} END {exit !ok}' || fail 'pushed fixture ref did not read back at the expected commit'
  git cat-file -e "$FIXTURE_SHA:.github/workflows/ci.yml" || fail 'fixture workflow blob is not in the immutable ref'
  FOUND_WORKFLOW_BLOB="$(git rev-parse "$FIXTURE_SHA:.github/workflows/ci.yml")"
  [[ "$FOUND_WORKFLOW_BLOB" == "$FIXTURE_BLOB" ]] || fail 'fixture workflow blob identity changed'
  preserve_evidence
  jq --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" \
    '.expected.fixture_ref_state="verified" | .preserved_revisions += [{ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
else
  FOUND_WORKFLOW_BLOB="$(git rev-parse "$FIXTURE_SHA:.github/workflows/ci.yml" 2>/dev/null || true)"
  [[ "$FOUND_WORKFLOW_BLOB" == "$FIXTURE_BLOB" ]] || fail 'saved fixture source identities do not resolve locally'
fi
record_budget

FIXTURE_BRANCH="${FIXTURE_REF#refs/heads/}"
if [[ "$ALL_REMAINING" == true ]]; then
  SCENARIOS=(docs-only actual-failure missing-seam unexpected-skip cancelled)
else
  SCENARIOS=("$SCENARIO")
fi

dispatch_scenario() {
  local case_name="$1" run_list run_id run_json jobs_json artifacts_json artifact_id archive receipt_tmp reserve current_jobs new_jobs
  jq -e --arg name "$case_name" '.scenarios[$name] == null' "$EVIDENCE" >/dev/null || fail "scenario already has a receipt: $case_name"
  current_jobs="$(jq -r '.budget.actual_jobs // 0' "$EVIDENCE")"
  (( current_jobs + 6 <= MAX_JOBS )) || fail "dispatch would exceed the $MAX_JOBS-job ceiling"
  [[ "$case_name" == full-pass ]] || check_budget "$WATCH_RESERVATION"
  ((REQUEST_COUNT += 1))
  check_budget "$WATCH_RESERVATION"
  log_request "dispatch scenario=$case_name ref=$FIXTURE_BRANCH"
  gh workflow run .github/workflows/ci.yml --repo "$REPO" --ref "$FIXTURE_BRANCH" \
    -f "scenario=$case_name" -f "candidate_sha=$CANDIDATE_SHA" -f "fixture_sha=$FIXTURE_SHA" -f "fixture_blob=$FIXTURE_BLOB" || fail "dispatch failed for $case_name"
  record_budget
  run_list="$(mktemp /tmp/253-canary-runs.XXXXXX.json)"
  sleep 5
  api_get "actions/workflows/$WORKFLOW_ID/runs?event=workflow_dispatch&branch=$FIXTURE_BRANCH&per_page=100" "$run_list"
  run_id="$(jq -r --arg branch "$FIXTURE_BRANCH" --arg sha "$FIXTURE_SHA" --arg title "Phase 253 Gate Canary / $case_name /" '[.workflow_runs[] | select(.workflow_id==259268962 and .head_branch==$branch and .head_sha==$sha and .event=="workflow_dispatch" and (.display_title|startswith($title)))] | sort_by(.run_number) | last | .id // empty' "$run_list")"
  [[ -n "$run_id" ]] || fail "dispatch receipt not found for $case_name"
  if [[ "$case_name" == cancelled ]]; then
    jq -e --argjson run_id "$run_id" --arg branch "$FIXTURE_BRANCH" --arg sha "$FIXTURE_SHA" \
      '.workflow_runs[] | select(.id==$run_id and .event=="workflow_dispatch" and .head_branch==$branch and .head_sha==$sha and .workflow_id==259268962)' \
      "$run_list" >/dev/null || fail 'refusing to cancel a run whose fixture identity is not exact'
    ((REQUEST_COUNT += 1)); check_budget 0
    log_request "gh run cancel identified fixture run id=$run_id" reserved 1
    record_budget
    gh run cancel "$run_id" --repo "$REPO" || fail 'identified canary cancellation failed'
  fi
  local watch_status
  if watch_run "$run_id" "$case_name"; then watch_status=0; else watch_status=$?; fi
  record_budget
  (( watch_status != 124 )) || fail "watch exceeded its reserved four-minute window for $case_name"
  (( watch_status != 77 )) || fail "watch received a GitHub 403/429 rate-limit response; stop until reset"
  run_json="$(mktemp /tmp/253-canary-run.XXXXXX.json)"
  jobs_json="$(mktemp /tmp/253-canary-jobs.XXXXXX.json)"
  artifacts_json="$(mktemp /tmp/253-canary-artifacts.XXXXXX.json)"
  api_get "actions/runs/$run_id" "$run_json"
  api_get "actions/runs/$run_id/jobs?per_page=100" "$jobs_json"
  api_get "actions/runs/$run_id/artifacts?per_page=100" "$artifacts_json"
  local run_attempt conclusion
  run_attempt="$(jq -r '.run_attempt' "$run_json")"
  conclusion="$(jq -r '.conclusion // ""' "$run_json")"
  if [[ "$conclusion" == failure ]]; then
    ((REQUEST_COUNT += 2)); check_budget 0
    log_request "GET actions/runs/$run_id/logs including redirect" reserved 2
    record_budget
    failed_logs="$(mktemp /tmp/253-canary-failed-logs.XXXXXX.zip)"
    gh api "repos/$REPO/actions/runs/$run_id/logs" > "$failed_logs" || fail "failed-log retrieval failed for run $run_id"
  fi
  current_jobs="$(jq -r '.budget.actual_jobs // 0' "$EVIDENCE")"
  new_jobs="$(jq -r '[.jobs[] | select(.conclusion != "skipped")] | length' "$jobs_json")"
  (( current_jobs + new_jobs <= MAX_JOBS )) || fail "hosted execution count exceeded $MAX_JOBS jobs"
  receipt_tmp="$(mktemp /tmp/253-canary-receipt.XXXXXX.json)"
  if [[ "$case_name" == cancelled ]]; then
    jq -n --slurpfile run "$run_json" --slurpfile jobs "$jobs_json" --slurpfile artifacts "$artifacts_json" \
      --arg run_id "$run_id" --argjson attempt "$run_attempt" '{run_id:$run_id,run_attempt:$attempt,run:$run[0],jobs:$jobs[0],artifacts:$artifacts[0]}' > "$receipt_tmp"
  else
    artifact_id="$(jq -r --arg name "gate-canary-$case_name-$run_id-$run_attempt" '[.artifacts[] | select(.name==$name and .expired==false)] | if length==1 then .[0].id else empty end' "$artifacts_json")"
    [[ -n "$artifact_id" ]] || fail "expected same-run retained artifact missing for $case_name"
    archive="$(mktemp /tmp/253-canary-artifact.XXXXXX.zip)"
    ((REQUEST_COUNT += 2)); check_budget 0
    log_request "GET artifact ZIP id=$artifact_id including redirect" observed 2
    record_budget
    gh api "repos/$REPO/actions/artifacts/$artifact_id/zip" > "$archive" || fail "artifact download failed for $case_name"
    local artifact_data
    artifact_data="$(python3 - "$archive" <<'PY'
import base64, hashlib, json, sys, zipfile
archive_path=sys.argv[1]
raw=open(archive_path,'rb').read()
with zipfile.ZipFile(archive_path) as bundle:
    names=[name for name in bundle.namelist() if not name.endswith('/')]
    if names != ['canary-result.json']:
        raise SystemExit('unexpected canary artifact contents: '+repr(names))
    content=bundle.read('canary-result.json')
record=json.loads(content)
print(json.dumps({'archive_sha256':hashlib.sha256(raw).hexdigest(),'archive_base64':base64.b64encode(raw).decode(),
  'file':{'content':content.decode(),'sha256':hashlib.sha256(content).hexdigest(),'json':record}}))
PY
)" || fail "retained artifact is malformed for $case_name"
    jq -n --slurpfile run "$run_json" --slurpfile jobs "$jobs_json" --slurpfile artifacts "$artifacts_json" \
      --arg run_id "$run_id" --argjson attempt "$run_attempt" --arg artifact_id "$artifact_id" --argjson retained "$artifact_data" \
      '{run_id:$run_id,run_attempt:$attempt,run:$run[0],jobs:$jobs[0],artifacts:$artifacts[0],retained_artifact:{artifact_id:$artifact_id,archive_sha256:$retained.archive_sha256,archive_base64:$retained.archive_base64,files:{"canary-result.json":$retained.file}}}' > "$receipt_tmp"
  fi
  preserve_evidence
  preserve_evidence
  jq --arg scenario "$case_name" --slurpfile receipt "$receipt_tmp" --argjson count "$REQUEST_COUNT" --argjson jobs "$((current_jobs + new_jobs))" --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" \
    '.scenarios[$scenario]=$receipt[0] | .budget.request_count=$count | .budget.actual_jobs=$jobs | .preserved_revisions += [{ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --evidence "$EVIDENCE" --scenario "$case_name"
  record_budget
  [[ "$conclusion" == success && "$case_name" == actual-failure || "$conclusion" == success && "$case_name" == missing-seam || "$conclusion" == success && "$case_name" == unexpected-skip ]] && fail "negative source unexpectedly concluded success: $case_name"
}

for current_scenario in "${SCENARIOS[@]}"; do dispatch_scenario "$current_scenario"; done

if [[ "$ALL_REMAINING" == true ]]; then
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --evidence "$EVIDENCE" --scenario sources || fail 'source matrix is incomplete before separate verifier dispatch'
  MATRIX_B64="$(python3 - "$EVIDENCE" <<'PY'
import base64,sys
print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())
PY
)"
  current_jobs="$(jq -r '.budget.actual_jobs // 0' "$EVIDENCE")"
  (( current_jobs + 1 <= MAX_JOBS )) || fail "separate verifier would exceed the $MAX_JOBS-job ceiling"
  ((REQUEST_COUNT += 1)); check_budget "$WATCH_RESERVATION"
  log_request "dispatch separate verifier ref=$FIXTURE_BRANCH"
  gh workflow run .github/workflows/ci.yml --repo "$REPO" --ref "$FIXTURE_BRANCH" \
    -f 'scenario=verifier' -f "candidate_sha=$CANDIDATE_SHA" -f "fixture_sha=$FIXTURE_SHA" \
    -f "fixture_blob=$FIXTURE_BLOB" -f "matrix_evidence=$MATRIX_B64" || fail 'separate verifier dispatch failed'
  record_budget
  # The verifier run is found by its distinct workflow display title and exact fixture identity.
  VERIFY_LIST="$(mktemp /tmp/253-canary-verifier-runs.XXXXXX.json)"
  sleep 5
  api_get "actions/workflows/$WORKFLOW_ID/runs?event=workflow_dispatch&branch=$FIXTURE_BRANCH&per_page=100" "$VERIFY_LIST"
  VERIFY_ID="$(jq -r --arg branch "$FIXTURE_BRANCH" --arg sha "$FIXTURE_SHA" '[.workflow_runs[] | select(.head_branch==$branch and .head_sha==$sha and .event=="workflow_dispatch" and (.display_title|startswith("Phase 253 Gate Canary / verifier /")))] | sort_by(.run_number) | last | .id // empty' "$VERIFY_LIST")"
  [[ -n "$VERIFY_ID" ]] || fail 'separate verifier run was not created'
  if watch_run "$VERIFY_ID" 'separate verifier'; then watch_status=0; else watch_status=$?; fi
  (( watch_status != 124 )) || fail 'separate verifier watch exceeded its reservation'
  (( watch_status != 77 )) || fail 'separate verifier watch received a GitHub 403/429; stop until reset'
  VERIFY_RUN="$(mktemp /tmp/253-canary-verifier-run.XXXXXX.json)"
  VERIFY_JOBS="$(mktemp /tmp/253-canary-verifier-jobs.XXXXXX.json)"
  api_get "actions/runs/$VERIFY_ID" "$VERIFY_RUN"
  api_get "actions/runs/$VERIFY_ID/jobs?per_page=100" "$VERIFY_JOBS"
  new_jobs="$(jq -r '[.jobs[] | select(.conclusion != "skipped")] | length' "$VERIFY_JOBS")"
  (( current_jobs + new_jobs <= MAX_JOBS )) || fail "separate verifier exceeded the $MAX_JOBS-job ceiling"
  preserve_evidence
  jq --argjson id "$VERIFY_ID" --slurpfile run "$VERIFY_RUN" --slurpfile jobs "$VERIFY_JOBS" --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" \
    '.separate_verifier={status:"passed",run_id:($id|tostring),job_conclusion:$run[0].conclusion,run:$run[0],jobs:$jobs[0]} | .budget.actual_jobs+=([$jobs[0].jobs[] | select(.conclusion != "skipped")] | length) | .budget.request_count+=(0) | .preserved_revisions += [{ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --evidence "$EVIDENCE" --scenario matrix
fi

record_budget
[[ "$REQUEST_COUNT" -le "$MAX_REQUESTS" ]] || fail 'request budget exceeded'
echo "ci-gate-canary: retained evidence at $EVIDENCE (requests=$REQUEST_COUNT/$MAX_REQUESTS; job ceiling=$MAX_JOBS; time ceiling=${MAX_MINUTES}m)"
