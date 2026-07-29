#!/usr/bin/env bash
# Phase 230 (AFTER-DOCSONLY closure): the docs-only receipt.
#
# CONTRACT
# Given a TERMINAL `pull_request` run that classified `docs_only=true`, prove FAST-05's
# `true` branch end-to-end: all five ruleset-required contexts concluded `success` (so the
# PR is merge-eligible rather than stranded), while `fast_checks` and the library suite
# still executed in full.
#
# WHY IT IS OPPORTUNISTIC RATHER THAN A PROBE
# No pre-merge pull request can reach `docs_only=true` -- `ci.yml` triggers on
# `pull_request: branches: [main]`, so any PR carrying Phase 230's own ci.yml changes
# necessarily diffs non-Markdown against origin/main. Rather than manufacture the
# condition (a synthetic PR probe costs a full run forever; a `force_docs_only` dispatch
# input would bypass the very classifier under test AND open a tag-dispatch path to an
# unverified Hex publish), this receipt simply fires the first time a genuine
# Markdown/.planning-only PR lands -- which in this repo is routine -- and then keeps
# firing on every one after that. The first observation is calendar-dependent, not
# action-dependent; that residual is disclosed rather than automated away.
#
# NON-DOCS-ONLY RUNS ARE NOT FAILURES. They report `n/a` and exit 0: this receipt makes a
# conditional claim, and a run that did not meet the condition has not falsified it.
#
# THE docs_only VALUE IS READ FROM THE `changes` JOB'S OWN LOG -- the value the job
# actually emitted. It is deliberately NOT inferred from "every Playwright seam was
# skipped": that aggregator line is Phase 231 GATE-03's designated input, and
# re-deriving the classification from it would fork one signal into two oracles.
#
# Security: never echoes GH_TOKEN or any secret. `gh` is invoked bare via PATH so the
# self-test can shadow it with a recording stub.
set -euo pipefail

REPO="szTheory/sigra"
RUN_ID="${GITHUB_RUN_ID:-}"
FROM_JSON=""
DOCS_ONLY_OVERRIDE=""
FORMAT="table"

# The five ruleset-14941512-required context names, byte-identical to ci.yml's `name:`
# values. A docs-only PR must still produce all five as `success` -- a job-level
# docs_only gate would make them `skipped` and can strand the PR (D-06).
REQUIRED_CONTEXTS=(
  "Library tests"
  "Example unit smoke (ExUnit + ConnTest)"
  "Install smoke (fresh phx.new + sigra.install)"
  "Example HTTP smoke (boot + curl critical routes)"
  "Example Playwright smoke (full lifecycle)"
)

# Lanes that must still run IN FULL on a docs-only PR (never gated) -- their guards read
# .planning/** and guides/**, exactly what a docs-only PR changes.
MUST_RUN_FULL=(
  "Fast checks (milestone/installer/contracts/snapshot/ledger guards)"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --from-json) FROM_JSON="$2"; shift 2;;
    --docs-only) DOCS_ONLY_OVERRIDE="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) echo "docs-only-receipt: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() { echo "docs-only-receipt: FAIL: $*" >&2; exit 1; }

[[ "$FORMAT" == "table" || "$FORMAT" == "json" ]] || fail "unknown --format: ${FORMAT} (expected table|json)"

if [[ -n "$FROM_JSON" ]]; then
  [[ -f "$FROM_JSON" ]] || fail "--from-json payload not found at ${FROM_JSON}"
  RUN_JSON="$(cat "$FROM_JSON")"
else
  [[ -n "$RUN_ID" ]] || fail "no run id: pass --run <id> or set GITHUB_RUN_ID"
  command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
  RUN_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs,event,databaseId)" \
    || fail "gh run view failed for run ${RUN_ID}"
fi

echo "$RUN_JSON" | jq -e 'type == "object" and has("jobs")' >/dev/null 2>&1 \
  || fail "run payload is not an object carrying a .jobs array"
JOB_COUNT="$(echo "$RUN_JSON" | jq '.jobs | length')"
[[ "$JOB_COUNT" -gt 0 ]] || fail "run payload has an empty job list -- fail-closed"

RUN_DBID="$(echo "$RUN_JSON" | jq -r '.databaseId // empty')"; [[ -n "$RUN_DBID" ]] || RUN_DBID="${RUN_ID:-unknown}"

# ---------------------------------------------------------------------------
# Resolve docs_only from the `changes` job's own log.
# ---------------------------------------------------------------------------
if [[ -n "$DOCS_ONLY_OVERRIDE" ]]; then
  DOCS_ONLY="$DOCS_ONLY_OVERRIDE"
else
  CHANGES_JOB_ID="$(echo "$RUN_JSON" | jq -r '.jobs[] | select(.name == "Detect docs-only change") | .databaseId' | head -1)"
  [[ -n "$CHANGES_JOB_ID" && "$CHANGES_JOB_ID" != "null" ]] \
    || fail "run ${RUN_DBID} has no 'Detect docs-only change' job -- cannot establish the classification honestly"
  LOG="$(gh run view "$RUN_ID" --repo "$REPO" --log --job "$CHANGES_JOB_ID" 2>/dev/null)" \
    || fail "could not read the changes job log for run ${RUN_DBID}"
  # `grep -oE` exits 1 when the pattern is absent; under `set -o pipefail` that would abort
  # the script HERE, fail-closed but with no diagnostic. Swallow the status so the explicit
  # emptiness check below is what reports, and the operator learns why.
  DOCS_ONLY="$(printf '%s' "$LOG" | grep -oE 'docs_only=(true|false)' | tail -1 | cut -d= -f2 || true)"
  [[ -n "$DOCS_ONLY" ]] \
    || fail "the changes job log for run ${RUN_DBID} emitted no docs_only= line -- refusing to infer the classification"
