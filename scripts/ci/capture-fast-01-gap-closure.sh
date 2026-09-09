#!/usr/bin/env bash
# Capture the post-remediation FAST-01 population without reopening old evidence.
set -euo pipefail

REPO="szTheory/sigra"
WORKFLOW="ci.yml"
EVENT="pull_request"
CUTOFF_SHA="54c33e904155a454255952666711c882afdd06e4"
CUTOFF="2026-08-03T21:37:08Z"
CUTOFF_EPOCH="1785793028"
MAX_PAGES=10000
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OLD_RECEIPT="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.json"

usage() { echo "usage: $0 --readiness OUTPUT | --protected-output OUTPUT --endpoint UTC" >&2; exit 2; }
fail() { echo "capture-fast-01-gap-closure: FAIL: $*" >&2; exit 1; }
sha256() { shasum -a 256 | awk '{print $1}'; }

MODE="" OUTPUT="" ENDPOINT=""
case "$#" in
  2) [[ "$1" == "--readiness" ]] || usage; MODE=readiness; OUTPUT="$2" ;;
  4) [[ "$1" == "--protected-output" && "$3" == "--endpoint" ]] || usage; MODE=protected; OUTPUT="$2"; ENDPOINT="$4" ;;
  *) usage ;;
esac

command -v gh >/dev/null 2>&1 || fail "gh_cli_not_found"
command -v jq >/dev/null 2>&1 || fail "jq_not_found"
[[ -f "$OLD_RECEIPT" ]] || fail "immutable_prior_receipt_missing"
git merge-base --is-ancestor "$CUTOFF_SHA" origin/main || fail "cutoff_not_on_origin_main"
[[ "$(git show -s --format=%ct "$CUTOFF_SHA")" == "$CUTOFF_EPOCH" ]] || fail "cutoff_timestamp_mismatch"

# The approved two-PR evidence design deliberately records digests from the
# remediation merge, not a later evidence-only main commit. Verify those blobs
# directly at the immutable cutoff so later receipt-validation code cannot alter
# the historical evidence claim.
while IFS=$'\t' read -r file_name expected; do
  actual="$(git show "$CUTOFF_SHA:$file_name" | sha256)" || fail "cutoff_blob_missing_${file_name}"
  [[ "$actual" == "$expected" ]] || fail "cutoff_blob_digest_mismatch_${file_name}"
done < <(jq -r '.file_digests | to_entries[] | "\(.key)\t\(.value)"' "$ROOT/.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEDIATION.json")

