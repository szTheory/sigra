#!/usr/bin/env bash
# Phase 230 (AFTER-PUSH closure): the demotion receipt.
#
# CONTRACT
# Given a TERMINAL workflow run, prove that every construct Phase 230 demoted off the
# pull_request lane actually executed on the lane that received it. This is the standing,
# permanent form of the AFTER-PUSH human UAT item: instead of a maintainer pasting one
# run's evidence once, this asserts the same thing on every non-PR run, forever.
#
# WHY IT IS NOT A JOB INSIDE ci.yml
# A job cannot observe its own in-progress run. The Actions API serializes an unfinished
# job's `completedAt` as "0001-01-01T00:00:00Z" and its `conclusion` as "" -- and
# ci-run-metrics.sh's (correct, deliberate) negative-duration clamp turns that into `0s`,
# which is byte-identical to a genuinely skipped job. A `conclusion != "skipped"` test
# passes on "" too. Both directions fail OPEN. This script therefore runs from
# .github/workflows/ci-observe.yml on `workflow_run: [completed]`, where every conclusion
# is populated and every timestamp is real, and it fail-CLOSES on any non-terminal state
# rather than inferring from duration.
#
# SCOPE (deliberate, recorded)
# Asserts on tier B of .github/ci-skip-manifest.tsv -- the constructs Phase 230 itself
# demoted. NOT tier A (pre-existing since Phase 196; Phase 231's GATE-01/GATE-02 own it,
# and the nightly is 0-pass/9-fail, so a tenth red would be unread by construction). NOT
# tier C's step-level completeness (that inventory is Phase 235's GATE-05).
#
# BOUNDARY WITH PHASE 231 (GATE-03)
# This script only OBSERVES and REPORTS. It never changes what `ci-gate` counts as a
# pass, and the job that runs it is deliberately absent from `ci-gate.needs`. GATE-03
# owns the "is this skip legitimate, and should the run fail?" question on the PR side;
# it should CONSUME this receipt (or invoke this script with --from-json) rather than
# re-deriving the executed set, so there is exactly one oracle.
#
# A `failure` conclusion PASSES. The receipt asserts EXECUTION, not success -- which is
# precisely why admin_eval_render's deliberately-retained `continue-on-error: true` red
# (Phase 231 GATE-04 owns removing it) does not red this receipt.
#
# Security: never echoes GH_TOKEN or any secret; reads only run metadata. `gh` is invoked
# bare via PATH so the self-test can shadow it with a recording stub -- no network call
# and no GH_TOKEN anywhere in scripts/ci/ci-demotion-observer.test.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO="szTheory/sigra"
MANIFEST="${ROOT}/.github/ci-skip-manifest.tsv"
RUN_ID="${GITHUB_RUN_ID:-}"
FROM_JSON=""
FORMAT="table"
EVENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --manifest) MANIFEST="$2"; shift 2;;
    --from-json) FROM_JSON="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --event) EVENT="$2"; shift 2;;
    *) echo "ci-demotion-observer: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "ci-demotion-observer: FAIL: $*" >&2
  exit 1
}

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

[[ -f "$MANIFEST" ]] || fail "manifest not found at ${MANIFEST}"

# ---------------------------------------------------------------------------
# Manifest -> the assert set. Non-vacuity is enforced: a manifest that parses to
# zero assert rows is a BROKEN PARSE, not a clean run. Without this an emptied or
# reformatted manifest would make every run trivially green.
# ---------------------------------------------------------------------------
ASSERT_ROWS="$(awk -F'\t' '
  /^#/ { next }
  /^[[:space:]]*$/ { next }
  $1 == "tier" { next }
  $8 == "assert" { print $2 "\t" $3 "\t" $4 "\t" $5 }
' "$MANIFEST")"

ASSERT_COUNT="$(printf '%s' "$ASSERT_ROWS" | grep -c . || true)"
if [[ "$ASSERT_COUNT" -lt 2 ]]; then
  fail "manifest ${MANIFEST} yielded ${ASSERT_COUNT} assert row(s); expected at least 2 (admin_eval_render + design_gallery_snapshots) -- the parse broke, this is not a pass"
fi

