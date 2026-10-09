#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/scripts/ci/refresh-release-docs.sh"
BRANCH="release-please--branches--main"
REPOSITORY="szTheory/sigra"
REAL_GIT="$(command -v git)"
ORIGINAL_PATH="$PATH"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

TOTAL=0
FAILED=0

fail() { echo "refresh-release-docs.test: $*" >&2; return 1; }

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

new_fixture() {
  local label="$1"
  FIXTURE="$TEMP_ROOT/$label"
  mkdir -p "$FIXTURE/bin" "$FIXTURE/gh"
  export REAL_GIT_BIN="$REAL_GIT"
  export FAKE_GH_FIXTURES="$FIXTURE/gh"
  export FAKE_PR_FILE="$FIXTURE/gh/pull-requests.json"
  export FAKE_MAIN_SHA_FILE="$FIXTURE/gh/main-sha"
  export FAKE_CI_MODE=present
  export FAKE_GH_CALLS="$FIXTURE/gh/calls.log"
  export FAKE_GH_COUNTER="$FIXTURE/gh/pr-count"
  export FAKE_GIT_PUSH_LOG="$FIXTURE/gh/git-push.log"
  export PATH="$FIXTURE/bin:$ORIGINAL_PATH"

  cat > "$FIXTURE/bin/gh" <<'GH_MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_CALLS"
case "${1:-}" in
  api)
    if [[ -s "$FAKE_MAIN_SHA_FILE" ]]; then cat "$FAKE_MAIN_SHA_FILE"; else echo "${FAKE_MAIN_SHA:-}"; fi
    ;;
  pr)
    [[ "${2:-}" == "list" ]] || { echo "unexpected gh pr command: $*" >&2; exit 90; }
    count=0
    [[ -f "$FAKE_GH_COUNTER" ]] && count="$(cat "$FAKE_GH_COUNTER")"
    count=$((count + 1))
    echo "$count" > "$FAKE_GH_COUNTER"
    response="$FAKE_GH_FIXTURES/pull-requests-$count.json"
    [[ -f "$response" ]] || response="$FAKE_PR_FILE"
    cat "$response"
    ;;
  auth)
    [[ "${2:-}" == "setup-git" ]] || { echo "unexpected gh auth command: $*" >&2; exit 91; }
    ;;
  run)
    [[ "${2:-}" == "list" ]] || { echo "unexpected gh run command: $*" >&2; exit 92; }
    commit=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--commit" ]]; then commit="$2"; shift 2; else shift; fi
    done
    if [[ "${FAKE_CI_MODE:-present}" == "absent" ]]; then
      echo '[]'
    else
      jq -cn --arg sha "$commit" --arg branch "release-please--branches--main" \
        '[{databaseId:987654,workflowName:"CI",event:"push",headBranch:$branch,headSha:$sha,status:"queued",conclusion:null,url:"https://github.com/szTheory/sigra/actions/runs/987654"}]'
    fi
    ;;
  *) echo "unexpected gh command: $*" >&2; exit 93 ;;
esac
GH_MOCK

  cat > "$FIXTURE/bin/git" <<'GIT_MOCK'
#!/usr/bin/env bash
set -euo pipefail
is_push=false
repo=""
previous=""
for arg in "$@"; do
  [[ "$previous" == "-C" ]] && repo="$arg"
  [[ "$arg" == "push" ]] && is_push=true
  previous="$arg"
done
printf '%s\n' "$*" >> "$FAKE_GIT_PUSH_LOG"
set +e
"$REAL_GIT_BIN" "$@"
result=$?
set -e
if [[ "$is_push" == true && "$result" -eq 0 && -n "$repo" ]]; then
  new_sha="$("$REAL_GIT_BIN" -C "$repo" rev-parse HEAD)"
  tmp="$FAKE_PR_FILE.tmp"
  jq --arg sha "$new_sha" '.[0].headRefOid = $sha' "$FAKE_PR_FILE" > "$tmp"
  mv "$tmp" "$FAKE_PR_FILE"
