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
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "ci-run-metrics: FAIL: $*" >&2
  exit 1
}

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

if [[ "$MODE" != "wall" && "$MODE" != "jobspan" ]]; then
  fail "unknown --mode: ${MODE} (expected wall|jobspan)"
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
