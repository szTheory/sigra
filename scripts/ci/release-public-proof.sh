#!/usr/bin/env bash
# Read-only proof that one published Hex release matches its tagged source and CI.
set -euo pipefail

REPOSITORY="szTheory/sigra"
PACKAGE="sigra"
VERSION=""
PREFLIGHT=""
OUTPUT=""
usage() {
  echo "Usage: release-public-proof.sh --version <semver> --preflight <path> --output <path>" >&2
}
fail_usage() { echo "release-public-proof: FAIL: $1" >&2; usage; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) [[ $# -ge 2 ]] || fail_usage "--version requires a value"; VERSION="$2"; shift 2 ;;
    --preflight) [[ $# -ge 2 ]] || fail_usage "--preflight requires a path"; PREFLIGHT="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || fail_usage "--output requires a path"; OUTPUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail_usage "unknown argument" ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail_usage "version must be a stable semantic version"
[[ -n "$PREFLIGHT" && -n "$OUTPUT" && "$PREFLIGHT" != "$OUTPUT" ]] || fail_usage "distinct preflight and output paths are required"

for command_name in gh curl jq node unzip git; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "release-public-proof: FAIL: required command unavailable" >&2
    exit 1
  }
done

TAG="v${VERSION}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sigra-release-proof.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
CHECKS='[]'
BLOCKERS='[]'
OBSERVED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
MAIN_SHA=""
SOURCE_SHA=""
RELEASE_RUN_ID=""
RELEASE_ATTEMPT=""
RELEASE_RUN_URL=""
ARTIFACT_ID=""
ARTIFACT_NAME=""
ARTIFACT_URL=""
CI_RUN_ID=""
CI_ATTEMPT=""
CI_RUN_URL=""
CI_GATE_JOB_ID=""
CI_GATE_URL=""
HEX_URL="https://hex.pm/packages/${PACKAGE}/${VERSION}"
HEX_API_URL="https://hex.pm/api/packages/${PACKAGE}/releases/${VERSION}"
HEX_CHECKSUM=""
DOCS_URL="https://hexdocs.pm/${PACKAGE}/${VERSION}/Sigra.html"
DOCS_EFFECTIVE_URL=""
SOURCE_HREF=""
SOURCE_PATH=""
SOURCE_BLOB_SHA=""
CANDIDATE_JSON='null'
WORKTREE_SHA=""
WORKTREE_CLEAN=false

record_check() {
  local id="$1" status="$2" detail="${3-}"
  [[ -n "$detail" ]] || detail='{}'
  CHECKS="$(jq -cn --argjson checks "$CHECKS" --arg id "$id" --arg status "$status" --argjson detail "$detail" \
    '$checks + [($detail + {id:$id,status:$status})]')"
}
record_blocker() {
  local id="$1"
  BLOCKERS="$(jq -cn --argjson blockers "$BLOCKERS" --arg id "$id" '$blockers + [$id]')"
}
write_preflight() {
  local verdict="ready" temp
  [[ "$BLOCKERS" == '[]' ]] || verdict="blocked"
  mkdir -p "$(dirname -- "$PREFLIGHT")"
  temp="${PREFLIGHT}.tmp.$$"
  jq -n \
    --arg observed_at "$OBSERVED_AT" --arg repository "$REPOSITORY" --arg package "$PACKAGE" --arg version "$VERSION" --arg tag "$TAG" \
    --arg current_main_sha "$MAIN_SHA" --arg package_source_sha "$SOURCE_SHA" \
    --arg release_run_id "$RELEASE_RUN_ID" --arg release_run_attempt "$RELEASE_ATTEMPT" \
    --arg artifact_id "$ARTIFACT_ID" --arg artifact_name "$ARTIFACT_NAME" \
    --arg package_source_ci_run_id "$CI_RUN_ID" --arg package_source_ci_attempt "$CI_ATTEMPT" \
    --argjson checks "$CHECKS" --argjson blockers "$BLOCKERS" --arg verdict "$verdict" \
    '{schema:1,phase:249,observed_at:$observed_at,repository:$repository,package:$package,version:$version,tag:$tag,
      current_main_sha:(if $current_main_sha=="" then null else $current_main_sha end),
      package_source_sha:(if $package_source_sha=="" then null else $package_source_sha end),
      release_run:(if $release_run_id=="" then null else {id:$release_run_id,attempt:($release_run_attempt|tonumber)} end),
      release_artifact:(if $artifact_id=="" then null else {id:$artifact_id,name:$artifact_name} end),
      package_source_ci:(if $package_source_ci_run_id=="" then null else {run_id:$package_source_ci_run_id,attempt:(if $package_source_ci_attempt=="" then null else ($package_source_ci_attempt|tonumber) end)} end),
      verdict:$verdict,checks:$checks,blockers:$blockers}' \
    > "$temp"
  jq -e . "$temp" >/dev/null
  mv -f "$temp" "$PREFLIGHT"
}
block_and_finish() {
  local id="$1" detail="${2-}"
  [[ -n "$detail" ]] || detail='{}'
  record_check "$id" blocked "$detail"
  record_blocker "$id"
  write_preflight
  echo "release-public-proof: BLOCKED: ${id}" >&2
  exit 1
}
api_json() {
  local endpoint="$1" destination="$2"
  gh api "$endpoint" > "$destination" 2>"$TMP/gh-error.log" && jq -e . "$destination" >/dev/null 2>&1
}
fetch_url() {
  local url="$1" destination="$2" meta
  meta="$(curl -fsSL --max-time 30 --output "$destination" --write-out $'%{http_code}\n%{url_effective}' "$url" 2>"$TMP/curl-error.log")" || return 1
  HTTP_STATUS="${meta%%$'\n'*}"
  HTTP_EFFECTIVE_URL="${meta#*$'\n'}"
  [[ "$HTTP_STATUS" =~ ^[0-9]{3}$ && -n "$HTTP_EFFECTIVE_URL" ]]
}

# Check auth and quota before any sequence of GitHub API reads. Never persist CLI output.
if ! gh auth status >/dev/null 2>&1; then
  block_and_finish github_authorization '{"available":false}'
fi
record_check github_authorization pass '{"available":true,"credential_material_recorded":false}'
if ! api_json rate_limit "$TMP/rate-limit.json"; then
  block_and_finish github_rate_limit '{"available":false}'
fi
CORE_REMAINING="$(jq -r '.resources.core.remaining // -1' "$TMP/rate-limit.json")"
if ! [[ "$CORE_REMAINING" =~ ^[0-9]+$ ]]; then
  block_and_finish github_rate_limit '{"available":false}'
fi
if (( CORE_REMAINING <= 250 )); then
  record_check github_rate_limit blocked "$(jq -cn --argjson remaining "$CORE_REMAINING" '{core_remaining:$remaining,stop_threshold:250}')"
  record_blocker github_rate_limit
  write_preflight
  echo "release-public-proof: BLOCKED: github_rate_limit" >&2
  exit 1
fi
record_check github_rate_limit pass "$(jq -cn --argjson remaining "$CORE_REMAINING" '{core_remaining:$remaining,stop_threshold:250}')"

# Current main and a clean checkout are separate observations; this command must run from
# the clean current-main source, not from a dirty maintainer workspace.
if ! api_json "repos/${REPOSITORY}/commits/main" "$TMP/main.json"; then
  block_and_finish current_main '{"available":false}'
fi
MAIN_SHA="$(jq -r '.sha // empty' "$TMP/main.json")"
[[ "$MAIN_SHA" =~ ^[0-9a-f]{40}$ ]] || block_and_finish current_main '{"sha_valid":false}'
record_check current_main pass "$(jq -cn --arg sha "$MAIN_SHA" --arg url "https://github.com/${REPOSITORY}/commit/${MAIN_SHA}" '{sha:$sha,url:$url}')"
WORKTREE_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
WORKTREE_STATUS="$(git status --porcelain=v1 -uall 2>/dev/null || true)"
if [[ "$WORKTREE_SHA" == "$MAIN_SHA" && -z "$WORKTREE_STATUS" ]]; then
  WORKTREE_CLEAN=true
  record_check current_source_checkout pass "$(jq -cn --arg sha "$WORKTREE_SHA" '{sha:$sha,clean:true}')"
else
  DIRTY_COUNT="$(printf '%s\n' "$WORKTREE_STATUS" | sed '/^$/d' | wc -l | tr -d ' ')"
  block_and_finish current_source_checkout "$(jq -cn --arg sha "$WORKTREE_SHA" --arg main "$MAIN_SHA" --argjson dirty "$DIRTY_COUNT" '{sha:$sha,expected_main_sha:$main,clean:false,dirty_path_count:$dirty}')"
fi

# Capture only the one current fixed-branch Release Please candidate; its identity is not
# allowed to replace the immutable package-source identity below.
if ! api_json "repos/${REPOSITORY}/pulls?state=open&base=main&per_page=100" "$TMP/pulls.json"; then
  block_and_finish current_release_candidate '{"available":false}'
fi
CANDIDATE_JSON="$(jq -c --arg repository "$REPOSITORY" '[.[] | select(.state=="open" and .base.ref=="main" and .head.ref=="release-please--branches--main" and ((.head.repo.full_name // $repository)==$repository)) | {number,head_sha:.head.sha,base_sha:.base.sha,url:.html_url}]' "$TMP/pulls.json")"
CANDIDATE_COUNT="$(jq 'length' <<<"$CANDIDATE_JSON")"
if (( CANDIDATE_COUNT > 1 )); then
  block_and_finish current_release_candidate '{"ambiguous":true}'
fi
if (( CANDIDATE_COUNT == 1 )); then
  CANDIDATE_HEAD="$(jq -r '.[0].head_sha // empty' <<<"$CANDIDATE_JSON")"
  [[ "$CANDIDATE_HEAD" =~ ^[0-9a-f]{40}$ ]] || block_and_finish current_release_candidate '{"head_sha_valid":false}'
fi
record_check current_release_candidate pass "$(jq -cn --argjson candidate "$(if (( CANDIDATE_COUNT == 0 )); then echo null; else jq -c '.[0]' <<<"$CANDIDATE_JSON"; fi)" '{candidate:$candidate}')"

# Resolve lightweight or annotated tags to a full commit without trusting local refs.
if ! api_json "repos/${REPOSITORY}/git/ref/tags/${TAG}" "$TMP/tag-ref.json"; then
  block_and_finish package_source_tag '{"available":false}'
fi
TAG_TYPE="$(jq -r '.object.type // empty' "$TMP/tag-ref.json")"
TAG_OBJECT_SHA="$(jq -r '.object.sha // empty' "$TMP/tag-ref.json")"
[[ "$TAG_OBJECT_SHA" =~ ^[0-9a-f]{40}$ ]] || block_and_finish package_source_tag '{"object_sha_valid":false}'
for _ in 1 2 3 4 5; do
  case "$TAG_TYPE" in
    commit) SOURCE_SHA="$TAG_OBJECT_SHA"; break ;;
    tag)
      if ! api_json "repos/${REPOSITORY}/git/tags/${TAG_OBJECT_SHA}" "$TMP/tag-object.json"; then
        block_and_finish package_source_tag '{"annotated_tag_resolution":"unavailable"}'
      fi
      TAG_TYPE="$(jq -r '.object.type // empty' "$TMP/tag-object.json")"
      TAG_OBJECT_SHA="$(jq -r '.object.sha // empty' "$TMP/tag-object.json")"
      [[ "$TAG_OBJECT_SHA" =~ ^[0-9a-f]{40}$ ]] || block_and_finish package_source_tag '{"object_sha_valid":false}'
      ;;
    *) block_and_finish package_source_tag '{"target_type":"unsupported"}' ;;
  esac