fi
exit "$result"
GIT_MOCK
  chmod +x "$FIXTURE/bin/gh" "$FIXTURE/bin/git"

  export BARE_REPO="$FIXTURE/remote.git"
  export BUILD_REPO="$FIXTURE/build"
  export WRITER_REPO="$FIXTURE/writer"
  "$REAL_GIT" init --bare -q "$BARE_REPO"
  "$REAL_GIT" init -q "$BUILD_REPO"
  "$REAL_GIT" -C "$BUILD_REPO" config user.name "Sigra Test"
  "$REAL_GIT" -C "$BUILD_REPO" config user.email "sigra-test@example.invalid"
  mkdir -p "$BUILD_REPO/doc"
  printf 'old generated index\n' > "$BUILD_REPO/doc/llms.txt"
  printf 'source fixture\n' > "$BUILD_REPO/README.md"
  "$REAL_GIT" -C "$BUILD_REPO" add README.md doc/llms.txt
  "$REAL_GIT" -C "$BUILD_REPO" commit -qm 'chore(main): release 1.6.1'
  "$REAL_GIT" -C "$BUILD_REPO" branch -M "$BRANCH"
  "$REAL_GIT" -C "$BUILD_REPO" remote add origin "$BARE_REPO"
  "$REAL_GIT" -C "$BUILD_REPO" push -q origin "HEAD:refs/heads/$BRANCH"
  "$REAL_GIT" -C "$BUILD_REPO" push -q origin "HEAD:refs/heads/main"
  "$REAL_GIT" clone -q --branch "$BRANCH" "$BARE_REPO" "$WRITER_REPO"
  "$REAL_GIT" -C "$WRITER_REPO" remote set-url origin "https://github.com/$REPOSITORY.git"
  "$REAL_GIT" -C "$WRITER_REPO" remote set-url --push origin "$BARE_REPO"
  "$REAL_GIT" -C "$WRITER_REPO" config user.name "Sigra Test"
  "$REAL_GIT" -C "$WRITER_REPO" config user.email "sigra-test@example.invalid"

  TRUSTED_MAIN_SHA="$("$REAL_GIT" -C "$BUILD_REPO" rev-parse HEAD)"
  CANDIDATE_SHA="$TRUSTED_MAIN_SHA"
  printf '%s\n' "$TRUSTED_MAIN_SHA" > "$FAKE_MAIN_SHA_FILE"
  export FAKE_MAIN_SHA="$TRUSTED_MAIN_SHA"
  export TRUSTED_MAIN_SHA CANDIDATE_SHA
  jq -n --arg repo "$REPOSITORY" --arg branch "$BRANCH" --arg sha "$CANDIDATE_SHA" \
    '[{number:302,state:"OPEN",title:"chore(main): release 1.6.1",baseRefName:"main",headRefName:$branch,headRefOid:$sha,headRepository:{nameWithOwner:$repo},labels:[{name:"autorelease: pending"}],url:"https://github.com/szTheory/sigra/pull/302"}]' \
    > "$FAKE_PR_FILE"
}

cleanup_fixture() {
  rm -rf "$FIXTURE"
  PATH="$ORIGINAL_PATH"
  export PATH
}

run_test() {
  local name="$1"; shift
  TOTAL=$((TOTAL + 1))
  if "$@"; then
    printf 'ok %s - %s\n' "$TOTAL" "$name"
  else
    printf 'not ok %s - %s\n' "$TOTAL" "$name"
    FAILED=$((FAILED + 1))
  fi
}

