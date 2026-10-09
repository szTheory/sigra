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
  export FAKE_BRANCH="release-please--branches--main"
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
if [[ "$is_push" == true && "${FAKE_PUSH_RACE:-false}" == true && -n "$repo" ]]; then
  push_url="$("$REAL_GIT_BIN" -C "$repo" remote get-url --push origin)"
  racer="$(dirname "$repo")/concurrent-writer"
  "$REAL_GIT_BIN" clone -q --branch "$FAKE_BRANCH" "$push_url" "$racer"
  "$REAL_GIT_BIN" -C "$racer" config user.name "Concurrent Test"
  "$REAL_GIT_BIN" -C "$racer" config user.email "concurrent@example.invalid"
  printf 'advanced by a concurrent writer\n' > "$racer/concurrent.txt"
  "$REAL_GIT_BIN" -C "$racer" add concurrent.txt
  "$REAL_GIT_BIN" -C "$racer" commit -qm 'advance candidate during push'
  "$REAL_GIT_BIN" -C "$racer" push -q origin "HEAD:refs/heads/$FAKE_BRANCH"
  raced_sha="$("$REAL_GIT_BIN" -C "$racer" rev-parse HEAD)"
  tmp="$FAKE_PR_FILE.tmp"
  jq --arg sha "$raced_sha" '.[0].headRefOid = $sha' "$FAKE_PR_FILE" > "$tmp"
  mv "$tmp" "$FAKE_PR_FILE"
  export FAKE_PUSH_RACE=false
fi
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
  cat > "$FIXTURE/bin/sleep" <<'SLEEP_MOCK'
#!/usr/bin/env bash
exit 0
SLEEP_MOCK
  chmod +x "$FIXTURE/bin/gh" "$FIXTURE/bin/git" "$FIXTURE/bin/sleep"

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

test_capture_rejects_candidate_advanced_between_reads() {
  new_fixture capture-race
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt"
  jq --arg sha 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' '.[0].headRefOid = $sha' "$FAKE_PR_FILE" \
    > "$FAKE_GH_FIXTURES/pull-requests-2.json"
  if bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null 2>&1; then
    cleanup_fixture
    fail "capture must reject a candidate that advances between its identity reads"
    return 1
  fi
  [[ ! -e "$identity" ]] || { cleanup_fixture; fail "unstable candidate identity must not be emitted"; return 1; }
  cleanup_fixture
}

test_package_rejects_candidate_checkout_or_extra_build_drift() {
  new_fixture package-drift
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before package drift checks"
    return 1
  fi
  printf 'generated index\n' > "$BUILD_REPO/doc/llms.txt"
  printf 'unexpected build output\n' >> "$BUILD_REPO/README.md"
  if bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null 2>&1; then
    cleanup_fixture
    fail "docs package must reject build changes outside doc/llms.txt"
    return 1
  fi
  printf 'expected source sha changed\n' > "$BUILD_REPO/extra.txt"
  "$REAL_GIT" -C "$BUILD_REPO" add extra.txt
  "$REAL_GIT" -C "$BUILD_REPO" commit -qm 'advance candidate checkout'
  if bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null 2>&1; then
    cleanup_fixture
    fail "docs package must reject a checkout whose HEAD differs from the selected SHA"
    return 1
  fi
  cleanup_fixture
}

test_writer_rejects_candidate_change_immediately_before_push() {
  new_fixture writer-pr-race
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before write-race check"
    return 1
  fi
  printf 'fresh generated index\n' > "$BUILD_REPO/doc/llms.txt"
  if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null; then
    cleanup_fixture
    fail "candidate artifact should package before write-race check"
    return 1
  fi
  jq --arg sha 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' '.[0].headRefOid = $sha' "$FAKE_PR_FILE" \
    > "$FAKE_GH_FIXTURES/pull-requests-4.json"
  if GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
      --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
    cleanup_fixture
    fail "writer must reject a candidate whose head changes immediately before push"
    return 1
  fi
  if grep -E '(^|[[:space:]])push([[:space:]]|$)' "$FAKE_GIT_PUSH_LOG" >/dev/null; then
    cleanup_fixture
    fail "changed candidate must not reach git push"
    return 1
  fi
  cleanup_fixture
}

test_writer_rejects_symlinked_artifact_and_missing_credential() {
  new_fixture writer-artifact
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before artifact checks"
    return 1
  fi
  printf 'fresh generated index\n' > "$BUILD_REPO/doc/llms.txt"
  if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null; then
    cleanup_fixture
    fail "candidate artifact should package before artifact checks"
    return 1
  fi
  printf 'outside artifact data\n' > "$FIXTURE/outside.txt"
  rm "$artifact/doc/llms.txt"
  ln -s "$FIXTURE/outside.txt" "$artifact/doc/llms.txt"
  if GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
      --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
    cleanup_fixture
    fail "writer must reject a symlinked generated artifact"
    return 1
  fi
  rm "$artifact/doc/llms.txt"
  cp "$FIXTURE/outside.txt" "$artifact/doc/llms.txt"
  if env -u GH_TOKEN bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
      --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
    cleanup_fixture
    fail "writer must reject a missing event-capable credential"
    return 1
  fi
  if grep -E '(^|[[:space:]])push([[:space:]]|$)' "$FAKE_GIT_PUSH_LOG" >/dev/null; then
    cleanup_fixture
    fail "invalid artifact or missing credential must not reach git push"
    return 1
  fi
  cleanup_fixture
}