done
[[ -n "$SOURCE_SHA" ]] || block_and_finish package_source_tag '{"annotated_tag_resolution":"depth_exceeded"}'
record_check package_source_tag pass "$(jq -cn --arg tag "$TAG" --arg sha "$SOURCE_SHA" '{tag:$tag,object_type:"commit",commit_sha:$sha}')"

# Select the newest successful Release Please run for the tag's exact source SHA.
if ! api_json "repos/${REPOSITORY}/actions/runs?head_sha=${SOURCE_SHA}&per_page=100" "$TMP/release-runs.json"; then
  block_and_finish release_run '{"available":false}'
fi
RELEASE_RUN="$(jq -c --arg sha "$SOURCE_SHA" '[.workflow_runs[]? | select(.head_sha==$sha and .path==".github/workflows/release-please.yml" and .status=="completed" and .conclusion=="success" and (.event=="push" or .event=="workflow_dispatch"))] | sort_by(.run_started_at) | if length==0 then empty else last end' "$TMP/release-runs.json")"
[[ -n "$RELEASE_RUN" ]] || block_and_finish release_run '{"matching_success":false}'
RELEASE_RUN_ID="$(jq -r '.id|tostring' <<<"$RELEASE_RUN")"
RELEASE_ATTEMPT="$(jq -r '.run_attempt|tostring' <<<"$RELEASE_RUN")"
RELEASE_RUN_URL="$(jq -r '.html_url // empty' <<<"$RELEASE_RUN")"
[[ "$RELEASE_RUN_ID" =~ ^[1-9][0-9]*$ && "$RELEASE_ATTEMPT" =~ ^[1-9][0-9]*$ ]] || block_and_finish release_run '{"identity_valid":false}'
if ! api_json "repos/${REPOSITORY}/actions/runs/${RELEASE_RUN_ID}/attempts/${RELEASE_ATTEMPT}" "$TMP/release-attempt.json"; then
  block_and_finish release_run_attempt '{"available":false}'