test_capture_one_eligible_candidate() {
  new_fixture capture-eligible
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output"; then
    cleanup_fixture
    fail "eligible Release Please candidate capture should pass"
    return 1
  fi
  assert_eq "$CANDIDATE_SHA" "$(jq -r '.candidate.head_sha' "$identity")" "capture records the exact candidate head" || { cleanup_fixture; return 1; }
  assert_eq "302" "$(jq -r '.candidate.number' "$identity")" "capture records the PR number" || { cleanup_fixture; return 1; }
  assert_eq "$TRUSTED_MAIN_SHA" "$(jq -r '.trusted_main_sha' "$identity")" "capture binds the trusted main SHA" || { cleanup_fixture; return 1; }
  assert_eq "1" "$(grep -Fxc 'has_candidate=true' "$output")" "capture exposes the eligible candidate output" || { cleanup_fixture; return 1; }
  assert_eq "2" "$(cat "$FAKE_GH_COUNTER")" "capture re-reads the candidate identity" || { cleanup_fixture; return 1; }
  cleanup_fixture
}

test_no_candidate_is_explicit_noop() {
  new_fixture capture-empty
  printf '[]\n' > "$FAKE_PR_FILE"
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output"; then
    cleanup_fixture
    fail "an empty candidate query should be an explicit no-op"
    return 1
  fi
  assert_eq "null" "$(jq -r '.candidate' "$identity")" "no-candidate identity is explicit" || { cleanup_fixture; return 1; }
  assert_eq "1" "$(grep -Fxc 'has_candidate=false' "$output")" "no-candidate output is explicit" || { cleanup_fixture; return 1; }
  cleanup_fixture
}

test_generated_index_is_only_pushed_file_and_fresh_ci_is_recorded() {
  new_fixture writer-happy
  local identity="$FIXTURE/identity.json" github_output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  printf 'fresh generated index\nwith complete rows\n' > "$BUILD_REPO/doc/llms.txt"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$github_output"; then
    cleanup_fixture
    fail "eligible candidate capture should pass before docs packaging"
    return 1
  fi
  if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" --output-dir "$artifact"; then
    cleanup_fixture
    fail "the exact-head docs artifact should package"
    return 1
  fi
  if ! GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$github_output" \
      --summary-file "$FIXTURE/summary.md"; then
    cleanup_fixture
    fail "writer should update an unchanged eligible candidate and prove fresh CI"
    return 1
  fi
  assert_eq "doc/llms.txt" "$("$REAL_GIT" -C "$WRITER_REPO" show --pretty=format: --name-only HEAD | sed '/^$/d')" \
    "writer commit contains only the generated docs index" || { cleanup_fixture; return 1; }
  assert_eq "fresh generated index" "$(head -n 1 "$WRITER_REPO/doc/llms.txt")" "writer installs generated output" || { cleanup_fixture; return 1; }
  assert_eq "refreshed" "$(grep -F 'status=refreshed' "$github_output" | cut -d= -f2)" "writer reports a refresh" || { cleanup_fixture; return 1; }
  assert_eq "987654" "$(grep -F 'fresh_ci_run_id=' "$github_output" | cut -d= -f2)" "writer records the exact fresh CI run" || { cleanup_fixture; return 1; }
  if grep -E -- '(^|[[:space:]])(--force|-f)([[:space:]]|$)' "$FAKE_GIT_PUSH_LOG" >/dev/null; then
    cleanup_fixture
    fail "writer must use a non-force push"
    return 1
  fi
  grep -F 'https://github.com/szTheory/sigra/actions/runs/987654' "$FIXTURE/summary.md" >/dev/null || {
    cleanup_fixture
    fail "writer summary must retain a link to ordinary CI"
    return 1
  }
  cleanup_fixture
}

printf 'TAP version 13\n'
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "capture" ]]; then
  run_test 'captures one eligible fixed Release Please candidate at a stable full SHA' test_capture_one_eligible_candidate
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "no-candidate" ]]; then
  run_test 'reports no candidate as an explicit no-op' test_no_candidate_is_explicit_noop
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "writer" ]]; then
  run_test 'writes only doc/llms.txt and records ordinary CI for the new head' test_generated_index_is_only_pushed_file_and_fresh_ci_is_recorded
fi
printf '1..%s\n' "$TOTAL"
printf '# tests %s\n# pass %s\n# fail %s\n' "$TOTAL" "$((TOTAL - FAILED))" "$FAILED"
[[ "$FAILED" -eq 0 ]]