fi

if [[ "$DOCS_ONLY" != "true" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    jq -n --arg run "$RUN_DBID" '{run_id: $run, docs_only: false, verdict: "n/a",
      note: "not a docs-only run; this receipt makes a conditional claim and was not exercised"}'
  else
    printf 'Docs-only receipt -- run %s: docs_only=false, nothing to assert (n/a).\n' "$RUN_DBID"
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# docs_only == true: assert merge-eligibility and the un-gated lanes.
# ---------------------------------------------------------------------------
VERDICTS="[]"
EXIT_CODE=0

assert_job() {
  local name="$1" role="$2" require_nonzero="$3" node status concl dur verdict reason
  node="$(echo "$RUN_JSON" | jq -c --arg n "$name" '.jobs[] | select(.name == $n)' | head -1)"
  if [[ -z "$node" ]]; then
    verdict="FAIL"; reason="required context absent from the run -- a context that is never created leaves the PR pending forever (D-06)"
    status=""; concl=""; dur=0
  else
    status="$(echo "$node" | jq -r '.status // ""')"
    concl="$(echo "$node" | jq -r '.conclusion // ""')"
    dur="$(echo "$node" | jq -r '
      if (.completedAt // "") == "" or (.startedAt // "") == "" then 0
      elif (.completedAt | startswith("0001-")) then 0
      else (((.completedAt|fromdate) - (.startedAt|fromdate)) as $r | if $r < 0 then 0 else $r end) end')"
    if [[ "$status" != "completed" ]]; then
      verdict="FAIL"; reason="status '${status:-<empty>}' is not 'completed'"
    elif [[ "$concl" != "success" ]]; then
      verdict="FAIL"; reason="concluded '${concl:-<empty>}', not 'success' -- not merge-eligible"
    elif [[ "$require_nonzero" == "yes" && "$dur" -le 0 ]]; then
      verdict="FAIL"; reason="ran for 0s -- this lane must execute in full on a docs-only PR, not be gated off"
    else
      verdict="PASS"; reason="${concl} (${dur}s)"
    fi
  fi
  [[ "$verdict" == "PASS" ]] || EXIT_CODE=1
  VERDICTS="$(echo "$VERDICTS" | jq --arg name "$name" --arg role "$role" --arg status "$status" \
    --arg concl "$concl" --argjson dur "${dur:-0}" --arg verdict "$verdict" --arg reason "$reason" \
    '. + [{name: $name, role: $role, status: $status, conclusion: $concl,
           duration_seconds: $dur, verdict: $verdict, reason: $reason}]')"
}

for ctx in "${REQUIRED_CONTEXTS[@]}"; do assert_job "$ctx" "required-context" "no"; done
for ctx in "${MUST_RUN_FULL[@]}"; do assert_job "$ctx" "must-run-in-full" "yes"; done

# The sharded library suite must also have executed in full. Its job names are
# `Library tests shard <n>`, so match by prefix and require at least one shard.
SHARDS="$(echo "$RUN_JSON" | jq -c '[.jobs[] | select(.name | startswith("Library tests shard"))]')"
SHARD_COUNT="$(echo "$SHARDS" | jq 'length')"
if [[ "$SHARD_COUNT" -lt 1 ]]; then
  EXIT_CODE=1
  VERDICTS="$(echo "$VERDICTS" | jq '. + [{name: "Library tests shard *", role: "must-run-in-full",
    verdict: "FAIL", reason: "no library test shard ran on a docs-only PR -- the suite that reads .planning/** was gated off"}]')"
else
  while IFS= read -r shard_name; do
    assert_job "$shard_name" "must-run-in-full" "yes"
  done < <(echo "$SHARDS" | jq -r '.[].name')
fi

case "$FORMAT" in
  json)
    jq -n --arg run "$RUN_DBID" --argjson checks "$VERDICTS" --argjson code "$EXIT_CODE" \
      '{run_id: $run, docs_only: true, checks: $checks,
        verdict: (if $code == 0 then "PASS" else "FAIL" end)}'
    ;;
  table)
    printf 'Docs-only receipt -- run %s (docs_only=true)\n\n' "$RUN_DBID"
    { printf 'lane\trole\tconclusion\tduration\tverdict\n'
      echo "$VERDICTS" | jq -r '.[] | "\(.name)\t\(.role)\t\(.conclusion // "-")\t\(.duration_seconds // 0)s\t\(.verdict)"'
    } | column -t -s $'\t'
    echo
    echo "$VERDICTS" | jq -r '.[] | select(.verdict == "FAIL") | "  FAIL \(.name): \(.reason)"'
    [[ "$EXIT_CODE" -ne 0 ]] || echo "  all five required contexts merge-eligible; fast_checks and the library suite ran in full."
    ;;
esac

exit "$EXIT_CODE"
