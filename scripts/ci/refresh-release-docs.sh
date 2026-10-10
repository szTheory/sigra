#!/usr/bin/env bash
# Refresh the generated docs index on the one fixed Release Please candidate.
# Candidate code runs in a separate unprivileged job; this helper treats its
# artifact as data and scopes the release credential to the final push path.
set -euo pipefail

readonly RELEASE_BRANCH="release-please--branches--main"
readonly INDEX_PATH="doc/llms.txt"
readonly MAX_INDEX_BYTES=5000000
readonly EXPECTED_ARTIFACT_ENTRIES=$'./candidate.json\n./doc\n./doc/llms.txt'

fail() {
  echo "refresh-release-docs: FAIL: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
usage:
  refresh-release-docs.sh capture --repository OWNER/NAME --expected-main-sha SHA --identity-file FILE --github-output FILE
  refresh-release-docs.sh package --candidate-dir DIR --identity-file FILE --output-dir DIR
  refresh-release-docs.sh write --repository OWNER/NAME --repo-dir DIR --artifact-dir DIR --identity-file FILE --github-output FILE --summary-file FILE
USAGE
}

valid_sha() {
  [[ "${1:-}" =~ ^[0-9a-f]{40}$ ]]
}

parse_options() {
  local command_name="$1"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repository) REPOSITORY="${2:-}"; shift 2 ;;
      --expected-main-sha) EXPECTED_MAIN_SHA="${2:-}"; shift 2 ;;
      --identity-file) IDENTITY_FILE="${2:-}"; shift 2 ;;
      --github-output) GITHUB_OUTPUT_FILE="${2:-}"; shift 2 ;;
      --candidate-dir) CANDIDATE_DIR="${2:-}"; shift 2 ;;
      --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
      --repo-dir) REPO_DIR="${2:-}"; shift 2 ;;
      --artifact-dir) ARTIFACT_DIR="${2:-}"; shift 2 ;;
      --summary-file) SUMMARY_FILE="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown ${command_name} argument: $1" ;;
    esac
  done
}

require_file_path() {
  local name="$1" value="$2"
  [[ -n "$value" ]] || fail "$name is required"
}

main_sha() {
  local sha
  sha="$(gh api "repos/$REPOSITORY/git/ref/heads/main" --jq '.object.sha')" \
    || fail "could not read trusted main SHA"
  valid_sha "$sha" || fail "trusted main returned a malformed SHA"
  printf '%s\n' "$sha"
}

read_candidate() {
  local output_file="$1"
  local raw_file="$2"
  gh pr list --repo "$REPOSITORY" --state open --base main \
    --head "$RELEASE_BRANCH" \
    --json number,state,title,baseRefName,headRefName,headRefOid,headRepository,labels,url \
    > "$raw_file" || fail "could not read the fixed Release Please candidate"

  jq -e 'type == "array" and length <= 1' "$raw_file" >/dev/null 2>&1 \
    || fail "candidate query must return zero or one open PR"
  local count
  count="$(jq 'length' "$raw_file")"
  if [[ "$count" == "0" ]]; then
    printf '{"candidate":null}\n' > "$output_file"
    return 0
  fi

  jq -e --arg repository "$REPOSITORY" --arg branch "$RELEASE_BRANCH" '
    .[0] as $pr |
    ($pr.number | type == "number")
    and $pr.state == "OPEN"
    and $pr.baseRefName == "main"
    and $pr.headRefName == $branch
    and ($pr.headRefOid | type == "string" and test("^[0-9a-f]{40}$"))
    and ($pr.title | type == "string" and test("^chore\\(main\\): release [0-9]+\\.[0-9]+\\.[0-9]+$"))
    and $pr.headRepository.nameWithOwner == $repository
    and ($pr.labels | type == "array" and any(.[]; .name == "autorelease: pending"))
    and ($pr.url | type == "string" and startswith("https://github.com/" + $repository + "/pull/"))
  ' "$raw_file" >/dev/null 2>&1 || fail "open PR identity is not the eligible same-repository Release Please candidate"

  jq -c '{candidate:{
    number:.[0].number,
    state:.[0].state,
    title:.[0].title,
    base_ref_name:.[0].baseRefName,
    head_ref_name:.[0].headRefName,
    head_sha:.[0].headRefOid,
    head_repository:.[0].headRepository.nameWithOwner,
    labels:([.[0].labels[].name] | sort),
    url:.[0].url
  }}' "$raw_file" > "$output_file"
}

