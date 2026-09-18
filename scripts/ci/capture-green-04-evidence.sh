#!/usr/bin/env bash
# Capture the GREEN-04 n>=20 dispatch window (SC-1) and the `main` ci.yml window (SC-2)
# as one canonical JSON receipt. This command deliberately has NO caller-configurable
# repository, workflow, job-name selector or jobs `filter`.
#
# WHY NON-STEERABLE: a collector whose window the caller steers lets whoever runs it choose
# the window that flatters the verdict — that is evidence forgery wearing a green receipt.
# The in-repo precedent is capture-terminal-ratification-evidence.sh:5-8, which fixes its
# repo/workflow/window the same way. Only the dispatch run id, the `main` window bounds
# (themselves bounded by the dispatch run) and the output path are arguments.
#
# DUAL PROVENANCE:
#   * `request_page` / `validate_manifest` / `collect_pages` are copied VERBATIM from
#     scripts/ci/capture-terminal-ratification-evidence.sh:47-92. They already encode every
#     D-11 pagination requirement (per_page=100, total_count stability, total_count vs summed
#     length, proven terminal empty page, page contiguity, no empty non-terminal page,
#     duplicate item ids, and the MAX_PAGES bound). Do not re-derive that loop.
#   * The canonical-output idiom (`schema_version`, `jq -S -n`, `--slurpfile`, temp file then
#     `mv -f`) is taken from scripts/ci/capture-fast-01-remeasurement.sh:84-92.
#
# D-12: capture-fast-01-remeasurement.sh is NOT extended. Its cutoff SHA and timestamp at
# :5-11 are protected constants pinned by
# test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs; adding a second
# window to that script would put this phase's evidence inside a file whose constants another
# phase's test owns. A new, standalone collector is the right shape.
#
# D-08: SC-1 and SC-2 verdicts are read at the JOB conclusion level via
# GET /repos/{repo}/actions/runs/{id}/jobs — NEVER at the run conclusion. On `main`, ci.yml's
# run-level conclusion is `failure` for a reason OUTSIDE ci-gate (`admin_eval_render`, which
# ci.yml:2089-2110 documents as not being in ci-gate.needs). Reading the run conclusion is the
# Phase 238 lesson inverted.
#
# This script does NOT write 240-EVIDENCE.md. Neither existing collector writes a ledger: the
# JSON is the receipt, and the markdown claim is authored by a human/executor from the JSON.
set -euo pipefail

# ---------------------------------------------------------------------------
# Fixed, non-configurable constants. No `${VAR:-default}` form appears below:
# nothing here can be overridden by an environment variable or an argument.
# ---------------------------------------------------------------------------
REPO="szTheory/sigra"
EVIDENCE_WORKFLOW="green-04-evidence.yml"
CI_WORKFLOW="ci.yml"
# THE JOB-NAME CONTRACT: this is the workflow's `name:` value, which the Actions API reports
# as a PREFIX — a matrix job's API `name` is that value plus a ` (N)` suffix (ci.yml:556-560).
# The ` (N)` must NOT appear in this constant; it is supplied by Actions.
JOB_NAME="Generated admin Playwright smoke (GREEN-04 repeat)"
CI_JOB_NAME="Generated admin Playwright smoke"
CI_GATE_JOB_NAME="ci-gate"
JOBS_FILTER="latest"
MIN_LEGS=20
MAX_PAGES=10000
SCHEMA_VERSION="sigra.green-04-evidence/v1"
SC2_CAVEAT="example_unit_smoke is absent from the ten ci-gate.needs entries (ci.yml:1547-1557: changes, install_golden_contract, library_tests, library_tests_dep_off, install_smoke, upgrade_smoke, example_http_smoke, example_playwright_smoke, generated_admin_playwright_smoke, fast_checks) while being independently required by ruleset 14941512, so a ci-gate: success is a nine-of-ten claim, not a whole-gate claim (D-10). This phase discloses that caveat; it does not fix it."

fail() { echo "capture-green-04-evidence: FAIL: $*" >&2; exit 1; }
usage() {
  echo "usage: $0 --output PATH --run-id ID --main-window-start UTC --main-window-end UTC" >&2
  exit 2
}

