#!/usr/bin/env bash
# Correlate one completed workflow_run event to the authoritative source run and
# persist a cancellation receipt without checking out or executing source code.
set -euo pipefail

EVENT_FILE="${EVENT_PATH:-}"
SOURCE_RUN_ID_INPUT=""
OUTPUT_PATH="release-cancellation.json"
fail() { echo "release-observer: FAIL: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event) [[ $# -ge 2 ]] || fail "--event requires a path"; EVENT_FILE="$2"; shift 2 ;;
    --source-run-id) [[ $# -ge 2 ]] || fail "--source-run-id requires an ID"; SOURCE_RUN_ID_INPUT="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || fail "--output requires a path"; OUTPUT_PATH="$2"; shift 2 ;;
    -h|--help) echo "Usage: release-observer.sh (--event <workflow_run-event.json> | --source-run-id <cancelled-canary-run-id>) [--output <receipt.json>]"; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -z "$EVENT_FILE" || -z "$SOURCE_RUN_ID_INPUT" ]] || fail "choose exactly one event source"
[[ -n "${GITHUB_REPOSITORY:-}" && "$GITHUB_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "observer repository identity is missing or malformed"
[[ -n "${GITHUB_RUN_ID:-}" && "$GITHUB_RUN_ID" =~ ^[1-9][0-9]*$ ]] || fail "observer run ID is missing or malformed"
[[ -n "${GITHUB_RUN_ATTEMPT:-}" && "$GITHUB_RUN_ATTEMPT" =~ ^[1-9][0-9]*$ ]] || fail "observer run attempt is missing or malformed"
[[ -n "${GITHUB_SERVER_URL:-}" && "$GITHUB_SERVER_URL" =~ ^https://github\.com$ ]] || fail "GitHub server URL is invalid"
[[ -n "${GH_TOKEN:-}" ]] || fail "GitHub API token is unavailable"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v gh >/dev/null 2>&1 || fail "gh is required"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

SOURCE_RUN=""
if [[ -n "$SOURCE_RUN_ID_INPUT" ]]; then
  [[ "$GITHUB_EVENT_NAME" == workflow_dispatch ]] || fail "source-run-id mode requires workflow_dispatch"
  [[ "$SOURCE_RUN_ID_INPUT" =~ ^[1-9][0-9]*$ ]] || fail "source run ID is malformed"
  SOURCE_RUN="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${SOURCE_RUN_ID_INPUT}" 2>/dev/null)" || fail "authoritative source run query failed"
  jq -e --argjson id "$SOURCE_RUN_ID_INPUT" '.id == $id and type == "object"' <<<"$SOURCE_RUN" >/dev/null 2>&1 || fail "source run ID does not match authoritative Actions metadata"
  EVENT_FILE="$WORK_DIR/source-run-event.json"
  jq -n --arg repository "$GITHUB_REPOSITORY" --argjson run "$SOURCE_RUN" \
    '{repository:{full_name:$repository},workflow_run:{id:$run.id,head_sha:$run.head_sha,event:$run.event,workflow_id:$run.workflow_id}}' > "$EVENT_FILE" || fail "could not construct authoritative source context"
fi
[[ -n "$EVENT_FILE" && -f "$EVENT_FILE" ]] || fail "workflow_run event file is required"

EVENT_RUN_ID="$(jq -er '.workflow_run.id | select(type == "number" and floor == . and . > 0) | tostring' "$EVENT_FILE" 2>/dev/null)" || fail "event source run ID is malformed"
EVENT_SHA="$(jq -er '.workflow_run.head_sha | select(type == "string" and test("^[0-9a-f]{40}$"))' "$EVENT_FILE" 2>/dev/null)" || fail "event source SHA is malformed"
EVENT_REPOSITORY="$(jq -er '.repository.full_name | select(type == "string")' "$EVENT_FILE" 2>/dev/null)" || fail "event repository identity is missing"
EVENT_EVENT="$(jq -er '.workflow_run.event | select(type == "string")' "$EVENT_FILE" 2>/dev/null)" || fail "event source event is missing"
EVENT_WORKFLOW_ID="$(jq -er '.workflow_run.workflow_id | select(type == "number" and floor == . and . > 0)' "$EVENT_FILE" 2>/dev/null)" || fail "event source workflow ID is malformed"
[[ "$EVENT_REPOSITORY" == "$GITHUB_REPOSITORY" ]] || fail "event repository does not match observer repository"

if [[ -z "$SOURCE_RUN" ]]; then
  SOURCE_RUN="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${EVENT_RUN_ID}" 2>/dev/null)" || fail "authoritative source run query failed"
fi
jq -e 'type == "object"' <<<"$SOURCE_RUN" >/dev/null 2>&1 || fail "authoritative source run is not an object"

API_REPOSITORY="$(jq -er '.repository.full_name | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source repository is missing"
API_RUN_ID="$(jq -er '.id | select(type == "number" and floor == . and . > 0) | tostring' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source run ID is malformed"
API_SHA="$(jq -er '.head_sha | select(type == "string" and test("^[0-9a-f]{40}$"))' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source SHA is malformed"
API_EVENT="$(jq -er '.event | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source event is missing"
API_BRANCH="$(jq -er '.head_branch | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source branch is missing"
API_CONCLUSION="$(jq -er '.conclusion | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source conclusion is missing"
API_WORKFLOW_ID="$(jq -er '.workflow_id | select(type == "number" and floor == . and . > 0)' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source workflow ID is malformed"
API_WORKFLOW_NAME="$(jq -er '.name | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source workflow name is missing"
API_WORKFLOW_PATH="$(jq -er '.path | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source workflow path is missing"
API_URL="$(jq -er '.html_url | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source run URL is missing"
API_ATTEMPT="$(jq -er '.run_attempt | select(type == "number" and floor == . and . > 0)' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source attempt is malformed"
API_STARTED="$(jq -er '.run_started_at | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "authoritative source start time is missing"

case "$API_WORKFLOW_PATH" in
  .github/workflows/release-please.yml|.github/workflows/release-please.yml@main)
    WORKFLOW="$(gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/release-please.yml" 2>/dev/null)" || fail "authoritative Release Please workflow query failed"
    ;;
  .github/workflows/release-receipt-canary.yml|.github/workflows/release-receipt-canary.yml@main)
    WORKFLOW="$(gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary.yml" 2>/dev/null)" || fail "authoritative canary workflow query failed"
    ;;
  *) fail "unsupported source workflow path" ;;