test_non_fast_forward_race_is_rejected_without_overwriting_candidate() {
  new_fixture writer-non-ff
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before non-fast-forward fixture"
    return 1
  fi
  printf 'fresh generated index\n' > "$BUILD_REPO/doc/llms.txt"
  if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null; then
    cleanup_fixture
    fail "candidate artifact should package before non-fast-forward fixture"
    return 1
  fi
  export FAKE_PUSH_RACE=true
  if GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
      --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
    cleanup_fixture
    fail "non-fast-forward candidate push must fail closed"
    return 1
  fi
  local remote_sha local_sha
  remote_sha="$(jq -r '.[0].headRefOid' "$FAKE_PR_FILE")"
  local_sha="$("$REAL_GIT" --git-dir="$BARE_REPO" rev-parse "refs/heads/$BRANCH")"
  assert_eq "$remote_sha" "$local_sha" "remote candidate retains the concurrent head" || { cleanup_fixture; return 1; }
  [[ "$remote_sha" != "$CANDIDATE_SHA" ]] || { cleanup_fixture; fail "concurrent fixture must advance the remote candidate"; return 1; }
  if grep -E -- '(^|[[:space:]])(--force|-f)([[:space:]]|$)' "$FAKE_GIT_PUSH_LOG" >/dev/null; then
    cleanup_fixture
    fail "writer must not force over a concurrent candidate head"
    return 1
  fi
  cleanup_fixture
}

test_absent_fresh_ci_never_reports_refresh_ready() {
  new_fixture writer-no-ci
  export FAKE_CI_MODE=absent
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before missing-CI fixture"
    return 1
  fi
  printf 'fresh generated index\n' > "$BUILD_REPO/doc/llms.txt"
  if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null; then
    cleanup_fixture
    fail "candidate artifact should package before missing-CI fixture"
    return 1
  fi
  if GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
      --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
    cleanup_fixture
    fail "writer must fail when no ordinary CI run exists for the refreshed SHA"
    return 1
  fi
  if grep -F 'status=refreshed' "$output" >/dev/null || grep -F 'fresh_ci_run_id=' "$output" >/dev/null; then
    cleanup_fixture
    fail "missing fresh CI must not be reported as ready"
    return 1
  fi
  cleanup_fixture
}

test_package_rejects_oversized_generated_index() {
  new_fixture package-oversize
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before artifact size check"
    return 1
  fi
  dd if=/dev/zero of="$BUILD_REPO/doc/llms.txt" bs=1000000 count=6 2>/dev/null
  if bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null 2>&1; then
    cleanup_fixture
    fail "docs package must reject an unexpectedly large generated index"
    return 1
  fi
  cleanup_fixture
}

test_package_rejects_empty_generated_index() {
  new_fixture package-empty
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before empty-index check"
    return 1
  fi
  : > "$BUILD_REPO/doc/llms.txt"
  if bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null 2>&1; then
    cleanup_fixture
    fail "docs package must reject an empty generated index"
    return 1
  fi
  cleanup_fixture
}

test_writer_rejects_unexpected_artifact_member() {
  new_fixture writer-extra-artifact
  local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
  if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
      --identity-file "$identity" --github-output "$output" >/dev/null; then
    cleanup_fixture
    fail "candidate capture should pass before unexpected-artifact check"
    return 1
  fi
  printf 'fresh generated index\n' > "$BUILD_REPO/doc/llms.txt"
  if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
      --output-dir "$artifact" >/dev/null; then
    cleanup_fixture
    fail "candidate artifact should package before unexpected-artifact check"
    return 1
  fi
  printf 'unexpected executable-like payload\n' > "$artifact/unexpected.txt"
  if GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
      --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
      --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
    cleanup_fixture
    fail "writer must reject unexpected artifact members"
    return 1
  fi
  if grep -E '(^|[[:space:]])push([[:space:]]|$)' "$FAKE_GIT_PUSH_LOG" >/dev/null; then
    cleanup_fixture
    fail "unexpected artifact members must not reach git push"
    return 1
  fi
  cleanup_fixture
}

