#!/usr/bin/env bash
# Data-only identity and candidate-content gate for the trusted workflow_run merge job.
set -euo pipefail

REPOSITORY=""
EVENT_RUN=""
QUERIED_RUN=""
PULL_REQUESTS=""
GATE_JOBS=""
CHANGELOG=""
LEDGER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository) REPOSITORY="$2"; shift 2;;
    --event-run) EVENT_RUN="$2"; shift 2;;
    --queried-run) QUERIED_RUN="$2"; shift 2;;
    --pull-requests) PULL_REQUESTS="$2"; shift 2;;
    --gate-jobs) GATE_JOBS="$2"; shift 2;;
    --changelog) CHANGELOG="$2"; shift 2;;
    --ledger) LEDGER="$2"; shift 2;;
    -h|--help)
      echo "usage: release-candidate-preflight.sh --repository owner/name --event-run FILE --queried-run FILE --pull-requests FILE --gate-jobs FILE [--changelog FILE --ledger FILE]"
      exit 0
      ;;
    *) echo "release-candidate-preflight: FAIL: unknown argument: $1" >&2; exit 2;;
  esac
done

fail() { echo "release-candidate-preflight: FAIL: $*" >&2; exit 1; }

[[ -n "$REPOSITORY" ]] || fail "repository is required"
for input in "$EVENT_RUN" "$QUERIED_RUN" "$PULL_REQUESTS" "$GATE_JOBS"; do
  [[ -n "$input" && -f "$input" ]] || fail "required JSON input file is missing"
done
if [[ -n "$CHANGELOG" || -n "$LEDGER" ]]; then
  [[ -n "$CHANGELOG" && -f "$CHANGELOG" ]] || fail "candidate changelog input is missing"
  [[ -n "$LEDGER" && -f "$LEDGER" ]] || fail "candidate ledger input is missing"
fi

jq -e --arg repository "$REPOSITORY" '
  type == "object"
  and .repository == $repository
  and .workflow_name == "CI"
  and (.run_id | type == "number")
  and .event == "push"
  and .head_branch == "release-please--branches--main"
  and (.head_sha | type == "string" and test("^[0-9a-f]{40}$"))
  and .conclusion == "success"
' "$EVENT_RUN" >/dev/null 2>&1 || fail "workflow_run event is not a successful CI push on the configured Release Please branch"

jq -e --arg repository "$REPOSITORY" --slurpfile event "$EVENT_RUN" '
  type == "object"
  and .repository == $repository
  and .workflowName == "CI"
  and (.databaseId | type == "number")
  and .databaseId == $event[0].run_id
  and .event == $event[0].event
  and .headBranch == $event[0].head_branch
  and .headSha == $event[0].head_sha
  and .conclusion == "success"
  and (.url | type == "string" and startswith("https://github.com/"))
' "$QUERIED_RUN" >/dev/null 2>&1 || fail "queried CI run identity, branch, SHA, or conclusion differs from workflow_run event"

jq -e --slurpfile event "$EVENT_RUN" --arg repository "$REPOSITORY" '
  type == "array" and length == 1
  and (.[0].number | type == "number")
  and .[0].state == "OPEN"
  and .[0].baseRefName == "main"
  and .[0].headRefName == "release-please--branches--main"
  and (.[0].headRefOid | type == "string" and test("^[0-9a-f]{40}$"))
  and .[0].headRefOid == $event[0].head_sha
  and (.[0].title | type == "string" and test("^chore\\(main\\): release [0-9]+\\.[0-9]+\\.[0-9]+$"))
  and .[0].headRepository.nameWithOwner == $repository
  and (.[0].labels | type == "array" and any(.[]; .name == "autorelease: pending"))
' "$PULL_REQUESTS" >/dev/null 2>&1 || fail "there must be exactly one open candidate whose full head SHA matches the CI run"

jq -e 'type == "array" and (map(select(.name == "ci-gate")) | length) == 1 and any(.[]; .name == "ci-gate" and .conclusion == "success")' \
  "$GATE_JOBS" >/dev/null 2>&1 || fail "the source CI run has no single successful ci-gate job"

PR_NUMBER="$(jq -r '.[0].number' "$PULL_REQUESTS")"
PR_HEAD_SHA="$(jq -r '.[0].headRefOid' "$PULL_REQUESTS")"
PR_TITLE="$(jq -r '.[0].title' "$PULL_REQUESTS")"
PR_URL="$(jq -r '.[0].url' "$PULL_REQUESTS")"
VERSION="$(sed -E 's/^chore\(main\): release ([0-9]+\.[0-9]+\.[0-9]+)$/\1/' <<<"$PR_TITLE")"

jq -cn --arg repository "$REPOSITORY" --argjson pr_number "$PR_NUMBER" \
  --arg head_sha "$PR_HEAD_SHA" --arg title "$PR_TITLE" --arg pr_url "$PR_URL" \
  --arg version "$VERSION" --arg run_id "$(jq -r '.databaseId' "$QUERIED_RUN")" \
  --arg run_url "$(jq -r '.url' "$QUERIED_RUN")" \
  '{verdict:"PASS", repository:$repository, pr_number:$pr_number, head_sha:$head_sha, title:$title, version:$version, pr_url:$pr_url, run_id:($run_id|tonumber), run_url:$run_url}'