esac
jq -e 'type == "object"' <<<"$WORKFLOW" >/dev/null 2>&1 || fail "authoritative workflow is not an object"

WORKFLOW_ID="$(jq -er '.id | select(type == "number" and floor == . and . > 0)' <<<"$WORKFLOW" 2>/dev/null)" || fail "Release Please workflow ID is malformed"
WORKFLOW_NAME="$(jq -er '.name | select(type == "string")' <<<"$WORKFLOW" 2>/dev/null)" || fail "Release Please workflow name is missing"
WORKFLOW_PATH="$(jq -er '.path | select(type == "string")' <<<"$WORKFLOW" 2>/dev/null)" || fail "Release Please workflow path is missing"

if [[ "$API_WORKFLOW_PATH" == .github/workflows/release-receipt-canary.yml* ]]; then
  [[ "$API_REPOSITORY" == "$GITHUB_REPOSITORY" ]] || fail "authoritative canary repository mismatch"
  [[ "$API_RUN_ID" == "$EVENT_RUN_ID" ]] || fail "authoritative canary run ID mismatch"
  [[ "$API_SHA" == "$EVENT_SHA" ]] || fail "authoritative canary SHA mismatch"
  [[ "$API_EVENT" == workflow_dispatch && "$EVENT_EVENT" == workflow_dispatch ]] || fail "canary event is not workflow_dispatch"
  [[ "$API_BRANCH" == main ]] || fail "canary source run did not target main"
  [[ "$API_CONCLUSION" == cancelled ]] || fail "canary source run was not cancelled"
  [[ "$API_WORKFLOW_NAME" == "Release Receipt Canary" && "$WORKFLOW_NAME" == "Release Receipt Canary" ]] || fail "canary workflow name mismatch"
  [[ "$API_WORKFLOW_PATH" =~ ^\.github/workflows/release-receipt-canary\.yml(@main)?$ && "$WORKFLOW_PATH" == .github/workflows/release-receipt-canary.yml ]] || fail "canary workflow path mismatch"
  [[ "$API_WORKFLOW_ID" == "$WORKFLOW_ID" && "$EVENT_WORKFLOW_ID" == "$API_WORKFLOW_ID" ]] || fail "canary workflow ID mismatch"

  DISPLAY_TITLE="$(jq -er '.display_title | select(type == "string")' <<<"$SOURCE_RUN" 2>/dev/null)" || fail "canary display title is missing"
  [[ "$DISPLAY_TITLE" =~ ^release-receipt-canary-cancellation-([a-f0-9-]{16,64})$ ]] || fail "canary probe identity is malformed"
  PROBE_ID="${BASH_REMATCH[1]}"
  [[ "$API_STARTED" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?Z$ ]] || fail "canary source start timestamp is malformed"
  SOURCE_STARTED="${BASH_REMATCH[1]}Z"
  SOURCE_OBSERVED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  [[ "$API_URL" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$ ]] || fail "canary source URL is malformed"

  OBSERVER_RUN="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}" 2>/dev/null)" || fail "authoritative observer run query failed"
  OBSERVER_WORKFLOW="$(gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/release-run-observer.yml" 2>/dev/null)" || fail "authoritative observer workflow query failed"
  OBSERVER_ATTEMPT="$(jq -er '.run_attempt | select(type == "number" and floor == . and . >= 1)' <<<"$OBSERVER_RUN" 2>/dev/null)" || fail "observer attempt is malformed"
  OBSERVER_WORKFLOW_ID="$(jq -er '.id | select(type == "number" and floor == . and . > 0)' <<<"$OBSERVER_WORKFLOW" 2>/dev/null)" || fail "observer workflow ID is malformed"
  OBSERVER_STARTED_RAW="$(jq -er '.run_started_at | select(type == "string")' <<<"$OBSERVER_RUN" 2>/dev/null)" || fail "observer start time is missing"
  [[ "$OBSERVER_STARTED_RAW" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?Z$ ]] || fail "observer start timestamp is malformed"
  OBSERVER_STARTED="${BASH_REMATCH[1]}Z"
  OBSERVER_COMPLETED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  OBSERVER_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  jq -n --arg probe_id "$PROBE_ID" --arg sha "$API_SHA" --arg repository "$GITHUB_REPOSITORY" --arg source_started "$SOURCE_STARTED" \
    --arg source_observed "$SOURCE_OBSERVED" --arg source_url "$API_URL" --arg source_id "$API_RUN_ID" \
    --argjson source_attempt "$API_ATTEMPT" --argjson source_workflow_id "$API_WORKFLOW_ID" \
    --arg observer_id "$GITHUB_RUN_ID" --arg observer_url "$OBSERVER_URL" \
    --arg observer_started "$OBSERVER_STARTED" --arg observer_observed "$OBSERVER_COMPLETED" \
    --argjson observer_attempt "$OBSERVER_ATTEMPT" --argjson observer_workflow_id "$OBSERVER_WORKFLOW_ID" \
    '{schema_version:1,receipt_kind:"canary",canary:{probe_id:$probe_id,scenario:"cancellation"},
      source_event:"workflow_dispatch",source:{repository:$repository,ref:"refs/heads/main",sha:$sha},
      source_run:{id:$source_id,attempt:$source_attempt,workflow_id:$source_workflow_id,
        workflow_name:"Release Receipt Canary",workflow_path:".github/workflows/release-receipt-canary.yml",
        url:$source_url,started_at:$source_started,observed_at:$source_observed},
      terminal_verdict:"cancelled",observer_run:{id:$observer_id,attempt:$observer_attempt,
        workflow_id:$observer_workflow_id,url:$observer_url,started_at:$observer_started,
        observed_at:$observer_observed}}' > "$WORK_DIR/canary-receipt-input.json" || fail "could not construct canary cancellation receipt"
  bash "$SCRIPT_DIR/release-receipt.sh" --mode canary --expected-workflow-id "$WORKFLOW_ID" --input "$WORK_DIR/canary-receipt-input.json" --output "$OUTPUT_PATH"
  echo "release-observer: recorded canary cancellation source run ${EVENT_RUN_ID}"
  exit 0