fi
if ! jq -e --arg id "$RELEASE_RUN_ID" --argjson attempt "$RELEASE_ATTEMPT" --arg sha "$SOURCE_SHA" \
  '(.id|tostring)==$id and .run_attempt==$attempt and .head_sha==$sha and .path==".github/workflows/release-please.yml" and (.event=="push" or .event=="workflow_dispatch") and .status=="completed" and .conclusion=="success"' \
  "$TMP/release-attempt.json" >/dev/null 2>&1; then
  block_and_finish release_run_attempt '{"identity_match":false}'
fi
record_check release_run pass "$(jq -cn --arg id "$RELEASE_RUN_ID" --argjson attempt "$RELEASE_ATTEMPT" --arg sha "$SOURCE_SHA" --arg url "$RELEASE_RUN_URL" '{run_id:$id,attempt:$attempt,head_sha:$sha,url:$url}')"

if ! api_json "repos/${REPOSITORY}/actions/runs/${RELEASE_RUN_ID}/artifacts" "$TMP/artifacts.json"; then
  block_and_finish release_artifact '{"available":false}'
fi
ARTIFACT_NAME="release-result-${VERSION}-${RELEASE_RUN_ID}"
MATCHING_ARTIFACTS="$(jq -c --arg name "$ARTIFACT_NAME" '[.artifacts[]? | select(.name==$name and .expired==false)]' "$TMP/artifacts.json")"
if [[ "$(jq 'length' <<<"$MATCHING_ARTIFACTS")" -ne 1 ]]; then
  block_and_finish release_artifact '{"unique_unexpired_artifact":false}'