# Resolve a kind=step row's parent job display_name from the manifest's own kind=job row.
parent_display_name() {
  local parent_id="$1" out
  out="$(awk -F'\t' -v pid="$parent_id" '
    /^#/ { next }
    $1 == "tier" { next }
    $2 == "job" && $3 == pid { print $5; exit }
  ' "$MANIFEST")"
  [[ -n "$out" ]] || fail "manifest has a step row whose parent_job_id '${parent_id}' has no matching kind=job row -- cannot resolve the parent job's display name"
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Run payload: exactly one `gh` round-trip, or a saved payload via --from-json.
# ---------------------------------------------------------------------------
if [[ -n "$FROM_JSON" ]]; then
  [[ -f "$FROM_JSON" ]] || fail "--from-json payload not found at ${FROM_JSON}"
  RUN_JSON="$(cat "$FROM_JSON")"
else
  [[ -n "$RUN_ID" ]] || fail "no run id: pass --run <id> or set GITHUB_RUN_ID"
  command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
  RUN_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs,event,createdAt,updatedAt,databaseId)" \
    || fail "gh run view failed for run ${RUN_ID}"
fi

echo "$RUN_JSON" | jq -e 'type == "object" and has("jobs")' >/dev/null 2>&1 \
  || fail "run payload is not an object carrying a .jobs array"

JOB_COUNT="$(echo "$RUN_JSON" | jq '.jobs | length')"
[[ "$JOB_COUNT" -gt 0 ]] || fail "run payload has an empty job list -- fail-closed, never 'nothing to check so pass'"

RUN_EVENT="${EVENT:-$(echo "$RUN_JSON" | jq -r '.event // ""')}"
RUN_DBID="$(echo "$RUN_JSON" | jq -r '.databaseId // empty')"
[[ -n "$RUN_DBID" ]] || RUN_DBID="${RUN_ID:-unknown}"

# ---------------------------------------------------------------------------
# Verdicts. Tri-state and fail-closed at every branch:
#   not found            -> FAIL  (a renamed construct is the #1 rot mode)
#   status != completed  -> FAIL  (unobservable is NOT observed-good; this is the
#                                  0001-01-01 / conclusion:"" fail-open hole)
#   conclusion == ""     -> FAIL
#   skipped/cancelled    -> FAIL  (the demotion has rotted -- the receiving lane
#                                  did not receive)
#   timed_out            -> FAIL
#   duration <= 0        -> FAIL  (green-on-noop)
#   success | failure    -> PASS  (execution is the claim, not success)
# ---------------------------------------------------------------------------
VERDICTS="[]"
EXIT_CODE=0

while IFS=$'\t' read -r kind id parent_id display_name; do
  [[ -n "$kind" ]] || continue

  if [[ "$kind" == "job" ]]; then
    NODE="$(echo "$RUN_JSON" | jq -c --arg n "$display_name" '.jobs[] | select(.name == $n)' | head -1)"
    LOCATION="job"
  else
    PARENT_NAME="$(parent_display_name "$parent_id")"
    NODE="$(echo "$RUN_JSON" | jq -c --arg pj "$PARENT_NAME" --arg n "$display_name" \
      '.jobs[] | select(.name == $pj) | .steps[]? | select(.name == $n)' | head -1)"
    LOCATION="step in ${PARENT_NAME}"
  fi

  if [[ -z "$NODE" ]]; then
    VERDICT="FAIL"; REASON="not found in the run by name -- renamed, removed, or its owning job never ran"
    STATUS=""; CONCL=""; DUR=0
  else
    STATUS="$(echo "$NODE" | jq -r '.status // ""')"
    CONCL="$(echo "$NODE" | jq -r '.conclusion // ""')"
    DUR="$(echo "$NODE" | jq -r '
      if (.completedAt // "") == "" or (.startedAt // "") == "" then 0
      elif (.completedAt | startswith("0001-")) then 0
      else (((.completedAt|fromdate) - (.startedAt|fromdate)) as $r | if $r < 0 then 0 else $r end)
      end')"

    if [[ "$STATUS" != "completed" ]]; then
      VERDICT="FAIL"; REASON="status is '${STATUS:-<empty>}', not 'completed' -- an unfinished construct reports a zero-date completedAt, which is indistinguishable from a skip; refusing to infer"
    elif [[ -z "$CONCL" ]]; then
      VERDICT="FAIL"; REASON="empty conclusion -- never treat an absent conclusion as 'not skipped'"
    elif [[ "$CONCL" == "skipped" ]]; then
      VERDICT="FAIL"; REASON="skipped on a non-pull_request run -- the demotion rotted; the receiving lane did not receive the work"
    elif [[ "$CONCL" == "cancelled" ]]; then
      VERDICT="FAIL"; REASON="cancelled -- release integrity outranks PR latency (FAST-04)"
    elif [[ "$CONCL" == "timed_out" ]]; then
      VERDICT="FAIL"; REASON="timed out -- the ceiling truncated work the receipt is meant to observe (FAST-07)"
    elif [[ "$DUR" -le 0 ]]; then
      VERDICT="FAIL"; REASON="zero duration despite conclusion '${CONCL}' -- green on a no-op"
    else
      VERDICT="PASS"; REASON="executed (${CONCL})"
    fi
  fi

  [[ "$VERDICT" == "PASS" ]] || EXIT_CODE=1

  VERDICTS="$(echo "$VERDICTS" | jq \
    --arg id "$id" --arg kind "$kind" --arg loc "$LOCATION" --arg name "$display_name" \
    --arg status "$STATUS" --arg concl "$CONCL" --argjson dur "${DUR:-0}" \
    --arg verdict "$VERDICT" --arg reason "$REASON" \
    '. + [{id: $id, kind: $kind, location: $loc, display_name: $name, status: $status,
           conclusion: $concl, duration_seconds: $dur, verdict: $verdict, reason: $reason}]')"
