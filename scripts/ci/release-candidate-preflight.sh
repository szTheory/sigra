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

if [[ -n "$CHANGELOG" ]]; then
  VERSION_HEADING_COUNT="$(grep -F -c "## [${VERSION}]" "$CHANGELOG" || true)"
  [[ "$VERSION_HEADING_COUNT" -eq 1 ]] || fail "CHANGELOG must contain exactly one version section for ${VERSION}"

  VERSION_SECTION="$(awk -v heading="## [${VERSION}]" '
    index($0, heading) == 1 { active=1; next }
    active && /^## / { exit }
    active { print }
  ' "$CHANGELOG")"
  [[ -n "$VERSION_SECTION" ]] || fail "the ${VERSION} changelog section is empty"

  UNRELEASED_NOTES="$(awk '
    /^## Unreleased$/ { active=1; next }
    active && /^## / { exit }
    active && /^[[:space:]]*[-*+][[:space:]]+/ { print }
  ' "$CHANGELOG")"
  [[ -z "$UNRELEASED_NOTES" ]] || fail "candidate changelog notes remain under Unreleased"

  VERSION_NOTES="$(awk '
    /^[[:space:]]*[-*+][[:space:]]+/ { print }
  ' <<<"$VERSION_SECTION" | sed -E 's/\[([^]]+)\]\([^)]*\)/\1/g' \
      | tr '[:upper:]' '[:lower:]' | sed -E 's/[^[:alnum:]]+/ /g; s/[[:space:]]+/ /g; s/^ | $//g' \
      | sort | uniq -d)"
  [[ -z "$VERSION_NOTES" ]] || fail "duplicate normalized changelog note: ${VERSION_NOTES}"

  jq -e '
    . as $ledger
    | ($ledger.source_selection.status == "ready"
      and ($ledger.source_selection.selected_source_sha | type == "string" and test("^[0-9a-f]{40}$"))
      and $ledger.final_validation.valid == true and $ledger.final_validation.status == "ready"
      and ($ledger.final_readiness.source_sha | type == "string" and test("^[0-9a-f]{40}$"))
      and $ledger.final_validation.checked.pr_head_sha == $ledger.final_readiness.source_sha
      and $ledger.final_readiness.docs.candidate_summary_under_versioned_heading == true
      and ($ledger.final_readiness.docs.candidate_summary_only_unreleased // false) == false
      and ($ledger.final_readiness.claim_sources | type == "array" and length > 0)
      and all($ledger.final_readiness.claim_sources[];
        (.claim | type == "string" and length > 0)
        and (.source | type == "string" and length > 0)
        and (.evidence | type == "string" and length > 0)
        and (.source_paths | type == "array" and length > 0)
        and .source_paths_present == true
        and .source_sha == $ledger.final_readiness.source_sha
        and (.ci_run_id | type == "number")
      ))
  ' "$LEDGER" >/dev/null 2>&1 || fail "candidate readiness ledger is blocked, stale internally, or missing source-backed adopter claim evidence"

  jq -e --arg head_sha "$PR_HEAD_SHA" --argjson run_id "$(jq -r '.databaseId' "$QUERIED_RUN")" '
    (.source_selection.selected_source_sha | type == "string" and test("^[0-9a-f]{40}$"))
    and .final_readiness.source_sha == $head_sha
    and .final_validation.checked.pr_head_sha == $head_sha
    and all(.final_readiness.claim_sources[]; .source_sha == $head_sha and .ci_run_id == $run_id)
  ' "$LEDGER" >/dev/null 2>&1 || fail "candidate ledger source or CI evidence does not bind to the exact PR head and successful run"

  normalize_tokens() {
    tr '[:upper:]' '[:lower:]' <<<"$1" | tr -cs '[:alnum:]' '\n' | awk '
      BEGIN { split("about after again also and are around as at be been before being between both but by can could did do does down during each else enough every few for from further had has have he her here hers herself him himself his how if in into is it its itself just more most nor not of off on once only onto or other our ours ourselves out over own same she should so some such than that the their theirs them themselves then there these they this those through to too under until up upon us very was we were what when where which while who whom why will with would you your yours yourselves without", words, " "); for (i in words) stop[words[i]]=1 }
      {
        word=$0
        if (length(word) > 5 && substr(word, length(word)-2) == "ies") word=substr(word, 1, length(word)-3) "y"
        else if (length(word) > 4 && substr(word, length(word), 1) == "s" && word != "business" && word != "process") word=substr(word, 1, length(word)-1)
        else if (length(word) > 5 && substr(word, length(word)-1) == "ly") word=substr(word, 1, length(word)-2)
        if (length(word) >= 4 && !stop[word]) print word
      }
    ' | sort -u
  }

  VERSION_BLOCKS="$(awk '
    function flush() { if (block ~ /[^[:space:]]/) print block; block="" }
    /^[[:space:]]*$/ { flush(); next }
    /^## / { flush(); next }
    /^### / { flush(); next }
    /^[[:space:]]*[-*+][[:space:]]+/ { flush(); sub(/^[[:space:]]*[-*+][[:space:]]+/, ""); block=$0; flush(); next }
    { if (block != "") block=block " " $0; else block=$0 }
    END { flush() }
  ' <<<"$VERSION_SECTION" | sed -E 's/\[([^]]+)\]\([^)]*\)/\1/g')"
  BLOCK_TOKEN_SETS=()
  while IFS= read -r BLOCK; do
    BLOCK_TOKEN_SETS+=("$(normalize_tokens "$BLOCK")")
  done <<<"$VERSION_BLOCKS"

  while IFS= read -r CLAIM_ROW; do
    CLAIM="$(jq -r '.claim' <<<"$CLAIM_ROW")"
    CLAIM_TOKENS="$(normalize_tokens "$CLAIM")"
    TOTAL_TOKENS="$(wc -l <<<"$CLAIM_TOKENS" | tr -d '[:space:]')"
    BEST_MATCH=0
    for BLOCK_TOKEN_SET in "${BLOCK_TOKEN_SETS[@]}"; do
      MATCHED_TOKENS="$(comm -12 <(printf '%s\n' "$CLAIM_TOKENS") \
        <(printf '%s\n' "$BLOCK_TOKEN_SET") | wc -l | tr -d '[:space:]')"
      (( MATCHED_TOKENS > BEST_MATCH )) && BEST_MATCH=$MATCHED_TOKENS || true
    done
    (( BEST_MATCH >= 3 && BEST_MATCH * 100 >= TOTAL_TOKENS * 40 )) \
      || fail "source-backed adopter summary is absent from the ${VERSION} section: ${CLAIM}"
  done < <(jq -c '.final_readiness.claim_sources[]' "$LEDGER")
fi

jq -cn --arg repository "$REPOSITORY" --argjson pr_number "$PR_NUMBER" \
  --arg head_sha "$PR_HEAD_SHA" --arg title "$PR_TITLE" --arg pr_url "$PR_URL" \
  --arg version "$VERSION" --arg run_id "$(jq -r '.databaseId' "$QUERIED_RUN")" \
  --arg run_url "$(jq -r '.url' "$QUERIED_RUN")" \
  '{verdict:"PASS", repository:$repository, pr_number:$pr_number, head_sha:$head_sha, title:$title, version:$version, pr_url:$pr_url, run_id:($run_id|tonumber), run_url:$run_url}'
