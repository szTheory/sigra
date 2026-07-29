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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) RUN_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --workflow) WORKFLOW="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --since) SINCE="$2"; shift 2;;
    --event) EVENT="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
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

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI not found on PATH"
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