DATE_BIN="/usr/bin/date"; [[ -x "$DATE_BIN" ]] || DATE_BIN="/bin/date"
if [[ "$MODE" == readiness ]]; then ENDPOINT="$($DATE_BIN -u +%Y-%m-%dT%H:%M:%SZ)"; fi
[[ "$ENDPOINT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || fail "endpoint_malformed"
[[ "$ENDPOINT" > "$CUTOFF" ]] || fail "endpoint_at_or_before_cutoff"

RATE_LIMIT="$(gh api rate_limit 2>/dev/null || true)"
REMAINING="$(printf '%s' "$RATE_LIMIT" | jq -r '.resources.core.remaining // empty' 2>/dev/null || true)"
[[ "$REMAINING" =~ ^[0-9]+$ ]] || fail "rate_limit_preflight_failed"
(( REMAINING > 250 )) || fail "rate_limit_remaining_at_or_below_250"
RESET="$(printf '%s' "$RATE_LIMIT" | jq -r '.resources.core.reset // empty' 2>/dev/null || true)"; [[ -n "$RESET" ]] || RESET=null

OUTDIR="$(dirname -- "$OUTPUT")"; [[ -d "$OUTDIR" ]] || fail "output_directory_missing"
TMP="$(mktemp -d)"; OUTTMP="$(mktemp "$OUTDIR/.fast-01-gap-closure.XXXXXX")"
trap 'rm -rf "$TMP"; rm -f "$OUTTMP"' EXIT
MANIFEST="$TMP/pages.jsonl"; : > "$MANIFEST"; page=1
while :; do
  response="$TMP/page-$page.json"
  api="repos/${REPO}/actions/workflows/${WORKFLOW}/runs?created=${CUTOFF}..${ENDPOINT}&per_page=100&page=${page}"
  gh api "$api" >"$response" || fail "github_api_request_failed_page_${page}"
  jq -e --argjson page "$page" '{page:$page,body:.}' "$response" >>"$MANIFEST" || fail "malformed_page_${page}"
  count="$(jq '.workflow_runs | if type == "array" then length else -1 end' "$response")"
  (( count >= 0 )) || fail "malformed_runs_page_${page}"
  (( count == 0 )) && break
  (( page < MAX_PAGES )) || fail "pagination_bound_reached"
  page=$((page + 1))
done

jq -s -e --arg cutoff "$CUTOFF" --arg endpoint "$ENDPOINT" --slurpfile old "$OLD_RECEIPT" '
  if length == 0 then error("no_pages") else . end
  | if ([.[].page] | sort) == [range(1; length + 1)] then . else error("non_contiguous_pages") end
  | if (.[-1].body.workflow_runs | type == "array" and length == 0) then . else error("missing_terminal_empty_page") end
  | if all(.[0:-1][]; (.body.workflow_runs | type == "array" and length > 0)) then . else error("empty_nonterminal_page") end
  # The endpoint query can include PR runs which are not terminal yet. They
  # cannot contribute a complete wall interval, so the population is every
  # terminal PR conclusion rather than only successful PR runs.
  | ([.[].body.workflow_runs[]? | select(.event == "pull_request" and (.conclusion|type) == "string" and (.conclusion|length) > 0)] | .) as $runs
  | if ($runs | map(.id) | unique | length) == ($runs | length) then . else error("duplicate_run_id") end
  | if ([ $runs[].id ] | any(. as $id | $old[0].runs[] | .run_id == $id)) then error("old_population_overlap") else . end
  # The GitHub created query fixes population membership at the workflow-start
  # endpoint. A run which started within that immutable window can legitimately
  # become terminal just after it, so retain its complete wall-clock interval
  # rather than rejecting it as an inverted chronology.
  | if all($runs[]; (.id|type)=="number" and (.conclusion|type)=="string" and (.conclusion|length)>0 and (.created_at|type)=="string" and (.updated_at|type)=="string" and .created_at >= $cutoff and .created_at <= $endpoint and .updated_at >= .created_at) then . else error("run_chronology_or_identity_invalid") end
' "$MANIFEST" >/dev/null || fail "manifest_invalid"

SOURCE_COLLECTION="$TMP/source-collection.json"
jq -S -s --arg cutoff "$CUTOFF" --arg endpoint "$ENDPOINT" '
  {resource:"GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs",
   query:{created:($cutoff + ".." + $endpoint),per_page:100},
   requested_pages:[.[].page],terminal_page:.[-1].page,exhausted:true,
   pages:[.[] | {page:.page,returned_count:(.body.workflow_runs|length),
     runs:[.body.workflow_runs[] | {run_id:.id,url:.html_url,event:.event,
       conclusion:.conclusion,created_at:.created_at,updated_at:.updated_at}]}]}
' "$MANIFEST" >"$SOURCE_COLLECTION" || fail "source_collection_build_failed"

if jq -e --slurpfile old "$OLD_RECEIPT" '
  [.pages[].runs[].run_id] as $ids |
  any($ids[]; . as $id | any($old[0].runs[]; .run_id == $id))
' "$SOURCE_COLLECTION" >/dev/null; then
  fail "old_population_overlap"
fi

INSTRUMENT_COMMAND=(bash "$ROOT/scripts/ci/ci-run-metrics.sh" --source-pages "$SOURCE_COLLECTION" --mode wall --event pull_request --since "$CUTOFF" --until "$ENDPOINT" --threshold 720 --format json)
printf -v INSTRUMENT_COMMAND_TEXT '%q ' "${INSTRUMENT_COMMAND[@]}"
INSTRUMENT_COMMAND_TEXT="${INSTRUMENT_COMMAND_TEXT% }"
INSTRUMENT_OUTPUT="$TMP/instrument-output.json"
"${INSTRUMENT_COMMAND[@]}" >"$INSTRUMENT_OUTPUT" || fail "instrument_failed"
jq -e '.schema_version=="sigra.ci-run-metrics/source-pages-v1"' "$INSTRUMENT_OUTPUT" >/dev/null || fail "instrument_output_invalid"

collect_pole() {
  local role="$1" run_id="$2" pole_page=1 pole_response pole_api pole_count
  local pole_manifest="$TMP/${role}-pages.jsonl"
  : >"$pole_manifest"
  while :; do
    pole_response="$TMP/${role}-page-${pole_page}.json"
    pole_api="repos/${REPO}/actions/runs/${run_id}/jobs?per_page=100&page=${pole_page}"
    gh api "$pole_api" >"$pole_response" || fail "github_jobs_api_request_failed_${role}_page_${pole_page}"
    jq -e --argjson page "$pole_page" --argjson run_id "$run_id" '
      if ((.jobs | type) == "array" and
        all(.jobs[]; (.id|type)=="number" and .run_id==$run_id and (.name|type)=="string" and
          ((.conclusion==null) or (.conclusion|type)=="string") and
          (.started_at|type)=="string" and (.completed_at|type)=="string" and .completed_at>=.started_at and
          (.steps|type)=="array" and
          all(.steps[]; (.number|type)=="number" and (.name|type)=="string" and (.status|type)=="string" and
            ((.conclusion==null) or (.conclusion|type)=="string") and
            (.started_at|type)=="string" and (.completed_at|type)=="string" and .completed_at>=.started_at)))
      then {page:$page,jobs:.jobs} else error("jobs_page_invalid") end
    ' "$pole_response" >>"$pole_manifest" || fail "malformed_${role}_jobs_page_${pole_page}"
    pole_count="$(jq '.jobs | length' "$pole_response")"
    (( pole_count == 0 )) && break
    (( pole_page < MAX_PAGES )) || fail "${role}_jobs_pagination_bound_reached"
    pole_page=$((pole_page + 1))
  done
  jq -S -s --arg role "$role" --argjson run_id "$run_id" '
    {role:$role,run_id:$run_id,resource:("GET /repos/szTheory/sigra/actions/runs/"+($run_id|tostring)+"/jobs"),
     query:{per_page:100},requested_pages:[.[].page],terminal_page:.[-1].page,exhausted:true,
     pages:[.[] | {page:.page,returned_count:(.jobs|length),jobs:[.jobs[] |
       {job_id:.id,run_id:.run_id,name:.name,conclusion:.conclusion,started_at:.started_at,
        completed_at:.completed_at,steps:[.steps[] | {number:.number,name:.name,status:.status,
          conclusion:.conclusion,started_at:.started_at,completed_at:.completed_at}]}]}]}
  ' "$pole_manifest" >"$TMP/${role}-pole.json" || fail "${role}_pole_build_failed"
  jq -e '
    [.pages[].jobs[]] as $jobs |
    ([$jobs[].job_id] | length) == ([$jobs[].job_id] | unique | length) and
    all($jobs[]; . as $job | .run_id == $run_id and (.conclusion|type)=="string" and (.conclusion|length)>0 and
      ([.steps[].number] == ([.steps[].number] | sort)) and
      ([.steps[].number] | length) == ([.steps[].number] | unique | length) and
      all(.steps[]; .status=="completed" and (.conclusion|type)=="string" and (.conclusion|length)>0 and
        .started_at >= $job.started_at and .completed_at >= .started_at and .completed_at <= $job.completed_at))
  ' --argjson run_id "$run_id" "$TMP/${role}-pole.json" >/dev/null || fail "${role}_pole_linkage_invalid"
}

VERDICT="$(jq -r '.verdict // empty' "$INSTRUMENT_OUTPUT")"
BINDING_POLES="$TMP/binding-poles.json"
if [[ "$VERDICT" == "miss" ]]; then
  MEDIAN_RUN_ID="$(jq -r '.selected_poles.median_run_id' "$INSTRUMENT_OUTPUT")"
  MAXIMUM_RUN_ID="$(jq -r '.selected_poles.maximum_run_id' "$INSTRUMENT_OUTPUT")"
  collect_pole median "$MEDIAN_RUN_ID"
  collect_pole maximum "$MAXIMUM_RUN_ID"
  jq -S -n --slurpfile median "$TMP/median-pole.json" --slurpfile maximum "$TMP/maximum-pole.json" \
    '{median:$median[0],maximum:$maximum[0]}' >"$BINDING_POLES"
else
  printf 'null\n' >"$BINDING_POLES"
fi

jq -S -n --arg mode "$MODE" --arg endpoint "$ENDPOINT" --arg cutoff "$CUTOFF" --arg sha "$CUTOFF_SHA" \
  --arg reset "$RESET" --argjson remaining "$REMAINING" --arg instrument_command "$INSTRUMENT_COMMAND_TEXT" \
  --slurpfile source "$SOURCE_COLLECTION" --slurpfile instrument "$INSTRUMENT_OUTPUT" --slurpfile poles "$BINDING_POLES" '
  ($instrument[0]) as $i |
  {schema_version:"sigra.fast-01-source-complete-remeasurement/1",
   authority:(if $mode=="readiness" then "readiness_only" else "protected_main_attestation" end),
   endpoint_source:(if $mode=="readiness" then "collector_current_utc" else "protected_workflow_start" end),
   repository:"szTheory/sigra",workflow:"ci.yml",event:"pull_request",
   cutoff:{sha:$sha,timestamp:$cutoff},window:{endpoint:$endpoint},
   rate_limit:{remaining:$remaining,reset:$reset},source_collection:$source[0],
   instrument_receipt:{mode:"wall",command:$instrument_command,output:$i},
   runs:$i.runs,eligible_pr_run_count:$i.eligible_pr_run_count,statistics:$i.statistics,
   selected_poles:$i.selected_poles,verdict:$i.verdict,
   status:(if $mode=="readiness" and $i.status=="measured" then "ready" else $i.status end),
   diagnostics:$i.diagnostics,binding_poles:$poles[0]}
' >"$OUTTMP" || fail "canonical_source_complete_output_failed"

if [[ "$MODE" == protected ]]; then
  jq -e '.status=="measured" and .eligible_pr_run_count>=10 and (.verdict=="pass" or .verdict=="miss") and
    (if .verdict=="miss" then (.binding_poles.median.run_id==.selected_poles.median_run_id and
      .binding_poles.maximum.run_id==.selected_poles.maximum_run_id) else .binding_poles==null end)' \
    "$OUTTMP" >/dev/null || fail "protected_subject_not_attestable"
fi
mv -f "$OUTTMP" "$OUTPUT"