done <<< "$ASSERT_ROWS"

# Run-wide integrity: no job anywhere may be cancelled or timed out. A non-PR run keys
# its concurrency group on its own run_id, so a cancellation there means something other
# than supersession happened (FAST-04 / D-12).
CANCELLED="$(echo "$RUN_JSON" | jq -c '[.jobs[] | select(.conclusion == "cancelled") | .name]')"
TIMED_OUT="$(echo "$RUN_JSON" | jq -c '[.jobs[] | select(.conclusion == "timed_out") | .name]')"
[[ "$(echo "$CANCELLED" | jq 'length')" -eq 0 ]] || EXIT_CODE=1
[[ "$(echo "$TIMED_OUT" | jq 'length')" -eq 0 ]] || EXIT_CODE=1

WALL="$(echo "$RUN_JSON" | jq -r '
  if (.createdAt // "") == "" or (.updatedAt // "") == "" then 0
  else (((.updatedAt|fromdate) - (.createdAt|fromdate)) as $r | if $r < 0 then 0 else $r end)
  end')"

case "$FORMAT" in
  json)
    jq -n --arg run "$RUN_DBID" --arg event "$RUN_EVENT" --argjson wall "${WALL:-0}" \
      --argjson constructs "$VERDICTS" --argjson cancelled "$CANCELLED" \
      --argjson timed_out "$TIMED_OUT" --argjson exit_code "$EXIT_CODE" \
      '{run_id: $run, event: $event, wall_clock_seconds: $wall, constructs: $constructs,
        cancelled_jobs: $cancelled, timed_out_jobs: $timed_out,
        verdict: (if $exit_code == 0 then "PASS" else "FAIL" end)}'
    ;;
  table)
    printf 'Demotion receipt -- run %s (event: %s, wall-clock %dm%02ds)\n\n' \
      "$RUN_DBID" "${RUN_EVENT:-unknown}" "$((WALL / 60))" "$((WALL % 60))"
    {
      printf 'construct\tlocation\tconclusion\tduration\tverdict\n'
      echo "$VERDICTS" | jq -r '.[]
        | "\(.id)\t\(.location)\t\(.conclusion // "-")\t\(.duration_seconds)s\t\(.verdict)"'
    } | column -t -s $'\t'
    echo
    echo "$VERDICTS" | jq -r '.[] | select(.verdict == "FAIL") | "  FAIL \(.id): \(.reason)"'
    [[ "$(echo "$CANCELLED" | jq 'length')" -eq 0 ]] \
      || echo "  FAIL run-wide: cancelled jobs: $(echo "$CANCELLED" | jq -r 'join(", ")')"
    [[ "$(echo "$TIMED_OUT" | jq 'length')" -eq 0 ]] \
      || echo "  FAIL run-wide: timed-out jobs: $(echo "$TIMED_OUT" | jq -r 'join(", ")')"
    if [[ "$EXIT_CODE" -eq 0 ]]; then
      echo "  every demoted construct executed on this lane."
    fi
    ;;
esac

exit "$EXIT_CODE"