validate_identity() {
  local identity_file="$1"
  [[ -f "$identity_file" && ! -L "$identity_file" ]] || fail "candidate identity file is missing or unsafe"
  jq -e --arg repository "$REPOSITORY" --arg branch "$RELEASE_BRANCH" '
    type == "object"
    and .schema_version == 1
    and .repository == $repository
    and (.trusted_main_sha | type == "string" and test("^[0-9a-f]{40}$"))
    and (.candidate == null or (
      (.candidate.number | type == "number")
      and .candidate.state == "OPEN"
      and (.candidate.title | test("^chore\\(main\\): release [0-9]+\\.[0-9]+\\.[0-9]+$"))
      and .candidate.base_ref_name == "main"
      and .candidate.head_ref_name == $branch
      and (.candidate.head_sha | type == "string" and test("^[0-9a-f]{40}$"))
      and .candidate.head_repository == $repository
      and (.candidate.labels | type == "array" and any(.[]; . == "autorelease: pending"))
      and (.candidate.url | type == "string" and startswith("https://github.com/" + $repository + "/pull/"))
    ))
  ' "$identity_file" >/dev/null 2>&1 || fail "candidate identity is malformed or ineligible"
}

same_json() {
  jq -cS . "$1" > "$2"
}

validate_index_file() {
  local file="$1" size
  [[ -f "$file" && ! -L "$file" && -s "$file" ]] \
    || fail "generated doc/llms.txt must be a non-empty regular file"
  size="$(wc -c < "$file" | tr -d '[:space:]')"
  [[ "$size" =~ ^[0-9]+$ ]] || fail "generated docs index size is malformed"
  (( size <= MAX_INDEX_BYTES )) \
    || fail "generated docs index exceeds the ${MAX_INDEX_BYTES}-byte artifact limit"
  iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1 \
    || fail "generated docs index must contain valid UTF-8 text"
}