fi
ARTIFACT_ID="$(jq -r '.[0].id|tostring' <<<"$MATCHING_ARTIFACTS")"
ARTIFACT_URL="$(jq -r '.[0].archive_download_url // empty' <<<"$MATCHING_ARTIFACTS")"
[[ "$ARTIFACT_ID" =~ ^[1-9][0-9]*$ && "$ARTIFACT_URL" == "https://api.github.com/repos/${REPOSITORY}/actions/artifacts/${ARTIFACT_ID}/zip" ]] || \
  block_and_finish release_artifact '{"download_url_valid":false}'
if ! gh api "repos/${REPOSITORY}/actions/artifacts/${ARTIFACT_ID}/zip" > "$TMP/artifact.zip" 2>"$TMP/gh-error.log"; then
  block_and_finish release_artifact '{"downloadable":false}'
fi
ARTIFACT_MEMBERS="$(unzip -Z1 "$TMP/artifact.zip" 2>"$TMP/unzip-error.log" || true)"
if [[ "$ARTIFACT_MEMBERS" != "release-result.json" ]]; then
  block_and_finish release_artifact '{"expected_member_only":false}'
fi
if ! unzip -Z -v "$TMP/artifact.zip" 2>"$TMP/unzip-error.log" | awk '
  /Unix file attributes/ {
    saw_unix_mode = 1
    mode = $0
    sub(/^.*:[[:space:]]*/, "", mode)
    if (substr(mode, 1, 1) != "-") non_regular = 1
  }
  END { if (saw_unix_mode && non_regular) print "non-regular" }
' > "$TMP/archive-member-type.txt"; then
  block_and_finish release_artifact '{"archive_metadata_available":false}'
fi
if [[ -s "$TMP/archive-member-type.txt" ]]; then
  block_and_finish release_artifact '{"release_result_regular_file":false}'