test_writer_rejects_candidate_destination_symlinks() {
  local link_kind
  for link_kind in index doc-directory; do
    new_fixture "writer-destination-symlink-$link_kind"
    local identity="$FIXTURE/identity.json" output="$FIXTURE/output.txt" artifact="$FIXTURE/artifact"
    local outside="$FIXTURE/outside" outside_index="$FIXTURE/outside-index.txt" candidate_sha
    mkdir -p "$outside"
    printf 'do not overwrite this destination\n' > "$outside_index"

    if [[ "$link_kind" == "index" ]]; then
      rm "$BUILD_REPO/doc/llms.txt"
      ln -s "$outside_index" "$BUILD_REPO/doc/llms.txt"
    else
      mkdir "$outside/doc-directory"
      printf 'do not overwrite this destination\n' > "$outside/doc-directory/llms.txt"
      rm -rf "$BUILD_REPO/doc"
      ln -s "$outside/doc-directory" "$BUILD_REPO/doc"
    fi

    "$REAL_GIT" -C "$BUILD_REPO" add -A
    "$REAL_GIT" -C "$BUILD_REPO" commit -qm "candidate replaces $link_kind with a symlink"
    candidate_sha="$("$REAL_GIT" -C "$BUILD_REPO" rev-parse HEAD)"
    "$REAL_GIT" -C "$BUILD_REPO" push -q origin "HEAD:refs/heads/$BRANCH"
    "$REAL_GIT" -C "$WRITER_REPO" fetch -q "$BARE_REPO" "$BRANCH"
    "$REAL_GIT" -C "$WRITER_REPO" reset --hard -q FETCH_HEAD
    jq --arg sha "$candidate_sha" '.[0].headRefOid = $sha' "$FAKE_PR_FILE" > "$FAKE_PR_FILE.tmp"
    mv "$FAKE_PR_FILE.tmp" "$FAKE_PR_FILE"

    if ! bash "$HELPER" capture --repository "$REPOSITORY" --expected-main-sha "$TRUSTED_MAIN_SHA" \
        --identity-file "$identity" --github-output "$output" >/dev/null; then
      cleanup_fixture
      fail "candidate identity should capture before destination-symlink checks ($link_kind)"
      return 1
    fi

    if [[ "$link_kind" == "index" ]]; then
      rm "$BUILD_REPO/doc/llms.txt"
      printf 'fresh generated index\n' > "$BUILD_REPO/doc/llms.txt"
    else
      outside_index="$outside/doc-directory/llms.txt"
      printf 'fresh generated index\n' > "$outside_index"
    fi

    if ! bash "$HELPER" package --candidate-dir "$BUILD_REPO" --identity-file "$identity" \
        --output-dir "$artifact" >/dev/null; then
      cleanup_fixture
      fail "docs build artifact should package before destination-symlink check ($link_kind)"
      return 1
    fi

    printf 'sentinel must remain unchanged\n' > "$outside_index"
    if GH_TOKEN='test-token' bash "$HELPER" write --repository "$REPOSITORY" --repo-dir "$WRITER_REPO" \
        --artifact-dir "$artifact" --identity-file "$identity" --github-output "$output" \
        --summary-file "$FIXTURE/summary.md" >/dev/null 2>&1; then
      cleanup_fixture
      fail "writer must reject a candidate destination symlink ($link_kind)"
      return 1
    fi
    assert_eq 'sentinel must remain unchanged' "$(cat "$outside_index")" \
      "writer must not follow the candidate destination symlink ($link_kind)" || { cleanup_fixture; return 1; }
    if grep -E '(^|[[:space:]])push([[:space:]]|$)' "$FAKE_GIT_PUSH_LOG" >/dev/null; then
      cleanup_fixture
      fail "candidate destination symlink must not reach git push ($link_kind)"
      return 1
    fi
    cleanup_fixture
  done
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
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "candidate-race" ]]; then
  run_test 'rejects a candidate SHA that changes between selection reads' test_capture_rejects_candidate_advanced_between_reads
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "package-drift" ]]; then
  run_test 'rejects source checkout drift and unrelated docs-build changes' test_package_rejects_candidate_checkout_or_extra_build_drift
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "pre-push-race" ]]; then
  run_test 'rejects a candidate identity change immediately before push' test_writer_rejects_candidate_change_immediately_before_push
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "artifact-token" ]]; then
  run_test 'rejects symlinked artifacts and missing release credentials' test_writer_rejects_symlinked_artifact_and_missing_credential
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "non-ff" ]]; then
  run_test 'rejects non-fast-forward races without overwriting the candidate' test_non_fast_forward_race_is_rejected_without_overwriting_candidate
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "missing-ci" ]]; then
  run_test 'does not report readiness when ordinary CI is absent for the new SHA' test_absent_fresh_ci_never_reports_refresh_ready
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "oversize" ]]; then
  run_test 'rejects oversized generated docs before uploading an artifact' test_package_rejects_oversized_generated_index
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "empty-index" ]]; then
  run_test 'rejects an empty generated index before artifact upload' test_package_rejects_empty_generated_index
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "artifact-extra" ]]; then
  run_test 'rejects unexpected artifact members before any candidate write' test_writer_rejects_unexpected_artifact_member
fi
if [[ -z "${REFRESH_ONLY:-}" || "$REFRESH_ONLY" == "destination-symlink" ]]; then
  run_test 'rejects symlinked candidate destinations before writing or pushing' test_writer_rejects_candidate_destination_symlinks
fi
printf '1..%s\n' "$TOTAL"
printf '# tests %s\n# pass %s\n# fail %s\n' "$TOTAL" "$((TOTAL - FAILED))" "$FAILED"
[[ "$FAILED" -eq 0 ]]