capture() {
  parse_options capture "$@"
  require_file_path repository "$REPOSITORY"
  require_file_path expected-main-sha "$EXPECTED_MAIN_SHA"
  require_file_path identity-file "$IDENTITY_FILE"
  require_file_path github-output "$GITHUB_OUTPUT_FILE"
  valid_sha "$EXPECTED_MAIN_SHA" || fail "expected main SHA is malformed"
  [[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "repository is malformed"

  local temp_dir main_before main_after identity_json
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  main_before="$(main_sha)"
  [[ "$main_before" == "$EXPECTED_MAIN_SHA" ]] || fail "workflow SHA is not the current trusted main SHA"
  read_candidate "$temp_dir/first.json" "$temp_dir/first-raw.json"

  if [[ "$(jq -r '.candidate == null' "$temp_dir/first.json")" == "true" ]]; then
    main_after="$(main_sha)"
    [[ "$main_after" == "$main_before" ]] || fail "trusted main changed during the no-candidate read"
    jq -cn --arg repository "$REPOSITORY" --arg main "$main_before" \
      '{schema_version:1,repository:$repository,trusted_main_sha:$main,candidate:null}' > "$IDENTITY_FILE"
    {
      echo 'has_candidate=false'
      echo 'candidate_number='
      echo 'candidate_head_sha='
      echo "trusted_main_sha=$main_before"
      echo 'candidate_identity='
    } >> "$GITHUB_OUTPUT_FILE"
    echo "refresh-release-docs: no eligible Release Please candidate; explicit no-op"
    return 0
  fi

  read_candidate "$temp_dir/second.json" "$temp_dir/second-raw.json"
  same_json "$temp_dir/first.json" "$temp_dir/first.sorted.json"
  same_json "$temp_dir/second.json" "$temp_dir/second.sorted.json"
  cmp -s "$temp_dir/first.sorted.json" "$temp_dir/second.sorted.json" \
    || fail "candidate identity changed during the two-read selection"
  main_after="$(main_sha)"
  [[ "$main_after" == "$main_before" ]] || fail "trusted main changed during candidate selection"

  jq -c --arg repository "$REPOSITORY" --arg main "$main_before" \
    '{schema_version:1,repository:$repository,trusted_main_sha:$main,candidate:.candidate}' \
    "$temp_dir/first.json" > "$IDENTITY_FILE.tmp"
  mv "$IDENTITY_FILE.tmp" "$IDENTITY_FILE"
  validate_identity "$IDENTITY_FILE"
  identity_json="$(jq -c . "$IDENTITY_FILE")"
  {
    echo 'has_candidate=true'
    echo "candidate_number=$(jq -r '.candidate.number' "$IDENTITY_FILE")"
    echo "candidate_head_sha=$(jq -r '.candidate.head_sha' "$IDENTITY_FILE")"
    echo "trusted_main_sha=$main_before"
    echo "candidate_identity=$identity_json"
  } >> "$GITHUB_OUTPUT_FILE"
  echo "refresh-release-docs: selected PR #$(jq -r '.candidate.number' "$IDENTITY_FILE") at $(jq -r '.candidate.head_sha' "$IDENTITY_FILE")"
}

package_artifact() {
  parse_options package "$@"
  require_file_path candidate-dir "$CANDIDATE_DIR"
  require_file_path identity-file "$IDENTITY_FILE"
  require_file_path output-dir "$OUTPUT_DIR"
  REPOSITORY="$(jq -r '.repository // empty' "$IDENTITY_FILE" 2>/dev/null || true)"
  [[ -n "$REPOSITORY" ]] || fail "candidate identity has no repository"
  validate_identity "$IDENTITY_FILE"
  [[ "$(jq -r '.candidate == null' "$IDENTITY_FILE")" == "false" ]] || fail "cannot package without a candidate"

  local expected_sha status_line path actual_root
  expected_sha="$(jq -r '.candidate.head_sha' "$IDENTITY_FILE")"
  valid_sha "$expected_sha" || fail "candidate head SHA is malformed"
  [[ -d "$CANDIDATE_DIR" && ! -L "$CANDIDATE_DIR" ]] || fail "candidate checkout is missing or unsafe"
  actual_root="$(git -C "$CANDIDATE_DIR" rev-parse --show-toplevel)" \
    || fail "candidate checkout is not a Git repository"
  [[ "$(git -C "$actual_root" rev-parse HEAD)" == "$expected_sha" ]] \
    || fail "docs were not built from the recorded candidate SHA"
  validate_index_file "$actual_root/$INDEX_PATH"
  status_line="$(git -C "$actual_root" status --porcelain --untracked-files=all)"
  while IFS= read -r status_line; do
    [[ -z "$status_line" ]] && continue
    path="${status_line:3}"
    [[ "$path" == "$INDEX_PATH" ]] || fail "docs build changed an unexpected candidate path: $path"
  done <<< "$(git -C "$actual_root" status --porcelain --untracked-files=all)"
  [[ ! -L "$OUTPUT_DIR" ]] || fail "artifact output directory cannot be a symlink"
  if [[ -e "$OUTPUT_DIR" ]]; then
    [[ -d "$OUTPUT_DIR" ]] || fail "artifact output path is not a directory"
    [[ -z "$(find "$OUTPUT_DIR" -mindepth 1 -print -quit)" ]] || fail "artifact output directory must be empty"
  else
    mkdir -p "$OUTPUT_DIR"
  fi
  mkdir -p "$OUTPUT_DIR/doc"
  cp "$actual_root/$INDEX_PATH" "$OUTPUT_DIR/$INDEX_PATH"
  jq -cS . "$IDENTITY_FILE" > "$OUTPUT_DIR/candidate.json"
  [[ -f "$OUTPUT_DIR/$INDEX_PATH" && ! -L "$OUTPUT_DIR/$INDEX_PATH" ]] || fail "artifact index is not a regular file"
  echo "refresh-release-docs: packaged only $INDEX_PATH and candidate identity"
}

candidate_from_query() {
  local tmp="$1"
  mkdir -p "$tmp"
  read_candidate "$tmp/normalized.json" "$tmp/raw.json"
  [[ "$(jq -r '.candidate == null' "$tmp/normalized.json")" == "false" ]] \
    || fail "Release Please candidate disappeared before the write"
  jq -cS . "$tmp/normalized.json"
}

run_rows() {
  local sha="$1" output_file="$2"
  gh run list --repo "$REPOSITORY" --workflow CI --branch "$RELEASE_BRANCH" \
    --commit "$sha" --limit 20 \
    --json databaseId,workflowName,event,headBranch,headSha,status,conclusion,url \
    > "$output_file" || fail "could not query ordinary CI for the refreshed head"
  jq -e 'type == "array"' "$output_file" >/dev/null 2>&1 || fail "ordinary CI query returned malformed JSON"
  jq -c --arg sha "$sha" --arg branch "$RELEASE_BRANCH" '
    [.[] | select(.workflowName == "CI" and .event == "push" and .headBranch == $branch
      and .headSha == $sha and (.databaseId | type == "number")
      and (.url | type == "string" and startswith("https://github.com/")))]
  ' "$output_file"
}

write_candidate() {
  parse_options write "$@"
  require_file_path repository "$REPOSITORY"
  require_file_path repo-dir "$REPO_DIR"
  require_file_path artifact-dir "$ARTIFACT_DIR"
  require_file_path identity-file "$IDENTITY_FILE"
  require_file_path github-output "$GITHUB_OUTPUT_FILE"
  require_file_path summary-file "$SUMMARY_FILE"
  [[ -n "${GH_TOKEN:-}" ]] || fail "event-capable release credential is unavailable to the writer"
  [[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "repository is malformed"
  validate_identity "$IDENTITY_FILE"
  [[ "$(jq -r '.repository' "$IDENTITY_FILE")" == "$REPOSITORY" ]] || fail "identity repository differs from writer target"
  [[ "$(jq -r '.candidate == null' "$IDENTITY_FILE")" == "false" ]] || fail "writer received no candidate"

  local actual_entries artifact_identity expected_identity candidate_sha main_before
  [[ -d "$ARTIFACT_DIR" && ! -L "$ARTIFACT_DIR" ]] || fail "downloaded docs artifact is missing or unsafe"
  actual_entries="$(cd "$ARTIFACT_DIR" && find . -mindepth 1 -maxdepth 2 -print | LC_ALL=C sort)"
  [[ "$actual_entries" == "$EXPECTED_ARTIFACT_ENTRIES" ]] \
    || fail "artifact must contain only candidate.json and regular doc/llms.txt"
  [[ ! -L "$ARTIFACT_DIR/candidate.json" && -f "$ARTIFACT_DIR/candidate.json" ]] \
    || fail "artifact candidate identity must be a regular file"
  [[ ! -L "$ARTIFACT_DIR/doc" && -d "$ARTIFACT_DIR/doc" ]] \
    || fail "artifact doc directory must be a regular directory"
  validate_index_file "$ARTIFACT_DIR/$INDEX_PATH"
  artifact_identity="$(jq -cS . "$ARTIFACT_DIR/candidate.json")" || fail "artifact identity is not valid JSON"
  expected_identity="$(jq -cS . "$IDENTITY_FILE")"
  [[ "$artifact_identity" == "$expected_identity" ]] || fail "artifact identity differs from the selected candidate"
  candidate_sha="$(jq -r '.candidate.head_sha' "$IDENTITY_FILE")"
  main_before="$(jq -r '.trusted_main_sha' "$IDENTITY_FILE")"

  [[ -d "$REPO_DIR" && ! -L "$REPO_DIR" ]] || fail "writer checkout is missing or unsafe"
  REPO_DIR="$(cd "$REPO_DIR" && pwd -P)"
  local git_root origin_url current_sha expected_candidate tmp_dir normalized pushed_sha ci_rows ci_run_id ci_url
  git_root="$(git -C "$REPO_DIR" rev-parse --show-toplevel)" || fail "writer checkout is not a Git repository"
  [[ "$git_root" == "$REPO_DIR" ]] || fail "writer checkout path is not the repository root"
  origin_url="$(git -C "$REPO_DIR" remote get-url origin)" || fail "writer checkout has no origin remote"
  case "$origin_url" in
    "https://github.com/$REPOSITORY"|"https://github.com/$REPOSITORY.git"|"git@github.com:$REPOSITORY"|"git@github.com:$REPOSITORY.git"|"ssh://git@github.com/$REPOSITORY"|"ssh://git@github.com/$REPOSITORY.git") ;;
    *) fail "writer origin does not identify the configured GitHub repository" ;;
  esac
  current_sha="$(git -C "$REPO_DIR" rev-parse HEAD)"
  [[ "$current_sha" == "$candidate_sha" ]] || fail "writer checkout does not start at the selected candidate head"
  [[ -z "$(git -C "$REPO_DIR" status --porcelain --untracked-files=all)" ]] \
    || fail "writer checkout must be clean before applying the artifact"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  [[ "$(main_sha)" == "$main_before" ]] || fail "trusted main changed after candidate selection"
  expected_candidate="$(jq -cS '{candidate:.candidate}' "$IDENTITY_FILE")"
  normalized="$(candidate_from_query "$tmp_dir/first-read")"
  [[ "$normalized" == "$expected_candidate" ]] || fail "candidate identity or head changed before write"

  [[ -d "$REPO_DIR/doc" && ! -L "$REPO_DIR/doc" ]] \
    || fail "candidate doc directory must be a regular directory"
  [[ -f "$REPO_DIR/$INDEX_PATH" && ! -L "$REPO_DIR/$INDEX_PATH" ]] \
    || fail "candidate doc/llms.txt destination must be a regular file"
  cp "$ARTIFACT_DIR/$INDEX_PATH" "$REPO_DIR/$INDEX_PATH"
  git -C "$REPO_DIR" add -- "$INDEX_PATH"
  if git -C "$REPO_DIR" diff --cached --quiet; then
    {
      echo 'status=unchanged'
      echo "head_sha=$candidate_sha"
      echo 'fresh_ci_run_id='
      echo 'fresh_ci_url='
    } >> "$GITHUB_OUTPUT_FILE"
    printf '# Release candidate docs refresh\n\nThe generated index already matches candidate %s; no commit was created.\n' \
      "$candidate_sha" >> "$SUMMARY_FILE"
    echo "refresh-release-docs: generated index already matches; explicit no-op"
    return 0
  fi
  local changed_paths
  changed_paths="$(git -C "$REPO_DIR" diff --cached --name-only --diff-filter=ACDMRTUXB)"
  [[ "$changed_paths" == "$INDEX_PATH" ]] || fail "planned writer diff must contain only $INDEX_PATH"
  git -C "$REPO_DIR" diff --cached --check || fail "generated index contains whitespace errors"
  git -C "$REPO_DIR" config user.name "github-actions[bot]"
  git -C "$REPO_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git -C "$REPO_DIR" commit -m 'docs: refresh generated release index'
  [[ "$(git -C "$REPO_DIR" rev-parse HEAD^)" == "$candidate_sha" ]] \
    || fail "writer commit is not a direct child of the selected candidate SHA"

  [[ "$(main_sha)" == "$main_before" ]] || fail "trusted main changed before candidate push"
  normalized="$(candidate_from_query "$tmp_dir/pre-push-read")"
  [[ "$normalized" == "$expected_candidate" ]] || fail "candidate identity or head changed immediately before push"
  gh auth setup-git --hostname github.com || fail "could not configure the event-capable release credential for Git"
  git -C "$REPO_DIR" push --porcelain origin "HEAD:refs/heads/$RELEASE_BRANCH" \
    || fail "non-force candidate push failed; candidate may have advanced"

  pushed_sha="$(git -C "$REPO_DIR" rev-parse HEAD)"
  valid_sha "$pushed_sha" || fail "writer produced a malformed commit SHA"
  [[ "$(main_sha)" == "$main_before" ]] || fail "trusted main changed during candidate push"
  expected_candidate="$(jq -cS --arg sha "$pushed_sha" '{candidate:(.candidate | .head_sha = $sha)}' "$IDENTITY_FILE")"
  local post_push_match=false post_push_attempt=0 last_candidate_sha=""
  for post_push_attempt in 1 2 3 4 5 6; do
    normalized="$(candidate_from_query "$tmp_dir/post-push-read-$post_push_attempt")"
    last_candidate_sha="$(jq -r '.candidate.head_sha' <<<"$normalized")"
    if [[ "$normalized" == "$expected_candidate" ]]; then
      post_push_match=true
      break
    fi
    (( post_push_attempt == 6 )) || sleep 2
  done
  [[ "$post_push_match" == true ]] \
    || fail "post-push candidate head remained ${last_candidate_sha}; expected writer SHA ${pushed_sha} after ${post_push_attempt} reads"

  run_rows "$pushed_sha" "$tmp_dir/ci-runs-first.json" > "$tmp_dir/ci-matches-first.json"
  ci_rows="$(cat "$tmp_dir/ci-matches-first.json")"
  if [[ "$(jq 'length' <<< "$ci_rows")" == "0" ]]; then
    sleep 10
    run_rows "$pushed_sha" "$tmp_dir/ci-runs-second.json" > "$tmp_dir/ci-matches-second.json"
    ci_rows="$(cat "$tmp_dir/ci-matches-second.json")"
  fi
  [[ "$(jq 'length' <<< "$ci_rows")" == "1" ]] \
    || fail "ordinary CI push run for the exact refreshed SHA was not registered after one recheck"
  ci_run_id="$(jq -r '.[0].databaseId' <<< "$ci_rows")"
  ci_url="$(jq -r '.[0].url' <<< "$ci_rows")"
  {
    echo 'status=refreshed'
    echo "head_sha=$pushed_sha"
    echo "fresh_ci_run_id=$ci_run_id"
    echo "fresh_ci_url=$ci_url"
  } >> "$GITHUB_OUTPUT_FILE"
  {
    echo '# Release candidate docs refresh'
    echo
    printf 'Updated only %s on PR #%s.\n' "$INDEX_PATH" "$(jq -r '.candidate.number' "$IDENTITY_FILE")"
    echo
    printf -- '- Previous head: %s\n' "$candidate_sha"
    printf -- '- Refreshed head: %s\n' "$pushed_sha"
    printf -- '- Ordinary CI: [%s](%s)\n' "$ci_run_id" "$ci_url"
    echo '- Merge remains governed by the existing exact-head CI guard.'
  } >> "$SUMMARY_FILE"
  echo "refresh-release-docs: pushed $pushed_sha; ordinary CI run $ci_run_id is registered"
}

[[ $# -gt 0 ]] || { usage >&2; exit 2; }
command_name="$1"
shift
case "$command_name" in
  capture) capture "$@" ;;
  package) package_artifact "$@" ;;
  write) write_candidate "$@" ;;
  -h|--help) usage ;;
  *) usage >&2; fail "unknown command: $command_name" ;;
esac