fi
if ! unzip -p "$TMP/artifact.zip" release-result.json > "$TMP/release-result.json" 2>"$TMP/unzip-error.log" || \
  ! jq -e . "$TMP/release-result.json" >/dev/null 2>&1; then
  block_and_finish release_artifact '{"expected_json_member_valid":false}'
fi

if ! jq -e --arg id "$RELEASE_RUN_ID" --argjson attempt "$RELEASE_ATTEMPT" --arg version "$VERSION" --arg tag "$TAG" --arg sha "$SOURCE_SHA" \
  'type=="object" and .schema_version==1 and
   ([..|objects|keys[]?|select(test("(token|secret|credential|api.?key)";"i"))]|length)==0 and
   (.release_run_id|tostring)==$id and .release_run_attempt==$attempt and
   .workflow_name=="Release Please" and .release_run_url==("https://github.com/szTheory/sigra/actions/runs/"+$id) and
   (.source_event=="push" or .source_event=="workflow_dispatch") and
   .version==$version and .tag==$tag and .source_sha==$sha and
   .gate.verdict=="pass" and (.gate.run_id|tostring)==(.gate.ci_run_id|tostring) and
   (.gate.ci_run_id|tostring|test("^[1-9][0-9]*$")) and
   .gate.head_sha==$sha and (.gate.ci_run_url|type)=="string" and
   .publish.outcome=="published" and .terminal_verdict=="success" and .failure==null and
   (has("final_main_sha")|not) and (has("final_main_ci")|not)' "$TMP/release-result.json" >/dev/null 2>&1; then
  block_and_finish release_artifact_identity '{"identity_match":false,"credential_keys_absent":false}'
fi
RECEIPT_RELEASE_RUN_ID="$(jq -r '.release_run_id|tostring' "$TMP/release-result.json")"
RECEIPT_RELEASE_ATTEMPT="$(jq -r '.release_run_attempt' "$TMP/release-result.json")"
RECEIPT_RELEASE_URL="$(jq -r '.release_run_url' "$TMP/release-result.json")"
CI_RUN_ID="$(jq -r '.gate.ci_run_id' "$TMP/release-result.json")"
CI_RUN_URL="$(jq -r '.gate.ci_run_url' "$TMP/release-result.json")"
if [[ "$RECEIPT_RELEASE_RUN_ID" != "$RELEASE_RUN_ID" || "$RECEIPT_RELEASE_ATTEMPT" != "$RELEASE_ATTEMPT" || "$RECEIPT_RELEASE_URL" != "$RELEASE_RUN_URL" ]]; then
  block_and_finish release_artifact_identity '{"run_attempt_match":false}'
fi
record_check release_artifact pass "$(jq -cn --arg id "$ARTIFACT_ID" --arg name "$ARTIFACT_NAME" --arg url "$ARTIFACT_URL" --arg sha "$SOURCE_SHA" '{artifact_id:$id,name:$name,url:$url,source_sha:$sha,expected_member_only:true}')"

# The receipt names only the immutable package-source CI, never later-main CI.
if ! [[ "$CI_RUN_ID" =~ ^[1-9][0-9]*$ ]] || ! api_json "repos/${REPOSITORY}/actions/runs/${CI_RUN_ID}" "$TMP/source-ci-run.json"; then
  block_and_finish package_source_ci '{"available":false}'
fi
if ! jq -e --arg id "$CI_RUN_ID" --arg sha "$SOURCE_SHA" \
  '(.id|tostring)==$id and .head_sha==$sha and .path==".github/workflows/ci.yml" and
   .status=="completed" and .conclusion=="success" and
   (.run_attempt|type)=="number" and .run_attempt>=1' "$TMP/source-ci-run.json" >/dev/null 2>&1; then
  block_and_finish package_source_ci '{"exact_source_ci_run_identity":false}'
fi
CI_ATTEMPT="$(jq -r '.run_attempt // empty' "$TMP/source-ci-run.json")"
if ! [[ "$CI_ATTEMPT" =~ ^[1-9][0-9]*$ ]]; then
  block_and_finish package_source_ci '{"attempt_valid":false}'
fi
if ! api_json "repos/${REPOSITORY}/actions/runs/${CI_RUN_ID}/attempts/${CI_ATTEMPT}" "$TMP/source-ci-attempt.json"; then
  block_and_finish package_source_ci '{"attempt_available":false}'
