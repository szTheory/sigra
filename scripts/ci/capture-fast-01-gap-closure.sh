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
  | ([.[].body.workflow_runs[]? | select(.event == "pull_request")] | .) as $runs
  | if ($runs | map(.id) | unique | length) == ($runs | length) then . else error("duplicate_run_id") end
  | if ([ $runs[].id ] | any(. as $id | $old[0].runs[] | .run_id == $id)) then error("old_population_overlap") else . end
  | if all($runs[]; (.id|type)=="number" and (.conclusion|type)=="string" and (.conclusion|length)>0 and (.created_at|type)=="string" and (.updated_at|type)=="string" and .created_at >= $cutoff and .created_at <= $endpoint and .updated_at >= .created_at and .updated_at <= $endpoint) then . else error("run_chronology_or_identity_invalid") end
' "$MANIFEST" >/dev/null || fail "manifest_invalid"

if [[ "$MODE" == readiness ]]; then
  jq -S -n --arg endpoint "$ENDPOINT" --arg cutoff "$CUTOFF" --arg sha "$CUTOFF_SHA" --arg reset "$RESET" --argjson remaining "$REMAINING" --arg command "bash scripts/ci/capture-fast-01-gap-closure.sh --readiness $OUTPUT" --slurpfile pages "$MANIFEST" '
    ([ $pages[].body.workflow_runs[]? | select(.event == "pull_request") ] | map({run_id:.id,url:.html_url,event:.event,conclusion:.conclusion,created_at:.created_at,updated_at:.updated_at})) as $runs
    | {schema_version:"sigra.fast-01-gap-closure-readiness/v1",authority:"readiness_only",endpoint_source:"collector_current_utc",repository:"szTheory/sigra",workflow:"ci.yml",event:"pull_request",cutoff:{sha:$sha,timestamp:$cutoff},window:{endpoint:$endpoint},command:$command,source_api:"GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs",requested_pages:[$pages[].page],exhausted:true,rate_limit:{remaining:$remaining,reset:$reset},runs:$runs,eligible_pr_run_count:($runs|length),statistics:null,verdict:null,status:(if ($runs|length)<10 then "insufficient_population" else "ready" end),diagnostics:(if ($runs|length)<10 then ["requires_at_least_10_terminal_pull_request_runs"] else [] end)}
  ' >"$OUTTMP" || fail "canonical_readiness_output_failed"
else
  jq -S -n --arg endpoint "$ENDPOINT" --arg cutoff "$CUTOFF" --arg sha "$CUTOFF_SHA" --slurpfile pages "$MANIFEST" '
    ([ $pages[].body.workflow_runs[]? | select(.event == "pull_request") ] | map({run_id:.id,wall_seconds:((.updated_at|fromdateiso8601)-(.created_at|fromdateiso8601)),conclusion:.conclusion,url:.html_url})) as $runs
    | if ($runs|length)<10 then error("insufficient_population") else . end
    | ($runs|sort_by(.wall_seconds,.run_id)) as $ordered | ($ordered[($ordered|length/2|floor)].wall_seconds) as $p50
    | {schema_version:"sigra.fast-01-gap-closure-remeasurement/v1",authority:"protected_main_attestation",repository:"szTheory/sigra",workflow:"ci.yml",event:"pull_request",cutoff:{sha:$sha,timestamp:$cutoff},window:{endpoint:$endpoint},runs:$ordered,eligible_pr_run_count:($ordered|length),statistics:{mode:"wall",ordering:"{wall_seconds, run_id}",p50_seconds:$p50},verdict:(if $p50<720 then "pass" else "miss" end),status:"measured"}
  ' >"$OUTTMP" || fail "canonical_protected_output_failed"
fi
mv -f "$OUTTMP" "$OUTPUT"
