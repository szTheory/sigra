#!/usr/bin/env bash
# Capture the fixed Phase 235 historical Actions population as an attestation subject.
# This command deliberately has no caller-configurable repository, workflow, or window.
set -euo pipefail

REPO="szTheory/sigra"
WORKFLOW="ci.yml"
CUTOFF="2026-08-01T02:06:30Z"
ENDPOINT="2026-08-02T18:07:04Z"
MAX_PAGES=10000
RUN_IDS=(30686149095 30720751244 30722291400 30722736494 30723164608 30723565742 30723575804 30723593560 30723596945 30723600313 30723601060 30723605581 30723607878 30723608377 30723615281 30723622708 30729478819 30729487808 30729531710 30729534413 30729540143 30729540659 30734422326)

if [[ $# -ne 1 ]]; then
  echo "capture-terminal-ratification-evidence: FAIL: expected OUTPUT_PATH" >&2
  exit 2
fi
OUTPUT="$1"
TMPDIR_CAPTURE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CAPTURE"; rm -f "$OUTPUT"' ERR INT TERM
trap 'rm -rf "$TMPDIR_CAPTURE"' EXIT

fail() { echo "capture-terminal-ratification-evidence: FAIL: $*" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
command -v jq >/dev/null 2>&1 || fail "jq not found on PATH"

# Exactly one preflight. Collection is finite REST retrieval, not workflow polling.
REMAINING="$(gh api rate_limit --jq '.resources.core.remaining')" || fail "rate_limit_preflight_failed"
[[ "$REMAINING" =~ ^[0-9]+$ ]] || fail "rate_limit_preflight_malformed"
(( REMAINING > 250 )) || fail "rate_limit_remaining_at_or_below_250"

request_page() {
  local endpoint="$1" page="$2" out="$3"
  if ! gh api "${endpoint}&per_page=100&page=${page}" >"$out"; then
    # gh prints HTTP detail itself; do not retry 403/429 or any other API failure.
    fail "github_api_request_failed_page_${page}"
  fi
}

validate_manifest() {
  local manifest="$1" item_key="$2" label="$3"
  jq -e --arg key "$item_key" '
    if type != "array" or length == 0 then error("absent_terminal_empty_page") else . end
    | . as $pages
    | if all(.[]; (.page|type) == "number" and (.page|floor) == . and .page > 0 and (.body|type) == "object") then . else error("malformed_envelope") end
    | if ([.[].page] | sort) == [range(1; length + 1)] then . else error("non_contiguous_or_duplicate_page") end
    | if ([.[].body.total_count] | all(type == "number" and floor == . and . >= 0)) then . else error("malformed_total_count") end
    | if ([.[].body.total_count] | unique | length) == 1 then . else error("total_count_changed") end
    | if (.[-1].body[$key] | type) == "array" and (.[-1].body[$key] | length) == 0 then . else error("absent_terminal_empty_page") end
    | if ([.[0:-1][].body[$key] | length] | add // 0) == .[0].body.total_count then . else error("total_count_disagreement") end
    | if all(.[0:-1][]; (.body[$key] | type) == "array" and length > 0) then . else error("nonterminal_empty_page") end
    | ([.[].body[$key][]?.id] | if all(type == "number" or type == "string") then . else error("malformed_item_identity") end) as $ids
    | if ($ids | length) == ($ids | unique | length) then . else error("duplicate_item_id") end
  ' "$manifest" >/dev/null || fail "${label}_manifest_invalid"
}

collect_pages() {
  local endpoint="$1" item_key="$2" label="$3" manifest="$4"
  local page=1 response total minimum_pages items
  : >"$manifest"
  while :; do
    response="$TMPDIR_CAPTURE/${label}-${page}.json"
    request_page "$endpoint" "$page" "$response"
    jq -e --argjson page "$page" '{page: $page, body: .}' "$response" >>"$manifest" || fail "${label}_malformed_response"
    total="$(jq -r '.total_count' "$response")"
    [[ "$total" =~ ^[0-9]+$ ]] || fail "${label}_malformed_total_count"
    minimum_pages=$(( (total + 99) / 100 + 1 ))
    (( minimum_pages <= MAX_PAGES )) || fail "pagination_bound_reached"
    items="$(jq --arg key "$item_key" '.[$key] | if type == "array" then length else -1 end' "$response")"
    (( items >= 0 )) || fail "${label}_malformed_items"
    if (( items == 0 )); then break; fi
    (( page < MAX_PAGES )) || fail "pagination_bound_reached"
    page=$((page + 1))
  done
  validate_manifest "$manifest" "$item_key" "$label"
}

RUNS_MANIFEST="$TMPDIR_CAPTURE/runs.manifest.jsonl"
RUNS_ENDPOINT="repos/${REPO}/actions/workflows/${WORKFLOW}/runs?created=${CUTOFF}..${ENDPOINT}"
collect_pages "$RUNS_ENDPOINT" workflow_runs runs "$RUNS_MANIFEST"

# Reject clock inversions and malformed historical identities before any duration consumer sees them.
jq -s -e --arg cutoff "$CUTOFF" --arg endpoint "$ENDPOINT" '
  [.[].body.workflow_runs[]]
  | all(.[]; (.id|type) == "number" and (.event|type) == "string" and (.event|IN("pull_request"; "push"; "schedule")) and (.conclusion|type) == "string" and length > 0 and (.created_at|type) == "string" and (.updated_at|type) == "string" and .created_at >= $cutoff and .created_at <= $endpoint and .updated_at <= $endpoint and .updated_at >= .created_at)
' "$RUNS_MANIFEST" >/dev/null || fail "run_chronology_or_identity_invalid"

JOB_MANIFESTS="[]"
for run_id in "${RUN_IDS[@]}"; do
  manifest="$TMPDIR_CAPTURE/jobs-${run_id}.manifest.jsonl"
  collect_pages "repos/${REPO}/actions/runs/${run_id}/jobs?" jobs "jobs-${run_id}" "$manifest"
  jq -s -e '
    [.[].body.jobs[]]
    | all(.[]; (.id|type) == "number" and (.name|type) == "string" and length > 0 and (.conclusion|type) == "string" and length > 0 and (.started_at|type) == "string" and (.completed_at|type) == "string" and .completed_at >= .started_at)
  ' "$manifest" >/dev/null || fail "job_chronology_or_identity_invalid_run_${run_id}"
  JOB_MANIFESTS="$(jq -c --arg id "$run_id" --slurpfile pages "$manifest" '. + [{run_id: ($id|tonumber), pages: $pages}]' <<<"$JOB_MANIFESTS")"
done

jq -S -n --arg repository "$REPO" --arg workflow "$WORKFLOW" --arg cutoff "$CUTOFF" --arg endpoint "$ENDPOINT" --slurpfile run_pages "$RUNS_MANIFEST" --argjson jobs "$JOB_MANIFESTS" '
  def receipt($pages; $key): {
    requested_pages: [$pages[].page],
    data_page_count: ([$pages[] | select(.body[$key] | length > 0)] | length),
    terminal_page: $pages[-1].page,
    exhausted: true,
    total_count: $pages[0].body.total_count,
    pages: $pages
  };
  {schema_version: "sigra.terminal-ratification-receipt/v1", repository: $repository, workflow: $workflow,
   window: {cutoff: $cutoff, endpoint: $endpoint}, workflow_runs: receipt($run_pages; "workflow_runs"), jobs: $jobs}
' >"$OUTPUT" || fail "canonical_output_failed"

test -s "$OUTPUT" || fail "empty_canonical_output"
trap - ERR INT TERM