fi
if ! jq -e --arg id "$CI_RUN_ID" --argjson attempt "$CI_ATTEMPT" --arg sha "$SOURCE_SHA" \
  '(.id|tostring)==$id and .run_attempt==$attempt and .head_sha==$sha and .path==".github/workflows/ci.yml" and .status=="completed" and .conclusion=="success"' "$TMP/source-ci-attempt.json" >/dev/null 2>&1; then
  block_and_finish package_source_ci '{"exact_source_ci_success":false}'
fi
CI_RUN_URL="$(jq -r '.html_url // empty' "$TMP/source-ci-attempt.json")"
if ! api_json "repos/${REPOSITORY}/actions/runs/${CI_RUN_ID}/attempts/${CI_ATTEMPT}/jobs" "$TMP/source-ci-jobs.json"; then
  block_and_finish package_source_ci '{"jobs_available":false}'
fi
CI_GATE_JOBS="$(jq -c --arg sha "$SOURCE_SHA" --argjson attempt "$CI_ATTEMPT" '[.jobs[]? | select(.name=="ci-gate" and .head_sha==$sha and .run_attempt==$attempt and .status=="completed" and .conclusion=="success")]' "$TMP/source-ci-jobs.json")"
if [[ "$(jq 'length' <<<"$CI_GATE_JOBS")" -ne 1 ]]; then
  block_and_finish package_source_ci '{"exact_head_ci_gate_success":false}'
fi
CI_GATE_JOB_ID="$(jq -r '.[0].id|tostring' <<<"$CI_GATE_JOBS")"
CI_GATE_URL="$(jq -r '.[0].html_url // empty' <<<"$CI_GATE_JOBS")"
record_check package_source_ci pass "$(jq -cn --arg id "$CI_RUN_ID" --argjson attempt "$CI_ATTEMPT" --arg sha "$SOURCE_SHA" --arg url "$CI_RUN_URL" --arg job "$CI_GATE_JOB_ID" --arg job_url "$CI_GATE_URL" '{run_id:$id,attempt:$attempt,head_sha:$sha,workflow:".github/workflows/ci.yml",conclusion:"success",ci_gate_job_id:$job,ci_gate_conclusion:"success",ci_gate_url:$job_url,url:$url}')"

if ! fetch_url "$HEX_API_URL" "$TMP/hex-release.json" || ! jq -e --arg version "$VERSION" \
  '.version==$version and (.checksum|type)=="string" and (.checksum|test("^[0-9a-f]{64}$")) and (.html_url|type)=="string"' \
  "$TMP/hex-release.json" >/dev/null 2>&1; then
  block_and_finish hex_release '{"exact_version_available":false}'
fi
HEX_CHECKSUM="$(jq -r '.checksum' "$TMP/hex-release.json")"
record_check hex_release pass "$(jq -cn --arg version "$VERSION" --arg url "$HEX_URL" --arg api "$HEX_API_URL" --arg checksum "$HEX_CHECKSUM" '{package:"sigra",version:$version,url:$url,api_url:$api,checksum:$checksum}')"

if ! fetch_url "$DOCS_URL" "$TMP/docs.html" || [[ "$HTTP_STATUS" != 200 ]]; then
  block_and_finish versioned_hexdocs '{"http_status":"unavailable"}'
