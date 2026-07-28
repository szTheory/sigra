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
FORMAT="table"
RUN_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) RUN_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "ci-run-metrics: FAIL: $*" >&2
  exit 1
}

if [[ -z "$RUN_ID" ]]; then
  fail "--jobs <run_id> is required (single-run mode)"
fi

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI not found on PATH"
fi

JOBS_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs --jq '.jobs')" || fail "gh run view failed for run ${RUN_ID}"

JOB_COUNT="$(echo "$JOBS_JSON" | jq 'length')"
if [[ -z "$JOB_COUNT" || "$JOB_COUNT" -eq 0 ]]; then
  fail "run ${RUN_ID} has an empty job list"
fi

# Duration rule: completedAt - startedAt, clamped at 0. Skipped jobs can report
# `completedAt` up to ~1s *before* `startedAt` (observed on `Upgrade smoke` and
# `notify_release_lane_rot` in run 30390832059) -- clamp, never emit a negative number.
# Never filter on `conclusion` -- a `continue-on-error: true` job that concludes
# "failure" (e.g. admin_eval_render) still burned real runner time and must be counted.
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
