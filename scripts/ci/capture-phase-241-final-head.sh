#!/usr/bin/env bash
# Capture one completed ci.yml pull-request run at the exact frozen local SHA.
# The selectors below are deliberately fixed: caller-controlled selectors would let a
# receipt describe a convenient green run instead of the contributor CI contract.
set -euo pipefail

REPO="szTheory/sigra"
WORKFLOW="ci.yml"
SCHEMA_VERSION="sigra.phase-241-final-head/1"
LIBRARY_OWNER="Library tests shard"
LIBRARY_OWNER_STEP="Run contributor CI gate"
LIBRARY_AGGREGATOR="Library tests"
FAST_CHECKS="Fast checks (milestone/installer/contracts/snapshot/ledger guards)"
FAST_CHECKS_STEP="Phase 230 prohibition guards"
MAX_PAGES=10000

fail() { echo "capture-phase-241-final-head: FAIL: $*" >&2; exit 1; }
usage() {
  echo "usage: $0 --run-id ID --head-sha SHA --pr-number N --output PATH [--comment]" >&2
  exit 2
}

RUN_ID="" HEAD_SHA="" PR_NUMBER="" OUTPUT="" COMMENT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) [[ $# -ge 2 ]] || usage; RUN_ID="$2"; shift 2 ;;
    --head-sha) [[ $# -ge 2 ]] || usage; HEAD_SHA="$2"; shift 2 ;;
    --pr-number) [[ $# -ge 2 ]] || usage; PR_NUMBER="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || usage; OUTPUT="$2"; shift 2 ;;
    --comment) COMMENT=true; shift ;;
    *) fail "unknown_argument_$1" ;;
  esac
done
[[ "$RUN_ID" =~ ^[0-9]+$ ]] || fail "run_id_malformed"
[[ "$PR_NUMBER" =~ ^[0-9]+$ ]] || fail "pr_number_malformed"
[[ "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "head_sha_malformed"
[[ -n "$OUTPUT" ]] || usage
OUTPUT_DIR="$(dirname "$OUTPUT")"
[[ -d "$OUTPUT_DIR" ]] || fail "output_directory_missing"
command -v gh >/dev/null 2>&1 || fail "gh_not_found"
command -v jq >/dev/null 2>&1 || fail "jq_not_found"
command -v git >/dev/null 2>&1 || fail "git_not_found"
[[ "$(git rev-parse HEAD 2>/dev/null || true)" == "$HEAD_SHA" ]] || fail "local_head_sha_mismatch"
git diff --cached --quiet || fail "staged_changes_present"

TMPD="$(mktemp -d)"
cleanup() { rm -rf "$TMPD"; }
trap cleanup EXIT INT TERM

api() {
  local label endpoint stdout stderr
  label="$1"
  endpoint="$2"
  stdout="$TMPD/${label}.json"
  stderr="$TMPD/${label}.err"
  if gh api "$endpoint" >"$stdout" 2>"$stderr"; then
    cat "$stdout"
    return 0
  fi
  if grep -Eq 'HTTP[[:space:]]+403|\b403\b' "$stderr"; then
    fail "github_rate_limited_http_403: $(tr '\n' ' ' <"$stderr")"
  fi
  if grep -Eq 'HTTP[[:space:]]+429|\b429\b' "$stderr"; then
    fail "github_rate_limited_http_429: $(tr '\n' ' ' <"$stderr")"
  fi
  fail "github_api_request_failed_${label}: $(tr '\n' ' ' <"$stderr")"
}

# One rate-limit request happens before collection. A low value stops before the
# run request, and the reset value is carried into both diagnostic and receipt.
RATE_LIMIT="$(api rate_limit rate_limit)"
REMAINING="$(jq -r '.resources.core.remaining' <<<"$RATE_LIMIT")"
RESET="$(jq -r '.resources.core.reset' <<<"$RATE_LIMIT")"
[[ "$REMAINING" =~ ^[0-9]+$ && "$RESET" =~ ^[0-9]+$ ]] || fail "rate_limit_preflight_malformed"
(( REMAINING > 250 )) || fail "rate_limit_too_low: remaining=${REMAINING} reset=${RESET}"

PR="$(api pull_request "repos/${REPO}/pulls/${PR_NUMBER}")"
jq -e 'type == "object"' <<<"$PR" >/dev/null || fail "pr_payload_malformed"
[[ "$(jq -r '.number' <<<"$PR")" == "$PR_NUMBER" ]] || fail "pr_number_mismatch"
[[ "$(jq -r '.base.repo.full_name' <<<"$PR")" == "$REPO" ]] || fail "pr_base_repository_mismatch"
[[ "$(jq -r '.head.sha' <<<"$PR")" == "$HEAD_SHA" ]] || fail "pr_head_sha_mismatch"

RUN="$(api run "repos/${REPO}/actions/runs/${RUN_ID}")"
jq -e 'type == "object"' <<<"$RUN" >/dev/null || fail "run_payload_malformed"
RUN_HEAD="$(jq -r '.head_sha' <<<"$RUN")"
[[ "$RUN_HEAD" == "$HEAD_SHA" ]] || fail "run_head_sha_mismatch"
[[ "$(jq -r '.event' <<<"$RUN")" == pull_request ]] || fail "run_event_not_pull_request"
[[ "$(jq -r '.status' <<<"$RUN")" == completed ]] || fail "run_not_completed"
[[ "$(jq -r '.conclusion' <<<"$RUN")" == success ]] || fail "run_conclusion_not_success"
RUN_URL="$(jq -r '.html_url' <<<"$RUN")"
[[ "$RUN_URL" != null && -n "$RUN_URL" ]] || fail "run_url_missing"

MANIFEST="$TMPD/jobs.manifest.jsonl"
: >"$MANIFEST"
page=1
while :; do
  response="$(api "jobs_page_${page}" "repos/${REPO}/actions/runs/${RUN_ID}/jobs?filter=latest&per_page=100&page=${page}")" \
    || fail "jobs_pagination_not_exhausted"
  jq -e --argjson page "$page" '{page: $page, body: .}' <<<"$response" >>"$MANIFEST" || fail "jobs_payload_malformed"
  jobs_type="$(jq -r '.jobs | type' <<<"$response")"
  [[ "$jobs_type" == array ]] || fail "jobs_payload_malformed"
  count="$(jq '.jobs | length' <<<"$response")"
  [[ "$count" =~ ^[0-9]+$ ]] || fail "jobs_payload_malformed"
  (( count == 0 )) && break
  (( page < MAX_PAGES )) || fail "jobs_pagination_bound_reached"
  page=$((page + 1))
done

jq -s -e '
  ([.[].page] == [range(1; length + 1)]) and
  ([.[].body.total_count] | all(type == "number" and floor == . and . >= 0)) and
  ([.[].body.total_count] | unique | length == 1) and
  ((.[-1].body.jobs | type) == "array" and (.[-1].body.jobs | length == 0)) and
  (all(.[0:-1][]; (.body.jobs | type) == "array" and length > 0))
' "$MANIFEST" >/dev/null || fail "jobs_pagination_not_exhausted"
TOTAL="$(jq -s -r '.[0].body.total_count' "$MANIFEST")"
jq -s '[.[].body.jobs[]]' "$MANIFEST" >"$TMPD/jobs.json" || fail "jobs_payload_malformed"
ACTUAL="$(jq 'length' "$TMPD/jobs.json")"
[[ "$TOTAL" == "$ACTUAL" ]] || fail "jobs_total_count_disagreement"
jq -e --argjson run "$RUN_ID" '
  all(.[]; (.id | type) == "number" and .run_id == $run and .status == "completed" and
    (.conclusion | type) == "string" and (.conclusion | length) > 0) and
  (([.[].id] | unique | length) == ([.[].id] | length))
' "$TMPD/jobs.json" >/dev/null || fail "jobs_identity_or_completion_invalid"

require_job() {
  local name token selected
  name="$1"
  token="${2:-$1}"
  selected="$TMPD/job-$(tr -cd '[:alnum:]' <<<"$name").json"
  jq --arg name "$name" '[.[] | select(.name == $name)]' "$TMPD/jobs.json" >"$selected"
  local count
  count="$(jq 'length' "$selected")"
  (( count > 0 )) || fail "required_job_missing_${token}"
  (( count == 1 )) || fail "required_job_not_unique_${token}"
  jq -e '.[0].conclusion == "success"' "$selected" >/dev/null || fail "required_job_not_success_${token}"
  printf '%s' "$selected"
}
require_step() {
  local job_file name token selected
  job_file="$1"
  name="$2"
  token="$3"
  selected="$TMPD/step-$(tr -cd '[:alnum:]' <<<"$name").json"
  jq --arg name "$name" '.[0].steps | if type == "array" then [.[] | select(.name == $name)] else [] end' "$job_file" >"$selected"
  local count
  count="$(jq 'length' "$selected")"
  (( count > 0 )) || fail "required_step_missing_${token}"
  (( count == 1 )) || fail "required_step_not_unique_${token}"
  jq -e '.[0].status == "completed" and .[0].conclusion == "success"' "$selected" >/dev/null || fail "required_step_not_success_${token}"
  printf '%s' "$selected"
}

OWNER_FILE="$(require_job "$LIBRARY_OWNER" Library_tests_shard)"
OWNER_STEP_FILE="$(require_step "$OWNER_FILE" "$LIBRARY_OWNER_STEP" Run_contributor_CI_gate)"
AGGREGATOR_FILE="$(require_job "$LIBRARY_AGGREGATOR" Library_tests)"
FAST_FILE="$(require_job "$FAST_CHECKS" Fast_checks)"
FAST_STEP_FILE="$(require_step "$FAST_FILE" "$FAST_CHECKS_STEP" Phase_230_prohibition_guards)"

# Recheck after collecting the run and jobs so a PR that advances during the
# multi-request read cannot produce a receipt for a now-stale candidate.
PR_FINAL="$(api pull_request_final "repos/${REPO}/pulls/${PR_NUMBER}")"
jq -e 'type == "object"' <<<"$PR_FINAL" >/dev/null || fail "pr_payload_malformed"
[[ "$(jq -r '.number' <<<"$PR_FINAL")" == "$PR_NUMBER" ]] || fail "pr_number_mismatch"
[[ "$(jq -r '.base.repo.full_name' <<<"$PR_FINAL")" == "$REPO" ]] || fail "pr_base_repository_mismatch"
[[ "$(jq -r '.head.sha' <<<"$PR_FINAL")" == "$HEAD_SHA" ]] || fail "pr_head_sha_mismatch"

COLLECTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
jq -S -n \
  --arg schema "$SCHEMA_VERSION" --arg repo "$REPO" --arg workflow "$WORKFLOW" \
  --argjson run_id "$RUN_ID" --arg run_url "$RUN_URL" --arg head_sha "$HEAD_SHA" \
  --arg event pull_request --arg run_conclusion success --argjson pr_number "$PR_NUMBER" \
  --argjson remaining "$REMAINING" --argjson reset "$RESET" --arg collected_at "$COLLECTED_AT" \
  --slurpfile owner "$OWNER_FILE" --slurpfile owner_step "$OWNER_STEP_FILE" \
  --slurpfile aggregator "$AGGREGATOR_FILE" --slurpfile fast "$FAST_FILE" --slurpfile fast_step "$FAST_STEP_FILE" '
  {
    schema_version: $schema, repository: $repo, workflow: $workflow, run_id: $run_id,
    run_url: $run_url, head_sha: $head_sha, event: $event, run_conclusion: $run_conclusion,
    pr_number: $pr_number, rate_limit: {core_remaining: $remaining, core_reset: $reset},
    collected_at: $collected_at,
    library_owner: ($owner[0][0] | {id, name, run_id, html_url, conclusion} + {step: ($owner_step[0][0] | {name, conclusion})}),
    library_aggregator: ($aggregator[0][0] | {id, name, run_id, html_url, conclusion}),
    fast_checks: ($fast[0][0] | {id, name, run_id, html_url, conclusion} + {step: ($fast_step[0][0] | {name, conclusion})})
  }
' >"$TMPD/receipt.json" || fail "receipt_serialization_failed"
jq -e --arg sha "$HEAD_SHA" '
  .schema_version == "sigra.phase-241-final-head/1" and .head_sha == $sha and
  .library_owner.step.conclusion == "success" and .library_aggregator.conclusion == "success" and
  .fast_checks.step.conclusion == "success"
' "$TMPD/receipt.json" >/dev/null || fail "receipt_self_validation_failed"

OUTPUT_TMP="$(mktemp "$OUTPUT_DIR/.phase-241-final-head.XXXXXX")"
cp "$TMPD/receipt.json" "$OUTPUT_TMP"
mv -f "$OUTPUT_TMP" "$OUTPUT"

if [[ "$COMMENT" == true ]]; then
  BODY="$(printf 'sigra.phase-241-final-head/1\n```json\n%s\n```\n' "$(cat "$OUTPUT")")"
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$BODY" || fail "pr_comment_failed"
fi