fi

[[ "$API_REPOSITORY" == "$GITHUB_REPOSITORY" ]] || fail "authoritative source repository mismatch"
[[ "$API_RUN_ID" == "$EVENT_RUN_ID" ]] || fail "authoritative source run ID mismatch"
[[ "$API_SHA" == "$EVENT_SHA" ]] || fail "authoritative source SHA mismatch"
[[ "$API_EVENT" == "$EVENT_EVENT" ]] || fail "authoritative source event mismatch"
[[ "$API_EVENT" == "push" || "$API_EVENT" == "workflow_dispatch" ]] || fail "unsupported source event"
[[ "$API_BRANCH" == main ]] || fail "source run did not target main"
[[ "$API_CONCLUSION" == cancelled ]] || fail "source run was not cancelled"
[[ "$API_WORKFLOW_NAME" == "Release Please" && "$WORKFLOW_NAME" == "Release Please" ]] || fail "source workflow name mismatch"
[[ "$API_WORKFLOW_PATH" =~ ^\.github/workflows/release-please\.yml(@main)?$ && "$WORKFLOW_PATH" == .github/workflows/release-please.yml ]] || fail "source workflow path mismatch"
[[ "$API_WORKFLOW_ID" == "$WORKFLOW_ID" ]] || fail "source workflow ID mismatch"
[[ "$EVENT_WORKFLOW_ID" == "$API_WORKFLOW_ID" ]] || fail "event source workflow ID mismatch"