OUTPUT=""
RUN_ID=""
WINDOW_START=""
WINDOW_END=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) [[ $# -ge 2 ]] || usage; OUTPUT="$2"; shift 2 ;;
    --run-id) [[ $# -ge 2 ]] || usage; RUN_ID="$2"; shift 2 ;;
    --main-window-start) [[ $# -ge 2 ]] || usage; WINDOW_START="$2"; shift 2 ;;
    --main-window-end) [[ $# -ge 2 ]] || usage; WINDOW_END="$2"; shift 2 ;;
    *) echo "capture-green-04-evidence: FAIL: unknown_argument: $1" >&2; usage ;;
  esac
done
[[ -n "$OUTPUT" && -n "$RUN_ID" && -n "$WINDOW_START" && -n "$WINDOW_END" ]] || usage
[[ "$RUN_ID" =~ ^[0-9]+$ ]] || fail "run_id_malformed"
[[ "$WINDOW_START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || fail "main_window_start_malformed"
[[ "$WINDOW_END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || fail "main_window_end_malformed"
[[ "$WINDOW_START" < "$WINDOW_END" ]] || fail "main_window_inverted"

# ---------------------------------------------------------------------------
# Preflight, in order, each fail-closed.
# ---------------------------------------------------------------------------
command -v gh >/dev/null 2>&1 || fail "gh_not_found"
command -v jq >/dev/null 2>&1 || fail "jq_not_found"
command -v git >/dev/null 2>&1 || fail "git_not_found"

# Exactly one rate-limit check. Collection is finite REST retrieval, not polling.
REMAINING="$(gh api rate_limit --jq '.resources.core.remaining')" || fail "rate_limit_preflight_failed"
[[ "$REMAINING" =~ ^[0-9]+$ ]] || fail "rate_limit_preflight_malformed"
(( REMAINING > 250 )) || fail "rate_limit_too_low"

# D-13 — the Phase 216 SC-5 trap. A capture taken against a dirty tree, or against a run
# whose head_sha is not the final committed HEAD, describes code that is not what shipped.
[[ -z "$(git status --porcelain)" ]] || fail "dirty_tree"
HEAD_SHA="$(git rev-parse HEAD)" || fail "head_sha_unreadable"
RUN_HEAD_SHA="$(gh api "repos/${REPO}/actions/runs/${RUN_ID}" | jq -r '.head_sha')" || fail "dispatch_run_unreadable"
[[ "$RUN_HEAD_SHA" == "$HEAD_SHA" ]] || fail "evidence_run_head_sha_is_not_final_committed_head"

TMPD="$(mktemp -d)"
output_tmp=""
cleanup() {
  rm -rf "$TMPD"
  if [[ -n "$output_tmp" ]]; then rm -f "$output_tmp"; fi
}
trap cleanup ERR INT TERM EXIT

# ---------------------------------------------------------------------------
# Pagination core — copied verbatim from
# capture-terminal-ratification-evidence.sh:47-92.
# ---------------------------------------------------------------------------
request_page() {
  local endpoint="$1" page="$2" out="$3"
  if ! gh api "${endpoint}&per_page=100&page=${page}" >"$out"; then
    # gh prints HTTP detail itself; do not retry 403/429 or any other API failure.
    fail "github_api_request_failed_page_${page}"
  fi
}

validate_manifest() {
  local manifest="$1" item_key="$2" label="$3"
  jq -s -e --arg key "$item_key" '
    if type != "array" or length == 0 then error("absent_terminal_empty_page") else . end
    | . as $pages
    | if all(.[]; (.page|type) == "number" and ((.page|floor) == .page) and .page > 0 and (.body|type) == "object") then . else error("malformed_envelope") end
    | if ([.[].page] | sort) == [range(1; length + 1)] then . else error("non_contiguous_or_duplicate_page") end
    | if ([.[].body.total_count] | all(type == "number" and (floor == .) and . >= 0)) then . else error("malformed_total_count") end
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
    response="$TMPD/${label}-${page}.json"
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

# ---------------------------------------------------------------------------
# THE SELECTOR CONTRACT — anchored regex, never byte equality.
#
# `green_04_evidence_repeat` carries BOTH a `name:` and a `strategy.matrix`, so
# GET /runs/{id}/jobs returns twenty jobs named
# `Generated admin Playwright smoke (GREEN-04 repeat) (1)` … ` (20)` (ci.yml:556-560).
# A selector comparing the API `name` for byte equality against JOB_NAME harvests ZERO legs
# and would report an empty window as if it were a clean miss. Both regexes below are
# anchored at both ends; the leg regex REQUIRES the ` (N)` suffix and yields `matrix_repeat`
# from its named capture group, so the index is read from the same parse that selected it.
# ---------------------------------------------------------------------------
regex_escape() { printf '%s' "$1" | sed 's/[][(){}.*+?^$|\\\/]/\\&/g'; }
JOB_NAME_ESC="$(regex_escape "$JOB_NAME")"
CI_JOB_NAME_ESC="$(regex_escape "$CI_JOB_NAME")"
CI_GATE_JOB_NAME_ESC="$(regex_escape "$CI_GATE_JOB_NAME")"
LEG_NAME_RE="^${JOB_NAME_ESC} \\((?<repeat>[0-9]+)\\)$"
BARE_NAME_RE="^${JOB_NAME_ESC}$"
CI_JOB_NAME_RE="^${CI_JOB_NAME_ESC}$"
CI_GATE_JOB_NAME_RE="^${CI_GATE_JOB_NAME_ESC}$"

# ---------------------------------------------------------------------------
# SC-1 — the n>=20 dispatch legs.
# ---------------------------------------------------------------------------
SC1_MANIFEST="$TMPD/sc1-jobs.manifest.jsonl"
collect_pages "repos/${REPO}/actions/runs/${RUN_ID}/jobs?filter=${JOBS_FILTER}" jobs sc1-jobs "$SC1_MANIFEST"

SC1_ALL="$TMPD/sc1-all.json"
jq -s -e '[.[].body.jobs[]]' "$SC1_MANIFEST" >"$SC1_ALL" || fail "sc1_jobs_unreadable"

SC1_LEGS_RAW="$TMPD/sc1-legs-raw.json"
jq -e --arg re "$LEG_NAME_RE" '[.[] | select(.name | test($re))]' "$SC1_ALL" >"$SC1_LEGS_RAW" || fail "sc1_leg_selection_failed"
LEG_COUNT="$(jq -r 'length' "$SC1_LEGS_RAW")"
BARE_COUNT="$(jq -r --arg re "$BARE_NAME_RE" '[.[] | select(.name | test($re))] | length' "$SC1_ALL")"

# A payload of bare, unsuffixed names is a REJECTED SHAPE, not an empty window. Conflating
# the two is exactly what would hide a selector bug behind a plausible "no legs yet".
if (( LEG_COUNT == 0 )) && (( BARE_COUNT > 0 )); then
  fail "no_matrix_suffix"
fi
(( LEG_COUNT >= MIN_LEGS )) || fail "insufficient_legs"

# An in-progress, queued or cancelled leg means the capture ran too early. Never count it.
jq -e 'all(.[]; (.conclusion | type) == "string" and (.conclusion | length) > 0)' "$SC1_LEGS_RAW" >/dev/null \
  || fail "leg_without_conclusion"

SC1_LEGS="$TMPD/sc1-legs.json"
jq -e --arg re "$LEG_NAME_RE" '
  [ .[] | {
      run_id: .run_id,
      job_id: .id,
      matrix_repeat: (.name | capture($re) | .repeat | tonumber),
      url: .html_url,
      conclusion: .conclusion
    } ]
  | sort_by(.matrix_repeat)
' "$SC1_LEGS_RAW" >"$SC1_LEGS" || fail "sc1_leg_normalisation_failed"

jq -e --argjson min "$MIN_LEGS" '[.[].matrix_repeat] == [range(1; $min + 1)]' "$SC1_LEGS" >/dev/null \
  || fail "matrix_repeat_set_mismatch"
jq -e --argjson rid "$RUN_ID" 'all(.[]; .run_id == $rid)' "$SC1_LEGS" >/dev/null || fail "foreign_run_id"

SC1_VERDICT="$(jq -r 'if all(.[]; .conclusion == "success") then "pass" else "fail" end' "$SC1_LEGS")"

# ---------------------------------------------------------------------------
# SC-2 — the `main` ci.yml window, read per job.
# ---------------------------------------------------------------------------
SC2_RUNS_MANIFEST="$TMPD/sc2-runs.manifest.jsonl"
collect_pages "repos/${REPO}/actions/workflows/${CI_WORKFLOW}/runs?branch=main&created=${WINDOW_START}..${WINDOW_END}" \
  workflow_runs sc2-runs "$SC2_RUNS_MANIFEST"

SC2_RUNS_FILE="$TMPD/sc2-runs.json"
printf '%s\n' '[]' >"$SC2_RUNS_FILE"
MAIN_RUN_IDS="$(jq -s -r '[.[].body.workflow_runs[].id] | sort | .[]' "$SC2_RUNS_MANIFEST")"
for main_run_id in $MAIN_RUN_IDS; do
  [[ "$main_run_id" =~ ^[0-9]+$ ]] || fail "main_run_id_malformed"
  jobs_manifest="$TMPD/sc2-jobs-${main_run_id}.manifest.jsonl"
  collect_pages "repos/${REPO}/actions/runs/${main_run_id}/jobs?filter=${JOBS_FILTER}" jobs "sc2-jobs-${main_run_id}" "$jobs_manifest"
  run_meta="$TMPD/sc2-run-${main_run_id}.json"
  jq -s -e --argjson rid "$main_run_id" '
    [.[].body.workflow_runs[]] | map(select(.id == $rid)) | .[0]
    | {run_id: .id, url: .html_url, run_conclusion: .conclusion}
  ' "$SC2_RUNS_MANIFEST" >"$run_meta" || fail "main_run_metadata_missing_${main_run_id}"
  next="$TMPD/sc2-runs-next-${main_run_id}.json"
  jq -e \
    --slurpfile meta "$run_meta" \
    --slurpfile pages "$jobs_manifest" \
    --arg ci_re "$CI_JOB_NAME_RE" \
    --arg gate_re "$CI_GATE_JOB_NAME_RE" '
    ([$pages[].body.jobs[]] | map({name: .name, conclusion: .conclusion})) as $jobs
    | . + [ $meta[0] + {
        jobs: ($jobs | sort_by(.name)),
        ci_gate_conclusion: ([$jobs[] | select(.name | test($gate_re)) | .conclusion] | first),
        generated_admin_smoke_conclusion: ([$jobs[] | select(.name | test($ci_re)) | .conclusion] | first)
      } ]
  ' "$SC2_RUNS_FILE" >"$next" || fail "main_run_jobs_merge_failed_${main_run_id}"
  mv "$next" "$SC2_RUNS_FILE"
done
jq -e 'sort_by(.run_id)' "$SC2_RUNS_FILE" >"$TMPD/sc2-runs-sorted.json" || fail "main_run_sort_failed"
mv "$TMPD/sc2-runs-sorted.json" "$SC2_RUNS_FILE"

# ---------------------------------------------------------------------------
# Canonical emission — `jq -S` for byte-stable key order, temp file then `mv -f`.
# Never take ownership of the caller's receipt path until a complete, validated
# replacement exists.
# ---------------------------------------------------------------------------
output_dir="$(dirname -- "$OUTPUT")"
[[ -d "$output_dir" ]] || fail "output_directory_missing"
output_tmp="$(mktemp "$output_dir/.green-04-evidence.XXXXXX")" || fail "output_temporary_file_failed"

jq -S -n \
  --arg schema "$SCHEMA_VERSION" \
  --arg repository "$REPO" \
  --arg head_sha "$HEAD_SHA" \
  --arg evidence_workflow "$EVIDENCE_WORKFLOW" \
  --arg ci_workflow "$CI_WORKFLOW" \
  --arg job_name "$JOB_NAME" \
  --arg ci_job_name "$CI_JOB_NAME" \
  --arg jobs_filter "$JOBS_FILTER" \
  --arg verdict "$SC1_VERDICT" \
  --arg window_start "$WINDOW_START" \
  --arg window_end "$WINDOW_END" \
  --arg caveat "$SC2_CAVEAT" \
  --argjson dispatch_run_id "$RUN_ID" \
  --slurpfile legs "$SC1_LEGS" \
  --slurpfile runs "$SC2_RUNS_FILE" '
  ($legs[0]) as $l
  | ($runs[0]) as $r
  | {
      schema_version: $schema,
      repository: $repository,
      head_sha: $head_sha,
      clean_tree: true,
      sc1: {
        workflow: $evidence_workflow,
        dispatch_run_id: $dispatch_run_id,
        job_name: $job_name,
        jobs_filter: $jobs_filter,
        legs: $l,
        leg_count: ($l | length),
        verdict: $verdict
      },
      sc2: {
        workflow: $ci_workflow,
        branch: "main",
        job_name: $ci_job_name,
        jobs_filter: $jobs_filter,
        window: {start: $window_start, end: $window_end},
        runs: $r,
        run_count: ($r | length),
        ci_gate_conclusions: {
          success: ([$r[] | select(.ci_gate_conclusion == "success")] | length),
          failure: ([$r[] | select(.ci_gate_conclusion == "failure")] | length),
          skipped: ([$r[] | select(.ci_gate_conclusion == "skipped")] | length)
        },
        flake_attributable_red_count: ([$r[] | select(.generated_admin_smoke_conclusion == "failure")] | length),
        caveat: $caveat
      }
    }
' >"$output_tmp" || fail "canonical_output_failed"

test -s "$output_tmp" || fail "empty_canonical_output"
mv -f -- "$output_tmp" "$OUTPUT" || fail "canonical_output_replace_failed"
output_tmp=""
echo "capture-green-04-evidence: wrote $OUTPUT (sc1.leg_count=$LEG_COUNT verdict=$SC1_VERDICT)"