fi
DOCS_EFFECTIVE_URL="$HTTP_EFFECTIVE_URL"
if ! [[ "$DOCS_EFFECTIVE_URL" =~ ^https://[A-Za-z0-9.-]*hexdocs\.pm/${VERSION}/ ]]; then
  block_and_finish versioned_hexdocs '{"versioned_destination":false}'
fi
record_check versioned_hexdocs pass "$(jq -cn --arg version "$VERSION" --arg requested "$DOCS_URL" --arg effective "$DOCS_EFFECTIVE_URL" --arg status "$HTTP_STATUS" '{version:$version,requested_url:$requested,effective_url:$effective,http_status:($status|tonumber)}')"

SOURCE_HREF="$(node -e '
  const fs=require("fs");
  const [repo,tag]=process.argv.slice(1);
  const html=fs.readFileSync(0,"utf8");
  const hrefs=[...html.matchAll(/\bhref\s*=\s*(["\x27])([^"\x27]*)\1/gi)].map(m=>m[2].replace(/&amp;/g,"&"));
  const prefix=`https://github.com/${repo.toLowerCase()}/blob/${tag}/`;
  const matches=hrefs.filter(href=>href.toLowerCase().startsWith(prefix));
  if(matches.length!==1) process.exit(1);
  try {
    const u=new URL(matches[0]);
    const encoded=u.pathname.slice(`/${repo.toLowerCase()}/blob/${tag}/`.length);
    const path=decodeURIComponent(encoded);
    if(u.protocol!=="https:" || u.hostname.toLowerCase()!=="github.com" || u.search || !path || path.split("/").some(part=>!part || part==="." || part==="..")) process.exit(1);
    if(!/^[A-Za-z0-9._/-]+$/.test(path)) process.exit(1);
    process.stdout.write(matches[0]);
  } catch { process.exit(1); }
' "${REPOSITORY}" "${TAG}" < "$TMP/docs.html" 2>/dev/null)" || block_and_finish rendered_source_reference '{"tagged_source_href":false}'
SOURCE_PATH="$(node -e 'const u=new URL(process.argv[1]);process.stdout.write(decodeURIComponent(u.pathname.split("/").slice(5).join("/")))' "$SOURCE_HREF" 2>/dev/null)"
[[ "$SOURCE_PATH" =~ ^[A-Za-z0-9._/-]+$ && "$SOURCE_PATH" != *..* && "$SOURCE_PATH" != /* ]] || \
  block_and_finish rendered_source_reference '{"source_path_valid":false}'
if ! fetch_url "$SOURCE_HREF" "$TMP/source-page.html" || [[ "$HTTP_STATUS" != 200 ]]; then
  block_and_finish rendered_source_reference '{"destination_http_status":"unavailable"}'
fi
SOURCE_EFFECTIVE_URL="$HTTP_EFFECTIVE_URL"
if ! node -e '
  const [requested, effective, repository, tag, commit, path] = process.argv.slice(1);
  const identity = raw => {
    const url = new URL(raw);
    if (url.protocol !== "https:" || url.hostname.toLowerCase() !== "github.com" || url.search) return null;
    const parts = url.pathname.split("/");
    if (parts.length < 6 || parts[0] !== "" || parts[3] !== "blob" || parts.slice(4).some(part => !part)) return null;
    const [, owner, repo, , ref, ...sourcePath] = parts;
    return `${owner.toLowerCase()}/${repo.toLowerCase()}/blob/${ref}/${sourcePath.join("/")}`;
  };
  const expectedRepository = repository.toLowerCase();
  const expectedRequested = `${expectedRepository}/blob/${tag}/${path}`;
  const expectedCommit = `${expectedRepository}/blob/${commit}/${path}`;
  const requestedIdentity = identity(requested);
  const effectiveIdentity = identity(effective);
  if (requestedIdentity !== expectedRequested || ![expectedRequested, expectedCommit].includes(effectiveIdentity)) process.exit(1);
' "$SOURCE_HREF" "$SOURCE_EFFECTIVE_URL" "$REPOSITORY" "$TAG" "$SOURCE_SHA" "$SOURCE_PATH" 2>/dev/null; then
  block_and_finish rendered_source_reference '{"resolved_page_destination_match":false}'
fi
if ! api_json "repos/${REPOSITORY}/contents/${SOURCE_PATH}?ref=${SOURCE_SHA}" "$TMP/source-content.json"; then
  block_and_finish rendered_source_reference '{"source_blob_available":false}'
fi
SOURCE_BLOB_SHA="$(jq -r '.sha // empty' "$TMP/source-content.json")"
SOURCE_CONTENT_PATH="$(jq -r '.path // empty' "$TMP/source-content.json")"
SOURCE_CONTENT_URL="$(jq -r '.html_url // empty' "$TMP/source-content.json")"
[[ "$SOURCE_BLOB_SHA" =~ ^[0-9a-f]{40}$ && "$SOURCE_CONTENT_PATH" == "$SOURCE_PATH" && "$SOURCE_CONTENT_URL" == "https://github.com/${REPOSITORY}/blob/${SOURCE_SHA}/${SOURCE_PATH}" ]] || \
  block_and_finish rendered_source_reference '{"resolved_destination_match":false}'
record_check rendered_source_reference pass "$(jq -cn --arg href "$SOURCE_HREF" --arg tag "$TAG" --arg sha "$SOURCE_SHA" --arg path "$SOURCE_PATH" --arg blob "$SOURCE_BLOB_SHA" '{href:$href,http_status:200,tag:$tag,resolved_commit_sha:$sha,path:$path,content_blob_sha:$blob}')"

# This is the first repository evidence artifact written by the verifier. A blocked
# result stops here and never produces a success receipt.
write_preflight
if [[ "$BLOCKERS" != '[]' ]]; then
  echo "release-public-proof: BLOCKED: preflight" >&2
  exit 1
fi

if [[ -e "$OUTPUT" ]] && ! jq -e --arg sha "$SOURCE_SHA" --arg version "$VERSION" --arg run "$RELEASE_RUN_ID" \
  '.package_source_sha==$sha and .version==$version and (.release_run.id|tostring)==$run' "$OUTPUT" >/dev/null 2>&1; then
  record_check existing_receipt_identity blocked '{"identity_match":false}'
  record_blocker existing_receipt_identity
  write_preflight
  echo "release-public-proof: BLOCKED: existing_receipt_identity" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$OUTPUT")"
RECEIPT_TEMP="${OUTPUT}.tmp.$$"
jq -n \
  --arg version "$VERSION" --arg tag "$TAG" --arg source_sha "$SOURCE_SHA" \
  --arg artifact_id "$ARTIFACT_ID" --arg artifact_name "$ARTIFACT_NAME" --arg artifact_url "$ARTIFACT_URL" \
  --arg release_run_id "$RELEASE_RUN_ID" --arg release_attempt "$RELEASE_ATTEMPT" --arg release_url "$RELEASE_RUN_URL" \
  --arg ci_run_id "$CI_RUN_ID" --arg ci_attempt "$CI_ATTEMPT" --arg ci_url "$CI_RUN_URL" --arg ci_head "$SOURCE_SHA" \
  --arg ci_gate_job_id "$CI_GATE_JOB_ID" --arg ci_gate_url "$CI_GATE_URL" \
  --arg hex_url "$HEX_URL" --arg hex_api_url "$HEX_API_URL" --arg checksum "$HEX_CHECKSUM" \
  --arg docs_url "$DOCS_EFFECTIVE_URL" --arg source_href "$SOURCE_HREF" --arg source_tag "$TAG" \
  --arg source_commit "$SOURCE_SHA" --arg source_path "$SOURCE_PATH" --arg blob_sha "$SOURCE_BLOB_SHA" --arg observed_at "$OBSERVED_AT" \
  '{schema:1,package:"sigra",version:$version,tag:$tag,package_source_sha:$source_sha,
    release_artifact:{id:$artifact_id,name:$artifact_name,url:$artifact_url},
    release_run:{id:$release_run_id,attempt:($release_attempt|tonumber),url:$release_url},
    package_source_ci:{run_id:$ci_run_id,attempt:($ci_attempt|tonumber),head_sha:$ci_head,url:$ci_url,
      workflow:".github/workflows/ci.yml",ci_gate_job_id:$ci_gate_job_id,ci_gate_conclusion:"success",ci_gate_url:$ci_gate_url},
    hex:{package_url:$hex_url,release_api_url:$hex_api_url,checksum:$checksum},
    versioned_docs_url:$docs_url,
    source_reference:{href:$source_href,resolved_tag:$source_tag,resolved_commit_sha:$source_commit,path:$source_path,content_blob_sha:$blob_sha},
    observed_at:$observed_at,verdict:"passed"}' > "$RECEIPT_TEMP"
if ! jq -e 'type=="object" and .schema==1 and .verdict=="passed" and
  ([..|objects|keys[]?|select(test("(token|secret|credential|api.?key)";"i"))]|length)==0 and
  (has("final_main_sha")|not) and (has("final_main_ci")|not) and
  (has("release_receipt_commit")|not)' "$RECEIPT_TEMP" >/dev/null 2>&1; then
  rm -f "$RECEIPT_TEMP"
  record_check receipt_projection blocked '{"allowlist_valid":false}'
  record_blocker receipt_projection
  write_preflight
  echo "release-public-proof: BLOCKED: receipt_projection" >&2
  exit 1
fi
mv -f "$RECEIPT_TEMP" "$OUTPUT"
echo "release-public-proof: PASS: ${VERSION} source ${SOURCE_SHA}"