RUN_URL_RE='^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$'
[[ "$API_URL" =~ $RUN_URL_RE ]] || fail "authoritative source run URL is malformed"
OBSERVER_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
[[ "$OBSERVER_URL" =~ $RUN_URL_RE ]] || fail "observer run URL is malformed"
[[ "$GITHUB_RUN_ID" != "$EVENT_RUN_ID" ]] || fail "observer and source run IDs must differ"

MANIFEST_CONTENT="$(gh api "repos/${GITHUB_REPOSITORY}/contents/.release-please-manifest.json?ref=${API_SHA}" --jq .content 2>/dev/null)" || fail "source release manifest query failed"
printf '%s' "$MANIFEST_CONTENT" | jq -Rs 'gsub("\\s"; "") | @base64d | fromjson' > "$WORK_DIR/manifest.json" 2>/dev/null || fail "source release manifest is not valid base64 JSON"
jq -e 'type == "object"' "$WORK_DIR/manifest.json" >/dev/null 2>&1 || fail "source release manifest is not a JSON object"
VERSION="$(jq -er '. ["."] | select(type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+([-.][0-9A-Za-z.-]+)?$"))' "$WORK_DIR/manifest.json" 2>/dev/null)" || fail "source release manifest version is missing or malformed"
EXPECTED_TAG="v${VERSION}"
TAG_DIAGNOSTIC=""
TAG_MATCHES_SOURCE=false
TAG_RESPONSE="$(gh api "repos/${GITHUB_REPOSITORY}/commits/${EXPECTED_TAG}" 2>/dev/null || true)"
if [[ -z "$TAG_RESPONSE" ]]; then
  TAG_DIAGNOSTIC="tag_not_found"
else
  TAG_SHA="$(jq -r '.sha // empty' <<<"$TAG_RESPONSE" 2>/dev/null || true)"
  if [[ ! "$TAG_SHA" =~ ^[0-9a-f]{40}$ ]]; then
    TAG_DIAGNOSTIC="tag_invalid_response"
  elif [[ "$TAG_SHA" == "$API_SHA" ]]; then
    TAG_MATCHES_SOURCE=true
  else
    TAG_DIAGNOSTIC="tag_sha_mismatch"
  fi
fi

[[ "$API_STARTED" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?Z$ ]] || fail "source run start timestamp is malformed"
RECEIPT_STARTED="${BASH_REMATCH[1]}Z"
jq -n \
  --arg run_id "$EVENT_RUN_ID" --argjson attempt "$API_ATTEMPT" --arg run_url "$API_URL" \
  --arg workflow "$API_WORKFLOW_NAME" --arg workflow_url "https://github.com/${GITHUB_REPOSITORY}/actions/workflows/release-please.yml" \
  --arg event "$API_EVENT" --arg version "$VERSION" --arg tag "$EXPECTED_TAG" --arg sha "$API_SHA" \
  --arg started "$RECEIPT_STARTED" --arg observer_id "$GITHUB_RUN_ID" --arg observer_url "$OBSERVER_URL" \
  --arg diagnostic "$TAG_DIAGNOSTIC" --argjson tag_matches "$TAG_MATCHES_SOURCE" \
  '{schema_version:1,
    release_run:{id:$run_id,attempt:$attempt,url:$run_url,workflow_name:$workflow,workflow_url:$workflow_url,started_at:$started,completed_at:null},
    source_event:$event,source:{version:$version,tag:$tag,sha:$sha},
    gate:null,publish:{outcome:"not_run",started_at:null,completed_at:null},
    terminal_verdict:"cancelled",failure:null,
    observer_run:{id:$observer_id,url:$observer_url},
    stages:{source_run:{conclusion:"cancelled",event:$event,head_branch:"main",run_attempt:$attempt},
      source_tag:({expected:$tag,resolves_to_source:$tag_matches} + (if $diagnostic == "" then {} else {diagnostic:$diagnostic} end))}}' \
  > "$WORK_DIR/receipt-input.json" || fail "could not construct cancellation receipt input"
bash "$SCRIPT_DIR/release-receipt.sh" --input "$WORK_DIR/receipt-input.json" --output "$OUTPUT_PATH"
echo "release-observer: recorded cancelled source run ${EVENT_RUN_ID}"
